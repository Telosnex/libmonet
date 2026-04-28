import 'dart:math' as math;
import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/core/argb_srgb_xyz_lab.dart';
import 'package:libmonet/effects/temperature.dart';
import 'package:libmonet/extract/quantizer_result.dart';
import 'package:libmonet/extract/scorer.dart';
import 'package:libmonet/colorspaces/hct.dart';

/// Returns 3 HCTs if [result.argbToCount] is not empty, otherwise returns an
/// empty list.
///
/// Candidate colors are tone-filtered to L* 10-95 by default before scoring.
/// Set [toneTooLow] and/or [toneTooHigh] to null to disable either side of the
/// tone filter.
///
/// Candidate colors are chroma-filtered using the active color model's default
/// threshold. Set [minChroma] to 0 to disable chroma filtering.
///
/// Secondary and tertiary representatives are always selected from their
/// role-specific filtered candidate pools.
///
/// [primaryIsAverageOfNearby] is an optional parameter that can be used to
/// determine the primary color by averaging the hue, chroma, and tone of nearby
/// colors. [true] is useful in the same scenario described above.
///
/// [ensureClosestPairPrimary] is an optional parameter that can be used to
/// ensure that secondary is the closest non-primary hue to the selected
/// primary. The extracted primary remains primary; tertiary keeps meaning
/// "go somewhere else" without letting a fallback or accent color replace the
/// dominant extracted primary.
/// The non-default, false, is useful in the same scenario described above.
class ScorerTriad {
  static List<Hct> threeColorsFromQuantizer(
    QuantizerResult result, {
    bool debugLog = false,
    List<String>? traceLog,
    double? toneTooLow = 10,
    double? toneTooHigh = 95,
    double? minChroma,
    bool primaryIsAverageOfNearby = false,
    bool ensureClosestPairPrimary = true,
    ColorModel colorModel = ColorModel.kDefault,
  }) {
    void log(String Function() message) {
      if (debugLog || traceLog != null) {
        final line = message();
        traceLog?.add(line);
      }
      if (debugLog) {
        // rationale: this is a debug log, so it's ok to print to console
        // ignore: avoid_print
        print(traceLog?.last ?? message());
      }
    }

    if (result.argbToCount.isEmpty) {
      return [];
    }

    final scorer = Scorer(
      result,
      toneTooLow: toneTooLow,
      toneTooHigh: toneTooHigh,
      minChroma: minChroma,
      colorModel: colorModel,
    );
    String describeHct(Hct hct) =>
        'H${hct.hue.toStringAsFixed(2)} C${hct.chroma.toStringAsFixed(2)} T${hct.tone.toStringAsFixed(2)}';
    String describeCandidates(List<Hct> hcts, {int limit = 8}) {
      final sorted = hcts.toList()
        ..sort((a, b) =>
            (scorer.hctToCount[b] ?? 0).compareTo(scorer.hctToCount[a] ?? 0));
      return sorted.take(limit).map((hct) {
        final count = scorer.hctToCount[hct] ?? 0;
        return '${describeHct(hct)} count=$count';
      }).join('; ');
    }

    final filteredHues = scorer.hcts.map((hct) => hct.hue.round()).toSet()
      ..removeWhere((hue) => hue < 0 || hue > 360);
    log(() => 'filtered candidates: ${scorer.hcts.length}');
    log(() => 'filtered hues: ${filteredHues.toList()..sort()}');
    log(() => 'top primary hue without chroma filter: '
        '${scorer.primaryHueToSmearedPercent.indexOf(scorer.primaryHueToSmearedPercent.reduce(math.max))}');
    log(() => 'top filtered hue with chroma filter: '
        '${scorer.hueToSmearedPercent.indexOf(scorer.hueToSmearedPercent.reduce(math.max))}');

    final colorToCountKeys = result.argbToCount.keys.toList();
    // Sort the keys so the color with the top count is first.
    colorToCountKeys.sort(
        (a, b) => result.argbToCount[b]!.compareTo(result.argbToCount[a]!));
    final topFilteredColor = colorToCountKeys.reduce(
      (incumbentKey, contenderKey) {
        final incumbentHct = Hct.fromInt(incumbentKey, model: colorModel);
        final contenderHct = Hct.fromInt(contenderKey, model: colorModel);
        if (toneTooLow != null && contenderHct.tone <= toneTooLow) {
          return incumbentKey;
        }
        if (toneTooHigh != null && contenderHct.tone >= toneTooHigh) {
          return incumbentKey;
        }
        if (scorer.primaryHuePercent(contenderHct.hue.round()) >
            scorer.primaryHuePercent(incumbentHct.hue.round())) {
          return contenderKey;
        } else {
          return incumbentKey;
        }
      },
    );
    final backupHct = Hct.fromInt(topFilteredColor, model: colorModel);
    final double topPrimaryHue;
    final double topPrimaryChroma;
    final double topPrimaryTone;
    {
      if (scorer.hcts.isEmpty) {
        topPrimaryHue = backupHct.hue;
        topPrimaryChroma = backupHct.chroma;
        topPrimaryTone = backupHct.tone;
      } else {
        // Primary hue uses tone-filtered colors without applying the chroma
        // filter, so dominant low-chroma wallpaper hues still get a vote.
        topPrimaryHue = scorer.primaryHueToSmearedPercent
            .indexOf(scorer.primaryHueToSmearedPercent.reduce(math.max))
            .toDouble();

        if (debugLog) {
          log(() =>
              '[ScorerTriad] topPrimaryHue from hueToSmearedPercent: $topPrimaryHue');
        }

        final Hct primary;
        if (primaryIsAverageOfNearby) {
          primary = scorer.averagedHctNearHue(
              hue: topPrimaryHue, backupTone: backupHct.tone);
          log(() =>
              'Selected primary using averaged HCT near hue. Primary HCT: $primary');
        } else {
          primary = scorer.topHctNearHue(
              hue: topPrimaryHue, backupTone: backupHct.tone);
          log(() =>
              'Selected primary using top HCT near hue. Primary HCT: $primary');
        }
        topPrimaryChroma = primary.chroma;
        topPrimaryTone = primary.tone;
      }
    }
    final primary = Hct.from(
      topPrimaryHue,
      topPrimaryChroma,
      topPrimaryTone,
      model: colorModel,
    );

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
        final secondarySelection = _selectSecondaryCandidates(
          scorer.hcts,
          primary: primary,
        );
        final secondaryHcts = secondarySelection.candidates;
        if (secondaryHcts.isEmpty) {
          topSecondaryHue = TemperatureCache(primary).analogous()[1].hue;
          log(() =>
              'secondary has 0 candidates, going with analogous hue to primary hue ${primary.hue.round()}: ${topSecondaryHue.round()}');
          topSecondaryChroma = backupHct.chroma;
          topSecondaryTone = backupHct.tone;
        } else {
          log(() =>
              'secondary has ${secondaryHcts.length} candidates using ${secondarySelection.label}');
          log(() =>
              'secondary top candidates: ${describeCandidates(secondaryHcts)}');
          final secondaryHuesSmeared = Scorer.createHueToPercentage(
              secondaryHcts, scorer.hueToPercent, 0);
          final topHueIndex = secondaryHuesSmeared
              .indexOf(secondaryHuesSmeared.reduce(math.max));
          topSecondaryHue = topHueIndex.toDouble();
          log(() =>
              'topSecondaryHue from secondary candidates: $topSecondaryHue');
          final secondary = scorer.topHctNearHueFrom(secondaryHcts,
              hue: topSecondaryHue, backupTone: backupHct.tone);
          log(() =>
              'secondary representative from rolePool: ${describeHct(secondary)}');
          topSecondaryChroma = secondary.chroma;
          topSecondaryTone = secondary.tone;
        }
      }
    }
    final secondary = Hct.from(
      topSecondaryHue,
      topSecondaryChroma,
      topSecondaryTone,
      model: colorModel,
    );

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
        final tertiarySelection = _selectTertiaryCandidates(
          scorer.hcts,
          primary: primary,
          secondary: secondary,
          avoidsPrimary: tertiaryHueAvoidsPrimaryHue,
          avoidsSecondary: tertiaryHueAvoidsSecondaryHue,
        );
        final tertiaryHcts = tertiarySelection.candidates;

        if (tertiaryHcts.isEmpty) {
          topTertiaryHue = TemperatureCache(primary).analogous()[3].hue;
          log(() =>
              'tertiary has 0 candidates, going with analogous hue to primary hue ${primary.hue.round()}: ${topTertiaryHue.round()}');
          topTertiaryChroma = backupHct.chroma;
          topTertiaryTone = backupHct.tone;
        } else {
          log(() =>
              'tertiary has ${tertiaryHcts.length} candidates using ${tertiarySelection.label}');
          log(() =>
              'tertiary top candidates: ${describeCandidates(tertiaryHcts)}');
          final tertiaryHuesSmeared = Scorer.createHueToPercentage(
              tertiaryHcts, scorer.hueToPercent, 0);
          topTertiaryHue = tertiaryHuesSmeared
              .indexOf(tertiaryHuesSmeared.reduce(math.max))
              .toDouble();
          log(() =>
              'topTertiaryHue for ${tertiaryHcts.length} candidates: $topTertiaryHue');
          final tertiary = scorer.topHctNearHueFrom(tertiaryHcts,
              hue: topTertiaryHue, backupTone: backupHct.tone);
          log(() =>
              'tertiary representative from rolePool: ${describeHct(tertiary)}');
          topTertiaryChroma = tertiary.chroma;
          topTertiaryTone = tertiary.tone;
        }
      }
    }
    final tertiary = Hct.from(
      topTertiaryHue,
      topTertiaryChroma,
      topTertiaryTone,
      model: colorModel,
    );
    log(() =>
        'threeColorsFromQuantizer done. Primary: $primary, Secondary: $secondary, Tertiary: $tertiary');
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
    //
    // Important: keep the selected primary anchored. Some images, such as a
    // yellow flower with green accents, legitimately select yellow as primary,
    // then produce a close secondary/tertiary pair in green. Promoting that
    // pair would make green primary, which breaks the role semantics.
    if (ensureClosestPairPrimary) {
      final reordered = _ensureClosestPairPrimary(
        [primary, secondary, tertiary],
        debugLog: debugLog,
        traceLog: traceLog,
      );
      log(() => 'threeColorsFromQuantizer final returned roles. '
          'Primary: ${reordered[0]}, Secondary: ${reordered[1]}, '
          'Tertiary: ${reordered[2]}');
      return reordered;
    } else {
      log(() => 'threeColorsFromQuantizer final returned roles. '
          'Primary: $primary, Secondary: $secondary, Tertiary: $tertiary');
      return [primary, secondary, tertiary];
    }
  }

  static List<Hct> _ensureClosestPairPrimary(List<Hct> candidates,
      {bool debugLog = false, List<String>? traceLog}) {
    void log(String Function() message) {
      if (debugLog || traceLog != null) {
        final line = message();
        traceLog?.add(line);
      }
      if (debugLog) {
        // rationale: this is a debug log, so it's ok to print to console
        // ignore: avoid_print
        print(traceLog?.last ?? message());
      }
    }

    if (candidates.length != 3) {
      throw ArgumentError(
          'The list must contain exactly three Hct candidates.');
    }

    final primarySecondaryDistance =
        differenceDegrees(candidates[0].hue, candidates[1].hue);
    final secondaryTertiaryDistance =
        differenceDegrees(candidates[1].hue, candidates[2].hue);
    final tertiaryPrimaryDistance =
        differenceDegrees(candidates[2].hue, candidates[0].hue);
    log(() => 'pairwise distances before closest-pair reorder: '
        'primary-secondary=${primarySecondaryDistance.toStringAsFixed(2)}, '
        'secondary-tertiary=${secondaryTertiaryDistance.toStringAsFixed(2)}, '
        'tertiary-primary=${tertiaryPrimaryDistance.toStringAsFixed(2)}');

    if (primarySecondaryDistance <= tertiaryPrimaryDistance) {
      log(() => 'selected primary is anchored; secondary is already closer. '
          'primary: ${candidates[0].hue.round()} '
          'secondary: ${candidates[1].hue.round()} '
          'tertiary: ${candidates[2].hue.round()}');
      return [candidates[0], candidates[1], candidates[2]];
    }

    log(() => 'selected primary is anchored; tertiary is closer, swapping '
        'secondary/tertiary. primary: ${candidates[0].hue.round()} '
        'secondary: ${candidates[1].hue.round()} '
        'tertiary: ${candidates[2].hue.round()}');
    return [candidates[0], candidates[2], candidates[1]];
  }

  static _CandidateSelection _selectSecondaryCandidates(
    List<Hct> candidates, {
    required Hct primary,
  }) {
    final preferred = candidates.where((hct) {
      return differenceDegrees(hct.hue, primary.hue) >= 30;
    }).toList();
    if (preferred.isNotEmpty) {
      return _CandidateSelection('>=30deg from primary', preferred);
    }

    final relaxed = candidates.where((hct) {
      return differenceDegrees(hct.hue, primary.hue) >= 15;
    }).toList();
    if (relaxed.isNotEmpty) {
      return _CandidateSelection('>=15deg from primary', relaxed);
    }

    final farthest = _farthestFromPrimary(candidates, primary: primary);
    if (farthest == null) {
      return const _CandidateSelection('none', []);
    }
    return _CandidateSelection('farthest from primary', [farthest]);
  }

  static _CandidateSelection _selectTertiaryCandidates(
    List<Hct> candidates, {
    required Hct primary,
    required Hct secondary,
    required bool avoidsPrimary,
    required bool avoidsSecondary,
  }) {
    for (final threshold in [45.0, 30.0, 15.0]) {
      final matching = candidates.where((hct) {
        final farEnoughFromPrimary = !avoidsPrimary ||
            differenceDegrees(hct.hue, primary.hue) >= threshold;
        final farEnoughFromSecondary = !avoidsSecondary ||
            differenceDegrees(hct.hue, secondary.hue) >= threshold;
        return farEnoughFromPrimary && farEnoughFromSecondary;
      }).toList();
      if (matching.isNotEmpty) {
        return _CandidateSelection(
            '>=${threshold.round()}deg from primary/secondary', matching);
      }
    }

    final farthest = _farthestFromPrimaryAndSecondary(
      candidates,
      primary: primary,
      secondary: secondary,
    );
    if (farthest == null) {
      return const _CandidateSelection('none', []);
    }
    return _CandidateSelection('farthest from primary/secondary', [farthest]);
  }

  static Hct? _farthestFromPrimary(
    List<Hct> candidates, {
    required Hct primary,
  }) {
    if (candidates.isEmpty) return null;
    return candidates.reduce((best, contender) {
      final bestDistance = differenceDegrees(best.hue, primary.hue);
      final contenderDistance = differenceDegrees(contender.hue, primary.hue);
      return contenderDistance > bestDistance ? contender : best;
    });
  }

  static Hct? _farthestFromPrimaryAndSecondary(
    List<Hct> candidates, {
    required Hct primary,
    required Hct secondary,
  }) {
    if (candidates.isEmpty) return null;
    return candidates.reduce((best, contender) {
      final bestDistance = math.min(
        differenceDegrees(best.hue, primary.hue),
        differenceDegrees(best.hue, secondary.hue),
      );
      final contenderDistance = math.min(
        differenceDegrees(contender.hue, primary.hue),
        differenceDegrees(contender.hue, secondary.hue),
      );
      return contenderDistance > bestDistance ? contender : best;
    });
  }
}

class _CandidateSelection {
  const _CandidateSelection(this.label, this.candidates);

  final String label;
  final List<Hct> candidates;
}
