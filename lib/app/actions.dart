import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/design/agronomy.dart';
import '../core/io/pdf_sheet.dart';
import '../core/io/project_export.dart';
import '../core/model/currency.dart';
import '../core/model/entities.dart';
import '../core/model/project.dart';
import 'examples.dart';
import 'io/file_io.dart';
import 'io/project_store.dart';
import 'state/controller.dart';
import 'state/workspace.dart';
import 'widgets/dialogs/export_dialogs.dart';

const pointScopeZone = HydraulicScope.zone;
const pointScopeMain = HydraulicScope.mainline;

/// Project file extension (open JSON).
const projectExtension = '.oci.json';

/// Every importable format (drawings, GIS, surveys, rasters).
const importAccept = '.dxf,.dwg,.kml,.kmz,.shp,.zip,.csv,.txt,.xyz,.pts,.pnezd,.jpg,.jpeg,.png,.tif,.tiff';

Future<void> confirmNew(BuildContext context, ProjectController c) async {
  if (c.dirty) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c.t('file.new')),
        content: Text(c.t('msg.unsavedConfirm')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(c.t('cancel'))), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(c.t('ok')))],
      ),
    );
    if (ok != true) return;
  }
  c.newProject();
}

Future<void> openProjectAction(BuildContext context, ProjectController c) async {
  final f = await openTextFile(accept: '.json,.oci,.icad');
  if (f == null) return;
  try {
    c.loadJson(f.$2);
    c.store.acknowledge(c.project.meta.uid);
  } catch (e) {
    c.notify(c.t('msg.error', {'e': '$e'}));
  }
}

/// Opens a project file into the current tab when it is still blank,
/// otherwise in a new tab.
Future<void> openProjectInTabAction(BuildContext context, Workspace ws) async {
  final f = await openTextFile(accept: '.json,.oci,.icad');
  if (f == null) return;
  openJsonInTab(ws, f.$2);
}

/// Loads project JSON into the blank current tab or a new tab.
ProjectController? openJsonInTab(Workspace ws, String json) {
  final cur = ws.current;
  final reuse = cur.project.entities.isEmpty && !cur.dirty;
  final target = reuse ? cur : ws.addTab();
  try {
    target.loadJson(json);
    target.store.acknowledge(target.project.meta.uid);
    return target;
  } catch (e) {
    if (!reuse) ws.closeTab(ws.tabs.indexOf(target));
    ws.current.notify(cur.t('msg.error', {'e': '$e'}));
    return null;
  }
}

/// Opens a project kept in the browser store (recent projects).
void openStoredAction(Workspace ws, StoredProject p) {
  final json = ws.current.store.load(p.uid);
  if (json == null) return;
  // already open in a tab?
  for (var i = 0; i < ws.tabs.length; i++) {
    if (ws.tabs[i].project.meta.uid == p.uid) {
      ws.select(i);
      return;
    }
  }
  openJsonInTab(ws, json);
}

/// Copies (or cuts) the selection of the active tab to the clipboard.
Future<void> copySelectionAction(Workspace ws, {bool cut = false}) async {
  final c = ws.current;
  final n = await ws.copy(cut: cut);
  c.notify(n == 0 ? c.t('msg.nothingSelected') : c.t(cut ? 'msg.cut' : 'msg.copied', {'n': '$n'}));
}

/// Pastes the clipboard into the active tab (new ids; layers/catalog merged).
Future<void> pasteAction(Workspace ws) async {
  final c = ws.current;
  final n = await ws.paste();
  c.notify(n == 0 ? c.t('msg.clipboardEmpty') : c.t('msg.pasted', {'n': '$n'}));
}

String _safeName(ProjectController c) {
  final n = c.project.meta.name.trim();
  return (n.isEmpty ? c.t('name.newProject') : n).replaceAll(RegExp(r'[^\w\-]+', unicode: true), '_');
}

Future<void> saveProjectAction(BuildContext context, ProjectController c) async {
  await saveTextFile('${_safeName(c)}$projectExtension', c.saveJson());
  c.track('save');
  c.notify(c.t('msg.saved'));
}

Future<void> importDxfAction(BuildContext context, ProjectController c) => importDrawingAction(context, c);

