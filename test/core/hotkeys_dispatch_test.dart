import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/keys/hotkeys.dart';
import 'package:opencadirrigation/app/shortcuts.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

/// The keyboard dispatcher on its own: every key, every typed command and
/// what dialogs and menus block, with the shell's actions recorded.
class _Actions implements HotkeyActions {
  _Actions(this.controller);
  @override
  final ProjectController controller;
  final calls = <String>[];
  @override
  bool modalOpen = false;
  @override
  bool menuOpen = false;
  bool dismissable = true;

  @override
  bool dismissModal() {
    calls.add('dismiss');
    return dismissable;
  }

  @override
  void runDesign() => calls.add('run');
  @override
  void save() => calls.add('save');
  @override
  void open() => calls.add('open');
  @override
  void import() => calls.add('import');
  @override
  void exportPdf() => calls.add('pdf');
  @override
  void newTab() => calls.add('newTab');
  @override
  void closeTab() => calls.add('closeTab');
  @override
  void nextTab() => calls.add('nextTab');
  @override
  void prevTab() => calls.add('prevTab');
  @override
  void toggleReports() => calls.add('reports');
  @override
  void array() => calls.add('array');
  @override
  void designCheck() => calls.add('check');
  @override
  void autoFix() => calls.add('fix');
  @override
  void optimize() => calls.add('optimize');
  @override
  void densogram() => calls.add('densogram');
  @override
  void clipboard(CadAction action) => calls.add('clip:${action.name}');
}

class _Canvas implements CanvasKeyTarget {
  final calls = <String>[];
  @override
  bool toolIdle = true;
  @override
  void toolKey(String key) => calls.add('tool:$key');
  @override
  void setSpaceHeld(bool held) => calls.add('space:$held');
  @override
  void modifiersChanged() => calls.add('modifiers');
  @override
  void redraw() => calls.add('redraw');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProjectController c;
  late _Actions a;
  late _Canvas canvas;
  late Hotkeys keys;

  setUp(() {
    c = ProjectController()..autosaveEnabled = false;
    c.setLanguage('en');
    c.newProject();
    canvas = _Canvas();
    c.keyTarget = canvas;
    a = _Actions(c);
    keys = Hotkeys(a);
  });
  tearDown(() => keys.dispose());

  bool press(String key, {bool ctrl = false, bool shift = false, bool alt = false, bool meta = false, bool repeat = false, String code = ''}) =>
      keys.handle(HotkeyEvent(key, code: code, ctrl: ctrl, shift: shift, alt: alt, meta: meta, repeat: repeat));

  void typeCommand(String s) {
    for (final ch in s.split('')) {
      press(ch);
    }
  }

  test('application keys: files, tabs, design and reports; blocked under a dialog', () {
    expect(press('s', ctrl: true), isTrue);
    expect(press('o', meta: true), isTrue);
    expect(press('i', ctrl: true), isTrue);
    expect(press('p', ctrl: true), isTrue);
    expect(press('F5'), isTrue);
    expect(press('F2'), isTrue);
    expect(press('n', ctrl: true, alt: true, code: 'KeyN'), isTrue);
    expect(press('w', ctrl: true, alt: true, code: 'KeyW'), isTrue);
    expect(press('ArrowRight', ctrl: true, alt: true, code: 'ArrowRight'), isTrue);
    expect(press('ArrowLeft', ctrl: true, alt: true, code: 'ArrowLeft'), isTrue);
    expect(a.calls, ['save', 'open', 'import', 'pdf', 'run', 'reports', 'newTab', 'closeTab', 'nextTab', 'prevTab']);
    // a dialog swallows them (the browser must not reload or save the page)
    a.calls.clear();
    a.modalOpen = true;
    expect(press('F5'), isTrue);
    expect(press('s', ctrl: true), isTrue);
    expect(press('n', ctrl: true, alt: true, code: 'KeyN'), isTrue);
    expect(a.calls, isEmpty);
    // Escape closes it; other keys go to the dialog, the browser keys are kept from the page
    expect(press('Escape'), isTrue);
    expect(a.calls, ['dismiss']);
    a.dismissable = false;
    expect(press('Escape'), isFalse);
    expect(press('F7'), isTrue);
    expect(press('x'), isFalse);
    a.modalOpen = false;
    // an open menu: same
    a.menuOpen = true;
    expect(press('Delete'), isFalse);
    expect(press('F9'), isTrue);
    expect(press('d', ctrl: true), isTrue, reason: 'reserved by the browser (bookmark)');
    a.menuOpen = false;
    // Ctrl+Alt with another key and Alt alone are not ours
    expect(press('k', ctrl: true, alt: true, code: 'KeyK'), isFalse);
    expect(press('F5', alt: true), isFalse);
  });

