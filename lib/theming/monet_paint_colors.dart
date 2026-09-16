import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:libmonet/theming/interpolation_style.dart';
import 'package:libmonet/theming/monet_theme_data.dart';
import 'package:libmonet/theming/palette.dart';
import 'package:libmonet/theming/palette_recipe.dart';
import 'package:libmonet/theming/paint/palette_motion.dart';
import 'package:libmonet/theming/paint/progress_motion.dart';
import 'package:libmonet/theming/paint/theme_frame.dart';

export 'package:libmonet/theming/paint/palette_motion.dart' show PaletteRole;

/// Stable recipe keys for built-ins; paint and inherited readers share colors.
enum MonetPalette {
  primary,
  secondary,
  tertiary;

  Palette resolve(MonetThemeData data) => switch (this) {
    primary => data.primary,
    secondary => data.secondary,
    tertiary => data.tertiary,
  };
}

/// One coordinator/ticker per scope. Palette getters discover demand; no role
/// declaration is required. Bindings own paint subscriptions and release their
/// observed roles on disposal. Optional role sets prewarm outputs before paint.
///
/// In inherited mode, reads of [value] discover scope-owned roles (at most 123).
/// Their intermediate RGB conversions are lazy. In final-only mode use a
/// binding: listen directly to it for role-local invalidation. Ticks do not
/// calculate colors. A potentially changing color may round to the same RGB;
/// conservative invalidation avoids solving unused states merely to find out.
/// Listening to the coordinator itself reports only logical theme changes and
/// completion. It is NOT a paint subscription; use a [MonetPaletteBinding].
/// See `docs/design/paint-bindings.md` for first-read and lifecycle semantics.
class MonetPaintColors extends ChangeNotifier with Diagnosticable {
  MonetPaintColors(
    MonetThemeData value, {
    this._requestFrame,
    this._clock,
    this._duration = Duration.zero,
    this._style = InterpolationStyle.cartesian,
    this._animateThemeData = false,
    this._animateUnboundRoles = true,
    this.stats,
  }) : _value = value,
       _target = value,
       _anchor = value,
       _beginTone = value.backgroundTone,
       _beginContrast = value.contrast,
       _beginScale = value.scale {
    for (final key in MonetPalette.values) {
      _builtIns[key] = _PaletteSlot(
        key,
        key.resolve,
        _motion(key.resolve(value)),
      );
    }
    _publishFrame();
  }
  final PaintMotionStats? stats;
  MonetThemeData _value, _target, _anchor;
  final VoidCallback? _requestFrame;
  final double Function()? _clock;
  double _beginTone, _beginContrast, _beginScale;
  // Semantic scalars share one progress value; also gives unread theme changes
  // a Material-anchor/onEnd lifecycle without evaluating any color getters.
  final ProgressMotion _progress = ProgressMotion();
  final Map<MonetPalette, _PaletteSlot> _builtIns = {};
  final List<_PaletteSlot> _derived = [];
  final Map<Object, Set<_PaletteSlot>> _byKey = {};
  final Map<Object, (MonetThemeData, PaletteEndpoint)> _endpoints = {};
  final Set<MonetPaletteBinding> _pendingBindings = {};
  Iterable<_PaletteSlot> get _slots sync* {
    yield* _builtIns.values;
    yield* _derived;
  }

  double _time = 0;
  Duration _duration;
  InterpolationStyle _style;
  bool _animateThemeData;
  bool _animateUnboundRoles;
  int _generation = 0;
  bool _disposed = false;
  double _themeProgress = 1;
  bool _hasDerivedForks = false;

  MonetThemeData get value => _value;
  MonetThemeData get target => _target.target;
  PaletteMotion _motion(Palette palette) => PaletteMotion(
    palette,
    model: _target.colorModel,
    style: _style,
    stats: stats,
  );

