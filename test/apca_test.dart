import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/apca_contrast.dart';

void main() {
  // Using APCA value 60, represents contrast for w400 (normal) text @ 18 pts.
  // Roughly equivalent to WCAG 4.5.
  // See Font Use Lookup Tables under https://git.apcacontrast.com/documentation/README
  group('lighter background', () {
    test('T0', () {
      const textLstar = 0.0;
      final backgroundLstar = lighterBackgroundLstar(textLstar, 60);
      expect(backgroundLstar, closeTo(71.095, 0.001));
    });

    test('T10', () {
      const textLstar = 10.0;
      final backgroundLstar = lighterBackgroundLstar(textLstar, 60);
      expect(backgroundLstar, closeTo(72.205, 0.001));
    });

    test('T50', () {
      const textLstar = 50.0;
      final backgroundLstar = lighterBackgroundLstar(textLstar, 60);
      expect(backgroundLstar, closeTo(93.398, 0.001));
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
      expect(backgroundLstar, closeTo(30.159, 0.001));
    });

    test('T90', () {
      const textLstar = 90.0;
      final backgroundLstar = darkerBackgroundLstar(textLstar, -60);
      expect(backgroundLstar, closeTo(48.041, 0.001));
    });

    test('T100', () {
      const textLstar = 100.0;
      final backgroundLstar = darkerBackgroundLstar(textLstar, -60);
      expect(backgroundLstar, closeTo(63.222, 0.001));
    });
  });

  group('lighter text', () {
    test('T0', () {
      const textLstar = 0.0;
      final backgroundLstar = lighterTextLstar(textLstar, -60);
      expect(backgroundLstar, closeTo(72.205, 0.001));
    });

    test('T10', () {
      const textLstar = 10.0;
      final backgroundLstar = lighterTextLstar(textLstar, -60);
      expect(backgroundLstar, closeTo(72.943, 0.001));
    });

    test('T50', () {
      const textLstar = 50.0;
      final backgroundLstar = lighterTextLstar(textLstar, -60);
      expect(backgroundLstar, closeTo(90.941, 0.001));
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
      expect(backgroundLstar, closeTo(72.205, 0.001));
    });

    test('T10', () {
      const textLstar = 10.0;
      final backgroundLstar = darkerTextLstar(textLstar, 60);
      expect(backgroundLstar, closeTo(72.943, 0.001));
    });

    test('T50', () {
      const textLstar = 50.0;
      final backgroundLstar = darkerTextLstar(textLstar, 60);
      expect(backgroundLstar, closeTo(90.941, 0.001));
    });

    test('T80', () {
      const textLstar = 80.0;
      final backgroundLstar = darkerTextLstar(textLstar, 60);
      expect(backgroundLstar, closeTo(28.413, 0.001));
    });

    test('T90', () {
      const textLstar = 90.0;
      final backgroundLstar = darkerTextLstar(textLstar, 60);
      expect(backgroundLstar, closeTo(44.819, 0.001));
    });

    test('T100', () {
      const textLstar = 100.0;
      final backgroundLstar = darkerTextLstar(textLstar, 60);
      expect(backgroundLstar, closeTo(59.020, 0.001));
    });
  });
}
