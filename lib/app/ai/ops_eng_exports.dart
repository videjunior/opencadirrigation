/// Engineering operations of the File menu exports that export_file does
/// not take: the PDF plot with every sheet option (sets of sheets per zone
/// or area, windows, construction details, charts, the base map), the PNG
/// image of the sheet, the plain DXF R12, GPX and the text report, and the
/// share link. Every file goes through the app's own download helper and is
/// always confirmed by the user. Before a plot is exported, preview_sheet
/// shows the model one of its sheets as it will print, with a check of its
/// layout (sheet_check.dart) and what fixes each finding.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../core/api.dart';
import '../actions.dart' show pdfTexts;
import '../i18n.dart' show I18n;
import '../io/pdf_font_loader.dart';
import '../io/png_export.dart' show pngDpiFor, renderSheetPng, sheetPng;
import '../io/sheet_basemap.dart';
import '../state/controller.dart' show BaseMap;
import 'agent_tools.dart';
import 'ops_eng_common.dart';
import 'view_snapshot.dart' show pictureGeoKey;
import 'vision_mapping.dart' show PictureFrame, VisionSession;
import 'vision_render.dart' show CanvasSnapshots;
import 'vision_tiles.dart' show HttpTileFetcher;

/// Sheet options common to the PDF and the PNG of a sheet.
Map<String, Object?> _sheetProps() => {
  'page': str('Sheet size; default a3.', [for (final p in PageSize.values) p.name]),
  'landscape': bool_('Landscape (default true) or portrait.'),
  'scale': num_('Scale denominator 1:N (e.g. 500); omitted = fit the drawing to the sheet.'),
  'labels': bool_('Result labels (default true).'),
  'wetted_radii': bool_('Wetted circles of the sprinklers (default true).'),
  'legend': bool_('Legend (default true).'),
  'bom_on_sheet': bool_('Bill of materials beside the drawing (needs results; default true).'),
  'base_map': bool_('The base map shown on screen under the drawing, downloaded for everything the sheets show (needs a georeference and a base map shown; default true when available).'),
};

/// The sheet options of [a] (shared fields but the base map).
SheetOptions _sheetOf(AgentToolbox b, ToolArgs a) {
  final c = b.c;
  final scale = a.number('scale', min: 1, max: 1e6);
  return SheetOptions(
    page: PageSize.values.byName(a.str('page') ?? 'a3'),
    landscape: a.flag('landscape') ?? true,
    scale: scale,
    labels: a.flag('labels') ?? true,
    wettedRadii: a.flag('wetted_radii') ?? true,
    legend: a.flag('legend') ?? true,
    bomOnSheet: (a.flag('bom_on_sheet') ?? true) && c.results != null,
  );
}

/// [o] (its sheets all set) with the base map under the drawing when [a]
/// asks for it, the default, and the project can show one.
Future<SheetOptions> _withBaseMap(AgentToolbox b, ToolArgs a, SheetOptions o, {double dpi = sheetMapDpi}) async {
  final c = b.c;
  final mapAvailable = b.p.meta.georef != null && c.baseMap != BaseMap.none && c.baseMapSnapshot != null;
  if (!(a.flag('base_map') ?? true) || !mapAvailable) return o;
  final snaps = b.snapshots;
  return withSheetBaseMap(c, o, dpi: dpi, fetcher: snaps is CanvasSnapshots ? snaps.tiles : const HttpTileFetcher());
}

/// Inputs of a set of sheets (export_sheet_pdf and preview_sheet).
Map<String, Object?> _setProps() => {
  ..._sheetProps(),
  'include_reports': bool_('Report pages after the sheets (needs results; default false).'),
  'split': str('One sheet, or an overview plus a sheet per zone or irrigated area; default single.', [for (final s in SheetSplit.values) s.name]),
  'dim_others': bool_('On a zone or area sheet, the other zones in grey (default true).'),
  'windows': arr(obj({'bbox': bbox, 'title': str('Sheet title.'), 'scale': num_('1:N; omitted = fit.')}, required: ['bbox']), 'Extra sheets of chosen regions.', 20),
  'current_view': bool_('Add a sheet of the user\'s current view.'),
  'details': arr(str(null, ['all', for (final k in DetailKind.values) k.name]), 'Construction detail sheets.'),
  'charts': bool_('Chart pages (grade lines, profiles, pump curves).'),
};

/// The set of sheets [a] asks for (export_sheet_pdf, preview_sheet), the
/// base map not yet under it; and whether charts were asked for that cannot
/// be made (they need design results, a profile path or a catalogue pump).
(SheetOptions, bool) _setOf(AgentToolbox b, ToolArgs a) {
  final c = b.c;
  if (b.p.entities.isEmpty) throw ToolInputError(b.t('msg.nothingToExport'));
  var o = _sheetOf(b, a);
  final windows = <SheetWindow>[];
  for (final w in (a.input['windows'] as List?) ?? const []) {
    final m = Map<String, dynamic>.from(w as Map);
    final box = bboxOf(m['bbox']);
    if (box.width <= 0 || box.height <= 0) throw ToolInputError('A window needs a bbox with an area.');
    final sc = m['scale'];
    windows.add(SheetWindow(bounds: box, title: '${m['title'] ?? ''}', scale: sc is num && sc > 0 ? sc.toDouble() : null));
  }
  if ((a.flag('current_view') ?? false) && !c.camera.size.isEmpty) windows.add(SheetWindow(bounds: c.camera.visible, title: b.t('sheet.view')));
  final names = a.strings('details');
  final details = names.contains('all')
      ? [...DetailKind.values]
      : [
          for (final k in DetailKind.values)
            if (names.contains(k.name)) k,
        ];
  final split = SheetSplit.values.byName(a.str('split') ?? 'single');
  if (split == SheetSplit.zones && zoneMembers(b.p, c.results).isEmpty) throw ToolInputError('No zone to split by: the drawing has no zone valve with items.');
  if (split == SheetSplit.areas && areaZones(b.p, const {}).isEmpty) throw ToolInputError('No irrigated area to split by.');
  final chartsAvailable = c.results != null || c.profilePath != null || b.p.entities.any((e) => e is PumpEntity && b.p.catalog.pump(e.pumpSpecId) != null);
  final charts = (a.flag('charts') ?? false) && chartsAvailable;
  o = o.copyWith(
    includeReports: (a.flag('include_reports') ?? false) && c.results != null,
    split: split,
    dimOthers: a.flag('dim_others') ?? true,
    windows: windows,
    details: details,
    charts: charts,
    profilePath: charts ? c.profilePath : null,
    clearProfilePath: !charts || c.profilePath == null,
  );
  return (o, (a.flag('charts') ?? false) && !chartsAvailable);
}

