// Modified and maintained by open-source contributors, on behalf of libmonet.
//
// Original notice:
// Copyright 2022 Google LLC
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

import 'dart:math' as math;

import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/core/argb_srgb_xyz_lab.dart';
import 'package:libmonet/colorspaces/hct.dart';
import 'package:libmonet/effects/afterimage.dart';
import 'package:libmonet/effects/uv_harmony.dart' as uv;

/// Design utilities using color temperature theory.
///
/// Warm/cool queries ([warmest], [coldest], [relativeTemperature]) use the
/// Chang-Ou 2026 temperature model. Harmony queries are now delegated to the
/// u'v' vector model: [complement] is the afterimage complement and
/// [analogous] walks neighboring u'v' directions. This keeps the historical
/// API while moving complement/analogous off the old warm-cool wheel.
///
/// Color science has researched emotion and harmony, which art uses to select
/// colors. See:
/// - Li-Chen Ou's Chapter 19 in Handbook of Color Psychology (2015).
/// - Josef Albers' Interaction of Color chapters 19 and 21.
///
/// The canonical model here is Chang & Ou's chromaticity-based warm-cool
/// model (Color Research & Application, 2026): perceived warmth is the
/// signed distance from the color's CIE 1976 u'v' chromaticity to a neutral
/// line through Illuminant D75 (see [rawTemperature]). It supersedes the
/// hue-angle models from the same lab — Ou et al. 2004 (used by Material
/// Color Utilities, kept as [rawTemperature2004]) and the 12-region
/// "universal model" of Ou et al. 2018 ([rawTemperature2018]) — correlating
/// r ≈ 0.96 with paired-comparison data on both chromatic and near-white
/// stimuli, where the older models were never validated near white.
///
/// Material Color Utilities' original implementation evaluated its formula
/// at all 360 hues — 360 invocations of the HCT solver — just to locate the
/// warmest/coolest colors and normalize against them. Besides being slow,
/// the search's answers were dominated by sRGB gamut clamping at high
/// chroma: the "warmest" hue drifted to green-yellow at high chroma and
/// tone, simply because that is where the gamut lets chroma survive.
///
/// This implementation instead refits the model in hue space. The Chang-Ou
/// warmth was evaluated on unclamped colors (CAM16 JCH → XYZ and
/// OKLCH → XYZ, no sRGB gamut involved), which shows temperature at fixed
/// chroma and tone is a smooth single-peaked cycle in hue: warmest at
/// red-orange, coolest at blue. Relative temperature is modeled as a
/// "warped cosine" between those two poles, which matches the normalized
/// warmth curve with mean absolute error ≈ 0.06 across chroma and tone —
/// while making every operation here O(1).
///
/// Poles per hue space (fit against Chang-Ou 2026, unclamped):
/// - CAM16:      warm 44, cool 227
/// - CAM16 v1.1: warm 40, cool 230
/// - OKLCH:      warm 43, cool 225
class TemperatureCache {
  final Hct input;

  TemperatureCache(this.input);

  /// Hue of the warmest color, per hue space of the input's [ColorModel].
  static double warmestHue(ColorModel model) {
    switch (model) {
      case ColorModel.cam16:
        return 44.0;
      case ColorModel.cam16v11:
        return 40.0;
      case ColorModel.oklch:
        return 43.0;
    }
  }

  /// Hue of the coolest color, per hue space of the input's [ColorModel].
  static double coolestHue(ColorModel model) {
    switch (model) {
      case ColorModel.cam16:
        return 227.0;
      case ColorModel.cam16v11:
        return 230.0;
      case ColorModel.oklch:
        return 225.0;
    }
  }

  /// Warmest color with the same chroma and tone as the input.
  Hct get warmest => Hct.from(
        warmestHue(input.colorModel),
        input.chroma,
        input.tone,
        model: input.colorModel,
      );

  /// Coolest color with the same chroma and tone as the input.
  Hct get coldest => Hct.from(
        coolestHue(input.colorModel),
        input.chroma,
        input.tone,
        model: input.colorModel,
      );

  /// A set of colors neighboring the input in u'v' chromatic direction.
  ///
  /// Keeps the historical Material-style signature: [count] is the number of
  /// returned colors (including the input) and [divisions] is the number of
  /// wheel divisions, so the step is `360 / divisions` degrees. Unlike the
  /// old implementation, the wheel is the u'v' vector around white rather
  /// than the warm-cool temperature cycle.
  ///
  /// Behavior is undefined when [count] or [divisions] is 0.
  /// When divisions < count, colors repeat.
  List<Hct> analogous({int count = 5, int divisions = 12}) =>
      uv.analogous(input, count: count, step: 360.0 / divisions);

  /// The color that complements the input, defined physiologically: the
  /// afterimage the eye produces after adapting to the input.
  ///
  /// In art this is described as being "across the color wheel", but the
  /// wheels disagree with each other. The afterimage definition needs no
  /// wheel and has a checkable property: an additive mixture of the input
  /// and its complement is neutral gray. Rendered at the input's tone;
  /// chroma is NOT preserved (the gamut may not offer the opposite
  /// chromaticity at equal strength). See [afterimageComplement].
  Hct get complement => afterimageComplement(input);

  /// Temperature relative to all colors with the same chroma and tone.
  /// Value on a scale from 0 to 1.
  double relativeTemperature(Hct hct) {
    // Achromatic colors have no meaningful hue; match the previous behavior
    // of treating them as mid-temperature. Thresholds mirror the achromatic
    // short-circuit in the HCT solver.
    if (hct.chroma < 0.0001 || hct.tone < 0.0001 || hct.tone > 99.9999) {
      return 0.5;
    }
    final position = _cyclePosition(hct.hue);
    return position <= 1.0 ? 1.0 - position : position - 1.0;
  }

