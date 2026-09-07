import 'dart:math' as math;
import 'dart:ui';

import 'package:androidx_graphics_shapes/androidx_graphics_shapes.dart';

/// Offline containment checks for one closed cubic outline in unit coordinates.
///
/// A filled center plus no boundary anywhere inside a connected rectangle proves
/// that rectangle is filled. We exclude the boundary using the convex-hull
/// property of Beziers: each curve is inside its control-point bounding box.
/// Subdivision tightens those boxes; unresolved boxes fail closed at maxDepth.
/// This handles concavities without flattening or checking only four corners.
/// Floating-point arithmetic is guarded, not an exact-arithmetic proof.
class SafeInteriorOutline {
  SafeInteriorOutline(Iterable<Cubic> cubics, {this.maxDepth = 24}) {
    if (maxDepth < 0 || maxDepth > 30) {
      throw ArgumentError.value(maxDepth, 'maxDepth', 'Must be in 0..30');
    }
    final curves = cubics.toList();
    if (curves.isEmpty) throw ArgumentError('Outline must not be empty');
    for (var i = 0; i < curves.length; i++) {
      final c = curves[i];
      if (!_coordinates(c).every((v) => v.isFinite)) {
        throw ArgumentError('Outline coordinates must be finite');
      }
      final next = curves[(i + 1) % curves.length];
      if ((c.anchor1X - next.anchor0X).abs() > numericGuard ||
          (c.anchor1Y - next.anchor0Y).abs() > numericGuard) {
        throw ArgumentError('Outline must be continuous and closed');
      }
    }
    _nodes = curves.map(_CurveNode.new).toList();
    _path = Path()..moveTo(curves.first.anchor0X, curves.first.anchor0Y);
    for (final c in curves) {
      _path.cubicTo(
        c.control0X,
        c.control0Y,
        c.control1X,
        c.control1Y,
        c.anchor1X,
        c.anchor1Y,
      );
    }
    _path.close();
    _bounds = _path.getBounds();
    _areaCentroid = _computeAreaCentroid(curves) ?? _bounds.center;
  }

  static const numericGuard = 1e-9;
  final int maxDepth;
  late final List<_CurveNode> _nodes;
  late final Path _path;
  late final Rect _bounds;
  late final Offset _areaCentroid;

  /// Exact filled-area centroid of the closed cubic chain, evaluated by
  /// integrating its polynomial segments. Falls back to the path-bounds center
  /// only for a degenerate zero-area outline.
  Offset get areaCentroid => _areaCentroid;

  /// Clearance is an L-infinity (rectangular) margin in source coordinates.
  /// It is separate from content padding and runtime border stroke width.
  bool contains(Rect rect, {double clearance = 0.01}) {
    if (!clearance.isFinite || clearance < 0) {
      throw ArgumentError.value(clearance, 'clearance');
    }
    if (!rect.isFinite || rect.isEmpty || !_path.contains(rect.center)) {
      return false;
    }
    final protected = rect.inflate(clearance + numericGuard);
    return _nodes.every((node) => node.excludes(protected, maxDepth));
  }

