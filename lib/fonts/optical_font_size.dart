import 'package:flutter/painting.dart' show TextStyle;
import 'package:monet_ui/fonts/font_height_equalizer.g.dart';

/// Font size at which [fontFamily] looks as large as [referenceFontFamily]
/// does at [referenceFontSize].
///
/// Uses the same visual-height metric as the text-theme role equalizer
/// ([visualHeightScaleForFontFamily]), so it composes with it: when the
/// reference style was already equalized by libmonet, the result depends only
/// on [fontFamily], not on which font the reference role happens to use.
///
/// Typical uses:
/// - Monospace standing in for a role (pass that role's size and family).
/// - Inline code matching the prose, heading, or table cell around it.
///
/// Families missing from the table are treated as the reference font
/// (scale 1.0), the same fallback the role equalizer uses.
double opticallyMatchedFontSize({
  required double referenceFontSize,
  required String? referenceFontFamily,
  required String? fontFamily,
}) {
  return referenceFontSize /
      visualHeightScaleForFontFamily(referenceFontFamily) *
      visualHeightScaleForFontFamily(fontFamily);
}

/// The font size of [style] before libmonet's size equalizer scaled it.
///
/// createTextTheme multiplies each role's size by
/// [visualHeightScaleForFontFamily], so that letters look the same size in
/// every font. Thus the letter ink is proportional to this size, not to
/// [TextStyle.fontSize]. Size things that sit next to text by it, so they
/// match the letters in every font.
double requestedFontSize(TextStyle style) =>
    style.fontSize! / visualHeightScaleForFontFamily(style.fontFamily);

/// Icon size that matches the letters of [style] in every font: the
/// [requestedFontSize] of [style].
double iconSizeFor(TextStyle style) => requestedFontSize(style);
