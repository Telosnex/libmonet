import 'package:example/padding.dart';

import 'package:flutter/material.dart';
import 'package:libmonet/safe_colors.dart';


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
                ElevatedButton(onPressed: () {}, child: const Text('Elevated')),
                const HorizontalPadding(),

                FilledButton(
                  // style: buttonStylefromSafeColorsColor(colors),
                  onPressed: () {},
                  child: const Text('Filled'),
                ),
                const HorizontalPadding(),

                OutlinedButton(onPressed: () {}, child: const Text('Outline')),
                const HorizontalPadding(),

                TextButton(onPressed: () {}, child: const Text('Text')),
              ],
            ))
      ],
    );
  }
}
