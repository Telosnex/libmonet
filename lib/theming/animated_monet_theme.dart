import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/colorspaces/hct.dart';
import 'package:libmonet/flux/flux_animation.dart';
import 'package:libmonet/flux/rk4_spring.dart';
import 'package:libmonet/flux/sim.dart';
import 'package:libmonet/theming/interpolation_style.dart';
import 'package:libmonet/theming/monet_theme.dart';
import 'package:libmonet/theming/monet_theme_data.dart';
import 'package:libmonet/theming/monet_paint_colors.dart';
import 'package:libmonet/theming/palette.dart';
import 'package:libmonet/theming/palette_lerped.dart';

/// Interpolated theme data that lerps the three palettes while keeping
/// [ThemeData] stable by default to avoid Material transient states.
///
/// Still used directly by [MonetThemeDataTween] for callers that want a
/// simple scalar-`t` lerp between two known themes (e.g. tests, or explicit
/// non-widget interpolation). [AnimatedMonetTheme] itself no longer drives its
/// live animation through this class -- see the moving-target spring notes
/// on [AnimatedMonetTheme].
class InterpolatedMonetThemeData extends MonetThemeData {
  final MonetThemeData begin;
  final MonetThemeData end;
  final double t;
  final bool animateThemeData;
  final InterpolationStyle interpolationStyle;

  InterpolatedMonetThemeData({
    required this.begin,
    required this.end,
    required this.t,
    this.animateThemeData = false,
    this.interpolationStyle = InterpolationStyle.cartesian,
  }) : super(
         backgroundTone:
             lerpDouble(begin.backgroundTone, end.backgroundTone, t) ??
             end.backgroundTone,
         brightness: t < 1.0 ? begin.brightness : end.brightness,
         primary: PaletteLerped(
           a: begin.primary,
           b: end.primary,
           t: t,
           interpolationStyle: interpolationStyle,
         ),
         secondary: PaletteLerped(
           a: begin.secondary,
           b: end.secondary,
           t: t,
           interpolationStyle: interpolationStyle,
         ),
         tertiary: PaletteLerped(
           a: begin.tertiary,
           b: end.tertiary,
           t: t,
           interpolationStyle: interpolationStyle,
         ),
         algo: t < 1.0 ? begin.algo : end.algo,
         colorModel: t < 1.0 ? begin.colorModel : end.colorModel,
         contrast: lerpDouble(begin.contrast, end.contrast, t) ?? end.contrast,
         scale: lerpDouble(begin.scale, end.scale, t) ?? end.scale,
         typography: t < 1.0 ? begin.typography : end.typography,
       );

  @override
  ThemeData createThemeData(BuildContext context) {
    if (animateThemeData) {
      return super.createThemeData(context);
    }
    // Keep Material ThemeData stable during palette animation to avoid
    // transient glitches in Material components.
    return t >= 1.0
        ? end.createThemeData(context)
        : begin.createThemeData(context);
  }
}

/// Tween between two [MonetThemeData] instances using a scalar `t`.
///
/// Kept for callers that want a simple, non-animated scalar lerp (e.g. tests
/// asserting a specific `t` midpoint). [AnimatedMonetTheme] no longer uses
/// this internally for its live animation -- see the moving-target spring
/// notes there.
class MonetThemeDataTween extends Tween<MonetThemeData> {
  bool animateThemeData;
  InterpolationStyle interpolationStyle;

  MonetThemeDataTween({
    super.begin,
    super.end,
    this.animateThemeData = false,
    this.interpolationStyle = InterpolationStyle.cartesian,
  });

  @override
  MonetThemeData lerp(double t) {
    final begin = this.begin;
    final end = this.end;
    if (begin == null && end == null) {
      throw StateError('MonetThemeDataTween has neither begin nor end.');
    }
    if (begin == null) {
      return end!;
    }
    if (end == null) {
      return begin;
    }
    if (begin == end) {
      return end;
    }
    if (t <= 0.0) {
      return begin;
    }
    if (t >= 1.0) {
      return end;
    }
    return InterpolatedMonetThemeData(
      begin: begin,
      end: end,
      t: t,
      animateThemeData: animateThemeData,
      interpolationStyle: interpolationStyle,
    );
  }
}

// ── Moving-target spring plumbing ────────────────────────────────────────
//
// `AnimatedMonetTheme` used to drive its animation with a fixed-duration
// `AnimationController`, restarting the controller from t=0 on every single
// retarget (`_controller.forward(from: 0)`). That is correct for a single
// isolated retarget (it rebases `begin` to the current interpolated value),
// but breaks down when retargets arrive faster than `duration` -- e.g. a
// wallpaper-driven theme resampling every ~8ms (one vsync at 120Hz) against a
// 200ms duration. Each reset pins the animation near its `t=0` starting point,
// so the visible value barely moves for the whole gesture; the *last*
// scheduled animation is then the first one ever allowed to run to
// completion, producing one large, sudden-looking swing once retargets stop.
// See `test/theming/animated_monet_theme_test.dart`,
// "rapid continuous retargets do not freeze then jump (moving-target bug)".
//
// The fix: represent the animated portion of the theme as a strongly-typed
// `_ThemeMotionState` (RGB channels of the six base colors behind
// primary/secondary/tertiary, plus backgroundTone/contrast/scale), and drive
// that state with a Flux `SimAnimationController`. Retargeting never resets a
// fixed-duration clock: every retarget re-simulates a spring from the *current
// value and velocity* toward the new target. Retargeting every 8ms no longer
// produces a frozen-then-jump artifact, because there is no "elapsed time since
// retarget" to reset -- only "value" and "velocity", which stay continuous by
// construction.

// Strongly typed spring state for the animated parts of a [MonetThemeData].
//
// The physics still consists of 21 independent scalar springs: six RGB colors
// (18 channels) plus backgroundTone, contrast, and scale. The important bit is
// that the animation value is no longer a raw `List<double>`/"vector" with
// magic positions. `SimAnimationController` now carries this named type, so
// the compiler and the field names document what is actually animating.
class _ThemeMotionState {
  const _ThemeMotionState({
    required this.primaryColorA,
    required this.primaryColorB,
    required this.primaryColorTone,
    required this.primaryBackgroundA,
    required this.primaryBackgroundB,
    required this.primaryBackgroundTone,
    required this.secondaryColorA,
    required this.secondaryColorB,
    required this.secondaryColorTone,
    required this.secondaryBackgroundA,
    required this.secondaryBackgroundB,
    required this.secondaryBackgroundTone,
    required this.tertiaryColorA,
    required this.tertiaryColorB,
    required this.tertiaryColorTone,
    required this.tertiaryBackgroundA,
    required this.tertiaryBackgroundB,
    required this.tertiaryBackgroundTone,
    required this.backgroundTone,
    required this.contrast,
    required this.scale,
  });

  final double primaryColorA;
  final double primaryColorB;
  final double primaryColorTone;
  final double primaryBackgroundA;
  final double primaryBackgroundB;
  final double primaryBackgroundTone;
  final double secondaryColorA;
  final double secondaryColorB;
  final double secondaryColorTone;
  final double secondaryBackgroundA;
  final double secondaryBackgroundB;
  final double secondaryBackgroundTone;
  final double tertiaryColorA;
  final double tertiaryColorB;
  final double tertiaryColorTone;
  final double tertiaryBackgroundA;
  final double tertiaryBackgroundB;
  final double tertiaryBackgroundTone;
  final double backgroundTone;
  final double contrast;
  final double scale;

