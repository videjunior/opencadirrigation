part of 'pdf_reader.dart';

// Fonts of the PDF reader: how the bytes of a shown string split into
// character codes, the text of each code and its advance width.

/// A font as far as text extraction goes.
class _Font {
  _Font._();

  /// Composite (Type0) font: codes split by [encoding], widths by CID.
  bool composite = false;

  /// Codespace and CIDs of a composite font.
  _CMap encoding = _CMap.identity;

  /// The codes of the predefined Unicode CMaps (UniJIS-UCS2-H…) are the
  /// characters themselves.
  bool unicodeCodes = false;
  _CMap? toUnicode;

  /// Text of each code of a simple font (encoding and /Differences).
  List<String?> simple = const [];
  int firstChar = 0;
  List<double> widths = const [];
  double missingWidth = 0;
  Map<int, double> cidWidths = const {};
  List<(int, int, double)> cidWidthRanges = const [];
  double defaultWidth = 1000;

  /// Glyph space → text space (FontMatrix of Type 3 fonts, 1/1000 otherwise).
  double scale = 0.001;

  /// Ratio of the em of a Type 3 font to the font size.
  double heightScale = 1;
  String baseFont = '';
  bool fixedPitch = false;

  /// Stands for a font missing from the resources: WinAnsi codes, Helvetica widths.
  static _Font fallback() => _Font._()..simple = [for (final u in _winAnsi) u == 0 ? null : String.fromCharCode(u)];

  static _Font load(PdfReader doc, Map<String, Object?> d) {
    final f = _Font._();
    final subtype = doc._name(d['Subtype']) ?? 'Type1';
    f.baseFont = (doc._name(d['BaseFont']) ?? '').replaceFirst(RegExp(r'^[A-Z]{6}\+'), '');
    final tu = doc._resolve(d['ToUnicode']);
    if (tu is _Stream) {
      try {
        f.toUnicode = _CMap.parse(doc._decodeStream(tu));
      } on _TooLarge {
        rethrow;
      } on Object {
        // a damaged ToUnicode: the encoding is all there is
      }
    }
    if (subtype == 'Type0') {
      f.composite = true;
      final enc = doc._resolve(d['Encoding']);
      if (enc is _Name) {
        final n = enc.v;
        if (n.startsWith('Uni') && (n.contains('UCS2') || n.contains('UTF16'))) {
          f.unicodeCodes = true;
          f.encoding = n.contains('UTF16') ? _CMap.utf16 : _CMap.identity;
        } else if (n != 'Identity-H' && n != 'Identity-V') {
          // another predefined CMap: its code lengths are those of the ToUnicode map, if any
          f.encoding = f.toUnicode != null && f.toUnicode!.codespace.isNotEmpty ? (_CMap()..codespace.addAll(f.toUnicode!.codespace)) : _CMap.identity;
        }
      } else if (enc is _Stream) {
        try {
          f.encoding = _CMap.parse(doc._decodeStream(enc));
          if (f.encoding.codespace.isEmpty) f.encoding.codespace.addAll(_CMap.identity.codespace);
        } on _TooLarge {
          rethrow;
        } on Object {
          f.encoding = _CMap.identity;
        }
      }
      final desc = doc._dict(doc._array(d['DescendantFonts'])?.firstOrNull);
      if (desc != null) {
        f.defaultWidth = doc._num(desc['DW']) ?? 1000;
        final w = doc._array(desc['W']);
        if (w != null) {
          final singles = <int, double>{};
          final ranges = <(int, int, double)>[];
          var i = 0;
          while (i < w.length) {
            final c0 = doc._int(w[i]);
            if (c0 == null) break;
            final next = doc._resolve(i + 1 < w.length ? w[i + 1] : null);
            if (next is List) {
              for (var k = 0; k < next.length; k++) {
                singles[c0 + k] = doc._num(next[k]) ?? f.defaultWidth;
              }
              i += 2;
            } else {
              final c1 = doc._int(next), wv = doc._num(i + 2 < w.length ? w[i + 2] : null);
              if (c1 == null || wv == null) break;
              ranges.add((c0, c1, wv));
              i += 3;
            }
          }
          f.cidWidths = singles;
          f.cidWidthRanges = ranges;
        }
        f.fixedPitch = ((doc._int(doc._dict(desc['FontDescriptor'])?['Flags']) ?? 0) & 1) != 0;
      }
      return f;
    }
    f.firstChar = doc._int(d['FirstChar']) ?? 0;
    f.widths = [for (final v in doc._array(d['Widths']) ?? const []) doc._num(v) ?? 0];
    final fd = doc._dict(d['FontDescriptor']);
    f.missingWidth = doc._num(fd?['MissingWidth']) ?? 0;
    f.fixedPitch = ((doc._int(fd?['Flags']) ?? 0) & 1) != 0 || f.baseFont.contains('Courier');
    if (subtype == 'Type3') {
      final m = doc._numbers(d['FontMatrix']);
      if (m != null && m.length >= 4) {
        f.scale = m[0].abs() > 0 ? m[0] : 0.001;
        f.heightScale = (m[3].abs() * 1000).clamp(0.01, 100).toDouble();
      }
    }
    f.simple = _simpleEncoding(doc, d, subtype, f.baseFont);
    return f;
  }