/// The texts [PdfSheetBuilder] may measure and draw for [o] (its fonts are
/// loaded for them first, as for the PDF).
Future<void> _sheetFonts(AgentToolbox b, SheetOptions o) => preparePdfFonts(pdfTexts(b.c, reports: o.includeReports || o.bomOnSheet || o.details.isNotEmpty || o.charts), language: b.c.lang);

List<AgentTool> exportOperations(AgentToolbox b) {
  final c = b.c;
  final t = b.t;
  return [
    engOp(
      b,
      name: 'export_sheet_pdf',
      effect: ToolEffect.export,
      description: 'File → Export drawing → PDF with every option of the plot dialog: page size and orientation, scale, labels, wetted circles, legend, the bill of materials beside the drawing, the reports after the sheets, the base map under the drawing, a set of sheets (an overview plus one sheet per zone or per irrigated area, the others greyed), extra sheets of chosen windows (or the current view), construction detail sheets (trench, valve box, sprinkler riser, drip connection, air valve, thrust block, pump suction, filter station, drawn with the project\'s own pipes and parts) and the chart pages (grade lines, profiles, pump curves). export_file "pdf" makes the plain single sheet. Look at the sheets first with preview_sheet (the same inputs, plus the sheet to see) and fix what it finds. Always confirmed by the user (a download in the browser). Inputs: page, landscape, scale, labels, wetted_radii, legend, bom_on_sheet, include_reports (needs results), base_map, split single|zones|areas, dim_others (default true), windows [{bbox [minX, minY, maxX, maxY] m, title, scale}] (≤ 20), current_view (a sheet of the user\'s view), details (names or ["all"]), charts (needs results, a profile path or a catalogue pump). Output: the file and its sheets.',
      schema: obj(_setProps()),
      summary: (i) => engSummary(b, 'ai.op.export_sheet_pdf.${i['split'] ?? 'single'}', 'ai.op.export_sheet_pdf.single'),
      run: (a, _) async {
        var (o, noCharts) = _setOf(b, a);
        o = await _withBaseMap(b, a, o);
        await _sheetFonts(b, o);
        final builder = c.exporter().sheetBuilder();
        final Object data;
        try {
          data = c.exporter().exportDrawing(DrawingFormat.pdf, sheet: o);
        } catch (e) {
          throw ToolInputError('The PDF could not be made (${c.describeError(e)}).');
        }
        final file = '${engStem(c)}.pdf';
        await engFileSink(c, file, DrawingFormat.pdf.mime, data);
        final split = o.split;
        final extra = (split == SheetSplit.zones ? zoneMembers(b.p, c.results).length : (split == SheetSplit.areas ? areaZones(b.p, const {}).length : 0)) + o.windows.length;
        return ToolOutput(
          'Saved $file: ${1 + extra} drawing sheets (${o.page.label} ${o.landscape ? 'landscape' : 'portrait'}, 1:${engN(o.scale ?? builder.sheetScale(o), 0)}${o.scale == null ? ' to fit' : ''}), ${builder.detailSheets(o).length} detail sheets${o.includeReports ? ', report pages' : ''}${o.charts ? ', chart pages' : ''}${o.rasters.isEmpty ? '' : ', base map under the drawing'}.${noCharts ? ' No charts: they need design results, a profile path or a catalogue pump.' : ''}',
        );
      },
    ),
    engOp(
      b,
      name: 'preview_sheet',
      description:
          'Looks at one sheet of the plot as it will print, with a check of its layout, before it is exported. The sheet ("sheet", 1-based, default 1) of the set export_sheet_pdf makes with the same inputs — frame, drawing, the base map under it when the export prints one, north arrow, scale bar, legend, bill of materials, title block — comes as one picture within the size the model in use reads pixel for pixel, and the check is computed from the sheet itself: texts overlapping each other or hidden under the north arrow, scale bar or sheet title; texts cut by the edge of the drawing area or beyond the frame; texts under ${fmt(previewMinTextMm, 1)} mm high in print; a viewport the drawing fills less than ${(previewMinFill * 100).round()} % of (scale too small, or a few far items stretching it) or runs out of (scale too large); whether the north arrow, scale bar, legend and materials table are there; the title block fields, the empty ones flagged. Each finding says where it is (sheet mm, picture pixels, world metres and the item when known), and the answer ends with what fixes each kind (scale, split, windows, page, set_project_info, update_entities…). Use it before export_sheet_pdf or export_sheet_png, fix what it finds and look again. No side effects: nothing is saved and the project does not change (the base map tiles are downloaded as for the export). Inputs: those of export_sheet_pdf, sheet, size (longest side in pixels; default $previewSheetSide or the most the model reads). Output: the picture, the sheets of the set (number, kind, title, scale, paper), the picture\'s scale in pixels per paper mm, the title block, the layout check and the next steps.',
      schema: obj({
        ..._setProps(),
        'sheet': int_('Which sheet to look at, 1-based (default 1): the drawing sheets first (the overview, then the zone, area and window sheets), then the detail sheets.'),
        'size': int_('Longest side of the picture in pixels, 256–8192 (default $previewSheetSide); kept within what the model in use reads unscaled (a larger value is reduced, with a note).'),
      }),
      summary: (i) => t('ai.op.preview_sheet', {'n': '${i['sheet'] ?? 1}'}),
      run: (a, _) => _previewSheet(b, a),
    ),
    engOp(
      b,
      name: 'export_sheet_png',
      effect: ToolEffect.export,
      description: 'File → Export drawing → PNG: the drawing sheet (frame, drawing, legend, bill of materials, title block — the overview of the PDF) as a PNG image at a resolution, for a message or a presentation. Look at it first with preview_sheet (sheet 1, the same inputs) and fix what it finds. Always confirmed by the user (a download in the browser). Inputs: page, landscape, scale, labels, wetted_radii, legend, bom_on_sheet, base_map (as export_sheet_pdf), dpi 50–600 (default 200; lowered for very large sheets). Output: the file and its size in pixels.',
      schema: obj({..._sheetProps(), 'dpi': num_('Resolution, 50–600 dots per inch; default 200.')}),
      run: (a, _) async {
        if (b.p.entities.isEmpty) throw ToolInputError(t('msg.nothingToExport'));
        final asked = a.number('dpi', min: 50, max: 600) ?? 200;
        final o = await _withBaseMap(b, a, _sheetOf(b, a).copyWith(dpi: asked), dpi: asked);
        final Uint8List png;
        try {
          png = await sheetPng(c, o);
        } catch (e) {
          throw ToolInputError('The image could not be made (${c.describeError(e)}).');
        }
        final file = '${engStem(c)}.png';
        await engFileSink(c, file, 'image/png', png);
        final dpi = pngDpiForSheet(o);
        return ToolOutput('Saved $file (${o.page.label} ${o.landscape ? 'landscape' : 'portrait'} at ${engN(dpi, 0)} dpi, ${engN(png.length / 1024, 0)} KB).');
      },
    ),
    engOp(
      b,
      name: 'export_more_formats',
      effect: ToolEffect.export,
      description: 'File → Export: the formats export_file does not list — "dxf_r12" (the plain DXF R12 for older CAD programs that do not read AutoCAD 2000 files), "gpx" (waypoints and tracks for a GPS receiver; needs a georeference) and "report_txt" (the design reports as plain text; needs design results). Always confirmed by the user (a download in the browser). Input: format. Output: the file name.',
      schema: obj(
        {
          'format': str(null, ['dxf_r12', 'gpx', 'report_txt']),
        },
        required: ['format'],
      ),
      summary: (i) => t('ai.op.export_more_formats', {'n': '${i['format']}'}),
      run: (a, _) async {
        if (b.p.entities.isEmpty) throw ToolInputError(t('msg.nothingToExport'));
        final f = a.str('format', required: true)!;
        final String file;
        final String mime;
        final Object data;
        try {
          if (f == 'report_txt') {
            engNeedResults(c);
            file = '${engStem(c)}_${t('name.report')}.${ReportFormat.txt.extension}';
            mime = ReportFormat.txt.mime;
            data = c.exporter().exportReport(ReportFormat.txt);
          } else {
            final df = f == 'gpx' ? DrawingFormat.gpx : DrawingFormat.dxfR12;
            if (df.needsGeoref && b.p.meta.georef == null) throw ToolInputError('gpx needs a georeference: set_site (or set_project_info with latitude and longitude) first.');
            file = '${engStem(c)}${df == DrawingFormat.dxfR12 ? '_r12' : ''}.${df.extension}';
            mime = df.mime;
            data = c.exporter().exportDrawing(df);
          }
        } on ToolInputError {
          rethrow;
        } catch (e) {
          throw ToolInputError('The file could not be made (${c.describeError(e)}).');
        }
        await engFileSink(c, file, mime, data);
        return ToolOutput('Saved $file.');
      },
    ),
    engOp(
      b,
      name: 'share_link',
      effect: ToolEffect.export,
      description: 'File → Share by link: the whole project (without pictures and results) packed into an address that opens it in OpenCADIrrigation in any browser — nothing is uploaded; the data travel inside the link. By default it is copied to the user\'s clipboard (always confirmed by the user). Very large projects make links too long to share (the op says so; save the project file instead). Inputs: copy (to the clipboard; default true), include_link (return the link itself when it is at most 4000 characters; default false). Output: the link size and whether it was copied.',
      schema: obj({'copy': bool_('Copy to the clipboard (default true).'), 'include_link': bool_('Return the link (≤ 4000 characters).')}),
      run: (a, _) async {
        final base = (Uri.base.scheme == 'http' || Uri.base.scheme == 'https') ? '${Uri.base.origin}/' : shareLinkBase;
        final link = shareLinkFor(shareableProjectJson(b.p.toJson()), base: base);
        if (link.length > shareLinkMaxLength) throw ToolInputError('${t('share.tooLong')} (${engN(link.length / 1024, 0)} KB): save the project file instead (export_file "project").');
        final copy = a.flag('copy') ?? true;
        if (copy) {
          await Clipboard.setData(ClipboardData(text: link));
          c.notify(t('share.copied'));
        }
        final show = (a.flag('include_link') ?? false) && link.length <= 4000;
        return ToolOutput(
          'Share link of ${engN(link.length / 1024, 1)} KB${copy ? ', copied to the user\'s clipboard' : ''}.${link.length > shareLinkWarnLength ? ' It is long: some messengers cut such links; a file is safer.' : ''}${show ? '\n$link' : ''}',
        );
      },
    ),
  ];
}

