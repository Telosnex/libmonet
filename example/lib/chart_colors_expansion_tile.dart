import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:libmonet/charts/chart_colors.dart';
import 'package:libmonet/theming/monet_theme.dart';
import 'package:monet_studio/padding.dart';
import 'package:monet_studio/swatch.dart';

class ChartColorsExpansionTile extends HookWidget {
  const ChartColorsExpansionTile({
    super.key,
    required this.seed,
    required this.onColorChanged,
  });

  final Color seed;
  final ValueChanged<Color> onColorChanged;

  @override
  Widget build(BuildContext context) {
    final count = useState(8);
    final contrast = useState(0.5);
    final stableIndexes = useState(true);
    final monet = MonetTheme.of(context);
    final background = monet.primary.background;
    final chart = ChartColors.fromColorAndBackground(
      seed,
      background,
      contrast: contrast.value,
      algo: monet.algo,
      colorModel: monet.colorModel,
    );
    final categorical = chart.categorical(
      count.value,
      isColorAtIndexStable: stableIndexes.value,
    );
    final sequential = chart.sequential.discretize(13);
    final diverging = chart.divergingWith(seed).discretize(13);

    final textTheme = Theme.of(context).textTheme;
    final titleStyle = textTheme.headlineLarge!.copyWith(
      color: monet.primary.text,
    );
    final captionStyle = textTheme.bodySmall!.copyWith(
      color: monet.primary.text,
    );
    final onChartBackground = monet.primary.backgroundText;

    return ExpansionTile(
      title: Text('Chart Colors', style: titleStyle),
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: Text(
                  'Stable color per index (golden angle; adding series '
                  'never changes earlier ones)',
                  style: captionStyle,
                ),
                value: stableIndexes.value,
                onChanged: (value) => stableIndexes.value = value,
              ),
              Text('Series: ${count.value}', style: captionStyle),
              Slider(
                value: count.value.toDouble(),
                min: 1,
                max: 32,
                divisions: 31,
                label: count.value.toString(),
                onChanged: (value) => count.value = value.round(),
              ),
              Text(
                'Contrast: ${(contrast.value * 100).round()}%',
                style: captionStyle,
              ),
              Slider(
                value: contrast.value,
                min: 0.1,
                max: 1.0,
                divisions: 18,
                label: '${(contrast.value * 100).round()}%',
                onChanged: (value) => contrast.value = value,
              ),
              Text(
                'Hues spread evenly in u\u2032v\u2032 from the seed; tones '
                'cycle the visible band so adjacent series always differ in '
                'tone, which survives color vision deficiencies. At high '
                'counts, identification is the job of labels and shapes.',
                style: captionStyle,
              ),
              const VerticalPadding(),
              Container(
                width: double.infinity,
                color: background,
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Categorical',
                      style: textTheme.titleMedium!.copyWith(
                        color: onChartBackground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (var i = 0; i < categorical.length; i++)
                          GestureDetector(
                            onTap: () => onColorChanged(categorical[i]),
                            child: SizedBox.square(
                              dimension: 48,
                              child: Swatch(
                                color: categorical[i],
                                tooltip: 'series ${i + 1}; tap to use as seed',
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sequential \u00b7 low \u2192 high',
                      style: textTheme.titleMedium!.copyWith(
                        color: onChartBackground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _Ramp(colors: sequential, midpointIndex: null),
                    const SizedBox(height: 16),
                    Text(
                      'Diverging \u00b7 seed \u2190 neutral \u2192 '
                      'afterimage complement',
                      style: textTheme.titleMedium!.copyWith(
                        color: onChartBackground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _Ramp(colors: diverging, midpointIndex: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Ramp extends StatelessWidget {
  const _Ramp({required this.colors, required this.midpointIndex});

  final List<Color> colors;
  final int? midpointIndex;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < colors.length; i++)
            Expanded(
              child: Container(
                decoration: midpointIndex == i
                    ? BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                          width: 2,
                        ),
                      )
                    : null,
                child: Swatch(
                  color: colors[i],
                  tooltip: midpointIndex == i
                      ? 't = ${(i / (colors.length - 1)).toStringAsFixed(2)}; '
                          'semantic midpoint'
                      : 't = ${(i / (colors.length - 1)).toStringAsFixed(2)}',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
