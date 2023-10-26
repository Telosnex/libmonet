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

import 'dart:ui';

import 'package:libmonet/argb_srgb_xyz_lab.dart';
import 'package:libmonet/cam16_viewing_conditions.dart';
import 'package:libmonet/cam16.dart';
import 'package:libmonet/hct_solver_noalloc.dart';

/// HCT, hue, chroma, and tone. A color system that provides a perceptually
/// accurate color measurement system that can also accurately render what
/// colors will appear as in different lighting environments.
class Hct {
  late double _hue;
  late double _chroma;
  late double _tone;
  late int _argb;

  /// 0 <= [hue] < 360; invalid values are corrected.
  /// 0 <= [chroma] <= ?; Informally, colorfulness. The color returned may be
  ///    lower than the requested chroma. Chroma has a different maximum for any
  ///    given hue and tone.
  /// 0 <= [tone] <= 100; informally, lightness. Invalid values are corrected.
  static Hct from(double hue, double chroma, double tone) {
    final argb = HctSolverNoAlloc.solveToInt(hue, chroma, tone);
    return Hct._(argb);
  }

  @override
  bool operator ==(other) {
    if (other is! Hct) {
      return false;
    }
    return other._argb == _argb;
  }

  @override
  int get hashCode => _argb.hashCode;

  @override
  String toString() {
    return 'H${hue.round().toString()} C${chroma.round()} T${tone.round().toString()}';
  }

  /// HCT representation of [argb].
  static Hct fromInt(int argb) {
    return Hct._(argb);
  }

  static Color colorFrom(double hue, double chroma, double tone) {
    final argb = HctSolverNoAlloc.solveToInt(hue, chroma, tone);
    return Color(argb);
  }

  factory Hct.fromColor(Color color) {
    final argb = color.value;
    return Hct._(argb);
  }

  int toInt() {
    return _argb;
  }

  Color get color {
    return Color(_argb);
  }

  static Color lerpKeepHue(Color colorA, Color colorB, double t) {
    final a = Hct.fromColor(colorA);
    final b = Hct.fromColor(colorB);
    final lstar = lerpDouble(a.tone, b.tone, t)!;
    final chroma = lerpDouble(a.chroma, b.chroma, t)!;
    final hue = _lerpKeepHueAngle(a.hue, b.hue, t);
    return Hct.from(hue, chroma, lstar).color;
  }

  static double _lerpKeepHueAngle(double a, double b, double t) {
    double shortestDistance;
    if ((b - a).abs() <= 180) {
      shortestDistance = b - a;
    } else {
      shortestDistance = (360 - b) + a;
    }
    final interpolatedDistance = shortestDistance * t;
    double interpolatedAngle;
    if (a + interpolatedDistance >= 360) {
      interpolatedAngle = a + interpolatedDistance - 360;
    } else {
      interpolatedAngle = a + interpolatedDistance;
    }
    return interpolatedAngle;
  }

  /// A number, in degrees, representing ex. red, orange, yellow, etc.
  /// Ranges from 0 <= [hue] < 360
  double get hue {
    return _hue;
  }

  /// 0 <= [newHue] < 360; invalid values are corrected.
  /// After setting hue, the color is mapped from HCT to the more
  /// limited sRGB gamut for display. This will change its ARGB/integer
  /// representation. If the HCT color is outside of the sRGB gamut, chroma
  /// will decrease until it is inside the gamut.
  set hue(double newHue) {
    _argb = HctSolverNoAlloc.solveToInt(newHue, chroma, tone);
    final cam16 = Cam16.fromInt(_argb);
    _hue = cam16.hue;
    _chroma = cam16.chroma;
    _tone = lstarFromArgb(_argb);
  }

  double get chroma {
    return _chroma;
  }

  /// 0 <= [newChroma] <= ?
  /// After setting chroma, the color is mapped from HCT to the more
  /// limited sRGB gamut for display. This will change its ARGB/integer
  /// representation. If the HCT color is outside of the sRGB gamut, chroma
  /// will decrease until it is inside the gamut.
  set chroma(double newChroma) {
    _argb = HctSolverNoAlloc.solveToInt(hue, newChroma, tone);
    final cam16 = Cam16.fromInt(_argb);
    _hue = cam16.hue;
    _chroma = cam16.chroma;
    _tone = lstarFromArgb(_argb);
  }

  /// Lightness. Ranges from 0 to 100.
  double get tone {
    return _tone;
  }

  /// 0 <= [newTone] <= 100; invalid values are corrected.
  /// After setting tone, the color is mapped from HCT to the more
  /// limited sRGB gamut for display. This will change its ARGB/integer
  /// representation. If the HCT color is outside of the sRGB gamut, chroma
  /// will decrease until it is inside the gamut.
  set tone(double newTone) {
    _argb = HctSolverNoAlloc.solveToInt(hue, chroma, newTone);
    final cam16 = Cam16.fromInt(_argb);
    _hue = cam16.hue;
    _chroma = cam16.chroma;
    _tone = lstarFromArgb(_argb);
  }

  Hct._(int argb) {
    _argb = argb;
    final cam16 = Cam16.fromInt(argb);
    _hue = cam16.hue;
    _chroma = cam16.chroma;
    _tone = lstarFromArgb(_argb);
  }

  /// Translate a color into different [ViewingConditions].
  ///
  /// Colors change appearance. They look different with lights on versus off,
  /// the same color, as in hex code, on white looks different when on black.
  /// This is called color relativity, most famously explicated by Josef Albers
  /// in Interaction of Color.
  ///
  /// In color science, color appearance models can account for this and
  /// calculate the appearance of a color in different settings. HCT is based on
  /// CAM16, a color appearance model, and uses it to make these calculations.
  ///
  /// See [ViewingConditions.make] for parameters affecting color appearance.
  Hct inViewingConditions(Cam16ViewingConditions vc) {
    // 1. Use CAM16 to find XYZ coordinates of color in specified VC.
    final cam16 = Cam16.fromInt(toInt());
    final viewedInVc = cam16.xyzInViewingConditions(vc);

    // 2. Create CAM16 of those XYZ coordinates in default VC.
    final recastInVc = Cam16.fromXyzInViewingConditions(
      viewedInVc[0],
      viewedInVc[1],
      viewedInVc[2],
      Cam16ViewingConditions.make(),
    );

    // 3. Create HCT from:
    // - CAM16 using default VC with XYZ coordinates in specified VC.
    // - L* converted from Y in XYZ coordinates in specified VC.
    final recastHct = Hct.from(
      recastInVc.hue,
      recastInVc.chroma,
      lstarFromY(viewedInVc[1]),
    );
    return recastHct;
  }
}
