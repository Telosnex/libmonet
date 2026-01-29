import 'dart:ui';

import 'package:libmonet/hex_codes.dart';
import 'package:libmonet/safe_colors.dart';
import 'package:flutter_test/flutter_test.dart';

import 'utils/color_matcher.dart';

void main() {
  group('#334157', () {
    test('light mode', () {
      final colors = SafeColors.from(
        const Color(0xff334157),
        backgroundTone: 100.0,
      );
      expect(colors.color, isColor(0xff334157));
      expect(colors.colorBorder, isColor(0xff334157));
      expect(colors.colorText, isColor(0xffB5C3DE));
      expect(colors.colorIcon, isColor(0xff9BA9C4));
      expect(colors.colorHovered, isColor(0xff63718A));
      expect(colors.colorHoveredText, isColor(0xffD4E3FF));
      expect(colors.colorSplashed, isColor(0xff808EA8));
      expect(colors.colorSplashedText, isColor(0xffF6F7FF));
      expect(colors.fill, isColor(0xffA4B3CD));
      expect(colors.fillText, isColor(0xff0B1A2F));
      expect(colors.fillIcon, isColor(0xff3A485E));
      expect(colors.fillHovered, isColor(0xff7B89A3));
      expect(colors.fillHoveredText, isColor(0xffDCE7FF));
      expect(colors.fillSplashed, isColor(0xff5E6C84));
      expect(colors.fillSplashedText, isColor(0xffBDCBE7));
      expect(colors.text, isColor(0xff7B89A2));
      expect(colors.textHovered, isColor(0xffC2D0EC));
      expect(colors.textHoveredText, isColor(0xff3B495F));
      expect(colors.textSplashed, isColor(0xffA2B0CB));
      expect(colors.textSplashedText, isColor(0xff051529));
    });

    test('dark mode', () {
      final colors = SafeColors.from(
        const Color(0xff334157),
        backgroundTone: 0.0,
      );
      expect(colors.color, isColor(0xff334157));
      expect(colors.colorBorder, isColor(0xff76849D));
      expect(colors.colorText, isColor(0xffB5C3DE));
      expect(colors.colorIcon, isColor(0xff9BA9C4));
      expect(colors.colorHovered, isColor(0xff63718A));
      expect(colors.colorHoveredText, isColor(0xffD4E3FF));
      expect(colors.colorSplashed, isColor(0xff808EA8));
      expect(colors.colorSplashedText, isColor(0xffF6F7FF));
      expect(colors.fill, isColor(0xff8391AB));
      expect(colors.fillText, isColor(0xffFAF9FF));
      expect(colors.fillIcon, isColor(0xffDFE9FF));
      expect(colors.fillHovered, isColor(0xffABB9D4));
      expect(colors.fillHoveredText, isColor(0xff233147));
      expect(colors.fillSplashed, isColor(0xffC3D2ED));
      expect(colors.fillSplashedText, isColor(0xff515F76));
      expect(colors.text, isColor(0xffA4B2CD));
      expect(colors.textHovered, isColor(0xff5B6981));
      expect(colors.textHoveredText, isColor(0xffCFDDF9));
      expect(colors.textSplashed, isColor(0xff8290AA));
      expect(colors.textSplashedText, isColor(0xffF8F8FF));
    });
  });

  group('helpers', skip: 'helpers like test generators', () {
    const color = Color(0xff334157);

    test('generate light mode test code', () {
      final answers = SafeColors.from(color, backgroundTone: 100.0);
      final code = '''
      expect(colors.color, isColor(${hexFromArgb(color.argb).replaceAll('#', '0xff')}));
      expect(colors.colorBorder, isColor(${hexFromArgb(answers.colorBorder.argb).replaceAll('#', '0xff')}));
      expect(colors.colorText, isColor(${hexFromArgb(answers.colorText.argb).replaceAll('#', '0xff')}));
      expect(colors.colorIcon, isColor(${hexFromArgb(answers.colorIcon.argb).replaceAll('#', '0xff')}));
      expect(colors.colorHovered, isColor(${hexFromArgb(answers.colorHovered.argb).replaceAll('#', '0xff')}));
      expect(colors.colorHoveredText, isColor(${hexFromArgb(answers.colorHoveredText.argb).replaceAll('#', '0xff')}));
      expect(colors.colorSplashed, isColor(${hexFromArgb(answers.colorSplashed.argb).replaceAll('#', '0xff')}));
      expect(colors.colorSplashedText, isColor(${hexFromArgb(answers.colorSplashedText.argb).replaceAll('#', '0xff')}));
      expect(colors.fill, isColor(${hexFromArgb(answers.fill.argb).replaceAll('#', '0xff')}));
      expect(colors.fillText, isColor(${hexFromArgb(answers.fillText.argb).replaceAll('#', '0xff')}));
      expect(colors.fillIcon, isColor(${hexFromArgb(answers.fillIcon.argb).replaceAll('#', '0xff')}));
      expect(colors.fillHovered, isColor(${hexFromArgb(answers.fillHovered.argb).replaceAll('#', '0xff')}));
      expect(colors.fillHoveredText, isColor(${hexFromArgb(answers.fillHoveredText.argb).replaceAll('#', '0xff')}));
      expect(colors.fillSplashed, isColor(${hexFromArgb(answers.fillSplashed.argb).replaceAll('#', '0xff')}));
      expect(colors.fillSplashedText, isColor(${hexFromArgb(answers.fillSplashedText.argb).replaceAll('#', '0xff')}));
      expect(colors.text, isColor(${hexFromArgb(answers.text.argb).replaceAll('#', '0xff')}));
      expect(colors.textHovered, isColor(${hexFromArgb(answers.textHovered.argb).replaceAll('#', '0xff')}));
      expect(colors.textHoveredText, isColor(${hexFromArgb(answers.textHoveredText.argb).replaceAll('#', '0xff')}));
      expect(colors.textSplashed, isColor(${hexFromArgb(answers.textSplashed.argb).replaceAll('#', '0xff')}));
      expect(colors.textSplashedText, isColor(${hexFromArgb(answers.textSplashedText.argb).replaceAll('#', '0xff')}));
      ''';
      // ignore: avoid_print
      print(code);
    });

    test('generate dark mode test code', () {
      final answers = SafeColors.from(color, backgroundTone: 0.0);
      final code = '''
      expect(colors.color, isColor(${hexFromArgb(color.argb).replaceAll('#', '0xff')}));
      expect(colors.colorBorder, isColor(${hexFromArgb(answers.colorBorder.argb).replaceAll('#', '0xff')}));
      expect(colors.colorText, isColor(${hexFromArgb(answers.colorText.argb).replaceAll('#', '0xff')}));
      expect(colors.colorIcon, isColor(${hexFromArgb(answers.colorIcon.argb).replaceAll('#', '0xff')}));
      expect(colors.colorHovered, isColor(${hexFromArgb(answers.colorHovered.argb).replaceAll('#', '0xff')}));
      expect(colors.colorHoveredText, isColor(${hexFromArgb(answers.colorHoveredText.argb).replaceAll('#', '0xff')}));
      expect(colors.colorSplashed, isColor(${hexFromArgb(answers.colorSplashed.argb).replaceAll('#', '0xff')}));
      expect(colors.colorSplashedText, isColor(${hexFromArgb(answers.colorSplashedText.argb).replaceAll('#', '0xff')}));
      expect(colors.fill, isColor(${hexFromArgb(answers.fill.argb).replaceAll('#', '0xff')}));
      expect(colors.fillText, isColor(${hexFromArgb(answers.fillText.argb).replaceAll('#', '0xff')}));
      expect(colors.fillIcon, isColor(${hexFromArgb(answers.fillIcon.argb).replaceAll('#', '0xff')}));
      expect(colors.fillHovered, isColor(${hexFromArgb(answers.fillHovered.argb).replaceAll('#', '0xff')}));
      expect(colors.fillHoveredText, isColor(${hexFromArgb(answers.fillHoveredText.argb).replaceAll('#', '0xff')}));
      expect(colors.fillSplashed, isColor(${hexFromArgb(answers.fillSplashed.argb).replaceAll('#', '0xff')}));
      expect(colors.fillSplashedText, isColor(${hexFromArgb(answers.fillSplashedText.argb).replaceAll('#', '0xff')}));
      expect(colors.text, isColor(${hexFromArgb(answers.text.argb).replaceAll('#', '0xff')}));
      expect(colors.textHovered, isColor(${hexFromArgb(answers.textHovered.argb).replaceAll('#', '0xff')}));
      expect(colors.textHoveredText, isColor(${hexFromArgb(answers.textHoveredText.argb).replaceAll('#', '0xff')}));
      expect(colors.textSplashed, isColor(${hexFromArgb(answers.textSplashed.argb).replaceAll('#', '0xff')}));
      expect(colors.textSplashedText, isColor(${hexFromArgb(answers.textSplashedText.argb).replaceAll('#', '0xff')}));
      ''';
      // ignore: avoid_print
      print(code);
    });
  });
}
