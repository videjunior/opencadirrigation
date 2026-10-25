/// TrueType font file reader (pure Dart): the tables the PDF writer embeds
/// and the shaper reads. Follows the OpenType specification 1.9 (ISO/IEC
/// 14496-22), chapters "cmap" (formats 4 and 12), "head", "hhea", "hmtx",
/// "maxp", "loca", "glyf", "post", "OS/2" and "name". Only fonts with
/// TrueType outlines (glyf) are supported, which is what PDF embeds as
/// FontFile2 (ISO 32000-1, 9.9).
library;

import 'dart:convert';
import 'dart:typed_data';

/// Thrown for files that are not TrueType fonts or are truncated.
class FontFormatException implements Exception {
  const FontFormatException(this.message);
  final String message;
  @override
  String toString() => 'FontFormatException: $message';
}

/// Offset and length of a table in the font file.
class FontTable {
  const FontTable(this.offset, this.length);
  final int offset;
  final int length;
}

/// A parsed TrueType font.
class TrueTypeFont {
  TrueTypeFont._(this.bytes, this.data, this.tables);

  /// Parses [bytes] (a TrueType/OpenType file with glyf outlines).
  factory TrueTypeFont.parse(Uint8List bytes) {
    if (bytes.length < 12) throw const FontFormatException('file too short');
    final data = ByteData.sublistView(bytes);
    final version = data.getUint32(0);
    if (version != 0x00010000 && version != 0x74727565 /* 'true' */) {
      throw FontFormatException(version == 0x4F54544F ? 'CFF outlines are not supported' : 'not a TrueType font');
    }
    final numTables = data.getUint16(4);
    if (12 + numTables * 16 > bytes.length) throw const FontFormatException('truncated table directory');
    final tables = <String, FontTable>{};
    for (var i = 0; i < numTables; i++) {
      final rec = 12 + i * 16;
      final tag = String.fromCharCodes(bytes, rec, rec + 4);
      final offset = data.getUint32(rec + 8), length = data.getUint32(rec + 12);
      if (offset + length > bytes.length) throw FontFormatException('table $tag outside the file');
      tables[tag] = FontTable(offset, length);
    }
    for (final t in const ['head', 'hhea', 'hmtx', 'maxp', 'cmap', 'loca', 'glyf']) {
      if (!tables.containsKey(t)) throw FontFormatException('missing $t table');
    }
    final f = TrueTypeFont._(bytes, data, tables);
    f._parseMetrics();
    return f;
  }

  final Uint8List bytes;
  final ByteData data;
  final Map<String, FontTable> tables;

  late final int unitsPerEm;
  late final int numGlyphs;
  late final int indexToLocFormat;
  late final int numberOfHMetrics;

  /// Font bounding box (head), font units.
  late final int xMin, yMin, xMax, yMax;

  /// Typographic ascender and descender (OS/2 when present, else hhea).
  late final int ascender, descender;
  late final int capHeight;
  late final int weightClass;

  /// Italic angle in degrees (post).
  late final double italicAngle;
  late final bool fixedPitch;

  /// PostScript name (name id 6), or a name derived from the family.
  late final String postScriptName;

  Map<int, int>? _cmap;

  int _u16(int o) => data.getUint16(o);
  int _i16(int o) => data.getInt16(o);
  int _u32(int o) => data.getUint32(o);

