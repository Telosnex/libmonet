import 'dart:math' as math;
import 'dart:ui';

import 'package:libmonet/apca_contrast.dart';
import 'package:libmonet/contrast.dart';
import 'package:libmonet/hct.dart';
import 'package:libmonet/wcag.dart';

// Internal cache token for typed, collision-free memoization.
// Keep this list in sync with the getters below.
enum _Token {
  background,
  backgroundText,
  backgroundFill,
  backgroundBorder,
  backgroundHovered,
  backgroundSplashed,
  backgroundHoveredFill,
  backgroundSplashedFill,
  backgroundHoveredText,
  backgroundSplashedText,
  backgroundHoveredBorder,
  backgroundSplashedBorder,

  colorHovered,
  colorSplashed,
  colorText,
  colorHoveredText,
  colorSplashedText,
  colorIcon,
  colorBorder,
  colorHoveredBorder,
  colorSplashedBorder,

  fill,
  fillBorder,
  fillHovered,
  fillSplashed,
  fillText,
  fillHoveredText,
  fillSplashedText,
  fillIcon,
  fillHoveredBorder,
  fillSplashedBorder,

  text,
  textHovered,
  textHoveredText,
  textSplashed,
  textSplashedText,
}

/// SafeColors
///
/// Roles are conceptualized as a small cross-product:
/// - Container family (what you paint onto): background, fill (brand on background), color (brand container)
/// - State: normal, hover, splash
/// - On-role: Text (Usage.text), Fill (Usage.fill), Border (Usage.large or two-reference solver)
///
/// Naming convention: [container][State][OnRole]. Examples:
/// - backgroundText, backgroundHoveredText, backgroundSplashedText
/// - backgroundFill, backgroundHoveredFill, backgroundSplashedFill
/// - fillText, fillHoveredText, fillSplashedText; colorText, colorHoveredText, colorSplashedText
/// - colorBorder, fillBorder (borders use a robust two-reference solver)
///
/// Brand-tinted on-roles use baseColor's hue/chroma; neutral on-background roles use background's hue/chroma.
/// Tones are solved via contrastingLstar against the container tone using the configured algorithm and contrast dial.
class SafeColors {
  // Enable verbose debug logging during development/tests.
  // Tests can toggle this flag to print candidate/cost details.
  static bool debug = false;

  // Core parameters
  final Color _baseColor;
  final Color _baseBackground;
  final double _backgroundTone;
  final double _contrast;
  final Algo _algo;

  // Precomputed HCT channels to avoid repeated Hct.fromColor lookups
  final double _baseHue;
  final double _baseChroma;
  final double _baseTone;
  final double _bgHue;
  final double _bgChroma;

  // Cache for lazy-computed values (typed keys)
  final Map<_Token, Color> _cache = {};

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
        _algo = algo,
        _baseHue = Hct.fromColor(baseColor).hue,
        _baseChroma = Hct.fromColor(baseColor).chroma,
        _baseTone = Hct.fromColor(baseColor).tone,
        _bgHue = Hct.fromColor(baseBackground).hue,
        _bgChroma = Hct.fromColor(baseBackground).chroma;

  // Getters with lazy computation
  Color get background => _computeOrGet(_Token.background, _computeBackground);
  Color get backgroundText =>
      _computeOrGet(_Token.backgroundText, _computeBackgroundText);
  Color get backgroundFill =>
      _computeOrGet(_Token.backgroundFill, _computeBackgroundFill);
  Color get backgroundBorder =>
      _computeOrGet(_Token.backgroundBorder, _computeBackgroundBorder);

  // New: Background interactive (brand overlay on background)
  // Distinct hover/splash colors that preserve base hue/chroma and
  // solve tone against the background using the interactive contrast dials.
  Color get backgroundHovered =>
      _computeOrGet(_Token.backgroundHovered, _computeBackgroundHovered);
  Color get backgroundSplashed =>
      _computeOrGet(_Token.backgroundSplashed, _computeBackgroundSplashed);

  // Synonyms for explicit intent (fill overlay on background during hover/press)
  Color get backgroundHoveredFill =>
      _computeOrGet(_Token.backgroundHoveredFill, _computeBackgroundHoveredFill);
  Color get backgroundSplashedFill =>
      _computeOrGet(_Token.backgroundSplashedFill, _computeBackgroundSplashedFill);

