import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/theming/monet_shape_theme.dart';

void main() {
  test('scales radii and gap padding with the linear Monet scale', () {
    const theme = MonetShapeTheme(
      borderRadius: BorderRadius.all(Radius.circular(18)),
      inputGapPadding: 3,
    );

    final small = theme.resolve(0.25);
    final normal = theme.resolve(1);
    final large = theme.resolve(4);

    expect(
      (small.border() as RoundedRectangleBorder).borderRadius,
      const BorderRadius.all(Radius.circular(9)),
    );
    expect(
      (normal.border() as RoundedRectangleBorder).borderRadius,
      const BorderRadius.all(Radius.circular(18)),
    );
    expect(
      (large.border() as RoundedRectangleBorder).borderRadius,
      const BorderRadius.all(Radius.circular(36)),
    );

    final input =
        large.inputBorder(textDirection: TextDirection.ltr)
            as OutlineInputBorder;
    expect(input.borderRadius, const BorderRadius.all(Radius.circular(36)));
    expect(input.gapPadding, 6);
  });

  test('scales custom directional radii but not border sides', () {
    const side = BorderSide(width: 3, color: Colors.red);
    const designRadius = BorderRadiusDirectional.only(
      topStart: Radius.circular(5),
      bottomEnd: Radius.circular(7),
    );
    const theme = MonetShapeTheme();
    final shapes = theme.resolve(4);

    final border =
        shapes.border(borderRadius: designRadius, side: side)
            as RoundedRectangleBorder;
    expect(border.side, side);
    expect(
      border.borderRadius,
      const BorderRadiusDirectional.only(
        topStart: Radius.circular(10),
        bottomEnd: Radius.circular(14),
      ),
    );

    final input =
        shapes.inputBorder(
              borderRadius: designRadius,
              borderSide: side,
              textDirection: TextDirection.rtl,
            )
            as OutlineInputBorder;
    expect(input.borderSide, side);
    expect(
      input.borderRadius,
      const BorderRadius.only(
        topRight: Radius.circular(10),
        bottomLeft: Radius.circular(14),
      ),
    );
  });

  test('shape configuration has semantic equality', () {
    const a = MonetShapeTheme(
      borderRadius: BorderRadius.all(Radius.circular(18)),
      inputGapPadding: 2,
    );
    const b = MonetShapeTheme(
      borderRadius: BorderRadius.all(Radius.circular(18)),
      inputGapPadding: 2,
    );

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.resolve(4), b.resolve(4));
    expect(a.resolve(4), isNot(a.resolve(1)));
  });
}
