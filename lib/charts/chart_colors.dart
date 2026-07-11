import 'dart:math' as math;
import 'dart:ui' show Brightness, Color;

import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/colorspaces/hct.dart';
import 'package:libmonet/contrast/contrast.dart';
import 'package:libmonet/core/argb_srgb_xyz_lab.dart';
import 'package:libmonet/core/hex_codes.dart';
import 'package:libmonet/effects/uv_harmony.dart';

/// Chart colors derived from a seed color and a real chart background.
///
/// All colors live in a *visible tone band* solved against the background
/// with the library's [contrast] dial and [Algo] (APCA by default):
///
///  - the band's **near** edge is the tone that is just visibly distinct
///    from the background ([Usage.border]);
///  - the band's **far** edge is the tone of maximum separation that the
///    dial requests ([Usage.text]), forced to the same polarity.
///
/// Hue comes from the u'v' harmony system: categorical series spread evenly
/// around the white point from the seed's chromatic direction (the same
/// angles as [harmony]); diverging ramps use the afterimage complement when
/// the two seeds are too close in direction.
///
/// Color vision deficiency is handled structurally rather than by a mode
/// parameter: adjacent categorical series always differ in tone, and tone
/// survives protanopia, deuteranopia, and tritanopia. At high series counts
/// hue gaps shrink and colors become grouping cues rather than identifiers;
/// per the chart brief, labels, boundaries, shapes, and patterns carry
/// identification there.
class ChartColors {
  /// Chart colors against a synthesized near-neutral background of
  /// [backgroundTone], mirroring [Palette.from]'s background treatment.
  factory ChartColors.from(
    Color seed, {
    required double backgroundTone,
    double contrast = 0.5,
    Algo algo = Algo.apca,
    ColorModel colorModel = ColorModel.kDefault,
  }) {
    final seedHct = Hct.fromColor(seed, model: colorModel);
    final background = Hct.from(
      seedHct.hue,
      math.min(seedHct.chroma, 16.0),
      backgroundTone,
      model: colorModel,
    ).color;
    return ChartColors.fromColorAndBackground(
      seed,
      background,
      contrast: contrast,
      algo: algo,
      colorModel: colorModel,
    );
  }

  ChartColors.fromColorAndBackground(
    this.seed,
    this.background, {
    this.contrast = 0.5,
    this.algo = Algo.apca,
    this.colorModel = ColorModel.kDefault,
  });

  final Color seed;
  final Color background;
  final double contrast;
  final Algo algo;
  final ColorModel colorModel;

  /// Golden angle: prefix-stable hue sequence; the three-distance theorem
  /// bounds how uneven the gaps can get at any n.
  static const _goldenAngle = 137.50776405003785;

  final Map<(int, bool), List<Color>> _categoricalCache = {};
  late final Hct _seedHct = Hct.fromColor(seed, model: colorModel);
  late final Hct _backgroundHct = Hct.fromColor(background, model: colorModel);

  /// Same polarity for every chart tone: siblings solved against the same
  /// background must land on the same side of it.
  late final ContrastDirection _direction =
      lstarPrefersLighterPair(_backgroundHct.tone)
      ? ContrastDirection.lighter
      : ContrastDirection.darker;

  double _solveTone(Usage usage, {double? atContrast}) {
    return contrastingTone(
      withArgb: background.argb,
      withTone: _backgroundHct.tone,
      targetHue: _seedHct.hue,
      targetChroma: _seedHct.chroma,
      usage: usage,
      by: algo,
      contrast: atContrast ?? contrast,
      forceDirection: _direction,
      colorModel: colorModel,
    );
  }

  /// Edge of the visible tone band closest to the background: just visibly
  /// distinct from it ([Usage.border]).
  ///
  /// Raising the [contrast] dial pushes both band edges away from the
  /// background — but the far edge saturates at the gamut ceiling, so a
  /// naively solved band *narrows* as the dial rises, collapsing to zero
  /// width at 100% (every ramp value rendering as white on dark
  /// backgrounds). Charts encode data in the band's interior, so its width
  /// is load-bearing: the near edge cedes ground back toward the dial-0.5
  /// visibility floor as needed to keep the band at least as wide as the
  /// default-dial band. At dials ≤ 0.5 this is a no-op.
  late final double nearTone = () {
    final ideal = _solveTone(Usage.border);
    final floor = _solveTone(Usage.border, atContrast: 0.5);
    final defaultWidth = (_solveTone(Usage.text, atContrast: 0.5) - floor)
        .abs();
    if (_direction == ContrastDirection.lighter) {
      return math.min(ideal, math.max(floor, farTone - defaultWidth));
    }
    return math.max(ideal, math.min(floor, farTone + defaultWidth));
  }();

