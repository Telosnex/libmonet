import {readFileSync} from 'node:fs';
import {describe, expect, test} from 'vitest';
import {
  Algo,
  Hct,
  argbFromHex,
  hexFromArgb,
  MonetThemeData,
  Palette,
  PaletteLerped,
  quantizerResultFromRecord,
  ScorerTriad,
  TemperatureCache,
  QuantizerCelebi,
  QuantizerMap,
  QuantizerWu,
  Scorer,
  findBoundaryArgbsForLuma,
  grayscaleArgbFromLuma,
  lumaFromArgb,
  lumaFromLstar,
  lumaToLstarRange,
  getOpacityForArgbs,
  getShadowOpacitiesForArgbs,
  lstarToApcaY,
  lighterBackgroundApcaY,
  darkerBackgroundApcaY,
  lighterTextApcaY,
  darkerTextApcaY,
  lighterBackgroundLstarUnsafe,
  lighterBackgroundLstar,
  darkerBackgroundLstarUnsafe,
  darkerBackgroundLstar,
  lighterTextLstarUnsafe,
  lighterTextLstar,
  darkerTextLstarUnsafe,
  darkerTextLstar,
  findBoundaryArgbsForApcaY,
} from '../index.js';

interface PaletteCaseFixture {
  name: string;
  color: string;
  backgroundTone: number;
  algo: 'apca' | 'wcag21';
  contrast: number;
  colorModel?: 'cam16' | 'cam16v11' | 'oklch';
  roles: Record<string, string>;
}

interface ThemeCaseFixture {
  name: string;
  color: string;
  backgroundTone: number;
  brightness: 'light' | 'dark';
  contrast: number;
  primary: Record<string, string>;
  secondary: Record<string, string>;
  tertiary: Record<string, string>;
}

interface PaletteWithBackgroundCaseFixture {
  name: string;
  color: string;
  background: string;
  algo: 'apca' | 'wcag21';
  contrast: number;
  colorModel?: 'cam16' | 'cam16v11' | 'oklch';
  roles: Record<string, string>;
}

interface LerpCaseFixture {
  name: string;
  aColor: string;
  aBackgroundTone: number;
  bColor: string;
  bBackgroundTone: number;
  t: number;
  style: 'cartesian' | 'polar';
  roles: Record<string, string>;
}

interface TriadCaseFixture {
  name: string;
  argbToCount: Record<string, number>;
  triad: string[];
  theme: {
    primary: Record<string, string>;
    secondary: Record<string, string>;
    tertiary: Record<string, string>;
  };
}

interface ScorerCaseFixture {
  name: string;
  argbToCount: Record<string, number>;
  argbEntries: Array<[string, number]>;
  toneTooLow: number | null;
  toneTooHigh: number | null;
  minChroma: number | null;
  hcts: string[];
  hctCount: number;
  triad: string[];
  hueSamples: Record<string, number>;
  primaryHueSamples: Record<string, number>;
}

interface HctColorCaseFixture {
  argb: string;
  hue: number;
  chroma: number;
  tone: number;
  roundTrip: string;
}

interface HctSolveCaseFixture {
  name: string;
  hue: number;
  chroma: number;
  tone: number;
  argb: string;
  actualHue: number;
  actualChroma: number;
  actualTone: number;
}

interface HctModelCaseFixture {
  name: string;
  model: 'cam16' | 'cam16v11' | 'oklch';
  argb: string;
  hue: number;
  chroma: number;
  tone: number;
  solvedArgb: string;
  solvedHue: number;
  solvedChroma: number;
  solvedTone: number;
}

interface TemperatureCaseFixture {
  argb: string;
  complement: string;
  analogous: string[];
  inputRelativeTemperature: number;
  coldest: string;
  warmest: string;
}

interface QuantizerCaseFixture {
  name: string;
  pixels: string[];
  maxColors: number;
  map: Record<string, number>;
  wu: Record<string, number>;
  celebi: Record<string, number>;
}

