// Spring presets and convenience constructors for Flux animations.
//
// All values ported directly from Fuchsia's Armadillo/Mondrian source.
// Friction is always 50 — Fuchsia only ever varied tension.
//
// Copied into libmonet from telosnex's `features/flux` port.

import 'package:flutter/physics.dart';

import 'package:libmonet/flux/sim.dart';

/// Named spring presets from Fuchsia's Armadillo shell.
///
/// Fuchsia used a single friction (50) and five tension tiers.
/// Names here match Fuchsia's actual usage patterns.
abstract final class FluxSpring {
  /// Tension 250, friction 50. RK4 settle ~1600ms.
  /// Entrance transitions, idle/dim, suggestion splash.
  /// Very overdamped (ζ=1.58) — slow, deliberate, cinematic.
  static const theatrical = SpringDescription(
    mass: 1,
    stiffness: 250,
    damping: 50,
  );
  static const theatricalSettleMilliseconds = 1200;

  /// Tension 450, friction 50. RK4 settle ~680ms.
  /// Fuchsia's default. Bar height, card expand, drag settle, sizing.
  /// Overdamped (ζ=1.18) — no overshoot, smooth deceleration.
  static const gentle = SpringDescription(mass: 1, stiffness: 450, damping: 50);
  static const gentleSettleMilliseconds = 683;

  /// Tension 600, friction 50. RK4 settle ~600ms.
  /// Now bar, quick settings progress.
  /// Near-critically damped (ζ=1.02).
  static const responsive = SpringDescription(
    mass: 1,
    stiffness: 600,
    damping: 50,
  );
  static const responsiveSettleMilliseconds = 483;

  /// Tension 750, friction 50. RK4 settle ~480ms.
  /// Focus, resize, drag transition, scrim, layout transforms.
  /// Barely underdamped (ζ=0.91) — very subtle overshoot then settle.
  /// Most common spring for interactive elements.
  static const snappy = SpringDescription(mass: 1, stiffness: 750, damping: 50);
  static const snappySettleMilliseconds = 317;

  /// Tension 900, friction 50. RK4 settle ~420ms.
  /// Inline preview progress.
  /// Underdamped (ζ=0.83) — slightly more visible overshoot.
  static const snappiest = SpringDescription(
    mass: 1,
    stiffness: 900,
    damping: 50,
  );
  static const snappiestSettleMilliseconds = 383;
}

/// Create a [SimDouble] spring from start → end with initial velocity.
///
/// This is the most common Flux usage: "spring this double from A to B,
/// starting at velocity V."
SimDouble springSimDouble({
  required double start,
  required double end,
  double velocity = 0.0,
  SpringDescription spring = FluxSpring.snappy,
}) {
  return SimDouble(simulation: SpringSimulation(spring, start, end, velocity));
}

/// A [Simulate] function for doubles. Use with [MovingTargetAnimation].
Simulate<double> springSimulateDouble({
  SpringDescription spring = FluxSpring.snappy,
}) {
  return (double start, double end, double velocity) {
    return springSimDouble(
      start: start,
      end: end,
      velocity: velocity,
      spring: spring,
    );
  };
}
