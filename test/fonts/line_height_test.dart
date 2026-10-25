import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/libmonet.dart';
import 'package:material_ui/material_ui.dart';

/// docs/design/ADR_font_line_height.md in telosnex, I1 to I4 and I6.
void main() {
  group('lineHeightForFontFamily', () {
    test('I1: fits the ink plus the clearance, with the floor', () {
      var count = 0;
      for (final family in googleFontsList) {
        final height = lineHeightForFontFamily(family);
        final ink = latinInkForFontFamily(family);
        expect(height == null, ink == null, reason: family);
        if (height == null || ink == null) continue;
        count++;
        final scale = visualHeightScaleForFontFamily(family);
        expect(
          height,
          greaterThanOrEqualTo(
            ink.$1 + ink.$2 + kLineHeightClearance / scale - 1e-9,
          ),
          reason: family,
        );
        expect(
          height,
          greaterThanOrEqualTo(kLineHeightFloor / scale - 1e-9),
          reason: family,
        );
      }
      // I6: catches large data drift. 1,801 when written.
      expect(count, inInclusiveRange(1700, 1900));
    });

    test('the clearance is relative to the requested size', () {
      // Tenali Ramakrishna is drawn 1.55x larger than requested.
      const family = 'Tenali Ramakrishna';
      final ink = latinInkForFontFamily(family)!;
      final scale = visualHeightScaleForFontFamily(family);
      expect(scale, greaterThan(1.4));
      expect(
        lineHeightForFontFamily(family, clearance: 0.3),
        closeTo(ink.$1 + ink.$2 + 0.3 / scale, 1e-9),
      );
      expect(
        lineHeightForFontFamily(family, clearance: 0.3)! -
            lineHeightForFontFamily(family)!,
        closeTo((0.3 - kLineHeightClearance) / scale, 1e-9),
      );
    });

    test('I3: fonts without Latin letters have no height', () {
      // No `latin` subset.
      expect(lineHeightForFontFamily('Chenla'), isNull);
      expect(naturalLineHeightForFontFamily('Chenla'), isNull);
      expect(lineHeightForFontFamily('Not A Font'), isNull);
      expect(lineHeightForFontFamily(null), isNull);
    });

    test('values', () {
      expect(lineHeightForFontFamily('Mukta'), closeTo(1.20, 0.01));
      expect(lineHeightForFontFamily('Laila'), closeTo(1.35, 0.01));
      expect(
        lineHeightForFontFamily('Tenali Ramakrishna'),
        closeTo(0.69, 0.01),
      );
      // Roboto's own box is tighter than its ink plus the clearance.
      expect(lineHeightForFontFamily('Roboto'), closeTo(1.26, 0.01));
      expect(naturalLineHeightForFontFamily('Roboto'), closeTo(1.17, 0.01));
      expect(
        lineHeightForFontFamily('Mukta_500'),
        lineHeightForFontFamily('Mukta'),
      );
    });
  });

  group('patchFontLineMetrics', () {
    late ByteData tenali;
    setUpAll(() {
      tenali = ByteData.sublistView(
        File('test/assets/fonts/TenaliRamakrishna-Regular.ttf')
            .readAsBytesSync(),
      );
    });

    Future<LineMetrics> layout(String family, {double? height}) async {
      final painter = TextPainter(
        text: TextSpan(
          text: 'Hxgjp\nHxgjp',
          style: TextStyle(
            fontFamily: family,
            fontSize: 100,
            height: height,
            leadingDistribution: TextLeadingDistribution.even,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return painter.computeLineMetrics().first;
    }

    Future<void> load(String name, ByteData bytes) =>
        (FontLoader(name)..addFont(Future.value(bytes))).load();

    testWidgets('centres the line box on the Latin ink', (tester) async {
      const family = 'Tenali Ramakrishna';
      final ink = latinInkForFontFamily(family)!;
      final height = lineHeightForFontFamily(family)!;
      await tester.runAsync(() async {
        await load('TenaliOriginal', tenali);
        await load('TenaliPatched', patchFontLineMetrics(tenali, family));
      });

      final original = await layout('TenaliOriginal', height: height);
      final patched = await layout('TenaliPatched');
      final pad = (height - ink.$1 - ink.$2) / 2 * 100;

      // The same line height as TextStyle.height on the original font.
      expect(patched.height, closeTo(original.height, 1));
      // With TextStyle.height, the ascenders reach out of the line box.
      expect(original.ascent, lessThan(ink.$1 * 100));
      // Patched, the same space is above the ink as below it.
      expect(patched.ascent - ink.$1 * 100, closeTo(pad, 0.5));
      expect(patched.descent - ink.$2 * 100, closeTo(pad, 0.5));

      // Any TextStyle.height keeps the letters centred.
      final tall = await layout(
        'TenaliPatched',
        height: lineHeightForFontFamily(family, clearance: 0.5),
      );
      expect(
        (tall.ascent - ink.$1 * 100) - (tall.descent - ink.$2 * 100),
        closeTo(0, 1),
      );
    });

    test('keeps every other byte, and valid checksums', () {
      final patched = patchFontLineMetrics(tenali, 'Tenali Ramakrishna');
      expect(patched.lengthInBytes, tenali.lengthInBytes);
      var sum = 0;
      for (var i = 0; i < patched.lengthInBytes; i += 4) {
        sum = (sum + patched.getUint32(i)) & 0xffffffff;
      }
      // The whole-file checksum of a valid font.
      expect(sum, 0xB1B0AFBA);
    });

    test('returns fonts without data and non-fonts unchanged', () {
      expect(identical(patchFontLineMetrics(tenali, 'Chenla'), tenali), isTrue);
      final junk = ByteData(64);
      expect(identical(patchFontLineMetrics(junk, 'Mukta'), junk), isTrue);
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

    TextTheme create({required bool compact, double clearance = 0.08}) =>
        MonetThemeData.fromColor(
          backgroundTone: 95,
          brightness: Brightness.light,
          color: const Color(0xff3366cc),
          compactLineHeights: compact,
          lineHeightClearance: clearance,
        ).createTextTheme(typography, TextScaler.noScaling, 1.0, 1.0);

    test('I4: without compactLineHeights, each style has its natural box', () {
      final theme = create(compact: false);
      expect(theme.bodyMedium!.height, naturalLineHeightForFontFamily('Mukta'));
      expect(
        theme.labelMedium!.height,
        naturalLineHeightForFontFamily('Roboto'),
      );
    });

    test('with compactLineHeights, each style gets its font height', () {
      final theme = create(compact: true, clearance: 0.2);
      final muktaHeight = lineHeightForFontFamily('Mukta', clearance: 0.2);
      expect(theme.bodyMedium!.height, muktaHeight);
      expect(theme.titleLarge!.height, muktaHeight);
      expect(
        theme.labelMedium!.height,
        lineHeightForFontFamily('Roboto', clearance: 0.2),
      );
      expect(
        theme.bodyMedium!.leadingDistribution,
        TextLeadingDistribution.even,
      );
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
      expect(a.lineHeightClearance, kLineHeightClearance);
      expect(a.copyWith(lineHeightClearance: 0.2), isNot(a));
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
