import type {Argb} from './color.js';
import type {QuantizerResult} from './extract.js';
import {PointProviderLab} from './point-provider-lab.js';
import {QuantizerWsmeans} from './quantizer-wsmeans.js';
import {QuantizerWu} from './quantizer-wu.js';

export class QuantizerCelebi {
  static quantize(
    pixels: Iterable<Argb>,
    maxColors: number,
    {
      returnInputPixelToClusterPixel = false,
    }: {returnInputPixelToClusterPixel?: boolean} = {},
  ): QuantizerResult {
    const wu = new QuantizerWu();
    const wuResult = wu.quantize(pixels, maxColors);
    const wsmeansResult = QuantizerWsmeans.quantize(
      pixels,
      maxColors,
      {
        startingClusters: Array.from(wuResult.argbToCount.keys()),
        pointProvider: new PointProviderLab(),
        returnInputPixelToClusterPixel,
      },
    );
    const result: QuantizerResult = {
      argbToCount: wsmeansResult.argbToCount,
    };
    if (wuResult.lstarToCount) {
      result.lstarToCount = wuResult.lstarToCount;
    }
    if (returnInputPixelToClusterPixel) {
      result.inputPixelToClusterPixel = wsmeansResult.inputPixelToClusterPixel ?? new Map<Argb, Argb>();
    }
    return result;
  }
}
