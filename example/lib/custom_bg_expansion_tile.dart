import 'package:monet_ui/monet_ui.dart';
import 'package:monet_studio/hue_tone_picker.dart';
import 'package:monet_studio/padding.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:squadron/squadron.dart';

class CustomBgExpansionTile extends HookConsumerWidget {
  final double contrast;

  const CustomBgExpansionTile({super.key, required this.contrast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monetTheme = MonetTheme.of(context);
    final primaryColors = monetTheme.primary;

    final bgHue = useState(210.0);
    final bgChroma = useState(30.0);
    final bgTone = useState(50.0);

    final bgHct = Hct.from(bgHue.value, bgChroma.value, bgTone.value);
    final bgColor = bgHct.color;
    final bgArgb = bgColor.argb;
    final fgArgb = primaryColors.backgroundText.argb;

    final hexController = useTextEditingController(text: bgArgb.hex);
    final hueController =
        useTextEditingController(text: bgHue.value.round().toString());
    final chromaController =
        useTextEditingController(text: bgChroma.value.round().toString());
    final toneController =
        useTextEditingController(text: bgTone.value.round().toString());

    useEffect(() {
      final hct = Hct.from(bgHue.value, bgChroma.value, bgTone.value);
      hexController.text = hct.toInt().hex;
      hueController.text = bgHue.value.round().toString();
      chromaController.text = bgChroma.value.round().toString();
      toneController.text = bgTone.value.round().toString();
      return null;
    }, [bgHue.value, bgChroma.value, bgTone.value]);

    final scrim = AnyBackground(
      [bgArgb],
      algo: monetTheme.algo,
      contrast: contrast,
    ).scrimFor(fgArgb);
    final shadows = scrim.shadows(blurRadius: 5, contentRadius: 3);

    final shadowString = StringBuffer();
    if (shadows.layerOpacities.isEmpty) {
      shadowString.write('none');
    } else {
      final full = shadows.layerOpacities.where((o) => o == 1.0);
      if (full.isNotEmpty && full.length < shadows.layerOpacities.length) {
        shadowString.write('${full.length} @ 100%, 1 @ ');
      }
      shadowString.write(
          '${(shadows.layerOpacities.last * 100).round()}% of ${hexFromArgb(shadows.scrim.scrimArgb)}');
    }

    final scrimString = StringBuffer();
    final scrimPct = (scrim.opacity * 100).ceil().clamp(0, 100);
    if (scrimPct == 0) {
      scrimString.write('none');
    } else {
      scrimString.write('$scrimPct% of ${hexFromArgb(scrim.scrimArgb)}');
    }

    final inputsText = 'Inputs\n'
        '  Text color: ${hexFromArgb(fgArgb)}\n'
        '  Background: ${hexFromArgb(bgArgb)}\n'
        '  Target contrast: $contrast\n'
        '  Algorithm: ${monetTheme.algo.name}\n'
        '\n'
        'Results\n'
        '  scrimFor: $scrimString\n'
        '  Meets target: ${scrim.meetsTarget ? 'yes' : 'NO — best effort'}\n'
        '  Worst contrast: ${scrim.worstContrast.toStringAsFixed(2)}\n'
        '  Shadows: $shadowString\n'
        '  Shadow layers: ${shadows.layerOpacities.length}';

    final letterTextStyle = Theme.of(context)
        .textTheme
        .headlineLarge!
        .copyWith(fontWeight: FontWeight.w500, color: primaryColors.colorIcon);

    return ExpansionTile(
      title: Text(
        'Custom Background',
        style: Theme.of(context)
            .textTheme
            .headlineLarge!
            .copyWith(color: primaryColors.text),
      ),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // HueTone picker grid
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SizedBox(
            height: 360,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hex field + color swatch
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: bgColor,
                        border: Border.all(color: primaryColors.colorBorder),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const HorizontalPadding(),
                    Expanded(
                      child: TextField(
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
                          if (argb == null) return;
                          final hct = Hct.fromInt(argb);
                          bgHue.value = hct.hue;
                          bgChroma.value = hct.chroma;
                          bgTone.value = hct.tone;
                        },
                        controller: hexController,
                        decoration: const InputDecoration(
                          labelText: 'BG HEX',
                          border: OutlineInputBorder(),
                          isCollapsed: false,
                          isDense: true,
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge!
                            .copyWith(color: primaryColors.text),
                      ),
                    ),
                  ],
                ),
                const VerticalPadding(),
                // Hue-Tone grid
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: HueTonePicker(
                      hueIntent: bgHue.value,
                      chromaIntent: bgChroma.value,
                      toneIntent: bgTone.value,
                      onChanged: (double hue, double tone) {
                        bgHue.value = hue;
                        bgTone.value = tone;
                      },
                    ),
                  ),
                ),
                const VerticalPadding(),
                // H slider
                Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: TextField(
                        onSubmitted: (value) {
                          final hue = double.tryParse(value);
                          if (hue == null) return;
                          bgHue.value = hue;
                        },
                        controller: hueController,
                        decoration: const InputDecoration(
                          labelText: 'H',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium!
                            .copyWith(color: primaryColors.text),
                      ),
                    ),
                    const HorizontalPadding(),
                    Expanded(
                      child: SliderFlat(
                        slider: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbShape: SliderFlatThumb(
                              borderWidth: 2,
                              borderColor: primaryColors.colorBorder,
                              letterTextStyle: letterTextStyle,
                              letter: 'H',
                            ),
                          ),
                          child: Slider(
                            value: bgHue.value,
                            min: 0,
                            max: 360,
                            onChanged: (v) => bgHue.value = v,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // C slider
                Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: TextField(
                        onSubmitted: (value) {
                          final chroma = double.tryParse(value);
                          if (chroma == null) return;
                          bgChroma.value = chroma;
                        },
                        controller: chromaController,
                        decoration: const InputDecoration(
                          labelText: 'C',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium!
                            .copyWith(color: primaryColors.text),
                      ),
                    ),
                    const HorizontalPadding(),
                    Expanded(
                      child: SliderFlat(
                        borderColor: primaryColors.colorBorder,
                        borderWidth: 2,
                        slider: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbShape: SliderFlatThumb(
                              borderWidth: 2,
                              borderColor: primaryColors.colorBorder,
                              letterTextStyle: letterTextStyle,
                              letter: 'C',
                            ),
                          ),
                          child: Slider(
                            value: bgChroma.value,
                            min: 0,
                            max: 120,
                            onChanged: (v) => bgChroma.value = v,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // T slider
                Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: TextField(
                        onSubmitted: (value) {
                          final tone = double.tryParse(value);
                          if (tone == null) return;
                          bgTone.value = tone;
                        },
                        controller: toneController,
                        decoration: const InputDecoration(
                          labelText: 'T',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium!
                            .copyWith(color: primaryColors.text),
                      ),
                    ),
                    const HorizontalPadding(),
                    Expanded(
                      child: SliderFlat(
                        borderColor: primaryColors.colorBorder,
                        borderWidth: 2,
                        slider: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbShape: SliderFlatThumb(
                              borderWidth: 2,
                              borderColor: primaryColors.colorBorder,
                              letterTextStyle: letterTextStyle,
                              letter: 'T',
                            ),
                          ),
                          child: Slider(
                            value: bgTone.value,
                            min: 0,
                            max: 100,
                            onChanged: (v) => bgTone.value = v,
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
        const VerticalPadding(),
        // Inputs / Results
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: SelectableText(
            inputsText,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  fontFamily: 'monospace',
                  color: primaryColors.text,
                ),
          ),
        ),
        const VerticalPadding(),
        // Previews
        _label(context, 'scrim (rect)', primaryColors),
        Stack(
          children: [
            Positioned.fill(child: Container(color: bgColor)),
            Positioned.fill(
                child: Container(
                    color: Color(scrim.scrimArgb)
                        .withValues(alpha: scrim.opacity))),
            _sampleText(context, primaryColors),
          ],
        ),
        const VerticalPadding(),
        _label(context, 'No scrim', primaryColors),
        Stack(
          children: [
            Positioned.fill(child: Container(color: bgColor)),
            _sampleText(context, primaryColors),
          ],
        ),
        const VerticalPadding(),
        _label(context, 'scrim.shadows', primaryColors),
        Stack(
          children: [
            Positioned.fill(child: Container(color: bgColor)),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "This is Major Tom to Ground Control. I'm stepping through "
                "the door And I'm floating in a most peculiar way And the "
                "stars look very different today",
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: primaryColors.backgroundText,
                    shadows: shadows.textShadows),
              ),
            ),
          ],
        ),
        const VerticalPadding(),
      ],
    );
  }

  Widget _label(BuildContext context, String text, dynamic primaryColors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall!.copyWith(
              color: primaryColors.text,
            ),
      ),
    );
  }

  Widget _sampleText(BuildContext context, dynamic primaryColors) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        "This is Major Tom to Ground Control. I'm stepping through "
        "the door And I'm floating in a most peculiar way And the "
        "stars look very different today",
        style: Theme.of(context)
            .textTheme
            .bodyMedium!
            .copyWith(color: primaryColors.backgroundText),
      ),
    );
  }
}
