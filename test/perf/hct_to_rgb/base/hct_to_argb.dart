// Baseline: delegates to the library's existing HctSolver.solveToInt.
import 'package:libmonet/colorspaces/hct_solver.dart';

int hctToArgb((double hue, double chroma, double tone) hct) {
  return HctSolver.solveToInt(hct.$1, hct.$2, hct.$3);
}
