import 'dart:math' as math;

/// Derives a display scale factor (physical pixels per logical pixel) from
/// physical display geometry and expected viewing distance, instead of
/// trusting the OS or device manufacturer to report a sane DPI.
///
/// Follows Fuchsia's root_presenter DisplayModel
/// (garnet/bin/ui/root_presenter/displays/display_model.cc), which defines
/// the logical unit *angularly*: one logical pixel ("pip") subtends 0.0255
/// degrees of visual angle at nominal viewing distance. This is Android's dp
/// (1/160in at ~14in => ~0.0253 deg) and iOS's pt (1/163in => ~0.0245 deg)
/// generalized to be distance-independent. CSS px (1/96in at 28in =>
/// 0.0213 deg) is the outlier; it is used here only as a fallback.
///
/// The entire model reduces to:
///
///     scale = pxPerMm * tan(0.0255 deg) * vdist * (0.5 + 180mm / vdist)
///
/// The trailing term is Fuchsia's empirically-derived *adaptation factor*.
/// Pure angular parity feels wrong across distances: human size constancy
/// partially "un-shrinks" distant objects, and far displays (desktops, TVs)
/// are expected to carry more content than a phone. The factor is anchored
/// at 1.0 for handheld (360mm) — dp-equivalent by construction — and
/// asymptotes to 0.5 for infinitely distant displays.

/// Visual angle subtended by one logical pixel at nominal viewing distance,
/// in degrees. Taken verbatim from Fuchsia; equals an Android dp to ~1%.
const double logicalPixelVisualAngleDegrees = 0.0255;

/// Fallback pixel angle when density or viewing distance is unknown: assume
/// physical pixels are CSS reference pixels, i.e. pretend the display is a
/// classic 96dpi desktop monitor at arm's length. Yields scale ~1.2, which
/// degrades to roughly what X11/Windows would have done anyway.
const double _fallbackPixelVisualAngleDegrees = 0.0213;

/// Adaptation factor = 0.5 + [_adaptationDistanceMm] / vdist.
const double _adaptationDistanceMm = 180.0;

/// Densities outside 30..600 ppi are treated as lies (EDID physical-size
/// bytes are frequently zero, wrong, or copy-pasted from another panel;
/// projectors report nonsense by definition) and trigger the fallback path.
const double _minPlausiblePxPerMm = 30.0 / 25.4;
const double _maxPlausiblePxPerMm = 600.0 / 25.4;

/// Expected viewing distance, when not directly known. Values from Fuchsia.
enum DisplayUsage {
  /// Held in the hand: phone, small tablet.
  handheld(360),

  /// Laptop distance.
  close(500),

  /// Desktop monitor distance.
  near(720),

  /// Kitchen display, kiosk.
  midrange(1200),

  /// TV across the room.
  far(3000);

  const DisplayUsage(this.viewingDistanceMm);

  final double viewingDistanceMm;
}

/// Physical floor on scale imposed by fingertips rather than eyes.
///
/// Legibility is governed by visual angle and thus viewing distance; tap
/// targets are governed by fingertip size (~7-9mm) and are
/// distance-irrelevant. On touch displays the final scale is
/// max(visualScale, touchScale) where touchScale guarantees that
/// [minLogicalPx] logical pixels span at least [minPhysicalMm] millimeters.
class TouchTargets {
  const TouchTargets({
    this.minPhysicalMm = 8.0,
    this.minLogicalPx = 48.0,
  });

  /// Minimum physical size of a touch target. ~7-9mm fits adult fingertips;
  /// 8mm is a reasonable default. (Material's 48dp at 160dpi is 7.62mm.)
  final double minPhysicalMm;

  /// The logical-pixel convention for a minimum touch target in your UI
  /// toolkit. Material uses 48.
  final double minLogicalPx;
}

/// Inputs describing a physical display. Call [compute] to derive
/// [DisplayMetrics].
///
/// Physical size may be given as [widthMm]/[heightMm] (e.g. from EDID) or as
/// [diagonalInches] (e.g. from a spec sheet). If neither is available — or
/// the claimed density is implausible — the model falls back to assuming a
/// 96dpi desktop monitor rather than inventing precision it doesn't have.
class DisplayModel {
  DisplayModel({
    required this.widthPx,
    required this.heightPx,
    this.widthMm,
    this.heightMm,
    this.diagonalInches,
    this.usage,
    this.viewingDistanceMm,
    this.userScaleFactor = 1.0,
    this.touch,
    this.integerSnapTolerance = 0.02,
  })  : assert(widthPx > 0),
        assert(heightPx > 0),
        assert(userScaleFactor > 0);

  final int widthPx;
  final int heightPx;

  /// Physical width/height of the display area, in millimeters, if known.
  final double? widthMm;
  final double? heightMm;

  /// Alternative to [widthMm]/[heightMm]: diagonal in inches, per spec sheet.
  final double? diagonalInches;

  /// Usage class supplying a default viewing distance.
  final DisplayUsage? usage;

  /// Measured/configured viewing distance; overrides [usage] if set.
  final double? viewingDistanceMm;

  /// User preference multiplier, applied last. Callers should report the
  /// reduced logical resolution honestly so layout reflows rather than
  /// zoom-cropping.
  final double userScaleFactor;

  /// If non-null, enforce a minimum physical touch-target size.
  final TouchTargets? touch;

  /// Snap scale to a nearby integer within this relative tolerance (e.g.
  /// 1.985 -> 2.0). Bitmap assets and 1px hairlines render dramatically
  /// crisper at integer scales, and a ~2% size change is imperceptible.
  final double integerSnapTolerance;

