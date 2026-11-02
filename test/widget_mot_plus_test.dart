// 1.6.0 MOT+: the dialogs of the pump station, the reservoir and the design
// over its life lay out on a phone and with the text twice as big; the
// station and the reservoir are one undo step; the long network analyses
// show their progress and stop with Cancel.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/dialogs/life_scenarios_dialog.dart';
import 'package:opencadirrigation/app/widgets/dialogs/network_ops_dialogs.dart';
import 'package:opencadirrigation/app/widgets/dialogs/pump_station_dialog.dart';
import 'package:opencadirrigation/app/widgets/dialogs/reservoir_dialog.dart';
import 'package:opencadirrigation/core/design/block_generator.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/main.dart';

/// A pump from a pond feeding one micro-sprinkler zone, with a closed
/// outline around the pond.
Project pumpedProject() {
  final p = Project();
  final block = generateBlock(
    p,
    BlockOptions(
      polygon: [Pt.zero, const Pt(40, 0), const Pt(40, 24), const Pt(0, 24)],
      direction: const Pt(1, 0),
      lateralSpacing: 4,
      outletSpecId: 'micro',
      nozzleId: 'm50',
      outletSpacing: 3.5,
      headM: 15,
      valveSpecId: 'ev50',
      zoneName: 'Zona 1',
    ),
  );
  p.entities.addAll(block.all);
  final v = block.valve!;
  final src = v.position + const Pt(-100, 0);
  p.entities.add(PipeEntity(id: 'main', points: [src, v.position], scope: HydraulicScope.mainline, name: 'Main'));
  p.entities.add(WaterSupplyEntity(id: 'src', position: src, name: 'Pond', calculatePressure: false, designHeadM: 0));
  p.entities.add(PumpEntity(id: 'pump', position: src + const Pt(3, 0), pumpSpecId: 'pump_c2', name: 'Pump'));
  p.entities.add(PolylineEntity(id: 'pond', points: [src + const Pt(-5, -5), src + const Pt(5, -5), src + const Pt(5, 5), src + const Pt(-5, 5)], closed: true));
  return p;
}

void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<ProjectController> pumpShell(WidgetTester tester, {Size size = const Size(1920, 1080), double textScale = 1}) async {
    TutorialController.markDone();
    setPref('lang', 'pt');
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
    c
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.openProject(pumpedProject());
    await settle(tester);
    return c;
  }

  BuildContext ctxOf(WidgetTester tester) => tester.element(find.byType(Scaffold).first);

  for (final (name, size, scale) in const [('phone', Size(360, 640), 1.0), ('text twice as big', Size(1280, 800), 2.0)]) {
    testWidgets('the new dialogs lay out: $name', (tester) async {
      final c = await pumpShell(tester, size: size, textScale: scale);
      c.results = Designer(c.project).designAll();
      c.refresh();
      await settle(tester, 1);
      final pump = c.project.byId('pump') as PumpEntity;
      final supply = c.project.byId('src') as WaterSupplyEntity;
      final open = <String, void Function()>{
        'station': () => showPumpStationDialog(ctxOf(tester), c, pump),
        'reservoir': () => showReservoirDialog(ctxOf(tester), c, supply),
        'life': () => showLifeScenariosDialog(ctxOf(tester), c),
      };
      for (final e in open.entries) {
        e.value();
        await settle(tester);
        expect(tester.takeException(), isNull, reason: '${e.key} at $name');
        expect(find.byType(Dialog), findsWidgets, reason: '${e.key} opened');
        Navigator.of(tester.element(find.byType(Dialog).last)).pop();
        await settle(tester);
        expect(tester.takeException(), isNull, reason: '${e.key} closing at $name');
      }
    });
  }

  testWidgets('the pump station: a standby pump added in one undo step', (tester) async {
    final c = await pumpShell(tester);
    showPumpStationDialog(ctxOf(tester), c, c.project.byId('pump') as PumpEntity);
    await settle(tester);
    await tester.tap(find.byKey(const Key('station_add')));
    await settle(tester, 1);
    await tester.tap(find.byKey(const Key('station_standby_0')));
    await settle(tester, 1);
    await tester.tap(find.byKey(const Key('station_apply')));
    await settle(tester);
    final s = (c.project.byId('pump') as PumpEntity).station;
    expect(s, isNotNull);
    expect(s!.standbyCount, 1);
    expect(s.dutyCount, 1);
    c.undo();
    await settle(tester, 1);
    expect((c.project.byId('pump') as PumpEntity).station, isNull);
  });

  testWidgets('the reservoir: the outline picked, the volume shown, applied in one step', (tester) async {
    final c = await pumpShell(tester);
    final supply = c.project.byId('src') as WaterSupplyEntity;
    showReservoirDialog(ctxOf(tester), c, supply);
    await settle(tester);
    // the closed outline of the drawing is offered and taken by default
    expect(find.text('Volume'), findsWidgets);
    await tester.tap(find.byKey(const Key('res_apply')));
    await settle(tester);
    final r = (c.project.byId('src') as WaterSupplyEntity).reservoir;
    expect(r, isNotNull);
    expect(r!.outlineId, 'pond');
    c.undo();
    await settle(tester, 1);
    expect((c.project.byId('src') as WaterSupplyEntity).reservoir, isNull);
  });

  testWidgets('a long analysis shows its progress and stops with Cancel', (tester) async {
    final c = await pumpShell(tester);
    c.results = Designer(c.project).designAll();
    c.refresh();
    await settle(tester, 1);
    showCriticalityDialog(ctxOf(tester), c);
    await settle(tester);
    await tester.tap(find.byKey(const Key('crit_run')));
    await tester.pump();
    // running: the bar and the Cancel button
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    final cancel = find.byKey(const Key('crit_run_cancel'));
    expect(cancel, findsOneWidget);
    await tester.tap(cancel);
    await settle(tester);
    expect(find.byKey(const Key('crit_run_cancel')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
