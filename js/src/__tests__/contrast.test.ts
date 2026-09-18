import {describe, expect, test} from 'vitest';
import {Algo, apcaBrightnessBoundsAtTone, apcaContrastOfApcaY, apcaFromArgbs, apcaInterpolation, apcaYFromArgb, ContrastDirection, contrastingTone, sharedForegroundDirection, Usage} from '../index.js';

describe('APCA primitives', () => {
  test('interpolation mirrors Dart libmonet usage thresholds', () => {
    expect(apcaInterpolation(0.5, Usage.text)).toBe(60);
    expect(apcaInterpolation(0.5, Usage.fill)).toBe(45);
    expect(apcaInterpolation(0.5, Usage.large)).toBe(30);
    expect(apcaInterpolation(0.5, Usage.border)).toBe(15);
    expect(apcaInterpolation(1.0, Usage.text)).toBe(110);
  });

  test('black on white has positive high contrast', () => {
    expect(apcaFromArgbs(0xff000000, 0xffffffff)).toBeGreaterThan(100);
  });

  test('white on black has negative high contrast', () => {
    expect(apcaFromArgbs(0xffffffff, 0xff000000)).toBeLessThan(-100);
  });

  test('same color clips to zero', () => {
    const y = apcaYFromArgb(0xff1177aa);
    expect(apcaContrastOfApcaY(y, y)).toBe(0);
  });
});

describe('shared foreground polarity', () => {
  test('cached bounds cannot be mutated to change shared polarity', () => {
    const opts = {backgroundTone: 66.6, contrast: .5};
    const before = sharedForegroundDirection(opts);
    const bounds = apcaBrightnessBoundsAtTone(opts.backgroundTone - .3);
    const original = {...bounds};
    try {
      // Reflect models an untyped JS consumer without bypassing TS readonly checks.
      Reflect.set(bounds, 'minimum', 1);
      expect(sharedForegroundDirection(opts)).toBe(before);
      Reflect.set(bounds, 'maximum', 0);
      expect(bounds).toEqual(original);
      expect(Object.isFrozen(bounds)).toBe(true);
      expect(apcaBrightnessBoundsAtTone(opts.backgroundTone - .3)).toBe(bounds);
    } finally {
      Reflect.set(bounds, 'minimum', original.minimum);
      Reflect.set(bounds, 'maximum', original.maximum);
    }
  });

  test('continuous envelope matches independent witnesses', () => {
    const bounds = apcaBrightnessBoundsAtTone(50);
    expect(bounds.minimum).toBeCloseTo(.16027158, 7);
    expect(bounds.maximum).toBeCloseTo(.18275507, 7);
    expect(apcaBrightnessBoundsAtTone(50)).toBe(bounds);
  });

  test('covers feasibility, aesthetic and maximin branches', () => {
    const direction = (backgroundTone: number, contrast: number, by = Algo.apca) =>
      sharedForegroundDirection({backgroundTone, contrast, by});
    expect(direction(20, .5)).toBe(ContrastDirection.lighter);
    expect(direction(94, .5)).toBe(ContrastDirection.darker);
    expect(direction(50, .1)).toBe(ContrastDirection.lighter);
    expect(direction(80, .1)).toBe(ContrastDirection.darker);
    expect(direction(66, .5)).toBe(ContrastDirection.lighter);
    expect(direction(67, .5)).toBe(ContrastDirection.darker);
    expect(direction(20, .5, Algo.wcag21)).toBe(ContrastDirection.lighter);
    expect(direction(94, .5, Algo.wcag21)).toBe(ContrastDirection.darker);
    expect(direction(50, 1, Algo.wcag21)).toBe(ContrastDirection.darker);
  });

  test('APCA both-feasible policy prefers aesthetics over maximum capacity', () => {
    // Both meet Lc12; darker is preferred despite greater light capacity.
    expect(sharedForegroundDirection({backgroundTone: 62, contrast: .1}))
      .toBe(ContrastDirection.darker);
  });

  test('APCA light-only feasibility overrides darker preference', () => {
    // Only light guarantees Lc60, despite the darker aesthetic preference.
    expect(sharedForegroundDirection({backgroundTone: 60.6, contrast: .5}))
      .toBe(ContrastDirection.lighter);
  });

  test('WCAG dark-only feasibility overrides lighter preference', () => {
    // Only dark guarantees 4.5:1, despite the lighter aesthetic preference.
    expect(sharedForegroundDirection({backgroundTone: 55, contrast: .5, by: Algo.wcag21}))
      .toBe(ContrastDirection.darker);
  });

  test('forced WCAG polarity never flips at an unreachable boundary', () => {
    expect(contrastingTone({withArgb: 0xff000000, withTone: 0,
      targetHue: 200, targetChroma: 80, usage: Usage.text, by: Algo.wcag21,
      contrast: .5, forceDirection: ContrastDirection.darker})).toBe(0);
    expect(contrastingTone({withArgb: 0xffffffff, withTone: 100,
      targetHue: 200, targetChroma: 80, usage: Usage.text, by: Algo.wcag21,
      contrast: .5, forceDirection: ContrastDirection.lighter})).toBe(100);
  });
});
