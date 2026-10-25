/// PDF reader for plans imported as an underlay (pure Dart, ISO 32000-1 /
/// PDF 1.7, and PDF 2.0 files written the same way).
///
/// File structure: the header (found within the first kilobyte, offsets
/// corrected when junk precedes it), classic cross-reference tables and PDF
/// 1.5 cross-reference streams, object streams, the /Prev chain of
/// incremental updates (the newest definition wins) and hybrid files
/// (/XRefStm). A damaged or missing table is rebuilt by scanning the file
/// for `n g obj`, which also finds the objects packed in object streams.
/// Encrypted files are refused (`pdf_encrypted`): even those that open
/// without a password would need the RC4/AES ciphers.
///
/// Stream filters: FlateDecode and LZWDecode with the PNG and TIFF
/// predictors, ASCIIHexDecode, ASCII85Decode, RunLengthDecode; for images
/// DCTDecode (the JPEG data is passed through) and CCITTFaxDecode (through
/// the TIFF fax decoder of the image package). JPXDecode and JBIG2Decode
/// images are left out with a warning. Decoded streams are capped, so a
/// small file cannot expand into gigabytes.
///
/// A page is interpreted on demand into neutral items, in displayed page
/// space: points (1/72 inch, times /UserUnit), origin at the bottom-left
/// corner of the crop box, /Rotate applied, so the plan comes in the way a
/// viewer shows it:
///
/// * [PdfPathItem]: stroked and filled outlines. Curves are flattened to
///   polylines within a tolerance tied to the page size; consecutive
///   stroked segments of one style that meet end to end (CAD programs often
///   write every line on its own) are merged into one polyline.
/// * [PdfTextItem]: shown strings joined into runs along their baseline,
///   with the baseline origin, the height (the font size on the page) and
///   the angle. Codes are decoded through the ToUnicode CMap, else the font
///   encoding (WinAnsi, MacRoman, Standard, Symbol, /Differences with the
///   standard glyph names) or, for composite fonts, the Unicode CMaps;
///   glyphs that cannot be mapped are skipped. Invisible text (render mode
///   3, the OCR layer of scans) is left out.
/// * [PdfImageItem]: image XObjects and inline images, re-encoded as PNG
///   (JPEG data passed through), with the page positions of the four
///   corners of the raster.
///
/// Optional content groups (/OC on marked content and XObjects, OCMDs)
/// name the layer of what they enclose; content of layers that are off by
/// default is marked hidden. Clipping is approximated by a rectangle: the
/// bounding box of each clipping path (and of each form's /BBox),
/// intersected along the graphics state stack, so that what a map frame or
/// a CAD viewport hides stays out while nothing visible is lost; paths are
/// cut to it, texts and images wholly outside it are dropped. Shadings,
/// pattern fills (drawn grey), transparency groups, annotations and the
/// drawings of Type 3 glyphs are not interpreted. The work of a page is
/// capped ([pdfMaxSegments] segments and a number of operators); a
/// truncated page says so in its warnings.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;

import '../model/geometry.dart';
import 'fonts/pdf_fonts.dart' show helveticaWidth;

part 'pdf_reader_fonts.dart';
part 'pdf_reader_images.dart';

/// Most path segments read from one page; the rest is left out with the
/// warning `pdf_truncated`.
const pdfMaxSegments = 200000;

/// Most text runs and images read from one page.
const _maxTexts = 60000, _maxImages = 400;

/// Most content operators interpreted for one page (forms included).
const _maxOps = 40000000;

/// Largest decoded stream, and most bytes decoded for one page (forms,
/// images), so that a small file cannot expand without end.
const _maxStreamBytes = 256 << 20, _maxPageBytes = 768 << 20;

// ---------------------------------------------------------------- results

/// A page of the document: its 0-based [index], the size shown in points
/// (after /Rotate and /UserUnit) and the rotation applied (0, 90, 180, 270).
class PdfPageInfo {
  const PdfPageInfo({required this.index, required this.width, required this.height, this.rotation = 0, this.userUnit = 1});
  final int index;
  final double width, height;
  final int rotation;
  final double userUnit;

  /// Size in millimetres (1 point = 1/72 inch).
  double get widthMm => width * 25.4 / 72;
  double get heightMm => height * 25.4 / 72;
}

/// An optional content group (layer) and whether it is on by default.
class PdfLayerInfo {
  const PdfLayerInfo(this.name, {this.visible = true});
  final String name;
  final bool visible;
}

/// An outline painted on the page: points in page space, open or closed,
/// stroked and/or filled with RGB colours (0xRRGGBB), the line width in
/// page units and the layer (optional content group name, empty outside
/// any) it belongs to. [hidden] marks content of a layer that is off.
class PdfPathItem {
  PdfPathItem({required this.points, this.closed = false, this.stroked = true, this.filled = false, this.strokeRgb = 0, this.fillRgb = 0, this.lineWidth = 1, this.layer = '', this.hidden = false});
  final List<Pt> points;
  bool closed;
  final bool stroked, filled;
  final int strokeRgb, fillRgb;
  final double lineWidth;
  final String layer;
  final bool hidden;

  /// The colour it shows: the stroke when stroked, else the fill.
  int get rgb => stroked ? strokeRgb : fillRgb;

  /// Segments of the outline.
  int get segments => closed ? points.length : points.length - 1;
}

/// A run of text: the [origin] of its baseline, the [height] (font size on
/// the page) and the [angleDeg] of the baseline, counter-clockwise.
class PdfTextItem {
  PdfTextItem({required this.text, required this.origin, required this.height, this.angleDeg = 0, this.rgb = 0, this.layer = '', this.hidden = false});
  final String text;
  final Pt origin;
  final double height, angleDeg;
  final int rgb;
  final String layer;
  final bool hidden;
}

/// An image on the page: where the raster's bottom-left, bottom-right,
/// top-right and top-left corners are ([corners], page space; clockwise
/// when the image is drawn mirrored), its size in pixels and its encoded
/// [bytes] (PNG, or JPEG as stored), null when not decoded or not readable.
class PdfImageItem {
  PdfImageItem({required this.corners, required this.widthPx, required this.heightPx, this.bytes, this.mime = 'image/png', this.layer = '', this.hidden = false});
  final List<Pt> corners;
  final int widthPx, heightPx;
  final Uint8List? bytes;
  final String mime;
  final String layer;
  final bool hidden;
}

/// What a page draws, in page space (see the library comment).
class PdfPageContent {
  PdfPageContent({required this.page, required this.paths, required this.texts, required this.images, required this.layers, required this.warnings, this.truncated = false});
  final PdfPageInfo page;
  final List<PdfPathItem> paths;
  final List<PdfTextItem> texts;
  final List<PdfImageItem> images;

  /// Layers the page uses, in order of first use.
  final List<PdfLayerInfo> layers;

  /// Warning codes (`pdf_*`, optionally `code:detail`).
  final List<String> warnings;

  /// Whether the page had more than could be read (see [pdfMaxSegments]).
  final bool truncated;

  int get segments => paths.fold(0, (s, p) => s + p.segments);

  /// The same page with [images] in place of these (a second reading that
  /// decoded them).
  PdfPageContent withImages(List<PdfImageItem> images, [Iterable<String> moreWarnings = const []]) =>
      PdfPageContent(page: page, paths: paths, texts: texts, images: images, layers: layers, warnings: {...warnings, ...moreWarnings}.toList(), truncated: truncated);
}

/// An open PDF document: its pages and layers, and the content of a page
/// on demand ([readPage]).
class PdfReader {
  PdfReader._(this._b);

  /// Opens [bytes]. Throws a [FormatException] with a code (`pdf_not_pdf`,
  /// `pdf_encrypted`, `pdf_no_pages`, `pdf_damaged`) when it cannot.
  static PdfReader open(Uint8List bytes) {
    final r = PdfReader._(bytes);
    try {
      r._open();
    } on FormatException {
      rethrow;
    } on Object {
      // the readers' bounds tripped by a damaged file
      throw const FormatException('pdf_damaged');
    }
    return r;
  }

  final Uint8List _b;
  final Map<int, _XrefEntry> _xref = {};
  Map<String, Object?> _trailer = {};
  final Map<int, Object?> _objects = {};
  final Set<int> _loading = {};
  final Map<int, _ObjStm?> _objStms = {};
  bool _rebuilt = false;

  /// Set while the cross-reference sections are read: a missing object
  /// then does not start a rebuild (the sections still to come may have it).
  bool _readingXref = false;
  int _headerOffset = 0;

  /// Streams that could not be decoded completely (damaged, cut short).
  int _damagedStreams = 0;

  /// Bytes the current reading may still inflate.
  int _budget = _maxPageBytes;

  final List<_Page> _pages = [];

  /// Notes about the file itself (`pdf_xref_rebuilt`).
  final List<String> warnings = [];

  /// The pages, in document order.
  List<PdfPageInfo> get pages => [for (final p in _pages) p.info];
  int get pageCount => _pages.length;

  /// Every layer (optional content group) of the document.
  late final List<PdfLayerInfo> layers = _documentLayers();

  /// The content of page [index]: paths ([vectors]), texts ([texts]) and
  /// images. Images are always listed (their corners) but their pixels are
  /// only decoded with [images], which can take a while for scans.
  PdfPageContent readPage(int index, {bool vectors = true, bool texts = true, bool images = true, int maxSegments = pdfMaxSegments}) {
    final page = _pages[index];
    final it = _Interp(this, page, vectors: vectors, texts: texts, images: images, maxSegments: maxSegments);
    final damagedBefore = _damagedStreams;
    _budget = _maxPageBytes;
    try {
      it.runPage();
    } on _TooLarge {
      it.warnings.add('pdf_too_large');
    } on _Stop {
      it.truncated = true;
    } on Object {
      it.warnings.add('pdf_stream_damaged');
    }
    it.flushRun();
    if (_damagedStreams > damagedBefore) it.warnings.add('pdf_stream_damaged');
    if (it.truncated) it.warnings.add('pdf_truncated:$maxSegments');
    return PdfPageContent(
      page: page.info,
      paths: it.paths,
      texts: it.textItems,
      images: it.imageItems,
      layers: [for (final e in it.layersUsed.entries) PdfLayerInfo(e.key, visible: e.value)],
      warnings: [...warnings, ...it.warnings],
      truncated: it.truncated,
    );
  }

  // ------------------------------------------------------------ structure

  void _open() {
    final b = _b;
    _headerOffset = _indexOf(b, '%PDF-', 0, math.min(b.length, 1024));
    if (_headerOffset < 0) {
      // no header: a PDF only if objects are there ("1 0 obj")
      if (!RegExp(r'\d+\s+\d+\s+obj\b').hasMatch(latin1.decode(Uint8List.sublistView(b, 0, math.min(b.length, 4096))))) throw const FormatException('pdf_not_pdf');
      _headerOffset = 0;
    }
    try {
      _readingXref = true;
      _readXref();
    } on FormatException {
      rethrow;
    } on Object {
      _xref.clear();
    } finally {
      _readingXref = false;
    }
    if (_dict(_trailer['Root']) == null && !_rebuilt) _rebuildXref();
    if (_trailer['Encrypt'] != null) throw const FormatException('pdf_encrypted');
    _loadPages();
    if (_pages.isEmpty && !_rebuilt) {
      _rebuildXref();
      if (_trailer['Encrypt'] != null) throw const FormatException('pdf_encrypted');
      _loadPages();
    }
    if (_pages.isEmpty) throw const FormatException('pdf_no_pages');
  }

