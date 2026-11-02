import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/design/agronomy.dart';
import '../core/io/pdf_sheet.dart';
import '../core/io/project_export.dart';
import '../core/io/share_link.dart';
import '../core/model/currency.dart';
import '../core/model/entities.dart';
import '../core/model/project.dart';
import 'examples.dart';
import 'i18n.dart' show I18n; // 1.6.0 PRD
import 'io/file_io.dart';
import 'io/pdf_font_loader.dart';
import 'io/project_store.dart';
import 'io/storage_info.dart';
import 'state/controller.dart';
import 'state/workspace.dart';
import 'widgets/dialogs/export_dialogs.dart';
import 'widgets/dialogs/import_progress_dialog.dart';
import 'widgets/dialogs/pdf_import_dialog.dart';
import 'theme.dart';

const pointScopeZone = HydraulicScope.zone;
const pointScopeMain = HydraulicScope.mainline;

/// Project file extension (open JSON).
const projectExtension = '.oci.json';

/// Every importable format (drawings, GIS, surveys, rasters).
const importAccept = '.dxf,.dwg,.dgn,.pdf,.kml,.kmz,.shp,.zip,.geojson,.json,.gpx,.xml,.landxml,.inp,.las,.laz,.csv,.txt,.xyz,.pts,.pnezd,.jpg,.jpeg,.png,.tif,.tiff';

Future<void> confirmNew(BuildContext context, ProjectController c) async {
  if (c.dirty) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c.t('file.new')),
        content: Text(c.t('msg.unsavedConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(c.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(c.t('ok'))),
        ],
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
    // a project whose copy here has changes not saved to a file opens as a
    // copy, so that copy stays offered (see ProjectController.openProject)
    c.loadJson(f.$2);
  } catch (e) {
    c.notify(openErrorMessage(c, e));
  }
}

/// What to tell when a file did not open as a project: one that is no
/// project (a renamed drawing, damaged JSON, another kind of JSON) says to
/// import it instead; anything else with the program's own wording.
String openErrorMessage(ProjectController c, Object e) => e is FormatException || e is TypeError || e is ArgumentError || e is NoSuchMethodError
    ? c.t('msg.notProject', {'m': '${c.t('menu.file')} → ${c.t('file.importDrawing').replaceAll(RegExp(r'\s*\(.*\)'), '').replaceAll('…', '').trim()}'})
    : c.t('msg.error', {'e': c.describeError(e)});

/// Opens a project file into the current tab when it is still blank,
/// otherwise in a new tab.
Future<void> openProjectInTabAction(BuildContext context, Workspace ws) async {
  final f = await openTextFile(accept: '.json,.oci,.icad');
  if (f == null) return;
  openJsonInTab(ws, f.$2);
}

/// Loads project JSON into the blank current tab or a new tab. [fromStore]:
/// the browser's own copy (recent projects), whose uid is kept; [asCopy]: a
/// project with a uid of its own (a shared link, which carries the uid of
/// whoever sent it).
ProjectController? openJsonInTab(Workspace ws, String json, {bool fromStore = false, bool asCopy = false}) {
  final cur = ws.current;
  final reuse = cur.project.entities.isEmpty && !cur.dirty;
  final target = reuse ? cur : ws.addTab();
  try {
    target.loadJson(json, fromStore: fromStore, asCopy: asCopy);
    return target;
  } catch (e) {
    if (!reuse) ws.closeTab(ws.tabs.indexOf(target));
    ws.current.notify(openErrorMessage(ws.current, e));
    return null;
  }
}

/// Opens a project kept in the browser store (recent projects): the tab
/// that has it already, else a tab with the copy kept (changes not saved to
/// a file stay marked as such).
Future<void> openStoredAction(Workspace ws, StoredProject p) async {
  // already open in a tab?
  for (var i = 0; i < ws.tabs.length; i++) {
    if (ws.tabs[i].project.meta.uid == p.uid) {
      ws.select(i);
      return;
    }
  }
  final json = await ws.current.store.load(p.uid);
  if (json == null) {
    if (ws.current.store.has(p.uid)) ws.current.notify(ws.current.t('store.err.read'));
    return;
  }
  for (final t in ws.tabs) {
    if (t.project.meta.uid == p.uid) return; // opened meanwhile
  }
  final c = openJsonInTab(ws, json, fromStore: true);
  if (c == null) return;
  if (p.kind == 'autosave') {
    c.dirty = true;
    c.store.acknowledge(p.uid);
  }
}

/// Copies (or cuts) the selection of the active tab to the clipboard.
Future<void> copySelectionAction(Workspace ws, {bool cut = false}) async {
  final c = ws.current;
  // a cut refused while a design runs has said why already
  if (cut && c.busy) {
    c.editAllowed();
    return;
  }
  final n = await ws.copy(cut: cut);
  c.notify(n == 0 ? c.t('msg.nothingSelected') : c.t(cut ? 'msg.cut' : 'msg.copied', {'n': '$n'}));
}

