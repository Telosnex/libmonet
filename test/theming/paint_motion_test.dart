import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/libmonet.dart';
import 'package:libmonet/theming/paint/palette_motion.dart';

const _duration = Duration(milliseconds: 160);

MonetThemeData _theme(double tone) => MonetThemeData.fromColors(
  brightness: Brightness.light,
  backgroundTone: tone,
  primary: const Color(0xffc3999a),
  secondary: const Color(0xffc1999e),
  tertiary: const Color(0xffc29994),
);
Palette _gold(MonetThemeData theme) =>
    Palette.from(const Color(0xfff5a623), backgroundTone: theme.backgroundTone);

class _ColorOnlyPalette extends RolePalette {
  const _ColorOnlyPalette() : super(ColorModel.cam16);
  @override
  Color readRole(PaletteRole role) => role == PaletteRole.color
      ? Colors.red
      : throw StateError('Unretained role $role');
}

void main() {
  testWidgets(
    'theme completes while a later custom recipe transition keeps ticking',
    (tester) async {
      final first = _theme(94),
          next = _theme(12).copyWith(brightness: Brightness.dark);
      late MonetPaintColors bus;
      late MonetThemeData inherited;
      late Brightness materialBrightness;
      var completions = 0;
      Widget tree(MonetThemeData data) => MaterialApp(
        home: AnimatedMonetTheme(
          data: data,
          duration: _duration,
          maxUpdatesPerSecond: 0,
          onEnd: () => completions++,
          child: Builder(
            builder: (context) {
              bus = MonetPaintColorsScope.of(context);
              inherited = MonetTheme.of(context).monetThemeData;
              materialBrightness = Theme.of(context).brightness;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpWidget(tree(first));
      final custom = bus.bind('gold', _gold, roles: const {PaletteRole.color});
      addTearDown(custom.dispose);
      await tester.pumpWidget(tree(next));
      await tester.pump(const Duration(milliseconds: 240));
      expect(completions, 0);
      custom.update(
        'blue',
        (data) =>
            Palette.from(Colors.blue, backgroundTone: data.backgroundTone),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(completions, 1);
      expect(inherited.target, next);
      expect(inherited.isAnimating, false);
      expect(materialBrightness, Brightness.dark);
      expect(bus.isAnimating, true);
      final intermediate = custom.value.color;
      expect(intermediate, isNot(Colors.blue));
      await tester.pump(const Duration(milliseconds: 40));
      expect(
        custom.value.color,
        isNot(intermediate),
        reason: 'semantic completion cannot stop local paint',
      );
      await tester.pumpAndSettle();
      expect(custom.value.color, Colors.blue);
      expect(completions, 1);
      expect(tester.hasRunningAnimations, false);
    },
  );

  testWidgets(
    'one completion per target, custom-only motion and same-target zero duration',
    (tester) async {
      final first = _theme(94);
      var target = first;
      var duration = _duration;
      var completions = 0;
      late StateSetter update;
      late MonetPaintColors bus;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return AnimatedMonetTheme(
                data: target,
                duration: duration,
                maxUpdatesPerSecond: 0,
                onEnd: () => completions++,
                child: Builder(
                  builder: (context) {
                    bus = MonetPaintColorsScope.of(context);
                    return const SizedBox();
                  },
                ),
              );
            },
          ),
        ),
      );
      final custom = bus.bind('gold', _gold);
      addTearDown(custom.dispose);
      expect(
        custom.value.text,
        _gold(first).text,
      ); // Discover the painted role.
      update(() => target = _theme(12));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 24));
      expect(bus.isAnimating, isTrue);
      update(() => duration = Duration.zero);
      await tester.pump();
      expect(bus.value.target, target);
      expect(bus.isAnimating, isFalse);
      expect(completions, 1);
      update(() => duration = _duration);
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      custom.update(
        'blue',
        (data) =>
            Palette.from(Colors.blue, backgroundTone: data.backgroundTone),
      );
      expect(bus.isAnimating, isTrue);
      await tester.pumpAndSettle();
      expect(bus.isAnimating, isFalse);
      expect(
        completions,
        1,
        reason: 'local binding changes are not new theme generations',
      );
      expect(tester.hasRunningAnimations, isFalse);
    },
  );

  test('prewarmed roles share work, release independently, and do not resolve again from getters', () {
    final stats = PaintMotionStats();
    final bus = MonetPaintColors(
      _theme(67),
      animateUnboundRoles: false,
      stats: stats,
    );
    addTearDown(bus.dispose);
    expect(bus.retainedRoleCount, 0);
    var resolves = 0;
    Palette resolve(MonetThemeData data) {
      resolves++;
      return _gold(data);
    }

    final first = bus.bind('gold', resolve, roles: const {PaletteRole.text});
    expect(stats.roleReads, 1);
    final second = bus.bind(
      'gold',
      resolve,
      roles: const {PaletteRole.text, PaletteRole.background},
    );
    expect(resolves, 1);
    expect(stats.roleReads, 2);
    expect(bus.retainedRoleCount, 2);
    final saved = first.value;
    expect(bus.retainedRoleCount, 2);
    final b = _theme(66.5);
    bus.retarget(b, time: 0, duration: _duration);
    expect(
      stats.roleReads,
      4,
      reason: 'only the union of two retained outputs',
    );
    bus.sample(0.04);
    final visible = first.value.text;
    final reads = stats.roleReads;
    final decoded = stats.interpolations;
    bus.sample(0.04);
    bus.retarget(b.copyWith(scale: 2), time: 0.04, duration: _duration);
    expect(
      stats.interpolations,
      decoded,
      reason: 'sample/retarget do not re-decode the same instant',
    );
    expect(first.value.text, visible);
    expect(saved.text, Colors.black);
    first.dispose();
    expect(bus.retainedRoleCount, 2, reason: 'other consumer retains text');
    second.update('gold', resolve, roles: const {PaletteRole.text});
    expect(bus.retainedRoleCount, 1);
    expect(
      second.value.text,
      visible,
      reason: 'role set change preserves existing motion',
    );
    expect(bus.retainedRoleCount, 1, reason: 'unread prewarm can be released');
    final readsAfterUpdate = stats.roleReads;
    expect(readsAfterUpdate, greaterThanOrEqualTo(reads));
    bus.sample(2);
    expect(second.value.text, Colors.white);
    expect(bus.isAnimating, isFalse);
    expect(
      stats.roleReads,
      readsAfterUpdate,
      reason: 'completion does not capture unused roles',
    );
    second.dispose();
    expect(bus.retainedRoleCount, 0);
    expect(bus.retainedPaletteCount, 0);
  });

  test(
    'retaining mid-flight joins existing roles, snaps only newly visible roles',
    () {
      final bus = MonetPaintColors(_theme(67), animateUnboundRoles: false);
      addTearDown(bus.dispose);
      final text = bus.bindThemePalette(
        MonetPalette.primary,
        roles: const {PaletteRole.text},
      );
      addTearDown(text.dispose);
      bus.retarget(_theme(10), time: 0, duration: _duration);
      bus.sample(0.04);
      final midText = text.value.text;
      final later = bus.bindThemePalette(
        MonetPalette.primary,
        roles: const {PaletteRole.text, PaletteRole.background},
      );
      expect(later.value.text, midText);
      expect(later.value.background, bus.target.primary.background);
      expect(bus.retainedRoleCount, 2);
      later.dispose();
      expect(bus.retainedRoleCount, 1);
      bus.sample(2);
      expect(text.value.text, bus.target.primary.text);
    },
  );

  test('recipe fork copies only owned roles; inherited reads share built-in tracks', () {
    final stats = PaintMotionStats();
    final first = _theme(67);
    final next = _theme(66.5);
    final bus = MonetPaintColors(
      first,
      animateUnboundRoles: false,
      stats: stats,
    );
    addTearDown(bus.dispose);
    final a = bus.bind('gold', _gold, roles: const {PaletteRole.text});
    final b = bus.bind('gold', _gold, roles: const {PaletteRole.background});
    bus.retarget(next, time: 0, duration: _duration);
    bus.sample(0.04);
    final saved = a.value.text;
    final reads = stats.roleReads;
    a.update(
      'new',
      (data) => Palette.from(Colors.blue, backgroundTone: data.backgroundTone),
    );
    expect(a.value.text, saved);
    expect(stats.roleReads - reads, 1);
    expect(
      bus.retainedRoleCount,
      2,
      reason: 'not a copy of the entire source union',
    );
    expect(bus.retainedRoleCount, 2);
    a.dispose();
    b.dispose();
    final builtin = bus.bindThemePalette(
      MonetPalette.primary,
      roles: const {PaletteRole.text},
    );
    bus.retarget(first, time: 0.04, duration: _duration);
    bus.sample(0.08);
    final beforeModeChange = builtin.value.text;
    bus.retarget(
      first,
      time: 0.08,
      duration: _duration,
      animateUnboundRoles: true,
    );
    expect(builtin.value.text, beforeModeChange);
    expect(bus.value.primary.text, beforeModeChange);
    expect(
      bus.retainedRoleCount,
      1,
      reason: 'inherited reads share the existing text track',
    );
    expect(bus.value.primary.background, first.primary.background);
    expect(
      bus.retainedRoleCount,
      2,
      reason: 'only the additional getter adds a role',
    );
    bus.retarget(
      first,
      time: 0.08,
      duration: _duration,
      animateUnboundRoles: false,
    );
    expect(builtin.value.text, beforeModeChange);
    expect(bus.retainedRoleCount, 1);
    bus.sample(2);
    expect(builtin.value.text, first.primary.text);
    builtin.dispose();
    expect(bus.retainedRoleCount, 0);
  });

  test('all 41 palette outputs survive snapshot and equality includes derived colors', () {
    final colors = [
      for (final role in PaletteRole.values)
        Color(0xff000000 + role.index * 357913),
    ];
    expect(colors.length, 41);
    final snapshot = ResolvedPalette(colors, ColorModel.cam16);
    for (final role in PaletteRole.values) {
      expect(role.read(snapshot), colors[role.index]);
    }
    final changed = colors.toList()..[PaletteRole.text.index] = Colors.white;
    expect(snapshot, isNot(ResolvedPalette(changed, ColorModel.cam16)));
    colors[0] = Colors.red;
    expect(snapshot.background, isNot(Colors.red));
  });

  test(
    'updated equal-key recipes preserve motion then share settled tracks',
    () {
      final stats = PaintMotionStats();
      final bus = MonetPaintColors(
        _theme(67),
        duration: _duration,
        animateUnboundRoles: false,
        stats: stats,
      );
      addTearDown(bus.dispose);
      Palette blue(MonetThemeData data) =>
          Palette.from(Colors.blue, backgroundTone: data.backgroundTone);
      final a = bus.bind('gold', _gold, roles: const {PaletteRole.color});
      final b = bus.bind(
        'blue',
        blue,
        roles: const {PaletteRole.color, PaletteRole.background},
      );
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      final before = a.value.color;
      final blueBefore = b.value;
      a.update('blue', blue);
      expect(
        a.value.color,
        before,
        reason: 'must not jump to the existing blue track',
      );
      expect(
        b.value,
        same(blueBefore),
        reason: 'other consumers keep their history',
      );
      expect(
        bus.retainedPaletteCount,
        2,
        reason: 'distinct histories while moving',
      );
      bus.sample(0.04);
      expect(a.value.color, isNot(before));
      expect(a.value.color, isNot(b.value.color));
      final reads = stats.roleReads;
      bus.sample(2);
      expect(a.value, b.value);
      expect(bus.retainedPaletteCount, 1);
      expect(bus.retainedRoleCount, 2);
      expect(
        stats.roleReads,
        reads,
        reason: 'coalescing must not resolve on a tick',
      );
      b.dispose();
      expect(bus.retainedRoleCount, 1);
      expect(bus.retainedRoleCount, 1);
      // A moved binding must also retain/release correctly on its next update.
      a.update('gold', _gold);
      bus.sample(4);
      expect(a.value.color, _gold(bus.target).color);
      a.dispose();
      expect(bus.retainedPaletteCount, 0);
      expect(bus.retainedRoleCount, 0);
    },
  );

  test(
    'coalescing unions disjoint roles and retains overlap reference counts',
    () {
      final stats = PaintMotionStats();
      final bus = MonetPaintColors(
        _theme(67),
        duration: _duration,
        animateUnboundRoles: false,
        stats: stats,
      );
      addTearDown(bus.dispose);
      Palette blue(MonetThemeData data) =>
          Palette.from(Colors.blue, backgroundTone: data.backgroundTone);
      final a = bus.bind('gold', _gold, roles: const {PaletteRole.color});
      final b = bus.bind('blue', blue, roles: const {PaletteRole.background});
      final c = bus.bind('gold', _gold, roles: const {PaletteRole.color});
      for (final binding in [a, b, c]) {
        addTearDown(binding.dispose);
      }
      a.update('blue', blue);
      c.update('blue', blue);
      expect(bus.retainedPaletteCount, 3);
      final reads = stats.roleReads;
      bus.sample(2);
      expect(stats.roleReads, reads);
      expect(bus.retainedPaletteCount, 1);
      expect(bus.retainedRoleCount, 2);
      expect(a.value, b.value);
      expect(a.value, c.value);
      a.dispose();
      expect(bus.retainedRoleCount, 2, reason: 'c still retains color');
      c.dispose();
      expect(bus.retainedRoleCount, 1);
      expect(bus.retainedRoleCount, 1);
      b.dispose();
      expect(bus.retainedRoleCount, 0);
    },
  );

  test('forking toward an existing moving recipe preserves the original trajectory', () {
    final bus = MonetPaintColors(
      _theme(67),
      duration: _duration,
      animateUnboundRoles: false,
    );
    final control = MonetPaintColors(
      _theme(67),
      duration: _duration,
      animateUnboundRoles: false,
    );
    addTearDown(bus.dispose);
    addTearDown(control.dispose);
    Palette blue(MonetThemeData data) =>
        Palette.from(Colors.blue, backgroundTone: data.backgroundTone);
    const roles = {PaletteRole.text, PaletteRole.background};
    final a = bus.bind('gold', _gold, roles: roles);
    final b = bus.bind('blue', blue, roles: roles);
    final c = control.bind('gold', _gold, roles: roles);
    for (final binding in [a, b, c]) {
      addTearDown(binding.dispose);
    }
    for (final owner in [bus, control]) {
      owner.retarget(_theme(12), time: 0, duration: _duration);
      owner.sample(0.04);
    }
    final before = a.value;
    final otherBefore = b.value;
    a.update('blue', blue);
    c.update('blue', blue);
    for (final role in roles) {
      expect(role.read(a.value), role.read(before));
      expect(role.read(b.value), role.read(otherBefore));
    }
    for (var frame = 1; frame < 10; frame++) {
      final time = 0.04 + frame * 0.008;
      bus.sample(time);
      control.sample(time);
      for (final role in roles) {
        expect(
          role.read(a.value),
          role.read(c.value),
          reason:
              'existing destination must not replace the rebased transition',
        );
      }
    }
    bus.sample(2);
    expect(a.value, b.value);
    expect(bus.retainedPaletteCount, 1);
    expect(bus.retainedRoleCount, roles.length);
  });

  test('zero-duration recipe update coalesces and defers notification', () {
    var requests = 0, notifications = 0;
    final bus = MonetPaintColors(
      _theme(67),
      animateUnboundRoles: false,
      requestFrame: () => requests++,
    );
    addTearDown(bus.dispose);
    Palette blue(MonetThemeData data) =>
        Palette.from(Colors.blue, backgroundTone: data.backgroundTone);
    final a = bus.bind('gold', _gold, roles: const {PaletteRole.color});
    final b = bus.bind('blue', blue, roles: const {PaletteRole.color});
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    a.addListener(() => notifications++);
    a.update('blue', blue);
    expect(a.value, b.value);
    expect(bus.retainedPaletteCount, 1);
    expect(bus.retainedRoleCount, 1);
    expect(bus.isAnimating, false);
    expect(
      notifications,
      0,
      reason: 'binding updates may run under the tree lock',
    );
    expect(requests, 1);
    bus.sample(0);
    expect(notifications, 1);
    bus.sample(0);
    expect(notifications, 1);
  });

  test('recipe and role update seeds new roles from the new endpoint only', () {
    final bus = MonetPaintColors(
      _theme(67),
      duration: _duration,
      animateUnboundRoles: false,
    );
    addTearDown(bus.dispose);
    final a = bus.bind(
      'partial',
      (_) => const _ColorOnlyPalette(),
      roles: const {PaletteRole.color},
    );
    addTearDown(a.dispose);
    a.update(
      'gold',
      _gold,
      roles: const {PaletteRole.color, PaletteRole.background},
    );
    expect(a.value.color, Colors.red);
    expect(
      a.value.background,
      _gold(bus.target).background,
      reason: 'never read an unretained background from the departed recipe',
    );
    bus.sample(2);
    expect(a.value.color, _gold(bus.target).color);
  });

  test('tiny theme change completes custom black/white motion, never resolves during ticks', () {
    final a = _theme(67);
    final b = _theme(66.5);
    final bus = MonetPaintColors(a);
    addTearDown(bus.dispose);
    var solves = 0;
    Palette resolve(MonetThemeData data) {
      solves++;
      return _gold(data);
    }

    final gold = bus.bind('gold', resolve);
    final shared = bus.bind('gold', resolve);
    addTearDown(gold.dispose);
    addTearDown(shared.dispose);
    expect(solves, 1);
    expect(bus.retainedPaletteCount, 1);
    expect(gold.value.text, Colors.black);
    bus.retarget(b, time: 0, duration: _duration);
    expect(solves, 2);
    final saved = gold.value;
    final tones = <double>[Hct.fromColor(saved.text).tone];
    for (var i = 1; i <= 100; i++) {
      bus.sample(i * 0.008);
      expect(shared.value, gold.value);
      tones.add(Hct.fromColor(gold.value.text).tone);
    }
    expect(solves, 2);
    expect(saved.text, Colors.black, reason: 'saved frames are immutable');
    expect(gold.value.text, Colors.white);
    expect(bus.value.target, b);
    expect(bus.isAnimating, isFalse);
    for (var i = 1; i < tones.length; i++) {
      expect((tones[i] - tones[i - 1]).abs(), lessThan(12));
    }
    final lastIntermediate = tones.lastWhere((t) => t != 100);
    expect(100 - lastIntermediate, lessThan(1));
  });

  test(
    'custom-only recipe change after idle notifies and forks shared motion',
    () {
      var now = 100.0;
      final bus = MonetPaintColors(
        _theme(67),
        duration: _duration,
        clock: () => now,
      );
      addTearDown(bus.dispose);
      final first = bus.bind('gold', _gold);
      final second = bus.bind('gold', _gold);
      expect(first.value.text, Colors.black);
      expect(second.value.text, Colors.black);
      var notifications = 0;
      first.addListener(() => notifications++);
      first.update(
        'white',
        (_) => Palette.from(Colors.white, backgroundTone: 10),
      );
      expect(first.value.text, Colors.black);
      expect(second.value.text, Colors.black);
      expect(bus.retainedPaletteCount, 2);
      now += 0.008;
      bus.sample(now);
      expect(notifications, 1);
      expect(first.value.text, isNot(Colors.white));
      expect(first.value.text, isNot(Colors.black));
      expect(second.value.text, Colors.black);
      bus.sample(now + 1);
      expect(bus.isAnimating, isFalse);
      first.dispose();
      second.dispose();
      for (var i = 0; i < 1000; i++) {
        bus.bind('churn$i', _gold).dispose();
      }
      expect(bus.retainedPaletteCount, 0);
    },
  );

  test(
    'model/style swap and zero-duration same-target update settle all roles',
    () {
      final bus = MonetPaintColors(_theme(94));
      addTearDown(bus.dispose);
      final binding = bus.bind('gold', _gold);
      addTearDown(binding.dispose);
      final next = _theme(12);
      bus.retarget(next, time: 0, duration: _duration);
      bus.sample(0.05);
      final visible = bus.value.primary.text;
      bus.retarget(
        next,
        time: 0.05,
        duration: _duration,
        style: InterpolationStyle.polar,
      );
      expect(bus.value.primary.text, visible);
      bus.retarget(next, time: 0.05, duration: Duration.zero);
      expect(bus.value.target, next);
      expect(binding.value.text, _gold(next).text);
      expect(bus.isAnimating, isFalse);
    },
  );

  test(
    'one RGB step crossing the foreground seam produces a complete fade',
    () {
      final a = _theme(67).copyWith(
        primary: Palette.fromColorAndBackground(
          const Color(0xffc3999a),
          const Color(0xffbb9c9e),
        ),
      );
      final b = a.copyWith(
        primary: Palette.fromColorAndBackground(
          const Color(0xffc3999a),
          const Color(0xffbb9b9e),
        ),
      );
      expect(a.primary.text, Colors.black);
      expect(b.primary.text, Colors.white);
      final bus = MonetPaintColors(a);
      addTearDown(bus.dispose);
      expect(bus.value.primary.text, Colors.black);
      bus.retarget(b, time: 0, duration: _duration);
      final tones = <double>[0];
      for (var i = 1; i <= 100; i++) {
        bus.sample(i * 0.008);
        tones.add(Hct.fromColor(bus.value.primary.text).tone);
      }
      expect(tones.last, 100);
      expect(tones.where((v) => v > 0 && v < 100).length, greaterThan(8));
      expect(
        [for (var i = 1; i < tones.length; i++) (tones[i] - tones[i - 1]).abs()]
            .reduce(math.max),
        lessThan(12),
      );
    },
  );
}
