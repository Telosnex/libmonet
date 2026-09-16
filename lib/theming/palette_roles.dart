import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:libmonet/colorspaces/color_model.dart';

import 'palette.dart';

/// Exhaustive public palette paint outputs. Keep in sync with Palette.
enum PaletteRole {
  background,
  backgroundText,
  backgroundFill,
  backgroundBorder,
  backgroundHovered,
  backgroundSplashed,
  backgroundHoveredFill,
  backgroundSplashedFill,
  backgroundHoveredText,
  backgroundSplashedText,
  backgroundHoveredBorder,
  backgroundSplashedBorder,
  fill,
  fillBorder,
  fillHovered,
  fillSplashed,
  fillText,
  fillHoveredText,
  fillSplashedText,
  fillIcon,
  fillHoveredIcon,
  fillSplashedIcon,
  fillHoveredBorder,
  fillSplashedBorder,
  color,
  colorText,
  colorIcon,
  colorHoveredIcon,
  colorSplashedIcon,
  colorBorder,
  colorHovered,
  colorHoveredText,
  colorHoveredBorder,
  colorSplashed,
  colorSplashedText,
  colorSplashedBorder,
  text,
  textHovered,
  textHoveredText,
  textSplashed,
  textSplashedText;

  Color read(Palette palette) => switch (this) {
    background => palette.background,
    backgroundText => palette.backgroundText,
    backgroundFill => palette.backgroundFill,
    backgroundBorder => palette.backgroundBorder,
    backgroundHovered => palette.backgroundHovered,
    backgroundSplashed => palette.backgroundSplashed,
    backgroundHoveredFill => palette.backgroundHoveredFill,
    backgroundSplashedFill => palette.backgroundSplashedFill,
    backgroundHoveredText => palette.backgroundHoveredText,
    backgroundSplashedText => palette.backgroundSplashedText,
    backgroundHoveredBorder => palette.backgroundHoveredBorder,
    backgroundSplashedBorder => palette.backgroundSplashedBorder,
    fill => palette.fill,
    fillBorder => palette.fillBorder,
    fillHovered => palette.fillHovered,
    fillSplashed => palette.fillSplashed,
    fillText => palette.fillText,
    fillHoveredText => palette.fillHoveredText,
    fillSplashedText => palette.fillSplashedText,
    fillIcon => palette.fillIcon,
    fillHoveredIcon => palette.fillHoveredIcon,
    fillSplashedIcon => palette.fillSplashedIcon,
    fillHoveredBorder => palette.fillHoveredBorder,
    fillSplashedBorder => palette.fillSplashedBorder,
    color => palette.color,
    colorText => palette.colorText,
    colorIcon => palette.colorIcon,
    colorHoveredIcon => palette.colorHoveredIcon,
    colorSplashedIcon => palette.colorSplashedIcon,
    colorBorder => palette.colorBorder,
    colorHovered => palette.colorHovered,
    colorHoveredText => palette.colorHoveredText,
    colorHoveredBorder => palette.colorHoveredBorder,
    colorSplashed => palette.colorSplashed,
    colorSplashedText => palette.colorSplashedText,
    colorSplashedBorder => palette.colorSplashedBorder,
    text => palette.text,
    textHovered => palette.textHovered,
    textHoveredText => palette.textHoveredText,
    textSplashed => palette.textSplashed,
    textSplashedText => palette.textSplashedText,
  };
}

