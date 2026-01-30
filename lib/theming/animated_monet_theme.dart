import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:libmonet/theming/palette.dart';
import 'package:libmonet/theming/monet_theme.dart';
import 'package:libmonet/theming/monet_theme_data.dart';

/// Interpolated theme data that lerps the three seed colors in HCT and
/// constructs Palette for each frame, while keeping ThemeData stable by
/// default to avoid Material transient states.
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
          backgroundTone: lerpDouble(
                  begin.backgroundTone, end.backgroundTone, t) ??
              end.backgroundTone,
          brightness: begin.brightness,
          primary: PaletteLerped(
              a: begin.primary, b: end.primary, t: t),
          secondary:
              PaletteLerped(
              a: begin.secondary, b: end.secondary, t: t),
          tertiary: PaletteLerped(
              a: begin.tertiary, b: end.tertiary, t: t),
          algo: begin.algo,
          contrast: begin.contrast,
          scale: lerpDouble(begin.scale, end.scale, t) ?? end.scale,
          typography: begin.typography,
        );

  @override
  ThemeData createThemeData(BuildContext context) {
    if (animateThemeData) {
      return super.createThemeData(context);
    }
    // Keep Material ThemeData stable during animation to avoid transient glitches.
    if (t >= 1.0) {
      return end.createThemeData(context);
    } else {
      return begin.createThemeData(context);
    }
  }
}

/// Implicitly animated wrapper that smooths Palette transitions.
/// By default, Material ThemeData is not animated.
class AnimatedMonetTheme extends StatefulWidget {
  final MonetThemeData begin;
  final MonetThemeData end;
  final Widget child;
  final bool animateThemeData;
  final Duration duration;
  final Curve curve;

  const AnimatedMonetTheme({
    super.key,
    required this.begin,
    required this.end,
    required this.child,
    this.animateThemeData = false,
    this.duration = kThemeAnimationDuration,
    this.curve = Curves.easeInOut,
  });

  @override
  State<AnimatedMonetTheme> createState() => _AnimatedMonetThemeState();
}

class _AnimatedMonetThemeState extends State<AnimatedMonetTheme>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late MonetThemeData _begin;
  late MonetThemeData _end;

  void _alignBeginTypographyWithEnd() {
    if (identical(_begin.typography, _end.typography)) {
      return;
    }
    _begin = MonetThemeData(
      brightness: _begin.brightness,
      backgroundTone: _begin.backgroundTone,
      primary: _begin.primary,
      secondary: _begin.secondary,
      tertiary: _begin.tertiary,
      algo: _begin.algo,
      contrast: _begin.contrast,
      scale: _begin.scale,
      typography: _end.typography,
    );
  }

  @override
  void initState() {
    super.initState();
    _begin = widget.begin;
    _end = widget.end;
    final shouldSkipAnimation = identical(_begin, _end);
    _alignBeginTypographyWithEnd();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (shouldSkipAnimation) {
      _controller.value = 1.0;
    } else {
      _controller.value = 0.0;
      _controller.animateTo(1.0, curve: widget.curve);
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedMonetTheme oldWidget) {
    super.didUpdateWidget(oldWidget);
    final endChanged = !identical(widget.end, _end);
    final durationChanged = widget.duration != _controller.duration;
    if (durationChanged) {
      _controller.duration = widget.duration;
    }
    if (endChanged) {
      // Capture current displayed state as new begin to avoid snaps.
      final snapshot = InterpolatedMonetThemeData(
        begin: _begin,
        end: _end,
        t: _controller.value,
        animateThemeData: widget.animateThemeData,
      );
      _begin = MonetThemeData(
        brightness: snapshot.brightness,
        backgroundTone: snapshot.backgroundTone,
        primary: PaletteSnapshot.capture(snapshot.primary),
        secondary: PaletteSnapshot.capture(snapshot.secondary),
        tertiary: PaletteSnapshot.capture(snapshot.tertiary),
        algo: snapshot.algo,
        contrast: snapshot.contrast,
        scale: snapshot.scale,
        typography: widget.end.typography,
      );
      _end = widget.end;
      _alignBeginTypographyWithEnd();
      _controller
        ..value = 0.0
        ..animateTo(1.0, curve: widget.curve);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final data = InterpolatedMonetThemeData(
          begin: _begin,
          end: _end,
          t: t,
          animateThemeData: widget.animateThemeData,
        );
        return MonetTheme(
          monetThemeData: t >= 1.0 ? _end : data,
          child: widget.child,
        );
      },
    );
  }
}
