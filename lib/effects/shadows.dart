import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:libmonet/core/argb_srgb_xyz_lab.dart';
import 'package:libmonet/contrast/contrast.dart';
import 'package:libmonet/effects/opacity.dart';
import 'package:libmonet/util/debug_print.dart';
import 'package:libmonet/core/hex_codes.dart';
import 'package:libmonet/colorspaces/luma.dart';
import 'package:libmonet/util/alpha_neue.dart';
import 'package:libmonet/util/with_opacity_neue.dart';

class ShadowResult {
  final double blurRadius;
  
  /// ARGB of the shadow color (typically black or white).
  final int shadowArgb;
  
  /// Opacities for each shadow layer.
  final List<double> opacities;

  ShadowResult({
    required this.blurRadius,
    required this.shadowArgb,
    required this.opacities,
  });

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
          color: Color(shadowArgb).withOpacityNeue(e),
          blurRadius: blurRadius,
          offset: const Offset(0, 0),
        );
      }).toList();
    }
    _shadows = resolvedShadows;
    return _shadows!;
  }
}

/// Core shadow calculation.
///
/// Given a foreground color and a range of possible background colors,
/// calculates the shadow layers needed to ensure the foreground meets
/// the target contrast against all backgrounds.
ShadowResult getShadowOpacitiesForArgbs({
  required int foregroundArgb,
  required int minBackgroundArgb,
  required int maxBackgroundArgb,
  required double contrast,
  required Algo algo,
  required double blurRadius,
  double contentRadius = -1.0,
  bool debug = false,
}) {
  contentRadius = contentRadius <= 0.0 ? blurRadius : contentRadius;
  
  final opacityResult = getOpacityForArgbs(
    foregroundArgb: foregroundArgb,
    minBackgroundArgb: minBackgroundArgb,
    maxBackgroundArgb: maxBackgroundArgb,
    contrast: contrast,
    algo: algo,
    debug: debug,
  );
  final requiredOpacity = opacityResult.opacity;

  if (requiredOpacity == 0.0) {
    return ShadowResult(blurRadius: 0, shadowArgb: 0xFF000000, opacities: []);
  }
  if (blurRadius.round() == 0) {
    if (kDebugMode) {
      print(
          'WARNING: blurRadius is 0; without blur, shadows are not visible. Returning 0 shadows');
    }
    return ShadowResult(blurRadius: 0, shadowArgb: 0xFF000000, opacities: []);
  }
  
  monetDebug(
      debug,
      () => 'object being blurred is color ${hexFromArgb(foregroundArgb)}');
  monetDebug(
      debug,
      () => 'shadow is color ${hexFromArgb(opacityResult.protectionArgb)}');
  
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
      shadowArgb: opacityResult.protectionArgb,
      opacities: [requiredOpacity / effectiveOpacity],
    );
  }
  var bgColor = Color(minBackgroundArgb);
  final shadowColor =
      Color(opacityResult.protectionArgb).withOpacityNeue(effectiveOpacity);
  var blended = Color.alphaBlend(shadowColor, bgColor);
  assert(blended.alphaNeue == 255);
  monetDebug(
      debug,
      () =>
          'added ${Color(opacityResult.protectionArgb)} at ${(1.0 * 100).toStringAsFixed(2)}. blended: $blended. lstar: ${lstarFromArgb(blended.argb)}');

  var netOpacity = effectiveOpacity;
  final allOpacities = [1.0];
  var turns = 0;
  while (netOpacity < requiredOpacity) {
    turns++;
    final double gap = requiredOpacity - netOpacity;
    if (gap < 0.004) {
      // In rare cases, gaps of ex. 5.551115123125783e-17 were leading to this
      // loop to continue excessively and sometimes produce a NaN opacity.
      //
      // This prevents that issue, and the rationale is that if the gap is this
      // small, there would be no difference in the final answer, as we round
      // to the nearest 0.01.
      break;
    }

    final double currentEffectiveOpacity =
        effectiveOpacity * allOpacities.reduce((a, b) => a * b);
    
    // Guard against division by zero or near-zero values
    if (currentEffectiveOpacity < 1e-10 || netOpacity >= 1.0 - 1e-10) {
      break;
    }

    final double targetOpacity = 1 - (1 - requiredOpacity) / (1 - netOpacity);
    final double nextOpacity =
        math.min(targetOpacity / currentEffectiveOpacity, 1.0);
    
    // Guard against NaN or invalid opacity values from floating-point edge cases
    if (nextOpacity.isNaN || nextOpacity.isInfinite || nextOpacity <= 0) {
      break;
    }

    monetDebug(
        debug,
        () =>
            'gap is $gap. effectiveOpacity is $currentEffectiveOpacity. therefore nextOpacity is $nextOpacity');

    final shadowColor = Color(opacityResult.protectionArgb)
        .withOpacityNeue(nextOpacity * currentEffectiveOpacity);

    blended = Color.alphaBlend(shadowColor, blended);
    assert(blended.alphaNeue == 255);

    monetDebug(
        debug,
        () =>
            'added ${Color(opacityResult.protectionArgb)} at ${(nextOpacity * 100).toStringAsFixed(2)}. blended: $blended. lstar: ${lstarFromArgb(blended.argb)}');

    netOpacity += (1.0 - netOpacity) * nextOpacity * effectiveOpacity;

    allOpacities.add(nextOpacity);

    if (turns == 10) {
      break;
    }
  }
  
  final minBgLuma = lumaFromArgb(minBackgroundArgb);
  final maxBgLuma = lumaFromArgb(maxBackgroundArgb);
  final protectionLuma = lumaFromArgb(opacityResult.protectionArgb);
  final targetLuma = lumaFromArgb(argbFromLstar(opacityResult.targetLstar));
  
  final rawMath = numApplications(
      targetLuma,
      protectionLuma,
      opacityResult.protectionLstar > lstarFromArgb(minBackgroundArgb)
          ? minBgLuma
          : maxBgLuma,
      effectiveOpacity);
  monetDebug(
      debug, () => 'raw math says $rawMath, turns says ${allOpacities.length}');
  
  return ShadowResult(
    blurRadius: blurRadius,
    shadowArgb: opacityResult.protectionArgb,
    opacities: allOpacities,
  );
}

