/// Engine findings of the sweep of 2026-11-01 (MOT-03 onwards): each test
/// failed before its fix.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/block_generator.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/network_builder.dart';
import 'package:opencadirrigation/core/hydraulics/network.dart';
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
}
