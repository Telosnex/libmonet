import {type Argb, blueFromArgb, greenFromArgb, redFromArgb} from './color.js';
import {oklchFromArgb, oklchToXyz} from './oklch.js';

const whitePointD65 = [95.047, 100.0, 108.883] as const;
const kSrgbToXyz = [
  [0.41233895, 0.35762064, 0.18051042],
  [0.2126, 0.7152, 0.0722],
  [0.01932141, 0.11916382, 0.95034478],
] as const;
const inv0_42 = 1.0 / 0.42;
const inv2_4 = 1.0 / 2.4;
const midgrayY = 18.418651851244416;
export const srgbAdaptingLuminance = 200.0 / Math.PI * midgrayY / 100.0;
export type ColorModel = 'cam16' | 'cam16v11' | 'oklch';
export const defaultColorModel: ColorModel = 'cam16v11';

function signum(x: number): number { return x < 0 ? -1 : x === 0 ? 0 : 1; }
export function sanitizeDegreesDouble(degrees: number): number { degrees %= 360; return degrees < 0 ? degrees + 360 : degrees; }
export function differenceDegrees(a: number, b: number): number { return 180.0 - Math.abs(Math.abs(a - b) - 180.0); }

export function linearized(srgbNorm: number): number {
  return srgbNorm <= 0.040449936 ? srgbNorm / 12.92 : Math.pow((srgbNorm + 0.055) / 1.055, 2.4);
}
export function delinearized(linearNorm: number): number {
  return linearNorm <= 0.0031308 ? linearNorm * 12.92 : 1.055 * Math.pow(linearNorm, inv2_4) - 0.055;
}
export function linear(rgb: number): number { return linearized(rgb / 255) * 100; }
export function delinear(rgbComponent: number): number { return Math.round(Math.min(255, Math.max(0, delinearized(rgbComponent / 100) * 255))); }
function argbFromRgbInternal(red: number, green: number, blue: number): Argb { return ((255 << 24) | ((red & 255) << 16) | ((green & 255) << 8) | (blue & 255)) >>> 0; }

function labF(t: number): number { const e = 216 / 24389; const k = 24389 / 27; return t > e ? Math.cbrt(t) : (k * t + 16) / 116; }
function labInvf(ft: number): number { const e = 216 / 24389; const k = 24389 / 27; const ft3 = ft * ft * ft; return ft3 > e ? ft3 : (116 * ft - 16) / k; }
export function yFromLstar(lstar: number): number { return 100 * labInvf((lstar + 16) / 116); }
export function lstarFromY(y: number): number { return labF(y / 100) * 116 - 16; }
export function lstarFromArgb(argb: Argb): number {
  const r = linear(redFromArgb(argb)); const g = linear(greenFromArgb(argb)); const b = linear(blueFromArgb(argb));
  const y = r * kSrgbToXyz[1][0] + g * kSrgbToXyz[1][1] + b * kSrgbToXyz[1][2];
  return 116 * labF(y / 100) - 16;
}
export function argbFromXyz(x: number, y: number, z: number): Argb {
  const r = 3.2413774792388685 * x + -1.5376652402851851 * y + -0.49885366846268053 * z;
  const g = -0.9691452513005321 * x + 1.8758853451067872 * y + 0.04156585616912061 * z;
  const b = 0.05562093689691305 * x + -0.20395524564742123 * y + 1.0571799111220335 * z;
  return argbFromRgbInternal(delinear(r), delinear(g), delinear(b));
}

