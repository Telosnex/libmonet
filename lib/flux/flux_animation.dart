// Port of Fuchsia Mondrian's flux.dart
// Original: topaz/shell/mondrian_story_shell/lib/anim/flux.dart
// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// Copied into libmonet from telosnex's `features/flux` port so
// `AnimatedMonetTheme` can chase a moving target with velocity handoff
// instead of resetting a fixed-duration `AnimationController` on every
// retarget.

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:libmonet/flux/sim.dart';

/// An [Animation<T>] that carries an intrinsic velocity.
///
/// This is the core abstraction that makes jerk-free animation transitions
/// possible. When you transition from one animation to another (drag → spring,
/// spring → spring), the new animation picks up from the old one's velocity.
abstract class FluxAnimation<T> extends Animation<T> {
  const FluxAnimation();

  /// Wrap an existing [Animation] as a [FluxAnimation] with given velocity.
  factory FluxAnimation.fromAnimation(Animation<T> animation, T velocity) =>
      animation is FluxAnimation<T>
      ? animation
      : _FluxAnimationWrapper(animation, velocity);

  /// The instantaneous change in value, in natural units per second.
  T get velocity;
}

/// A function that creates a [FluxAnimation] from an initial value and velocity.
///
/// Used by [ManualAnimation] to create the "coast" animation when the user
/// lifts their finger — the spring picks up from the gesture's velocity.
typedef FluxAnimationInit<T> = FluxAnimation<T> Function(T value, T velocity);

class _FluxAnimationWrapper<T> extends FluxAnimation<T> {
  const _FluxAnimationWrapper(this.animation, this._velocity);

  final Animation<T> animation;
  final T _velocity;

  @override
  AnimationStatus get status => animation.status;

  @override
  T get value => animation.value;

  @override
  T get velocity => _velocity;

  @override
  void addListener(VoidCallback listener) => animation.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      animation.removeListener(listener);

  @override
  void addStatusListener(AnimationStatusListener listener) =>
      animation.addStatusListener(listener);

  @override
  void removeStatusListener(AnimationStatusListener listener) =>
      animation.removeStatusListener(listener);
}

/// A [FluxAnimation] driven by a [Sim].
///
/// This is the workhorse: it takes a generic simulation (spring, friction,
/// gravity, anything) and drives it with a [Ticker]. Unlike Flutter's
/// [AnimationController], the simulation owns the value — there's no
/// artificial 0.0–1.0 range.
class SimAnimationController<T> extends FluxAnimation<T>
    with
        AnimationLocalStatusListenersMixin,
        AnimationLocalListenersMixin,
        AnimationEagerListenerMixin {
  SimAnimationController({required TickerProvider vsync, required this.sim})
    : _value = sim.value(0.0),
      _velocity = sim.velocity(0.0),
      _elapsed = Duration.zero,
      _elapsedOffset = Duration.zero {
    _ticker = vsync.createTicker(_tick);
  }

  final Sim<T> sim;
  late final Ticker _ticker;

  @override
  AnimationStatus get status => _ticker.isActive
      ? .forward
      : sim.isDone(_elapsedInSeconds)
      ? .completed
      : .dismissed;

  @override
  T get value => _value;
  T _value;

  @override
  T get velocity => _velocity;
  T _velocity;

  /// The elapsed duration for this simulation. Setting stops the animation.
  Duration get elapsed => _elapsed + _elapsedOffset;
  Duration _elapsed;
  Duration _elapsedOffset;
  set elapsed(Duration duration) {
    stop();
    // ignore: match-getter-setter-field-names
    _elapsedOffset = duration;
    _tick(.zero);
  }

  double get _elapsedInSeconds =>
      (_elapsed + _elapsedOffset).inMicroseconds.toDouble() /
      Duration.microsecondsPerSecond;

  /// Start the animation.
  TickerFuture start() {
    final future = _ticker.start()..whenCompleteOrCancel(_sendStatusUpdate);
    _sendStatusUpdate();
    return future;
  }

  /// Stop the animation, optionally marking it as cancelled.
  void stop({bool canceled = false}) {
    _ticker.stop(canceled: canceled);
    _elapsedOffset = elapsed;
    _elapsed = .zero;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    _elapsed = elapsed;
    final elapsedSeconds = _elapsedInSeconds;
    _value = sim.value(elapsedSeconds);
    _velocity = sim.velocity(elapsedSeconds);
    if (sim.isDone(elapsedSeconds)) {
      _ticker.stop();
    }
    notifyListeners();
  }

  AnimationStatus? _lastSentStatus;
  void _sendStatusUpdate() {
    if (status != _lastSentStatus) {
      _lastSentStatus = status;
      notifyStatusListeners(status);
    }
  }
}