  /// Relative temperature of the input color. See [relativeTemperature].
  double get inputRelativeTemperature => relativeTemperature(input);

  /// Position of [hue] on the warm-cool cycle, in [0, 2).
  ///
  /// 0 at the warm pole, increasing clockwise (with hue) to 1 at the cool
  /// pole, and back up to 2 at the warm pole again. Equal steps in position
  /// are equal steps in temperature, so this is also cumulative temperature
  /// change: relative temperature is `1 - position` on the warm→cool arc and
  /// `position - 1` on the cool→warm arc.
  double _cyclePosition(double hue) {
    final warmHue = warmestHue(input.colorModel);
    final coolHue = coolestHue(input.colorModel);
    final warmToCoolArc = sanitizeDegreesDouble(coolHue - warmHue);
    final coolToWarmArc = 360.0 - warmToCoolArc;
    final fromWarm = sanitizeDegreesDouble(hue - warmHue);
    if (fromWarm <= warmToCoolArc) {
      final fraction = fromWarm / warmToCoolArc;
      return (1.0 - math.cos(math.pi * fraction)) / 2.0;
    }
    final fraction = sanitizeDegreesDouble(hue - coolHue) / coolToWarmArc;
    return 1.0 + (1.0 - math.cos(math.pi * fraction)) / 2.0;
  }

  /// Perceived warmth of a color: Chang & Ou (2026), the canonical model.
  ///
  /// Signed distance from the color's CIE 1976 u'v' chromaticity to a
  /// "reference line" of neutral warmth passing through CIE Illuminant D75
  /// (identified in the same research program as the most neutral white).
  /// Warmth = k * (a*u' + b*v' + c) / sqrt(a^2 + b^2), with k=1298.3,
  /// a=2.2175, b=1, c=-0.8877.
  ///
  /// Positive is warm, negative is cool, 0 on the neutral line. Purely
  /// chromaticity-based: no hue angle, chroma, or reference-white adaptation
  /// involved, and — unlike [rawTemperature2004] / [rawTemperature2018] — it
  /// is validated on near-white stimuli, so it remains meaningful at very
  /// high and very low tones.
  ///
  /// Reference: Chang & Ou, "A Chromaticity-Based Warm-Cool Model Integrated
  /// With the Neutral White Locus", Color Research & Application 51 (2026),
  /// Equation 2. https://doi.org/10.1002/col.70063
  static double rawTemperature(Hct color) {
    final xyz = xyzFromArgb(color.toInt());
    final denom = xyz[0] + 15.0 * xyz[1] + 3.0 * xyz[2];
    if (denom.abs() < 1e-9) {
      return 0.0;
    }
    final u = 4.0 * xyz[0] / denom;
    final v = 9.0 * xyz[1] / denom;
    const k = 1298.3, a = 2.2175, b = 1.0, c = -0.8877;
    return k * (a * u + b * v + c) / math.sqrt(a * a + b * b);
  }

  /// Warm-cool per Ou, Woodcock and Wright (2004), in CIELAB — the model
  /// Material Color Utilities used. Kept for comparison with newer models.
  ///
  /// `WC = -0.5 + 0.02 * chroma^1.07 * cos(hue - 50°)`
  ///
  /// Return value has these properties:
  /// - Values below 0 are cool, above 0 are warm.
  /// - Lower bound: -0.52 - (chroma ^ 1.07 / 20). L*a*b* chroma is infinite.
  ///   Assuming max of 130 chroma, -9.66.
  /// - Upper bound: -0.52 + (chroma ^ 1.07 / 20). L*a*b* chroma is infinite.
  ///   Assuming max of 130 chroma, 8.61.
  static double rawTemperature2004(Hct color) {
    final lab = labFromArgb(color.toInt());
    final hue = sanitizeDegreesDouble(
        math.atan2(lab[2], lab[1]) * 180.0 / math.pi);
    final chroma = math.sqrt((lab[1] * lab[1]) + (lab[2] * lab[2]));
    final temperature = -0.5 +
        0.02 *
            math.pow(chroma, 1.07) *
            math.cos(
              sanitizeDegreesDouble(hue - 50.0) * math.pi / 180.0,
            );
    return temperature;
  }

  /// Warm-cool per Ou et al.'s "universal model" (2018), fit to
  /// psychophysical data from 12 regions worldwide. Kept for comparison.
  ///
  /// `WC = -0.89 + 0.052 * chroma * [cos(hue - 50°) + 0.16*cos(2*hue - 350°)]`
  ///
  /// Reference: Ou et al., "Universal Models of Colour Emotion and Colour
  /// Harmony", Color Research & Application 43 (2018), Equation A6.
  static double rawTemperature2018(Hct color) {
    final lab = labFromArgb(color.toInt());
    final hue = sanitizeDegreesDouble(
        math.atan2(lab[2], lab[1]) * 180.0 / math.pi);
    final chroma = math.sqrt((lab[1] * lab[1]) + (lab[2] * lab[2]));
    final radians = math.pi / 180.0;
    return -0.89 +
        0.052 *
            chroma *
            (math.cos(sanitizeDegreesDouble(hue - 50.0) * radians) +
                0.16 *
                    math.cos(
                        sanitizeDegreesDouble(2.0 * hue - 350.0) * radians));
  }
}
