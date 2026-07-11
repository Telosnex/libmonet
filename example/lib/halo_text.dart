import 'package:flutter/material.dart';
import 'package:libmonet/effects/protection.dart';

/// Renders text with a single dilated-then-blurred halo underlay — i.e. a 
/// stroke / spread radius, then, a blur.
///
/// Two paint passes:
///  1. Underlay: the same glyphs stroked at width `2 * spread` with
///     `MaskFilter.blur(BlurStyle.solid, sigma)`. `BlurStyle.solid` keeps the
///     stroke band itself at full paint alpha and blurs only beyond it, so
///     coverage at the glyph edge is exactly 1.0 — which is what makes
///     [HaloResult.opacity] the paint alpha with no kernel model, no layer
///     stack, no calibration constant.
///  2. The text itself, unchanged, on top.
///
/// Contrast this with the legacy stacked-shadow path (D-5 fallback): N plain
/// Gaussian layers whose edge coverage is modeled (~0.3/layer), requiring a
/// layer loop and honest-but-awkward accounting.
class HaloText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final HaloResult halo;

  const HaloText({
    super.key,
    required this.text,
    required this.style,
    required this.halo,
  });

  @override
  Widget build(BuildContext context) {
    final underlayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * halo.spread
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = Color(halo.argb).withValues(alpha: halo.opacity)
      ..maskFilter = MaskFilter.blur(
        BlurStyle.solid,
        convertRadiusToSigma(halo.blurRadius),
      );
    // Identical Text widgets under identical constraints wrap identically,
    // so the two passes stay glyph-aligned.
    return Stack(
      children: [
        Text(text, style: style.copyWith(foreground: underlayPaint)),
        Text(text, style: style),
      ],
    );
  }
}