/// Pastes the clipboard into the active tab (new ids; layers/catalog merged).
Future<void> pasteAction(Workspace ws) async {
  final c = ws.current;
  final n = await ws.paste();
  final onMap = n > 0 && (ws.lastPaste?.placedOnMap ?? false);
  c.notify(n == 0 ? c.t('msg.clipboardEmpty') : '${c.t('msg.pasted', {'n': '$n'})}${onMap ? ' ${c.t('msg.pastedOnMap')}' : ''}');
}

String _safeName(ProjectController c) {
  final n = c.project.meta.name.trim();
  return (n.isEmpty ? c.t('name.newProject') : n).replaceAll(RegExp(r'[^\w\-]+', unicode: true), '_');
}

/// File → Save (Ctrl+S): the project file, written again into the same
/// file where the browser allows it (file system access, Chromium on the
/// computer), else through its save dialog or as a download. The project is
/// marked saved only once the file is written (or handed to the browser as
/// a download, which tells nothing back): a cancelled dialog leaves it
/// unsaved. [saveAs] always asks where.
Future<void> saveProjectAction(BuildContext context, ProjectController c, {bool saveAs = false}) async {
  final name = '${_safeName(c)}$projectExtension';
  final (file, compact) = c.fileJson();
  final r = await saveProjectFile(name, file, handle: c.fileHandle, saveAs: saveAs, onHandle: (h) => c.fileHandle = h);
  c.track('save');
  switch (r) {
    case FileSaveResult.cancelled:
      c.notify(c.t('msg.saveCancelled'));
      return;
    case FileSaveResult.failed:
      c.notify(c.t('msg.saveFailed'));
      return;
    case FileSaveResult.saved:
      c.markSaved(compact: compact);
      c.notify(c.t('msg.saved'));
    case FileSaveResult.downloaded:
      c.markSaved(compact: compact);
      c.notify(c.t('msg.savedDownload', {'f': name}));
  }
  unawaited(_keepBrowserStorage(c));
}

/// File → Save as copy: the project becomes a copy of its own (a new uid:
/// its copy in the browser, versions and recent entry no longer mix with
/// the original's), named as a copy, then saved where the user says.
Future<void> saveCopyAction(BuildContext context, ProjectController c) async {
  if (!c.editAllowed()) return;
  c.renewUid();
  final suffix = c.t('file.copyName', {'n': ''}).trim();
  if (!c.project.meta.name.trimRight().endsWith(suffix)) c.project.meta.name = c.t('file.copyName', {'n': c.project.meta.name});
  c.fileHandle = null;
  if (!context.mounted) return;
  await saveProjectAction(context, c, saveAs: true);
}

/// After the first save of a visit: asks the browser to keep this site's
/// storage under pressure (the copies, versions and conversations), which
/// Chromium grants to sites in use without a question; Firefox would show a
/// question at every first save, so there it is asked from File → Browser
/// storage only.
Future<void> _keepBrowserStorage(ProjectController c) async {
  if (_askedPersistence || browserIsFirefox) return;
  _askedPersistence = true;
  if (await storagePersisted() ?? true) return;
  await requestPersistentStorage();
}

bool _askedPersistence = false;

Future<void> importDxfAction(BuildContext context, ProjectController c) => importDrawingAction(context, c);

/// Imports DXF, DWG, KML/KMZ, SHP, survey points or raster images.
Future<void> importDrawingAction(BuildContext context, ProjectController c) async {
  final f = await openBinaryFile(accept: importAccept);
  if (f == null) return;
  // a PDF plan: page, scale and contents are asked in a dialog
  if (f.$1.toLowerCase().endsWith('.pdf')) {
    if (context.mounted) await importPdfAction(context, c, f.$1, f.$2);
    return;
  }
  try {
    // large files are read in slices, with their progress and a cancel button
    final summary = context.mounted ? await showImportProgressDialog(context, c, f.$1, f.$2) : c.importFile(f.$1, f.$2);
    c.notify(summary == null ? c.t('fmt.import.cancelled') : '${c.t('msg.imported')}: $summary');
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
    await preparePdfFonts(pdfTexts(c, reports: sheet.includeReports || sheet.bomOnSheet || sheet.details.isNotEmpty || sheet.charts), language: c.lang);
  }
  await deliverExport(c, '${_safeName(c)}.${f.extension}', f.mime, () => c.exporter().exportDrawing(f, sheet: sheet));
}

