import 'package:flutter_test/flutter_test.dart';
import 'package:monet_ui/fonts/font_height_equalizer.g.dart';
import 'package:monet_ui/fonts/optical_font_size.dart';

void main() {
  const mono = 'JetBrains Mono';

  test('same family returns the reference size', () {
    for (final family in ['Roboto', 'Antonio', 'IM Fell Great Primer', mono]) {
      expect(
        opticallyMatchedFontSize(
          referenceFontSize: 17,
          referenceFontFamily: family,
          fontFamily: family,
        ),
        closeTo(17, 1e-9),
      );
    }
  });

  test('matching an equalized role is independent of the role font', () {
    // Mirrors the role equalizer: rolePx = basePx * scale(roleFont).
    // Antonio (big x-height, shrunk) and IM Fell Great Primer (small
    // x-height, boosted) used to drag mono in opposite directions.
    const basePx = 17.0;
    final expected = basePx * visualHeightScaleForFontFamily(mono);
    for (final roleFont in [
      'Roboto',
      'Antonio',
      'Quantico',
      'Kdam Thmor Pro',
      'IM Fell Great Primer',
      'Lusitana',
      'Alice',
    ]) {
      final rolePx = basePx * visualHeightScaleForFontFamily(roleFont);
      expect(
        opticallyMatchedFontSize(
          referenceFontSize: rolePx,
          referenceFontFamily: roleFont,
          fontFamily: mono,
        ),
        closeTo(expected, 1e-9),
        reason: roleFont,
      );
    }
  });

  test('matches visual height of the reference', () {
    final px = opticallyMatchedFontSize(
      referenceFontSize: 20,
      referenceFontFamily: 'Antonio',
      fontFamily: mono,
    );
    expect(
      px * rasterVisualHeightEmForFontFamily(mono)!,
      closeTo(20 * rasterVisualHeightEmForFontFamily('Antonio')!, 1e-9),
    );
  });

  test('unknown or null families fall back to scale 1.0', () {
    expect(
      opticallyMatchedFontSize(
        referenceFontSize: 15,
        referenceFontFamily: null,
        fontFamily: 'Not A Real Font',
      ),
      15,
    );
    expect(
      opticallyMatchedFontSize(
        referenceFontSize: 15,
        referenceFontFamily: 'Not A Real Font',
        fontFamily: mono,
      ),
      closeTo(15 * visualHeightScaleForFontFamily(mono), 1e-9),
    );
  });
}