  /// Follows startxref and the /Prev chain, newest section first.
  void _readXref() {
    final b = _b;
    var sx = _lastIndexOf(b, 'startxref', math.max(0, b.length - 4096));
    if (sx < 0) sx = _lastIndexOf(b, 'startxref', 0);
    if (sx < 0) {
      _readingXref = false;
      _rebuildXref();
      return;
    }
    final first = _Parser(b, sx + 9).parse(0, false);
    var next = first is int ? first : -1;
    final seen = <int>{};
    var newest = true;
    while (next >= 0 && seen.add(next) && seen.length < 1000) {
      var t = _readXrefSection(next);
      if (t == null && _headerOffset > 0) t = _readXrefSection(next + _headerOffset);
      if (t == null) {
        // startxref points nowhere: the file was edited or cut
        _readingXref = false;
        if (newest) _rebuildXref();
        return;
      }
      for (final e in t.entries) {
        _trailer.putIfAbsent(e.key, () => e.value);
      }
      newest = false;
      final stm = t['XRefStm'];
      if (stm is int) _readXrefStream(stm);
      final prev = t['Prev'];
      next = prev is num ? prev.toInt() : -1;
    }
  }

  /// Reads the table or cross-reference stream at [off]: its trailer, or
  /// null when nothing of the kind is there.
  Map<String, Object?>? _readXrefSection(int off) {
    if (off < 0 || off >= _b.length) return null;
    final p = _Parser(_b, off);
    p.skipWs();
    if (p.lookingAt('xref')) {
      p.pos += 4;
      while (true) {
        p.skipWs();
        if (p.atEnd) return null;
        if (p.lookingAt('trailer')) {
          p.pos += 7;
          final t = p.parse();
          return t is Map<String, Object?> ? t : null;
        }
        final start = p.parse(0, false), count = p.parse(0, false);
        if (start is! int || count is! int || count < 0) return null;
        var s = start;
        for (var i = 0; i < count; i++) {
          final o = p.parse(0, false), g = p.parse(0, false), k = p.parse(0, false);
          if (o is! num || g is! num || k is! _Kw) return null;
          // a subsection numbered from 1 whose first entry is the head of
          // the free list: a writer's off-by-one, the table starts at 0
          if (i == 0 && s == 1 && k.v == 'f' && g == 65535) s = 0;
          if (k.v == 'n' && o > 0) _xref.putIfAbsent(s + i, () => _XrefEntry(1, o.toInt(), g.toInt()));
        }
      }
    }
    final o = _objectAt(off, null);
    if (o is! _Stream || _nameOf(o.dict['Type']) != 'XRef') return null;
    _xrefStreamEntries(o);
    return o.dict;
  }

  void _readXrefStream(int off) {
    final o = _objectAt(off, null);
    if (o is _Stream) _xrefStreamEntries(o);
  }

  void _xrefStreamEntries(_Stream s) {
    final w = [for (final v in _numbers(s.dict['W']) ?? const <double>[]) v.toInt()];
    if (w.length < 3 || w.any((v) => v < 0 || v > 8)) return;
    final index = [
      for (final v in _numbers(s.dict['Index']) ?? [0, _num(s.dict['Size']) ?? 0]) v.toInt(),
    ];
    final data = _decodeStream(s);
    final rec = w[0] + w[1] + w[2];
    if (rec == 0) return;
    var p = 0;
    int field(int n) {
      var v = 0;
      for (var i = 0; i < n; i++) {
        v = v * 256 + data[p++];
      }
      return v;
    }

    for (var k = 0; k + 1 < index.length; k += 2) {
      final start = index[k], count = index[k + 1];
      for (var i = 0; i < count && p + rec <= data.length; i++) {
        final type = w[0] == 0 ? 1 : field(w[0]);
        final a = field(w[1]);
        final b = field(w[2]);
        if (type == 1 || type == 2) _xref.putIfAbsent(start + i, () => _XrefEntry(type, a, b));
      }
    }
  }

  /// Rebuilds the cross-reference from the objects found in the file (the
  /// last definition of a number wins) and the trailers or cross-reference
  /// streams met on the way.
  void _rebuildXref() {
    _rebuilt = true;
    warnings.add('pdf_xref_rebuilt');
    final b = _b;
    final n = b.length;
    final found = <int, (int, int)>{};
    var i = 0;
    while (true) {
      i = _indexOf(b, 'obj', i, n);
      if (i < 0) break;
      final at = i;
      i += 3;
      if (at + 3 < n && _cls[b[at + 3]] == 0) continue; // "object", "objects"
      var j = at - 1;
      while (j >= 0 && _cls[b[j]] == 1) {
        j--;
      }
      final genEnd = j + 1;
      while (j >= 0 && b[j] >= 0x30 && b[j] <= 0x39) {
        j--;
      }
      final genStart = j + 1;
      if (genStart == genEnd || genEnd - genStart > 5) continue;
      final ws = j;
      while (j >= 0 && _cls[b[j]] == 1) {
        j--;
      }
      if (j == ws) continue;
      final numEnd = j + 1;
      while (j >= 0 && b[j] >= 0x30 && b[j] <= 0x39) {
        j--;
      }
      final numStart = j + 1;
      if (numStart == numEnd || numEnd - numStart > 10 || (j >= 0 && _cls[b[j]] == 0)) continue;
      final num = int.parse(String.fromCharCodes(b, numStart, numEnd));
      final gen = int.parse(String.fromCharCodes(b, genStart, genEnd));
      found[num] = (numStart, gen);
    }
    Map<String, Object?>? trailer;
    var t = 0;
    while ((t = _indexOf(b, 'trailer', t, n)) >= 0) {
      t += 7;
      try {
        final d = _Parser(b, t).parse();
        if (d is Map<String, Object?>) trailer = {...?trailer, ...d};
      } on Object {
        // a damaged trailer: the next one may do
      }
    }
    _xref.clear();
    _objects.clear();
    _objStms.clear();
    for (final e in found.entries) {
      _xref[e.key] = _XrefEntry(1, e.value.$1, e.value.$2);
    }
    // object streams and cross-reference streams (their dictionaries are
    // looked at only when the type shows near the start of the object)
    Map<String, Object?>? xrefTrailer;
    int? catalog;
    for (final e in found.entries) {
      final head = String.fromCharCodes(b, e.value.$1, math.min(n, e.value.$1 + 400));
      final objStm = head.contains('/ObjStm'), xrefStm = head.contains('/XRef'), cat = head.contains('/Catalog');
      if (!objStm && !xrefStm && !cat) continue;
      final o = _get(e.key);
      final d = o is _Stream ? o.dict : (o is Map<String, Object?> ? o : null);
      final type = _nameOf(d?['Type']);
      if (type == 'Catalog') catalog = e.key;
      if (o is _Stream && type == 'XRef') xrefTrailer = {...?xrefTrailer, ...o.dict};
      if (o is _Stream && type == 'ObjStm') {
        final s = _objStm(e.key);
        if (s == null) continue;
        for (var k = 0; k < s.nums.length; k++) {
          _xref.putIfAbsent(s.nums[k], () => _XrefEntry(2, e.key, k));
        }
      }
    }
    final tr = <String, Object?>{...?xrefTrailer, ...?trailer};
    if (_dict(tr['Root']) == null) {
      if (catalog != null) {
        tr['Root'] = _Ref(catalog, 0);
      } else {
        // the catalog may sit in an object stream
        for (final e in _xref.entries) {
          if (e.value.type != 2) continue;
          final d = _dict(_get(e.key));
          if (_nameOf(d?['Type']) == 'Catalog') {
            tr['Root'] = _Ref(e.key, 0);
            break;
          }
        }
      }
    }
    _trailer = tr;
  }

  // ------------------------------------------------------------ objects

  /// Object [n] (null when missing or unreadable).
  Object? _get(int n) {
    if (_objects.containsKey(n)) return _objects[n];
    if (!_loading.add(n)) return null; // a reference loop (a /Length pointing at its own stream)
    try {
      final v = _load(n, true);
      _objects[n] = v;
      return v;
    } on _TooLarge {
      rethrow;
    } on Object {
      _objects[n] = null;
      return null;
    } finally {
      _loading.remove(n);
    }
  }

  Object? _load(int n, bool mayRebuild) {
    final e = _xref[n];
    if (e == null) return null;
    if (e.type == 2) return _fromObjStm(e.a, e.b, n);
    var v = _objectAt(e.a, n);
    if (identical(v, _bad) && _headerOffset > 0) v = _objectAt(e.a + _headerOffset, n);
    if (identical(v, _bad) && mayRebuild && !_rebuilt && !_readingXref) {
      // the table points beside the objects: find them again
      _rebuildXref();
      return _load(n, false);
    }
    return identical(v, _bad) ? null : v;
  }

  /// `n g obj … endobj` at [off] (its number checked against [expect]), or
  /// [_bad] when something else is there.
  Object? _objectAt(int off, int? expect) {
    if (off < 0 || off >= _b.length) return _bad;
    final p = _Parser(_b, off);
    final num = p.parse(0, false), gen = p.parse(0, false), kw = p.parse(0, false);
    if (num is! int || gen is! int || kw is! _Kw || kw.v != 'obj') return _bad;
    if (expect != null && num != expect) return _bad;
    final v = p.parse();
    p.skipWs();
    if (v is Map<String, Object?> && p.lookingAt('stream')) return _streamAt(p, v, num);
    return v is _Kw ? null : v;
  }

  _Stream _streamAt(_Parser p, Map<String, Object?> dict, int num) {
    final b = _b;
    p.pos += 6;
    // the keyword ends with CR LF or LF (a lone CR, or spaces before the
    // EOL, from careless writers)
    while (p.pos < b.length && b[p.pos] == 0x20) {
      p.pos++;
    }
    if (p.pos < b.length && b[p.pos] == 0x0D) p.pos++;
    if (p.pos < b.length && b[p.pos] == 0x0A) p.pos++;
    final start = p.pos;
    final len = _num(dict['Length'])?.toInt() ?? -1;
    var end = -1;
    if (len >= 0 && start + len <= b.length) {
      // the length is right when endstream follows
      final q = _Parser(b, start + len)..skipWs();
      if (q.lookingAt('endstream')) end = start + len;
    }
    if (end < 0) {
      final e = _indexOf(b, 'endstream', start, b.length);
      end = e < 0 ? b.length : e;
      if (end > start && b[end - 1] == 0x0A) end--;
      if (end > start && b[end - 1] == 0x0D) end--;
    }
    return _Stream(dict, Uint8List.sublistView(b, start, end), num);
  }

  Object? _fromObjStm(int stm, int index, int n) {
    final s = _objStm(stm);
    if (s == null) return null;
    var k = index < s.nums.length && s.nums[index] == n ? index : s.nums.indexOf(n);
    if (k < 0) return null;
    final p = _Parser(s.data, s.first + s.offs[k]);
    final v = p.parse();
    return v is _Kw ? null : v;
  }

  _ObjStm? _objStm(int n) {
    if (_objStms.containsKey(n)) return _objStms[n];
    _objStms[n] = null; // a stream that holds itself
    final o = _get(n);
    if (o is! _Stream) return null;
    final count = _num(o.dict['N'])?.toInt() ?? 0;
    final first = _num(o.dict['First'])?.toInt() ?? 0;
    final data = _decodeStream(o);
    final p = _Parser(data);
    final nums = <int>[], offs = <int>[];
    for (var i = 0; i < count; i++) {
      final a = p.parse(0, false), b = p.parse(0, false);
      if (a is! int || b is! int) break;
      nums.add(a);
      offs.add(b);
    }
    return _objStms[n] = _ObjStm(data, first, nums, offs);
  }

