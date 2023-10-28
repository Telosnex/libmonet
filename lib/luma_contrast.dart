import 'dart:math' as math;
import 'package:libmonet/argb_srgb_xyz_lab.dart';
import 'package:libmonet/luma.dart';

List<double> lumaToLstarRange(double luma, {bool debug = false}) {
  final argbs = findBoundaryArgbsForLuma(luma);
  final lstars = argbs.map((e) => lstarFromArgb(e)).toList(growable: false);
  final minLstar = lstars.reduce(math.min);
  final maxLstar = lstars.reduce(math.max);
  return [
    (minLstar - 0.24766520401936987).clamp(0, 100),
    (maxLstar + 0.008416650634032408).clamp(0, 100)
  ];
}

int grayscaleArgbFromLuma(double luma) {
  // xR + yG + zB = luma
  // R = G = B
  // xRGB + yRGB + zRGB = luma
  // RGB * (x + y + z) = luma
  // RGB = luma / (x + y + z)
  final rgbNormalized = (luma / (lumaRed + lumaGreen + lumaBlue));
  final rgb = (255.0 * rgbNormalized).round();
  return argbFromRgb(rgb, rgb, rgb);
}

List<int> findBoundaryArgbsForLuma(double luma) {
  /// Find the R/G/B whole number that will generate the most progress towards
  /// fulfilling the luma.
  ///
  /// Note this has built-in error: R/G/B are whole numbers, and sometimes to
  /// fulfill the luma, we'd need ex. 250.2 of a channel, but we can't have
  /// 0.2 of a channel.
  ///
  /// The maximum error is 0.003369962535303306, calculated by iterating over
  /// all possible values of R/G/B and finding the maximum difference between
  /// [apcaYNeeded] and APCA Y contribution produced by [answer]
  double getChannel(
    double lumaRequired,
    double lumaCreatedSoFar,
    double thisChannelsCoefficient,
  ) {
    final lumaNeeded = lumaRequired - lumaCreatedSoFar;
    final answer =
        (255.0 * lumaNeeded / thisChannelsCoefficient).roundToDouble();
    return answer;
  }

  final boundaryInts = <int>[grayscaleArgbFromLuma(luma)];
  void addAnswer(int argb) {
    boundaryInts.add(argb);
  }

  // luma = lumaR * R + lumaG * G + lumaB * B
  //
  // We have to find R, G, B coordinates that generate the luma.
  //
  // Let's say we have R = 255, G = 0, B = 0 and still more luma to consume.
  //
  // We can't increase R, so we have to spill over to another channel.
  //
  // Since there are two other channels, we have to work through two cases,
  // where we spill over to one channel, then the other.
  //
  // Then, if we have more luma to consume, we have to spill over to the
  // remaining channel.
  //
  // That gives use a basic outline of:
  // R => G => B
  // R => B => G
  // G => R => B
  // G => B => R
  // B => R => G
  // B => G => R
  final maxR = (255.0 * luma / lumaRed).toDouble();
  if (maxR <= 255) {
    addAnswer(argbFromRgb(maxR.round(), 0, 0));
  } else {
    final g1 = getChannel(luma, lumaRed, lumaGreen);
    if (g1 <= 255) {
      addAnswer(argbFromRgb(255, g1.round(), 0));
    } else {
      final b1 = getChannel(luma, lumaRed + lumaGreen, lumaBlue);
      addAnswer(argbFromRgb(255, 255, b1.round()));
    }
    final b2 = getChannel(luma, lumaRed, lumaBlue);
    if (b2 <= 255) {
      addAnswer(argbFromRgb(255, 0, b2.round()));
    } else {
      final g2 = getChannel(luma, lumaRed + lumaBlue, lumaGreen);
      addAnswer(argbFromRgb(255, g2.round(), 255));
    }
  }
  final maxG = (255.0 * luma / lumaGreen).toDouble();
  if (maxG <= 255) {
    addAnswer(argbFromRgb(0, maxG.round(), 0));
  } else {
    final r1 = getChannel(luma, lumaGreen, lumaRed);
    if (r1 <= 255) {
      addAnswer(argbFromRgb(r1.round(), 255, 0));
    } else {
      final b1 = getChannel(luma, lumaGreen + lumaRed, lumaBlue);
      addAnswer(argbFromRgb(255, 255, b1.round()));
    }
    final b2 = getChannel(luma, lumaGreen, lumaBlue);
    if (b2 <= 255) {
      addAnswer(argbFromRgb(0, 255, b2.round()));
    } else {
      final r2 = getChannel(luma, lumaGreen + lumaBlue, lumaRed);
      addAnswer(argbFromRgb(r2.round(), 255, 255));
    }
  }
  final maxB = (255.0 * luma / lumaBlue).toDouble();
  if (maxB <= 255) {
    addAnswer(argbFromRgb(0, 0, maxB.round()));
  } else {
    final r1 = getChannel(luma, lumaBlue, lumaRed);
    if (r1 <= 255) {
      addAnswer(argbFromRgb(r1.round(), 0, 255));
    } else {
      final g1 = getChannel(luma, lumaBlue + lumaRed, lumaGreen);
      addAnswer(argbFromRgb(255, g1.round(), 255));
    }
    final g2 = getChannel(luma, lumaBlue, lumaGreen);
    if (g2 <= 255) {
      addAnswer(argbFromRgb(0, g2.round(), 255));
    } else {
      final r2 = getChannel(luma, lumaBlue + lumaGreen, lumaRed);
      addAnswer(argbFromRgb(r2.round(), 255, 255));
    }
  }

  return boundaryInts;
}
