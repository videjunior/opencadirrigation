/// One project inserted into another (1.6.0 MOD: File → Insert project…):
/// new ids with the references kept, catalogue items renamed on conflict,
/// prices in the target's currency, layers, system flows and blocks, and
/// the placement by the two georeferences.
library;

import 'dart:convert';

import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/insert_project.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/model/blocks.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/currency.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/project_merge.dart';

List<Pt> _rect(double x0, double y0, double x1, double y1) => [Pt(x0, y0), Pt(x1, y0), Pt(x1, y1), Pt(x0, y1)];

/// A small project: a lawn, a valve fed by a pipe of its own item "pipe1",
/// a layer of its own and a system flow running the valve.
Project _source() {
  final p = Project();
  p.catalog.pipes.add(PipeSpec(id: 'pipe1', name: 'PE 32 of the source', nominalMm: 32, innerDiameterMm: 28, costPerM: 2));
  p.layers.add(Layer(name: 'POND', color: 0xFF2196F3, visible: false));
  final valve = ControlValveEntity(id: p.newId(), position: const Pt(5, 5), zoneName: 'Lawn');
  p.entities.addAll([
    AreaEntity(id: p.newId(), name: 'Lawn', points: _rect(0, 0, 10, 10)),
    valve,
    PipeEntity(id: p.newId(), points: const [Pt(5, 5), Pt(9, 5)], scope: HydraulicScope.zone, pipeSpecId: 'pipe1', computerSized: false),
    PolylineEntity(id: p.newId(), layer: 'POND', points: _rect(2, 2, 4, 4), closed: true),
  ]);
  p.systemFlows.add(SystemFlow(id: 'f1', name: 'Flow 1', valveIds: {valve.id}));
  p.blocks.put(
    BlockDefinition(
      name: 'Kit',
      entities: [LineEntity(id: 'k1', a: Pt.zero, b: const Pt(1, 0))],
    ),
  );
  p.blocks.put(
    BlockDefinition(
      name: 'Manifold',
      entities: [LineEntity(id: 'm1', a: Pt.zero, b: const Pt(2, 0))],
    ),
  );
  return p;
}

/// The project the source goes into: its own "pipe1" (another pipe), an
/// entity, a system flow and blocks of the same names.
Project _target() {
  final p = Project();
  p.catalog.pipes.add(PipeSpec(id: 'pipe1', name: 'PVC 50 of the target', nominalMm: 50, innerDiameterMm: 46.4, costPerM: 5));
  final v = ControlValveEntity(id: p.newId(), position: const Pt(50, 50), zoneName: 'Garden');
  p.entities.add(v);
  p.systemFlows.add(SystemFlow(id: 'f1', name: 'Flow 1', valveIds: {v.id}));
  p.blocks.put(
    BlockDefinition(
      name: 'Kit',
      entities: [LineEntity(id: 'k1', a: Pt.zero, b: const Pt(1, 0))],
    ),
  );
  p.blocks.put(
    BlockDefinition(
      name: 'Manifold',
      entities: [LineEntity(id: 'm9', a: Pt.zero, b: const Pt(3, 0))],
    ),
  );
  return p;
}

