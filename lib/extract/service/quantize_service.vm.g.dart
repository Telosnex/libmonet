// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// Generator: WorkerGenerator 7.1.0 (Squadron 7.1.0)
// **************************************************************************

import 'package:squadron/squadron.dart';

import 'quantize_service.dart';

void _start$QuantizeService(WorkerRequest command) {
  /// VM entry point for QuantizeService
  run($QuantizeServiceInitializer, command);
}

EntryPoint $getQuantizeServiceActivator(SquadronPlatformType platform) {
  if (platform.isVm) {
    return _start$QuantizeService;
  } else {
    throw UnsupportedError('${platform.label} not supported.');
  }
}
