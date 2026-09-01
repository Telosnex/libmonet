import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/flux/rk4_spring.dart';

void main() {
  test('monotonic queries step only the elapsed delta', () {
    // AnimatedMonetTheme asks value/velocity/isDone for every channel on every
    // frame. Once sampled at a large absolute time, the next frame must cost
    // only one frame's delta -- not replay the entire simulation from t=0.
    const elapsed = 5.0;
    const frame = 1 / 60;
    const samples = 20;

    final baseline = Stopwatch()..start();
    for (var i = 0; i < samples; i++) {
      RK4SpringSim(start: 0, end: 100).value(elapsed);
    }
    baseline.stop();

    final sims = List.generate(
      samples,
      (_) => RK4SpringSim(start: 0, end: 100)..value(elapsed),
    );
    final nextFrame = Stopwatch()..start();
    for (final sim in sims) {
      sim
        ..value(elapsed + frame)
        ..velocity(elapsed + frame)
        ..isDone(elapsed + frame);
    }
    nextFrame.stop();

    expect(
      nextFrame.elapsedMicroseconds,
      lessThan(baseline.elapsedMicroseconds ~/ 5),
      reason:
          'the next frame should integrate only its delta; replaying five '
          'seconds for each query stalls multi-channel theme animation',
    );
  });

  test('position and velocity do not depend on sampling cadence', () {
    for (final initialVelocity in [0.0, 3.0, -3.0]) {
      final incrementallySampled = RK4SpringSim(
        start: 0,
        end: 100,
        velocity: initialVelocity,
      );
      var time = 0.0;
      for (var frame = 0; frame < 180; frame++) {
        // Deliberately irregular intervals exercise fractional RK4 steps.
        time += [1 / 60, 1 / 47, 1 / 90, 0.031][frame % 4];
        final directlySampled = RK4SpringSim(
          start: 0,
          end: 100,
          velocity: initialVelocity,
        );

        expect(
          incrementallySampled.value(time),
          closeTo(directlySampled.value(time), 1e-9),
          reason: 'position at t=$time, initial velocity=$initialVelocity',
        );
        expect(
          incrementallySampled.velocity(time),
          closeTo(directlySampled.velocity(time), 1e-9),
          reason: 'velocity at t=$time, initial velocity=$initialVelocity',
        );
        expect(incrementallySampled.isDone(time), directlySampled.isDone(time));
      }
    }
  });

  test('60 Hz and 120 Hz histories agree at shared frame times', () {
    final at60Hz = RK4SpringSim(start: 0, end: 100, velocity: -2);
    final at120Hz = RK4SpringSim(start: 0, end: 100, velocity: -2);

    for (var frame120 = 1; frame120 <= 360; frame120++) {
      final time = frame120 / 120;
      at120Hz.value(time);
      if (frame120.isEven) {
        expect(at120Hz.value(time), closeTo(at60Hz.value(time), 1e-9));
        expect(at120Hz.velocity(time), closeTo(at60Hz.velocity(time), 1e-9));
        expect(at120Hz.isDone(time), at60Hz.isDone(time));
      }
    }
  });

  test('backward and arbitrary-time queries are deterministic', () {
    final queriedOutOfOrder = RK4SpringSim(start: -20, end: 80, velocity: 4)
      ..value(2)
      ..velocity(0.7)
      ..isDone(4);

    for (final time in [0.1, 1.3, 0.4, 5.0, 0.0, 0.8]) {
      final fresh = RK4SpringSim(start: -20, end: 80, velocity: 4);
      expect(queriedOutOfOrder.value(time), closeTo(fresh.value(time), 1e-9));
      expect(
        queriedOutOfOrder.velocity(time),
        closeTo(fresh.velocity(time), 1e-9),
      );
      expect(queriedOutOfOrder.isDone(time), fresh.isDone(time));
    }
  });

  test('retargeting preserves interrupted position and velocity', () {
    for (final newTarget in [-50.0, 200.0]) {
      final interrupted = RK4SpringSim(start: 0, end: 100, velocity: 2);
      // Reach the interruption through an irregular frame history.
      var time = 0.0;
      for (final dt in [0.013, 0.021, 0.008, 0.019, 0.014]) {
        time += dt;
        interrupted.value(time);
      }
      final position = interrupted.value(time);
      final velocity = interrupted.velocity(time);
      final retargeted = RK4SpringSim(
        start: position,
        end: newTarget,
        velocity: velocity,
      );

      expect(retargeted.value(0), position);
      expect(retargeted.velocity(0), velocity);
      expect(retargeted.isDone(0), isFalse);

      // It must immediately continue moving rather than pause after the
      // interruption. RK4Spring exposes normalized progress velocity, not the
      // numerical derivative of its output value, so continuity is asserted
      // through the exact carried velocity above.
      expect(retargeted.value(1 / 120), isNot(position));
    }
  });
}
