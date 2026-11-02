/// Plot sheets and tabular report pages rendered with [PdfDocument].
///
/// A PDF holds the drawing sheets of a set (an overview, one sheet per zone
/// or per irrigated area, windows chosen by the user; see sheet_set.dart),
/// the sheets of construction details (details.dart), the report pages and
/// the charts of the design (plot_charts.dart). Sheets are drawn on a
/// [SheetCanvas], so the same layout also records a sheet for the raster
/// (PNG) export of the app.
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
import 'details.dart';
import 'pdf.dart';
import 'plot.dart';
import 'plot_charts.dart';
import 'sheet_canvas.dart';
import 'sheet_grid.dart';
import 'sheet_set.dart';
import 'sheet_theme.dart';
import 'title_block_sheet.dart';

export 'details.dart' show DetailKind;
export 'sheet_grid.dart' show SheetGrid;
export 'sheet_set.dart' show SheetSplit, SheetWindow, SheetSpec, SheetKind, SheetTheme;
export 'title_block_sheet.dart' show SheetRevision;

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
  String get label => switch (this) {
    PageSize.letter => 'Letter',
    PageSize.tabloid => 'Tabloid',
    _ => name.toUpperCase(),
  };
}

class SheetOptions {
  const SheetOptions({
    this.page = PageSize.a3,
    this.landscape = true,
    this.scale,
    this.marginMm = 10,
    this.wettedRadii = true,
    this.labels = true,
    this.legend = true,
    this.includeReports = false,
    this.bomOnSheet = true,
    this.rasters = const [],
    this.attribution = '',
    this.split = SheetSplit.single,
    this.dimOthers = true,
    this.windows = const [],
    this.details = const [],
    this.charts = false,
    this.profilePath,
    this.dpi = 200,
    // 1.6.0 PRD
    this.grid = SheetGrid.none,
    this.themes = const [],
  });
  final PageSize page;
  final bool landscape;

  /// Scale denominator (1:N); null fits the drawing to the sheet. Sheets of
  /// zones and areas always fit their subject; windows have their own scale.
  final double? scale;
  final double marginMm;
  final bool wettedRadii;
  final bool labels;
  final bool legend;
  final bool includeReports;

  /// Bill of materials table in the side column of the sheet (when the
  /// project has design results): the whole project on the overview, the
  /// zone's on the sheet of a zone, the area's zones on the sheet of an area.
  final bool bomOnSheet;

  /// Rasters drawn under the drawing (e.g. base-map tiles), clipped to the
  /// drawing window.
  final List<PlotRaster> rasters;

  /// Credit line printed small in the drawing window when [rasters] are
  /// shown (e.g. "© OpenStreetMap contributors").
  final String attribution;

  /// One sheet, or an overview plus a sheet per zone or per irrigated area.
  final SheetSplit split;

  /// On the sheet of a zone or area, the other zones in grey (false: left out).
  final bool dimOthers;

  /// Extra sheets of chosen regions of the drawing.
  final List<SheetWindow> windows;

  /// Construction details printed on detail sheets after the drawing sheets.
  final List<DetailKind> details;

  /// Chart pages (grade lines, profiles, pump curves) after the report pages.
  final bool charts;

  /// A path drawn with the profile tool, charted with the others.
  final List<Pt>? profilePath;

  /// Resolution of raster exports of the sheet (dots per inch).
  final double dpi;

  /// 1.6.0 PRD: the coordinate grid of the drawing sheets (UTM, geographic
  /// or both; local X, Y without a georeference).
  final SheetGrid grid;

  /// 1.6.0 PRD: thematic sheets of the terrain after the drawing sheets
  /// (slope by class, aspect), each with its key.
  final List<SheetTheme> themes;

  double get widthMm => landscape ? page.longMm : page.shortMm;
  double get heightMm => landscape ? page.shortMm : page.longMm;

  SheetOptions copyWith({
    PageSize? page,
    bool? landscape,
    double? scale,
    bool clearScale = false,
    double? marginMm,
    bool? wettedRadii,
    bool? labels,
    bool? legend,
    bool? includeReports,
    bool? bomOnSheet,
    List<PlotRaster>? rasters,
    String? attribution,
    SheetSplit? split,
    bool? dimOthers,
    List<SheetWindow>? windows,
    List<DetailKind>? details,
    bool? charts,
    List<Pt>? profilePath,
    bool clearProfilePath = false,
    double? dpi,
    // 1.6.0 PRD
    SheetGrid? grid,
    List<SheetTheme>? themes,
  }) => SheetOptions(
    page: page ?? this.page,
    landscape: landscape ?? this.landscape,
    scale: clearScale ? null : (scale ?? this.scale),
    marginMm: marginMm ?? this.marginMm,
    wettedRadii: wettedRadii ?? this.wettedRadii,
    labels: labels ?? this.labels,
    legend: legend ?? this.legend,
    includeReports: includeReports ?? this.includeReports,
    bomOnSheet: bomOnSheet ?? this.bomOnSheet,
    rasters: rasters ?? this.rasters,
    attribution: attribution ?? this.attribution,
    split: split ?? this.split,
    dimOthers: dimOthers ?? this.dimOthers,
    windows: windows ?? this.windows,
    details: details ?? this.details,
    charts: charts ?? this.charts,
    profilePath: clearProfilePath ? null : (profilePath ?? this.profilePath),
    dpi: dpi ?? this.dpi,
    grid: grid ?? this.grid,
    themes: themes ?? this.themes,
  );
}

/// Sheet geometry: usable drawing area (mm) for a given option set.
class SheetLayout {
  SheetLayout(this.o, {required this.hasLegend, double? legendWidthMm, this.titleMm = titleBlockMm}) : legendWidth = legendWidthMm ?? legendMm;
  final SheetOptions o;
  final bool hasLegend;

  /// Width of the side column (legend + materials table), mm.
  final double legendWidth;

  /// 1.6.0 PRD: height of the title block (mm): [titleBlockMm], or the
  /// professional one's.
  final double titleMm;
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
  double get areaY => frameY + titleMm;
  double get areaW => frameW - (hasLegend ? legendWidth : 0);
  double get areaH => frameH - titleMm;
  double get drawW => areaW - 2 * padMm;
  double get drawH => areaH - 2 * padMm;
}

const _ink = 0xFF1A1A1A;
const _grey = 0xFF8A8F94;
const _lightGrey = 0xFFE3E8EE;
const _warnFill = 0xFFFFE0B2;
const _cellLine = 0xFFB8C0C8;
const _brand = 0xFF1E88E5;

/// Smallest cell of a construction detail on a detail sheet (mm).
const _detailCellW = 90.0, _detailCellH = 78.0;

