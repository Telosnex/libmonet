import 'package:libmonet/apca.dart';
import 'package:libmonet/hex_codes.dart';
import 'package:test/test.dart';

void main() {
  // 1. Take hex pair & Lc value from https://apcacontrast.com/
  // 2. Convert and verify our impl matches.
  group('APCA implementation matches reference', () {
    test('first', () {
      final ref = ApcaReference(
        bg: '#e9e4d0',
        fg: '#1234b0',
        lc: 75.6,
      );
      expect(ref.implementationLc, closeTo(ref.lc, 0.1));
    });

    test('first swapped', () {
      final ref = ApcaReference(
        bg: '#1234b0',
        fg: '#e9e4d0',
        lc: -78.3,
      );
      expect(ref.implementationLc, closeTo(ref.lc, 0.1));
    });

    test('dark bg', () {
      final ref = ApcaReference(
        bg: '#161618',
        fg: '#adaa94',
        lc: -54.9,
      );
      expect(ref.implementationLc, closeTo(ref.lc, 0.1));
    });

    test('dark bg swapped', () {
      final ref = ApcaReference(
        bg: '#adaa94',
        fg: '#161618',
        lc: 56.5,
      );
      expect(ref.implementationLc, closeTo(ref.lc, 0.1));
    });

    test('black bg', () {
      final ref = ApcaReference(
        bg: '#000000',
        fg: '#adaa94',
        lc: -55.8,
      );
      expect(ref.implementationLc, closeTo(ref.lc, 0.1));
    });

    test('black bg swapped', () {
      final ref = ApcaReference(
        bg: '#adaa94',
        fg: '#000000',
        lc: 57.7,
      );
      expect(ref.implementationLc, closeTo(ref.lc, 0.1));
    });
  });
}

class ApcaReference {
  final String bg;
  final String fg;
  final double lc;

  double get implementationLc {
    return apcaFromColors(
      backgroundColor: colorFromHex(bg)!,
      textColor: colorFromHex(fg)!,
    );
  }

  ApcaReference({required this.bg, required this.fg, required this.lc});
}
