import 'package:example/chessboard_painter.dart';
import 'package:example/padding.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:libmonet/argb_srgb_xyz_lab.dart';
import 'package:libmonet/hex_codes.dart';
import 'package:libmonet/theming/monet_theme.dart';
import 'package:libmonet/opacity.dart';
import 'package:libmonet/shadows.dart';

class ScrimExpansionTile extends ConsumerWidget {
  final double contrast;

  const ScrimExpansionTile({super.key, required this.contrast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monetTheme = MonetTheme.of(context);
    final primaryColors = monetTheme.primary;
    final scrimOpacity = getOpacity(
      minBgLstar: 0,
      maxBgLstar: 100,
      algo: monetTheme.algo,
      foregroundLstar: lstarFromArgb(primaryColors.backgroundText.value),
      contrast: contrast,
    );
    final shadows = getShadowOpacities(
      minBgLstar: 0,
      maxBgLstar: 100,
      algo: monetTheme.algo,
      foregroundLstar: lstarFromArgb(primaryColors.backgroundText.value),
      contrast: contrast,
      blurRadius: 5,
      contentRadius: 3,
    );
    final shadowString = StringBuffer();
    shadowString.write('Shadows: ');
    if (shadows.opacities.isEmpty) {
      shadowString.write('none');
    } else {
      final oneHundredPercent = shadows.opacities.where((o) => o == 1.0);
      if (oneHundredPercent.isNotEmpty) {
        shadowString.write('${oneHundredPercent.length} @ 100%, 1 @ ');
      }
      shadowString.write(
          '${(shadows.opacities.last * 100).round()}% of ${hexFromArgb(argbFromLstar(shadows.lstar))}');
    }

    final scrimString = StringBuffer();
    scrimString.write('Scrim: ');
    final scrimPercentageInt =
        (scrimOpacity.opacity * 100).ceil().clamp(0, 100);
    if (scrimPercentageInt == 0) {
      scrimString.write('none');
    } else {
      scrimString.write(
          '${(scrimOpacity.opacity * 100).ceil()}% of ${hexFromArgb(argbFromLstar(scrimOpacity.lstar))}');
    }

    return ExpansionTile(
      title: Text(
        'Scrim',
        style: Theme.of(context)
            .textTheme
            .headlineLarge!
            .copyWith(color: primaryColors.text),
      ),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(scrimString.toString()),
              Text(shadowString.toString()),
            ],
          ),
        ),
        const VerticalPadding(),
        Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: ChessBoardPainter(squareSize: 16),
              ),
            ),
            Positioned.fill(
                child: Container(
              color: scrimOpacity.color,
            )),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "This is Major Tom to Ground Control. I'm stepping through the door And I'm floating in a most peculiar way And the stars look very different today",
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .copyWith(color: primaryColors.backgroundText),
              ),
            ),
          ],
        ),
        Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: ChessBoardPainter(squareSize: 16),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "This is Major Tom to Ground Control. I'm stepping through the door And I'm floating in a most peculiar way And the stars look very different today",
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .copyWith(color: primaryColors.backgroundText),
              ),
            ),
          ],
        ),
        Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: ChessBoardPainter(squareSize: 16),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "This is Major Tom to Ground Control. I'm stepping through the door And I'm floating in a most peculiar way And the stars look very different today",
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: primaryColors.backgroundText,
                    shadows: shadows.shadows),
              ),
            ),
          ],
        )
      ],
    );
  }
}
