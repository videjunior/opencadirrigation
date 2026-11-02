/// The PDF of a document package (1.6.0 PRD, PRD-04; the packages and their
/// sections are in doc_package.dart): a cover, the table of contents,
/// numbered sections on A4 pages (portrait, or landscape for wide tables)
/// with a header and the page number, drawing sheets on pages of their own
/// paper, and the signature block.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../design/report_tables.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../translate.dart';
import 'doc_package.dart';
import 'fonts/pdf_fonts.dart';
import 'pdf.dart';
import 'pdf_sheet.dart';
import 'plot_charts.dart';
import 'sheet_canvas.dart';

/// What the user chose for a package.
class DocPackageOptions {
  const DocPackageOptions({required this.profile, this.sections, this.title = '', this.recipient = ''});
  final DocProfile profile;

  /// The section ids to include, in any order (null: the package's
  /// default ones, [defaultSectionIds]); sections that cannot be made for
  /// the project are left out.
  final List<String>? sections;

  /// The title on the cover (empty: the package's own).
  final String title;

  /// Who the document is addressed to (the client, the water agency…).
  final String recipient;
}

/// What a package holds once made: the sections in it, in order, and its
/// table of contents.
class DocPackage {
  const DocPackage(this.bytes, this.sections, this.pageCount, this.contents);
  final Uint8List bytes;
  final List<DocSection> sections;
  final int pageCount;

  /// The entries of the contents: number ("2.1"), title and page (from 1,
  /// the cover).
  final List<(String, String, int)> contents;
}

/// The sections of package [o] that [ctx] can build, in order.
List<DocSection> packageSections(DocContext ctx, DocPackageOptions o) {
  final chosen = o.sections == null ? defaultSectionIds(o.profile, ctx).toSet() : o.sections!.toSet();
  return [
    for (final s in profileSections(o.profile))
      if (chosen.contains(s.id) && s.canBuild(ctx)) s,
    // sections chosen from another package go after the package's own, by their best place
    for (final s in documentSections())
      if (chosen.contains(s.id) && !s.profiles.containsKey(o.profile) && s.canBuild(ctx)) s,
  ];
}

/// Builds the PDF of package [o] for [ctx] ([compress] false leaves the
/// page contents readable, for tests).
DocPackage buildDocumentPackage(DocContext ctx, DocPackageOptions o, {bool compress = true}) {
  final sections = packageSections(ctx, o);
  final w = _DocWriter(ctx, o);
  w.build(sections);
  return DocPackage(w.doc.build(compress: compress), sections, w.doc.pages.length, w.contents);
}

/// The title of package [p] ("Technical memorial").
String docProfileTitle(Translate t, DocProfile p) => t('prd.doc.profile.${p.name}');

const _ink = 0xFF1A1A1A, _grey = 0xFF6B7178, _light = 0xFFE3E8EE, _rule = 0xFFB8C0C8, _warnFill = 0xFFFFE0B2, _accent = 0xFF1E88E5;

/// An entry of the table of contents.
class _TocEntry {
  _TocEntry(this.number, this.title, this.level, this.page);
  final String number, title;
  final int level;

  /// Index of its page among the content pages.
  final int page;
}

class _DocWriter {
  _DocWriter(this.ctx, this.o)
    : fonts = ctx.fonts ?? PdfFonts.shared,
      doc = PdfDocument(
        title: '${ctx.project.meta.name} - ${o.title.isNotEmpty ? o.title : docProfileTitle(ctx.t, o.profile)}',
        author: ctx.project.meta.titleBlock.responsible.isNotEmpty ? ctx.project.meta.titleBlock.responsible : ctx.project.meta.designer,
        subject: docProfileTitle(ctx.t, o.profile),
        fonts: ctx.fonts,
      );
  final DocContext ctx;
  final DocPackageOptions o;
  final PdfFonts fonts;
  final PdfDocument doc;
  Translate get t => ctx.t;
  Project get project => ctx.project;
  String get title => o.title.isNotEmpty ? o.title : docProfileTitle(t, o.profile);

  // the page being written
  PdfPage? _page;
  bool _landscape = false;
  double y = 0; // baseline (pt) from the bottom
  final List<PdfPage> _content = [];
  final Set<PdfPage> _sheetPages = {};
  final List<_TocEntry> _toc = [];

