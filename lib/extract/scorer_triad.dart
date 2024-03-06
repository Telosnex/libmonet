import 'dart:math' as math;
import 'package:libmonet/argb_srgb_xyz_lab.dart';
import 'package:libmonet/extract/quantizer_result.dart';
import 'package:libmonet/extract/scorer.dart';
import 'package:libmonet/hct.dart';
import 'package:libmonet/temperature.dart';

/// Returns 3 HCTs if [result.argbToCount] is not empty, otherwise returns an
/// empty list.
class ScorerTriad {
  static List<Hct> threeColorsFromQuantizer(
    QuantizerResult result, {
    bool debugLog = false,
  }) {
    void log(String Function() message) {
      if (debugLog) {
        // rationale: this is a debug log, so it's ok to print to console
        // ignore: avoid_print
        print(message());
      }
    }

    if (result.argbToCount.isEmpty) {
      return [];
    }

    final scorer = Scorer(result);
    final colorToCountKeys = result.argbToCount.keys.toList();
    // Sort the keys so the color with the top count is first.
    colorToCountKeys.sort(
        (a, b) => result.argbToCount[b]!.compareTo(result.argbToCount[a]!));
    final topFilteredColor = colorToCountKeys.reduce(
      (incumbentKey, contenderKey) {
        final incumbentHct = Hct.fromInt(incumbentKey);
        final contenderHct = Hct.fromInt(contenderKey);
        if (!(contenderHct.tone > 10 && contenderHct.tone < 95)) {
          return incumbentKey;
        }

        if (scorer.huePercent(contenderHct.hue.round()) >
            scorer.huePercent(incumbentHct.hue.round())) {
          return contenderKey;
        } else {
          return incumbentKey;
        }
      },
    );
    final backupHct = Hct.fromInt(topFilteredColor);
    final double topPrimaryHue;
    final double topPrimaryChroma;
    final double topPrimaryTone;
    {
      if (scorer.hcts.isEmpty) {
        topPrimaryHue = backupHct.hue;
        topPrimaryChroma = backupHct.chroma;
        topPrimaryTone = backupHct.tone;
      } else {
        final primaryHcts = scorer.hcts;
        final primaryHctsSmeared =
            Scorer.createHueToPercentage(primaryHcts, scorer.hueToPercent, 0);
        topPrimaryHue = primaryHctsSmeared
            .indexOf(primaryHctsSmeared.reduce(math.max))
            .toDouble();
        final primary = scorer.topHctNearHue(
            hue: topPrimaryHue, backupTone: backupHct.tone);
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
        topSecondaryHue = TemperatureCache(primary).analogous()[1].hue;
        log(() =>
            'secondary has 0 candidates, going with analogous hue to primary hue ${primary.hue.round()}: ${topSecondaryHue.round()}');
        topSecondaryChroma = backupHct.chroma;
        topSecondaryTone = backupHct.tone;
      } else {
        final secondaryHcts = scorer.hcts.where((hct) {
          final hue = hct.hue;
          if (differenceDegrees(hue, primary.hue) < 30) {
            return false;
          }
          return true;
        }).toList();
        if (secondaryHcts.isEmpty) {
          topSecondaryHue = TemperatureCache(primary).analogous()[1].hue;
          log(() =>
              'secondary has 0 candidates, going with analogous hue to primary hue ${primary.hue.round()}: ${topSecondaryHue.round()}');
          topSecondaryChroma = backupHct.chroma;
          topSecondaryTone = backupHct.tone;
        } else {
          log(() => 'secondary has ${secondaryHcts.length} candidates');
          final secondaryHuesSmeared = Scorer.createHueToPercentage(
              secondaryHcts, scorer.hueToPercent, 0);
          final topHueIndex = secondaryHuesSmeared
              .indexOf(secondaryHuesSmeared.reduce(math.max));
          topSecondaryHue = topHueIndex.toDouble();
          final secondary = scorer.topHctNearHue(
              hue: topSecondaryHue, backupTone: backupHct.tone);
          topSecondaryChroma = secondary.chroma;
          topSecondaryTone = secondary.tone;
        }
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
        topTertiaryHue = TemperatureCache(primary).analogous()[3].hue;
        log(() =>
            'tertiary has 0 candidates, going with analogous hue to primary hue ${primary.hue.round()}: ${topSecondaryHue.round()}');
        topTertiaryChroma = backupHct.chroma;
        topTertiaryTone = backupHct.tone;
      } else {
        // 45 motivating example:
        // At 30, with Unsplash photo of Christmas tree yard by Dan Asaki,
        // primary is 263, secondary is 37, and tertiary is 68.
        // The photo is overwhelmingly blue, but because secondary and tertiary
        // are so close, they become primary/secondary.
        // Avoiding picking up two hues so close to eachother is a good idea.
        // In general, it biases towards picking primary/secondary matching
        // the background.
        final tertiaryHcts = scorer.hcts.where((hct) {
          final hue = hct.hue;
          if (tertiaryHueAvoidsPrimaryHue &&
              differenceDegrees(hue, primary.hue) < 45) {
            return false;
          }
          if (tertiaryHueAvoidsSecondaryHue &&
              differenceDegrees(hue, secondary.hue) < 45) {
            return false;
          }
          return true;
        }).toList();

        if (tertiaryHcts.isEmpty) {
          topTertiaryHue = TemperatureCache(primary).analogous()[3].hue;
          log(() =>
              'tertiary has 0 candidates, going with analogous hue to primary hue ${primary.hue.round()}: ${topTertiaryHue.round()}');
          topTertiaryChroma = backupHct.chroma;
          topTertiaryTone = backupHct.tone;
        } else {
          final tertiaryHuesSmeared = Scorer.createHueToPercentage(
              tertiaryHcts, scorer.hueToPercent, 0);
          topTertiaryHue = tertiaryHuesSmeared
              .indexOf(tertiaryHuesSmeared.reduce(math.max))
              .toDouble();
          log(() =>
              'topTertiaryHue for ${tertiaryHcts.length} candidates: $topTertiaryHue');
          final tertiary = scorer.topHctNearHue(
              hue: topTertiaryHue, backupTone: backupHct.tone);
          topTertiaryChroma = tertiary.chroma;
          topTertiaryTone = tertiary.tone;
        }
      }
    }
    final tertiary =
        Hct.from(topTertiaryHue, topTertiaryChroma, topTertiaryTone);
    // Motivating examples for ensureClosestPairPrimary:
    // 1. A blue and green flower on a blue background.
    // Unsplash photo by Saffu.
    // By default, blue would be primary, secondary is yellow, tertiary is
    // orange.
    //
    // This is unintended because without color extraction, primary and
    // secondary should be relatively close in hue, and tertiary should
    // be differentiated (it indicates a 'do something else' color, i.e. a
    // departure from the current activity).
    //
    // 2. A red room with white chandalier and ceiling.
    // Unsplash photo by Sung Jin Cho.
    // By default, red would be primary (hue 27), secondary is close-to-red
    // (hue 2), and tertiary has no candidates and becomes 47.
    // 47 and 27 are closer than 2 and 27, so tertiary should become secondary.
    // (this case had an especially pleasing effect considering how close the
    // math is to being ambivalent between 2 and 47)
    //
    // 3. A Christmas dinner table with very dark tree in background.
    // Unsplash photo by Anita Austvika.
    // By default, primary would be 66, secondary 358, and tertiary has
    // no candidates and becomes analogous at 97.
    // 97 and 66 are closer than 358 and 66, so tertiary should become
    // secondary.
    return _ensureClosestPairPrimary([primary, secondary, tertiary],
        debugLog: debugLog);
  }

