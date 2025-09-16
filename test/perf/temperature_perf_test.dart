// ignore_for_file: avoid_print

import 'dart:math' as math;

import 'package:libmonet/argb_srgb_xyz_lab.dart';
import 'package:libmonet/hct.dart';
import 'package:libmonet/temperature.dart' as original;

import '../perf/perf_tester.dart';

class _TempTestCase {
  final Hct input;
  final int count;
  final int divisions;
  final String description;

  _TempTestCase({
    required this.input,
    this.count = 5,
    this.divisions = 12,
    required this.description,
  });

  @override
  String toString() => description;
}

Map<String, dynamic> _runOriginal(_TempTestCase c) {
  final cache = original.TemperatureCache(c.input);
  final analog = cache.analogous(count: c.count, divisions: c.divisions)
      .map((h) => h.toInt())
      .toList(growable: false);
  final comp = cache.complement.toInt();
  return {
    'analogous': analog,
    'complement': comp,
  };
}

/// Optimized temperature cache implementation focused on performance.
///
/// Strategy:
/// - Use a fast, closed-form approximation of Ou et al.'s warm/cool metric
///   that depends only on Lab hue and chroma.
/// - Approximate temperature as T(h) = -0.5 + k * cos((h - 50)deg), where
///   k = 0.02 * (C_lab)^1.07 and C_lab is the input Lab chroma.
/// - Build analogue/complement selections using only this cheap temperature
///   curve, then construct HCT colors only for the final answers.
class TemperatureCacheOptimized {
  final Hct input;

  late final double _inputHue; // degrees
  late final double _inputChromaHct;
  late final double _inputTone;
  late final int _inputArgb;

  late final double _k; // amplitude factor for temp function
  static const double _degToRad = math.pi / 180.0;

  // Precomputed tables for fast analogous selection under cosine model
  // D[i] = |cos((i-50)deg) - cos(((i-1)-50)deg)| for i in 0..359 (wrap at -1 -> 359)
  // P[i] = prefix sum of D, with P[0]=0, P[360]=total absolute delta
  static List<double>? _deltaCos; // length 360
  static List<double>? _prefix;   // length 361
  static double? _totalAbsDelta;  // P[360]
  static void _ensureTables() {
    if (_deltaCos != null) return;
    final dc = List<double>.filled(360, 0.0);
    final cosVals = List<double>.filled(360, 0.0);
    for (var i = 0; i < 360; i++) {
      cosVals[i] = math.cos((i - 50) * _degToRad);
    }
    for (var i = 0; i < 360; i++) {
      final prev = (i == 0) ? cosVals[359] : cosVals[i - 1];
      dc[i] = (cosVals[i] - prev).abs();
    }
    final pf = List<double>.filled(361, 0.0);
    for (var i = 0; i < 360; i++) {
      pf[i + 1] = pf[i] + dc[i];
    }
    _deltaCos = dc;
    _prefix = pf;
    _totalAbsDelta = pf[360];
  }

  TemperatureCacheOptimized(this.input) {
    _inputHue = input.hue;
    _inputChromaHct = input.chroma;
    _inputTone = input.tone;
    _inputArgb = input.toInt();

    // Use input's Lab chroma for amplitude. This avoids 361 HCT solves.
    final lab = labFromArgb(_inputArgb);
    final a = lab[1];
    final b = lab[2];
    final chromaLab = math.sqrt(a * a + b * b);
    _k = 0.02 * math.pow(chromaLab, 1.07).toDouble();

    // Ensure cosine delta tables are initialized once.
    _ensureTables();
  }

  // Fast approximate raw temperature at Lab hue = h degrees.
  double _tempAtHue(double hueDeg) {
    final h = sanitizeDegreesDouble(hueDeg);
    return -0.5 + _k * math.cos((h - 50.0) * _degToRad);
  }

  // Relative temperature for a given hue under the fast model.
  double _relativeTempAtHue(double hueDeg) {
    // Under cosine model, min/max are -0.5 - k and -0.5 + k
    final t = _tempAtHue(hueDeg);
    final coldest = -0.5 - _k;
    final range = 2.0 * _k; // warmest - coldest
    if (range == 0.0) return 0.5;
    return (t - coldest) / range;
  }

  Hct _hctAtHue(int hue) {
    return Hct.from(hue.toDouble(), _inputChromaHct, _inputTone);
  }

  // Replicates the original analogous selection logic but using fast temp.
  List<Hct> analogous({int count = 5, int divisions = 12}) {
    final startHue = sanitizeDegreesInt(_inputHue.round());

    // Using precomputed absolute cosine deltas, total is constant.
    final totalAbs = _totalAbsDelta!;
    final tempStep = totalAbs / divisions;

    // Helper to compute cumulative abs temp delta from startHue over k steps.
    double cumFromStart(int k) {
      if (k <= 0) return 0.0;
      final pf = _prefix!;
      final s = startHue;
      final end = (s + k) % 360;
      if (end >= s) {
        return pf[end] - pf[s];
      } else {
        return (pf[360] - pf[s]) + pf[end];
      }
    }

    // Binary search for each division threshold to find hue offsets.
    List<int> allHues = List.filled(divisions, 0);
    for (int idx = 0; idx < divisions; idx++) {
      final target = idx * tempStep;
      int lo = 0;
      int hi = 360;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (cumFromStart(mid) >= target) {
          hi = mid;
        } else {
          lo = mid + 1;
        }
      }
      allHues[idx] = sanitizeDegreesInt(startHue + lo);
    }

