import 'dart:math' as math;
import 'dart:ui';

import 'package:libmonet/apca_contrast.dart';
import 'package:libmonet/contrast.dart';
import 'package:libmonet/hct.dart';
import 'package:libmonet/wcag.dart';

class SafeColors {
  // Core parameters
  final Color _baseColor;
  final Color _baseBackground;
  final double _backgroundTone;
  final double _contrast;
  final Algo _algo;

  // Cache for lazy-computed values
  final Map<String, Color> _cache = {};

  // Constructor now only takes core parameters needed for calculations
  SafeColors._(
      {required Color baseColor,
      required Color baseBackground,
      double? backgroundTone,
      required double contrast,
      required Algo algo})
      : _baseColor = baseColor,
        _baseBackground = baseBackground,
        _backgroundTone = backgroundTone ?? Hct.fromColor(baseBackground).tone,
        _contrast = contrast,
        _algo = algo;

  // Getters with lazy computation
  Color get background => _computeOrGet('background', _computeBackground);
  Color get backgroundText =>
      _computeOrGet('backgroundText', _computeBackgroundText);
  Color get backgroundFill =>
      _computeOrGet('backgroundFill', _computeBackgroundFill);
  Color get backgroundBorder =>
      _computeOrGet('backgroundBorder', _computeBackgroundBorder);

  Color get color => _baseColor;
  Color get colorHover => _computeOrGet('colorHover', _computeColorHover);
  Color get colorSplash => _computeOrGet('colorSplash', _computeColorSplash);

  Color get colorText => _computeOrGet('colorText', _computeColorText);
  Color get colorHoverText =>
      _computeOrGet('colorHoverText', _computeColorHoverText);
  Color get colorSplashText =>
      _computeOrGet('colorSplashText', _computeColorSplashText);

  Color get colorIcon => _computeOrGet('colorIcon', _computeColorIcon);
  Color get colorBorder => _computeOrGet('colorBorder', _computeColorBorder);

  Color get fill => _computeOrGet('fill', _computeFill);
  Color get fillHover => _computeOrGet('fillHover', _computeFillHover);
  Color get fillSplash => _computeOrGet('fillSplash', _computeFillSplash);

  Color get fillText => _computeOrGet('fillText', _computeFillText);
  Color get fillHoverText =>
      _computeOrGet('fillHoverText', _computeFillHoverText);
  Color get fillSplashText =>
      _computeOrGet('fillSplashText', _computeFillSplashText);

  Color get fillIcon => _computeOrGet('fillIcon', _computeFillIcon);

  Color get text => _computeOrGet('text', _computeText);
  Color get textHover => _computeOrGet('textHover', _computeTextHover);
  Color get textHoverText =>
      _computeOrGet('textHoverText', _computeTextHoverText);
  Color get textSplash => _computeOrGet('textSplash', _computeTextSplash);
  Color get textSplashText =>
      _computeOrGet('textSplashText', _computeTextSplashText);

  // Helper method for lazy computation with caching
  Color _computeOrGet(String key, Color Function() compute) {
    if (!_cache.containsKey(key)) {
      _cache[key] = compute();
    }
    return _cache[key]!;
  }

  /// Helper method to check if a tone has sufficient contrast with either
  /// background or color. This is crucial because APCA methods can return tones
  /// that don't actually meet the requested contrast (e.g., returning T100 when
  /// T130 is the only way to have sufficient contrast with a lighter color).
  ///
  /// We check all four possible contrast combinations:
  /// 1. background as bg, tone as fg
  /// 2. color as bg, tone as fg
  /// 3. tone as bg, background as fg
  /// 4. tone as bg, color as fg
  bool _hasValidContrastHelper({
    required double tone,
    required double backgroundTone,
    required double colorTone,
    required double requiredContrast,
  }) {
    // Calculate contrast: background as bg, tone as fg
    final backgroundBgToneFgContrast = _algo.getContrastBetweenLstars(
      bg: backgroundTone,
      fg: tone,
    );

    // Calculate contrast: color as bg, tone as fg
    final colorBgToneFgContrast = _algo.getContrastBetweenLstars(
      bg: colorTone,
      fg: tone,
    );

    // Calculate contrast: tone as bg, background as fg
    final toneBgBackgroundFgContrast = _algo.getContrastBetweenLstars(
      bg: tone,
      fg: backgroundTone,
    );

    // Calculate contrast: tone as bg, color as fg
    final toneBgColorFgContrast = _algo.getContrastBetweenLstars(
      bg: tone,
      fg: colorTone,
    );

    // Check if any of the four contrasts meet the required threshold
    // For APCA, contrast can be negative (polarity), so we need absolute value
    // For WCAG, contrast is always positive
    final isValid = (_algo == Algo.apca)
        ? (backgroundBgToneFgContrast.abs() >= requiredContrast ||
            colorBgToneFgContrast.abs() >= requiredContrast ||
            toneBgBackgroundFgContrast.abs() >= requiredContrast ||
            toneBgColorFgContrast.abs() >= requiredContrast)
        : (backgroundBgToneFgContrast >= requiredContrast ||
            colorBgToneFgContrast >= requiredContrast ||
            toneBgBackgroundFgContrast >= requiredContrast ||
            toneBgColorFgContrast >= requiredContrast);

    // Uncomment for debugging:
    // print('  T${tone.round()}: '
    //       'bg→tone: ${backgroundBgToneFgContrast.toStringAsFixed(2)}, '
    //       'color→tone: ${colorBgToneFgContrast.toStringAsFixed(2)}, '
    //       'tone→bg: ${toneBgBackgroundFgContrast.toStringAsFixed(2)}, '
    //       'tone→color: ${toneBgColorFgContrast.toStringAsFixed(2)} '
    //       '(need ${requiredContrast.toStringAsFixed(2)}) => ${isValid ? "VALID" : "invalid"}');

    return isValid;
  }

