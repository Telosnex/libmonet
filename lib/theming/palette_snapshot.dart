import 'package:flutter/material.dart';
import 'package:libmonet/libmonet.dart';

// Snapshot of [Palette]: captures token outputs at construction time and
// returns the same values thereafter.
class PaletteSnapshot extends Palette {
  // Background
  final Color _background;
  final Color _backgroundText;
  final Color _backgroundFill;
  final Color _backgroundBorder;
  final Color _backgroundHovered;
  final Color _backgroundSplashed;
  final Color _backgroundHoveredFill;
  final Color _backgroundSplashedFill;
  final Color _backgroundHoveredText;
  final Color _backgroundSplashedText;
  final Color _backgroundHoveredBorder;
  final Color _backgroundSplashedBorder;

  // Fill
  final Color _fill;
  final Color _fillBorder;
  final Color _fillHovered;
  final Color _fillSplashed;
  final Color _fillText;
  final Color _fillHoveredText;
  final Color _fillSplashedText;
  final Color _fillIcon;
  final Color _fillHoveredBorder;
  final Color _fillSplashedBorder;

  // Color
  final Color _color;
  final Color _colorText;
  final Color _colorIcon;
  final Color _colorBorder;
  final Color _colorHovered;
  final Color _colorHoveredText;
  final Color _colorHoveredBorder;
  final Color _colorSplashed;
  final Color _colorSplashedText;
  final Color _colorSplashedBorder;

  // Text
  final Color _text;
  final Color _textHovered;
  final Color _textHoveredText;
  final Color _textSplashed;
  final Color _textSplashedText;

  PaletteSnapshot._({
    required super.baseColor,
    required super.baseBackground,
    required Color background,
    required Color backgroundText,
    required Color backgroundFill,
    required Color backgroundBorder,
    required Color backgroundHovered,
    required Color backgroundSplashed,
    required Color backgroundHoveredFill,
    required Color backgroundSplashedFill,
    required Color backgroundHoveredText,
    required Color backgroundSplashedText,
    required Color backgroundHoveredBorder,
    required Color backgroundSplashedBorder,
    required Color fill,
    required Color fillBorder,
    required Color fillHovered,
    required Color fillSplashed,
    required Color fillText,
    required Color fillHoveredText,
    required Color fillSplashedText,
    required Color fillIcon,
    required Color fillHoveredBorder,
    required Color fillSplashedBorder,
    required Color color,
    required Color colorText,
    required Color colorIcon,
    required Color colorBorder,
    required Color colorHovered,
    required Color colorHoveredText,
    required Color colorHoveredBorder,
    required Color colorSplashed,
    required Color colorSplashedText,
    required Color colorSplashedBorder,
    required Color text,
    required Color textHovered,
    required Color textHoveredText,
    required Color textSplashed,
    required Color textSplashedText,
  })  : _background = background,
        _backgroundText = backgroundText,
        _backgroundFill = backgroundFill,
        _backgroundBorder = backgroundBorder,
        _backgroundHovered = backgroundHovered,
        _backgroundSplashed = backgroundSplashed,
        _backgroundHoveredFill = backgroundHoveredFill,
        _backgroundSplashedFill = backgroundSplashedFill,
        _backgroundHoveredText = backgroundHoveredText,
        _backgroundSplashedText = backgroundSplashedText,
        _backgroundHoveredBorder = backgroundHoveredBorder,
        _backgroundSplashedBorder = backgroundSplashedBorder,
        _fill = fill,
        _fillBorder = fillBorder,
        _fillHovered = fillHovered,
        _fillSplashed = fillSplashed,
        _fillText = fillText,
        _fillHoveredText = fillHoveredText,
        _fillSplashedText = fillSplashedText,
        _fillIcon = fillIcon,
        _fillHoveredBorder = fillHoveredBorder,
        _fillSplashedBorder = fillSplashedBorder,
        _color = color,
        _colorText = colorText,
        _colorIcon = colorIcon,
        _colorBorder = colorBorder,
        _colorHovered = colorHovered,
        _colorHoveredText = colorHoveredText,
        _colorHoveredBorder = colorHoveredBorder,
        _colorSplashed = colorSplashed,
        _colorSplashedText = colorSplashedText,
        _colorSplashedBorder = colorSplashedBorder,
        _text = text,
        _textHovered = textHovered,
        _textHoveredText = textHoveredText,
        _textSplashed = textSplashed,
        _textSplashedText = textSplashedText,
        // ignore: invalid_use_of_visible_for_testing_member
        super.base(
          contrast: 0.5,
          algo: Algo.apca,
        );

