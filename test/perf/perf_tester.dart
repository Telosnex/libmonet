// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'perf_profiler.dart';

/// Small utility for comparing two implementations on the same inputs.
///
/// It verifies output parity first, then runs a warmup phase and a benchmark
/// phase, finally printing a human-readable summary of the results.
///
/// ## Testing after you've already edited the file
///
/// The most common scenario: you've already changed a method and want to
/// benchmark old vs new. The old code lives in `git diff` — here's how to
/// recover it.
///
/// 1. **Extract the old version** next to the current one:
///    ```bash
///    # Dump the committed (pre-edit) file:
///    git show HEAD:lib/path/to/foo.dart > test/perf/foo_old.dart
///    ```
///    Then trim it to just the function(s) you care about. Remove
///    framework imports that won't resolve in a plain `dart run` context.
///
/// 2. **Extract the new version** the same way — copy the function(s) from
///    the working-tree file into `test/perf/foo_new.dart`.
///
///    Why copy both instead of importing the real file? If the real file
///    has framework imports (Flutter, provider, etc.) and you want to run
///    outside Flutter, standalone copies keep the test runnable with
///    `dart run`. If you're fine using `flutter test`, you can import
///    the real file directly.
///
/// 3. **Make private methods public** in the copies. The copies are
///    throwaway test scaffolding — visibility doesn't matter.
///
/// 4. **Import with prefixes** in your perf test:
///    ```dart
///    import 'foo_old.dart' as old;
///    import 'foo_new.dart' as current;
///    ```
///
/// 5. **Wire into PerfTester** as `implementation1` (old) and
///    `implementation2` (new).
///
/// 6. **Run:**
///    ```bash
///    # Pure Dart:
///    dart run test/perf/foo_perf_test.dart
///
///    # Flutter (code imports flutter packages):
///    flutter test test/perf/foo_perf_test.dart
///
///    # Flutter + CPU profiling:
///    flutter test --enable-vmservice --no-dds test/perf/foo_perf_test.dart
///    ```
class PerfTester<Input, Output> {
  /// A short label used in the benchmark output.
  final String testName;

  /// Inputs that will be fed to both implementations.
  final List<Input> testCases;

  /// The baseline implementation being measured.
  final FutureOr<Output?> Function(Input) implementation1;

  /// The candidate implementation being measured.
  final FutureOr<Output?> Function(Input) implementation2;

  /// Display name for [implementation1].
  final String impl1Name;

  /// Display name for [implementation2].
  final String impl2Name;

  /// Optional custom equality check for result comparison.
  final bool Function(Output?, Output?)? equalityCheck;

  /// Stable RNG used to select warmup inputs reproducibly.
  final _random = math.Random(42);

  /// Measured runtime samples for [implementation1], in milliseconds.
  final List<double> impl1Times = [];

  /// Measured runtime samples for [implementation2], in milliseconds.
  final List<double> impl2Times = [];

  PerfTester({
    required this.testName,
    required this.testCases,
    required this.implementation1,
    required this.implementation2,
    this.impl1Name = 'Original',
    this.impl2Name = 'Optimized',
    this.equalityCheck,
  });

  // ── Output helpers ──────────────────────────────────────────────────

  static const _ruleDouble =
      '══════════════════════════════════════════════════════';
  static const _ruleSingle =
      '──────────────────────────────────────────────────────';

  void _header(String title) {
    print('');
    print(_ruleDouble);
    print(' PerfTester: $title');
    print(_ruleDouble);
  }

  void _step(int n, int total, String msg) {
    print('');
    print('[$n/$total] $msg');
  }

  void _sub(String msg) => print('      $msg');

  // ── Public entry point ──────────────────────────────────────────────

