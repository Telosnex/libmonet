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
    testWidgets('${fixture.name} quantizer and CAM16 v1.1 triad are stable',
        (tester) async {
      await tester.runAsync(() async {
        final image = FileImage(File(fixture.path));
        final result = await Extract.quantize(image, 32);
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
        'colors=32 total=6912 top=#D19977:509,#A8A779:501,#A29F68:409,#BB9A65:390,#909052:367,#5D703C:309,#BAB591:303,#C0895E:286',
    triadHexes: ['#ACA678', '#355329', '#D09A76'],
  ),
  _WallpaperFixture(
    name: 'allec-gomes-cb2WKRZA9i8-unsplash.jpg',
    quantizerFingerprint:
        'colors=32 total=6144 top=#E50B03:782,#ED3303:521,#491D01:404,#E22403:351,#371401:262,#B61802:249,#CB2002:248,#DD3104:238',
    triadHexes: ['#D63500', '#E15802', '#E37105'],
  ),
  _WallpaperFixture(
    name: 'curated-lifestyle-7lQlYxH0Ljs-unsplash.jpg',
    quantizerFingerprint:
        'colors=32 total=6144 top=#CECFC9:813,#CBCBC5:787,#CACBC5:590,#0C0D08:531,#D1D2CC:437,#151710:319,#13140E:259,#0F100B:256',
    triadHexes: ['#CECFC9', '#D0CFC7', '#CDCFCD'],
  ),
  _WallpaperFixture(
    name: 'hanna-lazar-CXT0TZcpyyE-unsplash.jpg',
    quantizerFingerprint:
        'colors=32 total=6144 top=#18161A:921,#2B561B:315,#8FA369:302,#608148:284,#21331C:266,#31671A:244,#478329:241,#9FAF78:220',
    triadHexes: ['#2D5618', '#C6D8BE', '#9FAF78'],
  ),
  _WallpaperFixture(
    name: 'hans-isaacson-VrP25Libv-E-unsplash.jpg',
    quantizerFingerprint:
        'colors=32 total=6048 top=#6A9290:592,#4F7B7A:568,#5A8483:508,#436D70:400,#3B6569:393,#779B99:342,#467273:301,#628987:294',
    triadHexes: ['#689293', '#AECBC4', '#C4DECF'],
  ),
  _WallpaperFixture(
    name: 'henrique-ferreira-lneox9o1MjU-unsplash.jpg',
    quantizerFingerprint:
        'colors=32 total=6144 top=#EDE7E3:1056,#F1E7DF:723,#E7E4E3:579,#C2C5C6:408,#A0ACB4:325,#8797A3:261,#A8A1A2:247,#B3BABD:207',
    triadHexes: ['#F9DEB9', '#E6B09D', '#668290'],
  ),
  _WallpaperFixture(
    name: 'ingmar-E_PKxMtARbw-unsplash.jpg',
    quantizerFingerprint:
        'colors=32 total=6144 top=#D2B3DB:815,#D7BBDB:776,#C9A6D8:475,#CCACD9:467,#DFCBDE:457,#C4A2D8:399,#DCC4DD:371,#BF9AD4:335',
    triadHexes: ['#D2B3DB', '#76466B', '#47272F'],
  ),
  _WallpaperFixture(
    name: 'ingmar-_KZW2oCkRIQ-unsplash.jpg',
    quantizerFingerprint:
        'colors=32 total=6816 top=#FD964C:1993,#FD9949:877,#FD924C:537,#FC9845:502,#FC9947:451,#F85A3D:233,#F8963C:216,#FA9849:208',
    triadHexes: ['#FD964C', '#F9BA65', '#F85A3D'],
  ),
  _WallpaperFixture(
    name: 'lorin-both-2ScC2nkYYDk-unsplash.jpg',
    quantizerFingerprint:
        'colors=32 total=7104 top=#A927E8:814,#7203A5:718,#B840F2:667,#9C16DC:582,#A520E5:514,#B033EE:417,#890AC6:412,#7C05B5:401',
    triadHexes: ['#A42DEA', '#A344C5', '#374A18'],
  ),
  _WallpaperFixture(
    name: 'lorin-both-C7X5ijG_-uM-unsplash.jpg',
    quantizerFingerprint:
        'colors=32 total=6144 top=#E19E12:830,#F5C51F:774,#F1BC1C:528,#CB7200:524,#DC930D:474,#D38105:467,#ECB219:435,#CF7B02:396',
    triadHexes: ['#DF9F0A', '#CB7202', '#456202'],
  ),
  _WallpaperFixture(
    name: 'nick-fancher-BDr0sOaODXc-unsplash.jpg',
    quantizerFingerprint:
        'colors=32 total=6144 top=#02060E:851,#022EB6:448,#011768:413,#021E88:406,#001247:395,#020F2A:346,#01219B:295,#0236CB:254',
    triadHexes: ['#00389F', '#0E70A1', '#13B7E4'],
  ),
  _WallpaperFixture(
    name: 'solen-feyissa-u-VOCC2yg9s-unsplash.jpg',
    quantizerFingerprint:
        'colors=32 total=6144 top=#FB8D03:592,#FA8103:545,#BF0301:537,#950202:533,#FA6903:526,#FB9D03:323,#A60301:319,#D50201:286',
    triadHexes: ['#BF0203', '#FA6903', '#FB8D00'],
  ),
  _WallpaperFixture(
    name: 'zhenyu-luo-0MM2JsXz2aI-unsplash.jpg',
    quantizerFingerprint:
        'colors=32 total=6144 top=#031C30:960,#0B3345:767,#052841:691,#020F17:584,#1A4D5E:491,#0E3D58:479,#276579:326,#031624:218',
    triadHexes: ['#073344', '#052841', '#6E3F36'],
  ),
];

class _WallpaperFixture {
  const _WallpaperFixture({
    required this.name,
    required this.quantizerFingerprint,
    required this.triadHexes,
  });

  final String name;
  final String quantizerFingerprint;
  final List<String> triadHexes;

  String get path => 'test/fixtures/wallpapers/$name';
}

String _quantizerFingerprint(QuantizerResult result) {
  final entries = result.argbToCount.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final total = entries.fold<int>(0, (sum, entry) => sum + entry.value);
  final top = entries.take(8).map((entry) {
    return '${hexFromArgb(entry.key)}:${entry.value}';
  }).join(',');
  return 'colors=${entries.length} total=$total top=$top';
}
