/// TrueType subsetter for PDF embedding: keeps the outlines of .notdef and
/// of the glyphs a document uses (with the components of composite glyphs)
/// and empties every other glyph, without renumbering, so that a
/// CIDFontType2 with CIDToGIDMap /Identity addresses the glyphs by their
/// original ids (ISO 32000-1, 9.7.4.2 and 9.9). Copies of glyphs can be
/// appended after the last glyph of the font: the PDF writer gives a glyph
/// that stands for different texts (a shared Arabic letter skeleton, the
/// first glyph of different Indic syllables) one id per text, so that the
/// ToUnicode CMap stays exact. The glyph count is cut after the highest
/// glyph used. Tables written: head, hhea, maxp, OS/2, hmtx, loca (long
/// format), glyf, a minimal cmap, name and post (format 3), laid out as the
/// OpenType specification describes them.
library;

import 'dart:typed_data';

import 'truetype.dart';

/// A subset font program.
class FontSubset {
  FontSubset._(this.bytes, this.glyphs);

  /// The TrueType file.
  final Uint8List bytes;

  /// Glyph ids with outlines in the subset (sorted; components included).
  final List<int> glyphs;

  /// Subsets [font] to [used] glyph ids (glyph 0 is always kept), followed
  /// by copies of the glyphs [copies] at ids `font.numGlyphs + i`.
  factory FontSubset.build(TrueTypeFont font, Iterable<int> used, {List<int> copies = const []}) {
    final keep = <int>{};
    final todo = <int>[0, ...used.where((g) => g >= 0 && g < font.numGlyphs), ...copies.where((g) => g >= 0 && g < font.numGlyphs)];
    while (todo.isNotEmpty) {
      final g = todo.removeLast();
      if (!keep.add(g)) continue;
      for (final c in font.components(g)) {
        if (c < font.numGlyphs && !keep.contains(c)) todo.add(c);
      }
    }
    final sorted = keep.toList()..sort();
    final n = copies.isEmpty ? sorted.last + 1 : font.numGlyphs + copies.length;
    final src = font.bytes;
    // original glyph of each id: itself, or the copied glyph past the end of the font
    int source(int g) => g < font.numGlyphs ? g : copies[g - font.numGlyphs];

    // glyf + loca: outlines of the kept glyphs, empty ranges for the others
    final glyf = BytesBuilder(copy: false);
    final loca = ByteData(4 * (n + 1));
    var off = 0;
    for (var g = 0; g < n; g++) {
      loca.setUint32(4 * g, off);
      if (g < font.numGlyphs && !keep.contains(g)) continue;
      final (a, b) = font.glyphRange(source(g));
      if (b <= a) continue;
      glyf.add(Uint8List.sublistView(src, a, b));
      off += b - a;
      final pad = (4 - off % 4) % 4;
      if (pad > 0) {
        glyf.add(Uint8List(pad));
        off += pad;
      }
    }
    loca.setUint32(4 * n, off);

    // hmtx: one long metric per glyph (zero for the emptied ones)
    final hmtx = ByteData(4 * n);
    var maxAdvance = 0;
    for (final g in [...sorted, for (var i = 0; i < copies.length; i++) font.numGlyphs + i]) {
      final adv = font.advanceWidth(source(g));
      if (adv > maxAdvance) maxAdvance = adv;
      hmtx.setUint16(4 * g, adv);
      hmtx.setInt16(4 * g + 2, font.leftSideBearing(source(g)));
    }

    Uint8List copyTable(String tag) {
      final t = font.tables[tag]!;
      return Uint8List.fromList(src.sublist(t.offset, t.offset + t.length));
    }

    final head = copyTable('head');
    ByteData.sublistView(head)
      ..setUint32(8, 0) // checkSumAdjustment, set below
      ..setInt16(50, 1); // indexToLocFormat: long offsets
    final hhea = copyTable('hhea');
    ByteData.sublistView(hhea)
      ..setUint16(10, maxAdvance)
      ..setUint16(34, n);
    final maxp = copyTable('maxp');
    ByteData.sublistView(maxp).setUint16(4, n);
    final post = Uint8List(32);
    final pd = ByteData.sublistView(post)..setUint32(0, 0x00030000);
    final srcPost = font.tables['post'];
    if (srcPost != null && srcPost.length >= 32) {
      final sp = ByteData.sublistView(src, srcPost.offset, srcPost.offset + 32);
      for (var k = 4; k < 32; k += 4) {
        pd.setUint32(k, sp.getUint32(k));
      }
    }
    // cmap: one empty format 4 subtable (glyphs are addressed by CID)
    final cmap = ByteData(36)
      ..setUint16(0, 0)
      ..setUint16(2, 1)
      ..setUint16(4, 3)
      ..setUint16(6, 1)
      ..setUint32(8, 12)
      ..setUint16(12, 4) // format
      ..setUint16(14, 24) // length
      ..setUint16(16, 0) // language
      ..setUint16(18, 2) // segCountX2
      ..setUint16(20, 2) // searchRange
      ..setUint16(22, 0) // entrySelector
      ..setUint16(24, 0) // rangeShift
      ..setUint16(26, 0xFFFF) // endCode
      ..setUint16(28, 0) // reservedPad
      ..setUint16(30, 0xFFFF) // startCode
      ..setInt16(32, 1) // idDelta
      ..setUint16(34, 0); // idRangeOffset

    final tables = <String, Uint8List>{
      'OS/2': ?(font.tables.containsKey('OS/2') ? copyTable('OS/2') : null),
      'cmap': cmap.buffer.asUint8List(),
      'glyf': glyf.takeBytes(),
      'head': head,
      'hhea': hhea,
      'hmtx': hmtx.buffer.asUint8List(),
      'loca': loca.buffer.asUint8List(),
      'maxp': maxp,
      'name': ?(font.tables.containsKey('name') ? copyTable('name') : null),
      'post': post,
    };
    final bytes = _assemble(tables);
    // checkSumAdjustment = 0xB1B0AFBA - checksum of the whole file
    final headOffset = _tableOffset(bytes, 'head');
    ByteData.sublistView(bytes).setUint32(headOffset + 8, (0xB1B0AFBA - _checksum(bytes)) & 0xFFFFFFFF);
    return FontSubset._(bytes, sorted);
  }

