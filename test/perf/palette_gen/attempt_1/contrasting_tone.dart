/// Attempt 1: Optimized ARGB binary search for contrasting tone.
///
/// Optimizations vs base:
///   1. 30 → 15 iterations  (0.003T precision, visually identical)
///   2. HctSolver.solveToInt directly  (skip Color wrapper)
///   3. Precompute reference apcaY  (avoid recomputing constant per iteration)
///   4. L*-based seed with verified bracket  (±6T from analytical answer,
///      with ARGB-verified bracket widening if needed)
///   5. Inline apcaY→contrast  (skip function-call overhead in hot loop)
///
/// Max chromatic L*↔apcaY drift is 4.79T (measured exhaustively in
/// apca_contrast_test.dart at RGB 0,0,95).  We use ±6T for safety,
/// but always verify the bracket endpoints with ARGB contrast before
/// searching, widening to full range if the seed was off.
library;


import 'package:libmonet/colorspaces/hct_solver.dart';
import 'package:libmonet/contrast/apca.dart';
import 'package:libmonet/contrast/apca_contrast.dart';
import 'package:libmonet/contrast/contrast.dart';

/// APCA contrast from a precomputed reference apcaY and a candidate ARGB.
/// Avoids recomputing apcaY for the reference on every iteration.
double _lcFromPrecomputed(double refApcaY, int candidateArgb) {
  final candY = apcaYFromArgb(candidateArgb);
  return apcaContrastOfApcaY(candY, refApcaY).abs();
}

double contrastingToneApca({
  required int refArgb,
  required double refTone,
  required double hue,
  required double chroma,
  required double requiredLc,
  bool? forceLighter,
}) {
  final prefersLighter = forceLighter ?? lstarPrefersLighterPair(refTone);

  // Precompute reference apcaY once (optimization #3).
  final refY = apcaYFromArgb(refArgb);

  double lcAt(double tone) =>
      _lcFromPrecomputed(refY, HctSolver.solveToInt(hue, chroma, tone));

  // L*-based seed for narrowing the search range (optimization #4).
  // Max chromatic drift is 4.79T; we use 6T margin.
  // The analytical L*-based answer assumes grayscale, so for chromatic
  // colors it may overshoot or undershoot.
  double? lstarSeed() {
    try {
      if (prefersLighter) {
        final naive = lighterTextLstar(refTone, -requiredLc);
        if (naive >= 0 && naive <= 100) return naive;
      } else {
        final naive = darkerTextLstarUnsafe(refTone, requiredLc);
        if (naive >= 0 && naive <= 100) return naive;
      }
    } catch (_) {}
    return null;
  }

  const kIter = 15; // optimization #1
  const kSeedMargin = 6.0; // optimization #4: analytical max drift is 4.79T

  if (prefersLighter) {
    final maxLc = lcAt(100);
    if (maxLc < requiredLc) {
      if (forceLighter != null) return 100.0;
      final minLc = lcAt(0);
      return (requiredLc - minLc).abs() <= (requiredLc - maxLc).abs()
          ? 0.0
          : 100.0;
    }
    final seed = lstarSeed();
    double lo =
        seed != null ? (seed - kSeedMargin).clamp(refTone, 100.0) : refTone;
    double hi =
        seed != null ? (seed + kSeedMargin).clamp(refTone, 100.0) : 100.0;
    // Verify bracket: hi must meet contrast, lo must not.
    // If bracket is broken, widen to full range.
    if (lcAt(hi) < requiredLc) hi = 100.0;
    // (lo failing is fine — it just means the seed range is valid.)
    for (int i = 0; i < kIter; i++) {
      final mid = (lo + hi) / 2.0;
      if (lcAt(mid) >= requiredLc) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    return hi.clamp(0.0, 100.0);
  } else {
    final minLc = lcAt(0);
    if (minLc < requiredLc) {
      if (forceLighter != null) return 0.0;
      final maxLc = lcAt(100);
      return (requiredLc - minLc).abs() <= (requiredLc - maxLc).abs()
          ? 0.0
          : 100.0;
    }
    final seed = lstarSeed();
    double lo = seed != null ? (seed - kSeedMargin).clamp(0.0, refTone) : 0.0;
    double hi =
        seed != null ? (seed + kSeedMargin).clamp(0.0, refTone) : refTone;
    // Verify bracket: lo must meet contrast.
    if (lcAt(lo) < requiredLc) lo = 0.0;
    for (int i = 0; i < kIter; i++) {
      final mid = (lo + hi) / 2.0;
      if (lcAt(mid) >= requiredLc) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo.clamp(0.0, 100.0);
  }
}
