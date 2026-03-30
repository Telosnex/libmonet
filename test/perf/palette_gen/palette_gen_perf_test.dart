// Performance test: contrasting tone solver (APCA binary search).
//
// Compares attempt_1 (base) vs attempt_2 (tighter seed margin).

// ignore_for_file: avoid_print

import 'dart:math' as math;

import 'package:libmonet/colorspaces/cam16.dart';
import 'package:libmonet/core/argb_srgb_xyz_lab.dart';

import '../perf_tester.dart';

import 'attempt_1/contrasting_tone.dart' as base;
import 'attempt_2/contrasting_tone.dart' as attempt;

typedef _Input = ({
  int refArgb,
  double refTone,
  double hue,
  double chroma,
  double requiredLc,
});

void main() async {
  final rng = math.Random(42);
  final testCases = <_Input>[];

  // Sample sRGB colors, derive HCT, pick realistic APCA contrast targets.
  for (var r = 0; r < 256; r += 32) {
    for (var g = 0; g < 256; g += 32) {
      for (var b = 0; b < 256; b += 32) {
        final argb = 0xFF000000 | (r << 16) | (g << 8) | b;
        final cam = Cam16.fromInt(argb);
        final tone = lstarFromArgb(argb);
        for (final lc in [30.0, 45.0, 60.0, 75.0]) {
          testCases.add((
            refArgb: argb,
            refTone: tone,
            hue: cam.hue,
            chroma: cam.chroma,
            requiredLc: lc,
          ));
        }
      }
    }
  }

  testCases.shuffle(rng);
  print('Test cases: ${testCases.length}');

  var maxDelta = 0.0;
  var mismatchCount = 0;

  final tester = PerfTester<_Input, double>(
    testName: 'Contrasting Tone (APCA)',
    testCases: testCases,
    implementation1: (input) => base.contrastingToneApca(
      refArgb: input.refArgb,
      refTone: input.refTone,
      hue: input.hue,
      chroma: input.chroma,
      requiredLc: input.requiredLc,
    ),
    implementation2: (input) => attempt.contrastingToneApca(
      refArgb: input.refArgb,
      refTone: input.refTone,
      hue: input.hue,
      chroma: input.chroma,
      requiredLc: input.requiredLc,
    ),
    impl1Name: 'attempt_1 (margin=6.0)',
    impl2Name: 'attempt_2 (margin=5.0, no clamp)',
    equalityCheck: (a, b) {
      if (a == null && b == null) return true;
      if (a == null || b == null) return false;
      final delta = (a - b).abs();
      if (delta > 0.001) {
        if (delta > maxDelta) maxDelta = delta;
        mismatchCount++;
      }
      return delta < 0.01;
    },
  );

  attempt.resetBracketBreaks();
  await tester.run(
    warmupRuns: 50,
    benchmarkRuns: 20,
    profile: false,
  );
  print('');
  print('  Deltas > 0.001T: $mismatchCount / ${testCases.length}');
  print('  Max delta: ${maxDelta.toStringAsFixed(6)}T');
  print('  Bracket breaks (margin=4.9): ${attempt.bracketBreaks}');
}
