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
      expect(colors.colorText, isColor(0xffB4C3DE));
      expect(colors.colorIcon, isColor(0xff9AA9C3));
      expect(colors.colorHover, isColor(0xff637189));
      expect(colors.colorHoverText, isColor(0xffD2E1FD));
      expect(colors.colorSplash, isColor(0xff808EA7));
      expect(colors.colorSplashText, isColor(0xffF4F6FF));
      expect(colors.fill, isColor(0xff334157));
      expect(colors.fillText, isColor(0xffB4C3DE));
      expect(colors.fillIcon, isColor(0xff9AA9C3));
      expect(colors.fillHover, isColor(0xff637189));
      expect(colors.fillHoverText, isColor(0xffD2E1FD));
      expect(colors.fillSplash, isColor(0xff808EA7));
      expect(colors.fillSplashText, isColor(0xffF4F6FF));
      expect(colors.text, isColor(0xff818FA8));
      expect(colors.textHover, isColor(0xffC4D3EE));
      expect(colors.textHoverText, isColor(0xff47556C));
      expect(colors.textSplash, isColor(0xffA3B2CC));
      expect(colors.textSplashText, isColor(0xff132236));
    });

    test('dark mode', () {
      final colors = SafeColors.from(
        const Color(0xff334157),
        backgroundTone: 0.0,
      );
      expect(colors.color, isColor(0xff334157));
      expect(colors.colorBorder, isColor(0xff8391AA));
      expect(colors.colorText, isColor(0xffB4C3DE));
      expect(colors.colorIcon, isColor(0xff9AA9C3));
      expect(colors.colorHover, isColor(0xff637189));
      expect(colors.colorHoverText, isColor(0xffD2E1FD));
      expect(colors.colorSplash, isColor(0xff808EA7));
      expect(colors.colorSplashText, isColor(0xffF4F6FF));
      expect(colors.fill, isColor(0xff8391AA));
      expect(colors.fillText, isColor(0xffF7F8FF));
      expect(colors.fillIcon, isColor(0xffDCE8FF));
      expect(colors.fillHover, isColor(0xffA9B8D2));
      expect(colors.fillHoverText, isColor(0xff1E2D42));
      expect(colors.fillSplash, isColor(0xffC1D0EB));
      expect(colors.fillSplashText, isColor(0xff435167));
      expect(colors.text, isColor(0xffA3B2CC));
      expect(colors.textHover, isColor(0xff5B6981));
      expect(colors.textHoverText, isColor(0xffCDDCF7));
      expect(colors.textSplash, isColor(0xff8290A9));
      expect(colors.textSplashText, isColor(0xffF5F7FF));
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
      expect(colors.colorHover, isColor(${hexFromArgb(answers.colorHover.value).replaceAll('#', '0xff')}));
      expect(colors.colorHoverText, isColor(${hexFromArgb(answers.colorHoverText.value).replaceAll('#', '0xff')}));
      expect(colors.colorSplash, isColor(${hexFromArgb(answers.colorSplash.value).replaceAll('#', '0xff')}));
      expect(colors.colorSplashText, isColor(${hexFromArgb(answers.colorSplashText.value).replaceAll('#', '0xff')}));
      expect(colors.fill, isColor(${hexFromArgb(answers.fill.value).replaceAll('#', '0xff')}));
      expect(colors.fillText, isColor(${hexFromArgb(answers.fillText.value).replaceAll('#', '0xff')}));
      expect(colors.fillIcon, isColor(${hexFromArgb(answers.fillIcon.value).replaceAll('#', '0xff')}));
      expect(colors.fillHover, isColor(${hexFromArgb(answers.fillHover.value).replaceAll('#', '0xff')}));
      expect(colors.fillHoverText, isColor(${hexFromArgb(answers.fillHoverText.value).replaceAll('#', '0xff')}));
      expect(colors.fillSplash, isColor(${hexFromArgb(answers.fillSplash.value).replaceAll('#', '0xff')}));
      expect(colors.fillSplashText, isColor(${hexFromArgb(answers.fillSplashText.value).replaceAll('#', '0xff')}));
      expect(colors.text, isColor(${hexFromArgb(answers.text.value).replaceAll('#', '0xff')}));
      expect(colors.textHover, isColor(${hexFromArgb(answers.textHover.value).replaceAll('#', '0xff')}));
      expect(colors.textHoverText, isColor(${hexFromArgb(answers.textHoverText.value).replaceAll('#', '0xff')}));
      expect(colors.textSplash, isColor(${hexFromArgb(answers.textSplash.value).replaceAll('#', '0xff')}));
      expect(colors.textSplashText, isColor(${hexFromArgb(answers.textSplashText.value).replaceAll('#', '0xff')}));
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
      expect(colors.colorHover, isColor(${hexFromArgb(answers.colorHover.value).replaceAll('#', '0xff')}));
      expect(colors.colorHoverText, isColor(${hexFromArgb(answers.colorHoverText.value).replaceAll('#', '0xff')}));
      expect(colors.colorSplash, isColor(${hexFromArgb(answers.colorSplash.value).replaceAll('#', '0xff')}));
      expect(colors.colorSplashText, isColor(${hexFromArgb(answers.colorSplashText.value).replaceAll('#', '0xff')}));
      expect(colors.fill, isColor(${hexFromArgb(answers.fill.value).replaceAll('#', '0xff')}));
      expect(colors.fillText, isColor(${hexFromArgb(answers.fillText.value).replaceAll('#', '0xff')}));
      expect(colors.fillIcon, isColor(${hexFromArgb(answers.fillIcon.value).replaceAll('#', '0xff')}));
      expect(colors.fillHover, isColor(${hexFromArgb(answers.fillHover.value).replaceAll('#', '0xff')}));
      expect(colors.fillHoverText, isColor(${hexFromArgb(answers.fillHoverText.value).replaceAll('#', '0xff')}));
      expect(colors.fillSplash, isColor(${hexFromArgb(answers.fillSplash.value).replaceAll('#', '0xff')}));
      expect(colors.fillSplashText, isColor(${hexFromArgb(answers.fillSplashText.value).replaceAll('#', '0xff')}));
      expect(colors.text, isColor(${hexFromArgb(answers.text.value).replaceAll('#', '0xff')}));
      expect(colors.textHover, isColor(${hexFromArgb(answers.textHover.value).replaceAll('#', '0xff')}));
      expect(colors.textHoverText, isColor(${hexFromArgb(answers.textHoverText.value).replaceAll('#', '0xff')}));
      expect(colors.textSplash, isColor(${hexFromArgb(answers.textSplash.value).replaceAll('#', '0xff')}));
      expect(colors.textSplashText, isColor(${hexFromArgb(answers.textSplashText.value).replaceAll('#', '0xff')}));
      ''';
      // ignore: avoid_print
      print(code);
    });
  });
}
