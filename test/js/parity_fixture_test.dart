// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/material.dart' show Brightness;
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/contrast/apca_contrast.dart' as apca_contrast;
import 'package:libmonet/libmonet.dart';
import 'package:libmonet/theming/palette_lerped.dart';

const _paletteRoles = <String>[
  'background',
  'backgroundText',
  'backgroundFill',
  'backgroundBorder',
  'backgroundHovered',
  'backgroundSplashed',
  'backgroundHoveredFill',
  'backgroundSplashedFill',
  'backgroundHoveredText',
  'backgroundSplashedText',
  'backgroundHoveredBorder',
  'backgroundSplashedBorder',
  'color',
  'colorText',
  'colorIcon',
  'colorHovered',
  'colorSplashed',
  'colorHoveredText',
  'colorSplashedText',
  'colorHoveredIcon',
  'colorSplashedIcon',
  'colorBorder',
  'colorHoveredBorder',
  'colorSplashedBorder',
  'fill',
  'fillText',
  'fillIcon',
  'fillHovered',
  'fillSplashed',
  'fillHoveredText',
  'fillSplashedText',
  'fillHoveredIcon',
  'fillSplashedIcon',
  'fillBorder',
  'fillHoveredBorder',
  'fillSplashedBorder',
  'text',
  'textHovered',
  'textSplashed',
  'textHoveredText',
  'textSplashedText',
];

String _hex(Color color) => hexFromArgb(color.argb).toUpperCase();

Map<String, String> _paletteRecord(Palette p) => {
  'background': _hex(p.background),
  'backgroundText': _hex(p.backgroundText),
  'backgroundFill': _hex(p.backgroundFill),
  'backgroundBorder': _hex(p.backgroundBorder),
  'backgroundHovered': _hex(p.backgroundHovered),
  'backgroundSplashed': _hex(p.backgroundSplashed),
  'backgroundHoveredFill': _hex(p.backgroundHoveredFill),
  'backgroundSplashedFill': _hex(p.backgroundSplashedFill),
  'backgroundHoveredText': _hex(p.backgroundHoveredText),
  'backgroundSplashedText': _hex(p.backgroundSplashedText),
  'backgroundHoveredBorder': _hex(p.backgroundHoveredBorder),
  'backgroundSplashedBorder': _hex(p.backgroundSplashedBorder),
  'color': _hex(p.color),
  'colorText': _hex(p.colorText),
  'colorIcon': _hex(p.colorIcon),
  'colorHovered': _hex(p.colorHovered),
  'colorSplashed': _hex(p.colorSplashed),
  'colorHoveredText': _hex(p.colorHoveredText),
  'colorSplashedText': _hex(p.colorSplashedText),
  'colorHoveredIcon': _hex(p.colorHoveredIcon),
  'colorSplashedIcon': _hex(p.colorSplashedIcon),
  'colorBorder': _hex(p.colorBorder),
  'colorHoveredBorder': _hex(p.colorHoveredBorder),
  'colorSplashedBorder': _hex(p.colorSplashedBorder),
  'fill': _hex(p.fill),
  'fillText': _hex(p.fillText),
  'fillIcon': _hex(p.fillIcon),
  'fillHovered': _hex(p.fillHovered),
  'fillSplashed': _hex(p.fillSplashed),
  'fillHoveredText': _hex(p.fillHoveredText),
  'fillSplashedText': _hex(p.fillSplashedText),
  'fillHoveredIcon': _hex(p.fillHoveredIcon),
  'fillSplashedIcon': _hex(p.fillSplashedIcon),
  'fillBorder': _hex(p.fillBorder),
  'fillHoveredBorder': _hex(p.fillHoveredBorder),
  'fillSplashedBorder': _hex(p.fillSplashedBorder),
  'text': _hex(p.text),
  'textHovered': _hex(p.textHovered),
  'textSplashed': _hex(p.textSplashed),
  'textHoveredText': _hex(p.textHoveredText),
  'textSplashedText': _hex(p.textSplashedText),
};

Map<String, Object?> _hctColorCase(int argb) {
  final hct = Hct.fromInt(argb);
  return {
    'argb': _hex(Color(argb)),
    'hue': hct.hue,
    'chroma': hct.chroma,
    'tone': hct.tone,
    'roundTrip': _hex(hct.color),
  };
}

List<Map<String, Object?>> _hctRoundTripSweepCases() {
  const channels = [0x00, 0x11, 0x33, 0x55, 0x77, 0x99, 0xbb, 0xdd, 0xff];
  final cases = <Map<String, Object?>>[];
  for (final r in channels) {
    for (final g in channels) {
      for (final b in channels) {
        cases.add(_hctColorCase(0xff000000 | (r << 16) | (g << 8) | b));
      }
    }
  }
  return cases;
}

