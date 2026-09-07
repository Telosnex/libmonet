# Material 3 Expressive shapes

libmonet gives the 35 Material 3 Expressive silhouettes as Flutter borders. The
geometry comes from the `androidx_graphics_shapes` package. The
`MaterialExpressiveShape` enum maps a name to a polygon in that catalog. libmonet
stores no shape coordinates of its own.

There are two entry points:

- `MaterialExpressiveBorder` paints one static shape.
- `ExpressiveShapeGeometry` pairs a static or animated border with precomputed
  content rectangles. For buttons and other content, see
  [Expressive buttons](expressive_buttons.md).

## Import

`package:libmonet/libmonet.dart` exports both entry points. You can also import
one file:

```dart
import 'package:libmonet/shapes/material_expressive_border.dart';
import 'package:libmonet/shapes/expressive_button.dart';
```

## One static shape

```dart
const shape = MaterialExpressiveBorder(
  shape: MaterialExpressiveShape.cookie7Sided,
);

MonetClip(shape: shape, child: myImage);
Material(shape: shape, clipBehavior: Clip.antiAlias, child: myContent);
InkWell(customBorder: shape, onTap: onTap, child: myContent);
```

The border is a const value. To draw an outline, give it a `side`. To fill the
bounds on both axes, set `stretch` to true.

## Geometry

The catalog polygons use normalized unit coordinates. By default the border
scales the unit path by the shortest side of the bounds. Then it centers the
bounds of the path. A non-square motif keeps its proportions.

`stretch: true` scales each axis independently to fill the bounds. This is the
same mapping as `RoundedPolygon.toShape` in Compose.

The result is geometric centering, not optical centering. The border uses the
bounds of the path. A shape with asymmetric visual weight, such as `fan`, can
still look off-center. libmonet applies no shape-specific offset and no estimate
of the visual centroid.

These are dimensionless motifs, not configurable rounded rectangles:

- The rounding scales with the size of the widget. The border reads no
  corner-radius token. To scale the motif, change the size of the widget.
- `scale()` scales the border side only.
- `dimensions` reports the stroke inset only.
- Stroke placement and the inner path use an adjusted rectangle, as `StarBorder`
  in Flutter does. This is not an exact constant-distance offset of a concave
  curve. For lobes and notches, add content padding.
- The shapes do not mirror in a right-to-left text direction.
- An empty rectangle or a non-finite rectangle gives an empty path.
- Unit paths are cached. Each returned path is an independent copy, so a caller
  cannot change the cached path.
- `copyWith`, equality, stroke alignment, hairlines, and interpolation of the
  border side are supported.
- A change of `shape` or of `stretch` switches at the midpoint of an
  interpolation. `MaterialExpressiveBorder` does not morph.

The border needs no assets and no network access at run time.

## Morphing

`MaterialExpressiveBorder` switches at the midpoint. For a continuous
transition, use a morph.

`ExpressiveShapeGeometry` is the recommended API. It applies the same bounds
centering as the static border, and it also gives content rectangles:

```dart
// Keep this object while the endpoints stay the same.
final geometry = ExpressiveShapeGeometry(
  from: MaterialExpressiveShape.circle,
  to: MaterialExpressiveShape.heart,
);

// In an animation builder:
final border = geometry.border(progress: animation.value);
```

The geometry matches the morph one time for each pair of endpoints, not for each
frame. `progress` must be in the range 0 to 1.

The dependency also exports `Morph`, `RoundedPolygonBorder`, and `MorphBorder`
for direct use:

```dart
import 'package:androidx_graphics_shapes/material_shapes.dart';

// Create one Morph for each pair of endpoints. Do not create one for each frame.
final morph = Morph(MaterialShapes.circle, MaterialShapes.cookie7Sided);
final border = MorphBorder(morph: morph, progress: animation.value, squash: 1);
```

`MaterialExpressiveShape.cookie7Sided.polygon` gives the same polygon, with the
corner features that the morph needs. These borders center the unit square. Only
`ExpressiveShapeGeometry` adds bounds centering and content rectangles.

## Content-safe rectangles

`ExpressiveShapeGeometry.safeRects` gives centered rectangles that stay inside
the outline. libmonet ships this table as const Dart data in
`lib/shapes/src/material_shape_safe_area_data.dart`. Consumers load no assets and
parse no JSON.

Only the catalog endpoints are certified. During a morph, intermediate frames can
clip the content.

To regenerate the table, run this command from the libmonet root:

```sh
dart tool/precompute_safe_areas.dart \
  --dart-output=lib/shapes/src/material_shape_safe_area_data.dart
```

[The generator guide](../tool/SAFE_AREAS.md) gives the options, the containment
checks, and the coordinate transforms.

## Dependency and provenance

`pubspec.yaml` pins `androidx_graphics_shapes` to the fork revision that
libmonet certified the safe-area table against. The revision is
`37da7df46ab5eb60dc42e440a9e71d5159059f16`.

There is no local path override. The fork needs Dart 3.13 or later, and Flutter
3.47 or later.

CAUTION: Do not float this dependency to a branch. A change of geometry
invalidates the generated safe-area table, and content can then overflow the
outline.

To move to a new revision of the fork:

1. Change `ref` in `pubspec.yaml` and in `example/pubspec.yaml`.
2. Run `flutter pub get`.
3. Regenerate the safe-area table.
4. Run `flutter test test/shapes`.
5. Examine each geometric difference before you accept the result.

The upstream of the fork moved `material_shapes.dart` into a package that depends
on a different package with the name `libmonet`. Fork commit `37da7df` restores
the catalog, the path extensions, and the border helpers inside the fork. This
removes the dependency cycle and keeps the geometry in one package. The restored
source keeps the MIT attribution of deminearchiver. The original algorithm and
catalog come from AndroidX, under Apache-2.0:
https://github.com/androidx/androidx/blob/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/MaterialShapes.kt

## Parity with AndroidX

`test/shapes/material_shapes_androidx_parity_test.dart` compares the Dart catalog
with a reference fixture. The fixture comes from
[`tool/material_shapes_reference`](../tool/material_shapes_reference/README.md),
a Kotlin project that imports the published AndroidX Material3 artifact and
exports every polygon. The test requires the same names, the same cubic counts,
the same traversal order, and the same coordinates within a small epsilon. The
epsilon covers the difference between the Kotlin `Float` type and the Dart
`double` type.

Goldens of the catalog test the rendered result. They are not a proof of parity,
because they use the Dart data on both sides.

## Example application

The example application has a **Material 3 Expressive shapes** section. It shows
all 35 shapes, a morph with playback and progress controls, and the button
integration. To run it, see [the example README](../example/README.md).
