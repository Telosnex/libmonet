import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts_lite.dart';
import 'package:libmonet/fonts/font_height_equalizer.g.dart';
import 'package:libmonet/fonts/google_fonts_catalog.g.dart';

import '../../tool/generate_fonts.dart';

String descriptor(String family, {bool constant = true}) =>
    '''
    '$family': {
      ${constant ? 'const ' : ''}GoogleFontsVariant(
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.normal,
      ): ${constant ? 'const ' : ''}GoogleFontsFile(
        '${'a' * 64}',
        1234,
      ),
      const GoogleFontsVariant(
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
      ): const GoogleFontsFile(
        '${'b' * 64}',
        2345,
      ),
    },
''';

void main() {
  test('generated font data is fresh for the resolved dependency', () async {
    final result = await Process.run('dart', [
      'tool/generate_fonts.dart',
      '--check',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });

  test(
    'every resolved family has picker metadata and measured or fallback sizing',
    () {
      expect(googleFontsList, unorderedEquals(GoogleFontsLite.fontsMap.keys));
      expect(googleFontsDetails.keys, unorderedEquals(googleFontsList));
      final unavailable = <String>[];
      for (final family in googleFontsList) {
        if (rasterVisualHeightEmForFontFamily(family) == null) {
          unavailable.add(family);
          expect(visualHeightScaleForFontFamily(family), 1);
        } else {
          expect(visualHeightScaleForFontFamily(family), greaterThan(0));
        }
        final expectedVariants = GoogleFontsLite.fontsMap[family]!.keys.map(
          (v) =>
              '${v.fontWeight.value}${v.fontStyle.name == 'italic' ? 'i' : ''}',
        );
        expect(
          googleFontsDetails[family]!['variants']!.split(','),
          unorderedEquals(expectedVariants),
        );
      }
      expect(unavailable, [
        'Karla Tamil Inclined',
        'Karla Tamil Upright',
        'Khmer',
        'Molle',
        'Phetsarath',
      ]);
    },
  );

  test('parses const and non-const variant descriptors', () {
    for (final constant in [false, true]) {
      final variants = parseLiteDescriptors(
        descriptor('Example Font', constant: constant),
      )['Example Font']!;
      expect(variants.map((v) => v.pickerName), ['400', '700i']);
      expect(variants.map((v) => v.length), [1234, 2345]);
      expect(variants.first.hash, 'a' * 64);
    }
  });

  test('rejects empty, malformed, and duplicate families', () {
    expect(() => parseLiteDescriptors(''), throwsFormatException);
    expect(
      () => parseLiteDescriptors("    'Empty': {\n    },"),
      throwsFormatException,
    );
    expect(
      () => parseLiteDescriptors(descriptor('Same') + descriptor('Same')),
      throwsFormatException,
    );
    expect(
      () => parseLiteDescriptors(
        descriptor('Bad').replaceAll('1234,', 'invalid,'),
      ),
      throwsFormatException,
    );
  });

  test(
    'catalog includes new families and uses package variants, not API variants',
    () {
      final source = FontSource(
        Directory('/unused'),
        '9.0.0',
        'hash',
        parseLiteDescriptors(descriptor('New Font')),
      );
      final metadata = <String, dynamic>{
        'New Font': {
          'category': 'sans-serif',
          'subsets': ['latin'],
        },
      };
      final catalog = generateCatalog(source, metadata);
      expect(catalog, contains("'New Font'"));
      expect(catalog, contains("'variants': '400,700i'"));
      expect(catalog, contains('// Source package: google_fonts-9.0.0.'));
      expect(catalog, contains('// Source descriptor SHA-256: hash.'));
      expect(() => generateCatalog(source, {}), throwsFormatException);
    },
  );

  test(
    'package config resolution uses its own URI, not HOME or latest pub cache',
    () {
      final temporary = Directory.systemTemp.createTempSync('libmonet_fonts_');
      addTearDown(() => temporary.deleteSync(recursive: true));
      final package = Directory('${temporary.path}/resolved')..createSync();
      File('${package.path}/pubspec.yaml')
          .writeAsStringSync('version: 9.0.0\n');
      Directory('${package.path}/lib/src').createSync(recursive: true);
      File('${package.path}/lib/src/google_fonts_lite.dart')
          .writeAsStringSync(descriptor('Resolved'));
      final config = File('${temporary.path}/package_config.json')
        ..writeAsStringSync('''
{"packages":[{"name":"google_fonts","rootUri":"resolved/"}]}
''');
      final source = readFontSource(config);
      expect(source.version, '9.0.0');
      expect(source.families.keys, ['Resolved']);
      expect(source.hash, hasLength(64));
    },
  );
}
