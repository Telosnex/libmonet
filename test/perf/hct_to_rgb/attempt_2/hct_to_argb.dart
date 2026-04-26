// Attempt 2: Everything from attempt 1, plus:
//   7. _inverseCA body inlined directly into Newton loop
//      (eliminates 15.2% self-time function-call overhead, 3 calls/iter × 5 iters)

import 'dart:math' as math;

import 'package:libmonet/colorspaces/cam16/cam16_viewing_conditions.dart';
import 'package:libmonet/colorspaces/gamut.dart';

// ═══════════════════════════════════════════════════════════════════════
// Precomputed constants
// ═══════════════════════════════════════════════════════════════════════

const _inv0_42 = 1.0 / 0.42; // 2.380952...
const _inv0_9 = 1.0 / 0.9; // 1.111111...
const _inv2_4 = 1.0 / 2.4; // 0.416667...

final _sc = _SolverConst._compute();

class _SolverConst {
  // Viewing conditions
  final double aw;
  final double nbb;
  final double invCZ; // 1/(c*z)
  final double tInnerCoeff;
  final double p1Coeff; // (50000/13) * nc * ncb

  // linrgbFromScaledDiscount (flattened)
  final double m00, m01, m02;
  final double m10, m11, m12;
  final double m20, m21, m22;

  // scaledDiscountFromLinrgb (flattened)
  final double sd00, sd01, sd02;
  final double sd10, sd11, sd12;
  final double sd20, sd21, sd22;

  // Y from linear RGB
  final double kR, kG, kB, kSum;

  // Critical planes for bisection
  final List<double> criticalPlanes;

  _SolverConst._({
    required this.aw,
    required this.nbb,
    required this.invCZ,
    required this.tInnerCoeff,
    required this.p1Coeff,
    required this.m00, required this.m01, required this.m02,
    required this.m10, required this.m11, required this.m12,
    required this.m20, required this.m21, required this.m22,
    required this.sd00, required this.sd01, required this.sd02,
    required this.sd10, required this.sd11, required this.sd12,
    required this.sd20, required this.sd21, required this.sd22,
    required this.kR, required this.kG, required this.kB, required this.kSum,
    required this.criticalPlanes,
  });

