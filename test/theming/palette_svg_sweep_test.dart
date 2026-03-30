// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui';

import 'package:libmonet/colorspaces/hct.dart';
import 'package:libmonet/core/hex_codes.dart';
import 'package:libmonet/theming/palette.dart';
import 'package:test/test.dart';

/// Brand colors from example/lib/brand_colors.dart, LLM providers, + black & white.
const _colors = <String, Color>{
  'Black': Color(0xff000000),
  'White': Color(0xffffffff),
  'Starbucks': Color(0xff006241),
  'Coca-Cola': Color(0xfff40009),
  "McDonald's": Color(0xffffc72c),
  'Tiffany': Color(0xff0abab5),
  'Facebook': Color(0xff4267b2),
  'Google': Color(0xff4285f4),
  'Deere': Color(0xff367c2b),
  'Cadbury': Color(0xff482683),
  'Barbie': Color(0xffe0218a),
  'Telosnex': Color(0xff0066AA),
  // LLM providers (skipping dupes: Black, Google)
  'Anthropic': Color(0xFFA9532E),
  'Mistral': Color(0xFFFA500F),
  'Groq': Color(0xff192830),
  'Perplexity': Color(0xFF20808D),
  'Moonshot': Color(0xff444444),
  'Inception': Color(0xFF004298),
  'Fireworks': Color(0xFFFF6B35),
  'xAI': Color(0xff1F1F1F),
};

const _bgTones = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100];

void main() {
  test(
    'generate colorBorder SVG grid',
    skip: 'visual harness — run manually',
    () {
      const contrast = 0.499;

      const cellW = 140;
      const cellH = 90;
      const labelColW = 80;
      const headerRowH = 40;
      const borderWidth = 3;
      const rectW = 90;
      const rectH = 54;

      final cols = _colors.length;
      final rows = _bgTones.length;
      final svgW = labelColW + cols * cellW;
      final svgH = headerRowH + rows * cellH;

      final sb = StringBuffer();
      sb.writeln(
          '<svg xmlns="http://www.w3.org/2000/svg" width="$svgW" height="$svgH"'
          ' font-family="system-ui, sans-serif" font-size="11">');

      // White background for the whole SVG
      sb.writeln(
          '<rect width="$svgW" height="$svgH" fill="white"/>');

      // Column headers (color names)
      final colorEntries = _colors.entries.toList();
      for (var c = 0; c < cols; c++) {
        final x = labelColW + c * cellW + cellW / 2;
        sb.writeln(
            '<text x="$x" y="${headerRowH - 8}" text-anchor="middle"'
            ' font-size="10" fill="#333">${colorEntries[c].key}</text>');
        // Show hex underneath the name
        final hex = hexFromColor(colorEntries[c].value);
        sb.writeln(
            '<text x="$x" y="${headerRowH - 0}" text-anchor="middle"'
            ' font-size="8" fill="#999">$hex</text>');
      }

      // Row headers (bg tones) + cells
      for (var r = 0; r < rows; r++) {
        final bgTone = _bgTones[r].toDouble();
        final y = headerRowH + r * cellH;

        // Row label
        sb.writeln(
            '<text x="${labelColW - 8}" y="${y + cellH / 2 + 4}"'
            ' text-anchor="end" font-size="11" fill="#333">T$bgTone</text>');

        for (var c = 0; c < cols; c++) {
          final color = colorEntries[c].value;
          final x = labelColW + c * cellW;

          final p = Palette.from(color,
              backgroundTone: bgTone, contrast: contrast);

          final bgHex = hexFromColor(p.background);
          final colorHex = hexFromColor(p.color);
          final borderHex = hexFromColor(p.colorBorder);

          final textHex = hexFromColor(p.colorText);
          final colorTone = Hct.fromColor(p.color).tone;
          final borderTone = Hct.fromColor(p.colorBorder).tone;

          // Background fill
          sb.writeln(
              '<rect x="$x" y="$y" width="$cellW" height="$cellH"'
              ' fill="$bgHex"/>');

          // Colored rectangle with border
          final rx = x + (cellW - rectW) / 2;
          final ry = y + (cellH - rectH) / 2 - 4;
          sb.writeln(
              '<rect x="$rx" y="$ry" width="$rectW" height="$rectH"'
              ' rx="6" fill="$colorHex"'
              ' stroke="$borderHex" stroke-width="$borderWidth"/>');

          // Text sample on the colored surface
          sb.writeln(
              '<text x="${rx + rectW / 2}" y="${ry + rectH / 2 + 5}"'
              ' text-anchor="middle" font-size="14" font-weight="bold"'
              ' fill="$textHex">Aa</text>');

          // Tone label below the rectangle
          final labelY = ry + rectH + 11;
          sb.writeln(
              '<text x="${x + cellW / 2}" y="$labelY" text-anchor="middle"'
              ' font-size="8" fill="${bgTone > 50 ? '#333' : '#ccc'}">'
              'c${colorTone.toStringAsFixed(0)}'
              ' b${borderTone.toStringAsFixed(0)}'
              '</text>');
        }
      }

      sb.writeln('</svg>');

      final outFile = File('test/theming/palette_border_visual.svg');
      outFile.writeAsStringSync(sb.toString());
      print('Wrote ${outFile.path}');
    },
  );
}