/// The resolution the PNG of [o] gets (lowered for very large sheets).
double pngDpiForSheet(SheetOptions o) => pngDpiFor(o.widthMm / 25.4 * 72, o.heightMm / 25.4 * 72, o.dpi);

// ---------------------------------------------------------------- preview_sheet

/// Longest side of the picture of a sheet preview by default (pixels), when
/// the model in use reads that much.
const previewSheetSide = 1600;

/// Texts lower than this on paper (cap height, mm) are flagged by the
/// preview: about the 1.8 mm of the smallest standard lettering, leaving
/// alone the program's own 1.6 mm labels (contours, spot heights, pumps).
const previewMinTextMm = 1.6;

/// Texts running into each other less deep than this (mm) only touch.
const previewOverlapMm = 0.3;

/// The share of its viewport's limiting side the drawing of a sheet should
/// fill: less wastes the paper (the scale is too small for it).
const previewMinFill = 0.4;

/// A preview's PNG larger than this gets a JPEG twin when that is clearly
/// smaller (a photographic one, over the base map), as the other pictures
/// the model is shown.
const _previewJpegAbove = 256 * 1024;

/// The picture of a sheet for the model.
typedef _SheetPicture = ({Uint8List bytes, String type, int width, int height});

/// preview_sheet: sheet "sheet" of the set of [a] drawn as it prints, its
/// layout checked, and what fixes each finding.
Future<ToolOutput> _previewSheet(AgentToolbox b, ToolArgs a) async {
  final c = b.c;
  final t = b.t;
  var (o, noCharts) = _setOf(b, a);
  final builder = c.exporter().sheetBuilder();
  final plan = builder.sheetPlan(o);
  final details = builder.detailSheets(o);
  final count = plan.length + details.length;
  final n = a.integer('sheet', min: 1, max: 1000) ?? 1;
  if (n > count) {
    throw ToolInputError('The set has $count sheet${count == 1 ? '' : 's'}, so "sheet" is ${count == 1 ? '1' : '1–$count'} (the report and chart pages after the sheets are not previewed).');
  }
  final notes = <String>[];
  final k = _previewPxPerMm(b, a, o, notes);
  o = await _withBaseMap(b, a, o, dpi: k * 25.4);
  await _sheetFonts(b, o);
  final RecordedSheet rec;
  final _SheetPicture pic;
  try {
    rec = builder.recordSheet(o, index: n - 1);
    pic = await _sheetPicture(rec, k);
  } catch (e) {
    throw ToolInputError('The sheet could not be drawn (${c.describeError(e)}).');
  }
  final review = SheetReview(rec, fonts: builder.fonts, ignoreImages: [for (final r in o.rasters) r.bytes]);
  final height = review.heightMm;
  final drawing = n <= plan.length;
  final spec = drawing ? plan[n - 1] : null;
  final scale = spec?.scale ?? 0;
  final upm = scale / 1000;
  final area = drawing && review.regions.isNotEmpty ? review.regions.first : null;
  // the world point at the centre of the drawing area (as drawSheet places it)
  final centre = spec == null || area == null ? null : (spec.window?.center ?? builder.sheetViews(o.copyWith(split: SheetSplit.single, windows: const [], details: const [])).first.$1.center);
  final kx = pic.width / review.widthMm, ky = pic.height / height;
  Pt? world(Pt mm) => centre == null || area == null ? null : centre + (mm - area.center) * upm;
  Bounds worldOf(Bounds mm) => Bounds.ofPoints([world(Pt(mm.minX, mm.minY))!, world(Pt(mm.maxX, mm.maxY))!]);
  Bounds paperOf(Bounds w) => Bounds.ofPoints([area!.center + (Pt(w.minX, w.minY) - centre!) / upm, area.center + (Pt(w.maxX, w.maxY) - centre) / upm]);
  String xy(Pt p) => '[${fmt(p.x, 1)}, ${fmt(p.y, 1)}]';
  String pixels(Pt mm) => '[${(mm.x * kx).round()}, ${((height - mm.y) * ky).round()}]';
  String place(Pt mm, {bool onDrawing = true}) {
    final w = onDrawing ? world(mm) : null;
    return 'sheet ${xy(mm)} mm, picture ${pixels(mm)} px${w == null ? '' : ', world ${xy(w)} m'}';
  }

  final sources = Map<SheetTextBox, Entity?>.identity();
  String quote(SheetTextBox x) {
    final s = '"${AgentToolbox.short(x.text, 44)}"';
    if (x.region != 0 || centre == null) return s;
    final e = sources.putIfAbsent(x, () => _printedBy(b, x.text, world(x.anchor)!, upm));
    return e == null ? s : '$s (${b.kindOf(e)} ${e.id})';
  }

  final out = <String>[];
  final paper = '${o.page.label} ${o.landscape ? 'landscape' : 'portrait'} (${fmt(o.widthMm, 0)} × ${fmt(o.heightMm, 0)} mm)';
  out.add(
    spec != null
        ? 'Sheet $n of $count: the ${spec.kind.name} sheet${spec.title.isEmpty ? '' : ' "${spec.title}"'} at 1:${engN(scale, 0)} on $paper${o.rasters.isEmpty ? '' : ', the base map under the drawing'}.'
        : 'Sheet $n of $count: construction details (${details[n - 1 - plan.length].map((x) => x.name).join(', ')}), each at its own scale, on $paper.',
  );
  // ---- the picture and its scale
  final id = VisionSession.of(b).nextId('s');
  out.add(
    'Picture $id: the sheet as it prints, ${pic.width}×${pic.height} px (${pic.type == 'image/jpeg' ? 'JPEG' : 'PNG'}), ${fmt(kx, 2)} px per paper mm (${engN(kx * 25.4, 0)} dpi). Positions below: sheet [x, y] mm from its bottom-left corner (x right, y up, as in the PDF) and picture [px, py] from its top-left corner (y down): px = x × ${fmt(kx, 3)}, py = (${fmt(height, 1)} − y) × ${fmt(ky, 3)}.',
  );
  out.addAll(notes);
  if (spec != null && area != null && centre != null) {
    out.add(
      'Drawing area: sheet [${fmt(area.minX, 1)}, ${fmt(area.minY, 1)}, ${fmt(area.maxX, 1)}, ${fmt(area.maxY, 1)}] mm = picture [${(area.minX * kx).round()}, ${((height - area.maxY) * ky).round()}, ${(area.maxX * kx).round()}, ${((height - area.minY) * ky).round()}] px, showing world ${AgentToolbox.box(worldOf(area))} m at 1:${engN(scale, 0)} (1 paper mm = ${fmt(upm, 3)} m), north up; image_to_world {snapshot "$id", pixels [[px, py], …]} turns what you see there into project coordinates.',
    );
    // the whole picture maps to the world as its drawing area does
    final mpp = upm / kx;
    final minX = centre.x - area.center.x * upm, maxY = centre.y + (height - area.center.y) * upm;
    VisionSession.of(b).add(
      id,
      PictureFrame(Bounds(minX, maxY - pic.height * mpp, minX + pic.width * mpp, maxY), pic.width, pic.height),
      'sheet $n of the plot as it prints (paper; its drawing area shows the world at 1:${engN(scale, 0)})',
      geo: pictureGeoKey(c),
    );
  }
  // ---- the sheets of the set
  out.add('Sheets of the set, $paper each:');
  final windowScales = [
    for (final w in o.windows)
      if (!w.bounds.isEmpty) w.scale,
  ];
  var wi = 0;
  for (var i = 0; i < plan.length; i++) {
    final s = plan[i];
    final fitted = switch (s.kind) {
      SheetKind.overview => o.scale == null,
      SheetKind.window => (wi < windowScales.length ? windowScales[wi++] : null) == null,
      _ => true,
    };
    out.add('${i + 1}. ${s.kind.name}${s.title.isEmpty ? '' : ' "${AgentToolbox.short(s.title, 40)}"'}, 1:${engN(s.scale!, 0)}${fitted ? ' (fitted)' : ''}${i == n - 1 ? '  ← this picture' : ''}');
  }
  for (var j = 0; j < details.length; j++) {
    out.add('${plan.length + j + 1}. details: ${details[j].map((x) => x.name).join(', ')} (each at its own scale)${plan.length + j == n - 1 ? '  ← this picture' : ''}');
  }
  if (o.includeReports || o.charts) {
    out.add('After the sheets: ${[if (o.includeReports) 'the report pages', if (o.charts) 'the chart pages'].join(' and ')} (A4 landscape; not previewed).');
  }
  if (noCharts) out.add('No chart pages: they need design results, a profile path or a catalogue pump.');
  // ---- the title block
  final m = b.p.meta;
  final printed = {
    for (final x in review.texts)
      if (x.region < 0) x.text,
  };
  final missing = <String>[], shortened = <String>[];
  String field(String label, String key, String raw, {String? ifEmpty, bool optional = false}) {
    final v = raw.replaceAll('\n', ' ');
    if (v.trim().isEmpty) {
      if (!optional) missing.add(key);
      return '$label: EMPTY${ifEmpty == null ? '' : ' ($ifEmpty)'}';
    }
    final shown = '$label "${AgentToolbox.short(v, 60)}"';
    if (printed.contains(v)) return shown;
    final cutTo = printed.where((p) => p.length > 1 && p.endsWith('…') && v.startsWith(p.substring(0, p.length - 1))).firstOrNull;
    if (cutTo == null) return shown;
    shortened.add(key);
    return '$shown, cut to fit: it prints "$cutTo"';
  }

  final g = m.georef;
  final sheetField = count == 1 ? '1/1' : '$n/$count${spec == null ? ' · ${t('det.title')}' : (spec.title.isEmpty ? '' : ' · ${spec.title}')}';
  final fields = [
    field('Project', 'name', m.name, ifEmpty: 'it prints "${t('name.newProject')}"'),
    field('Client', 'client', m.client),
    field('Site', 'site', m.site),
    field('Designer', 'designer', m.designer),
    field('Notes', 'notes', m.notes, optional: true, ifEmpty: 'optional; the count of zones / outlets prints there'),
    'Date ${PdfSheetBuilder.dateString(DateTime.now())} (the day of the export)',
    'Scale "${spec == null ? t('det.scaleAsShown') : '1:${scale.round()}'}"',
    'Coordinates ${g == null ? '"${t('pdf.local')}" (no georeference; optional)' : '"${g.crsName}"'}',
    'Sheet "$sheetField"',
  ];
  out.add('Title block: ${fields.join(' · ')}.');
  // ---- the layout check
  out.add('Layout check (computed from the sheet as drawn; sizes in paper mm):');
  final fixes = <String>{};
  final ov = review.overlaps(minDepthMm: previewOverlapMm);
  if (ov.isEmpty) {
    out.add('- Overlapping texts: none.');
  } else {
    out.add('- Overlapping texts: ${ov.length} place${ov.length == 1 ? '' : 's'}${ov.length > 10 ? ', the 10 deepest' : ''}:');
    for (final x in ov.take(10)) {
      final same = x.texts.map((y) => y.text).toSet().length == 1;
      out.add(
        '  · ${x.texts.take(4).map(quote).join(' × ')}${x.texts.length > 4 ? ' and ${x.texts.length - 4} more' : ''}${same ? ' (the same text more than once: a duplicate item?)' : ''}: ${fmt(x.depthMm, 1)} mm into each other at ${place(x.box.center, onDrawing: x.texts.first.region == 0)}.',
      );
    }
    for (final x in ov) {
      fixes.add(x.texts.first.region < 0 ? 'own' : (drawing ? 'overlap' : 'detail'));
    }
  }
  if (drawing) {
    final under = review.underMarks(minDepthMm: previewOverlapMm);
    if (under.isEmpty) {
      final marks = ['the north arrow', 'the scale bar', if (count > 1 && spec!.title.isNotEmpty) 'the sheet title', if (o.rasters.isNotEmpty) 'the map credit'];
      out.add('- Texts under ${marks.sublist(0, marks.length - 1).join(', ')} or ${marks.last}: none.');
    } else {
      out.add('- Texts under the sheet\'s marks: ${under.length}:');
      for (final (x, mk, d) in under.take(8)) {
        out.add('  · ${quote(x)} under the ${_markName(mk.kind)}, ${fmt(d, 1)} mm in, at ${place(x.bounds.center)}.');
      }
      fixes.add('under');
    }
  }
  final edge = drawing ? 'the drawing area' : 'their detail cell';
  final cut = review.cut();
  if (cut.isEmpty) {
    out.add('- Texts cut by the edge of $edge: none.');
  } else {
    out.add('- Texts cut by the edge of $edge: ${cut.length}${cut.length > 8 ? ', the first 8' : ''}:');
    for (final (x, d) in cut.take(8)) {
      out.add('  · ${quote(x)} runs ${fmt(d, 1)} mm out at ${place(x.bounds.center)}.');
    }
    fixes.add(drawing ? 'cut' : 'detail');
  }
  if (spec?.kind == SheetKind.overview) {
    final hidden = review.hidden();
    if (hidden.isNotEmpty) {
      out.add('- Texts wholly outside the drawing area (they do not print): ${hidden.length}, e.g. ${hidden.take(3).map((x) => '${quote(x)} at ${place(x.anchor)}').join('; ')}.');
      fixes.add('overflow');
    }
  }
  final off = review.beyond(Bounds(o.marginMm, o.marginMm, review.widthMm - o.marginMm, height - o.marginMm));
  if (off.isNotEmpty) {
    out.add('- The sheet\'s own texts beyond its frame: ${off.take(5).map((e) => '${quote(e.$1)} ${fmt(e.$2, 1)} mm out at ${place(e.$1.bounds.center, onDrawing: false)}').join('; ')}.');
    fixes.add('own');
  }
  final small = review.small(previewMinTextMm);
  if (small.isEmpty) {
    out.add('- Texts lower than ${fmt(previewMinTextMm, 1)} mm (cap height in print): none.');
  } else {
    out.add('- Texts lower than ${fmt(previewMinTextMm, 1)} mm (cap height in print; under about 1.8 mm they read poorly): ${small.length}${small.length > 10 ? ', the first 10' : ''}:');
    for (final x in small.take(10)) {
      out.add('  · ${quote(x)}: ${fmt(x.capMm, 2)} mm at ${place(x.anchor)}.');
    }
    fixes.add(drawing ? 'small' : 'detail');
  }
  // the viewport: how much of the drawing area the drawing fills
  double? fitted;
  var fillAtFit = 1.0;
  Bounds? mainPart;
  if (spec != null && area != null && centre != null) {
    final w = spec.window;
    final fit = switch (spec.kind) {
      SheetKind.overview => builder.sheetScale(o.copyWith(clearScale: true)),
      SheetKind.window => fitScale(w!.inflate(math.max(w.width, w.height) * 0.04 + 1), area.width - 2 * SheetLayout.padMm, area.height - 2 * SheetLayout.padMm),
      _ => scale,
    };
    fitted = fit;
    final subject = w == null ? review.drawnIn(0) : paperOf(w);
    if (!subject.isEmpty) {
      final fw = subject.width / area.width, fh = subject.height / area.height;
      fillAtFit = math.max(fw, fh) * scale / fit;
      final tol = math.max(2.0, 0.02 * math.max(area.width, area.height));
      final outs = [
        if (area.minX - subject.minX > tol) 'on the left by ${fmt(area.minX - subject.minX, 0)} mm',
        if (subject.maxX - area.maxX > tol) 'on the right by ${fmt(subject.maxX - area.maxX, 0)} mm',
        if (subject.maxY - area.maxY > tol) 'at the top by ${fmt(subject.maxY - area.maxY, 0)} mm',
        if (area.minY - subject.minY > tol) 'at the bottom by ${fmt(area.minY - subject.minY, 0)} mm',
      ];
      final what = switch (spec.kind) {
        SheetKind.overview => 'the drawing',
        SheetKind.window => 'the window',
        SheetKind.zone => 'the zone',
        SheetKind.area => 'the area',
      };
      final head = '- Viewport: the drawing area is ${fmt(area.width, 0)} × ${fmt(area.height, 0)} mm; $what spans ${_pct(fw)} of its width and ${_pct(fh)} of its height';
      if (outs.isNotEmpty) {
        out.add('$head and runs out of it ${outs.join(', ')}: that part does not print (it fits at 1:${engN(fit, 0)}).');
        fixes.add('overflow');
      } else if (math.max(fw, fh) < previewMinFill) {
        out.add('$head: less than ${_pct(previewMinFill)}, so 1:${engN(scale, 0)} is a small scale for this sheet (1:${engN(fit, 0)} fills it).');
        fixes.add('empty');
      } else {
        out.add('$head.');
        if (spec.kind == SheetKind.overview) {
          final core = review.bulk(0);
          final share = core.isEmpty ? 1.0 : math.max(core.width / area.width, core.height / area.height);
          if (share < previewMinFill) {
            final far = review.away(0, core, pad: 0.1 * math.max(core.width, core.height) + 2);
            mainPart = worldOf(core);
            out.add(
              '- Most of the drawing (all but the 1 % of its items farthest out each way) spans only ${_pct(share)} of the viewport: ${far.isEmpty ? 'a few items' : '${far.length} group${far.length == 1 ? '' : 's'} of items'} far from it stretch the sheet${far.isEmpty ? '' : ' — ${[for (final x in far) _farItems(b, worldOf(x))].join('; ')}'}. The main part is world ${AgentToolbox.box(mainPart)} m.',
            );
            fixes.add('stray');
          }
        }
      }
    }
  }
  // the marks, legend and tables of a drawing sheet
  if (drawing) {
    final na = review.mark(SheetMarkKind.northArrow), sb = review.mark(SheetMarkKind.scaleBar);
    final own = [
      for (final x in review.texts)
        if (x.region < 0) x,
    ];
    final legendTitle = own.where((x) => x.bold && x.text == t('pdf.legend')).firstOrNull;
    final rows = legendTitle == null ? 0 : own.where((x) => !x.bold && x.sizePt == 7 && (x.anchor.x - legendTitle.anchor.x - 10).abs() < 0.5).length;
    final bom = own.any((x) => x.bold && x.text == t('pdf.bom'));
    final more = _bomMore(t, own);
    final revisions = own.any((x) => x.bold && x.text == t('pdf.revisions'));
    out.add(
      '- North arrow: ${na == null ? 'MISSING' : 'yes, at ${place(na.box.center, onDrawing: false)}'}. Scale bar: ${sb == null ? 'MISSING' : 'yes, "${sb.texts.map((x) => x.text).join(' ')}" at ${place(sb.box.center, onDrawing: false)}'}.',
    );
    out.add(
      '- Legend: ${legendTitle != null ? 'yes, $rows layer${rows == 1 ? '' : 's'}' : (o.legend ? 'none (nothing on the sheet to list)' : 'none (legend false)')}. Materials table: ${bom ? (more == null ? 'yes, every item' : 'CUT, $more more items do not fit') : (c.results == null ? 'none (no design results)' : (o.bomOnSheet ? 'none (no materials on this sheet)' : 'none (bom_on_sheet false)'))}${revisions ? '. Revision table: yes' : ''}.',
    );
    if (legendTitle == null && !o.legend) fixes.add('legend');
    if (more != null) fixes.add('bom');
  }
  out.add(
    '- Labels: ${o.labels ? 'on' : 'off (labels false)'}. Design results: ${c.results == null ? 'none, so the labels show no flows or pressures and there is no materials table' : 'yes'}. Base map: ${o.rasters.isNotEmpty ? 'under the drawing${o.attribution.isEmpty ? '' : ' (${o.attribution})'}' : _noMap(b, a)}.',
  );
  if (!o.labels) fixes.add('labels');
  if (c.results == null) fixes.add('results');
  // ---- what fixes each finding
  final bigger = _largerPage(o.page), smaller = _smallerPage(o.page);
  final larger = bigger == null ? 'a larger page' : 'a larger page (page "${bigger.name}")';
  final fitText = fitted == null ? '' : ': it fits at 1:${engN(fitted, 0)}';
  String? tip;
  if (spec?.kind == SheetKind.overview) {
    final now = builder.sheetScale(o.copyWith(clearScale: true)), other = builder.sheetScale(o.copyWith(landscape: !o.landscape, clearScale: true));
    if (other < now) {
      tip = 'Tip: ${o.landscape ? 'portrait (landscape false)' : 'landscape (landscape true)'} fits the overview at 1:${engN(other, 0)}, a larger scale than the 1:${engN(now, 0)} it fits at now.';
    }
  }
  final steps = [
    if (fixes.contains('overlap'))
      'Overlapping texts: give them room — a larger scale spread over more sheets (split "zones" or "areas"; windows [{bbox, title, scale}] of the crowded parts) or $larger with the scale fitted (scale omitted); or fewer texts (wetted_radii false declutters; labels false drops every name and result). Items that carry their own text: move or shorten them — text and leader items (update_entities "p" or "pts", "text", "h"; transform_entities to move), a comment prints until it is resolved (update_entities "done": true), a valve prints its zone name ("zone"), an area its name ("name"); update_entities discards the design results, so run_design again before exporting. Conditional labels (set_label_rules) colour results on the screen only: they do not print on the sheets.',
    if (fixes.contains('under')) 'Texts under the marks: the north arrow (top right of the drawing area), the scale bar (bottom left), the sheet title (top left) and the map credit (bottom right) keep their corners; move the item (transform_entities), or let the drawing sit otherwise (another scale, orientation or page).',
    if (fixes.contains('cut')) spec?.kind == SheetKind.overview ? 'Texts cut by the edge: fit the scale (omit scale$fitText) or take a larger N, or move the item inwards.' : 'Texts cut by the edge: what lies at the edge of a zone, area or window sheet belongs to its neighbours and prints whole on the overview; a window with a larger bbox prints it whole here.',
    if (fixes.contains('small'))
      'Small texts: text and leader items are sized in metres on the ground ("h"), so at 1:${engN(scale, 0)} they print h × ${fmt(1000 / scale, 3)} mm — update_entities {"h": ${fmt(2.5 * scale / 1000, 2)}} prints 2.5 mm here; or a larger scale (a smaller N). The program\'s own labels print at 1.8 mm on every sheet.',
    if (fixes.contains('detail')) 'The detail sheets are laid out by the program: $larger gives each detail a larger cell.',
    if (fixes.contains('own')) 'The sheet\'s own texts (legend, tables, title block) do not fit: $larger.',
    if (fixes.contains('overflow'))
      'The drawing runs out of the drawing area: fit the scale (omit scale$fitText) or take a larger N; or show the parts larger on sheets of their own (split "zones" or "areas", windows); or $larger.',
    if (fixes.contains('empty'))
      'The drawing fills little of its viewport: scale ${engN(fitted ?? scale, 0)}${spec?.kind == SheetKind.overview ? ' (or scale omitted, which fits the drawing)' : ''} fills it${fillAtFit < previewMinFill && smaller != null ? '; it stays small even so, and a smaller page (page "${smaller.name}") suits it' : ''}.',
    if (fixes.contains('stray'))
      'Items far from the rest stretch the sheet: if they are strays, delete or move them (delete_entities, transform_entities; list_entities with their bbox names them) or hide their layer (edit_layers visible false: hidden layers do not print); if they belong, keep the overview and add a window sheet of the main part (windows [{"bbox": ${AgentToolbox.box(mainPart ?? Bounds.empty)}, "title": "…"}]) at a larger scale.',
    if (fixes.contains('legend')) 'legend true adds the legend of the layers.',
    if (fixes.contains('bom')) 'The materials table is cut: $larger, or bom_on_sheet false with include_reports true (the whole bill of materials on the report pages).',
    if (fixes.contains('results')) 'No design results: run_design first; the labels then show flows and pressures, and the materials table comes.',
    if (fixes.contains('labels')) 'labels true prints the names and the results.',
    if (missing.isNotEmpty) 'Empty title block fields (${missing.join(', ')}): set_project_info {${missing.join(', ')}} — ask the user for what you do not know rather than inventing it.',
    if (shortened.isNotEmpty) 'Title block fields cut to fit (${shortened.join(', ')}): shorten them with set_project_info, or take $larger.',
    ?tip,
  ];
  out.add(steps.isEmpty ? 'Next steps: none needed, the sheet looks ready.' : 'Next steps:');
  for (final s in steps) {
    out.add('- $s');
  }
  out.add(
    'Nothing was saved and the project did not change. When the sheet is right, export it with export_sheet_pdf and the same inputs without "sheet" and "size" (export_sheet_png makes the overview as an image)${count > 1 ? '; preview_sheet with sheet 1–$count shows the others' : ''}.',
  );
  return ToolOutput(out.join('\n'), images: [ToolImage(pic.type, base64Encode(pic.bytes))]);
}

