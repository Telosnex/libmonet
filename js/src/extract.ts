import {QuantizerCelebi} from './quantizer-celebi.js';
import {differenceDegrees, Hct, sanitizeDegreesDouble} from './hct.js';
import {TemperatureCache} from './temperature.js';
import {type Argb, asOpaqueArgb} from './color.js';

export interface QuantizerResult {
  argbToCount: Map<Argb, number>;
  inputPixelToClusterPixel?: Map<Argb, Argb>;
  lstarToCount?: Map<number, number>;
}

export interface SerializedQuantizerResult {
  argbToCount: Record<string, number>;
  inputPixelToClusterPixel?: Record<string, number>;
  lstarToCount?: Record<string, number>;
}

export function quantizerResultFromRecord(argbToCount: Record<string, number> | Map<Argb, number>): QuantizerResult {
  if (argbToCount instanceof Map) return {argbToCount};
  return {argbToCount: new Map(Object.entries(argbToCount).map(([k, v]) => [Number(k), v]))};
}

export function serializeQuantizerResult(result: QuantizerResult): SerializedQuantizerResult {
  return {argbToCount: Object.fromEntries(result.argbToCount)};
}

export function rgbaToArgb(rgba: number): Argb {
  const r = (rgba >> 0) & 0xff;
  const g = (rgba >> 8) & 0xff;
  const b = (rgba >> 16) & 0xff;
  const a = (rgba >> 24) & 0xff;
  return (((a << 24) | (r << 16) | (g << 8) | b) >>> 0);
}

export function argbPixelsFromImageData(imageData: ImageData): Argb[] {
  const pixels: Argb[] = [];
  const data = imageData.data;
  for (let i = 0; i < data.length; i += 4) {
    const a = data[i + 3]!;
    if (a !== 255) continue;
    pixels.push((0xff000000 | (data[i]! << 16) | (data[i + 1]! << 8) | data[i + 2]!) >>> 0);
  }
  return pixels;
}

export async function imageElementToScaledImageData(image: HTMLImageElement | HTMLCanvasElement | ImageBitmap, maxDimension = 96): Promise<ImageData> {
  const width = image.width;
  const height = image.height;
  const scale = Math.min(1, maxDimension / Math.max(width, height));
  const targetWidth = Math.max(1, Math.floor(width * scale));
  const targetHeight = Math.max(1, Math.floor(height * scale));
  const canvas = typeof OffscreenCanvas !== 'undefined'
    ? new OffscreenCanvas(targetWidth, targetHeight)
    : Object.assign(document.createElement('canvas'), {width: targetWidth, height: targetHeight});
  const ctx = canvas.getContext('2d', {willReadFrequently: true});
  if (!ctx) throw new Error('Could not get 2D canvas context');
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(image, 0, 0, targetWidth, targetHeight);
  return ctx.getImageData(0, 0, targetWidth, targetHeight);
}

export function quantizeArgbPixels(pixels: readonly Argb[], colorCount = 128): QuantizerResult {
  return QuantizerCelebi.quantize(Array.from(pixels, asOpaqueArgb), colorCount);
}

export async function quantizeImage(image: HTMLImageElement | HTMLCanvasElement | ImageBitmap, colorCount = 128, maxDimension = 96): Promise<QuantizerResult> {
  const data = await imageElementToScaledImageData(image, maxDimension);
  return quantizeArgbPixels(argbPixelsFromImageData(data), colorCount);
}

export interface ScorerOptions {
  toneTooLow?: number | null;
  toneTooHigh?: number | null;
  minChroma?: number;
}

const defaultMinChroma = 8;
const smearDistance = 7;

function hctKey(hct: Hct): number { return hct.toInt(); }

export class Scorer {
  readonly hcts: Hct[] = [];
  readonly hctToCount = new Map<number, number>();
  readonly hueToPercent = new Array<number>(361).fill(0);
  readonly primaryHueToPercent = new Array<number>(361).fill(0);
  readonly hueToSmearedPercent = new Array<number>(361).fill(0);
  readonly primaryHueToSmearedPercent = new Array<number>(361).fill(0);