  /// Includes local recipe transitions, which keep the ticker alive without
  /// delaying the semantic theme's completion ([value].isAnimating).
  bool get isAnimating =>
      _isThemeAnimating || _derived.any((s) => s.motion.isMoving);
  bool get _isThemeAnimating =>
      _themeProgress < 1 || _builtIns.values.any((s) => s.motion.isMoving);

  /// Explicit assignment is an exact snap (also supports manually driven buses).
  set value(MonetThemeData next) =>
      retarget(next, time: _time, duration: Duration.zero, style: _style);

  MonetPaletteBinding bindThemePalette(
    MonetPalette palette, {
    Set<PaletteRole>? roles,
  }) => bind(palette, palette.resolve, roles: roles);

  MonetPaletteBinding bindRecipe(
    PaletteRecipe recipe, {
    Set<PaletteRole>? roles,
  }) => bind(recipe, recipe.resolve, roles: roles);

  PaletteEndpoint _endpointFor(
    Object key,
    Palette Function(MonetThemeData) resolve,
  ) {
    final cached = _endpoints[key];
    if (cached != null && cached.$1 == target) return cached.$2;
    final palette = resolve(target);
    final endpoint = cached != null && cached.$2.palette == palette
        ? cached.$2
        : PaletteEndpoint(palette, stats);
    _endpoints[key] = (target, endpoint);
    return endpoint;
  }

  void _addDerived(_PaletteSlot slot) {
    _derived.add(slot);
    (_byKey[slot.key] ??= {}).add(slot);
  }

  void _unindex(_PaletteSlot slot) {
    final group = _byKey[slot.key]!;
    group.remove(slot);
    if (group.isEmpty) {
      _byKey.remove(slot.key);
      _endpoints.remove(slot.key);
    }
  }

  void _invalidate(_PaletteSlot slot, Set<PaletteRole> changed) {
    if (changed.isEmpty) return;
    for (final binding in slot.bindings) {
      if (changed.any(
        (r) =>
            binding._prewarmedRoles.contains(r) ||
            binding._observedRoles.contains(r),
      )) {
        _pendingBindings.add(binding);
      }
    }
  }

  /// Equal keys share the union of retained roles, with per-role lifetimes.
  /// Updating a binding to an existing derived key preserves its distinct
  /// visible transition until both histories settle, then shares their palette.
  /// New bindings join the first retained history for that key.
  ///
  /// Keys must have stable equality/hashCode and include every recipe parameter.
  /// Equal keys must resolve equivalent palettes for any supplied endpoint;
  /// resolvers must not capture changing state absent from the key. Built-in
  /// [MonetPalette] keys are reserved for their corresponding palette resolver.
  /// [roles] optionally prewarms outputs; additional getters always work and
  /// retain their roles automatically. Observations survive skipped paints.
  /// Binding/updates never notify synchronously: lifecycle can hold a tree lock.
  MonetPaletteBinding bind(
    Object key,
    Palette Function(MonetThemeData) resolve, {
    Set<PaletteRole>? roles,
  }) {
    assert(!_disposed);
    final selected = Set<PaletteRole>.unmodifiable(roles ?? const {});
    var slot = key is MonetPalette ? _builtIns[key] : _byKey[key]?.first;
    if (slot == null) {
      slot = _PaletteSlot(
        key,
        resolve,
        PaletteMotion.fromEndpoint(
          _endpointFor(key, resolve),
          model: _target.colorModel,
          style: _style,
        ),
      );
      _addDerived(slot);
    }
    final binding = MonetPaletteBinding._(this, slot, selected);
    slot.retain(binding);
    _syncRoles(slot);
    return binding;
  }

  void _syncRoles(_PaletteSlot slot) {
    slot.motion.setRoles({
      ...slot.roles.keys,
      if (_animateUnboundRoles) ...slot.implicitRoles,
    });
  }

