import {type Argb, argbFromRgb, blueFromArgb, greenFromArgb, redFromArgb} from './color.js';
import {delinear, lstarFromArgb, yFromLstar} from './hct.js';
import {clamp} from './contrast.js';

// sRGB luma coefficients (Rec. 709), scaled by 100 for 0-100 range output.
// These operate on gamma-encoded sRGB values, not linear RGB.
export const lumaRed = 21.26;
export const lumaGreen = 71.52;
export const lumaBlue = 7.22;

export function argbFromLstar(lstar: number): Argb {
  const component = delinear(yFromLstar(lstar));
  return argbFromRgb(component, component, component);
}

export function lumaFromArgb(argb: Argb): number {
  const r = redFromArgb(argb) / 255.0;
  const g = greenFromArgb(argb) / 255.0;
  const b = blueFromArgb(argb) / 255.0;
  return lumaRed * r + lumaGreen * g + lumaBlue * b;
}

export function lumaFromLstar(lstar: number): number {
  return lumaFromArgb(argbFromLstar(lstar));
}

export function grayscaleArgbFromLuma(luma: number): Argb {
  const rgbNormalized = luma / (lumaRed + lumaGreen + lumaBlue);
  const rgb = Math.round(255.0 * rgbNormalized);
  return argbFromRgb(rgb, rgb, rgb);
}

export function findBoundaryArgbsForLuma(luma: number): Argb[] {
  const getChannel = (lumaRequired: number, lumaCreatedSoFar: number, thisChannelsCoefficient: number): number => {
    const lumaNeeded = lumaRequired - lumaCreatedSoFar;
    return Math.round(255.0 * lumaNeeded / thisChannelsCoefficient);
  };

  const boundaryInts: Argb[] = [grayscaleArgbFromLuma(luma)];
  const addAnswer = (argb: Argb) => boundaryInts.push(argb);

  const maxR = 255.0 * luma / lumaRed;
  if (maxR <= 255) {
    addAnswer(argbFromRgb(Math.round(maxR), 0, 0));
  } else {
    const g1 = getChannel(luma, lumaRed, lumaGreen);
    if (g1 <= 255) addAnswer(argbFromRgb(255, Math.round(g1), 0));
    else addAnswer(argbFromRgb(255, 255, Math.round(getChannel(luma, lumaRed + lumaGreen, lumaBlue))));
    const b2 = getChannel(luma, lumaRed, lumaBlue);
    if (b2 <= 255) addAnswer(argbFromRgb(255, 0, Math.round(b2)));
    else addAnswer(argbFromRgb(255, Math.round(getChannel(luma, lumaRed + lumaBlue, lumaGreen)), 255));
  }

  const maxG = 255.0 * luma / lumaGreen;
  if (maxG <= 255) {
    addAnswer(argbFromRgb(0, Math.round(maxG), 0));
  } else {
    const r1 = getChannel(luma, lumaGreen, lumaRed);
    if (r1 <= 255) addAnswer(argbFromRgb(Math.round(r1), 255, 0));
    else addAnswer(argbFromRgb(255, 255, Math.round(getChannel(luma, lumaGreen + lumaRed, lumaBlue))));
    const b2 = getChannel(luma, lumaGreen, lumaBlue);
    if (b2 <= 255) addAnswer(argbFromRgb(0, 255, Math.round(b2)));
    else addAnswer(argbFromRgb(Math.round(getChannel(luma, lumaGreen + lumaBlue, lumaRed)), 255, 255));
  }

  const maxB = 255.0 * luma / lumaBlue;
  if (maxB <= 255) {
    addAnswer(argbFromRgb(0, 0, Math.round(maxB)));
  } else {
    const r1 = getChannel(luma, lumaBlue, lumaRed);
    if (r1 <= 255) addAnswer(argbFromRgb(Math.round(r1), 0, 255));
    else addAnswer(argbFromRgb(255, Math.round(getChannel(luma, lumaBlue + lumaRed, lumaGreen)), 255));
    const g2 = getChannel(luma, lumaBlue, lumaGreen);
    if (g2 <= 255) addAnswer(argbFromRgb(0, Math.round(g2), 255));
    else addAnswer(argbFromRgb(Math.round(getChannel(luma, lumaBlue + lumaGreen, lumaRed)), 255, 255));
  }

  return boundaryInts;
}

export function lumaToLstarRange(luma: number): [number, number] {
  const lstars = findBoundaryArgbsForLuma(luma).map(lstarFromArgb);
  const minLstar = Math.min(...lstars);
  const maxLstar = Math.max(...lstars);
  return [
    clamp(minLstar - 0.24766520401936987, 0, 100),
    clamp(maxLstar + 0.008416650634032408, 0, 100),
  ];
}