function matrix3Mul(a: number[][], b: readonly (readonly number[])[]): number[][] {
  return Array.from({length: 3}, (_, i) => Array.from({length: 3}, (_, j) => a[i]![0]! * b[0]![j]! + a[i]![1]! * b[1]![j]! + a[i]![2]! * b[2]![j]!));
}
function invert3(m: readonly (readonly number[])[]): number[][] {
  const a = m[0]![0]!, b = m[0]![1]!, c = m[0]![2]!;
  const d = m[1]![0]!, e = m[1]![1]!, f = m[1]![2]!;
  const g = m[2]![0]!, h = m[2]![1]!, i = m[2]![2]!;
  const det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
  const invDet = 1 / det;
  return [[(e * i - f * h) * invDet, (c * h - b * i) * invDet, (b * f - c * e) * invDet], [(f * g - d * i) * invDet, (a * i - c * g) * invDet, (c * d - a * f) * invDet], [(d * h - e * g) * invDet, (b * g - a * h) * invDet, (a * e - b * d) * invDet]];
}
const cat16 = [[0.401288, 0.650173, -0.051461], [-0.250268, 1.204414, 0.045854], [-0.002079, 0.048952, 0.953127]];
function computeScaledDiscountFromLinrgb(rgbToXyz: readonly (readonly number[])[]): number[][] {
  const wp = whitePointD65;
  const rW = cat16[0]![0]! * wp[0] + cat16[0]![1]! * wp[1] + cat16[0]![2]! * wp[2];
  const gW = cat16[1]![0]! * wp[0] + cat16[1]![1]! * wp[1] + cat16[1]![2]! * wp[2];
  const bW = cat16[2]![0]! * wp[0] + cat16[2]![1]! * wp[1] + cat16[2]![2]! * wp[2];
  const f = 1.0;
  let d = f * (1 - (1 / 3.6) * Math.exp((-srgbAdaptingLuminance - 42) / 92));
  d = Math.min(1, Math.max(0, d));
  const rgbD = [d * (100 / rW) + 1 - d, d * (100 / gW) + 1 - d, d * (100 / bW) + 1 - d];
  const k = 1 / (5 * srgbAdaptingLuminance + 1); const k4 = k ** 4; const k4F = 1 - k4;
  const fl = k4 * srgbAdaptingLuminance + 0.1 * k4F * k4F * Math.cbrt(5 * srgbAdaptingLuminance);
  const catRgb = matrix3Mul(cat16, rgbToXyz);
  return Array.from({length: 3}, (_, i) => Array.from({length: 3}, (_, j) => catRgb[i]![j]! * fl * rgbD[i]! / 100));
}

const scaledDiscountFromLinrgb = computeScaledDiscountFromLinrgb(kSrgbToXyz);
const linrgbFromScaledDiscount = invert3(scaledDiscountFromLinrgb);
const criticalPlanes = Array.from({length: 255}, (_, i) => linear(i + 0.5));
const yFromLinrgb = [0.2126, 0.7152, 0.0722] as const;

function viewingConditions() {
  const wp = whitePointD65;
  const rW = wp[0] * 0.401288 + wp[1] * 0.650173 + wp[2] * -0.051461;
  const gW = wp[0] * -0.250268 + wp[1] * 1.204414 + wp[2] * 0.045854;
  const bW = wp[0] * -0.002079 + wp[1] * 0.048952 + wp[2] * 0.953127;
  const f = 1.0; const c = 0.69; const nc = f;
  let d = f * (1 - (1 / 3.6) * Math.exp((-srgbAdaptingLuminance - 42) / 92));
  d = Math.min(1, Math.max(0, d));
  const rgbD = [d * (100 / rW) + 1 - d, d * (100 / gW) + 1 - d, d * (100 / bW) + 1 - d];
  const k = 1 / (5 * srgbAdaptingLuminance + 1); const k4 = k ** 4; const k4F = 1 - k4;
  const fl = k4 * srgbAdaptingLuminance + 0.1 * k4F * k4F * Math.cbrt(5 * srgbAdaptingLuminance);
  const fLRoot = Math.pow(fl, 0.25);
  const n = yFromLstar(50) / wp[1]; const z = 1.48 + Math.sqrt(n); const nbb = 0.725 / Math.pow(n, 0.2);
  const rgbAF = [Math.pow(fl * rgbD[0]! * rW / 100, 0.42), Math.pow(fl * rgbD[1]! * gW / 100, 0.42), Math.pow(fl * rgbD[2]! * bW / 100, 0.42)];
  const rgbA = rgbAF.map(v => 400 * v / (v + 27.13));
  const awV11 = 2 * rgbA[0]! + rgbA[1]! + 0.05 * rgbA[2]!;
  const awLegacy = awV11 * nbb;
  return {aw: awV11, awLegacy, nbb, ncb: nbb, c, nC: nc, rgbD, fl, fLRoot, z, backgroundYToWhitePointY: n};
}
const vc = viewingConditions();
const kColorfulnessScale = 43.0;

