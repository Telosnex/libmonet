import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:androidx_graphics_shapes/material_shapes.dart';
import 'package:flutter/material.dart' hide Cubic;
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/shapes/expressive_button.dart';
import 'package:libmonet/shapes/src/material_shape_safe_area_data.dart';

import '../../tool/src/safe_interior.dart';
import '../../tool/src/optical_center.dart';

const _panelWidth = 700.0;
const _cellSize = 100.0;
const _shapeSize = 80.0;

Offset _point(Cubic cubic, double t) {
  final u = 1 - t;
  return Offset(
    u * u * u * cubic.anchor0X +
        3 * u * u * t * cubic.control0X +
        3 * u * t * t * cubic.control1X +
        t * t * t * cubic.anchor1X,
    u * u * u * cubic.anchor0Y +
        3 * u * u * t * cubic.control0Y +
        3 * u * t * t * cubic.control1Y +
        t * t * t * cubic.anchor1Y,
  );
}

Offset _perimeterCentroid(MaterialExpressiveShape shape) {
  var weighted = Offset.zero;
  var total = 0.0;
  for (final cubic in shape.polygon.cubics) {
    var previous = _point(cubic, 0);
    for (var i = 1; i <= 200; i++) {
      final next = _point(cubic, i / 200);
      final length = (next - previous).distance;
      weighted += (previous + next) / 2 * length;
      total += length;
      previous = next;
    }
  }
  return weighted / total;
}

Offset _mapCenter(Rect rect, Offset rawCenter, Offset rawBoundsCenter) =>
    rect.center + (rawCenter - rawBoundsCenter) * rect.shortestSide;

void _drawMarker(Canvas canvas, Offset center) {
  canvas
    ..drawCircle(center, 16, Paint()..color = Colors.black)
    ..drawCircle(center, 10, Paint()..color = Colors.white);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalog center definitions golden', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..drawColor(Colors.white, BlendMode.src);
    final fill = Paint()..color = const Color(0xff6750a4);

    final metadata = <Map<String, Object>>[];
    for (final shape in MaterialExpressiveShape.values) {
      final rawPath = shape.polygon.toPath();
      final rawBoundsCenter = rawPath.getBounds().center;
      final areaCentroid = SafeInteriorOutline(shape.polygon.cubics)
          .areaCentroid;
      final optical = findOpticalCenter(
        cubics: shape.polygon.cubics,
        path: rawPath,
        areaCentroid: areaCentroid,
      );
      final generatedCenter = materialShapePreferredCenterData[shape]!;
      expect(
        generatedCenter,
        offsetMoreOrLessEquals(optical.center, epsilon: 1e-12),
        reason: '${shape.name} generated center',
      );
      // Guard the wiring that the visual comparison depends on: panel five
      // must use the new center, not accidentally duplicate another panel.
      if (shape == MaterialExpressiveShape.heart) {
        expect(optical.axisCount, 1);
        expect(optical.center.dy, closeTo(0.5444, 0.001));
      } else if (shape == MaterialExpressiveShape.ghostish) {
        expect(optical.axisCount, 1);
        expect(optical.center.dy, closeTo(0.4318, 0.001));
      } else if (shape == MaterialExpressiveShape.triangle) {
        expect(optical.axisCount, greaterThan(1));
        expect(optical.center, offsetMoreOrLessEquals(areaCentroid));
      }
      final centers = [
        rawBoundsCenter,
        areaCentroid,
        _perimeterCentroid(shape),
        optical.hullCentroid,
        generatedCenter,
      ];
      expect(rawPath.contains(optical.center), isTrue, reason: shape.name);
      metadata.add({
        'shape': shape.name,
        'centers': [
          for (final center in centers) [center.dx, center.dy],
        ],
        'axisCount': optical.axisCount,
        'method': optical.method.name,
      });
      for (var panel = 0; panel < centers.length; panel++) {
        final rect = Rect.fromLTWH(
          panel * _panelWidth + (shape.index % 7) * _cellSize + 10,
          (shape.index ~/ 7) * _cellSize + 10,
          _shapeSize,
          _shapeSize,
        );
        canvas.drawPath(
          ExpressiveShapeGeometry(to: shape).border().getOuterPath(rect),
          fill,
        );
        _drawMarker(canvas, _mapCenter(rect, centers[panel], rawBoundsCenter));
      }
    }
    const metadataPath = String.fromEnvironment('CENTER_DIAGNOSTIC_METADATA');
    if (metadataPath.isNotEmpty) {
      File(
        metadataPath,
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(metadata));
    }
    for (final x in [
      _panelWidth,
      _panelWidth * 2,
      _panelWidth * 3,
      _panelWidth * 4,
    ]) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, 500),
        Paint()..color = const Color(0xffdddddd),
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(3500, 500);
    try {
      await expectLater(
        image,
        matchesGoldenFile('goldens/expressive_shape_center_definitions.png'),
      );
    } finally {
      image.dispose();
      picture.dispose();
    }
  });
}
