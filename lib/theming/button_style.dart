import 'package:flutter/material.dart';
import 'package:libmonet/safe_colors.dart';
import 'package:libmonet/theming/monet_theme_data.dart';

extension SafeColorsButtonStyle on ButtonStyle {
  static ButtonStyle fromSafeColorsColor(SafeColors safeColors) {
    return ButtonStyle(
      backgroundColor: MaterialStateProperty.all(safeColors.color),
      overlayColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.hovered)) {
          return safeColors.colorHover;
        } else if (states.contains(MaterialState.pressed)) {
          return safeColors.colorSplash;
        } else if (states.contains(MaterialState.focused)) {
          return safeColors.colorHover;
        }
        return Colors.transparent;
      }),
      foregroundColor: MaterialStateProperty.all(safeColors.colorText),
      shadowColor: MaterialStateProperty.all(safeColors.colorBorder),
      elevation: MaterialStateProperty.all(0),
      side: MaterialStateProperty.all(
          BorderSide(color: safeColors.colorBorder, width: 2)),
    );
  }
}

MaterialStateProperty<Color> stateColors(
    {required Color color, required Color hover, required Color splash}) {
  return MaterialStateProperty.resolveWith((states) {
    if (states.contains(MaterialState.pressed)) {
      return splash;
    } else if (states.contains(MaterialState.focused) ||
        states.contains(MaterialState.hovered)) {
      return hover;
    }
    return color;
  });
}

ButtonStyle elevatedButtonStyleFromColors(SafeColors safeColors,
    {double elevation = MonetThemeData.buttonElevation}) {
  return filledButtonBackgroundIsColor(safeColors).copyWith(
    elevation: MaterialStatePropertyAll(elevation),
  );
}

ButtonStyle filledButtonBackgroundIsBackground(SafeColors safeColors,
    {TextStyle? textStyle}) {
  final alwaysSurface = stateColors(
    color: safeColors.background,
    hover: safeColors.background,
    splash: safeColors.background,
  );
  return ButtonStyle(
    backgroundColor: alwaysSurface,
    surfaceTintColor: alwaysSurface,
    overlayColor: stateColors(
      color: safeColors.background,
      hover: safeColors.textHover,
      splash: safeColors.textSplash,
    ),
    foregroundColor: stateColors(
      color: safeColors.text,
      hover: safeColors.textHoverText,
      splash: safeColors.textSplashText,
    ),
    textStyle: textStyle != null
        ? MaterialStateProperty.all(textStyle)
        : MaterialStateProperty.all(null),
    side: MaterialStateProperty.all(
      BorderSide(color: safeColors.colorBorder, width: 2),
    ),
  );
}

ButtonStyle filledButtonBackgroundIsFill(SafeColors safeColors,
    {TextStyle? textStyle}) {
  final alwaysSurface = stateColors(
    color: safeColors.fill,
    hover: safeColors.fill,
    splash: safeColors.fill,
  );
  return ButtonStyle(
    backgroundColor: alwaysSurface,
    surfaceTintColor: alwaysSurface,
    overlayColor: stateColors(
      color: safeColors.fill,
      hover: safeColors.fillHover,
      splash: safeColors.fillSplash,
    ),
    foregroundColor: stateColors(
      color: safeColors.fillText,
      hover: safeColors.fillHoverText,
      splash: safeColors.fillSplashText,
    ),
    textStyle: textStyle != null
        ? MaterialStateProperty.all(textStyle)
        : MaterialStateProperty.all(null),
    side: MaterialStateProperty.all(
      BorderSide(color: safeColors.colorBorder, width: 2),
    ),
  );
}

ButtonStyle filledButtonBackgroundIsColor(SafeColors safeColors,
    {TextStyle? textStyle}) {
  final alwaysSurface = stateColors(
    color: safeColors.color,
    hover: safeColors.color,
    splash: safeColors.color,
  );
  return ButtonStyle(
    backgroundColor: alwaysSurface,
    surfaceTintColor: alwaysSurface,
    overlayColor: stateColors(
      color: safeColors.color,
      hover: safeColors.colorHover,
      splash: safeColors.colorSplash,
    ),
    foregroundColor: stateColors(
      color: safeColors.colorText,
      hover: safeColors.colorHoverText,
      splash: safeColors.colorSplashText,
    ),
    textStyle: textStyle != null
        ? MaterialStateProperty.all(textStyle)
        : MaterialStateProperty.all(null),
    side: MaterialStateProperty.all(
      BorderSide(color: safeColors.colorBorder, width: 2),
    ),
  );
}

