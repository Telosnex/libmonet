import 'package:libmonet/extract/quantizer_result.dart';
import 'package:libmonet/extract/scorer.dart';
import 'package:libmonet/extract/scorer_triad.dart';
import 'package:libmonet/hct.dart';
import 'package:monet_studio/quantizer_provider.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ExtractedWidget extends HookConsumerWidget {
  final ImageProvider image;
  final Function(Color) onColorTapped;

  const ExtractedWidget({
    super.key,
    required this.image,
    required this.onColorTapped,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantizerResult = ref.watch(quantizerResultProvider(image));
    return SizedBox(
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
            child: switch (quantizerResult) {
              AsyncData(:final value) => _ColorToCountRow(
                  quantizerResult: value,
                  onColorTapped: onColorTapped,
                ),
              AsyncError() => const Text('Oops, something unexpected happened'),
              _ => const CircularProgressIndicator(),
            },
          ),
        ],
      ),
    );
  }
}

class _ColorToCountRow extends StatelessWidget {
  final QuantizerResult quantizerResult;
  final Map<int, int> colorToCount;
  final Map<int, int> sortedColorToCount;
  final int totalCount;
  final Function(Color) onColorTapped;

  _ColorToCountRow({
    required this.quantizerResult,
    required this.onColorTapped,
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
    final threeHcts = ScorerTriad.threeColorsFromQuantizer(
        Theme.of(context).brightness == Brightness.light, quantizerResult);
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

                child: GestureDetector(
                  onTap: () {
                    onColorTapped(hct.color);
                  },
                  child: Container(color: hct.color),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
