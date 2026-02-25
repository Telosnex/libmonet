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

import 'dart:math';

import 'package:libmonet/colorspaces/gamut.dart';
import 'package:libmonet/core/argb_srgb_xyz_lab.dart';
import 'package:libmonet/colorspaces/cam16.dart';
import 'package:libmonet/colorspaces/cam16_viewing_conditions.dart';
import 'package:libmonet/core/math.dart';

/// A class that solves the HCT equation.
///
/// Can solve for any RGB gamut by passing a [Gamut] parameter. Defaults to
/// sRGB for backward compatibility.
class HctSolver {
  /// Sanitizes a small enough angle in radians.
  ///
  /// [angle] An angle in radians; must not deviate too much from 0.
  /// Returns A coterminal angle between 0 and 2pi.
  static double _sanitizeRadians(double angle) {
    return (angle + pi * 8) % (pi * 2);
  }

  /// CAM16 chromatic adaptation.
  /// Constants 400.0, 27.13, and 0.42 are from the CAM16 specification.
  /// See: https://observablehq.com/@jrus/cam16
  static double _chromaticAdaptation(double component) {
    final af = pow(component.abs(), 0.42).toDouble();
    return signum(component) * 400.0 * af / (af + 27.13);
  }

  /// Returns the hue of [r] [g] [b], a linear RGB color, in CAM16, in
  /// radians.
  static double _hueOfComponents(
      double r, double g, double b, Gamut gamut) {
    final matrix = gamut.scaledDiscountFromLinrgb;
    final scaledDiscountR =
        r * matrix[0][0] + g * matrix[0][1] + b * matrix[0][2];
    final scaledDiscountG =
        r * matrix[1][0] + g * matrix[1][1] + b * matrix[1][2];
    final scaledDiscountB =
        r * matrix[2][0] + g * matrix[2][1] + b * matrix[2][2];
    final rA = _chromaticAdaptation(scaledDiscountR);
    final gA = _chromaticAdaptation(scaledDiscountG);
    final bA = _chromaticAdaptation(scaledDiscountB);
    // redness-greenness
    final aP = (11.0 * rA + -12.0 * gA + bA) / 11.0;
    // yellowness-blueness
    final bP = (rA + gA - 2.0 * bA) / 9.0;
    return atan2(bP, aP);
  }

  static bool _areInCyclicOrder(double a, double b, double c) {
    final deltaAB = _sanitizeRadians(b - a);
    final deltaAC = _sanitizeRadians(c - a);
    return deltaAB < deltaAC;
  }

  /// Solves the lerp equation.
  ///
  /// Returns a number t such that lerp([source], [target], t) =
  /// [mid].
  static double _intercept(double source, double mid, double target) {
    return (mid - source) / (target - source);
  }

  static bool _isBounded(double x) {
    return 0.0 <= x && x <= 100.0;
  }

  static int _criticalPlaneBelow(double x) {
    return (x - 0.5).floor();
  }

  static int _criticalPlaneAbove(double x) {
    return (x - 0.5).ceil();
  }

  static double _inverseChromaticAdaptation(double adapted) {
    final adaptedAbs = adapted.abs();
    final base = max(0.0, 27.13 * adaptedAbs / (400.0 - adaptedAbs));
    return signum(adapted) * pow(base, 1.0 / 0.42).toDouble();
  }

