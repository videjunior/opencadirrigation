import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/canvas/cad_canvas.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tools/edit_commands.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/main.dart';

/// Touch and pen on the drawing (CAD-17, CAD-34): several items selected
/// without Shift, a selection window from a held finger, the menu of a
/// held finger and of the right button, the pen's side button, the double
/// tap of a finger.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 3]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<ProjectController> pumpShell(WidgetTester tester, {Size size = const Size(1920, 1080)}) async {
    TutorialController.markDone();
    setPref('lang', 'en');
    LocalProjectStore().clearAll();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false));
    await settle(tester);
    final dynamic shell = tester.state(find.byType(AppShell));
    final ProjectController c = shell.c as ProjectController;
    c.autosaveEnabled = false;
    c.newProject();
    c.snap.enabled = false;
    c.camera.center = const Pt(20, 0);
    c.camera.scale = 10;
    await settle(tester);
    return c;
  }

  RenderBox canvasBox(WidgetTester tester) => tester.renderObject(find.byType(CadCanvas)) as RenderBox;
  Offset global(WidgetTester tester, ProjectController c, Pt world) => canvasBox(tester).localToGlobal(c.camera.toScreen(world));

  Future<void> tap(WidgetTester tester, ProjectController c, Pt at) async {
    final g = await tester.startGesture(global(tester, c, at), kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 50));
    await g.up();
    await tester.pump(const Duration(milliseconds: 400));
  }

  List<JunctionEntity> addItems(ProjectController c) {
    final items = [for (var i = 0; i < 3; i++) JunctionEntity(id: c.project.newId(), position: Pt(10.0 * i, 0))];
    c.addEntities(items);
    return items;
  }

  testWidgets('with "add to selection" each tap adds an item and a tap on a selected one takes it out (CAD-17)', (tester) async {
    final c = await pumpShell(tester);
    final items = addItems(c);
    await settle(tester, 1);
    await tap(tester, c, items[0].position);
    await tap(tester, c, items[1].position);
    expect(c.selection, {items[1].id}, reason: 'without the mode a tap replaces the selection');
    c.setAddToSelection(true);
    await tap(tester, c, items[0].position);
    await tap(tester, c, items[2].position);
    expect(c.selection, {for (final e in items) e.id});
    await tap(tester, c, items[1].position);
    expect(c.selection, {items[0].id, items[2].id});
    // the cutting edges of Trim are picked the same way
    c.select(const []);
    c.addEntity(LineEntity(id: 'edge', a: const Pt(-5, 20), b: const Pt(25, 20)));
    c.setTool(ToolId.trim);
    await settle(tester, 1);
    await tap(tester, c, const Pt(5, 20));
    expect(c.selection, {'edge'});
  });

  testWidgets('a finger held still then dragged draws a selection window; a plain drag pans (CAD-17)', (tester) async {
    final c = await pumpShell(tester);
    final items = addItems(c);
    await settle(tester, 1);
    // a plain drag over empty space pans
    final center = c.camera.center;
    var g = await tester.startGesture(global(tester, c, const Pt(-8, 8)), kind: PointerDeviceKind.touch);
    for (var i = 1; i <= 5; i++) {
      await g.moveTo(global(tester, c, Pt(-8 + 6.0 * i, 8 - 2.0 * i)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await settle(tester, 1);
    expect(c.camera.center, isNot(center));
    expect(c.selection, isEmpty);
    // held still, then dragged: a window around the first two items
    c.camera.center = const Pt(20, 0);
    await settle(tester, 1);
    g = await tester.startGesture(global(tester, c, const Pt(-3, 3)), kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 650));
    for (var i = 1; i <= 5; i++) {
      await g.moveTo(global(tester, c, Pt(-3 + 3.0 * i, 3 - 1.2 * i)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(c.camera.center, const Pt(20, 0), reason: 'no pan');
    await g.up();
    await settle(tester, 1);
    expect(c.selection, {items[0].id, items[1].id});
  });

  testWidgets('the phone shows the add-to-selection button with the tools that use it (CAD-17)', (tester) async {
    final c = await pumpShell(tester, size: const Size(390, 844));
    expect(find.byKey(const Key('mobile_add_select')), findsOneWidget);
    await tester.tap(find.byKey(const Key('mobile_add_select')));
    await settle(tester, 1);
    expect(c.editSettings.addToSelection, isTrue);
    c.setTool(ToolId.line);
    await settle(tester, 1);
    expect(find.byKey(const Key('mobile_add_select')), findsNothing);
    c.setTool(ToolId.extend);
    await settle(tester, 1);
    expect(find.byKey(const Key('mobile_add_select')), findsOneWidget);
  });
}