  /// Calls [f] with every code of [s] and its length in bytes.
  void forEachCode(Uint8List s, void Function(int code, int length) f) {
    if (!composite) {
      for (final c in s) {
        f(c, 1);
      }
      return;
    }
    encoding.split(s, f);
  }

  /// Text of [code], or null when it cannot be mapped.
  String? text(int code) {
    final u = toUnicode?.lookup(code);
    if (u != null) return _clean(u);
    if (composite) {
      if (!unicodeCodes) return null;
      return _clean(code > 0xFFFF ? String.fromCharCodes([0xD800 + ((code - 0x10000) >> 10), 0xDC00 + ((code - 0x10000) & 0x3FF)]) : String.fromCharCode(code));
    }
    return code < simple.length ? simple[code] : null;
  }

  /// Advance of [code] in text space units per unit of font size.
  double advance(int code) {
    if (composite) {
      final cid = encoding.cid(code) ?? (unicodeCodes ? -1 : code);
      var w = cidWidths[cid];
      if (w == null) {
        for (final r in cidWidthRanges) {
          if (cid >= r.$1 && cid <= r.$2) {
            w = r.$3;
            break;
          }
        }
      }
      return (w ?? defaultWidth) / 1000;
    }
    final i = code - firstChar;
    if (i >= 0 && i < widths.length) return widths[i] * scale;
    if (missingWidth > 0) return missingWidth * scale;
    // the standard fonts come without widths: their metrics, roughly
    if (fixedPitch) return 0.6;
    final t = code < simple.length ? simple[code] : null;
    return helveticaWidth(t == null || t.isEmpty ? 'n' : t) / 1000;
  }

  /// [s] without control characters and private-use code points (symbol
  /// fonts), which no font of the drawing could show; null when nothing is left.
  static String? _clean(String s) {
    if (s.isEmpty) return null;
    var plain = true;
    for (final u in s.codeUnits) {
      if (u < 0x20 || (u >= 0xE000 && u <= 0xF8FF) || u == 0xFFFD || u == 0xFEFF) {
        plain = false;
        break;
      }
    }
    if (plain) return s;
    final out = String.fromCharCodes(s.runes.where((r) => r >= 0x20 && !(r >= 0xE000 && r <= 0xF8FF) && r != 0xFFFD && r != 0xFEFF && !(r >= 0xF0000)));
    return out.isEmpty ? null : out;
  }
}

/// Text of every code of a simple font: its base encoding with the
/// /Differences applied.
List<String?> _simpleEncoding(PdfReader doc, Map<String, Object?> d, String subtype, String baseFont) {
  final enc = doc._resolve(d['Encoding']);
  final symbol = baseFont.startsWith('Symbol');
  final dingbats = baseFont.contains('Dingbats') || baseFont.startsWith('Wingdings') || baseFont.startsWith('Webdings');
  final baseName = enc is _Name ? enc.v : (enc is Map<String, Object?> ? doc._name(enc['BaseEncoding']) : null);
  final List<int>? table = switch (baseName) {
    'WinAnsiEncoding' => _winAnsi,
    'MacRomanEncoding' => _macRoman,
    'StandardEncoding' => _standard,
    'PDFDocEncoding' => _pdfDoc,
    _ => symbol ? _symbol : (dingbats ? null : (subtype == 'TrueType' ? _winAnsi : _standard)),
  };
  final out = List<String?>.generate(256, (i) {
    final u = table == null ? 0 : table[i];
    return u == 0 ? null : String.fromCharCode(u);
  });
  if (enc is Map<String, Object?>) {
    final diff = doc._array(enc['Differences']);
    if (diff != null) {
      var code = 0;
      for (final e in diff) {
        final v = doc._resolve(e);
        if (v is num) {
          code = v.toInt();
        } else if (v is _Name) {
          if (code >= 0 && code < 256) out[code] = _glyphText(v.v);
          code++;
        }
      }
    }
  }
  return out;
}

/// Text of a glyph name: the standard names, `uniXXXX`, `uXXXX[XX]`,
/// ligatures joined by `_` and variants after a period (`a.sc`).
String? _glyphText(String name) {
  final dot = name.indexOf('.');
  final base = dot > 0 ? name.substring(0, dot) : name;
  if (base.contains('_')) {
    final parts = [for (final p in base.split('_')) _glyphText(p)];
    return parts.any((p) => p == null) ? null : parts.join();
  }
  final known = _glyphNames[base];
  if (known != null) return String.fromCharCode(known);
  if (base.length == 1) {
    final c = base.codeUnitAt(0);
    if ((c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A)) return base;
  }
  if (base.startsWith('uni') && base.length >= 7 && (base.length - 3) % 4 == 0) {
    final units = <int>[];
    for (var i = 3; i < base.length; i += 4) {
      final v = int.tryParse(base.substring(i, i + 4), radix: 16);
      if (v == null) return null;
      units.add(v);
    }
    return _Font._clean(String.fromCharCodes(units));
  }
  if (base.startsWith('u') && base.length >= 5 && base.length <= 7) {
    final v = int.tryParse(base.substring(1), radix: 16);
    if (v != null && v <= 0x10FFFF) return _Font._clean(String.fromCharCodes([v]));
  }
  return null;
}

