import 'dart:math' as math;
import 'dart:ui';

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
    final colorBorder = contrastingLstar(
      withLstar: backgroundLstar,
      usage: Usage.fill,
      by: algo,
      contrastPercentage: contrast,

    );
    final colorText = contrastingLstar(
      withLstar: colorHct.tone,
      usage: Usage.text,
      by: algo,
      contrastPercentage: contrast,
    );
    final colorIcon = contrastingLstar(
      withLstar: colorHct.tone,
      usage: Usage.fill,
      by: algo,
      contrastPercentage: contrast,
    );

    final fill = contrastingLstar(
      withLstar: backgroundLstar,
      usage: Usage.fill,
      by: algo,
      contrastPercentage: contrast,
    );
    final fillText = contrastingLstar(
      withLstar: fill,
      usage: Usage.text,
      by: algo,
      contrastPercentage: contrast,
    );
    final fillIcon = contrastingLstar(
      withLstar: fill,
      usage: Usage.fill,
      by: algo,
      contrastPercentage: contrast,
    );
    final text = contrastingLstar(
      withLstar: backgroundLstar,
      usage: Usage.text,
      by: algo,
      contrastPercentage: contrast,
    );

    final hoverContrast = math.max(contrast - 0.3, 0.0);
    final splashContrast =  math.max(contrast - 0.2, 0.0);
    final colorHover = contrastingLstar(
      withLstar: colorHct.tone,
      usage: Usage.fill,
      by: algo,
      contrastPercentage: hoverContrast,
    );
    final colorSplash = contrastingLstar(
      withLstar: colorHct.tone,
      usage: Usage.fill,
      by: algo,
      contrastPercentage: splashContrast,
    );
    final fillHover = contrastingLstar(
      withLstar: fill,
      usage: Usage.fill,
      by: algo,
      contrastPercentage: hoverContrast,
    );
    final fillSplash = contrastingLstar(
      withLstar: fill,
      usage: Usage.fill,
      by: algo,
      contrastPercentage: splashContrast,
    );
    final textHover = contrastingLstar(
      withLstar: backgroundLstar,
      usage: Usage.text,
      by: algo,
      contrastPercentage: hoverContrast,
    );
    final textSplash = contrastingLstar(
      withLstar: backgroundLstar,
      usage: Usage.text,
      by: algo,
      contrastPercentage: splashContrast,
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
