import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/shapes/expressive_button.dart';

void main() {
  test('settled and reversed endpoints keep the catalog source', () {
    final g = ExpressiveShapeGeometry(
      from: MaterialExpressiveShape.circle,
      to: MaterialExpressiveShape.heart,
    );
    expect(
      g.retarget(MaterialExpressiveShape.fan, progress: 1).from,
      MaterialExpressiveShape.heart,
    );
    expect(
      g.retarget(MaterialExpressiveShape.fan, progress: 0).from,
      MaterialExpressiveShape.circle,
    );
    final static = ExpressiveShapeGeometry(to: MaterialExpressiveShape.heart);
    expect(
      static.retarget(MaterialExpressiveShape.fan, progress: .4).from,
      MaterialExpressiveShape.heart,
    );
    for (final t in [-1.0, 2.0, double.nan, double.infinity]) {
      expect(
        () => g.retarget(MaterialExpressiveShape.fan, progress: t),
        throwsArgumentError,
      );
    }
  });

  test(
    'repeated interruptions preserve outlines and destination safe areas',
    () {
      var geometry = ExpressiveShapeGeometry(
        from: MaterialExpressiveShape.circle,
        to: MaterialExpressiveShape.heart,
      );
      for (final target in MaterialExpressiveShape.values) {
        final next = geometry.retarget(target, progress: .37);
        for (final stretch in [false, true]) {
          const rect = Rect.fromLTWH(19, 27, 144, 110);
          final before = geometry
              .border(progress: .37, stretch: stretch)
              .getOuterPath(rect);
          final after = next
              .border(progress: 0, stretch: stretch)
              .getOuterPath(rect);
          final a = before.computeMetrics().single;
          final b = after.computeMetrics().single;
          // Arc-length estimates vary after splitting. Check subpixel agreement
          // along the outline, not exact equality of approximate lengths.
          for (var i = 0; i < 50; i++) {
            expect(
              (a.getTangentForOffset(a.length * i / 50)!.position -
                      b.getTangentForOffset(b.length * i / 50)!.position)
                  .distance,
              lessThan(.5),
              reason: target.name,
            );
          }
          final end = next.border(progress: 1, stretch: stretch);
          expect(end.alignmentCorrection, Offset.zero);
          final path = end.getOuterPath(rect);
          expect(next.safeRects, isNotEmpty);
          for (final safe in next.safeRects) {
            for (var y = 0; y <= 4; y++) {
              for (var x = 0; x <= 4; x++) {
                final sx = stretch ? rect.width : rect.shortestSide;
                final sy = stretch ? rect.height : rect.shortestSide;
                expect(
                  path.contains(
                    rect.center +
                        Offset(
                          (safe.left + safe.width * x / 4 - .5) * sx,
                          (safe.top + safe.height * y / 4 - .5) * sy,
                        ),
                  ),
                  isTrue,
                );
              }
            }
          }
        }
        geometry = next;
      }
    },
  );
}
