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
import 'package:libmonet/core/argb_srgb_xyz_lab.dart';

/// CIE 1976 u'v' chromaticity of [argb], or null for degenerate (black).
(double, double)? uvOfArgb(int argb) {
  final xyz = xyzFromArgb(argb);
  final denom = xyz[0] + 15.0 * xyz[1] + 3.0 * xyz[2];
  if (denom.abs() < 1e-9) return null;
  return (4.0 * xyz[0] / denom, 9.0 * xyz[1] / denom);
}

/// u'v' chromaticity of the sRGB white point (D65).
final (double, double) whiteUvPoint = uvOfArgb(0xffffffff)!;

/// The afterimage complement: the color the eye produces after adapting to
/// [input].
///
/// Cone fatigue shifts perception of a neutral field in the direction
/// *opposite* the stimulus chromaticity (Zaidi et al., "Neural locus of
/// color afterimages", Current Biology 2012: the rebound is the
/// chromatically opposite signal), so the afterimage chromaticity is the
/// point reflection of the input's u'v' through the white point:
///
///     target = white + (white - input)
///
/// equal strength, opposite direction — rendered at the input's tone. This
/// gives the pair its defining, physically checkable property: an additive
/// mixture of input and complement is neutral. Verified across the RGB cube
/// in test/effects/afterimage_test.dart (99.9% of colors mix to within one
/// u'v' JND of white).
///
/// If the full-strength target is out of gamut at the input's tone, strength
/// is clamped ALONG THE RAY from white: direction is physiology, only
/// magnitude yields to the gamut. Consequently chroma is NOT preserved —
/// yellow's complement is a far dimmer violet-blue than blue's complement is
/// a gold — which is what distinguishes this from hue-rotation complements.
///
/// Achromatic inputs return themselves: with no chromatic fatigue there is
/// no afterimage.
Hct afterimageComplement(Hct input) {
  final p = uvOfArgb(input.toInt());
  if (p == null) return input; // black: no chromaticity to fatigue against
  final (u, v) = p;
  final (wu, wv) = whiteUvPoint;
  final du = wu - u, dv = wv - v; // opposite direction; s=1 is full strength
  final slice = SliceCache.of(input.tone);
  final exit = slice.rayExit(du, dv);
  final result = exit == null
      ? Hct.from(0.0, 0.0, input.tone)
      // Clamp strength along the ray to just inside the boundary.
      : slice.nearest(wu + math.min(1.0, exit.$1 * 0.995) * du,
          wv + math.min(1.0, exit.$1 * 0.995) * dv);
  // Slice tone is quantized (0.5 steps); restore the exact input tone, and
  // re-express in the input's color model.
  final retoned = Hct.from(result.hue, result.chroma, input.tone);
  return Hct.fromInt(retoned.toInt(), model: input.colorModel);
}

/// Per-tone cache of the sRGB gamut slice's chromaticity boundary.
///
/// Answers queries against one object: "the set of u'v' chromaticities
/// renderable at tone T". The boundary is sampled once per tone (360 HCT
/// solves); queries are polyline arithmetic plus a small local refinement
/// (~46 solves, ~40us).
///
/// Refinement effort (iteration counts below) was chosen by sweeping the
/// full RGB cube; error is mix-to-neutral deviation in u'v' (JND ~ 0.004):
///
///   config                       p95      max     %<JND  us/call
///   c16 h[4,1]x10 p8   0.00120  0.00505   99.9    108
///   c12 h[4,1]x8  p8   0.00127  0.00483   99.9     86
///   c8  h[4]x6    p4   0.00149  0.00483   99.9     42   <- shipped
///   c6  h[4]x5    p4   0.00170  0.00483   99.9     34
///   c4  h[4]x4    p2   0.00206  0.00806   99.6     24
///
/// Max error is identical from ceiling to minimal: it is a gamut-clamping
/// floor that more iterations cannot buy back. The shipped config sits well
/// above the accuracy cliff (which begins at c4/h4/p2) at half the cost of
/// the conservative config.
class SliceCache {
  SliceCache._(this.tone, this.us, this.vs, this.maxChromas);

  /// The (quantized) tone this slice was sampled at.
  final double tone;

  /// Boundary chromaticity u', v', and max chroma, indexed by hue degree.
  final List<double> us, vs, maxChromas;

  static final Map<double, SliceCache> _byTone = {};

  // See the class doc for the sweep behind these values.
  static const int _chromaIters = 8;
  static const double _hueWidth = 4.0;
  static const int _hueIters = 6;
  static const int _polishIters = 4;

  /// The slice for [rawTone].
  ///
  /// Tones are quantized to 0.5 steps: bounds the cache at 201 entries and
  /// makes arbitrary real-world tones (T=47.238...) actually hit it. Callers
  /// re-tone results to the exact input tone; chromaticity error from a
  /// <=0.25 tone shift is far below a JND.
  static SliceCache of(double rawTone) {
    final tone = (rawTone.clamp(0.0, 100.0) * 2.0).round() / 2.0;
    return _byTone.putIfAbsent(tone, () {
      final us = List.filled(360, 0.0);
      final vs = List.filled(360, 0.0);
      final cs = List.filled(360, 0.0);
      for (var h = 0; h < 360; h++) {
        final hct = Hct.from(h.toDouble(), 250.0, tone); // gamut-clamped
        final uv = uvOfArgb(hct.toInt()) ?? whiteUvPoint;
        us[h] = uv.$1;
        vs[h] = uv.$2;
        cs[h] = hct.chroma;
      }
      return SliceCache._(tone, us, vs, cs);
    });
  }

