import 'dart:async';

import 'package:libmonet/extract/quantizer_celebi.dart';
import 'package:libmonet/extract/quantizer_result.dart';
import 'package:squadron/squadron_annotations.dart';
import 'package:squadron/squadron.dart';

import 'quantize_service.activator.g.dart';

part 'quantize_service.worker.g.dart';

@SquadronService()
class QuantizeService {
  @SquadronMethod()
  Future<QuantizerResult> quantize(List<int> argbs, int maxColors) async =>
      _quantize(argbs, maxColors);

  static Future<QuantizerResult> _quantize(
    Iterable<int> argbs,
    int maxColors,
  ) async {
    return QuantizerCelebi().quantize(
      argbs,
      maxColors,
    );
  }
}
