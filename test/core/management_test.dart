import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/management.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/hydraulics/uniformity.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

/// Zones A…: each a valve feeding [n] micro-sprinklers of 50 L/h.
Project _zones(List<int> emitters, {double supplyFlowM3h = 0}) {
  final p = Project();
  p.entities.add(WaterSupplyEntity(id: 'ws', position: const Pt(-10, 0), designFlow: supplyFlowM3h * m3sPerM3h));
  for (var k = 0; k < emitters.length; k++) {
    final y = k * 20.0;
    final name = String.fromCharCode(65 + k);
    p.entities.add(ControlValveEntity(id: 'v$name', position: Pt(0, y), zoneName: name));
    p.entities.add(PipeEntity(id: 'z$name', points: [Pt(0, y), Pt(emitters[k] * 2.0, y)], scope: HydraulicScope.zone));
    for (var i = 1; i <= emitters[k]; i++) {
      p.entities.add(OutletEntity(id: 'o$name$i', position: Pt(i * 2.0, y), outletSpecId: 'micro', nozzleId: 'm50', headM: 15));
    }
  }
  return p;
}

void main() {
  test('demands: zone valves and pivots in drawing order, named by zone', () {
    final p = _zones([2, 1]);
    p.entities.add(PivotEntity(id: 'pv', center: const Pt(500, 0), radiusM: 200, zoneName: 'Pivô'));
    p.entities.insert(0, ControlValveEntity(id: 'vx', position: const Pt(-50, -50), name: 'Solo'));
    expect(demandIds(p), ['vx', 'vA', 'vB', 'pv']);
    expect(demandName(p, 'vA'), 'A');
    expect(demandName(p, 'pv'), 'Pivô');
    expect(demandName(p, 'vx'), 'Solo');
    expect(demandName(p, 'nope'), 'nope');
  });

  test('nominal demands: emitters at nominal pressure, pivots from the machine, results first', () {
    final p = _zones([4, 2]);
    p.entities.add(PivotEntity(id: 'pv', center: const Pt(500, 0), radiusM: 200, grossDepthMm: 8, hoursPerCycle: 24));
    final q = nominalDemands(p);
    expect(q['vA']! / m3sPerLph, closeTo(200, 1e-6));
    expect(q['vB']! / m3sPerLph, closeTo(100, 1e-6));
    expect(q['pv'], closeTo(Designer(p).analyzePivotEntity(p.byId('pv') as PivotEntity).flow, 1e-12));
    final r = DesignResults(timestamp: DateTime(2026));
    r.zones['vA'] = ZoneResult(
      valveId: 'vA', zoneName: 'A', converged: true, totalFlow: 0.123, downstreamHead: 0, valveLoss: 0, requiredUpstreamHead: 0, minOutletPressure: 0, maxOutletPressure: 0,
      allowedMin: 0, allowedMax: 0, nominalPressure: 0, uniformity: UniformityStats.empty, pipes: const [], outlets: const [], devices: const [], warnings: const [], valveElevation: 0,
    );
    expect(nominalDemands(p, results: r)['vA'], 0.123);
  });

  test('automatic flows pack the largest demands first within the supply flow', () {
    // 300, 250, 200, 150, 100 L/h with a 0.5 m³/h supply
    final p = _zones([6, 5, 4, 3, 2], supplyFlowM3h: 0.5);
    final plan = autoSystemFlows(p, AutoFlowOptions(durationHours: 2, firstStartHour: 22), label: (k) => k == 'name.flow' ? 'Turno' : k);
    expect(plan.capacity, closeTo(0.5 * m3sPerM3h, 1e-12));
    expect(plan.oversized, isEmpty);
    // first fit decreasing: {300+200}, {250+150+100}
    final sets = plan.flows.map((f) => f.valveIds.toSet()).toList();
    expect(sets, containsAll([{'vA', 'vC'}, {'vB', 'vD', 'vE'}]));
    expect(plan.flows.length, 2);
    for (final f in plan.flows) {
      expect(f.valveIds.fold(0.0, (s, id) => s + plan.demands[id]!), lessThanOrEqualTo(plan.capacity + 1e-12));
      expect(f.durationHours, 2);
      expect(f.name, startsWith('Turno '));
    }
    // one after the other, wrapping past midnight
    expect(plan.flows[0].startHour, 22);
    expect(plan.flows[1].startHour, 0);
    expect(plan.flows[0].name, contains('A + C'));
    expect(peakFlowDemand(plan.flows, plan.demands) / m3sPerLph, closeTo(500, 1e-6));
  });

  test('a limit on the number of zones splits further', () {
    final p = _zones([1, 1, 1, 1, 1]);
    final plan = autoSystemFlows(p, AutoFlowOptions(maxValves: 2));
    expect(plan.capacity, 0); // the supply states no design flow
    expect(plan.flows.map((f) => f.valveIds.length), [2, 2, 1]);
    // no limit at all: everything together
    expect(autoSystemFlows(p, AutoFlowOptions()).flows.single.valveIds.length, 5);
  });

  test('a zone larger than the limit gets a flow of its own and is reported', () {
    final p = _zones([10, 1, 1]);
    final plan = autoSystemFlows(p, AutoFlowOptions(maxFlow: 200 * m3sPerLph));
    expect(plan.oversized, ['vA']);
    expect(plan.flows.first.valveIds, {'vA'});
    expect(plan.flows.length, 2);
    expect(plan.flows.last.valveIds, {'vB', 'vC'});
  });

  test('new flow ids never collide with the flows being replaced', () {
    final p = _zones([1, 1]);
    p.systemFlows.add(SystemFlow(id: 'sf1', name: 'old', valveIds: {'vB'}));
    final plan = autoSystemFlows(p, AutoFlowOptions(maxValves: 1));
    final ids = plan.flows.map((f) => f.id).toList();
    expect(ids.toSet().length, 2);
    expect(ids.first, isNot('sf1'));
    // a flow identical to an existing one keeps its id
    p.systemFlows
      ..clear()
      ..add(SystemFlow(id: 'sf1', name: 'old', valveIds: {'vA'}));
    expect(autoSystemFlows(p, AutoFlowOptions(maxValves: 1)).flows.first.id, 'sf1');
  });

  test('supplies design flow is known only when every supply states it', () {
    final p = _zones([1], supplyFlowM3h: 3);
    expect(suppliesDesignFlow(p), closeTo(3 * m3sPerM3h, 1e-12));
    p.entities.add(WaterSupplyEntity(id: 'ws2', position: const Pt(0, 99), designFlow: 2 * m3sPerM3h));
    expect(suppliesDesignFlow(p), closeTo(5 * m3sPerM3h, 1e-12));
    p.entities.add(WaterSupplyEntity(id: 'ws3', position: const Pt(0, 199)));
    expect(suppliesDesignFlow(p), 0);
    expect(suppliesDesignFlow(Project()), 0);
  });
}
