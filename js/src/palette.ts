import {Hct, lstarFromArgb, type ColorModel} from './hct.js';
import {type Argb, hexFromArgb} from './color.js';
import {Algo, Usage, ContrastDirection, clamp, contrastingTone, contrastBetweenArgbs, getAbsoluteContrast, lighterLstarUnsafe, darkerLstarUnsafe, lstarPrefersLighterPair} from './contrast.js';

export interface PaletteOptions { backgroundTone: number; contrast?: number; algo?: Algo; colorModel?: ColorModel }
export interface PaletteWithBackgroundOptions { contrast?: number; algo?: Algo; colorModel?: ColorModel }

export type PaletteRole =
  | 'background' | 'backgroundText' | 'backgroundFill' | 'backgroundBorder'
  | 'backgroundHovered' | 'backgroundSplashed' | 'backgroundHoveredFill' | 'backgroundSplashedFill'
  | 'backgroundHoveredText' | 'backgroundSplashedText' | 'backgroundHoveredBorder' | 'backgroundSplashedBorder'
  | 'color' | 'colorText' | 'colorIcon' | 'colorHovered' | 'colorSplashed'
  | 'colorHoveredText' | 'colorSplashedText' | 'colorHoveredIcon' | 'colorSplashedIcon'
  | 'colorBorder' | 'colorHoveredBorder' | 'colorSplashedBorder'
  | 'fill' | 'fillText' | 'fillIcon' | 'fillHovered' | 'fillSplashed'
  | 'fillHoveredText' | 'fillSplashedText' | 'fillHoveredIcon' | 'fillSplashedIcon'
  | 'fillBorder' | 'fillHoveredBorder' | 'fillSplashedBorder'
  | 'text' | 'textHovered' | 'textSplashed' | 'textHoveredText' | 'textSplashedText';

export const paletteRoles: readonly PaletteRole[] = [
  'background','backgroundText','backgroundFill','backgroundBorder','backgroundHovered','backgroundSplashed','backgroundHoveredFill','backgroundSplashedFill','backgroundHoveredText','backgroundSplashedText','backgroundHoveredBorder','backgroundSplashedBorder','color','colorText','colorIcon','colorHovered','colorSplashed','colorHoveredText','colorSplashedText','colorHoveredIcon','colorSplashedIcon','colorBorder','colorHoveredBorder','colorSplashedBorder','fill','fillText','fillIcon','fillHovered','fillSplashed','fillHoveredText','fillSplashedText','fillHoveredIcon','fillSplashedIcon','fillBorder','fillHoveredBorder','fillSplashedBorder','text','textHovered','textSplashed','textHoveredText','textSplashedText'
] as const;

export class Palette {
  static from(color: Argb, options: PaletteOptions): Palette {
    const colorModel = options.colorModel ?? 'cam16v11';
    const hct = Hct.fromInt(color, colorModel);
    const bg = Hct.from(hct.hue, Math.min(16, hct.chroma), options.backgroundTone, colorModel).toInt();
    return new Palette(color, bg, options.backgroundTone, options.contrast ?? 0.5, options.algo ?? Algo.apca, colorModel);
  }

  static fromColorAndBackground(color: Argb, background: Argb, options: PaletteWithBackgroundOptions = {}): Palette {
    return new Palette(color, background, undefined, options.contrast ?? 0.5, options.algo ?? Algo.apca, options.colorModel ?? 'cam16v11');
  }

  private readonly colorHct: Hct;
  private readonly backgroundHct: Hct;
  private readonly colorHue: number;
  private readonly colorChroma: number;
  private readonly colorTone: number;
  private readonly backgroundHue: number;
  private readonly backgroundChroma: number;
  private readonly backgroundTone: number;

  private readonly cache = new Map<PaletteRole | string, Argb | number | ContrastDirection>();

  private constructor(
    private readonly baseColor: Argb,
    private readonly baseBackground: Argb,
    private readonly backgroundToneOverride: number | undefined,
    private readonly contrast: number,
    private readonly algo: Algo,
    readonly colorModel: ColorModel,
  ) {
    this.colorHct = Hct.fromInt(this.baseColor, this.colorModel);
    this.backgroundHct = Hct.fromInt(this.baseBackground, this.colorModel);
    this.colorHue = this.colorHct.hue;
    this.colorChroma = Math.max(this.colorHct.chroma, this.backgroundHct.chroma);
    this.colorTone = this.colorHct.tone;
    this.backgroundHue = this.backgroundHct.hue;
    this.backgroundChroma = this.backgroundHct.chroma;
    this.backgroundTone = this.backgroundToneOverride ?? this.backgroundHct.tone;
  }

