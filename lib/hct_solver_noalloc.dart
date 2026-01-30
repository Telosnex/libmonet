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

import 'package:libmonet/argb_srgb_xyz_lab.dart';
import 'package:libmonet/cam16.dart';
import 'package:libmonet/cam16_viewing_conditions.dart';
import 'package:libmonet/math.dart';

/// A class that solves the HCT equation.
class HctSolverNoAlloc {
  /// Sanitizes a small enough angle in radians.
  ///
  /// [angle] An angle in radians; must not deviate too much from 0.
  /// Returns A coterminal angle between 0 and 2pi.
  static double _sanitizeRadians(double angle) {
    return (angle + pi * 8) % (pi * 2);
  }

  /// Delinearizes an RGB component, returning a floating-point
  /// number.
  ///
  /// 0.0 <= [rgbComponent] <= 100.0 represents linear R/G/B channel.
  /// 0.0 <= output <= 255.0, color channel converted to regular RGB
  /// space.
  static double _trueDelinearized(double rgbComponent) {
    final normalized = rgbComponent / 100.0;
    var delinearized = 0.0;
    if (normalized <= 0.0031308) {
      delinearized = normalized * 12.92;
    } else {
      delinearized = 1.055 * pow(normalized, 1.0 / 2.4).toDouble() - 0.055;
    }
    return delinearized * 255.0;
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
  static double _hueOfComponents(double r, double g, double b) {
    const matrix = _scaledDiscountFromLinrgb;
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
  /// [y] as a hexadecimal integer, if found; and returns 0 otherwise.
  ///
  /// Uses Newton's method to iteratively refine J (lightness in CAM16).
  /// Always returns within 5 iterations: either converges (error < 0.002)
  /// or returns the best approximation on iteration 4.
  static int _findResultByJ(double hueRadians, double chroma, double y) {
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
      const matrix = _linrgbFromScaledDiscount;
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
        return 0;
      }
      final kR = _yFromLinrgb[0];
      final kG = _yFromLinrgb[1];
      final kB = _yFromLinrgb[2];
      final fnj = kR * linR + kG * linG + kB * linB;
      if (fnj <= 0) {
        return 0;
      }
      if (iterationRound == 4 || (fnj - y).abs() < 0.002) {
        if (linR > 100.01 || linG > 100.01 || linB > 100.01) {
          return 0;
        }
        return argbFromLinrgbComponents(linR, linG, linB);
      }
      // Newton's method: j_next = j - f(j)/f'(j)
      // Using 2 * f(j) / j as the approximation of f'(j)
      j = j - (fnj - y) * j / (2 * fnj);
    }
    // Unreachable: loop always returns on iterationRound == 4
    return 0;
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
    if (chroma < 0.0001 || lstar < 0.0001 || lstar > 99.9999) {
      return argbFromLstar(lstar);
    }
    hueDegrees = sanitizeDegreesDouble(hueDegrees);
    final hueRadians = hueDegrees / 180 * pi;
    final y = yFromLstar(lstar);
    final exactAnswer = _findResultByJ(hueRadians, chroma, y);
    if (exactAnswer != 0) {
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
    int bisectToLimit(double y, double targetHue) {
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
          final kR = _yFromLinrgb[0];
          final kG = _yFromLinrgb[1];
          final kB = _yFromLinrgb[2];
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
              bisectToSegmentMid0, bisectToSegmentMid1, bisectToSegmentMid2);
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
          bisectToLimitLeft0, bisectToLimitLeft1, bisectToLimitLeft2);
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
            lPlane = _criticalPlaneBelow(_trueDelinearized(leftForAxis));
            rPlane = _criticalPlaneAbove(_trueDelinearized(rightForAxis));
          } else {
            lPlane = _criticalPlaneAbove(_trueDelinearized(leftForAxis));
            rPlane = _criticalPlaneBelow(_trueDelinearized(rightForAxis));
          }
          for (var i = 0; i < 8; i++) {
            if ((rPlane - lPlane).abs() <= 1) {
              break;
            } else {
              final mPlane = ((lPlane + rPlane) / 2.0).floor();
              final midPlaneCoordinate = _criticalPlanes[mPlane];
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
                  bisectToLimitMid0, bisectToLimitMid1, bisectToLimitMid2);
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

      return argbFromLinrgbComponents(r, g, b);
    }

