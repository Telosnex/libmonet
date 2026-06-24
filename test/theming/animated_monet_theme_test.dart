import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/theming/animated_monet_theme.dart';
import 'package:libmonet/theming/interpolation_style.dart';
import 'package:libmonet/theming/monet_theme.dart';
import 'package:libmonet/theming/monet_theme_data.dart';
import 'package:libmonet/theming/monet_paint_colors.dart';
import 'package:libmonet/theming/palette_lerped.dart';

class _PaintProbe extends StatefulWidget {
  const _PaintProbe({required this.onValue});

  final void Function(MonetThemeData value) onValue;

  @override
  State<_PaintProbe> createState() => _PaintProbeState();
}

class _PaintProbeState extends State<_PaintProbe> {
  MonetPaintColors? _colors;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = MonetPaintColorsScope.of(context);
    if (identical(_colors, next)) return;
    _colors?.removeListener(_notify);
    _colors = next..addListener(_notify);
    _notify();
  }

  void _notify() {
    final colors = _colors;
    if (colors != null) widget.onValue(colors.value);
  }

  @override
  void dispose() {
    _colors?.removeListener(_notify);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _Probe extends StatefulWidget {
  const _Probe({required this.onBuild});

  final void Function(BuildContext ctx) onBuild;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) {
    widget.onBuild(context);
    return const SizedBox.shrink();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MonetThemeData themeFrom(
    Color primary, {
    Brightness brightness = Brightness.dark,
  }) {
    return MonetThemeData.fromColors(
      brightness: brightness,
      backgroundTone: brightness == Brightness.dark ? 12 : 94,
      primary: primary,
      secondary: Colors.teal,
      tertiary: Colors.orange,
      contrast: 0.5,
    );
  }

  testWidgets('initial mount publishes target data without animation', (
    tester,
  ) async {
    final data = themeFrom(Colors.blue);
    Color? sampled;

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedMonetTheme(
          data: data,
          animateThemeData: false,
          duration: const Duration(milliseconds: 200),
          child: _Probe(
            onBuild: (ctx) {
              sampled = MonetTheme.of(ctx).primary.background;
            },
          ),
        ),
      ),
    );

    expect(sampled, equals(data.primary.background));
  });

  testWidgets('AnimatedMonetTheme animates Palette.background', (tester) async {
    final begin = themeFrom(Colors.blue);
    final end = themeFrom(Colors.purple);
    Color? sampled;

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedMonetTheme(
          data: begin,
          animateThemeData: false,
          duration: const Duration(milliseconds: 200),
          child: _Probe(
            onBuild: (ctx) {
              sampled = MonetTheme.of(ctx).primary.background;
            },
          ),
        ),
      ),
    );
    expect(sampled, equals(begin.primary.background));

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedMonetTheme(
          data: end,
          animateThemeData: false,
          duration: const Duration(milliseconds: 200),
          child: _Probe(
            onBuild: (ctx) {
              sampled = MonetTheme.of(ctx).primary.background;
            },
          ),
        ),
      ),
    );
    expect(sampled, equals(begin.primary.background));

    await tester.pump(const Duration(milliseconds: 100));
    final mid = sampled!;
    expect(mid, isNot(equals(begin.primary.background)));
    expect(mid, isNot(equals(end.primary.background)));

    await tester.pump(const Duration(milliseconds: 120));
    expect(sampled, equals(end.primary.background));
  });

  testWidgets(
    'AnimatedMonetTheme defaults to cartesian palette interpolation',
    (tester) async {
      final begin = themeFrom(Colors.red);
      final end = themeFrom(Colors.blue);
      Color? sampled;

      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedMonetTheme(
            data: begin,
            animateThemeData: false,
            duration: const Duration(milliseconds: 200),
            child: _Probe(
              onBuild: (ctx) {
                sampled = MonetTheme.of(ctx).primary.color;
              },
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedMonetTheme(
            data: end,
            animateThemeData: false,
            duration: const Duration(milliseconds: 200),
            child: _Probe(
              onBuild: (ctx) {
                sampled = MonetTheme.of(ctx).primary.color;
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final expected = PaletteLerped(
        a: begin.primary,
        b: end.primary,
        t: 0.5,
        interpolationStyle: InterpolationStyle.cartesian,
      ).color;
      expect(sampled, expected);
    },
  );

  testWidgets('AnimatedMonetTheme can use polar palette interpolation', (
    tester,
  ) async {
    final begin = themeFrom(Colors.red);
    final end = themeFrom(Colors.blue);
    Color? sampled;

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedMonetTheme(
          data: begin,
          animateThemeData: false,
          interpolationStyle: InterpolationStyle.polar,
          duration: const Duration(milliseconds: 200),
          child: _Probe(
            onBuild: (ctx) {
              sampled = MonetTheme.of(ctx).primary.color;
            },
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedMonetTheme(
          data: end,
          animateThemeData: false,
          interpolationStyle: InterpolationStyle.polar,
          duration: const Duration(milliseconds: 200),
          child: _Probe(
            onBuild: (ctx) {
              sampled = MonetTheme.of(ctx).primary.color;
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final expected = PaletteLerped(
      a: begin.primary,
      b: end.primary,
      t: 0.5,
      interpolationStyle: InterpolationStyle.polar,
    ).color;
    final cartesianMid = PaletteLerped(
      a: begin.primary,
      b: end.primary,
      t: 0.5,
      interpolationStyle: InterpolationStyle.cartesian,
    ).color;

    expect(sampled, expected);
    expect(sampled, isNot(cartesianMid));
  });

  testWidgets('ThemeData stable when animateThemeData=false', (tester) async {
    final begin = themeFrom(Colors.blue);
    final end = themeFrom(Colors.purple);

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedMonetTheme(
          data: begin,
          animateThemeData: false,
          duration: const Duration(milliseconds: 200),
          child: const SizedBox.shrink(),
        ),
      ),
    );
    final initialThemePrimary = Theme.of(
      tester.element(find.byType(SizedBox)),
    ).colorScheme.primary;

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedMonetTheme(
          data: end,
          animateThemeData: false,
          duration: const Duration(milliseconds: 200),
          child: const SizedBox.shrink(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    final midThemePrimary = Theme.of(
      tester.element(find.byType(SizedBox)),
    ).colorScheme.primary;
    expect(midThemePrimary, equals(initialThemePrimary));

    await tester.pump(const Duration(milliseconds: 120));
    final endThemePrimary = Theme.of(
      tester.element(find.byType(SizedBox)),
    ).colorScheme.primary;
    expect(
      endThemePrimary,
      equals(
        end
            .createThemeData(tester.element(find.byType(SizedBox)))
            .colorScheme
            .primary,
      ),
    );
  });

  testWidgets('retargets mid-animation continuously', (tester) async {
    final begin = themeFrom(Colors.blue);
    final firstEnd = themeFrom(Colors.purple);
    final secondEnd = themeFrom(Colors.green);
    Color? sampled;

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedMonetTheme(
          data: begin,
          animateThemeData: false,
          duration: const Duration(milliseconds: 200),
          child: _Probe(
            onBuild: (ctx) {
              sampled = MonetTheme.of(ctx).primary.background;
            },
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedMonetTheme(
          data: firstEnd,
          animateThemeData: false,
          duration: const Duration(milliseconds: 200),
          child: _Probe(
            onBuild: (ctx) {
              sampled = MonetTheme.of(ctx).primary.background;
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final beforeRetarget = sampled!;

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedMonetTheme(
          data: secondEnd,
          animateThemeData: false,
          duration: const Duration(milliseconds: 200),
          child: _Probe(
            onBuild: (ctx) {
              sampled = MonetTheme.of(ctx).primary.background;
            },
          ),
        ),
      ),
    );

    expect(sampled, equals(beforeRetarget));

    await tester.pump(const Duration(milliseconds: 100));
    final afterSome = sampled!;
    expect(afterSome, isNot(equals(beforeRetarget)));
    expect(afterSome, isNot(equals(secondEnd.primary.background)));

    await tester.pump(const Duration(milliseconds: 120));
    expect(sampled, equals(secondEnd.primary.background));
  });

  testWidgets('semantically equal data objects do not restart animation', (
    tester,
  ) async {
    final begin = themeFrom(Colors.blue);
    final end = themeFrom(Colors.purple);
    Color? sampled;

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedMonetTheme(
          data: begin,
          animateThemeData: false,
          duration: const Duration(milliseconds: 200),
          child: _Probe(
            onBuild: (ctx) {
              sampled = MonetTheme.of(ctx).primary.background;
            },
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedMonetTheme(
          data: end,
          animateThemeData: false,
          duration: const Duration(milliseconds: 200),
          child: _Probe(
            onBuild: (ctx) {
              sampled = MonetTheme.of(ctx).primary.background;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(sampled, equals(end.primary.background));

    // New object, same semantic theme values. This should not restart.
    final equalEnd = themeFrom(Colors.purple);
    expect(equalEnd, equals(end));

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedMonetTheme(
          data: equalEnd,
          animateThemeData: false,
          duration: const Duration(milliseconds: 200),
          child: _Probe(
            onBuild: (ctx) {
              sampled = MonetTheme.of(ctx).primary.background;
            },
          ),
        ),
      ),
    );

    expect(sampled, equals(end.primary.background));
    await tester.pump(const Duration(milliseconds: 100));
    expect(sampled, equals(end.primary.background));
  });

  testWidgets('maxUpdatesPerSecond caps inherited theme publishes', (
    tester,
  ) async {
    final begin = themeFrom(Colors.blue);
    final end = themeFrom(Colors.purple);
    var buildCount = 0;
    Color? sampled;

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedMonetTheme(
          data: begin,
          animateThemeData: false,
          duration: const Duration(milliseconds: 1000),
          maxUpdatesPerSecond: 10,
          child: _Probe(
            onBuild: (ctx) {
              buildCount++;
              sampled = MonetTheme.of(ctx).primary.background;
            },
          ),
        ),
      ),
    );
    expect(buildCount, 1);
    expect(sampled, equals(begin.primary.background));

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedMonetTheme(
          data: end,
          animateThemeData: false,
          duration: const Duration(milliseconds: 1000),
          maxUpdatesPerSecond: 10,
          child: _Probe(
            onBuild: (ctx) {
              buildCount++;
              sampled = MonetTheme.of(ctx).primary.background;
            },
          ),
        ),
      ),
    );
    final afterRetargetBuilds = buildCount;

    // 5 vsync-ish frames at 16ms each is below the 100ms publish interval.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(buildCount, afterRetargetBuilds);
    expect(sampled, equals(begin.primary.background));

    await tester.pump(const Duration(milliseconds: 25));
    expect(buildCount, greaterThan(afterRetargetBuilds));
    expect(sampled, isNot(equals(begin.primary.background)));

    await tester.pumpAndSettle();
    expect(sampled, equals(end.primary.background));
  });

  testWidgets('paint color bus updates while inherited theme is final-only', (
    tester,
  ) async {
    final begin = themeFrom(Colors.blue);
    final end = themeFrom(Colors.purple);
    var inheritedBuilds = 0;
    var paintUpdates = 0;
    Color? inheritedColor;
    Color? paintColor;

    Widget tree(MonetThemeData data) {
      return MaterialApp(
        home: AnimatedMonetTheme(
          data: data,
          animateThemeData: false,
          duration: const Duration(milliseconds: 1000),
          maxUpdatesPerSecond: 0,
          child: Column(
            children: [
              _Probe(
                onBuild: (ctx) {
                  inheritedBuilds++;
                  inheritedColor = MonetTheme.of(ctx).primary.background;
                },
              ),
              _PaintProbe(
                onValue: (value) {
                  paintUpdates++;
                  paintColor = value.primary.background;
                },
              ),
            ],
          ),
        ),
      );
    }

    await tester.pumpWidget(tree(begin));
    expect(inheritedColor, equals(begin.primary.background));
    expect(paintColor, equals(begin.primary.background));

    await tester.pumpWidget(tree(end));
    final buildsAfterRetarget = inheritedBuilds;
    final paintUpdatesAfterRetarget = paintUpdates;

    await tester.pump(const Duration(milliseconds: 16));
    expect(inheritedBuilds, buildsAfterRetarget);
    expect(inheritedColor, equals(begin.primary.background));
    expect(paintUpdates, greaterThan(paintUpdatesAfterRetarget));
    expect(paintColor, isNot(equals(begin.primary.background)));

    await tester.pumpAndSettle();
    expect(inheritedColor, equals(end.primary.background));
    expect(paintColor, equals(end.primary.background));
  });

  testWidgets('final-only inherited mode does not publish on retarget', (
    tester,
  ) async {
    final begin = themeFrom(Colors.blue);
    final firstEnd = themeFrom(Colors.purple);
    final secondEnd = themeFrom(Colors.green);
    var inheritedBuilds = 0;
    var paintUpdates = 0;
    Color? inheritedColor;
    Color? paintColor;

    Widget tree(MonetThemeData data) {
      return MaterialApp(
        home: AnimatedMonetTheme(
          data: data,
          animateThemeData: false,
          duration: const Duration(milliseconds: 1000),
          maxUpdatesPerSecond: 0,
          child: Column(
            children: [
              _Probe(
                onBuild: (ctx) {
                  inheritedBuilds++;
                  inheritedColor = MonetTheme.of(ctx).primary.background;
                },
              ),
              _PaintProbe(
                onValue: (value) {
                  paintUpdates++;
                  paintColor = value.primary.background;
                },
              ),
            ],
          ),
        ),
      );
    }

    await tester.pumpWidget(tree(begin));
    expect(inheritedColor, equals(begin.primary.background));

    await tester.pumpWidget(tree(firstEnd));
    expect(inheritedColor, equals(begin.primary.background));
    final buildsAfterFirstRetarget = inheritedBuilds;

    await tester.pump(const Duration(milliseconds: 200));
    expect(inheritedBuilds, buildsAfterFirstRetarget);
    expect(inheritedColor, equals(begin.primary.background));
    expect(paintColor, isNot(equals(begin.primary.background)));

    await tester.pumpWidget(tree(secondEnd));
    // This is the important bit: retargeting from an in-flight paint value must
    // not publish that intermediate value through the inherited MonetTheme.
    expect(inheritedColor, equals(begin.primary.background));
    final buildsAfterSecondRetarget = inheritedBuilds;
    final paintUpdatesAfterSecondRetarget = paintUpdates;

    await tester.pump(const Duration(milliseconds: 16));
    expect(inheritedBuilds, buildsAfterSecondRetarget);
    expect(inheritedColor, equals(begin.primary.background));
    expect(paintUpdates, greaterThan(paintUpdatesAfterSecondRetarget));

    await tester.pumpAndSettle();
    expect(inheritedColor, equals(secondEnd.primary.background));
    expect(paintColor, equals(secondEnd.primary.background));
  });

  testWidgets('ThemeData animates when animateThemeData=true', (tester) async {
    final begin = themeFrom(Colors.blue);
    final end = themeFrom(Colors.purple);

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedMonetTheme(
          data: begin,
          animateThemeData: true,
          duration: const Duration(milliseconds: 200),
          child: const SizedBox.shrink(),
        ),
      ),
    );

    final initial = Theme.of(
      tester.element(find.byType(SizedBox)),
    ).colorScheme.primary;

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedMonetTheme(
          data: end,
          animateThemeData: true,
          duration: const Duration(milliseconds: 200),
          child: const SizedBox.shrink(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    final mid = Theme.of(
      tester.element(find.byType(SizedBox)),
    ).colorScheme.primary;
    expect(mid, isNot(equals(initial)));

    await tester.pump(const Duration(milliseconds: 120));
    final endColor = Theme.of(
      tester.element(find.byType(SizedBox)),
    ).colorScheme.primary;
    expect(endColor, isNot(equals(initial)));
  });
}
