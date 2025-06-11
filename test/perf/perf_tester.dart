// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:math' as math;

class PerfTester<Input, Output> {
  final String testName;
  final List<Input> testCases;
  final Output? Function(Input) implementation1;
  final Output? Function(Input) implementation2;
  final String impl1Name;
  final String impl2Name;
  final bool Function(Output?, Output?)? equalityCheck;

  final _random = math.Random(42);
  final List<double> impl1Times = [];
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

  void run({
    int warmupRuns = 100,
    int benchmarkRuns = 100,
    bool skipEqualityCheck = false,
  }) {
    if (!skipEqualityCheck) {
      _verifyImplementations();
    }
    _warmup(warmupRuns);
    _benchmark(benchmarkRuns);
    _printResults();
  }

  void _verifyImplementations() {
    print('Verifying implementations...');
    var allEqual = true;

    for (var i = 0; i < testCases.length; i++) {
      final input = testCases[i];
      final result1 = implementation1(input);
      final result2 = implementation2(input);

      bool isEqual;
      if (equalityCheck != null) {
        isEqual = equalityCheck!(result1, result2);
      } else {
        // Default equality check using JSON encoding for deep comparison
        final str1 = jsonEncode(result1);
        final str2 = jsonEncode(result2);
        isEqual = str1 == str2;
      }

      if (!isEqual) {
        final result1String = result1?.toString() ?? 'null';
        final result1LengthLimited = result1String.length > 1000
            ? '${result1String.substring(0, 1000)}...truncated after 1000 characters'
            : result1String;
        final result2String = result2?.toString() ?? 'null';
        final result2LengthLimited = result2String.length > 1000
            ? '${result2String.substring(0, 1000)}...truncated after 1000 characters'
            : result2String;
        print('\nMismatch found for test case $i:');
        print('Input: $input');
        print('$impl1Name: $result1LengthLimited');
        print('$impl2Name: $result2LengthLimited');
        allEqual = false;
      }
    }

    if (allEqual) {
      print('\nAll test cases produced identical output! ✅');
    } else {
      print('\nWarning: Differences found in outputs! ❌');
    }
  }

  void _warmup(int runs) {
    print('\nWarming up...');
    for (var i = 0; i < runs; i++) {
      final input = testCases[_random.nextInt(testCases.length)];
      implementation1(input);
      implementation2(input);
    }
  }

  void _benchmark(int runs) {
    print('\nRunning benchmark...');
    for (var run = 0; run < runs; run++) {
      var testA = run % 2 == 0;
      // print('\nRun ${run + 1}:');

      // First run
      var startTime = DateTime.now().microsecondsSinceEpoch;
      for (var input in testCases) {
        testA ? implementation1(input) : implementation2(input);
      }
      var time1 = (DateTime.now().microsecondsSinceEpoch - startTime) / 1000.0;

      // Second run
      startTime = DateTime.now().microsecondsSinceEpoch;
      for (var input in testCases) {
        testA ? implementation2(input) : implementation1(input);
      }
      var time2 = (DateTime.now().microsecondsSinceEpoch - startTime) / 1000.0;

      // Store results
      if (testA) {
        impl1Times.add(time1);
        impl2Times.add(time2);
      } else {
        impl2Times.add(time1);
        impl1Times.add(time2);
      }
    }
  }

  void _printResults() {
    _printStats();
    _printVisualizations();
  }

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

    print('\n=== $testName Performance Summary ===');
    print('Total Operations: $totalOps');

    // Print header
    print(
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

      print(
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

  String _generateDistributionPair(
    List<double> data1,
    List<double> data2, {
    String label1 = 'Data 1',
    String label2 = 'Data 2',
    int width = 30,
  }) {
    if (data1.isEmpty || data2.isEmpty) return '';

    // Calculate full ranges and percentiles
    var sorted1 = List<double>.of(data1)..sort();
    var sorted2 = List<double>.of(data2)..sort();

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
    var binCount = width;
    var binSize = (visMax - visMin) / binCount;
    var histogram1 = List<int>.filled(binCount, 0);
    var histogram2 = List<int>.filled(binCount, 0);
    var outliers1 = 0;
    var outliers2 = 0;

    void addToHistogram(double value, List<int> hist, var outliersRef) {
      if (value > visMax) {
        outliersRef++;
        return;
      }
      var bin = ((value - visMin) / binSize).floor();
      // rationale: would be too confusing, its confusing already!
      // ignore: avoid-unnecessary-reassignment
      bin = math.min(math.max(bin, 0), binCount - 1);
      hist[bin]++;
    }

    for (var value in data1) {
      addToHistogram(value, histogram1, outliers1);
    }
    for (var value in data2) {
      addToHistogram(value, histogram2, outliers2);
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
      'Distribution (showing ${formatValue(visMin)}-${formatValue(visMax)}ms):',
    );
    result.writeln(
      getDistributionLine(histogram1, label1, outliers1, min1, max1),
    );
    result.writeln(
      getDistributionLine(histogram2, label2, outliers2, min2, max2),
    );

    return result.toString();
  }

  void _printVisualizations() {
    print('\n');
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
