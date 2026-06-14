import {describe, expect, test} from 'vitest';
import {hexFromArgb, MonetThemeData, quantizerResultFromRecord, rgbaToArgb, Scorer, ScorerTriad} from '../index.js';

describe('extract/scorer', () => {
  test('rgbaToArgb mirrors Dart byte conversion', () => {
    expect(rgbaToArgb(0x44332211)).toBe(0x44112233);
  });

  test('Scorer builds filtered hue percentages', () => {
    const result = quantizerResultFromRecord(new Map([
      [0xffff0000, 8],
      [0xff0000ff, 2],
      [0xffffffff, 10],
    ]));
    const scorer = new Scorer(result);
    expect(scorer.hcts.length).toBeGreaterThan(0);
    expect(Math.max(...scorer.primaryHueToSmearedPercent)).toBeGreaterThan(0);
  });

  test('ScorerTriad returns primary/secondary/tertiary from quantizer result', () => {
    const result = quantizerResultFromRecord(new Map([
      [0xffff0000, 50],
      [0xff00ff00, 25],
      [0xff0000ff, 25],
    ]));
    const triad = ScorerTriad.threeColorsFromQuantizer(result);
    expect(triad).toHaveLength(3);
    expect(triad[0]!.hue).toBeGreaterThanOrEqual(20);
    expect(triad[0]!.hue).toBeLessThanOrEqual(30);
  });

  test('MonetThemeData.fromQuantizerResult uses extracted triad', () => {
    const result = quantizerResultFromRecord(new Map([
      [0xffff0000, 50],
      [0xff00ff00, 25],
      [0xff0000ff, 25],
    ]));
    const theme = MonetThemeData.fromQuantizerResult({brightness: 'light', backgroundTone: 93, result});
    expect(hexFromArgb(theme.primary.color)).toMatch(/^#[0-9A-F]{6}$/);
    expect(hexFromArgb(theme.secondary.color)).toMatch(/^#[0-9A-F]{6}$/);
    expect(hexFromArgb(theme.tertiary.color)).toMatch(/^#[0-9A-F]{6}$/);
  });
});
