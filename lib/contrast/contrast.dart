import 'dart:math' as math;
import 'package:libmonet/contrast/apca.dart';
import 'package:libmonet/contrast/apca_contrast.dart';
import 'package:libmonet/core/argb_srgb_xyz_lab.dart';
import 'package:libmonet/contrast/wcag.dart';
import '../util/debug_print.dart';

enum Algo {
  wcag21,
  apca;

  double getAbsoluteContrast(double interpolation, Usage usage) {
    switch (this) {
      case Algo.wcag21:
        return contrastRatioInterpolation(percent: interpolation, usage: usage);
      case Algo.apca:
        return apcaInterpolation(percent: interpolation, usage: usage);
    }
  }

  double getContrastBetweenLstars({required double bg, required double fg}) {
    switch (this) {
      case Algo.wcag21:
        return contrastRatioOfLstars(bg, fg);
      case Algo.apca:
        return apcaContrastOfApcaY(lstarToApcaY(bg), lstarToApcaY(fg));
    }
  }
}

enum Usage {
  text,
  fill,
  large, // 160dp, large text
  border, // border + blur radius >= 5px, per APCA Lc 15 guidance
}

double contrastingLstar({
  required double withLstar,
  required Usage usage,
  Algo by = Algo.apca,
  required double contrast,
  bool debug = false,
}) {
  monetDebug(debug, () => '== CONTRASTING LSTAR ENTER');
  monetDebug(
      debug,
      () =>
          '== Looking for $contrast contrast with $usage usage using $by algo on L* $withLstar');
  final prefersLighter = lstarPrefersLighterPair(withLstar);
  monetDebug(debug, () => 'prefersLighter: $prefersLighter');
  if (prefersLighter) {
    switch (by) {
      case Algo.apca:
        final apca = apcaInterpolation(percent: contrast, usage: usage);
        monetDebug(debug, () => 'apca: $apca');
        final naiveLighterLstar = switch (usage) {
          (Usage.text) => lighterTextLstar(withLstar, -apca, debug: debug),
          (Usage.fill) => lighterBackgroundLstar(withLstar, apca, debug: debug),
          (Usage.large) => lighterTextLstar(withLstar, -apca, debug: debug),
          (Usage.border) => lighterTextLstar(withLstar, -apca, debug: debug),
        };
        monetDebug(debug, () => 'naiveLighterLstar: $naiveLighterLstar');
        if (naiveLighterLstar.round() <= 100) {
          return naiveLighterLstar.clamp(0, 100);
        }
        // Lighter direction impossible; fall back to black or white
        // Compare actual contrast error: which is closer to desired?
        final apcaYWith = lstarToApcaY(withLstar);
        final blackContrast = apcaContrastOfApcaY(apcaYWith, lstarToApcaY(0)).abs();
        final whiteContrast = apcaContrastOfApcaY(apcaYWith, lstarToApcaY(100)).abs();
        final blackError = (apca - blackContrast).abs();
        final whiteError = (apca - whiteContrast).abs();
        monetDebug(debug, () => 'blackContrast: $blackContrast, error: $blackError');
        monetDebug(debug, () => 'whiteContrast: $whiteContrast, error: $whiteError');
        if (blackError <= whiteError) {
          monetDebug(debug, () => 'returning black (closer to desired contrast)');
          return 0.0;
        }
        monetDebug(debug, () => 'returning white (closer to desired contrast)');
        return 100.0;
      case Algo.wcag21:
        final ratio =
            contrastRatioInterpolation(percent: contrast, usage: usage);
        monetDebug(debug, () => 'ratio: $ratio');
        final naiveLighterLstar = lighterLstarUnsafe(
          lstar: withLstar,
          contrastRatio: ratio,
        );
        monetDebug(debug, () => 'naiveLighterLstar: $naiveLighterLstar');
        if (naiveLighterLstar.round() <= 100) {
          return naiveLighterLstar.clamp(0, 100);
        }
        // Lighter direction impossible; fall back to black or white
        // Compare actual contrast error: which is closer to desired?
        final blackContrast = contrastRatioOfLstars(withLstar, 0);
        final whiteContrast = contrastRatioOfLstars(withLstar, 100);
        final blackError = (ratio - blackContrast).abs();
        final whiteError = (ratio - whiteContrast).abs();
        monetDebug(debug, () => 'blackContrast: $blackContrast, error: $blackError');
        monetDebug(debug, () => 'whiteContrast: $whiteContrast, error: $whiteError');
        if (blackError <= whiteError) {
          monetDebug(debug, () => 'returning black (closer to desired contrast)');
          return 0.0;
        }
        monetDebug(debug, () => 'returning white (closer to desired contrast)');
        return 100.0;
    }
  } else {
    switch (by) {
      case Algo.apca:
        // APCA is negative when referring to a darker color.
        final apca = apcaInterpolation(percent: contrast, usage: usage);
        monetDebug(debug, () => 'apca: $apca');
        // Use unsafe functions to detect impossible values (< 0 or > 100)
        final naiveDarkerLstar = switch (usage) {
          (Usage.text) => darkerTextLstarUnsafe(withLstar, apca, debug: debug),
          (Usage.fill) =>
            darkerBackgroundLstarUnsafe(withLstar, -apca, debug: debug),
          (Usage.large) => darkerTextLstarUnsafe(withLstar, apca, debug: debug),
          (Usage.border) => darkerTextLstarUnsafe(withLstar, apca, debug: debug),
        };
        monetDebug(debug, () => 'naiveDarkerLstar: $naiveDarkerLstar');
        if (naiveDarkerLstar.round() >= 0) {
          return naiveDarkerLstar.clamp(0.0, 100.0);
        }
        final naiveLighterLstar = switch (usage) {
          (Usage.text) =>
            lighterTextLstarUnsafe(withLstar, -apca, debug: debug),
          (Usage.fill) =>
            lighterBackgroundLstarUnsafe(withLstar, apca, debug: debug),
          (Usage.large) => lighterTextLstarUnsafe(withLstar, -apca, debug: debug),
          (Usage.border) => lighterTextLstarUnsafe(withLstar, -apca, debug: debug),
        };
        monetDebug(debug, () => 'naiveLighterLstar: $naiveLighterLstar');
        // Compare actual contrast error: which is closer to desired?
        final apcaYWith = lstarToApcaY(withLstar);
        final blackContrast = apcaContrastOfApcaY(apcaYWith, lstarToApcaY(0)).abs();
        final whiteContrast = apcaContrastOfApcaY(apcaYWith, lstarToApcaY(100)).abs();
        final blackError = (apca - blackContrast).abs();
        final whiteError = (apca - whiteContrast).abs();
        monetDebug(debug, () => 'blackContrast: $blackContrast, error: $blackError');
        monetDebug(debug, () => 'whiteContrast: $whiteContrast, error: $whiteError');
        if (blackError <= whiteError) {
          monetDebug(debug, () => 'returning black (closer to desired contrast)');
          return 0.0;
        }
        monetDebug(debug, () => 'returning white (closer to desired contrast)');
        return 100.0;
      case Algo.wcag21:
        final ratio =
            contrastRatioInterpolation(percent: contrast, usage: usage);
        monetDebug(debug, () => 'ratio: $ratio with ${withLstar.round()}');
        final naiveDarkerLstar = darkerLstarUnsafe(
          lstar: withLstar,
          contrastRatio: ratio,
        );
        monetDebug(debug, () => 'naiveDarkerLstar: $naiveDarkerLstar');
        if (naiveDarkerLstar.round() >= 0) {
          return naiveDarkerLstar.clamp(0.0, 100.0);
        }
        final naiveLighterLstar = lighterLstarUnsafe(
          lstar: withLstar,
          contrastRatio: ratio,
        );
        monetDebug(debug, () => 'naiveLighterLstar: $naiveLighterLstar');
        // Compare actual contrast error: which is closer to desired?
        final blackContrast = contrastRatioOfLstars(withLstar, 0);
        final whiteContrast = contrastRatioOfLstars(withLstar, 100);
        final blackError = (ratio - blackContrast).abs();
        final whiteError = (ratio - whiteContrast).abs();
        monetDebug(debug, () => 'blackContrast: $blackContrast, error: $blackError');
        monetDebug(debug, () => 'whiteContrast: $whiteContrast, error: $whiteError');
        if (blackError <= whiteError) {
          monetDebug(debug, () => 'returning black (closer to desired contrast)');
          return 0.0;
        }
        monetDebug(debug, () => 'returning white (closer to desired contrast)');
        return 100.0;
    }
  }
}

