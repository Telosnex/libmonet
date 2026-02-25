import 'dart:ui' show Color;

import 'package:libmonet/contrast/apca_contrast.dart';
import 'package:libmonet/core/argb_srgb_xyz_lab.dart';
import 'package:libmonet/contrast/contrast.dart';
import 'package:libmonet/util/debug_print.dart';
import 'package:libmonet/core/hex_codes.dart';
import 'package:libmonet/colorspaces/luma.dart';
import 'package:libmonet/contrast/wcag.dart';

/// Result of an opacity calculation.
class OpacityResult {
  /// ARGB of the protection layer.
  final int protectionArgb;

  /// Opacity of the protection layer (0.0 to 1.0).
  final double opacity;

  /// Target L* that the protection layer achieves after blending.
  final double targetLstar;

  OpacityResult({
    required this.protectionArgb,
    required this.opacity,
    required this.targetLstar,
  });

  /// Whether a protection layer is needed at all.
  bool get needsProtection => opacity > 0.0;

  /// Protection layer as a color with opacity applied.
  Color get color {
    final r = redFromArgb(protectionArgb);
    final g = greenFromArgb(protectionArgb);
    final b = blueFromArgb(protectionArgb);
    return Color.fromARGB((opacity * 255).round(), r, g, b);
  }

  /// L* of the protection layer.
  double get protectionLstar => lstarFromArgb(protectionArgb);

  /// Luma of the protection layer (0.0 to 100.0).
  double get protectionLuma => lumaFromArgb(protectionArgb);

  // Backward compat
  @Deprecated('Use protectionLstar')
  double get lstar => protectionLstar;

  @Deprecated('Use targetLstar')
  double get requiredLstar => targetLstar;
}

const _white = 0xFFFFFFFF;
const _black = 0xFF000000;

/// Core opacity calculation.
///
/// Given a foreground color and a range of possible background colors,
/// calculates the minimum opacity needed for a protection layer (black or white)
/// to ensure the foreground meets the target contrast against all backgrounds.
OpacityResult getOpacityForArgbs({
  required int foregroundArgb,
  required int minBackgroundArgb,
  required int maxBackgroundArgb,
  required double contrast,
  required Algo algo,
  bool debug = false,
}) {
  final absoluteContrast = algo.getAbsoluteContrast(contrast, Usage.text);

  final foregroundLstar = lstarFromArgb(foregroundArgb);
  final minBgLstar = lstarFromArgb(minBackgroundArgb);
  final maxBgLstar = lstarFromArgb(maxBackgroundArgb);

  // 1. Check if we even need a protection layer.
  final contrastWithMin =
      algo.getContrastBetweenLstars(bg: minBgLstar, fg: foregroundLstar);
  final contrastWithMax =
      algo.getContrastBetweenLstars(bg: maxBgLstar, fg: foregroundLstar);

  if (absoluteContrast <= contrastWithMin &&
      absoluteContrast <= contrastWithMax) {
    monetDebug(
        debug,
        () =>
            '== No protection needed, desired contrast is $absoluteContrast, '
            'against min bg is $contrastWithMin, against max bg is $contrastWithMax');
    return OpacityResult(
      protectionArgb: foregroundArgb,
      opacity: 0.0,
      targetLstar: foregroundLstar,
    );
  }

  monetDebug(
      debug,
      () => '== Protection needed, desired contrast is $absoluteContrast, '
          'against min bg is $contrastWithMin, against max bg is $contrastWithMax');

  // 2. Try white protection (lighten bg) and black protection (darken bg).

  // White protection on darkest background (where lightening helps most)
  final whiteProt = _calculateProtection(
    protectionArgb: _white,
    backgroundArgb: minBackgroundArgb,
    foregroundLstar: foregroundLstar,
    absoluteContrast: absoluteContrast,
    algo: algo,
    lightenBackground: true,
    debug: debug,
  );

  // Black protection on lightest background (where darkening helps most)
  final blackProt = _calculateProtection(
    protectionArgb: _black,
    backgroundArgb: maxBackgroundArgb,
    foregroundLstar: foregroundLstar,
    absoluteContrast: absoluteContrast,
    algo: algo,
    lightenBackground: false,
    debug: debug,
  );

  monetDebug(debug, () => 'White protection opacity: ${whiteProt?.opacity}');
  monetDebug(debug, () => 'Black protection opacity: ${blackProt?.opacity}');

  // 3. Choose the best protection.
  final result = _chooseBestProtection(
    whiteProt: whiteProt,
    blackProt: blackProt,
    foregroundArgb: foregroundArgb,
    minBackgroundArgb: minBackgroundArgb,
    maxBackgroundArgb: maxBackgroundArgb,
    foregroundLstar: foregroundLstar,
    absoluteContrast: absoluteContrast,
    algo: algo,
    debug: debug,
  );

  return result;
}

