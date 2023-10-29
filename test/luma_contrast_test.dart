// ignore_for_file: avoid_print, dead_code, unused_local_variable

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/argb_srgb_xyz_lab.dart';
import 'package:libmonet/luma.dart';
import 'package:libmonet/luma_contrast.dart';

import 'utils/color_matcher.dart';

void main() {
  test('all RGBs are in range of L* produced from their APCA Y', () {
    for (int r = 0; r <= 255; r += 1) {
      for (int g = 0; g <= 255; g += 1) {
        for (int b = 0; b <= 255; b += 1) {
          final argb = argbFromRgb(r, g, b);
          final lstar = lstarFromArgb(argb);
          final luma = lumaFromArgb(argb);
          final lstarRange = lumaToLstarRange(luma);
          expect(lstar, inInclusiveRange(lstarRange[0], lstarRange[1]));
        }
      }
    }
  });

  test('verify highest diff. between grayscale L* and L* from luma', () {
    final color = argbFromRgb(255, 0, 3);
    final luma = lumaFromArgb(color);
    final grayscaleArgb = grayscaleArgbFromLuma(luma);
    final grayscaleLstar = lstarFromArgb(grayscaleArgb);
    final lstar = lstarFromArgb(color);
    final diff = (grayscaleLstar - lstar).abs();
    expect(diff, closeTo(30.62477937847987, 0.001));
  });

  test('verify highest range from luma', () {
    const luma = 21.34494117647059;
    final lstarRange = lumaToLstarRange(luma);
    final first = lstarRange[0];
    final last = lstarRange[1];
    expect(first, closeTo(22.367572941267085, 0.001));
    expect(last, closeTo(53.24843417440036, 0.001));
  });

  test('luma range test', () {
    expect(lumaFromArgb(0xffffffff), 100.0);
    expect(lumaFromArgb(0xff000000), 0.0);
  });

  test('inverse luma range test', () {
    expect(grayscaleArgbFromLuma(100.0), isColor(0xffffffff));
    expect(grayscaleArgbFromLuma(0.0), isColor(0xff000000));
  });

  test('CSV of range', () {
    final tsv = StringBuffer();
    for (int i = 0; i <= 100; i++) {
      final luma = i.toDouble();
      final lstarRange = lumaToLstarRange(luma);
      final first = lstarRange[0];
      final last = lstarRange[1];
      tsv.writeln('$luma,$first,$last');
    }
    print(tsv.toString());
  });

  test('Full RGB Explorer',
      skip:
          'important diagnostic code for producing error tolerances needed due to RGB being whole numbers, but not a test',
      () {
    var maxLumaToGrayscaleToLumaError = -1.0;
    var maxOverallDiff = -1.0;
    var maxOverallDiffRgbTriple = <int>[];
    var maxError = -1.0;
    var maxErrorRgbTriple = <int>[];
    var argbToLumaToArgbsToLumasMaxError = -1.0;
    var minBoundaryErrorLstar = -1.0;
    var minBoundaryErrors = 0;
    var maxBoundaryErrorLstar = -1.0;
    var maxBoundaryErrors = 0;
    for (int r = 0; r <= 255; r += 1) {
      for (int g = 0; g <= 255; g += 1) {
        for (int b = 0; b <= 255; b += 1) {
          // This verifies that when we go from luma => ARGB by assuming
          // grayscale, that the luma of the grayscale ARGB is close to the
          // original.
          //
          // This was used to find a maximum error of 0.19607843137256253 (due
          // to ARG being whole numbers, ex. if we need red 250.2 to reach a
          // certain luma, we can only provide red 250, and red 251 will have
          // greater error).
          if (false) {
            final luma = lumaFromArgb(argbFromRgb(r, g, b));
            final grayscaleArgbMatchingLuma = grayscaleArgbFromLuma(luma);
            final verifyGrayscaleLuma = lumaFromArgb(grayscaleArgbMatchingLuma);
            final error = (luma - verifyGrayscaleLuma).abs();
            maxLumaToGrayscaleToLumaError =
                math.max(maxLumaToGrayscaleToLumaError, error);
          }

          // This verifies that when we go from luma => ARGBs, the ARGBs
          // have lumas that are close to the original luma.
          //
          // Error is expected, due to RGB being whole numbers, so if luma
          // needed, say, 250.2 to be represented, it would be rounded to 250.
          //
          // This test is used to find the maximum luma error when combining
          // all 3 channels, which is 0.19607843137256253
          if (false) {
            final luma = lumaFromArgb(argbFromRgb(r, g, b));
            final boundaryArgbs = findBoundaryArgbsForLuma(luma);
            final boundaryArgbsLumas =
                boundaryArgbs.map((e) => lumaFromArgb(e)).toList();
            for (final boundaryArgbLuma in boundaryArgbsLumas) {
              final diffFromTrueLuma = (boundaryArgbLuma - luma).abs();
              argbToLumaToArgbsToLumasMaxError =
                  math.max(argbToLumaToArgbsToLumasMaxError, diffFromTrueLuma);
            }
          }

          // This verifies that given a RGB => luma => boundary ARGBs = lumas,
          // the Y of the RGB falls in the range of the Ys.
          //
          // Due to quantization of ARGB, not all APCA Ys can be accurately
          // reversed. ex. it may require a red channel of 250.2, but R/G/B
          // channels are whole numbers.
          //
          // This test is used to identify the error in the lstar range due to
          // this effect.
          //
          // minBoundaryError: 0.24766520401936987. total errors: 171193
          // maxBoundaryError: 0.008416650634032408. total errors: 632
          if (false) {
            final trueLuma = lumaFromArgb(argbFromRgb(r, g, b));
            final trueLstar = lstarFromArgb(argbFromRgb(r, g, b));
            final boundaryArgbsForTrueLuma = findBoundaryArgbsForLuma(trueLuma);

            final boundaryLstars =
                boundaryArgbsForTrueLuma.map((e) => lstarFromArgb(e)).toList();
            final maxBoundaryLstar = boundaryLstars.reduce(math.max);
            final minBoundaryLstar = boundaryLstars.reduce(math.min);

            expect(
                trueLstar,
                inInclusiveRange(minBoundaryLstar - 0.24766520401936987,
                    maxBoundaryLstar + 0.008416650634032408),
                reason: 'tried $r, $g, $b');
            if (trueLstar < minBoundaryLstar) {
              minBoundaryErrors++;
              minBoundaryErrorLstar = math.max(
                  minBoundaryErrorLstar, (minBoundaryLstar - trueLstar).abs());
            } else if (trueLstar > maxBoundaryLstar) {
              maxBoundaryErrors++;
              maxBoundaryErrorLstar = math.max(
                  maxBoundaryErrorLstar, (maxBoundaryLstar - trueLstar).abs());
            }
          }

          // This calculates the difference between L* of a color and the L*
          // range we'd calculate if we only had the luma.
          //
          // maxOverallDiff: 30.62477937847987. @ 255, 0, 3
          if (false) {
            final yDiff = _findDiffBetweenTrueLstarAndLstarRangeFromLuma(
                argbFromRgb(r, g, b));
            if (yDiff > maxOverallDiff) {
              maxOverallDiff = yDiff;
              maxOverallDiffRgbTriple = [r, g, b];
            }
          }
        }
      }
    }

    if (maxLumaToGrayscaleToLumaError > -1) {
      print('maxLumaToGrayscaleToLumaError: $maxLumaToGrayscaleToLumaError');
    }
    if (argbToLumaToArgbsToLumasMaxError > -1) {
      print(
          'maxArgbToApcaToApcsToArgbsApcaError: $argbToLumaToArgbsToLumasMaxError');
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
}

double _findDiffBetweenTrueLstarAndLstarRangeFromLuma(int argb) {
  final lstar = lstarFromArgb(argb);
  final luma = lumaFromArgb(argb);
  final lstarRange = lumaToLstarRange(luma);
  final diffFromMin = (lstar - lstarRange[0]).abs();
  final diffFromMax = (lstar - lstarRange[1]).abs();
  final lstarDiff = math.max(diffFromMin, diffFromMax);
  return lstarDiff;
}
