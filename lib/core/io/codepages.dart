/// Text encodings of the files the readers take: byte order marks (UTF-8,
/// UTF-16), strict UTF-8, the single-byte code pages of Windows and DOS
/// (the `$DWGCODEPAGE` of DXF files and the code page of DWG R13–R2004
/// files) and the East Asian double-byte pages 932 (Japanese), 936
/// (Simplified Chinese), 949 (Korean) and 950 (Traditional Chinese). The
/// single-byte tables are the upper halves (0x80–0xFF) of the Unicode
/// mappings of each code page; a byte a page leaves undefined keeps its own
/// value, as Windows does. The double-byte tables live in a library loaded
/// on demand ([loadCjkCodepages], codepages_cjk_data.dart): until then
/// those pages are not held and callers read them as 1252 and say so.
/// Johab (1361) is not held.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'codepages_cjk_data.dart' deferred as cjk;

/// The single-byte code pages (numbers as in `ANSI_1252`, `DOS850`).
const singleByteCodepages = {874, 1250, 1251, 1252, 1253, 1254, 1255, 1256, 1257, 1258, 437, 850, 852, 866, 28591};

/// Code pages held: the single-byte ones, and the East Asian ones once
/// their tables are loaded.
Set<int> get supportedCodepages => _dbcs.isEmpty ? singleByteCodepages : {...singleByteCodepages, ..._dbcs.keys};

/// Multibyte East Asian code pages.
const cjkCodepages = {932, 936, 949, 950, 1361};

/// The East Asian pages whose tables [loadCjkCodepages] brings.
const loadableCjkCodepages = {932, 936, 949, 950};

/// Whether the double-byte tables are loaded.
bool get cjkCodepagesLoaded => _dbcs.isNotEmpty;

final Map<int, _Dbcs> _dbcs = {};
Future<void>? _loading;

/// Loads the tables of the East Asian code pages (932, 936, 949, 950):
/// a deferred library, which the browser fetches the first time a file
/// needs it. A failure (offline, no copy of the library) leaves them out
/// and the readers fall back to 1252 with their note.
Future<void> loadCjkCodepages() => _loading ??= () async {
  try {
    await cjk.loadLibrary();
    for (final e in cjk.cjkTables.entries) {
      _dbcs[e.key] = _Dbcs.decode(e.value);
    }
  } on Object {
    _loading = null;
  }
}();

/// A double-byte code page: the characters of the single bytes 0x80–0xFF
/// and, per lead byte, of the trail bytes 0x40–0xFF (0: none).
class _Dbcs {
  _Dbcs(this.single, this.rows);
  final Uint16List single;
  final Map<int, Uint16List> rows;

  /// The table of tool/formats/gen_codepages_cjk.py.
  static _Dbcs decode(String base64Data) {
    final raw = const ZLibDecoder().decodeBytes(base64.decode(base64Data));
    final bd = ByteData.sublistView(Uint8List.fromList(raw));
    final single = Uint16List(128);
    var p = 0;
    for (var i = 0; i < 128; i++, p += 2) {
      single[i] = bd.getUint16(p, Endian.little);
    }
    final n = raw[p++];
    final rows = <int, Uint16List>{};
    for (var k = 0; k < n; k++) {
      final lead = raw[p++];
      final row = Uint16List(256);
      var prev = 0;
      for (var t = 0x40; t < 0x100; t++, p += 2) {
        final d = bd.getUint16(p, Endian.little);
        if (d == 0) continue;
        prev = (prev + d) & 0xFFFF;
        row[t] = prev;
      }
      rows[lead] = row;
    }
    return _Dbcs(single, rows);
  }

  String decodeRange(List<int> bytes, int start, int end) {
    final out = Uint16List(end - start);
    var o = 0;
    for (var i = start; i < end; i++) {
      final b = bytes[i];
      if (b < 0x80) {
        out[o++] = b;
        continue;
      }
      final row = rows[b];
      if (row != null && i + 1 < end) {
        final c = row[bytes[i + 1]];
        if (c != 0) {
          out[o++] = c;
          i++;
          continue;
        }
      }
      final s = single[b - 0x80];
      out[o++] = s != 0 ? s : 0xFFFD;
    }
    return String.fromCharCodes(Uint16List.sublistView(out, 0, o));
  }
}