List<Map<String, Object?>> _hctSolveSweepCases() {
  final cases = <Map<String, Object?>>[];
  const hues = [0.0, 30.0, 60.0, 90.0, 120.0, 180.0, 240.0, 300.0, 330.0];
  const chromas = [0.0, 4.0, 16.0, 48.0, 96.0, 120.0];
  const tones = [0.0, 10.0, 25.0, 50.0, 75.0, 90.0, 100.0];
  for (final hue in hues) {
    for (final chroma in chromas) {
      for (final tone in tones) {
        cases.add(
          _hctSolveCase(
            name:
                'h${hue.toStringAsFixed(0)}-c${chroma.toStringAsFixed(0)}-t${tone.toStringAsFixed(0)}',
            hue: hue,
            chroma: chroma,
            tone: tone,
          ),
        );
      }
    }
  }
  return cases;
}

Map<String, Object?> _hctSolveCase({
  required String name,
  required double hue,
  required double chroma,
  required double tone,
}) {
  final hct = Hct.from(hue, chroma, tone);
  return {
    'name': name,
    'hue': hue,
    'chroma': chroma,
    'tone': tone,
    'argb': _hex(hct.color),
    'actualHue': hct.hue,
    'actualChroma': hct.chroma,
    'actualTone': hct.tone,
  };
}

Map<String, Object?> _hctModelCase({
  required String name,
  required int argb,
  required ColorModel model,
}) {
  final hct = Hct.fromInt(argb, model: model);
  final solved = Hct.from(hct.hue, hct.chroma, hct.tone, model: model);
  return {
    'name': name,
    'model': model.name,
    'argb': _hex(Color(argb)),
    'hue': hct.hue,
    'chroma': hct.chroma,
    'tone': hct.tone,
    'solvedArgb': _hex(solved.color),
    'solvedHue': solved.hue,
    'solvedChroma': solved.chroma,
    'solvedTone': solved.tone,
  };
}

Map<String, Object?> _temperatureCase(int argb) {
  final cache = TemperatureCache(Hct.fromInt(argb));
  return {
    'argb': _hex(Color(argb)),
    'complement': _hex(cache.complement.color),
    'analogous': cache
        .analogous(count: 5, divisions: 12)
        .map((hct) => _hex(hct.color))
        .toList(),
    'inputRelativeTemperature': cache.inputRelativeTemperature,
    'coldest': _hex(cache.coldest.color),
    'warmest': _hex(cache.warmest.color),
  };
}

Map<String, Object?> _lumaCase(double luma, {int? argb, double? lstar}) {
  final result = <String, Object?>{
    'luma': luma,
    'grayscale': _hex(Color(grayscaleArgbFromLuma(luma))),
    'boundaryArgbs': findBoundaryArgbsForLuma(
      luma,
    ).map((argb) => _hex(Color(argb))).toList(),
    'lstarRange': lumaToLstarRange(luma),
  };
  if (argb != null) {
    result['argb'] = _hex(Color(argb));
    result['lumaFromArgb'] = lumaFromArgb(argb);
  }
  if (lstar != null) {
    result['lstar'] = lstar;
    result['lumaFromLstar'] = lumaFromLstar(lstar);
  }
  return result;
}

Map<String, Object?> _apcaInverseCase({
  required String name,
  required double lstar,
  required double apca,
}) {
  final apcaY = lstarToApcaY(lstar);
  final lighterBgY = apca_contrast.lighterBackgroundApcaY(apcaY, apca);
  final darkerBgY = apca_contrast.darkerBackgroundApcaY(apcaY, apca);
  final lighterTextY = apca_contrast.lighterTextApcaY(apcaY, apca);
  final darkerTextY = apca_contrast.darkerTextApcaY(apcaY, apca);
  return {
    'name': name,
    'lstar': lstar,
    'apca': apca,
    'apcaY': apcaY,
    'lighterBackgroundApcaY': lighterBgY,
    'darkerBackgroundApcaY': darkerBgY,
    'lighterTextApcaY': lighterTextY,
    'darkerTextApcaY': darkerTextY,
    'lighterBackgroundLstarUnsafe': apca_contrast.lighterBackgroundLstarUnsafe(
      lstar,
      apca,
    ),
    'lighterBackgroundLstar': apca_contrast.lighterBackgroundLstar(lstar, apca),
    'darkerBackgroundLstarUnsafe': apca_contrast.darkerBackgroundLstarUnsafe(
      lstar,
      apca,
    ),
    'darkerBackgroundLstar': apca_contrast.darkerBackgroundLstar(lstar, apca),
    'lighterTextLstarUnsafe': apca_contrast.lighterTextLstarUnsafe(lstar, apca),
    'lighterTextLstar': apca_contrast.lighterTextLstar(lstar, apca),
    'darkerTextLstarUnsafe': apca_contrast.darkerTextLstarUnsafe(lstar, apca),
    'darkerTextLstar': apca_contrast.darkerTextLstar(lstar, apca),
    'boundaryArgbs': apca_contrast
        .findBoundaryArgbsForApcaY(apcaY)
        .map((argb) => _hex(Color(argb)))
        .toList(),
  };
}

