// Afterimage complement. Port of lib/effects/afterimage.dart; must be kept
// in sync.
//
// The afterimage the eye produces after adapting to a color: cone fatigue
// shifts perception of a neutral field in the direction opposite the
// stimulus chromaticity, so the afterimage chromaticity is the point
// reflection of the input's u'v' through the white point. Rendered at the
// input's tone. If the full-strength target is out of gamut, strength is
// clamped along the ray from white: direction is physiology, only magnitude
// yields to the gamut. An additive mixture of input and complement is
// neutral.
import {Hct} from './hct.js';
import {xyzFromArgb} from './oklch.js';

/** CIE 1976 u'v' chromaticity of argb, or null for degenerate (black). */
export function uvOfArgb(argb: number): [number, number] | null {
  const [x, y, z] = xyzFromArgb(argb);
  const denom = x + 15 * y + 3 * z;
  if (Math.abs(denom) < 1e-9) return null;
  return [4 * x / denom, 9 * y / denom];
}

/** u'v' chromaticity of the sRGB white point (D65). */
export const whiteUvPoint: [number, number] = uvOfArgb(0xffffffff)!;

// Refinement effort; see lib/effects/afterimage.dart for the sweep behind
// these values.
const chromaIters = 8;
const hueWidth = 4;
const hueIters = 6;
const polishIters = 4;

/**
 * Per-tone cache of the sRGB gamut slice's chromaticity boundary: the set
 * of u'v' chromaticities renderable at tone T. Sampled once per tone
 * (360 HCT solves); queries are polyline arithmetic plus a small local
 * refinement.
 */
export class SliceCache {
  private static byTone = new Map<number, SliceCache>();

  private constructor(
    readonly tone: number,
    readonly us: Float64Array,
    readonly vs: Float64Array,
    readonly maxChromas: Float64Array,
  ) {}

  /**
   * The slice for rawTone. Tones are quantized to 0.5 steps: bounds the
   * cache at 201 entries and makes arbitrary real-world tones actually hit
   * it. Callers re-tone results to the exact input tone.
   */
  static of(rawTone: number): SliceCache {
    const tone = Math.round(Math.min(100, Math.max(0, rawTone)) * 2) / 2;
    let slice = SliceCache.byTone.get(tone);
    if (slice) return slice;
    const us = new Float64Array(360);
    const vs = new Float64Array(360);
    const cs = new Float64Array(360);
    for (let h = 0; h < 360; h++) {
      const hct = Hct.from(h, 250, tone); // gamut-clamped
      const uv = uvOfArgb(hct.toInt()) ?? whiteUvPoint;
      us[h] = uv[0];
      vs[h] = uv[1];
      cs[h] = hct.chroma;
    }
    slice = new SliceCache(tone, us, vs, cs);
    SliceCache.byTone.set(tone, slice);
    return slice;
  }

  /**
   * Walks boundary segments to find where the ray `white + s*(du, dv)`
   * exits the slice. Returns [s, hueIndex + fraction], or null if the
   * slice is degenerate (tone ~0 or ~100, or a zero direction).
   */
  rayExit(du: number, dv: number): [number, number] | null {
    const [wu, wv] = whiteUvPoint;
    let best: [number, number] | null = null;
    for (let i = 0; i < 360; i++) {
      const j = (i + 1) % 360;
      const au = this.us[i]! - wu, av = this.vs[i]! - wv;
      const bu = this.us[j]! - wu, bv = this.vs[j]! - wv;
      const eu = bu - au, ev = bv - av;
      const det = du * ev - dv * eu;
      if (Math.abs(det) < 1e-18) continue;
      const t = (au * dv - av * du) / det; // along segment
      const s = (au * ev - av * eu) / det; // along ray
      if (t >= 0 && t < 1 && s > 0) {
        if (best === null || s < best[0]) best = [s, i + t];
      }
    }
    return best;
  }

  private dist2(h: Hct, tu: number, tv: number): number {
    const q = uvOfArgb(h.toInt());
    if (q === null) return Number.POSITIVE_INFINITY;
    return (q[0] - tu) * (q[0] - tu) + (q[1] - tv) * (q[1] - tv);
  }

  private chromaSearch(hue: number, tu: number, tv: number): Hct {
    let lo = 0, hi = this.maxChromas[Math.floor(hue) % 360]! + 4;
    for (let i = 0; i < chromaIters; i++) {
      const m1 = lo + (hi - lo) / 3, m2 = hi - (hi - lo) / 3;
      if (this.dist2(Hct.from(hue, m1, this.tone), tu, tv) <=
          this.dist2(Hct.from(hue, m2, this.tone), tu, tv)) {
        hi = m2;
      } else {
        lo = m1;
      }
    }
    return Hct.from(hue, (lo + hi) / 2, this.tone);
  }