  constructor(readonly quantizerResult: QuantizerResult, options: ScorerOptions = {}) {
    const toneTooLow = options.toneTooLow === undefined ? 10 : options.toneTooLow;
    const toneTooHigh = options.toneTooHigh === undefined ? 95 : options.toneTooHigh;
    const minChroma = options.minChroma ?? defaultMinChroma;
    if (quantizerResult.argbToCount.size === 0) return;

    const intermediate: Hct[] = [];
    for (const color of quantizerResult.argbToCount.keys()) {
      const hct = Hct.fromInt(color);
      this.hctToCount.set(hctKey(hct), quantizerResult.argbToCount.get(color)!);
      intermediate.push(hct);
    }

    const toneFilteredHcts = intermediate.filter(hct =>
      (toneTooLow === null || hct.tone >= toneTooLow) &&
      (toneTooHigh === null || hct.tone <= toneTooHigh),
    );
    const filteredHcts = toneFilteredHcts.filter(hct => hct.chroma >= minChroma);
    this.hcts.push(...filteredHcts);

    let totalCount = 0;
    for (const count of quantizerResult.argbToCount.values()) totalCount += count;
    const colorToPercent = new Map<Argb, number>();
    for (const [key, value] of quantizerResult.argbToCount) colorToPercent.set(key, value / totalCount);

    for (const hct of filteredHcts) {
      const hue = Math.round(hct.hue);
      this.hueToPercent[hue]! += colorToPercent.get(hct.toInt()) ?? 0;
    }
    for (const hct of toneFilteredHcts) {
      const hue = Math.round(hct.hue);
      this.primaryHueToPercent[hue]! += colorToPercent.get(hct.toInt()) ?? 0;
    }

    Scorer.smearHuePercentages(this.hueToPercent, this.hueToSmearedPercent, smearDistance);
    Scorer.smearHuePercentages(this.primaryHueToPercent, this.primaryHueToSmearedPercent, smearDistance);
  }

  static smearHuePercentages(source: readonly number[], target: number[], distance: number): void {
    for (let i = 0; i < 361; i++) {
      const percentage = source[i]!;
      if (percentage === 0) continue;
      target[i]! += percentage;
      for (let offset = 1; offset < distance; offset += 1) {
        target[Math.round(sanitizeDegreesDouble(i + offset))]! += percentage;
        target[Math.round(sanitizeDegreesDouble(i - offset))]! += percentage;
      }
    }
  }

  static createHueToPercentage(hcts: readonly Hct[], hueToPercent: readonly number[], distance: number): number[] {
    const out = new Array<number>(361).fill(0);
    for (const hct of hcts) {
      const hue = Math.round(hct.hue);
      const count = hueToPercent[hue]!;
      out[hue]! += count;
      for (let i = 1; i < distance; i += 1) {
        out[Math.round(sanitizeDegreesDouble(hct.hue + i))]! += count;
        out[Math.round(sanitizeDegreesDouble(hct.hue - i))]! += count;
      }
    }
    return out;
  }

  averagedHctNearHue({hue, backupTone}: {hue: number; backupTone: number}): Hct {
    const hctsNearHue = this.hcts.filter(hct => differenceDegrees(hct.hue, hue) < 15);
    let totalCount = 0, chromaSum = 0, toneSum = 0;
    for (const hct of hctsNearHue) {
      const count = this.hctToCount.get(hctKey(hct)) ?? 0;
      totalCount += count;
      chromaSum += count * hct.chroma;
      toneSum += count * hct.tone;
    }
    if (totalCount === 0) return Hct.from(hue, 8, backupTone);
    return Hct.from(hue, chromaSum / totalCount, toneSum / totalCount);
  }

  topHctNearHue({hue, backupTone}: {hue: number; backupTone: number}): Hct {
    return this.topHctNearHueFrom(this.hcts, {hue, backupTone});
  }

  topHctNearHueFrom(candidates: Iterable<Hct>, {hue, backupTone}: {hue: number; backupTone: number}): Hct {
    const near = Array.from(candidates).filter(hct => differenceDegrees(hct.hue, hue) < 15);
    if (!near.length) return Hct.from(hue, 8, backupTone);
    return near.reduce((a, b) => (this.hctToCount.get(hctKey(a)) ?? 0) > (this.hctToCount.get(hctKey(b)) ?? 0) ? a : b);
  }

  huePercent(hue: number): number { return this.hueToPercent[hue]!; }
  primaryHuePercent(hue: number): number { return this.primaryHueToPercent[hue]!; }
}

export interface ScorerTriadOptions extends ScorerOptions {
  primaryIsAverageOfNearby?: boolean;
  ensureClosestPairPrimary?: boolean;
}

function indexOfMax(xs: readonly number[]): number {
  let idx = 0, best = Number.NEGATIVE_INFINITY;
  for (let i = 0; i < xs.length; i++) if (xs[i]! > best) { best = xs[i]!; idx = i; }
  return idx;
}

function farthestFromPrimary(candidates: readonly Hct[], primary: Hct): Hct | undefined {
  return candidates.reduce<Hct | undefined>((best, contender) => {
    if (!best) return contender;
    return differenceDegrees(contender.hue, primary.hue) > differenceDegrees(best.hue, primary.hue) ? contender : best;
  }, undefined);
}

function farthestFromPrimaryAndSecondary(candidates: readonly Hct[], primary: Hct, secondary: Hct): Hct | undefined {
  return candidates.reduce<Hct | undefined>((best, contender) => {
    if (!best) return contender;
    const bestDistance = Math.min(differenceDegrees(best.hue, primary.hue), differenceDegrees(best.hue, secondary.hue));
    const contenderDistance = Math.min(differenceDegrees(contender.hue, primary.hue), differenceDegrees(contender.hue, secondary.hue));
    return contenderDistance > bestDistance ? contender : best;
  }, undefined);
}