/// Whether file [name] ([bytes]) names an East Asian code page whose
/// tables are not loaded yet: the `$DWGCODEPAGE` of a DXF, the code page of
/// a DWG R13–R2004 or the .cpg of a shapefile (in a zip or beside it as a
/// DBF's language driver).
bool needsCjkCodepages(String name, Uint8List bytes) {
  if (cjkCodepagesLoaded) return false;
  final lower = name.toLowerCase();
  int? cp;
  if (lower.endsWith('.dxf')) {
    final head = latin1.decode(Uint8List.sublistView(bytes, 0, bytes.length < 65536 ? bytes.length : 65536));
    final page = RegExp(r'\$DWGCODEPAGE\s*\r?\n\s*3\s*\r?\n\s*([^\r\n]+)').firstMatch(head)?.group(1);
    cp = page == null ? null : codepageFromName(page);
  } else if (lower.endsWith('.dwg')) {
    final v = bytes.length > 6 ? String.fromCharCodes(bytes.sublist(0, 6)) : '';
    if (v.compareTo('AC1021') < 0 && bytes.length > 0x14) cp = codepageFromDwg(bytes[0x13] + bytes[0x14] * 256);
  } else if (lower.endsWith('.dbf')) {
    cp = bytes.length > 29 ? codepageFromDbfLanguage(bytes[29]) : null;
  } else if (lower.endsWith('.zip')) {
    // the .cpg of a shapefile (a few bytes; the DBF is not opened for this)
    try {
      for (final f in ZipDecoder().decodeBytes(bytes)) {
        if (!f.name.toLowerCase().endsWith('.cpg') || f.size <= 0 || f.size > 256) continue;
        final page = codepageFromCpg(latin1.decode(f.readBytes() ?? const []));
        if (page != null && loadableCjkCodepages.contains(page)) return true;
      }
    } on Object {
      return false;
    }
  }
  return cp != null && loadableCjkCodepages.contains(cp);
}

/// The code page a .cpg file names (`1252`, `CP1251`, `ANSI 1250`,
/// `ISO-8859-1`, `GBK`, `BIG5`, `SJIS`, `EUC-KR`), or null.
int? codepageFromCpg(String text) {
  final c = text.toUpperCase().trim();
  if (c.isEmpty) return null;
  if (c.contains('8859') || c.contains('LATIN')) return 28591;
  if (c.contains('GBK') || c.contains('GB2312') || c.contains('GB18030')) return 936;
  if (c.contains('BIG5') || c.contains('BIG-5')) return 950;
  if (c.contains('SJIS') || c.contains('SHIFT_JIS') || c.contains('SHIFT-JIS')) return 932;
  if (c.contains('EUC-KR') || c.contains('EUCKR') || c.contains('KS_C_5601') || c.contains('UHC')) return 949;
  final named = RegExp(r'^(?:CP|ANSI|WINDOWS|MS)?[ _-]?(\d{3,5})$').firstMatch(c)?.group(1);
  return named == null ? null : int.parse(named);
}

/// The code page of a DBF language driver id (byte 29 of the header) for
/// the East Asian pages, or null.
int? codepageFromDbfLanguage(int ldid) => switch (ldid) {
  0x13 || 0x7B => 932,
  0x4D || 0x7A => 936,
  0x4E || 0x79 => 949,
  0x4F || 0x78 => 950,
  _ => null,
};

/// The code page named by a DXF `$DWGCODEPAGE` value (`ANSI_1251`,
/// `DOS850`, `ISO8859-1`), or null when the name is not understood.
int? codepageFromName(String name) {
  final n = name.trim().toUpperCase();
  final m = RegExp(r'^(?:ANSI|DOS|CP|WINDOWS)[_-]?(\d{3,4})$').firstMatch(n);
  if (m != null) return int.parse(m.group(1)!);
  if (RegExp(r'^ISO[_-]?8859[_-]1$').hasMatch(n)) return 28591;
  if (n == 'BIG5') return 950;
  if (n == 'GB2312') return 936;
  if (n == 'JOHAB') return 1361;
  return null;
}

/// The code page of a DWG file header (R13–R2004 store a number at byte
/// 0x13), or null for an unknown number. 0 and 30 (the usual value) are 1252.
int? codepageFromDwg(int n) => switch (n) {
  0 || 30 => 1252,
  1 || 2 => 28591,
  11 => 437,
  12 => 850,
  13 => 852,
  22 || 38 => 932,
  24 || 41 => 950,
  25 || 40 => 949,
  26 || 42 => 1361,
  27 => 866,
  28 => 1250,
  29 => 1251,
  31 || 39 => 936,
  32 => 1253,
  33 => 1254,
  34 => 1255,
  35 => 1256,
  36 => 1257,
  37 => 874,
  44 => 1258,
  _ => null,
};

