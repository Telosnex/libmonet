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
  }) : _spring = RK4Spring(initValue: start, desc: desc),
       _initialStart = start,
       _initialTarget = end,
       _initialVelocity = velocity {
    _spring.target = end;
    if (velocity != 0.0) {
      _spring._velocity = velocity;
    }
  }

  final RK4Spring _spring;

  /// Immutable initial conditions, so any non-monotonic query (a retarget
  /// reading `value(t)` after `isDone(t2 > t)`, tests probing arbitrary
  /// times) can rebuild the state deterministically.
  final double _initialStart;
  final double _initialTarget;
  final double _initialVelocity;

  // Keep integration on a canonical grid. Advancing directly by each frame's
  // (possibly irregular) delta would be fast, but numerical integration would
  // then produce a slightly different position and velocity for different
  // frame schedules. That carried velocity is observable when retargeting.
  static const double _stepSize = 1.0 / 60.0;

  /// Number of canonical steps committed to [_spring].
  int _committedStep = 0;

  double? _sampleTime;
  double _sampleValue = 0.0;
  double _sampleVelocity = 0.0;
  bool _sampleDone = false;

  void _reset() {
    _spring
      .._startValue = _initialStart
      .._target = _initialStart
      .._value = _initialStart
      .._velocity = 0.0
      .._curT = 0.0
      .._delta = 0.0
      .._isDone = true
      .._accelerationMultiplier = 0.0
      ..target = _initialTarget;
    if (_initialVelocity != 0.0) _spring._velocity = _initialVelocity;
    _committedStep = 0;
    _sampleTime = null;
  }

  static void _copyState(RK4Spring from, RK4Spring to) {
    to
      .._startValue = from._startValue
      .._target = from._target
      .._value = from._value
      .._velocity = from._velocity
      .._curT = from._curT
      .._delta = from._delta
      .._isDone = from._isDone
      .._accelerationMultiplier = from._accelerationMultiplier;
  }

  /// Samples the deterministic state at [time].
  ///
  /// Full 1/60-second steps are retained in [_spring], making monotonic ticker
  /// use O(dt) rather than replaying from zero on every value/velocity/isDone
  /// query. A fractional final step is evaluated on a copy, so it cannot alter
  /// subsequent integration or make retarget velocity depend on frame cadence.
  void _sample(double time) {
    final sampleTime = math.max(0.0, time);
    if (_sampleTime == sampleTime) return;

    // Map floating-point representations of exact frame boundaries back onto
    // the canonical grid.
    final targetStep = (sampleTime / _stepSize + 1e-10).floor();
    if (targetStep < _committedStep) _reset();

    if (!_spring.isDone) {
      while (_committedStep < targetStep) {
        _spring.elapseTime(_stepSize);
        _committedStep++;
        if (_spring.isDone) break;
      }
    }
    // A settled spring has the same state at every later grid point.
    if (_spring.isDone) _committedStep = targetStep;

    final remainder = sampleTime - targetStep * _stepSize;
    if (remainder > 1e-12 && !_spring.isDone) {
      final sampled = RK4Spring(initValue: _spring.value, desc: _spring.desc);
      _copyState(_spring, sampled);
      sampled.elapseTime(remainder);
      _sampleValue = sampled.value;
      _sampleVelocity = sampled.velocity;
      _sampleDone = sampled.isDone;
    } else {
      _sampleValue = _spring.value;
      _sampleVelocity = _spring.velocity;
      _sampleDone = _spring.isDone;
    }
    _sampleTime = sampleTime;
  }

  @override
  double value(double time) {
    _sample(time);
    return _sampleValue;
  }

  @override
  double velocity(double time) {
    _sample(time);
    return _sampleVelocity;
  }

  @override
  bool isDone(double time) {
    _sample(time);
    return _sampleDone;
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