ButtonStyle iconButtonStyleFromColors(SafeColors safeColors) {
  final foregroundAndIcon = stateColors(
    color: safeColors.text,
    hover: safeColors.textHoverText,
    splash: safeColors.textSplashText,
  );
  return ButtonStyle(
    backgroundColor: const MaterialStatePropertyAll(Colors.transparent),
    surfaceTintColor: const MaterialStatePropertyAll(Colors.transparent),
    overlayColor: stateColors(
      color: safeColors.text,
      hover: safeColors.textHover,
      splash: safeColors.textSplash,
    ),
    foregroundColor: foregroundAndIcon,
    side: MaterialStateProperty.all(
      const BorderSide(color: Colors.transparent, width: 0),
    ),
    // iconColor: foregroundAndIcon,
  );
}

/// Useful for ex. MaterialBanner
ButtonStyle onFillButtonStyleFromColors(SafeColors safeColors) {
  final alwaysSurface = stateColors(
    color: safeColors.background,
    hover: safeColors.background,
    splash: safeColors.background,
  );
  return ButtonStyle(
    backgroundColor: alwaysSurface,
    surfaceTintColor: alwaysSurface,
    overlayColor: stateColors(
      color: safeColors.background,
      hover: safeColors.textHover,
      splash: safeColors.textSplash,
    ),
    foregroundColor: stateColors(
      color: safeColors.backgroundText,
      hover: safeColors.textHoverText,
      splash: safeColors.textSplashText,
    ),
    side: MaterialStateProperty.all(
      BorderSide(color: safeColors.colorBorder, width: 2),
    ),
  );
}

ButtonStyle outlineButtonStyleFromColors(SafeColors safeColors) {
  return ButtonStyle(
    backgroundColor: MaterialStatePropertyAll(safeColors.background),
    surfaceTintColor: MaterialStatePropertyAll(safeColors.background),
    overlayColor: stateColors(
      color: Colors.transparent,
      hover: safeColors.textHover,
      splash: safeColors.textSplash,
    ),
    foregroundColor: stateColors(
      color: safeColors.text,
      hover: safeColors.textHoverText,
      splash: safeColors.textSplashText,
    ),
    side: MaterialStateProperty.all(
      BorderSide(color: safeColors.fill, width: 2),
    ),
  );
}

ButtonStyle textButtonStyleFromColors(SafeColors safeColors) {
  return outlineButtonStyleFromColors(safeColors).copyWith(
    side: MaterialStateProperty.all(BorderSide.none),
    backgroundColor: MaterialStateProperty.all(Colors.transparent),
    textStyle: MaterialStateProperty.all(
      TextStyle(
        color: safeColors.text,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

ButtonStyle buttonStylefromSafeColorsFill(SafeColors safeColors) {
  final alwaysSurface = stateColors(
    color: safeColors.fill,
    hover: safeColors.fill,
    splash: safeColors.fill,
  );
  return ButtonStyle(
    backgroundColor: alwaysSurface,
    surfaceTintColor: alwaysSurface,
    overlayColor: stateColors(
      color: safeColors.fill,
      hover: safeColors.fillHover,
      splash: safeColors.fillSplash,
    ),
    foregroundColor: stateColors(
      color: safeColors.fillText,
      hover: safeColors.fillHoverText,
      splash: safeColors.fillSplashText,
    ),
    side: MaterialStateProperty.all(
      BorderSide(color: safeColors.fill, width: 2),
    ),
  );
}

ButtonStyle buttonStylefromSafeColorsText(SafeColors safeColors) {
  return ButtonStyle(
    backgroundColor: MaterialStateProperty.all(null),
    surfaceTintColor: MaterialStateProperty.all(null),
    overlayColor: stateColors(
      color: Colors.transparent,
      hover: safeColors.textHover,
      splash: safeColors.textSplash,
    ),
    foregroundColor: stateColors(
      color: safeColors.text,
      hover: safeColors.textHoverText,
      splash: safeColors.textSplashText,
    ),
    side: MaterialStateProperty.all(BorderSide.none),
  );
}