// ---------------------------------------------------------------- CMaps

/// A CMap (9.7.5, 9.10.3): the codespace ranges that split strings into
/// codes, and the code → CID or code → text mappings.
class _CMap {
  _CMap();

  /// Two-byte codes, CID = code (Identity-H/V).
  static final identity = _CMap()
    ..identityCids = true
    ..codespace.add(_CodeRange(2, 0, 0xFFFF));

  /// UTF-16 codes (two bytes, four for a surrogate pair).
  static final utf16 = _CMap()
    ..utf16Codes = true
    ..codespace.add(_CodeRange(2, 0, 0xFFFF));

  final List<_CodeRange> codespace = [];
  bool identityCids = false;
  bool utf16Codes = false;
  final Map<int, String> chars = {};
  final List<(int, int, String)> charRanges = [];
  final Map<int, int> cids = {};
  final List<(int, int, int)> cidRanges = [];

  int? cid(int code) {
    if (identityCids) return code;
    final c = cids[code];
    if (c != null) return c;
    for (final r in cidRanges) {
      if (code >= r.$1 && code <= r.$2) return r.$3 + code - r.$1;
    }
    return null;
  }

  String? lookup(int code) {
    final s = chars[code];
    if (s != null) return s;
    for (final r in charRanges) {
      if (code >= r.$1 && code <= r.$2) {
        // the last code unit counts up through the range
        final base = r.$3;
        final last = base.codeUnitAt(base.length - 1) + code - r.$1;
        return base.substring(0, base.length - 1) + String.fromCharCode(last & 0xFFFF);
      }
    }
    return null;
  }

  /// Calls [f] with every code of [s] (9.7.6.2: the shortest codespace
  /// range the bytes fit; a code in no range takes the shortest length).
  void split(Uint8List s, void Function(int code, int length) f) {
    final spaces = codespace.isEmpty ? identity.codespace : codespace;
    var minLen = 4;
    for (final r in spaces) {
      if (r.length < minLen) minLen = r.length;
    }
    var i = 0;
    while (i < s.length) {
      if (utf16Codes && i + 3 < s.length && s[i] >= 0xD8 && s[i] <= 0xDB) {
        final hi = (s[i] << 8) | s[i + 1], lo = (s[i + 2] << 8) | s[i + 3];
        f(0x10000 + ((hi - 0xD800) << 10) + (lo - 0xDC00), 4);
        i += 4;
        continue;
      }
      var matched = 0, code = 0;
      for (var len = 1; len <= 4 && matched == 0; len++) {
        if (i + len > s.length) break;
        var v = 0;
        for (var k = 0; k < len; k++) {
          v = v * 256 + s[i + k];
        }
        for (final r in spaces) {
          if (r.length == len && r.contains(v)) {
            matched = len;
            code = v;
            break;
          }
        }
      }
      if (matched == 0) {
        matched = math.min(minLen, s.length - i);
        for (var k = 0; k < matched; k++) {
          code = code * 256 + s[i + k];
        }
      }
      f(code, matched);
      i += matched;
    }
  }

  static int _code(_Str s) {
    var v = 0;
    for (final b in s.b) {
      v = v * 256 + b;
    }
    return v;
  }

  static String _utf16(_Str s) {
    final b = s.b;
    if (b.length == 1) return String.fromCharCode(b[0]);
    return String.fromCharCodes([for (var i = 0; i + 1 < b.length; i += 2) (b[i] << 8) | b[i + 1]]);
  }

