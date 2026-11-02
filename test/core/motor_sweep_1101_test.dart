/// Engine findings of the sweep of 2026-11-01 (MOT-03 onwards): each test
/// failed before its fix.
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/block_generator.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/lp.dart';
import 'package:opencadirrigation/core/design/lp_sizing.dart';
import 'package:opencadirrigation/core/design/network_builder.dart';
import 'package:opencadirrigation/core/design/pump_selection.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/design/tariff.dart';
import 'package:opencadirrigation/core/hydraulics/network.dart';
import 'package:opencadirrigation/core/hydraulics/water_hammer.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

/// One micro-sprinkler zone of 120 × 45 m fed by a 100 m mainline from a
/// tank (or a well), its valve at the middle of the submain.
(Project, ControlValveEntity, Pt supply, PipeEntity stub) _zone({double width = 120, double height = 45, double stub = 1.5, double headM = 15}) {
  final p = Project();
  final block = generateBlock(
    p,
    BlockOptions(
      polygon: [const Pt(0, 0), Pt(width, 0), Pt(width, height), Pt(0, height)],
      direction: const Pt(1, 0),
      lateralSpacing: 4,
      outletSpecId: 'micro',
      nozzleId: 'm50',
      outletSpacing: 3.5,
      headM: headM,
      submainPosition: SubmainPosition.start,
      valveSpecId: 'ev50',
      valvePosition: ValvePosition.centre,
      submainStub: stub,
      zoneName: 'Zona 1',
    ),
  );
  p.entities.addAll(block.all);
  final valve = block.valve!;
  final supplyPos = valve.position + const Pt(-100, 0);
  p.entities.add(PipeEntity(id: 'main', points: [supplyPos, valve.position], scope: HydraulicScope.mainline, name: 'Main'));
  return (p, valve, supplyPos, block.stub!);
}

