// Research/verification tool for the production shared-polarity envelope.
// Run: dart run tool/apca_tone_bounds.dart [--exhaustive] [--out=directory]
// Regenerate tables: dart run tool/apca_tone_bounds.dart --write-production
// Uses the exact libmonet CIE weights/transfer and APCA constants. No Flutter,
// tests, network access, or build_runner.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:libmonet/core/argb_srgb_xyz_lab.dart' as cie;
import 'package:libmonet/contrast/apca_tone_bounds_data.dart';

const p = 2.4;
const q = 1 / p;
const a = [0.2126729, 0.7151522, 0.0721750];
const c = [0.2126, 0.7152, 0.0722];
const whiteA = 1.0000001;
const dartTablePath = 'lib/contrast/apca_tone_bounds_data.dart';
const typescriptTablePath = 'js/src/apca-tone-bounds-data.ts';
// Exact branch selector used by libmonet's linearized(), not the rounded
// 0.0031308 inverse cutoff. Keep both one-sided limits at the tiny discontinuity.
const kneeSrgb = 0.040449936;
final kneeA = power(kneeSrgb, p);
final kneeLinearLow = kneeSrgb / 12.92;
final kneeLinearHigh = power((kneeSrgb + .055) / 1.055, p);

double power(double x, double n) => math.pow(x, n).toDouble();
double dot(List<double> x, List<double> w) =>
    x[0] * w[0] + x[1] * w[1] + x[2] * w[2];

class Witness {
  Witness(this.value, List<double> srgb) : srgb = List.unmodifiable(srgb);
  final double value;
  // Floating normalized sRGB, NOT rounded bytes.
  final List<double> srgb;
  Map<String, Object> toJson() => {'value': value, 'srgb': srgb};
}

class Bounds {
  Bounds(this.lower, this.upper);
  final Witness lower, upper;
  double get width => upper.value - lower.value;
  Map<String, Object> toJson() => {
    'lower': lower.toJson(),
    'upper': upper.toJson(),
    'width': width,
  };
}

/// Each branch is strictly convex in linear light (forward), strictly concave
/// in channel^2.4 (reverse). Splitting all 8 channel branch combinations avoids
/// incorrectly assuming global convexity across sRGB's derivative discontinuity.
class Branch {
  Branch(this.forward, this.high);
  final bool forward, high;
  double get lo => high ? (forward ? kneeLinearHigh : kneeA) : 0;
  double get hi => high ? 1 : (forward ? kneeLinearLow : kneeA);
  double srgb(double x) =>
      forward ? (high ? 1.055 * power(x, q) - .055 : 12.92 * x) : power(x, q);
  double value(double x) {
    if (forward) return power(srgb(x).clamp(0, 1), p);
    return high ? power((power(x, q) + .055) / 1.055, p) : power(x, q) / 12.92;
  }

  double derivative(double x) {
    if (forward) {
      return high
          ? 1.055 * power(1.055 - .055 * power(x, -q), p - 1)
          : p * power(12.92, p) * power(x, p - 1);
    }
    if (x == 0) return double.infinity;
    return high
        ? power(1 + .055 * power(x, -q), p - 1) / power(1.055, p)
        : q / 12.92 * power(x, q - 1);
  }

  double atDerivative(double d) {
    if (forward) {
      if (d <= derivative(lo)) return lo;
      if (d >= derivative(hi)) return hi;
      return high
          ? power(.055 / (1.055 - power(d / 1.055, 1 / (p - 1))), p)
          : power(d / (p * power(12.92, p)), 1 / (p - 1));
    }
    if (d >= derivative(lo)) return lo;
    if (d <= derivative(hi)) return hi;
    return high
        ? power(.055 / (power(d * power(1.055, p), 1 / (p - 1)) - 1), p)
        : power(d * 12.92 / q, 1 / (q - 1));
  }
}

