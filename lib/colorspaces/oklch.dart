import 'dart:math' as math;

import 'package:libmonet/core/argb_srgb_xyz_lab.dart';

class Oklch {
  final double hue;
  final double chroma;
  final double l;

  const Oklch(this.hue, this.chroma, this.l);

  static Oklch fromInt(int argb) {
    final xyz = xyzFromArgb(argb);
    return fromXyz(xyz[0], xyz[1], xyz[2]);
  }

  static Oklch fromXyz(double x, double y, double z) {
    final xn = x / 100.0;
    final yn = y / 100.0;
    final zn = z / 100.0;

    final lmsL = 0.8189330101 * xn + 0.3618667424 * yn - 0.1288597137 * zn;
    final lmsM = 0.0329845436 * xn + 0.9293118715 * yn + 0.0361456387 * zn;
    final lmsS = 0.0482003018 * xn + 0.2643662691 * yn + 0.6338517070 * zn;

    final lRoot = _signedCubeRoot(lmsL);
    final mRoot = _signedCubeRoot(lmsM);
    final sRoot = _signedCubeRoot(lmsS);

    final okL =
        0.2104542553 * lRoot + 0.7936177850 * mRoot - 0.0040720468 * sRoot;
    final okA =
        1.9779984951 * lRoot - 2.4285922050 * mRoot + 0.4505937099 * sRoot;
    final okB =
        0.0259040371 * lRoot + 0.7827717662 * mRoot - 0.8086757660 * sRoot;

    final chroma = math.sqrt(okA * okA + okB * okB);
    var hue = math.atan2(okB, okA) * 180.0 / math.pi;
    if (hue < 0.0) {
      hue += 360.0;
    }

    return Oklch(hue, chroma, okL);
  }

  static List<double> toXyz(double l, double chroma, double hue) {
    final hueRadians = hue * math.pi / 180.0;
    final a = chroma * math.cos(hueRadians);
    final b = chroma * math.sin(hueRadians);

    final lRoot = l + 0.3963377774 * a + 0.2158037573 * b;
    final mRoot = l - 0.1055613458 * a - 0.0638541728 * b;
    final sRoot = l - 0.0894841775 * a - 1.2914855480 * b;

    final lmsL = lRoot * lRoot * lRoot;
    final lmsM = mRoot * mRoot * mRoot;
    final lmsS = sRoot * sRoot * sRoot;

    final x = 1.2270138511 * lmsL - 0.5577999807 * lmsM + 0.2812561490 * lmsS;
    final y = -0.0405801784 * lmsL + 1.1122568696 * lmsM - 0.0716766787 * lmsS;
    final z = -0.0763812845 * lmsL - 0.4214819784 * lmsM + 1.5861632204 * lmsS;

    return [x * 100.0, y * 100.0, z * 100.0];
  }

  static int toInt(double l, double chroma, double hue) {
    final xyz = toXyz(l, chroma, hue);
    return argbFromXyz(xyz[0], xyz[1], xyz[2]);
  }

  static double _signedCubeRoot(double value) {
    if (value < 0.0) {
      return -math.pow(-value, 1.0 / 3.0).toDouble();
    }
    return math.pow(value, 1.0 / 3.0).toDouble();
  }
}