  /// [o] with references followed.
  Object? _resolve(Object? o) {
    var v = o;
    for (var i = 0; v is _Ref && i < 32; i++) {
      v = _get(v.n);
    }
    return v is _Ref ? null : v;
  }

  Map<String, Object?>? _dict(Object? o) {
    final v = _resolve(o);
    if (v is Map<String, Object?>) return v;
    if (v is _Stream) return v.dict;
    return null;
  }

  List<Object?>? _array(Object? o) {
    final v = _resolve(o);
    return v is List<Object?> ? v : null;
  }

  double? _num(Object? o) {
    final v = _resolve(o);
    return v is num ? v.toDouble() : null;
  }

  int? _int(Object? o) => _num(o)?.round();

  String? _name(Object? o) => _nameOf(_resolve(o));

  bool? _bool(Object? o) {
    final v = _resolve(o);
    return v is bool ? v : null;
  }

  List<double>? _numbers(Object? o) {
    final a = _array(o);
    if (a == null) return null;
    final out = <double>[];
    for (final v in a) {
      final x = _num(v);
      if (x == null) return null;
      out.add(x);
    }
    return out;
  }

  // ------------------------------------------------------------ streams

  /// The filters of a stream or image (abbreviations of inline images
  /// expanded) and their parameters.
  (List<String>, List<Map<String, Object?>?>) _filters(Map<String, Object?> d) {
    final f = _resolve(d['Filter']);
    final p = _resolve(d['DecodeParms']);
    final names = <String>[
      if (f is _Name) _filterName(f.v),
      if (f is List)
        for (final e in f) _filterName(_name(e) ?? ''),
    ];
    final parms = <Map<String, Object?>?>[for (var i = 0; i < names.length; i++) p is List ? (i < p.length ? _dict(p[i]) : null) : (i == 0 ? _dict(p) : null)];
    return (names, parms);
  }

  /// The decoded data of stream [s] (every filter applied; a damaged
  /// stream gives what could be decoded).
  Uint8List _decodeStream(_Stream s) {
    final (names, parms) = _filters(s.dict);
    var data = s.raw;
    for (var i = 0; i < names.length; i++) {
      data = _filter(names[i], data, parms[i]);
    }
    return data;
  }

  Uint8List _filter(String name, Uint8List data, Map<String, Object?>? parms) {
    switch (name) {
      case 'FlateDecode':
        return _predict(_inflate(data), parms);
      case 'LZWDecode':
        return _predict(_lzw(data, _int(parms?['EarlyChange']) ?? 1), parms);
      case 'ASCIIHexDecode':
        return _asciiHex(data);
      case 'ASCII85Decode':
        return _ascii85(data);
      case 'RunLengthDecode':
        return _runLength(data);
      case 'Crypt':
        return data; // the identity crypt filter (encrypted files are refused)
      default:
        throw _Unsupported(name);
    }
  }

  Uint8List _inflate(Uint8List data) {
    var start = 0;
    // the zlib header (a few writers leave it out: raw deflate)
    if (data.length >= 2 && (data[0] & 0x0F) == 8 && (data[0] * 256 + data[1]) % 31 == 0) start = (data[1] & 0x20) != 0 ? 6 : 2;
    final out = _CappedOutput();
    try {
      Inflate(Uint8List.sublistView(data, math.min(start, data.length)), output: out);
    } on _TooLarge {
      rethrow;
    } on Object {
      // damaged or cut short: what was decoded so far
      _damagedStreams++;
    }
    _budget -= out.length;
    if (_budget < 0) throw const _TooLarge();
    return out.getBytes();
  }

  Uint8List _predict(Uint8List data, Map<String, Object?>? parms) {
    final pred = _int(parms?['Predictor']) ?? 1;
    if (pred <= 1) return data;
    final colors = math.max(1, _int(parms?['Colors']) ?? 1);
    final bpc = math.max(1, _int(parms?['BitsPerComponent']) ?? 8);
    final columns = math.max(1, _int(parms?['Columns']) ?? 1);
    final rowBytes = (colors * bpc * columns + 7) ~/ 8;
    final bpp = math.max(1, (colors * bpc + 7) ~/ 8);
    if (pred == 2) {
      // TIFF: each sample minus the one to its left (8 and 16 bits)
      final out = Uint8List.fromList(data);
      for (var row = 0; row + rowBytes <= out.length; row += rowBytes) {
        if (bpc == 8) {
          for (var i = colors; i < rowBytes; i++) {
            out[row + i] = (out[row + i] + out[row + i - colors]) & 0xFF;
          }
        } else if (bpc == 16) {
          for (var i = 2 * colors; i + 1 < rowBytes; i += 2) {
            final v = ((out[row + i] << 8) | out[row + i + 1]) + ((out[row + i - 2 * colors] << 8) | out[row + i - 2 * colors + 1]);
            out[row + i] = (v >> 8) & 0xFF;
            out[row + i + 1] = v & 0xFF;
          }
        }
      }
      return out;
    }
    // PNG: a filter type byte before each row
    final rows = (data.length + rowBytes) ~/ (rowBytes + 1);
    final out = Uint8List(rows * rowBytes);
    for (var r = 0; r < rows; r++) {
      final src = r * (rowBytes + 1);
      if (src >= data.length) break;
      final type = data[src];
      final dst = r * rowBytes;
      final avail = math.min(rowBytes, data.length - src - 1);
      for (var i = 0; i < avail; i++) {
        final raw = data[src + 1 + i];
        final left = i >= bpp ? out[dst + i - bpp] : 0;
        final up = r > 0 ? out[dst - rowBytes + i] : 0;
        final upLeft = r > 0 && i >= bpp ? out[dst - rowBytes + i - bpp] : 0;
        final v = switch (type) {
          1 => raw + left,
          2 => raw + up,
          3 => raw + ((left + up) >> 1),
          4 => raw + _paeth(left, up, upLeft),
          _ => raw,
        };
        out[dst + i] = v & 0xFF;
      }
    }
    return out;
  }

  // ------------------------------------------------------------ pages

  void _loadPages() {
    _pages.clear();
    final root = _dict(_trailer['Root']);
    final seen = <Object>{};
    void walk(Object? node, Map<String, Object?> inherited, int depth) {
      if (depth > 64 || _pages.length >= 100000) return;
      if (node is _Ref && !seen.add(node.n)) return;
      final d = _dict(node);
      if (d == null || (node is! _Ref && !seen.add(d))) return;
      final inh = {...inherited};
      for (final k in const ['Resources', 'MediaBox', 'CropBox', 'Rotate']) {
        if (d[k] != null) inh[k] = d[k];
      }
      final type = _nameOf(_resolve(d['Type']));
      final kids = _array(d['Kids']);
      if (kids != null && type != 'Page') {
        for (final k in kids) {
          walk(k, inh, depth + 1);
        }
        return;
      }
      if (type == 'Pages') return; // a node without kids
      if (type == 'Page' || d.containsKey('Contents') || d.containsKey('MediaBox')) _addPage(d, inh);
    }

    walk(root?['Pages'], const {}, 0);
    if (_pages.isNotEmpty) return;
    // a broken page tree: every page object in number order
    for (final n in (_xref.keys.toList()..sort())) {
      final d = _dict(_get(n));
      if (d == null || _nameOf(_resolve(d['Type'])) != 'Page') continue;
      _addPage(d, {
        for (final k in const ['Resources', 'MediaBox', 'CropBox', 'Rotate'])
          if (d[k] != null) k: d[k],
      });
    }
  }

  void _addPage(Map<String, Object?> d, Map<String, Object?> inh) {
    List<double>? box(Object? o) {
      final v = _numbers(o);
      if (v == null || v.length < 4 || v.any((x) => !x.isFinite)) return null;
      final r = [math.min(v[0], v[2]), math.min(v[1], v[3]), math.max(v[0], v[2]), math.max(v[1], v[3])];
      return r[2] - r[0] > 0 && r[3] - r[1] > 0 ? r : null;
    }

    final media = box(inh['MediaBox']) ?? const [0.0, 0.0, 612.0, 792.0];
    var crop = box(inh['CropBox']) ?? media;
    // what shows is the crop box inside the media box
    final clip = [math.max(crop[0], media[0]), math.max(crop[1], media[1]), math.min(crop[2], media[2]), math.min(crop[3], media[3])];
    crop = clip[2] > clip[0] && clip[3] > clip[1] ? clip : media;
    final rot = ((((_num(inh['Rotate']) ?? 0) / 90).round() * 90) % 360 + 360) % 360;
    final uu = _num(d['UserUnit']) ?? 1;
    final unit = uu > 0 && uu.isFinite ? uu : 1.0;
    final w = crop[2] - crop[0], h = crop[3] - crop[1];
    final x0 = crop[0], y0 = crop[1];
    // user space → shown page: crop box origin at (0, 0), turned clockwise by /Rotate
    final base = switch (rot) {
      90 => Affine(0, -1, 1, 0, -y0, w + x0),
      180 => Affine(-1, 0, 0, -1, w + x0, h + y0),
      270 => Affine(0, 1, -1, 0, h + y0, -x0),
      _ => Affine(1, 0, 0, 1, -x0, -y0),
    }.then(Affine.scaling(unit));
    final turned = rot == 90 || rot == 270;
    final info = PdfPageInfo(index: _pages.length, width: (turned ? h : w) * unit, height: (turned ? w : h) * unit, rotation: rot, userUnit: unit);
    _pages.add(_Page(d, _dict(inh['Resources']), base, info));
  }

  // ------------------------------------------------------------ layers

  late final Map<String, Object?>? _ocProps = _dict(_dict(_trailer['Root'])?['OCProperties']);

  /// Object numbers of the groups that are off in the default configuration.
  late final Set<int> _ocOff = () {
    final d = _dict(_ocProps?['D']);
    final off = <int>{};
    if (d == null) return off;
    final on = {
      for (final r in _array(d['ON']) ?? const [])
        if (r is _Ref) r.n,
    };
    if (_name(d['BaseState']) == 'OFF') {
      for (final r in _array(_ocProps?['OCGs']) ?? const []) {
        if (r is _Ref && !on.contains(r.n)) off.add(r.n);
      }
    }
    for (final r in _array(d['OFF']) ?? const []) {
      if (r is _Ref) off.add(r.n);
    }
    return off;
  }();

  final Map<int, _Oc?> _ocCache = {};

  List<PdfLayerInfo> _documentLayers() {
    final out = <PdfLayerInfo>[];
    final names = <String>{};
    for (final r in _array(_ocProps?['OCGs']) ?? const []) {
      final oc = _ocOf(r);
      if (oc != null && names.add(oc.name)) out.add(PdfLayerInfo(oc.name, visible: oc.visible));
    }
    return out;
  }

  /// The layer an /OC entry (a group or a membership dictionary) stands for.
  _Oc? _ocOf(Object? o, [int depth = 0]) {
    if (depth > 8) return null;
    final n = o is _Ref ? o.n : null;
    if (n != null && _ocCache.containsKey(n)) return _ocCache[n];
    final d = _dict(o);
    _Oc? out;
    if (d != null) {
      if (_name(d['Type']) == 'OCMD') {
        final m = _resolve(d['OCGs']);
        final members = [
          for (final g in (m is List ? m : [if (m != null) d['OCGs']])) ?_ocOf(g, depth + 1),
        ];
        if (members.isNotEmpty) {
          final visible = switch (_name(d['P'])) {
            'AllOn' => members.every((g) => g.visible),
            'AnyOff' => members.any((g) => !g.visible),
            'AllOff' => members.every((g) => !g.visible),
            _ => members.any((g) => g.visible),
          };
          out = _Oc(members.first.name, visible);
        }
      } else {
        final name = _textString(_resolve(d['Name'])).trim();
        out = _Oc(name.isEmpty ? 'OC${n ?? ''}' : name, n == null || !_ocOff.contains(n));
      }
    }
    if (n != null) _ocCache[n] = out;
    return out;
  }
}

