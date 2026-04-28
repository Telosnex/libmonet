// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:math' as math;

import 'package:libmonet/extract/point_provider_lab.dart';
import 'package:libmonet/extract/quantizer_celebi.dart';
import 'package:libmonet/extract/quantizer_result.dart';
import 'package:libmonet/extract/quantizer_wsmeans.dart';
import 'package:libmonet/extract/quantizer_wu.dart';

import 'perf_tester.dart';

void main(List<String> args) async {
  final profile = args.contains('--profile');
  final counters = args.contains('--counters');
  final warmupRuns = _intArg(args, '--warmup', fallback: 10);
  final benchmarkRuns = _intArg(args, '--runs', fallback: 30);
  final profileRuns = _intArg(args, '--profile-runs', fallback: 30);
  final profileTopN = _intArg(args, '--profile-top', fallback: 40);
  final profileDumpDirectory = _stringArg(args, '--profile-dump');
  final only = _stringArg(args, '--only');

  final cases = _buildCases();
  if (counters) {
    _printCounters(cases);
    return;
  }

  final seededCases = await _buildWuSeededCases(cases);
  final suites = <_Suite>[
    _Suite(
      name: 'wsmeans_32_vs_256',
      cases: cases,
      baselineName: 'wsmeans_random_init_32',
      baseline: _wsmeansRandom32,
      candidateName: 'wsmeans_random_init_256',
      candidate: _wsmeansRandom256,
    ),
    _Suite(
      name: 'wsmeans_32_vs_input_map',
      cases: cases,
      baselineName: 'wsmeans_random_init_32',
      baseline: _wsmeansRandom32,
      candidateName: 'wsmeans_random_init_32_with_input_map',
      candidate: _wsmeansRandom32WithInputMap,
    ),
    _Suite(
      name: 'wsmeans_32_vs_wu_seeded_32',
      cases: seededCases,
      baselineName: 'wsmeans_random_init_32',
      baseline: _wsmeansRandom32,
      candidateName: 'wsmeans_wu_seeded_32',
      candidate: _wsmeansWuSeeded32,
    ),
    _Suite(
      name: 'wsmeans_32_vs_celebi_32',
      cases: cases,
      baselineName: 'wsmeans_random_init_32',
      baseline: _wsmeansRandom32,
      candidateName: 'celebi_wu_plus_wsmeans_32',
      candidate: _celebi32,
    ),
  ];

  final selectedSuites = only == null
      ? suites
      : suites.where((suite) => suite.name == only).toList();
  if (selectedSuites.isEmpty) {
    print('No suite named "$only". Available suites:');
    for (final suite in suites) {
      print('  ${suite.name}');
    }
    return;
  }

  print('WSMeans perf/profiling runner');
  print('warmup=$warmupRuns runs=$benchmarkRuns profile=$profile');
  print('profileRuns=$profileRuns profileTopN=$profileTopN');
  if (profileDumpDirectory != null) {
    print('profileDumpDirectory=$profileDumpDirectory');
  }
  print('cases=${cases.length}');
  print('');
  print('CPU profiling commands:');
  print('  dart run --enable-vm-service test/perf/wsmeans_perf.dart --profile');
  print(
    '  dart run --enable-vm-service test/perf/wsmeans_perf.dart --profile --only=wsmeans_32_vs_256',
  );
  print(
    '  dart run --enable-vm-service test/perf/wsmeans_perf.dart --profile --profile-dump=/tmp/wsmeans-profile',
  );
  print('  dart run test/perf/wsmeans_perf.dart --counters');
  print('');

  for (final suite in selectedSuites) {
    final tester = PerfTester<_PerfInput, QuantizerResult>(
      testName: suite.name,
      testCases: suite.cases,
      implementation1: suite.baseline,
      implementation2: suite.candidate,
      impl1Name: suite.baselineName,
      impl2Name: suite.candidateName,
    );

    await tester.run(
      warmupRuns: warmupRuns,
      benchmarkRuns: benchmarkRuns,
      skipEqualityCheck: true,
      profile: profile,
      profileRuns: profileRuns,
      profileTopN: profileTopN,
      profileDumpDirectory: profileDumpDirectory,
    );
  }
}

void _printCounters(List<_PerfInput> cases) {
  print('WSMeans phase counters');
  for (final input in cases) {
    for (final maxColors in [input.maxColors, 256]) {
      QuantizerWsmeans.quantize(
        input.pixels,
        maxColors,
        pointProvider: const PointProviderLab(),
      );
      print('\n============================================================');
      print('${input.name} maxColors=$maxColors');
      print('============================================================');
      print('phase counters disabled for stock QuantizerWsmeans');
    }
  }
}

QuantizerResult _wsmeansRandom32(_PerfInput input) {
  return QuantizerWsmeans.quantize(
    input.pixels,
    input.maxColors,
    pointProvider: const PointProviderLab(),
  );
}

QuantizerResult _wsmeansRandom256(_PerfInput input) {
  return QuantizerWsmeans.quantize(
    input.pixels,
    256,
    pointProvider: const PointProviderLab(),
  );
}

