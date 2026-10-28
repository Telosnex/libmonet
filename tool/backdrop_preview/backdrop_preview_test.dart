// Preview of AnyBackground.sharedBorder: chips over real wallpapers and
// flat backgrounds, today's per-chip colorBorder vs one shared border.
//
// Writes build/backdrop_preview/index.html. Run:
//   WALLPAPER_DIR=~/dev/monet_gdt/data/images/megalith \
//   flutter test tool/backdrop_preview/backdrop_preview_test.dart
//
// Env: WALLPAPER_DIR (jpg/png/webp; optional), SAMPLE (images rendered from
// it, default 24), EXTRA (comma-separated image paths, always rendered).

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/libmonet.dart';

const _contrast = 0.5;
// 96px wide, as Extract downscales.
const _sampleWidth = 96;
final _sample = int.tryParse(Platform.environment['SAMPLE'] ?? '') ?? 24;

/// One stage: something behind three chips.
typedef _Stage = ({
  String title,
  String css,
  List<int> pixels,
  List<Palette> palettes,
});

void main() {
  testWidgets('backdrop preview', (tester) async {
    await tester.runAsync(() async {
      final stages = <_Stage>[
        ..._flatStages(),
        for (final f in _imageFiles()) await _imageStage(f),
      ];
      final body = stages.map(_section).join('\n');
      final out = File('build/backdrop_preview/index.html')
        ..createSync(recursive: true)
        ..writeAsStringSync(_page(body));
      print('Rendered ${stages.length}. Wrote ${out.absolute.path}');
    });
  }, timeout: const Timeout(Duration(minutes: 30)));
}

List<File> _imageFiles() {
  final env = Platform.environment;
  final files = <File>[
    for (final p in (env['EXTRA'] ?? '').split(','))
      if (p.isNotEmpty) File(p),
  ];
  final dir = env['WALLPAPER_DIR'];
  if (dir != null) {
    final all =
        Directory(dir)
            .listSync()
            .whereType<File>()
            .where((f) => RegExp(r'\.(jpe?g|png|webp)$').hasMatch(f.path))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path))
          ..shuffle(math.Random(1));
    files.addAll(all.take(_sample));
  }
  return files;
}

/// Flat backgrounds: where the background check matters most, and what a
/// photo set never covers.
List<_Stage> _flatStages() {
  const chipSets = {
    'dark chips': [0xff1a3a6a, 0xff3a1a4a, 0xff1f3f2a],
    'mid chips': [0xff4477aa, 0xffaa4444, 0xff44aa66],
    'light chips': [0xffb0d0f0, 0xfff0c0b0, 0xffc8e8c0],
  };
  final gray20 = argbFromLstar(20), gray35 = argbFromLstar(35);
  final backgrounds = <String, (String, List<int>)>{
    'solid #ff0000': ('#ff0000', [0xffff0000]),
    'solid #1e1e1e': ('#1e1e1e', [0xff1e1e1e]),
    'solid #f4f4f4': ('#f4f4f4', [0xfff4f4f4]),
    'gradient T20–T35': (
      'linear-gradient(90deg, ${_cssArgb(gray20)}, ${_cssArgb(gray35)})',
      [for (var l = 20; l <= 35; l++) argbFromLstar(l.toDouble())],
    ),
  };
  return [
    for (final bg in backgrounds.entries)
      for (final chips in chipSets.entries)
        (
          title: '${bg.key} · ${chips.key}',
          css: bg.value.$1,
          pixels: bg.value.$2,
          palettes: [
            for (final c in chips.value)
              Palette.from(
                ui.Color(c),
                backgroundTone: _meanTone(bg.value.$2),
                contrast: _contrast,
              ),
          ],
        ),
  ];
}

