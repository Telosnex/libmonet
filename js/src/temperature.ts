import {afterimageComplement} from './afterimage.js';
import {Hct, sanitizeDegreesDouble, type ColorModel} from './hct.js';
import {analogous as uvAnalogous} from './uv-harmony.js';
import {xyzFromArgb} from './oklch.js';
import {labFromArgb} from './xyz-lab.js';

export function sanitizeDegreesInt(degrees: number): number {
  degrees = Math.trunc(degrees) % 360;
  return degrees < 0 ? degrees + 360 : degrees;
}

export function isBetween(angle: number, a: number, b: number): boolean {
  if (a < b) return a <= angle && angle <= b;
  return a <= angle || angle <= b;
}

/**
 * Perceived warmth of a color: Chang & Ou (2026), the canonical model.
 * Signed distance from the color's CIE 1976 u'v' chromaticity to a
 * reference line of neutral warmth through Illuminant D75. Must be kept in
 * sync with lib/effects/temperature.dart.
 */
export function rawTemperature(color: Hct): number {
  const [x, y, z] = xyzFromArgb(color.toInt());
  const denom = x + 15 * y + 3 * z;
  if (Math.abs(denom) < 1e-9) return 0;
  const u = 4 * x / denom;
  const v = 9 * y / denom;
  const k = 1298.3, a = 2.2175, b = 1, c = -0.8877;
  return k * (a * u + b * v + c) / Math.sqrt(a * a + b * b);
}

/**
 * Warm-cool per Ou, Woodcock and Wright (2004), in CIELAB - the model
 * Material Color Utilities used. Kept for comparison with newer models.
 */
export function rawTemperature2004(color: Hct): number {
  const lab = labFromArgb(color.toInt());
  const hue = sanitizeDegreesDouble(Math.atan2(lab[2]!, lab[1]!) * 180 / Math.PI);
  const chroma = Math.sqrt(lab[1]! * lab[1]! + lab[2]! * lab[2]!);
  return -0.5 + 0.02 * Math.pow(chroma, 1.07) * Math.cos(sanitizeDegreesDouble(hue - 50) * Math.PI / 180);
}

/**
 * Warm-cool per Ou et al.'s "universal model" (2018). Kept for comparison.
 */
export function rawTemperature2018(color: Hct): number {
  const lab = labFromArgb(color.toInt());
  const hue = sanitizeDegreesDouble(Math.atan2(lab[2]!, lab[1]!) * 180 / Math.PI);
  const chroma = Math.sqrt(lab[1]! * lab[1]! + lab[2]! * lab[2]!);
  const radians = Math.PI / 180;
  return -0.89 + 0.052 * chroma * (
      Math.cos(sanitizeDegreesDouble(hue - 50) * radians) +
      0.16 * Math.cos(sanitizeDegreesDouble(2 * hue - 350) * radians));
}

/// Hue of the warmest color, per hue space of the given color model.
/// Poles fit against Chang-Ou 2026 on unclamped colors; must be kept in
/// sync with lib/effects/temperature.dart.
export function warmestHue(model: ColorModel): number {
  switch (model) {
    case 'cam16':
      return 44;
    case 'cam16v11':
      return 40;
    case 'oklch':
      return 43;
  }
}

/// Hue of the coolest color, per hue space of the given color model.
export function coolestHue(model: ColorModel): number {
  switch (model) {
    case 'cam16':
      return 227;
    case 'cam16v11':
      return 230;
    case 'oklch':
      return 225;
  }
}

/**
 * Design utilities using color temperature theory.
 *
 * Analogous colors, complementary color, and relative temperature, computed
 * in closed form directly in HCT.
 *
 * Relative temperature is modeled as a "warped cosine" in hue: +1 at the warm
 * pole, -1 at the cool pole. The poles were fit against Ou, Woodcock and
 * Wright's CIELAB warm-cool formula evaluated on unclamped CAM16 colors
 * (JCH -> XYZ -> L*a*b*), so no gamut search is required. Must be kept in
 * sync with lib/effects/temperature.dart.
 */
export class TemperatureCache {
  constructor(readonly input: Hct) {}

  get warmest(): Hct {
    return Hct.from(warmestHue(this.input.colorModel), this.input.chroma, this.input.tone, this.input.colorModel);
  }

  get coldest(): Hct {
    return Hct.from(coolestHue(this.input.colorModel), this.input.chroma, this.input.tone, this.input.colorModel);
  }

  /**
   * A set of colors with differing hues, equidistant in temperature.
   * [count] colors, including the input color, on a wheel divided into
   * [divisions].
   */
  analogous(count = 5, divisions = 12): Hct[] {
    // Historical signature, new geometry: divisions now mean 360/divisions
    // degrees of u'v' chromatic direction per step around the white point.
    return uvAnalogous(this.input, {count, step: 360 / divisions});
  }

  /**
   * The color that complements the input, defined physiologically: the
   * afterimage the eye produces after adapting to the input. An additive
   * mixture of the input and its complement is neutral gray. Rendered at
   * the input's tone; chroma is NOT preserved.
   */
  get complement(): Hct {
    return afterimageComplement(this.input);
  }

  /**
   * Temperature relative to all colors with the same chroma and tone.
   * Value on a scale from 0 to 1.
   */
  relativeTemperature(hct: Hct): number {
    // Achromatic colors have no meaningful hue; treat as mid-temperature.
    // Thresholds mirror the achromatic short-circuit in the HCT solver.
    if (hct.chroma < 0.0001 || hct.tone < 0.0001 || hct.tone > 99.9999) {
      return 0.5;
    }
    const position = this.cyclePosition(hct.hue);
    return position <= 1 ? 1 - position : position - 1;
  }

  get inputRelativeTemperature(): number {
    return this.relativeTemperature(this.input);
  }

  /**
   * Position of [hue] on the warm-cool cycle, in [0, 2): 0 at the warm pole,
   * 1 at the cool pole, wrapping back to warm at 2. Equal steps in position
   * are equal steps in temperature.
   */
  private cyclePosition(hue: number): number {
    const warmHue = warmestHue(this.input.colorModel);
    const coolHue = coolestHue(this.input.colorModel);
    const warmToCoolArc = sanitizeDegreesDouble(coolHue - warmHue);
    const coolToWarmArc = 360 - warmToCoolArc;
    const fromWarm = sanitizeDegreesDouble(hue - warmHue);
    if (fromWarm <= warmToCoolArc) {
      const fraction = fromWarm / warmToCoolArc;
      return (1 - Math.cos(Math.PI * fraction)) / 2;
    }
    const fraction = sanitizeDegreesDouble(hue - coolHue) / coolToWarmArc;
    return 1 + (1 - Math.cos(Math.PI * fraction)) / 2;
  }

  /** Inverse of [cyclePosition]; [position] is taken modulo 2. */
  private hueAtCyclePosition(position: number): number {
    const warmHue = warmestHue(this.input.colorModel);
    const coolHue = coolestHue(this.input.colorModel);
    const warmToCoolArc = sanitizeDegreesDouble(coolHue - warmHue);
    const coolToWarmArc = 360 - warmToCoolArc;
    let p = position % 2;
    if (p < 0) p += 2;
    if (p <= 1) {
      const fraction = Math.acos(Math.min(1, Math.max(-1, 1 - 2 * p))) / Math.PI;
      return sanitizeDegreesDouble(warmHue + fraction * warmToCoolArc);
    }
    const fraction = Math.acos(Math.min(1, Math.max(-1, 1 - 2 * (p - 1)))) / Math.PI;
    return sanitizeDegreesDouble(coolHue + fraction * coolToWarmArc);
  }
}