// ---------------------------------------------------------------- model

class _Page {
  _Page(this.dict, this.resources, this.base, this.info);
  final Map<String, Object?> dict;
  final Map<String, Object?>? resources;

  /// User space → shown page space.
  final Affine base;
  final PdfPageInfo info;
}

class _XrefEntry {
  const _XrefEntry(this.type, this.a, this.b);

  /// 1: at offset [a] with generation [b]; 2: object [b] of object stream [a].
  final int type;
  final int a, b;
}

class _ObjStm {
  _ObjStm(this.data, this.first, this.nums, this.offs);
  final Uint8List data;
  final int first;
  final List<int> nums, offs;
}

/// A layer: its name and whether it shows by default.
class _Oc {
  const _Oc(this.name, this.visible);
  final String name;
  final bool visible;
}

class _Name {
  const _Name(this.v);
  final String v;
  @override
  bool operator ==(Object other) => other is _Name && other.v == v;
  @override
  int get hashCode => v.hashCode;
  @override
  String toString() => '/$v';
}

class _Ref {
  const _Ref(this.n, this.g);
  final int n, g;
}

/// A string object (literal or hexadecimal): its bytes.
class _Str {
  const _Str(this.b);
  final Uint8List b;
}

/// A keyword met where an object was expected (`endobj`, an operator…).
class _Kw {
  const _Kw(this.v);
  final String v;
}

class _Stream {
  _Stream(this.dict, this.raw, this.id);
  final Map<String, Object?> dict;

  /// The encoded data (a view into the file).
  final Uint8List raw;

  /// Object number.
  final int id;
}

/// Marks a position where the expected object was not found.
const _bad = _Kw('\u0000bad');

class _Eof implements Exception {
  const _Eof();
}

class _TooLarge implements Exception {
  const _TooLarge();
}

/// The operator limit of a page was reached.
class _Stop implements Exception {
  const _Stop();
}

class _Unsupported implements Exception {
  const _Unsupported(this.filter);
  final String filter;
}

String? _nameOf(Object? o) => o is _Name ? o.v : null;

String _filterName(String n) => switch (n) {
  'AHx' => 'ASCIIHexDecode',
  'A85' => 'ASCII85Decode',
  'LZW' => 'LZWDecode',
  'Fl' => 'FlateDecode',
  'RL' => 'RunLengthDecode',
  'CCF' => 'CCITTFaxDecode',
  'DCT' => 'DCTDecode',
  _ => n,
};

/// A text string (7.9.2.2): UTF-16BE or UTF-8 with a byte order mark, else
/// PDFDocEncoding.
String _textString(Object? o) {
  if (o is! _Str) return o is _Name ? o.v : '';
  final b = o.b;
  if (b.length >= 2 && b[0] == 0xFE && b[1] == 0xFF) {
    final units = [for (var i = 2; i + 1 < b.length; i += 2) (b[i] << 8) | b[i + 1]];
    return String.fromCharCodes(units);
  }
  if (b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) return utf8.decode(b.sublist(3), allowMalformed: true);
  return String.fromCharCodes([for (final c in b) c >= 0x80 && c <= 0xA0 ? _pdfDocHigh[c - 0x80] : c]);
}

/// PDFDocEncoding 0x80–0xA0 (annex D.2).
const _pdfDocHigh = [
  0x2022, 0x2020, 0x2021, 0x2026, 0x2014, 0x2013, 0x0192, 0x2044, 0x2039, 0x203A, 0x2212, 0x2030, 0x201E, 0x201C, 0x201D, 0x2018, //
  0x2019, 0x201A, 0x2122, 0xFB01, 0xFB02, 0x0141, 0x0152, 0x0160, 0x0178, 0x017D, 0x0131, 0x0142, 0x0153, 0x0161, 0x017E, 0xFFFD, 0x20AC,
];

int _paeth(int a, int b, int c) {
  final p = a + b - c;
  final pa = (p - a).abs(), pb = (p - b).abs(), pc = (p - c).abs();
  if (pa <= pb && pa <= pc) return a;
  return pb <= pc ? b : c;
}

/// First index of the ASCII [word] in [b] within [from, to), or −1.
int _indexOf(Uint8List b, String word, int from, int to) {
  final n = word.length;
  final c0 = word.codeUnitAt(0);
  final end = math.min(to, b.length) - n;
  outer:
  for (var i = math.max(0, from); i <= end; i++) {
    if (b[i] != c0) continue;
    for (var k = 1; k < n; k++) {
      if (b[i + k] != word.codeUnitAt(k)) continue outer;
    }
    return i;
  }
  return -1;
}

/// Last index of the ASCII [word] in [b] at or after [from], or −1.
int _lastIndexOf(Uint8List b, String word, int from) {
  final n = word.length;
  outer:
  for (var i = b.length - n; i >= from; i--) {
    for (var k = 0; k < n; k++) {
      if (b[i + k] != word.codeUnitAt(k)) continue outer;
    }
    return i;
  }
  return -1;
}

// ---------------------------------------------------------------- filters

/// Output of the inflater that refuses to grow past [_maxStreamBytes].
class _CappedOutput extends OutputMemoryStream {
  _CappedOutput() : super(size: 1 << 16);

  @override
  void writeByte(int value) {
    if (length >= _maxStreamBytes) throw const _TooLarge();
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    if (this.length + (length ?? bytes.length) > _maxStreamBytes) throw const _TooLarge();
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    if (length + stream.length > _maxStreamBytes) throw const _TooLarge();
    super.writeStream(stream);
  }

  @override
  void writeBackReference(int distance, int count) {
    if (length + count > _maxStreamBytes) throw const _TooLarge();
    super.writeBackReference(distance, count);
  }
}

/// Growable byte buffer.
class _Bytes {
  Uint8List _buf = Uint8List(1024);
  int length = 0;

  void add(int v) {
    if (length == _buf.length) _grow(1);
    _buf[length++] = v;
  }

  void addAll(Uint8List src, int start, int end) {
    final n = end - start;
    if (n <= 0) return;
    if (length + n > _buf.length) _grow(n);
    _buf.setRange(length, length + n, src, start);
    length += n;
  }

  void _grow(int need) {
    if (length + need > _maxStreamBytes) throw const _TooLarge();
    final b = Uint8List(math.max(_buf.length * 2, length + need));
    b.setRange(0, length, _buf);
    _buf = b;
  }

  Uint8List take() => Uint8List.sublistView(_buf, 0, length);
}

/// LZWDecode (7.4.4): 9 to 12-bit codes, 256 clears the table, 257 ends;
/// [early] 1 widens the codes one entry early, as most writers do.
Uint8List _lzw(Uint8List d, int early) {
  final out = _Bytes();
  final prefix = Int32List(4096), suffix = Uint8List(4096), first = Uint8List(4096);
  for (var i = 0; i < 256; i++) {
    prefix[i] = -1;
    suffix[i] = i;
    first[i] = i;
  }
  final stack = Uint8List(4096);
  var next = 258, width = 9, prev = -1;
  var buf = 0, bits = 0, pos = 0;
  while (true) {
    while (bits < width && pos < d.length) {
      buf = (buf << 8) | d[pos++];
      bits += 8;
    }
    if (bits < width) break;
    final code = (buf >> (bits - width)) & ((1 << width) - 1);
    bits -= width;
    buf &= (1 << bits) - 1;
    if (code == 256) {
      next = 258;
      width = 9;
      prev = -1;
      continue;
    }
    if (code == 257) break;
    if (prev < 0) {
      if (code > 255) break;
      out.add(code);
      prev = code;
      continue;
    }
    if (code > next) break; // damaged
    // the string of the code (for code == next: the previous string plus its first byte)
    var c = code == next ? prev : code;
    var sp = 0;
    while (c >= 0 && sp < stack.length) {
      stack[sp++] = suffix[c];
      c = prefix[c];
    }
    for (var i = sp - 1; i >= 0; i--) {
      out.add(stack[i]);
    }
    if (code == next) out.add(first[prev]);
    if (next < 4096) {
      prefix[next] = prev;
      suffix[next] = code == next ? first[prev] : first[code];
      first[next] = first[prev];
      next++;
    }
    prev = code;
    if (next + early >= (1 << width) && width < 12) width++;
  }
  return out.take();
}

Uint8List _asciiHex(Uint8List d) {
  final out = _Bytes();
  var hi = -1;
  for (final c in d) {
    if (c == 0x3E) break;
    final v = _hexValue(c);
    if (v < 0) continue;
    if (hi < 0) {
      hi = v;
    } else {
      out.add((hi << 4) | v);
      hi = -1;
    }
  }
  if (hi >= 0) out.add(hi << 4);
  return out.take();
}

Uint8List _ascii85(Uint8List d) {
  final out = _Bytes();
  var i = d.length >= 2 && d[0] == 0x3C && d[1] == 0x7E ? 2 : 0;
  var n = 0, acc = 0;
  void emit(int value, int count) {
    // arithmetic, not shifts: the value may not fit 32 bits on the web
    final b0 = value ~/ 16777216 % 256, b1 = value ~/ 65536 % 256, b2 = value ~/ 256 % 256, b3 = value % 256;
    final bytes = [b0, b1, b2, b3];
    for (var k = 0; k < count; k++) {
      out.add(bytes[k]);
    }
  }

  for (; i < d.length; i++) {
    final c = d[i];
    if (c == 0x7E) break;
    if (c == 0x7A && n == 0) {
      emit(0, 4);
      continue;
    }
    if (c < 0x21 || c > 0x75) continue;
    acc = acc * 85 + (c - 33);
    if (++n == 5) {
      emit(acc, 4);
      n = 0;
      acc = 0;
    }
  }
  if (n > 1) {
    for (var k = n; k < 5; k++) {
      acc = acc * 85 + 84;
    }
    emit(acc, n - 1);
  }
  return out.take();
}

Uint8List _runLength(Uint8List d) {
  final out = _Bytes();
  var i = 0;
  while (i < d.length) {
    final len = d[i++];
    if (len == 128) break;
    if (len < 128) {
      final end = math.min(d.length, i + len + 1);
      out.addAll(d, i, end);
      i = end;
    } else {
      if (i >= d.length) break;
      final v = d[i++];
      for (var k = 0; k < 257 - len; k++) {
        out.add(v);
      }
    }
  }
  return out.take();
}

int _hexValue(int c) {
  if (c >= 0x30 && c <= 0x39) return c - 0x30;
  if (c >= 0x41 && c <= 0x46) return c - 0x37;
  if (c >= 0x61 && c <= 0x66) return c - 0x57;
  return -1;
}

// ---------------------------------------------------------------- lexer

/// Byte classes: 1 white-space, 2 delimiter, 0 regular character.
final Uint8List _cls = () {
  final t = Uint8List(256);
  for (final c in const [0, 9, 10, 12, 13, 32]) {
    t[c] = 1;
  }
  for (final c in '()<>[]{}/%'.codeUnits) {
    t[c] = 2;
  }
  return t;
}();

bool _structural(String kw) => kw == 'endobj' || kw == 'stream' || kw == 'endstream' || kw == 'obj' || kw == 'xref' || kw == 'trailer' || kw == 'startxref' || kw == '>';

