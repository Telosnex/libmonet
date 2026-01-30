import 'package:libmonet/effects/opacity.dart';
import 'package:libmonet/effects/shadows.dart';
import 'package:libmonet/theming/palette.dart';
import 'package:monet_studio/padding.dart';

import 'package:flutter/material.dart';
import 'package:libmonet/theming/button_style.dart';

class PalettePreviewRow extends StatelessWidget {
  final Palette palette;
  final OpacityResult? scrim;
  final ShadowResult? shadows;

  const PalettePreviewRow({
    required this.palette,
    super.key,
    this.scrim,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return _paletteRow(context, palette);
  }

  Widget _paletteRow(BuildContext context, Palette colors) {
    final textButtonStyleBase = fillButtonStyle(palette);
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
                    style: fillButtonStyle(colors),
                    onPressed: () {},
                    child: const Text('Color')),
                const HorizontalPadding(),
                FilledButton(
                  style: fillButtonStyle(colors),
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
