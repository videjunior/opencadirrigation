/// Minimal PDF writer (pure Dart, ISO 32000-1 / PDF Reference 1.7, written
/// as PDF 1.4): vector paths, clipping, Flate-compressed content streams,
/// the standard Helvetica fonts with WinAnsi encoding for the text they can
/// show, embedded TrueType subsets for any other text, and images.
///
/// Text that WinAnsi cannot represent is laid out by
/// [PdfFonts] (lib/core/io/fonts) into runs of one script and direction,
/// shaped with the OpenType tables of the bundled Noto fonts and drawn
/// with a Type0 font per TrueType font (9.7: CIDFontType2 descendant,
/// Identity-H encoding, CIDToGIDMap /Identity, W widths, FontFile2 subset,
/// ToUnicode CMap, 9.10.3). Copy and search give the logical text: the
/// first glyph of each shaped cluster maps to the cluster's text and the
/// other glyphs of the cluster to nothing, and a glyph that stands for
/// different texts gets one CID (a copy of the glyph) per text. Bold is
/// simulated with text rendering mode 2 (fill and stroke) and a thin stroke.
///
/// Images are image XObjects (8.9.5): JPEG data passed through with
/// DCTDecode, anything else decoded and stored as RGB with FlateDecode plus
/// an SMask for the alpha channel (11.6.5.3); opacity uses an ExtGState
/// with /ca. Large images are downsampled for the size they are printed at.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;

import 'fonts/pdf_fonts.dart';
import 'fonts/subset.dart';
import 'fonts/truetype.dart';
import 'image_decode.dart';

export 'fonts/pdf_fonts.dart' show BundledFonts, PdfFonts;

const double ptPerMm = 72 / 25.4;

enum PdfAlign { left, center, right }

/// An embedded font: the glyphs used and the text of every CID.
class _FontUse {
  _FontUse(this.name, this.font, this.resource);
  final String name;
  final TrueTypeFont font;
  final String resource;
  final Set<int> glyphs = {0};

  /// Text of each CID (empty for the glyphs that follow the first glyph of a cluster).
  final Map<int, String> toUnicode = {};
  final Map<(int, String), int> _cids = {};

  /// Glyphs copied after the end of the font (CID numGlyphs + i shows copies[i]).
  final List<int> copies = [];

  /// CID that draws [glyph] and copies as [text].
  int cid(int glyph, String text) {
    final known = _cids[(glyph, text)];
    if (known != null) return known;
    glyphs.add(glyph);
    var c = glyph;
    if (toUnicode.containsKey(glyph)) {
      c = font.numGlyphs + copies.length;
      if (c > 0xFFFF) return glyph;
      copies.add(glyph);
    }
    toUnicode[c] = text;
    return _cids[(glyph, text)] = c;
  }

  /// Glyph drawn by [cid].
  int glyphOf(int cid) => cid < font.numGlyphs ? cid : copies[cid - font.numGlyphs];
}

/// An image XObject of a document.
class PdfImage {
  PdfImage._(this.resource, this.width, this.height, this.data, this.filter, this.colorSpace, this.alpha);

  /// Resource name (/Im1...).
  final String resource;

  /// Size in pixels (after any downsampling).
  final int width, height;

  /// Samples: JPEG data (DCTDecode) or Flate-compressed 8-bit samples.
  final Uint8List data;

  /// Filter of [data]: DCTDecode or FlateDecode.
  final String filter;

  /// DeviceRGB or DeviceGray.
  final String colorSpace;

  /// Flate-compressed 8-bit alpha (soft mask), or null when opaque.
  final Uint8List? alpha;
}

class PdfDocument {
  PdfDocument({this.title = '', this.author = '', this.subject = '', this.creator = 'OpenCADIrrigation', PdfFonts? fonts}) : fonts = fonts ?? PdfFonts.shared;
  final String title;
  final String author;
  final String subject;
  final String creator;

