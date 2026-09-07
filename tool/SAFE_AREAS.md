# Endpoint-safe content rectangles

From the libmonet root, after `flutter pub get`:

```sh
dart tool/precompute_safe_areas.dart --dart-output=lib/shapes/src/material_shape_safe_area_data.dart
# Optional settings:
dart tool/precompute_safe_areas.dart --ratios=0.5,1,2,4,8 --clearance=0.015 --output=/tmp/safe.json
```

The Dart launcher invokes one explicit worker through Flutter's headless test
engine, because the geometry package imports `dart:ui`. No device, build_runner,
or full test suite is involved. `flutter` must be on PATH. Output paths are
relative to the caller's working directory. Failures propagate a nonzero exit.

Default output: `tool/data/material_shape_safe_areas.json`, covering all 35 shapes
and nine width/height ratios: 0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8. This is offline
layout data. `--dart-output` additionally emits the const Dart table shipped in
libmonet; consumers need no assets or JSON loading. See
[ExpressiveButton usage](../docs/expressive_buttons.md).

## Meaning of an entry

`rect` is `[left, top, right, bottom]` in the package polygon's **original unit
coordinates**, centered at that shape's `Path.getBounds().center` (stored as
`shapes[].anchor` in schema version 2). We do not resize or renormalize the path.
Some shapes leave unused space inside the unit square.

- Each rectangle has the requested width/height ratio.
- `clearance` is additional rectangular clearance from the outline, in source
  units (default 0.01). It is **not logical-pixel padding or a stroke allowance**.
- `null` means no useful safe rectangle at this center. It does not mean the
  entire shape has no usable interior elsewhere.
- Output preserves full double precision. Do not round coordinates outward.
- Generation is deterministic. Regenerate after upgrading the geometry fork;
  the checked-in table test detects changes to the calculated rectangles.

## Algorithm and safety limits

Binary-search the size of nested, centered rectangles, bounded by the unit
square. Accept a candidate only if its center is inside the actual filled Path
and every outline cubic is excluded from the rectangle inflated by clearance
plus a `1e-9` numerical guard.

A cubic lies inside the convex hull of its four control points, hence inside
their axis-aligned bounding box. If that box is strictly separated from the
protected rectangle, the cubic cannot enter it. Otherwise, subdivide at t=0.5
and test both children. Touching or unresolved overlap at depth 24 is rejected,
not assumed safe. This avoids the concave-notch failure of corner-only tests
and does not rely on raster/frame sampling. Bounds are cached for the offline
search. The result is conservative, not a global maximum over possible centers.

This is floating-point geometry with a guard, not a formally verified exact
arithmetic proof. Visual anti-aliasing and border strokes need their own runtime
allowance. Tests include analytic shapes, concave notches, fail-closed behavior,
and independent dense filled-path checks for every catalog shape.

## Consuming it in a button

Measure the content **plus desired content padding**. For a selected safe
rectangle of width `w` and height `h`, and padded content size `(cw, ch)`, a
uniform source-coordinate scale must be at least:

```text
scale = max(cw / w, ch / h)
```

Choosing the closest ratio is an efficiency choice, not a containment condition:
any entry remains safe if the actual content fits both its dimensions. Do not
interpolate rectangles or union them; neither operation preserves containment.
Use the same coordinate transform as the rendered border for both shape and safe
rectangle. `ExpressiveShapeGeometry` wraps the fork's borders with
`BoundsCenteredBorder`: scale by the shortest surface dimension when stretch is
off, independently by width/height when on, then center the scaled path bounds.
The layout translates a certified rectangle into these centered coordinates.
For morph endpoints, it uses a centered subset around the actual endpoint bounds
center: curve subdivision can change reported bounds despite preserving the
outline. Only then are endpoint rectangles intersected. Do not substitute the
unwrapped fork border, whose unit-square centering differs. Tests check the
rendered transform and containment, not just the raw lookup data.

Inset the transformed safe rectangle further for any unaccounted-for inward
stroke/AA allowance, then verify that content still fits. If parent constraints
prevent the required size, use an explicit fallback instead of claiming safety.

Only static endpoints must fit. For a morphing button choose a stable layout
that fits the transformed safe rectangles at both endpoints, or lay out the
endpoints separately. Intermediate frames may overflow/clip by design; there are
no morph-pair tables and no promise of containment during transitions.
