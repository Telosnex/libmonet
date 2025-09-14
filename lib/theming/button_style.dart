import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:libmonet/safe_colors.dart';
import 'package:libmonet/theming/monet_theme_data.dart';

// Resolve Material states to our 3-state model and return a value per state.
WidgetStateProperty<T> widgetPropertyByState<T>({
  required T normal,
  required T hover,
  required T splash,
}) {
  return WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.pressed) ||
        states.contains(WidgetState.dragged)) {
      return splash;
    }
    if (states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.focused) ||
        states.contains(WidgetState.selected)) {
      return hover;
    }
    return normal;
  });
}

Size get minimumSize =>
    const Size(MonetThemeData.touchSize, MonetThemeData.touchSize);
Size get maximumSize => const Size(double.infinity, double.infinity);
EdgeInsetsGeometry get padding {
  final isDesktop = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);
  final amount = 2.0 + (isDesktop ? 10.0 : 0.0);
  return EdgeInsets.symmetric(vertical: amount, horizontal: 8);
}

// 1) Background button — recolor container per state; never use overlay
ButtonStyle backgroundButtonStyle(
  SafeColors sc, {
  bool showBorder = false,
  TextStyle? textStyle,
  double borderWidth = 2,
}) {
  return ButtonStyle(
    visualDensity: VisualDensity.compact,
    backgroundColor: widgetPropertyByState(
        normal: sc.background,
        hover: sc.backgroundHovered,
        splash: sc.backgroundSplashed),
    surfaceTintColor: widgetPropertyByState(
        normal: sc.background,
        hover: sc.backgroundHovered,
        splash: sc.backgroundSplashed),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    foregroundColor: widgetPropertyByState(
        normal: sc.backgroundText,
        hover: sc.backgroundHoveredText,
        splash: sc.backgroundSplashedText),
    iconColor: widgetPropertyByState(
        normal: sc.backgroundText,
        hover: sc.backgroundHoveredText,
        splash: sc.backgroundSplashedText),
    textStyle: textStyle != null ? WidgetStatePropertyAll(textStyle) : null,
    minimumSize: WidgetStatePropertyAll(minimumSize),
    maximumSize: WidgetStatePropertyAll(maximumSize),
    padding: WidgetStatePropertyAll(padding),
    side: showBorder
        ? WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.dragged)) {
              return BorderSide(
                  color: sc.backgroundSplashedBorder, width: borderWidth);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused) ||
                states.contains(WidgetState.selected)) {
              return BorderSide(
                  color: sc.backgroundHoveredBorder, width: borderWidth);
            }
            return BorderSide(color: sc.backgroundBorder, width: borderWidth);
          })
        : null,
  );
}

// 2) Fill button — recolor container per state; never use overlay
ButtonStyle fillButtonStyle(
  SafeColors sc, {
  bool showBorder = true,
  TextStyle? textStyle,
  double borderWidth = 2,
}) {
  return ButtonStyle(
    visualDensity: VisualDensity.compact,
    backgroundColor: widgetPropertyByState(
        normal: sc.fill, hover: sc.fillHovered, splash: sc.fillSplashed),
    surfaceTintColor: widgetPropertyByState(
        normal: sc.fill, hover: sc.fillHovered, splash: sc.fillSplashed),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    foregroundColor: widgetPropertyByState(
        normal: sc.fillText,
        hover: sc.fillHoveredText,
        splash: sc.fillSplashedText),
    // For icons, use the icon role if available; hover/splash fall back to text roles.
    iconColor: widgetPropertyByState(
        normal: sc.fillIcon,
        hover: sc.fillHoveredText,
        splash: sc.fillSplashedText),
    textStyle: textStyle != null ? WidgetStatePropertyAll(textStyle) : null,
    minimumSize: WidgetStatePropertyAll(minimumSize),
    maximumSize: WidgetStatePropertyAll(maximumSize),
    padding: WidgetStatePropertyAll(padding),
    side: showBorder
        ? WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.dragged)) {
              return BorderSide(
                  color: sc.fillSplashedBorder, width: borderWidth);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused) ||
                states.contains(WidgetState.selected)) {
              return BorderSide(
                  color: sc.fillHoveredBorder, width: borderWidth);
            }
            return BorderSide(color: sc.fillBorder, width: borderWidth);
          })
        : null,
  );
}

