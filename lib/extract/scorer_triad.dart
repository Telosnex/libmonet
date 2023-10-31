import 'dart:math' as math;
import 'package:libmonet/argb_srgb_xyz_lab.dart';
import 'package:libmonet/contrast.dart';
import 'package:libmonet/extract/quantizer_result.dart';
import 'package:libmonet/extract/scorer.dart';
import 'package:libmonet/hct.dart';

class ScorerTriad {
  static List<Hct> threeColorsFromQuantizer(
    bool isLight,
    QuantizerResult result,
  ) {
    const smearDistance = 7.0;
    const minHueDistance = 45.0;
    final scorer = Scorer(result);

    final colorToCountKeys = result.argbToCount.keys.toList();
    // Sort the keys so the color with the top count is first.
    colorToCountKeys.sort(
        (a, b) => result.argbToCount[b]!.compareTo(result.argbToCount[a]!));
    /**
    * "TOP COLOR"
    *
    * Higher rank if:
    * - T10 <= tone <= T95
    * - hue population within 7 degrees of hue is higher
    * Light mode:
    * - T50 >= tone
    * Dark mode:
    * - T40 <= tone 
    * - hue is not red
    * - T10 <= tone <= T30
    */
    final color = colorToCountKeys.reduce(
      (incumbentKey, contenderKey) {
        final incumbentHct = Hct.fromInt(incumbentKey);
        final contenderHct = Hct.fromInt(contenderKey);
        if (!(contenderHct.tone > 10 && contenderHct.tone < 95)) {
          return incumbentKey;
        }

        final isLightMode = isLight;
        final isDarkMode = !isLightMode;

        if (isLightMode) {
          final incumbentDark = incumbentHct.tone < 50;
          final contenderLight = contenderHct.tone >= 50;
          if (incumbentDark && contenderLight) {
            return contenderKey;
          } else if (!incumbentDark && !contenderLight) {
            return incumbentKey;
          } else if (scorer.huePercent(contenderHct.hue.round()) >
              scorer.huePercent(incumbentHct.hue.round())) {
            return contenderKey;
          } else {
            return incumbentKey;
          }
        } else if (isDarkMode) {
          final incumbentLight = incumbentHct.tone >= 40 ||
              (incumbentHct.hue > 35 && incumbentHct.hue < 120); // light or red
          final contenderDark = contenderHct.tone < 40 &&
              (!(contenderHct.hue > 35 &&
                  contenderHct.hue < 120)); // dark and not red
          final contenderTooDark = contenderHct.tone < 10;
          final incumbentTooDark = incumbentHct.tone < 10;
          if (incumbentLight && contenderDark) {
            return contenderKey;
          } else if (!incumbentLight && !contenderDark) {
            return incumbentKey;
          } else if (incumbentTooDark &&
              !contenderTooDark &&
              contenderHct.tone <= 30) {
            return contenderKey;
          } else if (scorer.huePercent(contenderHct.hue.round()) >
              scorer.huePercent(incumbentHct.hue.round())) {
            return contenderKey;
          } else {
            return incumbentKey;
          }
        } else {
          throw 'Unreachable case';
        }
      },
    );

    final backupHue = scorer.hueToSmearedPercent
        .indexOf(scorer.hueToSmearedPercent.reduce(math.max));
    final hctsWithin15Degrees = scorer.hcts
        .where((hct) => differenceDegrees(hct.hue, backupHue.toDouble()) < 15)
        .toList(growable: false);

    final backupHct = Hct.fromInt(color);

    /**
     * SURFACE
     * 
     * Hue: top hue within 15 degrees latitude, in all HCTs close to T25/T80.
     *   If none, use top color hue.
     * Chroma: average chroma of all near hue and chroma >= 8. If none, use 8.
     * Tone: >=T80 if light, <=T25 if dark. Average tone within 15 degrees of 
     *   hue to determine if its >=T80 or <=T25.
     */
    final averageToneOfTopHue = hctsWithin15Degrees.isEmpty
        ? 50.0
        : hctsWithin15Degrees
                .map((hct) => hct.tone)
                .reduce((value, element) => value + element) /
            hctsWithin15Degrees.length;
    final targetSurfaceTone = isLight
        ? math.max(averageToneOfTopHue, 80.0)
        : math.min(averageToneOfTopHue, 25.0);
    final backupOnSurfaceTone = contrastingLstar(
        withLstar: targetSurfaceTone, usage: Usage.fill, contrast: 0.5);

    final double topPrimaryHue;
    final double topPrimaryChroma;
    final double topPrimaryTone;
    {
      // const primaryHueAvoidsSurfaceHue = false;
      if (scorer.hcts.isEmpty) {
        topPrimaryHue = backupHct.hue;
        topPrimaryChroma = backupHct.chroma;
        topPrimaryTone = backupOnSurfaceTone;
      } else {
        final primaryHcts = scorer.hcts;
        final primaryHctsSmeared =
            Scorer.createHueToPercentage(primaryHcts, scorer.hueToPercent, 0);
        topPrimaryHue = primaryHctsSmeared
            .indexOf(primaryHctsSmeared.reduce(math.max))
            .toDouble();
        final primary = scorer.averagedHctNearHue(
            hue: topPrimaryHue, backupTone: backupOnSurfaceTone);
        topPrimaryChroma = primary.chroma;
        topPrimaryTone = primary.tone;
      }
    }
    final primary = Hct.from(topPrimaryHue, topPrimaryChroma, topPrimaryTone);

    final double topSecondaryHue;
    final double topSecondaryChroma;
    final double topSecondaryTone;
    {
      if (scorer.hcts.isEmpty) {
        topSecondaryHue = backupHct.hue;
        topSecondaryChroma = backupHct.chroma;
        topSecondaryTone = backupOnSurfaceTone;
      } else {
        final secondaryHcts = scorer.hcts.where((hct) {
          final hue = hct.hue;
          if (differenceDegrees(hue, primary.hue) < minHueDistance) {
            return false;
          }
          return true;
        }).toList();
        final secondaryHuesSmeared =
            Scorer.createHueToPercentage(secondaryHcts, scorer.hueToPercent, 0);
        final topHueIndex =
            secondaryHuesSmeared.indexOf(secondaryHuesSmeared.reduce(math.max));
        topSecondaryHue = topHueIndex.toDouble();
        final secondary = scorer.averagedHctNearHue(
            hue: topSecondaryHue, backupTone: backupOnSurfaceTone);
        topSecondaryChroma = secondary.chroma;
        topSecondaryTone = secondary.tone;
      }
    }
    final secondary =
        Hct.from(topSecondaryHue, topSecondaryChroma, topSecondaryTone);

    /** 
     * TERTIARY
     */

    final double topTertiaryHue;
    final double topTertiaryChroma;
    final double topTertiaryTone;
    {
      const tertiaryHueAvoidsPrimaryHue = true;
      const tertiaryHueAvoidsSecondaryHue = true;
      if (scorer.hcts.isEmpty) {
        topTertiaryHue = backupHct.hue;
        topTertiaryChroma = backupHct.chroma;
        topTertiaryTone = backupOnSurfaceTone;

      } else {
        final tertiaryHcts = scorer.hcts.where((hct) {
          final hue = hct.hue;
          if (tertiaryHueAvoidsPrimaryHue &&
              differenceDegrees(hue, primary.hue) < 15) {
            return false;
          }
          if (tertiaryHueAvoidsSecondaryHue &&
              differenceDegrees(hue, secondary.hue) < 15) {
            return false;
          }
          return true;
        }).toList();
        final tertiaryHuesSmeared =
            Scorer.createHueToPercentage(tertiaryHcts, scorer.hueToPercent, 0);
        topTertiaryHue = tertiaryHuesSmeared
            .indexOf(tertiaryHuesSmeared.reduce(math.max))
            .toDouble();
        final tertiary = scorer.averagedHctNearHue(
            hue: topTertiaryHue, backupTone: backupOnSurfaceTone);
        topTertiaryChroma = tertiary.chroma;
        topTertiaryTone = tertiary.tone;
      }
    }
    final tertiary =
        Hct.from(topTertiaryHue, topTertiaryChroma, topTertiaryTone);

    return [primary, secondary, tertiary];
  }
}