  /// Edge of the visible tone band farthest from the background at this
  /// [contrast] dial ([Usage.text]), same polarity as [nearTone].
  late final double farTone = _solveTone(Usage.text);

  double _bandTone(double fraction) =>
      nearTone + (farTone - nearTone) * fraction;

  /// Below this u'v' distance from the white point, hue is a numerical
  /// default rather than a direction; do not treat it as data.
  static const _achromaticUvChroma = 0.01;

  late final bool _seedIsChromatic = _seedHct.uvChroma >= _achromaticUvChroma;

  /// The chromatic strength (u'v' distance from white) categorical series
  /// aim for. Near-neutral seeds get a floor so series remain tellable
  /// apart by color at all; very vivid seeds get a ceiling, because at
  /// maximal strength many hue directions clamp to the same corner of the
  /// gamut (requested 20° gaps can render 7° apart), collapsing the hue
  /// wheel the palette depends on.
  late final double _uvStrength = _seedHct.uvChroma
      .clamp(0.07, 0.12)
      .toDouble();

  /// [n] deterministic series colors.
  ///
  /// Hue: by default, a golden-angle (137.5°) sequence makes
  /// `categorical(n)` a prefix of `categorical(n + 1)`, so a series keeps its
  /// color when another series is added. Set [isColorAtIndexStable] to false
  /// to spread [n] directions evenly in u'v' (the same angles as [harmony]),
  /// gaining optimal spacing at the cost of recoloring existing indices.
  ///
  /// Tone: consecutive series always differ by at least 40% of the visible
  /// band. Tone survives all forms of dichromacy; this is the palette's
  /// color-vision-deficiency mechanism and needs no mode parameter. In
  /// stable mode each new index additionally takes the tone that maximizes
  /// its worst-case (hue, tone) distinctness from every earlier index, so
  /// hue near-returns of the golden angle (e.g. indices 8 apart are only 20°
  /// apart in hue) are compensated by tone. In re-spread mode series cycle
  /// three tiers (mid → far → near), and the last/first pair is also kept
  /// apart in tone for wheel-shaped charts — a guarantee prefix stability
  /// cannot offer, since every stable index is "last" for some n.
  ///
  /// Colors are unique until 8-bit quantization collides; there is no silent
  /// cycling. Identification (matching an arbitrary mark to a legend by
  /// color alone) degrades as n grows; see class docs.
  ///
  /// Achromatic seeds still yield a fully chromatic palette. Unlike
  /// [sequential] and [divergingWith] — where hue *identity* carries meaning
  /// and inventing one would mislead — categorical color only relies on hue
  /// *distinctness*, and any rotation of the wheel is equally correct. The
  /// wheel starts at the u'v' zero direction; a gray-only palette would cap
  /// the distinguishable series at roughly three.
  List<Color> categorical(int n, {bool isColorAtIndexStable = true}) {
    if (n < 0) throw RangeError.range(n, 0, null, 'n');
    if (n == 0) return const [];
    return _categoricalCache.putIfAbsent((n, isColorAtIndexStable), () {
      final seedDirection = _seedHct.uvHue;
      final colors = <Color>[];
      final used = <int>{};
      for (var i = 0; i < n; i++) {
        final direction = sanitizeDegreesDouble(
          isColorAtIndexStable
              ? seedDirection + i * _goldenAngle
              : seedDirection + i * 360.0 / n,
        );
        final tone = _bandTone(
          isColorAtIndexStable
              ? _stableAssignment(i).fraction
              : _respreadTierFraction(i, n),
        );
        var color = hctFromUv(
          tone,
          direction,
          _uvStrength,
          model: colorModel,
        ).color;
        // Near the background edge the tone slice is small; two directions
        // can clamp and quantize to one ARGB. Nudge tone deterministically
        // (small steps, alternating sides) until unique.
        if (!used.add(color.argb)) {
          for (var step = 1; step <= 40; step++) {
            final delta = (step.isOdd ? 1.0 : -1.0) * ((step + 1) ~/ 2) * 1.5;
            final candidate = hctFromUv(
              (tone + delta).clamp(0.0, 100.0),
              direction,
              _uvStrength,
              model: colorModel,
            ).color;
            if (used.add(candidate.argb)) {
              color = candidate;
              break;
            }
          }
        }
        colors.add(color);
      }
      return List.unmodifiable(colors);
    });
  }

