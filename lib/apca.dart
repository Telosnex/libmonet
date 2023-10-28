import 'dart:math' as math;

import 'package:libmonet/argb_srgb_xyz_lab.dart';
import 'package:libmonet/debug_print.dart';

/// Calculations for APCA contrast.
/// Per [APCA landing page](https://github.com/Myndex/apca-w3/):
///   The correct code to use is right here apca-w3 in this satellite repository
/// Referring to:
///   https://github.com/Myndex/apca-w3/blob/master/src/apca-w3.js
/// Variable names and most comments are from the original source.
const double mainTrc = 2.4;

// For reverse APCA
const double mainTrcEncode = 1.0 / 2.4;

// sRGB coefficients
const double sRco = 0.2126729;
const double sGco = 0.7151522;
const double sBco = 0.0721750;

// G-4g constants for use with 2.4 exponent
const double normBg = 0.56;
const double normText = 0.57;
const double revText = 0.62;
const double revBg = 0.65;

// G-4g Clamps and Scalers
const double blkThrs = 0.022;
const double blkClmp = 1.414;
const double scaleBoW = 1.14;
const double scaleWoB = 1.14;
const double loBoWOffset = 0.027;
const double loWoBOffset = 0.027;
const double deltaYMin = 0.0005;
const double loClip = 0.1;

// MAGIC NUMBERS for UNCLAMP, for use with 0.022 & 1.414
// Magic numbers of reverseAPCA
const double mFactor = 1.94685544331710;
const double mFactInv = 1.0 / 1.94685544331710;
const double mOffsetIn = 0.03873938165714010;
const double mExpAdj = 0.2833433964208690;
const double mExp = 0.2833433964208690 / 1.414;
const double mOffsetOut = 0.3128657958707580;

// Extracted from apcaContrast in original source, so all functions can use it
// for validation.
const inputClampMin = 0.0;
const inputClampMax = 1.1;
double inBoundsApcaY(double apcaY) {
  if (apcaY < inputClampMin) {
    apcaY = inputClampMin;
  }
  if (apcaY > inputClampMax) {
    apcaY = inputClampMax;
  }

  apcaY = _fixupForBlackThreshold(apcaY);

  return apcaY;
}

int apcaYToGrayscaleArgb(double apcaY, {bool debug = false}) {
  monetDebug(debug, () => 'APCA Y TO GRAYSCALE ARGB ENTER. apcaY = $apcaY');
  // Given answer is graycale, can assume R = G = B
  // Therefore:
  // sRCO * simpleExp(R) + sGCO * simpleExp(G) + sBCO * simpleExp(B) = Y
  // is equivalent to:
  // sRCO * simpleExp(R) + sGCO * simpleExp(R) + sBCO * simpleExp(R) = Y
  // Therefore:
  // (sRCO + sGCO + sBCO) * simpleExp(X) = Y
  // simpleExp(X) = Y / (sRCO + sGCO + sBCO)
  // simpleExp(X) = (X / 255) ^ 2.4
  // Therefore:
  // (sRCO + sGCO + sBCO) * (X / 255) ^ 2.4 = Y
  // (X / 255) ^ 2.4 = (Y / (sRCO + sGCO + sBCO))
  // X / 255 = (Y / (sRCO + sGCO + sBCO)) ^ (1/2.4)
  // X = 255 * (Y / (sRCO + sGCO + sBCO)) ^ (1/2.4)
  apcaY = apcaY.clamp(0, 1.1);
  final channel = (255.0 * math.pow(apcaY / (sRco + sGco + sBco), 1.0 / 2.4))
      .round()
      .clamp(0, 255);
  return argbFromRgb(channel, channel, channel);
}

double apcaYToLstar(double apcaY, {bool debug = false}) {
  final range = apcaYToLstarRange(apcaY, debug: debug);

  if (apcaY > 0.55) {
    return range[1];
  }

  return range[0];
  // final answer = lstarFromArgb(apcaYToGrayscaleArgb(apcaY, debug: debug));
  // print('range: $range actual: $answer');
  // return answer;
}

