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

List<double> apcaYToLstarRange(double apcaY, {bool debug = false}) {
  if (apcaY < inputClampMin) {
    final asIfGrayscale =
        lstarFromArgb(apcaYToGrayscaleArgb(apcaY, debug: debug));
    return [asIfGrayscale, asIfGrayscale];
  }
  final argbs = findBoundaryArgbsForApcaY(apcaY);
  final ys = argbs.map((e) => yFromArgb(e)).toList(growable: false);
  final minY = ys.reduce(math.min);
  final maxY = ys.reduce(math.max);
  final minLstar = lstarFromY(minY);
  final maxLstar = lstarFromY(maxY);
  return [
    (minLstar - 0.08747562332222003).clamp(0, 100),
    (maxLstar + 0.23986207179298447).clamp(0, 100)
  ];
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

List<int> findBoundaryArgbsForApcaY(double apcaY) {
  /// Find the R/G/B whole number that will generate the most progress towards
  /// fulfilling the apcaY.
  ///
  /// Note this has built-in error: R/G/B are whole numbers, and sometimes to
  /// fulfill the apcaY, we'd need ex. 250.2 of a channel, but we can't have
  /// 0.2 of a channel.
  ///
  /// The maximum error is 0.003369962535303306, calculated by iterating over
  /// all possible values of R/G/B and finding the maximum difference between
  /// [apcaYNeeded] and APCA Y contribution produced by [answer]
  double calculateContribution(
    double apcaY,
    double apcaYAlreadyFulfilled,
    double sCO,
  ) {
    final apcaYNeeded = apcaY - apcaYAlreadyFulfilled;
    final answer =
        (255.0 * math.pow(apcaYNeeded / sCO, 1.0 / 2.4)).roundToDouble();
    if (answer.isNaN) {
      assert(apcaYAlreadyFulfilled >= apcaY);
      return 0.0;
    }
    return answer;
  }

  final boundaryInts = <int>[apcaYToGrayscaleArgb(apcaY)];
  void addAnswer(int argb) {
    boundaryInts.add(argb);
  }

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
    addAnswer(argbFromRgb(maxR.round(), 0, 0));
  } else {
    const redContribution = sRco;
    final g1 = calculateContribution(apcaY, redContribution, sGco);
    if (g1 <= 255) {
      addAnswer(argbFromRgb(255, g1.round(), 0));
    } else {
      const greenContribution = sGco;
      final b1 = calculateContribution(
          apcaY, redContribution + greenContribution, sBco);
      addAnswer(argbFromRgb(255, 255, b1.round()));
    }
    final b2 = calculateContribution(apcaY, redContribution, sBco);
    if (b2 <= 255) {
      addAnswer(argbFromRgb(255, 0, b2.round()));
    } else {
      const blueContribution = sBco;
      final g2 = calculateContribution(
          apcaY, redContribution + blueContribution, sGco);
      addAnswer(argbFromRgb(255, g2.round(), 255));
    }
  }
  final maxG = (255.0 * math.pow(apcaY / sGco, 1.0 / 2.4)).toDouble();
  if (maxG <= 255) {
    addAnswer(argbFromRgb(0, maxG.round(), 0));
  } else {
    const greenContribution = sGco;
    final r1 = calculateContribution(apcaY, greenContribution, sRco);
    if (r1 <= 255) {
      addAnswer(argbFromRgb(r1.round(), 255, 0));
    } else {
      const redContribution = sRco;
      final b1 = calculateContribution(
          apcaY, greenContribution + redContribution, sBco);
      addAnswer(argbFromRgb(255, 255, b1.round()));
    }
    final b2 = calculateContribution(apcaY, greenContribution, sBco);
    if (b2 <= 255) {
      addAnswer(argbFromRgb(0, 255, b2.round()));
    } else {
      const blueContribution = sBco;
      final r2 = calculateContribution(
          apcaY, greenContribution + blueContribution, sRco);
      addAnswer(argbFromRgb(r2.round(), 255, 255));
    }
  }
  final maxB = (255.0 * math.pow(apcaY / sBco, 1.0 / 2.4)).roundToDouble();
  if (maxB <= 255) {
    addAnswer(argbFromRgb(0, 0, maxB.round()));
  } else {
    const blueContribution = sBco;
    final r1 = calculateContribution(apcaY, blueContribution, sRco);
    if (r1 <= 255) {
      addAnswer(argbFromRgb(r1.round(), 0, 255));
    } else {
      const redContribution = sRco;
      final g1 = calculateContribution(
          apcaY, blueContribution + redContribution, sGco);
      addAnswer(argbFromRgb(255, g1.round(), 255));
    }
    final g2 = calculateContribution(apcaY, blueContribution, sGco);
    if (g2 <= 255) {
      addAnswer(argbFromRgb(0, g2.round(), 255));
    } else {
      const greenContribution = sGco;
      final r2 = calculateContribution(
          apcaY, blueContribution + greenContribution, sRco);
      addAnswer(argbFromRgb(r2.round(), 255, 255));
    }
  }

  return boundaryInts;
}
