import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:libmonet/libmonet.dart';
import 'package:test/test.dart';
import 'package:libmonet/util/with_opacity_neue.dart';

void main() {
  group('zebra BG', () {
    test('0 FG', () {
      expectOpacity(0.47, fgL: 0, bgLMin: 0.0, bgLMax: 100.0);
    });

    test('10 FG', () {
      expectOpacity(0.52, fgL: 10, bgLMin: 0.0, bgLMax: 100.0);
    });

    test('20 FG', () {
      expectOpacity(0.61, fgL: 20, bgLMin: 0.0, bgLMax: 100.0);
    });

    test('30 FG', () {
      expectOpacity(0.72, fgL: 30, bgLMin: 0.0, bgLMax: 100.0);
    });

    test('40 FG', () {
      expectOpacity(0.86, fgL: 40, bgLMin: 0.0, bgLMax: 100.0);
    });

    test('50 FG', () {
      expectOpacity(0.99, fgL: 50, bgLMin: 0.0, bgLMax: 100.0);
    });

    test('60 FG', () {
      expectOpacity(0.85, fgL: 60, bgLMin: 0.0, bgLMax: 100.0);
    });

    test('70 FG', () {
      expectOpacity(0.76, fgL: 70, bgLMin: 0.0, bgLMax: 100.0);
    });

    test('80 FG', () {
      expectOpacity(0.69, fgL: 80, bgLMin: 0.0, bgLMax: 100.0);
    });

    test('90 FG', () {
      expectOpacity(0.62, fgL: 90, bgLMin: 0.0, bgLMax: 100.0);
    });

    test('100 FG', () {
      expectOpacity(0.55, fgL: 100, bgLMin: 0.0, bgLMax: 100.0);
    });
  });

  group('black BG', () {
    test('0 FG', () {
      expectOpacity(0.47, fgL: 0, bgLMin: 0, bgLMax: 0);
    });

    test('10 FG', () {
      expectOpacity(0.52, fgL: 10, bgLMin: 0, bgLMax: 0);
    });

    test('20 FG', () {
      expectOpacity(0.61, fgL: 20, bgLMin: 0, bgLMax: 0);
    });

    test('30 FG', () {
      expectOpacity(0.72, fgL: 30, bgLMin: 0, bgLMax: 0);
    });

    test('40 FG', () {
      expectOpacity(0.86, fgL: 40, bgLMin: 0, bgLMax: 0);
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
      expectOpacity(0.99, fgL: 50, bgLMin: 100, bgLMax: 100);
    });

    test('60 FG', () {
      expectOpacity(0.85, fgL: 60, bgLMin: 100, bgLMax: 100);
    });

    test('70 FG', () {
      expectOpacity(0.76, fgL: 70, bgLMin: 100, bgLMax: 100);
    });

    test('80 FG', () {
      expectOpacity(0.69, fgL: 80, bgLMin: 100, bgLMax: 100);
    });

    test('90 FG', () {
      expectOpacity(0.62, fgL: 90, bgLMin: 100, bgLMax: 100);
    });

    test('100 FG', () {
      expectOpacity(0.55, fgL: 100, bgLMin: 100, bgLMax: 100);
    });
  });

  group('ARGB-based API', () {
    test('#5B746B on zebra, APCA contrast 0.5', () {
      const fgArgb = 0xFF5B746B;
      final result = getOpacityForArgbs(
        foregroundArgb: fgArgb,
        minBackgroundArgb: 0xFF000000,
        maxBackgroundArgb: 0xFFFFFFFF,
        contrast: 0.5,
        algo: Algo.apca,
        debug: true,
      );

      // Verify contrast is actually met
      final resultColor = result.color;
      final minBgColor = const Color(0xFF000000);
      final maxBgColor = const Color(0xFFFFFFFF);
      final minBlended = Color.alphaBlend(resultColor, minBgColor);
      final maxBlended = Color.alphaBlend(resultColor, maxBgColor);
      final fgLstar = lstarFromArgb(fgArgb);
      final contrastExpected = Algo.apca.getAbsoluteContrast(0.5, Usage.text);
      final contrastMin = Algo.apca.getContrastBetweenLstars(
        bg: lstarFromArgb(minBlended.argb),
        fg: fgLstar,
      );
      final contrastMax = Algo.apca.getContrastBetweenLstars(
        bg: lstarFromArgb(maxBlended.argb),
        fg: fgLstar,
      );

      expect(contrastMin.abs(), greaterThanOrEqualTo(contrastExpected),
          reason: 'contrast against black bg + scrim should meet requirement');
      expect(contrastMax.abs(), greaterThanOrEqualTo(contrastExpected),
          reason: 'contrast against white bg + scrim should meet requirement');
      expect(result.protectionArgb, 0xFFFFFFFF);
      expect(result.opacity, 0.91);
    });

    test('#5B746B on zebra, APCA contrast 1.0 (impossible, best effort)', () {
      const fgArgb = 0xFF5B746B;
      final result = getOpacityForArgbs(
        foregroundArgb: fgArgb,
        minBackgroundArgb: 0xFF000000,
        maxBackgroundArgb: 0xFFFFFFFF,
        contrast: 1.0,
        algo: Algo.apca,
        debug: true,
      );

      // Contrast 1.0 -> Lc 110, impossible for mid-tone fg.
      // Should return 100% opacity in whichever direction gets closest.
      expect(result.opacity, 1.0);

      // Verify it picked the better direction.
      final fgLstar = lstarFromArgb(fgArgb);
      final whiteContrast = Algo.apca
          .getContrastBetweenLstars(
            bg: 100.0,
            fg: fgLstar,
          )
          .abs();
      final blackContrast = Algo.apca
          .getContrastBetweenLstars(
            bg: 0.0,
            fg: fgLstar,
          )
          .abs();

      if (whiteContrast >= blackContrast) {
        expect(result.protectionArgb, 0xFFFFFFFF,
            reason: 'should pick white (higher contrast)');
      } else {
        expect(result.protectionArgb, 0xFF000000,
            reason: 'should pick black (higher contrast)');
      }
      expect(result.protectionArgb, 0xFFFFFFFF);
      expect(result.opacity, 1.0);
    });
  });

  group('edge cases - division by zero', () {
    test(
        'white protection with white min bg, black protection with black max bg',
        () {
      // This case causes division by zero in BOTH opacity calculations:
      // - oPMinRaw: sPMin(1.0) - sBMin(1.0) = 0 (white bg with white protection)
      // - oPMaxRaw: sPMax(0.0) - sBMax(0.0) = 0 (black bg with black protection)
      // The function should handle this gracefully and still achieve contrast.
      const algo = Algo.wcag21;
      const contrast = 0.5;
      final result = getOpacity(
        minBgLstar: 100.0, // white min background
        maxBgLstar: 0.0, // black max background
        foregroundLstar: 50.0,
        contrast: contrast,
        algo: algo,
      );
      expect(result.opacity.isNaN, isFalse,
          reason: 'opacity should not be NaN');
      expect(result.opacity.isInfinite, isFalse,
          reason: 'opacity should not be infinite');
      expect(result.lstar.isNaN, isFalse, reason: 'lstar should not be NaN');

      // Verify that the result actually achieves the required contrast
      final resultColor =
          Color(argbFromLstar(result.lstar)).withOpacityNeue(result.opacity);
      final minBgColor = Color(argbFromLstar(100.0));
      final maxBgColor = Color(argbFromLstar(0.0));
      final minBlended = Color.alphaBlend(resultColor, minBgColor);
      final maxBlended = Color.alphaBlend(resultColor, maxBgColor);
      final contrastExpected = algo.getAbsoluteContrast(contrast, Usage.text);
      final contrastWithMin = algo.getContrastBetweenLstars(
        bg: lstarFromArgb(minBlended.argb),
        fg: 50.0,
      );
      final contrastWithMax = algo.getContrastBetweenLstars(
        bg: lstarFromArgb(maxBlended.argb),
        fg: 50.0,
      );
      expect(contrastWithMin, greaterThanOrEqualTo(contrastExpected),
          reason: 'contrast against min bg should meet requirement');
      expect(contrastWithMax, greaterThanOrEqualTo(contrastExpected),
          reason: 'contrast against max bg should meet requirement');
      expect(result.protectionArgb, 0xFF000000);
      expect(result.opacity, 0.99);
    });

    test('protection layer same as background - white', () {
      // minBgLstar = 100 causes sPMin - sBMin = 0
      final result = getOpacity(
        minBgLstar: 100.0,
        maxBgLstar: 100.0,
        foregroundLstar: 50.0,
        contrast: 0.5,
        algo: Algo.wcag21,
      );
      expect(result.protectionArgb, 0xFF000000);
      expect(result.opacity, 0.99);
    });

    test('protection layer same as background - black', () {
      // maxBgLstar = 0 causes sPMax - sBMax = 0
      final result = getOpacity(
        minBgLstar: 0.0,
        maxBgLstar: 0.0,
        foregroundLstar: 50.0,
        contrast: 0.5,
        algo: Algo.wcag21,
      );
      expect(result.protectionArgb, 0xff777777);
      expect(result.opacity, 0.0);
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
  // Allow 0.02 tolerance on opacity - the contrast verification below is what matters
  expect(result.opacity, closeTo(opacity, 0.001));
  final resultColor =
      Color(argbFromLstar(result.lstar)).withOpacityNeue(result.opacity);
  final minBgColor = Color(argbFromLstar(bgLMin));
  final maxBgColor = Color(argbFromLstar(bgLMax));
  final minBlended = Color.alphaBlend(resultColor, minBgColor);
  final maxBlended = Color.alphaBlend(resultColor, maxBgColor);
  final fgColor = Color(argbFromLstar(fgL));
  final contrastExpected = algo.getAbsoluteContrast(0.5, Usage.text);
  final contrastMin = algo.getContrastBetweenLstars(
      bg: lstarFromArgb(minBlended.argb), fg: fgL);
  final contrastMax = algo.getContrastBetweenLstars(
      bg: lstarFromArgb(maxBlended.argb), fg: fgL);
  if (debug) {
    // Double-nesting avoids compiler warning because it sees if (kDebugMode)
    if (kDebugMode) {
      print('ANSWER IS ${result.opacity}. TEST VERFIYING RATIO.');
      print(
          'added opacity ${result.opacity} with lstar ${result.lstar} ($resultColor)');
      print(
          'added to minBgColor $minBgColor to get $minBlended with lstar ${lstarFromArgb(minBlended.argb).round()}');
      print(
          'added to maxBgColor $maxBgColor to get $maxBlended with lstar ${lstarFromArgb(maxBlended.argb).round()}');
      print('text color $fgColor');
      print(
          'contrastMin: $contrastMin, contrastMax: $contrastMax, contrastExpected: $contrastExpected');
    }
  }
  expect(contrastMin, greaterThanOrEqualTo(contrastExpected));
  expect(contrastMax, greaterThanOrEqualTo(contrastExpected));
}
