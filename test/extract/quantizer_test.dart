import 'dart:io';

import 'package:flutter/material.dart' show FileImage;
import 'package:libmonet/extract/extract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Flutter needed to paint downscaled image
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1 color', () {
    test('red', () async {
      String imagePath = 'test/data/red.png';
      expect(
        File(imagePath).existsSync(),
        isTrue,
        reason: 'Image file not found',
      );
      final imageProvider = FileImage(File(imagePath));
      final quantize = await Extract.quantize(imageProvider, 16);
      expect(quantize.argbToCount, {0xffff0000: 9216});
    });

    test('green', () async {
      String imagePath = 'test/data/green.png';
      expect(
        File(imagePath).existsSync(),
        isTrue,
        reason: 'Image file not found',
      );
      final imageProvider = FileImage(File(imagePath));
      final quantize = await Extract.quantize(imageProvider, 16);

      expect(quantize.argbToCount, {0xff00ff00: 9216});
    });

    test('blue', () async {
      String imagePath = 'test/data/blue.png';
      expect(
        File(imagePath).existsSync(),
        isTrue,
        reason: 'Image file not found',
      );
      final imageProvider = FileImage(File(imagePath));
      final quantize = await Extract.quantize(imageProvider, 16);

      expect(quantize.argbToCount, {0xff0000ff: 9216});
    });
  });

  group('1 image', () {
    test('fonnx', () async {
      String imagePath = 'test/data/fonnx.png';
      expect(
        File(imagePath).existsSync(),
        isTrue,
        reason: 'Image file not found',
      );
      final imageProvider = FileImage(File(imagePath));
      final quantize = await Extract.quantize(imageProvider, 16, debug: false);
      expect(quantize.argbToCount, {
        4281799994: 228,
        4285836231: 68,
        4290390894: 82,
        4292636310: 40,
        4283053137: 70,
        4294438125: 174,
        4284794838: 504,
        4294324354: 355,
        4285008451: 93,
        4282322498: 1842,
        4290636261: 29,
        4293444304: 81,
        4283328393: 36,
        4286999424: 48,
        4294703848: 795,
        4290092973: 63,
      });
    });
  });
}
