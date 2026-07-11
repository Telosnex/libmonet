// Probe: is the "winner list" (pixels that ever win 'worst pixel' at any
// opacity 0..255, black or white scrim) small — and does solving with only
// winners exactly match solving with every pixel?
// Run: dart tool/probe_winner_list.dart
import 'dart:math';

final rng = Random(42);

double lin(double c) {
  final s = c / 255;
  return s <= 0.04045 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4).toDouble();
}

double wcagY(List<double> p) =>
    0.2126 * lin(p[0]) + 0.7152 * lin(p[1]) + 0.0722 * lin(p[2]);
double apcaY(List<double> p) =>
    0.2126729 * pow(p[0] / 255, 2.4) +
    0.7151522 * pow(p[1] / 255, 2.4) +
    0.0721750 * pow(p[2] / 255, 2.4);

double wcagC(double yt, double yb) =>
    (max(yt, yb) + 0.05) / (min(yt, yb) + 0.05);

double _sc(double y) => y < 0.022 ? y + pow(0.022 - y, 1.414) : y;
double apcaC(double yt0, double yb0) {
  final yt = _sc(yt0), yb = _sc(yb0);
  if ((yb - yt).abs() < 0.0005) return 0;
  if (yb > yt) {
    final s = (pow(yb, 0.56) - pow(yt, 0.57)) * 1.14;
    return s < 0.1 ? 0 : (s - 0.027) * 100;
  }
  final s = (pow(yb, 0.65) - pow(yt, 0.62)) * 1.14;
  return s > -0.1 ? 0 : (s + 0.027).abs() * 100;
}

class Algo {
  final double Function(List<double>) yOf;
  final double Function(double, double) c;
  final List<double> targets;
  Algo(this.yOf, this.c, this.targets);
}

final algos = [
  Algo(wcagY, wcagC, [3, 4.5, 7]),
  Algo(apcaY, (yt, yb) => apcaC(yt, yb).abs(), [45, 60, 75]),
];

List<double> blend(List<double> p, double h, double a) =>
    [for (var i = 0; i < 3; i++) (1 - a) * p[i] + a * h];

// Forbidden band of background luminance for text yt at target t.
List<double>? band(Algo algo, double yt, double t) {
  const n = 2048;
  double? lo, hi;
  for (var i = 0; i <= n; i++) {
    final y = i / n;
    if (algo.c(yt, y) < t) {
      lo ??= y;
      hi = y;
    }
  }
  return lo == null ? null : [lo - 1 / n, hi! + 1 / n];
}

double r255() => rng.nextInt(256).toDouble();

final generators = <String, List<List<double>> Function()>{
  'uniform': () => List.generate(200, (_) => [r255(), r255(), r255()]),
  'bimodal': () {
    final c1 = [r255(), r255(), r255()], c2 = [r255(), r255(), r255()];
    return List.generate(200, (i) {
      final c = i.isEven ? c1 : c2;
      return [
        for (final v in c)
          (v + rng.nextInt(31) - 15).clamp(0, 255).toDouble()
      ];
    });
  },
  'gradient': () {
    final a = [r255(), r255(), r255()], b = [r255(), r255(), r255()];
    return List.generate(
        200, (i) => [for (var k = 0; k < 3; k++) a[k] + (b[k] - a[k]) * i / 199]);
  },
  // Anti-chain: red->green hue sweep. Every pixel is a "suspect" under
  // channel-wise comparison; the old frontier statistic is maximally bad here.
  'hueSweep': () =>
      List.generate(200, (i) => [255.0 * i / 199, 255.0 * (199 - i) / 199, 0]),
};

// Old statistic: channel-wise Pareto frontier, optional cap w/ closest-pair merge.
List<List<double>> frontier(List<List<double>> pix, int sign, int? cap) {
  bool dom(List<double> q, List<double> p) {
    for (var k = 0; k < 3; k++) {
      if (sign * q[k] < sign * p[k]) return false;
    }
    return true;
  }

  var f = <List<double>>[];
  for (final p in pix) {
    if (f.any((q) => dom(q, p))) continue;
    f = [...f.where((q) => !dom(p, q)), List.of(p)];
    if (cap != null && f.length > cap) {
      var bi = 0, bj = 1;
      var bd = double.infinity;
      for (var i = 0; i < f.length; i++) {
        for (var j = i + 1; j < f.length; j++) {
          var d = 0.0;
          for (var k = 0; k < 3; k++) {
            d += (f[i][k] - f[j][k]) * (f[i][k] - f[j][k]);
          }
          if (d < bd) {
            bd = d;
            bi = i;
            bj = j;
          }
        }
      }
      final m = [
        for (var k = 0; k < 3; k++)
          sign > 0 ? max(f[bi][k], f[bj][k]) : min(f[bi][k], f[bj][k])
      ];
      f = [
        for (var i = 0; i < f.length; i++)
          if (i != bi && i != bj) f[i],
        m
      ];
    }
  }
  return f;
}

