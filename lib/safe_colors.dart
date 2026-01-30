import 'dart:math' as math;
import 'dart:ui';

import 'package:libmonet/apca_contrast.dart';
import 'package:libmonet/contrast.dart';
import 'package:libmonet/hct.dart';
import 'package:libmonet/libmonet.dart';
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
  // Lazily-evaluated HCT channels to make construction 0-cost.
  // These are evaluated only on first use.
  final double? _backgroundToneOverride;
  final double _contrast;
  final Algo _algo;

  // Precomputed HCT channels to avoid repeated Hct.fromColor lookups
  late final Hct _baseBackgroundHct = Hct.fromColor(_baseBackground);
  late final Hct _baseColorHct = Hct.fromColor(_baseColor);
  late final double _backgroundTone =
      _backgroundToneOverride ?? _baseBackgroundHct.tone;
  late final double _baseHue = _baseColorHct.hue;
  late final double _baseChroma = _baseColorHct.chroma;
  late final double _baseTone = _baseColorHct.tone;
  late final double _bgHue = _baseBackgroundHct.hue;
  late final double _bgChroma = _baseBackgroundHct.chroma;

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
        _backgroundToneOverride = backgroundTone,
        _contrast = contrast,
        _algo = algo;

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

  // APCA/WCAG candidate tones around a reference tone for border solving.
  // Use "unsafe" variants that return out-of-bounds values when impossible,
  // allowing callers to handle fallback consistently.
  double _lighterCandidate(double tone, double requiredContrast) =>
      (_algo == Algo.apca)
          ? lighterTextLstarUnsafe(tone, -requiredContrast)
          : lighterLstarUnsafe(lstar: tone, contrastRatio: requiredContrast);
  double _darkerCandidate(double tone, double requiredContrast) =>
      (_algo == Algo.apca)
          ? darkerTextLstarUnsafe(tone, requiredContrast)
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

  // Fill roles that sit ON TOP of the interactive background overlays.
  // Solve using BRAND family against the overlay tone (preserve hue/chroma),
  // ensuring contrast with the hovered/splashed background overlay.
  Color _computeBackgroundHoveredFill() {
    final overlayTone = _solveTone(
        containerTone: _backgroundTone, usage: Usage.fill, dial: _hoverDial());
    return _brandOn(
        containerTone: overlayTone, usage: Usage.fill, dial: _contrast);
  }

  Color _computeBackgroundSplashedFill() {
    final overlayTone = _solveTone(
        containerTone: _backgroundTone, usage: Usage.fill, dial: _splashDial());
    return _brandOn(
        containerTone: overlayTone, usage: Usage.fill, dial: _contrast);
  }

  // Text intended to sit on top of the brand overlays above –
  // compute against the overlay tone, preserving brand hue/chroma.
  Color _computeBackgroundHoveredText() {
    final overlayTone = _solveTone(
        containerTone: _backgroundTone, usage: Usage.fill, dial: _hoverDial());
    return _brandOn(
        containerTone: overlayTone, usage: Usage.text, dial: _contrast);
  }

  Color _computeBackgroundSplashedText() {
    final overlayTone = _solveTone(
        containerTone: _backgroundTone, usage: Usage.fill, dial: _splashDial());
    return _brandOn(
        containerTone: overlayTone, usage: Usage.text, dial: _contrast);
  }

  Color _computeBackgroundHoveredBorder() {
    final overlayTone = _solveTone(
        containerTone: _backgroundTone, usage: Usage.fill, dial: _hoverDial());
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
    final overlayTone = _solveTone(
        containerTone: _backgroundTone, usage: Usage.fill, dial: _splashDial());
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
    final innerTone = _solveTone(
        containerTone: _backgroundTone, usage: Usage.fill, dial: _contrast);
    return _solveEitherSideBorder(
      innerTone: innerTone,
      baseTone: _baseTone,
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

    // Candidate tones (avoid duplicates).
    // Use "unsafe" variants that return out-of-bounds values when impossible,
    // so we can filter consistently.
    final Set<double> candidateSet = {};
    // Background-side candidates
    final bgLighterTone = (_algo == Algo.apca)
        ? lighterTextLstarUnsafe(backgroundTone, -requiredContrast)
        : lighterLstarUnsafe(
            lstar: backgroundTone, contrastRatio: requiredContrast);
    final bgDarkerTone = (_algo == Algo.apca)
        ? darkerTextLstarUnsafe(backgroundTone, requiredContrast)
        : darkerLstarUnsafe(
            lstar: backgroundTone, contrastRatio: requiredContrast);
    if (bgLighterTone <= 100) candidateSet.add(bgLighterTone.clamp(0, 100));
    if (bgDarkerTone >= 0) candidateSet.add(bgDarkerTone.clamp(0, 100));
    // Inner-side candidates
    final inLighterTone = (_algo == Algo.apca)
        ? lighterBackgroundLstarUnsafe(innerTone, requiredContrast)
        : lighterLstarUnsafe(lstar: innerTone, contrastRatio: requiredContrast);
    final inDarkerTone = (_algo == Algo.apca)
        ? darkerBackgroundLstarUnsafe(innerTone, -requiredContrast)
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
    final innerTone = _baseTone; // color surface tone
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
    final colorHoveredTone = _solveTone(
        containerTone: _baseTone, usage: Usage.fill, dial: _hoverDial());
    return _brandOn(
        containerTone: colorHoveredTone, usage: Usage.text, dial: _contrast);
  }

  Color _computeColorSplashedText() {
    final colorSplashedTone = _solveTone(
        containerTone: _baseTone, usage: Usage.fill, dial: _splashDial());
    return _brandOn(
        containerTone: colorSplashedTone, usage: Usage.text, dial: _contrast);
  }

  Color _computeColorHoveredBorder() {
    final colorHoveredTone = _solveTone(
        containerTone: _baseTone, usage: Usage.fill, dial: _hoverDial());
    final required = _algo.getAbsoluteContrast(_contrast, Usage.large);
    final baseVsHovered = _algo.getContrastBetweenLstars(bg: colorHoveredTone, fg: _baseTone).abs();
    final baseVsBg = _algo.getContrastBetweenLstars(bg: _backgroundTone, fg: _baseTone).abs();
    if (baseVsHovered >= required && baseVsBg >= required) return _baseColor;
    final tone = _twoRefBorderTone(refA: colorHoveredTone, refB: _backgroundTone, requiredContrast: required);
    return _brandFromTone(tone);
  }

  Color _computeColorSplashedBorder() {
    final colorSplashedTone = _solveTone(
        containerTone: _baseTone, usage: Usage.fill, dial: _splashDial());
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
    final fillTone = _solveTone(
        containerTone: _backgroundTone, usage: Usage.fill, dial: _contrast);
    return _brandOn(
        containerTone: fillTone, usage: Usage.text, dial: _contrast);
  }

  Color _computeFillIcon() {
    final fillTone = _solveTone(
        containerTone: _backgroundTone, usage: Usage.fill, dial: _contrast);
    return _brandOn(
        containerTone: fillTone, usage: Usage.fill, dial: _contrast);
  }

  Color _computeFillHovered() {
    final fillTone = _solveTone(
        containerTone: _backgroundTone, usage: Usage.fill, dial: _contrast);
    return _brandOn(
        containerTone: fillTone, usage: Usage.fill, dial: _hoverDial());
  }

  Color _computeFillSplashed() {
    final fillTone = _solveTone(
        containerTone: _backgroundTone, usage: Usage.fill, dial: _contrast);
    return _brandOn(
        containerTone: fillTone, usage: Usage.fill, dial: _splashDial());
  }

  Color _computeFillHoveredText() {
    final fillTone = _solveTone(
        containerTone: _backgroundTone, usage: Usage.fill, dial: _contrast);
    final fillHoveredTone = _solveTone(
      containerTone: fillTone,
      usage: Usage.fill,
      dial: _hoverDial(),
    );
    return _brandOn(
        containerTone: fillHoveredTone, usage: Usage.text, dial: _contrast);
  }

  Color _computeFillSplashedText() {
    final fillTone = _solveTone(
        containerTone: _backgroundTone, usage: Usage.fill, dial: _contrast);
    final fillSplashedTone = _solveTone(
        containerTone: fillTone, usage: Usage.fill, dial: _splashDial());
    return _brandOn(
        containerTone: fillSplashedTone, usage: Usage.text, dial: _contrast);
  }

  Color _computeFillHoveredBorder() {
    final fillHoveredTone = _solveTone(
        containerTone: _solveTone(
            containerTone: _backgroundTone,
            usage: Usage.fill,
            dial: _contrast),
        usage: Usage.fill,
        dial: _hoverDial());
    final required = _algo.getAbsoluteContrast(_contrast, Usage.large);
    final baseVsHovered = _algo.getContrastBetweenLstars(bg: fillHoveredTone, fg: _baseTone).abs();
    final baseVsBg = _algo.getContrastBetweenLstars(bg: _backgroundTone, fg: _baseTone).abs();
    if (baseVsHovered >= required && baseVsBg >= required) return _baseColor;
    final tone = _twoRefBorderTone(refA: fillHoveredTone, refB: _backgroundTone, requiredContrast: required);
    return _brandFromTone(tone);
  }

  Color _computeFillSplashedBorder() {
    final fillSplashedTone = _solveTone(
        containerTone: _solveTone(
            containerTone: _backgroundTone,
            usage: Usage.fill,
            dial: _contrast),
        usage: Usage.fill,
        dial: _splashDial());
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
    final textHoveredTone = _solveTone(
        containerTone: _backgroundTone, usage: Usage.text, dial: _hoverDial());
    return _brandOn(
        containerTone: textHoveredTone, usage: Usage.text, dial: _contrast);
  }

  Color _computeTextSplashedText() {
    final textSplashedTone = _solveTone(
        containerTone: _backgroundTone, usage: Usage.text, dial: _splashDial());
    return _brandOn(
        containerTone: textSplashedTone, usage: Usage.text, dial: _contrast);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SafeColors &&
          runtimeType == other.runtimeType &&
          color.argb == other.color.argb &&
          background.argb == other.background.argb &&
          _contrast == other._contrast &&
          _algo == other._algo &&
          // If backgroundToneOverride was provided, ensure parity.
          (_backgroundToneOverride == null) ==
              (other._backgroundToneOverride == null) &&
          (_backgroundToneOverride == null ||
              _backgroundToneOverride == other._backgroundToneOverride);

  @override
  int get hashCode => Object.hash(
      color.argb,
      background.argb,
      _contrast,
      _algo,
      _backgroundToneOverride);
}

// Interpolated view of SafeColors that HCT-lerps token outputs between two
// SafeColors instances. Lives in this library to access the private
// constructor.
class LerpedSafeColors extends SafeColors {

// Snapshot of SafeColors: captures token outputs at construction time and
// returns the same values thereafter. Lives in this library to access the
// private constructor.
// SnapshotSafeColors moved to top-level after LerpedSafeColors.
  final SafeColors a;
  final SafeColors b;
  final double t;

  LerpedSafeColors({required this.a, required this.b, required this.t})
      : super._(
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
}

// Snapshot of SafeColors: captures token outputs at construction time and
// returns the same values thereafter. Lives in this library to access the
// private constructor.
class SnapshotSafeColors extends SafeColors {
  // Background
  final Color _background;
  final Color _backgroundText;
  final Color _backgroundFill;
  final Color _backgroundBorder;
  final Color _backgroundHovered;
  final Color _backgroundSplashed;
  final Color _backgroundHoveredFill;
  final Color _backgroundSplashedFill;
  final Color _backgroundHoveredText;
  final Color _backgroundSplashedText;
  final Color _backgroundHoveredBorder;
  final Color _backgroundSplashedBorder;

  // Fill
  final Color _fill;
  final Color _fillBorder;
  final Color _fillHovered;
  final Color _fillSplashed;
  final Color _fillText;
  final Color _fillHoveredText;
  final Color _fillSplashedText;
  final Color _fillIcon;
  final Color _fillHoveredBorder;
  final Color _fillSplashedBorder;

  // Color (ink)
  final Color _color;
  final Color _colorText;
  final Color _colorIcon;
  final Color _colorBorder;
  final Color _colorHovered;
  final Color _colorHoveredText;
  final Color _colorHoveredBorder;
  final Color _colorSplashed;
  final Color _colorSplashedText;
  final Color _colorSplashedBorder;

  // Text standalone
  final Color _text;
  final Color _textHovered;
  final Color _textHoveredText;
  final Color _textSplashed;
  final Color _textSplashedText;

  SnapshotSafeColors._(
    Color baseColor,
    Color baseBackground,
    Color background,
    Color backgroundText,
    Color backgroundFill,
    Color backgroundBorder,
    Color backgroundHovered,
    Color backgroundSplashed,
    Color backgroundHoveredFill,
    Color backgroundSplashedFill,
    Color backgroundHoveredText,
    Color backgroundSplashedText,
    Color backgroundHoveredBorder,
    Color backgroundSplashedBorder,
    Color fill,
    Color fillBorder,
    Color fillHovered,
    Color fillSplashed,
    Color fillText,
    Color fillHoveredText,
    Color fillSplashedText,
    Color fillIcon,
    Color fillHoveredBorder,
    Color fillSplashedBorder,
    Color color,
    Color colorText,
    Color colorIcon,
    Color colorBorder,
    Color colorHovered,
    Color colorHoveredText,
    Color colorHoveredBorder,
    Color colorSplashed,
    Color colorSplashedText,
    Color colorSplashedBorder,
    Color text,
    Color textHovered,
    Color textHoveredText,
    Color textSplashed,
    Color textSplashedText,
  )   : _background = background,
        _backgroundText = backgroundText,
        _backgroundFill = backgroundFill,
        _backgroundBorder = backgroundBorder,
        _backgroundHovered = backgroundHovered,
        _backgroundSplashed = backgroundSplashed,
        _backgroundHoveredFill = backgroundHoveredFill,
        _backgroundSplashedFill = backgroundSplashedFill,
        _backgroundHoveredText = backgroundHoveredText,
        _backgroundSplashedText = backgroundSplashedText,
        _backgroundHoveredBorder = backgroundHoveredBorder,
        _backgroundSplashedBorder = backgroundSplashedBorder,
        _fill = fill,
        _fillBorder = fillBorder,
        _fillHovered = fillHovered,
        _fillSplashed = fillSplashed,
        _fillText = fillText,
        _fillHoveredText = fillHoveredText,
        _fillSplashedText = fillSplashedText,
        _fillIcon = fillIcon,
        _fillHoveredBorder = fillHoveredBorder,
        _fillSplashedBorder = fillSplashedBorder,
        _color = color,
        _colorText = colorText,
        _colorIcon = colorIcon,
        _colorBorder = colorBorder,
        _colorHovered = colorHovered,
        _colorHoveredText = colorHoveredText,
        _colorHoveredBorder = colorHoveredBorder,
        _colorSplashed = colorSplashed,
        _colorSplashedText = colorSplashedText,
        _colorSplashedBorder = colorSplashedBorder,
        _text = text,
        _textHovered = textHovered,
        _textHoveredText = textHoveredText,
        _textSplashed = textSplashed,
        _textSplashedText = textSplashedText,
        super._(
          baseColor: baseColor,
          baseBackground: baseBackground,
          contrast: 0.5,
          algo: Algo.apca,
        );

  factory SnapshotSafeColors.capture(SafeColors s) {
    return SnapshotSafeColors._(
      s.color,
      s.background,
      s.background,
      s.backgroundText,
      s.backgroundFill,
      s.backgroundBorder,
      s.backgroundHovered,
      s.backgroundSplashed,
      s.backgroundHoveredFill,
      s.backgroundSplashedFill,
      s.backgroundHoveredText,
      s.backgroundSplashedText,
      s.backgroundHoveredBorder,
      s.backgroundSplashedBorder,
      s.fill,
      s.fillBorder,
      s.fillHovered,
      s.fillSplashed,
      s.fillText,
      s.fillHoveredText,
      s.fillSplashedText,
      s.fillIcon,
      s.fillHoveredBorder,
      s.fillSplashedBorder,
      s.color,
      s.colorText,
      s.colorIcon,
      s.colorBorder,
      s.colorHovered,
      s.colorHoveredText,
      s.colorHoveredBorder,
      s.colorSplashed,
      s.colorSplashedText,
      s.colorSplashedBorder,
      s.text,
      s.textHovered,
      s.textHoveredText,
      s.textSplashed,
      s.textSplashedText,
    );
  }

  // Background
  @override
  Color get background => _background;
  @override
  Color get backgroundText => _backgroundText;
  @override
  Color get backgroundFill => _backgroundFill;
  @override
  Color get backgroundBorder => _backgroundBorder;
  @override
  Color get backgroundHovered => _backgroundHovered;
  @override
  Color get backgroundSplashed => _backgroundSplashed;
  @override
  Color get backgroundHoveredFill => _backgroundHoveredFill;
  @override
  Color get backgroundSplashedFill => _backgroundSplashedFill;
  @override
  Color get backgroundHoveredText => _backgroundHoveredText;
  @override
  Color get backgroundSplashedText => _backgroundSplashedText;
  @override
  Color get backgroundHoveredBorder => _backgroundHoveredBorder;
  @override
  Color get backgroundSplashedBorder => _backgroundSplashedBorder;

  // Fill
  @override
  Color get fill => _fill;
  @override
  Color get fillBorder => _fillBorder;
  @override
  Color get fillHovered => _fillHovered;
  @override
  Color get fillSplashed => _fillSplashed;
  @override
  Color get fillText => _fillText;
  @override
  Color get fillHoveredText => _fillHoveredText;
  @override
  Color get fillSplashedText => _fillSplashedText;
  @override
  Color get fillIcon => _fillIcon;
  @override
  Color get fillHoveredBorder => _fillHoveredBorder;
  @override
  Color get fillSplashedBorder => _fillSplashedBorder;

  // Color (ink)
  @override
  Color get color => _color;
  @override
  Color get colorText => _colorText;
  @override
  Color get colorIcon => _colorIcon;
  @override
  Color get colorBorder => _colorBorder;
  @override
  Color get colorHovered => _colorHovered;
  @override
  Color get colorHoveredText => _colorHoveredText;
  @override
  Color get colorHoveredBorder => _colorHoveredBorder;
  @override
  Color get colorSplashed => _colorSplashed;
  @override
  Color get colorSplashedText => _colorSplashedText;
  @override
  Color get colorSplashedBorder => _colorSplashedBorder;

  // Text standalone
  @override
  Color get text => _text;
  @override
  Color get textHovered => _textHovered;
  @override
  Color get textHoveredText => _textHoveredText;
  @override
  Color get textSplashed => _textSplashed;
  @override
  Color get textSplashedText => _textSplashedText;
}
