import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/hydraulics/emitter.dart';
import 'package:opencadirrigation/core/hydraulics/friction.dart';
import 'package:opencadirrigation/core/hydraulics/network.dart';
import 'package:opencadirrigation/core/io/epanet_inp.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

String tr(String key, [Map<String, String>? args]) => key;

/// A designed example: sized by [Designer.designAll], then analysed afresh
/// (zones and system flows) as the reference of the round trips.
(Project, DesignResults) designed(ExampleId id) {
  final p = buildExample(id, tr);
  Designer(p).designAll();
  final d = Designer(p);
  final r = DesignResults(timestamp: DateTime(2026));
  for (final v in d.model.valveNodes.keys) {
    r.zones[v] = d.analyzeZone(v);
    d.results.zones[v] = r.zones[v]!;
  }
  for (final f in d.effectiveSystemFlows()) {
    r.systemFlows.add(d.analyzeSystemFlow(f));
  }
  return (p, r);
}

/// Our solver on the network read back from [inp].
(InpModel, NetworkResult) solveBack(String inp) {
  final m = EpanetInpReader.parse(inp);
  final r = m.toNetwork().solve();
  expect(r.converged, isTrue, reason: 'read-back network did not converge');
  return (m, r);
}

void comparePipes(EpanetExport x, NetworkResult r, List<PipeSegmentResult> pipes, {double flowRel = 1e-5}) {
  expect(pipes, isNotEmpty);
  for (final s in pipes) {
    final id = x.linkIds[s.linkId];
    expect(id, isNotNull, reason: s.linkId);
    final lr = r.links[id]!;
    final sign = x.reversedLinks.contains(s.linkId) ? -1 : 1;
    expect(sign * lr.flow, closeTo(s.flow, s.flow.abs() * flowRel + 1e-9), reason: 'flow ${s.linkId}');
  }
}

