import 'package:example/padding.dart';

import 'package:flutter/material.dart';
import 'package:libmonet/safe_colors.dart';
import 'package:libmonet/theming/button_style.dart';


class SafeColorsPreviewRow extends StatelessWidget {
  final SafeColors safeColors;

  const SafeColorsPreviewRow({
    required this.safeColors,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return _safeColorsRow(context, safeColors);
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
                ElevatedButton(
                    style: elevatedButtonStyleFromColors(colors),
                    onPressed: () {},
                    child: const Text('Elevated')),
                const HorizontalPadding(),
                FilledButton(
                  style: filledButtonStyleFromColors(colors),
                  onPressed: () {},
                  child: const Text('Filled'),
                ),
                const HorizontalPadding(),
                OutlinedButton(
                  onPressed: () {},
                  style: outlineButtonStyleFromColors(safeColors),
                  child: const Text('Outline'),
                ),
                const HorizontalPadding(),
                TextButton(
                  onPressed: () {},
                  style: textButtonStyleFromColors(safeColors),
                  child: const Text('Text'),
                ),
              ],
            ))
      ],
    );
  }
}