void main() {
  group('MOT-03: a device drawn on the zone valve is in the way of the water', () {
    test('a filter on the valve (mainline) passes the zone flow and its loss', () {
      final (p, valve, supply, _) = _zone();
      p.entities.add(WaterSupplyEntity(id: 'tank', position: supply, name: 'Tank', calculatePressure: true, designHeadM: 0, waterLevelOffsetM: 1.5));
      p.entities.add(PumpEntity(id: 'pump', position: Pt(supply.x + 5, supply.y), pumpSpecId: 'pump_mid', name: 'Pump'));
      p.entities.add(MiscHydraulicEntity(id: 'filt', position: valve.position, valveSpecId: 'filter_screen80', name: 'filter at valve'));
      final r = Designer(p).designAll();
      final f = r.systemFlows.single;
      final filt = f.devices.firstWhere((d) => d.entityId == 'filt');
      expect(filt.flow, closeTo(f.totalFlow, 1e-9), reason: 'it passed 0 m³/h while the zone drew 18.7');
      expect(filt.headLoss, greaterThan(0.05));
      final pump = f.devices.firstWhere((d) => d.entityId == 'pump');
      expect(f.valves.single.availableHead, closeTo(pump.downstreamPressure - filt.headLoss - (pump.downstreamPressure - filt.upstreamPressure), 1e-6));
    });

    for (final (spec, setting) in [('prv50', 12.0), ('filter_disc50', 0.0)]) {
      test('$spec on the valve (zone scope) carries the zone flow', () {
        final (p, valve, supply, _) = _zone(width: 60, height: 30);
        p.entities.add(MiscHydraulicEntity(id: 'dev', position: valve.position, valveSpecId: spec, scope: HydraulicScope.zone, settingM: setting, name: spec));
        p.entities.add(WaterSupplyEntity(id: 'tank', position: supply, name: 'Tank', calculatePressure: true, designHeadM: 0, waterLevelOffsetM: 0));
        final m = NetworkBuilder(p).build();
        final (_, zoneNode) = m.valveNodes[valve.id]!;
        final dev = m.links.firstWhere((l) => l.entityId == 'dev');
        expect(dev.from, zoneNode, reason: 'the device follows the valve');
        expect(m.nodes[zoneNode]!.links.where((l) => l.kind == GLinkKind.pipe), isEmpty, reason: 'every zone pipe after the device');
        final r = Designer(p).designAll();
        final z = r.zones.values.single;
        final d = z.devices.firstWhere((d) => d.entityId == 'dev');
        expect(d.flow, closeTo(z.totalFlow, 1e-6 * z.totalFlow), reason: 'it was a dead end with 0 m³/h');
        expect(z.downstreamHead, lessThan(60));
      });
    }

    test('a device at the centre of a pivot feeds the pivot', () {
      final p = Project();
      p.entities.add(WaterSupplyEntity(id: 'well', position: const Pt(-200, 0), name: 'Well', calculatePressure: true));
      p.entities.add(PipeEntity(id: 'main', points: [const Pt(-200, 0), Pt.zero], scope: HydraulicScope.mainline, name: 'Main'));
      p.entities.add(PivotEntity(id: 'pv', center: Pt.zero, radiusM: 300, name: 'Pivot'));
      p.entities.add(MiscHydraulicEntity(id: 'filt', position: Pt.zero, valveSpecId: 'filter_screen80', name: 'filter'));
      final m = NetworkBuilder(p).build();
      final dev = m.links.firstWhere((l) => l.entityId == 'filt');
      expect(m.pivotNodes['pv'], dev.to);
      final r = Designer(p).designAll();
      final f = r.systemFlows.single;
      final d = f.devices.firstWhere((d) => d.entityId == 'filt');
      expect(r.pivots['pv']!.flow, greaterThan(0));
      expect(d.flow, closeTo(r.pivots['pv']!.flow, 1e-9));
    });
  });

  test('MOT-04: an FCV keeps its flow setting when another device is stacked on it', () {
    final (p, _, supply, _) = _zone();
    p.entities.add(WaterSupplyEntity(id: 'tank', position: supply, name: 'Tank', calculatePressure: true, designHeadM: 0, waterLevelOffsetM: 1.5));
    p.entities.add(PumpEntity(id: 'pump', position: Pt(supply.x + 5, supply.y), pumpSpecId: 'pump_mid', name: 'Pump'));
    final at = Pt(supply.x + 50, supply.y);
    p.entities.add(MiscHydraulicEntity(id: 'fcv', position: at, valveSpecId: 'fcv80', name: 'fcv', settingFlow: 60 * m3sPerM3h));
    p.entities.add(MiscHydraulicEntity(id: 'chk', position: at, valveSpecId: 'check80', name: 'check'));
    final m = NetworkBuilder(p).build();
    expect(m.links.firstWhere((l) => l.kind == GLinkKind.fcv).settingFlow, closeTo(60 * m3sPerM3h, 1e-12), reason: 'it was 0 m³/h after the move');
    final f = Designer(p).designAll().systemFlows.single;
    final fcv = f.devices.firstWhere((d) => d.entityId == 'fcv');
    expect(fcv.flow, closeTo(f.totalFlow, 1e-9));
    expect(f.supplies.single.requiredHead, lessThan(100), reason: 'it asked for 519 371 m');
    expect(f.warnings, isNot(contains('pressure_rating_exceeded:main')));
  });

  test('MOT-05: a surface pump drawn on the well is checked for its suction lift', () {
    for (final onWell in [false, true]) {
      final (p, _, supply, _) = _zone();
      p.entities.add(WaterSupplyEntity(id: 'well', position: supply, name: 'Well', calculatePressure: true, designHeadM: 0, waterLevelOffsetM: -12));
      p.entities.add(PumpEntity(id: 'pump', position: onWell ? supply : Pt(supply.x + 5, supply.y), pumpSpecId: 'pump_big', name: 'Pump'));
      final f = Designer(p).designAll().systemFlows.single;
      final d = f.devices.firstWhere((d) => d.entityId == 'pump');
      expect(f.warnings, contains('pump_suction_lift:pump'), reason: 'on the well: $onWell');
      expect(d.upstreamPressure, lessThan(-11.9), reason: 'the inlet stands on the ground, 12 m above the water');
      expect(d.elevation, closeTo(0, 1e-9));
    }
    // a submersible pump in the well has no suction lift
    final (p, _, supply, _) = _zone();
    p.entities.add(WaterSupplyEntity(id: 'well', position: supply, name: 'Well', calculatePressure: true, designHeadM: 0, waterLevelOffsetM: -12));
    p.entities.add(PumpEntity(id: 'pump', position: supply, pumpSpecId: 'pump_sub', name: 'Pump'));
    final f = Designer(p).designAll().systemFlows.single;
    expect(f.warnings, isNot(contains('pump_suction_lift:pump')));
  });

  test('MOT-06: a PRV of the zone set below what the emitters need leaves a finite valve head and says why', () {
    for (final setting in [25.0, 8.0]) {
      final (p, _, supply, stub) = _zone(stub: 6);
      final mid = (stub.points.first + stub.points.last) * 0.5;
      p.entities.add(MiscHydraulicEntity(id: 'zprv', position: mid, valveSpecId: 'prv50', scope: HydraulicScope.zone, settingM: setting, name: 'zone PRV'));
      p.entities.add(WaterSupplyEntity(id: 'tank', position: supply, name: 'Tank', calculatePressure: true, designHeadM: 0, waterLevelOffsetM: 0));
      final r = Designer(p).analyzeAll();
      final z = r.zones.values.single;
      expect(z.downstreamHead, lessThan(setting + 30), reason: 'it was 4.7·10⁷ m');
      expect(z.warnings, contains('zone_pressure_unreachable:zprv'));
      expect(r.systemFlows.single.supplies.single.requiredHead, lessThan(200));
      // at the head found the zone already gets all the PRV lets through
      final more = Designer(p).analyzeZone(z.valveId, downstreamHead: z.downstreamHead + 20);
      expect(more.totalFlow, closeTo(z.totalFlow, 0.01 * z.totalFlow));
    }
  });

  test('MOT-07: a demand behind a closed link is reported, not drawn through it', () {
    for (final closed in [HLinkKind.closed, HLinkKind.fcv]) {
      final n = HydraulicNetwork()
        ..addNode(HNode(id: 'R', kind: HNodeKind.reservoir, elevation: 0, fixedHead: 30))
        ..addNode(HNode(id: 'A', elevation: 0))
        ..addNode(HNode(id: 'B', elevation: 2, demand: 0.002))
        ..addNode(HNode(id: 'C', elevation: 1, demand: 0.001))
        ..addLink(HLink(id: 'p1', from: 'R', to: 'A', diameter: 0.1, length: 100))
        // an FCV set to no flow shuts like a closed link
        ..addLink(HLink(id: 'v', from: 'A', to: 'B', kind: closed, fcvFlow: 0))
        ..addLink(HLink(id: 'p2', from: 'B', to: 'C', diameter: 0.05, length: 10));
      final r = n.solve();
      expect(r.converged, isTrue);
      expect(r.warnings, contains('demand_disconnected:B'), reason: '$closed: the largest demand of the part names it');
      expect(r.warnings.where((w) => w.startsWith('demand_disconnected')), hasLength(1));
      expect(r.nodes['B']!.pressure, 0, reason: 'it was −199 970 m');
      expect(r.nodes['C']!.pressure, 0);
      expect(r.links['v']!.flow.abs(), lessThan(1e-6));
      expect(r.links['p1']!.flow.abs(), lessThan(1e-6), reason: 'the rest of the network does not feed it');
      expect(r.nodes['A']!.head, closeTo(30, 1e-6));
    }
  });

  test('MOT-08: a feasible sizing LP of 50 units and 7 diameters is solved, not reported infeasible', () {
    // pressure rows mixing losses of 0.3 to 900 m (the shape of lpSize):
    // unscaled, the first phase stalled for 61 050 iterations (24 s) and the
    // design fell back on the greedy method as if no sizing existed
    final rnd = math.Random(1);
    final specs = [
      for (final (d, c) in [(26.0, 1.0), (32.0, 1.5), (40.0, 2.2), (50.0, 3.4), (63.0, 5.0), (75.0, 7.0), (100.0, 12.0)])
        PipeSpec(id: 'p$d', name: 'p$d', nominalMm: d, innerDiameterMm: d * 0.9, costPerM: c),
    ];
    const nUnits = 50;
    final units = [for (var i = 0; i < nUnits; i++) 'u$i'];
    final len = {for (final u in units) u: 50.0 + rnd.nextDouble() * 100};
    final constraints = <LpHeadConstraint>[];
    for (var k = 0; k < nUnits * 3; k++) {
      final u = k % nUnits;
      final by = <String, Map<String, double>>{
        for (final pu in <String>{'u0', 'u${(u ~/ 10) * 10}', 'u$u'}) pu: {for (final s in specs) s.id: 2000 / math.pow(s.innerDiameterMm, 4.871) * 1e6 * (0.5 + rnd.nextDouble())},
      };
      constraints.add(LpHeadConstraint(headVar: 0, lossByUnitSpec: by, minPressure: 10, maxPressure: 13 + rnd.nextDouble()));
    }
    // feasible: every window holds some head with the largest pipes
    var lo = -double.infinity, hi = double.infinity;
    for (final c in constraints) {
      final l = c.lossByUnitSpec.values.fold(0.0, (s, m) => s + m['p100.0']!);
      lo = math.max(lo, c.minPressure! + l);
      hi = math.min(hi, c.maxPressure! + l);
    }
    expect(lo, lessThan(hi));
    final sw = Stopwatch()..start();
    final a = lpSize(
      LpSizingInput(
        units: units,
        candidates: {for (final u in units) u: specs},
        unitLength: len,
        maxSizes: {for (final u in units) u: 2},
        headVars: [LpHeadVar(energyPerMetre: 10)],
        constraints: constraints,
        crf: 0.1,
        tradeCapital: true,
      ),
    );
    expect(a.feasible, isTrue, reason: '${a.message} after ${a.iterations} iterations');
    expect(a.iterations, lessThan(5000));
    // and with four diameters, whatever the data (some seeds cycled on
    // degenerate vertices until the limit: 53 550 iterations)
    for (final seed in [2, 3, 4, 6]) {
      final rnd = math.Random(seed);
      final narrow = specs.take(4).toList();
      final len = {for (final u in units) u: 50.0 + rnd.nextDouble() * 100};
      final cs = <LpHeadConstraint>[];
      for (var k = 0; k < nUnits * 3; k++) {
        final u = k % nUnits;
        cs.add(
          LpHeadConstraint(
            headVar: 0,
            lossByUnitSpec: {
              for (final pu in <String>{'u0', 'u${(u ~/ 10) * 10}', 'u$u'}) pu: {for (final s in narrow) s.id: (0.5 + rnd.nextDouble()) * math.pow(40 / s.innerDiameterMm, 4.871)},
            },
            minPressure: 10,
            maxPressure: 13 + rnd.nextDouble(),
          ),
        );
      }
      final b = lpSize(
        LpSizingInput(
          units: units,
          candidates: {for (final u in units) u: narrow},
          unitLength: len,
          maxSizes: {for (final u in units) u: 2},
          headVars: [LpHeadVar(energyPerMetre: 10)],
          constraints: cs,
          crf: 0.1,
          tradeCapital: true,
        ),
      );
      expect(b.feasible, isTrue, reason: 'seed $seed: ${b.message} after ${b.iterations} iterations');
      expect(b.iterations, lessThan(3000), reason: 'seed $seed');
    }
    expect(sw.elapsedMilliseconds, lessThan(5000));
    expect(a.heads.single, greaterThanOrEqualTo(lo - 1e-6), reason: 'no less head than the largest pipes need');
    // an iteration limit is told apart from infeasibility
    final p = LpProblem(0);
    final x = p.addVariable(1), y = p.addVariable(1);
    p.add({x: 1, y: 1}, LpSense.ge, 1);
    p.add({x: 1, y: -1}, LpSense.eq, 0.25);
    expect(solveLp(p, maxIterations: 0).status, LpStatus.iterationLimit);
    expect(solveLp(p).status, LpStatus.optimal);
  });

  test('MOT-09: a zone on a slope beyond its pressure window keeps its cheaper pipes and says why', () {
    double cost(double slopePct, List<String> warnings, Set<String> names) {
      final (p, _, supply, _) = _zone();
      for (final (x, y) in [(-200.0, -200.0), (400.0, -200.0), (-200.0, 300.0), (400.0, 300.0), (0.0, 0.0), (120.0, 0.0), (0.0, 45.0), (120.0, 45.0)]) {
        p.entities.add(SpotHeightEntity(id: p.newId(), position: Pt(x, y), elevation: 100 - slopePct / 100 * x));
      }
      p.entities.add(WaterSupplyEntity(id: 'tank', position: supply, name: 'Tank', calculatePressure: true, designHeadM: 0, waterLevelOffsetM: 0));
      final z = Designer(p).designAll().zones.values.single;
      warnings.addAll(z.warnings);
      names.addAll(z.pipes.map((x) => x.pipeName));
      return z.pipeCost;
    }

    final flat = <String>[], steep = <String>[];
    final steepPipes = <String>{};
    final c0 = cost(0, flat, {});
    final c6 = cost(6, steep, steepPipes);
    expect(flat, isEmpty);
    // 7.2 m of ground across a 3 m window: the submain went to DN100 (+15 %)
    // and the window was missed all the same
    expect(steep, contains('zone_slope_exceeds_window'));
    expect(steep, isNot(contains('cannot_meet_pressure_window')));
    expect(steepPipes.where((n) => n.contains('DN 100')), isEmpty);
    expect(c6, lessThanOrEqualTo(c0 + 1e-6));
  });

  test('MOT-10: the surge screening of a mainline drawn in pieces runs along the whole water path', () {
    // 2 000 m of PVC DN100 in four pieces of 500 m, a valve closing in 6 s:
    // over one piece tc = 2.67 s and the surge at the valve end was cut to
    // tc/6 of Joukowsky's, on the unsafe side
    final p = Project();
    p.params.valveClosureTimeS = 6;
    p.entities.add(WaterSupplyEntity(id: 'tank', position: Pt.zero, name: 'Tank', calculatePressure: true));
    for (var i = 0; i < 4; i++) {
      p.entities.add(PipeEntity(id: 'm$i', points: [Pt(500.0 * i, 0), Pt(500.0 * (i + 1), 0)], scope: HydraulicScope.mainline, name: 'M$i', pipeSpecId: 'pvc100', computerSized: false));
    }
    final block = generateBlock(
      p,
      BlockOptions(
        polygon: const [Pt(2001.5, -30), Pt(2121.5, -30), Pt(2121.5, 30), Pt(2001.5, 30)],
        direction: const Pt(0, 1),
        lateralSpacing: 4,
        outletSpecId: 'micro',
        nozzleId: 'm50',
        outletSpacing: 3.5,
        headM: 15,
        submainPosition: SubmainPosition.start,
        valveSpecId: 'ev50',
        valvePosition: ValvePosition.centre,
        submainStub: 1.5,
        zoneName: 'Z',
      ),
    );
    p.entities.addAll(block.all);
    p.entities.add(PipeEntity(id: 'link', points: [const Pt(2000, 0), block.valve!.position], scope: HydraulicScope.mainline, name: 'L', pipeSpecId: 'pvc100', computerSized: false));
    final r = Designer(p).designAll();
    for (var i = 0; i < 4; i++) {
      final s = r.surge.firstWhere((x) => x.entityId == 'm$i');
      // the far end of piece i lies 500·(i + 1) m from the tank
      expect(s.pathLength, closeTo(500.0 * (i + 1), 1e-6), reason: 'm$i');
      expect(s.criticalTime, closeTo(2 * s.pathLength / s.celerity, 1e-9));
      final joukowsky = joukowskySurgeHead(celerity: s.celerity, velocityChange: s.velocity);
      // Michaud: 2·x·V/(g·T) from the tank, never above Joukowsky
      expect(s.surgeHead, lessThanOrEqualTo(math.min(joukowsky, 2 * s.pathLength * s.velocity / (9.80665 * 6)) + 1e-9), reason: 'm$i');
    }
    final last = r.surge.firstWhere((x) => x.entityId == 'm3');
    expect(last.criticalTime, greaterThan(6), reason: 'the closure is faster than 2L/a over the whole line');
    expect(
      last.surgeHead,
      closeTo(joukowskySurgeHead(celerity: last.celerity, velocityChange: last.velocity), 1e-9),
      reason: 'the full surge at the valve end',
    );
    // the first piece, next to the tank, gets the share of its distance
    final first = r.surge.firstWhere((x) => x.entityId == 'm0');
    expect(first.surgeHead, lessThan(last.surgeHead));
  });

  test('MOT-11: the operating range of a pump scales with its speed; below its minimum flow; boosters of a zone too', () {
    const h = m3sPerM3h;
    PumpSpec spec({double minFlow = 0, double maxFlow = 20}) =>
        PumpSpec(id: 'p60', name: '60 Hz', points: [(0.0, 60.0), (10 * h, 55.0), (20 * h, 45.0), (30 * h, 30.0)], ratedHz: 60, minFlow: minFlow * h, maxFlow: maxFlow * h, powerKw: 5.5);
    List<String> flowWarnings(double mainsHz, PumpSpec s) {
      final (p, _, supply, _) = _zone();
      p.params.mainsHz = mainsHz;
      p.catalog.pumps.add(s);
      p.entities.add(WaterSupplyEntity(id: 'tank', position: supply, name: 'Tank', calculatePressure: true, designHeadM: 0, waterLevelOffsetM: 1.5));
      p.entities.add(PumpEntity(id: 'pump', position: Pt(supply.x + 5, supply.y), pumpSpecId: s.id, name: 'Pump'));
      final f = Designer(p).designAll().systemFlows.single;
      expect(f.totalFlow / h, inInclusiveRange(17, 20.5));
      return f.warnings;
    }

    // 18.7 m³/h: within the 20 m³/h of the 60 Hz curve, beyond the 16.7 m³/h
    // the motor gives on 50 Hz mains (Q ∝ n)
    expect(flowWarnings(60, spec()), isNot(contains('pump_out_of_range:pump')));
    expect(flowWarnings(50, spec()), contains('pump_out_of_range:pump'));
    // never compared with the minimum flow of the catalogue
    expect(flowWarnings(60, spec(minFlow: 25, maxFlow: 40)), contains('pump_below_min_flow:pump'));
    expect(flowWarnings(60, spec(minFlow: 10, maxFlow: 40)), isNot(contains('pump_below_min_flow:pump')));
    // a booster in the zone had only the suction check
    final (p, _, supply, stub) = _zone(stub: 6);
    p.catalog.pumps.add(spec(maxFlow: 5));
    p.entities.add(PumpEntity(id: 'boost', position: (stub.points.first + stub.points.last) * 0.5, pumpSpecId: 'p60', scope: HydraulicScope.zone, name: 'Booster'));
    p.entities.add(WaterSupplyEntity(id: 'tank', position: supply, name: 'Tank', calculatePressure: true));
    final z = Designer(p).designAll().zones.values.single;
    expect(z.devices.where((d) => d.entityId == 'boost'), isNotEmpty);
    expect(z.warnings, contains('pump_out_of_range:boost'));
  });

  test('MOT-12: a mainline over a hill runs below the atmosphere and says so; a suction pipe does not', () {
    final (p, valve, supply, _) = _zone();
    final mid = (supply + valve.position) * 0.5;
    p.entities.removeWhere((e) => e.id == 'main');
    p.entities.add(PipeEntity(id: 'main', points: [supply, mid, valve.position], scope: HydraulicScope.mainline, name: 'Main', pipeSpecId: 'pvc100', computerSized: false));
    for (final (at, z) in [(supply, 100.0), (mid, 112.0), (valve.position, 85.0), (const Pt(0, 0), 85.0), (const Pt(120, 45), 85.0), (const Pt(120, 0), 85.0), (const Pt(0, 45), 85.0)]) {
      p.entities.add(SpotHeightEntity(id: p.newId(), position: at, elevation: z));
    }
    p.entities.add(WaterSupplyEntity(id: 'tank', position: supply, name: 'Tank', calculatePressure: false, designHeadM: 4, waterLevelOffsetM: 0));
    final f = Designer(p).analyzeAll().systemFlows.single;
    final top = f.pipes.where((x) => x.entityId == 'main').map((x) => math.min(x.pressureStart, x.pressureEnd)).reduce(math.min);
    expect(top, lessThan(-5), reason: 'the line of heads passes 8 m below the hilltop');
    expect(f.warnings, contains('pressure_below_atmospheric:main'));
    // the suction pipe of a surface pump 5 m from a well with the water 6 m
    // down: its negative pressure is the suction lift, checked as such
    final (q, _, s2, _) = _zone();
    q.entities.add(WaterSupplyEntity(id: 'well', position: s2, name: 'Well', calculatePressure: true, waterLevelOffsetM: -6));
    q.entities.add(PumpEntity(id: 'pump', position: Pt(s2.x + 5, s2.y), pumpSpecId: 'pump_mid', name: 'Pump'));
    final g = Designer(q).designAll().systemFlows.single;
    expect(g.devices.firstWhere((d) => d.entityId == 'pump').upstreamPressure, lessThan(-5));
    expect(g.warnings.where((w) => w.startsWith('pressure_below_atmospheric')), isEmpty);
  });

  test('MOT-13: a zone valve that does not regulate and gets far more than its zone needs is pointed out', () {
    for (final regulated in [false, true]) {
      final (p, valve, supply, _) = _zone();
      if (regulated) valve.fixedDownstreamHeadM = 17;
      p.entities.add(WaterSupplyEntity(id: 'tank', position: supply, name: 'Tank', calculatePressure: false, designHeadM: 50, waterLevelOffsetM: 0));
      final r = Designer(p).designAll();
      final f = r.systemFlows.single;
      final duty = f.valves.single;
      expect(duty.surplus, greaterThan(20), reason: '50 m at the tank, the zone needs about 18');
      expect(duty.regulates, regulated);
      expect(f.warnings.contains('valve_pressure_excess:${valve.id}'), !regulated);
      final back = ValveDuty.fromJson(duty.toJson());
      expect(back.regulates, regulated);
      expect(back.excessive, duty.excessive);
    }
  });

  test('MOT-14: a regulated tape holds its inlet pressure and the zone keeps its submain at the regulator minimum', () {
    ZoneResult run(bool regulated, double slopePct, {bool design = true}) {
      final p = Project();
      final block = generateBlock(
        p,
        BlockOptions(
          polygon: const [Pt(0, 0), Pt(100, 0), Pt(100, 30), Pt(0, 30)],
          direction: const Pt(1, 0),
          lateralSpacing: 1.5,
          isTape: true,
          tapeSpecId: 'tape16_16_20',
          tapeInletHeadM: 8,
          submainPosition: SubmainPosition.start,
          valveSpecId: 'ev50',
          valvePosition: ValvePosition.centre,
          submainStub: 1.5,
          zoneName: 'Z',
        ),
      );
      p.entities.addAll(block.all);
      for (final e in block.laterals.whereType<TapeEntity>()) {
        e
          ..regulated = regulated
          ..submainMinHeadM = 12;
      }
      for (final (x, y) in [(-200.0, -200.0), (300.0, -200.0), (-200.0, 300.0), (300.0, 300.0)]) {
        p.entities.add(SpotHeightEntity(id: p.newId(), position: Pt(x, y), elevation: 100 - slopePct / 100 * y));
      }
      final valve = block.valve!;
      final supplyPos = valve.position + const Pt(-100, 0);
      p.entities.add(PipeEntity(id: 'main', points: [supplyPos, valve.position], scope: HydraulicScope.mainline, name: 'Main'));
      p.entities.add(WaterSupplyEntity(id: 'tank', position: supplyPos, name: 'Tank', calculatePressure: true));
      final d = Designer(p);
      return (design ? d.designAll() : d.analyzeAll()).zones.values.single;
    }

    for (final design in [false, true]) {
      final flat = run(true, 0, design: design), slope = run(true, 4, design: design);
      for (final z in [flat, slope]) {
        final regs = z.devices.where((d) => d.linkId.startsWith('reg_')).toList();
        expect(regs, hasLength(20), reason: 'one regulator per tape');
        expect(regs.every((d) => d.status == 'active'), isTrue);
        // the submain keeps 12 m at the least favoured regulator, no more
        expect(regs.map((d) => d.upstreamPressure).reduce(math.min), closeTo(12, 0.01));
        // every tape inlet at its 8 m, whatever the submain gives
        for (final o in z.outlets.where((o) => o.index == 0)) {
          expect(o.pressure, closeTo(8, 0.3), reason: o.entityId);
        }
      }
      // the tapes behind their regulators do not see the slope
      expect(slope.minOutletPressure, closeTo(flat.minOutletPressure, 1e-6));
      expect(slope.maxOutletPressure, closeTo(flat.maxOutletPressure, 1e-6));
      expect(slope.downstreamHead, greaterThan(flat.downstreamHead), reason: 'the valve gives the higher regulators their 12 m');
    }
    // without regulators the inlet pressures follow the valve
    final plain = run(false, 4, design: false);
    expect(plain.devices.where((d) => d.linkId.startsWith('reg_')), isEmpty);
    final inlets = [for (final o in plain.outlets.where((o) => o.index == 0)) o.pressure];
    expect(inlets.reduce(math.max) - inlets.reduce(math.min), greaterThan(1));
  });

  test('MOT-15: the motor and drive efficiency of a pump enters the energy of the design and of the tariff schedule alike', () {
    (DesignResults, Project) run(double motor) {
      final (p, _, supply, _) = _zone();
      p.entities.add(WaterSupplyEntity(id: 'tank', position: supply, name: 'Tank', calculatePressure: false, designHeadM: 0.5, waterLevelOffsetM: 0));
      p.entities.add(PumpEntity(id: 'pump', position: Pt(supply.x + 5, supply.y), pumpSpecId: 'pump_mid', name: 'Pump', motorEfficiency: motor));
      return (Designer(p).designAll(), p);
    }

    final (one, p1) = run(1);
    final (eighty, p2) = run(0.8);
    expect(one.annualEnergyCost, greaterThan(0));
    expect(eighty.annualEnergyCost, closeTo(one.annualEnergyCost / 0.8, 1e-6 * one.annualEnergyCost));
    // the schedule takes the same power as the design: the curve at the
    // operating point (it took the single efficiency) and the motor
    final f = one.systemFlows.single;
    final d = f.devices.firstWhere((x) => x.entityId == 'pump');
    final spec = p1.catalog.pump('pump_mid')!;
    final jobs1 = tariffJobsFromDesign(p1, one), jobs2 = tariffJobsFromDesign(p2, eighty);
    final kw = waterDensity * gravity * d.flow * d.pumpHead / spec.efficiencyAt(d.flow, speed: d.speedRatio) / 1000;
    expect(jobs1.single.powerKw, closeTo(kw, 1e-6 * kw));
    expect(jobs2.single.powerKw, closeTo(jobs1.single.powerKw / 0.8, 1e-6 * kw));
    // kept in the file only when given
    final pump = p2.byId('pump')! as PumpEntity;
    expect(pump.toJson()['meff'], 0.8);
    expect((Entity.fromJson(pump.toJson()) as PumpEntity).motorEfficiency, 0.8);
    expect((p1.byId('pump')! as PumpEntity).toJson().containsKey('meff'), isFalse);
  });

  test('MOT-16: the pump selection adds the head of the pumps in series once, not of every pump of the flow', () {
    final (p, _, supply, _) = _zone();
    p.entities.add(WaterSupplyEntity(id: 'tank', position: supply, name: 'Tank', calculatePressure: true));
    // two pumps in parallel on a loop of the mainline next to the tank
    final a = Pt(supply.x + 10, supply.y), b = Pt(supply.x + 30, supply.y);
    p.entities.removeWhere((e) => e.id == 'main');
    final valvePos = supply + const Pt(100, 0);
    p.entities.add(PipeEntity(id: 'main0', points: [supply, a], scope: HydraulicScope.mainline, name: 'M0'));
    p.entities.add(PipeEntity(id: 'up', points: [a, Pt(a.x, a.y + 5), Pt(b.x, b.y + 5), b], scope: HydraulicScope.mainline, name: 'Up'));
    p.entities.add(PipeEntity(id: 'down', points: [a, Pt(a.x, a.y - 5), Pt(b.x, b.y - 5), b], scope: HydraulicScope.mainline, name: 'Down'));
    p.entities.add(PipeEntity(id: 'main1', points: [b, valvePos], scope: HydraulicScope.mainline, name: 'M1'));
    p.entities.add(PumpEntity(id: 'pa', position: Pt(supply.x + 20, supply.y + 5), pumpSpecId: 'pump_c15', name: 'A'));
    p.entities.add(PumpEntity(id: 'pb', position: Pt(supply.x + 20, supply.y - 5), pumpSpecId: 'pump_c15', name: 'B'));
    final r = Designer(p).designAll();
    final f = r.systemFlows.single;
    final heads = [for (final d in f.devices.where((d) => d.pumpHead > 0)) d.pumpHead];
    expect(heads, hasLength(2), reason: 'both pumps run');
    final duty = worstPumpDuty(r, 'tank')!;
    final boost = duty.supply.pumpBoost!;
    expect(heads.any((x) => (x - boost).abs() < 1e-6), isTrue, reason: 'the head of one of the two in parallel: $boost of $heads');
    expect(duty.head, closeTo(duty.supply.requiredHead + boost, 1e-6), reason: 'it added both: +${heads.reduce((x, y) => x + y)} m');
    final back = SupplyDuty.fromJson(duty.supply.toJson());
    expect(back.pumpBoost, closeTo(duty.supply.pumpBoost!, 1e-12));
  });

  test('MOT-24: the pump ranking reads the efficiency curve at the share of each pump and annualises the purchase', () {
    const h = m3sPerM3h;
    final cat = Catalog(
      pipes: [],
      outlets: [],
      tapes: [],
      valves: [],
      pumps: [
        // the same curve; the cheap one is efficient only far from this duty
        PumpSpec(
          id: 'cheap',
          name: 'cheap',
          points: [(0.0, 50.0), (20 * h, 45.0), (40 * h, 35.0)],
          efficiency: 0.75,
          efficiencyPoints: [(0.0, 0.2), (20 * h, 0.4), (40 * h, 0.75)],
          maxFlow: 40 * h,
          cost: 1000,
          powerKw: 7.5,
        ),
        PumpSpec(
          id: 'dear',
          name: 'dear',
          points: [(0.0, 50.0), (20 * h, 45.0), (40 * h, 35.0)],
          efficiency: 0.70,
          efficiencyPoints: [(0.0, 0.3), (20 * h, 0.70), (40 * h, 0.6)],
          maxFlow: 40 * h,
          cost: 1600,
          powerKw: 7.5,
        ),
      ],
    );
    final ranked = rankPumps(cat, flow: 20 * h, head: 40, hoursPerYear: 2000, costPerKwh: 0.2, crf: 0.1);
    expect(ranked.first.spec.id, 'dear', reason: 'at 20 m³/h the cheap one runs at 40 %, not at its 75 %');
    final cheap = ranked.firstWhere((c) => c.spec.id == 'cheap');
    expect(cheap.shaftPowerKw, closeTo(waterDensity * gravity * cheap.operatingFlow * cheap.operatingHead / cat.pump('cheap')!.efficiencyAt(cheap.operatingFlow) / 1000, 1e-9));
    // a dear money (high capital recovery) makes the cheaper purchase win
    expect(rankPumps(cat, flow: 20 * h, head: 40, hoursPerYear: 50, costPerKwh: 0.2, crf: 0.5).first.spec.id, 'cheap');
  });
}
