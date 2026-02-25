import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:libmonet/colorspaces/cam16.dart';
import 'package:libmonet/colorspaces/cam16_viewing_conditions.dart';
import 'package:libmonet/colorspaces/gamut.dart';
import 'package:libmonet/colorspaces/hct_solver.dart';
import 'package:libmonet/core/argb_srgb_xyz_lab.dart';
import 'package:libmonet/theming/monet_theme.dart';
import 'package:libmonet/theming/slider_flat.dart';
import 'package:libmonet/theming/slider_flat_thumb.dart';

// =============================================================================
// Cell data — stores everything we need for display and diagnostics.
// =============================================================================

class _CellData {
  final double requestedHue;
  final double requestedChroma;
  final double requestedTone;

  // sRGB solve results
  final Color? srgbColor;
  final bool inSrgb;
  final double srgbActualHue;
  final double srgbActualChroma;
  final double srgbActualTone;
  final (double, double, double) srgbLinear;

  // Display P3 solve results
  final Color? p3Color;
  final bool inP3;
  final double p3ActualHue;
  final double p3ActualChroma;
  final double p3ActualTone;
  final (double, double, double) p3Linear;

  const _CellData({
    required this.requestedHue,
    required this.requestedChroma,
    required this.requestedTone,
    required this.srgbColor,
    required this.inSrgb,
    required this.srgbActualHue,
    required this.srgbActualChroma,
    required this.srgbActualTone,
    required this.srgbLinear,
    required this.p3Color,
    required this.inP3,
    required this.p3ActualHue,
    required this.p3ActualChroma,
    required this.p3ActualTone,
    required this.p3Linear,
  });
}

// =============================================================================
// Compute a single cell
// =============================================================================

_CellData _computeCell(double hue, double chroma, double tone) {
  // Solve in sRGB
  final sLinear =
      HctSolver.solveToLinrgb(hue, chroma, tone, gamut: Gamut.srgb);
  final sRound = _roundtrip(sLinear.$1, sLinear.$2, sLinear.$3, Gamut.srgb);
  final inSrgb = chroma < 0.5 || (sRound.chroma >= chroma - 1.5);
  final (sDr, sDg, sDb) =
      HctSolver.solveToDisplayRgb(hue, chroma, tone, gamut: Gamut.srgb);
  final srgbColor =
      inSrgb ? Color.from(alpha: 1.0, red: sDr, green: sDg, blue: sDb) : null;

  // Solve in Display P3
  final pLinear =
      HctSolver.solveToLinrgb(hue, chroma, tone, gamut: Gamut.displayP3);
  final pRound =
      _roundtrip(pLinear.$1, pLinear.$2, pLinear.$3, Gamut.displayP3);
  final inP3 = chroma < 0.5 || (pRound.chroma >= chroma - 1.5);
  Color? p3Color;
  if (inP3) {
    final (pDr, pDg, pDb) = HctSolver.solveToDisplayRgb(hue, chroma, tone,
        gamut: Gamut.displayP3);
    p3Color = Color.from(
      alpha: 1.0,
      red: pDr,
      green: pDg,
      blue: pDb,
      colorSpace: ui.ColorSpace.displayP3,
    );
  }

  return _CellData(
    requestedHue: hue,
    requestedChroma: chroma,
    requestedTone: tone,
    srgbColor: srgbColor,
    inSrgb: inSrgb,
    srgbActualHue: sRound.hue,
    srgbActualChroma: sRound.chroma,
    srgbActualTone: sRound.tone,
    srgbLinear: sLinear,
    p3Color: p3Color,
    inP3: inP3,
    p3ActualHue: pRound.hue,
    p3ActualChroma: pRound.chroma,
    p3ActualTone: pRound.tone,
    p3Linear: pLinear,
  );
}