  /// Fonts for the text Helvetica cannot draw (and for measuring it).
  final PdfFonts fonts;
  final List<PdfPage> pages = [];
  final Map<String, _FontUse> _fonts = {};
  final List<PdfImage> _images = [];
  final Map<Object, PdfImage?> _imageCache = {};
  final Map<int, String> _alphaStates = {};

  PdfPage addPage({required double widthPt, required double heightPt}) {
    final p = PdfPage(widthPt, heightPt, this);
    pages.add(p);
    return p;
  }

  _FontUse? _useFont(String name) {
    final existing = _fonts[name];
    if (existing != null) return existing;
    final f = fonts.font(name);
    if (f == null) return null;
    return _fonts[name] = _FontUse(name, f, 'F${3 + _fonts.length}');
  }

  /// Name of an ExtGState with fill and stroke alpha [alpha] (0..1).
  String _alphaState(double alpha) {
    final key = (alpha.clamp(0.0, 1.0) * 1000).round();
    return _alphaStates[key] ??= 'GS${_alphaStates.length + 1}';
  }

  /// Image XObject for encoded image [bytes] (JPEG, PNG or anything the
  /// image package decodes), downsampled to at most [maxWidthPx] ×
  /// [maxHeightPx] pixels when given. Returns null when the data cannot be
  /// decoded. The same bytes and limits give the same XObject, and so do
  /// the same bytes under any limits they already fit (a base map drawn on
  /// every sheet of a set at different scales is stored once).
  PdfImage? image(Uint8List bytes, {String mime = '', int? maxWidthPx, int? maxHeightPx}) {
    final size = pixelSize(bytes);
    final fits = size != null && _downscale(size.$1, size.$2, maxWidthPx, maxHeightPx) >= 1;
    final maxW = fits ? null : maxWidthPx, maxH = fits ? null : maxHeightPx;
    final key = (bytes, maxW, maxH); // lists compare by identity
    if (_imageCache.containsKey(key)) return _imageCache[key];
    PdfImage? out;
    try {
      out = _makeImage(bytes, mime, maxW, maxH);
    } on Object {
      out = null;
    }
    if (out != null) _images.add(out);
    return _imageCache[key] = out;
  }

  PdfImage? _makeImage(Uint8List bytes, String mime, int? maxW, int? maxH) {
    // a picture the decoder refuses (beyond its pixel limit, damaged) is left
    // out of the sheet, as one it cannot read
    try {
      return _makeImageOf(bytes, mime, maxW, maxH);
    } on FormatException catch (e) {
      if (e.message == 'image_too_large' || e.message == 'image_unreadable') return null;
      rethrow;
    }
  }

