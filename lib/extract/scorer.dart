import 'package:libmonet/argb_srgb_xyz_lab.dart';
import 'package:libmonet/extract/quantizer_result.dart';
import 'package:libmonet/hct.dart';

class Scorer {
  final QuantizerResult quantizerResult;
  final List<Hct> hcts = [];
  final Map<Hct, int> hctToCount = {};
  final List<double> hueToPercent = List.filled(361, 0.0);
  final List<double> hueToSmearedPercent = List.filled(361, 0.0);

  Scorer(this.quantizerResult) {
    const smearDistance = 7.0;

    // 1. Get all colors that are not too dark or too light
    final argbToCount = quantizerResult.argbToCount;
    if (argbToCount.isEmpty) {
      return;
    }
    final filteredHcts = argbToCount.keys
        .map((color) {
          final hct = Hct.fromInt(color);
          hctToCount[hct] = argbToCount[color]!;
          return hct;
        })
        .where((element) =>
            element.tone >= 10 && element.tone <= 95 && element.chroma > 16)
        .toList();
    hcts.addAll(filteredHcts);

    // 2. Get the percentage of each color
    // Use colorToCount to get the total count of all colors, instead of HCTs,
    // because we want to count all colors, not just the ones that are not too
    // dark or too light.
    final totalCount = argbToCount.values.fold(0, (previousValue, element) {
      return previousValue + element;
    });

    final colorToPercent =
        argbToCount.map((key, value) => MapEntry(key, value / totalCount));
    for (final hct in filteredHcts) {
      final hue = hct.hue.round();
      final percentage = colorToPercent[hct.toInt()]!;
      hueToPercent[hue] += percentage;
    }

    for (var i = 0; i < 361; i++) {
      final hue = i;
      final percentage = hueToPercent[i];
      if (percentage == 0.0) continue;
      hueToSmearedPercent[hue] += percentage;
      for (double i = 1.0; i < smearDistance; i += 1.0) {
        hueToSmearedPercent[sanitizeDegreesDouble(hue + i).round()] +=
            percentage;
        hueToSmearedPercent[sanitizeDegreesDouble(hue - i).round()] +=
            percentage;
      }
    }
  }

  static List<double> createHueToPercentage(
    List<Hct> hcts,
    List<double> hueToPercent,
    double smearDistance,
  ) {
    final smearedHuesNearSurfaceTone = List.filled(361, 0.0);
    for (final hct in hcts) {
      final hue = hct.hue;
      final count = hueToPercent[hue.round()];
      smearedHuesNearSurfaceTone[hue.round()] += count;
      for (double i = 1.0; i < smearDistance; i += 1.0) {
        smearedHuesNearSurfaceTone[sanitizeDegreesDouble(hue + i).round()] +=
            count;
        smearedHuesNearSurfaceTone[sanitizeDegreesDouble(hue - i).round()] +=
            count;
      }
    }
    return smearedHuesNearSurfaceTone;
  }

  Hct averagedHctNearHue({required double hue, required double backupTone}) {
    final hctsNearHue =
        hcts.where((hct) => differenceDegrees(hct.hue, hue) < 15);
    final totalCount = hctsNearHue.fold(0, (previousValue, element) {
      return previousValue + hctToCount[element]!;
    });
    if (totalCount == 0) {
      return Hct.from(hue, 8.0, backupTone);
    }

    final chromaSum = hctsNearHue.fold(0.0, (previousValue, element) {
      return previousValue + (hctToCount[element]! * element.chroma);
    });
    final chroma = hctsNearHue.isEmpty ? 8.0 : (chromaSum / totalCount);
    final toneSum = hctsNearHue.fold(0.0, (previousValue, element) {
      return previousValue + (hctToCount[element]! * element.tone);
    });
    final tone = hctsNearHue.isEmpty ? backupTone : (toneSum / totalCount);

    return Hct.from(hue, chroma, tone);
  }

  Hct topHctNearHue({required double hue, required double backupTone}) {
    final hctsNearHue =
        hcts.where((hct) => differenceDegrees(hct.hue, hue) < 15);
    if (hctsNearHue.isEmpty) {
      return Hct.from(hue, 8.0, backupTone);
    }
    final topHct = hctsNearHue.reduce((value, element) {
      return hctToCount[value]! > hctToCount[element]! ? value : element;
    });
    return topHct;
  }

  double huePercent(int hue) {
    return hueToPercent[hue];
  }
}
