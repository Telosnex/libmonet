import 'dart:io';

import 'package:google_fonts/google_fonts.dart';
import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/contrast/contrast.dart';
import 'package:libmonet/core/hex_codes.dart';
import 'package:libmonet/effects/opacity.dart';
import 'package:libmonet/effects/shadows.dart';
import 'package:libmonet/theming/monet_theme_data.dart';
import 'package:monet_studio/background_expansion_tile.dart';
import 'package:monet_studio/chessboard_painter.dart';
import 'package:monet_studio/color_picker.dart';
import 'package:monet_studio/gamut_chart.dart';
import 'package:monet_studio/components_widget.dart';
import 'package:monet_studio/contrast_expansion_tile.dart';
import 'package:monet_studio/extracted_widget.dart';
import 'package:monet_studio/padding.dart';
import 'package:monet_studio/palette_viewer.dart';
import 'package:monet_studio/quantizer_provider.dart';
import 'package:monet_studio/safe_colors_preview.dart';
import 'package:monet_studio/scaling_expansion_tile.dart';
import 'package:monet_studio/scrim_expansion_tile.dart';
import 'package:monet_studio/theme_data_provider.dart';
import 'package:monet_studio/custom_bg_expansion_tile.dart';
import 'package:monet_studio/tokens_expansion_tile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
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

class _QuantizerColorCountToggle extends StatelessWidget {
  const _QuantizerColorCountToggle({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 32, label: Text('32')),
        ButtonSegment(value: 64, label: Text('64')),
        ButtonSegment(value: 128, label: Text('128')),
        ButtonSegment(value: 256, label: Text('256')),
      ],
      selected: {value},
      onSelectionChanged: (selection) {
        onChanged(selection.single);
      },
    );
  }
}

class Home extends HookConsumerWidget {
  const Home({super.key, this.initialColor = const Color(0xff335147)});

