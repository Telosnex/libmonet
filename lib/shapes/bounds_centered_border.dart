import 'package:androidx_graphics_shapes/material_shapes.dart';
import 'package:flutter/painting.dart';

/// Applies Compose's path-bounds centering after the fork's unit-space scaling.
/// Does not resize to fill the path bounds or apply an optical/centroid offset.
/// Keeps the same transform for fill, stroke, clip, ink and inner paths.
class BoundsCenteredBorder extends OutlinedBorder {
  BoundsCenteredBorder(this.source, {this.alignmentCorrection = Offset.zero})
    : super(side: source.side);

  final StaticPathBorder source;

  /// Unit-coordinate offset used to preserve position when a morph is
  /// rematched. Normally zero; this is not an optical-centering adjustment.
  final Offset alignmentCorrection;

  Rect _shifted(Rect rect) {
    final bounds = source.getOuterPath(rect).getBounds();
    final sx =
        rect.shortestSide + (rect.width - rect.shortestSide) * source.squash;
    final sy =
        rect.shortestSide + (rect.height - rect.shortestSide) * source.squash;
    return rect.shift(
      rect.center -
          bounds.center +
          Offset(alignmentCorrection.dx * sx, alignmentCorrection.dy * sy),
    );
  }

  @override
  EdgeInsetsGeometry get dimensions => source.dimensions;

  @override
  BoundsCenteredBorder copyWith({BorderSide? side}) => BoundsCenteredBorder(
    source.copyWith(side: side),
    alignmentCorrection: alignmentCorrection,
  );

  @override
  BoundsCenteredBorder scale(double t) => BoundsCenteredBorder(
    source.scale(t),
    alignmentCorrection: alignmentCorrection,
  );

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      !rect.isFinite || rect.isEmpty
      ? Path()
      : source.getOuterPath(_shifted(rect), textDirection: textDirection);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      !rect.isFinite || rect.isEmpty
      ? Path()
      : source.getInnerPath(_shifted(rect), textDirection: textDirection);

  @override
  bool get preferPaintInterior => source.preferPaintInterior;

  @override
  void paintInterior(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    TextDirection? textDirection,
  }) {
    if (!rect.isFinite || rect.isEmpty) return;
    source.paintInterior(
      canvas,
      _shifted(rect),
      paint,
      textDirection: textDirection,
    );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (!rect.isFinite || rect.isEmpty) return;
    source.paint(canvas, _shifted(rect), textDirection: textDirection);
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is BoundsCenteredBorder) {
      final lerped = ShapeBorder.lerp(a.source, source, t);
      if (lerped is StaticPathBorder) {
        return BoundsCenteredBorder(
          lerped,
          alignmentCorrection: Offset.lerp(
            a.alignmentCorrection,
            alignmentCorrection,
            t,
          )!,
        );
      }
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) =>
      b is BoundsCenteredBorder ? b.lerpFrom(this, t) : super.lerpTo(b, t);

  @override
  bool operator ==(Object other) =>
      other is BoundsCenteredBorder &&
      other.source == source &&
      other.alignmentCorrection == alignmentCorrection;

  @override
  int get hashCode =>
      Object.hash(BoundsCenteredBorder, source, alignmentCorrection);
}
