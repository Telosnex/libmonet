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
      expect(colors.colorHoveredText, isColor(0xffD4E2FE));
      expect(colors.colorSplashed, isColor(0xff808EA8));
      expect(colors.colorSplashedText, isColor(0xffF5F6FF));
      expect(colors.fill, isColor(0xff334157));
      expect(colors.fillText, isColor(0xffB5C3DE));
      expect(colors.fillIcon, isColor(0xff9BA9C4));
      expect(colors.fillHovered, isColor(0xff63718A));
      expect(colors.fillHoveredText, isColor(0xffD4E2FE));
      expect(colors.fillSplashed, isColor(0xff808EA8));
      expect(colors.fillSplashedText, isColor(0xffF5F6FF));
      expect(colors.text, isColor(0xff7B89A2));
      expect(colors.textHovered, isColor(0xffC2D0EC));
      expect(colors.textHoveredText, isColor(0xff39475E));
      expect(colors.textSplashed, isColor(0xffA2B0CB));
      expect(colors.textSplashedText, isColor(0xff051529));
    });

    test('dark mode', () {
      final colors = SafeColors.from(
        const Color(0xff334157),
        backgroundTone: 0.0,
      );
      expect(colors.color, isColor(0xff334157));
      expect(colors.colorBorder, isColor(0xff8391AB));
      expect(colors.colorText, isColor(0xffB5C3DE));
      expect(colors.colorIcon, isColor(0xff9BA9C4));
      expect(colors.colorHovered, isColor(0xff63718A));
      expect(colors.colorHoveredText, isColor(0xffD4E2FE));
      expect(colors.colorSplashed, isColor(0xff808EA8));
      expect(colors.colorSplashedText, isColor(0xffF5F6FF));
      expect(colors.fill, isColor(0xff8391AB));
      expect(colors.fillText, isColor(0xffF8F8FF));
      expect(colors.fillIcon, isColor(0xffDDE9FF));
      expect(colors.fillHovered, isColor(0xffAAB8D3));
      expect(colors.fillHoveredText, isColor(0xff142337));
      expect(colors.fillSplashed, isColor(0xffC2D0EC));
      expect(colors.fillSplashedText, isColor(0xff39475E));
      expect(colors.text, isColor(0xffA4B2CD));
      expect(colors.textHovered, isColor(0xff5B6981));
      expect(colors.textHoveredText, isColor(0xffCEDCF8));
      expect(colors.textSplashed, isColor(0xff8290AA));
      expect(colors.textSplashedText, isColor(0xffF6F8FF));
    });
  });

  group('helpers', skip: 'helpers like test generators', () {
    const color = Color(0xff334157);

    test('generate light mode test code', () {
      final answers = SafeColors.from(color, backgroundTone: 100.0);
      final code = '''
      expect(colors.color, isColor(${hexFromArgb(color.value).replaceAll('#', '0xff')}));
      expect(colors.colorBorder, isColor(${hexFromArgb(answers.colorBorder.value).replaceAll('#', '0xff')}));
      expect(colors.colorText, isColor(${hexFromArgb(answers.colorText.value).replaceAll('#', '0xff')}));
      expect(colors.colorIcon, isColor(${hexFromArgb(answers.colorIcon.value).replaceAll('#', '0xff')}));
      expect(colors.colorHovered, isColor(${hexFromArgb(answers.colorHovered.value).replaceAll('#', '0xff')}));
      expect(colors.colorHoveredText, isColor(${hexFromArgb(answers.colorHoveredText.value).replaceAll('#', '0xff')}));
      expect(colors.colorSplashed, isColor(${hexFromArgb(answers.colorSplashed.value).replaceAll('#', '0xff')}));
      expect(colors.colorSplashedText, isColor(${hexFromArgb(answers.colorSplashedText.value).replaceAll('#', '0xff')}));
      expect(colors.fill, isColor(${hexFromArgb(answers.fill.value).replaceAll('#', '0xff')}));
      expect(colors.fillText, isColor(${hexFromArgb(answers.fillText.value).replaceAll('#', '0xff')}));
      expect(colors.fillIcon, isColor(${hexFromArgb(answers.fillIcon.value).replaceAll('#', '0xff')}));
      expect(colors.fillHovered, isColor(${hexFromArgb(answers.fillHovered.value).replaceAll('#', '0xff')}));
      expect(colors.fillHoveredText, isColor(${hexFromArgb(answers.fillHoveredText.value).replaceAll('#', '0xff')}));
      expect(colors.fillSplashed, isColor(${hexFromArgb(answers.fillSplashed.value).replaceAll('#', '0xff')}));
      expect(colors.fillSplashedText, isColor(${hexFromArgb(answers.fillSplashedText.value).replaceAll('#', '0xff')}));
      expect(colors.text, isColor(${hexFromArgb(answers.text.value).replaceAll('#', '0xff')}));
      expect(colors.textHovered, isColor(${hexFromArgb(answers.textHovered.value).replaceAll('#', '0xff')}));
      expect(colors.textHoveredText, isColor(${hexFromArgb(answers.textHoveredText.value).replaceAll('#', '0xff')}));
      expect(colors.textSplashed, isColor(${hexFromArgb(answers.textSplashed.value).replaceAll('#', '0xff')}));
      expect(colors.textSplashedText, isColor(${hexFromArgb(answers.textSplashedText.value).replaceAll('#', '0xff')}));
      ''';
      // ignore: avoid_print
      print(code);
    });

    test('generate dark mode test code', () {
      final answers = SafeColors.from(color, backgroundTone: 0.0);
      final code = '''
      expect(colors.color, isColor(${hexFromArgb(color.value).replaceAll('#', '0xff')}));
      expect(colors.colorBorder, isColor(${hexFromArgb(answers.colorBorder.value).replaceAll('#', '0xff')}));
      expect(colors.colorText, isColor(${hexFromArgb(answers.colorText.value).replaceAll('#', '0xff')}));
      expect(colors.colorIcon, isColor(${hexFromArgb(answers.colorIcon.value).replaceAll('#', '0xff')}));
      expect(colors.colorHovered, isColor(${hexFromArgb(answers.colorHovered.value).replaceAll('#', '0xff')}));
      expect(colors.colorHoveredText, isColor(${hexFromArgb(answers.colorHoveredText.value).replaceAll('#', '0xff')}));
      expect(colors.colorSplashed, isColor(${hexFromArgb(answers.colorSplashed.value).replaceAll('#', '0xff')}));
      expect(colors.colorSplashedText, isColor(${hexFromArgb(answers.colorSplashedText.value).replaceAll('#', '0xff')}));
      expect(colors.fill, isColor(${hexFromArgb(answers.fill.value).replaceAll('#', '0xff')}));
      expect(colors.fillText, isColor(${hexFromArgb(answers.fillText.value).replaceAll('#', '0xff')}));
      expect(colors.fillIcon, isColor(${hexFromArgb(answers.fillIcon.value).replaceAll('#', '0xff')}));
      expect(colors.fillHovered, isColor(${hexFromArgb(answers.fillHovered.value).replaceAll('#', '0xff')}));
      expect(colors.fillHoveredText, isColor(${hexFromArgb(answers.fillHoveredText.value).replaceAll('#', '0xff')}));
      expect(colors.fillSplashed, isColor(${hexFromArgb(answers.fillSplashed.value).replaceAll('#', '0xff')}));
      expect(colors.fillSplashedText, isColor(${hexFromArgb(answers.fillSplashedText.value).replaceAll('#', '0xff')}));
      expect(colors.text, isColor(${hexFromArgb(answers.text.value).replaceAll('#', '0xff')}));
      expect(colors.textHovered, isColor(${hexFromArgb(answers.textHovered.value).replaceAll('#', '0xff')}));
      expect(colors.textHoveredText, isColor(${hexFromArgb(answers.textHoveredText.value).replaceAll('#', '0xff')}));
      expect(colors.textSplashed, isColor(${hexFromArgb(answers.textSplashed.value).replaceAll('#', '0xff')}));
      expect(colors.textSplashedText, isColor(${hexFromArgb(answers.textSplashedText.value).replaceAll('#', '0xff')}));
      ''';
      // ignore: avoid_print
      print(code);
    });
  });
}