/// Roundtrips linear RGB through XYZ → CAM16 → L* to get actual HCT.
({double hue, double chroma, double tone}) _roundtrip(
    double linR, double linG, double linB, Gamut gamut) {
  final m = gamut.rgbToXyz;
  final x = linR * m[0][0] + linG * m[0][1] + linB * m[0][2];
  final y = linR * m[1][0] + linG * m[1][1] + linB * m[1][2];
  final z = linR * m[2][0] + linG * m[2][1] + linB * m[2][2];
  final cam =
      Cam16.fromXyzInViewingConditions(x, y, z, Cam16ViewingConditions.sRgb);
  return (hue: cam.hue, chroma: cam.chroma, tone: lstarFromY(y));
}

// =============================================================================
// Main widget
// =============================================================================

class GamutChart extends HookConsumerWidget {
  final double initialHue;

  const GamutChart({super.key, this.initialHue = 0.0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hue = useState(initialHue);
    final letterTextStyle = Theme.of(context).textTheme.headlineLarge!.copyWith(
        fontWeight: FontWeight.w500,
        color: MonetTheme.of(context).primary.colorIcon);

    return ExpansionTile(
      title: Text(
        'Wide Gamut Chart',
        style: Theme.of(context).textTheme.headlineLarge!.copyWith(
              color: MonetTheme.of(context).primary.text,
            ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              // Hue slider
              Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(
                      'Hue ${hue.value.round()}°',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                            color: MonetTheme.of(context).primary.text,
                          ),
                    ),
                  ),
                  Expanded(
                    child: SliderFlat(
                      slider: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          thumbShape: SliderFlatThumb(
                            borderWidth: 2,
                            borderColor:
                                MonetTheme.of(context).primary.colorBorder,
                            letterTextStyle: letterTextStyle,
                            letter: 'H',
                          ),
                        ),
                        child: Slider(
                          value: hue.value,
                          min: 0,
                          max: 360,
                          onChanged: (v) => hue.value = v,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // The chart
              LayoutBuilder(builder: (context, constraints) {
                return _GamutChartBody(
                  hue: hue.value,
                  maxChroma: 150.0,
                  width: constraints.maxWidth,
                );
              }),
              const SizedBox(height: 8),
              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _LegendItem(
                    color: Colors.transparent,
                    border: null,
                    label: 'sRGB',
                  ),
                  const SizedBox(width: 24),
                  _LegendItem(
                    color: Colors.transparent,
                    border: Border.all(color: Colors.white, width: 2),
                    label: 'Display P3 only',
                  ),
                  const SizedBox(width: 24),
                  _LegendItem(
                    color: Colors.grey.shade800,
                    border: null,
                    label: 'Out of gamut',
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final BoxBorder? border;
  final String label;

  const _LegendItem({
    required this.color,
    required this.border,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            border: border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: MonetTheme.of(context).primary.text,
              ),
        ),
      ],
    );
  }
}

// =============================================================================
// The chart body — precomputes cells, handles hover, shows tooltip
// =============================================================================

class _GamutChartBody extends HookWidget {
  final double hue;
  final double maxChroma;
  final double width;

  const _GamutChartBody({
    required this.hue,
    required this.maxChroma,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final hoveredCell = useState<_CellData?>(null);
    final hoverPos = useState<Offset?>(null);

    // Chroma steps: 0, 10, 20, ... up to maxChroma
    final chromaSteps = <double>[
      for (var c = 0.0; c <= maxChroma; c += 10.0) c
    ];
    // Tone steps: 100, 90, 80, ... 0 (top to bottom)
    final toneSteps = <double>[
      for (var t = 100.0; t >= 0.0; t -= 10.0) t
    ];

    final cols = chromaSteps.length;
    final rows = toneSteps.length;

    // Compute cell data
    final cells = useMemoized(() {
      final result = <_CellData>[];
      for (final tone in toneSteps) {
        for (final chroma in chromaSteps) {
          result.add(_computeCell(hue, chroma, tone));
        }
      }
      return result;
    }, [hue, maxChroma]);

    // Layout
    const labelWidth = 32.0;
    const labelHeight = 20.0;
    final chartWidth = width - labelWidth;
    final cellSize = chartWidth / cols;
    final chartHeight = cellSize * rows;
    final totalHeight = chartHeight + labelHeight;

    return SizedBox(
      width: width,
      height: totalHeight + _kTooltipMaxHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The painted chart + mouse tracking
          Positioned(
            left: 0,
            top: 0,
            width: width,
            height: totalHeight,
            child: MouseRegion(
              onHover: (event) {
                hoverPos.value = event.localPosition;
                final col =
                    ((event.localPosition.dx - labelWidth) / cellSize).floor();
                final row = (event.localPosition.dy / cellSize).floor();
                if (col >= 0 && col < cols && row >= 0 && row < rows) {
                  hoveredCell.value = cells[row * cols + col];
                } else {
                  hoveredCell.value = null;
                }
              },
              onExit: (_) {
                hoveredCell.value = null;
                hoverPos.value = null;
              },
              child: CustomPaint(
                size: Size(width, totalHeight),
                painter: _GamutChartPainter(
                  cells: cells,
                  cols: cols,
                  rows: rows,
                  chromaSteps: chromaSteps,
                  toneSteps: toneSteps,
                  labelWidth: labelWidth,
                  labelHeight: labelHeight,
                ),
              ),
            ),
          ),

          // Tooltip
          if (hoveredCell.value != null && hoverPos.value != null)
            Positioned(
              left: 0,
              right: 0,
              top: totalHeight + 4,
              child: _HoverTooltip(cell: hoveredCell.value!),
            ),
        ],
      ),
    );
  }
}

const _kTooltipMaxHeight = 100.0;

// =============================================================================
// Hover tooltip — shows requested vs actual HCT for both gamuts
// =============================================================================

class _HoverTooltip extends StatelessWidget {
  final _CellData cell;

  const _HoverTooltip({required this.cell});

  @override
  Widget build(BuildContext context) {
    final monet = MonetTheme.of(context);
    final labelStyle = Theme.of(context).textTheme.bodySmall!.copyWith(
          color: monet.primary.text,
          fontFamily: 'monospace',
          fontSize: 11,
          height: 1.4,
        );
    final headerStyle = labelStyle.copyWith(fontWeight: FontWeight.bold);

    final c = cell;
    final reqH = c.requestedHue.toStringAsFixed(1);
    final reqC = c.requestedChroma.toStringAsFixed(1);
    final reqT = c.requestedTone.toStringAsFixed(1);

    String gamutLine(String name, double actH, double actC, double actT,
        (double, double, double) lin, bool inGamut) {
      final hDelta = _hueDelta(c.requestedHue, actH);
      final hDeltaStr =
          '${hDelta >= 0 ? '+' : ''}${hDelta.toStringAsFixed(1)}';
      final cDelta = actC - c.requestedChroma;
      final cDeltaStr =
          '${cDelta >= 0 ? '+' : ''}${cDelta.toStringAsFixed(1)}';

      final tag = inGamut ? '✓' : '✗';
      return '$tag $name  '
          'H ${actH.toStringAsFixed(1).padLeft(6)}  (Δ${hDeltaStr.padLeft(6)})  '
          'C ${actC.toStringAsFixed(1).padLeft(6)}  (Δ${cDeltaStr.padLeft(6)})  '
          'T ${actT.toStringAsFixed(1).padLeft(6)}  '
          'linRGB [${lin.$1.toStringAsFixed(2)}, ${lin.$2.toStringAsFixed(2)}, ${lin.$3.toStringAsFixed(2)}]';
    }

    final srgbLine = gamutLine('sRGB', c.srgbActualHue, c.srgbActualChroma,
        c.srgbActualTone, c.srgbLinear, c.inSrgb);
    final p3Line = gamutLine('P3  ', c.p3ActualHue, c.p3ActualChroma,
        c.p3ActualTone, c.p3Linear, c.inP3);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: monet.primary.background.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: monet.primary.colorBorder.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Requested  H $reqH   C $reqC   T $reqT', style: headerStyle),
          const SizedBox(height: 4),
          Text(srgbLine, style: labelStyle),
          Text(p3Line, style: labelStyle),
        ],
      ),
    );
  }

  /// Signed hue delta in [-180, 180].
  static double _hueDelta(double requested, double actual) {
    var d = actual - requested;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d;
  }
}