interface LumaCaseFixture {
  luma: number;
  argb?: string;
  lumaFromArgb?: number;
  lstar?: number;
  lumaFromLstar?: number;
  grayscale: string;
  boundaryArgbs: string[];
  lstarRange: [number, number];
}

interface ApcaInverseCaseFixture {
  name: string;
  lstar: number;
  apca: number;
  apcaY: number;
  lighterBackgroundApcaY: number;
  darkerBackgroundApcaY: number;
  lighterTextApcaY: number;
  darkerTextApcaY: number;
  lighterBackgroundLstarUnsafe: number;
  lighterBackgroundLstar: number;
  darkerBackgroundLstarUnsafe: number;
  darkerBackgroundLstar: number;
  lighterTextLstarUnsafe: number;
  lighterTextLstar: number;
  darkerTextLstarUnsafe: number;
  darkerTextLstar: number;
  boundaryArgbs: string[];
}

interface OpacityCaseFixture {
  name: string;
  foreground: string;
  minBackground: string;
  maxBackground: string;
  contrast: number;
  algo: 'apca' | 'wcag21';
  protectionArgb: string;
  opacity: number;
  targetLstar: number;
  needsProtection: boolean;
  color: string;
  protectionLstar: number;
  protectionLuma: number;
}

interface ShadowCaseFixture {
  name: string;
  foreground: string;
  minBackground: string;
  maxBackground: string;
  contrast: number;
  algo: 'apca' | 'wcag21';
  blurRadius: number;
  contentRadius: number;
  resultBlurRadius: number;
  shadowArgb: string;
  opacities: number[];
}

interface WallpaperGoldenCaseFixture {
  name: string;
  maxColors?: number;
  quantizerFingerprint: string;
  triadHexes: string[];
}

interface Fixture {
  schema: number;
  paletteRoles: string[];
  hctColorCases: HctColorCaseFixture[];
  hctRoundTripSweepCases: HctColorCaseFixture[];
  hctSolveCases: HctSolveCaseFixture[];
  hctSolveSweepCases: HctSolveCaseFixture[];
  hctModelCases: HctModelCaseFixture[];
  temperatureCases: TemperatureCaseFixture[];
  lumaCases: LumaCaseFixture[];
  apcaInverseCases: ApcaInverseCaseFixture[];
  opacityCases: OpacityCaseFixture[];
  shadowCases: ShadowCaseFixture[];
  quantizerCases: QuantizerCaseFixture[];
  paletteCases: PaletteCaseFixture[];
  paletteSweepCases: PaletteCaseFixture[];
  paletteWithBackgroundCases: PaletteWithBackgroundCaseFixture[];
  lerpCases: LerpCaseFixture[];
  themeCases: ThemeCaseFixture[];
  scorerCases: ScorerCaseFixture[];
  triadCases: TriadCaseFixture[];
  wallpaperGoldenCases: WallpaperGoldenCaseFixture[];
}

const fixture = JSON.parse(readFileSync('fixtures/libmonet_parity.json', 'utf8')) as Fixture;

function channelDistance(a: string, b: string): number {
  const ax = argbFromHex(a);
  const bx = argbFromHex(b);
  return Math.max(
    Math.abs(((ax >> 16) & 0xff) - ((bx >> 16) & 0xff)),
    Math.abs(((ax >> 8) & 0xff) - ((bx >> 8) & 0xff)),
    Math.abs((ax & 0xff) - (bx & 0xff)),
  );
}

// Keep this as a real cross-runtime parity gate, not a golden re-baseline.
// HCT, temperature, quantizer, and palette role fixtures are exact.
function expectHexClose(actual: string, expected: string, label: string, tolerance = 0): void {
  const delta = channelDistance(actual, expected);
  expect(delta, `${label}: expected ${expected}, got ${actual}, max channel delta ${delta}`).toBeLessThanOrEqual(tolerance);
}

function toleranceForRole(_role: string): number {
  return 0;
}

function compareRoles(actual: Record<string, number>, expected: Record<string, string>, label: string): void {
  for (const role of fixture.paletteRoles) {
    expectHexClose(hexFromArgb(actual[role]!), expected[role]!, `${label}.${role}`, toleranceForRole(role));
  }
}