  // Text intended to sit on top of the brand background overlays above.
  Color get backgroundHoveredText =>
      _computeOrGet(_Token.backgroundHoveredText, _computeBackgroundHoveredText);
  Color get backgroundSplashedText =>
      _computeOrGet(_Token.backgroundSplashedText, _computeBackgroundSplashedText);

  // Borders for brand overlays on background (two-reference solver against
  // overlay tone and background tone). Useful for edge clarity and potential
  // elevation animations.
  Color get backgroundHoveredBorder => _computeOrGet(
      _Token.backgroundHoveredBorder, _computeBackgroundHoveredBorder);
  Color get backgroundSplashedBorder => _computeOrGet(
      _Token.backgroundSplashedBorder, _computeBackgroundSplashedBorder);

  Color get color => _baseColor;
  Color get colorHovered => _computeOrGet(_Token.colorHovered, _computeColorHovered);
  Color get colorSplashed =>
      _computeOrGet(_Token.colorSplashed, _computeColorSplashed);

  Color get colorText => _computeOrGet(_Token.colorText, _computeColorText);
  Color get colorHoveredText =>
      _computeOrGet(_Token.colorHoveredText, _computeColorHoveredText);
  Color get colorSplashedText =>
      _computeOrGet(_Token.colorSplashedText, _computeColorSplashedText);

  Color get colorIcon => _computeOrGet(_Token.colorIcon, _computeColorIcon);
  Color get colorBorder =>
      _computeOrGet(_Token.colorBorder, _computeColorBorder);
  Color get colorHoveredBorder => _computeOrGet(_Token.colorHoveredBorder, _computeColorHoveredBorder);
  Color get colorSplashedBorder => _computeOrGet(_Token.colorSplashedBorder, _computeColorSplashedBorder);

  Color get fill => _computeOrGet(_Token.fill, _computeFill);
  Color get fillBorder => _computeOrGet(_Token.fillBorder, _computeFillBorder);
  Color get fillHovered => _computeOrGet(_Token.fillHovered, _computeFillHovered);
  Color get fillSplashed => _computeOrGet(_Token.fillSplashed, _computeFillSplashed);

  Color get fillText => _computeOrGet(_Token.fillText, _computeFillText);
  Color get fillHoveredText =>
      _computeOrGet(_Token.fillHoveredText, _computeFillHoveredText);
  Color get fillSplashedText =>
      _computeOrGet(_Token.fillSplashedText, _computeFillSplashedText);

  Color get fillIcon => _computeOrGet(_Token.fillIcon, _computeFillIcon);
  Color get fillHoveredBorder => _computeOrGet(_Token.fillHoveredBorder, _computeFillHoveredBorder);
  Color get fillSplashedBorder => _computeOrGet(_Token.fillSplashedBorder, _computeFillSplashedBorder);

  Color get text => _computeOrGet(_Token.text, _computeText);
  Color get textHovered => _computeOrGet(_Token.textHovered, _computeTextHovered);
  Color get textHoveredText =>
      _computeOrGet(_Token.textHoveredText, _computeTextHoveredText);
  Color get textSplashed => _computeOrGet(_Token.textSplashed, _computeTextSplashed);
  Color get textSplashedText =>
      _computeOrGet(_Token.textSplashedText, _computeTextSplashedText);


  // Helper method for lazy computation with caching (typed key)
  Color _computeOrGet(_Token key, Color Function() compute) {
    if (!_cache.containsKey(key)) {
      _cache[key] = compute();
    }
    return _cache[key]!;
  }

  // -------------------------
  // Shared helpers (DRY)
  // -------------------------

  // Contrast dials per state
  double _hoverDial() => math.max(_contrast - 0.3, 0.1);
  double _splashDial() => math.max(_contrast - 0.15, 0.25);

  // Tone solver
  double _solveTone({
    required double containerTone,
    required Usage usage,
    required double dial,
  }) =>
      contrastingLstar(
          withLstar: containerTone, usage: usage, by: _algo, contrast: dial);

