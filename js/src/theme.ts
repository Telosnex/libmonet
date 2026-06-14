import {Hct, type ColorModel} from './hct.js';
import {TemperatureCache} from './temperature.js';
import {type Argb} from './color.js';
import {Algo} from './contrast.js';
import {ScorerTriad, type QuantizerResult, type ScorerTriadOptions} from './extract.js';
import {Palette} from './palette.js';

export type Brightness = 'light' | 'dark';

export interface MonetThemeDataOptions {
  backgroundTone: number;
  brightness: Brightness;
  primary: Argb;
  secondary: Argb;
  tertiary: Argb;
  contrast?: number;
  algo?: Algo;
  colorModel?: ColorModel;
}

export class MonetThemeData {
  readonly primary: Palette;
  readonly secondary: Palette;
  readonly tertiary: Palette;
  readonly contrast: number;
  readonly algo: Algo;

  constructor(readonly options: Required<MonetThemeDataOptions>) {
    this.primary = Palette.from(options.primary, {backgroundTone: options.backgroundTone, contrast: options.contrast, algo: options.algo, colorModel: options.colorModel});
    this.secondary = Palette.from(options.secondary, {backgroundTone: options.backgroundTone, contrast: options.contrast, algo: options.algo, colorModel: options.colorModel});
    this.tertiary = Palette.from(options.tertiary, {backgroundTone: options.backgroundTone, contrast: options.contrast, algo: options.algo, colorModel: options.colorModel});
    this.contrast = options.contrast;
    this.algo = options.algo;
  }

  static fromColors(options: MonetThemeDataOptions): MonetThemeData {
    return new MonetThemeData({contrast: 0.5, algo: Algo.apca, colorModel: 'cam16v11', ...options});
  }

  static fromColor(options: Omit<MonetThemeDataOptions, 'primary' | 'secondary' | 'tertiary'> & {color: Argb}): MonetThemeData {
    const temperature = new TemperatureCache(Hct.fromInt(options.color, options.colorModel ?? 'cam16v11'));
    const analogous = temperature.analogous(5, 12)[1]!.toInt();
    const complement = temperature.complement.toInt();
    const themeOptions: MonetThemeDataOptions = {
      backgroundTone: options.backgroundTone,
      brightness: options.brightness,
      primary: options.color,
      secondary: analogous,
      tertiary: complement,
    };
    if (options.contrast !== undefined) themeOptions.contrast = options.contrast;
    if (options.algo !== undefined) themeOptions.algo = options.algo;
    return MonetThemeData.fromColors(themeOptions);
  }

  static fromQuantizerResult(options: Omit<MonetThemeDataOptions, 'primary' | 'secondary' | 'tertiary'> & {result: QuantizerResult; scorer?: ScorerTriadOptions}): MonetThemeData {
    const triad = ScorerTriad.threeColorsFromQuantizer(options.result, options.scorer ?? {});
    if (triad.length === 0) {
      return MonetThemeData.fromColor({
        backgroundTone: options.backgroundTone,
        brightness: options.brightness,
        color: 0xff1177aa,
        ...(options.contrast === undefined ? {} : {contrast: options.contrast}),
        ...(options.algo === undefined ? {} : {algo: options.algo}),
      });
    }
    const themeOptions: MonetThemeDataOptions = {
      backgroundTone: options.backgroundTone,
      brightness: options.brightness,
      primary: triad[0]!.toInt(),
      secondary: triad[1]!.toInt(),
      tertiary: triad[2]!.toInt(),
    };
    if (options.contrast !== undefined) themeOptions.contrast = options.contrast;
    if (options.algo !== undefined) themeOptions.algo = options.algo;
    return MonetThemeData.fromColors(themeOptions);
  }
}
