import 'dart:math' as math;
import 'dart:ui' show Color;
import 'package:libmonet/argb_srgb_xyz_lab.dart';

double lighterLstarUnsafe({
  required double lstar,
  required double contrastRatio,
}) {
  assert(lstar >= 0.0 && lstar <= 100.0,
      'lstar must be between 0 and 100, it was $lstar');
  assert(contrastRatio >= 1.0);
  final y = yFromLstar(lstar);
  // contrast ratio = (lighter + 5) / (darker + 5)
  // contrast ratio * (darker + 5) = lighter + 5
  // (contrast ratio * (darker + 5)) - 5 = lighter
  // lighter = (contrast ratio * (darker + 5)) - 5
  final lighterY = (contrastRatio * (y + 5.0)) - 5.0;
  final lighterLstar = lstarFromY(lighterY);
  return lighterLstar;
}

double darkerLstarUnsafe({
  required double lstar,
  required double contrastRatio,
}) {
  assert(lstar >= 0.0 && lstar <= 100.0,
      'lstar must be between 0 and 100, it was $lstar');
  assert(contrastRatio >= 1.0);
  final y = yFromLstar(lstar);
  // contrast ratio = (lighter + 5) / (darker + 5)
  // contrast ratio * (darker + 5) = lighter + 5
  // darker + 5 = (lighter + 5) / contrast ratio
  // darker = ((lighter + 5) / contrast ratio) - 5
  final darkerY = ((y + 5.0) / contrastRatio) - 5.0;
  final darkerLstar = lstarFromY(darkerY);
  return darkerLstar;
}

double wcagFromArgbs(int a, int b) {
  final aY = yFromArgb(a);
  final bY = yFromArgb(b);

  final max = math.max(aY, bY);
  final min = (max == aY) ? bY : aY;
  final ratio = (max + 5.0) / (min + 5.0);
  return ratio;
}

double wcagFromColors(Color a, Color b) {
  return wcagFromArgbs(a.value, b.value);
}
