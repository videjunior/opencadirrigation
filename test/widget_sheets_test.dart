import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/canvas/camera.dart';
import 'package:opencadirrigation/app/io/png_export.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/tools/insert_block_tool.dart';
import 'package:opencadirrigation/app/tools/tools.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/dialogs/blocks_dialogs.dart';
import 'package:opencadirrigation/app/widgets/dialogs/export_dialogs.dart';
import 'package:opencadirrigation/core/io/pdf.dart' show ptPerMm;
import 'package:opencadirrigation/core/io/pdf_sheet.dart';
import 'package:opencadirrigation/core/io/plot.dart';
import 'package:opencadirrigation/core/io/sheet_canvas.dart';
import 'package:opencadirrigation/core/model/blocks.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/main.dart';

/// Records the status line; every other request of the tools is ignored.
class _Host implements ToolHost {
  String status = '';
  @override
  void setStatus(String text) => status = text;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Uint8List _png(int w, int h, int argb) {
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF));
  return Uint8List.fromList(img.encodePng(im));
}

/// The plot dialog choices (sheet sets, details, charts, the PNG mode, the
/// phone layout), the PNG renderer of a sheet and the user blocks dialogs
/// and insert tool.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<ProjectController> pumpShell(WidgetTester tester, {Size size = const Size(1920, 1080), bool design = true}) async {
    TutorialController.markDone();
    setPref('lang', 'pt');
    LocalProjectStore().clearAll();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false));
    await settle(tester);
    final shell = tester.state(find.byType(AppShell)) as dynamic;
    final ProjectController c = shell.c as ProjectController;
    c
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.snap.enabled = false;
    loadExampleAction(c);
    if (design) await tester.runAsync(() => c.runDesign());
    await settle(tester);
    return c;
  }

  BuildContext ctx(WidgetTester tester) => tester.element(find.byType(AppShell));

  testWidgets('PNG of a sheet: size from the resolution, the frame, the drawing and a background raster', (tester) async {
    final c = await pumpShell(tester, design: false);
    final b = c.exporter().sheetBuilder();
    // a red raster over the whole drawing
    final raster = PlotRaster.bounds(_png(8, 8, 0xFFFF0000), c.project.bounds.inflate(5));
    final o = SheetOptions(page: PageSize.a4, rasters: [raster]);
    final rec = b.recordSheet(o);
    expect(rec.images, hasLength(1));
    final png = (await tester.runAsync(() => renderSheetPng(rec, dpi: 50)))!;
    final im = img.decodePng(png)!;
    expect(im.width, (297 / 25.4 * 50).round());
    expect(im.height, (210 / 25.4 * 50).round());
    int luminance(img.Pixel p) => (p.r + p.g + p.b).toInt();
    // the frame line, 10 mm in from the left edge, half-way up
    final fx = (10 / 25.4 * 50).round(), fy = im.height ~/ 2;
    expect([for (var dx = -1; dx <= 1; dx++) luminance(im.getPixel(fx + dx, fy))].reduce((a, b) => a < b ? a : b), lessThan(300));
    // the page margin stays white
    expect(luminance(im.getPixel(3, 3)), 765);
    // the raster shows red under the drawing, at the centre of the project
    var red = 0;
    for (var y = 0; y < im.height; y++) {
      for (var x = 0; x < im.width; x++) {
        final p = im.getPixel(x, y);
        if (p.r > 200 && p.g < 90 && p.b < 90) red++;
      }
    }
    expect(red, greaterThan(im.width * im.height ~/ 20));
    // through the controller: the drawing sheet alone, whatever set the options ask
    final viaController = img.decodePng(
      (await tester.runAsync(() => sheetPng(c, const SheetOptions(page: PageSize.a4, landscape: false, dpi: 30, split: SheetSplit.zones, details: [DetailKind.trench]))))!,
    )!;
    expect((viaController.width, viaController.height), ((210 / 25.4 * 30).round(), (297 / 25.4 * 30).round()));
    // a huge sheet at a high resolution is held under the pixel limit
    expect(pngDpiFor(841 * ptPerMm * 1.414, 841 * ptPerMm, 300), lessThan(300));
    expect(pngDpiFor(420 * ptPerMm, 297 * ptPerMm, 150), 150);
  });

  testWidgets('the sheet canvas paints the PDF graphics state: dashes, opacity, clipping, rotated text', (tester) async {
    await pumpShell(tester, design: false);
    final rec = SheetRecorder(100, 100);
    rec
      ..save()
      ..clipRect(0, 0, 50, 100)
      ..fillColor(0xFF0000FF)
      ..rect(0, 0, 100, 100, stroke: false, fill: true)
      ..restore()
      ..save()
      ..opacity(0.5)
      ..fillColor(0xFF00FF00)
      ..rect(60, 60, 30, 30, stroke: false, fill: true)
      ..restore()
      ..strokeColor(0xFF000000)
      ..lineWidth(2)
      ..dash(true, 4, 4)
      ..line(0, 10, 100, 10)
      ..text(60, 20, 'Ab', size: 8, rotationDeg: 90);
    final png = (await tester.runAsync(() => renderSheetPng(rec.sheet, dpi: 72)))!;
    final im = img.decodePng(png)!;
    expect((im.width, im.height), (100, 100));
    // clipped to the left half
    final inside = im.getPixel(20, 50), outside = im.getPixel(80, 50);
    expect((inside.r.toInt() < 60, inside.b.toInt() > 200), (true, true), reason: 'blue inside the clip');
    expect((outside.r.toInt(), outside.b.toInt()), (255, 255), reason: 'white outside the clip');
    // half-transparent green over white
    final g = im.getPixel(75, 25);
    expect(g.g.toInt(), greaterThan(200));
    expect(g.r.toInt(), inInclusiveRange(100, 160));
    // a dashed line: ink and gaps along y = 90 px
    final row = [for (var x = 60; x < 100; x++) im.getPixel(x, 90).r.toInt()];
    expect(row.any((v) => v < 100), isTrue);
    expect(row.any((v) => v > 200), isTrue);
  });

  testWidgets('plot dialog: a sheet per zone, details, charts and the sheet count', (tester) async {
    final c = await pumpShell(tester);
    final t = c.t;
    final result = showPlotDialog(ctx(tester), c);
    await settle(tester);
    expect(find.byKey(const Key('plot_dpi')), findsNothing);
    final zones = c.project.entities.whereType<ControlValveEntity>().length;
    await tester.tap(find.byKey(const Key('plot_split')));
    await settle(tester, 2);
    await tester.tap(find.text(t('plot.split.zones', {'n': '$zones'})).last);
    await settle(tester, 2);
    expect(find.text(t('plot.sheetCount', {'n': '${1 + zones}'})), findsOneWidget);
    await tester.tap(find.byKey(const Key('plot_detail_trench')));
    await tester.tap(find.byKey(const Key('plot_detail_pumpSuction')));
    await settle(tester, 1);
    expect(find.text(t('plot.sheetCount', {'n': '${2 + zones}'})), findsOneWidget, reason: 'one sheet of details');
    await tester.tap(find.widgetWithText(CheckboxListTile, t('plot.dimOthers')));
    await tester.tap(find.byKey(const Key('plot_charts')));
    await settle(tester, 1);
    await tester.tap(find.byKey(const Key('plot_ok')));
    await settle(tester);
    final o = (await result)!;
    expect(o.split, SheetSplit.zones);
    expect(o.dimOthers, isFalse);
    expect(o.details, [DetailKind.trench, DetailKind.pumpSuction]);
    expect(o.charts, isTrue);
    expect(o.windows, isEmpty);
    // the PDF of these options: overview, zones, details, then the charts
    final pdf = c.exporter().pdfSheet(o);
    final pages = int.parse(RegExp(r'/Count (\d+)').firstMatch(String.fromCharCodes(pdf))!.group(1)!);
    expect(pages, greaterThan(2 + zones));

    // all the details at once, and the current view as an extra sheet
    final again = showPlotDialog(ctx(tester), c);
    await settle(tester);
    await tester.tap(find.byKey(const Key('plot_details_all')));
    await tester.tap(find.widgetWithText(CheckboxListTile, t('plot.currentView')));
    await settle(tester, 1);
    await tester.tap(find.byKey(const Key('plot_ok')));
    await settle(tester);
    final o2 = (await again)!;
    expect(o2.details, DetailKind.values);
    expect(o2.windows, hasLength(1));
    expect(o2.windows.single.title, t('sheet.view'));
    expect(o2.split, SheetSplit.single);
  });

  testWidgets('plot dialog for the PNG: a resolution and no sheet sets', (tester) async {
    final c = await pumpShell(tester, design: false);
    final t = c.t;
    final result = showPlotDialog(
      ctx(tester),
      c,
      raster: true,
      initial: const SheetOptions(split: SheetSplit.zones, details: [DetailKind.trench], charts: true),
    );
    await settle(tester);
    expect(find.text(t('plot.pngTitle')), findsOneWidget);
    expect(find.byKey(const Key('plot_split')), findsNothing);
    expect(find.widgetWithText(CheckboxListTile, t('plot.reports')), findsNothing);
    await tester.tap(find.byKey(const Key('plot_dpi')));
    await settle(tester, 2);
    await tester.tap(find.text('300 dpi').last);
    await settle(tester, 2);
    await tester.tap(find.byKey(const Key('plot_ok')));
    await settle(tester);
    final o = (await result)!;
    expect(o.dpi, 300);
    expect((o.split, o.details.length, o.charts, o.includeReports), (SheetSplit.single, 0, false, false));
  });

  testWidgets('phone: the plot and block dialogs open and scroll without layout errors', (tester) async {
    final c = await pumpShell(tester, size: const Size(390, 844), design: false);
    final t = c.t;
    var result = showPlotDialog(ctx(tester), c);
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -600));
    await settle(tester, 2);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(t('cancel')).last);
    await settle(tester);
    expect(await result, isNull);
    result = showPlotDialog(ctx(tester), c, raster: true);
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(t('cancel')).last);
    await settle(tester);
    // blocks
    final lib = BlockLibrary();
    c.select(c.project.entities.take(3).map((e) => e.id));
    final saved = showSaveBlockDialog(ctx(tester), c, lib);
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(t('cancel')).last);
    await settle(tester);
    expect(await saved, isNull);
    lib.put(BlockDefinition.fromEntities('A', c.project.entities.take(2), Pt.zero));
    final inserted = showInsertBlockDialog(ctx(tester), c, lib);
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(t('cancel')).last);
    await settle(tester);
    expect(await inserted, isNull);
  });

  testWidgets('blocks: save the selection, insert at typed coordinates or with the tool, delete', (tester) async {
    final c = await pumpShell(tester, design: false);
    final t = c.t;
    final lib = BlockLibrary();
    // nothing selected: only a message
    c.select(const []);
    expect(await showSaveBlockDialog(ctx(tester), c, lib), isNull);
    // two entities, base point at their centre
    final picked = c.project.entities.whereType<ControlValveEntity>().take(2).toList();
    c.select(picked.map((e) => e.id));
    final saving = showSaveBlockDialog(ctx(tester), c, lib);
    await settle(tester);
    expect(find.text(t('blk.count', {'n': '2'})), findsOneWidget);
    await tester.enterText(find.byKey(const Key('blk_name')), 'Valves');
    await tester.enterText(find.byKey(const Key('blk_desc')), 'two zones');
    await tester.tap(find.text(t('blk.baseCenter')));
    await settle(tester, 1);
    await tester.tap(find.byKey(const Key('blk_save_ok')));
    await settle(tester);
    final def = (await saving)!;
    expect((def.name, def.description, def.entities.length), ('Valves', 'two zones', 2));
    final bb = def.bounds;
    expect(bb.center.distanceTo(Pt.zero), lessThan(1e-9), reason: 'base point at the centre of the selection');
    expect(c.saveBlock(lib, def), isTrue);
    expect(lib.byName('Valves'), isNotNull);
    expect(c.historyEntries.last.label, 'hist.saveBlock|Valves');

    // insert: typed coordinates, turned and scaled
    final before = c.project.entities.length;
    final asking = showInsertBlockDialog(ctx(tester), c, lib, onDelete: (n) => c.deleteBlock(lib, n));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('blk_rot')), '90');
    await tester.enterText(find.byKey(const Key('blk_scale')), '0');
    await tester.tap(find.text(t('blk.at')));
    await settle(tester, 1);
    await tester.enterText(find.byKey(const Key('blk_ax')), '500');
    await tester.enterText(find.byKey(const Key('blk_ay')), '-200');
    await tester.tap(find.byKey(const Key('blk_insert_ok')));
    await settle(tester, 1);
    expect(find.text(t('blk.invalid')), findsOneWidget, reason: 'a zero scale is refused');
    await tester.enterText(find.byKey(const Key('blk_scale')), '2');
    await tester.tap(find.byKey(const Key('blk_insert_ok')));
    await settle(tester);
    final r = (await asking)!;
    expect((r.block.name, r.rotationDeg, r.scale, r.at), ('Valves', 90.0, 2.0, const Pt(500, -200)));
    final ids = c.insertBlock(r.block, r.at!, rotationDeg: r.rotationDeg, scale: r.scale);
    expect(ids, hasLength(2));
    expect(c.project.entities.length, before + 2);
    expect(c.selection, ids.toSet());
    final copies = [for (final id in ids) c.project.byId(id)! as ControlValveEntity];
    final centre = Bounds.ofPoints(copies.map((v) => v.position)).center;
    expect(centre.distanceTo(const Pt(500, -200)), lessThan(1e-6));
    final d0 = picked[0].position.distanceTo(picked[1].position), d1 = copies[0].position.distanceTo(copies[1].position);
    expect(d1, closeTo(2 * d0, 1e-6));

    // picked on the drawing: the action arms the insert tool, which places a copy at every click
    final arming = insertBlockAction(ctx(tester), c, lib, pickTool: ToolId.junction);
    await settle(tester);
    await tester.tap(find.byKey(const Key('blk_insert_ok')));
    await settle(tester);
    await arming;
    expect(c.activeTool, ToolId.junction);
    expect(pendingBlockInserts[c]!.block.name, 'Valves');
    final host = _Host();
    final tool = InsertBlockTool(c, host, ToolId.junction);
    expect(tool.hintKey, 'hint.insertBlock');
    tool.onMove(const Pt(10, 10));
    final recorder = ui.PictureRecorder();
    tool.paint(Canvas(recorder), Camera(center: Pt.zero, scale: 2, size: const Size(800, 600)));
    recorder.endRecording().dispose();
    expect(host.status, 'Valves');
    final n = c.project.entities.length;
    tool.onDown(const Pt(10, 10));
    tool.onDown(const Pt(30, 10));
    expect(c.project.entities.length, n + 4);
    // with nothing pending the tool hands back to selection
    pendingBlockInserts[c] = null;
    tool.onDown(const Pt(50, 10));
    expect(c.activeTool, ToolId.select);
    expect(c.project.entities.length, n + 4);

    // delete from the insert dialog
    final deleting = showInsertBlockDialog(ctx(tester), c, lib, onDelete: (name) => c.deleteBlock(lib, name));
    await settle(tester);
    await tester.tap(find.byKey(const Key('blk_delete')));
    await settle(tester);
    expect(lib.isEmpty, isTrue);
    expect(find.byKey(const Key('blk_none')), findsOneWidget);
    await tester.tap(find.text(t('cancel')).last);
    await settle(tester);
    expect(await deleting, isNull);
  });
}
