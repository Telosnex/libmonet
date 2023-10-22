import 'dart:math' as math;
import 'dart:ui';
import 'package:libmonet/argb_srgb_xyz_lab.dart';
import 'package:libmonet/contrast.dart';
import 'package:libmonet/debug_print.dart';
import 'package:libmonet/hex_codes.dart';
import 'package:libmonet/opacity.dart';

List<double> getShadowOpacities({
  required double minBgLstar,
  required double maxBgLstar,
  required double foregroundLstar,
  required double contrast,
  required Algo algo,
  required double blurRadius,
  bool debug = false,
}) {
  final opacityResult = getOpacity(
    minBgLstar: minBgLstar,
    maxBgLstar: maxBgLstar,
    foregroundLstar: foregroundLstar,
    contrast: contrast,
    algo: algo,
    debug: debug,
  );
  final requiredOpacity = opacityResult.opacity;

  if (requiredOpacity == 0.0) {
    return [];
  }
  monetDebug(
      debug,
      () =>
          'object being blurred is color ${hexFromArgb(argbFromLstar(foregroundLstar))}');
  monetDebug(
      debug,
      () =>
          'shadow is color ${hexFromArgb(argbFromLstar(opacityResult.lstar))}');
  final sigma = convertRadiusToSigma(blurRadius);
  final gaussians = List.generate(blurRadius.round() * 2 + 1, (index) {
    final i = index - blurRadius;
    return gauss1d(i, sigma);
  });
  final total = gaussians.reduce((a, b) => a + b);
  final normalizedGaussians = gaussians.map((e) => e / total).toList();
  // Normalized gaussians represents the percentage of each pixel that is used
  // in the blur.
  // For example, for a blur radius of 2, we expect an array of 5 elements.
  assert(normalizedGaussians.length == blurRadius.round() * 2 + 1);
  // Shadows are drawn by duplicating the shape being blurred, setting the
  // duplicated shape's color to the shadow color, then blurring.
  //
  // We will ensure the first pixel outside the shape meets contrast.
  //
  // The first pixel uses blurRadius gaussians.
  final effectiveOpacity =
      normalizedGaussians.take(blurRadius.round() + 1).reduce((a, b) => a + b);
  monetDebug(debug, () => 'effectiveOpacity: $effectiveOpacity');
  monetDebug(debug, () => 'requiredOpacity: $requiredOpacity');
  if (effectiveOpacity >= requiredOpacity) {
    return [requiredOpacity / effectiveOpacity];
  }

  var bgColor = Color(argbFromLstar(minBgLstar));
  final shadowColor =
      Color(argbFromLstar(opacityResult.lstar)).withOpacity(effectiveOpacity);
  var blended = Color.alphaBlend(shadowColor, bgColor);
  assert(blended.alpha == 255);
  monetDebug(
      debug,
      () =>
          'added ${Color(argbFromLstar(opacityResult.lstar))} at ${(1.0 * 100).toStringAsFixed(2)}. blended: $blended. lstar: ${lstarFromArgb(blended.value)}');

  var netOpacity = effectiveOpacity;
  final allOpacities = [1.0];
  var turns = 0;
  while (netOpacity < requiredOpacity) {
    turns++;
    final double gap = requiredOpacity - netOpacity;
    final double currentEffectiveOpacity =
        effectiveOpacity * allOpacities.reduce((a, b) => a * b);
    final double targetOpacity = 1 - (1 - requiredOpacity) / (1 - netOpacity);
    final double nextOpacity =
        math.min(targetOpacity / currentEffectiveOpacity, 1.0);

    monetDebug(
        debug,
        () =>
            'gap is $gap. effectiveOpacity is $currentEffectiveOpacity. therefore nextOpacity is $nextOpacity');

    final shadowColor = Color(argbFromLstar(opacityResult.lstar))
        .withOpacity(nextOpacity * currentEffectiveOpacity);

    blended = Color.alphaBlend(shadowColor, blended);
    assert(blended.alpha == 255);

    monetDebug(
        debug,
        () =>
            'added ${Color(argbFromLstar(opacityResult.lstar))} at ${(nextOpacity * 100).toStringAsFixed(2)}. blended: $blended. lstar: ${lstarFromArgb(blended.value)}');

    netOpacity += (1 - netOpacity) * nextOpacity * effectiveOpacity;

    allOpacities.add(nextOpacity);

    if (turns == 10) {
      break;
    }
  }
  return allOpacities;
}

double gauss1d(double x, double sigma) {
  return (1 / (sigma * math.sqrt(2 * math.pi))) *
      math.exp(-(x * x) / (2 * sigma * sigma));
}

// See SkBlurMask::ConvertRadiusToSigma().
// <https://github.com/google/skia/blob/bb5b77db51d2e149ee66db284903572a5aac09be/src/effects/SkBlurMask.cpp#L23>
double convertRadiusToSigma(double radius) {
  return radius > 0 ? radius * 0.57735 + 0.5 : 0;
}
