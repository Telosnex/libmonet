// Contrast protection solver (ADR-001). Direct port of
// lib/effects/protection.dart — keep the two in lockstep; parity is enforced
// by fixtures in js/fixtures/libmonet_parity.json.
//
// One boring predicate — "does this scrim at this opacity make the foreground
// meet contrast against every provided background color?" — evaluated at all
// 256 renderable opacities. No algebra, no inversion, no reduction of the
// background list. Exact against its inputs by construction.
//
// INPUT CONTRACT: backgroundArgbs must be real sampled pixels from the region
// under the text. If downscaling first, use min/max pooling, never averaging.

import {type Argb, argbFromRgb, blueFromArgb, greenFromArgb, redFromArgb} from './color.js';
import {Algo, Usage, apcaYFromArgb, contrastBetweenArgbs, getAbsoluteContrast} from './contrast.js';
import {lstarFromArgb, yFromLstar} from './hct.js';

export enum ClearedSide { low = 'low', high = 'high' }

export class ProtectionResult {
  constructor(
    /** ARGB of the protection layer (black/white in auto mode, or the caller's protectionArgb). */
    readonly protectionArgb: Argb,
    /** Solved opacity, quantized to 1/255 (matches 8-bit compositing exactly). */
    readonly opacity: number,
    /** False when no opacity of this scrim can meet the target — result is best effort at 1.0. */
    readonly meetsTarget: boolean,
    /** Worst-case |contrast| over all provided backgrounds at `opacity`. */
    readonly achievedContrast: number,
    /** Side of the foreground's luminance on which all backgrounds landed. */
    readonly clearedSide: ClearedSide,
    /** True when a lower opacity passed per-pixel but with backgrounds on BOTH sides of the fg. */
    readonly straddleCollapsed: boolean,
  ) {}

  get needsProtection(): boolean { return this.opacity > 0; }
}

/** Spec for a dilated-then-blurred halo (ADR-001 D-4). */
export class HaloResult {
  constructor(
    readonly argb: Argb,
    readonly opacity: number,
    readonly spread: number,
    readonly blurRadius: number,
    readonly meetsTarget: boolean,
  ) {}
}

/**
 * Recipe for approximating protection with ordinary Gaussian shadows
 * (ADR-001 D-5): draw one shadow per entry in `opacities`, each with color
 * `argb`, blur `blurRadius`, zero offset. Layer math, where e is the modeled
 * fraction of one layer's alpha landing just outside the glyph edge:
 *   n = ceil(log(1 - requiredOpacity) / log(1 - e))
 *   perLayer = (1 - (1 - requiredOpacity)^(1/n)) / e, quantized UP to 1/255.
 *
 * HONESTY NOTE: unlike ProtectionResult.meetsTarget (exact by construction),
 * meetsTarget here is conditional on the edge-coverage model (the Gaussian
 * edge profile, Φ; calibrated against rendered Skia pixels in the Dart
 * repo's shadow_pixel_calibration_test.dart). Corners and very thin strokes
 * deviate. Prefer the halo where available.
 */
export class StackedShadowSpec {
  constructor(
    readonly argb: Argb,
    readonly blurRadius: number,
    /** Per-layer paint alphas; identical by construction. */
    readonly opacities: number[],
    readonly meetsTarget: boolean,
    /** Modeled edge coverage e per layer — exposed for audits and goldens. */
    readonly edgeCoverage: number,
    /** The scrim opacity this stack is approximating (the exact solver's α). */
    readonly requiredOpacity: number,
  ) {}
}

const white: Argb = 0xffffffff;
const black: Argb = 0xff000000;

export interface ProtectionOptions {
  foregroundArgb: Argb;
  backgroundArgbs: Argb[];
  contrast: number;
  algo: Algo;
  usage?: Usage;
  protectionArgb?: Argb;
}

/**
 * Minimum scrim opacity so foreground meets `contrast` (0..1 interpolation
 * percent) against every background, for every opacity at or above the
 * returned one. `protectionArgb` fixes the scrim color; omitted, both black
 * and white are solved and the cheaper wins.
 */
