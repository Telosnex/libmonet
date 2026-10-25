import 'package:libmonet/fonts/font_height_equalizer.g.dart';

/// Clearance between adjacent lines, as a fraction of the requested size.
///
/// The space between the lowest ink of one line and the highest ink of the
/// next. Taste: about 1.4 px at a 17 px label.
const kLineHeightClearance = 0.08;

/// Minimum baseline distance, as a fraction of the requested size.
const kLineHeightFloor = 1.0;

/// TextStyle.height for [fontFamily], or null for the natural line box.
///
/// The height fits the ink of the font's Latin letters, over every weight
/// and style. Other scripts can need more room: an app that shows them
/// turns this off ([MonetThemeData.compactLineHeights]). The height adds
/// [kLineHeightClearance], and is at least
/// [kLineHeightFloor]. Both are relative to the requested size: the font
/// size before [visualHeightScaleForFontFamily] scales it.
///
/// Null if the result is not less than the font's own line box, or the font
/// has no data. Thus a line height never increases.
///
/// See docs/design/ADR_font_line_height.md in telosnex.
double? lineHeightForFontFamily(String? fontFamily) {
  if (fontFamily == null) return null;
  final key = normalizeFontFamilyForFontMetrics(fontFamily);
  final need = kLetterNeedEmByFontFamily[key];
  final box = kMinLineBoxEmByFontFamily[key];
  if (need == null || box == null) return null;
  final scale = visualHeightScaleForFontFamily(fontFamily);
  final clearance = kLineHeightClearance / scale;
  final floor = kLineHeightFloor / scale;
  final height = need + clearance > floor ? need + clearance : floor;
  return height < box ? height : null;
}
