import 'dart:math' as math;

/// Critically damped 0→1 progress, always starting at rest. Retargeting rebases
/// visible colors outside this class, then calls [restart]. No carried velocity.
class ProgressMotion {
  double? _start;
  double _omega = 1;

  double get omega => _omega;

  void restart(double time, double omega) {
    assert(time.isFinite && omega.isFinite && omega > 0);
    _start = time;
    _omega = omega;
  }

  /// Normalized progress, exactly 1 when complete. Evaluate motion and
  /// completion together so they cannot disagree or repeat the exponential.
  /// Stop when remaining progress and predicted one-frame travel are both at
  /// most 0.01%, independent of color distance/model and getter frequency.
  double sample(double time) {
    final start = _start;
    if (start == null) return 1;
    final x = _omega * math.max(0.0, time - start);
    final decay = math.exp(-x);
    final remaining = (1 + x) * decay;
    return remaining <= 0.0001 && _omega * x * decay / 60 <= 0.0001
        ? 1
        : 1 - remaining;
  }

  void snap() => _start = null;
}

/// Duration remains a response-speed hint, not a fixed completion deadline.
/// Reference tension 750 corresponds to a 317 ms response hint; scale tension
/// inversely with that hint and clamp it to avoid excessively slow/stiff motion.
double paintMotionOmega(Duration duration) {
  final ms = duration.inMicroseconds / 1000;
  return math.sqrt(ms <= 1 ? 4000 : (750 * 317 / ms).clamp(60, 4000));
}
