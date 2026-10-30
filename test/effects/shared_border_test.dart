import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:monet_ui/monet_ui.dart';

/// Stronger-polarity contrast, as borders judge it.
double sep(Algo algo, int a, int b) => max(
  algo.contrastBetweenArgbs(bgArgb: a, fgArgb: b).abs(),
  algo.contrastBetweenArgbs(bgArgb: b, fgArgb: a).abs(),
);

int rand(Random rng) => 0xFF000000 | rng.nextInt(1 << 24);

void main() {
  group('invariants (seeded random)', () {
    final rng = Random(2026);
    for (var trial = 0; trial < 300; trial++) {
      final algo = Algo.values[trial % 2];
      final contrast = [0.3, 0.5, 0.7][trial % 3];
      final surfaces = [for (var i = 0; i < 1 + rng.nextInt(4); i++) rand(rng)];
      final pixels = trial % 5 == 0
          ? const <int>[]
          : [for (var i = 0; i < 1 + rng.nextInt(30); i++) rand(rng)];

      test('trial $trial', () {
        final bg = AnyBackground(pixels, algo: algo, contrast: contrast);
        final r = bg.sharedBorder(surfaces);
        final target = algo.getAbsoluteContrast(contrast, Usage.border);

        // I1: one tone; each border is its surface's resting hue at it.
        expect(r.borderArgbs, hasLength(surfaces.length));
        for (var i = 0; i < surfaces.length; i++) {
          final h = Hct.fromInt(surfaces[i]);
          expect(r.borderArgbs[i], Hct.from(h.hue, h.chroma, r.tone).toInt());
        }

        // I2: the guarantee holds against what it claims.
        if (r.meetsTarget && r.clearsBackground) {
          expect(pixels, isNotEmpty);
          for (final b in r.borderArgbs) {
            for (final p in pixels) {
              expect(sep(algo, b, p), greaterThanOrEqualTo(target - 1e-9));
            }
          }
        } else if (r.meetsTarget) {
          for (var i = 0; i < surfaces.length; i++) {
            expect(
              sep(algo, r.borderArgbs[i], surfaces[i]),
              greaterThanOrEqualTo(target - 1e-9),
            );
          }
        }
        if (pixels.isEmpty) expect(r.clearsBackground, isFalse);

        // I4: surface order doesn't change the tone.
        final reversed = AnyBackground(
          pixels,
          algo: algo,
          contrast: contrast,
        ).sharedBorder(surfaces.reversed.toList());
        expect(reversed.tone, r.tone);

        // I5: pure; cached on the same background, equal on a new one.
        expect(bg.sharedBorder(surfaces), same(r));
        expect(
          AnyBackground(
            pixels,
            algo: algo,
            contrast: contrast,
          ).sharedBorder(surfaces),
          r,
        );
      });
    }
  });

  test('I3: unknown matches a background no tone can clear', () {
    final everyGray = [for (var g = 0; g < 256; g++) 0xFF000000 | g * 0x010101];
    final surfaces = [0xFFB431ED, 0xFF4D394F, 0xFF536D2D];
    for (final algo in Algo.values) {
      final unknown = AnyBackground.unknown(
        algo: algo,
        contrast: 0.5,
      ).sharedBorder(surfaces);
      final busy = AnyBackground(
        everyGray,
        algo: algo,
        contrast: 0.5,
      ).sharedBorder(surfaces);
      expect(busy.clearsBackground, isFalse);
      expect(unknown.tone, busy.tone);
      expect(unknown.borderArgbs, busy.borderArgbs);
    }
  });

  test('prefers a shadow: just darker than the darkest surface', () {
    // Light surfaces over a light wallpaper: a dark border clears both.
    final r = AnyBackground(
      const [0xFFE8EEF4, 0xFFD0DAE4],
      algo: Algo.apca,
      contrast: 0.5,
    ).sharedBorder(const [0xFFB0D0F0, 0xFFF0C0B0]);
    expect(r.meetsTarget, isTrue);
    expect(r.clearsBackground, isTrue);
    final darkest = min(lstarFromArgb(0xFFB0D0F0), lstarFromArgb(0xFFF0C0B0));
    expect(r.tone, lessThanOrEqualTo(darkest));
  });

  test('a surface that stands out may go without a visible border', () {
    // The background branch only needs borders to clear the pixels; a
    // surface already at that tone keeps the set's elevation, borderless.
    final r = AnyBackground(
      const [0xFFF4F4F4],
      algo: Algo.apca,
      contrast: 0.5,
    ).sharedBorder(const [0xFF303030]);
    expect(r.clearsBackground, isTrue);
    expect(r.tone, lessThanOrEqualTo(lstarFromArgb(0xFF303030)));
  });

  group('flat backgrounds', () {
    // Megalith is all photos, which span nearly every tone, so the
    // background branch almost never wins there. Flat backgrounds are where
    // it matters: chips that already stand out keep a near-invisible border.
    const chipSets = {
      'dark': [0xff1a3a6a, 0xff3a1a4a, 0xff1f3f2a],
      'light': [0xffb0d0f0, 0xfff0c0b0, 0xffc8e8c0],
      'mid': [0xff4477aa, 0xffaa4444, 0xff44aa66],
    };
    const solids = {'red': 0xffff0000, 'dark gray': 0xff1e1e1e};
    for (final solid in solids.entries) {
      for (final chips in chipSets.entries) {
        test('${chips.key} chips on solid ${solid.key}', () {
          for (final algo in Algo.values) {
            final r = AnyBackground(
              [solid.value],
              algo: algo,
              contrast: 0.5,
            ).sharedBorder(chips.value);
            final tones = chips.value.map(lstarFromArgb);
            final darkest = tones.reduce(min);
            final lightest = tones.reduce(max);
            expect(r.meetsTarget, isTrue);
            expect(r.clearsBackground, isTrue, reason: '$algo');
            // Outside the chips' range: never a ring cutting through them.
            expect(
              r.tone <= darkest || r.tone >= lightest,
              isTrue,
              reason: '$algo T${r.tone}',
            );
            if (solid.key == 'red') {
              // Red sits between every set and its border side: the border
              // lands at the darkest chip, borderless, one elevation.
              expect(darkest - r.tone, inInclusiveRange(0, 5), reason: '$algo');
            }
          }
        });
      }
    }

    test('red: background wins over chips-only on every chip set', () {
      for (final chips in chipSets.values) {
        final r = AnyBackground(
          const [0xffff0000],
          algo: Algo.apca,
          contrast: 0.5,
        ).sharedBorder(chips);
        final chipsOnly = AnyBackground.unknown(
          algo: Algo.apca,
          contrast: 0.5,
        ).sharedBorder(chips);
        expect(r.clearsBackground, isTrue);
        expect(r.tone, isNot(chipsOnly.tone));
      }
    });

    test('a gradient overlapping the chips falls back to chips-only', () {
      final gradient = [
        for (var l = 20; l <= 35; l++) argbFromLstar(l.toDouble()),
      ];
      final chips = chipSets['dark']!;
      final r = AnyBackground(
        gradient,
        algo: Algo.apca,
        contrast: 0.5,
      ).sharedBorder(chips);
      final chipsOnly = AnyBackground.unknown(
        algo: Algo.apca,
        contrast: 0.5,
      ).sharedBorder(chips);
      expect(r.clearsBackground, isFalse);
      expect(r.tone, chipsOnly.tone);
    });
  });

  test('no valid tone: best effort, flagged', () {
    // Max contrast, text target, one mid-gray chip on every gray: nothing
    // clears the background, and no tone reaches the target from #777777.
    final everyGray = [for (var g = 0; g < 256; g++) 0xFF000000 | g * 0x010101];
    final r = AnyBackground(
      everyGray,
      algo: Algo.wcag21,
      contrast: 1.0,
    ).sharedBorder(const [0xFF777777], usage: Usage.text);
    final target = Algo.wcag21.getAbsoluteContrast(1.0, Usage.text);
    expect(r.meetsTarget, isFalse);
    expect(r.clearsBackground, isFalse);
    expect(r.worstContrast, lessThan(target));
    // Strongest available: no tone does better against the chip.
    for (var t = 0; t <= 100; t++) {
      final h = Hct.fromInt(0xFF777777);
      final b = Hct.from(h.hue, h.chroma, t.toDouble()).toInt();
      expect(
        sep(Algo.wcag21, b, 0xFF777777),
        lessThanOrEqualTo(r.worstContrast + 1e-9),
      );
    }
  });

  test('unknown is not equal to a real black-and-white background', () {
    final unknown = AnyBackground.unknown(algo: Algo.apca, contrast: 0.5);
    final bw = AnyBackground(
      const [0xFF000000, 0xFFFFFFFF],
      algo: Algo.apca,
      contrast: 0.5,
    );
    expect(unknown, isNot(bw));
    expect(
      unknown.sharedBorder(const [0xFF4477AA]),
      isNot(bw.sharedBorder(const [0xFF4477AA])),
    );
  });

  group('validation', () {
    final bg = AnyBackground.unknown(algo: Algo.apca, contrast: 0.5);
    test('no surfaces throws', () {
      expect(() => bg.sharedBorder(const <int>[]), throwsArgumentError);
    });
  });
}
