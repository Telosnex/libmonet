import 'package:monet_ui/monet_ui.dart';
import 'package:monet_studio/chessboard_painter.dart';
import 'package:monet_studio/halo_text.dart';
import 'package:monet_studio/padding.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ScrimExpansionTile extends ConsumerWidget {
  final double contrast;

  const ScrimExpansionTile({super.key, required this.contrast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monetTheme = MonetTheme.of(context);
    final primaryColors = monetTheme.primary;
    final fgArgb = primaryColors.backgroundText.argb;
    final scrim = AnyBackground.unknown(
      algo: monetTheme.algo,
      contrast: contrast,
    ).scrimFor(fgArgb);
    final shadows = scrim.shadows(blurRadius: 5, contentRadius: 3);
    final stroked = scrim.shadowsWithStroke();
    final shadowString = StringBuffer();
    if (shadows.layerOpacities.isEmpty) {
      shadowString.write('none');
    } else {
      final oneHundredPercent = shadows.layerOpacities.where((o) => o == 1.0);
      if (oneHundredPercent.isNotEmpty) {
        shadowString.write('${oneHundredPercent.length} @ 100%, 1 @ ');
      }
      shadowString.write(
          '${(shadows.layerOpacities.last * 100).round()}% of ${hexFromArgb(shadows.scrim.scrimArgb)}');
    }

    final scrimString = StringBuffer();
    final scrimPercentageInt = (scrim.opacity * 100).ceil().clamp(0, 100);
    if (scrimPercentageInt == 0) {
      scrimString.write('none');
    } else {
      scrimString.write(
          '${(scrim.opacity * 100).ceil()}% of ${hexFromArgb(scrim.scrimArgb)}');
    }

    final inputsText = 'Inputs\n'
        '  Text color: ${hexFromArgb(fgArgb)}\n'
        '  Backgrounds: black, white (worst case for "any image")\n'
        '  Target contrast: $contrast\n'
        '  Algorithm: ${monetTheme.algo.name}\n'
        '\n'
        'Results\n'
        '  scrimFor: $scrimString\n'
        '  Meets target: ${scrim.meetsTarget ? 'yes' : 'NO — best effort'}\n'
        '  Worst contrast: ${scrim.worstContrast.toStringAsFixed(2)}\n'
        '  Polarity: ${scrim.polarity.name}'
        '${scrim.mixedPolarityRejected ? '\n  Mixed polarity rejected: background passed per-pixel on both sides; pushed to one side for legibility' : ''}\n'
        '  shadowsWithStroke: ${(stroked.scrim.opacity * 100).round()}% of ${hexFromArgb(stroked.scrim.scrimArgb)}, '
        '1 layer, stroke ${stroked.stroke}, blur ${stroked.blurRadius}\n'
        '  shadows (${shadows.layerOpacities.length} layers): $shadowString';

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
        _label(context, 'scrim (rect)', primaryColors),
        Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: ChessBoardPainter(squareSize: 16),
              ),
            ),
            Positioned.fill(
                child: Container(
              color: Color(scrim.scrimArgb).withValues(alpha: scrim.opacity),
            )),
            _sampleText(context, primaryColors),
          ],
        ),
        const VerticalPadding(),
        _label(context, 'No scrim', primaryColors),
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
        _label(
            context, 'scrim.shadowsWithStroke (stroke + blur)', primaryColors),
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
                stroked: stroked,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .copyWith(color: primaryColors.backgroundText),
              ),
            ),
          ],
        ),
        const VerticalPadding(),
        _label(context, 'scrim.shadows (stacked, approximate)', primaryColors),
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
                    shadows: shadows.textShadows),
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
