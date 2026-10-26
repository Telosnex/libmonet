import 'package:libmonet/extract/monet_gdt_rule_v1.dart';
import 'package:test/test.dart';

void main() {
  group('monetGdtRuleV1Triad', () {
    const red = '#d03030', cyan = '#20b0c0', yellow = '#d0c020';
    const green = '#30a040', dullRed = '#806060', gray = '#808080';
    final even = {
      for (final h in [red, cyan, yellow, green, dullRed]) h: 0.2,
    };

    test('primary is the most chromatic plausible option', () {
      final t = monetGdtRuleV1Triad(
        [dullRed, red, cyan, yellow],
        [
          {dullRed: 0.5, red: 0.3, cyan: 0.1, yellow: 0.1},
          even,
          even,
        ],
      );
      expect(t!.first, red);
    });

    test(
      'the probabilities bound each role: an implausible option is not chosen',
      () {
        final t = monetGdtRuleV1Triad(
          [dullRed, red, cyan, yellow],
          [
            {dullRed: 0.9, red: 0.1},
            even,
            even,
          ],
        );
        expect(t!.first, dullRed);
      },
    );

    test('tertiary is nearest primary complement; secondary a third hue', () {
      final t = monetGdtRuleV1Triad(
        [red, yellow, cyan, dullRed],
        [even, even, even],
      );
      expect(t, [red, yellow, cyan]);
    });

    test('with no distinct hue, secondary still differs from primary', () {
      final t = monetGdtRuleV1Triad(
        [gray, '#202020', '#e0e0e0'],
        [
          {gray: 1},
          {'#202020': 0.5, '#e0e0e0': 0.5},
          {'#202020': 0.5, '#e0e0e0': 0.5},
        ],
      );
      expect(t!.toSet(), hasLength(3));
      expect(t.first, gray);
    });

    test('null with fewer than three options', () {
      expect(monetGdtRuleV1Triad([red, cyan], [even, even, even]), isNull);
    });
  });
}
