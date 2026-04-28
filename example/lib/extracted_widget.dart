import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/colorspaces/hct.dart';
import 'package:libmonet/core/hex_codes.dart';
import 'package:libmonet/extract/extract.dart';
import 'package:libmonet/extract/quantizer_result.dart';
import 'package:libmonet/extract/scorer.dart';
import 'package:libmonet/extract/scorer_triad.dart';
import 'package:monet_studio/quantizer_provider.dart';

final _imageByteFingerprintProvider =
    FutureProvider.family<String, ImageProvider>((ref, image) async {
  final key = await image.obtainKey(const ImageConfiguration());
  final data = await _readImageProviderBytes(key);
  return _bytesFingerprint(data);
});

final _scaledRgbaFingerprintProvider =
    FutureProvider.family<String, ImageProvider>((ref, image) async {
  final data = await imageProviderToScaledRgba(image, 96);
  return _bytesFingerprint(data.buffer.asUint8List());
});

Future<Uint8List> _readImageProviderBytes(Object key) {
  return switch (key) {
    FileImage(:final file) => file.readAsBytes(),
    NetworkImage(:final url) => NetworkAssetBundle(Uri.parse(url))
        .load(url)
        .then((data) => data.buffer.asUint8List()),
    _ => Future<Uint8List>.value(Uint8List(0)),
  };
}

class ExtractedWidget extends HookConsumerWidget {
  final ImageProvider image;
  final int quantizerColorCount;
  final Function() onTapped;
  final VoidCallback onRemove;

  const ExtractedWidget({
    super.key,
    required this.image,
    required this.quantizerColorCount,
    required this.onTapped,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantizerResult = ref.watch(quantizerResultProvider(QuantizerRequest(
      imageProvider: image,
      colorCount: quantizerColorCount,
    )));
    final byteFingerprint = ref.watch(_imageByteFingerprintProvider(image));
    final scaledRgbaFingerprint =
        ref.watch(_scaledRgbaFingerprintProvider(image));
    final imageDescription = _describeImageProvider(image);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTapped,
      child: Tooltip(
        message: 'Press to use this image for theme.\n\n'
            'Each model column computes hue sorting, filtering, and triad '
            'selection independently.',
        child: SizedBox(
          height: 148,
          child: Row(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image(
                      fit: BoxFit.cover,
                      image: image,
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton.filledTonal(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Remove wallpaper',
                        icon: const Icon(Icons.close),
                        onPressed: onRemove,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: switch (quantizerResult) {
                    AsyncData(:final value) => _ExtractionGrid(
                        imageDescription: imageDescription,
                        byteFingerprint: byteFingerprint.valueOrNull,
                        scaledRgbaFingerprint:
                            scaledRgbaFingerprint.valueOrNull,
                        quantizerResult: value,
                        quantizerColorCount: quantizerColorCount,
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

class _ExtractionGrid extends StatelessWidget {
  const _ExtractionGrid({
    required this.imageDescription,
    required this.byteFingerprint,
    required this.scaledRgbaFingerprint,
    required this.quantizerResult,
    required this.quantizerColorCount,
  });

  static const _labelWidth = 64.0;
  static const _headerHeight = 20.0;
  static const _rowHeight = 18.0;
  static const _gap = 2.0;

  final String imageDescription;
  final String? byteFingerprint;
  final String? scaledRgbaFingerprint;
  final QuantizerResult quantizerResult;
  final int quantizerColorCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: _labelWidth,
          child: _LabelColumn(),
        ),
        for (final model in ColorModel.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: _gap),
              child: _ModelExtractionColumn(
                quantizerResult: quantizerResult,
                imageDescription: imageDescription,
                byteFingerprint: byteFingerprint,
                scaledRgbaFingerprint: scaledRgbaFingerprint,
                model: model,
                quantizerColorCount: quantizerColorCount,
              ),
            ),
          ),
      ],
    );
  }
}

class _LabelColumn extends StatelessWidget {
  const _LabelColumn();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(height: _ExtractionGrid._headerHeight),
        _LabelCell('count', style: style),
        _LabelCell('hue', style: style),
        _LabelCell('filtered', style: style),
        _LabelCell('primary', style: style),
        _LabelCell('secondary', style: style),
        _LabelCell('tertiary', style: style),
      ],
    );
  }
}

class _LabelCell extends StatelessWidget {
  const _LabelCell(this.label, {required this.style});

  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _ExtractionGrid._rowHeight,
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    );
  }
}

