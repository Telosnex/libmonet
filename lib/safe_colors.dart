import 'dart:math' as math;
import 'dart:ui';

import 'package:libmonet/apca_contrast.dart';
import 'package:libmonet/contrast.dart';
import 'package:libmonet/hct.dart';
import 'package:libmonet/wcag.dart';

// Helper functions for getting lighter/darker tones with specific contrast
double lighterLstarForContrast({
  required double lstar,
  required double contrast,
  required Algo algo,
}) {
  switch (algo) {
    case Algo.wcag21:
      return lighterLstarUnsafe(lstar: lstar, contrastRatio: contrast);
    case Algo.apca:
      // For APCA, use negative contrast for lighter text
      return lighterTextLstar(lstar, -contrast);
  }
}

double darkerLstarForContrast({
  required double lstar,
  required double contrast,
  required Algo algo,
}) {
  switch (algo) {
    case Algo.wcag21:
      return darkerLstarUnsafe(lstar: lstar, contrastRatio: contrast);
    case Algo.apca:
      // For APCA, use positive contrast for darker text
      return darkerTextLstar(lstar, contrast);
  }
}

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

  Color _computeColorBorder() {
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
    bool hasValidContrast(double tone) {
      final bgContrast = _algo.getContrastBetweenLstars(
        bg: backgroundTone,
        fg: tone,
      );
      final colorContrast = _algo.getContrastBetweenLstars(
        bg: colorTone,
        fg: tone,
      );
      return bgContrast >= requiredContrast ||
          colorContrast >= requiredContrast;
    }

    // Candidate tones to consider (use Set to avoid duplicates)
    Set<double> candidateSet = {};

    // For background: add both lighter and darker contrasting options
    // Lighter option
    final bgLighterTone = lighterLstarForContrast(
      lstar: backgroundTone,
      contrast: requiredContrast,
      algo: _algo,
    );
    if (bgLighterTone <= 100) {
      candidateSet.add(bgLighterTone.clamp(0, 100));
    }

    // Darker option
    final bgDarkerTone = darkerLstarForContrast(
      lstar: backgroundTone,
      contrast: requiredContrast,
      algo: _algo,
    );
    if (bgDarkerTone >= 0) {
      candidateSet.add(bgDarkerTone.clamp(0, 100));
    }

    // For color: add both lighter and darker contrasting options
    // Lighter option
    final colorLighterTone = lighterLstarForContrast(
      lstar: colorTone,
      contrast: requiredContrast,
      algo: _algo,
    );
    if (colorLighterTone <= 100) {
      candidateSet.add(colorLighterTone.clamp(0, 100));
    }

    // Darker option
    final colorDarkerTone = darkerLstarForContrast(
      lstar: colorTone,
      contrast: requiredContrast,
      algo: _algo,
    );
    if (colorDarkerTone >= 0) {
      candidateSet.add(colorDarkerTone.clamp(0, 100));
    }

    final candidateTones = candidateSet.toList();

    // Filter candidates that have sufficient contrast with either background or color
    final validCandidates = candidateTones.where(hasValidContrast).toList();
    print(
        'Color tone: ${colorTone.round()} bg tone: ${backgroundTone.round()}');
    print('All candidates: ${candidateTones.map((t) => t.round())}');
    print('Valid candidates: ${validCandidates.map((t) => t.round())}');
    // If no valid candidates, fall back to pure black or white
    if (validCandidates.isEmpty) {
      // Choose black or white based on which has better contrast with both
      final blackDelta = calculateTotalDelta(0);
      final whiteDelta = calculateTotalDelta(100);
      return Hct.colorFrom(
          colorHct.hue, colorHct.chroma, blackDelta < whiteDelta ? 0 : 100);
    }

    // Find the candidate with minimal total delta
    double bestTone = validCandidates.first;
    double minDelta = calculateTotalDelta(bestTone);

    for (final tone in validCandidates) {
      final delta = calculateTotalDelta(tone);
      if (delta < minDelta) {
        minDelta = delta;
        bestTone = tone;
      }
    }

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
