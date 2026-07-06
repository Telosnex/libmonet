// Modified and maintained by open-source contributors, on behalf of libmonet.
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

/// Color harmony as vector arithmetic around the white point.
///
/// A color is gray plus a chromatic push: in CIE 1976 u'v' (where light
/// mixing is linear) the push is a vector from the white point with a
/// direction ([HctUvCoordinates.uvHue]) and a magnitude
/// ([HctUvCoordinates.uvChroma]). Harmony operations are arithmetic on the
/// direction:
///
///  - complement: +180 degrees ([afterimageComplement])
///  - [harmony]: n evenly spaced directions; the set can mix to gray
///  - [analogous]: small steps to either side
///
/// Direction is the harmony definition. Tone is a rendering policy; see
/// [HarmonyTonePolicy]. Note that HCT chroma is not comparable across hues
/// (equal chromatic strength can cost C23 in blue and C30 in teal);
/// uvChroma is the comparable measure.
library;

import 'dart:math' as math;

import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/colorspaces/hct.dart';
import 'package:libmonet/core/argb_srgb_xyz_lab.dart';
import 'package:libmonet/effects/afterimage.dart';

/// How harmony colors choose their rendered tone after their u'v' direction
/// has been chosen.
enum HarmonyTonePolicy {
  /// Keep every generated color at the input tone; if the requested
  /// chromaticity cannot exist there, reduce chroma along the ray from white.
  /// This is the theming-safe default: tone remains available for contrast.
  preserveTone,

  /// Render generated companions at `100 - input.tone`; if the requested
  /// chromaticity cannot exist there, reduce chroma along the ray from white.
  /// This gives the dramatic painterly yellow -> blue style of complement.
  /// The seed direction (0 degrees) still uses the input tone.
  reflectTone,

  /// Preserve the requested u'v' chroma when possible by moving tone to the
  /// closest L* where that chromaticity fits in sRGB. If no tone can hold
  /// that chromaticity (the point is outside the RGB chromaticity triangle),
  /// render the nearest chromaticity on the triangle's boundary instead,
  /// again moving tone only as far as necessary. The boundary projection may
  /// bend the u'v' hue slightly; it minimizes chromaticity error rather than
  /// preserving the exact direction.
  fitUvChroma,

  /// Use the rotated u'v' target to choose an HCT hue, then preserve the
  /// input's HCT chroma as closely as possible by scanning tone. Unlike
  /// [fitUvChroma], this treats HCT chroma as the thing to match and lets
  /// u'v' distance vary.
  fitHctChroma,
}

/// u'v' polar coordinates of a color's chromatic push from the white point.
extension HctUvCoordinates on Hct {
  /// Direction of this color's chromaticity from the white point, in
  /// degrees [0, 360). 0 for achromatic colors.
  double get uvHue {
    final p = uvOfArgb(toInt());
    if (p == null) return 0.0;
    final (wu, wv) = whiteUvPoint;
    final degrees = math.atan2(p.$2 - wv, p.$1 - wu) * 180.0 / math.pi;
    return sanitizeDegreesDouble(degrees);
  }

  /// Distance of this color's chromaticity from the white point in u'v'
  /// (0 = achromatic; sRGB colors reach ~0.28 at vivid red).
  double get uvChroma {
    final p = uvOfArgb(toInt());
    if (p == null) return 0.0;
    final (wu, wv) = whiteUvPoint;
    final du = p.$1 - wu, dv = p.$2 - wv;
    return math.sqrt(du * du + dv * dv);
  }
}

/// Color at [tone] whose chromaticity sits [uvChroma] from the white point
/// in direction [uvHue] (degrees), clamped to the sRGB gamut.
Hct hctFromUv(
  double tone,
  double uvHue,
  double uvChroma, {
  ColorModel model = ColorModel.kDefault,
}) {
  final (wu, wv) = whiteUvPoint;
  final radians = uvHue * math.pi / 180.0;
  final slice = SliceCache.of(tone);
  final result = slice.nearest(
    wu + uvChroma * math.cos(radians),
    wv + uvChroma * math.sin(radians),
  );
  final retoned = Hct.from(result.hue, result.chroma, tone.clamp(0.0, 100.0));
  return Hct.fromInt(retoned.toInt(), model: model);
}

const _xyzToSrgb = [
  [3.2413774792388685, -1.5376652402851851, -0.49885366846268053],
  [-0.9691452513005321, 1.8758853451067872, 0.04156585616912061],
  [0.05562093689691305, -0.20395524564742123, 1.0571799111220335],
];