  /// The contents with their page numbers, once [build] has run.
  final List<(String, String, int)> contents = [];

  double get _wMm => _landscape ? 297 : 210;
  double get _hMm => _landscape ? 210 : 297;
  static const _marginMm = 18.0;
  double get left => _marginMm * ptPerMm;
  double get right => (_wMm - _marginMm + 2) * ptPerMm;
  double get top => (_hMm - _marginMm) * ptPerMm;
  double get bottom => (_marginMm + 6) * ptPerMm;
  double get avail => right - left;
  PdfPage get page => _page ??= _newPage();

  PdfPage _newPage() {
    final p = doc.addPage(widthPt: _wMm * ptPerMm, heightPt: _hMm * ptPerMm);
    _content.add(p);
    _page = p;
    // header: the document's title and the project
    p.fillColor(_grey);
    p.text(left, top + 2, fonts.fit(title, avail * 0.55, 7.5), size: 7.5);
    p.text(right, top + 2, fonts.fit(project.meta.name, avail * 0.4, 7.5), size: 7.5, align: PdfAlign.right);
    p.strokeColor(_rule);
    p.lineWidth(0.5);
    p.dash(false);
    p.line(left, top - 2, right, top - 2);
    y = top - 18;
    return p;
  }

  void _ensure(double needed) {
    if (_page == null || y - needed < bottom) _newPage();
  }

  void build(List<DocSection> sections) {
    _cover();
    var n = 0;
    for (final s in sections) {
      final blocks = s.build(ctx);
      if (blocks.isEmpty) continue;
      n++;
      // a section starts on a new page when the orientation changes, else on the same page if there is room
      if (s.landscape != _landscape || _page == null) {
        _landscape = s.landscape;
        _newPage();
      }
      _heading('$n', t(s.titleKey), 1);
      var sub = 0;
      for (final b in blocks) {
        switch (b) {
          case DocHeading h:
            sub++;
            _heading('$n.$sub', h.text, 2);
          case DocParagraph x:
            _paragraph(x.text, bold: x.bold);
          case DocFields f:
            _fields(f.fields);
          case DocBullets l:
            for (final item in l.items) {
              _paragraph('•  $item');
            }
          case DocTable tb:
            _table(tb.table, standards: tb.standards);
          case DocChart c:
            _chart(c.chart);
          case DocSheets sh:
            _sheets(sh.options);
          case DocNote x:
            _paragraph(x.text, size: 7, color: _grey);
          case DocSignature sg:
            _signature(client: sg.client);
          case DocPageBreak _:
            _newPage();
        }
      }
      y -= 6;
    }
    _finish();
  }

  // ------------------------------------------------------------------ cover

