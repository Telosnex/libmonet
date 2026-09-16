import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/libmonet.dart';
import 'package:libmonet/theming/paint/palette_motion.dart';

const duration = Duration(milliseconds: 160);
MonetThemeData theme(Color color, {ColorModel model = ColorModel.cam16}) =>
    MonetThemeData.fromColors(
      brightness: Brightness.light,
      backgroundTone: 67,
      primary: color,
      secondary: Colors.teal,
      tertiary: Colors.orange,
      colorModel: model,
    );
Palette gold(MonetThemeData data) => Palette.from(
  Colors.amber,
  backgroundTone: data.backgroundTone,
  colorModel: data.colorModel,
);

void main() {
  test(
    'bindings start empty; getters discover roles and share endpoint work',
    () {
      final stats = PaintMotionStats();
      final bus = MonetPaintColors(
        theme(Colors.red),
        animateUnboundRoles: false,
        stats: stats,
      );
      addTearDown(bus.dispose);
      final a = bus.bind('gold', gold), b = bus.bind('gold', gold);
      expect(bus.retainedRoleCount, 0);
      expect(stats.roleReads, 0);
      expect(a.value.text, b.value.text);
      expect(bus.retainedRoleCount, 1);
      expect(stats.roleReads, 1);
      expect(b.value.background, gold(bus.target).background);
      expect(bus.retainedRoleCount, 2);
      expect(stats.roleReads, 2);
      a.dispose();
      expect(bus.retainedRoleCount, 2, reason: 'b observed text too');
      b.dispose();
      expect(bus.retainedRoleCount, 0);
      expect(bus.retainedPaletteCount, 0);
    },
  );

  test(
    'prewarm is a hint, not an allowlist; observations survive hint changes',
    () {
      final bus = MonetPaintColors(
        theme(Colors.red),
        animateUnboundRoles: false,
      );
      addTearDown(bus.dispose);
      final binding = bus.bindThemePalette(
        MonetPalette.primary,
        roles: const {PaletteRole.background},
      );
      addTearDown(binding.dispose);
      expect(bus.retainedRoleCount, 1);
      expect(binding.value.text, bus.target.primary.text);
      expect(bus.retainedRoleCount, 2);
      binding.update(
        MonetPalette.primary,
        MonetPalette.primary.resolve,
        roles: const {},
      );
      expect(
        bus.retainedRoleCount,
        1,
        reason: 'unread prewarm is gone, observed text remains',
      );
    },
  );

  test(
    'paint subscriptions survive skipped paints and do not notify from getters',
    () {
      var requests = 0, notifications = 0;
      final stats = PaintMotionStats();
      final bus = MonetPaintColors(
        theme(Colors.red),
        animateUnboundRoles: false,
        stats: stats,
        requestFrame: () => requests++,
      );
      addTearDown(bus.dispose);
      final a = bus.bindThemePalette(MonetPalette.primary);
      final b = bus.bindThemePalette(MonetPalette.primary);
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      a.addListener(() => notifications++);
      final begin = a.value.color;
      expect(b.value.color, begin);
      expect(notifications, 0);
      expect(requests, 0);
      bus.retarget(theme(Colors.blue), time: 0, duration: duration);
      notifications = 0;
      final reads = stats.roleReads;
      for (var i = 1; i <= 8; i++) {
        bus.sample(i * .008);
      }
      expect(bus.retainedRoleCount, 1);
      expect(
        notifications,
        greaterThan(0),
        reason: 'no getter needed to continue scheduling repaints',
      );
      expect(
        stats.roleReads,
        reads,
        reason: 'ticks never resolve roles already discovered',
      );
      final decodes = stats.interpolations;
      for (var i = 0; i < 100; i++) {
        expect(a.value.color, b.value.color);
      }
      expect(
        stats.interpolations,
        decodes + 1,
        reason:
            'first paint calculates once; all readers share that lazy result',
      );
      expect(a.value.color, isNot(begin));
      expect(a.value.color, isNot(bus.target.primary.color));
      bus.sample(2);
      notifications = 0;
      bus.sample(3);
      expect(notifications, 0, reason: 'no blanket tick notifications');
    },
  );

  test(
    'inherited outputs discover on read and defer intermediate RGB until read',
    () {
      final stats = PaintMotionStats();
      final bus = MonetPaintColors(theme(Colors.red), stats: stats);
      addTearDown(bus.dispose);
      expect(bus.retainedRoleCount, 0);
      expect(bus.value.primary.color, bus.target.primary.color);
      expect(bus.retainedRoleCount, 1);
      bus.retarget(theme(Colors.blue), time: 0, duration: duration);
      final decodes = stats.interpolations;
      final reads = stats.roleReads;
      for (var i = 1; i <= 8; i++) {
        bus.sample(i * .008);
      }
      expect(
        stats.interpolations,
        decodes,
        reason: 'unread intermediate frames do not convert RGB',
      );
      final frame = bus.value;
      final color = frame.primary.color;
      expect(stats.interpolations, decodes + 1);
      for (var i = 0; i < 100; i++) {
        expect(frame.primary.color, color);
      }
      expect(stats.interpolations, decodes + 1);
      expect(stats.roleReads, reads);
      expect(bus.retainedRoleCount, 1, reason: 'not all 123 built-in outputs');
    },
  );

  test('first use after many targets starts at endpoint; historical frames stay immutable', () {
    final stats = PaintMotionStats();
    final bus = MonetPaintColors(theme(Colors.red), stats: stats);
    addTearDown(bus.dispose);
    final saved = bus.value;
    final savedHash = saved.hashCode;
    for (var i = 0; i < 50; i++) {
      bus.retarget(
        theme(i.isEven ? Colors.blue : Colors.green),
        time: i * .016,
        duration: duration,
      );
      bus.sample(i * .016 + .008);
    }
    expect(stats.roleReads, 0);
    expect(stats.interpolations, 0);
    expect(bus.retainedRoleCount, 0);
    expect(saved.primary.fillHoveredText, saved.target.primary.fillHoveredText);
    expect(saved.hashCode, savedHash);
    expect(
      bus.retainedRoleCount,
      0,
      reason: 'historical getter must not subscribe the current endpoint',
    );
    expect(
      bus.value.primary.fillHoveredText,
      bus.target.primary.fillHoveredText,
    );
    expect(bus.retainedRoleCount, 1);
    final view = bus.value;
    final hash = view.hashCode;
    expect(view.primary.backgroundBorder, view.target.primary.backgroundBorder);
    expect(
      view.hashCode,
      hash,
      reason: 'lazy memoization cannot invalidate map keys',
    );
  });

  test('saved binding palettes cannot resurrect dependencies after update or disposal', () {
    final bus = MonetPaintColors(
      theme(Colors.red),
      duration: duration,
      animateUnboundRoles: false,
    );
    addTearDown(bus.dispose);
    final binding = bus.bind('gold', gold);
    final saved = binding.value;
    binding.update(
      'blue',
      (data) => Palette.from(Colors.blue, backgroundTone: data.backgroundTone),
    );
    expect(saved.text, gold(bus.target).text);
    expect(bus.retainedRoleCount, 0);
    final beforeDispose = binding.value;
    binding.dispose();
    expect(beforeDispose.color, isA<Color>());
    expect(bus.retainedRoleCount, 0);
    expect(bus.retainedPaletteCount, 0);
  });

  test('a newly used state joins a shared track, or starts at the endpoint if unseen', () {
    final bus = MonetPaintColors(theme(Colors.red), animateUnboundRoles: false);
    addTearDown(bus.dispose);
    final a = bus.bindThemePalette(MonetPalette.primary);
    final b = bus.bindThemePalette(MonetPalette.primary);
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    final before = a.value.colorHovered;
    bus.retarget(theme(Colors.blue), time: 0, duration: duration);
    bus.sample(.05);
    expect(b.value.colorHovered, a.value.colorHovered);
    expect(b.value.colorHovered, isNot(before));
    expect(b.value.colorSplashed, bus.target.primary.colorSplashed);
    expect(bus.retainedRoleCount, 2);
    final discovered = b.value.colorSplashed;
    bus.retarget(theme(Colors.green), time: .05, duration: duration);
    expect(b.value.colorSplashed, discovered);
    bus.sample(.1);
    expect(b.value.colorSplashed, isNot(discovered));
  });

  test(
    'same-timestamp retarget reuses lazy decode and old frame stays frozen',
    () {
      final stats = PaintMotionStats();
      final bus = MonetPaintColors(theme(Colors.red), stats: stats);
      addTearDown(bus.dispose);
      bus.value.primary.color;
      bus.retarget(theme(Colors.blue), time: 0, duration: duration);
      bus.sample(.05);
      final old = bus.value.primary;
      final visible = old.color;
      final decoded = stats.interpolations;
      bus.retarget(theme(Colors.green), time: .05, duration: duration);
      expect(bus.value.primary.color, visible);
      expect(stats.interpolations, decoded);
      bus.sample(.1);
      expect(bus.value.primary.color, isNot(visible));
      expect(old.color, visible);
    },
  );

  test(
    'completion reaches observers without further reads or phantom tracks',
    () {
      final bus = MonetPaintColors(theme(Colors.red));
      final saved = bus.value;
      var completions = 0;
      bus.addListener(() {
        if (!bus.value.isAnimating) completions++;
      });
      bus.retarget(theme(Colors.blue), time: 0, duration: duration);
      expect(
        bus.isAnimating,
        true,
        reason: 'Material-anchor lifecycle without color demand',
      );
      bus.sample(2);
      bus.sample(3);
      expect(completions, 1);
      expect(bus.retainedRoleCount, 0);
      bus.dispose();
      expect(
        saved.primary.textSplashedText,
        saved.target.primary.textSplashedText,
      );
    },
  );

  test(
    'automatic paint demand matches manual prewarming work across retargets',
    () {
      final autoStats = PaintMotionStats(), manualStats = PaintMotionStats();
      final automatic = MonetPaintColors(
        theme(Colors.red),
        animateUnboundRoles: false,
        stats: autoStats,
      );
      final manual = MonetPaintColors(
        theme(Colors.red),
        animateUnboundRoles: false,
        stats: manualStats,
      );
      addTearDown(automatic.dispose);
      addTearDown(manual.dispose);
      final a = automatic.bindThemePalette(MonetPalette.primary);
      final b = manual.bindThemePalette(
        MonetPalette.primary,
        roles: const {PaletteRole.color, PaletteRole.text},
      );
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      expect(a.value.color, b.value.color);
      expect(a.value.text, b.value.text);
      for (var i = 0; i < 50; i++) {
        final time = i * .016;
        final next = theme([Colors.blue, Colors.red, Colors.green][i % 3]);
        for (final bus in [automatic, manual]) {
          bus.retarget(next, time: time, duration: duration);
          bus.sample(time + .008);
        }
        expect(a.value.color, b.value.color);
        expect(a.value.text, b.value.text);
        expect(autoStats.roleReads, manualStats.roleReads);
        expect(autoStats.interpolations, manualStats.interpolations);
        expect(automatic.retainedRoleCount, 2);
      }
    },
  );

  test(
    'basis swap preserves lazy historical frames and uses the new motion model',
    () {
      final bus = MonetPaintColors(theme(Colors.red));
      addTearDown(bus.dispose);
      final begin = bus.value.primary.color;
      bus.retarget(theme(Colors.blue), time: 0, duration: duration);
      bus.sample(.05);
      final historical = bus.value.primary;
      final next = theme(Colors.green, model: ColorModel.oklch);
      bus.retarget(
        next,
        time: .05,
        duration: duration,
        style: InterpolationStyle.polar,
      );
      final visible = bus.value.primary.color;
      expect(visible, isNot(begin));
      expect(
        historical.color,
        visible,
        reason: 'first old-frame read occurs after the basis changed',
      );
      expect(historical.colorModel, ColorModel.cam16);
      expect(bus.value.primary.colorModel, ColorModel.oklch);
      final custom = bus.bind(
        'default-model-endpoint',
        (_) => Palette.from(Colors.amber, backgroundTone: 67),
      );
      addTearDown(custom.dispose);
      expect(
        custom.value.colorModel,
        ColorModel.oklch,
        reason: 'view metadata follows the motion basis',
      );
      bus.sample(2);
      expect(bus.value.primary.color, next.primary.color);
      expect(historical.color, visible);
    },
  );

  for (final model in ColorModel.values) {
    for (final style in InterpolationStyle.values) {
      test(
        'lazy frames preserve moving histories and completion: $model $style',
        () {
          final lazyStats = PaintMotionStats(), paintStats = PaintMotionStats();
          final a = MonetPaintColors(
            theme(Colors.red, model: model),
            style: style,
            stats: lazyStats,
          );
          final b = MonetPaintColors(
            theme(Colors.red, model: model),
            style: style,
            stats: paintStats,
            animateUnboundRoles: false,
          );
          addTearDown(a.dispose);
          addTearDown(b.dispose);
          final paint = b.bindThemePalette(MonetPalette.primary);
          addTearDown(paint.dispose);
          expect(a.value.primary.color, paint.value.color);
          final historical = <(Palette, Color)>[];
          for (var target = 0; target < 20; target++) {
            final time = target * .08;
            final next = theme(
              [Colors.blue, Colors.orange, Colors.green][target % 3],
              model: model,
            );
            for (final bus in [a, b]) {
              bus.retarget(next, time: time, duration: duration, style: style);
            }
            for (var frame = 1; frame < 8; frame++) {
              final t = time + frame * .01;
              a.sample(t);
              b.sample(t);
              if (frame == 4) {
                // First read of this frozen lazy frame will occur AFTER retargets.
                historical.add((a.value.primary, paint.value.color));
              }
              if (frame == 7) expect(a.value.primary.color, paint.value.color);
            }
          }
          expect(lazyStats.interpolations, lessThan(paintStats.interpolations));
          for (var i = 0; i < 100; i++) {
            final time = 1.6 + i * .008;
            a.sample(time);
            b.sample(time);
            expect(
              a.isAnimating,
              b.isAnimating,
              reason: 'completion must not depend on getter frequency',
            );
          }
          expect(a.isAnimating, false);
          for (final (frame, expected) in historical) {
            expect(frame.color, expected);
          }
          expect(a.value.primary.color, b.target.primary.color);
          expect(a.retainedRoleCount, 1);
        },
      );
    }
  }
}
