import 'dart:math' as math;

import 'package:libmonet/apca.dart';
import 'package:libmonet/complex.dart';
import 'package:libmonet/debug_print.dart';

double lighterBackgroundLstar(double textLstar, double apca,
    {bool debug = false}) {
  monetDebug(debug, () => 'LIGHTER BACKGROUND L* ENTER');
  final lighterBackgroundApcaYValue =
      lighterBackgroundApcaY(lstarToApcaY(textLstar), apca);
  return apcaYToLstarRange(lighterBackgroundApcaYValue).last;
}

double lighterTextLstar(double backgroundLstar, double apca,
    {bool debug = false}) {
  monetDebug(debug, () => 'LIGHTER TEXT L* ENTER');
  final backgroundApcaY = lstarToApcaY(backgroundLstar);
  monetDebug(debug, () => 'apcaY: $backgroundApcaY');
  final lighterTextApcaYValue =
      lighterTextApcaY(backgroundApcaY, apca, debug: debug);
  if (lighterTextApcaYValue > 1.0) {
    monetDebug(debug,
        () => 'lighter text has $lighterTextApcaYValue, lets check darker');
    final darkerTextApcaYValue =
        darkerTextApcaY(backgroundApcaY, apca, debug: debug);
    if (darkerTextApcaYValue < 0) {
      final distanceFromNeededLightToMaxLight = lighterTextApcaYValue - 1.0;
      final distanceFromNeededDarkToMaxDark = 0.0 - darkerTextApcaYValue;
      if (distanceFromNeededLightToMaxLight > distanceFromNeededDarkToMaxDark) {
        monetDebug(
            debug,
            () =>
                'going with darker, lighter distance was $distanceFromNeededLightToMaxLight, darker distance was $distanceFromNeededDarkToMaxDark');
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
      return apcaYToLstarRange(darkerTextApcaYValue).last;
    }
  }
  return apcaYToLstarRange(lighterTextApcaYValue).first;
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
                'going with darker, lighter distance was $distanceFromNeededLightToMaxLight, darker distance was $distanceFromNeededDarkToMaxDark');
        return 0.0;
      } else {
        return 100.0;
      }
    }
    // WARNING: Couldn't find an obvious visual error to confirm .last is correct.
    return apcaYToLstarRange(lighterBackgroundApcaYValue).first;
  }

  // WARNING: Couldn't find an obvious visual error to confirm .last is correct.
  return apcaYToLstarRange(darkerBackgroundApcaYValue).last;
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
                'going with darker, lighter distance was $distanceFromNeededLightToMaxLight, darker distance was $distanceFromNeededDarkToMaxDark');
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
      // WARNING: Couldn't find an obvious visual error to confirm .last is correct.
      return apcaYToLstarRange(lighterTextApcaYValue).first;
    }
  }
  // WARNING: Couldn't find an obvious visual error to confirm .last is correct.
  return apcaYToLstarRange(darkerTextApcaYValue).last;
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
