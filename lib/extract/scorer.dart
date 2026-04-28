import 'package:libmonet/core/argb_srgb_xyz_lab.dart';
import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/extract/quantizer_result.dart';
import 'package:libmonet/colorspaces/hct.dart';

double _minChroma(ColorModel model) {
  switch (model) {
    case ColorModel.oklch:
      return 0.04;
    case ColorModel.cam16:
      return 16;
    case ColorModel.cam16v11:
      return 8;
  }
}

class Scorer {
  final QuantizerResult quantizerResult;
  final List<Hct> hcts = [];
  final Map<Hct, int> hctToCount = {};
  final List<double> hueToPercent = List.filled(361, 0.0);
  final List<double> primaryHueToPercent = List.filled(361, 0.0);
  final ColorModel colorModel;
  final List<double> hueToSmearedPercent = List.filled(361, 0.0);
  final List<double> primaryHueToSmearedPercent = List.filled(361, 0.0);

  Scorer(
    this.quantizerResult, {
    double? toneTooLow = 10,
    double? toneTooHigh = 95,
    double? minChroma,
    this.colorModel = ColorModel.kDefault,
  }) {
    const smearDistance = 7.0;
    final effectiveMinChroma = minChroma ?? _minChroma(colorModel);
    // 1. Get all colors that are not too dark or too light
    final argbToCount = quantizerResult.argbToCount;
    if (argbToCount.isEmpty) {
      return;
    }
    final intermediate = argbToCount.keys.map((color) {
      final hct = Hct.fromInt(color, model: colorModel);
      hctToCount[hct] = argbToCount[color]!;
      return hct;
    }).toList();

    final toneFilteredHcts = intermediate.where((element) {
      final meetsLow = toneTooLow == null || element.tone >= toneTooLow;
      final meetsHigh = toneTooHigh == null || element.tone <= toneTooHigh;
      return meetsLow && meetsHigh;
    }).toList();
    final filteredHcts = toneFilteredHcts
        .where((element) => element.chroma >= effectiveMinChroma);
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
    for (final hct in toneFilteredHcts) {
      final hue = hct.hue.round();
      final percentage = colorToPercent[hct.toInt()]!;
      primaryHueToPercent[hue] += percentage;
    }

    _smearHuePercentages(
      hueToPercent,
      hueToSmearedPercent,
      smearDistance,
    );
    _smearHuePercentages(
      primaryHueToPercent,
      primaryHueToSmearedPercent,
      smearDistance,
    );
  }

  static void _smearHuePercentages(
    List<double> source,
    List<double> target,
    double smearDistance,
  ) {
    for (var i = 0; i < 361; i++) {
      final hue = i;
      final percentage = source[i];
      if (percentage == 0.0) continue;
      target[hue] += percentage;
      for (double offset = 1.0; offset < smearDistance; offset += 1.0) {
        target[sanitizeDegreesDouble(hue + offset).round()] += percentage;
        target[sanitizeDegreesDouble(hue - offset).round()] += percentage;
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
      return Hct.from(hue, 8.0, backupTone, model: colorModel);
    }

    final chromaSum = hctsNearHue.fold(0.0, (previousValue, element) {
      return previousValue + (hctToCount[element]! * element.chroma);
    });
    final chroma = hctsNearHue.isEmpty ? 8.0 : (chromaSum / totalCount);
    final toneSum = hctsNearHue.fold(0.0, (previousValue, element) {
      return previousValue + (hctToCount[element]! * element.tone);
    });
    final tone = hctsNearHue.isEmpty ? backupTone : (toneSum / totalCount);

    return Hct.from(hue, chroma, tone, model: colorModel);
  }

  Hct topHctNearHue({required double hue, required double backupTone}) {
    return topHctNearHueFrom(hcts, hue: hue, backupTone: backupTone);
  }

  Hct topHctNearHueFrom(
    Iterable<Hct> candidates, {
    required double hue,
    required double backupTone,
  }) {
    final hctsNearHue =
        candidates.where((hct) => differenceDegrees(hct.hue, hue) < 15);
    if (hctsNearHue.isEmpty) {
      return Hct.from(hue, 8.0, backupTone, model: colorModel);
    }
    final topHct = hctsNearHue.reduce((value, element) {
      return hctToCount[value]! > hctToCount[element]! ? value : element;
    });
    return topHct;
  }

  double huePercent(int hue) {
    return hueToPercent[hue];
  }

  double primaryHuePercent(int hue) {
    return primaryHueToPercent[hue];
  }
}
