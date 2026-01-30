import 'dart:ui';

import 'package:libmonet/libmonet.dart';

/// Interpolates between two [Palette] instances using perceptual HCT lerp.
///
/// **Performance note:** Each token access recomputes the HCT lerp.
/// For repeated access (e.g., in a build method), wrap with
/// [PaletteSnapshot.capture] to evaluate all tokens once:
///
/// ```dart
/// final snapshot = PaletteSnapshot.capture(PaletteLerped(a: a, b: b, t: t));
/// ```
///
/// Lives in this library to access the private constructor.
class PaletteLerped extends Palette {
  final Palette a;
  final Palette b;
  final double t;

  PaletteLerped({required this.a, required this.b, required this.t})
      // ignore: invalid_use_of_visible_for_testing_member
      : super.base(
          baseColor: a.color,
          baseBackground: a.background,
          contrast: 0.5,
          algo: Algo.apca,
        );

  Color _lerp(Color x, Color y) {
    if (t <= 0.0) return x;
    if (t >= 1.0) return y;
    final ha = Hct.fromColor(x);
    final hb = Hct.fromColor(y);
    double dh = hb.hue - ha.hue;
    if (dh > 180) dh -= 360;
    if (dh < -180) dh += 360;
    final hue = (ha.hue + dh * t) % 360.0;
    final chroma = ha.chroma + (hb.chroma - ha.chroma) * t;
    final tone = ha.tone + (hb.tone - ha.tone) * t;
    return Hct.from(hue, chroma, tone).color;
  }

  // Background family
  @override
  Color get background => _lerp(a.background, b.background);
  @override
  Color get backgroundText => _lerp(a.backgroundText, b.backgroundText);
  @override
  Color get backgroundFill => _lerp(a.backgroundFill, b.backgroundFill);
  @override
  Color get backgroundBorder => _lerp(a.backgroundBorder, b.backgroundBorder);
  @override
  Color get backgroundHovered => _lerp(a.backgroundHovered, b.backgroundHovered);
  @override
  Color get backgroundSplashed => _lerp(a.backgroundSplashed, b.backgroundSplashed);
  @override
  Color get backgroundHoveredFill => _lerp(a.backgroundHoveredFill, b.backgroundHoveredFill);
  @override
  Color get backgroundSplashedFill => _lerp(a.backgroundSplashedFill, b.backgroundSplashedFill);
  @override
  Color get backgroundHoveredText => _lerp(a.backgroundHoveredText, b.backgroundHoveredText);
  @override
  Color get backgroundSplashedText => _lerp(a.backgroundSplashedText, b.backgroundSplashedText);
  @override
  Color get backgroundHoveredBorder => _lerp(a.backgroundHoveredBorder, b.backgroundHoveredBorder);
  @override
  Color get backgroundSplashedBorder => _lerp(a.backgroundSplashedBorder, b.backgroundSplashedBorder);

  // Fill family
  @override
  Color get fill => _lerp(a.fill, b.fill);
  @override
  Color get fillBorder => _lerp(a.fillBorder, b.fillBorder);
  @override
  Color get fillHovered => _lerp(a.fillHovered, b.fillHovered);
  @override
  Color get fillSplashed => _lerp(a.fillSplashed, b.fillSplashed);
  @override
  Color get fillText => _lerp(a.fillText, b.fillText);
  @override
  Color get fillHoveredText => _lerp(a.fillHoveredText, b.fillHoveredText);
  @override
  Color get fillSplashedText => _lerp(a.fillSplashedText, b.fillSplashedText);
  @override
  Color get fillIcon => _lerp(a.fillIcon, b.fillIcon);
  @override
  Color get fillHoveredBorder => _lerp(a.fillHoveredBorder, b.fillHoveredBorder);
  @override
  Color get fillSplashedBorder => _lerp(a.fillSplashedBorder, b.fillSplashedBorder);

  // Color (ink) family
  @override
  Color get color => _lerp(a.color, b.color);
  @override
  Color get colorText => _lerp(a.colorText, b.colorText);
  @override
  Color get colorIcon => _lerp(a.colorIcon, b.colorIcon);
  @override
  Color get colorBorder => _lerp(a.colorBorder, b.colorBorder);
  @override
  Color get colorHovered => _lerp(a.colorHovered, b.colorHovered);
  @override
  Color get colorHoveredText => _lerp(a.colorHoveredText, b.colorHoveredText);
  @override
  Color get colorHoveredBorder => _lerp(a.colorHoveredBorder, b.colorHoveredBorder);
  @override
  Color get colorSplashed => _lerp(a.colorSplashed, b.colorSplashed);
  @override
  Color get colorSplashedText => _lerp(a.colorSplashedText, b.colorSplashedText);
  @override
  Color get colorSplashedBorder => _lerp(a.colorSplashedBorder, b.colorSplashedBorder);

  // Text standalone family
  @override
  Color get text => _lerp(a.text, b.text);
  @override
  Color get textHovered => _lerp(a.textHovered, b.textHovered);
  @override
  Color get textHoveredText => _lerp(a.textHoveredText, b.textHoveredText);
  @override
  Color get textSplashed => _lerp(a.textSplashed, b.textSplashed);
  @override
  Color get textSplashedText => _lerp(a.textSplashedText, b.textSplashedText);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaletteLerped &&
          runtimeType == other.runtimeType &&
          a == other.a &&
          b == other.b &&
          t == other.t;

  @override
  int get hashCode => Object.hash(runtimeType, a, b, t);
}