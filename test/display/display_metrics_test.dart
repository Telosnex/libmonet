import 'package:test/test.dart';
import 'package:libmonet/display/display_metrics.dart';

void main() {
  group('anchors', () {
    test('160ppi handheld is dp-equivalent: scale snaps to 1.0', () {
      // 640x960 px at exactly 160ppi (25.4/160 * px = mm).
      final metrics = DisplayModel(
        widthPx: 640,
        heightPx: 960,
        widthMm: 101.6,
        heightMm: 152.4,
        usage: DisplayUsage.handheld,
      ).compute();
      // Raw model output is 1.0093 (the 0.9% is the 180mm adaptation
      // intercept vs dp's implied 14in); snaps to 1.0.
      expect(metrics.visualScale, closeTo(1.0093, 0.001));
      expect(metrics.scale, 1.0);
      expect(metrics.logicalWidth, 640.0);
      expect(metrics.logicalHeight, 960.0);
      expect(metrics.usedFallback, isFalse);
    });

    test('logical pixel angle at dp anchor is ~0.0253 degrees', () {
      final metrics = DisplayModel(
        widthPx: 640,
        heightPx: 960,
        widthMm: 101.6,
        heightMm: 152.4,
        usage: DisplayUsage.handheld,
      ).compute();
      // 1/160in at 360mm = atan(0.15875/360) = 0.02527 deg; Android dp.
      expect(metrics.logicalPixelAngleDegrees!, closeTo(0.02527, 0.0001));
    });

    test('iPhone 4 (640x960, 3.5in) handheld: model says ~2.08', () {
      // Apple ships 2.0. The model disagrees by 4%: the panel is 329.65ppi
      // by this geometry, and Apple's pt anchor is 1/163in vs dp's 1/160in.
      // No integer snap at 4%; quantized to 8 mantissa bits: 133/256 * 4.
      final metrics = DisplayModel(
        widthPx: 640,
        heightPx: 960,
        diagonalInches: 3.5,
        usage: DisplayUsage.handheld,
      ).compute();
      expect(metrics.visualScale, closeTo(2.0794, 0.001));
      expect(metrics.scale, closeTo(2.078125, 1e-9));
    });
  });

  group('7in 1080p panel (the Pi display)', () {
    DisplayModel model(DisplayUsage usage, {TouchTargets? touch}) =>
        DisplayModel(
          widthPx: 1920,
          heightPx: 1080,
          diagonalInches: 7.0,
          usage: usage,
          touch: touch,
        );

    test('~315ppi density derived from diagonal', () {
      expect(model(DisplayUsage.handheld).pxPerMm!, closeTo(12.389, 0.01));
    });

    test('handheld: snaps to 2.0, logical 960x540 (a landscape phone)', () {
      final metrics = model(DisplayUsage.handheld).compute();
      expect(metrics.visualScale, closeTo(1.985, 0.001));
      expect(metrics.scale, 2.0);
      expect(metrics.logicalWidth, 960.0);
      expect(metrics.logicalHeight, 540.0);
    });

    test('near (desktop distance): snaps to 3.0, logical 640x360', () {
      // Raw 2.9776; a 7in panel at 720mm physically cannot hold more than
      // a phone's worth of legible UI. Not a bug.
      final metrics = model(DisplayUsage.near).compute();
      expect(metrics.visualScale, closeTo(2.9776, 0.001));
      expect(metrics.scale, 3.0);
      expect(metrics.logicalWidth, 640.0);
      expect(metrics.logicalHeight, 360.0);
    });

    test('handheld + touch: fingertip floor beats visual scale', () {
      // Visual scale is 1.985 but 48lp must span >= 8mm:
      // floor = 12.389 * 8 / 48 = 2.0649. Integer snap to 2.0 is refused
      // (below floor); round-quantize gives 2.0625, also below floor, so
      // the next quantization step up is taken: 133/256 * 4 = 2.078125.
      final metrics =
          model(DisplayUsage.handheld, touch: const TouchTargets()).compute();
      expect(metrics.touchScale!, closeTo(2.0649, 0.001));
      expect(metrics.scale, closeTo(2.078125, 1e-9));
      expect(metrics.scale, greaterThanOrEqualTo(metrics.touchScale!));
    });
  });

  group('far field', () {
    test('55in 4K TV at 3m: scale ~2.36', () {
      // Adaptation factor is 0.56 here; angular parity alone would give ~4.2
      // and a comically oversized ~910px-wide UI.
      final metrics = DisplayModel(
        widthPx: 3840,
        heightPx: 2160,
        diagonalInches: 55.0,
        usage: DisplayUsage.far,
      ).compute();
      expect(metrics.visualScale, closeTo(2.3581, 0.001));
      expect(metrics.scale, closeTo(2.359375, 1e-9)); // 151/256 * 4
      expect(metrics.logicalWidth, closeTo(1627.5, 0.1));
    });
  });

  group('fallback', () {
    test('unknown physical size: pretend 96dpi monitor, scale ~1.2', () {
      final metrics = DisplayModel(
        widthPx: 1920,
        heightPx: 1080,
        usage: DisplayUsage.near,
      ).compute();
      expect(metrics.usedFallback, isTrue);
      expect(metrics.visualScale, closeTo(0.0255 / 0.0213, 1e-9));
      expect(metrics.scale, closeTo(1.1953125, 1e-9)); // 153/256 * 2
    });

    test('implausible EDID density is treated as unknown', () {
      // Claims 1920px across 10mm: ~4900ppi. EDID lies; fall back.
      final metrics = DisplayModel(
        widthPx: 1920,
        heightPx: 1080,
        widthMm: 10.0,
        heightMm: 5.6,
        usage: DisplayUsage.near,
      ).compute();
      expect(metrics.pxPerMm, isNull);
      expect(metrics.usedFallback, isTrue);
    });

    test('unknown viewing distance also falls back', () {
      final metrics = DisplayModel(
        widthPx: 1920,
        heightPx: 1080,
        diagonalInches: 7.0,
      ).compute();
      expect(metrics.usedFallback, isTrue);
    });
  });

  group('user scale factor', () {
    test('applied before snapping/quantization, reflows logical size', () {
      final metrics = DisplayModel(
        widthPx: 640,
        heightPx: 960,
        widthMm: 101.6,
        heightMm: 152.4,
        usage: DisplayUsage.handheld,
        userScaleFactor: 1.5,
      ).compute();
      // 1.0093 * 1.5 = 1.5139; no integer within 2%; quantized 194/256 * 2.
      expect(metrics.scale, closeTo(1.515625, 1e-9));
      expect(metrics.logicalWidth, closeTo(640 / 1.515625, 1e-6));
    });
  });

  group('device goldens', () {
    // Golden values for real hardware. Comments note what the vendor ships
    // (when there is a vendor) vs what the perceptual model derives.

    test('iPhone Air: 2736x1260, 6.5in, handheld', () {
      // Apple ships @3x (420x912 pt). Model derives 2.92 — 2.6% under, just
      // outside the 2% integer-snap window. Apple consistently rounds up to
      // integer scales: legibility-biased, and wider snap tolerance than ours.
      final metrics = DisplayModel(
        widthPx: 1260,
        heightPx: 2736,
        diagonalInches: 6.5,
        usage: DisplayUsage.handheld,
      ).compute();
      expect(metrics.visualScale, closeTo(2.9232, 0.001));
      expect(metrics.scale, closeTo(2.921875, 1e-9)); // 187/256 * 4
      expect(metrics.logicalWidth, closeTo(431.2, 0.1)); // Apple: 420
      expect(metrics.logicalHeight, closeTo(936.4, 0.1)); // Apple: 912
    });

    test('MacBook Pro 16in (M4): 3456x2234, 16.2in, close', () {
      // 254ppi panel (exactly 10 px/mm). Apple ships @2x (looks like
      // 1728x1117). Model derives 1.914 — 4.3% under Apple, same
      // round-up-to-integer story as iPhone.
      final metrics = DisplayModel(
        widthPx: 3456,
        heightPx: 2234,
        diagonalInches: 16.2,
        usage: DisplayUsage.close,
      ).compute();
      expect(metrics.pxPerMm!, closeTo(10.0, 0.01));
      expect(metrics.visualScale, closeTo(1.9139, 0.001));
      expect(metrics.scale, closeTo(1.9140625, 1e-9)); // 245/256 * 2
      expect(metrics.logicalWidth, closeTo(1805.6, 0.1)); // Apple: 1728
      expect(metrics.logicalHeight, closeTo(1167.2, 0.1)); // Apple: 1117
    });

    test('Raspberry Pi display: 1920x1080, 7in, close', () {
      // The desk-companion usage; handheld (2.0) and near (3.0) are covered
      // in the group above.
      final metrics = DisplayModel(
        widthPx: 1920,
        heightPx: 1080,
        diagonalInches: 7.0,
        usage: DisplayUsage.close,
      ).compute();
      expect(metrics.visualScale, closeTo(2.3711, 0.001));
      expect(metrics.scale, closeTo(2.375, 1e-9)); // 152/256 * 4
      expect(metrics.logicalWidth, closeTo(808.4, 0.1));
      expect(metrics.logicalHeight, closeTo(454.7, 0.1));
    });

    test('Raspberry Pi display: 1024x600, 7in, close', () {
      // ~170ppi aftermarket panel. Lands at ~800x468 logical — essentially
      // the original official Pi 7in display's 800x480, derived rather than
      // decreed. The model saying "these two panels deserve the same UI" is
      // it working as intended.
      final metrics = DisplayModel(
        widthPx: 1024,
        heightPx: 600,
        diagonalInches: 7.0,
        usage: DisplayUsage.close,
      ).compute();
      expect(metrics.visualScale, closeTo(1.2775, 0.001));
      expect(metrics.scale, closeTo(1.28125, 1e-9)); // 164/256 * 2
      expect(metrics.logicalWidth, closeTo(799.2, 0.1));
      expect(metrics.logicalHeight, closeTo(468.3, 0.1));
    });

    test('ESP32-P4 smart panel: 720x720, 4in, handheld', () {
      // ~255ppi square MIPI-DSI panel (e.g. Waveshare 4in for the P4).
      // A hold-it-or-lean-in gadget, so handheld distance.
      final metrics = DisplayModel(
        widthPx: 720,
        heightPx: 720,
        diagonalInches: 4.0,
        usage: DisplayUsage.handheld,
      ).compute();
      expect(metrics.visualScale, closeTo(1.6057, 0.001));
      expect(metrics.scale, closeTo(1.609375, 1e-9)); // 206/256 * 2
      expect(metrics.logicalWidth, closeTo(447.4, 0.1));
      expect(metrics.logicalHeight, closeTo(447.4, 0.1));
    });

    test('ESP32 Cheap Yellow Display: 240x320, 2.8in, handheld', () {
      // ESP32-2432S028R, ~143ppi. Scale comes out *below* 1.0: this panel's
      // physical pixels are chunkier than a dp, so logical resolution
      // exceeds physical. Correct behavior for low-DPI panels, and exactly
      // the case dpi-assuming toolkits get wrong in the other direction.
      final metrics = DisplayModel(
        widthPx: 240,
        heightPx: 320,
        diagonalInches: 2.8,
        usage: DisplayUsage.handheld,
      ).compute();
      expect(metrics.visualScale, closeTo(0.9011, 0.001));
      expect(metrics.scale, closeTo(0.90234375, 1e-9)); // 231/256
      expect(metrics.logicalWidth, closeTo(266.0, 0.1));
      expect(metrics.logicalHeight, closeTo(354.6, 0.1));
    });

    test('Cheap Yellow Display + touch: fingertip floor wins, 256 lp wide',
        () {
      // With resistive touch enabled, the 8mm/48lp floor (0.9374) beats the
      // visual scale (0.9011). Quantizes to exactly 15/16, making the
      // logical width exactly 256.0.
      final metrics = DisplayModel(
        widthPx: 240,
        heightPx: 320,
        diagonalInches: 2.8,
        usage: DisplayUsage.handheld,
        touch: const TouchTargets(),
      ).compute();
      expect(metrics.touchScale!, closeTo(0.9374, 0.001));
      expect(metrics.scale, closeTo(0.9375, 1e-9)); // 240/256 = 15/16
      expect(metrics.scale, greaterThanOrEqualTo(metrics.touchScale!));
      expect(metrics.logicalWidth, closeTo(256.0, 1e-9));
      expect(metrics.logicalHeight, closeTo(341.3, 0.1));
    });
  });

  group('quantization', () {
    test('all emitted scales have at most 8 mantissa bits', () {
      for (final usage in DisplayUsage.values) {
        for (final diagonal in [3.5, 5.0, 7.0, 13.3, 27.0, 55.0]) {
          final scale = DisplayModel(
            widthPx: 1920,
            heightPx: 1080,
            diagonalInches: diagonal,
            usage: usage,
          ).compute().scale;
          // scale = m/256 * 2^exp for integer m in [128, 256], so
          // scale * 2^(8 - exp) must be an integer.
          var s = scale;
          var steps = 0;
          while (s < 128.0) {
            s *= 2.0;
            steps++;
            expect(steps, lessThan(64));
          }
          while (s >= 256.0) {
            s /= 2.0;
          }
          expect(s, equals(s.roundToDouble()),
              reason: 'scale $scale (usage $usage, ${diagonal}in) '
                  'has more than 8 mantissa bits');
        }
      }
    });
  });
}
