import {lstarFromArgb} from './hct.js';
import type {Argb} from './color.js';
import type {QuantizerResult} from './extract.js';

function alphaFromArgb(argb: Argb): number {
  return (argb >>> 24) & 0xff;
}

export class QuantizerMap {
  quantize(pixels: Iterable<Argb>, _maxColors: number): QuantizerResult {
    const argbToCount = new Map<Argb, number>();
    const lstarToCount = new Map<number, number>();
    for (const pixel of pixels) {
      if (alphaFromArgb(pixel) < 255) continue;
      argbToCount.set(pixel, (argbToCount.get(pixel) ?? 0) + 1);
      const lstar = Math.round(lstarFromArgb(pixel));
      lstarToCount.set(lstar, (lstarToCount.get(lstar) ?? 0) + 1);
    }
    return {argbToCount, lstarToCount};
  }
}
