import 'dart:math' as math;

import 'package:flutter/material.dart';
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

    // The spring is barely underdamped: it visually arrives well before it
    // rigorously settles within tolerance (overshoot/ring), so it can take
    // meaningfully longer than `duration` to reach `isDone`. Wait for actual
    // completion rather than assuming a fixed-duration Tween's exact timing.
    await tester.pumpAndSettle();
    expect(sampled, equals(end.primary.background));
  });

  // `AnimatedMonetTheme` used to interpolate colors via `PaletteLerped`
  // (HCT-space cartesian/polar hue lerp) driven by a scalar `t` from a
  // fixed-duration `AnimationController`. It now drives a moving-target spring
  // over raw sRGB channels of the underlying base colors instead (see
  // `_ThemeVectorSim`/`_springDescriptionFor` in animated_monet_theme.dart),
  // which is what makes retargeting velocity-continuous rather than
  // clock-resetting. `interpolationStyle` no longer changes the live
  // animation's color path -- it is kept only for API compatibility. These
  // tests now assert the architecture-independent property that actually
  // matters: the animated color moves smoothly from `begin` toward `end`,
  // rather than an exact `PaletteLerped` midpoint.
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

  testWidgets(
    'AnimatedMonetTheme accepts interpolationStyle without effect on the '
    'live spring (kept for API compatibility)',
    (tester) async {
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
    },
  );

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

    await tester.pumpAndSettle();
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

    await tester.pumpAndSettle();
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

    // The spring has a soft onset (acceleration ramps 0->1 over ~167ms, see
    // RK4Spring), so a single 16ms tick is too early to show visible integer
    // RGB movement for a 1000ms-duration spring. Use a slightly longer elapsed
    // time so the ramp has engaged, while still being comfortably before
    // `pumpAndSettle()`.
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
                inheritedTypography = MonetTheme.of(
                  ctx,
                ).monetThemeData.typography;
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
    'rapid continuous retargets do not freeze then jump (moving-target bug)',
    (tester) async {
      // Reproduces the WallpaperPositionedTheme scroll-jank bug: a scroll
      // gesture retargets AnimatedMonetTheme roughly every 8ms (one vsync at
      // 120Hz), well inside its 200ms duration. Each individual retarget is
      // handled correctly (current -> new target), but `_controller.forward(
      // from: 0)` resets the animation clock on every single retarget. Since
      // retargets arrive far faster than `duration`, the visible value never
      // gets past `t ~= elapsed/duration` before being reset again, so it sits
      // almost frozen near `begin` for the whole gesture. The instant retargets
      // stop, the last scheduled animation is finally allowed to run
      // uninterrupted, covering all the accumulated distance in one visible
      // burst -- exactly the reported "eases slowly, then suddenly jumps".
      final begin = themeFrom(Colors.blue);
      final end = themeFrom(Colors.red);
      final samples = <Color>[];

      Widget tree(MonetThemeData data) => MaterialApp(
        home: AnimatedMonetTheme(
          data: data,
          animateThemeData: false,
          duration: const Duration(milliseconds: 200),
          child: _Probe(
            onBuild: (ctx) {
              samples.add(MonetTheme.of(ctx).primary.background);
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

      // "Scrolling" now stops. Let the final in-flight animation finish.
      final beforeSettle = samples.last;
      await tester.pumpAndSettle();
      final afterSettle = samples.last;
      final postScrollJump = rgbColorDistance(beforeSettle, afterSettle);

      // A well-behaved moving-target follow should have visibly tracked most
      // of the true target's motion *during* the 400ms of continuous
      // scrolling, so the remaining post-scroll settle is a small tail, not a
      // big sudden swing.
      expect(
        distanceCoveredDuringScroll,
        greaterThan(totalDistance * 0.5),
        reason:
            'expected the animated value to have visibly tracked the moving '
            'target during the scroll gesture, not sit frozen near `begin`',
      );
      expect(
        postScrollJump,
        lessThan(totalDistance * 0.3),
        reason:
            'expected only a small residual settle after scrolling stops, not '
            'a big one-shot jump covering most of the total distance',
      );
    },
  );

  testWidgets('settles promptly after a big retarget followed by a tiny one '
      '(no post-settle tick storm)', (tester) async {
    // Reproduces a real scroll trace (repro4.txt): a big wallpaper-driven
    // retarget, then ~100ms later a second retarget only ~1 unit away in RGB
    // (essentially "already there"). `_springDescriptionFor` used to fix
    // friction=50 (Fuchsia's UI-spring convention), which is underdamped for
    // these tensions and rings -- repeatedly overshoots and returns past the
    // target -- for a long time after any fast chase, observed as ~30 extra
    // ticks / ~250ms of paint-bus notifications and repaints doing nothing
    // perceptible. Deriving friction from tension to hold a critical damping
    // ratio removes the ringing: the value still converges monotonically
    // (verified below), leaving only genuine, proportional settle time --
    // not oscillation. `_ThemeVectorSim.isDone`'s perceptual early-exit is a
    // secondary backstop for the remaining tail.
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

    // Give it a generous window: 320ms at ~8ms/frame is 40 frames.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 8));
    }

    final ticksDuringWindow = samples.length - samplesAtSecondRetarget;

    // The property that actually matters: no ringing. Once two consecutive
    // published colors are equal, every later one must also equal it --
    // i.e. the value converges monotonically and settles once, rather than
    // oscillating in and out of "visually arrived" repeatedly.
    final tail = samples.sublist(samplesAtSecondRetarget);
    final finalValue = tail.last;
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

    // A generous bound on genuine settle time. Before deriving friction from
    // tension (critical damping), this scenario needed on the order of 30
    // ticks / ~250ms purely from ringing; it now needs meaningfully less,
    // proportional to the (large) first retarget's distance and how early
    // the second retarget interrupted it -- not an arbitrary tail.
    expect(
      ticksDuringWindow,
      lessThan(25),
      reason:
          'expected the spring to converge well within the settle window, not '
          'keep ticking for nearly the whole 40-frame window',
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

  testWidgets(
    'derived text hue moves smoothly, without large per-tick swings, through '
    'a near-complementary retarget (repro13.txt)',
    (tester) async {
      // `primary.text` is *derived* (contrast-solved from primary.color and
      // primary.background), not itself directly animated. Before hue/chroma
      // /tone became the animated base seed representation (see
      // `_ThemeMotionState`), the seeds sprang independently in raw sRGB, so a
      // transition between two sufficiently different hues drew a straight
      // line through RGB space that could pass close to the neutral axis --
      // and near that axis, derived hue became numerically unstable, showing
      // single-tick swings of 30-150 degrees even though the actual color was
      // nearly imperceptible from gray (see repro13.txt and
      // hue_instability_diagnostic_test.dart). Confirms that no longer
      // happens end-to-end through the real widget/spring pipeline.
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
      // mid-flight — the derived (contrast-solved) text sweeps hue faster
      // while its chroma dips through the valley between near-complementary
      // endpoints (observed peak: ~27 deg/tick at chroma ~16). So assert the
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
      // boundary. Derived-palette-space interpolation (lerping the two solved
      // endpoint palettes) keeps every role continuous.
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
    // polarity crossing usually happens *mid-flight*, between retargets
    // whose begin palette is itself an in-flight lerped value. Exercises
    // the rebased-begin path (including nested-lerp flattening) across
    // several segments spanning light->dark and back.
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
    // Threshold note: a chasing spring with carried velocity legitimately
    // moves the solved text ~12 tones/tick here -- the foreground's journey
    // within one 80ms segment can be several times longer than the
    // background's, so the lerp traverses it faster. That is continuous
    // motion, not the pathology. The polarity flip this guards against was
    // a ~100-tone single-tick step.
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
        'a large color transition actually animates under $model x $style '
        '(motion epsilons must match the model\'s native coordinate scale)',
        (tester) async {
          // The motion channels spring in each color model's *native*
          // coordinates, whose scales differ by ~100x (CAM16 aStar spans
          // roughly +-50, oklch a/b roughly +-0.3). A model-blind epsilon
          // sized for CAM16 would classify almost any oklch journey as
          // sub-epsilon: born-done, one publish, instant snap. Assert every
          // model/basis pairing produces a real multi-tick animation that
          // settles at the target.
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
              child: _PaintProbe(onValue: publishes.add),
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
