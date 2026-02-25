import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:libmonet/libmonet.dart';

/// A complete set of contrast-safe colors derived from a single brand color
/// and a background tone.
///
/// The palette is organized into four **container families**:
///
/// | Family       | Container surface                        |
/// |--------------|------------------------------------------|
/// | background   | The page/canvas background               |
/// | color        | The brand color itself as a surface       |
/// | fill         | A brand-tinted surface on the background  |
/// | text         | Brand text sitting on the background      |
///
/// Each family carries **on-roles** (text, fill/icon, border) and
/// **interactive states** (hovered, splashed) with their own on-roles.
///
/// Naming: `[container][State][OnRole]`.  Examples:
/// - `backgroundText` — neutral text on the background
/// - `fillHoveredText` — text on the hovered fill surface
/// - `colorBorder` — border around the brand color surface
///
/// Brand-tinted roles use the base color's hue/chroma; neutral roles use the
/// background's hue/chroma.  Tones are solved via [contrastingLstar] against
/// the container tone using the configured [Algo] and contrast dial.
///
/// Construction is zero-cost: all colors are lazily computed on first access.
class Palette {
  /// Set to `true` to emit solver diagnostics during development/tests.
  static bool debug = false;

  // ── Construction ──────────────────────────────────────────────

  final Color _baseColor;
  final Color _baseBackground;
  final double? _backgroundToneOverride;
  final double _contrast;
  final Algo _algo;

  /// Prefer [Palette.from] or [Palette.fromColorAndBackground].
  @visibleForTesting
  Palette.base({
    required Color baseColor,
    required Color baseBackground,
    double? backgroundTone,
    required double contrast,
    required Algo algo,
  })  : _baseColor = baseColor,
        _baseBackground = baseBackground,
        _backgroundToneOverride = backgroundTone,
        _contrast = contrast,
        _algo = algo;

  /// Creates a palette from a brand [color] with an explicit [backgroundTone].
  ///
  /// The background surface is synthesized with the brand hue and capped
  /// chroma (≤ 16) so it stays near-neutral.
  factory Palette.from(
    Color color, {
    required double backgroundTone,
    double contrast = 0.5,
    Algo algo = Algo.apca,
  }) {
    final hct = Hct.fromColor(color);
    final bg = Hct.from(hct.hue, math.min(16, hct.chroma), backgroundTone);
    return Palette.base(
      baseColor: color,
      baseBackground: bg.color,
      backgroundTone: backgroundTone,
      contrast: contrast,
      algo: algo,
    );
  }

  /// Creates a palette from an explicit [color] and [background].
  ///
  /// Use when you already have a concrete background color (e.g. a colorful
  /// card).  [Palette.from] is preferred for typical page backgrounds.
  factory Palette.fromColorAndBackground(
    Color color,
    Color background, {
    double contrast = 0.5,
    Algo algo = Algo.apca,
  }) {
    return Palette.base(
      baseColor: color,
      baseBackground: background,
      contrast: contrast,
      algo: algo,
    );
  }

  // ── Derived HCT channels (lazy — keeps construction free) ─────

  late final Hct _baseColorHct = Hct.fromColor(_baseColor);
  late final Hct _baseBackgroundHct = Hct.fromColor(_baseBackground);

  late final double _colorHue = _baseColorHct.hue;
  late final double _colorChroma = _baseColorHct.chroma;
  late final double _colorTone = _baseColorHct.tone;

  late final double _backgroundHue = _baseBackgroundHct.hue;
  late final double _backgroundChroma = _baseBackgroundHct.chroma;
  late final double _backgroundTone =
      _backgroundToneOverride ?? _baseBackgroundHct.tone;

  // ── Per-container polarity ───────────────────────────────
  //
  // Siblings solved against the same container must land on the same side.
  // The *hardest* sibling (text, which needs the most contrast) solves
  // first without constraint.  Its actual result determines the direction
  // that every easier sibling (fill, icon, hover, …) is forced to follow.

