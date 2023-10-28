// ignore_for_file: avoid_print, dead_code, unused_local_variable

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/apca.dart';
import 'package:libmonet/argb_srgb_xyz_lab.dart';

void main() {
  test('integer RGB', () {
    var maxRYDiff = -1.0;
    var maxRDiffRgbTriple = <int>[];
    for (int r = 0; r <= 255; r += 1) {
      final yDiff = findDiffBetweenYsFoundFromGrayscaleApcaAndTrueApca(
          argbFromRgb(r, 0, 0));
      if (yDiff > maxRYDiff) {
        maxRYDiff = yDiff;
        maxRDiffRgbTriple = [r, 0, 0];
      }
    }
    print(
        'maxRYDiff: $maxRYDiff @ ${maxRDiffRgbTriple[0]}, ${maxRDiffRgbTriple[1]}, ${maxRDiffRgbTriple[2]}');

    var maxGYDiff = -1.0;
    var maxGDiffRgbTriple = <int>[];
    for (int g = 0; g <= 255; g += 1) {
      final yDiff = findDiffBetweenYsFoundFromGrayscaleApcaAndTrueApca(
          argbFromRgb(0, g, 0));

      if (yDiff > maxGYDiff) {
        maxGYDiff = yDiff;
        maxGDiffRgbTriple = [0, g, 0];
      }
    }
    print(
        'maxGYDiff: $maxGYDiff @ ${maxGDiffRgbTriple[0]}, ${maxGDiffRgbTriple[1]}, ${maxGDiffRgbTriple[2]}');

    var maxBYDiff = -1.0;
    var maxBDiffRgbTriple = <int>[];
    for (int b = 0; b <= 255; b += 1) {
      final yDiff = findDiffBetweenYsFoundFromGrayscaleApcaAndTrueApca(
          argbFromRgb(0, 0, b));

      if (yDiff > maxBYDiff) {
        maxBYDiff = yDiff;
        maxBDiffRgbTriple = [0, 0, b];
      }
    }
    print(
        'maxBYDiff: $maxBYDiff @ ${maxBDiffRgbTriple[0]}, ${maxBDiffRgbTriple[1]}, ${maxBDiffRgbTriple[2]}');

    var maxOverallDiff = -100.0;
    var maxOverallDiffRgbTriple = <int>[];
    for (int r = 0; r <= 1; r += 1) {
      print('r = $r');
      for (int g = 0; g <= 255; g += 1) {
        for (int b = 0; b <= 255; b += 1) {
          final yDiff = findDiffBetweenYsFoundFromGrayscaleApcaAndTrueApca(
              argbFromRgb(r, g, b));
          final yDiff2 = findYToApcaYDiffUsingBoundary(argbFromRgb(r, g, b));
          if (yDiff2 < yDiff) {
            print(
                'underestimate @ $r, $g, $b: ${yDiff2.toStringAsFixed(4)} < ${yDiff.toStringAsFixed(4)}');
          } else if (yDiff2 > yDiff) {
            print(
                'overestimate @ $r, $g, $b: ${yDiff2.toStringAsFixed(4)} > ${yDiff.toStringAsFixed(4)}');
          }
          if (yDiff > maxOverallDiff) {
            maxOverallDiff = yDiff;
            maxOverallDiffRgbTriple = [r, g, b];
          }
        }
      }
    }
    print(
        'maxOverallDiff: $maxOverallDiff. @ ${maxOverallDiffRgbTriple[0]}, ${maxOverallDiffRgbTriple[1]}, ${maxOverallDiffRgbTriple[2]}');
  });

  test('simpler RGB', () {
    var maxOverallDiff = -100.0;
    var maxOverallDiffRgbTriple = <int>[];
    var maxError = -1.0;
    var maxErrorRgbTriple = <int>[];
    for (int r = 0; r <= 255; r += 1) {
      for (int g = 0; g <= 255; g += 1) {
        for (int b = 0; b <= 255; b += 1) {
          // This keeps track of the maximum difference APCA Y => grayscale ARGB => XYZ Y
          // and the actual APCA Y => XYZ Y.
          if (false) {
            final yDiff = findDiffBetweenYsFoundFromGrayscaleApcaAndTrueApca(
                argbFromRgb(r, g, b));
            if (yDiff > maxOverallDiff) {
              maxOverallDiff = yDiff;
              maxOverallDiffRgbTriple = [r, g, b];
            }
          }
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
          if (false) {
            final trueApcaY = apcaYFromArgb(argbFromRgb(r, g, b));
            final boundaryArgbs = findBoundaryArgbsForApcaY(trueApcaY);
            final boundaryArgbsApcaYs = boundaryArgbs.map((triple) {
              try {
                return apcaYFromArgb(argbFromRgb(
                    triple[0].round(), triple[1].round(), triple[1].round()));
              } catch (e) {
                return 0.0;
              }
            }).toList();

            // print('true apcaY: $trueApcaY');
            // print('apcaYs of boundary argbs: $boundaryArgbsApcaYs');
            // Check if true apcaY falls in range of boundaryArgbsApcaYs
            final maxBoundaryApcaY = boundaryArgbsApcaYs.reduce(math.max);
            final minBoundaryApcaY = boundaryArgbsApcaYs.reduce(math.min);
            expect(trueApcaY,
                inInclusiveRange(minBoundaryApcaY, maxBoundaryApcaY + .0001));
          }

          // This verifies that given a RGB => APCA Y => boundary ARGBs = Ys,
          // the Y of the RGB falls in the range of the Ys.
          if (true) {
            final trueApcaY = apcaYFromArgb(argbFromRgb(r, g, b));
            final boundaryArgbsForTrueApcaY =
                findBoundaryArgbsForApcaY(trueApcaY);
            final trueY = yFromArgb(argbFromRgb(r, g, b));

            final boundaryYs = boundaryArgbsForTrueApcaY.map((triple) {
              int argb = 0;
              try {
                argb = argbFromRgb(
                    triple[0].round(), triple[1].round(), triple[1].round());
              } catch (e) {
                print('failed to convert $triple to argb');
                rethrow;
              }
              return yFromArgb(argb);
            }).toList();
            final maxBoundaryY = boundaryYs.reduce(math.max);
            final minBoundaryY = boundaryYs.reduce(math.min);
            expect(
                trueY, inInclusiveRange(minBoundaryY - 0.1, maxBoundaryY + 0.1),
                reason: 'tried $r, $g, $b');
            final minError = (trueY - minBoundaryY).abs();
            final maxError2 = (trueY - maxBoundaryY).abs();
            final error = math.max(minError, maxError2);
            if (error > maxError) {
              maxError = error;
              maxErrorRgbTriple = [r, g, b];
            }
          }
        }
      }
    }
    if (maxError > -1) {
      print(
          'maxError: $maxError. @ ${maxErrorRgbTriple[0]}, ${maxErrorRgbTriple[1]}, ${maxErrorRgbTriple[2]}');
    }
    // print(
    // 'maxOverallDiff: $maxOverallDiff. @ ${maxOverallDiffRgbTriple[0]}, ${maxOverallDiffRgbTriple[1]}, ${maxOverallDiffRgbTriple[2]}');
  });
}

