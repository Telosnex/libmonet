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
/// Direction is the definition; magnitude yields to the gamut. Note that
/// HCT chroma is not comparable across hues (equal chromatic strength can
/// cost C23 in blue and C30 in teal); uvChroma is the comparable measure.
library;

import 'dart:math' as math;

import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/colorspaces/hct.dart';
import 'package:libmonet/effects/afterimage.dart';

/// u'v' polar coordinates of a color's chromatic push from the white point.
extension HctUvCoordinates on Hct {
  /// Direction of this color's chromaticity from the white point, in
  /// degrees [0, 360). 0 for achromatic colors.
  double get uvHue {
    final p = uvOfArgb(toInt());
    if (p == null) return 0.0;
    final (wu, wv) = whiteUvPoint;
    final degrees =
        math.atan2(p.$2 - wv, p.$1 - wu) * 180.0 / math.pi;
    return (degrees % 360.0 + 360.0) % 360.0;
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

Hct _rotated(
  Hct input,
  SliceCache slice,
  (double, double) offset,
  double degrees,
  double sharedStrength,
) {
  final (wu, wv) = whiteUvPoint;
  final radians = degrees * math.pi / 180.0;
  final cos = math.cos(radians), sin = math.sin(radians);
  final du = offset.$1 * cos - offset.$2 * sin;
  final dv = offset.$1 * sin + offset.$2 * cos;
  final exit = slice.rayExit(du, dv);
  if (exit == null) return Hct.from(0.0, 0.0, input.tone);
  final s = math.min(sharedStrength, exit.$1 * 0.995);
  final result = slice.nearest(wu + s * du, wv + s * dv);
  final retoned = Hct.from(result.hue, result.chroma, input.tone);
  return Hct.fromInt(retoned.toInt(), model: input.colorModel);
}

/// [n] colors at [x]'s tone whose chromatic directions are evenly spaced
/// around the white point, starting at [x]. Because the directions cancel,
/// an additive mixture of the set (at some ratio) is neutral gray: this is
/// the checkable property behind complement (n=2), triad (n=3), and
/// quad (n=4). x itself is the first element.
///
/// By default each color is as vivid as the gamut allows in its direction.
/// With [balanced], all are capped at the weakest direction's strength for
/// an even ensemble (equal [HctUvCoordinates.uvChroma], not equal HCT
/// chroma; the two differ by hue).
///
/// Achromatic inputs return n copies of themselves: no direction to spread.
List<Hct> harmony(Hct x, int n, {bool balanced = false}) {
  assert(n >= 2, 'harmony needs at least 2 colors');
  final p = uvOfArgb(x.toInt());
  if (p == null || x.chroma < 1e-4) return List.filled(n, x);
  final (wu, wv) = whiteUvPoint;
  final offset = (p.$1 - wu, p.$2 - wv);
  final slice = SliceCache.of(x.tone);
  final angles = [for (var i = 0; i < n; i++) i * 360.0 / n];
  var shared = 1.0;
  if (balanced) {
    for (final a in angles) {
      final radians = a * math.pi / 180.0;
      final du = offset.$1 * math.cos(radians) - offset.$2 * math.sin(radians);
      final dv = offset.$1 * math.sin(radians) + offset.$2 * math.cos(radians);
      final exit = slice.rayExit(du, dv);
      if (exit != null) shared = math.min(shared, exit.$1 * 0.995);
    }
  }
  return [
    for (final a in angles)
      if (a == 0.0 && !balanced)
        x // the seed itself, untouched
      else
        _rotated(x, slice, offset, a, shared),
  ];
}

/// [count] colors at [x]'s tone: [x] flanked by neighbors [step] degrees
/// apart in chromatic direction (u'v' angle around the white point), at
/// [x]'s chromatic strength. For odd [count], x is the middle element.
///
/// Unlike [harmony] sets, analogous colors all lean the same way from gray
/// and cannot mix to neutral; this is a nearness operation, not a balance
/// operation. [step] is a design knob, not physics: 30 degrees of u'v'
/// direction per step is the default.
List<Hct> analogous(Hct x, {int count = 5, double step = 30.0}) {
  assert(count >= 1, 'analogous needs at least 1 color');
  final p = uvOfArgb(x.toInt());
  if (p == null || x.chroma < 1e-4) return List.filled(count, x);
  final (wu, wv) = whiteUvPoint;
  final offset = (p.$1 - wu, p.$2 - wv);
  final slice = SliceCache.of(x.tone);
  return [
    for (var i = 0; i < count; i++)
      if (i * 2 == count - 1)
        x // the seed itself, untouched
      else
        _rotated(x, slice, offset, (i - (count - 1) / 2.0) * step, 1.0),
  ];
}