  /// Pixel density in px/mm, or null if unknown or implausible.
  double? get pxPerMm {
    final wMm = widthMm;
    final hMm = heightMm;
    final diagonalPx =
        math.sqrt((widthPx * widthPx + heightPx * heightPx).toDouble());
    double? ppm;
    if (wMm != null && hMm != null && wMm > 0 && hMm > 0) {
      ppm = diagonalPx / math.sqrt(wMm * wMm + hMm * hMm);
    } else if (diagonalInches != null && diagonalInches! > 0) {
      ppm = diagonalPx / (diagonalInches! * 25.4);
    }
    if (ppm == null) {
      return null;
    }
    if (ppm < _minPlausiblePxPerMm || ppm > _maxPlausiblePxPerMm) {
      return null;
    }
    return ppm;
  }

  DisplayMetrics compute() {
    final ppm = pxPerMm;
    final vdist = viewingDistanceMm ?? usage?.viewingDistanceMm;
    final tanPip =
        math.tan(logicalPixelVisualAngleDegrees * math.pi / 180.0);

    final double visualScale;
    final bool usedFallback;
    if (ppm != null && vdist != null && vdist > 0) {
      final adaptation = 0.5 + _adaptationDistanceMm / vdist;
      visualScale = ppm * tanPip * vdist * adaptation * userScaleFactor;
      usedFallback = false;
    } else {
      visualScale = logicalPixelVisualAngleDegrees /
          _fallbackPixelVisualAngleDegrees *
          userScaleFactor;
      usedFallback = true;
    }

    double? touchScale;
    final touchTargets = touch;
    if (touchTargets != null && ppm != null) {
      touchScale = ppm * touchTargets.minPhysicalMm / touchTargets.minLogicalPx;
    }

    var raw = visualScale;
    if (touchScale != null && touchScale > raw) {
      raw = touchScale;
    }

    double scale;
    final nearestInt = raw.roundToDouble();
    if (nearestInt >= 1.0 &&
        (raw - nearestInt).abs() / nearestInt <= integerSnapTolerance &&
        (touchScale == null || nearestInt >= touchScale)) {
      scale = nearestInt;
    } else {
      // Quantize to 8 mantissa bits so scale * any integer up to +/-65793
      // stays exact in float32, killing seam/round-off bugs in layout.
      scale = _quantize(raw, (m) => m.roundToDouble());
      if (touchScale != null && scale < touchScale) {
        // Rounding dipped below the physical touch floor; take the next
        // quantization step up instead.
        scale = _quantize(raw, (m) => m.ceilToDouble());
      }
    }

    return DisplayMetrics(
      scale: scale,
      logicalWidth: widthPx / scale,
      logicalHeight: heightPx / scale,
      pxPerMm: ppm,
      viewingDistanceMm: vdist,
      visualScale: visualScale,
      touchScale: touchScale,
      usedFallback: usedFallback,
    );
  }
}

/// Derived metrics: the scale factor and logical resolution, plus the
/// intermediate values for diagnostics.
class DisplayMetrics {
  const DisplayMetrics({
    required this.scale,
    required this.logicalWidth,
    required this.logicalHeight,
    required this.pxPerMm,
    required this.viewingDistanceMm,
    required this.visualScale,
    required this.touchScale,
    required this.usedFallback,
  });

  /// Physical pixels per logical pixel. Integer-snapped or quantized to
  /// 8 mantissa bits.
  final double scale;

  final double logicalWidth;
  final double logicalHeight;

  /// Derived density, or null if unknown/implausible.
  final double? pxPerMm;

  /// Viewing distance used, or null if unknown.
  final double? viewingDistanceMm;

  /// The perceptual scale before integer snapping / quantization, after
  /// [DisplayModel.userScaleFactor].
  final double visualScale;

  /// The touch-target floor, if one was requested and density is known.
  final double? touchScale;

  /// True if the 96dpi-monitor fallback was used because density or viewing
  /// distance were unknown.
  final bool usedFallback;

  /// Visual angle actually subtended by one logical pixel, in degrees, or
  /// null if density or distance is unknown. Compare against
  /// [logicalPixelVisualAngleDegrees]; 20/20 acuity is ~0.0167 degrees.
  double? get logicalPixelAngleDegrees {
    final ppm = pxPerMm;
    final vdist = viewingDistanceMm;
    if (ppm == null || vdist == null || vdist <= 0) {
      return null;
    }
    return math.atan((scale / ppm) / vdist) * 180.0 / math.pi;
  }

  @override
  String toString() {
    return 'DisplayMetrics('
        'scale: $scale, '
        'logical: ${logicalWidth.toStringAsFixed(1)}x'
        '${logicalHeight.toStringAsFixed(1)}, '
        'pxPerMm: ${pxPerMm?.toStringAsFixed(2)}, '
        'vdist: $viewingDistanceMm, '
        'visualScale: ${visualScale.toStringAsFixed(4)}, '
        'touchScale: ${touchScale?.toStringAsFixed(4)}, '
        'usedFallback: $usedFallback)';
  }
}

/// Quantizes [value] to 8 significant mantissa bits (including the implicit
/// leading 1), per Fuchsia's DisplayModel::Quantize. [roundFn] chooses
/// round-to-nearest or ceil.
double _quantize(double value, double Function(double) roundFn) {
  if (!value.isFinite || value <= 0) {
    return value;
  }
  // frexp: value = m * 2^exp with m in [0.5, 1).
  var exp = (math.log(value) / math.ln2).floor() + 1;
  var m = value / math.pow(2.0, exp).toDouble();
  // Guard against log() rounding error at exact powers of two.
  if (m >= 1.0) {
    m /= 2.0;
    exp += 1;
  } else if (m < 0.5) {
    m *= 2.0;
    exp -= 1;
  }
  return roundFn(m * 256.0) / 256.0 * math.pow(2.0, exp).toDouble();
}