  void _observe(
    MonetPaletteBinding binding,
    PaletteRole role,
    int generation,
    int endpointGeneration,
  ) {
    if (_disposed ||
        binding._disposed ||
        binding._generation != generation ||
        endpointGeneration != _generation ||
        binding._observedRoles.contains(role)) {
      return;
    }
    final alreadyRetained = binding._roles.contains(role);
    binding._observedRoles.add(role);
    if (!alreadyRetained) {
      final slot = binding._slot;
      slot.roles[role] = (slot.roles[role] ?? 0) + 1;
      _syncRoles(slot);
    }
    // First use starts at the endpoint if no shared role history exists. No tree-lock
    // notification, ticker restart, or history replay can happen from a getter.
  }

  void _observeInherited(MonetPalette key, PaletteRole role, int generation) {
    if (_disposed || !_animateUnboundRoles || generation != _generation) return;
    final slot = _builtIns[key]!;
    if (slot.implicitRoles.add(role)) _syncRoles(slot);
  }

  void _updateBinding(
    MonetPaletteBinding binding,
    Object key,
    Palette Function(MonetThemeData) resolve,
    Set<PaletteRole> roles,
  ) {
    if (_disposed) return;
    final keyChanged = binding._slot.key != key;
    final rolesChanged = !setEquals(binding._prewarmedRoles, roles);
    if (!keyChanged && !rolesChanged) return;
    _sampleTracks(_clock?.call() ?? _time);
    // Sampling can coalesce the source history and move this binding.
    var slot = binding._slot;
    final previousRoles = binding._roles;
    if (keyChanged) {
      if (key is MonetPalette) {
        // Built-in consumers join their common palette, never restart it.
        _release(binding);
        slot = _builtIns[key]!;
      } else {
        _hasDerivedForks |= _byKey.containsKey(key);
        if (slot.references > 1 || slot.key is MonetPalette) {
          // Preserve the departing consumer's displayed colors;
          // joining another moving history would cause a visible jump.
          final motion = PaletteMotion.copy(slot.motion, roles: previousRoles);
          _release(binding);
          slot = _PaletteSlot(key, resolve, motion);
          _addDerived(slot);
        } else {
          slot.release(binding);
          _unindex(slot);
          (_byKey[key] ??= {}).add(slot);
        }
        slot.key = key;
        slot.resolve = resolve;
      }
      binding._slot = slot;
    } else {
      slot.release(binding);
    }
    binding._prewarmedRoles = Set.unmodifiable(roles);
    binding._generation++;
    binding._view = null;
    slot.retain(binding);
    if (keyChanged && key is! MonetPalette) {
      // Newly visible roles have no history. Resolve them from the NEW recipe
      // only, after retargeting, rather than creating motion from the old one.
      slot.motion.setRoles(previousRoles.intersection(binding._roles));
      final endpoint = _endpointFor(key, resolve);
      slot.motion.retarget(
        endpoint.palette,
        _time,
        paintMotionOmega(_duration),
        model: _target.colorModel,
        style: _style,
        snap: _duration == Duration.zero,
        endpoint: endpoint,
      );
    }
    _syncRoles(slot);
    if (binding._roles.isNotEmpty) {
      _pendingBindings.add(binding);
    }
    _coalesceSettledRecipes();
    if (isAnimating || _pendingBindings.isNotEmpty) _requestFrame?.call();
    // Widget lifecycle can run under the tree lock: no synchronous notify.
  }

  void _release(MonetPaletteBinding binding) {
    if (_disposed) return;
    final slot = binding._slot;
    _pendingBindings.remove(binding);
    slot.release(binding);
    if (slot.references == 0 && slot.key is! MonetPalette) {
      _derived.remove(slot);
      _unindex(slot);
    } else {
      _syncRoles(slot);
    }
  }

