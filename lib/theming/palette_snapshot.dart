import 'package:libmonet/theming/palette.dart';
import 'package:libmonet/theming/palette_roles.dart';

/// Complete immutable capture, including every interactive icon role.
/// Equality/hash use actual outputs and model, never placeholder solver inputs.
class PaletteSnapshot extends ResolvedPalette {
  PaletteSnapshot.capture(Palette source)
    : super([
        for (final role in PaletteRole.values) role.read(source),
      ], source.colorModel);
}
