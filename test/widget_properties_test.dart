import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/dialogs/dialogs.dart';
import 'package:opencadirrigation/app/widgets/fields.dart';
import 'package:opencadirrigation/app/widgets/hgl_chart.dart';
import 'package:opencadirrigation/app/widgets/profile_chart.dart';
import 'package:opencadirrigation/core/design/pivot.dart' show PivotKind;
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/main.dart';

/// The properties panel for every entity type, batch editing, the results
/// of the selection after a design and the defaults of every tool; the
/// lateral calculator with an incomplete catalogue.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<ProjectController> pumpShell(WidgetTester tester, {bool example = true, bool design = false}) async {
    TutorialController.markDone();
    setPref('lang', 'pt');
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
    if (!example) c.newProject();
    if (design) await tester.runAsync(() => c.runDesign());
    await settle(tester);
    return c;
  }

  Future<void> show(WidgetTester tester, ProjectController c, Iterable<Entity> es) async {
    c.select(es.map((e) => e.id));
    await settle(tester, 2);
  }

  Future<T> add<T extends Entity>(WidgetTester tester, ProjectController c, T e) async {
    c.addEntity(e);
    await show(tester, c, [e]);
    return e;
  }

  Finder field(String prefix) => find.byWidgetPredicate((w) => w is TextField && (w.decoration?.labelText ?? '').startsWith(prefix));

  Future<void> type(WidgetTester tester, String prefix, String value) async {
    final f = field(prefix).first;
    expect(f, findsOneWidget, reason: 'field $prefix');
    await tester.tap(f);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(f, value);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 2);
  }

  /// Picks [id] in the dropdown labelled [label] (as the menu would).
  Future<void> pick(WidgetTester tester, String label, String? id) async {
    final f = find.byWidgetPredicate((w) => w is SpecDropdown && w.label == label);
    expect(f, findsWidgets, reason: 'dropdown $label');
    (tester.widget(f.first) as SpecDropdown).onChanged(id);
    await settle(tester, 2);
  }

  Future<void> toggle(WidgetTester tester, String title) async {
    await tester.tap(find.widgetWithText(SwitchListTile, title).first);
    await settle(tester, 2);
  }

  testWidgets('single entities: locked layer, catalogue pickers and every drawing and hydraulic type', (tester) async {
    final c = await pumpShell(tester, example: false);
    final t = c.t;
    // nothing selected: the defaults of the active tool
    expect(find.textContaining(t('props.defaults')), findsOneWidget);
    // an entity on a locked layer says so
    final pipe = await add(tester, c, PipeEntity(id: c.project.newId(), points: [Pt.zero, const Pt(30, 0)], scope: HydraulicScope.zone));
    c.setLayerLocked(pipe.layer, true);
    c.select([pipe.id]);
    await settle(tester, 2);
    expect(find.text(t('props.locked')), findsOneWidget);
    c.setLayerLocked(pipe.layer, false);
    await show(tester, c, [pipe]);
    // a catalogue pipe turns automatic sizing off in the model; "auto" turns it back on
    final zonePipe = c.project.catalog.pipesFor(PipeUsage.zone).first;
    pipe.computerSized = false;
    await pick(tester, t('props.pipe'), zonePipe.id);
    expect(pipe.pipeSpecId, zonePipe.id);
    await pick(tester, t('props.pipe'), null);
    expect((pipe.pipeSpecId, pipe.computerSized), (null, true));

    // lateral: a new outlet brings its first nozzle; a lateral pipe back to auto
    final lat = await add(tester, c, SpraylineEntity(id: c.project.newId(), points: [const Pt(0, 10), const Pt(30, 10)], outletSpecId: 'micro', nozzleId: 'm50', pipeSpecId: c.project.catalog.pipesFor(PipeUsage.lateral).first.id, computerSized: false));
    await pick(tester, t('props.outlet'), 'rotor');
    expect((lat.outletSpecId, lat.nozzleId), ('rotor', c.project.catalog.outlet('rotor')!.nozzles.first.id));
    await pick(tester, t('props.pipe'), null);
    expect(lat.computerSized, isTrue);

    // single outlet: outlet, nozzle and arc
    final o = await add(tester, c, OutletEntity(id: c.project.newId(), position: const Pt(40, 0), outletSpecId: 'micro', nozzleId: 'm50'));
    await pick(tester, t('props.outlet'), 'spray');
    expect(o.nozzleId, c.project.catalog.outlet('spray')!.nozzles.first.id);
    await pick(tester, t('props.nozzle'), 's12h');
    expect(o.nozzleId, 's12h');
    await type(tester, t('props.arc'), '180');
    expect(o.arcDeg, 180);

    // pressure reducing valve: the setting field appears with a PRV
    final misc = await add(tester, c, MiscHydraulicEntity(id: c.project.newId(), position: const Pt(50, 0), valveSpecId: 'gate50'));
    expect(field(t('props.setting')), findsNothing);
    await pick(tester, t('props.misc'), 'prv50');
    expect(misc.valveSpecId, 'prv50');
    await type(tester, t('props.setting'), '28');
    expect(misc.settingM, closeTo(28, 1e-9));

    // junction: a fixed elevation, and 0 back to the terrain
    final j = await add(tester, c, JunctionEntity(id: c.project.newId(), position: const Pt(60, 0)));
    await type(tester, t('props.elevationDem'), '512,5');
    expect(j.fixedElevation, 512.5);
    await type(tester, t('props.elevationDem'), '0');
    expect(j.fixedElevation, isNull);

    // pivot: a linear move gets the default travel
    final pv = await add(tester, c, PivotEntity(id: c.project.newId(), center: const Pt(0, 100), radiusM: 200));
    await pick(tester, t('props.pivotKind'), PivotKind.linear.name);
    expect((pv.kind, pv.travelM), (PivotKind.linear, c.toolSettings.pivotTravelM));
    expect(field(t('props.pivotTravel')), findsOneWidget);
    await type(tester, t('props.pivotRadius'), '-5');
    expect(pv.radiusM, 200, reason: 'a non-positive radius is refused');

    // terrain and drawing entities
    final spot = await add(tester, c, SpotHeightEntity(id: c.project.newId(), position: const Pt(70, 0), elevation: 100));
    await type(tester, t('props.elevation'), '101.25');
    expect(spot.elevation, 101.25);
    final arc = await add(tester, c, ArcEntity(id: c.project.newId(), center: Pt.zero, radius: 5, startRad: 0, sweepRad: 1.5707963267948966));
    expect(find.text('90.0°'), findsOneWidget);
    await type(tester, t('props.radius'), '6');
    expect(arc.radius, 6);
    final spline = await add(tester, c, SplineEntity(id: c.project.newId(), points: [Pt.zero, const Pt(5, 3), const Pt(10, 0)]));
    await toggle(tester, t('props.closed'));
    expect(spline.closed, isTrue);
    final dim = await add(tester, c, DimensionEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(10, 0)));
    await type(tester, t('props.dimOffset'), '3');
    expect(dim.offset, 3);
    final ang = await add(tester, c, AngularDimensionEntity(id: c.project.newId(), vertex: Pt.zero, a: const Pt(5, 0), b: const Pt(0, 5)));
    expect(find.text('90.00°'), findsOneWidget);
    await type(tester, t('props.dimRadius'), '-2');
    expect(ang.radius, 1, reason: 'a non-positive radius falls back to 1');
    final rad = await add(tester, c, RadialDimensionEntity(id: c.project.newId(), center: Pt.zero, point: const Pt(3, 0)));
    await toggle(tester, t('props.dimDiameter'));
    expect(rad.diameter, isTrue);
    expect(find.text(t('props.diameter')), findsOneWidget);
    final od = await add(tester, c, OrdinateDimensionEntity(id: c.project.newId(), point: const Pt(7, 2), leaderEnd: const Pt(7, 8)));
    await toggle(tester, t('props.ordinateX'));
    expect(od.xAxis, isFalse);
    await type(tester, '${t('props.ordinateOrigin')} Y', '2');
    expect(od.value, 0);
    final ctrl = await add(tester, c, ControllerEntity(id: c.project.newId(), position: const Pt(0, -10)));
    await type(tester, t('props.stations'), '0');
    expect(ctrl.stations, 1);
    await type(tester, t('props.outputVolts'), '-1');
    expect(ctrl.outputVolts, 24);
    await add(tester, c, WireEntity(id: c.project.newId(), points: [const Pt(0, -10), const Pt(0, -20)]));
    expect(find.text(t('hint.wire')), findsOneWidget);
    final line = await add(tester, c, LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(3, 4)));
    expect(find.textContaining('5.00'), findsWidgets);
    // the layer picker moves the entity
    await pick(tester, t('props.layer'), Layers.text);
    expect(line.layer, Layers.text);
    // the name field
    await type(tester, t('props.name'), 'Divisa');
    expect(line.name, 'Divisa');
  });

  testWidgets('batch editing of every kind, mixed values and the layer of the selection', (tester) async {
    final c = await pumpShell(tester, example: false);
    final t = c.t;
    Future<List<T>> two<T extends Entity>(T Function(int i) make) async {
      final es = [make(0), make(1)];
      c.addEntities(es);
      await show(tester, c, es);
      expect(find.text(t('props.multi', {'n': '2'})), findsOneWidget);
      return es;
    }

    // laterals with different heads show "mixed"
    final lats = await two((i) => SpraylineEntity(id: c.project.newId(), points: [Pt(0, i * 10.0), Pt(20, i * 10.0)], outletSpecId: 'micro', nozzleId: 'm50', headM: 15.0 + i, pipeSpecId: 'x', computerSized: false));
    expect(find.text(t('props.mixed')), findsWidgets);
    await pick(tester, t('props.pipe'), null);
    expect(lats.every((e) => e.pipeSpecId == null && e.computerSized), isTrue);
    await pick(tester, t('props.outlet'), 'rotor');
    expect(lats.every((e) => e.outletSpecId == 'rotor' && e.nozzleId == c.project.catalog.outlet('rotor')!.nozzles.first.id), isTrue);
    await pick(tester, t('props.nozzle'), 'r3');
    expect(lats.every((e) => e.nozzleId == 'r3'), isTrue);
    await type(tester, t('props.head'), '25');
    await type(tester, t('props.spacing'), '9');
    expect(lats.every((e) => e.headM == 25 && e.spacing == 9), isTrue);

    final tapes = await two((i) => TapeEntity(id: c.project.newId(), points: [Pt(0, 30 + i * 1.0), Pt(20, 30 + i * 1.0)], tapeSpecId: 'tape16_10_30', inletHeadM: 8.0 + i));
    await pick(tester, t('props.tape'), 'drip16_16_50');
    await type(tester, t('props.inlet'), '10');
    expect(tapes.every((e) => e.tapeSpecId == 'drip16_16_50' && e.inletHeadM == 10), isTrue);

    final pipes = await two((i) => PipeEntity(id: c.project.newId(), points: [Pt(0, 50 + i * 5.0), Pt(20, 50 + i * 5.0)], scope: HydraulicScope.mainline, depth: i * 0.5));
    await toggle(tester, t('props.auto'));
    expect(pipes.every((e) => !e.computerSized), isTrue);
    await type(tester, t('props.depth'), '0.8');
    expect(pipes.every((e) => e.depth == 0.8), isTrue);

    final outs = await two((i) => OutletEntity(id: c.project.newId(), position: Pt(i * 5.0, 70), outletSpecId: 'micro', nozzleId: 'm50', arcDeg: 360.0 - i * 180));
    await pick(tester, t('props.outlet'), 'spray');
    await pick(tester, t('props.nozzle'), 's12q');
    await type(tester, t('props.head'), '21');
    await type(tester, t('props.arc'), '90');
    expect(outs.every((e) => e.outletSpecId == 'spray' && e.nozzleId == 's12q' && e.headM == 21 && e.arcDeg == 90), isTrue);

    final valves = await two((i) => ControlValveEntity(id: c.project.newId(), position: Pt(i * 5.0, 80), valveSpecId: i == 0 ? 'ev25' : 'ev40'));
    await pick(tester, t('props.valve'), 'ev50');
    expect(valves.every((e) => e.valveSpecId == 'ev50'), isTrue);

    final spots = await two((i) => SpotHeightEntity(id: c.project.newId(), position: Pt(i * 5.0, 90), elevation: 100.0 + i));
    await type(tester, t('props.elevation'), '99');
    expect(spots.every((e) => e.elevation == 99), isTrue);

    final contours = await two((i) => ContourEntity(id: c.project.newId(), points: [Pt(0, 95 + i * 1.0), Pt(9, 95 + i * 1.0)], elevation: 100.0 + i));
    await type(tester, t('props.elevation'), '98');
    expect(contours.every((e) => e.elevation == 98), isTrue);

    final texts = await two((i) => TextEntity(id: c.project.newId(), position: Pt(i * 5.0, 100), text: 'T$i'));
    await type(tester, t('props.textHeight'), '2.5');
    expect(texts.every((e) => e.height == 2.5), isTrue);

    final areas = await two((i) => AreaEntity(id: c.project.newId(), points: [Pt(i * 20.0, 110), Pt(i * 20.0 + 10, 110), Pt(i * 20.0 + 10, 120)]));
    await type(tester, t('props.efficiency'), '5');
    expect(areas.every((e) => e.efficiency == 1.0), isTrue, reason: 'clamped to 100 %');
    await type(tester, t('props.eto'), '6');
    expect(areas.every((e) => e.etoMmDay == 6), isTrue);
    // the layer of the whole selection
    await pick(tester, t('props.layer'), Layers.drawing);
    expect(areas.every((e) => e.layer == Layers.drawing), isTrue);
    // delete the selection
    final n = c.project.entities.length;
    await tester.tap(find.widgetWithText(FilledButton, t('edit.delete')));
    await settle(tester, 2);
    expect(c.project.entities.length, n - 2);
  });

  testWidgets('results of the selection after a design', (tester) async {
    final c = await pumpShell(tester, design: true);
    final t = c.t;
    expect(c.results, isNotNull);
    final valve = c.project.entities.whereType<ControlValveEntity>().first;
    await show(tester, c, [valve]);
    expect(find.text(t('props.results').toUpperCase()), findsOneWidget);
    expect(find.text(t('props.downstream')), findsOneWidget);
    expect(find.text(t('props.uniformity')), findsOneWidget);
    final pipe = c.project.entities.whereType<PipeEntity>().firstWhere((p) => c.results!.pipesByEntity[p.id]?.isNotEmpty ?? false);
    await show(tester, c, [pipe]);
    expect(find.text(t('result.velocity')), findsOneWidget);
    expect(find.text(t('result.pEnd')), findsOneWidget);
    final lateral = c.project.entities.firstWhere((e) => (e is SpraylineEntity || e is TapeEntity) && (c.results!.outletsByEntity[e.id]?.isNotEmpty ?? false));
    await show(tester, c, [lateral]);
    expect(find.textContaining('${t('result.pressure')} ${t('result.min')}'), findsOneWidget);
    final supply = c.project.entities.whereType<WaterSupplyEntity>().first;
    await show(tester, c, [supply]);
    expect(find.text(c.results!.systemFlows.first.name), findsWidgets);
    final pump = c.project.entities.whereType<PumpEntity>().firstOrNull;
    if (pump != null) {
      await show(tester, c, [pump]);
      expect(find.textContaining(t('rep.pIn')), findsWidgets);
    }
    // an entity without results says so
    final text = await add(tester, c, TextEntity(id: c.project.newId(), position: Pt.zero, text: 'x'));
    expect(text.text, 'x');
  });

  testWidgets('reports of the selection: profile with the pipe and grade line, HGL of a valve', (tester) async {
    final c = await pumpShell(tester, design: true);
    final r = c.results!;
    // a designed pipe: ground profile, the pipe and its hydraulic grade line
    final pipe = c.project.entities.whereType<PipeEntity>().firstWhere((p) => (r.pipesByEntity[p.id]?.length ?? 0) >= 1);
    c.select([pipe.id]);
    c.reportTab = ProjectController.profileReportTab;
    c.showReports = true;
    c.refresh();
    await settle(tester);
    final chart = tester.widget<ProfileChart>(find.byType(ProfileChart));
    final segs = [...r.pipesByEntity[pipe.id]!]..sort((a, b) => a.segmentIndex.compareTo(b.segmentIndex));
    expect(chart.pipe!.length, segs.length + 1);
    expect(chart.hgl!.length, segs.length + 1);
    expect(chart.pipe!.last.$1, closeTo(pipe.length, 1e-6), reason: 'stations along the drawn pipe');
    // the grade line stands above the pipe by the pressure head at each end
    expect(chart.hgl!.first.$2 - chart.pipe!.first.$2, closeTo(segs.first.pressureStart, 1e-9));
    expect(chart.hgl!.last.$2 - chart.pipe!.last.$2, closeTo(segs.last.pressureEnd, 1e-9));
    expect(chart.samples.last.$1, closeTo(pipe.length, 1e-6));
    // a valve: the HGL of the lateral with the lowest emitter pressure of its zone
    final valve = c.project.entities.whereType<ControlValveEntity>().firstWhere((v) => r.zones[v.id]?.minOutlet != null);
    c.select([valve.id]);
    c.reportTab = 6;
    c.refresh();
    await settle(tester);
    final hgl = tester.widget<HglChart>(find.byType(HglChart));
    final z = r.zones[valve.id]!;
    expect(hgl.title, z.zoneName);
    expect((hgl.allowedMin, hgl.allowedMax), (z.allowedMin, z.allowedMax));
    expect(hgl.segments.every((sg) => sg.entityId == z.minOutlet!.entityId), isTrue);
    // nothing designed selected: a hint
    final text = await add(tester, c, TextEntity(id: c.project.newId(), position: Pt.zero, text: 't'));
    c.reportTab = ProjectController.profileReportTab;
    c.refresh();
    await settle(tester);
    expect(find.byKey(const Key('profile_tool')), findsOneWidget, reason: 'no path for ${text.id}');
  });

  testWidgets('defaults of every creation and editing tool', (tester) async {
    final c = await pumpShell(tester, example: false);
    final t = c.t;
    final s = c.toolSettings;
    Future<void> tool(ToolId id) async {
      c.setTool(id);
      await settle(tester, 2);
      expect(find.textContaining(t('props.defaults')), findsOneWidget, reason: '$id');
    }

    await tool(ToolId.sprayline);
    await pick(tester, t('props.outlet'), 'impact34');
    final impact = c.project.catalog.outlet('impact34')!.nozzles.first;
    expect((s.nozzleId, s.headM), (impact.id, impact.defaultHeadM));
    await pick(tester, t('props.nozzle'), c.project.catalog.outlet('impact34')!.nozzles.last.id);
    expect(s.headM, c.project.catalog.outlet('impact34')!.nozzles.last.defaultHeadM);
    await toggle(tester, t('props.halfSpacing'));
    expect(s.outletOffsetHalf, isFalse);
    await pick(tester, t('props.pipe'), c.project.catalog.pipesFor(PipeUsage.lateral).first.id);
    expect(s.lateralPipeSpecId, isNotNull);
    await tool(ToolId.outlet);
    await type(tester, t('props.arc'), '270');
    expect(s.arcDeg, 270);
    await tester.tap(find.descendant(of: find.byType(SegmentedButton<HydraulicScope>), matching: find.text(t('scope.mainline'))));
    await settle(tester, 2);
    expect(s.pointScope, HydraulicScope.mainline);
    await tool(ToolId.tape);
    await pick(tester, t('props.tape'), 'tape16_16_20');
    expect(s.tapeInletHeadM, c.project.catalog.tape('tape16_16_20')!.defaultInletHeadM);
    await type(tester, t('props.inlet'), '9');
    expect(s.tapeInletHeadM, 9);
    await tool(ToolId.misc);
    await pick(tester, t('props.misc'), 'prv80');
    expect(s.miscSettingM, 30);
    await type(tester, t('props.setting'), '27');
    expect(s.miscSettingM, 27);
    await toggle(tester, t('props.splitOnInsert'));
    expect(s.splitPipesOnInsert, isFalse);
    await tool(ToolId.valve);
    await pick(tester, t('props.valve'), 'ev80');
    expect(s.valveSpecId, 'ev80');
    await tool(ToolId.pump);
    await pick(tester, t('props.pump'), c.project.catalog.pumps.last.id);
    expect(s.pumpSpecId, c.project.catalog.pumps.last.id);
    await tool(ToolId.zonePipe);
    await pick(tester, t('props.pipe'), c.project.catalog.pipesFor(PipeUsage.zone).last.id);
    expect(s.zonePipeSpecId, c.project.catalog.pipesFor(PipeUsage.zone).last.id);
    await tool(ToolId.mainPipe);
    await pick(tester, t('props.pipe'), null);
    expect(s.mainPipeSpecId, isNull);
    await tool(ToolId.pivot);
    await pick(tester, t('props.pivotKind'), PivotKind.linear.name);
    expect(field(t('props.pivotTravel')), findsOneWidget);
    await type(tester, t('props.pivotSpan'), '0');
    expect(s.pivotSpan, 50);
    await tool(ToolId.alignImage);
    expect(find.text(t('msg.alignSelectFirst')), findsOneWidget);
    await toggle(tester, t('align.keepScale'));
    expect(s.alignKeepScale, isTrue);
    await tool(ToolId.contour);
    await toggle(tester, t('props.contourSmooth'));
    expect(s.contourSmooth, isTrue);
    await tool(ToolId.hatch);
    await type(tester, t('props.hatchSpacing'), '0');
    expect(s.hatchSpacing, 1);
    await tool(ToolId.spline);
    await toggle(tester, t('props.splineClosed'));
    expect(s.splineClosed, isTrue);
    await tool(ToolId.dimAngular);
    await type(tester, t('props.dimRadius'), '0');
    expect(s.angularDimRadius, 1);
    await tool(ToolId.controller);
    await type(tester, t('props.stations'), '0');
    expect(s.controllerStations, 1);
    await tool(ToolId.rotate);
    await toggle(tester, t('props.copyOnTransform'));
    expect(s.copyOnTransform, isTrue);
    await tool(ToolId.mirror);
    await toggle(tester, t('props.mirrorKeep'));
    expect(s.mirrorKeepSource, isFalse);
    await tool(ToolId.leader);
    await type(tester, t('props.leaderText'), 'Nota');
    expect(s.leaderText, 'Nota');
    await tool(ToolId.offset);
    await type(tester, t('props.offsetDistance'), '-3');
    expect(s.offsetDistance, 3, reason: 'the side is chosen by the click');
    c.setTool(ToolId.select);
  });

  testWidgets('number fields take thousands separators and decimal commas', (tester) async {
    final c = await pumpShell(tester, example: false);
    final supply = await add(tester, c, WaterSupplyEntity(id: c.project.newId(), position: Pt.zero));
    await type(tester, c.t('props.maxFlow'), '1.234,5');
    expect(c.units.flowFromSi(supply.maxFlow), closeTo(1234.5, 1e-6));
    await type(tester, c.t('props.waterLevel'), 'abc');
    expect(supply.waterLevelOffsetM, 0, reason: 'text that is not a number is refused');
  });

  testWidgets('lateral calculator with a catalogue lacking tapes or emitters', (tester) async {
    final c = await pumpShell(tester, example: false);
    BuildContext ctx() => tester.element(find.byType(AppShell));
    // no tapes: it opens on the emitter lateral
    c.project.catalog.tapes.clear();
    showLateralCalculator(ctx(), c);
    await settle(tester);
    expect(find.text(c.t('props.nozzle')), findsWidgets);
    await tester.tap(find.text(c.t('close')).last);
    await settle(tester);
    // neither tapes nor emitters: a message instead of a broken dialog
    c.project.catalog.outlets.clear();
    showLateralCalculator(ctx(), c);
    await settle(tester);
    expect(find.byType(Dialog), findsNothing);
    expect(c.lastMessage, c.t('msg.lateralNeedsCatalog'));
  });
}
