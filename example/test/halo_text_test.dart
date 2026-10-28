import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/libmonet.dart';
import 'package:monet_studio/halo_text.dart';

void main() {
  testWidgets('HaloText renders underlay + text without asserts',
      (tester) async {
    final stroked = AnyBackground(
      const [0xFF000000, 0xFFFFFFFF],
      contrast: 0.5,
      algo: Algo.apca,
    ).scrimFor(0xFFFFFFFF).shadowsWithStroke();
    expect(stroked.scrim.meetsTarget, isTrue);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HaloText(
          text: 'Ground Control',
          stroked: stroked,
          // Style WITH a color set: exercises the copyWith(foreground:)
          // path, which must drop color rather than trip TextStyle's
          // color/foreground exclusivity assert.
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    ));

    final texts = tester.widgetList<Text>(find.byType(Text)).toList();
    expect(texts, hasLength(2));
    final underlay = texts.first.style!;
    expect(underlay.color, isNull);
    expect(underlay.foreground, isNotNull);
    expect(underlay.foreground!.style, PaintingStyle.stroke);
    expect(underlay.foreground!.strokeWidth, 2 * stroked.stroke);
    expect(texts.last.style!.color, Colors.white);
  });
}
