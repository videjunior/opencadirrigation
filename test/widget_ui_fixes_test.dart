import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/io/app_keys.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/keys/hotkeys.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_job.dart';
import 'package:opencadirrigation/app/state/workspace.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/main.dart';

/// Defects of the interface outside the drawing (sweep of 2026-11-01, UI-*):
/// each test fails on the code before its fix.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  /// The app as a visitor opens it: an empty project, nothing asked.
  Future<dynamic> pumpFresh(WidgetTester tester, {Size size = const Size(1600, 1000)}) async {
    TutorialController.markDone();
    setPref('lang', 'pt');
    LocalProjectStore().clearAll();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false, askAi: false));
    await settle(tester);
    final shell = tester.state(find.byType(AppShell)) as dynamic;
    (shell.c as ProjectController).autosaveEnabled = false;
    return shell;
  }

  Future<void> openHelp(WidgetTester tester, String item) async {
    await tester.tap(find.text('Ajuda'));
    await settle(tester);
    await tester.tap(find.text(item).last);
    await settle(tester);
  }

  group('UI-01 the tutorial works on its own orchard', () {
    testWidgets('Help → Tutorial in a freshly opened app loads the orchard the first step talks about', (tester) async {
      final shell = await pumpFresh(tester);
      final ws = shell.ws as Workspace;
      expect(ws.current.project.entities, isEmpty, reason: 'the app opens empty');
      await openHelp(tester, 'Tutorial interativo');
      expect(find.byKey(const Key('tut_next')), findsOneWidget);
      // the blank tab of the fresh start is used: no tab left over
      expect(ws.tabs, hasLength(1));
      final c = ws.current;
      expect(c.project.entities.whereType<ControlValveEntity>(), isNotEmpty, reason: 'the orchard is there');
      expect(c.project.entities.whereType<SpraylineEntity>(), isNotEmpty);
      // the first step says the truth
      expect(find.textContaining('numa aba só dele'), findsOneWidget);
      // and the steps that select something find it: the valve demo completes
      final steps = buildTutorialSteps('pt');
      final valve = steps.indexWhere((s) => s.id == 'properties');
      expect(valve, greaterThan(0));
      shell.tutorial.setAutoAdvance(false);
      shell.tutorial.goTo(valve);
      await settle(tester);
      await tester.tap(find.byKey(const Key('tut_demo')));
      await settle(tester);
      expect(find.textContaining('Feito!'), findsOneWidget, reason: 'the demo found a valve to rename');
    });

    testWidgets("the user's own project stays as it was: the demos run in a new tab", (tester) async {
      final shell = await pumpFresh(tester);
      final ws = shell.ws as Workspace;
      final mine = ws.current;
      mine.addEntity(LineEntity(id: mine.project.newId(), a: Pt.zero, b: const Pt(25, 0)));
      final before = mine.saveJson(markClean: false);
      await openHelp(tester, 'Tutorial interativo');
      expect(ws.tabs, hasLength(2));
      expect(identical(ws.current, mine), isFalse, reason: 'the tutorial tab is selected');
      shell.tutorial.setAutoAdvance(false);
      // the georeference, terrain and rename demos change only the tutorial's tab
      for (final id in ['georef', 'properties']) {
        shell.tutorial.goTo(buildTutorialSteps('pt').indexWhere((s) => s.id == id));
        await settle(tester);
        await tester.tap(find.byKey(const Key('tut_demo')));
        await settle(tester);
      }
      expect(ws.current.project.meta.georef, isNotNull);
      expect(mine.project.meta.georef, isNull);
      expect(mine.saveJson(markClean: false), before);
    });
  });

  group('UI-03 the application keys take the value being typed', () {
    Future<(ProjectController, SpotHeightEntity)> typeElevation(WidgetTester tester, dynamic shell, String text) async {
      final ProjectController c = shell.c;
      loadExampleAction(c);
      c.designRunner = InThreadDesignRunner();
      final sp = SpotHeightEntity(id: c.project.newId(), position: const Pt(5, 5), elevation: 100);
      c.addEntity(sp);
      c.select([sp.id]);
      await settle(tester);
      final field = find.widgetWithText(TextField, c.t('props.elevation'));
      expect(field, findsOneWidget);
      await tester.enterText(field, text);
      await tester.pump();
      expect(editableTextFocused(), isTrue);
      return (c, sp);
    }

    testWidgets('F5 while typing designs with the number just typed (it was refused as "design running")', (tester) async {
      final shell = await pumpFresh(tester);
      final (c, sp) = await typeElevation(tester, shell, '123.5');
      (shell.hotkeys as Hotkeys).handle(const HotkeyEvent('F5'));
      await settle(tester);
      for (var k = 0; k < 400 && c.busy; k++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      await settle(tester);
      expect(c.results, isNotNull, reason: 'the design ran');
      expect((c.project.entities.firstWhere((e) => e.id == sp.id) as SpotHeightEntity).elevation, 123.5);
      expect(c.lastMessage, isNot(c.t('msg.designBusy')));
    });

    testWidgets('Ctrl+S while typing saves the number just typed', (tester) async {
      final shell = await pumpFresh(tester);
      final (c, sp) = await typeElevation(tester, shell, '321');
      (shell.hotkeys as Hotkeys).handle(const HotkeyEvent('s', ctrl: true));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      final saved = c.store.load(c.project.meta.uid);
      expect(saved, isNotNull);
      final entities = ((jsonDecode(saved!) as Map<String, dynamic>)['project'] as Map<String, dynamic>? ?? jsonDecode(saved) as Map<String, dynamic>)['entities'] as List;
      expect((entities.firstWhere((e) => (e as Map)['id'] == sp.id) as Map)['z'], 321);
      expect(c.dirty, isFalse);
      // the file chooser of the desktop build
      appNavigatorKey.currentState?.pop();
      await settle(tester);
    });
  });

  group('UI-05 the phone menu has tabs, recent projects and the desktop toggles', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('mobile_menu')));
      await settle(tester);
    }

    Finder sheetList() => find.descendant(of: find.byKey(const Key('mobile_menu_sheet')), matching: find.byType(Scrollable)).first;

    testWidgets('the open tabs are listed, switched and closed; the recent projects open', (tester) async {
      final shell = await pumpFresh(tester, size: const Size(390, 844));
      final ws = shell.ws as Workspace;
      final first = ws.current;
      first.addEntity(LineEntity(id: first.project.newId(), a: Pt.zero, b: const Pt(25, 0)));
      first.project.meta.name = 'Horta';
      first.saveJson(); // kept in this browser: a recent project
      ws.addTab();
      await settle(tester);
      expect(ws.active, 1);
      await openMenu(tester);
      expect(find.byKey(const Key('mobile_tab_0')), findsOneWidget);
      expect(find.byKey(const Key('mobile_tab_1')), findsOneWidget);
      expect(find.text('Horta'), findsOneWidget);
      await tester.tap(find.byKey(const Key('mobile_tab_0')));
      await settle(tester);
      expect(ws.active, 0, reason: 'back to the first tab without a keyboard');
      await openMenu(tester);
      await tester.tap(find.byKey(const Key('mobile_tab_close_1')));
      await settle(tester);
      expect(ws.tabs, hasLength(1));
      // the recent project opens (already open: its tab is selected)
      ws.addTab();
      await settle(tester);
      await openMenu(tester);
      await tester.tap(find.byKey(const Key('mobile_menu_recent')));
      await settle(tester);
      await tester.tap(find.byKey(Key('mobile_recent_${first.project.meta.uid}')));
      await settle(tester);
      expect(identical(ws.current, first), isTrue);
    });

    testWidgets('grid snap, polar tracking, edit grips, autosave and the terrain method', (tester) async {
      final shell = await pumpFresh(tester, size: const Size(390, 844));
      final ProjectController c = shell.c;
      Future<void> tapItem(String section, String label) async {
        await openMenu(tester);
        await tester.scrollUntilVisible(find.text(section), 200, scrollable: sheetList());
        await tester.tap(find.text(section));
        await settle(tester);
        await tester.scrollUntilVisible(find.text(label), 200, scrollable: sheetList());
        await tester.ensureVisible(find.text(label));
        await settle(tester, 1);
        await tester.tap(find.text(label));
        await settle(tester);
      }

      final grid = c.snap.grid, grips = c.showGrips, autosave = c.autosaveEnabled, polar = c.snap.polarStepDeg;
      await tapItem(c.t('menu.view'), c.t('mob.gridSnap'));
      expect(c.snap.grid, !grid);
      await tapItem(c.t('menu.view'), c.t('view.grips'));
      expect(c.showGrips, !grips);
      await tapItem(c.t('menu.view'), c.t('mob.polar', {'s': polar > 0 ? '${polar.round()}°' : c.t('mob.off')}));
      expect(c.snap.polarStepDeg, isNot(polar));
      await tapItem(c.t('menu.file'), c.t('file.autosave'));
      expect(c.autosaveEnabled, !autosave);
      await tapItem(c.t('menu.design'), c.t('terrain.idw'));
      expect(c.project.params.terrainMethod.name, 'idw');
    });
  });
}