  /// Rebase from visible colors and restart shared progress from rest.
  /// [time] is finite animation time in seconds, in the same monotonic epoch as
  /// [sample] and the injected `clock` used by binding updates. Repeated times
  /// are allowed. Duration zero snaps; other durations are spring pacing hints.
  /// Unlike binding updates, this can synchronously notify bus listeners.
  void retarget(
    MonetThemeData next, {
    required double time,
    required Duration duration,
    InterpolationStyle style = InterpolationStyle.cartesian,
    bool animateThemeData = false,
    bool? animateUnboundRoles,
  }) {
    _sampleTracks(time);
    if (!_isThemeAnimating) _anchor = _target;
    final previous = _target;
    final basisChanged =
        _style != style || _target.colorModel != next.colorModel;
    final targetChanged = next != _target;
    final endpointChanged = next.target != _target.target;
    final durationChanged = _duration != duration;
    final t = _themeProgress;
    final tone = lerpDouble(_beginTone, previous.backgroundTone, t)!;
    final contrast = lerpDouble(_beginContrast, previous.contrast, t)!;
    final scale = lerpDouble(_beginScale, previous.scale, t)!;
    _animateUnboundRoles = animateUnboundRoles ?? _animateUnboundRoles;
    final snap = duration == Duration.zero;
    // Scope-owned demand is bounded by 3 * 41 roles, not scroll history.
    // Disabling inherited motion releases it; bound roles keep their histories.
    for (final slot in _builtIns.values) {
      if (!_animateUnboundRoles) slot.implicitRoles.clear();
      _syncRoles(slot);
    }
    if (targetChanged || basisChanged || durationChanged) _generation++;
    _target = next;
    _duration = duration;
    _style = style;
    _animateThemeData = animateThemeData;
    final omega = paintMotionOmega(duration);
    if (targetChanged || basisChanged || durationChanged) {
      for (final slot in _slots) {
        final builtin = slot.key is MonetPalette;
        if (!builtin && !endpointChanged && !basisChanged && !durationChanged) {
          continue;
        }
        final endpoint = builtin ? null : _endpointFor(slot.key, slot.resolve);
        final changed = slot.motion.retarget(
          endpoint?.palette ?? slot.resolve(next),
          time,
          omega,
          model: next.colorModel,
          style: style,
          snap: snap,
          endpoint: endpoint,
        );
        _invalidate(slot, changed);
      }
      final visualTargetChanged =
          next.backgroundTone != previous.backgroundTone ||
          next.contrast != previous.contrast ||
          next.scale != previous.scale ||
          next.primary != previous.primary ||
          next.secondary != previous.secondary ||
          next.tertiary != previous.tertiary;
      if (snap) {
        _progress.snap();
        _themeProgress = 1;
      } else if (visualTargetChanged ||
          ((basisChanged || durationChanged) && _themeProgress < 1)) {
        _beginTone = tone;
        _beginContrast = contrast;
        _beginScale = scale;
        _progress.restart(time, omega);
        _themeProgress = 0;
      }
    }
    _coalesceSettledRecipes();
    _publishFrame(forceSemantic: previous != next);
    if (isAnimating) _requestFrame?.call();
  }

  /// Samples at finite, nondecreasing animation [time] in seconds and notifies
  /// only bindings whose used roles may have changed. Coordinator listeners
  /// receive semantic completion, not paint ticks or custom recipe changes.
  /// Does not calculate RGB or resolve endpoints. Repeated timestamps are inert.
  void sample(double time) {
    _sampleTracks(time);
    _publishFrame();
  }

  void _sampleTracks(double time) {
    assert(time.isFinite && time >= _time);
    _time = time;
    _themeProgress = _progress.sample(time);
    for (final slot in _slots) {
      _invalidate(slot, slot.motion.sample(time));
    }
    _coalesceSettledRecipes();
  }

  void _coalesceSettledRecipes() {
    // Ordinary shared-key paints pay no allocation/scan here. Forks exist only
    // when a binding changes recipe while preserving a distinct motion history.
    if (!_hasDerivedForks) return;
    _hasDerivedForks = false;
    final byKey = <Object, _PaletteSlot>{};
    _derived.removeWhere((slot) {
      final shared = byKey[slot.key];
      if (shared == null) {
        byKey[slot.key] = slot;
        return false;
      }
      if (shared.motion.isMoving || slot.motion.isMoving) {
        _hasDerivedForks = true;
        return false;
      }
      // Merge already-resolved colors, including disjoint roles. Calling
      // setRoles here would solve newly shared outputs inside a paint tick.
      shared.motion.absorbSettledRoles(slot.motion);
      for (final binding in slot.bindings) {
        binding._slot = shared;
        shared.retain(binding);
      }
      _unindex(slot);
      return true;
    });
  }