function hexRecord(map: Map<number, number>): Record<string, number> {
  return Object.fromEntries(Array.from(map.entries()).map(([argb, count]) => [hexFromArgb(argb), count]));
}

describe('Dart libmonet parity fixtures', () => {
  test('fixture has the expected schema', () => {
    expect(fixture.schema).toBe(11);
    expect(fixture.paletteRoles.length).toBeGreaterThan(40);
    expect(fixture.paletteCases.length).toBeGreaterThan(0);
    expect(fixture.hctRoundTripSweepCases.length).toBeGreaterThan(700);
    expect(fixture.hctSolveSweepCases.length).toBeGreaterThan(300);
    expect(fixture.paletteSweepCases.length).toBeGreaterThan(700);
    expect(fixture.wallpaperGoldenCases.length).toBe(17);
  });

  for (const c of fixture.hctColorCases) {
    test(`Hct.fromInt parity: ${c.argb}`, () => {
      const hct = Hct.fromInt(argbFromHex(c.argb));
      expect(hct.hue).toBeCloseTo(c.hue, 6);
      expect(hct.chroma).toBeCloseTo(c.chroma, 6);
      expect(hct.tone).toBeCloseTo(c.tone, 6);
      expect(hexFromArgb(hct.toInt())).toBe(c.roundTrip);
    });
  }

  for (const c of fixture.hctSolveCases) {
    test(`Hct.from solve parity: ${c.name}`, () => {
      const hct = Hct.from(c.hue, c.chroma, c.tone);
      expectHexClose(hexFromArgb(hct.toInt()), c.argb, `${c.name}.argb`, 0);
      expect(hct.hue).toBeCloseTo(c.actualHue, 3);
      expect(hct.chroma).toBeCloseTo(c.actualChroma, 3);
      expect(hct.tone).toBeCloseTo(c.actualTone, 3);
    });
  }

  test('Hct.fromInt sweep parity', () => {
    for (const c of fixture.hctRoundTripSweepCases) {
      const hct = Hct.fromInt(argbFromHex(c.argb));
      expect(hct.hue, c.argb).toBeCloseTo(c.hue, 6);
      expect(hct.chroma, c.argb).toBeCloseTo(c.chroma, 6);
      expect(hct.tone, c.argb).toBeCloseTo(c.tone, 6);
      expect(hexFromArgb(hct.toInt()), c.argb).toBe(c.roundTrip);
    }
  });

  test('Hct.from solve sweep parity', () => {
    for (const c of fixture.hctSolveSweepCases) {
      const hct = Hct.from(c.hue, c.chroma, c.tone);
      expectHexClose(hexFromArgb(hct.toInt()), c.argb, `${c.name}.argb`, 0);
      expect(hct.hue, c.name).toBeCloseTo(c.actualHue, 3);
      expect(hct.chroma, c.name).toBeCloseTo(c.actualChroma, 3);
      expect(hct.tone, c.name).toBeCloseTo(c.actualTone, 3);
    }
  });

  for (const c of fixture.hctModelCases) {
    test(`Hct colorModel parity: ${c.name}`, () => {
      const hct = Hct.fromInt(argbFromHex(c.argb), c.model);
      expect(hct.hue).toBeCloseTo(c.hue, 6);
      expect(hct.chroma).toBeCloseTo(c.chroma, 9);
      expect(hct.tone).toBeCloseTo(c.tone, 6);
      const solved = Hct.from(hct.hue, hct.chroma, hct.tone, c.model);
      expectHexClose(hexFromArgb(solved.toInt()), c.solvedArgb, `${c.name}.solvedArgb`, 0);
      expect(solved.hue).toBeCloseTo(c.solvedHue, 6);
      expect(solved.chroma).toBeCloseTo(c.solvedChroma, 9);
      expect(solved.tone).toBeCloseTo(c.solvedTone, 6);
    });
  }

  for (const c of fixture.temperatureCases) {
    test(`TemperatureCache parity: ${c.argb}`, () => {
      const cache = new TemperatureCache(Hct.fromInt(argbFromHex(c.argb)));
      expect(hexFromArgb(cache.complement.toInt())).toBe(c.complement);
      expect(cache.analogous(5, 12).map(hct => hexFromArgb(hct.toInt()))).toEqual(c.analogous);
      expect(cache.inputRelativeTemperature).toBeCloseTo(c.inputRelativeTemperature, 6);
      expect(hexFromArgb(cache.coldest.toInt())).toBe(c.coldest);
      expect(hexFromArgb(cache.warmest.toInt())).toBe(c.warmest);
    });
  }

  for (const c of fixture.lumaCases) {
    test(`Luma parity: ${c.luma}`, () => {
      if (c.argb !== undefined) expect(lumaFromArgb(argbFromHex(c.argb))).toBeCloseTo(c.lumaFromArgb!, 12);
      if (c.lstar !== undefined) expect(lumaFromLstar(c.lstar)).toBeCloseTo(c.lumaFromLstar!, 12);
      expect(hexFromArgb(grayscaleArgbFromLuma(c.luma))).toBe(c.grayscale);
      expect(findBoundaryArgbsForLuma(c.luma).map(argb => hexFromArgb(argb))).toEqual(c.boundaryArgbs);
      const range = lumaToLstarRange(c.luma);
      expect(range[0]).toBeCloseTo(c.lstarRange[0], 9);
      expect(range[1]).toBeCloseTo(c.lstarRange[1], 9);
    });
  }

  for (const c of fixture.apcaInverseCases) {
    test(`APCA inverse parity: ${c.name}`, () => {
      expect(lstarToApcaY(c.lstar)).toBeCloseTo(c.apcaY, 12);
      expect(lighterBackgroundApcaY(c.apcaY, c.apca)).toBeCloseTo(c.lighterBackgroundApcaY, 12);
      expect(darkerBackgroundApcaY(c.apcaY, c.apca)).toBeCloseTo(c.darkerBackgroundApcaY, 12);
      expect(lighterTextApcaY(c.apcaY, c.apca)).toBeCloseTo(c.lighterTextApcaY, 12);
      expect(darkerTextApcaY(c.apcaY, c.apca)).toBeCloseTo(c.darkerTextApcaY, 12);
      expect(lighterBackgroundLstarUnsafe(c.lstar, c.apca)).toBeCloseTo(c.lighterBackgroundLstarUnsafe, 9);
      expect(lighterBackgroundLstar(c.lstar, c.apca)).toBeCloseTo(c.lighterBackgroundLstar, 9);
      expect(darkerBackgroundLstarUnsafe(c.lstar, c.apca)).toBeCloseTo(c.darkerBackgroundLstarUnsafe, 9);
      expect(darkerBackgroundLstar(c.lstar, c.apca)).toBeCloseTo(c.darkerBackgroundLstar, 9);
      expect(lighterTextLstarUnsafe(c.lstar, c.apca)).toBeCloseTo(c.lighterTextLstarUnsafe, 9);
      expect(lighterTextLstar(c.lstar, c.apca)).toBeCloseTo(c.lighterTextLstar, 9);
      expect(darkerTextLstarUnsafe(c.lstar, c.apca)).toBeCloseTo(c.darkerTextLstarUnsafe, 9);
      expect(darkerTextLstar(c.lstar, c.apca)).toBeCloseTo(c.darkerTextLstar, 9);
      expect(findBoundaryArgbsForApcaY(c.apcaY).map(argb => hexFromArgb(argb))).toEqual(c.boundaryArgbs);
    });
  }

  for (const c of fixture.opacityCases) {
    test(`Opacity parity: ${c.name}`, () => {
      const result = getOpacityForArgbs({
        foregroundArgb: argbFromHex(c.foreground),
        minBackgroundArgb: argbFromHex(c.minBackground),
        maxBackgroundArgb: argbFromHex(c.maxBackground),
        contrast: c.contrast,
        algo: c.algo === 'wcag21' ? Algo.wcag21 : Algo.apca,
      });
      expect(hexFromArgb(result.protectionArgb)).toBe(c.protectionArgb);
      expect(result.opacity).toBeCloseTo(c.opacity, 12);
      expect(result.targetLstar).toBeCloseTo(c.targetLstar, 9);
      expect(result.needsProtection).toBe(c.needsProtection);
      expect(hexFromArgb(result.color)).toBe(c.color);
      expect(result.protectionLstar).toBeCloseTo(c.protectionLstar, 9);
      expect(result.protectionLuma).toBeCloseTo(c.protectionLuma, 12);
    });
  }

  for (const c of fixture.shadowCases) {
    test(`Shadow parity: ${c.name}`, () => {
      const result = getShadowOpacitiesForArgbs({
        foregroundArgb: argbFromHex(c.foreground),
        minBackgroundArgb: argbFromHex(c.minBackground),
        maxBackgroundArgb: argbFromHex(c.maxBackground),
        contrast: c.contrast,
        algo: c.algo === 'wcag21' ? Algo.wcag21 : Algo.apca,
        blurRadius: c.blurRadius,
        contentRadius: c.contentRadius,
      });
      expect(result.blurRadius).toBeCloseTo(c.resultBlurRadius, 12);
      expect(hexFromArgb(result.shadowArgb)).toBe(c.shadowArgb);
      expect(result.opacities).toHaveLength(c.opacities.length);
      for (let i = 0; i < c.opacities.length; i++) expect(result.opacities[i]).toBeCloseTo(c.opacities[i]!, 12);
    });
  }

  for (const c of fixture.quantizerCases) {
    test(`Quantizer parity: ${c.name}`, () => {
      const pixels = c.pixels.map(argbFromHex);
      expect(hexRecord(new QuantizerMap().quantize(pixels, c.maxColors).argbToCount)).toEqual(c.map);
      expect(hexRecord(new QuantizerWu().quantize(pixels, c.maxColors).argbToCount)).toEqual(c.wu);
      expect(hexRecord(QuantizerCelebi.quantize(pixels, c.maxColors).argbToCount)).toEqual(c.celebi);
    });
  }

  for (const c of fixture.paletteCases) {
    test(`Palette.from parity: ${c.name}`, () => {
      const palette = Palette.from(argbFromHex(c.color), {
        backgroundTone: c.backgroundTone,
        contrast: c.contrast,
        algo: c.algo === 'wcag21' ? Algo.wcag21 : Algo.apca,
        colorModel: c.colorModel ?? 'cam16v11',
      });
      compareRoles(palette.toRecord(), c.roles, c.name);
    });
  }

  for (const c of fixture.paletteWithBackgroundCases) {
    test(`Palette.fromColorAndBackground parity: ${c.name}`, () => {
      const palette = Palette.fromColorAndBackground(argbFromHex(c.color), argbFromHex(c.background), {
        contrast: c.contrast,
        algo: c.algo === 'wcag21' ? Algo.wcag21 : Algo.apca,
        colorModel: c.colorModel ?? 'cam16v11',
      });
      compareRoles(palette.toRecord(), c.roles, c.name);
    });
  }

  test('Palette.from sweep parity budget', () => {
    const overBudget: Array<{label: string; actual: string; expected: string; delta: number}> = [];
    let maxDelta = 0;
    for (const c of fixture.paletteSweepCases) {
      const palette = Palette.from(argbFromHex(c.color), {
        backgroundTone: c.backgroundTone,
        contrast: c.contrast,
        algo: c.algo === 'wcag21' ? Algo.wcag21 : Algo.apca,
      }).toRecord();
      for (const role of fixture.paletteRoles) {
        const actual = hexFromArgb(palette[role as keyof typeof palette]!);
        const expected = c.roles[role]!;
        const delta = channelDistance(actual, expected);
        maxDelta = Math.max(maxDelta, delta);
        if (delta > toleranceForRole(role)) overBudget.push({label: `${c.name}.${role}`, actual, expected, delta});
      }
    }

    overBudget.sort((a, b) => b.delta - a.delta || a.label.localeCompare(b.label));

    // Broad sweep now has no solver-edge drift beyond the strict role budget.
    expect(overBudget).toEqual([]);
    expect(maxDelta).toBe(0);
  });

  for (const c of fixture.lerpCases) {
    test(`PaletteLerped parity: ${c.name}`, () => {
      const a = Palette.from(argbFromHex(c.aColor), {backgroundTone: c.aBackgroundTone});
      const b = Palette.from(argbFromHex(c.bColor), {backgroundTone: c.bBackgroundTone});
      const lerped = new PaletteLerped(a, b, c.t, c.style);
      compareRoles(lerped.toRecord(), c.roles, c.name);
    });
  }

  for (const c of fixture.themeCases) {
    test(`MonetThemeData.fromColor parity: ${c.name}`, () => {
      const theme = MonetThemeData.fromColor({
        color: argbFromHex(c.color),
        backgroundTone: c.backgroundTone,
        brightness: c.brightness,
        contrast: c.contrast,
      });
      compareRoles(theme.primary.toRecord(), c.primary, `${c.name}.primary`);
      compareRoles(theme.secondary.toRecord(), c.secondary, `${c.name}.secondary`);
      compareRoles(theme.tertiary.toRecord(), c.tertiary, `${c.name}.tertiary`);
    });
  }

  for (const c of fixture.scorerCases) {
    test(`Scorer parameter parity: ${c.name}`, () => {
      const result = {argbToCount: new Map(c.argbEntries.map(([argb, count]) => [argbFromHex(argb), count]))};
      const options = {
        toneTooLow: c.toneTooLow,
        toneTooHigh: c.toneTooHigh,
        ...(c.minChroma === null ? {} : {minChroma: c.minChroma}),
      };
      const scorer = new Scorer(result, options);
      expect(scorer.hcts.map(hct => hexFromArgb(hct.toInt()))).toEqual(c.hcts);
      expect(scorer.hcts.length).toBe(c.hctCount);
      const triad = ScorerTriad.threeColorsFromQuantizer(result, options).map(hct => hexFromArgb(hct.toInt()));
      for (let i = 0; i < triad.length; i++) expectHexClose(triad[i]!, c.triad[i]!, `${c.name}.triad[${i}]`);
      for (const [hue, percent] of Object.entries(c.hueSamples)) expect(scorer.huePercent(Number(hue))).toBeCloseTo(percent, 12);
      for (const [hue, percent] of Object.entries(c.primaryHueSamples)) expect(scorer.primaryHuePercent(Number(hue))).toBeCloseTo(percent, 12);
    });
  }

  for (const c of fixture.wallpaperGoldenCases) {
    test(`Wallpaper extraction golden metadata is pinned: ${c.name}/${c.maxColors ?? 32}`, () => {
      expect(c.name).toMatch(/\.jpg$/);
      expect(c.maxColors ?? 32).toBeGreaterThan(0);
      expect(c.quantizerFingerprint).toMatch(/^colors=\d+ total=\d+ top=#/);
      expect(c.triadHexes).toHaveLength(3);
      for (const hex of c.triadHexes) expect(hex).toMatch(/^#[0-9A-F]{6}$/);
    });
  }

  for (const c of fixture.triadCases) {
    test(`ScorerTriad/fromQuantizerResult parity: ${c.name}`, () => {
      const result = quantizerResultFromRecord(c.argbToCount);
      const triad = ScorerTriad.threeColorsFromQuantizer(result).map(hct => hexFromArgb(hct.toInt()));
      expect(triad).toHaveLength(c.triad.length);
      for (let i = 0; i < triad.length; i++) expectHexClose(triad[i]!, c.triad[i]!, `${c.name}.triad[${i}]`);

      const theme = MonetThemeData.fromQuantizerResult({backgroundTone: 93, brightness: 'light', result});
      compareRoles(theme.primary.toRecord(), c.theme.primary, `${c.name}.theme.primary`);
      compareRoles(theme.secondary.toRecord(), c.theme.secondary, `${c.name}.theme.secondary`);
      compareRoles(theme.tertiary.toRecord(), c.theme.tertiary, `${c.name}.theme.tertiary`);
    });
  }
});
