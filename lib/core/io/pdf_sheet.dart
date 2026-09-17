/// Plot sheets and tabular report pages rendered with [PdfDocument].
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../design/report_tables.dart';
import '../design/results.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../translate.dart';
import '../units.dart';
import 'pdf.dart';
import 'plot.dart';

enum PageSize {
  a4(210, 297),
  a3(297, 420),
  a2(420, 594),
  a1(594, 841),
  a0(841, 1189),
  letter(215.9, 279.4),
  tabloid(279.4, 431.8);

  const PageSize(this.shortMm, this.longMm);
  final double shortMm;
  final double longMm;
  String get label => switch (this) { PageSize.letter => 'Letter', PageSize.tabloid => 'Tabloid', _ => name.toUpperCase() };
}

class SheetOptions {
  const SheetOptions({this.page = PageSize.a3, this.landscape = true, this.scale, this.marginMm = 10, this.wettedRadii = true, this.labels = true, this.legend = true, this.includeReports = false, this.bomOnSheet = true});
  final PageSize page;
  final bool landscape;

  /// Scale denominator (1:N); null fits the drawing to the sheet.
  final double? scale;
  final double marginMm;
  final bool wettedRadii;
  final bool labels;
  final bool legend;
  final bool includeReports;

  /// Bill of materials table in the side column of the sheet (when the
  /// project has design results).
  final bool bomOnSheet;

  double get widthMm => landscape ? page.longMm : page.shortMm;
  double get heightMm => landscape ? page.shortMm : page.longMm;

  SheetOptions copyWith({PageSize? page, bool? landscape, double? scale, bool clearScale = false, double? marginMm, bool? wettedRadii, bool? labels, bool? legend, bool? includeReports, bool? bomOnSheet}) => SheetOptions(
    page: page ?? this.page,
    landscape: landscape ?? this.landscape,
    scale: clearScale ? null : (scale ?? this.scale),
    marginMm: marginMm ?? this.marginMm,
    wettedRadii: wettedRadii ?? this.wettedRadii,
    labels: labels ?? this.labels,
    legend: legend ?? this.legend,
    includeReports: includeReports ?? this.includeReports,
    bomOnSheet: bomOnSheet ?? this.bomOnSheet,
  );
}

/// Sheet geometry: usable drawing area (mm) for a given option set.
class SheetLayout {
  SheetLayout(this.o, {required this.hasLegend, double? legendWidthMm}) : legendWidth = legendWidthMm ?? legendMm;
  final SheetOptions o;
  final bool hasLegend;

  /// Width of the side column (legend + materials table), mm.
  final double legendWidth;
  static const titleBlockMm = 30.0;
  static const legendMm = 46.0;

  /// Side column width when the materials table is on the sheet.
  static const legendWithBomMm = 82.0;
  static const padMm = 3.0;

  double get frameX => o.marginMm;
  double get frameY => o.marginMm;
  double get frameW => o.widthMm - 2 * o.marginMm;
  double get frameH => o.heightMm - 2 * o.marginMm;
  double get areaX => frameX;
  double get areaY => frameY + titleBlockMm;
  double get areaW => frameW - (hasLegend ? legendWidth : 0);
  double get areaH => frameH - titleBlockMm;
  double get drawW => areaW - 2 * padMm;
  double get drawH => areaH - 2 * padMm;
}

const _ink = 0xFF1A1A1A;
const _grey = 0xFF8A8F94;
const _lightGrey = 0xFFE3E8EE;
const _warnFill = 0xFFFFE0B2;

class PdfSheetBuilder {
  PdfSheetBuilder({required this.project, this.results, required this.t, this.layerNames = const {}, this.units = Units.metric});
  final Project project;
  final DesignResults? results;
  final Translate t;
  final Map<String, String> layerNames;
  final Units units;

  String layerLabel(String l) => layerNames[l] ?? l;

