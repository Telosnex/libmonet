# Display metrics

This component computes a display scale from physical display data. The scale
is the number of physical pixels in one logical pixel. The component does not
trust the DPI value that a device reports. It computes the scale from the
display geometry and the viewing distance.

The model comes from the display code of the Fuchsia project. The `fuchsia/`
directory contains verbatim copies of the source documents. The Dart
implementation is `lib/display/display_metrics.dart`. The tests are
`test/display/display_metrics_test.dart`.

## The problem

UI toolkits lay out interfaces in logical pixels. Android names this unit
"dp". iOS names it "pt". CSS names it "px". On phones, the manufacturer
selects a correct scale for each device, and layouts look correct.

A generic display has no trusted scale. An example is an HDMI panel on a
Raspberry Pi. Software must compute one.

## The key idea

A logical pixel is an angular unit. Each platform unit implies a visual angle
at the eye of the user:

| Unit        | Definition                | Implied visual angle |
| ----------- | ------------------------- | -------------------- |
| CSS px      | 1/96 inch at 711 mm       | 0.0213 degrees       |
| iOS pt      | 1/163 inch at ~360 mm     | 0.0245 degrees       |
| Android dp  | 1/160 inch at ~360 mm     | 0.0253 degrees       |
| Fuchsia pip | defined directly as angle | 0.0255 degrees       |

Android and iOS bake one viewing distance into a constant. This works on
phones because phones have one usage. It fails on a TV or on a desk display.
Fuchsia makes the angle explicit. Then one formula works at every distance.

## The formula

The full model is one line:

```
scale = pxPerMm × tan(0.0255°) × vdist × (0.5 + 180 / vdist)
```

- `pxPerMm`: the pixel density of the display, in pixels per millimeter.
- `vdist`: the viewing distance, in millimeters.
- `0.5 + 180 / vdist`: the adaptation factor.

The first three terms keep one logical pixel at 0.0255 degrees of visual
angle. The last term adapts the result to the distance.

### The adaptation factor

Angular parity alone is not sufficient. Human vision partially corrects for
the distance of an object. This effect is named size constancy. A TV
interface with phone angular sizes looks too large. A desk display with phone
angular sizes holds no more content than a phone.

The adaptation factor corrects for both effects. It is 1.0 at 360 mm. At
360 mm, the model is equal to an Android dp to approximately 1 percent. The
factor decreases toward 0.5 when the viewing distance increases. At 3000 mm,
the factor is 0.56.

### Viewing distance defaults

If the viewing distance is not known, a usage class supplies a default:

| Usage class | Distance | Example                 |
| ----------- | -------- | ----------------------- |
| `handheld`  | 360 mm   | phone, small tablet     |
| `close`     | 500 mm   | laptop                  |
| `near`      | 720 mm   | desktop monitor         |
| `midrange`  | 1200 mm  | kiosk, kitchen display  |
| `far`       | 3000 mm  | TV                      |

## Inputs and fallbacks

The component accepts physical size in two forms: width and height in
millimeters (from EDID), or a diagonal in inches (from a spec sheet).

EDID data is frequently wrong. The component treats a density outside 30 ppi
to 600 ppi as unknown. If the density or the viewing distance is unknown, the
component uses a fallback. The fallback assumes a 96 dpi desktop monitor and
returns a scale near 1.2. This is the same assumption that X11 and Windows
make by default. The `usedFallback` field reports when this occurs.

## Touch targets

Eyes govern legibility. Fingers govern touch targets. A fingertip needs
approximately 8 mm, at every distance. If you supply `TouchTargets`, the
component computes a second scale. This scale makes 48 logical pixels span at
least 8 mm. The final scale is the maximum of the visual scale and the touch
scale.

## Output steps

The raw scale goes through two steps:

1. Integer snap. If the scale is within 2 percent of an integer, the
   component snaps it to that integer. Bitmap assets and 1 px lines render
   sharper at integer scales. A 2 percent size change is not visible.
2. Quantization. Other scales quantize to 8 mantissa bits. The product of the
   scale and any integer up to ±65793 stays exact in float32. This prevents
   seam errors in layout.

If the touch floor is active and quantization rounds below the floor, the
component takes the next quantization step up.

## How to use it

```dart
import 'package:libmonet/libmonet.dart';

final metrics = DisplayModel(
  widthPx: 1920,
  heightPx: 1080,
  diagonalInches: 7.0,
  usage: DisplayUsage.handheld,
).compute();

metrics.scale;        // 2.0 physical px per logical px
metrics.logicalWidth; // 960.0
```

1. Supply `widthPx` and `heightPx`.
2. If you have EDID data, supply `widthMm` and `heightMm`.
3. If you have a spec sheet, supply `diagonalInches`.
4. Supply a `DisplayUsage` value, or set `viewingDistanceMm`.
5. If the display has touch, supply `TouchTargets`.
6. Call `compute()`. Read `scale`, `logicalWidth`, and `logicalHeight`.

For diagnostics, read `visualScale`, `touchScale`, `usedFallback`, and
`logicalPixelAngleDegrees`. Compare `logicalPixelAngleDegrees` with the
0.0255 degree target. For reference, 20/20 vision resolves 0.0167 degrees.

## Example results

The test suite contains golden values for real hardware:

| Display                               | Usage    | Scale      | Logical size |
| ------------------------------------- | -------- | ---------- | ------------ |
| iPhone Air, 2736×1260, 6.5 in         | handheld | 2.921875   | 431×936      |
| MacBook Pro 16 in, 3456×2234          | close    | 1.9140625  | 1806×1167    |
| Raspberry Pi panel, 1920×1080, 7 in   | close    | 2.375      | 808×455      |
| Raspberry Pi panel, 1024×600, 7 in    | close    | 1.28125    | 799×468      |
| ESP32-P4 panel, 720×720, 4 in         | handheld | 1.609375   | 447×447      |
| Cheap Yellow Display, 240×320, 2.8 in | handheld | 0.90234375 | 266×355      |

Two results need explanation. Apple ships 3.0 for the iPhone Air and 2.0 for
the MacBook Pro. Apple rounds up to integer scales, and the model lands 3 to
4 percent lower. Second, a scale below 1.0 is correct for low-density panels.
The pixels of the Cheap Yellow Display are larger than one logical pixel, so
the logical resolution is larger than the physical resolution.

## Differences from the Fuchsia code

The Dart port adds four behaviors:

1. Integer snap within 2 percent.
2. An optional touch-target floor.
3. A plausibility guard for density (30 ppi to 600 ppi).
4. Physical size input as a diagonal in inches.

The angular constant, the adaptation factor, the usage distances, the
quantization, and the fallback are unchanged.

## Files

- `README.md`: this document.
- `fuchsia/ui_units_and_metrics.md`: the Fuchsia units document, verbatim.
- `fuchsia/display_model.h`, `fuchsia/display_model.cc`: the Fuchsia
  implementation, verbatim. All constants in the Dart port come from these
  files.
- `fuchsia/display_metrics.h`: the Fuchsia output structure, verbatim.

The `fuchsia/` files come from the `garnet` repository of the Fuchsia
project. Copyright 2017 The Fuchsia Authors. The source files keep their
original headers and are under a BSD-style license. The license text is in
the LICENSE file of the `garnet` repository.
