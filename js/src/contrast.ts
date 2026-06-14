import {Hct, lstarFromArgb, yFromLstar, delinearized, linearized, type ColorModel} from './hct.js';
import {type Argb, argbFromRgb, redFromArgb, greenFromArgb, blueFromArgb} from './color.js';

export enum Algo { wcag21 = 'wcag21', apca = 'apca' }
export enum Usage { text = 'text', fill = 'fill', large = 'large', border = 'border' }
export enum ContrastDirection { lighter = 'lighter', darker = 'darker' }

export const mainTrc = 2.4;
export const sRco = 0.2126729;
export const sGco = 0.7151522;
export const sBco = 0.0721750;
export const normBg = 0.56;
export const normText = 0.57;
export const revText = 0.62;
export const revBg = 0.65;
export const blkThrs = 0.022;
export const blkClmp = 1.414;
export const scaleBoW = 1.14;
export const scaleWoB = 1.14;
export const loBoWOffset = 0.027;
export const loWoBOffset = 0.027;
export const deltaYMin = 0.0005;
export const loClip = 0.1;

export function clamp(v: number, lo: number, hi: number): number { return Math.min(hi, Math.max(lo, v)); }

function fixupForBlackThreshold(apcaY: number): number {
  return apcaY > blkThrs ? apcaY : apcaY + Math.pow(blkThrs - apcaY, blkClmp);
}

function inBoundsApcaY(apcaY: number): number {
  return fixupForBlackThreshold(clamp(apcaY, 0, 1.1));
}

export function apcaYFromArgb(argb: Argb): number {
  const simpleExp = (c: number) => Math.pow(c / 255, mainTrc);
  return sRco * simpleExp(redFromArgb(argb)) + sGco * simpleExp(greenFromArgb(argb)) + sBco * simpleExp(blueFromArgb(argb));
}

export function apcaContrastOfApcaY(textApcaY: number, backgroundApcaY: number): number {
  textApcaY = fixupForBlackThreshold(clamp(textApcaY, 0, 1.1));
  backgroundApcaY = fixupForBlackThreshold(clamp(backgroundApcaY, 0, 1.1));
  if (Math.abs(backgroundApcaY - textApcaY) < deltaYMin) return 0;
  if (backgroundApcaY > textApcaY) {
    const sapc = (Math.pow(backgroundApcaY, normBg) - Math.pow(textApcaY, normText)) * scaleBoW;
    return (sapc < loClip ? 0 : sapc - loBoWOffset) * 100;
  }
  const sapc = (Math.pow(backgroundApcaY, revBg) - Math.pow(textApcaY, revText)) * scaleWoB;
  return (sapc > -loClip ? 0 : sapc + loWoBOffset) * 100;
}

export function apcaFromArgbs(textArgb: Argb, backgroundArgb: Argb): number {
  return apcaContrastOfApcaY(apcaYFromArgb(textArgb), apcaYFromArgb(backgroundArgb));
}

export function lstarToApcaY(lstar: number): number {
  const srgb = delinearized(yFromLstar(lstar) / 100);
  return (sRco + sGco + sBco) * Math.pow(clamp(srgb, 0, 1), mainTrc);
}

export function lstarPrefersLighterPair(lstar: number): boolean { return Math.round(lstar) <= 60; }

export function apcaInterpolation(percent: number, usage: Usage): number {
  const mid = usage === Usage.text ? 60 : usage === Usage.fill ? 45 : usage === Usage.large ? 30 : 15;
  const actualPercent = (percent > 0.5 ? percent - 0.5 : percent) / 0.5;
  const start = percent > 0.5 ? mid : 0;
  const end = percent > 0.5 ? 110 : mid;
  return start + (end - start) * actualPercent;
}

export function contrastRatioOfLstars(a: number, b: number): number {
  const ay = yFromLstar(a), by = yFromLstar(b);
  return (Math.max(ay, by) + 5) / (Math.min(ay, by) + 5);
}

export function contrastRatioInterpolation(percent: number, usage: Usage): number {
  const mid = usage === Usage.text ? 4.5 : usage === Usage.fill || usage === Usage.large ? 3 : 1.5;
  const actualPercent = (percent > 0.5 ? percent - 0.5 : percent) / 0.5;
  const start = percent > 0.5 ? mid : 1;
  const end = percent > 0.5 ? 21 : mid;
  return start + (end - start) * actualPercent;
}

export function lighterLstarUnsafe(lstar: number, contrastRatio: number): number {
  const y = yFromLstar(lstar);
  return lstarFromY((contrastRatio * (y + 5)) - 5);
}

