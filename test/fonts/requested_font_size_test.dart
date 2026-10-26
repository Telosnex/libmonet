import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/libmonet.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('requestedFontSize removes the size equalizer scale', () {
    const family = 'Tenali Ramakrishna';
    final scale = visualHeightScaleForFontFamily(family);
    expect(scale, greaterThan(1.4));
    final style = TextStyle(fontFamily: family, fontSize: 17 * scale);
    expect(requestedFontSize(style), closeTo(17, 1e-9));
    expect(iconSizeFor(style), requestedFontSize(style));
  });

  test('fonts without data keep their size', () {
    const style = TextStyle(fontFamily: 'Not A Font', fontSize: 17);
    expect(requestedFontSize(style), 17);
  });
}
