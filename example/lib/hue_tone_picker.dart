import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:libmonet/hct.dart';

class HueTonePicker extends HookConsumerWidget {
  final Color color;
  final Function(double hue, double tone) onChanged;
  const HueTonePicker(
      {super.key, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hct = useMemoized(() => Hct.fromColor(color), [color]);
    final chroma = hct.chroma;
    final panningHue = useState(hct.hue);
    final panningTone = useState(hct.tone);
    final panningHct = Hct.from(panningHue.value, chroma, panningTone.value);
    // If hue / chroma / tone aren't within 3.0 / 3.0 / 3.0 of the original
    // color, then we need to update the panningHue and panningTone.
    //
    // Reminder: for hue, handle edge cases from wrapping
    final hueDelta = hct.hue - panningHct.hue;
    final hueDeltaWrapped =
        hueDelta.abs() > 180 ? 360 - hueDelta.abs() : hueDelta.abs();
    final toneDelta = (hct.tone - panningHct.tone).abs();
    final chromaDelta = (hct.chroma - panningHct.chroma).abs();
    if ((hueDeltaWrapped > 3.0 && toneDelta > 3.0) || chromaDelta > 3.0) {
      panningHue.value = hct.hue;
      panningTone.value = hct.tone;
    }

    return GestureDetector(
      onPanDown: (details) => _handleDrag(
        context,
        details.localPosition,
        panningHue,
        panningTone,
      ),
      onPanUpdate: (details) {
        _handleDrag(
          context,
          details.localPosition,
          panningHue,
          panningTone,
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _HueTone(chroma: chroma),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _Marker(
                hue: panningHue.value,
                tone: panningTone.value,
              ),
            ),
          )
        ],
      ),
    );
  }

  void _handleDrag(
    BuildContext context,
    Offset localPosition,
    ValueNotifier<double> panningHue,
    ValueNotifier<double> panningTone,
  ) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final double width = box.size.width;
    final double height = box.size.height;

    final double hue = (localPosition.dx / width).clamp(0.0, 1.0);
    final double value = (1 - localPosition.dy / height).clamp(0.0, 1.0);
    final panningHueValue = hue * 360.0;
    final panningToneValue = value * 100.0;
    panningHue.value = panningHueValue;
    panningTone.value = panningToneValue;
    onChanged(panningHue.value, panningTone.value);
  }
}

class _Marker extends CustomPainter {
  final double hue;
  final double tone;

  _Marker({required this.hue, required this.tone});
  @override
  void paint(Canvas canvas, Size size) {
    Offset indicatorPosition = Offset(
      hue / 360.0 * size.width,
      (100 - tone).abs() / 100.0 * size.height,
    );
    // Draw the indicator.
    final indicatorPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    canvas.drawCircle(indicatorPosition, 8, indicatorPaint);
    indicatorPaint.color = Colors.black;
    indicatorPaint.style = PaintingStyle.stroke;
    canvas.drawCircle(indicatorPosition, 8, indicatorPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! _Marker ||
        oldDelegate.hue != hue ||
        oldDelegate.tone != tone;
  }
}

class _HueTone extends CustomPainter {
  static const hueResolution = 1.0;
  static const toneResolution = 2.0;

  final double chroma;
  final List<List<Color>> colors = [];
  bool didPaintOnce = false;
  _HueTone({required this.chroma}) {
    for (var i = 0.0; i < 360; i += hueResolution) {
      colors.add([]);
      for (var j = 100.0; j > 0; j -= toneResolution) {
        colors.last
            .add(Color(Hct.from(i.toDouble(), chroma, j.toDouble()).toInt()));
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    const numberOfHues = 360 ~/ hueResolution;
    const numberOfTones = 100 ~/ toneResolution;
    final cellWidth = size.width / numberOfHues;
    final cellHeight = size.height / numberOfTones;

    // Draw the hue tone grid.
    final hueTonePaint = Paint()..style = PaintingStyle.fill;
    var left = 0.0;
    for (var i = 0.0; i < 360; i += hueResolution) {
      var top = 0.0;
      final hueColors = colors[i ~/ hueResolution];
      for (var j = 100.0; j > 0; j -= toneResolution) {
        hueTonePaint.color = hueColors[hueColors.length - j ~/ toneResolution];
        canvas.drawRect(
          Rect.fromLTWH(
            left,
            top,
            cellWidth + 0.5,
            cellHeight,
          ),
          hueTonePaint,
        );
        top += cellHeight;
      }
      left += cellWidth;
    }
  }

  @override
  bool shouldRepaint(_HueTone old) {
    final shouldRepaint = old.chroma != chroma;
    return shouldRepaint;
  }
}
