// Modified and maintained by open-source contributors, on behalf of libmonet.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0

import 'dart:math';

import 'package:libmonet/colorspaces/matrix_utils.dart';

/// Defines the gamut-specific constants that the HCT solver needs.
///
/// A gamut is defined by:
/// - Its RGB-to-XYZ matrix (determined by the RGB primaries and white point)
/// - Its transfer function (EOTF/OETF, i.e. "gamma")
///
/// The solver uses precomputed composite matrices that bake together the
/// RGB-to-XYZ conversion with CAM16's chromatic adaptation, plus a lookup
/// table of "critical planes" derived from the transfer function.
///
/// Three standard gamuts are provided: [srgb], [displayP3], and [rec2020].
class Gamut {
  /// Human-readable name for debugging.
  final String name;

  /// The Y (luminance) row of the linear-RGB-to-XYZ matrix.
  /// For sRGB: [0.2126, 0.7152, 0.0722] (Rec. 709 primaries).
  final List<double> yFromLinrgb;

  /// Composite matrix: linear RGB → CAM16 scaled discount.
  /// Equals fl/100 * diag(rgbD) * CAT16 * rgbToXyz.
  final List<List<double>> scaledDiscountFromLinrgb;

  /// Inverse of [scaledDiscountFromLinrgb]: CAM16 scaled discount → linear RGB.
  final List<List<double>> linrgbFromScaledDiscount;

  /// The full 3x3 linear-RGB-to-XYZ matrix.
  final List<List<double>> rgbToXyz;

  /// The full 3x3 XYZ-to-linear-RGB matrix.
  final List<List<double>> xyzToRgb;

  /// Delinearizes a linear RGB component [0..100] to display-encoded [0..255].
  /// This is the transfer function (OETF) scaled to the [0..255] range.
  final double Function(double) trueDelinearize;

  /// Linearizes a display-encoded RGB component [0..255] to linear [0..100].
  /// This is the inverse transfer function (EOTF) scaled from [0..255] range.
  final double Function(double) linearize;

  /// Precomputed critical planes for the transfer function.
  ///
  /// 255 entries at half-integer display boundaries (0.5, 1.5, ..., 254.5).
  /// Used to accelerate the bisection search in the HCT solver.
  final List<double> criticalPlanes;

  const Gamut({
    required this.name,
    required this.yFromLinrgb,
    required this.scaledDiscountFromLinrgb,
    required this.linrgbFromScaledDiscount,
    required this.rgbToXyz,
    required this.xyzToRgb,
    required this.trueDelinearize,
    required this.linearize,
    required this.criticalPlanes,
  });

  /// Creates a Gamut from an RGB-to-XYZ matrix and transfer functions.
  ///
  /// The composite matrices are computed automatically. The critical planes
  /// table is generated from the [linearize] function.
  factory Gamut.fromPrimaries({
    required String name,
    required List<List<double>> rgbToXyz,
    required double Function(double) trueDelinearize,
    required double Function(double) linearize,
  }) {
    final scaledDiscount = computeScaledDiscountFromLinrgb(rgbToXyz);
    final linrgbFromSD = computeLinrgbFromScaledDiscount(rgbToXyz);
    final xyzToRgb = invert3x3(rgbToXyz);
    final yRow = [rgbToXyz[1][0], rgbToXyz[1][1], rgbToXyz[1][2]];

    // Generate critical planes from the linearize function
    final planes = List<double>.generate(255, (i) => linearize(i + 0.5));

    return Gamut(
      name: name,
      yFromLinrgb: yRow,
      scaledDiscountFromLinrgb: scaledDiscount,
      linrgbFromScaledDiscount: linrgbFromSD,
      rgbToXyz: rgbToXyz,
      xyzToRgb: xyzToRgb,
      trueDelinearize: trueDelinearize,
      linearize: linearize,
      criticalPlanes: planes,
    );
  }

  // ===========================================================================
  // sRGB transfer functions
  // ===========================================================================

