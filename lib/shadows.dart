import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:libmonet/argb_srgb_xyz_lab.dart';
import 'package:libmonet/contrast.dart';
import 'package:libmonet/debug_print.dart';
import 'package:libmonet/hex_codes.dart';
import 'package:libmonet/luma.dart';
import 'package:libmonet/opacity.dart';

class ShadowResult {
  final double blurRadius;
  final double lstar;
  final List<double> opacities;

  ShadowResult(
      {required this.blurRadius, required this.lstar, required this.opacities});

  List<Shadow>? _shadows;
  List<Shadow> get shadows {
    if (_shadows != null) {
      return _shadows!;
    }
    final List<Shadow> resolvedShadows;
    if (opacities.isEmpty) {
      resolvedShadows = [];
    } else {
      resolvedShadows = opacities.map((e) {
        return Shadow(
          color: Color(argbFromLstar(lstar)).withOpacity(e),
          blurRadius: blurRadius,
          offset: const Offset(0, 0),
        );
      }).toList();
    }
    _shadows = resolvedShadows;
    return _shadows!;
  }
}

ShadowResult getShadowOpacities({
  required double minBgLstar,
  required double maxBgLstar,
  required double foregroundLstar,
  required double contrast,
  required Algo algo,
  required double blurRadius,
  double contentRadius = -1.0,
  bool debug = false,
}) {
  contentRadius = contentRadius <= 0.0 ? blurRadius : contentRadius;
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
    return ShadowResult(blurRadius: 0, lstar: 0, opacities: []);
  }
  if (blurRadius.round() == 0) {
    if (kDebugMode) {
      print(
          'WARNING: blurRadius is 0; without blur, shadows are not visible. Returning 0 shadows');
    }
    return ShadowResult(blurRadius: 0, lstar: 0, opacities: []);
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
      normalizedGaussians.take(contentRadius.round()).reduce((a, b) => a + b);
  monetDebug(debug, () => 'effectiveOpacity: $effectiveOpacity');
  monetDebug(debug, () => 'requiredOpacity: $requiredOpacity');
  if (effectiveOpacity >= requiredOpacity) {
    return ShadowResult(
      blurRadius: blurRadius,
      lstar: opacityResult.lstar,
      opacities: [requiredOpacity / effectiveOpacity],
    );
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
    if (gap < 0.004) {
      // In rare cases, gaps of ex. 5.551115123125783e-17 were leading to this
      // loop to continue excessively and sometimes produce a NaN opacity.
      //
      // This prevents that issue, and the rationale is that if the gap is this
      // small, there would be no difference in the final answer, as we round
      // to the nearest 0.01.
      break;
    }

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

    netOpacity += (1.0 - netOpacity) * nextOpacity * effectiveOpacity;

    allOpacities.add(nextOpacity);

    if (turns == 10) {
      break;
    }
  }
  final rawMath = numApplications(
      lumaFromLstar(opacityResult.requiredLstar),
      lumaFromLstar(opacityResult.lstar),
      opacityResult.lstar > minBgLstar
          ? lumaFromLstar(minBgLstar)
          : lumaFromLstar(maxBgLstar),
      effectiveOpacity);
  monetDebug(
      true, () => 'raw math says $rawMath, turns says ${allOpacities.length}');
  return ShadowResult(
    blurRadius: blurRadius,
    lstar: opacityResult.lstar,
    opacities: allOpacities,
  );
}

double numApplications(double finalBg, double fg, double bg, double opacity) {
  return math.log((finalBg - fg) / (bg - fg)) / math.log(1.0 - opacity);
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