  /// Use for colorful backgrounds: [SafeColors.from] reduces the chroma of the
  /// background color to 16.
  factory SafeColors.fromColorAndBackground(
    Color color,
    Color background, {
    double contrast = 0.5,
    Algo algo = Algo.apca,
  }) {
    return SafeColors._(
      baseColor: color,
      baseBackground: background,
      contrast: contrast,
      algo: algo,
    );
  }

  factory SafeColors.from(
    Color color, {
    required double backgroundTone,
    double contrast = 0.5,
    Algo algo = Algo.apca,
  }) {
    // Create a background color with the specified tone
    final colorHct = Hct.fromColor(color);
    final backgroundHct =
        Hct.from(colorHct.hue, math.min(16, colorHct.chroma), backgroundTone);

    return SafeColors._(
      baseColor: color,
      baseBackground: backgroundHct.color,
      backgroundTone: backgroundTone,
      contrast: contrast,
      algo: algo,
    );
  }

  // Computation methods for all color properties
  Color _computeBackground() => _baseBackground;

  Color _computeBackgroundText() {
    final backgroundHct = Hct.fromColor(_baseBackground);
    final backgroundTextTone = contrastingLstar(
      withLstar: _backgroundTone,
      usage: Usage.text,
      by: _algo,
      contrast: _contrast,
    );
    return Hct.colorFrom(
        backgroundHct.hue, backgroundHct.chroma, backgroundTextTone);
  }

  Color _computeBackgroundFill() {
    final backgroundHct = Hct.fromColor(_baseBackground);
    final backgroundFillTone = contrastingLstar(
      withLstar: _backgroundTone,
      usage: Usage.fill,
      by: _algo,
      contrast: _contrast,
    );
    return Hct.colorFrom(
        backgroundHct.hue, backgroundHct.chroma, backgroundFillTone);
  }

  Color _computeBackgroundBorder() {
    final backgroundHct = Hct.fromColor(_baseBackground);
    final backgroundBorderTone = contrastingLstar(
      withLstar: _backgroundTone,
      usage: Usage.large,
      by: _algo,
      contrast: _contrast,
    );
    return Hct.colorFrom(
        backgroundHct.hue, backgroundHct.chroma, backgroundBorderTone);
  }