  /// Runs the full comparison flow.
  ///
  /// The default flow is: verify outputs, warm up both implementations, then
  /// benchmark them and print a summary.
  ///
  /// ## CPU profiling
  ///
  /// Set [profile] to `true` to collect a CPU sample profile during the
  /// benchmark phase and print the top-N hottest functions afterward.
  ///
  /// ### Pure Dart tests
  ///
  /// ```bash
  /// dart run --enable-vm-service test/perf/some_perf_test.dart
  /// ```
  ///
  /// ### Flutter tests (code depends on Flutter)
  ///
  /// Flutter tests need two extra flags and one code change:
  ///
  /// ```bash
  /// flutter test --enable-vmservice --no-dds test/perf/some_perf_test.dart
  /// ```
  ///
  /// Why both flags:
  /// - `--enable-vmservice` starts the VM service (off by default in tests).
  /// - `--no-dds` disables the Dart Development Service, which otherwise
  ///   puts the VM service in single-client mode and silently drops our
  ///   WebSocket connection (causing an infinite hang).
  ///
  /// In your test, pass `tester.runAsync` to escape the fake async zone
  /// that Flutter's test framework uses. Without it, the VM service
  /// WebSocket connection (real I/O) never completes:
  ///
  /// ```dart
  /// testWidgets('perf', (tester) async {
  ///   await myTester.run(
  ///     profile: true,
  ///     runAsync: tester.runAsync,
  ///   );
  /// });
  /// ```
  ///
  /// Without the VM service flags, profiling is silently skipped and the
  /// benchmark runs normally.
  Future<void> run({
    int warmupRuns = 100,
    int benchmarkRuns = 100,
    bool skipEqualityCheck = false,
    bool profile = false,
    int profileTopN = 50,
    int profileRuns = 100,

    /// Pass `tester.runAsync` when running inside a Flutter widget test.
    /// Real I/O (VM service connection) needs to escape the fake async zone.
    Future<T?> Function<T>(
      Future<T> Function() callback, {
      Duration additionalTime,
    })?
    runAsync,
  }) async {
    final totalSteps = 2 + (skipEqualityCheck ? 0 : 1) + (profile ? 1 : 0);
    var step = 0;

    _header(testName);
    final steps = [
      if (!skipEqualityCheck) 'Verify',
      'Warmup',
      'Benchmark',
      if (profile) 'Profile (×2)',
    ];
    print(' Steps: ${steps.join(' → ')}');
    print(_ruleSingle);

    // ── Verify ──
    if (!skipEqualityCheck) {
      step++;
      _step(
        step,
        totalSteps,
        'Verify: checking $impl1Name vs $impl2Name produce identical output...',
      );
      await _verifyImplementations();
    }

    // ── Warmup ──
    step++;
    _step(
      step,
      totalSteps,
      'Warmup: $warmupRuns randomly selected test case${warmupRuns == 1 ? '' : 's'}...',
    );
    await _warmup(warmupRuns);

    // ── Benchmark ──
    step++;
    _step(
      step,
      totalSteps,
      'Benchmark: $benchmarkRuns run${benchmarkRuns == 1 ? '' : 's'}, ${testCases.length} test case${testCases.length == 1 ? '' : 's'} each...',
    );
    await _benchmark(benchmarkRuns);
    _printResults();

    // ── Profile ──
    if (profile) {
      step++;

      Future<void> doProfile() async {
        final profiler = PerfProfiler();
        final connected = await profiler.connect();
        if (connected) {
          _step(
            step,
            totalSteps,
            'Profile: running each implementation separately...',
          );
          for (final (name, impl) in [
            (impl1Name, implementation1),
            (impl2Name, implementation2),
          ]) {
            await profiler.clearSamples();
            // Detect sync vs async: try one call.
            final probe = impl(testCases.first);
            if (probe is Future) await probe;
            final isSync = probe is! Future;
            for (int r = 0; r < profileRuns; r++) {
              if (isSync) {
                // Tight sync loop — no await/Future/microtask overhead.
                for (final input in testCases) {
                  impl(input);
                }
              } else {
                for (final input in testCases) {
                  await _invoke(impl, input);
                }
              }
            }
            await profiler.collectAndPrint(topN: profileTopN, label: name);
          }
          await profiler.dispose();
        } else {
          _step(
            step,
            totalSteps,
            'Profile: skipped (VM service not available).',
          );
        }
      }

      // Real I/O (VM service websocket) must run outside the fake async zone.
      if (runAsync != null) {
        await runAsync(doProfile);
      } else {
        await doProfile();
      }
    }
  }

  // ── Verify ────────────────────────────────────────────────────────────

