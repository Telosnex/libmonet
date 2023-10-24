import 'package:flutter/material.dart';
import 'package:libmonet/contrast.dart';
import 'package:libmonet/full_color_scheme.dart';
import 'package:libmonet/hct.dart';
import 'package:libmonet/safe_colors.dart';
import 'package:libmonet/temperature.dart';
import 'package:libmonet/theming/button_style.dart';

class MonetTheme extends StatelessWidget {
  final SafeColors primarySafeColors;
  final SafeColors secondarySafeColors;
  final SafeColors tertiarySafeColors;

  final double surfaceLstar;
  final double contrast;
  final Algo algo;

  final Brightness brightness;
  final Widget child;

  factory MonetTheme.fromColor({
    required Color color,
    required double surfaceLstar,
    required Brightness brightness,
    double contrast = 0.5,
    Algo algo = Algo.apca,
    required Widget child,
  }) {
    final temperatureCache = TemperatureCache(Hct.fromColor(color));
    final complement = temperatureCache.complement;
    final analogous = temperatureCache.analogous()[1];
    return MonetTheme.fromColors(
      brightness: brightness,
      surfaceLstar: surfaceLstar,
      primary: color,
      secondary: analogous.color,
      tertiary: complement.color,
      contrast: contrast,
      algo: algo,
      child: child,
    );
  }
  
  factory MonetTheme.fromColors({
    required Brightness brightness,
    required double surfaceLstar,
    required Color primary,
    required Color secondary,
    required Color tertiary,
    double contrast = 0.5,
    Algo algo = Algo.apca,
    required Widget child,
  }) {
    final primarySafeColors = SafeColors.from(primary,
        backgroundLstar: surfaceLstar, contrast: contrast, algo: algo);
    final secondarySafeColors = SafeColors.from(secondary,
        backgroundLstar: surfaceLstar, contrast: contrast, algo: algo);
    final tertiarySafeColors = SafeColors.from(tertiary,
        backgroundLstar: surfaceLstar, contrast: contrast, algo: algo);
    return MonetTheme(
      brightness: brightness,
      primarySafeColors: primarySafeColors,
      secondarySafeColors: secondarySafeColors,
      tertiarySafeColors: tertiarySafeColors,
      surfaceLstar: surfaceLstar,
      algo: algo,
      contrast: contrast,
      child: child,
    );
  }

  const MonetTheme({
    super.key,
    required this.brightness,
    required this.primarySafeColors,
    required this.secondarySafeColors,
    required this.tertiarySafeColors,
    required this.surfaceLstar,
    this.contrast = 0.5,
    this.algo = Algo.apca,
    required this.child,
  });

  static MonetTheme of(BuildContext context) {
    final _MonetInheritedTheme? inheritedTheme =
        context.dependOnInheritedWidgetOfExactType<_MonetInheritedTheme>();
    return inheritedTheme!.theme;
    // final MaterialLocalizations? localizations = Localizations.of<MaterialLocalizations>(context, MaterialLocalizations);
    // final ScriptCategory category = localizations?.scriptCategory ?? ScriptCategory.englishLike;
    // final ThemeData theme = inheritedTheme?.theme.data ?? ThemeData.fallback();
    // return ThemeData.localize(theme, theme.typography.geometryThemeFor(category));
  }

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context).copyWith(
      brightness: brightness,
      colorScheme: _monetColorScheme(
        brightness,
        primarySafeColors,
        secondarySafeColors,
        tertiarySafeColors,
        contrast,
        algo,
        Hct.from(0, 0, surfaceLstar).color,
      ),
      extensions: [
        MonetColorScheme.fromSafeColors(
          primary: primarySafeColors,
          secondary: secondarySafeColors,
          tertiary: tertiarySafeColors,
        ),
      ],
      // BEGIN ALL THE ACCOUTREMENTS
      appBarTheme: appBarTheme(),
      elevatedButtonTheme: elevatedButtonTheme(),
      filledButtonTheme: filledButtonTheme(),
      outlinedButtonTheme: outlinedButtonTheme(),
      textButtonTheme: textButtonTheme(),
    );

    return _MonetInheritedTheme(
      theme: this,
      child: Theme(
        data: themeData,
        child: child,
      ),
    );
  }

  AppBarTheme appBarTheme() {
    return AppBarTheme(
      backgroundColor: primarySafeColors.color,
      foregroundColor: primarySafeColors.colorText,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    );
  }

  ElevatedButtonThemeData elevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: elevatedButtonStyleFromColors(primarySafeColors),
    );
  }

  FilledButtonThemeData filledButtonTheme() {
    return FilledButtonThemeData(
      style: filledButtonStyleFromColors(primarySafeColors),
    );
  }

  OutlinedButtonThemeData outlinedButtonTheme() {
    return OutlinedButtonThemeData(
      style: outlinedButtonStyleFromColors(primarySafeColors),
    );
  }

  TextButtonThemeData textButtonTheme() {
    return TextButtonThemeData(
      style: textButtonStyleFromColors(primarySafeColors),
    );
  }
}

class _MonetInheritedTheme extends InheritedTheme {
  const _MonetInheritedTheme({
    required this.theme,
    required super.child,
  });

  final MonetTheme theme;

  @override
  Widget wrap(BuildContext context, Widget child) {
    return MonetTheme(
      brightness: theme.brightness,
      primarySafeColors: theme.primarySafeColors,
      secondarySafeColors: theme.secondarySafeColors,
      tertiarySafeColors: theme.tertiarySafeColors,
      surfaceLstar: theme.surfaceLstar,
      contrast: theme.contrast,
      algo: theme.algo,
      child: child,
    );
  }

  @override
  bool updateShouldNotify(_MonetInheritedTheme old) => theme != old.theme;
}

ColorScheme _monetColorScheme(
  Brightness brightness,
  SafeColors primary,
  SafeColors secondary,
  SafeColors tertiary,
  double contrast,
  Algo algo,
  Color surface,
) {
  final surfaceHct = Hct.fromColor(surface);

  final error = SafeColors.from(
    Colors.red,
    backgroundLstar: surfaceHct.tone,
    contrast: contrast,
  );

  final onSurface = Hct.colorFrom(
    surfaceHct.hue,
    surfaceHct.chroma,
    contrastingLstar(
      withLstar: surfaceHct.tone,
      usage: Usage.text,
      contrast: contrast,
    ),
  );
  return ColorScheme(
    brightness: brightness,
    primary: primary.fill,
    onPrimary: primary.fillText,
    primaryContainer: primary.color,
    onPrimaryContainer: primary.colorText,
    secondary: secondary.fill,
    onSecondary: secondary.fillText,
    secondaryContainer: secondary.color,
    onSecondaryContainer: secondary.colorText,
    tertiary: tertiary.fill,
    onTertiary: tertiary.fillText,
    tertiaryContainer: tertiary.color,
    onTertiaryContainer: tertiary.colorText,
    error: error.color,
    onError: error.colorText,
    background: surface,
    onBackground: onSurface,
    surface: surface,
    onSurface: onSurface,
    surfaceTint: Colors.transparent,
  );
}
