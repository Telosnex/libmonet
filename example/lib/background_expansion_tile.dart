import 'package:monet_studio/home.dart';
import 'package:monet_studio/padding.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:libmonet/theming/monet_theme.dart';
import 'package:libmonet/theming/slider_flat.dart';

class BackgroundExpansionTile extends ConsumerWidget {
  final ValueNotifier<double> darkModeLstarNotifier;
  final ValueNotifier<double> lightModeLstarNotifier;
  final ValueNotifier<BrightnessSetting> brightnessSettingNotifier;

  const BackgroundExpansionTile({
    super.key,
    required this.darkModeLstarNotifier,
    required this.lightModeLstarNotifier,
    required this.brightnessSettingNotifier,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkModeLstar = darkModeLstarNotifier.value;
    final lightModeLstar = lightModeLstarNotifier.value;
    return ExpansionTile(
      childrenPadding: const EdgeInsets.symmetric(horizontal: 8),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      title: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Background',
            style: Theme.of(context).textTheme.headlineLarge!.copyWith(
                  color: MonetTheme.of(context).primary.text,
                ),
          ),
          const HorizontalPadding(),
          FittedBox(child: _brightnessToggleButtons())
        ],
      ),
      children: [
        const Text('Dark'),
        SliderFlat(
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
        const Text('Light'),
        SliderFlat(
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
        const VerticalPadding()
      ],
    );
  }

  Widget _brightnessToggleButtons() {
    final brightnessSetting = brightnessSettingNotifier;
    return ToggleButtons(
      isSelected: [
        brightnessSetting.value == BrightnessSetting.dark,
        brightnessSetting.value == BrightnessSetting.light,
        brightnessSetting.value == BrightnessSetting.auto,
      ],
      onPressed: (index) {
        if (index == 0) {
          brightnessSetting.value = BrightnessSetting.dark;
        } else if (index == 1) {
          brightnessSetting.value = BrightnessSetting.light;
        } else if (index == 2) {
          brightnessSetting.value = BrightnessSetting.auto;
        }
      },
      children: const [Text('Dark'), Text('Light'), Text('Auto')]
          .map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: e,
            ),
          )
          .toList(),
    );
  }
}