  /// Finds a color with the given hue, chroma, and Y.
  ///
  /// Returns a color with the desired [hueRadians], [chroma], and
  /// [y] as linear RGB components (r, g, b) in [0..100], if found;
  /// and returns null otherwise.
  ///
  /// Uses Newton's method to iteratively refine J (lightness in CAM16).
  /// Always returns within 5 iterations: either converges (error < 0.002)
  /// or returns the best approximation on iteration 4.
  static (double, double, double)? _findResultByJ(
      double hueRadians, double chroma, double y, Gamut gamut) {
    // Initial estimate of j.
    var j = sqrt(y) * 11.0;
    // ===========================================================
    // Operations inlined from Cam16 to avoid repeated calculation
    // ===========================================================
    final viewingConditions = Cam16ViewingConditions.standard;
    // CAM16 constants: 1.64, 0.29, 0.73 are from the CAM16 specification
    final tInnerCoeff = 1 /
        pow(
          1.64 -
              pow(0.29, viewingConditions.backgroundYToWhitePointY).toDouble(),
          0.73,
        ).toDouble();
    final eHue = 0.25 * (cos(hueRadians + 2.0) + 3.8);
    final p1 =
        eHue * (50000.0 / 13.0) * viewingConditions.nC * viewingConditions.ncb;
    final hSin = sin(hueRadians);
    final hCos = cos(hueRadians);
    for (var iterationRound = 0; iterationRound < 5; iterationRound++) {
      // ===========================================================
      // Operations inlined from Cam16 to avoid repeated calculation
      // ===========================================================
      final jNormalized = j / 100.0;
      final alpha =
          chroma == 0.0 || j == 0.0 ? 0.0 : chroma / sqrt(jNormalized);
      final t = pow(alpha * tInnerCoeff, 1.0 / 0.9).toDouble();
      final ac = viewingConditions.aw *
          pow(
            jNormalized,
            1.0 / viewingConditions.c / viewingConditions.z,
          ).toDouble();
      final p2 = ac / viewingConditions.nbb;
      final gamma = 23.0 *
          (p2 + 0.305) *
          t /
          (23.0 * p1 + 11 * t * hCos + 108.0 * t * hSin);
      final a = gamma * hCos;
      final b = gamma * hSin;
      final rA = (460.0 * p2 + 451.0 * a + 288.0 * b) / 1403.0;
      final gA = (460.0 * p2 - 891.0 * a - 261.0 * b) / 1403.0;
      final bA = (460.0 * p2 - 220.0 * a - 6300.0 * b) / 1403.0;
      final rCScaled = _inverseChromaticAdaptation(rA);
      final gCScaled = _inverseChromaticAdaptation(gA);
      final bCScaled = _inverseChromaticAdaptation(bA);
      final matrix = gamut.linrgbFromScaledDiscount;
      final linR = rCScaled * matrix[0][0] +
          gCScaled * matrix[0][1] +
          bCScaled * matrix[0][2];
      final linG = rCScaled * matrix[1][0] +
          gCScaled * matrix[1][1] +
          bCScaled * matrix[1][2];
      final linB = rCScaled * matrix[2][0] +
          gCScaled * matrix[2][1] +
          bCScaled * matrix[2][2];
      // ===========================================================
      // Operations inlined from Cam16 to avoid repeated calculation
      // ===========================================================
      if (linR < 0 || linG < 0 || linB < 0) {
        return null;
      }
      final kR = gamut.yFromLinrgb[0];
      final kG = gamut.yFromLinrgb[1];
      final kB = gamut.yFromLinrgb[2];
      final fnj = kR * linR + kG * linG + kB * linB;
      if (fnj <= 0) {
        return null;
      }
      if (iterationRound == 4 || (fnj - y).abs() < 0.002) {
        if (linR > 100.01 || linG > 100.01 || linB > 100.01) {
          return null;
        }
        return (linR, linG, linB);
      }
      // Newton's method: j_next = j - f(j)/f'(j)
      // Using 2 * f(j) / j as the approximation of f'(j)
      j = j - (fnj - y) * j / (2 * fnj);
    }
    // Unreachable: loop always returns on iterationRound == 4
    return null;
  }

  /// Finds an sRGB color with the given hue, chroma, and L*, if
  /// possible.
  ///
  /// Returns a hexadecimal representing a sRGB color with its hue,
  /// chroma, and L* sufficiently close to [hueDegrees], [chroma], and
  /// [lstar], respectively. If it is impossible to satisfy all three
  /// constraints, the hue and L* will be sufficiently close, and the
  /// chroma will be maximized.
  static int solveToInt(double hueDegrees, double chroma, double lstar) {
    final linrgb = solveToLinrgb(hueDegrees, chroma, lstar, gamut: Gamut.srgb);
    return argbFromLinrgbComponents(linrgb.$1, linrgb.$2, linrgb.$3);
  }