export function getProtectionOpacity(opts: ProtectionOptions): ProtectionResult {
  const {foregroundArgb, backgroundArgbs, contrast, algo} = opts;
  const usage = opts.usage ?? Usage.text;
  if (backgroundArgbs.length === 0) throw new Error('backgroundArgbs cannot be empty');
  if (!(contrast > 0 && contrast <= 1)) throw new Error(`contrast must be in (0, 1]: ${contrast}`);
  const target = getAbsoluteContrast(algo, contrast, usage);

  if (opts.protectionArgb !== undefined) {
    return solveForScrim(foregroundArgb, backgroundArgbs, target, algo, opts.protectionArgb);
  }
  const blackResult = solveForScrim(foregroundArgb, backgroundArgbs, target, algo, black);
  const whiteResult = solveForScrim(foregroundArgb, backgroundArgbs, target, algo, white);
  if (blackResult.meetsTarget && whiteResult.meetsTarget) {
    return blackResult.opacity <= whiteResult.opacity ? blackResult : whiteResult;
  }
  if (blackResult.meetsTarget) return blackResult;
  if (whiteResult.meetsTarget) return whiteResult;
  // Infeasible either way: best effort is whichever pole contrasts harder.
  return blackResult.achievedContrast >= whiteResult.achievedContrast ? blackResult : whiteResult;
}

/** Halo variant: same solve, delivered as a dilate-then-blur spec. */
export function getHalo(opts: ProtectionOptions & {spread?: number; blurRadius?: number}): HaloResult {
  const spread = opts.spread ?? 1.0;
  const blurRadius = opts.blurRadius ?? 4.0;
  if (!(spread >= 0) || !(blurRadius >= 0)) {
    throw new Error('spread and blurRadius must be non-negative');
  }
  const r = getProtectionOpacity(opts);
  return new HaloResult(r.protectionArgb, r.opacity, spread, blurRadius, r.meetsTarget);
}

/**
 * Fallback delivery of getProtectionOpacity as stacked Gaussian shadows.
 * Prefer getHalo wherever the renderer supports dilate-then-blur.
 */
export function getStackedShadowSpec(
  opts: ProtectionOptions & {blurRadius: number; contentRadius?: number; maxLayers?: number},
): StackedShadowSpec {
  const {blurRadius} = opts;
  const contentRadius = opts.contentRadius ?? -1.0;
  const maxLayers = opts.maxLayers ?? 8;
  if (!Number.isFinite(blurRadius) || blurRadius < 0) throw new Error(`invalid blurRadius: ${blurRadius}`);
  if (!Number.isFinite(contentRadius)) throw new Error(`invalid contentRadius: ${contentRadius}`);
  if (maxLayers < 1) throw new Error(`invalid maxLayers: ${maxLayers}`);

  const protection = getProtectionOpacity(opts);
  const alpha = protection.opacity;
  if (alpha === 0) {
    return new StackedShadowSpec(protection.protectionArgb, 0, [], protection.meetsTarget, 0, 0);
  }

  // D7 fix: round the radius exactly once; all kernel math uses the rounded
  // value, including sigma.
  const r = Math.round(blurRadius);
  if (r === 0) {
    // Protection is needed but a zero-blur shadow is invisible.
    return new StackedShadowSpec(protection.protectionArgb, 0, [], false, 0, alpha);
  }

  // Edge coverage: continuous Gaussian edge profile at the first outside
  // pixel's center (0.5px past the edge). CALIBRATED against rendered Skia
  // pixels (test/effects/shadow_pixel_calibration_test.dart in the Dart
  // repo); a truncated-renormalized discrete kernel was measured 0.04
  // optimistic on thin content and rejected.
  const sigma = convertRadiusToSigma(r);
  const cr = contentRadius < 0 ? r : Math.round(contentRadius);
  const e = contentRadius < 0
    ? 1 - phi(0.5 / sigma) // content wide relative to blur: half-plane
    : phi((0.5 + 2 * cr) / sigma) - phi(0.5 / sigma);

  if (e <= 0) {
    return new StackedShadowSpec(protection.protectionArgb, r, [], false, e, alpha);
  }

  // Closed form. alpha == 1 is unreachable through (1-e)^n for e < 1.
  const n = alpha >= 1
    ? maxLayers + 1
    : Math.min(Math.max(Math.ceil(Math.log(1 - alpha) / Math.log(1 - e)), 1), maxLayers + 1);
  if (n > maxLayers) {
    return new StackedShadowSpec(
      protection.protectionArgb, r, Array(maxLayers).fill(1.0) as number[], false, e, alpha);
  }
  // Closed form hits alpha with EQUALITY — but alpha is the solver's minimal
  // passing opacity, and renderers quantize paint alpha to 1/255. Round UP
  // so the drawn stack can never land below the proven minimum.
  const perLayerRaw = (1 - Math.pow(1 - alpha, 1 / n)) / e;
  const perLayer = Math.min(Math.max(Math.ceil(perLayerRaw * 255), 0), 255) / 255;
  return new StackedShadowSpec(
    protection.protectionArgb, r, Array(n).fill(perLayer) as number[],
    protection.meetsTarget, e, alpha);
}

