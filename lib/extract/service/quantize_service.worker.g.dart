// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quantize_service.dart';

// **************************************************************************
// Generator: WorkerGenerator 7.1.0 (Squadron 7.1.0)
// **************************************************************************

/// Command ids used in operations map
const int _$quantizeId = 1;

/// WorkerService operations for QuantizeService
extension on QuantizeService {
  OperationsMap _$getOperations() => OperationsMap({
        _$quantizeId: ($req) async {
          final QuantizerResult $res;
          try {
            final $dsr = _$Deser(contextAware: false);
            $res = await quantize($dsr.$1($req.args[0]), $dsr.$0($req.args[1]));
          } finally {}
          try {
            final $sr = _$Ser(contextAware: false);
            return $sr.$0($res);
          } finally {}
        },
      });
}

/// Invoker for QuantizeService, implements the public interface to invoke the
/// remote service.
mixin _$QuantizeService$Invoker on Invoker implements QuantizeService {
  @override
  Future<QuantizerResult> quantize(List<int> argbs, int maxColors) async {
    final dynamic $res = await send(_$quantizeId, args: [argbs, maxColors]);
    try {
      final $dsr = _$Deser(contextAware: false);
      return $dsr.$2($res);
    } finally {}
  }
}

/// Facade for QuantizeService, implements other details of the service unrelated to
/// invoking the remote service.
mixin _$QuantizeService$Facade implements QuantizeService {}

/// WorkerService class for QuantizeService
class _$QuantizeService$WorkerService extends QuantizeService
    implements WorkerService {
  _$QuantizeService$WorkerService() : super();

  @override
  OperationsMap get operations => _$getOperations();
}

/// Service initializer for QuantizeService
WorkerService $QuantizeServiceInitializer(WorkerRequest $req) =>
    _$QuantizeService$WorkerService();

/// Worker for QuantizeService
base class QuantizeServiceWorker extends Worker
    with _$QuantizeService$Invoker, _$QuantizeService$Facade
    implements QuantizeService {
  QuantizeServiceWorker(
      {PlatformThreadHook? threadHook, ExceptionManager? exceptionManager})
      : super($QuantizeServiceActivator(Squadron.platformType),
            threadHook: threadHook, exceptionManager: exceptionManager);

  QuantizeServiceWorker.vm(
      {PlatformThreadHook? threadHook, ExceptionManager? exceptionManager})
      : super($QuantizeServiceActivator(SquadronPlatformType.vm),
            threadHook: threadHook, exceptionManager: exceptionManager);

  QuantizeServiceWorker.js(
      {PlatformThreadHook? threadHook, ExceptionManager? exceptionManager})
      : super($QuantizeServiceActivator(SquadronPlatformType.js),
            threadHook: threadHook, exceptionManager: exceptionManager);

  QuantizeServiceWorker.wasm(
      {PlatformThreadHook? threadHook, ExceptionManager? exceptionManager})
      : super($QuantizeServiceActivator(SquadronPlatformType.wasm),
            threadHook: threadHook, exceptionManager: exceptionManager);

  @override
  List? getStartArgs() => null;
}

/// Worker pool for QuantizeService
base class QuantizeServiceWorkerPool extends WorkerPool<QuantizeServiceWorker>
    with _$QuantizeService$Facade
    implements QuantizeService {
  QuantizeServiceWorkerPool(
      {PlatformThreadHook? threadHook,
      ExceptionManager? exceptionManager,
      ConcurrencySettings? concurrencySettings})
      : super(
            (ExceptionManager exceptionManager) => QuantizeServiceWorker(
                threadHook: threadHook, exceptionManager: exceptionManager),
            concurrencySettings: concurrencySettings,
            exceptionManager: exceptionManager);

  QuantizeServiceWorkerPool.vm(
      {PlatformThreadHook? threadHook,
      ExceptionManager? exceptionManager,
      ConcurrencySettings? concurrencySettings})
      : super(
            (ExceptionManager exceptionManager) => QuantizeServiceWorker.vm(
                threadHook: threadHook, exceptionManager: exceptionManager),
            concurrencySettings: concurrencySettings,
            exceptionManager: exceptionManager);

  QuantizeServiceWorkerPool.js(
      {PlatformThreadHook? threadHook,
      ExceptionManager? exceptionManager,
      ConcurrencySettings? concurrencySettings})
      : super(
            (ExceptionManager exceptionManager) => QuantizeServiceWorker.js(
                threadHook: threadHook, exceptionManager: exceptionManager),
            concurrencySettings: concurrencySettings,
            exceptionManager: exceptionManager);

  QuantizeServiceWorkerPool.wasm(
      {PlatformThreadHook? threadHook,
      ExceptionManager? exceptionManager,
      ConcurrencySettings? concurrencySettings})
      : super(
            (ExceptionManager exceptionManager) => QuantizeServiceWorker.wasm(
                threadHook: threadHook, exceptionManager: exceptionManager),
            concurrencySettings: concurrencySettings,
            exceptionManager: exceptionManager);

  @override
  Future<QuantizerResult> quantize(List<int> argbs, int maxColors) =>
      execute((w) => w.quantize(argbs, maxColors));
}

final class _$Deser extends MarshalingContext {
  _$Deser({super.contextAware});
  late final $0 = value<int>();
  late final $1 = list<int>($0);
  late final $2 = (($) => QuantizerResult.fromJson($));
}

final class _$Ser extends MarshalingContext {
  _$Ser({super.contextAware});
  late final $0 = (($) => ($ as QuantizerResult).toJson());
}