  PdfImage? _makeImageOf(Uint8List bytes, String mime, int? maxW, int? maxH) {
    final name = 'Im${_images.length + 1}';
    final jpeg = jpegInfo(bytes);
    if (jpeg != null && (jpeg.$3 == 1 || jpeg.$3 == 3)) {
      final (w, h, comps) = jpeg;
      final scale = _downscale(w, h, maxW, maxH);
      if (scale >= 1) return PdfImage._(name, w, h, bytes, 'DCTDecode', comps == 1 ? 'DeviceGray' : 'DeviceRGB', null);
      final decoded = decodeJpgSafe(bytes);
      if (decoded == null) return null;
      final small = img.copyResize(decoded, width: math.max(1, (w * scale).round()), height: math.max(1, (h * scale).round()), interpolation: img.Interpolation.average);
      final again = Uint8List.fromList(img.encodeJpg(small, quality: 88));
      final info = jpegInfo(again);
      return PdfImage._(name, small.width, small.height, again, 'DCTDecode', info?.$3 == 1 ? 'DeviceGray' : 'DeviceRGB', null);
    }
    var decoded = decodeImageSafe(bytes);
    if (decoded == null) return null;
    final scale = _downscale(decoded.width, decoded.height, maxW, maxH);
    if (scale < 1) {
      decoded = img.copyResize(decoded, width: math.max(1, (decoded.width * scale).round()), height: math.max(1, (decoded.height * scale).round()), interpolation: img.Interpolation.average);
    }
    // 8-bit RGBA whatever the source (palette, gray, 16-bit, float)
    final rgba = decoded.convert(format: img.Format.uint8, numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
    final n = decoded.width * decoded.height;
    final rgb = Uint8List(3 * n);
    final a = Uint8List(n);
    var opaque = true;
    for (var i = 0; i < n; i++) {
      rgb[3 * i] = rgba[4 * i];
      rgb[3 * i + 1] = rgba[4 * i + 1];
      rgb[3 * i + 2] = rgba[4 * i + 2];
      a[i] = rgba[4 * i + 3];
      if (a[i] != 255) opaque = false;
    }
    return PdfImage._(
      name,
      decoded.width,
      decoded.height,
      Uint8List.fromList(ZLibEncoder().encodeBytes(rgb)),
      'FlateDecode',
      'DeviceRGB',
      opaque ? null : Uint8List.fromList(ZLibEncoder().encodeBytes(a)),
    );
  }

  static double _downscale(int w, int h, int? maxW, int? maxH) {
    var s = 1.0;
    if (maxW != null && maxW > 0 && w > maxW) s = math.min(s, maxW / w);
    if (maxH != null && maxH > 0 && h > maxH) s = math.min(s, maxH / h);
    return s;
  }

  /// Width and height of a JPEG or PNG read from its header, or null for
  /// other data.
  static (int, int)? pixelSize(Uint8List b) {
    final jpeg = jpegInfo(b);
    if (jpeg != null) return (jpeg.$1, jpeg.$2);
    const png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    if (b.length < 24) return null;
    for (var i = 0; i < 8; i++) {
      if (b[i] != png[i]) return null;
    }
    // the IHDR chunk comes first: length, type, width, height (big endian)
    int u32(int p) => (b[p] << 24) | (b[p + 1] << 16) | (b[p + 2] << 8) | b[p + 3];
    return (u32(16), u32(20));
  }

  /// Width, height and components of a baseline or progressive (Huffman) JPEG, or null.
  static (int, int, int)? jpegInfo(Uint8List b) {
    if (b.length < 4 || b[0] != 0xFF || b[1] != 0xD8) return null;
    var p = 2;
    while (p + 9 < b.length) {
      if (b[p] != 0xFF) return null;
      final marker = b[p + 1];
      if (marker == 0xD8 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
        p += 2;
        continue;
      }
      final len = (b[p + 2] << 8) | b[p + 3];
      if (marker >= 0xC0 && marker <= 0xC2) {
        final h = (b[p + 5] << 8) | b[p + 6], w = (b[p + 7] << 8) | b[p + 8];
        return (w, h, b[p + 9]);
      }
      if (marker == 0xD9 || marker == 0xDA) return null;
      p += 2 + len;
    }
    return null;
  }

  /// Serialises the document. Content streams are Flate-compressed unless
  /// [compress] is false (handy for inspecting the output in tests).
  Uint8List build({bool compress = true}) {
    final out = BytesBuilder(copy: false);
    final offsets = <int>[];
    void obj(int id, List<int> body) {
      offsets.add(out.length);
      out.add(latin1.encode('$id 0 obj\n'));
      out.add(body);
      out.add(latin1.encode('\nendobj\n'));
    }

    List<int> stream(String dict, List<int> raw, {bool flate = true, bool alreadyCompressed = false}) {
      final data = alreadyCompressed || !flate || !compress ? raw : ZLibEncoder().encodeBytes(raw);
      final filter = alreadyCompressed || (flate && compress) ? ' /Filter /FlateDecode' : '';
      return (BytesBuilder(copy: false)
            ..add(latin1.encode('<< /Length ${data.length}$filter$dict >>\nstream\n'))
            ..add(data)
            ..add(latin1.encode('\nendstream')))
          .takeBytes();
    }

    out.add(latin1.encode('%PDF-1.4\n%âãÏÓ\n'));
    final n = pages.length;
    // 1 catalog, 2 pages, 3 font, 4 bold font, 5 info, 2 objects per page, then
    // 5 objects per embedded font, 1 or 2 per image and 1 per graphics state
    var next = 6 + 2 * n;
    final fontIds = <String, int>{};
    for (final f in _fonts.values) {
      fontIds[f.name] = next;
      next += 5;
    }
    final imageIds = <PdfImage, int>{};
    for (final im in _images) {
      imageIds[im] = next;
      next += im.alpha == null ? 1 : 2;
    }
    final stateIds = <int, int>{};
    for (final k in _alphaStates.keys) {
      stateIds[k] = next++;
    }
    final kids = [for (var i = 0; i < n; i++) '${6 + 2 * i} 0 R'].join(' ');
    obj(1, latin1.encode('<< /Type /Catalog /Pages 2 0 R >>'));
    obj(2, latin1.encode('<< /Type /Pages /Kids [$kids] /Count $n >>'));
    obj(3, latin1.encode('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>'));
    obj(4, latin1.encode('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>'));
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final date = 'D:${now.year}${two(now.month)}${two(now.day)}${two(now.hour)}${two(now.minute)}${two(now.second)}';
    obj(
      5,
      latin1.encode(
        '<< /Title ${pdfTextString(title)} /Author ${pdfTextString(author)} /Subject ${pdfTextString(subject)} /Creator ${pdfTextString(creator)} /Producer (OpenCADIrrigation) /CreationDate ($date) >>',
      ),
    );
    final fontRes = StringBuffer('/F1 3 0 R /F2 4 0 R');
    for (final f in _fonts.values) {
      fontRes.write(' /${f.resource} ${fontIds[f.name]} 0 R');
    }
    final extra = StringBuffer();
    if (_images.isNotEmpty) extra.write(' /XObject << ${[for (final im in _images) '/${im.resource} ${imageIds[im]} 0 R'].join(' ')} >>');
    if (_alphaStates.isNotEmpty) extra.write(' /ExtGState << ${[for (final e in _alphaStates.entries) '/${e.value} ${stateIds[e.key]} 0 R'].join(' ')} >>');
    final procSet = _images.isEmpty ? '[/PDF /Text]' : '[/PDF /Text /ImageB /ImageC]';
    final resources = '/Resources << /Font << $fontRes >>$extra /ProcSet $procSet >>';
    for (var i = 0; i < n; i++) {
      final p = pages[i];
      final pageId = 6 + 2 * i, contentId = 7 + 2 * i;
      obj(pageId, latin1.encode('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${_num(p.width)} ${_num(p.height)}] $resources /Contents $contentId 0 R >>'));
      obj(contentId, stream('', latin1.encode(p._ops.toString())));
    }
    for (final f in _fonts.values) {
      final id = fontIds[f.name]!;
      final subset = FontSubset.build(f.font, f.glyphs, copies: f.copies);
      final scale = 1000 / f.font.unitsPerEm;
      String s(num v) => _num(v * scale);
      final baseName = '${_subsetTag(f)}+${f.font.postScriptName.replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '')}';
      obj(id, latin1.encode('<< /Type /Font /Subtype /Type0 /BaseFont /$baseName /Encoding /Identity-H /DescendantFonts [${id + 1} 0 R] /ToUnicode ${id + 4} 0 R >>'));
      obj(
        id + 1,
        latin1.encode(
          '<< /Type /Font /Subtype /CIDFontType2 /BaseFont /$baseName /CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> /FontDescriptor ${id + 2} 0 R /DW 0 /W ${_widths(f)} /CIDToGIDMap /Identity >>',
        ),
      );
      final flags = 4 | (f.font.fixedPitch ? 1 : 0) | (f.font.italicAngle != 0 ? 64 : 0);
      obj(
        id + 2,
        latin1.encode(
          '<< /Type /FontDescriptor /FontName /$baseName /Flags $flags /FontBBox [${s(f.font.xMin)} ${s(f.font.yMin)} ${s(f.font.xMax)} ${s(f.font.yMax)}] /ItalicAngle ${_num(f.font.italicAngle)} /Ascent ${s(f.font.ascender)} /Descent ${s(f.font.descender)} /CapHeight ${s(f.font.capHeight)} /StemV ${f.font.weightClass >= 600 ? 120 : 80} /FontFile2 ${id + 3} 0 R >>',
        ),
      );
      obj(id + 3, stream(' /Length1 ${subset.bytes.length}', subset.bytes));
      obj(id + 4, stream('', latin1.encode(_toUnicodeCMap(f))));
    }
    for (final im in _images) {
      final id = imageIds[im]!;
      final smask = im.alpha == null ? '' : ' /SMask ${id + 1} 0 R';
      final bpc = ' /Type /XObject /Subtype /Image /Width ${im.width} /Height ${im.height} /ColorSpace /${im.colorSpace} /BitsPerComponent 8';
      if (im.filter == 'DCTDecode') {
        obj(id, stream('$bpc /Filter /DCTDecode$smask', im.data, flate: false));
      } else {
        obj(id, stream('$bpc$smask', im.data, alreadyCompressed: true));
      }
      if (im.alpha != null) {
        obj(id + 1, stream(' /Type /XObject /Subtype /Image /Width ${im.width} /Height ${im.height} /ColorSpace /DeviceGray /BitsPerComponent 8', im.alpha!, alreadyCompressed: true));
      }
    }
    for (final e in _alphaStates.entries) {
      final a = _num(e.key / 1000);
      obj(stateIds[e.key]!, latin1.encode('<< /Type /ExtGState /ca $a /CA $a >>'));
    }
    final xref = out.length;
    final b = StringBuffer()
      ..write('xref\n0 ${offsets.length + 1}\n')
      ..write('0000000000 65535 f \n');
    for (final o in offsets) {
      b.write('${o.toString().padLeft(10, '0')} 00000 n \n');
    }
    b.write('trailer\n<< /Size ${offsets.length + 1} /Root 1 0 R /Info 5 0 R >>\nstartxref\n$xref\n%%EOF\n');
    out.add(latin1.encode(b.toString()));
    return out.takeBytes();
  }

  /// Six capital letters identifying a subset (ISO 32000-1, 9.6.4).
  static String _subsetTag(_FontUse f) {
    var h = 0x811C9DC5;
    for (final c in '${f.name}${(f.glyphs.toList()..sort()).join(',')}/${f.copies.join(',')}'.codeUnits) {
      h = ((h ^ c) * 0x01000193) % 0x100000000;
    }
    final b = StringBuffer();
    for (var i = 0; i < 6; i++) {
      b.writeCharCode(65 + h % 26);
      h ~/= 26;
    }
    return b.toString();
  }

  /// W array: widths (1/1000 em) of the used CIDs, by runs of consecutive ids.
  static String _widths(_FontUse f) {
    final ids = {...f.glyphs, ...f.toUnicode.keys}.toList()..sort();
    final scale = 1000 / f.font.unitsPerEm;
    final b = StringBuffer('[');
    var i = 0;
    while (i < ids.length) {
      var j = i + 1;
      while (j < ids.length && ids[j] == ids[j - 1] + 1) {
        j++;
      }
      b.write('${ids[i]} [${[for (var k = i; k < j; k++) _num(f.font.advanceWidth(f.glyphOf(ids[k])) * scale)].join(' ')}] ');
      i = j;
    }
    b.write(']');
    return b.toString();
  }

  static String _toUnicodeCMap(_FontUse f) {
    final entries = f.toUnicode.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final b = StringBuffer()
      ..writeln('/CIDInit /ProcSet findresource begin')
      ..writeln('12 dict begin')
      ..writeln('begincmap')
      ..writeln('/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def')
      ..writeln('/CMapName /Adobe-Identity-UCS def')
      ..writeln('/CMapType 2 def')
      ..writeln('1 begincodespacerange')
      ..writeln('<0000> <FFFF>')
      ..writeln('endcodespacerange');
    for (var i = 0; i < entries.length; i += 100) {
      final chunk = entries.sublist(i, math.min(i + 100, entries.length));
      b.writeln('${chunk.length} beginbfchar');
      for (final e in chunk) {
        b.writeln('<${_hex4(e.key)}> <${_utf16Hex(e.value)}>');
      }
      b.writeln('endbfchar');
    }
    b
      ..writeln('endcmap')
      ..writeln('CMapName currentdict /CMap defineresource pop')
      ..writeln('end')
      ..writeln('end');
    return b.toString();
  }

  /// PDF literal string with WinAnsi characters and escapes (content streams).
  static String pdfString(String s) {
    final b = StringBuffer('(');
    for (final ch in winAnsi(s).codeUnits) {
      if (ch == 0x28 || ch == 0x29 || ch == 0x5C) {
        b.write('\\');
        b.writeCharCode(ch);
      } else if (ch < 32 || ch > 126) {
        b.write('\\${ch.toRadixString(8).padLeft(3, '0')}');
      } else {
        b.writeCharCode(ch);
      }
    }
    b.write(')');
    return b.toString();
  }

  /// PDF text string (document information, 7.9.2.2): a literal when the
  /// text is ASCII or Latin-1, otherwise UTF-16BE with a byte order mark.
  static String pdfTextString(String s) {
    final plain = s.runes.every((r) => r < 0x80 || (r >= 0xA0 && r <= 0xFF));
    if (plain) return pdfString(s);
    return '<FEFF${_utf16Hex(s)}>';
  }

  /// Maps a string to WinAnsi code points (one code unit ≤ 0xFF per char).
  static String winAnsi(String s) => toWinAnsi(s);
}

String _hex4(int v) => v.toRadixString(16).toUpperCase().padLeft(4, '0');

String _utf16Hex(String s) {
  final b = StringBuffer();
  for (final u in s.codeUnits) {
    b.write(_hex4(u));
  }
  return b.toString();
}

String _num(double v) {
  if (!v.isFinite) return '0';
  var s = v.toStringAsFixed(2);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s == '-0' ? '0' : s;
}

class PdfPage {
  PdfPage(this.width, this.height, [this.document]);
  final double width;
  final double height;

