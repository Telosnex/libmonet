// Performance test: HCT → ARGB (the inverse / solver direction).
//
// Generates valid (hue, chroma, tone) test cases from real sRGB colors,
// then benchmarks + profiles HctSolver.solveToInt vs optimized attempts.

// ignore_for_file: avoid_print

import 'package:libmonet/colorspaces/cam16/cam16.dart';
import 'package:libmonet/core/argb_srgb_xyz_lab.dart';

import '../perf_tester.dart';

import 'package:libmonet/colorspaces/hct_solver.dart';
import 'attempt_3/hct_to_argb.dart' as attempt;


void main() async {
  // ── Generate test cases: valid HCT triples from real sRGB colors ──
  final testCases = <(double, double, double)>[];
  // Use the same sampling as the forward test: every 4th value per channel.
  for (var r = 0; r < 256; r += 17) {
    for (var g = 0; g < 256; g += 17) {
      for (var b = 0; b < 256; b += 17) {
        final argb = 0xFF000000 | (r << 16) | (g << 8) | b;
        final cam = Cam16.fromInt(argb);
        final tone = lstarFromArgb(argb);
        testCases.add((cam.hue, cam.chroma, tone));
      }
    }
  }
  print('Test cases: ${testCases.length}');

  final tester = PerfTester<(double, double, double), int>(
    testName: 'HCT to RGB',
    testCases: testCases,
    implementation1: (args) => HctSolver.solveToInt(args.$1, args.$2, args.$3),
    implementation2: attempt.hctToArgb,
    impl1Name: 'lib/ (on disk)',
    impl2Name: 'attempt_3 (standalone)',
  );

  await tester.run(
    warmupRuns: 50,
    benchmarkRuns: 100,
    profile: true,
    profileRuns: 200,
  );
}
