import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:libmonet/theming/interpolation_style.dart';
import 'package:libmonet/theming/monet_theme.dart';
import 'package:libmonet/theming/monet_theme_data.dart';
import 'package:libmonet/theming/monet_paint_colors.dart';
import 'package:libmonet/theming/palette_lerped.dart';

/// Interpolated theme data that lerps the three palettes while keeping
/// [ThemeData] stable by default to avoid Material transient states.
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

/// Tween used by [AnimatedMonetTheme].
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
/// [interpolationStyle] controls how palette colors move through color space.
/// The default is [InterpolationStyle.cartesian].
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
  late final AnimationController _controller;
  late MonetThemeData _begin;
  late MonetThemeData _end;
  late MonetThemeData _published;
  late final MonetPaintColors _paintColors;
  Duration? _lastPublishedElapsed;

  @override
  void initState() {
    super.initState();
    _begin = widget.data;
    _end = widget.data;
    _published = widget.data;
    _paintColors = MonetPaintColors(widget.data);
    _controller =
        AnimationController(vsync: this, duration: widget.duration, value: 1)
          ..addListener(_handleTick)
          ..addStatusListener(_handleStatus);
  }

  @override
  void didUpdateWidget(covariant AnimatedMonetTheme oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;

    final targetChanged = widget.data != _end;
    final interpolationChanged =
        widget.animateThemeData != oldWidget.animateThemeData ||
        widget.interpolationStyle != oldWidget.interpolationStyle ||
        widget.curve != oldWidget.curve;

    if (targetChanged) {
      final current = _evaluate();
      _begin = current;
      _end = widget.data;
      _lastPublishedElapsed = null;
      if (widget.duration == Duration.zero || _begin == _end) {
        _controller.value = 1;
        _publish(_end, force: true);
      } else {
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
        // The retarget publish/paint-bus update is the first publication for
        // the new animation. Start throttling from t=0 so 120Hz tickers don't
        // publish again on the very next vsync.
        _lastPublishedElapsed = Duration.zero;
        _controller.forward(from: 0);
      }
    } else if (interpolationChanged) {
      final value = _evaluate();
      if (_publishesIntermediateInheritedThemes) {
        _publish(value, force: true);
      } else {
        _paintColors.value = value;
      }
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleTick)
      ..removeStatusListener(_handleStatus)
      ..dispose();
    _paintColors.dispose();
    super.dispose();
  }

  void _handleTick() {
    final elapsed = _controller.lastElapsedDuration ?? Duration.zero;
    final value = _evaluate();
    _paintColors.value = value;
    if (_shouldPublish(elapsed) || _controller.isCompleted) {
      _lastPublishedElapsed = elapsed;
      _publish(value);
    }
  }

  void _handleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _lastPublishedElapsed = _controller.lastElapsedDuration;
    _paintColors.value = _end;
    _publish(_end, force: true);
    widget.onEnd?.call();
  }

  bool get _publishesIntermediateInheritedThemes {
    final maxUpdates = widget.maxUpdatesPerSecond;
    return maxUpdates == null || maxUpdates > 0;
  }

  bool _shouldPublish(Duration elapsed) {
    final maxUpdates = widget.maxUpdatesPerSecond;
    if (maxUpdates == null) return true;
    if (maxUpdates <= 0) return false;
    final last = _lastPublishedElapsed;
    if (last == null) return true;
    final minInterval = Duration(
      microseconds: (Duration.microsecondsPerSecond / maxUpdates).round(),
    );
    return elapsed - last >= minInterval;
  }

  MonetThemeData _evaluate() {
    final t = widget.curve.transform(_controller.value.clamp(0.0, 1.0));
    return MonetThemeDataTween(
      begin: _begin,
      end: _end,
      animateThemeData: widget.animateThemeData,
      interpolationStyle: widget.interpolationStyle,
    ).lerp(t);
  }

  void _publish(MonetThemeData value, {bool force = false}) {
    _paintColors.value = value;
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
