import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:libmonet/theming/monet_theme.dart';
import 'package:libmonet/theming/slider_flat.dart';
import 'package:libmonet/theming/slider_flat_thumb.dart';
import 'package:monet_studio/padding.dart';

class ScalingExpansionTile extends HookConsumerWidget {
  final ValueNotifier<double> scaleValueNotifier;
  const ScalingExpansionTile({super.key, required this.scaleValueNotifier});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExpansionTile(
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      title: Text(
        'Scaling',
        style: Theme.of(context).textTheme.headlineLarge!.copyWith(
              color: MonetTheme.of(context).primary.text,
            ),
      ),
      children: [
        Container(
          width: 160 * scaleValueNotifier.value * scaleValueNotifier.value,
          height: 4,
          color: MonetTheme.of(context).primary.fill,
        ),
        const Text('1 inch'),
        Container(
          width: 63 * scaleValueNotifier.value * scaleValueNotifier.value,
          height: 4,
          color: MonetTheme.of(context).primary.fill,
        ),
        const Text('1 cm'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: SliderFlat(
            slider: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: SliderFlatThumb(
                    borderWidth: 2,
                    borderColor: MonetTheme.of(context).primary.colorBorder,
                    iconColor: MonetTheme.of(context).primary.colorText,
                    iconData: Icons.format_size),
              ),
              child: Slider(
                value: math
                    .pow(scaleValueNotifier.value, 2)
                    .toDouble()
                    .clamp(0.5, 2.0),
                label:
                    '${(math.pow(scaleValueNotifier.value, 2).toDouble() * 100).round()}%',
                min: 0.5,
                max: 2.0,
                onChanged: (double value) {
                  scaleValueNotifier.value = math.sqrt(value);
                },
              ),
            ),
          ),
        ),
        const VerticalPadding(),
      ],
    );
  }
}
