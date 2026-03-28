// Copied from lib/core/argb_srgb_xyz_lab.dart for perf testing.
// Edit freely — this is throwaway test scaffolding.

import 'dart:math';

/// Returns the standard white point, D65. Blue-white of a sunny day.
const whitePointD65 = [95.047, 100.0, 108.883];
const kSrgbToXyz = [
  [0.41233895, 0.35762064, 0.18051042],
  [0.2126, 0.7152, 0.0722],
  [0.01932141, 0.11916382, 0.95034478],
];
const _midgrayY = 18.418651851244416; /* yFromLstar(50.0) */
const srgbAdaptingLuminance = 200.0 / pi * _midgrayY / 100.0;

const _xyzToSrgb = [
  [
    3.2413774792388685,
    -1.5376652402851851,
    -0.49885366846268053,
  ],
  [
    -0.9691452513005321,
    1.8758853451067872,
    0.04156585616912061,
  ],
  [
    0.05562093689691305,
    -0.20395524564742123,
    1.0571799111220335,
  ],
];

/// Converts a color from RGB components to ARGB format.
int argbFromRgb(int red, int green, int blue) {
  return 255 << 24 | (red & 255) << 16 | (green & 255) << 8 | blue & 255;
}

int argbFromLinrgbComponents(double r, double g, double b) {
  return argbFromRgb(delinear(r), delinear(g), delinear(b));
}

/// Returns the red component of a color in ARGB format.
int redFromArgb(int argb) {
  return argb >> 16 & 255;
}

/// Returns the green component of a color in ARGB format.
int greenFromArgb(int argb) {
  return argb >> 8 & 255;
}

/// Returns the blue component of a color in ARGB format.
int blueFromArgb(int argb) {
  return argb & 255;
}

double yFromArgb(int argb) {
  return yFromLstar(lstarFromArgb(argb));
}

/// Converts a color from ARGB to XYZ.
int argbFromXyz(double x, double y, double z) {
  const matrix = _xyzToSrgb;
  final linearR = matrix[0][0] * x + matrix[0][1] * y + matrix[0][2] * z;
  final linearG = matrix[1][0] * x + matrix[1][1] * y + matrix[1][2] * z;
  final linearB = matrix[2][0] * x + matrix[2][1] * y + matrix[2][2] * z;
  final r = delinear(linearR);
  final g = delinear(linearG);
  final b = delinear(linearB);
  return argbFromRgb(r, g, b);
}

/// Returns the alpha component of a color in ARGB format.
int alphaFromArgb(int argb) {
  return argb >> 24 & 255;
}

/// Converts an L* value to an ARGB representation.
int argbFromLstar(double lstar) {
  final y = yFromLstar(lstar);
  final component = delinear(y);
  return argbFromRgb(component, component, component);
}

/// Computes the L* value of a color in ARGB representation.
double lstarFromArgb(int argb) {
  final r = linear(redFromArgb(argb));
  final g = linear(greenFromArgb(argb));
  final b = linear(blueFromArgb(argb));
  const m = kSrgbToXyz;
  final y = r * m[1][0] + g * m[1][1] + b * m[1][2];
  return 116.0 * _labF(y / 100.0) - 16.0;
}

/// Converts an L* value to a Y value.
double yFromLstar(double lstar) {
  return 100.0 * _labInvf((lstar + 16.0) / 116.0);
}

/// Converts a Y value to an L* value.
double lstarFromY(double y) {
  return _labF(y / 100.0) * 116.0 - 16.0;
}

// ── sRGB transfer functions ──────────────────────────────────────────────────

/// Delinearizes a normalized channel: linear [0,1] → sRGB gamma-encoded [0,1].
double delinearized(double linearNorm) {
  if (linearNorm <= 0.0031308) {
    return linearNorm * 12.92;
  }
  return 1.055 * pow(linearNorm, 1.0 / 2.4) - 0.055;
}

/// Linearizes a normalized channel: sRGB gamma-encoded [0,1] → linear [0,1].
double linearized(double srgbNorm) {
  if (srgbNorm <= 0.040449936) {
    return srgbNorm / 12.92;
  }
  return pow((srgbNorm + 0.055) / 1.055, 2.4).toDouble();
}

/// Linearizes an RGB component.
/// [rgbComponent] 0 <= rgb_component <= 255
/// Returns 0.0 <= output <= 100.0
double linear(int rgbComponent) {
  return linearized(rgbComponent / 255.0) * 100.0;
}

/// Delinearizes an RGB component.
/// [rgbComponent] 0.0 <= rgb_component <= 100.0
/// Returns 0 <= output <= 255
int delinear(double rgbComponent) {
  return (delinearized(rgbComponent / 100.0) * 255.0).clamp(0, 255).round();
}

/// Ensures [degrees] is between 0 and 360.
double sanitizeDegreesDouble(double degrees) {
  degrees = degrees % 360.0;
  if (degrees < 0) {
    degrees = degrees + 360.0;
  }
  return degrees;
}

double _labF(double t) {
  const e = 216.0 / 24389.0;
  const kappa = 24389.0 / 27.0;
  if (t > e) {
    return pow(t, 1.0 / 3.0).toDouble();
  } else {
    return (kappa * t + 16) / 116;
  }
}

double _labInvf(double ft) {
  const e = 216.0 / 24389.0;
  const kappa = 24389.0 / 27.0;
  final ft3 = ft * ft * ft;
  if (ft3 > e) {
    return ft3;
  } else {
    return (116 * ft - 16) / kappa;
  }
}
