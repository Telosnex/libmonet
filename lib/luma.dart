import 'package:libmonet/argb_srgb_xyz_lab.dart';

// sRGB luma coefficients (Rec. 709), scaled by 100 for 0-100 range output.
// These operate on gamma-encoded sRGB values, not linear RGB.
// Standard values: R=0.2126, G=0.7152, B=0.0722
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
