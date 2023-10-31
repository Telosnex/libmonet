import 'dart:math';

import 'package:monet_studio/brand_colors.dart';
import 'package:monet_studio/hue_tone_picker.dart';
import 'package:monet_studio/padding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:libmonet/hct.dart';
import 'package:libmonet/theming/monet_theme.dart';
import 'package:libmonet/theming/slider_flat.dart';
import 'package:libmonet/theming/slider_flat_thumb.dart';

class ColorPicker extends StatefulHookConsumerWidget {
  const ColorPicker({
    super.key,
    required this.color,
    required this.onColorChanged,
    this.onPhotoLibraryTapped,
  });

  final Color color;
  final void Function(Color) onColorChanged;
  final void Function()? onPhotoLibraryTapped;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ColorPickerState();
}

class _ColorPickerState extends ConsumerState<ColorPicker> {
  static const chromaMax = 120.0;

  late var color = widget.color;
  final random = Random.secure();

  @override
  void initState() {
    color = widget.color;
    super.initState();
  }

  static String _colorToHex(Color color) {
    return color.value
        .toRadixString(16)
        .padLeft(8, '0')
        .toUpperCase()
        .replaceFirst('FF', '');
  }

  void onColorChanged(Color newColor) {
    color = newColor;
    widget.onColorChanged(newColor);
  }