  Color _computeColorBorder() {
    void debugLog(String Function() message) {
      // ignore: dead_code
      if (false) {
        // ignore: avoid_print
        print(message());
      }
    }

    final colorHct = Hct.fromColor(_baseColor);
    final colorTone = colorHct.tone;
    final backgroundTone = _backgroundTone;

    // First check if the color already has sufficient contrast with background
    final colorBgContrast = _algo.getContrastBetweenLstars(
      bg: backgroundTone,
      fg: colorTone,
    );
    final requiredContrast = _algo.getAbsoluteContrast(_contrast, Usage.large);

    // If color already has enough contrast with background, use it as the border
    if (colorBgContrast >= requiredContrast) {
      return _baseColor;
    }

    // Calculate total delta for a given tone
    double calculateTotalDelta(double tone) {
      return (tone - colorTone).abs() + (tone - backgroundTone).abs();
    }

    // Check if a tone has sufficient contrast with either background or color
    // This is strictly necessary because the APCA methods will return a tone
    // value even when they cannot meet the contrat requested, i.e. if contrast
    // required a T130, the APCA methods will return T100.
    bool hasValidContrast(double tone) {
      return _hasValidContrastHelper(
        tone: tone,
        backgroundTone: backgroundTone,
        colorTone: colorTone,
        requiredContrast: requiredContrast,
      );
    }

    // Candidate tones to consider (use Set to avoid duplicates)
    Set<double> candidateSet = {};

    // We need to find tones that contrast WITH the background/color,
    // not tones that would work AS TEXT ON the background/color.
    // So we need to think of background/color as the "text" and find "background" tones.

    // For tones that contrast with the background:
    // Use APCA contrast value for APCA (negative for lighter text)
    final bgLighterTone = (_algo == Algo.apca)
        ? lighterTextLstar(backgroundTone, -requiredContrast)
        : lighterLstarUnsafe(
            lstar: backgroundTone, contrastRatio: requiredContrast);
    final bgDarkerTone = (_algo == Algo.apca)
        ? darkerTextLstar(backgroundTone, requiredContrast)
        : darkerLstarUnsafe(
            lstar: backgroundTone, contrastRatio: requiredContrast);

    if (bgLighterTone <= 100) {
      candidateSet.add(bgLighterTone.clamp(0, 100));
    }
    if (bgDarkerTone >= 0) {
      candidateSet.add(bgDarkerTone.clamp(0, 100));
    }

    // For tones that contrast with the color:
    final colorLighterTone = (_algo == Algo.apca)
        ? lighterTextLstar(colorTone, -requiredContrast)
        : lighterLstarUnsafe(lstar: colorTone, contrastRatio: requiredContrast);
    final colorDarkerTone = (_algo == Algo.apca)
        ? darkerTextLstar(colorTone, requiredContrast)
        : darkerLstarUnsafe(lstar: colorTone, contrastRatio: requiredContrast);

    if (colorLighterTone <= 100) {
      candidateSet.add(colorLighterTone.clamp(0, 100));
    }
    if (colorDarkerTone >= 0) {
      candidateSet.add(colorDarkerTone.clamp(0, 100));
    }

    final candidateTones = candidateSet.toList();

    // Filter candidates that have sufficient contrast with either background or color
    final validCandidates = candidateTones.where(hasValidContrast).toList();

    // rationale: leaving in debug prints because logic is new, and crucial to
    // effects like glow and contrast on dynamic backgrounds.
    debugLog(() =>
        'Color tone: ${colorTone.round()} bg tone: ${backgroundTone.round()}');
    debugLog(() =>
        'Background contrasts with lighter T${bgLighterTone.round()}, darker T${bgDarkerTone.round()}');
    debugLog(() =>
        'Color contrasts with lighter T${colorLighterTone.round()}, darker T${colorDarkerTone.round()}');
    debugLog(() => 'All candidates: ${candidateTones.map((t) => t.round())}');
    debugLog(
        () => 'Valid candidates: ${validCandidates.map((t) => t.round())}');

    // If no valid candidates, fall back to pure black or white
    if (validCandidates.isEmpty) {
      // Choose black or white based on which has better contrast with both.
      // This works as you'd expect because in practice, there's 0 valid
      // candidates when contrast is at a max.
      final blackDelta = calculateTotalDelta(0);
      final whiteDelta = calculateTotalDelta(100);
      debugLog(() =>
          'No valid candidates found. Using black (0) with delta $blackDelta, white (100) with delta $whiteDelta');
      return Hct.colorFrom(
          colorHct.hue, colorHct.chroma, blackDelta > whiteDelta ? 0 : 100);
    }

    final colorPrefersLighter = lstarPrefersLighterPair(colorTone);
    if (colorPrefersLighter) {
      final lighterCandidates =
          validCandidates.where((tone) => tone > colorTone).toList();
      if (lighterCandidates.isNotEmpty) {
        debugLog(() =>
            'Lighter candidates: ${lighterCandidates.map((t) => t.round())}');
        // Find the candidate with minimal total delta
        double bestTone = lighterCandidates.first;
        double minDelta = calculateTotalDelta(bestTone);
        for (final tone in lighterCandidates) {
          final delta = calculateTotalDelta(tone);
          debugLog(() => 'Tone ${tone.round()}: delta = ${delta.round()}');
          if (delta < minDelta) {
            minDelta = delta;
            bestTone = tone;
          }
        }
        debugLog(() =>
            'Final best tone: ${bestTone.round()} with delta ${minDelta.round()}');
        return Hct.colorFrom(colorHct.hue, colorHct.chroma, bestTone);
      }
    } else {
      final darkerCandidates =
          validCandidates.where((tone) => tone < colorTone).toList();
      if (darkerCandidates.isNotEmpty) {
        debugLog(() =>
            'Darker candidates: ${darkerCandidates.map((t) => t.round())}');
        // Find the candidate with minimal total delta
        double bestTone = darkerCandidates.first;
        double minDelta = calculateTotalDelta(bestTone);
        for (final tone in darkerCandidates) {
          final delta = calculateTotalDelta(tone);
          debugLog(() => 'Tone ${tone.round()}: delta = ${delta.round()}');
          if (delta < minDelta) {
            minDelta = delta;
            bestTone = tone;
          }
        }
        debugLog(() =>
            'Final best tone: ${bestTone.round()} with delta ${minDelta.round()}');
        return Hct.colorFrom(colorHct.hue, colorHct.chroma, bestTone);
      }
    }

    // Find the candidate with minimal total delta
    double bestTone = validCandidates.first;
    double minDelta = calculateTotalDelta(bestTone);

    for (final tone in validCandidates) {
      final delta = calculateTotalDelta(tone);
      debugLog(() => 'Tone ${tone.round()}: delta = ${delta.round()}');
      if (delta < minDelta) {
        minDelta = delta;
        bestTone = tone;
      }
    }
    debugLog(() =>
        'Final best tone: ${bestTone.round()} with delta ${minDelta.round()}');

    return Hct.colorFrom(colorHct.hue, colorHct.chroma, bestTone);
  }

