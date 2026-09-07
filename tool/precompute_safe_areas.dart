// Run from any directory with `dart /path/to/libmonet/tool/precompute_safe_areas.dart`.
// The package uses dart:ui, so this launcher runs the worker in Flutter's
// headless test engine rather than trying to load geometry into the Dart VM.
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  var output = 'tool/data/material_shape_safe_areas.json';
  String? dartOutput;
  var ratios = <double>[0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8];
  var clearance = 0.01;
  var tolerance = 1e-5;
  try {
    for (final arg in args) {
      if (arg == '--help') {
        stdout.writeln(
          'Usage: dart tool/precompute_safe_areas.dart '
          '[--output=path.json] [--dart-output=path.dart] [--ratios=0.5,1,2,4,8] '
          '[--clearance=0.01] [--tolerance=0.00001]\n'
          'Output paths are relative to the invoking directory. Requires '
          'flutter on PATH and resolved pub dependencies. Static endpoints '
          'only; temporary overflow during morphing is allowed.',
        );
        return;
      } else if (arg.startsWith('--dart-output=')) {
        dartOutput = arg.substring('--dart-output='.length);
        if (dartOutput.isEmpty) {
          throw const FormatException('Empty Dart output path');
        }
      } else if (arg.startsWith('--output=')) {
        output = arg.substring('--output='.length);
        if (output.isEmpty) throw const FormatException('Empty output path');
      } else if (arg.startsWith('--ratios=')) {
        ratios = arg
            .substring('--ratios='.length)
            .split(',')
            .map(double.parse)
            .toList();
        if (ratios.any((v) => !v.isFinite || v <= 0)) {
          throw const FormatException('Ratios must be finite and positive');
        }
      } else if (arg.startsWith('--clearance=')) {
        clearance = double.parse(arg.substring('--clearance='.length));
        if (!clearance.isFinite || clearance < 0 || clearance >= 0.5) {
          throw const FormatException('Clearance must be in [0, 0.5)');
        }
      } else if (arg.startsWith('--tolerance=')) {
        tolerance = double.parse(arg.substring('--tolerance='.length));
        if (!tolerance.isFinite || tolerance <= 0 || tolerance >= 0.1) {
          throw const FormatException('Tolerance must be in (0, 0.1)');
        }
      } else {
        throw FormatException('Unknown argument: $arg');
      }
    }
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
    return;
  }
  ratios = ratios.toSet().toList()..sort();
  final root = File.fromUri(Platform.script).parent.parent;
  final process = await Process.start(
    'flutter',
    ['test', '--no-pub', 'tool/src/precompute_safe_areas_worker.dart'],
    workingDirectory: root.path,
    environment: {
      'MONET_SAFE_AREAS_OPTIONS': jsonEncode({
        'output': File(output).absolute.path,
        'ratios': ratios,
        'dartOutput': dartOutput == null
            ? null
            : File(dartOutput).absolute.path,
        'clearance': clearance,
        'tolerance': tolerance,
      }),
    },
    mode: ProcessStartMode.inheritStdio,
  );
  exitCode = await process.exitCode;
}
