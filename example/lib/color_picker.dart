import 'dart:math';

import 'package:example/safe_colors_preview.dart';
import 'package:flutter/material.dart';
import 'package:libmonet/contrast.dart';

class ColorPicker extends StatefulWidget {
  const ColorPicker({
    super.key,
    required this.color,
    required this.onColorChanged,
  });

  final Color color;
  final Function(Color) onColorChanged;

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  // var _color = const Color(0xff334157);
  var _algo = Algo.apca;
  var _contrast = 0.5;
  final random = Random.secure();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ToggleButtons(
          isSelected: [_algo == Algo.apca, _algo == Algo.wcag21],
          onPressed: (index) {
            setState(() {
              _algo = index == 0 ? Algo.apca : Algo.wcag21;
            });
          },
          children: const [Text('APCA'), Text('WCAG 2.1')],
        ),
        ElevatedButton.icon(
            onPressed: () {
              final randomColor = Color.fromARGB(255, random.nextInt(256),
                  random.nextInt(256), random.nextInt(256));
              widget.onColorChanged(randomColor);
            },
            icon: const Icon(Icons.shuffle),
            label: const Text('Shuffle')),
        Slider(
            value: _contrast,
            min: 0.0,
            max: 1.0,
            onChanged: (value) {
              setState(() {
                _contrast = value;
              });
            }),
        SafeColorsPreviewRow(
            color: widget.color,
            contrast: _contrast,
            algo: _algo,
            backgroundLstar: 100),
        SafeColorsPreviewRow(
            color: widget.color,
            contrast: _contrast,
            algo: _algo,
            backgroundLstar: 0),
      ],
    );
  }
}
