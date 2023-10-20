import 'dart:math' as math;
import 'dart:ui';

import 'package:libmonet/apca.dart';
import 'package:libmonet/contrast.dart';
import 'package:libmonet/hct.dart';

class SafeColors {
  final Color color;
  final Color colorBorder;
  final Color colorText;
  final Color colorIcon;
  final Color colorHover;
  final Color colorSplash;

  final Color fill;
  final Color fillText;
  final Color fillIcon;
  final Color fillHover;
  final Color fillSplash;

  final Color text;
  final Color textHover;
  final Color textSplash;

  SafeColors({
    required this.color,
    required this.colorBorder,
    required this.colorText,
    required this.colorIcon,
    required this.colorHover,
    required this.colorSplash,
    required this.fill,
    required this.fillText,
    required this.fillIcon,
    required this.fillHover,
    required this.fillSplash,
    required this.text,
    required this.textHover,
    required this.textSplash,
  });

  factory SafeColors.from(
    Color color, {
    required double backgroundLstar,
    double contrast = 0.5,
    Algo algo = Algo.apca,
  }) {
    final colorHct = Hct.fromColor(color);
    bool needBorder = false;
    switch (algo) {
      case Algo.wcag21:
        final requiredContrastRatio = contrastRatioInterpolation(percent: contrast, usage: Usage.fill);
        final actualContrastRatio = contrastRatioOfLstars(colorHct.tone, backgroundLstar);
        if (actualContrastRatio < requiredContrastRatio) {
          needBorder = true;
        }
        break;
      case Algo.apca:
        final  apca = apcaContrastOfApcaY(lstarToApcaY(colorHct.tone), lstarToApcaY(backgroundLstar));
        final requiredApca = apcaInterpolation(percent: contrast, usage: Usage.fill);
        if (apca.abs() < requiredApca.abs()) {
          needBorder = true;
        }
        break;
    }
  
    final colorBorder = !needBorder ? colorHct.tone : contrastingLstar(
      withLstar: backgroundLstar,
      usage: Usage.fill,
      by: algo,
      contrast: contrast,

    );
    final colorText = contrastingLstar(
      withLstar: colorHct.tone,
      usage: Usage.text,
      by: algo,
      contrast: contrast,
    );
    final colorIcon = contrastingLstar(
      withLstar: colorHct.tone,
      usage: Usage.fill,
      by: algo,
      contrast: contrast,
    );

    final fill = colorBorder;
    final fillText = contrastingLstar(
      withLstar: fill,
      usage: Usage.text,
      by: algo,
      contrast: contrast,
    );
    final fillIcon = contrastingLstar(
      withLstar: fill,
      usage: Usage.fill,
      by: algo,
      contrast: contrast,
    );
    final text = contrastingLstar(
      withLstar: backgroundLstar,
      usage: Usage.text,
      by: algo,
      contrast: contrast,
    );

    final hoverContrast = math.max(contrast - 0.3, 0.0);
    final splashContrast =  math.max(contrast - 0.2, 0.0);
    final colorHover = contrastingLstar(
      withLstar: colorHct.tone,
      usage: Usage.fill,
      by: algo,
      contrast: hoverContrast,
    );
    final colorSplash = contrastingLstar(
      withLstar: colorHct.tone,
      usage: Usage.fill,
      by: algo,
      contrast: splashContrast,
    );
    final fillHover = contrastingLstar(
      withLstar: fill,
      usage: Usage.fill,
      by: algo,
      contrast: hoverContrast,
    );
    final fillSplash = contrastingLstar(
      withLstar: fill,
      usage: Usage.fill,
      by: algo,
      contrast: splashContrast,
    );
    final textHover = contrastingLstar(
      withLstar: backgroundLstar,
      usage: Usage.text,
      by: algo,
      contrast: hoverContrast,
    );
    final textSplash = contrastingLstar(
      withLstar: backgroundLstar,
      usage: Usage.text,
      by: algo,
      contrast: splashContrast,
    );
    final hue = colorHct.hue;
    final chroma = colorHct.chroma;
    return SafeColors(
      color: color,
      colorBorder: Hct.colorFrom(hue, chroma, colorBorder),
      colorText: Hct.colorFrom(hue, chroma, colorText),
      colorIcon: Hct.colorFrom(hue, chroma, colorIcon),
      colorHover: Hct.colorFrom(hue, chroma, colorHover),
      colorSplash: Hct.colorFrom(hue, chroma, colorSplash),
      fill: Hct.colorFrom(hue, chroma, fill),
      fillText: Hct.colorFrom(hue, chroma, fillText),
      fillIcon: Hct.colorFrom(hue, chroma, fillIcon),
      fillHover: Hct.colorFrom(hue, chroma, fillHover),
      fillSplash: Hct.colorFrom(hue, chroma, fillSplash),
      text: Hct.colorFrom(hue, chroma, text),
      textHover: Hct.colorFrom(hue, chroma, textHover),
      textSplash: Hct.colorFrom(hue, chroma, textSplash),
    );
  }
}
