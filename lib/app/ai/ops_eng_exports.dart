/// Engineering operations of the File menu exports that export_file does
/// not take: the PDF plot with every sheet option (sets of sheets per zone
/// or area, windows, construction details, charts, the base map), the PNG
/// image of the sheet, the plain DXF R12, GPX and the text report, and the
/// share link. Every file goes through the app's own download helper and is
/// always confirmed by the user.
library;

import 'dart:typed_data';

import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../core/api.dart';
import '../actions.dart' show pdfTexts;
import '../io/pdf_font_loader.dart';
import '../io/png_export.dart' show pngDpiFor, sheetPng;
import '../state/controller.dart' show BaseMap;
import 'agent_tools.dart';
import 'ops_eng_common.dart';

/// Sheet options common to the PDF and the PNG of a sheet.
Map<String, Object?> _sheetProps() => {
  'page': str('Sheet size; default a3.', [for (final p in PageSize.values) p.name]),
  'landscape': bool_('Landscape (default true) or portrait.'),
  'scale': num_('Scale denominator 1:N (e.g. 500); omitted = fit the drawing to the sheet.'),
  'labels': bool_('Result labels (default true).'),
  'wetted_radii': bool_('Wetted circles of the sprinklers (default true).'),
  'legend': bool_('Legend (default true).'),
  'bom_on_sheet': bool_('Bill of materials beside the drawing (needs results; default true).'),
  'base_map': bool_('The base map on screen under the drawing (needs a georeference and a base map shown; default true when available).'),
};

/// The sheet options of [a] (shared fields).
Future<SheetOptions> _sheetOf(AgentToolbox b, ToolArgs a) async {
  final c = b.c;
  final scale = a.number('scale', min: 1, max: 1e6);
  var o = SheetOptions(
    page: PageSize.values.byName(a.str('page') ?? 'a3'),
    landscape: a.flag('landscape') ?? true,
    scale: scale,
    labels: a.flag('labels') ?? true,
    wettedRadii: a.flag('wetted_radii') ?? true,
    legend: a.flag('legend') ?? true,
    bomOnSheet: (a.flag('bom_on_sheet') ?? true) && c.results != null,
  );
  final mapAvailable = b.p.meta.georef != null && c.baseMap != BaseMap.none && c.baseMapSnapshot != null;
  if ((a.flag('base_map') ?? true) && mapAvailable) {
    final snap = await c.baseMapSnapshot!();
    if (snap != null) {
      o = o.copyWith(
        rasters: [PlotRaster(bytes: snap.$1, mime: 'image/png', corners: snap.$2, opacity: c.baseMapOpacity)],
        attribution: c.baseMapAttribution?.call() ?? '',
      );
    }
  }
  return o;
}