  /// Executes both implementations for every test case and checks that the
  /// outputs match.
  Future<void> _verifyImplementations() async {
    var allEqual = true;

    for (var i = 0; i < testCases.length; i++) {
      final input = testCases[i];
      final result1 = await _invoke(implementation1, input);
      final result2 = await _invoke(implementation2, input);

      final encoded1 = _safeEncode(result1);
      final encoded2 = _safeEncode(result2);
      final isEqual = equalityCheck != null
          ? equalityCheck!(result1, result2)
          : encoded1 == encoded2;

      if (!isEqual) {
        _sub('❌ Mismatch on test case $i:');
        _sub('Input: $input');

        if (encoded1.length > 1000 || encoded2.length > 1000) {
          _printStringDiff(
            encoded1,
            encoded2,
            labelA: impl1Name,
            labelB: impl2Name,
          );
        } else {
          _sub('$impl1Name: $encoded1');
          _sub('$impl2Name: $encoded2');
        }
        allEqual = false;
      }
    }

    if (allEqual) {
      _sub(
        '✅ All ${testCases.length} test case${testCases.length == 1 ? '' : 's'} match.',
      );
    } else {
      _sub('❌ Differences found in outputs!');
    }
  }

  // ── Warmup ────────────────────────────────────────────────────────────

  /// Performs a short warmup using random test cases to reduce cold-start
  /// effects before the timed benchmark begins.
  Future<void> _warmup(int runs) async {
    final sw = Stopwatch()..start();
    for (var i = 0; i < runs; i++) {
      final input = testCases[_random.nextInt(testCases.length)];
      await _invoke(implementation1, input);
      await _invoke(implementation2, input);
    }
    sw.stop();
    _sub('Done (${sw.elapsedMilliseconds} ms).');
  }

  // ── Benchmark ─────────────────────────────────────────────────────────

  /// Measures both implementations across the full test suite.
  ///
  /// The order alternates each run to reduce bias from cache or VM effects.
  Future<void> _benchmark(int runs) async {
    // Detect sync implementations to avoid await overhead in hot loop.
    final probe1 = implementation1(testCases.first);
    if (probe1 is Future) await probe1;
    final probe2 = implementation2(testCases.first);
    if (probe2 is Future) await probe2;
    final isSync = probe1 is! Future && probe2 is! Future;

    for (var run = 0; run < runs; run++) {
      final runIterationSw = Stopwatch()..start();

      var testA = run % 2 == 0;

      // First run
      final impl1st = testA ? implementation1 : implementation2;
      final stopwatch1 = Stopwatch()..start();
      if (isSync) {
        for (var input in testCases) {
          impl1st(input);
        }
      } else {
        for (var input in testCases) {
          await _invoke(impl1st, input);
        }
      }
      stopwatch1.stop();
      var time1 = stopwatch1.elapsedMicroseconds / 1000.0;

      // Second run
      final impl2nd = testA ? implementation2 : implementation1;
      final stopwatch2 = Stopwatch()..start();
      if (isSync) {
        for (var input in testCases) {
          impl2nd(input);
        }
      } else {
        for (var input in testCases) {
          await _invoke(impl2nd, input);
        }
      }
      stopwatch2.stop();
      var time2 = stopwatch2.elapsedMicroseconds / 1000.0;

      // Store results
      if (testA) {
        impl1Times.add(time1);
        impl2Times.add(time2);
      } else {
        impl2Times.add(time1);
        impl1Times.add(time2);
      }
      runIterationSw.stop();
      // Print at most 10 progress messages.
      final printStep = math.max(1, runs ~/ 10);
      if ((run + 1) % printStep == 0 || run == runs - 1) {
        _sub(
          'Run ${run + 1}/$runs (${runIterationSw.elapsedMilliseconds} ms).',
        );
      }
    }
  }

  Future<Output?> _invoke(
    FutureOr<Output?> Function(Input) implementation,
    Input input,
  ) async {
    final result = implementation(input);
    if (result is Future<Output?>) {
      return await result;
    }
    return result;
  }

  // ── Results ───────────────────────────────────────────────────────────

  /// Prints the final timing summary and a distribution view.
  void _printResults() {
    _printStats();
    _printVisualizations();
  }

