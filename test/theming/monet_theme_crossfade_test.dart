import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/theming/monet_theme_crossfade.dart';
import 'package:libmonet/theming/monet_theme_data.dart';

MonetThemeData _theme(Brightness brightness) => MonetThemeData.fromColor(
  color: brightness == Brightness.light ? Colors.white : Colors.black,
  brightness: brightness,
  backgroundTone: brightness == Brightness.light ? 93 : 10,
);

/// Center pixel of the scene as a color; the widget under test is a 100×100
/// plain [ColoredBox] whose color is chosen from [MonetThemeData.brightness].
Future<Color> _centerPixel(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('scene')),
  );
  final image = await tester.runAsync(() => boundary.toImage());
  final bytes = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  final w = image!.width;
  final h = image.height;
  final i = ((h ~/ 2) * w + (w ~/ 2)) * 4;
  final d = bytes!.buffer.asUint8List();
  image.dispose();
  return Color.fromARGB(d[i + 3], d[i], d[i + 1], d[i + 2]);
}

Widget _scene(MonetThemeData data) => MaterialApp(
  home: RepaintBoundary(
    key: const Key('scene'),
    child: Center(
      child: SizedBox(
        width: 100,
        height: 100,
        child: MonetThemeCrossfade(
          data: data,
          duration: const Duration(milliseconds: 200),
          child: ColoredBox(
            color: data.brightness == Brightness.light
                ? Colors.white
                : Colors.black,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('dissolves the previous raster into the new child', (
    tester,
  ) async {
    await tester.pumpWidget(_scene(_theme(Brightness.light)));
    await tester.pump();
    expect((await _centerPixel(tester)).r, closeTo(1.0, 0.01));

    final render = tester.renderObject<RenderMonetThemeCrossfade>(
      find.byType(MonetThemeCrossfade),
    );
    expect(render.debugIsCrossfading, isFalse);

    // Theme changes: the child snaps to black; the old white raster is drawn
    // on top at full alpha in the first frame, so the pixel is still white.
    await tester.pumpWidget(_scene(_theme(Brightness.dark)));
    expect(render.debugIsCrossfading, isTrue);
    expect((await _centerPixel(tester)).r, closeTo(1.0, 0.01));

    // Halfway: a blend.
    await tester.pump(const Duration(milliseconds: 100));
    final mid = (await _centerPixel(tester)).r;
    expect(mid, greaterThan(0.3));
    expect(mid, lessThan(0.7));

    // Done: black, snapshot released.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect((await _centerPixel(tester)).r, closeTo(0.0, 0.01));
    expect(render.debugIsCrossfading, isFalse);
  });

  testWidgets('does not rebuild the child during the fade', (tester) async {
    var builds = 0;
    Widget scene(MonetThemeData data) => MaterialApp(
      home: MonetThemeCrossfade(
        data: data,
        duration: const Duration(milliseconds: 200),
        child: Builder(
          builder: (_) {
            builds++;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    await tester.pumpWidget(scene(_theme(Brightness.light)));
    expect(builds, 1);
    await tester.pumpWidget(scene(_theme(Brightness.dark)));
    expect(builds, 2);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(builds, 2);
  });

  testWidgets('a resize mid-fade drops the stale raster', (tester) async {
    Widget scene(MonetThemeData data, double size) => MaterialApp(
      home: Center(
        child: SizedBox(
          width: size,
          height: size,
          child: MonetThemeCrossfade(
            data: data,
            duration: const Duration(milliseconds: 200),
            child: const ColoredBox(color: Colors.white),
          ),
        ),
      ),
    );
    await tester.pumpWidget(scene(_theme(Brightness.light), 100));
    await tester.pumpWidget(scene(_theme(Brightness.dark), 100));
    final render = tester.renderObject<RenderMonetThemeCrossfade>(
      find.byType(MonetThemeCrossfade),
    );
    expect(render.debugIsCrossfading, isTrue);
    await tester.pumpWidget(scene(_theme(Brightness.dark), 150));
    expect(render.debugIsCrossfading, isFalse);
  });
}