  void _publishFrame({bool forceSemantic = false}) {
    final t = _themeProgress;
    final moving = _isThemeAnimating;
    if (!moving) {
      _progress.snap();
      _anchor = _target;
    }
    final weakOwner = WeakReference(this);
    final generation = _generation;
    Palette frame(MonetPalette key) {
      final source = _builtIns[key]!.motion.frame;
      return _animateUnboundRoles
          ? _inheritedView(source, weakOwner, key, generation)
          : source;
    }

    final next = MonetThemeFrame(
      target: target,
      materialAnchor: _anchor,
      animateThemeData: _animateThemeData,
      isAnimating: moving,
      primary: frame(MonetPalette.primary),
      secondary: frame(MonetPalette.secondary),
      tertiary: frame(MonetPalette.tertiary),
      backgroundTone: lerpDouble(_beginTone, _target.backgroundTone, t)!,
      contrast: lerpDouble(_beginContrast, _target.contrast, t)!,
      scale: lerpDouble(_beginScale, _target.scale, t)!,
    );
    // Do NOT capture/compare full palettes here: that would solve every unused
    // role just to decide whether a retained paint output changed.
    final changed =
        forceSemantic ||
        _value.brightness != next.brightness ||
        (_value.isAnimating && !moving);
    _value = next;
    final pending = _pendingBindings.toList();
    _pendingBindings.clear();
    for (final binding in pending) {
      if (_disposed) return;
      binding._publish();
    }
    if (_disposed) return;
    if (changed) notifyListeners();
  }

  @visibleForTesting
  int get retainedPaletteCount => _derived.length;
  @visibleForTesting
  int get retainedRecipeCount => _endpoints.length;
  @visibleForTesting
  int get retainedRoleCount =>
      _slots.fold(0, (n, s) => n + s.motion.trackCount);

  @override
  void dispose() {
    _disposed = true;
    // Detach callbacks even if a consumer outlives the owner. Saved values remain
    // immutable and readable; neither can resurrect a subscription.
    for (final slot in _slots) {
      for (final binding in slot.bindings.toList()) {
        binding.dispose();
      }
    }
    _pendingBindings.clear();
    _byKey.clear();
    _endpoints.clear();
    _builtIns.clear();
    _derived.clear();
    super.dispose();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<MonetThemeData>('value', value));
  }
}

class _PaletteSlot {
  _PaletteSlot(this.key, this.resolve, this.motion);
  Object key;
  Palette Function(MonetThemeData) resolve;
  final PaletteMotion motion;
  final Map<PaletteRole, int> roles = {};
  final Set<PaletteRole> implicitRoles = {};
  final Set<MonetPaletteBinding> bindings = {};
  int get references => bindings.length;
  void retain(MonetPaletteBinding binding) {
    assert(!bindings.contains(binding));
    bindings.add(binding);
    for (final role in binding._roles) {
      roles[role] = (roles[role] ?? 0) + 1;
    }
  }

  void release(MonetPaletteBinding binding) {
    assert(bindings.contains(binding));
    bindings.remove(binding);
    for (final role in binding._roles) {
      final count = roles[role]! - 1;
      if (count == 0) {
        roles.remove(role);
      } else {
        roles[role] = count;
      }
    }
  }
}

/// A mounted consumer's palette. Getter reads automatically retain outputs;
/// first use may resolve an endpoint. Subsequent ticks do not resolve endpoints.
/// Listen to this binding for local repaint invalidation rather than to the bus.
/// A notification means a retained color may change; RGB is calculated on read.
/// Dispose when detached or switching buses. Saved values are immutable frames,
/// not live handles; read [value] again for each new paint.
class MonetPaletteBinding extends ChangeNotifier {
  MonetPaletteBinding._(this._owner, this._slot, this._prewarmedRoles);
  final MonetPaintColors _owner;
  _PaletteSlot _slot;
  Set<PaletteRole> _prewarmedRoles;
  final Set<PaletteRole> _observedRoles = {};
  Set<PaletteRole> get _roles => {..._prewarmedRoles, ..._observedRoles};
  int _generation = 0;
  int _viewGeneration = -1;
  ObservedPalette? _view;
  bool _disposed = false;