  factory _ThemeMotionState.fromTheme(
    MonetThemeData data,
    _ColorMotionBasis basis,
  ) {
    final model = data.colorModel;
    final primaryColor = basis.extract(data.primary.color, model);
    final primaryBackground = basis.extract(data.primary.background, model);
    final secondaryColor = basis.extract(data.secondary.color, model);
    final secondaryBackground = basis.extract(data.secondary.background, model);
    final tertiaryColor = basis.extract(data.tertiary.color, model);
    final tertiaryBackground = basis.extract(data.tertiary.background, model);
    return _ThemeMotionState(
      primaryColorA: primaryColor[0],
      primaryColorB: primaryColor[1],
      primaryColorTone: primaryColor[2],
      primaryBackgroundA: primaryBackground[0],
      primaryBackgroundB: primaryBackground[1],
      primaryBackgroundTone: primaryBackground[2],
      secondaryColorA: secondaryColor[0],
      secondaryColorB: secondaryColor[1],
      secondaryColorTone: secondaryColor[2],
      secondaryBackgroundA: secondaryBackground[0],
      secondaryBackgroundB: secondaryBackground[1],
      secondaryBackgroundTone: secondaryBackground[2],
      tertiaryColorA: tertiaryColor[0],
      tertiaryColorB: tertiaryColor[1],
      tertiaryColorTone: tertiaryColor[2],
      tertiaryBackgroundA: tertiaryBackground[0],
      tertiaryBackgroundB: tertiaryBackground[1],
      tertiaryBackgroundTone: tertiaryBackground[2],
      backgroundTone: data.backgroundTone,
      contrast: data.contrast,
      scale: data.scale,
    );
  }

  /// Builds a retarget target relative to [from]'s *current* raw channel
  /// values, using [basis] to decide what continuity means for this motion
  /// representation (e.g. the polar basis continues hue along the shortest
  /// arc; the cartesian basis has no wraparound dimension, so it is just a
  /// plain re-extraction). [basis] should be the basis that *will* drive the
  /// new spring -- if it differs from whatever basis produced [from], [from]
  /// must already have been re-extracted into [basis] by the caller (see
  /// `_AnimatedMonetThemeState.didUpdateWidget`'s interpolation-style-change
  /// handling).
  factory _ThemeMotionState.retarget({
    required _ThemeMotionState from,
    required MonetThemeData to,
    required _ColorMotionBasis basis,
  }) {
    final model = to.colorModel;
    final primaryColor = basis.retarget(
      [from.primaryColorA, from.primaryColorB, from.primaryColorTone],
      to.primary.color,
      model,
    );
    final primaryBackground = basis.retarget(
      [
        from.primaryBackgroundA,
        from.primaryBackgroundB,
        from.primaryBackgroundTone,
      ],
      to.primary.background,
      model,
    );
    final secondaryColor = basis.retarget(
      [from.secondaryColorA, from.secondaryColorB, from.secondaryColorTone],
      to.secondary.color,
      model,
    );
    final secondaryBackground = basis.retarget(
      [
        from.secondaryBackgroundA,
        from.secondaryBackgroundB,
        from.secondaryBackgroundTone,
      ],
      to.secondary.background,
      model,
    );
    final tertiaryColor = basis.retarget(
      [from.tertiaryColorA, from.tertiaryColorB, from.tertiaryColorTone],
      to.tertiary.color,
      model,
    );
    final tertiaryBackground = basis.retarget(
      [
        from.tertiaryBackgroundA,
        from.tertiaryBackgroundB,
        from.tertiaryBackgroundTone,
      ],
      to.tertiary.background,
      model,
    );
    return _ThemeMotionState(
      primaryColorA: primaryColor[0],
      primaryColorB: primaryColor[1],
      primaryColorTone: primaryColor[2],
      primaryBackgroundA: primaryBackground[0],
      primaryBackgroundB: primaryBackground[1],
      primaryBackgroundTone: primaryBackground[2],
      secondaryColorA: secondaryColor[0],
      secondaryColorB: secondaryColor[1],
      secondaryColorTone: secondaryColor[2],
      secondaryBackgroundA: secondaryBackground[0],
      secondaryBackgroundB: secondaryBackground[1],
      secondaryBackgroundTone: secondaryBackground[2],
      tertiaryColorA: tertiaryColor[0],
      tertiaryColorB: tertiaryColor[1],
      tertiaryColorTone: tertiaryColor[2],
      tertiaryBackgroundA: tertiaryBackground[0],
      tertiaryBackgroundB: tertiaryBackground[1],
      tertiaryBackgroundTone: tertiaryBackground[2],
      backgroundTone: to.backgroundTone,
      contrast: to.contrast,
      scale: to.scale,
    );
  }

  factory _ThemeMotionState.zero() => const _ThemeMotionState(
    primaryColorA: 0.0,
    primaryColorB: 0.0,
    primaryColorTone: 0.0,
    primaryBackgroundA: 0.0,
    primaryBackgroundB: 0.0,
    primaryBackgroundTone: 0.0,
    secondaryColorA: 0.0,
    secondaryColorB: 0.0,
    secondaryColorTone: 0.0,
    secondaryBackgroundA: 0.0,
    secondaryBackgroundB: 0.0,
    secondaryBackgroundTone: 0.0,
    tertiaryColorA: 0.0,
    tertiaryColorB: 0.0,
    tertiaryColorTone: 0.0,
    tertiaryBackgroundA: 0.0,
    tertiaryBackgroundB: 0.0,
    tertiaryBackgroundTone: 0.0,
    backgroundTone: 0.0,
    contrast: 0.0,
    scale: 0.0,
  );

  double _quantize(double value, double quantum) =>
      (value / quantum).round() * quantum;

  /// A copy of this state with all color-channel fields zeroed, keeping
  /// backgroundTone/contrast/scale as-is. Used when the active
  /// [_ColorMotionBasis] changes mid-flight: velocity computed under the old
  /// basis has no meaningful interpretation under the new one (e.g. "degrees
  /// per second of hue" vs "units per second of a Cartesian coordinate"), so
  /// color motion restarts from rest, while the basis-independent scalars
  /// keep their carried-over velocity.
  _ThemeMotionState get zeroedColorVelocity => _ThemeMotionState(
    primaryColorA: 0.0,
    primaryColorB: 0.0,
    primaryColorTone: 0.0,
    primaryBackgroundA: 0.0,
    primaryBackgroundB: 0.0,
    primaryBackgroundTone: 0.0,
    secondaryColorA: 0.0,
    secondaryColorB: 0.0,
    secondaryColorTone: 0.0,
    secondaryBackgroundA: 0.0,
    secondaryBackgroundB: 0.0,
    secondaryBackgroundTone: 0.0,
    tertiaryColorA: 0.0,
    tertiaryColorB: 0.0,
    tertiaryColorTone: 0.0,
    tertiaryBackgroundA: 0.0,
    tertiaryBackgroundB: 0.0,
    tertiaryBackgroundTone: 0.0,
    backgroundTone: backgroundTone,
    contrast: contrast,
    scale: scale,
  );

