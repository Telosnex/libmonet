import {type Argb, blueFromArgb, greenFromArgb, redFromArgb} from './color.js';
import {linearized, delinearized} from './hct.js';

export const whitePointD65 = [95.047, 100.0, 108.883] as const;
export const kSrgbToXyz = [
  [0.41233895, 0.35762064, 0.18051042],
  [0.2126, 0.7152, 0.0722],
  [0.01932141, 0.11916382, 0.95034478],
] as const;

function labF(t: number): number {
  const e = 216 / 24389;
  const kappa = 24389 / 27;
  return t > e ? Math.cbrt(t) : (kappa * t + 16) / 116;
}

function labInvf(ft: number): number {
  const e = 216 / 24389;
  const kappa = 24389 / 27;
  const ft3 = ft * ft * ft;
  return ft3 > e ? ft3 : (116 * ft - 16) / kappa;
}

export function linear(rgbComponent: number): number {
  return linearized(rgbComponent / 255) * 100;
}

export function delinear(rgbComponent: number): number {
  return Math.round(Math.min(255, Math.max(0, delinearized(rgbComponent / 100) * 255)));
}

export function labFromArgb(argb: Argb): [number, number, number] {
  const linearR = linear(redFromArgb(argb));
  const linearG = linear(greenFromArgb(argb));
  const linearB = linear(blueFromArgb(argb));
  const x = kSrgbToXyz[0][0] * linearR + kSrgbToXyz[0][1] * linearG + kSrgbToXyz[0][2] * linearB;
  const y = kSrgbToXyz[1][0] * linearR + kSrgbToXyz[1][1] * linearG + kSrgbToXyz[1][2] * linearB;
  const z = kSrgbToXyz[2][0] * linearR + kSrgbToXyz[2][1] * linearG + kSrgbToXyz[2][2] * linearB;
  const fx = labF(x / whitePointD65[0]);
  const fy = labF(y / whitePointD65[1]);
  const fz = labF(z / whitePointD65[2]);
  return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}

export function argbFromXyz(x: number, y: number, z: number): Argb {
  const linearR = 3.2413774792388685 * x + -1.5376652402851851 * y + -0.49885366846268053 * z;
  const linearG = -0.9691452513005321 * x + 1.8758853451067872 * y + 0.04156585616912061 * z;
  const linearB = 0.05562093689691305 * x + -0.20395524564742123 * y + 1.0571799111220335 * z;
  return ((0xff << 24) | (delinear(linearR) << 16) | (delinear(linearG) << 8) | delinear(linearB)) >>> 0;
}

export function argbFromLab(l: number, a: number, b: number): Argb {
  const fy = (l + 16) / 116;
  const fx = a / 500 + fy;
  const fz = fy - b / 200;
  return argbFromXyz(labInvf(fx) * whitePointD65[0], labInvf(fy) * whitePointD65[1], labInvf(fz) * whitePointD65[2]);
}
