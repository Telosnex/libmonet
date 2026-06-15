# Fonts

Generated font data for dynamic Google Fonts support.

## Runtime files

- `font_height_equalizer.g.dart` — per-family raster metrics and `visualHeightScaleForFontFamily`.
- `google_fonts_catalog.g.dart` — picker/search metadata for families present in both the locked `google_fonts` package and public Google Fonts metadata.

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

When `google_fonts` changes, regenerate both generated files:

```bash
/opt/homebrew/bin/python3 -u lib/fonts/generate_font_height_equalizer.py \
  --cache-dir /tmp/google_fonts_ttf_cache

/opt/homebrew/bin/python3 lib/fonts/generate_google_fonts_catalog.py
```

Also regenerate if the phrase corpus, reference font, generator logic, or Google Fonts metadata requirements change.

Before committing:

```bash
/opt/homebrew/bin/python3 -m py_compile \
  lib/fonts/generate_font_height_equalizer.py \
  lib/fonts/generate_google_fonts_catalog.py

dart analyze \
  lib/fonts/font_height_equalizer.g.dart \
  lib/fonts/google_fonts_catalog.g.dart \
  lib/theming/monet_theme_data.dart
```

Quick sanity check: inspect scale changes for `Roboto`, `Bahianita`, `Cormorant Garamond`, `JetBrains Mono`, `Fauna One`, and `Tenor Sans`.
