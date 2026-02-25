/// Matrix utilities for computing gamut-specific HCT solver constants.
///
/// These are used to derive the composite matrices that the HCT solver needs
/// for any RGB color space, by combining the RGB→XYZ matrix with the CAM16
/// chromatic adaptation matrices.
library;

import 'dart:math';

/// Multiplies two 3x3 matrices represented as [List<List<double>>].
List<List<double>> multiply3x3(List<List<double>> a, List<List<double>> b) {
  final result = List.generate(3, (_) => List.filled(3, 0.0));
  for (var i = 0; i < 3; i++) {
    for (var j = 0; j < 3; j++) {
      result[i][j] = a[i][0] * b[0][j] + a[i][1] * b[1][j] + a[i][2] * b[2][j];
    }
  }
  return result;
}

/// Inverts a 3x3 matrix.
List<List<double>> invert3x3(List<List<double>> m) {
  final a = m[0][0], b = m[0][1], c = m[0][2];
  final d = m[1][0], e = m[1][1], f = m[1][2];
  final g = m[2][0], h = m[2][1], i = m[2][2];

  final det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
  if (det.abs() < 1e-20) {
    throw ArgumentError('Matrix is singular, cannot invert');
  }
  final invDet = 1.0 / det;

  return [
    [
      (e * i - f * h) * invDet,
      (c * h - b * i) * invDet,
      (b * f - c * e) * invDet
    ],
    [
      (f * g - d * i) * invDet,
      (a * i - c * g) * invDet,
      (c * d - a * f) * invDet
    ],
    [
      (d * h - e * g) * invDet,
      (b * g - a * h) * invDet,
      (a * e - b * d) * invDet
    ],
  ];
}

/// The CAM16 M16 matrix (Hunt-Pointer-Estevez adapted for CAM16).
const cat16 = [
  [0.401288, 0.650173, -0.051461],
  [-0.250268, 1.204414, 0.045854],
  [-0.002079, 0.048952, 0.953127],
];

/// Computes the "scaled discount from linear RGB" matrix used by the HCT solver.
///
/// This is: diag(rgbD) * CAT16 * rgbToXyz, then scaled by 1/100 and by
/// the viewing-conditions fl factor embedded in the chromatic adaptation.
///
/// For standard sRGB viewing conditions (D65, 200/pi * midgrayY/100 adapting
/// luminance), the discount factors rgbD and fl are fixed. This function
/// computes the composite for those standard conditions.
///
/// [rgbToXyz] is the 3x3 linear-RGB-to-XYZ matrix for the color space.
List<List<double>> computeScaledDiscountFromLinrgb(
    List<List<double>> rgbToXyz) {
  // Standard sRGB viewing conditions values (from Cam16ViewingConditions.sRgb)
  // We need rgbD and fl. These depend on the white point and adapting luminance.
  // For D65 white point, they are:
  //
  // The white point in XYZ: [95.047, 100.0, 108.883]
  // Adapting luminance: 11.72 (200/pi * 18.4186/100)
  //
  // The CAT16 transform of the white point gives rW, gW, bW:
  const whitePoint = [95.047, 100.0, 108.883];
  final rW = cat16[0][0] * whitePoint[0] +
      cat16[0][1] * whitePoint[1] +
      cat16[0][2] * whitePoint[2];
  final gW = cat16[1][0] * whitePoint[0] +
      cat16[1][1] * whitePoint[1] +
      cat16[1][2] * whitePoint[2];
  final bW = cat16[2][0] * whitePoint[0] +
      cat16[2][1] * whitePoint[1] +
      cat16[2][2] * whitePoint[2];

  // Degree of adaptation (same calculation as Cam16ViewingConditions.make)
  const midgrayY = 18.418651851244416;
  final adaptingLuminance = 200.0 / pi * midgrayY / 100.0;
  final f = 0.8 + (2.0 / 10.0); // surround = 2.0
  var d = f * (1.0 - ((1.0 / 3.6) * exp((-adaptingLuminance - 42.0) / 92.0)));
  d = d.clamp(0.0, 1.0);

  final rgbD = [
    d * (100.0 / rW) + 1.0 - d,
    d * (100.0 / gW) + 1.0 - d,
    d * (100.0 / bW) + 1.0 - d,
  ];

  // fl (luminance-level adaptation factor)
  final k = 1.0 / (5.0 * adaptingLuminance + 1.0);
  final k4 = k * k * k * k;
  final k4F = 1.0 - k4;
  final fl = (k4 * adaptingLuminance) +
      (0.1 * k4F * k4F * pow(5.0 * adaptingLuminance, 1.0 / 3.0));

  // The composite matrix is:
  // scaledDiscount = diag(rgbD) * CAT16 * rgbToXyz
  // Then each element is multiplied by fl/100
  //
  // But wait - the HCT solver's _chromaticAdaptation expects the input to be
  // (fl * rgbD[i] * component / 100)^0.42, which means the matrix encodes
  // fl * rgbD[i] / 100 into each row.

  // First: CAT16 * rgbToXyz
  final cat16TimesRgb = multiply3x3(
    cat16.map((r) => r.toList()).toList(),
    rgbToXyz,
  );

  // Then apply diag(rgbD) and scale by fl/100
  final result = List.generate(3, (i) {
    final scale = fl * rgbD[i] / 100.0;
    return List.generate(3, (j) => cat16TimesRgb[i][j] * scale);
  });

  return result;
}

/// Computes the inverse: "linear RGB from scaled discount".
///
/// [rgbToXyz] is the 3x3 linear-RGB-to-XYZ matrix for the color space.
List<List<double>> computeLinrgbFromScaledDiscount(
    List<List<double>> rgbToXyz) {
  final forward = computeScaledDiscountFromLinrgb(rgbToXyz);
  return invert3x3(forward);
}
