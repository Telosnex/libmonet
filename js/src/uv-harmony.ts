import {SliceCache, uvOfArgb, whiteUvPoint} from './afterimage.js';
import {Hct, type ColorModel} from './hct.js';

/** Direction of color's chromaticity from the white point, in degrees. */
export function uvHue(color: Hct): number {
  const p = uvOfArgb(color.toInt());
  if (p === null) return 0;
  const [wu, wv] = whiteUvPoint;
  return ((Math.atan2(p[1] - wv, p[0] - wu) * 180 / Math.PI) % 360 + 360) % 360;
}

/** Distance of color's chromaticity from the white point in u'v'. */
export function uvChroma(color: Hct): number {
  const p = uvOfArgb(color.toInt());
  if (p === null) return 0;
  const [wu, wv] = whiteUvPoint;
  const du = p[0] - wu, dv = p[1] - wv;
  return Math.sqrt(du * du + dv * dv);
}

/** Color at tone whose chromaticity is uvChroma from white at uvHue. */
export function hctFromUv(
  tone: number,
  hue: number,
  chroma: number,
  model?: ColorModel,
): Hct {
  const [wu, wv] = whiteUvPoint;
  const radians = hue * Math.PI / 180;
  const slice = SliceCache.of(tone);
  const result = slice.nearest(
      wu + chroma * Math.cos(radians),
      wv + chroma * Math.sin(radians));
  const retoned = Hct.from(result.hue, result.chroma, Math.min(100, Math.max(0, tone)));
  return Hct.fromInt(retoned.toInt(), model);
}

function rotated(
  input: Hct,
  slice: SliceCache,
  offset: [number, number],
  degrees: number,
  sharedStrength: number,
): Hct {
  const [wu, wv] = whiteUvPoint;
  const radians = degrees * Math.PI / 180;
  const cos = Math.cos(radians), sin = Math.sin(radians);
  const du = offset[0] * cos - offset[1] * sin;
  const dv = offset[0] * sin + offset[1] * cos;
  const exit = slice.rayExit(du, dv);
  if (exit === null) return Hct.from(0, 0, input.tone);
  const s = Math.min(sharedStrength, exit[0] * 0.995);
  const result = slice.nearest(wu + s * du, wv + s * dv);
  const retoned = Hct.from(result.hue, result.chroma, input.tone);
  return Hct.fromInt(retoned.toInt(), input.colorModel);
}

/**
 * n evenly-spaced chromatic directions including x. n=2 is complement,
 * n=3 triad, n=4 quad. The set can mix to neutral gray.
 */
export function harmony(x: Hct, n: number, options: {balanced?: boolean} = {}): Hct[] {
  if (n < 2) throw new Error('harmony needs at least 2 colors');
  const p = uvOfArgb(x.toInt());
  if (p === null || x.chroma < 1e-4) return Array.from({length: n}, () => x);
  const [wu, wv] = whiteUvPoint;
  const offset: [number, number] = [p[0] - wu, p[1] - wv];
  const slice = SliceCache.of(x.tone);
  const angles = Array.from({length: n}, (_, i) => i * 360 / n);
  let shared = 1;
  if (options.balanced === true) {
    for (const a of angles) {
      const radians = a * Math.PI / 180;
      const du = offset[0] * Math.cos(radians) - offset[1] * Math.sin(radians);
      const dv = offset[0] * Math.sin(radians) + offset[1] * Math.cos(radians);
      const exit = slice.rayExit(du, dv);
      if (exit !== null) shared = Math.min(shared, exit[0] * 0.995);
    }
  }
  return angles.map((a) => (a === 0 && options.balanced !== true) ? x : rotated(x, slice, offset, a, shared));
}

/** Small neighboring steps around x in u'v' direction. */
export function analogous(x: Hct, options: {count?: number, step?: number} = {}): Hct[] {
  const count = options.count ?? 5;
  const step = options.step ?? 30;
  if (count < 1) throw new Error('analogous needs at least 1 color');
  const p = uvOfArgb(x.toInt());
  if (p === null || x.chroma < 1e-4) return Array.from({length: count}, () => x);
  const [wu, wv] = whiteUvPoint;
  const offset: [number, number] = [p[0] - wu, p[1] - wv];
  const slice = SliceCache.of(x.tone);
  return Array.from({length: count}, (_, i) => {
    if (i * 2 === count - 1) return x;
    return rotated(x, slice, offset, (i - (count - 1) / 2) * step, 1);
  });
}