/// Fix sum(inputWeights * x) and bound sum(outputWeights * branch(x)).
/// Convex minimum / concave maximum: KKT, one multiplier, monotone bisection.
/// Opposite extreme: vertices of each box/plane intersection (two fixed axes).
Bounds envelope(double target, {required bool forward}) {
  final input = forward ? c : a;
  final output = forward ? a : c;
  final maxInput = forward ? 1.0 : whiteA;
  if (!target.isFinite || target < 0 || target > maxInput) {
    throw ArgumentError.value(target);
  }
  if (target == 0) return Bounds(Witness(0, [0, 0, 0]), Witness(0, [0, 0, 0]));
  if (target == maxInput) {
    final w = Witness(forward ? whiteA : 1.0, [1, 1, 1]);
    return Bounds(w, w);
  }
  Witness? lower, upper;
  void record(List<double> x, List<Branch> branches) {
    final value = dot([
      for (var i = 0; i < 3; i++) branches[i].value(x[i]),
    ], output);
    final srgb = [for (var i = 0; i < 3; i++) branches[i].srgb(x[i])];
    if (lower == null || value < lower!.value) lower = Witness(value, srgb);
    if (upper == null || value > upper!.value) upper = Witness(value, srgb);
  }

  for (var mask = 0; mask < 8; mask++) {
    final branches = [
      for (var i = 0; i < 3; i++) Branch(forward, (mask & (1 << i)) != 0),
    ];
    final low = [for (final b in branches) b.lo];
    final high = [for (final b in branches) b.hi];
    final minInput = dot(low, input), maxInput = dot(high, input);
    if (target < minInput || target > maxInput) continue;
    // Enumerate every clipped box/plane vertex, without RGB quantization.
    for (var free = 0; free < 3; free++) {
      final j = (free + 1) % 3, k = (free + 2) % 3;
      for (var corners = 0; corners < 4; corners++) {
        final x = List<double>.filled(3, 0);
        x[j] = corners & 1 == 0 ? low[j] : high[j];
        x[k] = corners & 2 == 0 ? low[k] : high[k];
        x[free] = (target - input[j] * x[j] - input[k] * x[k]) / input[free];
        if (x[free] < low[free] - 2e-15 || x[free] > high[free] + 2e-15) {
          continue;
        }
        x[free] = x[free].clamp(low[free], high[free]);
        record(x, branches);
      }
    }
    List<double> atLambda(double lambda) => [
      for (var i = 0; i < 3; i++)
        branches[i]
            .atDerivative(lambda * input[i] / output[i])
            .clamp(low[i], high[i]),
    ];
    // Forward sum increases with lambda; reverse sum decreases.
    var l = 0.0, r = 2.0;
    while (forward
        ? dot(atLambda(r), input) < target
        : dot(atLambda(r), input) > target) {
      r *= 2;
    }
    for (var iteration = 0; iteration < 64; iteration++) {
      final mid = (l + r) / 2;
      final sum = dot(atLambda(mid), input);
      if (forward ? sum < target : sum > target) {
        l = mid;
      } else {
        r = mid;
      }
    }
    record(atLambda((l + r) / 2), branches);
  }
  if (lower == null || upper == null) {
    throw StateError('No feasible branches: $target');
  }
  return Bounds(lower!, upper!);
}

Bounds atTone(double tone) =>
    envelope(cie.yFromLstar(tone) / 100, forward: true);
Bounds tonesAtApca(double apca) {
  final b = envelope(apca, forward: false);
  return Bounds(
    Witness(cie.lstarFromY(b.lower.value * 100), b.lower.srgb),
    Witness(cie.lstarFromY(b.upper.value * 100), b.upper.srgb),
  );
}

