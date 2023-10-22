import 'package:libmonet/contrast.dart';
import 'package:libmonet/shadows.dart';
import 'package:test/test.dart';

void main() {
  test('black BG FG 100', () {
    final opacities = getShadowOpacities(
        minBgLstar: 0,
        maxBgLstar: 0,
        foregroundLstar: 100,
        contrast: 0.5,
        algo: Algo.wcag21,
        blurRadius: 10);
    expect(opacities, []);
  });

  test('black BG FG 40', () {
    final opacities = getShadowOpacities(
        minBgLstar: 0,
        maxBgLstar: 0,
        foregroundLstar: 40,
        contrast: 0.5,
        algo: Algo.wcag21,
        blurRadius: 10,
        debug: true);
    expect(opacities, [1.0, 1.0, 0.5718940716656867]);
  });

  test('black BG FG 30', () {
    final opacities = getShadowOpacities(
        minBgLstar: 0,
        maxBgLstar: 0,
        foregroundLstar: 30,
        contrast: 0.5,
        algo: Algo.wcag21,
        blurRadius: 10,
        debug: true);
    expect(opacities, [1.0, 0.7031085656183739]);
  });

  test('white BG FG 100', () {
    final opacities = getShadowOpacities(
        minBgLstar: 100,
        maxBgLstar: 100,
        foregroundLstar: 100,
        contrast: 0.5,
        algo: Algo.wcag21,
        blurRadius: 10,
        debug: true);
    expect(opacities, [1.0, 0.01974311408058837]);
  });

  test('white BG FG 90', () {
    final opacities = getShadowOpacities(
        minBgLstar: 100,
        maxBgLstar: 100,
        foregroundLstar: 90,
        contrast: 0.5,
        algo: Algo.wcag21,
        blurRadius: 10,
        debug: true);
    expect(opacities, [1.0, 0.3011288882432057]);
  });

  test('white BG FG 0', () {
    final opacities = getShadowOpacities(
        minBgLstar: 100,
        maxBgLstar: 100,
        foregroundLstar: 0,
        contrast: 0.5,
        algo: Algo.wcag21,
        blurRadius: 10,
        debug: true);
    expect(opacities, []);
  });
}
