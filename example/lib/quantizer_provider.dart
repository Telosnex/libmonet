import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:libmonet/extract/extract.dart';
import 'package:libmonet/extract/quantizer_result.dart';

final quantizerResultProvider =
    FutureProvider.family<QuantizerResult, QuantizerRequest>((ref, request) {
  return Extract.quantize(request.imageProvider, request.colorCount);
});

@immutable
class QuantizerRequest {
  const QuantizerRequest({
    required this.imageProvider,
    required this.colorCount,
  });

  final ImageProvider imageProvider;
  final int colorCount;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is QuantizerRequest &&
            imageProvider == other.imageProvider &&
            colorCount == other.colorCount;
  }

  @override
  int get hashCode => Object.hash(imageProvider, colorCount);
}
