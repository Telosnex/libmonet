// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quantize_service.dart';

// **************************************************************************
// Generator: WorkerGenerator 2.4.2
// **************************************************************************

/// WorkerService class for QuantizeService
class _$QuantizeServiceWorkerService extends QuantizeService
    implements WorkerService {
  _$QuantizeServiceWorkerService() : super();

  @override
  Map<int, CommandHandler> get operations => _operations;

  late final Map<int, CommandHandler> _operations =
      Map.unmodifiable(<int, CommandHandler>{
    _$quantizeId: ($) async =>
        (await quantize($.args[0].cast<int>(), $.args[1])).toJson(),
  });

  static const int _$quantizeId = 1;
}

/// Service initializer for QuantizeService
WorkerService $QuantizeServiceInitializer(WorkerRequest startRequest) =>
    _$QuantizeServiceWorkerService();

/// Operations map for QuantizeService
@Deprecated(
    'squadron_builder now supports "plain old Dart objects" as services. '
    'Services do not need to derive from WorkerService nor do they need to mix in '
    'with \$QuantizeServiceOperations anymore.')
mixin $QuantizeServiceOperations on WorkerService {
  @override
  // not needed anymore, generated for compatibility with previous versions of squadron_builder
  Map<int, CommandHandler> get operations => WorkerService.noOperations;
}

/// Worker for QuantizeService
class QuantizeServiceWorker extends Worker implements QuantizeService {
  QuantizeServiceWorker({PlatformWorkerHook? platformWorkerHook})
      : super($QuantizeServiceActivator,
            platformWorkerHook: platformWorkerHook);

  @override
  Future<QuantizerResult> quantize(List<int> argbs, int maxColors) =>
      send(_$QuantizeServiceWorkerService._$quantizeId,
              args: [argbs.cast<int>(), maxColors])
          .then((_) => QuantizerResult.fromJson(_));
}

/// Worker pool for QuantizeService
class QuantizeServiceWorkerPool extends WorkerPool<QuantizeServiceWorker>
    implements QuantizeService {
  QuantizeServiceWorkerPool(
      {ConcurrencySettings? concurrencySettings,
      PlatformWorkerHook? platformWorkerHook})
      : super(
            () => QuantizeServiceWorker(platformWorkerHook: platformWorkerHook),
            concurrencySettings: concurrencySettings);

  @override
  Future<QuantizerResult> quantize(List<int> argbs, int maxColors) =>
      execute((w) => w.quantize(argbs, maxColors));
}
