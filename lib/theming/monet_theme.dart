import 'package:flutter/foundation.dart';
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
    final primaryColorLight = Hct.fromColor(primarySafeColors.fill).tone >
            Hct.fromColor(primarySafeColors.color).tone
        ? primarySafeColors.fill
        : primarySafeColors.color;
    final primaryColorDark = primaryColorLight == primarySafeColors.fill
        ? primarySafeColors.color
        : primarySafeColors.fill;

    final colorScheme = _monetColorScheme(
      brightness,
      primarySafeColors,
      secondarySafeColors,
      tertiarySafeColors,
      contrast,
      algo,
      Hct.from(0, 0, surfaceLstar).color,
    );
    final typographyData = typography(colorScheme);
    final textThemeData = textTheme(typographyData);
    final themeData = Theme.of(context).copyWith(
      // Hack-y, idea is, in dark mode, apply on surface (usually lighter)
      // with opacity to surface to make elevated surfaces lighter. Doesn't
      // make sense once you don't only have opacity for lightening, but color.
      applyElevationOverlayColor: false,
      // TODO: odd dance, to construct one _requires_ ThemeData
      cupertinoOverrideTheme: null,
      extensions: [
        MonetColorScheme.fromSafeColors(
          primary: primarySafeColors,
          secondary: secondarySafeColors,
          tertiary: tertiarySafeColors,
        ),
      ],
      inputDecorationTheme: inputDecorationTheme(),
      // Not sure this is used all that much, it's not affecting buttons on
      // macOS at all. Default to shrinkWrap, because the components tend to
      // be excessively large due to being designed for touch.
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      // Use default (slide on iOS/macOS, zoom on others)
      pageTransitionsTheme: const PageTransitionsTheme(),
      scrollbarTheme: scrollbarThemeData(),
      // Copy logic from ThemeData, modulo useMaterial3 always is true
      splashFactory: defaultTargetPlatform == TargetPlatform.android && !kIsWeb
          ? InkRipple.splashFactory
          : InkSparkle.splashFactory,
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      brightness: brightness,
      canvasColor: primarySafeColors.background,
      cardColor: primarySafeColors.background,
      colorScheme: colorScheme,
      dialogBackgroundColor: primarySafeColors.background,
      // TODO: do we want to set this?
      disabledColor: primarySafeColors.color,
      dividerColor: primarySafeColors.backgroundText,
      // colorHover only guarantees contrast with colorBorder
      focusColor: primarySafeColors.fillHover,
      highlightColor: primarySafeColors.fillSplash,
      hintColor: primarySafeColors.backgroundText,
      hoverColor: primarySafeColors.fillHover,
      // ThemeData uses white if primary = secondary, otherwise, secondary
      primaryColor: primarySafeColors.color,
      primaryColorDark: primaryColorDark,
      primaryColorLight: primaryColorLight,
      indicatorColor: secondarySafeColors.fill,
      scaffoldBackgroundColor: primarySafeColors.background,
      secondaryHeaderColor: secondarySafeColors.backgroundText,
      // TODO: non-sequitor, need shadow opacity too, and may need multiple
      // shadows
      shadowColor: Colors.transparent,
      splashColor: primarySafeColors.fillSplash,
      // TODO: material uses 70% white in dark mode, 54% black in light mode
      // Is transparency important? Where is this used?
      // For now, treat it like text
      unselectedWidgetColor: primarySafeColors.backgroundText,
      iconTheme: iconThemeData(),
      primaryIconTheme: iconThemeData(),
      primaryTextTheme: textThemeData,
      textTheme: textThemeData,
      typography: typographyData,
      // BEGIN ALL THE ACCOUTREMENTS
      actionIconTheme: actionIconTheme(),
      appBarTheme: appBarTheme(),
      badgeTheme: badgeThemeData(context, textThemeData),
      bannerTheme: bannerThemeData(),
      bottomAppBarTheme: bottomAppBarTheme(),
      bottomNavigationBarTheme: bottomNavigationBarThemeData(textThemeData),
      bottomSheetTheme: bottomSheetThemeData(),
      buttonBarTheme: buttonBarThemeData(),
      buttonTheme: buttonThemeData(),
      cardTheme: cardTheme(),
      checkboxTheme: checkboxThemeData(),
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

  ActionIconThemeData actionIconTheme() {
    // Provides platform default icons, just use default.
    return const ActionIconThemeData();
  }

  AppBarTheme appBarTheme() {
    return AppBarTheme(
      backgroundColor: primarySafeColors.color,
      foregroundColor: primarySafeColors.colorText,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    );
  }

  BadgeThemeData badgeThemeData(BuildContext context, TextTheme textTheme) {
    return BadgeThemeData(
      backgroundColor: primarySafeColors.fill,
      textColor: primarySafeColors.fillText,
      // defaults, see badge.dart
      smallSize: 6.0,
      largeSize: 16.0,
      textStyle: textTheme.labelSmall,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: AlignmentDirectional.topEnd,
      offset: Directionality.of(context) == TextDirection.ltr
          ? const Offset(4, -4)
          : const Offset(-4, -4),
    );
  }

  MaterialBannerThemeData bannerThemeData() {
    return MaterialBannerThemeData(
      backgroundColor: primarySafeColors.fill,
      surfaceTintColor: primarySafeColors.fill,
      shadowColor: Colors.transparent,
      dividerColor: primarySafeColors.backgroundText,
      // Copy defaults from Banner.dart
      contentTextStyle: TextStyle(
        color: primarySafeColors.fillText,
        fontSize: 10.2,
        fontWeight: FontWeight.w900,
        height: 1.0,
      ),
    );
  }

  BottomAppBarTheme bottomAppBarTheme() {
    return BottomAppBarTheme(
      color: primarySafeColors.color,
      elevation: 0,
      shape: const AutomaticNotchedShape(
          RoundedRectangleBorder()), // bottom_app_bar.dart _BottomAppBarDefaultsM3
      height: 80.0, // bottom_app_bar.dart _BottomAppBarDefaultsM3
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(
          vertical: 12.0, horizontal: 16.0), // bottom_app_bar.dart
    );
  }

  BottomNavigationBarThemeData bottomNavigationBarThemeData(
      TextTheme textTheme) {
    return BottomNavigationBarThemeData(
      backgroundColor: primarySafeColors.background,
      elevation: 0,
      selectedIconTheme: iconThemeData(),
      unselectedIconTheme:
          iconThemeData().copyWith(color: primarySafeColors.backgroundText),
      selectedLabelStyle: textTheme.bodyMedium!
          .copyWith(fontSize: 14.0, color: primarySafeColors.fill),
      unselectedLabelStyle: textTheme.bodyMedium!
          .copyWith(fontSize: 12.0, color: primarySafeColors.backgroundText),
      showSelectedLabels: true,
      showUnselectedLabels: true,

      // Don't specify: this allows the widget to switch between fixed and
      // shifting based on the number of items.
      // type: BottomNavigationBarType.fixed,

      enableFeedback: true,
      // Don't specify, allows widget to default to spread
      // landscapeLayout: BottomNavigationBarLandscapeLayout.centered,

      // Don't specify, allows widget to default to MaterialStateMouseCursor.clickable
      // mouseCursor:
    );
  }

  BottomSheetThemeData bottomSheetThemeData() {
    return BottomSheetThemeData(
      backgroundColor: primarySafeColors.background,
      elevation: 0,
      modalBackgroundColor: primarySafeColors.background,
      modalElevation: 0,
      shape: const RoundedRectangleBorder(),
      clipBehavior: Clip.none,
    );
  }

  ButtonBarThemeData buttonBarThemeData() {
    // Go with defaults, most of the properties are about padding and spacing.
    return const ButtonBarThemeData();
  }

  ButtonThemeData buttonThemeData() {
    // Go with defaults, most of the properties are about padding and spacing.
    return const ButtonThemeData();
  }

  CardTheme cardTheme() {
    return CardTheme(
      clipBehavior: Clip.none, // match default
      color: primarySafeColors.background,
      shadowColor: Colors.transparent,
      surfaceTintColor: primarySafeColors.background,
      elevation: 0,
      margin: const EdgeInsets.all(4), // match default
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4)), // match default
    );
  }

  CheckboxThemeData checkboxThemeData() {
    return CheckboxThemeData(
      mouseCursor: const MaterialStatePropertyAll(
          null), // allows widget to default to clickable
      fillColor: MaterialStateProperty.all(primarySafeColors.fill),
      checkColor: MaterialStateProperty.all(primarySafeColors.fillIcon),
      overlayColor: MaterialStateProperty.all(primarySafeColors.fillSplash),
      splashRadius: 20.0, // match M3 default
      materialTapTargetSize: null, // let Theme manage it
      visualDensity: null, // let Theme manage it
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(2.0)),
      ), // match default
      side: BorderSide(
        width: 2.0,
        color: primarySafeColors.fill,
      ), // match default
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

  InputDecorationTheme inputDecorationTheme() {
    return InputDecorationTheme(
      fillColor: primarySafeColors.color,
      filled: true,
      border: OutlineInputBorder(
        borderSide: BorderSide(width: 2, color: primarySafeColors.colorBorder),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  IconThemeData iconThemeData() {
    return IconThemeData(
      size: 24.0,
      fill: 0.0,
      weight: 400.0,
      grade: 0.0,
      opticalSize: 48.0,
      shadows: const [],
      color: primarySafeColors.colorIcon,
      opacity: 1,
    );
  }

  ScrollbarThemeData scrollbarThemeData() {
    const thickness = 8.0;
    return ScrollbarThemeData(
      thumbVisibility: const MaterialStatePropertyAll(true),
      thickness: const MaterialStatePropertyAll(thickness),
      trackVisibility: const MaterialStatePropertyAll(true),
      radius: const Radius.circular(thickness / 2.0),
      thumbColor: MaterialStatePropertyAll(primarySafeColors.backgroundText),
      trackColor: const MaterialStatePropertyAll(Colors.transparent),
      trackBorderColor: const MaterialStatePropertyAll(Colors.transparent),
      interactive: true,
    );
  }

  Typography typography(ColorScheme colorScheme) {
    return Typography.material2021(
        platform: defaultTargetPlatform, colorScheme: colorScheme);
  }

  TextTheme textTheme(Typography typography) {
    return switch (brightness) {
      (Brightness.dark) => typography.white,
      (Brightness.light) => typography.black,
    };
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