  MonetThemeData toThemeData(MonetThemeData meta, _ColorMotionBasis basis) {
    // Quantize scalars so two ticks that produce byte-identical,
    // pixel-identical colors for every Palette getter are recognized as equal
    // (see repro10.txt/repro11.txt) instead of differing by an imperceptible
    // raw amount and causing duplicate paint notifications.
    final tone = _quantize(backgroundTone, 0.5);
    final quantizedContrast = _quantize(contrast, 0.001);
    final quantizedScale = _quantize(scale, 0.001);

    final primaryColor = basis.reconstruct([
      primaryColorA,
      primaryColorB,
      primaryColorTone,
    ], meta.colorModel);
    final primaryBackground = basis.reconstruct([
      primaryBackgroundA,
      primaryBackgroundB,
      primaryBackgroundTone,
    ], meta.colorModel);
    final secondaryColor = basis.reconstruct([
      secondaryColorA,
      secondaryColorB,
      secondaryColorTone,
    ], meta.colorModel);
    final secondaryBackground = basis.reconstruct([
      secondaryBackgroundA,
      secondaryBackgroundB,
      secondaryBackgroundTone,
    ], meta.colorModel);
    final tertiaryColor = basis.reconstruct([
      tertiaryColorA,
      tertiaryColorB,
      tertiaryColorTone,
    ], meta.colorModel);
    final tertiaryBackground = basis.reconstruct([
      tertiaryBackgroundA,
      tertiaryBackgroundB,
      tertiaryBackgroundTone,
    ], meta.colorModel);

    final primary = Palette.fromColorAndBackground(
      primaryColor,
      primaryBackground,
      contrast: quantizedContrast,
      algo: meta.algo,
      colorModel: meta.colorModel,
    );
    final secondary = Palette.fromColorAndBackground(
      secondaryColor,
      secondaryBackground,
      contrast: quantizedContrast,
      algo: meta.algo,
      colorModel: meta.colorModel,
    );
    final tertiary = Palette.fromColorAndBackground(
      tertiaryColor,
      tertiaryBackground,
      contrast: quantizedContrast,
      algo: meta.algo,
      colorModel: meta.colorModel,
    );
    return MonetThemeData(
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      backgroundTone: tone,
      brightness: meta.brightness,
      algo: meta.algo,
      colorModel: meta.colorModel,
      contrast: quantizedContrast,
      scale: quantizedScale,
      typography: meta.typography,
    );
  }
}

/// Wraps [hue] into `[0, 360)`, matching [Hct.from]'s expected input range.
double _wrapDegrees(double hue) {
  final wrapped = hue % 360.0;
  return wrapped < 0 ? wrapped + 360.0 : wrapped;
}

/// Shortest signed delta, in `(-180, 180]` degrees, to rotate from
/// [fromHueMod360] to reach [toHueMod360]. Mirrors
/// `Hct._lerpKeepHueAngle`'s wrap convention.
double _shortestHueDelta(double fromHueMod360, double toHueMod360) =>
    ((toHueMod360 - fromHueMod360 + 540.0) % 360.0) - 180.0;

/// How a single base seed color's 3 raw spring channels (named `A`, `B`,
/// `Tone` -- deliberately basis-neutral) map to and from an actual [Color].
///
/// Mirrors `palette_lerped.dart`'s [InterpolationStyle], but for a spring
/// (continuous value + velocity) rather than a fixed-duration scalar `t`
/// lerp. See `_PolarColorMotionBasis`/`_CartesianColorMotionBasis` for the
/// tradeoff between the two.
sealed class _ColorMotionBasis {
  const _ColorMotionBasis();

  /// Converts [color] to this basis's 3 raw channel values `[A, B, Tone]`.
  List<double> extract(Color color, ColorModel model);

  /// Continuity-preserving target given this color's *current* raw channel
  /// values (`[A, B, Tone]`) and a new target color. Differs from [extract]
  /// only for bases with a wraparound dimension (polar's hue).
  List<double> retarget(List<double> current, Color target, ColorModel model);

  /// Reconstructs a [Color] from raw channel values, correcting invalid or
  /// out-of-range values (e.g. spring overshoot producing negative chroma).
  Color reconstruct(List<double> raw, ColorModel model);

  /// Per-channel "visually indistinguishable" epsilon, in this basis's own
  /// units, in `[A, B, Tone]` order.
  List<double> get epsilons;
}

/// Springs hue, chroma, and tone directly and independently. `A`/`B`/`Tone`
/// here mean hue/chroma/tone. Hue springs over an *unwrapped* range (see
/// [_wrapDegrees]/[_shortestHueDelta]) so it can never become an unstable,
/// emergent byproduct of two other channels passing near the neutral axis --
/// which is exactly the bug this basis exists to avoid. See
/// hue_instability_diagnostic_test.dart.
class _PolarColorMotionBasis extends _ColorMotionBasis {
  const _PolarColorMotionBasis();

  @override
  List<double> extract(Color color, ColorModel model) {
    final hct = Hct.fromColor(color, model: model);
    return [hct.hue, hct.chroma, hct.tone];
  }

  @override
  List<double> retarget(List<double> current, Color target, ColorModel model) {
    final hct = Hct.fromColor(target, model: model);
    final hue =
        current[0] + _shortestHueDelta(_wrapDegrees(current[0]), hct.hue);
    return [hue, hct.chroma, hct.tone];
  }

  @override
  Color reconstruct(List<double> raw, ColorModel model) => Hct.from(
    _wrapDegrees(raw[0]),
    math.max(0.0, raw[1]),
    raw[2].clamp(0.0, 100.0),
    model: model,
  ).color;

  @override
  List<double> get epsilons => const [1.0, 0.5, 0.5];
}

/// Springs a Cartesian UCS-ish plane (`A = chroma*cos(hue)`,
/// `B = chroma*sin(hue)`) plus tone, then recovers hue/chroma via
/// `atan2`/`sqrt` on reconstruction -- mirroring
/// `Hct.lerpLoseHueAndChroma`/`InterpolationStyle.cartesian`, but for a
/// spring rather than a fixed-duration lerp.
///
/// Deliberate simplification: `palette_lerped.dart`'s cartesian mode uses
/// each color model's *native* UCS coordinates -- CAM16/CAM16V11's own
/// `aStar`/`bStar`/`jStar` (4 components, tone tracked separately), oklch's
/// `a`/`b` (3 components). Springing a variable number of channels per model
/// would break the fixed 21-channel `_ThemeMotionState` shape, so this basis
/// instead derives `A`/`B` from [Hct]'s own hue/chroma for every model. This
/// is *not* a bit-exact match for `PaletteLerped`'s cartesian output at a
/// given `t`, but it is a faithful reproduction of cartesian's defining,
/// documented tradeoff: interpolating between sufficiently different hues
/// passes through lower-chroma territory, and hue can swing meaningfully
/// while it does -- deliberately, unlike the polar basis above.
class _CartesianColorMotionBasis extends _ColorMotionBasis {
  const _CartesianColorMotionBasis();

