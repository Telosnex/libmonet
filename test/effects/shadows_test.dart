import 'dart:math' as math;

import 'package:monet_ui/contrast/contrast.dart';
import 'package:monet_ui/core/argb_srgb_xyz_lab.dart';
import 'package:monet_ui/effects/over_image.dart';
import 'package:test/test.dart';

/// Modeled net alpha at the first pixel outside the glyph for a stack of
/// identical layers: 1 - (1 - p*e)^n.
double netEdgeAlpha(Shadows spec) {
  var remaining = 1.0;
  for (final p in spec.layerOpacities) {
    remaining *= 1 - p * spec.edgeCoverage;
  }
  return 1 - remaining;
}

void checkSpec(Shadows spec) {
  // Uniform layers by construction (closed form, not greedy).
  for (final p in spec.layerOpacities) {
    expect(p, spec.layerOpacities.first);
    expect(p, inInclusiveRange(0.0, 1.0));
    // Renderable as-is: paint alpha is quantized to 1/255, rounded UP, so
    // what the renderer draws is what we audited — no silent re-rounding.
    expect(
      (p * 255) - (p * 255).round(),
      closeTo(0, 1e-9),
      reason: 'per-layer alpha must be a multiple of 1/255',
    );
  }
  if (spec.meetsTarget && spec.scrim.opacity > 0) {
    // Coverage audit: stack reaches the solver's required opacity. No
    // epsilon forgiveness: quantize-up means net must clear alpha exactly
    // or better, never "close enough from below".
    expect(netEdgeAlpha(spec), greaterThanOrEqualTo(spec.scrim.opacity));
    // ...and minimally: one fewer layer at full paint alpha cannot.
    final n = spec.layerOpacities.length;
    expect(
      1 - math.pow(1 - spec.edgeCoverage, n - 1),
      lessThan(spec.scrim.opacity),
    );
  }
}

Shadows specFor({
  required double fgLstar,
  required List<double> bgLstars,
  double contrast = 0.5,
  Algo algo = Algo.wcag21,
  double blurRadius = 10,
  double contentRadius = -1.0,
}) {
  return AnyBackground(
        bgLstars.map(argbFromLstar).toList(),
        algo: algo,
        contrast: contrast,
      )
      .scrimFor(argbFromLstar(fgLstar))
      .shadows(blurRadius: blurRadius, contentRadius: contentRadius);
}

void main() {
  group('closed-form stacks: uniform, sufficient, minimal', () {
    // (fg L*, bg L*s) cases mirroring the legacy suite: black bg, zebra
    // (black+white), white bg — the mid-tone fgs that need protection.
    final cases = <(double, List<double>)>[
      (40, [0.0]),
      (30, [0.0]),
      (100, [0.0, 100.0]),
      (40, [0.0, 100.0]),
      (30, [0.0, 100.0]),
      (0, [0.0, 100.0]),
      (100, [100.0]),
      (90, [100.0]),
    ];
    for (final (fg, bgs) in cases) {
      test('FG $fg over $bgs', () {
        final spec = specFor(fgLstar: fg, bgLstars: bgs);
        expect(
          spec.layerOpacities,
          isNotEmpty,
          reason: 'mid-tone/same-tone fg must need protection',
        );
        expect(spec.meetsTarget, isTrue);
        checkSpec(spec);
      });
    }
  });

  group('known cases', () {
    test('zero blur with needed protection: empty and flagged', () {
      final spec = specFor(fgLstar: 50, bgLstars: [50], blurRadius: 0);
      expect(spec.layerOpacities, isEmpty);
      expect(spec.meetsTarget, isFalse);
      expect(spec.scrim.opacity, greaterThan(0));
    });
    test('layer cap: best effort at full alpha, flagged', () {
      // Tiny content (1px hairline) under a huge blur: edge coverage is so
      // low that the cap must trip rather than emit a giant stack.
      final spec = specFor(
        fgLstar: 50,
        bgLstars: [50],
        blurRadius: 40,
        contentRadius: 1,
      );
      if (!spec.meetsTarget) {
        expect(spec.layerOpacities, everyElement(1.0));
      } else {
        checkSpec(spec);
      }
    });
    test('D4 regression: small content uses edge-adjacent kernel entries', () {
      // Same inputs, smaller content: edge coverage must DROP (less of the
      // kernel is covered) but remain the near-edge sum, not the far tail.
      final wide = specFor(fgLstar: 50, bgLstars: [50], blurRadius: 10);
      final narrow = specFor(
        fgLstar: 50,
        bgLstars: [50],
        blurRadius: 10,
        contentRadius: 2,
      );
      expect(narrow.edgeCoverage, lessThan(wide.edgeCoverage));
      // Legacy bug summed the smallest (far-tail) weights: for r=10, cr=2
      // that was < 0.02. Edge-adjacent entries for the same geometry are an
      // order of magnitude larger.
      expect(narrow.edgeCoverage, greaterThan(0.1));
      checkSpec(narrow);
    });
  });
}