Map<String, Object?> _opacityCase({
  required String name,
  required int foreground,
  required int minBackground,
  required int maxBackground,
  required double contrast,
  required Algo algo,
}) {
  final result = getOpacityForArgbs(
    foregroundArgb: foreground,
    minBackgroundArgb: minBackground,
    maxBackgroundArgb: maxBackground,
    contrast: contrast,
    algo: algo,
  );
  return {
    'name': name,
    'foreground': _hex(Color(foreground)),
    'minBackground': _hex(Color(minBackground)),
    'maxBackground': _hex(Color(maxBackground)),
    'contrast': contrast,
    'algo': algo.name,
    'protectionArgb': _hex(Color(result.protectionArgb)),
    'opacity': result.opacity,
    'targetLstar': result.targetLstar,
    'needsProtection': result.needsProtection,
    'color': _hex(result.color),
    'protectionLstar': result.protectionLstar,
    'protectionLuma': result.protectionLuma,
  };
}

Map<String, Object?> _shadowCase({
  required String name,
  required int foreground,
  required int minBackground,
  required int maxBackground,
  required double contrast,
  required Algo algo,
  required double blurRadius,
  double contentRadius = -1.0,
}) {
  final result = getShadowOpacitiesForArgbs(
    foregroundArgb: foreground,
    minBackgroundArgb: minBackground,
    maxBackgroundArgb: maxBackground,
    contrast: contrast,
    algo: algo,
    blurRadius: blurRadius,
    contentRadius: contentRadius,
  );
  return {
    'name': name,
    'foreground': _hex(Color(foreground)),
    'minBackground': _hex(Color(minBackground)),
    'maxBackground': _hex(Color(maxBackground)),
    'contrast': contrast,
    'algo': algo.name,
    'blurRadius': blurRadius,
    'contentRadius': contentRadius,
    'resultBlurRadius': result.blurRadius,
    'shadowArgb': _hex(Color(result.shadowArgb)),
    'opacities': result.opacities,
  };
}

Map<String, Object?> _paletteCase({
  required String name,
  required int color,
  required double backgroundTone,
  Algo algo = Algo.apca,
  double contrast = 0.5,
  ColorModel colorModel = ColorModel.kDefault,
}) {
  final p = Palette.from(
    Color(color),
    backgroundTone: backgroundTone,
    algo: algo,
    contrast: contrast,
    colorModel: colorModel,
  );
  return {
    'name': name,
    'color': _hex(Color(color)),
    'backgroundTone': backgroundTone,
    'algo': algo.name,
    'contrast': contrast,
    'colorModel': colorModel.name,
    'roles': _paletteRecord(p),
  };
}

List<Map<String, Object?>> _paletteSweepCases() {
  final cases = <Map<String, Object?>>[];
  const hues = [0.0, 30.0, 60.0, 120.0, 180.0, 240.0, 300.0, 330.0];
  const chromas = [4.0, 16.0, 48.0, 96.0];
  const tones = [35.0, 55.0, 75.0];
  const backgroundTones = [0.0, 10.0, 50.0, 93.0, 100.0];
  const contrasts = [0.2, 0.5, 0.8, 1.0];
  const algos = [Algo.apca, Algo.wcag21];

  for (final hue in hues) {
    for (final chroma in chromas) {
      for (final tone in tones) {
        final color = Hct.from(hue, chroma, tone).color.argb;
        for (final backgroundTone in backgroundTones) {
          for (final contrast in contrasts) {
            for (final algo in algos) {
              cases.add(
                _paletteCase(
                  name:
                      'h${hue.toStringAsFixed(0)}-c${chroma.toStringAsFixed(0)}-t${tone.toStringAsFixed(0)}-bg${backgroundTone.toStringAsFixed(0)}-${algo.name}-k${(contrast * 10).toStringAsFixed(0)}',
                  color: color,
                  backgroundTone: backgroundTone,
                  algo: algo,
                  contrast: contrast,
                ),
              );
            }
          }
        }
      }
    }
  }
  return cases;
}

