import 'dart:ui';
import 'package:libmonet/contrast/contrast.dart';
import 'package:libmonet/core/hex_codes.dart';
import 'package:libmonet/effects/protection.dart';
import 'package:libmonet/util/with_opacity_neue.dart';

export 'package:libmonet/effects/protection.dart'
    show StackedShadowSpec, getStackedShadowSpec, convertRadiusToSigma;

/// Flutter-flavored view of a [StackedShadowSpec].
///
/// The math lives in `protection.dart` (`getStackedShadowSpec`); this type
/// exists to hand `TextStyle.shadows` a ready list. Prefer the single-layer
/// halo (`getHalo` + a dilate-then-blur underlay) wherever the renderer
/// allows; stacked shadows are the compatibility fallback.
class ShadowResult {
  final double blurRadius;

  /// ARGB of the shadow color (typically black or white).
  final int shadowArgb;

  /// Opacities for each shadow layer. Identical by construction (closed
  /// form), unlike the legacy iterative solver's descending tail.
  final List<double> opacities;

  /// False when no stack of shadows can meet the target (infeasible
  /// protection, zero blur, or layer cap exceeded). The layers returned are
  /// then the best effort. Never silently absent.
  final bool meetsTarget;

  ShadowResult({
    required this.blurRadius,
    required this.shadowArgb,
    required this.opacities,
    this.meetsTarget = true,
  });

  List<Shadow>? _shadows;
  List<Shadow> get shadows {
    _shadows ??= opacities
        .map((e) => Shadow(
              color: Color(shadowArgb).withOpacityNeue(e),
              blurRadius: blurRadius,
              offset: const Offset(0, 0),
            ))
        .toList();
    return _shadows!;
  }
}

ShadowResult _fromSpec(StackedShadowSpec spec) => ShadowResult(
      blurRadius: spec.blurRadius,
      shadowArgb: spec.argb,
      opacities: spec.opacities,
      meetsTarget: spec.meetsTarget,
    );

/// Shadow layers so [foreground] meets [contrast] against every color in
/// [backgrounds].
ShadowResult getShadowOpacitiesForBackgrounds({
  required Color foreground,
  required Iterable<Color> backgrounds,
  required double contrast,
  required Algo algo,
  required double blurRadius,
  double contentRadius = -1.0,
  bool debug = false,
}) {
  return _fromSpec(getStackedShadowSpec(
    foregroundArgb: foreground.argb,
    backgroundArgbs: backgrounds.map((c) => c.argb).toList(),
    contrast: contrast,
    algo: algo,
    blurRadius: blurRadius,
    contentRadius: contentRadius,
  ));
}
