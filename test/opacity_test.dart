import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:libmonet/argb_srgb_xyz_lab.dart';
import 'package:libmonet/contrast.dart';
import 'package:libmonet/opacity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('zebra BG', () {
    test('0 FG', () {
      expectOpacity(0.46, fgL: 0, bgLMin: 0.0, bgLMax: 100.0);
    });

    test('10 FG', () {
      expectOpacity(0.52, fgL: 10, bgLMin: 0.0, bgLMax: 100.0);
    });

    test('20 FG', () {
      expectOpacity(0.60, fgL: 20, bgLMin: 0.0, bgLMax: 100.0);
    });

    test('30 FG', () {
      expectOpacity(0.71, fgL: 30, bgLMin: 0.0, bgLMax: 100.0);
    });

    test('40 FG', () {
      expectOpacity(0.85, fgL: 40, bgLMin: 0.0, bgLMax: 100.0);
    });

    test('50 FG', () {
      expectOpacity(0.98, fgL: 50, bgLMin: 0.0, bgLMax: 100.0);
    });

    test('60 FG', () {
      expectOpacity(0.84, fgL: 60, bgLMin: 0.0, bgLMax: 100.0);
    });

    test('70 FG', () {
      expectOpacity(0.75, fgL: 70, bgLMin: 0.0, bgLMax: 100.0);
    });

    test('80 FG', () {
      expectOpacity(0.68, fgL: 80, bgLMin: 0.0, bgLMax: 100.0);
    });

    test('90 FG', () {
      expectOpacity(0.61, fgL: 90, bgLMin: 0.0, bgLMax: 100.0);
    });

    test('100 FG', () {
      expectOpacity(0.54, fgL: 100, bgLMin: 0.0, bgLMax: 100.0);
    });
  });

  group('black BG', () {
    test('0 FG', () {
      expectOpacity(0.46, fgL: 0, bgLMin: 0, bgLMax: 0);
    });

    test('10 FG', () {
      expectOpacity(0.52, fgL: 10, bgLMin: 0, bgLMax: 0);
    });

    test('20 FG', () {
      expectOpacity(0.60, fgL: 20, bgLMin: 0, bgLMax: 0);
    });

    test('30 FG', () {
      expectOpacity(0.71, fgL: 30, bgLMin: 0, bgLMax: 0);
    });

    test('40 FG', () {
      expectOpacity(0.85, fgL: 40, bgLMin: 0, bgLMax: 0);
    });

    test('50 FG', () {
      expectOpacity(0.0, fgL: 50, bgLMin: 0, bgLMax: 0);
    });

    test('60 FG', () {
      expectOpacity(0.0, fgL: 60, bgLMin: 0, bgLMax: 0);
    });

    test('70 FG', () {
      expectOpacity(0.0, fgL: 70, bgLMin: 0, bgLMax: 0);
    });

    test('80 FG', () {
      expectOpacity(0.0, fgL: 80, bgLMin: 0, bgLMax: 0);
    });

    test('90 FG', () {
      expectOpacity(0.0, fgL: 90, bgLMin: 0, bgLMax: 0);
    });

    test('100 FG', () {
      expectOpacity(0.0, fgL: 100, bgLMin: 0, bgLMax: 0);
    });
  });

  group('white BG', () {
    test('0 FG', () {
      expectOpacity(0.0, fgL: 0, bgLMin: 100, bgLMax: 100);
    });

    test('10 FG', () {
      expectOpacity(0.0, fgL: 10, bgLMin: 100, bgLMax: 100);
    });

    test('20 FG', () {
      expectOpacity(0.0, fgL: 20, bgLMin: 100, bgLMax: 100);
    });

    test('30 FG', () {
      expectOpacity(0.0, fgL: 30, bgLMin: 100, bgLMax: 100);
    });

    test('40 FG', () {
      expectOpacity(0.0, fgL: 40, bgLMin: 100, bgLMax: 100);
    });

    test('50 FG', () {
      expectOpacity(0.98, fgL: 50, bgLMin: 100, bgLMax: 100);
    });

    test('60 FG', () {
      expectOpacity(0.84, fgL: 60, bgLMin: 100, bgLMax: 100);
    });

    test('70 FG', () {
      expectOpacity(0.75, fgL: 70, bgLMin: 100, bgLMax: 100);
    });

    test('80 FG', () {
      expectOpacity(0.68, fgL: 80, bgLMin: 100, bgLMax: 100);
    });

    test('90 FG', () {
      expectOpacity(0.61, fgL: 90, bgLMin: 100, bgLMax: 100);
    });

    test('100 FG', () {
      expectOpacity(0.54, fgL: 100, bgLMin: 100, bgLMax: 100);
    });
  });
}

void expectOpacity(double opacity,
    {required double fgL,
    required double bgLMin,
    required double bgLMax,
    bool debug = false}) {
  const algo = Algo.wcag21;
  const relativeContrast = 0.5;
  final result = getOpacity(
    minBgLstar: bgLMin,
    maxBgLstar: bgLMax,
    contrast: relativeContrast,
    algo: algo,
    foregroundLstar: fgL,
    debug: debug,
  );
  expect(result.opacity, closeTo(opacity, 0.001));
  final resultColor =
      Color(argbFromLstar(result.lstar)).withOpacity(result.opacity);
  final minBgColor = Color(argbFromLstar(bgLMin));
  final maxBgColor = Color(argbFromLstar(bgLMax));
  final minBlended = Color.alphaBlend(resultColor, minBgColor);
  final maxBlended = Color.alphaBlend(resultColor, maxBgColor);
  final fgColor = Color(argbFromLstar(fgL));
  final contrastExpected = algo.getAbsoluteContrast(0.5, Usage.text);
  final contrastMin =
      algo.getContrastBetweenLstars(lstarFromArgb(minBlended.value), fgL);
  final contrastMax =
      algo.getContrastBetweenLstars(lstarFromArgb(maxBlended.value), fgL);
  if (debug) {
    // Double-nesting avoids compiler warning because it sees if (kDebugMode)
    if (kDebugMode) {
      print('ANSWER IS ${result.opacity}. TEST VERFIYING RATIO.');
      print(
          'added opacity ${result.opacity} with lstar ${result.lstar} ($resultColor)');
      print(
          'added to minBgColor $minBgColor to get $minBlended with lstar ${lstarFromArgb(minBlended.value).round()}');
      print(
          'added to maxBgColor $maxBgColor to get $maxBlended with lstar ${lstarFromArgb(maxBlended.value).round()}');
      print('text color $fgColor');
      print(
          'contrastMin: $contrastMin, contrastMax: $contrastMax, contrastExpected: $contrastExpected');
    }
  }
  expect(contrastMin, greaterThanOrEqualTo(contrastExpected));
  expect(contrastMax, greaterThanOrEqualTo(contrastExpected));
}
