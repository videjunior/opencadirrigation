/// Technical documents built from the project in pure Dart — the permit
/// table of the water sources, the memorial, the operation and maintenance
/// plan, the budget by compositions, the life-cycle cost of the
/// alternatives (1.6.0) — and their writers: PDF (A4 pages with a running
/// header and the page numbers), Markdown (to edit in any text editor),
/// CSV (tables to paste into a form) and XLSX.
///
/// A document is a title and [TechSection]s of [TechBlock]s: paragraphs,
/// lists, label–value fields, formulas with the meaning of their symbols,
/// notes and tables (the [ReportTable] of the reports, so a table reads the
/// same in every output). A package of documents (cover, contents,
/// signature) takes the sections of each document as they are
/// ([TechDocument.sections]) or draws the whole document into a PDF it
/// already holds ([addTechDocumentPages], without its own header and footer
/// when the package numbers the pages).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../design/report_tables.dart' show RBar, RNum, ReportTable;
import '../translate.dart';
import '../units.dart';
import 'pdf.dart';
import 'xlsx.dart';

/// A block of a section.
sealed class TechBlock {
  const TechBlock();

  /// Every text of the block (for the fonts of the PDF and for searches).
  Iterable<String> get texts;
}

/// A paragraph of running text.
class TechParagraph extends TechBlock {
  const TechParagraph(this.text);
  final String text;
  @override
  Iterable<String> get texts => [text];
}

/// A list of items, with bullets or numbered.
class TechBullets extends TechBlock {
  const TechBullets(this.items, {this.numbered = false});
  final List<String> items;
  final bool numbered;
  @override
  Iterable<String> get texts => items;
}

/// Label–value pairs (a form's fields).
class TechFields extends TechBlock {
  const TechFields(this.rows);
  final List<(String, String)> rows;
  @override
  Iterable<String> get texts => [
    for (final (k, v) in rows) ...[k, v],
  ];
}

/// A formula, the meaning of each of its symbols and where it comes from.
class TechFormula extends TechBlock {
  const TechFormula(this.expression, {this.where = const [], this.source = ''});
  final String expression;

  /// (symbol, meaning with its unit).
  final List<(String, String)> where;
  final String source;
  @override
  Iterable<String> get texts => [
    expression,
    for (final (s, m) in where) ...[s, m],
    source,
  ];
}

/// A remark set apart from the text; [warning] marks one that needs action.
class TechNote extends TechBlock {
  const TechNote(this.text, {this.warning = false});
  final String text;
  final bool warning;
  @override
  Iterable<String> get texts => [text];
}

/// A table, with a remark under it.
class TechTable extends TechBlock {
  const TechTable(this.table, {this.note = ''});
  final ReportTable table;
  final String note;
  @override
  Iterable<String> get texts sync* {
    yield table.title;
    yield* table.headers;
    for (final r in table.rows) {
      for (final c in r) {
        if (c is String) yield c;
      }
    }
    yield note;
  }
}

/// A section: its title, its level (1 = a chapter, 2 = within it) and its
/// blocks; [key] names it for the packages (`identification`, `climate`…).
class TechSection {
  const TechSection(this.title, this.blocks, {this.level = 1, this.key = ''});
  final String title;
  final List<TechBlock> blocks;
  final int level;
  final String key;
}

/// A technical document of the project.
class TechDocument {
  const TechDocument({required this.key, required this.title, this.subtitle = '', required this.sections, this.landscape = false, this.header = ''});

  /// What document it is: `permit`, `memorial`, `om`, `budget`, `lcc`.
  final String key;
  final String title;

  /// A line under the title (the project, the client, the site).
  final String subtitle;
  final List<TechSection> sections;

  /// Wide tables: A4 landscape pages.
  final bool landscape;

  /// Text of the running header of the pages (default: [subtitle]).
  final String header;

  /// Every text of the document.
  Iterable<String> get texts sync* {
    yield title;
    yield subtitle;
    yield header;
    for (final s in sections) {
      yield s.title;
      for (final b in s.blocks) {
        yield* b.texts;
      }
    }
  }

  /// Every table, in the order of the document.
  List<ReportTable> get tables => [
    for (final s in sections)
      for (final b in s.blocks)
        if (b is TechTable) b.table,
  ];

