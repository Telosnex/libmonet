// Optimized HCT-from-RGB: single-pass, no allocations, precomputed constants.
//
// Savings vs baseline:
//   - LUT for sRGB linearization → eliminates 6 pow(x,2.4) per color
//   - Shared XYZ between CAM16 and L* → eliminates redundant linearization + matmul
//   - Precomputed viewing condition constants → eliminates per-call pow(0.29,n) etc.
//   - No Cam16 object allocation → no 9-field class instantiation
//   - Skips Q, M, s, jstar, astar, bstar → unused for hue/chroma

import 'dart:math' as math;
import 'dart:typed_data';

/// Precomputed sRGB byte [0..255] → linearized [0..100].
final _linearLut = Float64List.fromList(List<double>.generate(256, (i) {
  final s = i / 255.0;
  return (s <= 0.040449936
          ? s / 12.92
          : math.pow((s + 0.055) / 1.055, 2.4).toDouble()) *
      100.0;
}));

/// All sRGB viewing condition constants, computed once.
final _vc = _Vc._compute();

class _Vc {
  final double fl;
  final double aw;
  final double nbb;
  final double cz; // c * z
  final double p1k; // 50000/13 * nC * ncb
  final double rgbD0, rgbD1, rgbD2;
  final double alphaK; // pow(1.64 - pow(0.29, n), 0.73)

  const _Vc._({
    required this.fl,
    required this.aw,
    required this.nbb,
    required this.cz,
    required this.p1k,
    required this.rgbD0,
    required this.rgbD1,
    required this.rgbD2,
    required this.alphaK,
  });

  factory _Vc._compute() {
    const wp = [95.047, 100.0, 108.883];
    final aL = 200.0 / math.pi * 18.418651851244416 / 100.0;

    final rW = wp[0] * 0.401288 + wp[1] * 0.650173 + wp[2] * -0.051461;
    final gW = wp[0] * -0.250268 + wp[1] * 1.204414 + wp[2] * 0.045854;
    final bW = wp[0] * -0.002079 + wp[1] * 0.048952 + wp[2] * 0.953127;

    const surround = 2.0;
    final f = 0.8 + surround / 10.0;
    final c = 0.59 + (0.69 - 0.59) * ((f - 0.9) * 10.0); // f=1.0 ≥ 0.9
    var d = f * (1.0 - (1.0 / 3.6) * math.exp((-aL - 42.0) / 92.0));
    d = d.clamp(0.0, 1.0);
    final nc = f;

    final rgbD0 = d * (100.0 / rW) + 1.0 - d;
    final rgbD1 = d * (100.0 / gW) + 1.0 - d;
    final rgbD2 = d * (100.0 / bW) + 1.0 - d;

    final k = 1.0 / (5.0 * aL + 1.0);
    final k4 = k * k * k * k;
    final k4F = 1.0 - k4;
    final fl = (k4 * aL +
            0.1 * k4F * k4F * math.pow(5.0 * aL, 1.0 / 3.0))
        .toDouble();

    final n = 18.418651851244416 / wp[1];
    final z = 1.48 + math.sqrt(n);
    final nbb = 0.725 / math.pow(n, 0.2).toDouble();
    final ncb = nbb;

    final rgbAF = [
      math.pow(fl * rgbD0 * rW / 100.0, 0.42).toDouble(),
      math.pow(fl * rgbD1 * gW / 100.0, 0.42).toDouble(),
      math.pow(fl * rgbD2 * bW / 100.0, 0.42).toDouble(),
    ];
    final rgbA = [
      400.0 * rgbAF[0] / (rgbAF[0] + 27.13),
      400.0 * rgbAF[1] / (rgbAF[1] + 27.13),
      400.0 * rgbAF[2] / (rgbAF[2] + 27.13),
    ];
    final aw = (40.0 * rgbA[0] + 20.0 * rgbA[1] + rgbA[2]) / 20.0 * nbb;

    return _Vc._(
      fl: fl,
      aw: aw,
      nbb: nbb,
      cz: c * z,
      p1k: 50000.0 / 13.0 * nc * ncb,
      rgbD0: rgbD0,
      rgbD1: rgbD1,
      rgbD2: rgbD2,
      alphaK: math.pow(1.64 - math.pow(0.29, n), 0.73).toDouble(),
    );
  }
}

