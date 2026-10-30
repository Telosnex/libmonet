// Performance: AnyBackground.sharedBorder vs today's per-palette colorBorder.
//
// Both build the same three chip palettes. Baseline reads each palette's
// colorBorder. Candidate solves one
// shared border over a background. Outputs differ by design, so the equality
// check is skipped.
//
// Caveat: 400 chip sets over 25 backgrounds is ~16 per background, which
// fits each 64-entry answer cache, so after warmup this mostly times cache
// hits. Cold solves are ~20-190 µs per set (see Linear follow-up).
//
// Run: flutter test test/perf/shared_border/shared_border_perf_test.dart

// ignore_for_file: avoid_print

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:monet_ui/monet_ui.dart';

import '../perf_tester.dart';

const _contrast = 0.5;

typedef _Input = ({
  List<Color> chips,
  double backgroundTone,
  AnyBackground background,
});

List<Palette> _palettes(_Input input) => [
  for (final c in input.chips)
    Palette.from(c, backgroundTone: input.backgroundTone, contrast: _contrast),
];

/// Baseline: what a chip set costs today.
int _today(_Input input) {
  var acc = 0;
  for (final p in _palettes(input)) {
    acc ^= p.color.argb ^ p.colorBorder.argb;
  }
  return acc;
}

/// Candidate: same palettes, one shared border over the background.
int _shared(_Input input) {
  final palettes = _palettes(input);
  final border = input.background.sharedBorder([
    for (final p in palettes) p.color.argb,
  ]);
  var acc = 0;
  for (var i = 0; i < palettes.length; i++) {
    acc ^= palettes[i].color.argb ^ border.borderArgbs[i];
  }
  return acc;
}

/// A synthetic wallpaper: [regions] blobs of random color with noise.
List<int> _wallpaper(math.Random rng, int regions, int pixels) {
  final centers = [
    for (var i = 0; i < regions; i++) 0xff000000 | rng.nextInt(0xffffff),
  ];
  return [
    for (var i = 0; i < pixels; i++)
      () {
        final c = centers[rng.nextInt(regions)];
        int ch(int shift) =>
            (((c >> shift) & 0xff) + rng.nextInt(31) - 15).clamp(0, 255);
        return 0xff000000 | (ch(16) << 16) | (ch(8) << 8) | ch(0);
      }(),
  ];
}

void main() {
  test('shared border perf', () async {
    final rng = math.Random(42);
    // 96px wide at 3:2, as Extract downscales.
    const pixels = 96 * 64;
    final wallpapers = [
      for (final regions in [1, 2, 4, 8, 16, 32])
        for (var i = 0; i < 4; i++) _wallpaper(rng, regions, pixels),
    ];
    final backgrounds = [
      for (final w in wallpapers)
        AnyBackground(w, algo: Algo.apca, contrast: _contrast),
      AnyBackground.unknown(algo: Algo.apca, contrast: _contrast),
    ];

    final testCases = <_Input>[];
    for (var i = 0; i < 400; i++) {
      testCases.add((
        chips: [
          for (var c = 0; c < 3; c++)
            Hct.from(
              rng.nextDouble() * 360,
              10 + rng.nextDouble() * 60,
              5 + rng.nextDouble() * 90,
            ).color,
        ],
        backgroundTone: rng.nextDouble() * 100,
        background: backgrounds[rng.nextInt(backgrounds.length)],
      ));
    }

    await PerfTester<_Input, int>(
      testName: 'Chip set borders: today vs AnyBackground.sharedBorder',
      testCases: testCases,
      implementation1: _today,
      implementation2: _shared,
      impl1Name: 'today: 3x Palette.colorBorder',
      impl2Name: 'sharedBorder over a background',
    ).run(warmupRuns: 20, benchmarkRuns: 20, skipEqualityCheck: true);

    // Per-image setup: building a background and its first answer reduces
    // the pixels. Once per wallpaper change.
    final watch = Stopwatch()..start();
    const runs = 200;
    const surfaces = [0xffb431ed, 0xff4d394f, 0xff536d2d];
    for (var i = 0; i < runs; i++) {
      AnyBackground(
        wallpapers[i % wallpapers.length],
        algo: Algo.apca,
        contrast: _contrast,
      ).sharedBorder(surfaces);
    }
    print('');
    print(
      'New background + first sharedBorder, $pixels px: '
      '${(watch.elapsedMicroseconds / runs / 1000).toStringAsFixed(2)} ms',
    );
  }, timeout: Timeout.none);
}
