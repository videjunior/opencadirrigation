import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/canvas/cad_canvas.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/main.dart';

/// Canvas navigation by mouse, trackpad and fingers: wheel and pinch zoom
/// about the cursor, panning with the middle button or two fingers, the
/// hover highlight of the select tool.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 3]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
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
    final dynamic shell = tester.state(find.byType(AppShell));
    final ProjectController c = shell.c as ProjectController;
    c.autosaveEnabled = false;
    c.newProject();
    c.snap.enabled = false;
    await settle(tester);
    return c;
  }

  RenderBox canvasBox(WidgetTester tester) => tester.renderObject(find.byType(CadCanvas)) as RenderBox;
  Offset global(WidgetTester tester, ProjectController c, Pt world) => canvasBox(tester).localToGlobal(c.camera.toScreen(world));
  Pt worldAt(WidgetTester tester, ProjectController c, Offset global) => c.camera.toWorld(canvasBox(tester).globalToLocal(global));

  testWidgets('the mouse wheel zooms about the cursor, a trackpad pinch too', (tester) async {
    final c = await pumpShell(tester);
    final at = canvasBox(tester).localToGlobal(canvasBox(tester).size.center(Offset.zero)) + const Offset(120, -60);
    final before = worldAt(tester, c, at);
    final scale = c.camera.scale;
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(at));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -40)));
    await tester.pump();
    expect(c.camera.scale, closeTo(scale * 1.15, 1e-9));
    expect(worldAt(tester, c, at).distanceTo(before), lessThan(1e-6), reason: 'the point under the cursor stays put');
    expect(c.eventCount('zoom'), 1);
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 40)));
    await tester.pump();
    expect(c.camera.scale, closeTo(scale, 1e-9));
    // trackpad pinch (scale events), clamped to half/double per event
    await tester.sendEventToBinding(PointerScaleEvent(position: at, scale: 5));
    await tester.pump();
    expect(c.camera.scale, closeTo(scale * 2, 1e-9));
    expect(worldAt(tester, c, at).distanceTo(before), lessThan(1e-6));
  });

  testWidgets('dragging with the middle button pans; the hover highlights what the click would pick', (tester) async {
    final c = await pumpShell(tester);
    final line = LineEntity(id: c.project.newId(), a: const Pt(0, 0), b: const Pt(40, 0));
    c.addEntity(line);
    await settle(tester);
    // hover over the line, then away
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: global(tester, c, const Pt(20, 30)));
    await mouse.moveTo(global(tester, c, const Pt(20, 0)));
    await tester.pump();
    expect(c.hoverId, line.id);
    await mouse.moveTo(global(tester, c, const Pt(20, 30)));
    await tester.pump();
    expect(c.hoverId, isNull);
    await mouse.removePointer();
    // middle-button drag: the world point under the cursor follows it
    final start = global(tester, c, const Pt(10, 10));
    final grab = await tester.startGesture(start, kind: PointerDeviceKind.mouse, buttons: kMiddleMouseButton);
    await grab.moveBy(const Offset(100, 50));
    await grab.moveBy(const Offset(50, 0));
    await grab.up();
    await tester.pump();
    expect(worldAt(tester, c, start + const Offset(150, 50)).distanceTo(const Pt(10, 10)), lessThan(1e-6));
    expect(c.eventCount('pan'), 1);
    expect(c.project.entities.length, 1, reason: 'panning draws nothing');
  });

  testWidgets('two fingers pinch to zoom and pan; a lifted finger ends the gesture', (tester) async {
    final c = await pumpShell(tester);
    c.setTool(ToolId.line);
    await settle(tester, 1);
    final center = canvasBox(tester).localToGlobal(canvasBox(tester).size.center(Offset.zero));
    final scale = c.camera.scale;
    final f1 = await tester.startGesture(center - const Offset(50, 0), kind: PointerDeviceKind.touch, pointer: 11);
    final f2 = await tester.startGesture(center + const Offset(50, 0), kind: PointerDeviceKind.touch, pointer: 12);
    // fingers twice as far apart: twice the zoom
    await f1.moveBy(const Offset(-25, 0));
    await f2.moveBy(const Offset(25, 0));
    await tester.pump();
    await f1.moveBy(const Offset(-25, 0));
    await f2.moveBy(const Offset(25, 0));
    await tester.pump();
    expect(c.camera.scale, closeTo(scale * 2, 1e-6));
    await f1.up();
    await f2.moveBy(const Offset(30, 30));
    await f2.up();
    await tester.pump();
    expect(c.project.entities, isEmpty, reason: 'a pinch never draws with the line tool');
    // a cancelled touch leaves the canvas ready for a new gesture
    final f3 = await tester.startGesture(center, kind: PointerDeviceKind.touch, pointer: 13);
    await f3.cancel();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tool without snapping drops the angle lock indicator', (tester) async {
    final c = await pumpShell(tester);
    c.angleLockActive = true;
    c.setTool(ToolId.pan);
    await settle(tester, 1);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: global(tester, c, const Pt(5, 5)));
    await mouse.moveTo(global(tester, c, const Pt(6, 6)));
    await tester.pump();
    expect(c.angleLockActive, isFalse);
    await mouse.removePointer();
  });
}
