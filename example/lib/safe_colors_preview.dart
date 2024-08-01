import 'package:libmonet/opacity.dart';
import 'package:libmonet/shadows.dart';
import 'package:monet_studio/padding.dart';

import 'package:flutter/material.dart';
import 'package:libmonet/safe_colors.dart';
import 'package:libmonet/theming/button_style.dart';

class SafeColorsPreviewRow extends StatelessWidget {
  final SafeColors safeColors;
  final OpacityResult? scrim;
  final ShadowResult? shadows;

  const SafeColorsPreviewRow({
    required this.safeColors,
    super.key,
    this.scrim,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return _safeColorsRow(context, safeColors);
  }

  Widget _safeColorsRow(BuildContext context, SafeColors colors) {
    final textButtonStyleBase = textButtonStyleFromColors(safeColors);
    final textButtonStyle = textButtonStyleBase.copyWith(
        textStyle: WidgetStateProperty.resolveWith((states) {
      final base = textButtonStyleBase.textStyle?.resolve(states);
      if (shadows == null) {
        return base;
      }
      return base?.copyWith(
        shadows: shadows!.shadows,
      );
    }));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
            height: kMinInteractiveDimension,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton(
                    style: filledButtonBackgroundIsColor(colors),
                    onPressed: () {},
                    child: const Text('Color')),
                const HorizontalPadding(),
                FilledButton(
                  style: filledButtonBackgroundIsFill(colors),
                  onPressed: () {},
                  child: const Text('Fill'),
                ),
                const HorizontalPadding(),
                TextButton(
                  onPressed: () {},
                  style: textButtonStyle,
                  child: const Text(
                    'Text',
                  ),
                ),
              ],
            ))
      ],
    );
  }
}