// =============================================================================
// Convenience APIs
// =============================================================================

/// Calculate shadow layers for foreground to contrast with background.
///
/// Most common case: you know both colors exactly.
ShadowResult getShadowOpacitiesForColors({
  required Color foreground,
  required Color background,
  required double contrast,
  required Algo algo,
  required double blurRadius,
  double contentRadius = -1.0,
  bool debug = false,
}) {
  return getShadowOpacitiesForArgbs(
    foregroundArgb: foreground.argb,
    minBackgroundArgb: background.argb,
    maxBackgroundArgb: background.argb,
    contrast: contrast,
    algo: algo,
    blurRadius: blurRadius,
    contentRadius: contentRadius,
    debug: debug,
  );
}

/// Calculate shadow layers that work across a set of possible backgrounds.
///
/// Use case: element over an image, sampled at multiple points.
ShadowResult getShadowOpacitiesForBackgrounds({
  required Color foreground,
  required Iterable<Color> backgrounds,
  required double contrast,
  required Algo algo,
  required double blurRadius,
  double contentRadius = -1.0,
  bool debug = false,
}) {
  // Find the backgrounds with min and max luma
  int? minLumaArgb;
  int? maxLumaArgb;
  double? minLuma;
  double? maxLuma;

  for (final bg in backgrounds) {
    final luma = lumaFromArgb(bg.argb);
    if (minLuma == null || luma < minLuma) {
      minLuma = luma;
      minLumaArgb = bg.argb;
    }
    if (maxLuma == null || luma > maxLuma) {
      maxLuma = luma;
      maxLumaArgb = bg.argb;
    }
  }

  if (minLumaArgb == null || maxLumaArgb == null) {
    throw ArgumentError('backgrounds cannot be empty');
  }

  return getShadowOpacitiesForArgbs(
    foregroundArgb: foreground.argb,
    minBackgroundArgb: minLumaArgb,
    maxBackgroundArgb: maxLumaArgb,
    contrast: contrast,
    algo: algo,
    blurRadius: blurRadius,
    contentRadius: contentRadius,
    debug: debug,
  );
}

// =============================================================================
// Deprecated L*-based API (backward compatibility)
// =============================================================================

/// Calculate shadow layers from L* values.
///
/// ⚠️ DEPRECATED: Prefer [getShadowOpacitiesForColors] for accurate results.
///
/// This converts L* to grayscale colors internally. For chromatic colors,
/// use [getShadowOpacitiesForColors] instead.
@Deprecated(
    'Use getShadowOpacitiesForColors() or getShadowOpacitiesForArgbs() for accurate results')
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
  return getShadowOpacitiesForArgbs(
    foregroundArgb: argbFromLstar(foregroundLstar),
    minBackgroundArgb: argbFromLstar(minBgLstar),
    maxBackgroundArgb: argbFromLstar(maxBgLstar),
    contrast: contrast,
    algo: algo,
    blurRadius: blurRadius,
    contentRadius: contentRadius,
    debug: debug,
  );
}

// =============================================================================
// Internal helpers
// =============================================================================

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
