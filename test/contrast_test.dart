import 'package:test/test.dart';
import 'package:libmonet/contrast.dart';

void main() {
  group('contrast ratios from percentage and usage', () {
    test('min for text', () {
      final ratio = contrastRatio(percent: 0.0, usage: Usage.text);
      expect(ratio, 1.0);
    });

    test('min for fill', () {
      final ratio = contrastRatio(percent: 0.0, usage: Usage.fill);
      expect(ratio, 1.0);
    });

    test('min-mid for text', () {
      final ratio = contrastRatio(percent: 0.25, usage: Usage.text);
      expect(ratio, 2.75);
    });

    test('min-mid for fill', () {
      final ratio = contrastRatio(percent: 0.25, usage: Usage.fill);
      expect(ratio, 2.0);
    });

    test('mid for text', () {
      final ratio = contrastRatio(percent: 0.5, usage: Usage.text);
      expect(ratio, 4.5);
    });

    test('mid for fill', () {
      final ratio = contrastRatio(percent: 0.5, usage: Usage.fill);
      expect(ratio, 3.0);
    });

    test('mid-max for text', () {
      final ratio = contrastRatio(percent: 0.75, usage: Usage.text);
      expect(ratio, 12.75);
    });

    test('mid-max for fill', () {
      final ratio = contrastRatio(percent: 0.75, usage: Usage.fill);
      expect(ratio, 12.0);
    });

    test('max for text', () {
      final ratio = contrastRatio(percent: 1.0, usage: Usage.text);
      expect(ratio, 21.0);
    });

    test('max for fill', () {
      final ratio = contrastRatio(percent: 1.0, usage: Usage.fill);
      expect(ratio, 21.0);
    });
  });

  group('contrasting L* APCA', () {
    test('darker text', () {
      final lstar = contrastingLstar(
        withLstar: 100.0,
        usage: Usage.text,
        by: Algo.apca,
        contrastPercentage: 0.5,
      );
      expect(lstar, closeTo(59.020, 0.001));
    });
    test('lighter text', () {
      final lstar = contrastingLstar(
        withLstar: 0.0,
        usage: Usage.text,
        by: Algo.apca,
        contrastPercentage: 0.5,
      );
      expect(lstar, closeTo(72.205, 0.001));
    });

    test('darker fill', () {
      final lstar = contrastingLstar(
        withLstar: 100.0,
        usage: Usage.fill,
        by: Algo.apca,
        contrastPercentage: 0.5,
      );
      expect(lstar, closeTo(73.312, 0.001));
    });

    test('lighter fill', () {
      final lstar = contrastingLstar(
        withLstar: 0.0,
        usage: Usage.fill,
        by: Algo.apca,
        contrastPercentage: 0.5,
      );
      expect(lstar, closeTo(59.788, 0.001));
    });
  });

  group('contrasting L* WCAG', () {
    test('darker text', () {
      final lstar = contrastingLstar(
        withLstar: 100.0,
        usage: Usage.text,
        by: Algo.wcag21,
        contrastPercentage: 0.5,
      );
      expect(lstar, closeTo(49.897, 0.001));
    });
    test('lighter text', () {
      final lstar = contrastingLstar(
        withLstar: 0.0,
        usage: Usage.text,
        by: Algo.wcag21,
        contrastPercentage: 0.5,
      );
      expect(lstar, closeTo(48.883, 0.001));
    });

    test('darker fill', () {
      final lstar = contrastingLstar(
        withLstar: 100.0,
        usage: Usage.fill,
        by: Algo.wcag21,
        contrastPercentage: 0.5,
      );
      expect(lstar, closeTo(61.654, 0.001));
    });
    test('lighter fill', () {
      final lstar = contrastingLstar(
        withLstar: 0.0,
        usage: Usage.fill,
        by: Algo.wcag21,
        contrastPercentage: 0.5,
      );
      expect(lstar, closeTo(37.842, 0.001));
    });
  });
}