  /// Text tone on the background — solved first, unconstrained.
  late final double _bgTextTone =
      _solve(_backgroundTone, Usage.text, _contrast);

  late final ContrastDirection _bgDirection =
      _bgTextTone >= _backgroundTone
          ? ContrastDirection.lighter
          : ContrastDirection.darker;

  /// Text tone on the fill surface — solved first, unconstrained.
  late final double _fillTextTone =
      _solve(_bgFillTone, Usage.text, _contrast);

  late final ContrastDirection _fillDirection =
      _fillTextTone >= _bgFillTone
          ? ContrastDirection.lighter
          : ContrastDirection.darker;

  /// Text tone on the color surface — solved first, unconstrained.
  late final double _colorTextTone =
      _solve(_colorTone, Usage.text, _contrast);

  late final ContrastDirection _colorDirection =
      _colorTextTone >= _colorTone
          ? ContrastDirection.lighter
          : ContrastDirection.darker;

  // ── Contrast dials & thresholds ───────────────────────────────

  /// Hover state uses a lower contrast dial (subtler shift).
  late final double _hoverDial = math.max(_contrast - 0.3, 0.1);

  /// Splash state uses a dial between normal and hover.
  late final double _splashDial = math.max(_contrast - 0.15, 0.25);

  /// Minimum APCA/WCAG contrast required for border visibility.
  late final double _borderContrast =
      _algo.getAbsoluteContrast(_contrast, Usage.border);

  /// Contrast a fg layer needs to be visible on its own (no border help).
  late final double _fgContrast =
      _algo.getAbsoluteContrast(_contrast, Usage.fill);

  // ── Shared intermediate tones ─────────────────────────────────
  //
  // These are the "spine" of the palette.  Each surface is solved against
  // the surface it sits on, forming a dependency chain:
  //
  //   background ──┬── bgFillTone ──┬── fillHoverTone
  //                │                └── fillSplashTone
  //                ├── bgHoverTone
  //                ├── bgSplashTone
  //                └── (baseTone is given, not solved)
  //                     ├── colorHoverTone
  //                     └── colorSplashTone

  /// Fill surface tone on the background.
  late final double _bgFillTone =
      _solve(_backgroundTone, Usage.fill, _contrast, _bgDirection);

  /// Hover overlay tone on the background.
  late final double _bgHoverTone =
      _solve(_backgroundTone, Usage.fill, _hoverDial, _bgDirection);

  /// Splash overlay tone on the background.
  late final double _bgSplashTone =
      _solve(_backgroundTone, Usage.fill, _splashDial, _bgDirection);

  /// Hover overlay tone on the color surface.
  late final double _colorHoverTone =
      _solve(_colorTone, Usage.fill, _hoverDial, _colorDirection);

  /// Splash overlay tone on the color surface.
  late final double _colorSplashTone =
      _solve(_colorTone, Usage.fill, _splashDial, _colorDirection);

  /// Hover overlay tone on the fill surface.
  late final double _fillHoverTone =
      _solve(_bgFillTone, Usage.fill, _hoverDial, _fillDirection);

  /// Splash overlay tone on the fill surface.
  late final double _fillSplashTone =
      _solve(_bgFillTone, Usage.fill, _splashDial, _fillDirection);

  /// Text-hover tone on the background (used by textHovered family).
  late final double _textHoverTone =
      _solve(_backgroundTone, Usage.text, _hoverDial, _bgDirection);

  /// Text-splash tone on the background (used by textSplashed family).
  late final double _textSplashTone =
      _solve(_backgroundTone, Usage.text, _splashDial, _bgDirection);

  // ── Tone solver & color constructors ──────────────────────────

