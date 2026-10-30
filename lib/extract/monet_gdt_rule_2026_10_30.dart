// monet_gdt rule 2026-10-30: the wallpaper theme color triad (primary,
// secondary, tertiary), from a quantizer's clusters.
//
// Made mainly to create training targets: monet_gdt's on-device color model
// is trained on this rule's triads, and its graph applies this rule's role
// order exactly. It was not tuned as a general-purpose scorer.
//
// Guiding principle: choose colorful colors, at the expense of population.
// A small vivid area outweighs a large dull one
// (MonetGdtRule20261030Option.colorMass), and a neutral is never chosen
// while a colorful option covering 1% of the image is unused.
//
// It needs kMonetGdtRule20261030Clusters (128) clusters from
// QuantizerCelebi (Wu, then weighted k-means), as the original Material You
// wallpaper extraction used. With the 32 used before, small colorful areas
// are lost in larger clusters. 128 clusters cost much more: per 96 px
// thumbnail (Dart VM, desktop Mac, 200 wallpapers), quantizing takes 3.1 ms
// and this rule 7.7 ms, against 2.8 ms and 1.3 ms with 32 clusters, and
// about 0.1 ms for ScorerTriad.
//
// So it is slower than ScorerTriad and picks small colorful areas. Whether
// that trade-off is right depends on the use case and the compute budget.
import 'dart:math';

import 'package:monet_ui/colorspaces/hct.dart';
import 'package:monet_ui/core/argb_srgb_xyz_lab.dart';
import 'package:monet_ui/extract/quantizer_result.dart';

/// The QuantizerCelebi cluster count this rule needs.
const kMonetGdtRule20261030Clusters = 128;

/// Whether a color reads as colorful rather than dull: chroma at least
/// [MonetGdtRule20261030.colorfulChroma], or, where its hue and tone cannot
/// reach much chroma, at least [MonetGdtRule20261030.colorfulFraction] of what
/// they can (never below [MonetGdtRule20261030.minChroma]). So a dark red near
/// its limit counts, and a lavender is not held to a blue's high limit.
bool monetGdtRule20261030IsColorful(Hct h) =>
    h.chroma >= MonetGdtRule20261030.minChroma &&
    h.chroma >=
        min(
          MonetGdtRule20261030.colorfulChroma,
          MonetGdtRule20261030.colorfulFraction *
              monetGdtRule20261030MaxChroma(h.hue, h.tone),
        );

/// The most chroma sRGB can show at [hue] and [tone].
double monetGdtRule20261030MaxChroma(double hue, double tone) =>
    Hct.from(hue, 200, tone).chroma;

/// A measured color option: a merged group of quantizer clusters, shown as
/// its most chromatic sizable member.
class MonetGdtRule20261030Option {
  final int argb;
  final Hct hct;

  /// The group's share of the image.
  final double share;

  /// The share of the image in this group's colorful members.
  final double colorfulShare;

  MonetGdtRule20261030Option(this.argb, this.share, this.colorfulShare)
    : hct = Hct.fromInt(argb),
      lab = labFromArgb(argb);

  final List<double> lab;

  /// CIELAB ΔE76 to [o].
  double deltaE(MonetGdtRule20261030Option o) => sqrt(
    pow(lab[0] - o.lab[0], 2) +
        pow(lab[1] - o.lab[1], 2) +
        pow(lab[2] - o.lab[2], 2),
  );

  double get hue => hct.hue;
  double get chroma => hct.chroma;
  double get tone => hct.tone;
  bool get isColorful =>
      colorfulShare > 0 && monetGdtRule20261030IsColorful(hct);

  /// How much color this option puts in front of a viewer: chroma, times
  /// the colorful area with diminishing returns (doubling an area does not
  /// double how much it reads), so a vivid accent can outweigh a large dull
  /// area.
  double get colorMass => sqrt(colorfulShare) * chroma;
}

/// The triad and the options it was chosen from.
class MonetGdtRule20261030Triad {
  final List<MonetGdtRule20261030Option> options;
  final List<MonetGdtRule20261030Option> triad;