  Color _computeColorText() {
    final colorHct = Hct.fromColor(_baseColor);
    final colorTextTone = contrastingLstar(
      withLstar: colorHct.tone,
      usage: Usage.text,
      by: _algo,
      contrast: _contrast,
    );
    return Hct.colorFrom(colorHct.hue, colorHct.chroma, colorTextTone);
  }

  Color _computeColorIcon() {
    final colorHct = Hct.fromColor(_baseColor);
    final colorIconTone = contrastingLstar(
      withLstar: colorHct.tone,
      usage: Usage.fill,
      by: _algo,
      contrast: _contrast,
    );
    return Hct.colorFrom(colorHct.hue, colorHct.chroma, colorIconTone);
  }

  Color _computeColorHover() {
    final colorHct = Hct.fromColor(_baseColor);
    final hoverContrast = math.max(_contrast - 0.3, 0.1);
    final colorHoverTone = contrastingLstar(
      withLstar: colorHct.tone,
      usage: Usage.fill,
      by: _algo,
      contrast: hoverContrast,
    );
    return Hct.colorFrom(colorHct.hue, colorHct.chroma, colorHoverTone);
  }

  Color _computeColorSplash() {
    final colorHct = Hct.fromColor(_baseColor);
    final splashContrast = math.max(_contrast - 0.15, 0.25);
    final colorSplashTone = contrastingLstar(
      withLstar: colorHct.tone,
      usage: Usage.fill,
      by: _algo,
      contrast: splashContrast,
    );
    return Hct.colorFrom(colorHct.hue, colorHct.chroma, colorSplashTone);
  }

  Color _computeColorHoverText() {
    final colorHoverTone = Hct.fromColor(colorHover).tone;
    final colorHoverTextTone = contrastingLstar(
      withLstar: colorHoverTone,
      usage: Usage.text,
      by: _algo,
      contrast: _contrast,
    );
    final colorHct = Hct.fromColor(_baseColor);
    return Hct.colorFrom(colorHct.hue, colorHct.chroma, colorHoverTextTone);
  }

  Color _computeColorSplashText() {
    final colorSplashTone = Hct.fromColor(colorSplash).tone;
    final colorSplashTextTone = contrastingLstar(
      withLstar: colorSplashTone,
      usage: Usage.text,
      by: _algo,
      contrast: _contrast,
    );
    final colorHct = Hct.fromColor(_baseColor);
    return Hct.colorFrom(colorHct.hue, colorHct.chroma, colorSplashTextTone);
  }

  Color _computeFill() {
    final colorHct = Hct.fromColor(_baseColor);

    final fillTone = contrastingLstar(
      withLstar: _backgroundTone,
      usage: Usage.fill,
      by: _algo,
      contrast: _contrast,
    );

    return Hct.colorFrom(colorHct.hue, colorHct.chroma, fillTone);
  }