  /// Solve for the tone that achieves [usage]-level contrast against
  /// [containerTone] at the given contrast [dial].
  ///
  /// When [direction] is provided, siblings solved against the same
  /// container are guaranteed to land on the same side.
  double _solve(double containerTone, Usage usage, double dial,
          [ContrastDirection? direction]) =>
      contrastingLstar(
          withLstar: containerTone,
          usage: usage,
          by: _algo,
          contrast: dial,
          forceDirection: direction);

  /// Color at [tone] using the base color's hue and chroma.
  Color _withColorsChroma(double tone) =>
      Hct.colorFrom(_colorHue, _colorChroma, tone);

  /// Color at [tone] using the background's hue and chroma.
  Color _withBackgroundsChroma(double tone) =>
      Hct.colorFrom(_backgroundHue, _backgroundChroma, tone);

  // ═════════════════════════════════════════════════════════════════
  //  BACKGROUND FAMILY
  //  Container: the page/canvas background surface.
  // ═════════════════════════════════════════════════════════════════

  /// The background surface itself (pass-through).
  Color get background => _baseBackground;

  /// Neutral high-contrast text on the background.
  late final Color backgroundText = _withBackgroundsChroma(_bgTextTone);

  /// Neutral medium-contrast fill on the background.
  late final Color backgroundFill = _withBackgroundsChroma(_bgFillTone);

  /// Achromatic border around the background.
  late final Color backgroundBorder = _withBackgroundsChroma(
      _solve(_backgroundTone, Usage.large, _contrast, _bgDirection));

  /// Brand-tinted hover overlay on the background.
  late final Color backgroundHovered = _withColorsChroma(_bgHoverTone);

  /// Brand-tinted splash overlay on the background.
  late final Color backgroundSplashed = _withColorsChroma(_bgSplashTone);

  /// Brand fill sitting on the hover overlay.
  late final Color backgroundHoveredFill =
      _withColorsChroma(_solve(_bgHoverTone, Usage.fill, _contrast));

  /// Brand fill sitting on the splash overlay.
  late final Color backgroundSplashedFill =
      _withColorsChroma(_solve(_bgSplashTone, Usage.fill, _contrast));

  /// Brand text on the hover overlay.
  late final Color backgroundHoveredText =
      _withColorsChroma(_solve(_bgHoverTone, Usage.text, _contrast));

  /// Brand text on the splash overlay.
  late final Color backgroundSplashedText =
      _withColorsChroma(_solve(_bgSplashTone, Usage.text, _contrast));

  /// Border for the hover overlay (must contrast both overlay and background).
  late final Color backgroundHoveredBorder = _overlayBorder(_bgHoverTone);

  /// Border for the splash overlay (must contrast both overlay and background).
  late final Color backgroundSplashedBorder = _overlayBorder(_bgSplashTone);

  // ═════════════════════════════════════════════════════════════════
  //  COLOR FAMILY
  //  Container: the brand color itself, used as a surface (e.g. a FAB).
  // ═════════════════════════════════════════════════════════════════

  /// The brand color surface itself (pass-through).
  Color get color => _baseColor;

  /// High-contrast brand text on the color surface.
  late final Color colorText = _withColorsChroma(_colorTextTone);

  /// Medium-contrast brand icon on the color surface.
  late final Color colorIcon =
      _withColorsChroma(_solve(_colorTone, Usage.fill, _contrast, _colorDirection));

  /// Hover overlay on the color surface.
  late final Color colorHovered = _withColorsChroma(_colorHoverTone);

  /// Splash overlay on the color surface.
  late final Color colorSplashed = _withColorsChroma(_colorSplashTone);

  /// Text on the hovered color surface.
  late final Color colorHoveredText =
      _withColorsChroma(_solve(_colorHoverTone, Usage.text, _contrast));

  /// Text on the splashed color surface.
  late final Color colorSplashedText =
      _withColorsChroma(_solve(_colorSplashTone, Usage.text, _contrast));

