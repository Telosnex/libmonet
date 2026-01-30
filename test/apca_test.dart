import 'package:test/test.dart';
import 'package:libmonet/apca_contrast.dart';

void main() {
  group('unsafe functions return out-of-bounds when impossible', () {
    test('lighterTextLstarUnsafe returns >100 when impossible', () {
      // Light background, request even lighter text - impossible
      const backgroundLstar = 95.0;
      const contrast = -60.0;

      final result = lighterTextLstarUnsafe(backgroundLstar, contrast);

      expect(result, closeTo(125.123, 0.001));
    });

    test('darkerTextLstarUnsafe returns <0 when impossible', () {
      // Dark background, request even darker text - impossible
      const backgroundLstar = 5.0;
      const contrast = 60.0;

      final result = darkerTextLstarUnsafe(backgroundLstar, contrast);

      expect(result, closeTo(-61.231, 0.001));
    });

    test('lighterBackgroundLstarUnsafe returns >100 when impossible', () {
      // Light text, request even lighter background - impossible
      const textLstar = 95.0;
      const contrast = 60.0;

      final result = lighterBackgroundLstarUnsafe(textLstar, contrast);

      expect(result, closeTo(128.698, 0.001));
    });

    test('darkerBackgroundLstarUnsafe returns <0 when impossible', () {
      // Dark text, request even darker background - impossible
      const textLstar = 5.0;
      const contrast = -60.0;

      final result = darkerBackgroundLstarUnsafe(textLstar, contrast);

      expect(result, closeTo(-60.841, 0.001));
    });

    test('unsafe vs safe: unsafe is honest, safe falls back', () {
      const backgroundLstar = 0.0;
      const contrast = 60.0;

      final unsafeResult = darkerTextLstarUnsafe(backgroundLstar, contrast);
      final safeResult = darkerTextLstar(backgroundLstar, contrast);

      expect(unsafeResult, lessThan(0.0),
          reason: 'Unsafe should honestly report impossible');
      expect(safeResult, greaterThan(backgroundLstar),
          reason: 'Safe silently fell back to lighter');
    });
  });

  // Using APCA value 60, represents contrast for w400 (normal) text @ 18 pts.
  // Roughly equivalent to WCAG 4.5.
  // See Font Use Lookup Tables under https://git.apcacontrast.com/documentation/README
  group('lighter background', () {
    test('T0', () {
      const textLstar = 0.0;
      final backgroundLstar = lighterBackgroundLstar(textLstar, 60);
      expect(backgroundLstar, closeTo(70.304, 0.001));
    });

    test('T10', () {
      const textLstar = 10.0;
      final backgroundLstar = lighterBackgroundLstar(textLstar, 60);
      expect(backgroundLstar, closeTo(71.593, 0.001));
    });

    test('T50', () {
      const textLstar = 50.0;
      final backgroundLstar = lighterBackgroundLstar(textLstar, 60);
      expect(backgroundLstar, closeTo(93.180, 0.001));
    });

    test('T80', () {
      const textLstar = 80.0;
      final backgroundLstar = lighterBackgroundLstar(textLstar, 60);
      expect(backgroundLstar, closeTo(100.0, 0.001));
    });

    test('T90', () {
      const textLstar = 90.0;
      final backgroundLstar = lighterBackgroundLstar(textLstar, 60);
      expect(backgroundLstar, closeTo(100.0, 0.001));
    });

    test('T100', () {
      const textLstar = 100.0;
      final backgroundLstar = lighterBackgroundLstar(textLstar, 60);
      expect(backgroundLstar, closeTo(100.0, 0.001));
    });
  });

  group('darker background', () {
    test('T0', () {
      const textLstar = 0.0;
      final backgroundLstar = darkerBackgroundLstar(textLstar, -60);
      expect(backgroundLstar, closeTo(0.0, 0.001));
    });

    test('T10', () {
      const textLstar = 10.0;
      final backgroundLstar = darkerBackgroundLstar(textLstar, -60);
      expect(backgroundLstar, closeTo(0.0, 0.001));
    });

    test('T50', () {
      const textLstar = 50.0;
      final backgroundLstar = darkerBackgroundLstar(textLstar, -60);
      expect(backgroundLstar, closeTo(0.0, 0.001));
    });

    test('T80', () {
      const textLstar = 80.0;
      final backgroundLstar = darkerBackgroundLstar(textLstar, -60);
      expect(backgroundLstar, closeTo(30.399, 0.001));
    });

    test('T90', () {
      const textLstar = 90.0;
      final backgroundLstar = darkerBackgroundLstar(textLstar, -60);
      expect(backgroundLstar, closeTo(48.281, 0.001));
    });

    test('T100', () {
      const textLstar = 100.0;
      final backgroundLstar = darkerBackgroundLstar(textLstar, -60);
      expect(backgroundLstar, closeTo(63.462, 0.001));
    });
  });

  group('lighter text', () {
    test('T0', () {
      const textLstar = 0.0;
      final backgroundLstar = lighterTextLstar(textLstar, -60);
      expect(backgroundLstar, closeTo(71.271, 0.001));
    });

    test('T10', () {
      const textLstar = 10.0;
      final backgroundLstar = lighterTextLstar(textLstar, -60);
      expect(backgroundLstar, closeTo(72.236, 0.001));
    });

    test('T50', () {
      const textLstar = 50.0;
      final backgroundLstar = lighterTextLstar(textLstar, -60);
      expect(backgroundLstar, closeTo(90.450, 0.001));
    });

    test('T80', () {
      const textLstar = 80.0;
      final backgroundLstar = lighterTextLstar(textLstar, -60);
      expect(backgroundLstar, closeTo(100.0, 0.001));
    });

    test('T90', () {
      const textLstar = 90.0;
      final backgroundLstar = lighterTextLstar(textLstar, -60);
      expect(backgroundLstar, closeTo(100.0, 0.001));
    });

    test('T100', () {
      const textLstar = 100.0;
      final backgroundLstar = lighterTextLstar(textLstar, -60);
      expect(backgroundLstar, closeTo(100.0, 0.001));
    });
  });

  group('darker text', () {
    test('T0', () {
      const textLstar = 0.0;
      final backgroundLstar = darkerTextLstar(textLstar, 60);
      expect(backgroundLstar, closeTo(71.271, 0.001));
    });

    test('T10', () {
      const textLstar = 10.0;
      final backgroundLstar = darkerTextLstar(textLstar, 60);
      expect(backgroundLstar, closeTo(72.236, 0.001));
    });

    test('T50', () {
      const textLstar = 50.0;
      final backgroundLstar = darkerTextLstar(textLstar, 60);
      expect(backgroundLstar, closeTo(90.450, 0.001));
    });

    test('T80', () {
      const textLstar = 80.0;
      final backgroundLstar = darkerTextLstar(textLstar, 60);
      expect(backgroundLstar, closeTo(28.653, 0.001));
    });

    test('T90', () {
      const textLstar = 90.0;
      final backgroundLstar = darkerTextLstar(textLstar, 60);
      expect(backgroundLstar, closeTo(45.059, 0.001));
    });

    test('T100', () {
      const textLstar = 100.0;
      final backgroundLstar = darkerTextLstar(textLstar, 60);
      expect(backgroundLstar, closeTo(59.260, 0.001));
    });
  });
}