  /// The document of the page (null for a page made on its own, which can
  /// only draw WinAnsi text).
  final PdfDocument? document;
  final StringBuffer _ops = StringBuffer();

  int _strokeColor = -1, _fillColor = -1;
  double _lineWidth = -1;
  bool _dashed = false;

  PdfFonts get _fonts => document?.fonts ?? PdfFonts.shared;

  void save() {
    _ops.writeln('q');
  }

  void restore() {
    _ops.writeln('Q');
    _strokeColor = -1;
    _fillColor = -1;
    _lineWidth = -1;
    _dashed = false;
  }

  void strokeColor(int argb) {
    if (_strokeColor == argb) return;
    _strokeColor = argb;
    _ops.writeln('${_rgb(argb)} RG');
  }

  void fillColor(int argb) {
    if (_fillColor == argb) return;
    _fillColor = argb;
    _ops.writeln('${_rgb(argb)} rg');
  }

  void lineWidth(double pt) {
    if (_lineWidth == pt) return;
    _lineWidth = pt;
    _ops.writeln('${_num(pt)} w');
  }

  void dash(bool on, [double dashPt = 3, double gapPt = 2]) {
    if (_dashed == on) return;
    _dashed = on;
    _ops.writeln(on ? '[${_num(dashPt)} ${_num(gapPt)}] 0 d' : '[] 0 d');
  }