  /// Tone tier for series [i] of [n], as a fraction of the visible band.
  /// Cycles mid (0.5) → far (1.0) → near (0.0); adjacent tiers differ by at
  /// least half the band. The final series is reassigned when the cycle
  /// would give it the first series' tier, so wheel charts (pie, donut,
  /// sunburst) keep tone separation across the wrap.
  static double _respreadTierFraction(int i, int n) {
    const fractions = [0.5, 1.0, 0.0];
    var tier = i % 3;
    if (i == n - 1 && n > 3 && tier == 0) {
      final previous = (i - 1) % 3;
      tier = previous == 1 ? 2 : 1;
    }
    return fractions[tier];
  }

  /// Stable-mode tone assignments, greedy and grown lazily; the assignment
  /// for index i never depends on n, so it is prefix-stable.
  ///
  /// A pair is comfortably distinct when its hue gap is ≥ 35° or its tone
  /// gap is ≥ 35% of the band; each new index takes the tone maximizing its
  /// worst-case margin against that criterion. Scoring uses the *rendered*
  /// colors, not the requested lattice: gamut clamping can pull two
  /// requested directions 40° apart to within ≃10° of each other for vivid
  /// seeds, so requested geometry is not trustworthy. A fixed alternation
  /// cannot achieve this criterion at all — any tone pattern of period p
  /// collides with a golden-angle hue near-return at some index gap
  /// divisible by p (period 2 fails at gap 8: 20° apart in hue, same tone).
  /// Verified on rendered colors across diverse seeds and backgrounds:
  /// every pair keeps hue ≥ 25° or tone ≥ 25% of the band through n = 13;
  /// beyond that, distinction degrades gracefully and identification is the
  /// job of labels and shapes.
  final List<({double fraction, double uvHue, double tone})>
  _stableAssignments = [];

  ({double fraction, double uvHue, double tone}) _stableAssignment(int i) {
    while (_stableAssignments.length <= i) {
      final next = _stableAssignments.length;
      final direction = sanitizeDegreesDouble(
        _seedHct.uvHue + next * _goldenAngle,
      );
      final bandWidth = math.max((farTone - nearTone).abs(), 1e-6);
      // The first series is the default for every single-series chart, where
      // there is no sibling color to distinguish it from. Put it at maximum
      // background separation. Previously the empty-comparison score stayed
      // infinite and accidentally selected the first candidate (nearTone),
      // making primary bars almost merge into light chart backgrounds.
      if (next == 0) {
        final rendered = hctFromUv(
          farTone,
          direction,
          _uvStrength,
          model: colorModel,
        );
        _stableAssignments.add((
          fraction: 1.0,
          uvHue: rendered.uvHue,
          tone: rendered.tone,
        ));
        continue;
      }
      var best = (fraction: 0.5, uvHue: direction, tone: _bandTone(0.5));
      var bestScore = double.negativeInfinity;
      for (var k = 0; k <= 20; k++) {
        final x = k / 20.0;
        // Hard guarantee: consecutive series ≥ 40% of the band apart.
        if (next > 0 &&
            (x - _stableAssignments[next - 1].fraction).abs() < 0.40) {
          continue;
        }
        final rendered = hctFromUv(
          _bandTone(x),
          direction,
          _uvStrength,
          model: colorModel,
        );
        var worst = double.infinity;
        for (var j = 0; j < next; j++) {
          final other = _stableAssignments[j];
          final hueGap = _hueGapDegrees(rendered.uvHue - other.uvHue);
          final toneGap = (rendered.tone - other.tone).abs() / bandWidth;
          worst = math.min(worst, math.max(hueGap / 35.0, toneGap / 0.35));
        }
        // Tie-break toward mid-band, where more chroma is available.
        final score = worst - (x - 0.5).abs() * 1e-4;
        if (score > bestScore) {
          bestScore = score;
          best = (fraction: x, uvHue: rendered.uvHue, tone: rendered.tone);
        }
      }
      _stableAssignments.add(best);
    }
    return _stableAssignments[i];
  }