/// Pixels per paper millimetre of the preview of [o]: the longest side
/// asked for ([previewSheetSide] by default), within the limits of the
/// model in use in whole pixels; why it is smaller goes to [notes].
double _previewPxPerMm(AgentToolbox b, ToolArgs a, SheetOptions o, List<String> notes) {
  final l = b.pictures;
  final asked = a.integer('size', min: 256, max: 8192);
  var side = asked ?? math.min(previewSheetSide, l.maxSide);
  if (side > l.maxSide) {
    notes.add('size $side was reduced to ${l.maxSide} px, the most the model in use reads pixel for pixel.');
    side = l.maxSide;
  }
  final w = o.widthMm, h = o.heightMm, long = math.max(w, h), short = math.min(w, h);
  final maxShort = l.maxShortSide;
  var k = side / long;
  if (maxShort != null && short * k > maxShort) k = maxShort / short;
  if (w * h * k * k > l.maxPixels) k = math.sqrt(l.maxPixels / (w * h));
  bool over() => (w * k).round() * (h * k).round() > l.maxPixels || (long * k).round() > l.maxSide || (maxShort != null && (short * k).round() > maxShort);
  for (var i = 0; i < 50 && over(); i++) {
    k *= 0.997;
  }
  if (asked != null && (long * k).round() < side - 1) {
    notes.add(
      'The picture is ${(w * k).round()}×${(h * k).round()} px rather than $side px long: the most of this sheet the model in use reads pixel for pixel (about ${fmt(l.maxPixels / 1e6, 2)} megapixels${maxShort == null ? '' : ', the shorter side at most $maxShort px'}).',
    );
  }
  return k;
}

