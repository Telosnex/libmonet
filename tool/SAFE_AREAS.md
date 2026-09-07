# Endpoint-safe content rectangles

From the libmonet root, after `flutter pub get`:

```sh
dart tool/precompute_safe_areas.dart --dart-output=lib/shapes/src/material_shape_safe_area_data.dart
# Optional settings:
dart tool/precompute_safe_areas.dart --ratios=0.5,1,2,4,8 --clearance=0.015 --tolerance=0.00001 --output=/tmp/safe.json
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

Each aspect-ratio entry contains the largest certified rectangle centered on the
shape's generated optical center, in the package polygon's **original unit
coordinates**. `rect` uses `[left, top, right, bottom]`.

- Each rectangle has the requested width/height ratio.
- `preferredCenter` is the generated optical center used by layout.
- `centerMethod` records which branch of the center algorithm selected it.
- `reflectionAxisCount` records the number of detected axes.
- `areaCentroid` and `convexHullCentroid` are diagnostic metadata.
- `clearance` is additional rectangular clearance from the outline, in source
  units (default 0.01). It is **not logical-pixel padding or a stroke allowance**.
- `tolerance` bounds fixed-center size bisection (default `1e-5`).
- `null` means no useful certified rectangle exists at that optical center.
- Output preserves full double precision. Do not round coordinates outward.
- Generation is deterministic. Regenerate after upgrading the geometry fork or
  changing the optical-center algorithm.

## Algorithm and safety limits

The generator derives the optical center from the silhouette without a
shape-name lookup. It flattens each cubic into 200 segments and resamples the
closed outline at 512 equal arc-length positions. Reflection reverses traversal
order, so cyclic reversal fits reveal reflection axes. The fit uses both RMS and
maximum residual thresholds.

- Multiple detected axes meet at the area centroid, which becomes the center.
- With exactly one axis, a deterministic 4096-interval search chooses the
  interior point on that axis with maximum distance from the outline.
- With no detected axis, the filled convex-hull centroid becomes the center.

At that fixed center, binary-search the size of nested rectangles. A candidate
is accepted only if its center is inside the actual filled Path and every
outline cubic is excluded from the rectangle inflated by clearance plus a
`1e-9` numerical guard. The polyline approximation chooses placement only;
rectangle containment is separately checked against the original cubics.

A cubic lies inside the convex hull of its four control points, hence inside
their axis-aligned bounding box. If that box is strictly separated from the
protected rectangle, the cubic cannot enter it. Otherwise, subdivide at t=0.5
and test both children. Touching or unresolved overlap at depth 24 is rejected,
not assumed safe. This avoids the concave-notch failure of corner-only tests
and does not rely on raster/frame sampling. Bounds are cached for the offline
search. The returned rectangle is contained and within the requested numerical
tolerance of the maximum at its fixed optical center.

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
The layout applies the border's exact bounds-centering translation to every
certified rectangle and its optical center. For morphs, endpoint rectangles are
translated independently, intersected, and cropped around the averaged optical
center. Content can scale down but never translates to gain size. Do not
substitute
the unwrapped fork border, whose unit-square centering differs. Tests check the
rendered transform and containment, not just the raw lookup data.

Inset the transformed safe rectangle further for any unaccounted-for inward
stroke/AA allowance, then verify that content still fits. If parent constraints
prevent the required size, use an explicit fallback instead of claiming safety.

Only static endpoints must fit. For a morphing button choose a stable layout
that fits the transformed safe rectangles at both endpoints, or lay out the
endpoints separately. Intermediate frames may overflow/clip by design; there are
no morph-pair tables and no promise of containment during transitions.
