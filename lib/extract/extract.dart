import 'package:flutter/material.dart';
import 'package:libmonet/argb_srgb_xyz_lab.dart';
import 'package:libmonet/debug_print.dart';
import 'package:libmonet/extract/quantizer.dart';
import 'package:libmonet/extract/quantizer_celebi.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

class Extract {
  static Future<QuantizerResult> quantize(
      ImageProvider imageProvider, int count,
      {bool debug = false}) async {
    final sw = Stopwatch()..start();
    final byteData = await _imageProviderScaledRgba(imageProvider, 96);
    monetDebug(
        debug, () => '[Extract] downscaled in ${sw.elapsedMilliseconds}ms');
    if (byteData.lengthInBytes == 0) {
      return Future<QuantizerResult>.value(const QuantizerResult({}));
    }

    sw.reset();
    final bytes = byteData.buffer.asUint32List();
    monetDebug(debug, () => '[Extract] Uint32s in ${sw.elapsedMilliseconds}ms');

    sw.reset();
    final argbBytes = bytes.map(_rgbaToArgb).toList();
    monetDebug(debug, () => '[Extract] ARGB in ${sw.elapsedMilliseconds}ms');

    sw.reset();
    final quantizerResult = await QuantizerCelebi().quantize(
        argbBytes.where((element) => alphaFromArgb(element) == 255), count);
    monetDebug(
        debug, () => '[Extract] Quantized in ${sw.elapsedMilliseconds}ms');

    return Future<QuantizerResult>.value(quantizerResult);
  }
}

int _rgbaToArgb(int rgba) {
  int r = (rgba >> 0) & 0xFF;
  int g = (rgba >> 8) & 0xFF;
  int b = (rgba >> 16) & 0xFF;
  int a = (rgba >> 24) & 0xFF;

  return (a << 24) | (r << 16) | (g << 8) | b;
}

class ImageToBytesResponse {
  final ByteData byteData;
  final ImageInfo imageInfo;

  ImageToBytesResponse(this.byteData, this.imageInfo);
}

Future<ByteData> _imageProviderScaledRgba(
    ImageProvider imageProvider, double maxDimension) {
  final stream = imageProvider
      .resolve(ImageConfiguration(size: Size(maxDimension, maxDimension)));
  late ImageStreamListener listener;
  final completer = Completer<ByteData>();
  listener = ImageStreamListener((frame, sync) async {
    try {
      stream.removeListener(listener);
      final image = frame.image;
      final width = image.width;
      final height = image.height;
      var paintWidth = width.toDouble();
      var paintHeight = height.toDouble();
      final rescale = width > maxDimension || height > maxDimension;
      if (rescale) {
        paintWidth =
            (width > height) ? maxDimension : (maxDimension / height) * width;
        paintHeight =
            (height > width) ? maxDimension : (maxDimension / width) * height;
      }
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      paintImage(
          canvas: canvas,
          rect: Rect.fromLTRB(0, 0, paintWidth, paintHeight),
          image: image,
          filterQuality: FilterQuality.none);
      final picture = pictureRecorder.endRecording();
      final scaledImage =
          await picture.toImage(paintWidth.toInt(), paintHeight.toInt());
      final byteData = await scaledImage.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba);
      completer.complete(byteData);
    } catch (e, stack) {
      debugPrint('error scaling image: $e, $stack');
      completer.completeError('Failed to scale image. Error receieved: $e');
    }
  });
  stream.addListener(listener);
  return completer.future;
}
