import 'package:flutter_test/flutter_test.dart';
import 'package:monet_ui/colorspaces/hct.dart';
import 'package:monet_ui/core/argb_srgb_xyz_lab.dart';
import 'package:monet_ui/extract/quantizer_result.dart';
import 'package:monet_ui/extract/monet_gdt_rule_2026_10_30.dart';

QuantizerResult q(Map<int, int> argbToCount) =>
    QuantizerResult(argbToCount, lstarToCount: const {});

int hct(double h, double c, double t) => Hct.from(h, c, t).toInt();

String hex(int argb) =>
    '#${(argb & 0xffffff).toRadixString(16).padLeft(6, '0')}';

void main() {
  test('a large gray never beats a noticeable colorful option', () {
    final gray = hct(0, 2, 60), beige = hct(80, 10, 75);
    final red = hct(25, 60, 50), blue = hct(260, 40, 40);
    final teal = hct(190, 30, 60);
    final t = MonetGdtRule20261030.score(
      q({gray: 600, beige: 300, red: 40, blue: 30, teal: 30}),
    ).triad;
    expect(t.map((o) => o.chroma >= 16), everyElement(isTrue));
  });

  test('primary is the most color, not the largest area', () {
    final dull = hct(60, 18, 60), vivid = hct(10, 80, 50);
    final t = MonetGdtRule20261030.score(
      q({dull: 800, vivid: 150, hct(0, 0, 20): 50}),
    ).triad;
    expect(hex(t[0].argb), hex(vivid));
  });

  test('tertiary is the big jump with most color, secondary the ~25 step', () {
    final p = hct(30, 70, 50), near = hct(55, 50, 55);
    final mid = hct(100, 50, 60), opp = hct(210, 50, 50);
    final t = MonetGdtRule20261030.score(
      q({p: 500, near: 150, mid: 60, opp: 240, hct(0, 0, 90): 50}),
    ).triad;
    expect(hex(t[0].argb), hex(p));
    expect(hex(t[1].argb), hex(near));
    expect(hex(t[2].argb), hex(opp));
  });

  test('all gray: picked by lightness spread, three distinct', () {
    final t = MonetGdtRule20261030.score(
      q({
        hct(0, 0, 50): 500,
        hct(0, 0, 55): 200,
        hct(0, 0, 10): 150,
        hct(0, 0, 95): 150,
      }),
    ).triad;
    expect(t.length, 3);
    final tones = t.map((o) => o.tone.round()).toSet();
    expect(tones.length, 3);
    expect(tones.contains(10) && tones.contains(95), isTrue);
  });

  test('every returned color is one of the options', () {
    final r = MonetGdtRule20261030.score(
      q({
        for (var i = 0; i < 32; i++)
          hct(i * 11.0, 5.0 + i * 2, 30.0 + i): 10 + i,
      }),
    );
    final opts = r.options.map((o) => o.argb).toSet();
    expect(r.triad.length, 3);
    expect(r.triad.every((o) => opts.contains(o.argb)), isTrue);
    expect(r.options.length, lessThanOrEqualTo(12));
    for (var i = 0; i < r.triad.length; i++) {
      for (var j = i + 1; j < r.triad.length; j++) {
        expect(r.triad[i].argb, isNot(r.triad[j].argb));
      }
    }
  });

  test('a dark red reads as colorful; a beige does not', () {
    expect(monetGdtRule20261030IsColorful(Hct.from(25, 16, 21)), isTrue);
    expect(
      monetGdtRule20261030IsColorful(Hct.from(80, 10, 75)),
      isFalse,
    ); // #cbb697
  });

  test('a big dull group with a vivid speck is not noticeably colorful', () {
    // The vivid member is 0.4% of the image, inside a 40% beige group.
    final beige = hct(70, 6, 75), vivid = hct(70, 9, 72);
    final speck = hct(30, 70, 55);
    final r = MonetGdtRule20261030.mergeOptions(
      [
        (beige, 0.396),
        (speck, 0.004),
        (vivid, 0.2),
        (hct(250, 40, 30), 0.2),
        (hct(140, 40, 50), 0.2),
      ],
      minDeltaE: 200,
      maxOptions: 4,
    );
    final o = r.firstWhere((o) => o.share > 0.39);
    expect(o.colorfulShare, lessThan(0.01));
  });

  test('a different hue beats another shade of primary', () {
    final orange = hct(55, 70, 60), orange2 = hct(60, 60, 45);
    final orange3 = hct(50, 50, 75), navy = hct(265, 12, 20);
    final t = MonetGdtRule20261030.score(
      q({orange: 400, orange2: 300, orange3: 200, navy: 100}),
    ).triad;
    expect(t.map((o) => hex(o.argb)), contains(hex(navy)));
  });

  test('a lavender reads as colorful', () {
    expect(monetGdtRule20261030IsColorful(Hct.from(300, 23, 50)), isTrue);
  });

  test('tertiary: a big vivid jump beats a tiny more-opposite speck', () {
    final blue = hct(265, 45, 35), purple = hct(300, 25, 30);
    final red = hct(20, 45, 50), speck = hct(85, 30, 75);
    final t = MonetGdtRule20261030.score(
      q({blue: 320, purple: 400, red: 100, speck: 15, hct(0, 0, 10): 165}),
    ).triad;
    expect(t.map((o) => hex(o.argb)), contains(hex(red)));
    expect(t.map((o) => hex(o.argb)), isNot(contains(hex(speck))));
  });

  test('one hue: fill adds a light and a dark, not more shades', () {
    final b1 = hct(257, 20, 45), b2 = hct(254, 20, 54), b3 = hct(253, 13, 49);
    final snow = hct(244, 6, 80), dark = hct(330, 1, 11);
    final t = MonetGdtRule20261030.score(
      q({b1: 450, b2: 120, b3: 30, snow: 200, dark: 200}),
    ).triad;
    expect(hex(t[0].argb), hex(b1));
    expect(t.map((o) => hex(o.argb)).toSet(), {hex(b1), hex(snow), hex(dark)});
  });

  test('tertiary is the larger step even when filled', () {
    // Primary orange; a red accent (big hue step) and a filled gray.
    final orange = hct(60, 40, 60), red = hct(10, 40, 35);
    final t = MonetGdtRule20261030.score(
      q({orange: 300, red: 100, hct(0, 0, 55): 500}),
    ).triad;
    final p = t[0];
    double step(MonetGdtRule20261030Option o) => p.deltaE(o);
    expect(step(t[1]), lessThanOrEqualTo(step(t[2])));
  });

  test('differenceDegrees is symmetric across 0', () {
    expect(differenceDegrees(350, 10), closeTo(20, 1e-9));
  });
}
