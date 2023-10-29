import 'dart:ui';

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
  final SafeColors primary;
  final SafeColors secondary;
  final SafeColors tertiary;

  final double surfaceLstar;
  final double contrast;
  final Algo algo;

  final Brightness brightness;
  final Widget child;

  static const double buttonElevation = 16.0;
  static const double modalElevation = 2.0;

  /// The maximum width of any content panel.
  ///
  /// 1040 dp; 8.5" - 1" margins = 6.5" * 160 dp / in.
  static const double maxPanelWidth = 1040.0;
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
      primary: primarySafeColors,
      secondary: secondarySafeColors,
      tertiary: tertiarySafeColors,
      surfaceLstar: surfaceLstar,
      algo: algo,
      contrast: contrast,
      child: child,
    );
  }

  const MonetTheme({
    super.key,
    required this.brightness,
    required this.primary,
    required this.secondary,
    required this.tertiary,
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
    return _MonetInheritedTheme(
      theme: this,
      // Animated theme is actually worse for design, ex. when switching theme
      // color, the InputDecoration of a text field only acquires the correct
      // background color and text color at the end of animating.
      child: Theme(
        data: createThemeData(context),
        child: child,
      ),
    );
  }

  ThemeData createThemeData(BuildContext context) {
    final primaryColorLight =
        Hct.fromColor(primary.fill).tone > Hct.fromColor(primary.color).tone
            ? primary.fill
            : primary.color;
    final primaryColorDark =
        primaryColorLight == primary.fill ? primary.color : primary.fill;
    final colorScheme = _createColorScheme(
      brightness,
      primary,
      secondary,
      tertiary,
      contrast,
      algo,
      Hct.from(0, 0, surfaceLstar).color,
    );

    final typographyData = typography(colorScheme);
    final textTheme = createTextTheme(typographyData);

    final themeData = ThemeData(
      // Hack-y, idea is, in dark mode, apply on surface (usually lighter)
      // with opacity to surface to make elevated surfaces lighter. Doesn't
      // make sense once you don't only have opacity for lightening, but color.
      applyElevationOverlayColor: false,
      cupertinoOverrideTheme: null,
      extensions: [
        MonetColorScheme.fromSafeColors(
          primary: primary,
          secondary: secondary,
          tertiary: tertiary,
        ),
      ],
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
      canvasColor: primary.background,
      cardColor: primary.background,
      colorScheme: colorScheme,
      dialogBackgroundColor: primary.background,
      disabledColor: primary.color,
      dividerColor: primary.backgroundText,
      // colorHover only guarantees contrast with colorBorder
      focusColor: primary.fillHover,
      highlightColor: primary.fillSplash,
      hintColor: primary.backgroundText,
      hoverColor: primary.textHover,
      // ThemeData uses white if primary = secondary, otherwise, secondary
      primaryColor: primary.color,
      primaryColorDark: primaryColorDark,
      primaryColorLight: primaryColorLight,
      indicatorColor: secondary.fill,
      scaffoldBackgroundColor: primary.background,
      secondaryHeaderColor: secondary.backgroundText,
      // Avoid setting a default, as each widget may be a different color and
      // thus should be set explicitly.
      shadowColor: Colors.transparent,
      splashColor: primary.textSplash,
      // Material uses 70% white in dark mode, 54% black in light mode
      // Is transparency important? Where is this used?
      // For now, treat it like text
      unselectedWidgetColor: primary.backgroundText,
      iconTheme: iconThemeData(primary),
      primaryIconTheme: iconThemeData(primary),
      primaryTextTheme: textTheme,
      textTheme: textTheme,
      typography: typographyData,
      // BEGIN ALL THE ACCOUTREMENTS
      actionIconTheme: actionIconTheme(),
      appBarTheme: appBarTheme(primary, textTheme),
      badgeTheme: badgeThemeData(context, primary, textTheme),
      bannerTheme: bannerThemeData(primary, textTheme),
      bottomAppBarTheme: bottomAppBarTheme(primary),
      bottomNavigationBarTheme:
          bottomNavigationBarThemeData(primary, textTheme),
      bottomSheetTheme: bottomSheetThemeData(primary),
      buttonBarTheme: buttonBarThemeData(),
      buttonTheme: buttonThemeData(),
      cardTheme: cardTheme(primary),
      checkboxTheme: checkboxThemeData(primary),
      chipTheme: chipThemeData(brightness, primary, textTheme),
      dataTableTheme: dataTableThemeData(textTheme),
      datePickerTheme: datePickerThemeData(brightness, primary, textTheme),
      dialogTheme: createDialogTheme(primary, textTheme),
      dividerTheme: dividerThemeData(primary),
      drawerTheme: drawerThemeData(primary),
      dropdownMenuTheme: dropdownMenuThemeData(primary, textTheme),
      elevatedButtonTheme: elevatedButtonTheme(primary),
      expansionTileTheme: expansionTileThemeData(primary),
      filledButtonTheme: filledButtonTheme(primary),
      floatingActionButtonTheme: fabThemeData(primary, textTheme),
      iconButtonTheme: iconButtonThemeData(primary),
      inputDecorationTheme: inputDecorationTheme(primary, textTheme),
      listTileTheme: listTileThemeData(primary, textTheme),
      menuBarTheme: menuBarThemeData(primary),
      menuButtonTheme: menuButtonThemeData(primary),
      menuTheme: menuThemeData(primary),
      navigationBarTheme: navigationBarThemeData(primary, textTheme),
      navigationDrawerTheme: navigationDrawerThemeData(primary, textTheme),
      navigationRailTheme: navigationRailThemeData(primary, textTheme),
      outlinedButtonTheme: outlinedButtonTheme(primary),
      popupMenuTheme: popupMenuThemeData(primary, textTheme),
      progressIndicatorTheme: progressIndicatorThemeData(primary),
      radioTheme: radioThemeData(primary),
      searchBarTheme: searchBarThemeData(primary, textTheme),
      searchViewTheme: searchViewThemeData(primary, textTheme),
      segmentedButtonTheme: segmentedButtonThemeData(primary),
      sliderTheme: sliderThemeData(primary, textTheme),
      snackBarTheme: snackBarThemeData(primary, textTheme),
      switchTheme: switchThemeData(primary),
      tabBarTheme: createTabBarTheme(primary, textTheme),
      textButtonTheme: textButtonTheme(primary),
      textSelectionTheme: textSelectionThemeData(primary),
      timePickerTheme: timePickerThemeData(primary, textTheme),
      toggleButtonsTheme: toggleButtonsThemeData(primary, textTheme),
      tooltipTheme: tooltipThemeData(primary, textTheme),
    );
    final cupertinoOverrideTheme =
        MaterialBasedCupertinoThemeData(materialTheme: themeData);
    return themeData.copyWith(
      cupertinoOverrideTheme: cupertinoOverrideTheme,
    );
  }

  static ActionIconThemeData actionIconTheme() {
    // Provides platform default icons, just use default.
    return const ActionIconThemeData();
  }

  static AppBarTheme appBarTheme(SafeColors colors, TextTheme textTheme) {
    return AppBarTheme(
      titleTextStyle: textTheme.displayLarge,
      backgroundColor: colors.background,
      foregroundColor: colors.backgroundText,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    );
  }

  static BadgeThemeData badgeThemeData(
      BuildContext context, SafeColors colors, TextTheme textTheme) {
    return BadgeThemeData(
      backgroundColor: colors.fill,
      textColor: colors.fillText,
      // defaults, see badge.dart
      smallSize: 6.0,
      largeSize: 16.0,
      textStyle: textTheme.labelSmall!,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: AlignmentDirectional.topEnd,
      offset: Directionality.of(context) == TextDirection.ltr
          ? const Offset(4, -4)
          : const Offset(-4, -4),
    );
  }

  static MaterialBannerThemeData bannerThemeData(
      SafeColors colors, TextTheme textTheme) {
    return MaterialBannerThemeData(
      backgroundColor: colors.fill,
      surfaceTintColor: colors.fill,
      shadowColor: Colors.transparent,
      dividerColor: Colors.transparent,
      // Copy defaults from Banner.dart
      contentTextStyle: textTheme.bodyLarge!.copyWith(
        color: colors.fillText,
        fontWeight: FontWeight.w900,
        height: 1.0,
      ),
    );
  }

  static BottomAppBarTheme bottomAppBarTheme(SafeColors colors) {
    return BottomAppBarTheme(
      color: colors.background,
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

  static BottomSheetThemeData bottomSheetThemeData(SafeColors colors) {
    return BottomSheetThemeData(
      backgroundColor: colors.background,
      elevation: 0,
      modalBackgroundColor: colors.background,
      modalElevation: 0,
      shape: const RoundedRectangleBorder(),
      clipBehavior: Clip.none,
    );
  }

  static ButtonBarThemeData buttonBarThemeData() {
    // Go with defaults, most of the properties are about padding and spacing.
    return const ButtonBarThemeData(alignment: MainAxisAlignment.center);
  }

  static ButtonThemeData buttonThemeData() {
    // Go with defaults, most of the properties are about padding and spacing.
    return const ButtonThemeData();
  }

  static CardTheme cardTheme(SafeColors colors) {
    return CardTheme(
      clipBehavior: Clip.none, // match default
      color: colors.background,
      shadowColor: _singleShadowColorFor(colors.background),
      surfaceTintColor: colors.background,
      elevation: modalElevation,
      margin: const EdgeInsets.all(0), // match default
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: colors.fill, width: 2),
      ), // match default
    );
  }

  static CheckboxThemeData checkboxThemeData(SafeColors colors) {
    return CheckboxThemeData(
      mouseCursor: const MaterialStatePropertyAll(
          null), // allows widget to default to clickable
      fillColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return colors.fill;
        } else if (states.contains(MaterialState.hovered)) {
          return colors.textHover;
        } else if (states.contains(MaterialState.pressed)) {
          return colors.textSplash;
        } else {
          return colors.background;
        }
      }),
      // Even though it is an icon, it is displayed very small, text is a better
      // fit (icon implies a height of 40 dp / 18 pt in parlance of WCAG 2.1)
      checkColor: MaterialStateProperty.all(colors.fillText),
      overlayColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return colors.textHover;

          // Note 1:
          // Even though this is "wrong", i.e. the checkbox is filled,
          // Checkbox is unique in that its overlay isn't actually displayed in
          // the component, but around it. It feels more accurate to use the
          // same overlay color as when it is not selected.
          //
          // Note 2: Other states aren't respected here, even if supplied. Ex.
          // selected doesn't distinguish between being hovered and pressed.
        } else if (states.contains(MaterialState.hovered)) {
          return colors.textHover;
        } else if (states.contains(MaterialState.pressed)) {
          return colors.textSplash;
        } else {
          return colors.background;
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
        color: colors.fill,
      ), // match default
    );
  }

  static ChipThemeData chipThemeData(
    Brightness brightness,
    SafeColors colors,
    TextTheme textTheme,
  ) {
    return ChipThemeData.fromDefaults(
      brightness: brightness,
      secondaryColor: colors.color,
      labelStyle: textTheme.bodyMedium!.copyWith(
        color: colors.colorText,
      ),
    ).copyWith(
      checkmarkColor: MaterialStateColor.resolveWith((states) {
        return colors.fill;
      }),
      surfaceTintColor: MaterialStateColor.resolveWith((states) {
        return colors.background;
      }),
      selectedColor: Colors
          .transparent, // messes everything up because FG can't be set based on state
      secondarySelectedColor: colors.textHover,
      secondaryLabelStyle:
          textTheme.labelLarge!.copyWith(color: colors.textHoverText),
      side: BorderSide(width: 2, color: colors.fill),
      backgroundColor: colors.background,
      labelStyle: textTheme.labelLarge!.copyWith(
        color: colors.text,
      ),
    );
  }

  static DataTableThemeData dataTableThemeData(TextTheme textTheme) {
    return DataTableThemeData(
      columnSpacing: 16, // Material default is __56__
      dataTextStyle: textTheme.bodyMedium!.copyWith(fontFeatures: [
        const FontFeature.tabularFigures(),
        const FontFeature.slashedZero()
      ]),
      dividerThickness: 1.0,
      headingTextStyle: textTheme.headlineMedium,
      headingRowColor: MaterialStateProperty.all(Colors.transparent),
      dataRowMinHeight: touchSize,
      dataRowMaxHeight: double.infinity,
      headingRowHeight: (textTheme.headlineMedium!.fontSize! *
          (textTheme.headlineMedium!.height ?? 1.0)) + 8 /* 4 dp vertical adding */,
    );
  }

  static DatePickerThemeData datePickerThemeData(
    Brightness brightness,
    SafeColors colors,
    TextTheme textTheme,
  ) {
    final background = MaterialStateProperty.resolveWith(
      (states) {
        if (states.contains(MaterialState.hovered)) {
          return colors.textHover;
        } else if (states.contains(MaterialState.pressed)) {
          return colors.textSplash;
        } else if (states.contains(MaterialState.selected)) {
          return colors.color;
        } else {
          return Colors.transparent;
        }
      },
    );
    final foreground = MaterialStateProperty.resolveWith(
      (states) {
        if (states.contains(MaterialState.selected)) {
          return colors.colorText;
        } else {
          return colors.backgroundText;
        }
      },
    );
    final fillText = MaterialStateProperty.resolveWith(
      (states) {
        if (states.contains(MaterialState.hovered)) {
          return colors.fillHoverText;
        } else if (states.contains(MaterialState.pressed)) {
          return colors.fillSplashText;
        } else if (states.contains(MaterialState.selected)) {
          return colors.fillSplashText;
        } else {
          return colors.fillText;
        }
      },
    );
    final shadowColor = _singleShadowColorFor(colors.background);
    return DatePickerThemeData(
      backgroundColor: colors.background,
      elevation: null /* will match Dialog.elevation */,
      shadowColor: shadowColor,
      surfaceTintColor: colors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      headerBackgroundColor: colors.color,
      headerForegroundColor: colors.colorText,
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
        color: colors.fill,
      ),
      yearStyle: textTheme.headlineMedium,
      yearBackgroundColor: background,
      yearForegroundColor: foreground,
      yearOverlayColor: background,
      rangePickerBackgroundColor: colors.background,
      rangePickerElevation: 0,
      rangePickerShadowColor: shadowColor,
      rangePickerSurfaceTintColor: colors.background,
      rangePickerShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      rangePickerHeaderBackgroundColor: colors.color,
      rangePickerHeaderForegroundColor: colors.colorText,
      rangePickerHeaderHeadlineStyle: textTheme.headlineMedium,
      rangePickerHeaderHelpStyle: textTheme.headlineSmall,
      rangeSelectionBackgroundColor: colors.fill,
      rangeSelectionOverlayColor: fillText,
      dividerColor: Colors.transparent,
      inputDecorationTheme: null, // if null, uses ThemeData's
    );
  }

  static DialogTheme createDialogTheme(SafeColors colors, TextTheme textTheme) {
    return DialogTheme(
      backgroundColor: colors.background,
      elevation: modalElevation,
      shadowColor: _singleShadowColorFor(colors.background),
      surfaceTintColor: colors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: null,
      iconColor: colors.fill,
      titleTextStyle: textTheme.headlineMedium,
      contentTextStyle: textTheme.bodyMedium,
      actionsPadding:
          null, // don't override default in AlertDialog.actionsPading
    );
  }

  static DropdownMenuThemeData dropdownMenuThemeData(
    SafeColors colors,
    TextTheme textTheme,
  ) {
    return DropdownMenuThemeData(
      inputDecorationTheme: const InputDecorationTheme(
        fillColor: Colors.red,
        filled: true,
      ),
      textStyle: textTheme.bodyMedium!.copyWith(color: colors.text),
      menuStyle: createMenuStyleForDropdown(colors),
    );
  }

  static ElevatedButtonThemeData elevatedButtonTheme(SafeColors colors) {
    return ElevatedButtonThemeData(
      style: elevatedButtonStyleFromColors(colors),
    );
  }

  static ExpansionTileThemeData expansionTileThemeData(SafeColors colors) {
    return ExpansionTileThemeData(
      backgroundColor: colors.background,
      collapsedBackgroundColor: colors.background,
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      /* Match default */
      expandedAlignment: Alignment.center,
      childrenPadding: EdgeInsets.zero,
      iconColor: colors.text,
      collapsedIconColor: colors.text,
      textColor: colors.text,
      collapsedTextColor: colors.text,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: colors.fill,
          width: 2,
        ),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: colors.fill,
          width: 2,
        ),
      ),
    );
  }

  static FilledButtonThemeData filledButtonTheme(SafeColors colors) {
    return FilledButtonThemeData(style: filledButtonFromColor(colors));
  }

  static FloatingActionButtonThemeData fabThemeData(
      SafeColors colors, TextTheme textTheme) {
    return FloatingActionButtonThemeData(
      foregroundColor: MaterialStateColor.resolveWith((states) {
        if (states.contains(MaterialState.pressed)) {
          return colors.colorSplashText;
        } else if (states.contains(MaterialState.hovered)) {
          return colors.colorHoverText;
        } else {
          return colors.colorText;
        }
      }),
      backgroundColor: MaterialStateColor.resolveWith((states) {
        if (states.contains(MaterialState.pressed)) {
          return colors.colorSplash;
        } else if (states.contains(MaterialState.hovered)) {
          return colors.colorHover;
        } else {
          return colors.color;
        }
      }),
      focusColor: colors.colorHover,
      hoverColor: colors.colorHover,
      splashColor: colors.colorSplash,
      elevation: buttonElevation,
      focusElevation: buttonElevation,
      hoverElevation: buttonElevation,
      highlightElevation: buttonElevation,
      disabledElevation: buttonElevation,
      shape: CircleBorder(
        side: BorderSide(
          color: colors.colorBorder,
          width: 2,
        ),
      ),
      enableFeedback: true,
      iconSize: 24,
      extendedTextStyle:
          textTheme.bodyMedium!.copyWith(color: colors.colorText),
      /* size constraints not included */
    );
  }

  static IconButtonThemeData iconButtonThemeData(SafeColors colors) {
    return IconButtonThemeData(
      style: iconButtonStyleFromColors(colors),
    );
  }

  static ListTileThemeData listTileThemeData(
      SafeColors colors, TextTheme textTheme) {
    return ListTileThemeData(
      dense: true,
      shape: null,
      style: ListTileStyle.list,
      selectedColor: colors.fillHover,
      iconColor: colors.fill,
      textColor: colors.text,
      titleTextStyle: textTheme.titleSmall!.copyWith(color: colors.text),
      subtitleTextStyle: textTheme.bodyLarge!.copyWith(color: colors.text),
      leadingAndTrailingTextStyle:
          textTheme.bodyMedium!.copyWith(color: colors.text),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
      tileColor: colors.background,
      selectedTileColor: colors.fillHover,
      horizontalTitleGap: 16,
      minVerticalPadding: 4,
      minLeadingWidth: 40,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      titleAlignment: ListTileTitleAlignment.threeLine,
    );
  }

  static MenuBarThemeData menuBarThemeData(SafeColors colors) {
    return MenuBarThemeData(
      style: createMenuStyleForMenuBar(colors),
    );
  }

  static MenuStyle createMenuStyleForDropdown(SafeColors colors) {
    return MenuStyle(
      backgroundColor: MaterialStatePropertyAll(colors.background),
      shadowColor: MaterialStateProperty.all(Colors.transparent),
      surfaceTintColor: MaterialStatePropertyAll(colors.background),
      elevation: const MaterialStatePropertyAll(modalElevation),
      side: MaterialStatePropertyAll(
        BorderSide(
          color: colors.colorBorder,
          width: 2,
        ),
      ),
      padding: const MaterialStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
      shape: MaterialStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: colors.colorBorder,
            width: 2,
          ),
        ),
      ),
    );
  }

  static MenuStyle createMenuStyleForMenuBar(SafeColors colors) {
    return MenuStyle(
      backgroundColor: MaterialStatePropertyAll(colors.background),
      shadowColor: MaterialStateProperty.all(Colors.transparent),
      surfaceTintColor: MaterialStatePropertyAll(colors.background),
      elevation: const MaterialStatePropertyAll(modalElevation),
      padding: const MaterialStatePropertyAll(EdgeInsets.zero),
      shape: const MaterialStatePropertyAll(null),
    );
  }

  static MenuButtonThemeData menuButtonThemeData(SafeColors colors) {
    return MenuButtonThemeData(
      style: textButtonStyleFromColors(colors).copyWith(
        padding: MaterialStateProperty.all(const EdgeInsets.all(4)),
        shape: MaterialStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  static MenuThemeData menuThemeData(SafeColors colors) {
    return MenuThemeData(
      style: createMenuStyleForDropdown(colors),
    );
  }

  static NavigationBarThemeData navigationBarThemeData(
      SafeColors colors, TextTheme textTheme) {
    return NavigationBarThemeData(
      height: 80, // match default
      backgroundColor: colors.background,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: colors.background,
      indicatorColor: colors.fill,
      indicatorShape: const StadiumBorder(), // match default
      labelTextStyle:
          MaterialStateProperty.resolveWith((Set<MaterialState> states) {
        final TextStyle style = textTheme.labelSmall!;
        return style.apply(
          color: states.contains(MaterialState.selected)
              ? colors.text
              : colors.backgroundText,
        );
      }),
      iconTheme: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return IconThemeData(color: colors.fillIcon);
        } else {
          // not supported by component, i.e. none of the other states are
          // ever passed via [states]
        }
        return IconThemeData(color: colors.backgroundText);
      }),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      /* size constraints not included */
    );
  }

  static BottomNavigationBarThemeData bottomNavigationBarThemeData(
      SafeColors colors, TextTheme textTheme) {
    return BottomNavigationBarThemeData(
      backgroundColor: colors.background,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
      // If this isn't specified, text becomes tertiary something...
      selectedItemColor: colors.text,
      unselectedItemColor: colors.backgroundText,
      selectedIconTheme: iconThemeData(colors),
      unselectedIconTheme: iconThemeData(colors),
      selectedLabelStyle:
          textTheme.labelSmall!.copyWith(color: colors.fillText),
      unselectedLabelStyle:
          textTheme.labelSmall!.copyWith(color: colors.backgroundText),
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

  static NavigationDrawerThemeData navigationDrawerThemeData(
      SafeColors colors, TextTheme textTheme) {
    return NavigationDrawerThemeData(
      tileHeight: 56,
      /* match _NavigationDrawerDefaultsM3 */
      backgroundColor: colors.background,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: colors.background,
      indicatorColor: colors.fill,
      indicatorShape: const StadiumBorder(), // match default
      labelTextStyle:
          MaterialStateProperty.resolveWith((Set<MaterialState> states) {
        final TextStyle style = textTheme.labelMedium!;
        return style.apply(
          color: states.contains(MaterialState.selected)
              ? colors.text
              : colors.backgroundText,
        );
      }),
    );
  }

  static NavigationRailThemeData navigationRailThemeData(
      SafeColors colors, TextTheme textTheme) {
    return NavigationRailThemeData(
      backgroundColor: colors.background,
      elevation: 0,
      unselectedLabelTextStyle:
          textTheme.labelMedium!.copyWith(color: colors.backgroundText),
      selectedLabelTextStyle:
          textTheme.labelMedium!.copyWith(color: colors.text),
      unselectedIconTheme:
          iconThemeData(colors).copyWith(color: colors.backgroundText),
      selectedIconTheme: iconThemeData(colors).copyWith(color: colors.fillIcon),
      groupAlignment: -1.0, // match default, top
      labelType: NavigationRailLabelType.all,
      useIndicator: true,
      indicatorColor: colors.fill,
      indicatorShape: const StadiumBorder(), // match default
      minWidth: 72, // match default
      minExtendedWidth: 256, // match default
    );
  }

  static OutlinedButtonThemeData outlinedButtonTheme(SafeColors colors) {
    return OutlinedButtonThemeData(
      style: outlineButtonStyleFromColors(colors),
    );
  }

  static PopupMenuThemeData popupMenuThemeData(
      SafeColors colors, TextTheme textTheme) {
    return PopupMenuThemeData(
      color: colors.background, // Popup background
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: colors.fill,
          width: 2,
        ),
      ),
      elevation: modalElevation, // Popup outline elevation
      shadowColor: _singleShadowColorFor(colors.background),
      surfaceTintColor: colors.background,
      textStyle: textTheme.bodyMedium,
      labelTextStyle: MaterialStateProperty.resolveWith((states) {
        // Doesn't support hover or selected, only disabled, which we do not
        // specify.
        return textTheme.labelMedium!.apply(color: colors.backgroundText);
      }),
      enableFeedback: true,
      position: PopupMenuPosition.under,
    );
  }

  static ProgressIndicatorThemeData progressIndicatorThemeData(
      SafeColors colors) {
    return ProgressIndicatorThemeData(
      color: colors.fill,
      linearTrackColor: colors.background,
      linearMinHeight: 4,
      circularTrackColor: colors.background,
      refreshBackgroundColor: colors.background,
    );
  }

  static RadioThemeData radioThemeData(SafeColors colors) {
    // States have choices that look odd compared to other components.
    // This component is particularly challenging due to it being essentially
    // a fill with a circle surrounding it for hover state. These were
    // picked thoughtfully.
    return RadioThemeData(
      fillColor: MaterialStateProperty.resolveWith(
        (Set<MaterialState> states) {
          if (states.contains(MaterialState.hovered)) {
            return colors.textHoverText;
          }
          if (states.contains(MaterialState.selected)) {
            return colors.text;
          }
          return colors.text;
        },
      ),
      overlayColor: MaterialStateProperty.resolveWith(
        (Set<MaterialState> states) {
          return colors.textHover;
        },
      ),
      splashRadius: 20.0, // match checkbox default,
      materialTapTargetSize: null, // let Theme manage it
      visualDensity: null, // let Theme manage it
    );
  }

  static SearchBarThemeData searchBarThemeData(
      SafeColors colors, TextTheme textTheme) {
    return SearchBarThemeData(
      elevation: const MaterialStatePropertyAll(2),
      backgroundColor: MaterialStatePropertyAll(colors.background),
      shadowColor: MaterialStatePropertyAll(colors.background),
      surfaceTintColor: MaterialStatePropertyAll(colors.background),
      overlayColor: MaterialStatePropertyAll(colors.background),
      side: MaterialStatePropertyAll(
        BorderSide(
          color: colors.fill,
          width: 2,
        ),
      ),
      shape: MaterialStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: colors.fill,
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

  static SearchViewThemeData searchViewThemeData(
      SafeColors colors, TextTheme textTheme) {
    return SearchViewThemeData(
      backgroundColor: colors.background,
      elevation: modalElevation,
      surfaceTintColor: colors.background,
      constraints: const BoxConstraints(
          minWidth: 360.0, maxWidth: 800.0, minHeight: 56.0),
      side: BorderSide(color: colors.fill, width: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: colors.fill,
          width: 2,
        ),
      ),
      headerTextStyle: textTheme.headlineMedium,
      headerHintStyle: textTheme.headlineSmall,
      dividerColor: colors.backgroundText,
    );
  }

  static SegmentedButtonThemeData segmentedButtonThemeData(SafeColors colors) {
    // Button style in-lined due to unique requirements, essentially, a text
    // button when not selected, fillbutton when selected.
    final selectedBackground = stateColors(
      color: colors.fill,
      hover: colors.fillHover,
      splash: colors.fillSplash,
    );
    final unselectedBackground = stateColors(
      color: colors.background,
      hover: colors.textHover,
      splash: colors.textSplash,
    );
    final background = MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.selected)) {
        return selectedBackground.resolve(states);
      } else {
        return unselectedBackground.resolve(states);
      }
    });
    final selectedForeground = stateColors(
      color: colors.fillText,
      hover: colors.fillHoverText,
      splash: colors.fillSplashText,
    );
    final unselectedForeground = stateColors(
      color: colors.backgroundText,
      hover: colors.textHoverText,
      splash: colors.textSplashText,
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
        BorderSide(color: colors.colorBorder, width: 2),
      ),
    ));
  }

  static SliderThemeData sliderThemeData(
      SafeColors colors, TextTheme textTheme) {
    return SliderThemeData(
      overlayShape: const RoundSliderOverlayShape(),
      tickMarkShape: SliderTickMarkShape.noTickMark,
      thumbShape: SliderFlatThumb(
        borderWidth: 2,
        borderColor: colors.colorBorder,
      ),
      trackShape: SliderFlatShape(),
      trackHeight: touchSize,
      activeTrackColor: colors.color,
      // This is a _nice_ touch: ex. if an elevated button is above this slider,
      // the shadow isn't cut off
      inactiveTrackColor: Colors.transparent,
      secondaryActiveTrackColor: colors.color,
      disabledActiveTrackColor: colors.color,
      disabledInactiveTrackColor: colors.background,
      disabledSecondaryActiveTrackColor: colors.color,
      // Tick marks mess up SliderFlat, aka a Slider with a border.
      activeTickMarkColor: Colors.transparent,
      inactiveTickMarkColor: Colors.transparent,
      disabledActiveTickMarkColor: Colors.transparent,
      disabledInactiveTickMarkColor: Colors.transparent,
      thumbColor: colors.color,
      overlappingShapeStrokeColor: colors.fillText,
      disabledThumbColor: colors.color,
      overlayColor: Colors.transparent,
      valueIndicatorColor: colors.color,
      valueIndicatorShape: const DropSliderValueIndicatorShape(),
      rangeTickMarkShape: const RoundRangeSliderTickMarkShape(),
      rangeThumbShape: const RoundRangeSliderThumbShape(),
      rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
      rangeValueIndicatorShape: const PaddleRangeSliderValueIndicatorShape(),
      showValueIndicator: ShowValueIndicator.always,
      valueIndicatorTextStyle: textTheme.labelLarge!.copyWith(
        color: colors.colorText,
      ),
      minThumbSeparation: 8,
      allowedInteraction: SliderInteraction.tapAndSlide,
    );
  }

  static SnackBarThemeData snackBarThemeData(
      SafeColors colors, TextTheme textTheme) {
    return SnackBarThemeData(
      backgroundColor: colors.color,
      actionTextColor: colors.colorText,
      disabledActionTextColor: colors.colorText,
      contentTextStyle: textTheme.bodyMedium!.copyWith(color: colors.colorText),
      elevation: modalElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: colors.colorBorder,
          width: 2,
        ),
      ),

      behavior: SnackBarBehavior.floating,
      width: null, // allows use of margin instead
      insetPadding: const EdgeInsets.fromLTRB(15.0, 5.0, 15.0, 10.0),
      showCloseIcon: true,
      closeIconColor: colors.colorIcon,
      actionOverflowThreshold:
          0.25, // match default,  the percentage threshold for action widget's width before it overflows  to a new line.
      actionBackgroundColor: colors.color,
      disabledActionBackgroundColor: colors.color,
    );
  }

  static SwitchThemeData switchThemeData(SafeColors colors) {
    return SwitchThemeData(
      thumbColor: MaterialStatePropertyAll(colors.fill),
      trackColor: MaterialStatePropertyAll(colors.background),
      trackOutlineColor: MaterialStatePropertyAll(colors.fill),
      trackOutlineWidth: const MaterialStatePropertyAll(2.0),
      materialTapTargetSize: null, // let Theme manage it
      mouseCursor: null, // let Theme manage it
      overlayColor: MaterialStateProperty.resolveWith(
        (Set<MaterialState> states) {
          if (states.contains(MaterialState.selected)) {
            return colors.fillSplash;
          } else if (states.contains(MaterialState.hovered)) {
            return colors.fillHover;
          } else if (states.contains(MaterialState.pressed)) {
            return colors.fillSplash;
          } else {
            return colors.fill;
          }
        },
      ),
      splashRadius: 20.0, // match checkbox default,
      thumbIcon: MaterialStateProperty.resolveWith(
        (Set<MaterialState> states) {
          if (states.contains(MaterialState.selected)) {
            return Icon(
              Icons.check_outlined,
              color: colors.colorSplashText,
            );
          } else {
            return null;
          }
        },
      ),
    );
  }

  static TabBarTheme createTabBarTheme(SafeColors colors, TextTheme textTheme) {
    final labelColor = MaterialStateColor.resolveWith((states) {
      if (states.contains(MaterialState.selected)) {
        return colors.text;
      } else if (states.contains(MaterialState.hovered)) {
        return colors.textHoverText;
      } else if (states.contains(MaterialState.pressed)) {
        return colors.textSplashText;
      } else {
        return colors.backgroundText;
      }
    });
    return TabBarTheme(
      // Oddly, this still is required even if indicatorColor is set.
      indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: colors.fill, width: 2)),
      indicatorColor: colors.fill,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      labelColor: colors.fill,
      labelStyle: textTheme.labelMedium,
      unselectedLabelColor: labelColor,
      unselectedLabelStyle: textTheme.labelMedium,
      overlayColor: MaterialStateProperty.resolveWith(
        (Set<MaterialState> states) {
          if (states.contains(MaterialState.selected)) {
            return colors.textSplash;
          } else if (states.contains(MaterialState.hovered)) {
            return colors.textHover;
          } else if (states.contains(MaterialState.pressed)) {
            return colors.textSplash;
          } else {
            return colors.background;
          }
        },
      ),
      splashFactory: splashFactory,
      mouseCursor: null, // use default view
      tabAlignment: TabAlignment.fill,
    );
  }

  TextButtonThemeData textButtonTheme(SafeColors colors) {
    return TextButtonThemeData(
      style: textButtonStyleFromColors(colors),
    );
  }

  static TextSelectionThemeData textSelectionThemeData(SafeColors colors) {
    return TextSelectionThemeData(
      cursorColor: colors.fill,
      // Can't induce text to use textHoverText, so instead, use opacity to
      // introduce some effect, but not so much so that contrast between
      // text and the selection color is jarringly low.
      selectionColor: colors.text.withOpacity(0.4),
      selectionHandleColor: colors.fill,
    );
  }

  static TimePickerThemeData timePickerThemeData(
      SafeColors colors, TextTheme textTheme) {
    return TimePickerThemeData(
      backgroundColor: colors.background,
      cancelButtonStyle: outlineButtonStyleFromColors(colors),
      confirmButtonStyle: filledButtonFromColor(colors),
      dayPeriodBorderSide: BorderSide(
        color: colors.fill,
        width: 2,
      ),

      dayPeriodShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: colors.fill,
          width: 2,
        ),
      ),
      dayPeriodTextColor: MaterialStateColor.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return colors.fillText;
        } else {
          return colors.backgroundText;
        }
      }),
      dayPeriodTextStyle: textTheme.labelLarge,
      dialBackgroundColor: colors.fill,
      dialHandColor: colors.fillText.withOpacity(0.4),
      dialTextColor: colors.fillText,
      dialTextStyle: textTheme.labelLarge!.copyWith(color: colors.fillText),
      elevation: modalElevation,
      entryModeIconColor: colors.fill,
      helpTextStyle: textTheme.headlineSmall,
      dayPeriodColor: MaterialStateColor.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return colors.fill;
        } else {
          return colors.background;
        }
      }),
      hourMinuteColor: MaterialStateColor.resolveWith((states) {
        if (states.contains(MaterialState.hovered)) {
          return colors.fillHover;
        } else if (states.contains(MaterialState.pressed)) {
          return colors.fillSplash;
        } else if (states.contains(MaterialState.selected)) {
          return colors.fill;
        } else {
          return colors.background;
        }
      }),
      hourMinuteShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: colors.fill,
          width: 2,
        ),
      ),
      hourMinuteTextColor: MaterialStateColor.resolveWith((states) {
        if (states.contains(MaterialState.hovered)) {
          return colors.fillHoverText;
        } else if (states.contains(MaterialState.pressed)) {
          return colors.fillSplashText;
        } else if (states.contains(MaterialState.selected)) {
          return colors.fillText;
        } else {
          return colors.backgroundText;
        }
      }),
      inputDecorationTheme: null, // let picker use its defaults
      padding: const EdgeInsets.all(24), // match default in time_picker.dart
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: colors.fill,
          width: 2,
        ),
      ),
    );
  }

  static ToggleButtonsThemeData toggleButtonsThemeData(
      SafeColors colors, TextTheme textTheme) {
    return ToggleButtonsThemeData(
      textStyle: textTheme.bodyMedium,
      constraints: const BoxConstraints(
        minWidth: touchSize,
        minHeight: touchSize - 8,
      ),
      color: MaterialStateColor.resolveWith((states) {
        // States are always empty.
        return colors.text;
      }),
      selectedColor: MaterialStateColor.resolveWith((states) {
        return colors.colorText;
      }),
      disabledColor: colors.text,
      fillColor: colors.color,
      focusColor: colors.colorHover,
      highlightColor: colors.fillHover,
      hoverColor: MaterialStateColor.resolveWith((states) {
        return colors.textHover;
      }),
      splashColor: colors.fillSplash,
      borderColor: colors.colorBorder,
      selectedBorderColor: colors.colorBorder,
      disabledBorderColor: colors.colorBorder,
      borderRadius: BorderRadius.circular(8),
      borderWidth: 2,
    );
  }

  static TooltipThemeData tooltipThemeData(
      SafeColors colors, TextTheme textTheme) {
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
            color: colors.colorBorder,
            width: 2,
          ),
        ),
        color: colors.color,
      ),
      textStyle: textTheme.bodyMedium!.copyWith(color: colors.colorText),
      textAlign: TextAlign.center,
      showDuration: const Duration(seconds: 2),
      waitDuration: const Duration(seconds: 1),
      triggerMode: TooltipTriggerMode.longPress,
      enableFeedback: true,
    );
  }

  static InputDecorationTheme inputDecorationTheme(
      SafeColors colors, TextTheme textTheme) {
    final border = OutlineInputBorder(
      borderSide: BorderSide(width: 2, color: colors.fill),
      borderRadius: BorderRadius.circular(8),
    );
    final focusedBorder = OutlineInputBorder(
      borderSide: BorderSide(width: 3, color: colors.text),
      borderRadius: BorderRadius.circular(8),
    );
    return InputDecorationTheme(
      isCollapsed: true,
      isDense: true,
      fillColor: colors.background,
      filled: true,
      border: border,
      focusedBorder: focusedBorder,
      enabledBorder: border,
      hintStyle: textTheme.labelLarge!.copyWith(color: colors.text),
      helperStyle: textTheme.labelLarge!.copyWith(color: colors.text),
      labelStyle: textTheme.labelMedium!
          .copyWith(color: colors.text)
          .copyWith(fontWeight: FontWeight.w700),
      // Can't specify text in hover state: introduce some change in the
      // background, but not so much as to make the text unreadable, as
      // primarySafeColors.textHover would do.
      hoverColor: colors.text.withOpacity(0.2),
    );
  }

  static IconThemeData iconThemeData(SafeColors colors) {
    return IconThemeData(
      size: 24.0,
      fill: 0.0,
      weight: 400.0,
      grade: 0.0,
      opticalSize: 48.0,
      shadows: const [],
      color: colors.fill,
      opacity: 1,
    );
  }

  ScrollbarThemeData scrollbarThemeData() {
    const thickness = 4.0;
    return ScrollbarThemeData(
      thumbVisibility: const MaterialStatePropertyAll(true),
      thickness: const MaterialStatePropertyAll(thickness),
      trackVisibility: const MaterialStatePropertyAll(true),
      radius: const Radius.circular(thickness / 2.0),
      thumbColor: MaterialStatePropertyAll(secondary.fill.withOpacity(0.8)),
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
    final tt = switch (brightness) {
      (Brightness.dark) => typography.white,
      (Brightness.light) => typography.black,
    };

    final txtC = primary.backgroundText;
    const h = null;
    const med = FontWeight.w500;
    final textTheme = tt.copyWith(
      displayLarge: tt.displayLarge!.copyWith(
          fontSize: 24,
          color: primary.backgroundText,
          fontWeight: FontWeight.w500,
          height: 1.5),
      displayMedium: tt.displayMedium!
          .copyWith(fontSize: 22, color: txtC, fontWeight: med, height: h),
      displaySmall: tt.displaySmall!
          .copyWith(fontSize: 20, color: txtC, fontWeight: med, height: h),
      headlineLarge: tt.headlineLarge!
          .copyWith(fontSize: 20, color: txtC, fontWeight: med, height: h),
      headlineMedium: tt.headlineMedium!
          .copyWith(fontSize: 18, color: txtC, fontWeight: med, height: h),
      headlineSmall: tt.headlineSmall!
          .copyWith(fontSize: 16, color: txtC, fontWeight: med, height: h),
      bodyLarge: tt.bodyLarge!.copyWith(fontSize: 16, color: txtC, height: h),
      bodyMedium: tt.bodyMedium!.copyWith(fontSize: 14, color: txtC, height: h),
      bodySmall: tt.bodySmall!.copyWith(fontSize: 12, color: txtC, height: h),
      labelLarge: tt.labelLarge!.copyWith(
          fontSize: 16, color: txtC, fontWeight: FontWeight.w500, height: h),
      labelMedium:
          tt.labelMedium!.copyWith(fontSize: 14, color: txtC, height: h),
      labelSmall: tt.labelSmall!.copyWith(fontSize: 12, color: txtC, height: h),
    );
    return textTheme;
  }

  DividerThemeData dividerThemeData(SafeColors colors) {
    return DividerThemeData(
      color: colors.backgroundText,
      space: 4,
      thickness: 2,
      indent: 4,
      endIndent: 4,
    );
  }

  DrawerThemeData drawerThemeData(SafeColors colors) {
    return DrawerThemeData(
      backgroundColor: colors.backgroundText,
      scrimColor: Colors.black.withOpacity(0.54),
      shadowColor: _singleShadowColorFor(colors.background),
      surfaceTintColor: colors.background,
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
      primary: theme.primary,
      secondary: theme.secondary,
      tertiary: theme.tertiary,
      surfaceLstar: theme.surfaceLstar,
      contrast: theme.contrast,
      algo: theme.algo,
      child: child,
    );
  }

  @override
  bool updateShouldNotify(_MonetInheritedTheme old) => theme != old.theme;
}

ColorScheme _createColorScheme(
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

Color _singleShadowColorFor(Color color) {
  return lstarFromArgb(color.value).round() >= 60 ? Colors.black : Colors.white;
}
