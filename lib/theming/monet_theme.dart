import 'package:flutter/material.dart';
import 'package:libmonet/contrast.dart';
import 'package:libmonet/safe_colors.dart';
import 'package:libmonet/theming/monet_theme_data.dart';

class MonetTheme extends StatelessWidget {
  final MonetThemeData monetThemeData;
  final Widget child;

  SafeColors get primary => monetThemeData.primary;
  SafeColors get secondary => monetThemeData.secondary;
  SafeColors get tertiary => monetThemeData.tertiary;
  Algo get algo => monetThemeData.algo;
  Brightness get brightness => monetThemeData.brightness;
  double get contrast => monetThemeData.contrast;
  double get scale => monetThemeData.scale;
  double get backgroundTone => monetThemeData.backgroundTone;
  
  const MonetTheme({
    super.key,
    required this.monetThemeData,
    required this.child,
  });

  static MonetTheme of(BuildContext context) {
    final _MonetInheritedTheme? inheritedTheme =
        context.dependOnInheritedWidgetOfExactType<_MonetInheritedTheme>();
    return inheritedTheme!.theme;
  }

  @override
  Widget build(BuildContext context) {
    final themeData = monetThemeData.createThemeData(context);
    return _MonetInheritedTheme(
      theme: this,
      // Animated theme is actually worse for design, ex. when switching theme
      // color, the InputDecoration of a text field only acquires the correct
      // background color and text color at the end of animating.
      child: DefaultTextStyle(
        style: themeData.textTheme.bodyMedium!,
        child: Theme(
          data: themeData,
          child: child,
        ),
      ),
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
      monetThemeData: theme.monetThemeData,
      child: child,
    );
  }

  @override
  bool updateShouldNotify(_MonetInheritedTheme old) => theme != old.theme;
}