  /// Solves for the linear RGB color with the given hue, chroma, and L* in
  /// the specified [gamut].
  ///
  /// Returns `(r, g, b)` in linear RGB space [0..100] for the given gamut.
  /// The hue and L* will be preserved; if the requested chroma exceeds what
  /// the gamut can represent, it will be reduced to the gamut boundary.
  ///
  /// To get display-encoded values in [0..1], use:
  /// ```dart
  /// final (r, g, b) = HctSolver.solveToLinrgb(h, c, t, gamut: Gamut.displayP3);
  /// final displayR = gamut.trueDelinearize(r) / 255.0;
  /// ```
  static (double, double, double) solveToLinrgb(
    double hueDegrees,
    double chroma,
    double lstar, {
    Gamut? gamut,
  }) {
    gamut ??= Gamut.srgb;

    if (chroma < 0.0001 || lstar < 0.0001 || lstar > 99.9999) {
      // Achromatic: solve for the gray that matches L*
      final y = yFromLstar(lstar);
      // Find the linear component value that produces this Y in the gamut.
      // For any gamut, Y = kR*R + kG*G + kB*B. For gray, R=G=B=v.
      // So v = Y / (kR + kG + kB). Since the Y row should sum to 1.0
      // for a D65 gamut, v = Y.
      final kSum =
          gamut.yFromLinrgb[0] + gamut.yFromLinrgb[1] + gamut.yFromLinrgb[2];
      final v = y / kSum;
      return (v, v, v);
    }
    hueDegrees = sanitizeDegreesDouble(hueDegrees);
    final hueRadians = hueDegrees / 180 * pi;
    final y = yFromLstar(lstar);
    final exactAnswer = _findResultByJ(hueRadians, chroma, y, gamut);
    if (exactAnswer != null) {
      return exactAnswer;
    }

    // =========================================================================
    // No-allocation pattern: nested functions share state via outer scope
    // variables instead of allocating tuples/lists. This creates deep nesting
    // (bisectToLimit -> bisectToSegment -> nthVertex) but avoids GC pressure.
    // =========================================================================

    /// Finds a color with the given Y and hue on the boundary of the
    /// cube.
    ///
    /// Returns the color with the desired Y value [y] and hue
    /// [targetHue], in linear RGB coordinates.
    (double, double, double) bisectToLimit(double y, double targetHue) {
      var bisectToSegmentLeft0 = -1.0;
      var bisectToSegmentLeft1 = -1.0;
      var bisectToSegmentLeft2 = -1.0;
      var bisectToSegmentRight0 = -1.0;
      var bisectToSegmentRight1 = -1.0;
      var bisectToSegmentRight2 = -1.0;
      var bisectToSegmentMid0 = -1.0;
      var bisectToSegmentMid1 = -1.0;
      var bisectToSegmentMid2 = -1.0;

      /// Finds the segment containing the desired color.
      ///
      /// Given a plane Y = [y] and a desired [target_hue], returns the
      /// segment containing the desired color, represented as an array of
      /// its two endpoints.
      void bisectToSegment(double y, double targetHue) {
        /// Returns the nth possible vertex of the polygonal intersection.
        ///
        /// Given a plane Y = [y] and an zero-based index [n] such that 0
        /// <= [n] <= 11, returns the nth possible vertex of the polygonal
        /// intersection of the plane and the RGB cube, in linear RGB
        /// coordinates, if it exists.
        /// If this possible vertex lies outside of the cube, [-1.0, -1.0,
        /// -1.0] is returned.
        void nthVertex(double y, int n) {
          final kR = gamut!.yFromLinrgb[0];
          final kG = gamut.yFromLinrgb[1];
          final kB = gamut.yFromLinrgb[2];
          final coordA = n % 4 <= 1 ? 0.0 : 100.0;
          final coordB = n % 2 == 0 ? 0.0 : 100.0;
          if (n < 4) {
            final g = coordA;
            final b = coordB;
            final r = (y - g * kG - b * kB) / kR;
            if (_isBounded(r)) {
              bisectToSegmentMid0 = r;
              bisectToSegmentMid1 = g;
              bisectToSegmentMid2 = b;
            } else {
              bisectToSegmentMid0 = -1.0;
              bisectToSegmentMid1 = -1.0;
              bisectToSegmentMid2 = -1.0;
            }
          } else if (n < 8) {
            final b = coordA;
            final r = coordB;
            final g = (y - r * kR - b * kB) / kG;
            if (_isBounded(g)) {
              bisectToSegmentMid0 = r;
              bisectToSegmentMid1 = g;
              bisectToSegmentMid2 = b;
            } else {
              bisectToSegmentMid0 = -1.0;
              bisectToSegmentMid1 = -1.0;
              bisectToSegmentMid2 = -1.0;
            }
          } else {
            final r = coordA;
            final g = coordB;
            final b = (y - r * kR - g * kG) / kB;
            if (_isBounded(b)) {
              bisectToSegmentMid0 = r;
              bisectToSegmentMid1 = g;
              bisectToSegmentMid2 = b;
            } else {
              bisectToSegmentMid0 = -1.0;
              bisectToSegmentMid1 = -1.0;
              bisectToSegmentMid2 = -1.0;
            }
          }
        }

        var leftHue = 0.0;
        var rightHue = 0.0;
        var initialized = false;
        var uncut = true;
        for (var n = 0; n < 12; n++) {
          nthVertex(y, n);
          if (bisectToSegmentMid0 < 0) {
            continue;
          }
          final midHue = _hueOfComponents(
              bisectToSegmentMid0, bisectToSegmentMid1, bisectToSegmentMid2,
              gamut!);
          if (!initialized) {
            bisectToSegmentLeft0 = bisectToSegmentMid0;
            bisectToSegmentLeft1 = bisectToSegmentMid1;
            bisectToSegmentLeft2 = bisectToSegmentMid2;
            bisectToSegmentRight0 = bisectToSegmentMid0;
            bisectToSegmentRight1 = bisectToSegmentMid1;
            bisectToSegmentRight2 = bisectToSegmentMid2;

            leftHue = midHue;
            rightHue = midHue;
            initialized = true;
            continue;
          }
          if (uncut || _areInCyclicOrder(leftHue, midHue, rightHue)) {
            uncut = false;
            if (_areInCyclicOrder(leftHue, targetHue, midHue)) {
              bisectToSegmentRight0 = bisectToSegmentMid0;
              bisectToSegmentRight1 = bisectToSegmentMid1;
              bisectToSegmentRight2 = bisectToSegmentMid2;
              rightHue = midHue;
            } else {
              bisectToSegmentLeft0 = bisectToSegmentMid0;
              bisectToSegmentLeft1 = bisectToSegmentMid1;
              bisectToSegmentLeft2 = bisectToSegmentMid2;
              leftHue = midHue;
            }
          }
        }
      }

      bisectToSegment(y, targetHue);

      var bisectToLimitLeft0 = bisectToSegmentLeft0;
      var bisectToLimitLeft1 = bisectToSegmentLeft1;
      var bisectToLimitLeft2 = bisectToSegmentLeft2;
      var leftHue = _hueOfComponents(
          bisectToLimitLeft0, bisectToLimitLeft1, bisectToLimitLeft2, gamut!);
      var bisectToLimitRight0 = bisectToSegmentRight0;
      var bisectToLimitRight1 = bisectToSegmentRight1;
      var bisectToLimitRight2 = bisectToSegmentRight2;

      var bisectToLimitMid0 = -1.0;
      var bisectToLimitMid1 = -1.0;
      var bisectToLimitMid2 = -1.0;

      for (var axis = 0; axis < 3; axis++) {
        // The default cases below are unreachable since axis is always 0, 1, or 2.
        // StateError is thrown (rather than returning a dummy value) to fail fast
        // if the loop bounds ever change, satisfying both exhaustiveness checking
        // and defensive programming practices.
        var leftForAxis = switch (axis) {
          0 => bisectToLimitLeft0,
          1 => bisectToLimitLeft1,
          2 => bisectToLimitLeft2,
          _ => throw StateError('unreachable: axis must be 0, 1, or 2')
        };
        var rightForAxis = switch (axis) {
          0 => bisectToLimitRight0,
          1 => bisectToLimitRight1,
          2 => bisectToLimitRight2,
          _ => throw StateError('unreachable: axis must be 0, 1, or 2')
        };
        if (leftForAxis != rightForAxis) {
          var lPlane = -1;
          var rPlane = 255;
          if (leftForAxis < rightForAxis) {
            lPlane = _criticalPlaneBelow(
                gamut.trueDelinearize(leftForAxis));
            rPlane = _criticalPlaneAbove(
                gamut.trueDelinearize(rightForAxis));
          } else {
            lPlane = _criticalPlaneAbove(
                gamut.trueDelinearize(leftForAxis));
            rPlane = _criticalPlaneBelow(
                gamut.trueDelinearize(rightForAxis));
          }
          for (var i = 0; i < 8; i++) {
            if ((rPlane - lPlane).abs() <= 1) {
              break;
            } else {
              final mPlane = ((lPlane + rPlane) / 2.0).floor();
              final midPlaneCoordinate = gamut.criticalPlanes[mPlane];
              void setCoordinate2(int axis, double sourceAxisValue,
                  double coordinate, double targetAxisValue) {
                double lerpPoint(double source, double t, double target) {
                  return source + (target - source) * t;
                }

                final t =
                    _intercept(sourceAxisValue, coordinate, targetAxisValue);
                if (axis == 0) {
                  bisectToLimitMid0 =
                      lerpPoint(bisectToLimitLeft0, t, bisectToLimitRight0);
                } else if (axis == 1) {
                  bisectToLimitMid1 =
                      lerpPoint(bisectToLimitLeft1, t, bisectToLimitRight1);
                } else if (axis == 2) {
                  bisectToLimitMid2 =
                      lerpPoint(bisectToLimitLeft2, t, bisectToLimitRight2);
                }
              }

              for (var axis2 = 0; axis2 < 3; axis2++) {
                setCoordinate2(
                    axis2, leftForAxis, midPlaneCoordinate, rightForAxis);
              }
              final midHue = _hueOfComponents(
                  bisectToLimitMid0, bisectToLimitMid1, bisectToLimitMid2,
                  gamut);
              if (_areInCyclicOrder(leftHue, targetHue, midHue)) {
                bisectToLimitRight0 = bisectToLimitMid0;
                bisectToLimitRight1 = bisectToLimitMid1;
                bisectToLimitRight2 = bisectToLimitMid2;
                rPlane = mPlane;
              } else {
                bisectToLimitLeft0 = bisectToLimitMid0;
                bisectToLimitLeft1 = bisectToLimitMid1;
                bisectToLimitLeft2 = bisectToLimitMid2;
                leftHue = midHue;
                lPlane = mPlane;
              }
            }
          }
        }
      }

      final r = (bisectToLimitLeft0 + bisectToLimitRight0) / 2;
      final g = (bisectToLimitLeft1 + bisectToLimitRight1) / 2;
      final b = (bisectToLimitLeft2 + bisectToLimitRight2) / 2;

      return (r, g, b);
    }

    return bisectToLimit(y, hueRadians);
  }

