import {type Argb, alphaFromArgb, argbFromRgb, blueFromArgb, greenFromArgb, redFromArgb} from './color.js';
import {
  Algo,
  Usage,
  contrastBetweenArgbs,
  darkerBackgroundLstar,
  darkerLstarUnsafe,
  getAbsoluteContrast,
  lighterBackgroundLstar,
  lighterLstarUnsafe,
} from './contrast.js';
import {argbFromLstar, lumaFromArgb} from './luma.js';
import {lstarFromArgb} from './hct.js';

const white = 0xffffffff;
const black = 0xff000000;

export class OpacityResult {
  constructor(
    readonly protectionArgb: Argb,
    readonly opacity: number,
    readonly targetLstar: number,
  ) {}

  get needsProtection(): boolean { return this.opacity > 0; }
  get protectionLstar(): number { return lstarFromArgb(this.protectionArgb); }
  get protectionLuma(): number { return lumaFromArgb(this.protectionArgb); }

  get color(): Argb {
    const alpha = Math.round(this.opacity * 255);
    return (((alpha & 0xff) << 24) | (this.protectionArgb & 0x00ffffff)) >>> 0;
  }
}

export interface OpacityForArgbsOptions {
  foregroundArgb: Argb;
  minBackgroundArgb: Argb;
  maxBackgroundArgb: Argb;
  contrast: number;
  algo: Algo;
}

function alphaBlend(foreground: Argb, background: Argb): Argb {
  const fa = alphaFromArgb(foreground) / 255;
  const ba = alphaFromArgb(background) / 255;
  const outA = fa + ba * (1 - fa);
  if (outA <= 0) return 0;
  const blend = (fg: number, bg: number) => Math.round((fg * fa + bg * ba * (1 - fa)) / outA);
  const alpha = Math.round(outA * 255);
  return (((alpha & 0xff) << 24) | (blend(redFromArgb(foreground), redFromArgb(background)) << 16) | (blend(greenFromArgb(foreground), greenFromArgb(background)) << 8) | blend(blueFromArgb(foreground), blueFromArgb(background))) >>> 0;
}

function lighterTargetLstar(foregroundLstar: number, contrast: number, algo: Algo): number {
  return algo === Algo.wcag21 ? lighterLstarUnsafe(foregroundLstar, contrast) : lighterBackgroundLstar(foregroundLstar, contrast);
}

function darkerTargetLstar(foregroundLstar: number, contrast: number, algo: Algo): number {
  return algo === Algo.wcag21 ? darkerLstarUnsafe(foregroundLstar, contrast) : darkerBackgroundLstar(foregroundLstar, contrast);
}

function calculateProtection(opts: {
  protectionArgb: Argb;
  backgroundArgb: Argb;
  foregroundLstar: number;
  absoluteContrast: number;
  algo: Algo;
  lightenBackground: boolean;
}): OpacityResult | undefined {
  const targetLstar = opts.lightenBackground
    ? lighterTargetLstar(opts.foregroundLstar, opts.absoluteContrast, opts.algo)
    : darkerTargetLstar(opts.foregroundLstar, opts.absoluteContrast, opts.algo);

  if (!Number.isFinite(targetLstar)) return undefined;

  const targetLuma = lumaFromArgb(argbFromLstar(targetLstar));
  const protectionLuma = lumaFromArgb(opts.protectionArgb);
  const backgroundLuma = lumaFromArgb(opts.backgroundArgb);
  const denominator = protectionLuma - backgroundLuma;
  if (Math.abs(denominator) < 1e-10) return undefined;

  const rawOpacity = (targetLuma - backgroundLuma) / denominator;
  if (!Number.isFinite(rawOpacity) || rawOpacity < 0) return undefined;

  const opacity = Math.ceil((rawOpacity + 0.01) * 100) / 100;
  if (opacity > 1) return undefined;
  return new OpacityResult(opts.protectionArgb, opacity, targetLstar);
}

function protectionWorksBothSides(opts: {
  prot: OpacityResult;
  foregroundArgb: Argb;
  minBackgroundArgb: Argb;
  maxBackgroundArgb: Argb;
  absoluteContrast: number;
  algo: Algo;
}): boolean {
  const minBlended = alphaBlend(opts.prot.color, opts.minBackgroundArgb);
  const maxBlended = alphaBlend(opts.prot.color, opts.maxBackgroundArgb);
  return Math.abs(contrastBetweenArgbs(opts.algo, minBlended, opts.foregroundArgb)) >= opts.absoluteContrast &&
    Math.abs(contrastBetweenArgbs(opts.algo, maxBlended, opts.foregroundArgb)) >= opts.absoluteContrast;
}

function bestEffortFullOpacity(opts: {
  foregroundArgb: Argb;
  absoluteContrast: number;
  algo: Algo;
}): OpacityResult {
  const whiteContrast = Math.abs(contrastBetweenArgbs(opts.algo, white, opts.foregroundArgb));
  const blackContrast = Math.abs(contrastBetweenArgbs(opts.algo, black, opts.foregroundArgb));
  const useWhite = whiteContrast >= blackContrast;
  void opts.absoluteContrast;
  return new OpacityResult(useWhite ? white : black, 1, useWhite ? 100 : 0);
}

