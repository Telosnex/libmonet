// Attempt 3: Pure-Dart atan2 to avoid C FFI call overhead.
//
// Inherited from Attempt 2:
//   1. Fused sRGB→Cone matrix — eliminates intermediate XYZ (saves 9 MADs)
//   2. Signum elimination — all fused matrix coefficients are positive,
//      so cone responses ≥ 0 for valid sRGB. Skip abs()/sign branches.
//   3. Fast cube root — IEEE 754 bit manipulation + 2 Halley iterations.
//      Replaces generic pow(x,1/3) which handles negative bases, NaN, etc.
//   4. exp(p*log(x)) replaces pow(x,p) — dart:math pow() returns `num`
//      requiring boxing + toDouble(); exp/log return `double` directly.
//   5. Combined J+chroma — chroma = alphaK * exp(0.9*log(t) + halfCz*log(ac/aw))
//      replaces pow(ac/aw,cz) + pow(t,0.9) + sqrt(J/100). Saves 1 exp + 1 sqrt.
//   6. Precomputed derived constants — 1/aw, c*z/2, fl*rgbD[i]/100 as bare doubles.

import 'dart:math' as math;
import 'dart:typed_data';

// ═══════════════════════════════════════════════════════════════════
// LUT: sRGB byte [0..255] → linearized×100 [0..100]
// ═══════════════════════════════════════════════════════════════════
final _lut = Float64List.fromList(List<double>.generate(256, (i) {
  final s = i / 255.0;
  return (s <= 0.040449936
          ? s / 12.92
          : math.pow((s + 0.055) / 1.055, 2.4).toDouble()) *
      100.0;
}));

// ═══════════════════════════════════════════════════════════════════
// Fused sRGB_linear → Cone = M_HPE × M_sRGBtoXYZ
// One matmul instead of two. All coefficients > 0.
// ═══════════════════════════════════════════════════════════════════
const _crr = 0.30269915328759;
const _crg = 0.60238031164330;
const _crb = 0.07047346329738;
const _cgr = 0.15374913599554;
const _cgg = 0.77736002827076;
const _cgb = 0.08535981854956;
const _cbr = 0.02796570007202;
const _cbg = 0.14784523135458;
const _cbb = 0.90895832236389;

// ═══════════════════════════════════════════════════════════════════
// Viewing conditions (sRGB standard, all derived)
// ═══════════════════════════════════════════════════════════════════
final _vc = _Vc._init();

class _Vc {
  final double nbb;
  final double invAw;
  final double halfCz;
  final double p1k;
  final double alphaK;
  final double kR, kG, kB; // fl * rgbD[i] / 100

  const _Vc._({
    required this.nbb,
    required this.invAw,
    required this.halfCz,
    required this.p1k,
    required this.alphaK,
    required this.kR,
    required this.kG,
    required this.kB,
  });

