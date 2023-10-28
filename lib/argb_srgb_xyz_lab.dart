// Modified and maintained by open-source contributors, on behalf of libmonet.
//
// Original notice:
// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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

double lumaFromLstar(double lstar) {
  return lumaFromArgb(argbFromLstar(lstar));
}

double yFromArgb(int argb) {
  return yFromLstar(lstarFromArgb(argb));
  // double linear(int rgbComponent) {
  //   final normalized = rgbComponent / 255.0;
  //   if (normalized <= 0.040449936) {
  //     return normalized / 12.92 * 100.0;
  //   } else {
  //     return pow((normalized + 0.055) / 1.055, 2.4).toDouble() * 100.0;
  //   }
  // }
  // final linearR = linear(redFromArgb(argb));
  // final linearG = linear(greenFromArgb(argb));
  // final linearB = linear(blueFromArgb(argb));
  // final y = 0.2126 * linearR + 0.7152 * linearG + 0.0722 * linearB;
  // return y;
}

double lumaFromArgb(int argb) {
  final r = redFromArgb(argb).toDouble() / 255.0;
  final g = greenFromArgb(argb).toDouble() / 255.0;
  final b = blueFromArgb(argb).toDouble() / 255.0;
  return (0.2126 * r + 0.7152 * g + 0.0722 * b) * 100.0;
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

/// Convert a color from L*a*b* to RGB.
int argbFromLab(double l, double a, double b) {
  const whitePoint = whitePointD65;
  final fy = (l + 16.0) / 116.0;
  final fx = a / 500.0 + fy;
  final fz = fy - b / 200.0;
  final xNormalized = _labInvf(fx);
  final yNormalized = _labInvf(fy);
  final zNormalized = _labInvf(fz);
  final x = xNormalized * whitePoint[0];
  final y = yNormalized * whitePoint[1];
  final z = zNormalized * whitePoint[2];
  return argbFromXyz(x, y, z);
}

/// Convert a color from ARGB to L*a*b*.
///
/// [argb] the ARGB representation of a color
/// Returns 3 doubles representing L*, a*, and b*.
List<double> labFromArgb(int argb) {
  final linearR = linear(redFromArgb(argb));
  final linearG = linear(greenFromArgb(argb));
  final linearB = linear(blueFromArgb(argb));
  const matrix = kSrgbToXyz;
  final x =
      matrix[0][0] * linearR + matrix[0][1] * linearG + matrix[0][2] * linearB;
  final y =
      matrix[1][0] * linearR + matrix[1][1] * linearG + matrix[1][2] * linearB;
  final z =
      matrix[2][0] * linearR + matrix[2][1] * linearG + matrix[2][2] * linearB;
  final xNormalized = x / whitePointD65[0];
  final yNormalized = y / whitePointD65[1];
  final zNormalized = z / whitePointD65[2];
  final fx = _labF(xNormalized);
  final fy = _labF(yNormalized);
  final fz = _labF(zNormalized);
  final l = 116.0 * fy - 16;
  final a = 500.0 * (fx - fy);
  final b = 200.0 * (fy - fz);
  return [l, a, b];
}

/// Converts an L* value to an ARGB representation.
///
/// [lstar] L* in L*a*b*
/// Returns ARGB representation of grayscale color with lightness matching L*
int argbFromLstar(double lstar) {
  final y = yFromLstar(lstar);
  final component = delinear(y);
  return argbFromRgb(component, component, component);
}

/// Computes the L* value of a color in ARGB representation.
///
/// [argb] ARGB representation of a color
/// Returns L*, from L*a*b*, coordinate of the color
double lstarFromArgb(int argb) {
  final r = linear(redFromArgb(argb));
  final g = linear(greenFromArgb(argb));
  final b = linear(blueFromArgb(argb));
  const m = kSrgbToXyz;
  final y = r * m[1][0] + g * m[1][1] + b * m[1][2];
  return 116.0 * _labF(y / 100.0) - 16.0;
}

/// Converts an L* value to a Y value.
///
/// [lstar] L* in L*a*b*
/// Returns Y in XYZ
double yFromLstar(double lstar) {
  return 100.0 * _labInvf((lstar + 16.0) / 116.0);
}

/// Converts a Y value to an L* value.
///
/// [y] Y in XYZ
/// Returns L* in L*a*b*
double lstarFromY(double y) {
  return _labF(y / 100.0) * 116.0 - 16.0;
}

/// Linearizes an RGB component.
///
/// [rgbComponent] 0 <= rgb_component <= 255, represents R/G/B channel.
/// Returns 0.0 <= output <= 100.0, color channel converted to linear RGB.
double linear(int rgbComponent) {
  final normalized = rgbComponent / 255.0;
  if (normalized <= 0.040449936) {
    return normalized / 12.92 * 100.0;
  } else {
    return pow((normalized + 0.055) / 1.055, 2.4).toDouble() * 100.0;
  }
}

/// Delinearizes an RGB component.
///
/// [rgbComponent] 0.0 <= rgb_component <= 100.0, represents linear
/// R/G/B channel
///
/// Returns 0 <= output <= 255, color channel converted to regular RGB.
int delinear(double rgbComponent) {
  final normalized = rgbComponent / 100.0;
  var delinearized = 0.0;
  if (normalized <= 0.0031308) {
    delinearized = normalized * 12.92;
  } else {
    delinearized = 1.055 * pow(normalized, 1.0 / 2.4).toDouble() - 0.055;
  }
  final raw = delinearized * 255.0;
  return raw.clamp(0, 255).round();
}

/// Ensures [degrees] is between 0 and 360.
double sanitizeDegreesDouble(double degrees) {
  degrees = degrees % 360.0;
  if (degrees < 0) {
    degrees = degrees + 360.0;
  }
  return degrees;
}

/// Ensures [degrees] is between 0 and 360.
int sanitizeDegreesInt(int degrees) {
  degrees = degrees % 360;
  if (degrees < 0) {
    degrees = degrees + 360;
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
