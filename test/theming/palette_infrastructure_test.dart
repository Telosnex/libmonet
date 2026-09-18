import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/libmonet.dart';
import 'package:libmonet/theming/palette_lerped.dart';

MonetThemeData theme({
  Algo algo = Algo.apca,
  ColorModel model = ColorModel.kDefault,
}) => MonetThemeData.fromColors(
  brightness: Brightness.light,
  backgroundTone: 94,
  primary: const Color(0xffba481d),
  secondary: Colors.teal,
  tertiary: Colors.orange,
  algo: algo,
  colorModel: model,
);

class _CountingPalette extends RolePalette {
  _CountingPalette(this.seed, super.colorModel);
  final int seed;
  final Map<PaletteRole, int> reads = {};
  @override
  Color readRole(PaletteRole role) {
    reads.update(role, (n) => n + 1, ifAbsent: () => 1);
    return Color(0xff000000 | (seed + role.index * 3109));
  }
}

void main() {
  test('output schema includes every public color getter', () {
    final source = File('lib/theming/palette.dart')
        .readAsStringSync()
        .split('class _ComputedPalette')
        .first;
    final getters = RegExp(r'Color get (\w+);')
        .allMatches(source)
        .map((m) => m[1]!)
        .toSet();
    expect(PaletteRole.values.map((r) => r.name).toSet(), getters);
  });

  test(
    'snapshots are complete, immutable and compare outputs rather than seeds',
    () {
      for (final model in ColorModel.values) {
        final source = _CountingPalette(0x123456, model);
        final snapshot = PaletteSnapshot.capture(source);
        expect(source.reads.values, everyElement(1));
        expect(source.reads.length, PaletteRole.values.length);
        final same = PaletteSnapshot.capture(_CountingPalette(0x123456, model));
        expect(snapshot, same);
        expect(snapshot.hashCode, same.hashCode);
        for (final role in PaletteRole.values) {
          expect(
            role.read(snapshot),
            Color(0xff000000 | (source.seed + role.index * 3109)),
          );
        }
        expect(source.reads.values, everyElement(1));
        expect(() => snapshot.colors[0] = Colors.red, throwsUnsupportedError);
        expect(() => ResolvedPalette([], model), throwsArgumentError);
        final bright = PaletteSnapshot.capture(
          Palette.from(
            Colors.red,
            backgroundTone: 60,
            contrast: .9,
            colorModel: model,
          ),
        );
        final dim = PaletteSnapshot.capture(
          Palette.from(
            Colors.red,
            backgroundTone: 60,
            contrast: .1,
            colorModel: model,
          ),
        );
        expect(bright, isNot(dim));
      }
    },
  );

  test(
    'lerp construction, hashing and endpoint access do no unrelated work',
    () {
      final a = _CountingPalette(0x112233, ColorModel.cam16);
      final b = _CountingPalette(0x998877, ColorModel.oklch);
      final start = PaletteLerped(a: a, b: b, t: 0);
      final end = PaletteLerped(a: a, b: b, t: 1);
      expect(start, PaletteLerped(a: a, b: b, t: 0));
      start.hashCode;
      expect(a.reads, isEmpty);
      expect(b.reads, isEmpty);
      start.text;
      start.text;
      expect(a.reads, {PaletteRole.text: 1});
      expect(b.reads, isEmpty);
      end.fill;
      end.fill;
      expect(b.reads, {PaletteRole.fill: 1});
      expect(end.colorModel, ColorModel.oklch);
      expect(start.colorModel, ColorModel.cam16);
      for (final style in InterpolationStyle.values) {
        final mid = PaletteLerped(a: a, b: b, t: .3, interpolationStyle: style);
        for (final role in PaletteRole.values) {
          final color = role.read(mid);
          final beforeA = a.reads[role], beforeB = b.reads[role];
          expect(role.read(mid), color);
          expect(a.reads[role], beforeA);
          expect(b.reads[role], beforeB);
        }
      }
    },
  );

  test(
    'computed palette identity includes policy but does not read adapters',
    () {
      final a = Palette.fromColorAndBackground(Colors.blue, Colors.white);
      final b = Palette.fromColorAndBackground(Colors.blue, Colors.white);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      final hash = a.hashCode;
      for (final role in PaletteRole.values) {
        expect(role.read(a), role.read(b));
      }
      expect(a.hashCode, hash);
      final observer = _CountingPalette(0x123456, ColorModel.kDefault);
      expect(a, isNot(observer));
      expect(observer.reads, isEmpty);
      expect(
        Palette.fromColorAndBackground(
          Colors.blue,
          Colors.white,
          backgroundTone: 99,
        ),
        isNot(a),
        reason: 'logical polarity context participates in endpoint identity',
      );
    },
  );

  test(
    'scheme extension faithfully maps all 51 fields from all three palettes',
    () {
      final palettes = [
        for (var i = 0; i < 3; i++)
          _CountingPalette(0x123456 + i * 80000, ColorModel.kDefault),
      ];
      final s = MonetColorScheme.fromPalettes(
        primary: palettes[0],
        secondary: palettes[1],
        tertiary: palettes[2],
      );
      final actual = [
        [
          s.primaryColor,
          s.primaryColorText,
          s.primaryColorHover,
          s.primaryColorHoverText,
          s.primaryColorSplash,
          s.primaryColorSplashText,
          s.primaryFill,
          s.primaryFillText,
          s.primaryFillHover,
          s.primaryFillHoverText,
          s.primaryFillSplash,
          s.primaryFillSplashText,
          s.primaryText,
          s.primaryTextHover,
          s.primaryTextHoverText,
          s.primaryTextSplash,
          s.primaryTextSplashText,
        ],
        [
          s.secondaryColor,
          s.secondaryColorText,
          s.secondaryColorHover,
          s.secondaryColorHoverText,
          s.secondaryColorSplash,
          s.secondaryColorSplashText,
          s.secondaryFill,
          s.secondaryFillText,
          s.secondaryFillHover,
          s.secondaryFillHoverText,
          s.secondaryFillSplash,
          s.secondaryFillSplashText,
          s.secondaryText,
          s.secondaryTextHover,
          s.secondaryTextHoverText,
          s.secondaryTextSplash,
          s.secondaryTextSplashText,
        ],
        [
          s.tertiaryColor,
          s.tertiaryColorText,
          s.tertiaryColorHover,
          s.tertiaryColorHoverText,
          s.tertiaryColorSplash,
          s.tertiaryColorSplashText,
          s.tertiaryFill,
          s.tertiaryFillText,
          s.tertiaryFillHover,
          s.tertiaryFillHoverText,
          s.tertiaryFillSplash,
          s.tertiaryFillSplashText,
          s.tertiaryText,
          s.tertiaryTextHover,
          s.tertiaryTextHoverText,
          s.tertiaryTextSplash,
          s.tertiaryTextSplashText,
        ],
      ];
      const roles = [
        PaletteRole.color,
        PaletteRole.colorText,
        PaletteRole.colorHovered,
        PaletteRole.colorHoveredText,
        PaletteRole.colorSplashed,
        PaletteRole.colorSplashedText,
        PaletteRole.fill,
        PaletteRole.fillText,
        PaletteRole.fillHovered,
        PaletteRole.fillHoveredText,
        PaletteRole.fillSplashed,
        PaletteRole.fillSplashedText,
        PaletteRole.text,
        PaletteRole.textHovered,
        PaletteRole.textHoveredText,
        PaletteRole.textSplashed,
        PaletteRole.textSplashedText,
      ];
      for (var i = 0; i < 3; i++) {
        expect(actual[i], [for (final r in roles) r.read(palettes[i])]);
      }
    },
  );

  testWidgets('theme cache is bounded, LRU, semantic and subscribes on a hit', (
    tester,
  ) async {
    MonetThemeData.debugClearThemeCache();
    addTearDown(MonetThemeData.debugClearThemeCache);
    late BuildContext context;
    late StateSetter update;
    var scaler = TextScaler.noScaling, dpr = 1.0;
    var builds = 0;
    final data = theme();
    late ThemeData latest;
    final child = Builder(
      builder: (c) {
        context = c;
        builds++;
        latest = data.createThemeData(c);
        return const SizedBox();
      },
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return MediaQuery(
              data: MediaQueryData(textScaler: scaler, devicePixelRatio: dpr),
              child: child,
            );
          },
        ),
      ),
    );
    final initial = latest;
    expect(theme().createThemeData(context), same(initial));
    update(() => scaler = const TextScaler.linear(1.5));
    await tester.pump();
    expect(builds, 2);
    expect(latest, isNot(same(initial)));
    final scaled = latest;
    update(() => dpr = 2);
    await tester.pump();
    expect(builds, 3);
    expect(latest, isNot(same(scaled)));
    update(() {
      scaler = TextScaler.noScaling;
      dpr = 1;
    });
    await tester.pump();
    expect(latest, same(initial)); // warm hit still registers dependencies
    update(() => dpr = 3);
    await tester.pump();
    expect(builds, 5);
    final hot = data.createThemeData(context);
    for (var i = 0; i < 80; i++) {
      data.copyWith(scale: 1 + i / 100).createThemeData(context);
      expect(data.createThemeData(context), same(hot));
      expect(
        MonetThemeData.debugThemeCacheSize,
        lessThanOrEqualTo(MonetThemeData.themeCacheCapacity),
      );
    }
    expect(
      MonetThemeData.debugThemeCacheSize,
      MonetThemeData.themeCacheCapacity,
    );
    // Remove hot status, evict even though the weak value is externally retained.
    for (var i = 0; i < 40; i++) {
      data.copyWith(scale: 2 + i / 100).createThemeData(context);
    }
    expect(data.createThemeData(context), isNot(same(hot)));
  });

  testWidgets(
    'Material surface/error honor the selected algorithm in every model',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      for (final model in ColorModel.values) {
        for (final algo in Algo.values) {
          final data = theme(algo: algo, model: model);
          final scheme = data.createThemeData(context).colorScheme;
          final expected = Palette.fromColorAndBackground(
            scheme.surface,
            scheme.surface,
            backgroundTone: data.backgroundTone,
            algo: algo,
            colorModel: model,
            contrast: data.contrast,
          ).backgroundText;
          expect(scheme.onSurface, expected, reason: '$algo $model');
          expect(
            scheme.onError,
            Palette.from(
              Colors.red,
              backgroundTone: 94,
              algo: algo,
              colorModel: model,
            ).colorText,
          );
          if (algo == Algo.wcag21) {
            expect(
              algo.contrastBetweenArgbs(
                bgArgb: scheme.surface.toARGB32(),
                fgArgb: scheme.onSurface.toARGB32(),
              ),
              greaterThanOrEqualTo(4.5),
            );
          }
        }
      }
    },
  );

  testWidgets('theme cache separates platform-dependent components', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final data = theme();
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final android = data.createThemeData(context);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final ios = data.createThemeData(context);
      expect(ios, isNot(same(android)));
      expect(android.platform, TargetPlatform.android);
      expect(ios.platform, TargetPlatform.iOS);
      expect(android.splashFactory, InkSparkle.splashFactory);
      expect(ios.splashFactory, InkRipple.splashFactory);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(data.createThemeData(context), same(android));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('near-neutral backgrounds use native model chroma caps and preserve explicit surfaces', () {
    for (final model in ColorModel.values) {
      for (final seed in [
        Colors.red,
        Colors.green,
        Colors.blue,
        Colors.amber,
        Colors.grey,
      ]) {
        for (final tone in [20.0, 60.0, 94.0]) {
          final p = Palette.from(seed, backgroundTone: tone, colorModel: model);
          final hct = Hct.fromColor(p.background, model: model);
          expect(
            hct.chroma,
            lessThanOrEqualTo(
              model.neutralBackgroundChroma +
                  (model == ColorModel.oklch ? .004 : 1.5),
            ),
          );
          expect(hct.tone, closeTo(tone, .4));
          expect(p.color, seed);
          expect(
            Palette.fromColorAndBackground(
              seed,
              Colors.red,
              colorModel: model,
            ).background,
            Colors.red,
          );
        }
      }
    }
  });

  test('overlay borders validate actual tinted surfaces on either side', () {
    for (final model in ColorModel.values) {
      for (final algo in Algo.values) {
        for (final background in [
          Colors.indigo,
          Colors.orange,
          Colors.teal,
          Colors.white,
        ]) {
          final p = Palette.fromColorAndBackground(
            Colors.red,
            background,
            algo: algo,
            colorModel: model,
            contrast: .3,
          );
          for (final pair in [
            (p.backgroundHovered, p.backgroundHoveredBorder),
            (p.backgroundSplashed, p.backgroundSplashedBorder),
            (p.fillHovered, p.fillHoveredBorder),
            (p.fillSplashed, p.fillSplashedBorder),
            (p.colorHovered, p.colorHoveredBorder),
            (p.colorSplashed, p.colorSplashedBorder),
          ]) {
            final required = algo.getAbsoluteContrast(.3, Usage.border);
            final contrasts = [
              for (final surface in [pair.$1, background]) ...[
                algo
                    .contrastBetweenArgbs(
                      bgArgb: surface.toARGB32(),
                      fgArgb: pair.$2.toARGB32(),
                    )
                    .abs(),
                algo
                    .contrastBetweenArgbs(
                      bgArgb: pair.$2.toARGB32(),
                      fgArgb: surface.toARGB32(),
                    )
                    .abs(),
              ],
            ];
            expect(
              contrasts.any((v) => v >= required),
              true,
              reason: '$model $algo $background $pair',
            );
          }
        }
      }
    }
  });
}