(double hue, double chroma, double tone) hctFromArgb(int argb) {
  // ── Linear RGB from LUT (eliminates 6 pow calls) ──
  final lut = _linearLut;
  final rL = lut[(argb >> 16) & 0xFF];
  final gL = lut[(argb >> 8) & 0xFF];
  final bL = lut[argb & 0xFF];

  // ── XYZ (one matmul, shared by CAM16 + tone) ──
  final x = rL * 0.41233895 + gL * 0.35762064 + bL * 0.18051042;
  final y = rL * 0.2126 + gL * 0.7152 + bL * 0.0722;
  final z = rL * 0.01932141 + gL * 0.11916382 + bL * 0.95034478;

  // ── Tone (L* from Y — no second linearization) ──
  final fy = y / 100.0;
  final double tone;
  if (fy > 0.008856451679035631) {
    // 216/24389
    tone = 116.0 * math.pow(fy, 1.0 / 3.0).toDouble() - 16.0;
  } else {
    tone = 903.2962962962963 * fy; // (24389/27) * fy
  }

  // ── CAM16 cone responses ──
  final rC = 0.401288 * x + 0.650173 * y - 0.051461 * z;
  final gC = -0.250268 * x + 1.204414 * y + 0.045854 * z;
  final bC = -0.002079 * x + 0.048952 * y + 0.953127 * z;

  // ── Chromatic adaptation ──
  final vc = _vc;
  final rD = vc.rgbD0 * rC;
  final gD = vc.rgbD1 * gC;
  final bD = vc.rgbD2 * bC;

  final rAF = math.pow(vc.fl * rD.abs() / 100.0, 0.42).toDouble();
  final gAF = math.pow(vc.fl * gD.abs() / 100.0, 0.42).toDouble();
  final bAF = math.pow(vc.fl * bD.abs() / 100.0, 0.42).toDouble();

  final rS = rD < 0.0 ? -1.0 : (rD > 0.0 ? 1.0 : 0.0);
  final gS = gD < 0.0 ? -1.0 : (gD > 0.0 ? 1.0 : 0.0);
  final bS = bD < 0.0 ? -1.0 : (bD > 0.0 ? 1.0 : 0.0);

  final rA = rS * 400.0 * rAF / (rAF + 27.13);
  final gA = gS * 400.0 * gAF / (gAF + 27.13);
  final bA = bS * 400.0 * bAF / (bAF + 27.13);

  // ── Hue ──
  final a = (11.0 * rA - 12.0 * gA + bA) / 11.0;
  final b = (rA + gA - 2.0 * bA) / 9.0;
  final atanDeg = math.atan2(b, a) * (180.0 / math.pi);
  final hue = atanDeg < 0
      ? atanDeg + 360.0
      : atanDeg >= 360.0
          ? atanDeg - 360.0
          : atanDeg;

  // ── J (lightness) ──
  final p2 = (40.0 * rA + 20.0 * gA + bA) / 20.0;
  final ac = p2 * vc.nbb;
  final J = 100.0 * math.pow(ac / vc.aw, vc.cz).toDouble();

  // ── Chroma (skip Q, M, s, jstar, astar, bstar) ──
  final u = (20.0 * rA + 20.0 * gA + 21.0 * bA) / 20.0;
  final huePrime = hue < 20.14 ? hue + 360.0 : hue;
  final eHue = 0.25 * (math.cos(huePrime * math.pi / 180.0 + 2.0) + 3.8);
  final p1 = vc.p1k * eHue;
  final t = p1 * math.sqrt(a * a + b * b) / (u + 0.305);
  final alpha = math.pow(t, 0.9).toDouble() * vc.alphaK;
  final chroma = alpha * math.sqrt(J / 100.0);

  return (hue, chroma, tone);
}
