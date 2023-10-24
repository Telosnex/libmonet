import 'package:flutter/material.dart';
import 'package:libmonet/safe_colors.dart';

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

ButtonStyle elevatedButtonStyleFromColors(SafeColors safeColors) {
  return filledButtonStyleFromColors(safeColors)
      .copyWith(elevation: const MaterialStatePropertyAll(16));
}

ButtonStyle filledButtonStyleFromColors(SafeColors safeColors) {
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
    side: MaterialStateProperty.all(
      BorderSide(color: safeColors.colorBorder, width: 2),
    ),
  );
}

ButtonStyle outlinedButtonStyleFromColors(SafeColors safeColors) {
  return ButtonStyle(
    backgroundColor: const MaterialStatePropertyAll(Colors.transparent),
    surfaceTintColor: const MaterialStatePropertyAll(Colors.transparent),
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
  return outlinedButtonStyleFromColors(safeColors).copyWith(
    side: MaterialStateProperty.all(BorderSide.none),
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
