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

// Correctness sweep for afterimageComplement over the RGB cube: the
// defining property is that an additive mixture of input + afterimage is
// neutral, i.e. the white point's chromaticity lies on the u'v' segment
// between the pair. Error = distance (in u'v') from the white point to that
// segment. 0.004 is roughly a just-noticeable difference in u'v'.
//
// Where the point-reflected target is renderable at the input's tone the
// error should be ~0; residuals come from gamut projection (deep blues/reds
// whose opposites don't exist in sRGB at that tone).
import 'dart:math' as math;

import 'package:libmonet/colorspaces/hct.dart';
import 'package:libmonet/effects/afterimage.dart';
import 'package:test/test.dart';

void main() {
  test('mix(input, afterimage) is neutral across the RGB cube', () {
    final (wu, wv) = whiteUvPoint;

    // Distance from white to the segment p..q in u'v'.
    double err((double, double) p, (double, double) q) {
      final (pu, pv) = p;
      final (qu, qv) = q;
      final du = qu - pu, dv = qv - pv;
      final len2 = du * du + dv * dv;
      var t = len2 < 1e-12 ? 0.0 : ((wu - pu) * du + (wv - pv) * dv) / len2;
      t = t.clamp(0.0, 1.0);
      final xu = pu + t * du, xv = pv + t * dv;
      return math.sqrt((wu - xu) * (wu - xu) + (wv - xv) * (wv - xv));
    }

    final errors = <double>[];
    // Guard against the degenerate cheat: gray mixes to neutral trivially.
    // A chromatic input must get a chromatic afterimage.
    var grayCheats = 0, chromaticInputs = 0;
    for (var r = 0; r <= 255; r += 17) {
      for (var g = 0; g <= 255; g += 17) {
        for (var b = 0; b <= 255; b += 17) {
          final argb = 0xff000000 | (r << 16) | (g << 8) | b;
          final p = uvOfArgb(argb);
          if (p == null) continue; // black
          final comp = afterimageComplement(Hct.fromInt(argb));
          final q = uvOfArgb(comp.toInt());
          if (q == null) continue;
          errors.add(err(p, q));
          final (pu, pv) = p;
          final (qu, qv) = q;
          final inStr =
              math.sqrt((pu - wu) * (pu - wu) + (pv - wv) * (pv - wv));
          final outStr =
              math.sqrt((qu - wu) * (qu - wu) + (qv - wv) * (qv - wv));
          if (inStr > 0.02) {
            chromaticInputs++;
            if (outStr < 0.005) grayCheats++;
          }
        }
      }
    }

    errors.sort();
    double pct(double q) => errors[(q * (errors.length - 1)).round()];
    final jnd = errors.where((e) => e < 0.004).length / errors.length;
    expect(pct(.5), lessThan(0.001), reason: 'median should be sub-JND');
    expect(pct(.95), lessThan(0.004), reason: 'p95 should be sub-JND');
    expect(pct(1.0), lessThan(0.01),
        reason: 'max error is a gamut-clamping floor, ~0.005');
    expect(jnd, greaterThan(0.99),
        reason: 'nearly all of the cube should mix to neutral within a JND');
    expect(grayCheats / chromaticInputs, lessThan(0.01),
        reason: 'gray output for chromatic input = degenerate non-answer');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('achromatic inputs return themselves', () {
    expect(afterimageComplement(Hct.fromInt(0xff000000)).toInt(),
        equals(0xff000000));
    expect(afterimageComplement(Hct.fromInt(0xffffffff)).toInt(),
        equals(0xffffffff));
    final gray = afterimageComplement(Hct.from(0.0, 0.0, 50.0));
    expect(gray.chroma, lessThan(2.5));
    expect(gray.tone, closeTo(50.0, 0.5));
  });

  test('preserves tone and color model', () {
    final input = Hct.from(27.0, 60.0, 43.7);
    final comp = afterimageComplement(input);
    expect(comp.tone, closeTo(input.tone, 0.5));
    expect(comp.colorModel, equals(input.colorModel));
  });

  test('chroma is not preserved: yellow vs blue asymmetry', () {
    // Yellow is chromatically weak per unit HCT chroma; its violet-blue
    // opposite is strong. The complement of a vivid yellow must therefore
    // have far lower chroma than the complement of a vivid blue.
    final yellow = Hct.fromInt(0xffffff00);
    final blue = Hct.fromInt(0xff0000ff);
    final yellowComp = afterimageComplement(yellow);
    final blueComp = afterimageComplement(blue);
    expect(yellowComp.chroma, lessThan(yellow.chroma));
    expect(blueComp.chroma, lessThan(blue.chroma));
    expect(yellowComp.chroma, lessThan(blueComp.chroma));
  });
}