  /// Largest certified freely translated rectangle with
  /// width/height = [aspectRatio].
  ///
  /// This is a deterministic branch-and-bound search over the rectangle's
  /// center. At each center, monotonic bisection finds a certified lower bound
  /// and an unsafe upper bound on height. The objective is 2-Lipschitz in the
  /// aspect-weighted L-infinity metric, which gives every center cell a valid
  /// global upper bound. Search ends only when no cell can improve the returned
  /// height by more than [tolerance]. Equal-height candidates prefer the
  /// outline's filled-area centroid.
  ///
  /// [contains] remains the final certification boundary; floating-point and
  /// recursive cubic guards make this an epsilon-global numerical result, not
  /// an exact-arithmetic proof. Null means no useful certified region.
  Rect? find({
    required double aspectRatio,
    double clearance = 0.01,
    double tolerance = 1e-5,
  }) {
    if (!aspectRatio.isFinite || aspectRatio <= 0) {
      throw ArgumentError.value(aspectRatio, 'aspectRatio');
    }
    if (!clearance.isFinite || clearance < 0) {
      throw ArgumentError.value(clearance, 'clearance');
    }
    if (!tolerance.isFinite || tolerance <= 0) {
      throw ArgumentError.value(tolerance, 'tolerance');
    }

    final domain = _bounds.deflate(clearance + numericGuard);
    if (domain.isEmpty) return null;

    final tieTolerance = tolerance * 0.01;
    final branchTolerance = tolerance - tieTolerance;
    var maxLower = 0.0;
    _CenterFit? best;
    void consider(_CenterFit fit) {
      if (fit.rect == null) return;
      maxLower = math.max(maxLower, fit.lower);
      final current = best;
      if (current == null ||
          current.lower < maxLower - tieTolerance ||
          (fit.lower >= maxLower - tieTolerance &&
              (fit.center - areaCentroid).distanceSquared <
                  (current.center - areaCentroid).distanceSquared)) {
        best = fit;
      }
    }

    _CenterFit fitAt(Offset center) => _fitAtCenter(
      center,
      aspectRatio: aspectRatio,
      clearance: clearance,
      tolerance: tolerance,
    );

    _CenterFit locallyMaximize(Offset seed) {
      var current = fitAt(seed);
      var stepX = domain.width / 4;
      var stepY = domain.height / 4;
      while (math.max(stepX / aspectRatio, stepY) > tolerance * 0.25) {
        var next = current;
        for (final dx in [-stepX, 0.0, stepX]) {
          for (final dy in [-stepY, 0.0, stepY]) {
            if (dx == 0 && dy == 0) continue;
            final point = Offset(
              (current.center.dx + dx).clamp(domain.left, domain.right),
              (current.center.dy + dy).clamp(domain.top, domain.bottom),
            );
            final candidate = fitAt(point);
            if (candidate.lower > next.lower) next = candidate;
          }
        }
        if (next.lower > current.lower + tolerance * 0.01) {
          current = next;
        } else {
          stepX /= 2;
          stepY /= 2;
        }
      }
      return current;
    }

    final seeds = <Offset>{
      if (domain.contains(areaCentroid)) areaCentroid,
      for (final x in [0.25, 0.5, 0.75])
        for (final y in [0.25, 0.5, 0.75])
          Offset(
            domain.left + domain.width * x,
            domain.top + domain.height * y,
          ),
    };
    for (final seed in seeds) {
      consider(locallyMaximize(seed));
    }

    final queue = _MaxCellHeap();
    void enqueue(Rect cellBounds) {
      final fit = _fitAtCenter(
        cellBounds.center,
        aspectRatio: aspectRatio,
        clearance: clearance,
        tolerance: tolerance,
      );
      consider(fit);
      final centerRadius = math.max(
        cellBounds.width / (2 * aspectRatio),
        cellBounds.height / 2,
      );
      final upper = fit.upper + 2 * centerRadius;
      if (upper > maxLower + branchTolerance) {
        queue.add(_SearchCell(cellBounds, upper));
      }
    }

    enqueue(domain);
    var visited = 0;
    while (queue.isNotEmpty) {
      final cell = queue.removeFirst();
      if (cell.upper <= maxLower + branchTolerance) continue;
      if (++visited > 2000000) {
        throw StateError(
          'Safe-area branch-and-bound exceeded 2000000 cells; '
          'best=$maxLower, nextUpper=${cell.upper}, '
          'cell=${cell.bounds}; increase tolerance or inspect the outline',
        );
      }
      final bounds = cell.bounds;
      if (bounds.width / aspectRatio >= bounds.height) {
        final middle = bounds.center.dx;
        enqueue(Rect.fromLTRB(bounds.left, bounds.top, middle, bounds.bottom));
        enqueue(Rect.fromLTRB(middle, bounds.top, bounds.right, bounds.bottom));
      } else {
        final middle = bounds.center.dy;
        enqueue(Rect.fromLTRB(bounds.left, bounds.top, bounds.right, middle));
        enqueue(
          Rect.fromLTRB(bounds.left, middle, bounds.right, bounds.bottom),
        );
      }
    }

    final result = best?.rect;
    if (result == null || result.shortestSide < 1e-8) return null;
    return contains(result, clearance: clearance) ? result : null;
  }

  _CenterFit _fitAtCenter(
    Offset center, {
    required double aspectRatio,
    required double clearance,
    required double tolerance,
  }) {
    Rect rectangle(double height) => Rect.fromCenter(
      center: center,
      width: height * aspectRatio,
      height: height,
    );

    final horizontalRoom = math.min(
      center.dx - _bounds.left,
      _bounds.right - center.dx,
    );
    final verticalRoom = math.min(
      center.dy - _bounds.top,
      _bounds.bottom - center.dy,
    );
    var high =
        (2 *
                math.min(
                  verticalRoom - clearance - numericGuard,
                  (horizontalRoom - clearance - numericGuard) / aspectRatio,
                ))
            .toDouble();
    if (high <= 0 || !_path.contains(center)) {
      return _CenterFit(center, 0, 0, null);
    }

    var low = 0.0;
    Rect? safe;
    for (var i = 0; i < 60 && high - low > tolerance * 0.125; i++) {
      final middle = (low + high) / 2;
      final candidate = rectangle(middle);
      if (contains(candidate, clearance: clearance)) {
        low = middle;
        safe = candidate;
      } else {
        high = middle;
      }
    }
    return _CenterFit(center, low, high, safe);
  }
}

class _CenterFit {
  const _CenterFit(this.center, this.lower, this.upper, this.rect);

  final Offset center;
  final double lower;
  final double upper;
  final Rect? rect;
}

class _SearchCell {
  const _SearchCell(this.bounds, this.upper);

  final Rect bounds;
  final double upper;
}

