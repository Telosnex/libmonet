import 'dart:ui';

import 'package:libmonet/colorspaces/hct.dart';
import 'package:libmonet/contrast/contrast.dart';
import 'package:libmonet/theming/interpolation_style.dart';
import 'package:libmonet/theming/palette.dart';

/// Interpolates between two [Palette] instances using perceptual HCT lerp.
///
/// [InterpolationStyle.cartesian] interpolates in the cartesian UCS coordinates
/// of the active color model. [InterpolationStyle.polar] interpolates HCT's
/// polar hue/chroma/tone coordinates using shortest-path hue rotation.
///
/// Token accesses are memoized per [PaletteLerped] instance. This matters when
/// many widgets read the same animated theme token during a frame, and also
/// prevents nested lerps created by implicit-animation retargeting from
/// repeatedly solving the same intermediate color.
class PaletteLerped extends Palette {
  final Palette a;
  final Palette b;
  final double t;
  final InterpolationStyle interpolationStyle;

  PaletteLerped({
    required this.a,
    required this.b,
    required this.t,
    this.interpolationStyle = InterpolationStyle.cartesian,
  })
    // ignore: invalid_use_of_visible_for_testing_member
    : super.base(
         baseColor: a.color,
         baseBackground: a.background,
         contrast: 0.5,
         algo: Algo.apca,
         colorModel: a.colorModel,
       );

  Color _lerp(Color x, Color y) {
    if (t <= 0.0 || x == y) return x;
    if (t >= 1.0) return y;
    return switch (interpolationStyle) {
      InterpolationStyle.polar => Hct.lerpKeepHue(x, y, t, model: a.colorModel),
      InterpolationStyle.cartesian => Hct.lerpLoseHueAndChroma(
        x,
        y,
        t,
        model: a.colorModel,
      ),
    };
  }

  // Background family
  late final Color _background = _lerp(a.background, b.background);
  @override
  Color get background => _background;

  late final Color _backgroundText = _lerp(a.backgroundText, b.backgroundText);
  @override
  Color get backgroundText => _backgroundText;

  late final Color _backgroundFill = _lerp(a.backgroundFill, b.backgroundFill);
  @override
  Color get backgroundFill => _backgroundFill;

  late final Color _backgroundBorder = _lerp(
    a.backgroundBorder,
    b.backgroundBorder,
  );
  @override
  Color get backgroundBorder => _backgroundBorder;

  late final Color _backgroundHovered = _lerp(
    a.backgroundHovered,
    b.backgroundHovered,
  );
  @override
  Color get backgroundHovered => _backgroundHovered;

  late final Color _backgroundSplashed = _lerp(
    a.backgroundSplashed,
    b.backgroundSplashed,
  );
  @override
  Color get backgroundSplashed => _backgroundSplashed;

  late final Color _backgroundHoveredFill = _lerp(
    a.backgroundHoveredFill,
    b.backgroundHoveredFill,
  );
  @override
  Color get backgroundHoveredFill => _backgroundHoveredFill;

  late final Color _backgroundSplashedFill = _lerp(
    a.backgroundSplashedFill,
    b.backgroundSplashedFill,
  );
  @override
  Color get backgroundSplashedFill => _backgroundSplashedFill;

  late final Color _backgroundHoveredText = _lerp(
    a.backgroundHoveredText,
    b.backgroundHoveredText,
  );
  @override
  Color get backgroundHoveredText => _backgroundHoveredText;

  late final Color _backgroundSplashedText = _lerp(
    a.backgroundSplashedText,
    b.backgroundSplashedText,
  );
  @override
  Color get backgroundSplashedText => _backgroundSplashedText;

  late final Color _backgroundHoveredBorder = _lerp(
    a.backgroundHoveredBorder,
    b.backgroundHoveredBorder,
  );
  @override
  Color get backgroundHoveredBorder => _backgroundHoveredBorder;

  late final Color _backgroundSplashedBorder = _lerp(
    a.backgroundSplashedBorder,
    b.backgroundSplashedBorder,
  );
  @override
  Color get backgroundSplashedBorder => _backgroundSplashedBorder;

  // Fill family
  late final Color _fill = _lerp(a.fill, b.fill);
  @override
  Color get fill => _fill;

  late final Color _fillBorder = _lerp(a.fillBorder, b.fillBorder);
  @override
  Color get fillBorder => _fillBorder;

  late final Color _fillHovered = _lerp(a.fillHovered, b.fillHovered);
  @override
  Color get fillHovered => _fillHovered;

  late final Color _fillSplashed = _lerp(a.fillSplashed, b.fillSplashed);
  @override
  Color get fillSplashed => _fillSplashed;