  @override
  List<double> extract(Color color, ColorModel model) {
    final hct = Hct.fromColor(color, model: model);
    final radians = hct.hue * math.pi / 180.0;
    return [
      hct.chroma * math.cos(radians),
      hct.chroma * math.sin(radians),
      hct.tone,
    ];
  }

  @override
  List<double> retarget(List<double> current, Color target, ColorModel model) =>
      // No wraparound dimension in a Cartesian plane -- a plain re-extraction
      // already gives velocity-continuous motion via the spring itself.
      extract(target, model);

  @override
  Color reconstruct(List<double> raw, ColorModel model) {
    final chroma = math.sqrt(raw[0] * raw[0] + raw[1] * raw[1]);
    var hue = math.atan2(raw[1], raw[0]) * 180.0 / math.pi;
    if (hue < 0.0) hue += 360.0;
    return Hct.from(hue, chroma, raw[2].clamp(0.0, 100.0), model: model).color;
  }

  @override
  List<double> get epsilons => const [0.5, 0.5, 0.5];
}

_ColorMotionBasis _motionBasisFor(InterpolationStyle style) => switch (style) {
  InterpolationStyle.polar => const _PolarColorMotionBasis(),
  InterpolationStyle.cartesian => const _CartesianColorMotionBasis(),
};

/// A [Sim] over [_ThemeMotionState]: one independent [RK4SpringSim] per
/// named scalar channel. Hue channels (when [basis] is
/// [_PolarColorMotionBasis]) spring over an unwrapped (not mod-360) range so
/// motion stays continuous across the wrap boundary; see
/// `_ThemeMotionState.retarget`.
class _ThemeMotionSim extends Sim<_ThemeMotionState> {
  _ThemeMotionSim({
    required _ThemeMotionState start,
    required _ThemeMotionState end,
    required _ThemeMotionState velocity,
    required RK4SpringDescription desc,
    required _ColorMotionBasis basis,
  }) : _end = end,
       _primaryColorA = _spring(
         start.primaryColorA,
         end.primaryColorA,
         velocity.primaryColorA,
         desc,
       ),
       _primaryColorB = _spring(
         start.primaryColorB,
         end.primaryColorB,
         velocity.primaryColorB,
         desc,
       ),
       _primaryColorTone = _spring(
         start.primaryColorTone,
         end.primaryColorTone,
         velocity.primaryColorTone,
         desc,
       ),
       _primaryBackgroundA = _spring(
         start.primaryBackgroundA,
         end.primaryBackgroundA,
         velocity.primaryBackgroundA,
         desc,
       ),
       _primaryBackgroundB = _spring(
         start.primaryBackgroundB,
         end.primaryBackgroundB,
         velocity.primaryBackgroundB,
         desc,
       ),
       _primaryBackgroundTone = _spring(
         start.primaryBackgroundTone,
         end.primaryBackgroundTone,
         velocity.primaryBackgroundTone,
         desc,
       ),
       _secondaryColorA = _spring(
         start.secondaryColorA,
         end.secondaryColorA,
         velocity.secondaryColorA,
         desc,
       ),
       _secondaryColorB = _spring(
         start.secondaryColorB,
         end.secondaryColorB,
         velocity.secondaryColorB,
         desc,
       ),
       _secondaryColorTone = _spring(
         start.secondaryColorTone,
         end.secondaryColorTone,
         velocity.secondaryColorTone,
         desc,
       ),
       _secondaryBackgroundA = _spring(
         start.secondaryBackgroundA,
         end.secondaryBackgroundA,
         velocity.secondaryBackgroundA,
         desc,
       ),
       _secondaryBackgroundB = _spring(
         start.secondaryBackgroundB,
         end.secondaryBackgroundB,
         velocity.secondaryBackgroundB,
         desc,
       ),
       _secondaryBackgroundTone = _spring(
         start.secondaryBackgroundTone,
         end.secondaryBackgroundTone,
         velocity.secondaryBackgroundTone,
         desc,
       ),
       _tertiaryColorA = _spring(
         start.tertiaryColorA,
         end.tertiaryColorA,
         velocity.tertiaryColorA,
         desc,
       ),
       _tertiaryColorB = _spring(
         start.tertiaryColorB,
         end.tertiaryColorB,
         velocity.tertiaryColorB,
         desc,
       ),
       _tertiaryColorTone = _spring(
         start.tertiaryColorTone,
         end.tertiaryColorTone,
         velocity.tertiaryColorTone,
         desc,
       ),
       _tertiaryBackgroundA = _spring(
         start.tertiaryBackgroundA,
         end.tertiaryBackgroundA,
         velocity.tertiaryBackgroundA,
         desc,
       ),
       _tertiaryBackgroundB = _spring(
         start.tertiaryBackgroundB,
         end.tertiaryBackgroundB,
         velocity.tertiaryBackgroundB,
         desc,
       ),
       _tertiaryBackgroundTone = _spring(
         start.tertiaryBackgroundTone,
         end.tertiaryBackgroundTone,
         velocity.tertiaryBackgroundTone,
         desc,
       ),
       _backgroundTone = _spring(
         start.backgroundTone,
         end.backgroundTone,
         velocity.backgroundTone,
         desc,
       ),
       _contrast = _spring(
         start.contrast,
         end.contrast,
         velocity.contrast,
         desc,
       ),
       _scale = _spring(start.scale, end.scale, velocity.scale, desc),
       _primaryColorAEpsilon = basis.epsilons[0],
       _primaryColorBEpsilon = basis.epsilons[1],
       _primaryColorToneEpsilon = basis.epsilons[2],
       _primaryBackgroundAEpsilon = basis.epsilons[0],
       _primaryBackgroundBEpsilon = basis.epsilons[1],
       _primaryBackgroundToneEpsilon = basis.epsilons[2],
       _secondaryColorAEpsilon = basis.epsilons[0],
       _secondaryColorBEpsilon = basis.epsilons[1],
       _secondaryColorToneEpsilon = basis.epsilons[2],
       _secondaryBackgroundAEpsilon = basis.epsilons[0],
       _secondaryBackgroundBEpsilon = basis.epsilons[1],
       _secondaryBackgroundToneEpsilon = basis.epsilons[2],
       _tertiaryColorAEpsilon = basis.epsilons[0],
       _tertiaryColorBEpsilon = basis.epsilons[1],
       _tertiaryColorToneEpsilon = basis.epsilons[2],
       _tertiaryBackgroundAEpsilon = basis.epsilons[0],
       _tertiaryBackgroundBEpsilon = basis.epsilons[1],
       _tertiaryBackgroundToneEpsilon = basis.epsilons[2],
       _backgroundToneEpsilon = 0.5,
       _contrastEpsilon = 0.005,
       _scaleEpsilon = 0.005;

