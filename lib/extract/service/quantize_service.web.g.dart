// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// Generator: WorkerGenerator 7.1.0 (Squadron 7.1.0)
// **************************************************************************

import 'package:squadron/squadron.dart';

import 'quantize_service.dart';

void main() {
  /// Web entry point for QuantizeService
  run($QuantizeServiceInitializer);
}

EntryPoint $getQuantizeServiceActivator(SquadronPlatformType platform) {
  if (platform.isJs) {
    return Squadron.uri('lib/extract/service/quantize_service.web.g.dart.js');
  } else if (platform.isWasm) {
    return Squadron.uri('lib/extract/service/quantize_service.web.g.dart.wasm');
  } else {
    throw UnsupportedError('${platform.label} not supported.');
  }
}
