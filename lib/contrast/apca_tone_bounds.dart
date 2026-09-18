import 'dart:math' as math;

import 'package:libmonet/contrast/apca.dart';
import 'package:libmonet/contrast/apca_tone_bounds_data.dart';
import 'package:libmonet/util/lru_cache.dart';

/// Conservative raw APCA-brightness envelope for every opaque sRGB color at
/// one actual CIE L*. These are inputs to canonical APCA, before its black clamp.
final class ApcaBrightnessBounds {
  const ApcaBrightnessBounds(this.minimum, this.maximum);
  final double minimum;
  final double maximum;
}

// HCT fixes continuous CIE Y, then rounds each encoded sRGB channel to 8 bits.
// Enumerating all 256^3 rounded cells and their half-code preimages gives a
// worst CIE L* displacement of 0.260590. The larger public policy margin also
// covers transfer-knee and optimizer floating-point residuals.
const double kPaletteToneMaterializationUncertainty = 0.3;

const _whiteApcaY = sRco + sGco + sBco;
const _outwardEpsilon = 1e-10;
const _stepsPerTone = 4;
final _boundsCache = LruCache<double, ApcaBrightnessBounds>(capacity: 256);

/// Returns a reviewed, conservative continuous-gamut envelope at [actualTone].
///
/// The checked-in quarter-tone table is generated from the branch-complete
/// derivation in `tool/apca_tone_bounds.dart`: split all eight sRGB transfer
/// branch combinations, use the one-multiplier convex minimum, and enumerate
/// sliced-box vertices for the maximum. The envelopes are monotone (a feasible
/// color can increase/decrease channels to reach the adjacent Y while APCA
/// brightness moves in the same direction), so floor/ceiling table brackets
/// are conservative. We never interpolate. A 1e-10 outward margin exceeds the
/// measured ~1.2e-14 optimizer residual. Cached values allocate once per tone;
/// no optimizer runs in production or per palette role.
ApcaBrightnessBounds apcaBrightnessBoundsAtTone(double actualTone) {
  if (!actualTone.isFinite || actualTone < 0 || actualTone > 100) {
    throw ArgumentError.value(
      actualTone,
      'actualTone',
      'must be finite and in 0...100',
    );
  }
  return _boundsCache.putIfAbsent(actualTone, () {
    final scaled = actualTone * _stepsPerTone;
    final lowerIndex = scaled.floor();
    final upperIndex = scaled.ceil();
    assert(apcaMinimumAtQuarterTone.length == 401);
    assert(apcaMaximumAtQuarterTone.length == 401);
    return ApcaBrightnessBounds(
      math.max(0, apcaMinimumAtQuarterTone[lowerIndex] - _outwardEpsilon),
      math.min(
        _whiteApcaY,
        apcaMaximumAtQuarterTone[upperIndex] + _outwardEpsilon,
      ),
    );
  });
}