/// Name of a code page in the `$DWGCODEPAGE` style (`ANSI_1252`).
String codepageName(int cp) => switch (cp) {
  437 || 850 || 852 || 866 => 'DOS$cp',
  28591 => 'ISO8859-1',
  _ => 'ANSI_$cp',
};

/// The Unicode character of byte [b] (0–255) in code page [cp] (1252 when
/// the page is not held).
int codepageChar(int b, int cp) {
  if (b < 0x80 || cp == 28591) return b;
  final d = _dbcs[cp];
  if (d != null) return d.single[b - 0x80] != 0 ? d.single[b - 0x80] : b;
  final t = _tables[cp] ?? _tables[1252]!;
  return t.codeUnitAt(b - 0x80);
}

/// [bytes] (or the range [start]–[end]) read in code page [cp] (an East
/// Asian page as double bytes once its table is loaded).
String decodeCodepage(List<int> bytes, int cp, [int start = 0, int? end]) {
  final e = end ?? bytes.length;
  if (cp == 28591) return latin1.decode(bytes.sublist(start, e));
  final d = _dbcs[cp];
  if (d != null) return d.decodeRange(bytes, start, e);
  final t = _tables[cp] ?? _tables[1252]!;
  final out = Uint16List(e - start);
  for (var i = start; i < e; i++) {
    final b = bytes[i];
    out[i - start] = b < 0x80 ? b : t.codeUnitAt(b - 0x80);
  }
  return String.fromCharCodes(out);
}

/// [s] in code page 1252: characters outside it become `?`.
Uint8List encodeCp1252(String s) {
  final back = _reverse1252 ??= {for (var i = 0; i < 128; i++) _tables[1252]!.codeUnitAt(i): 0x80 + i};
  final buf = Uint8List(s.length);
  var n = 0;
  for (final r in s.runes) {
    buf[n++] = r < 0x80 ? r : (back[r] ?? 0x3F);
  }
  return Uint8List.sublistView(buf, 0, n);
}

Map<int, int>? _reverse1252;

/// The byte order mark at the start of [bytes]: 'utf8', 'utf16le',
/// 'utf16be' or null.
String? byteOrderMark(List<int> bytes) {
  if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) return 'utf8';
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) return 'utf16le';
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) return 'utf16be';
  return null;
}

/// UTF-16 without a byte order mark, told by the zero bytes of ASCII text
/// at every other position: 'utf16le', 'utf16be' or null.
String? utf16WithoutBom(List<int> bytes) {
  final n = bytes.length < 4096 ? bytes.length & ~1 : 4096;
  if (n < 8) return null;
  var evenZero = 0, oddZero = 0;
  for (var i = 0; i < n; i += 2) {
    if (bytes[i] == 0) evenZero++;
    if (bytes[i + 1] == 0) oddZero++;
  }
  final half = n ~/ 2;
  if (oddZero > half * 0.6 && evenZero < half * 0.1) return 'utf16le';
  if (evenZero > half * 0.6 && oddZero < half * 0.1) return 'utf16be';
  return null;
}

/// UTF-16 [bytes] from [start] (pairs in the given byte order; a lone
/// surrogate stays as it is).
String decodeUtf16(List<int> bytes, {required bool littleEndian, int start = 0}) {
  final n = (bytes.length - start) ~/ 2;
  final units = Uint16List(n);
  for (var i = 0; i < n; i++) {
    final a = bytes[start + 2 * i], b = bytes[start + 2 * i + 1];
    units[i] = littleEndian ? a | (b << 8) : (a << 8) | b;
  }
  return String.fromCharCodes(units);
}

/// Text of a file whose encoding is not declared: a byte order mark
/// (UTF-8, UTF-16) wins, then UTF-16 told by its zero bytes, then strict
/// UTF-8, else code page [fallback] (1252: Latin-1 would turn "€", "–" and
/// the curly quotes into control characters).
String decodeTextBytes(List<int> bytes, {int fallback = 1252}) {
  switch (byteOrderMark(bytes)) {
    case 'utf8':
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    case 'utf16le':
      return decodeUtf16(bytes, littleEndian: true, start: 2);
    case 'utf16be':
      return decodeUtf16(bytes, littleEndian: false, start: 2);
  }
  final u16 = utf16WithoutBom(bytes);
  if (u16 != null) return decodeUtf16(bytes, littleEndian: u16 == 'utf16le');
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return decodeCodepage(bytes, fallback);
  }
}

