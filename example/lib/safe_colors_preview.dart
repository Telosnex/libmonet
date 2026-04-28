import 'package:flutter/material.dart';
import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/core/hex_codes.dart';
import 'package:libmonet/effects/opacity.dart';
import 'package:libmonet/effects/shadows.dart';
import 'package:libmonet/theming/button_style.dart';
import 'package:libmonet/theming/monet_theme.dart';
import 'package:libmonet/theming/monet_theme_data.dart';
import 'package:libmonet/theming/palette.dart';
import 'package:monet_studio/padding.dart';

class SafeColorsPreview extends StatelessWidget {
  const SafeColorsPreview({
    required this.themeDataByModel,
    super.key,
    this.scrim,
    this.shadows,
  });

  final Map<ColorModel, MonetThemeData> themeDataByModel;
  final OpacityResult? scrim;
  final ShadowResult? shadows;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final model in ColorModel.values)
          _ColorModelPreview(
            themeData: themeDataByModel[model]!,
            colorModel: model,
            scrim: scrim,
            shadows: shadows,
          ),
      ],
    );
  }
}

class _ColorModelPreview extends StatelessWidget {
  const _ColorModelPreview({
    required this.themeData,
    required this.colorModel,
    this.scrim,
    this.shadows,
  });

  final MonetThemeData themeData;
  final ColorModel colorModel;
  final OpacityResult? scrim;
  final ShadowResult? shadows;

  @override
  Widget build(BuildContext context) {
    final activeTheme = MonetTheme.of(context);

    return MonetTheme(
      monetThemeData: themeData,
      child: Builder(builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              colorModel.label,
              style: Theme.of(context).textTheme.titleSmall!.copyWith(
                    color: activeTheme.primary.text,
                  ),
            ),
            const SizedBox(height: 4),
            _RolePreview(
              name: 'Primary',
              sourceColor: themeData.primary.color,
              palette: themeData.primary,
              scrim: scrim,
              shadows: shadows,
            ),
            _RolePreview(
              name: 'Secondary',
              sourceColor: themeData.secondary.color,
              palette: themeData.secondary,
              scrim: scrim,
              shadows: shadows,
            ),
            _RolePreview(
              name: 'Tertiary',
              sourceColor: themeData.tertiary.color,
              palette: themeData.tertiary,
              scrim: scrim,
              shadows: shadows,
            ),
          ],
        );
      }),
    );
  }
}

class _RolePreview extends StatelessWidget {
  const _RolePreview({
    required this.name,
    required this.sourceColor,
    required this.palette,
    this.scrim,
    this.shadows,
  });

  final String name;
  final Color sourceColor;
  final Palette palette;
  final OpacityResult? scrim;
  final ShadowResult? shadows;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SourceColorSwatch(name: name, color: sourceColor),
        const SizedBox(height: 4),
        PalettePreviewRow(
          palette: palette,
          scrim: scrim,
          shadows: shadows,
        ),
      ],
    );
  }
}

class _SourceColorSwatch extends StatelessWidget {
  const _SourceColorSwatch({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$name ${hexFromColor(color)}',
      child: Container(
        width: 128,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
      ),
    );
  }
}

class PalettePreviewRow extends StatelessWidget {
  final Palette palette;
  final OpacityResult? scrim;
  final ShadowResult? shadows;

  const PalettePreviewRow({
    required this.palette,
    super.key,
    this.scrim,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return _paletteRow(context, palette);
  }

  Widget _paletteRow(BuildContext context, Palette colors) {
    final textButtonStyleBase = fillButtonStyle(palette);
    final textButtonStyle = textButtonStyleBase.copyWith(
        textStyle: WidgetStateProperty.resolveWith((states) {
      final base = textButtonStyleBase.textStyle?.resolve(states);
      if (shadows == null) {
        return base;
      }
      return base?.copyWith(
        shadows: shadows!.shadows,
      );
    }));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
            height: kMinInteractiveDimension,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton(
                    style: colorButtonStyle(colors),
                    onPressed: () {},
                    child: const Text('Color')),
                const HorizontalPadding(),
                FilledButton(
                  style: fillButtonStyle(colors),
                  onPressed: () {},
                  child: const Text('Fill'),
                ),
                const HorizontalPadding(),
                TextButton(
                  onPressed: () {},
                  style: textButtonStyle,
                  child: const Text(
                    'Text',
                  ),
                ),
              ],
            ))
      ],
    );
  }
}
