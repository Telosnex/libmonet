import 'package:flutter/material.dart';
import 'package:libmonet/hct.dart';
import 'package:libmonet/safe_colors.dart';

class MonetColorScheme extends ThemeExtension<MonetColorScheme> {
  final Color primaryColor;
  final Color primaryColorText;
  final Color primaryColorHover;
  final Color primaryColorHoverText;
  final Color primaryColorSplash;
  final Color primaryColorSplashText;
  final Color primaryFill;
  final Color primaryFillText;
  final Color primaryFillHover;
  final Color primaryFillHoverText;
  final Color primaryFillSplash;
  final Color primaryFillSplashText;
  final Color primaryText;
  final Color primaryTextHover;
  final Color primaryTextHoverText;
  final Color primaryTextSplash;
  final Color primaryTextSplashText;

  final Color secondaryColor;
  final Color secondaryColorText;
  final Color secondaryColorHover;
  final Color secondaryColorHoverText;
  final Color secondaryColorSplash;
  final Color secondaryColorSplashText;
  final Color secondaryFill;
  final Color secondaryFillText;
  final Color secondaryFillHover;
  final Color secondaryFillHoverText;
  final Color secondaryFillSplash;
  final Color secondaryFillSplashText;
  final Color secondaryText;
  final Color secondaryTextHover;
  final Color secondaryTextHoverText;
  final Color secondaryTextSplash;
  final Color secondaryTextSplashText;

  final Color tertiaryColor;
  final Color tertiaryColorText;
  final Color tertiaryColorHover;
  final Color tertiaryColorHoverText;
  final Color tertiaryColorSplash;
  final Color tertiaryColorSplashText;
  final Color tertiaryFill;
  final Color tertiaryFillText;
  final Color tertiaryFillHover;
  final Color tertiaryFillHoverText;
  final Color tertiaryFillSplash;
  final Color tertiaryFillSplashText;
  final Color tertiaryText;
  final Color tertiaryTextHover;
  final Color tertiaryTextHoverText;
  final Color tertiaryTextSplash;
  final Color tertiaryTextSplashText;

  MonetColorScheme({
    required this.primaryColor,
    required this.primaryColorText,
    required this.primaryColorHover,
    required this.primaryColorHoverText,
    required this.primaryColorSplash,
    required this.primaryColorSplashText,
    required this.primaryFill,
    required this.primaryFillText,
    required this.primaryFillHover,
    required this.primaryFillHoverText,
    required this.primaryFillSplash,
    required this.primaryFillSplashText,
    required this.primaryText,
    required this.primaryTextHover,
    required this.primaryTextHoverText,
    required this.primaryTextSplash,
    required this.primaryTextSplashText,
    required this.secondaryColor,
    required this.secondaryColorText,
    required this.secondaryColorHover,
    required this.secondaryColorHoverText,
    required this.secondaryColorSplash,
    required this.secondaryColorSplashText,
    required this.secondaryFill,
    required this.secondaryFillText,
    required this.secondaryFillHover,
    required this.secondaryFillHoverText,
    required this.secondaryFillSplash,
    required this.secondaryFillSplashText,
    required this.secondaryText,
    required this.secondaryTextHover,
    required this.secondaryTextHoverText,
    required this.secondaryTextSplash,
    required this.secondaryTextSplashText,
    required this.tertiaryColor,
    required this.tertiaryColorText,
    required this.tertiaryColorHover,
    required this.tertiaryColorHoverText,
    required this.tertiaryColorSplash,
    required this.tertiaryColorSplashText,
    required this.tertiaryFill,
    required this.tertiaryFillText,
    required this.tertiaryFillHover,
    required this.tertiaryFillHoverText,
    required this.tertiaryFillSplash,
    required this.tertiaryFillSplashText,
    required this.tertiaryText,
    required this.tertiaryTextHover,
    required this.tertiaryTextHoverText,
    required this.tertiaryTextSplash,
    required this.tertiaryTextSplashText,
  });

