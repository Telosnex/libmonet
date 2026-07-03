// A Curve adapter that lets implicit animations (AnimatedContainer, etc.)
// use spring dynamics without restructuring to explicit AnimationController.
//
// Copied into libmonet from telosnex's `features/flux` port. Not used by
// `AnimatedMonetTheme` (which uses `MovingTargetAnimation` directly), kept for
// parity with the source library.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:libmonet/flux/rk4_spring.dart';
import 'package:libmonet/flux/spring.dart';

/// A [Curve] backed by a spring simulation.
///
/// Maps t ∈ [0, 1] to the spring's position at time t * [settleTime].
/// The spring runs from 0.0 → 1.0 with zero initial velocity.
class FluxCurve extends Curve {
  FluxCurve({
    SpringDescription spring = FluxSpring.gentle,
    RK4SpringDescription? rk4,
    double? settleTime,
    this.debugLabel,
    // Can be used at runtime; flagged so there's a warning to remove it after
    // debugging and before checking in.
    @visibleForTesting this.debugLogs = false,
  }) : _rk4Desc =
           rk4 ??
           RK4SpringDescription(
             tension: spring.stiffness,
             friction: spring.damping,
           ),
       _settleTime =
           settleTime ??
           _computeSettleTimeRK4(
             rk4 ??
                 RK4SpringDescription(
                   tension: spring.stiffness,
                   friction: spring.damping,
                 ),
           ) {
    assert(() {
      if (debugLogs) {
        debugPrint(
          '[FluxCurve${debugLabel == null ? '' : ' $debugLabel'}] '
          'settle=${(_settleTime * 1000).toStringAsFixed(0)}ms '
          'rk4=$_rk4Desc',
        );
      }
      return true;
    }());
  }

  final RK4SpringDescription _rk4Desc;
  final double _settleTime;
  final String? debugLabel;
  final bool debugLogs;

  /// The spring settle time in seconds, used to map [transformInternal].
  double get settleTime => _settleTime;

  /// The spring's natural duration — the wall-clock time it needs to settle.
  Duration get duration => .new(milliseconds: (_settleTime * 1000).round());

  @override
  double transformInternal(double t) {
    final spring = RK4Spring(initValue: 0.0, desc: _rk4Desc);
    spring.target = 1.0;
    spring.elapseTime(t * _settleTime);
    return spring.value;
  }

  /// Compute the time at which the RK4 spring settles within tolerance.
  static double _computeSettleTimeRK4(RK4SpringDescription desc) {
    final spring = RK4Spring(initValue: 0.0, desc: desc);
    spring.target = 1.0;
    const tolerance = 0.001;
    const maxTime = 5.0;
    const dt = 1.0 / 60.0;
    double t = 0.0;
    while (t < maxTime) {
      spring.elapseTime(dt);
      t += dt;
      if ((spring.value - 1.0).abs() < tolerance &&
          spring.velocity.abs() < tolerance) {
        return math.max(t, 0.1);
      }
    }
    return maxTime;
  }
}