  factory PaletteSnapshot.capture(Palette s) {
    return PaletteSnapshot._(
      baseColor: s.color,
      baseBackground: s.background,
      background: s.background,
      backgroundText: s.backgroundText,
      backgroundFill: s.backgroundFill,
      backgroundBorder: s.backgroundBorder,
      backgroundHovered: s.backgroundHovered,
      backgroundSplashed: s.backgroundSplashed,
      backgroundHoveredFill: s.backgroundHoveredFill,
      backgroundSplashedFill: s.backgroundSplashedFill,
      backgroundHoveredText: s.backgroundHoveredText,
      backgroundSplashedText: s.backgroundSplashedText,
      backgroundHoveredBorder: s.backgroundHoveredBorder,
      backgroundSplashedBorder: s.backgroundSplashedBorder,
      fill: s.fill,
      fillBorder: s.fillBorder,
      fillHovered: s.fillHovered,
      fillSplashed: s.fillSplashed,
      fillText: s.fillText,
      fillHoveredText: s.fillHoveredText,
      fillSplashedText: s.fillSplashedText,
      fillIcon: s.fillIcon,
      fillHoveredBorder: s.fillHoveredBorder,
      fillSplashedBorder: s.fillSplashedBorder,
      color: s.color,
      colorText: s.colorText,
      colorIcon: s.colorIcon,
      colorBorder: s.colorBorder,
      colorHovered: s.colorHovered,
      colorHoveredText: s.colorHoveredText,
      colorHoveredBorder: s.colorHoveredBorder,
      colorSplashed: s.colorSplashed,
      colorSplashedText: s.colorSplashedText,
      colorSplashedBorder: s.colorSplashedBorder,
      text: s.text,
      textHovered: s.textHovered,
      textHoveredText: s.textHoveredText,
      textSplashed: s.textSplashed,
      textSplashedText: s.textSplashedText,
    );
  }

  // Background
  @override
  Color get background => _background;
  @override
  Color get backgroundText => _backgroundText;
  @override
  Color get backgroundFill => _backgroundFill;
  @override
  Color get backgroundBorder => _backgroundBorder;
  @override
  Color get backgroundHovered => _backgroundHovered;
  @override
  Color get backgroundSplashed => _backgroundSplashed;
  @override
  Color get backgroundHoveredFill => _backgroundHoveredFill;
  @override
  Color get backgroundSplashedFill => _backgroundSplashedFill;
  @override
  Color get backgroundHoveredText => _backgroundHoveredText;
  @override
  Color get backgroundSplashedText => _backgroundSplashedText;
  @override
  Color get backgroundHoveredBorder => _backgroundHoveredBorder;
  @override
  Color get backgroundSplashedBorder => _backgroundSplashedBorder;

  // Fill
  @override
  Color get fill => _fill;
  @override
  Color get fillBorder => _fillBorder;
  @override
  Color get fillHovered => _fillHovered;
  @override
  Color get fillSplashed => _fillSplashed;
  @override
  Color get fillText => _fillText;
  @override
  Color get fillHoveredText => _fillHoveredText;
  @override
  Color get fillSplashedText => _fillSplashedText;
  @override
  Color get fillIcon => _fillIcon;
  @override
  Color get fillHoveredBorder => _fillHoveredBorder;
  @override
  Color get fillSplashedBorder => _fillSplashedBorder;

  // Color (ink)
  @override
  Color get color => _color;
  @override
  Color get colorText => _colorText;
  @override
  Color get colorIcon => _colorIcon;
  @override
  Color get colorBorder => _colorBorder;
  @override
  Color get colorHovered => _colorHovered;
  @override
  Color get colorHoveredText => _colorHoveredText;
  @override
  Color get colorHoveredBorder => _colorHoveredBorder;
  @override
  Color get colorSplashed => _colorSplashed;
  @override
  Color get colorSplashedText => _colorSplashedText;
  @override
  Color get colorSplashedBorder => _colorSplashedBorder;

  // Text standalone
  @override
  Color get text => _text;
  @override
  Color get textHovered => _textHovered;
  @override
  Color get textHoveredText => _textHoveredText;
  @override
  Color get textSplashed => _textSplashed;
  @override
  Color get textSplashedText => _textSplashedText;
}
