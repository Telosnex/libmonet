import 'package:example/quantizer_provider.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ExtractedWidget extends HookConsumerWidget {
  final ImageProvider image;

  const ExtractedWidget({
    super.key,
    required this.image,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantizerResult = ref.watch(quantizerResultProvider(image));
    return SizedBox(
      height: 160,
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
              AsyncData(:final value) =>
                _ColorToCountRow(colorToCount: value.argbToCount),
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
  final Map<int, int> colorToCount;
  final Map<int, int> sortedColorToCount;
  final int totalCount;

  _ColorToCountRow({required this.colorToCount})
      : sortedColorToCount = _sortColorToCount(colorToCount),
        totalCount = colorToCount.values.reduce((a, b) => a + b);

  static Map<int, int> _sortColorToCount(Map<int, int> colorToCount) {
    var sortedEntries = colorToCount.entries.toList()
      ..sort((e1, e2) => e2.value.compareTo(e1.value));
    return Map<int, int>.fromEntries(sortedEntries);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}
