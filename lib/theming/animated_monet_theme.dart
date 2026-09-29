import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';
import 'package:libmonet/theming/interpolation_style.dart';
import 'package:libmonet/theming/monet_theme.dart';
import 'package:libmonet/theming/monet_theme_data.dart';
import 'package:libmonet/theming/monet_paint_colors.dart';
import 'package:libmonet/theming/palette_lerped.dart';

/// Interpolated theme data that lerps the three palettes while keeping
/// [ThemeData] stable by default to avoid Material transient states.
///
/// Still used directly by [MonetThemeDataTween] for callers that want a
/// simple scalar-`t` lerp between two known themes (e.g. tests, or explicit
/// non-widget interpolation). [AnimatedMonetTheme] itself no longer drives its
/// live animation through this class -- see the shared-progress notes
/// on [AnimatedMonetTheme].
class InterpolatedMonetThemeData extends MonetThemeData {
  @override
  MonetThemeData get target => end.target;
  @override
  bool get isAnimating => t < 1;

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
         shapeTheme: t < 1.0 ? begin.shapeTheme : end.shapeTheme,
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
/// this internally for its live animation -- see the shared-progress
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

/// Animates solved palette colors with shared-progress interpolation.
/// Each palette/recipe has one critically damped 0→1 progress spring. A changed
/// target snapshots the visible colors and restarts progress from rest: position
/// is continuous, velocity intentionally is not. Frequent retargets may lag the
/// input more than a momentum-preserving spring, then catch up after it stops.
/// Contrast-polarity changes fade between solved colors rather than rerunning
/// the contrast solver on intermediate seeds. Intermediate colors are not
/// guaranteed to meet either endpoint's contrast requirement.
///
/// There are two notification channels:
/// * [MonetPaintColors] advances progress on every ticker tick without RGB work.
///   Paint-aware consumers retain and listen to a [MonetPaletteBinding]
///   for repaints, and read the binding's palette without rebuilding widgets.
/// * [MonetTheme] publishes inherited values at [maxUpdatesPerSecond]. Widgets
///   using `MonetTheme.of(context)` rebuild on those publishes. Final-only mode
///   requires explicit paint bindings for intermediate color motion.
///
/// Palette getters discover their roles automatically; optional binding role
/// lists only prewarm them. All outputs calculate RGB lazily on read;
/// bindings notify only when a retained role may change. First use
/// joins an existing role track, or starts at the current endpoint when no
/// history exists. Prewarm interactive states if their first appearance during
/// a fade must follow the already-running trajectory.
///
/// [InterpolationStyle.cartesian] (default) follows the color model's Cartesian
/// chromatic coordinates and can pass through lower chroma. Polar motion follows
/// the shortest hue arc. All components use the same progress. Changing the
/// model or path preserves displayed pixels and starts a new interpolation.
///
/// Material [ThemeData] remains anchored to the last settled theme unless
/// [animateThemeData] is true, avoiding transient Material-component states.
/// [duration] controls spring pacing, not a fixed completion deadline; [curve]
/// remains for source compatibility and does not shape springs. Animation time
/// respects Flutter's [timeDilation]; inherited publish throttling uses real
/// frame time independently.
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
  ///   animation completes. Paint integrations own a `bindThemePalette`/`bind`
  ///   subscription; palette getters automatically discover which colors to
  ///   animate. This is ideal for high-frequency local palette
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
        defaultValue: InterpolationStyle.cartesian,
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
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final MonetPaintColors _paintColors;
  late MonetThemeData _published;
  Duration? _lastPublishedAt;
  bool _pendingEnd = false;
  // A continuous animation-time clock, including across ticker restarts.
  // Ticker elapsed respects timeDilation. Raw system frame time is used ONLY
  // for publish throttling, never to advance the springs. While idle, bindings
  // retarget at the last sample; starting the ticker begins a fresh segment.
  double _motionTime = 0;
  double _tickerOrigin = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _paintColors = MonetPaintColors(
      widget.data,
      requestFrame: _ensureTick,
      clock: () => _motionTime,
      duration: widget.duration,
      style: widget.interpolationStyle,
      animateThemeData: widget.animateThemeData,
      animateUnboundRoles:
          widget.maxUpdatesPerSecond != 0 || widget.animateThemeData,
    );
    _published = _paintColors.value;
  }

  void _ensureTick() {
    if (mounted && !_ticker.isActive) {
      _tickerOrigin = _motionTime;
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedMonetTheme oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = widget.data != oldWidget.data;
    if (!changed &&
        widget.duration == oldWidget.duration &&
        widget.interpolationStyle == oldWidget.interpolationStyle &&
        widget.animateThemeData == oldWidget.animateThemeData &&
        widget.maxUpdatesPerSecond == oldWidget.maxUpdatesPerSecond) {
      return;
    }
    _pendingEnd |= changed;
    _paintColors.retarget(
      widget.data,
      time: _motionTime,
      duration: widget.duration,
      style: widget.interpolationStyle,
      animateThemeData: widget.animateThemeData,
      animateUnboundRoles:
          widget.maxUpdatesPerSecond != 0 || widget.animateThemeData,
    );
    if (!_paintColors.value.isAnimating) {
      _finishTheme();
    } else {
      if (widget.maxUpdatesPerSecond == null ||
          widget.maxUpdatesPerSecond! > 0) {
        _publish(_paintColors.value);
      }
      _lastPublishedAt = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    }
    if (_paintColors.isAnimating) {
      _ensureTick();
    } else {
      _ticker.stop();
    }
  }

  void _tick(Duration elapsed) {
    _motionTime = _tickerOrigin + elapsed.inMicroseconds / 1e6;
    _paintColors.sample(_motionTime);
    if (!_paintColors.isAnimating) _ticker.stop();
    if (!_paintColors.value.isAnimating) {
      _finishTheme();
    } else if (_shouldPublish()) {
      _publish(_paintColors.value);
    }
  }

  // Custom recipe changes are local paint motion, not a reason to withhold
  // typography/brightness/shape updates or delay a theme generation's onEnd.
  void _finishTheme() {
    _publish(_paintColors.value);
    if (_pendingEnd) {
      _pendingEnd = false;
      widget.onEnd?.call();
    }
  }

  bool _shouldPublish() {
    final limit = widget.maxUpdatesPerSecond;
    if (limit == null) return true;
    if (limit <= 0) return false;
    final last = _lastPublishedAt;
    return last == null ||
        SchedulerBinding.instance.currentSystemFrameTimeStamp - last >=
            Duration(microseconds: (1e6 / limit).round());
  }

  void _publish(MonetThemeData value) {
    if (!mounted || _published == value) return;
    _lastPublishedAt = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    setState(() => _published = value);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _paintColors.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MonetPaintColorsScope(
    colors: _paintColors,
    child: MonetTheme(monetThemeData: _published, child: widget.child),
  );
}