double findYDiffFromBoundaryYs(double apcaY) {
  final grayscaleArgb = apcaYToGrayscaleArgb(apcaY);
  final grayscaleY = yFromArgb(grayscaleArgb);
  final boundaryYs = apcaYToBoundaryYs(apcaY);
  final diffs = boundaryYs.map((boundaryY) => (boundaryY - grayscaleY).abs());
  return diffs.reduce(math.max);
}

List<double> apcaYToBoundaryYs(double apcaY) {
  return findBoundaryArgbsForApcaY(apcaY).map((triple) {
    try {
      return yFromArgb(
          argbFromRgb(triple[0].round(), triple[1].round(), triple[1].round()));
    } catch (e) {
      return 0.0;
    }
  }).toList();
}


double apcaYFromRgbComponents(int red, int green, int blue) {
  const double mainTrc = 2.4;

// sRGB coefficients
  const double sRco = 0.2126729;
  const double sGco = 0.7151522;
  const double sBco = 0.0721750;
  double simpleExp(int channel) {
    return math.pow(channel.toDouble() / 255.0, mainTrc).toDouble();
  }

  return sRco * simpleExp(red) +
      sGco * simpleExp(green) +
      sBco * simpleExp(blue);
}

double findDiffBetweenYsFoundFromGrayscaleApcaAndTrueApca(int argb) {
  final apcaY = apcaYFromArgb(argb);
  final yIfGrayscale = apcaYToGrayscaleY(apcaY);
  final y = yFromArgb(argb);
  final yDiff = (y - yIfGrayscale).abs();
  return yDiff;
}

