import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/canvas/cad_canvas.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/state/workspace.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/main.dart';

void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> pumpApp(WidgetTester tester, {bool autoTutorial = true}) async {
    LocalProjectStore().clearAll();
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(IrrigationCadApp(autoTutorial: autoTutorial));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('app shell renders menu, palette and canvas', (tester) async {
    TutorialController.markDone();
    setPref('lang', 'pt');
    await pumpApp(tester, autoTutorial: false);
    expect(find.text('OpenCADIrrigation'), findsWidgets);
    expect(find.text('Arquivo'), findsOneWidget);
    expect(find.text('Projeto'), findsOneWidget);
  });

  testWidgets('first run offers the tutorial and skip remembers it', (tester) async {
    TutorialController.reset();
    setPref('lang', 'pt');
    await pumpApp(tester);
    expect(find.text('Bem-vindo ao OpenCADIrrigation'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tut_skip')));
    await settle(tester);
    expect(find.text('Bem-vindo ao OpenCADIrrigation'), findsNothing);
    expect(TutorialController.isDone, isTrue);
  });

  testWidgets('tutorial walks through all steps with next, back, demo and skip', (tester) async {
    TutorialController.reset();
    setPref('lang', 'pt');
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('tut_start')));
    await settle(tester);
    final shell = tester.state(find.byType(AppShell)) as dynamic;
    shell.tutorial.setAutoAdvance(false);
    await settle(tester);
    final steps = buildTutorialSteps('pt');
    expect(steps.length, greaterThan(45));
    expect(steps.where((s) => s.interactive).length, greaterThan(35));
    expect(steps.where((s) => s.interactive).every((s) => s.demo != null), isTrue, reason: 'every interactive step has a demo');
    expect(steps.map((s) => s.id).toSet().length, steps.length, reason: 'unique ids');
    expect(find.text(steps.first.title), findsOneWidget);
    expect(find.textContaining('Passo 1 de ${steps.length}'), findsOneWidget);
    expect(find.textContaining('Navegação'), findsOneWidget);
    // next twice, back once
    await tester.tap(find.byKey(const Key('tut_next')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('tut_next')));
    await settle(tester);
    expect(find.text(steps[2].title), findsOneWidget);
    await tester.tap(find.byKey(const Key('tut_prev')));
    await settle(tester);
    expect(find.text(steps[1].title), findsOneWidget);
    // the zoom step has a demo that changes the camera and marks it done
    await tester.tap(find.byKey(const Key('tut_demo')));
    await settle(tester);
    expect(find.text('Feito!'), findsOneWidget);
    // walk to the end
    while (find.byKey(const Key('tut_next')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('tut_next')));
      await settle(tester);
    }
    expect(TutorialController.isDone, isTrue);
  });

  testWidgets('tutorial moves on by itself after a step is done', (tester) async {
    TutorialController.reset();
    setPref('lang', 'pt');
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('tut_start')));
    await settle(tester);
    final steps = buildTutorialSteps('pt');
    await tester.tap(find.byKey(const Key('tut_next')));
    await settle(tester);
    expect(find.text(steps[1].title), findsOneWidget);
    await tester.tap(find.byKey(const Key('tut_demo')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Feito! Avançando…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1400));
    await settle(tester);
    expect(find.text(steps[2].title), findsOneWidget);
    // the toggle switches auto-advance off
    await tester.tap(find.byKey(const Key('tut_auto')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('tut_demo')));
    await tester.pump(const Duration(milliseconds: 2200));
    await settle(tester);
    expect(find.text(steps[2].title), findsOneWidget);
    expect(find.text('Feito!'), findsOneWidget);
  });

  testWidgets('every interactive tutorial step is completed by its demo', (tester) async {
    TutorialController.markDone();
    setPref('lang', 'pt');
    await pumpApp(tester, autoTutorial: false);
    final shell = tester.state(find.byType(AppShell)) as dynamic;
    final ProjectController c = shell.c as ProjectController;
    c.autosaveEnabled = false;
    c.designRunner = InThreadDesignRunner();
    final steps = buildTutorialSteps('pt');
    final failed = <String>[];
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      if (!step.interactive || step.id == 'save') continue;
      // fresh state for every step
      loadExampleAction(c);
      c.clearResults();
      c.select(const []);
      c.feedEnvelope.clear();
      c.profilePath = null;
      c.overlay = OverlayMode.velocity;
      shell.openReports(false);
      shell.showLayersTab(false);
      shell.startTutorial(startAt: i);
      shell.tutorial.setAutoAdvance(false);
      await settle(tester);
      expect(find.text(step.title), findsAtLeastNWidgets(1), reason: step.id);
      expect(find.textContaining('Feito!'), findsNothing, reason: '${step.id} must not be done before the action');
      await tester.tap(find.byKey(const Key('tut_demo')));
      await settle(tester);
      for (var k = 0; k < 400 && c.busy; k++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      await settle(tester);
      if (find.textContaining('Feito!').evaluate().isEmpty) failed.add(step.id);
      shell.tutorial.skip();
      await settle(tester);
    }
    expect(failed, isEmpty, reason: 'steps whose demo did not complete them');
  });

  testWidgets('tutorial can be skipped from the card and reopened from Help', (tester) async {
    TutorialController.reset();
    setPref('lang', 'pt');
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('tut_start')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('tut_skip_all')));
    await settle(tester);
    expect(find.byKey(const Key('tut_next')), findsNothing);
    expect(TutorialController.isDone, isTrue);
    await tester.tap(find.text('Ajuda'));
    await settle(tester);
    await tester.tap(find.text('Tutorial interativo'));
    await settle(tester);
    expect(find.byKey(const Key('tut_next')), findsOneWidget);
  });

  testWidgets('language switch translates the menus into English and Spanish', (tester) async {
    TutorialController.markDone();
    setPref('lang', 'pt');
    await pumpApp(tester, autoTutorial: false);
    final shell = tester.state(find.byType(AppShell)) as dynamic;
    final ProjectController c = shell.c as ProjectController;
    expect(find.text('Arquivo'), findsOneWidget);
    c.setLanguage('en');
    await settle(tester);
    expect(find.text('File'), findsOneWidget);
    expect(find.text('Design'), findsOneWidget);
    c.setLanguage('es');
    await settle(tester);
    expect(find.text('Archivo'), findsOneWidget);
    expect(find.text('Diseño'), findsOneWidget);
    expect(getPref('lang'), 'es');
    c.setLanguage('pt');
    await settle(tester);
    expect(find.text('Arquivo'), findsOneWidget);
  });

  tabsAndShortcutsTests();

  test('example project designs end to end through the controller', () async {
    setPref('lang', 'pt');
    final c = ProjectController();
    loadExampleAction(c);
    expect(c.project.entities.whereType<ControlValveEntity>().length, 2);
    await c.runDesign();
    expect(c.results, isNotNull);
    expect(c.results!.zones.length, 2);
    expect(c.results!.systemFlows.length, 2);
    for (final z in c.results!.zones.values) {
      expect(z.converged, isTrue);
      expect(z.withinWindow, isTrue, reason: '${z.zoneName}: ${z.warnings}');
    }
    for (final f in c.results!.systemFlows) {
      expect(f.converged, isTrue);
      expect(f.maxDeficit, lessThan(0.05));
    }
    expect(c.results!.bom, isNotEmpty);
    final json = c.saveJson();
    c.loadJson(json);
    expect(c.project.entities.length, greaterThan(20));
    final dxf = c.exportDxf();
    expect(dxf, contains('ENTITIES'));
    final n = c.importDxf(dxf);
    expect(n, greaterThan(0));
    c.undo();
  });
}