Map<String, Object?> _paletteWithBackgroundCase({
  required String name,
  required int color,
  required int background,
  Algo algo = Algo.apca,
  double contrast = 0.5,
  ColorModel colorModel = ColorModel.kDefault,
}) {
  final p = Palette.fromColorAndBackground(
    Color(color),
    Color(background),
    algo: algo,
    contrast: contrast,
    colorModel: colorModel,
  );
  return {
    'name': name,
    'color': _hex(Color(color)),
    'background': _hex(Color(background)),
    'algo': algo.name,
    'contrast': contrast,
    'colorModel': colorModel.name,
    'roles': _paletteRecord(p),
  };
}

Map<String, Object?> _lerpCase({
  required String name,
  required int aColor,
  required double aBackgroundTone,
  required int bColor,
  required double bBackgroundTone,
  required double t,
  required InterpolationStyle style,
}) {
  final a = Palette.from(Color(aColor), backgroundTone: aBackgroundTone);
  final b = Palette.from(Color(bColor), backgroundTone: bBackgroundTone);
  final lerped = PaletteLerped(a: a, b: b, t: t, interpolationStyle: style);
  return {
    'name': name,
    'aColor': _hex(Color(aColor)),
    'aBackgroundTone': aBackgroundTone,
    'bColor': _hex(Color(bColor)),
    'bBackgroundTone': bBackgroundTone,
    't': t,
    'style': style.name,
    'roles': _paletteRecord(lerped),
  };
}

Map<String, Object?> _themeCase({
  required String name,
  required int color,
  required double backgroundTone,
  required Brightness brightness,
  double contrast = 0.5,
}) {
  final theme = MonetThemeData.fromColor(
    color: Color(color),
    backgroundTone: backgroundTone,
    brightness: brightness,
    contrast: contrast,
  );
  return {
    'name': name,
    'color': _hex(Color(color)),
    'backgroundTone': backgroundTone,
    'brightness': brightness.name,
    'contrast': contrast,
    'primary': _paletteRecord(theme.primary),
    'secondary': _paletteRecord(theme.secondary),
    'tertiary': _paletteRecord(theme.tertiary),
  };
}

Future<Map<String, Object?>> _quantizerCase({
  required String name,
  required List<int> pixels,
  required int maxColors,
}) async {
  Map<String, int> stringify(Map<int, int> map) =>
      map.map((key, value) => MapEntry(_hex(Color(key)), value));
  final mapResult = await QuantizerMap().quantize(pixels, maxColors);
  final wuResult = await QuantizerWu().quantize(pixels, maxColors);
  final celebiResult = await QuantizerCelebi().quantize(pixels, maxColors);
  return {
    'name': name,
    'pixels': pixels.map((argb) => _hex(Color(argb))).toList(),
    'maxColors': maxColors,
    'map': stringify(mapResult.argbToCount),
    'wu': stringify(wuResult.argbToCount),
    'celebi': stringify(celebiResult.argbToCount),
  };
}

Map<String, Object?> _scorerCase({
  required String name,
  required Map<int, int> argbToCount,
  double? toneTooLow = 10,
  double? toneTooHigh = 95,
  double? minChroma,
}) {
  final result = QuantizerResult(argbToCount, lstarToCount: const {});
  final scorer = Scorer(
    result,
    toneTooLow: toneTooLow,
    toneTooHigh: toneTooHigh,
    minChroma: minChroma,
  );
  final triad = ScorerTriad.threeColorsFromQuantizer(
    result,
    toneTooLow: toneTooLow,
    toneTooHigh: toneTooHigh,
    minChroma: minChroma,
  );
  return {
    'name': name,
    'argbToCount': argbToCount.map(
      (key, value) => MapEntry(key.toString(), value),
    ),
    'argbEntries': argbToCount.entries
        .map((entry) => [_hex(Color(entry.key)), entry.value])
        .toList(),
    'toneTooLow': toneTooLow,
    'toneTooHigh': toneTooHigh,
    'minChroma': minChroma,
    'hcts': scorer.hcts.map((hct) => _hex(hct.color)).toList(),
    'hctCount': scorer.hcts.length,
    'triad': triad.map((hct) => _hex(hct.color)).toList(),
    'hueSamples': {
      '0': scorer.huePercent(0),
      '30': scorer.huePercent(30),
      '120': scorer.huePercent(120),
      '240': scorer.huePercent(240),
    },
    'primaryHueSamples': {
      '0': scorer.primaryHuePercent(0),
      '30': scorer.primaryHuePercent(30),
      '120': scorer.primaryHuePercent(120),
      '240': scorer.primaryHuePercent(240),
    },
  };
}

