import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/contrast/apca_tone_bounds.dart';
import 'package:libmonet/libmonet.dart';

bool isLighter(Color foreground, Color background) =>
    lstarFromArgb(foreground.toARGB32()) >=
    lstarFromArgb(background.toARGB32());

Color at(double hue, double chroma, double tone, ColorModel model) =>
    Hct.colorFrom(hue, chroma, tone, model: model);

void main() {
  test(
    'production APCA envelope matches witnesses and contains chromatic samples',
    () {
      final at50 = apcaBrightnessBoundsAtTone(50);
      expect(at50.minimum, closeTo(.16027158, 2e-7));
      expect(at50.maximum, closeTo(.18275507, 2e-7));
      expect(
        identical(at50, apcaBrightnessBoundsAtTone(50)),
        isTrue,
        reason: 'repeated requests reuse the cached table lookup',
      );
      for (final model in ColorModel.values) {
        for (final tone in [5.0, 20.0, 50.0, 66.6, 80.0, 95.0]) {
          for (var hue = 0.0; hue < 360; hue += 15) {
            final color = at(
              hue,
              model == ColorModel.oklch ? .4 : 140,
              tone,
              model,
            );
            final actualTone = lstarFromArgb(color.toARGB32());
            final bounds = apcaBrightnessBoundsAtTone(actualTone);
            final brightness = apcaYFromArgb(color.toARGB32());
            expect(
              brightness,
              inInclusiveRange(bounds.minimum, bounds.maximum),
              reason: '$model T$tone H$hue actual=$actualTone',
            );
            expect(
              (actualTone - tone).abs(),
              lessThanOrEqualTo(kPaletteToneMaterializationUncertainty),
              reason: 'the shared uncertainty interval must enclose HCT materialization',
            );
          }
        }
      }
      final random = math.Random(91826);
      for (var i = 0; i < 2000; i++) {
        final argb = 0xff000000 | random.nextInt(0x1000000);
        final tone = lstarFromArgb(argb);
        final bounds = apcaBrightnessBoundsAtTone(tone);
        expect(
          apcaYFromArgb(argb),
          inInclusiveRange(bounds.minimum, bounds.maximum),
          reason: Color(argb).toString(),
        );
      }
    },
  );

  test('shared policy covers APCA feasibility branches deterministically', () {
    ContrastDirection direction(double tone, double contrast) =>
        sharedForegroundDirection(backgroundTone: tone, contrast: contrast);
    expect(
      direction(20, .5),
      ContrastDirection.lighter,
      reason: 'only light guarantees Lc60',
    );
    expect(
      direction(94, .5),
      ContrastDirection.darker,
      reason: 'only dark guarantees Lc60',
    );
    expect(
      direction(50, .1),
      ContrastDirection.lighter,
      reason: 'both meet; aesthetic wins',
    );
    expect(
      direction(80, .1),
      ContrastDirection.darker,
      reason: 'both meet; aesthetic wins',
    );
    expect(
      direction(66, .5),
      ContrastDirection.lighter,
      reason: 'neither meets; light has larger worst case',
    );
    expect(
      direction(67, .5),
      ContrastDirection.darker,
      reason: 'neither meets; dark has larger worst case',
    );
  });

  test('WCAG policy uses tone capacities without APCA chromatic bounds', () {
    ContrastDirection direction(double tone, double contrast) =>
        sharedForegroundDirection(
          backgroundTone: tone,
          contrast: contrast,
          by: Algo.wcag21,
        );
    expect(direction(20, .5), ContrastDirection.lighter);
    expect(direction(94, .5), ContrastDirection.darker);
    expect(
      direction(50, .1),
      ContrastDirection.lighter,
      reason: 'both meet the low target; aesthetic wins',
    );
    expect(
      direction(50, 1),
      ContrastDirection.darker,
      reason: 'neither reaches 21:1 after uncertainty; dark has more capacity',
    );
  });

  test('APCA both-feasible policy prefers aesthetics over maximum capacity', () {
    expect(
      sharedForegroundDirection(backgroundTone: 62, contrast: .1),
      ContrastDirection.darker,
      reason:
          'both meet Lc12; darker is preferred despite greater light capacity',
    );
  });

  test('APCA light-only feasibility overrides darker preference', () {
    expect(
      sharedForegroundDirection(backgroundTone: 60.6, contrast: .5),
      ContrastDirection.lighter,
      reason:
          'only light guarantees Lc60, despite the darker aesthetic preference',
    );
  });

  test('WCAG dark-only feasibility overrides lighter preference', () {
    expect(
      sharedForegroundDirection(
        backgroundTone: 55,
        contrast: .5,
        by: Algo.wcag21,
      ),
      ContrastDirection.darker,
      reason: 'only dark guarantees 4.5:1, despite the lighter aesthetic preference',
    );
  });

  test('forced WCAG polarity clamps at its own extreme even at a boundary', () {
    final darker = contrastingTone(
      withArgb: const Color(0xff000000).toARGB32(),
      withTone: 0,
      targetHue: 200,
      targetChroma: 80,
      usage: Usage.text,
      by: Algo.wcag21,
      contrast: .5,
      forceDirection: ContrastDirection.darker,
    );
    final lighter = contrastingTone(
      withArgb: const Color(0xffffffff).toARGB32(),
      withTone: 100,
      targetHue: 200,
      targetChroma: 80,
      usage: Usage.text,
      by: Algo.wcag21,
      contrast: .5,
      forceDirection: ContrastDirection.lighter,
    );
    expect(darker, 0);
    expect(lighter, 100);
  });

  test('independent palettes with one logical tone agree across hues and models', () {
    const logicalTone = 66.6;
    for (final algo in Algo.values) {
      for (final model in ColorModel.values) {
        final directions = <bool>{};
        for (var hue = 0.0; hue < 360; hue += 15) {
          final background = at(
            hue,
            model == ColorModel.oklch ? .35 : 100,
            logicalTone,
            model,
          );
          final brand = at(
            (hue + 137) % 360,
            model == ColorModel.oklch ? .3 : 80,
            50,
            model,
          );
          final palette = Palette.fromColorAndBackground(
            brand,
            background,
            backgroundTone: logicalTone,
            contrast: .5,
            algo: algo,
            colorModel: model,
          );
          final direction = isLighter(palette.backgroundText, background);
          directions.add(direction);
          for (final sibling in [
            palette.text,
            palette.fill,
            palette.textHovered,
            palette.textSplashed,
          ]) {
            expect(
              isLighter(sibling, background),
              direction,
              reason:
                  '$algo $model H$hue must anchor background siblings to text',
            );
          }
        }
        expect(directions, hasLength(1), reason: '$algo $model');
      }
    }
  });

  test('reachable actual RGB solves meet target while impossible solves never flip', () {
    for (final nominal in [20.0, 90.0]) {
      final direction = sharedForegroundDirection(
        backgroundTone: nominal,
        contrast: .5,
      );
      for (var hue = 0.0; hue < 360; hue += 30) {
        final background = at(hue, 100, nominal, ColorModel.cam16v11);
        final palette = Palette.fromColorAndBackground(
          at(hue + 120, 80, 50, ColorModel.cam16v11),
          background,
          backgroundTone: nominal,
          contrast: .5,
        );
        for (final foreground in [palette.backgroundText, palette.text]) {
          expect(
            isLighter(foreground, background),
            direction == ContrastDirection.lighter,
          );
          expect(
            apcaFromArgbs(foreground.toARGB32(), background.toARGB32()).abs(),
            greaterThanOrEqualTo(60),
            reason: 'T$nominal H$hue',
          );
        }
      }
    }
    const nominal = 66.0;
    final direction = sharedForegroundDirection(
      backgroundTone: nominal,
      contrast: 1,
    );
    final background = at(300, 100, nominal, ColorModel.cam16v11);
    final impossible = Palette.fromColorAndBackground(
      Colors.orange,
      background,
      backgroundTone: nominal,
      contrast: 1,
    );
    for (final foreground in [impossible.backgroundText, impossible.text]) {
      expect(
        isLighter(foreground, background),
        direction == ContrastDirection.lighter,
        reason: 'unreachable Lc110 must clamp without a palette-specific flip',
      );
      expect(
        lstarFromArgb(foreground.toARGB32()),
        direction == ContrastDirection.lighter
            ? greaterThan(99.7)
            : lessThan(.3),
      );
    }
  });

  test('a worst-case miss still lets favorable actual RGB succeed', () {
    const nominal = 62.0;
    expect(
      sharedForegroundDirection(backgroundTone: nominal, contrast: .5),
      ContrastDirection.lighter,
      reason:
          'neither direction is guaranteed; light has more worst-case capacity',
    );
    var successes = 0, clamps = 0;
    for (var hue = 0.0; hue < 360; hue += 5) {
      final background = at(hue, 140, nominal, ColorModel.cam16v11);
      final palette = Palette.fromColorAndBackground(
        Colors.orange,
        background,
        backgroundTone: nominal,
        contrast: .5,
      );
      final achieved = apcaFromArgbs(
        palette.backgroundText.toARGB32(),
        background.toARGB32(),
      ).abs();
      if (achieved >= 60) {
        successes++;
      } else {
        clamps++;
        expect(
          lstarFromArgb(palette.backgroundText.toARGB32()),
          greaterThan(99.7),
        );
      }
    }
    expect(successes, greaterThan(0));
    expect(clamps, greaterThan(0));
  });

  test('nested surfaces choose their own context polarity', () {
    final background = at(30, 30, 90, ColorModel.cam16v11);
    final darkButton = at(220, 60, 20, ColorModel.cam16v11);
    final palette = Palette.fromColorAndBackground(
      darkButton,
      background,
      backgroundTone: 90,
      contrast: .5,
    );
    expect(isLighter(palette.backgroundText, background), isFalse);
    expect(isLighter(palette.text, background), isFalse);
    expect(
      isLighter(palette.colorText, darkButton),
      isTrue,
      reason: 'button text belongs to the button surface, not the page context',
    );
  });

  test(
    'explicit backgrounds without a shared tone remain separate contexts',
    () {
      final dark = at(220, 100, 20, ColorModel.cam16v11);
      final light = at(20, 100, 90, ColorModel.cam16v11);
      final darkPalette = Palette.fromColorAndBackground(Colors.orange, dark);
      final lightPalette = Palette.fromColorAndBackground(Colors.orange, light);
      expect(isLighter(darkPalette.backgroundText, dark), isTrue);
      expect(isLighter(lightPalette.backgroundText, light), isFalse);

      final theme = MonetThemeData.fromColors(
        brightness: Brightness.light,
        backgroundTone: 90,
        primary: Colors.red,
        secondary: Colors.green,
        tertiary: Colors.blue,
      );
      final ownContext = ColorPaletteRecipe(
        Colors.orange,
        background: dark,
      ).resolve(theme);
      expect(
        isLighter(ownContext.backgroundText, dark),
        isTrue,
        reason: 'an explicit recipe does not inherit the page tone implicitly',
      );
    },
  );

  test(
    'theme palettes and typed custom recipes retain shared policy inputs',
    () {
      final theme = MonetThemeData.fromColors(
        brightness: Brightness.light,
        backgroundTone: 66.6,
        primary: Colors.red,
        secondary: Colors.green,
        tertiary: Colors.blue,
        contrast: .5,
      );
      final themeDirections = [
        theme.primary,
        theme.secondary,
        theme.tertiary,
      ].map((p) => isLighter(p.backgroundText, p.background)).toSet();
      expect(themeDirections, hasLength(1));

      final backgrounds = [
        at(0, 100, 66.6, ColorModel.cam16v11),
        at(120, 100, 66.6, ColorModel.cam16v11),
        at(240, 100, 66.6, ColorModel.cam16v11),
      ];
      final recipes = [
        for (var i = 0; i < backgrounds.length; i++)
          ColorPaletteRecipe(
            [Colors.red, Colors.green, Colors.blue][i],
            background: backgrounds[i],
            backgroundTone: 66.6,
          ),
      ];
      final recipeDirections = recipes.map((r) {
        final p = r.resolve(theme);
        return isLighter(p.backgroundText, p.background);
      }).toSet();
      expect(recipeDirections, hasLength(1));
      expect(
        recipes.first,
        isNot(
          ColorPaletteRecipe(
            Colors.red,
            background: backgrounds.first,
            backgroundTone: 67,
          ),
        ),
        reason: 'recipe identity includes the shared policy tone',
      );
      final inherited = const ColorPaletteRecipe(Color(0xfff5a623))
          .resolve(theme);
      expect(
        isLighter(inherited.backgroundText, inherited.background),
        sharedForegroundDirection(
              backgroundTone: theme.backgroundTone,
              contrast: theme.contrast,
            ) ==
            ContrastDirection.lighter,
      );
    },
  );

  testWidgets('Material onSurface uses the original theme context tone', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );
    for (final algo in Algo.values) {
      for (final model in ColorModel.values) {
        final theme = MonetThemeData.fromColors(
          brightness: Brightness.light,
          backgroundTone: 66.6,
          primary: Colors.red,
          secondary: Colors.green,
          tertiary: Colors.blue,
          algo: algo,
          colorModel: model,
        );
        final scheme = theme.createThemeData(context).colorScheme;
        expect(
          isLighter(scheme.onSurface, scheme.surface),
          sharedForegroundDirection(
                backgroundTone: theme.backgroundTone,
                contrast: theme.contrast,
                by: algo,
              ) ==
              ContrastDirection.lighter,
          reason: '$algo $model',
        );
      }
    }
  });
}
