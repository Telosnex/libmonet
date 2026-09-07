import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:androidx_graphics_shapes/material_shapes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/shapes/material_expressive_shape.dart';
import 'package:libmonet/shapes/src/material_shape_safe_area_data.dart';

import '../../tool/src/optical_center.dart';
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

  test('checked-in JSON and Dart tables agree', () {
    final data = jsonDecode(
      File('tool/data/material_shape_safe_areas.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(data['schemaVersion'], 5);
    final shapes = (data['shapes'] as List).cast<Map<String, dynamic>>();
    expect(
      shapes.map((entry) => entry['shape']),
      MaterialExpressiveShape.values.map((shape) => shape.name),
    );
    for (var i = 0; i < shapes.length; i++) {
      final shape = MaterialExpressiveShape.values[i];
      Offset decodePoint(String key) {
        final values = (shapes[i][key] as List).cast<num>();
        return Offset(values[0].toDouble(), values[1].toDouble());
      }

      final areaCentroid = decodePoint('areaCentroid');
      expect(materialShapeAreaCentroidData[shape], areaCentroid);
      final optical = findOpticalCenter(
        cubics: shape.polygon.cubics,
        path: shape.polygon.toPath(),
        areaCentroid: areaCentroid,
      );
      final preferredCenter = decodePoint('preferredCenter');
      expect(materialShapePreferredCenterData[shape], preferredCenter);
      expect(
        preferredCenter,
        offsetMoreOrLessEquals(optical.center, epsilon: 1e-12),
      );
      expect(shapes[i]['centerMethod'], optical.method.name);
      expect(shapes[i]['reflectionAxisCount'], optical.axisCount);
      expect(
        decodePoint('convexHullCentroid'),
        offsetMoreOrLessEquals(optical.hullCentroid, epsilon: 1e-12),
      );
      final dartRects = materialShapeSafeAreaData[shape]!;
      final jsonRects = [
        for (final entry in shapes[i]['rectangles'] as List)
          (() {
            final values = (entry['rect'] as List)
                .cast<num>()
                .map((value) => value.toDouble())
                .toList();
            return Rect.fromLTRB(values[0], values[1], values[2], values[3]);
          })(),
      ];
      expect(jsonRects, dartRects);
      for (final rect in dartRects) {
        expect(
          rect.center,
          offsetMoreOrLessEquals(preferredCenter, epsilon: 1e-12),
          reason: shape.name,
        );
      }
    }
  });

  test('square agrees with analytic centered solution and clearance', () {
    final outline = SafeInteriorOutline(square);
    for (final ratio in [0.5, 1.0, 2.0, 8.0]) {
      final rect = outline.find(aspectRatio: ratio, clearance: 0.02)!;
      final expectedHeight = ratio < 1 ? 0.96 : 0.96 / ratio;
      expect(rect.height, closeTo(expectedHeight, 2e-6));
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

  test('free translation finds the analytic maximum square in a triangle', () {
    final outline = SafeInteriorOutline(
      lines(const [Offset(0.5, 0), Offset(1, 1), Offset(0, 1)]),
    );
    final rect = outline.find(
      aspectRatio: 1,
      clearance: 0,
      tolerance: 1e-6,
      preferredCenter: const Offset(0.5, 0.5),
    )!;
    final anchored = outline.findAtCenter(
      aspectRatio: 1,
      center: const Offset(0.5, 0.5),
      clearance: 0,
      tolerance: 1e-6,
    )!;

    expect(anchored.width, closeTo(1 / 3, 2e-5));
    expect(anchored.center, const Offset(0.5, 0.5));
    expect(outline.areaCentroid.dx, closeTo(0.5, 1e-12));
    expect(outline.areaCentroid.dy, closeTo(2 / 3, 1e-12));
    expect(rect.width, closeTo(0.5, 2e-5));
    expect(rect.height, closeTo(0.5, 2e-5));
    expect(rect.center.dx, closeTo(0.5, 2e-5));
    expect(rect.center.dy, closeTo(0.75, 2e-5));
    expect(outline.contains(rect, clearance: 0), isTrue);
  });

  test('flat catalog optima remain at their design anchors', () {
    for (final (shape, ratio) in [
      (MaterialExpressiveShape.bun, 0.75),
      (MaterialExpressiveShape.bun, 1.0),
      (MaterialExpressiveShape.pixelCircle, 1.0),
    ]) {
      final outline = SafeInteriorOutline(shape.polygon.cubics);
      final anchor = shape.polygon.toPath().getBounds().center;
      final rect = outline.find(aspectRatio: ratio, preferredCenter: anchor)!;
      expect(
        (rect.center - anchor).distance,
        lessThan(1e-10),
        reason: '${shape.name} ratio=$ratio',
      );
    }
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
      expect(safe.width, greaterThan(0.6));
      expect(outline.contains(safe), isTrue);
    },
  );

  test('free translation finds a safe lobe when bounds center is unfilled', () {
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
    final rect = outline.find(aspectRatio: 1)!;
    expect(rect.center.dx, isNot(closeTo(0.5, 0.01)));
    expect(outline.contains(rect), isTrue);
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
      final coarseSafe = coarse.find(
        aspectRatio: 1,
        clearance: 0,
        tolerance: 0.01,
      );
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
    expect(
      () => outline.find(aspectRatio: 1, tolerance: 0),
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
      final path = shape.polygon.toPath();
      for (final (index, ratio) in [0.5, 1.0, 2.0, 4.0, 8.0].indexed) {
        final rect = materialShapeSafeAreaData[shape]![index * 2];
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