/// Imports DXF, DWG, KML/KMZ, SHP, survey points or raster images.
Future<void> importDrawingAction(BuildContext context, ProjectController c) async {
  final f = await openBinaryFile(accept: importAccept);
  if (f == null) return;
  try {
    final summary = c.importFile(f.$1, f.$2);
    c.notify('${c.t('msg.imported')}: $summary');
  } catch (e, st) {
    debugPrint('$e\n$st');
    c.notify(c.t('msg.error', {'e': c.describeError(e)}));
  }
}

Future<void> exportDxfAction(BuildContext context, ProjectController c) => exportDrawingAction(context, c, DrawingFormat.dxf);

Future<void> exportCsvAction(BuildContext context, ProjectController c) => exportReportAction(context, c, ReportFormat.csv);

/// Exports the drawing in any supported format. Geographic formats ask for a
/// georeference when the project has none; PDF asks for the sheet options.
Future<void> exportDrawingAction(BuildContext context, ProjectController c, DrawingFormat f) async {
  if (c.project.entities.isEmpty) {
    c.notify(c.t('msg.nothingToExport'));
    return;
  }
  if (f.needsGeoref && c.project.meta.georef == null) {
    final ok = await showGeoreferenceDialog(context, c);
    if (ok != true || c.project.meta.georef == null) return;
  }
  var sheet = const SheetOptions();
  if (f == DrawingFormat.pdf) {
    if (!context.mounted) return;
    final o = await showPlotDialog(context, c);
    if (o == null) return;
    sheet = o;
  }
  await deliverExport(c, '${_safeName(c)}.${f.extension}', f.mime, () => c.exporter().exportDrawing(f, sheet: sheet));
}

/// Exports the design report (needs results).
Future<void> exportReportAction(BuildContext context, ProjectController c, ReportFormat f) async {
  if (c.results == null) {
    c.notify(c.t('msg.needResults'));
    return;
  }
  await deliverExport(c, '${_safeName(c)}_${c.t('name.report')}.${f.extension}', f.mime, () => c.exporter().exportReport(f));
}

/// Exports the controller programme (irrigation schedule) as CSV.
Future<void> exportScheduleAction(BuildContext context, ProjectController c) async {
  final prog = buildControllerProgram(c.project, c.results, days: 14);
  if (prog.entries.isEmpty) {
    c.notify(c.t('msg.noAreas'));
    return;
  }
  await deliverExport(c, '${_safeName(c)}_schedule.csv', 'text/csv', () => controllerProgramCsv(prog, t: c.t.call));
}

/// Builds the export and hands it to the browser as a download.
Future<void> deliverExport(ProjectController c, String filename, String mime, Object Function() build) async {
  try {
    final data = build();
    if (data is Uint8List) {
      await saveBinaryFile(filename, data, mime: mime);
    } else {
      await saveTextFile(filename, data as String, mime: mime);
    }
    c.notify(c.t('msg.exported', {'f': filename}));
  } catch (e, st) {
    debugPrint('$e\n$st');
    c.notify(c.t('msg.error', {'e': c.describeError(e)}));
  }
}

/// Computes the allowable submain envelope for the selected laterals.
void feedEnvelopeAction(ProjectController c) {
  final n = c.computeFeedEnvelope();
  c.notify(n == 0 ? c.t('msg.selectLateral') : c.t('msg.feedComputed', {'n': '$n'}));
}

/// Loads one of the gallery examples (File → Examples, the welcome dialog,
/// `?example=<id>` in the URL).
void loadExampleAction(ProjectController c, [ExampleId id = ExampleId.orchard]) {
  final p = buildExample(id, c.t.call, lang: c.lang);
  // the user's currency (region or explicit choice) when it differs from the
  // language default the example was written in
  final code = c.defaultCurrency();
  final rate = exchangeRate(p.params.currencyCode, code);
  if (rate != null && code != p.params.currencyCode) p.setCurrency(code, rate: rate);
  c.openProject(p, dirty: true);
  c.track('example');
}

/// The orchard example (kept for callers and tests; see `examples.dart`).
Project buildExampleProject(String Function(String key, [Map<String, String>? args]) t, {String lang = 'en'}) => buildExample(ExampleId.orchard, t, lang: lang);