  static _CMap parse(Uint8List data) {
    final m = _CMap();
    final p = _Parser(data);
    final ops = <Object?>[];
    var guard = 0;
    while (guard++ < 2000000) {
      Object? t;
      try {
        t = p.parse(0, false);
      } on _Eof {
        break;
      } on FormatException {
        break;
      }
      if (t is! _Kw) {
        ops.add(t);
        continue;
      }
      switch (t.v) {
        case 'endcodespacerange':
          for (var i = 0; i + 1 < ops.length; i += 2) {
            final lo = ops[i], hi = ops[i + 1];
            if (lo is _Str && hi is _Str && lo.b.isNotEmpty && lo.b.length == hi.b.length && lo.b.length <= 4) m.codespace.add(_CodeRange(lo.b.length, _code(lo), _code(hi), lo.b, hi.b));
          }
        case 'endbfchar':
          for (var i = 0; i + 1 < ops.length; i += 2) {
            final src = ops[i], dst = ops[i + 1];
            if (src is! _Str) continue;
            if (dst is _Str) {
              m.chars[_code(src)] = _utf16(dst);
            } else if (dst is _Name) {
              final g = _glyphText(dst.v);
              if (g != null) m.chars[_code(src)] = g;
            }
          }
        case 'endbfrange':
          for (var i = 0; i + 2 < ops.length; i += 3) {
            final lo = ops[i], hi = ops[i + 1], dst = ops[i + 2];
            if (lo is! _Str || hi is! _Str) continue;
            final a = _code(lo), b = _code(hi);
            if (b < a || b - a > 0xFFFF) continue;
            if (dst is _Str && dst.b.isNotEmpty) {
              if (b - a < 256) {
                final base = _utf16(dst);
                for (var c = a; c <= b; c++) {
                  final last = base.codeUnitAt(base.length - 1) + c - a;
                  m.chars.putIfAbsent(c, () => base.substring(0, base.length - 1) + String.fromCharCode(last & 0xFFFF));
                }
              } else {
                m.charRanges.add((a, b, _utf16(dst)));
              }
            } else if (dst is List) {
              for (var k = 0; k < dst.length && a + k <= b; k++) {
                final s = dst[k];
                if (s is _Str) m.chars[a + k] = _utf16(s);
              }
            }
          }
        case 'endcidrange':
          for (var i = 0; i + 2 < ops.length; i += 3) {
            final lo = ops[i], hi = ops[i + 1], cid = ops[i + 2];
            if (lo is _Str && hi is _Str && cid is int) m.cidRanges.add((_code(lo), _code(hi), cid));
          }
        case 'endcidchar':
          for (var i = 0; i + 1 < ops.length; i += 2) {
            final src = ops[i], cid = ops[i + 1];
            if (src is _Str && cid is int) m.cids[_code(src)] = cid;
          }
        case 'usecmap':
          final base = ops.isEmpty ? null : ops.last;
          if (base is _Name && base.v.startsWith('Identity')) {
            m.identityCids = m.cids.isEmpty && m.cidRanges.isEmpty;
            if (m.codespace.isEmpty) m.codespace.addAll(identity.codespace);
          }
      }
      ops.clear();
    }
    return m;
  }
}

/// A codespace range: codes of [length] bytes, each byte within the bytes
/// of [lo] and [hi].
class _CodeRange {
  _CodeRange(this.length, this.low, this.high, [this.lo, this.hi]);
  final int length;
  final int low, high;
  final Uint8List? lo, hi;

  bool contains(int code) {
    if (code < low || code > high) return false;
    final a = lo, b = hi;
    if (a == null || b == null) return true;
    // byte by byte (a range like <8140> <9FFC> leaves gaps)
    var v = code;
    for (var k = length - 1; k >= 0; k--) {
      final byte = v % 256;
      v ~/= 256;
      if (byte < a[k] || byte > b[k]) return false;
    }
    return true;
  }
}

// ---------------------------------------------------------------- encodings

/// WinAnsiEncoding (annex D.2): code → Unicode (0 = none).
final List<int> _winAnsi = () {
  final t = List<int>.filled(256, 0);
  for (var i = 0x20; i < 0x7F; i++) {
    t[i] = i;
  }
  const high = [
    0x20AC, 0, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0, 0x017D, 0, //
    0, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0, 0x017E, 0x0178,
  ];
  for (var i = 0; i < 32; i++) {
    t[0x80 + i] = high[i];
  }
  for (var i = 0xA0; i < 0x100; i++) {
    t[i] = i;
  }
  t[0xA0] = 0x20;
  t[0xAD] = 0x2D;
  return t;
}();

/// MacRomanEncoding (annex D.2).
final List<int> _macRoman = () {
  final t = List<int>.filled(256, 0);
  for (var i = 0x20; i < 0x7F; i++) {
    t[i] = i;
  }
  const high = [
    0xC4, 0xC5, 0xC7, 0xC9, 0xD1, 0xD6, 0xDC, 0xE1, 0xE0, 0xE2, 0xE4, 0xE3, 0xE5, 0xE7, 0xE9, 0xE8, //
    0xEA, 0xEB, 0xED, 0xEC, 0xEE, 0xEF, 0xF1, 0xF3, 0xF2, 0xF4, 0xF6, 0xF5, 0xFA, 0xF9, 0xFB, 0xFC,
    0x2020, 0xB0, 0xA2, 0xA3, 0xA7, 0x2022, 0xB6, 0xDF, 0xAE, 0xA9, 0x2122, 0xB4, 0xA8, 0x2260, 0xC6, 0xD8,
    0x221E, 0xB1, 0x2264, 0x2265, 0xA5, 0xB5, 0x2202, 0x2211, 0x220F, 0x3C0, 0x222B, 0xAA, 0xBA, 0x3A9, 0xE6, 0xF8,
    0xBF, 0xA1, 0xAC, 0x221A, 0x192, 0x2248, 0x2206, 0xAB, 0xBB, 0x2026, 0x20, 0xC0, 0xC3, 0xD5, 0x152, 0x153,
    0x2013, 0x2014, 0x201C, 0x201D, 0x2018, 0x2019, 0xF7, 0x25CA, 0xFF, 0x178, 0x2044, 0xA4, 0x2039, 0x203A, 0xFB01, 0xFB02,
    0x2021, 0xB7, 0x201A, 0x201E, 0x2030, 0xC2, 0xCA, 0xC1, 0xCB, 0xC8, 0xCD, 0xCE, 0xCF, 0xCC, 0xD3, 0xD4,
    0, 0xD2, 0xDA, 0xDB, 0xD9, 0x131, 0x2C6, 0x2DC, 0xAF, 0x2D8, 0x2D9, 0x2DA, 0xB8, 0x2DD, 0x2DB, 0x2C7,
  ];
  for (var i = 0; i < 128; i++) {
    t[0x80 + i] = high[i];
  }
  return t;
}();