List<Map<String, Object?>> _wallpaperGoldenCases() => [
  {
    'name': 'aaron-burden-OA6OuqfSWew-unsplash.jpg',
    'quantizerFingerprint':
        'colors=32 total=6912 top=#DA9677:410,#A1A36B:401,#A7965B:368,#C0A278:342,#B6AD7B:332,#908F50:331,#BB9762:330,#D6A287:320',
    'triadHexes': ['#A6A26A', '#C0A278', '#C93916'],
  },
  {
    'name': 'allec-gomes-cb2WKRZA9i8-unsplash.jpg',
    'quantizerFingerprint':
        'colors=32 total=6144 top=#ED3303:639,#E40B03:484,#EB0A03:379,#DD1003:370,#522201:327,#461B01:304,#E36605:264,#351301:251',
    'triadHexes': ['#EC3500', '#E52725', '#522201'],
  },
  {
    'name': 'curated-lifestyle-7lQlYxH0Ljs-unsplash.jpg',
    'quantizerFingerprint':
        'colors=32 total=6144 top=#CDCEC8:1110,#CACBC5:720,#12130D:462,#0E0F0A:444,#D1D2CC:421,#C7C8C2:357,#151610:323,#161811:272',
    'triadHexes': ['#CDCEC8', '#CFCEC6', '#CCCECC'],
  },
  {
    'name': 'hanna-lazar-CXT0TZcpyyE-unsplash.jpg',
    'quantizerFingerprint':
        'colors=32 total=6144 top=#151218:558,#1A191D:403,#1A211A:278,#222025:267,#8E9E68:245,#A1B179:240,#2C581B:226,#306619:221',
    'triadHexes': ['#859F72', '#C5D7BD', '#A1B179'],
  },
  {
    'name': 'hans-isaacson-VrP25Libv-E-unsplash.jpg',
    'quantizerFingerprint':
        'colors=32 total=6048 top=#638C8B:373,#3B6469:371,#5B8584:361,#426D71:359,#6B9390:338,#537E7D:321,#759A97:306,#457172:304',
    'triadHexes': ['#628C8C', '#B7D3CB', '#C3DECD'],
  },
  {
    'name': 'henrique-ferreira-lneox9o1MjU-unsplash.jpg',
    'quantizerFingerprint':
        'colors=32 total=6144 top=#EDE7E3:1285,#F1E7DE:639,#E4E4E4:389,#9AA3AB:238,#D4D4D2:235,#BEBFBF:230,#F4E2D4:230,#ACAEB0:203',
    'triadHexes': ['#F7CF99', '#E4AF9D', '#668593'],
  },
  {
    'name': 'ingmar-E_PKxMtARbw-unsplash.jpg',
    'quantizerFingerprint':
        'colors=32 total=6144 top=#D7BBDB:935,#D1B1DB:737,#CBABDA:495,#C5A2D8:442,#DCC4DD:430,#E0CCDE:396,#BF9BD6:387,#C8A6D7:378',
    'triadHexes': ['#D6BBDB', '#4E3349', '#47272E'],
  },
  {
    'name': 'ingmar-_KZW2oCkRIQ-unsplash.jpg',
    'quantizerFingerprint':
        'colors=32 total=6816 top=#FD964C:2111,#FD9A48:944,#FD994B:569,#FC9845:513,#FD924C:440,#F8963C:297,#FB6346:159,#FA5E41:154',
    'triadHexes': ['#FD964C', '#F9B964', '#FB6346'],
  },
  {
    'name': 'lorin-both-2ScC2nkYYDk-unsplash.jpg',
    'quantizerFingerprint':
        'colors=32 total=7104 top=#B032ED:708,#A41DE3:618,#6C039D:495,#A926E9:468,#7403A9:458,#9C16DB:458,#BA44F3:445,#B63BF2:427',
    'triadHexes': ['#AA38F0', '#A849CA', '#51682C'],
  },
  {
    'name': 'lorin-both-C7X5ijG_-uM-unsplash.jpg',
    'quantizerFingerprint':
        'colors=32 total=6144 top=#F5C51F:735,#F1BC1C:571,#D78C0A:537,#DC930D:490,#CA7100:464,#E29F12:444,#ECB41A:439,#E9AC17:350',
    'triadHexes': ['#FDC12E', '#CA7101', '#426103'],
  },
  {
    'name': 'nick-fancher-BDr0sOaODXc-unsplash.jpg',
    'quantizerFingerprint':
        'colors=32 total=6144 top=#02050C:771,#01219B:382,#020C1B:321,#020E29:303,#010F36:298,#011457:298,#0237CC:296,#011E8F:276',
    'triadHexes': ['#002C83', '#015997', '#299DD4'],
  },
  {
    'name': 'solen-feyissa-u-VOCC2yg9s-unsplash.jpg',
    'quantizerFingerprint':
        'colors=32 total=6144 top=#FA8203:539,#FA8E03:474,#FB7603:451,#FA6803:392,#BE0201:360,#970201:351,#FB9B03:316,#8B0202:293',
    'triadHexes': ['#BD0B00', '#FA6800', '#FA8E06'],
  },
  {
    'name': 'zhenyu-luo-0MM2JsXz2aI-unsplash.jpg',
    'quantizerFingerprint':
        'colors=32 total=6144 top=#021C32:708,#062738:520,#052942:513,#020D15:481,#0A3549:481,#031523:461,#13445A:406,#0C3A56:362',
    'triadHexes': ['#092738', '#764037', '#F7DCC8'],
  },
  {
    'name': 'aaron-burden-OA6OuqfSWew-unsplash.jpg',
    'maxColors': 256,
    'quantizerFingerprint':
        'colors=256 total=6912 top=#ADAD7B:81,#AAAD73:77,#DEB198:76,#DC9D7A:65,#D29173:65,#A5A471:64,#CF9578:62,#D4A179:61',
    'triadHexes': ['#ADAD7B', '#3D5C48', '#DFB09A'],
  },
  {
    'name': 'curated-lifestyle-7lQlYxH0Ljs-unsplash.jpg',
    'maxColors': 256,
    'quantizerFingerprint':
        'colors=236 total=6144 top=#CCCDC7:555,#CBCCC6:456,#CECFC9:434,#12130E:291,#D0D1CB:255,#0F110B:213,#C9CAC4:179,#C7C8C2:170',
    'triadHexes': ['#CCCDC7', '#CECDC5', '#CBCDCB'],
  },
  {
    'name': 'lorin-both-2ScC2nkYYDk-unsplash.jpg',
    'maxColors': 256,
    'quantizerFingerprint':
        'colors=256 total=7104 top=#B740F3:263,#A31CE2:229,#AD2FEB:221,#AB27EA:219,#7202A6:219,#A61FE5:215,#69029A:213,#B236F0:209',
    'triadHexes': ['#B83FF2', '#302E05', '#303F17'],
  },
  {
    'name': 'zhenyu-luo-0MM2JsXz2aI-unsplash.jpg',
    'maxColors': 256,
    'quantizerFingerprint':
        'colors=256 total=6144 top=#000B10:157,#010D16:155,#021D32:143,#011321:139,#022134:125,#011B2D:124,#05283A:116,#011C34:115',
    'triadHexes': ['#002134', '#4B8582', '#D39A8C'],
  },
];