class _ModelExtractionColumn extends StatelessWidget {
  const _ModelExtractionColumn({
    required this.quantizerResult,
    required this.imageDescription,
    required this.byteFingerprint,
    required this.scaledRgbaFingerprint,
    required this.model,
    required this.quantizerColorCount,
  });

  final QuantizerResult quantizerResult;
  final String imageDescription;
  final String? byteFingerprint;
  final String? scaledRgbaFingerprint;
  final ColorModel model;
  final int quantizerColorCount;

  @override
  Widget build(BuildContext context) {
    final argbToCount = quantizerResult.argbToCount;
    final quantizerFingerprint = _quantizerFingerprint(quantizerResult);
    final sortedByCount = _sortByCount(argbToCount);
    final totalCount = argbToCount.values.fold(0, (sum, count) => sum + count);
    final sortedByHue = sortedByCount.keys.toList()
      ..sort((a, b) => Hct.fromInt(a, model: model)
          .hue
          .compareTo(Hct.fromInt(b, model: model).hue));
    final scorer = Scorer(
      quantizerResult,
      colorModel: model,
    );
    final filteredByHue = scorer.hcts.toList()
      ..sort((a, b) => a.hue.compareTo(b.hue));
    final traceLog = <String>[];
    traceLog.add('image: $imageDescription');
    traceLog.add('bytes: ${byteFingerprint ?? 'loading'}');
    traceLog.add('scaledRgba: ${scaledRgbaFingerprint ?? 'loading'}');
    traceLog.add('quantizerColorCount: $quantizerColorCount');
    traceLog.add('quantizer: $quantizerFingerprint');
    final triad = ScorerTriad.threeColorsFromQuantizer(
      quantizerResult,
      colorModel: model,
      traceLog: traceLog,
    );

    return Column(
      children: [
        Tooltip(
          message: 'Tap to copy trace\n\n'
              '${model.label}\n\n${traceLog.join('\n')}',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _copyTrace(
              context,
              label: model.label,
              traceLog: traceLog,
            ),
            child: SizedBox(
              height: _ExtractionGrid._headerHeight,
              child: Center(
                child: Text(
                  model.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          ),
        ),
        _WeightedColorBand(
          colors: sortedByCount.keys.toList(),
          countForColor: (color) => sortedByCount[color] ?? 0,
          totalCount: totalCount,
          tooltipPrefix: '${model.label} count',
          model: model,
        ),
        _WeightedColorBand(
          colors: sortedByHue,
          countForColor: (color) => sortedByCount[color] ?? 0,
          totalCount: totalCount,
          tooltipPrefix: '${model.label} hue',
          model: model,
        ),
        _WeightedHctBand(
          colors: filteredByHue,
          countForHct: (hct) => scorer.hctToCount[hct] ?? 0,
          totalCount: totalCount,
          tooltipPrefix: '${model.label} filtered',
          model: model,
        ),
        _TriadCell(
          role: 'primary',
          model: model,
          hct: triad.isNotEmpty ? triad[0] : null,
          traceLog: traceLog,
        ),
        _TriadCell(
          role: 'secondary',
          model: model,
          hct: triad.length > 1 ? triad[1] : null,
          traceLog: traceLog,
        ),
        _TriadCell(
          role: 'tertiary',
          model: model,
          hct: triad.length > 2 ? triad[2] : null,
          traceLog: traceLog,
        ),
      ],
    );
  }

  static Map<int, int> _sortByCount(Map<int, int> colorToCount) {
    final sortedEntries = colorToCount.entries.toList()
      ..sort((e1, e2) => e2.value.compareTo(e1.value));
    return Map<int, int>.fromEntries(sortedEntries);
  }
}

class _WeightedColorBand extends StatelessWidget {
  const _WeightedColorBand({
    required this.colors,
    required this.countForColor,
    required this.totalCount,
    required this.tooltipPrefix,
    required this.model,
  });

  final List<int> colors;
  final int Function(int color) countForColor;
  final int totalCount;
  final String tooltipPrefix;
  final ColorModel model;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _ExtractionGrid._rowHeight,
      child: Row(
        children: [
          for (final color in colors)
            Expanded(
              flex: _flex(countForColor(color), totalCount),
              child: _ColorSegment(
                color: Color(color),
                hct: Hct.fromInt(color, model: model),
                model: model,
                tooltipPrefix: tooltipPrefix,
              ),
            ),
        ],
      ),
    );
  }
}

