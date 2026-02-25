import 'dart:ui';

import 'package:libmonet/core/hex_codes.dart';
import 'package:libmonet/libmonet.dart';
import 'package:libmonet/theming/palette.dart';
import 'package:test/test.dart';

import '../utils/color_matcher.dart';

void main() {
  group('#334157', () {
    test('light mode', () {
      final colors = Palette.from(
        const Color(0xff334157),
        backgroundTone: 100.0,
      );
      expect(colors.color, isColor(0xff334157));
      expect(colors.colorBorder, isColor(0xff334157));
      expect(colors.colorText, isColor(0xffB2C1DC));
      expect(colors.colorIcon, isColor(0xff98A7C1));
      expect(colors.colorHovered, isColor(0xff5C6A82));
      expect(colors.colorHoveredText, isColor(0xffCCDBF6));
      expect(colors.colorSplashed, isColor(0xff7988A1));
      expect(colors.colorSplashedText, isColor(0xffEBF1FF));
      expect(colors.fill, isColor(0xffA4B3CD));
      expect(colors.fillText, isColor(0xff0B1A2F));
      expect(colors.fillIcon, isColor(0xff3A485E));
      expect(colors.fillHovered, isColor(0xff7B89A3));
      expect(colors.fillHoveredText, isColor(0xffEDF2FF));
      expect(colors.fillSplashed, isColor(0xff5E6C84));
      expect(colors.fillSplashedText, isColor(0xffCDDCF7));
      expect(colors.text, isColor(0xff7B89A2));
      expect(colors.textHovered, isColor(0xffC2D0EC));
      expect(colors.textHoveredText, isColor(0xff3B495F));
      expect(colors.textSplashed, isColor(0xffA2B0CB));
      expect(colors.textSplashedText, isColor(0xff051529));
    });

    test('dark mode', () {
      final colors = Palette.from(
        const Color(0xff334157),
        backgroundTone: 0.0,
      );
      expect(colors.color, isColor(0xff334157));
      expect(colors.colorBorder, isColor(0xff45536A));
      expect(colors.colorText, isColor(0xffB2C1DC));
      expect(colors.colorIcon, isColor(0xff98A7C1));
      expect(colors.colorHovered, isColor(0xff5C6A82));
      expect(colors.colorHoveredText, isColor(0xffCCDBF6));
      expect(colors.colorSplashed, isColor(0xff7988A1));
      expect(colors.colorSplashedText, isColor(0xffEBF1FF));
      expect(colors.fill, isColor(0xff7D8BA4));
      expect(colors.fillText, isColor(0xffEFF3FF));
      expect(colors.fillIcon, isColor(0xffD3E1FD));
      expect(colors.fillHovered, isColor(0xffA2B0CB));
      expect(colors.fillHoveredText, isColor(0xff051529));
      expect(colors.fillSplashed, isColor(0xffBAC8E4));
      expect(colors.fillSplashedText, isColor(0xff2F3D53));
      expect(colors.text, isColor(0xffA1AFCA));
      expect(colors.textHovered, isColor(0xff54627A));
      expect(colors.textHoveredText, isColor(0xffC7D6F1));
      expect(colors.textSplashed, isColor(0xff7B8AA3));
      expect(colors.textSplashedText, isColor(0xffEDF2FF));
    });
  });

  group('regression', () {
    test('#02174E should have blue border, not white', () {
      // Very dark blue on very dark background (both ~tone 10) should get
      // a lighter blue border (~tone 50), not an extreme white fallback.
      // The L* is conservative to ensure chromatic colors meet contrast.
      final colors = Palette.from(
        const Color(0xff02174E),
        backgroundTone: 10.0,
      );
      expect(colors.color, isColor(0xff02174E));
      expect(colors.colorBorder, isColor(0xff415189)); // blue at ~tone 38
    });

    test('#D29C57 should have darker border, not lighter', () {
      // Golden-brown (T≈68) on a warm light background (T≈83).
      // The border should be a subtle shadow darker than the surface,
      // not identical to it (the old fast-path returned the base tone).
      final colors = Palette.from(
        const Color(0xffD29C57),
        backgroundTone: lstarFromArgb(0xffFFCA88),
      );
      expect(colors.color, isColor(0xffD29C57));
      expect(colors.colorBorder, isColor(0xffD29C57)); // same as input (already meets Lc 15)
    });

    test('#D29C57 should have darker border, not lighter', () {
      // Very dark blue on very dark background (both ~tone 10) should get
      // a lighter blue border (~tone 50), not an extreme white fallback.
      // The L* is conservative to ensure chromatic colors meet contrast.
      final colors = Palette.from(
        const Color(0xffD29C57),
        backgroundTone: lstarFromArgb(0xffFFCA88),
      );
      expect(colors.color, isColor(0xffD29C57));
      expect(colors.colorBorder, isColor(0xffD29C57)); // same as input (already meets Lc 15)
    });

    test('#A57B43 has darker border visually, feels intense as stroke', () {
      // Very dark blue on very dark background (both ~tone 10) should get
      // a lighter blue border (~tone 50), not an extreme white fallback.
      // The L* is conservative to ensure chromatic colors meet contrast.
      final colors = Palette.from(
        const Color(0xffA57B43),
        backgroundTone: lstarFromArgb(0xff986E38),
      );
      expect(colors.color, isColor(0xffA57B43));
      expect(colors.colorBorder, isColor(0xff76511D)); // subtle shadow, not harsh hole
      expect(lstarFromArgb(colors.color.argb), closeTo(54.627, 0.001));
      expect(lstarFromArgb(colors.colorBorder.argb), closeTo(37.527, 0.001));
    });
  });

  group('helpers', skip: 'test generators', () {
    const color = Color(0xff334157);

    test('generate light mode test code', () {
      final answers = Palette.from(color, backgroundTone: 100.0);
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
      final answers = Palette.from(color, backgroundTone: 0.0);
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