// 3) Color button — recolor container per state; never use overlay
ButtonStyle colorButtonStyle(
  SafeColors sc, {
  bool showBorder = true,
  TextStyle? textStyle,
  double borderWidth = 2,
}) {
  return ButtonStyle(
    visualDensity: VisualDensity.compact,
    backgroundColor: widgetPropertyByState(
        normal: sc.color, hover: sc.colorHovered, splash: sc.colorSplashed),
    surfaceTintColor: widgetPropertyByState(
        normal: sc.color, hover: sc.colorHovered, splash: sc.colorSplashed),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    foregroundColor: widgetPropertyByState(
        normal: sc.colorText,
        hover: sc.colorHoveredText,
        splash: sc.colorSplashedText),
    iconColor: widgetPropertyByState(
        normal: sc.colorIcon,
        hover: sc.colorHoveredText,
        splash: sc.colorSplashedText),
    textStyle: textStyle != null ? WidgetStatePropertyAll(textStyle) : null,
    minimumSize: WidgetStatePropertyAll(minimumSize),
    maximumSize: WidgetStatePropertyAll(maximumSize),
    padding: WidgetStatePropertyAll(padding),
    side: showBorder
        ? WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.dragged)) {
              return BorderSide(
                  color: sc.colorSplashedBorder, width: borderWidth);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused) ||
                states.contains(WidgetState.selected)) {
              return BorderSide(
                  color: sc.colorHoveredBorder, width: borderWidth);
            }
            return BorderSide(color: sc.colorBorder, width: borderWidth);
          })
        : null,
  );
}

// Convenience aliases for common button patterns

/// Text button with transparent background, no border.
ButtonStyle textButtonStyle(
  SafeColors sc, {
  TextStyle? textStyle,
}) {
  return ButtonStyle(
    visualDensity: VisualDensity.compact,
    backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    foregroundColor: widgetPropertyByState(
      normal: sc.text,
      hover: sc.textHovered,
      splash: sc.textSplashed,
    ),
    iconColor: widgetPropertyByState(
      normal: sc.text,
      hover: sc.textHovered,
      splash: sc.textSplashed,
    ),
    textStyle: textStyle != null ? WidgetStatePropertyAll(textStyle) : null,
    minimumSize: WidgetStatePropertyAll(minimumSize),
    maximumSize: WidgetStatePropertyAll(maximumSize),
    padding: WidgetStatePropertyAll(padding),
  );
}

/// Icon button: transparent background and stateful icon/text colors.
ButtonStyle iconButtonStyle(
  SafeColors sc, {
  TextStyle? textStyle,
}) {
  return ButtonStyle(
    visualDensity: VisualDensity.compact,
    backgroundColor: widgetPropertyByState(
      normal: Colors.transparent,
      hover: sc.backgroundHovered,
      splash: sc.backgroundSplashed,
    ),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    foregroundColor: widgetPropertyByState(
      normal: sc.fill,
      hover: sc.backgroundHoveredFill,
      splash: sc.backgroundSplashedFill,
    ),
    iconColor: widgetPropertyByState(
      normal: sc.fill,
      hover: sc.backgroundHoveredFill,
      splash: sc.backgroundSplashedFill,
    ),
    padding: WidgetStatePropertyAll(EdgeInsets.zero),
    textStyle: textStyle != null ? WidgetStatePropertyAll(textStyle) : null,
  );
}

/// Outlined button with transparent background and border.
ButtonStyle outlineButtonStyle(
  SafeColors sc, {
  TextStyle? textStyle,
  double borderWidth = 2,
}) {
  final base = backgroundButtonStyle(sc,
      showBorder: true, textStyle: textStyle, borderWidth: borderWidth);
  return base.copyWith(
    backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
  );
}