/// Tokeniser and object parser over a byte buffer (file objects, content
/// stream operands, CMaps).
class _Parser {
  _Parser(this.b, [this.pos = 0]);
  final Uint8List b;
  int pos;

  bool get atEnd => pos >= b.length;

  void skipWs() {
    final n = b.length;
    while (pos < n) {
      final c = b[pos];
      if (_cls[c] == 1) {
        pos++;
      } else if (c == 0x25) {
        while (pos < n && b[pos] != 0x0A && b[pos] != 0x0D) {
          pos++;
        }
      } else {
        break;
      }
    }
  }

  /// Whether the token [word] starts at the current position.
  bool lookingAt(String word) {
    final n = word.length;
    if (pos + n > b.length) return false;
    for (var i = 0; i < n; i++) {
      if (b[pos + i] != word.codeUnitAt(i)) return false;
    }
    return pos + n == b.length || _cls[b[pos + n]] != 0;
  }

  /// The next object; with [refs], `n g R` reads as a reference (file
  /// objects; content streams have none).
  Object? parse([int depth = 0, bool refs = true]) {
    skipWs();
    if (pos >= b.length) throw const _Eof();
    final c = b[pos];
    switch (c) {
      case 0x2F:
        return _Name(readName());
      case 0x28:
        return _Str(readLiteral());
      case 0x3C:
        if (pos + 1 < b.length && b[pos + 1] == 0x3C) {
          pos += 2;
          return readDict(depth, refs);
        }
        return _Str(readHex());
      case 0x5B:
        pos++;
        return readArray(depth, refs);
      case 0x5D || 0x29 || 0x7B || 0x7D:
        pos++;
        return _Kw(String.fromCharCode(c));
      case 0x3E:
        pos++;
        if (pos < b.length && b[pos] == 0x3E) pos++;
        return const _Kw('>');
    }
    if (c == 0x2B || c == 0x2D || c == 0x2E || (c >= 0x30 && c <= 0x39)) {
      final v = readNumber();
      if (refs && v is int && v >= 0) {
        final save = pos;
        skipWs();
        if (pos < b.length && b[pos] >= 0x30 && b[pos] <= 0x39) {
          final g = readNumber();
          skipWs();
          if (g is int && pos < b.length && b[pos] == 0x52 && (pos + 1 == b.length || _cls[b[pos + 1]] != 0)) {
            pos++;
            return _Ref(v, g);
          }
        }
        pos = save;
      }
      return v;
    }
    final w = readWord();
    return switch (w) {
      'true' => true,
      'false' => false,
      'null' => null,
      _ => _Kw(w),
    };
  }

  String readWord() {
    final start = pos;
    while (pos < b.length && _cls[b[pos]] == 0) {
      pos++;
    }
    if (pos == start) {
      pos++;
      return '';
    }
    return String.fromCharCodes(b, start, pos);
  }

  /// A number (an int when it has no decimal point). Stray signs and
  /// characters glued to it ("--1", "1.2.3") are tolerated.
  num readNumber() {
    final n = b.length;
    var neg = false;
    while (pos < n && (b[pos] == 0x2D || b[pos] == 0x2B)) {
      if (b[pos] == 0x2D) neg = !neg;
      pos++;
    }
    var v = 0.0;
    while (pos < n) {
      final d = b[pos] - 0x30;
      if (d < 0 || d > 9) break;
      v = v * 10 + d;
      pos++;
    }
    var real = false;
    if (pos < n && b[pos] == 0x2E) {
      real = true;
      pos++;
      var f = 0.0, scale = 1.0;
      while (pos < n) {
        final d = b[pos] - 0x30;
        if (d < 0 || d > 9) break;
        f = f * 10 + d;
        scale *= 10;
        pos++;
      }
      v += f / scale;
    }
    while (pos < n && (b[pos] == 0x2E || b[pos] == 0x2D || b[pos] == 0x2B || (b[pos] >= 0x30 && b[pos] <= 0x39))) {
      pos++;
    }
    if (neg) v = -v;
    if (!real && v.abs() < 9007199254740992) return v.toInt();
    return v;
  }

  /// A number of a content stream, always as a double.
  double readReal() {
    final v = readNumber();
    return v.toDouble();
  }

  String readName() {
    pos++; // '/'
    final start = pos;
    var escaped = false;
    while (pos < b.length && _cls[b[pos]] == 0) {
      if (b[pos] == 0x23) escaped = true;
      pos++;
    }
    if (!escaped) return String.fromCharCodes(b, start, pos);
    final out = <int>[];
    for (var i = start; i < pos; i++) {
      final c = b[i];
      // #xx: a byte in hexadecimal
      if (c == 0x23 && i + 2 < pos) {
        final h = _hexValue(b[i + 1]), l = _hexValue(b[i + 2]);
        if (h >= 0 && l >= 0) {
          out.add(h * 16 + l);
          i += 2;
          continue;
        }
      }
      out.add(c);
    }
    return utf8.decode(out, allowMalformed: true);
  }

  Uint8List readLiteral() {
    pos++; // '('
    final n = b.length;
    // fast path: no escapes and no carriage returns
    var depth = 1, i = pos;
    var simple = true;
    for (; i < n; i++) {
      final c = b[i];
      if (c == 0x5C || c == 0x0D) {
        simple = false;
        break;
      }
      if (c == 0x28) depth++;
      if (c == 0x29 && --depth == 0) break;
    }
    if (simple) {
      final s = Uint8List.sublistView(b, pos, math.min(i, n));
      pos = math.min(i + 1, n);
      return s;
    }
    final out = <int>[];
    depth = 1;
    while (pos < n) {
      var c = b[pos++];
      if (c == 0x5C) {
        if (pos >= n) break;
        c = b[pos++];
        switch (c) {
          case 0x6E:
            out.add(0x0A);
          case 0x72:
            out.add(0x0D);
          case 0x74:
            out.add(0x09);
          case 0x62:
            out.add(0x08);
          case 0x66:
            out.add(0x0C);
          case 0x0D:
            if (pos < n && b[pos] == 0x0A) pos++;
          case 0x0A:
            break;
          default:
            if (c >= 0x30 && c <= 0x37) {
              var v = c - 0x30;
              for (var k = 0; k < 2 && pos < n && b[pos] >= 0x30 && b[pos] <= 0x37; k++) {
                v = v * 8 + b[pos++] - 0x30;
              }
              out.add(v & 0xFF);
            } else {
              out.add(c);
            }
        }
        continue;
      }
      if (c == 0x28) {
        depth++;
      } else if (c == 0x29) {
        if (--depth == 0) break;
      } else if (c == 0x0D) {
        if (pos < n && b[pos] == 0x0A) pos++;
        c = 0x0A;
      }
      out.add(c);
    }
    return Uint8List.fromList(out);
  }

  Uint8List readHex() {
    pos++; // '<'
    final out = <int>[];
    var hi = -1;
    while (pos < b.length) {
      final c = b[pos++];
      if (c == 0x3E) break;
      final v = _hexValue(c);
      if (v < 0) continue;
      if (hi < 0) {
        hi = v;
      } else {
        out.add((hi << 4) | v);
        hi = -1;
      }
    }
    if (hi >= 0) out.add(hi << 4);
    return Uint8List.fromList(out);
  }

  List<Object?> readArray(int depth, bool refs) {
    if (depth > 100) throw const FormatException('pdf_damaged');
    final out = <Object?>[];
    while (true) {
      skipWs();
      if (pos >= b.length) break;
      if (b[pos] == 0x5D) {
        pos++;
        break;
      }
      final start = pos;
      final v = parse(depth + 1, refs);
      if (v is _Kw && _structural(v.v)) {
        pos = start;
        break;
      }
      out.add(v);
    }
    return out;
  }

  Map<String, Object?> readDict(int depth, bool refs) {
    if (depth > 100) throw const FormatException('pdf_damaged');
    final out = <String, Object?>{};
    while (true) {
      skipWs();
      if (pos >= b.length) break;
      final c = b[pos];
      if (c == 0x3E) {
        pos++;
        if (pos < b.length && b[pos] == 0x3E) pos++;
        break;
      }
      final start = pos;
      if (c != 0x2F) {
        // a value without its key: skipped, unless the dictionary ended
        final junk = parse(depth + 1, refs);
        if (junk is _Kw && _structural(junk.v)) {
          pos = start;
          break;
        }
        continue;
      }
      final key = readName();
      skipWs();
      final vStart = pos;
      final v = parse(depth + 1, refs);
      if (v is _Kw && _structural(v.v)) {
        pos = vStart;
        if (v.v != '>') break;
        continue;
      }
      out[key] = v;
    }
    return out;
  }
}

// ---------------------------------------------------------------- content

// operators, their bytes packed little-endian
const _opBDC = 0x434442, _opBMC = 0x434d42, _opEMC = 0x434d45, _opBT = 0x5442, _opET = 0x5445, _opBI = 0x4942;
const _opTc = 0x6354, _opTw = 0x7754, _opTz = 0x7a54, _opTL = 0x4c54, _opTf = 0x6654, _opTr = 0x7254, _opTs = 0x7354;
const _opTd = 0x6454, _opTD = 0x4454, _opTm = 0x6d54, _opTStar = 0x2a54, _opTj = 0x6a54, _opTJ = 0x4a54, _opQuote = 0x27, _opDQuote = 0x22;
const _opCm = 0x6d63, _opq = 0x71, _opQ = 0x51, _opw = 0x77, _opGs = 0x7367;
const _opm = 0x6d, _opl = 0x6c, _opc = 0x63, _opv = 0x76, _opy = 0x79, _oph = 0x68, _opRe = 0x6572;
const _opS = 0x53, _ops = 0x73, _opf = 0x66, _opF = 0x46, _opfStar = 0x2a66, _opB = 0x42, _opBStar = 0x2a42, _opb = 0x62, _opbStar = 0x2a62, _opn = 0x6e, _opW = 0x57, _opWStar = 0x2a57;
const _opCS = 0x5343, _opcs = 0x7363, _opSC = 0x4353, _opSCN = 0x4e4353, _opsc = 0x6373, _opscn = 0x6e6373;
const _opG = 0x47, _opg = 0x67, _opRG = 0x4752, _oprg = 0x6772, _opK = 0x4b, _opk = 0x6b, _opSh = 0x6873, _opDo = 0x6f44;

class _GState {
  _GState(this.ctm);
  Affine ctm;
  int strokeRgb = 0, fillRgb = 0;
  _Cs strokeCs = _Cs.gray, fillCs = _Cs.gray;
  double lineWidth = 1;
  double strokeAlpha = 1, fillAlpha = 1;
  _Font? font;
  double fontSize = 0, charSpacing = 0, wordSpacing = 0, hScale = 1, leading = 0, rise = 0;
  int render = 0;

  /// The clipping region, as a rectangle of page space that holds it (the
  /// bounding boxes of the clipping paths, intersected); null: the page.
  Bounds? clip;

  _GState copy() => _GState(ctm)
    ..clip = clip
    ..strokeRgb = strokeRgb
    ..fillRgb = fillRgb
    ..strokeCs = strokeCs
    ..fillCs = fillCs
    ..lineWidth = lineWidth
    ..strokeAlpha = strokeAlpha
    ..fillAlpha = fillAlpha
    ..font = font
    ..fontSize = fontSize
    ..charSpacing = charSpacing
    ..wordSpacing = wordSpacing
    ..hScale = hScale
    ..leading = leading
    ..rise = rise
    ..render = render;
}

class _Sub {
  _Sub(Pt start) : pts = [start];
  final List<Pt> pts;
  bool closed = false;
}

