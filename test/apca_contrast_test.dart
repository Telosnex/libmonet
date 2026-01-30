// ignore_for_file: avoid_print, dead_code, unused_local_variable

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/apca.dart';
import 'package:libmonet/apca_contrast.dart';
import 'package:libmonet/argb_srgb_xyz_lab.dart';

void main() {
  test('all RGBs are in range of L* produced from their APCA Y', () {
    for (int r = 0; r <= 255; r += 1) {
      for (int g = 0; g <= 255; g += 1) {
        for (int b = 0; b <= 255; b += 1) {
          final argb = argbFromRgb(r, g, b);
          final lstar = lstarFromArgb(argb);
          final apcaY = apcaYFromArgb(argb);
          final lstarRange = apcaYToLstarRange(apcaY);
          expect(
              lstar, inInclusiveRange(lstarRange.darkest, lstarRange.lightest));
        }
      }
    }
  });

  test('CSV of range', skip: 'data generator', () {
    final tsv = StringBuffer();
    for (int i = 0; i <= 100; i++) {
      final apcaY = i.toDouble() / 100.0;
      final lstarRange = apcaYToLstarRange(apcaY);
      tsv.writeln('$apcaY,${lstarRange.darkest},${lstarRange.lightest}');
    }
    print(tsv.toString());
  });

  test('Full RGB Explorer',
      skip:
          'important diagnostic code for producing error tolerances needed due to RGB being whole numbers, but not a test',
      () {
    var maxOverallDiff = -1.0;
    var maxOverallDiffRgbTriple = <int>[];
    var maxError = -1.0;
    var maxErrorRgbTriple = <int>[];
    var maxArgbToApcaToApcsToArgbsApcaError = -1.0;
    var minBoundaryErrorLstar = -1.0;
    var minBoundaryErrors = 0;
    var maxBoundaryErrorLstar = -1.0;
    var maxBoundaryErrors = 0;
    for (int r = 0; r <= 255; r += 1) {
      for (int g = 0; g <= 255; g += 1) {
        for (int b = 0; b <= 255; b += 1) {
          // This verifies that when we go from apcaY => ARGB by assuming
          // grayscale, that the apcaY of the grayscale ARGB is close to the original.
          if (false) {
            final apcaY = apcaYFromArgb(argbFromRgb(r, g, b));
            final grayscaleArgbMatchingApcaY = apcaYToGrayscaleArgb(apcaY);
            final verifyGrayscaleApcaY =
                apcaYFromArgb(grayscaleArgbMatchingApcaY);

            expect(apcaY, closeTo(verifyGrayscaleApcaY, 0.005));
          }

          // This verifies that when we go from apcaY => ARGBs, the ARGBs
          // have apcaYs that are close to the original apcaY.
          //
          // Error is expected, due to RGB being whole numbers, so if APCA Y
          // needed, say, 250.2 to be represented, it would be rounded to 250.
          //
          // Another test was used to identify that the maximum per-channel error is
          // 0.003369962535303306.
          //
          // This test is used to find the maximum APCA Y error when combining
          // all 3 channels, which is 0.004683538862013781.
          if (false) {
            final trueApcaY = apcaYFromArgb(argbFromRgb(r, g, b));
            final boundaryArgbs = findBoundaryArgbsForApcaY(trueApcaY);
            final boundaryArgbsApcaYs =
                boundaryArgbs.map((e) => apcaYFromArgb(e)).toList();
            for (final boundaryArgbApcaY in boundaryArgbsApcaYs) {
              final diffFromTrueApcaY = (boundaryArgbApcaY - trueApcaY).abs();
              maxArgbToApcaToApcsToArgbsApcaError = math.max(
                  maxArgbToApcaToApcsToArgbsApcaError, diffFromTrueApcaY);
            }
          }

          // This verifies that given a RGB => APCA Y => boundary ARGBs = Ys,
          // the Y of the RGB falls in the range of the Ys.
          //
          // Due to quantization of ARGB, not all APCA Ys can be accurately
          // reversed. ex. it may require a red channel of 250.2, but R/G/B
          // channels are whole numbers.
          //
          // This test is used to identify the error in the lstar range due to
          // this effect.
          //
          // minBoundaryError: 0.08747562332222003. total errors: 12234
          // maxBoundaryError: 0.23986207179298447. total errors: 1341645
          if (false) {
            final trueApcaY = apcaYFromArgb(argbFromRgb(r, g, b));
            final boundaryArgbsForTrueApcaY =
                findBoundaryArgbsForApcaY(trueApcaY);
            final trueY = yFromArgb(argbFromRgb(r, g, b));

            final boundaryYs =
                boundaryArgbsForTrueApcaY.map((e) => yFromArgb(e)).toList();
            final maxBoundaryY = boundaryYs.reduce(math.max);
            final minBoundaryY = boundaryYs.reduce(math.min);

            final trueLstar = lstarFromY(trueY);
            final minBoundaryLstar = lstarFromY(minBoundaryY);
            final maxBoundaryLstar = lstarFromY(maxBoundaryY);
            expect(
                trueLstar,
                inInclusiveRange(minBoundaryLstar - 0.08747562332222003,
                    maxBoundaryLstar + 0.23986207179298447),
                reason: 'tried $r, $g, $b');
            if (trueY < minBoundaryY) {
              minBoundaryErrors++;
              minBoundaryErrorLstar = math.max(minBoundaryErrorLstar,
                  (lstarFromY(minBoundaryY) - lstarFromY(trueY)).abs());
            } else if (trueY > maxBoundaryY) {
              maxBoundaryErrors++;
              maxBoundaryErrorLstar = math.max(maxBoundaryErrorLstar,
                  (lstarFromY(maxBoundaryY) - lstarFromY(trueY)).abs());
            }
            final minError = (trueY - minBoundaryY).abs();
            final maxError2 = (trueY - maxBoundaryY).abs();
            final error = math.max(minError, maxError2);
            if (error > maxError) {
              maxError = error;
              maxErrorRgbTriple = [r, g, b];
            }
          }

          // This calculates the difference between L* of a color and the L*
          // range we'd calculate if we only had the APCA Y.
          //
          // 4.7867847389446965 @ 0, 0, 95
          if (false) {
            final yDiff = _findDiffBetweenTrueLstarAndLstarRangeFromApcaY(
                argbFromRgb(r, g, b));
            if (yDiff > maxOverallDiff) {
              maxOverallDiff = yDiff;
              maxOverallDiffRgbTriple = [r, g, b];
            }
          }
        }
      }
    }

    if (maxArgbToApcaToApcsToArgbsApcaError > -1) {
      print(
          'maxArgbToApcaToApcsToArgbsApcaError: $maxArgbToApcaToApcsToArgbsApcaError');
    }
    if (maxOverallDiff > -1) {
      print(
          'maxOverallDiff: $maxOverallDiff. @ ${maxOverallDiffRgbTriple[0]}, ${maxOverallDiffRgbTriple[1]}, ${maxOverallDiffRgbTriple[2]}');
    }
    if (minBoundaryErrorLstar > -1) {
      print(
          'minBoundaryError: $minBoundaryErrorLstar. total errors: $minBoundaryErrors');
      print(
          'maxBoundaryError: $maxBoundaryErrorLstar. total errors: $maxBoundaryErrors');
    }
    if (maxError > -1) {
      print(
          'maxError: $maxError. @ ${maxErrorRgbTriple[0]}, ${maxErrorRgbTriple[1]}, ${maxErrorRgbTriple[2]}');
    }
  });

  group('closestTo - returns L* nearest to input for least disruption', () {
    test('lighterBackgroundLstarUnsafe returns closestTo(textLstar)', () {
      const textLstar = 50.0;
      const apca = 60.0;

      final result = lighterBackgroundLstarUnsafe(textLstar, apca);
      final apcaY = lighterBackgroundApcaY(lstarToApcaY(textLstar), apca);
      final range = apcaYToLstarRange(apcaY);

      print(
          'FG=$textLstar wants lighter BG. Result=${result.round()}. Range=${range.darkest.round()}-${range.lightest.round()}. closestTo=$textLstar');

      expect(result, equals(range.closestTo(textLstar)));
    });

    test('lighterTextLstarUnsafe returns closestTo(backgroundLstar)', () {
      const backgroundLstar = 20.0;
      const apca = 60.0;

      final result = lighterTextLstarUnsafe(backgroundLstar, apca);
      final backgroundApcaY = lstarToApcaY(backgroundLstar);
      final apcaY = lighterTextApcaY(backgroundApcaY, apca);
      final range = apcaYToLstarRange(apcaY);

      print(
          'BG=$backgroundLstar wants lighter text. Result=${result.round()}. Range=${range.darkest.round()}-${range.lightest.round()}. closestTo=$backgroundLstar');

      expect(result, equals(range.closestTo(backgroundLstar)));
    });

    test('darkerBackgroundLstar returns closestTo(textLstar)', () {
      const textLstar = 90.0;
      const apca = 60.0;

      final result = darkerBackgroundLstar(textLstar, apca);
      final textApcaY = lstarToApcaY(textLstar);
      final apcaY = darkerBackgroundApcaY(textApcaY, apca);
      final range = apcaYToLstarRange(apcaY);

      print(
          'FG=$textLstar wants darker BG. Result=${result.round()}. Range=${range.darkest.round()}-${range.lightest.round()}. closestTo=$textLstar');

      expect(result, equals(range.closestTo(textLstar).clamp(0.0, 100.0)));
    });
  });
}

double _findDiffBetweenTrueLstarAndLstarRangeFromApcaY(int argb) {
  final lstar = lstarFromArgb(argb);
  final apcaY = apcaYFromArgb(argb);
  final lstarRange = apcaYToLstarRange(apcaY);
  final diffFromMin = (lstar - lstarRange.darkest).abs();
  final diffFromMax = (lstar - lstarRange.lightest).abs();
  final lstarDiff = math.max(diffFromMin, diffFromMax);
  return lstarDiff;
}