/// Calculate protection for a specific protection color and background.
OpacityResult? _calculateProtection({
  required int protectionArgb,
  required int backgroundArgb,
  required double foregroundLstar,
  required double absoluteContrast,
  required Algo algo,
  required bool lightenBackground,
  required bool debug,
}) {
  // Calculate what L* we need the background to become
  final targetLstar = lightenBackground
      ? _lighterTargetLstar(foregroundLstar, absoluteContrast, algo)
      : _darkerTargetLstar(foregroundLstar, absoluteContrast, algo);

  if (targetLstar == null) {
    monetDebug(debug,
        () => 'No valid target L* for ${lightenBackground ? "lighter" : "darker"} protection');
    return null;
  }

  // Convert to luma for alpha blending math
  // Target is grayscale-ish (we're blending toward black or white), so L* -> luma is close
  final targetLuma = lumaFromArgb(argbFromLstar(targetLstar));
  final protectionLuma = lumaFromArgb(protectionArgb);
  final backgroundLuma = lumaFromArgb(backgroundArgb);

  // Guard against division by zero
  final denominator = protectionLuma - backgroundLuma;
  if (denominator.abs() < 1e-10) {
    monetDebug(debug,
        () => 'Protection luma equals background luma, cannot compute opacity');
    return null;
  }

  // Alpha blending: blended = α * protection + (1 - α) * background
  // Solving for α: α = (target - background) / (protection - background)
  final rawOpacity = (targetLuma - backgroundLuma) / denominator;

  // Validate opacity is in valid range
  if (rawOpacity.isNaN || rawOpacity.isInfinite || rawOpacity < 0.0) {
    monetDebug(debug, () => 'Invalid raw opacity: $rawOpacity');
    return null;
  }

  // Add 0.01 then ceiling to ensure contrast is met after RGB integer rounding.
  // Without this, edge cases can miss contrast by ~0.04 due to rounding.
  final opacity = ((rawOpacity + 0.01) * 100.0).ceil() / 100.0;
  if (opacity > 1.0) {
    monetDebug(
        debug, () => 'Opacity $opacity exceeds 1.0, protection insufficient');
    return null;
  }

  return OpacityResult(
    protectionArgb: protectionArgb,
    opacity: opacity,
    targetLstar: targetLstar,
  );
}

double? _lighterTargetLstar(
    double foregroundLstar, double contrast, Algo algo) {
  return switch (algo) {
    Algo.wcag21 =>
      lighterLstarUnsafe(lstar: foregroundLstar, contrastRatio: contrast),
    Algo.apca => lighterBackgroundLstar(foregroundLstar, contrast),
  };
}

double? _darkerTargetLstar(
    double foregroundLstar, double contrast, Algo algo) {
  return switch (algo) {
    Algo.wcag21 =>
      darkerLstarUnsafe(lstar: foregroundLstar, contrastRatio: contrast),
    Algo.apca => darkerBackgroundLstar(foregroundLstar, contrast),
  };
}

