import 'dart:io';

import 'package:example/background_expansion_tile.dart';
import 'package:example/color_picker.dart';
import 'package:example/components_widget.dart';
import 'package:example/contrast_picker.dart';
import 'package:example/extracted_widget.dart';
import 'package:example/padding.dart';
import 'package:example/safe_colors_preview.dart';
import 'package:example/tokens_expansion_tile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:libmonet/contrast.dart';
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
                        title: Text(
                          'Contrast',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge!
                              .copyWith(
                                  color: MonetTheme.of(context)
                                      .primarySafeColors
                                    .text,
                              ),
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
            
                      SafeColorsPreviewRow(
                        safeColors: MonetTheme.of(context).primarySafeColors,
                      ),
                      SafeColorsPreviewRow(
                        safeColors: MonetTheme.of(context).secondarySafeColors,
                      ),
                      SafeColorsPreviewRow(
                        safeColors: MonetTheme.of(context).tertiarySafeColors,
                      ),
                      const TokensExpansionTile(),
                      const VerticalPadding(),
                      ExpansionTile(
                        title: Text(
                          'Material Components',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge!
                              .copyWith(
                                  color: MonetTheme.of(context)
                                      .primarySafeColors
                                      .text),
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
