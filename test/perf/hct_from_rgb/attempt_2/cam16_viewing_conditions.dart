// Copied from lib/colorspaces/cam16_viewing_conditions.dart for perf testing.
// Edit freely — this is throwaway test scaffolding.

import 'dart:math' as math;

import 'argb_srgb_xyz_lab.dart';
import 'core_math.dart';

/// In traditional color spaces, a color can be identified solely by the
/// observer's measurement of the color. Color appearance models such as CAM16
/// also use information about the environment where the color was
/// observed, known as the viewing conditions.
class Cam16ViewingConditions {
  static final standard = sRgb;
  static final sRgb = Cam16ViewingConditions.make();

  final List<double> whitePoint;
  final double adaptingLuminance;
  final double backgroundLstar;
  final double surround;
  final bool discountingIlluminant;

  final double backgroundYToWhitePointY;
  final double aw;
  final double nbb;
  final double ncb;
  final double c;
  final double nC;
  final List<double> rgbD;
  final double fl;
  final double fLRoot;
  final double z;

  const Cam16ViewingConditions({
    required this.whitePoint,
    required this.adaptingLuminance,
    required this.backgroundLstar,
    required this.surround,
    required this.discountingIlluminant,
    required this.backgroundYToWhitePointY,
    required this.aw,
    required this.nbb,
    required this.ncb,
    required this.c,
    required this.nC,
    required this.rgbD,
    required this.fl,
    required this.fLRoot,
    required this.z,
  });

  factory Cam16ViewingConditions.make({
    List<double> whitePoint = whitePointD65,
    double adaptingLuminance = srgbAdaptingLuminance,
    double backgroundLstar = 50.0,
    double surround = 2.0,
    bool discountingIlluminant = false,
  }) {
    backgroundLstar = math.max(0.1, backgroundLstar);
    final xyz = whitePoint;
    final rW = xyz[0] * 0.401288 + xyz[1] * 0.650173 + xyz[2] * -0.051461;
    final gW = xyz[0] * -0.250268 + xyz[1] * 1.204414 + xyz[2] * 0.045854;
    final bW = xyz[0] * -0.002079 + xyz[1] * 0.048952 + xyz[2] * 0.953127;

    assert(surround >= 0.0 && surround <= 2.0);
    final f = 0.8 + (surround / 10.0);
    final c = (f >= 0.9)
        ? lerp(0.59, 0.69, ((f - 0.9) * 10.0))
        : lerp(0.525, 0.59, ((f - 0.8) * 10.0));
    var d = discountingIlluminant
        ? 1.0
        : f *
            (1.0 -
                ((1.0 / 3.6) * math.exp((-adaptingLuminance - 42.0) / 92.0)));
    d = (d > 1.0)
        ? 1.0
        : (d < 0.0)
            ? 0.0
            : d;
    final nc = f;

    final rgbD = <double>[
      d * (100.0 / rW) + 1.0 - d,
      d * (100.0 / gW) + 1.0 - d,
      d * (100.0 / bW) + 1.0 - d,
    ];

    final k = 1.0 / (5.0 * adaptingLuminance + 1.0);
    final k4 = k * k * k * k;
    final k4F = 1.0 - k4;

    final fl = (k4 * adaptingLuminance) +
        (0.1 * k4F * k4F * math.pow(5.0 * adaptingLuminance, 1.0 / 3.0));
    final n = yFromLstar(backgroundLstar) / whitePoint[1];

    final z = 1.48 + math.sqrt(n);

    final nbb = 0.725 / math.pow(n, 0.2);
    final ncb = nbb;

    final rgbAFactors = [
      math.pow(fl * rgbD[0] * rW / 100.0, 0.42),
      math.pow(fl * rgbD[1] * gW / 100.0, 0.42),
      math.pow(fl * rgbD[2] * bW / 100.0, 0.42)
    ];

    final rgbA = [
      (400.0 * rgbAFactors[0]) / (rgbAFactors[0] + 27.13),
      (400.0 * rgbAFactors[1]) / (rgbAFactors[1] + 27.13),
      (400.0 * rgbAFactors[2]) / (rgbAFactors[2] + 27.13),
    ];

    final aw = (40.0 * rgbA[0] + 20.0 * rgbA[1] + rgbA[2]) / 20.0 * nbb;

    return Cam16ViewingConditions(
      whitePoint: whitePoint,
      adaptingLuminance: adaptingLuminance,
      backgroundLstar: backgroundLstar,
      surround: surround,
      discountingIlluminant: discountingIlluminant,
      backgroundYToWhitePointY: n,
      aw: aw,
      nbb: nbb,
      ncb: ncb,
      c: c,
      nC: nc,
      rgbD: rgbD,
      fl: fl,
      fLRoot: math.pow(fl, 0.25).toDouble(),
      z: z,
    );
  }
}