Future<_Stage> _imageStage(File file) async {
  final codec = await ui.instantiateImageCodec(
    file.readAsBytesSync(),
    targetWidth: _sampleWidth,
  );
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final rgba = data!.buffer.asUint8List();
  final pixels = [
    for (var i = 0; i + 3 < rgba.length; i += 4)
      if (rgba[i + 3] == 255)
        0xff000000 | (rgba[i] << 16) | (rgba[i + 1] << 8) | rgba[i + 2],
  ];
  final quantized = await QuantizerCelebi().quantize(pixels, 32);
  final tone = _meanTone(pixels);
  return (
    title: file.uri.pathSegments.last,
    css: "url('${file.absolute.uri}') center / cover",
    pixels: pixels,
    palettes: [
      for (final h in ScorerTriad.threeColorsFromQuantizer(quantized))
        Palette.from(h.color, backgroundTone: tone, contrast: _contrast),
    ],
  );
}

String _section(_Stage s) {
  final border = AnyBackground(
    s.pixels,
    algo: Algo.apca,
    contrast: _contrast,
  ).sharedBorder([for (final p in s.palettes) p.color.argb]);
  const names = ['primary', 'secondary', 'tertiary'];
  String row(String label, List<ui.Color> borders) =>
      '<div class="row"><span class="tag">$label</span>'
      '${[for (var i = 0; i < 3; i++) _chip(names[i], s.palettes[i], borders[i])].join()}'
      '</div>';
  final today = row('today', [for (final p in s.palettes) p.colorBorder]);
  final shared = row('sharedBorder', [
    for (var i = 0; i < 3; i++) border.colorAt(i),
  ]);
  final how = border.clearsBackground
      ? 'clears the background'
      : 'clears each chip (background too varied)';
  return '''
<section>
  <h2>${const HtmlEscape().convert(s.title)}</h2>
  <p class="meta">sharedBorder T${border.tone.round()}: $how${border.meetsTarget ? '' : ' · <b>misses target</b>'}</p>
  <div class="stage" style="background:${s.css}">$today$shared$today$shared</div>
</section>''';
}

String _chip(String name, Palette p, ui.Color border) {
  final visible = border != p.color;
  return '<div class="chip" style="background:${_css(p.color)};'
      'color:${_css(p.colorText)};border-color:${_css(border)}" '
      'title="$name ${_css(p.color)} / border ${_css(border)}">'
      '$name<small>T${_tone(p.color)} | '
      '${visible ? 'T${_tone(border)}' : '=color'}</small></div>';
}

double _meanTone(List<int> argbs) =>
    argbs.map(lstarFromArgb).reduce((a, b) => a + b) / argbs.length;

String _css(ui.Color c) => _cssArgb(c.argb);
String _cssArgb(int argb) =>
    '#${(argb & 0xffffff).toRadixString(16).padLeft(6, '0')}';
String _tone(ui.Color c) => lstarFromArgb(c.argb).round().toString();

String _page(String body) =>
    '''
<!doctype html>
<html><head><meta charset="utf-8"><title>sharedBorder preview</title>
<style>
  body { font: 13px -apple-system, sans-serif; background:#222; color:#eee;
         margin:24px; }
  section { margin-bottom:32px; }
  h2 { font-size:15px; margin:0 0 4px; }
  .meta { margin:0 0 8px; color:#bbb; }
  .stage { padding:16px; display:flex; flex-direction:column; gap:24px;
           border-radius:8px; }
  .row { display:flex; align-items:center; gap:12px; }
  .tag { width:96px; font-size:11px; color:#fff; text-shadow:0 0 3px #000; }
  .chip { box-sizing:border-box; height:36px; padding:0 14px;
          border:2px solid; border-radius:18px; display:flex;
          align-items:center; gap:8px; font-weight:600; }
  .chip small { font-weight:400; opacity:.75; }
</style></head>
<body>
<h1>sharedBorder preview</h1>
<p>Chips: palette <code>color</code> with a 2px border. <b>today</b>: each
chip's own <code>colorBorder</code>. <b>sharedBorder</b>:
<code>AnyBackground(pixels).sharedBorder(chip colors)</code>, one tone for
all three, each in its chip's hue. Labels: chip tone | border tone
("=color" means no visible border). Flat backgrounds first; photos rarely
let the background decide.</p>
$body
</body></html>
''';