// APCA core, kept literal here so this standalone research tool does not import
// dart:ui. verifySourceConstants checks the corresponding production definitions.
double contrast(double text, double bg) {
  double black(double v) => v > .022 ? v : v + power(.022 - v, 1.414);
  text = black(text);
  bg = black(bg);
  if ((bg - text).abs() < .0005) return 0;
  if (bg > text) {
    final raw = (power(bg, .56) - power(text, .57)) * 1.14;
    return raw < .1 ? 0 : (raw - .027) * 100;
  }
  final raw = (power(bg, .65) - power(text, .62)) * 1.14;
  return raw > -.1 ? 0 : (raw + .027) * 100;
}

double actualA(List<double> srgb) =>
    dot([for (final s in srgb) power(s, p)], a);
double actualY(List<double> srgb) => dot(srgb.map(cie.linearized).toList(), c);
double grayA(double tone) =>
    whiteA * power(cie.delinearized(cie.yFromLstar(tone) / 100).clamp(0, 1), p);

/// Monotonicity of signed APCA gives tight extrema for independently chosen
/// foreground/background colors at two tones. Low-clip can create holes in the
/// attainable values; this is an enclosing interval, not a promise every
/// intermediate Lc occurs. Negative is light text on dark background.
(double, double) contrastRange(double textTone, double backgroundTone) {
  final t = atTone(textTone), b = atTone(backgroundTone);
  return (
    contrast(t.upper.value, b.lower.value),
    contrast(t.lower.value, b.upper.value),
  );
}

/// Guaranteed darker foreground: minimum magnitude over all sRGB hues at the
/// specified tones. Returns null rather than lying if even black cannot fit.
double? guaranteedDarkerTone(double backgroundTone, double lc) {
  double score(double tone) => contrastRange(tone, backgroundTone).$1;
  if (score(0) < lc) return null;
  var pass = 0.0, fail = backgroundTone;
  for (var i = 0; i < 56; i++) {
    final mid = (pass + fail) / 2;
    if (score(mid) >= lc) {
      pass = mid;
    } else {
      fail = mid;
    }
  }
  return pass;
}

/// Guaranteed lighter foreground, with the conservative signed endpoint.
double? guaranteedLighterTone(double backgroundTone, double lc) {
  double score(double tone) => -contrastRange(tone, backgroundTone).$2;
  if (score(100) < lc) return null;
  var fail = backgroundTone, pass = 100.0;
  for (var i = 0; i < 56; i++) {
    final mid = (pass + fail) / 2;
    if (score(mid) >= lc) {
      pass = mid;
    } else {
      fail = mid;
    }
  }
  return pass;
}

