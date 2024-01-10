import 'package:libmonet/extract/quantizer_result.dart';
import 'package:libmonet/extract/scorer.dart';
import 'package:libmonet/extract/scorer_triad.dart';
import 'package:libmonet/hct.dart';
import 'package:monet_studio/quantizer_provider.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ExtractedWidget extends HookConsumerWidget {
  final ImageProvider image;
  final Function() onTapped;

  const ExtractedWidget({
    super.key,
    required this.image,
    required this.onTapped,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantizerResult = ref.watch(quantizerResultProvider(image));
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTapped,
      child: Tooltip(
        message: 'Press to use this image for theme.\n\n'
            'Row 1: image colors sorted by count\n'
            'Row 2: image colors sorted by hue\n'
            'Row 3: image colors sorted by hue, filtered by tone and chroma\n'
            'Row 4: three colors from triad algorithm',
        child: SizedBox(
          height: 80,
          child: Row(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Image(
                  fit: BoxFit.cover,
                  image: image,
                ),
              ),
              Expanded(
                child: Center(
                  child: switch (quantizerResult) {
                    AsyncData(:final value) => _ColorToCountRow(
                        quantizerResult: value,
                      ),
                    AsyncError() =>
                      const Text('Oops, something unexpected happened'),
                    _ => const CircularProgressIndicator(),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorToCountRow extends StatelessWidget {
  final QuantizerResult quantizerResult;
  final Map<int, int> colorToCount;
  final Map<int, int> sortedColorToCount;
  final int totalCount;

  _ColorToCountRow({
    required this.quantizerResult,

  })  : colorToCount = quantizerResult.argbToCount,
        sortedColorToCount = _sortColorToCount(quantizerResult.argbToCount),
        totalCount = quantizerResult.argbToCount.values.reduce((a, b) => a + b);

  static Map<int, int> _sortColorToCount(Map<int, int> colorToCount) {
    var sortedEntries = colorToCount.entries.toList()
      ..sort((e1, e2) => e2.value.compareTo(e1.value));
    return Map<int, int>.fromEntries(sortedEntries);
  }

  @override
  Widget build(BuildContext context) {
    final prefilterSortedByHue = sortedColorToCount.keys.toList()
      ..sort((a, b) => Hct.fromInt(a).hue.compareTo(Hct.fromInt(b).hue));
    final scorer = Scorer(quantizerResult);
    final postfilterSortedByHue = scorer.hcts
      ..sort((a, b) => a.hue.compareTo(b.hue));
    final threeHcts = ScorerTriad.threeColorsFromQuantizer( quantizerResult);
    return Column(
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            children: sortedColorToCount.keys.map((color) {
              double flex = sortedColorToCount[color]! / totalCount;
              int calculatedFlex = (flex * 1000).round();
              return Expanded(
                flex: calculatedFlex,
                child: Container(
                  color: Color(color),
                ),
              );
            }).toList(),
          ),
        ),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            children: prefilterSortedByHue.map((color) {
              double flex = sortedColorToCount[color]! / totalCount;
              int calculatedFlex = (flex * 1000).round();
              return Expanded(
                flex: calculatedFlex,
                child: Container(
                  color: Color(color),
                ),
              );
            }).toList(),
          ),
        ),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            children: postfilterSortedByHue.map((color) {
              double flex = scorer.hctToCount[color]! / totalCount;
              int calculatedFlex = (flex * 1000).round();
              return Expanded(
                flex: calculatedFlex,
                child: Container(
                  color: color.color,
                ),
              );
            }).toList(),
          ),
        ),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            children: threeHcts.map((hct) {
              return Flexible(
    
                child: Container(color: hct.color),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
