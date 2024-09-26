// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quantize_service.dart';

// **************************************************************************
// Generator: WorkerGenerator 6.0.2
// **************************************************************************

/// WorkerService class for QuantizeService
class _$QuantizeServiceWorkerService extends QuantizeService
    implements WorkerService {
  _$QuantizeServiceWorkerService() : super();

  @override
  late final Map<int, CommandHandler> operations =
      Map.unmodifiable(<int, CommandHandler>{
    _$quantizeId: ($) =>
        quantize(_$X.$1($.args[0]), _$X.$0($.args[1])).then(_$X.$2),
  });

  static const int _$quantizeId = 1;
}

/// Service initializer for QuantizeService
WorkerService $QuantizeServiceInitializer(WorkerRequest $$) =>
    _$QuantizeServiceWorkerService();

/// Worker for QuantizeService
base class QuantizeServiceWorker extends Worker implements QuantizeService {
  QuantizeServiceWorker(
      {PlatformThreadHook? threadHook, ExceptionManager? exceptionManager})
      : super($QuantizeServiceActivator(Squadron.platformType));

  QuantizeServiceWorker.vm(
      {PlatformThreadHook? threadHook, ExceptionManager? exceptionManager})
      : super($QuantizeServiceActivator(SquadronPlatformType.vm));

  QuantizeServiceWorker.js(
      {PlatformThreadHook? threadHook, ExceptionManager? exceptionManager})
      : super($QuantizeServiceActivator(SquadronPlatformType.js),
            threadHook: threadHook, exceptionManager: exceptionManager);

  QuantizeServiceWorker.wasm(
      {PlatformThreadHook? threadHook, ExceptionManager? exceptionManager})
      : super($QuantizeServiceActivator(SquadronPlatformType.wasm));

  @override
  Future<QuantizerResult> quantize(List<int> argbs, int maxColors) =>
      send(_$QuantizeServiceWorkerService._$quantizeId,
              args: [_$X.$3(argbs), maxColors],
              inspectRequest: true,
              inspectResponse: true)
          .then(_$X.$4);
}

/// Worker pool for QuantizeService
base class QuantizeServiceWorkerPool extends WorkerPool<QuantizeServiceWorker>
    implements QuantizeService {
  QuantizeServiceWorkerPool(
      {ConcurrencySettings? concurrencySettings,
      PlatformThreadHook? threadHook,
      ExceptionManager? exceptionManager})
      : super(
          (ExceptionManager exceptionManager) => QuantizeServiceWorker(
              threadHook: threadHook, exceptionManager: exceptionManager),
          concurrencySettings: concurrencySettings,
        );

  QuantizeServiceWorkerPool.vm(
      {ConcurrencySettings? concurrencySettings,
      PlatformThreadHook? threadHook,
      ExceptionManager? exceptionManager})
      : super(
          (ExceptionManager exceptionManager) => QuantizeServiceWorker.vm(
              threadHook: threadHook, exceptionManager: exceptionManager),
          concurrencySettings: concurrencySettings,
        );

  QuantizeServiceWorkerPool.js(
      {ConcurrencySettings? concurrencySettings,
      PlatformThreadHook? threadHook,
      ExceptionManager? exceptionManager})
      : super(
          (ExceptionManager exceptionManager) => QuantizeServiceWorker.js(
              threadHook: threadHook, exceptionManager: exceptionManager),
          concurrencySettings: concurrencySettings,
        );

  QuantizeServiceWorkerPool.wasm(
      {ConcurrencySettings? concurrencySettings,
      PlatformThreadHook? threadHook,
      ExceptionManager? exceptionManager})
      : super(
          (ExceptionManager exceptionManager) => QuantizeServiceWorker.wasm(
              threadHook: threadHook, exceptionManager: exceptionManager),
          concurrencySettings: concurrencySettings,
        );

  @override
  Future<QuantizerResult> quantize(List<int> argbs, int maxColors) =>
      execute((w) => w.quantize(argbs, maxColors));
}

class _$X {
  static final $0 = Squadron.converter.value<int>();
  static final $1 = Squadron.converter.list<int>(_$X.$0);
  static final $2 = (($) => ($ as QuantizerResult).toJson());
  static final $3 = Squadron.converter.list<int>();
  static final $4 = (($) => QuantizerResult.fromJson($));
}