  /// Walks boundary segments to find where the ray `white + s*(du, dv)`
  /// exits the slice. Returns (s, hueIndex + fraction), or null if the
  /// slice is degenerate (tone ~0 or ~100, or a zero direction).
  (double, double)? rayExit(double du, double dv) {
    final (wu, wv) = whiteUvPoint;
    (double, double)? best;
    for (var i = 0; i < 360; i++) {
      final j = (i + 1) % 360;
      final au = us[i] - wu, av = vs[i] - wv;
      final bu = us[j] - wu, bv = vs[j] - wv;
      final eu = bu - au, ev = bv - av;
      final det = du * ev - dv * eu;
      if (det.abs() < 1e-18) continue;
      final t = (au * dv - av * du) / det; // along segment
      final s = (au * ev - av * eu) / det; // along ray
      if (t >= 0 && t < 1 && s > 0) {
        if (best == null || s < best.$1) best = (s, i + t);
      }
    }
    return best;
  }

  double _dist2(Hct h, double tu, double tv) {
    final q = uvOfArgb(h.toInt());
    if (q == null) return double.infinity;
    final (qu, qv) = q;
    return (qu - tu) * (qu - tu) + (qv - tv) * (qv - tv);
  }

  Hct _chromaSearch(double hue, double tu, double tv) {
    var lo = 0.0, hi = maxChromas[hue.floor() % 360] + 4.0;
    for (var i = 0; i < _chromaIters; i++) {
      final m1 = lo + (hi - lo) / 3.0, m2 = hi - (hi - lo) / 3.0;
      if (_dist2(Hct.from(hue, m1, tone), tu, tv) <=
          _dist2(Hct.from(hue, m2, tone), tu, tv)) {
        hi = m2;
      } else {
        lo = m1;
      }
    }
    return Hct.from(hue, (lo + hi) / 2.0, tone);
  }

  /// In-gamut color at [tone] whose chromaticity is nearest (tu, tv).
  Hct nearest(double tu, double tv) {
    final (wu, wv) = whiteUvPoint;
    final du = tu - wu, dv = tv - wv;
    final dist = math.sqrt(du * du + dv * dv);
    if (dist < 1e-9) return Hct.from(0.0, 0.0, tone);
    final exit = rayExit(du, dv);
    if (exit == null) return Hct.from(0.0, 0.0, tone);
    final hue = exit.$2 % 360.0;
    if (exit.$1 <= 1.0) {
      // Target at/outside boundary: nearest point on the cached polyline,
      // pure arithmetic (no solver), then a short boundary polish.
      var bestD = double.infinity;
      var bestHue = hue;
      for (var i = 0; i < 360; i++) {
        final j = (i + 1) % 360;
        final eu = us[j] - us[i], ev = vs[j] - vs[i];
        final len2 = eu * eu + ev * ev;
        var t = 0.0;
        if (len2 > 1e-18) {
          t = (((tu - us[i]) * eu + (tv - vs[i]) * ev) / len2).clamp(0.0, 1.0);
        }
        final qu = us[i] + t * eu - tu, qv = vs[i] + t * ev - tv;
        final d = qu * qu + qv * qv;
        if (d < bestD) {
          bestD = d;
          bestHue = (i + t) % 360.0;
        }
      }
      // Polish: polyline is ~1 degree coarse; ternary-search true boundary.
      var lo = bestHue - 1.0, hi = bestHue + 1.0;
      for (var i = 0; i < _polishIters; i++) {
        final m1 = lo + (hi - lo) / 3.0, m2 = hi - (hi - lo) / 3.0;
        if (_dist2(Hct.from(m1 % 360.0, 250.0, tone), tu, tv) <=
            _dist2(Hct.from(m2 % 360.0, 250.0, tone), tu, tv)) {
          hi = m2;
        } else {
          lo = m1;
        }
      }
      return Hct.from(((lo + hi) / 2.0) % 360.0, 250.0, tone);
    }
    // Inside: refine chroma, then hue, then chroma again. HCT hue lines
    // curve in u'v', so the best hue can sit a few degrees off the
    // ray-exit hue.
    var bestHue = hue;
    var best = _chromaSearch(bestHue, tu, tv);
    var lo = bestHue - _hueWidth, hi = bestHue + _hueWidth;
    for (var i = 0; i < _hueIters; i++) {
      final m1 = lo + (hi - lo) / 3.0, m2 = hi - (hi - lo) / 3.0;
      if (_dist2(Hct.from(m1 % 360.0, best.chroma, tone), tu, tv) <=
          _dist2(Hct.from(m2 % 360.0, best.chroma, tone), tu, tv)) {
        hi = m2;
      } else {
        lo = m1;
      }
    }
    bestHue = ((lo + hi) / 2.0) % 360.0;
    return _chromaSearch(bestHue, tu, tv);
  }
}
