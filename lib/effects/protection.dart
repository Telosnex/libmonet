import 'dart:math' as math;

import 'package:libmonet/contrast/apca.dart';
import 'package:libmonet/contrast/contrast.dart';
import 'package:libmonet/core/argb_srgb_xyz_lab.dart';

/// Contrast protection: make foreground text/icons legible over
/// arbitrary, possibly busy backgrounds by putting a translucent layer
/// ("protection") between them, at the minimum opacity that works.
///
/// Three entry points, one solver:
///  * [getProtectionOpacity] — the core. Returns a scrim color and opacity;
///    fill a rect/gradient behind the content with it.
///  * [getHalo] — the same guarantee shaped to hug the glyph: dilate the
///    glyph, blur, paint underneath. Preferred when the renderer can do it.
///  * [getStackedShadowSpec] — the same guarantee approximated with plain
///    Gaussian shadows, for renderers that can't draw a stroke: ex. CSS 
///    `text-shadow` / Flutter `Shadow`, versus CSS `box-shadow` and Flutter 
///    `BoxShadow`, both of which accept a spread radius.
/// INPUT CONTRACT: `backgroundArgbs` must be real sampled pixels from the
/// region under the content. If downscaling first, use min/max pooling, never
/// averaging (averaged black+white pixels hallucinate a mid-gray that hides
/// both extremes). Quantizer palette entries are cluster centers — averages —
/// acceptable for theming, not for protection. Alpha bits on all input
/// colors are ignored: every color is treated as opaque (ADR-001 D-6).

/// Which side of the foreground's luminance the whole background ends up on
/// once the scrim is applied: [low] = background darker than the foreground
/// (light-on-dark), [high] = background lighter (dark-on-light). Useful for
/// choosing decorations (underlines, selection colors) that match the regime.
enum ClearedSide { low, high }

class ProtectionResult {
  /// ARGB of the protection layer (black/white in auto mode, or the caller's
  /// [protectionArgb]).
  final int protectionArgb;

  /// Solved opacity, quantized to 1/255 (matches 8-bit compositing exactly).
  final double opacity;

  /// True when [opacity] genuinely delivers the requested contrast.
  ///
  /// False means NO opacity of this scrim color can; [opacity] is then the
  /// best effort (1.0). Check this before trusting the result: on false,
  /// drop the custom [protectionArgb] (auto black/white always succeeds for
  /// non-mid foregrounds) or revisit the design. Don't ship it silently.
  final bool meetsTarget;

  /// Worst-case |contrast| over all provided backgrounds at [opacity].
  final double achievedContrast;

  /// Side of the foreground's luminance on which all backgrounds landed.
  final ClearedSide clearedSide;

  /// Diagnostic: true when a LOWER opacity technically passed per-pixel
  /// contrast but with backgrounds on both sides of the foreground (e.g.
  /// mid-tone text over a black+white checkerboard). Such "passes" are
  /// illegible in practice, so the solver kept pushing opacity until the
  /// whole background sat on one side; [opacity] reflects that. Nothing to
  /// act on — exposed so audits can see the extra cost was deliberate.
  final bool straddleCollapsed;

  const ProtectionResult({
    required this.protectionArgb,
    required this.opacity,
    required this.meetsTarget,
    required this.achievedContrast,
    required this.clearedSide,
    required this.straddleCollapsed,
  });

  bool get needsProtection => opacity > 0.0;
}

/// Recipe for a halo (ADR-001 D-4): the glyph's own shape, dilated by
/// [spread] pixels, blurred by [blurRadius], painted in [argb] at [opacity],
/// drawn underneath the glyph.
///
/// To render: stroke or dilate the glyph outline by [spread], apply a
/// Gaussian blur, and paint below the fill. Because dilation keeps the area
/// under and immediately around the glyph SOLID before blurring, the halo's
/// alpha at the glyph edge is exactly [opacity] — the contrast guarantee
/// carries over with no approximation. This is why halos are preferred over
/// [getStackedShadowSpec], which must model blur falloff instead.
class HaloResult {
  /// Halo paint color.
  final int argb;

  /// Halo paint alpha, 0..1, quantized to 1/255.
  final double opacity;

  /// Dilation distance in pixels (how far the solid core extends past the
  /// glyph before blurring).
  final double spread;

  /// Gaussian blur radius in pixels, applied after dilation.
  final double blurRadius;

