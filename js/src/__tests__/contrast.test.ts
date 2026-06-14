import {describe, expect, test} from 'vitest';
import {apcaContrastOfApcaY, apcaFromArgbs, apcaInterpolation, apcaYFromArgb, Usage} from '../index.js';

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
