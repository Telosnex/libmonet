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

double apcaContrast(double textApcaY, double backgroundApcaY) {
  const inputClampMin = 0.0;
  const inputClampMax = 1.1;
  final smallest = math.min(textApcaY, backgroundApcaY);
  final largest = math.max(textApcaY, backgroundApcaY);
  assert(smallest >= inputClampMin);
  assert(largest <= inputClampMax);

  var sapc = 0.0; // For raw SAPC value
  var outputContrast = 0.0;

  // Ignore unused variable; crucial step in algortihm, in original 
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
    outputContrast = (sapc < loClip) ? 0 : sapc - loBoWOffset;
  } else {
    polarity = Polarity.whiteOnBlack;
    sapc = (math.pow(backgroundApcaY, revBg) - math.pow(textApcaY, revText)) *
        scaleWoB;
    outputContrast = (sapc > loClip) ? 0.0 : sapc + loWoBOffset;
  }

  // return Lc (lightness contrast) as a signed numeric value
  // Note: Original implementation could conditionally return a string based
  // on the value of a `places` argument.
  return outputContrast;
}
