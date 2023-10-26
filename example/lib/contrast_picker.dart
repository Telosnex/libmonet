import 'package:example/padding.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:libmonet/contrast.dart';
import 'package:libmonet/theming/monet_theme.dart';
import 'package:libmonet/theming/slider_flat.dart';
import 'package:libmonet/theming/slider_flat_thumb.dart';

class ContrastPicker extends HookConsumerWidget {
  final double contrast;
  final Function(double newContrast) onContrastChanged;
  const ContrastPicker(
      {required this.contrast, required this.onContrastChanged, super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final algo = useState(Algo.apca);
    return Row(
      children: [
        ToggleButtons(
          isSelected: [algo.value == Algo.apca, algo.value == Algo.wcag21],
          onPressed: (index) {
            algo.value = index == 0 ? Algo.apca : Algo.wcag21;
          },
          children: const [Text('APCA'), Text('WCAG 2.1')]
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
                label: 'Contrast: ${(contrast * 100.0).round()}%',
                value: contrast.clamp(0.1, 1.0),
                min: 0.1,
                max: 1.0,
                onChanged: (value) {
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
