import 'dart:ui';

import 'package:test/test.dart';
import 'package:libmonet/contrast/contrast.dart';
import 'package:libmonet/core/hex_codes.dart';
import 'package:libmonet/theming/safe_colors.dart';

void main() {
  test('Either-side (colorBorder) sweep with constant bg and color', () {
    final contrasts = [
      for (var i = 1; i <= 10; i++) (i / 10).toDouble(),
    ];
    final scenarios = <(String, Color, double)>[
      ('Light+Pink', const Color(0xffC2185B), 95.0),
      ('Mid+Pink', const Color(0xffC2185B), 80.0),
      ('Dark+Pink', const Color(0xffC2185B), 15.0),
      ('Light+Blue', const Color(0xff2962FF), 95.0),
      ('Mid+Blue', const Color(0xff2962FF), 80.0),
      ('Dark+Blue', const Color(0xff2962FF), 15.0),
      ('Light+Green', const Color(0xff00C853), 95.0),
      ('Mid+Green', const Color(0xff00C853), 80.0),
      ('Dark+Green', const Color(0xff00C853), 15.0),
      ('Light+Yellow', const Color(0xffFFD600), 95.0),
      ('Mid+Yellow', const Color(0xffFFD600), 80.0),
      ('Dark+Yellow', const Color(0xffFFD600), 15.0),
      // Telosnex brand (#1177AA)
      ('Light+Telos', const Color(0xff1177aa), 95.0),
      ('Mid+Telos', const Color(0xff1177aa), 80.0),
      ('Dark+Telos', const Color(0xff1177aa), 15.0),
    ];

    for (final (name, seed, bgTone) in scenarios) {
      // Constant bg and color for the scenario
      final base = SafeColors.from(seed, backgroundTone: bgTone, contrast: 0.5, algo: Algo.apca);
      final bgHex = hexFromColor(base.background);
      final colorHex = hexFromColor(base.color);
      // ignore: avoid_print
      print('SC $name BG $bgHex COLOR $colorHex');
      for (final c in contrasts) {
        final sc = SafeColors.from(seed, backgroundTone: bgTone, contrast: c, algo: Algo.apca);
        final borderHex = hexFromColor(sc.colorBorder);
        // ignore: avoid_print
        print('SC $name c=$c BORDER $borderHex');
      }
    }
  });
}
