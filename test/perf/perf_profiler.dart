// ignore_for_file: avoid_print, sdk_version_since

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate' as isolate;

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// Connects to the VM service running in *this* process and collects CPU
/// profiling samples around a user-supplied block.
///
/// Requires `--enable-vm-service` when launching:
/// ```bash
/// dart run --enable-vm-service test/perf/some_perf_test.dart
/// ```
///
/// If the VM service isn't available (e.g. normal `dart run` without the
/// flag), [connect] returns `false` and the other methods are no-ops.
class PerfProfiler {
  VmService? _service;
  String? _isolateId;

  /// Try to connect to the VM service. Returns `true` on success.
  Future<bool> connect() async {
    try {
      // getInfo() reads existing state without blocking (controlWebServer
      // hangs in the Flutter tester even with --enable-vmservice).
      print('[PerfProfiler] Calling Service.getInfo()...');
      final info = await developer.Service.getInfo();
      print('[PerfProfiler] getInfo returned: ${info.serverUri}');
      final uri = info.serverUri;
      if (uri == null) {
        print(
          '[PerfProfiler] VM service not available. '
          'Run with: dart run --enable-vm-service <script>',
        );
        return false;
      }

      // Convert HTTP URI to WebSocket URI.
      final wsUri = uri.replace(
        scheme: uri.scheme == 'https' ? 'wss' : 'ws',
        path: '${uri.path}ws',
      );

      _service = await vmServiceConnectUri(wsUri.toString()).timeout(
        const Duration(seconds: 5),
        onTimeout: () =>
            throw TimeoutException('VM service connection timed out after 5s'),
      );

      // Enable the profiler.
      await _service!.setFlag('profiler', 'true');

      // Get our own isolate ID.
      _isolateId = developer.Service.getIsolateId(isolate.Isolate.current);
      if (_isolateId == null) {
        print('[PerfProfiler] Could not determine isolate ID.');
        await _service?.dispose();
        _service = null;
        return false;
      }

      return true;
    } catch (e) {
      print('[PerfProfiler] Failed to connect: $e');
      return false;
    }
  }

  /// Clear previously collected CPU samples so the next [collectProfile]
  /// only sees samples from the benchmark region.
  Future<void> clearSamples() async {
    if (_service == null || _isolateId == null) return;
    await _service!.clearCpuSamples(_isolateId!);
  }

  /// Collect CPU samples and print the top-N hottest functions.
  Future<void> collectAndPrint({
    int topN = 20,
    String? label,
    String? dumpPath,
  }) async {
    if (_service == null || _isolateId == null) return;

    final cpuSamples = await _service!.getCpuSamples(_isolateId!, 0, ~0);
    final functions = cpuSamples.functions ?? [];
    final samples = cpuSamples.samples ?? [];

    if (samples.isEmpty) {
      print('\n[PerfProfiler] No CPU samples collected.');
      return;
    }

    if (dumpPath != null) {
      final file = File(dumpPath);
      await file.parent.create(recursive: true);
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(cpuSamples.toJson()));
      print('[PerfProfiler] Wrote raw CPU samples to ${file.path}');
    }

    // Sort by exclusive ticks (self time) descending.
    final sorted = List.of(
      functions,
    )..sort((a, b) => (b.exclusiveTicks ?? 0).compareTo(a.exclusiveTicks ?? 0));

    final totalSamples = cpuSamples.sampleCount ?? samples.length;
    final period = cpuSamples.samplePeriod ?? 0; // microseconds

    final title = label != null
        ? 'CPU Profile: $label  ($totalSamples samples, $periodµs)'
        : 'CPU Profile  ($totalSamples samples, $periodµs)';
    final boxWidth = title.length + 4;
    print('');
    print('      ┌${'─' * boxWidth}┐');
    print('      │  $title  │');
    print('      └${'─' * boxWidth}┘');
    print(
      '      Self% = time in function itself.  '
      'Incl% = time in function + everything it calls.',
    );
    print(
      '      [Stub] = compiler-generated helpers '
      '(type checks, allocation, etc.).',
    );
    print('');
    print(
      '      ${'Self%'.padRight(8)}'
      '${'Incl%'.padRight(8)}'
      '${'Self'.padRight(8)}'
      '${'Incl'.padRight(8)}'
      'Function',
    );
    print('      ${'─' * 8}${'─' * 8}${'─' * 8}${'─' * 8}${'─' * 40}');

    var printed = 0;
    for (final pf in sorted) {
      if (printed >= topN) break;
      final excl = pf.exclusiveTicks ?? 0;
      final incl = pf.inclusiveTicks ?? 0;
      if (excl == 0 && incl == 0) continue;

      final exclPct = (excl / totalSamples * 100).toStringAsFixed(1);
      final inclPct = (incl / totalSamples * 100).toStringAsFixed(1);

      // Extract a readable function name.
      final funcName = _functionName(pf);
      final url = pf.resolvedUrl ?? '';
      // Shorten the URL to just the filename.
      final shortUrl = url.contains('/') ? url.split('/').last : url;

      print(
        '      ${exclPct.padLeft(5)}%  '
        '${inclPct.padLeft(5)}%  '
        '${excl.toString().padLeft(6)}  '
        '${incl.toString().padLeft(6)}  '
        '$funcName ($shortUrl)',
      );
      printed++;
    }
  }

  /// Disconnect from the VM service.
  Future<void> dispose() async {
    await _service?.dispose();
    _service = null;
  }

  String _functionName(ProfileFunction pf) {
    final func = pf.function;
    if (func is FuncRef) {
      final owner = func.owner;
      if (owner is ClassRef) {
        return '${owner.name}.${func.name}';
      }
      return func.name ?? '?';
    }
    if (func is NativeFunction) {
      return func.name ?? '[native]';
    }
    // Fallback: try .name via dynamic, else toString.
    try {
      return (func as dynamic).name as String;
    } catch (_) {
      return func.toString();
    }
  }
}