Map<String, Object?> _triadCase() {
  const argbToCount = <int, int>{
    0xffff0000: 50,
    0xff00ff00: 25,
    0xff0000ff: 25,
  };
  final result = QuantizerResult(argbToCount, lstarToCount: const {});
  final triad = ScorerTriad.threeColorsFromQuantizer(result);
  final theme = MonetThemeData.fromQuantizerResult(
    brightness: Brightness.light,
    backgroundTone: 93,
    quantizerResult: result,
  );
  return {
    'name': 'red-green-blue-weighted',
    'argbToCount': argbToCount.map(
      (key, value) => MapEntry(key.toString(), value),
    ),
    'triad': triad.map((hct) => _hex(hct.color)).toList(),
    'theme': {
      'primary': _paletteRecord(theme.primary),
      'secondary': _paletteRecord(theme.secondary),
      'tertiary': _paletteRecord(theme.tertiary),
    },
  };
}

void main() {
  test('generate JS parity fixtures', () async {
    final fixture = {
      'schema': 11,
      'paletteRoles': _paletteRoles,
      'hctColorCases': [
        _hctColorCase(0xff1177aa),
        _hctColorCase(0xff334157),
        _hctColorCase(0xffd29c57),
        _hctColorCase(0xfffe0032),
        _hctColorCase(0xffffffff),
        _hctColorCase(0xff000000),
      ],
      'hctRoundTripSweepCases': _hctRoundTripSweepCases(),
      'hctSolveCases': [
        _hctSolveCase(
          name: 'brand-bg-dark',
          hue: 241.54611525395205,
          chroma: 16,
          tone: 10,
        ),
        _hctSolveCase(
          name: 'brand-fill-dark',
          hue: 241.54611525395205,
          chroma: 44.88660912662872,
          tone: 61.5,
        ),
        _hctSolveCase(
          name: 'red-ish',
          hue: 27.408,
          chroma: 113.357,
          tone: 53.233,
        ),
      ],
      'hctSolveSweepCases': _hctSolveSweepCases(),
      'hctModelCases': [
        _hctModelCase(
          name: 'cam16-brand',
          argb: 0xff1177aa,
          model: ColorModel.cam16,
        ),
        _hctModelCase(
          name: 'cam16-golden',
          argb: 0xffd29c57,
          model: ColorModel.cam16,
        ),
        _hctModelCase(
          name: 'cam16-red',
          argb: 0xffff0033,
          model: ColorModel.cam16,
        ),
        _hctModelCase(
          name: 'oklch-brand',
          argb: 0xff1177aa,
          model: ColorModel.oklch,
        ),
        _hctModelCase(
          name: 'oklch-golden',
          argb: 0xffd29c57,
          model: ColorModel.oklch,
        ),
        _hctModelCase(
          name: 'oklch-red',
          argb: 0xffff0033,
          model: ColorModel.oklch,
        ),
      ],
      'temperatureCases': [
        _temperatureCase(0xff1177aa),
        _temperatureCase(0xff334157),
        _temperatureCase(0xffd29c57),
      ],
      'lumaCases': [
        _lumaCase(0, argb: 0xff000000, lstar: 0),
        _lumaCase(7.22, argb: 0xff0000ff, lstar: 25),
        _lumaCase(21.26, argb: 0xffff0000, lstar: 50),
        _lumaCase(50, argb: 0xff1177aa, lstar: 75),
        _lumaCase(71.52, argb: 0xff00ff00, lstar: 90),
        _lumaCase(100, argb: 0xffffffff, lstar: 100),
      ],
      'apcaInverseCases': [
        _apcaInverseCase(name: 'mid-lstar-lc60', lstar: 50, apca: 60),
        _apcaInverseCase(name: 'dark-lstar-lc60', lstar: 20, apca: 60),
        _apcaInverseCase(name: 'light-lstar-lc60', lstar: 90, apca: 60),
        _apcaInverseCase(name: 'near-black-lc110', lstar: 3, apca: 110),
        _apcaInverseCase(name: 'near-white-lc110', lstar: 97, apca: 110),
      ],
      'opacityCases': [
        _opacityCase(
          name: 'white-on-dark-no-protection-apca',
          foreground: 0xffffffff,
          minBackground: 0xff000000,
          maxBackground: 0xff101010,
          contrast: 0.5,
          algo: Algo.apca,
        ),
        _opacityCase(
          name: 'brand-on-wide-backgrounds-apca',
          foreground: 0xff1177aa,
          minBackground: 0xff202020,
          maxBackground: 0xffeeeeee,
          contrast: 0.5,
          algo: Algo.apca,
        ),
        _opacityCase(
          name: 'black-on-light-wcag',
          foreground: 0xff000000,
          minBackground: 0xffbbbbbb,
          maxBackground: 0xffffffff,
          contrast: 0.5,
          algo: Algo.wcag21,
        ),
        _opacityCase(
          name: 'brand-on-wide-backgrounds-wcag',
          foreground: 0xff1177aa,
          minBackground: 0xff202020,
          maxBackground: 0xffeeeeee,
          contrast: 0.8,
          algo: Algo.wcag21,
        ),
      ],
      'shadowCases': [
        _shadowCase(
          name: 'no-shadow-needed-apca',
          foreground: 0xffffffff,
          minBackground: 0xff000000,
          maxBackground: 0xff101010,
          contrast: 0.5,
          algo: Algo.apca,
          blurRadius: 4,
        ),
        _shadowCase(
          name: 'brand-wide-apca-blur4',
          foreground: 0xff1177aa,
          minBackground: 0xff202020,
          maxBackground: 0xffeeeeee,
          contrast: 0.5,
          algo: Algo.apca,
          blurRadius: 4,
        ),
        _shadowCase(
          name: 'brand-wide-wcag-blur6-content3',
          foreground: 0xff1177aa,
          minBackground: 0xff202020,
          maxBackground: 0xffeeeeee,
          contrast: 0.8,
          algo: Algo.wcag21,
          blurRadius: 6,
          contentRadius: 3,
        ),
      ],
      'quantizerCases': [
        await _quantizerCase(
          name: 'two-color-equal',
          pixels: const [0xffff0000, 0xffff0000, 0xff0000ff, 0xff0000ff],
          maxColors: 2,
        ),
        await _quantizerCase(
          name: 'weighted-three-color',
          pixels: const [
            0xffff0000,
            0xffff0000,
            0xffff0000,
            0xff00ff00,
            0xff00ff00,
            0xff0000ff,
          ],
          maxColors: 3,
        ),
      ],
      'paletteCases': [
        _paletteCase(
          name: 'brand-dark-apca',
          color: 0xff1177aa,
          backgroundTone: 10,
        ),
        _paletteCase(
          name: 'brand-light-apca',
          color: 0xff1177aa,
          backgroundTone: 93,
        ),
        _paletteCase(
          name: 'neutral-light-apca',
          color: 0xff334157,
          backgroundTone: 100,
        ),
        _paletteCase(
          name: 'neutral-dark-apca',
          color: 0xff334157,
          backgroundTone: 0,
        ),
        _paletteCase(
          name: 'golden-mid-apca',
          color: 0xffd29c57,
          backgroundTone: lstarFromArgb(0xffffca88),
        ),
        _paletteCase(
          name: 'brand-light-cam16',
          color: 0xff1177aa,
          backgroundTone: 93,
          colorModel: ColorModel.cam16,
        ),
        _paletteCase(
          name: 'golden-dark-cam16',
          color: 0xffd29c57,
          backgroundTone: 10,
          colorModel: ColorModel.cam16,
        ),
        _paletteCase(
          name: 'brand-light-oklch',
          color: 0xff1177aa,
          backgroundTone: 93,
          colorModel: ColorModel.oklch,
        ),
        _paletteCase(
          name: 'golden-dark-oklch',
          color: 0xffd29c57,
          backgroundTone: 10,
          colorModel: ColorModel.oklch,
        ),
      ],
      'paletteSweepCases': _paletteSweepCases(),
      'paletteWithBackgroundCases': [
        _paletteWithBackgroundCase(
          name: 'home-datetime-header-cyan-hover-regression',
          color: Hct.from(
            Hct.fromInt(0xffa2c6f0).hue,
            Hct.fromInt(0xffa2c6f0).chroma,
            100,
          ).color.argb,
          background: Hct.from(
            Hct.fromInt(0xffa2c6f0).hue,
            Hct.fromInt(0xffa2c6f0).chroma,
            Hct.fromInt(0xffa2c6f0).tone,
          ).color.argb,
        ),
      ],
      'lerpCases': [
        _lerpCase(
          name: 'red-blue-cartesian-mid',
          aColor: 0xffff0000,
          aBackgroundTone: 20,
          bColor: 0xff0000ff,
          bBackgroundTone: 80,
          t: 0.5,
          style: InterpolationStyle.cartesian,
        ),
        _lerpCase(
          name: 'red-blue-polar-mid',
          aColor: 0xffff0000,
          aBackgroundTone: 20,
          bColor: 0xff0000ff,
          bBackgroundTone: 80,
          t: 0.5,
          style: InterpolationStyle.polar,
        ),
        _lerpCase(
          name: 'endpoint-low-clamps',
          aColor: 0xff1565c0,
          aBackgroundTone: 12,
          bColor: 0xffffa000,
          bBackgroundTone: 94,
          t: -1,
          style: InterpolationStyle.cartesian,
        ),
        _lerpCase(
          name: 'endpoint-high-clamps',
          aColor: 0xff1565c0,
          aBackgroundTone: 12,
          bColor: 0xffffa000,
          bBackgroundTone: 94,
          t: 2,
          style: InterpolationStyle.polar,
        ),
      ],
      'themeCases': [
        _themeCase(
          name: 'brand-light-fromColor',
          color: 0xff1177aa,
          backgroundTone: 93,
          brightness: Brightness.light,
        ),
        _themeCase(
          name: 'brand-dark-fromColor',
          color: 0xff1177aa,
          backgroundTone: 10,
          brightness: Brightness.dark,
        ),
      ],
      'scorerCases': [
        _scorerCase(
          name: 'default-filters',
          argbToCount: const {
            0xff111111: 40,
            0xff777777: 30,
            0xffff0000: 25,
            0xff00ff00: 20,
            0xff0000ff: 15,
            0xffffffff: 10,
          },
        ),
        _scorerCase(
          name: 'no-chroma-filter',
          argbToCount: const {
            0xff111111: 40,
            0xff777777: 30,
            0xffff0000: 25,
            0xff00ff00: 20,
            0xff0000ff: 15,
            0xffffffff: 10,
          },
          minChroma: 0,
        ),
        _scorerCase(
          name: 'no-tone-or-chroma-filter',
          argbToCount: const {
            0xff111111: 40,
            0xff777777: 30,
            0xffff0000: 25,
            0xff00ff00: 20,
            0xff0000ff: 15,
            0xffffffff: 10,
          },
          toneTooLow: null,
          toneTooHigh: null,
          minChroma: 0,
        ),
      ],
      'triadCases': [_triadCase()],
      'wallpaperGoldenCases': _wallpaperGoldenCases(),
    };

    final file = File('js/fixtures/libmonet_parity.json');
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(fixture)}\n');
    print('wrote ${file.path}');
  });
}