  /// Border around the color surface.
  ///
  /// Uses the either-side solver: the border must contrast with at least
  /// one of (color surface, background).  Prefers a subtle shadow tone
  /// close to the surface.
  late final Color colorBorder = _solveEitherSideBorder(
    innerTone: _colorTone,
    baseTone: _colorTone,
    backgroundTone: _backgroundTone,
    requiredContrast: _borderContrast,
    hue: _colorHue,
    chroma: _colorChroma,
  );

  /// Border for the hovered color surface.
  late final Color colorHoveredBorder = _overlayBorder(_colorHoverTone);

  /// Border for the splashed color surface.
  late final Color colorSplashedBorder = _overlayBorder(_colorSplashTone);

  // ═════════════════════════════════════════════════════════════════
  //  FILL FAMILY
  //  Container: a brand-tinted surface on the background (e.g. a card).
  // ═════════════════════════════════════════════════════════════════

  /// Brand fill on the background (medium contrast).
  late final Color fill = _withColorsChroma(_bgFillTone);

  /// High-contrast brand text on the fill surface.
  late final Color fillText = _withColorsChroma(_fillTextTone);

  /// Medium-contrast brand icon on the fill surface.
  late final Color fillIcon =
      _withColorsChroma(_solve(_bgFillTone, Usage.fill, _contrast, _fillDirection));

  /// Hover overlay on the fill surface.
  late final Color fillHovered = _withColorsChroma(_fillHoverTone);

  /// Splash overlay on the fill surface.
  late final Color fillSplashed = _withColorsChroma(_fillSplashTone);

  /// Text on the hovered fill surface.
  late final Color fillHoveredText =
      _withColorsChroma(_solve(_fillHoverTone, Usage.text, _contrast));

  /// Text on the splashed fill surface.
  late final Color fillSplashedText =
      _withColorsChroma(_solve(_fillSplashTone, Usage.text, _contrast));

  /// Border around the fill surface.
  ///
  /// Uses the either-side solver: the border must contrast with at least
  /// one of (fill surface, background).  Prefers a subtle shadow tone
  /// close to the fill.
  late final Color fillBorder = _solveEitherSideBorder(
    innerTone: _bgFillTone,
    baseTone: _colorTone,
    backgroundTone: _backgroundTone,
    requiredContrast: _borderContrast,
    hue: _colorHue,
    chroma: _colorChroma,
  );

  /// Border for the hovered fill surface.
  late final Color fillHoveredBorder = _overlayBorder(_fillHoverTone);

  /// Border for the splashed fill surface.
  late final Color fillSplashedBorder = _overlayBorder(_fillSplashTone);

  // ═════════════════════════════════════════════════════════════════
  //  TEXT FAMILY
  //  Brand text as an interactive target (e.g. a tappable label).
  // ═════════════════════════════════════════════════════════════════

  /// Brand text on the background (high contrast).
  late final Color text = _withColorsChroma(_bgTextTone);

  /// Hovered brand text on the background.
  late final Color textHovered = _withColorsChroma(_textHoverTone);

  /// Splashed brand text on the background.
  late final Color textSplashed = _withColorsChroma(_textSplashTone);

  /// Text on the hovered-text highlight surface.
  late final Color textHoveredText =
      _withColorsChroma(_solve(_textHoverTone, Usage.text, _contrast));

  /// Text on the splashed-text highlight surface.
  late final Color textSplashedText =
      _withColorsChroma(_solve(_textSplashTone, Usage.text, _contrast));

  // ═════════════════════════════════════════════════════════════════
  //  PRIVATE — Border solvers
  // ═════════════════════════════════════════════════════════════════