/// The text run being assembled (strings shown one after the other along
/// a baseline).
class _Run {
  _Run(this.origin, this.end, this.height, this.angle, this.rgb, this.layer, this.hidden);
  final Pt origin;
  Pt end;
  final double height, angle;
  final int rgb;
  final String layer;
  final bool hidden;
  final StringBuffer text = StringBuffer();
}

/// Interprets the content of one page.
class _Interp {
  _Interp(this.doc, this.page, {required this.vectors, required this.texts, required this.images, required this.maxSegments}) {
    final w = page.info.width, h = page.info.height;
    final diag = math.sqrt(w * w + h * h);
    tol = (diag * 5e-5).clamp(0.01, 0.5);
    dedupe2 = math.pow(tol * 0.01, 2).toDouble();
    join2 = math.pow(tol * 0.1, 2).toDouble();
    gs = _GState(page.base);
  }

  final PdfReader doc;
  final _Page page;
  final bool vectors, texts, images;
  final int maxSegments;

  final paths = <PdfPathItem>[];
  final textItems = <PdfTextItem>[];
  final imageItems = <PdfImageItem>[];
  final warnings = <String>{};

  /// Layer names met, with their visibility.
  final layersUsed = <String, bool>{};
  int segments = 0;
  bool truncated = false;
  int ops = 0;

  /// Flattening tolerance (page units) and the squared distances under
  /// which points are the same / paths meet.
  late final double tol, dedupe2, join2;

  late _GState gs;
  final stack = <_GState>[];
  final subs = <_Sub>[];
  _Sub? cur;
  Pt? cp;

  /// A W or W* waits for the end of the path.
  bool pendingClip = false;
  Affine tm = Affine.identity, tlm = Affine.identity;
  _Run? run;

  /// Marked content: the layer of every open BDC /OC (null for other tags).
  final mc = <_Oc?>[];
  String ocName = '';
  bool ocHidden = false;

  final activeForms = <_Stream>{};
  final formData = <_Stream, Uint8List>{};
  final fonts = <Object, _Font>{};
  final colorSpaces = <Object, _Cs>{};
  final rasters = <Object, _Raster?>{};

  void runPage() {
    final c = doc._resolve(page.dict['Contents']);
    final parts = <Uint8List>[];
    void add(Object? s) {
      final v = doc._resolve(s);
      if (v is! _Stream) return;
      try {
        parts.add(doc._decodeStream(v));
      } on _TooLarge {
        rethrow;
      } on Object {
        warnings.add('pdf_stream_damaged');
      }
    }

    if (c is List) {
      for (final s in c) {
        add(s);
      }
    } else {
      add(page.dict['Contents']);
    }
    // the parts of an array split at token boundaries: joined by a space
    final all = _Bytes();
    for (final p in parts) {
      all.addAll(p, 0, p.length);
      all.add(0x0A);
    }
    // annotations that show something (comments, stamps, markups) are not
    // drawn: said so. Those without an appearance draw nothing, such as the
    // invisible notes CAD plotters add to carry the text of stroked fonts.
    final annots = doc._array(page.dict['Annots']) ?? const [];
    for (final a in annots) {
      final d = doc._dict(a);
      if (d == null || const {'Link', 'Popup', 'Widget'}.contains(doc._name(d['Subtype']))) continue;
      final flags = doc._int(d['F']) ?? 0;
      if (flags & (2 | 32) != 0 || doc._dict(d['AP'])?['N'] == null) continue;
      warnings.add('pdf_annotations');
      break;
    }
    execute(all.take(), page.resources, 0);
  }

  void execute(Uint8List b, Map<String, Object?>? res, int depth) {
    final p = _Parser(b);
    final n = b.length;
    final nums = Float64List(48);
    var nn = 0;
    final args = <Object?>[];
    while (p.pos < n) {
      final c = b[p.pos];
      final k = _cls[c];
      if (k == 1) {
        p.pos++;
        continue;
      }
      if (c == 0x25) {
        p.skipWs();
        continue;
      }
      if ((c >= 0x30 && c <= 0x39) || c == 0x2D || c == 0x2E || c == 0x2B) {
        final v = p.readReal();
        if (nn < nums.length) nums[nn++] = v;
        continue;
      }
      if (k == 2) {
        try {
          final v = p.parse(0, false);
          if (v is! _Kw) args.add(v);
        } on _Eof {
          break;
        } on FormatException {
          break;
        }
        continue;
      }
      final start = p.pos;
      while (p.pos < n && _cls[b[p.pos]] == 0) {
        p.pos++;
      }
      final len = p.pos - start;
      var op = -1;
      if (len <= 3) {
        op = 0;
        for (var i = 0; i < len; i++) {
          op |= b[start + i] << (8 * i);
        }
      } else if (len == 4 && b[start] == 0x74 && b[start + 1] == 0x72) {
        args.add(true);
        continue;
      } else if (len == 5 && b[start] == 0x66 && b[start + 1] == 0x61) {
        args.add(false);
        continue;
      } else if (len == 4 && b[start] == 0x6E && b[start + 1] == 0x75) {
        args.add(null);
        continue;
      }
      if (++ops > _maxOps) throw const _Stop();
      if (op == _opBI) {
        inlineImage(p, res);
      } else {
        try {
          dispatch(op, nums, nn, args, res, depth);
        } on _TooLarge {
          rethrow;
        } on _Stop {
          rethrow;
        } on Object {
          // an operator with the wrong operands: skipped
        }
      }
      nn = 0;
      args.clear();
    }
  }

  Pt tp(double x, double y) {
    final m = gs.ctm;
    return Pt(m.a * x + m.c * y + m.e, m.b * x + m.d * y + m.f);
  }

  void dispatch(int op, Float64List a, int n, List<Object?> args, Map<String, Object?>? res, int depth) {
    switch (op) {
      case _opq:
        if (stack.length < 1000) stack.add(gs.copy());
      case _opQ:
        if (stack.isNotEmpty) gs = stack.removeLast();
      case _opCm:
        if (n >= 6) gs.ctm = Affine(a[n - 6], a[n - 5], a[n - 4], a[n - 3], a[n - 2], a[n - 1]).then(gs.ctm);
      case _opw:
        if (n >= 1) gs.lineWidth = a[n - 1];
      case _opGs:
        extGState(args, res);
      case _opm:
        if (n >= 2) moveTo(tp(a[n - 2], a[n - 1]));
      case _opl:
        if (n >= 2) lineTo(tp(a[n - 2], a[n - 1]));
      case _opc:
        if (n >= 6) curveTo(tp(a[n - 6], a[n - 5]), tp(a[n - 4], a[n - 3]), tp(a[n - 2], a[n - 1]));
      case _opv:
        if (n >= 4 && cp != null) curveTo(cp!, tp(a[n - 4], a[n - 3]), tp(a[n - 2], a[n - 1]));
      case _opy:
        if (n >= 4) {
          final end = tp(a[n - 2], a[n - 1]);
          curveTo(tp(a[n - 4], a[n - 3]), end, end);
        }
      case _oph:
        closePath();
      case _opRe:
        if (n >= 4) rect(a[n - 4], a[n - 3], a[n - 2], a[n - 1]);
      case _opS:
        paint(stroke: true);
      case _ops:
        closePath();
        paint(stroke: true);
      case _opf || _opF || _opfStar:
        paint(fill: true);
      case _opB || _opBStar:
        paint(stroke: true, fill: true);
      case _opb || _opbStar:
        closePath();
        paint(stroke: true, fill: true);
      case _opn:
        endPath();
      case _opW || _opWStar:
        pendingClip = true;
      case _opG:
        gs.strokeCs = _Cs.gray;
        gs.strokeRgb = _Cs.gray.rgbOf(a, n - 1, n);
      case _opg:
        gs.fillCs = _Cs.gray;
        gs.fillRgb = _Cs.gray.rgbOf(a, n - 1, n);
      case _opRG:
        gs.strokeCs = _Cs.rgb;
        gs.strokeRgb = _Cs.rgb.rgbOf(a, n - 3, n);
      case _oprg:
        gs.fillCs = _Cs.rgb;
        gs.fillRgb = _Cs.rgb.rgbOf(a, n - 3, n);
      case _opK:
        gs.strokeCs = _Cs.cmyk;
        gs.strokeRgb = _Cs.cmyk.rgbOf(a, n - 4, n);
      case _opk:
        gs.fillCs = _Cs.cmyk;
        gs.fillRgb = _Cs.cmyk.rgbOf(a, n - 4, n);
      case _opCS:
        if (args.isNotEmpty) {
          gs.strokeCs = colorSpace(args.last, res);
          gs.strokeRgb = gs.strokeCs.initial;
        }
      case _opcs:
        if (args.isNotEmpty) {
          gs.fillCs = colorSpace(args.last, res);
          gs.fillRgb = gs.fillCs.initial;
        }
      case _opSC || _opSCN:
        gs.strokeRgb = gs.strokeCs.kind == _csPattern ? _patternRgb : gs.strokeCs.rgbOf(a, n - gs.strokeCs.n, n);
      case _opsc || _opscn:
        gs.fillRgb = gs.fillCs.kind == _csPattern ? _patternRgb : gs.fillCs.rgbOf(a, n - gs.fillCs.n, n);
      case _opBT:
        tm = Affine.identity;
        tlm = Affine.identity;
      case _opET:
        break;
      case _opTc:
        if (n >= 1) gs.charSpacing = a[n - 1];
      case _opTw:
        if (n >= 1) gs.wordSpacing = a[n - 1];
      case _opTz:
        if (n >= 1) gs.hScale = a[n - 1] / 100;
      case _opTL:
        if (n >= 1) gs.leading = a[n - 1];
      case _opTr:
        if (n >= 1) gs.render = a[n - 1].round();
      case _opTs:
        if (n >= 1) gs.rise = a[n - 1];
      case _opTf:
        if (n >= 1) gs.fontSize = a[n - 1];
        if (args.isNotEmpty) gs.font = font(doc._dict(res?['Font'])?[_nameOf(args.last) ?? ''] ?? args.last);
      case _opTd:
        if (n >= 2) moveText(a[n - 2], a[n - 1]);
      case _opTD:
        if (n >= 2) {
          gs.leading = -a[n - 1];
          moveText(a[n - 2], a[n - 1]);
        }
      case _opTm:
        if (n >= 6) {
          tlm = Affine(a[n - 6], a[n - 5], a[n - 4], a[n - 3], a[n - 2], a[n - 1]);
          tm = tlm;
        }
      case _opTStar:
        moveText(0, -gs.leading);
      case _opTj:
        if (args.isNotEmpty) show(args.last);
      case _opQuote:
        moveText(0, -gs.leading);
        if (args.isNotEmpty) show(args.last);
      case _opDQuote:
        if (n >= 2) {
          gs.wordSpacing = a[n - 2];
          gs.charSpacing = a[n - 1];
        }
        moveText(0, -gs.leading);
        if (args.isNotEmpty) show(args.last);
      case _opTJ:
        if (args.isNotEmpty) showArray(args.last);
      case _opDo:
        if (args.isNotEmpty) xObject(_nameOf(args.last), res, depth);
      case _opSh:
        warnings.add('pdf_shading');
      case _opBMC:
        mc.add(null);
      case _opBDC:
        beginMarked(args, res);
      case _opEMC:
        if (mc.isNotEmpty) {
          mc.removeLast();
          updateOc();
        }
    }
  }

  // ------------------------------------------------------------ paths

  void moveTo(Pt p) {
    // a lone point left by a previous m is dropped
    if (cur != null && cur!.pts.length == 1 && identical(subs.last, cur)) subs.removeLast();
    final s = _Sub(p);
    subs.add(s);
    cur = s;
    cp = p;
  }

