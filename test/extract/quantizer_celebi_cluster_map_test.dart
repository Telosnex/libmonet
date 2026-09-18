import 'package:libmonet/extract/quantizer_celebi.dart';
import 'package:libmonet/extract/quantizer_result.dart';
import 'package:test/test.dart';

void main() {
  const red = 0xffff0000;
  const nearRed = 0xfffe0101;
  const blue = 0xff0000ff;
  const nearBlue = 0xff0101fe;

  final pixels = <int>[
    ...List.filled(40, red),
    ...List.filled(24, nearRed),
    ...List.filled(30, blue),
    ...List.filled(6, nearBlue),
  ];

  test('returns an input-pixel to cluster-pixel map when requested', () async {
    final result = await QuantizerCelebi().quantize(
      pixels,
      2,
      returnInputPixelToClusterPixel: true,
    );

    expect(result.argbToCount.length, 2);
    expect(result.inputPixelToClusterPixel.keys.toSet(), {
      red,
      nearRed,
      blue,
      nearBlue,
    });
    expect(
      result.inputPixelToClusterPixel.values.toSet(),
      result.argbToCount.keys.toSet(),
      reason: 'every mapped value must be an actual palette entry',
    );
    expect(
      result.inputPixelToClusterPixel[red],
      result.inputPixelToClusterPixel[nearRed],
    );
    expect(
      result.inputPixelToClusterPixel[blue],
      result.inputPixelToClusterPixel[nearBlue],
    );
    expect(
      result.inputPixelToClusterPixel[red],
      isNot(result.inputPixelToClusterPixel[blue]),
    );
    expect(_reconstructedPopulations(pixels, result), result.argbToCount);
  });

  test('omits the map by default', () async {
    final result = await QuantizerCelebi().quantize(pixels, 2);
    expect(result.inputPixelToClusterPixel, isEmpty);
    expect(result.argbToCount.length, 2);
  });
}

Map<int, int> _reconstructedPopulations(
  List<int> pixels,
  QuantizerResult result,
) {
  final populations = <int, int>{};
  for (final pixel in pixels) {
    final cluster = result.inputPixelToClusterPixel[pixel]!;
    populations[cluster] = (populations[cluster] ?? 0) + 1;
  }
  return populations;
}
