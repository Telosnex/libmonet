import 'package:example/padding.dart';
import 'package:example/swatch.dart';
import 'package:flutter/material.dart';
import 'package:libmonet/contrast.dart';
import 'package:libmonet/hct.dart';
import 'package:libmonet/safe_colors.dart';
import 'package:libmonet/theming/button_style.dart';

class SafeColorsPreviewRow extends StatelessWidget {
  final Color color;
  final double backgroundLstar;
  final Algo algo;
  final double contrast;

  const SafeColorsPreviewRow(
      {super.key,
      required this.color,
      required this.contrast,
      required this.algo,
      required this.backgroundLstar});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Hct.colorFrom(0, 0, backgroundLstar),
      padding: const EdgeInsets.all(8),
      child: _safeColorsRow(
        context,
        SafeColors.from(color, backgroundLstar: backgroundLstar, contrast: contrast, algo: algo),
      ),
    );
  }

  Widget _safeColorsRow(BuildContext context, SafeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: kMinInteractiveDimension,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Swatch(
                color: colors.color,
                tooltip: 'Color',
              ),
              Swatch(
                color: colors.colorBorder,
                tooltip: 'Color Border',
              ),
              Swatch(
                color: colors.text,
                tooltip: 'Color Text',
              ),
              Swatch(
                color: colors.fill,
                tooltip: 'Fill',
              ),
              Swatch(
                color: colors.fillText,
                tooltip: 'Fill Text',
              ),
              Swatch(
                color: colors.text,
                tooltip: 'Text',
              ),
            ],
          ),
        ),
        SizedBox(
            height: kMinInteractiveDimension,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
             
                OutlinedButton(
                  style: buttonStylefromSafeColorsColor(colors),
                  onPressed: () {},
                  child: const Text('Color'),
                ),
                const HorizontalPadding(),
                OutlinedButton(
                    style: buttonStylefromSafeColorsFill(colors),
                    onPressed: () {},
                    child: const Text('Fill')),
                const HorizontalPadding(),
                TextButton(
                  style: buttonStylefromSafeColorsText(colors),
                  onPressed: () {},
                  child: const Text('Text'),
                ),
                const HorizontalPadding(),
              ],
            ))
      ],
    );
  }
}