function chromaticAdaptation(component: number): number { const af = Math.pow(Math.abs(component), 0.42); return signum(component) * 400 * af / (af + 27.13); }
function inverseChromaticAdaptation(adapted: number): number { const aa = Math.abs(adapted); const denom = 400 - aa; if (denom <= 0) return 0; const base = 27.13 * aa / denom; if (base <= 0) return 0; const result = Math.exp(inv0_42 * Math.log(base)); return adapted < 0 ? -result : result; }
function hueEccentricity(h: number): number { return 1 - 0.0582 * Math.cos(h) - 0.0258 * Math.cos(2 * h) - 0.1347 * Math.cos(3 * h) + 0.0289 * Math.cos(4 * h) - 0.1475 * Math.sin(h) - 0.0308 * Math.sin(2 * h) + 0.0385 * Math.sin(3 * h) + 0.0096 * Math.sin(4 * h); }
function areInCyclicOrder(a: number, b: number, c: number): boolean { const ab = sanitizeRadians(b - a); const ac = sanitizeRadians(c - a); return ab < ac; }
function sanitizeRadians(angle: number): number { return (angle + Math.PI * 8) % (Math.PI * 2); }
function trueDelinearizeSrgb(lin: number): number { return delinearized(lin / 100) * 255; }
function hueOfSrgb(r: number, g: number, b: number): number {
  const sdR = r * scaledDiscountFromLinrgb[0]![0]! + g * scaledDiscountFromLinrgb[0]![1]! + b * scaledDiscountFromLinrgb[0]![2]!;
  const sdG = r * scaledDiscountFromLinrgb[1]![0]! + g * scaledDiscountFromLinrgb[1]![1]! + b * scaledDiscountFromLinrgb[1]![2]!;
  const sdB = r * scaledDiscountFromLinrgb[2]![0]! + g * scaledDiscountFromLinrgb[2]![1]! + b * scaledDiscountFromLinrgb[2]![2]!;
  const rA = chromaticAdaptation(sdR), gA = chromaticAdaptation(sdG), bA = chromaticAdaptation(sdB);
  return Math.atan2((rA + gA - 2 * bA) / 9, (11 * rA - 12 * gA + bA) / 11);
}

