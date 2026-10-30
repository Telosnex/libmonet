// monet_gdt rule v1: the wallpaper theme color triad. Given a wallpaper's
// color options and a probability per option for each role (primary,
// secondary, tertiary), picks one option per role. The probabilities come
// from a vision model's answers or the on-device graph's color model.
// monet_gdt trains that color model on this rule's triads and ports the rule
// into the graph (scripts/graph_rule.py, checked equal on every label).
import 'dart:math';

import 'package:monet_ui/colorspaces/hct.dart';
import 'package:monet_ui/core/argb_srgb_xyz_lab.dart';

/// The roles, in order.
const kWallpaperColorRoles = ['primary', 'secondary', 'tertiary'];

int _argbOfHex(String hex) =>
    0xff000000 | int.parse(hex.substring(1), radix: 16);

/// [kMonetGdtRuleV1Plausible] x the role's best probability; colorful at HCT
/// chroma [kMonetGdtRuleV1Colorful]; a distinct hue at
/// [kMonetGdtRuleV1HueGap] degrees; S weighs chroma by
/// [kMonetGdtRuleV1SecondaryChromaWeight]; S and T stay [kMonetGdtRuleV1MinDeltaE]
/// (CIELAB ΔE76) from earlier picks when they can.
const kMonetGdtRuleV1Plausible = 0.25;
const kMonetGdtRuleV1Colorful = 16.0;
const kMonetGdtRuleV1HueGap = 30.0;
const kMonetGdtRuleV1SecondaryChromaWeight = 0.5;
const kMonetGdtRuleV1MinDeltaE = 10.0;

/// The bands, in degrees from primary's complement, that tertiary searches.
const _kTertiaryBands = [30.0, 60.0, 90.0, 120.0, 180.0];

/// The triad by rule_v1 (blind A/B: beat the vision model's top picks with the
/// on-device chroma rule 27-11). [options] in offered order; [probabilities]
/// per role in [kWallpaperColorRoles] order, by hex (missing counts as 0).
/// The probabilities bound each role to its plausible options; the rule picks:
///  - primary: the most chromatic plausible option;
///  - tertiary: among colorful plausible options, the nearest primary's
///    complement hue, in widening bands, most chromatic in the first band
///    that has any; else (none colorful, or primary gray) the most chromatic;
///  - secondary: colorful and a distinct hue from both -> most chromatic;
///    else the best mix of chroma and hue gap from primary (tone gap when
///    primary is gray).
/// HCT is rounded to whole numbers, as in the labels. Ties go to the earlier
/// option. Null with fewer than three options.
List<String>? monetGdtRuleV1Triad(
  List<String> options,
  List<Map<String, double>> probabilities,
) {
  if (options.length < 3 || probabilities.length != 3) return null;
  // Rounded, as the labels show them and as the A/B ran.
  final hct = {
    for (final h in options)
      h: () {
        final c = Hct.fromInt(_argbOfHex(h));
        return (
          hue: c.hue.roundToDouble(),
          chroma: c.chroma.roundToDouble(),
          tone: c.tone.roundToDouble(),
        );
      }(),
  };
  final lab = {for (final h in options) h: labFromArgb(_argbOfHex(h))};
  double chroma(String h) => hct[h]!.chroma;
  double de(String a, String b) {
    final x = lab[a]!, y = lab[b]!;
    return sqrt(
      pow(x[0] - y[0], 2) + pow(x[1] - y[1], 2) + pow(x[2] - y[2], 2),
    );
  }

  double hueGap(double a, double b) => ((a - b + 180) % 360 - 180).abs();
  String maxBy(List<String> xs, double Function(String) f) {
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

  List<String> plausible(int role, List<String> pool) {
    final p = probabilities[role];
    final known = pool.where(p.containsKey).toList();
    final from = known.isEmpty ? pool : known;
    final top = from.map((x) => p[x] ?? 0).reduce(max);
    return [
      for (final x in from)
        if ((p[x] ?? 0) >= kMonetGdtRuleV1Plausible * top) x,
    ];
  }

  List<String> apart(List<String> picked) {
    final free = [
      for (final x in options)
        if (!picked.contains(x)) x,
    ];
    final far = [
      for (final x in free)
        if (picked.every((y) => de(x, y) >= kMonetGdtRuleV1MinDeltaE)) x,
    ];
    return far.isEmpty ? free : far;
  }

  final p = maxBy(plausible(0, options), chroma);
  final primaryGray = chroma(p) < kMonetGdtRuleV1Colorful;

  final tPool = plausible(2, apart([p]));
  String? t;
  final colorful = [
    for (final x in tPool)
      if (chroma(x) >= kMonetGdtRuleV1Colorful) x,
  ];
  if (colorful.isNotEmpty && !primaryGray) {
    final complement = (hct[p]!.hue + 180) % 360;
    for (final band in _kTertiaryBands) {
      final inBand = [
        for (final x in colorful)
          if (hueGap(hct[x]!.hue, complement) <= band) x,
      ];
      if (inBand.isNotEmpty) {
        t = maxBy(inBand, chroma);
        break;
      }
    }
  }
  t ??= maxBy(tPool, chroma);

  final sPool = plausible(1, apart([p, t]));
  final distinct = [
    for (final x in sPool)
      if (chroma(x) >= kMonetGdtRuleV1Colorful &&
          hueGap(hct[x]!.hue, hct[p]!.hue) >= kMonetGdtRuleV1HueGap &&
          hueGap(hct[x]!.hue, hct[t]!.hue) >= kMonetGdtRuleV1HueGap)
        x,
  ];
  final String s;
  if (distinct.isNotEmpty) {
    s = maxBy(distinct, chroma);
  } else {
    final top = sPool.map(chroma).reduce(max);
    final maxChroma = top == 0 ? 1.0 : top;
    double gap(String x) => primaryGray
        ? (hct[x]!.tone - hct[p]!.tone).abs() / 100
        : hueGap(hct[x]!.hue, hct[p]!.hue) / 180;
    const w = kMonetGdtRuleV1SecondaryChromaWeight;
    s = maxBy(sPool, (x) => w * chroma(x) / maxChroma + (1 - w) * gap(x));
  }
  return [p, s, t];
}
