import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/contrast/contrast.dart';
import 'package:libmonet/effects/protection.dart';
import 'package:monet_studio/halo_text.dart';

void main() {
  testWidgets('HaloText renders underlay + text without asserts',
      (tester) async {
    final halo = getHalo(
      foregroundArgb: 0xFFFFFFFF,
      backgroundArgbs: const [0xFF000000, 0xFFFFFFFF],
      contrast: 0.5,
      algo: Algo.apca,
    );
    expect(halo.meetsTarget, isTrue);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HaloText(
          text: 'Ground Control',
          halo: halo,
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
    expect(underlay.foreground!.strokeWidth, 2 * halo.spread);
    expect(texts.last.style!.color, Colors.white);
  });
}
