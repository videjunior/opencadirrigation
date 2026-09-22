import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/electrical.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/io/catalog_io.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

/// Controller at the origin; routes 0→(L,0)→(L,L/2) and (L,0)→(2L,0);
/// valve C in the middle of the first route (L/2), A at (L,L/2), B at (2L,0).
Project _site(double l, {int stations = 12}) {
  final p = Project();
  p.entities.addAll([
    ControllerEntity(id: 'ctl', position: Pt.zero, name: 'Ctrl', stations: stations, cost: 900),
    WireEntity(id: 'w1', points: [Pt.zero, Pt(l, 0), Pt(l, l / 2)]),
    WireEntity(id: 'w2', points: [Pt(l, 0), Pt(2 * l, 0)]),
    ControlValveEntity(id: 'vA', position: Pt(l, l / 2), zoneName: 'A'),
    ControlValveEntity(id: 'vB', position: Pt(2 * l, 0), zoneName: 'B'),
    ControlValveEntity(id: 'vC', position: Pt(l / 2, 0), zoneName: 'C'),
  ]);
  return p;
}

void main() {
  const all = [
    {'vA', 'vB', 'vC'},
  ];

  test('routes: nearest valve is station 1, a valve on a route joins it', () {
    final r = designElectrical(_site(100), flows: all)!;
    expect(r.warnings, isEmpty);
    final byValve = {for (final x in r.runs) x.valveId: x};
    expect(byValve['vC']!.routeM, closeTo(50, 1e-9));
    expect(byValve['vA']!.routeM, closeTo(150, 1e-9));
    expect(byValve['vB']!.routeM, closeTo(200, 1e-9));
    expect([for (final x in r.runs) x.station], [1, 2, 3]);
    expect(byValve['vB']!.station, 3);
    expect(byValve['vB']!.wireM, closeTo(220, 1e-9)); // +10 % slack
    final duty = r.controllers.single;
    expect(duty.used, 3);
    expect(duty.maxOpen, 3);
    expect(duty.commonRouteM, closeTo(250, 1e-9));
    expect(duty.peakCurrentA, closeTo(0.37 + 2 * 0.22, 1e-12));
  });

  test('solenoid voltage by hand (valve B opening, A and C holding)', () {
    final p = _site(100);
    // only 1.0 mm² wire enabled
    for (final w in p.catalog.wires) {
      w.enabled = w.id == 'w1';
    }
    final r = designElectrical(p, flows: all)!;
    final b = r.runs.firstWhere((x) => x.valveId == 'vB');
    final ohm = copperOhmPerKm(1.0);
    // station: 0.37 A over 220 m; common: 0.81 A × 55 m + 0.59 A × 55 m + 0.37 A × 110 m
    final expected = 24 - 0.37 * ohm * 0.220 - (0.81 * 55 + 0.59 * 55 + 0.37 * 110) / 1000 * ohm;
    expect(b.volts, closeTo(expected, 1e-9));
    expect(b.ok, isTrue);
    expect(b.stationWireId, 'w1');
    expect(b.commonWireId, 'w1');
  });

  test('valves in separate flows load the common wire less', () {
    final together = designElectrical(_site(400), flows: all)!;
    final apart = designElectrical(_site(400), flows: const [{'vA'}, {'vB'}, {'vC'}])!;
    double cost(ElectricalResult r, Catalog c) => r.wireMeters.entries.fold(0.0, (s, e) => s + e.value * c.wire(e.key)!.costPerM);
    final c = Project().catalog;
    expect(apart.controllers.single.maxOpen, 1);
    expect(apart.controllers.single.peakCurrentA, closeTo(0.37, 1e-12));
    expect(cost(apart, c), lessThanOrEqualTo(cost(together, c) + 1e-9));
    // same wires, fewer amps: never a lower voltage
    final a = designElectrical(_site(400), flows: const [{'vA'}, {'vB'}, {'vC'}])!;
    for (final run in a.runs) {
      expect(run.volts, greaterThanOrEqualTo(20 - 1e-9));
    }
  });

  test('long runs get thicker wires and the choice is the cheapest one', () {
    final p = _site(800);
    final r = designElectrical(p, flows: all)!;
    expect(r.runs.every((x) => x.ok), isTrue, reason: r.warnings.join(','));
    final far = r.runs.firstWhere((x) => x.valveId == 'vB');
    expect(p.catalog.wire(far.stationWireId)!.sectionMm2, greaterThan(1.0));
    // brute force over every common × station combination
    final wires = p.catalog.enabledWires;
    final routes = {for (final x in r.runs) x.valveId: x.routeM};
    const slack = 1.1;
    double commonDrop(String v) {
      // per Ω/km, with the others holding (all open together)
      final edges = <String, List<(double, Set<String>)>>{
        'vC': [(400, {'vA', 'vB', 'vC'})],
        'vA': [(400, {'vA', 'vB', 'vC'}), (400, {'vA', 'vB'}), (400, {'vA'})],
        'vB': [(400, {'vA', 'vB', 'vC'}), (400, {'vA', 'vB'}), (800, {'vB'})],
      };
      var d = 0.0;
      for (final (len, users) in edges[v]!) {
        final amps = users.fold(0.0, (s, u) => s + (u == v ? 0.37 : 0.22));
        d += amps * len * slack / 1000;
      }
      return d;
    }

    var best = double.infinity;
    for (final cw in wires) {
      var cost = 2000 * slack * cw.costPerM;
      var ok = true;
      for (final v in ['vA', 'vB', 'vC']) {
        final feasible = wires.where((sw) => 24 - 0.37 * sw.ohmPerKm * routes[v]! * slack / 1000 - commonDrop(v) * cw.ohmPerKm >= 20 - 1e-9).toList();
        if (feasible.isEmpty) {
          ok = false;
          break;
        }
        cost += routes[v]! * slack * feasible.map((w) => w.costPerM).reduce(math.min);
      }
      if (ok) best = math.min(best, cost);
    }
    final got = r.wireMeters.entries.fold(0.0, (s, e) => s + e.value * p.catalog.wire(e.key)!.costPerM);
    expect(got, closeTo(best, 1e-6));
  });

  test('a run no wire can serve is reported with the thickest wire', () {
    final p = _site(20000);
    final r = designElectrical(p, flows: all)!;
    expect(r.warnings, contains('elec_voltage:vB'));
    final far = r.runs.firstWhere((x) => x.valveId == 'vB');
    expect(far.ok, isFalse);
    expect(far.stationWireId, p.catalog.enabledWires.last.id);
  });

  test('problems: unwired valve, orphan route, too few stations, no controller', () {
    final p = _site(100, stations: 2);
    p.entities.add(ControlValveEntity(id: 'vX', position: const Pt(500, 500), zoneName: 'X'));
    p.entities.add(WireEntity(id: 'w9', points: const [Pt(900, 900), Pt(950, 900)]));
    p.entities.add(ControllerEntity(id: 'ctl2', position: const Pt(-300, -300)));
    final r = designElectrical(p, flows: all)!;
    expect(r.warnings, containsAll(['elec_unwired:vX', 'elec_wire_orphan:w9', 'elec_stations:ctl', 'elec_ctrl_unwired:ctl2']));
    expect(r.controllers.firstWhere((c) => c.controllerId == 'ctl').overloaded, isTrue);
    expect(r.controllers.firstWhere((c) => c.controllerId == 'ctl2').used, 0);

    final noCtrl = Project()..entities.add(WireEntity(id: 'w', points: const [Pt.zero, Pt(5, 0)]));
    expect(designElectrical(noCtrl)!.warnings, ['elec_no_controller']);
    expect(designElectrical(Project()), isNull);
  });

  test('a controller that opens fewer stations than a flow asks is reported', () {
    final p = _site(100);
    (p.byId('ctl') as ControllerEntity).maxSimultaneous = 2;
    expect(designElectrical(p, flows: all)!.warnings, contains('elec_simultaneous:ctl'));
    expect(designElectrical(p, flows: const [{'vA', 'vB'}])!.warnings, isNot(contains('elec_simultaneous:ctl')));
  });

  test('without catalogue wires a 1.5 mm² conductor is assumed and reported', () {
    final p = _site(100);
    p.catalog.wires.clear();
    final r = designElectrical(p, flows: all)!;
    expect(r.warnings, contains('elec_no_wires'));
    expect(r.runs.first.stationWireId, isNull);
    expect(r.wireMeters, isEmpty);
    expect(r.runs.every((x) => x.volts < 24 && x.volts > 20), isTrue);
  });

  test('results round-trip through JSON', () {
    final r = designElectrical(_site(800), flows: all)!;
    final back = ElectricalResult.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
    expect(back.runs.length, r.runs.length);
    expect(back.runOf('vB')!.volts, closeTo(r.runOf('vB')!.volts, 1e-12));
    expect(back.runOf('vB')!.stationWireId, r.runOf('vB')!.stationWireId);
    expect(back.controllers.single.commonWireId, r.controllers.single.commonWireId);
    expect(back.wireMeters, r.wireMeters);
    final dr = DesignResults(timestamp: DateTime(2026))..electrical = r;
    expect(DesignResults.fromJson(jsonDecode(jsonEncode(dr.toJson())) as Map<String, dynamic>).electrical!.runs.length, 3);
    expect(DesignResults.fromJson(DesignResults(timestamp: DateTime(2026)).toJson()).electrical, isNull);
  });

  test('the design sizes the wiring and lists wires, controller and splices', () {
    final p = _site(300);
    // a small hydraulic network so the design runs
    p.entities.addAll([
      WaterSupplyEntity(id: 'ws', position: const Pt(0, -20), calculatePressure: false, designHeadM: 40, maxHeadM: 60, designFlow: 20 * m3sPerM3h, maxFlow: 30 * m3sPerM3h),
      PipeEntity(id: 'mp', points: const [Pt(0, -20), Pt(150, -20), Pt(150, 0)], scope: HydraulicScope.mainline),
    ]);
    final r = Designer(p).designAll();
    expect(r.electrical, isNotNull);
    expect(r.electrical!.runs.length, 3);
    final lines = r.bom.where((l) => l.category == 'bom.electrical').toList();
    expect(lines.any((l) => l.description.startsWith('Ctrl') && l.unitCost == 900), isTrue);
    expect(lines.firstWhere((l) => l.description == 'elec.splice').quantity, 6);
    final metres = lines.where((l) => l.unit == 'm').fold(0.0, (s, l) => s + l.quantity);
    expect(metres, closeTo(r.electrical!.wireMeters.values.fold(0.0, (s, v) => s + v), 1e-6));
    // no system flows: every valve is on together, as the hydraulic design assumes
    expect(r.electrical!.controllers.single.maxOpen, 3);
  });

  test('entities: controller and wire round-trip, transform and pick', () {
    final c = ControllerEntity(id: 'c', position: const Pt(1, 2), stations: 24, outputVolts: 26.5, cost: 10, maxSimultaneous: 2);
    final w = WireEntity(id: 'w', points: const [Pt(0, 0), Pt(10, 0)]);
    final c2 = Entity.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>) as ControllerEntity;
    expect([c2.stations, c2.outputVolts, c2.cost, c2.maxSimultaneous, c2.layer], [24, 26.5, 10, 2, Layers.controllers]);
    final w2 = Entity.fromJson(w.toJson()) as WireEntity;
    expect(w2.points, w.points);
    expect(w2.layer, Layers.wires);
    expect(w.transformed(Affine.translation(const Pt(1, 1))).points.first, const Pt(1, 1));
    expect(c.translated(const Pt(1, 0)).position, const Pt(2, 2));
    expect(w.distanceTo(const Pt(5, 1)), closeTo(1, 1e-12));
    expect(w.length, 10);
  });

  test('wire catalogue: defaults, AWG, CSV and JSON round trips', () {
    final cat = Catalog.defaultCatalog(lang: 'pt');
    expect(cat.wires.where((w) => w.enabled).map((w) => w.sectionMm2), [1.0, 1.5, 2.5, 4.0, 6.0, 10.0]);
    expect(cat.wires.firstWhere((w) => w.id == 'awg14').sectionMm2, closeTo(2.08, 0.01));
    expect(cat.wires.first.name, startsWith('Fio de cobre'));
    expect(awgMm2(12), closeTo(3.31, 0.01));
    expect(copperOhmPerKm(2.5), closeTo(7.24, 0.01));
    expect(cat.enabledWires.first.sectionMm2, 1.0);
    expect(cat.wire('w2.5')!.resistance(1000), closeTo(copperOhmPerKm(2.5), 1e-9));
    final csv = CatalogIo.exportCsv(cat, CatalogGroup.wires);
    final back = CatalogIo.parseCsv(csv);
    expect(back.group, CatalogGroup.wires);
    expect(back.catalog.wires.length, cat.wires.length);
    expect(back.catalog.wire('w4')!.costPerM, cat.wire('w4')!.costPerM);
    // AWG columns without a section
    final awg = CatalogIo.parseCsv('id;name;awg;cost\nx;Cable 14;14;2');
    expect(awg.catalog.wires.single.sectionMm2, closeTo(2.08, 0.01));
    expect(awg.catalog.wires.single.ohmPerKm, closeTo(copperOhmPerKm(awgMm2(14)), 1e-9));
    final json = Catalog.fromJson(jsonDecode(jsonEncode(cat.toJson())) as Map<String, dynamic>);
    expect(json.wires.length, cat.wires.length);
    expect(json.itemCount, cat.itemCount);
    // an old catalogue without wires stays without them
    expect(Catalog.fromJson({'pipes': []}).wires, isEmpty);
    expect(Catalog.fromJson({'pipes': []}).toJson().containsKey('wires'), isFalse);
    // xlsx carries the wires sheet
    final x = CatalogIo.parseXlsx(CatalogIo.exportXlsx(cat));
    expect(x.catalog.wires.length, cat.wires.length);
    // merge and ids
    final other = Catalog(wires: [WireSpec(id: 'w1', name: 'x', sectionMm2: 1, ohmPerKm: 18)]);
    expect(cat.merge(other, replace: true), 1);
    expect(cat.wire('w1')!.name, 'x');
    expect(cat.newId('w'), isNot(anyOf('w1', 'w4')));
    expect(WireSpec.fromJson({'id': 'a', 'name': 'a', 'mm2': 4}).ohmPerKm, closeTo(copperOhmPerKm(4), 1e-9));
  });
}
