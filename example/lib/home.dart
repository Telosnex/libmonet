import 'dart:io';

import 'package:monet_studio/background_expansion_tile.dart';
import 'package:monet_studio/chessboard_painter.dart';
import 'package:monet_studio/color_picker.dart';
import 'package:monet_studio/components_widget.dart';
import 'package:monet_studio/contrast_picker.dart';
import 'package:monet_studio/contrast_slider.dart';
import 'package:monet_studio/extracted_widget.dart';
import 'package:monet_studio/padding.dart';
import 'package:monet_studio/safe_colors_preview.dart';
import 'package:monet_studio/scrim_expansion_tile.dart';
import 'package:monet_studio/tokens_expansion_tile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:libmonet/argb_srgb_xyz_lab.dart';
import 'package:libmonet/contrast.dart';
import 'package:libmonet/hex_codes.dart';
import 'package:libmonet/opacity.dart';
import 'package:libmonet/shadows.dart';
import 'package:libmonet/theming/monet_theme.dart';

enum BrightnessSetting {
  light,
  dark,
  auto;

  Brightness brightness(BuildContext context) {
    switch (this) {
      case BrightnessSetting.light:
        return Brightness.light;
      case BrightnessSetting.dark:
        return Brightness.dark;
      case BrightnessSetting.auto:
        return MediaQuery.platformBrightnessOf(context);
    }
  }
}

class Home extends HookConsumerWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = useState(const Color(0xff335147));
    final images = useState(<ImageProvider>[]);
    final contrast = useState(0.5);
    final algo = useState(Algo.apca);
    final brightnessSetting = useState(BrightnessSetting.auto);
    final brightness = brightnessSetting.value.brightness(context);
    final darkSurfaceLstar = useState(10.0);
    final lightSurfaceLstar = useState(93.0);


    return MonetTheme.fromColor(
      brightness: brightness,
      algo: algo.value,
      contrast: contrast.value,
      color: color.value,
      surfaceLstar: brightness == Brightness.light
          ? lightSurfaceLstar.value
          : darkSurfaceLstar.value,
      child: Builder(builder: (context) {

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            title: const Text('Monet Studio'),
          ),
          body: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: MonetTheme.maxPanelWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      BackgroundExpansionTile(
                        darkModeLstarNotifier: darkSurfaceLstar,
                        lightModeLstarNotifier: lightSurfaceLstar,
                        brightnessSettingNotifier: brightnessSetting,
                      ),
                      const VerticalPadding(),
                      ColorPicker(
                        color: color.value,
                        onColorChanged: (newColor) {
                          color.value = newColor;
                        },
                      ),
                      const VerticalPadding(),
                      ExpansionTile(
                        title: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Contrast',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge!
                                  .copyWith(
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
                      ),

                      Wrap(
                        alignment: WrapAlignment.center,
                        // mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            children: [
                              SafeColorsPreviewRow(
                                safeColors: MonetTheme.of(context).primary,
                              ),
                              SafeColorsPreviewRow(
                                safeColors: MonetTheme.of(context).secondary,
                              ),
                              SafeColorsPreviewRow(
                                safeColors: MonetTheme.of(context).tertiary,
                              ),
                            ],
                          ),
                          const HorizontalPadding(),
                          buildScrimShadows(context, contrast.value),
                        ],
                      ),

                      const TokensExpansionTile(),
                      const VerticalPadding(),
                      ScrimExpansionTile(
                        contrast: contrast.value,
                      ),
                      const VerticalPadding(),

                      ExpansionTile(
                        title: Text(
                          'Material Components',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge!
                              .copyWith(
                                  color: MonetTheme.of(context).primary.text),
                        ),
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: ComponentsWidget(),
                          ),
                        ],
                      ),
                      const VerticalPadding(),
                      // ElevatedButton.icon(
                      //   onPressed: () => _uploadImagePressed(images),
                      //   icon: const Icon(Icons.photo),
                      //   label: const Text('Upload Image'),
                      // ),
                      for (final image in images.value)
                        ExtractedWidget(image: image),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget buildScrimShadows(BuildContext context, double contrast) {
    final monetTheme = MonetTheme.of(context);
    final primaryColors = monetTheme.primary;
    final scrimOpacity = getOpacity(
      minBgLstar: 0,
      maxBgLstar: 100,
      algo: monetTheme.algo,
      foregroundLstar: lstarFromArgb(primaryColors.backgroundText.value),
      contrast: contrast,
    );
    final shadows = getShadowOpacities(
      minBgLstar: 0,
      maxBgLstar: 100,
      algo: monetTheme.algo,
      foregroundLstar: lstarFromArgb(primaryColors.backgroundText.value),
      contrast: contrast,
      blurRadius: 5,
      contentRadius: 3,
    );
    final shadowString = StringBuffer();
    shadowString.write('Shadows: ');
    if (shadows.opacities.isEmpty) {
      shadowString.write('none');
    } else {
      final oneHundredPercent = shadows.opacities.where((o) => o == 1.0);
      if (oneHundredPercent.isNotEmpty) {
        shadowString.write('${oneHundredPercent.length} @ 100%\n1 @ ');
      }
      shadowString.write(
          '${(shadows.opacities.last * 100).round()}% of ${hexFromArgb(argbFromLstar(shadows.lstar))}');
    }

    final scrimString = StringBuffer();
    scrimString.write('Scrim: ');
    final scrimPercentageInt =
        (scrimOpacity.opacity * 100).ceil().clamp(0, 100);
    if (scrimPercentageInt == 0) {
      scrimString.write('none');
    } else {
      scrimString.write(
          '${(scrimOpacity.opacity * 100).ceil()}% ${hexFromArgb(argbFromLstar(scrimOpacity.lstar))}');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: ChessBoardPainter(squareSize: 16),
              ),
            ),
            Column(
              children: [
                Stack(
                  children: [
                    Positioned.fill(
                        child: Container(
                      color: scrimOpacity.color,
                    )),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        scrimString.toString(),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium!
                            .copyWith(color: primaryColors.backgroundText),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    shadowString.toString(),
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: primaryColors.backgroundText,
                        shadows: shadows.shadows),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  void _uploadImagePressed(
      ValueNotifier<List<ImageProvider<Object>>> images) async {
    final imageProvider = await _pickImage();
    if (imageProvider == null) {
      return;
    }

    images.value = List.from(images.value)..add(imageProvider);

    // final sw = Stopwatch()..start();
    // final quantizerResult = await Extract.quantize(imageProvider, 64);
    // debugPrint('Quantization took ${sw.elapsedMilliseconds}ms');
    // final entriesSortedByCountDescending = quantizerResult.argbToCount.entries
    //     .toList()
    //   ..sort((a, b) => b.value.compareTo(a.value));
    // final topColor = entriesSortedByCountDescending.first.key;
  }

  Future<ImageProvider<Object>?> _pickImage() async {
    final picker = ImagePicker();
    final imageFile = await picker.pickImage(source: ImageSource.gallery);
    if (imageFile == null) {
      return null;
    }
    if (kIsWeb) {
      return NetworkImage(imageFile.path);
    } else {
      return FileImage(File(imageFile.path));
    }
  }
}
