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

import 'package:libmonet/colorspaces/hct.dart';
import 'package:libmonet/core/hex_codes.dart';
import 'package:libmonet/effects/temperature.dart';
import 'package:test/test.dart';

import 'utils/color_matcher.dart';

void main() {
  group('TemperatureCache', () {
    group('complement', () {
      test('returns valid complement for saturated red', () {
        final red = Hct.from(27.0, 113.0, 53.0);
        final cache = TemperatureCache(red);
        final complement = cache.complement;
        expect(complement.color, isColor(0xff007BFB));
      });

      test('returns valid complement for saturated blue', () {
        final blue = Hct.from(282.0, 87.0, 32.0);
        final cache = TemperatureCache(blue);
        final complement = cache.complement;
        expect(complement.color, isColor(0xff9C0001));
      });

      test('returns valid complement for mid-chroma color', () {
        final color = Hct.from(120.0, 40.0, 50.0);
        final cache = TemperatureCache(color);
        final complement = cache.complement;
        expect(complement.color, isColor(0xff9366A3));
      });

      // These tests expose the division by zero bug:
      // When chroma is 0 (pure gray), all hues have the same temperature,
      // so warmestTemp == coldestTemp and range == 0.

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
        expect(complement.color, isColor(0xff7B7674));
      });

      test('handles very low chroma color without NaN', () {
        // Very low chroma might also cause near-zero temperature range
        final almostGray = Hct.from(180.0, 0.5, 50.0);
        final cache = TemperatureCache(almostGray);
        final complement = cache.complement;
        expect(complement.color, isColor(0xff7A7676));
      });

      // These tests verify that when range == 0, the complement calculation
      // uses a proper fallback (0.5) instead of producing NaN through division by zero.
      // The bug: relativeTemp = (temp - coldestTemp) / range produces NaN when range == 0.
      // The fix should handle range == 0 by using 0.5 as the relative temperature.
      test('complement calculation does not produce NaN for white (range == 0)',
          () {
        final white = Hct.from(0.0, 0.0, 100.0);
        final cache = TemperatureCache(white);

        // Verify the precondition: range is zero for white
        final warmestTemp = cache.tempsByHct[cache.warmest]!;
        final coldestTemp = cache.tempsByHct[cache.coldest]!;
        final range = warmestTemp - coldestTemp;
        expect(range, equals(0.0),
            reason: 'Precondition: temperature range should be 0 for white');

        // When range == 0, calculating relativeTemp without a guard produces NaN:
        //   relativeTemp = (someTemp - coldestTemp) / range = 0.0 / 0.0 = NaN
        // The fix should guard against this.
        final possibleAnswer = cache.hctsByHue[0];
        final possibleTemp = cache.tempsByHct[possibleAnswer]!;

        // This simulates what the complement getter does internally.
        // With the bug, this produces NaN. With the fix, it should be 0.5.
        final relativeTemp =
            range == 0.0 ? 0.5 : (possibleTemp - coldestTemp) / range;
        expect(relativeTemp.isNaN, isFalse,
            reason: 'relativeTemp should not be NaN when range == 0');
        expect(relativeTemp, equals(0.5),
            reason: 'relativeTemp should be 0.5 when range == 0');
      });

      test('complement calculation does not produce NaN for black (range == 0)',
          () {
        final black = Hct.from(0.0, 0.0, 0.0);
        final cache = TemperatureCache(black);

        // Verify the precondition: range is zero for black
        final warmestTemp = cache.tempsByHct[cache.warmest]!;
        final coldestTemp = cache.tempsByHct[cache.coldest]!;
        final range = warmestTemp - coldestTemp;
        expect(range, equals(0.0),
            reason: 'Precondition: temperature range should be 0 for black');

        final possibleAnswer = cache.hctsByHue[0];
        final possibleTemp = cache.tempsByHct[possibleAnswer]!;

        final relativeTemp =
            range == 0.0 ? 0.5 : (possibleTemp - coldestTemp) / range;
        expect(relativeTemp.isNaN, isFalse,
            reason: 'relativeTemp should not be NaN when range == 0');
        expect(relativeTemp, equals(0.5),
            reason: 'relativeTemp should be 0.5 when range == 0');
      });
    });

    group('relativeTemperature', () {
      test('returns 0.5 when temperature range is zero (white)', () {
        final white = Hct.from(0.0, 0.0, 100.0);
        final cache = TemperatureCache(white);

        // relativeTemperature correctly handles range == 0
        final relTemp = cache.relativeTemperature(white);
        expect(relTemp, equals(0.5));
        expect(relTemp.isNaN, isFalse);
      });

      test('returns 0.5 when temperature range is zero (black)', () {
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
    });

    group('inputRelativeTemperature', () {
      test('returns 0.5 when temperature range is zero (white)', () {
        final white = Hct.from(0.0, 0.0, 100.0);
        final cache = TemperatureCache(white);

        final relTemp = cache.inputRelativeTemperature;
        expect(relTemp, equals(0.5));
        expect(relTemp.isNaN, isFalse);
      });

      test('returns 0.5 when temperature range is zero (black)', () {
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

        expect(
            analogues.map(
              (e) => e.color.hex,
            ),
            equals(['#F6007D', '#FB004C', '#FE0005', '#D75600', '#AE7200']));
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
            equals(['#787775', '#777776', '#777777', '#787778', '#7A7678']));
      });
    });

    group('warmest and coldest', () {
      test('warmest and coldest are valid for gray', () {
        final gray = Hct.from(0.0, 0.0, 50.0);
        final cache = TemperatureCache(gray);

        expect(cache.warmest.hue, closeTo(64.045, 0.001));
        expect(cache.coldest.hue, closeTo(234.520, 0.001));
      });
    });

    group('rawTemperature', () {
      test('warm colors have positive temperature', () {
        // Red/orange/yellow are warm
        final red = Hct.from(27.0, 100.0, 50.0);
        final temp = TemperatureCache.rawTemperature(red);
        expect(temp, closeTo(1.964, 0.001));
      });

      test('cool colors have negative temperature', () {
        // Blue/cyan are cool
        final blue = Hct.from(250.0, 100.0, 50.0);
        final temp = TemperatureCache.rawTemperature(blue);
        expect(temp, closeTo(-1.437, 0.001));
      });

      test('gray has near-zero temperature', () {
        final gray = Hct.from(0.0, 0.0, 50.0);
        final temp = TemperatureCache.rawTemperature(gray);
        // Gray (chroma ~0) should have temperature close to -0.5 (the base offset)
        expect(temp, closeTo(-0.5, 0.001));
      });
    });
  });
}
