// Port of Fuchsia Mondrian's sim.dart
// Original: topaz/shell/mondrian_story_shell/lib/anim/sim.dart
// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// Copied into libmonet from telosnex's `features/flux` port so
// `AnimatedMonetTheme` can use velocity-continuous moving-target animation
// instead of a fixed-duration `AnimationController`.

import 'package:flutter/painting.dart';
import 'package:flutter/physics.dart';

/// The base class for all generic immutable simulations.
///
/// Like Flutter's [Simulation] but generic over T, not just double.
/// This is the foundation that lets springs work on Offset, Rect, or any type.
abstract class Sim<T> {
  Sim({Tolerance? tolerance}) : tolerance = tolerance ?? .defaultTolerance;

  /// The output of the object in the simulation at the given time.
  T value(double time);

  /// The change in value of the object in the simulation at the given time.
  T velocity(double time);

  /// Whether the simulation is "done" at the given time.
  bool isDone(double time);

  /// How close to the actual end of the simulation a value at a particular time
  /// must be before [isDone] considers the simulation to be "done".
  final Tolerance tolerance;
}

/// Generates a Sim with given params.
///
/// Used by [MovingTargetAnimation] to create new springs whenever the target
/// moves, picking up from current value and velocity.
typedef Simulate<T> = Sim<T> Function(T start, T end, T velocity);

/// Convenience wrapper for Flutter's [Simulation] (which is double-only).
class SimDouble extends Sim<double> {
  SimDouble({required this.simulation})
    : super(tolerance: simulation.tolerance);

  final Simulation simulation;

  @override
  double value(double time) => simulation.x(time);

  @override
  double velocity(double time) => simulation.dx(time);

  @override
  bool isDone(double time) => simulation.isDone(time);
}

/// A Simulation that never changes its value.
class StaticSimulation extends Simulation {
  StaticSimulation({required this._value});

  final double _value;

  @override
  double x(double time) => _value;

  @override
  double dx(double time) => 0.0;

  @override
  bool isDone(double time) => true;
}

/// 2D Sim where each axis is independent of the other.
///
/// Used for drag/fling on both axes simultaneously.
class Independent2DSim extends Sim<Offset> {
  Independent2DSim({required this.xSim, required this.ySim, super.tolerance});

  /// Convenience constructor when the simulation is symmetric on each axis.
  Independent2DSim.symmetric({required Simulation sim, super.tolerance})
    : xSim = sim,
      ySim = sim;

  /// Convenience constructor when the value is fixed.
  Independent2DSim.static({required Offset value})
    : xSim = StaticSimulation(value: value.dx),
      ySim = StaticSimulation(value: value.dy);

  final Simulation xSim;
  final Simulation ySim;

  @override
  Offset value(double time) => .new(xSim.x(time), ySim.x(time));

  @override
  Offset velocity(double time) => .new(xSim.dx(time), ySim.dx(time));

  @override
  bool isDone(double time) => xSim.isDone(time) && ySim.isDone(time);
}

/// Rect Sim with independent size and position simulators.
///
/// Used by Mondrian to animate surface frames: position and size spring
/// independently, with different stiffness if desired.
class IndependentRectSim extends Sim<Rect> {
  IndependentRectSim({
    required this.sizeSim,
    required this.positionSim,
    FractionalOffset? origin,
    super.tolerance,
  }) : origin = origin ?? .center;

  final Sim<Offset> sizeSim;
  final Sim<Offset> positionSim;
  final FractionalOffset origin;

  @override
  Rect value(double time) {
    final size = Size.zero + sizeSim.value(time);
    return (positionSim.value(time) - origin.alongSize(size)) & size;
  }

  @override
  Rect velocity(double time) =>
      positionSim.velocity(time) & (Size.zero + sizeSim.velocity(time));

  @override
  bool isDone(double time) => positionSim.isDone(time) && sizeSim.isDone(time);
}
