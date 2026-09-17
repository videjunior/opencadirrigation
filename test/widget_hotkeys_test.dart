import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/canvas/cad_canvas.dart';
import 'package:opencadirrigation/app/canvas/snapping.dart';
import 'package:opencadirrigation/app/io/app_keys.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/keys/hotkeys.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/main.dart';

/// Keyboard shortcuts through the focus-independent dispatcher, the typed
/// command auto-run and the Shift angle lock while drawing.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<ProjectController> pumpShell(WidgetTester tester, {bool example = false}) async {
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
    if (!example) c.newProject();
    c.snap.enabled = false;
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

  Future<void> type(WidgetTester tester, String s) async {
    for (final ch in s.split('')) {
      await tester.sendKeyEvent(LogicalKeyboardKey.knownLogicalKeys.firstWhere((k) => k.keyLabel.toLowerCase() == ch), character: ch);
    }
  }

  test('lockAngle projects onto the nearest 45° or 90° direction', () {
    void near(Pt a, Pt b) {
      expect(a.x, closeTo(b.x, 1e-9));
      expect(a.y, closeTo(b.y, 1e-9));
    }

    near(lockAngle(const Pt(10, 3), const Pt(0, 0), 45), const Pt(10, 0));
    near(lockAngle(const Pt(3, 10), const Pt(0, 0), 45), const Pt(0, 10));
    near(lockAngle(const Pt(10, 8), const Pt(0, 0), 45), const Pt(9, 9));
    near(lockAngle(const Pt(10, 8), const Pt(0, 0), 90), const Pt(10, 0));
    near(lockAngle(const Pt(-7, 6), const Pt(1, 1), 90), const Pt(-7, 1));
    near(lockAngle(const Pt(0, 0), const Pt(0, 0), 45), const Pt(0, 0));
    // exact zeros on the axes (no 6e-17 residue)
    expect(lockAngle(const Pt(3, 10), const Pt(0, 0), 45).x, 0);
  });

  test('HotkeyEvent maps Flutter keys to DOM names', () {
    expect(HotkeyEvent.fromKeyEvent(const KeyDownEvent(physicalKey: PhysicalKeyboardKey.f5, logicalKey: LogicalKeyboardKey.f5, timeStamp: Duration.zero)).key, 'F5');
    expect(HotkeyEvent.fromKeyEvent(const KeyDownEvent(physicalKey: PhysicalKeyboardKey.keyL, logicalKey: LogicalKeyboardKey.keyL, character: 'l', timeStamp: Duration.zero)).char, 'l');
    final n = HotkeyEvent.fromKeyEvent(const KeyDownEvent(physicalKey: PhysicalKeyboardKey.keyN, logicalKey: LogicalKeyboardKey.keyN, timeStamp: Duration.zero));
    expect(n.code, 'KeyN');
    expect(HotkeyEvent.fromKeyEvent(const KeyUpEvent(physicalKey: PhysicalKeyboardKey.space, logicalKey: LogicalKeyboardKey.space, timeStamp: Duration.zero)).down, isFalse);
    expect(const HotkeyEvent('Shift').isModifier, isTrue);
    expect(Hotkeys.reservedByBrowser(const HotkeyEvent('F5')), isTrue);
    expect(Hotkeys.reservedByBrowser(const HotkeyEvent('s', ctrl: true)), isTrue);
    expect(Hotkeys.reservedByBrowser(const HotkeyEvent('s')), isFalse);
  });

  testWidgets('shortcuts work whatever has the focus: palette button, then canvas', (tester) async {
    final c = await pumpShell(tester);
    // click a palette button: it takes the focus in the widget tree
    await tester.tap(find.byTooltip('Retângulo  [REC]'));
    await settle(tester, 1);
    expect(c.activeTool, ToolId.rect);
    await type(tester, 'l');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester, 1);
    expect(c.activeTool, ToolId.line, reason: 'typed alias after a palette click');
    // Esc back to select, F7 grid, Ctrl+A / Delete / Ctrl+Z
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester, 1);
    expect(c.activeTool, ToolId.select);
    final grid = c.showGrid;
    await tester.sendKeyEvent(LogicalKeyboardKey.f7);
    await settle(tester, 1);
    expect(c.showGrid, !grid);
    c.addEntity(CircleEntity(id: c.project.newId(), center: const Pt(0, 0), radius: 1));
    await settle(tester, 1);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester, 1);
    expect(c.selection.length, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await settle(tester, 1);
    expect(c.project.entities, isEmpty);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester, 1);
    expect(c.project.entities.length, 1);
    // F2 toggles the reports panel from anywhere
    final reports = c.showReports;
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await settle(tester, 1);
    expect(c.showReports, !reports);
    expect(c.eventCount('command'), 1);
    expect(c.eventCount('undo'), 1);
  });

  testWidgets('a typed alias runs by itself after a pause; the status bar names it', (tester) async {
    final c = await pumpShell(tester);
    await type(tester, 'p');
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.command, 'P');
    expect(find.textContaining('→ Mover vista'), findsOneWidget);
    // keep typing before the pause: no auto-run of P
    await type(tester, 'l');
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.command, 'PL');
    expect(c.activeTool, ToolId.select);
    await tester.pump(Hotkeys.autoRunDelay + const Duration(milliseconds: 100));
    expect(c.command, '');
    expect(c.activeTool, ToolId.polyline);
    // an unknown buffer never runs by itself
    await type(tester, 'q');
    await tester.pump(Hotkeys.autoRunDelay + const Duration(milliseconds: 100));
    expect(c.command, 'Q');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(c.command, '');
  });

  testWidgets('typing in a text field and open dialogs never trigger shortcuts', (tester) async {
    final c = await pumpShell(tester, example: true);
    final valve = c.project.entities.whereType<ControlValveEntity>().first;
    c.select([valve.id]);
    await settle(tester, 2);
    // the properties panel has a name field: focus it and type
    final field = find.byType(TextField).first;
    await tester.tap(field);
    await settle(tester, 1);
    expect(editableTextFocused(), isTrue);
    await type(tester, 'l');
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await settle(tester, 1);
    expect(c.command, '');
    expect(c.activeTool, ToolId.select);
    expect(c.project.byId(valve.id), isNotNull, reason: 'Delete edits the text, not the drawing');
    // a dialog: Delete and letters go to the dialog
    await tester.tap(find.byType(CadCanvas));
    await settle(tester, 1);
    await tester.tap(find.text('Projeto'));
    await settle(tester, 2);
    await tester.tap(find.text('Parâmetros de projeto…'));
    await settle(tester, 3);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await type(tester, 'l');
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await settle(tester, 1);
    expect(c.project.byId(valve.id), isNotNull);
    expect(c.command, '');
    expect(c.busy, isFalse);
    appNavigatorKey.currentState!.pop();
    await settle(tester, 3);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('holding Shift locks a line to 0°/45°/90°', (tester) async {
    final c = await pumpShell(tester);
    c.setTool(ToolId.line);
    await settle(tester, 1);
    await clickWorld(tester, c, const Pt(0, 0));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    // hovering with Shift held shows the lock chip before the second click
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: screenOf(tester, c, const Pt(10, 2)));
    await g.moveTo(screenOf(tester, c, const Pt(20, 4)));
    await tester.pump();
    expect(c.angleLockActive, isTrue);
    await tester.pump();
    expect(find.byKey(const Key('angle_lock')), findsOneWidget);
    await g.removePointer();
    await clickWorld(tester, c, const Pt(20, 4));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await settle(tester, 1);
    expect(c.angleLockActive, isFalse);
    final line = c.project.entities.whereType<LineEntity>().single;
    expect(line.a.distanceTo(const Pt(0, 0)), lessThan(0.5));
    expect(line.b.y, closeTo(0, 0.5), reason: 'locked to the horizontal');
    expect(line.b.x, closeTo(20, 0.5));
    expect(c.eventCount('lock'), 1);
    // without Shift the point is free
    await clickWorld(tester, c, const Pt(0, 10));
    await clickWorld(tester, c, const Pt(20, 14));
    final free = c.project.entities.whereType<LineEntity>().last;
    expect(free.b.y, closeTo(14, 0.5));
    // ortho (F8) locks to 0°/90° even with snapping off
    await tester.sendKeyEvent(LogicalKeyboardKey.f8);
    await settle(tester, 1);
    expect(c.snap.ortho, isTrue);
    await clickWorld(tester, c, const Pt(0, 20));
    await clickWorld(tester, c, const Pt(6, 30));
    final ortho = c.project.entities.whereType<LineEntity>().last;
    expect(ortho.b.x, closeTo(0, 0.5));
    expect(ortho.b.y, closeTo(30, 0.5));
  });
}