  static double _hueGapDegrees(double degrees) {
    final wrapped = sanitizeDegreesDouble(degrees);
    return math.min(wrapped, 360.0 - wrapped);
  }

  /// Ordered low → high ramp at the seed's hue.
  ///
  /// Tone runs monotonically from [nearTone] (low values, close to the
  /// background but solved to stay visible) to [farTone]; chroma rises with
  /// value, muted → vivid. Interpolation is [Hct.lerpKeepHue] between solved
  /// anchors: perceptual tone/chroma movement with zero hue drift.
  ///
  /// An achromatic seed has no hue, so the ramp stays achromatic: pure gray
  /// from [nearTone] to [farTone], tone alone carrying the value — the same
  /// policy as [divergingWith] with two achromatic seeds, rather than
  /// inventing a hue the seed never expressed.
  late final ToneRamp sequential = () {
    if (!_seedIsChromatic) {
      final low = Hct.from(0.0, 0.0, nearTone, model: colorModel).color;
      final high = Hct.from(0.0, 0.0, farTone, model: colorModel).color;
      return ToneRamp._(
        (t) => Hct.lerpKeepHue(low, high, t, model: colorModel),
      );
    }
    final hue = _seedHct.hue;
    // Muted at the low end so small values recede; vivid at the high end so
    // large values project. Bounds keep dull seeds legible and loud seeds
    // in-gamut across tones.
    final highChroma = math.max(_seedHct.chroma, 48.0).clamp(48.0, 72.0);
    final high = Hct.from(hue, highChroma, farTone, model: colorModel);
    // The high anchor's *rendered* chroma can fall well below the request
    // when farTone sits near the gamut ceiling (vivid red at tone 82 caps
    // near chroma 17). Cap the low end below what the high end actually
    // achieved, or the muted → vivid encoding silently inverts.
    final lowChroma = math.min(
      _seedHct.chroma.clamp(8.0, 20.0),
      high.chroma * 0.6,
    );
    final low = Hct.from(hue, lowChroma, nearTone, model: colorModel).color;
    return ToneRamp._(
      (t) => Hct.lerpKeepHue(low, high.color, t, model: colorModel),
    );
  }();

  /// Diverging ramp: this instance's seed on the low side, [highSeed] on the
  /// high side, neutral at exactly t = 0.5.
  ///
  /// The midpoint is a pure gray at [nearTone]: semantically neutral, but
  /// solved to stay visible against the background. Both sides share one
  /// tone/chroma schedule ([nearTone] → [farTone], gray → vivid), so
  /// perceptual progression is balanced by construction. If [highSeed]'s
  /// chromatic direction is within 90° of the seed's, it is replaced by the
  /// seed's afterimage complement (`harmony(seed, 2)[1]`) so the two sides
  /// remain distinguishable.
  ///
  /// An achromatic seed has no hue to diverge from, so its side stays
  /// achromatic (gray endpoint) rather than inventing a hue. When both
  /// seeds are achromatic, tone itself carries the sign: the ramp runs
  /// monotonically from [nearTone] through mid-gray to [farTone] — light
  /// through dark on light backgrounds and the reverse on dark ones — so
  /// the endpoints remain unmistakably different.
  ToneRamp divergingWith(Color highSeed) {
    final low = _seedHct;
    var high = Hct.fromColor(highSeed, model: colorModel);
    final lowIsChromatic = _seedIsChromatic;
    final highIsChromatic = high.uvChroma >= _achromaticUvChroma;
    if (!lowIsChromatic && !highIsChromatic) {
      final lowEnd = Hct.from(0.0, 0.0, nearTone, model: colorModel).color;
      final highEnd = Hct.from(0.0, 0.0, farTone, model: colorModel).color;
      return ToneRamp._(
        (t) => Hct.lerpKeepHue(lowEnd, highEnd, t, model: colorModel),
      );
    }
    if (lowIsChromatic &&
        highIsChromatic &&
        _uvHueDifference(low.uvHue, high.uvHue) < 90.0) {
      high = harmony(low, 2, tonePolicy: HarmonyTonePolicy.fitUvChroma)[1];
    }
    final neutral = Hct.from(0.0, 0.0, nearTone, model: colorModel).color;
    Color anchor(Hct side, {required bool isChromatic}) => Hct.from(
      isChromatic ? side.hue : 0.0,
      isChromatic ? math.max(side.chroma, 48.0).clamp(48.0, 72.0) : 0.0,
      farTone,
      model: colorModel,
    ).color;
    final lowAnchor = anchor(low, isChromatic: lowIsChromatic);
    final highAnchor = anchor(high, isChromatic: highIsChromatic);
    return ToneRamp._((t) {
      if (t == 0.5) return neutral;
      final amount = (t - 0.5).abs() * 2.0;
      final side = t < 0.5 ? lowAnchor : highAnchor;
      return Hct.lerpKeepHue(neutral, side, amount, model: colorModel);
    });
  }