// =============================================================================
// The predicate, and the scan.
// =============================================================================

/** 8-bit source-over blend of scrim at alpha a (0..255) onto opaque bg. */
export function blendArgb(bg: Argb, scrim: Argb, a: number): Argb {
  const ch = (b: number, s: number) => Math.round(((255 - a) * b + a * s) / 255);
  return argbFromRgb(
    ch(redFromArgb(bg), redFromArgb(scrim)),
    ch(greenFromArgb(bg), greenFromArgb(scrim)),
    ch(blueFromArgb(bg), blueFromArgb(scrim)),
  );
}

function yForSide(algo: Algo, argb: Argb): number {
  return algo === Algo.apca ? apcaYFromArgb(argb) : yFromLstar(lstarFromArgb(argb));
}

interface Outcome {
  allPass: boolean;
  oneSided: boolean;
  worstAbs: number;
  side: ClearedSide;
}

function evaluate(
  fgArgb: Argb, bgArgbs: Argb[], target: number, algo: Algo, scrimArgb: Argb, a: number,
): Outcome {
  const fgY = yForSide(algo, fgArgb);
  let allPass = true;
  let anyLow = false, anyHigh = false;
  let worst = Infinity;
  for (const bg of bgArgbs) {
    const blended = blendArgb(bg, scrimArgb, a);
    const c = Math.abs(contrastBetweenArgbs(algo, blended, fgArgb));
    if (c < worst) worst = c;
    if (c < target) allPass = false;
    if (yForSide(algo, blended) < fgY) anyLow = true; else anyHigh = true;
  }
  return {
    allPass,
    oneSided: !(anyLow && anyHigh),
    worstAbs: worst,
    side: anyHigh && !anyLow ? ClearedSide.high : ClearedSide.low,
  };
}

function solveForScrim(
  fgArgb: Argb, bgArgbs: Argb[], target: number, algo: Algo, scrimArgb: Argb,
): ProtectionResult {
  // Evaluate everything; invert nothing. 256 x N cheap evaluations.
  const outcomes: Outcome[] = [];
  for (let a = 0; a <= 255; a++) outcomes.push(evaluate(fgArgb, bgArgbs, target, algo, scrimArgb, a));

  // Lowest alpha such that it AND every higher alpha clears one-sided.
  // (Blended luminance is not monotone in alpha for arbitrary scrim colors;
  // the downward suffix scan preserves "solved alpha and above are safe".)
  let solved: number | undefined;
  for (let a = 255; a >= 0; a--) {
    const o = outcomes[a]!;
    if (o.allPass && o.oneSided) solved = a; else break;
  }

  if (solved === undefined) {
    // Infeasible: fg cannot meet target even against the pure scrim color.
    const at = outcomes[255]!;
    return new ProtectionResult(scrimArgb, 1.0, false, at.worstAbs, at.side, false);
  }

  // Straddle: some lower alpha passed per-pixel but with backgrounds on both
  // sides of the foreground. Deliberately rejected; surfaced, not silent.
  let straddle = false;
  for (let a = 0; a < solved; a++) {
    const o = outcomes[a]!;
    if (o.allPass && !o.oneSided) { straddle = true; break; }
  }

  const at = outcomes[solved]!;
  return new ProtectionResult(
    scrimArgb, solved / 255, true, at.worstAbs, at.side, straddle);
}

export function gauss1d(x: number, sigma: number): number {
  return (1 / (sigma * Math.sqrt(2 * Math.PI))) * Math.exp(-(x * x) / (2 * sigma * sigma));
}

// Standard normal CDF via Abramowitz & Stegun 7.1.26 (|err| < 1.5e-7).
// Keep bit-identical with lib/effects/protection.dart.
function phi(z: number): number {
  return 0.5 * (1 + erf(z / Math.SQRT2));
}

function erf(x: number): number {
  const sign = x < 0 ? -1 : 1;
  const ax = Math.abs(x);
  const t = 1 / (1 + 0.3275911 * ax);
  const y = 1 -
    ((((1.061405429 * t - 1.453152027) * t + 1.421413741) * t - 0.284496736) * t + 0.254829592) *
    t * Math.exp(-ax * ax);
  return sign * y;
}

// See SkBlurMask::ConvertRadiusToSigma().
export function convertRadiusToSigma(radius: number): number {
  return radius > 0 ? radius * 0.57735 + 0.5 : 0;
}