  const MonetGdtRule20261030Triad(this.options, this.triad);
}

/// Picks primary, secondary and tertiary the way the wallpaper color brief
/// asks a person or a vision model to, as code.
///
/// The brief: choose only from colors measured from the image; represent
/// the wallpaper as a person sees it, not only its largest areas; the three
/// differ; secondary is a hue step of about 20-30 degrees from primary, not
/// a darker, lighter or grayer version of it; tertiary a much larger jump,
/// roughly opposite when the image has every hue; with few hues, the two
/// that differ most in hue, tertiary the most; if every color is gray, pick
/// by lightness.
///
/// The steps:
/// 1. Options: the image's clusters merged as for the brief (at most
///    [maxOptions], no two within ΔE [minDeltaE]); each shows its most
///    chromatic member with at least 1% of the group.
/// 2. Colorful: [monetGdtRule20261030IsColorful]. An option is noticeably colorful when
///    its colorful members cover at least [noticeableShare] of the image.
/// 3. Invariant: a neutral is never chosen while a noticeably colorful
///    option is unused.
/// 4. Primary: the noticeably colorful option with the most color
///    ([MonetGdtRule20261030Option.colorMass]).
/// 5. Tertiary: of options at least [tertiaryJump] in hue from primary,
///    the one with the most color (else the farthest hue). Secondary: of
///    the rest with a distinct hue (at least [distinctHue] from both), the
///    one with the most color within 15 degrees of [secondaryStep] from
///    primary (else the nearest step). Each looks first among
///    noticeably colorful options, then among all colorful ones, so a
///    different hue beats another shade of primary's.
/// 6. Otherwise fill: noticeably colorful options by color, then options
///    by lightness (farthest in tone from those chosen); both skip shades
///    of a chosen color (same hue, ΔE < [shadeDeltaE]). With no colorful
///    option at all, primary is the largest option.
/// 7. Roles: of the two others, tertiary is the larger step from primary
///    (hue when all three are colorful, else ΔE).
///
/// Every returned color is a measured option; none is invented.
class MonetGdtRule20261030 {
  static const double colorfulChroma = 16;
  static const double minChroma = 8;
  static const double colorfulFraction = 0.35;
  static const double noticeableShare = 0.01;
  static const double secondaryStep = 25;
  static const double distinctHue = 15;
  static const double tertiaryJump = 60;

  /// Twice the option merge distance: closer than this, a same-hue option
  /// reads as a shade of the chosen one.
  static const double shadeDeltaE = 20;

