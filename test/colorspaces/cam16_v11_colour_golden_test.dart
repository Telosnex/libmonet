import 'package:libmonet/colorspaces/cam16V11/cam16_v11.dart';
import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/colorspaces/hct_solver.dart';
import 'package:libmonet/core/argb_srgb_xyz_lab.dart';
import 'package:test/test.dart';

void main() {
  group('Cam16V11 matches Colour Hellwig2022 goldens', () {
    // Generated from Colour Hellwig2022 with libmonet's sRGB XYZ matrix,
    // D65 white point, average surround, Y_b from L* 50, and matching L_A.
    const goldens = <String, _Golden>{
      '#FFFFFF': _Golden(
        argb: 0xffffffff,
        j: 100.000000098985,
        chroma: 1.306068615252,
        hue: 209.491959473838,
        m: 1.100164391276,
        s: 1.287410490903,
        q: 85.455602471027,
      ),
      '#FF0000': _Golden(
        argb: 0xffff0000,
        j: 46.445185455166,
        chroma: 64.995547051422,
        hue: 27.408225137159,
        m: 54.748874310623,
        s: 137.941185094947,
        q: 39.690013010211,
      ),
      '#00FF00': _Golden(
        argb: 0xff00ff00,
        j: 79.331576631980,
        chroma: 69.269727226066,
        hue: 142.139893507646,
        m: 58.349221777156,
        s: 86.069334044649,
        q: 67.793276693517,
      ),
      '#0000FF': _Golden(
        argb: 0xff0000ff,
        j: 25.465629356430,
        chroma: 86.327113769174,
        hue: 282.788179561873,
        m: 72.717478592927,
        s: 334.151840882231,
        q: 21.761806968035,
      ),
      '#4285F4': _Golden(
        argb: 0xff4285f4,
        j: 46.588695611366,
        chroma: 46.942396264011,
        hue: 265.979395357926,
        m: 39.541837394867,
        s: 99.319781324393,
        q: 39.812650478677,
      ),
      '#ADE9FF': _Golden(
        argb: 0xffade9ff,
        j: 84.352062551168,
        chroma: 16.978185732572,
        hue: 221.941541909629,
        m: 14.301542165029,
        s: 19.840226446099,
        q: 72.083563178486,
      ),
      '#E3EAFF': _Golden(
        argb: 0xffe3eaff,
        j: 90.098688455929,
        chroma: 9.152554988334,
        hue: 264.868847451616,
        m: 7.709637127616,
        s: 10.013246982168,
        q: 76.994376962295,
      ),
    };

    for (final entry in goldens.entries) {
      test(entry.key, () {
        final actual = Cam16V11.fromInt(entry.value.argb);
        entry.value.expectMatches(actual);
      });
    }
  });

  group('HctSolver v11 round-trips in-gamut colors', () {
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
        final cam = Cam16V11.fromInt(argb);
        final solved = HctSolver.solveToIntForModel(
          cam.hue,
          cam.chroma,
          lstarFromArgb(argb),
          model: ColorModel.cam16v11,
        );

        expect(solved, argb);
      });
    }
  });
}

class _Golden {
  const _Golden({
    required this.argb,
    required this.j,
    required this.chroma,
    required this.hue,
    required this.m,
    required this.s,
    required this.q,
  });

  final int argb;
  final double j;
  final double chroma;
  final double hue;
  final double m;
  final double s;
  final double q;

  void expectMatches(Cam16V11 actual) {
    const tolerance = 1e-9;

    expect(actual.j, closeTo(j, tolerance), reason: 'J');
    expect(actual.chroma, closeTo(chroma, tolerance), reason: 'C');
    expect(actual.hue, closeTo(hue, tolerance), reason: 'h');
    expect(actual.m, closeTo(m, tolerance), reason: 'M');
    expect(actual.s, closeTo(s, tolerance), reason: 's');
    expect(actual.q, closeTo(q, tolerance), reason: 'Q');
  }
}
