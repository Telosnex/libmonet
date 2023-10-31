import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:libmonet/theming/monet_theme.dart';
import 'package:libmonet/theming/slider_flat.dart';
import 'package:libmonet/theming/slider_flat_thumb.dart';

class ContrastSlider extends HookConsumerWidget {
  final double contrast;
  final Function(double newContrast) onContrastChanged;

  const ContrastSlider(
      {super.key, required this.contrast, required this.onContrastChanged});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliderFlat(
      borderColor: MonetTheme.of(context).primary.colorBorder,
      borderWidth: 2,
      slider: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          thumbShape: SliderFlatThumb(
              borderWidth: 2,
              borderColor: MonetTheme.of(context).primary.colorBorder,
              iconColor: MonetTheme.of(context).primary.colorIcon,
              iconData: Icons.brightness_6),
        ),
        child: Slider(
          label: '${(contrast * 100.0).round()}%',
          value: contrast.clamp(0.1, 1.0),
          min: 0.1,
          max: 1.0,
          onChanged: (value) {
            int rounded = (value * 100).round();
            int base = (rounded ~/ 25) * 25;
            if (rounded < base + 3) {
              value = base / 100.0;
            } else if (rounded > base + 22) {
              value = (base + 25) / 100.0;
            } else {
              value = rounded / 100.0;
            }
            onContrastChanged(value);
          },
        ),
      ),
    );
  }
}
