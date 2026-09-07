# Expressive buttons

An expressive shape has lobes, notches, and points. A rectangle of content does
not fit inside such an outline in the same way that it fits inside a rounded
rectangle. This library measures the content, then chooses a surface size that
keeps the content inside a certified interior rectangle of the shape.

There are two widgets:

- `ExpressiveButton` is a stock Flutter button with this layout.
- `ExpressiveShapeContent` is the layout alone, for a custom surface.

Both come from `package:libmonet/shapes/expressive_button.dart`, which
`package:libmonet/libmonet.dart` also exports. For the shape catalog itself, see
[Material 3 Expressive shapes](material_expressive_shapes.md).

## Quick start

```dart
import 'package:libmonet/shapes/expressive_button.dart';

// Keep this object in a State or another long-lived owner.
// Create a new one when the endpoints change.
final geometry = ExpressiveShapeGeometry(
  to: MaterialExpressiveShape.cookie7Sided,
);

ExpressiveButton(
  geometry: geometry,
  onPressed: save,
  stretch: true,
  constraints: const BoxConstraints(minWidth: 48, minHeight: 48, maxWidth: 280),
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  child: const Text('Save my changes'),
);
```

## Parameters

| Parameter | Function |
|---|---|
| `geometry` | The shape or the pair of morph endpoints, and their interiors. |
| `variant` | `elevated` (default), `filled`, or `outlined`. |
| `progress` | The morph position, from 0 to 1. The default is 1. |
| `stretch` | If true, the shape fills both axes. If false, it keeps its proportions. |
| `padding` | Space between the content and the interior rectangle. |
| `clearance` | Extra space in logical pixels for the stroke and anti-aliasing. |
| `constraints` | The size limits of the surface. The default minimum is 48 by 48. |
| `overflow` | The policy for a parent that is too small. |
| `style` | Colors, typography, elevation, overlays, and the side. |

Flutter keeps the interaction, keyboard activation, focus, disabled semantics,
and ink. The button overrides the shape, the padding, the alignment, the visual
density, the animation duration, and the size fields of `style`. These fields
must stay under the control of this widget, because the layout coordinates and
the paint coordinates must be identical. To set the size, use `padding` and
`constraints`. The constraints of the parent always win.

## How the layout works

libmonet ships const Dart rectangles that are certified to stay inside each
catalog outline. There is no asset, no JSON parse, no run-time search of the
curve, and no precompute in consumer code.

For each candidate rectangle, the layout measures the content at the available
wrapping width. Then it sizes the surface so that the content and padding fit.
Every candidate is centered on one precomputed optical center. Layout can scale
content down when space is constrained, but it never translates content away
from that center to gain size.

The ratios in the table are candidates, not limits on the aspect ratio of your
label. A candidate stays safe when the content fits both of its dimensions.

### Placement

`geometry.border()` returns a `BoundsCenteredBorder` around the polygon border or
the morph border. The border scales the path, then centers the bounds of the path
in the surface. This is the same convention as `toShape` in Compose. The border
does not stretch the path to fill its bounds.

For each aspect ratio the generator retains the largest rectangle centered on
the shape's optical center. That center is generated from the silhouette without
shape-name exceptions:

- multiple reflection axes use their common intersection;
- one reflection axis uses the point of maximum outline clearance on that axis;
- no detected reflection axis uses the convex-hull centroid.

The layout applies the same bounds-centering translation to the optical center
and rectangle as to the path.

For a morph, endpoint rectangles are translated independently, intersected, and
cropped symmetrically around the average of the endpoint optical centers. One
fixed content center stays valid through the animation.

### Clearance

`clearance` reserves logical pixels between the content padding and the safe
outline. It covers the stroke and anti-aliasing. It is separate from the
normalized clearance of the generated table.

The default of `ExpressiveButton` is 5 pixels. This value covers its default
1-pixel outline with a miter limit of 4, plus anti-aliasing. The default of
`ExpressiveShapeContent` is 1 pixel.

