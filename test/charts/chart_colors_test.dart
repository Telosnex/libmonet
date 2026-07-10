import 'dart:ui';

import 'package:libmonet/charts/chart_colors.dart';
import 'package:libmonet/colorspaces/cam16/cam16.dart';
import 'package:libmonet/colorspaces/hct.dart';
import 'package:libmonet/contrast/contrast.dart';
import 'package:libmonet/core/argb_srgb_xyz_lab.dart';
import 'package:libmonet/core/hex_codes.dart';
import 'package:libmonet/effects/uv_harmony.dart';
import 'package:test/test.dart';
import 'dart:math' as math;

// ---------------------------------------------------------------------------
// CVD verification (test-only): Machado et al. 2009 100% severity matrices,
// applied in linear RGB. The library contains no CVD code; robustness is
// structural (tone tiers). These tests verify that structure delivers.
// ---------------------------------------------------------------------------

const _protanopia = [
  [0.152286, 1.052583, -0.204868],
  [0.114503, 0.786281, 0.099216],
  [-0.003882, -0.048116, 1.051998],
];
const _deuteranopia = [
  [0.367322, 0.860646, -0.227968],
  [0.280085, 0.672501, 0.047413],
  [-0.011820, 0.042940, 0.968881],
];
const _tritanopia = [
  [1.255528, -0.076749, -0.178779],
  [-0.078411, 0.930809, 0.147602],
  [0.004733, 0.691367, 0.303900],
];

int _simulate(int argb, List<List<double>> m) {
  final r = linear(redFromArgb(argb));
  final g = linear(greenFromArgb(argb));
  final b = linear(blueFromArgb(argb));
  double ch(int row) =>
      (m[row][0] * r + m[row][1] * g + m[row][2] * b).clamp(0.0, 100.0);
  return argbFromLinrgbComponents(ch(0), ch(1), ch(2));
}

double _worstCaseDistance(Color a, Color b) {
  var result = Cam16.fromInt(a.argb).distance(Cam16.fromInt(b.argb));
  for (final m in [_protanopia, _deuteranopia, _tritanopia]) {
    final d = Cam16.fromInt(
      _simulate(a.argb, m),
    ).distance(Cam16.fromInt(_simulate(b.argb, m)));
    if (d < result) result = d;
  }
  return result;
}

