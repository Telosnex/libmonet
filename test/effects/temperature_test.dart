// Modified and maintained by open-source contributors, on behalf of libmonet.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:math' as math;

import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/colorspaces/hct.dart';
import 'package:libmonet/core/hex_codes.dart';
import 'package:libmonet/effects/afterimage.dart';
import 'package:libmonet/effects/temperature.dart';
import 'package:test/test.dart';

import '../utils/color_matcher.dart';

void main() {
  group('TemperatureCache', () {
    group('complement (afterimage)', () {
      test('returns valid complement for saturated red', () {
        final red = Hct.from(27.0, 113.0, 53.0);
        final cache = TemperatureCache(red);
        final complement = cache.complement;
        expect(complement.color, isColor(0xff028D8D));
      });

      test('returns valid complement for saturated blue', () {
        final blue = Hct.from(282.0, 87.0, 32.0);
        final cache = TemperatureCache(blue);
        final complement = cache.complement;
        expect(complement.color, isColor(0xff4E4E02));
      });

      test('returns valid complement for mid-chroma color', () {
        final color = Hct.from(120.0, 40.0, 50.0);
        final cache = TemperatureCache(color);
        final complement = cache.complement;
        expect(complement.color, isColor(0xff8569B3));
      });

      test('complement is approximately an involution', () {
        // Exact in chromaticity direction; gamut clamping and CAM16 hue-line
        // curvature cost a few degrees on the round trip.
        for (final hue in [0.0, 27.0, 60.0, 120.0, 200.0, 282.0, 330.0]) {
          final input = Hct.from(hue, 40.0, 50.0);
          final complement = TemperatureCache(input).complement;
          final roundTrip = TemperatureCache(complement).complement;
          final delta = (roundTrip.hue - input.hue).abs() % 360.0;
          final wrapped = delta > 180.0 ? 360.0 - delta : delta;
          expect(wrapped, lessThan(5.0),
              reason: 'complement of complement of H$hue should be ~H$hue, '
                  'was H${roundTrip.hue}');
        }
      });

      test('additive mix of input and complement is neutral', () {
        // The defining property of the afterimage complement: the white
        // point lies on the u\'v\' segment between the pair (within ~a JND).
        final red = Hct.from(27.0, 113.0, 53.0);
        final complement = TemperatureCache(red).complement;
        final (wu, wv) = whiteUvPoint;
        final (pu, pv) = uvOfArgb(red.toInt())!;
        final (qu, qv) = uvOfArgb(complement.toInt())!;
        final du = qu - pu, dv = qv - pv;
        final t =
            (((wu - pu) * du + (wv - pv) * dv) / (du * du + dv * dv))
                .clamp(0.0, 1.0);
        final xu = pu + t * du, xv = pv + t * dv;
        final err = math.sqrt(
            (wu - xu) * (wu - xu) + (wv - xv) * (wv - xv));
        expect(err, lessThan(0.004));
      });

      // When a color is achromatic (pure white/black), all hues collapse to
      // the same color; the complement is the color itself.

      test('handles pure white (tone 100, chroma 0) without NaN', () {
        final white = Hct.from(0.0, 0.0, 100.0);
        final cache = TemperatureCache(white);
        final complement = cache.complement;
        expect(complement.color, isColor(0xffffffff));
      });

      test('handles pure black (tone 0, chroma 0) without NaN', () {
        final black = Hct.from(0.0, 0.0, 0.0);
        final cache = TemperatureCache(black);
        final complement = cache.complement;
        expect(complement.color, isColor(0xff000000));
      });

      test('handles mid-gray (tone 50, chroma 0) without NaN', () {
        final gray = Hct.from(0.0, 0.0, 50.0);
        final cache = TemperatureCache(gray);
        final complement = cache.complement;
        expect(complement.color, isColor(0xff777777));
      });

      test('handles very low chroma color without NaN', () {
        final almostGray = Hct.from(180.0, 0.5, 50.0);
        final cache = TemperatureCache(almostGray);
        final complement = cache.complement;
        expect(complement.color, isColor(0xff767779));
      });
    });

    group('relativeTemperature', () {
      test('returns 0.5 for pure white', () {
        final white = Hct.from(0.0, 0.0, 100.0);
        final cache = TemperatureCache(white);

        final relTemp = cache.relativeTemperature(white);
        expect(relTemp, equals(0.5));
        expect(relTemp.isNaN, isFalse);
      });

      test('returns 0.5 for pure black', () {
        final black = Hct.from(0.0, 0.0, 0.0);
        final cache = TemperatureCache(black);

        final relTemp = cache.relativeTemperature(black);
        expect(relTemp, equals(0.5));
        expect(relTemp.isNaN, isFalse);
      });

      test('returns valid value for saturated color', () {
        final red = Hct.from(27.0, 113.0, 53.0);
        final cache = TemperatureCache(red);
        final relTemp = cache.relativeTemperature(red);

        expect(relTemp, inInclusiveRange(0.0, 1.0));
        expect(relTemp.isNaN, isFalse);
      });

      test('warmest is ~1, coldest is ~0', () {
        final input = Hct.from(120.0, 40.0, 50.0);
        final cache = TemperatureCache(input);
        expect(cache.relativeTemperature(cache.warmest), closeTo(1.0, 0.01));
        expect(cache.relativeTemperature(cache.coldest), closeTo(0.0, 0.01));
      });

      test('is continuous across the warm pole', () {
        final cache = TemperatureCache(Hct.from(0.0, 40.0, 50.0));
        final warmHue = TemperatureCache.warmestHue(ColorModel.kDefault);
        final justBelow = cache
            .relativeTemperature(Hct.from(warmHue - 0.5, 40.0, 50.0));
        final justAbove = cache
            .relativeTemperature(Hct.from(warmHue + 0.5, 40.0, 50.0));
        expect(justBelow, closeTo(justAbove, 0.01));
      });
    });

    group('inputRelativeTemperature', () {
      test('returns 0.5 for pure white', () {
        final white = Hct.from(0.0, 0.0, 100.0);
        final cache = TemperatureCache(white);

        final relTemp = cache.inputRelativeTemperature;
        expect(relTemp, equals(0.5));
        expect(relTemp.isNaN, isFalse);
      });

      test('returns 0.5 for pure black', () {
        final black = Hct.from(0.0, 0.0, 0.0);
        final cache = TemperatureCache(black);

        final relTemp = cache.inputRelativeTemperature;
        expect(relTemp, equals(0.5));
        expect(relTemp.isNaN, isFalse);
      });
    });

    group('analogous', () {
      test('returns valid colors for saturated input', () {
        final red = Hct.from(27.0, 113.0, 53.0);
        final cache = TemperatureCache(red);
        final analogues = cache.analogous();
        expect(analogues.length, equals(5));
        expect(analogues[2].color, red.color);

        expect(
            analogues.map(
              (e) => e.color.hex,
            ),
            equals(['#E201D6', '#F0059C', '#FE0005', '#B46F00', '#927E00']));
      });

      test('handles gray input without NaN', () {
        final gray = Hct.from(0.0, 0.0, 50.0);
        final cache = TemperatureCache(gray);
        final analogues = cache.analogous();

        expect(analogues.length, equals(5));
        expect(
            analogues.map(
              (e) => e.color.hex,
            ),
            equals(['#777777', '#777777', '#777777', '#777777', '#777777']));
      });

      test('input is always at the center', () {
        for (final hue in [0.0, 90.0, 180.0, 270.0]) {
          final input = Hct.from(hue, 40.0, 50.0);
          final analogues = TemperatureCache(input).analogous();
          expect(analogues[2], equals(input));
        }
      });
    });

    group('warmest and coldest', () {
      test('warmest and coldest hues are fixed poles', () {
        final gray = Hct.from(0.0, 0.0, 50.0);
        final cache = TemperatureCache(gray);

        // Poles are constants; actual hue shifts slightly through the
        // solver's sRGB round trip at near-zero chroma.
        expect(cache.warmest.hue, closeTo(30.825, 0.001));
        expect(cache.coldest.hue, closeTo(234.520, 0.001));
      });

      test('warmest and coldest preserve chroma and tone', () {
        final input = Hct.from(300.0, 24.0, 60.0);
        final cache = TemperatureCache(input);
        expect(cache.warmest.chroma, closeTo(24.0, 1.0));
        expect(cache.warmest.tone, closeTo(60.0, 1.0));
        expect(cache.coldest.chroma, closeTo(24.0, 1.0));
        expect(cache.coldest.tone, closeTo(60.0, 1.0));
      });
    });

    group('rawTemperature (Chang-Ou 2026)', () {
      test('warm colors have positive temperature', () {
        // Red/orange/yellow are warm
        final red = Hct.from(27.0, 100.0, 50.0);
        final temp = TemperatureCache.rawTemperature(red);
        expect(temp, closeTo(337.919, 0.001));
      });

      test('cool colors have negative temperature', () {
        // Blue/cyan are cool
        final blue = Hct.from(250.0, 100.0, 50.0);
        final temp = TemperatureCache.rawTemperature(blue);
        expect(temp, closeTo(-103.108, 0.001));
      });

      test('gray reads slightly warm (D65 white point vs D75 neutral)', () {
        // The model's neutral line passes through Illuminant D75; sRGB gray
        // has the D65 chromaticity, which sits on the warm side of it.
        final gray = Hct.from(0.0, 0.0, 50.0);
        final temp = TemperatureCache.rawTemperature(gray);
        expect(temp, closeTo(10.325, 0.001));
      });

      test('black is exactly neutral (degenerate chromaticity)', () {
        final black = Hct.from(0.0, 0.0, 0.0);
        expect(TemperatureCache.rawTemperature(black), equals(0.0));
      });
    });

    group('rawTemperature2004 (Ou et al., kept for comparison)', () {
      test('warm colors have positive temperature', () {
        final red = Hct.from(27.0, 100.0, 50.0);
        final temp = TemperatureCache.rawTemperature2004(red);
        expect(temp, closeTo(2.181, 0.001));
      });

      test('cool colors have negative temperature', () {
        final blue = Hct.from(250.0, 100.0, 50.0);
        final temp = TemperatureCache.rawTemperature2004(blue);
        expect(temp, closeTo(-1.437, 0.001));
      });

      test('gray has near-baseline temperature', () {
        final gray = Hct.from(0.0, 0.0, 50.0);
        final temp = TemperatureCache.rawTemperature2004(gray);
        // Gray (chroma ~0) sits at the formula's base offset of -0.5.
        expect(temp, closeTo(-0.5, 0.001));
      });
    });

    group('rawTemperature2018 (Ou universal model, kept for comparison)', () {
      test('warm colors have positive temperature', () {
        final red = Hct.from(27.0, 100.0, 50.0);
        final temp = TemperatureCache.rawTemperature2018(red);
        expect(temp, closeTo(4.179, 0.001));
      });

      test('cool colors have negative temperature', () {
        final blue = Hct.from(250.0, 100.0, 50.0);
        final temp = TemperatureCache.rawTemperature2018(blue);
        expect(temp, closeTo(-3.132, 0.001));
      });

      test('gray has near-baseline temperature', () {
        final gray = Hct.from(0.0, 0.0, 50.0);
        final temp = TemperatureCache.rawTemperature2018(gray);
        // Gray (chroma ~0) sits at the formula's base offset of -0.89.
        expect(temp, closeTo(-0.89, 0.001));
      });
    });
  });
}
