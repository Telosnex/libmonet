import {hexFromArgb} from './color.js';
import {type PaletteRole, paletteRoles} from './palette.js';
import {MonetThemeData} from './theme.js';

export type MonetFamily = 'primary' | 'secondary' | 'tertiary';
export type MonetCssVars = Record<string, string>;

export type MonetColorSchemeRole =
  | 'primaryColor' | 'primaryColorText' | 'primaryColorHover' | 'primaryColorHoverText' | 'primaryColorSplash' | 'primaryColorSplashText'
  | 'primaryFill' | 'primaryFillText' | 'primaryFillHover' | 'primaryFillHoverText' | 'primaryFillSplash' | 'primaryFillSplashText'
  | 'primaryText' | 'primaryTextHover' | 'primaryTextHoverText' | 'primaryTextSplash' | 'primaryTextSplashText'
  | 'secondaryColor' | 'secondaryColorText' | 'secondaryColorHover' | 'secondaryColorHoverText' | 'secondaryColorSplash' | 'secondaryColorSplashText'
  | 'secondaryFill' | 'secondaryFillText' | 'secondaryFillHover' | 'secondaryFillHoverText' | 'secondaryFillSplash' | 'secondaryFillSplashText'
  | 'secondaryText' | 'secondaryTextHover' | 'secondaryTextHoverText' | 'secondaryTextSplash' | 'secondaryTextSplashText'
  | 'tertiaryColor' | 'tertiaryColorText' | 'tertiaryColorHover' | 'tertiaryColorHoverText' | 'tertiaryColorSplash' | 'tertiaryColorSplashText'
  | 'tertiaryFill' | 'tertiaryFillText' | 'tertiaryFillHover' | 'tertiaryFillHoverText' | 'tertiaryFillSplash' | 'tertiaryFillSplashText'
  | 'tertiaryText' | 'tertiaryTextHover' | 'tertiaryTextHoverText' | 'tertiaryTextSplash' | 'tertiaryTextSplashText';

export type MonetColorScheme = Record<MonetColorSchemeRole, number>;

function kebab(input: string): string {
  return input.replace(/[A-Z]/g, m => `-${m.toLowerCase()}`);
}

export function paletteCssVars(family: MonetFamily, record: Record<PaletteRole, number>, prefix = '--monet'): MonetCssVars {
  const out: MonetCssVars = {};
  for (const role of paletteRoles) out[`${prefix}-${family}-${kebab(role)}`] = hexFromArgb(record[role]);
  return out;
}

export function themeCssVars(theme: MonetThemeData, prefix = '--monet'): MonetCssVars {
  return {
    ...paletteCssVars('primary', theme.primary.toRecord(), prefix),
    ...paletteCssVars('secondary', theme.secondary.toRecord(), prefix),
    ...paletteCssVars('tertiary', theme.tertiary.toRecord(), prefix),
  };
}

function schemeFamilyVars(family: MonetFamily, palette: ReturnType<MonetThemeData['primary']['toRecord']>): Record<string, number> {
  return {
    [`${family}Color`]: palette.color,
    [`${family}ColorText`]: palette.colorText,
    [`${family}ColorHover`]: palette.colorHovered,
    [`${family}ColorHoverText`]: palette.colorHoveredText,
    [`${family}ColorSplash`]: palette.colorSplashed,
    [`${family}ColorSplashText`]: palette.colorSplashedText,
    [`${family}Fill`]: palette.color,
    [`${family}FillText`]: palette.colorText,
    [`${family}FillHover`]: palette.colorHovered,
    [`${family}FillHoverText`]: palette.colorHoveredText,
    [`${family}FillSplash`]: palette.colorSplashed,
    [`${family}FillSplashText`]: palette.colorSplashedText,
    [`${family}Text`]: palette.colorText,
    [`${family}TextHover`]: palette.colorHoveredText,
    [`${family}TextHoverText`]: palette.colorHoveredText,
    [`${family}TextSplash`]: palette.colorSplashedText,
    [`${family}TextSplashText`]: palette.colorSplashedText,
  };
}

export function monetColorScheme(theme: MonetThemeData): MonetColorScheme {
  return {
    ...schemeFamilyVars('primary', theme.primary.toRecord()),
    ...schemeFamilyVars('secondary', theme.secondary.toRecord()),
    ...schemeFamilyVars('tertiary', theme.tertiary.toRecord()),
  } as MonetColorScheme;
}

export function monetColorSchemeCssVars(theme: MonetThemeData, prefix = '--monet-scheme'): MonetCssVars {
  const scheme = monetColorScheme(theme);
  const out: MonetCssVars = {};
  for (const [role, argb] of Object.entries(scheme)) out[`${prefix}-${kebab(role)}`] = hexFromArgb(argb);
  return out;
}

export function applyCssVars(vars: MonetCssVars, target: Pick<CSSStyleDeclaration, 'setProperty'> = document.documentElement.style): void {
  for (const [name, value] of Object.entries(vars)) target.setProperty(name, value);
}
