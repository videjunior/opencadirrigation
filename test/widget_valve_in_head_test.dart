import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/dialogs/dialogs.dart';
import 'package:opencadirrigation/app/widgets/reports_panel.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/main.dart';

/// Valve-in-head heads in the interface: the station of a mainline outlet
/// and the flows that run it in the properties panel, the stations among the
/// demands of the system flows dialog, and their report tab.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('station field, flows of the station, demands of the flows dialog and the report tab', (tester) async {
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
    c.snap.enabled = false;
    c.newProject();
    final t = c.t;
    c.mutate(() {
      c.project.entities.addAll([
        WaterSupplyEntity(id: c.project.newId(), position: Pt.zero),
        PipeEntity(id: c.project.newId(), points: const [Pt.zero, Pt(60, 0)], scope: HydraulicScope.mainline),
        for (final (x, s) in [(10.0, 'Green'), (20.0, 'Green'), (40.0, '')])
          OutletEntity(id: c.project.newId(), position: Pt(x, 0), scope: HydraulicScope.mainline, outletSpecId: 'impact34', nozzleId: 'i4.0', headM: 30, zoneName: s),
      ]);
      c.project.systemFlows.add(SystemFlow(id: 'sf1', name: 'Morning', valveIds: {'vih:Green'}));
    });
    await settle(tester, 2);
    final heads = c.project.entities.whereType<OutletEntity>().toList();

    // a head of the station: its station name and the flow that runs it
    c.select([heads.first.id]);
    await settle(tester, 2);
    expect(find.byKey(const Key('vih_station')), findsOneWidget);
    expect(find.text('Morning'), findsOneWidget);
    // the head of its own is in no flow: it runs in every flow
    c.select([heads.last.id]);
    await settle(tester, 2);
    expect(find.text(t('props.vihEveryFlow')), findsOneWidget);

    // the flows dialog lists both stations with their icon
    showManagementDialog(tester.element(find.byType(AppShell)), c);
    await settle(tester);
    final chips = find.ancestor(of: find.byIcon(Icons.water_drop_outlined), matching: find.byType(FilterChip));
    expect(chips, findsNWidgets(2));
    expect(find.widgetWithText(FilterChip, 'Green'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'OK').last);
    await settle(tester);

    // the design and the report tab of the stations
    await tester.runAsync(() => c.runDesign());
    await settle(tester);
    expect(c.results!.vihStations.keys, ['vih:Green', heads.last.id]);
    c.showReports = true;
    c.reportTab = reportTabKeys.indexOf('reports.vih');
    c.refresh();
    await settle(tester, 2);
    expect(find.byKey(const ValueKey('report_table_vih')), findsOneWidget);
  });
}