  /// Solves for the display-encoded RGB color in [0..1] for the given [gamut].
  ///
  /// This is the primary method for wide gamut use. Returns `(r, g, b)` where
  /// each component is in [0..1], display-encoded using the gamut's transfer
  /// function.
  ///
  /// Example:
  /// ```dart
  /// final (r, g, b) = HctSolver.solveToDisplayRgb(
  ///   120.0, 50.0, 60.0,
  ///   gamut: Gamut.displayP3,
  /// );
  /// // r, g, b are in [0..1], suitable for color(display-p3 r g b)
  /// ```
  static (double, double, double) solveToDisplayRgb(
    double hueDegrees,
    double chroma,
    double lstar, {
    Gamut? gamut,
  }) {
    gamut ??= Gamut.srgb;
    final (linR, linG, linB) =
        solveToLinrgb(hueDegrees, chroma, lstar, gamut: gamut);
    return (
      (gamut.trueDelinearize(linR) / 255.0).clamp(0.0, 1.0),
      (gamut.trueDelinearize(linG) / 255.0).clamp(0.0, 1.0),
      (gamut.trueDelinearize(linB) / 255.0).clamp(0.0, 1.0),
    );
  }

  /// Finds a CAM16 object with the given hue, chroma, and L*, if
  /// possible.
  ///
  /// Returns a CAM16 object representing a sRGB color with its hue,
  /// chroma, and L* sufficiently close to [hueDegrees], [chroma], and
  /// [lstar], respectively. If it is impossible to satisfy all three
  /// constraints, the hue and L* will be sufficiently close, and the
  /// chroma will be maximized.
  static Cam16 solveToCam(double hueDegrees, double chroma, double lstar) {
    return Cam16.fromInt(solveToInt(hueDegrees, chroma, lstar));
  }
}
