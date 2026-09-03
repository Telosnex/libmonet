import 'dart:ui' as ui;

import 'package:flutter/material.dart' show kThemeAnimationDuration;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:libmonet/theming/monet_theme_data.dart';

/// Dissolves the previous rendering of [child] into its new one when [data]
/// changes: a raster cross-fade instead of an animated inherited theme.
///
/// ## Why
///
/// [AnimatedMonetTheme] animates a theme change by publishing intermediate
/// inherited themes (by default 30×/s), and every `MonetTheme.of` dependent
/// rebuilds on each publish. For a *local* palette change (one surface moving
/// over wallpaper) the dependents are few and the paint bus carries most of the
/// motion. For a *global* change — light/dark toggle, new seed color, contrast
/// or scale — the dependents are the whole app, so each publish is a
/// thousands-of-rebuilds frame and the transition janks in proportion to how
/// much UI is on screen.
///
/// A dissolve costs the same regardless of UI complexity: one rebuild wave
/// when the target changes (the theme snaps), one GPU texture of the previous
/// frame, and a per-frame image blend. No widget rebuilds during motion.
///
/// ## Use
///
/// Wrap the theme that should snap. [data] must be the *same* value handed to
/// the inner theme so both switch in the same frame:
///
/// ```dart
/// MonetThemeCrossfade(
///   data: theme,
///   duration: kThemeAnimationDuration,
///   child: AnimatedMonetTheme(
///     data: theme,
///     duration: Duration.zero, // snap; the crossfade is the transition
///     child: app,
///   ),
/// )
/// ```
///
/// Nested [AnimatedMonetTheme]s below (e.g. wallpaper-positioned surfaces)
/// keep working; their own motion simply happens under the fading raster.
///
/// ## How
///
/// [child] is wrapped in a [RepaintBoundary], so its render object owns an
/// [OffsetLayer] holding exactly the pixels it drew last frame. When [data]
/// changes, that layer is rasterized *during the build phase of the same
/// frame* — before this frame's paint replaces its contents — with
/// `OffsetLayer.toImageSync`. The live child then paints normally and the
/// snapshot is drawn on top with decreasing alpha, driven by an animation the
/// render object listens to directly (paint-only; no `setState`).
///
/// The snapshot is dropped early if the child's size changes mid-fade (window
/// resize): a stale-sized raster is worse than an abrupt finish.
///
/// Pointer events pass through to the live child throughout; the snapshot is
/// purely visual.
class MonetThemeCrossfade extends StatefulWidget {
  /// The theme value whose changes trigger a cross-fade. Compared with `==`.
  final MonetThemeData data;

  /// Fade duration of the previous raster.
  final Duration duration;

  /// Applied to the fade progress before it becomes alpha.
  final Curve curve;

  final Widget child;

  const MonetThemeCrossfade({
    super.key,
    required this.data,
    required this.child,
    this.duration = kThemeAnimationDuration,
    this.curve = Curves.linear,
  });

  @override
  State<MonetThemeCrossfade> createState() => _MonetThemeCrossfadeState();
}

class _MonetThemeCrossfadeState extends State<MonetThemeCrossfade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    // Start completed: nothing to fade until the first change.
    value: 1.0,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: widget.curve,
  );

  /// Bumped on every [MonetThemeCrossfade.data] change; the render object
  /// captures its child's last raster when it sees a new generation.
  int _captureGeneration = 0;

  @override
  void didUpdateWidget(MonetThemeCrossfade oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (widget.data != oldWidget.data) {
      _captureGeneration++;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _MonetThemeCrossfadeRenderWidget(
      captureGeneration: _captureGeneration,
      progress: _progress,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      child: RepaintBoundary(child: widget.child),
    );
  }
}

class _MonetThemeCrossfadeRenderWidget extends SingleChildRenderObjectWidget {
  final int captureGeneration;
  final Animation<double> progress;
  final double devicePixelRatio;

  const _MonetThemeCrossfadeRenderWidget({
    required this.captureGeneration,
    required this.progress,
    required this.devicePixelRatio,
    required Widget super.child,
  });