// min alpha (grid 0..255) where [yLo,yHi] over `set` clears the band one-sided.
int? solve(Algo algo, List<List<double>> set_, double h, List<double>? bd) {
  for (var ai = 0; ai <= 255; ai++) {
    final a = ai / 255;
    var yLo = double.infinity, yHi = -double.infinity;
    for (final p in set_) {
      final y = algo.yOf(blend(p, h, a));
      yLo = min(yLo, y);
      yHi = max(yHi, y);
    }
    if (bd == null || yHi < bd[0] || yLo > bd[1]) return ai;
  }
  return null;
}

void main() {
  final winnerSizes = <String, List<int>>{};
  final frontierSizes = <String, List<int>>{};
  final cap12Err = <String, List<int>>{};
  const caps = [12, 16, 24, 32, 48];
  var mismatches = 0, trials = 0;

  for (var t = 0; t < 2000; t++) {
    final gname = generators.keys.elementAt(t % 4);
    final pix = generators[gname]!();
    final algo = algos[t % 2];
    final text = [
      [255.0, 255.0, 255.0],
      [0.0, 0.0, 0.0],
      [r255(), r255(), r255()]
    ][t % 3];
    final yt = algo.yOf(text);
    final h = yt > 0.3 ? 0.0 : 255.0; // black or white scrim
    final target = algo.targets[rng.nextInt(3)];
    if (algo.c(yt, algo.yOf([h, h, h])) < target) continue;
    trials++;
    final bd = band(algo, yt, target);

    // Winner list: pixels that ever win worst-light or worst-dark at any
    // grid alpha, for BOTH scrim colors (statistic must not know the text).
    final winners = <int>{};
    for (final hh in [0.0, 255.0]) {
      for (var ai = 0; ai <= 255; ai++) {
        final a = ai / 255;
        var loI = 0, hiI = 0;
        var loY = double.infinity, hiY = -double.infinity;
        for (var i = 0; i < pix.length; i++) {
          final y = algo.yOf(blend(pix[i], hh, a));
          if (y < loY) { loY = y; loI = i; }
          if (y > hiY) { hiY = y; hiI = i; }
        }
        winners..add(loI)..add(hiI);
      }
    }
    winnerSizes.putIfAbsent(gname, () => []).add(winners.length);

    final fHi = frontier(pix, 1, null), fLo = frontier(pix, -1, null);
    frontierSizes
        .putIfAbsent(gname, () => [])
        .add(max(fHi.length, fLo.length));

    final aAll = solve(algo, pix, h, bd);
    final aWin = solve(algo, [for (final i in winners) pix[i]], h, bd);
    if (aAll != aWin) mismatches++;

    for (final k in caps) {
      final aK = solve(
          algo, [...frontier(pix, 1, k), ...frontier(pix, -1, k)], h, bd);
      if (aAll != null && aK != null) {
        cap12Err.putIfAbsent('$gname/$k', () => []).add(aK - aAll);
      }
    }
  }

  num q(List<int> v, double f) {
    final s = [...v]..sort();
    return s[(f * (s.length - 1)).floor()];
  }

  print('trials=$trials  winner-list solver vs all-pixel solver mismatches: '
      '$mismatches (must be 0)\n');
  print('winner-list size [med/p99/max] | suspect-list size [med/max]');
  for (final g in generators.keys) {
    final w = winnerSizes[g]!, fr = frontierSizes[g]!;
    print('  ${g.padRight(9)} winners: ${q(w, .5)}/${q(w, .99)}/${w.reduce(max)}'
        '   suspects: ${q(fr, .5)}/${fr.reduce(max)}');
  }
  print('\nerror in 1/255 opacity steps vs exact, by shortlist size K '
      '[med/p99/max]:');
  for (final k in caps) {
    final row = StringBuffer('  K=${k.toString().padRight(3)}');
    for (final g in generators.keys) {
      final e = cap12Err['$g/$k']!;
      row.write('  $g ${q(e, .5)}/${q(e, .99)}/${e.reduce(max)}');
    }
    print(row);
  }
}