  /// The document as Markdown: headings, paragraphs, lists, fields as a
  /// two-column table, formulas as code, notes as quotes and tables as
  /// pipe tables.
  String toMarkdown() {
    final b = StringBuffer('# ${_mdInline(title)}\n');
    if (subtitle.isNotEmpty) b.write('\n${_mdInline(subtitle)}\n');
    for (final s in sections) {
      b.write('\n${'#' * (s.level + 1)} ${_mdInline(s.title)}\n');
      for (final blk in s.blocks) {
        b.writeln();
        switch (blk) {
          case TechParagraph p:
            b.writeln(_mdInline(p.text));
          case TechBullets l:
            for (var i = 0; i < l.items.length; i++) {
              b.writeln('${l.numbered ? '${i + 1}.' : '-'} ${_mdInline(l.items[i])}');
            }
          case TechFields f:
            b.writeln('| | |\n|---|---|');
            for (final (k, v) in f.rows) {
              b.writeln('| ${_mdCell(k)} | ${_mdCell(v)} |');
            }
          case TechFormula f:
            b.writeln('```\n${f.expression}\n```');
            for (final (sym, m) in f.where) {
              b.writeln('- `$sym`: ${_mdInline(m)}');
            }
            if (f.source.isNotEmpty) b.writeln('\n_${_mdInline(f.source)}_');
          case TechNote n:
            b.writeln('> ${n.warning ? '**' : ''}${_mdInline(n.text)}${n.warning ? '**' : ''}');
          case TechTable t:
            final tb = t.table;
            b.writeln('**${_mdInline(tb.title)}**\n');
            b.writeln('| ${tb.headers.map(_mdCell).join(' | ')} |');
            b.writeln('|${[for (var i = 0; i < tb.headers.length; i++) _numericColumn(tb, i) ? '---:' : '---'].join('|')}|');
            for (final r in tb.rows) {
              b.writeln('| ${[for (var i = 0; i < tb.headers.length; i++) i < r.length ? _mdCell(_cellText(r[i])) : ''].join(' | ')} |');
            }
            if (t.note.isNotEmpty) b.writeln('\n_${_mdInline(t.note)}_');
        }
      }
    }
    return b.toString();
  }

  /// Semicolon-separated CSV with a UTF-8 BOM (as the reports): the title,
  /// then every section with its fields (label; value), its texts on lines
  /// of their own and its tables (header and rows).
  String toCsv() {
    final b = StringBuffer('﻿');
    b.writeln(_csv(title));
    if (subtitle.isNotEmpty) b.writeln(_csv(subtitle));
    for (final s in sections) {
      b.writeln();
      b.writeln(_csv(s.title.toUpperCase()));
      for (final blk in s.blocks) {
        switch (blk) {
          case TechParagraph p:
            b.writeln(_csv(p.text));
          case TechBullets l:
            for (final x in l.items) {
              b.writeln(_csv(x));
            }
          case TechFields f:
            for (final (k, v) in f.rows) {
              b.writeln('${_csv(k)};${_csv(v)}');
            }
          case TechFormula f:
            b.writeln(_csv(f.expression));
            for (final (sym, m) in f.where) {
              b.writeln('${_csv(sym)};${_csv(m)}');
            }
          case TechNote n:
            b.writeln(_csv(n.text));
          case TechTable t:
            b.writeln(_csv(t.table.title));
            b.writeln(t.table.headers.map(_csv).join(';'));
            for (final r in t.table.rows) {
              b.writeln(r.map((c) => _csv(_cellText(c))).join(';'));
            }
            if (t.note.isNotEmpty) b.writeln(_csv(t.note));
        }
      }
    }
    return b.toString();
  }

  /// XLSX: a first sheet with the text of the document (section, label,
  /// value), then one sheet per table with its numbers as numbers.
  Uint8List toXlsx() {
    final text = <List<Object?>>[];
    for (final s in sections) {
      text.add([s.title]);
      for (final blk in s.blocks) {
        switch (blk) {
          case TechParagraph p:
            text.add(['', p.text]);
          case TechBullets l:
            for (final x in l.items) {
              text.add(['', x]);
            }
          case TechFields f:
            for (final (k, v) in f.rows) {
              text.add(['', k, v]);
            }
          case TechFormula f:
            text.add(['', f.expression]);
            for (final (sym, m) in f.where) {
              text.add(['', sym, m]);
            }
          case TechNote n:
            text.add(['', n.text]);
          case TechTable t:
            text.add(['', t.table.title]);
        }
      }
    }
    return XlsxWriter.write([
      XlsxSheet(name: title, headers: [title, subtitle, ''], rows: text),
      for (final tb in tables)
        XlsxSheet(
          name: tb.title,
          headers: tb.headers,
          rows: [
            for (final r in tb.rows) [for (final c in r) c is RNum ? double.parse(c.value.toStringAsFixed(c.decimals)) : (c is RBar ? '' : c)],
          ],
        ),
    ]);
  }
}

String _cellText(Object c) => c is RBar ? '' : '$c';

bool _numericColumn(ReportTable tb, int i) => tb.rows.isNotEmpty && tb.rows.every((r) => i >= r.length || r[i] is num || r[i] is RNum || '${r[i]}'.isEmpty);

String _mdInline(String s) => s.replaceAll('\n', ' ').replaceAllMapped(RegExp(r'([\\`*_<>\[\]#|])'), (m) => '\\${m[1]}');

String _mdCell(String s) => _mdInline(s).trim();

String _csv(String s) => s.contains(RegExp(r'[;"\n]')) ? '"${s.replaceAll('"', '""')}"' : s;

// ---------------------------------------------------------------- PDF

const _ink = 0xFF1A1A1A;
const _grey = 0xFF6B7178;
const _rule = 0xFFB8C0C8;
const _headFill = 0xFFE3E8EE;
const _warnFill = 0xFFFFE0B2;
const _noteFill = 0xFFEEF3F8;
const _brand = 0xFF1E88E5;

/// The document [doc] as a PDF of its own (A4, portrait unless the document
/// is [TechDocument.landscape]), with [t] for the page numbers and the
/// footer line.
Uint8List techDocumentPdf(TechDocument doc, {required Translate t, PdfFonts? fonts, String author = '', DateTime? date}) {
  final pdf = PdfDocument(title: doc.title, author: author, subject: doc.subtitle, fonts: fonts);
  addTechDocumentPages(pdf, doc, t: t, date: date);
  return pdf.build();
}

/// Draws [doc] on new pages of [pdf] and returns them. With [chrome] each
/// page has the running header (the title, [TechDocument.header] and the
/// date) and the footer (generated by, page i of n of the document);
/// without it the pages are bare, for a package that adds its own.
List<PdfPage> addTechDocumentPages(PdfDocument pdf, TechDocument doc, {required Translate t, bool chrome = true, DateTime? date}) {
  final w = _TechPages(pdf, doc, t, chrome: chrome, date: date ?? DateTime.now());
  w.write();
  return w.pages;
}

class _TechPages {
  _TechPages(this.pdf, this.doc, this.t, {required this.chrome, required this.date});
  final PdfDocument pdf;
  final TechDocument doc;
  final Translate t;
  final bool chrome;
  final DateTime date;
  final List<PdfPage> pages = [];
  late PdfPage page;
  double y = 0;

