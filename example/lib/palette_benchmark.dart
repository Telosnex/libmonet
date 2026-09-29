// Standalone performance harness, not a Studio feature or a release guarantee.
// See docs/design/palette-performance.md in the library root.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';
import 'package:libmonet/libmonet.dart';
import 'package:libmonet/theming/paint/palette_motion.dart'
    show PaintMotionStats;

const _mode =
    String.fromEnvironment('PALETTE_BENCH_MODE', defaultValue: 'local');
const _prewarmAll = bool.fromEnvironment('PALETTE_BENCH_PREWARM_ALL');
const _exit = bool.fromEnvironment('PALETTE_BENCH_EXIT');
const _warmup = 120;
const _frames = 720;
const _hint = Duration(milliseconds: 160);
final _roles = _prewarmAll
    ? PaletteRole.values.toSet()
    : {PaletteRole.color, PaletteRole.text};

void main() {
  if (!['local', 'scope', 'eagerScope'].contains(_mode)) {
    throw ArgumentError(
        'PALETTE_BENCH_MODE must be local, scope, or eagerScope');
  }
  runApp(const Directionality(
      textDirection: TextDirection.ltr, child: _Benchmark()));
}

MonetThemeData _theme(int i) => MonetThemeData.fromColors(
    brightness: Brightness.light,
    backgroundTone: 40 + (i % 110) / 2,
    primary: Color(0xff113355 + (i % 10000) * 83),
    secondary: Colors.teal,
    tertiary: Colors.orange);

class _Signal extends ChangeNotifier {
  void publish() => notifyListeners();
}

class _Benchmark extends StatefulWidget {
  const _Benchmark();
  @override
  State<_Benchmark> createState() => _BenchmarkState();
}

