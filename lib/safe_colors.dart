import 'dart:math' as math;
import 'dart:ui';

import 'package:libmonet/apca.dart';
import 'package:libmonet/contrast.dart';
import 'package:libmonet/hct.dart';

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
    
    // Helper function to check contrast
    bool hasContrastWith(double tone1, double tone2) {
      switch (_algo) {
        case Algo.wcag21:
          final requiredContrastRatio =
              contrastRatioInterpolation(percent: _contrast, usage: Usage.large);
          final actualContrastRatio = contrastRatioOfLstars(tone1, tone2);
          return actualContrastRatio >= requiredContrastRatio;
          
        case Algo.apca:
          final requiredApca = apcaInterpolation(percent: _contrast, usage: Usage.large);
          final actualApca = apcaContrastOfApcaY(lstarToApcaY(tone1), lstarToApcaY(tone2));
          return actualApca.abs() >= requiredApca.abs();
      }
    }
    
    // Calculate total delta for a given tone
    double calculateTotalDelta(double tone) {
      return (tone - colorTone).abs() + (tone - backgroundTone).abs();
    }
    
    // Candidate tones to consider (use Set to avoid duplicates)
    Set<double> candidateSet = {};
    
    // Add the original color and background tones
    candidateSet.add(colorTone);
    candidateSet.add(backgroundTone);
    
    // Add the midpoint (minimizes total delta)
    candidateSet.add((colorTone + backgroundTone) / 2);
    
    // Add contrasting tones
    candidateSet.add(contrastingLstar(
      withLstar: backgroundTone,
      usage: Usage.large,
      by: _algo,
      contrast: _contrast,
    ));
    
    candidateSet.add(contrastingLstar(
      withLstar: colorTone,
      usage: Usage.large,
      by: _algo,
      contrast: _contrast,
    ));
    
    final candidateTones = candidateSet.toList();
    
    // Filter candidates that have sufficient contrast with either background or color
    final validCandidates = candidateTones.where((tone) {
      return hasContrastWith(tone, backgroundTone) || hasContrastWith(tone, colorTone);
    }).toList();
    
    // If no valid candidates, fall back to contrasting with background
    if (validCandidates.isEmpty) {
      final fallbackTone = contrastingLstar(
        withLstar: backgroundTone,
        usage: Usage.large,
        by: _algo,
        contrast: _contrast,
      );
      return Hct.colorFrom(colorHct.hue, colorHct.chroma, fallbackTone);
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
    
    // Calculate what the old algorithm would have recommended for comparison
    bool oldNeedBorder = false;
    switch (_algo) {
      case Algo.wcag21:
        final requiredContrastRatio =
            contrastRatioInterpolation(percent: _contrast, usage: Usage.fill);
        final actualContrastRatio =
            contrastRatioOfLstars(colorTone, backgroundTone);
        if (actualContrastRatio < requiredContrastRatio) {
          oldNeedBorder = true;
        }
        break;
      case Algo.apca:
        final apca = apcaContrastOfApcaY(
            lstarToApcaY(colorTone), lstarToApcaY(backgroundTone));
        final requiredApca =
            apcaInterpolation(percent: _contrast, usage: Usage.fill);
        if (apca.abs() < requiredApca.abs()) {
          oldNeedBorder = true;
        }
        break;
    }
    
    final oldTone = !oldNeedBorder
        ? colorTone
        : contrastingLstar(
            withLstar: backgroundTone,
            usage: Usage.fill,
            by: _algo,
            contrast: _contrast,
          );
    
    final oldDelta = calculateTotalDelta(oldTone);
    final newDelta = calculateTotalDelta(bestTone);
    final improvement = oldDelta - newDelta;
    
    // Debug print
    print('Border: candidates=[${candidateTones.map((t) => t.round()).join(',')}] '
          'selected=${bestTone.round()} (Δ=${newDelta.round()}) '
          'old=${oldTone.round()} (Δ=${oldDelta.round()}) '
          'improve=${improvement.round()}');
    
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