export function darkerLstarUnsafe(lstar: number, contrastRatio: number): number {
  const y = yFromLstar(lstar);
  return lstarFromY(((y + 5) / contrastRatio) - 5);
}

export function contrastingLstar(opts: {withLstar: number; usage: Usage; by?: Algo; contrast: number; forceDirection?: ContrastDirection}): number {
  const by = opts.by ?? Algo.apca;
  const prefersLighter = opts.forceDirection === ContrastDirection.lighter ? true : opts.forceDirection === ContrastDirection.darker ? false : lstarPrefersLighterPair(opts.withLstar);
  const forced = opts.forceDirection !== undefined;

  if (by === Algo.wcag21) {
    const ratio = contrastRatioInterpolation(opts.contrast, opts.usage);
    if (prefersLighter) {
      const naive = lighterLstarUnsafe(opts.withLstar, ratio);
      if (Math.round(naive) <= 100) return clamp(naive, 0, 100);
      if (forced) return 100;
      const blackError = Math.abs(ratio - contrastRatioOfLstars(opts.withLstar, 0));
      const whiteError = Math.abs(ratio - contrastRatioOfLstars(opts.withLstar, 100));
      return blackError <= whiteError ? 0 : 100;
    }
    const naive = darkerLstarUnsafe(opts.withLstar, ratio);
    if (Math.round(naive) >= 0) return clamp(naive, 0, 100);
    if (forced) return 0;
    const blackError = Math.abs(ratio - contrastRatioOfLstars(opts.withLstar, 0));
    const whiteError = Math.abs(ratio - contrastRatioOfLstars(opts.withLstar, 100));
    return blackError <= whiteError ? 0 : 100;
  }

  const apca = apcaInterpolation(opts.contrast, opts.usage);
  if (prefersLighter) {
    const naive = lighterTextLstar(opts.withLstar, -apca);
    if (Math.round(naive) <= 100) return clamp(naive, 0, 100);
    if (forced) return 100;
    const apcaYWith = lstarToApcaY(opts.withLstar);
    const blackError = Math.abs(apca - Math.abs(apcaContrastOfApcaY(apcaYWith, lstarToApcaY(0))));
    const whiteError = Math.abs(apca - Math.abs(apcaContrastOfApcaY(apcaYWith, lstarToApcaY(100))));
    return blackError <= whiteError ? 0 : 100;
  }
  const naive = darkerTextLstarUnsafe(opts.withLstar, apca);
  if (Math.round(naive) >= 0) return clamp(naive, 0, 100);
  if (forced) return 0;
  const apcaYWith = lstarToApcaY(opts.withLstar);
  const blackError = Math.abs(apca - Math.abs(apcaContrastOfApcaY(apcaYWith, lstarToApcaY(0))));
  const whiteError = Math.abs(apca - Math.abs(apcaContrastOfApcaY(apcaYWith, lstarToApcaY(100))));
  return blackError <= whiteError ? 0 : 100;
} 

export function contrastBetweenArgbs(algo: Algo, bgArgb: Argb, fgArgb: Argb): number {
  if (algo === Algo.wcag21) return contrastRatioOfLstars(lstarFromArgb(bgArgb), lstarFromArgb(fgArgb));
  return apcaFromArgbs(fgArgb, bgArgb);
}

export function getAbsoluteContrast(algo: Algo, interpolation: number, usage: Usage): number {
  return algo === Algo.wcag21 ? contrastRatioInterpolation(interpolation, usage) : apcaInterpolation(interpolation, usage);
}

function apcaYToGrayscaleArgb(apcaY: number): Argb {
  const clamped = clamp(apcaY, 0, 1.1);
  const channel = Math.round(255 * Math.pow(clamped / (sRco + sGco + sBco), 1 / mainTrc));
  return argbFromRgb(clamp(channel, 0, 255), clamp(channel, 0, 255), clamp(channel, 0, 255));
}

function apcaYToGrayscaleLstar(apcaY: number): number {
  const sign = apcaY < 0 ? -1 : 1;
  const normalized = Math.pow(Math.abs(apcaY), 1 / mainTrc);
  return sign * lstarFromY(linearized(normalized) * 100);
}

function lstarFromY(y: number): number {
  const e = 216 / 24389;
  const kappa = 24389 / 27;
  const yNormalized = y / 100;
  return yNormalized <= e ? yNormalized * kappa : 116 * Math.cbrt(yNormalized) - 16;
}

