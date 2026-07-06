import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:libmonet/colorspaces/hct.dart';
import 'package:libmonet/core/argb_srgb_xyz_lab.dart';
import 'package:libmonet/effects/afterimage.dart';
import 'package:libmonet/effects/uv_harmony.dart';
import 'package:libmonet/theming/monet_theme.dart';
import 'package:monet_studio/padding.dart';
import 'package:monet_studio/swatch.dart';

/// Demo of u'v' harmony: the seed color plus N companions whose chromatic
/// directions are evenly spaced around white, and a visual proof that the
/// set optically mixes to neutral gray.
class HarmonyExpansionTile extends HookWidget {
  const HarmonyExpansionTile({
    super.key,
    required this.color,
    required this.onColorChanged,
  });

  final Color color;
  final ValueChanged<Color> onColorChanged;

  @override
  Widget build(BuildContext context) {
    final companions = useState(1);
    final balanced = useState(false);

    final seed = Hct.fromColor(color);
    final set = harmony(seed, companions.value + 1, balanced: balanced.value);
    final argbs = [for (final c in set) c.toInt()];
    final fractions = _mixFractions(argbs);
    final mixArgb = _additiveMix(argbs, fractions);
    final grayArgb = argbFromLstar(lstarFromArgb(mixArgb));

    final theme = MonetTheme.of(context);
    final captionStyle = Theme.of(context)
        .textTheme
        .bodySmall!
        .copyWith(color: theme.primary.text);

    return ExpansionTile(
      title: Text(
        'Harmony',
        style: Theme.of(context)
            .textTheme
            .headlineLarge!
            .copyWith(color: theme.primary.text),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<int>(
                      segments: [
                        for (var n = 1; n <= 5; n++)
                          ButtonSegment(
                            value: n,
                            label: Text(switch (n) {
                              1 => '+1 complement',
                              2 => '+2 triad',
                              3 => '+3 quad',
                              _ => '+$n',
                            }),
                          ),
                      ],
                      selected: {companions.value},
                      onSelectionChanged: (selection) {
                        companions.value = selection.first;
                      },
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                title: Text('Balanced', style: captionStyle),
                subtitle: Text(
                  'Cap every color at the weakest direction\u2019s strength',
                  style: captionStyle,
                ),
                value: balanced.value,
                onChanged: (value) {
                  balanced.value = value;
                },
              ),
              const VerticalPadding(),
              SizedBox(
                height: 72,
                child: Row(
                  children: [
                    for (var i = 0; i < set.length; i++)
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            onColorChanged(Color(argbs[i]));
                          },
                          child: Container(
                            decoration: i == 0
                                ? BoxDecoration(
                                    border: Border.all(
                                      color: theme.primary.text,
                                      width: 2,
                                    ),
                                  )
                                : null,
                            child: Swatch(
                              color: Color(argbs[i]),
                              tooltip: i == 0
                                  ? 'seed'
                                  : 'mix ${(fractions[i] * 100).round()}%',
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text('Tap a color to make it the seed.', style: captionStyle),
              const VerticalPadding(),
              Text('These colors mix to gray:', style: captionStyle),
              const SizedBox(height: 4),
              SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRect(
                        child: CustomPaint(
                          painter: _DitherPainter(argbs, fractions),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Swatch(
                        color: Color(grayArgb),
                        tooltip: 'neutral gray, same luminance',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Left: the colors above, interleaved at their mix '
                'percentages. Right: neutral gray. Step back or squint '
                '\u2014 they match.',
                style: captionStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Mixing fractions (area weights) so the set's additive mixture is neutral:
/// the u'v' mixture weight of color i is f_i * Y_i / v'_i, and evenly spaced
/// unit directions cancel, so f_i \u221d v'_i / (Y_i * s_i) where s_i is the
/// color's uvChroma.
List<double> _mixFractions(List<int> argbs) {
  final raw = <double>[];
  for (final argb in argbs) {
    final p = uvOfArgb(argb);
    final y = yFromLstar(lstarFromArgb(argb));
    if (p == null || y < 1e-4) {
      raw.add(1.0);
      continue;
    }
    final s = Hct.fromInt(argb).uvChroma;
    raw.add(s < 1e-6 ? 1.0 : p.$2 / (y * s));
  }
  final total = raw.fold(0.0, (a, b) => a + b);
  return [for (final r in raw) r / total];
}

/// Additive mixture of the colors at the given fractions, in linear RGB.
int _additiveMix(List<int> argbs, List<double> fractions) {
  var r = 0.0, g = 0.0, b = 0.0;
  for (var i = 0; i < argbs.length; i++) {
    r += fractions[i] * linear(redFromArgb(argbs[i]));
    g += fractions[i] * linear(greenFromArgb(argbs[i]));
    b += fractions[i] * linear(blueFromArgb(argbs[i]));
  }
  return argbFromRgb(delinear(r), delinear(g), delinear(b));
}

/// A grid of small squares of the set's colors, apportioned by the mixing
/// fractions and scattered with a low-discrepancy (R2) sequence so no
/// stripes form: the mosaic optically fuses toward gray at a distance.
class _DitherPainter extends CustomPainter {
  _DitherPainter(this.argbs, this.fractions);

  final List<int> argbs;
  final List<double> fractions;

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 6.0;
    final paint = Paint();
    final cols = (size.width / cell).ceil();
    final rows = (size.height / cell).ceil();
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        // R2 low-discrepancy point for this cell, in [0, 1).
        final t = (col * 0.7548776662466927 + row * 0.5698402909980532) % 1.0;
        var i = 0;
        var cumulative = fractions[0];
        while (t > cumulative && i < argbs.length - 1) {
          i++;
          cumulative += fractions[i];
        }
        paint.color = Color(argbs[i]);
        canvas.drawRect(
          Rect.fromLTWH(col * cell, row * cell, cell, cell),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DitherPainter oldDelegate) =>
      oldDelegate.argbs != argbs || oldDelegate.fractions != fractions;
}
