import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/contrast/apca_tone_bounds_data.dart';

import '../../tool/apca_tone_bounds.dart' as tool;

void main() {
  test(
    'production tables match the current constants and fresh derivation',
    () {
      // Recompute only the 401 production tones, not the exhaustive RGB sweep.
      tool.verifySourceConstants();
      tool.verifyProductionTables();
    },
  );

  List<tool.Bounds> storedWithDrift(double drift) => [
    for (var i = 0; i < apcaMinimumAtQuarterTone.length; i++)
      tool.Bounds(
        tool.Witness(apcaMinimumAtQuarterTone[i] + drift, const []),
        tool.Witness(apcaMaximumAtQuarterTone[i] + drift, const []),
      ),
  ];

  test('numerical tolerance does not require byte-identical fresh output', () {
    final drifted = storedWithDrift(5e-15);
    final dartSource = File(tool.dartTablePath).readAsStringSync();
    final typescriptSource = File(tool.typescriptTablePath).readAsStringSync();
    expect(tool.dartProductionTable(drifted), isNot(dartSource));
    expect(tool.typescriptProductionTable(drifted), isNot(typescriptSource));
    // A platform's slightly different solve is acceptable, while the checked-in
    // sources must remain synchronized with each other, not with that solve.
    tool.verifyProductionTableValues(drifted);
    tool.verifyProductionTableSources(dartSource, typescriptSource);
  });

  test(
    'numerical verification rejects material drift and nonfinite results',
    () {
      for (final drift in [1e-12, double.nan, double.infinity]) {
        expect(
          () => tool.verifyProductionTableValues(storedWithDrift(drift)),
          throwsStateError,
        );
      }
    },
  );

  test('source synchronization still rejects divergent TypeScript or Dart', () {
    final stored = storedWithDrift(0);
    final drifted = storedWithDrift(5e-15);
    expect(
      () => tool.verifyProductionTableSources(
        tool.dartProductionTable(stored),
        tool.typescriptProductionTable(drifted),
      ),
      throwsStateError,
    );
    expect(
      () => tool.verifyProductionTableSources(
        tool.dartProductionTable(drifted),
        tool.typescriptProductionTable(stored),
      ),
      throwsStateError,
    );
  });
}
