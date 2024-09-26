import 'dart:io';

import 'package:google_fonts/google_fonts.dart';
import 'package:libmonet/extract/quantizer_result.dart';
import 'package:libmonet/theming/monet_theme_data.dart';
import 'package:monet_studio/background_expansion_tile.dart';
import 'package:monet_studio/chessboard_painter.dart';
import 'package:monet_studio/color_picker.dart';
import 'package:monet_studio/components_widget.dart';
import 'package:monet_studio/contrast_expansion_tile.dart';
import 'package:monet_studio/extracted_widget.dart';
import 'package:monet_studio/padding.dart';
import 'package:monet_studio/quantizer_provider.dart';
import 'package:monet_studio/safe_colors_preview.dart';
import 'package:monet_studio/scaling_expansion_tile.dart';
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
    final backgroundImage = useState<ImageProvider?>(null);
    final images = useState(<ImageProvider>[]);
    final contrast = useState(0.5);
    final algo = useState(Algo.apca);
    final darkSurfaceLstar = useState(10.0);
    final lightSurfaceLstar = useState(93.0);
    final scale = useState(1.0);
    final brightnessSetting = useState(BrightnessSetting.auto);
    final brightness = brightnessSetting.value.brightness(context);
    final font = GoogleFonts.alice();
    final font2 = GoogleFonts.imFellEnglish();
    final font3 = GoogleFonts.lusitana();
    final font4 = GoogleFonts.lobster();
    final ui = FutureBuilder<Object>(
        future: GoogleFonts.pendingFonts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          print('async snapshot data: ${snapshot.data}');
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
                                ContrastExpansionTile(
                                    contrast: contrast, algo: algo),
                                _buildComponentPreview(
                                    context, contrast, images),
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
                                            fontFamily: font3.fontFamily,
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

    final imageQuantizerResult = backgroundImage.value == null
        ? null
        : ref
            .watch(quantizerResultProvider(backgroundImage.value!))
            .valueOrNull;
    final surfaceLstar = brightness == Brightness.light
        ? lightSurfaceLstar.value
        : darkSurfaceLstar.value;
    final answer = switch (imageQuantizerResult) {
      (QuantizerResult e) => MonetTheme(
          monetThemeData: MonetThemeData.fromQuantizerResult(
          brightness: brightness,
            backgroundTone: surfaceLstar,
          quantizerResult: e,
          contrast: contrast.value,
          algo: algo.value,
            scale: scale.value,
          ),
          child: ui),
      _ => MonetTheme(
          monetThemeData: MonetThemeData.fromColor(
          brightness: brightness,
          algo: algo.value,
          contrast: contrast.value,
          color: color.value,
            backgroundTone: surfaceLstar,
            scale: scale.value,
          ),
          child: ui,
        )
    };
    return answer;
  }

  Stack _buildComponentPreview(
    BuildContext context,
    ValueNotifier<double> contrast,
    ValueNotifier<List<ImageProvider>> images,
  ) {
    final monetTheme = MonetTheme.of(context);
    final primaryColors = monetTheme.primary;
    final scrimOpacity = getOpacity(
      minBgLstar: 0,
      maxBgLstar: 100,
      algo: monetTheme.algo,
      foregroundLstar: lstarFromArgb(primaryColors.backgroundText.value),
      contrast: contrast.value,
    );
    final shadows = getShadowOpacities(
      minBgLstar: 0,
      maxBgLstar: 100,
      algo: monetTheme.algo,
      foregroundLstar: lstarFromArgb(primaryColors.backgroundText.value),
      contrast: contrast.value,
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
                SafeColorsPreviewRow(
                  safeColors: MonetTheme.of(context).primary,
                  scrim: previewRowScrim,
                  shadows: previewRowShadows,
                ),
                SafeColorsPreviewRow(
                  safeColors: MonetTheme.of(context).secondary,
                  scrim: previewRowScrim,
                  shadows: previewRowShadows,
                ),
                SafeColorsPreviewRow(
                  safeColors: MonetTheme.of(context).tertiary,
                  scrim: previewRowScrim,
                  shadows: previewRowShadows,
                ),
              ],
            ),
            const HorizontalPadding(),
            buildScrimShadows(context, contrast.value, scrimOpacity, shadows),
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
      WidgetRef ref,
      ValueNotifier<List<ImageProvider<Object>>> images,
      ValueNotifier<ImageProvider?> backgroundImage,
      ValueNotifier<Color> color) async {
    final imageProvider = await _pickImage();
    if (imageProvider == null) {
      return;
    }
    images.value = List.from(images.value)..add(imageProvider);
    backgroundImage.value = imageProvider;
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
