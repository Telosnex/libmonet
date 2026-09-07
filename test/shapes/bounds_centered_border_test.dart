import 'dart:ui' as ui;

import 'package:androidx_graphics_shapes/material_shapes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/shapes/expressive_button.dart';

void main() {
  test('catalog and morph frames use the Compose scale-then-center transform', () {
    for (final shape in MaterialExpressiveShape.values) {
      for (final from in [null, MaterialExpressiveShape.fan]) {
        final geometry = ExpressiveShapeGeometry(from: from, to: shape);
        for (final stretch in [false, true]) {
          for (final t in [0.0, 0.25, 0.5, 0.75, 1.0]) {
            const rect = Rect.fromLTWH(31, 47, 240, 120);
            final border = geometry.border(progress: t, stretch: stretch);
            // Independent reference: Compose scales the unit path, obtains
            // its bounds, and translates the bounds' center to the box center.
            final source = border.source;
            final raw = source is MorphBorder
                ? source.path
                : (source as RoundedPolygonBorder).path;
            final matrix = Matrix4.diagonal3Values(
              240 * (stretch ? 1 : .5),
              120,
              1,
            );
            final scaled = raw.transform(matrix.storage);
            final expected = scaled.shift(
              rect.center - scaled.getBounds().center,
            );
            final actual = border.getOuterPath(rect);
            expect(
              (actual.getBounds().center - rect.center).distance,
              lessThan(0.0001),
              reason: '${shape.name} $t',
            );
            final a = actual.computeMetrics().single;
            final e = expected.computeMetrics().single;
            for (var i = 0; i < 10; i++) {
              expect(
                (a.getTangentForOffset(a.length * i / 10)!.position -
                        e.getTangentForOffset(e.length * i / 10)!.position)
                    .distance,
                lessThan(0.001),
              );
            }
            if (t != 0 && t != 1) continue;
            for (final safe in geometry.safeRects) {
              expect(
                (safe.center - const Offset(.5, .5)).distance,
                lessThan(1e-10),
              );
              for (var y = 0; y <= 4; y++) {
                for (var x = 0; x <= 4; x++) {
                  final point = Offset(
                    safe.left + safe.width * x / 4,
                    safe.top + safe.height * y / 4,
                  );
                  final sx = stretch ? rect.width : rect.shortestSide;
                  final sy = stretch ? rect.height : rect.shortestSide;
                  expect(
                    actual.contains(
                      rect.center +
                          Offset((point.dx - .5) * sx, (point.dy - .5) * sy),
                    ),
                    isTrue,
                    reason: '${shape.name} from=$from t=$t',
                  );
                }
              }
            }
          }
        }
      }
    }
  });

  test('copy, scale, interpolation and degenerate bounds retain centering', () {
    final border = ExpressiveShapeGeometry(to: MaterialExpressiveShape.fan)
        .border();
    final copy = border.copyWith(
      side: const BorderSide(width: 2, color: Colors.red),
    );
    const rect = Rect.fromLTWH(20, 30, 120, 80);
    expect(
      copy.getOuterPath(rect).getBounds(),
      border.getOuterPath(rect).getBounds(),
    );
    expect(copy.scale(2).side.width, 4);
    expect(copy.copyWith(), copy);
    expect(copy.copyWith().hashCode, copy.hashCode);
    final end = ExpressiveShapeGeometry(to: MaterialExpressiveShape.arrow)
        .border();
    final middle = ShapeBorder.lerp(copy, end, .5)!;
    expect(middle, isA<BoundsCenteredBorder>());
    expect(
      (middle.getOuterPath(rect).getBounds().center - rect.center).distance,
      lessThan(.001),
    );
    for (final bounds in [
      Rect.zero,
      const Rect.fromLTWH(0, 0, double.infinity, 10),
    ]) {
      expect(copy.getOuterPath(bounds).computeMetrics(), isEmpty);
      expect(copy.getInnerPath(bounds).computeMetrics(), isEmpty);
    }
  });

  testWidgets('Fan icon and text align to painted bounds at both endpoints', (
    tester,
  ) async {
    for (final from in [null, MaterialExpressiveShape.circle]) {
      final geometry = ExpressiveShapeGeometry(
        from: from,
        to: MaterialExpressiveShape.fan,
      );
      for (final stretch in [false, true]) {
        for (final label in [false, true]) {
          Size? initial;
          for (final progress in [0.0, 1.0]) {
            const contentKey = ValueKey('foreground');
            await tester.pumpWidget(
              MaterialApp(
                home: Center(
                  child: ExpressiveButton(
                    geometry: geometry,
                    progress: progress,
                    stretch: stretch,
                    constraints: const BoxConstraints(maxWidth: 240),
                    padding: const EdgeInsets.all(8),
                    onPressed: () {},
                    child: label
                        ? const Text('Save changes', key: contentKey)
                        : const Icon(Icons.add, size: 48, key: contentKey),
                  ),
                ),
              ),
            );
            final surface = tester.renderObject<RenderBox>(
              find.byType(ExpressiveShapeContent),
            );
            final foreground = tester.renderObject<RenderBox>(
              find.byKey(contentKey),
            );
            final contentRect = MatrixUtils.transformRect(
              foreground.getTransformTo(surface),
              Offset.zero & foreground.size,
            );
            final bounds = geometry
                .border(progress: progress, stretch: stretch)
                .getOuterPath(Offset.zero & surface.size)
                .getBounds();
            expect(
              (contentRect.center - bounds.center).distance,
              lessThan(.001),
            );
            initial ??= surface.size;
            expect(surface.size, initial);
            expect(tester.takeException(), isNull);
          }
        }
      }
    }
  });

  test('Fan before-after bounds-centering golden', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..drawColor(Colors.white, BlendMode.src);
    final raw = RoundedPolygonBorder(polygon: MaterialShapes.fan);
    for (var row = 0; row < 2; row++) {
      for (var column = 0; column < 2; column++) {
        final rect = Rect.fromLTWH(20 + column * 220, 20 + row * 180, 180, 140);
        final source = raw.copyWith(squash: row.toDouble());
        final border = column == 0 ? source : BoundsCenteredBorder(source);
        border.paintInterior(
          canvas,
          rect,
          Paint()..color = const Color(0xff6750a4),
        );
        border
            .copyWith(side: const BorderSide(color: Colors.black, width: 2))
            .paint(canvas, rect);
        canvas.drawRect(
          rect,
          Paint()
            ..color = Colors.grey
            ..style = PaintingStyle.stroke,
        );
        final center = rect.center;
        canvas.drawLine(
          center - const Offset(10, 0),
          center + const Offset(10, 0),
          Paint()
            ..color = Colors.amber
            ..strokeWidth = 3,
        );
        canvas.drawLine(
          center - const Offset(0, 10),
          center + const Offset(0, 10),
          Paint()
            ..color = Colors.amber
            ..strokeWidth = 3,
        );
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(440, 360);
    try {
      await expectLater(
        image,
        matchesGoldenFile('goldens/fan_bounds_centering.png'),
      );
    } finally {
      image.dispose();
      picture.dispose();
    }
  });
}