  /// Same meaning as [ProtectionResult.meetsTarget]: false means no opacity
  /// of this color can reach the target and [opacity] is best effort (1.0).
  final bool meetsTarget;

  const HaloResult({
    required this.argb,
    required this.opacity,
    required this.spread,
    required this.blurRadius,
    required this.meetsTarget,
  });
}

/// Recipe for approximating protection with shadows that cannot spread — CSS
/// `text-shadow` and Flutter `Shadow`. By contrast, CSS `box-shadow` and
/// Flutter `BoxShadow` have a spread radius, which effectively draws a stroke;
/// use [getHalo] for them.
///
/// To render: draw one shadow per entry in [opacities], each with color
/// [argb], blur radius [blurRadius], and zero offset, under the glyph.
///
/// Why a stack: a single blurred shadow is only about half-opaque at the
/// glyph edge — the blur pushes roughly half of each pixel's ink inward,
/// under the glyph where it does nothing. One layer therefore cannot deliver
/// a high [requiredOpacity]; several identical layers are stacked until the
/// pixel just outside the glyph reaches it. [opacities] is sized by that
/// closed form (see [getStackedShadowSpec]); all entries are identical.
class StackedShadowSpec {
  /// Shadow paint color.
  final int argb;

  /// Blur radius in pixels to draw every layer with ([getStackedShadowSpec]'s
  /// input rounded to a whole pixel — use THIS value, not your original).
  final double blurRadius;

  /// Per-layer paint alphas, one shadow layer each; identical by
  /// construction. Empty when nothing needs to be drawn.
  final List<double> opacities;

  /// True when drawing this spec is expected to deliver the contrast target.
  ///
  /// False when the underlying solve failed, when blur is zero (an invisible
  /// shadow can't protect anything), or when more than the layer cap would be
  /// required; [opacities] is then a best effort.
  ///
  /// Caveat: unlike [ProtectionResult.meetsTarget], which is exact, this
  /// depends on a model of how much of a blurred shadow lands at the glyph
  /// edge. The model is calibrated against real rendered pixels for long
  /// straight edges (test/effects/shadow_pixel_calibration_test.dart), but
  /// corners and very thin strokes deviate. Prefer [getHalo] when possible.
  final bool meetsTarget;

  /// Modeled fraction of one layer's paint alpha that lands on the first
  /// pixel outside the glyph ("edge coverage", e in the closed form).
  /// Exposed for audits and golden tests.
  final double edgeCoverage;

  /// The scrim opacity this stack is approximating — what
  /// [getProtectionOpacity] said the content actually needs.
  final double requiredOpacity;

  const StackedShadowSpec({
    required this.argb,
    required this.blurRadius,
    required this.opacities,
    required this.meetsTarget,
    required this.edgeCoverage,
    required this.requiredOpacity,
  });
}