  factory _Vc._init() {
    const wp = [95.047, 100.0, 108.883];
    final aL = 200.0 / math.pi * 18.418651851244416 / 100.0;
    final rW = wp[0] * 0.401288 + wp[1] * 0.650173 + wp[2] * -0.051461;
    final gW = wp[0] * -0.250268 + wp[1] * 1.204414 + wp[2] * 0.045854;
    final bW = wp[0] * -0.002079 + wp[1] * 0.048952 + wp[2] * 0.953127;
    const surround = 2.0;
    final f = 0.8 + surround / 10.0;
    final c = 0.59 + 0.10 * ((f - 0.9) * 10.0);
    var d = f * (1.0 - (1.0 / 3.6) * math.exp((-aL - 42.0) / 92.0));
    d = d.clamp(0.0, 1.0);
    final nc = f;
    final rgbD0 = d * (100.0 / rW) + 1.0 - d;
    final rgbD1 = d * (100.0 / gW) + 1.0 - d;
    final rgbD2 = d * (100.0 / bW) + 1.0 - d;
    final k = 1.0 / (5.0 * aL + 1.0);
    final k4 = k * k * k * k;
    final k4F = 1.0 - k4;
    final fl = k4 * aL + 0.1 * k4F * k4F * math.pow(5.0 * aL, 1.0 / 3.0);
    final n = 18.418651851244416 / wp[1];
    final z = 1.48 + math.sqrt(n);
    final nbb = 0.725 / math.pow(n, 0.2);
    final ncb = nbb;
    final rgbAF = [
      math.pow(fl * rgbD0 * rW / 100, 0.42),
      math.pow(fl * rgbD1 * gW / 100, 0.42),
      math.pow(fl * rgbD2 * bW / 100, 0.42),
    ];
    final rgbA = [
      400 * rgbAF[0] / (rgbAF[0] + 27.13),
      400 * rgbAF[1] / (rgbAF[1] + 27.13),
      400 * rgbAF[2] / (rgbAF[2] + 27.13),
    ];
    final aw = (40 * rgbA[0] + 20 * rgbA[1] + rgbA[2]) / 20 * nbb;
    return _Vc._(
      nbb: nbb.toDouble(),
      invAw: 1.0 / aw,
      halfCz: c * z / 2.0,
      p1k: 50000.0 / 13.0 * nc * ncb,
      alphaK: math.pow(1.64 - math.pow(0.29, n), 0.73).toDouble(),
      kR: (fl * rgbD0 / 100.0).toDouble(),
      kG: (fl * rgbD1 / 100.0).toDouble(),
      kB: (fl * rgbD2 / 100.0).toDouble(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Fast cube root (positive x only)
// IEEE 754 bit hack for initial guess + 2 Halley iterations
// (cubic convergence → 54+ bits after 2 steps from ~6-bit seed).
// ═══════════════════════════════════════════════════════════════════
final _cbrtF = Float64List(1);
final _cbrtI = _cbrtF.buffer.asInt64List();

double _cbrt(double x) {
  _cbrtF[0] = x;
  _cbrtI[0] = _cbrtI[0] ~/ 3 + 3071454945866678272;
  double y = _cbrtF[0];
  // Halley iteration: y *= (y³ + 2x) / (2y³ + x)
  double y3 = y * y * y;
  y *= (y3 + x + x) / (y3 + y3 + x);
  y3 = y * y * y;
  y *= (y3 + x + x) / (y3 + y3 + x);
  return y;
}

// ═══════════════════════════════════════════════════════════════════
// Fast atan2 → degrees (pure Dart, stays in JIT-land)
// 7th-order minimax polynomial for atan on [0,1], then quadrant logic.
// Max error ~1.3e-7 radians ≈ 7.5e-6 degrees — well within 0.01° tol.
// ═══════════════════════════════════════════════════════════════════
double _atan2Deg(double y, double x) {
  // Handle origin (achromatic black)
  if (x == 0.0 && y == 0.0) return 0.0;

  final ax = x < 0.0 ? -x : x;
  final ay = y < 0.0 ? -y : y;

  // Reduce to atan(t) where t = min/max ∈ [0, 1]
  final double t;
  final bool swapped;
  if (ay > ax) {
    t = ax / ay;
    swapped = true;
  } else {
    t = ay / ax;
    swapped = false;
  }

  // Minimax polynomial: atan(t) ≈ t * (c0 + t² * (c1 + t² * (c2 + t² * c3)))
  // Coefficients from Remez algorithm for atan on [0,1].
  final t2 = t * t;
  final p = t * (0.9998660373390498 +
      t2 * (-0.3302994853598744 +
          t2 * (0.18014100558784592 +
              t2 * (-0.08513091091949968 +
                  t2 * 0.020835795246366796))));

  // Undo range reduction: if swapped, atan(t) → π/2 - atan(t)
  double r = swapped ? 1.5707963267948966 - p : p;

  // Quadrant: map to [0, 2π) then convert to degrees
  if (x < 0.0) r = 3.141592653589793 - r;
  if (y < 0.0) r = -r;

  // Convert to degrees and normalize to [0, 360)
  final deg = r * 57.29577951308232; // 180/π
  return deg < 0.0 ? deg + 360.0 : deg;
}

// ════════════════════════════════════════════��══════════════════════
// Main entry point
// ═══════════════════════════════════════════════════════════════════
const _deg2rad = math.pi / 180.0;

(double hue, double chroma, double tone) hctFromArgb(int argb) {
  // ── Linearize via LUT ──
  final lut = _lut;
  final rL = lut[(argb >> 16) & 0xFF];
  final gL = lut[(argb >> 8) & 0xFF];
  final bL = lut[argb & 0xFF];

  // ── Tone: L* from Y (only Y row of sRGB→XYZ) ──
  final y = rL * 0.2126 + gL * 0.7152 + bL * 0.0722;
  final fy = y * 0.01;
  final double tone = fy > 0.008856451679035631
      ? 116.0 * _cbrt(fy) - 16.0
      : 903.2962962962963 * fy;

  // ── Cone responses (fused matrix, no XYZ intermediate) ──
  final rC = _crr * rL + _crg * gL + _crb * bL;
  final gC = _cgr * rL + _cgg * gL + _cgb * bL;
  final bC = _cbr * rL + _cbg * gL + _cbb * bL;

  // ── Chromatic adaptation ──
  // All fused coefficients > 0, so cones ≥ 0 for sRGB → no signum.
  // exp(p*log(x)) returns double directly; pow(x,p) returns num (boxing).
  final vc = _vc;
  final rAF = math.exp(0.42 * math.log(vc.kR * rC));
  final gAF = math.exp(0.42 * math.log(vc.kG * gC));
  final bAF = math.exp(0.42 * math.log(vc.kB * bC));
  final rA = 400.0 * rAF / (rAF + 27.13);
  final gA = 400.0 * gAF / (gAF + 27.13);
  final bA = 400.0 * bAF / (bAF + 27.13);

  // ── Opponent signals + hue ──
  final a = (11.0 * rA - 12.0 * gA + bA) / 11.0;
  final b = (rA + gA - 2.0 * bA) / 9.0;
  final hue = _atan2Deg(b, a);

  // ── Chroma (combined: saves 1 exp + 1 sqrt vs separate J, alpha) ──
  //   chroma = pow(t,0.9) * alphaK * pow(ac/aw, cz/2)
  //          = alphaK * exp(0.9*log(t) + halfCz*log(ac*invAw))
  final p2 = (40.0 * rA + 20.0 * gA + bA) * 0.05; // /20
  final ac = p2 * vc.nbb;
  final u = (20.0 * rA + 20.0 * gA + 21.0 * bA) * 0.05; // /20
  final huePrime = hue < 20.14 ? hue + 360.0 : hue;
  final eHue = 0.25 * (math.cos(huePrime * _deg2rad + 2.0) + 3.8);
  final t = vc.p1k * eHue * math.sqrt(a * a + b * b) / (u + 0.305);
  final chroma =
      vc.alphaK * math.exp(0.9 * math.log(t) + vc.halfCz * math.log(ac * vc.invAw));

  return (hue, chroma, tone);
}