  final _ThemeMotionState _end;
  final RK4SpringSim _primaryColorA;
  final RK4SpringSim _primaryColorB;
  final RK4SpringSim _primaryColorTone;
  final RK4SpringSim _primaryBackgroundA;
  final RK4SpringSim _primaryBackgroundB;
  final RK4SpringSim _primaryBackgroundTone;
  final RK4SpringSim _secondaryColorA;
  final RK4SpringSim _secondaryColorB;
  final RK4SpringSim _secondaryColorTone;
  final RK4SpringSim _secondaryBackgroundA;
  final RK4SpringSim _secondaryBackgroundB;
  final RK4SpringSim _secondaryBackgroundTone;
  final RK4SpringSim _tertiaryColorA;
  final RK4SpringSim _tertiaryColorB;
  final RK4SpringSim _tertiaryColorTone;
  final RK4SpringSim _tertiaryBackgroundA;
  final RK4SpringSim _tertiaryBackgroundB;
  final RK4SpringSim _tertiaryBackgroundTone;
  final RK4SpringSim _backgroundTone;
  final RK4SpringSim _contrast;
  final RK4SpringSim _scale;
  final double _primaryColorAEpsilon;
  final double _primaryColorBEpsilon;
  final double _primaryColorToneEpsilon;
  final double _primaryBackgroundAEpsilon;
  final double _primaryBackgroundBEpsilon;
  final double _primaryBackgroundToneEpsilon;
  final double _secondaryColorAEpsilon;
  final double _secondaryColorBEpsilon;
  final double _secondaryColorToneEpsilon;
  final double _secondaryBackgroundAEpsilon;
  final double _secondaryBackgroundBEpsilon;
  final double _secondaryBackgroundToneEpsilon;
  final double _tertiaryColorAEpsilon;
  final double _tertiaryColorBEpsilon;
  final double _tertiaryColorToneEpsilon;
  final double _tertiaryBackgroundAEpsilon;
  final double _tertiaryBackgroundBEpsilon;
  final double _tertiaryBackgroundToneEpsilon;
  final double _backgroundToneEpsilon;
  final double _contrastEpsilon;
  final double _scaleEpsilon;

  static RK4SpringSim _spring(
    double start,
    double end,
    double velocity,
    RK4SpringDescription desc,
  ) => RK4SpringSim(start: start, end: end, velocity: velocity, desc: desc);

  @override
  _ThemeMotionState value(double time) => _ThemeMotionState(
    primaryColorA: _primaryColorA.value(time),
    primaryColorB: _primaryColorB.value(time),
    primaryColorTone: _primaryColorTone.value(time),
    primaryBackgroundA: _primaryBackgroundA.value(time),
    primaryBackgroundB: _primaryBackgroundB.value(time),
    primaryBackgroundTone: _primaryBackgroundTone.value(time),
    secondaryColorA: _secondaryColorA.value(time),
    secondaryColorB: _secondaryColorB.value(time),
    secondaryColorTone: _secondaryColorTone.value(time),
    secondaryBackgroundA: _secondaryBackgroundA.value(time),
    secondaryBackgroundB: _secondaryBackgroundB.value(time),
    secondaryBackgroundTone: _secondaryBackgroundTone.value(time),
    tertiaryColorA: _tertiaryColorA.value(time),
    tertiaryColorB: _tertiaryColorB.value(time),
    tertiaryColorTone: _tertiaryColorTone.value(time),
    tertiaryBackgroundA: _tertiaryBackgroundA.value(time),
    tertiaryBackgroundB: _tertiaryBackgroundB.value(time),
    tertiaryBackgroundTone: _tertiaryBackgroundTone.value(time),
    backgroundTone: _backgroundTone.value(time),
    contrast: _contrast.value(time),
    scale: _scale.value(time),
  );

  @override
  _ThemeMotionState velocity(double time) => _ThemeMotionState(
    primaryColorA: _primaryColorA.velocity(time),
    primaryColorB: _primaryColorB.velocity(time),
    primaryColorTone: _primaryColorTone.velocity(time),
    primaryBackgroundA: _primaryBackgroundA.velocity(time),
    primaryBackgroundB: _primaryBackgroundB.velocity(time),
    primaryBackgroundTone: _primaryBackgroundTone.velocity(time),
    secondaryColorA: _secondaryColorA.velocity(time),
    secondaryColorB: _secondaryColorB.velocity(time),
    secondaryColorTone: _secondaryColorTone.velocity(time),
    secondaryBackgroundA: _secondaryBackgroundA.velocity(time),
    secondaryBackgroundB: _secondaryBackgroundB.velocity(time),
    secondaryBackgroundTone: _secondaryBackgroundTone.velocity(time),
    tertiaryColorA: _tertiaryColorA.velocity(time),
    tertiaryColorB: _tertiaryColorB.velocity(time),
    tertiaryColorTone: _tertiaryColorTone.velocity(time),
    tertiaryBackgroundA: _tertiaryBackgroundA.velocity(time),
    tertiaryBackgroundB: _tertiaryBackgroundB.velocity(time),
    tertiaryBackgroundTone: _tertiaryBackgroundTone.velocity(time),
    backgroundTone: _backgroundTone.velocity(time),
    contrast: _contrast.velocity(time),
    scale: _scale.velocity(time),
  );

  @override
  bool isDone(double time) =>
      _done(_primaryColorA, time, _end.primaryColorA, _primaryColorAEpsilon) &&
      _done(_primaryColorB, time, _end.primaryColorB, _primaryColorBEpsilon) &&
      _done(
        _primaryColorTone,
        time,
        _end.primaryColorTone,
        _primaryColorToneEpsilon,
      ) &&
      _done(
        _primaryBackgroundA,
        time,
        _end.primaryBackgroundA,
        _primaryBackgroundAEpsilon,
      ) &&
      _done(
        _primaryBackgroundB,
        time,
        _end.primaryBackgroundB,
        _primaryBackgroundBEpsilon,
      ) &&
      _done(
        _primaryBackgroundTone,
        time,
        _end.primaryBackgroundTone,
        _primaryBackgroundToneEpsilon,
      ) &&
      _done(
        _secondaryColorA,
        time,
        _end.secondaryColorA,
        _secondaryColorAEpsilon,
      ) &&
      _done(
        _secondaryColorB,
        time,
        _end.secondaryColorB,
        _secondaryColorBEpsilon,
      ) &&
      _done(
        _secondaryColorTone,
        time,
        _end.secondaryColorTone,
        _secondaryColorToneEpsilon,
      ) &&
      _done(
        _secondaryBackgroundA,
        time,
        _end.secondaryBackgroundA,
        _secondaryBackgroundAEpsilon,
      ) &&
      _done(
        _secondaryBackgroundB,
        time,
        _end.secondaryBackgroundB,
        _secondaryBackgroundBEpsilon,
      ) &&
      _done(
        _secondaryBackgroundTone,
        time,
        _end.secondaryBackgroundTone,
        _secondaryBackgroundToneEpsilon,
      ) &&
      _done(
        _tertiaryColorA,
        time,
        _end.tertiaryColorA,
        _tertiaryColorAEpsilon,
      ) &&
      _done(
        _tertiaryColorB,
        time,
        _end.tertiaryColorB,
        _tertiaryColorBEpsilon,
      ) &&
      _done(
        _tertiaryColorTone,
        time,
        _end.tertiaryColorTone,
        _tertiaryColorToneEpsilon,
      ) &&
      _done(
        _tertiaryBackgroundA,
        time,
        _end.tertiaryBackgroundA,
        _tertiaryBackgroundAEpsilon,
      ) &&
      _done(
        _tertiaryBackgroundB,
        time,
        _end.tertiaryBackgroundB,
        _tertiaryBackgroundBEpsilon,
      ) &&
      _done(
        _tertiaryBackgroundTone,
        time,
        _end.tertiaryBackgroundTone,
        _tertiaryBackgroundToneEpsilon,
      ) &&
      _done(
        _backgroundTone,
        time,
        _end.backgroundTone,
        _backgroundToneEpsilon,
      ) &&
      _done(_contrast, time, _end.contrast, _contrastEpsilon) &&
      _done(_scale, time, _end.scale, _scaleEpsilon);