  /// Overlay-border shortcut used by all `*HoveredBorder` / `*SplashedBorder`
  /// getters.  Returns the base color if it already contrasts against both
  /// [overlayTone] and the background; otherwise solves via
  /// [_twoRefBorderTone].
  Color _overlayBorder(double overlayTone) {
    final vsOverlay = _algo
        .getContrastBetweenLstars(bg: overlayTone, fg: _colorTone)
        .abs();
    final vsBg = _algo
        .getContrastBetweenLstars(bg: _backgroundTone, fg: _colorTone)
        .abs();
    if (vsOverlay >= _borderContrast && vsBg >= _borderContrast) {
      return _baseColor;
    }
    return _withColorsChroma(_twoRefBorderTone(
        refA: overlayTone,
        refB: _backgroundTone,
        requiredContrast: _borderContrast));
  }

  /// Selects a border tone that contrasts with at least one of
  /// ([innerTone], [backgroundTone]).  Prefers darker (shadow-like) tones
  /// close to the inner surface.
  ///
  /// Used by [fillBorder] and [colorBorder].
  Color _solveEitherSideBorder({
    required double innerTone,
    required double baseTone,
    required double backgroundTone,
    required double requiredContrast,
    required double hue,
    required double chroma,
  }) {
    void debugLog(String Function() message) {
      if (Palette.debug) {
        // ignore: avoid_print
        print(message());
      }
    }

    // If the fg already meets fill-level contrast against the background,
    // it's visible on its own — the border IS the fg edge.
    // Check both APCA polarities: the fill was solved in one direction,
    // but visibility works either way.
    final fgVsBg = math.max(
        _algo.getContrastBetweenLstars(bg: backgroundTone, fg: innerTone).abs(),
        _algo.getContrastBetweenLstars(bg: innerTone, fg: backgroundTone).abs());
    if (fgVsBg >= _fgContrast) {
      debugLog(() =>
          'border fast-path: fg visible vs bg '
          '(|Lc|=${fgVsBg.toStringAsFixed(1)} >= '
          '${_fgContrast.toStringAsFixed(1)})');
      return Hct.colorFrom(hue, chroma, innerTone);
    }

    // Candidate tones (avoid duplicates).
    // Use "unsafe" variants that return out-of-bounds values when impossible,
    // so we can filter consistently.
    final Set<double> candidateSet = {};
    // Background-side candidates
    final bgLighterTone = _lighterCandidate(backgroundTone, requiredContrast);
    final bgDarkerTone = _darkerCandidate(backgroundTone, requiredContrast);
    if (bgLighterTone <= 100) candidateSet.add(bgLighterTone.clamp(0, 100));
    if (bgDarkerTone >= 0) candidateSet.add(bgDarkerTone.clamp(0, 100));
    // Inner-side candidates
    final inLighterTone = (_algo == Algo.apca)
        ? lighterBackgroundLstarUnsafe(innerTone, requiredContrast)
        : lighterLstarUnsafe(
            lstar: innerTone, contrastRatio: requiredContrast);
    final inDarkerTone = (_algo == Algo.apca)
        ? darkerBackgroundLstarUnsafe(innerTone, -requiredContrast)
        : darkerLstarUnsafe(
            lstar: innerTone, contrastRatio: requiredContrast);
    if (inLighterTone <= 100) candidateSet.add(inLighterTone.clamp(0, 100));
    if (inDarkerTone >= 0) candidateSet.add(inDarkerTone.clamp(0, 100));
    // Include base tone for smooth transitions
    candidateSet.add(baseTone.clamp(0, 100));

    final candidateTones = candidateSet.toList();

    bool hasValidContrast(double t) {
      final lcBg =
          _algo.getContrastBetweenLstars(bg: backgroundTone, fg: t).abs();
      final lcIn =
          _algo.getContrastBetweenLstars(bg: innerTone, fg: t).abs();
      return lcBg >= requiredContrast || lcIn >= requiredContrast;
    }

    final validCandidates = candidateTones.where(hasValidContrast).toList();

    // Prefer darker tones (shadow-like) when available — they look more
    // natural as borders.  Only fall back to lighter if no darker ones work.
    final darkerValid = validCandidates.where((t) => t < innerTone).toList();
    final lighterValid =
        validCandidates.where((t) => t >= innerTone).toList();
    final preferredCandidates =
        darkerValid.isNotEmpty ? darkerValid : lighterValid;

    debugLog(() =>
        'borderSolve: inner=${innerTone.toStringAsFixed(1)} '
        'bg=${backgroundTone.toStringAsFixed(1)} '
        'req=${requiredContrast.toStringAsFixed(1)}');
    debugLog(() =>
        'Candidates: ${candidateTones.map((t) => t.toStringAsFixed(1)).toList()}');
    for (final t in candidateTones) {
      final lcBg =
          _algo.getContrastBetweenLstars(bg: backgroundTone, fg: t).abs();
      final lcIn =
          _algo.getContrastBetweenLstars(bg: innerTone, fg: t).abs();
      final best = math.max(lcBg, lcIn);
      final cost = math.max(0.0, requiredContrast - best);
      final dIn = (t - innerTone).abs();
      final dBg = (t - backgroundTone).abs();
      debugLog(() =>
          '  cand T${t.toStringAsFixed(1)} '
          'lcBg=${lcBg.toStringAsFixed(1)} lcIn=${lcIn.toStringAsFixed(1)} '
          'cost=${cost.toStringAsFixed(1)} '
          'dInner=${dIn.toStringAsFixed(1)} dBg=${dBg.toStringAsFixed(1)}');
    }
    debugLog(() =>
        'Valid     : ${validCandidates.map((t) => t.toStringAsFixed(1)).toList()}');
    debugLog(() =>
        'Darker    : ${darkerValid.map((t) => t.toStringAsFixed(1)).toList()}');
    debugLog(() =>
        'Preferred : ${preferredCandidates.map((t) => t.toStringAsFixed(1)).toList()}');

    double calculateTotalDelta(double tone) =>
        (tone - innerTone).abs() + (tone - backgroundTone).abs();

    if (preferredCandidates.isEmpty) {
      // Evaluate extremes by either-side cost; tie → smaller total delta.
      double costFor(double t) {
        final lcBg = _algo
            .getContrastBetweenLstars(bg: backgroundTone, fg: t)
            .abs();
        final lcIn =
            _algo.getContrastBetweenLstars(bg: innerTone, fg: t).abs();
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
          'Fallback extremes: cost(T0)=${costBlack.toStringAsFixed(1)} '
          'cost(T100)=${costWhite.toStringAsFixed(1)} '
          '-> T${fb.toStringAsFixed(0)}');
      return Hct.colorFrom(hue, chroma, fb.toDouble());
    }

    // Primary selection: lexicographic on (cost, totalDist, distToInner, distToBg).
    double bestTone = preferredCandidates.first;
    double bestCost = double.infinity;
    double bestTotalDist = double.infinity;
    double bestDInner = double.infinity;
    double bestDBg = double.infinity;
    for (final t in preferredCandidates) {
      final lcBg =
          _algo.getContrastBetweenLstars(bg: backgroundTone, fg: t).abs();
      final lcIn =
          _algo.getContrastBetweenLstars(bg: innerTone, fg: t).abs();
      final best = math.max(lcBg, lcIn);
      final cost = math.max(0.0, requiredContrast - best);
      final dIn = (t - innerTone).abs();
      final dBg = (t - backgroundTone).abs();
      final total = dIn + dBg;

      if (_isBetterCandidate(
        cost: cost,
        totalDist: total,
        distToInner: dIn,
        distToBg: dBg,
        bestCost: bestCost,
        bestTotalDist: bestTotalDist,
        bestDistToInner: bestDInner,
        bestDistToBg: bestDBg,
      )) {
        bestCost = cost;
        bestTotalDist = total;
        bestDInner = dIn;
        bestDBg = dBg;
        bestTone = t;
      }
    }
    debugLog(() =>
        'Selected bestTone T${bestTone.toStringAsFixed(1)} '
        'cost=${bestCost.toStringAsFixed(1)} '
        'totalDist=${bestTotalDist.toStringAsFixed(1)} '
        'dInner=${bestDInner.toStringAsFixed(1)} '
        'dBg=${bestDBg.toStringAsFixed(1)}');
    return Hct.colorFrom(hue, chroma, bestTone);
  }

