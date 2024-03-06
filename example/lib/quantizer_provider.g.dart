// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quantizer_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$quantizerResultHash() => r'28fdc7a6d0bba59cd2456e24f8ee7a0573fb309f';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// This will create a provider named `activityProvider`
/// which will cache the result of this function.
///
/// Copied from [quantizerResult].
@ProviderFor(quantizerResult)
const quantizerResultProvider = QuantizerResultFamily();

/// This will create a provider named `activityProvider`
/// which will cache the result of this function.
///
/// Copied from [quantizerResult].
class QuantizerResultFamily extends Family<AsyncValue<QuantizerResult>> {
  /// This will create a provider named `activityProvider`
  /// which will cache the result of this function.
  ///
  /// Copied from [quantizerResult].
  const QuantizerResultFamily();

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'quantizerResultProvider';

  /// This will create a provider named `activityProvider`
  /// which will cache the result of this function.
  ///
  /// Copied from [quantizerResult].
  QuantizerResultProvider call(
    ImageProvider imageProvider,
  ) {
    return QuantizerResultProvider(
      imageProvider,
    );
  }

  @visibleForOverriding
  @override
  QuantizerResultProvider getProviderOverride(
    covariant QuantizerResultProvider provider,
  ) {
    return call(
      provider.imageProvider,
    );
  }

  /// Enables overriding the behavior of this provider, no matter the parameters.
  Override overrideWith(
      FutureOr<QuantizerResult> Function(QuantizerResultRef ref) create) {
    return _$QuantizerResultFamilyOverride(this, create);
  }
}

class _$QuantizerResultFamilyOverride
    implements FamilyOverride<AsyncValue<QuantizerResult>> {
  _$QuantizerResultFamilyOverride(this.overriddenFamily, this.create);

  final FutureOr<QuantizerResult> Function(QuantizerResultRef ref) create;

  @override
  final QuantizerResultFamily overriddenFamily;

  @override
  QuantizerResultProvider getProviderOverride(
    covariant QuantizerResultProvider provider,
  ) {
    return provider._copyWith(create);
  }
}

/// This will create a provider named `activityProvider`
/// which will cache the result of this function.
///
/// Copied from [quantizerResult].
class QuantizerResultProvider
    extends AutoDisposeFutureProvider<QuantizerResult> {
  /// This will create a provider named `activityProvider`
  /// which will cache the result of this function.
  ///
  /// Copied from [quantizerResult].
  QuantizerResultProvider(
    ImageProvider imageProvider,
  ) : this._internal(
          (ref) => quantizerResult(
            ref as QuantizerResultRef,
            imageProvider,
          ),
          from: quantizerResultProvider,
          name: r'quantizerResultProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$quantizerResultHash,
          dependencies: QuantizerResultFamily._dependencies,
          allTransitiveDependencies:
              QuantizerResultFamily._allTransitiveDependencies,
          imageProvider: imageProvider,
        );

  QuantizerResultProvider._internal(
    super.create, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.imageProvider,
  }) : super.internal();

  final ImageProvider imageProvider;

  @override
  Override overrideWith(
    FutureOr<QuantizerResult> Function(QuantizerResultRef ref) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: QuantizerResultProvider._internal(
        (ref) => create(ref as QuantizerResultRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        imageProvider: imageProvider,
      ),
    );
  }

  @override
  (ImageProvider,) get argument {
    return (imageProvider,);
  }

  @override
  AutoDisposeFutureProviderElement<QuantizerResult> createElement() {
    return _QuantizerResultProviderElement(this);
  }

  QuantizerResultProvider _copyWith(
    FutureOr<QuantizerResult> Function(QuantizerResultRef ref) create,
  ) {
    return QuantizerResultProvider._internal(
      (ref) => create(ref as QuantizerResultRef),
      name: name,
      dependencies: dependencies,
      allTransitiveDependencies: allTransitiveDependencies,
      debugGetCreateSourceHash: debugGetCreateSourceHash,
      from: from,
      imageProvider: imageProvider,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is QuantizerResultProvider &&
        other.imageProvider == imageProvider;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, imageProvider.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin QuantizerResultRef on AutoDisposeFutureProviderRef<QuantizerResult> {
  /// The parameter `imageProvider` of this provider.
  ImageProvider get imageProvider;
}

class _QuantizerResultProviderElement
    extends AutoDisposeFutureProviderElement<QuantizerResult>
    with QuantizerResultRef {
  _QuantizerResultProviderElement(super.provider);

  @override
  ImageProvider get imageProvider =>
      (origin as QuantizerResultProvider).imageProvider;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, inference_failure_on_uninitialized_variable, inference_failure_on_function_return_type, inference_failure_on_untyped_parameter, deprecated_member_use_from_same_package
