import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/theming/monet_clip.dart';
import 'package:libmonet/theming/monet_shape_theme.dart';
import 'package:libmonet/theming/monet_theme.dart';
import 'package:libmonet/theming/monet_theme_data.dart';

void main() {
  testWidgets('derives its clip from resolved Monet geometry', (tester) async {
    final data = MonetThemeData.fromColor(
      backgroundTone: 93,
      brightness: Brightness.light,
      color: Colors.blue,
      scale: 4,
      shapeTheme: const MonetShapeTheme(
        borderRadius: BorderRadius.all(Radius.circular(9)),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MonetTheme(
          monetThemeData: data,
          child: const MonetClip(child: SizedBox.square(dimension: 20)),
        ),
      ),
    );

    final clip = tester.widget<ClipPath>(find.byType(ClipPath));
    final clipper = clip.clipper! as ShapeBorderClipper;
    final shape = clipper.shape as RoundedRectangleBorder;
    expect(shape.borderRadius, const BorderRadius.all(Radius.circular(18)));
  });

  testWidgets('accepts an explicit shape without a Monet theme', (
    tester,
  ) async {
    const shape = StadiumBorder();
    await tester.pumpWidget(
      const MaterialApp(
        home: MonetClip(shape: shape, child: SizedBox.square(dimension: 20)),
      ),
    );

    final clip = tester.widget<ClipPath>(find.byType(ClipPath));
    expect((clip.clipper! as ShapeBorderClipper).shape, shape);
  });
}