/// Solves protection for [foregroundArgb] over [backgroundArgbs] and returns
/// it as a stack of identical Gaussian shadows — the delivery of last resort
/// for renderers that only offer shadows with blur radius, no spread radius or
/// stroke (`text-shadow` / `Shadow`). Prefer [getHalo] for spread-capable
/// shadows (`box-shadow` / `BoxShadow`) or explicit strokes.
///
/// [blurRadius] is the shadow blur you intend to draw with (Skia/CSS radius
/// convention). It is rounded to a whole pixel once; draw with the returned
/// [StackedShadowSpec.blurRadius].
///
/// [contentRadius] is the half-thickness in pixels of the strokes being
/// protected — roughly half the font's stem width. The default (-1) assumes
/// strokes at least as wide as the blur. Pass the real half-thickness when
/// strokes may be thinner than [blurRadius]: thin strokes need more layers.
/// Too small a value wastes layers; too large (including the default, for
/// thin strokes) delivers less protection than [StackedShadowSpec.meetsTarget]
/// claims.
///
/// [maxLayers] caps the stack — the required layer count is sometimes
/// unbounded (a required opacity of 1.0 is unreachable by stacking; hairline
/// strokes under large blur can demand dozens). Past the cap:
/// [StackedShadowSpec.meetsTarget] false, [maxLayers] full-alpha layers as
/// best effort.
StackedShadowSpec getStackedShadowSpec({
  required int foregroundArgb,
  required List<int> backgroundArgbs,
  required double contrast,
  required Algo algo,
  required double blurRadius,
  Usage usage = Usage.text,
  int? protectionArgb,
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
  final protection = getProtectionOpacity(
    foregroundArgb: foregroundArgb,
    backgroundArgbs: backgroundArgbs,
    contrast: contrast,
    algo: algo,
    usage: usage,
    protectionArgb: protectionArgb,
  );
  final alpha = protection.opacity;
  if (alpha == 0.0) {
    return StackedShadowSpec(
      argb: protection.protectionArgb,
      blurRadius: 0,
      opacities: const [],
      meetsTarget: protection.meetsTarget,
      edgeCoverage: 0,
      requiredOpacity: 0,
    );
  }

  // Round the radius exactly once: sigma and coverage below
  // must be computed from the same whole-pixel radius the caller will draw
  // with, or the model quietly diverges from the render.
  final r = blurRadius.round();
  if (r == 0) {
    // Protection is needed but a zero-blur shadow is invisible. Honest spec:
    // nothing to draw, target not met.
    return StackedShadowSpec(
      argb: protection.protectionArgb,
      blurRadius: 0,
      opacities: const [],
      meetsTarget: false,
      edgeCoverage: 0,
      requiredOpacity: alpha,
    );
  }

  // Edge coverage: continuous Gaussian edge profile, evaluated at the first
  // outside pixel's center (0.5px past the edge). The content bar spans
  // [0.5, 0.5 + 2*cr] away from that center; coverage is the Gaussian mass
  // over that window. CALIBRATED against rendered Skia pixels
  // (shadow_pixel_calibration_test.dart): a truncated-renormalized discrete
  // kernel was measured 0.04 optimistic on thin content and rejected.
  final sigma = convertRadiusToSigma(r.toDouble());
  final cr = (contentRadius < 0 ? r : contentRadius.round());
  final e = contentRadius < 0
      // Default: content wide relative to blur — half-plane coverage.
      ? 1.0 - _phi(0.5 / sigma)
      : _phi((0.5 + 2.0 * cr) / sigma) - _phi(0.5 / sigma);

  if (e <= 0.0) {
    return StackedShadowSpec(
      argb: protection.protectionArgb,
      blurRadius: r.toDouble(),
      opacities: const [],
      meetsTarget: false,
      edgeCoverage: e,
      requiredOpacity: alpha,
    );
  }

  // Layer count. Each full-alpha layer deposits e at the first pixel outside
  // the glyph, so n layers reach 1 - (1-e)^n; the smallest n meeting alpha is
  //   n = ceil(log(1 - alpha) / log(1 - e)).
  // alpha == 1 is unreachable (1 - (1-e)^n < 1 for every finite n) and tiny
  // e can demand absurd n; the cap keeps the answer drawable and reports the
  // shortfall through meetsTarget instead.
  final int n = alpha >= 1.0
      ? maxLayers + 1
      : (math.log(1 - alpha) / math.log(1 - e)).ceil().clamp(1, maxLayers + 1);
  if (n > maxLayers) {
    return StackedShadowSpec(
      argb: protection.protectionArgb,
      blurRadius: r.toDouble(),
      opacities: List.filled(maxLayers, 1.0),
      meetsTarget: false,
      edgeCoverage: e,
      requiredOpacity: alpha,
    );
  }
  // Per-layer alpha spreading alpha evenly over n layers:
  //   perLayer = (1 - (1 - alpha)^(1/n)) / e
  // This hits alpha with EQUALITY — but alpha is the solver's minimal
  // passing opacity, and renderers quantize paint alpha to 1/255. Round UP
  // to the next renderable step so the drawn stack can never land below the
  // proven minimum. (perLayer <= 1 before ceil because n satisfies
  // (1-e)^n <= 1-alpha, so ceil stays <= 255.)
  final perLayerRaw = (1 - math.pow(1 - alpha, 1 / n)) / e;
  final perLayer = ((perLayerRaw * 255).ceil().clamp(0, 255)) / 255.0;
  return StackedShadowSpec(
    argb: protection.protectionArgb,
    blurRadius: r.toDouble(),
    opacities: List.filled(n, perLayer),
    meetsTarget: protection.meetsTarget,
    edgeCoverage: e,
    requiredOpacity: alpha,
  );
}


/// Φ(z): the fraction of a bell curve's area lying below z (the standard
/// normal CDF).
///
/// Why it's here: a Gaussian blur turns a hard edge into exactly this
/// S-shaped profile. "How much shadow lands d pixels past the glyph edge"
/// is therefore a single Φ evaluation — no kernel loops. Calibrated against
/// real Skia output in test/effects/shadow_pixel_calibration_test.dart.
double _phi(double z) => 0.5 * (1 + _erf(z / math.sqrt2));

/// erf, the "error function": the running integral of the bell curve,
/// related to Φ by Φ(z) = (1 + erf(z/√2)) / 2. dart:math doesn't provide
/// it, so this is the classic Abramowitz & Stegun approximation 7.1.26 —
/// max error 1.5e-7, far below the 1/255 alpha quantum anything here is
/// rounded to. Keep bit-identical with the port in js/src/protection.ts.
double _erf(double x) {
  final sign = x < 0 ? -1.0 : 1.0;
  final ax = x.abs();
  const p = 0.3275911;
  final t = 1 / (1 + p * ax);
  final y = 1 -
      ((((1.061405429 * t - 1.453152027) * t + 1.421413741) * t -
                  0.284496736) *
              t +
          0.254829592) *
          t *
          math.exp(-ax * ax);
  return sign * y;
}

/// Converts a blur radius (the number CSS and Flutter APIs take) to the
/// Gaussian sigma the renderer actually blurs with. This is Skia's own
/// mapping — SkBlurMask::ConvertRadiusToSigma — so the model in this file
/// and what Skia draws agree by construction.
/// <https://github.com/google/skia/blob/bb5b77db51d2e149ee66db284903572a5aac09be/src/effects/SkBlurMask.cpp#L23>
double convertRadiusToSigma(double radius) {
  return radius > 0 ? radius * 0.57735 + 0.5 : 0;
}

const _white = 0xFFFFFFFF;
const _black = 0xFF000000;

/// The minimum scrim opacity that makes [foregroundArgb] meet [contrast]
/// against every color in [backgroundArgbs] — and keeps meeting it at every
/// opacity above the returned one, so callers may round up freely.
///
/// To use: fill the area behind the foreground with
/// [ProtectionResult.protectionArgb] at [ProtectionResult.opacity], then
/// check [ProtectionResult.meetsTarget] — false means even a fully opaque
/// scrim of that color can't reach the target.
///
/// [contrast] is libmonet's usual 0..1 interpolation percent (0.5 = WCAG
/// 4.5:1 / APCA Lc 60 for text), converted via [Algo.getAbsoluteContrast] with
/// [usage]. [backgroundArgbs] must be real sampled pixels — see the input
/// contract at the top of this file.
///
/// [protectionArgb] fixes the scrim color (e.g. a brand-tinted scrim); null
/// lets the solver try both black and white and return the cheaper. Custom
/// scrims generally cost more opacity than the auto pole, and are infeasible
/// when the foreground can't meet the target against the scrim color itself
/// (at opacity 1.0 the background IS the scrim).
ProtectionResult getProtectionOpacity({
  required int foregroundArgb,
  required List<int> backgroundArgbs,
  required double contrast,
  required Algo algo,
  Usage usage = Usage.text,
  int? protectionArgb,
}) {
  if (backgroundArgbs.isEmpty) {
    throw ArgumentError('backgroundArgbs cannot be empty');
  }
  if (contrast.isNaN || contrast <= 0.0 || contrast > 1.0) {
    throw ArgumentError.value(contrast, 'contrast', 'must be in (0, 1]');
  }
  final target = algo.getAbsoluteContrast(contrast, usage);

  if (protectionArgb != null) {
    return _solveForScrim(
      foregroundArgb, backgroundArgbs, target, algo, protectionArgb,
    );
  }
  final black =
      _solveForScrim(foregroundArgb, backgroundArgbs, target, algo, _black);
  final white =
      _solveForScrim(foregroundArgb, backgroundArgbs, target, algo, _white);
  if (black.meetsTarget && white.meetsTarget) {
    return black.opacity <= white.opacity ? black : white;
  }
  if (black.meetsTarget) return black;
  if (white.meetsTarget) return white;
  // Infeasible either way: best effort is whichever pole contrasts harder.
  return black.achievedContrast >= white.achievedContrast ? black : white;
}

/// Solves protection for [foregroundArgb] over [backgroundArgbs] and returns
/// it shaped as a halo hugging the glyph instead of a rectangular scrim —
/// see [HaloResult] for how to render it.
///
/// The contrast solve is identical to [getProtectionOpacity]; [spread] and
/// [blurRadius] only shape the halo's geometry and are passed through. The
/// defaults (1px spread, 4px blur) suit body text; scale with glyph size.
HaloResult getHalo({
  required int foregroundArgb,
  required List<int> backgroundArgbs,
  required double contrast,
  required Algo algo,
  Usage usage = Usage.text,
  int? protectionArgb,
  double spread = 1.0,
  double blurRadius = 4.0,
}) {
  if (spread.isNaN || spread < 0 || blurRadius.isNaN || blurRadius < 0) {
    throw ArgumentError('spread and blurRadius must be non-negative');
  }
  final r = getProtectionOpacity(
    foregroundArgb: foregroundArgb,
    backgroundArgbs: backgroundArgbs,
    contrast: contrast,
    algo: algo,
    usage: usage,
    protectionArgb: protectionArgb,
  );
  return HaloResult(
    argb: r.protectionArgb,
    opacity: r.opacity,
    spread: spread,
    blurRadius: blurRadius,
    meetsTarget: r.meetsTarget,
  );
}

// =============================================================================
// The predicate, and the scan.
// =============================================================================

/// 8-bit source-over blend of [scrim] at alpha [a] (0..255) onto opaque [bg].
int blendArgb(int bg, int scrim, int a) {
  int ch(int shift) {
    final b = (bg >> shift) & 0xFF;
    final s = (scrim >> shift) & 0xFF;
    return (((255 - a) * b + a * s) / 255).round();
  }

  return 0xFF000000 | (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

class _Outcome {
  final bool allPass; // every background meets |contrast| >= target
  final bool oneSided; // and every background is on the same side of fg
  final double worstAbs; // min |contrast| over backgrounds
  final ClearedSide side;
  const _Outcome(this.allPass, this.oneSided, this.worstAbs, this.side);
}

_Outcome _evaluate(
  int fgArgb,
  List<int> bgArgbs,
  double target,
  Algo algo,
  int scrimArgb,
  int a,
) {
  final fgY = switch (algo) {
    Algo.apca => apcaYFromArgb(fgArgb),
    Algo.wcag21 => yFromArgb(fgArgb),
  };
  var allPass = true;
  var anyLow = false, anyHigh = false;
  var worst = double.infinity;
  for (final bg in bgArgbs) {
    final blended = blendArgb(bg, scrimArgb, a);
    final c = algo
        .contrastBetweenArgbs(bgArgb: blended, fgArgb: fgArgb)
        .abs();
    if (c < worst) worst = c;
    if (c < target) allPass = false;
    final bgY = switch (algo) {
      Algo.apca => apcaYFromArgb(blended),
      Algo.wcag21 => yFromArgb(blended),
    };
    if (bgY < fgY) {
      anyLow = true;
    } else {
      anyHigh = true;
    }
  }
  final oneSided = !(anyLow && anyHigh);
  return _Outcome(allPass, oneSided, worst,
      anyHigh && !anyLow ? ClearedSide.high : ClearedSide.low);
}

ProtectionResult _solveForScrim(
  int fgArgb,
  List<int> bgArgbs,
  double target,
  Algo algo,
  int scrimArgb,
) {
  // Evaluate everything; invert nothing. 256 x N cheap evaluations.
  final outcomes = List<_Outcome>.generate(
      256, (a) => _evaluate(fgArgb, bgArgbs, target, algo, scrimArgb, a));

  // Lowest alpha such that it AND every higher alpha clears one-sided.
  // (Downward suffix scan: blended luminance is not monotone in alpha for
  // arbitrary scrim colors, and this preserves "solved alpha and above are
  // safe" for free. For black/white it coincides with the first-true alpha.)
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
    // Infeasible: fg cannot meet target even against the pure scrim color.
    return ProtectionResult(
      protectionArgb: scrimArgb,
      opacity: 1.0,
      meetsTarget: false,
      achievedContrast: outcomes[255].worstAbs,
      clearedSide: outcomes[255].side,
      straddleCollapsed: false,
    );
  }

  // Straddle: some lower alpha passed per-pixel but with backgrounds on both
  // sides of the foreground. Deliberately rejected; surfaced, not silent.
  var straddle = false;
  for (var a = 0; a < solved; a++) {
    final o = outcomes[a];
    if (o.allPass && !o.oneSided) {
      straddle = true;
      break;
    }
  }

  final at = outcomes[solved];
  return ProtectionResult(
    protectionArgb: scrimArgb,
    opacity: solved / 255.0,
    meetsTarget: true,
    achievedContrast: at.worstAbs,
    clearedSide: at.side,
    straddleCollapsed: straddle,
  );
}
