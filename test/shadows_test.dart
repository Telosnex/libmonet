import 'package:libmonet/contrast.dart';
import 'package:libmonet/shadows.dart';
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
      expect(opacities.opacities, [1.0, 1.0, 1.0]);
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
      expect(opacities.opacities, [1.0, 0.9852060793573316]);
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
      expect(opacities.opacities, [1.0, 0.301840627819546]);
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
      expect(opacities.opacities, [1.0, 1.0, 1.0]);
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
      expect(opacities.opacities, [1.0, 0.9852060793573316]);
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
      expect(opacities.opacities, [1.0, 0.301840627819546]);
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
      expect(opacities.opacities, [1.0, 0.301840627819546]);
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
      expect(opacities.opacities, [1.0, 0.5832264019821635]);
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