  Color _computeFillText() {
    final fillTone = Hct.fromColor(fill).tone;
    final fillTextTone = contrastingLstar(
      withLstar: fillTone,
      usage: Usage.text,
      by: _algo,
      contrast: _contrast,
    );
    final colorHct = Hct.fromColor(_baseColor);
    return Hct.colorFrom(colorHct.hue, colorHct.chroma, fillTextTone);
  }

  Color _computeFillIcon() {
    final fillTone = Hct.fromColor(fill).tone;
    final fillIconTone = contrastingLstar(
      withLstar: fillTone,
      usage: Usage.fill,
      by: _algo,
      contrast: _contrast,
    );
    final colorHct = Hct.fromColor(_baseColor);
    return Hct.colorFrom(colorHct.hue, colorHct.chroma, fillIconTone);
  }

  Color _computeFillHover() {
    final fillTone = Hct.fromColor(fill).tone;
    final hoverContrast = math.max(_contrast - 0.3, 0.1);
    final fillHoverTone = contrastingLstar(
      withLstar: fillTone,
      usage: Usage.fill,
      by: _algo,
      contrast: hoverContrast,
    );
    final colorHct = Hct.fromColor(_baseColor);
    return Hct.colorFrom(colorHct.hue, colorHct.chroma, fillHoverTone);
  }

  Color _computeFillSplash() {
    final fillTone = Hct.fromColor(fill).tone;
    final splashContrast = math.max(_contrast - 0.15, 0.25);
    final fillSplashTone = contrastingLstar(
      withLstar: fillTone,
      usage: Usage.fill,
      by: _algo,
      contrast: splashContrast,
    );
    final colorHct = Hct.fromColor(_baseColor);
    return Hct.colorFrom(colorHct.hue, colorHct.chroma, fillSplashTone);
  }

  Color _computeFillHoverText() {
    final fillHoverTone = Hct.fromColor(fillHover).tone;
    final fillHoverTextTone = contrastingLstar(
      withLstar: fillHoverTone,
      usage: Usage.text,
      by: _algo,
      contrast: _contrast,
    );
    final colorHct = Hct.fromColor(_baseColor);
    return Hct.colorFrom(colorHct.hue, colorHct.chroma, fillHoverTextTone);
  }

  Color _computeFillSplashText() {
    final fillSplashTone = Hct.fromColor(fillSplash).tone;
    final fillSplashTextTone = contrastingLstar(
      withLstar: fillSplashTone,
      usage: Usage.text,
      by: _algo,
      contrast: _contrast,
    );
    final colorHct = Hct.fromColor(_baseColor);
    return Hct.colorFrom(colorHct.hue, colorHct.chroma, fillSplashTextTone);
  }

  Color _computeText() {
    final textTone = contrastingLstar(
      withLstar: _backgroundTone,
      usage: Usage.text,
      by: _algo,
      contrast: _contrast,
    );
    final colorHct = Hct.fromColor(_baseColor);
    return Hct.colorFrom(colorHct.hue, colorHct.chroma, textTone);
  }

  Color _computeTextHover() {
    final hoverContrast = math.max(_contrast - 0.3, 0.1);
    final textHoverTone = contrastingLstar(
      withLstar: _backgroundTone,
      usage: Usage.text,
      by: _algo,
      contrast: hoverContrast,
    );
    final colorHct = Hct.fromColor(_baseColor);
    return Hct.colorFrom(colorHct.hue, colorHct.chroma, textHoverTone);
  }

  Color _computeTextSplash() {
    final splashContrast = math.max(_contrast - 0.15, 0.25);
    final textSplashTone = contrastingLstar(
      withLstar: _backgroundTone,
      usage: Usage.text,
      by: _algo,
      contrast: splashContrast,
    );
    final colorHct = Hct.fromColor(_baseColor);
    return Hct.colorFrom(colorHct.hue, colorHct.chroma, textSplashTone);
  }

  Color _computeTextHoverText() {
    final textHoverTone = Hct.fromColor(textHover).tone;
    final textHoverTextTone = contrastingLstar(
      withLstar: textHoverTone,
      usage: Usage.text,
      by: _algo,
      contrast: _contrast,
    );
    final colorHct = Hct.fromColor(_baseColor);
    return Hct.colorFrom(colorHct.hue, colorHct.chroma, textHoverTextTone);
  }

  Color _computeTextSplashText() {
    final textSplashTone = Hct.fromColor(textSplash).tone;
    final textSplashTextTone = contrastingLstar(
      withLstar: textSplashTone,
      usage: Usage.text,
      by: _algo,
      contrast: _contrast,
    );
    final colorHct = Hct.fromColor(_baseColor);
    return Hct.colorFrom(colorHct.hue, colorHct.chroma, textSplashTextTone);
  }
}