class PdfSheetBuilder {
  PdfSheetBuilder({required this.project, this.results, required this.t, this.layerNames = const {}, this.units = Units.metric, PdfFonts? fonts}) : fonts = fonts ?? PdfFonts.shared;
  final Project project;
  final DesignResults? results;
  final Translate t;
  final Map<String, String> layerNames;
  final Units units;

  /// Fonts for the text Helvetica cannot show; also used to measure every
  /// text of the sheet and of the report pages.
  final PdfFonts fonts;

  String layerLabel(String l) => layerNames[l] ?? l;

  static String dateString(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// The revision table of the sheets: the revisions of the title block
  /// (1.6.0 PRD) and of the revision clouds, one row per distinct revision,
  /// date and description.
  late final List<SheetRevision> revisions = sheetRevisions(project);

  /// 1.6.0 PRD: height (mm) of the title block of this project's sheets.
  double get titleMm => project.meta.titleBlock.isProfessional ? proTitleBlockMm : SheetLayout.titleBlockMm;

  /// 1.6.0 PRD: the terrain maps of the thematic sheets, made once.
  final Map<SheetTheme, ThemeMap?> _themeMaps = {};
  ThemeMap? themeMap(SheetTheme th) => _themeMaps.putIfAbsent(th, () => ThemeMap.of(project, th));

  /// Largest throw of the sprinklers (m): how far beyond a sheet's window
  /// an outlet still shows on it.
  late final double _reach = () {
    var r = 0.0;
    for (final e in project.entities) {
      final (spec, nozzle, head) = switch (e) {
        OutletEntity o => (o.outletSpecId, o.nozzleId, o.headM),
        SpraylineEntity s => (s.outletSpecId, s.nozzleId, s.headM),
        _ => ('', null, 0.0),
      };
      if (spec.isNotEmpty) r = math.max(r, project.catalog.outlet(spec)?.nozzle(nozzle)?.curve.radius(head) ?? 0);
    }
    return r;
  }();

  /// Scale used for the sheet (auto-fit when [SheetOptions.scale] is null).
  double sheetScale(SheetOptions o) {
    if (o.scale != null && o.scale! > 0) return o.scale!;
    final b = project.bounds;
    if (b.isEmpty) return 1000;
    final lay = SheetLayout(o, hasLegend: o.legend || _showBom(o) || revisions.isNotEmpty, legendWidthMm: _showBom(o) ? SheetLayout.legendWithBomMm : null, titleMm: titleMm);
    final inflated = b.inflate(math.max(b.width, b.height) * 0.04 + 1);
    return fitScale(inflated, lay.drawW, lay.drawH);
  }

  /// The drawing sheets of [o] with their scales: the overview at
  /// [sheetScale], zones and areas fitted to their subject, windows at their
  /// own scale or fitted, then the thematic sheets of the terrain (1.6.0
  /// PRD) fitted to the terrain data.
  List<SheetSpec> sheetPlan(SheetOptions o) {
    final specs = sheetSpecs(project, o.split, results: results, t: t, windows: o.windows);
    // 1.6.0 PRD: the thematic sheets (a theme without terrain data has none)
    final themed = [
      for (final th in SheetTheme.values)
        if (o.themes.contains(th) && themeMap(th) != null) SheetSpec(kind: SheetKind.window, title: t('prd.sheet.${th.name}'), window: themeMap(th)!.bounds, theme: th),
    ];
    final multi = specs.length > 1 || themed.isNotEmpty;
    return [
      for (final s in [if (multi && specs.length == 1 && specs.first.title.isEmpty) SheetSpec(title: t('sheet.overview')) else ...specs, ...themed])
        if (s.scale != null && s.scale! > 0) s else s.withScale(s.window == null ? sheetScale(o) : _fitWindow(o, s)),
    ];
  }

  double _fitWindow(SheetOptions o, SheetSpec s) {
    final w = s.window!;
    final bom = o.bomOnSheet && _bomFor(s).isNotEmpty;
    // 1.6.0 PRD: a thematic sheet has its key in the wide side column
    final lay = s.theme != null
        ? SheetLayout(o, hasLegend: true, legendWidthMm: SheetLayout.legendWithBomMm, titleMm: titleMm)
        : SheetLayout(o, hasLegend: o.legend || bom || revisions.isNotEmpty, legendWidthMm: bom ? SheetLayout.legendWithBomMm : null, titleMm: titleMm);
    return fitScale(w.inflate(math.max(w.width, w.height) * 0.04 + 1), lay.drawW, lay.drawH);
  }

  /// Construction details of [o] by detail sheet (in the order of
  /// [DetailKind], as many per sheet as fit).
  List<List<DetailKind>> detailSheets(SheetOptions o) {
    final kinds = [
      for (final k in DetailKind.values)
        if (o.details.contains(k)) k,
    ];
    if (kinds.isEmpty) return const [];
    final (cols, rows) = _detailCapacity(o);
    final per = cols * rows;
    return [for (var i = 0; i < kinds.length; i += per) kinds.sublist(i, math.min(kinds.length, i + per))];
  }

  (int, int) _detailCapacity(SheetOptions o) {
    final lay = SheetLayout(o, hasLegend: false, titleMm: titleMm);
    return (math.max(1, (lay.areaW / _detailCellW).floor()), math.max(1, (lay.areaH / _detailCellH).floor()));
  }

  /// The project name, or "New project" when it has none (1.6.0 UI).
  String get _title => project.meta.name.trim().isEmpty ? t('name.newProject') : project.meta.name;

  /// Number of sheets (drawing and detail sheets) of [o].
  int sheetCount(SheetOptions o) => sheetPlan(o).length + detailSheets(o).length;

  /// Drawing sheets, detail sheets, then report pages and charts as [o] asks.
  Uint8List buildSheet(SheetOptions o, {List<ReportTable> reports = const []}) {
    final doc = PdfDocument(title: _title, author: project.meta.designer, subject: t('pdf.subtitle'), fonts: fonts);
    addSheetPages(doc, o);
    final charts = o.charts ? designCharts(project, results, t: t, u: units, profilePath: o.profilePath) : const <PlotChart>[];
    if (o.includeReports) {
      addReportPages(doc, reports, charts: charts);
    } else if (charts.isNotEmpty) {
      addChartPages(doc, charts);
    }
    return doc.build();
  }

  /// Report document only.
  Uint8List buildReport(List<ReportTable> tables) {
    final doc = PdfDocument(title: '$_title - ${t('pdf.reportTitle')}', author: project.meta.designer, subject: t('pdf.reportTitle'), fonts: fonts);
    addReportPages(doc, tables);
    return doc.build();
  }

  bool _showBom(SheetOptions o) => o.bomOnSheet && (results?.bom.isNotEmpty ?? false);

  /// Materials of the sheet [s]: the project's on the overview, the zones'
  /// own on the sheet of a zone or area, none on a window.
  List<BomLine> _bomFor(SheetSpec s) {
    final r = results;
    if (r == null) return const [];
    switch (s.kind) {
      case SheetKind.overview:
        return r.bom;
      case SheetKind.window:
        return const [];
      case SheetKind.zone || SheetKind.area:
        final merged = <String, BomLine>{};
        for (final z in s.zones) {
          for (final l in r.bomByZone[z] ?? const <BomLine>[]) {
            final k = '${l.category}|${l.description}|${l.unit}|${l.specId}|${l.code}';
            final m = merged[k];
            merged[k] = BomLine(
              category: l.category,
              description: l.description,
              unit: l.unit,
              quantity: (m?.quantity ?? 0) + l.quantity,
              unitCost: l.unitCost,
              specId: l.specId,
              code: l.code,
              supplier: l.supplier,
            );
          }
        }
        return merged.values.toList();
    }
  }

  /// Adds every drawing sheet of [o] and its detail sheets; returns how many.
  /// A set of one sheet is exactly the classic single sheet.
  int addSheetPages(PdfDocument doc, SheetOptions o) {
    final plan = sheetPlan(o);
    final details = detailSheets(o);
    final count = plan.length + details.length;
    if (count == 1) {
      addSheetPage(doc, o);
      return 1;
    }
    for (var i = 0; i < plan.length; i++) {
      final page = doc.addPage(widthPt: o.widthMm * ptPerMm, heightPt: o.heightMm * ptPerMm);
      drawSheet(PdfSheetCanvas(page), o, plan[i], number: i + 1, count: count);
    }
    final ctx = details.isEmpty ? null : DetailContext.of(project, results);
    var first = 0;
    for (var j = 0; j < details.length; j++) {
      final page = doc.addPage(widthPt: o.widthMm * ptPerMm, heightPt: o.heightMm * ptPerMm);
      drawDetailSheet(PdfSheetCanvas(page), o, details[j], ctx!, number: plan.length + j + 1, count: count, firstIndex: first);
      first += details[j].length;
    }
    return count;
  }

  /// The single drawing sheet of [o] (frame, title block, legend, north
  /// arrow and scale bar), as one page of [doc].
  void addSheetPage(PdfDocument doc, SheetOptions o) {
    final page = doc.addPage(widthPt: o.widthMm * ptPerMm, heightPt: o.heightMm * ptPerMm);
    drawSheet(PdfSheetCanvas(page), o, SheetSpec(scale: sheetScale(o)));
  }

  /// Sheet [index] of the set of [o] (drawing sheets first, then detail
  /// sheets) recorded for a raster or vector writer.
  RecordedSheet recordSheet(SheetOptions o, {int index = 0}) {
    final rec = SheetRecorder(o.widthMm * ptPerMm, o.heightMm * ptPerMm);
    final plan = sheetPlan(o);
    final details = detailSheets(o);
    final count = plan.length + details.length;
    final i = index.clamp(0, count - 1);
    if (count == 1) {
      drawSheet(rec, o, SheetSpec(scale: sheetScale(o)));
    } else if (i < plan.length) {
      drawSheet(rec, o, plan[i], number: i + 1, count: count);
    } else {
      final j = i - plan.length;
      drawDetailSheet(rec, o, details[j], DetailContext.of(project, results), number: i + 1, count: count, firstIndex: details.take(j).fold(0, (a, d) => a + d.length));
    }
    return rec.sheet;
  }

  /// The world rectangle (m) the drawing area of each drawing sheet of [o]
  /// shows, with the sheet's scale denominator: where a base map under the
  /// sheets ([SheetOptions.rasters]) is needed, and how fine.
  List<(Bounds, double)> sheetViews(SheetOptions o) {
    final out = <(Bounds, double)>[];
    for (final s in sheetPlan(o)) {
      final scale = s.scale!;
      final upm = scale / 1000;
      final Pt centre;
      final SheetLayout lay;
      if (s.window != null) {
        // centred on the window; the widest drawing area (no side column)
        // covers the sheet whatever goes beside it
        centre = s.window!.center;
        lay = SheetLayout(o, hasLegend: false, titleMm: titleMm);
      } else {
        final showBom = o.bomOnSheet && _bomFor(s).isNotEmpty;
        final scene = _sheetScene(o, s, upm, showBom);
        centre = _sheetCentre(s, scene);
        lay = _sheetLayout(o, scene, showBom);
      }
      final hw = lay.areaW / 2 * upm, hh = lay.areaH / 2 * upm;
      out.add((Bounds(centre.x - hw, centre.y - hh, centre.x + hw, centre.y + hh), scale));
    }
    return out;
  }

  /// Plot scene of drawing sheet [spec] (a window sheet holds only what may
  /// show on it).
  PlotScene _sheetScene(SheetOptions o, SheetSpec spec, double unitsPerMm, bool showBom) {
    Bounds? cull;
    final w = spec.window;
    if (w != null) {
      // what the drawing area shows around the window centre, plus the throw
      // of the sprinklers outside it and room for their labels
      final lay0 = SheetLayout(o, hasLegend: true, legendWidthMm: showBom ? SheetLayout.legendWithBomMm : null, titleMm: titleMm);
      final hw = (lay0.areaW + 2 * SheetLayout.legendMm) / 2 * unitsPerMm, hh = lay0.areaH / 2 * unitsPerMm;
      cull = Bounds(w.center.x - hw, w.center.y - hh, w.center.x + hw, w.center.y + hh).inflate(_reach + 30 * unitsPerMm);
    }
    // 1.6.0 PRD: on a thematic sheet the whole drawing is context, in grey
    final themed = spec.theme != null;
    return buildPlotScene(
      project,
      results: results,
      unitsPerMm: unitsPerMm,
      options: PlotOptions(
        wettedRadii: o.wettedRadii && !themed,
        labels: o.labels && !themed,
        results: o.labels && !themed,
        muted: themed ? {for (final e in project.entities) e.id} : spec.muted,
        hideMuted: !themed && !o.dimOthers,
        window: cull,
      ),
      units: units,
      t: t,
      rasters: o.rasters,
      attribution: o.attribution,
    );
  }

  SheetLayout _sheetLayout(SheetOptions o, PlotScene scene, bool showBom, {bool themed = false}) => themed
      ? SheetLayout(o, hasLegend: true, legendWidthMm: SheetLayout.legendWithBomMm, titleMm: titleMm)
      : SheetLayout(o, hasLegend: (o.legend && scene.layers.isNotEmpty) || showBom || revisions.isNotEmpty, legendWidthMm: showBom ? SheetLayout.legendWithBomMm : null, titleMm: titleMm);

  /// World point at the centre of the drawing area of sheet [spec]: the
  /// window's centre, else the centre of what is plotted.
  Pt _sheetCentre(SheetSpec spec, PlotScene scene) {
    final w = spec.window;
    if (w != null) return w.center;
    final b = scene.bounds.isEmpty ? project.bounds : scene.bounds;
    return b.isEmpty ? Pt.zero : b.center;
  }

  /// Draws drawing sheet [spec] of a set of [count] sheets on [page].
  void drawSheet(SheetCanvas page, SheetOptions o, SheetSpec spec, {int number = 1, int count = 1}) {
    final scale = spec.scale ?? sheetScale(o);
    final unitsPerMm = scale / 1000;
    final bom = _bomFor(spec);
    final showBom = o.bomOnSheet && bom.isNotEmpty;
    final revs = revisions;
    final scene = _sheetScene(o, spec, unitsPerMm, showBom);
    // 1.6.0 PRD: the terrain map of a thematic sheet
    final theme = spec.theme == null ? null : themeMap(spec.theme!);
    final lay = _sheetLayout(o, scene, showBom, themed: theme != null);
    double px(double mm) => mm * ptPerMm;
    _frame(page, lay, px);
    // drawing (clipped)
    final centre = _sheetCentre(spec, scene);
    final cx = centre.x, cy = centre.y;
    final ox = lay.areaX + lay.areaW / 2, oy = lay.areaY + lay.areaH / 2; // paper centre (mm)
    (double, double) map(Pt p) => (px(ox + (p.x - cx) / unitsPerMm), px(oy + (p.y - cy) / unitsPerMm));
    final barLen = niceBarLength(unitsPerMm, 40);
    final barMm = barLen / unitsPerMm;
    final bx = lay.areaX + 6, by = lay.areaY + 6;
    final nx = lay.areaX + lay.areaW - 10, ny = lay.areaY + lay.areaH - 14;
    page.save();
    page.clipRect(px(lay.areaX) + 0.5, px(lay.areaY) + 0.5, px(lay.areaW) - 1, px(lay.areaH) - 1);
    if (theme == null) {
      drawScene(page, scene, map, unitsPerMm);
    } else {
      // the base map, the classes, then the drawing in grey with the names of the areas
      drawScene(page, PlotScene(items: const [], bounds: scene.bounds, unitsPerMm: unitsPerMm, layers: const {}, rasters: scene.rasters), map, unitsPerMm);
      drawThemeCells(page, theme, map, opacity: 0.7);
      drawScene(page, PlotScene(items: [...scene.items, ..._areaNames(unitsPerMm)], bounds: scene.bounds, unitsPerMm: unitsPerMm, layers: const {}), map, unitsPerMm);
    }
    // 1.6.0 PRD: the coordinate grid, its values clear of the marks of the sheet
    final gridNote = _gridNote(o, unitsPerMm);
    if (o.grid != SheetGrid.none) {
      final view = Bounds(cx - lay.areaW / 2 * unitsPerMm, cy - lay.areaH / 2 * unitsPerMm, cx + lay.areaW / 2 * unitsPerMm, cy + lay.areaH / 2 * unitsPerMm);
      drawSheetGrid(
        page,
        fonts,
        grid: o.grid,
        georef: project.meta.georef,
        view: view,
        area: Bounds(px(lay.areaX), px(lay.areaY), px(lay.areaX + lay.areaW), px(lay.areaY + lay.areaH)),
        unitsPerMm: unitsPerMm,
        map: map,
        avoid: [
          Bounds(px(nx - 3), px(ny - 4), px(nx + 3), px(ny + 12)),
          Bounds(px(bx - 3), px(by - 1.5), px(bx + barMm + 14), px(by + (gridNote.isEmpty ? 6 : 10))),
          if (count > 1 && spec.title.isNotEmpty) _captionBox(spec.title, lay, px),
          if (scene.attribution.isNotEmpty) _attributionBox(scene.attribution, lay, px),
        ],
        t: t,
      );
    }
    page.restore();
    if (scene.attribution.isNotEmpty) _attribution(page, scene.attribution, lay, px);
    if (count > 1 && spec.title.isNotEmpty) _caption(page, spec.title, lay, px);
    if (gridNote.isNotEmpty) {
      page.fillColor(_grey);
      page.text(px(bx - 2), px(by + 6.6), fonts.fit(gridNote, px(lay.areaW * 0.5), 5.5), size: 5.5);
    }
    // north arrow (top-right of the drawing area)
    page.strokeColor(_ink);
    page.fillColor(_ink);
    page.lineWidth(px(0.3));
    page.path([map0(px(nx), px(ny)), map0(px(nx - 2.2), px(ny - 3)), map0(px(nx), px(ny + 7)), map0(px(nx + 2.2), px(ny - 3))], close: true, fill: true);
    page.text(px(nx), px(ny + 8.5), 'N', size: 9, bold: true, align: PdfAlign.center);
    // scale bar (bottom-left)
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
    // legend, materials table and revisions (side column)
    final floor = revs.isEmpty ? null : _revisionTable(page, lay, px, revs);
    var sideY = lay.frameY + lay.frameH - 8;
    if (theme != null) {
      // 1.6.0 PRD: the key of the thematic sheet instead
      drawThemeKey(page, fonts, t, project, theme, x0: lay.areaX + lay.areaW + 4, top: sideY, width: lay.legendWidth - 8, floor: floor ?? lay.areaY);
    } else {
      if (lay.hasLegend && o.legend && scene.layers.isNotEmpty) sideY = _legend(page, scene, lay, px, floor: floor);
      if (showBom) _bomBlock(page, lay, px, sideY - 4, bom, floor: floor);
    }
    // title block
    _titleBlock(page, lay, scale, px, sheet: count > 1 ? '$number/$count${spec.title.isEmpty ? '' : ' · ${spec.title}'}' : '1/1', number: number, count: count);
  }

  /// 1.6.0 PRD: the names of the irrigated areas on a thematic sheet (its
  /// drawing is greyed without labels), top-left inside each area.
  List<PlotItem> _areaNames(double unitsPerMm) => [
    for (final a in project.entities.whereType<AreaEntity>())
      if (a.points.length >= 3 && a.name.isNotEmpty)
        PlotText(
          layer: a.layer,
          color: _ink,
          position: Pt(Bounds.ofPoints(a.points).minX + 1.5 * unitsPerMm, Bounds.ofPoints(a.points).maxY - 4 * unitsPerMm),
          text: a.name,
          heightMm: 2.2,
          bold: true,
        ),
  ];

  /// 1.6.0 PRD: the steps of the coordinate grid of [o] at [unitsPerMm]
  /// ("UTM grid 100 m · geographic 30""), or empty without a grid.
  String _gridNote(SheetOptions o, double unitsPerMm) {
    if (o.grid == SheetGrid.none) return '';
    final g = project.meta.georef;
    final parts = <String>[
      if (o.grid.hasUtm) t(g == null ? 'prd.grid.noteLocal' : 'prd.grid.noteUtm', {'s': '${fmt(units.lengthFromSi(utmGridStep(unitsPerMm)), 0)} ${units.lengthLabel}'}),
      if (o.grid.hasGeographic && g != null) t('prd.grid.noteGeo', {'s': _stepText(graticuleStepSeconds(unitsPerMm))}),
    ];
    return parts.join(' · ');
  }

  static String _stepText(int seconds) => seconds % 3600 == 0 ? '${seconds ~/ 3600}°' : (seconds % 60 == 0 ? '${seconds ~/ 60}\'' : '$seconds"');

  /// Box (pt) of the title of a sheet of a set ([_caption]).
  Bounds _captionBox(String title, SheetLayout lay, double Function(double) px) {
    const size = 10.0;
    final s = fonts.fit(title, px(lay.areaW) * 0.6, size, bold: true);
    final w = fonts.textWidth(s, size, bold: true);
    final x = px(lay.areaX) + 8, y = px(lay.areaY + lay.areaH) - 8 - size;
    return Bounds(x - 5, y - 5, x + w + 5, y + size + 4);
  }

  /// Box (pt) of the credit line of the base map ([_attribution]).
  Bounds _attributionBox(String text, SheetLayout lay, double Function(double) px) {
    const size = 5.0;
    final s = fonts.fit(text, px(lay.areaW) * 0.6, size);
    final w = fonts.textWidth(s, size);
    final x = px(lay.areaX + lay.areaW) - 3, y = px(lay.areaY) + 3;
    return Bounds(x - w - 3, y - 2.5, x + 3, y + size + 2.5);
  }

  void _frame(SheetCanvas page, SheetLayout lay, double Function(double) px) {
    page.strokeColor(_ink);
    page.lineWidth(px(0.5));
    page.rect(px(lay.frameX), px(lay.frameY), px(lay.frameW), px(lay.frameH));
    page.lineWidth(px(0.25));
    page.line(px(lay.areaX), px(lay.areaY), px(lay.frameX + lay.frameW), px(lay.areaY));
    if (lay.hasLegend) page.line(px(lay.areaX + lay.areaW), px(lay.areaY), px(lay.areaX + lay.areaW), px(lay.frameY + lay.frameH));
  }

  static (double, double) map0(double x, double y) => (x, y);

  /// Print resolution of images, dots per inch at their size on paper.
  static const imageDpi = 250.0;

  /// Draws an image (raster or image entity) on its world corners, with the
  /// pixel size limited to [imageDpi] at the printed size.
  void _drawImage(SheetCanvas page, Uint8List bytes, String mime, List<Pt> corners, double opacity, (double, double) Function(Pt) map) {
    if (corners.length < 4) return;
    final bl = map(corners[0]), br = map(corners[1]), tl = map(corners[3]);
    double dist((double, double) a, (double, double) b) => math.sqrt((a.$1 - b.$1) * (a.$1 - b.$1) + (a.$2 - b.$2) * (a.$2 - b.$2));
    final wPx = (dist(bl, br) / 72 * imageDpi).ceil(), hPx = (dist(bl, tl) / 72 * imageDpi).ceil();
    if (wPx <= 0 || hPx <= 0) return;
    page.image(bytes, mime, bl, br, tl, opacity: opacity, maxWidthPx: math.max(wPx, 16), maxHeightPx: math.max(hPx, 16));
  }

  void _attribution(SheetCanvas page, String text, SheetLayout lay, double Function(double) px) {
    const size = 5.0;
    final maxW = px(lay.areaW) * 0.6;
    final s = fonts.fit(text, maxW, size);
    final w = fonts.textWidth(s, size);
    final x = px(lay.areaX + lay.areaW) - 3, y = px(lay.areaY) + 3;
    page.save();
    page.opacity(0.75);
    page.fillColor(0xFFFFFFFF);
    page.rect(x - w - 2, y - 1.5, w + 4, size + 2.5, stroke: false, fill: true);
    page.restore();
    page.fillColor(_grey);
    page.text(x, y, s, size: size, align: PdfAlign.right);
  }

  /// Title of a sheet of a set, top-left in the drawing area on a white box.
  void _caption(SheetCanvas page, String title, SheetLayout lay, double Function(double) px) {
    const size = 10.0;
    final s = fonts.fit(title, px(lay.areaW) * 0.6, size, bold: true);
    final w = fonts.textWidth(s, size, bold: true);
    final x = px(lay.areaX) + 8, y = px(lay.areaY + lay.areaH) - 8 - size;
    page.fillColor(0xFFFFFFFF);
    page.strokeColor(_ink);
    page.lineWidth(px(0.25));
    page.dash(false);
    page.rect(x - 4, y - 4, w + 8, size + 7, fill: true);
    page.fillColor(_ink);
    page.text(x, y, s, size: size, bold: true);
  }

  /// A translucent fill: [fill] (a path drawn without its outline) in
  /// [argb] at [alpha].
  static void _tint(SheetCanvas page, int argb, double alpha, void Function() fill) {
    page.save();
    page.opacity(alpha);
    page.fillColor(argb);
    fill();
    page.restore();
  }

  void drawScene(SheetCanvas page, PlotScene scene, (double, double) Function(Pt) map, double unitsPerMm) {
    for (final r in scene.rasters) {
      _drawImage(page, r.bytes, r.mime, r.corners, r.opacity, map);
    }
    for (final it in scene.items) {
      switch (it) {
        case PlotImage im:
          _drawImage(page, im.bytes, im.mime, im.corners, im.opacity, map);
        case PlotPath p:
          final pts = p.points.map(map).toList();
          final tinted = p.fillColor != null && p.fillOpacity < 1;
          if (tinted) _tint(page, p.fillColor!, p.fillOpacity, () => page.path(pts, close: p.closed, stroke: false, fill: true));
          page.strokeColor(p.color);
          page.lineWidth(p.widthMm * ptPerMm);
          page.dash(p.dashed, p.widthMm * ptPerMm * 6, p.widthMm * ptPerMm * 4);
          final opaque = p.fillColor != null && !tinted;
          if (opaque) page.fillColor(p.fillColor!);
          page.path(pts, close: p.closed, fill: opaque);
        case PlotCircle c:
          final (x, y) = map(c.center);
          final r = c.radius / unitsPerMm * ptPerMm;
          final tinted = c.fillColor != null && c.fillOpacity < 1;
          if (tinted) _tint(page, c.fillColor!, c.fillOpacity, () => page.circle(x, y, r, stroke: false, fill: true));
          if (c.stroke) {
            page.strokeColor(c.color);
            page.lineWidth(c.widthMm * ptPerMm);
            page.dash(false);
          }
          final opaque = c.fillColor != null && !tinted;
          if (opaque) page.fillColor(c.fillColor!);
          if (c.stroke || opaque) page.circle(x, y, r, stroke: c.stroke, fill: opaque);
        case PlotText tx:
          final (x, y) = map(tx.position);
          final size = tx.heightMm * ptPerMm / 0.72;
          page.fillColor(tx.color);
          final align = switch (tx.anchor) {
            PlotAnchor.bottomCenter || PlotAnchor.center => PdfAlign.center,
            PlotAnchor.bottomRight => PdfAlign.right,
            _ => PdfAlign.left,
          };
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

  /// Draws the legend in the side column; returns the y (mm) below it. Rows
  /// stop above [floor] (the revision table) when given.
  double _legend(SheetCanvas page, PlotScene scene, SheetLayout lay, double Function(double) px, {double? floor}) {
    final x0 = lay.areaX + lay.areaW + 4;
    var y = lay.frameY + lay.frameH - 8;
    page.fillColor(_ink);
    page.text(px(x0), px(y), t('pdf.legend'), size: 9, bold: true);
    y -= 6;
    for (final e in scene.layers.entries) {
      if (y < (floor ?? lay.areaY) + 4) break;
      page.strokeColor(e.value);
      page.fillColor(e.value);
      page.lineWidth(px(0.6));
      page.dash(false);
      page.line(px(x0), px(y + 1), px(x0 + 8), px(y + 1));
      page.fillColor(_ink);
      page.text(px(x0 + 10), px(y), fonts.fit(layerLabel(e.key), px(lay.legendWidth - 16), 7), size: 7);
      y -= 4.6;
    }
    return y;
  }

  /// Compact bill of materials in the side column (description, quantity,
  /// unit); rows that do not fit are counted in a closing line.
  void _bomBlock(SheetCanvas page, SheetLayout lay, double Function(double) px, double top, List<BomLine> bom, {double? floor}) {
    if (bom.isEmpty) return;
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
    final lines = bom.where((l) => l.quantity > 0).toList()..sort((a, b) => a.category == b.category ? a.description.compareTo(b.description) : a.category.compareTo(b.category));
    String? lastCat;
    var shown = 0;
    for (final l in lines) {
      final needed = l.category != lastCat ? 7.6 : 3.8;
      if (y - needed < (floor ?? lay.areaY) + 8) break;
      if (l.category != lastCat) {
        lastCat = l.category;
        page.fillColor(_ink);
        page.text(px(x0), px(y), fonts.fit(t(l.category), px(w), 6.5, bold: true), size: 6.5, bold: true);
        y -= 3.8;
      }
      page.fillColor(_ink);
      page.text(px(x0 + 2), px(y), fonts.fit(l.description, px(w - qtyW - 3), 6), size: 6);
      final qty = l.unit == 'm' ? fmt(l.quantity, 0) : fmt(l.quantity, 0);
      page.text(px(x0 + w), px(y), '$qty ${l.unit}', size: 6, align: PdfAlign.right);
      y -= 3.8;
      shown++;
    }
    if (shown < lines.length) {
      page.fillColor(_grey);
      page.text(px(x0), px(y), fonts.fit(t('pdf.bomMore', {'n': '${lines.length - shown}'}), px(w), 5.5), size: 5.5);
    }
  }

  /// Revision table at the bottom of the side column (revision, date and
  /// description of the revision clouds, oldest at the bottom); returns the
  /// y (mm) of its top.
  double _revisionTable(SheetCanvas page, SheetLayout lay, double Function(double) px, List<SheetRevision> revs) {
    final x0 = lay.areaX + lay.areaW + 4;
    final w = lay.legendWidth - 8;
    const lineH = 2.9, revW = 7.0, dateW = 14.0;
    final rows = revs.length > 8 ? revs.sublist(revs.length - 8) : revs;
    var y = lay.areaY + 3;
    // oldest at the bottom; a description wraps onto (at most three) lines
    for (final r in rows) {
      var lines = _wrap(fonts, r.description, px(w - revW - dateW), 6);
      if (lines.length > 3) lines = [lines[0], lines[1], fonts.fit(lines.sublist(2).join(' '), px(w - revW - dateW), 6)];
      final top = y + (lines.length - 1) * lineH;
      page.fillColor(_ink);
      page.text(px(x0), px(top), fonts.fit(r.revision, px(revW - 1), 6, bold: true), size: 6, bold: true);
      page.text(px(x0 + revW), px(top), fonts.fit(r.date, px(dateW - 1), 6), size: 6);
      for (var k = 0; k < lines.length; k++) {
        page.text(px(x0 + revW + dateW), px(top - k * lineH), lines[k], size: 6);
      }
      y = top + lineH + 0.8;
    }
    page.fillColor(_grey);
    page.text(px(x0), px(y), t('pdf.rev').toUpperCase(), size: 5.5);
    page.text(px(x0 + revW), px(y), t('pdf.date').toUpperCase(), size: 5.5);
    page.text(px(x0 + revW + dateW), px(y), t('rep.description').toUpperCase(), size: 5.5);
    y += 3.4;
    page.strokeColor(_ink);
    page.lineWidth(px(0.25));
    page.dash(false);
    page.line(px(x0), px(y), px(x0 + w), px(y));
    y += 1.6;
    page.fillColor(_ink);
    page.text(px(x0), px(y), t('pdf.revisions'), size: 8, bold: true);
    return y + 4;
  }

  void _titleBlock(SheetCanvas page, SheetLayout lay, double scale, double Function(double) px, {String sheet = '1/1', String? scaleText, int number = 1, int count = 1}) {
    final m = project.meta;
    final x0 = lay.frameX, y0 = lay.frameY, w = lay.frameW;
    // 1.6.0 PRD: the professional title block when any of it is set
    if (m.titleBlock.isProfessional) {
      final g = m.georef;
      final issued = m.titleBlock.issued ?? DateTime.now();
      final epsg = g?.epsg;
      drawProTitleBlock(
        page,
        fonts,
        t,
        project,
        x0: x0,
        y0: y0,
        w: w,
        h: lay.titleMm,
        sheet: sheet,
        number: number,
        count: count,
        scale: scaleText ?? '1:${scale.round()}',
        paper: _pageLabel(lay.o),
        date: dateString(issued),
        crs: g == null ? '' : g.crsName,
        crsNote: g == null ? '' : '${epsg == null ? '' : 'EPSG:$epsg · '}E ${g.originEasting.toStringAsFixed(0)} N ${g.originNorthing.toStringAsFixed(0)}',
        generated: t('pdf.generated', {'d': dateString(DateTime.now())}),
      );
      return;
    }
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
      final kw = fonts.textWidth(key, 5.5);
      page.fillColor(_grey);
      page.text(px(x), px(yy), key, size: 5.5);
      page.fillColor(_ink);
      page.text(px(x) + kw + 4, px(yy), fonts.fit(v, px(maxW) - kw - 6, 7.5), size: 7.5);
    }

    // column A: project, client, site, designer, notes
    var y = y0 + h - 6;
    page.text(px(x0 + 3), px(y), fonts.fit(m.name.isEmpty ? t('name.newProject') : m.name, px(colA - 6), 12, bold: true), size: 12, bold: true);
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
    kv(xb, y, t('pdf.scale'), '${scaleText ?? '1:${scale.round()}'}  (${_pageLabel(lay.o)})', colB - 6);
    y -= row;
    final g = m.georef;
    kv(xb, y, t('pdf.crs'), g == null ? t('pdf.local') : g.crsName, colB - 6);
    y -= row;
    kv(xb, y, t('pdf.origin'), g == null ? '0 / 0' : 'E ${g.originEasting.toStringAsFixed(0)}  N ${g.originNorthing.toStringAsFixed(0)}', colB - 6);
    y -= row;
    kv(xb, y, t('pdf.sheet'), sheet, colB - 6);
    // column C: branding
    final xc = x0 + colA + colB;
    final wc = w - colA - colB;
    page.fillColor(_brand);
    page.text(px(xc + wc / 2), px(y0 + h - 10), 'OpenCADIrrigation', size: 11, bold: true, align: PdfAlign.center);
    page.fillColor(_grey);
    page.text(px(xc + wc / 2), px(y0 + h - 15), fonts.fit(t('pdf.subtitle'), px(wc - 4), 6.5), size: 6.5, align: PdfAlign.center);
    page.text(px(xc + wc / 2), px(y0 + 4), fonts.fit(t('pdf.generated', {'d': dateString(DateTime.now())}), px(wc - 4), 5.5), size: 5.5, align: PdfAlign.center);
  }

  String _pageLabel(SheetOptions o) => '${o.page.label} ${o.landscape ? t('plot.landscape') : t('plot.portrait')}';

  // ------------------------------------------------------------------ details

  /// A sheet of construction details [kinds] (numbered from [firstIndex] + 1)
  /// in a grid of cells: title and scale on top, the drawing with its
  /// dimensions and callouts, the notes with the values of the design.
  void drawDetailSheet(SheetCanvas page, SheetOptions o, List<DetailKind> kinds, DetailContext ctx, {int number = 1, int count = 1, int firstIndex = 0}) {
    final lay = SheetLayout(o, hasLegend: false, titleMm: titleMm);
    double px(double mm) => mm * ptPerMm;
    _frame(page, lay, px);
    final (maxCols, maxRows) = _detailCapacity(o);
    final rows = math.max(1, math.min(maxRows, (kinds.length / maxCols).ceil()));
    final cols = math.max(1, (kinds.length / rows).ceil());
    final cw = lay.areaW / cols, ch = lay.areaH / rows;
    for (var i = 0; i < kinds.length; i++) {
      final x0 = lay.areaX + (i % cols) * cw, y0 = lay.areaY + lay.areaH - (i ~/ cols + 1) * ch;
      _detailCell(page, kinds[i], ctx, firstIndex + i + 1, x0, y0, cw, ch, px);
    }
    _titleBlock(page, lay, 0, px, sheet: '$number/$count · ${t('det.title')}', scaleText: t('det.scaleAsShown'), number: number, count: count);
  }

  void _detailCell(SheetCanvas page, DetailKind kind, DetailContext ctx, int n, double x0, double y0, double cw, double ch, double Function(double) px) {
    const titleH = 9.0, noteSize = 6.0, noteLine = 2.7;
    // cell frame
    page.strokeColor(_cellLine);
    page.lineWidth(px(0.2));
    page.dash(false);
    page.rect(px(x0), px(y0), px(cw), px(ch));
    // the drawing first at the full height, then again if the notes need more room
    var noteH = 3 * noteLine + 3;
    var d = buildDetail(kind, ctx, widthMm: cw - 6, heightMm: ch - titleH - noteH - 4, t: t);
    var notes = [for (final s in d.notes) ..._wrap(fonts, s, px(cw - 8), noteSize)];
    if (notes.length * noteLine + 3 > noteH) {
      noteH = notes.length * noteLine + 3;
      d = buildDetail(kind, ctx, widthMm: cw - 6, heightMm: math.max(20, ch - titleH - noteH - 4), t: t);
      notes = [for (final s in d.notes) ..._wrap(fonts, s, px(cw - 8), noteSize)];
    }
    // title: number in a circle, name, scale
    final ty = y0 + ch - 6.2;
    page.strokeColor(_ink);
    page.lineWidth(px(0.3));
    page.fillColor(0xFFFFFFFF);
    page.circle(px(x0 + 5), px(ty + 1.2), px(2.6), fill: true);
    page.fillColor(_ink);
    page.text(px(x0 + 5), px(ty), '$n', size: 7.5, bold: true, align: PdfAlign.center);
    final scaleLabel = t('det.scale', {'n': fmt(d.scale, d.scale < 10 && d.scale != d.scale.roundToDouble() ? 1 : 0)});
    final sw = fonts.textWidth(scaleLabel, 6);
    page.text(px(x0 + 9.5), px(ty), fonts.fit(d.title, px(cw - 14) - sw - 6, 8, bold: true), size: 8, bold: true);
    page.fillColor(_grey);
    page.text(px(x0 + cw - 2.5), px(ty), scaleLabel, size: 6, align: PdfAlign.right);
    page.strokeColor(_cellLine);
    page.lineWidth(px(0.2));
    page.line(px(x0 + 2), px(y0 + ch - titleH), px(x0 + cw - 2), px(y0 + ch - titleH));
    // notes at the bottom
    page.fillColor(0xFF37474F);
    for (var k = 0; k < notes.length; k++) {
      page.text(px(x0 + 3), px(y0 + 2 + (notes.length - 1 - k) * noteLine), notes[k], size: noteSize);
    }
    // the drawing, centred in what is left
    final ax = x0 + 3, ay = y0 + noteH + 1, aw = cw - 6, ah = ch - titleH - noteH - 2;
    final b = d.bounds;
    if (b.isEmpty) return;
    final upm = d.unitsPerMm;
    final cxw = b.center.x, cyw = b.center.y, ox = ax + aw / 2, oy = ay + ah / 2;
    (double, double) map(Pt p) => (px(ox + (p.x - cxw) / upm), px(oy + (p.y - cyw) / upm));
    page.save();
    page.clipRect(px(x0) + 0.5, px(y0) + 0.5, px(cw) - 1, px(ch - titleH) - 1);
    drawScene(page, PlotScene(items: d.items, bounds: b, unitsPerMm: upm, layers: const {}), map, upm);
    page.restore();
  }

  // ------------------------------------------------------------------ reports

  void addReportPages(PdfDocument doc, List<ReportTable> tables, {List<PlotChart> charts = const []}) {
    final pages = _ReportPages(doc, this);
    pages.begin();
    if (tables.isEmpty || tables.every((tb) => tb.key == 'water' || tb.key == 'messages')) {
      pages.paragraph(t('pdf.noResults'));
    }
    pages.paramsBlock();
    for (final tb in tables) {
      pages.table(tb);
    }
    for (final c in charts) {
      pages.chart(c);
    }
    pages.finish();
  }

  /// Chart pages alone (A4 landscape, two charts a page).
  void addChartPages(PdfDocument doc, List<PlotChart> charts) {
    if (charts.isEmpty) return;
    final pages = _ReportPages(doc, this, title: t('chart.pages'));
    pages.begin();
    for (final c in charts) {
      pages.chart(c);
    }
    pages.finish();
  }
}

/// A4 landscape report pages with header/footer and paginated tables.
class _ReportPages {
  _ReportPages(this.doc, this.b, {String? title}) : title = title ?? b.t('pdf.reportTitle');
  final PdfDocument doc;
  final PdfSheetBuilder b;
  final String title;
  PdfFonts get fonts => b.fonts;
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
    page.text(left, top - 10, title, size: 12, bold: true);
    page.fillColor(_grey);
    final m = b.project.meta;
    final sub = [m.name, if (m.client.isNotEmpty) m.client, if (m.site.isNotEmpty) m.site].join(' · ');
    page.text(left, top - 21, fonts.fit(sub, avail - 120, 8), size: 8);
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
    final lines = _wrap(fonts, s, avail, 8);
    _ensure(lines.length * 11.0);
    page.fillColor(_ink);
    for (final l in lines) {
      page.text(left, y, l, size: 8);
      y -= 11;
    }
    y -= 6;
  }

  /// A chart (plot_charts.dart) across the page, about half of it high,
  /// with its notes under it.
  void chart(PlotChart c) {
    const chartMm = 74.0;
    final notes = [for (final n in c.notes) ..._wrap(fonts, n, avail, 7)];
    final h = chartMm * ptPerMm;
    _ensure(h + notes.length * 9.5 + 10);
    final scene = chartScene(c, widthMm: avail / ptPerMm, heightMm: chartMm);
    final y0 = y + 8 - h; // bottom of the chart frame
    (double, double) map(Pt p) => (left + p.x * ptPerMm, y0 + p.y * ptPerMm);
    b.drawScene(PdfSheetCanvas(page), scene, map, 1);
    page.dash(false);
    y = y0 - 9;
    page.fillColor(_ink);
    for (final l in notes) {
      page.text(left, y, l, size: 7);
      y -= 9.5;
    }
    y -= 12;
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
      page.text(left + col * colW, y - row * 10, fonts.fit(items[i], colW - 6, 7), size: 7);
    }
    y -= ((items.length + 3) ~/ 4) * 10 + 8;
  }

  void table(ReportTable tb) {
    const size = 7.0, pad = 3.0, lineH = 9.5;
    final n = tb.headers.length;
    if (n == 0) return;
    // natural widths; columns may shrink down to their widest word (headers
    // and long text cells then wrap onto several lines)
    final widths = List<double>.generate(n, (i) => fonts.textWidth(tb.headers[i], size, bold: true) + 2 * pad);
    final minW = List<double>.generate(n, (i) => _widestWord(fonts, tb.headers[i], size, bold: true) + 2 * pad);
    final numeric = List<bool>.generate(n, (i) => tb.rows.isNotEmpty && tb.rows.every((r) => i >= r.length || r[i] is num || r[i] is RNum || '${r[i]}'.isEmpty));
    for (final r in tb.rows) {
      for (var i = 0; i < n && i < r.length; i++) {
        final w = (r[i] is RBar ? barW : fonts.textWidth('${r[i]}', size)) + 2 * pad;
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
      for (var i = 0; i < n; i++) i < r.length && r[i] is! RBar ? (wrapCol.contains(i) ? _wrap(fonts, '${r[i]}', widths[i] - 2 * pad, size) : [fonts.fit('${r[i]}', widths[i] - 2 * pad, size)]) : [''],
    ];
    final headerLines = [for (var i = 0; i < n; i++) _wrap(fonts, tb.headers[i], widths[i] - 2 * pad, size, bold: true)];
    final headerRows = headerLines.fold(1, (m, l) => math.max(m, l.length));
    // 1.6.0 PRD: the standards of the criteria of the table, under its title
    final note = tb.standards.isEmpty ? const <String>[] : _wrap(fonts, tb.standards, avail, 6.5);
    void header({bool cont = false}) {
      page.fillColor(_ink);
      page.text(left, y, cont ? '${tb.title} ${b.t('pdf.cont')}' : tb.title, size: 10, bold: true);
      y -= 12;
      if (!cont && note.isNotEmpty) {
        page.fillColor(_grey);
        for (final l in note) {
          page.text(left, y + 2, l, size: 6.5);
          y -= 8.5;
        }
        y -= 1.5;
      }
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

  /// Natural width (pt) of a timeline column.
  static const barW = 110.0;

  /// A timeline cell [w] wide from [x] on the text line at [baseline]: the
  /// whole schedule as a thin track, the task's days as a bar over it.
  void _bar(RBar c, double x, double baseline, double w) {
    if (c.total <= 0 || w <= 0) return;
    final a = x + w * c.start / c.total, b = math.max(a + 1.5, x + w * c.end / c.total);
    page.fillColor(_lightGrey);
    page.rect(x, baseline + 1.5, w, 2, fill: true, stroke: false);
    page.fillColor(_brand);
    page.rect(a, baseline - 0.25, b - a, 5.5, fill: true, stroke: false);
    page.fillColor(_ink);
  }
}

List<String> _wrap(PdfFonts fonts, String s, double width, double size, {bool bold = false}) {
  final words = s.split(RegExp(r'\s+'));
  final lines = <String>[];
  var cur = '';
  for (final w in words) {
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
