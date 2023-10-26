import 'package:flutter/material.dart';

class SliderFlatThumb extends SliderComponentShape {
  final double thumbRadius;

  SliderFlatThumb({this.thumbRadius = 18});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius);
  }

  @override
  void paint(PaintingContext context, Offset center,
      {required Animation<double> activationAnimation,
      required Animation<double> enableAnimation,
      bool? isDiscrete,
      TextPainter? labelPainter,
      RenderBox? parentBox,
      required SliderThemeData sliderTheme,
      TextDirection? textDirection,
      double? value,
      double? textScaleFactor,
      Size? sizeWithOverflow}) {
    final Canvas canvas = context.canvas;
    final ColorTween colorTween = ColorTween(
        begin: sliderTheme.disabledThumbColor, end: sliderTheme.thumbColor);
    final paint = Paint()..color = colorTween.evaluate(enableAnimation)!;
    canvas.drawCircle(center, thumbRadius, paint);
  }
}