  static bool _done(
    RK4SpringSim spring,
    double time,
    double end,
    double epsilon,
  ) {
    if (spring.isDone(time)) return true;
    // Perceptual short-circuit. The spring can be numerically alive after its
    // rounded/reconstructed output is visually indistinguishable from the
    // target. Stop once this channel is within its perceptibility epsilon and
    // not moving fast enough to visibly cross back out of that band before
    // the next frame.
    const frameSeconds = 1.0 / 60.0;
    final residual = (spring.value(time) - end).abs();
    if (residual >= epsilon) return false;
    final velocity = spring.velocity(time).abs();
    return velocity * frameSeconds < epsilon;
  }
}

class _SpringThemeData extends MonetThemeData {
  _SpringThemeData({
    required MonetThemeData computed,
    required this.frozenThemeData,
    required this.animateThemeData,
  }) : super(
         primary: computed.primary,
         secondary: computed.secondary,
         tertiary: computed.tertiary,
         backgroundTone: computed.backgroundTone,
         brightness: computed.brightness,
         algo: computed.algo,
         colorModel: computed.colorModel,
         contrast: computed.contrast,
         scale: computed.scale,
         typography: computed.typography,
       );

  /// The theme to use for Material [ThemeData] while unsettled. `null` means
  /// settled -- use this instance's own computed [ThemeData].
  final MonetThemeData? frozenThemeData;
  final bool animateThemeData;

  @override
  ThemeData createThemeData(BuildContext context) {
    final frozen = frozenThemeData;
    if (animateThemeData || frozen == null) {
      return super.createThemeData(context);
    }
    return frozen.createThemeData(context);
  }

  // `MonetThemeData.createThemeData` caches by `this` in a *static*, global
  // map using `==`/`hashCode`. The base implementation only compares
  // primary/secondary/tertiary/etc -- it knows nothing about
  // `frozenThemeData`/`animateThemeData`. Include these fields so frozen and
  // live ThemeData resolutions cannot collide in that cache.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (super == other &&
          other is _SpringThemeData &&
          frozenThemeData == other.frozenThemeData &&
          animateThemeData == other.animateThemeData);

  @override
  int get hashCode =>
      Object.hash(super.hashCode, frozenThemeData, animateThemeData);
}

/// Approximates an [RK4SpringDescription] from a wall-clock [duration].
///
/// Springs do not have a fixed duration -- the whole point of a moving-target
/// spring is that "how long until settled" depends on the actual distance
/// travelled and current velocity, not a fixed timer. This maps the legacy
/// `duration` parameter onto a roughly-equivalent spring stiffness so existing
/// call sites (which only tune `duration`) keep a similar *feel*, calibrated
/// against `FluxSpring.snappy` (tension 750 settles in ~317ms at rest).
RK4SpringDescription _springDescriptionFor(Duration duration) {
  const referenceTension = 750.0;
  const referenceSettleMs = 317.0;
  final ms = duration.inMicroseconds / 1000.0;
  final tension = ms <= 1.0
      ? 4000.0
      // Linear (not inverse-square) scaling. Scaling tension too aggressively
      // for shorter durations (e.g. an inverse-square fit) makes the spring
      // visually arrive at ~99% of the journey well before `duration` even
      // elapses, which defeats the point of `duration` as a rough pacing hint.
      : (referenceTension * (referenceSettleMs / ms)).clamp(60.0, 4000.0);
  // Critically damped (zeta=1): the fastest response with no overshoot or
  // ringing. Fuchsia's UI springs fix friction=50 for a lively, slightly
  // underdamped feel (see FluxSpring), which is fine for a single, isolated
  // transition. But a moving-target theme animation retargets frequently, and
  // an underdamped spring rings -- repeatedly overshooting and returning past
  // the target -- for a long time after any fast chase before formally
  // settling. That produced a long tail of extra ticks/repaints doing nothing
  // perceptible (see repro4.txt and "settles promptly after a big retarget..."
  // in the test suite). Deriving friction from tension to hold zeta at 1
  // removes that ringing entirely: the value still approaches at a similar
  // pace, but monotonically, so it crosses into (and stays within) any given
  // epsilon band once, instead of oscillating in and out of it.
  final friction = 2 * math.sqrt(tension);
  return RK4SpringDescription(tension: tension, friction: friction);
}

/// Animated version of [MonetTheme], modeled after Flutter's [AnimatedTheme].
///
/// [data] is the target theme. When [data] changes semantically, this widget
/// implicitly animates from the currently displayed theme to the new target.
/// New-but-equal [MonetThemeData] objects do not restart the animation because
/// implicit animation tween updates use `==` to detect target changes.
///
/// This intentionally has no public `begin`/`end`: retargeting is continuous
/// and automatic, matching Flutter implicit-animation semantics.
///
/// ## Velocity-continuous spring, not a fixed-duration tween
///
/// Internally this animates a strongly-typed `_ThemeMotionState` with a
/// `SimAnimationController<_ThemeMotionState>` driving one `RK4SpringSim` per
/// scalar channel (`package:libmonet/flux`), not an
/// `AnimationController`/`Tween`.
/// Every retarget disposes the in-flight `SimAnimationController`, reads its
/// current *value and velocity*, and starts a brand-new simulation from
/// `(currentValue, currentVelocity) -> newTarget` -- synchronously, in the
/// same `didUpdateWidget` call, matching the old controller's synchronous
/// `forward(from: 0)` timing but without resetting an elapsed-time clock.
/// This matters for high-frequency retargeting (e.g. wallpaper-driven
/// no-background theming during scroll): a fixed-duration controller reset on
/// every retarget can pin the visible value near its starting point for an
/// entire gesture, then produce one large swing once retargets stop. Because
/// this carries real velocity across every retarget instead of restarting a
/// timer, it does not have that failure mode.
///
/// (`MovingTargetAnimation` in `package:libmonet/flux` provides similar
/// velocity handoff for a continuously-*animating* target, e.g. layout driven
/// by another animation. It is not used here because its target-changed path
/// defers the first re-simulation by one frame via
/// `SchedulerBinding.scheduleFrameCallback`, which is fine for its original
/// Mondrian layout use case but not for this widget's synchronous,
/// `didUpdateWidget`-triggered retargeting.)
///
/// [duration] is kept for API compatibility and approximates a spring
/// stiffness with a similar settle time; [curve] no longer has an effect
/// (springs do not use `Curve`s) and is retained only so existing call sites
/// compile unchanged.
///
/// ## Two output channels
///
/// This widget publishes the animated theme through two different mechanisms:
///
/// * A regular inherited [MonetTheme]. Descendants that call
///   `MonetTheme.of(context)` rebuild whenever this value is published. This is
///   the correct channel for semantic theme changes, Material [ThemeData], and
///   layout-affecting values.
/// * A stable [MonetPaintColors] controller exposed via
///   [MonetPaintColorsScope]. Its [MonetPaintColors.value] updates every
///   animation tick, but the inherited scope itself does not notify. Paint-aware
///   render objects can listen to the controller and repaint without rebuilding
///   their widget subtree.
///
/// The split exists because color-only wallpaper/theme motion can otherwise
/// dirty hundreds of inherited-theme dependents per frame. Prefer the paint
/// channel for frequently animated foreground, icon, border, and shadow colors;
/// keep inherited [MonetTheme] for rare semantic/layout updates.
///
/// By default, Material [ThemeData] is not animated; only [MonetThemeData]
/// palette tokens are interpolated. Set [animateThemeData] to also interpolate
/// the generated Material [ThemeData].
///
/// [interpolationStyle] selects how each base seed color's motion is
/// represented (see `_ColorMotionBasis`):
///
/// * [InterpolationStyle.polar] springs hue, chroma, and tone
///   directly and independently, with hue continuing along the shortest arc
///   across retargets.
/// * [InterpolationStyle.cartesian] (default) springs a Cartesian UCS-ish plane
///   (`chroma*cos(hue)`, `chroma*sin(hue)`) plus tone. This prevents a tour
///   of unrelated hues when animating between two colors with very different 
///   hues, and will produce grays in between. This is desirable for animating
///   app-level color themes, but may be undesirable for animating, say, a UI
///   element that is supposed to represent active state.
class AnimatedMonetTheme extends StatefulWidget {
  final MonetThemeData data;
  final Widget child;
  final bool animateThemeData;
  final InterpolationStyle interpolationStyle;
  final Curve curve;
  final Duration duration;
  final VoidCallback? onEnd;

