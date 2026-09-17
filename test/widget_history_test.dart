import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/history_panel.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/main.dart';

/// Photoshop-style history: controller timeline and the History tab.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  test('controller timeline: labels, current state, jump back and forward', () {
    LocalProjectStore().clearAll();
    final c = ProjectController();
    c.autosaveEnabled = false;
    c.newProject();
    expect(c.historyEntries.length, 1);
    expect(c.historyEntries.single.label, 'hist.start');
    expect(c.historyEntries.single.current, isTrue);
    final l1 = LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(10, 0));
    c.addEntity(l1);
    c.addEntity(CircleEntity(id: c.project.newId(), center: Pt.zero, radius: 5));
    c.select([l1.id]);
    c.moveSelected(const Pt(5, 5));
    c.deleteSelected();
    var h = c.historyEntries;
    expect(h.map((e) => e.label).toList(), ['hist.start', 'hist.add|line', 'hist.add|circle', 'hist.move', 'hist.delete|1']);
    expect(h.last.current, isTrue);
    expect(c.historyIndex, 4);
    // back to the state after the two additions
    c.jumpToHistory(2);
    expect(c.historyIndex, 2);
    expect(c.project.entities.length, 2);
    expect((c.project.byId(l1.id) as LineEntity).a, Pt.zero, reason: 'move undone');
    h = c.historyEntries;
    expect(h.length, 5);
    expect(h[2].current, isTrue);
    expect(h[3].future, isTrue);
    expect(h[3].label, 'hist.move');
    expect(h[4].label, 'hist.delete|1');
    // forward again
    c.jumpToHistory(4);
    expect(c.project.entities.length, 1);
    expect(c.historyEntries.where((e) => e.future), isEmpty);
    // a new edit after going back discards the future
    c.jumpToHistory(1);
    c.addEntity(TextEntity(id: c.project.newId(), position: Pt.zero, text: 'x', height: 1));
    h = c.historyEntries;
    expect(h.map((e) => e.label).toList(), ['hist.start', 'hist.add|line', 'hist.add|text']);
    expect(c.canRedo, isFalse);
    // labels resolve to readable text
    expect(HistoryPanel.labelText(c, 'hist.add|line'), isNot(contains('|')));
    expect(HistoryPanel.labelText(c, 'hist.delete|3'), contains('3'));
  });

  testWidgets('History tab lists steps and clicking one restores the drawing', (tester) async {
    TutorialController.markDone();
    setPref('lang', 'pt');
    LocalProjectStore().clearAll();
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false));
    await settle(tester);
    final shell = tester.state(find.byType(AppShell)) as dynamic;
    final ProjectController c = shell.c as ProjectController;
    c.autosaveEnabled = false;
    c.newProject();
    c.addEntity(LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(10, 0)));
    c.addEntity(CircleEntity(id: c.project.newId(), center: Pt.zero, radius: 5));
    await settle(tester, 2);
    await tester.tap(find.byKey(const Key('side_tab_history')));
    await settle(tester, 2);
    expect(find.byKey(const Key('hist_list')), findsOneWidget);
    expect(find.text('Estado inicial'), findsOneWidget);
    expect(find.text('Adicionar Círculo'), findsOneWidget);
    expect(shell.sideTab, 2);
    // click the state after the first addition
    await tester.tap(find.byKey(const Key('hist_row_1')));
    await settle(tester, 2);
    expect(c.project.entities.length, 1);
    expect(c.historyIndex, 1);
    // the undone step is still listed (redo) and the redo button works
    expect(find.byKey(const Key('hist_row_2')), findsOneWidget);
    await tester.tap(find.byKey(const Key('hist_redo')));
    await settle(tester, 2);
    expect(c.project.entities.length, 2);
    // tutorial step for the history tab is detected
    final steps = buildTutorialSteps('pt');
    final hist = steps.firstWhere((s) => s.id == 'history');
    expect(hist.interactive, isTrue);
  });

  testWidgets('phone layout opens the history in the properties sheet', (tester) async {
    TutorialController.markDone();
    setPref('lang', 'pt');
    LocalProjectStore().clearAll();
    tester.view.physicalSize = const Size(420, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false));
    await settle(tester);
    final shell = tester.state(find.byType(AppShell)) as dynamic;
    final ProjectController c = shell.c as ProjectController;
    c.autosaveEnabled = false;
    c.newProject();
    c.addEntity(LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(10, 0)));
    await tester.pump(const Duration(seconds: 4));
    await settle(tester, 2);
    await tester.tap(find.byKey(const Key('mobile_history')));
    await settle(tester);
    expect(find.byKey(const Key('mobile_props_sheet')), findsOneWidget);
    expect(find.byKey(const Key('hist_list')), findsOneWidget);
    await tester.tap(find.byKey(const Key('hist_row_0')));
    await settle(tester, 2);
    expect(c.project.entities, isEmpty);
  });
}