/// A manually controllable [FluxAnimation].
///
/// This is the drag-to-spring bridge. During a drag gesture:
/// 1. Call [update] on each frame with the current position and velocity
/// 2. Call [done] when the gesture ends
/// 3. The [builder] creates a spring animation from the final value/velocity
///
/// The spring picks up seamlessly from the gesture — no jerk.
class ManualAnimation<T> extends FluxAnimation<T>
    with
        AnimationLocalStatusListenersMixin,
        AnimationLocalListenersMixin,
        AnimationLazyListenerMixin {
  /// Constructs with initial value and velocity.
  ManualAnimation({
    required this._value,
    required this._velocity,
    this._builder,
  }) : _delegate = null,
       _done = false;

  /// Constructs with value and velocity provided by delegate to start.
  ManualAnimation.withDelegate({required FluxAnimation<T> delegate})
    : _delegate = delegate,
      _builder = null,
      _done = true,
      _value = delegate.value,
      _velocity = delegate.velocity;

  final FluxAnimationInit<T>? _builder;
  FluxAnimation<T>? _delegate;

  @override
  T get value => _done ? (_delegate?.value ?? _value) : _value;
  T _value;

  @override
  T get velocity => _done ? (_delegate?.velocity ?? _velocity) : _velocity;
  T _velocity;

  bool _done;

  @override
  AnimationStatus get status =>
      _done ? (_delegate?.status ?? AnimationStatus.completed) : .forward;

  /// Manually change the value and velocity of this animation.
  ///
  /// Call this from your gesture handler on every drag update.
  void update({required T value, required T velocity}) {
    final oldStatus = status;
    if (_done) {
      _stopDelegating();
      _done = false;
    }
    _value = value;
    _velocity = velocity;
    if (oldStatus != status) {
      notifyStatusListeners(status);
    }
    notifyListeners();
  }

  /// Signal the end of manually changing this animation.
  ///
  /// This creates a new animation via [builder] that picks up from the
  /// current value and velocity. If no builder was provided, the animation
  /// immediately completes.
  void done() {
    if (_done) return;
    final oldStatus = status;
    _done = true;
    _startDelegating();
    if (status != oldStatus) {
      notifyStatusListeners(status);
    }
    notifyListeners();
  }

  @override
  void didStartListening() {
    _startDelegating();
  }

  @override
  void didStopListening() {
    _stopDelegating();
  }

  void _startDelegating() {
    if (_done) {
      if (_builder != null) {
        _delegate = _builder(_value, _velocity);
      }
      _delegate?.addListener(notifyListeners);
      _delegate?.addStatusListener(notifyStatusListeners);
    }
  }

  void _stopDelegating() {
    if (_done) {
      _delegate?.removeListener(notifyListeners);
      _delegate?.removeStatusListener(notifyStatusListeners);
    }
  }
}

/// Animation that chases a moving target using a [Simulate] function.
///
/// When the target changes, a new simulation is created that picks up from
/// the current value and velocity. Used by Mondrian for layout animations:
/// when the system resizes cards, each card's target rect changes and the
/// spring chases it without resetting.
class MovingTargetAnimation<T> extends FluxAnimation<T>
    with
        AnimationLocalStatusListenersMixin,
        AnimationLocalListenersMixin,
        AnimationLazyListenerMixin {
  MovingTargetAnimation({
    required this._vsync,
    required Animation<T> target,
    required this.simulate,
    required this._value,
    required T velocity,
  }) : target = FluxAnimation.fromAnimation(target, velocity),
       _velocity = velocity;

  /// The simulation generator for moving to target.
  final Simulate<T> simulate;

  /// The moving target.
  final FluxAnimation<T> target;

  final TickerProvider _vsync;
  SimAnimationController<T>? _animation;
  T _value;
  T _velocity;
  int? _lastUpdateCallbackId;

  @override
  AnimationStatus get status =>
      _animation?.status ??
      (simulate(value, target.value, velocity).isDone(0.0)
          ? AnimationStatus.completed
          : AnimationStatus.forward);

  @override
  T get value => _animation?.value ?? _value;

  @override
  T get velocity => _animation?.velocity ?? _velocity;

  void _scheduleUpdate() {
    if (_lastUpdateCallbackId != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(
        _lastUpdateCallbackId!,
      );
    }
    _lastUpdateCallbackId = SchedulerBinding.instance.scheduleFrameCallback((
      Duration timestamp,
    ) {
      _update();
      _lastUpdateCallbackId = null;
    });
  }

  void _update() {
    final sim = simulate(value, target.value, velocity);
    _disposeAnimation();
    _animation = SimAnimationController(vsync: _vsync, sim: sim)
      ..addListener(notifyListeners)
      ..addStatusListener(notifyStatusListeners);
    if (_animation case final anim? when !anim.isCompleted) {
      anim.start();
    }
  }

  void _disposeAnimation() {
    final anim = _animation;
    if (anim != null) {
      _value = anim.value;
      _velocity = anim.velocity;
      anim
        ..removeListener(notifyListeners)
        ..removeStatusListener(notifyStatusListeners)
        ..dispose();
      _animation = null;
    }
  }

  @override
  void didStartListening() {
    _update();
    target.addListener(_scheduleUpdate);
  }

  @override
  void didStopListening() {
    target.removeListener(_scheduleUpdate);
    _disposeAnimation();
    if (_lastUpdateCallbackId != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(
        _lastUpdateCallbackId!,
      );
      _lastUpdateCallbackId = null;
    }
  }
}

