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
      expect(File(imagePath).existsSync(), isTrue,
          reason: 'Image file not found');
      final imageProvider = FileImage(File(imagePath));
      final quantize = await Extract.quantize(imageProvider, 16);
      expect(quantize.argbToCount, {
        0xffff0000: 9216,
      });
    });

    test('green', () async {
      String imagePath = 'test/data/green.png';
      expect(File(imagePath).existsSync(), isTrue,
          reason: 'Image file not found');
      final imageProvider = FileImage(File(imagePath));
      final quantize = await Extract.quantize(imageProvider, 16);

      expect(quantize.argbToCount, {
        0xff00ff00: 9216,
      });
    });

    test('blue', () async {
      String imagePath = 'test/data/blue.png';
      expect(File(imagePath).existsSync(), isTrue,
          reason: 'Image file not found');
      final imageProvider = FileImage(File(imagePath));
      final quantize = await Extract.quantize(imageProvider, 16);

      expect(quantize.argbToCount, {
        0xff0000ff: 9216,
      });
    });
  });

  group('1 image', () {
    test('fonnx', () async {
      String imagePath = 'test/data/fonnx.png';
      expect(File(imagePath).existsSync(), isTrue,
          reason: 'Image file not found');
      final imageProvider = FileImage(File(imagePath));
      final quantize = await Extract.quantize(imageProvider, 16, debug: false);
      expect(quantize.argbToCount, {
        4282192191: 1352,
        4285186771: 131,
        4289405542: 73,
        4292969898: 35,
        4283186523: 97,
        4294505448: 416,
        4294324353: 338,
        4287993771: 53,
        4284484676: 91,
        4282387525: 752,
        4287854987: 56,
        4284925910: 440,
        4293477510: 58,
        4284048514: 25,
        4292525514: 40,
        4294638057: 595
      });
    });
  });
}
