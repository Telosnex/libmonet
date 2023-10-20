import 'dart:math' as math;

import 'package:libmonet/argb_srgb_xyz_lab.dart';
import 'package:libmonet/complex.dart';
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
  apcaY = apcaY.clamp(0, 1.0);
  final channel = (255.0 * math.pow(apcaY / (sRco + sGco + sBco), 1.0 / 2.4))
      .round()
      .clamp(0, 255);
  return argbFromRgb(channel, channel, channel);
}

double apcaYToLstar(double apcaY, {bool debug = false}) {
  return lstarFromArgb(apcaYToGrayscaleArgb(apcaY, debug: debug));
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

double lighterBackgroundLstar(double textLstar, double apca,
    {bool debug = false}) {
  monetDebug(debug, () => 'LIGHTER BACKGROUND L* ENTER');
  final lighterBackgroundApcaYValue =
      lighterBackgroundApcaY(lstarToApcaY(textLstar), apca);
  return apcaYToLstar(lighterBackgroundApcaYValue);
}

double lighterTextLstar(double backgroundLstar, double apca,
    {bool debug = false}) {
  monetDebug(debug, () => 'LIGHTER TEXT L* ENTER');
  final backgroundApcaY = lstarToApcaY(backgroundLstar);
  monetDebug(debug, () => 'apcaY: $backgroundApcaY');
  final lighterTextApcaYValue = lighterTextApcaY(backgroundApcaY, apca, debug: debug);
  if (lighterTextApcaYValue > 1.0) {
    monetDebug(debug, () => 'lighter text has $lighterTextApcaYValue, lets check darker');
    final darkerTextApcaYValue = darkerTextApcaY(backgroundApcaY, apca, debug: debug);
    if (darkerTextApcaYValue < 0) {
      final distanceFromNeededLightToMaxLight =
          lighterTextApcaYValue - 1.0;
      final distanceFromNeededDarkToMaxDark = 0.0 - darkerTextApcaYValue;
      if (distanceFromNeededLightToMaxLight > distanceFromNeededDarkToMaxDark) {
        monetDebug(
            debug,
            () =>
                'going with darker, lighter distance was ${distanceFromNeededLightToMaxLight}, darker distance was $distanceFromNeededDarkToMaxDark');
        return 0.0;
      } else {
        monetDebug(debug, () => 'going with lighter');
        return 100.0;
      }
    } else {
      monetDebug(
          debug,
          () =>
              'asked for lighter, but darker is in bounds. darkerTextApcaYValue: $darkerTextApcaYValue');
      return apcaYToLstar(darkerTextApcaYValue);
    }
  }
  return apcaYToLstar(lighterTextApcaYValue);
}

double darkerBackgroundLstar(double textLstar, double apca,
    {bool debug = false}) {
  monetDebug(debug, () => 'DARKER BACKGROUND L* ENTER');

  final textApcaY = lstarToApcaY(textLstar);
  monetDebug(debug, () => 'apcaY: $textApcaY');

  final darkerBackgroundApcaYValue = darkerBackgroundApcaY(textApcaY, apca);
  monetDebug(
      debug, () => 'darkerBackgroundApcaYValue: $darkerBackgroundApcaYValue');
  if (darkerBackgroundApcaYValue < 0) {
    monetDebug(
        debug,
        () =>
            'darker background has $darkerBackgroundApcaYValue, lets check lighter');
    final lighterBackgroundApcaYValue = lighterBackgroundApcaY(textApcaY, apca);
    if (lighterBackgroundApcaYValue > 1) {
      final distanceFromNeededLightToMaxLight =
          lighterBackgroundApcaYValue - 1.0;
      final distanceFromNeededDarkToMaxDark = 0.0 - darkerBackgroundApcaYValue;
      if (distanceFromNeededLightToMaxLight > distanceFromNeededDarkToMaxDark) {
        monetDebug(
            debug,
            () =>
                'going with darker, lighter distance was ${distanceFromNeededLightToMaxLight}, darker distance was $distanceFromNeededDarkToMaxDark');
        return 0.0;
      } else {
        return 100.0;
      }
    }
    return apcaYToLstar(lighterBackgroundApcaYValue);
  }
  return apcaYToLstar(darkerBackgroundApcaYValue, debug: debug);
}

double darkerTextLstar(double backgroundYLstar, double apca,
    {bool debug = false}) {
  monetDebug(debug, () => 'DARKER TEXT L* ENTER');

  final backgroundApcaY = lstarToApcaY(backgroundYLstar);
  monetDebug(debug, () => 'apcaY: $backgroundApcaY');
  final darkerTextApcaYValue =
      darkerTextApcaY(backgroundApcaY, apca, debug: debug);
  monetDebug(debug, () => 'darkerTextApcaYValue: $darkerTextApcaYValue');
  if (darkerTextApcaYValue < 0) {
    monetDebug(debug,
        () => 'darker text has $darkerTextApcaYValue, lets check lighter');
    final lighterTextApcaYValue =
        lighterTextApcaY(backgroundApcaY, apca, debug: debug);
    if (lighterTextApcaYValue > 1) {
      final distanceFromNeededLightToMaxLight = lighterTextApcaYValue - 1.0;
      final distanceFromNeededDarkToMaxDark = 0.0 - darkerTextApcaYValue;
      if (distanceFromNeededLightToMaxLight > distanceFromNeededDarkToMaxDark) {
        monetDebug(
            debug,
            () =>
                'going with darker, lighter distance was ${distanceFromNeededLightToMaxLight}, darker distance was $distanceFromNeededDarkToMaxDark');
        return 0.0;
      } else {
        monetDebug(debug, () => 'going with lighter');
        return 100.0;
      }
    } else {
      monetDebug(
          debug,
          () =>
              'asked for darker, but lighter is in bounds. lighterTextApcaYValue: $lighterTextApcaYValue');
      return apcaYToLstar(lighterTextApcaYValue);
    }
  }
  return apcaYToLstar(darkerTextApcaYValue);
}

double lighterBackgroundApcaY(double textApcaY, double apca,
    {bool debug = false}) {
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
  // y = (z ^ k2 + x / k3) ^ (1/k1)
  final firstTerm = math.pow(textApcaY, normText);
  final secondTerm = sapc / scaleBoW;
  final base = firstTerm + secondTerm;
  if (base < 0) {
    final complex = Complex(0, (secondTerm - firstTerm)).pow(1 / normBg);
    monetDebug(debug, () => 'lighter background APCA Y is complex: $complex');
    return complex.real;
  }
  final bgApcaY = math.pow(base, 1.0 / normBg).toDouble();
  monetDebug(debug, () => 'lighterBackgroundApcaY bgApcaY: $bgApcaY');
  return bgApcaY;
}

double lighterTextApcaY(double backgroundApcaY, double apca,
    {bool debug = false}) {
  backgroundApcaY = inBoundsApcaY(backgroundApcaY);
  apca = apca / 100.0;
  if (apca > 0) {
    apca = -apca;
  }
  // Go backwards through apcaContrastOfApcaY with background < text
  final sapc = apca == 0.0 ? 0.0 : apca - loWoBOffset;
  // k1 = revBg
  // k2 = revText
  // k3 = scaleWoB
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
  final firstTerm = math.pow(backgroundApcaY, revBg);
  final secondTerm = sapc / scaleWoB;
  final base = firstTerm - secondTerm;
  if (base < 0) {
    Complex complexTerm2 = Complex(0, (secondTerm - firstTerm)).pow(1 / revBg);
    monetDebug(debug, () => 'lighterTextApcaY complex: $complexTerm2');
    return complexTerm2.real;
  }
  final textApcaY = math
      .pow(
        math.pow(backgroundApcaY, revBg) - (sapc / scaleWoB),
        1.0 / revText,
      )
      .toDouble();
  monetDebug(debug, () => 'lighterTextApcaY textApcaY: $textApcaY');
  return textApcaY;
}

double darkerBackgroundApcaY(
  double textApcaY,
  double apca, {
  bool debug = false,
}) {
  textApcaY = inBoundsApcaY(textApcaY);
  apca = apca / 100.0;
  if (apca > 0) {
    apca = -apca;
  }
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
  final firstTerm = sapc / scaleWoB;
  final secondTerm = math.pow(textApcaY, revText);
  final base = firstTerm + secondTerm;
  if (base < 0) {
    final complex = Complex(0, (secondTerm + firstTerm)).pow(1 / revBg);
    monetDebug(debug, () => 'darkerBackgroundApcaY complex: $complex');
    return complex.real;
  }
  final bgApcaY = math.pow(base, 1.0 / revBg).toDouble();
  return bgApcaY;
}

double darkerTextApcaY(double backgroundApcaY, double apca,
    {bool debug = false}) {
  backgroundApcaY = inBoundsApcaY(backgroundApcaY);
  monetDebug(debug, () => 'backgroundApcaY: $backgroundApcaY');
  apca = apca / 100.0;
  monetDebug(debug, () => 'apca: $apca');
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
  final firstTerm = math.pow(backgroundApcaY, normBg);
  final secondTerm = sapc / scaleBoW;
  final base = firstTerm - secondTerm;

  if (base < 0) {
// When 'secondTerm' is greater than 'firstTerm', the difference
// (firstTerm - secondTerm) is negative.
// Negative numbers present complexities when raised to fractional powers.
// To adhere to mathematical principals in the complex plane,
// we switch positions from 'firstTerm - secondTerm' to 'secondTerm - firstTerm'
// to make the difference positive.
// As we are dealing with a negative number (in the real number system),
// which corresponds to a purely imaginary number in the complex plane,
// we put this positive difference in the imaginary part (0, (secondTerm - firstTerm).abs()).
// This way, we represent the original negative real number as a positive imaginary number,
// in order to handle the power operation in the complex number system properly.
    Complex complexTerm2 =
        Complex(0, (secondTerm - firstTerm)).pow(1 / normText);

    return complexTerm2.real;
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