/// Texts a PDF of the project may show: the title block, names and notes
/// typed in the drawing, layer names, a sample of the interface language
/// and, with [reports], every report cell.
Iterable<String> pdfTexts(ProjectController c, {bool reports = false}) sync* {
  final m = c.project.meta;
  yield* [m.name, m.client, m.site, m.designer, m.notes];
  // 1.6.0 PRD: the professional title block
  final tb = m.titleBlock;
  yield* [tb.company, tb.responsible, tb.council, tb.registration, tb.responsibilityRecord, tb.car, tb.waterPermit, tb.municipality, tb.drawingNumber];
  for (final r in tb.revisions) {
    yield* [r.revision, r.date, r.description, r.author];
  }
  for (final l in c.project.layers) {
    yield l.name;
  }
  // (the flow names title the charts)
  for (final f in c.project.systemFlows) {
    yield f.name;
  }
  for (final e in c.project.entities) {
    yield e.name;
    switch (e) {
      case TextEntity t:
        yield t.text;
      case LeaderEntity l:
        yield l.text;
      case CommentEntity n:
        yield* [n.text, n.author];
      case RevisionCloudEntity r:
        yield* [r.revision, r.description];
      case ControlValveEntity v:
        yield v.zoneName;
      default:
        break;
    }
  }
  for (final k in const ['plot.title', 'reports.zone', 'reports.bom', 'rep.zone', 'rep.description', 'menu.mainline', 'name.report']) {
    yield c.t(k);
  }
  // 1.6.0 PRD: the title block, grid, thematic sheets and document packages
  for (final k in I18n.keys) {
    if (k.startsWith('prd.')) yield c.t(k);
  }
  if (reports && c.results != null) {
    for (final tb in c.reportTables()) {
      yield tb.title;
      yield tb.standards; // 1.6.0 PRD
      yield* tb.headers;
      for (final row in tb.rows) {
        for (final cell in row) {
          if (cell is String) yield cell;
        }
      }
    }
  }
}

/// The report tables with the project's own data that need no design.
const _noDesignTables = {'water', 'crop', 'schedule', 'comments', 'revisions', 'scenarios', 'requirement', 'requirementTotals', 'licensing', 'trench'};

/// Exports the report: every table there is (without a design, the ones
/// that need none: water, crops, comments, revisions, requirements…).
Future<void> exportReportAction(BuildContext context, ProjectController c, ReportFormat f) async {
  if (c.results == null && !c.reportTables().any((t) => _noDesignTables.contains(t.key) && !t.isEmpty)) {
    c.notify(c.t('msg.needResults'));
    return;
  }
  if (f == ReportFormat.pdf) await preparePdfFonts(pdfTexts(c, reports: true), language: c.lang);
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

/// Opens a gallery example from File → Examples, the welcome dialog or the
/// phone menu without replacing any work: in the current tab only when it
/// is blank (nothing drawn, nothing changed), otherwise in a new tab, or,
/// without a workspace, after the user confirms.
Future<void> openExampleAction(BuildContext context, ProjectController c, ExampleId id, {Workspace? ws}) async {
  final blank = c.project.entities.isEmpty && !c.dirty && !c.canUndo;
  if (blank) {
    loadExampleAction(c, id);
    return;
  }
  if (ws != null) {
    final tab = ws.addTab();
    loadExampleAction(tab, id);
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(c.t('file.examples')),
      content: Text(c.t('msg.exampleReplaces')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(c.t('cancel'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(c.t('ok'))),
      ],
    ),
  );
  if (ok == true) {
    await c.autosaveNow();
    loadExampleAction(c, id);
  }
}

/// Loads one of the gallery examples into [c] (the start-up `?example=<id>`
/// in the URL, the tutorial, tests; the menus go through
/// [openExampleAction]).
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

/// Turns the selected laterals and tapes into plain pipes and says how many.
void convertToPipeAction(ProjectController c) {
  if (!c.editAllowed()) return;
  final n = c.convertSelectedToPipe();
  c.notify(c.t(n == 0 ? 'msg.toPipeNone' : 'msg.toPipeDone', {'n': '$n'}));
}

/// File → Share by link: the project (without pictures and results) inside
/// an address that opens it in OpenCADIrrigation; nothing is uploaded.
Future<void> shareLinkAction(BuildContext context, ProjectController c) {
  final t = c.t;
  final base = (Uri.base.scheme == 'http' || Uri.base.scheme == 'https') ? '${Uri.base.origin}/' : shareLinkBase;
  final link = shareLinkFor(shareableProjectJson(c.project.toJson()), base: base);
  final tooLong = link.length > shareLinkMaxLength;
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t('share.title'), style: const TextStyle(fontSize: 15)),
      scrollable: true,
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('share.hint'), style: TextStyle(fontSize: 12, color: Cad.fg70)),
            const SizedBox(height: 10),
            if (tooLong)
              Text(t('share.tooLong'), style: TextStyle(fontSize: 12, color: Cad.attention))
            else ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Cad.fg24),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  link.length > 600 ? '${link.substring(0, 600)}…' : link,
                  key: const Key('share_link_text'),
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 6),
              Text(t('share.size', {'n': '${(link.length / 1024).toStringAsFixed(1)} KB'}), style: TextStyle(fontSize: 11, color: Cad.fg54)),
              if (link.length > shareLinkWarnLength) Text(t('share.long'), style: TextStyle(fontSize: 11, color: Cad.attention)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('close'))),
        if (!tooLong)
          FilledButton.icon(
            key: const Key('share_copy'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (ctx.mounted) Navigator.pop(ctx);
              c.notify(t('share.copied'));
            },
            icon: const Icon(Icons.copy, size: 16),
            label: Text(t('share.copy')),
          ),
      ],
    ),
  );
}