  @override
  RenderMonetThemeCrossfade createRenderObject(BuildContext context) {
    return RenderMonetThemeCrossfade(
      captureGeneration: captureGeneration,
      progress: progress,
      devicePixelRatio: devicePixelRatio,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderMonetThemeCrossfade renderObject,
  ) {
    renderObject
      ..devicePixelRatio = devicePixelRatio
      ..progress = progress
      // Last: capturing reads the child's layer, which must reflect the
      // previous frame. Setting it here — during build, before this frame's
      // paint — is what guarantees that.
      ..captureGeneration = captureGeneration;
  }
}

/// Paints [child], then the raster of its previous appearance fading out.
class RenderMonetThemeCrossfade extends RenderProxyBox {
  RenderMonetThemeCrossfade({
    required int captureGeneration,
    required Animation<double> progress,
    required double devicePixelRatio,
  }) // Private fields with public setters: initializing formals would put the
    // private names in the public signature.
    // ignore: prefer_initializing_formals
    : _captureGeneration = captureGeneration,
       // ignore: prefer_initializing_formals
       _progress = progress,
       // ignore: prefer_initializing_formals
       _devicePixelRatio = devicePixelRatio;

  int _captureGeneration;
  set captureGeneration(int value) {
    if (_captureGeneration == value) return;
    _captureGeneration = value;
    _captureSnapshot();
    markNeedsPaint();
  }

  Animation<double> _progress;
  set progress(Animation<double> value) {
    if (identical(_progress, value)) return;
    if (attached) _progress.removeListener(markNeedsPaint);
    _progress = value;
    if (attached) _progress.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) return;
    _devicePixelRatio = value;
    // A snapshot at the old ratio would be resampled; drop it.
    _disposeSnapshot();
    markNeedsPaint();
  }

  ui.Image? _snapshot;
  Size _snapshotSize = Size.zero;

  /// Rasterizes the child's *last painted* frame.
  ///
  /// Reads the child's [OffsetLayer] (it is a [RepaintBoundary]) rather than
  /// calling `RenderRepaintBoundary.toImageSync`, whose debug assertion
  /// rejects a child that is marked needing paint — which is exactly the
  /// state a child is in right after its theme changed. The layer still holds
  /// the previous frame's pictures until the paint phase replaces them.
  void _captureSnapshot() {
    final child = this.child;
    final layer = child?.layer;
    if (child == null || layer is! OffsetLayer || !child.hasSize) return;
    final bounds = Offset.zero & child.size;
    if (bounds.isEmpty) return;
    _disposeSnapshot();
    _snapshot = layer.toImageSync(bounds, pixelRatio: _devicePixelRatio);
    _snapshotSize = child.size;
  }

  void _disposeSnapshot() {
    _snapshot?.dispose();
    _snapshot = null;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _progress.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _progress.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _disposeSnapshot();
    super.dispose();
  }

  @override
  void performLayout() {
    super.performLayout();
    if (_snapshot != null && size != _snapshotSize) _disposeSnapshot();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    context.paintChild(child, offset);

    final snapshot = _snapshot;
    if (snapshot == null) return;
    final alpha = 1.0 - _progress.value;
    if (alpha <= 0.0) {
      _disposeSnapshot();
      return;
    }
    // Drawn into a fresh picture on top of the child's layer: paintChild
    // ended the previous recording, so this canvas is a new layer above it.
    final scale = 1.0 / _devicePixelRatio;
    context.canvas
      ..save()
      ..translate(offset.dx, offset.dy)
      ..scale(scale, scale)
      ..drawImage(
        snapshot,
        Offset.zero,
        Paint()..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0)),
      )
      ..restore();
  }

  /// Whether a previous raster is currently being faded out.
  bool get debugIsCrossfading => _snapshot != null;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('captureGeneration', _captureGeneration))
      ..add(DoubleProperty('progress', _progress.value))
      ..add(
        FlagProperty(
          'crossfading',
          value: _snapshot != null,
          ifTrue: 'fading previous raster',
        ),
      );
  }
}
