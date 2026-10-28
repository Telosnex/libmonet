// Drawing over something you didn't choose: a wallpaper, a video frame, a
// gradient, a map. Direct port of lib/effects/over_image.dart; keep the two
// in lockstep. Parity is enforced by js/fixtures/libmonet_parity.json.
//
// A palette's background is one color the theme chose. AnyBackground is
// whatever is actually behind the UI, as real pixels. Build one per image,
// then ask it: scrimFor (legible text and icons), sharedBorder (one border
// tone for surfaces drawn together). See ADR-001.

import {type Argb, argbFromRgb, blueFromArgb, greenFromArgb, redFromArgb} from './color.js';
import {
  Algo,
  Usage,
  apcaContrastOfApcaY,
  apcaYFromArgb,
  contrastBetweenArgbs,
  getAbsoluteContrast,
} from './contrast.js';
import {type ColorModel, Hct, defaultColorModel, lstarFromArgb, yFromLstar} from './hct.js';
import {LruCache} from './lru-cache.js';

const white: Argb = 0xffffffff;
const black: Argb = 0xff000000;

/** Which way the content reads once the scrim is applied. */
export enum Polarity {
  /** Every blended pixel is darker than the content. */
  lightOnDark = 'lightOnDark',
  /** Every blended pixel is lighter than the content. */
  darkOnLight = 'darkOnLight',
}

/** A translucent layer that makes content legible over an AnyBackground. */
export class Scrim {
  /** @internal */
  constructor(
    /** The scrim's color: black or white, or the caller's choice. */
    readonly scrimArgb: Argb,
    /** 0..1, quantized to 1/255 so 8-bit compositing is exact. */
    readonly opacity: number,
    /** False: no opacity of scrimArgb reaches the target; opacity is a 1.0 best effort. */
    readonly meetsTarget: boolean,
    /** Weakest absolute contrast over every pixel at opacity. */
    readonly worstContrast: number,
    readonly polarity: Polarity,
    /** A lower opacity passed per pixel but left pixels on both sides of the content. */
    readonly mixedPolarityRejected: boolean,
  ) {}

  get isNeeded(): boolean { return this.opacity > 0; }

  /** scrimArgb with opacity as its alpha. Fill a rect with it. */
  get paintArgb(): Argb {
    return ((Math.round(this.opacity * 255) << 24) | (this.scrimArgb & 0x00ffffff)) >>> 0;
  }

  /**
   * Draw this scrim hugging the glyph: its shape widened by `stroke` pixels,
   * then blurred by `blurRadius`. Exact; prefer it where the renderer can
   * widen a shape (a stroke, BoxShadow spread, CSS box-shadow).
   */
  shadowsWithStroke(opts: {stroke?: number; blurRadius?: number} = {}): ShadowsWithStroke {
    const stroke = opts.stroke ?? 1.0;
    const blurRadius = opts.blurRadius ?? 4.0;
    if (!(stroke >= 0) || !(blurRadius >= 0)) {
      throw new Error('stroke and blurRadius must be non-negative');
    }
    return new ShadowsWithStroke(this, stroke, blurRadius);
  }

  /**
   * Draw this scrim as stacked blurred copies of the glyph, for renderers that
   * can't widen it (CSS text-shadow). Approximate; prefer shadowsWithStroke.
   */
  shadows(opts: {blurRadius: number; contentRadius?: number; maxLayers?: number}): Shadows {
    const {blurRadius} = opts;
    const contentRadius = opts.contentRadius ?? -1.0;
    const maxLayers = opts.maxLayers ?? 8;
    if (!Number.isFinite(blurRadius) || blurRadius < 0) throw new Error(`invalid blurRadius: ${blurRadius}`);
    if (!Number.isFinite(contentRadius)) throw new Error(`invalid contentRadius: ${contentRadius}`);
    if (maxLayers < 1) throw new Error(`invalid maxLayers: ${maxLayers}`);

    const alpha = this.opacity;
    if (alpha === 0) return new Shadows(this, 0, [], this.meetsTarget, 0);

    // Round the radius once: sigma and coverage use the drawn radius.
    const r = Math.round(blurRadius);
    if (r === 0) return new Shadows(this, 0, [], false, 0);

    // Edge coverage at the first outside pixel's center, 0.5px past the edge.
    // Calibrated against Skia pixels (shadow_pixel_calibration_test.dart).
    const sigma = convertRadiusToSigma(r);
    const cr = contentRadius < 0 ? r : Math.round(contentRadius);
    const e = contentRadius < 0
      ? 1 - phi(0.5 / sigma)
      : phi((0.5 + 2 * cr) / sigma) - phi(0.5 / sigma);
    if (e <= 0) return new Shadows(this, r, [], false, e);

    const n = alpha >= 1
      ? maxLayers + 1
      : Math.min(Math.max(Math.ceil(Math.log(1 - alpha) / Math.log(1 - e)), 1), maxLayers + 1);
    if (n > maxLayers) {
      return new Shadows(this, r, Array(maxLayers).fill(1.0) as number[], false, e);
    }
    // Round up to 1/255 so the drawn stack never lands below the minimum.
    const perLayerRaw = (1 - Math.pow(1 - alpha, 1 / n)) / e;
    const perLayer = Math.min(Math.max(Math.ceil(perLayerRaw * 255), 0), 255) / 255;
    return new Shadows(this, r, Array(n).fill(perLayer) as number[], this.meetsTarget, e);
  }
}