/// [sheet] painted at [pxPerMm]: a PNG, or a JPEG when the PNG is large and
/// the JPEG clearly smaller (a sheet over the base map), as the other
/// pictures the model is shown (vision_render.dart).
Future<_SheetPicture> _sheetPicture(RecordedSheet sheet, double pxPerMm) async {
  final png = await renderSheetPng(sheet, dpi: pxPerMm * 25.4);
  // the size from the PNG header
  int be32(int i) => (png[i] << 24) | (png[i + 1] << 16) | (png[i + 2] << 8) | png[i + 3];
  final w = be32(16), h = be32(20);
  if (png.length > _previewJpegAbove) {
    try {
      final codec = await ui.instantiateImageCodec(png);
      final frame = await codec.getNextFrame();
      codec.dispose();
      final image = frame.image;
      try {
        final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (raw != null) {
          final jpeg = encodeJpegRgba(raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes), image.width, image.height);
          if (jpeg.length < 0.8 * png.length) return (bytes: jpeg, type: 'image/jpeg', width: image.width, height: image.height);
        }
      } finally {
        image.dispose();
      }
    } on Object {
      // the PNG then
    }
  }
  return (bytes: png, type: 'image/png', width: w, height: h);
}

/// The item that prints [s] near [at] (world m) on a sheet at [upm] metres
/// per paper mm: a text, leader or comment by its text, a valve by its zone,
/// a pipe, pump or device by its catalogue item, a contour or spot height by
/// its elevation, the letter in the symbol of a supply, pump or controller,
/// anything else by its name; the nearest within 8 mm on the paper, else
/// null.
Entity? _printedBy(AgentToolbox b, String s, Pt at, double upm) {
  final cat = b.p.catalog;
  Entity? best;
  var bestD = 8 * upm;
  for (final e in b.p.entities) {
    final names = switch (e) {
      TextEntity x => [x.text],
      LeaderEntity x => [x.text],
      CommentEntity x => [_commentLine(x)],
      ControlValveEntity x => [x.zoneName],
      PipeEntity x => [cat.pipe(x.pipeSpecId)?.name ?? ''],
      WaterSupplyEntity x => [x.name, 'W'],
      PumpEntity x => [cat.pump(x.pumpSpecId)?.name ?? b.t('tool.pump'), 'P'],
      ControllerEntity x => [x.name, 'C'],
      MiscHydraulicEntity x => [cat.valve(x.valveSpecId)?.name ?? ''],
      ContourEntity x => [fmt(x.elevation, 1)],
      SpotHeightEntity x => [fmt(x.elevation, 1)],
      _ => [e.name],
    };
    if (!names.any((name) => name.isNotEmpty && (s == name || s.startsWith('$name ')))) continue;
    final bb = e.bounds;
    final dx = math.max(0.0, math.max(bb.minX - at.x, at.x - bb.maxX)), dy = math.max(0.0, math.max(bb.minY - at.y, at.y - bb.maxY));
    final d = math.sqrt(dx * dx + dy * dy);
    if (d <= bestD) {
      bestD = d;
      best = e;
    }
  }
  return best;
}

