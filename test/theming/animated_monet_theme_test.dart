import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/theming/animated_monet_theme.dart';
import 'package:libmonet/theming/monet_theme.dart';
import 'package:libmonet/theming/monet_theme_data.dart';

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
