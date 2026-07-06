import 'package:flutter/material.dart';
import 'package:libmonet/colorspaces/hct.dart';
import 'package:libmonet/core/hex_codes.dart';
import 'package:libmonet/effects/afterimage.dart';
import 'package:libmonet/effects/uv_harmony.dart';

class Swatch extends StatelessWidget {
  final Color color;
  final String? tooltip;
  const Swatch({super.key, required this.color, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final swatch = AspectRatio(
      aspectRatio: 1,
      child: Container(
        color: color,
      ),
    );
    final finalTooltip = StringBuffer();
    if (tooltip != null) {
      finalTooltip.writeln(tooltip);
    }
    finalTooltip.writeln(hexFromArgb(color.argb));
    final hct = Hct.fromColor(color);
    finalTooltip.writeln(hct.toString());
    final uv = uvOfArgb(color.argb);
    if (uv != null) {
      finalTooltip.write(
        "u'v' (${uv.$1.toStringAsFixed(4)}, ${uv.$2.toStringAsFixed(4)}) "
        'H${hct.uvHue.round()} C${hct.uvChroma.toStringAsFixed(4)}',
      );
    }
    return Tooltip(
      message: finalTooltip.toString(),
      child: swatch,
    );
  }
}
