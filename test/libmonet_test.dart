import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/hct.dart';
import 'package:material_color_utilities/material_color_utilities.dart' as mcu;

void main() {
  test('speed', () {
    const iterations = 1000000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      Hct.fromInt(0xff0fd0ab);
    }
    sw.stop();
    print('Hct.fromInt: ${sw.elapsedMilliseconds}ms');

    sw.reset();
    sw.start();
    for (var i = 0; i < iterations; i++) {
      mcu.Hct.fromInt(0xff0fd0ab);
    }
    sw.stop();
    print('mcu.Hct.fromInt: ${sw.elapsedMilliseconds}ms');


    sw.reset();
    sw.start();
    for (var i = 0; i < iterations; i++) {
      Hct.from(252.0, 96.0, 94.0);
    }
    sw.stop();
    print('Hct.from: ${sw.elapsedMilliseconds}ms');

    sw.reset();
    sw.start();
    for (var i = 0; i < iterations; i++) {
      mcu.Hct.from(252.0, 96.0, 94.0);
    }
    sw.stop();
    print('mcu.Hct.from: ${sw.elapsedMilliseconds}ms');
  });
}
