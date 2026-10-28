import 'dart:math' as math;

import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/colorspaces/hct.dart';
import 'package:libmonet/contrast/apca.dart';
import 'package:libmonet/contrast/contrast.dart';
import 'package:libmonet/core/argb_srgb_xyz_lab.dart';
import 'package:libmonet/util/lru_cache.dart';

/// Drawing over something you didn't choose: a wallpaper, a video frame, a
/// gradient, a map.
///
/// A palette's background is one color the theme chose. [AnyBackground] is
/// whatever is actually behind the UI, as real pixels. Build one per image,
/// then ask it:
///  * [AnyBackground.scrimFor]: how to make text or an icon legible over it.
///    Draw the answer as a rect ([Scrim.paintArgb]), around the glyph
///    ([Scrim.shadowsWithStroke]), or as stacked shadows ([Scrim.shadows]).
///  * [AnyBackground.sharedBorder]: one border tone for surfaces drawn
///    together over it, so they read at one elevation.
///
/// Everything here is ARGB ints; Flutter types live in
/// `theming/over_image_flutter.dart`. See ADR-001.

/// The pixels behind some UI, plus the contrast policy to judge them by.
///
/// The pixels are reduced lazily, once. Answers are cached, 64 per method.
final class AnyBackground {
  /// [argbs] must be real sampled pixels from what's behind the UI. If
  /// downscaling first, use min/max pooling, never averaging: averaged
  /// black and white pixels make a mid-gray that hides both. Quantizer
  /// clusters are averages too. Alpha is ignored; every pixel is opaque.
  ///
  /// The list is read on first use; don't modify it afterwards.
  ///
  /// Empty means nothing is known about what's behind: see
  /// [AnyBackground.unknown].
  AnyBackground(this._argbs, {required this.algo, required this.contrast}) {
    if (contrast.isNaN || contrast <= 0.0 || contrast > 1.0) {
      throw ArgumentError.value(contrast, 'contrast', 'must be in (0, 1]');
    }
  }

  /// Nothing is known about what's behind.
  ///
  /// [scrimFor] answers for any possible pixel. [sharedBorder] skips the
  /// background and separates each border from its own surface.
  AnyBackground.unknown({required Algo algo, required double contrast})
    : this(const [], algo: algo, contrast: contrast);

  final List<int> _argbs;
  final Algo algo;

  /// libmonet's 0..1 contrast dial; see [Algo.getAbsoluteContrast].
  final double contrast;

  bool get isUnknown => _argbs.isEmpty;

  /// Unique opaque pixels, sorted. For unknown, black and white: blending
  /// is monotone per channel and contrast depends only on luminance, so
  /// every possible pixel's blend lies between theirs.
  late final List<int> _pixels = isUnknown
      ? const [_black, _white]
      : ({for (final argb in _argbs) 0xFF000000 | argb}.toList()..sort());

  /// Unique luminances in [algo]'s own space, sorted. Empty when unknown.
  late final List<double> _luminances = isUnknown
      ? const []
      : ({for (final argb in _pixels) _luminance(algo, argb)}.toList()..sort());

  final _scrims = LruCache<(int, Usage, int?), Scrim>(capacity: 64);
  final _borders = LruCache<_BorderKey, SharedBorder>(capacity: 64);

  /// The minimum-opacity scrim that makes [contentArgb] meet [usage]'s
  /// contrast against every pixel, and keeps meeting it at every opacity
  /// above, so callers may round up freely.
  ///
  /// [scrimArgb] fixes the scrim color, e.g. brand-tinted; null tries black
  /// and white and returns the cheaper. A fixed color can be infeasible:
  /// at opacity 1 the background is the scrim color itself.
  Scrim scrimFor(int contentArgb, {Usage usage = Usage.text, int? scrimArgb}) {
    return _scrims.putIfAbsent((
      contentArgb,
      usage,
      scrimArgb,
    ), () => _solveScrim(contentArgb, usage, scrimArgb));
  }

