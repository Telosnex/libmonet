// Modified and maintained by open-source contributors, on behalf of libmonet.
//
// Original notice:
// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:core';
import 'dart:math' as math;

import 'package:libmonet/core/argb_srgb_xyz_lab.dart';
import 'package:libmonet/core/math.dart';

import 'cam16_v11_viewing_conditions.dart';

// Appendix A and inverse CAM16 v11 use 43. Equation 23 uses 47, likely before
// the final eccentricity refit.
const double _kColorfulnessScale = 43.0;

/// Coordinates in a Euclidean CAM16-UCS-style space.
class Cam16V11UcsCoordinates {
  final double j;
  final double a;
  final double b;

  const Cam16V11UcsCoordinates(this.j, this.a, this.b);

  double distance(Cam16V11UcsCoordinates other) {
    final dJ = j - other.j;
    final dA = a - other.a;
    final dB = b - other.b;
    return math.sqrt(dJ * dJ + dA * dA + dB * dB);
  }
}

/// Hellwig/Fairchild 2022 revision of CAM16.
///
/// This intentionally forks the legacy [Cam16] implementation rather than
/// branching inside it. Hue still comes from the CAT16 opponent dimensions, but
/// brightness, colorfulness, chroma, saturation, and UCS coordinates follow the
/// revised equations.
class Cam16V11 {
  /// Like red, orange, yellow, green, etc.
  final double hue;

  /// Chroma, relative to the adapted white/context.
  final double chroma;

  /// Lightness.
  final double j;

  /// Brightness; ratio of lightness to white point's lightness
  final double q;

  /// Colorfulness
  final double m;

  /// Saturation; ratio of chroma to white point's chroma
  final double s;

  /// Relative CAM16 v11 UCS J' coordinate.
  final double jstar;

  /// Relative CAM16 v11 UCS a' coordinate.
  final double astar;

  /// Relative CAM16 v11 UCS b' coordinate.
  final double bstar;

  /// All of the CAM16 dimensions can be calculated from 3 of the dimensions, in
  /// the following combinations:
  ///     -  {j or q} and {c, m, or s} and hue
  ///     - jstar, astar, bstar
  /// Prefer using a static method that constructs from 3 of those dimensions.
  /// This constructor is intended for those methods to use to return all
  /// possible dimensions.
  Cam16V11(
    this.hue,
    this.chroma,
    this.j,
    this.q,
    this.m,
    this.s,
    this.jstar,
    this.astar,
    this.bstar,
  );

  /// Relative v11 UCS coordinates J'a'b'.
  Cam16V11UcsCoordinates relativeUcs() =>
      Cam16V11UcsCoordinates(jstar, astar, bstar);

  /// Absolute v11 UCS coordinates Q'p't'.
  Cam16V11UcsCoordinates absoluteUcs() {
    final hRad = hue * math.pi / 180.0;
    final qPrime = 0.86 * 1.7 * q / (1.0 + 0.007 * j);
    final mPrime = 2.0 * math.log(1.0 + 0.094 * m) / 0.094;
    return Cam16V11UcsCoordinates(
      qPrime,
      mPrime * math.cos(hRad),
      mPrime * math.sin(hRad),
    );
  }

  /// Euclidean distance in relative CAM16 v11 UCS. Unlike legacy CAM16-UCS,
  /// v11 distances are not compressed with `1.41 * dEPrime^0.63`.
  double distance(Cam16V11 other) =>
      relativeUcs().distance(other.relativeUcs());

  /// Distance in absolute CAM16 v11 UCS.
  double absoluteDistance(Cam16V11 other) =>
      absoluteUcs().distance(other.absoluteUcs());

  /// Convert [argb] to CAM16 v11, assuming default viewing conditions.
  static Cam16V11 fromInt(int argb) {
    return fromIntInViewingConditions(argb, Cam16V11ViewingConditions.sRgb);
  }

  /// Given [viewingConditions], convert [argb] to CAM16 v11.
  static Cam16V11 fromIntInViewingConditions(
      int argb, Cam16V11ViewingConditions viewingConditions) {
    final r = linear(redFromArgb(argb));
    final g = linear(greenFromArgb(argb));
    final b = linear(blueFromArgb(argb));
    const m = kSrgbToXyz;
    final x = r * m[0][0] + g * m[0][1] + b * m[0][2];
    final y = r * m[1][0] + g * m[1][1] + b * m[1][2];
    final z = r * m[2][0] + g * m[2][1] + b * m[2][2];
    return fromXyzInViewingConditions(x, y, z, viewingConditions);
  }

