import 'dart:math' as math;
import 'package:libmonet/apca.dart';
import 'package:libmonet/wcag.dart';
import 'debug_print.dart';

enum Algo {
  wcag21,
  apca,
}

enum Usage {
  text,
  fill,
}

double contrastingLstar({
  required double withLstar,
  required Usage usage,
  required Algo by,
  required double contrastPercentage,
  bool debug = false,
}) {
  final prefersLighter = lstarPrefersLighterPair(withLstar);
  monetDebug(debug, () => 'prefersLighter: $prefersLighter');
  if (prefersLighter) {
    switch (by) {
      case Algo.apca:
        final apca =
            apcaInterpolation(percent: contrastPercentage, usage: usage);
        monetDebug(debug, () => 'apca: $apca');
        final naiveLighterLstar = switch (usage) {
          (Usage.text) => lighterTextLstar(withLstar, -apca, debug: debug),
          (Usage.fill) => lighterBackgroundLstar(withLstar, apca, debug: debug)
        };
        monetDebug(debug, () => 'naiveLighterLstar: $naiveLighterLstar');
        if (naiveLighterLstar.round() <= 100) {
          return naiveLighterLstar;
        }
        final naiveDarkerLstar = switch (usage) {
          (Usage.text) => darkerTextLstar(withLstar, apca, debug: debug),
          (Usage.fill) => darkerBackgroundLstar(withLstar, -apca, debug: debug)
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
        final ratio = contrastRatio(percent: contrastPercentage, usage: usage);
        monetDebug(debug, () => 'ratio: $ratio');
        final naiveLighterLstar = lighterLstarUnsafe(
          lstar: withLstar,
          contrastRatio: ratio,
        );
        monetDebug(debug, () => 'naiveLighterLstar: $naiveLighterLstar');
        if (naiveLighterLstar.round() <= 100) {
          return naiveLighterLstar;
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
          monetDebug(debug, () => 'returning white, naiveLighterDelta >= naiveDarkerDelta');
          return 100.0;
        }
        monetDebug(debug, () => 'returning black, naiveLighterDelta < naiveDarkerDelta');
        return 0.0;
    }
  } else {
    switch (by) {
      case Algo.apca:
        // APCA is negative when referring to a darker color.
        final apca =
            apcaInterpolation(percent: contrastPercentage, usage: usage);
        monetDebug(debug, () => 'apca: $apca');
        final naiveDarkerLstar = switch (usage) {
          (Usage.text) => darkerTextLstar(withLstar, apca, debug: debug),
          (Usage.fill) => darkerBackgroundLstar(withLstar, -apca)
        };
        monetDebug(debug, () => 'naiveDarkerLstar: $naiveDarkerLstar');
        if (naiveDarkerLstar.round() >= 0) {
          return naiveDarkerLstar;
        }
        final naiveLighterLstar = switch (usage) {
          (Usage.text) => lighterTextLstar(withLstar, -apca),
          (Usage.fill) => lighterBackgroundLstar(withLstar, apca)
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
        final ratio = contrastRatio(percent: contrastPercentage, usage: usage);
        monetDebug(debug, () => 'ratio: $ratio with ${withLstar.round()}');
        final naiveDarkerLstar = darkerLstarUnsafe(
          lstar: withLstar,
          contrastRatio: ratio,
        );
        monetDebug(debug, () => 'naiveDarkerLstar: $naiveDarkerLstar');
        if (naiveDarkerLstar.round() >= 0) {
          return naiveDarkerLstar;
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
          monetDebug(debug, () => 'returning black, naiveDarkerDelta <= naiveLighterDelta');
          return 0.0;
        }
        monetDebug(debug, () => 'returning white, naiveDarkerDelta > naiveLighterDelta');
        return 100.0;
    }
  }
}

bool lstarPrefersLighterPair(double lstar) {
  return lstar.round() <= 60.0;
}

double contrastRatio({required double percent, required Usage usage}) {
  const start = 1.0;
  final mid = switch (usage) {
    (Usage.text) => 4.5,
    (Usage.fill) => 3.0,
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
  };
  const end = 100;
  final actualPercent = (percent > 0.5 ? percent - 0.5 : percent) / 0.5;
  final actualStart = percent > 0.5 ? mid : start;
  final actualEnd = percent > 0.5 ? end : mid;
  final range = actualEnd - actualStart;
  final apca = actualStart + (range * actualPercent);
  return apca;
}