  private solve(containerTone: number, containerArgb: Argb, targetHue: number, targetChroma: number, usage: Usage, dial: number, direction?: ContrastDirection): number {
    return contrastingTone({withArgb: containerArgb, withTone: containerTone, targetHue, targetChroma, usage, by: this.algo, contrast: dial, colorModel: this.colorModel, ...(direction === undefined ? {} : {forceDirection: direction})});
  }
  private withColorsChroma(tone: number): Argb { return Hct.from(this.colorHue, this.colorChroma, tone, this.colorModel).toInt(); }
  private withBackgroundsChroma(tone: number): Argb { return Hct.from(this.backgroundHue, this.backgroundChroma, tone, this.colorModel).toInt(); }
  private memo<T extends Argb | number | ContrastDirection>(key: string, fn: () => T): T {
    if (!this.cache.has(key)) this.cache.set(key, fn());
    return this.cache.get(key) as T;
  }

  private get bgTextTone(): number { return this.memo('bgTextTone', () => this.solve(this.backgroundTone, this.baseBackground, this.backgroundHue, this.backgroundChroma, Usage.text, this.contrast)); }
  private get bgDirection(): ContrastDirection { return this.memo('bgDirection', () => this.bgTextTone >= this.backgroundTone ? ContrastDirection.lighter : ContrastDirection.darker); }
  private get fillTextTone(): number { return this.memo('fillTextTone', () => this.solve(this.bgFillTone, this.fill, this.colorHue, this.colorChroma, Usage.text, this.contrast)); }
  private get fillDirection(): ContrastDirection { return this.memo('fillDirection', () => this.fillTextTone >= this.bgFillTone ? ContrastDirection.lighter : ContrastDirection.darker); }
  private get colorTextTone(): number { return this.memo('colorTextTone', () => this.solve(this.colorTone, this.baseColor, this.colorHue, this.colorChroma, Usage.text, this.contrast)); }
  private get colorDirection(): ContrastDirection { return this.memo('colorDirection', () => this.colorTextTone >= this.colorTone ? ContrastDirection.lighter : ContrastDirection.darker); }
  private get hoverDial(): number { return Math.max(this.contrast - 0.3, 0.1); }
  private get splashDial(): number { return Math.max(this.contrast - 0.15, 0.25); }
  private get borderContrast(): number { return getAbsoluteContrast(this.algo, this.contrast, Usage.border); }
  private get fgContrast(): number { return getAbsoluteContrast(this.algo, this.contrast, Usage.fill); }
  private get bgFillTone(): number { return this.memo('bgFillTone', () => this.solve(this.backgroundTone, this.baseBackground, this.colorHue, this.colorChroma, Usage.fill, this.contrast, this.bgDirection)); }
  private get bgHoverTone(): number { return this.memo('bgHoverTone', () => this.solve(this.backgroundTone, this.baseBackground, this.colorHue, this.colorChroma, Usage.fill, this.hoverDial, this.bgDirection)); }
  private get bgSplashTone(): number { return this.memo('bgSplashTone', () => this.solve(this.backgroundTone, this.baseBackground, this.colorHue, this.colorChroma, Usage.fill, this.splashDial, this.bgDirection)); }
  private get colorHoverTone(): number { return this.memo('colorHoverTone', () => this.solve(this.colorTone, this.baseColor, this.colorHue, this.colorChroma, Usage.fill, this.hoverDial, this.colorDirection)); }
  private get colorSplashTone(): number { return this.memo('colorSplashTone', () => this.solve(this.colorTone, this.baseColor, this.colorHue, this.colorChroma, Usage.fill, this.splashDial, this.colorDirection)); }
  private get fillHoverTone(): number { return this.memo('fillHoverTone', () => this.solve(this.bgFillTone, this.fill, this.colorHue, this.colorChroma, Usage.fill, this.hoverDial, this.fillDirection)); }
  private get fillSplashTone(): number { return this.memo('fillSplashTone', () => this.solve(this.bgFillTone, this.fill, this.colorHue, this.colorChroma, Usage.fill, this.splashDial, this.fillDirection)); }
  private get bgHoverTextTone(): number { return this.memo('bgHoverTextTone', () => this.solve(this.bgHoverTone, this.backgroundHovered, this.colorHue, this.colorChroma, Usage.text, this.contrast)); }
  private get bgHoverDirection(): ContrastDirection { return this.memo('bgHoverDirection', () => this.bgHoverTextTone >= this.bgHoverTone ? ContrastDirection.lighter : ContrastDirection.darker); }
  private get bgSplashTextTone(): number { return this.memo('bgSplashTextTone', () => this.solve(this.bgSplashTone, this.backgroundSplashed, this.colorHue, this.colorChroma, Usage.text, this.contrast)); }
  private get bgSplashDirection(): ContrastDirection { return this.memo('bgSplashDirection', () => this.bgSplashTextTone >= this.bgSplashTone ? ContrastDirection.lighter : ContrastDirection.darker); }
  private get colorHoverTextTone(): number { return this.memo('colorHoverTextTone', () => this.solve(this.colorHoverTone, this.colorHovered, this.colorHue, this.colorChroma, Usage.text, this.contrast)); }
  private get colorHoverDirection(): ContrastDirection { return this.memo('colorHoverDirection', () => this.colorHoverTextTone >= this.colorHoverTone ? ContrastDirection.lighter : ContrastDirection.darker); }
  private get colorSplashTextTone(): number { return this.memo('colorSplashTextTone', () => this.solve(this.colorSplashTone, this.colorSplashed, this.colorHue, this.colorChroma, Usage.text, this.contrast)); }
  private get colorSplashDirection(): ContrastDirection { return this.memo('colorSplashDirection', () => this.colorSplashTextTone >= this.colorSplashTone ? ContrastDirection.lighter : ContrastDirection.darker); }
  private get fillHoverTextTone(): number { return this.memo('fillHoverTextTone', () => this.solve(this.fillHoverTone, this.fillHovered, this.colorHue, this.colorChroma, Usage.text, this.contrast)); }
  private get fillHoverDirection(): ContrastDirection { return this.memo('fillHoverDirection', () => this.fillHoverTextTone >= this.fillHoverTone ? ContrastDirection.lighter : ContrastDirection.darker); }
  private get fillSplashTextTone(): number { return this.memo('fillSplashTextTone', () => this.solve(this.fillSplashTone, this.fillSplashed, this.colorHue, this.colorChroma, Usage.text, this.contrast)); }
  private get fillSplashDirection(): ContrastDirection { return this.memo('fillSplashDirection', () => this.fillSplashTextTone >= this.fillSplashTone ? ContrastDirection.lighter : ContrastDirection.darker); }
  private get textHoverTone(): number { return this.memo('textHoverTone', () => this.solve(this.backgroundTone, this.baseBackground, this.colorHue, this.colorChroma, Usage.text, this.hoverDial, this.bgDirection)); }
  private get textSplashTone(): number { return this.memo('textSplashTone', () => this.solve(this.backgroundTone, this.baseBackground, this.colorHue, this.colorChroma, Usage.text, this.splashDial, this.bgDirection)); }