function findResultByJLegacy(hueRadians: number, chroma: number, y: number): [number, number, number] | undefined {
  let j = Math.sqrt(y) * 11;
  const eHue = 0.25 * (Math.cos(hueRadians + 2.0) + 3.8);
  const p1 = eHue * (50000.0 / 13.0) * vc.nC * vc.ncb;
  const hSin = Math.sin(hueRadians);
  const hCos = Math.cos(hueRadians);
  const invCZ = 1.0 / (vc.c * vc.z);
  const inner = 1.64 - Math.pow(0.29, vc.backgroundYToWhitePointY);
  const tInnerCoeff = 1.0 / Math.pow(inner, 0.73);
  const logCT = Math.log(chroma * tInnerCoeff);
  const tJNCoeff = (1.0 / 0.9) * -0.5;
  for (let i = 0; i < 5; i++) {
    const jn = j / 100;
    const logJn = Math.log(jn);
    const ac = vc.awLegacy * Math.exp(invCZ * logJn);
    const t = Math.exp((1.0 / 0.9) * logCT + tJNCoeff * logJn);
    const p2 = ac / vc.nbb;
    const gamma = 23.0 * (p2 + 0.305) * t / (23.0 * p1 + 11.0 * t * hCos + 108.0 * t * hSin);
    const a = gamma * hCos;
    const b = gamma * hSin;
    const rA = (460.0 * p2 + 451.0 * a + 288.0 * b) / 1403.0;
    const gA = (460.0 * p2 - 891.0 * a - 261.0 * b) / 1403.0;
    const bA = (460.0 * p2 - 220.0 * a - 6300.0 * b) / 1403.0;
    const rCS = inverseChromaticAdaptation(rA), gCS = inverseChromaticAdaptation(gA), bCS = inverseChromaticAdaptation(bA);
    const linR = rCS * linrgbFromScaledDiscount[0]![0]! + gCS * linrgbFromScaledDiscount[0]![1]! + bCS * linrgbFromScaledDiscount[0]![2]!;
    const linG = rCS * linrgbFromScaledDiscount[1]![0]! + gCS * linrgbFromScaledDiscount[1]![1]! + bCS * linrgbFromScaledDiscount[1]![2]!;
    const linB = rCS * linrgbFromScaledDiscount[2]![0]! + gCS * linrgbFromScaledDiscount[2]![1]! + bCS * linrgbFromScaledDiscount[2]![2]!;
    if (linR < 0 || linG < 0 || linB < 0) return undefined;
    const fnj = yFromLinrgb[0] * linR + yFromLinrgb[1] * linG + yFromLinrgb[2] * linB;
    if (fnj <= 0) return undefined;
    if (i === 4 || Math.abs(fnj - y) < 0.002) { if (linR > 100.01 || linG > 100.01 || linB > 100.01) return undefined; return [linR, linG, linB]; }
    j = j - (fnj - y) * j / (2 * fnj);
  }
  return undefined;
}

function findResultByJv11(hueRadians: number, chroma: number, y: number): [number, number, number] | undefined {
  let j = Math.sqrt(y) * 11;
  const eHue = hueEccentricity(hueRadians); const hSin = Math.sin(hueRadians); const hCos = Math.cos(hueRadians); const invCZ = 1 / (vc.c * vc.z);
  const opponentMagnitude = chroma <= 0 ? 0 : (chroma * vc.aw / 35) / (43 * vc.nC * eHue);
  const a = opponentMagnitude * hCos, b = opponentMagnitude * hSin;
  for (let i = 0; i < 8; i++) {
    const jn = j / 100; if (jn <= 0) return undefined;
    const ac = vc.aw * Math.exp(invCZ * Math.log(jn));
    const p2 = ac;
    const rA = (460 * p2 + 451 * a + 288 * b) / 1403;
    const gA = (460 * p2 - 891 * a - 261 * b) / 1403;
    const bA = (460 * p2 - 220 * a - 6300 * b) / 1403;
    const rCS = inverseChromaticAdaptation(rA), gCS = inverseChromaticAdaptation(gA), bCS = inverseChromaticAdaptation(bA);
    const linR = rCS * linrgbFromScaledDiscount[0]![0]! + gCS * linrgbFromScaledDiscount[0]![1]! + bCS * linrgbFromScaledDiscount[0]![2]!;
    const linG = rCS * linrgbFromScaledDiscount[1]![0]! + gCS * linrgbFromScaledDiscount[1]![1]! + bCS * linrgbFromScaledDiscount[1]![2]!;
    const linB = rCS * linrgbFromScaledDiscount[2]![0]! + gCS * linrgbFromScaledDiscount[2]![1]! + bCS * linrgbFromScaledDiscount[2]![2]!;
    if (linR < 0 || linG < 0 || linB < 0) return undefined;
    const fnj = yFromLinrgb[0] * linR + yFromLinrgb[1] * linG + yFromLinrgb[2] * linB;
    if (fnj <= 0) return undefined;
    if (i === 7 || Math.abs(fnj - y) < 0.002) { if (linR > 100.01 || linG > 100.01 || linB > 100.01) return undefined; return [linR, linG, linB]; }
    j = j - (fnj - y) * j / (2 * fnj);
  }
  return undefined;
}

