// Copyright 2021 Google LLC
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

import 'package:test/test.dart';
import 'package:libmonet/core/argb_srgb_xyz_lab.dart';
import 'package:libmonet/colorspaces/cam16.dart';
import 'package:libmonet/colorspaces/cam16_viewing_conditions.dart';
import 'package:libmonet/colorspaces/hct.dart';
import 'package:libmonet/core/hex_codes.dart';

import '../utils/color_matcher.dart';

const black = 0xff000000;
const white = 0xffffffff;
const red = 0xffff0000;
const green = 0xff00ff00;
const blue = 0xff0000ff;
const midgray = 0xff777777;

void main() {
  test('==, hashCode basics', () {
    expect(Hct.fromInt(123), Hct.fromInt(123));
    expect(Hct.fromInt(123).hashCode, Hct.fromInt(123).hashCode);
  });

  test('conversions_areReflexive', () {
    final cam = Cam16.fromInt(red);
    final color = cam.viewed(Cam16ViewingConditions.standard);
    expect(color, equals(red));
  });

  test('y_midgray', () {
    expect(18.418, closeTo(yFromLstar(50.0), 0.001));
  });

  test('y_black', () {
    expect(0.0, closeTo(yFromLstar(0.0), 0.001));
  });

  test('y_white', () {
    expect(100.0, closeTo(yFromLstar(100.0), 0.001));
  });

  test('cam_red', () {
    final cam = Cam16.fromInt(red);
    expect(46.445, closeTo(cam.j, 0.001));
    expect(113.357, closeTo(cam.chroma, 0.001));
    expect(27.408, closeTo(cam.hue, 0.001));
    expect(89.494, closeTo(cam.m, 0.001));
    expect(91.889, closeTo(cam.s, 0.001));
    expect(105.988, closeTo(cam.q, 0.001));
  });

  test('cam_green', () {
    final cam = Cam16.fromInt(green);
    expect(79.331, closeTo(cam.j, 0.001));
    expect(108.410, closeTo(cam.chroma, 0.001));
    expect(142.139, closeTo(cam.hue, 0.001));
    expect(85.587, closeTo(cam.m, 0.001));
    expect(78.604, closeTo(cam.s, 0.001));
    expect(138.520, closeTo(cam.q, 0.001));
  });

  test('cam_blue', () {
    final cam = Cam16.fromInt(blue);
    expect(25.465, closeTo(cam.j, 0.001));
    expect(87.230, closeTo(cam.chroma, 0.001));
    expect(282.788, closeTo(cam.hue, 0.001));
    expect(68.867, closeTo(cam.m, 0.001));
    expect(93.674, closeTo(cam.s, 0.001));
    expect(78.481, closeTo(cam.q, 0.001));
  });

  test('cam_black', () {
    final cam = Cam16.fromInt(black);
    expect(0.0, closeTo(cam.j, 0.001));
    expect(0.0, closeTo(cam.chroma, 0.001));
    expect(0.0, closeTo(cam.hue, 0.001));
    expect(0.0, closeTo(cam.m, 0.001));
    expect(0.0, closeTo(cam.s, 0.001));
    expect(0.0, closeTo(cam.q, 0.001));
  });

  test('cam_white', () {
    final cam = Cam16.fromInt(white);
    expect(100.0, closeTo(cam.j, 0.001));
    expect(2.869, closeTo(cam.chroma, 0.001));
    expect(209.492, closeTo(cam.hue, 0.001));
    expect(2.265, closeTo(cam.m, 0.001));
    expect(12.068, closeTo(cam.s, 0.001));
    expect(155.521, closeTo(cam.q, 0.001));
  });

  test('gamutMap_red', () {
    const colorToTest = red;
    final cam = Cam16.fromInt(colorToTest);
    final color = Hct.from(
        cam.hue,
        cam.chroma,
        lstarFromArgb(
          colorToTest,
        )).toInt();
    expect(colorToTest, equals(color));
  });

  test('gamutMap_green', () {
    const colorToTest = green;
    final cam = Cam16.fromInt(colorToTest);
    final color =
        Hct.from(cam.hue, cam.chroma, lstarFromArgb(colorToTest)).toInt();
    expect(colorToTest, equals(color));
  });

  test('gamutMap_blue', () {
    const colorToTest = blue;
    final cam = Cam16.fromInt(colorToTest);
    final color = Hct.from(
      cam.hue,
      cam.chroma,
      lstarFromArgb(colorToTest),
    ).toInt();
    expect(colorToTest, equals(color));
  });

  test('gamutMap_white', () {
    const colorToTest = white;
    final cam = Cam16.fromInt(colorToTest);
    final color = Hct.from(
      cam.hue,
      cam.chroma,
      lstarFromArgb(colorToTest),
    ).toInt();
    expect(colorToTest, equals(color));
  });

  test('gamutMap_midgray', () {
    const colorToTest = green;
    final cam = Cam16.fromInt(colorToTest);
    final color = Hct.from(
      cam.hue,
      cam.chroma,
      lstarFromArgb(colorToTest),
    ).toInt();
    expect(colorToTest, equals(color));
  });

  test('HCT returns a sufficiently close color', () {
    bool colorIsOnBoundary(int argb) {
      return redFromArgb(argb) == 0 ||
          redFromArgb(argb) == 255 ||
          greenFromArgb(argb) == 0 ||
          greenFromArgb(argb) == 255 ||
          blueFromArgb(argb) == 0 ||
          blueFromArgb(argb) == 255;
    }

    for (var hue = 15; hue < 360; hue += 30) {
      for (var chroma = 0; chroma <= 100; chroma += 10) {
        for (var tone = 20; tone <= 80; tone += 10) {
          final hctRequestDescription = 'H$hue C$chroma T$tone';
          final hctColor = Hct.from(
            hue.toDouble(),
            chroma.toDouble(),
            tone.toDouble(),
          );

          if (chroma > 0) {
            expect(
              hctColor.hue,
              closeTo(hue, 4.0),
              reason: 'Hue should be close for $hctRequestDescription',
            );
          }

          expect(
            hctColor.chroma,
            inInclusiveRange(0.0, chroma + 2.5),
            reason: 'Chroma should be close or less for $hctRequestDescription',
          );

          if (hctColor.chroma < chroma - 2.5) {
            expect(
              colorIsOnBoundary(hctColor.toInt()),
              true,
              reason: 'HCT request for non-sRGB color should return '
                  'a color on the boundary of the sRGB cube '
                  'for $hctRequestDescription, but got '
                  '${hexFromArgb(hctColor.toInt())} instead',
            );
          }

          expect(
            hctColor.tone,
            closeTo(tone, 0.5),
            reason: 'Tone should be close for $hctRequestDescription',
          );
        }
      }
    }
  });

  group('lerpKeepHue', () {
    void expectHueClose(
      double actual,
      double expected, {
      required String label,
    }) {
      final delta = ((actual - expected + 540.0) % 360.0) - 180.0;

      expect(
        delta.abs(),
        lessThanOrEqualTo(0.1),
        reason: '$label expected≈$expected°, actual=$actual°, Δ=${delta.abs()}°',
      );
    }

    test('wraps across zero from high to low', () {
      final colorA = Hct.colorFrom(350.0, 40.0, 50.0);
      final colorB = Hct.colorFrom(10.0, 40.0, 50.0);
      final resultHue = Hct.fromColor(Hct.lerpKeepHue(colorA, colorB, 0.5)).hue;

      expectHueClose(
        resultHue,
        0.1,
        label: 'lerpKeepHue 350°→10° @ t=0.5',
      );
    });

    test('wraps across zero from low to high', () {
      final colorA = Hct.colorFrom(10.0, 40.0, 50.0);
      final colorB = Hct.colorFrom(350.0, 40.0, 50.0);
      final resultHue = Hct.fromColor(Hct.lerpKeepHue(colorA, colorB, 0.5)).hue;

      expectHueClose(
        resultHue,
        0.1,
        label: 'lerpKeepHue 10°→350° @ t=0.5',
      );
    });
  });

  group('lerpCartesian', () {
    test('returns endpoints', () {
      final colorA = Hct.colorFrom(20.0, 50.0, 60.0);
      final colorB = Hct.colorFrom(200.0, 30.0, 70.0);

      expect(
        Hct.lerpLoseHueAndChroma(colorA, colorB, 0.0),
        isColor(colorA),
        reason: 't=0 should return colorA',
      );
      expect(
        Hct.lerpLoseHueAndChroma(colorA, colorB, 1.0),
        isColor(colorB),
        reason: 't=1 should return colorB',
      );
    });

    test('lerps tone in L* space', () {
      final colorA = Hct.colorFrom(30.0, 60.0, 20.0);
      final colorB = Hct.colorFrom(140.0, 40.0, 80.0);
      const t = 0.5;
      final aTone = lstarFromArgb(colorA.argb);
      final bTone = lstarFromArgb(colorB.argb);
      final expectedTone = aTone + (bTone - aTone) * t;
      final result = Hct.lerpLoseHueAndChroma(colorA, colorB, t);
      final resultTone = Hct.fromColor(result).tone;

      expect(
        resultTone,
        closeTo(expectedTone, 0.5),
        reason: 'Expected tone≈$expectedTone but got $resultTone',
      );
    });

    test('lerp test case', () {
      final colorA = Hct.colorFrom(30.0, 60.0, 20.0);
      final colorB = Hct.colorFrom(140.0, 40.0, 80.0);
      const t = 0.7;
      final result = Hct.lerpLoseHueAndChroma(colorA, colorB, t);

      expect(
        result,
        isColor(0xff9D9863),
      );
    });

    test('lerp test case', () {
      final colorA = Hct.colorFrom(0.0, 0.0, 0.0);
      final colorB = Hct.colorFrom(90.0, 40.0, 100.0);
      const t = 0.7;
      final result = Hct.lerpLoseHueAndChroma(colorA, colorB, t);

      expect(
        result,
        isColor(0xffABABAB),
      );
    });
  });

  group('CAM16 to XYZ', () {
    test('without array', () {
      const colorToTest = red;
      final cam = Cam16.fromInt(colorToTest);
      final xyz = cam.xyzInViewingConditions(Cam16ViewingConditions.sRgb);
      expect(xyz[0], closeTo(41.23, 0.01));
      expect(xyz[1], closeTo(21.26, 0.01));
      expect(xyz[2], closeTo(1.93, 0.01));
    });

    test('with array', () {
      const colorToTest = red;
      final cam = Cam16.fromInt(colorToTest);
      final xyz = cam.xyzInViewingConditions(Cam16ViewingConditions.sRgb,
          array: [0, 0, 0]);
      expect(xyz[0], closeTo(41.23, 0.01));
      expect(xyz[1], closeTo(21.26, 0.01));
      expect(xyz[2], closeTo(1.93, 0.01));
    });
  });

  group('Color Relativity', () {
    test('red in black', () {
      const colorToTest = red;
      final hct = Hct.fromInt(colorToTest);
      expect(
          hct
              .inViewingConditions(
                  Cam16ViewingConditions.make(backgroundLstar: 0.0))
              .toInt(),
          isColor(0xff9F5C51));
    });

    test('red in white', () {
      const colorToTest = red;
      final hct = Hct.fromInt(colorToTest);
      expect(
          hct
              .inViewingConditions(
                  Cam16ViewingConditions.make(backgroundLstar: 100.0))
              .toInt(),
          isColor(0xffFF5D48));
    });

    test('green in black', () {
      const colorToTest = green;
      final hct = Hct.fromInt(colorToTest);
      expect(
          hct
              .inViewingConditions(
                  Cam16ViewingConditions.make(backgroundLstar: 0.0))
              .toInt(),
          isColor(0xffACD69D));
    });

    test('green in white', () {
      const colorToTest = green;
      final hct = Hct.fromInt(colorToTest);
      expect(
          hct
              .inViewingConditions(
                  Cam16ViewingConditions.make(backgroundLstar: 100.0))
              .toInt(),
          isColor(0xff8FFF77));
    });

    test('blue in black', () {
      const colorToTest = blue;
      final hct = Hct.fromInt(colorToTest);
      expect(
          hct
              .inViewingConditions(
                  Cam16ViewingConditions.make(backgroundLstar: 0.0))
              .toInt(),
          isColor(0xff343654));
    });

    test('blue in white', () {
      const colorToTest = blue;
      final hct = Hct.fromInt(colorToTest);
      expect(
          hct
              .inViewingConditions(
                  Cam16ViewingConditions.make(backgroundLstar: 100.0))
              .toInt(),
          isColor(0xff4048FF));
    });

    test('white in black', () {
      const colorToTest = white;
      final hct = Hct.fromInt(colorToTest);
      expect(
          hct
              .inViewingConditions(
                  Cam16ViewingConditions.make(backgroundLstar: 0.0))
              .toInt(),
          isColor(0xffFFFFFF));
    });

    test('white in white', () {
      const colorToTest = white;
      final hct = Hct.fromInt(colorToTest);
      expect(
          hct
              .inViewingConditions(
                  Cam16ViewingConditions.make(backgroundLstar: 100.0))
              .toInt(),
          isColor(0xffFFFFFF));
    });

    test('midgray in black', () {
      const colorToTest = midgray;
      final hct = Hct.fromInt(colorToTest);
      expect(
          hct
              .inViewingConditions(
                  Cam16ViewingConditions.make(backgroundLstar: 0.0))
              .toInt(),
          isColor(0xff605F5F));
    });

    test('midgray in white', () {
      const colorToTest = midgray;
      final hct = Hct.fromInt(colorToTest);
      expect(
          hct
              .inViewingConditions(
                  Cam16ViewingConditions.make(backgroundLstar: 100.0))
              .toInt(),
          isColor(0xff8E8E8E));
    });

    test('black in black', () {
      const colorToTest = black;
      final hct = Hct.fromInt(colorToTest);
      expect(
          hct
              .inViewingConditions(
                  Cam16ViewingConditions.make(backgroundLstar: 0.0))
              .toInt(),
          isColor(0xff000000));
    });

    test('black in white', () {
      const colorToTest = black;
      final hct = Hct.fromInt(colorToTest);
      expect(
          hct
              .inViewingConditions(
                  Cam16ViewingConditions.make(backgroundLstar: 100.0))
              .toInt(),
          isColor(0xff000000));
    });
  });
}