  void _parseMetrics() {
    final head = tables['head']!.offset;
    unitsPerEm = _u16(head + 18);
    xMin = _i16(head + 36);
    yMin = _i16(head + 38);
    xMax = _i16(head + 40);
    yMax = _i16(head + 42);
    indexToLocFormat = _i16(head + 50);
    numGlyphs = _u16(tables['maxp']!.offset + 4);
    final hhea = tables['hhea']!.offset;
    numberOfHMetrics = _u16(hhea + 34);
    var asc = _i16(hhea + 4), desc = _i16(hhea + 6);
    var cap = 0, weight = 400;
    final os2 = tables['OS/2'];
    if (os2 != null && os2.length >= 78) {
      weight = _u16(os2.offset + 4);
      asc = _i16(os2.offset + 68);
      desc = _i16(os2.offset + 70);
      if (_u16(os2.offset) >= 2 && os2.length >= 90) cap = _i16(os2.offset + 88);
    }
    ascender = asc;
    descender = desc;
    capHeight = cap > 0 ? cap : (asc * 0.7).round();
    weightClass = weight;
    final post = tables['post'];
    if (post != null && post.length >= 16) {
      italicAngle = data.getInt32(post.offset + 4) / 65536;
      fixedPitch = _u32(post.offset + 12) != 0;
    } else {
      italicAngle = 0;
      fixedPitch = false;
    }
    postScriptName = _nameString(6) ?? (_nameString(4) ?? 'Font').replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '');
  }

  /// A string of the name table (platform 3 or 0, UTF-16; or platform 1, encoding 0), or null.
  String? _nameString(int nameId) {
    final t = tables['name'];
    if (t == null || t.length < 6) return null;
    final o = t.offset;
    final count = _u16(o + 2), strings = o + _u16(o + 4);
    String? mac;
    for (var i = 0; i < count; i++) {
      final r = o + 6 + i * 12;
      if (r + 12 > o + t.length) break;
      if (_u16(r + 6) != nameId) continue;
      final platform = _u16(r), encoding = _u16(r + 2), len = _u16(r + 8), off = strings + _u16(r + 10);
      if (off + len > bytes.length) continue;
      if (platform == 3 && (encoding == 1 || encoding == 10) || platform == 0) {
        final units = <int>[for (var k = 0; k + 1 < len; k += 2) _u16(off + k)];
        return String.fromCharCodes(units);
      }
      if (platform == 1 && encoding == 0) mac = latin1.decode(bytes.sublist(off, off + len));
    }
    return mac;
  }

  /// Glyph id of the character [cp], or 0 (.notdef) when the font lacks it.
  int glyphId(int cp) => (_cmap ??= _parseCmap())[cp] ?? 0;

  /// Whether the font maps [cp] to a glyph.
  bool hasGlyph(int cp) => glyphId(cp) != 0;

  /// Every character the font maps.
  Iterable<int> get characters => (_cmap ??= _parseCmap()).keys;

  Map<int, int> _parseCmap() {
    final t = tables['cmap']!;
    final o = t.offset;
    final count = _u16(o + 2);
    int? best, bestScore;
    for (var i = 0; i < count; i++) {
      final r = o + 4 + i * 8;
      final platform = _u16(r), encoding = _u16(r + 2), sub = o + _u32(r + 4);
      if (sub + 2 > bytes.length) continue;
      final format = _u16(sub);
      final score = switch ((platform, encoding, format)) {
        (3, 10, 12) => 5,
        (0, 4 || 6, 12) => 4,
        (3, 1, 4) => 3,
        (0, _, 4) => 2,
        (3, 0, 4) => 1, // symbol fonts
        _ => 0,
      };
      if (score > 0 && (bestScore == null || score > bestScore)) {
        best = sub;
        bestScore = score;
      }
    }
    final map = <int, int>{};
    if (best == null) return map;
    if (_u16(best) == 12) {
      final groups = _u32(best + 12);
      for (var i = 0; i < groups; i++) {
        final g = best + 16 + i * 12;
        final start = _u32(g), end = _u32(g + 4), gid = _u32(g + 8);
        for (var c = start; c <= end && c <= 0x10FFFF; c++) {
          final id = gid + c - start;
          if (id != 0 && id < numGlyphs) map[c] = id;
        }
      }
    } else {
      final segX2 = _u16(best + 6);
      final ends = best + 14, starts = ends + segX2 + 2, deltas = starts + segX2, ranges = deltas + segX2;
      for (var s = 0; s < segX2 ~/ 2; s++) {
        final end = _u16(ends + 2 * s), start = _u16(starts + 2 * s), delta = _i16(deltas + 2 * s), rangeOff = _u16(ranges + 2 * s);
        for (var c = start; c <= end && c != 0xFFFF; c++) {
          int id;
          if (rangeOff == 0) {
            id = (c + delta) & 0xFFFF;
          } else {
            final p = ranges + 2 * s + rangeOff + 2 * (c - start);
            if (p + 2 > bytes.length) continue;
            id = _u16(p);
            if (id != 0) id = (id + delta) & 0xFFFF;
          }
          if (id != 0 && id < numGlyphs) map[c] = id;
        }
      }
    }
    return map;
  }

  /// Advance width of [glyph] in font units.
  int advanceWidth(int glyph) {
    final hmtx = tables['hmtx']!.offset;
    final i = glyph < numberOfHMetrics ? glyph : numberOfHMetrics - 1;
    return _u16(hmtx + 4 * i);
  }

  /// Left side bearing of [glyph] in font units.
  int leftSideBearing(int glyph) {
    final hmtx = tables['hmtx']!.offset;
    if (glyph < numberOfHMetrics) return _i16(hmtx + 4 * glyph + 2);
    return _i16(hmtx + 4 * numberOfHMetrics + 2 * (glyph - numberOfHMetrics));
  }

  /// Byte range of the outline of [glyph] inside the glyf table (empty for
  /// glyphs without contours, like the space).
  (int, int) glyphRange(int glyph) {
    if (glyph < 0 || glyph >= numGlyphs) return (0, 0);
    final loca = tables['loca']!.offset;
    int a, b;
    if (indexToLocFormat == 0) {
      a = _u16(loca + 2 * glyph) * 2;
      b = _u16(loca + 2 * glyph + 2) * 2;
    } else {
      a = _u32(loca + 4 * glyph);
      b = _u32(loca + 4 * glyph + 4);
    }
    final glyf = tables['glyf']!;
    if (b < a || b > glyf.length) return (0, 0);
    return (glyf.offset + a, glyf.offset + b);
  }

  /// Glyphs referenced by the composite glyph [glyph] (empty for simple glyphs).
  List<int> components(int glyph) {
    final (a, b) = glyphRange(glyph);
    if (b - a < 10 || _i16(a) >= 0) return const [];
    final out = <int>[];
    var p = a + 10;
    while (p + 4 <= b) {
      final flags = _u16(p);
      out.add(_u16(p + 2));
      p += 4 + ((flags & 0x0001) != 0 ? 4 : 2); // ARG_1_AND_2_ARE_WORDS
      if ((flags & 0x0008) != 0) {
        p += 2; // WE_HAVE_A_SCALE
      } else if ((flags & 0x0040) != 0) {
        p += 4; // WE_HAVE_AN_X_AND_Y_SCALE
      } else if ((flags & 0x0080) != 0) {
        p += 8; // WE_HAVE_A_TWO_BY_TWO
      }
      if ((flags & 0x0020) == 0) break; // MORE_COMPONENTS
    }
    return out;
  }

  /// Bytes of table [tag], or null.
  ByteData? table(String tag) {
    final t = tables[tag];
    return t == null ? null : ByteData.sublistView(bytes, t.offset, t.offset + t.length);
  }
}
