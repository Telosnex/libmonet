import 'package:test/test.dart';
import 'package:libmonet/colorspaces/hct.dart';
import 'package:libmonet/theming/safe_colors.dart';

void main() {
  group('color border', () {
    test('does not need border handles APCA polarity x abs()', () {
      final bgTone = 93.1;
      final colorTone = 61.1;
      final colorHct = Hct.from(0, 0, colorTone);
      final color = colorHct.color;
      final safeColors = SafeColors.from(color, backgroundTone: bgTone);
      final colorBorderColor = safeColors.colorBorder;
      final colorBorderHct = Hct.fromColor(colorBorderColor);
      expect(colorBorderHct.tone.round(), 61);
    });
  });
}
