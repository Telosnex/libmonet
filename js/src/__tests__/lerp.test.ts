import {describe, expect, test} from 'vitest';
import {hexFromArgb, lerpArgb, Palette, PaletteLerped} from '../index.js';

describe('lerp', () => {
  test('clamps endpoints exactly', () => {
    expect(lerpArgb(0xffff0000, 0xff0000ff, -1)).toBe(0xffff0000);
    expect(lerpArgb(0xffff0000, 0xff0000ff, 2)).toBe(0xff0000ff);
  });

  test('cartesian and polar follow different paths', () => {
    const cartesian = lerpArgb(0xffff0000, 0xff0000ff, 0.5, 'cartesian');
    const polar = lerpArgb(0xffff0000, 0xff0000ff, 0.5, 'polar');
    expect(cartesian).not.toBe(polar);
  });

  test('PaletteLerped exposes lerped palette roles', () => {
    const a = Palette.from(0xffff0000, {backgroundTone: 20});
    const b = Palette.from(0xff0000ff, {backgroundTone: 80});
    const lerped = new PaletteLerped(a, b, 0.5);
    expect(hexFromArgb(lerped.color)).toMatch(/^#[0-9A-F]{6}$/);
    expect(lerped.background).not.toBe(a.background);
    expect(lerped.background).not.toBe(b.background);
  });
});
