// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quantize_service.dart';

// **************************************************************************
// Generator: WorkerGenerator 6.0.0
// **************************************************************************

/// WorkerService class for QuantizeService
class _$QuantizeServiceWorkerService extends QuantizeService
    implements WorkerService {
  _$QuantizeServiceWorkerService() : super();

  @override
  Map<int, CommandHandler> get operations => _operations;

  late final Map<int, CommandHandler> _operations =
      Map.unmodifiable(<int, CommandHandler>{
    _$quantizeId: ($in) async {
      final $out =
          await quantize($in.args[0].cast<int>(), Cast.toInt($in.args[1]));
      return $out.toJson();
    },
  });

  static const int _$quantizeId = 1;
}

/// Service initializer for QuantizeService
WorkerService $QuantizeServiceInitializer(WorkerRequest $in) =>
    _$QuantizeServiceWorkerService();

/// Worker for QuantizeService
class QuantizeServiceWorker extends Worker implements QuantizeService {
  QuantizeServiceWorker({PlatformThreadHook? threadHook})
      : super($QuantizeServiceActivator, threadHook: threadHook);

  @override
  Future<QuantizerResult> quantize(List<int> argbs, int maxColors) =>
      send(_$QuantizeServiceWorkerService._$quantizeId,
          args: [argbs, maxColors]).then(($x) => QuantizerResult.fromJson($x));
}

/// Worker pool for QuantizeService
class QuantizeServiceWorkerPool extends WorkerPool<QuantizeServiceWorker>
    implements QuantizeService {
  QuantizeServiceWorkerPool(
      {ConcurrencySettings? concurrencySettings,
      PlatformThreadHook? threadHook})
      : super(() => QuantizeServiceWorker(threadHook: threadHook),
            concurrencySettings: concurrencySettings);

  @override
  Future<QuantizerResult> quantize(List<int> argbs, int maxColors) =>
      execute((w) => w.quantize(argbs, maxColors));
}
