import {type Argb, blueFromArgb, greenFromArgb, redFromArgb} from './color.js';
import {argbFromXyz} from './xyz-lab.js';

export interface Oklch { hue: number; chroma: number; l: number }

function signedCubeRoot(value: number): number {
  return value < 0 ? -Math.cbrt(-value) : Math.cbrt(value);
}

function linearized(srgbNorm: number): number {
  return srgbNorm <= 0.040449936 ? srgbNorm / 12.92 : Math.pow((srgbNorm + 0.055) / 1.055, 2.4);
}

export function xyzFromArgb(argb: Argb): [number, number, number] {
  const r = linearized(redFromArgb(argb) / 255) * 100;
  const g = linearized(greenFromArgb(argb) / 255) * 100;
  const b = linearized(blueFromArgb(argb) / 255) * 100;
  return [
    0.41233895 * r + 0.35762064 * g + 0.18051042 * b,
    0.2126 * r + 0.7152 * g + 0.0722 * b,
    0.01932141 * r + 0.11916382 * g + 0.95034478 * b,
  ];
}

export function oklchFromXyz(x: number, y: number, z: number): Oklch {
  const xn = x / 100.0;
  const yn = y / 100.0;
  const zn = z / 100.0;

  const lmsL = 0.8189330101 * xn + 0.3618667424 * yn - 0.1288597137 * zn;
  const lmsM = 0.0329845436 * xn + 0.9293118715 * yn + 0.0361456387 * zn;
  const lmsS = 0.0482003018 * xn + 0.2643662691 * yn + 0.6338517070 * zn;

  const lRoot = signedCubeRoot(lmsL);
  const mRoot = signedCubeRoot(lmsM);
  const sRoot = signedCubeRoot(lmsS);

  const okL = 0.2104542553 * lRoot + 0.7936177850 * mRoot - 0.0040720468 * sRoot;
  const okA = 1.9779984951 * lRoot - 2.4285922050 * mRoot + 0.4505937099 * sRoot;
  const okB = 0.0259040371 * lRoot + 0.7827717662 * mRoot - 0.8086757660 * sRoot;

  const chroma = Math.sqrt(okA * okA + okB * okB);
  let hue = Math.atan2(okB, okA) * 180.0 / Math.PI;
  if (hue < 0.0) hue += 360.0;
  return {hue, chroma, l: okL};
}

export function oklchFromArgb(argb: Argb): Oklch {
  const [x, y, z] = xyzFromArgb(argb);
  return oklchFromXyz(x, y, z);
}

export function oklchToXyz(l: number, chroma: number, hue: number): [number, number, number] {
  const hueRadians = hue * Math.PI / 180.0;
  const a = chroma * Math.cos(hueRadians);
  const b = chroma * Math.sin(hueRadians);

  const lRoot = l + 0.3963377774 * a + 0.2158037573 * b;
  const mRoot = l - 0.1055613458 * a - 0.0638541728 * b;
  const sRoot = l - 0.0894841775 * a - 1.2914855480 * b;

  const lmsL = lRoot * lRoot * lRoot;
  const lmsM = mRoot * mRoot * mRoot;
  const lmsS = sRoot * sRoot * sRoot;

  const x = 1.2270138511 * lmsL - 0.5577999807 * lmsM + 0.2812561490 * lmsS;
  const y = -0.0405801784 * lmsL + 1.1122568696 * lmsM - 0.0716766787 * lmsS;
  const z = -0.0763812845 * lmsL - 0.4214819784 * lmsM + 1.5861632204 * lmsS;
  return [x * 100.0, y * 100.0, z * 100.0];
}

export function argbFromOklch(l: number, chroma: number, hue: number): Argb {
  const [x, y, z] = oklchToXyz(l, chroma, hue);
  return argbFromXyz(x, y, z);
}