  /// Maximum inherited-theme publishes per second while animating.
  ///
  /// This throttles only the inherited [MonetTheme] channel. The
  /// [MonetPaintColors] paint channel still receives every evaluated animation
  /// value so paint-aware render objects can stay visually smooth.
  ///
  /// Why this matters: an inherited-theme publish marks every descendant that
  /// called `MonetTheme.of(context)` as dependent-dirty. On 120 Hz displays,
  /// publishing every vsync can turn a color-only transition into hundreds of
  /// widget rebuilds, text paragraph updates, layout passes, and parent repaints
  /// per second.
  ///
  /// Modes:
  ///
  /// * `null`: publish inherited [MonetTheme] every tick. This matches the
  ///   traditional implicit-theme behavior and is safest when descendants are
  ///   not paint-bus-aware.
  /// * `0`: final-only inherited mode. Intermediate values go only to
  ///   [MonetPaintColors]; [MonetTheme] publishes the final target when the
  ///   animation completes. This is ideal for high-frequency local palette
  ///   motion when the visible descendants have paint-bus integrations.
  /// * `> 0`: publish inherited [MonetTheme] at most this many times per
  ///   second, while still updating [MonetPaintColors] every tick.
  ///
  /// Default: `30`, a compromise that limits rebuild storms while preserving
  /// compatibility with descendants that still depend on inherited theme
  /// animation.
  final int? maxUpdatesPerSecond;

  const AnimatedMonetTheme({
    super.key,
    required this.data,
    required this.child,
    this.animateThemeData = false,
    this.interpolationStyle = InterpolationStyle.cartesian,
    this.curve = Curves.linear,
    this.duration = kThemeAnimationDuration,
    this.onEnd,
    this.maxUpdatesPerSecond = 30,
  });

  @override
  State<AnimatedMonetTheme> createState() => _AnimatedMonetThemeState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<MonetThemeData>('data', data));
    properties.add(
      FlagProperty(
        'animateThemeData',
        value: animateThemeData,
        ifTrue: 'animating Material ThemeData',
      ),
    );
    properties.add(
      EnumProperty<InterpolationStyle>(
        'interpolationStyle',
        interpolationStyle,
        defaultValue: InterpolationStyle.polar,
      ),
    );
    properties.add(
      DiagnosticsProperty<int?>(
        'maxUpdatesPerSecond',
        maxUpdatesPerSecond,
        defaultValue: 30,
      ),
    );
  }
}