  /// The subpath segments are added to (a new one after h, or when the
  /// path has no current point).
  _Sub target(Pt p) {
    final c = cur;
    if (c != null && !c.closed) return c;
    final s = _Sub(cp ?? p);
    subs.add(s);
    cur = s;
    return s;
  }

  void lineTo(Pt p) {
    target(p).pts.add(p);
    cp = p;
  }

  void curveTo(Pt p1, Pt p2, Pt p3) {
    final s = target(p1);
    final p0 = s.pts.last;
    // Wang's bound on the segments that keep a cubic within tol
    final ax = p0.x - 2 * p1.x + p2.x, ay = p0.y - 2 * p1.y + p2.y;
    final bx = p1.x - 2 * p2.x + p3.x, by = p1.y - 2 * p2.y + p3.y;
    final dd = math.sqrt(math.max(ax * ax + ay * ay, bx * bx + by * by));
    final est = math.sqrt(0.75 * dd / tol);
    final steps = est.isFinite ? est.ceil().clamp(1, 100) : 1;
    final pts = s.pts;
    for (var i = 1; i <= steps; i++) {
      final t = i / steps, u = 1 - t;
      final w0 = u * u * u, w1 = 3 * u * u * t, w2 = 3 * u * t * t, w3 = t * t * t;
      pts.add(Pt(w0 * p0.x + w1 * p1.x + w2 * p2.x + w3 * p3.x, w0 * p0.y + w1 * p1.y + w2 * p2.y + w3 * p3.y));
    }
    cp = p3;
  }

  void closePath() {
    final c = cur;
    if (c == null) return;
    c.closed = true;
    cp = c.pts.first;
  }

  void rect(double x, double y, double w, double h) {
    if (cur != null && cur!.pts.length == 1 && identical(subs.last, cur)) subs.removeLast();
    final s = _Sub(tp(x, y))
      ..pts.addAll([tp(x + w, y), tp(x + w, y + h), tp(x, y + h)])
      ..closed = true;
    subs.add(s);
    cur = s;
    cp = s.pts.first;
  }

  void paint({bool stroke = false, bool fill = false}) {
    if (vectors && !truncated) {
      final s = stroke && gs.strokeAlpha > 0;
      final f = fill && gs.fillAlpha > 0;
      if (s || f) {
        final m = gs.ctm;
        final lw = gs.lineWidth * math.sqrt((m.a * m.d - m.b * m.c).abs());
        for (final sub in subs) {
          emit(sub, s, f, lw);
          if (truncated) break;
        }
      }
    }
    endPath();
  }

  /// Ends the path; a clip set by W/W* takes effect now, after the painting.
  void endPath() {
    if (pendingClip) {
      pendingClip = false;
      var b = Bounds.empty;
      for (final s in subs) {
        for (final p in s.pts) {
          if (p.x.isFinite && p.y.isFinite) b = b.include(p);
        }
      }
      if (!b.isEmpty) gs.clip = _intersect(gs.clip, b);
    }
    subs.clear();
    cur = null;
  }

  static Bounds _intersect(Bounds? a, Bounds b) => a == null ? b : Bounds(math.max(a.minX, b.minX), math.max(a.minY, b.minY), math.min(a.maxX, b.maxX), math.min(a.maxY, b.maxY));

  void emit(_Sub sub, bool stroke, bool fill, double lw) {
    final raw = sub.pts;
    if (raw.length < 2) return;
    final pts = <Pt>[];
    for (final p in raw) {
      if (!p.x.isFinite || !p.y.isFinite) continue;
      if (pts.isNotEmpty) {
        final q = pts.last;
        final dx = p.x - q.x, dy = p.y - q.y;
        if (dx * dx + dy * dy <= dedupe2) continue;
      }
      pts.add(p);
    }
    final closed = sub.closed || fill;
    if (closed && pts.length > 2 && _near(pts.first, pts.last, dedupe2)) pts.removeLast();
    if (pts.length < 2) return;
    final clip = gs.clip;
    if (clip != null) {
      if (clip.isEmpty) return;
      final b = Bounds.ofPoints(pts);
      if (!b.intersects(clip)) return;
      if (b.minX < clip.minX || b.maxX > clip.maxX || b.minY < clip.minY || b.maxY > clip.maxY) {
        // partly outside: cut to the clip rectangle
        if (fill && closed && pts.length > 2) {
          final poly = _clipPolygon(pts, clip);
          if (poly.length > 2) add(poly, true, stroke, fill, lw);
          return;
        }
        for (final piece in _clipPolyline(pts, closed, clip)) {
          add(piece, false, stroke, fill, lw);
        }
        return;
      }
    }
    add(pts, closed, stroke, fill, lw);
  }

  void add(List<Pt> pts, bool closed, bool stroke, bool fill, double lw) {
    if (pts.length < 2 || (pts.length == 2 && _near(pts[0], pts[1], dedupe2))) return;
    if (pts.length < 3) closed = false;
    final segs = closed ? pts.length : pts.length - 1;
    if (segments + segs > maxSegments) {
      truncated = true;
      return;
    }
    segments += segs;
    final rgb = stroke ? gs.strokeRgb : gs.fillRgb;
    if (ocName.isNotEmpty) layersUsed.putIfAbsent(ocName, () => !ocHidden);
    // a segment that continues the previous polyline joins it
    if (!closed && stroke && !fill && paths.isNotEmpty) {
      final last = paths.last;
      if (last.stroked &&
          !last.filled &&
          !last.closed &&
          last.strokeRgb == rgb &&
          last.layer == ocName &&
          last.hidden == ocHidden &&
          (last.lineWidth - lw).abs() <= 1e-6 * math.max(1, lw) &&
          _near(last.points.last, pts.first, join2)) {
        last.points.addAll(pts.skip(1));
        if (last.points.length > 3 && _near(last.points.first, last.points.last, join2)) {
          last.points.removeLast();
          last.closed = true;
        }
        return;
      }
    }
    paths.add(PdfPathItem(points: pts, closed: closed, stroked: stroke, filled: fill, strokeRgb: gs.strokeRgb, fillRgb: gs.fillRgb, lineWidth: lw, layer: ocName, hidden: ocHidden));
  }

  static bool _near(Pt a, Pt b, double d2) {
    final dx = a.x - b.x, dy = a.y - b.y;
    return dx * dx + dy * dy <= d2;
  }

  // ------------------------------------------------------------ state

  void extGState(List<Object?> args, Map<String, Object?>? res) {
    final name = args.isEmpty ? null : _nameOf(args.last);
    if (name == null) return;
    final d = doc._dict(doc._dict(res?['ExtGState'])?[name]);
    if (d == null) return;
    final lw = doc._num(d['LW']);
    if (lw != null) gs.lineWidth = lw;
    final ca = doc._num(d['CA']);
    if (ca != null) gs.strokeAlpha = ca;
    final fa = doc._num(d['ca']);
    if (fa != null) gs.fillAlpha = fa;
    final f = doc._array(d['Font']);
    if (f != null && f.length >= 2) {
      gs.font = font(f[0]);
      gs.fontSize = doc._num(f[1]) ?? gs.fontSize;
    }
  }

  _Cs colorSpace(Object? spec, Map<String, Object?>? res) {
    final key = spec is _Name ? '${identityHashCode(res)}/${spec.v}' : spec;
    if (key == null) return _Cs.gray;
    return colorSpaces[key] ??= doc._colorSpace(spec, res);
  }

  _Font? font(Object? ref) {
    final key = ref is _Ref ? ref.n : ref;
    if (key == null) return null;
    final known = fonts[key];
    if (known != null) return known;
    // a font missing from the resources: its text read as WinAnsi
    final d = doc._dict(ref);
    return fonts[key] = d == null ? _Font.fallback() : _Font.load(doc, d);
  }

  void beginMarked(List<Object?> args, Map<String, Object?>? res) {
    _Oc? oc;
    if (args.length >= 2 && _nameOf(args[0]) == 'OC') {
      // the property list by name (from the resources) or inline
      var prop = args[1];
      if (prop is _Name) prop = doc._dict(res?['Properties'])?[prop.v];
      oc = doc._ocOf(prop);
    }
    // any other tag (or a property list that is no layer) still opens a level
    mc.add(oc);
    updateOc();
  }

  void updateOc() {
    var name = '';
    var hidden = false;
    for (final o in mc) {
      if (o == null) continue;
      name = o.name;
      if (!o.visible) hidden = true;
    }
    ocName = name;
    ocHidden = hidden;
  }

  // ------------------------------------------------------------ text

  void moveText(double tx, double ty) {
    tlm = Affine(1, 0, 0, 1, tx, ty).then(tlm);
    tm = tlm;
  }

  void show(Object? s) {
    final f = gs.font;
    if (s is! _Str || f == null) return;
    final th = gs.hScale, size = gs.fontSize;
    final buf = StringBuffer();
    var adv = 0.0;
    var unmapped = false;
    f.forEachCode(s.b, (code, len) {
      final t = f.text(code);
      if (t == null) {
        unmapped = true;
      } else {
        buf.write(t);
      }
      adv += (f.advance(code) * size + gs.charSpacing + (len == 1 && code == 32 ? gs.wordSpacing : 0)) * th;
    });
    if (unmapped) warnings.add('pdf_font_unmapped');
    if (texts) emitText(buf.toString(), adv, f);
    tm = Affine(1, 0, 0, 1, adv, 0).then(tm);
  }

  void showArray(Object? arr) {
    if (arr is! List) return;
    for (final e in arr) {
      if (e is _Str) {
        show(e);
      } else if (e is num) {
        final tx = -e / 1000 * gs.fontSize * gs.hScale;
        tm = Affine(1, 0, 0, 1, tx, 0).then(tm);
      }
    }
  }

  void emitText(String text, double adv, _Font f) {
    if (gs.render == 3 || gs.render == 7) return; // invisible (the OCR text of scans)
    if (text.isEmpty) return;
    final m = tm.then(gs.ctm);
    final o = m.apply(Pt(0, gs.rise)), e = m.apply(Pt(adv, gs.rise));
    final xv = m.applyVector(const Pt(1, 0)), yv = m.applyVector(const Pt(0, 1));
    final h = gs.fontSize.abs() * yv.length * f.heightScale;
    if (!(h > 0) || !h.isFinite || !o.x.isFinite || !o.y.isFinite) return;
    final clip = gs.clip;
    if (clip != null && (clip.isEmpty || !clip.inflate(h).contains(o))) return;
    final angle = xv.length > 0 ? xv.angle : 0.0;
    final rgb = gs.render == 1 || gs.render == 5 ? gs.strokeRgb : gs.fillRgb;
    if (ocName.isNotEmpty) layersUsed.putIfAbsent(ocName, () => !ocHidden);
    final r = run;
    if (r != null && r.layer == ocName && r.hidden == ocHidden && r.rgb == rgb && (r.height - h).abs() <= 0.03 * h && _sameAngle(r.angle, angle)) {
      final d = o - r.end;
      final dir = Pt(math.cos(angle), math.sin(angle));
      final along = d.dot(dir), across = d.cross(dir).abs();
      if (across <= 0.2 * h && along >= -0.35 * h && along <= 0.8 * h && r.text.length < 500) {
        final s = r.text.toString();
        if (along > 0.2 * h && !s.endsWith(' ') && !text.startsWith(' ')) r.text.write(' ');
        r.text.write(text);
        r.end = e;
        return;
      }
    }
    flushRun();
    run = _Run(o, e, h, angle, rgb, ocName, ocHidden)..text.write(text);
  }

