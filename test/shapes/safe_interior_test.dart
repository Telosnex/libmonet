import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:androidx_graphics_shapes/material_shapes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/shapes/material_expressive_shape.dart';

import '../../tool/src/safe_interior.dart';

List<Cubic> lines(List<Offset> points) => [
  for (var i = 0; i < points.length; i++)
    Cubic.straightLine(
      points[i].dx,
      points[i].dy,
      points[(i + 1) % points.length].dx,
      points[(i + 1) % points.length].dy,
    ),
];

void main() {
  final square = lines(const [
    Offset(0, 0),
    Offset(1, 0),
    Offset(1, 1),
    Offset(0, 1),
  ]);

  test('checked-in table matches current geometry and generator', () {
    final data = jsonDecode(
      File('tool/data/material_shape_safe_areas.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final shapes = (data['shapes'] as List).cast<Map<String, dynamic>>();
    expect(
      shapes.map((entry) => entry['shape']),
      MaterialExpressiveShape.values.map((shape) => shape.name),
    );
    for (var i = 0; i < shapes.length; i++) {
      final outline = SafeInteriorOutline(
        MaterialExpressiveShape.values[i].polygon.cubics,
      );
      for (final entry in shapes[i]['rectangles'] as List) {
        final rect = outline.find(
          aspectRatio: (entry['aspectRatio'] as num).toDouble(),
          clearance: (data['clearance'] as num).toDouble(),
          center: MaterialExpressiveShape.values[i].polygon
              .toPath()
              .getBounds()
              .center,
        );
        expect(
          entry['rect'],
          rect == null ? null : [rect.left, rect.top, rect.right, rect.bottom],
        );
      }
    }
  });

  test('square agrees with analytic centered solution and clearance', () {
    final outline = SafeInteriorOutline(square);
    for (final ratio in [0.5, 1.0, 2.0, 8.0]) {
      final rect = outline.find(aspectRatio: ratio, clearance: 0.02)!;
      final expectedHeight = ratio < 1 ? 0.96 : 0.96 / ratio;
      expect(rect.height, closeTo(expectedHeight, 1e-7));
      expect(rect.width / rect.height, closeTo(ratio, 1e-10));
      expect(rect.center, const Offset(0.5, 0.5));
      expect(outline.contains(rect, clearance: 0.02), isTrue);
      expect(outline.contains(rect.inflate(1e-5), clearance: 0.02), isFalse);
    }
    expect(
      outline.contains(const Rect.fromLTRB(0, 0, 1, 1), clearance: 0),
      isFalse,
    );
  });

  test(
    'concave notch between corners is rejected even when center is filled',
    () {
      final curves = lines(const [
        Offset(0, 0),
        Offset(0.2, 0),
        Offset(0.2, 0.4),
        Offset(0.3, 0.4),
        Offset(0.3, 0),
        Offset(1, 0),
        Offset(1, 1),
        Offset(0, 1),
      ]);
      final outline = SafeInteriorOutline(curves);
      const rect = Rect.fromLTRB(0.1, 0.1, 0.9, 0.9);
      // Corners and center all fit; the notch still intersects the rectangle.
      for (final point in [
        rect.topLeft,
        rect.topRight,
        rect.bottomLeft,
        rect.bottomRight,
        rect.center,
      ]) {
        expect(
          outline.contains(
            Rect.fromCenter(center: point, width: 0.001, height: 0.001),
            clearance: 0,
          ),
          isTrue,
        );
      }
      expect(outline.contains(rect, clearance: 0), isFalse);
      final safe = outline.find(aspectRatio: 1)!;
      expect(safe.width, lessThan(0.4));
    },
  );

  test('unfilled center returns null instead of an unsafe rectangle', () {
    final outline = SafeInteriorOutline(
      lines(const [
        Offset(0, 0),
        Offset(0.4, 0),
        Offset(0.4, 0.7),
        Offset(0.6, 0.7),
        Offset(0.6, 0),
        Offset(1, 0),
        Offset(1, 1),
        Offset(0, 1),
      ]),
    );
    expect(outline.find(aspectRatio: 1), isNull);
  });

  test(
    'subdivision resolves curved bounds; insufficient depth fails closed',
    () {
      // Canonical unit circle approximation, independent of catalog rounding
      // and normalization (the catalog circle is not an exact unit circle).
      const k = 0.2761423749153967;
      final circle = [
        Cubic.from(1, .5, 1, .5 + k, .5 + k, 1, .5, 1),
        Cubic.from(.5, 1, .5 - k, 1, 0, .5 + k, 0, .5),
        Cubic.from(0, .5, 0, .5 - k, .5 - k, 0, .5, 0),
        Cubic.from(.5, 0, .5 + k, 0, 1, .5 - k, 1, .5),
      ];
      final fine = SafeInteriorOutline(circle);
      final coarse = SafeInteriorOutline(circle, maxDepth: 0);
      final safe = fine.find(aspectRatio: 1, clearance: 0)!;
      expect(safe.width, closeTo(0.7071, 0.002));
      expect(fine.contains(safe, clearance: 0), isTrue);
      final coarseSafe = coarse.find(aspectRatio: 1, clearance: 0);
      expect(coarseSafe == null || coarseSafe.width <= safe.width, isTrue);
    },
  );

  test('invalid configuration and open or nonfinite geometry are rejected', () {
    final outline = SafeInteriorOutline(square);
    for (final value in [0.0, -1.0, double.nan, double.infinity]) {
      expect(() => outline.find(aspectRatio: value), throwsArgumentError);
    }
    expect(
      () => outline.find(aspectRatio: 1, clearance: -1),
      throwsArgumentError,
    );
    expect(() => SafeInteriorOutline([]), throwsArgumentError);
    expect(() => SafeInteriorOutline(square.take(3)), throwsArgumentError);
    expect(
      () => SafeInteriorOutline(square, maxDepth: -1),
      throwsArgumentError,
    );
    expect(
      () => SafeInteriorOutline([Cubic.from(double.nan, 0, 0, 0, 0, 0, 0, 0)]),
      throwsArgumentError,
    );
  });

  test('all catalog rectangles pass independent dense filled-path checks', () {
    for (final shape in MaterialExpressiveShape.values) {
      final outline = SafeInteriorOutline(shape.polygon.cubics);
      final path = shape.polygon.toPath();
      for (final ratio in [0.5, 1.0, 2.0, 4.0, 8.0]) {
        final rect = outline.find(aspectRatio: ratio)!;
        expect(outline.find(aspectRatio: ratio), rect); // Deterministic.
        expect(rect.width / rect.height, closeTo(ratio, 1e-10));
        final expanded = rect.inflate(
          0.009,
        ); // Within the reserved 0.01 margin.
        for (var y = 0; y <= 20; y++) {
          for (var x = 0; x <= 20; x++) {
            final point = Offset(
              expanded.left + expanded.width * x / 20,
              expanded.top + expanded.height * y / 20,
            );
            expect(
              path.contains(point),
              isTrue,
              reason: '${shape.name} ratio=$ratio point=$point',
            );
          }
        }
      }
    }
  });
}
