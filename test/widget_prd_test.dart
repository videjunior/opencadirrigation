import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/ai/agent_tools_agent.dart';
import 'package:opencadirrigation/app/ai/ops_eng_common.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/dialogs/document_package_dialog.dart';
import 'package:opencadirrigation/app/widgets/dialogs/export_dialogs.dart';
import 'package:opencadirrigation/app/widgets/dialogs/title_block_dialog.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/io/datum.dart';
import 'package:opencadirrigation/core/io/doc_package.dart' show DocProfile;
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/pdf_sheet.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/title_block.dart';
import 'package:opencadirrigation/main.dart';

/// The deliverables of 1.6.0 (PRD) in the interface and for the assistant:
/// the title block dialog (one undo step, the user's defaults, the logo),
/// the datum of the georeference, the grid and terrain sheets of the plot
/// dialog, the document package dialog, the assistant's operations, and the
/// dialogs on a phone, sideways, right to left and with text twice as big.
class _Host implements AgentHost {
  @override
  AgentPermission permission = AgentPermission.auto;
  @override
  bool stopped = false;
  @override
  String notes = '';
  @override
  final Map<String, Uint8List> files = {};
  @override
  String get instructions => '';
  @override
  void setTodos(List<AiTodo> items) {}
  @override
  Future<List<String>?> ask(List<AiQuestion> questions) async => null;
  @override
  Future<PlanDecision?> reviewPlan(String plan) async => null;
  @override
  void setNotes(String text) => notes = text;
  @override
  bool openTab(Project p) => false;
}

Uint8List _png(int w, int h) => Uint8List.fromList(img.encodePng(img.Image(width: w, height: h, numChannels: 4)..clear(img.ColorRgba8(200, 30, 30, 255))));