function yFromArgb(argb: Argb): number {
  const r = linearized(redFromArgb(argb) / 255) * 100;
  const g = linearized(greenFromArgb(argb) / 255) * 100;
  const b = linearized(blueFromArgb(argb) / 255) * 100;
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

export function findBoundaryArgbsForApcaY(apcaY: number): Argb[] {
  const calculateContribution = (target: number, fulfilled: number, coefficient: number): number => {
    const needed = target - fulfilled;
    const answer = 255 * Math.pow(needed / coefficient, 1 / mainTrc);
    return Number.isNaN(answer) ? 0 : answer;
  };

  const boundaryInts: Argb[] = [apcaYToGrayscaleArgb(apcaY)];
  const addAnswer = (argb: Argb) => boundaryInts.push(argb);

  const maxR = 255 * Math.pow(apcaY / sRco, 1 / mainTrc);
  if (maxR <= 255) {
    addAnswer(argbFromRgb(Math.round(maxR), 0, 0));
  } else {
    const redContribution = sRco;
    const g1 = calculateContribution(apcaY, redContribution, sGco);
    if (g1 <= 255) addAnswer(argbFromRgb(255, Math.round(g1), 0));
    else addAnswer(argbFromRgb(255, 255, Math.round(calculateContribution(apcaY, redContribution + sGco, sBco))));
    const b2 = calculateContribution(apcaY, redContribution, sBco);
    if (b2 <= 255) addAnswer(argbFromRgb(255, 0, Math.round(b2)));
    else addAnswer(argbFromRgb(255, Math.round(calculateContribution(apcaY, redContribution + sBco, sGco)), 255));
  }

  const maxG = 255 * Math.pow(apcaY / sGco, 1 / mainTrc);
  if (maxG <= 255) {
    addAnswer(argbFromRgb(0, Math.round(maxG), 0));
  } else {
    const greenContribution = sGco;
    const r1 = calculateContribution(apcaY, greenContribution, sRco);
    if (r1 <= 255) addAnswer(argbFromRgb(Math.round(r1), 255, 0));
    else addAnswer(argbFromRgb(255, 255, Math.round(calculateContribution(apcaY, greenContribution + sRco, sBco))));
    const b2 = calculateContribution(apcaY, greenContribution, sBco);
    if (b2 <= 255) addAnswer(argbFromRgb(0, 255, Math.round(b2)));
    else addAnswer(argbFromRgb(Math.round(calculateContribution(apcaY, greenContribution + sBco, sRco)), 255, 255));
  }

  const maxB = Math.round(255 * Math.pow(apcaY / sBco, 1 / mainTrc));
  if (maxB <= 255) {
    addAnswer(argbFromRgb(0, 0, Math.round(maxB)));
  } else {
    const blueContribution = sBco;
    const r1 = calculateContribution(apcaY, blueContribution, sRco);
    if (r1 <= 255) addAnswer(argbFromRgb(Math.round(r1), 0, 255));
    else addAnswer(argbFromRgb(255, Math.round(calculateContribution(apcaY, blueContribution + sRco, sGco)), 255));
    const g2 = calculateContribution(apcaY, blueContribution, sGco);
    if (g2 <= 255) addAnswer(argbFromRgb(0, Math.round(g2), 255));
    else addAnswer(argbFromRgb(Math.round(calculateContribution(apcaY, blueContribution + sGco, sRco)), 255, 255));
  }

  return boundaryInts;
}

function apcaYToLstarRange(apcaY: number): {darkest: number; lightest: number} {
  if (apcaY < 0 || apcaY > sRco + sGco + sBco) {
    const l = apcaYToGrayscaleLstar(apcaY);
    return {darkest: l, lightest: l};
  }
  const ys = findBoundaryArgbsForApcaY(apcaY).map(yFromArgb);
  const minY = Math.min(...ys);
  const maxY = Math.max(...ys);
  return {
    darkest: clamp(lstarFromY(minY) - 0.08747562332222003, 0, 100),
    lightest: clamp(lstarFromY(maxY) + 0.23986207179298447, 0, 100),
  };
}

function realPartOfImaginaryPower(imaginary: number, exponent: number): number {
  const r = Math.abs(imaginary);
  const theta = imaginary < 0 ? -Math.PI / 2 : Math.PI / 2;
  return Math.pow(r, exponent) * Math.cos(exponent * theta);
}

export function lighterBackgroundApcaY(textApcaY: number, apca: number): number {
  textApcaY = inBoundsApcaY(textApcaY);
  apca = apca / 100;
  const sapc = apca === 0 ? 0 : apca + loBoWOffset;
  const firstTerm = Math.pow(textApcaY, normText);
  const secondTerm = sapc / scaleBoW;
  const base = firstTerm + secondTerm;
  return base < 0 ? realPartOfImaginaryPower(secondTerm - firstTerm, 1 / normBg) : Math.pow(base, 1 / normBg);
}

export function darkerBackgroundApcaY(textApcaY: number, apca: number): number {
  textApcaY = inBoundsApcaY(textApcaY);
  apca = apca / 100;
  if (apca > 0) apca = -apca;
  const sapc = apca === 0 ? 0 : apca - loWoBOffset;
  const firstTerm = sapc / scaleWoB;
  const secondTerm = Math.pow(textApcaY, revText);
  const base = firstTerm + secondTerm;
  return base < 0 ? realPartOfImaginaryPower(secondTerm + firstTerm, 1 / revBg) : Math.pow(base, 1 / revBg);
}

export function lighterTextApcaY(backgroundApcaY: number, apca: number): number {
  backgroundApcaY = inBoundsApcaY(backgroundApcaY);
  apca = apca / 100; if (apca > 0) apca = -apca;
  const sapc = apca === 0 ? 0 : apca - loWoBOffset;
  const firstTerm = Math.pow(backgroundApcaY, revBg);
  const secondTerm = sapc / scaleWoB;
  const base = firstTerm - secondTerm;
  return base < 0 ? realPartOfImaginaryPower(secondTerm - firstTerm, 1 / revBg) : Math.pow(base, 1 / revText);
}

export function darkerTextApcaY(backgroundApcaY: number, apca: number): number {
  backgroundApcaY = inBoundsApcaY(backgroundApcaY);
  apca = apca / 100;
  const sapc = apca === 0 ? 0 : apca + loBoWOffset;
  const firstTerm = Math.pow(backgroundApcaY, normBg);
  const secondTerm = sapc / scaleBoW;
  const base = firstTerm - secondTerm;
  return base < 0 ? realPartOfImaginaryPower(secondTerm - firstTerm, 1 / normText) : Math.pow(base, 1 / normText);
}

export function lighterBackgroundLstarUnsafe(textLstar: number, apca: number): number {
  return apcaYToLstarRange(lighterBackgroundApcaY(lstarToApcaY(textLstar), apca)).lightest;
}
export function lighterBackgroundLstar(textLstar: number, apca: number): number { return clamp(lighterBackgroundLstarUnsafe(textLstar, apca), 0, 100); }
export function darkerBackgroundLstarUnsafe(textLstar: number, apca: number): number {
  return apcaYToLstarRange(darkerBackgroundApcaY(lstarToApcaY(textLstar), apca)).darkest;
}
export function darkerBackgroundLstar(textLstar: number, apca: number): number {
  const textApcaY = lstarToApcaY(textLstar);
  const darkerBackgroundApcaYValue = darkerBackgroundApcaY(textApcaY, apca);
  if (darkerBackgroundApcaYValue < 0) {
    const lighterBackgroundApcaYValue = lighterBackgroundApcaY(textApcaY, apca);
    if (lighterBackgroundApcaYValue > 1) {
      const distanceFromNeededLightToMaxLight = lighterBackgroundApcaYValue - 1.0;
      const distanceFromNeededDarkToMaxDark = 0.0 - darkerBackgroundApcaYValue;
      return distanceFromNeededLightToMaxLight > distanceFromNeededDarkToMaxDark ? 0.0 : 100.0;
    }
    return clamp(apcaYToLstarRange(lighterBackgroundApcaYValue).lightest, 0, 100);
  }
  return clamp(apcaYToLstarRange(darkerBackgroundApcaYValue).darkest, 0, 100);
}
export function lighterTextLstarUnsafe(backgroundLstar: number, apca: number): number {
  return apcaYToLstarRange(lighterTextApcaY(lstarToApcaY(backgroundLstar), apca)).lightest;
}
export function lighterTextLstar(backgroundLstar: number, apca: number): number {
  const backgroundApcaY = lstarToApcaY(backgroundLstar);
  const lighterTextApcaYValue = lighterTextApcaY(backgroundApcaY, apca);
  if (lighterTextApcaYValue > 1.0) {
    const darkerTextApcaYValue = darkerTextApcaY(backgroundApcaY, apca);
    if (darkerTextApcaYValue < 0) {
      const distanceFromNeededLightToMaxLight = lighterTextApcaYValue - 1.0;
      const distanceFromNeededDarkToMaxDark = 0.0 - darkerTextApcaYValue;
      return distanceFromNeededLightToMaxLight > distanceFromNeededDarkToMaxDark ? 0.0 : 100.0;
    }
    return clamp(apcaYToLstarRange(darkerTextApcaYValue).darkest, 0, 100);
  }
  return clamp(apcaYToLstarRange(lighterTextApcaYValue).lightest, 0, 100);
}
export function darkerTextLstarUnsafe(backgroundLstar: number, apca: number): number {
  return apcaYToLstarRange(darkerTextApcaY(lstarToApcaY(backgroundLstar), apca)).darkest;
}
export function darkerTextLstar(backgroundLstar: number, apca: number): number {
  const backgroundApcaY = lstarToApcaY(backgroundLstar);
  const darkerTextApcaYValue = darkerTextApcaY(backgroundApcaY, apca);
  if (darkerTextApcaYValue < 0) {
    const lighterTextApcaYValue = lighterTextApcaY(backgroundApcaY, apca);
    if (lighterTextApcaYValue > 1) {
      const distanceFromNeededLightToMaxLight = lighterTextApcaYValue - 1.0;
      const distanceFromNeededDarkToMaxDark = 0.0 - darkerTextApcaYValue;
      return distanceFromNeededLightToMaxLight > distanceFromNeededDarkToMaxDark ? 0.0 : 100.0;
    }
    return clamp(apcaYToLstarRange(lighterTextApcaYValue).lightest, 0, 100);
  }
  return clamp(apcaYToLstarRange(darkerTextApcaYValue).darkest, 0, 100);
}

export function contrastingTone(opts: {withArgb: Argb; withTone: number; targetHue: number; targetChroma: number; usage: Usage; by?: Algo; contrast: number; forceDirection?: ContrastDirection; colorModel?: ColorModel}): number {
  const by = opts.by ?? Algo.apca;
  if (by === Algo.wcag21) {
    return contrastingLstar({
      withLstar: opts.withTone,
      usage: opts.usage,
      by,
      contrast: opts.contrast,
      ...(opts.forceDirection === undefined ? {} : {forceDirection: opts.forceDirection}),
    });
  }
  const target = getAbsoluteContrast(by, opts.contrast, opts.usage);
  const prefersLighter = opts.forceDirection === ContrastDirection.lighter ? true : opts.forceDirection === ContrastDirection.darker ? false : lstarPrefersLighterPair(opts.withTone);
  const forced = opts.forceDirection !== undefined;
  const lcAt = (tone: number) => Math.abs(contrastBetweenArgbs(by, opts.withArgb, Hct.from(opts.targetHue, opts.targetChroma, tone, opts.colorModel).toInt()));
  const iterations = 15;
  const seedMargin = 6.0;
  const lstarSeed = (): number | undefined => {
    try {
      const seed = prefersLighter ? lighterTextLstar(opts.withTone, -target) : darkerTextLstarUnsafe(opts.withTone, target);
      return seed >= 0 && seed <= 100 ? seed : undefined;
    } catch {
      return undefined;
    }
  };
  if (prefersLighter) {
    const maxLc = lcAt(100);
    if (maxLc < target) {
      if (forced) return 100;
      const minLc = lcAt(0);
      return Math.abs(target - minLc) <= Math.abs(target - maxLc) ? 0 : 100;
    }
    const seed = lstarSeed();
    let lo = seed !== undefined ? clamp(seed - seedMargin, opts.withTone, 100) : opts.withTone;
    let hi = seed !== undefined ? clamp(seed + seedMargin, opts.withTone, 100) : 100;
    if (lcAt(hi) < target) hi = 100;
    for (let i = 0; i < iterations; i++) { const mid = (lo + hi) / 2; if (lcAt(mid) >= target) hi = mid; else lo = mid; }
    return clamp(hi, 0, 100);
  }
  const minLc = lcAt(0);
  if (minLc < target) {
    if (forced) return 0;
    const maxLc = lcAt(100);
    return Math.abs(target - minLc) <= Math.abs(target - maxLc) ? 0 : 100;
  }
  const seed = lstarSeed();
  let lo = seed !== undefined ? clamp(seed - seedMargin, 0, opts.withTone) : 0;
  let hi = seed !== undefined ? clamp(seed + seedMargin, 0, opts.withTone) : opts.withTone;
  if (lcAt(lo) < target) lo = 0;
  for (let i = 0; i < iterations; i++) { const mid = (lo + hi) / 2; if (lcAt(mid) >= target) lo = mid; else hi = mid; }
  return clamp(lo, 0, 100);
}
