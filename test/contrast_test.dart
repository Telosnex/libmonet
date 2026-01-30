import 'package:test/test.dart';
import 'package:libmonet/contrast/apca.dart';
import 'package:libmonet/contrast/apca_contrast.dart';
import 'package:libmonet/contrast/contrast.dart';
import 'package:libmonet/contrast/wcag.dart';

void main() {
  group('contrast ratios from percentage and usage', () {
    test('min for text', () {
      final ratio = contrastRatioInterpolation(percent: 0.0, usage: Usage.text);
      expect(ratio, 1.0);
    });

    test('min for fill', () {
      final ratio = contrastRatioInterpolation(percent: 0.0, usage: Usage.fill);
      expect(ratio, 1.0);
    });

    test('min-mid for text', () {
      final ratio =
          contrastRatioInterpolation(percent: 0.25, usage: Usage.text);
      expect(ratio, 2.75);
    });

    test('min-mid for fill', () {
      final ratio =
          contrastRatioInterpolation(percent: 0.25, usage: Usage.fill);
      expect(ratio, 2.0);
    });

    test('mid for text', () {
      final ratio = contrastRatioInterpolation(percent: 0.5, usage: Usage.text);
      expect(ratio, 4.5);
    });

    test('mid for fill', () {
      final ratio = contrastRatioInterpolation(percent: 0.5, usage: Usage.fill);
      expect(ratio, 3.0);
    });

    test('mid-max for text', () {
      final ratio =
          contrastRatioInterpolation(percent: 0.75, usage: Usage.text);
      expect(ratio, 12.75);
    });

    test('mid-max for fill', () {
      final ratio =
          contrastRatioInterpolation(percent: 0.75, usage: Usage.fill);
      expect(ratio, 12.0);
    });

    test('max for text', () {
      final ratio = contrastRatioInterpolation(percent: 1.0, usage: Usage.text);
      expect(ratio, 21.0);
    });

    test('max for fill', () {
      final ratio = contrastRatioInterpolation(percent: 1.0, usage: Usage.fill);
      expect(ratio, 21.0);
    });
  });

  group('contrasting L* min mid APCA', () {
    const contrast = 0.25;
    test('darker text', () {
      final lstar = contrastingLstar(
        withLstar: 100.0,
        usage: Usage.text,
        by: Algo.apca,
        contrast: contrast,
      );
      expect(lstar, closeTo(79.548, 0.001));
    });
    test('lighter text', () {
      final lstar = contrastingLstar(
        withLstar: 0.0,
        usage: Usage.text,
        by: Algo.apca,
        contrast: contrast,
      );
      expect(lstar, closeTo(46.686, 0.001));
    });

    test('darker fill', () {
      final lstar = contrastingLstar(
        withLstar: 100.0,
        usage: Usage.fill,
        by: Algo.apca,
        contrast: contrast,
      );
      // Changed from 86.935 after switching to unsafe functions in else branch
      expect(lstar, closeTo(86.103, 0.001));
    });

    test('lighter fill', () {
      final lstar = contrastingLstar(
        withLstar: 0.0,
        usage: Usage.fill,
        by: Algo.apca,
        contrast: contrast,
      );
      expect(lstar, closeTo(37.628, 0.001));
    });
  });

  group('contrasting L* mid max APCA', () {
    const contrast = 0.75;
    test('darker text', () {
      final lstar = contrastingLstar(
        withLstar: 100.0,
        usage: Usage.text,
        by: Algo.apca,
        contrast: contrast,
      );
      expect(lstar, closeTo(33.629, 0.001));
    });
    test('lighter text', () {
      final lstar = contrastingLstar(
        withLstar: 0.0,
        usage: Usage.text,
        by: Algo.apca,
        contrast: contrast,
      );
      expect(lstar, closeTo(86.723, 0.001));
    });

    test('darker fill', () {
      final lstar = contrastingLstar(
        withLstar: 100.0,
        usage: Usage.fill,
        by: Algo.apca,
        contrast: contrast,
      );
      // Changed from 49.478 after switching to unsafe functions in else branch
      expect(lstar, closeTo(46.475, 0.001));
    });

    test('lighter fill', () {
      final lstar = contrastingLstar(
        withLstar: 0.0,
        usage: Usage.fill,
        by: Algo.apca,
        contrast: contrast,
      );
      expect(lstar, closeTo(82.039, 0.001));
    });
  });

  group('contrasting L* APCA', () {
    test('darker text', () {
      final lstar = contrastingLstar(
        withLstar: 100.0,
        usage: Usage.text,
        by: Algo.apca,
        contrast: 0.5,
      );
      expect(lstar, closeTo(56.797, 0.001));
    });
    test('lighter text', () {
      final lstar = contrastingLstar(
        withLstar: 0.0,
        usage: Usage.text,
        by: Algo.apca,
        contrast: 0.5,
      );
      expect(lstar, closeTo(71.271, 0.001));
    });

    test('darker fill', () {
      final lstar = contrastingLstar(
        withLstar: 100.0,
        usage: Usage.fill,
        by: Algo.apca,
        contrast: 0.5,
      );
      // Changed from 73.551 after switching to unsafe functions in else branch
      expect(lstar, closeTo(72.557, 0.001));
    });

    test('lighter fill', () {
      final lstar = contrastingLstar(
        withLstar: 0.0,
        usage: Usage.fill,
        by: Algo.apca,
        contrast: 0.5,
      );
      expect(lstar, closeTo(57.540, 0.001));
    });
  });
  group('contrasting L* WCAG', () {
    test('darker text', () {
      final lstar = contrastingLstar(
        withLstar: 100.0,
        usage: Usage.text,
        by: Algo.wcag21,
        contrast: 0.5,
      );
      expect(lstar, closeTo(49.897, 0.001));
    });
    test('lighter text', () {
      final lstar = contrastingLstar(
        withLstar: 0.0,
        usage: Usage.text,
        by: Algo.wcag21,
        contrast: 0.5,
      );
      expect(lstar, closeTo(48.883, 0.001));
    });

    test('darker fill', () {
      final lstar = contrastingLstar(
        withLstar: 100.0,
        usage: Usage.fill,
        by: Algo.wcag21,
        contrast: 0.5,
      );
      expect(lstar, closeTo(61.654, 0.001));
    });
    test('lighter fill', () {
      final lstar = contrastingLstar(
        withLstar: 0.0,
        usage: Usage.fill,
        by: Algo.wcag21,
        contrast: 0.5,
      );
      expect(lstar, closeTo(37.842, 0.001));
    });
  });

  // Fallback tests: when preferred direction fails (L* out of 0-100 range),
  // return whichever of black/white gives contrast closest to desired.

  group('fallback at high L* (prefers darker, both fail)', () {
    // withLstar=85: prefers darker, but at max contrast darker goes < 0.
    // Black (~80 APCA) is closer to target 110 than white (~23 APCA).

    test('APCA text: high L* should fall back to black for max contrast', () {
      const withLstar = 85.0;
      final result = contrastingLstar(
        withLstar: withLstar,
        usage: Usage.text,
        by: Algo.apca,
        contrast: 1.0,
      );

      // Black gives ~80 APCA, white gives ~23 APCA
      // Black is closer to desired 110 APCA
      expect(result, equals(0.0));
    });

    test('APCA fill: high L* should fall back to black for max contrast', () {
      const withLstar = 85.0;

      final result = contrastingLstar(
        withLstar: withLstar,
        usage: Usage.fill,
        by: Algo.apca,
        contrast: 1.0,
      );

      expect(result, equals(0.0));
    });

    test('WCAG text: high L* should fall back to black, not white', () {
      const withLstar = 85.0;

      final result = contrastingLstar(
        withLstar: withLstar,
        usage: Usage.text,
        by: Algo.wcag21,
        contrast: 1.0,
      );

      expect(result, equals(0.0));
    });

    test('WCAG fill: high L* should fall back to black, not white', () {
      const withLstar = 85.0;

      final result = contrastingLstar(
        withLstar: withLstar,
        usage: Usage.fill,
        by: Algo.wcag21,
        contrast: 1.0,
      );

      expect(result, equals(0.0));
    });

    test('verify: APCA darker goes negative at max contrast from L*=85', () {
      expect(darkerTextLstarUnsafe(85.0, 110.0), lessThan(0));
    });

    test('verify: WCAG darker goes negative at max contrast from L*=85', () {
      expect(darkerLstarUnsafe(lstar: 85.0, contrastRatio: 21.0), lessThan(0));
    });
  });

  // ==========================================================================
  // Fallback picks option with contrast CLOSEST to desired (not L* distance)
  // ==========================================================================
  //
  // For L*=50, black and white are equidistant (both 50 L* away).
  // But they give different contrast values, so we must compare actual
  // contrast error, not L* distance.

  group('fallback uses contrast error, not L* distance', () {
    test('WCAG: L*=50 at max contrast picks black (closer to ratio 21)', () {
      // L*=50 vs black: ratio ~4.68, error from 21 = 16.3
      // L*=50 vs white: ratio ~4.48, error from 21 = 16.5
      // Black wins (16.3 < 16.5)
      final blackRatio = contrastRatioOfLstars(50, 0);
      final whiteRatio = contrastRatioOfLstars(50, 100);
      expect((21.0 - blackRatio).abs(), lessThan((21.0 - whiteRatio).abs()));

      final result = contrastingLstar(
        withLstar: 50.0,
        usage: Usage.text,
        by: Algo.wcag21,
        contrast: 1.0,
      );
      expect(result, equals(0.0));
    });

    test('APCA: L*=50 at max contrast picks white (closer to APCA 110)', () {
      // L*=50 vs black: ~30.6 APCA, error from 110 = 79.4
      // L*=50 vs white: ~71.1 APCA, error from 110 = 38.9
      // White wins (38.9 < 79.4)
      final apcaY50 = lstarToApcaY(50.0);
      final blackApca = apcaContrastOfApcaY(apcaY50, lstarToApcaY(0)).abs();
      final whiteApca = apcaContrastOfApcaY(apcaY50, lstarToApcaY(100)).abs();
      expect((110.0 - whiteApca).abs(), lessThan((110.0 - blackApca).abs()));

      final result = contrastingLstar(
        withLstar: 50.0,
        usage: Usage.text,
        by: Algo.apca,
        contrast: 1.0,
      );
      expect(result, equals(100.0));
    });

    test('WCAG: L*=50 fill at max contrast picks black', () {
      final result = contrastingLstar(
        withLstar: 50.0,
        usage: Usage.fill,
        by: Algo.wcag21,
        contrast: 1.0,
      );
      expect(result, equals(0.0));
    });

    test('APCA: L*=50 fill at max contrast picks white', () {
      final result = contrastingLstar(
        withLstar: 50.0,
        usage: Usage.fill,
        by: Algo.apca,
        contrast: 1.0,
      );
      expect(result, equals(100.0));
    });
  });
}
