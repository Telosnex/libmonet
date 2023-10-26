import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class SliderFlatThumb extends SliderComponentShape {
  final double thumbRadius;
  final IconData? iconData;
  final Color borderColor;
  final double borderWidth;
  final Color? iconColor;

  SliderFlatThumb({this.thumbRadius = 18, this.iconData, this.iconColor, required this.borderColor, required this.borderWidth});

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
    canvas.drawArc(
      Rect.fromCenter(center: center, width: 2 * thumbRadius, height: 2 * thumbRadius)
          .deflate(borderWidth / 2),
      math.pi / 2,
      -math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..color = borderColor,
    );
    final concreteIconData = iconData;
    if (concreteIconData == null) return;

    // Paint icon
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas iconCanvas = Canvas(pictureRecorder);
    final double iconSize = thumbRadius * 2 - 16; // Change as needed
    final ui.ParagraphBuilder builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontFamily: concreteIconData.fontFamily,
      fontSize: iconSize,
    ))
      ..pushStyle(ui.TextStyle(
        color: iconColor, // specify the colour you wish here
        fontSize: iconSize,
      ))
      ..addText(String.fromCharCode(concreteIconData.codePoint));
    final ui.Paragraph paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: iconSize));
    final double iconHeight = paragraph.height;
    final double iconWidth = paragraph.minIntrinsicWidth;
    iconCanvas.drawParagraph(paragraph,
        Offset(center.dx - iconWidth / 2, center.dy - iconHeight / 2));
    final ui.Picture p = pictureRecorder.endRecording();
    canvas.drawPicture(p);
  }
}
