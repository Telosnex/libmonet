import 'package:test/test.dart';

void main() {
  test('bit shift formula equals r*33*33 + g*33 + b for all valid indices', () {
    // The quantizer uses a 33x33x33 cube (indices 0-32)
    const indexCount = 33;

    int bitShiftFormula(int r, int g, int b) {
      return (r << 10) + (r << 6) + (g << 5) + r + g + b;
    }

    int readableFormula(int r, int g, int b) {
      return r * 33 * 33 + g * 33 + b;
    }

    // Test all 33^3 = 35,937 combinations
    for (int r = 0; r < indexCount; r++) {
      for (int g = 0; g < indexCount; g++) {
        for (int b = 0; b < indexCount; b++) {
          final bitShift = bitShiftFormula(r, g, b);
          final readable = readableFormula(r, g, b);
          expect(bitShift, equals(readable),
              reason: 'Mismatch at r=$r, g=$g, b=$b: '
                  'bitShift=$bitShift, readable=$readable');
        }
      }
    }
  });

  test('bit shift formula derivation is mathematically correct', () {
    // Prove: (r << 10) + (r << 6) + (g << 5) + r + g + b == r*1089 + g*33 + b
    //
    // (r << 10) = r * 1024
    // (r << 6)  = r * 64
    // (g << 5)  = g * 32
    //
    // So: r*1024 + r*64 + g*32 + r + g + b
    //   = r*(1024 + 64 + 1) + g*(32 + 1) + b
    //   = r*1089 + g*33 + b
    //   = r*33*33 + g*33 + b  ✓

    expect(1024 + 64 + 1, equals(33 * 33), reason: '1024+64+1 should equal 1089');
    expect(32 + 1, equals(33), reason: '32+1 should equal 33');
  });
}
