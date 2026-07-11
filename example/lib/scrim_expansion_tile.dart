import 'package:libmonet/core/hex_codes.dart';
import 'package:libmonet/effects/protection.dart';
import 'package:libmonet/effects/shadows.dart';
import 'package:monet_studio/chessboard_painter.dart';
import 'package:monet_studio/halo_text.dart';
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
    final scrimOpacity = getProtectionOpacity(
      foregroundArgb: fgArgb,
      backgroundArgbs: const [0xFF000000, 0xFFFFFFFF],
      algo: monetTheme.algo,
      contrast: contrast,
    );
    final shadows = getShadowOpacitiesForBackgrounds(
      foreground: Color(fgArgb),
      backgrounds: const [Color(0xFF000000), Color(0xFFFFFFFF)],
      algo: monetTheme.algo,
      contrast: contrast,
      blurRadius: 5,
      contentRadius: 3,
    );
    final halo = getHalo(
      foregroundArgb: fgArgb,
      backgroundArgbs: const [0xFF000000, 0xFFFFFFFF],
      algo: monetTheme.algo,
      contrast: contrast,
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
        '  Backgrounds: black, white (worst case for "any image")\n'
        '  Target contrast: $contrast\n'
        '  Algorithm: ${monetTheme.algo.name}\n'
        '\n'
        'Results\n'
        '  Scrim: $scrimString\n'
        '  Meets target: ${scrimOpacity.meetsTarget ? 'yes' : 'NO — best effort'}\n'
        '  Achieved contrast: ${scrimOpacity.achievedContrast.toStringAsFixed(2)}\n'
        '  Cleared side: ${scrimOpacity.clearedSide.name}'
        '${scrimOpacity.straddleCollapsed ? '\n  Straddle collapsed: background passed per-pixel on both sides; pushed to one side for legibility' : ''}\n'
        '  Halo: ${(halo.opacity * 100).round()}% of ${hexFromArgb(halo.argb)}, '
        '1 layer, spread ${halo.spread}, blur ${halo.blurRadius}\n'
        '  Shadows (legacy, ${shadows.opacities.length} layers): $shadowString';

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
              color: Color(scrimOpacity.protectionArgb)
                  .withValues(alpha: scrimOpacity.opacity),
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
        _label(context, 'With halo (1 layer, dilate + blur)', primaryColors),
        Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: ChessBoardPainter(squareSize: 16),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: HaloText(
                text: _sampleString,
                halo: halo,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .copyWith(color: primaryColors.backgroundText),
              ),
            ),
          ],
        ),
        const VerticalPadding(),
        _label(context, 'With shadows (legacy, stacked)', primaryColors),
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
                _sampleString,
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

  static const _sampleString =
      "This is Major Tom to Ground Control. I'm stepping through the door And I'm floating in a most peculiar way And the stars look very different today";

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
        _sampleString,
        style: Theme.of(context)
            .textTheme
            .bodyMedium!
            .copyWith(color: primaryColors.backgroundText),
      ),
    );
  }
}