  void _cover() {
    final c = doc.addPage(widthPt: 210 * ptPerMm, heightPt: 297 * ptPerMm);
    final canvas = PdfSheetCanvas(c);
    final m = project.meta, tb = m.titleBlock;
    double px(double mm) => mm * ptPerMm;
    const l = 22.0, r = 188.0;
    // logo and company, top
    var logoRight = l;
    final logo = tb.logo;
    if (logo != null) {
      final size = PdfDocument.pixelSize(logo);
      if (size != null && size.$1 > 0 && size.$2 > 0) {
        final s = math.min(45 / size.$1, 28 / size.$2);
        final iw = size.$1 * s, ih = size.$2 * s;
        canvas.image(logo, tb.logoMime, (px(l), px(270 - ih)), (px(l + iw), px(270 - ih)), (px(l), px(270)), maxWidthPx: (iw / 25.4 * 300).ceil(), maxHeightPx: (ih / 25.4 * 300).ceil());
        logoRight = l + iw + 6;
      }
    }
    if (tb.company.trim().isNotEmpty) {
      c.fillColor(_ink);
      c.text(px(logoRight), px(262), fonts.fit(tb.company.trim(), px(r - logoRight), 14, bold: true), size: 14, bold: true);
    }
    c.strokeColor(_accent);
    c.lineWidth(px(0.8));
    c.line(px(l), px(240), px(r), px(240));
    // the document and the project
    c.fillColor(_accent);
    var yy = 222.0;
    for (final line in _wrap(fonts, title, px(r - l), 22, bold: true).take(3)) {
      c.text(px(l), px(yy), line, size: 22, bold: true);
      yy -= 10;
    }
    c.fillColor(_ink);
    for (final line in _wrap(fonts, m.name.isEmpty ? t('name.newProject') : m.name, px(r - l), 15, bold: true).take(3)) {
      c.text(px(l), px(yy), line, size: 15, bold: true);
      yy -= 7.5;
    }
    if (tb.stage.name != 'none') {
      c.fillColor(_grey);
      c.text(px(l), px(yy), fonts.fit(t('prd.stage.${tb.stage.name}'), px(r - l), 10), size: 10);
      yy -= 6;
    }
    // who it is for and where
    yy -= 8;
    final fields = <(String, String)>[
      if (o.recipient.trim().isNotEmpty) (t('prd.doc.recipient'), o.recipient.trim()),
      (t('dlg.client'), m.client),
      (t('prd.tb.property'), m.site),
      (t('prd.tb.municipality'), tb.municipality),
      (t('prd.tb.car'), tb.car),
      (t('prd.tb.permit'), tb.waterPermit),
      (t('prd.tb.drawingNumber'), tb.drawingNumber),
      (t('pdf.rev'), tb.currentRevision),
    ].where((f) => f.$2.trim().isNotEmpty).toList();
    for (final (k, v) in fields) {
      c.fillColor(_grey);
      c.text(px(l), px(yy), fonts.fit(k.toUpperCase(), px(45), 7), size: 7);
      c.fillColor(_ink);
      c.text(px(l + 48), px(yy), fonts.fit(v.replaceAll('\n', ' '), px(r - l - 48), 10), size: 10);
      yy -= 7;
    }
    // the technical lead and the date, at the bottom
    c.strokeColor(_rule);
    c.lineWidth(px(0.3));
    c.line(px(l), px(52), px(r), px(52));
    var by = 44.0;
    void lead(String k, String v) {
      if (v.trim().isEmpty) return;
      c.fillColor(_grey);
      c.text(px(l), px(by), fonts.fit(k.toUpperCase(), px(45), 7), size: 7);
      c.fillColor(_ink);
      c.text(px(l + 48), px(by), fonts.fit(v, px(r - l - 48), 10), size: 10);
      by -= 6.5;
    }

    lead(t('prd.tb.responsible'), tb.responsible.trim().isEmpty ? m.designer : tb.responsible);
    lead(t('prd.tb.registration'), tb.registrationText);
    lead(tb.recordName, tb.responsibilityRecord);
    lead(t('pdf.date'), [if (tb.municipality.trim().isNotEmpty) tb.municipality.trim(), PdfSheetBuilder.dateString(ctx.date)].join(', '));
    c.fillColor(_grey);
    c.text(px(105), px(14), fonts.fit(t('pdf.generated', {'d': PdfSheetBuilder.dateString(DateTime.now())}), px(r - l), 6.5), size: 6.5, align: PdfAlign.center);
  }

  // ------------------------------------------------------------------ content

  void _heading(String number, String text, int level) {
    final size = level == 1 ? 13.0 : 10.5;
    _ensure(size + 30);
    _toc.add(_TocEntry(number, text, level, _content.length - 1));
    page.fillColor(level == 1 ? _accent : _ink);
    page.text(left, y, fonts.fit('$number  $text', avail, size, bold: true), size: size, bold: true);
    y -= level == 1 ? 16 : 13;
  }

  void _paragraph(String s, {double size = 9, int color = _ink, bool bold = false}) {
    for (final para in s.split('\n')) {
      final lines = _wrap(fonts, para, avail, size, bold: bold);
      for (final l in lines) {
        _ensure(size * 1.45);
        page.fillColor(color);
        page.text(left, y, l, size: size, bold: bold);
        y -= size * 1.45;
      }
    }
    y -= 4;
  }