/// StandardEncoding (annex D.2).
final List<int> _standard = () {
  final t = List<int>.filled(256, 0);
  for (var i = 0x20; i < 0x7F; i++) {
    t[i] = i;
  }
  t[0x27] = 0x2019;
  t[0x60] = 0x2018;
  const pairs = {
    0xA1: 0xA1, 0xA2: 0xA2, 0xA3: 0xA3, 0xA4: 0x2044, 0xA5: 0xA5, 0xA6: 0x192, 0xA7: 0xA7, 0xA8: 0xA4, 0xA9: 0x27, 0xAA: 0x201C, 0xAB: 0xAB, 0xAC: 0x2039, 0xAD: 0x203A, 0xAE: 0xFB01, 0xAF: 0xFB02, //
    0xB1: 0x2013, 0xB2: 0x2020, 0xB3: 0x2021, 0xB4: 0xB7, 0xB6: 0xB6, 0xB7: 0x2022, 0xB8: 0x201A, 0xB9: 0x201E, 0xBA: 0x201D, 0xBB: 0xBB, 0xBC: 0x2026, 0xBD: 0x2030, 0xBF: 0xBF,
    0xC1: 0x60, 0xC2: 0xB4, 0xC3: 0x2C6, 0xC4: 0x2DC, 0xC5: 0xAF, 0xC6: 0x2D8, 0xC7: 0x2D9, 0xC8: 0xA8, 0xCA: 0x2DA, 0xCB: 0xB8, 0xCD: 0x2DD, 0xCE: 0x2DB, 0xCF: 0x2C7,
    0xD0: 0x2014, 0xE1: 0xC6, 0xE3: 0xAA, 0xE8: 0x141, 0xE9: 0xD8, 0xEA: 0x152, 0xEB: 0xBA, 0xF1: 0xE6, 0xF5: 0x131, 0xF8: 0x142, 0xF9: 0xF8, 0xFA: 0x153, 0xFB: 0xDF,
  };
  pairs.forEach((k, v) => t[k] = v);
  return t;
}();

/// PDFDocEncoding (annex D.2).
final List<int> _pdfDoc = () {
  final t = List<int>.filled(256, 0);
  for (var i = 0x20; i < 0x100; i++) {
    t[i] = i >= 0x80 && i <= 0xA0 ? _pdfDocHigh[i - 0x80] : i;
  }
  t[0x7F] = 0;
  return t;
}();