class _AnimatedMonetThemeState extends State<AnimatedMonetTheme>
    with TickerProviderStateMixin {
  /// Meta template (brightness/algo/colorModel/typography) while unsettled.
  late MonetThemeData _begin;

  /// The latest logical target -- used for retarget equality checks and as
  /// the meta template once settled.
  late MonetThemeData _end;
  late MonetThemeData _published;
  late final MonetPaintColors _paintColors;
  late SimAnimationController<_ThemeMotionState> _channel;
  Duration? _lastPublishedAt;
  MonetThemeData? _lastTickValue;

  /// The [_ColorMotionBasis] driving the currently-attached [_channel].
  late _ColorMotionBasis _activeBasis;

  @override
  void initState() {
    super.initState();
    _begin = widget.data;
    _end = widget.data;
    _published = widget.data;
    _paintColors = MonetPaintColors(widget.data);
    _activeBasis = _motionBasisFor(widget.interpolationStyle);
    final state = _ThemeMotionState.fromTheme(widget.data, _activeBasis);
    _attachChannel(
      _ThemeMotionSim(
        start: state,
        end: state,
        velocity: _ThemeMotionState.zero(),
        desc: _springDescriptionFor(widget.duration),
        basis: _activeBasis,
      ),
    );
  }

  void _attachChannel(_ThemeMotionSim sim) {
    _channel = SimAnimationController<_ThemeMotionState>(vsync: this, sim: sim)
      ..addListener(_handleTick)
      ..addStatusListener(_handleStatus);
    if (!_channel.isCompleted) {
      _channel.start();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedMonetTheme oldWidget) {
    super.didUpdateWidget(oldWidget);

    final targetChanged = widget.data != _end;
    final basisChanged =
        widget.interpolationStyle != oldWidget.interpolationStyle;
    final interpolationChanged =
        widget.animateThemeData != oldWidget.animateThemeData || basisChanged;

    if (targetChanged || basisChanged) {
      final current = _currentThemeData();
      final newBasis = _motionBasisFor(widget.interpolationStyle);
      _begin = current;
      _end = widget.data;

      _channel
        ..removeListener(_handleTick)
        ..removeStatusListener(_handleStatus)
        ..dispose();

      if (widget.duration == Duration.zero) {
        // Instantly jumps to the new target with zero residual velocity,
        // matching the old controller's `_controller.value = 1` snap. No
        // continuity to preserve, so a plain stateless conversion is fine.
        final snapState = _ThemeMotionState.fromTheme(widget.data, newBasis);
        _activeBasis = newBasis;
        _attachChannel(
          _ThemeMotionSim(
            start: snapState,
            end: snapState,
            velocity: _ThemeMotionState.zero(),
            desc: _springDescriptionFor(widget.duration),
            basis: newBasis,
          ),
        );
        _lastTickValue = widget.data;
        _paintColors.value = widget.data;
        _publish(widget.data, force: true);
        _lastPublishedAt = SchedulerBinding.instance.currentFrameTimeStamp;
        return;
      }

      _ThemeMotionState currentState;
      _ThemeMotionState currentVelocity;
      if (basisChanged) {
        // A basis change means the in-flight raw channel values (and their
        // velocity) mean something different now -- e.g. "degrees per second
        // of hue" doesn't translate to "units per second of a Cartesian
        // coordinate". Re-extract the actual current *visual* color into the
        // new basis and restart color motion from rest. The
        // backgroundTone/contrast/scale scalars are basis-independent, so
        // they keep their carried-over velocity.
        currentState = _ThemeMotionState.fromTheme(current, newBasis);
        currentVelocity = _channel.velocity.zeroedColorVelocity;
      } else {
        currentState = _channel.value;
        currentVelocity = _channel.velocity;
      }

      // Continuity-aware: each hue channel's new target continues along the
      // shortest arc from wherever it currently is, rather than snapping to a
      // stateless 0-360 hue value that could be on the "wrong side" of a wrap
      // boundary relative to the in-flight motion. (No-op for the cartesian
      // basis, which has no wraparound dimension.)
      final newTargetState = _ThemeMotionState.retarget(
        from: currentState,
        to: widget.data,
        basis: newBasis,
      );
      _activeBasis = newBasis;
      _attachChannel(
        _ThemeMotionSim(
          start: currentState,
          end: newTargetState,
          velocity: currentVelocity,
          desc: _springDescriptionFor(widget.duration),
          basis: newBasis,
        ),
      );
      if (_channel.isCompleted) {
        // Born-done retarget: the target compared unequal but every numeric
        // channel is already within its perceptibility epsilon of the
        // target, so the ticker never starts and the completed status
        // callback — the only path that publishes `_end` — will never fire.
        // Two ways to get here:
        // - meta-only change (e.g. a typography callback identity change
        //   from a font setting): palettes byte-identical, and skipping the
        //   publish leaves inherited dependents (fonts!) stale until an
        //   unrelated color motion completes — potentially forever on a
        //   static wallpaper;
        // - a retarget landing sub-epsilon from the in-flight value.
        // Publish the semantic target to the inherited MonetTheme in both
        // cases. Only sync the paint bus when the palettes are
        // byte-identical: force-snapping a sub-epsilon residual is the one
        // visible artifact an imperceptible retarget can produce — derived
        // colors (APCA-solved text) can amplify it into a large single-tick
        // hue swing (see the repro13 near-complementary test).
        _lastTickValue = _end;
        if (_samePaintValue(_paintColors.value, _end)) {
          _publish(_end, force: true);
        } else if (mounted && _published != _end) {
          setState(() {
            _published = _end;
          });
        }
        _lastPublishedAt = SchedulerBinding.instance.currentFrameTimeStamp;
        widget.onEnd?.call();
        return;
      }
      if (_publishesIntermediateInheritedThemes) {
        _publish(current, force: true);
      } else {
        // Final-only mode means inherited-theme dependents see the old
        // semantic theme until completion. Do not publish even the current
        // in-flight value on retarget: retargets can happen many times per
        // second while a transparent surface moves across wallpaper, and each
        // inherited publish would wake the entire MonetTheme.of dependency
        // graph. The paint bus carries the visible intermediate color.
        _paintColors.value = current;
      }
      _lastPublishedAt = SchedulerBinding.instance.currentFrameTimeStamp;
    } else if (interpolationChanged) {
      final value = _currentThemeData();
      if (_publishesIntermediateInheritedThemes) {
        _publish(value, force: true);
      } else {
        _paintColors.value = value;
      }
    }
  }

  @override
  void dispose() {
    _channel
      ..removeListener(_handleTick)
      ..removeStatusListener(_handleStatus)
      ..dispose();
    _paintColors.dispose();
    super.dispose();
  }

  void _handleTick() {
    final value = _currentThemeData();
    // Rounded-value dedup. `_ThemeMotionState.toThemeData` rounds each color
    // channel to the nearest integer, but the underlying spring can keep
    // ticking (ringing within its strict analytic tolerance, see
    // `_ThemeMotionSim.isDone`) for a
    // while after every rounded channel has stopped changing -- e.g. a small
    // residual retarget arriving mid-flight from a fast prior motion can leave
    // the spring decaying leftover velocity via friction alone for dozens of
    // extra ticks. None of that is visible once the rounded value is stable,
    // so skip re-notifying the paint bus / re-publishing for ticks that
    // produce an identical visible value. This is what actually eliminates
    // wasted rebuilds/repaints -- independent of, and in addition to, the
    // `isDone` early-exit, which only saves the (much cheaper) simulation
    // ticks themselves.
    if (_samePaintValue(_lastTickValue, value)) return;
    _lastTickValue = value;
    _paintColors.value = value;
    if (_shouldPublish() || _channel.isCompleted) {
      _lastPublishedAt = SchedulerBinding.instance.currentFrameTimeStamp;
      _publish(value);
    }
  }

  void _handleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _lastPublishedAt = SchedulerBinding.instance.currentFrameTimeStamp;
    _lastTickValue = _end;
    _publish(_end, force: true);
    widget.onEnd?.call();
  }

  bool get _publishesIntermediateInheritedThemes {
    final maxUpdates = widget.maxUpdatesPerSecond;
    return maxUpdates == null || maxUpdates > 0;
  }

  bool _shouldPublish() {
    final maxUpdates = widget.maxUpdatesPerSecond;
    if (maxUpdates == null) return true;
    if (maxUpdates <= 0) return false;
    final now = SchedulerBinding.instance.currentFrameTimeStamp;
    final last = _lastPublishedAt;
    if (last == null) return true;
    final minInterval = Duration(
      microseconds: (Duration.microsecondsPerSecond / maxUpdates).round(),
    );
    return now - last >= minInterval;
  }

  MonetThemeData _currentThemeData() {
    final settled = _channel.isCompleted;
    final meta = settled ? _end : _begin;
    final computed = _channel.value.toThemeData(meta, _activeBasis);
    // Keep Material ThemeData stable while unsettled, matching the old
    // InterpolatedMonetThemeData behavior, unless animateThemeData is set.
    return _SpringThemeData(
      computed: computed,
      frozenThemeData: settled ? null : _begin,
      animateThemeData: widget.animateThemeData,
    );
  }

  bool _samePaintValue(MonetThemeData? a, MonetThemeData b) {
    if (a == null) return false;
    // Paint-only listeners care about the rendered palette colors, not raw
    // semantic scalars like an unrounded backgroundTone. Completion publishes
    // the exact semantic target (`_end`) to the inherited MonetTheme, but if
    // the previous paint-bus tick already produced identical palettes, do not
    // notify paint listeners again. This fixes the final duplicate seen in
    // repro11.txt: tone 44.5 -> exact target tone 44.7 with byte-identical
    // palette colors.
    return a.brightness == b.brightness &&
        a.primary == b.primary &&
        a.secondary == b.secondary &&
        a.tertiary == b.tertiary;
  }

  void _publish(MonetThemeData value, {bool force = false}) {
    if (!_samePaintValue(_paintColors.value, value)) {
      _paintColors.value = value;
    }
    if (!force && _published == value) return;
    if (!mounted) return;
    setState(() {
      _published = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MonetPaintColorsScope(
      colors: _paintColors,
      child: MonetTheme(monetThemeData: _published, child: widget.child),
    );
  }
}
