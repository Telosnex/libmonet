import 'dart:math';

import 'package:example/hue_tone_picker.dart';
import 'package:example/safe_colors_preview.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:libmonet/hct.dart';
import 'package:libmonet/theming/monet_theme.dart';

class ColorPicker extends HookConsumerWidget {
  ColorPicker({
    super.key,
    required this.color,
    required this.onColorChanged,
  });

  final random = Random.secure();
  final Color color;
  final void Function(Color) onColorChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        SizedBox(
          height: 240,
          child: HueTonePicker(
              color: color,
              onChanged: (double hue, double tone) {
                final hct = Hct.fromColor(color);
                hct.hue = hue;
                hct.tone = tone;
                onColorChanged(hct.color);
              }),
        ),
        ElevatedButton.icon(
          onPressed: () {
            final randomColor = Color.fromARGB(255, random.nextInt(256),
                random.nextInt(256), random.nextInt(256));
            onColorChanged(randomColor);
          },
          icon: const Icon(Icons.shuffle),
          label: const Text('Random Color'),
        ),
        SafeColorsPreviewRow(
          safeColors: MonetTheme.of(context).primarySafeColors,
        ),
        SafeColorsPreviewRow(
          safeColors: MonetTheme.of(context).secondarySafeColors,
        ),
        SafeColorsPreviewRow(
          safeColors: MonetTheme.of(context).tertiarySafeColors,
        ),
      ],
    );
  }
}