/// Encoding of the Symbol font (annex D.5); bracket pieces and other
/// glyphs without a character are left out.
final List<int> _symbol = () {
  final t = List<int>.filled(256, 0);
  for (var i = 0x20; i < 0x7F; i++) {
    t[i] = i;
  }
  const pairs = {
    0x22: 0x2200, 0x24: 0x2203, 0x27: 0x220B, 0x2A: 0x2217, 0x2D: 0x2212, 0x40: 0x2245, //
    0x41: 0x391, 0x42: 0x392, 0x43: 0x3A7, 0x44: 0x394, 0x45: 0x395, 0x46: 0x3A6, 0x47: 0x393, 0x48: 0x397, 0x49: 0x399, 0x4A: 0x3D1, 0x4B: 0x39A, 0x4C: 0x39B, 0x4D: 0x39C, 0x4E: 0x39D, 0x4F: 0x39F,
    0x50: 0x3A0, 0x51: 0x398, 0x52: 0x3A1, 0x53: 0x3A3, 0x54: 0x3A4, 0x55: 0x3A5, 0x56: 0x3C2, 0x57: 0x3A9, 0x58: 0x39E, 0x59: 0x3A8, 0x5A: 0x396, 0x5C: 0x2234, 0x5E: 0x22A5, 0x60: 0,
    0x61: 0x3B1, 0x62: 0x3B2, 0x63: 0x3C7, 0x64: 0x3B4, 0x65: 0x3B5, 0x66: 0x3C6, 0x67: 0x3B3, 0x68: 0x3B7, 0x69: 0x3B9, 0x6A: 0x3D5, 0x6B: 0x3BA, 0x6C: 0x3BB, 0x6D: 0x3BC, 0x6E: 0x3BD, 0x6F: 0x3BF,
    0x70: 0x3C0, 0x71: 0x3B8, 0x72: 0x3C1, 0x73: 0x3C3, 0x74: 0x3C4, 0x75: 0x3C5, 0x76: 0x3D6, 0x77: 0x3C9, 0x78: 0x3BE, 0x79: 0x3C8, 0x7A: 0x3B6, 0x7E: 0x223C,
    0xA0: 0x20AC,
    0xA1: 0x3D2,
    0xA2: 0x2032,
    0xA3: 0x2264,
    0xA4: 0x2044,
    0xA5: 0x221E,
    0xA6: 0x192,
    0xA7: 0x2663,
    0xA8: 0x2666,
    0xA9: 0x2665,
    0xAA: 0x2660,
    0xAB: 0x2194,
    0xAC: 0x2190,
    0xAD: 0x2191,
    0xAE: 0x2192,
    0xAF: 0x2193,
    0xB0: 0xB0, 0xB1: 0xB1, 0xB2: 0x2033, 0xB3: 0x2265, 0xB4: 0xD7, 0xB5: 0x221D, 0xB6: 0x2202, 0xB7: 0x2022, 0xB8: 0xF7, 0xB9: 0x2260, 0xBA: 0x2261, 0xBB: 0x2248, 0xBC: 0x2026, 0xBF: 0x21B5,
    0xC0: 0x2135,
    0xC1: 0x2111,
    0xC2: 0x211C,
    0xC3: 0x2118,
    0xC4: 0x2297,
    0xC5: 0x2295,
    0xC6: 0x2205,
    0xC7: 0x2229,
    0xC8: 0x222A,
    0xC9: 0x2283,
    0xCA: 0x2287,
    0xCB: 0x2284,
    0xCC: 0x2282,
    0xCD: 0x2286,
    0xCE: 0x2208,
    0xCF: 0x2209,
    0xD0: 0x2220,
    0xD1: 0x2207,
    0xD2: 0xAE,
    0xD3: 0xA9,
    0xD4: 0x2122,
    0xD5: 0x220F,
    0xD6: 0x221A,
    0xD7: 0x22C5,
    0xD8: 0xAC,
    0xD9: 0x2227,
    0xDA: 0x2228,
    0xDB: 0x21D4,
    0xDC: 0x21D0,
    0xDD: 0x21D1,
    0xDE: 0x21D2,
    0xDF: 0x21D3,
    0xE0: 0x25CA, 0xE1: 0x2329, 0xE2: 0xAE, 0xE3: 0xA9, 0xE4: 0x2122, 0xE5: 0x2211, 0xF1: 0x232A, 0xF2: 0x222B, 0xF3: 0x2320, 0xF5: 0x2321,
  };
  pairs.forEach((k, v) => t[k] = v);
  return t;
}();

