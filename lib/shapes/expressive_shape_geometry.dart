import 'package:androidx_graphics_shapes/material_shapes.dart';
import 'package:flutter/painting.dart';

import 'bounds_centered_border.dart';
import 'material_expressive_shape.dart';
import 'src/material_shape_safe_area_data.dart';

export 'material_expressive_shape.dart';
export 'bounds_centered_border.dart';

/// A reusable pairing of a border and its precomputed content interiors.
///
/// Keep this object while endpoints stay unchanged. Morph matching happens once,
/// not on animation ticks. No assets, asynchronous loading, or runtime geometric
/// searches are needed. Only the catalog's unrotated, unit-coordinate borders
/// are supported; do not apply these interiors to another border transform.
class ExpressiveShapeGeometry {
  ExpressiveShapeGeometry({required this.to, this.from})
    : _snapshot = null,
      _snapshotCenter = null;

  ExpressiveShapeGeometry._retarget({
    required this.to,
    required this._snapshot,
    required this._snapshotCenter,
  }) : from = null;

  final RoundedPolygon? _snapshot;
  final Offset? _snapshotCenter;

  // Re-matching subdivides curves, which can shift Path.getBounds(). Preserve
  // the previous alignment at t=0, relaxing the correction to zero at t=1.
  late final Offset _startCorrection = _snapshotCenter == null
      ? Offset.zero
      : _morph!.toPath(progress: 0).getBounds().center - _snapshotCenter;

  final MaterialExpressiveShape to;
  final MaterialExpressiveShape? from;

  late final Morph? _morph = _snapshot != null
      ? Morph(_snapshot, to.polygon)
      : from == null
      ? null
      : Morph(from!.polygon, to.polygon);

  /// Redirect from the current outline, not the previous target. Settled
  /// endpoints keep their original polygon features. An interrupted frame has
  /// no catalog corner metadata: preserve its exact cubics as ignorable edge
  /// features and let Morph use its perimeter-based fallback correspondence.
  /// This preserves position, not animation velocity. It neither samples nor
  /// normalizes the outline and retains no chain of previous animations.
  ///
  /// For interrupted transitions only the new destination's interior is used:
  /// the snapshot is a transient frame and is NOT certified content-safe.
  ExpressiveShapeGeometry retarget(
    MaterialExpressiveShape target, {
    required double progress,
  }) {
    _validateProgress(progress);
    if (progress == 1 || _morph == null) {
      return ExpressiveShapeGeometry(from: to, to: target);
    }
    if (progress == 0 && _snapshot == null) {
      return ExpressiveShapeGeometry(from: from, to: target);
    }
    final cubics = _morph.asCubics(progress);
    // Morph's matching tolerances can leave tiny gaps after repeated cuts.
    // Match Path.cubicTo's behavior: each segment starts at the previous end,
    // not its independently stored anchor0. This keeps the captured path closed.
    final connected = [
      for (var i = 0; i < cubics.length; i++)
        Cubic.from(
          cubics[(i + cubics.length - 1) % cubics.length].anchor1X,
          cubics[(i + cubics.length - 1) % cubics.length].anchor1Y,
          cubics[i].control0X,
          cubics[i].control0Y,
          cubics[i].control1X,
          cubics[i].control1Y,
          cubics[i].anchor1X,
          cubics[i].anchor1Y,
        ),
    ];
    return ExpressiveShapeGeometry._retarget(
      to: target,
      snapshot: RoundedPolygon.fromFeatures(
        features: connected.map(Feature.edge).toList(),
      ),
      snapshotCenter:
          _morph.toPath(progress: progress).getBounds().center -
          _startCorrection * (1 - progress),
    );
  }

  void _validateProgress(double progress) {
    if (!progress.isFinite || progress < 0 || progress > 1) {
      throw ArgumentError.value(progress, 'progress', 'Must be in [0, 1]');
    }
  }

  /// Filled-area centroid in the same centered unit coordinates as [safeRects].
  /// Candidate selection uses this only after legibility and surface size are
  /// tied, preventing table order from choosing an arbitrary equivalent lobe.
  late final Offset preferredCenter = from == null
      ? _translatedPoint(
          to,
          _morph?.toPath(progress: 1).getBounds().center ??
              to.polygon.toPath().getBounds().center,
        )
      : (_translatedPoint(
                  from!,
                  _morph!.toPath(progress: 0).getBounds().center,
                ) +
                _translatedPoint(
                  to,
                  _morph.toPath(progress: 1).getBounds().center,
                )) /
            2;

  /// Rectangles safe at catalog endpoints, not necessarily during transitions.
  /// After mid-morph retargeting, only the destination is certified safe.
  /// Intersecting endpoint rectangles is safe; interpolating/unioning is not.
  late final List<Rect> safeRects = List.unmodifiable({
    if (from == null)
      ..._translatedRects(
        to,
        _morph?.toPath(progress: 1).getBounds().center ??
            to.polygon.toPath().getBounds().center,
      )
    else
      for (final start in _translatedRects(
        from!,
        _morph!.toPath(progress: 0).getBounds().center,
      ))
        for (final end in _translatedRects(
          to,
          _morph.toPath(progress: 1).getBounds().center,
        ))
          if (!start.intersect(end).isEmpty) start.intersect(end),
  });

  Offset _translatedPoint(MaterialExpressiveShape shape, Offset center) =>
      materialShapeAreaCentroidData[shape]! + (const Offset(0.5, 0.5) - center);

  Iterable<Rect> _translatedRects(
    MaterialExpressiveShape shape,
    Offset center,
  ) sync* {
    final translation = const Offset(0.5, 0.5) - center;
    for (final rect in materialShapeSafeAreaData[shape]!) {
      // BoundsCenteredBorder translates this endpoint's path center to the
      // layout center. Apply exactly the same translation to the certified raw
      // rectangle, preserving the generator's freely optimized placement.
      yield rect.shift(translation);
    }
  }

  /// Centers the scaled path's bounds like Compose's toShape adapter.
  /// [stretch] permits nonuniform scaling; false preserves proportions.
  BoundsCenteredBorder border({double progress = 1, bool stretch = false}) {
    _validateProgress(progress);
    final morph = _morph;
    return BoundsCenteredBorder(
      morph == null
          ? RoundedPolygonBorder(polygon: to.polygon, squash: stretch ? 1 : 0)
          : MorphBorder(
              morph: morph,
              progress: progress,
              squash: stretch ? 1 : 0,
            ),
      alignmentCorrection: _startCorrection * (1 - progress),
    );
  }
}
