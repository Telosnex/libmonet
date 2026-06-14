import {describe, expect, test} from 'vitest';
import {hexFromArgb, quantizeArgbPixels} from '../index.js';
import {QuantizerCelebi} from '../quantizer-celebi.js';
import {QuantizerMap} from '../quantizer-map.js';
import {QuantizerWu} from '../quantizer-wu.js';

describe('quantizers', () => {
  test('QuantizerMap counts opaque pixels and ignores transparency', () => {
    const result = new QuantizerMap().quantize([
      0xffff0000,
      0xffff0000,
      0xff0000ff,
      0x80ff0000,
    ], 8);

    expect(result.argbToCount).toEqual(new Map([
      [0xffff0000, 2],
      [0xff0000ff, 1],
    ]));
    expect(result.lstarToCount instanceof Map).toBe(true);
  });

  test('QuantizerWu preserves a simple two-color palette', () => {
    const result = new QuantizerWu().quantize([
      0xffff0000,
      0xffff0000,
      0xff0000ff,
      0xff0000ff,
    ], 2);

    expect([...result.argbToCount.keys()].map(color => hexFromArgb(color)).sort()).toEqual(['#0000FF', '#FF0000']);
  });

  test('quantizeArgbPixels is deterministic for a two-color input', () => {
    const result = quantizeArgbPixels([
      0xffff0000,
      0xffff0000,
      0xff0000ff,
      0xff0000ff,
    ], 2);

    expect(result.argbToCount.size).toBe(2);
    expect(result.argbToCount.get(0xffff0000)).toBe(2);
    expect(result.argbToCount.get(0xff0000ff)).toBe(2);
  });

  test('QuantizerCelebi keeps a single opaque color intact', () => {
    const result = QuantizerCelebi.quantize([
      0xff336699,
      0xff336699,
      0xff336699,
    ], 8);

    expect(result.argbToCount).toEqual(new Map([[0xff336699, 3]]));
  });
});
