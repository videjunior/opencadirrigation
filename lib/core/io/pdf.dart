/// Minimal PDF 1.4 writer (pure Dart): vector paths, standard Helvetica
/// fonts with WinAnsi encoding, clipping and Flate-compressed content
/// streams. Enough for plot sheets and tabular reports without any
/// third-party dependency.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';

const double ptPerMm = 72 / 25.4;

enum PdfAlign { left, center, right }

class PdfDocument {
  PdfDocument({this.title = '', this.author = '', this.subject = '', this.creator = 'OpenCADIrrigation'});
  final String title;
  final String author;
  final String subject;
  final String creator;
  final List<PdfPage> pages = [];

  PdfPage addPage({required double widthPt, required double heightPt}) {
    final p = PdfPage(widthPt, heightPt);
    pages.add(p);
    return p;
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

    out.add(latin1.encode('%PDF-1.4\n%âãÏÓ\n'));
    final n = pages.length;
    // 1 catalog, 2 pages, 3 font, 4 bold font, 5 info, then 2 objects per page
    final kids = [for (var i = 0; i < n; i++) '${6 + 2 * i} 0 R'].join(' ');
    obj(1, latin1.encode('<< /Type /Catalog /Pages 2 0 R >>'));
    obj(2, latin1.encode('<< /Type /Pages /Kids [$kids] /Count $n >>'));
    obj(3, latin1.encode('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>'));
    obj(4, latin1.encode('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>'));
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final date = 'D:${now.year}${two(now.month)}${two(now.day)}${two(now.hour)}${two(now.minute)}${two(now.second)}';
    obj(5, latin1.encode('<< /Title ${pdfString(title)} /Author ${pdfString(author)} /Subject ${pdfString(subject)} /Creator ${pdfString(creator)} /Producer (OpenCADIrrigation) /CreationDate ($date) >>'));
    for (var i = 0; i < n; i++) {
      final p = pages[i];
      final pageId = 6 + 2 * i, contentId = 7 + 2 * i;
      obj(pageId, latin1.encode('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${_num(p.width)} ${_num(p.height)}] /Resources << /Font << /F1 3 0 R /F2 4 0 R >> /ProcSet [/PDF /Text] >> /Contents $contentId 0 R >>'));
      final raw = latin1.encode(p._ops.toString());
      final data = compress ? ZLibEncoder().encodeBytes(raw) : raw;
      final body = BytesBuilder(copy: false)
        ..add(latin1.encode('<< /Length ${data.length}${compress ? ' /Filter /FlateDecode' : ''} >>\nstream\n'))
        ..add(data)
        ..add(latin1.encode('\nendstream'));
      obj(contentId, body.takeBytes());
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

  /// PDF literal string with WinAnsi characters and escapes.
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

  /// Maps a string to WinAnsi code points (one code unit ≤ 0xFF per char).
  static String winAnsi(String s) {
    final b = StringBuffer();
    for (final r in s.runes) {
      if (r <= 0xFF && !(r >= 0x80 && r <= 0x9F)) {
        b.writeCharCode(r);
        continue;
      }
      final m = _winAnsiExtra[r];
      b.writeCharCode(m ?? 0x3F);
    }
    return b.toString();
  }

  static const _winAnsiExtra = <int, int>{
    0x20AC: 0x80, 0x201A: 0x82, 0x0192: 0x83, 0x201E: 0x84, 0x2026: 0x85, 0x2020: 0x86, 0x2021: 0x87, 0x02C6: 0x88, 0x2030: 0x89, 0x0160: 0x8A, 0x2039: 0x8B, 0x0152: 0x8C, 0x017D: 0x8E,
    0x2018: 0x91, 0x2019: 0x92, 0x201C: 0x93, 0x201D: 0x94, 0x2022: 0x95, 0x2013: 0x96, 0x2014: 0x97, 0x02DC: 0x98, 0x2122: 0x99, 0x0161: 0x9A, 0x203A: 0x9B, 0x0153: 0x9C, 0x017E: 0x9E, 0x0178: 0x9F,
    0x2212: 0x2D, 0x00A0: 0x20, 0x2192: 0x3E, 0x0394: 0x44, 0x221E: 0x38,
  };
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
  PdfPage(this.width, this.height);
  final double width;
  final double height;
  final StringBuffer _ops = StringBuffer();

  int _strokeColor = -1, _fillColor = -1;
  double _lineWidth = -1;
  bool _dashed = false;

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

  /// Draws [s] with its baseline at (x, y). [size] in points.
  void text(double x, double y, String s, {double size = 10, bool bold = false, double rotationDeg = 0, PdfAlign align = PdfAlign.left}) {
    if (s.isEmpty) return;
    var dx = 0.0;
    if (align != PdfAlign.left) {
      final w = textWidth(s, size, bold: bold);
      dx = align == PdfAlign.center ? -w / 2 : -w;
    }
    final font = bold ? '/F2' : '/F1';
    _ops.write('BT $font ${_num(size)} Tf ');
    if (rotationDeg != 0) {
      final a = rotationDeg * math.pi / 180;
      final c = math.cos(a), sn = math.sin(a);
      _ops.write('${_num(c)} ${_num(sn)} ${_num(-sn)} ${_num(c)} ${_num(x + dx * c)} ${_num(y + dx * sn)} Tm ');
    } else {
      _ops.write('${_num(x + dx)} ${_num(y)} Td ');
    }
    _ops.writeln('${PdfDocument.pdfString(s)} Tj ET');
  }

  /// Truncates [s] with an ellipsis so it fits in [maxWidth] points.
  static String fit(String s, double maxWidth, double size, {bool bold = false}) {
    if (textWidth(s, size, bold: bold) <= maxWidth + 0.01) return s;
    var t = s;
    while (t.isNotEmpty && textWidth('$t…', size, bold: bold) > maxWidth) {
      t = t.substring(0, t.length - 1);
    }
    return t.isEmpty ? '' : '$t…';
  }

  /// Advance width of [s] in points for the standard Helvetica metrics.
  static double textWidth(String s, double size, {bool bold = false}) {
    var w = 0;
    for (final ch in PdfDocument.winAnsi(s).codeUnits) {
      w += _width(ch, bold);
    }
    return w * size / 1000;
  }

  static int _width(int ch, bool bold) {
    if (ch >= 32 && ch <= 126) return (bold ? _helveticaBold : _helvetica)[ch - 32];
    if (ch >= 0xC0 && ch <= 0xFF) {
      final base = _latin1Base[ch - 0xC0];
      return (bold ? _helveticaBold : _helvetica)[base - 32];
    }
    return switch (ch) {
      0xB0 || 0xB2 || 0xB3 || 0xB9 => 333, // ° ² ³ ¹
      0x96 => 556, // en dash
      0x97 => 1000, // em dash
      0x85 => 1000, // ellipsis
      0x95 => 350, // bullet
      0xB7 => 278, // middle dot
      0xA0 => 278,
      _ => 556,
    };
  }

  // Base ASCII letter for Latin-1 accented characters 0xC0..0xFF.
  static const _latin1Base = [
    65, 65, 65, 65, 65, 65, 65, 67, 69, 69, 69, 69, 73, 73, 73, 73, // À-Ï
    68, 78, 79, 79, 79, 79, 79, 120, 79, 85, 85, 85, 85, 89, 84, 66, // Ð-ß
    97, 97, 97, 97, 97, 97, 97, 99, 101, 101, 101, 101, 105, 105, 105, 105, // à-ï
    100, 110, 111, 111, 111, 111, 111, 47, 111, 117, 117, 117, 117, 121, 116, 121, // ð-ÿ
  ];

  // Helvetica AFM advance widths for code points 32..126.
  static const _helvetica = [
    278, 278, 355, 556, 556, 889, 667, 191, 333, 333, 389, 584, 278, 333, 278, 278, 556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 278, 278, 584, 584, 584, 556,
    1015, 667, 667, 722, 722, 667, 611, 778, 722, 278, 500, 667, 556, 833, 722, 778, 667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 278, 278, 278, 469, 556,
    333, 556, 556, 500, 556, 556, 278, 556, 556, 222, 222, 500, 222, 833, 556, 556, 556, 556, 333, 500, 278, 556, 500, 722, 500, 500, 500, 334, 260, 334, 584,
  ];
  static const _helveticaBold = [
    278, 333, 474, 556, 556, 889, 722, 238, 333, 333, 389, 584, 278, 333, 278, 278, 556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 333, 333, 584, 584, 584, 611,
    975, 722, 722, 722, 722, 667, 611, 778, 722, 278, 556, 722, 611, 833, 722, 778, 667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 333, 278, 333, 584, 556,
    333, 556, 611, 556, 611, 556, 333, 611, 611, 278, 278, 556, 278, 889, 611, 611, 611, 611, 389, 556, 333, 611, 556, 778, 556, 556, 500, 389, 280, 389, 584,
  ];
}
