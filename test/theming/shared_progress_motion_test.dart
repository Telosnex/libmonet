import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/libmonet.dart';
import 'package:libmonet/theming/paint/palette_motion.dart';
import 'package:libmonet/theming/paint/progress_motion.dart';

ResolvedPalette palette(Color color, ColorModel model) =>
    ResolvedPalette(List.filled(PaletteRole.values.length, color), model);

void main() {
  test('progress restarts at rest, is monotone, and settles without reads', () {
    final motion = ProgressMotion()..restart(0, 30);
    expect(motion.sample(0), 0);
    final mid = motion.sample(.05);
    expect(mid, greaterThan(0));
    motion.restart(.05, 30);
    expect(motion.sample(.05), 0);
    expect(motion.sample(.10), closeTo(mid, 1e-14));
    var previous = 0.0;
    for (var i = 0; i <= 100; i++) {
      final value = motion.sample(.05 + i * .01);
      expect(value, inInclusiveRange(previous, 1));
      previous = value;
    }
    expect(motion.sample(2), 1);
    motion.snap();
    expect(motion.sample(3), 1);
  });

  test('response hints retain their normalized progress and completion', () {
    for (final duration in [
      Duration.zero,
      const Duration(milliseconds: 160),
      const Duration(milliseconds: 320),
      const Duration(milliseconds: 640),
      const Duration(seconds: 30),
    ]) {
      final omega = paintMotionOmega(duration);
      final motion = ProgressMotion()..restart(0, omega);
      for (var i = 0; i <= 4000; i++) {
        final time = i / 1000;
        final decay = math.exp(-omega * time);
        final remaining = (1 + omega * time) * decay;
        final done =
            remaining <= .0001 && omega * omega * time * decay / 60 <= .0001;
        expect(motion.sample(time), done ? 1 : closeTo(1 - remaining, 1e-14));
      }
    }
  });

  test('releasing the only changing role stops progress with static roles retained', () {
    ResolvedPalette colors(Color text) => ResolvedPalette([
      for (final role in PaletteRole.values)
        role == PaletteRole.text ? text : Colors.black,
    ], ColorModel.cam16);
    final motion = PaletteMotion(
      colors(Colors.red),
      roles: const {PaletteRole.color, PaletteRole.text},
    );
    motion.retarget(colors(Colors.blue), 0, 30);
    motion.sample(.05);
    final saved = motion.frame;
    final savedText = saved.text;
    motion.setRoles(const {PaletteRole.color});
    expect(motion.isMoving, false);
    expect(motion.trackCount, 1);
    expect(motion.frame.color, Colors.black);
    // Role release must not mutate historical frames.
    expect(saved.text, savedText);
    motion.setRoles(const {PaletteRole.color, PaletteRole.text});
    expect(motion.frame.text, Colors.blue);
    expect(motion.isMoving, false, reason: 'new demand starts at the endpoint');
  });

  for (final model in ColorModel.values) {
    for (final style in InterpolationStyle.values) {
      test('all roles use shared progress including alpha: $model $style', () {
        final start = ResolvedPalette([
          for (final role in PaletteRole.values)
            Color(0x30123456 + role.index * 12937),
        ], model);
        final target = ResolvedPalette([
          for (final role in PaletteRole.values)
            Color(0xddcdffba - role.index * 17789),
        ], model);
        final motion = PaletteMotion(
          start,
          style: style,
          roles: PaletteRole.values.toSet(),
        );
        const omega = 35.0;
        motion.retarget(target, 0, omega);
        for (final time in [0.0, .008, .04, .08, .16]) {
          motion.sample(time);
          final t = 1 - (1 + omega * time) * math.exp(-omega * time);
          for (final role in PaletteRole.values) {
            final a = role.read(start), b = role.read(target);
            final expected = time == 0
                ? a
                : switch (style) {
                    InterpolationStyle.polar => Hct.lerpKeepHue(
                      a,
                      b,
                      t,
                      model: model,
                    ),
                    InterpolationStyle.cartesian => Hct.lerpLoseHueAndChroma(
                      a,
                      b,
                      t,
                      model: model,
                    ),
                  };
            expect(role.read(motion.frame), expected);
          }
        }
        motion.sample(2);
        expect(motion.isMoving, false);
        for (final role in PaletteRole.values) {
          expect(role.read(motion.frame), role.read(target));
        }
      });
    }
  }

  test(
    'equal targets do not restart and reversal uses visible RGB from rest',
    () {
      final start = palette(Colors.black, ColorModel.cam16);
      final target = palette(Colors.white, ColorModel.cam16);
      final a = PaletteMotion(start, roles: const {PaletteRole.text});
      final b = PaletteMotion(start, roles: const {PaletteRole.text});
      for (final motion in [a, b]) {
        motion.retarget(target, 0, 30);
        motion.sample(.06);
      }
      a.retarget(palette(Colors.white, ColorModel.cam16), .06, 30);
      a.sample(.08);
      b.sample(.08);
      expect(a.frame.text, b.frame.text);
      final visible = a.frame.text;
      a.retarget(start, .08, 30);
      expect(a.frame.text, visible);
      a.sample(.10);
      final t = 1 - (1 + 30 * .02) * math.exp(-30 * .02);
      expect(a.frame.text, Hct.lerpLoseHueAndChroma(visible, Colors.black, t));
    },
  );

  test(
    'completion does not depend on role count and release drops progress',
    () {
      final start = palette(Colors.black, ColorModel.cam16);
      final target = palette(Colors.white, ColorModel.cam16);
      final one = PaletteMotion(start, roles: const {PaletteRole.text});
      final all = PaletteMotion(start, roles: PaletteRole.values.toSet());
      one.retarget(target, 0, 30);
      all.retarget(target, 0, 30);
      for (var i = 0; i < 100; i++) {
        one.sample(i * .008);
        all.sample(i * .008);
        expect(one.isMoving, all.isMoving);
        expect(one.frame.text, all.frame.text);
      }
      all.retarget(start, 1, 30);
      all.setRoles(const {});
      expect(all.isMoving, false);
      expect(all.trackCount, 0);
    },
  );

  test(
    'semantic-only update does not restart shared progress or scalar values',
    () {
      final first = MonetThemeData.fromColors(
        brightness: Brightness.light,
        backgroundTone: 94,
        primary: Colors.blue,
        secondary: Colors.teal,
        tertiary: Colors.amber,
      );
      final next = first.copyWith(backgroundTone: 12, contrast: .7, scale: 2);
      final bus = MonetPaintColors(first);
      final control = MonetPaintColors(first);
      addTearDown(bus.dispose);
      addTearDown(control.dispose);
      for (final owner in [bus, control]) {
        owner.retarget(
          next,
          time: 0,
          duration: const Duration(milliseconds: 160),
        );
        owner.sample(.05);
      }
      final visible = bus.value.backgroundTone;
      bus.retarget(
        next.copyWith(brightness: Brightness.dark),
        time: .05,
        duration: const Duration(milliseconds: 160),
      );
      expect(bus.value.backgroundTone, visible);
      bus.sample(.10);
      control.sample(.10);
      expect(bus.value.backgroundTone, control.value.backgroundTone);
      expect(bus.value.contrast, control.value.contrast);
      expect(bus.value.scale, control.value.scale);
      bus.sample(2);
      expect(bus.value.brightness, Brightness.dark);
      expect(bus.value.backgroundTone, 12);
      expect(bus.value.contrast, .7);
      expect(bus.value.scale, 2);
    },
  );

  test('custom-only motion cannot delay semantic-only theme changes', () {
    final initial = MonetThemeData.fromColors(
      brightness: Brightness.light,
      backgroundTone: 94,
      primary: Colors.red,
      secondary: Colors.teal,
      tertiary: Colors.orange,
    );
    const duration = Duration(milliseconds: 160);
    final bus = MonetPaintColors(
      initial,
      duration: duration,
      animateUnboundRoles: false,
    );
    addTearDown(bus.dispose);
    final binding = bus.bind(
      'red',
      (_) => initial.primary,
      roles: const {PaletteRole.color},
    );
    addTearDown(binding.dispose);
    binding.update(
      'blue',
      (_) => Palette.from(Colors.blue, backgroundTone: 94),
    );
    bus.sample(.05);
    final before = binding.value.color;
    final next = initial.copyWith(
      brightness: Brightness.dark,
      typography: (scheme) => Typography.material2021(colorScheme: scheme),
    );
    bus.retarget(next, time: .05, duration: duration);
    expect(bus.value.brightness, Brightness.dark);
    expect(bus.value.typography, next.typography);
    expect(bus.value.isAnimating, false);
    expect(bus.isAnimating, true, reason: 'local colors still need the ticker');
    expect(
      binding.value.color,
      before,
      reason: 'semantic update cannot snap custom motion',
    );
    bus.sample(.1);
    expect(binding.value.color, isNot(before));
    bus.sample(2);
    expect(binding.value.color, Colors.blue);
    expect(bus.isAnimating, false);
  });
}