  static int _checksum(Uint8List b, [int start = 0, int? end]) {
    final e = end ?? b.length;
    var sum = 0;
    for (var i = start; i < e; i += 4) {
      final v = b[i] * 0x1000000 + (i + 1 < e ? b[i + 1] : 0) * 0x10000 + (i + 2 < e ? b[i + 2] : 0) * 0x100 + (i + 3 < e ? b[i + 3] : 0);
      sum = (sum + v) % 0x100000000;
    }
    return sum;
  }

  static int _tableOffset(Uint8List b, String tag) {
    final d = ByteData.sublistView(b);
    final n = d.getUint16(4);
    for (var i = 0; i < n; i++) {
      if (String.fromCharCodes(b, 12 + 16 * i, 16 + 16 * i) == tag) return d.getUint32(12 + 16 * i + 8);
    }
    return 0;
  }

  static Uint8List _assemble(Map<String, Uint8List> tables) {
    final tags = tables.keys.toList()..sort();
    final n = tags.length;
    var entrySelector = 0;
    while ((1 << (entrySelector + 1)) <= n) {
      entrySelector++;
    }
    final searchRange = 16 * (1 << entrySelector);
    final dirLen = 12 + 16 * n;
    var size = dirLen;
    for (final t in tags) {
      size += (tables[t]!.length + 3) & ~3;
    }
    final out = Uint8List(size);
    final d = ByteData.sublistView(out)
      ..setUint32(0, 0x00010000)
      ..setUint16(4, n)
      ..setUint16(6, searchRange)
      ..setUint16(8, entrySelector)
      ..setUint16(10, 16 * n - searchRange);
    var off = dirLen;
    for (var i = 0; i < n; i++) {
      final t = tables[tags[i]]!;
      out.setRange(off, off + t.length, t);
      final rec = 12 + 16 * i;
      for (var k = 0; k < 4; k++) {
        out[rec + k] = tags[i].codeUnitAt(k);
      }
      d
        ..setUint32(rec + 4, _checksum(out, off, off + t.length))
        ..setUint32(rec + 8, off)
        ..setUint32(rec + 12, t.length);
      off += (t.length + 3) & ~3;
    }
    return out;
  }
}