  /// [pixels]: the opaque ARGB pixels [result] quantized. When given, each
  /// cluster's share is recounted from them (the quantizer's mapping, else
  /// the nearest cluster in RGB), as the brief's options are measured.
  static MonetGdtRule20261030Triad score(
    QuantizerResult result, {
    List<int>? pixels,
    double noticeableShare = noticeableShare,
    double secondaryStep = secondaryStep,
    double distinctHue = distinctHue,
    double shadeDeltaE = shadeDeltaE,
    int maxOptions = 12,
    int minOptions = 4,
    double minDeltaE = 10,
  }) {
    final options = mergeOptions(
      clusterShares(result, pixels: pixels),
      maxOptions: maxOptions,
      minOptions: minOptions,
      minDeltaE: minDeltaE,
    );
    if (options.isEmpty) return MonetGdtRule20261030Triad(options, const []);

    final colorful = [
      for (final o in options)
        if (o.isColorful) o,
    ];
    final noticeable = [
      for (final o in colorful)
        if (o.colorfulShare >= noticeableShare) o,
    ];
    final triad = <MonetGdtRule20261030Option>[];
    List<MonetGdtRule20261030Option> unused(
      List<MonetGdtRule20261030Option> xs,
    ) => [
      for (final o in xs)
        if (!triad.contains(o)) o,
    ];
    bool distinct(MonetGdtRule20261030Option o) => triad.every(
      (t) => !t.isColorful || differenceDegrees(o.hue, t.hue) >= distinctHue,
    );

    if (colorful.isEmpty) {
      triad.add(_maxBy(options, (o) => o.share));
    } else {
      final primary = _maxBy(
        noticeable.isNotEmpty ? noticeable : colorful,
        (o) => o.colorMass,
      );
      triad.add(primary);
      double step(MonetGdtRule20261030Option o) =>
          differenceDegrees(o.hue, primary.hue);

      MonetGdtRule20261030Option? tertiary;
      for (final pool in [noticeable, colorful]) {
        final c = [
          for (final o in unused(pool))
            if (distinct(o)) o,
        ];
        if (c.isNotEmpty) {
          final jump = [
            for (final o in c)
              if (step(o) >= tertiaryJump) o,
          ];
          tertiary = jump.isNotEmpty
              ? _maxBy<MonetGdtRule20261030Option>(jump, (o) => o.colorMass)
              : _maxBy<MonetGdtRule20261030Option>(
                  c,
                  (o) => step(o) + o.colorMass * 1e-6,
                );
          break;
        }
      }
      if (tertiary != null) triad.add(tertiary);

      for (final pool in [noticeable, colorful]) {
        final c = [
          for (final o in unused(pool))
            if (distinct(o)) o,
        ];
        if (c.isNotEmpty) {
          final band = [
            for (final o in c)
              if ((step(o) - secondaryStep).abs() <= 15) o,
          ];
          final secondary = band.isNotEmpty
              ? _maxBy(band, (o) => o.colorMass)
              : _maxBy(
                  c,
                  (o) => -(step(o) - secondaryStep).abs() + o.colorMass * 1e-6,
                );
          triad.insert(1, secondary);
          break;
        }
      }
    }

    // A shade: same hue as a chosen colorful swatch and close to it
    // (ΔE < [shadeDeltaE]). It repeats a shown color rather than adding
    // one; a much lighter or darker one still adds range.
    bool shade(MonetGdtRule20261030Option o) =>
        o.isColorful &&
        triad.any(
          (t) =>
              t.isColorful &&
              differenceDegrees(o.hue, t.hue) < distinctHue &&
              t.deltaE(o) < shadeDeltaE,
        );
    while (triad.length < 3 && triad.length < options.length) {
      final left = [
        for (final o in unused(noticeable))
          if (!shade(o)) o,
      ];
      if (left.isNotEmpty) {
        triad.add(_maxBy(left, (o) => o.colorMass));
        continue;
      }
      final rest = [
        for (final o in unused(options))
          if (!shade(o)) o,
      ];
      triad.add(
        _maxBy(
          rest.isNotEmpty ? rest : unused(options),
          (o) => triad.map((t) => (t.tone - o.tone).abs()).reduce(min),
        ),
      );
    }

    // Roles: tertiary is the larger step from primary, in hue when all
    // three are colorful, else in overall color difference.
    if (triad.length == 3) {
      final p = triad[0];
      final byHue = triad.every((t) => t.isColorful);
      double step(MonetGdtRule20261030Option o) =>
          byHue ? differenceDegrees(o.hue, p.hue) : p.deltaE(o);
      if (step(triad[1]) > step(triad[2])) {
        triad.insert(1, triad.removeAt(2));
      }
    }
    return MonetGdtRule20261030Triad(options, triad);
  }

  static T _maxBy<T>(List<T> xs, double Function(T) f) {
    var best = xs.first;
    var bestV = f(best);
    for (final x in xs.skip(1)) {
      final v = f(x);
      if (v > bestV) {
        best = x;
        bestV = v;
      }
    }
    return best;
  }

