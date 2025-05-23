import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/contrast.dart';

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
      expect(lstar, closeTo(49.876, 0.001));
    });

    test('darker fill', () {
      final lstar = contrastingLstar(
        withLstar: 100.0,
        usage: Usage.fill,
        by: Algo.apca,
        contrast: contrast,
      );
      expect(lstar, closeTo(86.935, 0.001));
    });

    test('lighter fill', () {
      final lstar = contrastingLstar(
        withLstar: 0.0,
        usage: Usage.fill,
        by: Algo.apca,
        contrast: contrast,
      );
      expect(lstar, closeTo(40.970, 0.001));
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
      expect(lstar, closeTo(87.818, 0.001));
    });

    test('darker fill', () {
      final lstar = contrastingLstar(
        withLstar: 100.0,
        usage: Usage.fill,
        by: Algo.apca,
        contrast: contrast,
      );
      expect(lstar, closeTo(49.478, 0.001));
    });

    test('lighter fill', () {
      final lstar = contrastingLstar(
        withLstar: 0.0,
        usage: Usage.fill,
        by: Algo.apca,
        contrast: contrast,
      );
      expect(lstar, closeTo(83.004, 0.001));
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
      expect(lstar, closeTo(72.445, 0.001));
    });

    test('darker fill', () {
      final lstar = contrastingLstar(
        withLstar: 100.0,
        usage: Usage.fill,
        by: Algo.apca,
        contrast: 0.5,
      );
      expect(lstar, closeTo(73.551, 0.001));
    });

    test('lighter fill', () {
      final lstar = contrastingLstar(
        withLstar: 0.0,
        usage: Usage.fill,
        by: Algo.apca,
        contrast: 0.5,
      );
      expect(lstar, closeTo(60.028, 0.001));
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
}