class _MaxCellHeap {
  final List<_SearchCell> _items = [];

  bool get isNotEmpty => _items.isNotEmpty;

  void add(_SearchCell value) {
    _items.add(value);
    var child = _items.length - 1;
    while (child > 0) {
      final parent = (child - 1) ~/ 2;
      if (_items[parent].upper >= value.upper) break;
      _items[child] = _items[parent];
      child = parent;
    }
    _items[child] = value;
  }

  _SearchCell removeFirst() {
    final result = _items.first;
    final last = _items.removeLast();
    if (_items.isEmpty) return result;
    var parent = 0;
    while (true) {
      final left = parent * 2 + 1;
      if (left >= _items.length) break;
      final right = left + 1;
      final child =
          right < _items.length && _items[right].upper > _items[left].upper
          ? right
          : left;
      if (_items[child].upper <= last.upper) break;
      _items[parent] = _items[child];
      parent = child;
    }
    _items[parent] = last;
    return result;
  }
}

Offset? _computeAreaCentroid(List<Cubic> cubics) {
  var crossIntegral = 0.0;
  var xMoment = 0.0;
  var yMoment = 0.0;
  for (final cubic in cubics) {
    final x = _bezierCoefficients(
      cubic.anchor0X,
      cubic.control0X,
      cubic.control1X,
      cubic.anchor1X,
    );
    final y = _bezierCoefficients(
      cubic.anchor0Y,
      cubic.control0Y,
      cubic.control1Y,
      cubic.anchor1Y,
    );
    final dx = _derivative(x);
    final dy = _derivative(y);
    crossIntegral += _integral(_subtract(_multiply(x, dy), _multiply(y, dx)));
    xMoment += _integral(_multiply(_multiply(x, x), dy));
    yMoment -= _integral(_multiply(_multiply(y, y), dx));
  }
  if (!crossIntegral.isFinite || crossIntegral.abs() < 1e-14) return null;
  final result = Offset(xMoment / crossIntegral, yMoment / crossIntegral);
  return result.dx.isFinite && result.dy.isFinite ? result : null;
}

List<double> _bezierCoefficients(double p0, double p1, double p2, double p3) =>
    [p0, 3 * (p1 - p0), 3 * (p0 - 2 * p1 + p2), p3 - p0 + 3 * (p1 - p2)];

List<double> _derivative(List<double> polynomial) => [
  for (var i = 1; i < polynomial.length; i++) polynomial[i] * i,
];

List<double> _multiply(List<double> a, List<double> b) {
  final result = List<double>.filled(a.length + b.length - 1, 0);
  for (var i = 0; i < a.length; i++) {
    for (var j = 0; j < b.length; j++) {
      result[i + j] += a[i] * b[j];
    }
  }
  return result;
}

List<double> _subtract(List<double> a, List<double> b) => [
  for (var i = 0; i < math.max(a.length, b.length); i++)
    (i < a.length ? a[i] : 0) - (i < b.length ? b[i] : 0),
];

double _integral(List<double> polynomial) {
  var result = 0.0;
  for (var i = 0; i < polynomial.length; i++) {
    result += polynomial[i] / (i + 1);
  }
  return result;
}

List<double> _coordinates(Cubic c) => [
  c.anchor0X,
  c.anchor0Y,
  c.control0X,
  c.control0Y,
  c.control1X,
  c.control1Y,
  c.anchor1X,
  c.anchor1Y,
];

class _CurveNode {
  _CurveNode(this.cubic) {
    final xs = [
      cubic.anchor0X,
      cubic.control0X,
      cubic.control1X,
      cubic.anchor1X,
    ];
    final ys = [
      cubic.anchor0Y,
      cubic.control0Y,
      cubic.control1Y,
      cubic.anchor1Y,
    ];
    bounds = Rect.fromLTRB(
      xs.reduce(math.min),
      ys.reduce(math.min),
      xs.reduce(math.max),
      ys.reduce(math.max),
    );
  }

  final Cubic cubic;
  late final Rect bounds;
  (_CurveNode, _CurveNode)? _children;

  bool excludes(Rect rect, int remaining) {
    // Strict separation: touching is rejected. Rect.overlaps is unsuitable for
    // degenerate bounds (straight lines and point-like cubic segments).
    if (bounds.right < rect.left ||
        bounds.left > rect.right ||
        bounds.bottom < rect.top ||
        bounds.top > rect.bottom) {
      return true;
    }
    if (remaining == 0 ||
        (bounds.left >= rect.left &&
            bounds.right <= rect.right &&
            bounds.top >= rect.top &&
            bounds.bottom <= rect.bottom)) {
      return false;
    }
    final children = _children ??= (() {
      final (left, right) = cubic.split(0.5);
      return (_CurveNode(left), _CurveNode(right));
    })();
    return children.$1.excludes(rect, remaining - 1) &&
        children.$2.excludes(rect, remaining - 1);
  }
}