bool lstarPrefersLighterPair(double lstar) {
  return lstar.round() <= 60.0;
}

double contrastRatioOfLstars(double a, double b) {
  final aY = yFromLstar(a);
  final bY = yFromLstar(b);
  final higher = math.max(aY, bY);
  final lower = math.min(aY, bY);

  final contrast = (higher + 5.0) / (lower + 5.0);
  return contrast;
}

double contrastRatioInterpolation(
    {required double percent, required Usage usage}) {
  const start = 1.0;
  final mid = switch (usage) {
    (Usage.text) => 4.5,
    (Usage.fill) => 3.0,
    (Usage.large) => 3.0, // WCAG21 3.0 for large text (same as fill)
    (Usage.border) => 1.5, // Lower requirement for visible non-text
  };
  const end = 21.0;
  final actualPercent = (percent > 0.5 ? percent - 0.5 : percent) / 0.5;
  final actualStart = percent > 0.5 ? mid : start;
  final actualEnd = percent > 0.5 ? end : mid;
  final range = actualEnd - actualStart;
  final ratio = actualStart + (range * actualPercent);
  return ratio;
}

double apcaInterpolation({required double percent, required Usage usage}) {
  const start = 0.0;
  final mid = switch (usage) {
    (Usage.text) => 60.0, // "APCA Lc 60 'similar' to WCAG 4.5"
    (Usage.fill) => 45.0, // "APCA Lc 45 'similar' to WCAG 3.0"
    (Usage.large) => 30.0, // APCA Lc 30 is minimum for legible semantic elements
    // > 5.5 CSS px in at least one dimension.
    (Usage.border) => 15.0, // APCA Lc 15 for non-text >= 5px (border + blur)
  };
  // Earlier, assumed end was 100. But, at high contrast, this wasn't leading
  // to white/black as expected. 110 seems to work better...but better to have
  // a concrete reason for this.
  const end = 110.0;
  final actualPercent = (percent > 0.5 ? percent - 0.5 : percent) / 0.5;
  final actualStart = percent > 0.5 ? mid : start;
  final actualEnd = percent > 0.5 ? end : mid;
  final range = actualEnd - actualStart;
  final apca = actualStart + (range * actualPercent);
  return apca;
}
