# AndroidX Material shape reference exporter

This isolated Kotlin/JVM project imports the published AndroidX Material3
artifact and serializes every `MaterialShapes` polygon directly from Kotlin. It
does not import the Dart port or any generated libmonet data.

From the libmonet root, regenerate the fixture with:

```bash
./tool/generate_material_shapes_reference.sh
```

The Gradle wrapper verifies its distribution checksum. The Material3 version is
pinned in `build.gradle.kts`; Maven artifacts are immutable. The exporter writes
all cubics in traversal order, with each cubic represented as:

```text
anchor0X, anchor0Y, control0X, control0Y,
control1X, control1Y, anchor1X, anchor1Y
```

`test/shapes/material_shapes_androidx_parity_test.dart` compares that fixture to
the Dart catalog. Cubic count and order must match exactly. Coordinates permit a
small epsilon because AndroidX calculates with Kotlin `Float`, whereas the Dart
port calculates with `double`.

When updating AndroidX Material3:

1. Change `material3Version` in `build.gradle.kts`.
2. Regenerate the fixture.
3. Update the expected source in the Dart parity test.
4. Run the parity test and investigate every geometric difference; do not merely
   increase its epsilon.
5. Regenerate and recertify libmonet's safe-area table before updating the pinned
   `androidx_graphics_shapes` dependency.
