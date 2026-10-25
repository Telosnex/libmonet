import 'package:libmonet/fonts/font_height_equalizer.g.dart';

/// Clearance between adjacent lines, as a fraction of the requested size.
///
/// The space between the lowest ink of one line and the highest ink of the
/// next. Taste: about 1.4 px at a 17 px label.
const kLineHeightClearance = 0.08;

/// Minimum baseline distance, as a fraction of the requested size.
const kLineHeightFloor = 1.0;

/// TextStyle.height for [fontFamily], or null if the font has no data.
///
/// The height fits the ink of the font's Latin letters, over every weight
/// and style, plus [clearance]. It is at least [kLineHeightFloor]. Both are
/// fractions of the requested size: the font size before
/// [visualHeightScaleForFontFamily] scales it. Thus the same [clearance]
/// gives the same gap in pixels in every font.
///
/// The height can be more or less than the font's own line box. Other
/// scripts can need more room than Latin: an app that shows them turns this
/// off ([MonetThemeData.compactLineHeights]).
///
/// The extra space is split evenly above and below the line. The letters
/// are centred in it only if the font's ascent and descent are centred on
/// its Latin ink: see [patchFontLineMetrics].
///
/// See docs/design/ADR_font_line_height.md in telosnex.
double? lineHeightForFontFamily(
  String? fontFamily, {
  double clearance = kLineHeightClearance,
}) {
  final ink = latinInkForFontFamily(fontFamily);
  if (ink == null) return null;
  final scale = visualHeightScaleForFontFamily(fontFamily!);
  final fitted = ink.$1 + ink.$2 + clearance / scale;
  final floor = kLineHeightFloor / scale;
  return fitted > floor ? fitted : floor;
}

/// The font's own line box (hhea ascent + descent) in em, or null if the
/// font has no Latin ink data.
///
/// For a font whose bytes [patchFontLineMetrics] changed, this height keeps
/// the original line height. The letters are centred in it.
double? naturalLineHeightForFontFamily(String? fontFamily) {
  if (latinInkForFontFamily(fontFamily) == null) return null;
  final key = normalizeFontFamilyForFontMetrics(fontFamily!);
  final ascent = kAscentEmByFontFamily[key];
  final descent = kDescentEmByFontFamily[key];
  if (ascent == null || descent == null) return null;
  return ascent + descent;
}

/// How far the Latin letter ink of [fontFamily] reaches (above, below) the
/// baseline in em, over every weight and style. Null if it is unknown.
(double, double)? latinInkForFontFamily(String? fontFamily) {
  if (fontFamily == null) return null;
  final key = normalizeFontFamilyForFontMetrics(fontFamily);
  final above = kLatinInkAboveEmByFontFamily[key];
  final below = kLatinInkBelowEmByFontFamily[key];
  if (above == null || below == null) return null;
  return (above, below);
}