/// Palette interface shared by output snapshots and observing views.
abstract class RolePalette extends Palette {
  const RolePalette(this.colorModel);
  @override
  final ColorModel colorModel;
  Color readRole(PaletteRole role);
  @override
  Color get background => readRole(PaletteRole.background);
  @override
  Color get backgroundText => readRole(PaletteRole.backgroundText);
  @override
  Color get backgroundFill => readRole(PaletteRole.backgroundFill);
  @override
  Color get backgroundBorder => readRole(PaletteRole.backgroundBorder);
  @override
  Color get backgroundHovered => readRole(PaletteRole.backgroundHovered);
  @override
  Color get backgroundSplashed => readRole(PaletteRole.backgroundSplashed);
  @override
  Color get backgroundHoveredFill =>
      readRole(PaletteRole.backgroundHoveredFill);
  @override
  Color get backgroundSplashedFill =>
      readRole(PaletteRole.backgroundSplashedFill);
  @override
  Color get backgroundHoveredText =>
      readRole(PaletteRole.backgroundHoveredText);
  @override
  Color get backgroundSplashedText =>
      readRole(PaletteRole.backgroundSplashedText);
  @override
  Color get backgroundHoveredBorder =>
      readRole(PaletteRole.backgroundHoveredBorder);
  @override
  Color get backgroundSplashedBorder =>
      readRole(PaletteRole.backgroundSplashedBorder);
  @override
  Color get fill => readRole(PaletteRole.fill);
  @override
  Color get fillBorder => readRole(PaletteRole.fillBorder);
  @override
  Color get fillHovered => readRole(PaletteRole.fillHovered);
  @override
  Color get fillSplashed => readRole(PaletteRole.fillSplashed);
  @override
  Color get fillText => readRole(PaletteRole.fillText);
  @override
  Color get fillHoveredText => readRole(PaletteRole.fillHoveredText);
  @override
  Color get fillSplashedText => readRole(PaletteRole.fillSplashedText);
  @override
  Color get fillIcon => readRole(PaletteRole.fillIcon);
  @override
  Color get fillHoveredIcon => readRole(PaletteRole.fillHoveredIcon);
  @override
  Color get fillSplashedIcon => readRole(PaletteRole.fillSplashedIcon);
  @override
  Color get fillHoveredBorder => readRole(PaletteRole.fillHoveredBorder);
  @override
  Color get fillSplashedBorder => readRole(PaletteRole.fillSplashedBorder);
  @override
  Color get color => readRole(PaletteRole.color);
  @override
  Color get colorText => readRole(PaletteRole.colorText);
  @override
  Color get colorIcon => readRole(PaletteRole.colorIcon);
  @override
  Color get colorHoveredIcon => readRole(PaletteRole.colorHoveredIcon);
  @override
  Color get colorSplashedIcon => readRole(PaletteRole.colorSplashedIcon);
  @override
  Color get colorBorder => readRole(PaletteRole.colorBorder);
  @override
  Color get colorHovered => readRole(PaletteRole.colorHovered);
  @override
  Color get colorHoveredText => readRole(PaletteRole.colorHoveredText);
  @override
  Color get colorHoveredBorder => readRole(PaletteRole.colorHoveredBorder);
  @override
  Color get colorSplashed => readRole(PaletteRole.colorSplashed);
  @override
  Color get colorSplashedText => readRole(PaletteRole.colorSplashedText);
  @override
  Color get colorSplashedBorder => readRole(PaletteRole.colorSplashedBorder);
  @override
  Color get text => readRole(PaletteRole.text);
  @override
  Color get textHovered => readRole(PaletteRole.textHovered);
  @override
  Color get textHoveredText => readRole(PaletteRole.textHoveredText);
  @override
  Color get textSplashed => readRole(PaletteRole.textSplashed);
  @override
  Color get textSplashedText => readRole(PaletteRole.textSplashedText);
}

/// Small prewarm sets for reusable controls, not mandatory declarations.
/// A first-ever unprepared state starts at the endpoint; preparing its family
/// before a transition lets hover/pressed states share the existing fade.
abstract final class PaletteStates {
  static const fill = {
    PaletteRole.fill,
    PaletteRole.fillText,
    PaletteRole.fillIcon,
    PaletteRole.fillBorder,
    PaletteRole.fillHovered,
    PaletteRole.fillHoveredText,
    PaletteRole.fillHoveredIcon,
    PaletteRole.fillHoveredBorder,
    PaletteRole.fillSplashed,
    PaletteRole.fillSplashedText,
    PaletteRole.fillSplashedIcon,
    PaletteRole.fillSplashedBorder,
  };
  static const color = {
    PaletteRole.color,
    PaletteRole.colorText,
    PaletteRole.colorIcon,
    PaletteRole.colorBorder,
    PaletteRole.colorHovered,
    PaletteRole.colorHoveredText,
    PaletteRole.colorHoveredIcon,
    PaletteRole.colorHoveredBorder,
    PaletteRole.colorSplashed,
    PaletteRole.colorSplashedText,
    PaletteRole.colorSplashedIcon,
    PaletteRole.colorSplashedBorder,
  };
  static const text = {
    PaletteRole.text,
    PaletteRole.textHovered,
    PaletteRole.textHoveredText,
    PaletteRole.textSplashed,
    PaletteRole.textSplashedText,
  };
}

/// A complete immutable output snapshot. Every role must be present.
class ResolvedPalette extends RolePalette {
  ResolvedPalette(List<Color> colors, super.colorModel)
    : colors = List.unmodifiable(colors) {
    if (colors.length != PaletteRole.values.length) {
      throw ArgumentError.value(
        colors.length,
        'colors.length',
        'Expected all palette roles',
      );
    }
  }
  final List<Color> colors;
  @override
  Color readRole(PaletteRole role) => colors[role.index];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResolvedPalette &&
          colorModel == other.colorModel &&
          listEquals(colors, other.colors);
  @override
  int get hashCode => Object.hash(colorModel, Object.hashAll(colors));
}

/// Immutable colors with a side-channel for discovering consumer demand.
/// Equality/hash never call getters or depend on mutable observation state.
/// The callback should weakly reference its owner: saved frames may outlive it.
class ObservedPalette extends RolePalette {
  ObservedPalette(this.source, this.onRead) : super(source.colorModel);
  final Palette source;
  final void Function(PaletteRole) onRead;
  @override
  Color readRole(PaletteRole role) {
    final color = role.read(source);
    onRead(role);
    return color;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ObservedPalette && source == other.source;
  @override
  int get hashCode => source.hashCode;
}