/** A Scrim drawn hugging the glyph; see Scrim.shadowsWithStroke. */
export class ShadowsWithStroke {
  /** @internal */
  constructor(readonly scrim: Scrim, readonly stroke: number, readonly blurRadius: number) {}

  /** Gaussian sigma for blurRadius, as Skia converts it. */
  get blurSigma(): number { return convertRadiusToSigma(this.blurRadius); }
}

/** A Scrim as stacked blurred copies of the glyph; see Scrim.shadows. */
export class Shadows {
  /** @internal */
  constructor(
    readonly scrim: Scrim,
    /** The rounded radius to draw every layer with. */
    readonly blurRadius: number,
    /** One alpha per layer, all equal. Empty when nothing needs drawing. */
    readonly layerOpacities: number[],
    /** Model-based: calibrated on long straight edges. Stricter than scrim.meetsTarget. */
    readonly meetsTarget: boolean,
    /** Modeled share of one layer's alpha on the first pixel outside the glyph. */
    readonly edgeCoverage: number,
  ) {}
}

/** One border tone for surfaces drawn together; see AnyBackground.sharedBorder. */
export class SharedBorder {
  /** @internal */
  constructor(
    /** The shared tone, 0..100. */
    readonly tone: number,
    /** One border per surface, same order, each in its surface's hue. */
    readonly borderArgbs: readonly Argb[],
    /** True: every border clears every pixel. False: each clears its own surface. */
    readonly clearsBackground: boolean,
    /** False: no tone works; this is the strongest best effort. */
    readonly meetsTarget: boolean,
    /** Weakest contrast backing the guarantee. */
    readonly worstContrast: number,
  ) {}
}

/** The pixels behind some UI, plus the contrast policy to judge them by. */
export class AnyBackground {
  readonly algo: Algo;
  /** libmonet's 0..1 contrast dial. */
  readonly contrast: number;
  private readonly argbs: readonly Argb[];
  private pixelsCache: Argb[] | undefined;
  private luminancesCache: number[] | undefined;
  private readonly scrims = new LruCache<string, Scrim>(64);
  private readonly borders = new LruCache<string, SharedBorder>(64);

  /**
   * `argbs` must be real sampled pixels from what's behind the UI: min/max
   * pool when downscaling, never average; quantizer clusters are averages.
   * Read on first use; don't modify afterwards. Empty means unknown.
   */
  constructor(argbs: readonly Argb[], opts: {algo: Algo; contrast: number}) {
    if (!(opts.contrast > 0 && opts.contrast <= 1)) {
      throw new Error(`contrast must be in (0, 1]: ${opts.contrast}`);
    }
    this.argbs = argbs;
    this.algo = opts.algo;
    this.contrast = opts.contrast;
  }

  /** Nothing is known about what's behind. */
  static unknown(opts: {algo: Algo; contrast: number}): AnyBackground {
    return new AnyBackground([], opts);
  }

  get isUnknown(): boolean { return this.argbs.length === 0; }

  /** Unique opaque pixels, sorted; black and white when unknown. */
  private get pixels(): Argb[] {
    if (this.pixelsCache === undefined) {
      this.pixelsCache = this.isUnknown
        ? [black, white]
        : [...new Set(this.argbs.map((a) => (a | 0xff000000) >>> 0))].sort((a, b) => a - b);
    }
    return this.pixelsCache;
  }

  /** Unique luminances in algo's space, sorted; empty when unknown. */
  private get luminances(): number[] {
    if (this.luminancesCache === undefined) {
      this.luminancesCache = this.isUnknown
        ? []
        : [...new Set(this.pixels.map((a) => luminance(this.algo, a)))].sort((a, b) => a - b);
    }
    return this.luminancesCache;
  }