  @override
  ThemeExtension<MonetColorScheme> copyWith({
    Color? primaryColor,
    Color? primaryColorText,
    Color? primaryColorHover,
    Color? primaryColorHoverText,
    Color? primaryColorSplash,
    Color? primaryColorSplashText,
    Color? primaryFill,
    Color? primaryFillText,
    Color? primaryFillHover,
    Color? primaryFillHoverText,
    Color? primaryFillSplash,
    Color? primaryFillSplashText,
    Color? primaryText,
    Color? primaryTextHover,
    Color? primaryTextHoverText,
    Color? primaryTextSplash,
    Color? primaryTextSplashText,
    Color? secondaryColor,
    Color? secondaryColorText,
    Color? secondaryColorHover,
    Color? secondaryColorHoverText,
    Color? secondaryColorSplash,
    Color? secondaryColorSplashText,
    Color? secondaryFill,
    Color? secondaryFillText,
    Color? secondaryFillHover,
    Color? secondaryFillHoverText,
    Color? secondaryFillSplash,
    Color? secondaryFillSplashText,
    Color? secondaryText,
    Color? secondaryTextHover,
    Color? secondaryTextHoverText,
    Color? secondaryTextSplash,
    Color? secondaryTextSplashText,
    Color? tertiaryColor,
    Color? tertiaryColorText,
    Color? tertiaryColorHover,
    Color? tertiaryColorHoverText,
    Color? tertiaryColorSplash,
    Color? tertiaryColorSplashText,
    Color? tertiaryFill,
    Color? tertiaryFillText,
    Color? tertiaryFillHover,
    Color? tertiaryFillHoverText,
    Color? tertiaryFillSplash,
    Color? tertiaryFillSplashText,
    Color? tertiaryText,
    Color? tertiaryTextHover,
    Color? tertiaryTextHoverText,
    Color? tertiaryTextSplash,
    Color? tertiaryTextSplashText,
  }) {
    return MonetColorScheme(
      primaryColor: primaryColor ?? this.primaryColor,
      primaryColorText: primaryColorText ?? this.primaryColorText,
      primaryColorHover: primaryColorHover ?? this.primaryColorHover,
      primaryColorHoverText:
          primaryColorHoverText ?? this.primaryColorHoverText,
      primaryColorSplash: primaryColorSplash ?? this.primaryColorSplash,
      primaryColorSplashText:
          primaryColorSplashText ?? this.primaryColorSplashText,
      primaryFill: primaryFill ?? this.primaryFill,
      primaryFillText: primaryFillText ?? this.primaryFillText,
      primaryFillHover: primaryFillHover ?? this.primaryFillHover,
      primaryFillHoverText: primaryFillHoverText ?? this.primaryFillHoverText,
      primaryFillSplash: primaryFillSplash ?? this.primaryFillSplash,
      primaryFillSplashText:
          primaryFillSplashText ?? this.primaryFillSplashText,
      primaryText: primaryText ?? this.primaryText,
      primaryTextHover: primaryTextHover ?? this.primaryTextHover,
      primaryTextHoverText: primaryTextHoverText ?? this.primaryTextHoverText,
      primaryTextSplash: primaryTextSplash ?? this.primaryTextSplash,
      primaryTextSplashText:
          primaryTextSplashText ?? this.primaryTextSplashText,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      secondaryColorText: secondaryColorText ?? this.secondaryColorText,
      secondaryColorHover: secondaryColorHover ?? this.secondaryColorHover,
      secondaryColorHoverText:
          secondaryColorHoverText ?? this.secondaryColorHoverText,
      secondaryColorSplash: secondaryColorSplash ?? this.secondaryColorSplash,
      secondaryColorSplashText:
          secondaryColorSplashText ?? this.secondaryColorSplashText,
      secondaryFill: secondaryFill ?? this.secondaryFill,
      secondaryFillText: secondaryFillText ?? this.secondaryFillText,
      secondaryFillHover: secondaryFillHover ?? this.secondaryFillHover,
      secondaryFillHoverText:
          secondaryFillHoverText ?? this.secondaryFillHoverText,
      secondaryFillSplash: secondaryFillSplash ?? this.secondaryFillSplash,
      secondaryFillSplashText:
          secondaryFillSplashText ?? this.secondaryFillSplashText,
      secondaryText: secondaryText ?? this.secondaryText,
      secondaryTextHover: secondaryTextHover ?? this.secondaryTextHover,
      secondaryTextHoverText:
          secondaryTextHoverText ?? this.secondaryTextHoverText,
      secondaryTextSplash: secondaryTextSplash ?? this.secondaryTextSplash,
      secondaryTextSplashText:
          secondaryTextSplashText ?? this.secondaryTextSplashText,
      tertiaryColor: tertiaryColor ?? this.tertiaryColor,
      tertiaryColorText: tertiaryColorText ?? this.tertiaryColorText,
      tertiaryColorHover: tertiaryColorHover ?? this.tertiaryColorHover,
      tertiaryColorHoverText:
          tertiaryColorHoverText ?? this.tertiaryColorHoverText,
      tertiaryColorSplash: tertiaryColorSplash ?? this.tertiaryColorSplash,
      tertiaryColorSplashText:
          tertiaryColorSplashText ?? this.tertiaryColorSplashText,
      tertiaryFill: tertiaryFill ?? this.tertiaryFill,
      tertiaryFillText: tertiaryFillText ?? this.tertiaryFillText,
      tertiaryFillHover: tertiaryFillHover ?? this.tertiaryFillHover,
      tertiaryFillHoverText:
          tertiaryFillHoverText ?? this.tertiaryFillHoverText,
      tertiaryFillSplash: tertiaryFillSplash ?? this.tertiaryFillSplash,
      tertiaryFillSplashText:
          tertiaryFillSplashText ?? this.tertiaryFillSplashText,
      tertiaryText: tertiaryText ?? this.tertiaryText,
      tertiaryTextHover: tertiaryTextHover ?? this.tertiaryTextHover,
      tertiaryTextHoverText:
          tertiaryTextHoverText ?? this.tertiaryTextHoverText,
      tertiaryTextSplash: tertiaryTextSplash ?? this.tertiaryTextSplash,
      tertiaryTextSplashText:
          tertiaryTextSplashText ?? this.tertiaryTextSplashText,
    );
  }

