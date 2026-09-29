import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/theming/animated_monet_theme.dart';
import 'package:libmonet/theming/interpolation_style.dart';
import 'package:libmonet/theming/monet_theme.dart';
import 'package:libmonet/theming/monet_theme_data.dart';
import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/colorspaces/hct.dart';
import 'package:libmonet/theming/monet_paint_colors.dart';

class _PaintProbe extends StatefulWidget {
  const _PaintProbe({required this.onValue});

  final void Function(MonetThemeData value) onValue;

  @override
  State<_PaintProbe> createState() => _PaintProbeState();
}

class _PaintProbeState extends State<_PaintProbe> {
  MonetPaintColors? _colors;
  MonetPaletteBinding? _binding;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = MonetPaintColorsScope.of(context);
    if (identical(_colors, next)) return;
    _binding?.dispose();
    _binding = next.bindThemePalette(MonetPalette.primary)
      ..addListener(_notify);
    _colors = next;
    _notify();
  }

  void _notify() {
    final colors = _colors;
    if (colors != null) {
      widget.onValue(colors.value.copyWith(primary: _binding!.value));
    }
  }

  @override
  void dispose() {
    _binding?.dispose();
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

    // Duration is a spring pacing hint, not a fixed tween deadline.
    await tester.pumpAndSettle();
    expect(sampled, equals(end.primary.background));
  });

  // Live animation interpolates solved colors with shared progress. Assert
  // intermediate colors and position-continuous retargets, not a fixed-duration
  // tween fraction: the duration parameter controls spring stiffness.
  testWidgets('AnimatedMonetTheme interpolates through intermediate colors', (
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

    final mid = sampled!;
    expect(mid, isNot(equals(begin.primary.color)));
    expect(mid, isNot(equals(end.primary.color)));

    await tester.pumpAndSettle();
    expect(sampled, equals(end.primary.color));
  });

  testWidgets('AnimatedMonetTheme also animates with the polar style', (
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
    expect(sampled, isNot(equals(begin.primary.color)));
    expect(sampled, isNot(equals(end.primary.color)));

    await tester.pumpAndSettle();
    expect(sampled, equals(end.primary.color));
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
    final initialThemePrimary = Theme.of(tester.element(find.byType(SizedBox)))
        .colorScheme
        .primary;

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
    final midThemePrimary = Theme.of(tester.element(find.byType(SizedBox)))
        .colorScheme
        .primary;
    expect(midThemePrimary, equals(initialThemePrimary));

    await tester.pumpAndSettle();
    final endThemePrimary = Theme.of(tester.element(find.byType(SizedBox)))
        .colorScheme
        .primary;
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

    await tester.pumpAndSettle();
    expect(sampled, equals(secondEnd.primary.background));
  });

  testWidgets(
    'paint motion respects timeDilation across ticks and ticker restarts',
    (tester) async {
      addTearDown(() => timeDilation = 1);
      final begin = themeFrom(Colors.red);
      final end = themeFrom(Colors.blue);

      Future<(Color, Color)> run(double dilation) async {
        await tester.pumpWidget(const SizedBox());
        timeDilation = dilation;
        await tester.pump(); // Establish the scheduler's new monotonic epoch.
        late MonetPaintColors bus;
        var completions = 0;
        Widget tree(MonetThemeData data) => MaterialApp(
          home: AnimatedMonetTheme(
            data: data,
            maxUpdatesPerSecond: 0,
            duration: const Duration(milliseconds: 160),
            onEnd: () => completions++,
            child: Builder(
              builder: (context) {
                bus = MonetPaintColorsScope.of(context);
                return const SizedBox();
              },
            ),
          ),
        );
        await tester.pumpWidget(tree(begin));
        final binding = bus.bindThemePalette(
          MonetPalette.primary,
          roles: const {PaletteRole.color},
        );
        await tester.pumpWidget(tree(end));
        await tester.pump(const Duration(milliseconds: 100));
        final at100 = binding.value.color;
        if (dilation > 1) {
          await tester.pump(
            Duration(milliseconds: (100 * (dilation - 1)).round()),
          );
        }
        final atEqualAnimationTime = binding.value.color;
        await tester.pumpAndSettle();
        expect(binding.value.color, end.primary.color);
        expect(completions, 1);
        await tester.pump(const Duration(seconds: 10));
        // A restarted ticker's elapsed resets to zero; the motion epoch must not.
        await tester.pumpWidget(tree(begin));
        expect(binding.value.color, end.primary.color);
        await tester.pump(Duration(milliseconds: (100 * dilation).round()));
        expect(binding.value.color, isNot(end.primary.color));
        expect(binding.value.color, isNot(begin.primary.color));
        await tester.pumpAndSettle();
        expect(binding.value.color, begin.primary.color);
        expect(completions, 2);
        expect(tester.hasRunningAnimations, false);
        binding.dispose();
        await tester.pumpWidget(const SizedBox());
        return (at100, atEqualAnimationTime);
      }

      final normal = await run(1);
      final slow = await run(10);
      // Flutter verifies scheduler invariants before addTearDown callbacks.
      timeDilation = 1;
      expect(
        slow.$1,
        isNot(normal.$1),
        reason: '100 ms wall time is only 10 ms of slow motion',
      );
      expect(
        slow.$2,
        normal.$2,
        reason: 'equal animation time follows the same color path',
      );
    },
  );

  testWidgets(
    'changing timeDilation mid-flight preserves retarget continuity',
    (tester) async {
      addTearDown(() => timeDilation = 1);
      final begin = themeFrom(Colors.red);
      final end = themeFrom(Colors.blue);
      late MonetPaintColors bus;
      Widget tree(MonetThemeData data) => MaterialApp(
        home: AnimatedMonetTheme(
          data: data,
          maxUpdatesPerSecond: 0,
          child: Builder(
            builder: (context) {
              bus = MonetPaintColorsScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpWidget(tree(begin));
      final binding = bus.bindThemePalette(
        MonetPalette.primary,
        roles: const {PaletteRole.color},
      );
      addTearDown(binding.dispose);
      await tester.pumpWidget(tree(end));
      await tester.pump(const Duration(milliseconds: 50));
      final before = binding.value.color;
      timeDilation = 10;
      await tester.pumpWidget(tree(begin));
      expect(binding.value.color, before);
      await tester.pump(const Duration(milliseconds: 100));
      expect(bus.isAnimating, true);
      expect(binding.value.color, isNot(begin.primary.color));
      final beforeNormal = binding.value.color;
      timeDilation = 1;
      await tester.pump();
      expect(binding.value.color, beforeNormal);
      await tester.pumpAndSettle();
      expect(binding.value.color, begin.primary.color);
      expect(tester.hasRunningAnimations, false);
    },
  );

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

    // Allow enough spring travel to change rounded RGB values, while remaining
    // comfortably before settlement. There is no separate onset/easing ramp.
    await tester.pump(const Duration(milliseconds: 100));
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

  testWidgets(
    'meta-only retarget (typography change, identical colors) publishes '
    'immediately even in final-only mode',
    (tester) async {
      // Regression: a font-settings change produces a MonetThemeData that
      // differs ONLY in its typography callback identity. Every numeric
      // channel is already at the target, so the retarget sim is born done,
      // its ticker never starts, and the completed-status publish never
      // fires — leaving inherited-theme dependents (fonts!) stale forever on
      // a static wallpaper. Observed as: no-background mods never updating
      // when fonts change.
      final colors = themeFrom(Colors.blue);
      Typography oldTypography(ColorScheme scheme) =>
          Typography.material2021(colorScheme: scheme);
      Typography newTypography(ColorScheme scheme) => Typography.material2014();
      final begin = colors.copyWith(typography: oldTypography);
      final end = colors.copyWith(typography: newTypography);
      assert(begin != end, 'typography identity must affect equality');

      Typography Function(ColorScheme)? inheritedTypography;
      var onEndCalls = 0;

      Widget tree(MonetThemeData data) {
        return MaterialApp(
          home: AnimatedMonetTheme(
            data: data,
            animateThemeData: false,
            duration: const Duration(milliseconds: 1000),
            // Final-only inherited publishes: the wallpaper no-background
            // configuration, where the bug was reported.
            maxUpdatesPerSecond: 0,
            onEnd: () => onEndCalls++,
            child: _Probe(
              onBuild: (ctx) {
                inheritedTypography = MonetTheme.of(ctx)
                    .monetThemeData
                    .typography;
              },
            ),
          ),
        );
      }

      await tester.pumpWidget(tree(begin));
      expect(inheritedTypography, same(oldTypography));

      await tester.pumpWidget(tree(end));
      await tester.pump();
      // No color motion to wait out: the new semantic target (carrying the
      // new typography) must be published without pumpAndSettle.
      expect(inheritedTypography, same(newTypography));
      expect(onEndCalls, 1);

      // And the controller must be idle: nothing left to settle.
      expect(tester.hasRunningAnimations, isFalse);
    },
  );

  testWidgets(
    'rapid retargets keep moving and settle smoothly with shared progress',
    (tester) async {
      // Shared-progress interpolation restarts at rest and can lag during
      // 120 Hz target streams. The old '<30% remaining travel' requirement
      // depended on per-color velocity-preserving springs. Preserve
      // meaningful movement during the gesture, no single-frame catch-up jump,
      // and prompt/exact completion rather than that latency guarantee.
      final begin = themeFrom(Colors.blue);
      final end = themeFrom(Colors.red);
      final samples = <Color>[];

      Widget tree(MonetThemeData data) => MaterialApp(
        home: AnimatedMonetTheme(
          data: data,
          animateThemeData: false,
          duration: const Duration(milliseconds: 200),
          child: _PaintProbe(
            onValue: (value) {
              samples.add(value.primary.background);
            },
          ),
        ),
      );

      await tester.pumpWidget(tree(begin));

      // Simulate ~400ms of continuous scrolling: the true target moves
      // smoothly and monotonically from `begin` to `end`, retargeting every
      // 8ms (one vsync at 120Hz).
      const steps = 50;
      for (var i = 1; i <= steps; i++) {
        final t = i / steps;
        final target = themeFrom(Color.lerp(Colors.blue, Colors.red, t)!);
        await tester.pumpWidget(tree(target));
        await tester.pump(const Duration(milliseconds: 8));
      }

      double rgbColorDistance(Color a, Color b) {
        final dr = (a.r - b.r) * 255.0;
        final dg = (a.g - b.g) * 255.0;
        final db = (a.b - b.b) * 255.0;
        return math.sqrt(dr * dr + dg * dg + db * db);
      }

      final totalDistance = rgbColorDistance(
        begin.primary.background,
        end.primary.background,
      );
      final distanceCoveredDuringScroll = rgbColorDistance(
        begin.primary.background,
        samples.last,
      );

      // "Scrolling" stops. Sample every 8ms instead of conflating all remaining
      // travel (pumpAndSettle) with a single-frame jump.
      final settleStart = samples.length - 1;
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 8));
      }
      expect(
        distanceCoveredDuringScroll,
        greaterThan(totalDistance * 0.5),
        reason:
            'expected the animated value to have visibly tracked the moving '
            'target during the scroll gesture, not sit frozen near `begin`',
      );
      expect(
        [
          for (var i = settleStart + 1; i < samples.length; i++)
            rgbColorDistance(samples[i - 1], samples[i]),
        ].reduce(math.max),
        lessThan(totalDistance * 0.15),
        reason: 'catch-up must remain a smooth fade, not an endpoint snap',
      );
      expect(samples.last, end.primary.background);
      expect(tester.hasRunningAnimations, isFalse);
    },
  );

  testWidgets('settles promptly after a big retarget followed by a tiny one '
      '(no post-settle tick storm)', (tester) async {
    // Interrupted motion must converge without ringing. Conservative paint
    // invalidation can publish equal RGB values near completion; stopping is
    // governed by normalized progress, not when RGB rounding first plateaus.
    final begin = themeFrom(Colors.blue);
    final bigRetarget = themeFrom(const Color(0xFF391A0F));
    // Only ~1 unit of RGB distance from bigRetarget -- matches repro4.txt.
    final tinyRetarget = themeFrom(const Color(0xFF381A0F));
    final samples = <Color>[];

    Widget tree(MonetThemeData data) => MaterialApp(
      home: AnimatedMonetTheme(
        data: data,
        animateThemeData: false,
        duration: const Duration(milliseconds: 200),
        child: _PaintProbe(
          onValue: (value) {
            samples.add(value.primary.background);
          },
        ),
      ),
    );

    await tester.pumpWidget(tree(begin));
    await tester.pumpWidget(tree(bigRetarget));

    // Let the big retarget run for a while, then retarget again to a
    // near-identical value, mid-flight -- exactly like repro4.txt's second
    // `target compute` arriving ~100ms after the first.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(tree(tinyRetarget));

    final samplesAtSecondRetarget = samples.length;

    // Normalized progress completes within 480ms at this response speed.
    // Keep pumping past that deadline to verify no post-completion notifications.
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 8));
    }

    final ticksDuringWindow = samples.length - samplesAtSecondRetarget;

    // Once the endpoint is reached it must not oscillate away again. Temporary
    // rounding plateaus before reaching the endpoint are permitted.
    final tail = samples.sublist(samplesAtSecondRetarget);
    final finalValue = tail.last;
    expect(finalValue, tinyRetarget.primary.background);
    expect(tester.hasRunningAnimations, false);
    final firstSettledIndex = tail.indexWhere((c) => c == finalValue);
    for (var i = firstSettledIndex; i < tail.length; i++) {
      expect(
        tail[i],
        equals(finalValue),
        reason:
            'value changed again at tick $i after first reaching its final '
            'value -- this is ringing (oscillating in and out of "visually '
            'arrived"), which critical damping should eliminate',
      );
    }

    expect(
      ticksDuringWindow,
      lessThan(60),
      reason: 'normalized completion must stop notifications without further getters',
    );
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

    final initial = Theme.of(tester.element(find.byType(SizedBox)))
        .colorScheme
        .primary;

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
    final mid = Theme.of(tester.element(find.byType(SizedBox)))
        .colorScheme
        .primary;
    expect(mid, isNot(equals(initial)));

    await tester.pump(const Duration(milliseconds: 120));
    final endColor = Theme.of(tester.element(find.byType(SizedBox)))
        .colorScheme
        .primary;
    expect(endColor, isNot(equals(initial)));
  });

  testWidgets(
    'derived text hue moves smoothly, without large per-tick swings, through '
    'a near-complementary retarget (repro13.txt)',
    (tester) async {
      // The old raw-sRGB seed path re-solved text every tick and could produce
      // 30-150 degree hue swings near the neutral axis (repro13.txt). Text is
      // now solved only at the endpoints and directly animated in perceptual
      // coordinates. Keep this end-to-end regression against hue whipsaw.
      final begin = themeFrom(Colors.blue);
      final end = themeFrom(Colors.deepOrange);
      // Signed shortest-arc per-tick hue deltas of the derived text color.
      final hueDeltas = <double>[];
      double? lastHue;

      Widget tree(MonetThemeData data) => MaterialApp(
        home: AnimatedMonetTheme(
          data: data,
          animateThemeData: false,
          duration: const Duration(milliseconds: 200),
          child: _PaintProbe(
            onValue: (value) {
              final hue = Hct.fromColor(value.primary.text).hue;
              if (lastHue != null) {
                var delta = hue - lastHue!;
                if (delta > 180) delta -= 360;
                if (delta <= -180) delta += 360;
                hueDeltas.add(delta);
              }
              lastHue = hue;
            },
          ),
        ),
      );

      await tester.pumpWidget(tree(begin));
      await tester.pumpWidget(tree(end));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 8));
      }
      await tester.pumpAndSettle();

      expect(
        hueDeltas,
        isNotEmpty,
        reason: 'expected primary.text to actually move during the retarget',
      );
      // The instability this guards against was NON-MONOTONE: derived hue
      // whipping back and forth by 30-150 degrees per tick while the color
      // sat near the neutral axis. Smooth motion is allowed to accelerate
      // mid-flight — text can sweep hue faster while its chroma dips through
      // the valley between near-complementary endpoints. So assert the
      // two properties that separate a sweep from the pathology:
      // 1. one consistent direction of travel (reversals only as sub-degree
      //    settle jitter, not tens-of-degrees whipsaw);
      // 2. no single tick remotely near the old 30-150 degree swings.
      final travel = hueDeltas.reduce((a, b) => a + b);
      final direction = travel.sign;
      final maxReversal = hueDeltas
          .map((d) => d * direction < 0 ? d.abs() : 0.0)
          .reduce(math.max);
      expect(
        maxReversal,
        lessThan(5),
        reason:
            'expected monotone hue travel (settle jitter aside); a large '
            'direction reversal is the signature of the old raw-RGB-derived '
            'instability; got a $maxReversal degree reversal',
      );
      final maxDelta = hueDeltas.map((d) => d.abs()).reduce(math.max);
      expect(
        maxDelta,
        lessThan(30),
        reason:
            'expected a perceptually smooth hue sweep; got a $maxDelta degree '
            'single-tick swing, approaching the old instability magnitudes',
      );
    },
  );

  // Reusable harness for the polarity-crossing regression tests below.
  // Feeds [targets] to an AnimatedMonetTheme one after another ([holdTicks]
  // 8ms pumps between retargets), recording the contrast-solved
  // `primary.text` tone at every paint-bus publish, and returns the per-tick
  // tone deltas.
  Future<List<double>> textToneDeltasThrough(
    WidgetTester tester,
    List<MonetThemeData> targets, {
    int holdTicks = 10,
  }) async {
    final tones = <double>[];
    Widget tree(MonetThemeData data) => MaterialApp(
      home: AnimatedMonetTheme(
        data: data,
        duration: const Duration(milliseconds: 160),
        maxUpdatesPerSecond: 0,
        child: _PaintProbe(
          onValue: (value) => tones.add(Hct.fromColor(value.primary.text).tone),
        ),
      ),
    );
    await tester.pumpWidget(tree(targets.first));
    await tester.pumpAndSettle();
    for (final target in targets.skip(1)) {
      await tester.pumpWidget(tree(target));
      for (var i = 0; i < holdTicks; i++) {
        await tester.pump(const Duration(milliseconds: 8));
      }
    }
    await tester.pumpAndSettle();
    expect(
      tones.last,
      closeTo(Hct.fromColor(targets.last.primary.text).tone, 1.0),
      reason: 'expected the animation to arrive at the final target',
    );
    final deltas = <double>[];
    for (var i = 1; i < tones.length; i++) {
      deltas.add((tones[i] - tones[i - 1]).abs());
    }
    return deltas;
  }

  testWidgets(
    'derived text animates continuously through a light->dark background '
    'polarity crossing (wallpaper scroll snap repro)',
    (tester) async {
      // `primary.text` is contrast-solved against the background, and the
      // solver is a STEP function of background tone: it picks the lighter or
      // darker candidate. When the animated portion of the theme was the raw
      // seed channels re-solved per tick, animating a background across the
      // mid-tones made every solved foreground flip polarity -- text jumped
      // tone 0 -> 100 (black -> white) in a single 8ms tick regardless of
      // spring speed or timeDilation, which read as "the mod snaps to dark"
      // when a transparent surface scrolled across a light->dark wallpaper
      // boundary. Interpolating between solved paint outputs keeps each
      // retained role continuous instead of re-solving during the transition.
      final deltas = await textToneDeltasThrough(tester, [
        themeFrom(Colors.blue, brightness: Brightness.light), // bg tone 94
        themeFrom(Colors.blue), // dark, bg tone 12
      ], holdTicks: 40);
      expect(deltas, isNotEmpty);
      final maxDelta = deltas.reduce(math.max);
      expect(
        maxDelta,
        lessThan(10),
        reason:
            'expected solved text to travel smoothly between the two solved '
            'endpoints; a ~100-tone single-tick jump is the solver polarity '
            'flip this guards against; got $maxDelta',
      );
    },
  );

  testWidgets('derived text stays continuous under rapid retargets that cross '
      'polarity mid-flight (throttled wallpaper resampling)', (tester) async {
    // The wallpaper pipeline retargets every ~80ms during a scroll, so the
    // polarity crossing usually happens *mid-flight*. Exercise RGB rebasing
    // across several light->dark->light retargets; no nested lerp history grows.
    MonetThemeData at(double tone, Brightness brightness) =>
        MonetThemeData.fromColors(
          brightness: brightness,
          backgroundTone: tone,
          primary: Colors.blue,
          secondary: Colors.teal,
          tertiary: Colors.orange,
          contrast: 0.5,
        );
    final deltas = await textToneDeltasThrough(tester, [
      at(94, Brightness.light),
      at(75, Brightness.light),
      at(55, Brightness.light),
      at(30, Brightness.dark),
      at(12, Brightness.dark),
      at(40, Brightness.dark),
      at(80, Brightness.light),
    ]);
    expect(deltas, isNotEmpty);
    final maxDelta = deltas.reduce(math.max);
    // The polarity flip this guards against was a ~100-tone single-tick step.
    expect(
      maxDelta,
      lessThan(25),
      reason:
          'expected continuity across retargets that cross solver polarity '
          'mid-flight; got a $maxDelta tone single-tick jump',
    );
  });

  for (final model in ColorModel.values) {
    for (final style in InterpolationStyle.values) {
      testWidgets(
        'a large color transition animates and settles under $model x $style',
        (tester) async {
          // Progress and completion are normalized, not measured in a color
          // model's native units. Every model/path must produce intermediate
          // colors and eventually return the exact endpoint.
          MonetThemeData themeOf(Color color) => MonetThemeData.fromColors(
            brightness: Brightness.dark,
            backgroundTone: 12,
            primary: color,
            secondary: Colors.teal,
            tertiary: Colors.orange,
            contrast: 0.5,
            colorModel: model,
          );
          final begin = themeOf(Colors.blue);
          final end = themeOf(Colors.red);
          final publishes = <MonetThemeData>[];
          Widget tree(MonetThemeData data) => MaterialApp(
            home: AnimatedMonetTheme(
              data: data,
              duration: const Duration(milliseconds: 160),
              maxUpdatesPerSecond: 0,
              interpolationStyle: style,
              child: _PaintProbe(
                onValue: (value) {
                  // A real paint consumer reads the output it displays. Merely
                  // archiving theme objects is not a color subscription.
                  value.primary.color;
                  publishes.add(value);
                },
              ),
            ),
          );
          await tester.pumpWidget(tree(begin));
          await tester.pumpAndSettle();
          publishes.clear();
          await tester.pumpWidget(tree(end));
          for (var i = 0; i < 100; i++) {
            await tester.pump(const Duration(milliseconds: 8));
          }
          await tester.pumpAndSettle();
          expect(
            publishes.length,
            greaterThan(4),
            reason:
                'expected a multi-tick animation, got '
                '${publishes.length} paint publish(es) -- born-done epsilon '
                'misclassification?',
          );
          expect(publishes.last.primary.color, end.primary.color);
        },
      );
    }
  }
}
