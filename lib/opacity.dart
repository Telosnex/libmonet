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

  final lumaAfterProtection = lumaFromLstar(lstarAfterProtection);
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
  // lPF = lumaAfterProtection
  // lB = luma(minBgLstar)
  // lP = 100.0 (maximizing L* minimizes opacity)
  const lPMin = 100.0;
  final lBMin = lumaFromLstar(minBgLstar);
  final lstarPFMin = switch (algo) {
    (Algo.wcag21) => lighterLstarUnsafe(
        lstar: foregroundLstar, contrastRatio: absoluteContrast),
    (Algo.apca) => lighterBackgroundLstar(
        foregroundLstar,
        absoluteContrast,
      ),
  };
  final lPFMin = lumaFromLstar(lstarPFMin);
  // oP = (lPF - lB) / (lP - lB)
  final oPMinRaw = (lPFMin - lBMin) / (lPMin - lBMin);

  // Let's find the opacity for the maximum background / darkest protection.
  // lPF = lumaAfterProtection
  // lB = luma(maxBgLstar)
  // lP = 0.0 (minimizing L* minimizes opacity)
  const lPMax = 0.0;
  final lBMax = lumaFromLstar(maxBgLstar);
  final lstarPFMax = switch (algo) {
    (Algo.wcag21) => darkerLstarUnsafe(
        lstar: foregroundLstar, contrastRatio: absoluteContrast),
    (Algo.apca) => darkerBackgroundLstar(
        foregroundLstar,
        absoluteContrast,
      ),
  };
  final lPFMax = lumaFromLstar(lstarPFMax);
  // oP = (lPF - lB) / (lP - lB)
  final oPMaxRaw = (lPFMax - lBMax) / (lPMax - lBMax);

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
      () => 'lPMin: $lPMin lBMin: $lBMin luminance: $lumaAfterProtection');
  monetDebug(
      debug,
      () =>
          'opMinRaw: $oPMinRaw = ($lumaAfterProtection - $lBMin) / ($lPMin - $lBMin)');
  monetDebug(
      debug, () => 'Raw opacity required with white protection: $oPMinRaw');
  monetDebug(debug,
      () => 'lPMax: $lPMax lBMax: $lBMax luminance: $lumaAfterProtection');
  monetDebug(
      debug,
      () =>
          'opMaxRaw: $oPMaxRaw = ($lumaAfterProtection - $lBMax) / ($lPMax - $lBMax)');
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
        lstar: lPMin, opacity: oPMin, requiredLstar: lstarAfterProtection);
  } else if (oPMin == null && oPMax != null) {
    return OpacityResult(
        lstar: lPMax, opacity: oPMax, requiredLstar: lstarAfterProtection);
  } else {
    // If both are non-null, choose the one that's closer to the foreground.
    final minBgDelta = (minBgLstar - foregroundLstar).abs();
    final maxBgDelta = (maxBgLstar - foregroundLstar).abs();
    if (minBgDelta < maxBgDelta) {
      return OpacityResult(
          lstar: lPMin, opacity: oPMin!, requiredLstar: lstarAfterProtection);
    } else {
      return OpacityResult(
          lstar: lPMax, opacity: oPMax!, requiredLstar: lstarAfterProtection);
    }
  }
}
