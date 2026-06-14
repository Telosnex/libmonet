import {type Argb} from './color.js';
import {Algo} from './contrast.js';
import {getOpacityForArgbs} from './opacity.js';
import {argbFromLstar, lumaFromArgb} from './luma.js';
import {lstarFromArgb} from './hct.js';

export class ShadowResult {
  constructor(
    readonly blurRadius: number,
    readonly shadowArgb: Argb,
    readonly opacities: number[],
  ) {}
}

export interface ShadowForArgbsOptions {
  foregroundArgb: Argb;
  minBackgroundArgb: Argb;
  maxBackgroundArgb: Argb;
  contrast: number;
  algo: Algo;
  blurRadius: number;
  contentRadius?: number;
}

export function numApplications(finalBg: number, fg: number, bg: number, opacity: number): number {
  return Math.log((finalBg - fg) / (bg - fg)) / Math.log(1.0 - opacity);
}

export function gauss1d(x: number, sigma: number): number {
  return (1 / (sigma * Math.sqrt(2 * Math.PI))) * Math.exp(-(x * x) / (2 * sigma * sigma));
}

// See SkBlurMask::ConvertRadiusToSigma().
export function convertRadiusToSigma(radius: number): number {
  return radius > 0 ? radius * 0.57735 + 0.5 : 0;
}

export function getShadowOpacitiesForArgbs(opts: ShadowForArgbsOptions): ShadowResult {
  const contentRadius = opts.contentRadius === undefined || opts.contentRadius <= 0 ? opts.blurRadius : opts.contentRadius;
  const opacityResult = getOpacityForArgbs({
    foregroundArgb: opts.foregroundArgb,
    minBackgroundArgb: opts.minBackgroundArgb,
    maxBackgroundArgb: opts.maxBackgroundArgb,
    contrast: opts.contrast,
    algo: opts.algo,
  });
  const requiredOpacity = opacityResult.opacity;

  if (requiredOpacity === 0) return new ShadowResult(0, 0xff000000, []);
  if (Math.round(opts.blurRadius) === 0) return new ShadowResult(0, 0xff000000, []);

  const sigma = convertRadiusToSigma(opts.blurRadius);
  const gaussians = Array.from({length: Math.round(opts.blurRadius) * 2 + 1}, (_, index) => {
    const i = index - opts.blurRadius;
    return gauss1d(i, sigma);
  });
  const total = gaussians.reduce((a, b) => a + b, 0);
  const normalizedGaussians = gaussians.map(e => e / total);
  const effectiveOpacity = normalizedGaussians.slice(0, Math.round(contentRadius)).reduce((a, b) => a + b, 0);

  if (effectiveOpacity >= requiredOpacity) {
    return new ShadowResult(opts.blurRadius, opacityResult.protectionArgb, [requiredOpacity / effectiveOpacity]);
  }

  let netOpacity = effectiveOpacity;
  const allOpacities = [1.0];
  let turns = 0;
  while (netOpacity < requiredOpacity) {
    turns++;
    const gap = requiredOpacity - netOpacity;
    if (gap < 0.004) break;

    const currentEffectiveOpacity = effectiveOpacity * allOpacities.reduce((a, b) => a * b, 1);
    if (currentEffectiveOpacity < 1e-10 || netOpacity >= 1.0 - 1e-10) break;

    const targetOpacity = 1 - (1 - requiredOpacity) / (1 - netOpacity);
    const nextOpacity = Math.min(targetOpacity / currentEffectiveOpacity, 1.0);
    if (!Number.isFinite(nextOpacity) || nextOpacity <= 0) break;

    netOpacity += (1.0 - netOpacity) * nextOpacity * effectiveOpacity;
    allOpacities.push(nextOpacity);
    if (turns === 10) break;
  }

  const minBgLuma = lumaFromArgb(opts.minBackgroundArgb);
  const maxBgLuma = lumaFromArgb(opts.maxBackgroundArgb);
  const protectionLuma = lumaFromArgb(opacityResult.protectionArgb);
  const targetLuma = lumaFromArgb(argbFromLstar(opacityResult.targetLstar));
  void numApplications(
    targetLuma,
    protectionLuma,
    opacityResult.protectionLstar > lstarFromArgb(opts.minBackgroundArgb) ? minBgLuma : maxBgLuma,
    effectiveOpacity,
  );

  return new ShadowResult(opts.blurRadius, opacityResult.protectionArgb, allOpacities);
}

export function getShadowOpacitiesForColors(opts: {foreground: Argb; background: Argb; contrast: number; algo: Algo; blurRadius: number; contentRadius?: number}): ShadowResult {
  return getShadowOpacitiesForArgbs({
    foregroundArgb: opts.foreground,
    minBackgroundArgb: opts.background,
    maxBackgroundArgb: opts.background,
    contrast: opts.contrast,
    algo: opts.algo,
    blurRadius: opts.blurRadius,
    ...(opts.contentRadius === undefined ? {} : {contentRadius: opts.contentRadius}),
  });
}

export function getShadowOpacitiesForBackgrounds(opts: {foreground: Argb; backgrounds: Iterable<Argb>; contrast: number; algo: Algo; blurRadius: number; contentRadius?: number}): ShadowResult {
  let minLumaArgb: Argb | undefined;
  let maxLumaArgb: Argb | undefined;
  let minLuma: number | undefined;
  let maxLuma: number | undefined;
  for (const bg of opts.backgrounds) {
    const luma = lumaFromArgb(bg);
    if (minLuma === undefined || luma < minLuma) { minLuma = luma; minLumaArgb = bg; }
    if (maxLuma === undefined || luma > maxLuma) { maxLuma = luma; maxLumaArgb = bg; }
  }
  if (minLumaArgb === undefined || maxLumaArgb === undefined) throw new Error('backgrounds cannot be empty');
  return getShadowOpacitiesForArgbs({
    foregroundArgb: opts.foreground,
    minBackgroundArgb: minLumaArgb,
    maxBackgroundArgb: maxLumaArgb,
    contrast: opts.contrast,
    algo: opts.algo,
    blurRadius: opts.blurRadius,
    ...(opts.contentRadius === undefined ? {} : {contentRadius: opts.contentRadius}),
  });
}

export function getShadowOpacities(opts: {minBgLstar: number; maxBgLstar: number; foregroundLstar: number; contrast: number; algo: Algo; blurRadius: number; contentRadius?: number}): ShadowResult {
  return getShadowOpacitiesForArgbs({
    foregroundArgb: argbFromLstar(opts.foregroundLstar),
    minBackgroundArgb: argbFromLstar(opts.minBgLstar),
    maxBackgroundArgb: argbFromLstar(opts.maxBgLstar),
    contrast: opts.contrast,
    algo: opts.algo,
    blurRadius: opts.blurRadius,
    ...(opts.contentRadius === undefined ? {} : {contentRadius: opts.contentRadius}),
  });
}