class _BenchmarkState extends State<_Benchmark>
    with SingleTickerProviderStateMixin {
  final _stats = PaintMotionStats();
  final _buses = <MonetPaintColors>[];
  final _bindings = <MonetPaletteBinding>[];
  final _representatives = <List<MonetPaletteBinding>>[];
  final _signals = <_Signal>[];
  final _previous = <List<Color>?>[];
  final _retargetUs = <int>[], _sampleUs = <int>[];
  final _timings = <FrameTiming>[];
  late final Ticker _ticker;
  var _frame = 0, _paints = 0, _notifications = 0;
  var _reported = false;

  @override
  void initState() {
    super.initState();
    for (var scope = 0; scope < 8; scope++) {
      final bus = MonetPaintColors(_theme(scope),
          duration: _hint, animateUnboundRoles: false, stats: _stats);
      _buses.add(bus);
      _signals.add(_Signal());
      _previous.add(null);
      final reps = <MonetPaletteBinding>[];
      for (var consumer = 0; consumer < 40; consumer++) {
        final moving = consumer < 10;
        final binding = moving
            ? bus.bindThemePalette(MonetPalette.primary, roles: _roles)
            : bus.bindRecipe(
                const ColorPaletteRecipe(Colors.grey, backgroundTone: 94),
                roles: _roles);
        _bindings.add(binding);
        if (consumer == 0 || consumer == 10) {
          reps.add(binding);
          // Comparison only: production deliberately has no scope paint bus.
          // One representative per distinct recipe avoids duplicate broadcasts.
          if (_mode == 'scope') binding.addListener(_signals.last.publish);
        }
        final Listenable signal = switch (_mode) {
          'local' => binding,
          _ => _signals.last,
        };
        signal.addListener(_countNotification);
      }
      _representatives.add(reps);
    }
    SchedulerBinding.instance.addTimingsCallback(_record);
    _ticker = createTicker(_tick)..start();
  }

  void _countNotification() {
    if (_frame > _warmup) _notifications++;
  }

  void _record(List<FrameTiming> timings) {
    if (_frame > _warmup && !_reported) _timings.addAll(timings);
  }

  void _tick(Duration elapsed) {
    _frame++;
    if (_frame == _warmup + 1) {
      _stats.interpolations = 0;
      _stats.roleReads = 0;
      _stats.bindingNotifications = 0;
    }
    if (_frame > _frames) {
      _ticker.stop();
      // Frame timings arrive batched. Let the final batch drain before reporting.
      Future<void>.delayed(const Duration(seconds: 1), _report);
      return;
    }
    // Same deterministic 120-Hz target trace on every display. Last 120 samples
    // are idle so redundant near-end invalidation is included in the comparison.
    final time = _frame / 120;
    final watch = Stopwatch()..start();
    if (_frame < _frames - 120) {
      for (var i = 0; i < _buses.length; i++) {
        _buses[i].retarget(_theme(_frame + i), time: time, duration: _hint);
      }
    }
    watch.stop();
    if (_frame > _warmup) _retargetUs.add(watch.elapsedMicroseconds);
    watch
      ..reset()
      ..start();
    for (var scope = 0; scope < _buses.length; scope++) {
      _buses[scope].sample(time + .004);
      if (_mode == 'eagerScope') {
        // Benchmark-only approximation of the former exact-RGB scope signal,
        // not a preserved production engine. Includes dormant retained roles.
        final colors = [
          for (final binding in _representatives[scope])
            for (final role in _roles) role.read(binding.value)
        ];
        if (!listEquals(colors, _previous[scope])) _signals[scope].publish();
        _previous[scope] = colors;
      }
    }
    watch.stop();
    if (_frame > _warmup) _sampleUs.add(watch.elapsedMicroseconds);
  }

  void _report() {
    if (!mounted) return;
    SchedulerBinding.instance.removeTimingsCallback(_record);
    _reported = true;
    Map<String, int> distribution(List<int> values) {
      values.sort();
      int p(double percentile) => values.isEmpty
          ? 0
          : values[((values.length - 1) * percentile).round()];
      return {
        'n': values.length,
        'p50_us': p(.5),
        'p95_us': p(.95),
        'p99_us': p(.99)
      };
    }

    // ignore: avoid_print
    print(jsonEncode({
      'benchmark': 'palette',
      'mode': _mode,
      'prewarmAll': _prewarmAll,
      'runtime': kReleaseMode
          ? 'release'
          : kProfileMode
              ? 'profile'
              : 'debug',
      'os': Platform.operatingSystem,
      'dart': Platform.version,
      'scopes': 8,
      'consumers': 320,
      'movingConsumers': 80,
      'retarget': distribution(_retargetUs),
      'sample': distribution(_sampleUs),
      'ui': distribution(
          _timings.map((t) => t.buildDuration.inMicroseconds).toList()),
      'raster': distribution(
          _timings.map((t) => t.rasterDuration.inMicroseconds).toList()),
      'paints': _paints,
      'notifications': _notifications,
      'interpolations': _stats.interpolations,
      'endpointRoleReads': _stats.roleReads,
      'rssBytes': ProcessInfo.currentRss,
      'maxRssBytes': ProcessInfo.maxRss,
    }));
    if (_exit) exit(0);
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
      color: Colors.white,
      child: Center(
          child: Wrap(spacing: 1, runSpacing: 1, children: [
        for (var i = 0; i < _bindings.length; i++)
          RepaintBoundary(
              child: CustomPaint(
            size: const Size(22, 22),
            painter: _Swatch(
                _bindings[i],
                switch (_mode) {
                  'local' => _bindings[i],
                  _ => _signals[i ~/ 40],
                }, () {
              if (_frame > _warmup) _paints++;
            }),
          )),
      ])));

  @override
  void dispose() {
    _ticker.dispose();
    SchedulerBinding.instance.removeTimingsCallback(_record);
    for (final binding in _bindings) {
      binding.dispose();
    }
    for (final bus in _buses) {
      bus.dispose();
    }
    for (final signal in _signals) {
      signal.dispose();
    }
    super.dispose();
  }
}

class _Swatch extends CustomPainter {
  _Swatch(this.binding, Listenable signal, this.onPaint)
      : super(repaint: signal);
  final MonetPaletteBinding binding;
  final VoidCallback onPaint;
  @override
  void paint(Canvas canvas, Size size) {
    onPaint();
    final p = binding.value;
    canvas.drawRect(Offset.zero & size, Paint()..color = p.color);
    canvas.drawCircle(size.center(Offset.zero), 4, Paint()..color = p.text);
  }

  @override
  bool shouldRepaint(covariant _Swatch oldDelegate) => false;
}