/// The line a comment prints (as plot.dart writes it).
String _commentLine(CommentEntity cm) {
  var note = cm.text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (note.length > 90) note = '${note.substring(0, 89)}…';
  return cm.author.isEmpty ? note : '${cm.author}: $note';
}

/// The items in world box [w] (far from the rest of a sheet), for the model.
String _farItems(AgentToolbox b, Bounds w) {
  final near = w.inflate(math.max(1.0, 0.02 * math.max(w.width, w.height)));
  final items = [
    for (final e in b.p.entities)
      if (near.contains(e.bounds.center)) '${b.kindOf(e)} ${e.id}',
  ];
  return 'at world ${AgentToolbox.box(w)} m${items.isEmpty ? '' : ' (${items.take(4).join(', ')}${items.length > 4 ? ' and ${items.length - 4} more' : ''})'}';
}

/// How many items the materials table of a sheet left out (its closing
/// line, pdf.bomMore), or null when it shows them all.
int? _bomMore(I18n t, Iterable<SheetTextBox> own) {
  final probe = t('pdf.bomMore', {'n': '\u0001'});
  final at = probe.indexOf('\u0001');
  if (at < 0) return null;
  final head = probe.substring(0, at), tail = probe.substring(at + 1);
  for (final x in own) {
    if (head.isEmpty ? !x.text.endsWith(tail) : !x.text.startsWith(head)) continue;
    final m = RegExp(r'^\d+').firstMatch(x.text.substring(head.length));
    if (m != null) return int.parse(m.group(0)!);
  }
  return null;
}

