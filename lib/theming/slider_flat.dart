import 'package:flutter/material.dart';
import 'package:libmonet/theming/monet_theme.dart';

class SliderFlat extends StatelessWidget {
  final Color? borderColor;
  final double? borderWidth;
  final Widget slider;
  const SliderFlat({
    super.key,
    this.borderColor,
    this.borderWidth,
    required this.slider,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = this.borderColor ??
        MonetTheme.of(context).primary.colorBorder;
    final borderWidth = this.borderWidth ?? 2;
    final sliderTheme = Theme.of(context).sliderTheme;
    final trackHeight = sliderTheme.trackHeight!;
    final activeTrackColor = sliderTheme.activeTrackColor;
    final thumbWidth =
        sliderTheme.thumbShape!.getPreferredSize(true, true).width + 1.0;
    final backgroundColor = sliderTheme.inactiveTrackColor;
    final sliderWrapped = Stack(
      children: [
        Row(
          children: [
            Container(
              width: thumbWidth,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(trackHeight / 2),
                color: activeTrackColor ??
                    Theme.of(context).sliderTheme.activeTrackColor,
              ),
              height: trackHeight,
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(trackHeight / 2),
                  color: backgroundColor,
                ),
                height: trackHeight,
              ),
            ),
          ],
        ),
        Positioned.fill(
          child: slider,
        ),
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(trackHeight / 2),
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            height: trackHeight,
          ),
        ),
      ],
    );
    return sliderWrapped;
  }
}
