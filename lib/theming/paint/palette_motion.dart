import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/colorspaces/hct.dart';
import 'package:libmonet/theming/interpolation_style.dart';
import 'package:libmonet/theming/palette.dart';
import 'package:libmonet/theming/palette_roles.dart';

import 'progress_motion.dart';

// Compatibility for the original paint API; outputs no longer depend on motion.
export 'package:libmonet/theming/palette_roles.dart';

/// Optional structural work counters, not wall-clock performance guarantees.
class PaintMotionStats {
  int interpolations = 0;
  int roleReads = 0;
  int bindingNotifications = 0;
}

/// Immutable endpoint identity with lazily memoized colors. Distinct transitions
/// can share this without sharing their starting colors or progress.
class PaletteEndpoint {
  PaletteEndpoint(this.palette, this.stats);
  final Palette palette;
  final PaintMotionStats? stats;
  final Map<PaletteRole, Color> _colors = {};
  Color read(PaletteRole role) => _colors.putIfAbsent(role, () {
    stats?.roleReads++;
    return role.read(palette);
  });
}

class _LazyPaletteFrame extends RolePalette {
  _LazyPaletteFrame(
    this.endpoint,
    this.begin,
    this.t,
    super.colorModel,
    this.style,
  );
  final PaletteEndpoint endpoint;
  final Map<PaletteRole, Color> begin;
  final double t;
  final InterpolationStyle style;
  final Map<PaletteRole, Color> _colors = {};
  @override
  Color readRole(PaletteRole role) => _colors.putIfAbsent(role, () {
    final end = endpoint.read(role);
    final start = begin[role] ?? end;
    if (t <= 0 || start == end) return start;
    if (t >= 1) return end;
    endpoint.stats?.interpolations++;
    return switch (style) {
      InterpolationStyle.polar => Hct.lerpKeepHue(
        start,
        end,
        t,
        model: colorModel,
      ),
      InterpolationStyle.cartesian => Hct.lerpLoseHueAndChroma(
        start,
        end,
        t,
        model: colorModel,
      ),
    };
  });
  // Object identity: equality must never discover dependencies or solve colors.
}

/// One progress spring per independently retargeting palette. Only retained
/// colors are flattened on interruption. Ticks advance progress and report
/// potentially changing roles, but never calculate RGB or compare full palettes.
class PaletteMotion {
  PaletteMotion(
    Palette palette, {
    ColorModel? model,
    InterpolationStyle style = InterpolationStyle.cartesian,
    PaintMotionStats? stats,
    Set<PaletteRole>? roles,
  }) : this.fromEndpoint(
         PaletteEndpoint(palette, stats),
         model: model,
         style: style,
         roles: roles,
       );

  PaletteMotion.fromEndpoint(
    this._endpoint, {
    ColorModel? model,
    this._style = InterpolationStyle.cartesian,
    Set<PaletteRole>? roles,
  }) : _model = model ?? _endpoint.palette.colorModel {
    setRoles(roles ?? const {});
  }

  /// Fork only the departing consumer's displayed colors. The owner immediately
  /// retargets this snapshot; the destination endpoint can already be shared.
  PaletteMotion.copy(PaletteMotion other, {required Set<PaletteRole> roles})
    : _endpoint = other._endpoint,
      _model = other._model,
      _style = other._style,
      _roles = Set.of(roles),
      _changing = Set.of(roles),
      _begin = {for (final role in roles) role: role.read(other.frame)},
      _sampleTime = other._sampleTime,
      _t = 0;

  Set<PaletteRole> _roles = {};
  Map<PaletteRole, Color> _begin = const {};
  Set<PaletteRole> _changing = const {};
  PaletteEndpoint _endpoint;
  ColorModel _model;
  InterpolationStyle _style;
  final ProgressMotion _progress = ProgressMotion();
  double _t = 1;
  double? _sampleTime;
  Palette? _frame;
  bool get isMoving => _t < 1 && _changing.isNotEmpty;
  int get trackCount => _roles.length;
  Palette get frame =>
      _frame ??= _LazyPaletteFrame(_endpoint, _begin, _t, _model, _style);

  void setRoles(Set<PaletteRole> roles) {
    if (setEquals(roles, _roles)) return;
    _roles = Set.of(roles);
    if (_begin.keys.any((role) => !roles.contains(role))) {
      _begin = {
        for (final role in roles)
          if (_begin.containsKey(role)) role: _begin[role]!,
      };
      _frame = null;
    }
    _changing = _changing.intersection(roles);
    for (final role in roles) {
      _endpoint.read(role);
    }
    if (_changing.isEmpty && _t != 1) {
      _t = 1;
      _progress.snap();
      _frame = null;
    }
  }

  /// Returns retained roles whose displayed values changed immediately (snap),
  /// or may change (new transition). No reads of unretained outputs.
  Set<PaletteRole> retarget(
    Palette target,
    double time,
    double omega, {
    ColorModel? model,
    InterpolationStyle? style,
    bool snap = false,
    PaletteEndpoint? endpoint,
  }) {
    final sampled = sample(time);
    final sameEndpoint = _endpoint.palette == target;
    final nextModel = model ?? _model, nextStyle = style ?? _style;
    if (!snap &&
        sameEndpoint &&
        nextModel == _model &&
        nextStyle == _style &&
        ((_t == 1) || (isMoving && omega == _progress.omega))) {
      return sampled;
    }
    // Even snaps compare only already-retained outputs, once at retarget.
    final visible = {for (final role in _roles) role: role.read(frame)};
    if (!sameEndpoint) {
      _endpoint = endpoint ?? PaletteEndpoint(target, _endpoint.stats);
    }
    _model = nextModel;
    _style = nextStyle;
    final changed = {
      for (final role in _roles)
        if (visible[role] != _endpoint.read(role)) role,
    };
    _begin = snap ? const {} : visible;
    _changing = snap ? const {} : changed;
    _t = _changing.isEmpty ? 1 : 0;
    if (isMoving) {
      _progress.restart(time, omega);
    } else {
      _progress.snap();
    }
    _sampleTime = time;
    _frame = null;
    return {...sampled, ...changed};
  }

  Set<PaletteRole> sample(double time) {
    if (_sampleTime == time) return const {};
    _sampleTime = time;
    if (!isMoving) return const {};
    final t = _progress.sample(time);
    if (_t == t) return const {};
    _t = t;
    _frame = null;
    return _changing; // Includes the final sample even though isMoving is false.
  }

  /// Merge settled histories without resolving anything during the tick.
  void absorbSettledRoles(PaletteMotion other) {
    assert(!isMoving && !other.isMoving);
    assert(_model == other._model && _style == other._style);
    _endpoint._colors.addAll(other._endpoint._colors);
    _roles.addAll(other._roles);
    _begin = const {};
    _changing = const {};
    _t = 1;
    _frame = null;
  }
}
