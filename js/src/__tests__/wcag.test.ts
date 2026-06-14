import {describe, expect, test} from 'vitest';
import {Algo, contrastBetweenArgbs, contrastRatioInterpolation, contrastingLstar, contrastingTone, Palette, Usage} from '../index.js';

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
    expect(contrastBetweenArgbs(Algo.wcag21, p.background, p.text)).toBeGreaterThanOrEqual(4.49);
    // Mirrors Dart's WCAG path: when the preferred side cannot reach the
    // target, the closest extreme is chosen rather than flipping polarity.
    expect(p.fillText).toBe(0xffffffff);
  });
});