  get background(): Argb { return this.baseBackground; }
  get backgroundText(): Argb { return this.withBackgroundsChroma(this.bgTextTone); }
  get backgroundFill(): Argb { return this.withBackgroundsChroma(this.bgFillTone); }
  get backgroundHovered(): Argb { return this.withColorsChroma(this.bgHoverTone); }
  get backgroundSplashed(): Argb { return this.withColorsChroma(this.bgSplashTone); }
  get backgroundHoveredText(): Argb { return this.withColorsChroma(this.bgHoverTextTone); }
  get backgroundSplashedText(): Argb { return this.withColorsChroma(this.bgSplashTextTone); }
  get backgroundHoveredFill(): Argb { return this.withColorsChroma(this.solve(this.bgHoverTone, this.backgroundHovered, this.colorHue, this.colorChroma, Usage.fill, this.contrast, this.bgHoverDirection)); }
  get backgroundSplashedFill(): Argb { return this.withColorsChroma(this.solve(this.bgSplashTone, this.backgroundSplashed, this.colorHue, this.colorChroma, Usage.fill, this.contrast, this.bgSplashDirection)); }
  get color(): Argb { return this.baseColor; }
  get colorText(): Argb { return this.withColorsChroma(this.colorTextTone); }
  get colorIcon(): Argb { return this.withColorsChroma(this.solve(this.colorTone, this.baseColor, this.colorHue, this.colorChroma, Usage.fill, this.contrast, this.colorDirection)); }
  get colorHovered(): Argb { return this.withColorsChroma(this.colorHoverTone); }
  get colorSplashed(): Argb { return this.withColorsChroma(this.colorSplashTone); }
  get colorHoveredText(): Argb { return this.withColorsChroma(this.colorHoverTextTone); }
  get colorSplashedText(): Argb { return this.withColorsChroma(this.colorSplashTextTone); }
  get colorHoveredIcon(): Argb { return this.withColorsChroma(this.solve(this.colorHoverTone, this.colorHovered, this.colorHue, this.colorChroma, Usage.fill, this.contrast, this.colorHoverDirection)); }
  get colorSplashedIcon(): Argb { return this.withColorsChroma(this.solve(this.colorSplashTone, this.colorSplashed, this.colorHue, this.colorChroma, Usage.fill, this.contrast, this.colorSplashDirection)); }
  get fill(): Argb { return this.withColorsChroma(this.bgFillTone); }
  get fillText(): Argb { return this.withColorsChroma(this.fillTextTone); }
  get fillIcon(): Argb { return this.withColorsChroma(this.solve(this.bgFillTone, this.fill, this.colorHue, this.colorChroma, Usage.fill, this.contrast, this.fillDirection)); }
  get fillHovered(): Argb { return this.withColorsChroma(this.fillHoverTone); }
  get fillSplashed(): Argb { return this.withColorsChroma(this.fillSplashTone); }
  get fillHoveredText(): Argb { return this.withColorsChroma(this.fillHoverTextTone); }
  get fillSplashedText(): Argb { return this.withColorsChroma(this.fillSplashTextTone); }
  get fillHoveredIcon(): Argb { return this.withColorsChroma(this.solve(this.fillHoverTone, this.fillHovered, this.colorHue, this.colorChroma, Usage.fill, this.contrast, this.fillHoverDirection)); }
  get fillSplashedIcon(): Argb { return this.withColorsChroma(this.solve(this.fillSplashTone, this.fillSplashed, this.colorHue, this.colorChroma, Usage.fill, this.contrast, this.fillSplashDirection)); }
  get text(): Argb { return this.withColorsChroma(this.bgTextTone); }
  get textHovered(): Argb { return this.withColorsChroma(this.textHoverTone); }
  get textSplashed(): Argb { return this.withColorsChroma(this.textSplashTone); }
  get textHoveredText(): Argb { return this.withColorsChroma(this.solve(this.textHoverTone, this.textHovered, this.colorHue, this.colorChroma, Usage.text, this.contrast)); }
  get textSplashedText(): Argb { return this.withColorsChroma(this.solve(this.textSplashTone, this.textSplashed, this.colorHue, this.colorChroma, Usage.text, this.contrast)); }

