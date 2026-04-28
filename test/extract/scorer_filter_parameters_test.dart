import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/core/hex_codes.dart';
import 'package:libmonet/extract/extract.dart';
import 'package:libmonet/extract/scorer.dart';
import 'package:libmonet/extract/scorer_triad.dart';

void main() {
  testWidgets('Scorer honors tone and chroma filter parameters',
      (tester) async {
    await tester.runAsync(() async {
      final image = FileImage(File(
        'test/fixtures/wallpapers/henrique-ferreira-lneox9o1MjU-unsplash.jpg',
      ));
      final result = await Extract.quantize(image, 32);

      final defaults = Scorer(result, colorModel: ColorModel.cam16v11);
      final noToneFilter = Scorer(
        result,
        colorModel: ColorModel.cam16v11,
        toneTooLow: null,
        toneTooHigh: null,
      );
      final noChromaFilter = Scorer(
        result,
        colorModel: ColorModel.cam16v11,
        minChroma: 0,
      );
      final noToneOrChromaFilter = Scorer(
        result,
        colorModel: ColorModel.cam16v11,
        toneTooLow: null,
        toneTooHigh: null,
        minChroma: 0,
      );

      expect(noToneFilter.hcts.length, defaults.hcts.length);
      expect(noChromaFilter.hcts.length, greaterThan(defaults.hcts.length));
      expect(noToneOrChromaFilter.hcts.length,
          greaterThanOrEqualTo(noChromaFilter.hcts.length));

      final defaultTriad = ScorerTriad.threeColorsFromQuantizer(
        result,
        colorModel: ColorModel.cam16v11,
      );
      final noChromaTriad = ScorerTriad.threeColorsFromQuantizer(
        result,
        colorModel: ColorModel.cam16v11,
        minChroma: 0,
      );

      expect(defaultTriad.map((hct) => hexFromColor(hct.color)).toList(), [
        '#F9DEB9',
        '#E6B09D',
        '#668290',
      ]);
      expect(noChromaTriad.map((hct) => hexFromColor(hct.color)).toList(), [
        '#EDE7E3',
        '#E7E4E3',
        '#A1ACB5',
      ]);
    });
  });
}