(double, double) _rotateOffset((double, double) offset, double degrees) {
  final radians = degrees * math.pi / 180.0;
  final cos = math.cos(radians), sin = math.sin(radians);
  return (offset.$1 * cos - offset.$2 * sin, offset.$1 * sin + offset.$2 * cos);
}

(double, double, double)? _xyzFromUvTone(double u, double v, double tone) {
  if (v.abs() < 1e-9) return null;
  final y = yFromLstar(tone.clamp(0.0, 100.0));
  final x = 9.0 * u * y / (4.0 * v);
  final z = y * (12.0 - 3.0 * u - 20.0 * v) / (4.0 * v);
  return (x, y, z);
}

(double, double, double)? _linearRgbForUvTone(double u, double v, double tone) {
  final xyz = _xyzFromUvTone(u, v, tone);
  if (xyz == null) return null;
  final (x, y, z) = xyz;
  return (
    _xyzToSrgb[0][0] * x + _xyzToSrgb[0][1] * y + _xyzToSrgb[0][2] * z,
    _xyzToSrgb[1][0] * x + _xyzToSrgb[1][1] * y + _xyzToSrgb[1][2] * z,
    _xyzToSrgb[2][0] * x + _xyzToSrgb[2][1] * y + _xyzToSrgb[2][2] * z,
  );
}

bool _uvToneInSrgb(double u, double v, double tone) {
  final rgb = _linearRgbForUvTone(u, v, tone);
  if (rgb == null) return false;
  const epsilon = 1e-7;
  return rgb.$1 >= -epsilon &&
      rgb.$2 >= -epsilon &&
      rgb.$3 >= -epsilon &&
      rgb.$1 <= 100.0 + epsilon &&
      rgb.$2 <= 100.0 + epsilon &&
      rgb.$3 <= 100.0 + epsilon;
}

/// Closest tone to [preferredTone] that can render chromaticity (u, v)
/// exactly, or null if the chromaticity is outside the sRGB triangle at every
/// luminance.
double? _fitToneForUv(double u, double v, double preferredTone) {
  if (v.abs() < 1e-9) return null;

  // With chromaticity fixed, XYZ and linear RGB are all linear in Y. If any
  // channel coefficient is negative, the chromaticity is outside the RGB
  // triangle and no tone can render it exactly. Otherwise every dimmer Y is
  // valid up to the first channel hitting 100.
  final xPerY = 9.0 * u / (4.0 * v);
  final zPerY = (12.0 - 3.0 * u - 20.0 * v) / (4.0 * v);
  final rPerY =
      _xyzToSrgb[0][0] * xPerY + _xyzToSrgb[0][1] + _xyzToSrgb[0][2] * zPerY;
  final gPerY =
      _xyzToSrgb[1][0] * xPerY + _xyzToSrgb[1][1] + _xyzToSrgb[1][2] * zPerY;
  final bPerY =
      _xyzToSrgb[2][0] * xPerY + _xyzToSrgb[2][1] + _xyzToSrgb[2][2] * zPerY;
  const epsilon = 1e-9;
  if (rPerY < -epsilon || gPerY < -epsilon || bPerY < -epsilon) return null;

  var maxY = 100.0;
  for (final c in [rPerY, gPerY, bPerY]) {
    if (c > epsilon) maxY = math.min(maxY, 100.0 / c);
  }
  final maxTone = lstarFromY(maxY.clamp(0.0, 100.0));
  return math.min(preferredTone.clamp(0.0, 100.0), maxTone);
}

// Chromaticities of the sRGB primaries: corners of the triangle of
// chromaticities that sRGB colors can have (derived from the same pipeline
// as uvOfArgb so the geometry is self-consistent).
final (double, double) _uvRed = uvOfArgb(0xffff0000)!;
final (double, double) _uvGreen = uvOfArgb(0xff00ff00)!;
final (double, double) _uvBlue = uvOfArgb(0xff0000ff)!;

(double, double) _nearestOnSegment(
  (double, double) p,
  (double, double) a,
  (double, double) b,
) {
  final abu = b.$1 - a.$1, abv = b.$2 - a.$2;
  final len2 = abu * abu + abv * abv;
  var t = len2 < 1e-12
      ? 0.0
      : ((p.$1 - a.$1) * abu + (p.$2 - a.$2) * abv) / len2;
  t = t.clamp(0.0, 1.0);
  return (a.$1 + t * abu, a.$2 + t * abv);
}

double _distanceSquared((double, double) a, (double, double) b) {
  final du = a.$1 - b.$1, dv = a.$2 - b.$2;
  return du * du + dv * dv;
}