QuantizerResult _wsmeansRandom32WithInputMap(_PerfInput input) {
  return QuantizerWsmeans.quantize(
    input.pixels,
    input.maxColors,
    pointProvider: const PointProviderLab(),
    returnInputPixelToClusterPixel: true,
  );
}

QuantizerResult _wsmeansWuSeeded32(_PerfInput input) {
  return QuantizerWsmeans.quantize(
    input.pixels,
    input.maxColors,
    startingClusters: input.startingClusters,
    pointProvider: const PointProviderLab(),
  );
}

Future<QuantizerResult> _celebi32(_PerfInput input) {
  return QuantizerCelebi().quantize(input.pixels, input.maxColors);
}

Future<List<_PerfInput>> _buildWuSeededCases(List<_PerfInput> cases) async {
  final seeded = <_PerfInput>[];
  for (final input in cases) {
    final wu = QuantizerWu();
    final result = await wu.quantize(input.pixels, input.maxColors);
    seeded.add(
      input.copyWith(startingClusters: result.argbToCount.keys.toList()),
    );
  }
  return seeded;
}

List<_PerfInput> _buildCases() {
  return [
    _PerfInput(
      name: 'flat_96x96_12_unique',
      pixels: _paletteImage(96, 96, 12, seed: 1),
      maxColors: 32,
    ),
    _PerfInput(
      name: 'photoish_96x96_900_unique',
      pixels: _photoishImage(96, 96, seed: 2),
      maxColors: 32,
    ),
    _PerfInput(
      name: 'gradient_128x128_many_unique',
      pixels: _gradientImage(128, 128),
      maxColors: 32,
    ),
    _PerfInput(
      name: 'random_128x128_many_unique',
      pixels: _randomImage(128, 128, seed: 3),
      maxColors: 32,
    ),
    _PerfInput(
      name: 'photoish_192x192_1500_unique',
      pixels: _photoishImage(192, 192, seed: 4),
      maxColors: 32,
    ),
  ];
}

List<int> _paletteImage(
  int width,
  int height,
  int colorCount, {
  required int seed,
}) {
  final random = math.Random(seed);
  final palette = List.generate(colorCount, (_) {
    return _argb(random.nextInt(256), random.nextInt(256), random.nextInt(256));
  });
  return List.generate(
    width * height,
    (index) => palette[index % palette.length],
  );
}

List<int> _photoishImage(int width, int height, {required int seed}) {
  final random = math.Random(seed);
  final anchors = [
    (40, 50, 65),
    (95, 110, 120),
    (180, 150, 120),
    (215, 205, 185),
    (90, 130, 120),
    (35, 80, 105),
  ];
  return List.generate(width * height, (index) {
    final x = index % width;
    final y = index ~/ width;
    final anchor =
        anchors[(x ~/ 24 + y ~/ 24 + random.nextInt(2)) % anchors.length];
    final noise = 18;
    return _argb(
      _clamp8(anchor.$1 + random.nextInt(noise * 2 + 1) - noise),
      _clamp8(anchor.$2 + random.nextInt(noise * 2 + 1) - noise),
      _clamp8(anchor.$3 + random.nextInt(noise * 2 + 1) - noise),
    );
  });
}

List<int> _gradientImage(int width, int height) {
  return List.generate(width * height, (index) {
    final x = index % width;
    final y = index ~/ width;
    return _argb(
      (x * 255 / (width - 1)).round(),
      (y * 255 / (height - 1)).round(),
      ((x + y) * 255 / (width + height - 2)).round(),
    );
  });
}

List<int> _randomImage(int width, int height, {required int seed}) {
  final random = math.Random(seed);
  return List.generate(width * height, (_) {
    return _argb(random.nextInt(256), random.nextInt(256), random.nextInt(256));
  });
}

int _argb(int r, int g, int b) => 0xff000000 | (r << 16) | (g << 8) | b;

int _clamp8(int value) => value.clamp(0, 255).toInt();

int _intArg(List<String> args, String name, {required int fallback}) {
  final value = _stringArg(args, name);
  if (value == null) return fallback;
  return int.tryParse(value) ?? fallback;
}

String? _stringArg(List<String> args, String name) {
  final equalsPrefix = '$name=';
  for (final arg in args) {
    if (arg.startsWith(equalsPrefix)) {
      return arg.substring(equalsPrefix.length);
    }
  }
  return null;
}

class _Suite {
  const _Suite({
    required this.name,
    required this.cases,
    required this.baselineName,
    required this.baseline,
    required this.candidateName,
    required this.candidate,
  });

  final String name;
  final List<_PerfInput> cases;
  final String baselineName;
  final FutureOr<QuantizerResult> Function(_PerfInput input) baseline;
  final String candidateName;
  final FutureOr<QuantizerResult> Function(_PerfInput input) candidate;
}

class _PerfInput {
  const _PerfInput({
    required this.name,
    required this.pixels,
    required this.maxColors,
    this.startingClusters = const [],
  });

  final String name;
  final List<int> pixels;
  final int maxColors;
  final List<int> startingClusters;

  _PerfInput copyWith({List<int>? startingClusters}) {
    return _PerfInput(
      name: name,
      pixels: pixels,
      maxColors: maxColors,
      startingClusters: startingClusters ?? this.startingClusters,
    );
  }

  @override
  String toString() => name;
}