  Scrim _solveScrim(int content, Usage usage, int? scrimArgb) {
    final target = algo.getAbsoluteContrast(contrast, usage);
    // Unknown stands for every pixel between black and white. One of them
    // matches the content's luminance until the scrim lifts them all to one
    // side, so a mixed-polarity pass can't happen and isn't reported.
    final canMix = !isUnknown;
    Scrim solve(int scrim) =>
        _solveForScrimColor(content, _pixels, target, algo, scrim, canMix);
    if (scrimArgb != null) return solve(scrimArgb);
    final black = solve(_black);
    final white = solve(_white);
    if (black.meetsTarget && white.meetsTarget) {
      return black.opacity <= white.opacity ? black : white;
    }
    if (black.meetsTarget) return black;
    if (white.meetsTarget) return white;
    // Infeasible either way: best effort is whichever contrasts harder.
    return black.worstContrast >= white.worstContrast ? black : white;
  }

  /// One border tone for surfaces drawn together over this background, so
  /// they read at one elevation. Each border keeps its surface's hue.
  ///
  /// [surfaceArgbs] has each surface's resting color; it sets that border's
  /// hue and chroma. Hovered and pressed states are deliberately excluded:
  /// the border doesn't change with state, and a pressed surface briefly
  /// meeting its border just reads as the same elevation.
  ///
  /// A tone works if every border clears [usage]'s contrast against every
  /// pixel ([SharedBorder.clearsBackground]), or else against its own
  /// surface. The first lets a surface that already stands out
  /// go without a visible border. Preferred: just darker than the darkest
  /// surface, then just lighter than the lightest, then between.
  ///
  /// [colorModel] is the model the surfaces' hues are read and drawn in.
  SharedBorder sharedBorder(
    List<int> surfaceArgbs, {
    Usage usage = Usage.border,
    ColorModel colorModel = ColorModel.kDefault,
  }) {
    if (surfaceArgbs.isEmpty) {
      throw ArgumentError.value(surfaceArgbs, 'surfaceArgbs', 'is empty');
    }
    return _borders.putIfAbsent(
      _BorderKey(surfaceArgbs, usage, colorModel),
      () => _solveSharedBorder(surfaceArgbs, usage, colorModel),
    );
  }

  SharedBorder _solveSharedBorder(
    List<int> surfaces,
    Usage usage,
    ColorModel model,
  ) {
    final target = algo.getAbsoluteContrast(contrast, usage);
    final rests = [for (final s in surfaces) Hct.fromInt(s, model: model)];
    final surfaceYs = [for (final s in surfaces) _luminance(algo, s)];
    final tones = [for (final s in surfaces) lstarFromArgb(s)];
    final darkest = tones.reduce(math.min);
    final lightest = tones.reduce(math.max);

    final borders = <int, List<int>>{};
    List<int> bordersAt(int t) => borders.putIfAbsent(t, () {
      return [
        for (final h in rests)
          Hct.from(h.hue, h.chroma, t.toDouble(), model: model).toInt(),
      ];
    });

    // Weakest contrast backing each guarantee at tone t.
    double backgroundWorst(int t) {
      if (_luminances.isEmpty) return double.negativeInfinity;
      var worst = double.infinity;
      for (final b in bordersAt(t)) {
        worst = math.min(worst, _nearestContrast(_luminance(algo, b)));
      }
      return worst;
    }

    double surfacesWorst(int t) {
      final bs = bordersAt(t);
      var worst = double.infinity;
      for (var i = 0; i < bs.length; i++) {
        worst = math.min(
          worst,
          _contrastOfYs(algo, _luminance(algo, bs[i]), surfaceYs[i]),
        );
      }
      return worst;
    }

    SharedBorder at(int t) {
      final bg = backgroundWorst(t);
      final clears = bg >= target;
      return SharedBorder._(
        tone: t.toDouble(),
        borderArgbs: List.unmodifiable(bordersAt(t)),
        clearsBackground: clears,
        meetsTarget: clears || surfacesWorst(t) >= target,
        worstContrast: clears ? bg : surfacesWorst(t),
      );
    }

    bool valid(int t) =>
        backgroundWorst(t) >= target || surfacesWorst(t) >= target;

    for (var t = darkest.floor(); t >= 0; t--) {
      if (valid(t)) return at(t);
    }
    for (var t = lightest.ceil(); t <= 100; t++) {
      if (valid(t)) return at(t);
    }
    final mean = tones.reduce((a, b) => a + b) / tones.length;
    int? between;
    for (var t = darkest.ceil(); t <= lightest.floor(); t++) {
      if (valid(t) &&
          (between == null || (t - mean).abs() < (between - mean).abs())) {
        between = t;
      }
    }
    if (between != null) return at(between);

    // Nothing works: the tone whose better guarantee is strongest.
    var best = 0;
    var bestWorst = double.negativeInfinity;
    for (var t = 0; t <= 100; t++) {
      final w = math.max(backgroundWorst(t), surfacesWorst(t));
      if (w > bestWorst) {
        bestWorst = w;
        best = t;
      }
    }
    return at(best);
  }