// ---------------------------------------------------------------- tabs, clipboard, shortcuts

Future<void> _pressCtrl(WidgetTester tester, LogicalKeyboardKey key, {bool alt = false, String? character}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (alt) await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(key, character: character);
  if (alt) await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump(const Duration(milliseconds: 50));
}

void tabsAndShortcutsTests() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<dynamic> pumpShell(WidgetTester tester) async {
    TutorialController.markDone();
    setPref('lang', 'pt');
    // in-memory system clipboard so copy/paste exercises the platform path
    String? clip;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clip = (call.arguments as Map)['text'] as String?;
      if (call.method == 'Clipboard.getData') return clip == null ? null : {'text': clip};
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    LocalProjectStore().clearAll();
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false));
    await settle(tester);
    return tester.state(find.byType(AppShell)) as dynamic;
  }

  testWidgets('command line: typing L + Enter activates the line tool, Esc clears', (tester) async {
    final shell = await pumpShell(tester);
    final ProjectController c = shell.c as ProjectController;
    await tester.tap(find.byType(CadCanvas));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP, character: 'p');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL, character: 'l');
    await tester.pump();
    expect(c.command, 'PL');
    expect(find.byKey(const Key('command_line')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(c.command, '');
    expect(c.activeTool, ToolId.polyline);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(c.activeTool, ToolId.select);
    // Enter while selecting repeats the last drawing tool
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(c.activeTool, ToolId.polyline);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    // unknown alias is reported, buffer cleared by Esc
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ, character: 'q');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(c.command, '');
    // ZE zooms all; F7 toggles the grid display; Home zooms all
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ, character: 'z');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE, character: 'e');
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(c.command, '');
    final grid = c.showGrid;
    await tester.sendKeyEvent(LogicalKeyboardKey.f7);
    await tester.pump();
    expect(c.showGrid, !grid);
  });

  testWidgets('tabs: Ctrl+Alt+N opens a tab, copy/paste moves entities across, close returns', (tester) async {
    final shell = await pumpShell(tester);
    final Workspace ws = shell.ws as Workspace;
    final ProjectController a = ws.current;
    expect(find.byKey(const Key('tab_0')), findsOneWidget);
    expect(find.byKey(const Key('tab_1')), findsNothing);
    await tester.tap(find.byType(CadCanvas));
    await tester.pump();
    a.selectAll();
    final n = a.selection.length;
    expect(n, greaterThan(20));
    await _pressCtrl(tester, LogicalKeyboardKey.keyC, character: 'c');
    expect(ws.clipboard, isNotNull);
    expect(ws.clipboard!.count, n);
    await _pressCtrl(tester, LogicalKeyboardKey.keyN, alt: true, character: 'n');
    await settle(tester);
    expect(ws.tabs.length, 2);
    expect(ws.active, 1);
    expect(find.byKey(const Key('tab_1')), findsOneWidget);
    final ProjectController b = ws.current;
    expect(b.project.entities, isEmpty);
    await tester.tap(find.byType(CadCanvas));
    await tester.pump();
    await _pressCtrl(tester, LogicalKeyboardKey.keyV, character: 'v');
    await settle(tester);
    expect(b.project.entities.length, n);
    expect(b.project.entities.map((e) => e.id).toSet().length, n); // ids are per project
    // switch back with Ctrl+Alt+Left and with a click on the tab
    await _pressCtrl(tester, LogicalKeyboardKey.arrowLeft, alt: true);
    await settle(tester);
    expect(ws.active, 0);
    await tester.tap(find.byKey(const Key('tab_1')));
    await settle(tester);
    expect(ws.active, 1);
    // closing the dirty tab asks for confirmation
    await tester.tap(find.byKey(const Key('tab_close_1')));
    await settle(tester);
    expect(find.text('Fechar aba'), findsWidgets);
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect(ws.tabs.length, 1);
    expect(identical(ws.current, a), isTrue);
    // Edit menu exposes copy / paste
    await tester.tap(find.text('Editar'));
    await settle(tester);
    expect(find.text('Colar'), findsOneWidget);
    expect(find.text('Copiar'), findsOneWidget);
  });

  testWidgets('F2 toggles the reports panel and Help lists the shortcuts', (tester) async {
    final shell = await pumpShell(tester);
    final ProjectController c = shell.c as ProjectController;
    final before = c.showReports;
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await settle(tester);
    expect(c.showReports, !before);
    await tester.tap(find.text('Ajuda'));
    await settle(tester);
    await tester.tap(find.text('Atalhos de teclado…'));
    await settle(tester);
    expect(find.text('Atalhos de teclado'), findsOneWidget);
    expect(find.text('PL · PLINE'), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await settle(tester);
    expect(find.text('PL · PLINE'), findsNothing);
  });
}