  /** In-gamut color at this tone whose chromaticity is nearest (tu, tv). */
  nearest(tu: number, tv: number): Hct {
    const [wu, wv] = whiteUvPoint;
    const du = tu - wu, dv = tv - wv;
    if (Math.sqrt(du * du + dv * dv) < 1e-9) {
      return Hct.from(0, 0, this.tone);
    }
    const exit = this.rayExit(du, dv);
    if (exit === null) return Hct.from(0, 0, this.tone);
    const hue = exit[1] % 360;
    if (exit[0] <= 1) {
      // Target at/outside boundary: nearest point on the cached polyline,
      // pure arithmetic (no solver), then a short boundary polish.
      let bestD = Number.POSITIVE_INFINITY;
      let bestHue = hue;
      for (let i = 0; i < 360; i++) {
        const j = (i + 1) % 360;
        const eu = this.us[j]! - this.us[i]!, ev = this.vs[j]! - this.vs[i]!;
        const len2 = eu * eu + ev * ev;
        let t = 0;
        if (len2 > 1e-18) {
          t = Math.min(1, Math.max(0,
              ((tu - this.us[i]!) * eu + (tv - this.vs[i]!) * ev) / len2));
        }
        const qu = this.us[i]! + t * eu - tu, qv = this.vs[i]! + t * ev - tv;
        const d = qu * qu + qv * qv;
        if (d < bestD) {
          bestD = d;
          bestHue = (i + t) % 360;
        }
      }
      // Polish: polyline is ~1 degree coarse; ternary-search true boundary.
      let lo = bestHue - 1, hi = bestHue + 1;
      for (let i = 0; i < polishIters; i++) {
        const m1 = lo + (hi - lo) / 3, m2 = hi - (hi - lo) / 3;
        if (this.dist2(Hct.from(((m1 % 360) + 360) % 360, 250, this.tone), tu, tv) <=
            this.dist2(Hct.from(((m2 % 360) + 360) % 360, 250, this.tone), tu, tv)) {
          hi = m2;
        } else {
          lo = m1;
        }
      }
      return Hct.from(((((lo + hi) / 2) % 360) + 360) % 360, 250, this.tone);
    }
    // Inside: refine chroma, then hue, then chroma again. HCT hue lines
    // curve in u'v', so the best hue can sit a few degrees off the
    // ray-exit hue.
    let bestHue = hue;
    let best = this.chromaSearch(bestHue, tu, tv);
    let lo = bestHue - hueWidth, hi = bestHue + hueWidth;
    for (let i = 0; i < hueIters; i++) {
      const m1 = lo + (hi - lo) / 3, m2 = hi - (hi - lo) / 3;
      if (this.dist2(Hct.from(((m1 % 360) + 360) % 360, best.chroma, this.tone), tu, tv) <=
          this.dist2(Hct.from(((m2 % 360) + 360) % 360, best.chroma, this.tone), tu, tv)) {
        hi = m2;
      } else {
        lo = m1;
      }
    }
    bestHue = ((((lo + hi) / 2) % 360) + 360) % 360;
    return this.chromaSearch(bestHue, tu, tv);
  }
}

/**
 * The afterimage complement: the color the eye produces after adapting to
 * the input. Rendered at the input's tone; chroma is NOT preserved.
 * Achromatic inputs return themselves.
 */
export function afterimageComplement(input: Hct): Hct {
  const p = uvOfArgb(input.toInt());
  if (p === null) return input; // black: no chromaticity to fatigue against
  const [wu, wv] = whiteUvPoint;
  const du = wu - p[0], dv = wv - p[1]; // opposite direction; s=1 is full
  const slice = SliceCache.of(input.tone);
  const exit = slice.rayExit(du, dv);
  const result = exit === null
      ? Hct.from(0, 0, input.tone)
      // Clamp strength along the ray to just inside the boundary.
      : slice.nearest(
          wu + Math.min(1, exit[0] * 0.995) * du,
          wv + Math.min(1, exit[0] * 0.995) * dv);
  // Slice tone is quantized (0.5 steps); restore the exact input tone, and
  // re-express in the input's color model.
  const retoned = Hct.from(result.hue, result.chroma, input.tone);
  return Hct.fromInt(retoned.toInt(), input.colorModel);
}
