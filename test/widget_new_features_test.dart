import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/canvas/cad_canvas.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/shortcuts.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/dialogs/dialogs.dart';
import 'package:opencadirrigation/app/widgets/reports_panel.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/units.dart';
import 'package:opencadirrigation/main.dart';

/// The functions added for the densogram, the valve wiring, the automatic
/// system flows, ordinate / diameter dimensions and the settings dialogs
/// that now keep their edits however they are closed.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<ProjectController> pumpShell(WidgetTester tester, {bool example = true}) async {
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
    if (!example) c.newProject();
    await settle(tester);
    return c;
  }

  Offset screenOf(WidgetTester tester, ProjectController c, Pt world) {
    final box = tester.renderObject(find.byType(CadCanvas)) as RenderBox;
    return box.localToGlobal(c.camera.toScreen(world));
  }

  Future<void> clickWorld(WidgetTester tester, ProjectController c, Pt world) async {
    await tester.tapAt(screenOf(tester, c, world));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> typeInto(WidgetTester tester, Finder field, String value) async {
    final f = find.descendant(of: field, matching: find.byType(TextField), matchRoot: true).first;
    await tester.tap(f);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(f, value);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 2);
  }

  BuildContext ctxOf(WidgetTester tester) => tester.element(find.byType(CadCanvas));

  testWidgets('management: pivots join the flows, automatic flows, a tap outside keeps the edit as one undo step', (tester) async {
    final c = await pumpShell(tester);
    c.addEntity(PivotEntity(id: 'pvT', center: const Pt(-300, 0), radiusM: 100, zoneName: 'Pivô T'));
    await settle(tester);
    final before = jsonEncode([for (final f in c.project.systemFlows) f.toJson()]);
    final undoBefore = c.historyIndex;
    c.dirty = false;
    showManagementDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.widgetWithText(FilterChip, 'Pivô T'), findsWidgets, reason: 'the pivot can join a system flow');
    await tester.tap(find.byKey(const Key('mgmt_auto')));
    await settle(tester);
    expect(find.byKey(const Key('mgmt_auto_panel')), findsOneWidget);
    await typeInto(tester, find.byKey(const Key('mgmt_auto_n')), '1');
    await tester.tap(find.byKey(const Key('mgmt_auto_run')));
    await settle(tester);
    final demands = c.project.entities.where((e) => e is ControlValveEntity || e is PivotEntity).length;
    expect(c.project.systemFlows.length, demands);
    expect(c.project.systemFlows.every((f) => f.valveIds.length == 1), isTrue);
    expect(find.textContaining(c.t('mgmt.demand', {'q': ''}).trim()), findsWidgets);
    // closed with a tap outside the dialog: the edit stays and can be undone
    await tester.tapAt(const Offset(4, 1070));
    await settle(tester);
    expect(find.byKey(const Key('mgmt_auto_panel')), findsNothing);
    expect(c.dirty, isTrue);
    expect(c.historyIndex, undoBefore + 1);
    expect(c.historyEntries.last.label, 'hist.flows');
    c.undo();
    expect(jsonEncode([for (final f in c.project.systemFlows) f.toJson()]), before);
  });

  testWidgets('parameters closed outside keep the edit, drop the stale results and undo in one step; units keep the results', (tester) async {
    final c = await pumpShell(tester);
    c.results = DesignResults(timestamp: DateTime(2026));
    showDesignParamsDialog(ctxOf(tester), c);
    await settle(tester);
    await typeInto(tester, find.widgetWithText(TextField, c.t('dlg.vZone')), '1.2');
    await tester.tapAt(const Offset(4, 1070));
    await settle(tester);
    expect(c.project.params.maxZoneVelocity, 1.2);
    expect(c.results, isNull);
    expect(c.historyEntries.last.label, 'hist.params');
    c.undo();
    expect(c.project.params.maxZoneVelocity, 1.5);
    // units change the display only
    c.results = DesignResults(timestamp: DateTime(2026));
    showUnitsDialog(ctxOf(tester), c);
    await settle(tester);
    await tester.tap(find.text(c.t('dlg.us')));
    await settle(tester);
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect(c.units.flow, Units.us.flow);
    expect(c.results, isNotNull);
    expect(c.historyEntries.last.label, 'hist.units');
  });

  testWidgets('densogram: Zone menu, statistics, options and the map on the drawing', (tester) async {
    final c = await pumpShell(tester);
    await tester.tap(find.text(c.t('menu.zone')).first);
    await settle(tester, 2);
    await tester.tap(find.byKey(const Key('menu_densogram')));
    await settle(tester);
    expect(find.text(c.t('dens.title')), findsOneWidget);
    expect(find.text(c.t('dens.sources')), findsOneWidget);
    expect(find.text('CU (Christiansen)'), findsOneWidget);
    await typeInto(tester, find.byKey(const Key('dens_cell')), '2');
    expect(c.densogramOptions.cellSize, 2);
    expect(c.densogram.cell, greaterThanOrEqualTo(2));
    await tester.tap(find.byKey(const Key('dens_show')));
    await settle(tester);
    expect(c.overlay, OverlayMode.densogram);
    expect(c.densogram.stats.cu, greaterThan(0));
    // the map and its legend are painted without errors
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);
    // the DENS command opens it too
    expect(commandAliases['DENS'], CadAction.densogram);
    expect(commandAliases['DENSOGRAMA'], CadAction.densogram);
  });

  testWidgets('controller and wire tools draw the wiring; the design lists it in the Electrical tab and the properties', (tester) async {
    final c = await pumpShell(tester, example: false);
    c.addEntities([
      WaterSupplyEntity(id: 'ws', position: const Pt(-20, 0), calculatePressure: false, designHeadM: 45, maxHeadM: 60, designFlow: 10 * m3sPerM3h, maxFlow: 12 * m3sPerM3h),
      PipeEntity(id: 'mp', points: const [Pt(-20, 0), Pt(-5, 0)], scope: HydraulicScope.mainline),
      ControlValveEntity(id: 'v', position: const Pt(-5, 0), zoneName: 'Z1', valveSpecId: 'ev40'),
      PipeEntity(id: 'zp', points: const [Pt(-5, 0), Pt(0, 0), Pt(20, 0)], scope: HydraulicScope.zone),
      OutletEntity(id: 'o1', position: Pt.zero, outletSpecId: 'rotor', nozzleId: 'r3', headM: 25),
      OutletEntity(id: 'o2', position: const Pt(10, 0), outletSpecId: 'rotor', nozzleId: 'r3', headM: 25),
      OutletEntity(id: 'o3', position: const Pt(20, 0), outletSpecId: 'rotor', nozzleId: 'r3', headM: 25),
    ]);
    c.camera.center = const Pt(-5, 5);
    c.camera.scale = 12;
    await settle(tester);
    await tester.tap(find.byKey(const Key('tool_controller')));
    await settle(tester);
    expect(c.activeTool, ToolId.controller);
    await clickWorld(tester, c, const Pt(-15, 10));
    final ctrl = c.project.entities.whereType<ControllerEntity>().single;
    expect(ctrl.name, '${c.t('name.controller')} 1');
    expect(ctrl.stations, 12);
    await tester.tap(find.byKey(const Key('tool_wire')));
    await settle(tester);
    // the canvas tells double clicks by the wall clock: let it pass
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await clickWorld(tester, c, ctrl.position);
    await clickWorld(tester, c, const Pt(-5, 10));
    await clickWorld(tester, c, const Pt(-5, 0));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    final wire = c.project.entities.whereType<WireEntity>().single;
    expect(wire.points.length, 3, reason: '${wire.points}');
    // snap off: land the ends exactly on the controller and the valve
    wire.points
      ..[0] = ctrl.position
      ..[2] = const Pt(-5, 0);
    c.entitiesChanged();
    unawaited(c.runDesign());
    await tester.pump();
    for (var i = 0; i < 2000 && (c.busy || c.results == null); i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await settle(tester);
    final el = c.results!.electrical!;
    expect(el.runs.single.valveId, 'v');
    expect(el.runs.single.station, 1);
    expect(el.runs.single.ok, isTrue);
    expect(c.results!.bom.any((l) => l.category == 'bom.electrical'), isTrue);
    // Electrical tab
    c.reportTab = reportTabKeys.indexOf('reports.electrical');
    c.showReports = true;
    c.refresh();
    await settle(tester);
    expect(find.byKey(const ValueKey('report_table_electrical')), findsOneWidget);
    // properties of the controller and of the valve
    c.select([ctrl.id]);
    await settle(tester);
    expect(find.text(c.t('elec.used')), findsOneWidget);
    c.select(['v']);
    await settle(tester);
    expect(find.text(c.t('elec.volts')), findsOneWidget);
  });

  testWidgets('ordinate and diameter dimensions from their tools', (tester) async {
    final c = await pumpShell(tester, example: false);
    c.camera.center = const Pt(5, 5);
    c.camera.scale = 15;
    await settle(tester);
    await tester.tap(find.byKey(const Key('tool_dimOrdinate')));
    await settle(tester);
    await clickWorld(tester, c, const Pt(10, 2));
    await clickWorld(tester, c, const Pt(10.5, 12));
    final od = c.project.entities.whereType<OrdinateDimensionEntity>().single;
    expect(od.xAxis, isTrue, reason: 'a vertical leader dimensions X');
    expect(od.value, closeTo(10, 0.2));
    await tester.tap(find.byKey(const Key('tool_dimRadial')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('tool_radial_diameter')));
    await settle(tester);
    expect(c.toolSettings.radialDiameter, isTrue);
    await clickWorld(tester, c, const Pt(0, 0));
    await clickWorld(tester, c, const Pt(3, 0));
    final rd = c.project.entities.whereType<RadialDimensionEntity>().single;
    expect(rd.diameter, isTrue);
    expect(rd.value, closeTo(6, 0.3));
    // properties: switch the ordinate to Y
    c.select([od.id]);
    await settle(tester);
    await tester.tap(find.widgetWithText(SwitchListTile, c.t('props.ordinateX')));
    await settle(tester);
    expect(od.xAxis, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catalogue editor: the Wires tab adds a wire and the session is one undo step', (tester) async {
    final c = await pumpShell(tester);
    final n = c.project.catalog.wires.length;
    await tester.tap(find.text(c.t('menu.design')).first);
    await settle(tester, 2);
    await tester.tap(find.byKey(const Key('menu_catalog')));
    await settle(tester);
    await tester.tap(find.text(c.t('cat.wires')));
    await settle(tester);
    expect(find.text(c.t('cat.ohmKm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('cat_add')));
    await settle(tester);
    expect(c.project.catalog.wires.length, n + 1);
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect(c.historyEntries.last.label, 'hist.catalog');
    c.undo();
    expect(c.project.catalog.wires.length, n);
  });
}