  static bool _sameAngle(double a, double b) {
    var d = (a - b).abs() % (2 * math.pi);
    if (d > math.pi) d = 2 * math.pi - d;
    return d < 0.02;
  }

  void flushRun() {
    final r = run;
    run = null;
    if (r == null || textItems.length >= _maxTexts) return;
    final s = r.text.toString().trim();
    if (s.isEmpty) return;
    textItems.add(PdfTextItem(text: s, origin: r.origin, height: r.height, angleDeg: r.angle * 180 / math.pi, rgb: r.rgb, layer: r.layer, hidden: r.hidden));
  }

  // ------------------------------------------------------------ objects

  void xObject(String? name, Map<String, Object?>? res, int depth) {
    if (name == null) return;
    final xo = doc._resolve(doc._dict(res?['XObject'])?[name]);
    if (xo is! _Stream) return;
    final sub = doc._name(xo.dict['Subtype']);
    final oc = xo.dict['OC'];
    final pushed = oc != null;
    if (pushed) {
      mc.add(doc._ocOf(oc));
      updateOc();
    }
    try {
      if (sub == 'Image') {
        image(xo.dict, xo.raw, res, xo);
      } else if (sub == 'Form') {
        form(xo, res, depth);
      }
    } finally {
      if (pushed && mc.isNotEmpty) {
        mc.removeLast();
        updateOc();
      }
    }
  }

  void form(_Stream s, Map<String, Object?>? res, int depth) {
    if (depth >= 24 || !activeForms.add(s)) return; // a form drawing itself
    final saved = gs.copy();
    final depthStack = stack.length, depthMc = mc.length;
    final savedTm = tm, savedTlm = tlm;
    final savedSubs = List.of(subs), savedCur = cur, savedCp = cp;
    subs.clear();
    cur = null;
    try {
      final m = doc._numbers(s.dict['Matrix']);
      if (m != null && m.length >= 6) gs.ctm = Affine(m[0], m[1], m[2], m[3], m[4], m[5]).then(gs.ctm);
      // the form's bounding box clips it
      final box = doc._numbers(s.dict['BBox']);
      if (box != null && box.length >= 4 && box[2] != box[0] && box[3] != box[1]) {
        final c = gs.ctm;
        gs.clip = _intersect(gs.clip, Bounds.ofPoints([c.apply(Pt(box[0], box[1])), c.apply(Pt(box[2], box[1])), c.apply(Pt(box[2], box[3])), c.apply(Pt(box[0], box[3]))]));
      }
      final data = formData[s] ??= doc._decodeStream(s);
      execute(data, doc._dict(s.dict['Resources']) ?? res, depth + 1);
    } finally {
      activeForms.remove(s);
      gs = saved;
      if (stack.length > depthStack) stack.length = depthStack;
      if (mc.length > depthMc) {
        mc.length = depthMc;
        updateOc();
      }
      tm = savedTm;
      tlm = savedTlm;
      subs
        ..clear()
        ..addAll(savedSubs);
      cur = savedCur;
      cp = savedCp;
    }
  }

  /// An image drawn into the unit square of the current matrix.
  void image(Map<String, Object?> dict, Uint8List raw, Map<String, Object?>? res, Object? cacheKey) {
    if (imageItems.length >= _maxImages) {
      warnings.add('pdf_images_capped');
      return;
    }
    final w = doc._int(dict['Width']) ?? 0, h = doc._int(dict['Height']) ?? 0;
    if (w <= 0 || h <= 0) return;
    final m = gs.ctm;
    final corners = [m.apply(Pt.zero), m.apply(const Pt(1, 0)), m.apply(const Pt(1, 1)), m.apply(const Pt(0, 1))];
    if (corners.any((p) => !p.x.isFinite || !p.y.isFinite)) return;
    final area = (corners[1] - corners[0]).cross(corners[3] - corners[0]).abs();
    if (area < tol * tol) return; // nothing to see
    final clip = gs.clip;
    if (clip != null && (clip.isEmpty || !Bounds.ofPoints(corners).intersects(clip))) return;
    if (ocName.isNotEmpty) layersUsed.putIfAbsent(ocName, () => !ocHidden);
    _Raster? r;
    if (images) {
      final mask = doc._bool(dict['ImageMask']) ?? false;
      // a stencil takes the fill colour: cached per colour
      final key = cacheKey == null ? null : (mask ? '${identityHashCode(cacheKey)}/${gs.fillRgb}' : cacheKey);
      if (key != null && rasters.containsKey(key)) {
        r = rasters[key];
      } else {
        try {
          r = _decodeImage(this, dict, raw, res);
        } on _TooLarge {
          warnings.add('pdf_image_large');
        } on _Unsupported catch (e) {
          warnings.add('pdf_image_format:${e.filter.replaceAll('Decode', '')}');
        } on Object {
          warnings.add('pdf_image_failed');
        }
        if (key != null) rasters[key] = r;
      }
    }
    imageItems.add(PdfImageItem(corners: corners, widthPx: r?.width ?? w, heightPx: r?.height ?? h, bytes: r?.bytes, mime: r?.mime ?? 'image/png', layer: ocName, hidden: ocHidden));
  }

  /// BI … ID data EI: the dictionary, then the data up to EI.
  void inlineImage(_Parser p, Map<String, Object?>? res) {
    final b = p.b;
    final d = <String, Object?>{};
    while (true) {
      p.skipWs();
      if (p.atEnd) return;
      if (p.lookingAt('ID')) {
        p.pos += 2;
        break;
      }
      if (p.lookingAt('EI')) {
        p.pos += 2;
        return;
      }
      final Object? k;
      try {
        k = p.parse(0, false);
      } on _Eof {
        return;
      }
      if (k is! _Name) continue;
      final Object? v;
      try {
        v = p.parse(0, false);
      } on _Eof {
        return;
      }
      d[_inlineKey(k.v)] = v;
    }
    if (p.pos < b.length && _cls[b[p.pos]] == 1) p.pos++;
    final start = p.pos;
    final end = _inlineEnd(b, start, d, res);
    p.pos = math.min(b.length, end + 2);
    if (vectors || texts || images) image(d, Uint8List.sublistView(b, start, math.min(end, b.length)), res, null);
  }

  /// Where the data of an inline image ends (the position of its EI).
  int _inlineEnd(Uint8List b, int start, Map<String, Object?> d, Map<String, Object?>? res) {
    final n = b.length;
    final declared = doc._int(d['Length']);
    if (declared != null && declared >= 0 && start + declared <= n) {
      final q = _Parser(b, start + declared)..skipWs();
      if (q.lookingAt('EI')) return q.pos;
    }
    if (d['Filter'] == null) {
      // unfiltered: the size follows from the dictionary
      final w = doc._int(d['Width']) ?? 0, h = doc._int(d['Height']) ?? 0;
      final mask = doc._bool(d['ImageMask']) ?? false;
      final bpc = mask ? 1 : (doc._int(d['BitsPerComponent']) ?? 8);
      final comps = mask ? 1 : colorSpace(d['ColorSpace'], res).components;
      final size = ((w * comps * bpc + 7) ~/ 8) * h;
      if (size > 0 && start + size <= n) {
        final q = _Parser(b, start + size)..skipWs();
        if (q.lookingAt('EI')) return q.pos;
      }
    }
    // search: EI between white-space, followed by plain content
    for (var i = start; i + 1 < n; i++) {
      if (b[i] != 0x45 || b[i + 1] != 0x49) continue;
      if (i > start && _cls[b[i - 1]] != 1) continue;
      if (i + 2 < n && _cls[b[i + 2]] != 1) continue;
      var plain = true;
      for (var k = i + 2; k < math.min(n, i + 24); k++) {
        final c = b[k];
        if (c > 0x7E || (c < 0x20 && _cls[c] != 1)) {
          plain = false;
          break;
        }
      }
      if (plain) return i;
    }
    return n;
  }
}

String _inlineKey(String k) => switch (k) {
  'BPC' => 'BitsPerComponent',
  'CS' => 'ColorSpace',
  'D' => 'Decode',
  'DP' => 'DecodeParms',
  'F' => 'Filter',
  'H' => 'Height',
  'IM' => 'ImageMask',
  'I' => 'Interpolate',
  'W' => 'Width',
  'L' => 'Length',
  _ => k,
};

/// Segment [a]–[b] cut to [r] (Liang–Barsky); the ends inside are returned
/// as they are. Null when nothing of it is inside.
(Pt, Pt)? _clipSegment(Pt a, Pt b, Bounds r) {
  var t0 = 0.0, t1 = 1.0;
  final dx = b.x - a.x, dy = b.y - a.y;
  bool edge(double p, double q) {
    if (p == 0) return q >= 0;
    final t = q / p;
    if (p < 0) {
      if (t > t1) return false;
      if (t > t0) t0 = t;
    } else {
      if (t < t0) return false;
      if (t < t1) t1 = t;
    }
    return true;
  }

  if (!edge(-dx, a.x - r.minX) || !edge(dx, r.maxX - a.x) || !edge(-dy, a.y - r.minY) || !edge(dy, r.maxY - a.y)) return null;
  return (t0 > 0 ? Pt(a.x + t0 * dx, a.y + t0 * dy) : a, t1 < 1 ? Pt(a.x + t1 * dx, a.y + t1 * dy) : b);
}

/// The pieces of a polyline inside [r].
List<List<Pt>> _clipPolyline(List<Pt> pts, bool closed, Bounds r) {
  final out = <List<Pt>>[];
  List<Pt>? cur;
  final n = pts.length;
  for (var i = 0; i < (closed ? n : n - 1); i++) {
    final a = pts[i], b = pts[(i + 1) % n];
    final c = _clipSegment(a, b, r);
    if (c == null) {
      if (cur != null) out.add(cur);
      cur = null;
      continue;
    }
    final (p, q) = c;
    if (cur != null && identical(p, a)) {
      cur.add(q);
    } else {
      if (cur != null) out.add(cur);
      cur = [p, q];
    }
    if (!identical(q, b)) {
      out.add(cur);
      cur = null;
    }
  }
  if (cur != null) out.add(cur);
  // a loop that leaves and comes back: its last piece runs on into the first
  if (closed && out.length > 1 && identical(out.last.last, out.first.first)) out.first.insertAll(0, out.removeLast()..removeLast());
  return out;
}

/// A polygon cut to [r] (Sutherland–Hodgman).
List<Pt> _clipPolygon(List<Pt> pts, Bounds r) {
  var out = pts;
  for (var edge = 0; edge < 4 && out.isNotEmpty; edge++) {
    final input = out;
    out = <Pt>[];
    bool inside(Pt p) => switch (edge) {
      0 => p.x >= r.minX,
      1 => p.x <= r.maxX,
      2 => p.y >= r.minY,
      _ => p.y <= r.maxY,
    };
    Pt cut(Pt a, Pt b) {
      final t = switch (edge) {
        0 => (r.minX - a.x) / (b.x - a.x),
        1 => (r.maxX - a.x) / (b.x - a.x),
        2 => (r.minY - a.y) / (b.y - a.y),
        _ => (r.maxY - a.y) / (b.y - a.y),
      };
      return Pt(a.x + t * (b.x - a.x), a.y + t * (b.y - a.y));
    }

    for (var i = 0; i < input.length; i++) {
      final a = input[(i + input.length - 1) % input.length], b = input[i];
      final ia = inside(a), ib = inside(b);
      if (ib) {
        if (!ia) out.add(cut(a, b));
        out.add(b);
      } else if (ia) {
        out.add(cut(a, b));
      }
    }
  }
  return out;
}