  /// Weakest contrast of luminance [y] against any pixel. Contrast grows
  /// with luminance distance on each side, so only the nearest luminance
  /// below and above can be weakest.
  double _nearestContrast(double y) {
    final ys = _luminances;
    var lo = 0, hi = ys.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (ys[mid] < y) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    var worst = double.infinity;
    if (lo < ys.length) worst = math.min(worst, _contrastOfYs(algo, y, ys[lo]));
    if (lo > 0) worst = math.min(worst, _contrastOfYs(algo, y, ys[lo - 1]));
    return worst;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnyBackground &&
          isUnknown == other.isUnknown &&
          algo == other.algo &&
          contrast == other.contrast &&
          _listEquals(_pixels, other._pixels);

  @override
  late final int hashCode = Object.hash(
    isUnknown,
    algo,
    contrast,
    Object.hashAll(_pixels),
  );

  @override
  String toString() => isUnknown
      ? 'AnyBackground.unknown($algo, $contrast)'
      : 'AnyBackground(${_pixels.length} pixels, $algo, $contrast)';
}

/// Which way the content reads once the scrim is applied. Useful for
/// choosing decorations, e.g. underlines, that match.
enum Polarity {
  /// Every blended pixel is darker than the content.
  lightOnDark,

  /// Every blended pixel is lighter than the content.
  darkOnLight,
}

/// A translucent layer that makes content legible over [AnyBackground].
final class Scrim {
  const Scrim._({
    required this.scrimArgb,
    required this.opacity,
    required this.meetsTarget,
    required this.worstContrast,
    required this.polarity,
    required this.mixedPolarityRejected,
  });

  /// The scrim's color: black or white, or the caller's choice.
  final int scrimArgb;

  /// 0..1, quantized to 1/255 so 8-bit compositing is exact.
  final double opacity;

  /// False means no opacity of [scrimArgb] reaches the target; [opacity] is
  /// then a best effort, 1.0. Check before trusting: drop a custom scrim
  /// color, or revisit the design. Don't ship it silently.
  final bool meetsTarget;

  /// Weakest absolute contrast over every pixel at [opacity].
  final double worstContrast;

  final Polarity polarity;

  /// True when a lower opacity passed per pixel but left pixels on both
  /// sides of the content, e.g. mid-gray text on a black and white
  /// checkerboard. That reads badly, so the solve kept going until every
  /// pixel sat on one side. Nothing to act on; explains the extra cost.
  final bool mixedPolarityRejected;

  bool get isNeeded => opacity > 0;

  /// [scrimArgb] with [opacity] as its alpha. Fill a rect with it.
  int get paintArgb =>
      ((opacity * 255).round() << 24) | (scrimArgb & 0x00FFFFFF);

  /// Draw this scrim hugging the glyph: its shape widened by [stroke]
  /// pixels, then blurred by [blurRadius], painted under it.
  ///
  /// Widening keeps the area under and around the glyph solid before the
  /// blur, so the glyph edge gets exactly [opacity]: no approximation. Use
  /// where the renderer can widen a shape (a stroke, BoxShadow spread, CSS
  /// box-shadow). The defaults suit body text; scale with glyph size.
  ShadowsWithStroke shadowsWithStroke({
    double stroke = 1.0,
    double blurRadius = 4.0,
  }) {
    if (stroke.isNaN || stroke < 0 || blurRadius.isNaN || blurRadius < 0) {
      throw ArgumentError('stroke and blurRadius must be non-negative');
    }
    return ShadowsWithStroke._(this, stroke, blurRadius);
  }

