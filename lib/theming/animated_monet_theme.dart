import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:libmonet/theming/monet_theme.dart';
import 'package:libmonet/theming/monet_theme_data.dart';
import 'package:libmonet/theming/palette_lerped.dart';

/// Interpolated theme data that lerps the three palettes while keeping
/// [ThemeData] stable by default to avoid Material transient states.
class InterpolatedMonetThemeData extends MonetThemeData {
  final MonetThemeData begin;
  final MonetThemeData end;
  final double t;
  final bool animateThemeData;

  InterpolatedMonetThemeData({
    required this.begin,
    required this.end,
    required this.t,
    this.animateThemeData = false,
  }) : super(
         backgroundTone:
             lerpDouble(begin.backgroundTone, end.backgroundTone, t) ??
             end.backgroundTone,
         brightness: t < 1.0 ? begin.brightness : end.brightness,
         primary: PaletteLerped(a: begin.primary, b: end.primary, t: t),
         secondary: PaletteLerped(a: begin.secondary, b: end.secondary, t: t),
         tertiary: PaletteLerped(a: begin.tertiary, b: end.tertiary, t: t),
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

  MonetThemeDataTween({super.begin, super.end, this.animateThemeData = false});

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
/// By default, Material [ThemeData] is not animated; only [MonetThemeData]
/// palette tokens are interpolated. Set [animateThemeData] to also interpolate
/// the generated Material [ThemeData].
class AnimatedMonetTheme extends ImplicitlyAnimatedWidget {
  final MonetThemeData data;
  final Widget child;
  final bool animateThemeData;

  const AnimatedMonetTheme({
    super.key,
    required this.data,
    required this.child,
    this.animateThemeData = false,
    super.curve,
    super.duration = kThemeAnimationDuration,
    super.onEnd,
  });

  @override
  AnimatedWidgetBaseState<AnimatedMonetTheme> createState() =>
      _AnimatedMonetThemeState();
}

class _AnimatedMonetThemeState
    extends AnimatedWidgetBaseState<AnimatedMonetTheme> {
  MonetThemeDataTween? _data;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _data =
        visitor(
              _data,
              widget.data,
              (dynamic value) => MonetThemeDataTween(
                begin: value as MonetThemeData,
                animateThemeData: widget.animateThemeData,
              ),
            )!
            as MonetThemeDataTween;
    _data!.animateThemeData = widget.animateThemeData;
  }

  @override
  Widget build(BuildContext context) {
    return MonetTheme(
      monetThemeData: _data!.evaluate(animation),
      child: widget.child,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<MonetThemeDataTween>(
        'data',
        _data,
        showName: false,
        defaultValue: null,
      ),
    );
    properties.add(
      FlagProperty(
        'animateThemeData',
        value: widget.animateThemeData,
        ifTrue: 'animating Material ThemeData',
      ),
    );
  }
}
