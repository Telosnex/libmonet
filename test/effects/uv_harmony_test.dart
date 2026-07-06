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

import 'dart:math' as math;

import 'package:libmonet/colorspaces/hct.dart';
import 'package:libmonet/effects/afterimage.dart';
import 'package:libmonet/effects/uv_harmony.dart';
import 'package:test/test.dart';

/// Distance from white to the convex hull of the colors' chromaticities:
/// 0 means some additive mixture of the set is neutral.
double _hullMiss(List<Hct> colors) {
  final (wu, wv) = whiteUvPoint;
  final pts = [for (final c in colors) uvOfArgb(c.toInt())].nonNulls.toList();
  bool inTri((double, double) a, (double, double) b, (double, double) c) {
    double cross((double, double) p, (double, double) q) =>
        (q.$1 - p.$1) * (wv - p.$2) - (q.$2 - p.$2) * (wu - p.$1);
    final d1 = cross(a, b), d2 = cross(b, c), d3 = cross(c, a);
    return !((d1 < 0 || d2 < 0 || d3 < 0) && (d1 > 0 || d2 > 0 || d3 > 0));
  }

  for (var i = 0; i < pts.length; i++) {
    for (var j = i + 1; j < pts.length; j++) {
      for (var k = j + 1; k < pts.length; k++) {
        if (inTri(pts[i], pts[j], pts[k])) return 0.0;
      }
    }
  }
  var best = double.infinity;
  for (var i = 0; i < pts.length; i++) {
    for (var j = i + 1; j < pts.length; j++) {
      final (pu, pv) = pts[i];
      final (qu, qv) = pts[j];
      final du = qu - pu, dv = qv - pv;
      final len2 = du * du + dv * dv;
      var t = len2 < 1e-12 ? 0.0 : ((wu - pu) * du + (wv - pv) * dv) / len2;
      t = t.clamp(0.0, 1.0);
      final xu = pu + t * du, xv = pv + t * dv;
      best = math.min(best,
          math.sqrt((wu - xu) * (wu - xu) + (wv - xv) * (wv - xv)));
    }
  }
  return best;
}

void main() {
  group('uv coordinates', () {
    test('roundtrip: hctFromUv(tone, uvHue, uvChroma) recovers the color',
        () {
      for (var h = 0; h < 360; h += 20) {
        for (final (chroma, tone) in [(60.0, 50.0), (24.0, 75.0)]) {
          final x = Hct.from(h.toDouble(), chroma, tone);
          final back = hctFromUv(x.tone, x.uvHue, x.uvChroma);
          final (xu, xv) = uvOfArgb(x.toInt())!;
          final (bu, bv) = uvOfArgb(back.toInt())!;
          final d = math.sqrt(
              (xu - bu) * (xu - bu) + (xv - bv) * (xv - bv));
          expect(d, lessThan(0.004),
              reason: 'H$h C$chroma T$tone roundtrip drifted $d');
          expect(back.tone, closeTo(x.tone, 0.5));
        }
      }
    });

    test('achromatic colors have zero uvChroma', () {
      expect(Hct.from(0.0, 0.0, 50.0).uvChroma, lessThan(0.005));
    });

    test('out-of-gamut requests clamp to the boundary', () {
      final x = hctFromUv(50.0, 90.0, 10.0); // absurd strength
      expect(x.uvChroma, lessThan(0.3));
      expect(x.tone, closeTo(50.0, 0.5));
    });
  });

  group('harmony', () {
    test('harmony(x, 2)[1] is the afterimage complement, bit-identical', () {
      for (var h = 0; h < 360; h += 15) {
        final x = Hct.from(h.toDouble(), 60.0, 50.0);
        expect(harmony(x, 2)[1].toInt(),
            equals(afterimageComplement(x).toInt()));
      }
    });

    test('first element is the seed, untouched', () {
      final x = Hct.from(210.0, 60.0, 50.0);
      expect(harmony(x, 4)[0].toInt(), equals(x.toInt()));
    });

    test('sets of n >= 3 can mix to neutral, raw and balanced', () {
      for (final n in [3, 4, 6]) {
        for (var h = 0; h < 360; h += 30) {
          final x = Hct.from(h.toDouble(), 70.0, 55.0);
          expect(_hullMiss(harmony(x, n)), lessThan(1e-6),
              reason: 'raw n=$n H$h');
          expect(_hullMiss(harmony(x, n, balanced: true)), lessThan(1e-6),
              reason: 'balanced n=$n H$h');
        }
      }
    });

    test('balanced sets have equal uvChroma', () {
      final set = harmony(Hct.fromInt(0xFF4285F4), 4, balanced: true);
      final strengths = [for (final c in set) c.uvChroma];
      for (final s in strengths) {
        expect(s, closeTo(strengths.first, 0.005));
      }
    });

    test('members preserve tone', () {
      for (final c in harmony(Hct.from(27.0, 80.0, 40.0), 3)) {
        expect(c.tone, closeTo(40.0, 0.5));
      }
    });

    test('achromatic input returns copies', () {
      final gray = Hct.from(0.0, 0.0, 50.0);
      final set = harmony(gray, 3);
      expect(set.length, 3);
      for (final c in set) {
        expect(c.toInt(), equals(gray.toInt()));
      }
    });
  });

  group('analogous', () {
    test('odd count centers on the seed', () {
      final x = Hct.from(120.0, 50.0, 60.0);
      final set = analogous(x);
      expect(set.length, 5);
      expect(set[2].toInt(), equals(x.toInt()));
    });

    test('neighbors preserve tone and are distinct from the seed', () {
      final x = Hct.from(258.0, 60.0, 56.0);
      final set = analogous(x);
      for (final c in set) {
        expect(c.tone, closeTo(x.tone, 0.5));
      }
      expect(set[1].toInt(), isNot(equals(x.toInt())));
      expect(set[3].toInt(), isNot(equals(x.toInt())));
    });

    test('steps walk monotonically in uv direction', () {
      final x = Hct.from(25.0, 100.0, 55.0);
      final set = analogous(x, count: 5, step: 20.0);
      // Unwrap angles relative to the seed's direction.
      final base = x.uvHue;
      final rel = [
        for (final c in set)
          ((c.uvHue - base + 540.0) % 360.0) - 180.0,
      ];
      for (var i = 1; i < rel.length; i++) {
        expect(rel[i], greaterThan(rel[i - 1] - 1.0),
            reason: 'angles should not regress');
      }
    });

    test('achromatic input returns copies', () {
      final gray = Hct.from(0.0, 0.0, 70.0);
      for (final c in analogous(gray)) {
        expect(c.toInt(), equals(gray.toInt()));
      }
    });
  });
}
