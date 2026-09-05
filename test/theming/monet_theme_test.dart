import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/theming/monet_theme.dart';
import 'package:libmonet/theming/monet_theme_data.dart';

MonetThemeData _theme(Color primary, {double scale = 1}) =>
    MonetThemeData.fromColors(
      brightness: Brightness.light,
      backgroundTone: 94,
      primary: primary,
      secondary: Colors.teal,
      tertiary: Colors.orange,
      contrast: 0.5,
      scale: scale,
    );

class _ShapeProbe extends StatelessWidget {
  const _ShapeProbe(this.onBuild);

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    MonetTheme.shapesOf(context);
    return const SizedBox.shrink();
  }
}

void main() {
  testWidgets('propagates the Monet theme to Cupertino descendants', (
    tester,
  ) async {
    final rootTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
    );
    final monetTheme = MonetThemeData.fromColors(
      brightness: Brightness.light,
      backgroundTone: 94,
      primary: Colors.green,
      secondary: Colors.teal,
      tertiary: Colors.orange,
      contrast: 0.5,
    );
    ThemeData? inheritedMaterialTheme;
    CupertinoThemeData? inheritedCupertinoTheme;

    await tester.pumpWidget(
      MaterialApp(
        theme: rootTheme,
        home: MonetTheme(
          monetThemeData: monetTheme,
          child: Builder(
            builder: (context) {
              inheritedMaterialTheme = Theme.of(context);
              inheritedCupertinoTheme = CupertinoTheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(
      inheritedMaterialTheme!.colorScheme.primary,
      isNot(rootTheme.colorScheme.primary),
      reason: 'the test must put MonetTheme below a differently colored app',
    );
    expect(
      inheritedCupertinoTheme!.primaryColor,
      inheritedMaterialTheme!.colorScheme.primary,
    );
    expect(
      inheritedCupertinoTheme!.primaryContrastingColor,
      inheritedMaterialTheme!.colorScheme.onPrimary,
    );
    expect(
      inheritedCupertinoTheme!.selectionHandleColor,
      inheritedMaterialTheme!.textSelectionTheme.selectionHandleColor,
    );
  });

  testWidgets('shape lookup ignores palette-only changes', (tester) async {
    var data = _theme(Colors.blue);
    var builds = 0;
    late StateSetter update;
    final probe = _ShapeProbe(() => builds++);

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MonetTheme(monetThemeData: data, child: probe);
          },
        ),
      ),
    );
    expect(builds, 1);

    update(() => data = _theme(Colors.red));
    await tester.pump();
    expect(builds, 1);

    update(() => data = _theme(Colors.red, scale: 4));
    await tester.pump();
    expect(builds, 2);
  });
}
