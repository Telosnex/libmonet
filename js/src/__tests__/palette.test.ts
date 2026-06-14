import {describe, expect, test} from 'vitest';
import {argbFromHex, Hct, Palette, hexFromArgb} from '../index.js';

const tone = (argb: number) => Hct.fromInt(argb).tone;
const expectHex = (actual: number, expected: string, tolerance = 36) => {
  const a = actual;
  const e = argbFromHex(expected);
  const delta = Math.max(
    Math.abs(((a >> 16) & 0xff) - ((e >> 16) & 0xff)),
    Math.abs(((a >> 8) & 0xff) - ((e >> 8) & 0xff)),
    Math.abs((a & 0xff) - (e & 0xff)),
  );
  expect(delta, `expected ${expected}, got ${hexFromArgb(actual)}`).toBeLessThanOrEqual(tolerance);
};

describe('polarity consistency', () => {
  const brandColor = 0xff1565c0;
  const dir = (a: number, b: number, label: string) => {
    const d = tone(b) - tone(a);
    expect(Math.abs(d), `${label}: tones too close`).toBeGreaterThan(1);
    return Math.sign(d);
  };

  for (const bgTone of [10, 20, 30, 40, 50, 55, 60, 70, 80, 90, 95]) {
    describe(`bgTone=${bgTone}`, () => {
      const p = Palette.from(brandColor, {backgroundTone: bgTone});

      test('fill and text share polarity vs background', () => {
        expect(dir(p.background, p.fill, 'bg→fill')).toBe(dir(p.background, p.text, 'bg→text'));
      });

      test('hovered overlay fill and text share polarity vs hovered overlay', () => {
        expect(dir(p.backgroundHovered, p.backgroundHoveredFill, 'bgHover→fill')).toBe(dir(p.backgroundHovered, p.backgroundHoveredText, 'bgHover→text'));
      });

      test('splashed overlay fill and text share polarity vs splashed overlay', () => {
        expect(dir(p.backgroundSplashed, p.backgroundSplashedFill, 'bgSplash→fill')).toBe(dir(p.backgroundSplashed, p.backgroundSplashedText, 'bgSplash→text'));
      });

      test('fillText and fillIcon share polarity vs fill', () => {
        expect(dir(p.fill, p.fillText, 'fill→fillText')).toBe(dir(p.fill, p.fillIcon, 'fill→fillIcon'));
      });

      test('colorText and colorIcon share polarity vs color', () => {
        expect(dir(p.color, p.colorText, 'color→colorText')).toBe(dir(p.color, p.colorIcon, 'color→colorIcon'));
      });
    });
  }
});

describe('#1177AA bgTone=10', () => {
  test('snapshot core roles matches Dart libmonet', () => {
    const p = Palette.from(0xff1177aa, {backgroundTone: 10});
    expectHex(p.color, '#1177AA');
    expectHex(p.fill, '#4C9FD4');
    expectHex(p.fillBorder, '#4C9FD4');
    expectHex(p.text, '#6CBBF2');
    expectHex(p.fillText, '#FFFFFF');
    expectHex(p.fillIcon, '#D4EAFF');
    expectHex(p.backgroundBorder, '#485966');
  });
});

describe('#334157', () => {
  test('light mode core roles match Dart libmonet', () => {
    const colors = Palette.from(0xff334157, {backgroundTone: 100});
    expectHex(colors.color, '#334157');
    expectHex(colors.colorText, '#B5C3DE');
    expectHex(colors.colorIcon, '#9AA9C3');
    expectHex(colors.colorHovered, '#64728A');
    expectHex(colors.colorHoveredText, '#D4E2FE');
    expectHex(colors.colorSplashed, '#808FA8');
    expectHex(colors.colorSplashedText, '#F5F7FF');
    expectHex(colors.fill, '#9EACC7');
    expectHex(colors.fillText, '#000000');
    expectHex(colors.fillIcon, '#38455C');
    expectHex(colors.text, '#818FA8');
  });

  test('dark mode core roles match Dart libmonet', () => {
    const colors = Palette.from(0xff334157, {backgroundTone: 0});
    expectHex(colors.color, '#334157');
    expectHex(colors.colorText, '#B5C3DE');
    expectHex(colors.colorIcon, '#9AA9C3');
    expectHex(colors.colorHovered, '#64728A');
    expectHex(colors.colorHoveredText, '#D4E2FE');
    expectHex(colors.colorSplashed, '#808FA8');
    expectHex(colors.colorSplashedText, '#F5F7FF');
    expectHex(colors.fill, '#8796AF');
    expectHex(colors.fillText, '#FFFFFF');
    expectHex(colors.fillIcon, '#D9E6FF');
    expectHex(colors.text, '#A3B1CC');
  });
});

test('chromatic background keeps chroma in hover/splash', () => {
  const p = Palette.fromColorAndBackground(0xffe7f5ff, 0xff7bb1cf);
  const bgChroma = Hct.fromInt(p.background).chroma;
  expect(Hct.fromInt(p.backgroundHovered).chroma).toBeGreaterThanOrEqual(bgChroma - 1);
  expect(Hct.fromInt(p.backgroundSplashed).chroma).toBeGreaterThanOrEqual(bgChroma - 1);
});
