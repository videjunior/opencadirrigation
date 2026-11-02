import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/keys/hotkeys.dart';
import 'package:opencadirrigation/app/shortcuts.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tools/cad_plus_commands.dart';
import 'package:opencadirrigation/app/tools/typed_point.dart';
import 'package:opencadirrigation/core/io/geo.dart';
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
  void assistant() => calls.add('assistant');
  @override
  void densogram() => calls.add('densogram');
  @override
  void autoDesign(CadAction action) => calls.add(action.name);
  @override
  void networkTool(CadAction action) => calls.add('net:${action.name}');
  @override
  void mainlineAnalysis(CadAction action) => calls.add('main:${action.name}');
  @override
  void insertBlock() => calls.add('insertBlock');
  @override
  void saveBlock() => calls.add('saveBlock');
  @override
  void clipboard(CadAction action) => calls.add('clip:${action.name}');
  @override
  void quickSelect() => calls.add('quickSelect');
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
  @override
  Pt? referencePoint;
  @override
  Pt? cursorPoint;
  @override
  void feedPoint(Pt p) => calls.add('point:${p.x},${p.y}');

  /// The typed texts the tool takes (an option, a step value).
  Set<String> takes = {};
  @override
  bool toolInput(String text) {
    if (!takes.contains(text)) return false;
    calls.add('input:$text');
    return true;
  }
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
  group('typed points', typedPointTests);

  test('coordinates typed while a tool waits for a point are fed to it; minus is typed, not a zoom', () {
    c.setTool(ToolId.polyline);
    canvas.referencePoint = const Pt(10, 10);
    for (final ch in '@5,0'.split('')) {
      keys.handle(HotkeyEvent(ch));
    }
    expect(c.command, '@5,0');
    keys.handle(const HotkeyEvent('Enter'));
    expect(canvas.calls, contains('point:15.0,10.0'));
    expect(c.command, '');
    final scale = c.camera.scale;
    keys.handle(const HotkeyEvent('-'));
    keys.handle(const HotkeyEvent('3'));
    keys.handle(const HotkeyEvent(','));
    keys.handle(const HotkeyEvent('4'));
    expect(c.command, '-3,4');
    expect(c.camera.scale, scale);
    keys.handle(const HotkeyEvent(' '));
    expect(canvas.calls, contains('point:-3.0,4.0'));
    // with the selection tool the minus key still zooms out and aliases still run
    c.setTool(ToolId.select);
    keys.handle(const HotkeyEvent('-'));
    expect(c.camera.scale, lessThan(scale));
    expect(c.command, '');
  });

  test('the active tool reads the typed text first (an option, a step value), then points and aliases', () {
    c.setTool(ToolId.rotate);
    canvas.takes = {'45', 'C'};
    for (final ch in '45'.split('')) {
      keys.handle(HotkeyEvent(ch));
    }
    keys.handle(const HotkeyEvent('Enter'));
    expect(canvas.calls, contains('input:45'));
    expect(canvas.calls.where((x) => x.startsWith('point:')), isEmpty, reason: 'not a distance along the cursor');
    // an option letter wins over its alias (C would start the circle)
    c.setTool(ToolId.polyline);
    c.command = 'C';
    keys.runCommand();
    expect(canvas.calls, contains('input:C'));
    expect(c.activeTool, ToolId.polyline);
    // what the tool does not take is a point or an alias as before
    c.command = 'L';
    keys.runCommand();
    expect(c.activeTool, ToolId.line);
    // with the selection tool nothing is offered to the tool
    c.setTool(ToolId.select);
    canvas.calls.clear();
    c.command = 'C';
    keys.runCommand();
    expect(canvas.calls, isEmpty);
    expect(c.activeTool, ToolId.circle);
  });

  test('F10 cycles the polar tracking step', () {
    expect(c.snap.polarStepDeg, 0);
    keys.handle(const HotkeyEvent('F10'));
    expect(c.snap.polarStepDeg, 15);
    for (var i = 0; i < 4; i++) {
      keys.handle(const HotkeyEvent('F10'));
    }
    expect(c.snap.polarStepDeg, 0);
  });

  bool press(String key, {bool ctrl = false, bool shift = false, bool alt = false, bool meta = false, bool repeat = false, String code = ''}) =>
      keys.handle(HotkeyEvent(key, code: code, ctrl: ctrl, shift: shift, alt: alt, meta: meta, repeat: repeat));

  void typeCommand(String s) {
    for (final ch in s.split('')) {
      press(ch);
    }
  }

  test('Backspace (the delete key of a Mac) erases the selection with the selection tool (CAD-32)', () {
    final l = LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(5, 0));
    c.addEntity(l);
    c.setTool(ToolId.select);
    c.select([l.id]);
    expect(press('Backspace'), isTrue);
    expect(c.project.entities, isEmpty);
    expect(canvas.calls.where((x) => x == 'tool:Backspace'), isEmpty);
    // while a command is typed it edits the command
    final m = LineEntity(id: c.project.newId(), a: Pt.zero, b: const Pt(5, 0));
    c.addEntity(m);
    c.select([m.id]);
    typeCommand('lx');
    press('Backspace');
    expect(c.command, 'L');
    expect(c.project.entities.length, 1);
    press('Escape');
    // with a drawing tool it takes back the last point
    c.setTool(ToolId.polyline);
    press('Backspace');
    expect(canvas.calls.last, 'tool:Backspace');
    expect(c.project.entities.length, 1);
  });

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
          expect(c.lastMessage, c.t('msg.selectLateral'), reason: 'same message as Zone → Allowable submain position');
        case CadAction.run:
          expect(a.calls, ['run']);
        case CadAction.check:
          expect(a.calls, ['check']);
        case CadAction.autoFix:
          expect(a.calls, ['fix']);
        case CadAction.optimize:
          expect(a.calls, ['optimize']);
        case CadAction.assistant:
          expect(a.calls, ['assistant']);
        case CadAction.densogram:
          expect(a.calls, ['densogram']);
        case CadAction.autoLayout || CadAction.template || CadAction.fieldBlocks || CadAction.treeRings || CadAction.pivotFit || CadAction.vegetation:
          expect(a.calls, [target.name], reason: e.key);
        case CadAction.onDemand || CadAction.tariff || CadAction.energyGroups || CadAction.wireRoutes || CadAction.criticality || CadAction.calibration || CadAction.fertigation:
          expect(a.calls, ['net:${target.name}'], reason: e.key);
        case CadAction.transients || CadAction.airValves || CadAction.eps:
          expect(a.calls, ['main:${target.name}'], reason: e.key);
        case CadAction.insertBlock || CadAction.saveBlock:
          expect(a.calls, [target.name], reason: e.key);
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
        case CadAction.selectSimilar:
          expect(c.selection, {for (final e in c.project.entities.whereType<LineEntity>()) e.id}, reason: '${e.key}: every line of the layer');
        case CadAction.quickSelect:
          expect(a.calls, ['quickSelect']);
        case CadAction.selectLayer:
          expect(c.selection.length, c.project.entities.where((x) => x.layer == c.project.currentLayer).length, reason: e.key);
        // a lone line selected: nothing to join, explode or close, and the user is told
        case CadAction.join:
          expect(c.lastMessage, c.t('edt.nothingToJoin'), reason: e.key);
        case CadAction.explode:
          expect(c.lastMessage, c.t('edt.nothingToExplode'), reason: e.key);
        case CadAction.toArea:
          expect(c.lastMessage, c.t('edt.notClosed'), reason: e.key);
        // 1.6.0 CAD
        case CadAction.isolateLayer:
          expect([for (final l in c.project.layers) if (l.visible) l.name], [c.project.currentLayer], reason: e.key);
        case CadAction.unisolateLayers:
          expect(c.layersIsolated, isFalse, reason: e.key);
          expect(c.project.layers.every((l) => l.visible), isTrue, reason: e.key);
        case CadAction.toCurrentLayer:
          expect(c.lastMessage, c.t('cadp.alreadyOnLayer'), reason: e.key);
        case CadAction.bringToFront:
          expect(c.project.entities.last.id, line.id, reason: e.key);
        case CadAction.sendToBack:
          expect(c.project.entities.first.id, line.id, reason: e.key);
        case CadAction.editBlock:
          expect(c.lastMessage, c.t('blkref.selectRef'), reason: e.key);
      }
    }
  });

  // 1.6.0 CAD+
  group('coordinates of the field, a snap for one point, the dynamic input', () {
    const g = GeoReference(zone: 23, north: false, originEasting: 456000, originNorthing: 7654000);
    void typeKeys(String text) {
      for (final ch in text.split('')) {
        keys.handle(HotkeyEvent(ch));
      }
    }

    test('UTM typed with its zone and spaces goes to the tool as a local point', () {
      c.project.meta.georef = g;
      c.setTool(ToolId.polyline);
      typeKeys('23S 456789 7654321');
      expect(c.command, '23S 456789 7654321', reason: 'the spaces stay in the coordinate');
      keys.handle(const HotkeyEvent('Enter'));
      expect(canvas.calls, contains('point:789.0,321.0'));
    });

    test('latitude and longitude with the LL prefix; DMS through the command field; no georeference says so', () {
      c.project.meta.georef = g;
      c.setTool(ToolId.polyline);
      typeKeys('ll -22.5,-47.1');
      keys.handle(const HotkeyEvent('Enter'));
      final (x, y) = g.fromLatLon(-22.5, -47.1);
      expect(canvas.calls, contains('point:$x,$y'));
      canvas.calls.clear();
      c.command = "22°30'S 47°06'W";
      keys.runCommand();
      expect(canvas.calls.single, startsWith('point:'));
      c.project.meta.georef = null;
      c.command = 'LL -22.5,-47.1';
      keys.runCommand();
      expect(c.lastMessage, c.t('cmd.geoNoGeoref'));
      // a plain pair stays a local point
      canvas.calls.clear();
      c.command = '-22.5,-47.1';
      keys.runCommand();
      expect(canvas.calls, contains('point:-22.5,-47.1'));
    });

    test('END, MID… choose the snap of the next point; NON clears it; not while selecting', () {
      c.setTool(ToolId.line);
      c.command = 'END';
      keys.runCommand();
      expect(c.snap.once, 'endpoint');
      expect(c.lastMessage, c.t('cadp.snapOnce', {'k': c.t('snapk.endpoint')}));
      c.command = 'NON';
      keys.runCommand();
      expect(c.snap.once, isNull);
      c.setTool(ToolId.select);
      c.command = 'MID';
      keys.runCommand();
      expect(c.snap.once, isNull);
      expect(c.lastMessage, contains('MID'), reason: 'an unknown command while selecting');
    });

    test('Tab keeps the length typed (or on the screen) and the angle is typed next', () {
      c.setTool(ToolId.line);
      canvas
        ..referencePoint = Pt.zero
        ..cursorPoint = const Pt(3, 4);
      typeKeys('10');
      expect(keys.handle(const HotkeyEvent('Tab')), isTrue);
      expect(c.command, '@10<');
      typeKeys('90');
      keys.handle(const HotkeyEvent('Enter'));
      expect(canvas.calls.last, startsWith('point:'));
      final p = canvas.calls.last.substring(6).split(',').map(double.parse).toList();
      expect(p[0], closeTo(0, 1e-9));
      expect(p[1], closeTo(10, 1e-9));
      // nothing typed: the length on the screen
      expect(keys.handle(const HotkeyEvent('Tab')), isTrue);
      expect(c.command, startsWith('@5'));
      expect(c.command, endsWith('<'));
      keys.setCommand('');
      // off, or no point yet: Tab is left to the focus
      c.cadPlus.dynamicInput = false;
      expect(keys.handle(const HotkeyEvent('Tab')), isFalse);
      c.cadPlus.dynamicInput = true;
      canvas.referencePoint = null;
      expect(keys.handle(const HotkeyEvent('Tab')), isFalse);
    });
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

void typedPointTests() {
  test('typed points: absolute, relative, polar and direct distance in display units', () {
    expect(parseTypedPoint('10,20'), const Pt(10, 20));
    expect(parseTypedPoint('-2.5,4'), const Pt(-2.5, 4));
    expect(parseTypedPoint('1,5;2,5'), const Pt(1.5, 2.5)); // semicolon: decimal commas
    expect(parseTypedPoint('@3,4', reference: const Pt(1, 1)), const Pt(4, 5));
    final polar = parseTypedPoint('@10<90', reference: const Pt(1, 1))!;
    expect(polar.x, closeTo(1, 1e-9));
    expect(polar.y, closeTo(11, 1e-9));
    final direct = parseTypedPoint('5', reference: Pt.zero, cursor: const Pt(3, 4))!;
    expect(direct.x, closeTo(3, 1e-9));
    expect(direct.y, closeTo(4, 1e-9));
    // feet: 10 ft is 3.048 m
    expect(parseTypedPoint('10,0', toSi: (v) => v * 0.3048)!.x, closeTo(3.048, 1e-12));
    for (final bad in ['', '@1,2', '5', '@5<', 'abc', '1,2,3', '@x<1']) {
      expect(parseTypedPoint(bad), isNull, reason: bad);
    }
  });
}