void main() {
  group('EPANET export of a designed sprinkler project (sports field)', () {
    final (p, res) = designed(ExampleId.sportsField);
    final valveId = res.zones.keys.first;

    test('a zone round-trips: heads and flows match our analysis', () {
      final zr = res.zones[valveId]!;
      final x = EpanetWriter.write(p, results: res, scope: EpanetScope.zone(valveId));
      // every section of the format is there
      for (final s in [
        '[TITLE]',
        '[JUNCTIONS]',
        '[RESERVOIRS]',
        '[TANKS]',
        '[PIPES]',
        '[PUMPS]',
        '[VALVES]',
        '[EMITTERS]',
        '[CURVES]',
        '[STATUS]',
        '[OPTIONS]',
        '[TIMES]',
        '[REPORT]',
        '[COORDINATES]',
        '[VERTICES]',
        '[END]',
      ]) {
        expect(x.text, contains(s));
      }
      expect(x.emitterExponent, 0.5);
      expect(x.warnings.where((w) => w.startsWith('epanet_emitter')), isEmpty);
      final (m, r) = solveBack(x.text);
      expect(m.reservoirs, hasLength(1));
      expect(m.valves.single.type, 'GPV');
      expect(m.emitters, hasLength(zr.emitterCount));
      comparePipes(x, r, zr.pipes);
      // heads at both ends of every pipe and the emitter pressures
      final model = Designer(p).model;
      for (final s in zr.pipes) {
        final l = model.linkById(s.linkId)!;
        expect(r.nodes[x.nodeIds[l.from]]!.head, closeTo(s.pressureStart + s.elevationA, 1e-4), reason: 'head ${l.from}');
        expect(r.nodes[x.nodeIds[l.to]]!.head, closeTo(s.pressureEnd + s.elevationB, 1e-4), reason: 'head ${l.to}');
      }
      var total = 0.0;
      for (final n in r.nodes.values) {
        total += n.emitterFlow;
      }
      expect(total, closeTo(zr.totalFlow, zr.totalFlow * 1e-5));
      for (final o in zr.outlets) {
        final nid = model.nodes.values.firstWhere((n) => n.emitters.any((e) => e.entityId == o.entityId)).id;
        final j = m.junctions.firstWhere((j) => j.id == x.nodeIds[nid]);
        // the junction lies at the emitter (riser) elevation
        expect(j.elevation, closeTo(o.elevation, 1e-5));
        expect(r.nodes[j.id]!.pressure, closeTo(o.pressure, 1e-4));
      }
    });

    test('the mainline with one system flow (zones as demands) matches the system-flow analysis', () {
      final fr = res.systemFlows.first;
      final x = EpanetWriter.write(p, results: res, scope: EpanetScope.systemFlow(fr.flowId));
      final (m, r) = solveBack(x.text);
      expect(m.pumps, hasLength(1));
      expect(m.pipes.where((pp) => pp.status == 'CV'), hasLength(1), reason: 'the check valve');
      expect(m.curves.keys, contains(startsWith('PC_')));
      comparePipes(x, r, fr.pipes);
      final model = Designer(p).model;
      for (final v in fr.valves) {
        final nid = model.valveNodes[v.valveId]!.$1;
        expect(r.nodes[x.nodeIds[nid]]!.pressure, closeTo(v.availableHead, 1e-3), reason: 'valve ${v.zoneName}');
      }
      for (final d in fr.devices.where((d) => d.pumpHead > 0)) {
        expect(r.links[x.linkIds[d.linkId]]!.pumpHead, closeTo(d.pumpHead, 1e-3));
      }
    });

    test('everything with every valve open: converges and balances', () {
      final x = EpanetWriter.write(p, results: res);
      final (m, r) = solveBack(x.text);
      expect(m.valves.where((v) => v.type == 'GPV').length, greaterThanOrEqualTo(res.zones.length));
      var emitted = 0.0;
      for (final n in r.nodes.values) {
        emitted += n.emitterFlow;
      }
      final source = m.reservoirs.single.id;
      var out = 0.0;
      for (final l in m.pipes.where((l) => l.n1 == source || l.n2 == source)) {
        out += l.n1 == source ? r.links[l.id]!.flow : -r.links[l.id]!.flow;
      }
      expect(out, closeTo(emitted, emitted * 1e-4));
    });

    test('flows in m³/h and coordinates in UTM for a georeferenced project', () {
      final q = Project.fromJson(p.toJson())..meta.georef = const GeoReference(zone: 23, north: false, originEasting: 186000, originNorthing: 8253200);
      final zr = res.zones[valveId]!;
      final x = EpanetWriter.write(
        q,
        results: res,
        scope: EpanetScope.zone(valveId),
        options: const EpanetOptions(flowUnits: EpanetFlowUnits.cmh),
      );
      expect(x.text, contains('Units\tCMH'));
      final (m, r) = solveBack(x.text);
      comparePipes(x, r, zr.pipes);
      final c = m.coordinates.values.first;
      expect(c.$1, greaterThan(180000));
      expect(c.$2, greaterThan(8253000));
      expect(x.crs.utmZone, 23);
    });
  });

  group('EPANET export of a gravity drip project with a pressure-reducing valve', () {
    final (p, res) = designed(ExampleId.gravity);

    test('the PRV is written as such and the system flow matches', () {
      final fr = res.systemFlows.first;
      final x = EpanetWriter.write(p, results: res, scope: EpanetScope.systemFlow(fr.flowId));
      final (m, r) = solveBack(x.text);
      final prv = m.valves.firstWhere((v) => v.type == 'PRV');
      expect(double.parse(prv.setting), closeTo(25, 1e-9));
      expect(m.valves.where((v) => v.type == 'GPV'), isNotEmpty, reason: 'gate valve and filter');
      comparePipes(x, r, fr.pipes);
      final model = Designer(p).model;
      final dev = fr.devices.firstWhere((d) => model.linkById(d.linkId)!.settingM == 25);
      expect(r.nodes[prv.n2]!.pressure, closeTo(dev.downstreamPressure, 1e-4));
      // with more head at the reservoir the valve regulates: 25 m downstream
      final s = p.entities.whereType<WaterSupplyEntity>().single;
      final high = EpanetWriter.write(
        p,
        results: res,
        scope: EpanetScope.systemFlow(fr.flowId),
        options: EpanetOptions(supplyHeads: {s.id: 40}),
      );
      final (m2, r2) = solveBack(high.text);
      expect(r2.nodes[m2.valves.firstWhere((v) => v.type == 'PRV').n2]!.pressure, closeTo(25, 1e-3));
    });

    test('merged chains give the same heads at the nodes they keep', () {
      final fr = res.systemFlows.first;
      final plain = EpanetWriter.write(p, results: res, scope: EpanetScope.systemFlow(fr.flowId));
      final merged = EpanetWriter.write(p, results: res, scope: EpanetScope.systemFlow(fr.flowId), options: const EpanetOptions(mergeChains: true));
      final (_, a) = solveBack(plain.text);
      final (mm, b) = solveBack(merged.text);
      expect(mm.pipes.length, lessThan(EpanetInpReader.parse(plain.text).pipes.length));
      expect(mm.vertices, isNotEmpty);
      for (final e in merged.nodeIds.entries) {
        expect(b.nodes[e.value]!.head, closeTo(a.nodes[plain.nodeIds[e.key]]!.head, 1e-3));
      }
      comparePipes(merged, b, fr.pipes);
    });

    test('drip zones (lumped tape emitters) round-trip', () {
      for (final v in res.zones.keys) {
        final zr = res.zones[v]!;
        final x = EpanetWriter.write(p, results: res, scope: EpanetScope.zone(v));
        expect(x.warnings.where((w) => w.startsWith('epanet_emitter')), isEmpty);
        final (_, r) = solveBack(x.text);
        comparePipes(x, r, zr.pipes);
      }
    });

    test('the zones in detail behind their valves, other zones closed', () {
      final fr = res.systemFlows.first;
      final x = EpanetWriter.write(p, results: res, scope: EpanetScope.systemFlow(fr.flowId, detailedZones: true, includeClosedZones: true));
      final m = EpanetInpReader.parse(x.text);
      expect(m.status.values, contains('Closed'));
      final r = m.toNetwork().solve();
      expect(r.converged, isTrue);
    });
  });

  test('pressure-compensating emitters become fixed demands, with a warning', () {
    final (p, res) = designed(ExampleId.bananas);
    final v = res.zones.keys.first;
    final x = EpanetWriter.write(p, results: res, scope: EpanetScope.zone(v));
    expect(x.warnings.where((w) => w.startsWith('epanet_emitter_compensating:')), isNotEmpty);
    final (m, r) = solveBack(x.text);
    final demand = m.junctions.fold(0.0, (s, j) => s + j.baseDemand);
    expect(demand, closeTo(res.zones[v]!.totalFlow, res.zones[v]!.totalFlow * 0.03));
    expect(r.converged, isTrue);
  });

  test('a different emitter exponent keeps the flow at the nominal pressure', () {
    final p = Project();
    final valve = ControlValveEntity(id: 'v1', position: const Pt(0, 0), valveSpecId: 'ev25', zoneName: 'Z', fixedDownstreamHeadM: 30);
    p.entities.addAll([
      valve,
      PipeEntity(id: 'pz', points: const [Pt(0, 0), Pt(20, 0), Pt(40, 0)], scope: HydraulicScope.zone, pipeSpecId: 'pe32'),
      OutletEntity(id: 'o1', position: const Pt(20, 0), outletSpecId: 'impact34', nozzleId: 'i4.0', headM: 30),
      OutletEntity(id: 'o2', position: const Pt(40, 0), outletSpecId: 'micro', nozzleId: 'm50', headM: 15),
    ]);
    // a nozzle with exponent 0.46 instead of 0.5
    final nz = p.catalog.outlet('micro')!.nozzle('m50')!;
    nz.curve = EmitterCurve(k: nz.curve.k * math.pow(15, 0.5) / math.pow(15, 0.46), x: 0.46);
    final x = EpanetWriter.write(p, scope: const EpanetScope.zone('v1'));
    expect(x.warnings, contains('epanet_emitter_exponent:o2'));
    final m = EpanetInpReader.parse(x.text);
    final j = m.emitters.entries.map((e) => e.value).toList()..sort();
    // at its nominal 15 m the converted coefficient gives the catalogue flow
    expect(j.first * math.pow(15, 0.5), closeTo(nz.curve.flow(15), 1e-12));
  });

  test('a PRV at the supply gets a short pipe in front; a valve with a fixed outlet pressure is a PRV', () {
    final p = Project();
    p.entities.addAll([
      WaterSupplyEntity(id: 's1', position: const Pt(0, 0), calculatePressure: false, designHeadM: 50),
      MiscHydraulicEntity(id: 'prv1', position: const Pt(0, 0), valveSpecId: 'prv50', settingM: 35),
      PipeEntity(id: 'pm', points: const [Pt(0, 0), Pt(100, 0)], scope: HydraulicScope.mainline, pipeSpecId: 'pvc50'),
      ControlValveEntity(id: 'v1', position: const Pt(100, 0), valveSpecId: 'ev50', zoneName: 'Z1', fixedDownstreamHeadM: 30),
      PipeEntity(id: 'pz', points: const [Pt(100, 0), Pt(120, 0), Pt(140, 0)], scope: HydraulicScope.zone, pipeSpecId: 'pe32'),
      OutletEntity(id: 'o1', position: const Pt(120, 0), outletSpecId: 'impact34', nozzleId: 'i4.0', headM: 30),
      OutletEntity(id: 'o2', position: const Pt(140, 0), outletSpecId: 'impact34', nozzleId: 'i4.0', headM: 30),
    ]);
    final x = EpanetWriter.write(p);
    final m = EpanetInpReader.parse(x.text);
    final prvs = m.valves.where((v) => v.type == 'PRV').toList();
    expect(prvs, hasLength(2));
    final atSupply = prvs.firstWhere((v) => v.id == 'dev_prv1');
    // EPANET refuses a PRV joined to a reservoir (error 219): the short pipe in between
    expect(m.reservoirs.any((r) => r.id == atSupply.n1), isFalse);
    expect(m.pipes.any((pp) => pp.id == 'dev_prv1_s' && m.reservoirs.any((r) => r.id == pp.n1) && pp.n2 == atSupply.n1), isTrue);
    expect(double.parse(prvs.firstWhere((v) => v.id == 'cv_v1').setting), 30);
    final r = m.toNetwork().solve();
    expect(r.converged, isTrue);
    // both valves regulate: 35 m after the first, 30 m at the zone inlet
    expect(r.nodes[atSupply.n2]!.pressure, closeTo(35, 1e-3));
    expect(r.nodes[prvs.firstWhere((v) => v.id == 'cv_v1').n2]!.pressure, closeTo(30, 1e-3));
  });

  test('the reader converts US units and EPANET options', () {
    // the same network in GPM/ft/in/psi and in LPS/m/mm
    const us = '''
[TITLE]
US units
[JUNCTIONS]
J1  100  50
J2  90   0
[RESERVOIRS]
R1  250
[PIPES]
P1  R1  J1  1000  6  130  0  Open
P2  J1  J2  500   4  130  2  Open
[EMITTERS]
J2  2.0
[OPTIONS]
Units GPM
Headloss H-W
Emitter Exponent 0.5
[END]
''';
    const ft = 0.3048, inch = 0.0254, gpm = 6.30901964e-5;
    final si =
        '''
[JUNCTIONS]
J1  ${100 * ft}  ${50 * gpm * 1000}
J2  ${90 * ft}   0
[RESERVOIRS]
R1  ${250 * ft}
[PIPES]
P1  R1  J1  ${1000 * ft}  ${6 * inch * 1000}  130  0  Open
P2  J1  J2  ${500 * ft}   ${4 * inch * 1000}  130  2  Open
[EMITTERS]
J2  ${2.0 * gpm * 1000 * math.pow(0.4333 / 0.3048, 0.5)}
[OPTIONS]
Units LPS
Headloss H-W
[END]
''';
    final a = EpanetInpReader.parse(us).toNetwork().solve();
    final b = EpanetInpReader.parse(si).toNetwork().solve();
    expect(a.converged && b.converged, isTrue);
    expect(a.nodes['J2']!.head, closeTo(b.nodes['J2']!.head, 1e-9));
    expect(a.links['P2']!.flow, closeTo(b.links['P2']!.flow, 1e-12));
    expect(a.links['P2']!.flow, greaterThan(0));
    // an unsupported head-loss formula is refused with a code
    expect(EpanetInpReader.parse(us.replaceFirst('H-W', 'C-M')).method, FrictionMethod.manning);
  });

  test('the reader handles tanks, patterns, demands, status, valves and quoted labels', () {
    const inp = '''
[JUNCTIONS]
;ID Elev Demand Pattern
J1  10  1  P1
J2  5   0
J3  5   0
[TANKS]
T1  20  5  1  10  10  0
[PIPES]
A  T1  J1  100  100  140  0
B  J1  J2  100  100  140  0  Closed
C  J1  J3  100  100  140  0
[VALVES]
V1  J3  J2  100  TCV  5  0
[DEMANDS]
J1  2  P1
[PATTERNS]
P1  1.5  1.0
P1  0.5
[STATUS]
V1  Open
[COORDINATES]
J1  0  0
J2  100 0
J3  0 100
T1  -100 0
[VERTICES]
C  0 50
[LABELS]
0 0 "A label ; with a semicolon"
[OPTIONS]
Units LPS
Headloss H-W
[END]
''';
    final m = EpanetInpReader.parse(inp);
    expect(m.tanks.single.initLevel, 5);
    expect(m.patterns['P1'], [1.5, 1.0, 0.5]);
    final net = m.toNetwork();
    expect(net.nodes['J1']!.demand, closeTo(2 * 1.5 / 1000, 1e-12)); // [DEMANDS] replaces the base demand
    expect(net.nodes['T1']!.fixedHead, 25);
    expect(net.links.firstWhere((l) => l.id == 'B').kind, HLinkKind.closed);
    final r = net.solve();
    expect(r.converged, isTrue);
    expect(r.links['C']!.flow, closeTo(0, 1e-9)); // J3 and J2 have no demand
    final (doc, placement) = m.toDocument();
    expect(placement.georef, isNull);
    expect(doc.entities.where((e) => e.type == 'POLYLINE').length, 4); // three pipes and the valve
    expect(doc.entities.firstWhere((e) => e.name == 'C').points.length, 3);
  });
}