function chooseBestProtection(opts: {
  whiteProt?: OpacityResult;
  blackProt?: OpacityResult;
  foregroundArgb: Argb;
  minBackgroundArgb: Argb;
  maxBackgroundArgb: Argb;
  foregroundLstar: number;
  absoluteContrast: number;
  algo: Algo;
}): OpacityResult {
  const works = (prot: OpacityResult | undefined) => prot !== undefined && protectionWorksBothSides({...opts, prot});
  const whiteValid = works(opts.whiteProt);
  const blackValid = works(opts.blackProt);
  if (whiteValid && blackValid) return opts.whiteProt!.opacity <= opts.blackProt!.opacity ? opts.whiteProt! : opts.blackProt!;
  if (whiteValid) return opts.whiteProt!;
  if (blackValid) return opts.blackProt!;

  const blackOnMin = calculateProtection({
    protectionArgb: black,
    backgroundArgb: opts.minBackgroundArgb,
    foregroundLstar: opts.foregroundLstar,
    absoluteContrast: opts.absoluteContrast,
    algo: opts.algo,
    lightenBackground: false,
  });
  const whiteOnMax = calculateProtection({
    protectionArgb: white,
    backgroundArgb: opts.maxBackgroundArgb,
    foregroundLstar: opts.foregroundLstar,
    absoluteContrast: opts.absoluteContrast,
    algo: opts.algo,
    lightenBackground: true,
  });
  const blackOnMinValid = works(blackOnMin);
  const whiteOnMaxValid = works(whiteOnMax);
  if (blackOnMinValid && whiteOnMaxValid) return blackOnMin!.opacity <= whiteOnMax!.opacity ? blackOnMin! : whiteOnMax!;
  if (blackOnMinValid) return blackOnMin!;
  if (whiteOnMaxValid) return whiteOnMax!;
  return bestEffortFullOpacity(opts);
}

export function getOpacityForArgbs(opts: OpacityForArgbsOptions): OpacityResult {
  const absoluteContrast = getAbsoluteContrast(opts.algo, opts.contrast, Usage.text);
  const foregroundLstar = lstarFromArgb(opts.foregroundArgb);
  const contrastWithMin = contrastBetweenArgbs(opts.algo, opts.minBackgroundArgb, opts.foregroundArgb);
  const contrastWithMax = contrastBetweenArgbs(opts.algo, opts.maxBackgroundArgb, opts.foregroundArgb);
  if (absoluteContrast <= contrastWithMin && absoluteContrast <= contrastWithMax) {
    return new OpacityResult(opts.foregroundArgb, 0, foregroundLstar);
  }

  const whiteProt = calculateProtection({
    protectionArgb: white,
    backgroundArgb: opts.minBackgroundArgb,
    foregroundLstar,
    absoluteContrast,
    algo: opts.algo,
    lightenBackground: true,
  });
  const blackProt = calculateProtection({
    protectionArgb: black,
    backgroundArgb: opts.maxBackgroundArgb,
    foregroundLstar,
    absoluteContrast,
    algo: opts.algo,
    lightenBackground: false,
  });
  return chooseBestProtection({
    foregroundArgb: opts.foregroundArgb,
    minBackgroundArgb: opts.minBackgroundArgb,
    maxBackgroundArgb: opts.maxBackgroundArgb,
    foregroundLstar,
    absoluteContrast,
    algo: opts.algo,
    ...(whiteProt === undefined ? {} : {whiteProt}),
    ...(blackProt === undefined ? {} : {blackProt}),
  });
}

export function getOpacityForColors(opts: {foreground: Argb; background: Argb; contrast: number; algo: Algo}): OpacityResult {
  return getOpacityForArgbs({foregroundArgb: opts.foreground, minBackgroundArgb: opts.background, maxBackgroundArgb: opts.background, contrast: opts.contrast, algo: opts.algo});
}

export function getOpacityForBackgrounds(opts: {foreground: Argb; backgrounds: Iterable<Argb>; contrast: number; algo: Algo}): OpacityResult {
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
  return getOpacityForArgbs({foregroundArgb: opts.foreground, minBackgroundArgb: minLumaArgb, maxBackgroundArgb: maxLumaArgb, contrast: opts.contrast, algo: opts.algo});
}

export function getOpacity(opts: {minBgLstar: number; maxBgLstar: number; foregroundLstar: number; contrast: number; algo: Algo}): OpacityResult {
  return getOpacityForArgbs({
    foregroundArgb: argbFromLstar(opts.foregroundLstar),
    minBackgroundArgb: argbFromLstar(opts.minBgLstar),
    maxBackgroundArgb: argbFromLstar(opts.maxBgLstar),
    contrast: opts.contrast,
    algo: opts.algo,
  });
}
