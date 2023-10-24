import 'dart:io';

import 'package:example/color_picker.dart';
import 'package:example/extracted_widget.dart';
import 'package:example/padding.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:libmonet/contrast.dart';
import 'package:libmonet/theming/monet_theme.dart';

class Home extends HookConsumerWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = useState(const Color(0xff335147));
    final images = useState(<ImageProvider>[]);
    final contrast = useState(0.5);
    final algo = useState(Algo.apca);
    return MonetTheme.fromColor(
      brightness: Theme.of(context).brightness,
      algo: algo.value,
      contrast: contrast.value,
      color: color.value,
      surfaceLstar: Theme.of(context).brightness == Brightness.light ? 93 : 10,
      child: Builder(builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Monet Studio'),
          ),
          body: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ColorPicker(
                  color: color.value,
                  onColorChanged: (newColor) {
                    color.value = newColor;
                  },
                ),
                _contrastWidgets(algo, contrast),
                ElevatedButton.icon(
                  onPressed: () => _uploadImagePressed(images),
                  icon: const Icon(Icons.photo),
                  label: const Text('Upload Image'),
                ),
                for (final image in images.value) ExtractedWidget(image: image),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _contrastWidgets(
      ValueNotifier<Algo> algo, ValueNotifier<double> contrast) {
    return Row(
      children: [
        const HorizontalPadding(),
        ToggleButtons(
          isSelected: [algo.value == Algo.apca, algo.value == Algo.wcag21],
          onPressed: (index) {
            algo.value = index == 0 ? Algo.apca : Algo.wcag21;
          },
          children: const [Text('APCA'), Text('WCAG 2.1')],
        ),
        Flexible(
          child: Slider(
            value: contrast.value,
            min: 0.0,
            max: 1.0,
            onChanged: (value) {
              contrast.value = value;
            },
          ),
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
    print('images: ${images.value.length}');

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
