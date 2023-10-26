import 'dart:math';

import 'package:example/hue_tone_picker.dart';
import 'package:example/padding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:libmonet/hct.dart';
import 'package:libmonet/theming/button_style.dart';
import 'package:libmonet/theming/monet_theme.dart';
import 'package:libmonet/theming/slider_flat.dart';
import 'package:libmonet/theming/slider_flat_thumb.dart';

class ColorPicker extends HookConsumerWidget {
  ColorPicker({
    super.key,
    required this.color,
    required this.onColorChanged,
  });

  final random = Random.secure();
  final Color color;
  final void Function(Color) onColorChanged;

  static const chromaMax = 120.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mutableChroma = useState(Hct.fromColor(color).chroma);
    return ExpansionTile(
      title: Row(
        children: [
          Text(
            'Color',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          IconButton(
            style: iconButtonStyleFromColors(
                MonetTheme.of(context).primarySafeColors),
            onPressed: () {
              final randomColor = Color.fromARGB(255, random.nextInt(256),
                  random.nextInt(256), random.nextInt(256));
              onColorChanged(randomColor);
            },
            icon: const Icon(Icons.shuffle),
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SizedBox(
            height: 240,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: HueTonePicker(
                      chromaIntent: mutableChroma.value,
                      color: color,
                      onChanged: (double hue, double tone) {
                        final hct = Hct.fromColor(color);
                        hct.hue = hue;
                        hct.tone = tone;
                        hct.chroma = mutableChroma.value;
                        onColorChanged(hct.color);
                      },
                    ),
                  ),
                ),
                const VerticalPadding(),
                SliderFlat(
                  borderColor:
                      MonetTheme.of(context).primarySafeColors.colorBorder,
                  borderWidth: 2,
                  slider: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: SliderFlatThumb(
                          borderWidth: 2,
                          borderColor: MonetTheme.of(context)
                              .primarySafeColors
                              .colorBorder,
                          iconColor: MonetTheme.of(context)
                              .primarySafeColors
                              .colorIcon,
                          iconData: Icons.color_lens_outlined),
                    ),
                    child: Slider(
                      value: mutableChroma.value,
                      label:
                          'Chroma ${(mutableChroma.value / chromaMax * 100.0).round()}%',
                      min: 0,
                      max: chromaMax,
                      onChanged: (double value) {
                        mutableChroma.value = value;
                        final hct = Hct.fromColor(color);
                        hct.chroma = value;
                        onColorChanged(hct.color);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