  PdfFonts get fonts => pdf.fonts;
  double get wMm => doc.landscape ? 297 : 210;
  double get hMm => doc.landscape ? 210 : 297;
  static const marginMm = 15.0;
  double get left => marginMm * ptPerMm;
  double get right => (wMm - marginMm) * ptPerMm;
  double get avail => right - left;
  double get bottom => (marginMm + (chrome ? 7 : 0)) * ptPerMm;
  double get top => (hMm - marginMm) * ptPerMm;

  static String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void write() {
    _newPage(first: true);
    for (final s in doc.sections) {
      _heading(s);
      for (final b in s.blocks) {
        switch (b) {
          case TechParagraph p:
            _paragraph(p.text);
          case TechBullets l:
            _bullets(l);
          case TechFields f:
            _fields(f.rows);
          case TechFormula f:
            _formula(f);
          case TechNote n:
            _note(n);
          case TechTable tb:
            _table(tb.table);
            if (tb.note.isNotEmpty) _paragraph(tb.note, size: 7, color: _grey);
        }
      }
      y -= 4;
    }
    if (chrome) _footers();
  }

  void _newPage({bool first = false}) {
    page = pdf.addPage(widthPt: wMm * ptPerMm, heightPt: hMm * ptPerMm);
    pages.add(page);
    y = top;
    if (chrome) {
      page.fillColor(_ink);
      page.text(left, y - 9, fonts.fit(doc.title, avail - 70, 10, bold: true), size: 10, bold: true);
      page.fillColor(_grey);
      page.text(right, y - 9, _date(date), size: 7.5, align: PdfAlign.right);
      final head = doc.header.isNotEmpty ? doc.header : doc.subtitle;
      if (head.isNotEmpty) page.text(left, y - 19, fonts.fit(head, avail, 7.5), size: 7.5);
      page.strokeColor(_ink);
      page.lineWidth(0.6);
      page.dash(false);
      page.line(left, y - 23, right, y - 23);
      y -= 34;
    }
    if (first) {
      // the title of the document, large, on its first page
      final lines = _wrap(fonts, doc.title, avail, 15, bold: true);
      page.fillColor(_brand);
      for (final l in lines) {
        page.text(left, y - 4, l, size: 15, bold: true);
        y -= 19;
      }
      if (doc.subtitle.isNotEmpty) {
        page.fillColor(_grey);
        for (final l in _wrap(fonts, doc.subtitle, avail, 9)) {
          page.text(left, y - 2, l, size: 9);
          y -= 12;
        }
      }
      y -= 8;
    }
  }