void main() {
  test('new ids, the references kept, an item of the same id and other data renamed', () {
    final src = _source(), p = _target();
    final before = {for (final e in p.entities) e.id};
    final r = insertProject(p, src);
    expect(r.ids.length, src.entities.length);
    expect(r.ids.toSet().intersection(before), isEmpty, reason: 'no id of the target is taken');
    expect({for (final e in p.entities) e.id}.length, p.entities.length);
    // the target's own "pipe1" stays; the source's comes as "pipe1~2"
    expect(p.catalog.pipe('pipe1')!.name, 'PVC 50 of the target');
    expect(r.paste.renamedItems, {'pipe1': 'pipe1~2'});
    final pipe = p.entities.whereType<PipeEntity>().single;
    expect(pipe.pipeSpecId, 'pipe1~2');
    expect(p.catalog.pipe('pipe1~2')!.innerDiameterMm, 28);
    // as drawn: neither project is georeferenced
    expect(r.placement, InsertPlacement.asDrawn);
    expect(p.entities.whereType<AreaEntity>().single.points.first, Pt.zero);
  });

  test('layers with their state, system flows remapped and named apart, blocks', () {
    final src = _source(), p = _target();
    final r = insertProject(p, src);
    expect(r.layers, 1);
    expect(p.findLayer('POND')!.visible, isFalse);
    expect(p.findLayer('POND')!.color, 0xFF2196F3);
    expect(r.flows, 1);
    final flow = p.systemFlows.last;
    expect(flow.id, 'f1_2');
    expect(flow.name, 'Flow 1 (2)');
    final valve = p.entities.whereType<ControlValveEntity>().firstWhere((v) => v.zoneName == 'Lawn');
    expect(flow.valveIds, {valve.id});
    expect(p.systemFlows.first.valveIds.contains(valve.id), isFalse, reason: 'the target flow is left alone');
    // the same block once, another one of the same name under a free name
    expect(r.blocks, 1);
    expect(p.blocks.byName('Manifold (2)'), isNotNull);
    expect(p.blocks.byName('Kit (2)'), isNull);
  });

  test('placed by the georeferences; an empty project without one takes the file\'s', () {
    final src = _source()..meta.georef = const GeoReference(zone: 23, north: false, originEasting: 500100, originNorthing: 8000050);
    final p = _target()..meta.georef = const GeoReference(zone: 23, north: false, originEasting: 500000, originNorthing: 8000000);
    final r = insertProject(p, src);
    expect(r.placement, InsertPlacement.georeferenced);
    expect(p.entities.whereType<AreaEntity>().single.points.first, const Pt(100, 50));
    // another UTM zone: the corner of the drawing lands where its latitude and longitude are
    final far = _source()..meta.georef = GeoReference.fromLatLonOrigin(-15.0, -48.05);
    final near = Project()..meta.georef = GeoReference.fromLatLonOrigin(-15.0, -47.95);
    expect(far.meta.georef!.zone, isNot(near.meta.georef!.zone));
    insertProject(near, far);
    final corner = near.entities.whereType<AreaEntity>().single.points.first;
    final (lat0, lon0) = far.meta.georef!.toLatLon(0, 0);
    final (lat1, lon1) = near.meta.georef!.toLatLon(corner.x, corner.y);
    expect((lat1 - lat0).abs(), lessThan(1e-7));
    expect((lon1 - lon0).abs(), lessThan(1e-7));
    // nothing drawn and no georeference yet: it takes the source's
    final empty = Project();
    final taken = insertProject(empty, src);
    expect(taken.placement, InsertPlacement.georeferenceTaken);
    expect(empty.meta.georef!.originEasting, 500100);
  });

  test('prices in the target\'s currency', () {
    final src = _source()..params.currencyCode = 'USD';
    final p = _target();
    final r = insertProject(p, src);
    final rate = exchangeRate('USD', p.params.currencyCode);
    if (rate == null) return;
    expect(r.paste.rate, closeTo(rate, 1e-12));
    expect(p.catalog.pipe('pipe1~2')!.costPerM, closeTo(2 * rate, 1e-9));
  });

  test('in the editor: one undo step, the items selected; a file that is no project says so', () {
    setPref('lang', 'en');
    final c = ProjectController()..autosaveEnabled = false;
    c.newProject();
    c.camera.size = const Size(800, 600);
    final json = jsonEncode(_source().toJson());
    final r = c.insertProjectJson(json, name: 'lawn.oci.json')!;
    expect(c.project.entities.length, 4);
    expect(c.selection, r.ids.toSet());
    expect(c.historyEntries.where((h) => h.current).single.label, 'hist.insertProject');
    c.undo();
    expect(c.project.entities, isEmpty);
    expect(c.insertProjectJson('{"hello": 1}'), isNull);
    expect(c.lastMessage, c.t('insert.notProject'));
  });
}