  static double _uvHueDifference(double a, double b) =>
      180.0 - ((a - b).abs() - 180.0).abs();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartColors &&
          other.seed.argb == seed.argb &&
          other.background.argb == background.argb &&
          other.contrast == contrast &&
          other.algo == algo &&
          other.colorModel == colorModel;

  @override
  int get hashCode =>
      Object.hash(seed.argb, background.argb, contrast, algo, colorModel);
}

/// A reusable chart color ramp; see [ChartColors.sequential] and
/// [ChartColors.divergingWith]. Bins and legends should share one ramp so
/// they agree on colors.
class ToneRamp {
  const ToneRamp._(this._at);

  final Color Function(double t) _at;

  /// Color at [t] in 0–1.
  Color at(double t) {
    if (!t.isFinite || t < 0.0 || t > 1.0) {
      throw ArgumentError.value(t, 't', 'must be finite and between 0 and 1');
    }
    return _at(t);
  }

  /// [count] colors evenly spaced along the ramp, endpoints included.
  List<Color> discretize(int count) {
    if (count < 1) throw RangeError.range(count, 1, null, 'count');
    if (count == 1) return [at(0.5)];
    return [for (var i = 0; i < count; i++) at(i / (count - 1))];
  }
}

Color _defaultBackground(Brightness brightness) => switch (brightness) {
  Brightness.light => const Color(0xffffffff),
  Brightness.dark => const Color(0xff000000),
};

ChartColors _chartColors(
  Color seed,
  Brightness brightness,
  Color? background,
  double contrast,
  Algo algo,
) {
  return ChartColors.fromColorAndBackground(
    seed,
    background ?? _defaultBackground(brightness),
    contrast: contrast,
    algo: algo,
  );
}

/// [count] categorical series colors; see [ChartColors.categorical].
///
/// Prefer holding a [ChartColors] when generating many colors for one chart.
List<Color> categoricalChartPalette({
  required Color seed,
  required Brightness brightness,
  required int count,
  Color? background,
  double contrast = 0.5,
  Algo algo = Algo.apca,
  bool isColorAtIndexStable = true,
}) {
  return _chartColors(
    seed,
    brightness,
    background,
    contrast,
    algo,
  ).categorical(count, isColorAtIndexStable: isColorAtIndexStable);
}

/// Sequential (low → high) chart color at [t] in 0–1; see
/// [ChartColors.sequential].
Color sequentialChartColor({
  required Color seed,
  required Brightness brightness,
  required double t,
  Color? background,
  double contrast = 0.5,
  Algo algo = Algo.apca,
}) {
  return _chartColors(
    seed,
    brightness,
    background,
    contrast,
    algo,
  ).sequential.at(t);
}

/// Diverging chart color at [t] in 0–1, neutral at exactly 0.5; see
/// [ChartColors.divergingWith].
Color divergingChartColor({
  required Color lowSeed,
  required Color highSeed,
  required Brightness brightness,
  required double t,
  Color? background,
  double contrast = 0.5,
  Algo algo = Algo.apca,
}) {
  return _chartColors(
    lowSeed,
    brightness,
    background,
    contrast,
    algo,
  ).divergingWith(highSeed).at(t);
}
