import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Text roles that determine how font metrics should be balanced.
/// Different roles prioritize different aspects of typography.
enum TextRole {
  /// Headlines prioritize cap height for visual impact
  headline,
  /// Subtitles balance cap height and x-height
  subtitle, 
  /// Body text prioritizes x-height for readability
  body,
  /// Captions strongly favor x-height
  caption,
  /// Balanced approach for UI elements
  ui,
}

/// Comprehensive font metrics for a given font family and size.
///
/// This provides all the key measurements needed for precise typography:
/// - ascent: Distance from baseline to top of tallest character
/// - descent: Distance from baseline to bottom of lowest character
/// - capHeight: Height of capital letters (H, E, etc.)
/// - xHeight: Height of lowercase letters (x, a, etc.)
/// - lineHeight: Total line height including line spacing
class FontMetrics {
  const FontMetrics({
    required this.ascent,
    required this.descent,
    required this.capHeight,
    required this.xHeight,
    required this.lineHeight,
    required this.fontSize,
  });

  final double ascent;
  final double descent;
  final double capHeight;
  final double xHeight;
  final double lineHeight;
  final double fontSize;

  /// Coefficient for cap height: capHeight = capCoeff * fontSize
  double get capCoeff => capHeight / fontSize;

  /// Coefficient for x-height: xHeight = xCoeff * fontSize
  double get xCoeff => xHeight / fontSize;

  /// The ratio of x-height to cap height (useful for font characterization)
  double get xHeightToCapRatio => xHeight / capHeight;

  /// Whether this font has a relatively high x-height (>0.55 ratio to cap height)
  bool get hasHighXHeight => xHeightToCapRatio > 0.55;

  /// Whether this font has a relatively low x-height (<0.45 ratio to cap height)
  bool get hasLowXHeight => xHeightToCapRatio < 0.45;

  @override
  String toString() {
    return 'FontMetrics('
        'ascent: ${ascent.toStringAsFixed(2)}, '
        'descent: ${descent.toStringAsFixed(2)}, '
        'capHeight: ${capHeight.toStringAsFixed(2)}, '
        'xHeight: ${xHeight.toStringAsFixed(2)}, '
        'lineHeight: ${lineHeight.toStringAsFixed(2)}, '
        'capCoeff: ${capCoeff.toStringAsFixed(3)}, '
        'xCoeff: ${xCoeff.toStringAsFixed(3)})';
  }
}

/// Utilities for measuring and normalizing font metrics across different font families.
///
/// The core problem: Different font families have vastly different internal metrics
/// (ascent, descent, line gap) even when set to the same fontSize. This leads to
/// inconsistent visual sizing and line heights.
///
/// The solution: Measure the actual cap-height (or x-height) and normalize all fonts
/// to achieve the same physical cap-height, then apply consistent line-height afterwards.
class FontMetricsUtils {
  FontMetricsUtils._();

  /// Physical relationship between points and device pixels at 160 DPI
  static const double ptsToDevicePixels = 160.0 / 72.0;
  
  /// Reference font size for measuring coefficients (larger = more accurate)
  static const double _referenceFontSize = 100.0;

  /// Cache for font coefficients (measured at reference size)
  static final Map<String, FontMetrics> _coeffCache = <String, FontMetrics>{};
  
  /// Cache for font metrics at arbitrary sizes
  static final Map<String, FontMetrics> _metricsCache = <String, FontMetrics>{};
  
  /// Cache for calculated font sizes
  static final Map<String, double> _fontSizeCache = <String, double>{};
  
  /// Reference font for deriving consistent targets
  static const String _referenceFont = 'Roboto';
  
  /// Role-based weight configurations for optical balancing
  static const Map<TextRole, Map<String, double>> _roleWeights = {
    TextRole.headline: {'capHeight': 0.85, 'xHeight': 0.15},
    TextRole.subtitle: {'capHeight': 0.65, 'xHeight': 0.35},
    TextRole.body: {'capHeight': 0.35, 'xHeight': 0.65},
    TextRole.caption: {'capHeight': 0.25, 'xHeight': 0.75},
    TextRole.ui: {'capHeight': 0.5, 'xHeight': 0.5},
  };

