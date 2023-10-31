// Necessary for code-generation to work
import 'package:flutter/material.dart';
import 'package:libmonet/extract/extract.dart';
import 'package:libmonet/extract/quantizer_result.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'quantizer_provider.g.dart';

/// This will create a provider named `activityProvider`
/// which will cache the result of this function.
@riverpod
Future<QuantizerResult> quantizerResult(
    QuantizerResultRef ref, ImageProvider imageProvider) async {
  final result = await Extract.quantize(imageProvider, 32);
  return result;
}