List<double> apcaYToLstarRange(double apcaY, {bool debug = false}) {
  if (apcaY < inputClampMin) {
    final asIfGrayscale =
        lstarFromArgb(apcaYToGrayscaleArgb(apcaY, debug: debug));
    return [asIfGrayscale, asIfGrayscale];
  }
  final argbs = findBoundaryArgbsForApcaY(apcaY);
  final ys = argbs
      .map((e) => yFromArgb(
          argbFromRgb((e[0]).round(), (e[1]).round(), (e[2]).round())))
      .toList(growable: false);
  final minY = ys.reduce(math.min);
  final maxY = ys.reduce(math.max);
  final minLstar = lstarFromY(minY);
  final maxLstar = lstarFromY(maxY);
  return [minLstar, maxLstar];
}

double lstarToApcaY(double lstar) {
  return apcaYFromArgb(argbFromLstar(lstar));
}

double apcaYFromArgb(int argb) {
  double simpleExp(int channel) {
    return math.pow(channel.toDouble() / 255.0, mainTrc).toDouble();
  }

  return sRco * simpleExp(redFromArgb(argb)) +
      sGco * simpleExp(greenFromArgb(argb)) +
      sBco * simpleExp(blueFromArgb(argb));
}

enum Polarity {
  blackOnWhite,
  whiteOnBlack,
}

double _fixupForBlackThreshold(double apcaY) {
  if (apcaY > blkThrs) {
    return apcaY;
  } else {
    return apcaY + math.pow(blkThrs - apcaY, blkClmp).toDouble();
  }
}

double apcaContrastOfApcaY(double textApcaY, double backgroundApcaY) {
  const inputClampMin = 0.0;
  const inputClampMax = 1.1;
  final smallest = math.min(textApcaY, backgroundApcaY);
  final largest = math.max(textApcaY, backgroundApcaY);
  assert(smallest >= inputClampMin);
  assert(largest <= inputClampMax);

  var sapc = 0.0; // For raw SAPC value
  var outputContrast = 0.0;
  // Rational for ignore; crucial property of algorithm, present in original
  // implementation, and signals the code was ported correctly.
  // ignore: unused_local_variable
  var polarity = Polarity.blackOnWhite;

  // Soft clamps Y for either color if it is near black.
  textApcaY = _fixupForBlackThreshold(textApcaY);
  backgroundApcaY = _fixupForBlackThreshold(backgroundApcaY);

  // Return 0 Early for extremely low ∆Y
  if ((backgroundApcaY - textApcaY).abs() < deltaYMin) {
    return 0.0;
  }

  // APCA/SAPC CONTRAST - LOW CLIP (W3 LICENSE)
  if (backgroundApcaY > textApcaY) {
    // For normal polarity, black text on white (BoW)

    // Calculate the SAPC contrast value and scale
    sapc = (math.pow(backgroundApcaY, normBg) - math.pow(textApcaY, normText)) *
        scaleBoW;

    // Low Contrast smooth rollout to prevent polarity reversal and also a
    // low-clip for very low contrasts
    outputContrast = (sapc < loClip) ? 0.0 : sapc - loBoWOffset;
  } else {
    // background < text
    polarity = Polarity.whiteOnBlack;
    sapc = (math.pow(backgroundApcaY, revBg) - math.pow(textApcaY, revText)) *
        scaleWoB;
    outputContrast = (sapc > (-1.0 * loClip)) ? 0.0 : sapc + loWoBOffset;
  }

  // return Lc (lightness contrast) as a signed numeric value
  //
  // Note: Original implementation could conditionally return a string based
  // on the value of a `places` argument.
  return outputContrast * 100.0;
}

double apcaContrastOfArgb(int textArgb, int backgroundArgb) {
  return apcaContrastOfApcaY(
    apcaYFromArgb(textArgb),
    apcaYFromArgb(backgroundArgb),
  );
}