  /// Lexicographic comparison for border tone selection.
  /// Priority: cost → totalDist → distToInner → distToBackground.
  static bool _isBetterCandidate({
    required double cost,
    required double totalDist,
    required double distToInner,
    required double distToBg,
    required double bestCost,
    required double bestTotalDist,
    required double bestDistToInner,
    required double bestDistToBg,
  }) {
    const epsilon = 1e-6;
    if (cost < bestCost - epsilon) return true;
    if (cost > bestCost + epsilon) return false;
    if (totalDist < bestTotalDist - epsilon) return true;
    if (totalDist > bestTotalDist + epsilon) return false;
    if (distToInner < bestDistToInner - epsilon) return true;
    if (distToInner > bestDistToInner + epsilon) return false;
    return distToBg < bestDistToBg - epsilon;
  }

  // ═════════════════════════════════════════════════════════════════
  //  PRIVATE — Two-reference border solver
  // ═════════════════════════════════════════════════════════════════

  /// APCA/WCAG candidate tones (lighter/darker) around a reference.
  double _lighterCandidate(double tone, double requiredContrast) =>
      (_algo == Algo.apca)
          ? lighterTextLstarUnsafe(tone, -requiredContrast)
          : lighterLstarUnsafe(
              lstar: tone, contrastRatio: requiredContrast);
  double _darkerCandidate(double tone, double requiredContrast) =>
      (_algo == Algo.apca)
          ? darkerTextLstarUnsafe(tone, requiredContrast)
          : darkerLstarUnsafe(
              lstar: tone, contrastRatio: requiredContrast);

