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
import 'dart:math' as math;

import 'package:libmonet/colorspaces/cam16/cam16.dart';
import 'package:libmonet/colorspaces/cam16/cam16_viewing_conditions.dart';
import 'package:libmonet/colorspaces/cam16V11/cam16_v11.dart';
import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/colorspaces/hct_solver.dart';
import 'package:libmonet/colorspaces/oklch.dart';
import 'package:libmonet/core/argb_srgb_xyz_lab.dart';
import 'package:libmonet/core/hex_codes.dart';
import 'package:libmonet/util/with_opacity_neue.dart';

/// HCT, hue, chroma, and tone. A color system that provides a perceptually
/// accurate color measurement system that can also accurately render what
/// colors will appear as in different lighting environments.
class Hct {
  late double _hue;
  late double _chroma;
  late double _tone;
  late int _argb;
  late ColorModel _colorModel;

  /// 0 <= [hue] < 360; invalid values are corrected.
  /// 0 <= [chroma] <= ?; Informally, colorfulness. The color returned may be
  ///    lower than the requested chroma. Chroma has a different maximum for any
  ///    given hue and tone.
  /// 0 <= [tone] <= 100; informally, lightness. Invalid values are corrected.
  static Hct from(
    double hue,
    double chroma,
    double tone, {
    ColorModel model = ColorModel.kDefault,
  }) {
    final argb = HctSolver.solveToIntForModel(
      hue,
      chroma,
      tone,
      model: model,
    );
    return Hct._(argb, model: model);
  }

  @override
  bool operator ==(other) {
    if (other is! Hct) {
      return false;
    }
    return other._argb == _argb && other._colorModel == _colorModel;
  }

  @override
  int get hashCode => Object.hash(_argb, _colorModel);

  @override
  String toString() {
    return 'H${hue.round().toString()} C${chroma.round()} T${tone.round().toString()}';
  }

  /// HCT representation of [argb].
  static Hct fromInt(int argb, {ColorModel model = ColorModel.kDefault}) {
    return Hct._(argb, model: model);
  }

  static Color colorFrom(
    double hue,
    double chroma,
    double tone, {
    ColorModel model = ColorModel.kDefault,
  }) {
    final argb = HctSolver.solveToIntForModel(
      hue,
      chroma,
      tone,
      model: model,
    );
    return Color(argb);
  }

  factory Hct.fromColor(
    Color color, {
    ColorModel model = ColorModel.kDefault,
  }) {
    final argb = color.argb;
    return Hct._(argb, model: model);
  }

  int toInt() {
    return _argb;
  }

  Color get color {
    return Color(_argb);
  }

  ColorModel get colorModel => _colorModel;

  static Color lerpKeepHue(
    Color colorA,
    Color colorB,
    double t, {
    ColorModel model = ColorModel.kDefault,
  }) {
    final a = Hct.fromColor(colorA, model: model);
    final b = Hct.fromColor(colorB, model: model);
    final lstar = lerpDouble(a.tone, b.tone, t)!;
    final chroma = lerpDouble(a.chroma, b.chroma, t)!;
    final hue = _lerpKeepHueAngle(a.hue, b.hue, t);
    final opacity = lerpDouble(colorA.opacityNeue, colorB.opacityNeue, t);
    return Hct.from(hue, chroma, lstar, model: model)
        .color
        .withOpacityNeue(opacity!);
  }