function bisectToLimitSrgb(y: number, targetHue: number): [number, number, number] {
  let lR = -1, lG = -1, lB = -1, rR = -1, rG = -1, rB = -1, leftHue = 0, rightHue = 0;
  let initialized = false, uncut = true;
  for (let n = 0; n < 12; n++) {
    const coordA = n % 4 <= 1 ? 0 : 100; const coordB = n % 2 === 0 ? 0 : 100;
    let mR = -1, mG = -1, mB = -1;
    if (n < 4) { const g = coordA, b = coordB, r = (y - g * yFromLinrgb[1] - b * yFromLinrgb[2]) / yFromLinrgb[0]; if (r >= 0 && r <= 100) { mR = r; mG = g; mB = b; } }
    else if (n < 8) { const b = coordA, r = coordB, g = (y - r * yFromLinrgb[0] - b * yFromLinrgb[2]) / yFromLinrgb[1]; if (g >= 0 && g <= 100) { mR = r; mG = g; mB = b; } }
    else { const r = coordA, g = coordB, b = (y - r * yFromLinrgb[0] - g * yFromLinrgb[1]) / yFromLinrgb[2]; if (b >= 0 && b <= 100) { mR = r; mG = g; mB = b; } }
    if (mR < 0) continue;
    const midHue = hueOfSrgb(mR, mG, mB);
    if (!initialized) { lR = rR = mR; lG = rG = mG; lB = rB = mB; leftHue = rightHue = midHue; initialized = true; continue; }
    if (uncut || areInCyclicOrder(leftHue, midHue, rightHue)) {
      uncut = false;
      if (areInCyclicOrder(leftHue, targetHue, midHue)) { rR = mR; rG = mG; rB = mB; rightHue = midHue; } else { lR = mR; lG = mG; lB = mB; leftHue = midHue; }
    }
  }
  leftHue = hueOfSrgb(lR, lG, lB);
  for (let axis = 0; axis < 3; axis++) {
    const leftForAxis = axis === 0 ? lR : axis === 1 ? lG : lB;
    const rightForAxis = axis === 0 ? rR : axis === 1 ? rG : rB;
    if (leftForAxis === rightForAxis) continue;
    let lPlane: number, rPlane: number;
    if (leftForAxis < rightForAxis) { lPlane = Math.floor(trueDelinearizeSrgb(leftForAxis) - 0.5); rPlane = Math.ceil(trueDelinearizeSrgb(rightForAxis) - 0.5); }
    else { lPlane = Math.ceil(trueDelinearizeSrgb(leftForAxis) - 0.5); rPlane = Math.floor(trueDelinearizeSrgb(rightForAxis) - 0.5); }
    for (let i = 0; i < 8; i++) {
      if (Math.abs(rPlane - lPlane) <= 1) break;
      const mPlane = Math.floor((lPlane + rPlane) / 2); const midCoord = criticalPlanes[mPlane]!; const t = (midCoord - leftForAxis) / (rightForAxis - leftForAxis);
      const mR = lR + (rR - lR) * t, mG = lG + (rG - lG) * t, mB = lB + (rB - lB) * t; const midHue = hueOfSrgb(mR, mG, mB);
      if (areInCyclicOrder(leftHue, targetHue, midHue)) { rR = mR; rG = mG; rB = mB; rPlane = mPlane; } else { lR = mR; lG = mG; lB = mB; leftHue = midHue; lPlane = mPlane; }
    }
  }
  return [(lR + rR) / 2, (lG + rG) / 2, (lB + rB) / 2];
}

function rawLinrgbFromOklch(l: number, chroma: number, hueDegrees: number): [number, number, number] {
  const [x, y, z] = oklchToXyz(l, chroma, hueDegrees);
  return [
    3.2413774792388685 * x + -1.5376652402851851 * y + -0.49885366846268053 * z,
    -0.9691452513005321 * x + 1.8758853451067872 * y + 0.04156585616912061 * z,
    0.05562093689691305 * x + -0.20395524564742123 * y + 1.0571799111220335 * z,
  ];
}