  late final Color _fillText = _lerp(a.fillText, b.fillText);
  @override
  Color get fillText => _fillText;

  late final Color _fillHoveredText = _lerp(
    a.fillHoveredText,
    b.fillHoveredText,
  );
  @override
  Color get fillHoveredText => _fillHoveredText;

  late final Color _fillSplashedText = _lerp(
    a.fillSplashedText,
    b.fillSplashedText,
  );
  @override
  Color get fillSplashedText => _fillSplashedText;

  late final Color _fillIcon = _lerp(a.fillIcon, b.fillIcon);
  @override
  Color get fillIcon => _fillIcon;

  late final Color _fillHoveredIcon = _lerp(
    a.fillHoveredIcon,
    b.fillHoveredIcon,
  );
  @override
  Color get fillHoveredIcon => _fillHoveredIcon;

  late final Color _fillSplashedIcon = _lerp(
    a.fillSplashedIcon,
    b.fillSplashedIcon,
  );
  @override
  Color get fillSplashedIcon => _fillSplashedIcon;

  late final Color _fillHoveredBorder = _lerp(
    a.fillHoveredBorder,
    b.fillHoveredBorder,
  );
  @override
  Color get fillHoveredBorder => _fillHoveredBorder;

  late final Color _fillSplashedBorder = _lerp(
    a.fillSplashedBorder,
    b.fillSplashedBorder,
  );
  @override
  Color get fillSplashedBorder => _fillSplashedBorder;

  // Color (ink) family
  late final Color _color = _lerp(a.color, b.color);
  @override
  Color get color => _color;

  late final Color _colorText = _lerp(a.colorText, b.colorText);
  @override
  Color get colorText => _colorText;

  late final Color _colorIcon = _lerp(a.colorIcon, b.colorIcon);
  @override
  Color get colorIcon => _colorIcon;

  late final Color _colorHoveredIcon = _lerp(
    a.colorHoveredIcon,
    b.colorHoveredIcon,
  );
  @override
  Color get colorHoveredIcon => _colorHoveredIcon;

  late final Color _colorSplashedIcon = _lerp(
    a.colorSplashedIcon,
    b.colorSplashedIcon,
  );
  @override
  Color get colorSplashedIcon => _colorSplashedIcon;

  late final Color _colorBorder = _lerp(a.colorBorder, b.colorBorder);
  @override
  Color get colorBorder => _colorBorder;

  late final Color _colorHovered = _lerp(a.colorHovered, b.colorHovered);
  @override
  Color get colorHovered => _colorHovered;

  late final Color _colorHoveredText = _lerp(
    a.colorHoveredText,
    b.colorHoveredText,
  );
  @override
  Color get colorHoveredText => _colorHoveredText;

  late final Color _colorHoveredBorder = _lerp(
    a.colorHoveredBorder,
    b.colorHoveredBorder,
  );
  @override
  Color get colorHoveredBorder => _colorHoveredBorder;

  late final Color _colorSplashed = _lerp(a.colorSplashed, b.colorSplashed);
  @override
  Color get colorSplashed => _colorSplashed;

  late final Color _colorSplashedText = _lerp(
    a.colorSplashedText,
    b.colorSplashedText,
  );
  @override
  Color get colorSplashedText => _colorSplashedText;

  late final Color _colorSplashedBorder = _lerp(
    a.colorSplashedBorder,
    b.colorSplashedBorder,
  );
  @override
  Color get colorSplashedBorder => _colorSplashedBorder;

  // Text standalone family
  late final Color _text = _lerp(a.text, b.text);
  @override
  Color get text => _text;

  late final Color _textHovered = _lerp(a.textHovered, b.textHovered);
  @override
  Color get textHovered => _textHovered;

  late final Color _textHoveredText = _lerp(
    a.textHoveredText,
    b.textHoveredText,
  );
  @override
  Color get textHoveredText => _textHoveredText;

  late final Color _textSplashed = _lerp(a.textSplashed, b.textSplashed);
  @override
  Color get textSplashed => _textSplashed;

  late final Color _textSplashedText = _lerp(
    a.textSplashedText,
    b.textSplashedText,
  );
  @override
  Color get textSplashedText => _textSplashedText;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaletteLerped &&
          runtimeType == other.runtimeType &&
          a == other.a &&
          b == other.b &&
          t == other.t &&
          interpolationStyle == other.interpolationStyle &&
          a.colorModel == other.a.colorModel;

  @override
  int get hashCode => Object.hash(runtimeType, a, b, t, interpolationStyle);
}
