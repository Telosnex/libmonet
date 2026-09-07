import 'dart:math' as math;
import 'dart:ui';

import 'package:androidx_graphics_shapes/material_shapes.dart';

/// How a catalog shape's optical center was selected.
enum OpticalCenterMethod {
  convexHullCentroid,
  maximumClearanceOnReflectionAxis,
  reflectionAxesIntersection,
}

/// Offline optical-center result used to generate the checked-in catalog data.
class OpticalCenterResult {
  const OpticalCenterResult({
    required this.center,
    required this.hullCentroid,
    required this.axisCount,
    required this.method,
  });

  final Offset center;
  final Offset hullCentroid;
  final int axisCount;
  final OpticalCenterMethod method;
}

List<Offset> _sampleOutline(
  List<Cubic> cubics, {
  int subdivisionsPerCubic = 200,
}) {
  if (cubics.isEmpty || subdivisionsPerCubic <= 0) {
    throw ArgumentError(
      'A nonempty outline and positive subdivision count are required.',
    );
  }
  return [
    for (final cubic in cubics)
      for (var i = 0; i < subdivisionsPerCubic; i++)
        _cubicPoint(cubic, i / subdivisionsPerCubic),
  ];
}

Offset _cubicPoint(Cubic cubic, double t) {
  final u = 1 - t;
  return Offset(
    u * u * u * cubic.anchor0X +
        3 * u * u * t * cubic.control0X +
        3 * u * t * t * cubic.control1X +
        t * t * t * cubic.anchor1X,
    u * u * u * cubic.anchor0Y +
        3 * u * u * t * cubic.control0Y +
        3 * u * t * t * cubic.control1Y +
        t * t * t * cubic.anchor1Y,
  );
}

/// Finds a content anchor from the silhouette alone, without shape-name rules.
///
/// Reflection reverses arc-length order. This fits that reversal at every
/// cyclic offset to discover axes. Multiple axes pin the center at their common
/// intersection (equivalently, the area centroid). With exactly one axis, the
/// point of maximum outline clearance on that axis wins. Shapes with no
/// detected reflection axis use their convex-hull centroid.
///
/// [cubics] and [path] must describe the same closed silhouette. The returned
/// point is only an anchor; safe rectangles centered there are separately
/// certified against the original cubics.
OpticalCenterResult findOpticalCenter({
  required List<Cubic> cubics,
  required Path path,
  required Offset areaCentroid,
}) {
  final outline = _sampleOutline(cubics);
  final hullCentroid = _convexHullCentroid(outline);
  final samples = _arcSamples(
    outline,
    512,
  ).map((point) => point - areaCentroid).toList();
  final axes = <double>[];
  final fits = [
    for (var i = 0; i < samples.length; i++)
      _reflectionFit(samples, i.toDouble()),
  ];
  for (var i = 0; i < fits.length; i++) {
    if (fits[i].error > fits[(i + fits.length - 1) % fits.length].error ||
        fits[i].error > fits[(i + 1) % fits.length].error) {
      continue;
    }
    var shift = i.toDouble();
    var best = fits[i];
    for (var step = 0.5; step > 1e-5; step /= 2) {
      for (final candidate in [shift - step, shift + step]) {
        final fit = _reflectionFit(samples, candidate);
        if (fit.error < best.error) {
          best = fit;
          shift = candidate;
        }
      }
    }
    // Numerical recognition tolerance: < 0.08 px at this sheet's 80 px size.
    // Max residual (not just RMS) guards against isolated asymmetric features.
    if (best.error < 0.0005 &&
        _maximumReflectionError(samples, shift, best.angle) < 0.001 &&
        axes.every((angle) => math.sin(angle - best.angle).abs() > 0.01)) {
      axes.add(best.angle);
    }
  }
  if (axes.isEmpty) {
    return OpticalCenterResult(
      center: hullCentroid,
      hullCentroid: hullCentroid,
      axisCount: 0,
      method: OpticalCenterMethod.convexHullCentroid,
    );
  }
  if (axes.length > 1) {
    return OpticalCenterResult(
      center: areaCentroid,
      hullCentroid: hullCentroid,
      axisCount: axes.length,
      method: OpticalCenterMethod.reflectionAxesIntersection,
    );
  }

  final direction = Offset(math.cos(axes.single), math.sin(axes.single));
  final projections = [
    for (final point in outline) _dot(point - areaCentroid, direction),
  ];
  final low = projections.reduce(math.min);
  final high = projections.reduce(math.max);
  const intervals = 4096;
  final step = (high - low) / intervals;
  var bestCenter = areaCentroid;
  var bestClearance = -double.infinity;
  var bestDistance = double.infinity;
  for (var i = 0; i <= intervals; i++) {
    final center = areaCentroid + direction * (low + i * step);
    if (!path.contains(center)) continue;
    final clearance = math.sqrt(_boundaryDistanceSquared(outline, center));
    final anchorDistance = (center - hullCentroid).distanceSquared;
    if (clearance > bestClearance + 1e-8 ||
        ((clearance - bestClearance).abs() <= 1e-8 &&
            anchorDistance < bestDistance)) {
      bestClearance = clearance;
      bestCenter = center;
      bestDistance = anchorDistance;
    }
  }
  // Along an axis, clearance is 1-Lipschitz. The grid misses the optimum by
  // at most half a step on the sampled outline; cubic flattening adds error.
  return OpticalCenterResult(
    center: bestCenter,
    hullCentroid: hullCentroid,
    axisCount: 1,
    method: OpticalCenterMethod.maximumClearanceOnReflectionAxis,
  );
}

