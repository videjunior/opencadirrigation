import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/canvas/cad_canvas.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/widgets/hgl_chart.dart';
import 'package:opencadirrigation/app/widgets/history_panel.dart';
import 'package:opencadirrigation/app/widgets/reports_panel.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/main.dart';

/// Panels (reports, properties, layers), menu bar toggles, status bar, tabs
/// and keyboard shortcuts.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  late dynamic shell;
  Future<ProjectController> pumpShell(WidgetTester tester, {bool example = true, bool design = false}) async {
    TutorialController.markDone();
    setPref('lang', 'pt');
    LocalProjectStore().clearAll();
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false));
    await settle(tester);
    shell = tester.state(find.byType(AppShell)) as dynamic;
    final ProjectController c = shell.c as ProjectController;
    c.autosaveEnabled = false;
    c.snap.enabled = false;
    if (!example) c.newProject();
    if (design) await tester.runAsync(() => c.runDesign());
    await settle(tester);
    return c;
  }

  Future<void> openMenu(WidgetTester tester, String top, String item) async {
    await tester.tap(find.text(top).first);
    await settle(tester, 2);
    await tester.tap(find.textContaining(item).last);
    await settle(tester, 3);
  }

  Finder fieldWithLabel(String prefix) => find.byWidgetPredicate((w) => w is TextField && (w.decoration?.labelText ?? '').startsWith(prefix));

  Future<void> enterPrefixed(WidgetTester tester, String prefix, String value) async {
    final f = fieldWithLabel(prefix).first;
    expect(f, findsOneWidget, reason: 'field $prefix');
    await tester.tap(f);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(f, value);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 2);
  }

  Future<void> select(WidgetTester tester, ProjectController c, Entity e) async {
    c.select([e.id]);
    c.refresh();
    await settle(tester, 2);
  }

  testWidgets('design run shows a progress overlay and hides it when done', (tester) async {
    final c = await pumpShell(tester);
    c.designRunner = InThreadDesignRunner();
    final overlay = find.byKey(const Key('design_progress'));
    expect(overlay, findsNothing);
    final run = c.runDesign();
    await tester.pump();
    expect(c.busy, isTrue);
    expect(overlay, findsOneWidget);
    expect(find.text('Calculando o projeto…'), findsOneWidget);
    // the play button and the design menu are disabled while running
    expect(tester.widget<IconButton>(find.byKey(TutorialTargets.runButton)).onPressed, isNull);
    // the card does not block the workspace: the side tabs still respond…
    await tester.tap(find.byKey(const Key('side_tab_history')));
    await tester.pump();
    expect(find.byType(HistoryPanel), findsOneWidget);
    // …but edits are refused with a message until the run ends
    final layers = c.project.layers.length;
    expect(c.addLayer('Temporária'), isFalse);
    expect(c.project.layers.length, layers);
    expect(c.lastMessage, c.t('msg.designBusy'));
    expect(c.mutate(() => 1), isNull);
    final undoDepth = c.historyTouched;
    c.undo();
    expect(c.historyTouched, undoDepth);
    final stages = <DesignStage>{};
    c.addListener(() {
      final p = c.progress;
      if (p != null) stages.add(p.stage);
    });
    var sawZoneLabel = false;
    var sawThreadHint = false;
    // 10 ms per pump: one frame plus the zero-delay timer, i.e. at most one design step per pump
    for (var i = 0; i < 400 && c.busy; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      final p = c.progress;
      if (p?.stage == DesignStage.zones && find.textContaining('Zona ${p!.zoneIndex} de ${p.zoneCount}').evaluate().isNotEmpty) sawZoneLabel = true;
      if (c.designMode == 'thread' && find.text('O navegador pode ficar lento enquanto o cálculo roda.').evaluate().isNotEmpty) sawThreadHint = true;
    }
    await run;
    expect(c.busy, isFalse);
    expect(c.progress, isNull);
    expect(c.results, isNotNull);
    expect(c.results!.zones.length, 2);
    expect(stages, containsAll([DesignStage.zones, DesignStage.mainline, DesignStage.flushing, DesignStage.surge, DesignStage.bom]));
    expect(sawZoneLabel, isTrue);
    expect(sawThreadHint, isTrue);
    await settle(tester);
    expect(overlay, findsNothing);
    // a second run while busy is ignored, and F5 still works afterwards
    expect(tester.widget<IconButton>(find.byKey(TutorialTargets.runButton)).onPressed, isNotNull);
    // edits work again
    expect(c.addLayer('Temporária'), isTrue);
  });

  testWidgets('design results are discarded when the project is replaced meanwhile', (tester) async {
    final c = await pumpShell(tester);
    c.designRunner = InThreadDesignRunner();
    final run = c.runDesign();
    await tester.pump();
    expect(c.busy, isTrue);
    // wait for the first step, then open another project (here: the example
    // again), which swaps the project object under the running design
    for (var i = 0; i < 100 && c.progress == null; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(c.progress, isNotNull);
    loadExampleAction(c);
    for (var i = 0; i < 400 && c.busy; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    await run;
    expect(c.busy, isFalse);
    expect(c.results, isNull);
    expect(c.lastMessage, c.t('msg.designStale'));
    await settle(tester);
    expect(find.byKey(const Key('design_progress')), findsNothing);
  });

  testWidgets('pipes report builds only the visible rows of a long table', (tester) async {
    final c = await pumpShell(tester, design: true);
    c.showReports = true;
    c.reportTab = reportTabKeys.indexOf('reports.pipes');
    c.refresh();
    await settle(tester, 2);
    final rows = c.reportTables().firstWhere((x) => x.key == 'pipes').rows.length;
    expect(rows, greaterThan(500));
    expect(find.byType(ReportTableView), findsOneWidget);
    expect(find.byKey(const ValueKey('report_row_0')), findsOneWidget);
    expect(find.byKey(ValueKey('report_row_${rows - 1}')), findsNothing);
    // far fewer widgets than rows: the list is virtualised
    expect(tester.widgetList(find.byKey(const Key('report_table_list'))).length, 1);
    expect(find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('report_row_')).evaluate().length, lessThan(60));
    // jumping down shows the last rows
    final list = tester.widget<ListView>(find.byKey(const Key('report_table_list')));
    list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
    await tester.pump();
    expect(find.byKey(ValueKey('report_row_${rows - 1}')), findsOneWidget);
    expect(find.byKey(const ValueKey('report_row_0')), findsNothing);
    // switching tabs starts a fresh table
    c.reportTab = 0;
    c.refresh();
    await settle(tester, 2);
    expect(find.textContaining('Zona A'), findsWidgets);
  });

  testWidgets('reports panel renders every tab, the HGL of a selection and closes', (tester) async {
    final c = await pumpShell(tester, design: true);
    c.showReports = true;
    c.refresh();
    await settle(tester);
    for (var i = 0; i < reportTabKeys.length; i++) {
      await tester.ensureVisible(find.byKey(Key('report_tab_$i')));
      await tester.tap(find.byKey(Key('report_tab_$i')));
      await settle(tester, 2);
      expect(c.reportTab, i);
      expect(find.text(c.t(reportTabKeys[i])), findsWidgets, reason: reportTabKeys[i]);
    }
    await tester.ensureVisible(find.byKey(const Key('report_tab_0')));
    await tester.tap(find.byKey(const Key('report_tab_0')));
    await settle(tester, 2);
    expect(find.textContaining('Zona A'), findsWidgets);
    // HGL needs a selected pipe or lateral
    final hgl = reportTabKeys.indexOf('reports.hgl');
    await tester.ensureVisible(find.byKey(Key('report_tab_$hgl')));
    await tester.tap(find.byKey(Key('report_tab_$hgl')));
    await settle(tester, 2);
    // with results the chart of a lateral is shown; a selected pipe keeps a chart
    expect(find.byType(HglChart), findsOneWidget);
    await select(tester, c, c.project.entities.whereType<PipeEntity>().first);
    expect(find.byType(HglChart), findsOneWidget);
    expect(find.text(c.t('msg.selectForHgl')), findsNothing);
    // profile tab after a profile path
    final prof = reportTabKeys.indexOf('reports.profile');
    c.setProfilePath([const Pt(0, 0), const Pt(120, 0)]);
    c.reportTab = prof;
    c.refresh();
    await settle(tester, 2);
    expect(find.textContaining(c.t('prof.slope').split(' ').first), findsWidgets);
    await tester.tap(find.byKey(const Key('reports_close')));
    await settle(tester, 2);
    expect(c.showReports, isFalse);
  });

  testWidgets('properties panel shows the fields of every entity type and edits them', (tester) async {
    final c = await pumpShell(tester);
    final valve = c.project.entities.whereType<ControlValveEntity>().first;
    await select(tester, c, valve);
    expect(find.text(c.t('tool.valve')), findsWidgets);
    await enterPrefixed(tester, c.t('props.zone'), 'Zona Z');
    expect(valve.zoneName, 'Zona Z');
    final lateral = c.project.entities.whereType<SpraylineEntity>().first;
    await select(tester, c, lateral);
    await enterPrefixed(tester, c.t('props.spacing'), '4');
    expect(lateral.spacing, closeTo(4, 1e-9));
    final pipe = c.project.entities.whereType<PipeEntity>().first;
    await select(tester, c, pipe);
    expect(find.text(c.t('props.auto')), findsOneWidget);
    final auto = pipe.computerSized;
    await tester.tap(find.byType(Switch).first);
    await settle(tester, 2);
    expect(pipe.computerSized, !auto);
    final supply = c.project.entities.whereType<WaterSupplyEntity>().first;
    await select(tester, c, supply);
    expect(find.text(c.t('props.calc')), findsOneWidget);
    final pump = c.project.entities.whereType<PumpEntity>().first;
    await select(tester, c, pump);
    expect(find.text(c.t('props.pump')), findsWidgets);
    final tape = c.project.entities.whereType<TapeEntity>().first;
    await select(tester, c, tape);
    await enterPrefixed(tester, c.t('props.inlet'), '12');
    expect(tape.inletHeadM, closeTo(12, 1e-9));
    final area = c.project.entities.whereType<AreaEntity>().first;
    await select(tester, c, area);
    expect(find.text(c.t('props.crop')), findsOneWidget);
    expect(find.text(c.t('props.waterBalance')), findsOneWidget);
    final text = c.project.entities.whereType<TextEntity>().first;
    await select(tester, c, text);
    await enterPrefixed(tester, c.t('props.text'), 'Novo texto');
    expect(text.text, 'Novo texto');
    final contour = c.project.entities.whereType<ContourEntity>().first;
    await select(tester, c, contour);
    await enterPrefixed(tester, c.t('props.elevation'), '123');
    expect(contour.elevation, closeTo(123, 1e-9));
    // drawing entities created here
    final circle = CircleEntity(id: c.project.newId(), center: const Pt(0, 0), radius: 3);
    c.addEntity(circle);
    await select(tester, c, circle);
    await enterPrefixed(tester, c.t('props.radius'), '7');
    expect(circle.radius, closeTo(7, 1e-9));
    final poly = PolylineEntity(id: c.project.newId(), points: [const Pt(0, 0), const Pt(5, 0), const Pt(5, 5)]);
    c.addEntity(poly);
    await select(tester, c, poly);
    expect(find.text(c.t('props.closed')), findsOneWidget);
    await tester.tap(find.byType(Switch).first);
    await settle(tester, 2);
    expect(poly.closed, isTrue);
    final sym = SymbolEntity(id: c.project.newId(), position: const Pt(1, 1));
    c.addEntity(sym);
    await select(tester, c, sym);
    expect(find.text(c.t('props.symbolKind')), findsWidgets);
    final hatch = HatchEntity(id: c.project.newId(), points: [const Pt(0, 0), const Pt(5, 0), const Pt(5, 5)]);
    c.addEntity(hatch);
    await select(tester, c, hatch);
    expect(find.text(c.t('props.hatchSolid')), findsOneWidget);
    final leader = LeaderEntity(id: c.project.newId(), points: [const Pt(0, 0), const Pt(3, 3)], text: 'L');
    c.addEntity(leader);
    await select(tester, c, leader);
    expect(fieldWithLabel(c.t('props.text')), findsWidgets);
    final img = ImageEntity(id: c.project.newId(), origin: const Pt(0, 0), width: 10, height: 5);
    c.addEntity(img);
    await select(tester, c, img);
    expect(find.text(c.t('props.opacity')), findsOneWidget);
    // batch editing and the panel buttons
    final laterals = c.project.entities.whereType<SpraylineEntity>().take(2).map((e) => e.id).toList();
    c.select(laterals);
    c.refresh();
    await settle(tester, 2);
    expect(find.textContaining(c.t('props.batch', {'n': '2', 'type': ''}).split('(').first.trim().toUpperCase()), findsWidgets);
    await select(tester, c, circle);
    await tester.tap(find.byTooltip(c.t('props.zoomTo')));
    await settle(tester, 2);
    final n = c.project.entities.length;
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await settle(tester, 2);
    expect(c.project.entities.length, n - 1);
    // tool defaults
    c.setTool(ToolId.symbol);
    await settle(tester, 2);
    expect(find.text(c.t('props.symbolKind')), findsWidgets);
    c.setTool(ToolId.offset);
    await settle(tester, 2);
    expect(find.textContaining(c.t('props.offsetDistance')), findsWidgets);
    c.setTool(ToolId.select);
  });

  testWidgets('layers panel: add, rename, lock, hide, current layer and delete', (tester) async {
    final c = await pumpShell(tester);
    await tester.tap(find.text(c.t('view.layers')));
    await settle(tester, 2);
    await tester.tap(find.byKey(const Key('layer_add')));
    await settle(tester, 2);
    await tester.enterText(find.byKey(const Key('layer_name')), 'MINHA');
    await tester.tap(find.text('OK').last);
    await settle(tester, 2);
    expect(c.project.findLayer('MINHA'), isNotNull);
    // rename with a double tap on the name
    await tester.tap(find.text('MINHA'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text('MINHA'));
    await settle(tester, 2);
    expect(find.byKey(const Key('layer_name')), findsOneWidget, reason: 'a double tap on the name opens the rename dialog');
    await tester.enterText(find.byKey(const Key('layer_name')), 'OUTRA');
    await tester.tap(find.text('OK').last);
    await settle(tester, 2);
    expect(c.project.findLayer('OUTRA'), isNotNull);
    expect(c.project.findLayer('MINHA'), isNull);
    c.renameLayer('OUTRA', 'MINHA');
    // lock / hide the tapes layer through the controller API used by the panel
    c.setLayerLocked(Layers.tapes, true);
    c.refresh();
    await settle(tester, 2);
    expect(c.project.isLocked(Layers.tapes), isTrue);
    final tape = c.project.entities.whereType<TapeEntity>().first;
    c.select([tape.id]);
    final before = c.project.entities.length;
    c.deleteSelected();
    expect(c.project.entities.length, before, reason: 'locked layer keeps its entities');
    c.setLayerLocked(Layers.tapes, false);
    c.project.layerNamed(Layers.tapes).visible = false;
    c.refresh();
    await settle(tester, 2);
    expect(c.visibleEntities().whereType<TapeEntity>(), isEmpty);
    c.project.layerNamed(Layers.tapes).visible = true;
    c.setCurrentLayer('MINHA');
    expect(c.project.currentLayer, 'MINHA');
    c.setLayerColor('MINHA', 0xFF00FF00);
    expect(c.project.findLayer('MINHA')!.color & 0xFFFFFF, 0x00FF00);
    c.removeLayer('MINHA');
    expect(c.project.findLayer('MINHA'), isNull);
    await settle(tester, 2);
    await tester.tap(find.text(c.t('props.title')));
    await settle(tester, 1);
  });

  testWidgets('view menu toggles, overlays, zoom, language and edit menu actions', (tester) async {
    final c = await pumpShell(tester);
    await openMenu(tester, 'Ver', '(F7)');
    expect(c.showGrid, isFalse);
    await openMenu(tester, 'Ver', 'Rótulos');
    expect(c.showLabels, isFalse);
    await openMenu(tester, 'Ver', 'Raios molhados');
    expect(c.showWettedRadii, isFalse);
    await openMenu(tester, 'Ver', 'Alças de edição');
    expect(c.showGrips, isFalse);
    await openMenu(tester, 'Ver', 'Colorir por velocidade');
    expect(c.overlay, OverlayMode.velocity);
    await openMenu(tester, 'Ver', 'Marcar pressão');
    expect(c.overlay, OverlayMode.minMax);
    final scale = c.camera.scale;
    await openMenu(tester, 'Ver', 'Aproximar');
    expect(c.camera.scale, greaterThan(scale));
    final zoomedIn = c.camera.scale;
    await openMenu(tester, 'Ver', 'Afastar');
    expect(c.camera.scale, lessThan(zoomedIn));
    c.camera.center = const Pt(1e5, 1e5);
    await openMenu(tester, 'Ver', 'Enquadrar tudo');
    expect(c.camera.visible.contains(c.project.entities.first.bounds.center), isTrue, reason: 'zoom all brings the drawing back into view');
    await tester.tap(find.text('Ver'));
    await settle(tester, 2);
    await tester.tap(find.text('Idioma'));
    await settle(tester, 2);
    await tester.tap(find.text('English'));
    await settle(tester, 3);
    expect(c.lang, 'en');
    expect(find.text('View'), findsOneWidget);
    await tester.tap(find.text('View'));
    await settle(tester, 2);
    await tester.tap(find.text('Language'));
    await settle(tester, 2);
    await tester.tap(find.text('Português'));
    await settle(tester, 3);
    expect(c.lang, 'pt');
    // edit menu
    final n = c.project.entities.length;
    c.addEntity(CircleEntity(id: c.project.newId(), center: const Pt(0, 0), radius: 1));
    await settle(tester, 1);
    await openMenu(tester, 'Editar', 'Desfazer');
    expect(c.project.entities.length, n);
    await openMenu(tester, 'Editar', 'Refazer');
    expect(c.project.entities.length, n + 1);
    await openMenu(tester, 'Editar', 'Selecionar tudo');
    expect(c.selection.length, n + 1);
    await openMenu(tester, 'Editar', 'Excluir seleção');
    expect(c.project.entities, isEmpty);
    await openMenu(tester, 'Editar', 'Desfazer');
    expect(c.project.entities.length, n + 1);
    await openMenu(tester, 'Projeto', 'Verificação do projeto');
    expect(find.byKey(const Key('check_list')), findsOneWidget);
    expect(c.eventCount('check'), 1);
    await tester.tap(find.text('Fechar'));
    await settle(tester, 2);
    await openMenu(tester, 'Relatórios', 'Mensagens');
    expect(c.showReports, isTrue);
    expect(c.reportTab, reportTabKeys.indexOf('reports.messages'));
  });

  testWidgets('status bar toggles, tab bar and keyboard shortcuts', (tester) async {
    final c = await pumpShell(tester);
    await tester.tap(find.text('Snap F3'));
    await settle(tester, 1);
    expect(c.snap.enabled, isTrue);
    await tester.tap(find.text('Grade F9'));
    await settle(tester, 1);
    expect(c.snap.grid, isTrue);
    await tester.tap(find.text('Orto F8'));
    await settle(tester, 1);
    expect(c.snap.ortho, isTrue);
    // second tab, load the example there, close it
    await tester.tap(find.byTooltip('Nova aba (Ctrl+Alt+N)'));
    await settle(tester, 2);
    expect(shell.ws.tabs.length, 2);
    await tester.tap(find.byTooltip('Fechar aba (Ctrl+Alt+W)').last);
    await settle(tester, 2);
    expect(find.byType(AlertDialog), findsNothing, reason: 'a clean new tab closes without asking');
    expect(shell.ws.tabs.length, 1);
    // keyboard: command alias, escape, F7, Home, Ctrl+A, Delete, Ctrl+Z
    await tester.tap(find.byType(CadCanvas));
    await settle(tester, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester, 1);
    expect(c.activeTool, ToolId.line);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester, 1);
    expect(c.activeTool, ToolId.select);
    final grid = c.showGrid;
    await tester.sendKeyEvent(LogicalKeyboardKey.f7);
    await settle(tester, 1);
    expect(c.showGrid, !grid);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester, 1);
    expect(c.selection.length, c.project.entities.length);
    final n = c.project.entities.length;
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await settle(tester, 1);
    expect(c.project.entities, isEmpty);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester, 1);
    expect(c.project.entities.length, n);
    c.camera.center = const Pt(1e5, 1e5);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await settle(tester, 1);
    expect(c.camera.visible.contains(c.project.entities.first.bounds.center), isTrue, reason: 'Home zooms to the drawing');
  });
}