  static List<Hct> _ensureClosestPairPrimary(List<Hct> candidates,
      {bool debugLog = false}) {
    void log(String Function() message) {
      if (debugLog) {
        // rationale: this is a debug log, so it's ok to print to console
        // ignore: avoid_print
        print(message());
      }
    }

    if (candidates.length != 3) {
      throw ArgumentError(
          'The list must contain exactly three Hct candidates.');
    }

    // Calculate differences between each pair of hues.
    List<MapEntry<int, double>> pairwiseDistances = [
      MapEntry(
          0,
          differenceDegrees(
              candidates[0].hue, candidates[1].hue)), // Primary to Secondary
      MapEntry(
          1,
          differenceDegrees(
              candidates[1].hue, candidates[2].hue)), // Secondary to Tertiary
      MapEntry(
          2,
          differenceDegrees(
              candidates[2].hue, candidates[0].hue)), // Tertiary to Primary
    ];

    // Sort pairs by their hue difference.
    pairwiseDistances.sort((a, b) => a.value.compareTo(b.value));

    // The smallest difference pair should be the new primary & secondary.
    // The index tells us which pair is closest, so we choose the primary & secondary based on that.
    int smallestDifferenceIndex = pairwiseDistances.first.key;
    List<Hct> sortedHues;

    // Assign the closest pair to primary and secondary based on the smallest difference.
    switch (smallestDifferenceIndex) {
      case 0:
        // Primary and Secondary are the closest pair already.
        log(() =>
            'primary and secondary are closest pair. primary: ${candidates[0].hue.round()} secondary: ${candidates[1].hue.round()} tertiary: ${candidates[2].hue.round()}');
        sortedHues = [candidates[0], candidates[1], candidates[2]];
        break;
      case 1:
        // Secondary and Tertiary are the closest pair.
        log(() =>
            'secondary and tertiary are closest pair. primary: ${candidates[0].hue.round()} secondary: ${candidates[1].hue.round()} tertiary: ${candidates[2].hue.round()}');
        sortedHues = [candidates[1], candidates[2], candidates[0]];
        break;
      case 2:
        // Tertiary and Primary are the closest pair.
        log(() =>
            'tertiary and primary are closest pair. primary: ${candidates[0].hue.round()} secondary: ${candidates[1].hue.round()} tertiary: ${candidates[2].hue.round()}');
        sortedHues = [candidates[0], candidates[2], candidates[1]];
        break;
      default:
        throw ArgumentError('The smallestDifferenceIndex must be 0, 1, or 2.');
    }

    return sortedHues;
  }
}
