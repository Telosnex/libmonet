import 'dart:ui' show Color;

import 'package:libmonet/apca_contrast.dart';
import 'package:libmonet/argb_srgb_xyz_lab.dart';
import 'package:libmonet/contrast.dart';
import 'package:libmonet/debug_print.dart';
import 'package:libmonet/hex_codes.dart';
import 'package:libmonet/luma.dart';

import 'package:libmonet/util/with_opacity_neue.dart';
import 'package:libmonet/wcag.dart';

class OpacityResult {
  final double lstar;
  final double opacity;
  final double requiredLstar;

  Color get color => Color(argbFromLstar(lstar)).withOpacityNeue(opacity);
  OpacityResult(
      {required this.lstar,
      required this.opacity,
      required this.requiredLstar});
}

// Need to know: min/max of BG
// | Derive                          | Given                                   |
// |---------------------------------|-----------------------------------------|
// | opacity of protection layer     | L* of protection, L* of text            |
// | L* of protection layer          | L* of protection, opacity of layer      |
// | L* of text                      | L* of protection, opacity of protection |
OpacityResult getOpacity({
  required double minBgLstar,
  required double maxBgLstar,
  required double foregroundLstar,
  required double contrast,
  required Algo algo,
  bool debug = false,
}) {
  final absoluteContrast = algo.getAbsoluteContrast(contrast, Usage.text);

  // 1. Check if we even need a protection layer.
  final noProtectionContrastWithMin =
      algo.getContrastBetweenLstars(bg: minBgLstar, fg: foregroundLstar);
  final noProtectionContrastWithMax =
      algo.getContrastBetweenLstars(bg: maxBgLstar, fg: foregroundLstar);

  if (absoluteContrast <= noProtectionContrastWithMin &&
      absoluteContrast <= noProtectionContrastWithMax) {
    monetDebug(
        debug,
        () =>
            '== No protection needed, desired contrast is $absoluteContrast, against min bg is $noProtectionContrastWithMin, against max bg is $noProtectionContrastWithMax');
    return OpacityResult(
      lstar: foregroundLstar,
      opacity: 0.0,
      requiredLstar: foregroundLstar,
    );
  } else {
    monetDebug(
        debug,
        () => '''call
    getOpacity(
      minBgLstar: $minBgLstar,
      maxBgLstar: $maxBgLstar,
      foregroundLstar: $foregroundLstar,
      contrast: $contrast,
      algo: $algo,
    );
    ''');
    monetDebug(
        debug,
        () =>
            '== Protection needed, desired contrast is $absoluteContrast, against min bg is $noProtectionContrastWithMin, against max bg is $noProtectionContrastWithMax');
  }
  final lstarAfterProtection = contrastingLstar(
    withLstar: foregroundLstar,
    usage: Usage.text,
    by: algo,
    contrast: contrast,
  );
  // 2. We need the protection layer to create contrast for `foregroundLstar`.
  // What L* will create sufficient contrast?

  
  monetDebug(debug,
      () => 'Protection needs to create L* ${lstarAfterProtection.round()}');
  // 3. Find the opacity.
  // We know the end state:
  // - A protection layer, with some opacity O and L*, and when the O and L*
  //
  // We know colors are blended linearly in RGB.
  // - For example, blending RGB 120 0 0 with opacity 25% with a background of
  //   RGB 0 0 0 leads to 0.25 * 120 + 0.75 * 0 = 30.
  //
  // Let's use the blending formula to find the opacity.
  //
  // Let's define some constants:
  // - oP is opacity of protection layer, from 0.0 to 1.0
  // - lP is luma of protection layer, from 0.0 to 100.0
  // - lB is luma of the background, from 0.0 to 100.0, i.e the min/max lstar.
  // - lPF is the final luma of the protection layer, the luma resulting from
  //   its opacity applied to its L*.
  //
  // Let's derive a formula for oP:
  // - BLENDED = O * PROTECTION + (1 - O) * BACKGROUND
  // - lPF = oP * lP + (1 - oP) * lB
  // - lPF = oP * lP + lB - oP * lB
  // - lPF - lB = oP * lP - oP * lB
  // - lPF - lB = oP * (lP - lB)
  // - (lPF - lB) / (lP - lB) = oP
  // - oP = (lPF - lB) / (lP - lB)

  // Let's find the opacity for the minimum background / lightest protection.
  // We use sRGB-encoded values because alpha blending operates in sRGB space.
  //
  // sP = sRGB value of protection layer (1.0 for white, 0.0 for black)
  // sB = sRGB value of background
  // sPF = sRGB value needed after blending to achieve target contrast
  //
  // oP = (sPF - sB) / (sP - sB)
  const lstarPMin = 100.0;
  const sPMin = 1.0; // lumaFromLstar(100.0) / 100 = 1.0 (white)
  final sBMin = lumaFromLstar(minBgLstar) / 100.0;
  final lstarPFMin = switch (algo) {
    (Algo.wcag21) => lighterLstarUnsafe(
        lstar: foregroundLstar, contrastRatio: absoluteContrast),
    (Algo.apca) => lighterBackgroundLstar(
        foregroundLstar,
        absoluteContrast,
      ),
  };
  final sPFMin = lumaFromLstar(lstarPFMin) / 100.0;
  final oPMinRaw = (sPFMin - sBMin) / (sPMin - sBMin);

  // Let's find the opacity for the maximum background / darkest protection.
  const lstarPMax = 0.0;
  const sPMax = 0.0; // lumaFromLstar(0.0) / 100 = 0.0 (black)
  final sBMax = lumaFromLstar(maxBgLstar) / 100.0;
  final lstarPFMax = switch (algo) {
    (Algo.wcag21) => darkerLstarUnsafe(
        lstar: foregroundLstar, contrastRatio: absoluteContrast),
    (Algo.apca) => darkerBackgroundLstar(
        foregroundLstar,
        absoluteContrast,
      ),
  };
  final sPFMax = lumaFromLstar(lstarPFMax) / 100.0;
  final oPMaxRaw = (sPFMax - sBMax) / (sPMax - sBMax);

  double? cleanRawOpacity(double rawOpacity) {
    if (rawOpacity.isInfinite || rawOpacity.isNaN || rawOpacity < 0) {
      return null;
    }
    final clamped = rawOpacity.clamp(0.0, 1.0);
    final ceilingedToNearestHundredth = (clamped * 100.0).ceil() / 100.0;
    return ceilingedToNearestHundredth;
  }

  final oPMin = cleanRawOpacity(oPMinRaw);
  final oPMax = cleanRawOpacity(oPMaxRaw);

  monetDebug(debug,
      () => 'sPMin: $sPMin sBMin: $sBMin sPFMin: $sPFMin');
  monetDebug(
      debug,
      () =>
          'opMinRaw: $oPMinRaw = ($sPFMin - $sBMin) / ($sPMin - $sBMin)');
  monetDebug(
      debug, () => 'Raw opacity required with white protection: $oPMinRaw');
  monetDebug(debug,
      () => 'sPMax: $sPMax sBMax: $sBMax sPFMax: $sPFMax');
  monetDebug(
      debug,
      () =>
          'opMaxRaw: $oPMaxRaw = ($sPFMax - $sBMax) / ($sPMax - $sBMax)');
  monetDebug(
      debug, () => 'Raw opacity required with black protection: $oPMaxRaw');
  monetDebug(
      debug,
      () =>
          'Opacity required with white protection: $oPMin. Goal is to hit $lstarPFMin, which is hex ${hexFromArgb(argbFromLstar(lstarPFMin))}');
  monetDebug(
      debug,
      () =>
          'Opacity required with black protection: $oPMax. Goal is to hit $lstarPFMax, which is hex ${hexFromArgb(argbFromLstar(lstarPFMax))}');

  // Ensure opacity is null if it's completely impossible.
  //
  // This occurs when the background L* is equal to the protection L*.
  // (either maxBgLo - maxBgLstar or minBgLo - minBgLstar ~= 0.0)
  //
  // Floating point precision creates equivalent cases when the background is
  // very close to the protection.
  if (oPMin == null && oPMax == null) {
    return OpacityResult(
      lstar: 0.0,
      opacity: 0.0,
      requiredLstar: lstarAfterProtection,
    );
  } else if (oPMin != null && oPMax == null) {
    return OpacityResult(
        lstar: lstarPMin, opacity: oPMin, requiredLstar: lstarAfterProtection);
  } else if (oPMin == null && oPMax != null) {
    return OpacityResult(
        lstar: lstarPMax, opacity: oPMax, requiredLstar: lstarAfterProtection);
  } else {
    // If both are non-null, choose the one that's closer to the foreground.
    // Visually, people prefer a white scrim for light content, black scrim for dark.
    final minBgDelta = (minBgLstar - foregroundLstar).abs();
    final maxBgDelta = (maxBgLstar - foregroundLstar).abs();
    if (minBgDelta < maxBgDelta) {
      return OpacityResult(
          lstar: lstarPMin, opacity: oPMin!, requiredLstar: lstarAfterProtection);
    } else {
      return OpacityResult(
          lstar: lstarPMax, opacity: oPMax!, requiredLstar: lstarAfterProtection);
    }
  }
}
