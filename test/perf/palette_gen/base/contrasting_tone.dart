/// Base implementation: current ARGB binary search for contrasting tone.
///
/// Extracted from lib/contrast/contrast.dart — contrastingTone() APCA branch.
/// Only the APCA path is relevant; WCAG delegates to the old L*-based solver.

import 'package:libmonet/colorspaces/hct_solver.dart';
import 'package:libmonet/contrast/apca.dart';
import 'package:libmonet/contrast/contrast.dart';

/// Solve for a tone that achieves [requiredLc] APCA contrast against
/// a reference surface with ARGB [refArgb] at tone [refTone].
///
/// The solved color has HCT coordinates ([hue], [chroma], solvedTone).
double contrastingToneApca({
  required int refArgb,
  required double refTone,
  required double hue,
  required double chroma,
  required double requiredLc,
  bool? forceLighter,
}) {
  final prefersLighter = forceLighter ?? lstarPrefersLighterPair(refTone);

  int argbAt(double tone) => HctSolver.solveToInt(hue, chroma, tone);

  double lcAt(double tone) {
    final argb = argbAt(tone);
    return apcaFromArgbs(argb, refArgb).abs();
  }

  if (prefersLighter) {
    final maxLc = lcAt(100);
    if (maxLc < requiredLc) {
      if (forceLighter != null) return 100.0;
      final minLc = lcAt(0);
      return (requiredLc - minLc).abs() <= (requiredLc - maxLc).abs()
          ? 0.0
          : 100.0;
    }
    double lo = refTone, hi = 100.0;
    for (int i = 0; i < 30; i++) {
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
    double lo = 0.0, hi = refTone;
    for (int i = 0; i < 30; i++) {
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
