import 'package:libmonet/argb_srgb_xyz_lab.dart';
import 'package:libmonet/contrast.dart';
import 'package:libmonet/debug_print.dart';
import 'package:libmonet/hex_codes.dart';
import 'package:libmonet/wcag.dart';

class OpacityResult {
  final double lstar;
  final double opacity;

  OpacityResult({required this.lstar, required this.opacity});
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
      algo.getContrastBetweenLstars(minBgLstar, foregroundLstar);
  final noProtectionContrastWithMax =
      algo.getContrastBetweenLstars(maxBgLstar, foregroundLstar);

  if (absoluteContrast <= noProtectionContrastWithMin &&
      absoluteContrast <= noProtectionContrastWithMax) {
    monetDebug(
        debug,
        () =>
            '== No protection needed, desired contrast is $absoluteContrast, min is $noProtectionContrastWithMin, max is $noProtectionContrastWithMax');
    return OpacityResult(
      lstar: foregroundLstar,
      opacity: 0.0,
    );
  } else {
    monetDebug(
        debug,
        () =>
            '== Protection needed, desired contrast is $absoluteContrast, min is $noProtectionContrastWithMin, max is $noProtectionContrastWithMax');
  }

  // 2. We need the protection layer to create contrast for `foregroundLstar`.
  // What L* will create sufficient contrast?
  final lstarAfterBlend = contrastingLstar(
    withLstar: foregroundLstar,
    usage: Usage.text,
    by: algo,
    contrast: contrast,
  );
  final lumaAfterBlend = lumaFromLstar(lstarAfterBlend);

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
  // - lP is L* of protection layer, from 0.0 to 100.0
  // - lB is L* of the background, from 0.0 to 100.0, i.e the min/max lstar.
  // - lPF is the final L* of the protection layer, the L* resulting from its
  // opacity applied to its L*.
  //
  // Let's derive a formula for O:
  // - BLENDED = O * PROTECTION + (1 - O) * BACKGROUND
  // - lPF = oP * lP + (1 - oP) * lB
  // - lPF = oP * lP + lB - oP * lB
  // - lPF - lB = oP * lP - oP * lB
  // - lPF - lB = oP * (lP - lB)
  // - (lPF - lB) / (lP - lB) = oP
  //

  // Let's find the opacity for the minimum background.
  // lPF = lstarAfterBlend
  // lB = minBgLstar
  // lP = 100.0 (maximizing L* minimizes opacity)
  // oP = (lPF - lB) / (lP - lB)
  const lPMin = 100.0;
  final lBMin = lumaFromLstar(minBgLstar);
  final lstarPFMin = lighterLstarUnsafe(
    lstar: foregroundLstar,
    contrastRatio: absoluteContrast,
  );
  final lPFMin = lumaFromLstar(lstarPFMin);
  final oPMinRaw = (lPFMin - lBMin) / (lPMin - lBMin);

  // Let's find the opacity for the maximum background.
  // lPF = lstarAfterBlend
  // lB = maxBgLstar
  // lP = 0.0 (minimizing L* minimizes opacity)
  const lPMax = 0.0;
  final lBMax = lumaFromLstar(maxBgLstar);
  final lstarPFMax = darkerLstarUnsafe(
    lstar: foregroundLstar,
    contrastRatio: absoluteContrast,
  );
  final lPFMax = lumaFromLstar(lstarPFMax);
  final oPMaxRaw = (lPFMax - lBMax) / (lPMax - lBMax);

  double? cleanRawOpacity(double rawOpacity) {
    if (rawOpacity.isInfinite || rawOpacity.isNaN) {
      return null;
    }
    final clamped = rawOpacity.clamp(0.0, 1.0);
    final ceilingedToNearestHundredth = (clamped * 100.0).ceil() / 100.0;
    return ceilingedToNearestHundredth;
  }

  final oPMin = cleanRawOpacity(oPMinRaw);
  final oPMax = cleanRawOpacity(oPMaxRaw);

  monetDebug(
      debug, () => 'lPMin: $lPMin lBMin: $lBMin luminance: $lumaAfterBlend');
  monetDebug(
      debug,
      () =>
          'opMinRaw: $oPMinRaw = ($lumaAfterBlend - $lBMin) / ($lPMin - $lBMin)');
  monetDebug(
      debug, () => 'Raw opacity required with white protection: $oPMinRaw');
  monetDebug(
      debug, () => 'lPMax: $lPMax lBMax: $lBMax luminance: $lumaAfterBlend');
  monetDebug(
      debug,
      () =>
          'opMaxRaw: $oPMaxRaw = ($lumaAfterBlend - $lBMax) / ($lPMax - $lBMax)');
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
    );
  } else if (oPMin != null && oPMax == null) {
    return OpacityResult(lstar: lPMin, opacity: oPMin);
  } else if (oPMin == null && oPMax != null) {
    return OpacityResult(lstar: lPMax, opacity: oPMax);
  } else {
    // If both are non-null, choose the one that's closer to the foreground.
    final minBgDelta = (minBgLstar - foregroundLstar).abs();
    final maxBgDelta = (maxBgLstar - foregroundLstar).abs();
    if (minBgDelta < maxBgDelta) {
      return OpacityResult(lstar: lPMin, opacity: oPMin!);
    } else {
      return OpacityResult(lstar: lPMax, opacity: oPMax!);
    }
  }
}
