import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/dialogs/dialogs.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/main.dart';

/// The system flows dialog: every zone together, one at a time, the
/// automatic grouping (with a zone too large for the flow limit) and the
/// durations taken from the irrigation programme; one undo step.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<ProjectController> pumpShell(WidgetTester tester) async {
    TutorialController.markDone();
    setPref('lang', 'en');
    LocalProjectStore().clearAll();
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false));
    await settle(tester);
    final dynamic shell = tester.state(find.byType(AppShell));
    final ProjectController c = shell.c as ProjectController;
    c.autosaveEnabled = false;
    await tester.runAsync(() => c.runDesign());
    await settle(tester);
    return c;
  }

  Future<void> open(WidgetTester tester, ProjectController c) async {
    showManagementDialog(tester.element(find.byType(AppShell)), c);
    await settle(tester);
  }

  Future<void> ok(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'OK').last);
    // the commit waits for the focus change (a microtask)
    await settle(tester);
  }

  testWidgets('all together, one at a time, automatic flows and programme durations', (tester) async {
    final c = await pumpShell(tester);
    final t = c.t;
    final valves = c.project.entities.where((e) => e is ControlValveEntity || e is PivotEntity).map((e) => e.id).toList();
    expect(valves.length, greaterThan(1));
    final undoBefore = c.historyEntries.length;

    // every zone together
    await open(tester, c);
    await tester.tap(find.text(t('dlg.allTogether')));
    await settle(tester, 2);
    await ok(tester);
    expect(c.project.systemFlows.single.valveIds, valves.toSet());
    expect(c.results, isNull, reason: 'the flows changed: the results were computed with the old ones');
    expect(c.historyEntries.length, undoBefore + 1);
    expect(c.historyEntries.last.label, 'hist.flows');

    // one at a time: a flow per zone, an hour apart
    await open(tester, c);
    await tester.tap(find.text(t('dlg.oneAtATime')));
    await settle(tester, 2);
    await ok(tester);
    final flows = c.project.systemFlows;
    expect(flows.length, valves.length);
    for (var i = 0; i < flows.length; i++) {
      expect(flows[i].valveIds, {valves[i]});
      expect(flows[i].startHour, (flows.first.startHour + i) % 24);
    }

    // automatic grouping under a flow limit smaller than one zone
    await open(tester, c);
    await tester.tap(find.byKey(const Key('mgmt_auto')));
    await settle(tester, 2);
    expect(find.byKey(const Key('mgmt_auto_panel')), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byKey(const Key('mgmt_auto_q')), matching: find.byType(TextField)), '1');
    await tester.enterText(find.descendant(of: find.byKey(const Key('mgmt_auto_n')), matching: find.byType(TextField)), '1');
    await tester.tap(find.byKey(const Key('mgmt_auto_run')));
    await settle(tester, 2);
    expect(find.textContaining(t('mgmt.autoOversized', {'z': ''}).trim()), findsOneWidget);
    await ok(tester);
    expect(c.project.systemFlows.length, valves.length, reason: 'at most one zone per flow');

    // the programme gives each flow the hours its areas need
    await tester.runAsync(() => c.runDesign());
    await settle(tester);
    final before = [for (final f in c.project.systemFlows) f.durationHours];
    await open(tester, c);
    await tester.tap(find.text(t('mgmt.schedule')));
    await settle(tester, 2);
    final apply = find.widgetWithText(FilledButton, t('mgmt.apply'));
    expect(tester.widget<FilledButton>(apply).onPressed, isNotNull, reason: 'the example has irrigated areas');
    await tester.tap(apply);
    await settle(tester, 2);
    await ok(tester);
    final after = [for (final f in c.project.systemFlows) f.durationHours];
    expect(after.every((h) => h > 0), isTrue);
    expect(after, isNot(before));
    // undo takes the dialog session back at once
    c.undo();
    await settle(tester);
    expect([for (final f in c.project.systemFlows) f.durationHours], before);
  });
}