function selectSecondaryCandidates(candidates: readonly Hct[], primary: Hct): Hct[] {
  const preferred = candidates.filter(hct => differenceDegrees(hct.hue, primary.hue) >= 30);
  if (preferred.length) return preferred;
  const relaxed = candidates.filter(hct => differenceDegrees(hct.hue, primary.hue) >= 15);
  if (relaxed.length) return relaxed;
  const farthest = farthestFromPrimary(candidates, primary);
  return farthest ? [farthest] : [];
}

function selectTertiaryCandidates(candidates: readonly Hct[], primary: Hct, secondary: Hct): Hct[] {
  for (const threshold of [45, 30, 15]) {
    const matching = candidates.filter(hct => differenceDegrees(hct.hue, primary.hue) >= threshold && differenceDegrees(hct.hue, secondary.hue) >= threshold);
    if (matching.length) return matching;
  }
  const farthest = farthestFromPrimaryAndSecondary(candidates, primary, secondary);
  return farthest ? [farthest] : [];
}

function ensureClosestPairPrimary(candidates: [Hct, Hct, Hct]): [Hct, Hct, Hct] {
  const primarySecondaryDistance = differenceDegrees(candidates[0].hue, candidates[1].hue);
  const tertiaryPrimaryDistance = differenceDegrees(candidates[2].hue, candidates[0].hue);
  return primarySecondaryDistance <= tertiaryPrimaryDistance ? candidates : [candidates[0], candidates[2], candidates[1]];
}

export class ScorerTriad {
  static threeColorsFromQuantizer(result: QuantizerResult, options: ScorerTriadOptions = {}): Hct[] {
    if (result.argbToCount.size === 0) return [];
    const toneTooLow = options.toneTooLow === undefined ? 10 : options.toneTooLow;
    const toneTooHigh = options.toneTooHigh === undefined ? 95 : options.toneTooHigh;
    const scorer = new Scorer(result, options);

    const colorKeys = Array.from(result.argbToCount.keys()).sort((a, b) => result.argbToCount.get(b)! - result.argbToCount.get(a)!);
    const topFilteredColor = colorKeys.reduce((incumbentKey, contenderKey) => {
      const incumbentHct = Hct.fromInt(incumbentKey);
      const contenderHct = Hct.fromInt(contenderKey);
      if (toneTooLow !== null && contenderHct.tone <= toneTooLow) return incumbentKey;
      if (toneTooHigh !== null && contenderHct.tone >= toneTooHigh) return incumbentKey;
      return scorer.primaryHuePercent(Math.round(contenderHct.hue)) > scorer.primaryHuePercent(Math.round(incumbentHct.hue)) ? contenderKey : incumbentKey;
    });
    const backupHct = Hct.fromInt(topFilteredColor);

    let primary: Hct;
    if (scorer.hcts.length === 0) {
      primary = Hct.from(backupHct.hue, backupHct.chroma, backupHct.tone);
    } else {
      const topPrimaryHue = indexOfMax(scorer.primaryHueToSmearedPercent);
      primary = options.primaryIsAverageOfNearby
        ? scorer.averagedHctNearHue({hue: topPrimaryHue, backupTone: backupHct.tone})
        : scorer.topHctNearHue({hue: topPrimaryHue, backupTone: backupHct.tone});
      primary = Hct.from(topPrimaryHue, primary.chroma, primary.tone);
    }

    let secondary: Hct;
    if (scorer.hcts.length === 0) {
      secondary = Hct.from(new TemperatureCache(primary).analogous(5, 12)[1]!.hue, backupHct.chroma, backupHct.tone);
    } else {
      const pool = selectSecondaryCandidates(scorer.hcts, primary);
      if (!pool.length) {
        secondary = Hct.from(new TemperatureCache(primary).analogous(5, 12)[1]!.hue, backupHct.chroma, backupHct.tone);
      } else {
        const topHue = indexOfMax(Scorer.createHueToPercentage(pool, scorer.hueToPercent, 0));
        const representative = scorer.topHctNearHueFrom(pool, {hue: topHue, backupTone: backupHct.tone});
        secondary = Hct.from(topHue, representative.chroma, representative.tone);
      }
    }

    let tertiary: Hct;
    if (scorer.hcts.length === 0) {
      tertiary = Hct.from(new TemperatureCache(primary).analogous(5, 12)[3]!.hue, backupHct.chroma, backupHct.tone);
    } else {
      const pool = selectTertiaryCandidates(scorer.hcts, primary, secondary);
      if (!pool.length) {
        tertiary = Hct.from(new TemperatureCache(primary).analogous(5, 12)[3]!.hue, backupHct.chroma, backupHct.tone);
      } else {
        const topHue = indexOfMax(Scorer.createHueToPercentage(pool, scorer.hueToPercent, 0));
        const representative = scorer.topHctNearHueFrom(pool, {hue: topHue, backupTone: backupHct.tone});
        tertiary = Hct.from(topHue, representative.chroma, representative.tone);
      }
    }

    const triad: [Hct, Hct, Hct] = [primary, secondary, tertiary];
    return options.ensureClosestPairPrimary === false ? triad : ensureClosestPairPrimary(triad);
  }
}