  static String dateString(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Scale used for the sheet (auto-fit when [SheetOptions.scale] is null).
  double sheetScale(SheetOptions o) {
    if (o.scale != null && o.scale! > 0) return o.scale!;
    final b = project.bounds;
    if (b.isEmpty) return 1000;
    final lay = SheetLayout(o, hasLegend: o.legend || _showBom(o), legendWidthMm: _showBom(o) ? SheetLayout.legendWithBomMm : null);
    final inflated = b.inflate(math.max(b.width, b.height) * 0.04 + 1);
    return fitScale(inflated, lay.drawW, lay.drawH);
  }

  /// Drawing sheet with frame, title block, legend, north arrow and scale bar.
  Uint8List buildSheet(SheetOptions o, {List<ReportTable> reports = const []}) {
    final doc = PdfDocument(title: project.meta.name, author: project.meta.designer, subject: t('pdf.subtitle'));
    addSheetPage(doc, o);
    if (o.includeReports) addReportPages(doc, reports);
    return doc.build();
  }

  /// Report document only.
  Uint8List buildReport(List<ReportTable> tables) {
    final doc = PdfDocument(title: '${project.meta.name} - ${t('pdf.reportTitle')}', author: project.meta.designer, subject: t('pdf.reportTitle'));
    addReportPages(doc, tables);
    return doc.build();
  }

  bool _showBom(SheetOptions o) => o.bomOnSheet && (results?.bom.isNotEmpty ?? false);

  void addSheetPage(PdfDocument doc, SheetOptions o) {
    final scale = sheetScale(o);
    final unitsPerMm = scale / 1000;
    final scene = buildPlotScene(project, results: results, unitsPerMm: unitsPerMm, options: PlotOptions(wettedRadii: o.wettedRadii, labels: o.labels, results: o.labels), units: units, t: t);
    final showBom = _showBom(o);
    final lay = SheetLayout(o, hasLegend: (o.legend && scene.layers.isNotEmpty) || showBom, legendWidthMm: showBom ? SheetLayout.legendWithBomMm : null);
    final page = doc.addPage(widthPt: o.widthMm * ptPerMm, heightPt: o.heightMm * ptPerMm);
    double px(double mm) => mm * ptPerMm;
    // frame
    page.strokeColor(_ink);
    page.lineWidth(px(0.5));
    page.rect(px(lay.frameX), px(lay.frameY), px(lay.frameW), px(lay.frameH));
    page.lineWidth(px(0.25));
    page.line(px(lay.areaX), px(lay.areaY), px(lay.frameX + lay.frameW), px(lay.areaY));
    if (lay.hasLegend) page.line(px(lay.areaX + lay.areaW), px(lay.areaY), px(lay.areaX + lay.areaW), px(lay.frameY + lay.frameH));
    // drawing (clipped)
    final b = scene.bounds.isEmpty ? project.bounds : scene.bounds;
    final cx = b.isEmpty ? 0.0 : b.center.x, cy = b.isEmpty ? 0.0 : b.center.y;
    final ox = lay.areaX + lay.areaW / 2, oy = lay.areaY + lay.areaH / 2; // paper centre (mm)
    (double, double) map(Pt p) => (px(ox + (p.x - cx) / unitsPerMm), px(oy + (p.y - cy) / unitsPerMm));
    page.save();
    page.clipRect(px(lay.areaX) + 0.5, px(lay.areaY) + 0.5, px(lay.areaW) - 1, px(lay.areaH) - 1);
    drawScene(page, scene, map, unitsPerMm);
    page.restore();
    // north arrow (top-right of the drawing area)
    final nx = lay.areaX + lay.areaW - 10, ny = lay.areaY + lay.areaH - 14;
    page.strokeColor(_ink);
    page.fillColor(_ink);
    page.lineWidth(px(0.3));
    page.path([map0(px(nx), px(ny)), map0(px(nx - 2.2), px(ny - 3)), map0(px(nx), px(ny + 7)), map0(px(nx + 2.2), px(ny - 3))], close: true, fill: true);
    page.text(px(nx), px(ny + 8.5), 'N', size: 9, bold: true, align: PdfAlign.center);
    // scale bar (bottom-left)
    final barLen = niceBarLength(unitsPerMm, 40);
    final barMm = barLen / unitsPerMm;
    final bx = lay.areaX + 6, by = lay.areaY + 6;
    page.lineWidth(px(0.25));
    for (var i = 0; i < 4; i++) {
      final seg = barMm / 4;
      page.fillColor(i.isEven ? _ink : 0xFFFFFFFF);
      page.rect(px(bx + i * seg), px(by), px(seg), px(1.6), fill: true, stroke: true);
    }
    page.fillColor(_ink);
    page.text(px(bx), px(by + 2.6), '0', size: 6.5, align: PdfAlign.center);
    page.text(px(bx + barMm / 2), px(by + 2.6), fmt(units.lengthFromSi(barLen / 2), 0), size: 6.5, align: PdfAlign.center);
    page.text(px(bx + barMm), px(by + 2.6), '${fmt(units.lengthFromSi(barLen), 0)} ${units.lengthLabel}', size: 6.5, align: PdfAlign.center);
    // legend and materials table (side column)
    var sideY = lay.frameY + lay.frameH - 8;
    if (lay.hasLegend && o.legend && scene.layers.isNotEmpty) sideY = _legend(page, scene, lay, px);
    if (showBom) _bomBlock(page, lay, px, sideY - 4);
    // title block
    _titleBlock(page, lay, scale, px);
  }

  static (double, double) map0(double x, double y) => (x, y);

  void drawScene(PdfPage page, PlotScene scene, (double, double) Function(Pt) map, double unitsPerMm) {
    for (final it in scene.items) {
      switch (it) {
        case PlotPath p:
          page.strokeColor(p.color);
          page.lineWidth(p.widthMm * ptPerMm);
          page.dash(p.dashed, p.widthMm * ptPerMm * 6, p.widthMm * ptPerMm * 4);
          if (p.fillColor != null) page.fillColor(p.fillColor!);
          page.path(p.points.map(map).toList(), close: p.closed, fill: p.fillColor != null);
        case PlotCircle c:
          final (x, y) = map(c.center);
          if (c.stroke) {
            page.strokeColor(c.color);
            page.lineWidth(c.widthMm * ptPerMm);
            page.dash(false);
          }
          if (c.fillColor != null) page.fillColor(c.fillColor!);
          page.circle(x, y, c.radius / unitsPerMm * ptPerMm, stroke: c.stroke, fill: c.fillColor != null);
        case PlotText tx:
          final (x, y) = map(tx.position);
          final size = tx.heightMm * ptPerMm / 0.72;
          page.fillColor(tx.color);
          final align = switch (tx.anchor) { PlotAnchor.bottomCenter || PlotAnchor.center => PdfAlign.center, PlotAnchor.bottomRight => PdfAlign.right, _ => PdfAlign.left };
          final dy = tx.anchor == PlotAnchor.center || tx.anchor == PlotAnchor.centerLeft ? -tx.heightMm * ptPerMm / 2 : 0.0;
          if (tx.rotationDeg != 0) {
            final a = tx.rotationDeg * math.pi / 180;
            page.text(x - dy * math.sin(a), y + dy * math.cos(a), tx.text, size: size, bold: tx.bold, rotationDeg: tx.rotationDeg, align: align);
          } else {
            page.text(x, y + dy, tx.text, size: size, bold: tx.bold, align: align);
          }
      }
    }
  }

  /// Draws the legend in the side column; returns the y (mm) below it.
  double _legend(PdfPage page, PlotScene scene, SheetLayout lay, double Function(double) px) {
    final x0 = lay.areaX + lay.areaW + 4;
    var y = lay.frameY + lay.frameH - 8;
    page.fillColor(_ink);
    page.text(px(x0), px(y), t('pdf.legend'), size: 9, bold: true);
    y -= 6;
    for (final e in scene.layers.entries) {
      if (y < lay.areaY + 4) break;
      page.strokeColor(e.value);
      page.fillColor(e.value);
      page.lineWidth(px(0.6));
      page.dash(false);
      page.line(px(x0), px(y + 1), px(x0 + 8), px(y + 1));
      page.fillColor(_ink);
      page.text(px(x0 + 10), px(y), PdfPage.fit(layerLabel(e.key), px(lay.legendWidth - 16), 7), size: 7);
      y -= 4.6;
    }
    return y;
  }

  /// Compact bill of materials in the side column (description, quantity,
  /// unit); rows that do not fit are counted in a closing line.
  void _bomBlock(PdfPage page, SheetLayout lay, double Function(double) px, double top) {
    final r = results;
    if (r == null || r.bom.isEmpty) return;
    final x0 = lay.areaX + lay.areaW + 4;
    final w = lay.legendWidth - 8;
    final qtyW = 16.0;
    var y = math.min(top, lay.frameY + lay.frameH - 8);
    page.strokeColor(_ink);
    page.lineWidth(px(0.25));
    page.line(px(x0), px(y + 3), px(x0 + w), px(y + 3));
    page.fillColor(_ink);
    page.text(px(x0), px(y - 1), t('pdf.bom'), size: 9, bold: true);
    y -= 5.5;
    page.fillColor(_grey);
    page.text(px(x0), px(y), t('rep.description').toUpperCase(), size: 5.5);
    page.text(px(x0 + w), px(y), t('pdf.qty').toUpperCase(), size: 5.5, align: PdfAlign.right);
    y -= 3.6;
    final lines = r.bom.where((l) => l.quantity > 0).toList()..sort((a, b) => a.category == b.category ? a.description.compareTo(b.description) : a.category.compareTo(b.category));
    String? lastCat;
    var shown = 0;
    for (final l in lines) {
      final needed = l.category != lastCat ? 7.6 : 3.8;
      if (y - needed < lay.areaY + 8) break;
      if (l.category != lastCat) {
        lastCat = l.category;
        page.fillColor(_ink);
        page.text(px(x0), px(y), PdfPage.fit(t(l.category), px(w), 6.5, bold: true), size: 6.5, bold: true);
        y -= 3.8;
      }
      page.fillColor(_ink);
      page.text(px(x0 + 2), px(y), PdfPage.fit(l.description, px(w - qtyW - 3), 6), size: 6);
      final qty = l.unit == 'm' ? fmt(l.quantity, 0) : fmt(l.quantity, 0);
      page.text(px(x0 + w), px(y), '$qty ${l.unit}', size: 6, align: PdfAlign.right);
      y -= 3.8;
      shown++;
    }
    if (shown < lines.length) {
      page.fillColor(_grey);
      page.text(px(x0), px(y), PdfPage.fit(t('pdf.bomMore', {'n': '${lines.length - shown}'}), px(w), 5.5), size: 5.5);
    }
  }

  void _titleBlock(PdfPage page, SheetLayout lay, double scale, double Function(double) px) {
    final m = project.meta;
    final x0 = lay.frameX, y0 = lay.frameY, w = lay.frameW;
    final h = SheetLayout.titleBlockMm;
    final colA = w * 0.44, colB = w * 0.32;
    const row = 4.5;
    page.strokeColor(_ink);
    page.lineWidth(px(0.25));
    page.line(px(x0 + colA), px(y0), px(x0 + colA), px(y0 + h));
    page.line(px(x0 + colA + colB), px(y0), px(x0 + colA + colB), px(y0 + h));
    page.fillColor(_ink);
    void kv(double x, double yy, String k, String v, double maxW) {
      final key = k.toUpperCase();
      final kw = PdfPage.textWidth(key, 5.5);
      page.fillColor(_grey);
      page.text(px(x), px(yy), key, size: 5.5);
      page.fillColor(_ink);
      page.text(px(x) + kw + 4, px(yy), PdfPage.fit(v, px(maxW) - kw - 6, 7.5), size: 7.5);
    }

    // column A: project, client, site, designer, notes
    var y = y0 + h - 6;
    page.text(px(x0 + 3), px(y), PdfPage.fit(m.name.isEmpty ? t('name.newProject') : m.name, px(colA - 6), 12, bold: true), size: 12, bold: true);
    y -= 5.5;
    kv(x0 + 3, y, t('dlg.client'), m.client, colA - 6);
    y -= row;
    kv(x0 + 3, y, t('dlg.site'), m.site, colA - 6);
    y -= row;
    kv(x0 + 3, y, t('dlg.designer'), m.designer, colA - 6);
    y -= row;
    final zones = project.entities.whereType<ControlValveEntity>().length;
    final outlets = results != null && results!.zones.isNotEmpty
        ? results!.zones.values.fold<int>(0, (a, z) => a + z.emitterCount)
        : project.entities.fold<int>(0, (a, e) => a + (e is SpraylineEntity ? e.outletCount : (e is OutletEntity ? 1 : 0)));
    kv(x0 + 3, y, m.notes.trim().isNotEmpty ? t('dlg.notes') : t('pdf.summary'), m.notes.trim().isNotEmpty ? m.notes.replaceAll('\n', ' ') : '$zones / $outlets', colA - 6);
    // column B: date, scale, CRS, origin, sheet
    final xb = x0 + colA + 3;
    y = y0 + h - 6;
    kv(xb, y, t('pdf.date'), dateString(DateTime.now()), colB - 6);
    y -= row;
    kv(xb, y, t('pdf.scale'), '1:${scale.round()}  (${_pageLabel(lay.o)})', colB - 6);
    y -= row;
    final g = m.georef;
    kv(xb, y, t('pdf.crs'), g == null ? t('pdf.local') : g.crsName, colB - 6);
    y -= row;
    kv(xb, y, t('pdf.origin'), g == null ? '0 / 0' : 'E ${g.originEasting.toStringAsFixed(0)}  N ${g.originNorthing.toStringAsFixed(0)}', colB - 6);
    y -= row;
    kv(xb, y, t('pdf.sheet'), '1/1', colB - 6);
    // column C: branding
    final xc = x0 + colA + colB;
    final wc = w - colA - colB;
    page.fillColor(0xFF1E88E5);
    page.text(px(xc + wc / 2), px(y0 + h - 10), 'OpenCADIrrigation', size: 11, bold: true, align: PdfAlign.center);
    page.fillColor(_grey);
    page.text(px(xc + wc / 2), px(y0 + h - 15), PdfPage.fit(t('pdf.subtitle'), px(wc - 4), 6.5), size: 6.5, align: PdfAlign.center);
    page.text(px(xc + wc / 2), px(y0 + 4), PdfPage.fit(t('pdf.generated', {'d': dateString(DateTime.now())}), px(wc - 4), 5.5), size: 5.5, align: PdfAlign.center);
  }

  String _pageLabel(SheetOptions o) => '${o.page.label} ${o.landscape ? t('plot.landscape') : t('plot.portrait')}';

  // ------------------------------------------------------------------ reports

  void addReportPages(PdfDocument doc, List<ReportTable> tables) {
    final pages = _ReportPages(doc, this);
    pages.begin();
    if (tables.isEmpty || tables.every((tb) => tb.key == 'water' || tb.key == 'messages')) {
      pages.paragraph(t('pdf.noResults'));
    }
    pages.paramsBlock();
    for (final tb in tables) {
      pages.table(tb);
    }
    pages.finish();
  }
}

/// A4 landscape report pages with header/footer and paginated tables.
class _ReportPages {
  _ReportPages(this.doc, this.b);
  final PdfDocument doc;
  final PdfSheetBuilder b;
  static const wMm = 297.0, hMm = 210.0, margin = 12.0;
  final List<PdfPage> pages = [];
  late PdfPage page;
  double y = 0; // current baseline (pt), from bottom

