import 'dart:ui';

import 'package:libmonet/core/argb_srgb_xyz_lab.dart';
import 'package:libmonet/core/hex_codes.dart';
import 'package:libmonet/colorspaces/hct.dart';
import 'package:libmonet/theming/palette.dart';
import 'package:test/test.dart';

import '../utils/color_matcher.dart';

double _tone(Color c) => Hct.fromColor(c).tone;

/// Minimal class mirroring Palette's `late final` pattern.
/// Tracks evaluation counts to prove laziness.
class _LazyProbe {
  int aCount = 0;
  int bCount = 0;
  int cCount = 0;

  /// Computed once on first access, never again.
  late final int a = _computeA();

  /// Depends on [a] — still lazy, evaluated on first access of [b].
  late final int b = _computeB();

  /// Independent of [a] and [b].
  late final int c = _computeC();

  int _computeA() {
    aCount++;
    return 1;
  }

  int _computeB() {
    bCount++;
    return a + 10;
  }

  int _computeC() {
    cCount++;
    return 99;
  }
}

void main() {
  group('late final laziness', () {
    test('fields are not evaluated at construction time', () {
      final probe = _LazyProbe();
      expect(probe.aCount, 0);
      expect(probe.bCount, 0);
      expect(probe.cCount, 0);
    });

    test('accessing a field evaluates it exactly once', () {
      final probe = _LazyProbe();
      expect(probe.a, 1);
      expect(probe.aCount, 1);
      // Second access — no recomputation.
      expect(probe.a, 1);
      expect(probe.aCount, 1);
      // b and c still untouched.
      expect(probe.bCount, 0);
      expect(probe.cCount, 0);
    });

    test('dependent field triggers its dependency but each runs once', () {
      final probe = _LazyProbe();
      // Access b first — should trigger a (dependency), then b.
      expect(probe.b, 11);
      expect(probe.aCount, 1);
      expect(probe.bCount, 1);
      // Access a again — already cached.
      expect(probe.a, 1);
      expect(probe.aCount, 1);
      // c still untouched.
      expect(probe.cCount, 0);
    });

    test('unused fields are never evaluated', () {
      final probe = _LazyProbe();
      // Only touch a.
      expect(probe.a, 1);
      expect(probe.aCount, 1);
      expect(probe.bCount, 0);
      expect(probe.cCount, 0);
    });
  });

  group('polarity consistency', () {
    // The invariant: siblings solved against the **same container** must
    // land on the same side of that container (both lighter or both darker).
    //
    //   background ─┬─ fill  ┐ same polarity vs background
    //              └─ text  ┘
    //
    //   fill ─┬─ fillText  ┐ same polarity vs fill
    //         └─ fillIcon  ┘
    //
    //   color ─┬─ colorText ┐ same polarity vs color
    //          └─ colorIcon ┘

    const brandColor = Color(0xFF1565C0); // a blue

    /// Returns +1 if b is lighter than a, -1 if darker.
    /// Asserts the difference is non-trivial (> 1 tone).
    double dir(Color a, Color b, String label) {
      final ta = _tone(a);
      final tb = _tone(b);
      final d = tb - ta;
      expect(d.abs(), greaterThan(1.0),
          reason: '$label: tones too close '
              '(${ta.toStringAsFixed(1)} vs ${tb.toStringAsFixed(1)})');
      return d.sign;
    }

    for (final bgTone in [10, 20, 30, 40, 50, 55, 60, 70, 80, 90, 95]) {
      group('bgTone=$bgTone', () {
        late Palette p;
        setUp(() => p = Palette.from(brandColor,
            backgroundTone: bgTone.toDouble()));

        test('fill and text share polarity vs background', () {
          final fillDir = dir(p.background, p.fill, 'bg→fill');
          final textDir = dir(p.background, p.text, 'bg→text');
          expect(fillDir, textDir,
              reason: 'fill (T${_tone(p.fill).round()}) and '
                  'text (T${_tone(p.text).round()}) should both be '
                  '${fillDir > 0 ? "lighter" : "darker"} than '
                  'background (T${_tone(p.background).round()})');
        });

        test('fillText and fillIcon share polarity vs fill', () {
          final fillToText = dir(p.fill, p.fillText, 'fill→fillText');
          final fillToIcon = dir(p.fill, p.fillIcon, 'fill→fillIcon');
          expect(fillToText, fillToIcon,
              reason: 'fillText (T${_tone(p.fillText).round()}) and '
                  'fillIcon (T${_tone(p.fillIcon).round()}) should both be '
                  '${fillToText > 0 ? "lighter" : "darker"} than '
                  'fill (T${_tone(p.fill).round()})');
        });

        test('colorText and colorIcon share polarity vs color', () {
          final colorToText = dir(p.color, p.colorText, 'color→colorText');
          final colorToIcon = dir(p.color, p.colorIcon, 'color→colorIcon');
          expect(colorToText, colorToIcon,
              reason: 'colorText (T${_tone(p.colorText).round()}) and '
                  'colorIcon (T${_tone(p.colorIcon).round()}) should both be '
                  '${colorToText > 0 ? "lighter" : "darker"} than '
                  'color (T${_tone(p.color).round()})');
        });
      });
    }
  });

  group('#1177AA bgTone=10', () {
    test('snapshot', () {
      final p = Palette.from(
        const Color(0xff1177AA),
        backgroundTone: 10,
      );
      expect(p.color, isColor(0xff1177AA));
      expect(p.colorBorder, isColor(0xff005C86));
      expect(p.fill, isColor(0xff499CD1));
      expect(p.fillBorder, isColor(0xff499CD1));
      expect(p.text, isColor(0xff6DBDF4));
      expect(p.fillText, isColor(0xffFFFFFF));
      expect(p.fillIcon, isColor(0xffDDEEFF));
    });
  });

  group('#334157', () {
    test('light mode', () {
      final colors = Palette.from(
        const Color(0xff334157),
        backgroundTone: 100.0,
      );
      expect(colors.color, isColor(0xff334157));
      expect(colors.colorBorder, isColor(0xff334157));
      expect(colors.colorText, isColor(0xffB5C3DE));
      expect(colors.colorIcon, isColor(0xff9BA9C4));
      expect(colors.colorHovered, isColor(0xff64728B));
      expect(colors.colorHoveredText, isColor(0xffD5E3FF));
      expect(colors.colorSplashed, isColor(0xff808EA8));
      expect(colors.colorSplashedText, isColor(0xffF5F7FF));
      expect(colors.fill, isColor(0xffA4B3CD));
      expect(colors.fillText, isColor(0xff0B1A2E));
      expect(colors.fillIcon, isColor(0xff3A485E));
      expect(colors.fillHovered, isColor(0xff7B89A2));
      expect(colors.fillHoveredText, isColor(0xffF0F3FF));
      expect(colors.fillSplashed, isColor(0xff5E6C84));
      expect(colors.fillSplashedText, isColor(0xffD0DFFB));
      expect(colors.text, isColor(0xff7B89A2));
      expect(colors.textHovered, isColor(0xffC2D0EC));
      expect(colors.textHoveredText, isColor(0xff3A485E));
      expect(colors.textSplashed, isColor(0xffA2B0CB));
      expect(colors.textSplashedText, isColor(0xff061529));
    });

    test('dark mode', () {
      final colors = Palette.from(
        const Color(0xff334157),
        backgroundTone: 0.0,
      );
      expect(colors.color, isColor(0xff334157));
      expect(colors.colorBorder, isColor(0xff45536A));
      expect(colors.colorText, isColor(0xffB5C3DE));
      expect(colors.colorIcon, isColor(0xff9BA9C4));
      expect(colors.colorHovered, isColor(0xff64728B));
      expect(colors.colorHoveredText, isColor(0xffD5E3FF));
      expect(colors.colorSplashed, isColor(0xff808EA8));
      expect(colors.colorSplashedText, isColor(0xffF5F7FF));
      expect(colors.fill, isColor(0xff8391AB));
      expect(colors.fillText, isColor(0xffFAF9FF));
      expect(colors.fillIcon, isColor(0xffDFE9FF));
      expect(colors.fillHovered, isColor(0xffAAB8D3));
      expect(colors.fillHoveredText, isColor(0xff162439));
      expect(colors.fillSplashed, isColor(0xffC3D1ED));
      expect(colors.fillSplashedText, isColor(0xff3C4A60));
      expect(colors.text, isColor(0xffA4B2CD));
      expect(colors.textHovered, isColor(0xff5B6981));
      expect(colors.textHoveredText, isColor(0xffCEDDF9));
      expect(colors.textSplashed, isColor(0xff8290AA));
      expect(colors.textSplashedText, isColor(0xffF8F8FF));
    });
  });

  group('regression', () {
    test('#02174E should have blue border, not white', () {
      // Very dark blue on very dark background (both ~tone 10) should get
      // a lighter blue border (~tone 50), not an extreme white fallback.
      // The L* is conservative to ensure chromatic colors meet contrast.
      final colors = Palette.from(
        const Color(0xff02174E),
        backgroundTone: 10.0,
      );
      expect(colors.color, isColor(0xff02174E));
      expect(colors.colorBorder, isColor(0xff415189)); // blue at ~tone 38
    });

    test('#D29C57 should have darker border, not lighter', () {
      // Golden-brown (T≈68) on warm light background (T≈83).
      // Only ~Lc 20 between them — below fill-level visibility,
      // so a darker border is solved to help delineate the edge.
      final colors = Palette.from(
        const Color(0xffD29C57),
        backgroundTone: lstarFromArgb(0xffFFCA88),
      );
      expect(colors.color, isColor(0xffD29C57));
      expect(colors.colorBorder, isColor(0xffA87836)); // darker border (~T52)
    });

    test('#A57B43 has darker border visually, feels intense as stroke', () {
      // Very dark blue on very dark background (both ~tone 10) should get
      // a lighter blue border (~tone 50), not an extreme white fallback.
      // The L* is conservative to ensure chromatic colors meet contrast.
      final colors = Palette.from(
        const Color(0xffA57B43),
        backgroundTone: lstarFromArgb(0xff986E38),
      );
      expect(colors.color, isColor(0xffA57B43));
      expect(colors.colorBorder, isColor(0xff75511D)); // subtle shadow, not harsh hole
      expect(lstarFromArgb(colors.color.argb), closeTo(54.627, 0.001));
      expect(lstarFromArgb(colors.colorBorder.argb), closeTo(37.400, 0.001));
    });
  });

  group('helpers', skip: 'test generators', () {
    const color = Color(0xff334157);

    test('generate light mode test code', () {
      final answers = Palette.from(color, backgroundTone: 100.0);
      final code = '''
      expect(colors.color, isColor(${hexFromArgb(color.argb).replaceAll('#', '0xff')}));
      expect(colors.colorBorder, isColor(${hexFromArgb(answers.colorBorder.argb).replaceAll('#', '0xff')}));
      expect(colors.colorText, isColor(${hexFromArgb(answers.colorText.argb).replaceAll('#', '0xff')}));
      expect(colors.colorIcon, isColor(${hexFromArgb(answers.colorIcon.argb).replaceAll('#', '0xff')}));
      expect(colors.colorHovered, isColor(${hexFromArgb(answers.colorHovered.argb).replaceAll('#', '0xff')}));
      expect(colors.colorHoveredText, isColor(${hexFromArgb(answers.colorHoveredText.argb).replaceAll('#', '0xff')}));
      expect(colors.colorSplashed, isColor(${hexFromArgb(answers.colorSplashed.argb).replaceAll('#', '0xff')}));
      expect(colors.colorSplashedText, isColor(${hexFromArgb(answers.colorSplashedText.argb).replaceAll('#', '0xff')}));
      expect(colors.fill, isColor(${hexFromArgb(answers.fill.argb).replaceAll('#', '0xff')}));
      expect(colors.fillText, isColor(${hexFromArgb(answers.fillText.argb).replaceAll('#', '0xff')}));
      expect(colors.fillIcon, isColor(${hexFromArgb(answers.fillIcon.argb).replaceAll('#', '0xff')}));
      expect(colors.fillHovered, isColor(${hexFromArgb(answers.fillHovered.argb).replaceAll('#', '0xff')}));
      expect(colors.fillHoveredText, isColor(${hexFromArgb(answers.fillHoveredText.argb).replaceAll('#', '0xff')}));
      expect(colors.fillSplashed, isColor(${hexFromArgb(answers.fillSplashed.argb).replaceAll('#', '0xff')}));
      expect(colors.fillSplashedText, isColor(${hexFromArgb(answers.fillSplashedText.argb).replaceAll('#', '0xff')}));
      expect(colors.text, isColor(${hexFromArgb(answers.text.argb).replaceAll('#', '0xff')}));
      expect(colors.textHovered, isColor(${hexFromArgb(answers.textHovered.argb).replaceAll('#', '0xff')}));
      expect(colors.textHoveredText, isColor(${hexFromArgb(answers.textHoveredText.argb).replaceAll('#', '0xff')}));
      expect(colors.textSplashed, isColor(${hexFromArgb(answers.textSplashed.argb).replaceAll('#', '0xff')}));
      expect(colors.textSplashedText, isColor(${hexFromArgb(answers.textSplashedText.argb).replaceAll('#', '0xff')}));
      ''';
      // ignore: avoid_print
      print(code);
    });

    test('generate dark mode test code', () {
      final answers = Palette.from(color, backgroundTone: 0.0);
      final code = '''
      expect(colors.color, isColor(${hexFromArgb(color.argb).replaceAll('#', '0xff')}));
      expect(colors.colorBorder, isColor(${hexFromArgb(answers.colorBorder.argb).replaceAll('#', '0xff')}));
      expect(colors.colorText, isColor(${hexFromArgb(answers.colorText.argb).replaceAll('#', '0xff')}));
      expect(colors.colorIcon, isColor(${hexFromArgb(answers.colorIcon.argb).replaceAll('#', '0xff')}));
      expect(colors.colorHovered, isColor(${hexFromArgb(answers.colorHovered.argb).replaceAll('#', '0xff')}));
      expect(colors.colorHoveredText, isColor(${hexFromArgb(answers.colorHoveredText.argb).replaceAll('#', '0xff')}));
      expect(colors.colorSplashed, isColor(${hexFromArgb(answers.colorSplashed.argb).replaceAll('#', '0xff')}));
      expect(colors.colorSplashedText, isColor(${hexFromArgb(answers.colorSplashedText.argb).replaceAll('#', '0xff')}));
      expect(colors.fill, isColor(${hexFromArgb(answers.fill.argb).replaceAll('#', '0xff')}));
      expect(colors.fillText, isColor(${hexFromArgb(answers.fillText.argb).replaceAll('#', '0xff')}));
      expect(colors.fillIcon, isColor(${hexFromArgb(answers.fillIcon.argb).replaceAll('#', '0xff')}));
      expect(colors.fillHovered, isColor(${hexFromArgb(answers.fillHovered.argb).replaceAll('#', '0xff')}));
      expect(colors.fillHoveredText, isColor(${hexFromArgb(answers.fillHoveredText.argb).replaceAll('#', '0xff')}));
      expect(colors.fillSplashed, isColor(${hexFromArgb(answers.fillSplashed.argb).replaceAll('#', '0xff')}));
      expect(colors.fillSplashedText, isColor(${hexFromArgb(answers.fillSplashedText.argb).replaceAll('#', '0xff')}));
      expect(colors.text, isColor(${hexFromArgb(answers.text.argb).replaceAll('#', '0xff')}));
      expect(colors.textHovered, isColor(${hexFromArgb(answers.textHovered.argb).replaceAll('#', '0xff')}));
      expect(colors.textHoveredText, isColor(${hexFromArgb(answers.textHoveredText.argb).replaceAll('#', '0xff')}));
      expect(colors.textSplashed, isColor(${hexFromArgb(answers.textSplashed.argb).replaceAll('#', '0xff')}));
      expect(colors.textSplashedText, isColor(${hexFromArgb(answers.textSplashedText.argb).replaceAll('#', '0xff')}));
      ''';
      // ignore: avoid_print
      print(code);
    });
  });
}
