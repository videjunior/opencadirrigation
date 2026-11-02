import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/shortcuts.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tools/edit_tools.dart';
import 'package:opencadirrigation/app/tools/tools.dart';
import 'package:opencadirrigation/app/tools/typed_point.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

/// Records what the tools ask of the widget layer.
class _Host implements ToolHost {
  String status = '';
  @override
  void setStatus(String text) => status = text;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The editing tools of 1.6.0 driven directly, without the canvas widget.
void main() {
  late ProjectController c;
  late _Host host;

  setUp(() {
    setPref('lang', 'en');
    c = ProjectController()..autosaveEnabled = false;
    c.newProject();
    c.camera.size = const Size(800, 600);
    c.camera.center = Pt.zero;
    c.camera.scale = 10;
    c.snap.enabled = false;
    host = _Host();
  });

  Tool tool(ToolId id) => createTool(id, c, host);

  void paint(Tool t) {
    final rec = PictureRecorder();
    t.paint(Canvas(rec), c.camera);
    rec.endRecording().dispose();
  }

  /// A point typed on the command line while [t] waits for one.
  Pt typed(Tool t, String text) => parseTypedPoint(text, reference: t.referencePoint, cursor: t.cursor)!;

  group('move and copy by base point (CAD-06)', () {
    test('aliases: M is Move, CO/CP/COPY the Copy tool; the clipboard keeps Ctrl+C and COPYCLIP', () {
      for (final a in ['M', 'MOVE', 'MOVER']) {
        expect(commandAliases[a], ToolId.move, reason: a);
      }
      for (final a in ['CO', 'CP', 'COPY', 'COPIAR']) {
        expect(commandAliases[a], ToolId.copy, reason: a);
      }
      expect(commandAliases['COPYCLIP'], CadAction.copy);
      expect(aliasOf(ToolId.move), 'M');
      expect(aliasOf(ToolId.copy), 'CO');
    });

    test('move: a click picks, then base point and destination; typed @dx,dy, polar and a bare distance', () {
      c.addEntity(LineEntity(id: 'l', a: Pt.zero, b: const Pt(10, 0)));
      final mv = tool(ToolId.move);
      mv.onDown(const Pt(5, 0.1));
      expect(c.selection, {'l'}, reason: 'with nothing selected a click picks');
      mv.onDown(Pt.zero);
      expect(mv.referencePoint, Pt.zero);
      mv.onMove(const Pt(3, 4));
      paint(mv);
      expect(host.status, startsWith('Δx 3.00  Δy 4.00  d 5.00 m'));
      mv.onDown(const Pt(3, 4));
      final l = c.project.byId('l') as LineEntity;
      expect((l.a, l.b), (const Pt(3, 4), const Pt(13, 4)));
      expect(c.historyEntries.last.label, 'hist.move');
      // typed relative to the base point: @10,0
      mv.onDown(const Pt(3, 4));
      mv.onDown(typed(mv, '@10,0'));
      expect((c.project.byId('l') as LineEntity).a, const Pt(13, 4));
      // polar: 5 m at 90°
      mv.onDown(const Pt(13, 4));
      final polar = typed(mv, '@5<90');
      mv.onDown(polar);
      expect((c.project.byId('l') as LineEntity).a.distanceTo(const Pt(13, 9)), lessThan(1e-9));
      // a bare distance along the cursor
      final at = (c.project.byId('l') as LineEntity).a;
      mv.onDown(at);
      mv.onMove(at + const Pt(-100, 0));
      mv.onDown(typed(mv, '2'));
      expect((c.project.byId('l') as LineEntity).a.distanceTo(at + const Pt(-2, 0)), lessThan(1e-9));
      expect(c.project.entities.length, 1, reason: 'moves never copy');
    });

    test('move with Ctrl copies; the keep-original switch of rotate does not turn a move into a copy', () {
      c.addEntity(OutletEntity(id: 'o', position: Pt.zero, outletSpecId: 'micro'));
      c.select(['o']);
      c.toolSettings.copyOnTransform = true;
      final mv = tool(ToolId.move);
      mv.onDown(Pt.zero);
      mv.onDown(const Pt(2, 0));
      expect(c.project.entities.length, 1);
      expect((c.project.byId('o') as OutletEntity).position, const Pt(2, 0));
      mv.onDown(const Pt(2, 0), ctrl: true);
      mv.onDown(const Pt(2, 5), ctrl: true);
      expect(c.project.entities.length, 2);
      expect(c.project.entities.whereType<OutletEntity>().map((e) => e.position), containsAll([const Pt(2, 0), const Pt(2, 5)]));
    });

    test('copy repeats from the same base point until Enter, each copy one undo step, the originals stay selected', () {
      c.addEntity(LineEntity(id: 'l', a: Pt.zero, b: const Pt(4, 0)));
      c.select(['l']);
      final steps = c.historyEntries.length;
      final cp = tool(ToolId.copy);
      cp.onDown(Pt.zero);
      cp.onMove(const Pt(0, 3));
      paint(cp);
      expect(host.status, startsWith('Δx 0.00  Δy 3.00'));
      cp.onDown(const Pt(0, 3));
      cp.onDown(const Pt(0, 6));
      cp.onDown(typed(cp, '@0,9'));
      final lines = c.project.entities.whereType<LineEntity>().toList();
      expect(lines.length, 4);
      expect(lines.map((e) => e.a.y), [0, 3, 6, 9]);
      expect(c.selection, {'l'}, reason: 'the originals stay selected');
      expect(c.historyEntries.length, steps + 3);
      expect(c.historyEntries.last.label, 'hist.copy|1');
      cp.onKey('Enter');
      expect(c.activeTool, ToolId.select, reason: 'Enter ends the copies');
      c.undo();
      expect(c.project.entities.length, 3);
    });

    test('the tools have their labels, hints and a place in the history', () {
      for (final id in [ToolId.move, ToolId.copy]) {
        final t = tool(id);
        expect(t.hintKey, 'hint.${hintKeyOf(id)}');
        expect(c.t.has(t.hintKey), isTrue);
        expect(c.t.has('tool.${id.name}'), isTrue);
      }
      expect(displacementText(c, const Pt(0, -2)), contains('∠ 270.0°'));
    });
  });
}
