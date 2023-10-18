import 'dart:math' as math;

import 'package:libmonet/argb_srgb_xyz_lab.dart';

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

int apcaYToGrayscaleArgb(double apcaY) {
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
  final channel = (255.0 * math.pow(apcaY / (sRco + sGco + sBco), 1.0 / 2.4))
      .round()
      .clamp(0, 255);
  return argbFromRgb(channel, channel, channel);
}

double apcaYToLstar(double apcaY) {
  return lstarFromArgb(apcaYToGrayscaleArgb(apcaY));
}

double lstarToApcaY(double lstar) {
  return argbToApcaY(argbFromLstar(lstar));
}

double argbToApcaY(int argb) {
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

double lighterBackgroundLstar(double textLstar, double apca) {
  final lighterBackgroundApcaYValue =
      lighterBackgroundApcaY(lstarToApcaY(textLstar), apca);
  return apcaYToLstar(lighterBackgroundApcaYValue);
}

double lighterTextLstar(double backgroundLstar, double apca) {
  final lighterTextApcaYValue =
      lighterTextApcaY(lstarToApcaY(backgroundLstar), apca);
  return apcaYToLstar(lighterTextApcaYValue);
}

double darkerBackgroundLstar(double textLstar, double apca) {
  final darkerBackgroundApcaYValue =
      darkerBackgroundApcaY(lstarToApcaY(textLstar), apca);
  return apcaYToLstar(darkerBackgroundApcaYValue);
}

double darkerTextLstar(double backgroundYLstar, double apca) {
  final darkerTextApcaYValue =
      darkerTextApcaY(lstarToApcaY(backgroundYLstar), apca);
  return apcaYToLstar(darkerTextApcaYValue);
}

double lighterBackgroundApcaY(double textApcaY, double apca) {
  textApcaY = inBoundsApcaY(textApcaY);
  apca = apca / 100.0;
  // Go backwards through apcaContrastOfApcaY with background > text
  final sapc = apca == 0.0 ? 0.0 : apca + loBoWOffset;
  // k1 = normBg
  // k2 = normText
  // k3 = scaleBoW
  // x = sapc
  // y = backgroundApcaY
  // z = textApcaY

  // Find Y:
  // sapc = (backgroundApcaY ^ normBg - textApcaY ^ normText) * scaleBoW
  // x = (y^k1 - z^k2) * k3
  // x / k3 = y ^ k1 - z ^k2
  // x / k3 + z ^ k2 = y ^ k1
  // y ^ k1 = x / k3 + z ^ k2
  // y = (x / k3 + z ^ k2) ^ (1/k1)
  final bgApcaY = math
      .pow((sapc / scaleBoW) + math.pow(textApcaY, normText), 1.0 / normBg)
      .toDouble();
  return bgApcaY;
}

double lighterTextApcaY(double backgroundApcaY, double apca) {
  backgroundApcaY = inBoundsApcaY(backgroundApcaY);
  apca = apca / 100.0;
  // Go backwards through apcaContrastOfApcaY with background < text
  final sapc = apca == 0.0 ? 0.0 : apca - loWoBOffset;
  // k1 = normBg
  // k2 = normText
  // k3 = scaleBoW
  // x = sapc
  // y = backgroundApcaY
  // z = textApcaY

  // Find Z:
  // sapc = (backgroundApcaY ^ revBg - textApcaY ^ revText) * scaleWoB
  // x = (y^k1 - z^k2) * k3
  // x / k3 = y^k1 - z^k2
  // x / k3 + z^k2 = y^k1
  // z^k2 = (y^k1 - x / k3)
  // z = ((y^k1) - (x / k3)) ^ (1/k2)
  final textApcaY = math
      .pow(
        math.pow(backgroundApcaY, revBg) - (sapc / scaleWoB),
        1.0 / revText,
      )
      .toDouble();
  return textApcaY;
}

double darkerBackgroundApcaY(double textApcaY, double apca) {
  textApcaY = inBoundsApcaY(textApcaY);
  apca = apca / 100.0;
  // Go backwards through apcaContrastOfApcaY with background < text
  final sapc = apca == 0.0 ? 0.0 : apca - loWoBOffset;

  // k1 = revBg
  // k2 = revText
  // k3 = scaleWoB
  // x = sapc
  // y = backgroundApcaY
  // z = textApcaY

  // Find Y:
  // sapc = (backgroundApcaY ^ revBg - textApcaY ^ revText) * scaleWoB
  // x = (y^k1 - z^k2) * k3
  // x / k3 = y ^ k1 - z ^k2
  // x / k3 + z ^ k2 = y ^ k1
  // y ^ k1 = x / k3 + z ^ k2
  // y = (x / k3 + z ^ k2) ^ (1/k1)
  final base = (sapc / scaleWoB) + math.pow(textApcaY, revText);
  if (base < 0) {
    // Why?
    // #1 Raising a negative number to a fractional power returns NaN.
    // #2 What this tells us is that the text is too dark to be legible on
    //    any background at the desired contrast level (apca), even the darkest.
    // #3 The lighter functions somehow inherently fail gracefully in this
    //    case and simply return 100.0. Nothing was added to induce that.
    // Therefore, we match the behavior of the lighter functions and return
    // the lowest possible in-bounds value.
    return 0;
  }
  final bgApcaY = math.pow(base, 1.0 / revBg).toDouble();
  return bgApcaY;
}

double darkerTextApcaY(double backgroundApcaY, double apca) {
  backgroundApcaY = inBoundsApcaY(backgroundApcaY);
  apca = apca / 100.0;
  // Go backwards through apcaContrastOfApcaY with background > text
  final sapc = apca == 0.0 ? 0.0 : apca + loBoWOffset;
  // k1 = normBg
  // k2 = normText
  // k3 = scaleBoW
  // x = sapc
  // y = backgroundApcaY
  // z = textApcaY

  // Find Z:
  // sapc = (backgroundApcaY ^ normBg - textApcaY ^ normText) * scaleBow
  // x = (y^k1 - z^k2) * k3
  // x / k3 = y ^ k1 - z ^k2
  // x / k3 + z ^ k2 = y ^ k1
  // z ^ k2 = (y ^ k1 - x / k3)
  // z = ((y ^ k1) - (x / k3)) ^ (1/k2)
  final base = math.pow(backgroundApcaY, normBg) - (sapc / scaleBoW);
  if (base < 0) {
    // Why?
    // #1 Raising a negative number to a fractional power returns NaN.
    // #2 What this tells us is that the text is too dark to be legible on
    //    any background at the desired contrast level (apca), even the darkest.
    // #3 The lighter functions somehow inherently fail gracefully in this
    //    case and simply return 100.0. Nothing was added to induce that.
    // Therefore, we match the behavior of the lighter functions and return
    // the lowest possible in-bounds value.
    return 0;
  }
  final textApcaY = math
      .pow(
        base,
        1.0 / normText,
      )
      .toDouble();
  return textApcaY;
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
    argbToApcaY(textArgb),
    argbToApcaY(backgroundArgb),
  );
}