  void _footers() {
    for (var i = 0; i < pages.length; i++) {
      final p = pages[i];
      p.fillColor(_grey);
      p.text(left, marginMm * ptPerMm, fonts.fit(t('pdf.generated', {'d': _date(date)}), avail * 0.7, 6.5), size: 6.5);
      p.text(right, marginMm * ptPerMm, t('pdf.page', {'i': '${i + 1}', 'n': '${pages.length}'}), size: 6.5, align: PdfAlign.right);
    }
  }

  void _ensure(double needed) {
    if (y - needed < bottom) _newPage();
  }

  void _heading(TechSection s) {
    final size = s.level <= 1 ? 11.5 : 9.5;
    final lines = _wrap(fonts, s.title, avail, size, bold: true);
    // a heading never ends a page alone
    _ensure(lines.length * (size + 4) + 30);
    y -= s.level <= 1 ? 6 : 3;
    page.fillColor(s.level <= 1 ? _brand : _ink);
    for (final l in lines) {
      page.text(left, y - size, l, size: size, bold: true);
      y -= size + 4;
    }
    if (s.level <= 1) {
      page.strokeColor(_rule);
      page.lineWidth(0.4);
      page.dash(false);
      page.line(left, y + 1, right, y + 1);
    }
    y -= 5;
  }

  void _paragraph(String text, {double size = 8.5, int color = _ink, double indent = 0}) {
    if (text.isEmpty) return;
    final lead = size * 1.35;
    final lines = [for (final part in text.split('\n')) ..._wrap(fonts, part, avail - indent, size)];
    for (final l in lines) {
      _ensure(lead);
      page.fillColor(color);
      page.text(left + indent, y - size, l, size: size);
      y -= lead;
    }
    y -= 4;
  }

  void _bullets(TechBullets l) {
    const size = 8.5, lead = size * 1.35, indent = 12.0;
    for (var i = 0; i < l.items.length; i++) {
      final lines = _wrap(fonts, l.items[i], avail - indent, size);
      for (var k = 0; k < lines.length; k++) {
        _ensure(lead);
        page.fillColor(_ink);
        if (k == 0) page.text(left + 2, y - size, l.numbered ? '${i + 1}.' : '•', size: size);
        page.text(left + indent, y - size, lines[k], size: size);
        y -= lead;
      }
    }
    y -= 4;
  }

  void _fields(List<(String, String)> rows) {
    const size = 8.0, lead = size * 1.35;
    final labelW = avail * 0.36;
    for (final (k, v) in rows) {
      final kl = _wrap(fonts, k, labelW - 6, size);
      final vl = _wrap(fonts, v.isEmpty ? '—' : v, avail - labelW, size);
      final n = math.max(kl.length, vl.length);
      _ensure(n * lead + 2);
      for (var i = 0; i < n; i++) {
        if (i < kl.length) {
          page.fillColor(_grey);
          page.text(left, y - size, kl[i], size: size);
        }
        if (i < vl.length) {
          page.fillColor(_ink);
          page.text(left + labelW, y - size, vl[i], size: size);
        }
        y -= lead;
      }
      page.strokeColor(0xFFE1E6EB);
      page.lineWidth(0.3);
      page.dash(false);
      page.line(left, y + 2, right, y + 2);
      y -= 1.5;
    }
    y -= 4;
  }