  void _fields(List<(String, String)> fields) {
    final rows = [
      for (final (k, v) in fields)
        if (v.trim().isNotEmpty) (k, v.trim()),
    ];
    if (rows.isEmpty) return;
    final keyW = math.min(avail * 0.34, rows.fold(0.0, (m, r) => math.max(m, fonts.textWidth(r.$1, 8.5))) + 10);
    for (final (k, v) in rows) {
      final lines = _wrap(fonts, v.replaceAll('\n', ' '), avail - keyW, 9);
      _ensure(lines.length * 12.5 + 2);
      page.fillColor(_grey);
      page.text(left, y, fonts.fit(k, keyW - 6, 8.5), size: 8.5);
      page.fillColor(_ink);
      for (var i = 0; i < lines.length; i++) {
        page.text(left + keyW, y - i * 12.5, lines[i], size: 9);
      }
      y -= lines.length * 12.5;
      page.strokeColor(_light);
      page.lineWidth(0.4);
      page.line(left, y + 8, right, y + 8);
    }
    y -= 6;
  }

  void _chart(PlotChart c) {
    const chartMm = 74.0;
    final notes = [for (final n in c.notes) ..._wrap(fonts, n, avail, 7)];
    final h = chartMm * ptPerMm;
    _ensure(h + notes.length * 9.5 + 10);
    final scene = chartScene(c, widthMm: avail / ptPerMm, heightMm: chartMm);
    final y0 = y + 8 - h;
    (double, double) map(Pt p) => (left + p.x * ptPerMm, y0 + p.y * ptPerMm);
    ctx.sheets.drawScene(PdfSheetCanvas(page), scene, map, 1);
    page.dash(false);
    y = y0 - 9;
    page.fillColor(_ink);
    for (final l in notes) {
      page.text(left, y, l, size: 7);
      y -= 9.5;
    }
    y -= 12;
  }

  /// The drawing sheets of [so] on pages of their own; the text goes on
  /// after them on a new page.
  void _sheets(SheetOptions so) {
    if (ctx.sheets.sheetCount(so) == 0) return;
    // a line in the text says where they are
    _paragraph(t('prd.doc.sheetsFollow', {'n': '${ctx.sheets.sheetCount(so)}', 'p': '${so.page.label} ${so.landscape ? t('plot.landscape') : t('plot.portrait')}'}), size: 8.5, color: _grey);
    final before = doc.pages.length;
    ctx.sheets.addSheetPages(doc, so);
    for (final p in doc.pages.sublist(before)) {
      _content.add(p);
      _sheetPages.add(p);
    }
    _page = null;
  }

