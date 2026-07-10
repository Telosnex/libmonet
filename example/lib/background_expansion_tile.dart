import 'package:libmonet/theming/slider_flat_thumb.dart';
import 'package:monet_studio/padding.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:libmonet/theming/monet_theme.dart';
import 'package:libmonet/theming/slider_flat.dart';

class BackgroundExpansionTile extends ConsumerWidget {
  final ValueNotifier<double> darkModeLstarNotifier;
  final ValueNotifier<double> lightModeLstarNotifier;
  const BackgroundExpansionTile({
    super.key,
    required this.darkModeLstarNotifier,
    required this.lightModeLstarNotifier,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkModeLstar = darkModeLstarNotifier.value;
    final lightModeLstar = lightModeLstarNotifier.value;
    return ExpansionTile(
      childrenPadding: const EdgeInsets.symmetric(horizontal: 8),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      title: Text(
        'Background',
        style: Theme.of(context).textTheme.headlineLarge!.copyWith(
              color: MonetTheme.of(context).primary.text,
            ),
      ),
      children: [
        const Text('Dark'),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            thumbShape: SliderFlatThumb(
              borderWidth: 2,
              borderColor: MonetTheme.of(context).primary.colorBorder,
              iconColor: MonetTheme.of(context).primary.colorIcon,
              iconData: Icons.brightness_2,
            ),
          ),
          child: SliderFlat(
            slider: Slider(
              value: darkModeLstar,
              label: 'Tone ${darkModeLstar.round()}',
              min: 0,
              max: 100,
              onChanged: (double value) {
                darkModeLstarNotifier.value = value;
              },
            ),
          ),
        ),
        const Text('Light'),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            thumbShape: SliderFlatThumb(
              borderWidth: 2,
              borderColor: MonetTheme.of(context).primary.colorBorder,
              iconColor: MonetTheme.of(context).primary.colorIcon,
              iconData: Icons.brightness_7,
            ),
          ),
          child: SliderFlat(
            slider: Slider(
              value: lightModeLstar,
              label: 'Tone ${lightModeLstar.round()}',
              min: 0,
              max: 100,
              onChanged: (double value) {
                lightModeLstarNotifier.value = value;
              },
            ),
          ),
        ),
        const VerticalPadding()
      ],
    );
  }
}
