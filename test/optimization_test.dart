import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/hct.dart';
import 'package:material_color_utilities/material_color_utilities.dart' as mcu;

void main() {
  test('test optimization', () {
    const iterations = 1000000;
    final random = Random.secure();

    final randomHues =
        List.generate(iterations, (index) => random.nextDouble() * 360.0);
    final randomChromas =
        List.generate(iterations, (index) => random.nextDouble() * 100.0);
    final randomTones =
        List.generate(iterations, (index) => random.nextDouble() * 100.0);

    final mcuStopwatch = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      mcu.Hct.from(randomHues[i], randomChromas[i], randomTones[i]);
    }
    mcuStopwatch.stop();

    final monetStopwatch = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      Hct.from(randomHues[i], randomChromas[i], randomTones[i]);
    }
    monetStopwatch.stop();

    print('mcu: ${mcuStopwatch.elapsedMilliseconds}ms');
    print('monet: ${monetStopwatch.elapsedMilliseconds}ms');
  });
}
