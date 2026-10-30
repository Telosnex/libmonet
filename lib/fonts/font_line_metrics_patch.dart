import 'dart:typed_data';

import 'package:monet_ui/fonts/line_height.dart';

/// [bytes] with the ascent and descent centred on the font's Latin ink.
///
/// Flutter places the baseline at the font's ascent, so a font with spare
/// room for another script sits off-centre when TextStyle.height shrinks its
/// line: the cut is split evenly, but the spare room is not. This is the
/// equivalent of CSS `ascent-override` and `descent-override`.
///
/// The new line box is [lineHeightForFontFamily] at [clearance], centred on
/// the ink: half the space above the highest letter, half below the lowest.
/// Text with no TextStyle.height gets that line height. A different
/// TextStyle.height keeps the letters centred, with even leading.
///
/// Rewrites hhea (ascender, descender, lineGap), and OS/2 (typo and win
/// metrics), so every platform reads the same values. Recomputes the
/// checksums. Returns [bytes] if the font has no Latin ink data, or is not a
/// TrueType or OpenType file.
ByteData patchFontLineMetrics(
  ByteData bytes,
  String fontFamily, {
  double clearance = kLineHeightClearance,
}) {
  final ink = latinInkForFontFamily(fontFamily);
  final height = lineHeightForFontFamily(fontFamily, clearance: clearance);
  if (ink == null || height == null) return bytes;
  final pad = (height - ink.$1 - ink.$2) / 2;
  return patchFontAscentDescent(bytes, ink.$1 + pad, ink.$2 + pad);
}

/// [bytes] with the ascent and descent [ascentEm] and [descentEm], in em,
/// and no line gap. Returns [bytes] if it is not a TrueType or OpenType file
/// with head and hhea tables.
ByteData patchFontAscentDescent(
  ByteData bytes,
  double ascentEm,
  double descentEm,
) {
  if (bytes.lengthInBytes < 12) return bytes;
  final version = bytes.getUint32(0);
  // 1.0 (TrueType), 'OTTO' (CFF), 'true' (Apple TrueType).
  if (version != 0x00010000 && version != 0x4F54544F && version != 0x74727565) {
    return bytes;
  }
  final out = ByteData(bytes.lengthInBytes)
    ..buffer.asUint8List().setAll(
      0,
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  final numTables = out.getUint16(4);
  final records = <String, int>{}; // tag -> record offset
  for (var i = 0; i < numTables; i++) {
    final record = 12 + 16 * i;
    if (record + 16 > out.lengthInBytes) return bytes;
    records[String.fromCharCodes(out.buffer.asUint8List(record, 4))] = record;
  }
  int offsetOf(String tag) => out.getUint32(records[tag]! + 8);
  int lengthOf(String tag) => out.getUint32(records[tag]! + 12);
  if (!records.containsKey('head') ||
      !records.containsKey('hhea') ||
      lengthOf('head') < 54 ||
      lengthOf('hhea') < 36) {
    return bytes;
  }
  final head = offsetOf('head');
  final unitsPerEm = out.getUint16(head + 18);
  // Ceil, so that the box never cuts the ink.
  final ascent = (ascentEm * unitsPerEm).ceil().clamp(0, 0x7fff);
  final descent = (descentEm * unitsPerEm).ceil().clamp(0, 0x7fff);

  final hhea = offsetOf('hhea');
  out
    ..setInt16(hhea + 4, ascent)
    ..setInt16(hhea + 6, -descent)
    ..setInt16(hhea + 8, 0);
  if (records.containsKey('OS/2') && lengthOf('OS/2') >= 78) {
    final os2 = offsetOf('OS/2');
    out
      ..setInt16(os2 + 68, ascent)
      ..setInt16(os2 + 70, -descent)
      ..setInt16(os2 + 72, 0)
      ..setUint16(os2 + 74, ascent)
      ..setUint16(os2 + 76, descent);
  }

  int checksum(int offset, int length) {
    var sum = 0;
    final end = offset + length;
    for (var i = offset; i < end; i += 4) {
      var word = 0;
      for (var b = 0; b < 4; b++) {
        word = (word << 8) | (i + b < end ? out.getUint8(i + b) : 0);
      }
      sum = (sum + word) & 0xffffffff;
    }
    return sum;
  }

  out.setUint32(head + 8, 0);
  for (final tag in records.keys) {
    if (tag == 'head' || tag == 'hhea' || tag == 'OS/2') {
      out.setUint32(records[tag]! + 4, checksum(offsetOf(tag), lengthOf(tag)));
    }
  }
  final total = checksum(0, out.lengthInBytes);
  out.setUint32(head + 8, (0xB1B0AFBA - total) & 0xffffffff);
  return out;
}
