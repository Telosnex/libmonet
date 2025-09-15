import 'package:flutter/material.dart';
import 'package:libmonet/hct.dart';
import 'package:libmonet/hex_codes.dart';

class Swatch extends StatelessWidget {
  final Color color;
  final String? tooltip;
  const Swatch({super.key, required this.color, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final swatch = AspectRatio(aspectRatio: 1, child: Container(color: color,),);
    final finalTooltip = StringBuffer();
    if (tooltip != null) {
      finalTooltip.writeln(tooltip);
    }
    finalTooltip.writeln(hexFromArgb(color.argb));
    finalTooltip.write(Hct.fromColor(color).toString());
      return Tooltip(message: finalTooltip.toString(), child: swatch,);
  }
}