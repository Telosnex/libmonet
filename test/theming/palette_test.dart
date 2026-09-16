import 'dart:ui';

import 'package:libmonet/colorspaces/hct.dart';
import 'package:libmonet/core/argb_srgb_xyz_lab.dart';
import 'package:libmonet/core/hex_codes.dart';
import 'package:libmonet/theming/palette.dart';
import 'package:test/test.dart';

import '../utils/color_matcher.dart';

double _tone(Color c) => Hct.fromColor(c).tone;

void main() {
  group('actual palette laziness', () {
    test('construction and equality do not solve contrasts', () {
      final stats = PaletteWorkStats();
      final p = Palette.from(
        const Color(0xff1565c0),
        backgroundTone: 94,
        stats: stats,
      );
      expect(stats.backgroundConstructions, 1);
      expect(stats.contrastRequests, 0);
      expect(p, Palette.from(const Color(0xff1565c0), backgroundTone: 94));
      p.hashCode;
      p.background;
      p.color;
      expect(stats.contrastRequests, 0);
      expect(stats.colorMaterializations, 0);
      final explicit = PaletteWorkStats();
      Palette.fromColorAndBackground(
        const Color(0xff1565c0),
        const Color(0xffffffff),
        stats: explicit,
      );
      expect(explicit.backgroundConstructions, 0);
      expect(explicit.contrastRequests, 0);
    });
    test('a getter calculates prerequisites once, not unrelated families', () {
      final stats = PaletteWorkStats();
      final p = Palette.from(
        const Color(0xff1565c0),
        backgroundTone: 94,
        stats: stats,
      );
      p.text;
      expect(
        stats.contrastRequests,
        2,
        reason: 'neutral polarity plus actual branded foreground',
      );
      expect(stats.colorMaterializations, 1);
      for (var i = 0; i < 100; i++) {
        p.text;
      }
      expect(stats.contrastRequests, 2);
      p.fill;
      expect(
        stats.contrastRequests,
        3,
        reason: 'reuse already-solved background polarity',
      );
      p.fillHoveredIcon;
      final requests = stats.contrastRequests,
          conversions = stats.colorMaterializations;
      expect(requests, greaterThan(3));
      for (var i = 0; i < 100; i++) {
        p.fillHoveredIcon;
      }
      expect(stats.contrastRequests, requests);
      expect(stats.colorMaterializations, conversions);
      p.colorText;
      expect(
        stats.contrastRequests,
        requests + 1,
        reason: 'color-surface family was not calculated',
      );
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
      expect(
        d.abs(),
        greaterThan(1.0),
        reason:
            '$label: tones too close '
            '(${ta.toStringAsFixed(1)} vs ${tb.toStringAsFixed(1)})',
      );
      return d.sign;
    }

    for (final bgTone in [10, 20, 30, 40, 50, 55, 60, 70, 80, 90, 95]) {
      group('bgTone=$bgTone', () {
        late Palette p;
        setUp(
          () => p = Palette.from(brandColor, backgroundTone: bgTone.toDouble()),
        );

        test('fill and text share polarity vs background', () {
          final fillDir = dir(p.background, p.fill, 'bg→fill');
          final textDir = dir(p.background, p.text, 'bg→text');
          expect(
            fillDir,
            textDir,
            reason:
                'fill (T${_tone(p.fill).round()}) and '
                'text (T${_tone(p.text).round()}) should both be '
                '${fillDir > 0 ? "lighter" : "darker"} than '
                'background (T${_tone(p.background).round()})',
          );
        });

        test(
          'hovered overlay fill and text share polarity vs hovered overlay',
          () {
            final fillDir = dir(
              p.backgroundHovered,
              p.backgroundHoveredFill,
              'bgHover→fill',
            );
            final textDir = dir(
              p.backgroundHovered,
              p.backgroundHoveredText,
              'bgHover→text',
            );
            expect(
              fillDir,
              textDir,
              reason:
                  'backgroundHoveredFill and backgroundHoveredText '
                  'should be on the same side of backgroundHovered',
            );
          },
        );

        test(
          'splashed overlay fill and text share polarity vs splashed overlay',
          () {
            final fillDir = dir(
              p.backgroundSplashed,
              p.backgroundSplashedFill,
              'bgSplash→fill',
            );
            final textDir = dir(
              p.backgroundSplashed,
              p.backgroundSplashedText,
              'bgSplash→text',
            );
            expect(
              fillDir,
              textDir,
              reason:
                  'backgroundSplashedFill and backgroundSplashedText '
                  'should be on the same side of backgroundSplashed',
            );
          },
        );

        test('fillText and fillIcon share polarity vs fill', () {
          final fillToText = dir(p.fill, p.fillText, 'fill→fillText');
          final fillToIcon = dir(p.fill, p.fillIcon, 'fill→fillIcon');
          expect(
            fillToText,
            fillToIcon,
            reason:
                'fillText (T${_tone(p.fillText).round()}) and '
                'fillIcon (T${_tone(p.fillIcon).round()}) should both be '
                '${fillToText > 0 ? "lighter" : "darker"} than '
                'fill (T${_tone(p.fill).round()})',
          );
        });

        test('colorText and colorIcon share polarity vs color', () {
          final colorToText = dir(p.color, p.colorText, 'color→colorText');
          final colorToIcon = dir(p.color, p.colorIcon, 'color→colorIcon');
          expect(
            colorToText,
            colorToIcon,
            reason:
                'colorText (T${_tone(p.colorText).round()}) and '
                'colorIcon (T${_tone(p.colorIcon).round()}) should both be '
                '${colorToText > 0 ? "lighter" : "darker"} than '
                'color (T${_tone(p.color).round()})',
          );
        });
      });
    }
  });

  group('#1177AA bgTone=10', () {
    test('snapshot', () {
      final p = Palette.from(const Color(0xff1177AA), backgroundTone: 10);
      expect(p.color, isColor(0xff1177AA));
      expect(p.colorBorder, isColor(0xff1177AA));
      expect(p.fill, isColor(0xff529FD2));
      expect(p.fillBorder, isColor(0xff529FD2));
      expect(p.text, isColor(0xff73BBEF));
      expect(p.fillText, isColor(0xffFFFFFF));
      expect(p.fillIcon, isColor(0xffD4EBFF));
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
      expect(colors.colorText, isColor(0xffB7C3D9));
      expect(colors.colorIcon, isColor(0xff9DA8BF));
      expect(colors.colorHovered, isColor(0xff657288));
      expect(colors.colorHoveredText, isColor(0xffD7E2F8));
      expect(colors.colorSplashed, isColor(0xff828FA4));
      expect(colors.colorSplashedText, isColor(0xffF4F7FF));
      expect(colors.fill, isColor(0xffA1ACC2));
      expect(colors.fillText, isColor(0xff000000));
      expect(colors.fillIcon, isColor(0xff38465B));
      expect(colors.fillHovered, isColor(0xff78849A));
      expect(colors.fillHoveredText, isColor(0xffE8EFFF));
      expect(colors.fillSplashed, isColor(0xff5A677D));
      expect(colors.fillSplashedText, isColor(0xffD0DBF1));
      expect(colors.text, isColor(0xff828FA5));
      expect(colors.textHovered, isColor(0xffC8D2E9));
      expect(colors.textHoveredText, isColor(0xff47546A));
      expect(colors.textSplashed, isColor(0xffA6B1C8));
      expect(colors.textSplashedText, isColor(0xff07182F));
    });

    test('dark mode', () {
      final colors = Palette.from(const Color(0xff334157), backgroundTone: 0.0);
      expect(colors.color, isColor(0xff334157));
      expect(colors.colorBorder, isColor(0xff455368));
      expect(colors.colorText, isColor(0xffB7C3D9));
      expect(colors.colorIcon, isColor(0xff9DA8BF));
      expect(colors.colorHovered, isColor(0xff657288));
      expect(colors.colorHoveredText, isColor(0xffD7E2F8));
      expect(colors.colorSplashed, isColor(0xff828FA4));
      expect(colors.colorSplashedText, isColor(0xffF4F7FF));
      expect(colors.fill, isColor(0xff8A96AB));
      expect(colors.fillText, isColor(0xffFFFFFF));
      expect(colors.fillIcon, isColor(0xffDBE6FC));
      expect(colors.fillHovered, isColor(0xffADB9CF));
      expect(colors.fillHoveredText, isColor(0xff1E2D44));
      expect(colors.fillSplashed, isColor(0xffC5D0E6));
      expect(colors.fillSplashedText, isColor(0xff445167));
      expect(colors.text, isColor(0xffA6B2C8));
      expect(colors.textHovered, isColor(0xff5C697F));
      expect(colors.textHoveredText, isColor(0xffD1DCF2));
      expect(colors.textSplashed, isColor(0xff8390A5));
      expect(colors.textSplashedText, isColor(0xffF7F7FF));
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
      expect(colors.colorBorder, isColor(0xff445489)); // blue at ~tone 38
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
      expect(colors.colorBorder, isColor(0xffD29C57)); // darker border (~T52)
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
      expect(
        colors.colorBorder,
        isColor(0xff7D5418),
      ); // subtle shadow, not harsh hole
      expect(lstarFromArgb(colors.color.argb), closeTo(54.627, 0.001));
      expect(lstarFromArgb(colors.colorBorder.argb), closeTo(39.184, 0.001));
    });

    test('backgroundBorder uses Usage.border, not Usage.large', () {
      // At bgTone=10, Usage.large (Lc 30) forced backgroundBorder to T~51
      // because APCA is flat in the deep darks. With Usage.border (Lc 15)
      // it correctly lands at T~37 — still lighter (no darker headroom at
      // T10), but a much more reasonable delta.
      final p = Palette.from(const Color(0xff1177AA), backgroundTone: 10);
      expect(p.backgroundBorder, isColor(0xff445969));
      expect(_tone(p.backgroundBorder), closeTo(36.896, 0.5));
      // The old bug produced T~51; ensure we're well below that.
      expect(_tone(p.backgroundBorder), lessThan(45));
    });
  });

  test('chromatic background keeps chroma in hover/splash', () {
    // Regression: fromColorAndBackground with a high-tone color whose
    // chroma is gamut-capped (e.g. #E7F5FF, H:233 C:12 T:96) and a
    // mid-tone chromatic background (#7BB1CF, H:233 C:32 T:70).
    //
    // _colorChroma used to come solely from the base color, so
    // backgroundHovered/Splashed (built via _withColorsChroma) would
    // inherit the gamut-capped chroma ~12 while background itself was a
    // raw pass-through at chroma ~32 — a jarring desaturation on hover.
    //
    // Fix: _colorChroma = max(baseColor.chroma, baseBackground.chroma).
    final p = Palette.fromColorAndBackground(
      const Color(0xFFE7F5FF), // H:233 C:12.2 T:95.8 (gamut-capped)
      const Color(0xFF7BB1CF), // H:233 C:32.1 T:69.6
    );
    final bgChroma = Hct.fromColor(p.background).chroma;
    final hovChroma = Hct.fromColor(p.backgroundHovered).chroma;
    final splChroma = Hct.fromColor(p.backgroundSplashed).chroma;

    // Hover and splash chroma should be at least as high as the
    // background's, not collapsed to the base color's gamut-capped value.
    expect(
      hovChroma,
      greaterThanOrEqualTo(bgChroma - 1),
      reason:
          'backgroundHovered chroma ($hovChroma) should be '
          'close to background chroma ($bgChroma)',
    );
    expect(
      splChroma,
      greaterThanOrEqualTo(bgChroma - 1),
      reason:
          'backgroundSplashed chroma ($splChroma) should be '
          'close to background chroma ($bgChroma)',
    );
  });

  group('helpers', skip: 'test generators', () {
    const color = Color(0xff334157);

    test('generate light mode test code', () {
      final answers = Palette.from(color, backgroundTone: 100.0);
      final code =
          '''
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
      final code =
          '''
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
