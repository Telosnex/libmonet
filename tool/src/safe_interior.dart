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
  }

  static const numericGuard = 1e-9;
  final int maxDepth;
  late final List<_CurveNode> _nodes;
  late final Path _path;

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

  /// Largest certified centered rectangle (to binary-search precision) with
  /// width/height = aspectRatio, constrained to the unit square. Not a global
  /// optimum over possible centers. Null means no useful centered region.
  Rect? find({
    required double aspectRatio,
    double clearance = 0.01,
    Offset center = const Offset(0.5, 0.5),
  }) {
    if (!center.dx.isFinite ||
        !center.dy.isFinite ||
        center.dx <= 0 ||
        center.dx >= 1 ||
        center.dy <= 0 ||
        center.dy >= 1) {
      throw ArgumentError.value(
        center,
        'center',
        'Must be inside the unit square',
      );
    }
    if (!aspectRatio.isFinite || aspectRatio <= 0) {
      throw ArgumentError.value(aspectRatio, 'aspectRatio');
    }
    if (!clearance.isFinite || clearance < 0) {
      throw ArgumentError.value(clearance, 'clearance');
    }
    Rect rectangle(double height) => Rect.fromCenter(
      center: center,
      width: height * aspectRatio,
      height: height,
    );
    var low = 0.0;
    var high = math.min(
      2 * math.min(center.dy, 1 - center.dy),
      2 * math.min(center.dx, 1 - center.dx) / aspectRatio,
    );
    for (var i = 0; i < 44; i++) {
      final middle = (low + high) / 2;
      if (contains(rectangle(middle), clearance: clearance)) {
        low = middle;
      } else {
        high = middle;
      }
    }
    final result = rectangle(low);
    if (result.shortestSide < 1e-8) return null;
    return contains(result, clearance: clearance) ? result : null;
  }
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
