import 'package:libmonet/contrast/contrast.dart';
import 'package:monet_studio/contrast_picker.dart';
import 'package:monet_studio/contrast_slider.dart';
import 'package:monet_studio/padding.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:libmonet/theming/monet_theme.dart';

class ContrastExpansionTile extends ConsumerWidget {
  final ValueNotifier<double> contrast;
  final ValueNotifier<Algo> algo;

  const ContrastExpansionTile({
    super.key,
    required this.contrast,
    required this.algo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExpansionTile(
      title: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Contrast',
            style: Theme.of(context).textTheme.headlineLarge!.copyWith(
                  color: MonetTheme.of(context).primary.text,
                ),
          ),
          Padding(
            padding: VerticalPadding.inset,
            child: ContrastSlider(
              contrast: contrast.value,
              onContrastChanged: ((newContrast) {
                contrast.value = newContrast;
              }),
            ),
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ContrastPicker(
            algo: algo.value,
            onAlgoChanged: (newAlgo) {
              algo.value = newAlgo;
            },
            contrast: contrast.value,
            onContrastChanged: (newContrast) {
              contrast.value = newContrast;
            },
          ),
        )
      ],
    );
  }
}