  /// Fill and stroke opacity of what follows (call inside save/restore).
  void opacity(double alpha) {
    final d = document;
    if (d == null || alpha >= 1) return;
    _ops.writeln('/${d._alphaState(alpha)} gs');
  }

  static String _rgb(int argb) => '${_num(((argb >> 16) & 0xFF) / 255)} ${_num(((argb >> 8) & 0xFF) / 255)} ${_num((argb & 0xFF) / 255)}';

  void _paint(bool stroke, bool fill, bool close) {
    if (close) _ops.write('h ');
    _ops.writeln(fill && stroke ? 'B' : (fill ? 'f' : (stroke ? 'S' : 'n')));
  }

  void path(List<(double, double)> pts, {bool close = false, bool stroke = true, bool fill = false}) {
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      circle(pts.first.$1, pts.first.$2, 0.5, stroke: false, fill: true);
      return;
    }
    _ops.write('${_num(pts.first.$1)} ${_num(pts.first.$2)} m ');
    for (var i = 1; i < pts.length; i++) {
      _ops.write('${_num(pts[i].$1)} ${_num(pts[i].$2)} l ');
    }
    _paint(stroke, fill, close);
  }

  void line(double x1, double y1, double x2, double y2) => path([(x1, y1), (x2, y2)]);