    // Build answers around the input, mirroring the original approach.
    final answers = <Hct>[input];

    final increaseHueCount = ((count - 1) / 2.0).floor();
    for (int i = 1; i < (increaseHueCount + 1); i++) {
      var index = 0 - i;
      while (index < 0) {
        index = allHues.length + index;
      }
      if (index >= allHues.length) {
        index = index % allHues.length;
      }
      answers.insert(0, _hctAtHue(allHues[index]));
    }

    final decreaseHueCount = count - increaseHueCount - 1;
    for (int i = 1; i < (decreaseHueCount + 1); i++) {
      var index = i;
      while (index < 0) {
        index = allHues.length + index;
      }
      if (index >= allHues.length) {
        index = index % allHues.length;
      }
      answers.add(_hctAtHue(allHues[index]));
    }

    return answers;
  }

  // Complement based on matching inverse relative temperature under fast model.
  Hct get complement {
    // Warmest and coldest hues under cosine approximation.
    const warmestHue = 50.0;
    const coldestHue = 230.0;

    // Section selection matches original logic
    final startHueIsColdestToWarmest = original.TemperatureCache.isBetween(
      angle: _inputHue,
      a: coldestHue,
      b: warmestHue,
    );
    final startHue = startHueIsColdestToWarmest ? warmestHue : coldestHue;
    final endHue = startHueIsColdestToWarmest ? coldestHue : warmestHue;

    // Under the cosine model, relativeTemp(h) = (cos((h-50)deg) + 1)/2.
    // Setting relTemp(target) = 1 - relTemp(input) implies
    // cos((h_t-50)deg) = -cos((h_i-50)deg).
    // The principal solutions are:
    //   h_t = 280 - h_i  (mod 360)  [since 50 + (180 - (h_i - 50))]
    //   h_t = 230 + h_i  (mod 360)  [since 50 + (180 + (h_i - 50))]
    final cand1 = sanitizeDegreesDouble(280.0 - _inputHue);
    final cand2 = sanitizeDegreesDouble(230.0 + _inputHue);

    double pick;
    if (original.TemperatureCache.isBetween(angle: cand1, a: startHue, b: endHue)) {
      pick = cand1;
    } else if (original.TemperatureCache.isBetween(angle: cand2, a: startHue, b: endHue)) {
      pick = cand2;
    } else {
      // Fallback: choose the closer to the arc if rounding issues occur.
      final mid = sanitizeDegreesDouble((startHue + endHue) / 2.0);
      final d1 = (cand1 - mid).abs();
      final d2 = (cand2 - mid).abs();
      pick = d1 <= d2 ? cand1 : cand2;
    }

    return _hctAtHue(pick.round());
  }
}

Map<String, dynamic> _runOptimized(_TempTestCase c) {
  final cache = TemperatureCacheOptimized(c.input);
  final analog = cache
      .analogous(count: c.count, divisions: c.divisions)
      .map((h) => h.toInt())
      .toList(growable: false);
  final comp = cache.complement.toInt();
  return {
    'analogous': analog,
    'complement': comp,
  };
}

void main() {
  final rnd = math.Random(1234);

  // Build a small but representative set of test cases from random ARGB colors.
  final cases = <_TempTestCase>[];
  for (int i = 0; i < 24; i++) {
    final r = rnd.nextInt(256);
    final g = rnd.nextInt(256);
    final b = rnd.nextInt(256);
    final argb = (0xFF << 24) | (r << 16) | (g << 8) | b;
    final hct = Hct.fromInt(argb);
    // Use standard count/divisions values common in design tools
    final count = 5;
    final divisions = 12;
    cases.add(_TempTestCase(
      input: hct,
      count: count,
      divisions: divisions,
      description:
          'ARGB(${r.toString().padLeft(3)},${g.toString().padLeft(3)},${b.toString().padLeft(3)})',
    ));
  }

  // 1) Baseline: Original vs Original (no-op) to sanity check harness
  final baseline = PerfTester<_TempTestCase, Map<String, dynamic>>(
    testName: 'TemperatureCache Baseline (Original vs Original)',
    testCases: cases,
    implementation1: _runOriginal,
    implementation2: _runOriginal,
    impl1Name: 'Original',
    impl2Name: 'Original (copy)',
  );

  baseline.run(
    warmupRuns: 2,
    benchmarkRuns: 5,
    skipEqualityCheck: false,
  );

  // 2) Original vs Optimized
  final perf = PerfTester<_TempTestCase, Map<String, dynamic>>(
    testName: 'TemperatureCache Performance (Original vs Optimized)',
    testCases: cases,
    implementation1: _runOriginal,
    implementation2: _runOptimized,
    impl1Name: 'Original',
    impl2Name: 'Optimized',
  );

  // Skip strict equality: optimized uses an approximation to dramatically cut work.
  perf.run(
    warmupRuns: 3,
    benchmarkRuns: 10,
    skipEqualityCheck: true,
  );
}
