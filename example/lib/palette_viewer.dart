import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/colorspaces/hct.dart';
import 'package:libmonet/core/hex_codes.dart';
import 'package:libmonet/theming/monet_theme.dart';
import 'package:libmonet/theming/monet_theme_data.dart';

class PaletteViewer extends StatelessWidget {
  const PaletteViewer({super.key, required this.themeDataByModel});

  static const _tones = <double>[
    0,
    5,
    10,
    15,
    20,
    25,
    30,
    35,
    40,
    45,
    50,
    55,
    60,
    65,
    70,
    75,
    80,
    85,
    90,
    95,
    100,
  ];

  static const _rowHeight = 52.0;
  static const _seedBandHeight = 8.0;
  static const _roleGap = 12.0;
  static const _svgCellWidth = 48;
  static const _svgRowHeight = 48;
  static const _svgSeedBandHeight = 8;
  static const _svgRoleGap = 12;

  final Map<ColorModel, MonetThemeData> themeDataByModel;

  @override
  Widget build(BuildContext context) {
    final monet = MonetTheme.of(context);

    return ExpansionTile(
      title: Text(
        'Palette Viewer',
        style: Theme.of(context).textTheme.headlineLarge!.copyWith(
              color: monet.primary.text,
            ),
      ),
      subtitle: Text(
        'Primary, secondary, and tertiary tones 0-100 by 5',
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: monet.primary.text,
            ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => _copySvg(context),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy SVG'),
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final cellWidth = width / _tones.length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var modelIndex = 0;
                          modelIndex < ColorModel.values.length;
                          modelIndex++) ...[
                        _PaletteModelBlock(
                          model: ColorModel.values[modelIndex],
                          themeData:
                              themeDataByModel[ColorModel.values[modelIndex]]!,
                          tones: _tones,
                          cellWidth: cellWidth,
                        ),
                        if (modelIndex != ColorModel.values.length - 1)
                          const SizedBox(height: _roleGap),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _copySvg(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final svg = _buildSvg(themeDataByModel);

    Clipboard.setData(ClipboardData(text: svg)).then((_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Palette SVG copied')),
      );
    });
  }

  static String _buildSvg(Map<ColorModel, MonetThemeData> themeDataByModel) {
    final columns = _tones.length;
    final width = columns * _svgCellWidth;
    const rolesPerModel = 3;
    const modelHeight = rolesPerModel * (_svgSeedBandHeight + _svgRowHeight);
    final height = ColorModel.values.length * modelHeight +
        (ColorModel.values.length - 1) * _svgRoleGap;
    final svg = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<svg xmlns="http://www.w3.org/2000/svg" '
          'width="$width" height="$height" viewBox="0 0 $width $height" '
          'shape-rendering="crispEdges">');

    var y = 0;
    for (var modelIndex = 0;
        modelIndex < ColorModel.values.length;
        modelIndex++) {
      final model = ColorModel.values[modelIndex];
      final themeData = themeDataByModel[model]!;
      final roles = _roles(themeData);
      for (final role in roles) {
        final sourceHex = hexFromColor(role.color);
        final sourceHct = Hct.fromColor(role.color, model: model);

        svg.writeln('<rect x="0" y="$y" width="$width" '
            'height="$_svgSeedBandHeight" fill="$sourceHex"/>');
        y += _svgSeedBandHeight;

        for (var toneIndex = 0; toneIndex < _tones.length; toneIndex++) {
          final tone = _tones[toneIndex];
          final color = Hct.from(
            sourceHct.hue,
            sourceHct.chroma,
            tone,
            model: model,
          ).color;
          svg.writeln('<rect x="${toneIndex * _svgCellWidth}" y="$y" '
              'width="$_svgCellWidth" height="$_svgRowHeight" '
              'fill="${hexFromColor(color)}"/>');
        }

        y += _svgRowHeight;
      }

      if (modelIndex != ColorModel.values.length - 1) {
        y += _svgRoleGap;
      }
    }

    svg.writeln('</svg>');
    return svg.toString();
  }

  static List<_PaletteRole> _roles(MonetThemeData themeData) {
    return [
      _PaletteRole('Primary', themeData.primary.color),
      _PaletteRole('Secondary', themeData.secondary.color),
      _PaletteRole('Tertiary', themeData.tertiary.color),
    ];
  }
}

class _PaletteRole {
  const _PaletteRole(this.name, this.color);

  final String name;
  final Color color;
}

class _PaletteModelBlock extends StatelessWidget {
  const _PaletteModelBlock({
    required this.model,
    required this.themeData,
    required this.tones,
    required this.cellWidth,
  });

  final ColorModel model;
  final MonetThemeData themeData;
  final List<double> tones;
  final double cellWidth;

  @override
  Widget build(BuildContext context) {
    final monet = MonetTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          model.label,
          style: Theme.of(context).textTheme.titleSmall!.copyWith(
                color: monet.primary.text,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        for (final role in PaletteViewer._roles(themeData)) ...[
          _SeedBand(role: role, model: model),
          _PaletteStrip(
            role: role,
            model: model,
            tones: tones,
            cellWidth: cellWidth,
          ),
        ],
      ],
    );
  }
}

class _PaletteStrip extends StatelessWidget {
  const _PaletteStrip({
    required this.role,
    required this.model,
    required this.tones,
    required this.cellWidth,
  });

  final _PaletteRole role;
  final ColorModel model;
  final List<double> tones;
  final double cellWidth;

  @override
  Widget build(BuildContext context) {
    final sourceHct = Hct.fromColor(role.color, model: model);

    return Row(
      children: [
        for (final tone in tones)
          _ToneChip(
            color: Hct.from(
              sourceHct.hue,
              sourceHct.chroma,
              tone,
              model: model,
            ).color,
            role: role,
            sourceHct: sourceHct,
            tone: tone,
            model: model,
            width: cellWidth,
          ),
      ],
    );
  }
}

class _SeedBand extends StatelessWidget {
  const _SeedBand({required this.role, required this.model});

  final _PaletteRole role;
  final ColorModel model;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${model.label} / ${role.name} '
          '${hexFromColor(role.color)}',
      child: Container(
        width: double.infinity,
        height: PaletteViewer._seedBandHeight,
        color: role.color,
      ),
    );
  }
}

class _ToneChip extends StatelessWidget {
  const _ToneChip({
    required this.color,
    required this.role,
    required this.sourceHct,
    required this.tone,
    required this.model,
    required this.width,
  });

  final Color color;
  final _PaletteRole role;
  final Hct sourceHct;
  final double tone;
  final ColorModel model;
  final double width;

  @override
  Widget build(BuildContext context) {
    final actualHct = Hct.fromColor(color, model: model);

    return Tooltip(
      message: '${role.name} / ${model.label}\n'
          'Source ${hexFromColor(role.color)}\n'
          'Source H ${sourceHct.hue.toStringAsFixed(1)} · '
          'C ${sourceHct.chroma.toStringAsFixed(1)} · '
          'T ${sourceHct.tone.toStringAsFixed(1)}\n'
          'Requested T ${tone.toStringAsFixed(0)}\n'
          '${hexFromColor(color)}\n'
          'Actual H ${actualHct.hue.toStringAsFixed(1)} · '
          'C ${actualHct.chroma.toStringAsFixed(1)} · '
          'T ${actualHct.tone.toStringAsFixed(1)}',
      child: Container(
        width: width,
        height: PaletteViewer._rowHeight,
        color: color,
      ),
    );
  }
}
