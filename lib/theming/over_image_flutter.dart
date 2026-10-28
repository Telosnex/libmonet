import 'dart:ui';

import 'package:libmonet/contrast/contrast.dart';

import 'package:libmonet/effects/over_image.dart';
import 'package:libmonet/theming/monet_theme_data.dart';
import 'package:libmonet/util/lru_cache.dart';

// Few distinct (algo, contrast) pairs; a handful covers a contrast animation
// without holding every frame's.
final _unknownBackgrounds = LruCache<(Algo, double), AnyBackground>(
  capacity: 8,
);

/// Flutter helpers for `effects/over_image.dart`.

extension MonetThemeAnyBackground on MonetThemeData {
  /// [argbs] behind this theme's UI, judged by its algo and contrast.
  /// Real pixels only; see [AnyBackground.new].
  AnyBackground anyBackground(List<int> argbs) =>
      AnyBackground(argbs, algo: algo, contrast: contrast);

  /// Nothing known behind this theme's UI; see [AnyBackground.unknown].
  /// Shared per algo and contrast, so its answer cache is too.
  AnyBackground get unknownBackground => _unknownBackgrounds.putIfAbsent((
    algo,
    contrast,
  ), () => AnyBackground.unknown(algo: algo, contrast: contrast));
}

extension ScrimFlutter on Scrim {
  /// [Scrim.paintArgb] as a [Color]: fill a rect behind the content.
  Color get paintColor => Color(paintArgb);
}

extension ShadowsWithStrokeFlutter on ShadowsWithStroke {
  /// Paint for the widened glyph: stroke the glyph at 2 × [stroke] with
  /// this, under the fill. The mask keeps the band solid and blurs beyond.
  Paint get strokePaint => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2 * stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = scrim.paintColor
    ..maskFilter = blurRadius > 0
        ? MaskFilter.blur(BlurStyle.solid, blurSigma)
        : null;
}

extension ShadowsFlutter on Shadows {
  /// For [TextStyle.shadows].
  List<Shadow> get textShadows => [
    for (final o in layerOpacities)
      Shadow(
        color: Color(scrim.scrimArgb).withValues(alpha: o),
        blurRadius: blurRadius,
      ),
  ];
}

extension SharedBorderFlutter on SharedBorder {
  /// The border for surface [i], in the order passed to
  /// [AnyBackground.sharedBorder].
  Color colorAt(int i) => Color(borderArgbs[i]);
}