void main() {
  const seed = Color(0xff6750a4);
  const white = Color(0xffffffff);
  const black = Color(0xff000000);
  const tinted = Color(0xfff4eedf);

  ChartColors onLight() => ChartColors.fromColorAndBackground(seed, white);
  ChartColors onDark() => ChartColors.fromColorAndBackground(seed, black);

  group('visible tone band', () {
    test('near edge is visible against its background, both algos', () {
      for (final algo in Algo.values) {
        for (final bg in [white, black, tinted]) {
          final chart = ChartColors.fromColorAndBackground(
            seed,
            bg,
            algo: algo,
          );
          final bgTone = Hct.fromColor(bg).tone;
          // Border-usage separation at dial 0.5 is modest but nonzero.
          expect(
            (chart.nearTone - bgTone).abs(),
            greaterThan(2.0),
            reason: 'algo=$algo bg=${hexFromArgb(bg.argb)}',
          );
        }
      }
    });

    test('band is one-sided: near and far share polarity', () {
      for (final bg in [white, black, tinted]) {
        final chart = ChartColors.fromColorAndBackground(seed, bg);
        final bgTone = Hct.fromColor(bg).tone;
        expect(
          (chart.nearTone - bgTone).sign,
          (chart.farTone - bgTone).sign,
          reason: 'bg=${hexFromArgb(bg.argb)}',
        );
        expect(
          (chart.farTone - bgTone).abs(),
          greaterThan((chart.nearTone - bgTone).abs()),
        );
      }
    });
  });

  group('categorical', () {
    test('deterministic and value-equal instances share results', () {
      final a = onLight().categorical(12);
      final b = onLight().categorical(12);
      expect(a, b);
      expect(onLight(), onLight());
    });

    test('n colors, unique, for n = 1..32 on light and dark', () {
      for (final chart in [onLight(), onDark()]) {
        for (var n = 1; n <= 32; n++) {
          final colors = chart.categorical(n);
          expect(colors, hasLength(n));
          expect(
            colors.map((c) => c.argb).toSet(),
            hasLength(n),
            reason: 'n=$n',
          );
        }
      }
    });

    test('stable mode: consecutive series differ in tone', () {
      for (final chart in [onLight(), onDark()]) {
        final bandWidth = (chart.farTone - chart.nearTone).abs();
        final tones = [
          for (final c in chart.categorical(32)) Hct.fromColor(c).tone,
        ];
        for (var i = 1; i < 32; i++) {
          expect(
            (tones[i] - tones[i - 1]).abs(),
            greaterThan(bandWidth * 0.35),
            reason: 'consecutive pair ${i - 1},$i',
          );
        }
      }
    });

    test('stable mode: hue near-returns are compensated by tone', () {
      // Regression: seed 0xfff40009, n=10 — series 2 and 10 (indices 1, 9)
      // are 20° apart in hue (golden-angle near-return at gap 8) and were
      // previously assigned the same tone tier.
      for (final chart in [
        ChartColors.fromColorAndBackground(const Color(0xfff40009), white),
        onLight(),
        onDark(),
      ]) {
        final bandWidth = (chart.farTone - chart.nearTone).abs();
        // Verified bound: every pair keeps hue >= 25 degrees or tone >= 25%
        // of the band through n = 13 (probed across seeds and backgrounds;
        // the binding case is vivid seeds whose hue wheel partially
        // collapses under gamut clamping).
        final colors = chart.categorical(13);
        for (var i = 0; i < 13; i++) {
          for (var j = i + 1; j < 13; j++) {
            final a = Hct.fromColor(colors[i]);
            final b = Hct.fromColor(colors[j]);
            final hueGap = 180.0 - ((a.uvHue - b.uvHue).abs() - 180.0).abs();
            final toneGap = (a.tone - b.tone).abs();
            expect(
              hueGap >= 25.0 || toneGap >= bandWidth * 0.25,
              isTrue,
              reason: 'pair $i,$j: hueGap=$hueGap toneGap=$toneGap',
            );
          }
        }
      }
    });

    test('re-spread mode: adjacent series differ in tone, including wrap', () {
      for (final chart in [onLight(), onDark()]) {
        final bandWidth = (chart.farTone - chart.nearTone).abs();
        for (final n in [2, 3, 4, 5, 7, 8, 12, 16, 31, 32]) {
          final tones = [
            for (final c in chart.categorical(n, isColorAtIndexStable: false))
              Hct.fromColor(c).tone,
          ];
          for (var i = 0; i < n; i++) {
            final next = (i + 1) % n;
            if (n == 1) continue;
            expect(
              (tones[i] - tones[next]).abs(),
              greaterThan(bandWidth * 0.4),
              reason: 'n=$n adjacent pair $i,$next',
            );
          }
        }
      }
    });

    test('adjacent series are distinct under all dichromacies', () {
      for (final chart in [onLight(), onDark()]) {
        for (final n in [2, 3, 5, 8, 13, 21, 32]) {
          final colors = chart.categorical(n);
          for (var i = 0; i < n; i++) {
            final next = (i + 1) % n;
            if (i == next) continue;
            // Regression floor calibrated by probing seeds x backgrounds x
            // n=2..32: observed minimum 5.3 (yellow-green pairs under
            // deuteranopia). CAM16-UCS ~1 is a JND; 4.5+ is clearly
            // distinguishable for chart-sized marks. The tone-gap test above
            // is the structural guarantee; this catches regressions.
            expect(
              _worstCaseDistance(colors[i], colors[next]),
              greaterThan(4.5),
              reason: 'n=$n adjacent pair $i,$next',
            );
          }
        }
      }
    });

    test('hue varies: n distinct u\u2032v\u2032 directions', () {
      final colors = onLight().categorical(8);
      final hues = [for (final c in colors) Hct.fromColor(c).uvHue.round()];
      expect(hues.toSet(), hasLength(8));
    });

    test('stable mode: categorical(n) is a prefix of categorical(n + 1)', () {
      final chart = onLight();
      for (var n = 1; n < 24; n++) {
        final smaller = chart.categorical(n);
        final larger = chart.categorical(n + 1);
        expect(larger.sublist(0, n), smaller, reason: 'n=$n');
      }
    });

    test('unstable mode re-spreads: not prefix-stable (documented)', () {
      final chart = onLight();
      final three = chart.categorical(3, isColorAtIndexStable: false);
      final four = chart.categorical(4, isColorAtIndexStable: false);
      expect(four.sublist(0, 3), isNot(three));
    });

    test('near-neutral seeds still yield chromatic, distinct series', () {
      final chart = ChartColors.fromColorAndBackground(
        const Color(0xff888888),
        white,
      );
      final colors = chart.categorical(6);
      expect(colors.map((c) => c.argb).toSet(), hasLength(6));
      expect(
        colors.map((c) => Hct.fromColor(c).chroma).reduce(math.max),
        greaterThan(20.0),
      );
    });

    test('empty and negative counts', () {
      expect(onLight().categorical(0), isEmpty);
      expect(() => onLight().categorical(-1), throwsRangeError);
    });
  });

  group('sequential', () {
    test('tone is monotonic and spans a substantial range', () {
      for (final chart in [onLight(), onDark()]) {
        final tones = [
          for (var i = 0; i <= 20; i++)
            Hct.fromColor(chart.sequential.at(i / 20)).tone,
        ];
        final direction = (tones.last - tones.first).sign;
        for (var i = 1; i < tones.length; i++) {
          expect(
            (tones[i] - tones[i - 1]) * direction,
            greaterThanOrEqualTo(-0.5),
            reason: 'i=$i',
          );
        }
        expect((tones.last - tones.first).abs(), greaterThan(30.0));
      }
    });

    test('no hue drift', () {
      final chart = onLight();
      final anchorHue = Hct.fromColor(chart.sequential.at(1.0)).hue;
      for (var i = 1; i <= 10; i++) {
        final hct = Hct.fromColor(chart.sequential.at(i / 10));
        if (hct.chroma < 12.0) continue; // hue is noisy near gray
        final diff = 180.0 - ((hct.hue - anchorHue).abs() - 180.0).abs();
        expect(diff, lessThan(8.0), reason: 't=${i / 10}');
      }
    });

    test('low endpoint does not disappear into a tinted background', () {
      final chart = ChartColors.fromColorAndBackground(seed, tinted);
      final low = chart.sequential.at(0.0);
      expect(
        Algo.apca
            .contrastBetweenArgbs(bgArgb: tinted.argb, fgArgb: low.argb)
            .abs(),
        greaterThan(10.0),
      );
    });

    test('achromatic seed: gray ramp, tone carries the value', () {
      final chart = ChartColors.fromColorAndBackground(black, white);
      final r = chart.sequential;
      for (var i = 0; i <= 10; i++) {
        expect(
          Hct.fromColor(r.at(i / 10)).chroma,
          lessThan(4.0),
          reason: 't=${i / 10}',
        );
      }
      expect(
        (Hct.fromColor(r.at(1.0)).tone - Hct.fromColor(r.at(0.0)).tone).abs(),
        greaterThan(20.0),
      );
      // Same policy, same ramp: sequential(gray) == diverging(gray, gray).
      final d = chart.divergingWith(black);
      for (final t in [0.0, 0.3, 0.5, 0.8, 1.0]) {
        expect(r.at(t).argb, d.at(t).argb, reason: 't=$t');
      }
    });

    test('raising the contrast dial never collapses the band', () {
      // Regression: at high dials both edges race to the gamut ceiling; the
      // naive band collapsed to zero width at 100% (all values white on
      // dark). The near edge must cede toward the dial-0.5 floor instead.
      const vividRed = Color(0xfff40009);
      for (final bg in [white, black, const Color(0xff121212)]) {
        final defaultWidth =
            (ChartColors.fromColorAndBackground(vividRed, bg).farTone -
                    ChartColors.fromColorAndBackground(vividRed, bg).nearTone)
                .abs();
        for (final dial in [0.65, 0.8, 1.0]) {
          final chart = ChartColors.fromColorAndBackground(
            vividRed,
            bg,
            contrast: dial,
          );
          expect(
            (chart.farTone - chart.nearTone).abs(),
            greaterThanOrEqualTo(defaultWidth - 0.1),
            reason: 'bg=${hexFromArgb(bg.argb)} dial=$dial',
          );
          // The near edge may cede, but never below the 0.5 visibility floor.
          expect(
            Algo.apca
                .contrastBetweenArgbs(
                  bgArgb: bg.argb,
                  fgArgb: chart.sequential.at(0.0).argb,
                )
                .abs(),
            greaterThan(10.0),
            reason: 'bg=${hexFromArgb(bg.argb)} dial=$dial',
          );
        }
      }
    });

    test('muted → vivid never inverts, even at gamut-capped far tones', () {
      // Regression: vivid red on dark at dial 0.65 put the far anchor at
      // tone 82, where red caps near chroma 17 — below the low anchor's
      // requested 20, silently inverting the encoding.
      for (final dial in [0.5, 0.65, 0.8, 1.0]) {
        final ramp = ChartColors.fromColorAndBackground(
          const Color(0xfff40009),
          const Color(0xff121212),
          contrast: dial,
        ).sequential;
        final lowChroma = Hct.fromColor(ramp.at(0.0)).chroma;
        final highChroma = Hct.fromColor(ramp.at(1.0)).chroma;
        expect(
          highChroma,
          greaterThanOrEqualTo(lowChroma),
          reason: 'dial=$dial',
        );
      }
    });

    test('discretize shares the ramp and hits endpoints', () {
      final ramp = onLight().sequential;
      final bins = ramp.discretize(5);
      expect(bins, hasLength(5));
      expect(bins.first, ramp.at(0.0));
      expect(bins.last, ramp.at(1.0));
      expect(() => ramp.discretize(0), throwsRangeError);
      expect(() => ramp.at(1.01), throwsArgumentError);
    });
  });

  group('diverging', () {
    ToneRamp ramp({Color high = const Color(0xff00639b)}) =>
        ChartColors.fromColorAndBackground(
          const Color(0xffb3261e),
          white,
        ).divergingWith(high);

    test('midpoint at exactly 0.5 is neutral and visible', () {
      final mid = ramp().at(0.5);
      expect(Hct.fromColor(mid).chroma, lessThan(4.0));
      expect(
        Algo.apca
            .contrastBetweenArgbs(bgArgb: white.argb, fgArgb: mid.argb)
            .abs(),
        greaterThan(10.0),
      );
    });

    test('sides are balanced in tone', () {
      final r = ramp();
      for (final offset in [0.1, 0.25, 0.4]) {
        expect(
          Hct.fromColor(r.at(0.5 - offset)).tone,
          closeTo(Hct.fromColor(r.at(0.5 + offset)).tone, 1.5),
          reason: 'offset=$offset',
        );
      }
    });

    test('sides use distinguishable hues', () {
      final r = ramp();
      final low = Hct.fromColor(r.at(0.0));
      final high = Hct.fromColor(r.at(1.0));
      final diff = 180.0 - ((low.uvHue - high.uvHue).abs() - 180.0).abs();
      expect(diff, greaterThan(90.0));
    });

    test('both seeds achromatic: monotone gray, sign carried by tone', () {
      for (final bg in [white, black]) {
        final chart = ChartColors.fromColorAndBackground(black, bg);
        final r = chart.divergingWith(black);
        final tones = [
          for (var i = 0; i <= 10; i++) Hct.fromColor(r.at(i / 10)).tone,
        ];
        // Gray throughout; no invented hue.
        for (var i = 0; i <= 10; i++) {
          expect(
            Hct.fromColor(r.at(i / 10)).chroma,
            lessThan(4.0),
            reason: 'bg=${hexFromArgb(bg.argb)} t=${i / 10}',
          );
        }
        // Monotone from near edge to far edge: endpoints unmistakably
        // different, light→dark on light backgrounds, dark→light on dark.
        final direction = (tones.last - tones.first).sign;
        for (var i = 1; i < tones.length; i++) {
          expect(
            (tones[i] - tones[i - 1]) * direction,
            greaterThanOrEqualTo(-0.5),
            reason: 'bg=${hexFromArgb(bg.argb)} i=$i',
          );
        }
        expect((tones.last - tones.first).abs(), greaterThan(20.0));
        // Both endpoints visible against the background.
        for (final t in [0.0, 1.0]) {
          expect(
            Algo.apca
                .contrastBetweenArgbs(bgArgb: bg.argb, fgArgb: r.at(t).argb)
                .abs(),
            greaterThan(10.0),
            reason: 'bg=${hexFromArgb(bg.argb)} t=$t',
          );
        }
      }
    });

    test(
      'one achromatic side stays gray; the chromatic side keeps its hue',
      () {
        final r = ChartColors.fromColorAndBackground(
          const Color(0xffb3261e),
          white,
        ).divergingWith(black);
        expect(Hct.fromColor(r.at(0.0)).chroma, greaterThan(30.0));
        expect(Hct.fromColor(r.at(1.0)).chroma, lessThan(4.0));
      },
    );

    test('near-identical seeds get the afterimage complement', () {
      final r = ramp(high: const Color(0xffc4351f));
      final low = Hct.fromColor(r.at(0.0));
      final high = Hct.fromColor(r.at(1.0));
      final diff = 180.0 - ((low.uvHue - high.uvHue).abs() - 180.0).abs();
      expect(diff, greaterThan(120.0));
    });
  });

  group('brief wrapper signatures', () {
    test('work verbatim', () {
      final palette = categoricalChartPalette(
        seed: seed,
        brightness: Brightness.light,
        count: 5,
      );
      expect(palette, hasLength(5));
      final s = sequentialChartColor(
        seed: seed,
        brightness: Brightness.dark,
        t: 0.3,
      );
      final d = divergingChartColor(
        lowSeed: const Color(0xffb3261e),
        highSeed: const Color(0xff00639b),
        brightness: Brightness.light,
        t: 0.5,
      );
      expect(s, isA<Color>());
      expect(Hct.fromColor(d).chroma, lessThan(4.0));
    });

    test('wrappers match ChartColors output', () {
      expect(
        categoricalChartPalette(
          seed: seed,
          brightness: Brightness.light,
          count: 7,
        ),
        ChartColors.fromColorAndBackground(seed, white).categorical(7),
      );
    });
  });
}