  get backgroundBorder(): Argb { return this.withBackgroundsChroma(this.solveBorderTone(this.backgroundTone, this.baseBackground, this.backgroundHue, this.backgroundChroma)); }
  get colorBorder(): Argb { return this.solveEitherSideBorder(this.colorTone, this.colorTone, this.backgroundTone, this.colorHue, this.colorChroma); }
  get fillBorder(): Argb { return this.solveEitherSideBorder(this.bgFillTone, this.colorTone, this.backgroundTone, this.colorHue, this.colorChroma); }
  get backgroundHoveredBorder(): Argb { return this.overlayBorder(this.bgHoverTone); }
  get backgroundSplashedBorder(): Argb { return this.overlayBorder(this.bgSplashTone); }
  get colorHoveredBorder(): Argb { return this.overlayBorder(this.colorHoverTone); }
  get colorSplashedBorder(): Argb { return this.overlayBorder(this.colorSplashTone); }
  get fillHoveredBorder(): Argb { return this.overlayBorder(this.fillHoverTone); }
  get fillSplashedBorder(): Argb { return this.overlayBorder(this.fillSplashTone); }

  private solveBorderTone(containerTone: number, containerArgb: Argb, hue: number, chroma: number): number {
    const darker = ContrastDirection.darker, lighter = ContrastDirection.lighter;
    const usage = Usage.border;
    const meets = (t: number) => Math.abs(contrastBetweenArgbs(this.algo, containerArgb, Hct.from(hue, chroma, t, this.colorModel).toInt())) >= this.borderContrast;
    const tones = [this.solve(containerTone, containerArgb, hue, chroma, usage, this.contrast, darker), this.solve(containerTone, containerArgb, hue, chroma, usage, this.contrast, lighter)].filter(meets);
    if (tones.length === 0) return this.solve(containerTone, containerArgb, hue, chroma, usage, this.contrast, lighter);
    return (tones.filter(t => t < containerTone)[0] ?? tones[0])!;
  }

