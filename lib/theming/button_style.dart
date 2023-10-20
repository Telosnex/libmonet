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
      side:
          MaterialStateProperty.all(BorderSide(color: safeColors.colorBorder, width: 2)),
    );
  }
}

ButtonStyle buttonStylefromSafeColorsColor(SafeColors safeColors) {
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
      return null;
    }),
    foregroundColor: MaterialStateProperty.all(safeColors.colorText),
    shadowColor: MaterialStateProperty.all(safeColors.colorBorder),
    elevation: MaterialStateProperty.all(0),
    side: MaterialStateProperty.all(BorderSide(color: safeColors.colorBorder, width: 2)),
  );
}

ButtonStyle buttonStylefromSafeColorsFill(SafeColors safeColors) {
  return ButtonStyle(
    backgroundColor: MaterialStateProperty.all(safeColors.fill),
    overlayColor: MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.hovered)) {
        return safeColors.fillHover;
      } else if (states.contains(MaterialState.pressed)) {
        return safeColors.fillSplash;
      } else if (states.contains(MaterialState.focused)) {
        return safeColors.fillHover;
      }
      return null;
    }),
    foregroundColor: MaterialStateProperty.all(safeColors.fillText),
    shadowColor: MaterialStateProperty.all(safeColors.colorBorder),
    elevation: MaterialStateProperty.all(0),
    side: MaterialStateProperty.all(BorderSide(color: safeColors.fill)),
  );
}


ButtonStyle buttonStylefromSafeColorsText(SafeColors safeColors) {
  return ButtonStyle(
    backgroundColor: MaterialStateProperty.all(null),
    overlayColor: MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.hovered)) {
        return safeColors.textHover;
      } else if (states.contains(MaterialState.pressed)) {
        return safeColors.textSplash;
      } else if (states.contains(MaterialState.focused)) {
        return safeColors.textHover;
      }
      return null;
    }),
    foregroundColor: MaterialStateProperty.all(safeColors.text),
    shadowColor: MaterialStateProperty.all(null),
    elevation: MaterialStateProperty.all(0),
    side: MaterialStateProperty.all(BorderSide.none),
  );
}