  /** Minimum-opacity scrim making `contentArgb` meet usage's contrast against every pixel. */
  scrimFor(contentArgb: Argb, opts: {usage?: Usage; scrimArgb?: Argb} = {}): Scrim {
    const usage = opts.usage ?? Usage.text;
    const key = `${contentArgb}|${usage}|${opts.scrimArgb ?? ''}`;
    const hit = this.scrims.get(key);
    if (hit !== undefined) return hit;
    const target = getAbsoluteContrast(this.algo, this.contrast, usage);
    const canMix = !this.isUnknown;
    const solve = (scrim: Argb) =>
      solveForScrimColor(contentArgb, this.pixels, target, this.algo, scrim, canMix);
    let result: Scrim;
    if (opts.scrimArgb !== undefined) {
      result = solve(opts.scrimArgb);
    } else {
      const b = solve(black);
      const w = solve(white);
      if (b.meetsTarget && w.meetsTarget) result = b.opacity <= w.opacity ? b : w;
      else if (b.meetsTarget) result = b;
      else if (w.meetsTarget) result = w;
      else result = b.worstContrast >= w.worstContrast ? b : w;
    }
    this.scrims.set(key, result);
    return result;
  }

  /**
   * One border tone for surfaces drawn together, so they read at one
   * elevation. `surfaceArgbs`: each surface's resting color (sets its
   * border's hue). Hovered and pressed are deliberately excluded.
   */
  sharedBorder(
    surfaceArgbs: readonly Argb[],
    opts: {usage?: Usage; colorModel?: ColorModel} = {},
  ): SharedBorder {
    if (surfaceArgbs.length === 0) throw new Error('surfaceArgbs is empty');
    const surfaces = surfaceArgbs;
    const usage = opts.usage ?? Usage.border;
    const model = opts.colorModel ?? defaultColorModel;
    const key = `${usage}|${model}|${surfaces.join(',')}`;
    const hit = this.borders.get(key);
    if (hit !== undefined) return hit;
    const result = this.solveSharedBorder(surfaces, usage, model);
    this.borders.set(key, result);
    return result;
  }

  private solveSharedBorder(
    surfaces: readonly Argb[],
    usage: Usage,
    model: ColorModel,
  ): SharedBorder {
    const algo = this.algo;
    const target = getAbsoluteContrast(algo, this.contrast, usage);
    const rests = surfaces.map((s) => Hct.fromInt(s, model));
    const surfaceYs = surfaces.map((s) => luminance(algo, s));
    const tones = surfaces.map((s) => lstarFromArgb(s));
    const darkest = Math.min(...tones);
    const lightest = Math.max(...tones);

    const memo = new Map<number, Argb[]>();
    const bordersAt = (t: number): Argb[] => {
      let bs = memo.get(t);
      if (bs === undefined) {
        bs = rests.map((h) => Hct.from(h.hue, h.chroma, t, model).toInt());
        memo.set(t, bs);
      }
      return bs;
    };
    const backgroundWorst = (t: number): number => {
      if (this.luminances.length === 0) return -Infinity;
      let worst = Infinity;
      for (const b of bordersAt(t)) worst = Math.min(worst, this.nearestContrast(luminance(algo, b)));
      return worst;
    };
    const surfacesWorst = (t: number): number => {
      const bs = bordersAt(t);
      let worst = Infinity;
      for (let i = 0; i < bs.length; i++) {
        worst = Math.min(worst, contrastOfYs(algo, luminance(algo, bs[i]!), surfaceYs[i]!));
      }
      return worst;
    };
    const at = (t: number): SharedBorder => {
      const bg = backgroundWorst(t);
      const clears = bg >= target;
      const surf = clears ? Infinity : surfacesWorst(t);
      return new SharedBorder(
        t, Object.freeze([...bordersAt(t)]), clears, clears || surf >= target, clears ? bg : surf);
    };
    const valid = (t: number) => backgroundWorst(t) >= target || surfacesWorst(t) >= target;

    for (let t = Math.floor(darkest); t >= 0; t--) if (valid(t)) return at(t);
    for (let t = Math.ceil(lightest); t <= 100; t++) if (valid(t)) return at(t);
    const mean = tones.reduce((a, b) => a + b, 0) / tones.length;
    let between: number | undefined;
    for (let t = Math.ceil(darkest); t <= Math.floor(lightest); t++) {
      if (valid(t) && (between === undefined || Math.abs(t - mean) < Math.abs(between - mean))) between = t;
    }
    if (between !== undefined) return at(between);

    let best = 0;
    let bestWorst = -Infinity;
    for (let t = 0; t <= 100; t++) {
      const w = Math.max(backgroundWorst(t), surfacesWorst(t));
      if (w > bestWorst) { bestWorst = w; best = t; }
    }
    return at(best);
  }

