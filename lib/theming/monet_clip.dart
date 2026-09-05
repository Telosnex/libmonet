import 'package:flutter/material.dart';
import 'package:libmonet/theming/monet_theme.dart';

/// Clips [child] to a shape from the nearest Monet theme.
///
/// The clip path comes from the same [ShapeBorder] used for surfaces and ink.
class MonetClip extends StatelessWidget {
  const MonetClip({
    super.key,
    this.shape,
    this.borderRadius,
    this.clipBehavior = Clip.antiAlias,
    required this.child,
  }) : assert(shape == null || borderRadius == null);

  final ShapeBorder? shape;
  final BorderRadiusGeometry? borderRadius;
  final Clip clipBehavior;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final effectiveShape =
        shape ??
        MonetTheme.shapesOf(context).border(borderRadius: borderRadius);
    return ClipPath(
      clipper: ShapeBorderClipper(
        shape: effectiveShape,
        textDirection: Directionality.maybeOf(context),
      ),
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}