  void rect(double x, double y, double w, double h, {bool stroke = true, bool fill = false}) {
    _ops.write('${_num(x)} ${_num(y)} ${_num(w)} ${_num(h)} re ');
    _paint(stroke, fill, false);
  }

  void circle(double cx, double cy, double r, {bool stroke = true, bool fill = false}) {
    const k = 0.5522847498;
    final kr = k * r;
    _ops.write('${_num(cx + r)} ${_num(cy)} m ');
    _ops.write('${_num(cx + r)} ${_num(cy + kr)} ${_num(cx + kr)} ${_num(cy + r)} ${_num(cx)} ${_num(cy + r)} c ');
    _ops.write('${_num(cx - kr)} ${_num(cy + r)} ${_num(cx - r)} ${_num(cy + kr)} ${_num(cx - r)} ${_num(cy)} c ');
    _ops.write('${_num(cx - r)} ${_num(cy - kr)} ${_num(cx - kr)} ${_num(cy - r)} ${_num(cx)} ${_num(cy - r)} c ');
    _ops.write('${_num(cx + kr)} ${_num(cy - r)} ${_num(cx + r)} ${_num(cy - kr)} ${_num(cx + r)} ${_num(cy)} c ');
    _paint(stroke, fill, true);
  }

  /// Sets a rectangular clip (call inside save/restore).
  void clipRect(double x, double y, double w, double h) {
    _ops.writeln('${_num(x)} ${_num(y)} ${_num(w)} ${_num(h)} re W n');
  }

