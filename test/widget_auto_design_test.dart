import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/canvas/cad_canvas.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/dialogs/auto_design_dialogs.dart';
import 'package:opencadirrigation/core/design/auto_layout.dart';
import 'package:opencadirrigation/core/design/pivot_fit.dart';
import 'package:opencadirrigation/core/design/templates.dart';
import 'package:opencadirrigation/core/design/tree_rings.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/units.dart';
import 'package:opencadirrigation/main.dart';

List<Pt> _rect(double x0, double y0, double x1, double y1) => [Pt(x0, y0), Pt(x1, y0), Pt(x1, y1), Pt(x0, y1)];

/// The automatic design dialogs: each one opened on a selection, its live
/// summary, the entities it generates and the single undo step that takes
/// them all back.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<ProjectController> pumpShell(WidgetTester tester, {Size size = const Size(1920, 1080)}) async {
    TutorialController.markDone();
    setPref('lang', 'pt');
    LocalProjectStore().clearAll();
    tester.view.physicalSize = size;
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
    c.newProject();
    await settle(tester);
    return c;
  }

  BuildContext ctxOf(WidgetTester tester) => tester.element(find.byType(CadCanvas));

  /// Adds [es] to the drawing and selects those of [selected] (all by default).
  Future<void> place(WidgetTester tester, ProjectController c, List<Entity> es, {List<Entity>? selected}) async {
    c.addEntities(es);
    c.select((selected ?? es).map((e) => e.id));
    await settle(tester);
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(Key(key));
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle(tester);
  }

  /// Types [value] into the text field of the widget keyed [key] and commits it.
  Future<void> typeInto(WidgetTester tester, String key, String value) async {
    final f = find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(f, value);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 2);
  }

  /// Every entity added since [before] is gone after one undo.
  Future<void> undoRemovesAll(WidgetTester tester, ProjectController c, int before, int step) async {
    expect(c.historyIndex, step + 1, reason: 'one undo step');
    c.undo();
    await settle(tester);
    expect(c.project.entities, hasLength(before));
    expect(c.historyIndex, step);
  }

  testWidgets('every tool says what to select when the selection holds nothing it can use', (tester) async {
    final c = await pumpShell(tester);
    for (final (open, text) in [
      (showAutoLayoutDialog, 'Selecione o contorno fechado da área'),
      (showFieldSubdivisionDialog, 'Selecione o contorno fechado do talhão'),
      (showTreeRingsDialog, 'Selecione o contorno fechado do pomar'),
      (showPivotFitDialog, 'Selecione o contorno fechado do talhão'),
    ]) {
      open(ctxOf(tester), c);
      await settle(tester);
      expect(find.textContaining(text), findsOneWidget);
      await tester.tap(find.text('Fechar'));
      await settle(tester);
    }
    // the templates need no selection: they go to the centre of the view
    showTemplateDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.textContaining('centro da vista'), findsOneWidget);
    expect(find.byKey(const Key('tpl_generate')), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await settle(tester);
    expect(showAutoDesignDialog(ctxOf(tester), c, 'nothing'), isNull);
  });

  testWidgets('automatic layout: a lawn round a house, zoned by flow and routed from the supply in one undo step', (tester) async {
    final c = await pumpShell(tester);
    final p = c.project;
    final lawn = AreaEntity(id: p.newId(), points: _rect(0, 0, 40, 30), name: 'Gramado');
    final house = PolylineEntity(id: p.newId(), points: _rect(12, 10, 26, 20), closed: true);
    final supply = WaterSupplyEntity(id: p.newId(), position: const Pt(-8, -6), calculatePressure: false, designHeadM: 45, designFlow: 3 * m3sPerM3h);
    await place(tester, c, [lawn, house, supply], selected: [lawn, house]);
    final before = c.project.entities.length, step = c.historyIndex;
    showAutoLayoutDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.text('Layout automático de aspersores'), findsOneWidget);
    // the live summary of the default layout (rotors head to head)
    final expected = layoutLandscape(outline: lawn.points, exclusions: [house.points], family: p.catalog.outlet('rotor')!);
    expect(find.textContaining('${expected.heads.length} ('), findsOneWidget);
    expect(find.text('CU (Christiansen)'), findsOneWidget);
    expect(find.text('${fmtLocale(expected.metrics!.cu, 1, 'pt')} %'), findsOneWidget);
    await tapKey(tester, 'al_zoning');
    // the largest zone flow defaults to the supply's 3 m³/h (3000 L/h)
    expect(find.textContaining('3000'), findsWidgets);
    await tapKey(tester, 'al_routing');
    expect(find.text('Cruzamentos de tubos sem junção'), findsOneWidget);
    await tapKey(tester, 'al_generate');
    expect(find.text('Layout automático de aspersores'), findsNothing, reason: 'closed after generating');
    final outlets = c.project.entities.whereType<OutletEntity>().toList();
    final valves = c.project.entities.whereType<ControlValveEntity>().toList();
    final pipes = c.project.entities.whereType<PipeEntity>().toList();
    expect(outlets, hasLength(expected.heads.length));
    expect(outlets.every((o) => o.outletSpecId == 'rotor' && o.zoneName.isNotEmpty), isTrue);
    expect(outlets.any((o) => pointInPolygon(o.position, house.points) && !pointOnPolygonBoundary(o.position, house.points)), isFalse);
    // every zone draws at most the supply's flow and has its valve
    expect(valves.length, greaterThan(1));
    expect(valves.map((v) => v.zoneName).toSet(), outlets.map((o) => o.zoneName).toSet());
    expect(valves.every((v) => v.valveSpecId == 'ev25'), isTrue);
    for (final v in valves) {
      final heads = outlets.where((o) => o.zoneName == v.zoneName);
      final q = heads.fold(0.0, (s, o) => s + p.catalog.outlet(o.outletSpecId)!.nozzle(o.nozzleId)!.curve.flow(o.headM));
      expect(q, lessThanOrEqualTo(3 * m3sPerM3h * (1 + 1e-9)), reason: v.zoneName);
    }
    expect(pipes.where((e) => e.scope == HydraulicScope.zone), isNotEmpty);
    expect(pipes.where((e) => e.scope == HydraulicScope.mainline), isNotEmpty);
    expect(pipes.every((e) => e.computerSized && e.pipeSpecId == null), isTrue);
    expect(c.selection, hasLength(c.project.entities.length - before));
    await undoRemovesAll(tester, c, before, step);
  });

  testWidgets('automatic layout: the family is chosen in the dialog and its messages are translated', (tester) async {
    final c = await pumpShell(tester);
    final lawn = PolylineEntity(id: c.project.newId(), points: _rect(0, 0, 80, 60), closed: true);
    await place(tester, c, [lawn]);
    final before = c.project.entities.length, step = c.historyIndex;
    showAutoLayoutDialog(ctxOf(tester), c);
    await settle(tester);
    await tester.tap(find.byKey(const Key('al_family')));
    await settle(tester);
    await tester.tap(find.text('Aspersor de impacto 3/4"').last);
    await settle(tester);
    // impact sprinklers have no matched part circles: full circles inset from the edges
    expect(find.textContaining('Família sem bocais de setor equilibrados'), findsOneWidget);
    await tapKey(tester, 'al_generate');
    final outlets = c.project.entities.whereType<OutletEntity>().toList();
    expect(outlets, isNotEmpty);
    expect(outlets.every((o) => o.outletSpecId == 'impact34' && o.arcDeg == 360 && o.zoneName.isEmpty), isTrue);
    expect(c.project.entities.whereType<ControlValveEntity>(), isEmpty, reason: 'not routed');
    await undoRemovesAll(tester, c, before, step);
  });

  testWidgets('templates: a football pitch at the centre of the view, heads and turf area in one undo step', (tester) async {
    final c = await pumpShell(tester);
    final before = c.project.entities.length, step = c.historyIndex;
    final centre = c.camera.center;
    showTemplateDialog(ctxOf(tester), c);
    await settle(tester);
    final rotor = c.project.catalog.outlet('rotor')!;
    final expected = sportsPitchLayout(family: rotor, rows: 0, origin: centre - const Pt(52.5, 34));
    expect(find.textContaining('${expected.heads.length} ('), findsOneWidget);
    await tapKey(tester, 'tpl_generate');
    final outlets = c.project.entities.whereType<OutletEntity>().toList();
    expect(outlets, hasLength(expected.heads.length));
    for (var i = 0; i < outlets.length; i++) {
      expect(outlets[i].position.distanceTo(expected.heads[i].position), lessThan(1e-6));
      expect(outlets[i].nozzleId, expected.heads[i].nozzleId);
    }
    final area = c.project.entities.whereType<AreaEntity>().single;
    expect(area.name, 'Campo de futebol');
    expect(area.area, closeTo(105 * 68, 1e-6));
    expect(polygonCentroid(area.points).distanceTo(centre), lessThan(1e-6));
    await undoRemovesAll(tester, c, before, step);
  });

  testWidgets('templates: a green ringed round the selected outline, no second area', (tester) async {
    final c = await pumpShell(tester);
    final green = AreaEntity(id: c.project.newId(), points: ellipseOutline(const Pt(50, 40), 30, 22, rotationDeg: 20), name: 'Green 1');
    await place(tester, c, [green]);
    final before = c.project.entities.length, step = c.historyIndex;
    showTemplateDialog(ctxOf(tester), c);
    await settle(tester);
    await tester.tap(find.byKey(const Key('tpl_kind')));
    await settle(tester);
    await tester.tap(find.text('Green de golfe').last);
    await settle(tester);
    await tapKey(tester, 'tpl_generate');
    final outlets = c.project.entities.whereType<OutletEntity>().toList();
    expect(outlets.length, greaterThanOrEqualTo(4));
    // part circles outside the green, every one opening onto it
    for (final o in outlets) {
      expect(pointInPolygon(o.position, green.points), isFalse);
      expect(o.arcDeg, lessThan(360));
    }
    expect(c.project.entities.whereType<AreaEntity>(), hasLength(1), reason: 'the green is an irrigated area already');
    await undoRemovesAll(tester, c, before, step);
  });

  testWidgets('field subdivision: blocks of drip tape with their valves and a mainline, in one undo step', (tester) async {
    final c = await pumpShell(tester);
    final field = PolylineEntity(id: c.project.newId(), points: _rect(0, 0, 200, 120), closed: true);
    final supply = WaterSupplyEntity(id: c.project.newId(), position: const Pt(-20, 60), calculatePressure: false, designHeadM: 30);
    await place(tester, c, [field, supply], selected: [field]);
    final before = c.project.entities.length, step = c.historyIndex;
    showFieldSubdivisionDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.text('Divisão do talhão em blocos'), findsOneWidget);
    // 2.4 ha in blocks of at most 0.5 ha: five strips
    await typeInto(tester, 'fs_max_area', '0,5');
    expect(find.text('5'), findsWidgets);
    await tapKey(tester, 'fs_mainline');
    await tapKey(tester, 'fs_generate');
    final valves = c.project.entities.whereType<ControlValveEntity>().toList();
    expect(valves, hasLength(5));
    expect(valves.map((v) => v.zoneName), ['Bloco 1', 'Bloco 2', 'Bloco 3', 'Bloco 4', 'Bloco 5']);
    expect(valves.every((v) => v.valveSpecId != null), isTrue);
    final tapes = c.project.entities.whereType<TapeEntity>().toList();
    expect(tapes, isNotEmpty);
    expect(tapes.every((e) => e.tapeSpecId == c.toolSettings.tapeSpecId), isTrue);
    // laterals along the 200 m edge, inside the field
    for (final e in tapes) {
      expect((e.points.last - e.points.first).normalized.dot(const Pt(1, 0)).abs(), closeTo(1, 1e-9));
      expect(pointInPolygon(Pt.lerp(e.points.first, e.points.last, 0.5), field.points), isTrue);
    }
    final pipes = c.project.entities.whereType<PipeEntity>().toList();
    expect(pipes.where((e) => e.scope == HydraulicScope.zone).length, greaterThanOrEqualTo(10), reason: 'a submain and a stub per block');
    final mains = pipes.where((e) => e.scope == HydraulicScope.mainline).toList();
    expect(mains, isNotEmpty);
    // the mainline reaches every valve
    for (final v in valves) {
      expect(mains.any((m) => m.points.any((q) => q.distanceTo(v.position) < 1e-6)), isTrue, reason: v.zoneName);
    }
    await undoRemovesAll(tester, c, before, step);
  });

  testWidgets('tree rings: an orchard block of dripline rings, laterals and its valve in one undo step', (tester) async {
    final c = await pumpShell(tester);
    final orchard = AreaEntity(id: c.project.newId(), points: _rect(0, 0, 42, 28), name: 'Pomar');
    await place(tester, c, [orchard]);
    final before = c.project.entities.length, step = c.historyIndex;
    showTreeRingsDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.text('Anéis de gotejamento ao redor das árvores'), findsOneWidget);
    expect(find.text('28'), findsOneWidget, reason: '4 rows of 7 trees (6 × 7 m)');
    await tapKey(tester, 'tr_generate');
    final valve = c.project.entities.whereType<ControlValveEntity>().single;
    expect(valve.zoneName, 'Zona 1');
    expect(valve.valveSpecId, isNotNull);
    final rings = c.project.entities.whereType<TapeEntity>().toList();
    expect(rings, hasLength(2 * 28));
    expect(rings.every((r) => r.tapeSpecId == c.toolSettings.tapeSpecId), isTrue);
    expect(c.project.entities.whereType<PipeEntity>().length, 4 + 2, reason: 'a lateral per row, the submain and the stub');
    await undoRemovesAll(tester, c, before, step);
  });

  testWidgets('tree rings: a spacing far too small for the area is refused, not generated', (tester) async {
    final c = await pumpShell(tester);
    final orchard = AreaEntity(id: c.project.newId(), points: _rect(0, 0, 300, 200));
    await place(tester, c, [orchard]);
    final step = c.historyIndex;
    showTreeRingsDialog(ctxOf(tester), c);
    await settle(tester);
    final trees = layoutTreeRings(area: orchard.points, options: TreeRingOptions(plantSpacing: 6, rowSpacing: 7, ringRadius: 0.75)).trees.length;
    expect(find.text('$trees'), findsOneWidget, reason: '300 × 200 m at 6 × 7 m');
    // typed 0.05 m: taken as the least spacing, still far too many trees
    await typeInto(tester, 'tr_plant', '0,05');
    await typeInto(tester, 'tr_row', '0,05');
    expect(find.textContaining('mais de 20000 itens'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('tr_generate'))).onPressed, isNull);
    await tester.tap(find.text('Cancelar'));
    await settle(tester);
    expect(c.historyIndex, step);
  });

  testWidgets('tree rings: surveyed trees get drippers on a ring', (tester) async {
    final c = await pumpShell(tester);
    // two rows of three trees, 6 m apart along rows that run at 30°
    final trees = [
      for (var r = 0; r < 2; r++)
        for (var k = 0; k < 3; k++) SymbolEntity(id: c.project.newId(), position: Pt(k * 6.0, r * 7.0).rotate(degToRad(30))),
    ];
    await place(tester, c, trees);
    final before = c.project.entities.length, step = c.historyIndex;
    showTreeRingsDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.textContaining('6 árvores selecionadas'), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const Key('tr_direction')), matching: find.text('30,0')),
      findsOneWidget,
      reason: 'the row direction of the survey',
    );
    await tester.tap(find.text('Gotejadores num anel'));
    await settle(tester);
    await tapKey(tester, 'tr_generate');
    final drippers = c.project.entities.whereType<OutletEntity>().toList();
    expect(drippers, hasLength(6 * 4));
    expect(drippers.every((d) => d.outletSpecId == 'drip_pc' && d.zoneName == 'Zona 1'), isTrue);
    for (final d in drippers) {
      expect(trees.map((t) => t.position.distanceTo(d.position)).reduce((a, b) => a < b ? a : b), closeTo(0.75, 1e-9));
    }
    // a lateral per row, the submain, the stub and two ring pipes per tree
    expect(c.project.entities.whereType<PipeEntity>(), hasLength(2 + 1 + 1 + 2 * 6));
    await undoRemovesAll(tester, c, before, step);
  });

  testWidgets('pivot fit: the largest full circle clear of a power pole, as one undo step', (tester) async {
    final c = await pumpShell(tester);
    final field = PolylineEntity(id: c.project.newId(), points: _rect(0, 0, 900, 650), closed: true);
    final pole = SymbolEntity(id: c.project.newId(), position: const Pt(200, 300), kind: SymbolKind.well);
    await place(tester, c, [field, pole]);
    final before = c.project.entities.length, step = c.historyIndex;
    showPivotFitDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.text('Pivô ajustado ao talhão'), findsOneWidget);
    final expected = fitFullCirclePivot(field.points, PivotFitOptions(pointObstacles: const [PointObstacle(Pt(200, 300), 10)], endThrowM: 5));
    expect(find.text('${fmtLocale(expected.coverage * 100, 1, 'pt')} %'), findsOneWidget);
    await tapKey(tester, 'pf_generate');
    final pivot = c.project.entities.whereType<PivotEntity>().single;
    expect(pivot.center.distanceTo(expected.center), lessThan(1e-6));
    expect(pivot.radiusM, closeTo(expected.machineLength, 1e-9));
    expect(pivot.sectorDeg, 360);
    expect(pivot.endThrowM, 5);
    expect(pivot.center.distanceTo(pole.position), greaterThanOrEqualTo(pivot.irrigatedRadius + 10 - 1));
    expect(pivot.grossDepthMm, c.toolSettings.pivotDepthMm);
    expect(c.selection, {pivot.id});
    await undoRemovesAll(tester, c, before, step);
    // a machine of one span length typed with a decimal comma, no overhang
    c.select([field.id]);
    showPivotFitDialog(ctxOf(tester), c);
    await settle(tester);
    await typeInto(tester, 'pf_spans', '48,8');
    await typeInto(tester, 'pf_overhangs', '0');
    // the list as it was read, in the notation of the language (UI-08): one
    // length with a decimal comma, not the two lengths "48; 8"
    expect(find.text('48,8'), findsOneWidget, reason: 'the list as it was read');
    await tapKey(tester, 'pf_generate');
    final typed = c.project.entities.whereType<PivotEntity>().single;
    final fit = fitFullCirclePivot(field.points, PivotFitOptions(spanLengths: const [48.8], overhangs: const [0], endThrowM: 5));
    expect(typed.spanLengthM, 48.8);
    expect(typed.radiusM, closeTo(fit.machineLength, 1e-9));
    expect(typed.radiusM / 48.8, closeTo((typed.radiusM / 48.8).roundToDouble(), 1e-9));
  });

  testWidgets('every dialog lays out on a phone and on a small window', (tester) async {
    for (final size in const [Size(390, 844), Size(820, 640)]) {
      final c = await pumpShell(tester, size: size);
      final p = c.project;
      final lawn = AreaEntity(id: p.newId(), points: _rect(0, 0, 40, 30));
      final bed = PolylineEntity(id: p.newId(), points: _rect(12, 10, 20, 16), closed: true);
      final line = PolylineEntity(id: p.newId(), points: const [Pt(0, 40), Pt(150, 60)]);
      final tree = SymbolEntity(id: p.newId(), position: const Pt(30, 40));
      final supply = WaterSupplyEntity(id: p.newId(), position: const Pt(-5, -5));
      await place(tester, c, [lawn, bed, line, tree, supply], selected: [lawn, bed, line]);
      for (final (open, key) in [
        (showAutoLayoutDialog, 'al_generate'),
        (showTemplateDialog, 'tpl_generate'),
        (showFieldSubdivisionDialog, 'fs_generate'),
        (showTreeRingsDialog, 'tr_generate'),
        (showPivotFitDialog, 'pf_generate'),
      ]) {
        open(ctxOf(tester), c);
        await settle(tester);
        expect(find.byKey(Key(key)), findsOneWidget, reason: '$key at $size');
        if (key == 'al_generate') {
          await tapKey(tester, 'al_zoning');
          await tapKey(tester, 'al_routing');
          await tapKey(tester, 'al_advanced');
        }
        await tester.tap(find.text('Cancelar'));
        await settle(tester);
        expect(find.byKey(Key(key)), findsNothing);
      }
    }
  });

  testWidgets('pivot fit: a sector of an L-shaped field', (tester) async {
    final c = await pumpShell(tester);
    final field = PolylineEntity(id: c.project.newId(), points: const [Pt(0, 0), Pt(800, 0), Pt(800, 300), Pt(300, 300), Pt(300, 800), Pt(0, 800)], closed: true);
    await place(tester, c, [field]);
    final step = c.historyIndex;
    showPivotFitDialog(ctxOf(tester), c);
    await settle(tester);
    await tester.tap(find.text('Setor (a maior área)'));
    await settle(tester);
    await tapKey(tester, 'pf_generate');
    final pivot = c.project.entities.whereType<PivotEntity>().single;
    expect(pivot.sectorDeg, greaterThan(180));
    expect(pivot.sectorDeg, lessThan(360));
    for (final q in pivot.outline()) {
      expect(pointInPolygon(q, field.points) || pointOnPolygonBoundary(q, field.points, tol: 1e-3), isTrue, reason: '$q');
    }
    expect(c.historyIndex, step + 1);
  });
}
