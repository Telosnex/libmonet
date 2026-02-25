import 'dart:math';

import 'package:test/test.dart';
import 'package:libmonet/colorspaces/gamut.dart';
import 'package:libmonet/colorspaces/hct_solver.dart';
import 'package:libmonet/colorspaces/cam16.dart';
import 'package:libmonet/colorspaces/cam16_viewing_conditions.dart';
import 'package:libmonet/core/argb_srgb_xyz_lab.dart';

void main() {
  // =========================================================================
  // Gamut construction
  // =========================================================================
  group('Gamut construction', () {
    test('srgb gamut has correct yFromLinrgb', () {
      expect(Gamut.srgb.yFromLinrgb, [0.2126, 0.7152, 0.0722]);
    });

    test('displayP3 gamut has correct yFromLinrgb', () {
      expect(Gamut.displayP3.yFromLinrgb[0], closeTo(0.2289745641, 1e-9));
      expect(Gamut.displayP3.yFromLinrgb[1], closeTo(0.6917385218, 1e-9));
      expect(Gamut.displayP3.yFromLinrgb[2], closeTo(0.0792869141, 1e-9));
    });

    test('rec2020 gamut has correct yFromLinrgb', () {
      expect(Gamut.rec2020.yFromLinrgb[0], closeTo(0.2627002120, 1e-9));
      expect(Gamut.rec2020.yFromLinrgb[1], closeTo(0.6779980715, 1e-9));
      expect(Gamut.rec2020.yFromLinrgb[2], closeTo(0.0593017165, 1e-9));
    });

    test('critical planes have 255 entries', () {
      expect(Gamut.srgb.criticalPlanes.length, 255);
      expect(Gamut.displayP3.criticalPlanes.length, 255);
      expect(Gamut.rec2020.criticalPlanes.length, 255);
    });

    test('sRGB critical planes match original hardcoded values', () {
      // Spot-check first and last
      expect(Gamut.srgb.criticalPlanes[0], closeTo(0.015176349177441876, 1e-15));
      expect(Gamut.srgb.criticalPlanes[254], closeTo(99.55452497210776, 1e-10));
    });

    test('Display P3 shares sRGB critical planes (same transfer function)', () {
      for (var i = 0; i < 255; i++) {
        expect(
          Gamut.displayP3.criticalPlanes[i],
          closeTo(Gamut.srgb.criticalPlanes[i], 1e-15),
          reason: 'Critical plane $i should match since Display P3 uses sRGB TF',
        );
      }
    });

    test('Rec 2020 critical planes differ from sRGB (different TF)', () {
      // They shouldn't be the same since Rec 2020 has a different TF
      var anyDifferent = false;
      for (var i = 0; i < 255; i++) {
        if ((Gamut.rec2020.criticalPlanes[i] - Gamut.srgb.criticalPlanes[i]).abs() > 1e-6) {
          anyDifferent = true;
          break;
        }
      }
      expect(anyDifferent, true, reason: 'Rec 2020 should have different critical planes');
    });
  });

  // =========================================================================
  // sRGB backward compatibility
  // =========================================================================
  group('sRGB backward compatibility', () {
    test('solveToInt matches solveToLinrgb for sRGB', () {
      for (var hue = 0; hue < 360; hue += 60) {
        for (var chroma = 0; chroma <= 100; chroma += 25) {
          for (var tone = 10; tone <= 90; tone += 20) {
            final argb = HctSolver.solveToInt(
                hue.toDouble(), chroma.toDouble(), tone.toDouble());
            final (r, g, b) = HctSolver.solveToLinrgb(
                hue.toDouble(), chroma.toDouble(), tone.toDouble(),
                gamut: Gamut.srgb);
            final argb2 = argbFromLinrgbComponents(r, g, b);
            expect(argb2, equals(argb),
                reason: 'H$hue C$chroma T$tone: solveToLinrgb(srgb) should match solveToInt');
          }
        }
      }
    });

    test('solveToDisplayRgb gives values in [0,1] for sRGB', () {
      final (r, g, b) = HctSolver.solveToDisplayRgb(
        0.0, 50.0, 50.0,
        gamut: Gamut.srgb,
      );
      expect(r, inInclusiveRange(0.0, 1.0));
      expect(g, inInclusiveRange(0.0, 1.0));
      expect(b, inInclusiveRange(0.0, 1.0));
    });
  });

  // =========================================================================
  // Display P3 wide gamut
  // =========================================================================
  group('Display P3', () {
    test('solveToLinrgb returns valid linear RGB', () {
      final (r, g, b) = HctSolver.solveToLinrgb(
        120.0, 80.0, 60.0,
        gamut: Gamut.displayP3,
      );
      // Linear RGB should be in [0, 100]
      expect(r, greaterThanOrEqualTo(-0.01));
      expect(g, greaterThanOrEqualTo(-0.01));
      expect(b, greaterThanOrEqualTo(-0.01));
      expect(r, lessThanOrEqualTo(100.01));
      expect(g, lessThanOrEqualTo(100.01));
      expect(b, lessThanOrEqualTo(100.01));
    });

    test('solveToDisplayRgb gives values in [0,1]', () {
      for (var hue = 0; hue < 360; hue += 30) {
        for (var tone = 20; tone <= 80; tone += 20) {
          final (r, g, b) = HctSolver.solveToDisplayRgb(
            hue.toDouble(), 60.0, tone.toDouble(),
            gamut: Gamut.displayP3,
          );
          expect(r, inInclusiveRange(0.0, 1.0),
              reason: 'r out of range for H$hue T$tone');
          expect(g, inInclusiveRange(0.0, 1.0),
              reason: 'g out of range for H$hue T$tone');
          expect(b, inInclusiveRange(0.0, 1.0),
              reason: 'b out of range for H$hue T$tone');
        }
      }
    });

    test('Display P3 can represent higher chroma than sRGB at same tone', () {
      // At hue 0 (red-ish), tone 50, Display P3 should achieve higher chroma
      const hue = 27.0; // CAM16 red hue
      const tone = 50.0;

      // Find max achievable chroma in each gamut by requesting very high chroma
      final (sR, sG, sB) = HctSolver.solveToLinrgb(hue, 200.0, tone,
          gamut: Gamut.srgb);
      final (pR, pG, pB) = HctSolver.solveToLinrgb(hue, 200.0, tone,
          gamut: Gamut.displayP3);

      // Convert both to XYZ to measure actual CAM16 chroma
      final srgbM = Gamut.srgb.rgbToXyz;
      final sX = sR * srgbM[0][0] + sG * srgbM[0][1] + sB * srgbM[0][2];
      final sY = sR * srgbM[1][0] + sG * srgbM[1][1] + sB * srgbM[1][2];
      final sZ = sR * srgbM[2][0] + sG * srgbM[2][1] + sB * srgbM[2][2];
      final srgbCam = Cam16.fromXyzInViewingConditions(
          sX, sY, sZ,
          Cam16ViewingConditions.sRgb);

      final p3M = Gamut.displayP3.rgbToXyz;
      final pX = pR * p3M[0][0] + pG * p3M[0][1] + pB * p3M[0][2];
      final pY = pR * p3M[1][0] + pG * p3M[1][1] + pB * p3M[1][2];
      final pZ = pR * p3M[2][0] + pG * p3M[2][1] + pB * p3M[2][2];
      final p3Cam = Cam16.fromXyzInViewingConditions(
          pX, pY, pZ,
          Cam16ViewingConditions.sRgb);

      expect(p3Cam.chroma, greaterThan(srgbCam.chroma),
          reason: 'Display P3 should achieve higher chroma than sRGB for red at T50. '
              'P3 chroma: ${p3Cam.chroma}, sRGB chroma: ${srgbCam.chroma}');
    });

    test('achromatic colors are the same across gamuts', () {
      for (var tone = 0; tone <= 100; tone += 10) {
        final (sR, sG, sB) = HctSolver.solveToLinrgb(0.0, 0.0, tone.toDouble(),
            gamut: Gamut.srgb);
        final (pR, pG, pB) = HctSolver.solveToLinrgb(0.0, 0.0, tone.toDouble(),
            gamut: Gamut.displayP3);

        // Both should produce equal linear R=G=B values (gray)
        expect(sR, closeTo(sG, 0.01), reason: 'sRGB gray at T$tone');
        expect(sR, closeTo(sB, 0.01), reason: 'sRGB gray at T$tone');
        expect(pR, closeTo(pG, 0.01), reason: 'P3 gray at T$tone');
        expect(pR, closeTo(pB, 0.01), reason: 'P3 gray at T$tone');

        // The Y values should be the same (same L*)
        final srgbM = Gamut.srgb.yFromLinrgb;
        final sY = sR * srgbM[0] + sG * srgbM[1] + sB * srgbM[2];
        final p3M = Gamut.displayP3.yFromLinrgb;
        final pY = pR * p3M[0] + pG * p3M[1] + pB * p3M[2];
        expect(sY, closeTo(pY, 0.5), reason: 'Y should match at T$tone');
      }
    });

    test('hue is preserved in Display P3', () {
      for (var hue = 15; hue < 360; hue += 30) {
        for (var tone = 30; tone <= 70; tone += 20) {
          final (r, g, b) = HctSolver.solveToLinrgb(
            hue.toDouble(), 40.0, tone.toDouble(),
            gamut: Gamut.displayP3,
          );

          // Convert to XYZ and back to CAM16 to check hue
          final m = Gamut.displayP3.rgbToXyz;
          final x = r * m[0][0] + g * m[0][1] + b * m[0][2];
          final y = r * m[1][0] + g * m[1][1] + b * m[1][2];
          final z = r * m[2][0] + g * m[2][1] + b * m[2][2];
          final cam = Cam16.fromXyzInViewingConditions(
              x, y, z, Cam16ViewingConditions.sRgb);

          if (cam.chroma > 1.0) {
            // Only check hue for non-achromatic colors
            final hueDiff = ((cam.hue - hue + 540) % 360) - 180;
            expect(hueDiff.abs(), lessThan(4.0),
                reason: 'Hue should be close for H$hue T$tone in Display P3. '
                    'Got ${cam.hue}');
          }
        }
      }
    });

    test('tone is preserved in Display P3', () {
      for (var hue = 0; hue < 360; hue += 60) {
        for (var tone = 20; tone <= 80; tone += 20) {
          final (r, g, b) = HctSolver.solveToLinrgb(
            hue.toDouble(), 40.0, tone.toDouble(),
            gamut: Gamut.displayP3,
          );

          // Compute Y and convert to L*
          final m = Gamut.displayP3.yFromLinrgb;
          final y = r * m[0] + g * m[1] + b * m[2];
          final lstar = lstarFromY(y);

          expect(lstar, closeTo(tone, 0.5),
              reason: 'Tone should be close for H$hue T$tone in Display P3');
        }
      }
    });
  });

  // =========================================================================
  // Rec. 2020 wide gamut
  // =========================================================================
  group('Rec. 2020', () {
    test('solveToDisplayRgb gives values in [0,1]', () {
      for (var hue = 0; hue < 360; hue += 45) {
        for (var tone = 20; tone <= 80; tone += 20) {
          final (r, g, b) = HctSolver.solveToDisplayRgb(
            hue.toDouble(), 60.0, tone.toDouble(),
            gamut: Gamut.rec2020,
          );
          expect(r, inInclusiveRange(0.0, 1.0),
              reason: 'r out of range for H$hue T$tone');
          expect(g, inInclusiveRange(0.0, 1.0),
              reason: 'g out of range for H$hue T$tone');
          expect(b, inInclusiveRange(0.0, 1.0),
              reason: 'b out of range for H$hue T$tone');
        }
      }
    });

    test('Rec 2020 can represent higher chroma than Display P3', () {
      const hue = 27.0;
      const tone = 50.0;

      final (pR, pG, pB) = HctSolver.solveToLinrgb(hue, 200.0, tone,
          gamut: Gamut.displayP3);
      final (rR, rG, rB) = HctSolver.solveToLinrgb(hue, 200.0, tone,
          gamut: Gamut.rec2020);

      final p3M = Gamut.displayP3.rgbToXyz;
      final pX = pR * p3M[0][0] + pG * p3M[0][1] + pB * p3M[0][2];
      final pY = pR * p3M[1][0] + pG * p3M[1][1] + pB * p3M[1][2];
      final pZ = pR * p3M[2][0] + pG * p3M[2][1] + pB * p3M[2][2];
      final p3Cam = Cam16.fromXyzInViewingConditions(
          pX, pY, pZ, Cam16ViewingConditions.sRgb);

      final recM = Gamut.rec2020.rgbToXyz;
      final rX = rR * recM[0][0] + rG * recM[0][1] + rB * recM[0][2];
      final rY = rR * recM[1][0] + rG * recM[1][1] + rB * recM[1][2];
      final rZ = rR * recM[2][0] + rG * recM[2][1] + rB * recM[2][2];
      final recCam = Cam16.fromXyzInViewingConditions(
          rX, rY, rZ, Cam16ViewingConditions.sRgb);

      expect(recCam.chroma, greaterThan(p3Cam.chroma),
          reason: 'Rec 2020 should achieve higher chroma than Display P3. '
              'Rec2020 chroma: ${recCam.chroma}, P3 chroma: ${p3Cam.chroma}');
    });
  });

  // =========================================================================
  // Transfer function round-trips
  // =========================================================================
  group('Transfer function round-trips', () {
    test('sRGB linearize/delinearize round-trips', () {
      for (var i = 0; i <= 255; i++) {
        final linear = Gamut.srgb.linearize(i.toDouble());
        final back = Gamut.srgb.trueDelinearize(linear);
        expect(back, closeTo(i.toDouble(), 0.01),
            reason: 'sRGB round-trip failed at $i');
      }
    });

    test('Rec 2020 linearize/delinearize round-trips', () {
      for (var i = 0; i <= 255; i++) {
        final linear = Gamut.rec2020.linearize(i.toDouble());
        final back = Gamut.rec2020.trueDelinearize(linear);
        expect(back, closeTo(i.toDouble(), 0.01),
            reason: 'Rec 2020 round-trip failed at $i');
      }
    });
  });

  // =========================================================================
  // Custom gamut construction
  // =========================================================================
  group('Custom gamut', () {
    test('can create DCI-P3 with gamma 2.6', () {
      // DCI-P3: same primaries as Display P3 but pure gamma 2.6
      // and DCI white point. For simplicity, use D65 white here.
      final dciP3 = Gamut.fromPrimaries(
        name: 'DCI-P3 (D65)',
        rgbToXyz: const [
          [0.4865709486, 0.2656676932, 0.1982172852],
          [0.2289745641, 0.6917385218, 0.0792869141],
          [0.0000000000, 0.0451133819, 1.0439443689],
        ],
        trueDelinearize: (double component) {
          final normalized = component / 100.0;
          return pow(normalized.clamp(0.0, 1.0), 1.0 / 2.6) * 255.0;
        },
        linearize: (double encoded) {
          final normalized = encoded / 255.0;
          return pow(normalized, 2.6) * 100.0;
        },
      );

      expect(dciP3.criticalPlanes.length, 255);
      expect(dciP3.name, 'DCI-P3 (D65)');

      // Should be able to solve
      final (r, g, b) = HctSolver.solveToDisplayRgb(
        120.0, 40.0, 50.0,
        gamut: dciP3,
      );
      expect(r, inInclusiveRange(0.0, 1.0));
      expect(g, inInclusiveRange(0.0, 1.0));
      expect(b, inInclusiveRange(0.0, 1.0));
    });
  });
}
