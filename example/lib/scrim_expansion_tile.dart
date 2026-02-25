import 'package:libmonet/core/hex_codes.dart';
import 'package:libmonet/effects/opacity.dart';
import 'package:libmonet/effects/shadows.dart';
import 'package:monet_studio/chessboard_painter.dart';
import 'package:monet_studio/padding.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:libmonet/theming/monet_theme.dart';

class ScrimExpansionTile extends ConsumerWidget {
  final double contrast;

  const ScrimExpansionTile({super.key, required this.contrast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monetTheme = MonetTheme.of(context);
    final primaryColors = monetTheme.primary;
    final fgArgb = primaryColors.backgroundText.argb;
    final scrimOpacity = getOpacityForArgbs(
      foregroundArgb: fgArgb,
      minBackgroundArgb: 0xFF000000,
      maxBackgroundArgb: 0xFFFFFFFF,
      algo: monetTheme.algo,
      contrast: contrast,
    );
    final shadows = getShadowOpacitiesForArgbs(
      foregroundArgb: fgArgb,
      minBackgroundArgb: 0xFF000000,
      maxBackgroundArgb: 0xFFFFFFFF,
      algo: monetTheme.algo,
      contrast: contrast,
      blurRadius: 5,
      contentRadius: 3,
    );
    final shadowString = StringBuffer();
    if (shadows.opacities.isEmpty) {
      shadowString.write('none');
    } else {
      final oneHundredPercent = shadows.opacities.where((o) => o == 1.0);
      if (oneHundredPercent.isNotEmpty) {
        shadowString.write('${oneHundredPercent.length} @ 100%, 1 @ ');
      }
      shadowString.write(
          '${(shadows.opacities.last * 100).round()}% of ${hexFromArgb(shadows.shadowArgb)}');
    }

    final scrimString = StringBuffer();
    final scrimPercentageInt =
        (scrimOpacity.opacity * 100).ceil().clamp(0, 100);
    if (scrimPercentageInt == 0) {
      scrimString.write('none');
    } else {
      scrimString.write(
          '${(scrimOpacity.opacity * 100).ceil()}% of ${hexFromArgb(scrimOpacity.protectionArgb)}');
    }

    final inputsText = 'Inputs\n'
        '  Text color: ${hexFromArgb(fgArgb)}\n'
        '  Min background: ${hexFromArgb(0xFF000000)} (black)\n'
        '  Max background: ${hexFromArgb(0xFFFFFFFF)} (white)\n'
        '  Target contrast: $contrast\n'
        '  Algorithm: ${monetTheme.algo.name}\n'
        '\n'
        'Results\n'
        '  Scrim: $scrimString\n'
        '  Shadows: $shadowString';

    return ExpansionTile(
      title: Text(
        'Scrim & Shadows',
        style: Theme.of(context)
            .textTheme
            .headlineLarge!
            .copyWith(color: primaryColors.text),
      ),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: SelectableText(
            inputsText,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  fontFamily: 'monospace',
                  color: primaryColors.text,
                ),
          ),
        ),
        const VerticalPadding(),
        _label(context, 'With scrim', primaryColors),
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
            _sampleText(context, primaryColors),
          ],
        ),
        const VerticalPadding(),
        _label(context, 'No protection', primaryColors),
        Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: ChessBoardPainter(squareSize: 16),
              ),
            ),
            _sampleText(context, primaryColors),
          ],
        ),
        const VerticalPadding(),
        _label(context, 'With shadows', primaryColors),
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
        ),
      ],
    );
  }

  Widget _label(BuildContext context, String text, dynamic primaryColors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall!.copyWith(
              color: primaryColors.text,
            ),
      ),
    );
  }

  Widget _sampleText(BuildContext context, dynamic primaryColors) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        "This is Major Tom to Ground Control. I'm stepping through the door And I'm floating in a most peculiar way And the stars look very different today",
        style: Theme.of(context)
            .textTheme
            .bodyMedium!
            .copyWith(color: primaryColors.backgroundText),
      ),
    );
  }
}
