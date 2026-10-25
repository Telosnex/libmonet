import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/libmonet.dart';
import 'package:material_ui/material_ui.dart';

/// docs/design/ADR_font_line_height.md in telosnex, I1 to I4 and I6.
void main() {
  group('lineHeightForFontFamily', () {
    test('I1 and I2: fits the ink, has the floor, never increases', () {
      var changed = 0;
      for (final family in googleFontsList) {
        final height = lineHeightForFontFamily(family);
        if (height == null) continue;
        changed++;
        final key = normalizeFontFamilyForFontMetrics(family);
        final need = kLetterNeedEmByFontFamily[key]!;
        final box = kMinLineBoxEmByFontFamily[key]!;
        final scale = visualHeightScaleForFontFamily(family);
        expect(
          height,
          greaterThanOrEqualTo(need + kLineHeightClearance / scale - 1e-9),
          reason: family,
        );
        expect(
          height,
          greaterThanOrEqualTo(kLineHeightFloor / scale - 1e-9),
          reason: family,
        );
        expect(height, lessThan(box), reason: family);
      }
      // I6: catches large data drift. 890 when written.
      expect(changed, inInclusiveRange(800, 980));
    });

    test('the clearance is relative to the requested size', () {
      // Tenali Ramakrishna is drawn 1.55x larger than requested.
      const family = 'Tenali Ramakrishna';
      final key = normalizeFontFamilyForFontMetrics(family);
      final scale = visualHeightScaleForFontFamily(family);
      expect(scale, greaterThan(1.4));
      expect(
        lineHeightForFontFamily(family),
        closeTo(
          kLetterNeedEmByFontFamily[key]! + kLineHeightClearance / scale,
          1e-9,
        ),
      );
    });

    test('fonts with a line box that fits do not change', () {
      for (final family in [
        'Roboto',
        'Inter',
        'IM Fell Great Primer',
        'Lusitana',
        'Montserrat',
      ]) {
        expect(lineHeightForFontFamily(family), isNull, reason: family);
      }
    });

    test('I3: fonts without Latin letters do not change', () {
      // No `latin` subset.
      expect(lineHeightForFontFamily('Chenla'), isNull);
      expect(lineHeightForFontFamily('Not A Font'), isNull);
      expect(lineHeightForFontFamily(null), isNull);
    });

    test('tall-box fonts fit their Latin letters', () {
      expect(lineHeightForFontFamily('Mukta'), closeTo(1.20, 0.01));
      expect(lineHeightForFontFamily('Laila'), closeTo(1.35, 0.01));
      // Latin only, so its Telugu (1.25 em) does not keep it tall.
      expect(
        lineHeightForFontFamily('Tenali Ramakrishna'),
        closeTo(0.69, 0.01),
      );
      expect(
        lineHeightForFontFamily('Noto Nastaliq Urdu'),
        closeTo(1.26, 0.01),
      );
      expect(
        lineHeightForFontFamily('Mukta_500'),
        lineHeightForFontFamily('Mukta'),
      );
    });
  });

  group('createTextTheme', () {
    const mukta = TextStyle(fontFamily: 'Mukta');
    const roboto = TextStyle(fontFamily: 'Roboto');
    final textTheme = const TextTheme(
      displayLarge: mukta,
      displayMedium: mukta,
      displaySmall: mukta,
      headlineLarge: mukta,
      headlineMedium: mukta,
      headlineSmall: mukta,
      titleLarge: mukta,
      titleMedium: mukta,
      titleSmall: mukta,
      bodyLarge: mukta,
      bodyMedium: mukta,
      bodySmall: mukta,
      labelLarge: roboto,
      labelMedium: roboto,
      labelSmall: roboto,
    );
    final typography = Typography(
      black: textTheme,
      white: textTheme,
      englishLike: textTheme,
      dense: textTheme,
      tall: textTheme,
    );

    TextTheme create({required bool compact}) => MonetThemeData.fromColor(
      backgroundTone: 95,
      brightness: Brightness.light,
      color: const Color(0xff3366cc),
      compactLineHeights: compact,
    ).createTextTheme(typography, TextScaler.noScaling, 1.0, 1.0);

    test('I4: without compactLineHeights, no style has a height', () {
      final theme = create(compact: false);
      for (final style in _styles(theme)) {
        expect(style.height, isNull);
      }
    });

    test('with compactLineHeights, each style gets its font height', () {
      final theme = create(compact: true);
      final muktaHeight = lineHeightForFontFamily('Mukta');
      expect(theme.bodyMedium!.height, muktaHeight);
      expect(theme.titleLarge!.height, muktaHeight);
      expect(
        theme.bodyMedium!.leadingDistribution,
        TextLeadingDistribution.even,
      );
      // Roboto fits its box, so labels keep the natural line box.
      expect(theme.labelMedium!.height, isNull);
    });

    test('compactLineHeights defaults to true and is part of equality', () {
      final a = MonetThemeData.fromColor(
        backgroundTone: 95,
        brightness: Brightness.light,
        color: const Color(0xff3366cc),
      );
      expect(a.compactLineHeights, isTrue);
      expect(a.copyWith(compactLineHeights: false), isNot(a));
      expect(a.copyWith(compactLineHeights: false).compactLineHeights, isFalse);
    });
  });
}

List<TextStyle> _styles(TextTheme t) => [
  t.displayLarge!,
  t.displayMedium!,
  t.displaySmall!,
  t.headlineLarge!,
  t.headlineMedium!,
  t.headlineSmall!,
  t.titleLarge!,
  t.titleMedium!,
  t.titleSmall!,
  t.bodyLarge!,
  t.bodyMedium!,
  t.bodySmall!,
  t.labelLarge!,
  t.labelMedium!,
  t.labelSmall!,
];
