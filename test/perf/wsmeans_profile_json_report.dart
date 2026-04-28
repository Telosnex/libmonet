// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    print(
      'Usage: dart run test/perf/wsmeans_profile_json_report.dart <cpu-samples.json>',
    );
    exitCode = 64;
    return;
  }

  for (final path in args) {
    final json =
        jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
    final functions = (json['functions'] as List).cast<Map<String, Object?>>();
    final samples = (json['samples'] as List).cast<Map<String, Object?>>();
    final names = <int, String>{};
    for (var i = 0; i < functions.length; i++) {
      final entry = functions[i];
      final function = entry['function'] as Map<String, Object?>?;
      final name = function?['name'] as String? ?? '<unknown>';
      final url = entry['resolvedUrl'] as String? ?? '';
      names[i] = url.isEmpty ? name : '$name (${_basename(url)})';
    }

    print('\n============================================================');
    print(path);
    print('samples=${samples.length} period=${json['samplePeriod']}us');
    print('============================================================');

    final leafCounts = <String, int>{};
    final callerCounts = <String, int>{};
    final pairCounts = <String, int>{};
    final quantizeStackCounts = <String, int>{};
    var quantizeLeafSamples = 0;
    var quantizeStackSamples = 0;

    for (final sample in samples) {
      final stack = (sample['stack'] as List).cast<int>();
      if (stack.isEmpty) continue;
      final leaf = names[stack.first] ?? '<unknown>';
      leafCounts.update(leaf, (count) => count + 1, ifAbsent: () => 1);
      if (stack.length > 1) {
        final caller = names[stack[1]] ?? '<unknown>';
        callerCounts.update(caller, (count) => count + 1, ifAbsent: () => 1);
        pairCounts.update(
          '$leaf <= $caller',
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }

      final quantizeFrames = stack
          .map((id) => names[id] ?? '<unknown>')
          .where(
            (name) =>
                name.contains('QuantizerWsmeans') ||
                name.contains('quantizer_wsmeans.dart'),
          )
          .toList();
      if (quantizeFrames.isNotEmpty) {
        quantizeStackSamples++;
        quantizeStackCounts.update(
          quantizeFrames.join(' <= '),
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      if (leaf.contains('QuantizerWsmeans')) {
        quantizeLeafSamples++;
      }
    }

    print('QuantizerWsmeans leaf samples: $quantizeLeafSamples');
    print('QuantizerWsmeans stack samples: $quantizeStackSamples');
    _printTop('Leaf functions', leafCounts, samples.length, limit: 30);
    _printTop('Leaf <= caller pairs', pairCounts, samples.length, limit: 40);
    _printTop(
      'QuantizerWsmeans stack signatures',
      quantizeStackCounts,
      quantizeStackSamples,
      limit: 20,
    );
  }
}

void _printTop(
  String title,
  Map<String, int> counts,
  int total, {
  required int limit,
}) {
  print('\n$title');
  final entries = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final entry in entries.take(limit)) {
    final percent = total == 0 ? 0.0 : entry.value / total * 100;
    print(
      '${percent.toStringAsFixed(1).padLeft(5)}% '
      '${entry.value.toString().padLeft(6)}  ${entry.key}',
    );
  }
}

String _basename(String path) {
  final slash = path.lastIndexOf('/');
  return slash == -1 ? path : path.substring(slash + 1);
}
