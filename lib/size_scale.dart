import 'dart:math' as math;

extension SizeScale on double {
  /// Returns an adjusted scale value for width and height.
  ///
  /// This method adjusts a scale between 0.00 and 1.00 to be perceptually more
  /// accurate when it comes to scaling two-dimensional areas like rectangles.
  /// When you scale both width and height by a certain factor, the resulting
  /// area is scaled by the square of this factor. To give the intuitive effect
  /// of "half as big" when scaling, this method computes the square root of the
  /// input scale.
  double get sizeScale {
    return math.sqrt(this);
  }
}