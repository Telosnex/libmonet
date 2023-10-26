import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:libmonet/argb_srgb_xyz_lab.dart';
import 'package:libmonet/contrast.dart';
import 'package:libmonet/full_color_scheme.dart';
import 'package:libmonet/hct.dart';
import 'package:libmonet/safe_colors.dart';
import 'package:libmonet/temperature.dart';
import 'package:libmonet/theming/button_style.dart';
import 'package:libmonet/theming/slider_flat_shape.dart';
import 'package:libmonet/theming/slider_flat_thumb.dart';

class MonetTheme extends StatelessWidget {
  final SafeColors primarySafeColors;
  final SafeColors secondarySafeColors;
  final SafeColors tertiarySafeColors;

  final double surfaceLstar;
  final double contrast;
  static const double buttonElevation = 16.0;
  static const double modalElevation = 2.0;
  final Algo algo;

  final Brightness brightness;
  final Widget child;
  static const double maxPanelWidth =
      1040.0; // 8.5" - 1" margins * 160 dp / in.
  static const double touchSize = 36.0;
  static final InteractiveInkFeatureFactory splashFactory =
      defaultTargetPlatform == TargetPlatform.android && !kIsWeb
          ? InkSparkle.splashFactory
          : InkRipple.splashFactory;

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
    final tt = createTextTheme(typographyData);
    final txtC = primarySafeColors.backgroundText;
    final textTheme = tt.copyWith(
      displayLarge: tt.displayLarge!.copyWith(
          fontSize: 24,
          color: primarySafeColors.backgroundText,
          fontWeight: FontWeight.w500),
      displayMedium: tt.displayMedium!
          .copyWith(fontSize: 22, color: txtC, fontWeight: FontWeight.w500),
      displaySmall: tt.displaySmall!
          .copyWith(fontSize: 20, color: txtC, fontWeight: FontWeight.w500),
      headlineLarge: tt.headlineLarge!.copyWith(fontSize: 20, color: txtC),
      headlineMedium: tt.headlineMedium!.copyWith(fontSize: 18, color: txtC),
      headlineSmall: tt.headlineSmall!.copyWith(fontSize: 16, color: txtC),
      bodyLarge: tt.bodyLarge!.copyWith(fontSize: 16, color: txtC),
      bodyMedium: tt.bodyMedium!.copyWith(fontSize: 14, color: txtC),
      bodySmall: tt.bodySmall!.copyWith(fontSize: 12, color: txtC),
      labelLarge: tt.labelLarge!.copyWith(fontSize: 14, color: txtC),
      labelMedium: tt.labelMedium!.copyWith(fontSize: 14, color: txtC),
      labelSmall: tt.labelSmall!.copyWith(fontSize: 12, color: txtC),
    );
    final themeData = ThemeData(
      // Hack-y, idea is, in dark mode, apply on surface (usually lighter)
      // with opacity to surface to make elevated surfaces lighter. Doesn't
      // make sense once you don't only have opacity for lightening, but color.
      applyElevationOverlayColor: false,
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
      splashFactory: splashFactory,
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      brightness: brightness,
      canvasColor: primarySafeColors.background,
      cardColor: primarySafeColors.background,
      colorScheme: colorScheme,
      dialogBackgroundColor: primarySafeColors.background,
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
      // Avoid setting a default, as each widget may be a different color and
      // thus should be set explicitly.
      shadowColor: Colors.transparent,
      splashColor: primarySafeColors.fillSplash,
      // Material uses 70% white in dark mode, 54% black in light mode
      // Is transparency important? Where is this used?
      // For now, treat it like text
      unselectedWidgetColor: primarySafeColors.backgroundText,
      iconTheme: iconThemeData(),
      primaryIconTheme: iconThemeData(),
      primaryTextTheme: textTheme,
      textTheme: textTheme,
      typography: typographyData,
      // BEGIN ALL THE ACCOUTREMENTS
      actionIconTheme: actionIconTheme(),
      appBarTheme: appBarTheme(textTheme),
      badgeTheme: badgeThemeData(context, textTheme),
      bannerTheme: bannerThemeData(),
      bottomAppBarTheme: bottomAppBarTheme(),
      bottomNavigationBarTheme: bottomNavigationBarThemeData(textTheme),
      bottomSheetTheme: bottomSheetThemeData(),
      buttonBarTheme: buttonBarThemeData(),
      buttonTheme: buttonThemeData(),
      cardTheme: cardTheme(),
      checkboxTheme: checkboxThemeData(),
      chipTheme: chipThemeData(brightness, textTheme),
      dataTableTheme: dataTableThemeData(textTheme),
      datePickerTheme: datePickerThemeData(brightness, textTheme),
      dialogTheme: createDialogTheme(textTheme),
      dividerTheme: dividerThemeData(),
      drawerTheme: drawerThemeData(),
      elevatedButtonTheme: elevatedButtonTheme(),
      expansionTileTheme: expansionTileThemeData(),
      filledButtonTheme: filledButtonTheme(),
      floatingActionButtonTheme: floatingActionButtonThemeData(textTheme),
      iconButtonTheme: iconButtonThemeData(),
      listTileTheme: listTileThemeData(textTheme),
      menuBarTheme: menuBarThemeData(),
      menuButtonTheme: menuButtonThemeData(),
      menuTheme: menuThemeData(),
      navigationBarTheme: navigationBarThemeData(textTheme),
      navigationDrawerTheme: navigationDrawerThemeData(textTheme),
      navigationRailTheme: navigationRailThemeData(textTheme),
      outlinedButtonTheme: outlinedButtonTheme(),
      popupMenuTheme: popupMenuThemeData(textTheme),
      progressIndicatorTheme: progressIndicatorThemeData(),
      radioTheme: radioThemeData(),
      searchBarTheme: searchBarThemeData(textTheme),
      searchViewTheme: searchViewThemeData(textTheme),
      segmentedButtonTheme: segmentedButtonThemeData(),
      sliderTheme: sliderThemeData(textTheme),
      snackBarTheme: snackBarThemeData(textTheme),
      switchTheme: switchThemeData(),
      tabBarTheme: createTabBarTheme(textTheme),
      textButtonTheme: textButtonTheme(),
      textSelectionTheme: textSelectionThemeData(),
      timePickerTheme: timePickerThemeData(textTheme),
      toggleButtonsTheme: toggleButtonsThemeData(textTheme),
      tooltipTheme: tooltipThemeData(textTheme),
    );

