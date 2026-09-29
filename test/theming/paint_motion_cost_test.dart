import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/libmonet.dart';
import 'package:libmonet/theming/paint/palette_motion.dart';

// A diagnostic workload, not a release frame-time benchmark. Time endpoint
// resolution separately from motion sampling; correctness guards are structural.
void main() {
  for (final mode in ['prewarm-all', 'prewarm-used', 'automatic']) {
    test('scroll-chase cost: $mode', () {
      final roles = switch (mode) {
        'prewarm-all' => PaletteRole.values.toSet(),
        'prewarm-used' => {PaletteRole.text, PaletteRole.background},
        _ => null,
      };
      final stats = PaintMotionStats();
      final targets = [
        for (var i = 0; i < 180; i++)
          MonetThemeData.fromColors(
            brightness: Brightness.light,
            backgroundTone: 60 + (i % 20) / 2,
            primary: Color(0xffaa3344 + i * 257),
            secondary: Colors.teal,
            tertiary: Colors.orange,
          ),
      ];
      final buses = [
        for (var i = 0; i < 8; i++)
          MonetPaintColors(
            targets[i],
            animateUnboundRoles: false,
            stats: stats,
          ),
      ];
      var solves = 0;
      final leases = <MonetPaletteBinding>[];
      for (final bus in buses) {
        for (final palette in MonetPalette.values) {
          leases.add(bus.bindThemePalette(palette, roles: roles));
        }
        for (var i = 0; i < 8; i++) {
          leases.add(
            bus.bind('custom${i % 2}', (data) {
              solves++;
              return Palette.from(
                i.isEven ? Colors.amber : Colors.red,
                backgroundTone: data.backgroundTone,
                contrast: data.contrast,
              );
            }, roles: roles),
          );
        }
        expect(bus.retainedPaletteCount, 2);
      }
      // Same actual rendering demand in every mode. Automatic retention must
      // discover the exact same union as the handwritten two-role prewarm.
      for (final lease in leases) {
        expect(lease.value.text, isA<Color>());
        expect(lease.value.background, isA<Color>());
      }
      final retargetTimes = <int>[];
      final tickTimes = <int>[];
      final clock = Stopwatch();
      for (var i = 1; i < targets.length - 8; i++) {
        final time = i * 0.016;
        clock
          ..reset()
          ..start();
        for (var j = 0; j < buses.length; j++) {
          buses[j].retarget(
            targets[i + j],
            time: time,
            duration: const Duration(milliseconds: 160),
          );
        }
        clock.stop();
        if (i > 20) retargetTimes.add(clock.elapsedMicroseconds);
        final before = solves;
        final reads = stats.roleReads;
        clock
          ..reset()
          ..start();
        for (final bus in buses) {
          bus.sample(time + 0.008);
        }
        for (final lease in leases) {
          lease.value.text;
          lease.value.background;
        }
        clock.stop();
        if (i > 20) tickTimes.add(clock.elapsedMicroseconds);
        expect(
          stats.roleReads,
          reads,
          reason: 'no palette output resolution on ticks',
        );
        final decoded = stats.interpolations;
        for (final bus in buses) {
          bus.sample(time + 0.008);
        }
        expect(
          stats.interpolations,
          decoded,
          reason: 'no repeated work at same timestamp',
        );
        expect(
          solves,
          before,
          reason: 'ordinary ticks cannot invoke endpoint solvers',
        );
      }
      for (final bus in buses) {
        expect(bus.retainedRoleCount, mode == 'prewarm-all' ? 205 : 10);
        bus.sample(100);
        expect(bus.isAnimating, isFalse);
      }
      for (final lease in leases) {
        lease.dispose();
      }
      for (final bus in buses) {
        expect(bus.retainedPaletteCount, 0);
        bus.dispose();
      }
      retargetTimes.sort();
      tickTimes.sort();
      // ignore: avoid_print
      print(
        'DEBUG/JIT 8 scopes, $mode, roles/scope=${mode == 'prewarm-all' ? 205 : 10}: '
        'retarget p50=${retargetTimes[retargetTimes.length ~/ 2]}us p95=${retargetTimes[(retargetTimes.length * .95).floor()]}us; '
        'sample p50=${tickTimes[tickTimes.length ~/ 2]}us p95=${tickTimes[(tickTimes.length * .95).floor()]}us',
      );
    });
  }
}
