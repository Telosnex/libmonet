import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/shapes/material_expressive_border.dart';
import 'package:libmonet/theming/monet_clip.dart';

void main() {
  test('catalog has all 35 distinct named silhouettes', () {
    expect(MaterialExpressiveShape.values, hasLength(35));
    expect(
      MaterialExpressiveShape.values.map((s) => s.label).toSet(),
      hasLength(35),
    );
  });

  for (final shape in MaterialExpressiveShape.values) {
    test('${shape.label}: closed, finite, centered and contained', () {
      final border = MaterialExpressiveBorder(shape: shape);
      const rect = Rect.fromLTWH(31, 47, 240, 120);
      final path = border.getOuterPath(rect);
      final metrics = path.computeMetrics().toList();
      expect(metrics, hasLength(1));
      expect(metrics.single.isClosed, isTrue);
      expect(metrics.single.length, greaterThan(100));
      final bounds = path.getBounds();
      expect(bounds.isFinite, isTrue);
      expect((bounds.center - rect.center).distance, lessThan(0.001));
      expect(bounds.width, lessThanOrEqualTo(120.01));
      expect(bounds.height, lessThanOrEqualTo(120.01));
      expect(path.contains(rect.center), isTrue);
      for (var i = 0; i < 100; i++) {
        final point = metrics.single
            .getTangentForOffset(metrics.single.length * i / 100)!
            .position;
        expect(rect.inflate(0.001).contains(point), isTrue);
      }
      // The cached normalized path must not be exposed to caller mutations.
      path.reset();
      expect(border.getOuterPath(rect).getBounds(), bounds);
      expect(
        border.getOuterPath(rect, textDirection: TextDirection.rtl).getBounds(),
        bounds,
      );
    });
  }

  test('contain preserves proportions; stretch scales axes independently', () {
    const shape = MaterialExpressiveBorder(
      shape: MaterialExpressiveShape.circle,
    );
    const rect = Rect.fromLTWH(10, 20, 200, 100);
    final unit = shape
        .getOuterPath(const Rect.fromLTWH(0, 0, 1, 1))
        .getBounds();
    final contained = shape.getOuterPath(rect).getBounds();
    final stretched = shape
        .copyWith(stretch: true)
        .getOuterPath(rect)
        .getBounds();
    // Path.getBounds includes cubic control points, not just curve extrema.
    expect(contained.width, closeTo(unit.width * 100, 0.01));
    expect(contained.height, closeTo(unit.height * 100, 0.01));
    expect(stretched.width, closeTo(contained.width * 2, 0.01));
    expect(stretched.height, closeTo(contained.height, 0.01));
    expect((stretched.center - rect.center).distance, lessThan(0.001));
  });

  test('empty and non-finite rectangles yield empty paths', () {
    const border = MaterialExpressiveBorder(
      shape: MaterialExpressiveShape.flower,
    );
    for (final rect in [
      Rect.zero,
      const Rect.fromLTWH(0, 0, -1, 20),
      const Rect.fromLTWH(0, 0, double.infinity, 20),
      const Rect.fromLTWH(double.nan, 0, 20, 20),
    ]) {
      expect(border.getOuterPath(rect).computeMetrics(), isEmpty);
    }
    expect(
      border
          .copyWith(side: const BorderSide(width: 100))
          .getInnerPath(const Rect.fromLTWH(0, 0, 20, 20))
          .computeMetrics(),
      isEmpty,
    );
  });

  test('side, copy, scale, equality and stroke alignment', () {
    const border = MaterialExpressiveBorder(
      shape: MaterialExpressiveShape.clover4Leaf,
      stretch: true,
      side: BorderSide(color: Colors.red, width: 4),
    );
    expect(border.copyWith(), border);
    expect(border.copyWith().hashCode, border.hashCode);
    expect(border.copyWith(stretch: false), isNot(border));
    expect(
      border.copyWith(shape: MaterialExpressiveShape.heart),
      isNot(border),
    );
    final scaled = border.scale(2);
    expect(scaled.side.width, 8);
    expect(scaled.shape, border.shape);
    expect(scaled.stretch, isTrue);
    expect(border.dimensions, const EdgeInsets.all(4));
    const rect = Rect.fromLTWH(0, 0, 100, 100);
    expect(
      border.getInnerPath(rect).getBounds().width,
      lessThan(border.getOuterPath(rect).getBounds().width),
    );
    final outside = border.copyWith(
      side: border.side.copyWith(strokeAlign: BorderSide.strokeAlignOutside),
    );
    expect(outside.dimensions, EdgeInsets.zero);
    expect(
      outside.getInnerPath(rect).getBounds(),
      outside.getOuterPath(rect).getBounds(),
    );
  });

  test(
    'interpolation preserves endpoints and switches motifs, without morphing',
    () {
      const a = MaterialExpressiveBorder(shape: MaterialExpressiveShape.circle);
      const b = MaterialExpressiveBorder(
        shape: MaterialExpressiveShape.flower,
        stretch: true,
        side: BorderSide(width: 4, color: Colors.red),
      );
      expect(ShapeBorder.lerp(a, b, 0), a);
      expect(ShapeBorder.lerp(a, b, 1), b);
      final before = ShapeBorder.lerp(a, b, 0.25)! as MaterialExpressiveBorder;
      final after = ShapeBorder.lerp(a, b, 0.75)! as MaterialExpressiveBorder;
      expect(before.shape, a.shape);
      expect(before.stretch, isFalse);
      expect(after.shape, b.shape);
      expect(after.stretch, isTrue);
      expect(after.side, BorderSide.lerp(a.side, b.side, 0.75));
    },
  );

  test('all shapes paint solid, hairline, absent and oversized borders', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (final shape in MaterialExpressiveShape.values) {
      for (final side in [
        BorderSide.none,
        const BorderSide(width: 0),
        const BorderSide(width: 3),
        const BorderSide(width: 300),
      ]) {
        MaterialExpressiveBorder(
          shape: shape,
          side: side,
        ).paint(canvas, const Rect.fromLTWH(0, 0, 100, 100));
      }
    }
    recorder.endRecording().dispose();
  });

  test('catalog silhouette golden', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(Colors.white, BlendMode.src);
    for (final shape in MaterialExpressiveShape.values) {
      final rect = Rect.fromLTWH(
        (shape.index % 7) * 100 + 10,
        (shape.index ~/ 7) * 100 + 10,
        80,
        80,
      );
      canvas.drawPath(
        MaterialExpressiveBorder(shape: shape).getOuterPath(rect),
        Paint()..color = const Color(0xff6750a4),
      );
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(700, 500);
    try {
      await expectLater(
        image,
        matchesGoldenFile('goldens/material_expressive_catalog.png'),
      );
    } finally {
      image.dispose();
      picture.dispose();
    }
  });

  testWidgets('MonetClip and Material share the expressive border', (
    tester,
  ) async {
    const shape = MaterialExpressiveBorder(
      shape: MaterialExpressiveShape.cookie7Sided,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: MonetClip(
            shape: shape,
            child: SizedBox.square(
              dimension: 120,
              child: Material(shape: shape, elevation: 4, color: Colors.blue),
            ),
          ),
        ),
      ),
    );
    final clip = tester.widget<ClipPath>(find.byType(ClipPath));
    expect((clip.clipper! as ShapeBorderClipper).shape, shape);
    expect(tester.takeException(), isNull);
  });
}
