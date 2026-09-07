import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'expressive_shape_geometry.dart';

export 'expressive_shape_geometry.dart';

/// Explicit policy when parent constraints prevent full-size content fitting.
enum ExpressiveContentOverflow {
  /// Preserve containment by shrinking content; this can reduce text legibility.
  scaleDown,

  /// Fail with a layout error so the application can fix its size/shape choice.
  error,
}

/// Content-aware sizing for a surface painted with [geometry]'s border.
///
/// Place this *inside* the surface, with no additional external content padding
/// or alignment sizing: this widget's bounds must equal the painted surface's
/// bounds. It adds [padding] inside a precomputed safe rectangle, wraps text at
/// the available width, and chooses the candidate needing the smallest surface.
/// No per-aspect-ratio computation is required in consumer code.
///
/// For stock Flutter buttons use ExpressiveButton, which sets the necessary
/// zero button padding and standard visual density. For a custom button, replace
/// its Padding/Align with this widget and use geometry.border() for its surface.
/// [clearance] is extra logical-pixel space for strokes/AA, beyond table clearance.
/// Reserve the maximum inward stroke extent (including miter joins) across states.
///
/// Children must support intrinsic measurement and dry layout (Text, Icon, Row, Column; not
/// LayoutBuilder). Painting outside a child's layout bounds, including text
/// shadows, is not covered. [overflow] explicitly handles restrictive parents;
/// scaleDown shrinks content and its padding together, never scaling up. Morph ticks need not rebuild this widget.
class ExpressiveShapeContent extends SingleChildRenderObjectWidget {
  const ExpressiveShapeContent({
    super.key,
    required this.geometry,
    this.stretch = false,
    this.padding = const EdgeInsets.all(8),
    this.clearance = 1,
    this.overflow = ExpressiveContentOverflow.scaleDown,
    required super.child,
  }) : assert(clearance >= 0 && clearance < double.infinity);

  final ExpressiveShapeGeometry geometry;
  final bool stretch;
  final EdgeInsetsGeometry padding;
  final double clearance;
  final ExpressiveContentOverflow overflow;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderExpressiveContent(
        geometry,
        stretch,
        padding.resolve(Directionality.of(context)),
        clearance,
        overflow,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _RenderExpressiveContent).configure(
      geometry,
      stretch,
      padding.resolve(Directionality.of(context)),
      clearance,
      overflow,
    );
  }
}

class _Plan {
  const _Plan(
    this.size,
    this.childConstraints,
    this.rect,
    this.scale,
    this.offset,
  );
  final Size size;
  final BoxConstraints childConstraints;
  final Rect rect;
  final double scale;
  final Offset offset;
}

class _RenderExpressiveContent extends RenderShiftedBox {
  _RenderExpressiveContent(
    this.geometry,
    this.stretch,
    this.padding,
    this.clearance,
    this.overflow,
  ) : super(null);

  ExpressiveShapeGeometry geometry;
  bool stretch;
  EdgeInsets padding;
  double clearance;
  ExpressiveContentOverflow overflow;
  double _scale = 1;

  void configure(
    ExpressiveShapeGeometry g,
    bool s,
    EdgeInsets p,
    double c,
    ExpressiveContentOverflow o,
  ) {
    if (identical(g, geometry) &&
        s == stretch &&
        p == padding &&
        c == clearance &&
        o == overflow) {
      return;
    }
    geometry = g;
    stretch = s;
    padding = p;
    clearance = c;
    overflow = o;
    markNeedsLayout();
  }

  Rect _mapped(Rect rect, Size size) {
    final sx = stretch ? size.width : size.shortestSide;
    final sy = stretch ? size.height : size.shortestSide;
    return Rect.fromLTWH(
      (size.width - sx) / 2 + rect.left * sx,
      (size.height - sy) / 2 + rect.top * sy,
      rect.width * sx,
      rect.height * sy,
    );
  }

  _Plan _fit(
    BoxConstraints constraints,
    Rect rect,
    BoxConstraints childConstraints,
    Size childSize,
  ) {
    final padded = Size(
      childSize.width + padding.horizontal + clearance * 2,
      childSize.height + padding.vertical + clearance * 2,
    );
    var width = padded.width / rect.width;
    var height = padded.height / rect.height;
    if (!stretch) {
      // The border uses size.shortestSide. Clamp the shared scale before
      // constraining each axis, or a width-limited, height-unbounded parent
      // would reserve height that cannot enlarge the painted silhouette.
      // Apply minimum constraints afterwards: mandatory nonsquare bounds
      // still take precedence, and scaleDown/error handles content overflow.
      width = height = math.min(
        math.max(width, height),
        math.min(constraints.maxWidth, constraints.maxHeight),
      );
    }
    final size = constraints.constrain(Size(width, height));
    final mapped = _mapped(rect, size).deflate(clearance);
    final contentWidth = childSize.width + padding.horizontal;
    final contentHeight = childSize.height + padding.vertical;
    final scale = math.max(
      0.0,
      math.min(
        1.0,
        math.min(
          contentWidth == 0 ? 1.0 : mapped.width / contentWidth,
          contentHeight == 0 ? 1.0 : mapped.height / contentHeight,
        ),
      ),
    );
    return _Plan(
      size,
      childConstraints,
      rect,
      scale,
      mapped.center -
          Offset(contentWidth, contentHeight) * (scale / 2) +
          Offset(padding.left, padding.top) * scale,
    );
  }

