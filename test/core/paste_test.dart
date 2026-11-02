import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/state/workspace.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/currency.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/paste.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// Pasting between projects (MOD-07): catalogue ids that mean another item
/// in the target, references between entities, valve-in-head stations and
/// currency.
void main() {
  PipeSpec userPipe(String name, double di, double cost) => PipeSpec(id: 'pipe1', name: name, nominalMm: di + 4, innerDiameterMm: di, costPerM: cost);

  test('an item of the same id but other data is renamed; the same item is reused', () {
    final src = Project()..catalog.pipes.add(userPipe('Source pipe 75', 70, 20));
    final dst = Project()..catalog.pipes.add(userPipe('Target pipe 32', 28, 3));
    final pipe = PipeEntity(id: 'e1', points: const [Pt(0, 0), Pt(10, 0)], scope: HydraulicScope.mainline, pipeSpecId: 'pipe1');
    final valve = ControlValveEntity(id: 'e2', position: const Pt(10, 0), valveSpecId: 'ev50', zoneName: 'Z');
    final r = pasteEntities(dst, [pipe.toJson(), valve.toJson()], catalog: catalogSubset(src.catalog, [pipe, valve]));
    expect(r.renamedItems, {'pipe1': 'pipe1~2'});
    final pasted = dst.entities.whereType<PipeEntity>().single;
    expect(pasted.pipeSpecId, 'pipe1~2');
    expect(dst.catalog.pipe('pipe1~2')!.innerDiameterMm, 70);
    expect(dst.catalog.pipe('pipe1')!.name, 'Target pipe 32', reason: 'the target item is untouched');
    expect(dst.entities.whereType<ControlValveEntity>().single.valveSpecId, 'ev50', reason: 'the default valve is the same item: reused');
    expect(dst.catalog.valves.where((v) => v.id == 'ev50' || v.id.startsWith('ev50~')), hasLength(1));
  });

  test('references between pasted entities follow their copies, others are cleared in another project', () {
    final src = Project();
    final guide = AreaEntity(id: 'e3', points: const [Pt(0, 0), Pt(500, 0), Pt(500, 500), Pt(0, 500)]);
    final zone = AreaEntity(id: 'e4', points: const [Pt(0, 0), Pt(100, 0), Pt(100, 100)]);
    final pivot = PivotEntity(id: 'e5', center: const Pt(250, 250), radiusM: 200)
      ..machine.guidePathId = 'e3'
      ..machine.vriZones.addAll({'e4': 6, 'e9': 4})
      ..machine.endGunSpecId = 'gun';
    src.entities.addAll([guide, zone, pivot]);
    expect(catalogSubset(src.catalog, [pivot])['outlets']!.map((o) => o['id']), contains('gun'), reason: 'the end gun goes with the pivot');
    // the pivot with its guide and one of its zones
    final dst = Project()..entities.add(AreaEntity(id: 'e3', points: const [Pt(0, 0), Pt(1, 0), Pt(1, 1)]));
    dst.ensureNextId(10);
    pasteEntities(dst, [guide.toJson(), zone.toJson(), pivot.toJson()], catalog: catalogSubset(src.catalog, [pivot]));
    final p = dst.entities.whereType<PivotEntity>().single;
    final newGuide = dst.entities.whereType<AreaEntity>().where((a) => a.points.length == 4).single;
    expect(p.machine.guidePathId, newGuide.id);
    expect(p.machine.guidePathId, isNot('e3'), reason: 'e3 is another area in the target');
    expect(p.machine.vriZones.keys.single, isNot('e4'));
    expect(dst.byId(p.machine.vriZones.keys.single), isA<AreaEntity>());
    // the pivot alone: its references cannot be kept in another project…
    final alone = Project();
    pasteEntities(alone, [pivot.toJson()]);
    expect(alone.entities.whereType<PivotEntity>().single.machine.guidePathId, isNull);
    expect(alone.entities.whereType<PivotEntity>().single.machine.vriZones, isEmpty);
    // …but hold in the project it was copied from
    pasteEntities(src, [pivot.toJson()], sameProject: true);
    expect(src.entities.whereType<PivotEntity>().last.machine.guidePathId, 'e3');
  });

  test('valve-in-head stations of another project do not join the target\'s', () {
    final dst = Project();
    dst.entities.add(OutletEntity(id: dst.newId(), position: Pt.zero, scope: HydraulicScope.mainline, outletSpecId: 'rotor', zoneName: '1'));
    final heads = [
      for (var i = 0; i < 2; i++) OutletEntity(id: 'h$i', position: Pt(10.0 + i, 0), scope: HydraulicScope.mainline, outletSpecId: 'rotor', zoneName: '1').toJson(),
      OutletEntity(id: 'h9', position: const Pt(20, 0), scope: HydraulicScope.mainline, outletSpecId: 'rotor', zoneName: 'Tee 4').toJson(),
    ];
    pasteEntities(dst, heads);
    final names = [for (final o in dst.entities.whereType<OutletEntity>().skip(1)) o.zoneName];
    expect(names, ['2', '2', 'Tee 4'], reason: 'one new station for the heads that shared one; a free name stays');
  });

  test('prices follow the currency of the target', () {
    final src = Project()..setCurrency('USD', rate: exchangeRate('BRL', 'USD'));
    final usd = src.catalog.pipe('pvc50')!.costPerM;
    final ctl = ControllerEntity(id: 'c', position: Pt.zero, cost: 100, accessories: {'rain': 10});
    final pump = PumpEntity(id: 'p', position: Pt.zero, pumpSpecId: 'pump_c5', hourMeter: true, hourMeterCost: 50);
    final dst = Project()..catalog.pipes.removeWhere((p) => p.id == 'pvc50');
    final pipe = PipeEntity(id: 'e1', points: const [Pt(0, 0), Pt(1, 0)], scope: HydraulicScope.mainline, pipeSpecId: 'pvc50');
    final r = pasteEntities(dst, [pipe.toJson(), ctl.toJson(), pump.toJson()], catalog: catalogSubset(src.catalog, [pipe, pump]), currency: 'USD');
    final rate = exchangeRate('USD', 'BRL')!;
    expect(r.rate, rate);
    expect(dst.catalog.pipe('pvc50')!.costPerM, closeTo(usd * rate, 1e-9));
    final c2 = dst.entities.whereType<ControllerEntity>().single;
    expect(c2.cost, closeTo(100 * rate, 1e-9));
    expect(c2.accessories['rain'], closeTo(10 * rate, 1e-9));
    expect(dst.entities.whereType<PumpEntity>().single.hourMeterCost, closeTo(50 * rate, 1e-9));
    expect(dst.catalog.pumps.where((p) => p.id == 'pump_c5' || p.id.startsWith('pump_c5~')), hasLength(1), reason: 'the same pump at another price is the same item');
  });

  test('the workspace clipboard carries the currency and pastes through the core', () async {
    final w = Workspace(systemClipboard: false);
    final a = w.current;
    a.project.setCurrency('USD');
    a.project.catalog.pipes.add(userPipe('A', 70, 20));
    a.addEntities([
      PipeEntity(id: a.project.newId(), points: const [Pt(0, 0), Pt(5, 0)], scope: HydraulicScope.zone, pipeSpecId: 'pipe1'),
    ]);
    a.selectAll();
    await w.copy();
    expect(ClipboardPayload.tryParse(w.clipboard!.encode())!.currency, 'USD');
    final b = w.addTab();
    b.project.catalog.pipes.add(userPipe('B', 28, 3));
    expect(await w.paste(), 1);
    expect(b.project.entities.whereType<PipeEntity>().single.pipeSpecId, 'pipe1~2');
  });
}