/// Why no base map is under the drawing.
String _noMap(AgentToolbox b, ToolArgs a) {
  final c = b.c;
  if (a.flag('base_map') == false) return 'off (base_map false)';
  if (b.p.meta.georef == null) return 'none (the project has no georeference: set_site)';
  if (c.baseMap == BaseMap.none) return 'none (the screen shows no base map: set_base_map)';
  if (c.baseMapSnapshot == null) return 'none (no map view here)';
  return 'none (the tiles could not be downloaded)';
}

String _markName(SheetMarkKind k) => switch (k) {
  SheetMarkKind.northArrow => 'north arrow',
  SheetMarkKind.scaleBar => 'scale bar',
  SheetMarkKind.caption => 'sheet title',
  SheetMarkKind.credit => 'map credit',
  SheetMarkKind.other => 'mark',
};

String _pct(double f) => '${(f * 100).round()} %';

/// The next page size up (null for A0).
PageSize? _largerPage(PageSize p) => switch (p) {
  PageSize.a4 => PageSize.a3,
  PageSize.a3 => PageSize.a2,
  PageSize.a2 => PageSize.a1,
  PageSize.a1 => PageSize.a0,
  PageSize.a0 => null,
  PageSize.letter => PageSize.tabloid,
  PageSize.tabloid => PageSize.a2,
};

/// The next page size down (null for A4 and Letter).
PageSize? _smallerPage(PageSize p) => switch (p) {
  PageSize.a0 => PageSize.a1,
  PageSize.a1 => PageSize.a2,
  PageSize.a2 => PageSize.a3,
  PageSize.a3 => PageSize.a4,
  PageSize.tabloid => PageSize.letter,
  PageSize.a4 || PageSize.letter => null,
};
