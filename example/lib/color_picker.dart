import 'package:example/safe_colors_preview.dart';
import 'package:flutter/material.dart';
import 'package:libmonet/contrast.dart';

class ColorPicker extends StatefulWidget {
  const ColorPicker({super.key});

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  static const _color = Color(0xff334157);
  var _algo = Algo.apca;
  var _contrast = 0.5;


  @override
  Widget build(BuildContext context) {
    return  Column(
      children: [
        ToggleButtons(isSelected: [_algo == Algo.apca, _algo == Algo.wcag21], onPressed: (index) {
          setState(() {
            _algo = index == 0 ? Algo.apca : Algo.wcag21;
          });
        },children: const [Text('APCA'), Text('WCAG 2.1')],),
        Slider(value: _contrast, min: 0.0, max: 1.0, onChanged: (value) {
          setState(() {
            _contrast = value;
          });
        }),
        SafeColorsPreviewRow(color: _color, contrast: _contrast, algo: _algo, backgroundLstar: 100),
        SafeColorsPreviewRow(color: _color, contrast: _contrast, algo: _algo, backgroundLstar: 0),
      ],
    );
  }
}
