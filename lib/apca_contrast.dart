import 'dart:math' as math;

import 'package:libmonet/apca.dart';
import 'package:libmonet/argb_srgb_xyz_lab.dart';
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
