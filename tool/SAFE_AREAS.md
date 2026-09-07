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

Each aspect-ratio entry contains two rectangles in the package polygon's
**original unit coordinates**:

- `anchoredRect`: the largest rectangle whose center is the path-bounds center.
- `maximumRect`: a rectangle within `tolerance` of the globally largest freely
  translated rectangle, choosing the placement nearest that same anchor.

Both use `[left, top, right, bottom]`. Keeping these two Pareto endpoints lets
runtime layout decide whether additional size is worth visible displacement. We
do not resize or renormalize the path; some shapes leave unused space inside the
unit square.

- Each rectangle has the requested width/height ratio.
- `preferredCenter` is the design anchor used by both generation and runtime.
- `clearance` is additional rectangular clearance from the outline, in source
  units (default 0.01). It is **not logical-pixel padding or a stroke allowance**.
- `tolerance` bounds the maximum rectangle's source-coordinate height loss from
  the global maximum (default `1e-5`).
- `areaCentroid` is retained as exact geometric diagnostic metadata; it is not
  the design anchor.
- `null` means no useful certified rectangle exists for that objective.
- Output preserves full double precision. Do not round coordinates outward.
- Generation is deterministic. Regenerate after upgrading the geometry fork.

## Algorithm and safety limits

For a fixed center, binary-search the size of nested rectangles. A candidate is
accepted only if its center is inside the actual filled Path and every outline
cubic is excluded from the rectangle inflated by clearance plus a `1e-9`
numerical guard.

The center is optimized globally with deterministic branch-and-bound. If `F(c)`
is the maximum rectangle height at center `c`, then for centers `c` and `d`,

```text
|F(c) - F(d)| <= 2 * max(|cx-dx| / aspectRatio, |cy-dy|).
```

This follows by translating a contained rectangle and reducing its half-extents
by the translation on each axis. The inequality gives a certified upper bound
for every unvisited center cell. Local coordinate searches supply good lower
bounds but cannot decide termination.

`anchoredRect` needs only fixed-center bisection. For `maximumRect`, the first
branch-and-bound search uses one quarter of `tolerance` to bound the unknown
global maximum. A second search uses the remaining budget as an epsilon
constraint and minimizes Euclidean center distance from `preferredCenter`. Its
cells are ordered by a lower bound on anchor distance and rejected when the
Lipschitz bound proves they cannot contain the target rectangle. This prevents
binary-search grid noise from moving symmetric plateaus.

A cubic lies inside the convex hull of its four control points, hence inside
their axis-aligned bounding box. If that box is strictly separated from the
protected rectangle, the cubic cannot enter it. Otherwise, subdivide at t=0.5
and test both children. Touching or unresolved overlap at depth 24 is rejected,
not assumed safe. This avoids the concave-notch failure of corner-only tests
and does not rely on raster/frame sampling. Bounds are cached for the offline
search. The returned rectangle is contained and within the requested numerical
tolerance of the global maximum over translations.

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
certified rectangle. It prefers the anchored option once content reaches its
configured minimum scale and otherwise prefers maximum rendered scale. For morphs, endpoint rectangles are translated independently and then
intersected. Do not substitute
the unwrapped fork border, whose unit-square centering differs. Tests check the
rendered transform and containment, not just the raw lookup data.

Inset the transformed safe rectangle further for any unaccounted-for inward
stroke/AA allowance, then verify that content still fits. If parent constraints
prevent the required size, use an explicit fallback instead of claiming safety.

Only static endpoints must fit. For a morphing button choose a stable layout
that fits the transformed safe rectangles at both endpoints, or lay out the
endpoints separately. Intermediate frames may overflow/clip by design; there are
no morph-pair tables and no promise of containment during transitions.