  /// Draws [image] on the parallelogram with corners [bottomLeft],
  /// [bottomRight] and [topLeft] (points), with [opacity].
  void image(PdfImage image, (double, double) bottomLeft, (double, double) bottomRight, (double, double) topLeft, {double opacity = 1}) {
    if (document == null) return;
    final (x0, y0) = bottomLeft;
    final (x1, y1) = bottomRight;
    final (x2, y2) = topLeft;
    save();
    if (opacity < 1) this.opacity(opacity);
    _ops.writeln('${_num6(x1 - x0)} ${_num6(y1 - y0)} ${_num6(x2 - x0)} ${_num6(y2 - y0)} ${_num6(x0)} ${_num6(y0)} cm /${image.resource} Do');
    restore();
  }

  static String _num6(double v) {
    if (!v.isFinite) return '0';
    var s = v.toStringAsFixed(4);
    if (s.contains('.')) s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return s == '-0' ? '0' : s;
  }

  /// Draws [s] with its baseline at (x, y). [size] in points.
  void text(double x, double y, String s, {double size = 10, bool bold = false, double rotationDeg = 0, PdfAlign align = PdfAlign.left}) {
    if (s.isEmpty) return;
    final fonts = _fonts;
    final line = fonts.layout(s);
    var dx = 0.0;
    if (align != PdfAlign.left) {
      final w = line.width(size, bold: bold);
      dx = align == PdfAlign.center ? -w / 2 : -w;
    }
    final simple = line.spans.length == 1 && line.spans.first.isWinAnsi;
    final helvetica = bold ? '/F2' : '/F1';
    if (simple) {
      _ops.write('BT $helvetica ${_num(size)} Tf ');
    } else {
      _ops.write('BT ');
    }
    if (rotationDeg != 0) {
      final a = rotationDeg * math.pi / 180;
      final c = math.cos(a), sn = math.sin(a);
      _ops.write('${_num(c)} ${_num(sn)} ${_num(-sn)} ${_num(c)} ${_num(x + dx * c)} ${_num(y + dx * sn)} Tm ');
    } else {
      _ops.write('${_num(x + dx)} ${_num(y)} Td ');
    }
    if (simple) {
      _ops.writeln('${PdfDocument.pdfString(line.spans.first.text)} Tj ET');
      return;
    }
    for (final span in line.spans) {
      if (span.isWinAnsi) {
        _ops.write('$helvetica ${_num(size)} Tf ${PdfDocument.pdfString(span.text)} Tj ');
        continue;
      }
      final use = document?._useFont(span.fontName!);
      if (use == null) {
        // no document to embed into: draw what WinAnsi can
        _ops.write('$helvetica ${_num(size)} Tf ${PdfDocument.pdfString(span.text)} Tj ');
        continue;
      }
      if (bold) {
        strokeColor(_fillColor < 0 ? 0xFF000000 : _fillColor);
        lineWidth(size * 0.035);
        _ops.write('2 Tr ');
      }
      _ops.write('/${use.resource} ${_num(size)} Tf ');
      _showGlyphs(use, span, size);
      if (bold) _ops.write('0 Tr ');
    }
    _ops.writeln('ET');
  }

