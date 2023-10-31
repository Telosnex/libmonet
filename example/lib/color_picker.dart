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

  final random = Random.secure();


  static String _colorToHex(Color color) {
    return color.value
        .toRadixString(16)
        .padLeft(8, '0')
        .toUpperCase()
        .replaceFirst('FF', '');
  }

  @override
  Widget build(BuildContext context) {
    final hctDANGERDANGER = useMemoized(() => Hct.fromColor(widget.color), []);
    final mutableChroma = useState(hctDANGERDANGER.chroma);
    final mutableHue = useState(hctDANGERDANGER.hue);
    final mutableTone = useState(hctDANGERDANGER.tone);
    final hexController =
        useTextEditingController(text: _colorToHex(widget.color));
    final hueController = useTextEditingController(
        text: mutableHue.value.round().toString());
    final chromaController = useTextEditingController(
        text: mutableChroma.value.round().toString());
    final toneController = useTextEditingController(
        text: mutableTone.value.round().toString());
    useEffect(() {
      hexController.text = _colorToHex(widget.color);
      hueController.text = mutableHue.value.round().toString();
      chromaController.text = mutableChroma.value.round().toString();
      toneController.text = mutableTone.value.round().toString();
      hexController.text = _colorToHex(
          Hct.from(mutableHue.value, mutableChroma.value, mutableTone.value)
              .color);
      return null;
    }, [mutableHue.value, mutableChroma.value, mutableTone.value]);

    final hexTextField = TextField(
      onSubmitted: (value) {
        int? argb;
        if (value.length == 6) {
          argb = int.tryParse('FF$value', radix: 16);
        } else if (value.length == 8) {
          argb = int.tryParse(value, radix: 16);
        } else if (value.length == 3) {
          argb = int.tryParse(
              'FF${value[0]}${value[0]}${value[1]}${value[1]}${value[2]}${value[2]}',
              radix: 16);
        }
        if (argb == null) {
          return;
        }
        final hct = Hct.fromInt(argb);
        mutableHue.value = hct.hue;
        mutableChroma.value = hct.chroma;
        mutableTone.value = hct.tone;
        widget.onColorChanged(hct.color);
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
              final hct = Hct.fromColor(randomColor);
              mutableHue.value = hct.hue;
              mutableChroma.value = hct.chroma;
              mutableTone.value = hct.tone;
              widget.onColorChanged(randomColor);
            },
            icon: const Icon(Icons.shuffle),
          ),
          BrandColorsPopupMenuButton(onChanged: (newColor) {
            final hct = Hct.fromColor(newColor);
            mutableHue.value = hct.hue;
            mutableChroma.value = hct.chroma;
            mutableTone.value = hct.tone;
            widget.onColorChanged(newColor);
          }),
          if (widget.onPhotoLibraryTapped != null)
            IconButton(
              onPressed: widget.onPhotoLibraryTapped,
              icon: const Icon(Icons.photo_library),
            ),
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
                      onChanged: (double hue, double tone) {
                        mutableHue.value = hue;
                        mutableTone.value = tone;
                        final hct = Hct.from(hue, mutableChroma.value, tone);
                        widget.onColorChanged(hct.color);
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
                          final color = Hct.from(
                                  hue, mutableChroma.value, mutableTone.value)
                              .color;
                          mutableHue.value = hue;
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

                              final hct = Hct.from(value, mutableChroma.value,
                                  mutableTone.value);
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
                          mutableChroma.value = chroma;
                          final color = Hct.from(
                                  mutableHue.value, chroma, mutableTone.value)
                              .color;
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
                              final hct = Hct.from(
                                  mutableHue.value, value, mutableTone.value);
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
                          mutableTone.value = tone;
                          final color = Hct.from(
                                  mutableHue.value, mutableChroma.value, tone)
                              .color;
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
                              final hct = Hct.from(
                                  mutableHue.value, mutableChroma.value, value);
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
