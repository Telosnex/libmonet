import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/contrast/contrast.dart';
import 'package:libmonet/effects/protection.dart';

// Independent audit: 8-bit source-over blend, straight from the spec.
int auditBlend(int bg, int scrim, int a) {
  int ch(int shift) {
    final b = (bg >> shift) & 0xFF;
    final s = (scrim >> shift) & 0xFF;
    return (((255 - a) * b + a * s) / 255).round();
  }

  return 0xFF000000 | (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

/// Does [fg] meet [target] against every bg blended with the result's scrim
/// at alpha step [a]?
bool auditPasses(
    int fg, List<int> bgs, ProtectionResult r, Algo algo, double target, int a) {
  for (final bg in bgs) {
    final blended = auditBlend(bg, r.protectionArgb, a);
    final c =
        algo.contrastBetweenArgbs(bgArgb: blended, fgArgb: fg).abs();
    if (c < target) return false;
  }
  return true;
}

void main() {
  const black = 0xFF000000;
  const white = 0xFFFFFFFF;
  const brown = 0xFF8B4513;

  group('regressions', () {
    test('D1: white on black needs zero protection (APCA sign)', () {
      for (final algo in Algo.values) {
        final r = getProtectionOpacity(
          foregroundArgb: white,
          backgroundArgbs: [black],
          contrast: 0.5,
          algo: algo,
        );
        expect(r.opacity, 0.0, reason: '$algo');
        expect(r.meetsTarget, isTrue, reason: '$algo');
        expect(r.needsProtection, isFalse, reason: '$algo');
      }
    });

    test('D2: mid-luma chromatic pixel is protected, not skipped', () {
      // Old solver reduced {#7F4F5E, #1F9F39} to min/max luma and returned
      // white@1.0 for #AA98F4 at WCAG 2.4; black at moderate opacity suffices.
      final r = getProtectionOpacity(
        foregroundArgb: 0xFFAA98F4,
        backgroundArgbs: [0xFF7F4F5E, 0xFF1F9F39],
        contrast: 0.2, // WCAG ratio 2.4
        algo: Algo.wcag21,
      );
      expect(r.meetsTarget, isTrue);
      expect(r.protectionArgb, black);
      expect(r.opacity, lessThanOrEqualTo(0.35));
    });

    test('straddle: #777 over black+white collapses to one side, flagged', () {
      // At alpha 0 every pixel passes WCAG 3.0 per-pixel, but the pixels sit
      // on BOTH sides of the text tone. Policy: push to one side, say so.
      final r = getProtectionOpacity(
        foregroundArgb: 0xFF777777,
        backgroundArgbs: [black, white],
        contrast: 0.2857, // WCAG ratio ~3.0
        algo: Algo.wcag21,
      );
      expect(r.needsProtection, isTrue);
      expect(r.straddleCollapsed, isTrue);
      expect(r.meetsTarget, isTrue);
    });
  });

  group('custom scrim (protectionArgb)', () {
    test('brown scrim: feasible for white text, audited at and above alpha',
        () {
      final bgs = [0xFF123456, 0xFF999999, 0xFFE0E0B0];
      final r = getProtectionOpacity(
        foregroundArgb: white,
        backgroundArgbs: bgs,
        contrast: 0.5,
        algo: Algo.wcag21,
        protectionArgb: brown,
      );
      expect(r.meetsTarget, isTrue);
      expect(r.protectionArgb, brown);
      final target = Algo.wcag21.getAbsoluteContrast(0.5, Usage.text);
      final solvedStep = (r.opacity * 255).round();
      // Solved alpha and everything above it clears (suffix guarantee).
      for (var a = solvedStep; a <= 255; a += 5) {
        expect(auditPasses(white, bgs, r, Algo.wcag21, target, a), isTrue,
            reason: 'alpha step $a');
      }
    });

    test('brown scrim: honestly infeasible for mid-tone text', () {
      final r = getProtectionOpacity(
        foregroundArgb: 0xFF777777,
        backgroundArgbs: [black, white],
        contrast: 0.5,
        algo: Algo.wcag21,
        protectionArgb: brown,
      );
      expect(r.meetsTarget, isFalse);
      expect(r.opacity, 1.0);
    });
  });

  group('properties (seeded random)', () {
    test('solved alpha passes audit; alpha-1 does not solve; suffix holds',
        () {
      final rng = Random(1234);
      int randArgb() =>
          0xFF000000 | (rng.nextInt(1 << 24) & 0xFFFFFF);

      for (var trial = 0; trial < 400; trial++) {
        final algo = Algo.values[trial % 2];
        final contrast = [0.3, 0.5, 0.7][trial % 3];
        final fg = randArgb();
        final bgs =
            List.generate(1 + rng.nextInt(8), (_) => randArgb());
        final r = getProtectionOpacity(
          foregroundArgb: fg,
          backgroundArgbs: bgs,
          contrast: contrast,
          algo: algo,
        );
        final target = algo.getAbsoluteContrast(contrast, Usage.text);
        final solvedStep = (r.opacity * 255).round();

        if (!r.meetsTarget) {
          // Best effort must be at full opacity and genuinely infeasible:
          // even the pure scrim fails.
          expect(r.opacity, 1.0);
          expect(auditPasses(fg, bgs, r, algo, target, 255), isFalse);
          continue;
        }
        // 1. Contract: every bg passes at the solved alpha.
        expect(auditPasses(fg, bgs, r, algo, target, solvedStep), isTrue,
            reason: 'trial $trial: solved alpha must pass audit');
        // 2. Suffix: spot-check higher alphas also pass.
        for (final bump in [1, 17, 255 - solvedStep]) {
          final a = (solvedStep + bump).clamp(0, 255);
          expect(auditPasses(fg, bgs, r, algo, target, a), isTrue,
              reason: 'trial $trial: alpha $a above solved must pass');
        }
        // 3. Minimality: one step below, per-pixel contrast or coherence
        // must fail (otherwise the solver overshot).
        if (solvedStep > 0) {
          final below = solvedStep - 1;
          final passes = auditPasses(fg, bgs, r, algo, target, below);
          if (passes) {
            // Then it must have failed coherence: bgs on both sides of fg.
            expect(r.straddleCollapsed, isTrue,
                reason: 'trial $trial: alpha-1 passes per-pixel but was '
                    'rejected, must be a flagged straddle');
          }
        }
      }
    });
  });

  group('validation', () {
    test('empty backgrounds throws', () {
      expect(
          () => getProtectionOpacity(
              foregroundArgb: white,
              backgroundArgbs: [],
              contrast: 0.5,
              algo: Algo.wcag21),
          throwsArgumentError);
    });
    test('contrast out of range throws', () {
      for (final c in [0.0, -0.1, 1.1, double.nan]) {
        expect(
            () => getProtectionOpacity(
                foregroundArgb: white,
                backgroundArgbs: [black],
                contrast: c,
                algo: Algo.wcag21),
            throwsArgumentError,
            reason: 'contrast $c');
      }
    });
    test('negative halo geometry throws', () {
      expect(
          () => getHalo(
              foregroundArgb: white,
              backgroundArgbs: [black],
              contrast: 0.5,
              algo: Algo.wcag21,
              spread: -1),
          throwsArgumentError);
    });
  });

  group('halo', () {
    test('halo opacity equals solver opacity exactly', () {
      final bgs = [0xFF445566, 0xFF99AA77];
      final p = getProtectionOpacity(
          foregroundArgb: white,
          backgroundArgbs: bgs,
          contrast: 0.5,
          algo: Algo.apca);
      final h = getHalo(
          foregroundArgb: white,
          backgroundArgbs: bgs,
          contrast: 0.5,
          algo: Algo.apca);
      expect(h.opacity, p.opacity);
      expect(h.argb, p.protectionArgb);
      expect(h.meetsTarget, p.meetsTarget);
    });
  });
}