/// Verify that a protection result achieves contrast against BOTH backgrounds.
bool _protectionWorksBothSides({
  required OpacityResult prot,
  required int foregroundArgb,
  required int minBackgroundArgb,
  required int maxBackgroundArgb,
  required double absoluteContrast,
  required Algo algo,
  required bool debug,
}) {
  final foregroundLstar = lstarFromArgb(foregroundArgb);
  final protColor = prot.color;

  final minBlended = Color.alphaBlend(protColor, Color(minBackgroundArgb));
  final maxBlended = Color.alphaBlend(protColor, Color(maxBackgroundArgb));

  final contrastMin = algo.getContrastBetweenLstars(
    bg: lstarFromArgb(minBlended.argb),
    fg: foregroundLstar,
  );
  final contrastMax = algo.getContrastBetweenLstars(
    bg: lstarFromArgb(maxBlended.argb),
    fg: foregroundLstar,
  );

  monetDebug(debug, () => 'Verifying ${hexFromArgb(prot.protectionArgb)} '
      'at ${prot.opacity}: contrastMin=$contrastMin, contrastMax=$contrastMax, '
      'need=$absoluteContrast');

  return contrastMin.abs() >= absoluteContrast &&
      contrastMax.abs() >= absoluteContrast;
}

OpacityResult _chooseBestProtection({
  required OpacityResult? whiteProt,
  required OpacityResult? blackProt,
  required int foregroundArgb,
  required int minBackgroundArgb,
  required int maxBackgroundArgb,
  required double foregroundLstar,
  required double absoluteContrast,
  required Algo algo,
  required bool debug,
}) {
  // Verify each candidate works for BOTH backgrounds, not just the one
  // it was calculated against.
  final whiteValid = whiteProt != null &&
      _protectionWorksBothSides(
        prot: whiteProt,
        foregroundArgb: foregroundArgb,
        minBackgroundArgb: minBackgroundArgb,
        maxBackgroundArgb: maxBackgroundArgb,
        absoluteContrast: absoluteContrast,
        algo: algo,
        debug: debug,
      );
  final blackValid = blackProt != null &&
      _protectionWorksBothSides(
        prot: blackProt,
        foregroundArgb: foregroundArgb,
        minBackgroundArgb: minBackgroundArgb,
        maxBackgroundArgb: maxBackgroundArgb,
        absoluteContrast: absoluteContrast,
        algo: algo,
        debug: debug,
      );

  if (whiteValid && blackValid) {
    return whiteProt.opacity <= blackProt.opacity ? whiteProt : blackProt;
  } else if (whiteValid) {
    return whiteProt;
  } else if (blackValid) {
    return blackProt;
  }

  // Natural pairings didn't work for both sides. Try crossed pairings:
  // - Black protection on min background
  // - White protection on max background
  monetDebug(debug, () => 'Natural pairings failed both-sides check, trying crossed pairings');

  final blackOnMin = _calculateProtection(
    protectionArgb: _black,
    backgroundArgb: minBackgroundArgb,
    foregroundLstar: foregroundLstar,
    absoluteContrast: absoluteContrast,
    algo: algo,
    lightenBackground: false,
    debug: debug,
  );

  final whiteOnMax = _calculateProtection(
    protectionArgb: _white,
    backgroundArgb: maxBackgroundArgb,
    foregroundLstar: foregroundLstar,
    absoluteContrast: absoluteContrast,
    algo: algo,
    lightenBackground: true,
    debug: debug,
  );

  final blackOnMinValid = blackOnMin != null &&
      _protectionWorksBothSides(
        prot: blackOnMin,
        foregroundArgb: foregroundArgb,
        minBackgroundArgb: minBackgroundArgb,
        maxBackgroundArgb: maxBackgroundArgb,
        absoluteContrast: absoluteContrast,
        algo: algo,
        debug: debug,
      );
  final whiteOnMaxValid = whiteOnMax != null &&
      _protectionWorksBothSides(
        prot: whiteOnMax,
        foregroundArgb: foregroundArgb,
        minBackgroundArgb: minBackgroundArgb,
        maxBackgroundArgb: maxBackgroundArgb,
        absoluteContrast: absoluteContrast,
        algo: algo,
        debug: debug,
      );

  monetDebug(debug, () => 'Crossed: black on min = ${blackOnMin?.opacity} valid=$blackOnMinValid');
  monetDebug(debug, () => 'Crossed: white on max = ${whiteOnMax?.opacity} valid=$whiteOnMaxValid');

  if (blackOnMinValid && whiteOnMaxValid) {
    return blackOnMin.opacity <= whiteOnMax.opacity ? blackOnMin : whiteOnMax;
  } else if (blackOnMinValid) {
    return blackOnMin;
  } else if (whiteOnMaxValid) {
    return whiteOnMax;
  }

  // All pairings failed — contrast is impossible. Return best effort at 100%.
  // Pick whichever (white or black) gets closest to the target contrast.
  monetDebug(debug, () => 'All pairings failed, returning best effort at 100%');
  return _bestEffortFullOpacity(
    foregroundArgb: foregroundArgb,
    minBackgroundArgb: minBackgroundArgb,
    maxBackgroundArgb: maxBackgroundArgb,
    foregroundLstar: foregroundLstar,
    absoluteContrast: absoluteContrast,
    algo: algo,
    debug: debug,
  );
}

