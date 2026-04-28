import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/core/hex_codes.dart';
import 'package:libmonet/extract/extract.dart';
import 'package:libmonet/extract/quantizer_result.dart';
import 'package:libmonet/extract/scorer_triad.dart';

void main() {
  for (final fixture in _fixtures) {
    testWidgets('${fixture.name} ${fixture.maxColors} colors quantizer and '
        'CAM16 v1.1 triad are stable', (tester) async {
      await tester.runAsync(() async {
        final image = FileImage(File(fixture.path));
        final result = await Extract.quantize(image, fixture.maxColors);
        final triad = ScorerTriad.threeColorsFromQuantizer(
          result,
          colorModel: ColorModel.cam16v11,
        );

        expect(_quantizerFingerprint(result), fixture.quantizerFingerprint);
        expect(
          triad.map((hct) => hexFromColor(hct.color)).toList(),
          fixture.triadHexes,
        );
      });
    });
  }
}

const _fixtures = [
  _WallpaperFixture(
    name: 'aaron-burden-OA6OuqfSWew-unsplash.jpg',
    quantizerFingerprint:
        'colors=32 total=6912 top=#DA9677:410,#A1A36B:401,#A7965B:368,#C0A278:342,#B6AD7B:332,#908F50:331,#BB9762:330,#D6A287:320',
    triadHexes: ['#A6A26A', '#C0A278', '#C93916'],
  ),
  _WallpaperFixture(
    name: 'allec-gomes-cb2WKRZA9i8-unsplash.jpg',
    quantizerFingerprint:
        'colors=32 total=6144 top=#ED3303:639,#E40B03:484,#EB0A03:379,#DD1003:370,#522201:327,#461B01:304,#E36605:264,#351301:251',
    triadHexes: ['#EC3500', '#E52725', '#522201'],
  ),
  _WallpaperFixture(
    name: 'curated-lifestyle-7lQlYxH0Ljs-unsplash.jpg',
    quantizerFingerprint:
        'colors=32 total=6144 top=#CDCEC8:1110,#CACBC5:720,#12130D:462,#0E0F0A:444,#D1D2CC:421,#C7C8C2:357,#151610:323,#161811:272',
    triadHexes: ['#CDCEC8', '#CFCEC6', '#CCCECC'],
  ),
  _WallpaperFixture(
    name: 'hanna-lazar-CXT0TZcpyyE-unsplash.jpg',
    quantizerFingerprint:
        'colors=32 total=6144 top=#151218:558,#1A191D:403,#1A211A:278,#222025:267,#8E9E68:245,#A1B179:240,#2C581B:226,#306619:221',
    triadHexes: ['#859F72', '#C5D7BD', '#A1B179'],
  ),
  _WallpaperFixture(
    name: 'hans-isaacson-VrP25Libv-E-unsplash.jpg',
    quantizerFingerprint:
        'colors=32 total=6048 top=#638C8B:373,#3B6469:371,#5B8584:361,#426D71:359,#6B9390:338,#537E7D:321,#759A97:306,#457172:304',
    triadHexes: ['#628C8C', '#B7D3CB', '#C3DECD'],
  ),
  _WallpaperFixture(
    name: 'henrique-ferreira-lneox9o1MjU-unsplash.jpg',
    quantizerFingerprint:
        'colors=32 total=6144 top=#EDE7E3:1285,#F1E7DE:639,#E4E4E4:389,#9AA3AB:238,#D4D4D2:235,#BEBFBF:230,#F4E2D4:230,#ACAEB0:203',
    triadHexes: ['#F7CF99', '#E4AF9D', '#668593'],
  ),
  _WallpaperFixture(
    name: 'ingmar-E_PKxMtARbw-unsplash.jpg',
    quantizerFingerprint:
        'colors=32 total=6144 top=#D7BBDB:935,#D1B1DB:737,#CBABDA:495,#C5A2D8:442,#DCC4DD:430,#E0CCDE:396,#BF9BD6:387,#C8A6D7:378',
    triadHexes: ['#D6BBDB', '#4E3349', '#47272E'],
  ),
  _WallpaperFixture(
    name: 'ingmar-_KZW2oCkRIQ-unsplash.jpg',
    quantizerFingerprint:
        'colors=32 total=6816 top=#FD964C:2111,#FD9A48:944,#FD994B:569,#FC9845:513,#FD924C:440,#F8963C:297,#FB6346:159,#FA5E41:154',
    triadHexes: ['#FD964C', '#F9B964', '#FB6346'],
  ),
  _WallpaperFixture(
    name: 'lorin-both-2ScC2nkYYDk-unsplash.jpg',
    quantizerFingerprint:
        'colors=32 total=7104 top=#B032ED:708,#A41DE3:618,#6C039D:495,#A926E9:468,#7403A9:458,#9C16DB:458,#BA44F3:445,#B63BF2:427',
    triadHexes: ['#AA38F0', '#A849CA', '#51682C'],
  ),
  _WallpaperFixture(
    name: 'lorin-both-C7X5ijG_-uM-unsplash.jpg',
    quantizerFingerprint:
        'colors=32 total=6144 top=#F5C51F:735,#F1BC1C:571,#D78C0A:537,#DC930D:490,#CA7100:464,#E29F12:444,#ECB41A:439,#E9AC17:350',
    triadHexes: ['#FDC12E', '#CA7101', '#426103'],
  ),
  _WallpaperFixture(
    name: 'nick-fancher-BDr0sOaODXc-unsplash.jpg',
    quantizerFingerprint:
        'colors=32 total=6144 top=#02050C:771,#01219B:382,#020C1B:321,#020E29:303,#010F36:298,#011457:298,#0237CC:296,#011E8F:276',
    triadHexes: ['#002C83', '#015997', '#299DD4'],
  ),
  _WallpaperFixture(
    name: 'solen-feyissa-u-VOCC2yg9s-unsplash.jpg',
    quantizerFingerprint:
        'colors=32 total=6144 top=#FA8203:539,#FA8E03:474,#FB7603:451,#FA6803:392,#BE0201:360,#970201:351,#FB9B03:316,#8B0202:293',
    triadHexes: ['#BD0B00', '#FA6800', '#FA8E06'],
  ),
  _WallpaperFixture(
    name: 'zhenyu-luo-0MM2JsXz2aI-unsplash.jpg',
    quantizerFingerprint:
        'colors=32 total=6144 top=#021C32:708,#062738:520,#052942:513,#020D15:481,#0A3549:481,#031523:461,#13445A:406,#0C3A56:362',
    triadHexes: ['#092738', '#764037', '#F7DCC8'],
  ),
  _WallpaperFixture(
    name: 'aaron-burden-OA6OuqfSWew-unsplash.jpg',
    maxColors: 256,
    quantizerFingerprint:
        'colors=256 total=6912 top=#ADAD7B:81,#AAAD73:77,#DEB198:76,#DC9D7A:65,#D29173:65,#A5A471:64,#CF9578:62,#D4A179:61',
    triadHexes: ['#ADAD7B', '#3D5C48', '#DFB09A'],
  ),
  _WallpaperFixture(
    name: 'curated-lifestyle-7lQlYxH0Ljs-unsplash.jpg',
    maxColors: 256,
    quantizerFingerprint:
        'colors=248 total=6144 top=#CCCDC7:555,#CBCCC6:456,#CECFC9:434,#12130E:291,#D0D1CB:255,#0F110B:213,#C9CAC4:179,#C8C9C3:126',
    triadHexes: ['#CCCDC7', '#CECDC5', '#CBCDCB'],
  ),
  _WallpaperFixture(
    name: 'lorin-both-2ScC2nkYYDk-unsplash.jpg',
    maxColors: 256,
    quantizerFingerprint:
        'colors=256 total=7104 top=#B740F3:263,#A31CE2:229,#AD2FEB:221,#AB27EA:219,#7202A6:219,#A61FE5:215,#69029A:213,#B236F0:209',
    triadHexes: ['#B83FF2', '#302E05', '#303F17'],
  ),
  _WallpaperFixture(
    name: 'zhenyu-luo-0MM2JsXz2aI-unsplash.jpg',
    maxColors: 256,
    quantizerFingerprint:
        'colors=256 total=6144 top=#000B10:157,#010D16:155,#021D32:143,#011321:139,#022134:125,#011B2D:124,#05283A:116,#011C34:115',
    triadHexes: ['#002134', '#4B8582', '#D39A8C'],
  ),
];

class _WallpaperFixture {
  const _WallpaperFixture({
    required this.name,
    this.maxColors = 32,
    required this.quantizerFingerprint,
    required this.triadHexes,
  });

  final String name;
  final int maxColors;
  final String quantizerFingerprint;
  final List<String> triadHexes;

  String get path => 'test/fixtures/wallpapers/$name';
}

String _quantizerFingerprint(QuantizerResult result) {
  final entries = result.argbToCount.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final total = entries.fold<int>(0, (sum, entry) => sum + entry.value);
  final top = entries
      .take(8)
      .map((entry) {
        return '${hexFromArgb(entry.key)}:${entry.value}';
      })
      .join(',');
  return 'colors=${entries.length} total=$total top=$top';
}