  private overlayBorder(overlayTone: number): Argb {
    const overlayArgb = this.withColorsChroma(overlayTone);
    const vsOverlay = Math.abs(contrastBetweenArgbs(this.algo, overlayArgb, this.baseColor));
    const vsBg = Math.abs(contrastBetweenArgbs(this.algo, this.baseBackground, this.baseColor));
    if (vsOverlay >= this.borderContrast && vsBg >= this.borderContrast) return this.baseColor;
    return this.withColorsChroma(this.twoRefBorderTone(overlayTone, overlayArgb, this.backgroundTone, this.baseBackground, this.colorHue, this.colorChroma));
  }

  private candidate(startTone: number, refArgb: Argb, hue: number, chroma: number, lighter: boolean): number {
    if (this.algo === Algo.wcag21) {
      return lighter
        ? lighterLstarUnsafe(startTone, this.borderContrast)
        : darkerLstarUnsafe(startTone, this.borderContrast);
    }
    const lcAt = (t: number) => Math.abs(contrastBetweenArgbs(this.algo, refArgb, Hct.from(hue, chroma, t, this.colorModel).toInt()));
    if (lighter) {
      if (lcAt(100) < this.borderContrast) return 101;
      let lo = startTone, hi = 100; for (let i = 0; i < 15; i++) { const m = (lo + hi) / 2; if (lcAt(m) >= this.borderContrast) hi = m; else lo = m; } return hi;
    }
    if (lcAt(0) < this.borderContrast) return -1;
    let lo = 0, hi = startTone; for (let i = 0; i < 15; i++) { const m = (lo + hi) / 2; if (lcAt(m) >= this.borderContrast) lo = m; else hi = m; } return lo;
  }

  private solveEitherSideBorder(innerTone: number, baseTone: number, backgroundTone: number, hue: number, chroma: number): Argb {
    const bgArgb = backgroundTone === this.backgroundTone
      ? this.baseBackground
      : Hct.from(this.backgroundHue, this.backgroundChroma, backgroundTone, this.colorModel).toInt();
    const innerArgb = innerTone === this.colorTone
      ? this.baseColor
      : Hct.from(hue, chroma, innerTone, this.colorModel).toInt();
    const fgVsBg = Math.max(Math.abs(contrastBetweenArgbs(this.algo, bgArgb, innerArgb)), Math.abs(contrastBetweenArgbs(this.algo, innerArgb, bgArgb)));
    if (fgVsBg >= this.fgContrast) return Hct.from(hue, chroma, innerTone, this.colorModel).toInt();
    const candidates = [
      this.candidate(backgroundTone, bgArgb, hue, chroma, true), this.candidate(backgroundTone, bgArgb, hue, chroma, false),
      this.candidate(innerTone, innerArgb, hue, chroma, true), this.candidate(innerTone, innerArgb, hue, chroma, false), baseTone,
    ].filter(t => t >= 0 && t <= 100).map(t => clamp(t, 0, 100));
    const scored = candidates.map(t => {
      const argb = Hct.from(hue, chroma, t, this.colorModel).toInt();
      const lcBg = Math.abs(contrastBetweenArgbs(this.algo, bgArgb, argb));
      const lcIn = Math.abs(contrastBetweenArgbs(this.algo, innerArgb, argb));
      return {t, argb, lcBg, lcIn};
    });
    const valid = scored.filter(c => c.lcBg >= this.borderContrast || c.lcIn >= this.borderContrast);
    const preferred = valid.filter(c => c.t < innerTone || Math.abs(c.t - innerTone) <= 1);
    const pool = preferred.length ? preferred : valid;
    if (!pool.length) {
      const costFor = (t: number): number => {
        const argb = Hct.from(hue, chroma, t, this.colorModel).toInt();
        const lcBg = Math.abs(contrastBetweenArgbs(this.algo, bgArgb, argb));
        const lcIn = Math.abs(contrastBetweenArgbs(this.algo, innerArgb, argb));
        return Math.max(0, this.borderContrast - Math.max(lcBg, lcIn));
      };
      const costBlack = costFor(0);
      const costWhite = costFor(100);
      const totalDelta = (t: number) => Math.abs(t - innerTone) + Math.abs(t - backgroundTone);
      const fallbackTone = costBlack < costWhite - 1e-6
        ? 0
        : costWhite < costBlack - 1e-6
          ? 100
          : totalDelta(0) <= totalDelta(100) ? 0 : 100;
      return Hct.from(hue, chroma, fallbackTone, this.colorModel).toInt();
    }
    pool.sort((a, b) => {
      const bestA = Math.max(a.lcBg, a.lcIn);
      const bestB = Math.max(b.lcBg, b.lcIn);
      const costA = Math.max(0, this.borderContrast - bestA);
      const costB = Math.max(0, this.borderContrast - bestB);
      if (Math.abs(costA - costB) > 1e-6) return costA - costB;
      const totalA = Math.abs(a.t - innerTone) + Math.abs(a.t - backgroundTone);
      const totalB = Math.abs(b.t - innerTone) + Math.abs(b.t - backgroundTone);
      if (Math.abs(totalA - totalB) > 1e-6) return totalA - totalB;
      const innerA = Math.abs(a.t - innerTone);
      const innerB = Math.abs(b.t - innerTone);
      if (Math.abs(innerA - innerB) > 1e-6) return innerA - innerB;
      return Math.abs(a.t - backgroundTone) - Math.abs(b.t - backgroundTone);
    });
    return pool[0]!.argb;
  }

