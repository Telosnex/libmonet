import 'dart:ui';

extension AlphaNeue on Color {
  int get alphaNeue {
    return (a * 255.0).round() & 0xff;
  }
}