  MonetColorScheme.fromSafeColors({
    required SafeColors primary,
    required SafeColors secondary,
    required SafeColors tertiary,
  })  : primaryColor = primary.color,
        primaryColorText = primary.colorText,
        primaryColorHover = primary.colorHovered,
        primaryColorHoverText = primary.colorHoveredText,
        primaryColorSplash = primary.colorSplashed,
        primaryColorSplashText = primary.colorSplashedText,
        primaryFill = primary.color,
        primaryFillText = primary.colorText,
        primaryFillHover = primary.colorHovered,
        primaryFillHoverText = primary.colorHoveredText,
        primaryFillSplash = primary.colorSplashed,
        primaryFillSplashText = primary.colorSplashedText,
        primaryText = primary.colorText,
        primaryTextHover = primary.colorHoveredText,
        primaryTextHoverText = primary.colorHoveredText,
        primaryTextSplash = primary.colorSplashedText,
        primaryTextSplashText = primary.colorSplashedText,
        secondaryColor = secondary.color,
        secondaryColorText = secondary.colorText,
        secondaryColorHover = secondary.colorHovered,
        secondaryColorHoverText = secondary.colorHoveredText,
        secondaryColorSplash = secondary.colorSplashed,
        secondaryColorSplashText = secondary.colorSplashedText,
        secondaryFill = secondary.color,
        secondaryFillText = secondary.colorText,
        secondaryFillHover = secondary.colorHovered,
        secondaryFillHoverText = secondary.colorHoveredText,
        secondaryFillSplash = secondary.colorSplashed,
        secondaryFillSplashText = secondary.colorSplashedText,
        secondaryText = secondary.colorText,
        secondaryTextHover = secondary.colorHoveredText,
        secondaryTextHoverText = secondary.colorHoveredText,
        secondaryTextSplash = secondary.colorSplashedText,
        secondaryTextSplashText = secondary.colorSplashedText,
        tertiaryColor = tertiary.color,
        tertiaryColorText = tertiary.colorText,
        tertiaryColorHover = tertiary.colorHovered,
        tertiaryColorHoverText = tertiary.colorHoveredText,
        tertiaryColorSplash = tertiary.colorSplashed,
        tertiaryColorSplashText = tertiary.colorSplashedText,
        tertiaryFill = tertiary.color,
        tertiaryFillText = tertiary.colorText,
        tertiaryFillHover = tertiary.colorHovered,
        tertiaryFillHoverText = tertiary.colorHoveredText,
        tertiaryFillSplash = tertiary.colorSplashed,
        tertiaryFillSplashText = tertiary.colorSplashedText,
        tertiaryText = tertiary.colorText,
        tertiaryTextHover = tertiary.colorHoveredText,
        tertiaryTextHoverText = tertiary.colorHoveredText,
        tertiaryTextSplash = tertiary.colorSplashedText,
        tertiaryTextSplashText = tertiary.colorSplashedText;

