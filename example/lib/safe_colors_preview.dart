import 'package:example/padding.dart';

import 'package:flutter/material.dart';
import 'package:libmonet/safe_colors.dart';
import 'package:libmonet/theming/button_style.dart';

class SafeColorsPreviewRow extends StatelessWidget {
  final SafeColors safeColors;


  const SafeColorsPreviewRow({
    required this.safeColors,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return _safeColorsRow(context, safeColors);
  }

  Widget _safeColorsRow(BuildContext context, SafeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
            height: kMinInteractiveDimension,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  style: buttonStylefromSafeColorsColor(colors),
                  onPressed: () {},
                  child: const Text('Color'),
                ),
                const HorizontalPadding(),
                OutlinedButton(
                  style: buttonStylefromSafeColorsFill(colors),
                  onPressed: () {},
                  child: const Text('Fill'),
                ),
                const HorizontalPadding(),
                TextButton(
                  style: buttonStylefromSafeColorsText(colors),
                  onPressed: () {},
                  child: const Text('Text'),
                ),
                const HorizontalPadding(),
              ],
            ))
      ],
    );
  }
}