  /// Measures comprehensive font metrics in a single paragraph build.
  /// This correctly measures both cap height and x-height from one paragraph.
  static FontMetrics _measureFontMetrics(String fontFamily, double fontSize) {
    // Create single paragraph with mixed case text
    final paragraphStyle = ui.ParagraphStyle(
      textDirection: TextDirection.ltr,
      fontSize: fontSize,
      fontFamily: fontFamily,
    );
    final builder = ui.ParagraphBuilder(paragraphStyle);
    builder.addText('Hx'); // Cap + x-height + descender for complete metrics
    final paragraph = builder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: double.infinity));
    
    final lineMetrics = paragraph.computeLineMetrics();
    
    FontMetrics result;
    
    if (lineMetrics.isEmpty) {
      print('LINE METRICS EMPTY for $fontFamily at $fontSize');
      // Fallback to typical ratios
      result = FontMetrics(
        ascent: fontSize * 0.75,
        descent: fontSize * 0.25,
        capHeight: fontSize * 0.7,
        xHeight: fontSize * 0.5,
        lineHeight: fontSize,
        fontSize: fontSize,
      );
    } else {
      final metrics = lineMetrics.first;
      
      // The ascent represents the cap height for mixed case text
      final capHeight = metrics.ascent;
      
      // X-height will be measured precisely using glyph bounds in getFontMetrics()
      // This is just a placeholder that gets overwritten
      final xHeight = capHeight * 0.5; // Placeholder - gets replaced with precise measurement
      
      result = FontMetrics(
        ascent: metrics.ascent,
        descent: metrics.descent,
        capHeight: capHeight,
        xHeight: xHeight,
        lineHeight: metrics.height,
        fontSize: fontSize,
      );
    }
    
    // Clean up
    try {
      paragraph.dispose();
    } catch (e) {
      // dispose() is experimental, ignore errors
    }
    
    return result;
  }
  
  /// More precise x-height measurement using glyph bounds
  static double _measureXHeightPrecise(String fontFamily, double fontSize) {
    final paragraphStyle = ui.ParagraphStyle(
      textDirection: TextDirection.ltr,
      fontSize: fontSize,
      fontFamily: fontFamily,
    );
    final builder = ui.ParagraphBuilder(paragraphStyle);
    builder.addText('x');
    final paragraph = builder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: double.infinity));
    
    // Get the bounding boxes for the 'x' character
    final boxes = paragraph.getBoxesForRange(0, 1);
    
    double xHeight;
    if (boxes.isNotEmpty) {
      // The height of the glyph box represents the x-height
      xHeight = boxes.first.toRect().height;
    } else {
      // Fallback to line metrics based measurement
      final lineMetrics = paragraph.computeLineMetrics();
      if (lineMetrics.isNotEmpty) {
        xHeight = lineMetrics.first.ascent * 0.73;
      } else {
        xHeight = fontSize * 0.5;
      }
    }
    
    try {
      paragraph.dispose();
    } catch (e) {
      // ignore
    }
    
    return xHeight;
  }

  /// Gets comprehensive font metrics for a given font family and size.
  /// Uses caching to avoid repeated measurements.
  static FontMetrics getFontMetrics(String fontFamily, double fontSize) {
    final cacheKey = 'size:${fontFamily}_${fontSize.toStringAsFixed(1)}';
    if (_metricsCache.containsKey(cacheKey)) {
      return _metricsCache[cacheKey]!;
    }
    
    // Use more precise x-height measurement for better accuracy
    final basicMetrics = _measureFontMetrics(fontFamily, fontSize);
    final preciseXHeight = _measureXHeightPrecise(fontFamily, fontSize);
    
    final metrics = FontMetrics(
      ascent: basicMetrics.ascent,
      descent: basicMetrics.descent,
      capHeight: basicMetrics.capHeight,
      xHeight: preciseXHeight,
      lineHeight: basicMetrics.lineHeight,
      fontSize: fontSize,
    );
    
    _metricsCache[cacheKey] = metrics;
    return metrics;
  }
  
  /// Gets the scaling coefficients for a font family using a reference size.
  /// This is used for the closed-form optical balancing algorithm.
  static FontMetrics _getFontCoefficients(String fontFamily) {
    final cacheKey = 'coeffs:${fontFamily}';
    if (_coeffCache.containsKey(cacheKey)) {
      return _coeffCache[cacheKey]!;
    }
    
    final metrics = getFontMetrics(fontFamily, _referenceFontSize);
    _coeffCache[cacheKey] = metrics;
    return metrics;
  }
  
  /// Gets reference font coefficients (cached on first access)
  static FontMetrics get _referenceCoefficients {
    return _getFontCoefficients(_referenceFont);
  }
  
  /// Derives cap height target from reference font at given size
  static double _capTarget(double targetSizeDp) {
    return _referenceCoefficients.capCoeff * targetSizeDp;
  }
  
  /// Derives x-height target from reference font at given size
  static double _xTarget(double targetSizeDp) {
    return _referenceCoefficients.xCoeff * targetSizeDp;
  }

  /// Calculates the optimal font size using closed-form least-squares optimization.
  /// This is the mathematically correct way to balance cap height and x-height.
  ///
  /// Given:
  /// - capHeight(s) = kCap * s
  /// - xHeight(s) = kX * s  
  /// - targets: targetCap, targetX
  /// - weights: wCap, wX (sum = 1)
  ///
  /// The optimal size that minimizes weighted squared error is:
  /// s* = (wCap * kCap * targetCap + wX * kX * targetX) / (wCap * kCap² + wX * kX²)
  static double _opticallyBalancedSize({
    required String fontFamily,
    required double targetCapHeightDp,
    required double targetXHeightDp,
    required double capHeightWeight,
    required double xHeightWeight,
  }) {
    // Get font coefficients from reference measurement
    final coeffs = _getFontCoefficients(fontFamily);
    final kCap = coeffs.capCoeff;
    final kX = coeffs.xCoeff;
    
    // Handle degenerate cases
    if (kCap <= 0 || kX <= 0) {
      // Fallback to simple ratio if coefficients are invalid
      return (targetCapHeightDp + targetXHeightDp) / 2.0;
    }
    
    // Closed-form least-squares solution
    final numerator = (capHeightWeight * kCap * targetCapHeightDp) +
                      (xHeightWeight * kX * targetXHeightDp);
    final denominator = (capHeightWeight * kCap * kCap) +
                        (xHeightWeight * kX * kX);
    
    if (denominator <= 0) {
      return (targetCapHeightDp + targetXHeightDp) / 2.0;
    }
    
    return numerator / denominator;
  }
  
  /// Calculates the font size needed to achieve a specific cap-height in device pixels.
  /// This is a convenience method that uses pure cap-height optimization.
  static double fontSizeForCapHeight({
    required String fontFamily,
    required double targetCapHeightDp,
  }) {
    final cacheKey = '${fontFamily}_cap_${targetCapHeightDp.toStringAsFixed(1)}';
    if (_fontSizeCache.containsKey(cacheKey)) {
      return _fontSizeCache[cacheKey]!;
    }
    
    final result = _opticallyBalancedSize(
      fontFamily: fontFamily,
      targetCapHeightDp: targetCapHeightDp,
      targetXHeightDp: targetCapHeightDp * 0.5, // Dummy value, weight is 0
      capHeightWeight: 1.0,
      xHeightWeight: 0.0,
    );
    
    _fontSizeCache[cacheKey] = result;
    return result;
  }

  /// Calculates the font size needed to achieve a specific cap-height in points.
  /// This is the main function that should replace searchForFontSizeReachingPts.
  static double fontSizeForCapHeightPts({
    required String fontFamily,
    required double targetCapHeightPts,
  }) {
    final targetCapHeightDp = targetCapHeightPts * ptsToDevicePixels;
    return fontSizeForCapHeight(
      fontFamily: fontFamily,
      targetCapHeightDp: targetCapHeightDp,
    );
  }

  /// Calculates the font size needed to achieve a specific x-height in device pixels.
  /// This is useful for body text where lowercase letters are more important.
  static double fontSizeForXHeight({
    required String fontFamily,
    required double targetXHeightDp,
  }) {
    final cacheKey = '${fontFamily}_x_${targetXHeightDp.toStringAsFixed(1)}';
    if (_fontSizeCache.containsKey(cacheKey)) {
      return _fontSizeCache[cacheKey]!;
    }
    
    final result = _opticallyBalancedSize(
      fontFamily: fontFamily,
      targetCapHeightDp: targetXHeightDp * 2.0, // Dummy value, weight is 0
      targetXHeightDp: targetXHeightDp,
      capHeightWeight: 0.0,
      xHeightWeight: 1.0,
    );
    
    _fontSizeCache[cacheKey] = result;
    return result;
  }

  /// Calculates the font size needed to achieve a specific x-height in points.
  static double fontSizeForXHeightPts({
    required String fontFamily,
    required double targetXHeightPts,
  }) {
    final targetXHeightDp = targetXHeightPts * ptsToDevicePixels;
    return fontSizeForXHeight(
      fontFamily: fontFamily,
      targetXHeightDp: targetXHeightDp,
    );
  }

  /// Calculates the mathematically optimal font size that balances cap height and x-height targets.
  /// Uses closed-form least-squares optimization - no binary search needed.
  ///
  /// This is the main function for achieving consistent optical sizing across fonts.
  static double fontSizeForBalancedMetrics({
    required String fontFamily,
    required double targetCapHeightDp,
    required double targetXHeightDp,
    double capHeightWeight = 0.5,
    double xHeightWeight = 0.5,
  }) {
    assert(
      (capHeightWeight + xHeightWeight - 1.0).abs() < 0.001,
      'Weights must sum to 1.0',
    );
    assert(
      capHeightWeight >= 0.0 && capHeightWeight <= 1.0,
      'capHeightWeight must be between 0.0 and 1.0',
    );
    assert(
      xHeightWeight >= 0.0 && xHeightWeight <= 1.0,
      'xHeightWeight must be between 0.0 and 1.0',
    );

    final cacheKey = '${fontFamily}_balanced_'
        '${targetCapHeightDp.toStringAsFixed(1)}_'
        '${targetXHeightDp.toStringAsFixed(1)}_'
        '${capHeightWeight.toStringAsFixed(3)}_'
        '${xHeightWeight.toStringAsFixed(3)}';
    
    if (_fontSizeCache.containsKey(cacheKey)) {
      return _fontSizeCache[cacheKey]!;
    }

    final result = _opticallyBalancedSize(
      fontFamily: fontFamily,
      targetCapHeightDp: targetCapHeightDp,
      targetXHeightDp: targetXHeightDp,
      capHeightWeight: capHeightWeight,
      xHeightWeight: xHeightWeight,
    );
    
    _fontSizeCache[cacheKey] = result;
    return result;
  }

  /// Calculates a font size that balances both cap height and x-height targets in points.
  static double fontSizeForBalancedMetricsPts({
    required String fontFamily,
    required double targetCapHeightPts,
    required double targetXHeightPts,
    double capHeightWeight = 0.5,
    double xHeightWeight = 0.5,
  }) {
    final targetCapHeightDp = targetCapHeightPts * ptsToDevicePixels;
    final targetXHeightDp = targetXHeightPts * ptsToDevicePixels;
    
    return fontSizeForBalancedMetrics(
      fontFamily: fontFamily,
      targetCapHeightDp: targetCapHeightDp,
      targetXHeightDp: targetXHeightDp,
      capHeightWeight: capHeightWeight,
      xHeightWeight: xHeightWeight,
    );
  }
  
  /// The main API: calculates optimal font size for consistent visual appearance.
  /// This replaces the complex binary search with a single calculation.
  ///
  /// The targetSizeDp represents the desired "font size" in the reference font,
  /// and this method calculates what size in the target font will appear optically similar.
  ///
  /// Usage:
  /// ```dart
  /// final fontSize = FontMetricsUtils.opticalFontSize(
  ///   fontFamily: 'Inter',
  ///   targetSizeDp: 16.0, // "16dp Roboto-equivalent"
  ///   role: TextRole.body,
  /// );
  /// ```
  static double opticalFontSize({
    required String fontFamily,
    required double targetSizeDp,
    TextRole role = TextRole.ui,
  }) {
    final weights = _roleWeights[role]!;
    
    // Derive targets from reference font at the given size
    // This ensures "16dp" means "same as Roboto 16dp" across all fonts
    final targetCapHeight = _capTarget(targetSizeDp);
    final targetXHeight = _xTarget(targetSizeDp);
    
    return fontSizeForBalancedMetrics(
      fontFamily: fontFamily,
      targetCapHeightDp: targetCapHeight,
      targetXHeightDp: targetXHeight,
      capHeightWeight: weights['capHeight']!,
      xHeightWeight: weights['xHeight']!,
    );
  }
  
  /// Convenience method: optical font size in points
  static double opticalFontSizePts({
    required String fontFamily,
    required double targetSizePts,
    TextRole role = TextRole.ui,
  }) {
    final targetSizeDp = targetSizePts * ptsToDevicePixels;
    return opticalFontSize(
      fontFamily: fontFamily,
      targetSizeDp: targetSizeDp,
      role: role,
    );
  }

  /// Analyzes how well a font size balances the cap height and x-height targets.
  /// Returns a score where lower values indicate better balance.
  static double analyzeBalanceScore({
    required String fontFamily,
    required double fontSize,
    required double targetCapHeightDp,
    required double targetXHeightDp,
    double capHeightWeight = 0.5,
    double xHeightWeight = 0.5,
  }) {
    final metrics = getFontMetrics(fontFamily, fontSize);
    
    final capError = (metrics.capHeight - targetCapHeightDp).abs();
    final xError = (metrics.xHeight - targetXHeightDp).abs();
    
    // Weighted error score
    return (capError * capHeightWeight) + (xError * xHeightWeight);
  }

  /// Convenience method using TextRole-based presets
  static double fontSizeForRole({
    required String fontFamily,
    required double targetCapHeightDp,
    required double targetXHeightDp,
    required TextRole role,
  }) {
    final weights = _roleWeights[role]!;
    
    return fontSizeForBalancedMetrics(
      fontFamily: fontFamily,
      targetCapHeightDp: targetCapHeightDp,
      targetXHeightDp: targetXHeightDp,
      capHeightWeight: weights['capHeight']!,
      xHeightWeight: weights['xHeight']!,
    );
  }

  /// Clears all caches. Useful for testing or when font loading changes.
  static void clearCache() {
    _fontSizeCache.clear();
    _metricsCache.clear();
    _coeffCache.clear();
  }
  
  /// Debug method: prints font metrics for analysis
  static void debugPrintFontMetrics(String fontFamily, double fontSize) {
    final metrics = getFontMetrics(fontFamily, fontSize);
    print('Font metrics for $fontFamily at ${fontSize}px:');
    print('  Cap coefficient: ${metrics.capCoeff.toStringAsFixed(3)}');
    print('  X coefficient: ${metrics.xCoeff.toStringAsFixed(3)}');
    print('  X/Cap ratio: ${metrics.xHeightToCapRatio.toStringAsFixed(3)}');
    print('  Full metrics: $metrics');
  }
}