double _cross(Offset origin, Offset a, Offset b) =>
    (a.dx - origin.dx) * (b.dy - origin.dy) -
    (a.dy - origin.dy) * (b.dx - origin.dx);

Offset _convexHullCentroid(List<Offset> outline) {
  final points = [...outline]
    ..sort((a, b) {
      final x = a.dx.compareTo(b.dx);
      return x == 0 ? a.dy.compareTo(b.dy) : x;
    });
  final lower = <Offset>[];
  for (final point in points) {
    while (lower.length >= 2 &&
        _cross(lower[lower.length - 2], lower.last, point) <= 0) {
      lower.removeLast();
    }
    lower.add(point);
  }
  final upper = <Offset>[];
  for (final point in points.reversed) {
    while (upper.length >= 2 &&
        _cross(upper[upper.length - 2], upper.last, point) <= 0) {
      upper.removeLast();
    }
    upper.add(point);
  }
  final hull = [...lower..removeLast(), ...upper..removeLast()];
  var twiceArea = 0.0;
  var weightedX = 0.0;
  var weightedY = 0.0;
  for (var i = 0; i < hull.length; i++) {
    final a = hull[i];
    final b = hull[(i + 1) % hull.length];
    final cross = a.dx * b.dy - b.dx * a.dy;
    twiceArea += cross;
    weightedX += (a.dx + b.dx) * cross;
    weightedY += (a.dy + b.dy) * cross;
  }
  return Offset(weightedX / (3 * twiceArea), weightedY / (3 * twiceArea));
}

double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

List<Offset> _arcSamples(List<Offset> outline, int count) {
  final cumulative = <double>[0];
  for (var i = 0; i < outline.length; i++) {
    cumulative.add(
      cumulative.last +
          (outline[(i + 1) % outline.length] - outline[i]).distance,
    );
  }
  var segment = 0;
  return [
    for (var i = 0; i < count; i++)
      (() {
        final distance = i * cumulative.last / count;
        while (segment < outline.length - 1 &&
            cumulative[segment + 1] <= distance) {
          segment++;
        }
        final length = cumulative[segment + 1] - cumulative[segment];
        return Offset.lerp(
          outline[segment],
          outline[(segment + 1) % outline.length],
          length == 0 ? 0 : (distance - cumulative[segment]) / length,
        )!;
      })(),
  ];
}

Offset _cyclicSample(List<Offset> samples, double index) {
  final wrapped = index % samples.length;
  final start = wrapped.floor();
  return Offset.lerp(
    samples[start],
    samples[(start + 1) % samples.length],
    wrapped - start,
  )!;
}

({double angle, double error}) _reflectionFit(
  List<Offset> samples,
  double shift,
) {
  var real = 0.0;
  var imaginary = 0.0;
  var norm = 0.0;
  for (var i = 0; i < samples.length; i++) {
    final p = samples[i];
    final q = _cyclicSample(samples, shift - i);
    real += p.dx * q.dx - p.dy * q.dy;
    imaginary += p.dx * q.dy + p.dy * q.dx;
    norm += p.distanceSquared + q.distanceSquared;
  }
  return (
    angle: math.atan2(imaginary, real) / 2,
    error: math.sqrt(
      math.max(0, norm - 2 * math.sqrt(real * real + imaginary * imaginary)) /
          samples.length,
    ),
  );
}

double _maximumReflectionError(
  List<Offset> samples,
  double shift,
  double angle,
) {
  final c = math.cos(2 * angle);
  final s = math.sin(2 * angle);
  var error = 0.0;
  for (var i = 0; i < samples.length; i++) {
    final p = samples[i];
    final reflected = Offset(c * p.dx + s * p.dy, s * p.dx - c * p.dy);
    error = math.max(
      error,
      (reflected - _cyclicSample(samples, shift - i)).distance,
    );
  }
  return error;
}

double _boundaryDistanceSquared(List<Offset> outline, Offset point) {
  var best = double.infinity;
  for (var i = 0; i < outline.length; i++) {
    final a = outline[i];
    final b = outline[(i + 1) % outline.length];
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final px = point.dx - a.dx;
    final py = point.dy - a.dy;
    final lengthSquared = dx * dx + dy * dy;
    final t = lengthSquared == 0
        ? 0.0
        : ((px * dx + py * dy) / lengthSquared).clamp(0.0, 1.0);
    final x = px - t * dx;
    final y = py - t * dy;
    best = math.min(best, x * x + y * y);
  }
  return best;
}
