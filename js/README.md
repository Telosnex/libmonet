# @telosnex/libmonet

Browser/TypeScript sibling implementation of Dart `libmonet` dynamic theming.

```ts
import {
  MonetThemeData,
  argbFromHex,
  themeCssVars,
  applyCssVars,
} from '@telosnex/libmonet';

const theme = MonetThemeData.fromColor({
  color: argbFromHex('#1177AA'),
  backgroundTone: 93,
  brightness: 'light',
  contrast: 0.5,
});

applyCssVars(themeCssVars(theme));
```

Image extraction:

```ts
import {MonetThemeData, quantizeImage} from '@telosnex/libmonet';

const result = await quantizeImage(imgElement, 128, 96);
const theme = MonetThemeData.fromQuantizerResult({
  result,
  backgroundTone: 93,
  brightness: 'light',
});
```

Runtime animation:

```ts
import {PaletteLerped, paletteCssVars, applyCssVars} from '@telosnex/libmonet';

const lerped = new PaletteLerped(oldTheme.primary, newTheme.primary, 0.5, 'polar');
applyCssVars(paletteCssVars('primary', lerped.toRecord()));
```

The implementation intentionally lives next to Dart libmonet so parity fixtures/tests can be generated from the Dart source of truth.

Parity workflow:

```sh
npm run test:parity:generate # regenerates fixtures/libmonet_parity.json from Dart
npm run check                # TypeScript build + Vitest, including Dart fixture parity
npm run check:parity         # regenerate fixtures, fail on fixture diff, then run check
```

Current parity note: JS now includes direct CAM16 v1.1/HCT, TemperatureCache, and Celebi/Wu/WSMeans quantizer ports validated by focused tests and Dart fixtures. Palette/theme/scorer parity is checked against Dart-generated fixtures with a tiny channel-drift budget for solver-edge rounding.