  test('editing keys: undo, redo, select all, duplicate and the clipboard', () {
    final l = LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(1, 0));
    c.addEntity(l);
    expect(press('z', ctrl: true), isTrue);
    expect(c.project.entities, isEmpty);
    expect(press('z', ctrl: true, shift: true), isTrue);
    expect(c.project.entities.length, 1);
    press('z', ctrl: true);
    expect(press('y', ctrl: true), isTrue);
    expect(c.project.entities.length, 1);
    expect(press('a', ctrl: true), isTrue);
    expect(c.selection, {c.project.entities.single.id});
    expect(press('d', ctrl: true), isTrue);
    expect(c.project.entities.length, 2);
    press('c', ctrl: true);
    press('x', ctrl: true);
    press('v', ctrl: true);
    expect(a.calls, ['clip:copy', 'clip:cut', 'clip:paste']);
    expect(press('q', ctrl: true), isFalse);
  });

  test('canvas keys: space pans, Escape, Enter and Backspace go to the tool, toggles, pan and zoom', () {
    expect(press(' '), isTrue);
    expect(press(' ', repeat: true), isTrue);
    expect(keys.handle(const HotkeyEvent(' ', down: false)), isTrue);
    expect(canvas.calls, ['space:true', 'space:false']);
    canvas.calls.clear();
    keys.handle(const HotkeyEvent('Shift'));
    expect(canvas.calls, ['modifiers']);
    expect(keys.handle(const HotkeyEvent('Control')), isFalse);
    expect(keys.handle(const HotkeyEvent('x', down: false)), isFalse);
    // Enter repeats the last drawing tool, then goes to the tool
    c.lastTool = ToolId.circle;
    press('Enter');
    expect(c.activeTool, ToolId.circle);
    canvas.calls.clear();
    press('Enter');
    press('Backspace');
    expect(canvas.calls, ['tool:Enter', 'tool:Backspace']);
    // Escape: to the tool; a busy tool keeps itself, an idle one returns to Select
    canvas.toolIdle = false;
    press('Escape');
    expect(c.activeTool, ToolId.circle);
    canvas.toolIdle = true;
    press('Escape');
    expect(c.activeTool, ToolId.select);
    // toggles
    final ortho = c.snap.ortho, grid = c.snap.grid, snap = c.snap.enabled, shown = c.showGrid;
    press('F8');
    press('F9');
    press('F3');
    press('F7');
    expect((c.snap.ortho, c.snap.grid, c.snap.enabled, c.showGrid), (!ortho, !grid, !snap, !shown));
    // arrows pan the view by 40 px and repaint
    final center = c.camera.center;
    canvas.calls.clear();
    press('ArrowLeft');
    press('ArrowRight');
    expect(c.camera.center.distanceTo(center), lessThan(1e-9));
    press('ArrowUp');
    press('ArrowDown');
    expect(c.camera.center.distanceTo(center), lessThan(1e-9));
    expect(canvas.calls.where((x) => x == 'redraw').length, 4);
    expect(c.eventCount('pan'), 4);
    // zoom in and out
    final scale = c.camera.scale;
    press('+');
    expect(c.camera.scale, closeTo(scale * 1.25, 1e-9));
    press('=');
    press('-');
    press('-');
    expect(c.camera.scale, closeTo(scale, 1e-9));
    // Delete erases the selection; Home zooms to everything
    final l = LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(100, 50));
    c.addEntity(l);
    c.select([l.id]);
    press('Home');
    press('Delete');
    expect(c.project.entities, isEmpty);
    // other keys are not ours
    expect(press('Tab'), isFalse);
  });

  test('typed commands: letters build them, Backspace edits, Escape clears, Space and Enter run', () {
    typeCommand('lx');
    expect(c.command, 'LX');
    press('Backspace');
    expect(c.command, 'L');
    press(' ');
    expect(c.command, isEmpty);
    expect(c.activeTool, ToolId.line);
    typeCommand('pl');
    press('Escape');
    expect(c.command, isEmpty);
    expect(c.activeTool, ToolId.line, reason: 'Escape only cleared the command');
    // a held key does not repeat letters
    press('c');
    press('c', repeat: true);
    expect(c.command, 'C');
    press('Enter');
    expect(c.activeTool, ToolId.circle);
    // unknown command
    typeCommand('qqq');
    press('Enter');
    expect(c.lastMessage, contains('QQQ'));
    // point tools set the scope they belong to
    typeCommand('pu');
    press('Enter');
    typeCommand('v');
    press('Enter');
    expect(c.toolSettings.pointScope, HydraulicScope.zone);
  });

  test('every command alias runs its tool or action', () {
    for (final e in commandAliases.entries) {
      a.calls.clear();
      c.setTool(ToolId.select);
      final line = LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(3, 4));
      c.addEntity(line);
      c.select([line.id]);
      final n = c.project.entities.length;
      final snap = c.snap.enabled, ortho = c.snap.ortho, grid = c.snap.grid, shown = c.showGrid;
      final scale = c.camera.scale;
      c.command = e.key;
      keys.runCommand();
      expect(c.command, isEmpty);
      final target = e.value;
      if (target is ToolId) {
        expect(c.activeTool, target, reason: e.key);
        continue;
      }
      switch (target as CadAction) {
        case CadAction.select:
          expect(c.activeTool, ToolId.select);
        case CadAction.zoomAll:
          expect(c.eventCount('zoomAll'), greaterThan(0));
        case CadAction.zoomIn:
          expect(c.camera.scale, closeTo(scale * 1.25, 1e-9), reason: e.key);
        case CadAction.zoomOut:
          expect(c.camera.scale, closeTo(scale * 0.8, 1e-9), reason: e.key);
        case CadAction.erase:
          expect(c.project.entities.length, n - 1, reason: e.key);
        case CadAction.copy || CadAction.cut || CadAction.paste:
          expect(a.calls, ['clip:${target.name}'], reason: e.key);
        case CadAction.undo:
          expect(c.project.entities.length, n - 1, reason: e.key);
        case CadAction.redo:
          expect(c.eventCount('redo'), greaterThan(0));
        case CadAction.selectAll:
          expect(c.selection.length, c.project.entities.length);
        case CadAction.duplicate:
          expect(c.project.entities.length, n + 1, reason: e.key);
        case CadAction.array:
          expect(a.calls, ['array']);
        case CadAction.feedEnvelope:
          expect(c.lastMessage, c.t('msg.feedNone'));
        case CadAction.run:
          expect(a.calls, ['run']);
        case CadAction.check:
          expect(a.calls, ['check']);
        case CadAction.autoFix:
          expect(a.calls, ['fix']);
        case CadAction.optimize:
          expect(a.calls, ['optimize']);
        case CadAction.densogram:
          expect(a.calls, ['densogram']);
        case CadAction.snap:
          expect(c.snap.enabled, !snap, reason: e.key);
        case CadAction.ortho:
          expect(c.snap.ortho, !ortho, reason: e.key);
        case CadAction.gridSnap:
          expect(c.snap.grid, !grid, reason: e.key);
        case CadAction.gridDisplay:
          expect(c.showGrid, !shown, reason: e.key);
        case CadAction.reports:
          expect(a.calls, ['reports']);
        case CadAction.save:
          expect(a.calls, ['save']);
        case CadAction.open:
          expect(a.calls, ['open']);
      }
    }
  });

  test('browser keys that must never reach the page', () {
    for (final k in ['F2', 'F3', 'F5', 'F7', 'F8', 'F9']) {
      expect(Hotkeys.reservedByBrowser(HotkeyEvent(k)), isTrue, reason: k);
    }
    for (final ch in ['s', 'o', 'p', 'i', 'd']) {
      expect(Hotkeys.reservedByBrowser(HotkeyEvent(ch, ctrl: true)), isTrue, reason: ch);
    }
    expect(Hotkeys.reservedByBrowser(const HotkeyEvent('s', ctrl: true, alt: true)), isFalse);
    expect(Hotkeys.reservedByBrowser(const HotkeyEvent('a')), isFalse);
    expect(const HotkeyEvent('Meta').isModifier, isTrue);
    expect(const HotkeyEvent('F1').char, isNull);
    expect(const HotkeyEvent('a', meta: true).toString(), contains('meta'));
  });
}