  void _formula(TechFormula f) {
    const size = 9.0;
    final lines = _wrap(fonts, f.expression, avail - 24, size, bold: true);
    _ensure(lines.length * 13 + 10 + math.min(f.where.length, 3) * 10);
    y -= 2;
    for (final l in lines) {
      page.fillColor(_ink);
      page.text(left + 12, y - size, l, size: size, bold: true);
      y -= 13;
    }
    y -= 2;
    for (final (sym, m) in f.where) {
      final symW = math.min(fonts.textWidth(sym, 7.5, bold: true) + 8, avail * 0.3);
      final ml = _wrap(fonts, m, avail - 24 - symW, 7.5);
      for (var k = 0; k < ml.length; k++) {
        _ensure(10);
        if (k == 0) {
          page.fillColor(_ink);
          page.text(left + 24, y - 7.5, fonts.fit(sym, symW - 4, 7.5, bold: true), size: 7.5, bold: true);
        }
        page.fillColor(_grey);
        page.text(left + 24 + symW, y - 7.5, ml[k], size: 7.5);
        y -= 10;
      }
    }
    if (f.source.isNotEmpty) _paragraph(f.source, size: 7, color: _grey, indent: 24);
    y -= 3;
  }

  void _note(TechNote n) {
    const size = 8.0, lead = size * 1.35, pad = 5.0;
    final lines = _wrap(fonts, n.text, avail - 2 * pad, size);
    // a long note may run over pages: drawn in slices
    var i = 0;
    while (i < lines.length) {
      _ensure(lead + 2 * pad);
      final fit = math.max(1, ((y - bottom - 2 * pad) / lead).floor());
      final slice = lines.sublist(i, math.min(lines.length, i + fit));
      final h = slice.length * lead + 2 * pad;
      page.fillColor(n.warning ? _warnFill : _noteFill);
      page.rect(left, y - h, avail, h, fill: true, stroke: false);
      var yy = y - pad;
      for (final l in slice) {
        page.fillColor(_ink);
        page.text(left + pad, yy - size, l, size: size);
        yy -= lead;
      }
      y -= h + 4;
      i += slice.length;
    }
    y -= 2;
  }