function yFromOklch(l: number, chroma: number, hueDegrees: number): number {
  return oklchToXyz(l, chroma, hueDegrees)[1];
}

function linrgbFromOklchAndY(hueDegrees: number, chroma: number, y: number): [number, number, number] {
  let low = 0.0;
  let high = 1.1;
  for (let i = 0; i < 24; i++) {
    const mid = (low + high) * 0.5;
    if (yFromOklch(mid, chroma, hueDegrees) < y) low = mid;
    else high = mid;
  }
  return rawLinrgbFromOklch((low + high) * 0.5, chroma, hueDegrees);
}

function oklchChromaIsInGamut(hueDegrees: number, chroma: number, y: number): boolean {
  const [r, g, b] = linrgbFromOklchAndY(hueDegrees, chroma, y);
  return r >= 0 && r <= 100 && g >= 0 && g <= 100 && b >= 0 && b <= 100;
}

function findMaxOklchChroma(hueDegrees: number, chroma: number, y: number): number {
  if (oklchChromaIsInGamut(hueDegrees, chroma, y)) return chroma;
  let low = 0.0;
  let high = chroma;
  for (let i = 0; i < 24; i++) {
    const mid = (low + high) * 0.5;
    if (oklchChromaIsInGamut(hueDegrees, mid, y)) low = mid;
    else high = mid;
  }
  return low;
}

function solveOklchToInt(hueDegrees: number, chroma: number, lstar: number): Argb {
  const y = yFromLstar(lstar);
  if (chroma < 0.0001 || lstar < 0.0001 || lstar > 99.9999) {
    const c = delinear(y);
    return argbFromRgbInternal(c, c, c);
  }
  hueDegrees = sanitizeDegreesDouble(hueDegrees);
  const maxChroma = findMaxOklchChroma(hueDegrees, chroma, y);
  const [r, g, b] = linrgbFromOklchAndY(hueDegrees, maxChroma, y);
  return argbFromRgbInternal(delinear(r), delinear(g), delinear(b));
}

export function solveToIntForModel(hueDegrees: number, chroma: number, lstar: number, model: ColorModel = defaultColorModel): Argb {
  if (model === 'oklch') return solveOklchToInt(hueDegrees, chroma, lstar);
  if (model === 'cam16') return solveToIntCam16(hueDegrees, chroma, lstar);
  return solveToInt(hueDegrees, chroma, lstar);
}

export function solveToIntCam16(hueDegrees: number, chroma: number, lstar: number): Argb {
  if (chroma < 0.0001 || lstar < 0.0001 || lstar > 99.9999) {
    const y = yFromLstar(lstar); const c = delinear(y); return argbFromRgbInternal(c, c, c);
  }
  hueDegrees = sanitizeDegreesDouble(hueDegrees); const hueRadians = hueDegrees / 180 * Math.PI; const y = yFromLstar(lstar);
  const exact = findResultByJLegacy(hueRadians, chroma, y);
  const [r, g, b] = exact ?? bisectToLimitSrgb(y, hueRadians);
  return argbFromRgbInternal(delinear(r), delinear(g), delinear(b));
}

export function solveToInt(hueDegrees: number, chroma: number, lstar: number): Argb {
  if (chroma < 0.0001 || lstar < 0.0001 || lstar > 99.9999) {
    const y = yFromLstar(lstar); const c = delinear(y); return argbFromRgbInternal(c, c, c);
  }
  hueDegrees = sanitizeDegreesDouble(hueDegrees); const hueRadians = hueDegrees / 180 * Math.PI; const y = yFromLstar(lstar);
  const exact = findResultByJv11(hueRadians, chroma, y);
  const [r, g, b] = exact ?? bisectToLimitSrgb(y, hueRadians);
  return argbFromRgbInternal(delinear(r), delinear(g), delinear(b));
}

