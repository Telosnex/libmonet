// ADR-001 golden calibration: render REAL stacked shadows via Skia and
// measure net alpha at the first pixel outside the content edge, comparing
// against the closed-form model in getStackedShadowSpec.
//
// Geometry: a tall black bar with its right edge on an integer pixel
// boundary at x=edgeX, over a white background. The pixel column at index
// edgeX is the "first outside pixel" (center 0.5px from the edge) — matching
// the model's kernel indexing where content occupies offsets 1..2cr.
//
// Recovered alpha: black over white composites to v = 255*(1-A), so
// A(d) = 1 - v/255 at column edgeX + (d-1).

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/contrast/contrast.dart';
import 'package:libmonet/effects/protection.dart';

const _edgeX = 96;
const _imgW = 160;
const _imgH = 64;

Future<List<double>> renderEdgeAlphas({
  required int layers,
  required double perLayerAlpha,
  required int blurRadius,
  required int contentHalfWidth,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, _imgW.toDouble(), _imgH.toDouble()),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  final sigma = convertRadiusToSigma(blurRadius.toDouble());
  // Bar much taller than the image: middle row sees a pure vertical edge.
  final bar = Rect.fromLTRB(
    (_edgeX - 2 * contentHalfWidth).toDouble(),
    -3.0 * _imgH,
    _edgeX.toDouble(),
    4.0 * _imgH,
  );
  final paint = Paint()
    ..color = const Color(0xFF000000).withValues(alpha: perLayerAlpha)
    ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigma);
  for (var i = 0; i < layers; i++) {
    canvas.drawRect(bar, paint);
  }
  final image = await recorder.endRecording().toImage(_imgW, _imgH);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  final row = _imgH ~/ 2;
  final alphas = <double>[];
  for (var x = _edgeX; x < _imgW; x++) {
    final v = bytes!.getUint8((row * _imgW + x) * 4); // red channel
    alphas.add(1 - v / 255);
  }
  return alphas;
}

void main() {
  // ADR-001 calibration gate: modeled edge coverage within ±0.01 of Skia's
  // rendered profile for wide content (measured basis for the erf model).
  test('single full layer: modeled e matches rendered pixels', () async {
    for (final r in [4, 10, 16]) {
      final spec = getStackedShadowSpec(
        foregroundArgb: 0xFF777777,
        backgroundArgbs: const [0xFF777777],
        contrast: 0.5,
        algo: Algo.wcag21,
        blurRadius: r.toDouble(),
      );
      final measured = await renderEdgeAlphas(
        layers: 1,
        perLayerAlpha: 1.0,
        blurRadius: r,
        contentHalfWidth: r, // default cr: content wider than kernel reach
      );
      // ignore: avoid_print
      print('r=$r modeled e=${spec.edgeCoverage.toStringAsFixed(4)} '
          'measured A(d=1..4)=${measured.take(4).map((a) => a.toStringAsFixed(4)).join(", ")}');
      expect(measured.first, closeTo(spec.edgeCoverage, 0.01),
          reason: 'erf edge model must match rendered coverage at r=$r');
    }
  });

  // ADR-001 calibration gate (±0.03): when the spec claims meetsTarget, the
  // RENDERED stack must deliver at least requiredOpacity - 0.03 at the first
  // outside pixel; overshoot is unbounded (safe direction). When the spec
  // says meetsTarget=false, the render must confirm the shortfall — an
  // honest flag, not a pessimistic one.
  test('full stack: rendered net alpha honors meetsTarget', () async {
    for (final (name, r, cr) in [
      ('r=4 wide', 4, -1.0),
      ('r=10 wide', 10, -1.0),
      ('r=16 wide', 16, -1.0),
      ('r=10 thin cr=2', 10, 2.0),
      ('r=10 thin cr=2 LOW contrast', 10, 2.0),
      ('r=4 thin cr=1 LOW contrast', 4, 1.0),
    ]) {
      final spec = getStackedShadowSpec(
        foregroundArgb: 0xFF777777,
        backgroundArgbs: const [0xFF777777],
        contrast: name.contains('LOW') ? 0.25 : 0.5,
        algo: Algo.wcag21,
        blurRadius: r.toDouble(),
        contentRadius: cr,
      );
      if (spec.opacities.isEmpty) continue;
      final chw = cr < 0 ? r : cr.round();
      final measured = await renderEdgeAlphas(
        layers: spec.opacities.length,
        perLayerAlpha: spec.opacities.first,
        blurRadius: r,
        contentHalfWidth: chw,
      );
      final modeled = 1 -
          List.filled(spec.opacities.length, 0).fold<double>(
              1.0, (acc, _) => acc * (1 - spec.opacities.first * spec.edgeCoverage));
      // ignore: avoid_print
      print('$name: meets=${spec.meetsTarget} n=${spec.opacities.length} p=${spec.opacities.first.toStringAsFixed(4)} '
          'required=${spec.requiredOpacity.toStringAsFixed(4)} '
          'modeledNet=${modeled.toStringAsFixed(4)} '
          'measuredNet(d=1)=${measured.first.toStringAsFixed(4)} '
          'delta=${(measured.first - spec.requiredOpacity).toStringAsFixed(4)}');
      if (spec.meetsTarget) {
        expect(measured.first,
            greaterThanOrEqualTo(spec.requiredOpacity - 0.03),
            reason: '$name: claimed meetsTarget but rendered pixels fall '
                'more than 0.03 short (current worst measured: -0.008)');
      } else {
        expect(measured.first, lessThan(spec.requiredOpacity),
            reason: '$name: flagged meetsTarget=false but the render '
                'actually reaches the target — flag is lying pessimistic');
      }
    }
  });
}
