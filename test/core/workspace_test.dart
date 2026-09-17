import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/workspace.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

void main() {
  Workspace ws() => Workspace(systemClipboard: false);

  void seed(ProjectController c) {
    c.project.layers.add(Layer(name: 'MEU_LAYER', color: 0xFF112233));
    c.addEntities([
      PipeEntity(id: c.project.newId(), layer: 'MEU_LAYER', points: [const Pt(0, 0), const Pt(50, 0)], scope: HydraulicScope.mainline, pipeSpecId: 'pvc50', name: 'Adutora'),
      ControlValveEntity(id: c.project.newId(), position: const Pt(50, 0), valveSpecId: 'ev80', zoneName: 'Zona X'),
      TextEntity(id: c.project.newId(), position: const Pt(1, 1), text: 'nota'),
    ]);
  }

  test('tabs: add, select, cycle, close keeps one tab and propagates language', () {
    final w = ws();
    expect(w.tabs.length, 1);
    final first = w.current;
    first.setLanguage('pt');
    final second = w.addTab();
    expect(w.active, 1);
    expect(second.lang, 'pt');
    expect(second.tabId, isNot(first.tabId));
    w.next();
    expect(w.active, 0);
    w.previous();
    expect(w.active, 1);
    second.setLanguage('es');
    expect(first.lang, 'es');
    w.closeTab(1);
    expect(w.tabs, [first]);
    expect(w.active, 0);
    w.closeTab(0);
    expect(w.tabs.length, 1);
    expect(identical(w.current, first), isFalse);
    expect(w.current.lang, 'es');
  });

  test('copy/paste between tabs carries layers and catalog items, new ids', () async {
    final w = ws();
    final a = w.current;
    seed(a);
    a.selectAll();
    expect(await w.copy(), 3);
    final payload = w.clipboard!;
    expect(payload.layers.keys, containsAll(['MEU_LAYER', Layers.controlValves, Layers.text]));
    expect(payload.catalog['pipes']!.single['id'], 'pvc50');
    expect(payload.catalog['valves']!.single['id'], 'ev80');
    // JSON round trip (what goes to the system clipboard)
    final parsed = ClipboardPayload.tryParse(payload.encode())!;
    expect(parsed.count, 3);
    expect(parsed.sourceTab, a.tabId);
    expect(ClipboardPayload.tryParse('{"format":"other"}'), isNull);
    expect(ClipboardPayload.tryParse('not json opencadirrigation-clipboard'), isNull);

    final b = w.addTab();
    b.project.catalog.pipes.removeWhere((p) => p.id == 'pvc50');
    expect(b.project.catalog.pipe('pvc50'), isNull);
    expect(await w.paste(), 3);
    expect(b.project.entities.length, 3);
    expect(b.selection.length, 3);
    expect(b.project.catalog.pipe('pvc50'), isNotNull);
    expect(b.project.layers.any((l) => l.name == 'MEU_LAYER' && l.color == 0xFF112233), isTrue);
    final pipe = b.project.entities.whereType<PipeEntity>().single;
    expect(pipe.points.first, const Pt(0, 0)); // same coordinates in another project
    expect(b.project.entities.map((e) => e.id).toSet().length, 3); // fresh ids in the target
    expect(pipe.name, 'Adutora');
    expect(b.dirty, isTrue);
    expect(b.canUndo, isTrue);
    b.undo();
    expect(b.project.entities, isEmpty);
  });

  test('paste into the source project offsets the copies; cut removes them', () async {
    final w = ws();
    final a = w.current;
    seed(a);
    a.select([a.project.entities.first.id]);
    await w.copy();
    await w.paste();
    expect(a.project.entities.length, 4);
    final copy = a.project.entities.last as PipeEntity;
    expect(copy.points.first, const Pt(2, -2));
    a.select([copy.id]);
    expect(await w.copy(cut: true), 1);
    expect(a.project.entities.length, 3);
    expect(await w.paste(), 1);
    expect(a.project.entities.length, 4);
  });

  test('empty selection and empty clipboard are no-ops', () async {
    final w = ws();
    expect(await w.copy(), 0);
    expect(await w.paste(), 0);
    expect(w.clipboard, isNull);
  });

  test('example project survives a full copy into a fresh tab and still designs', () async {
    final w = ws();
    w.current.setLanguage('pt');
    loadExampleAction(w.current);
    w.current.selectAll();
    final n = await w.copy();
    expect(n, w.current.project.entities.length);
    final b = w.addTab();
    await w.paste();
    expect(b.project.entities.length, n);
    await b.runDesign();
    expect(b.results, isNotNull);
    expect(b.results!.zones.length, 2);
  });

  test('controller tracks the last drawing tool for Enter-to-repeat', () {
    final c = ProjectController();
    c.setTool(ToolId.circle);
    c.setTool(ToolId.pan);
    c.setTool(ToolId.select);
    expect(c.lastTool, ToolId.circle);
  });
}