  double get left => margin * ptPerMm;
  double get right => (wMm - margin) * ptPerMm;
  double get bottom => (margin + 6) * ptPerMm;
  double get avail => right - left;

  void begin() => _newPage();

  void _newPage() {
    page = doc.addPage(widthPt: wMm * ptPerMm, heightPt: hMm * ptPerMm);
    pages.add(page);
    final top = (hMm - margin) * ptPerMm;
    page.fillColor(_ink);
    page.text(left, top - 10, b.t('pdf.reportTitle'), size: 12, bold: true);
    page.fillColor(_grey);
    final m = b.project.meta;
    final sub = [m.name, if (m.client.isNotEmpty) m.client, if (m.site.isNotEmpty) m.site].join(' · ');
    page.text(left, top - 21, PdfPage.fit(sub, avail - 120, 8), size: 8);
    page.text(right, top - 21, PdfSheetBuilder.dateString(DateTime.now()), size: 8, align: PdfAlign.right);
    page.strokeColor(_ink);
    page.lineWidth(0.6);
    page.line(left, top - 25, right, top - 25);
    y = top - 36;
  }

  void finish() {
    for (var i = 0; i < pages.length; i++) {
      final p = pages[i];
      p.fillColor(_grey);
      p.text(left, margin * ptPerMm, b.t('pdf.generated', {'d': PdfSheetBuilder.dateString(DateTime.now())}), size: 6.5);
      p.text(right, margin * ptPerMm, b.t('pdf.page', {'i': '${i + 1}', 'n': '${pages.length}'}), size: 6.5, align: PdfAlign.right);
    }
  }