/// A generic transform function from one value to another of the same type.
typedef FluxTransform<T> = T Function(T value);

/// A transformation wrapper for an animation.
class TransformedAnimation<T> extends FluxAnimation<T>
    with
        AnimationLocalStatusListenersMixin,
        AnimationLocalListenersMixin,
        AnimationLazyListenerMixin {
  TransformedAnimation({
    required this.animation,
    required this.valueTransform,
    required this.velocityTransform,
  });

  final FluxAnimation<T> animation;
  final FluxTransform<T> valueTransform;
  final FluxTransform<T> velocityTransform;

  @override
  AnimationStatus get status => animation.status;

  @override
  T get value => valueTransform(animation.value);

  @override
  T get velocity => velocityTransform(animation.velocity);

  @override
  void didStartListening() {
    animation
      ..addListener(notifyListeners)
      ..addStatusListener(notifyStatusListeners);
  }

  @override
  void didStopListening() {
    animation
      ..removeListener(notifyListeners)
      ..removeStatusListener(notifyStatusListeners);
  }
}

/// A [FluxAnimation] that chains animations in succession.
///
/// First the initial animation runs until completed, then the next one
/// takes over. Used for: drag → spring → settle sequences.
class ChainedAnimation<T> extends FluxAnimation<T>
    with
        AnimationLocalStatusListenersMixin,
        AnimationLocalListenersMixin,
        AnimationLazyListenerMixin {
  ChainedAnimation(this._animation, {FluxAnimation<T>? then})
    : _next = then == null ? null : ChainedAnimation(then) {
    if (_next != null && _animation.isCompleted) {
      _active = _next;
    } else {
      _active = _animation;
    }
  }

  final FluxAnimation<T> _animation;
  final ChainedAnimation<T>? _next;
  late FluxAnimation<T> _active;

  /// Returns a new animation that runs this, then [next].
  ChainedAnimation<T> then(FluxAnimation<T> next) =>
      .new(_animation, then: next);

  @override
  AnimationStatus get status => _active.status;

  @override
  T get value => _active.value;

  @override
  T get velocity => _active.velocity;

  AnimationStatusListener get _currentStatusListener =>
      _active == _animation && _next != null
      ? _animationStatusListener
      : notifyStatusListeners;

  void _animationStatusListener(AnimationStatus status) {
    final next = _next;
    if (_active == _animation &&
        next != null &&
        (_animation.isCompleted || _animation.isDismissed)) {
      _animation
        ..removeListener(notifyListeners)
        ..removeStatusListener(_animationStatusListener);
      _active = next
        ..addListener(notifyListeners)
        ..addStatusListener(notifyStatusListeners);
    }
    if (status != .completed) {
      notifyStatusListeners(status);
    }
  }

  @override
  void didStartListening() {
    _active =
        (((_animation.isCompleted || _animation.isDismissed)
                  ? _next
                  : _animation) ??
              _animation)
          ..addListener(notifyListeners)
          ..addStatusListener(_currentStatusListener);
  }

  @override
  void didStopListening() {
    _active
      ..removeListener(notifyListeners)
      ..removeStatusListener(_currentStatusListener);
  }
}
