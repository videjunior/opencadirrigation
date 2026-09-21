import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/canvas/cad_canvas.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/main.dart';

/// Widget tests of the drawing/editing tools, grips, properties panel,
/// layers panel and the new dialogs.
void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<dynamic> pumpShell(WidgetTester tester) async {
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
    c.snap.enabled = false;
    await settle(tester);
    return shell;
  }

  Offset screenOf(WidgetTester tester, ProjectController c, Pt world) {
    final box = tester.renderObject(find.byType(CadCanvas)) as RenderBox;
    final local = c.camera.toScreen(world);
    return box.localToGlobal(local);
  }

  Future<void> clickWorld(WidgetTester tester, ProjectController c, Pt world) async {
    await tester.tapAt(screenOf(tester, c, world));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> dragWorld(WidgetTester tester, ProjectController c, Pt from, Pt to) async {
    final g = await tester.startGesture(screenOf(tester, c, from));
    await tester.pump(const Duration(milliseconds: 50));
    await g.moveTo(screenOf(tester, c, to));
    await tester.pump(const Duration(milliseconds: 50));
    await g.up();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Mouse press at [from] (world), moved by [by] pixels, then released.
  Future<void> mouseDrag(WidgetTester tester, ProjectController c, Pt from, Offset by) async {
    final g = await tester.startGesture(screenOf(tester, c, from), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 50));
    await g.moveBy(by);
    await tester.pump(const Duration(milliseconds: 50));
    await g.up();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('line and polyline tools create entities from canvas clicks', (tester) async {
    final shell = await pumpShell(tester);
    final ProjectController c = shell.c as ProjectController;
    c.camera.center = const Pt(20, 10);
    c.camera.scale = 10;
    await tester.tap(find.byKey(const Key('tool_line')));
    await settle(tester);
    expect(c.activeTool, ToolId.line);
    await clickWorld(tester, c, const Pt(0, 0));
    await clickWorld(tester, c, const Pt(10, 0));
    expect(c.project.entities.whereType<LineEntity>().length, 1);
    final l = c.project.entities.whereType<LineEntity>().single;
    expect(l.a.distanceTo(Pt.zero), lessThan(0.2));
    expect(l.b.distanceTo(const Pt(10, 0)), lessThan(0.2));
    await tester.tap(find.byKey(const Key('tool_polyline')));
    await settle(tester);
    await clickWorld(tester, c, const Pt(0, 5));
    await clickWorld(tester, c, const Pt(10, 5));
    await clickWorld(tester, c, const Pt(10, 15));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(c.project.entities.whereType<PolylineEntity>().single.points.length, 3);
    // arc through three points and symbol
    await tester.tap(find.byKey(const Key('tool_arc')));
    await settle(tester);
    await clickWorld(tester, c, const Pt(20, 0));
    await clickWorld(tester, c, const Pt(25, 5));
    await clickWorld(tester, c, const Pt(30, 0));
    expect(c.project.entities.whereType<ArcEntity>().length, 1);
    await tester.tap(find.byKey(const Key('tool_symbol')));
    await settle(tester);
    await clickWorld(tester, c, const Pt(35, 10));
    expect(c.project.entities.whereType<SymbolEntity>().length, 1);
  });

  testWidgets('select, move by drag, grips and rotate tool', (tester) async {
    final shell = await pumpShell(tester);
    final ProjectController c = shell.c as ProjectController;
    c.camera.center = const Pt(10, 5);
    c.camera.scale = 12;
    c.addEntity(LineEntity(id: 'l', a: Pt.zero, b: const Pt(10, 0)));
    await settle(tester);
    // click selects
    await clickWorld(tester, c, const Pt(5, 0));
    expect(c.selection, {'l'});
    // drag the grip at the end
    await dragWorld(tester, c, const Pt(10, 0), const Pt(10, 4));
    await settle(tester);
    final l = c.project.byId('l') as LineEntity;
    expect(l.b.distanceTo(const Pt(10, 4)), lessThan(0.3));
    // drag the body moves the whole line
    await dragWorld(tester, c, const Pt(5, 2), const Pt(7, 2));
    await settle(tester);
    expect((c.project.byId('l') as LineEntity).a.distanceTo(const Pt(2, 0)), lessThan(0.3));
    // rotate: base, reference, target (90°)
    await tester.tap(find.byKey(const Key('tool_rotate')));
    await settle(tester);
    expect(c.activeTool, ToolId.rotate);
    await clickWorld(tester, c, const Pt(2, 0));
    await clickWorld(tester, c, const Pt(12, 0));
    await clickWorld(tester, c, const Pt(2, 10));
    await settle(tester);
    final r = c.project.byId('l') as LineEntity;
    expect(r.b.x, closeTo(2 - 4, 0.4)); // rotated by 90°: (12,4) → (−2, 10)
    expect(r.b.y, closeTo(10, 0.4));
    // mirror keeps the source
    await tester.tap(find.byKey(const Key('tool_mirror')));
    await settle(tester);
    await clickWorld(tester, c, const Pt(0, -5));
    await clickWorld(tester, c, const Pt(0, 15));
    await settle(tester);
    expect(c.project.entities.whereType<LineEntity>().length, 2);
    // cut pipe tool splits a pipe
    c.addEntity(PipeEntity(id: 'p', points: [const Pt(0, 12), const Pt(20, 12)], scope: HydraulicScope.zone));
    await tester.tap(find.byKey(const Key('tool_cutPipe')));
    await settle(tester);
    await clickWorld(tester, c, const Pt(10, 12));
    await settle(tester);
    expect(c.project.entities.whereType<PipeEntity>().length, 2);
  });

  testWidgets('properties panel edits a pipe and batch-edits laterals', (tester) async {
    final shell = await pumpShell(tester);
    final ProjectController c = shell.c as ProjectController;
    c.addEntity(PipeEntity(id: 'p', points: [Pt.zero, const Pt(10, 0)], scope: HydraulicScope.zone));
    c.select(['p']);
    await settle(tester);
    expect(find.text('Tubo de zona'), findsWidgets);
    final depth = find.widgetWithText(TextField, 'Profundidade (m)');
    expect(depth, findsOneWidget);
    await tester.enterText(depth, '0.8');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect((c.project.byId('p') as PipeEntity).depth, closeTo(0.8, 1e-9));
    for (var i = 0; i < 3; i++) {
      c.addEntity(SpraylineEntity(id: 's$i', points: [Pt(0, 5.0 + i * 4), Pt(20, 5.0 + i * 4)], outletSpecId: 'micro', nozzleId: 'm50', headM: 15, spacing: 4));
    }
    c.select(['s0', 's1', 's2']);
    await settle(tester);
    expect(find.textContaining('3 itens selecionados'), findsOneWidget);
    final head = find.widgetWithText(TextField, 'Pressão nominal (m.c.a.)');
    expect(head, findsOneWidget);
    await tester.enterText(head, '22');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(c.project.entities.whereType<SpraylineEntity>().every((e) => e.headM == 22), isTrue);
  });

  testWidgets('layers panel: lock, current layer, colour, add and delete', (tester) async {
    final shell = await pumpShell(tester);
    final ProjectController c = shell.c as ProjectController;
    await tester.tap(find.text('Camadas'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('layer_lock_DRAWING')));
    await settle(tester);
    expect(c.project.layerNamed(Layers.drawing).locked, isTrue);
    await tester.tap(find.byKey(const Key('layer_lock_DRAWING')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('layer_row_TEXT')));
    await settle(tester);
    expect(c.project.currentLayer, Layers.text);
    await tester.tap(find.byKey(const Key('layer_color_TEXT')));
    await settle(tester);
    await tester.tap(find.byKey(Key('color_${0xFFFF5252.toRadixString(16)}')));
    await settle(tester);
    expect(c.project.layerNamed(Layers.text).color, 0xFFFF5252);
    await tester.tap(find.byKey(const Key('layer_add')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('layer_name')), 'ESTRADAS');
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect(c.project.findLayer('ESTRADAS'), isNotNull);
    await tester.tap(find.byKey(const Key('layer_del_ESTRADAS')));
    await settle(tester);
    expect(c.project.findLayer('ESTRADAS'), isNull);
  });

  testWidgets('array dialog and catalog editor add/remove items', (tester) async {
    final shell = await pumpShell(tester);
    final ProjectController c = shell.c as ProjectController;
    c.addEntity(CircleEntity(id: 'c', center: Pt.zero, radius: 1));
    await settle(tester);
    await tester.tap(find.byType(CadCanvas));
    await tester.pump();
    c.select(['c']);
    await tester.pump();
    for (final ch in 'array'.split('')) {
      await tester.sendKeyEvent(LogicalKeyboardKey.knownLogicalKeys.firstWhere((k) => k.keyLabel.toLowerCase() == ch), character: ch);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(find.byKey(const Key('array_ok')), findsOneWidget);
    await tester.tap(find.byKey(const Key('array_ok')));
    await settle(tester);
    expect(c.project.entities.whereType<CircleEntity>().length, 4);
    // catalog editor
    await tester.tap(find.text('Projeto'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('menu_catalog')));
    await settle(tester);
    final before = c.project.catalog.pipes.length;
    await tester.tap(find.byKey(const Key('cat_add')));
    await settle(tester);
    expect(c.project.catalog.pipes.length, before + 1);
    final added = c.project.catalog.pipes.last;
    await tester.ensureVisible(find.byKey(Key('cat_rm_${added.id}')));
    await tester.tap(find.byKey(Key('cat_rm_${added.id}')));
    await settle(tester);
    await tester.tap(find.text('OK').last);
    await settle(tester);
    expect(c.project.catalog.pipes.length, before);
  });

  testWidgets('recovery dialog restores an autosaved project', (tester) async {
    TutorialController.markDone();
    setPref('lang', 'pt');
    final store = LocalProjectStore()..clearAll();
    final c0 = ProjectController(store: store);
    c0.newProject();
    c0.project.meta.name = 'Perdido';
    c0.addEntity(LineEntity(id: 'l', a: Pt.zero, b: const Pt(3, 0)));
    c0.autosaveNow();
    expect(store.recoverable().length, 1);
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false));
    await settle(tester);
    expect(find.text('Recuperar projeto'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rec_restore')));
    await settle(tester);
    final shell = tester.state(find.byType(AppShell)) as dynamic;
    final ProjectController c = shell.c as ProjectController;
    expect(c.project.meta.name, 'Perdido');
    expect(c.project.entities.length, 1);
    expect(store.recoverable(), isEmpty);
  });

  testWidgets('a click that wobbles a few pixels never moves what it selects', (tester) async {
    final shell = await pumpShell(tester);
    final ProjectController c = shell.c as ProjectController;
    c.camera.center = const Pt(10, 0);
    c.camera.scale = 12;
    c.snap.enabled = true;
    c.addEntity(PipeEntity(id: 'p', points: [Pt.zero, const Pt(20, 0)], scope: HydraulicScope.zone));
    c.addEntity(OutletEntity(id: 'o', position: const Pt(5, 0), outletSpecId: 'micro'));
    await settle(tester);
    final history = c.historyIndex;
    // press on the sprinkler and wobble inside the dead zone
    await mouseDrag(tester, c, const Pt(5, 0), const Offset(3, -2));
    await settle(tester);
    expect(c.selection, {'o'});
    expect((c.project.byId('o') as OutletEntity).position, const Pt(5, 0));
    // it is selected now: pressing its grip and wobbling must not move it either
    await mouseDrag(tester, c, const Pt(5.6, 0), const Offset(-2, 3));
    await settle(tester);
    expect((c.project.byId('o') as OutletEntity).position, const Pt(5, 0));
    expect(c.historyIndex, history, reason: 'a click alone must not push an undo step');
    // past the dead zone it does move, and lands on the pipe under it
    await mouseDrag(tester, c, const Pt(4.4, 0), const Offset(60, 5));
    await settle(tester);
    final moved = (c.project.byId('o') as OutletEntity).position;
    expect(moved.x, greaterThan(8));
    expect(moved.y.abs(), lessThan(0.01));
  });

  testWidgets('dragging an item snaps the item onto the pipe, not the cursor', (tester) async {
    final shell = await pumpShell(tester);
    final ProjectController c = shell.c as ProjectController;
    c.camera.center = const Pt(10, 0);
    c.camera.scale = 12;
    c.snap.enabled = true;
    c.addEntity(PipeEntity(id: 'p', points: [Pt.zero, const Pt(20, 0)], scope: HydraulicScope.zone));
    c.addEntity(OutletEntity(id: 'o', position: const Pt(5, 0), outletSpecId: 'micro'));
    await settle(tester);
    // grabbed off-centre (0.3 m up and to the right) and dropped above the pipe
    await dragWorld(tester, c, const Pt(5.3, 0.3), const Pt(12.3, 0.6));
    await settle(tester);
    final p = (c.project.byId('o') as OutletEntity).position;
    expect(p.y.abs(), lessThan(c.project.params.connectTolerance), reason: 'the sprinkler left the pipe: $p');
    expect((p.x - 12).abs(), lessThan(0.4));
  });

  testWidgets('dragging a pipe node takes the joined pipe and item with it', (tester) async {
    final shell = await pumpShell(tester);
    final ProjectController c = shell.c as ProjectController;
    c.camera.center = const Pt(8, 4);
    c.camera.scale = 12;
    c.addEntity(PipeEntity(id: 'a', points: [Pt.zero, const Pt(10, 0)], scope: HydraulicScope.zone));
    c.addEntity(PipeEntity(id: 'b', points: [const Pt(10, 0), const Pt(10, 10)], scope: HydraulicScope.zone));
    c.addEntity(ControlValveEntity(id: 'v', position: const Pt(10, 0), valveSpecId: 'ev50'));
    expect(c.toolSettings.keepConnections, isTrue);
    await settle(tester);
    await clickWorld(tester, c, const Pt(5, 0)); // selects pipe a
    expect(c.selection, {'a'});
    await dragWorld(tester, c, const Pt(10, 0), const Pt(13, 3));
    await settle(tester);
    final a = (c.project.byId('a') as PipeEntity).points;
    final b = (c.project.byId('b') as PipeEntity).points;
    expect(a.last.distanceTo(const Pt(13, 3)), lessThan(0.3));
    expect(b.first.distanceTo(a.last), lessThan(1e-9), reason: 'the junction broke');
    expect((c.project.byId('v') as ControlValveEntity).position.distanceTo(a.last), lessThan(1e-9));
    // switched off, the same drag detaches the other pipe
    c.undo();
    c.toolSettings.keepConnections = false;
    await settle(tester);
    await clickWorld(tester, c, const Pt(5, 0));
    await dragWorld(tester, c, const Pt(10, 0), const Pt(13, 3));
    await settle(tester);
    expect((c.project.byId('b') as PipeEntity).points.first.distanceTo(const Pt(10, 0)), lessThan(1e-9));
  });

  testWidgets('clicking a midpoint grip does not add a vertex, dragging it does', (tester) async {
    final shell = await pumpShell(tester);
    final ProjectController c = shell.c as ProjectController;
    c.camera.center = const Pt(5, 0);
    c.camera.scale = 12;
    c.addEntity(PipeEntity(id: 'p', points: [Pt.zero, const Pt(10, 0)], scope: HydraulicScope.zone));
    await settle(tester);
    await clickWorld(tester, c, const Pt(5, 0));
    expect(c.selection, {'p'});
    await mouseDrag(tester, c, const Pt(5.7, 0), const Offset(2, 2));
    await settle(tester);
    expect((c.project.byId('p') as PipeEntity).points.length, 2);
    await mouseDrag(tester, c, const Pt(4.3, 0), const Offset(0, -40));
    await settle(tester);
    final pts = (c.project.byId('p') as PipeEntity).points;
    expect(pts.length, 3);
    expect(pts[1].y, greaterThan(2));
  });
}