  /// Finds a tone that contrasts with two references ([refA] and [refB]).
  /// Prefers lighter/darker relative to [refA]; ties broken by minimal
  /// total distance to both references.
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

  /// Checks whether [tone] has sufficient contrast with at least one of
  /// [backgroundTone] or [colorTone], considering all four polarity
  /// combinations for APCA.
  bool _hasValidContrastHelper({
    required double tone,
    required double backgroundTone,
    required double colorTone,
    required double requiredContrast,
  }) {
    final bgFg =
        _algo.getContrastBetweenLstars(bg: backgroundTone, fg: tone);
    final colorFg =
        _algo.getContrastBetweenLstars(bg: colorTone, fg: tone);
    final toneBgBg =
        _algo.getContrastBetweenLstars(bg: tone, fg: backgroundTone);
    final toneBgColor =
        _algo.getContrastBetweenLstars(bg: tone, fg: colorTone);

    return (_algo == Algo.apca)
        ? (bgFg.abs() >= requiredContrast ||
            colorFg.abs() >= requiredContrast ||
            toneBgBg.abs() >= requiredContrast ||
            toneBgColor.abs() >= requiredContrast)
        : (bgFg >= requiredContrast ||
            colorFg >= requiredContrast ||
            toneBgBg >= requiredContrast ||
            toneBgColor >= requiredContrast);
  }

  // ── Equality ──────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Palette &&
          runtimeType == other.runtimeType &&
          _baseColor.argb == other._baseColor.argb &&
          _baseBackground.argb == other._baseBackground.argb &&
          _contrast == other._contrast &&
          _algo == other._algo &&
          _backgroundToneOverride == other._backgroundToneOverride;

  @override
  int get hashCode => Object.hash(
      runtimeType,
      _baseColor.argb,
      _baseBackground.argb,
      _contrast,
      _algo,
      _backgroundToneOverride);
}
