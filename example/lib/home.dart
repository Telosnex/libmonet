import 'dart:io';

import 'package:example/color_picker.dart';
import 'package:example/components_widget.dart';
import 'package:example/contrast_picker.dart';
import 'package:example/extracted_widget.dart';
import 'package:example/padding.dart';
import 'package:example/safe_colors_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:libmonet/contrast.dart';
import 'package:libmonet/theming/monet_theme.dart';

enum BrighnessSetting {
  light,
  dark,
  auto;

  Brightness brightness(BuildContext context) {
    switch (this) {
      case BrighnessSetting.light:
        return Brightness.light;
      case BrighnessSetting.dark:
        return Brightness.dark;
      case BrighnessSetting.auto:
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
    final brightnessSetting = useState(BrighnessSetting.auto);
    final brightness = brightnessSetting.value.brightness(context);
    return MonetTheme.fromColor(
      brightness: brightness,
      algo: algo.value,
      contrast: contrast.value,
      color: color.value,
      surfaceLstar: brightness == Brightness.light ? 93 : 10,
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
                                      .text),
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
                      const VerticalPadding(),
                      ExpansionTile(
                        title: Text(
                          'Mode',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge!
                              .copyWith(
                                  color: MonetTheme.of(context)
                                      .primarySafeColors
                                      .text),
                        ),
                        trailing: ToggleButtons(
                            isSelected: [
                              brightnessSetting.value == BrighnessSetting.light,
                              brightnessSetting.value == BrighnessSetting.dark,
                              brightnessSetting.value == BrighnessSetting.auto,
                            ],
                            onPressed: (index) {
                              brightnessSetting.value =
                                  BrighnessSetting.values[index];
                            },
                            children: const [
                              Text('Light'),
                              Text('Dark'),
                              Text('Auto'),
                            ]
                                .map((e) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0),
                                      child: e,
                                    ))
                                .toList()),
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