  factory _SolverConst._compute() {
    final vc = Cam16ViewingConditions.standard;
    final g = Gamut.srgb;
    final m = g.linrgbFromScaledDiscount;
    final sd = g.scaledDiscountFromLinrgb;

    // tInnerCoeff = 1 / pow(1.64 - pow(0.29, n), 0.73)
    final inner =
        1.64 - math.exp(vc.backgroundYToWhitePointY * math.log(0.29));
    final tIC = 1.0 / math.exp(0.73 * math.log(inner));

    return _SolverConst._(
      aw: vc.aw,
      nbb: vc.nbb,
      invCZ: 1.0 / (vc.c * vc.z),
      tInnerCoeff: tIC,
      p1Coeff: (50000.0 / 13.0) * vc.nC * vc.ncb,
      m00: m[0][0], m01: m[0][1], m02: m[0][2],
      m10: m[1][0], m11: m[1][1], m12: m[1][2],
      m20: m[2][0], m21: m[2][1], m22: m[2][2],
      sd00: sd[0][0], sd01: sd[0][1], sd02: sd[0][2],
      sd10: sd[1][0], sd11: sd[1][1], sd12: sd[1][2],
      sd20: sd[2][0], sd21: sd[2][1], sd22: sd[2][2],
      kR: g.yFromLinrgb[0],
      kG: g.yFromLinrgb[1],
      kB: g.yFromLinrgb[2],
      kSum: g.yFromLinrgb[0] + g.yFromLinrgb[1] + g.yFromLinrgb[2],
      criticalPlanes: g.criticalPlanes,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════

/// yFromLstar inlined — no transcendentals, just cube or linear.
double _yFromLstar(double lstar) {
  final ft = (lstar + 16.0) / 116.0;
  final ft3 = ft * ft * ft;
  const e = 216.0 / 24389.0;
  if (ft3 > e) {
    return 100.0 * ft3;
  } else {
    return 100.0 * (116.0 * ft - 16.0) / (24389.0 / 27.0);
  }
}

/// Forward chromatic adaptation (for bisection fallback).
double _forwardCA(double component) {
  final abs = component < 0.0 ? -component : component;
  final af = math.exp(0.42 * math.log(abs));
  final adapted = 400.0 * af / (af + 27.13);
  return component < 0.0 ? -adapted : adapted;
}

/// Hue of linear RGB components in CAM16 (radians). For bisection.
double _hueOf(double r, double g, double b) {
  final sc = _sc;
  final sdR = r * sc.sd00 + g * sc.sd01 + b * sc.sd02;
  final sdG = r * sc.sd10 + g * sc.sd11 + b * sc.sd12;
  final sdB = r * sc.sd20 + g * sc.sd21 + b * sc.sd22;
  final rA = _forwardCA(sdR);
  final gA = _forwardCA(sdG);
  final bA = _forwardCA(sdB);
  final aP = (11.0 * rA - 12.0 * gA + bA) / 11.0;
  final bP = (rA + gA - 2.0 * bA) / 9.0;
  return math.atan2(bP, aP);
}

/// sRGB delinearize: linear [0,100] → 8-bit [0,255].
int _delinear(double lin) {
  final n = lin * 0.01;
  double enc;
  if (n <= 0.0031308) {
    enc = n * 12.92;
  } else {
    enc = 1.055 * math.exp(_inv2_4 * math.log(n)) - 0.055;
  }
  final v = (enc * 255.0).round();
  return v < 0 ? 0 : (v > 255 ? 255 : v);
}

/// sRGB trueDelinearize: linear [0,100] → display [0,255] as double.
double _trueDelinearize(double lin) {
  final n = lin * 0.01;
  double enc;
  if (n <= 0.0031308) {
    enc = n * 12.92;
  } else {
    enc = 1.055 * math.exp(_inv2_4 * math.log(n)) - 0.055;
  }
  return enc * 255.0;
}

// ═══════════════════════════════════════════════════════════════════════
// Newton solver
// ═══════════════════════════════════════════════════════════════════════

/// Finds linRGB with given hueRadians, chroma, y. Returns null if out of gamut.
(double, double, double)? _findResultByJ(
    double hueRadians, double chroma, double y) {
  final sc = _sc;
  var j = math.sqrt(y) * 11.0;

  final eHue = 0.25 * (math.cos(hueRadians + 2.0) + 3.8);
  final p1 = eHue * sc.p1Coeff;
  final hSin = math.sin(hueRadians);
  final hCos = math.cos(hueRadians);

  for (var i = 0; i < 5; i++) {
    final jN = j * 0.01;
    final alpha =
        chroma == 0.0 || j == 0.0 ? 0.0 : chroma / math.sqrt(jN);
    final t = math.exp(_inv0_9 * math.log(alpha * sc.tInnerCoeff));
    final ac = sc.aw * math.exp(sc.invCZ * math.log(jN));
    final p2 = ac / sc.nbb;
    final gamma = 23.0 *
        (p2 + 0.305) *
        t /
        (23.0 * p1 + 11.0 * t * hCos + 108.0 * t * hSin);
    final a = gamma * hCos;
    final b = gamma * hSin;
    final rA = (460.0 * p2 + 451.0 * a + 288.0 * b) / 1403.0;
    final gA = (460.0 * p2 - 891.0 * a - 261.0 * b) / 1403.0;
    final bA = (460.0 * p2 - 220.0 * a - 6300.0 * b) / 1403.0;

    // Inverse chromatic adaptation — fully inlined (no function call)
    double rCS, gCS, bCS;
    {
      final a1 = rA < 0.0 ? -rA : rA;
      final d1 = 400.0 - a1;
      if (d1 <= 0.0) { rCS = 0.0; } else {
        final b1 = 27.13 * a1 / d1;
        rCS = b1 <= 0.0 ? 0.0 : math.exp(_inv0_42 * math.log(b1));
        if (rA < 0.0) rCS = -rCS;
      }
    }
    {
      final a1 = gA < 0.0 ? -gA : gA;
      final d1 = 400.0 - a1;
      if (d1 <= 0.0) { gCS = 0.0; } else {
        final b1 = 27.13 * a1 / d1;
        gCS = b1 <= 0.0 ? 0.0 : math.exp(_inv0_42 * math.log(b1));
        if (gA < 0.0) gCS = -gCS;
      }
    }
    {
      final a1 = bA < 0.0 ? -bA : bA;
      final d1 = 400.0 - a1;
      if (d1 <= 0.0) { bCS = 0.0; } else {
        final b1 = 27.13 * a1 / d1;
        bCS = b1 <= 0.0 ? 0.0 : math.exp(_inv0_42 * math.log(b1));
        if (bA < 0.0) bCS = -bCS;
      }
    }

    // ScaledDiscount → linRGB
    final linR = rCS * sc.m00 + gCS * sc.m01 + bCS * sc.m02;
    final linG = rCS * sc.m10 + gCS * sc.m11 + bCS * sc.m12;
    final linB = rCS * sc.m20 + gCS * sc.m21 + bCS * sc.m22;

    if (linR < 0.0 || linG < 0.0 || linB < 0.0) return null;

    final fnj = sc.kR * linR + sc.kG * linG + sc.kB * linB;
    if (fnj <= 0.0) return null;

    if (i == 4 || (fnj - y).abs() < 0.002) {
      if (linR > 100.01 || linG > 100.01 || linB > 100.01) return null;
      return (linR, linG, linB);
    }

    j = j - (fnj - y) * j / (2.0 * fnj);
  }
  return null;
}

// ═══════════════════════════════════════════════════════════════════════
// Bisection fallback (rarely taken)
// ═══════════════════════════════════════════════════════════════════════

double _sanitizeRadians(double angle) => (angle + math.pi * 8) % (math.pi * 2);

bool _areInCyclicOrder(double a, double b, double c) {
  final dAB = _sanitizeRadians(b - a);
  final dAC = _sanitizeRadians(c - a);
  return dAB < dAC;
}

(double, double, double) _bisectToLimit(double y, double targetHue) {
  final sc = _sc;

  // ── bisectToSegment ──
  var lR = -1.0, lG = -1.0, lB = -1.0;
  var rR = -1.0, rG = -1.0, rB = -1.0;
  var mR = -1.0, mG = -1.0, mB = -1.0;

  var leftHue = 0.0, rightHue = 0.0;
  var initialized = false, uncut = true;

  for (var n = 0; n < 12; n++) {
    final coordA = n % 4 <= 1 ? 0.0 : 100.0;
    final coordB = n % 2 == 0 ? 0.0 : 100.0;
    if (n < 4) {
      final g = coordA, b = coordB;
      final r = (y - g * sc.kG - b * sc.kB) / sc.kR;
      if (r >= 0.0 && r <= 100.0) { mR = r; mG = g; mB = b; } else { mR = -1.0; }
    } else if (n < 8) {
      final b = coordA, r = coordB;
      final g = (y - r * sc.kR - b * sc.kB) / sc.kG;
      if (g >= 0.0 && g <= 100.0) { mR = r; mG = g; mB = b; } else { mR = -1.0; }
    } else {
      final r = coordA, g = coordB;
      final b = (y - r * sc.kR - g * sc.kG) / sc.kB;
      if (b >= 0.0 && b <= 100.0) { mR = r; mG = g; mB = b; } else { mR = -1.0; }
    }
    if (mR < 0.0) continue;
    final midHue = _hueOf(mR, mG, mB);
    if (!initialized) {
      lR = mR; lG = mG; lB = mB;
      rR = mR; rG = mG; rB = mB;
      leftHue = midHue; rightHue = midHue;
      initialized = true;
      continue;
    }
    if (uncut || _areInCyclicOrder(leftHue, midHue, rightHue)) {
      uncut = false;
      if (_areInCyclicOrder(leftHue, targetHue, midHue)) {
        rR = mR; rG = mG; rB = mB; rightHue = midHue;
      } else {
        lR = mR; lG = mG; lB = mB; leftHue = midHue;
      }
    }
  }

  // ── bisect on each axis ──
  leftHue = _hueOf(lR, lG, lB);

  for (var axis = 0; axis < 3; axis++) {
    final leftForAxis = axis == 0 ? lR : (axis == 1 ? lG : lB);
    final rightForAxis = axis == 0 ? rR : (axis == 1 ? rG : rB);
    if (leftForAxis == rightForAxis) continue;

    int lPlane, rPlane;
    if (leftForAxis < rightForAxis) {
      lPlane = (_trueDelinearize(leftForAxis) - 0.5).floor();
      rPlane = (_trueDelinearize(rightForAxis) - 0.5).ceil();
    } else {
      lPlane = (_trueDelinearize(leftForAxis) - 0.5).ceil();
      rPlane = (_trueDelinearize(rightForAxis) - 0.5).floor();
    }

    for (var i = 0; i < 8; i++) {
      if ((rPlane - lPlane).abs() <= 1) break;
      final mPlane = (lPlane + rPlane) ~/ 2;
      final midCoord = sc.criticalPlanes[mPlane];
      final t = (midCoord - leftForAxis) / (rightForAxis - leftForAxis);
      mR = lR + (rR - lR) * t;
      mG = lG + (rG - lG) * t;
      mB = lB + (rB - lB) * t;
      final midHue = _hueOf(mR, mG, mB);
      if (_areInCyclicOrder(leftHue, targetHue, midHue)) {
        rR = mR; rG = mG; rB = mB; rPlane = mPlane;
      } else {
        lR = mR; lG = mG; lB = mB; leftHue = midHue; lPlane = mPlane;
      }
    }
  }

  return ((lR + rR) * 0.5, (lG + rG) * 0.5, (lB + rB) * 0.5);
}

// ═══════════════════════════════════════════════════════════════════════
// Entry point
// ═══════════════════════════════════════════════════════════════════════

int hctToArgb((double hue, double chroma, double tone) hct) {
  var hueDeg = hct.$1;
  final chroma = hct.$2;
  final lstar = hct.$3;

  if (chroma < 0.0001 || lstar < 0.0001 || lstar > 99.9999) {
    final y = _yFromLstar(lstar);
    final v = y / _sc.kSum;
    final c = _delinear(v);
    return 0xFF000000 | (c << 16) | (c << 8) | c;
  }

  hueDeg = hueDeg % 360.0;
  if (hueDeg < 0.0) hueDeg += 360.0;
  final hueRad = hueDeg * (math.pi / 180.0);
  final y = _yFromLstar(lstar);

  final exact = _findResultByJ(hueRad, chroma, y);
  final (linR, linG, linB) = exact ?? _bisectToLimit(y, hueRad);

  final r = _delinear(linR);
  final g = _delinear(linG);
  final b = _delinear(linB);
  return 0xFF000000 | (r << 16) | (g << 8) | b;
}
