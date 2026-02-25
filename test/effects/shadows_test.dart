import 'package:libmonet/contrast/contrast.dart';
import 'package:libmonet/effects/shadows.dart';
import 'package:test/test.dart';

void main() {
  group('black BG', () {
    const minBgLstar = 0.0;
    const maxBgLstar = 0.0;
    test('FG 100', () {
      final opacities = getShadowOpacities(
        minBgLstar: minBgLstar,
        maxBgLstar: maxBgLstar,
        foregroundLstar: 100,
        contrast: 0.5,
        algo: Algo.wcag21,
        blurRadius: 10,
      );
      expect(opacities.opacities, []);
    });

    test('FG 40', () {
      final opacities = getShadowOpacities(
        minBgLstar: minBgLstar,
        maxBgLstar: maxBgLstar,
        foregroundLstar: 40,
        contrast: 0.5,
        algo: Algo.wcag21,
        blurRadius: 10,
      );
      expect(opacities.opacities, [1.0, 1.0, 1.0, 0.18541183084166843]);
    });

    test('FG 30', () {
      final opacities = getShadowOpacities(
        minBgLstar: minBgLstar,
        maxBgLstar: maxBgLstar,
        foregroundLstar: 30,
        contrast: 0.5,
        algo: Algo.wcag21,
        blurRadius: 10,
      );
      expect(opacities.opacities, [1.0, 1.0, 0.047476344013871886]);
    });
  });

  group('zebra bg', () {
    const minBgLstar = 0.0;
    const maxBgLstar = 100.0;
    test('FG 100', () {
      final opacities = getShadowOpacities(
        minBgLstar: minBgLstar,
        maxBgLstar: maxBgLstar,
        foregroundLstar: 100,
        contrast: 0.5,
        algo: Algo.wcag21,
        blurRadius: 10,
      );
      expect(opacities.opacities, [1.0, 0.34203859555706284]);
    });

    test('FG 40', () {
      final opacities = getShadowOpacities(
        minBgLstar: minBgLstar,
        maxBgLstar: maxBgLstar,
        foregroundLstar: 40,
        contrast: 0.5,
        algo: Algo.wcag21,
        blurRadius: 10,
      );
      expect(opacities.opacities, [1.0, 1.0, 1.0, 0.18541183084166843]);
    });

    test('FG 30', () {
      final opacities = getShadowOpacities(
        minBgLstar: minBgLstar,
        maxBgLstar: maxBgLstar,
        foregroundLstar: 30,
        contrast: 0.5,
        algo: Algo.wcag21,
        blurRadius: 10,
      );
      expect(opacities.opacities, [1.0, 1.0, 0.047476344013871886]);
    });

    test('FG 0', () {
      final opacities = getShadowOpacities(
        minBgLstar: minBgLstar,
        maxBgLstar: maxBgLstar,
        foregroundLstar: 100,
        contrast: 0.5,
        algo: Algo.wcag21,
        blurRadius: 10,
      );
      expect(opacities.opacities, [1.0, 0.34203859555706284]);
    });
  });

  group('white bg', () {
    const minBgLstar = 100.0;
    const maxBgLstar = 100.0;
    test('FG 100', () {
      final opacities = getShadowOpacities(
        minBgLstar: minBgLstar,
        maxBgLstar: maxBgLstar,
        foregroundLstar: 100,
        contrast: 0.5,
        algo: Algo.wcag21,
        blurRadius: 10,

      );
      expect(opacities.opacities, [1.0, 0.34203859555706284]);
    });

    test('FG 90', () {
      final opacities = getShadowOpacities(
        minBgLstar: minBgLstar,
        maxBgLstar: maxBgLstar,
        foregroundLstar: 90,
        contrast: 0.5,
        algo: Algo.wcag21,
        blurRadius: 10,
      );
      expect(opacities.opacities, [1.0, 0.6234243697196804]);
    });

    test('FG 0', () {
      final opacities = getShadowOpacities(
        minBgLstar: minBgLstar,
        maxBgLstar: maxBgLstar,
        foregroundLstar: 0,
        contrast: 0.5,
        algo: Algo.wcag21,
        blurRadius: 10,
      );
      expect(opacities.opacities, []);
    });
  });
}
