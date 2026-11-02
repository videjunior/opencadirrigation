import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/tools/edit_commands.dart';
import 'package:opencadirrigation/app/tools/selection_filters.dart';
import 'package:opencadirrigation/app/tools/tools.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

class _Host implements ToolHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Selection by what the items are (CAD-25): select similar, the quick
/// selection with its filters and modes, the lasso, the fence and the
/// selection of a layer.
void main() {
  late ProjectController c;
  late List<PipeSpec> zonePipes;

  setUp(() {
    setPref('lang', 'en');
    c = ProjectController()..autosaveEnabled = false;
    c.newProject();
    c.camera.size = const Size(800, 600);
    c.camera.center = const Pt(25, 0);
    c.camera.scale = 10;
    zonePipes = c.project.catalog.pipesFor(PipeUsage.zone);
  });

  /// Pipes of two sizes, two outlets of different nozzles, lines on two
  /// layers.
  void drawing() {
    final a = zonePipes.first.id, b = zonePipes.last.id;
    c.addEntities([
      PipeEntity(id: 'pa1', points: [Pt.zero, const Pt(10, 0)], scope: HydraulicScope.zone, pipeSpecId: a, computerSized: false),
      PipeEntity(id: 'pa2', points: [const Pt(0, 5), const Pt(30, 5)], scope: HydraulicScope.zone, pipeSpecId: a, computerSized: false),
      PipeEntity(id: 'pb', points: [const Pt(0, 10), const Pt(10, 10)], scope: HydraulicScope.zone, pipeSpecId: b, computerSized: false),
      PipeEntity(id: 'main', points: [const Pt(0, 20), const Pt(10, 20)], scope: HydraulicScope.mainline, pipeSpecId: a, computerSized: false),
      LineEntity(id: 'l1', a: const Pt(40, 0), b: const Pt(45, 0)),
      LineEntity(id: 'l2', a: const Pt(40, 2), b: const Pt(45, 2)),
      LineEntity(id: 'l3', layer: 'notes', a: const Pt(40, 4), b: const Pt(45, 4)),
    ]);
  }

  test('select similar: the same kind and catalogue item, or the same kind on the same layer', () {
    drawing();
    c.select(['pa1']);
    expect(c.selectSimilar(), 2);
    expect(c.selection, {'pa1', 'pa2'}, reason: 'not the other size, not the mainline pipe');
    c.select(['l1']);
    c.selectSimilar();
    expect(c.selection, {'l1', 'l2'}, reason: 'the line on another layer is not alike');
    c.select(['pb', 'l3']);
    c.selectSimilar();
    expect(c.selection, {'pb', 'l3'});
    c.select(const []);
    expect(c.selectSimilar(), 0);
    expect(c.lastMessage, c.t('msg.nothingSelected'));
  });

  test('quick selection: kind, catalogue item, layer and a range of a value, in every mode', () {
    drawing();
    final q = SelectionQuery(kind: 'zonePipe');
    expect(c.queryMatches(q).map((e) => e.id), ['pa1', 'pa2', 'pb']);
    q.spec = zonePipes.first.id;
    expect(c.queryMatches(q).map((e) => e.id), ['pa1', 'pa2']);
    // pipes longer than 15 m
    q
      ..spec = null
      ..property = SelectionProperty.length
      ..min = 15;
    expect(c.queryMatches(q).map((e) => e.id), ['pa2']);
    // by the bore of the catalogue item
    final bore = zonePipes.last.innerDiameter;
    final big = SelectionQuery(property: SelectionProperty.diameter, min: bore - 1e-6);
    expect(c.queryMatches(big).map((e) => e.id), ['pb']);
    expect(c.queryMatches(SelectionQuery(layer: 'notes')).map((e) => e.id), ['l3']);
    // the modes
    final pipes = SelectionQuery(kind: 'zonePipe');
    expect(c.selectByQuery(pipes), 3);
    expect(c.selectByQuery(SelectionQuery(kind: 'line'), mode: SelectionMode.add), 6);
    expect(c.selectByQuery(SelectionQuery(layer: 'notes'), mode: SelectionMode.remove), 5);
    expect(c.selectByQuery(SelectionQuery(kind: 'line'), mode: SelectionMode.within), 2);
    expect(c.selection, {'l1', 'l2'});
    // a locked layer is never selected
    c.project.layerNamed('notes').locked = true;
    expect(c.queryMatches(SelectionQuery(kind: 'line')).map((e) => e.id), ['l1', 'l2']);
  });

  test('the zone of a valve and its outlets', () {
    c.addEntities([
      ControlValveEntity(id: 'v1', position: Pt.zero, zoneName: 'Zone 1'),
      ControlValveEntity(id: 'v2', position: const Pt(50, 0), zoneName: 'Zone 2'),
      OutletEntity(id: 'o1', position: const Pt(5, 0), outletSpecId: 'micro', zoneName: 'Zone 1'),
      OutletEntity(id: 'o2', position: const Pt(55, 0), outletSpecId: 'micro', zoneName: 'Zone 2'),
    ]);
    expect(zoneNames(c.project, null), ['Zone 1', 'Zone 2']);
    expect(c.queryMatches(SelectionQuery(zone: 'zone 1')).map((e) => e.id), ['v1', 'o1']);
    expect(c.queryMatches(SelectionQuery(zone: 'Zone 2', kind: 'outlet')).map((e) => e.id), ['o2']);
  });

  test('lasso: what lies inside a concave outline, or what it crosses too', () {
    c.addEntities([
      JunctionEntity(id: 'in', position: const Pt(2, 2)),
      JunctionEntity(id: 'notch', position: const Pt(5, 8), scope: HydraulicScope.zone),
      LineEntity(id: 'cross', a: const Pt(8, 2), b: const Pt(14, 2)),
      LineEntity(id: 'inside', a: const Pt(1, 1), b: const Pt(3, 1)),
    ]);
    // a U open at the top: the notch point lies in the gap
    final u = [Pt.zero, const Pt(10, 0), const Pt(10, 10), const Pt(7, 10), const Pt(7, 4), const Pt(3, 4), const Pt(3, 10), const Pt(0, 10)];
    expect(c.selectInPolygon(u), 2);
    expect(c.selection, {'in', 'inside'});
    expect(c.selectInPolygon(u, crossing: true), 3);
    expect(c.selection, {'in', 'inside', 'cross'});
    c.select(['notch']);
    c.selectInPolygon(u, add: true);
    expect(c.selection, {'in', 'inside', 'notch'});
  });

  test('fence: what it crosses, and the point items it passes by', () {
    drawing();
    c.addEntity(JunctionEntity(id: 'j', position: const Pt(5, 15)));
    expect(c.selectByFence([const Pt(5, -2), const Pt(5, 7)]), 2);
    expect(c.selection, {'pa1', 'pa2'});
    c.selectByFence([const Pt(5.05, 12), const Pt(5.05, 18)], add: true);
    expect(c.selection, {'pa1', 'pa2', 'j'}, reason: 'the junction lies within the pick distance');
  });

  test('a layer: all its items; a hidden one selects nothing and says why', () {
    drawing();
    expect(c.selectOnLayer('notes'), 1);
    expect(c.selection, {'l3'});
    c.project.layerNamed('notes').visible = false;
    expect(c.selectOnLayer('notes'), 0);
    expect(c.lastMessage, c.t('sel.layerHidden'));
    c.project.currentLayer = Layers.drawing;
    expect(c.selectOnLayer(), 2, reason: 'the current layer');
  });

  test('the lasso tool drawn by hand and by clicks, the fence tool, Shift adding', () {
    drawing();
    final lasso = createTool(ToolId.lasso, c, _Host());
    // by hand around the two lines of the drawing layer
    lasso.onDown(const Pt(38, -1));
    for (final p in [const Pt(47, -1), const Pt(47, 3), const Pt(38, 3)]) {
      lasso.onMove(p, dragging: true);
    }
    lasso.onUp(const Pt(38, 3));
    expect(c.selection, {'l1', 'l2'});
    expect(lasso.idle, isTrue);
    // by clicks, with Shift: adds the third line
    for (final p in [const Pt(38, 3.5), const Pt(47, 3.5), const Pt(47, 5), const Pt(38, 5)]) {
      lasso.onDown(p, shift: p.x == 38 && p.y == 5);
      lasso.onUp(p);
    }
    lasso.onKey('Enter');
    expect(c.selection, {'l1', 'l2', 'l3'});
    final fence = createTool(ToolId.fence, c, _Host());
    fence.onDown(const Pt(5, -1));
    fence.onDown(const Pt(5, 11));
    fence.onKey('Enter');
    expect(c.selection, {'pa1', 'pa2', 'pb'});
    expect(c.activeTool, ToolId.select, reason: 'the tool is only driven here');
  });

  test('kinds, catalogue items and their names', () {
    final cat = Project().catalog;
    expect(selectionKindOf(PipeEntity(id: 'p', points: const [], scope: HydraulicScope.mainline)), 'mainPipe');
    expect(selectionKindOf(CommentEntity(id: 'c', position: Pt.zero)), 'comment');
    final o = OutletEntity(id: 'o', position: Pt.zero, outletSpecId: 'micro', nozzleId: 'm50');
    expect(specOf(o), 'micro|m50');
    expect(specLabel(cat, 'outlet', specOf(o)!, auto: 'auto'), contains(cat.outlet('micro')!.name));
    expect(specLabel(cat, 'zonePipe', '', auto: 'Automatic'), 'Automatic');
    expect(similarityKey(LineEntity(id: 'l', layer: 'x', a: Pt.zero, b: Pt.zero)), 'line@x');
  });
}