  /// Linearly interpolates between two colors in HCT space, allowing both hue
  /// and chroma to shift as needed.
  ///
  /// For example, interpolating between a saturated red and a saturated blue
  /// would pass through grays.
  static Color lerpLoseHueAndChroma(
    Color colorA,
    Color colorB,
    double t, {
    ColorModel model = ColorModel.kDefault,
  }) {
    final aTone = lstarFromArgb(colorA.argb);
    final bTone = lstarFromArgb(colorB.argb);
    final tone = lerpDouble(aTone, bTone, t)!;
    final opacity = lerpDouble(colorA.opacityNeue, colorB.opacityNeue, t)!;

    switch (model) {
      case ColorModel.cam16:
        final camA = Cam16.fromInt(colorA.argb);
        final camB = Cam16.fromInt(colorB.argb);
        final aStar = lerpDouble(camA.astar, camB.astar, t)!;
        final bStar = lerpDouble(camA.bstar, camB.bstar, t)!;
        final jStar = lerpDouble(camA.jstar, camB.jstar, t)!;
        final camMerged = Cam16.fromUcs(jStar, aStar, bStar);
        return Hct.from(camMerged.hue, camMerged.chroma, tone, model: model)
            .color
            .withOpacityNeue(opacity);
      case ColorModel.cam16v11:
        final camA = Cam16V11.fromInt(colorA.argb);
        final camB = Cam16V11.fromInt(colorB.argb);
        final aStar = lerpDouble(camA.astar, camB.astar, t)!;
        final bStar = lerpDouble(camA.bstar, camB.bstar, t)!;
        final jStar = lerpDouble(camA.jstar, camB.jstar, t)!;
        final camMerged = Cam16V11.fromUcs(jStar, aStar, bStar);
        return Hct.from(camMerged.hue, camMerged.chroma, tone, model: model)
            .color
            .withOpacityNeue(opacity);
      case ColorModel.oklch:
        final okA = Oklch.fromInt(colorA.argb);
        final okB = Oklch.fromInt(colorB.argb);
        final aA = okA.chroma * math.cos(okA.hue * math.pi / 180.0);
        final bA = okA.chroma * math.sin(okA.hue * math.pi / 180.0);
        final aB = okB.chroma * math.cos(okB.hue * math.pi / 180.0);
        final bB = okB.chroma * math.sin(okB.hue * math.pi / 180.0);
        final aMerged = lerpDouble(aA, aB, t)!;
        final bMerged = lerpDouble(bA, bB, t)!;
        final chroma = math.sqrt(aMerged * aMerged + bMerged * bMerged);
        var hue = math.atan2(bMerged, aMerged) * 180.0 / math.pi;
        if (hue < 0.0) hue += 360.0;
        return Hct.from(hue, chroma, tone, model: model)
            .color
            .withOpacityNeue(opacity);
    }
  }

  static double _lerpKeepHueAngle(double a, double b, double t) {
    final delta = ((b - a + 540.0) % 360.0) - 180.0;
    final interpolatedAngle = (a + delta * t) % 360.0;
    return interpolatedAngle < 0
        ? interpolatedAngle + 360.0
        : interpolatedAngle;
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
    _argb = HctSolver.solveToIntForModel(
      newHue,
      chroma,
      tone,
      model: _colorModel,
    );
    final cam = _camFromInt(_argb, _colorModel);
    _hue = cam.hue;
    _chroma = cam.chroma;
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
    _argb = HctSolver.solveToIntForModel(
      hue,
      newChroma,
      tone,
      model: _colorModel,
    );
    final cam = _camFromInt(_argb, _colorModel);
    _hue = cam.hue;
    _chroma = cam.chroma;
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
    _argb = HctSolver.solveToIntForModel(
      hue,
      chroma,
      newTone,
      model: _colorModel,
    );
    final cam = _camFromInt(_argb, _colorModel);
    _hue = cam.hue;
    _chroma = cam.chroma;
    _tone = lstarFromArgb(_argb);
  }

  Hct._(int argb, {ColorModel model = ColorModel.kDefault}) {
    _argb = argb;
    _colorModel = model;
    final cam = _camFromInt(argb, model);
    _hue = cam.hue;
    _chroma = cam.chroma;
    _tone = lstarFromArgb(_argb);
  }

  static ({double hue, double chroma}) _camFromInt(
    int argb,
    ColorModel model,
  ) {
    switch (model) {
      case ColorModel.cam16:
        final cam16 = Cam16.fromInt(argb);
        return (hue: cam16.hue, chroma: cam16.chroma);
      case ColorModel.cam16v11:
        final cam16v11 = Cam16V11.fromInt(argb);
        return (hue: cam16v11.hue, chroma: cam16v11.chroma);
      case ColorModel.oklch:
        final oklch = Oklch.fromInt(argb);
        return (hue: oklch.hue, chroma: oklch.chroma);
    }
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
      model: _colorModel,
    );
    return recastHct;
  }
}
