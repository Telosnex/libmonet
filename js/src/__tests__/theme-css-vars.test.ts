import {describe, expect, test, vi} from 'vitest';
import {argbFromHex, applyCssVars, hexFromArgb, MonetThemeData, monetColorScheme, monetColorSchemeCssVars, themeCssVars} from '../index.js';

describe('MonetThemeData', () => {
  test('fromColors creates primary secondary tertiary palettes', () => {
    const theme = MonetThemeData.fromColors({
      brightness: 'light',
      backgroundTone: 93,
      primary: 0xff2196f3,
      secondary: 0xff009688,
      tertiary: 0xffff9800,
      contrast: 0.5,
    });

    expect(theme.primary.color).toBe(0xff2196f3);
    expect(theme.secondary.color).toBe(0xff009688);
    expect(theme.tertiary.color).toBe(0xffff9800);
  });

  test('fromColor derives three palettes from one seed', () => {
    const theme = MonetThemeData.fromColor({
      brightness: 'light',
      backgroundTone: 93,
      color: argbFromHex('#1177AA'),
    });

    expect(theme.primary.color).toBe(argbFromHex('#1177AA'));
    expect(theme.secondary.color).not.toBe(theme.primary.color);
    expect(theme.tertiary.color).not.toBe(theme.primary.color);
  });
});

describe('CSS vars', () => {
  test('exports Docusaurus-ready monet variable map', () => {
    const theme = MonetThemeData.fromColor({brightness: 'light', backgroundTone: 93, color: 0xff1177aa});
    const vars = themeCssVars(theme);
    expect(vars['--monet-primary-background']).toMatch(/^#[0-9A-F]{6}$/);
    expect(vars['--monet-primary-color']).toBe('#1177AA');
    expect(vars['--monet-secondary-color']).toMatch(/^#[0-9A-F]{6}$/);
    expect(vars['--monet-tertiary-color']).toMatch(/^#[0-9A-F]{6}$/);
  });

  test('exports MonetColorScheme-style semantic tokens', () => {
    const theme = MonetThemeData.fromColor({brightness: 'light', backgroundTone: 93, color: 0xff1177aa});
    const scheme = monetColorScheme(theme);
    expect(scheme.primaryColor).toBe(theme.primary.color);
    expect(scheme.primaryFill).toBe(theme.primary.color);
    expect(scheme.primaryText).toBe(theme.primary.colorText);
    expect(scheme.secondaryColorHoverText).toBe(theme.secondary.colorHoveredText);
    expect(scheme.tertiaryTextSplashText).toBe(theme.tertiary.colorSplashedText);
    expect(Object.keys(scheme)).toHaveLength(51);
  });

  test('exports MonetColorScheme CSS vars', () => {
    const theme = MonetThemeData.fromColor({brightness: 'light', backgroundTone: 93, color: 0xff1177aa});
    const vars = monetColorSchemeCssVars(theme);
    expect(vars['--monet-scheme-primary-color']).toBe(hexFromArgb(theme.primary.color));
    expect(vars['--monet-scheme-primary-fill']).toBe(hexFromArgb(theme.primary.color));
    expect(vars['--monet-scheme-tertiary-text-splash-text']).toBe(hexFromArgb(theme.tertiary.colorSplashedText));
    expect(Object.keys(vars)).toHaveLength(51);
  });

  test('applies vars to any CSSStyleDeclaration-like target', () => {
    const setProperty = vi.fn();
    applyCssVars({'--monet-primary-color': '#1177AA'}, {setProperty});
    expect(setProperty).toHaveBeenCalledWith('--monet-primary-color', '#1177AA');
  });
});
