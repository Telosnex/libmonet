import 'package:androidx_graphics_shapes/material_shapes.dart';
import 'package:flutter/material.dart';
import 'package:libmonet/shapes/expressive_button.dart';
import 'package:libmonet/theming/monet_clip.dart';
import 'package:libmonet/theming/monet_theme.dart';

enum _ButtonContent { shortText, lotsOfText, largeIcon, smallIcon }

/// Per-widget shape overrides: the app's ordinary surfaces stay unchanged.
class ExpressiveShapesExpansionTile extends StatefulWidget {
  const ExpressiveShapesExpansionTile({super.key});

  @override
  State<ExpressiveShapesExpansionTile> createState() =>
      _ExpressiveShapesExpansionTileState();
}

class _ExpressiveShapesExpansionTileState
    extends State<ExpressiveShapesExpansionTile>
    with SingleTickerProviderStateMixin {
  String _fromLabel = MaterialExpressiveShape.cookie7Sided.label;
  MaterialExpressiveShape _selected = MaterialExpressiveShape.cookie7Sided;
  late ExpressiveShapeGeometry _geometry;
  late final AnimationController _progress;
  _ButtonContent _content = _ButtonContent.smallIcon;
  bool _stretch = false;
  double _padding = 24;
  int _presses = 0;

  @override
  void initState() {
    super.initState();
    _geometry = ExpressiveShapeGeometry(to: _selected);
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      value: 1,
    )..addListener(_updateProgress);
  }

  void _updateProgress() => setState(() {});

  void _selectShape(MaterialExpressiveShape target) {
    if (target == _selected) return;
    final progress = _progress.value;
    _progress.stop();
    setState(() {
      _fromLabel = progress == 1 ? _selected.label : 'Current outline';
      _geometry = _geometry.retarget(target, progress: progress);
      _selected = target;
    });
    _progress.forward(from: 0);
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Widget _buttonContent() => switch (_content) {
        _ButtonContent.shortText => const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Save changes',
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
            ),
          ),
        _ButtonContent.lotsOfText => const Text(
            'Save all of my changes and continue to the next step. '
            'This deliberately long button label wraps onto several lines '
            'so we can check whether the border leaves enough room for content.',
            textAlign: TextAlign.center,
          ),
        _ButtonContent.largeIcon => const Icon(Icons.favorite, size: 64),
        _ButtonContent.smallIcon => const Icon(Icons.favorite, size: 18),
      };

  @override
  Widget build(BuildContext context) {
    final colors = MonetTheme.of(context).primary;
    final shape =
        _geometry.border(progress: _progress.value, stretch: _stretch);
    return ExpansionTile(
      title: const Text('Material 3 Expressive shapes'),
      childrenPadding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Select a shape in the catalog to morph from the previous selection. '
          'Select again mid-animation to redirect from the current outline. Buttons, ink, '
          'shadow, and MonetClip share the same animated border. '
          'App-wide corners stay unchanged.',
        ),
        const SizedBox(height: 16),
        Text('Morph: $_fromLabel → ${_selected.label}'),
        Text('Progress: ${(_progress.value * 100).round()}%'),
        Slider(
          key: const ValueKey('expressive-morph-progress'),
          value: _progress.value,
          label: '${(_progress.value * 100).round()}%',
          onChanged: (value) {
            _progress.stop();
            _progress.value = value;
          },
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(
              onPressed: () => _progress.forward(from: 0),
              child: const Text('Replay morph'),
            ),
            TextButton(
              onPressed: () => _progress.reverse(from: 1),
              child: const Text('Reverse morph'),
            ),
            TextButton(
              onPressed: () => _progress.stop(),
              child: const Text('Pause morph'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Button border playground'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in const {
              _ButtonContent.shortText: 'Short text',
              _ButtonContent.lotsOfText: 'Lots of text',
              _ButtonContent.largeIcon: 'Large icon',
              _ButtonContent.smallIcon: 'Small icon',
            }.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: _content == entry.key,
                onSelected: (_) => setState(() => _content = entry.key),
              ),
          ],
        ),
        SwitchListTile(
          title: const Text('Stretch shape to button bounds'),
          subtitle: const Text('Off preserves the silhouette’s proportions.'),
          value: _stretch,
          onChanged: (value) => setState(() => _stretch = value),
        ),
        Text('Content padding: ${_padding.round()} px'),
        Slider(
          key: const ValueKey('expressive-content-padding'),
          value: _padding,
          max: 64,
          divisions: 16,
          label: '${_padding.round()} px',
          onChanged: (value) => setState(() => _padding = value),
        ),
        const Text(
          'Precomputed safe interiors size these real Flutter buttons (up to '
          '280 px wide). Settled shapes fit; an interrupted outline may clip. Text wraps first; if space is still '
          'insufficient, this demo explicitly scales content down. Stretching '
          'allows long labels to use more vertical space without shrinking.',
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth.clamp(0.0, 280.0);
          return Wrap(
            spacing: 24,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              for (final kind in ['Filled', 'Outlined', 'Elevated'])
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: width),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(kind),
                      const SizedBox(height: 8),
                      ExpressiveButton(
                        geometry: _geometry,
                        progress: _progress.value,
                        stretch: _stretch,
                        padding: EdgeInsets.all(_padding),
                        // 2px outline with default miter limit 4, plus AA.
                        clearance: 9,
                        overflow: ExpressiveContentOverflow.scaleDown,
                        variant: switch (kind) {
                          'Filled' => ExpressiveButtonVariant.filled,
                          'Outlined' => ExpressiveButtonVariant.outlined,
                          _ => ExpressiveButtonVariant.elevated,
                        },
                        key: ValueKey('expressive-${kind.toLowerCase()}'),
                        style: kind == 'Outlined'
                            ? ButtonStyle(
                                side: WidgetStatePropertyAll(BorderSide(
                                  color: colors.backgroundText,
                                  width: 2,
                                )),
                              )
                            : null,
                        onPressed: () => setState(() => _presses++),
                        child: _buttonContent(),
                      ),
                    ],
                  ),
                ),
            ],
          );
        }),
        const SizedBox(height: 8),
        Text('Button presses: $_presses'),
        const SizedBox(height: 24),
        Wrap(
          spacing: 24,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 144,
                  child: Material(
                    animationDuration: Duration.zero,
                    shape: shape,
                    color: colors.fill,
                    elevation: 6,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      customBorder: shape,
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${_selected.label} tapped')),
                      ),
                      child: Center(
                        child: Icon(Icons.touch_app, color: colors.fillText),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Material + ink + shadow'),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MonetClip(
                  shape: shape,
                  child: SizedBox.square(
                    dimension: 144,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colors.fill, colors.background],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(Icons.auto_awesome, color: colors.fillText),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('MonetClip'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Selected: ${_selected.label}'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final item in MaterialExpressiveShape.values)
              SizedBox(
                width: 96,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: item.label,
                      isSelected: item == _selected,
                      onPressed: () => _selectShape(item),
                      style: IconButton.styleFrom(
                        fixedSize: const Size.square(64),
                        backgroundColor:
                            item == _selected ? colors.fill : colors.background,
                        foregroundColor: item == _selected
                            ? colors.fillText
                            : colors.backgroundText,
                        shape: BoundsCenteredBorder(
                          RoundedPolygonBorder(polygon: item.polygon),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      selectedIcon: const Icon(Icons.check, size: 18),
                    ),
                    Text(item.label, textAlign: TextAlign.center),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Scrub the morph to inspect intermediate shapes. Geometry morphing '
          'may temporarily clip content between endpoints. Endpoint layout '
          'uses libmonet’s reusable ExpressiveButton / ExpressiveShapeContent.',
        ),
      ],
    );
  }
}
