import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/colorspaces/hct_solver.dart';
import 'package:libmonet/colorspaces/oklch.dart';
import 'package:libmonet/core/argb_srgb_xyz_lab.dart';
import 'package:test/test.dart';

void main() {
  group('Oklch matches Colour goldens', () {
    // Generated from Colour XYZ_to_Oklab + Oklab_to_Oklch with libmonet's
    // sRGB XYZ matrix.
    const goldens = <String, _Golden>{
      '#FFFFFF': _Golden(
        argb: 0xffffffff,
        l: 0.999999810178026,
        chroma: 0.000086699132428,
        hue: 263.318971156762,
      ),
      '#FF0000': _Golden(
        argb: 0xffff0000,
        l: 0.627918222704701,
        chroma: 0.257631306386850,
        hue: 29.225692605109,
      ),
      '#00FF00': _Golden(
        argb: 0xff00ff00,
        l: 0.866454021344049,
        chroma: 0.294804295688702,
        hue: 142.507321805181,
      ),
      '#0000FF': _Golden(
        argb: 0xff0000ff,
        l: 0.452041434403870,
        chroma: 0.313250054761735,
        hue: 264.096866069512,
      ),
      '#4285F4': _Golden(
        argb: 0xff4285f4,
        l: 0.630400980074946,
        chroma: 0.180076025862670,
        hue: 259.984149933570,
      ),
      '#ADE9FF': _Golden(
        argb: 0xffade9ff,
        l: 0.900630181083397,
        chroma: 0.067730974447632,
        hue: 222.619294202681,
      ),
      '#E3EAFF': _Golden(
        argb: 0xffe3eaff,
        l: 0.938054492856921,
        chroma: 0.029478638278644,
        hue: 271.088219778121,
      ),
    };

    for (final entry in goldens.entries) {
      test(entry.key, () {
        final actual = Oklch.fromInt(entry.value.argb);
        entry.value.expectMatches(actual);
      });
    }
  });

  group('HctSolver OKLCH round-trips in-gamut colors', () {
    const colors = <int>[
      0xffffffff,
      0xffff0000,
      0xff00ff00,
      0xff0000ff,
      0xff4285f4,
      0xffade9ff,
      0xffe3eaff,
    ];

    for (final argb in colors) {
      test(argb.toRadixString(16), () {
        final oklch = Oklch.fromInt(argb);
        final solved = HctSolver.solveToIntForModel(
          oklch.hue,
          oklch.chroma,
          lstarFromArgb(argb),
          model: ColorModel.oklch,
        );

        expect(solved, argb);
      });
    }
  });
}

class _Golden {
  const _Golden({
    required this.argb,
    required this.l,
    required this.chroma,
    required this.hue,
  });

  final int argb;
  final double l;
  final double chroma;
  final double hue;

  void expectMatches(Oklch actual) {
    const tolerance = 1e-9;

    expect(actual.l, closeTo(l, tolerance), reason: 'L');
    expect(actual.chroma, closeTo(chroma, tolerance), reason: 'C');
    expect(actual.hue, closeTo(hue, tolerance), reason: 'h');
  }
}