  /// Draw this scrim as stacked blurred copies of the glyph, for renderers
  /// that can't widen it (Flutter text Shadow, CSS text-shadow).
  /// Approximate; prefer [shadowsWithStroke].
  ///
  /// [blurRadius] is the blur you intend to draw (Skia/CSS radius). It is
  /// rounded to a whole pixel; draw with [Shadows.blurRadius].
  ///
  /// [contentRadius] is half the stroke thickness being protected, roughly
  /// half the font's stem width. The default, -1, assumes strokes at least
  /// as wide as the blur. Thinner strokes need more layers: pass the real
  /// value, or [Shadows.meetsTarget] overstates the result.
  ///
  /// [maxLayers] caps the stack. Past it, [Shadows.meetsTarget] is false
  /// and the layers are a best effort.
  Shadows shadows({
    required double blurRadius,
    double contentRadius = -1.0,
    int maxLayers = 8,
  }) {
    if (blurRadius.isNaN || blurRadius.isInfinite || blurRadius < 0) {
      throw ArgumentError.value(blurRadius, 'blurRadius');
    }
    if (contentRadius.isNaN || contentRadius.isInfinite) {
      throw ArgumentError.value(contentRadius, 'contentRadius');
    }
    if (maxLayers < 1) {
      throw ArgumentError.value(maxLayers, 'maxLayers');
    }
    final alpha = opacity;
    if (alpha == 0.0) {
      return Shadows._(this, 0, const [], meetsTarget, 0);
    }

    // Round the radius once: sigma and coverage must come from the same
    // whole-pixel radius the caller draws with.
    final r = blurRadius.round();
    if (r == 0) {
      // Needed, but a zero-blur shadow is invisible.
      return Shadows._(this, 0, const [], false, 0);
    }

    // Edge coverage: the Gaussian edge profile at the first outside pixel's
    // center, 0.5px past the edge. The content spans [0.5, 0.5 + 2*cr] away
    // from it. Calibrated against Skia pixels in
    // shadow_pixel_calibration_test.dart.
    final sigma = _convertRadiusToSigma(r.toDouble());
    final cr = contentRadius < 0 ? r : contentRadius.round();
    final e = contentRadius < 0
        ? 1.0 - _phi(0.5 / sigma)
        : _phi((0.5 + 2.0 * cr) / sigma) - _phi(0.5 / sigma);
    if (e <= 0.0) {
      return Shadows._(this, r.toDouble(), const [], false, e);
    }

    // n full layers reach 1 - (1-e)^n at the first outside pixel, so the
    // fewest that reach alpha is ceil(log(1 - alpha) / log(1 - e)).
    // alpha == 1 is unreachable; the cap reports shortfalls via meetsTarget.
    final n = alpha >= 1.0
        ? maxLayers + 1
        : (math.log(1 - alpha) / math.log(1 - e)).ceil().clamp(
            1,
            maxLayers + 1,
          );
    if (n > maxLayers) {
      return Shadows._(
        this,
        r.toDouble(),
        List.filled(maxLayers, 1.0),
        false,
        e,
      );
    }
    // Even split hits alpha exactly; round up to the next 1/255 so the drawn
    // stack never lands below the proven minimum.
    final perLayerRaw = (1 - math.pow(1 - alpha, 1 / n)) / e;
    final perLayer = (perLayerRaw * 255).ceil().clamp(0, 255) / 255.0;
    return Shadows._(
      this,
      r.toDouble(),
      List.filled(n, perLayer),
      meetsTarget,
      e,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Scrim &&
      scrimArgb == other.scrimArgb &&
      opacity == other.opacity &&
      meetsTarget == other.meetsTarget &&
      worstContrast == other.worstContrast &&
      polarity == other.polarity &&
      mixedPolarityRejected == other.mixedPolarityRejected;

  @override
  int get hashCode => Object.hash(
    scrimArgb,
    opacity,
    meetsTarget,
    worstContrast,
    polarity,
    mixedPolarityRejected,
  );
}

/// A [Scrim] drawn hugging the glyph; see [Scrim.shadowsWithStroke].
///
/// To draw: widen the glyph by [stroke] (e.g. stroke it at 2 × [stroke]),
/// blur by [blurRadius] keeping the widened band solid, and paint it in
/// [Scrim.scrimArgb] at [Scrim.opacity] under the glyph.
final class ShadowsWithStroke {
  const ShadowsWithStroke._(this.scrim, this.stroke, this.blurRadius);

  final Scrim scrim;
  final double stroke;
  final double blurRadius;

  /// Gaussian sigma for [blurRadius], as Skia converts it.
  double get blurSigma => _convertRadiusToSigma(blurRadius);
}

/// A [Scrim] as stacked blurred copies of the glyph; see [Scrim.shadows].
///
/// To draw: one zero-offset shadow per [layerOpacities] entry, in
/// [Scrim.scrimArgb], blurred by [blurRadius], under the glyph.
final class Shadows {
  const Shadows._(
    this.scrim,
    this.blurRadius,
    this.layerOpacities,
    this.meetsTarget,
    this.edgeCoverage,
  );

  final Scrim scrim;

  /// The rounded radius to draw every layer with.
  final double blurRadius;

  /// One alpha per layer, all equal. Empty when nothing needs drawing.
  final List<double> layerOpacities;

  /// Whether drawing this is expected to meet the target. Unlike
  /// [Scrim.meetsTarget], which is exact, this rests on a model of blur
  /// falloff calibrated on long straight edges; corners and very thin
  /// strokes deviate. False also when the scrim is infeasible, the blur is
  /// zero, or the layer cap was hit.
  final bool meetsTarget;

  /// Modeled share of one layer's alpha landing on the first pixel outside
  /// the glyph. For audits and golden tests.
  final double edgeCoverage;
}

/// One border tone for surfaces drawn together; see
/// [AnyBackground.sharedBorder].
final class SharedBorder {
  const SharedBorder._({
    required this.tone,
    required this.borderArgbs,
    required this.clearsBackground,
    required this.meetsTarget,
    required this.worstContrast,
  });

  /// The shared tone, 0..100.
  final double tone;

  /// One border per surface, in the same order, each in its surface's hue.
  final List<int> borderArgbs;

  /// True: every border clears every pixel. False: each border clears its
  /// own surface instead.
  final bool clearsBackground;

  /// False: no tone works; this is the strongest best effort.
  final bool meetsTarget;

  /// Weakest contrast backing the guarantee: against the pixels if
  /// [clearsBackground], else against each border's own surface.
  final double worstContrast;

  @override
  bool operator ==(Object other) =>
      other is SharedBorder &&
      tone == other.tone &&
      _listEquals(borderArgbs, other.borderArgbs) &&
      clearsBackground == other.clearsBackground &&
      meetsTarget == other.meetsTarget &&
      worstContrast == other.worstContrast;

  @override
  int get hashCode => Object.hash(
    tone,
    Object.hashAll(borderArgbs),
    clearsBackground,
    meetsTarget,
    worstContrast,
  );
}

// =============================================================================
// Internals.
// =============================================================================

const _white = 0xFFFFFFFF;
const _black = 0xFF000000;

final class _BorderKey {
  _BorderKey(List<int> surfaces, this.usage, this.model)
    : _flat = List.unmodifiable(surfaces);

  final List<int> _flat;
  final Usage usage;
  final ColorModel model;

  @override
  bool operator ==(Object other) =>
      other is _BorderKey &&
      usage == other.usage &&
      model == other.model &&
      _listEquals(_flat, other._flat);

  @override
  late final int hashCode = Object.hash(usage, model, Object.hashAll(_flat));
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Luminance in [algo]'s own space: APCA's per-channel Y, or WCAG's Y.
double _luminance(Algo algo, int argb) => switch (algo) {
  Algo.apca => apcaYFromArgb(argb),
  Algo.wcag21 => yFromArgb(argb),
};

/// Absolute contrast between two luminances, stronger polarity. Borders
/// aren't text, so either direction counts.
double _contrastOfYs(Algo algo, double a, double b) => switch (algo) {
  Algo.apca => math.max(
    apcaContrastOfApcaY(a, b).abs(),
    apcaContrastOfApcaY(b, a).abs(),
  ),
  // yFromArgb is 0..100; WCAG's 0.05 offset scales to 5.
  Algo.wcag21 => (math.max(a, b) + 5.0) / (math.min(a, b) + 5.0),
};

/// 8-bit source-over blend of [scrim] at alpha [a] (0..255) onto opaque [bg].
int _blendArgb(int bg, int scrim, int a) {
  int ch(int shift) {
    final b = (bg >> shift) & 0xFF;
    final s = (scrim >> shift) & 0xFF;
    return (((255 - a) * b + a * s) / 255).round();
  }

  return 0xFF000000 | (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

class _Outcome {
  const _Outcome(this.allPass, this.oneSided, this.worstAbs, this.polarity);
  final bool allPass; // every pixel meets |contrast| >= target
  final bool oneSided; // and every pixel is on the same side of the content
  final double worstAbs;
  final Polarity polarity;
}

_Outcome _evaluate(
  int content,
  List<int> pixels,
  double target,
  Algo algo,
  int scrim,
  int a,
) {
  final contentY = _luminance(algo, content);
  var allPass = true;
  var anyLow = false, anyHigh = false;
  var worst = double.infinity;
  for (final px in pixels) {
    final blended = _blendArgb(px, scrim, a);
    final c = algo.contrastBetweenArgbs(bgArgb: blended, fgArgb: content).abs();
    if (c < worst) worst = c;
    if (c < target) allPass = false;
    if (_luminance(algo, blended) < contentY) {
      anyLow = true;
    } else {
      anyHigh = true;
    }
  }
  return _Outcome(
    allPass,
    !(anyLow && anyHigh),
    worst,
    anyHigh && !anyLow ? Polarity.darkOnLight : Polarity.lightOnDark,
  );
}

Scrim _solveForScrimColor(
  int content,
  List<int> pixels,
  double target,
  Algo algo,
  int scrim,
  bool canMix,
) {
  // Evaluate every alpha; invert nothing. 256 x N cheap evaluations.
  final outcomes = List<_Outcome>.generate(
    256,
    (a) => _evaluate(content, pixels, target, algo, scrim, a),
  );

  // Lowest alpha such that it and every higher alpha passes one-sided.
  // Blended luminance isn't monotone in alpha for arbitrary scrim colors;
  // the downward scan keeps "solved alpha and above are safe" anyway.
  int? solved;
  for (var a = 255; a >= 0; a--) {
    final o = outcomes[a];
    if (o.allPass && o.oneSided) {
      solved = a;
    } else {
      break;
    }
  }

  if (solved == null) {
    return Scrim._(
      scrimArgb: scrim,
      opacity: 1.0,
      meetsTarget: false,
      worstContrast: outcomes[255].worstAbs,
      polarity: outcomes[255].polarity,
      mixedPolarityRejected: false,
    );
  }

  var mixed = false;
  for (var a = 0; canMix && a < solved; a++) {
    final o = outcomes[a];
    if (o.allPass && !o.oneSided) {
      mixed = true;
      break;
    }
  }

  final at = outcomes[solved];
  return Scrim._(
    scrimArgb: scrim,
    opacity: solved / 255.0,
    meetsTarget: true,
    worstContrast: at.worstAbs,
    polarity: at.polarity,
    mixedPolarityRejected: mixed,
  );
}

/// Φ(z), the standard normal CDF. A Gaussian blur turns a hard edge into
/// this profile, so "how much shadow lands d pixels out" is one Φ call.
double _phi(double z) => 0.5 * (1 + _erf(z / math.sqrt2));

/// erf, Abramowitz & Stegun 7.1.26: max error 1.5e-7, far below the 1/255
/// alpha quantum. Keep bit-identical with js/src/over-image.ts.
double _erf(double x) {
  final sign = x < 0 ? -1.0 : 1.0;
  final ax = x.abs();
  const p = 0.3275911;
  final t = 1 / (1 + p * ax);
  final y =
      1 -
      ((((1.061405429 * t - 1.453152027) * t + 1.421413741) * t - 0.284496736) *
                  t +
              0.254829592) *
          t *
          math.exp(-ax * ax);
  return sign * y;
}

/// Blur radius to the sigma Skia blurs with
/// (SkBlurMask::ConvertRadiusToSigma), so the model and the render agree.
/// <https://github.com/google/skia/blob/bb5b77db51d2e149ee66db284903572a5aac09be/src/effects/SkBlurMask.cpp#L23>
double _convertRadiusToSigma(double radius) =>
    radius > 0 ? radius * 0.57735 + 0.5 : 0;
