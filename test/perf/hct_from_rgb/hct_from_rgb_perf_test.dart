// ignore_for_file: avoid_print
//
// HCT-from-RGB performance benchmark.
//
// Compares the baseline (base/) implementation against an attempt folder.
// To try an optimization:
//   1. Edit any file in attempt_1/ (cam16.dart, argb_srgb_xyz_lab.dart, etc.)
//   2. Run:
//        dart run test/perf/hct_from_rgb/hct_from_rgb_perf_test.dart
//
//      With CPU profiling:
//        dart run --enable-vm-service test/perf/hct_from_rgb/hct_from_rgb_perf_test.dart
//
// To compare a different attempt, change the import below.

import 'dart:math' as math;

import '../perf_tester.dart';

import 'base/hct_from_argb.dart' as base;
import 'attempt_3/hct_from_argb.dart' as attempt;

void main() async {
  // ── Generate test colors ──────────────────────────────────────────────
  // Every possible fully-opaque RGB color (256^3 = 16,777,216).
  // That's too many for per-run overhead, so we use a large stratified
  // sample: full sweeps of edge cases + a big random block.
  final testCases = <int>[];

  // Edge cases: pure primaries, grays, near-black, near-white.
  for (var v = 0; v < 256; v++) {
    testCases.add(0xFF000000 | (v << 16));           // reds
    testCases.add(0xFF000000 | (v << 8));             // greens
    testCases.add(0xFF000000 | v);                    // blues
    testCases.add(0xFF000000 | (v << 16) | (v << 8) | v); // grays
  }

  // 50 000 random colors, seeded for reproducibility.
  final random = math.Random(42);
  for (var i = 0; i < 50000; i++) {
    testCases.add(
      0xFF000000 | (random.nextInt(256) << 16) | (random.nextInt(256) << 8) | random.nextInt(256),
    );
  }

  print('Test cases: ${testCases.length}');

  final tester = PerfTester<int, (double, double, double)>(
    testName: 'HCT from RGB',
    testCases: testCases,
    implementation1: base.hctFromArgb,
    implementation2: attempt.hctFromArgb,
    impl1Name: 'Base',
    impl2Name: 'Attempt',
    // Tolerate tiny floating-point drift from optimizations.
    equalityCheck: (a, b) {
      if (a == null || b == null) return a == b;
      return (a.$1 - b.$1).abs() < 0.01 &&
          (a.$2 - b.$2).abs() < 0.01 &&
          (a.$3 - b.$3).abs() < 0.01;
    },
  );

  await tester.run(
    warmupRuns: 50,
    benchmarkRuns: 100,
    profile: true,
    profileRuns: 500,
  );
}
