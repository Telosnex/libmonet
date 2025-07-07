

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:libmonet/safe_colors.dart';
import 'package:libmonet/theming/monet_theme_data.dart';

extension SafeColorsButtonStyle on ButtonStyle {
  static ButtonStyle fromSafeColorsColor(SafeColors safeColors) {
    return ButtonStyle(
      visualDensity: VisualDensity.compact,
      backgroundColor: WidgetStateProperty.all(safeColors.color),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return safeColors.colorHover;
        } else if (states.contains(WidgetState.pressed)) {
          return safeColors.colorSplash;
        } else if (states.contains(WidgetState.focused)) {
          return safeColors.colorHover;
        }
        return Colors.transparent;
      }),
      foregroundColor: WidgetStateProperty.all(safeColors.colorText),
      shadowColor: WidgetStateProperty.all(safeColors.colorBorder),
      elevation: WidgetStateProperty.all(0),
      side: WidgetStateProperty.all(
          BorderSide(color: safeColors.colorBorder, width: 2)),
    );
  }
}

WidgetStateProperty<Color> stateColors(
    {required Color color, required Color hover, required Color splash}) {
  return WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.pressed)) {
      return splash;
    } else if (states.contains(WidgetState.focused) ||
        states.contains(WidgetState.hovered) || states.contains(WidgetState.selected)) {
      return hover;
    }
    return color;
  });
}

ButtonStyle elevatedButtonStyleFromColors(SafeColors safeColors,
    {double elevation = MonetThemeData.buttonElevation}) {
  return filledButtonBackgroundIsColor(safeColors).copyWith(
    elevation: WidgetStatePropertyAll(elevation),
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
    visualDensity: VisualDensity.compact,
    backgroundColor: alwaysSurface,
    surfaceTintColor: alwaysSurface,
    overlayColor: stateColors(
      color: safeColors.background,
      hover: safeColors.textHover,
      splash: safeColors.textSplash,
    ),
    iconColor: stateColors(
      color: safeColors.text,
      hover: safeColors.textHoverText,
      splash: safeColors.textSplashText,
    ),
    iconSize: textStyle != null
        ? WidgetStateProperty.all(textStyle.fontSize!.roundToDouble())
        : null,
    minimumSize: WidgetStateProperty.all(minimumSize),
    maximumSize: WidgetStateProperty.all(maximumSize),
    padding: WidgetStateProperty.all(padding),
    foregroundColor: stateColors(
      color: safeColors.text,
      hover: safeColors.textHoverText,
      splash: safeColors.textSplashText,
    ),
    textStyle: textStyle != null
        ? WidgetStateProperty.all(textStyle)
        : WidgetStateProperty.all(null),
    side: WidgetStateProperty.all(
      BorderSide(color: safeColors.fill, width: 2),
    ),
  );
}

Size get minimumSize {
  return const Size(MonetThemeData.touchSize, MonetThemeData.touchSize);
}

Size get maximumSize {
  return const Size(double.infinity, double.infinity);
}

EdgeInsetsGeometry get padding {
  // Some platforms have buttons that ignore the minimum size.
  final isDesktop =
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);
  final amount = 2.0 + (isDesktop ? 10.0 : 0.0);
  return EdgeInsets.symmetric(vertical: amount, horizontal: 8);
}

