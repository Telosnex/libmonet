// Port of Fuchsia's RK4SpringSimulation.
// Original: topaz/public/dart/widgets/lib/src/widgets/rk4_spring_simulation.dart
// Copyright 2016 The Fuchsia Authors. BSD license.
//
// This is NOT Flutter's built-in SpringSimulation. The key difference is the
// _accelerationMultiplier — a ramp from 0→1 over the first ~167ms that gives
// every spring a soft onset. Without it, the spring yanks immediately on target
// change. With it, the spring starts gentle and builds up force.
//
// Copied into libmonet from telosnex's `features/flux` port.

import 'dart:math' as math;

import 'package:flutter/physics.dart';

import 'package:libmonet/flux/sim.dart';

/// The settle threshold for the spring (both distance and velocity).
const double _kTolerance = 0.01;

/// Spring parameters for the RK4 simulation.
///
/// [tension] maps to stiffness. [friction] maps to damping.
/// Fuchsia always used friction=50 and varied tension:
///   - 250 (theatrical/slow)
///   - 450 (default)
///   - 600 (responsive)
///   - 750 (snappy)
///   - 900 (snappiest)
class RK4SpringDescription {
  const RK4SpringDescription({this.tension = 450.0, this.friction = 50.0});

  /// Create from Flutter's [SpringDescription]. Maps stiffness→tension,
  /// damping→friction. Mass is ignored (Fuchsia always used mass=1).
  RK4SpringDescription.fromSpring(SpringDescription sd)
    : tension = sd.stiffness,
      friction = sd.damping;

  final double tension;
  final double friction;

  @override
  String toString() => 'RK4Spring(tension: $tension, friction: $friction)';
}

/// A spring simulation using 4th-order Runge-Kutta numerical integration.
///
/// The critical feature: [_accelerationMultiplier] ramps from 0→1 over ~167ms.
/// This makes the spring start gentle and build up force — the "soft onset"
/// that no standard analytical spring can produce.
///
/// Usage:
/// ```dart
/// final spring = RK4Spring(
///   initValue: 0.0,
///   desc: RK4SpringDescription(tension: 450, friction: 50),
/// );
/// spring.target = 1.0;
/// // Call elapseTime() each frame, read spring.value
/// ```
class RK4Spring {
  RK4Spring({double initValue = 0.0, this.desc = const RK4SpringDescription()})
    : _startValue = initValue,
      _target = initValue,
      _value = initValue,
      _delta = 0.0,
      _velocity = 0.0,
      _accelerationMultiplier = 0.0,
      _isDone = true;

  final RK4SpringDescription desc;

  double _startValue;
  double _target;
  double _velocity;
  double _accelerationMultiplier;
  bool _isDone;
  double _curT = 0.0;
  double _delta;
  double _value;

  /// Set a new target. The spring picks up from its current value and velocity.
  /// If the direction flips, velocity is negated (preserving momentum).
  set target(double target) {
    if (_target != target) {
      final wasGoingPositively = _target > _startValue;
      final willBeGoingPositively = target > value;
      if (wasGoingPositively != willBeGoingPositively) {
        _velocity = -_velocity;
      }
      _startValue = value;
      _target = target;
      _delta = _target - _startValue;
      if (_startValue != _target) {
        _curT = 0.0;
        _isDone = false;
        _accelerationMultiplier = 0.0;
      }
    }
  }

  bool get isDone => _isDone;
  double get value => _value;
  double get target => _target;
  double get velocity => _velocity;