void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<ProjectController> pumpShell(WidgetTester tester, {Size size = const Size(1600, 1000), String lang = 'pt', double textScale = 1}) async {
    TutorialController.markDone();
    setPref('lang', lang);
    removePref(titleBlockDefaultsPref);
    LocalProjectStore().clearAll();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false, askAi: false));
    await settle(tester);
    final c = (tester.state(find.byType(AppShell)) as dynamic).c as ProjectController;
    c.autosaveEnabled = false;
    loadExampleAction(c);
    await settle(tester);
    return c;
  }

  BuildContext ctxOf(WidgetTester tester) => tester.element(find.byType(AppShell));

  Future<void> enter(WidgetTester tester, String key, String text) async {
    await tester.enterText(find.descendant(of: find.byKey(Key('tb_$key')), matching: find.byType(TextField)), text);
    await tester.pump();
  }

  testWidgets('the title block dialog: one undo step, Cancel puts it back, the defaults', (tester) async {
    final c = await pumpShell(tester);
    final undoBefore = c.canUndo;
    showTitleBlockDialog(ctxOf(tester), c);
    await settle(tester);
    await enter(tester, 'responsible', 'Ana Souza');
    await enter(tester, 'council', 'CAU');
    await enter(tester, 'registration', 'A12345-6');
    await enter(tester, 'record', 'SI1234567');
    await enter(tester, 'car', 'MG-3170107-XYZ');
    await enter(tester, 'issued', '02/11/2026');
    await enter(tester, 'company', 'Irriga Projetos');
    expect(find.text(c.t('prd.tb.recordNo', {'r': 'RRT'})), findsOneWidget, reason: 'the record named after the council');
    await tester.tap(find.byKey(const Key('tb_rev_add')));
    await settle(tester, 2);
    await tester.tap(find.byKey(const Key('tb_ok')));
    await settle(tester);
    final tb = c.project.meta.titleBlock;
    expect((tb.responsible, tb.council, tb.registration, tb.responsibilityRecord, tb.car, tb.company), ('Ana Souza', 'CAU', 'A12345-6', 'SI1234567', 'MG-3170107-XYZ', 'Irriga Projetos'));
    expect(tb.issueDate, '2026-11-02');
    expect(tb.revisions.single.revision, '0');
    expect(c.canUndo, isTrue);
    c.undo();
    expect(c.project.meta.titleBlock.responsible, '', reason: 'the whole dialog was one step');
    expect(c.canUndo, undoBefore);
    c.redo();
    // Cancel puts back what was typed
    showTitleBlockDialog(ctxOf(tester), c);
    await settle(tester);
    await enter(tester, 'responsible', 'Somebody else');
    await tester.tap(find.byKey(const Key('tb_cancel')));
    await settle(tester);
    expect(c.project.meta.titleBlock.responsible, 'Ana Souza');
    // the defaults: saved here, filled in a new project
    showTitleBlockDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.byKey(const Key('tb_defaults_fill')), findsNothing, reason: 'nothing saved yet');
    await tester.tap(find.byKey(const Key('tb_defaults_save')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('tb_ok')));
    await settle(tester);
    expect(titleBlockDefaults()!.responsible, 'Ana Souza');
    expect(titleBlockDefaults()!.car, '', reason: 'only the professional\'s own part');
    c.newProject();
    await settle(tester);
    showTitleBlockDialog(ctxOf(tester), c);
    await settle(tester);
    await tester.tap(find.byKey(const Key('tb_defaults_fill')));
    await settle(tester, 2);
    await tester.tap(find.byKey(const Key('tb_ok')));
    await settle(tester);
    expect((c.project.meta.titleBlock.responsible, c.project.meta.titleBlock.company), ('Ana Souza', 'Irriga Projetos'));
  });

  testWidgets('the georeference names its datum; the plot dialog offers the grid and the terrain sheets', (tester) async {
    final c = await pumpShell(tester);
    c.project.meta.georef = GeoReference.fromLatLonOrigin(-19.75, -47.93);
    final result = showGeoreferenceDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.textContaining('SIRGAS 2000 / UTM 23S'), findsWidgets, reason: 'the datum of the site');
    await tester.ensureVisible(find.byKey(const Key('geo_datum')));
    await settle(tester, 1);
    await tester.tap(find.byKey(const Key('geo_datum')));
    await settle(tester, 2);
    await tester.tap(find.text('WGS84').last);
    await settle(tester, 2);
    await tester.tap(find.byKey(const Key('geo_ok')));
    await settle(tester);
    expect(await result, isTrue);
    expect(c.project.meta.georef!.datum, GeodeticDatum.wgs84);
    expect(c.project.meta.georef!.crsName, 'WGS84 / UTM 23S');
    // the plot dialog
    final plot = showPlotDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.byKey(const Key('plot_grid')), findsOneWidget);
    expect(find.byKey(const Key('plot_theme_slope')), findsOneWidget);
    await tester.tap(find.byKey(const Key('plot_grid')));
    await settle(tester, 2);
    await tester.tap(find.text(c.t('prd.plot.grid.both')).last);
    await settle(tester, 2);
    final slope = find.byKey(const Key('plot_theme_slope'));
    await tester.ensureVisible(slope);
    await tester.tap(slope);
    await settle(tester, 2);
    await tester.tap(find.byKey(const Key('plot_ok')));
    await settle(tester);
    final o = (await plot)!;
    expect(o.grid, SheetGrid.both);
    expect(o.themes, [SheetTheme.slope], reason: 'the orchard has contours');
  });

  testWidgets('the document package dialog makes the PDF of the package chosen', (tester) async {
    final c = await pumpShell(tester);
    final saved = documentPackageSink;
    final got = <String, Uint8List>{};
    documentPackageSink = (c, name, data) async => got[name] = data;
    addTearDown(() => documentPackageSink = saved);
    showDocumentPackageDialog(ctxOf(tester), c, profile: DocProfile.memorial);
    await settle(tester);
    expect(find.byKey(const Key('pkg_section_prd.identification')), findsOneWidget);
    expect(find.text(c.t('prd.pkg.needsResults')), findsWidgets, reason: 'no design yet: the hydraulic sections wait for it');
    await tester.tap(find.byKey(const Key('pkg_export')));
    // the fonts of the PDF may load from the assets: real time passes
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && got.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await settle(tester);
    expect(got.keys.single, endsWith('.pdf'));
    expect(latin1.decode(got.values.single.sublist(0, 5)), '%PDF-');
    expect(find.byKey(const Key('pkg_export')), findsNothing, reason: 'the dialog closed');
  });

  testWidgets('the assistant: title block, datum, document packages, grid and terrain sheets', (tester) async {
    LocalProjectStore().clearAll();
    removePref(titleBlockDefaultsPref);
    final c = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
    await c.setLanguage('en', persist: false);
    loadExampleAction(c);
    final host = _Host()..files['logo.png'] = _png(300, 100);
    final box = AgentToolbox(c, host: host);
    AgentTool op(String name) => box.operations.firstWhere((o) => o.name == name);
    final files = <String, Object>{};
    final sink = engFileSink;
    engFileSink = (c, name, mime, data) async => files[name] = data;
    addTearDown(() => engFileSink = sink);
    await tester.runAsync(() async {
      expect((await op('get_title_block').run({})).text, contains('plain title block'));
      final set = op('set_title_block');
      expect(set.effectOf(const {}), ToolEffect.write);
      final out = await set.run({
        'responsible': 'Ana Souza',
        'council': 'CREA',
        'registration': 'MG 1412345678',
        'record': 'MG2026',
        'stage': 'basic',
        'municipality': 'Uberaba/MG',
        'add_revision': {'description': 'First issue'},
        'logo_attachment': 'logo.png',
        'save_as_defaults': true,
      });
      expect(out.text, contains('professional title block'));
      final tb = c.project.meta.titleBlock;
      expect((tb.responsible, tb.recordName, tb.stage, tb.revisions.single.revision), ('Ana Souza', 'ART', ProjectStage.basic, '0'));
      expect(tb.logoMime, 'image/png');
      expect(titleBlockDefaults()!.responsible, 'Ana Souza');
      expect(c.canUndo, isTrue);
      await expectLater(set.run({'issue_date': 'tomorrow'}), throwsA(isA<ToolInputError>()));
      await expectLater(set.run({'logo_attachment': 'missing.png'}), throwsA(isA<ToolInputError>()));
      // the datum
      await expectLater(op('set_datum').run({'datum': 'wgs84'}), throwsA(isA<ToolInputError>()), reason: 'no georeference yet');
      c.project.meta.georef = GeoReference.fromLatLonOrigin(-19.75, -47.93);
      expect((await op('set_datum').run({'datum': 'wgs84'})).text, contains('WGS84 / UTM 23S'));
      expect(c.project.meta.georef!.datum, GeodeticDatum.wgs84);
      expect((await op('set_datum').run({'datum': 'auto'})).text, contains('SIRGAS 2000'));
      expect(c.project.meta.georef!.datum, isNull);
      // the packages
      final list = (await op('list_document_packages').run({})).text;
      expect(list, allOf(contains('proposal'), contains('prd.identification'), contains('needs the design results')));
      final export = op('export_document_package');
      expect(export.mustConfirm(const {'profile': 'memorial'}), isTrue, reason: 'a download is always confirmed');
      final done = await export.run({'profile': 'permit', 'recipient': 'IGAM', 'base_map': false});
      expect(done.text, startsWith('Exported '));
      expect(files.keys.single, endsWith('.pdf'));
      await expectLater(export.run({'profile': 'memorial', 'sections': ['nope']}), throwsA(isA<ToolInputError>()));
      // the sheets: grid and the slope sheet
      files.clear();
      final sheets = await box.operations.firstWhere((o) => o.name == 'export_sheet_pdf').run({'grid': 'both', 'themes': ['slope'], 'base_map': false});
      expect(sheets.isError, isFalse, reason: sheets.text);
      expect(files, hasLength(1));
    });
  });

  final dialogs = <String, Future<void> Function(BuildContext, ProjectController)>{
    'title block': showTitleBlockDialog,
    'document package': (ctx, c) => showDocumentPackageDialog(ctx, c),
    'georeference': (ctx, c) => showGeoreferenceDialog(ctx, c),
  };
  for (final (name, size, lang, scale) in const [
    ('phone', Size(360, 640), 'pt', 1.0),
    ('phone sideways', Size(844, 390), 'pt', 1.0),
    ('right to left', Size(360, 640), 'ar', 1.0),
    ('text twice as big', Size(1280, 800), 'pt', 2.0),
  ]) {
    testWidgets('the deliverables dialogs lay out: $name', (tester) async {
      final c = await pumpShell(tester, size: size, lang: lang, textScale: scale);
      c.project.meta.georef = GeoReference.fromLatLonOrigin(-19.75, -47.93);
      c.project.meta.titleBlock
        ..responsible = 'Ana Souza'
        ..logo = _png(120, 60)
        ..logoMime = 'image/png'
        ..revisions.add(TitleRevision(revision: 'A', date: '2026-11-02', description: 'Emissão'));
      expect(tester.takeException(), isNull);
      for (final e in dialogs.entries) {
        e.value(ctxOf(tester), c);
        await settle(tester);
        expect(tester.takeException(), isNull, reason: '${e.key} at $name');
        expect(find.byType(Dialog), findsWidgets, reason: '${e.key} opened');
        Navigator.of(tester.element(find.byType(Dialog).last)).pop();
        await settle(tester);
        expect(tester.takeException(), isNull, reason: '${e.key} closing at $name');
      }
    });
  }
}