/// Standard glyph names → Unicode (the names of the Latin encodings, the
/// Symbol font, Latin Extended-A and the common typographic glyphs).
final Map<String, int> _glyphNames = () {
  final m = <String, int>{};
  const ascii = [
    'space', 'exclam', 'quotedbl', 'numbersign', 'dollar', 'percent', 'ampersand', 'quotesingle', 'parenleft', 'parenright', 'asterisk', 'plus', 'comma', 'hyphen', 'period', 'slash', //
    'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'colon', 'semicolon', 'less', 'equal', 'greater', 'question', 'at',
  ];
  for (var i = 0; i < ascii.length; i++) {
    m[ascii[i]] = 0x20 + i;
  }
  const ascii2 = ['bracketleft', 'backslash', 'bracketright', 'asciicircum', 'underscore', 'grave'];
  for (var i = 0; i < ascii2.length; i++) {
    m[ascii2[i]] = 0x5B + i;
  }
  m.addAll({'braceleft': 0x7B, 'bar': 0x7C, 'braceright': 0x7D, 'asciitilde': 0x7E});
  const latin1 = [
    'nbspace',
    'exclamdown',
    'cent',
    'sterling',
    'currency',
    'yen',
    'brokenbar',
    'section',
    'dieresis',
    'copyright',
    'ordfeminine',
    'guillemotleft',
    'logicalnot',
    'sfthyphen',
    'registered',
    'macron', //
    'degree',
    'plusminus',
    'twosuperior',
    'threesuperior',
    'acute',
    'mu',
    'paragraph',
    'periodcentered',
    'cedilla',
    'onesuperior',
    'ordmasculine',
    'guillemotright',
    'onequarter',
    'onehalf',
    'threequarters',
    'questiondown',
    'Agrave', 'Aacute', 'Acircumflex', 'Atilde', 'Adieresis', 'Aring', 'AE', 'Ccedilla', 'Egrave', 'Eacute', 'Ecircumflex', 'Edieresis', 'Igrave', 'Iacute', 'Icircumflex', 'Idieresis',
    'Eth', 'Ntilde', 'Ograve', 'Oacute', 'Ocircumflex', 'Otilde', 'Odieresis', 'multiply', 'Oslash', 'Ugrave', 'Uacute', 'Ucircumflex', 'Udieresis', 'Yacute', 'Thorn', 'germandbls',
  ];
  for (var i = 0; i < latin1.length; i++) {
    m[latin1[i]] = 0xA0 + i;
  }
  // the lower-case half of Latin-1 mirrors the upper-case one
  for (var i = 0; i < 32; i++) {
    final upper = latin1[32 + i];
    final name = switch (i) {
      0x17 => 'divide',
      0x1F => 'ydieresis',
      _ => upper == 'AE' ? 'ae' : upper[0].toLowerCase() + upper.substring(1),
    };
    m[name] = 0xE0 + i;
  }
  m.addAll({
    'Euro': 0x20AC, 'quotesinglbase': 0x201A, 'florin': 0x192, 'quotedblbase': 0x201E, 'ellipsis': 0x2026, 'dagger': 0x2020, 'daggerdbl': 0x2021, 'circumflex': 0x2C6, //
    'perthousand': 0x2030, 'Scaron': 0x160, 'guilsinglleft': 0x2039, 'OE': 0x152, 'Zcaron': 0x17D, 'quoteleft': 0x2018, 'quoteright': 0x2019, 'quotedblleft': 0x201C,
    'quotedblright': 0x201D, 'bullet': 0x2022, 'endash': 0x2013, 'emdash': 0x2014, 'tilde': 0x2DC, 'trademark': 0x2122, 'scaron': 0x161, 'guilsinglright': 0x203A,
    'oe': 0x153, 'zcaron': 0x17E, 'Ydieresis': 0x178, 'fraction': 0x2044, 'fi': 0xFB01, 'fl': 0xFB02, 'dotlessi': 0x131, 'ring': 0x2DA, 'hungarumlaut': 0x2DD,
    'ogonek': 0x2DB, 'caron': 0x2C7, 'breve': 0x2D8, 'dotaccent': 0x2D9, 'Lslash': 0x141, 'lslash': 0x142, 'minus': 0x2212, 'mu1': 0xB5, 'micro': 0xB5,
    'Delta': 0x2206, 'Omega': 0x2126, 'pi': 0x3C0, 'notequal': 0x2260, 'infinity': 0x221E, 'lessequal': 0x2264, 'greaterequal': 0x2265, 'partialdiff': 0x2202,
    'summation': 0x2211, 'product': 0x220F, 'integral': 0x222B, 'radical': 0x221A, 'approxequal': 0x2248, 'lozenge': 0x25CA, 'emptyset': 0x2205, 'diameter': 0x2300,
    'universal': 0x2200, 'existential': 0x2203, 'suchthat': 0x220B, 'asteriskmath': 0x2217, 'congruent': 0x2245, 'therefore': 0x2234, 'perpendicular': 0x22A5,
    'similar': 0x223C, 'equivalence': 0x2261, 'proportional': 0x221D, 'arrowleft': 0x2190, 'arrowup': 0x2191, 'arrowright': 0x2192, 'arrowdown': 0x2193,
    'arrowboth': 0x2194, 'arrowdblleft': 0x21D0, 'arrowdblup': 0x21D1, 'arrowdblright': 0x21D2, 'arrowdbldown': 0x21D3, 'arrowdblboth': 0x21D4, 'carriagereturn': 0x21B5,
    'second': 0x2033, 'minute': 0x2032, 'aleph': 0x2135, 'Ifraktur': 0x2111, 'Rfraktur': 0x211C, 'weierstrass': 0x2118, 'circlemultiply': 0x2297, 'circleplus': 0x2295,
    'intersection': 0x2229, 'union': 0x222A, 'propersuperset': 0x2283, 'reflexsuperset': 0x2287, 'notsubset': 0x2284, 'propersubset': 0x2282, 'reflexsubset': 0x2286,
    'element': 0x2208, 'notelement': 0x2209, 'angle': 0x2220, 'gradient': 0x2207, 'dotmath': 0x22C5, 'logicaland': 0x2227, 'logicalor': 0x2228, 'angleleft': 0x2329,
    'angleright': 0x232A, 'integraltp': 0x2320, 'integralbt': 0x2321, 'club': 0x2663, 'diamond': 0x2666, 'heart': 0x2665, 'spade': 0x2660, 'Upsilon1': 0x3D2,
    'theta1': 0x3D1, 'phi1': 0x3D5, 'omega1': 0x3D6, 'sigma1': 0x3C2, 'registerserif': 0xAE, 'copyrightserif': 0xA9, 'trademarkserif': 0x2122,
    'registersans': 0xAE, 'copyrightsans': 0xA9, 'trademarksans': 0x2122, 'onethird': 0x2153, 'twothirds': 0x2154, 'oneeighth': 0x215B, 'Ohm': 0x2126, 'estimated': 0x212E,
    'degreecentigrade': 0x2103, 'afii61289': 0x2113, 'numero': 0x2116, 'checkmark': 0x2713, 'filledbox': 0x25A0, 'H22073': 0x25A1, 'triagup': 0x25B2, 'triagdn': 0x25BC,
    'circle': 0x25CB, 'H18533': 0x25CF, 'blackcircle': 0x25CF, 'whitecircle': 0x25CB, 'square': 0x25A1, 'blacksquare': 0x25A0, 'dieresistonos': 0x385, 'tonos': 0x384,
  });
  const greek = [
    'Alpha',
    'Beta',
    'Gamma',
    'Deltagreek',
    'Epsilon',
    'Zeta',
    'Eta',
    'Theta',
    'Iota',
    'Kappa',
    'Lambda',
    'Mu',
    'Nu',
    'Xi',
    'Omicron',
    'Pi',
    'Rho',
    '',
    'Sigma',
    'Tau',
    'Upsilon',
    'Phi',
    'Chi',
    'Psi',
    'Omegagreek',
  ];
  for (var i = 0; i < greek.length; i++) {
    if (greek[i].isEmpty) continue;
    m[greek[i]] = 0x391 + i;
    final lower = greek[i].replaceFirst('greek', '');
    m[lower[0].toLowerCase() + lower.substring(1)] = 0x3B1 + i;
  }
  m['mugreek'] = 0x3BC;
  m['Deltagreek'] = 0x394;
  m['Omegagreek'] = 0x3A9;
  m['sigmafinal'] = 0x3C2;
  // Latin Extended-A (pairs of upper and lower case from U+0100)
  const extA = [
    'Amacron', 'Abreve', 'Aogonek', 'Cacute', 'Ccircumflex', 'Cdotaccent', 'Ccaron', 'Dcaron', 'Dcroat', 'Emacron', 'Ebreve', 'Edotaccent', 'Eogonek', 'Ecaron', 'Gcircumflex', 'Gbreve', //
    'Gdotaccent', 'Gcommaaccent', 'Hcircumflex', 'Hbar', 'Itilde', 'Imacron', 'Ibreve', 'Iogonek', 'Idotaccent', 'IJ', 'Jcircumflex', 'Kcommaaccent',
  ];
  for (var i = 0; i < extA.length; i++) {
    final upper = extA[i];
    m[upper] = 0x100 + 2 * i;
    final lower = switch (upper) {
      'Idotaccent' => 'dotlessi',
      'IJ' => 'ij',
      'Dcroat' => 'dcroat',
      _ => upper[0].toLowerCase() + upper.substring(1),
    };
    if (upper != 'Idotaccent') m[lower] = 0x101 + 2 * i;
  }
  m['Idotaccent'] = 0x130;
  m['kgreenlandic'] = 0x138;
  const extA2 = [
    'Lacute', 'Lcommaaccent', 'Lcaron', 'Ldot', 'Lslash', 'Nacute', 'Ncommaaccent', 'Ncaron', //
  ];
  for (var i = 0; i < extA2.length; i++) {
    m[extA2[i]] = 0x139 + 2 * i;
    m[extA2[i][0].toLowerCase() + extA2[i].substring(1)] = 0x13A + 2 * i;
  }
  m['napostrophe'] = 0x149;
  const extA3 = [
    'Eng', 'Omacron', 'Obreve', 'Ohungarumlaut', 'OE', 'Racute', 'Rcommaaccent', 'Rcaron', 'Sacute', 'Scircumflex', 'Scedilla', 'Scaron', 'Tcommaaccent', 'Tcaron', 'Tbar', 'Utilde', //
    'Umacron', 'Ubreve', 'Uring', 'Uhungarumlaut', 'Uogonek', 'Wcircumflex', 'Ycircumflex',
  ];
  for (var i = 0; i < extA3.length; i++) {
    m[extA3[i]] = 0x14A + 2 * i;
    final lower = extA3[i] == 'OE' ? 'oe' : extA3[i][0].toLowerCase() + extA3[i].substring(1);
    m[lower] = 0x14B + 2 * i;
  }
  m.addAll({'Ydieresis': 0x178, 'Zacute': 0x179, 'zacute': 0x17A, 'Zdotaccent': 0x17B, 'zdotaccent': 0x17C, 'Zcaron': 0x17D, 'zcaron': 0x17E, 'longs': 0x17F, 'Tcedilla': 0x162, 'tcedilla': 0x163});
  // the glyph names of the Latin-1 half that differ from Latin-1 itself
  m['space'] = 0x20;
  m['hyphen'] = 0x2D;
  m['nbspace'] = 0x20;
  m['sfthyphen'] = 0x2D;
  m['Lslash'] = 0x141;
  m['lslash'] = 0x142;
  m['Omega'] = 0x3A9;
  m['Delta'] = 0x394;
  m['mu'] = 0xB5;
  return m;
}();