    return bisectToLimit(y, hueRadians);
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

/// Precomputed linear RGB values for sRGB integer boundaries.
///
/// ## What problem does this solve?
///
/// Picture the RGB cube: a 3D box where each corner is a color (black, white,
/// red, green, blue, cyan, magenta, yellow). When finding the most saturated
/// displayable color for a given hue and lightness, we trace a line through
/// this cube and find where it exits—that exit point is our answer.
///
/// The cube's walls are at R, G, or B = 0 or 255. To binary search along an
/// edge efficiently, we need to know where each integer step (0, 1, 2...255)
/// lands. Here's the catch: color math happens in *linear* RGB, but the cube's
/// edges are defined in *sRGB* (gamma-corrected). Gamma correction bunches
/// values together near black and spreads them out near white:
///
/// ```
/// sRGB:   |  0 | 1 | 2 | 3 |...| 250| 251| 252| 253| 254| 255|   (even steps)
/// Linear: |▪▪▪▪|▪▪▪|▪▪|▪▪|...|  ▪   |  ▪  |  ▪  |  ▪  |  ▪  |   (uneven steps)
///         ↑ bunched                               spread out ↑
/// ```
///
/// This table stores where each sRGB boundary falls in linear space, so the
/// bisection algorithm can jump directly to these "critical planes" rather
/// than stumbling through the non-linear mapping.
///
/// ## Table details
///
/// - 255 entries (indices 0-254), each at a half-integer: sRGB 0.5, 1.5...254.5
/// - Half-integers sit between adjacent integer boundaries, perfect for bisection
/// - Generated via sRGB linearization: `_criticalPlanes[i] = linearize(i + 0.5)`
///
/// To regenerate, call [generateCriticalPlanes] and copy the output.
const _criticalPlanes = [
  0.015176349177441876,
  0.045529047532325624,
  0.07588174588720938,
  0.10623444424209313,
  0.13658714259697685,
  0.16693984095186062,
  0.19729253930674434,
  0.2276452376616281,
  0.2579979360165119,
  0.28835063437139563,
  0.3188300904430532,
  0.350925934958123,
  0.3848314933096426,
  0.42057480301049466,
  0.458183274052838,
  0.4976837250274023,
  0.5391024159806381,
  0.5824650784040898,
  0.6277969426914107,
  0.6751227633498623,
  0.7244668422128921,
  0.775853049866786,
  0.829304845476233,
  0.8848452951698498,
  0.942497089126609,
  1.0022825574869039,
  1.0642236851973577,
  1.1283421258858297,
  1.1946592148522128,
  1.2631959812511864,
  1.3339731595349034,
  1.407011200216447,
  1.4823302800086415,
  1.5599503113873272,
  1.6398909516233677,
  1.7221716113234105,
  1.8068114625156377,
  1.8938294463134073,
  1.9832442801866852,
  2.075074464868551,
  2.1693382909216234,
  2.2660538449872063,
  2.36523901573795,
  2.4669114995532007,
  2.5710888059345764,
  2.6777882626779785,
  2.7870270208169257,
  2.898822059350997,
  3.0131901897720907,
  3.1301480604002863,
  3.2497121605402226,
  3.3718988244681087,
  3.4967242352587946,
  3.624204428461639,
  3.754355295633311,
  3.887192587735158,
  4.022731918402185,
  4.160988767090289,
  4.301978482107941,
  4.445716283538092,
  4.592217266055746,
  4.741496401646282,
  4.893568542229298,
  5.048448422192488,
  5.20615066083972,
  5.3666897647573375,
  5.5300801301023865,
  5.696336044816294,
  5.865471690767354,
  6.037501145825082,
  6.212438385869475,
  6.390297286737924,
  6.571091626112461,
  6.7548350853498045,
  6.941541251256611,
  7.131223617812143,
  7.323895587840543,
  7.5195704746346665,
  7.7182615035334345,
  7.919981813454504,
  8.124744458384042,
  8.332562408825165,
  8.543448553206703,
  8.757415699253682,
  8.974476575321063,
  9.194643831691977,
  9.417930041841839,
  9.644347703669503,
  9.873909240696694,
  10.106627003236781,
  10.342513269534024,
  10.58158024687427,
  10.8238400726681,
  11.069304815507364,
  11.317986476196008,
  11.569896988756009,
  11.825048221409341,
  12.083451977536606,
  12.345119996613247,
  12.610063955123938,
  12.878295467455942,
  13.149826086772048,
  13.42466730586372,
  13.702830557985108,
  13.984327217668513,
  14.269168601521828,
  14.55736596900856,
  14.848930523210871,
  15.143873411576273,
  15.44220572664832,
  15.743938506781891,
  16.04908273684337,
  16.35764934889634,
  16.66964922287304,
  16.985093187232053,
  17.30399201960269,
  17.62635644741625,
  17.95219714852476,
  18.281524751807332,
  18.614349837764564,
  18.95068293910138,
  19.290534541298456,
  19.633915083172692,
  19.98083495742689,
  20.331304511189067,
  20.685334046541502,
  21.042933821039977,
  21.404114048223256,
  21.76888489811322,
  22.137256497705877,
  22.50923893145328,
  22.884842241736916,
  23.264076429332462,
  23.6469514538663,
  24.033477234264016,
  24.42366364919083,
  24.817520537484558,
  25.21505769858089,
  25.61628489293138,
  26.021211842414342,
  26.429848230738664,
  26.842203703840827,
  27.258287870275353,
  27.678110301598522,
  28.10168053274597,
  28.529008062403893,
  28.96010235337422,
  29.39497283293396,
  29.83362889318845,
  30.276079891419332,
  30.722335150426627,
  31.172403958865512,
  31.62629557157785,
  32.08401920991837,
  32.54558406207592,
  33.010999283389665,
  33.4802739966603,
  33.953417292456834,
  34.430438229418264,
  34.911345834551085,
  35.39614910352207,
  35.88485700094671,
  36.37747846067349,
  36.87402238606382,
  37.37449765026789,
  37.87891309649659,
  38.38727753828926,
  38.89959975977785,
  39.41588851594697,
  39.93615253289054,
  40.460400508064545,
  40.98864111053629,
  41.520882981230194,
  42.05713473317016,
  42.597404951718396,
  43.141702194811224,
  43.6900349931913,
  44.24241185063697,
  44.798841244188324,
  45.35933162437017,
  45.92389141541209,
  46.49252901546552,
  47.065252796817916,
  47.64207110610409,
  48.22299226451468,
  48.808024568002054,
  49.3971762874833,
  49.9904556690408,
  50.587870934119984,
  51.189430279724725,
  51.79514187861014,
  52.40501387947288,
  53.0190544071392,
  53.637271562750364,
  54.259673423945976,
  54.88626804504493,
  55.517063457223934,
  56.15206766869424,
  56.79128866487574,
  57.43473440856916,
  58.08241284012621,
  58.734331877617365,
  59.39049941699807,
  60.05092333227251,
  60.715611475655585,
  61.38457167773311,
  62.057811747619894,
  62.7353394731159,
  63.417162620860914,
  64.10328893648692,
  64.79372614476921,
  65.48848194977529,
  66.18756403501224,
  66.89098006357258,
  67.59873767827808,
  68.31084450182222,
  69.02730813691093,
  69.74813616640164,
  70.47333615344107,
  71.20291564160104,
  71.93688215501312,
  72.67524319850172,
  73.41800625771542,
  74.16517879925733,
  74.9167682708136,
  75.67278210128072,
  76.43322770089146,
  77.1981124613393,
  77.96744375590167,
  78.74122893956174,
  79.51947534912904,
  80.30219030335869,
  81.08938110306934,
  81.88105503125999,
  82.67721935322541,
  83.4778813166706,
  84.28304815182372,
  85.09272707154808,
  85.90692527145302,
  86.72564993000343,
  87.54890820862819,
  88.3767072518277,
  89.2090541872801,
  90.04595612594655,
  90.88742016217518,
  91.73345337380438,
  92.58406282226491,
  93.43925555268066,
  94.29903859396902,
  95.16341895893969,
  96.03240364439274,
  96.9059996312159,
  97.78421388448044,
  98.6670533535366,
  99.55452497210776,
];

/// Matrix to convert linear RGB to scaled discount (CAM16 intermediate).
const _scaledDiscountFromLinrgb = [
  [
    0.001200833568784504,
    0.002389694492170889,
    0.0002795742885861124,
  ],
  [
    0.0005891086651375999,
    0.0029785502573438758,
    0.0003270666104008398,
  ],
  [
    0.00010146692491640572,
    0.0005364214359186694,
    0.0032979401770712076,
  ],
];

/// Matrix to convert scaled discount back to linear RGB.
const _linrgbFromScaledDiscount = [
  [
    1373.2198709594231,
    -1100.4251190754821,
    -7.278681089101213,
  ],
  [
    -271.815969077903,
    559.6580465940733,
    -32.46047482791194,
  ],
  [
    1.9622899599665666,
    -57.173814538844006,
    308.7233197812385,
  ],
];

/// sRGB luminance coefficients (Rec. 709).
const _yFromLinrgb = [0.2126, 0.7152, 0.0722];

/// Generates the [_criticalPlanes] lookup table as Dart source code.
///
/// Usage: `print(generateCriticalPlanes())`, then copy output into this file.
String generateCriticalPlanes() {
  final buffer = StringBuffer();
  buffer.writeln('const _criticalPlanes = [');
  for (var i = 0; i < 255; i++) {
    buffer.writeln('  ${_linearizeSrgb(i + 0.5)},');
  }
  buffer.writeln('];');
  return buffer.toString();
}

/// Converts sRGB (0-255) to linear RGB (0-100). Inverse of `_trueDelinearized`.
double _linearizeSrgb(double srgb) {
  final normalized = srgb / 255.0;
  if (normalized <= 0.040449936) {
    return normalized / 12.92 * 100.0;
  }
  return pow((normalized + 0.055) / 1.055, 2.4) * 100.0;
}