    final cupertinoOverrideTheme =
        MaterialBasedCupertinoThemeData(materialTheme: themeData);

    return _MonetInheritedTheme(
      theme: this,
      child: AnimatedTheme(
        data: themeData.copyWith(
          cupertinoOverrideTheme: cupertinoOverrideTheme,
        ),
        child: child,
      ),
    );
  }

  ActionIconThemeData actionIconTheme() {
    // Provides platform default icons, just use default.
    return const ActionIconThemeData();
  }

  AppBarTheme appBarTheme(TextTheme textTheme) {
    return AppBarTheme(
      titleTextStyle: textTheme.displayLarge,
      backgroundColor: primarySafeColors.background,
      foregroundColor: primarySafeColors.backgroundText,
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
      dividerColor: Colors.transparent,
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
      color: primarySafeColors.background,
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
    return const ButtonBarThemeData(alignment: MainAxisAlignment.center);
  }

  ButtonThemeData buttonThemeData() {
    // Go with defaults, most of the properties are about padding and spacing.
    return const ButtonThemeData();
  }

  CardTheme cardTheme() {
    return CardTheme(
      clipBehavior: Clip.none, // match default
      color: primarySafeColors.background,
      shadowColor: lstarFromArgb(primarySafeColors.background.value) > 60
          ? Colors.black
          : Colors.white,
      surfaceTintColor: primarySafeColors.background,
      elevation: 8,
      margin: const EdgeInsets.all(0), // match default
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(
              color: primarySafeColors.fill, width: 2)), // match default
    );
  }

  CheckboxThemeData checkboxThemeData() {
    return CheckboxThemeData(
      mouseCursor: const MaterialStatePropertyAll(
          null), // allows widget to default to clickable
      fillColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return primarySafeColors.fill;
        } else if (states.contains(MaterialState.hovered)) {
          return primarySafeColors.textHover;
        } else if (states.contains(MaterialState.pressed)) {
          return primarySafeColors.textSplash;
        } else {
          return primarySafeColors.background;
        }
      }),
      // Even though it is an icon, it is displayed very small, text is a better
      // fit (icon implies a height of 40 dp / 18 pt in parlance of WCAG 2.1)
      checkColor: MaterialStateProperty.all(primarySafeColors.fillText),
      overlayColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return primarySafeColors.textHover;

          // Note 1:
          // Even though this is "wrong", i.e. the checkbox is filled,
          // Checkbox is unique in that its overlay isn't actually displayed in
          // the component, but around it. It feels more accurate to use the
          // same overlay color as when it is not selected.
          //
          // Note 2: Other states aren't respected here, even if supplied. Ex.
          // selected doesn't distinguish between being hovered and pressed.
        } else if (states.contains(MaterialState.hovered)) {
          return primarySafeColors.textHover;
        } else if (states.contains(MaterialState.pressed)) {
          return primarySafeColors.textSplash;
        } else {
          return primarySafeColors.background;
        }
      }),
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

  ChipThemeData chipThemeData(Brightness brightness, TextTheme textTheme) {
    return ChipThemeData.fromDefaults(
      brightness: brightness,
      secondaryColor: secondarySafeColors.color,
      labelStyle: textTheme.bodyMedium!.copyWith(
        color: secondarySafeColors.colorText,
      ),
    ).copyWith(
        checkmarkColor: MaterialStateColor.resolveWith((states) {
          return primarySafeColors.fill;
        }),
        surfaceTintColor: MaterialStateColor.resolveWith((states) {
          return primarySafeColors.background;
        }),
        selectedColor: Colors
            .transparent, // messes everything up because FG can't be set based on state
        secondarySelectedColor: primarySafeColors.textHover,
        secondaryLabelStyle: textTheme.labelLarge!
            .copyWith(color: primarySafeColors.textHoverText),
        side: BorderSide(width: 2, color: primarySafeColors.fill),
        backgroundColor: primarySafeColors.background,
        labelStyle:
            textTheme.labelLarge!.copyWith(color: primarySafeColors.text));
  }

  DataTableThemeData dataTableThemeData(TextTheme textTheme) {
    return DataTableThemeData(
      dataTextStyle: textTheme.bodyMedium,
      dividerThickness: 2.0,
      headingTextStyle: textTheme.headlineMedium,
      headingRowColor: MaterialStateProperty.all(Colors.transparent),
      dataRowMinHeight: touchSize,
      dataRowMaxHeight: double.infinity,
      headingRowHeight: 0,
    );
  }

  DatePickerThemeData datePickerThemeData(
    Brightness brightness,
    TextTheme textTheme,
  ) {
    final background = MaterialStateProperty.resolveWith(
      (states) {
        if (states.contains(MaterialState.hovered)) {
          return primarySafeColors.textHover;
        } else if (states.contains(MaterialState.pressed)) {
          return primarySafeColors.textSplash;
        } else if (states.contains(MaterialState.selected)) {
          return primarySafeColors.color;
        } else {
          return Colors.transparent;
        }
      },
    );
    final foreground = MaterialStateProperty.resolveWith(
      (states) {
        if (states.contains(MaterialState.selected)) {
          return primarySafeColors.colorText;
        } else {
          return primarySafeColors.backgroundText;
        }
      },
    );
    final fillText = MaterialStateProperty.resolveWith(
      (states) {
        if (states.contains(MaterialState.hovered)) {
          return primarySafeColors.fillHoverText;
        } else if (states.contains(MaterialState.pressed)) {
          return primarySafeColors.fillSplashText;
        } else if (states.contains(MaterialState.selected)) {
          return primarySafeColors.fillSplashText;
        } else {
          return primarySafeColors.fillText;
        }
      },
    );
    final shadowColor = lstarFromArgb(primarySafeColors.background.value) > 60
        ? Colors.black
        : Colors.white;
    return DatePickerThemeData(
      backgroundColor: primarySafeColors.background,
      elevation: null /* will match Dialog.elevation */,
      shadowColor: shadowColor,
      surfaceTintColor: primarySafeColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      headerBackgroundColor: primarySafeColors.color,
      headerForegroundColor: primarySafeColors.colorText,
      headerHeadlineStyle: textTheme.headlineMedium,
      headerHelpStyle: textTheme.headlineSmall,
      weekdayStyle: textTheme.bodyLarge,
      dayStyle: textTheme.bodySmall,
      dayForegroundColor: foreground,
      dayBackgroundColor: background,
      dayOverlayColor: background,
      todayForegroundColor: foreground,
      todayBackgroundColor: background,
      todayBorder: BorderSide(
        width: 2.0,
        color: primarySafeColors.fill,
      ),
      yearStyle: textTheme.headlineMedium,
      yearBackgroundColor: background,
      yearForegroundColor: foreground,
      yearOverlayColor: background,
      rangePickerBackgroundColor: primarySafeColors.background,
      rangePickerElevation: 0,
      rangePickerShadowColor: shadowColor,
      rangePickerSurfaceTintColor: primarySafeColors.background,
      rangePickerShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      rangePickerHeaderBackgroundColor: primarySafeColors.color,
      rangePickerHeaderForegroundColor: primarySafeColors.colorText,
      rangePickerHeaderHeadlineStyle: textTheme.headlineMedium,
      rangePickerHeaderHelpStyle: textTheme.headlineSmall,
      rangeSelectionBackgroundColor: primarySafeColors.fill,
      rangeSelectionOverlayColor: fillText,
      dividerColor: Colors.transparent,
      inputDecorationTheme: null, // if null, uses ThemeData's
    );
  }

  DialogTheme createDialogTheme(TextTheme textTheme) {
    return DialogTheme(
      backgroundColor: primarySafeColors.background,
      elevation: modalElevation,
      shadowColor: lstarFromArgb(primarySafeColors.background.value) > 60
          ? Colors.black
          : Colors.white,
      surfaceTintColor: primarySafeColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: null,
      iconColor: primarySafeColors.fill,
      titleTextStyle: textTheme.headlineMedium,
      contentTextStyle: textTheme.bodyMedium,
      actionsPadding:
          null, // don't override default in AlertDialog.actionsPading
    );
  }

  DropdownMenuThemeData dropdownMenuThemeData(TextTheme textTheme) {
    return DropdownMenuThemeData(
      inputDecorationTheme: const InputDecorationTheme(
        fillColor: Colors.red,
        filled: true,
      ),
      textStyle: textTheme.bodyMedium!.copyWith(color: primarySafeColors.text),
      menuStyle: createMenuStyleForDropdown(),
    );
  }

  ElevatedButtonThemeData elevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: elevatedButtonStyleFromColors(primarySafeColors),
    );
  }

  ExpansionTileThemeData expansionTileThemeData() {
    return ExpansionTileThemeData(
      backgroundColor: primarySafeColors.background,
      collapsedBackgroundColor: primarySafeColors.background,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      /* Match default */
      expandedAlignment: Alignment.center,
      childrenPadding: EdgeInsets.zero,
      iconColor: primarySafeColors.fill,
      collapsedIconColor: primarySafeColors.fill,
      textColor: primarySafeColors.text,
      collapsedTextColor: primarySafeColors.text,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: primarySafeColors.colorBorder,
          width: 2,
        ),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: primarySafeColors.colorBorder,
          width: 2,
        ),
      ),
    );
  }

  FilledButtonThemeData filledButtonTheme() {
    return FilledButtonThemeData(
      style: filledButtonStyleFromColors(primarySafeColors),
    );
  }

  FloatingActionButtonThemeData floatingActionButtonThemeData(
      TextTheme textTheme) {
    return FloatingActionButtonThemeData(
      foregroundColor: MaterialStateColor.resolveWith((states) {
        if (states.contains(MaterialState.pressed)) {
          return primarySafeColors.colorSplashText;
        } else if (states.contains(MaterialState.hovered)) {
          return primarySafeColors.colorHoverText;
        } else {
          return primarySafeColors.colorText;
        }
      }),
      backgroundColor: MaterialStateColor.resolveWith((states) {
        if (states.contains(MaterialState.pressed)) {
          return primarySafeColors.colorSplash;
        } else if (states.contains(MaterialState.hovered)) {
          return primarySafeColors.colorHover;
        } else {
          return primarySafeColors.color;
        }
      }),
      focusColor: primarySafeColors.colorHover,
      hoverColor: primarySafeColors.colorHover,
      splashColor: primarySafeColors.colorSplash,
      elevation: buttonElevation,
      focusElevation: buttonElevation,
      hoverElevation: buttonElevation,
      highlightElevation: buttonElevation,
      disabledElevation: buttonElevation,
      shape: CircleBorder(
        side: BorderSide(
          color: primarySafeColors.colorBorder,
          width: 2,
        ),
      ),
      enableFeedback: true,
      iconSize: 24,
      extendedTextStyle:
          textTheme.bodyMedium!.copyWith(color: primarySafeColors.colorText),
      /* size constraints not included */
    );
  }

  IconButtonThemeData iconButtonThemeData() {
    return IconButtonThemeData(
        style: iconButtonStyleFromColors(primarySafeColors));
  }

  ListTileThemeData listTileThemeData(TextTheme textTheme) {
    return ListTileThemeData(
      dense: true,
      shape: null,
      style: ListTileStyle.list,
      selectedColor: primarySafeColors.fillHover,
      iconColor: primarySafeColors.fill,
      textColor: primarySafeColors.text,
      titleTextStyle:
          textTheme.titleSmall!.copyWith(color: primarySafeColors.text),
      subtitleTextStyle:
          textTheme.bodyLarge!.copyWith(color: primarySafeColors.text),
      leadingAndTrailingTextStyle:
          textTheme.bodyMedium!.copyWith(color: primarySafeColors.text),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
      tileColor: primarySafeColors.background,
      selectedTileColor: primarySafeColors.fillHover,
      horizontalTitleGap: 16,
      minVerticalPadding: 4,
      minLeadingWidth: 40,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      titleAlignment: ListTileTitleAlignment.threeLine,
    );
  }

  MenuBarThemeData menuBarThemeData() {
    return MenuBarThemeData(
      style: createMenuStyleForMenuBar(),
    );
  }

  MenuStyle createMenuStyleForDropdown() {
    return MenuStyle(
      backgroundColor: MaterialStatePropertyAll(primarySafeColors.background),
      shadowColor: MaterialStateProperty.all(Colors.transparent),
      surfaceTintColor: MaterialStatePropertyAll(primarySafeColors.background),
      elevation: const MaterialStatePropertyAll(modalElevation),
      side: MaterialStatePropertyAll(
        BorderSide(
          color: primarySafeColors.colorBorder,
          width: 2,
        ),
      ),
      padding: const MaterialStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
      shape: MaterialStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: primarySafeColors.colorBorder,
            width: 2,
          ),
        ),
      ),
    );
  }

  MenuStyle createMenuStyleForMenuBar() {
    return MenuStyle(
      backgroundColor: MaterialStatePropertyAll(primarySafeColors.background),
      shadowColor: MaterialStateProperty.all(Colors.transparent),
      surfaceTintColor: MaterialStatePropertyAll(primarySafeColors.background),
      elevation: const MaterialStatePropertyAll(modalElevation),
      padding: const MaterialStatePropertyAll(EdgeInsets.zero),
      shape: const MaterialStatePropertyAll(null),
    );
  }

  MenuButtonThemeData menuButtonThemeData() {
    return MenuButtonThemeData(
      style: textButtonStyleFromColors(primarySafeColors).copyWith(
        padding: MaterialStateProperty.all(const EdgeInsets.all(4)),
        shape: MaterialStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  MenuThemeData menuThemeData() {
    return MenuThemeData(
      style: createMenuStyleForDropdown(),
    );
  }

  NavigationBarThemeData navigationBarThemeData(TextTheme textTheme) {
    return NavigationBarThemeData(
      height: 80, // match default
      backgroundColor: primarySafeColors.background,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: primarySafeColors.background,
      indicatorColor: primarySafeColors.fill,
      indicatorShape: const StadiumBorder(), // match default
      labelTextStyle:
          MaterialStateProperty.resolveWith((Set<MaterialState> states) {
        final TextStyle style = textTheme.labelSmall!;
        return style.apply(
          color: states.contains(MaterialState.selected)
              ? primarySafeColors.text
              : primarySafeColors.backgroundText,
        );
      }),
      iconTheme: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return IconThemeData(color: primarySafeColors.fillIcon);
        } else if (states.contains(MaterialState.hovered)) {
          // not supported
        }
        return IconThemeData(color: primarySafeColors.backgroundText);
      }),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      /* size constraints not included */
    );
  }

  BottomNavigationBarThemeData bottomNavigationBarThemeData(
      TextTheme textTheme) {
    return BottomNavigationBarThemeData(
      backgroundColor: primarySafeColors.background,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
      selectedIconTheme:
          iconThemeData().copyWith(color: primarySafeColors.fill),
      unselectedIconTheme:
          iconThemeData().copyWith(color: primarySafeColors.backgroundText),
      selectedLabelStyle:
          textTheme.labelSmall!.copyWith(color: primarySafeColors.fill),
      unselectedLabelStyle: textTheme.labelSmall!
          .copyWith(color: primarySafeColors.backgroundText),
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

  NavigationDrawerThemeData navigationDrawerThemeData(TextTheme textTheme) {
    return NavigationDrawerThemeData(
      tileHeight: 56,
      /* match _NavigationDrawerDefaultsM3 */
      backgroundColor: primarySafeColors.background,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: primarySafeColors.background,
      indicatorColor: primarySafeColors.fill,
      indicatorShape: const StadiumBorder(), // match default
      labelTextStyle:
          MaterialStateProperty.resolveWith((Set<MaterialState> states) {
        final TextStyle style = textTheme.labelMedium!;
        return style.apply(
          color: states.contains(MaterialState.selected)
              ? primarySafeColors.text
              : primarySafeColors.backgroundText,
        );
      }),
    );
  }

  NavigationRailThemeData navigationRailThemeData(TextTheme textTheme) {
    return NavigationRailThemeData(
      backgroundColor: primarySafeColors.background,
      elevation: 0,
      unselectedLabelTextStyle: textTheme.labelMedium!
          .copyWith(color: primarySafeColors.backgroundText),
      selectedLabelTextStyle:
          textTheme.labelMedium!.copyWith(color: primarySafeColors.text),
      unselectedIconTheme:
          iconThemeData().copyWith(color: primarySafeColors.backgroundText),
      selectedIconTheme:
          iconThemeData().copyWith(color: primarySafeColors.fillIcon),
      groupAlignment: -1.0, // match default, top
      labelType: NavigationRailLabelType.all,
      useIndicator: true,
      indicatorColor: primarySafeColors.fill,
      indicatorShape: const StadiumBorder(), // match default
      minWidth: 72, // match default
      minExtendedWidth: 256, // match default
    );
  }

  OutlinedButtonThemeData outlinedButtonTheme() {
    return OutlinedButtonThemeData(
      style: outlineButtonStyleFromColors(primarySafeColors),
    );
  }

  PopupMenuThemeData popupMenuThemeData(TextTheme textTheme) {
    return PopupMenuThemeData(
      color: primarySafeColors.background, // Popup background
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: primarySafeColors.fill,
          width: 2,
        ),
      ),
      elevation: modalElevation, // Popup outline elevation
      shadowColor: lstarFromArgb(primarySafeColors.background.value) > 60
          ? Colors.black
          : Colors.white,
      surfaceTintColor: primarySafeColors.background,
      textStyle: textTheme.bodyMedium,
      labelTextStyle: MaterialStateProperty.resolveWith((states) {
        // Doesn't support hover or selected, only disabled, which we do not
        // specify.
        return textTheme.labelMedium!
            .apply(color: primarySafeColors.backgroundText);
      }),
      enableFeedback: true,
      position: PopupMenuPosition.under,
    );
  }

  ProgressIndicatorThemeData progressIndicatorThemeData() {
    return ProgressIndicatorThemeData(
      color: primarySafeColors.fill,
      linearTrackColor: primarySafeColors.fillText,
      linearMinHeight: 4,
      circularTrackColor: primarySafeColors.fillText,
      refreshBackgroundColor: primarySafeColors.background,
    );
  }

  RadioThemeData radioThemeData() {
    // States have choices that look odd compared to other components.
    // This component is particularly challenging due to it being essentially
    // a fill with a circle surrounding it for hover state. These were
    // picked thoughtfully.
    return RadioThemeData(
      fillColor: MaterialStateProperty.resolveWith(
        (Set<MaterialState> states) {
          if (states.contains(MaterialState.hovered)) {
            return primarySafeColors.textHoverText;
          }
          if (states.contains(MaterialState.selected)) {
            return primarySafeColors.text;
          }
          return primarySafeColors.text;
        },
      ),
      overlayColor: MaterialStateProperty.resolveWith(
        (Set<MaterialState> states) {
          return primarySafeColors.textHover;
        },
      ),
      splashRadius: 20.0, // match checkbox default,
      materialTapTargetSize: null, // let Theme manage it
      visualDensity: null, // let Theme manage it
    );
  }

  SearchBarThemeData searchBarThemeData(TextTheme textTheme) {
    return SearchBarThemeData(
      elevation: const MaterialStatePropertyAll(2),
      backgroundColor: MaterialStatePropertyAll(primarySafeColors.background),
      shadowColor: MaterialStatePropertyAll(
        lstarFromArgb(primarySafeColors.background.value) > 60
            ? Colors.black
            : Colors.white.withOpacity(0.54),
      ),
      surfaceTintColor: MaterialStatePropertyAll(primarySafeColors.background),
      overlayColor: MaterialStatePropertyAll(primarySafeColors.background),
      side: MaterialStatePropertyAll(
        BorderSide(
          color: primarySafeColors.fill,
          width: 2,
        ),
      ),
      shape: MaterialStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: primarySafeColors.fill,
            width: 2,
          ),
        ),
      ),
      padding: const MaterialStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: 16,
        ),
      ),
      textStyle: MaterialStatePropertyAll(textTheme.bodyMedium),
      hintStyle: MaterialStatePropertyAll(textTheme.labelMedium),
      constraints: const BoxConstraints(
          minWidth: 360.0, maxWidth: 800.0, minHeight: 56.0), // match default
    );
  }

  SearchViewThemeData searchViewThemeData(TextTheme textTheme) {
    return SearchViewThemeData(
      backgroundColor: primarySafeColors.background,
      elevation: modalElevation,
      surfaceTintColor: primarySafeColors.background,
      constraints: const BoxConstraints(
          minWidth: 360.0, maxWidth: 800.0, minHeight: 56.0),
      side: BorderSide(color: primarySafeColors.fill, width: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: primarySafeColors.fill,
          width: 2,
        ),
      ),
      headerTextStyle: textTheme.headlineMedium,
      headerHintStyle: textTheme.headlineSmall,
      dividerColor: primarySafeColors.backgroundText,
    );
  }

  SegmentedButtonThemeData segmentedButtonThemeData() {
    // Button style in-lined due to unique requirements, essentially, a text
    // button when not selected, fillbutton when selected.
    final safeColors = primarySafeColors;
    final selectedBackground = stateColors(
      color: safeColors.fill,
      hover: safeColors.fillHover,
      splash: safeColors.fillSplash,
    );
    final unselectedBackground = stateColors(
      color: safeColors.background,
      hover: safeColors.textHover,
      splash: safeColors.textSplash,
    );
    final background = MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.selected)) {
        return selectedBackground.resolve(states);
      } else {
        return unselectedBackground.resolve(states);
      }
    });
    final selectedForeground = stateColors(
      color: safeColors.fillText,
      hover: safeColors.fillHoverText,
      splash: safeColors.fillSplashText,
    );
    final unselectedForeground = stateColors(
      color: safeColors.backgroundText,
      hover: safeColors.textHoverText,
      splash: safeColors.textSplashText,
    );
    final foreground = MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.selected)) {
        return selectedForeground.resolve(states);
      } else {
        return unselectedForeground.resolve(states);
      }
    });
    return SegmentedButtonThemeData(
        style: ButtonStyle(
      backgroundColor: background,
      surfaceTintColor: background,
      overlayColor: background,
      foregroundColor: foreground,
      side: MaterialStateProperty.all(
        BorderSide(color: safeColors.colorBorder, width: 2),
      ),
    ));
  }

  SliderThemeData sliderThemeData(TextTheme textTheme) {
    return SliderThemeData(
      trackHeight: touchSize,
      activeTrackColor: primarySafeColors.color,
      // This is a _nice_ touch: ex. if an elevated button is above this slider,
      // the shadow isn't cut off
      inactiveTrackColor: Colors.transparent,
      secondaryActiveTrackColor: primarySafeColors.color,
      disabledActiveTrackColor: primarySafeColors.color,
      disabledInactiveTrackColor: primarySafeColors.background,
      disabledSecondaryActiveTrackColor: primarySafeColors.color,
      activeTickMarkColor: primarySafeColors.colorText,
      inactiveTickMarkColor: primarySafeColors.backgroundText,
      disabledActiveTickMarkColor: primarySafeColors.colorText,
      disabledInactiveTickMarkColor: primarySafeColors.backgroundText,
      thumbColor: primarySafeColors.color,
      overlappingShapeStrokeColor: primarySafeColors.fillText,
      disabledThumbColor: primarySafeColors.color,
      overlayColor: Colors.transparent,
      valueIndicatorColor: primarySafeColors.color,
      overlayShape: const RoundSliderOverlayShape(),
      tickMarkShape: const RoundSliderTickMarkShape(),
      thumbShape: SliderFlatThumb(),
      trackShape: SliderFlatShape(),
      valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
      rangeTickMarkShape: const RoundRangeSliderTickMarkShape(),
      rangeThumbShape: const RoundRangeSliderThumbShape(),
      rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
      rangeValueIndicatorShape: const PaddleRangeSliderValueIndicatorShape(),
      showValueIndicator: ShowValueIndicator.always,
      valueIndicatorTextStyle:
          textTheme.labelLarge!.copyWith(color: primarySafeColors.colorText),
      minThumbSeparation: 8,
      allowedInteraction: SliderInteraction.tapAndSlide,
    );
  }

  SnackBarThemeData snackBarThemeData(TextTheme textTheme) {
    return SnackBarThemeData(
      backgroundColor: primarySafeColors.color,
      actionTextColor: primarySafeColors.colorText,
      disabledActionTextColor: primarySafeColors.colorText,
      contentTextStyle:
          textTheme.bodyMedium!.copyWith(color: primarySafeColors.colorText),
      elevation: modalElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: primarySafeColors.colorBorder,
          width: 2,
        ),
      ),
      
      behavior: SnackBarBehavior.floating,
      width: null, // allows use of margin instead
      insetPadding: const EdgeInsets.fromLTRB(15.0, 5.0, 15.0, 10.0),
      showCloseIcon: true,
      closeIconColor: primarySafeColors.colorIcon,
      actionOverflowThreshold:
          0.25, // match default,  the percentage threshold for action widget's width before it overflows  to a new line.
      actionBackgroundColor: primarySafeColors.color,
      disabledActionBackgroundColor: primarySafeColors.color,
    );
  }

  SwitchThemeData switchThemeData() {
    return SwitchThemeData(
      thumbColor: MaterialStatePropertyAll(primarySafeColors.fill),
      trackColor: MaterialStatePropertyAll(primarySafeColors.background),
      trackOutlineColor: MaterialStatePropertyAll(primarySafeColors.fill),
      trackOutlineWidth: const MaterialStatePropertyAll(2.0),
      materialTapTargetSize: null, // let Theme manage it
      mouseCursor: null, // let Theme manage it
      overlayColor: MaterialStateProperty.resolveWith(
        (Set<MaterialState> states) {
          if (states.contains(MaterialState.selected)) {
            return primarySafeColors.fillSplash;
          } else if (states.contains(MaterialState.hovered)) {
            return primarySafeColors.fillHover;
          } else if (states.contains(MaterialState.pressed)) {
            return primarySafeColors.fillSplash;
          } else {
            return primarySafeColors.fill;
          }
        },
      ),
      splashRadius: 20.0, // match checkbox default,
      thumbIcon: MaterialStateProperty.resolveWith(
        (Set<MaterialState> states) {
          if (states.contains(MaterialState.selected)) {
            return Icon(
              Icons.check_outlined,
              color: primarySafeColors.colorSplashText,
            );
          } else {
            return null;
          }
        },
      ),
    );
  }

  TabBarTheme createTabBarTheme(TextTheme textTheme) {
    final labelColor = MaterialStateColor.resolveWith((states) {
      if (states.contains(MaterialState.selected)) {
        return primarySafeColors.text;
      } else if (states.contains(MaterialState.hovered)) {
        return primarySafeColors.textHoverText;
      } else if (states.contains(MaterialState.pressed)) {
        return primarySafeColors.textSplashText;
      } else {
        return primarySafeColors.backgroundText;
      }
    });
    return TabBarTheme(
      // Oddly, this still is required even if indicatorColor is set.
      indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: primarySafeColors.fill, width: 2)),
      indicatorColor: primarySafeColors.fill,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      labelColor: primarySafeColors.fill,
      labelStyle: textTheme.labelMedium,
      unselectedLabelColor: labelColor,
      unselectedLabelStyle: textTheme.labelMedium,
      overlayColor: MaterialStateProperty.resolveWith(
        (Set<MaterialState> states) {
          if (states.contains(MaterialState.selected)) {
            return primarySafeColors.textSplash;
          } else if (states.contains(MaterialState.hovered)) {
            return primarySafeColors.textHover;
          } else if (states.contains(MaterialState.pressed)) {
            return primarySafeColors.textSplash;
          } else {
            return primarySafeColors.background;
          }
        },
      ),
      splashFactory: splashFactory,
      mouseCursor: null, // use default view
      tabAlignment: TabAlignment.fill,
    );
  }

  TextButtonThemeData textButtonTheme() {
    return TextButtonThemeData(
      style: textButtonStyleFromColors(primarySafeColors),
    );
  }

  TextSelectionThemeData textSelectionThemeData() {
    return TextSelectionThemeData(
      cursorColor: primarySafeColors.fill,
      selectionColor: primarySafeColors.textHover,
      selectionHandleColor: primarySafeColors.fill,
    );
  }

  TimePickerThemeData timePickerThemeData(TextTheme textTheme) {
    return TimePickerThemeData(
      backgroundColor: primarySafeColors.background,
      cancelButtonStyle: outlineButtonStyleFromColors(tertiarySafeColors),
      confirmButtonStyle: filledButtonStyleFromColors(primarySafeColors),
      dayPeriodBorderSide: BorderSide(
        color: primarySafeColors.fill,
        width: 2,
      ),

      dayPeriodShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: primarySafeColors.fill,
          width: 2,
        ),
      ),
      dayPeriodTextColor: MaterialStateColor.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return primarySafeColors.fillText;
        } else {
          return primarySafeColors.backgroundText;
        }
      }),
      dayPeriodTextStyle: textTheme.labelLarge,
      dialBackgroundColor: primarySafeColors.fill,
      dialHandColor: primarySafeColors.fillText,
      dialTextColor: primarySafeColors.text,
      dialTextStyle: textTheme.labelLarge,
      elevation: modalElevation,
      entryModeIconColor: primarySafeColors.fill,
      helpTextStyle: textTheme.headlineSmall,
      dayPeriodColor: MaterialStateColor.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return primarySafeColors.fill;
        } else {
          return primarySafeColors.background;
        }
      }),
      hourMinuteColor: MaterialStateColor.resolveWith((states) {
        if (states.contains(MaterialState.hovered)) {
          return primarySafeColors.fillHover;
        } else if (states.contains(MaterialState.pressed)) {
          return primarySafeColors.fillSplash;
        } else if (states.contains(MaterialState.selected)) {
          return primarySafeColors.fill;
        } else {
          return primarySafeColors.background;
        }
      }),
      hourMinuteShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: primarySafeColors.fill,
          width: 2,
        ),
      ),
      hourMinuteTextColor: MaterialStateColor.resolveWith((states) {
        if (states.contains(MaterialState.hovered)) {
          return primarySafeColors.fillHoverText;
        } else if (states.contains(MaterialState.pressed)) {
          return primarySafeColors.fillSplashText;
        } else if (states.contains(MaterialState.selected)) {
          return primarySafeColors.fillText;
        } else {
          return primarySafeColors.backgroundText;
        }
      }),
      inputDecorationTheme: null, // let picker use its defaults
      padding: const EdgeInsets.all(24), // match default in time_picker.dart
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: primarySafeColors.fill,
          width: 2,
        ),
      ),
    );
  }

  ToggleButtonsThemeData toggleButtonsThemeData(TextTheme textTheme) {
    return ToggleButtonsThemeData(
      textStyle: textTheme.bodyMedium,
      constraints: const BoxConstraints(
        minWidth: touchSize,
        minHeight: touchSize,
      ),
      color: MaterialStateColor.resolveWith((states) {
        // Color is not selected.
        // States are always empty.
        return primarySafeColors.text;
      }),
      selectedColor: MaterialStateColor.resolveWith((states) {
        return primarySafeColors.textSplashText;
      }),
      disabledColor: primarySafeColors.text,
      fillColor: primarySafeColors.textSplash,
      focusColor: primarySafeColors.colorHover,
      highlightColor: primarySafeColors.fillHover,
      hoverColor: MaterialStateColor.resolveWith((states) {
        return primarySafeColors.textHover;
      }),
      splashColor: primarySafeColors.fillSplash,
      borderColor: primarySafeColors.colorBorder,
      selectedBorderColor: primarySafeColors.colorBorder,
      disabledBorderColor: primarySafeColors.colorBorder,
      borderRadius: BorderRadius.circular(8),
      borderWidth: 2,
    );
  }

  TooltipThemeData tooltipThemeData(TextTheme textTheme) {
    return TooltipThemeData(
      height: switch (defaultTargetPlatform) {
        TargetPlatform.macOS ||
        TargetPlatform.linux ||
        TargetPlatform.windows =>
          24.0,
        TargetPlatform.android ||
        TargetPlatform.fuchsia ||
        TargetPlatform.iOS =>
          32.0,
      },
      padding: switch (defaultTargetPlatform) {
        TargetPlatform.macOS ||
        TargetPlatform.linux ||
        TargetPlatform.windows =>
          const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        TargetPlatform.android ||
        TargetPlatform.fuchsia ||
        TargetPlatform.iOS =>
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      },
      margin: EdgeInsets.zero,
      verticalOffset: 24,
      preferBelow: true,
      excludeFromSemantics: false,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: primarySafeColors.colorBorder,
            width: 2,
          ),
        ),
        color: primarySafeColors.color,
      ),
      textStyle:
          textTheme.bodyMedium!.copyWith(color: primarySafeColors.colorText),
      textAlign: TextAlign.center,
      showDuration: const Duration(seconds: 2),
      waitDuration: const Duration(seconds: 1),
      triggerMode: TooltipTriggerMode.longPress,
      enableFeedback: true,
    );
  }

  InputDecorationTheme inputDecorationTheme() {
    return InputDecorationTheme(
      fillColor: primarySafeColors.background,
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
      color: primarySafeColors.fill,
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
      thumbColor:
          MaterialStatePropertyAll(tertiarySafeColors.fill.withOpacity(0.8)),
      trackColor: const MaterialStatePropertyAll(Colors.transparent),
      trackBorderColor: const MaterialStatePropertyAll(Colors.transparent),
      interactive: true,
    );
  }

  Typography typography(ColorScheme colorScheme) {
    return Typography.material2021(
      platform: defaultTargetPlatform,
      colorScheme: colorScheme,
    );
  }

  TextTheme createTextTheme(Typography typography) {
    return switch (brightness) {
      (Brightness.dark) => typography.white,
      (Brightness.light) => typography.black,
    };
  }

  DividerThemeData dividerThemeData() {
    return DividerThemeData(
      color: primarySafeColors.backgroundText,
      space: 4,
      thickness: 2,
      indent: 4,
      endIndent: 4,
    );
  }

  DrawerThemeData drawerThemeData() {
    return DrawerThemeData(
      backgroundColor: primarySafeColors.backgroundText,
      scrimColor: Colors.black.withOpacity(0.54),
      shadowColor: lstarFromArgb(primarySafeColors.background.value) > 60.0
          ? Colors.black
          : Colors.white,
      surfaceTintColor: primarySafeColors.background,
      shape: null,
      endShape: null,
      width: null /* use default value of Drawer.width */,
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
