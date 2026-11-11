import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/canvas/cad_canvas.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/dialogs/agb_dialogs.dart';
import 'package:opencadirrigation/app/widgets/dialogs/field_machine_dialogs.dart';
import 'package:opencadirrigation/app/widgets/reports_panel.dart';
import 'package:opencadirrigation/core/model/agb_settings.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/main.dart';

/// The dialogs of the machines, electrical and water design: each one
/// changes its settings (or draws its items) as one undo step, and the
/// report tab shows the tables after a design.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> until(WidgetTester tester, bool Function() done, {int max = 3000}) async {
    for (var i = 0; i < max && !done(); i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(done(), isTrue, reason: 'condition not reached');
    await settle(tester, 2);
  }

  Future<ProjectController> pumpShell(WidgetTester tester) async {
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
    c
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.snap.enabled = false;
    return c;
  }

  BuildContext ctxOf(WidgetTester tester) => tester.element(find.byType(CadCanvas));

  Future<void> tapVisible(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle(tester);
  }

  testWidgets('pump house, solar, water and two-wire: Apply stores the settings as one undo step', (tester) async {
    final c = await pumpShell(tester);
    loadExampleAction(c, ExampleId.orchard);
    await settle(tester);
    c.runDesign();
    await until(tester, () => !c.busy && c.results != null);

    // pump house: switch it on
    showPumpHouseDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.byKey(const Key('agb_ph_table')), findsOneWidget, reason: 'the circuits of the design');
    await tapVisible(tester, find.byKey(const Key('agb_ph_enabled')));
    await tapVisible(tester, find.byKey(const Key('agb_ph_apply')));
    expect(c.project.agb.pumpHouse.enabled, isTrue);
    expect(c.results, isNull, reason: 'the results priced the old settings');
    c.undo();
    await settle(tester);
    expect(c.project.agb.pumpHouse.enabled, isFalse, reason: 'one undo step');
    c.redo();
    await settle(tester);
    expect(c.project.agb.pumpHouse.enabled, isTrue);

    // two-wire: switch it on
    showTwoWireDialog(ctxOf(tester), c);
    await settle(tester);
    await tapVisible(tester, find.byKey(const Key('agb_tw_enabled')));
    await tapVisible(tester, find.byKey(const Key('agb_tw_apply')));
    expect(c.project.agb.twoWire.enabled, isTrue);

    // solar: grid-tied
    showSolarDesignDialog(ctxOf(tester), c);
    await settle(tester);
    await tapVisible(tester, find.byKey(const Key('agb_solar_mode')));
    await tester.tap(find.text(c.t('agb.solar.gridTied')).last);
    await settle(tester);
    await tapVisible(tester, find.byKey(const Key('agb_solar_apply')));
    expect(c.project.agb.solar.mode, SolarMode.gridTied);

    // water: a pH typed in the notation of the language
    showWaterQualityDialog(ctxOf(tester), c);
    await settle(tester);
    final ph = find.descendant(of: find.byKey(const Key('agb_water_ph')), matching: find.byType(TextField));
    await tester.ensureVisible(ph);
    await tester.enterText(ph, '7,8');
    await settle(tester, 2);
    expect(find.byKey(const Key('agb_water_hazards')), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('agb_water_apply')));
    expect(c.project.agb.water.ph, closeTo(7.8, 1e-9));

    // everything in one design, its tables under the new report tab
    c.runDesign();
    await until(tester, () => !c.busy && c.results != null);
    final keys = {for (final tb in c.reportTables()) tb.key};
    expect(keys, containsAll(['pumpHouse', 'pumpHouseSupply', 'solar', 'solarMonths', 'waterQuality', 'waterTreatment', 'twoWire']));
    c.reportTab = reportTabKeys.indexOf('reports.agb');
    c.showReports = true;
    c.refresh();
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('several pivots, traveller lanes and a furrow set are drawn from the selection', (tester) async {
    final c = await pumpShell(tester);
    c.newProject();
    await settle(tester);
    final field = AreaEntity(id: c.project.newId(), points: const [Pt(0, 0), Pt(2000, 0), Pt(2000, 1500), Pt(0, 1500)]);
    c.addEntity(field);
    c.select([field.id]);
    await settle(tester);

    showMultiPivotDialog(ctxOf(tester), c);
    await settle(tester);
    await tapVisible(tester, find.byKey(const Key('agb_mp_run')));
    expect(find.byKey(const Key('agb_mp_table')), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('agb_mp_apply')));
    final pivots = c.project.entities.whereType<PivotEntity>().toList();
    expect(pivots.length, greaterThanOrEqualTo(4));
    // named as every other pivot: the first part of the tool's label, numbered
    final base = c.t('tool.pivot').split('/').first.trim();
    expect([for (final x in pivots) x.name], [for (var k = 0; k < pivots.length; k++) '$base ${k + 1}']);
    expect(base, isNot(contains('/')));
    expect(c.project.entities.whereType<PipeEntity>().where((p) => p.scope == HydraulicScope.mainline), isNotEmpty);
    c.undo();
    await settle(tester);
    expect(c.project.entities.whereType<PivotEntity>(), isEmpty, reason: 'one undo step');

    final small = AreaEntity(id: c.project.newId(), points: const [Pt(0, 0), Pt(600, 0), Pt(600, 400), Pt(0, 400)]);
    c.addEntity(small);
    c.select([small.id]);
    await settle(tester);
    showTravellerLanesDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.byKey(const Key('agb_trav_table')), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('agb_trav_apply')));
    final lanes = c.project.entities.whereType<TravellerEntity>().toList();
    expect(lanes, isNotEmpty);
    expect(c.project.systemFlows.where((f) => f.valveIds.length == 1 && lanes.any((l) => f.valveIds.contains(l.id))), hasLength(lanes.length), reason: 'one system flow per lane');

    // a lane selected: its data
    c.select([lanes.first.id]);
    await settle(tester);
    showTravellerLanesDialog(ctxOf(tester), c);
    await settle(tester);
    await tapVisible(tester, find.byKey(const Key('agb_trav_apply')));
    expect(c.project.entities.whereType<TravellerEntity>(), hasLength(lanes.length));

    final head = LineEntity(id: c.project.newId(), a: const Pt(0, -10), b: const Pt(100, -10));
    c.addEntity(head);
    c.select([head.id]);
    await settle(tester);
    showFurrowSetDialog(ctxOf(tester), c);
    await settle(tester);
    await tapVisible(tester, find.byKey(const Key('agb_furrow_apply')));
    final sets = c.project.entities.whereType<FurrowEntity>().toList();
    expect(sets, hasLength(1));
    expect(sets.single.points.first, const Pt(0, -10));
    expect(tester.takeException(), isNull);
  });
}
