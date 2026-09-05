import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/theming/animated_monet_theme.dart';
import 'package:libmonet/theming/monet_theme_data.dart';
import 'package:libmonet/theming/monet_shape_theme.dart';

Typography _typography(ColorScheme colorScheme) {
  return Typography.material2021(colorScheme: colorScheme);
}

MonetThemeData _theme({
  Color primary = Colors.blue,
  Typography Function(ColorScheme)? typography,
  double scale = 1,
  MonetShapeTheme shapeTheme = const MonetShapeTheme(),
}) {
  return MonetThemeData.fromColors(
    brightness: Brightness.light,
    backgroundTone: 93,
    primary: primary,
    secondary: Colors.teal,
    tertiary: Colors.orange,
    contrast: 0.5,
    scale: scale,
    shapeTheme: shapeTheme,
    typography: typography,
  );
}

void main() {
  test('fromColors equality is semantic and hash-compatible', () {
    final a = _theme();
    final b = _theme();

    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
  });

  test('stable typography callback participates in equality', () {
    final a = _theme(typography: _typography);
    final b = _theme(typography: _typography);

    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
  });

  test('fresh typography closures are intentionally distinct', () {
    final a = _theme(
      typography: (colorScheme) {
        return Typography.material2021(colorScheme: colorScheme);
      },
    );
    final b = _theme(
      typography: (colorScheme) {
        return Typography.material2021(colorScheme: colorScheme);
      },
    );

    expect(a, isNot(equals(b)));
  });

  test('shape configuration participates in equality and copyWith', () {
    const shapes = MonetShapeTheme(
      borderRadius: BorderRadius.all(Radius.circular(18)),
    );
    final configured = _theme(shapeTheme: shapes);
    final other = _theme();

    expect(configured, isNot(other));
    expect(configured.copyWith(primary: other.primary).shapeTheme, shapes);
  });

  test('interpolated themes preserve shape policy until the endpoint', () {
    const beginShapes = MonetShapeTheme(
      borderRadius: BorderRadius.all(Radius.circular(4)),
    );
    const endShapes = MonetShapeTheme(
      borderRadius: BorderRadius.all(Radius.circular(20)),
    );
    final begin = _theme(shapeTheme: beginShapes);
    final end = _theme(shapeTheme: endShapes);

    expect(
      InterpolatedMonetThemeData(begin: begin, end: end, t: 0.5).shapeTheme,
      beginShapes,
    );
    expect(
      InterpolatedMonetThemeData(begin: begin, end: end, t: 1).shapeTheme,
      endShapes,
    );
  });

  testWidgets('ThemeData cache uses semantic theme keys', (tester) async {
    final a = _theme();
    final b = _theme();
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final first = a.createThemeData(capturedContext);
    final second = b.createThemeData(capturedContext);

    expect(a, equals(b));
    expect(identical(first, second), isTrue);
  });

  testWidgets('app bar height follows the linear component scale', (
    tester,
  ) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final theme = _theme(scale: 4).createThemeData(capturedContext);

    // Monet's component ruler is sqrt(scale), so 4x area scale is 2x length.
    expect(theme.appBarTheme.toolbarHeight, kToolbarHeight * 2);
  });

  testWidgets('Material buttons, cards, and inputs use resolved shapes', (
    tester,
  ) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final theme = _theme(
      scale: 4,
      shapeTheme: const MonetShapeTheme(
        borderRadius: BorderRadius.all(Radius.circular(9)),
      ),
    ).createThemeData(capturedContext);
    const expectedRadius = BorderRadius.all(Radius.circular(18));

    expect(
      (theme.cardTheme.shape! as RoundedRectangleBorder).borderRadius,
      expectedRadius,
    );
    expect(
      (theme.elevatedButtonTheme.style!.shape!.resolve({})!
              as RoundedRectangleBorder)
          .borderRadius,
      expectedRadius,
    );
    expect(
      (theme.inputDecorationTheme.border! as OutlineInputBorder).borderRadius,
      expectedRadius,
    );
  });

  testWidgets('ThemeData cache separates directional input geometry', (
    tester,
  ) async {
    final data = _theme(
      shapeTheme: const MonetShapeTheme(
        borderRadius: BorderRadiusDirectional.only(
          topStart: Radius.circular(6),
        ),
      ),
    );
    ThemeData? ltr;
    ThemeData? rtl;

    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: Builder(
                builder: (context) {
                  ltr = data.createThemeData(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Builder(
                builder: (context) {
                  rtl = data.createThemeData(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );

    expect(identical(ltr, rtl), isFalse);
    expect(
      (ltr!.inputDecorationTheme.border! as OutlineInputBorder).borderRadius,
      const BorderRadius.only(topLeft: Radius.circular(6)),
    );
    expect(
      (rtl!.inputDecorationTheme.border! as OutlineInputBorder).borderRadius,
      const BorderRadius.only(topRight: Radius.circular(6)),
    );
  });
}