List<List<double>> findBoundaryArgbsForApcaY(double apcaY) {
  double calculateContribution(apcaY, apcaYAlreadyFulfilled, sCO) {
    final answer =
        255.0 * math.pow((apcaY - apcaYAlreadyFulfilled) / sCO, 1.0 / 2.4);
    if (answer.isNaN) {
      assert(apcaYAlreadyFulfilled >= apcaY);
      return 0.0;
    }
    return answer;
  }

  final boundaryTriples = <List<double>>[];
  // apcaY = sRCO * simpleExp(R) + sGCO * simpleExp(G) + sBCO * simpleExp(B) = apcaY
  //
  // We have to find R, G, B coordinates that generate the apcaY.
  // Let's say we have R = 255, G = 0, B = 0 and still more apcaY to consume.
  // We can't increase R, so we have to spill over to another channel.
  // Since there are two other channels, we have to work through two cases,
  // where we spill over to one channel, then the other.
  // Then, if we have more apcaY to consume, we have to spill over to the
  // remaining channel.
  // So, we have 6 cases:

  // R => spill G => spill B
  // First, determine what R would lead to apcaY given G = 0, B = 0.
  // apcaY = sRCO * simpleExp(R)
  // simpleExp(R) = apcaY / sRCO
  // (R / 255) ^ 2.4 = apcaY / sRCO
  // R / 255 = (apcaY / sRCO) ^ (1/2.4)
  // R = 255 * (apcaY / sRCO) ^ (1/2.4)
  final maxR = (255.0 * math.pow(apcaY / sRco, 1.0 / 2.4)).toDouble();
  if (maxR <= 255) {
    boundaryTriples.add([maxR, 0.0, 0.0]);
  } else {
    const redContribution = sRco;
    final g1 = calculateContribution(apcaY, redContribution, sGco);
    if (g1 <= 255) {
      boundaryTriples.add([255, g1, 0]);
    } else {
      const greenContribution = sGco;
      final b1 = calculateContribution(
          apcaY, redContribution + greenContribution, sBco);
      boundaryTriples.add([255, 255, b1]);
    }
    final b2 = calculateContribution(apcaY, redContribution, sBco);
    if (b2 <= 255) {
      boundaryTriples.add([255, 0, b2]);
    } else {
      const blueContribution = sBco;
      final g2 = calculateContribution(
          apcaY, redContribution + blueContribution, sGco);
      boundaryTriples.add([255, g2, 255]);
    }
  }
  final maxG = (255.0 * math.pow(apcaY / sGco, 1.0 / 2.4)).toDouble();
  if (maxG <= 255) {
    boundaryTriples.add([0.0, maxG, 0.0]);
  } else {
    const greenContribution = sGco;
    final r1 = calculateContribution(apcaY, greenContribution, sRco);
    if (r1 <= 255) {
      boundaryTriples.add([r1, 255, 0]);
    } else {
      const redContribution = sRco;
      final b1 = calculateContribution(
          apcaY, greenContribution + redContribution, sBco);
      boundaryTriples.add([255, 255, b1]);
    }
    final b2 = calculateContribution(apcaY, greenContribution, sBco);
    if (b2 <= 255) {
      boundaryTriples.add([0, 255, b2]);
    } else {
      const blueContribution = sBco;
      final r2 = calculateContribution(
          apcaY, greenContribution + blueContribution, sRco);
      boundaryTriples.add([r2, 255, 255]);
    }
  }
  final maxB = (255.0 * math.pow(apcaY / sBco, 1.0 / 2.4)).toDouble();
  if (maxB <= 255) {
    boundaryTriples.add([0.0, 0.0, maxB]);
  } else {
    const blueContribution = sBco;
    final r1 = calculateContribution(apcaY, blueContribution, sRco);
    if (r1 <= 255) {
      boundaryTriples.add([r1, 0, 255]);
    } else {
      const redContribution = sRco;
      final g1 = calculateContribution(
          apcaY, blueContribution + redContribution, sGco);
      boundaryTriples.add([255, g1, 255]);
    }
    final g2 = calculateContribution(apcaY, blueContribution, sGco);
    if (g2 <= 255) {
      boundaryTriples.add([0, g2, 255]);
    } else {
      const greenContribution = sGco;
      final r2 = calculateContribution(
          apcaY, blueContribution + greenContribution, sRco);
      boundaryTriples.add([r2, 255, 255]);
    }
  }

  return boundaryTriples;
}