// =============================================================================
// Custom painter
// =============================================================================

class _GamutChartPainter extends CustomPainter {
  final List<_CellData> cells;
  final int cols;
  final int rows;
  final List<double> chromaSteps;
  final List<double> toneSteps;
  final double labelWidth;
  final double labelHeight;

  _GamutChartPainter({
    required this.cells,
    required this.cols,
    required this.rows,
    required this.chromaSteps,
    required this.toneSteps,
    required this.labelWidth,
    required this.labelHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chartWidth = size.width - labelWidth;
    final cellSize = chartWidth / cols;

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()..style = PaintingStyle.stroke;
    final emptyPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF1A1A1A);

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final cell = cells[row * cols + col];
        final x = labelWidth + col * cellSize;
        final y = row * cellSize;
        final rect = Rect.fromLTWH(x, y, cellSize, cellSize);

        if (cell.inP3 && !cell.inSrgb) {
          // P3-only: fill with P3 color + glowing border
          fillPaint.color = cell.p3Color!;
          canvas.drawRect(rect, fillPaint);

          final glowRect = rect.deflate(1.0);
          borderPaint.color = Colors.white.withValues(alpha: 0.9);
          borderPaint.strokeWidth = 2.0;
          canvas.drawRect(glowRect, borderPaint);
          borderPaint.color = Colors.white.withValues(alpha: 0.3);
          borderPaint.strokeWidth = 4.0;
          canvas.drawRect(rect, borderPaint);
        } else if (cell.inSrgb) {
          fillPaint.color = cell.srgbColor!;
          canvas.drawRect(rect, fillPaint);
        } else {
          canvas.drawRect(rect, emptyPaint);
          final crossPaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5
            ..color = const Color(0xFF333333);
          canvas.drawLine(rect.topLeft, rect.bottomRight, crossPaint);
          canvas.drawLine(rect.topRight, rect.bottomLeft, crossPaint);
        }
      }
    }

    // Tone labels (Y axis)
    for (var row = 0; row < rows; row++) {
      final tone = toneSteps[row];
      final y = row * cellSize + cellSize / 2;
      _drawLabel(canvas, tone.toInt().toString(), Offset(labelWidth - 4, y),
          alignRight: true);
    }

    // Chroma labels (X axis)
    for (var col = 0; col < cols; col++) {
      final chroma = chromaSteps[col];
      final x = labelWidth + col * cellSize + cellSize / 2;
      final y = rows * cellSize + 4;
      _drawLabel(canvas, chroma.toInt().toString(), Offset(x, y),
          alignRight: false);
    }

    // Axis titles
    _drawLabel(
      canvas,
      'T',
      Offset(2, rows * cellSize / 2),
      alignRight: false,
      bold: true,
    );
    _drawLabel(
      canvas,
      'C →',
      Offset(labelWidth + cols * cellSize / 2, rows * cellSize + 14),
      alignRight: false,
      bold: true,
    );
  }

  void _drawLabel(Canvas canvas, String text, Offset position,
      {bool alignRight = false, bool bold = false}) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: alignRight ? TextAlign.right : TextAlign.center,
      fontSize: 10,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    ))
      ..pushStyle(ui.TextStyle(color: const Color(0xFFAAAAAA)))
      ..addText(text);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 30));
    final dx = alignRight ? position.dx - 30 : position.dx - 15;
    final dy = position.dy - paragraph.height / 2;
    canvas.drawParagraph(paragraph, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(_GamutChartPainter oldDelegate) {
    return !identical(cells, oldDelegate.cells);
  }
}
