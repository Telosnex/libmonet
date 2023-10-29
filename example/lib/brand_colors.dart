import 'package:example/padding.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:libmonet/theming/monet_theme.dart';

enum BrandColors {
  starbucksGreen,
  cocaColaRed,
  mcdonaldsYellow,
  tiffanyBlue,
  facebookBlue,
  googleBlue,
  johnDeereGreen,
  cadburyPurple,
  barbiePink,
  telosnexBlue;

  String get name {
    switch (this) {
      case BrandColors.starbucksGreen:
        return 'Starbucks Green';
      case BrandColors.cocaColaRed:
        return 'Coca-Cola Red';
      case BrandColors.mcdonaldsYellow:
        return 'McDonald\'s Yellow';
      case BrandColors.tiffanyBlue:
        return 'Tiffany Blue';
      case BrandColors.facebookBlue:
        return 'Facebook Blue';
      case BrandColors.googleBlue:
        return 'Google Blue';
      case BrandColors.johnDeereGreen:
        return 'John Deere Green';
      case BrandColors.cadburyPurple:
        return 'Cadbury Purple';
      case BrandColors.barbiePink:
        return 'Barbie Pink';
      case BrandColors.telosnexBlue:
        return 'Telosnex Blue';
    }
  }

  Color get color {
    switch (this) {
      case BrandColors.starbucksGreen:
        return const Color(0xff006241);
      case BrandColors.cocaColaRed:
        return const Color(0xfff40009);
      case BrandColors.mcdonaldsYellow:
        return const Color(0xffffc72c);
      case BrandColors.tiffanyBlue:
        return const Color(0xff0abab5);
      case BrandColors.facebookBlue:
        return const Color(0xff4267b2);
      case BrandColors.googleBlue:
        return const Color(0xff4285f4);
      case BrandColors.johnDeereGreen:
        return const Color(0xff367c2b);
      case BrandColors.cadburyPurple:
        return const Color(0xff482683);
      case BrandColors.barbiePink:
        return const Color(0xffe0218a);
      case BrandColors.telosnexBlue:
        return const Color(0xff0066AA);
    }
  }
}

class BrandColorsPopupMenuButton extends HookConsumerWidget {
  final Function(Color) onChanged;
  const BrandColorsPopupMenuButton({super.key, required this.onChanged});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<BrandColors>(
      onSelected: (value) {},
      tooltip: 'Sample Colors',
      itemBuilder: (context) {
        return BrandColors.values.map((e) {
          return PopupMenuItem<BrandColors>(
            onTap: () => onChanged(e.color),
            value: e,
            child: MonetTheme.fromColor(
              color: e.color,
              brightness: MonetTheme.of(context).brightness,
              surfaceLstar: MonetTheme.of(context).surfaceLstar,
              child: Builder(builder: (context) {
                return Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: e.color,
                      ),
                      width: 16,
                      height: 16,
                    ),
                    const HorizontalPadding(),
                    Text(
                      e.name,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                );
              }),
            ),
          );
        }).toList();
      },
      child: const Icon(Icons.explore),
    );
  }
}