double apcaYToGrayscaleY(double apcaY, {bool debug = false}) {
  return yFromArgb(apcaYToGrayscaleArgb(apcaY, debug: debug));
}

double findYToApcaYDiffUsingBoundary(int argb) {
  final apcaY = apcaYFromArgb(argb);
  final grayscaleY = apcaYToGrayscaleY(apcaY);
  final boundaryYs = apcaYToBoundaryYs(apcaY);
  final diffs = boundaryYs.map((boundaryY) => (boundaryY - grayscaleY).abs());
  return diffs.reduce(math.max);
}

// final redContribution = sRco * math.pow(255.0, 2.4);

// // We have two cases, each enclosed in blocks.
// // First case: spill to G, then spill to B if needed
// {
//   // Spill to G
//   // apcaY = redContribution + sGCO * simpleExp(G)
//   // apcaY - redContribution = sGCO * simpleExp(G)
//   // (apcaY - redContribution) / sGCO = simpleExp(G)
//   // (apcaY - redContribution) / sGCO = (G / 255) ^ 2.4
//   // ((apcaY - redContribution) / sGCO) ^ (1/2.4) = (G / 255)
//   // 255 * (((apcaY - redContribution) / sGCO) ^ (1/2.4)) = G
//   final g = 255.0 * math.pow((apcaY - redContribution) / sGco, 1.0 / 2.4);
//   if (g <= 255) {
//     boundaryTriples.add([255, g, 0]);
//   } else {
//     final greenContribution = sGco * math.pow(255.0, 2.4);

//     // Spill to B
//     // apcaY = redContribution + greenContribution + sBCO * simpleExp(B)
//     // apcaY - redContribution - greenContribution = sBCO * simpleExp(B)
//     // (apcaY - redContribution - greenContribution) / sBCO = simpleExp(B)
//     // (apcaY - redContribution - greenContribution) / sBCO = (B / 255) ^ 2.4
//     // ((apcaY - redContribution - greenContribution) / sBCO) ^ (1/2.4) = (B / 255)
//     // 255 * (((apcaY - redContribution - sGCO * simpleExp(G)) / sBCO) ^ (1/2.4)) = B
//     final b = 255.0 *
//         math.pow((apcaY - redContribution - greenContribution) / sBco,
//             1.0 / 2.4);
//     boundaryTriples.add([255, 255, b]);
//   }
// }

// // Second case: spill to B, then spill to G if needed
// {
//   // Spill to B
//   // apcaY = redContribution + sBCO * simpleExp(B)
//   // apcaY - redContribution = sBCO * simpleExp(B)
//   // (apcaY - redContribution) / sBCO = simpleExp(B)
//   // (apcaY - redContribution) / sBCO = (B / 255) ^ 2.4
//   // ((apcaY - redContribution) / sBCO) ^ (1/2.4) = (B / 255)
//   // 255 * (((apcaY - redContribution) / sBCO) ^ (1/2.4)) = B
//   final b = 255.0 * math.pow((apcaY - redContribution) / sBco, 1.0 / 2.4);
//   if (b <= 255) {
//     boundaryTriples.add([255, 0, b]);
//   } else {
//     final blueContribution = sBco * math.pow(255.0, 2.4);

//     // Spill to G
//     // apcaY = redContribution + blueContribution + sGCO * simpleExp(G)
//     // apcaY - redContribution - blueContribution = sGCO * simpleExp(G)
//     // (apcaY - redContribution - blueContribution) / sGCO = simpleExp(G)
//     // (apcaY - redContribution - blueContribution) / sGCO = (G / 255) ^ 2.4
//     // ((apcaY - redContribution - blueContribution) / sGCO) ^ (1/2.4) = (G / 255)
//     // 255 * (((apcaY - redContribution - blueContribution) / sGCO) ^ (1/2.4)) = G
//     final g = 255.0 *
//         math.pow(
//             (apcaY - redContribution - blueContribution) / sGco, 1.0 / 2.4);
//     boundaryTriples.add([255, g, 255]);
//   }
// }