  /** Weakest contrast of luminance y against any pixel; only neighbors can be weakest. */
  private nearestContrast(y: number): number {
    const ys = this.luminances;
    let lo = 0, hi = ys.length;
    while (lo < hi) {
      const mid = (lo + hi) >> 1;
      if (ys[mid]! < y) lo = mid + 1; else hi = mid;
    }
    let worst = Infinity;
    if (lo < ys.length) worst = Math.min(worst, contrastOfYs(this.algo, y, ys[lo]!));
    if (lo > 0) worst = Math.min(worst, contrastOfYs(this.algo, y, ys[lo - 1]!));
    return worst;
  }
}

// =============================================================================
// Internals.
// =============================================================================

/** Luminance in algo's own space: APCA's per-channel Y, or WCAG's Y (0..100). */
function luminance(algo: Algo, argb: Argb): number {
  return algo === Algo.apca ? apcaYFromArgb(argb) : yFromLstar(lstarFromArgb(argb));
}

/** Absolute contrast between luminances, stronger polarity. */
function contrastOfYs(algo: Algo, a: number, b: number): number {
  if (algo === Algo.apca) {
    return Math.max(Math.abs(apcaContrastOfApcaY(a, b)), Math.abs(apcaContrastOfApcaY(b, a)));
  }
  return (Math.max(a, b) + 5) / (Math.min(a, b) + 5);
}

/** 8-bit source-over blend of scrim at alpha a (0..255) onto opaque bg. */
function blendArgb(bg: Argb, scrim: Argb, a: number): Argb {
  const ch = (b: number, s: number) => Math.round(((255 - a) * b + a * s) / 255);
  return argbFromRgb(
    ch(redFromArgb(bg), redFromArgb(scrim)),
    ch(greenFromArgb(bg), greenFromArgb(scrim)),
    ch(blueFromArgb(bg), blueFromArgb(scrim)),
  );
}

interface Outcome {
  allPass: boolean;
  oneSided: boolean;
  worstAbs: number;
  polarity: Polarity;
}

function evaluate(
  content: Argb, pixels: Argb[], target: number, algo: Algo, scrim: Argb, a: number,
): Outcome {
  const contentY = luminance(algo, content);
  let allPass = true;
  let anyLow = false, anyHigh = false;
  let worst = Infinity;
  for (const px of pixels) {
    const blended = blendArgb(px, scrim, a);
    const c = Math.abs(contrastBetweenArgbs(algo, blended, content));
    if (c < worst) worst = c;
    if (c < target) allPass = false;
    if (luminance(algo, blended) < contentY) anyLow = true; else anyHigh = true;
  }
  return {
    allPass,
    oneSided: !(anyLow && anyHigh),
    worstAbs: worst,
    polarity: anyHigh && !anyLow ? Polarity.darkOnLight : Polarity.lightOnDark,
  };
}

function solveForScrimColor(
  content: Argb, pixels: Argb[], target: number, algo: Algo, scrim: Argb, canMix: boolean,
): Scrim {
  const outcomes: Outcome[] = [];
  for (let a = 0; a <= 255; a++) outcomes.push(evaluate(content, pixels, target, algo, scrim, a));

  // Lowest alpha such that it and every higher alpha passes one-sided.
  let solved: number | undefined;
  for (let a = 255; a >= 0; a--) {
    const o = outcomes[a]!;
    if (o.allPass && o.oneSided) solved = a; else break;
  }
  if (solved === undefined) {
    const at = outcomes[255]!;
    return new Scrim(scrim, 1.0, false, at.worstAbs, at.polarity, false);
  }
  let mixed = false;
  for (let a = 0; canMix && a < solved; a++) {
    const o = outcomes[a]!;
    if (o.allPass && !o.oneSided) { mixed = true; break; }
  }
  const at = outcomes[solved]!;
  return new Scrim(scrim, solved / 255, true, at.worstAbs, at.polarity, mixed);
}

// Standard normal CDF via Abramowitz & Stegun 7.1.26 (|err| < 1.5e-7).
// Keep bit-identical with lib/effects/over_image.dart.
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

/** Blur radius to the sigma Skia blurs with (SkBlurMask::ConvertRadiusToSigma). */
function convertRadiusToSigma(radius: number): number {
  return radius > 0 ? radius * 0.57735 + 0.5 : 0;
}
