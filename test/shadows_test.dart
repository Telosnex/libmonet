import 'package:libmonet/contrast.dart';
import 'package:libmonet/shadows.dart';
import 'package:flutter_test/flutter_test.dart';

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
      expect(opacities, []);
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
      expect(opacities, [1.0, 1.0, 0.5718940716656867]);
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
      expect(opacities, [1.0, 0.7031085656183739]);
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
      expect(opacities, [1.0, 0.01974311408058837]);
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
      expect(opacities, [1.0, 1.0, 0.5718940716656867]);
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
      expect(opacities, [1.0, 0.7031085656183739]);
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
      expect(opacities, [1.0, 0.01974311408058837]);
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
      expect(opacities, [1.0, 0.01974311408058837]);
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
      expect(opacities, [1.0, 0.3011288882432057]);
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
      expect(opacities, []);
    });
  });
}