  /// Each cluster of [result] with its share of the image, largest first.
  /// With [pixels], shares are recounted from them: each pixel goes to the
  /// quantizer's cluster for it, else the nearest cluster in RGB.
  static List<(int argb, double share)> clusterShares(
    QuantizerResult result, {
    List<int>? pixels,
  }) {
    final clusters = result.argbToCount.keys.toList();
    final counts = <int, num>{};
    num total = 0;
    if (pixels == null) {
      result.argbToCount.forEach((k, v) => counts[k] = v);
      total = counts.values.fold<num>(0, (a, b) => a + b);
    } else {
      for (final c in clusters) {
        counts[c] = 0;
      }
      int d(int c, int p) {
        final dr = ((c >> 16) & 255) - ((p >> 16) & 255);
        final dg = ((c >> 8) & 255) - ((p >> 8) & 255);
        final db = (c & 255) - (p & 255);
        return dr * dr + dg * dg + db * db;
      }

      for (final p in pixels) {
        final m = result.inputPixelToClusterPixel[p];
        final c = m != null && counts.containsKey(m)
            ? m
            : clusters.reduce((a, b) => d(a, p) <= d(b, p) ? a : b);
        counts[c] = counts[c]! + 1;
        total++;
      }
    }
    if (total == 0) return const [];
    return [for (final e in counts.entries) (e.key, e.value / total)]
      ..sort((a, b) => b.$2.compareTo(a.$2));
  }

  /// The options a person is shown: [clusters] (largest first) merged
  /// closest pair first (CIELAB ΔE76) until at most [maxOptions] remain and
  /// none are within [minDeltaE], never below [minOptions]. A group's
  /// position is its largest member; it shows its most chromatic member with
  /// at least [minMemberFraction] of the group's share. Largest share first.
  static List<MonetGdtRule20261030Option> mergeOptions(
    List<(int argb, double share)> clusters, {
    int maxOptions = 12,
    int minOptions = 4,
    double minDeltaE = 10,
    double minMemberFraction = 0.01,
  }) {
    final groups = [
      for (final c in clusters) _Group(c.$1, [c.$1], [c.$2]),
    ];
    while (groups.length > minOptions) {
      var bi = 0, bj = 1;
      var best = double.infinity;
      for (var i = 0; i < groups.length; i++) {
        for (var j = i + 1; j < groups.length; j++) {
          final d = groups[i].distanceTo(groups[j]);
          if (d < best) {
            best = d;
            bi = i;
            bj = j;
          }
        }
      }
      if (best >= minDeltaE && groups.length <= maxOptions) break;
      final a = groups[bi], b = groups[bj];
      groups
        ..removeAt(bj)
        ..[bi] = _Group(
          a.share >= b.share ? a.argb : b.argb,
          [...a.members, ...b.members],
          [...a.memberShares, ...b.memberShares],
        );
    }
    groups.sort((a, b) => b.share.compareTo(a.share));
    return [
      for (final g in groups)
        MonetGdtRule20261030Option(
          g.vividArgb(minMemberFraction),
          g.share,
          g.colorfulShare(),
        ),
    ];
  }
}

class _Group {
  final int argb;
  final List<int> members;
  final List<double> memberShares;
  final List<double> lab;
  final double share;

  _Group(this.argb, this.members, this.memberShares)
    : lab = labFromArgb(argb),
      share = memberShares.fold(0.0, (a, b) => a + b);

  int vividArgb(double minFraction) {
    var best = argb;
    var bestChroma = Hct.fromInt(argb).chroma;
    for (var i = 0; i < members.length; i++) {
      if (memberShares[i] < minFraction * share) continue;
      final c = Hct.fromInt(members[i]).chroma;
      if (c > bestChroma) {
        best = members[i];
        bestChroma = c;
      }
    }
    return best;
  }

  double colorfulShare() {
    var s = 0.0;
    for (var i = 0; i < members.length; i++) {
      if (monetGdtRule20261030IsColorful(Hct.fromInt(members[i]))) {
        s += memberShares[i];
      }
    }
    return s;
  }

  double distanceTo(_Group o) => sqrt(
    pow(lab[0] - o.lab[0], 2) +
        pow(lab[1] - o.lab[1], 2) +
        pow(lab[2] - o.lab[2], 2),
  );
}
