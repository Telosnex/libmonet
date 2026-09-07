import 'package:androidx_graphics_shapes/material_shapes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/shapes/expressive_button.dart';
import 'package:libmonet/theming/monet_clip.dart';
import 'package:libmonet/theming/monet_theme.dart';
import 'package:libmonet/theming/monet_theme_data.dart';
import 'package:monet_studio/expressive_shapes_expansion_tile.dart';

void main() {
  testWidgets('morph playback, scrubbing and endpoint changes share one border',
      (tester) async {
    final theme = MonetThemeData.fromColor(
      backgroundTone: 93,
      brightness: Brightness.light,
      color: Colors.blue,
    );
    await tester.pumpWidget(MaterialApp(
        home: MonetTheme(
      monetThemeData: theme,
      child: const Scaffold(
          body: SingleChildScrollView(
        child: ExpressiveShapesExpansionTile(),
      )),
    )));
    await tester.tap(find.text('Material 3 Expressive shapes'));
    await tester.pumpAndSettle();

    BoundsCenteredBorder centeredBorder() =>
        tester.widget<MonetClip>(find.byType(MonetClip)).shape!
            as BoundsCenteredBorder;
    MorphBorder border() => centeredBorder().source as MorphBorder;
    void action(String label) => tester
        .widget<TextButton>(find.widgetWithText(TextButton, label))
        .onPressed!();
    expect(find.byType(DropdownButton<MaterialExpressiveShape>), findsNothing);
    void select(String name) => tester
        .widget<IconButton>(
            find.byWidgetPredicate((w) => w is IconButton && w.tooltip == name))
        .onPressed!();
    select('Heart');
    await tester.pumpAndSettle();
    expect(find.text('Morph: Cookie7Sided → Heart'), findsOneWidget);
    final originalMorph = border().morph;
    action('Replay morph');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(border().progress, closeTo(0.4, 0.01));
    expect(border().morph, same(originalMorph));
    action('Pause morph');
    final paused = border().progress;
    await tester.pump(const Duration(seconds: 3));
    expect(border().progress, paused);

    final slider = find.byKey(const ValueKey('expressive-morph-progress'));
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    await tester.tap(slider);
    await tester.pumpAndSettle();
    expect(border().progress, closeTo(0.5, 0.01));
    final frame = centeredBorder();
    for (final kind in ['filled', 'outlined', 'elevated']) {
      final button = tester.widget<ButtonStyleButton>(
        find.descendant(
            of: find.byKey(ValueKey('expressive-$kind')),
            matching: find
                .byWidgetPredicate((widget) => widget is ButtonStyleButton)),
      );
      expect(button.style!.shape!.resolve({}), frame);
      expect(button.style!.animationDuration, Duration.zero);
    }
    final ink = tester.widget<InkWell>(find.byWidgetPredicate(
      (widget) => widget is InkWell && identical(widget.customBorder, frame),
    ));
    expect(ink.customBorder, same(frame));
    expect(
        frame
            .getOuterPath(const Rect.fromLTWH(0, 0, 100, 100))
            .computeMetrics()
            .single
            .isClosed,
        isTrue);

    action('Reverse morph');
    await tester.pumpAndSettle();
    expect(border().progress, 0);
    action('Replay morph');
    await tester.pumpAndSettle();
    expect(border().progress, 1);

    // Redirect a half-finished morph from its actual outline, not its target.
    action('Replay morph');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    final before =
        centeredBorder().getOuterPath(const Rect.fromLTWH(0, 0, 144, 144));
    select('Fan');
    await tester.pump();
    expect(find.text('Morph: Current outline → Fan'), findsOneWidget);
    expect(border().progress, 0);
    final after =
        centeredBorder().getOuterPath(const Rect.fromLTWH(0, 0, 144, 144));
    _expectCloseOutline(before, after);
    await tester.pump(const Duration(milliseconds: 300));
    final oldProgress = border().progress;
    select('Fan'); // Re-selecting the current target must not restart.
    await tester.pump();
    expect(border().progress, oldProgress);
    select('Heart'); // Repeated interruption.
    await tester.pumpAndSettle();
    _expectHeartOutline(border().path);
    select('Arrow'); // Settled selection is now the source.
    await tester.pump();
    expect(find.text('Morph: Heart → Arrow'), findsOneWidget);
    action('Replay morph');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox()); // Dispose an active ticker.
    expect(tester.takeException(), isNull);
  });

  testWidgets('gallery selects silhouettes without changing the theme',
      (tester) async {
    final theme = MonetThemeData.fromColor(
        backgroundTone: 93, brightness: Brightness.light, color: Colors.blue);
    await tester.pumpWidget(MaterialApp(
        home: MonetTheme(
      monetThemeData: theme,
      child: const Scaffold(
          body: SingleChildScrollView(
        child: ExpressiveShapesExpansionTile(),
      )),
    )));
    await tester.tap(find.text('Material 3 Expressive shapes'));
    await tester.pumpAndSettle();
    expect(find.byType(IconButton), findsNWidgets(35));
    final heart = find.byTooltip('Heart');
    await tester.ensureVisible(heart);
    await tester.tap(heart);
    await tester.pumpAndSettle();
    expect(find.text('Selected: Heart'), findsOneWidget);
    final clip = tester.widget<MonetClip>(find.byType(MonetClip));
    final border = (clip.shape! as BoundsCenteredBorder).source as MorphBorder;
    expect(border.progress, 1);
    _expectHeartOutline(border.path);
    final context = tester.element(find.byType(MonetClip));
    expect(
        MonetTheme.shapesOf(context).border(), isA<RoundedRectangleBorder>());
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 1000.0]) {
    testWidgets('button content and border controls at width $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final theme = MonetThemeData.fromColor(
        backgroundTone: 93,
        brightness: Brightness.light,
        color: Colors.blue,
      );
      await tester.pumpWidget(MaterialApp(
        home: MonetTheme(
          monetThemeData: theme,
          child: const Scaffold(
            body: SingleChildScrollView(
              child: ExpressiveShapesExpansionTile(),
            ),
          ),
        ),
      ));
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tap(find.text('Material 3 Expressive shapes'));
      final buttons = [
        find.byKey(const ValueKey('expressive-filled')),
        find.byKey(const ValueKey('expressive-outlined')),
        find.byKey(const ValueKey('expressive-elevated')),
      ];
      final smallSize = tester.getSize(buttons.first);
      for (final button in buttons) {
        expect(
            tester
                .widget<Icon>(find.descendant(
                  of: button,
                  matching: find.byType(Icon),
                ))
                .size,
            18);
      }
      await tap(find.text('Large icon'));
      expect(
          tester.getSize(buttons.first).height, greaterThan(smallSize.height));
      for (final button in buttons) {
        expect(
            tester
                .widget<Icon>(find.descendant(
                  of: button,
                  matching: find.byType(Icon),
                ))
                .size,
            64);
        await tap(button);
      }
      expect(find.text('Button presses: 3'), findsOneWidget);
      await tap(find.text('Short text'));
      for (final button in buttons) {
        final text = tester.widget<Text>(
            find.descendant(of: button, matching: find.text('Save changes')));
        expect(text.maxLines, 1);
        expect(text.softWrap, isFalse);
        final fit = tester.widget<FittedBox>(
            find.descendant(of: button, matching: find.byType(FittedBox)));
        expect(fit.fit, BoxFit.scaleDown);
      }
      await tap(find.text('Lots of text'));
      for (final button in buttons) {
        final widget = tester.widget<ExpressiveButton>(button);
        expect(widget.child, isA<Text>());
        expect((widget.child as Text).data!.length, greaterThan(150));
        expect(
            find.descendant(
                of: button, matching: find.byType(ExpressiveShapeContent)),
            findsOneWidget);
        final size = tester.getSize(button);
        expect(size.width, lessThanOrEqualTo(280));
        // The width cap must also cap the unstretched surface's height;
        // otherwise a scroll view reserves blank space around the silhouette.
        expect(size.height, closeTo(size.width, 1e-7));
      }
      await tap(find.byType(Switch));
      await tap(find.byTooltip('Heart'));
      final slider = find.byKey(const ValueKey('expressive-content-padding'));
      await tap(slider); // Midpoint is 32 px.
      expect(find.text('Content padding: 32 px'), findsOneWidget);
      for (final button in buttons) {
        final wrapper = tester.widget<ExpressiveButton>(button);
        final style = tester
            .widget<ButtonStyleButton>(find.descendant(
                of: button,
                matching: find.byWidgetPredicate(
                    (widget) => widget is ButtonStyleButton)))
            .style!;
        final shape = (style.shape!.resolve({})! as BoundsCenteredBorder).source
            as MorphBorder;
        expect(shape.progress, 1);
        _expectHeartOutline(shape.path);
        expect(shape.squash, 1);
        expect(style.padding!.resolve({}), EdgeInsets.zero);
        expect(wrapper.padding, const EdgeInsets.all(32));
      }
      final outlined = tester.widget<OutlinedButton>(find.descendant(
          of: buttons[1], matching: find.byType(OutlinedButton)));
      expect(outlined.style!.side!.resolve({})!.width, 2);
      await tap(find.text('Small icon'));
      expect(tester.takeException(), isNull);
    });
  }
}

void _expectHeartOutline(Path actual) {
  final expected = MaterialShapes.heart.toPath();
  // Morph subdivides cubics: control-point bounds can change even though the
  // filled outline is identical. Compare occupancy, not Path.getBounds().
  for (var y = 0; y < 40; y++) {
    for (var x = 0; x < 40; x++) {
      final point = Offset((x + 0.5) / 40, (y + 0.5) / 40);
      expect(actual.contains(point), expected.contains(point),
          reason: '$point');
    }
  }
}

void _expectCloseOutline(Path before, Path after) {
  final a = before.computeMetrics().single;
  final b = after.computeMetrics().single;
  // Flutter's flattened arc-length estimate changes when cubics subdivide.
  expect(a.length, closeTo(b.length, 0.5));
  // Snapshot retains the curve's start and winding; matching may subdivide it.
  for (var i = 0; i < 100; i++) {
    expect(
        (a.getTangentForOffset(a.length * i / 100)!.position -
                b.getTangentForOffset(b.length * i / 100)!.position)
            .distance,
        lessThan(0.5));
  }
}
