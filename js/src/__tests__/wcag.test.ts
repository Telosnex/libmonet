import {describe, expect, test} from 'vitest';
import {Algo, contrastBetweenArgbs, contrastRatioInterpolation, contrastingLstar, contrastingTone, Hct, Palette, Usage} from '../index.js';

describe('WCAG 2.1 contrast', () => {
  test('contrast ratio interpolation mirrors Dart thresholds', () => {
    expect(contrastRatioInterpolation(0.5, Usage.text)).toBe(4.5);
    expect(contrastRatioInterpolation(0.5, Usage.fill)).toBe(3);
    expect(contrastRatioInterpolation(0.5, Usage.large)).toBe(3);
    expect(contrastRatioInterpolation(0.5, Usage.border)).toBe(1.5);
    expect(contrastRatioInterpolation(1, Usage.text)).toBe(21);
  });

  test('contrastingLstar solves lighter and darker directions', () => {
    const lighter = contrastingLstar({withLstar: 20, usage: Usage.text, by: Algo.wcag21, contrast: 0.5});
    const darker = contrastingLstar({withLstar: 80, usage: Usage.text, by: Algo.wcag21, contrast: 0.5});
    expect(lighter).toBeGreaterThan(20);
    expect(darker).toBeLessThan(80);
  });

  test('contrastingTone supports wcag21 instead of throwing', () => {
    const tone = contrastingTone({
      withArgb: 0xff101010,
      withTone: 10,
      targetHue: 250,
      targetChroma: 40,
      usage: Usage.text,
      by: Algo.wcag21,
      contrast: 0.5,
    });
    expect(tone).toBeGreaterThan(10);
  });

  test('Palette can be generated with wcag21 algorithm', () => {
    const p = Palette.from(0xff1177aa, {backgroundTone: 93, algo: Algo.wcag21});
    expect(contrastBetweenArgbs(Algo.wcag21, p.background, p.text)).toBeGreaterThanOrEqual(4.5);
    // The fill is its own logical context. White cannot meet 4.5:1 here;
    // the shared policy chooses dark, then solves against the actual fill RGB.
    expect(contrastBetweenArgbs(Algo.wcag21, p.fill, 0xffffffff)).toBeLessThan(4.5);
    expect(Hct.fromInt(p.fillText).tone).toBeLessThan(Hct.fromInt(p.fill).tone);
    expect(contrastBetweenArgbs(Algo.wcag21, p.fill, p.fillText)).toBeGreaterThanOrEqual(4.5);
  });
});