  /// Prints aggregate statistics such as total time, mean, median, and
  /// standard deviation.
  void _printStats() {
    impl1Times.sort();
    impl2Times.sort();

    double mean(List<double> list) =>
        list.reduce((a, b) => a + b) / list.length;
    double median(List<double> list) => list.length.isOdd
        ? list[list.length ~/ 2]
        : (list[list.length ~/ 2 - 1] + list[list.length ~/ 2]) / 2;
    double stdDev(List<double> list, double mean) {
      var squaredDiffs = list.map((x) => math.pow(x - mean, 2));
      return math.sqrt(
        squaredDiffs.reduce((a, b) => a + b) / (list.length - 1),
      );
    }

    var impl1Mean = mean(impl1Times);
    var impl2Mean = mean(impl2Times);

    // Calculate totals and ops/sec
    var impl1Total = impl1Times.reduce((a, b) => a + b);
    var impl2Total = impl2Times.reduce((a, b) => a + b);
    var totalOps = impl1Times.length * testCases.length;
    var impl1OpsPerSec = (totalOps / impl1Total) * 1000;
    var impl2OpsPerSec = (totalOps / impl2Total) * 1000;

    // Calculate maximum widths based on actual data
    var allValues = {
      'Total Time': [impl1Total, impl2Total],
      'Ops/Second': [impl1OpsPerSec, impl2OpsPerSec],
      'Min': [impl1Times.first, impl2Times.first],
      'Max': [impl1Times.last, impl2Times.last],
      'Median': [median(impl1Times), median(impl2Times)],
      'Mean': [impl1Mean, impl2Mean],
      'Std Dev': [stdDev(impl1Times, impl1Mean), stdDev(impl2Times, impl2Mean)],
    };

    // Find maximum width needed for labels
    var maxLabelWidth =
        allValues.keys.map((label) => '$label (ms):'.length).reduce(math.max) +
        2;

    // Find maximum width needed for each column's values
    var maxWidth1 = math.max(
      impl2Name.length,
      allValues.values
          .map(
            (vals) => vals[1]
                .toStringAsFixed(
                  vals[1] >= 1000
                      ? 0
                      : vals[1] >= 100
                      ? 1
                      : 3,
                )
                .length,
          )
          .reduce(math.max),
    );

    var maxWidth2 = math.max(
      impl1Name.length,
      allValues.values
          .map(
            (vals) => vals[0]
                .toStringAsFixed(
                  vals[0] >= 1000
                      ? 0
                      : vals[0] >= 100
                      ? 1
                      : 3,
                )
                .length,
          )
          .reduce(math.max),
    );

    // Add padding
    maxWidth1 += 2;
    maxWidth2 += 2;

    print('');
    _sub('Results:');

    // Print header
    _sub(
      '${''.padRight(maxLabelWidth)}'
      '${impl2Name.padRight(maxWidth1)}'
      '${impl1Name.padRight(maxWidth2)}'
      'Comparison',
    );

    // Helper function to format numbers intelligently
    String formatNumber(double value) {
      if (value >= 1000000) {
        return '${(value / 1000000).toStringAsFixed(2)}M';
      } else if (value >= 1000) {
        return '${(value / 1000).toStringAsFixed(2)}K';
      } else if (value >= 100) {
        return value.toStringAsFixed(1);
      } else if (value >= 10) {
        return value.toStringAsFixed(2);
      } else {
        return value.toStringAsFixed(3);
      }
    }

    // Helper function to format a row with improvement percentage and speedup factor
    void printRow(
      String label,
      double val1,
      double val2, {
      bool formatLarge = false,
      bool higherIsBetter = false,
    }) {
      var formattedVal1 = formatLarge
          ? formatNumber(val1)
          : val1.toStringAsFixed(3);
      var formattedVal2 = formatLarge
          ? formatNumber(val2)
          : val2.toStringAsFixed(3);

      // Calculate improvement and speedup
      var improvement = ((val2 - val1) / val2 * 100);
      var speedupFactor = val2 / val1;

      // For metrics where higher is better (like Ops/Second), invert the comparison
      if (higherIsBetter) {
        improvement = -improvement;
        speedupFactor = 1 / speedupFactor;
      }

      // Format the comparison info
      String comparisonInfo;
      if (improvement > 0) {
        // Handle infinity cases
        String speedupStr = speedupFactor.isInfinite
            ? 'Infinity'
            : speedupFactor.toStringAsFixed(1);

        comparisonInfo =
            '↑${improvement.toStringAsFixed(1)}% (${speedupStr}x faster)';
      } else if (improvement < 0) {
        comparisonInfo =
            '↓${(-improvement).toStringAsFixed(1)}% (${(1 / speedupFactor).toStringAsFixed(1)}x slower)';
      } else {
        comparisonInfo = 'No difference';
      }

      _sub(
        '${label.padRight(maxLabelWidth)}'
        '${formattedVal1.padRight(maxWidth1)}'
        '${formattedVal2.padRight(maxWidth2)}'
        '$comparisonInfo',
      );
    }

    // Print each row with consistent formatting
    printRow('Total Time (ms):', impl2Total, impl1Total);
    printRow(
      'Ops/Second:',
      impl2OpsPerSec,
      impl1OpsPerSec,
      formatLarge: true,
      higherIsBetter: true,
    );
    printRow('Min (ms):', impl2Times.first, impl1Times.first);
    printRow('Max (ms):', impl2Times.last, impl1Times.last);
    printRow('Median (ms):', median(impl2Times), median(impl1Times));
    printRow('Mean (ms):', impl2Mean, impl1Mean);
    printRow(
      'Std Dev (ms):',
      stdDev(impl2Times, impl2Mean),
      stdDev(impl1Times, impl1Mean),
    );
  }