List<AgentTool> exportOperations(AgentToolbox b) {
  final c = b.c;
  final t = b.t;
  return [
    engOp(
      b,
      name: 'export_sheet_pdf',
      effect: ToolEffect.export,
      description: 'File → Export drawing → PDF with every option of the plot dialog: page size and orientation, scale, labels, wetted circles, legend, the bill of materials beside the drawing, the reports after the sheets, the base map under the drawing, a set of sheets (an overview plus one sheet per zone or per irrigated area, the others greyed), extra sheets of chosen windows (or the current view), construction detail sheets (trench, valve box, sprinkler riser, drip connection, air valve, thrust block, pump suction, filter station, drawn with the project\'s own pipes and parts) and the chart pages (grade lines, profiles, pump curves). export_file "pdf" makes the plain single sheet. Always confirmed by the user (a download in the browser). Inputs: page, landscape, scale, labels, wetted_radii, legend, bom_on_sheet, include_reports (needs results), base_map, split single|zones|areas, dim_others (default true), windows [{bbox [minX, minY, maxX, maxY] m, title, scale}] (≤ 20), current_view (a sheet of the user\'s view), details (names or ["all"]), charts (needs results, a profile path or a catalogue pump). Output: the file and its sheets.',
      schema: obj({
        ..._sheetProps(),
        'include_reports': bool_('Report pages after the sheets (needs results; default false).'),
        'split': str('One sheet, or an overview plus a sheet per zone or irrigated area; default single.', [for (final s in SheetSplit.values) s.name]),
        'dim_others': bool_('On a zone or area sheet, the other zones in grey (default true).'),
        'windows': arr(obj({'bbox': bbox, 'title': str('Sheet title.'), 'scale': num_('1:N; omitted = fit.')}, required: ['bbox']), 'Extra sheets of chosen regions.', 20),
        'current_view': bool_('Add a sheet of the user\'s current view.'),
        'details': arr(str(null, ['all', for (final k in DetailKind.values) k.name]), 'Construction detail sheets.'),
        'charts': bool_('Chart pages (grade lines, profiles, pump curves).'),
      }),
      summary: (i) => engSummary(b, 'ai.op.export_sheet_pdf.${i['split'] ?? 'single'}', 'ai.op.export_sheet_pdf.single'),
      run: (a, i) async {
        if (b.p.entities.isEmpty) throw ToolInputError(t('msg.nothingToExport'));
        var o = await _sheetOf(b, a);
        final windows = <SheetWindow>[];
        for (final w in (i['windows'] as List?) ?? const []) {
          final m = Map<String, dynamic>.from(w as Map);
          final box = bboxOf(m['bbox']);
          if (box.width <= 0 || box.height <= 0) throw ToolInputError('A window needs a bbox with an area.');
          final sc = m['scale'];
          windows.add(SheetWindow(bounds: box, title: '${m['title'] ?? ''}', scale: sc is num && sc > 0 ? sc.toDouble() : null));
        }
        if ((a.flag('current_view') ?? false) && !c.camera.size.isEmpty) windows.add(SheetWindow(bounds: c.camera.visible, title: t('sheet.view')));
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
        await preparePdfFonts(pdfTexts(c, reports: o.includeReports || o.bomOnSheet || o.details.isNotEmpty || o.charts), language: c.lang);
        final builder = c.exporter().sheetBuilder();
        final Object data;
        try {
          data = c.exporter().exportDrawing(DrawingFormat.pdf, sheet: o);
        } catch (e) {
          throw ToolInputError('The PDF could not be made (${c.describeError(e)}).');
        }
        final file = '${engStem(c)}.pdf';
        await engFileSink(c, file, DrawingFormat.pdf.mime, data);
        final extra = (split == SheetSplit.zones ? zoneMembers(b.p, c.results).length : (split == SheetSplit.areas ? areaZones(b.p, const {}).length : 0)) + windows.length;
        return ToolOutput(
          'Saved $file: ${1 + extra} drawing sheets (${o.page.label} ${o.landscape ? 'landscape' : 'portrait'}, 1:${engN(o.scale ?? builder.sheetScale(o), 0)}${o.scale == null ? ' to fit' : ''}), ${builder.detailSheets(o).length} detail sheets${o.includeReports ? ', report pages' : ''}${o.charts ? ', chart pages' : ''}${o.rasters.isEmpty ? '' : ', base map under the drawing'}.${(a.flag('charts') ?? false) && !chartsAvailable ? ' No charts: they need design results, a profile path or a catalogue pump.' : ''}',
        );
      },
    ),
    engOp(
      b,
      name: 'export_sheet_png',
      effect: ToolEffect.export,
      description: 'File → Export drawing → PNG: the drawing sheet (frame, drawing, legend, bill of materials, title block — the overview of the PDF) as a PNG image at a resolution, for a message or a presentation. Always confirmed by the user (a download in the browser). Inputs: page, landscape, scale, labels, wetted_radii, legend, bom_on_sheet, base_map (as export_sheet_pdf), dpi 50–600 (default 200; lowered for very large sheets). Output: the file and its size in pixels.',
      schema: obj({..._sheetProps(), 'dpi': num_('Resolution, 50–600 dots per inch; default 200.')}),
      run: (a, _) async {
        if (b.p.entities.isEmpty) throw ToolInputError(t('msg.nothingToExport'));
        final o = (await _sheetOf(b, a)).copyWith(dpi: a.number('dpi', min: 50, max: 600) ?? 200);
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