  /// A table across the page, columns as wide as their texts and shrunk to
  /// the widest word when it does not fit (the long texts then wrap); the
  /// header repeats on a new page.
  void _table(ReportTable tb) {
    const size = 7.0, pad = 3.0, lineH = 9.5;
    final n = tb.headers.length;
    if (n == 0) return;
    final widths = List<double>.generate(n, (i) => fonts.textWidth(tb.headers[i], size, bold: true) + 2 * pad);
    final minW = List<double>.generate(n, (i) => _widestWord(fonts, tb.headers[i], size, bold: true) + 2 * pad);
    final numeric = List<bool>.generate(n, (i) => _numericColumn(tb, i));
    for (final r in tb.rows) {
      for (var i = 0; i < n && i < r.length; i++) {
        final c = r[i];
        final w = (c is RBar ? 80.0 : fonts.textWidth('$c', size)) + 2 * pad;
        widths[i] = math.max(widths[i], w);
        if (numeric[i]) minW[i] = math.max(minW[i], w);
      }
    }
    var total = widths.fold(0.0, (s, w) => s + w);
    final wrapCol = <int>{};
    if (total > avail) {
      var excess = total - avail;
      final order = List<int>.generate(n, (i) => i)..sort((a, b) => (widths[b] - minW[b]).compareTo(widths[a] - minW[a]));
      for (final i in order) {
        if (excess <= 0) break;
        final reducible = math.max(0.0, widths[i] - math.max(minW[i], numeric[i] ? minW[i] : 40.0));
        final take = math.min(reducible, excess);
        if (take > 0) {
          widths[i] -= take;
          excess -= take;
          if (!numeric[i]) wrapCol.add(i);
        }
      }
      if (excess > 0) {
        final f = avail / (avail + excess);
        for (var i = 0; i < n; i++) {
          widths[i] *= f;
          wrapCol.add(i);
        }
      }
      total = widths.fold(0.0, (s, w) => s + w);
    }
    List<List<String>> cellLines(List<Object> r) => [
      for (var i = 0; i < n; i++)
        if (i >= r.length || r[i] is RBar) [''] else if (wrapCol.contains(i)) _wrap(fonts, '${r[i]}', widths[i] - 2 * pad, size) else [fonts.fit('${r[i]}', widths[i] - 2 * pad, size)],
    ];
    final headerLines = [for (var i = 0; i < n; i++) _wrap(fonts, tb.headers[i], widths[i] - 2 * pad, size, bold: true)];
    final headerRows = headerLines.fold(1, (m, l) => math.max(m, l.length));
    void header({bool cont = false}) {
      page.fillColor(_ink);
      page.text(left, y - 9, fonts.fit(cont ? '${tb.title} ${t('pdf.cont')}' : tb.title, avail, 9, bold: true), size: 9, bold: true);
      y -= 14;
      page.fillColor(_headFill);
      page.rect(left, y - headerRows * lineH - 2, total, headerRows * lineH + 2, fill: true, stroke: false);
      var x = left;
      for (var i = 0; i < n; i++) {
        final lines = headerLines[i];
        for (var k = 0; k < lines.length; k++) {
          final yy = y - (headerRows - lines.length + k + 1) * lineH + 1;
          page.fillColor(_ink);
          page.text(numeric[i] ? x + widths[i] - pad : x + pad, yy, lines[k], size: size, bold: true, align: numeric[i] ? PdfAlign.right : PdfAlign.left);
        }
        x += widths[i];
      }
      y -= headerRows * lineH + 2;
    }

    _ensure(14 + lineH * (headerRows + 2));
    header();
    if (tb.rows.isEmpty) {
      page.fillColor(_grey);
      page.text(left + pad, y - lineH + 2, '—', size: size);
      y -= lineH + 8;
      return;
    }
    for (var r = 0; r < tb.rows.length; r++) {
      final lines = cellLines(tb.rows[r]);
      final rowLines = lines.fold(1, (m, l) => math.max(m, l.length));
      final rowH = rowLines * lineH;
      if (y - rowH < bottom) {
        _newPage();
        header(cont: true);
      }
      if (tb.warn.length > r && tb.warn[r]) {
        page.fillColor(_warnFill);
        page.rect(left, y - rowH, total, rowH, fill: true, stroke: false);
      }
      var x = left;
      for (var i = 0; i < n; i++) {
        final cell = i < tb.rows[r].length ? tb.rows[r][i] : null;
        if (cell is RBar) _bar(cell, x + pad, y - lineH + 2, widths[i] - 2 * pad);
        for (var k = 0; k < lines[i].length; k++) {
          page.fillColor(_ink);
          page.text(numeric[i] ? x + widths[i] - pad : x + pad, y - (k + 1) * lineH + 2.5, lines[i][k], size: size, align: numeric[i] ? PdfAlign.right : PdfAlign.left);
        }
        x += widths[i];
      }
      y -= rowH;
      page.strokeColor(0xFFCFD5DB);
      page.lineWidth(0.3);
      page.dash(false);
      page.line(left, y, left + total, y);
    }
    page.strokeColor(_ink);
    page.lineWidth(0.5);
    page.line(left, y, left + total, y);
    y -= 10;
  }

  void _bar(RBar c, double x, double baseline, double w) {
    if (c.total <= 0 || w <= 0) return;
    final a = x + w * c.start / c.total, b = math.max(a + 1.5, x + w * c.end / c.total);
    page.fillColor(_headFill);
    page.rect(x, baseline + 1.5, w, 2, fill: true, stroke: false);
    page.fillColor(_brand);
    page.rect(a, baseline - 0.25, b - a, 5.5, fill: true, stroke: false);
  }
}

List<String> _wrap(PdfFonts fonts, String s, double width, double size, {bool bold = false}) {
  final words = s.split(RegExp(r'\s+'));
  final lines = <String>[];
  var cur = '';
  for (final w in words) {
    if (w.isEmpty) continue;
    final cand = cur.isEmpty ? w : '$cur $w';
    if (fonts.textWidth(cand, size, bold: bold) <= width + 0.01) {
      cur = cand;
    } else {
      if (cur.isNotEmpty) lines.add(cur);
      cur = fonts.textWidth(w, size, bold: bold) <= width + 0.01 ? w : fonts.fit(w, width, size, bold: bold);
    }
  }
  if (cur.isNotEmpty) lines.add(cur);
  return lines.isEmpty ? [''] : lines;
}

double _widestWord(PdfFonts fonts, String s, double size, {bool bold = false}) => s.split(RegExp(r'\s+')).fold(0.0, (m, w) => math.max(m, fonts.textWidth(w, size, bold: bold)));

/// [v] with [decimals], for the text of the documents (the decimal point of
/// the exports; see [fmt]).
String docNum(double v, [int decimals = 2]) => fmt(v, decimals);