  /// Builds a compact ASCII histogram for the two timing distributions.
  String _generateDistributionPair(
    List<double> data1,
    List<double> data2, {
    String label1 = 'Data 1',
    String label2 = 'Data 2',
  }) {
    if (data1.isEmpty || data2.isEmpty) return '';

    // Calculate full ranges and percentiles
    var sorted1 = List.of(data1)..sort();
    var sorted2 = List.of(data2)..sort();

    var min1 = sorted1.first;
    var min2 = sorted2.first;
    var max1 = sorted1.last;
    var max2 = sorted2.last;

    // Use p99 for visualization range
    var p99_1 = sorted1[(data1.length * 0.99).floor()];
    var p99_2 = sorted2[(data2.length * 0.99).floor()];
    var visMax = math.min(math.max(p99_1, p99_2) * 1.2, math.max(max1, max2));
    var visMin = math.min(min1, min2);

    // Create histograms
    var binCount = 30;
    var binSize = (visMax - visMin) / binCount;
    var histogram1 = List.filled(binCount, 0);
    var histogram2 = List.filled(binCount, 0);
    var outliers1 = 0;
    var outliers2 = 0;

    for (var value in data1) {
      if (value > visMax) {
        outliers1++;
        continue;
      }
      var bin = ((value - visMin) / binSize).floor();
      bin = math.min(math.max(bin, 0), binCount - 1);
      histogram1[bin]++;
    }
    for (var value in data2) {
      if (value > visMax) {
        outliers2++;
        continue;
      }
      var bin = ((value - visMin) / binSize).floor();
      bin = math.min(math.max(bin, 0), binCount - 1);
      histogram2[bin]++;
    }

    var maxCount = math.max(
      histogram1.reduce(math.max),
      histogram2.reduce(math.max),
    );

    String formatValue(double val) {
      if (val < 0.001) return val.toStringAsFixed(6);
      if (val < 0.01) return val.toStringAsFixed(4);
      if (val < 0.1) return val.toStringAsFixed(3);
      if (val < 1) return val.toStringAsFixed(2);
      return val.toStringAsFixed(1);
    }

    String getDistributionLine(
      List<int> hist,
      String label,
      int outlierCount,
      double min,
      double max,
    ) {
      var line = StringBuffer();
      line.write('${label.padRight(15)}│');

      // Use square root scaling for better visibility
      for (var count in hist) {
        var heightRatio = count == 0
            ? 0
            : math.sqrt(count) / math.sqrt(maxCount);
        var height = (heightRatio * 8).round();
        var char = switch (height) {
          0 => ' ',
          1 => '▁',
          2 => '▂',
          3 => '▃',
          4 => '▄',
          5 => '▅',
          6 => '▆',
          7 => '▇',
          _ => '█',
        };
        line.write(char);
      }
      line.write('│');

      // Add statistics
      line.write(' n=${hist.reduce((a, b) => a + b)}');
      if (outlierCount > 0) line.write(' (+$outlierCount)');
      line.write(' [${formatValue(min)}-${formatValue(max)}ms]');

      return line.toString();
    }

    var result = StringBuffer();
    result.writeln(
      '      Distribution (showing ${formatValue(visMin)}-${formatValue(visMax)}ms):',
    );
    result.writeln(
      '      ${getDistributionLine(histogram1, label1, outliers1, min1, max1)}',
    );
    result.write(
      '      ${getDistributionLine(histogram2, label2, outliers2, min2, max2)}',
    );

    return result.toString();
  }

