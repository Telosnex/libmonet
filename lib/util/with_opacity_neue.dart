import 'dart:ui';


extension WithOpacity on Color {
  Color withOpacityNeue(double opacity) {
    return withValues(alpha: opacity);
  }
}
