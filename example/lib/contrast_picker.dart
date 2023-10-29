import 'package:example/padding.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:libmonet/contrast.dart';
import 'package:libmonet/theming/monet_theme.dart';
import 'package:libmonet/theming/slider_flat.dart';
import 'package:libmonet/theming/slider_flat_thumb.dart';

class ContrastPicker extends HookConsumerWidget {
  final double contrast;
  final Algo algo;
  final Function(double newContrast) onContrastChanged;
  final Function(Algo newAlgo) onAlgoChanged;
  const ContrastPicker(
      {
    required this.algo,
    required this.contrast,
    required this.onAlgoChanged,
    required this.onContrastChanged,
    super.key,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        ToggleButtons(
          isSelected: [algo == Algo.apca, algo == Algo.wcag21],
          onPressed: (index) {
            onAlgoChanged(index == 0 ? Algo.apca : Algo.wcag21);
          },
          children: const [Text('APCA'), Text('WCAG')]
              .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: e))
              .toList(),
        ),
        const HorizontalPadding(),
        Flexible(
          child: SliderFlat(
            borderColor: MonetTheme.of(context).primarySafeColors.colorBorder,
            borderWidth: 2,
            slider: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: SliderFlatThumb(
                    borderWidth: 2,
                    borderColor:
                        MonetTheme.of(context).primarySafeColors.colorBorder,
                    iconColor:
                        MonetTheme.of(context).primarySafeColors.colorIcon,
                    iconData: Icons.brightness_6),
              ),
              child: Slider(
                label: '${(contrast * 100.0).round()}%',
                value: contrast.clamp(0.1, 1.0),
                min: 0.1,
                max: 1.0,
                onChanged: (value) {
                  if ((value * 100).round() == 50) {
                    value = 0.5;
                  }
                  onContrastChanged(value);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