  /// Advance the simulation by [seconds].
  void elapseTime(double seconds) {
    if (isDone) return;

    double secondsRemaining = seconds;
    const maxStepSize = 1.0 / 60.0;

    while (secondsRemaining > 0.0) {
      final stepSize = secondsRemaining > maxStepSize
          ? maxStepSize
          : secondsRemaining;

      // THE KEY FEATURE: acceleration ramp.
      // Grows from 0→1 at rate 6.0/s. At 60fps that's 0→1 in ~10 frames (167ms).
      // This is why Fuchsia springs start gentle instead of yanking.
      _accelerationMultiplier = math.min(
        1.0,
        _accelerationMultiplier + stepSize * 6.0,
      );

      if (_evaluateRK(stepSize)) {
        _curT = 1.0;
        _value = _target;
        _velocity = 0.0;
        _isDone = true;
        _accelerationMultiplier = 0.0;
        return;
      }
      secondsRemaining -= maxStepSize;
    }
    _value = _startValue + _curT * _delta;
  }

  /// One RK4 integration step.
  /// Returns true if the spring has settled within tolerance.
  bool _evaluateRK(double stepSize) {
    final x = _curT - 1.0;
    final v = _velocity;

    final aDx = v;
    final aDv = _accel(x, v);

    final bDx = v + aDv * (stepSize * 0.5);
    final bDv = _accel(x + aDx * (stepSize * 0.5), bDx);

    final cDx = v + bDv * (stepSize * 0.5);
    final cDv = _accel(x + bDx * (stepSize * 0.5), cDx);

    final dDx = v + cDv * stepSize;
    final dDv = _accel(x + cDx * stepSize, dDx);

    final dxdt = (1.0 / 6.0) * (aDx + 2.0 * (bDx + cDx) + dDx);
    final dvdt = (1.0 / 6.0) * (aDv + 2.0 * (bDv + cDv) + dDv);

    _curT = 1.0 + (x + dxdt * stepSize);
    _velocity = v + dvdt * stepSize;

    return x.abs() < _kTolerance && _velocity.abs() < _kTolerance;
  }

  /// Spring force with acceleration multiplier.
  double _accel(double x, double vel) =>
      (-desc.tension * x - desc.friction * vel) * _accelerationMultiplier;
}

/// Wraps [RK4Spring] as a [Sim<double>] for use with [SimAnimationController].
///
/// Unlike [SimDouble] (which wraps Flutter's analytical SpringSimulation),
/// this uses numerical RK4 integration with the soft-onset acceleration ramp.
class RK4SpringSim extends Sim<double> {
  RK4SpringSim({
    required double start,
    required double end,
    double velocity = 0.0,
    RK4SpringDescription desc = const RK4SpringDescription(),
  }) : _spring = RK4Spring(initValue: start, desc: desc) {
    _spring.target = end;
    if (velocity != 0.0) {
      _spring._velocity = velocity;
    }
  }

  final RK4Spring _spring;

  @override
  double value(double time) {
    // RK4 is stateful (steps forward), not random-access like analytical.
    // For Sim<T> compatibility we reset and step forward to the requested time.
    // This is fine because SimAnimationController calls with monotonically
    // increasing time.
    final fresh = RK4Spring(initValue: _spring._startValue, desc: _spring.desc);
    fresh.target = _spring._target;
    fresh._velocity = _spring._velocity;
    fresh.elapseTime(time);
    return fresh.value;
  }

  @override
  double velocity(double time) {
    final fresh = RK4Spring(initValue: _spring._startValue, desc: _spring.desc);
    fresh.target = _spring._target;
    fresh._velocity = _spring._velocity;
    fresh.elapseTime(time);
    return fresh.velocity;
  }

  @override
  bool isDone(double time) {
    final fresh = RK4Spring(initValue: _spring._startValue, desc: _spring.desc);
    fresh.target = _spring._target;
    fresh._velocity = _spring._velocity;
    fresh.elapseTime(time);
    return fresh.isDone;
  }
}

/// Create an [RK4SpringSim] from start → end.
RK4SpringSim rk4SpringSim({
  required double start,
  required double end,
  double velocity = 0.0,
  RK4SpringDescription desc = const RK4SpringDescription(),
}) {
  return RK4SpringSim(start: start, end: end, velocity: velocity, desc: desc);
}