  _Plan _plan(BoxConstraints constraints) {
    if (!padding.isNonNegative ||
        !padding.horizontal.isFinite ||
        !padding.vertical.isFinite ||
        !clearance.isFinite ||
        clearance < 0) {
      throw FlutterError(
        'ExpressiveShapeContent requires finite nonnegative padding and clearance.',
      );
    }
    _Plan? best;
    final measurements = <double, Size>{};
    // Never force an unbreakable item (an icon or a long word) narrower than
    // its minimum intrinsic width, which could make it paint outside its box.
    final minimumChildWidth = child?.getMinIntrinsicWidth(double.infinity) ?? 0;
    if (!minimumChildWidth.isFinite) {
      throw FlutterError(
        'ExpressiveShapeContent requires finite intrinsic content width.',
      );
    }
    for (final rect in geometry.safeRects) {
      final maxScaleX = stretch
          ? constraints.maxWidth
          : math.min(constraints.maxWidth, constraints.maxHeight);
      final maxWidth = math.max(
        minimumChildWidth,
        maxScaleX * rect.width - padding.horizontal - clearance * 2,
      );
      // An unbounded height lets Text wrap without silently truncating before
      // the overflow policy gets a chance to inspect its full measured height.
      final childConstraints = BoxConstraints(maxWidth: maxWidth);
      final childSize = measurements.putIfAbsent(
        maxWidth,
        () => child?.getDryLayout(childConstraints) ?? Size.zero,
      );
      final candidate = _fit(constraints, rect, childConstraints, childSize);
      // Prefer legibility first; among equally fitting entries minimize area.
      if (best == null ||
          candidate.scale > best.scale + 1e-9 ||
          ((candidate.scale - best.scale).abs() < 1e-9 &&
              candidate.size.width * candidate.size.height <
                  best.size.width * best.size.height)) {
        best = candidate;
      }
    }
    if (best == null) {
      throw FlutterError('No endpoint-safe rectangle for this shape.');
    }
    return best;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _plan(constraints).size;

  // This content-driven render object has one preferred width; height is then
  // derived from the available width. Returning that preferred dimension for
  // both width queries (rather than RenderShiftedBox's default zero) makes the
  // lower-level widget usable under IntrinsicWidth/Height. _plan remains the
  // source of truth for wrapping, safe-rect choice, stretch and insets.
  double _intrinsicWidth() => _plan(const BoxConstraints()).size.width;

  double _intrinsicHeight(double width) =>
      _plan(BoxConstraints.tightForFinite(width: width)).size.height;

  @override
  double computeMinIntrinsicWidth(double height) => _intrinsicWidth();

  @override
  double computeMaxIntrinsicWidth(double height) => _intrinsicWidth();

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight(width);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    if (child == null) return null;
    final childBaseline = child!.getDistanceToActualBaseline(baseline);
    if (childBaseline == null) return null;
    final offset = (child!.parentData! as BoxParentData).offset;
    return offset.dy + childBaseline * _scale;
  }

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    if (child == null) return null;
    final plan = _plan(constraints);
    final childBaseline = child!.getDryBaseline(
      plan.childConstraints,
      baseline,
    );
    if (childBaseline == null) return null;
    final fitted = _fit(
      constraints,
      plan.rect,
      plan.childConstraints,
      child!.getDryLayout(plan.childConstraints),
    );
    return fitted.offset.dy + childBaseline * fitted.scale;
  }

  @override
  void performLayout() {
    final plan = _plan(constraints);
    child?.layout(plan.childConstraints, parentUsesSize: true);
    final fitted = _fit(
      constraints,
      plan.rect,
      plan.childConstraints,
      child?.size ?? Size.zero,
    );

    size = fitted.size;
    _scale = fitted.scale;
    if (child != null) {
      (child!.parentData! as BoxParentData).offset = fitted.offset;
    }
    if (fitted.scale < 1 - 1e-7 &&
        overflow == ExpressiveContentOverflow.error) {
      throw FlutterError(
        'ExpressiveShapeContent cannot fit its content at full size in $constraints. '
        'Allow a larger surface, enable stretch, simplify the content, or explicitly use scaleDown.',
      );
    }
  }

  Matrix4 get _transform {
    final offset = (child!.parentData! as BoxParentData).offset;
    return Matrix4.identity()
      ..translateByDouble(offset.dx, offset.dy, 0, 1)
      ..scaleByDouble(_scale, _scale, 1, 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || _scale == 0) return;
    context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      (context, offset) => context.paintChild(child!, offset),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (child == null || _scale == 0) return false;
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (result, position) => child!.hitTest(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) =>
      transform.multiply(_transform);
}
