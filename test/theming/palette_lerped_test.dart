import 'dart:ui';

import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/colorspaces/hct.dart';
import 'package:libmonet/theming/interpolation_style.dart';
import 'package:libmonet/theming/palette.dart';
import 'package:libmonet/theming/palette_lerped.dart';
import 'package:test/test.dart';

void main() {
  Palette palette(
    Color color, {
    required double backgroundTone,
    required ColorModel colorModel,
  }) {
    return Palette.from(
      color,
      backgroundTone: backgroundTone,
      colorModel: colorModel,
    );
  }

  group('PaletteLerped interpolationStyle', () {
    for (final model in ColorModel.values) {
      group(model.label, () {
        late Palette a;
        late Palette b;

        setUp(() {
          a = palette(
            const Color(0xffff0000),
            backgroundTone: 20,
            colorModel: model,
          );
          b = palette(
            const Color(0xff0000ff),
            backgroundTone: 80,
            colorModel: model,
          );
        });

        test('defaults to cartesian interpolation', () {
          final lerped = PaletteLerped(a: a, b: b, t: 0.5);
          final explicit = PaletteLerped(
            a: a,
            b: b,
            t: 0.5,
            interpolationStyle: InterpolationStyle.cartesian,
          );
          final expected = Hct.lerpLoseHueAndChroma(
            a.color,
            b.color,
            0.5,
            model: model,
          );

          expect(lerped.interpolationStyle, InterpolationStyle.cartesian);
          expect(lerped.color, expected);
          expect(explicit.color, expected);
        });

        test('polar interpolation delegates to HCT shortest-hue lerp', () {
          final lerped = PaletteLerped(
            a: a,
            b: b,
            t: 0.5,
            interpolationStyle: InterpolationStyle.polar,
          );
          final expected = Hct.lerpKeepHue(a.color, b.color, 0.5, model: model);

          expect(lerped.color, expected);
        });

        test(
          'cartesian and polar follow different paths for chromatic colors',
          () {
            final cartesian = PaletteLerped(
              a: a,
              b: b,
              t: 0.5,
              interpolationStyle: InterpolationStyle.cartesian,
            );
            final polar = PaletteLerped(
              a: a,
              b: b,
              t: 0.5,
              interpolationStyle: InterpolationStyle.polar,
            );

            expect(cartesian.color, isNot(polar.color));
          },
        );
      });
    }

    test('clamps endpoint colors exactly', () {
      final a = palette(
        const Color(0xff1565c0),
        backgroundTone: 12,
        colorModel: ColorModel.kDefault,
      );
      final b = palette(
        const Color(0xffffa000),
        backgroundTone: 94,
        colorModel: ColorModel.kDefault,
      );

      for (final style in InterpolationStyle.values) {
        expect(
          PaletteLerped(
            a: a,
            b: b,
            t: -1,
            interpolationStyle: style,
          ).background,
          a.background,
        );
        expect(
          PaletteLerped(a: a, b: b, t: 2, interpolationStyle: style).background,
          b.background,
        );
      }
    });

    test('interpolationStyle participates in equality and hashCode', () {
      final a = palette(
        const Color(0xff1565c0),
        backgroundTone: 12,
        colorModel: ColorModel.kDefault,
      );
      final b = palette(
        const Color(0xff7b1fa2),
        backgroundTone: 12,
        colorModel: ColorModel.kDefault,
      );
      final cartesian = PaletteLerped(
        a: a,
        b: b,
        t: 0.5,
        interpolationStyle: InterpolationStyle.cartesian,
      );
      final sameCartesian = PaletteLerped(
        a: a,
        b: b,
        t: 0.5,
        interpolationStyle: InterpolationStyle.cartesian,
      );
      final polar = PaletteLerped(
        a: a,
        b: b,
        t: 0.5,
        interpolationStyle: InterpolationStyle.polar,
      );

      expect(cartesian, sameCartesian);
      expect(cartesian.hashCode, sameCartesian.hashCode);
      expect(cartesian, isNot(polar));
    });
  });
}