/// When the target contrast is impossible, return 100% opacity in whichever
/// direction (black or white) gets closest.
OpacityResult _bestEffortFullOpacity({
  required int foregroundArgb,
  required int minBackgroundArgb,
  required int maxBackgroundArgb,
  required double foregroundLstar,
  required double absoluteContrast,
  required Algo algo,
  required bool debug,
}) {
  // Evaluate white at 100% — pure white replaces the background entirely.
  final whiteContrast = algo.getContrastBetweenLstars(
    bg: 100.0,
    fg: foregroundLstar,
  ).abs();

  // Evaluate black at 100% — pure black replaces the background entirely.
  final blackContrast = algo.getContrastBetweenLstars(
    bg: 0.0,
    fg: foregroundLstar,
  ).abs();

  monetDebug(debug, () => 'Best effort: white@100% contrast=$whiteContrast, '
      'black@100% contrast=$blackContrast');

  final useWhite = whiteContrast >= blackContrast;
  return OpacityResult(
    protectionArgb: useWhite ? _white : _black,
    opacity: 1.0,
    targetLstar: useWhite ? 100.0 : 0.0,
  );
}

// =============================================================================
// Convenience APIs
// =============================================================================

/// Calculate opacity needed for foreground to contrast with background.
///
/// Most common case: you know both colors exactly.
OpacityResult getOpacityForColors({
  required Color foreground,
  required Color background,
  required double contrast,
  required Algo algo,
  bool debug = false,
}) {
  return getOpacityForArgbs(
    foregroundArgb: foreground.argb,
    minBackgroundArgb: background.argb,
    maxBackgroundArgb: background.argb,
    contrast: contrast,
    algo: algo,
    debug: debug,
  );
}

/// Calculate opacity that works across a set of possible backgrounds.
///
/// Use case: text over an image, sampled at multiple points.
OpacityResult getOpacityForBackgrounds({
  required Color foreground,
  required Iterable<Color> backgrounds,
  required double contrast,
  required Algo algo,
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

  return getOpacityForArgbs(
    foregroundArgb: foreground.argb,
    minBackgroundArgb: minLumaArgb,
    maxBackgroundArgb: maxLumaArgb,
    contrast: contrast,
    algo: algo,
    debug: debug,
  );
}

// =============================================================================
// Deprecated L*-based API (backward compatibility)
// =============================================================================

/// Calculate opacity from L* values.
///
/// ⚠️ DEPRECATED: Prefer [getOpacityForColors] for accurate results.
///
/// This converts L* to grayscale colors internally. For chromatic colors,
/// use [getOpacityForColors] instead.
@Deprecated(
    'Use getOpacityForColors() or getOpacityForArgbs() for accurate results')
OpacityResult getOpacity({
  required double minBgLstar,
  required double maxBgLstar,
  required double foregroundLstar,
  required double contrast,
  required Algo algo,
  bool debug = false,
}) {
  return getOpacityForArgbs(
    foregroundArgb: argbFromLstar(foregroundLstar),
    minBackgroundArgb: argbFromLstar(minBgLstar),
    maxBackgroundArgb: argbFromLstar(maxBgLstar),
    contrast: contrast,
    algo: algo,
    debug: debug,
  );
}
