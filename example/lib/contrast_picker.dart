import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:libmonet/contrast/contrast.dart';

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
    return ToggleButtons(
      isSelected: [algo == Algo.apca, algo == Algo.wcag21],
      onPressed: (index) {
        onAlgoChanged(index == 0 ? Algo.apca : Algo.wcag21);
      },
      children: const [Text('APCA'), Text('WCAG')]
          .map((e) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0), child: e))
          .toList(),
    );
  }
}