double bisect(
  double Function(double) f,
  double value, {
  double lo = 0,
  double hi = 100,
}) {
  for (var i = 0; i < 64; i++) {
    final mid = (lo + hi) / 2;
    if (f(mid) < value) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return (lo + hi) / 2;
}

Map<String, Object> verify() {
  final random = math.Random(91826);
  var worstInput = 0.0, worstObjective = 0.0;
  var checked = 0;
  final nearKnee = [0.0, kneeSrgb - 1e-8, kneeSrgb, kneeSrgb + 1e-8, .5, 1.0];
  final samples = [
    for (var i = 0; i < 2000; i++)
      [random.nextDouble(), random.nextDouble(), random.nextDouble()],
    for (final r in nearKnee)
      for (final g in nearKnee)
        for (final b in nearKnee) [r, g, b],
  ];
  for (final rgb in samples) {
    checked++;
    final y = actualY(rgb), apca = actualA(rgb);
    final f = envelope(y, forward: true), r = envelope(apca, forward: false);
    if (apca < f.lower.value - 1e-12 ||
        apca > f.upper.value + 1e-12 ||
        y < r.lower.value - 1e-12 ||
        y > r.upper.value + 1e-12) {
      throw StateError('Outside continuous bounds: $rgb');
    }
    for (final w in [f.lower, f.upper]) {
      worstInput = math.max(worstInput, (actualY(w.srgb) - y).abs());
      worstObjective = math.max(
        worstObjective,
        (actualA(w.srgb) - w.value).abs(),
      );
    }
    for (final w in [r.lower, r.upper]) {
      worstInput = math.max(worstInput, (actualA(w.srgb) - apca).abs());
      worstObjective = math.max(
        worstObjective,
        (actualY(w.srgb) - w.value).abs(),
      );
    }
  }
  // One-sided knee witnesses can differ from the selected branch by <=2.25e-9
  // in physical Y. This is a transfer-function discontinuity, not solver error.
  if (worstInput > 3e-9 || worstObjective > 3e-9) {
    throw StateError('Witness mismatch');
  }
  return {
    'continuous_samples': checked,
    'max_witness_constraint_residual': worstInput,
    'max_witness_objective_residual': worstObjective,
  };
}

Map<String, Object> exhaustive() {
  // Envelopes are monotone. Bracket by grid endpoints (do NOT interpolate), so
  // this is a conservative all-8-bit containment check, not a proof of tightness.
  const n = 4096;
  final grid = [for (var i = 0; i <= n; i++) envelope(i / n, forward: true)];
  final rgb = [for (var i = 0; i < 256; i++) i / 255.0];
  final ys = rgb.map(cie.linearized).toList(),
      as = rgb.map((v) => power(v, p)).toList();
  final quantizationLow = [
    for (var i = 0; i < 256; i++) cie.linearized(math.max(0, (i - .5) / 255)),
  ];
  final quantizationHigh = [
    for (var i = 0; i < 256; i++) cie.linearized(math.min(1, (i + .5) / 255)),
  ];
  var maxBlackError = 0.0, maxWhiteError = 0.0, maxToneError = 0.0;
  var maxMaterializationToneError = 0.0;
  var blackRgb = 0, whiteRgb = 0, toneRgb = 0;
  for (var r = 0; r < 256; r++) {
    for (var g = 0; g < 256; g++) {
      for (var b = 0; b < 256; b++) {
        final y = c[0] * ys[r] + c[1] * ys[g] + c[2] * ys[b];
        final apca = a[0] * as[r] + a[1] * as[g] + a[2] * as[b];
        final index = (y * n).floor().clamp(0, n);
        if (apca < grid[index].lower.value - 1e-12 ||
            apca > grid[math.min(index + 1, n)].upper.value + 1e-12) {
          throw StateError('Outside bracketed bounds: $r $g $b');
        }
        final t = cie.lstarFromY(y * 100);
        final preimageLow =
            c[0] * quantizationLow[r] +
            c[1] * quantizationLow[g] +
            c[2] * quantizationLow[b];
        final preimageHigh =
            c[0] * quantizationHigh[r] +
            c[1] * quantizationHigh[g] +
            c[2] * quantizationHigh[b];
        maxMaterializationToneError = math.max(
          maxMaterializationToneError,
          math.max(
            t - cie.lstarFromY(preimageLow * 100),
            cie.lstarFromY(preimageHigh * 100) - t,
          ),
        );
        final neutral = grayA(t);
        final blackErr = (contrast(0, apca) - contrast(0, neutral)).abs();
        final whiteErr = (contrast(whiteA, apca) - contrast(whiteA, neutral))
            .abs();
        // APCA-equivalent gray tone: exact alternative coordinate, not CIE L*.
        final eqTone = cie.lstarFromY(
          cie.linearized(power(apca / whiteA, q)) * 100,
        );
        if ((eqTone - t).abs() > maxToneError) {
          maxToneError = (eqTone - t).abs();
          toneRgb = r << 16 | g << 8 | b;
        }
        if (blackErr > maxBlackError) {
          maxBlackError = blackErr;
          blackRgb = r << 16 | g << 8 | b;
        }
        if (whiteErr > maxWhiteError) {
          maxWhiteError = whiteErr;
          whiteRgb = r << 16 | g << 8 | b;
        }
      }
    }
  }
  Map<String, Object> example(int argb, double fg) {
    final s = [
      (argb >> 16 & 255) / 255.0,
      (argb >> 8 & 255) / 255.0,
      (argb & 255) / 255.0,
    ];
    final t = cie.lstarFromY(actualY(s) * 100);
    return {
      'rgb': argb.toRadixString(16).padLeft(6, '0'),
      'tone': t,
      'actual_lc': contrast(fg, actualA(s)),
      'gray_lc': contrast(fg, grayA(t)),
      'absolute_error': (contrast(fg, actualA(s)) - contrast(fg, grayA(t)))
          .abs(),
    };
  }

  return {
    'rgb_colors_checked': 16777216,
    'bound_violations': 0,
    'black_text_largest_observed_error': example(blackRgb, 0),
    'white_text_largest_observed_error': example(whiteRgb, whiteA),
    'largest_apca_equivalent_gray_tone_shift': maxToneError,
    'hct_8bit_materialization_max_tone_error': maxMaterializationToneError,
    'tone_shift_rgb': toneRgb.toRadixString(16).padLeft(6, '0'),
    'caveat': 'Finite 8-bit exhaustive maxima, not continuous-gamut maxima. Low-clip discontinuities included.',
  };
}

void verifySourceConstants() {
  final src = File('lib/contrast/apca.dart').readAsStringSync();
  const expected = {
    'mainTrc': p,
    'sRco': .2126729,
    'sGco': .7151522,
    'sBco': .0721750,
    'normBg': .56,
    'normText': .57,
    'revText': .62,
    'revBg': .65,
    'blkThrs': .022,
    'blkClmp': 1.414,
    'scaleBoW': 1.14,
    'scaleWoB': 1.14,
    'loBoWOffset': .027,
    'loWoBOffset': .027,
    'deltaYMin': .0005,
    'loClip': .1,
  };
  for (final e in expected.entries) {
    final match = RegExp('const double ${e.key} = ([0-9.]+);').firstMatch(src);
    if (match == null || double.parse(match[1]!) != e.value) {
      throw StateError('APCA source changed: ${e.key}');
    }
  }
  for (var i = 0; i < 3; i++) {
    if (cie.kSrgbToXyz[1][i] != c[i]) {
      throw StateError('CIE coefficients changed');
    }
  }
}

List<Bounds> productionBounds() => [
  for (var i = 0; i <= 400; i++) atTone(i / 4),
];

String dartProductionTable(List<Bounds> bounds) {
  final out = StringBuffer(
    '// GENERATED by `dart run tool/apca_tone_bounds.dart --write-production`.'
    '\n// Consumers bracket, never interpolate, and round outward.\n',
  );
  void write(String name, double Function(Bounds) value) {
    out.writeln('const $name = <double>[');
    for (final bound in bounds) {
      out.writeln('  ${value(bound)},');
    }
    out.writeln('];');
  }

  write('apcaMinimumAtQuarterTone', (bound) => bound.lower.value);
  write('apcaMaximumAtQuarterTone', (bound) => bound.upper.value);
  return out.toString();
}

String typescriptProductionTable(List<Bounds> bounds) {
  final out = StringBuffer(
    '// GENERATED by `dart run tool/apca_tone_bounds.dart --write-production`.'
    '\n// Consumers bracket, never interpolate, and round outward.\n',
  );
  void write(String name, double Function(Bounds) value) {
    out.writeln('export const $name = [');
    for (final bound in bounds) {
      out.writeln('  ${value(bound)},');
    }
    out.writeln('] as const;');
  }

  write('apcaMinimumAtQuarterTone', (bound) => bound.lower.value);
  write('apcaMaximumAtQuarterTone', (bound) => bound.upper.value);
  return out.toString();
}

void writeProductionTables() {
  final bounds = productionBounds();
  File(dartTablePath).writeAsStringSync(dartProductionTable(bounds));
  File(typescriptTablePath)
      .writeAsStringSync(typescriptProductionTable(bounds));
}

/// Compares stored values with a fresh numerical solve, allowing insignificant
/// platform differences in floating-point evaluation (not an interval proof).
void verifyProductionTableValues(List<Bounds> bounds) {
  if (apcaMinimumAtQuarterTone.length != 401 ||
      apcaMaximumAtQuarterTone.length != 401 ||
      bounds.length != 401) {
    throw StateError('Production APCA envelope table has the wrong length');
  }
  var previousMinimum = -1.0, previousMaximum = -1.0;
  for (var i = 0; i <= 400; i++) {
    final exact = bounds[i];
    final storedMinimum = apcaMinimumAtQuarterTone[i];
    final storedMaximum = apcaMaximumAtQuarterTone[i];
    if (!storedMinimum.isFinite ||
        !storedMaximum.isFinite ||
        !exact.lower.value.isFinite ||
        !exact.upper.value.isFinite ||
        (storedMinimum - exact.lower.value).abs() > 1e-14 ||
        (storedMaximum - exact.upper.value).abs() > 1e-14 ||
        storedMinimum < previousMinimum ||
        storedMaximum < previousMaximum) {
      throw StateError('Production APCA envelope mismatch at T${i / 4}');
    }
    previousMinimum = storedMinimum;
    previousMaximum = storedMaximum;
  }
}

/// Checks source formatting and cross-language synchronization against the
/// stored Dart values, NOT a fresh solve. This must not cancel the numerical
/// tolerance above by comparing a solver's last-bit differences as text.
void verifyProductionTableSources(String dartSource, String typescriptSource) {
  final stored = [
    for (var i = 0; i < apcaMinimumAtQuarterTone.length; i++)
      Bounds(
        Witness(apcaMinimumAtQuarterTone[i], const []),
        Witness(apcaMaximumAtQuarterTone[i], const []),
      ),
  ];
  if (dartSource != dartProductionTable(stored) ||
      typescriptSource != typescriptProductionTable(stored)) {
    throw StateError(
      'Production APCA table sources are out of sync; run with --write-production',
    );
  }
}

void verifyProductionTables() {
  verifyProductionTableValues(productionBounds());
  verifyProductionTableSources(
    File(dartTablePath).readAsStringSync(),
    File(typescriptTablePath).readAsStringSync(),
  );
}

void main(List<String> args) {
  verifySourceConstants();
  if (args.contains('--write-production')) {
    writeProductionTables();
    print('Wrote $dartTablePath and $typescriptTablePath');
    return;
  }
  verifyProductionTables();
  final out = Directory(
    args
            .where((s) => s.startsWith('--out='))
            .map((s) => s.substring(6))
            .firstOrNull ??
        'build/apca-tone-investigation',
  )..createSync(recursive: true);
  final report = <String, Object>{
    'scope': 'opaque sRGB, full continuous gamut, actual CIE L*, APCA 0.0.98G constants in libmonet',
    'verification': verify(),
  };
  final rows = <Map<String, Object>>[];
  for (final tone in [
    0.0,
    5.0,
    10.0,
    20.0,
    30.0,
    40.0,
    50.0,
    60.0,
    65.0,
    66.0,
    67.0,
    68.0,
    70.0,
    80.0,
    90.0,
    95.0,
    100.0,
  ]) {
    final bounds = atTone(tone);
    rows.add({
      'tone': tone,
      'apca_y': bounds.toJson(),
      'neutral_apca_y': grayA(tone),
      'black_text_lc': [
        contrast(0, bounds.lower.value),
        contrast(0, bounds.upper.value),
      ],
      'white_text_lc_magnitude': [
        contrast(whiteA, bounds.upper.value).abs(),
        contrast(whiteA, bounds.lower.value).abs(),
      ],
    });
  }
  report['tone_examples'] = rows;
  final threshold = bisect(
    (v) => contrast(0, v) - contrast(whiteA, v).abs(),
    0,
    hi: whiteA,
  );
  report['black_white_equal_contrast'] = {
    'apca_y': threshold,
    'possible_tones': tonesAtApca(threshold).toJson(),
    'neutral_tone': cie.lstarFromY(
      cie.linearized(power(threshold / whiteA, q)) * 100,
    ),
  };
  report['maximin_shared_polarity_tone'] = bisect((tone) {
    final b = atTone(tone);
    return contrast(0, b.lower.value) - contrast(whiteA, b.upper.value).abs();
  }, 0);
  report['guaranteed_lc_60_examples'] = [
    for (final bg in [20.0, 40.0, 50.0, 67.0, 80.0, 94.0])
      {
        'background_tone': bg,
        'darkest_side_max_foreground_tone': guaranteedDarkerTone(bg, 60),
        'lightest_side_min_foreground_tone': guaranteedLighterTone(bg, 60),
      },
  ];
  report['two_tone_signed_lc_examples'] = [
    for (final pair in [(40.0, 80.0), (80.0, 40.0), (50.0, 67.0)])
      {
        'text_tone': pair.$1,
        'background_tone': pair.$2,
        'range': [
          contrastRange(pair.$1, pair.$2).$1,
          contrastRange(pair.$1, pair.$2).$2,
        ],
        'neutral_reference': contrast(grayA(pair.$1), grayA(pair.$2)),
      },
  ];
  final sweep = StringBuffer(
    'tone,min_apca_y,max_apca_y,neutral_apca_y,black_min_lc,black_max_lc,white_min_lc,white_max_lc\n',
  );
  var maxWidth = -1.0, atWidth = 0.0, maxInverseWidth = -1.0, inverseAt = 0.0;
  for (var i = 0; i <= 10000; i++) {
    final t = i / 100.0, b = atTone(t);
    sweep.writeln(
      '$t,${b.lower.value},${b.upper.value},${grayA(t)},${contrast(0, b.lower.value)},${contrast(0, b.upper.value)},${contrast(whiteA, b.upper.value).abs()},${contrast(whiteA, b.lower.value).abs()}',
    );
    if (b.width > maxWidth) {
      maxWidth = b.width;
      atWidth = t;
    }
    final apca = i / 10000 * whiteA, inv = tonesAtApca(apca);
    if (inv.width > maxInverseWidth) {
      maxInverseWidth = inv.width;
      inverseAt = apca;
    }
  }
  report['sampled_max_apca_y_width'] = {'width': maxWidth, 'tone': atWidth};
  report['sampled_max_tone_width_at_fixed_apca_y'] = {
    'width': maxInverseWidth,
    'apca_y': inverseAt,
    'bounds': tonesAtApca(inverseAt).toJson(),
  };
  report['old_explorer_blue_00005f'] = {
    'actual_tone': cie.lstarFromArgb(0xff00005f),
    'exact_range_at_its_apca_y': tonesAtApca(a[2] * power(95 / 255, p))
        .toJson(),
  };
  if (args.contains('--exhaustive')) report['exhaustive'] = exhaustive();
  File('${out.path}/tone-bounds.csv').writeAsStringSync(sweep.toString());
  File('${out.path}/report.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  print('Report: ${out.path}/report.json');
  print('Continuous tone sweep: ${out.path}/tone-bounds.csv');
  print(
    const JsonEncoder.withIndent('  ').convert({
      for (final e in report.entries)
        if (e.key != 'tone_examples') e.key: e.value,
    }),
  );
  print('Tone | APCA Y min..max | black Lc | white |Lc|');
  for (final row in rows) {
    final b = row['apca_y']! as Map<String, Object>;
    print(
      '${row['tone']} | ${(b['lower']! as Map)['value']}..${(b['upper']! as Map)['value']} | ${row['black_text_lc']} | ${row['white_text_lc_magnitude']}',
    );
  }
}