  private hasValidContrastHelper(tone: number, backgroundTone: number, colorTone: number): boolean {
    const toneArgb = Hct.from(this.colorHue, this.colorChroma, tone, this.colorModel).toInt();
    const bgArgb = Hct.from(this.backgroundHue, this.backgroundChroma, backgroundTone, this.colorModel).toInt();
    const colorArgb = Hct.from(this.colorHue, this.colorChroma, colorTone, this.colorModel).toInt();
    return Math.abs(contrastBetweenArgbs(this.algo, bgArgb, toneArgb)) >= this.borderContrast ||
      Math.abs(contrastBetweenArgbs(this.algo, colorArgb, toneArgb)) >= this.borderContrast ||
      Math.abs(contrastBetweenArgbs(this.algo, toneArgb, bgArgb)) >= this.borderContrast ||
      Math.abs(contrastBetweenArgbs(this.algo, toneArgb, colorArgb)) >= this.borderContrast;
  }

  private twoRefBorderTone(refA: number, refAArgb: Argb, refB: number, refBArgb: Argb, hue: number, chroma: number): number {
    const delta = (t: number) => Math.abs(t - refA) + Math.abs(t - refB);
    const candidateSet = new Set<number>();
    for (const t of [
      this.candidate(refA, refAArgb, hue, chroma, true),
      this.candidate(refA, refAArgb, hue, chroma, false),
      this.candidate(refB, refBArgb, hue, chroma, true),
      this.candidate(refB, refBArgb, hue, chroma, false),
    ]) {
      if (t >= 0 && t <= 100) candidateSet.add(clamp(t, 0, 100));
    }
    const candidates = Array.from(candidateSet);
    const valid = candidates.filter(t => this.hasValidContrastHelper(t, refA, refB));
    // No tone can meet the required contrast against either reference. Fall
    // back to the core aesthetic rule (mid/dark surfaces pair with lighter
    // companions) instead of comparing tone distances, which is decided by
    // floating-point dust when refA/refB straddle neutral.
    if (!valid.length) return lstarPrefersLighterPair(refA) ? 100 : 0;

    const preferLighter = lstarPrefersLighterPair(refA);
    const directional = valid.filter(t => preferLighter ? t > refA : t < refA);
    const pool = directional.length ? directional : valid;
    pool.sort((a, b) => {
      const diff = delta(a) - delta(b);
      // WCAG candidates can be separated only by floating-point dust
      // (~1e-14), and Dart's private selection honors that. APCA still uses
      // the historical epsilon because its candidates come from iterative
      // ARGB/APCA threshold search and are noisier.
      return this.algo === Algo.wcag21 ? diff : Math.abs(diff) <= 1e-6 ? 0 : diff;
    });
    return pool[0]!;
  }

  toRecord(): Record<PaletteRole, Argb> {
    const out = {} as Record<PaletteRole, Argb>;
    for (const role of paletteRoles) out[role] = this[role];
    return out;
  }

  toHexRecord(): Record<PaletteRole, string> {
    const out = {} as Record<PaletteRole, string>;
    for (const role of paletteRoles) out[role] = hexFromArgb(this[role]);
    return out;
  }
}