  // Color constructors from tone
  Color _brandFromTone(double tone) =>
      Hct.colorFrom(_baseHue, _baseChroma, tone);
  Color _neutralFromTone(double tone) => Hct.colorFrom(_bgHue, _bgChroma, tone);

  // One-step solvers (brand/neutral on a container tone)
  Color _brandOn(
          {required double containerTone,
          required Usage usage,
          required double dial}) =>
      _brandFromTone(
          _solveTone(containerTone: containerTone, usage: usage, dial: dial));
  Color _neutralOn(
          {required double containerTone,
          required Usage usage,
          required double dial}) =>
      _neutralFromTone(
          _solveTone(containerTone: containerTone, usage: usage, dial: dial));

  // APCA/WCAG candidate tones around a reference tone for border solving
  double _lighterCandidate(double tone, double requiredContrast) =>
      (_algo == Algo.apca)
          ? lighterTextLstar(tone, -requiredContrast)
          : lighterLstarUnsafe(lstar: tone, contrastRatio: requiredContrast);
  double _darkerCandidate(double tone, double requiredContrast) =>
      (_algo == Algo.apca)
          ? darkerTextLstar(tone, requiredContrast)
          : darkerLstarUnsafe(lstar: tone, contrastRatio: requiredContrast);

  // Find a tone that contrasts with two references; prefers lighter/darker
  // relative to refA when available; otherwise chooses minimal total delta.
  double _twoRefBorderTone({
    required double refA,
    required double refB,
    required double requiredContrast,
  }) {
    bool hasValid(double t) => _hasValidContrastHelper(
          tone: t,
          backgroundTone: refA,
          colorTone: refB,
          requiredContrast: requiredContrast,
        );
    double delta(double t) => (t - refA).abs() + (t - refB).abs();

    final Set<double> candidateSet = {};
    final aLight = _lighterCandidate(refA, requiredContrast);
    final aDark = _darkerCandidate(refA, requiredContrast);
    final bLight = _lighterCandidate(refB, requiredContrast);
    final bDark = _darkerCandidate(refB, requiredContrast);
    if (aLight <= 100) candidateSet.add(aLight.clamp(0, 100));
    if (aDark >= 0) candidateSet.add(aDark.clamp(0, 100));
    if (bLight <= 100) candidateSet.add(bLight.clamp(0, 100));
    if (bDark >= 0) candidateSet.add(bDark.clamp(0, 100));

    final candidates = candidateSet.toList();
    final valid = candidates.where(hasValid).toList();
    if (valid.isEmpty) {
      final blackDelta = delta(0);
      final whiteDelta = delta(100);
      return blackDelta < whiteDelta ? 0 : 100;
    }

    final preferLighter = lstarPrefersLighterPair(refA);
    final dir = preferLighter
        ? valid.where((t) => t > refA).toList()
        : valid.where((t) => t < refA).toList();
    if (dir.isNotEmpty) {
      double best = dir.first;
      double minDelta = delta(best);
      for (final t in dir) {
        final d = delta(t);
        if (d < minDelta) {
          minDelta = d;
          best = t;
        }
      }
      return best;
    }

    double best = valid.first;
    double minDelta = delta(best);
    for (final t in valid) {
      final d = delta(t);
      if (d < minDelta) {
        minDelta = d;
        best = t;
      }
    }
    return best;
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

  Color _computeBackgroundText() => _neutralOn(
      containerTone: _backgroundTone, usage: Usage.text, dial: _contrast);

  Color _computeBackgroundFill() => _neutralOn(
      containerTone: _backgroundTone, usage: Usage.fill, dial: _contrast);

  Color _computeBackgroundBorder() => Hct.colorFrom(
      _bgHue,
      _baseChroma,
      _solveTone(
          containerTone: _backgroundTone, usage: Usage.large, dial: _contrast));

  // New: Background interactive (brand overlay on background)
  Color _computeBackgroundHovered() => _brandOn(
      containerTone: _backgroundTone, usage: Usage.fill, dial: _hoverDial());
  Color _computeBackgroundSplashed() => _brandOn(
      containerTone: _backgroundTone, usage: Usage.fill, dial: _splashDial());

  // Synonyms for clarity: compute identical to backgroundHovered/backgroundSplashed.
  Color _computeBackgroundHoveredFill() => backgroundHovered;
  Color _computeBackgroundSplashedFill() => backgroundSplashed;

  // Text intended to sit on top of the brand overlays above –
  // compute against the overlay tone, preserving brand hue/chroma.
  Color _computeBackgroundHoveredText() {
    final overlayTone = Hct.fromColor(backgroundHovered).tone;
    return _brandOn(
        containerTone: overlayTone, usage: Usage.text, dial: _contrast);
  }

  Color _computeBackgroundSplashedText() {
    final overlayTone = Hct.fromColor(backgroundSplashed).tone;
    return _brandOn(
        containerTone: overlayTone, usage: Usage.text, dial: _contrast);
  }

  Color _computeBackgroundHoveredBorder() {
    final overlayTone = Hct.fromColor(backgroundHovered).tone;
    final required = _algo.getAbsoluteContrast(_contrast, Usage.large);
    final baseVsOverlay =
        _algo.getContrastBetweenLstars(bg: overlayTone, fg: _baseTone).abs();
    final baseVsBg = _algo
        .getContrastBetweenLstars(bg: _backgroundTone, fg: _baseTone)
        .abs();
    if (baseVsOverlay >= required && baseVsBg >= required) return _baseColor;
    final tone = _twoRefBorderTone(
        refA: overlayTone, refB: _backgroundTone, requiredContrast: required);
    return _brandFromTone(tone);
  }

  Color _computeBackgroundSplashedBorder() {
    final overlayTone = Hct.fromColor(backgroundSplashed).tone;
    final required = _algo.getAbsoluteContrast(_contrast, Usage.large);
    final baseVsOverlay =
        _algo.getContrastBetweenLstars(bg: overlayTone, fg: _baseTone).abs();
    final baseVsBg = _algo
        .getContrastBetweenLstars(bg: _backgroundTone, fg: _baseTone)
        .abs();
    if (baseVsOverlay >= required && baseVsBg >= required) return _baseColor;
    final tone = _twoRefBorderTone(
        refA: overlayTone, refB: _backgroundTone, requiredContrast: required);
    return _brandFromTone(tone);
  }

  // Update: make fillBorder robust like colorBorder by solving for a tone
  // that contrasts with both the fill surface and the background. This
  // matches the two-reference approach used in _computeColorBorder.
  // Implementation is shared with _computeColorBorder via
  // _solveEitherSideBorder (either-side cost with smart tie-breaks).
  Color _computeFillBorder() {
    final innerTone = Hct.fromColor(fill).tone;
    return _solveEitherSideBorder(
      innerTone: innerTone,
      baseTone: Hct.fromColor(_baseColor).tone,
      backgroundTone: _backgroundTone,
      requiredContrast: _algo.getAbsoluteContrast(_contrast, Usage.large),
      hue: _baseHue,
      chroma: _baseChroma,
    );
  }

  // Shared either-side border solver used by fillBorder/colorBorder.
  // Selects a border tone that contrasts with at least one of
  // (innerTone, backgroundTone). Uses either-side cost with pass-oriented
  // tie-breaks. Optionally short-circuits to the base color if it already
  // meets the contrast requirement (vs bg only or vs both sides).
  Color _solveEitherSideBorder({
    required double innerTone,
    required double baseTone,
    required double backgroundTone,
    required double requiredContrast,
    required double hue,
    required double chroma,
  }) {
    void debugLog(String Function() message) {
      if (SafeColors.debug) {
        // ignore: avoid_print
        print(message());
      }
    }

    // Fast-path: if brand color already meets contrast vs background, keep it.
    final vsBg =
        _algo.getContrastBetweenLstars(bg: backgroundTone, fg: baseTone).abs();
    if (vsBg >= requiredContrast) {
      debugLog(() =>
          'border fast-path: base meets vs bg (|Lc|=${vsBg.toStringAsFixed(1)} ≥ ${requiredContrast.toStringAsFixed(1)})');
      return Hct.colorFrom(hue, chroma, baseTone);
    }

    // Candidate tones (avoid duplicates)
    final Set<double> candidateSet = {};
    // Background-side candidates
    final bgLighterTone = (_algo == Algo.apca)
        ? lighterTextLstar(backgroundTone, -requiredContrast)
        : lighterLstarUnsafe(
            lstar: backgroundTone, contrastRatio: requiredContrast);
    final bgDarkerTone = (_algo == Algo.apca)
        ? darkerTextLstar(backgroundTone, requiredContrast)
        : darkerLstarUnsafe(
            lstar: backgroundTone, contrastRatio: requiredContrast);
    if (bgLighterTone <= 100) candidateSet.add(bgLighterTone.clamp(0, 100));
    if (bgDarkerTone >= 0) candidateSet.add(bgDarkerTone.clamp(0, 100));
    // Inner-side candidates
    final inLighterTone = (_algo == Algo.apca)
        ? lighterBackgroundLstar(innerTone, requiredContrast)
        : lighterLstarUnsafe(lstar: innerTone, contrastRatio: requiredContrast);
    final inDarkerTone = (_algo == Algo.apca)
        ? darkerBackgroundLstar(innerTone, -requiredContrast)
        : darkerLstarUnsafe(lstar: innerTone, contrastRatio: requiredContrast);
    if (inLighterTone <= 100) candidateSet.add(inLighterTone.clamp(0, 100));
    if (inDarkerTone >= 0) candidateSet.add(inDarkerTone.clamp(0, 100));
    // Include base tone for smooth transitions
    candidateSet.add(baseTone.clamp(0, 100));

    final candidateTones = candidateSet.toList();

    bool hasValidContrast(double t) {
      final lcBg =
          _algo.getContrastBetweenLstars(bg: backgroundTone, fg: t).abs();
      final lcIn = _algo.getContrastBetweenLstars(bg: innerTone, fg: t).abs();
      return lcBg >= requiredContrast || lcIn >= requiredContrast;
    }

    final validCandidates = candidateTones.where(hasValidContrast).toList();

    debugLog(() =>
        'borderSolve: inner=${innerTone.toStringAsFixed(1)} bg=${backgroundTone.toStringAsFixed(1)} req=${requiredContrast.toStringAsFixed(1)}');
    debugLog(() =>
        'Candidates: ${candidateTones.map((t) => t.toStringAsFixed(1)).toList()}');
    for (final t in candidateTones) {
      final lcBg =
          _algo.getContrastBetweenLstars(bg: backgroundTone, fg: t).abs();
      final lcIn = _algo.getContrastBetweenLstars(bg: innerTone, fg: t).abs();
      final best = math.max(lcBg, lcIn);
      final cost = math.max(0.0, requiredContrast - best);
      final dIn = (t - innerTone).abs();
      final dBg = (t - backgroundTone).abs();
      debugLog(() =>
          '  cand T${t.toStringAsFixed(1)} lcBg=${lcBg.toStringAsFixed(1)} lcIn=${lcIn.toStringAsFixed(1)} cost=${cost.toStringAsFixed(1)} dInner=${dIn.toStringAsFixed(1)} dBg=${dBg.toStringAsFixed(1)}');
    }
    debugLog(() =>
        'Valid     : ${validCandidates.map((t) => t.toStringAsFixed(1)).toList()}');

    double calculateTotalDelta(double tone) =>
        (tone - innerTone).abs() + (tone - backgroundTone).abs();

    if (validCandidates.isEmpty) {
      // Evaluate extremes by either-side cost and choose lower-cost; tie → smaller total delta.
      double costFor(double t) {
        final lcBg =
            _algo.getContrastBetweenLstars(bg: backgroundTone, fg: t).abs();
        final lcIn = _algo.getContrastBetweenLstars(bg: innerTone, fg: t).abs();
        final best = math.max(lcBg, lcIn);
        return math.max(0.0, requiredContrast - best);
      }

      final costBlack = costFor(0);
      final costWhite = costFor(100);
      final fb = (costBlack < costWhite - 1e-6)
          ? 0
          : (costWhite < costBlack - 1e-6)
              ? 100
              : (calculateTotalDelta(0) <= calculateTotalDelta(100) ? 0 : 100);
      debugLog(() =>
          'Fallback extremes: cost(T0)=${costBlack.toStringAsFixed(1)} cost(T100)=${costWhite.toStringAsFixed(1)} -> T${fb.toStringAsFixed(0)}');
      return Hct.colorFrom(hue, chroma, fb.toDouble());
    }

    // Primary selection with pass-oriented tie-break.
    double bestTone = validCandidates.first;
    double bestCost = double.infinity;
    double bestTotalDist = double.infinity;
    double bestDInner = double.infinity;
    double bestDBg = double.infinity;
    for (final t in validCandidates) {
      final lcBg =
          _algo.getContrastBetweenLstars(bg: backgroundTone, fg: t).abs();
      final lcIn = _algo.getContrastBetweenLstars(bg: innerTone, fg: t).abs();
      final best = math.max(lcBg, lcIn);
      final cost = math.max(0.0, requiredContrast - best);
      final dIn = (t - innerTone).abs();
      final dBg = (t - backgroundTone).abs();
      final total = dIn + dBg;

      if (cost < bestCost - 1e-6 ||
          (cost <= bestCost + 1e-6 &&
              (total < bestTotalDist - 1e-6 ||
                  (total <= bestTotalDist + 1e-6 &&
                      (dIn < bestDInner - 1e-6 ||
                          (dIn <= bestDInner + 1e-6 &&
                              dBg < bestDBg - 1e-6)))))) {
        bestCost = cost;
        bestTotalDist = total;
        bestDInner = dIn;
        bestDBg = dBg;
        bestTone = t;
      }
    }
    debugLog(() =>
        'Selected bestTone T${bestTone.toStringAsFixed(1)} cost=${bestCost.toStringAsFixed(1)} totalDist=${bestTotalDist.toStringAsFixed(1)} dInner=${bestDInner.toStringAsFixed(1)} dBg=${bestDBg.toStringAsFixed(1)}');
    return Hct.colorFrom(hue, chroma, bestTone);
  }

  Color _computeColorBorder() {
    final innerTone = Hct.fromColor(_baseColor).tone; // color surface tone
    return _solveEitherSideBorder(
      innerTone: innerTone,
      baseTone: innerTone,
      backgroundTone: _backgroundTone,
      requiredContrast: _algo.getAbsoluteContrast(_contrast, Usage.large),
      hue: _baseHue,
      chroma: _baseChroma,
    );
  }

  Color _computeColorText() =>
      _brandOn(containerTone: _baseTone, usage: Usage.text, dial: _contrast);

  Color _computeColorIcon() =>
      _brandOn(containerTone: _baseTone, usage: Usage.fill, dial: _contrast);

  Color _computeColorHovered() =>
      _brandOn(containerTone: _baseTone, usage: Usage.fill, dial: _hoverDial());

  Color _computeColorSplashed() => _brandOn(
      containerTone: _baseTone, usage: Usage.fill, dial: _splashDial());

  Color _computeColorHoveredText() {
    final colorHoveredTone = Hct.fromColor(colorHovered).tone;
    return _brandOn(
        containerTone: colorHoveredTone, usage: Usage.text, dial: _contrast);
  }

  Color _computeColorSplashedText() {
    final colorSplashedTone = Hct.fromColor(colorSplashed).tone;
    return _brandOn(
        containerTone: colorSplashedTone, usage: Usage.text, dial: _contrast);
  }

  Color _computeColorHoveredBorder() {
    final colorHoveredTone = Hct.fromColor(colorHovered).tone;
    final required = _algo.getAbsoluteContrast(_contrast, Usage.large);
    final baseVsHovered = _algo.getContrastBetweenLstars(bg: colorHoveredTone, fg: _baseTone).abs();
    final baseVsBg = _algo.getContrastBetweenLstars(bg: _backgroundTone, fg: _baseTone).abs();
    if (baseVsHovered >= required && baseVsBg >= required) return _baseColor;
    final tone = _twoRefBorderTone(refA: colorHoveredTone, refB: _backgroundTone, requiredContrast: required);
    return _brandFromTone(tone);
  }

  Color _computeColorSplashedBorder() {
    final colorSplashedTone = Hct.fromColor(colorSplashed).tone;
    final required = _algo.getAbsoluteContrast(_contrast, Usage.large);
    final baseVsSplashed = _algo.getContrastBetweenLstars(bg: colorSplashedTone, fg: _baseTone).abs();
    final baseVsBg = _algo.getContrastBetweenLstars(bg: _backgroundTone, fg: _baseTone).abs();
    if (baseVsSplashed >= required && baseVsBg >= required) return _baseColor;
    final tone = _twoRefBorderTone(refA: colorSplashedTone, refB: _backgroundTone, requiredContrast: required);
    return _brandFromTone(tone);
  }

  Color _computeFill() => _brandOn(
      containerTone: _backgroundTone, usage: Usage.fill, dial: _contrast);

  Color _computeFillText() {
    final fillTone = Hct.fromColor(fill).tone;
    return _brandOn(
        containerTone: fillTone, usage: Usage.text, dial: _contrast);
  }

  Color _computeFillIcon() {
    final fillTone = Hct.fromColor(fill).tone;
    return _brandOn(
        containerTone: fillTone, usage: Usage.fill, dial: _contrast);
  }

  Color _computeFillHovered() {
    final fillTone = Hct.fromColor(fill).tone;
    return _brandOn(
        containerTone: fillTone, usage: Usage.fill, dial: _hoverDial());
  }

  Color _computeFillSplashed() {
    final fillTone = Hct.fromColor(fill).tone;
    return _brandOn(
        containerTone: fillTone, usage: Usage.fill, dial: _splashDial());
  }

  Color _computeFillHoveredText() {
    final fillHoveredTone = Hct.fromColor(fillHovered).tone;
    return _brandOn(
        containerTone: fillHoveredTone, usage: Usage.text, dial: _contrast);
  }

  Color _computeFillSplashedText() {
    final fillSplashedTone = Hct.fromColor(fillSplashed).tone;
    return _brandOn(
        containerTone: fillSplashedTone, usage: Usage.text, dial: _contrast);
  }

  Color _computeFillHoveredBorder() {
    final fillHoveredTone = Hct.fromColor(fillHovered).tone;
    final required = _algo.getAbsoluteContrast(_contrast, Usage.large);
    final baseVsHovered = _algo.getContrastBetweenLstars(bg: fillHoveredTone, fg: _baseTone).abs();
    final baseVsBg = _algo.getContrastBetweenLstars(bg: _backgroundTone, fg: _baseTone).abs();
    if (baseVsHovered >= required && baseVsBg >= required) return _baseColor;
    final tone = _twoRefBorderTone(refA: fillHoveredTone, refB: _backgroundTone, requiredContrast: required);
    return _brandFromTone(tone);
  }

  Color _computeFillSplashedBorder() {
    final fillSplashedTone = Hct.fromColor(fillSplashed).tone;
    final required = _algo.getAbsoluteContrast(_contrast, Usage.large);
    final baseVsSplashed = _algo.getContrastBetweenLstars(bg: fillSplashedTone, fg: _baseTone).abs();
    final baseVsBg = _algo.getContrastBetweenLstars(bg: _backgroundTone, fg: _baseTone).abs();
    if (baseVsSplashed >= required && baseVsBg >= required) return _baseColor;
    final tone = _twoRefBorderTone(refA: fillSplashedTone, refB: _backgroundTone, requiredContrast: required);
    return _brandFromTone(tone);
  }

  Color _computeText() => _brandOn(
      containerTone: _backgroundTone, usage: Usage.text, dial: _contrast);

  Color _computeTextHovered() => _brandOn(
      containerTone: _backgroundTone, usage: Usage.text, dial: _hoverDial());

  Color _computeTextSplashed() => _brandOn(
      containerTone: _backgroundTone, usage: Usage.text, dial: _splashDial());

  Color _computeTextHoveredText() {
    final textHoveredTone = Hct.fromColor(textHovered).tone;
    return _brandOn(
        containerTone: textHoveredTone, usage: Usage.text, dial: _contrast);
  }

  Color _computeTextSplashedText() {
    final textSplashedTone = Hct.fromColor(textSplashed).tone;
    return _brandOn(
        containerTone: textSplashedTone, usage: Usage.text, dial: _contrast);
  }
}