  @override
  ThemeExtension<MonetColorScheme> lerp(
      covariant ThemeExtension<MonetColorScheme>? other, double t) {
    if (other == null) return this;
    if (identical(other, this)) {
      return this;
    }
    if (other is MonetColorScheme) {
      return _lerpKeepHue(this, other, t);
    }
    return this;
  }

  static MonetColorScheme _lerpKeepHue(
      MonetColorScheme a, MonetColorScheme b, double t) {
    if (identical(a, b)) {
      return a;
    }

    return MonetColorScheme(
      // brightness: t < 0.5 ? a.brightness : b.brightness,
      // brightness: Hct.lerp(brightness, other.brightness, t),

      primaryColor: Hct.lerpKeepHue(a.primaryColor, b.primaryColor, t),
      primaryColorText:
          Hct.lerpKeepHue(a.primaryColorText, b.primaryColorText, t),
      primaryColorHover:
          Hct.lerpKeepHue(a.primaryColorHover, b.primaryColorHover, t),
      primaryColorHoverText:
          Hct.lerpKeepHue(a.primaryColorHoverText, b.primaryColorHoverText, t),
      primaryColorSplash:
          Hct.lerpKeepHue(a.primaryColorSplash, b.primaryColorSplash, t),
      primaryColorSplashText: Hct.lerpKeepHue(
          a.primaryColorSplashText, b.primaryColorSplashText, t),
      primaryFill: Hct.lerpKeepHue(a.primaryFill, b.primaryFill, t),
      primaryFillText: Hct.lerpKeepHue(a.primaryFillText, b.primaryFillText, t),
      primaryFillHover:
          Hct.lerpKeepHue(a.primaryFillHover, b.primaryFillHover, t),
      primaryFillHoverText:
          Hct.lerpKeepHue(a.primaryFillHoverText, b.primaryFillHoverText, t),
      primaryFillSplash:
          Hct.lerpKeepHue(a.primaryFillSplash, b.primaryFillSplash, t),
      primaryFillSplashText:
          Hct.lerpKeepHue(a.primaryFillSplashText, b.primaryFillSplashText, t),
      primaryText: Hct.lerpKeepHue(a.primaryText, b.primaryText, t),
      primaryTextHover:
          Hct.lerpKeepHue(a.primaryTextHover, b.primaryTextHover, t),
      primaryTextHoverText:
          Hct.lerpKeepHue(a.primaryTextHoverText, b.primaryTextHoverText, t),
      primaryTextSplash:
          Hct.lerpKeepHue(a.primaryTextSplash, b.primaryTextSplash, t),
      primaryTextSplashText:
          Hct.lerpKeepHue(a.primaryTextSplashText, b.primaryTextSplashText, t),
      secondaryColor: Hct.lerpKeepHue(a.secondaryColor, b.secondaryColor, t),
      secondaryColorText:
          Hct.lerpKeepHue(a.secondaryColorText, b.secondaryColorText, t),
      secondaryColorHover:
          Hct.lerpKeepHue(a.secondaryColorHover, b.secondaryColorHover, t),
      secondaryColorHoverText: Hct.lerpKeepHue(
          a.secondaryColorHoverText, b.secondaryColorHoverText, t),
      secondaryColorSplash:
          Hct.lerpKeepHue(a.secondaryColorSplash, b.secondaryColorSplash, t),
      secondaryColorSplashText: Hct.lerpKeepHue(
          a.secondaryColorSplashText, b.secondaryColorSplashText, t),
      secondaryFill: Hct.lerpKeepHue(a.secondaryFill, b.secondaryFill, t),
      secondaryFillText:
          Hct.lerpKeepHue(a.secondaryFillText, b.secondaryFillText, t),
      secondaryFillHover:
          Hct.lerpKeepHue(a.secondaryFillHover, b.secondaryFillHover, t),
      secondaryFillHoverText: Hct.lerpKeepHue(
          a.secondaryFillHoverText, b.secondaryFillHoverText, t),
      secondaryFillSplash:
          Hct.lerpKeepHue(a.secondaryFillSplash, b.secondaryFillSplash, t),
      secondaryFillSplashText: Hct.lerpKeepHue(
          a.secondaryFillSplashText, b.secondaryFillSplashText, t),
      secondaryText: Hct.lerpKeepHue(a.secondaryText, b.secondaryText, t),
      secondaryTextHover:
          Hct.lerpKeepHue(a.secondaryTextHover, b.secondaryTextHover, t),
      secondaryTextHoverText: Hct.lerpKeepHue(
          a.secondaryTextHoverText, b.secondaryTextHoverText, t),
      secondaryTextSplash:
          Hct.lerpKeepHue(a.secondaryTextSplash, b.secondaryTextSplash, t),
      secondaryTextSplashText: Hct.lerpKeepHue(
          a.secondaryTextSplashText, b.secondaryTextSplashText, t),
      tertiaryColor: Hct.lerpKeepHue(a.tertiaryColor, b.tertiaryColor, t),
      tertiaryColorText:
          Hct.lerpKeepHue(a.tertiaryColorText, b.tertiaryColorText, t),
      tertiaryColorHover:
          Hct.lerpKeepHue(a.tertiaryColorHover, b.tertiaryColorHover, t),
      tertiaryColorHoverText: Hct.lerpKeepHue(
          a.tertiaryColorHoverText, b.tertiaryColorHoverText, t),
      tertiaryColorSplash:
          Hct.lerpKeepHue(a.tertiaryColorSplash, b.tertiaryColorSplash, t),
      tertiaryColorSplashText: Hct.lerpKeepHue(
          a.tertiaryColorSplashText, b.tertiaryColorSplashText, t),
      tertiaryFill: Hct.lerpKeepHue(a.tertiaryFill, b.tertiaryFill, t),
      tertiaryFillText:
          Hct.lerpKeepHue(a.tertiaryFillText, b.tertiaryFillText, t),
      tertiaryFillHover:
          Hct.lerpKeepHue(a.tertiaryFillHover, b.tertiaryFillHover, t),
      tertiaryFillHoverText:
          Hct.lerpKeepHue(a.tertiaryFillHoverText, b.tertiaryFillHoverText, t),
      tertiaryFillSplash:
          Hct.lerpKeepHue(a.tertiaryFillSplash, b.tertiaryFillSplash, t),
      tertiaryFillSplashText: Hct.lerpKeepHue(
          a.tertiaryFillSplashText, b.tertiaryFillSplashText, t),
      tertiaryText: Hct.lerpKeepHue(a.tertiaryText, b.tertiaryText, t),
      tertiaryTextHover:
          Hct.lerpKeepHue(a.tertiaryTextHover, b.tertiaryTextHover, t),
      tertiaryTextHoverText:
          Hct.lerpKeepHue(a.tertiaryTextHoverText, b.tertiaryTextHoverText, t),
      tertiaryTextSplash:
          Hct.lerpKeepHue(a.tertiaryTextSplash, b.tertiaryTextSplash, t),
      tertiaryTextSplashText: Hct.lerpKeepHue(
          a.tertiaryTextSplashText, b.tertiaryTextSplashText, t),
    );
  }
}
