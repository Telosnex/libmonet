import 'package:libmonet/argb_srgb_xyz_lab.dart';

const lumaRed = 21.26;
const lumaGreen = 71.52;
const lumaBlue = 7.22;

double lumaFromArgb(int argb) {
  final r = redFromArgb(argb).toDouble() / 255.0;
  final g = greenFromArgb(argb).toDouble() / 255.0;
  final b = blueFromArgb(argb).toDouble() / 255.0;
  return (lumaRed * r + lumaGreen * g + lumaBlue * b);
}

double lumaFromLstar(double lstar) {
  return lumaFromArgb(argbFromLstar(lstar));
}
