import 'dart:math' as math;
import 'dart:ui';

import 'package:libmonet/apca.dart';
import 'package:libmonet/contrast.dart';
import 'package:libmonet/hct.dart';

class SafeColors {
  final Color background;
  final Color backgroundText;
  
  final Color color;
  final Color colorHover;
  final Color colorSplash;

  final Color colorText;
  final Color colorHoverText;
  final Color colorSplashText;

  final Color colorIcon;
  final Color colorBorder;

  final Color fill;
  final Color fillHover;
  final Color fillSplash;

  final Color fillHoverText;
  final Color fillSplashText;

  final Color fillText;
  final Color fillIcon;

  final Color text;
  final Color textHover;
  final Color textHoverText;
  final Color textSplash;
  final Color textSplashText;

  SafeColors({
    required this.background,
    required this.backgroundText,
    required this.color,
    required this.colorText,
    required this.colorBorder,
    required this.colorIcon,
    required this.colorHover,
    required this.colorHoverText,
    required this.colorSplashText,
    required this.colorSplash,
    required this.fill,
    required this.fillText,
    required this.fillHoverText,
    required this.fillSplashText,
    required this.fillIcon,
    required this.fillHover,
    required this.fillSplash,
    required this.text,
    required this.textHover,
    required this.textHoverText,
    required this.textSplash,
    required this.textSplashText,
  });

  factory SafeColors.from(
    Color color, {
    required double backgroundLstar,
    double contrast = 0.5,
    Algo algo = Algo.apca,
  }) {
    final hoverContrast = math.max(contrast - 0.3, 0.1);
    final splashContrast = math.max(contrast - 0.15, 0.25);
    final colorHct = Hct.fromColor(color);
    bool needBorder = false;
    switch (algo) {
      case Algo.wcag21:
        final requiredContrastRatio =
            contrastRatioInterpolation(percent: contrast, usage: Usage.fill);
        final actualContrastRatio =
            contrastRatioOfLstars(colorHct.tone, backgroundLstar);
        if (actualContrastRatio < requiredContrastRatio) {
          needBorder = true;
        }
        break;
      case Algo.apca:
        final apca = apcaContrastOfApcaY(
            lstarToApcaY(colorHct.tone), lstarToApcaY(backgroundLstar));
        final requiredApca =
            apcaInterpolation(percent: contrast, usage: Usage.fill);
        if (apca.abs() < requiredApca.abs()) {
          needBorder = true;
        }
        break;
    }

    final backgroundHct =
        Hct.from(colorHct.hue, colorHct.chroma, backgroundLstar);
    final backgroundTextTone = contrastingLstar(
      withLstar: backgroundLstar,
      usage: Usage.text,
      by: algo,
      contrast: contrast,
    );
    final colorBorder = !needBorder
        ? colorHct.tone
        : contrastingLstar(
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
    final colorTextSplash = contrastingLstar(
      withLstar: colorSplash,
      usage: Usage.text,
      by: algo,
      contrast: contrast,
    );
    final colorTextHover = contrastingLstar(
      withLstar: colorHover,
      usage: Usage.text,
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
    final fillTextHover = contrastingLstar(
      withLstar: fillHover,
      usage: Usage.text,
      by: algo,
      contrast: contrast,
    );
    final fillTextSplash = contrastingLstar(
      withLstar: fillSplash,
      usage: Usage.text,
      by: algo,
      contrast: contrast,
    );

    final text = contrastingLstar(
      withLstar: backgroundLstar,
      usage: Usage.text,
      by: algo,
      contrast: contrast,
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
    final textHoverText = contrastingLstar(
      withLstar: textHover,
      usage: Usage.text,
      by: algo,
      contrast: contrast,
    );
    final textSplashText = contrastingLstar(
      withLstar: textSplash,
      usage: Usage.text,
      by: algo,
      contrast: contrast,
    );
    final hue = colorHct.hue;
    final chroma = colorHct.chroma;
    return SafeColors(
      background: backgroundHct.color,
      backgroundText: Hct.colorFrom(
          backgroundHct.hue, backgroundHct.chroma, backgroundTextTone),
      color: color,
      colorHover: Hct.colorFrom(hue, chroma, colorHover),
      colorSplash: Hct.colorFrom(hue, chroma, colorSplash),
      colorBorder: Hct.colorFrom(hue, chroma, colorBorder),
      colorText: Hct.colorFrom(hue, chroma, colorText),
      colorHoverText: Hct.colorFrom(hue, chroma, colorTextHover),
      colorSplashText: Hct.colorFrom(hue, chroma, colorTextSplash),
      colorIcon: Hct.colorFrom(hue, chroma, colorIcon),
      fill: Hct.colorFrom(hue, chroma, fill),
      fillText: Hct.colorFrom(hue, chroma, fillText),
      fillHoverText: Hct.colorFrom(hue, chroma, fillTextHover),
      fillSplashText: Hct.colorFrom(hue, chroma, fillTextSplash),
      fillIcon: Hct.colorFrom(hue, chroma, fillIcon),
      fillHover: Hct.colorFrom(hue, chroma, fillHover),
      fillSplash: Hct.colorFrom(hue, chroma, fillSplash),
      text: Hct.colorFrom(hue, chroma, text),
      textHover: Hct.colorFrom(hue, chroma, textHover),
      textHoverText: Hct.colorFrom(hue, chroma, textHoverText),
      textSplash: Hct.colorFrom(hue, chroma, textSplash),
      textSplashText: Hct.colorFrom(hue, chroma, textSplashText),
    );
  }
}