  /// Given color expressed in XYZ and viewed in [viewingConditions], convert to
  /// CAM16 v11.
  static Cam16V11 fromXyzInViewingConditions(double x, double y, double z,
      Cam16V11ViewingConditions viewingConditions) {
    // Transform XYZ to 'cone'/'rgb' responses
    final rC = 0.401288 * x + 0.650173 * y - 0.051461 * z;
    final gC = -0.250268 * x + 1.204414 * y + 0.045854 * z;
    final bC = -0.002079 * x + 0.048952 * y + 0.953127 * z;

    // Discount illuminant
    final rD = viewingConditions.rgbD[0] * rC;
    final gD = viewingConditions.rgbD[1] * gC;
    final bD = viewingConditions.rgbD[2] * bC;

    // chromatic adaptation
    final rAF =
        math.pow(viewingConditions.fl * rD.abs() / 100.0, 0.42).toDouble();
    final gAF =
        math.pow(viewingConditions.fl * gD.abs() / 100.0, 0.42).toDouble();
    final bAF =
        math.pow(viewingConditions.fl * bD.abs() / 100.0, 0.42).toDouble();
    final rA = signum(rD) * 400.0 * rAF / (rAF + 27.13);
    final gA = signum(gD) * 400.0 * gAF / (gAF + 27.13);
    final bA = signum(bD) * 400.0 * bAF / (bAF + 27.13);

    // redness-greenness
    final a = (11.0 * rA + -12.0 * gA + bA) / 11.0;
    // yellowness-blueness
    final b = (rA + gA - 2.0 * bA) / 9.0;

    // Hue.
    final atan2 = math.atan2(b, a);
    final atanDegrees = atan2 * 180.0 / math.pi;
    final hue = atanDegrees < 0
        ? atanDegrees + 360.0
        : atanDegrees >= 360
            ? atanDegrees - 360
            : atanDegrees;
    final hueRadians = hue * math.pi / 180.0;
    assert(hue >= 0 && hue < 360, 'hue was really $hue');

    // Revised achromatic response. Colour's Hellwig2022 implementation adds
    // 0.1 during response compression and subtracts 0.305 here. This port keeps
    // adapted responses offset-free, so the equivalent expression omits both.
    final ac = 2.0 * rA + gA + 0.05 * bA;

    final J = 100.0 *
        math.pow(ac / viewingConditions.aw,
            viewingConditions.c * viewingConditions.z);
    final Q = (2.0 / viewingConditions.c) * (J / 100.0) * viewingConditions.aw;

    // eHue scales reported C/M; it does not change the CAT16 opponent hue.
    final eHue = hueEccentricity(hueRadians);
    final opponentMagnitude = math.sqrt(a * a + b * b);
    final M =
        _kColorfulnessScale * viewingConditions.nC * eHue * opponentMagnitude;
    final C = 35.0 * M / viewingConditions.aw;
    final saturation = Q == 0.0 ? 0.0 : 100.0 * M / Q;

    final (jstar, astar, bstar) = _relativeUcsFromJch(J, C, hueRadians);
    return Cam16V11(hue, C, J, Q, M, saturation, jstar, astar, bstar);
  }

  /// Revised hue eccentricity function. [hueRadians] must be in radians.
  static double hueEccentricity(double hueRadians) {
    final h = hueRadians;
    // Keep this polynomial verbatim with Colour's Hellwig2022 implementation;
    // the first cosine sign is easy to transpose from older CAM16 drafts.
    return 1.0 +
        -0.0582 * math.cos(h) -
        0.0258 * math.cos(2.0 * h) -
        0.1347 * math.cos(3.0 * h) +
        0.0289 * math.cos(4.0 * h) -
        0.1475 * math.sin(h) -
        0.0308 * math.sin(2.0 * h) +
        0.0385 * math.sin(3.0 * h) +
        0.0096 * math.sin(4.0 * h);
  }

  static (double, double, double) _relativeUcsFromJch(
      double J, double C, double hueRadians) {
    final jstar = 1.7 * J / (1.0 + 0.007 * J);
    final cstar = 2.4 * math.log(1.0 + 0.098 * C) / 0.098;
    final astar = cstar * math.cos(hueRadians);
    final bstar = cstar * math.sin(hueRadians);
    return (jstar, astar, bstar);
  }

  /// Create a CAM16 v11 color from lightness [j], chroma [c], and hue [h],
  /// assuming default viewing conditions.
  static Cam16V11 fromJch(double j, double c, double h) {
    return fromJchInViewingConditions(j, c, h, Cam16V11ViewingConditions.sRgb);
  }