ButtonStyle filledButtonBackgroundIsFill(SafeColors safeColors,
    {TextStyle? textStyle}) {
  final alwaysSurface = stateColors(
    color: safeColors.fill,
    hover: safeColors.fill,
    splash: safeColors.fill,
  );
  return ButtonStyle(
    visualDensity: VisualDensity.compact,
    backgroundColor: alwaysSurface,
    surfaceTintColor: alwaysSurface,
    overlayColor: stateColors(
      color: safeColors.fill,
      hover: safeColors.fillHover,
      splash: safeColors.fillSplash,
    ),
    minimumSize: WidgetStateProperty.all(minimumSize),
    maximumSize: WidgetStateProperty.all(maximumSize),
    padding: WidgetStateProperty.all(padding),
    foregroundColor: stateColors(
      color: safeColors.fillText,
      hover: safeColors.fillHoverText,
      splash: safeColors.fillSplashText,
    ),
    iconColor: stateColors(
      color: safeColors.fillText,
      hover: safeColors.fillHoverText,
      splash: safeColors.fillSplashText,
    ),
    iconSize: textStyle != null
        ? WidgetStateProperty.all(textStyle.fontSize!.roundToDouble())
        : null,
    textStyle: textStyle != null
        ? WidgetStateProperty.all(textStyle)
        : WidgetStateProperty.all(null),
    side: WidgetStateProperty.all(
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
    visualDensity: VisualDensity.compact,
    backgroundColor: alwaysSurface,
    surfaceTintColor: alwaysSurface,
    overlayColor: stateColors(
      color: safeColors.color,
      hover: safeColors.colorHover,
      splash: safeColors.colorSplash,
    ),
    iconColor: stateColors(
      color: safeColors.colorText,
      hover: safeColors.colorHoverText,
      splash: safeColors.colorSplashText,
    ),
    iconSize: textStyle != null
        ? WidgetStateProperty.all(textStyle.fontSize!.roundToDouble())
        : null,
    minimumSize: WidgetStateProperty.all(minimumSize),
    maximumSize: WidgetStateProperty.all(maximumSize),
    padding: WidgetStateProperty.all(padding),
    foregroundColor: stateColors(
      color: safeColors.colorText,
      hover: safeColors.colorHoverText,
      splash: safeColors.colorSplashText,
    ),
    textStyle: textStyle != null
        ? WidgetStateProperty.all(textStyle)
        : WidgetStateProperty.all(null),
    side: WidgetStateProperty.all(
      BorderSide(color: safeColors.colorBorder, width: 2),
    ),
  );
}

ButtonStyle iconButtonStyleFromColors(SafeColors safeColors,
    {double? iconSize}) {
  final foregroundAndIcon = stateColors(
    color: safeColors.text,
    hover: safeColors.textHoverText,
    splash: safeColors.textSplashText,
  );
  return ButtonStyle(
    visualDensity: VisualDensity.compact,
    backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    overlayColor: stateColors(
      color: safeColors.text,
      hover: safeColors.textHover,
      splash: safeColors.textSplash,
    ),
    foregroundColor: foregroundAndIcon,
    side: WidgetStateProperty.all(
      const BorderSide(color: Colors.transparent, width: 0),
    ),
    iconColor: foregroundAndIcon,
    iconSize: iconSize != null
        ? WidgetStateProperty.all(iconSize)
        : null,
  );
}

/// Useful for ex. MaterialBanner
ButtonStyle onFillButtonStyleFromColors(SafeColors safeColors, {double? iconSize}) {
  final alwaysSurface = stateColors(
    color: safeColors.background,
    hover: safeColors.background,
    splash: safeColors.background,
  );
  return ButtonStyle(
    visualDensity: VisualDensity.compact,
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
    iconColor: stateColors(
      color: safeColors.backgroundText,
      hover: safeColors.textHoverText,
      splash: safeColors.textSplashText,
    ),
    iconSize: iconSize != null
        ? WidgetStateProperty.all(iconSize)
        : null,
    side: WidgetStateProperty.all(
      BorderSide(color: safeColors.colorBorder, width: 2),
    ),
  );
}

ButtonStyle iconButtonStyleFromColorInSafeColors(SafeColors safeColors, {double? iconSize}) {
  return ButtonStyle(
    visualDensity: VisualDensity.compact,
    backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
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
    iconColor: stateColors(
      color: safeColors.colorText,
      hover: safeColors.colorHoverText,
      splash: safeColors.colorSplashText,
    ),
    iconSize: iconSize != null
        ? WidgetStateProperty.all(iconSize)
        : null,
    side: WidgetStateProperty.all(
      const BorderSide(color: Colors.transparent, width: 0),
    ),
    // iconColor: foregroundAndIcon,
  );
}

ButtonStyle outlineButtonStyleFromColors(SafeColors safeColors) {
  return ButtonStyle(
    visualDensity: VisualDensity.compact,
    backgroundColor: WidgetStatePropertyAll(safeColors.background),
    surfaceTintColor: WidgetStatePropertyAll(safeColors.background),
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
    iconColor: stateColors(
      color: safeColors.text,
      hover: safeColors.textHover,
      splash: safeColors.textSplash,
    ),
    minimumSize: WidgetStateProperty.all(minimumSize),
    maximumSize: WidgetStateProperty.all(maximumSize),
    padding: WidgetStateProperty.all(padding),
    side: WidgetStateProperty.all(
      BorderSide(color: safeColors.fill, width: 2),
    ),
  );
}

ButtonStyle textButtonStyleFromColors(SafeColors safeColors,
    {TextStyle? textStyle}) {
  return outlineButtonStyleFromColors(safeColors).copyWith(
    side: WidgetStateProperty.all(BorderSide.none),
    backgroundColor: WidgetStateProperty.all(Colors.transparent),
    textStyle: WidgetStateProperty.all(
      textStyle ??
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
    visualDensity: VisualDensity.compact,
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
    iconColor: stateColors(
      color: safeColors.fillText,
      hover: safeColors.fillHoverText,
      splash: safeColors.fillSplashText,
    ),
    side: WidgetStateProperty.all(
      BorderSide(color: safeColors.fill, width: 2),
    ),
  );
}

ButtonStyle buttonStylefromSafeColorsText(SafeColors safeColors) {
  return ButtonStyle(
    visualDensity: VisualDensity.compact,
    backgroundColor: WidgetStateProperty.all(null),
    surfaceTintColor: WidgetStateProperty.all(null),
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
    iconColor: stateColors(
      color: safeColors.text,
      hover: safeColors.textHover,
      splash: safeColors.textSplash,
    ),
    side: WidgetStateProperty.all(BorderSide.none),
  );
}
