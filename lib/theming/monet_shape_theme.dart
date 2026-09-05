import 'package:flutter/material.dart';
import 'package:libmonet/util/size_scale.dart';

/// Creates an outlined border from resolved logical-pixel geometry.
typedef MonetBorderBuilder =
    OutlinedBorder Function({
      required BorderRadiusGeometry borderRadius,
      required BorderSide side,
    });

/// Creates an input border from resolved logical-pixel geometry.
typedef MonetInputBorderBuilder =
    InputBorder Function({
      required BorderRadius borderRadius,
      required BorderSide borderSide,
      required double gapPadding,
    });

OutlinedBorder _roundedBorderBuilder({
  required BorderRadiusGeometry borderRadius,
  required BorderSide side,
}) => RoundedRectangleBorder(borderRadius: borderRadius, side: side);

InputBorder _roundedInputBorderBuilder({
  required BorderRadius borderRadius,
  required BorderSide borderSide,
  required double gapPadding,
}) => OutlineInputBorder(
  borderRadius: borderRadius,
  borderSide: borderSide,
  gapPadding: gapPadding,
);

/// Shape policy stored in Monet theme data.
///
/// Radius and gap values are design-space lengths. [resolve] applies Monet's
/// linear size scale before a border builder receives them.
@immutable
class MonetShapeTheme {
  const MonetShapeTheme({
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.inputGapPadding = 4,
    this.borderBuilder = _roundedBorderBuilder,
    this.inputBorderBuilder = _roundedInputBorderBuilder,
  });

  final BorderRadiusGeometry borderRadius;
  final double inputGapPadding;
  final MonetBorderBuilder borderBuilder;
  final MonetInputBorderBuilder inputBorderBuilder;

  MonetShapes resolve(double scale) {
    assert(scale >= 0, 'Monet scale must not be negative.');
    return MonetShapes(theme: this, linearScale: scale.sizeScale);
  }

  MonetShapeTheme copyWith({
    BorderRadiusGeometry? borderRadius,
    double? inputGapPadding,
    MonetBorderBuilder? borderBuilder,
    MonetInputBorderBuilder? inputBorderBuilder,
  }) => MonetShapeTheme(
    borderRadius: borderRadius ?? this.borderRadius,
    inputGapPadding: inputGapPadding ?? this.inputGapPadding,
    borderBuilder: borderBuilder ?? this.borderBuilder,
    inputBorderBuilder: inputBorderBuilder ?? this.inputBorderBuilder,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonetShapeTheme &&
          borderRadius == other.borderRadius &&
          inputGapPadding == other.inputGapPadding &&
          borderBuilder == other.borderBuilder &&
          inputBorderBuilder == other.inputBorderBuilder;

  @override
  int get hashCode => Object.hash(
    borderRadius,
    inputGapPadding,
    borderBuilder,
    inputBorderBuilder,
  );
}

/// Border factory with a Monet scale already resolved.
@immutable
class MonetShapes {
  const MonetShapes({required this.theme, required this.linearScale});

  final MonetShapeTheme theme;
  final double linearScale;

  /// Creates an outlined border.
  ///
  /// [borderRadius] is a design-space value. [side] is already in logical
  /// pixels and is not scaled.
  OutlinedBorder border({
    BorderRadiusGeometry? borderRadius,
    BorderSide side = BorderSide.none,
  }) => theme.borderBuilder(
    borderRadius: (borderRadius ?? theme.borderRadius) * linearScale,
    side: side,
  );

  /// Creates an input border.
  ///
  /// Radius and gap values are design-space lengths. [borderSide] is already
  /// in logical pixels and is not scaled.
  InputBorder inputBorder({
    BorderRadiusGeometry? borderRadius,
    BorderSide borderSide = BorderSide.none,
    double? gapPadding,
    required TextDirection textDirection,
  }) => theme.inputBorderBuilder(
    borderRadius: ((borderRadius ?? theme.borderRadius) * linearScale).resolve(
      textDirection,
    ),
    borderSide: borderSide,
    gapPadding: (gapPadding ?? theme.inputGapPadding) * linearScale,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonetShapes &&
          theme == other.theme &&
          linearScale == other.linearScale;

  @override
  int get hashCode => Object.hash(theme, linearScale);
}