  /// Create a CAM16 v11 color from lightness [j], chroma [c], and hue [h], in
  /// [viewingConditions].
  static Cam16V11 fromJchInViewingConditions(double J, double C, double h,
      Cam16V11ViewingConditions viewingConditions) {
    final Q = (2.0 / viewingConditions.c) * (J / 100.0) * viewingConditions.aw;
    final M = C * viewingConditions.aw / 35.0;
    final s = Q == 0.0 ? 0.0 : 100.0 * M / Q;

    final hueRadians = h * math.pi / 180.0;
    final (jstar, astar, bstar) = _relativeUcsFromJch(J, C, hueRadians);
    return Cam16V11(h, C, J, Q, M, s, jstar, astar, bstar);
  }

  /// Create a CAM16 v11 color from relative UCS coordinates J'a'b'.
  static Cam16V11 fromUcs(double jstar, double astar, double bstar) {
    return fromUcsInViewingConditions(
        jstar, astar, bstar, Cam16V11ViewingConditions.standard);
  }

  /// Create a CAM16 v11 color from relative UCS coordinates J'a'b' in
  /// [viewingConditions].
  static Cam16V11 fromUcsInViewingConditions(double jstar, double astar,
      double bstar, Cam16V11ViewingConditions viewingConditions) {
    final cstar = math.sqrt(astar * astar + bstar * bstar);
    final C = (math.exp(cstar * 0.098 / 2.4) - 1.0) / 0.098;
    var h = math.atan2(bstar, astar) * (180.0 / math.pi);
    if (h < 0.0) {
      h += 360.0;
    }
    final J = jstar / (1.7 - 0.007 * jstar);

    return Cam16V11.fromJchInViewingConditions(J, C, h, viewingConditions);
  }

  /// ARGB representation of color, assuming the color was viewed in default
  /// viewing conditions.
  int toInt() {
    return viewed(Cam16V11ViewingConditions.sRgb);
  }

  // Avoid allocations during conversion by pre-allocating an array.
  final _viewedArray = <double>[0, 0, 0];

  /// ARGB representation of a color, given the color was viewed in
  /// [viewingConditions].
  int viewed(Cam16V11ViewingConditions viewingConditions) {
    final xyz = xyzInViewingConditions(viewingConditions, array: _viewedArray);
    final argb = argbFromXyz(xyz[0], xyz[1], xyz[2]);
    return argb;
  }

  /// XYZ representation of CAM16 v11 seen in [viewingConditions].
  List<double> xyzInViewingConditions(
      Cam16V11ViewingConditions viewingConditions,
      {List<double>? array}) {
    final hRad = hue * math.pi / 180.0;
    final hSin = math.sin(hRad);
    final hCos = math.cos(hRad);

    final M = chroma * viewingConditions.aw / 35.0;
    // Inverting divides by the same eHue factor applied in fromXyz..., so
    // source-seeded palettes mostly treat eccentricity as a chroma unit scale.
    final eHue = hueEccentricity(hRad);
    final opponentMagnitude = (M == 0.0 || eHue == 0.0)
        ? 0.0
        : M / (_kColorfulnessScale * viewingConditions.nC * eHue);
    final a = opponentMagnitude * hCos;
    final b = opponentMagnitude * hSin;

    final ac = viewingConditions.aw *
        math.pow(j / 100.0, 1.0 / viewingConditions.c / viewingConditions.z);
    final p2 = ac;

    final rA = (460.0 * p2 + 451.0 * a + 288.0 * b) / 1403.0;
    final gA = (460.0 * p2 - 891.0 * a - 261.0 * b) / 1403.0;
    final bA = (460.0 * p2 - 220.0 * a - 6300.0 * b) / 1403.0;

    final rC = _inverseAdaptedResponse(rA, viewingConditions.fl);
    final gC = _inverseAdaptedResponse(gA, viewingConditions.fl);
    final bC = _inverseAdaptedResponse(bA, viewingConditions.fl);
    final rF = rC / viewingConditions.rgbD[0];
    final gF = gC / viewingConditions.rgbD[1];
    final bF = bC / viewingConditions.rgbD[2];

    final x = 1.86206786 * rF - 1.01125463 * gF + 0.14918677 * bF;
    final y = 0.38752654 * rF + 0.62144744 * gF - 0.00897398 * bF;
    final z = -0.01584150 * rF - 0.03412294 * gF + 1.04996444 * bF;

    if (array != null) {
      array[0] = x;
      array[1] = y;
      array[2] = z;
      return array;
    } else {
      return [x, y, z];
    }
  }

  static double _inverseAdaptedResponse(double adapted, double fl) {
    final adaptedAbs = adapted.abs();
    final denominator = 400.0 - adaptedAbs;
    if (denominator <= 0.0) {
      return 0.0;
    }
    final base = math.max(0.0, (27.13 * adaptedAbs) / denominator);
    return signum(adapted) * (100.0 / fl) * math.pow(base, 1.0 / 0.42);
  }
}
