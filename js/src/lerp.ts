import {Hct, lstarFromArgb, sanitizeDegreesDouble} from './hct.js';
import {type Argb} from './color.js';
import {type PaletteRole, paletteRoles} from './palette.js';
import {Palette} from './palette.js';

export type InterpolationStyle = 'cartesian' | 'polar';

export function lerpNumber(a: number, b: number, t: number): number {
  if (t <= 0) return a;
  if (t >= 1) return b;
  return a + (b - a) * t;
}

function shortestHue(a: number, b: number, t: number): number {
  const diff = ((b - a + 540) % 360) - 180;
  return sanitizeDegreesDouble(a + diff * t);
}

export function lerpArgbPolar(a: Argb, b: Argb, t: number): Argb {
  if (t <= 0) return a;
  if (t >= 1) return b;
  const ah = Hct.fromInt(a);
  const bh = Hct.fromInt(b);
  return Hct.from(
    shortestHue(ah.hue, bh.hue, t),
    lerpNumber(ah.chroma, bh.chroma, t),
    lerpNumber(ah.tone, bh.tone, t),
  ).toInt();
}

function cam16v11UcsFromArgb(argb: Argb): {jstar: number; astar: number; bstar: number} {
  const hct = Hct.fromInt(argb);
  // Hct.chroma is CAM16 v1.1 C in the JS HCT implementation.
  // Dart Cam16V11._relativeUcsFromJch uses J derived from Q, but for default
  // viewing conditions J is recoverable from tone-solver CAM as approximately
  // (tone/100)^2 * 100 in the same pathway used by solveToInt seeding.
  const j = Math.max(0, Math.min(100, Math.pow(lstarFromArgb(argb) / 10.0, 2)));
  const hueRadians = hct.hue * Math.PI / 180;
  const jstar = 1.7 * j / (1.0 + 0.007 * j);
  const cstar = 2.4 * Math.log(1.0 + 0.098 * hct.chroma) / 0.098;
  return {jstar, astar: cstar * Math.cos(hueRadians), bstar: cstar * Math.sin(hueRadians)};
}

function cam16v11FromUcs(jstar: number, astar: number, bstar: number, tone: number): Argb {
  const cstar = Math.sqrt(astar * astar + bstar * bstar);
  const chroma = (Math.exp(cstar * 0.098 / 2.4) - 1.0) / 0.098;
  let hue = Math.atan2(bstar, astar) * 180 / Math.PI;
  if (hue < 0) hue += 360;
  void jstar;
  return Hct.from(hue, chroma, tone).toInt();
}

export function lerpArgbCartesian(a: Argb, b: Argb, t: number): Argb {
  if (t <= 0) return a;
  if (t >= 1) return b;
  const au = cam16v11UcsFromArgb(a);
  const bu = cam16v11UcsFromArgb(b);
  return cam16v11FromUcs(
    lerpNumber(au.jstar, bu.jstar, t),
    lerpNumber(au.astar, bu.astar, t),
    lerpNumber(au.bstar, bu.bstar, t),
    lerpNumber(lstarFromArgb(a), lstarFromArgb(b), t),
  );
}

export function lerpArgb(a: Argb, b: Argb, t: number, style: InterpolationStyle = 'cartesian'): Argb {
  return style === 'polar' ? lerpArgbPolar(a, b, t) : lerpArgbCartesian(a, b, t);
}

export class PaletteLerped {
  constructor(
    readonly a: Palette,
    readonly b: Palette,
    readonly t: number,
    readonly interpolationStyle: InterpolationStyle = 'cartesian',
  ) {}

  private lerp(role: PaletteRole): Argb {
    return lerpArgb(this.a[role], this.b[role], this.t, this.interpolationStyle);
  }

  toRecord(): Record<PaletteRole, Argb> {
    const out = {} as Record<PaletteRole, Argb>;
    for (const role of paletteRoles) out[role] = this[role];
    return out;
  }

  get background(): Argb { return this.lerp('background'); }
  get backgroundText(): Argb { return this.lerp('backgroundText'); }
  get backgroundFill(): Argb { return this.lerp('backgroundFill'); }
  get backgroundBorder(): Argb { return this.lerp('backgroundBorder'); }
  get backgroundHovered(): Argb { return this.lerp('backgroundHovered'); }
  get backgroundSplashed(): Argb { return this.lerp('backgroundSplashed'); }
  get backgroundHoveredFill(): Argb { return this.lerp('backgroundHoveredFill'); }
  get backgroundSplashedFill(): Argb { return this.lerp('backgroundSplashedFill'); }
  get backgroundHoveredText(): Argb { return this.lerp('backgroundHoveredText'); }
  get backgroundSplashedText(): Argb { return this.lerp('backgroundSplashedText'); }
  get backgroundHoveredBorder(): Argb { return this.lerp('backgroundHoveredBorder'); }
  get backgroundSplashedBorder(): Argb { return this.lerp('backgroundSplashedBorder'); }
  get color(): Argb { return this.lerp('color'); }
  get colorText(): Argb { return this.lerp('colorText'); }
  get colorIcon(): Argb { return this.lerp('colorIcon'); }
  get colorHovered(): Argb { return this.lerp('colorHovered'); }
  get colorSplashed(): Argb { return this.lerp('colorSplashed'); }
  get colorHoveredText(): Argb { return this.lerp('colorHoveredText'); }
  get colorSplashedText(): Argb { return this.lerp('colorSplashedText'); }
  get colorHoveredIcon(): Argb { return this.lerp('colorHoveredIcon'); }
  get colorSplashedIcon(): Argb { return this.lerp('colorSplashedIcon'); }
  get colorBorder(): Argb { return this.lerp('colorBorder'); }
  get colorHoveredBorder(): Argb { return this.lerp('colorHoveredBorder'); }
  get colorSplashedBorder(): Argb { return this.lerp('colorSplashedBorder'); }
  get fill(): Argb { return this.lerp('fill'); }
  get fillText(): Argb { return this.lerp('fillText'); }
  get fillIcon(): Argb { return this.lerp('fillIcon'); }
  get fillHovered(): Argb { return this.lerp('fillHovered'); }
  get fillSplashed(): Argb { return this.lerp('fillSplashed'); }
  get fillHoveredText(): Argb { return this.lerp('fillHoveredText'); }
  get fillSplashedText(): Argb { return this.lerp('fillSplashedText'); }
  get fillHoveredIcon(): Argb { return this.lerp('fillHoveredIcon'); }
  get fillSplashedIcon(): Argb { return this.lerp('fillSplashedIcon'); }
  get fillBorder(): Argb { return this.lerp('fillBorder'); }
  get fillHoveredBorder(): Argb { return this.lerp('fillHoveredBorder'); }
  get fillSplashedBorder(): Argb { return this.lerp('fillSplashedBorder'); }
  get text(): Argb { return this.lerp('text'); }
  get textHovered(): Argb { return this.lerp('textHovered'); }
  get textSplashed(): Argb { return this.lerp('textSplashed'); }
  get textHoveredText(): Argb { return this.lerp('textHoveredText'); }
  get textSplashedText(): Argb { return this.lerp('textSplashedText'); }
}
