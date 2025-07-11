import 'dart:math' as math;
import 'package:libmonet/apca.dart';
import 'package:libmonet/apca_contrast.dart';
import 'package:libmonet/argb_srgb_xyz_lab.dart';
import 'package:libmonet/wcag.dart';
import 'debug_print.dart';

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
          (Usage.large) => lighterTextLstar(withLstar, -apca,
              debug: debug), // 160dp large text
        };
        monetDebug(debug, () => 'naiveLighterLstar: $naiveLighterLstar');
        if (naiveLighterLstar.round() <= 100) {
          return naiveLighterLstar.clamp(0, 100);
        }
        final naiveDarkerLstar = switch (usage) {
          (Usage.text) => darkerTextLstar(withLstar, apca, debug: debug),
          (Usage.fill) => darkerBackgroundLstar(withLstar, -apca, debug: debug),
          (Usage.large) =>
            darkerTextLstar(withLstar, apca, debug: debug), // 160dp large text
        };
        final naiveLighterDelta =
            (math.min(100, naiveLighterLstar) - withLstar).abs();
        final naiveDarkerDelta =
            (math.max(naiveDarkerLstar, 0) - withLstar).abs();
        monetDebug(debug, () => 'naiveLighterDelta: $naiveLighterDelta');
        monetDebug(debug, () => 'naiveDarkerDelta: $naiveDarkerDelta');
        if (naiveLighterDelta.roundToDouble() >=
            naiveDarkerDelta.roundToDouble()) {
          return 100.0;
        }
        return 0.0;
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
        final naiveDarkerLstar = darkerLstarUnsafe(
          lstar: withLstar,
          contrastRatio: ratio,
        );
        final naiveLighterDelta =
            (math.min(100, naiveLighterLstar) - withLstar).abs();
        final naiveDarkerDelta =
            (math.max(naiveDarkerLstar, 0) - withLstar).abs();
        monetDebug(debug, () => 'naiveLighterDelta: $naiveLighterDelta');
        monetDebug(debug, () => 'naiveDarkerDelta: $naiveDarkerDelta');
        if (naiveLighterDelta.roundToDouble() >=
            naiveDarkerDelta.roundToDouble()) {
          monetDebug(debug,
              () => 'returning white, naiveLighterDelta >= naiveDarkerDelta');
          return 100.0;
        }
        monetDebug(debug,
            () => 'returning black, naiveLighterDelta < naiveDarkerDelta');
        return 0.0;
    }
  } else {
    switch (by) {
      case Algo.apca:
        // APCA is negative when referring to a darker color.
        final apca = apcaInterpolation(percent: contrast, usage: usage);
        monetDebug(debug, () => 'apca: $apca');
        final naiveDarkerLstar = switch (usage) {
          (Usage.text) => darkerTextLstar(withLstar, apca, debug: debug),
          (Usage.fill) => darkerBackgroundLstar(withLstar, -apca, debug: debug),
          (Usage.large) =>
            darkerTextLstar(withLstar, apca, debug: debug), // 160dp large text
        };
        monetDebug(debug, () => 'naiveDarkerLstar: $naiveDarkerLstar');
        if (naiveDarkerLstar.round() >= 0) {
          return naiveDarkerLstar.clamp(0.0, 100.0);
        }
        final naiveLighterLstar = switch (usage) {
          (Usage.text) => lighterTextLstar(withLstar, -apca, debug: debug),
          (Usage.fill) => lighterBackgroundLstar(withLstar, apca, debug: debug),
          (Usage.large) => lighterTextLstar(withLstar, -apca,
              debug: debug), // 160dp large text
        };
        monetDebug(debug, () => 'naiveLighterLstar: $naiveLighterLstar');
        final naiveLighterDelta =
            (math.min(100, naiveLighterLstar) - naiveLighterLstar).abs();
        final naiveDarkerDelta =
            (math.max(naiveDarkerLstar, 0) - naiveDarkerLstar).abs();
        monetDebug(debug, () => 'naiveLighterDelta: $naiveLighterDelta');
        monetDebug(debug, () => 'naiveDarkerDelta: $naiveDarkerDelta');
        if (naiveDarkerDelta.roundToDouble() <=
            naiveLighterDelta.roundToDouble()) {
          return 0.0;
        }
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
        final naiveLighterDelta =
            (math.min(100, naiveLighterLstar) - naiveLighterLstar).abs();
        final naiveDarkerDelta =
            (math.max(naiveDarkerLstar, 0) - naiveDarkerLstar).abs();
        monetDebug(debug, () => 'naiveLighterDelta: $naiveLighterDelta');
        monetDebug(debug, () => 'naiveDarkerDelta: $naiveDarkerDelta');
        if (naiveDarkerDelta.roundToDouble() <=
            naiveLighterDelta.roundToDouble()) {
          monetDebug(debug,
              () => 'returning black, naiveDarkerDelta <= naiveLighterDelta');
          return 0.0;
        }
        monetDebug(debug,
            () => 'returning white, naiveDarkerDelta > naiveLighterDelta');
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
    (Usage.text) => 60, // "APCA Lc 60 'similar' to WCAG 4.5"
    (Usage.fill) => 45, // "APCA Lc 45 'similar' to WCAG 3.0"
    (Usage.large) => 30, // APCA Lc 30 is minimum for legible semantic elements
    // > 5.5 CSS px in at least one dimension.
  };
  // Earlier, assumed end was 100. But, at high contrast, this wasn't leading
  // to white/black as expected. 110 seems to work better...but better to have
  // a concrete reason for this.
  const end = 110;
  final actualPercent = (percent > 0.5 ? percent - 0.5 : percent) / 0.5;
  final actualStart = percent > 0.5 ? mid : start;
  final actualEnd = percent > 0.5 ? end : mid;
  final range = actualEnd - actualStart;
  final apca = actualStart + (range * actualPercent);
  return apca;
}
