import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/theming/monet_theme_data.dart';

Typography _typography(ColorScheme colorScheme) {
  return Typography.material2021(colorScheme: colorScheme);
}

MonetThemeData _theme({
  Color primary = Colors.blue,
  Typography Function(ColorScheme)? typography,
}) {
  return MonetThemeData.fromColors(
    brightness: Brightness.light,
    backgroundTone: 93,
    primary: primary,
    secondary: Colors.teal,
    tertiary: Colors.orange,
    contrast: 0.5,
    scale: 1.0,
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
}