  void _publish() {
    if (_disposed || !hasListeners) return;
    _owner.stats?.bindingNotifications++;
    notifyListeners();
  }

  /// Prepare a control's state family before first paint/interaction. Getter
  /// discovery still works; this explicitly owns demand until update/disposal.
  void prewarm(Set<PaletteRole> roles) =>
      update(_slot.key, _slot.resolve, roles: {..._prewarmedRoles, ...roles});

  void updateRecipe(PaletteRecipe recipe, {Set<PaletteRole>? roles}) =>
      update(recipe, recipe.resolve, roles: roles);
  Palette get value {
    final source = _slot.motion.frame;
    if (!identical(_view?.source, source) ||
        _viewGeneration != _owner._generation) {
      _viewGeneration = _owner._generation;
      _view = _bindingView(
        source,
        WeakReference(this),
        _generation,
        _viewGeneration,
      );
    }
    return _view!;
  }

  /// Update the recipe/roles in widget lifecycle, not from paint. For derived
  /// keys, existing roles keep their displayed history until settling; newly
  /// observed roles start at the new endpoint. Built-in keys join their common
  /// palette immediately. A changed resolver with an unchanged key is ignored.
  /// Does not notify synchronously; a changed output requests a later sample.
  void update(
    Object key,
    Palette Function(MonetThemeData) resolve, {
    Set<PaletteRole>? roles,
  }) {
    assert(!_disposed);
    _owner._updateBinding(this, key, resolve, roles ?? _prewarmedRoles);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _owner._release(this);
    super.dispose();
  }
}

// Create observer closures outside instance methods so their closure contexts
// cannot accidentally retain `this` alongside a weak reference. Cached Material
// themes and explicitly saved palette frames can outlive an entire widget scope.
ObservedPalette _inheritedView(
  Palette source,
  WeakReference<MonetPaintColors> owner,
  MonetPalette key,
  int generation,
) => ObservedPalette(
  source,
  (role) => owner.target?._observeInherited(key, role, generation),
);

ObservedPalette _bindingView(
  Palette source,
  WeakReference<MonetPaletteBinding> owner,
  int generation,
  int endpointGeneration,
) => ObservedPalette(source, (role) {
  final binding = owner.target;
  if (binding != null) {
    binding._owner._observe(binding, role, generation, endpointGeneration);
  }
});

/// Stable inherited scope for [MonetPaintColors].
///
/// The inherited widget intentionally exposes only the controller identity. It
/// notifies dependents when that identity changes, but not when
/// [MonetPaintColors.value] changes. Animated color ticks are delivered by
/// [MonetPaletteBinding] directly to interested paint consumers. Listening to
/// [MonetPaintColors] itself reports only logical theme changes and completion.
///
/// Use [maybeOf] when a widget can fall back to regular [MonetTheme] behavior
/// outside an [AnimatedMonetTheme]. Use [of] when paint-bus support is required
/// by the widget's contract.
class MonetPaintColorsScope extends InheritedWidget {
  const MonetPaintColorsScope({
    super.key,
    required this.colors,
    required super.child,
  });

  final MonetPaintColors colors;

  static MonetPaintColors of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<MonetPaintColorsScope>();
    assert(inherited != null, 'No MonetPaintColorsScope found in context.');
    return inherited!.colors;
  }

  static MonetPaintColors? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<MonetPaintColorsScope>()
        ?.colors;
  }

  @override
  bool updateShouldNotify(covariant MonetPaintColorsScope oldWidget) =>
      !identical(colors, oldWidget.colors);
}
