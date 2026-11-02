import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/main.dart';

/// The editing functions of 1.6.0 in the running app: coordinates typed in
/// the properties panel, the menus that start the new tools.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 3]) async {
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
    c.newProject();
    c.snap.enabled = false;
    await settle(tester);
    return c;
  }

  Future<void> type(WidgetTester tester, Key key, String value) async {
    final f = find.descendant(of: find.byKey(key), matching: find.byType(TextField));
    expect(f, findsOneWidget, reason: '$key');
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(f, value);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 2);
  }

  testWidgets('the properties panel edits X and Y of a point item, the ends of a line and the vertices of a pipe (CAD-06)', (tester) async {
    final c = await pumpShell(tester);
    final j = JunctionEntity(id: c.project.newId(), position: const Pt(1, 2));
    c.addEntity(j);
    c.select([j.id]);
    await settle(tester);
    expect(find.byKey(Key('xy_${j.id}_0_x')), findsOneWidget);
    await type(tester, Key('xy_${j.id}_0_x'), '12.5');
    await type(tester, Key('xy_${j.id}_0_y'), '-3');
    expect((c.project.byId(j.id) as JunctionEntity).position, const Pt(12.5, -3));
    // the ends of a line
    final l = LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(10, 0));
    c.addEntity(l);
    c.select([l.id]);
    await settle(tester);
    await type(tester, Key('xy_${l.id}_1_y'), '7');
    expect((c.project.byId(l.id) as LineEntity).b, const Pt(10, 7));
    // a vertex of a pipe drags the item joined there along (keep connections)
    final p = PipeEntity(id: c.project.newId(), points: [Pt.zero, const Pt(20, 0), const Pt(20, 20)], scope: HydraulicScope.zone);
    final v = OutletEntity(id: c.project.newId(), position: const Pt(20, 20), outletSpecId: 'micro');
    c.addEntities([p, v]);
    c.select([p.id]);
    await settle(tester);
    expect(find.byKey(Key('xy_${p.id}_2_x')), findsOneWidget);
    await type(tester, Key('xy_${p.id}_2_x'), '25');
    expect((c.project.byId(p.id) as PipeEntity).points.last, const Pt(25, 20));
    expect((c.project.byId(v.id) as OutletEntity).position, const Pt(25, 20), reason: 'the outlet at the vertex goes along');
    final steps = c.historyEntries.length;
    c.undo();
    expect(c.historyEntries.where((h) => !h.future).length, steps - 1);
    expect((c.project.byId(p.id) as PipeEntity).points.last, const Pt(20, 20), reason: 'one undo step');
  });

  testWidgets('a number typed after the base and reference points of Rotate is the angle (CAD-09)', (tester) async {
    final c = await pumpShell(tester);
    final dynamic shell = tester.state(find.byType(AppShell));
    final l = LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(10, 0));
    c.addEntity(l);
    c.select([l.id]);
    c.setTool(ToolId.rotate);
    await settle(tester, 1);
    c.keyTarget!.feedPoint(Pt.zero);
    c.keyTarget!.feedPoint(const Pt(10, 0));
    shell.typeCommand('45');
    await settle(tester, 1);
    final b = (c.project.byId(l.id) as LineEntity).b;
    expect(b.x, closeTo(7.0710678, 1e-6));
    expect(b.y, closeTo(7.0710678, 1e-6));
  });

  testWidgets('typing a letter that is an alias keeps the polyline in progress; C closes it (CAD-10)', (tester) async {
    final c = await pumpShell(tester);
    final dynamic shell = tester.state(find.byType(AppShell));
    c.setTool(ToolId.polyline);
    await settle(tester, 1);
    for (final p in [Pt.zero, const Pt(10, 0), const Pt(10, 10)]) {
      c.keyTarget!.feedPoint(p);
    }
    shell.typeCommand('L');
    await settle(tester, 1);
    expect(c.activeTool, ToolId.line);
    expect(c.project.entities.whereType<PolylineEntity>().single.points, [Pt.zero, const Pt(10, 0), const Pt(10, 10)]);
    // the C option of the polyline wins over the circle alias
    c.setTool(ToolId.polyline);
    await settle(tester, 1);
    for (final p in [const Pt(0, 50), const Pt(10, 50), const Pt(10, 60)]) {
      c.keyTarget!.feedPoint(p);
    }
    shell.typeCommand('C');
    await settle(tester, 1);
    expect(c.activeTool, ToolId.polyline);
    expect(c.project.entities.whereType<PolylineEntity>().last.closed, isTrue);
  });

  testWidgets('quick select from the Edit menu: a kind, the count of matches, the selection (CAD-25)', (tester) async {
    final c = await pumpShell(tester);
    c.addEntities([
      PipeEntity(id: 'p1', points: [Pt.zero, const Pt(10, 0)], scope: HydraulicScope.zone),
      PipeEntity(id: 'p2', points: [const Pt(0, 5), const Pt(10, 5)], scope: HydraulicScope.zone),
      LineEntity(id: 'l1', a: const Pt(0, 9), b: const Pt(10, 9)),
    ]);
    await settle(tester);
    await tester.tap(find.text('Edit'));
    await settle(tester, 2);
    await tester.tap(find.text(c.t('sel.menu')));
    await settle(tester, 2);
    await tester.tap(find.text(c.t('sel.quick')));
    await settle(tester, 2);
    expect(find.text(c.t('qs.title')), findsOneWidget);
    expect(find.text(c.t('qs.matches', {'n': '3'})), findsOneWidget);
    await tester.tap(find.byKey(const Key('qs_kind')));
    await settle(tester, 2);
    await tester.tap(find.text('${c.t('tool.zonePipe')} (2)').last);
    await settle(tester, 2);
    expect(find.text(c.t('qs.matches', {'n': '2'})), findsOneWidget);
    await tester.tap(find.byKey(const Key('qs_apply')));
    await settle(tester, 2);
    expect(c.selection, {'p1', 'p2'});
    // the layers panel selects the items of a layer
    c.select(const []);
    final dynamic shell = tester.state(find.byType(AppShell));
    shell.showSideTab(1);
    await settle(tester, 2);
    await tester.tap(find.byKey(Key('layer_select_${Layers.drawing}')));
    // (the row also takes double taps: the tap is decided after their timeout)
    await settle(tester, 2);
    expect(c.selection, {'l1'});
  });

  testWidgets('Edit → Geometry joins the selection and starts the fillet tool (CAD-26)', (tester) async {
    final c = await pumpShell(tester);
    c.addEntities([LineEntity(id: 'a', a: Pt.zero, b: const Pt(10, 0)), LineEntity(id: 'b', a: const Pt(10, 0), b: const Pt(10, 10))]);
    c.selectAll();
    await settle(tester);
    await tester.tap(find.text('Edit'));
    await settle(tester, 2);
    await tester.tap(find.text(c.t('edt.geometry')));
    await settle(tester, 2);
    await tester.tap(find.text(c.t('edt.join')));
    await settle(tester, 2);
    expect(c.project.entities.single, isA<PolylineEntity>());
    expect(c.historyEntries.where((h) => h.current).single.label, 'hist.join|2');
    await tester.tap(find.text('Edit'));
    await settle(tester, 2);
    await tester.tap(find.text(c.t('edt.geometry')));
    await settle(tester, 2);
    await tester.tap(find.text(c.t('tool.fillet')));
    await settle(tester, 2);
    expect(c.activeTool, ToolId.fillet);
    expect(find.byKey(const Key('tool_fillet_radius')), findsNothing, reason: 'the selection shows its properties');
    c.select(const []);
    await settle(tester, 2);
    expect(find.byKey(const Key('tool_fillet_radius')), findsOneWidget, reason: 'the radius in the panel of the tool');
  });

  testWidgets('Edit → Move and Copy start the tools (CAD-06)', (tester) async {
    final c = await pumpShell(tester);
    await tester.tap(find.text('Edit'));
    await settle(tester, 2);
    await tester.tap(find.text(c.t('tool.move')).last);
    await settle(tester, 2);
    expect(c.activeTool, ToolId.move);
    await tester.tap(find.text('Edit'));
    await settle(tester, 2);
    await tester.tap(find.text(c.t('tool.copy')).last);
    await settle(tester, 2);
    expect(c.activeTool, ToolId.copy);
  });
}
