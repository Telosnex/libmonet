import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:libmonet/theming/monet_theme_data.dart';

/// Paint-only Monet palette channel.
///
/// This is the high-frequency companion to [MonetTheme]. A normal
/// [MonetTheme] update is an inherited-widget update: every descendant that
/// called `MonetTheme.of(context)` is marked dependent-dirty and can rebuild,
/// relayout text, and repaint. That is correct for semantic theme changes, but
/// too expensive for palette values that animate every frame while, for example,
/// a transparent surface moves across wallpaper.
///
/// [MonetPaintColors] separates those concerns. The controller identity is
/// provided once by [MonetPaintColorsScope], while [value] may change often.
/// Paint-aware widgets/render objects can subscribe directly and respond with
/// `markNeedsPaint` or an in-place paragraph rebuild. They do not need to call
/// `setState`, rebuild their widget subtree, or create a new inherited
/// [MonetTheme] value.
///
/// In short:
///
/// * [MonetTheme]: semantic/layout/material theme, update sparingly.
/// * [MonetPaintColors]: paint-only palette animation, update freely.
class MonetPaintColors extends ChangeNotifier with Diagnosticable {
  MonetPaintColors(MonetThemeData value) : _value = value;

  MonetThemeData _value;

  MonetThemeData get value => _value;

  set value(MonetThemeData next) {
    if (_value == next) return;
    _value = next;
    notifyListeners();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<MonetThemeData>('value', value));
  }
}

/// Stable inherited scope for [MonetPaintColors].
///
/// The inherited widget intentionally exposes only the controller identity. It
/// notifies dependents when that identity changes, but not when
/// [MonetPaintColors.value] changes. Animated color ticks are delivered by
/// [MonetPaintColors.notifyListeners] directly to listeners that explicitly opt
/// into the paint-only channel.
///
/// Use [maybeOf] when a widget can fall back to regular [MonetTheme] behavior
/// outside an [AnimatedMonetTheme]. Use [of] when paint-bus support is required
/// by the widget's contract.
class MonetPaintColorsScope extends InheritedWidget {
  const MonetPaintColorsScope({
    super.key,
    required this.colors,
    required super.child,
  });

  final MonetPaintColors colors;

  static MonetPaintColors of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<MonetPaintColorsScope>();
    assert(inherited != null, 'No MonetPaintColorsScope found in context.');
    return inherited!.colors;
  }

  static MonetPaintColors? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<MonetPaintColorsScope>()
        ?.colors;
  }

  @override
  bool updateShouldNotify(covariant MonetPaintColorsScope oldWidget) =>
      !identical(colors, oldWidget.colors);
}
