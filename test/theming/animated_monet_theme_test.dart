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

  MonetThemeData themeFrom(Color primary, {Brightness brightness = Brightness.dark}) {
    return MonetThemeData.fromColors(
      brightness: brightness,
      backgroundTone: brightness == Brightness.dark ? 12 : 94,
      primary: primary,
      secondary: Colors.teal,
      tertiary: Colors.orange,
      contrast: 0.5,
    );
  }

  testWidgets('AnimatedMonetTheme animates Palette.background', (tester) async {
    final begin = themeFrom(Colors.blue);
    final end = themeFrom(Colors.purple);
    Color? sampled;

    // Mount at begin
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedMonetTheme(
          begin: begin,
          end: begin,
          animateThemeData: false,
          duration: const Duration(milliseconds: 200),
          child: _Probe(onBuild: (ctx) {
            sampled = MonetTheme.of(ctx).primary.background;
          }),
        ),
      ),
    );
    final initial = sampled!;
    expect(initial, begin.primary.background);

    // Change to end (start animation)
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedMonetTheme(
          begin: begin,
          end: end,
          animateThemeData: false,
          duration: const Duration(milliseconds: 200),
          child: _Probe(onBuild: (ctx) {
            sampled = MonetTheme.of(ctx).primary.background;
          }),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    final mid = sampled!;
    expect(mid, isNot(equals(begin.primary.background)));
    expect(mid, isNot(equals(end.primary.background)));

    await tester.pump(const Duration(milliseconds: 120));
    final finalBg = sampled!;
    expect(finalBg, equals(end.primary.background));
  });

  testWidgets('ThemeData stable when animateThemeData=false', (tester) async {
    final begin = themeFrom(Colors.blue);
    final end = themeFrom(Colors.purple);

    late Color initialThemePrimary;

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedMonetTheme(
          begin: begin,
          end: begin,
          animateThemeData: false,
          duration: const Duration(milliseconds: 200),
          child: _Probe(onBuild: (ctx) {
            initialThemePrimary = Theme.of(ctx).colorScheme.primary;
          }),
        ),
      ),
    );

    // Change to end (should keep ThemeData until animation completes)
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedMonetTheme(
          begin: begin,
          end: end,
          animateThemeData: false,
          duration: const Duration(milliseconds: 200),
          child: const SizedBox.shrink(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    final midThemePrimary = Theme.of(tester.element(find.byType(SizedBox))).colorScheme.primary;
    expect(midThemePrimary, equals(initialThemePrimary));

    await tester.pump(const Duration(milliseconds: 120));
    final endThemePrimary = Theme.of(tester.element(find.byType(SizedBox))).colorScheme.primary;
    expect(endThemePrimary, equals(end.createThemeData(tester.element(find.byType(SizedBox))).colorScheme.primary));
  });

  testWidgets('Retarget mid-animation is continuous (no snap)', (tester) async {
    final begin = themeFrom(Colors.blue);
    final midEnd = themeFrom(Colors.purple);
    final newEnd = themeFrom(Colors.green);

    Color? sampled;

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedMonetTheme(
          begin: begin,
          end: midEnd,
          animateThemeData: false,
          duration: const Duration(milliseconds: 200),
          child: _Probe(onBuild: (ctx) {
            sampled = MonetTheme.of(ctx).primary.background;
          }),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    final beforeRetarget = sampled!;

    // Update end (retarget). The immediate frame should equal beforeRetarget.
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedMonetTheme(
          begin: begin,
          end: newEnd,
          animateThemeData: false,
          duration: const Duration(milliseconds: 200),
          child: _Probe(onBuild: (ctx) {
            sampled = MonetTheme.of(ctx).primary.background;
          }),
        ),
      ),
    );

    final immediatelyAfter = sampled!;
    expect(immediatelyAfter, equals(beforeRetarget));

    await tester.pump(const Duration(milliseconds: 50));
    final afterSome = sampled!;
    expect(afterSome, isNot(equals(beforeRetarget)));
  });

  testWidgets('ThemeData animates when animateThemeData=true', (tester) async {
    final begin = themeFrom(Colors.blue);
    final end = themeFrom(Colors.purple);

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedMonetTheme(
          begin: begin,
          end: begin,
          animateThemeData: true,
          duration: const Duration(milliseconds: 200),
          child: const SizedBox.shrink(),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedMonetTheme(
          begin: begin,
          end: end,
          animateThemeData: true,
          duration: const Duration(milliseconds: 200),
          child: const SizedBox.shrink(),
        ),
      ),
    );

    final initial = Theme.of(tester.element(find.byType(SizedBox))).colorScheme.primary;
    await tester.pump(const Duration(milliseconds: 100));
    final mid = Theme.of(tester.element(find.byType(SizedBox))).colorScheme.primary;
    expect(mid, isNot(equals(initial)));
    await tester.pump(const Duration(milliseconds: 120));
    final endColor = Theme.of(tester.element(find.byType(SizedBox))).colorScheme.primary;
    expect(endColor, isNot(equals(initial)));
  });
}
