import 'dart:ui';

import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/contrast/contrast.dart';
import 'package:libmonet/theming/monet_theme_data.dart';
import 'package:libmonet/theming/palette.dart';

/// Immutable recipe identity and inputs in one value. Use with bindRecipe rather
/// than a separate key and closure. Inherited inputs come from the logical theme
/// endpoint, never its moving frame. Subclasses define which inputs inherit and
/// must have immutable value equality.
abstract class PaletteRecipe {
  const PaletteRecipe();
  Palette resolve(MonetThemeData theme);
}

/// A brand color on a theme-derived, tone-selected, or explicit background.
/// With an explicit [background], [backgroundTone] optionally identifies the
/// shared logical context used for polarity. Without it, that concrete surface
/// forms its own context. Without [background], a null tone inherits the theme.
final class ColorPaletteRecipe extends PaletteRecipe {
  const ColorPaletteRecipe(
    this.color, {
    this.background,
    this.backgroundTone,
    this.contrast,
    this.algo,
    this.colorModel,
  });

  final Color color;
  final Color? background;
  final double? backgroundTone;
  final double? contrast;
  final Algo? algo;
  final ColorModel? colorModel;

  @override
  Palette resolve(MonetThemeData theme) => background != null
      ? Palette.fromColorAndBackground(
          color,
          background!,
          backgroundTone: backgroundTone,
          contrast: contrast ?? theme.contrast,
          algo: algo ?? theme.algo,
          colorModel: colorModel ?? theme.colorModel,
        )
      : Palette.from(
          color,
          backgroundTone: backgroundTone ?? theme.backgroundTone,
          contrast: contrast ?? theme.contrast,
          algo: algo ?? theme.algo,
          colorModel: colorModel ?? theme.colorModel,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ColorPaletteRecipe &&
          color == other.color &&
          background == other.background &&
          backgroundTone == other.backgroundTone &&
          contrast == other.contrast &&
          algo == other.algo &&
          colorModel == other.colorModel;
  @override
  int get hashCode => Object.hash(
    color,
    background,
    backgroundTone,
    contrast,
    algo,
    colorModel,
  );
}