  /// Prints the histogram-style timing visualization.
  void _printVisualizations() {
    print('');
    print(
      _generateDistributionPair(
        impl1Times,
        impl2Times,
        label1: impl1Name,
        label2: impl2Name,
      ),
    );
  }
}

/// Encodes a value for comparison, falling back to `toString()` if JSON
/// encoding is not possible.
String _safeEncode(Object? value) {
  try {
    return jsonEncode(value);
  } catch (_) {
    return value?.toString() ?? 'null';
  }
}

/// Prints a compact diff between two long strings by showing the common
/// prefix/suffix and the differing middle segments with context.
void _printStringDiff(
  String a,
  String b, {
  String labelA = 'A',
  String labelB = 'B',
  // rationale: clarity for callers
  // ignore: avoid-never-passed-parameters
  int context = 200,
  // ignore: avoid-never-passed-parameters
  int maxMiddle = 600,
}) {
  // Find common prefix
  final minLen = a.length < b.length ? a.length : b.length;
  var prefix = 0;
  while (prefix < minLen && a.codeUnitAt(prefix) == b.codeUnitAt(prefix)) {
    prefix++;
  }

  // Find common suffix without overlapping the prefix
  var suffix = 0;
  while (suffix < minLen - prefix &&
      a.codeUnitAt(a.length - 1 - suffix) ==
          b.codeUnitAt(b.length - 1 - suffix)) {
    suffix++;
  }

  final aMidStart = prefix;
  final aMidEnd = a.length - suffix;
  final bMidStart = prefix;
  final bMidEnd = b.length - suffix;

  String safeSlice(String s, int start, int end) {
    if (start < 0) start = 0;
    if (end > s.length) end = s.length;
    if (start > end) start = end;
    return s.substring(start, end);
  }

  // Limit middle segments to maxMiddle each for readability
  final aMid = safeSlice(
    a,
    aMidStart,
    (aMidStart + maxMiddle).clamp(0, aMidEnd),
  );
  final bMid = safeSlice(
    b,
    bMidStart,
    (bMidStart + maxMiddle).clamp(0, bMidEnd),
  );

  // Metadata
  print('--- Diff summary ---');
  print('Lengths: $labelA=${a.length}, $labelB=${b.length}');
  print('Common prefix: $prefix chars, Common suffix: $suffix chars');

  // Show diff with context
  if (prefix > 0) {
    final prefixSnippet = safeSlice(
      a,
      (prefix - context).clamp(0, a.length),
      prefix,
    );

    print('...${prefixSnippet.replaceAll('\n', '\\n')}');
  }
  print('<<< $labelA differs >>>');
  print(aMid.replaceAll('\n', '\\n'));
  print('>>> $labelB differs <<<');
  print(bMid.replaceAll('\n', '\\n'));
  if (suffix > 0) {
    final hasSuffixEllipsis = suffix > context;

    final suffixSnippet = safeSlice(
      a,
      a.length - suffix,
      (a.length - suffix + context).clamp(0, a.length),
    );
    print(
      '${suffixSnippet.replaceAll('\n', '\\n')}${hasSuffixEllipsis ? '...' : ''}',
    );
  }
  print('--- End diff ---');
}
