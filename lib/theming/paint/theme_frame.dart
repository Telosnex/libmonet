import 'package:material_ui/material_ui.dart';
import 'package:libmonet/theming/monet_theme_data.dart';

/// Immutable theme view, including at rest so getters can discover demand.
/// Each palette/recipe has shared progress, but can retarget separately; there
/// is no universal theme-wide `t`. Compare [target] to logical
/// endpoints; view identity/equality is not endpoint equality.
/// [isAnimating] describes the theme transition, not custom binding-only motion.
class MonetThemeFrame extends MonetThemeData {
  MonetThemeFrame({
    required this.target,
    required this.materialAnchor,
    required this.animateThemeData,
    this.isAnimating = true,
    required super.primary,
    required super.secondary,
    required super.tertiary,
    required super.backgroundTone,
    required super.contrast,
    required super.scale,
  }) : super(
         brightness: materialAnchor.brightness,
         algo: materialAnchor.algo,
         colorModel: target.colorModel,
         typography: materialAnchor.typography,
         shapeTheme: materialAnchor.shapeTheme,
       );

  @override
  final MonetThemeData target;
  final MonetThemeData materialAnchor;
  final bool animateThemeData;
  @override
  bool operator ==(Object other) =>
      super == other &&
      other is MonetThemeFrame &&
      target == other.target &&
      materialAnchor == other.materialAnchor &&
      animateThemeData == other.animateThemeData &&
      isAnimating == other.isAnimating;
  @override
  int get hashCode => Object.hash(
    super.hashCode,
    target,
    materialAnchor,
    animateThemeData,
    isAnimating,
  );

  @override
  final bool isAnimating;
  @override
  ThemeData createThemeData(BuildContext context) => animateThemeData
      ? super.createThemeData(context)
      : materialAnchor.createThemeData(context);
}
