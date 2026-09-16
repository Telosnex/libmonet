import 'dart:ui';

import 'package:libmonet/colorspaces/hct.dart';
import 'package:libmonet/theming/interpolation_style.dart';
import 'package:libmonet/theming/palette.dart';
import 'package:libmonet/theming/palette_roles.dart';

/// Explicit, immutable interpolation of solved outputs. Construction reads no
/// colors; endpoint reads access only that endpoint. Each role is memoized.
/// Do not build an unbounded chain of these on interruption: live motion uses
/// a sparse RGB starting snapshot instead.
class PaletteLerped extends RolePalette {
  PaletteLerped({
    required this.a,
    required this.b,
    required this.t,
    this.interpolationStyle = InterpolationStyle.cartesian,
  }) : assert(t.isFinite),
       super(t >= 1 ? b.colorModel : a.colorModel);

  final Palette a;
  final Palette b;
  final double t;
  final InterpolationStyle interpolationStyle;
  final Map<PaletteRole, Color> _colors = {};

  @override
  Color readRole(PaletteRole role) => _colors.putIfAbsent(role, () {
    if (t <= 0) return role.read(a);
    if (t >= 1) return role.read(b);
    final start = role.read(a);
    if (identical(a, b)) return start;
    final end = role.read(b);
    if (start == end) return start;
    return switch (interpolationStyle) {
      InterpolationStyle.polar => Hct.lerpKeepHue(
        start,
        end,
        t,
        model: colorModel,
      ),
      InterpolationStyle.cartesian => Hct.lerpLoseHueAndChroma(
        start,
        end,
        t,
        model: colorModel,
      ),
    };
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaletteLerped &&
          runtimeType == other.runtimeType &&
          a == other.a &&
          b == other.b &&
          t == other.t &&
          interpolationStyle == other.interpolationStyle;
  @override
  int get hashCode => Object.hash(runtimeType, a, b, t, interpolationStyle);
}