class _WeightedHctBand extends StatelessWidget {
  const _WeightedHctBand({
    required this.colors,
    required this.countForHct,
    required this.totalCount,
    required this.tooltipPrefix,
    required this.model,
  });

  final List<Hct> colors;
  final int Function(Hct color) countForHct;
  final int totalCount;
  final String tooltipPrefix;
  final ColorModel model;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _ExtractionGrid._rowHeight,
      child: Row(
        children: [
          for (final hct in colors)
            Expanded(
              flex: _flex(countForHct(hct), totalCount),
              child: _ColorSegment(
                color: hct.color,
                hct: hct,
                model: model,
                tooltipPrefix: tooltipPrefix,
              ),
            ),
        ],
      ),
    );
  }
}

class _TriadCell extends StatelessWidget {
  const _TriadCell({
    required this.role,
    required this.model,
    required this.hct,
    required this.traceLog,
  });

  final String role;
  final ColorModel model;
  final Hct? hct;
  final List<String> traceLog;

  @override
  Widget build(BuildContext context) {
    final hct = this.hct;
    if (hct == null) {
      return const SizedBox(height: _ExtractionGrid._rowHeight);
    }

    return SizedBox(
      height: _ExtractionGrid._rowHeight,
      width: double.infinity,
      child: _ColorSegment(
        color: hct.color,
        hct: hct,
        model: model,
        tooltipPrefix: '${model.label} $role\n\n'
            '${traceLog.join('\n')}',
        onTap: () => _copyTrace(
          context,
          label: '${model.label} $role',
          traceLog: traceLog,
        ),
      ),
    );
  }
}

class _ColorSegment extends StatelessWidget {
  const _ColorSegment({
    required this.color,
    required this.hct,
    required this.model,
    required this.tooltipPrefix,
    this.onTap,
  });

  final Color color;
  final Hct hct;
  final ColorModel model;
  final String tooltipPrefix;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message:
          '$tooltipPrefix\n${hexFromColor(color)}\n${_hclTooltip(hct, model)}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.expand(
          child: ColoredBox(color: color),
        ),
      ),
    );
  }
}

void _copyTrace(
  BuildContext context, {
  required String label,
  required List<String> traceLog,
}) {
  final text = '$label\n${traceLog.join('\n')}';
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Copied $label trace')),
  );
}

String _hclTooltip(Hct hct, ColorModel model) {
  return 'H ${hct.hue.round()} · C ${_displayChroma(hct, model)} · '
      'L ${hct.tone.round()}';
}

int _displayChroma(Hct hct, ColorModel model) {
  return switch (model) {
    ColorModel.oklch => (hct.chroma * 100).round(),
    _ => hct.chroma.round(),
  };
}

int _flex(int count, int totalCount) {
  if (totalCount <= 0 || count <= 0) {
    return 1;
  }
  return (count / totalCount * 1000).round().clamp(1, 1000);
}

String _describeImageProvider(ImageProvider image) {
  return switch (image) {
    FileImage(:final file, :final scale) =>
      'FileImage(path=${file.path}, scale=$scale)',
    NetworkImage(:final url, :final scale) =>
      'NetworkImage(url=$url, scale=$scale)',
    _ => image.toString(),
  };
}

String _quantizerFingerprint(QuantizerResult result) {
  final entries = result.argbToCount.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final total = entries.fold<int>(0, (sum, entry) => sum + entry.value);
  final top = entries.take(8).map((entry) {
    return '${hexFromArgb(entry.key)}:${entry.value}';
  }).join(',');
  return 'colors=${entries.length} total=$total top=$top';
}

String _bytesFingerprint(Uint8List bytes) {
  return 'length=${bytes.length} fnv32=${_fnv1a32(bytes)}';
}

String _fnv1a32(Uint8List bytes) {
  const mask = 0xffffffff;
  var hash = 0x811c9dc5;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * 0x01000193) & mask;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