If the border is thick or changes with the state of the button, reserve the
largest inward extent of the stroke across all states, and include the miter
joins. The example application uses 9 pixels for its 2-pixel outline.

### Content

The content must support intrinsic measurement and dry layout. `Text`, `Icon`,
`Row`, and `Column` are supported. `LayoutBuilder` content and viewport content
are not supported.

`ExpressiveShapeContent` supports `IntrinsicWidth` and `IntrinsicHeight`.
`ExpressiveButton` uses a `LayoutBuilder`, so you cannot put the button itself
under a parent that measures intrinsic sizes.

A widget that paints outside its reported bounds stays the responsibility of the
caller. Custom painting, shadows, and explicit text overflow are examples. The
library does not override a `maxLines` value or an ellipsis that the caller
chose.

### Overflow

If the constraints prevent a fit, the `overflow` policy decides what happens:

- `ExpressiveContentOverflow.scaleDown` is the default. It scales the content and
  its padding down together. It keeps the content inside the outline, but it can
  make text too small to read. This is an explicit tradeoff, not a guarantee of
  accessibility.
- `ExpressiveContentOverflow.error` raises a layout error. Use it when a smaller
  content is not acceptable. Then give more space, set `stretch` to true, or
  simplify the shape or the content.

Zero space can never give a usable button.

## Morphs

```dart
final geometry = ExpressiveShapeGeometry(
  from: MaterialExpressiveShape.circle,
  to: MaterialExpressiveShape.heart,
);

// In an animation builder:
ExpressiveButton(
  geometry: geometry,
  progress: animation.value,
  onPressed: save,
  child: const Icon(Icons.favorite),
);
```

The library intersects the safe rectangles of the two endpoints one time. One
layout stays valid for the full transition. The library also caches the feature
matching of the morph in the geometry object.

Only the endpoints must contain the content. Intermediate frames can clip. A
change of content, constraints, padding, typography, or stretch starts a new
layout.

### Interruptible selection

To redirect a morph while it runs, capture a new geometry:

```dart
geometry = geometry.retarget(newSelection, progress: controller.value);
controller.forward(from: 0);
```

At a settled endpoint, `retarget` uses the features of the original catalog
polygon. During an animation, it captures the cubic outline on display, connects
the endpoints as `Path.cubicTo` does, and matches it to the destination with
ignorable edge features. A captured frame has no corner metadata, so the match
uses perimeter correspondence. It does not claim that the original corner
associations survive.

`retarget` preserves the position. It does not preserve the velocity. Each call
keeps one new snapshot, not a chain of previous animations.

A decaying alignment correction prevents a jump in position when the new match
splits curves and moves their control-point bounds. The correction reaches zero
at the destination, which keeps normal bounds centering.

CAUTION: The interrupted frame is not a certified endpoint. Only the safe
rectangles of the new destination govern the new leg of the animation.

## Custom surfaces

`ExpressiveShapeContent` is the lower-level widget. A custom surface keeps its
own gesture, focus, semantics, shadow, and paint code:

```dart
final border = geometry.border(progress: progress, stretch: stretch);

// Inside your existing interaction wrappers:
Material(
  shape: border,
  animationDuration: Duration.zero,
  clipBehavior: Clip.antiAlias,
  child: ExpressiveShapeContent(
    geometry: geometry,
    stretch: stretch,
    padding: contentPadding,
    clearance: 5,
    child: foreground,
  ),
);
```

The contract has five rules:

1. Make sure that the bounds of `ExpressiveShapeContent` are equal to the
   rectangle that you give to `border.getOuterPath`.
2. Do not put a `Padding` widget or a sizing `Align` widget between the content
   widget and the painted surface. Put the constraints of the surface outside
   both.
3. Use the same `geometry` object and the same `stretch` value for the paint and
   for the layout.
4. Use the border from `geometry.border()`. Do not use the unwrapped
   `source` border, because it has no bounds centering.
5. Do not substitute a border with different endpoint paths, different stroke
   behavior, or a different transform.

A repaint of the palette does not need a new geometry object and does not start a
new layout.