  void _ensure(double needed) {
    if (y - needed < bottom) _newPage();
  }

  void paragraph(String s) {
    final lines = _wrap(s, avail, 8);
    _ensure(lines.length * 11.0);
    page.fillColor(_ink);
    for (final l in lines) {
      page.text(left, y, l, size: 8);
      y -= 11;
    }
    y -= 6;
  }

  void paramsBlock() {
    final p = b.project.params;
    final u = b.units;
    final t = b.t;
    final items = <String>[
      '${t('dlg.frictionFormula')}: ${p.frictionMethod.name == 'hazenWilliams' ? 'Hazen-Williams' : 'Darcy-Weisbach'}',
      '${t('dlg.waterTemp')}: ${fmt(p.waterTempC, 0)} °C',
      '${t('dlg.vZone')}: ${fmt(u.velocityFromSi(p.maxZoneVelocity), 2)} ${u.velocityLabel}',
      '${t('dlg.vMain')}: ${fmt(u.velocityFromSi(p.maxMainlineVelocity), 2)} ${u.velocityLabel}',
      '${t('dlg.minorPct')}: ${fmt(p.minorLossPct, 0)} %',
      '${t('dlg.interest')}: ${fmt(p.interestRate * 100, 1)} % · ${t('dlg.term')}: ${p.termYears}',
      '${t('dlg.energyCost', {'c': p.currency})}: ${fmt(p.powerCostPerKwh, 2)}',
    ];
    _ensure(30);
    page.fillColor(_ink);
    page.text(left, y, b.t('pdf.params'), size: 10, bold: true);
    y -= 12;
    final colW = avail / 4;
    for (var i = 0; i < items.length; i++) {
      final col = i % 4, row = i ~/ 4;
      page.text(left + col * colW, y - row * 10, PdfPage.fit(items[i], colW - 6, 7), size: 7);
    }
    y -= ((items.length + 3) ~/ 4) * 10 + 8;
  }