  /// Shows the glyphs of an embedded span: TJ with the shaped advances and
  /// x offsets as adjustments, text rise for y offsets.
  void _showGlyphs(_FontUse use, PdfTextSpan span, double size) {
    final run = span.glyphs!;
    final font = use.font;
    final upem = font.unitsPerEm;
    // CIDs: one glyph of every cluster copies as the cluster's text (the
    // first one, left to right, that advances: not a mark drawn over the
    // base), the other glyphs of the cluster as nothing
    final starts = run.clusters.toSet().toList()..sort();
    String clusterText(int c) {
      final i = starts.indexOf(c);
      final end = i + 1 < starts.length ? starts[i + 1] : span.text.length;
      return span.text.substring(c, end);
    }

    final cids = List<int>.filled(run.length, 0);
    var from = 0;
    while (from < run.length) {
      var to = from + 1;
      while (to < run.length && run.clusters[to] == run.clusters[from]) {
        to++;
      }
      var carrier = from;
      for (var k = from; k < to; k++) {
        if (run.advances[k] > 0) {
          carrier = k;
          break;
        }
      }
      for (var k = from; k < to; k++) {
        cids[k] = use.cid(run.glyphs[k], k == carrier ? clusterText(run.clusters[from]) : '');
      }
      from = to;
    }
    var rise = 0;
    var pending = 0.0; // font units to move right before the next glyph
    final b = StringBuffer('[');
    String adj(double v) => _num(-v * 1000 / upem);
    for (var i = 0; i < run.length; i++) {
      final g = run.glyphs[i], dx = run.xOffsets[i], dy = run.yOffsets[i];
      if (dy != rise) {
        if (pending != 0) b.write(' ${adj(pending)}');
        pending = 0;
        b.write('] TJ ${_num(dy * size / upem)} Ts [');
        rise = dy;
      }
      final move = pending + dx;
      if (move != 0) b.write(' ${adj(move)} ');
      b.write('<${_hex4(cids[i])}>');
      pending = (run.advances[i] - dx - font.advanceWidth(g)).toDouble();
    }
    if (pending != 0) b.write(' ${adj(pending)}');
    b.write('] TJ ');
    if (rise != 0) b.write('0 Ts ');
    _ops.write(b.toString().replaceAll('[] TJ ', ''));
  }

  /// Truncates [s] with an ellipsis so it fits in [maxWidth] points
  /// (measured with [PdfFonts.shared]).
  static String fit(String s, double maxWidth, double size, {bool bold = false}) => PdfFonts.shared.fit(s, maxWidth, size, bold: bold);

  /// Advance width of [s] in points, as [text] draws it with [PdfFonts.shared]
  /// (Helvetica AFM metrics for WinAnsi runs, shaped advances otherwise).
  static double textWidth(String s, double size, {bool bold = false}) => PdfFonts.shared.textWidth(s, size, bold: bold);
}