  final Color initialColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = useState(initialColor);
    final backgroundImage = useState<ImageProvider?>(null);
    final images = useState(<ImageProvider>[]);
    final contrast = useState(0.5);
    final algo = useState(Algo.apca);
    final darkSurfaceLstar = useState(10.0);
    final lightSurfaceLstar = useState(93.0);
    final scale = useState(1.0);
    final quantizerColorCount = useState(32);
    final brightnessSetting = useState(BrightnessSetting.auto);
    final brightness = brightnessSetting.value.brightness(context);
    final surfaceLstar = brightness == Brightness.light
        ? lightSurfaceLstar.value
        : darkSurfaceLstar.value;
    final font = GoogleFonts.alice();
    final font2 = GoogleFonts.lusitana();
    final pendingFonts = useMemoized(GoogleFonts.pendingFonts);
    final imageQuantizerResult = backgroundImage.value == null
        ? null
        : ref
            .watch(quantizerResultProvider(QuantizerRequest(
              imageProvider: backgroundImage.value!,
              colorCount: quantizerColorCount.value,
            )))
            .valueOrNull;
    final themeRequest = MonetThemeDataRequest(
      brightness: brightness,
      backgroundTone: surfaceLstar,
      seedColor: color.value,
      quantizerResult: imageQuantizerResult,
      contrast: contrast.value,
      algo: algo.value,
      scale: scale.value,
    );
    final themeDataByModel = {
      for (final model in ColorModel.values)
        model: ref.watch(
          monetThemeDataProvider(themeRequest.copyWith(colorModel: model)),
        ),
    };
    final activeThemeData = themeDataByModel[ColorModel.kDefault]!;
    final ui = FutureBuilder<Object>(
        future: pendingFonts,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return Builder(builder: (context) {
            return DefaultTextStyle(
              style: font,
              child: Scaffold(
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  title: Text(
                    'Monet Studio',
                    style: font,
                  ),
                ),
                body: Stack(
                  children: [
                    if (backgroundImage.value != null)
                      Positioned.fill(
                        child: Image(
                          image: backgroundImage.value!,
                          fit: BoxFit.none,
                        ),
                      ),
                    SingleChildScrollView(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                              maxWidth: MonetThemeData.maxPanelWidth),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const VerticalPadding(),
                                BackgroundExpansionTile(
                                  darkModeLstarNotifier: darkSurfaceLstar,
                                  lightModeLstarNotifier: lightSurfaceLstar,
                                  brightnessSettingNotifier: brightnessSetting,
                                ),
                                const VerticalPadding(),
                                for (final image in images.value)
                                  ExtractedWidget(
                                    image: image,
                                    quantizerColorCount:
                                        quantizerColorCount.value,
                                    onRemove: () {
                                      images.value = images.value
                                          .where(
                                              (candidate) => candidate != image)
                                          .toList();
                                      if (backgroundImage.value == image) {
                                        backgroundImage.value = null;
                                      }
                                    },
                                    onTapped: () {
                                      backgroundImage.value = image;
                                    },
                                  ),
                                const VerticalPadding(),
                                ColorPicker(
                                  color: color.value,
                                  onColorChanged: (newColor) {
                                    color.value = newColor;
                                    backgroundImage.value = null;
                                  },
                                  onPhotoLibraryTapped: () {
                                    _uploadImagePressed(
                                        ref, images, backgroundImage, color);
                                  },
                                ),
                                const VerticalPadding(),
                                _QuantizerColorCountToggle(
                                  value: quantizerColorCount.value,
                                  onChanged: (value) {
                                    quantizerColorCount.value = value;
                                  },
                                ),
                                const VerticalPadding(),
                                PaletteViewer(
                                    themeDataByModel: themeDataByModel),
                                const VerticalPadding(),
                                ContrastExpansionTile(
                                    contrast: contrast, algo: algo),
                                _buildComponentPreview(
                                  context,
                                  themeDataByModel,
                                  images,
                                ),
                                const TokensExpansionTile(),
                                const VerticalPadding(),
                                ScrimExpansionTile(
                                  contrast: contrast.value,
                                ),
                                const VerticalPadding(),
                                CustomBgExpansionTile(
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
                                            fontFamily: font2.fontFamily,
                                            color: MonetTheme.of(context)
                                                .primary
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
                                ScalingExpansionTile(
                                  scaleValueNotifier: scale,
                                ),
                                const VerticalPadding(),
                                const GamutChart(initialHue: 27.0),
                                const VerticalPadding(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          });
        });

    return MonetTheme(
      monetThemeData: activeThemeData,
      child: ui,
    );
  }

  Stack _buildComponentPreview(
    BuildContext context,
    Map<ColorModel, MonetThemeData> themeDataByModel,
    ValueNotifier<List<ImageProvider>> images,
  ) {
    final monetTheme = MonetTheme.of(context);
    final themeData = themeDataByModel[ColorModel.kDefault]!;
    final primaryColors = monetTheme.primary;
    final fgArgb = primaryColors.backgroundText.argb;
    final scrimOpacity = getOpacityForArgbs(
      foregroundArgb: fgArgb,
      minBackgroundArgb: 0xFF000000,
      maxBackgroundArgb: 0xFFFFFFFF,
      algo: monetTheme.algo,
      contrast: themeData.contrast,
    );
    final shadows = getShadowOpacitiesForArgbs(
      foregroundArgb: fgArgb,
      minBackgroundArgb: 0xFF000000,
      maxBackgroundArgb: 0xFFFFFFFF,
      algo: monetTheme.algo,
      contrast: themeData.contrast,
      blurRadius: 5,
      contentRadius: 3,
    );
    final previewRowScrim = images.value.isEmpty ? null : scrimOpacity;
    final previewRowShadows = images.value.isEmpty ? null : shadows;

    return Stack(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          // mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              children: [
                SafeColorsPreview(
                  themeDataByModel: themeDataByModel,
                  scrim: previewRowScrim,
                  shadows: previewRowShadows,
                ),
              ],
            ),
            const HorizontalPadding(),
            buildScrimShadows(
                context, themeData.contrast, scrimOpacity, shadows),
          ],
        ),
      ],
    );
  }

  Widget buildScrimShadows(
    BuildContext context,
    double contrast,
    OpacityResult scrimOpacity,
    ShadowResult shadows,
  ) {
    final primaryColors = MonetTheme.of(context).primary;
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
          '${(shadows.opacities.last * 100).round()}% of ${hexFromArgb(shadows.shadowArgb)}');
    }

    final scrimString = StringBuffer();
    scrimString.write('Scrim: ');
    final scrimPercentageInt =
        (scrimOpacity.opacity * 100).ceil().clamp(0, 100);
    if (scrimPercentageInt == 0) {
      scrimString.write('none');
    } else {
      scrimString.write(
          '${(scrimOpacity.opacity * 100).ceil()}% ${hexFromArgb(scrimOpacity.protectionArgb)}');
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
      WidgetRef ref,
      ValueNotifier<List<ImageProvider<Object>>> images,
      ValueNotifier<ImageProvider?> backgroundImage,
      ValueNotifier<Color> color) async {
    final imageProviders = await _pickImages();
    if (imageProviders.isEmpty) {
      return;
    }
    images.value = List.from(images.value)..addAll(imageProviders);
    backgroundImage.value = imageProviders.first;
  }

  Future<List<ImageProvider<Object>>> _pickImages() async {
    final picker = ImagePicker();
    final imageFiles = await picker.pickMultiImage();
    if (imageFiles.isEmpty) {
      return const [];
    }
    return [
      for (final imageFile in imageFiles)
        if (kIsWeb)
          NetworkImage(imageFile.path)
        else
          FileImage(File(imageFile.path)),
    ];
  }
}
