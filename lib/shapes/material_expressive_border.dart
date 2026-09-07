import 'dart:typed_data';

import 'package:androidx_graphics_shapes/material_shapes.dart';
import 'package:flutter/material.dart';

import 'material_expressive_shape.dart';

export 'material_expressive_shape.dart';

final _unitPaths = <MaterialExpressiveShape, Path>{};

/// An AndroidX-derived Material 3 Expressive silhouette usable with Material,
/// ShapeDecoration, InkWell.customBorder, and MonetClip.shape.
///
/// These are dimensionless motifs, not configurable rounded rectangles: their
/// rounding scales with the available size, not Monet's corner-radius token.
/// By default the normalized unit square is centered and uniformly scaled to
/// the shortest side of the bounds. [stretch] instead scales each axis to fill
/// the bounds (the same mapping as Compose's RoundedPolygon.toShape).
///
/// Like Flutter's StarBorder, stroke placement and the inner path use adjusted
/// bounding rectangles; this is not a geometric offset of concave curves.
/// Supply explicit content padding for lobes/notches. [dimensions] only accounts
/// for the stroke. Shape changes during interpolation switch at the midpoint;
/// this adapter does not implement AndroidX Morph.
class MaterialExpressiveBorder extends OutlinedBorder {
  const MaterialExpressiveBorder({
    required this.shape,
    this.stretch = false,
    super.side,
  });

  final MaterialExpressiveShape shape;
  final bool stretch;

  @override
  EdgeInsetsGeometry get dimensions =>
      EdgeInsets.all(side.style == BorderStyle.none ? 0 : side.strokeInset);

  @override
  MaterialExpressiveBorder copyWith({
    BorderSide? side,
    MaterialExpressiveShape? shape,
    bool? stretch,
  }) => MaterialExpressiveBorder(
    shape: shape ?? this.shape,
    stretch: stretch ?? this.stretch,
    side: side ?? this.side,
  );

  @override
  MaterialExpressiveBorder scale(double t) => copyWith(side: side.scale(t));

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is MaterialExpressiveBorder) {
      return MaterialExpressiveBorder(
        shape: t < 0.5 ? a.shape : shape,
        stretch: t < 0.5 ? a.stretch : stretch,
        side: BorderSide.lerp(a.side, side, t),
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is MaterialExpressiveBorder) return b.lerpFrom(this, t);
    return super.lerpTo(b, t);
  }

  Path _path(Rect rect) {
    if (!rect.isFinite || rect.isEmpty) return Path();
    final path = _unitPaths.putIfAbsent(shape, () => shape.polygon.toPath());
    final width = stretch ? rect.width : rect.shortestSide;
    final height = stretch ? rect.height : rect.shortestSide;
    final center = path.getBounds().center;
    // transform returns a new Path: callers cannot mutate the shared unit path.
    return path.transform(
      Float64List.fromList([
        width,
        0,
        0,
        0,
        0,
        height,
        0,
        0,
        0,
        0,
        1,
        0,
        rect.center.dx - center.dx * width,
        rect.center.dy - center.dy * height,
        0,
        1,
      ]),
    );
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _path(
    side.style == BorderStyle.none ? rect : rect.deflate(side.strokeInset),
  );

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || !rect.isFinite || rect.isEmpty) {
      return;
    }
    canvas.drawPath(_path(rect.inflate(side.strokeOffset / 2)), side.toPaint());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaterialExpressiveBorder &&
          other.shape == shape &&
          other.stretch == stretch &&
          other.side == side;

  @override
  int get hashCode => Object.hash(shape, stretch, side);
}
