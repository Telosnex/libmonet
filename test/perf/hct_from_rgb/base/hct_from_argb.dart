// Entry point for this folder's HCT-from-RGB implementation.
// The perf test imports this file; edit any file in this folder to experiment.

import 'cam16.dart';
import 'argb_srgb_xyz_lab.dart';

/// Converts an ARGB int to HCT (hue, chroma, tone).
///
/// This is the hot path: Cam16.fromInt → hue/chroma, lstarFromArgb → tone.
(double hue, double chroma, double tone) hctFromArgb(int argb) {
  final cam16 = Cam16.fromInt(argb);
  return (cam16.hue, cam16.chroma, lstarFromArgb(argb));
}
