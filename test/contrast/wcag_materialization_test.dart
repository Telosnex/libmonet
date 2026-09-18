import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/libmonet.dart';

void main() {
  test('nested fill chooses the feasible WCAG polarity instead of white', () {
    final palette = Palette.from(
      const Color(0xff1177aa),
      backgroundTone: 93,
      algo: Algo.wcag21,
    );
    double ratio(Color foreground) => Algo.wcag21.contrastBetweenArgbs(
      bgArgb: palette.fill.toARGB32(),
      fgArgb: foreground.toARGB32(),
    );
    expect(ratio(const Color(0xffffffff)), lessThan(4.5));
    expect(
      Hct.fromColor(palette.fillText).tone,
      lessThan(Hct.fromColor(palette.fill).tone),
    );
    expect(ratio(palette.fillText), greaterThanOrEqualTo(4.5));
  });

  test('branded text verifies its own RGB against the actual background', () {
    final palette = Palette.from(
      const Color(0xff7b4338),
      backgroundTone: 93,
      algo: Algo.wcag21,
      colorModel: ColorModel.cam16v11,
    );
    double ratio(Color text) => Algo.wcag21.contrastBetweenArgbs(
      bgArgb: palette.background.toARGB32(),
      fgArgb: text.toARGB32(),
    );
    expect(ratio(palette.backgroundText), greaterThanOrEqualTo(4.5));
    expect(
      ratio(palette.text),
      greaterThanOrEqualTo(4.5),
      reason: 'neutral text tone cannot be reused after changing foreground hue/chroma',
    );
  });

  test('branded text meets reachable WCAG targets without changing sibling polarity', () {
    for (final model in ColorModel.values) {
      for (final seed in [
        const Color(0xff7b4338),
        const Color(0xff0055ff),
        const Color(0xffcc2200),
        const Color(0xff00aa55),
      ]) {
        for (final background in [
          const Color(0xffffe5e0),
          const Color(0xff113355),
          const Color(0xffa08030),
          const Color(0xff336611),
        ]) {
          for (final contrast in [.5, .75, 1.0]) {
            final palette = Palette.fromColorAndBackground(
              seed,
              background,
              colorModel: model,
              algo: Algo.wcag21,
              contrast: contrast,
            );
            double tone(Color c) => Hct.fromColor(c, model: model).tone;
            final lighter = tone(palette.backgroundText) >= tone(background);
            double ratio(Color c) => Algo.wcag21.contrastBetweenArgbs(
              bgArgb: background.toARGB32(),
              fgArgb: c.toARGB32(),
            );
            final extreme = lighter
                ? const Color(0xffffffff)
                : const Color(0xff000000);
            final required = Algo.wcag21.getAbsoluteContrast(
              contrast,
              Usage.text,
            );
            expect(
              ratio(palette.text),
              greaterThanOrEqualTo(
                ratio(extreme) < required ? ratio(extreme) : required,
              ),
              reason: '$model $seed $background $contrast',
            );
            expect(tone(palette.text) >= tone(background), lighter);
            expect(tone(palette.fill) >= tone(background), lighter);
          }
        }
      }
    }
  });

  test(
    'WCAG verifies quantized RGB and preserves forced polarity across models',
    () {
      const algo = Algo.wcag21;
      for (final model in ColorModel.values) {
        for (final bgTone in [10.0, 40.0, 60.0, 94.0]) {
          final bg = Hct.colorFrom(
            200,
            model.neutralBackgroundChroma,
            bgTone,
            model: model,
          );
          final actualTone = Hct.fromColor(bg, model: model).tone;
          for (final hue in [0.0, 60.0, 120.0, 240.0, 300.0]) {
            for (final direction in ContrastDirection.values) {
              for (final dial in [.5, .75, 1.0]) {
                final chroma = model.neutralBackgroundChroma * 3;
                final tone = contrastingTone(
                  withArgb: bg.toARGB32(),
                  withTone: actualTone,
                  targetHue: hue,
                  targetChroma: chroma,
                  usage: Usage.text,
                  by: algo,
                  contrast: dial,
                  colorModel: model,
                  forceDirection: direction,
                );
                final actual = Hct.colorFrom(hue, chroma, tone, model: model);
                final extreme = direction == ContrastDirection.lighter
                    ? 100.0
                    : 0.0;
                final maxColor = Hct.colorFrom(
                  hue,
                  chroma,
                  extreme,
                  model: model,
                );
                final required = algo.getAbsoluteContrast(dial, Usage.text);
                double ratio(Color c) => algo.contrastBetweenArgbs(
                  bgArgb: bg.toARGB32(),
                  fgArgb: c.toARGB32(),
                );
                if (ratio(maxColor) >= required) {
                  expect(
                    ratio(actual),
                    greaterThanOrEqualTo(required),
                    reason: '$model $bgTone $hue $direction $dial',
                  );
                } else {
                  expect(
                    tone,
                    extreme,
                    reason: 'unreachable target cannot flip forced polarity',
                  );
                }
                expect(
                  direction == ContrastDirection.lighter
                      ? tone >= actualTone
                      : tone <= actualTone,
                  true,
                );
              }
            }
          }
        }
      }
    },
  );
}