  void _signature({required bool client}) {
    final m = project.meta, tb = m.titleBlock;
    _ensure(150);
    final place = [if (tb.municipality.trim().isNotEmpty) tb.municipality.trim(), PdfSheetBuilder.dateString(ctx.date)].join(', ');
    page.fillColor(_ink);
    page.text(left, y, place, size: 9.5);
    y -= 52;
    final x0 = left + avail * 0.3, x1 = right - avail * 0.05;
    void block(List<String> lines) {
      page.strokeColor(_ink);
      page.lineWidth(0.6);
      page.dash(false);
      page.line(x0, y, x1, y);
      var yy = y - 12;
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) continue;
        page.fillColor(i == 0 ? _ink : _grey);
        page.text((x0 + x1) / 2, yy, fonts.fit(lines[i], x1 - x0, i == 0 ? 9.5 : 8.5, bold: i == 0), size: i == 0 ? 9.5 : 8.5, bold: i == 0, align: PdfAlign.center);
        yy -= 11.5;
      }
      y = yy - 10;
    }

    final who = tb.responsible.trim().isEmpty ? m.designer.trim() : tb.responsible.trim();
    block([
      who.isEmpty ? t('prd.doc.signatureLead') : who,
      if (who.isNotEmpty) t('prd.doc.signatureLead'),
      tb.registrationText,
      if (tb.responsibilityRecord.trim().isNotEmpty) '${tb.recordName} ${tb.responsibilityRecord.trim()}',
      tb.company.trim(),
    ]);
    if (client) {
      _ensure(90);
      y -= 34;
      block([m.client.trim().isEmpty ? t('prd.doc.signatureClient') : m.client.trim(), if (m.client.trim().isNotEmpty) t('prd.doc.signatureClient'), t('prd.doc.acceptance')]);
    }
  }

  // ------------------------------------------------------------------ tables

  void _table(ReportTable tb, {bool standards = true}) {
    const size = 7.0, pad = 3.0, lineH = 9.5;
    final n = tb.headers.length;
    if (n == 0) return;
    final widths = List<double>.generate(n, (i) => fonts.textWidth(tb.headers[i], size, bold: true) + 2 * pad);
    final minW = List<double>.generate(n, (i) => _widestWord(fonts, tb.headers[i], size, bold: true) + 2 * pad);
    final numeric = List<bool>.generate(n, (i) => tb.rows.isNotEmpty && tb.rows.every((r) => i >= r.length || r[i] is num || r[i] is RNum || '${r[i]}'.isEmpty));
    for (final r in tb.rows) {
      for (var i = 0; i < n && i < r.length; i++) {
        final cw = (r[i] is RBar ? 110.0 : fonts.textWidth('${r[i]}', size)) + 2 * pad;
        widths[i] = math.max(widths[i], cw);
        if (numeric[i]) minW[i] = math.max(minW[i], cw);
      }
    }
    var total = widths.fold(0.0, (s, w) => s + w);
    final wrapCol = <int>{};
    if (total > avail) {
      var excess = total - avail;
      final order = List<int>.generate(n, (i) => i)..sort((a, b) => (widths[b] - minW[b]).compareTo(widths[a] - minW[a]));
      for (final i in order) {
        if (excess <= 0) break;
        final reducible = math.max(0.0, widths[i] - math.max(minW[i], numeric[i] ? minW[i] : 48.0));
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
        i < r.length && r[i] is! RBar ? (wrapCol.contains(i) ? _wrap(fonts, '${r[i]}', widths[i] - 2 * pad, size) : [fonts.fit('${r[i]}', widths[i] - 2 * pad, size)]) : [''],
    ];
    final headerLines = [for (var i = 0; i < n; i++) _wrap(fonts, tb.headers[i], widths[i] - 2 * pad, size, bold: true)];
    final headerRows = headerLines.fold(1, (m, l) => math.max(m, l.length));
    final note = standards && tb.standards.isNotEmpty ? _wrap(fonts, tb.standards, avail, 6.5) : const <String>[];
    void header({bool cont = false}) {
      page.fillColor(_ink);
      page.text(left, y, fonts.fit(cont ? '${tb.title} ${t('pdf.cont')}' : tb.title, avail, 9.5, bold: true), size: 9.5, bold: true);
      y -= 11.5;
      if (!cont && note.isNotEmpty) {
        page.fillColor(_grey);
        for (final l in note) {
          page.text(left, y + 2, l, size: 6.5);
          y -= 8.5;
        }
        y -= 1.5;
      }
      page.fillColor(_light);
      page.rect(left, y - 3 - (headerRows - 1) * lineH, total, headerRows * lineH + 1, fill: true, stroke: false);
      page.fillColor(_ink);
      var x = left;
      for (var i = 0; i < n; i++) {
        final lines = headerLines[i];
        for (var k = 0; k < lines.length; k++) {
          final yy = y - (headerRows - lines.length + k) * lineH;
          page.text(numeric[i] ? x + widths[i] - pad : x + pad, yy, lines[k], size: size, bold: true, align: numeric[i] ? PdfAlign.right : PdfAlign.left);
        }
        x += widths[i];
      }
      y -= headerRows * lineH;
    }

    _ensure(12 + note.length * 8.5 + lineH * (headerRows + 2));
    header();
    if (tb.rows.isEmpty) {
      page.fillColor(_grey);
      page.text(left + pad, y, '—', size: size);
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
        page.rect(left, y - 3, total, rowH, fill: true, stroke: false);
      }
      page.strokeColor(0xFFCFD5DB);
      page.lineWidth(0.3);
      page.dash(false);
      page.line(left, y - 3, left + total, y - 3);
      page.fillColor(_ink);
      var x = left;
      for (var i = 0; i < n; i++) {
        final cell = i < tb.rows[r].length ? tb.rows[r][i] : null;
        if (cell is RBar) _bar(cell, x + pad, y, widths[i] - 2 * pad);
        for (var k = 0; k < lines[i].length; k++) {
          page.text(numeric[i] ? x + widths[i] - pad : x + pad, y - k * lineH, lines[i][k], size: size, align: numeric[i] ? PdfAlign.right : PdfAlign.left);
        }
        x += widths[i];
      }
      y -= rowH;
    }
    page.strokeColor(_ink);
    page.lineWidth(0.5);
    page.line(left, y - 3, left + total, y - 3);
    y -= 14;
  }

  void _bar(RBar c, double x, double baseline, double w) {
    if (c.total <= 0 || w <= 0) return;
    final a = x + w * c.start / c.total, b = math.max(a + 1.5, x + w * c.end / c.total);
    page.fillColor(_light);
    page.rect(x, baseline + 1.5, w, 2, fill: true, stroke: false);
    page.fillColor(_accent);
    page.rect(a, baseline - 0.25, b - a, 5.5, fill: true, stroke: false);
    page.fillColor(_ink);
  }

  // ------------------------------------------------------------------ contents, numbers

  void _finish() {
    // the table of contents, on pages put right after the cover
    const perPage = 46;
    final pages = math.max(1, (_toc.length / perPage).ceil());
    final tocPages = <PdfPage>[];
    for (var k = 0; k < pages; k++) {
      final p = doc.addPage(widthPt: 210 * ptPerMm, heightPt: 297 * ptPerMm);
      tocPages.add(p);
    }
    doc.pages
      ..removeRange(doc.pages.length - pages, doc.pages.length)
      ..insertAll(1, tocPages);
    // page numbers: cover 1, contents 2…, then the content pages
    int number(int contentIndex) => 2 + pages + contentIndex;
    contents.addAll([for (final e in _toc) (e.number, e.title, number(e.page))]);
    const l = 22.0 * ptPerMm, r = 188.0 * ptPerMm;
    for (var k = 0; k < pages; k++) {
      final p = tocPages[k];
      var yy = (297 - 25) * ptPerMm;
      if (k == 0) {
        p.fillColor(_accent);
        p.text(l, yy, t('prd.doc.contents'), size: 16, bold: true);
        yy -= 30;
      }
      for (final e in _toc.skip(k * perPage).take(perPage)) {
        final indent = e.level == 1 ? 0.0 : 14.0;
        final size = e.level == 1 ? 10.0 : 9.0;
        final pageNo = '${number(e.page)}';
        final pw = fonts.textWidth(pageNo, size);
        final label = fonts.fit('${e.number}  ${e.title}', r - l - indent - pw - 24, size, bold: e.level == 1);
        p.fillColor(e.level == 1 ? _ink : _grey);
        p.text(l + indent, yy, label, size: size, bold: e.level == 1);
        p.text(r, yy, pageNo, size: size, align: PdfAlign.right);
        // dotted leader
        final from = l + indent + fonts.textWidth(label, size, bold: e.level == 1) + 4, to = r - pw - 4;
        if (to > from) {
          p.strokeColor(_rule);
          p.lineWidth(0.5);
          p.dash(true, 0.8, 2.2);
          p.line(from, yy + 1, to, yy + 1);
          p.dash(false);
        }
        yy -= e.level == 1 ? 16 : 13;
      }
    }
    // footers of every page but the cover and the drawing sheets (they number themselves)
    final total = doc.pages.length;
    final generated = t('pdf.generated', {'d': PdfSheetBuilder.dateString(DateTime.now())});
    final code = project.meta.titleBlock.drawingNumber.trim();
    for (var i = 1; i < total; i++) {
      final p = doc.pages[i];
      if (_sheetPages.contains(p)) continue;
      final pl = _marginMm * ptPerMm, pr = p.width - (_marginMm - 2) * ptPerMm;
      p.fillColor(_grey);
      p.text(pl, 12 * ptPerMm, fonts.fit(generated, (pr - pl) * 0.45, 6.5), size: 6.5);
      if (code.isNotEmpty) p.text((pl + pr) / 2, 12 * ptPerMm, fonts.fit(code, (pr - pl) * 0.2, 6.5), size: 6.5, align: PdfAlign.center);
      p.text(pr, 12 * ptPerMm, t('pdf.page', {'i': '${i + 1}', 'n': '$total'}), size: 6.5, align: PdfAlign.right);
    }
  }
}

List<String> _wrap(PdfFonts fonts, String s, double width, double size, {bool bold = false}) {
  final lines = <String>[];
  var cur = '';
  for (final w in s.split(RegExp(r'\s+'))) {
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