  void table(ReportTable tb) {
    const size = 7.0, pad = 3.0, lineH = 9.5;
    final n = tb.headers.length;
    if (n == 0) return;
    // natural widths; columns may shrink down to their widest word (headers
    // and long text cells then wrap onto several lines)
    final widths = List<double>.generate(n, (i) => PdfPage.textWidth(tb.headers[i], size, bold: true) + 2 * pad);
    final minW = List<double>.generate(n, (i) => _widestWord(tb.headers[i], size, bold: true) + 2 * pad);
    final numeric = List<bool>.generate(n, (i) => tb.rows.isNotEmpty && tb.rows.every((r) => i >= r.length || r[i] is num || r[i] is RNum || '${r[i]}'.isEmpty));
    for (final r in tb.rows) {
      for (var i = 0; i < n && i < r.length; i++) {
        final w = PdfPage.textWidth('${r[i]}', size) + 2 * pad;
        widths[i] = math.max(widths[i], w);
        if (numeric[i]) minW[i] = math.max(minW[i], w);
      }
    }
    var total = widths.fold(0.0, (s, w) => s + w);
    final wrapCol = <int>{};
    if (total > avail) {
      var excess = total - avail;
      final order = List<int>.generate(n, (i) => i)..sort((a, b2) => (widths[b2] - minW[b2]).compareTo(widths[a] - minW[a]));
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
        // last resort: shrink everything proportionally
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
        i < r.length ? (wrapCol.contains(i) ? _wrap('${r[i]}', widths[i] - 2 * pad, size) : [PdfPage.fit('${r[i]}', widths[i] - 2 * pad, size)]) : [''],
    ];
    final headerLines = [for (var i = 0; i < n; i++) _wrap(tb.headers[i], widths[i] - 2 * pad, size, bold: true)];
    final headerRows = headerLines.fold(1, (m, l) => math.max(m, l.length));
    void header({bool cont = false}) {
      page.fillColor(_ink);
      page.text(left, y, cont ? '${tb.title} ${b.t('pdf.cont')}' : tb.title, size: 10, bold: true);
      y -= 12;
      page.fillColor(_lightGrey);
      page.rect(left, y - 3 - (headerRows - 1) * lineH, total, headerRows * lineH + 1, fill: true, stroke: false);
      page.fillColor(_ink);
      var x = left;
      for (var i = 0; i < n; i++) {
        final lines = headerLines[i];
        for (var k = 0; k < lines.length; k++) {
          // bottom-align multi-line headers
          final yy = y - (headerRows - lines.length + k) * lineH;
          page.text(numeric[i] ? x + widths[i] - pad : x + pad, yy, lines[k], size: size, bold: true, align: numeric[i] ? PdfAlign.right : PdfAlign.left);
        }
        x += widths[i];
      }
      y -= headerRows * lineH;
    }

    _ensure(12 + lineH * (headerRows + 2));
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
}

List<String> _wrap(String s, double width, double size, {bool bold = false}) {
  final words = s.split(RegExp(r'\s+'));
  final lines = <String>[];
  var cur = '';
  for (final w in words) {
    final cand = cur.isEmpty ? w : '$cur $w';
    if (PdfPage.textWidth(cand, size, bold: bold) <= width + 0.01) {
      cur = cand;
    } else {
      if (cur.isNotEmpty) lines.add(cur);
      cur = PdfPage.textWidth(w, size, bold: bold) <= width + 0.01 ? w : PdfPage.fit(w, width, size, bold: bold);
    }
  }
  if (cur.isNotEmpty) lines.add(cur);
  return lines.isEmpty ? [''] : lines;
}

double _widestWord(String s, double size, {bool bold = false}) => s.split(RegExp(r'\s+')).fold(0.0, (m, w) => math.max(m, PdfPage.textWidth(w, size, bold: bold)));
