import {SliceCache, uvOfArgb, whiteUvPoint} from './afterimage.js';
import {argbFromXyz, Hct, lstarFromY, sanitizeDegreesDouble, type ColorModel, yFromLstar} from './hct.js';

/** How harmony colors choose rendered tone after u'v' direction is chosen. */
export type HarmonyTonePolicy = 'preserveTone' | 'reflectTone' | 'fitUvChroma' | 'fitHctChroma';

/** Direction of color's chromaticity from the white point, in degrees. */
export function uvHue(color: Hct): number {
  const p = uvOfArgb(color.toInt());
  if (p === null) return 0;
  const [wu, wv] = whiteUvPoint;
  return sanitizeDegreesDouble(Math.atan2(p[1] - wv, p[0] - wu) * 180 / Math.PI);
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

const xyzToSrgb = [
  [3.2413774792388685, -1.5376652402851851, -0.49885366846268053],
  [-0.9691452513005321, 1.8758853451067872, 0.04156585616912061],
  [0.05562093689691305, -0.20395524564742123, 1.0571799111220335],
] as const;

function rotateOffset(offset: [number, number], degrees: number): [number, number] {
  const radians = degrees * Math.PI / 180;
  const cos = Math.cos(radians), sin = Math.sin(radians);
  return [offset[0] * cos - offset[1] * sin, offset[0] * sin + offset[1] * cos];
}

function xyzFromUvTone(u: number, v: number, tone: number): [number, number, number] | null {
  if (Math.abs(v) < 1e-9) return null;
  const y = yFromLstar(Math.min(100, Math.max(0, tone)));
  const x = 9 * u * y / (4 * v);
  const z = y * (12 - 3 * u - 20 * v) / (4 * v);
  return [x, y, z];
}

function linearRgbForUvTone(u: number, v: number, tone: number): [number, number, number] | null {
  const xyz = xyzFromUvTone(u, v, tone);
  if (xyz === null) return null;
  const [x, y, z] = xyz;
  return [
    xyzToSrgb[0][0] * x + xyzToSrgb[0][1] * y + xyzToSrgb[0][2] * z,
    xyzToSrgb[1][0] * x + xyzToSrgb[1][1] * y + xyzToSrgb[1][2] * z,
    xyzToSrgb[2][0] * x + xyzToSrgb[2][1] * y + xyzToSrgb[2][2] * z,
  ];
}

function uvToneInSrgb(u: number, v: number, tone: number): boolean {
  const rgb = linearRgbForUvTone(u, v, tone);
  if (rgb === null) return false;
  const epsilon = 1e-7;
  return rgb[0] >= -epsilon && rgb[1] >= -epsilon && rgb[2] >= -epsilon &&
      rgb[0] <= 100 + epsilon && rgb[1] <= 100 + epsilon && rgb[2] <= 100 + epsilon;
}

function fitToneForUv(u: number, v: number, preferredTone: number): number | null {
  if (Math.abs(v) < 1e-9) return null;
  const xPerY = 9 * u / (4 * v);
  const zPerY = (12 - 3 * u - 20 * v) / (4 * v);
  const rPerY = xyzToSrgb[0][0] * xPerY + xyzToSrgb[0][1] + xyzToSrgb[0][2] * zPerY;
  const gPerY = xyzToSrgb[1][0] * xPerY + xyzToSrgb[1][1] + xyzToSrgb[1][2] * zPerY;
  const bPerY = xyzToSrgb[2][0] * xPerY + xyzToSrgb[2][1] + xyzToSrgb[2][2] * zPerY;
  const epsilon = 1e-9;
  if (rPerY < -epsilon || gPerY < -epsilon || bPerY < -epsilon) return null;
  let maxY = 100;
  for (const c of [rPerY, gPerY, bPerY]) {
    if (c > epsilon) maxY = Math.min(maxY, 100 / c);
  }
  const maxTone = lstarFromY(Math.min(100, Math.max(0, maxY)));
  return Math.min(Math.min(100, Math.max(0, preferredTone)), maxTone);
}

function exactUvAtTone(u: number, v: number, tone: number, model?: ColorModel): Hct {
  const xyz = xyzFromUvTone(u, v, tone);
  if (xyz === null) return Hct.from(0, 0, tone, model);
  return Hct.fromInt(argbFromXyz(xyz[0], xyz[1], xyz[2]), model);
}

function targetTone(input: Hct, degrees: number, tonePolicy: HarmonyTonePolicy, u: number, v: number): number {
  if (Math.abs(degrees) < 1e-9 || Math.abs(degrees % 360) < 1e-9) return input.tone;
  switch (tonePolicy) {
    case 'preserveTone': return input.tone;
    case 'reflectTone': return 100 - input.tone;
    case 'fitUvChroma': return fitToneForUv(u, v, input.tone) ?? input.tone;
    case 'fitHctChroma': return input.tone;
  }
}

function rayColorAtScale(tone: number, du: number, dv: number, scale: number, model?: ColorModel): Hct {
  const [wu, wv] = whiteUvPoint;
  const result = SliceCache.of(tone).nearest(wu + scale * du, wv + scale * dv);
  const retoned = Hct.from(result.hue, result.chroma, tone);
  return Hct.fromInt(retoned.toInt(), model);
}

function hctHueFromUvTarget(tone: number, du: number, dv: number, model?: ColorModel): number {
  const exit = SliceCache.of(tone).rayExit(du, dv);
  if (exit === null) return 0;
  return rayColorAtScale(tone, du, dv, Math.min(1, exit[0] * 0.995), model).hue;
}

function isBetterHctChromaFit(candidate: Hct, best: Hct | null, input: Hct): boolean {
  if (best === null) return true;
  const chromaDiff = Math.abs(candidate.chroma - input.chroma);
  const bestChromaDiff = Math.abs(best.chroma - input.chroma);
  if (chromaDiff < bestChromaDiff - 1e-9) return true;
  if (Math.abs(chromaDiff - bestChromaDiff) > 1e-9) return false;
  return Math.abs(candidate.tone - input.tone) < Math.abs(best.tone - input.tone);
}

function fitHctChromaFromUvHue(input: Hct, du: number, dv: number): Hct {
  const targetHue = hctHueFromUvTarget(input.tone, du, dv, input.colorModel);
  let best: Hct | null = null;
  const visit = (tone: number): void => {
    const candidate = Hct.from(targetHue, input.chroma, Math.min(100, Math.max(0, tone)), input.colorModel);
    if (isBetterHctChromaFit(candidate, best, input)) best = candidate;
  };

  for (let tone = 0; tone <= 100; tone += 0.5) visit(tone);
  const coarse = best!.tone;
  for (let tone = coarse - 0.5; tone <= coarse + 0.5; tone += 0.05) visit(tone);
  return best!;
}

function rotated(
  input: Hct,
  offset: [number, number],
  degrees: number,
  sharedStrength: number,
  tonePolicy: HarmonyTonePolicy,
): Hct {
  const [wu, wv] = whiteUvPoint;
  const [rdu, rdv] = rotateOffset(offset, degrees);
  const du = rdu * sharedStrength, dv = rdv * sharedStrength;
  const targetU = wu + du, targetV = wv + dv;
  const tone = targetTone(input, degrees, tonePolicy, targetU, targetV);

  if (tonePolicy === 'fitUvChroma' && uvToneInSrgb(targetU, targetV, tone)) {
    return exactUvAtTone(targetU, targetV, tone, input.colorModel);
  }

  if (tonePolicy === 'fitHctChroma') {
    return fitHctChromaFromUvHue(input, du, dv);
  }

  const slice = SliceCache.of(tone);
  const exit = slice.rayExit(du, dv);
  if (exit === null) return Hct.from(0, 0, tone);
  const s = Math.min(1, exit[0] * 0.995);
  const result = slice.nearest(wu + s * du, wv + s * dv);
  const retoned = Hct.from(result.hue, result.chroma, tone);
  return Hct.fromInt(retoned.toInt(), input.colorModel);
}

/**
 * n evenly-spaced chromatic directions including x. n=2 is complement,
 * n=3 triad, n=4 quad. The set can mix to neutral gray.
 */
export function harmony(
  x: Hct,
  n: number,
  options: {balanced?: boolean, tonePolicy?: HarmonyTonePolicy} = {},
): Hct[] {
  if (n < 2) throw new Error('harmony needs at least 2 colors');
  const tonePolicy = options.tonePolicy ?? 'preserveTone';
  const p = uvOfArgb(x.toInt());
  if (p === null || x.chroma < 1e-4) return Array.from({length: n}, () => x);
  const [wu, wv] = whiteUvPoint;
  const offset: [number, number] = [p[0] - wu, p[1] - wv];
  const angles = Array.from({length: n}, (_, i) => i * 360 / n);
  let shared = 1;
  if (options.balanced === true) {
    for (const a of angles) {
      const [du, dv] = rotateOffset(offset, a);
      const tone = targetTone(x, a, tonePolicy, wu + du, wv + dv);
      const exit = SliceCache.of(tone).rayExit(du, dv);
      if (exit !== null) shared = Math.min(shared, exit[0] * 0.995);
    }
  }
  return angles.map((a) => (a === 0 && options.balanced !== true) ? x : rotated(x, offset, a, shared, tonePolicy));
}

/** Small neighboring steps around x in u'v' direction. */
export function analogous(
  x: Hct,
  options: {count?: number, step?: number, tonePolicy?: HarmonyTonePolicy} = {},
): Hct[] {
  const count = options.count ?? 5;
  const step = options.step ?? 30;
  const tonePolicy = options.tonePolicy ?? 'preserveTone';
  if (count < 1) throw new Error('analogous needs at least 1 color');
  const p = uvOfArgb(x.toInt());
  if (p === null || x.chroma < 1e-4) return Array.from({length: count}, () => x);
  const [wu, wv] = whiteUvPoint;
  const offset: [number, number] = [p[0] - wu, p[1] - wv];
  return Array.from({length: count}, (_, i) => {
    if (i * 2 === count - 1) return x;
    return rotated(x, offset, (i - (count - 1) / 2) * step, 1, tonePolicy);
  });
}