/// Nearest chromaticity to (u, v) that some sRGB color can have: (u, v)
/// itself when inside the sRGB chromaticity triangle, otherwise the closest
/// point on the triangle's boundary, nudged toward white so linear RGB stays
/// non-negative under floating point.
(double, double) _closestUvInSrgbTriangle(double u, double v) {
  double cross((double, double) a, (double, double) b) =>
      (b.$1 - a.$1) * (v - a.$2) - (b.$2 - a.$2) * (u - a.$1);
  final d1 = cross(_uvRed, _uvGreen);
  final d2 = cross(_uvGreen, _uvBlue);
  final d3 = cross(_uvBlue, _uvRed);
  final hasNegative = d1 < 0 || d2 < 0 || d3 < 0;
  final hasPositive = d1 > 0 || d2 > 0 || d3 > 0;
  if (!(hasNegative && hasPositive)) return (u, v);

  final p = (u, v);
  var best = _nearestOnSegment(p, _uvRed, _uvGreen);
  for (final candidate in [
    _nearestOnSegment(p, _uvGreen, _uvBlue),
    _nearestOnSegment(p, _uvBlue, _uvRed),
  ]) {
    if (_distanceSquared(candidate, p) < _distanceSquared(best, p)) {
      best = candidate;
    }
  }
  final (wu, wv) = whiteUvPoint;
  const nudge = 1e-4;
  return (best.$1 + (wu - best.$1) * nudge, best.$2 + (wv - best.$2) * nudge);
}

Hct _exactUvAtTone(double u, double v, double tone, ColorModel model) {
  final xyz = _xyzFromUvTone(u, v, tone);
  if (xyz == null) return Hct.from(0.0, 0.0, tone, model: model);
  return Hct.fromInt(argbFromXyz(xyz.$1, xyz.$2, xyz.$3), model: model);
}

double _targetTone(
  Hct input,
  double degrees,
  HarmonyTonePolicy tonePolicy,
  double u,
  double v,
) {
  // The seed direction represents the input color; don't tone-flip it.
  if (degrees.abs() < 1e-9 || (degrees % 360.0).abs() < 1e-9) {
    return input.tone;
  }
  return switch (tonePolicy) {
    HarmonyTonePolicy.preserveTone => input.tone,
    HarmonyTonePolicy.reflectTone => 100.0 - input.tone,
    HarmonyTonePolicy.fitUvChroma =>
      _fitToneForUv(u, v, input.tone) ?? input.tone,
    HarmonyTonePolicy.fitHctChroma => input.tone,
  };
}

Hct _rayColorAtScale(
  double tone,
  double du,
  double dv,
  double scale,
  ColorModel model,
) {
  final (wu, wv) = whiteUvPoint;
  final result = SliceCache.of(tone).nearest(wu + scale * du, wv + scale * dv);
  final retoned = Hct.from(result.hue, result.chroma, tone);
  return Hct.fromInt(retoned.toInt(), model: model);
}

double _hctHueFromUvTarget(
  double tone,
  double du,
  double dv,
  ColorModel model,
) {
  final exit = SliceCache.of(tone).rayExit(du, dv);
  if (exit == null) return 0.0;
  return _rayColorAtScale(
    tone,
    du,
    dv,
    math.min(1.0, exit.$1 * 0.995),
    model,
  ).hue;
}

bool _isBetterHctChromaFit(Hct candidate, Hct? best, Hct input) {
  if (best == null) return true;
  final chromaDiff = (candidate.chroma - input.chroma).abs();
  final bestChromaDiff = (best.chroma - input.chroma).abs();
  if (chromaDiff < bestChromaDiff - 1e-9) return true;
  if ((chromaDiff - bestChromaDiff).abs() > 1e-9) return false;
  return (candidate.tone - input.tone).abs() < (best.tone - input.tone).abs();
}

Hct _fitHctChromaFromUvHue(Hct input, double du, double dv) {
  final targetHue = _hctHueFromUvTarget(input.tone, du, dv, input.colorModel);
  Hct? best;

  void visit(double tone) {
    final candidate = Hct.from(
      targetHue,
      input.chroma,
      tone.clamp(0.0, 100.0),
      model: input.colorModel,
    );
    if (_isBetterHctChromaFit(candidate, best, input)) best = candidate;
  }

  for (var tone = 0.0; tone <= 100.0; tone += 0.5) {
    visit(tone);
  }

  final coarse = best!.tone;
  for (var tone = coarse - 0.5; tone <= coarse + 0.5; tone += 0.05) {
    visit(tone);
  }

  return best!;
}