export class Hct {
  readonly hue: number;
  readonly chroma: number;
  readonly tone: number;
  private constructor(private readonly argb: Argb, readonly colorModel: ColorModel = defaultColorModel) {
    if (colorModel === 'oklch') {
      const oklch = oklchFromArgb(argb);
      this.hue = oklch.hue;
      this.chroma = oklch.chroma;
      this.tone = lstarFromArgb(argb);
      return;
    }
    const r = linear(redFromArgb(argb)), g = linear(greenFromArgb(argb)), b = linear(blueFromArgb(argb));
    const x = r * kSrgbToXyz[0][0] + g * kSrgbToXyz[0][1] + b * kSrgbToXyz[0][2];
    const y = r * kSrgbToXyz[1][0] + g * kSrgbToXyz[1][1] + b * kSrgbToXyz[1][2];
    const z = r * kSrgbToXyz[2][0] + g * kSrgbToXyz[2][1] + b * kSrgbToXyz[2][2];
    const rC = 0.401288 * x + 0.650173 * y - 0.051461 * z;
    const gC = -0.250268 * x + 1.204414 * y + 0.045854 * z;
    const bC = -0.002079 * x + 0.048952 * y + 0.953127 * z;
    const rD = vc.rgbD[0]! * rC, gD = vc.rgbD[1]! * gC, bD = vc.rgbD[2]! * bC;
    const rAF = Math.pow(vc.fl * Math.abs(rD) / 100, 0.42), gAF = Math.pow(vc.fl * Math.abs(gD) / 100, 0.42), bAF = Math.pow(vc.fl * Math.abs(bD) / 100, 0.42);
    const rA = signum(rD) * 400 * rAF / (rAF + 27.13), gA = signum(gD) * 400 * gAF / (gAF + 27.13), bA = signum(bD) * 400 * bAF / (bAF + 27.13);
    const a = (11 * rA - 12 * gA + bA) / 11; const bb = (rA + gA - 2 * bA) / 9;
    const atan = Math.atan2(bb, a); const deg = atan * 180 / Math.PI;
    this.hue = deg < 0 ? deg + 360 : deg >= 360 ? deg - 360 : deg;
    if (colorModel === 'cam16') {
      const u = (20.0 * rA + 20.0 * gA + 21.0 * bA) / 20.0;
      const p2 = (40.0 * rA + 20.0 * gA + bA) / 20.0;
      const ac = p2 * vc.nbb;
      const j = 100.0 * Math.pow(ac / vc.awLegacy, vc.c * vc.z);
      const huePrime = this.hue < 20.14 ? this.hue + 360 : this.hue;
      const eHue = 0.25 * (Math.cos(huePrime * Math.PI / 180.0 + 2.0) + 3.8);
      const p1 = 50000.0 / 13.0 * eHue * vc.nC * vc.ncb;
      const t = p1 * Math.sqrt(a * a + bb * bb) / (u + 0.305);
      const alpha = Math.pow(t, 0.9) * Math.pow(1.64 - Math.pow(0.29, vc.backgroundYToWhitePointY), 0.73);
      this.chroma = alpha * Math.sqrt(j / 100.0);
      this.tone = lstarFromArgb(argb);
      return;
    }
    const ac = 2 * rA + gA + 0.05 * bA;
    const j = 100 * Math.pow(ac / vc.aw, vc.c * vc.z);
    const q = (2 / vc.c) * (j / 100) * vc.aw;
    const eHue = hueEccentricity(this.hue * Math.PI / 180); const opp = Math.sqrt(a * a + bb * bb); const m = kColorfulnessScale * vc.nC * eHue * opp;
    this.chroma = 35 * m / vc.aw;
    this.tone = lstarFromArgb(argb);
    void q;
  }
  static fromInt(argb: Argb, model: ColorModel = defaultColorModel): Hct { return new Hct(argb, model); }
  static from(hue: number, chroma: number, tone: number, model: ColorModel = defaultColorModel): Hct { return new Hct(solveToIntForModel(hue, chroma, tone, model), model); }
  toInt(): Argb { return this.argb; }
}
