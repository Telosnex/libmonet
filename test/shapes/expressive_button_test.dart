import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/shapes/expressive_button.dart';
import 'package:libmonet/shapes/src/material_shape_safe_area_data.dart';

import '../../tool/src/safe_interior.dart';

void main() {
  test('shipped Dart rectangles are certified for the current catalog', () {
    for (final shape in MaterialExpressiveShape.values) {
      final outline = SafeInteriorOutline(shape.polygon.cubics);
      expect(materialShapeSafeAreaData[shape], hasLength(9));
      for (final rect in materialShapeSafeAreaData[shape]!) {
        expect(outline.contains(rect), isTrue, reason: shape.name);
      }
    }
  });

  test('all catalog morph pairs retain one fixed optical center', () {
    for (final from in MaterialExpressiveShape.values) {
      for (final to in MaterialExpressiveShape.values) {
        final geometry = ExpressiveShapeGeometry(from: from, to: to);
        expect(
          geometry.safeRects,
          isNotEmpty,
          reason: '${from.name} -> ${to.name}',
        );
        for (final rect in geometry.safeRects) {
          expect(
            rect.center,
            offsetMoreOrLessEquals(geometry.preferredCenter, epsilon: 1e-12),
            reason: '${from.name} -> ${to.name}',
          );
        }
      }
    }
  });

  testWidgets('content stays at every catalog optical center', (tester) async {
    for (final shape in MaterialExpressiveShape.values) {
      final geometry = ExpressiveShapeGeometry(to: shape);
      final childKey = ValueKey(shape);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox.square(
              dimension: 52,
              child: ExpressiveShapeContent(
                geometry: geometry,
                padding: EdgeInsets.zero,
                clearance: 1,
                child: SizedBox.square(key: childKey, dimension: 36),
              ),
            ),
          ),
        ),
      );
      final content = tester.renderObject<RenderBox>(
        find.byType(ExpressiveShapeContent),
      );
      final child = tester.renderObject<RenderBox>(find.byKey(childKey));
      final paintedCenter = MatrixUtils.transformPoint(
        child.getTransformTo(content),
        child.size.center(Offset.zero),
      );
      expect(
        paintedCenter,
        offsetMoreOrLessEquals(
          Offset(
            geometry.preferredCenter.dx * content.size.width,
            geometry.preferredCenter.dy * content.size.height,
          ),
          epsilon: 0.001,
        ),
        reason: shape.name,
      );
    }
  });

  for (final stretch in [false, true]) {
    testWidgets(
      'endpoint fit, shared surface coordinates and stable morph layout stretch=$stretch',
      (tester) async {
        final geometry = ExpressiveShapeGeometry(
          from: MaterialExpressiveShape.heart,
          to: MaterialExpressiveShape.boom,
        );
        Size? initial;
        for (final progress in [0.0, 0.5, 1.0]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: ExpressiveButton(
                    geometry: geometry,
                    progress: progress,
                    stretch: stretch,
                    constraints: const BoxConstraints(
                      maxWidth: 240,
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    padding: const EdgeInsetsDirectional.only(
                      start: 12,
                      end: 4,
                      top: 8,
                      bottom: 3,
                    ),
                    onPressed: () {},
                    child: const Text('Save my changes and continue'),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final content = tester.renderObject<RenderBox>(
            find.byType(ExpressiveShapeContent),
          );
          final materialFinder = find.descendant(
            of: find.byType(ElevatedButton),
            matching: find.byType(Material),
          );
          final material = tester.renderObject<RenderBox>(materialFinder);
          expect(content.size, material.size);
          expect(
            content.localToGlobal(Offset.zero),
            material.localToGlobal(Offset.zero),
          );
          initial ??= content.size;
          expect(content.size, initial);
          if (progress == .5) {
            continue; // No intermediate containment requirement.
          }
          final text = tester.renderObject<RenderBox>(
            find.text('Save my changes and continue'),
          );
          final rect = MatrixUtils.transformRect(
            text.getTransformTo(content),
            Offset.zero & text.size,
          );
          final path = geometry
              .border(progress: progress, stretch: stretch)
              .getOuterPath(Offset.zero & content.size);
          for (var y = 0; y <= 16; y++) {
            for (var x = 0; x <= 16; x++) {
              expect(
                path.contains(
                  Offset(
                    rect.left + rect.width * x / 16,
                    rect.top + rect.height * y / 16,
                  ),
                ),
                isTrue,
              );
            }
          }
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets(
    'tight parent, RTL, large text and scaleDown stay within endpoint',
    (tester) async {
      final geometry = ExpressiveShapeGeometry(
        to: MaterialExpressiveShape.heart,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Center(
                child: SizedBox(
                  width: 100,
                  height: 80,
                  child: ExpressiveButton(
                    geometry: geometry,
                    onPressed: () {},
                    padding: const EdgeInsetsDirectional.only(start: 8, end: 2),
                    child: const Text('A longer accessible button label'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final content = tester.renderObject<RenderBox>(
        find.byType(ExpressiveShapeContent),
      );
      expect(content.size, const Size(100, 80));
      final text = tester.renderObject<RenderBox>(
        find.text('A longer accessible button label'),
      );
      final rect = MatrixUtils.transformRect(
        text.getTransformTo(content),
        Offset.zero & text.size,
      );
      final path = geometry.border().getOuterPath(Offset.zero & content.size);
      for (final point in [
        rect.topLeft,
        rect.topRight,
        rect.bottomLeft,
        rect.bottomRight,
        rect.center,
      ]) {
        expect(path.contains(point), isTrue);
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final bounds in const [
    BoxConstraints(maxWidth: 280),
    BoxConstraints(maxHeight: 280),
    // Mandatory minimums still win, even when a square cannot satisfy them.
    BoxConstraints(maxWidth: 280, minHeight: 400),
  ]) {
    testWidgets('unstretched fitting avoids unused space under $bounds', (
      tester,
    ) async {
      final geometry = ExpressiveShapeGeometry(
        from: MaterialExpressiveShape.circle,
        to: MaterialExpressiveShape.cookie7Sided,
      );
      final expected = bounds.constrain(const Size.square(280));
      for (final progress in [0.0, 1.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: UnconstrainedBox(
              child: ExpressiveButton(
                geometry: geometry,
                progress: progress,
                constraints: bounds,
                onPressed: () {},
                child: const Icon(Icons.favorite, size: 1000),
              ),
            ),
          ),
        );
        final content = tester.renderObject<RenderBox>(
          find.byType(ExpressiveShapeContent),
        );
        expect(content.size, expected);
        expect(content.getDryLayout(bounds), expected);
        final material = find.descendant(
          of: find.byType(ElevatedButton),
          matching: find.byType(Material),
        );
        expect(tester.getSize(material), expected);
        final icon = tester.renderObject<RenderBox>(find.byType(Icon));
        final rect = MatrixUtils.transformRect(
          icon.getTransformTo(content),
          Offset.zero & icon.size,
        );
        final path = geometry
            .border(progress: progress)
            .getOuterPath(Offset.zero & content.size);
        for (final point in [
          rect.topLeft,
          rect.topRight,
          rect.bottomLeft,
          rect.bottomRight,
          rect.center,
        ]) {
          expect(path.contains(point), isTrue);
        }
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('variants preserve activation, focus and disabled semantics', (
    tester,
  ) async {
    final geometry = ExpressiveShapeGeometry(
      to: MaterialExpressiveShape.cookie7Sided,
    );
    var presses = 0;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final semantics = tester.ensureSemantics();

    for (final variant in ExpressiveButtonVariant.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: ExpressiveButton(
              geometry: geometry,
              variant: variant,
              focusNode: focus,
              onPressed: () => presses++,
              child: const Text('Save'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Save'));
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
    }
    expect(presses, 6);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ExpressiveButton(
            geometry: geometry,
            onPressed: null,
            child: const Text('Disabled'),
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(ElevatedButton)),
      matchesSemantics(
        label: 'Disabled',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    semantics.dispose();
  });

  testWidgets('custom surface, composed content and tight theme sizes', (
    tester,
  ) async {
    final geometry = ExpressiveShapeGeometry(to: MaterialExpressiveShape.arrow);
    const child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.save, size: 24),
        SizedBox(width: 8),
        Flexible(child: Text('Save and continue')),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ButtonStyle(
              fixedSize: const WidgetStatePropertyAll(Size(90, 40)),
              padding: const WidgetStatePropertyAll(EdgeInsets.all(30)),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        home: Center(
          child: ExpressiveButton(
            geometry: geometry,
            constraints: const BoxConstraints.tightFor(width: 180, height: 140),
            onPressed: () {},
            child: child,
          ),
        ),
      ),
    );
    final contentFinder = find.byType(ExpressiveShapeContent);
    expect(tester.getSize(contentFinder), const Size(180, 140));
    final material = find.descendant(
      of: find.byType(ElevatedButton),
      matching: find.byType(Material),
    );
    expect(tester.getSize(material), tester.getSize(contentFinder));
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: Material(
            shape: geometry.border(),
            child: ExpressiveShapeContent(geometry: geometry, child: child),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(Material)),
      tester.getSize(contentFinder),
    );
    expect(tester.takeException(), isNull);
  });

  for (final intrinsic in [Axis.horizontal, Axis.vertical]) {
    testWidgets('lower-level content supports $intrinsic intrinsic sizing', (
      tester,
    ) async {
      final previous = debugCheckIntrinsicSizes;
      debugCheckIntrinsicSizes = true;
      try {
        final geometry = ExpressiveShapeGeometry(
          to: MaterialExpressiveShape.cookie7Sided,
        );
        final content = ExpressiveShapeContent(
          geometry: geometry,
          child: const Text('One-line action'),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: intrinsic == Axis.horizontal
                  ? IntrinsicWidth(child: content)
                  : IntrinsicHeight(
                      child: SizedBox(width: 180, child: content),
                    ),
            ),
          ),
        );

        final size = tester.getSize(find.byType(ExpressiveShapeContent));
        expect(size.width, greaterThan(0));
        expect(size.height, greaterThan(0));
        expect(size.width.isFinite, isTrue);
        expect(size.height.isFinite, isTrue);
        expect(tester.takeException(), isNull);
      } finally {
        debugCheckIntrinsicSizes = previous;
      }
    });
  }

  testWidgets('error policy explicitly rejects insufficient space', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox.square(
            dimension: 60,
            child: ExpressiveButton(
              geometry: ExpressiveShapeGeometry(
                to: MaterialExpressiveShape.boom,
              ),
              overflow: ExpressiveContentOverflow.error,
              onPressed: () {},
              child: const Icon(Icons.add, size: 100),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isA<FlutterError>());
  });
}