Hct _rotated(
  Hct input,
  (double, double) offset,
  double degrees,
  double sharedStrength,
  HarmonyTonePolicy tonePolicy,
) {
  final (wu, wv) = whiteUvPoint;
  final rotated = _rotateOffset(offset, degrees);
  final du = rotated.$1 * sharedStrength;
  final dv = rotated.$2 * sharedStrength;
  var targetU = wu + du, targetV = wv + dv;
  if (tonePolicy == HarmonyTonePolicy.fitUvChroma) {
    // If the exact chromaticity is impossible in sRGB at every tone, aim for
    // the closest possible chromaticity instead of the seed-tone ray clamp.
    (targetU, targetV) = _closestUvInSrgbTriangle(targetU, targetV);
  }
  final targetTone = _targetTone(input, degrees, tonePolicy, targetU, targetV);

  if (tonePolicy == HarmonyTonePolicy.fitUvChroma &&
      _uvToneInSrgb(targetU, targetV, targetTone)) {
    return _exactUvAtTone(targetU, targetV, targetTone, input.colorModel);
  }

  if (tonePolicy == HarmonyTonePolicy.fitHctChroma) {
    return _fitHctChromaFromUvHue(input, du, dv);
  }

  final slice = SliceCache.of(targetTone);
  final exit = slice.rayExit(du, dv);
  if (exit == null) return Hct.from(0.0, 0.0, targetTone);
  final s = math.min(1.0, exit.$1 * 0.995);
  final result = slice.nearest(wu + s * du, wv + s * dv);
  final retoned = Hct.from(result.hue, result.chroma, targetTone);
  return Hct.fromInt(retoned.toInt(), model: input.colorModel);
}

/// [n] colors whose chromatic directions are evenly spaced around the white
/// point, starting at [x]. Because the directions cancel, an additive mixture
/// of the set (at some ratio) is neutral gray: this is the checkable property
/// behind complement (n=2), triad (n=3), and quad (n=4).
///
/// By default each color is as vivid as the gamut allows in its direction.
/// With [balanced], all are capped at the weakest direction's strength for
/// an even ensemble (equal [HctUvCoordinates.uvChroma], not equal HCT
/// chroma; the two differ by hue).
///
/// [tonePolicy] controls L*: preserve tone for theming, reflect tone for the
/// dramatic painterly complement, move tone only as far as necessary to
/// preserve u'v' chroma, or move tone to preserve HCT chroma.
///
/// Achromatic inputs return n copies of themselves: no direction to spread.
List<Hct> harmony(
  Hct x,
  int n, {
  bool balanced = false,
  HarmonyTonePolicy tonePolicy = HarmonyTonePolicy.preserveTone,
}) {
  assert(n >= 2, 'harmony needs at least 2 colors');
  final p = uvOfArgb(x.toInt());
  if (p == null || x.chroma < 1e-4) return List.filled(n, x);
  final (wu, wv) = whiteUvPoint;
  final offset = (p.$1 - wu, p.$2 - wv);
  final angles = [for (var i = 0; i < n; i++) i * 360.0 / n];
  var shared = 1.0;
  if (balanced) {
    for (final a in angles) {
      final rotated = _rotateOffset(offset, a);
      final targetU = wu + rotated.$1, targetV = wv + rotated.$2;
      final tone = _targetTone(x, a, tonePolicy, targetU, targetV);
      final exit = SliceCache.of(tone).rayExit(rotated.$1, rotated.$2);
      if (exit != null) shared = math.min(shared, exit.$1 * 0.995);
    }
  }
  return [
    for (final a in angles)
      if (a == 0.0 && !balanced)
        x // the seed itself, untouched
      else
        _rotated(x, offset, a, shared, tonePolicy),
  ];
}

/// [count] colors: [x] flanked by neighbors [step] degrees apart in chromatic
/// direction (u'v' angle around the white point). For odd [count], x is the
/// middle element.
///
/// Unlike [harmony] sets, analogous colors all lean the same way from gray
/// and cannot mix to neutral; this is a nearness operation, not a balance
/// operation. [step] is a design knob, not physics: 30 degrees of u'v'
/// direction per step is the default.
List<Hct> analogous(
  Hct x, {
  int count = 5,
  double step = 30.0,
  HarmonyTonePolicy tonePolicy = HarmonyTonePolicy.preserveTone,
}) {
  assert(count >= 1, 'analogous needs at least 1 color');
  final p = uvOfArgb(x.toInt());
  if (p == null || x.chroma < 1e-4) return List.filled(count, x);
  final (wu, wv) = whiteUvPoint;
  final offset = (p.$1 - wu, p.$2 - wv);
  return [
    for (var i = 0; i < count; i++)
      if (i * 2 == count - 1)
        x // the seed itself, untouched
      else
        _rotated(x, offset, (i - (count - 1) / 2.0) * step, 1.0, tonePolicy),
  ];
}