/// Upper halves (bytes 0x80–0xFF) of the code pages.
const _tables = <int, String>{
  874:
      '\u20AC\u0081\u0082\u0083\u0084\u2026\u0086\u0087\u0088\u0089\u008A\u008B\u008C\u008D\u008E\u008F'
      '\u0090\u2018\u2019\u201C\u201D\u2022\u2013\u2014\u0098\u0099\u009A\u009B\u009C\u009D\u009E\u009F'
      '\u00A0\u0E01\u0E02\u0E03\u0E04\u0E05\u0E06\u0E07\u0E08\u0E09\u0E0A\u0E0B\u0E0C\u0E0D\u0E0E\u0E0F'
      '\u0E10\u0E11\u0E12\u0E13\u0E14\u0E15\u0E16\u0E17\u0E18\u0E19\u0E1A\u0E1B\u0E1C\u0E1D\u0E1E\u0E1F'
      '\u0E20\u0E21\u0E22\u0E23\u0E24\u0E25\u0E26\u0E27\u0E28\u0E29\u0E2A\u0E2B\u0E2C\u0E2D\u0E2E\u0E2F'
      '\u0E30\u0E31\u0E32\u0E33\u0E34\u0E35\u0E36\u0E37\u0E38\u0E39\u0E3A\u00DB\u00DC\u00DD\u00DE\u0E3F'
      '\u0E40\u0E41\u0E42\u0E43\u0E44\u0E45\u0E46\u0E47\u0E48\u0E49\u0E4A\u0E4B\u0E4C\u0E4D\u0E4E\u0E4F'
      '\u0E50\u0E51\u0E52\u0E53\u0E54\u0E55\u0E56\u0E57\u0E58\u0E59\u0E5A\u0E5B\u00FC\u00FD\u00FE\u00FF',
  1250:
      '\u20AC\u0081\u201A\u0083\u201E\u2026\u2020\u2021\u0088\u2030\u0160\u2039\u015A\u0164\u017D\u0179'
      '\u0090\u2018\u2019\u201C\u201D\u2022\u2013\u2014\u0098\u2122\u0161\u203A\u015B\u0165\u017E\u017A'
      '\u00A0\u02C7\u02D8\u0141\u00A4\u0104\u00A6\u00A7\u00A8\u00A9\u015E\u00AB\u00AC\u00AD\u00AE\u017B'
      '\u00B0\u00B1\u02DB\u0142\u00B4\u00B5\u00B6\u00B7\u00B8\u0105\u015F\u00BB\u013D\u02DD\u013E\u017C'
      '\u0154\u00C1\u00C2\u0102\u00C4\u0139\u0106\u00C7\u010C\u00C9\u0118\u00CB\u011A\u00CD\u00CE\u010E'
      '\u0110\u0143\u0147\u00D3\u00D4\u0150\u00D6\u00D7\u0158\u016E\u00DA\u0170\u00DC\u00DD\u0162\u00DF'
      '\u0155\u00E1\u00E2\u0103\u00E4\u013A\u0107\u00E7\u010D\u00E9\u0119\u00EB\u011B\u00ED\u00EE\u010F'
      '\u0111\u0144\u0148\u00F3\u00F4\u0151\u00F6\u00F7\u0159\u016F\u00FA\u0171\u00FC\u00FD\u0163\u02D9',
  1251:
      '\u0402\u0403\u201A\u0453\u201E\u2026\u2020\u2021\u20AC\u2030\u0409\u2039\u040A\u040C\u040B\u040F'
      '\u0452\u2018\u2019\u201C\u201D\u2022\u2013\u2014\u0098\u2122\u0459\u203A\u045A\u045C\u045B\u045F'
      '\u00A0\u040E\u045E\u0408\u00A4\u0490\u00A6\u00A7\u0401\u00A9\u0404\u00AB\u00AC\u00AD\u00AE\u0407'
      '\u00B0\u00B1\u0406\u0456\u0491\u00B5\u00B6\u00B7\u0451\u2116\u0454\u00BB\u0458\u0405\u0455\u0457'
      '\u0410\u0411\u0412\u0413\u0414\u0415\u0416\u0417\u0418\u0419\u041A\u041B\u041C\u041D\u041E\u041F'
      '\u0420\u0421\u0422\u0423\u0424\u0425\u0426\u0427\u0428\u0429\u042A\u042B\u042C\u042D\u042E\u042F'
      '\u0430\u0431\u0432\u0433\u0434\u0435\u0436\u0437\u0438\u0439\u043A\u043B\u043C\u043D\u043E\u043F'
      '\u0440\u0441\u0442\u0443\u0444\u0445\u0446\u0447\u0448\u0449\u044A\u044B\u044C\u044D\u044E\u044F',
  1252:
      '\u20AC\u0081\u201A\u0192\u201E\u2026\u2020\u2021\u02C6\u2030\u0160\u2039\u0152\u008D\u017D\u008F'
      '\u0090\u2018\u2019\u201C\u201D\u2022\u2013\u2014\u02DC\u2122\u0161\u203A\u0153\u009D\u017E\u0178'
      '\u00A0\u00A1\u00A2\u00A3\u00A4\u00A5\u00A6\u00A7\u00A8\u00A9\u00AA\u00AB\u00AC\u00AD\u00AE\u00AF'
      '\u00B0\u00B1\u00B2\u00B3\u00B4\u00B5\u00B6\u00B7\u00B8\u00B9\u00BA\u00BB\u00BC\u00BD\u00BE\u00BF'
      '\u00C0\u00C1\u00C2\u00C3\u00C4\u00C5\u00C6\u00C7\u00C8\u00C9\u00CA\u00CB\u00CC\u00CD\u00CE\u00CF'
      '\u00D0\u00D1\u00D2\u00D3\u00D4\u00D5\u00D6\u00D7\u00D8\u00D9\u00DA\u00DB\u00DC\u00DD\u00DE\u00DF'
      '\u00E0\u00E1\u00E2\u00E3\u00E4\u00E5\u00E6\u00E7\u00E8\u00E9\u00EA\u00EB\u00EC\u00ED\u00EE\u00EF'
      '\u00F0\u00F1\u00F2\u00F3\u00F4\u00F5\u00F6\u00F7\u00F8\u00F9\u00FA\u00FB\u00FC\u00FD\u00FE\u00FF',
  1253:
      '\u20AC\u0081\u201A\u0192\u201E\u2026\u2020\u2021\u0088\u2030\u008A\u2039\u008C\u008D\u008E\u008F'
      '\u0090\u2018\u2019\u201C\u201D\u2022\u2013\u2014\u0098\u2122\u009A\u203A\u009C\u009D\u009E\u009F'
      '\u00A0\u0385\u0386\u00A3\u00A4\u00A5\u00A6\u00A7\u00A8\u00A9\u00AA\u00AB\u00AC\u00AD\u00AE\u2015'
      '\u00B0\u00B1\u00B2\u00B3\u0384\u00B5\u00B6\u00B7\u0388\u0389\u038A\u00BB\u038C\u00BD\u038E\u038F'
      '\u0390\u0391\u0392\u0393\u0394\u0395\u0396\u0397\u0398\u0399\u039A\u039B\u039C\u039D\u039E\u039F'
      '\u03A0\u03A1\u00D2\u03A3\u03A4\u03A5\u03A6\u03A7\u03A8\u03A9\u03AA\u03AB\u03AC\u03AD\u03AE\u03AF'
      '\u03B0\u03B1\u03B2\u03B3\u03B4\u03B5\u03B6\u03B7\u03B8\u03B9\u03BA\u03BB\u03BC\u03BD\u03BE\u03BF'
      '\u03C0\u03C1\u03C2\u03C3\u03C4\u03C5\u03C6\u03C7\u03C8\u03C9\u03CA\u03CB\u03CC\u03CD\u03CE\u00FF',
  1254:
      '\u20AC\u0081\u201A\u0192\u201E\u2026\u2020\u2021\u02C6\u2030\u0160\u2039\u0152\u008D\u008E\u008F'
      '\u0090\u2018\u2019\u201C\u201D\u2022\u2013\u2014\u02DC\u2122\u0161\u203A\u0153\u009D\u009E\u0178'
      '\u00A0\u00A1\u00A2\u00A3\u00A4\u00A5\u00A6\u00A7\u00A8\u00A9\u00AA\u00AB\u00AC\u00AD\u00AE\u00AF'
      '\u00B0\u00B1\u00B2\u00B3\u00B4\u00B5\u00B6\u00B7\u00B8\u00B9\u00BA\u00BB\u00BC\u00BD\u00BE\u00BF'
      '\u00C0\u00C1\u00C2\u00C3\u00C4\u00C5\u00C6\u00C7\u00C8\u00C9\u00CA\u00CB\u00CC\u00CD\u00CE\u00CF'
      '\u011E\u00D1\u00D2\u00D3\u00D4\u00D5\u00D6\u00D7\u00D8\u00D9\u00DA\u00DB\u00DC\u0130\u015E\u00DF'
      '\u00E0\u00E1\u00E2\u00E3\u00E4\u00E5\u00E6\u00E7\u00E8\u00E9\u00EA\u00EB\u00EC\u00ED\u00EE\u00EF'
      '\u011F\u00F1\u00F2\u00F3\u00F4\u00F5\u00F6\u00F7\u00F8\u00F9\u00FA\u00FB\u00FC\u0131\u015F\u00FF',
  1255:
      '\u20AC\u0081\u201A\u0192\u201E\u2026\u2020\u2021\u02C6\u2030\u008A\u2039\u008C\u008D\u008E\u008F'
      '\u0090\u2018\u2019\u201C\u201D\u2022\u2013\u2014\u02DC\u2122\u009A\u203A\u009C\u009D\u009E\u009F'
      '\u00A0\u00A1\u00A2\u00A3\u20AA\u00A5\u00A6\u00A7\u00A8\u00A9\u00D7\u00AB\u00AC\u00AD\u00AE\u00AF'
      '\u00B0\u00B1\u00B2\u00B3\u00B4\u00B5\u00B6\u00B7\u00B8\u00B9\u00F7\u00BB\u00BC\u00BD\u00BE\u00BF'
      '\u05B0\u05B1\u05B2\u05B3\u05B4\u05B5\u05B6\u05B7\u05B8\u05B9\u00CA\u05BB\u05BC\u05BD\u05BE\u05BF'
      '\u05C0\u05C1\u05C2\u05C3\u05F0\u05F1\u05F2\u05F3\u05F4\u00D9\u00DA\u00DB\u00DC\u00DD\u00DE\u00DF'
      '\u05D0\u05D1\u05D2\u05D3\u05D4\u05D5\u05D6\u05D7\u05D8\u05D9\u05DA\u05DB\u05DC\u05DD\u05DE\u05DF'
      '\u05E0\u05E1\u05E2\u05E3\u05E4\u05E5\u05E6\u05E7\u05E8\u05E9\u05EA\u00FB\u00FC\u200E\u200F\u00FF',
  1256:
      '\u20AC\u067E\u201A\u0192\u201E\u2026\u2020\u2021\u02C6\u2030\u0679\u2039\u0152\u0686\u0698\u0688'
      '\u06AF\u2018\u2019\u201C\u201D\u2022\u2013\u2014\u06A9\u2122\u0691\u203A\u0153\u200C\u200D\u06BA'
      '\u00A0\u060C\u00A2\u00A3\u00A4\u00A5\u00A6\u00A7\u00A8\u00A9\u06BE\u00AB\u00AC\u00AD\u00AE\u00AF'
      '\u00B0\u00B1\u00B2\u00B3\u00B4\u00B5\u00B6\u00B7\u00B8\u00B9\u061B\u00BB\u00BC\u00BD\u00BE\u061F'
      '\u06C1\u0621\u0622\u0623\u0624\u0625\u0626\u0627\u0628\u0629\u062A\u062B\u062C\u062D\u062E\u062F'
      '\u0630\u0631\u0632\u0633\u0634\u0635\u0636\u00D7\u0637\u0638\u0639\u063A\u0640\u0641\u0642\u0643'
      '\u00E0\u0644\u00E2\u0645\u0646\u0647\u0648\u00E7\u00E8\u00E9\u00EA\u00EB\u0649\u064A\u00EE\u00EF'
      '\u064B\u064C\u064D\u064E\u00F4\u064F\u0650\u00F7\u0651\u00F9\u0652\u00FB\u00FC\u200E\u200F\u06D2',
  1257:
      '\u20AC\u0081\u201A\u0083\u201E\u2026\u2020\u2021\u0088\u2030\u008A\u2039\u008C\u00A8\u02C7\u00B8'
      '\u0090\u2018\u2019\u201C\u201D\u2022\u2013\u2014\u0098\u2122\u009A\u203A\u009C\u00AF\u02DB\u009F'
      '\u00A0\u00A1\u00A2\u00A3\u00A4\u00A5\u00A6\u00A7\u00D8\u00A9\u0156\u00AB\u00AC\u00AD\u00AE\u00C6'
      '\u00B0\u00B1\u00B2\u00B3\u00B4\u00B5\u00B6\u00B7\u00F8\u00B9\u0157\u00BB\u00BC\u00BD\u00BE\u00E6'
      '\u0104\u012E\u0100\u0106\u00C4\u00C5\u0118\u0112\u010C\u00C9\u0179\u0116\u0122\u0136\u012A\u013B'
      '\u0160\u0143\u0145\u00D3\u014C\u00D5\u00D6\u00D7\u0172\u0141\u015A\u016A\u00DC\u017B\u017D\u00DF'
      '\u0105\u012F\u0101\u0107\u00E4\u00E5\u0119\u0113\u010D\u00E9\u017A\u0117\u0123\u0137\u012B\u013C'
      '\u0161\u0144\u0146\u00F3\u014D\u00F5\u00F6\u00F7\u0173\u0142\u015B\u016B\u00FC\u017C\u017E\u02D9',
  1258:
      '\u20AC\u0081\u201A\u0192\u201E\u2026\u2020\u2021\u02C6\u2030\u008A\u2039\u0152\u008D\u008E\u008F'
      '\u0090\u2018\u2019\u201C\u201D\u2022\u2013\u2014\u02DC\u2122\u009A\u203A\u0153\u009D\u009E\u0178'
      '\u00A0\u00A1\u00A2\u00A3\u00A4\u00A5\u00A6\u00A7\u00A8\u00A9\u00AA\u00AB\u00AC\u00AD\u00AE\u00AF'
      '\u00B0\u00B1\u00B2\u00B3\u00B4\u00B5\u00B6\u00B7\u00B8\u00B9\u00BA\u00BB\u00BC\u00BD\u00BE\u00BF'
      '\u00C0\u00C1\u00C2\u0102\u00C4\u00C5\u00C6\u00C7\u00C8\u00C9\u00CA\u00CB\u0300\u00CD\u00CE\u00CF'
      '\u0110\u00D1\u0309\u00D3\u00D4\u01A0\u00D6\u00D7\u00D8\u00D9\u00DA\u00DB\u00DC\u01AF\u0303\u00DF'
      '\u00E0\u00E1\u00E2\u0103\u00E4\u00E5\u00E6\u00E7\u00E8\u00E9\u00EA\u00EB\u0301\u00ED\u00EE\u00EF'
      '\u0111\u00F1\u0323\u00F3\u00F4\u01A1\u00F6\u00F7\u00F8\u00F9\u00FA\u00FB\u00FC\u01B0\u20AB\u00FF',
  437:
      '\u00C7\u00FC\u00E9\u00E2\u00E4\u00E0\u00E5\u00E7\u00EA\u00EB\u00E8\u00EF\u00EE\u00EC\u00C4\u00C5'
      '\u00C9\u00E6\u00C6\u00F4\u00F6\u00F2\u00FB\u00F9\u00FF\u00D6\u00DC\u00A2\u00A3\u00A5\u20A7\u0192'
      '\u00E1\u00ED\u00F3\u00FA\u00F1\u00D1\u00AA\u00BA\u00BF\u2310\u00AC\u00BD\u00BC\u00A1\u00AB\u00BB'
      '\u2591\u2592\u2593\u2502\u2524\u2561\u2562\u2556\u2555\u2563\u2551\u2557\u255D\u255C\u255B\u2510'
      '\u2514\u2534\u252C\u251C\u2500\u253C\u255E\u255F\u255A\u2554\u2569\u2566\u2560\u2550\u256C\u2567'
      '\u2568\u2564\u2565\u2559\u2558\u2552\u2553\u256B\u256A\u2518\u250C\u2588\u2584\u258C\u2590\u2580'
      '\u03B1\u00DF\u0393\u03C0\u03A3\u03C3\u00B5\u03C4\u03A6\u0398\u03A9\u03B4\u221E\u03C6\u03B5\u2229'
      '\u2261\u00B1\u2265\u2264\u2320\u2321\u00F7\u2248\u00B0\u2219\u00B7\u221A\u207F\u00B2\u25A0\u00A0',
  850:
      '\u00C7\u00FC\u00E9\u00E2\u00E4\u00E0\u00E5\u00E7\u00EA\u00EB\u00E8\u00EF\u00EE\u00EC\u00C4\u00C5'
      '\u00C9\u00E6\u00C6\u00F4\u00F6\u00F2\u00FB\u00F9\u00FF\u00D6\u00DC\u00F8\u00A3\u00D8\u00D7\u0192'
      '\u00E1\u00ED\u00F3\u00FA\u00F1\u00D1\u00AA\u00BA\u00BF\u00AE\u00AC\u00BD\u00BC\u00A1\u00AB\u00BB'
      '\u2591\u2592\u2593\u2502\u2524\u00C1\u00C2\u00C0\u00A9\u2563\u2551\u2557\u255D\u00A2\u00A5\u2510'
      '\u2514\u2534\u252C\u251C\u2500\u253C\u00E3\u00C3\u255A\u2554\u2569\u2566\u2560\u2550\u256C\u00A4'
      '\u00F0\u00D0\u00CA\u00CB\u00C8\u0131\u00CD\u00CE\u00CF\u2518\u250C\u2588\u2584\u00A6\u00CC\u2580'
      '\u00D3\u00DF\u00D4\u00D2\u00F5\u00D5\u00B5\u00FE\u00DE\u00DA\u00DB\u00D9\u00FD\u00DD\u00AF\u00B4'
      '\u00AD\u00B1\u2017\u00BE\u00B6\u00A7\u00F7\u00B8\u00B0\u00A8\u00B7\u00B9\u00B3\u00B2\u25A0\u00A0',
  852:
      '\u00C7\u00FC\u00E9\u00E2\u00E4\u016F\u0107\u00E7\u0142\u00EB\u0150\u0151\u00EE\u0179\u00C4\u0106'
      '\u00C9\u0139\u013A\u00F4\u00F6\u013D\u013E\u015A\u015B\u00D6\u00DC\u0164\u0165\u0141\u00D7\u010D'
      '\u00E1\u00ED\u00F3\u00FA\u0104\u0105\u017D\u017E\u0118\u0119\u00AC\u017A\u010C\u015F\u00AB\u00BB'
      '\u2591\u2592\u2593\u2502\u2524\u00C1\u00C2\u011A\u015E\u2563\u2551\u2557\u255D\u017B\u017C\u2510'
      '\u2514\u2534\u252C\u251C\u2500\u253C\u0102\u0103\u255A\u2554\u2569\u2566\u2560\u2550\u256C\u00A4'
      '\u0111\u0110\u010E\u00CB\u010F\u0147\u00CD\u00CE\u011B\u2518\u250C\u2588\u2584\u0162\u016E\u2580'
      '\u00D3\u00DF\u00D4\u0143\u0144\u0148\u0160\u0161\u0154\u00DA\u0155\u0170\u00FD\u00DD\u0163\u00B4'
      '\u00AD\u02DD\u02DB\u02C7\u02D8\u00A7\u00F7\u00B8\u00B0\u00A8\u02D9\u0171\u0158\u0159\u25A0\u00A0',
  866:
      '\u0410\u0411\u0412\u0413\u0414\u0415\u0416\u0417\u0418\u0419\u041A\u041B\u041C\u041D\u041E\u041F'
      '\u0420\u0421\u0422\u0423\u0424\u0425\u0426\u0427\u0428\u0429\u042A\u042B\u042C\u042D\u042E\u042F'
      '\u0430\u0431\u0432\u0433\u0434\u0435\u0436\u0437\u0438\u0439\u043A\u043B\u043C\u043D\u043E\u043F'
      '\u2591\u2592\u2593\u2502\u2524\u2561\u2562\u2556\u2555\u2563\u2551\u2557\u255D\u255C\u255B\u2510'
      '\u2514\u2534\u252C\u251C\u2500\u253C\u255E\u255F\u255A\u2554\u2569\u2566\u2560\u2550\u256C\u2567'
      '\u2568\u2564\u2565\u2559\u2558\u2552\u2553\u256B\u256A\u2518\u250C\u2588\u2584\u258C\u2590\u2580'
      '\u0440\u0441\u0442\u0443\u0444\u0445\u0446\u0447\u0448\u0449\u044A\u044B\u044C\u044D\u044E\u044F'
      '\u0401\u0451\u0404\u0454\u0407\u0457\u040E\u045E\u00B0\u2219\u00B7\u221A\u2116\u00A4\u25A0\u00A0',
};