  @override
  Widget build(BuildContext context) {
    final hct = useMemoized(() => Hct.fromColor(color), [color]);
    final mutableChroma = useState(hct.chroma);
    final mutableHue = useState(hct.hue);
    final mutableTone = useState(hct.tone);
    final hexController = useTextEditingController(text: _colorToHex(color));

    final hueController = useTextEditingController(
        text: Hct.fromColor(color).hue.round().toString());
    final chromaController = useTextEditingController(
        text: Hct.fromColor(color).chroma.round().toString());
    final toneController = useTextEditingController(
        text: Hct.fromColor(color).tone.round().toString());
    useEffect(() {
      hexController.text = _colorToHex(color);
      hueController.text = mutableHue.value.round().toString();
      chromaController.text = mutableChroma.value.round().toString();
      toneController.text = mutableTone.value.round().toString();
      return null;
    }, [color, mutableHue.value, mutableChroma.value, mutableTone.value]);

    final hexTextField = TextField(
      onSubmitted: (value) {
        if (value.length == 6) {
          final color = Color(int.parse('FF$value', radix: 16));
          widget.onColorChanged(color);
        } else if (value.length == 8) {
          final color = Color(int.parse(value, radix: 16));
          widget.onColorChanged(color);
        } else if (value.length == 3) {
          final color = Color(int.parse(
              'FF${value[0]}${value[0]}${value[1]}'
              '${value[1]}${value[2]}${value[2]}',
              radix: 16));
          onColorChanged(color);
        }
      },
      controller: hexController,
      decoration: const InputDecoration(
        labelText: 'RGB | HEX',
        border: OutlineInputBorder(),
        isCollapsed: false,
        isDense: true,
      ),
      style: Theme.of(context)
          .textTheme
          .headlineLarge!
          .copyWith(color: MonetTheme.of(context).primary.text),
    );
    final letterTextStyle = Theme.of(context).textTheme.headlineLarge!.copyWith(
        fontWeight: FontWeight.w500, // medium
        color: MonetTheme.of(context).primary.colorIcon);
    return ExpansionTile(
      title: Row(
        children: [
          Padding(
            padding: HorizontalPadding.rightInset,
            child: Text(
              'Color',
              style: Theme.of(context).textTheme.headlineLarge!.copyWith(
                    color: MonetTheme.of(context).primary.text,
                  ),
            ),
          ),
          Flexible(child: hexTextField),
          IconButton(
            onPressed: () {
              final randomColor = Color.fromARGB(255, random.nextInt(256),
                  random.nextInt(256), random.nextInt(256));
              widget.onColorChanged(randomColor);
              color = randomColor;
            },
            icon: const Icon(Icons.shuffle),
          ),
          if (widget.onPhotoLibraryTapped != null)
            IconButton(
              onPressed: widget.onPhotoLibraryTapped,
              icon: const Icon(Icons.photo_library),
            ),
          BrandColorsPopupMenuButton(onChanged: (newColor) {
            color = newColor;
            widget.onColorChanged(newColor);
          }),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SizedBox(
            height: 360,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: HueTonePicker(
                      hueIntent: mutableHue.value,
                      chromaIntent: mutableChroma.value,
                      toneIntent: mutableTone.value,
                      color: color,
                      onChanged: (double hue, double tone) {
                        final hct = Hct.fromColor(color);
                        hct.hue = hue;
                        hct.tone = tone;
                        hct.chroma = mutableChroma.value;
                        mutableHue.value = hue;
                        mutableTone.value = tone;
                        onColorChanged(hct.color);
                      },
                    ),
                  ),
                ),
                const VerticalPadding(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      flex: 1,
                      child: TextField(
                        onSubmitted: (value) {
                          final hue = double.tryParse(value);
                          if (hue == null) {
                            return;
                          }
                          final color =
                              Hct.from(hue, hct.chroma, hct.tone).color;
                          widget.onColorChanged(color);
                        },
                        controller: hueController,
                        decoration: const InputDecoration(
                          labelText: 'HUE',
                          border: OutlineInputBorder(),
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge!
                            .copyWith(
                                color: MonetTheme.of(context).primary.text),
                      ),
                    ),
                    const HorizontalPadding(),
                    Flexible(
                      flex: 3,
                      child: SliderFlat(
                        slider: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbShape: SliderFlatThumb(
                              borderWidth: 2,
                              borderColor:
                                  MonetTheme.of(context).primary.colorBorder,
                              letterTextStyle: letterTextStyle,
                              letter: 'H',
                            ),
                          ),
                          child: Slider(
                            value: mutableHue.value,
                            label: 'Hue ${mutableHue.value.round()}',
                            min: 0,
                            max: 360,
                            onChanged: (double value) {
                              mutableHue.value = value;
                              final hct = Hct.fromColor(color);
                              hct.hue = value;
                              widget.onColorChanged(hct.color);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const VerticalPadding(),
                Row(
                  children: [
                    Flexible(
                      flex: 1,
                      child: TextField(
                        onSubmitted: (value) {
                          final chroma = double.tryParse(value);
                          if (chroma == null) {
                            return;
                          }
                          final color =
                              Hct.from(hct.hue, chroma, hct.tone).color;
                          widget.onColorChanged(color);
                        },
                        controller: chromaController,
                        decoration: const InputDecoration(
                          labelText: 'CHROMA',
                          border: OutlineInputBorder(),
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge!
                            .copyWith(
                                color: MonetTheme.of(context).primary.text),
                      ),
                    ),
                    const HorizontalPadding(),
                    Flexible(
                      flex: 3,
                      child: SliderFlat(
                        borderColor: MonetTheme.of(context).primary.colorBorder,
                        borderWidth: 2,
                        slider: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbShape: SliderFlatThumb(
                              borderWidth: 2,
                              borderColor:
                                  MonetTheme.of(context).primary.colorBorder,
                              letterTextStyle: letterTextStyle,
                              letter: 'C',
                            ),
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
                              widget.onColorChanged(hct.color);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const VerticalPadding(),
                Row(
                  children: [
                    Flexible(
                      flex: 1,
                      child: TextField(
                        onSubmitted: (value) {
                          final tone = double.tryParse(value);
                          if (tone == null) {
                            return;
                          }
                          final color =
                              Hct.from(hct.hue, hct.chroma, tone).color;
                          widget.onColorChanged(color);
                        },
                        controller: toneController,
                        decoration: const InputDecoration(
                          labelText: 'TONE | L*',
                          border: OutlineInputBorder(),
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge!
                            .copyWith(
                                color: MonetTheme.of(context).primary.text),
                      ),
                    ),
                    const HorizontalPadding(),
                    Flexible(
                      flex: 3,
                      child: SliderFlat(
                        borderColor: MonetTheme.of(context).primary.colorBorder,
                        borderWidth: 2,
                        slider: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbShape: SliderFlatThumb(
                              borderWidth: 2,
                              borderColor:
                                  MonetTheme.of(context).primary.colorBorder,
                              letterTextStyle: letterTextStyle,
                              letter: 'T',
                            ),
                          ),
                          child: Slider(
                            value: mutableTone.value,
                            label: 'Tone ${mutableTone.value.round()}',
                            min: 0,
                            max: 100,
                            onChanged: (double value) {
                              mutableTone.value = value;
                              final hct = Hct.fromColor(color);
                              hct.tone = value;
                              widget.onColorChanged(hct.color);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
