# Fonts

Generated font data for dynamic Google Fonts support.

## Runtime files

- `font_height_equalizer.g.dart` — per-family raster metrics and `visualHeightScaleForFontFamily`.
- `google_fonts_catalog.g.dart` — picker/search metadata for every family in the resolved `google_fonts` package.
  Its variants come from the package descriptors. Its categories and language subsets come from Google Fonts metadata.

## Font height equalizer

Goal: make the same text role feel similarly tall across fonts without runtime rasterization.

```text
fontSize = roleBasePx * userScale * visualHeightScale(font)
```

Current metric (`x50+w15`):

```text
phraseHeight(font) = trimmed mean(rendered phrase ink heights)
averageAdvance(font) = mean(phrase advance / phrase character count)
visualHeight(font) = phraseHeight(font)^0.50 * xHeight(font)^0.50 * averageAdvance(font)^0.15
visualHeightScale(font) = visualHeight(Roboto) / visualHeight(font)
```

Phrase corpus:

```text
Clear Prompt
Goal
Safety
Sign in
Start
```

Roboto is the reference font.

## Why phrases

Earlier metrics failed on real fonts:

```text
x-height only
sqrt(x-height * cap-height)
lowercase/uppercase glyph percentiles
75% lowercase body-zone + 25% cap-height
derived phrase heights from per-letter bounds
```

Actual rendered UI phrases were the best starting point, but phrase height alone made fonts with similar outer ink bounds but very different body zones look mismatched. The current metric blends rendered phrase height with x-height and a weak width/advance term.

## Useful test fonts

```text
Bahianita              decorative/condensed; bbox says tall, eye says small
IM Fell English        prose/mono mismatch and old-style serif behavior
Lusitana               serif; corpus/extrema metrics can underboost
Alice                  caps/lowercase balance made glyph blends overboost
Cormorant Garamond     tiny lowercase; pure x-height overboosts
Sen                    looked small only relative to overboosted serifs
Imbue                  vertically normal but very condensed/low footprint
JetBrains Mono         mono/prose matching needs x-height, not role visual metric
Fauna One              large x-height; should shrink somewhat
Tenor Sans             moderate baseline sanity check
Roboto                 reference font
```

## Non-goals

- No runtime rasterization.
- No `Picture.toImage` / `toByteData` in UI paths.
- No perfect perceptual model for every decorative font.
- No full ink-area/density compensation in the main role scale yet.
- Monospace fonts are supported, but code/prose size matching should use x-height rather than normal role visual-height scaling.

## Maintenance

The Dart workflow updates both runtime files with one command.
It resolves the exact package from `package_config.json`.
It saves the metadata snapshot and records the source fingerprints.

```bash
dart tool/generate_fonts.dart --write --refresh-metadata
```

For a consuming app, use its resolved package configuration:

```bash
dart tool/generate_fonts.dart --write --refresh-metadata \
  --package-config=../telosnex/.dart_tool/package_config.json
```

The workflow creates a local Python environment with pinned Pillow for the existing offline rasterizer.
Python 3 must be installed. Font downloads and the environment stay in `.dart_tool/font_generation/`.
The workflow verifies downloaded font hashes. Download failures stop publication of the runtime files.
Families without measurable Latin text remain selectable. Their visual-height scale defaults to `1.0`.
The generation manifest lists these exclusions.

The offline check detects changes to the package, descriptors, metadata, rasterizer, or output metrics:

```bash
dart tool/generate_fonts.dart --check
```

The generator tests run this check. A dependency upgrade therefore cannot silently leave old tables in place.
The old Python catalog generator is no longer part of the update workflow.

Quick sanity check: inspect scale changes for `Roboto`, `Bahianita`, `Cormorant Garamond`, `JetBrains Mono`, `Fauna One`, and `Tenor Sans`.