  /// sRGB OETF: linear [0..100] → display [0..255].
  static double _srgbTrueDelinearize(double rgbComponent) {
    final normalized = rgbComponent / 100.0;
    double delinearized;
    if (normalized <= 0.0031308) {
      delinearized = normalized * 12.92;
    } else {
      delinearized = 1.055 * pow(normalized, 1.0 / 2.4) - 0.055;
    }
    return delinearized * 255.0;
  }

  /// sRGB EOTF: display [0..255] → linear [0..100].
  static double _srgbLinearize(double srgb) {
    final normalized = srgb / 255.0;
    if (normalized <= 0.040449936) {
      return normalized / 12.92 * 100.0;
    }
    return pow((normalized + 0.055) / 1.055, 2.4) * 100.0;
  }

  // ===========================================================================
  // Rec. 2020 transfer functions (10-bit, pure gamma with linear segment)
  // ===========================================================================

  static const _rec2020Alpha = 1.09929682680944;
  static const _rec2020Beta = 0.018053968510807;

  /// Rec. 2020 OETF: linear [0..100] → display [0..255].
  static double _rec2020TrueDelinearize(double rgbComponent) {
    final normalized = rgbComponent / 100.0;
    double delinearized;
    if (normalized < _rec2020Beta) {
      delinearized = normalized * 4.5;
    } else {
      delinearized = _rec2020Alpha * pow(normalized, 0.45) - (_rec2020Alpha - 1.0);
    }
    return delinearized * 255.0;
  }

  /// Rec. 2020 EOTF: display [0..255] → linear [0..100].
  static double _rec2020Linearize(double encoded) {
    final normalized = encoded / 255.0;
    if (normalized < _rec2020Beta * 4.5) {
      return normalized / 4.5 * 100.0;
    }
    return pow((normalized + (_rec2020Alpha - 1.0)) / _rec2020Alpha, 1.0 / 0.45) * 100.0;
  }

  // ===========================================================================
  // Standard gamut instances
  // ===========================================================================

  /// sRGB / Rec. 709 gamut.
  ///
  /// Uses the sRGB transfer function and Rec. 709 primaries with D65 white point.
  static final srgb = Gamut.fromPrimaries(
    name: 'sRGB',
    rgbToXyz: const [
      [0.41233895, 0.35762064, 0.18051042],
      [0.2126, 0.7152, 0.0722],
      [0.01932141, 0.11916382, 0.95034478],
    ],
    trueDelinearize: _srgbTrueDelinearize,
    linearize: _srgbLinearize,
  );

  /// Display P3 gamut.
  ///
  /// Uses the sRGB transfer function but with wider P3 primaries and D65 white
  /// point. This is the gamut used by Apple displays, modern Android, and
  /// CSS `color(display-p3 ...)`.
  static final displayP3 = Gamut.fromPrimaries(
    name: 'Display P3',
    rgbToXyz: const [
      [0.4865709486, 0.2656676932, 0.1982172852],
      [0.2289745641, 0.6917385218, 0.0792869141],
      [0.0000000000, 0.0451133819, 1.0439443689],
    ],
    // Display P3 uses the same sRGB transfer function
    trueDelinearize: _srgbTrueDelinearize,
    linearize: _srgbLinearize,
  );

  /// Rec. 2020 gamut.
  ///
  /// Very wide gamut used in HDR video (BT.2020/BT.2100). Uses Rec. 2020's own
  /// transfer function with D65 white point.
  static final rec2020 = Gamut.fromPrimaries(
    name: 'Rec. 2020',
    rgbToXyz: const [
      [0.6369580483, 0.1446169036, 0.1688809752],
      [0.2627002120, 0.6779980715, 0.0593017165],
      [0.0000000000, 0.0280726930, 1.0609850577],
    ],
    trueDelinearize: _rec2020TrueDelinearize,
    linearize: _rec2020Linearize,
  );

  @override
  String toString() => 'Gamut($name)';
}
