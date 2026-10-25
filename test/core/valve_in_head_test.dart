import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/api.dart' as api;
import 'package:opencadirrigation/core/design/advisor.dart';
import 'package:opencadirrigation/core/design/agronomy.dart';
import 'package:opencadirrigation/core/design/auto_fix.dart';
import 'package:opencadirrigation/core/design/design_check.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/electrical.dart';
import 'package:opencadirrigation/core/design/energy_grouping.dart';
import 'package:opencadirrigation/core/design/management.dart';
import 'package:opencadirrigation/core/design/network_ops.dart';
import 'package:opencadirrigation/core/design/pump_selection.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/design/transient_analysis.dart';
import 'package:opencadirrigation/core/design/two_wire.dart';
import 'package:opencadirrigation/core/design/valve_in_head.dart';
import 'package:opencadirrigation/core/design/wire_routing.dart';
import 'package:opencadirrigation/core/io/epanet_inp.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

/// Heads of the three stations along the mainline (x, m).
const _xs = <double>[10, 20, 30, 40, 50, 60, 70, 80, 95, 105, 115, 125];

/// A mainline along y = 0 from a calculated supply at the origin to x = 130
/// with twelve valve-in-head impact sprinklers (1.2 m³/h at 30 m, 1 m riser)
/// in three stations of four: A (x 10–40) and B (x 50–80) on level ground, C
/// (x 95–125) 8 m lower. [flows] are the station sets of the system flows
/// (the first from 6 h for 2 h, the second from 10 h for 1 h); [wired] adds a
/// controller at x = −5 and a wire route along the heads to [wireTo];
/// [valves] adds two zone valves feeding micro-sprinklers.
Project _golf({
  List<Set<String>> flows = const [
    {'vih:A', 'vih:B'},
    {'vih:C'},
  ],
  bool wired = false,
  double wireTo = 130,
  bool valves = false,
}) {
  final p = Project();
  p.entities.add(WaterSupplyEntity(id: 'ws', position: Pt.zero));
  p.entities.add(PipeEntity(id: 'm', points: const [Pt.zero, Pt(130, 0)], scope: HydraulicScope.mainline));
  for (var i = 0; i < _xs.length; i++) {
    final station = i < 4 ? 'A' : (i < 8 ? 'B' : 'C');
    p.entities.add(OutletEntity(id: 'h${i + 1}', position: Pt(_xs[i], 0), scope: HydraulicScope.mainline, outletSpecId: 'impact34', nozzleId: 'i4.0', headM: 30, zoneName: station));
    if (station == 'C') p.entities.add(JunctionEntity(id: 'j${i + 1}', position: Pt(_xs[i], 0), scope: HydraulicScope.mainline, fixedElevation: -8));
  }
  if (valves) {
    for (final (id, x, dir) in [('v1', 65.0, 1.0), ('v2', 35.0, -1.0)]) {
      p.entities.add(ControlValveEntity(id: id, position: Pt(x, 0), zoneName: id.toUpperCase()));
      p.entities.add(PipeEntity(id: 'z$id', points: [Pt(x, 0), Pt(x, 20 * dir)], scope: HydraulicScope.zone));
      for (var k = 1; k <= 5; k++) {
        p.entities.add(OutletEntity(id: 'o$id$k', position: Pt(x, 4.0 * k * dir), outletSpecId: 'micro', nozzleId: 'm50', headM: 15));
      }
    }
  }
  for (var k = 0; k < flows.length; k++) {
    p.systemFlows.add(SystemFlow(id: 'f${k + 1}', name: 'F${k + 1}', valveIds: {...flows[k]}, startHour: k == 0 ? 6 : 10, durationHours: k == 0 ? 2 : 1));
  }
  if (wired) {
    p.entities.add(ControllerEntity(id: 'k', position: const Pt(-5, 0), stations: 6));
    p.entities.add(WireEntity(id: 'w', points: [const Pt(-5, 0), Pt(wireTo, 0)]));
  }
  return p;
}

const _a = ['h1', 'h2', 'h3', 'h4'], _b = ['h5', 'h6', 'h7', 'h8'], _c = ['h9', 'h10', 'h11', 'h12'];

SystemFlowResult _flow(DesignResults r, String id) => r.systemFlows.firstWhere((f) => f.flowId == id);

/// Results as JSON without the timestamp and the valve-in-head duties.
String _withoutHeads(DesignResults r) {
  final j = r.toJson()..remove('timestamp');
  for (final f in j['systemFlows'] as List) {
    (f as Map<String, dynamic>).remove('vih');
  }
  return encodeJson(j);
}

void main() {
  test('stations: heads sharing a station name are vih:<name>, a head without one is its own', () {
    final p = _golf();
    p.entities.add(OutletEntity(id: 'solo', name: 'Tee 1', position: const Pt(130, 0), scope: HydraulicScope.mainline, outletSpecId: 'impact34', nozzleId: 'i4.0', headM: 30));
    // a zone outlet is no valve-in-head head
    p.entities.add(OutletEntity(id: 'zone', position: const Pt(0, 50), outletSpecId: 'micro', nozzleId: 'm50'));
    final s = VihStations.of(p);
    expect(s.heads, {
      'vih:A': _a,
      'vih:B': _b,
      'vih:C': _c,
      'solo': ['solo'],
    });
    expect(s.stationOf['h5'], 'vih:B');
    expect(s.scheduled, {'vih:A', 'vih:B', 'vih:C'});
    expect(s.nameOf('vih:C'), 'C');
    expect(s.nameOf('solo'), 'Tee 1');
    expect(isVihHead(p.byId('zone')), isFalse);
    expect(vihStationId(p.byId('h1') as OutletEntity), 'vih:A');
    expect(demandIds(p), ['vih:A', 'vih:B', 'vih:C', 'solo']);
    expect(demandName(p, 'vih:B'), 'B');
    expect(demandName(p, 'solo'), 'Tee 1');
    // a station no flow lists runs in every flow, one that some flow lists only there
    expect(s.runs('solo', {'vih:A'}), isTrue);
    expect(s.runs('vih:C', {'vih:A'}), isFalse);
    expect(s.unscheduled(p.systemFlows), ['solo']);
    expect(s.flowsOf('vih:C', p.systemFlows).map((f) => f.id), ['f2']);
    // nominal demand: the heads at their nominal pressure
    final q = nominalDemands(p);
    expect(q['vih:A']! / m3sPerLph, closeTo(4 * 1200, 1e-6));
    expect(q['solo']! / m3sPerLph, closeTo(1200, 1e-6));
  });

  test('heads run only in the flows that schedule them, the worst at its nominal pressure', () {
    final p = _golf();
    final r = Designer(p).designAll();
    // sized by LP: in flow 1 the idle heads of C, 8 m lower, see 39 m of
    // static pressure, beyond their window; it is not theirs to keep
    expect(r.method, 'lp');
    expect(r.messages.where((m) => m.startsWith('lp_infeasible')), isEmpty);
    final f1 = _flow(r, 'f1'), f2 = _flow(r, 'f2');
    expect(f1.heads.map((h) => h.stationId), ['vih:A', 'vih:B']);
    expect(f2.heads.map((h) => h.stationId), ['vih:C']);
    for (final f in [f1, f2]) {
      expect(f.warnings, isEmpty);
      expect(f.totalFlow, closeTo(f.heads.fold(0.0, (s, h) => s + h.flow), 1e-9));
      for (final h in f.heads) {
        expect(h.heads, 4);
        expect(h.scheduled, isTrue);
        // every head at least at its nominal pressure, within its window
        expect(h.minPressure, greaterThanOrEqualTo(30 - 0.01));
        expect(h.deficit, lessThanOrEqualTo(0.01));
        expect(h.withinWindow, isTrue);
        expect(h.requiredHead, closeTo(31, 1e-9)); // 30 m at the nozzle on a 1 m riser
        expect(h.flow / m3sPerLph, closeTo(4 * 1200, 4 * 1200 * 0.03));
      }
      // the calculated supply gives the worst head exactly what it needs
      expect(f.heads.map((h) => h.deficit).reduce((a, b) => a > b ? a : b), closeTo(0, 0.01));
    }
    // flow 1: the farthest head of B is the critical one; nothing flows to C
    expect(f1.heads[1].criticalId, 'h8');
    for (final s in f1.pipes) {
      if (s.a.x >= 80 - 1e-9) expect(s.flow.abs(), lessThan(1e-9), reason: '${s.a.x}');
    }
    // flow 2: C alone, the supply 8 m lower in need
    expect(f2.pipes.first.flow, closeTo(f2.totalFlow, 1e-9));
    expect(f2.supplies.first.requiredHead, lessThan(f1.supplies.first.requiredHead - 5));
    expect(f2.heads.single.elevation, -8);
    // the aggregate per station
    final st = r.vihStations;
    expect(st.keys, ['vih:A', 'vih:B', 'vih:C']);
    expect(st['vih:C']!.flowIds, ['f2']);
    expect(st['vih:A']!.heads, 4);
    expect(st['vih:B']!.minPressure, closeTo(f1.heads[1].minPressure, 1e-12));
    // the mainline of a flow, as the transient, on-demand and calibration
    // studies get it: the heads of the stations off have no emitter running
    final mf = MainlineFlows(p, results: r);
    for (final f in mf.flows) {
      final net = mf.stateOf(f)!.network;
      for (final id in mf.model.mainlineNodes) {
        for (final e in mf.model.nodes[id]!.emitters) {
          final on = f.valveIds.contains(VihStations.of(p).stationOf[e.entityId]);
          expect(net.nodes[id]!.emitterCount, on ? 1 : 0, reason: '${f.id} ${e.entityId}');
        }
      }
    }
    // the group head of the energy tools is the flow's supply pressure
    expect(designerGroupHead(opsDesigner(p, r), {'vih:A', 'vih:B'}), closeTo(f1.supplies.first.requiredHead, 1e-9));
    // and the report table: one row per station and flow
    final tables = buildReportTables(
      project: p,
      results: r,
      labels: ReportLabels(t: (k, [a]) => k, has: (_) => true, warning: (w) => w),
    );
    final vih = tables.firstWhere((tb) => tb.key == 'vih');
    expect(vih.rows.map((row) => '${row[0]} ${row[1]} ${row[2]}'), ['F1 A 4', 'F1 B 4', 'F2 C 4']);
    expect(vih.warn, [false, false, false]);
  });

  test('the 24-hour simulation follows the schedule of the stations', () {
    final p = _golf();
    final r = Designer(p).designAll();
    final day = simulateDay(p, results: r);
    expect(day.converged, isTrue);
    expect(day.messages, isEmpty);
    final f1 = _flow(r, 'f1').totalFlow, f2 = _flow(r, 'f2').totalFlow;
    for (final h in day.hours) {
      final expected = (h.hour == 6 || h.hour == 7) ? f1 : (h.hour == 10 ? f2 : 0.0);
      expect(h.flow, closeTo(expected, 1e-3 * f1), reason: 'hour ${h.hour}');
    }
    expect(day.hours[10].flows, ['f2']);
  });

  test('wiring: one station per valve-in-head station, its heads in parallel', () {
    final p = _golf(wired: true);
    final r = Designer(p).designAll();
    final el = r.electrical!;
    expect(el.warnings, isEmpty);
    expect(el.runs.map((x) => (x.valveId, x.zoneName, x.station, x.solenoids)), [('vih:A', 'A', 1, 4), ('vih:B', 'B', 2, 4), ('vih:C', 'C', 3, 4)]);
    // the station conductor follows the route to its last head
    expect(el.runs.map((x) => x.routeM), [closeTo(45, 1e-9), closeTo(85, 1e-9), closeTo(130, 1e-9)]);
    final duty = el.controllers.single;
    expect((duty.used, duty.maxOpen), (3, 2));
    final pr = p.params;
    // A and B open together: four solenoids opening, four holding
    expect(duty.peakCurrentA, closeTo(4 * pr.solenoidInrushA + 4 * pr.solenoidHoldingA, 1e-12));
    // voltage at the last head of A while it opens with B holding: on every
    // stretch the station conductor carries the heads of A beyond it, the
    // common one those of A opening and those of B holding
    final a = el.runOf('vih:A')!;
    final rs = p.catalog.wire(a.stationWireId)!.ohmPerKm, rc = p.catalog.wire(a.commonWireId)!.ohmPerKm;
    final slack = 1 + pr.wireSlackPct / 100;
    const stretches = [(15.0, 4), (10.0, 3), (10.0, 2), (10.0, 1)];
    final station = stretches.fold(0.0, (s, x) => s + x.$2 * pr.solenoidInrushA * x.$1) * slack / 1000 * rs;
    final common = stretches.fold(0.0, (s, x) => s + (x.$2 * pr.solenoidInrushA + 4 * pr.solenoidHoldingA) * x.$1) * slack / 1000 * rc;
    expect(a.volts, closeTo(24 - station - common, 1e-9));
    expect(el.runs.every((x) => x.ok && x.volts < 24), isTrue);
    // two splices per solenoid
    expect(r.bom.firstWhere((l) => l.description == 'elec.splice').quantity, 24);
    // JSON keeps the solenoids
    expect(ElectricalResult.fromJson(jsonDecode(jsonEncode(el.toJson())) as Map<String, dynamic>).runOf('vih:B')!.solenoids, 4);

    // a route that stops at x = 100 leaves three heads of C unwired: one
    // message for the station, its first head still on the station
    final short = _golf(wired: true, wireTo: 100);
    final rs2 = Designer(short).designAll().electrical!;
    expect(rs2.warnings, contains('elec_unwired:h10:h11:h12'));
    expect(rs2.runOf('vih:C')!.solenoids, 1);
    final issue = runDesignCheck(short).issues.firstWhere((i) => i.code == 'elec_unwired');
    expect(issue.entityIds, ['h10', 'h11', 'h12']);
    // too thin a wire for the far station reports its lowest head
    final thin = _golf(wired: true);
    for (final w in thin.catalog.wires) {
      w.enabled = w.id == 'w1';
    }
    (thin.byId('k') as ControllerEntity).outputVolts = 21;
    final rt = Designer(thin).designAll().electrical!;
    expect(rt.warnings, contains('elec_voltage:h12'));

    // the automatic routes reach every head and give each station one output
    final routes = autoRouteWires(p);
    expect(routes.warnings, isEmpty);
    expect(routes.stations.map((s) => (s.station, s.kind, s.entityId)), [(1, StationKind.valveInHead, 'vih:A'), (2, StationKind.valveInHead, 'vih:B'), (3, StationKind.valveInHead, 'vih:C')]);
    expect(routes.stations.map((s) => s.routeM), [closeTo(45, 1e-9), closeTo(85, 1e-9), closeTo(130, 1e-9)]);
    expect(wiringFlows(p), [
      {'vih:A', 'vih:B'},
      {'vih:C'},
    ]);
  });

  test('json round trip of the station duties, numbers that are not finite as null', () {
    final r = Designer(_golf()).designAll();
    final text = encodeJson(r.toJson());
    final back = DesignResults.fromJson(jsonDecode(text) as Map<String, dynamic>);
    expect(encodeJson(back.toJson()), text);
    expect(back.systemFlows.first.heads.map((h) => (h.stationId, h.heads, h.criticalId, h.scheduled)), [('vih:A', 4, 'h4', true), ('vih:B', 4, 'h8', true)]);
    expect(back.vihStations['vih:C']!.maxPressure, r.vihStations['vih:C']!.maxPressure);

    final d = VihDuty(
      stationId: 'vih:X',
      name: 'X',
      heads: 0,
      flow: 0,
      minPressure: double.nan,
      maxPressure: double.nan,
      allowedMin: 20,
      allowedMax: double.infinity,
      criticalId: 'h',
      availableHead: double.nan,
      requiredHead: 31,
      elevation: 2,
      p: const Pt(1, 2),
      scheduled: false,
    );
    final j = jsonDecode(encodeJson(d.toJson())) as Map<String, dynamic>;
    expect([j['pmin'], j['pmax'], j['hi'], j['h']], [null, null, null, null]);
    final e = VihDuty.fromJson(j);
    expect([e.minPressure.isNaN, e.maxPressure.isNaN, e.availableHead.isNaN, e.scheduled], [true, true, true, false]);
    expect((e.allowedMax, e.requiredHead, e.p), (double.infinity, 31.0, const Pt(1, 2)));
    // a flow without stations writes no key at all
    expect(SystemFlowResult.fromJson(_flow(r, 'f1').toJson()..remove('vih')).heads, isEmpty);
    expect(_flow(Designer(_golf(flows: const [])).designAll(), 'auto').toJson(), contains('vih'));
  });

  test('a station no flow lists runs in every flow, without a say on the supply, and is reported', () {
    final p = _golf(
      flows: const [
        {'vih:A'},
        {'vih:B'},
      ],
    );
    final r = Designer(p).designAll();
    for (final f in r.systemFlows) {
      final c = f.heads.firstWhere((h) => h.stationId == 'vih:C');
      expect(c.scheduled, isFalse);
      expect(f.heads.length, 2);
    }
    // the advisor counts the stations and points at their heads
    final issue = checkSettings(p).firstWhere((i) => i.code == 'vih_not_in_flow');
    expect((issue.severity, issue.value), (CheckSeverity.warning, '1'));
    expect(issue.entityIds, _c);
    final advice = buildAdvice(p, results: r).firstWhere((a) => a.code == 'vih_not_in_flow');
    expect(advice.level, AdviceLevel.warning);
    expect(adviceCodes, containsAll(['vih_not_in_flow', 'vih_pressure_deficit', 'vih_pressure_high']));
    // a flow that lists only stations is not empty
    expect(checkSettings(p).where((i) => i.code == 'flow_empty'), isEmpty);
    // scheduled everywhere: no message
    expect(checkSettings(_golf()).where((i) => i.code == 'vih_not_in_flow'), isEmpty);
  });

  test('pressure messages of the scheduled stations', () {
    // A and C together: the supply set for A gives C, 8 m lower, too much
    final high = Designer(
      _golf(
        flows: const [
          {'vih:A', 'vih:C'},
          {'vih:B'},
        ],
      ),
    ).designAll();
    final w = _flow(high, 'f1').warnings.where((x) => x.startsWith('vih_pressure_high:')).toList();
    expect(w, hasLength(1));
    expect(_c, contains(w.single.split(':').last));
    // a fixed supply too low for the heads
    final p = _golf();
    (p.byId('ws') as WaterSupplyEntity)
      ..calculatePressure = false
      ..designHeadM = 20;
    final r = Designer(p).analyzeAll();
    // the critical head of each station short of pressure
    expect(_flow(r, 'f1').warnings, containsAll(['vih_pressure_deficit:h4', 'vih_pressure_deficit:h8']));
    final advice = buildAdvice(p, results: r).where((x) => x.raw == 'vih_pressure_deficit').toList();
    expect(advice.map((a) => a.entityIds.single), containsAll(['h4', 'h8']));
    for (final a in advice) {
      expect(a.level, AdviceLevel.error);
      expect(a.fixes, [FixKind.choosePump, FixKind.calculateSupply]);
    }
  });

  test('flows that list no valve-in-head station give the results of before', () {
    // zone valves in the flows, the heads in none: every head runs in every
    // flow and the valves alone set the supply, as before the heads could be
    // scheduled (a designer that knows no station)
    final p = _golf(
      flows: const [
        {'v1'},
        {'v2'},
      ],
      valves: true,
    );
    final now = Designer(p.copy()).designAll();
    final before = Designer(p.copy(), stations: const VihStations.none()).designAll();
    expect(_withoutHeads(now), _withoutHeads(before));
    for (final f in now.systemFlows) {
      expect(f.heads.map((h) => (h.stationId, h.scheduled)), [('vih:A', false), ('vih:B', false), ('vih:C', false)]);
      expect(f.warnings.where((w) => w.startsWith('vih_')), isEmpty);
    }
    expect(before.systemFlows.every((f) => f.heads.isEmpty), isTrue);
    // and so does a project without flows
    final q = _golf(flows: const [], valves: true);
    expect(_withoutHeads(Designer(q.copy()).designAll()), _withoutHeads(Designer(q.copy(), stations: const VihStations.none()).designAll()));
  });

  test('automatic flows pack the stations by flow like zone valves; energy grouping takes them', () {
    final p = _golf(flows: const []);
    (p.byId('ws') as WaterSupplyEntity).designFlow = 10 * m3sPerM3h;
    final plan = autoSystemFlows(p, AutoFlowOptions());
    expect(plan.flows.map((f) => f.valveIds), [
      {'vih:A', 'vih:B'},
      {'vih:C'},
    ]);
    expect(plan.flows.first.name, contains('A + B'));
    expect(autoSystemFlows(p, AutoFlowOptions(valveInHead: false)).flows, isEmpty);
    // the flows applied, the design runs the stations as planned
    p.systemFlows.addAll(plan.flows);
    final r = Designer(p).designAll();
    expect(r.systemFlows.map((f) => f.heads.map((h) => h.stationId).join('+')), ['vih:A+vih:B', 'vih:C']);
    // the scheduled stations are zones of the energy grouping, at the node
    // of their most demanding head
    final (zones, _) = energyZonesFromDesign(p, r);
    final byId = {for (final z in zones) z.id: z};
    expect(byId.keys, ['vih:A', 'vih:B', 'vih:C']);
    expect(byId['vih:C']!.elevation, -8);
    expect(byId['vih:A']!.requiredHead, closeTo(31, 1e-9));
    expect(byId['vih:B']!.flow, closeTo(r.vihStations['vih:B']!.flow, 1e-12));
    final flows = systemFlowsFromGroups(p, groupZonesForEnergy(zones, options: const GroupingOptions(maxFlow: 10 * m3sPerM3h)).groups);
    expect(flows.expand((f) => f.valveIds).toSet(), {'vih:A', 'vih:B', 'vih:C'});
  });

  test('removing what is gone from the flows keeps the station ids, and drops stale ones', () {
    final p = _golf(
      flows: const [
        {'vih:A', 'vih:B'},
        {'vih:C', 'gone'},
      ],
    );
    final empty = Advice(code: 'flow_empty', raw: 'flow_empty', level: AdviceLevel.warning);
    expect(applyFix(p, empty, FixKind.removeEmptyFlows).ok, isTrue);
    expect(p.systemFlows.map((f) => f.valveIds), [
      {'vih:A', 'vih:B'},
      {'vih:C'},
    ]);
    // a station renamed away leaves an id that is no station any more
    p.systemFlows.first.valveIds.add('vih:Old');
    expect(applyFix(p, empty, FixKind.removeEmptyFlows).ok, isTrue);
    expect(p.systemFlows.first.valveIds, {'vih:A', 'vih:B'});
    // the station module is part of the public API
    expect(api.vihStationId(p.byId('h9') as OutletEntity), 'vih:C');
  });

  test('two-wire: the heads of a station on one number, two solenoids per decoder output', () {
    final p = _golf(wired: true);
    final tw = designTwoWire(p, flows: wiringFlows(p))!;
    expect(tw.warnings, isEmpty);
    expect(tw.stations.map((s) => s.valveId), [..._a, ..._b, ..._c]);
    expect(tw.stations.map((s) => s.station), [1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3]);
    expect(tw.stations.map((s) => s.zoneName).toSet(), {'A', 'B', 'C'});
    // a decoder at the first head of each station: the heads 10 m apart are
    // within the 30 m solenoid cable, two by two on an output
    expect(tw.decoders.map((d) => (d.capacity, d.valveIds.length)), [(2, 4), (2, 4), (2, 4)]);
    expect(tw.decoders.map((d) => d.p.x), [10, 50, 95]);
    final path = tw.paths.single;
    expect((path.used, path.decoders, path.maxOpen), (3, 3, 2));
    final pr = p.params;
    const idle = 0.001;
    // A opening (four solenoids at once) with B holding
    expect(path.peakCurrentA, closeTo(3 * idle + 4 * pr.solenoidInrushA + 4 * pr.solenoidHoldingA, 1e-12));
    // C alone, at its decoder 100 m along the pair: the current beyond every
    // stretch (its four heads opening, the idle decoders), both conductors
    final r = p.catalog.wire(path.wireId)!.ohmPerKm;
    final slack = 1 + pr.wireSlackPct / 100;
    final drop = ((4 * pr.solenoidInrushA + 3 * idle) * 15 + (4 * pr.solenoidInrushA + 2 * idle) * 40 + (4 * pr.solenoidInrushA + idle) * 45) * 2 * slack;
    for (final s in tw.stations.where((s) => s.zoneName == 'C')) {
      expect(s.volts, closeTo(34 - drop * r / 1000, 1e-9));
      expect(s.openTogether, 1);
    }
    expect(tw.wireMeters[path.wireId], closeTo(2 * 130 * slack, 1e-9));
    // one solenoid per output: one output per head
    final one = designTwoWire(p, flows: wiringFlows(p), spec: const TwoWireSpec(solenoidsPerOutput: 1))!;
    expect(one.decoders.map((d) => d.capacity), [4, 4, 4]);
    // the heads no route reaches, the station's others still wired
    final short = designTwoWire(_golf(wired: true, wireTo: 100), flows: wiringFlows(p))!;
    expect(short.warnings, contains('twowire_unwired:h10:h11:h12'));
    expect(short.stations.where((s) => s.zoneName == 'C').map((s) => s.valveId), ['h9']);
  });

  test('EPANET: a system flow exports the heads of the stations it runs', () {
    // the heads with an emitter in the file
    Set<String> emitting(Project q, EpanetExport x) {
      final m = EpanetInpReader.parse(x.text);
      return {
        for (final e in Designer(q).vihHeadNodes.entries)
          if (m.emitters.containsKey(x.nodeIds[e.value])) e.key,
      };
    }

    final p = _golf();
    final r = Designer(p).designAll();
    final f1 = EpanetWriter.write(p, results: r, scope: const EpanetScope.systemFlow('f1'));
    expect(emitting(p, f1), {..._a, ..._b});
    // read back and solved, the flow of the analysis
    final back = EpanetInpReader.parse(f1.text).toNetwork().solve();
    expect(back.converged, isTrue);
    final q = back.nodes.values.fold(0.0, (s, n) => s + n.emitterFlow);
    expect(q, closeTo(_flow(r, 'f1').totalFlow, 1e-3 * q));
    expect(emitting(p, EpanetWriter.write(p, results: r, scope: const EpanetScope.systemFlow('f2'))), {..._c});
    expect(emitting(p, EpanetWriter.write(p, results: r)), {..._a, ..._b, ..._c});
    // stations in no flow: every head in every flow, as before
    final legacy = _golf(
      flows: const [
        {'v1'},
        {'v2'},
      ],
      valves: true,
    );
    final rl = Designer(legacy).designAll();
    expect(emitting(legacy, EpanetWriter.write(legacy, results: rl, scope: const EpanetScope.systemFlow('f1'))), {..._a, ..._b, ..._c});
  });

  test('static lift of the pump: the worst head of the stations of the flows', () {
    final p = _golf();
    final r = Designer(p).designAll();
    final ws = p.byId('ws') as WaterSupplyEntity;
    final duty = _flow(r, 'f1').supplies.single;
    // A and B on level ground need 30 m on a 1 m riser above the water level
    expect(staticLift(p, r, ws, duty), closeTo(31, 1e-9));
    // heads in no flow do not set it (the valves alone, as before)
    final legacy = _golf(
      flows: const [
        {'v1'},
        {'v2'},
      ],
      valves: true,
    );
    final rl = Designer(legacy).designAll();
    final top = rl.systemFlows.expand((f) => f.valves).map((v) => rl.zones[v.valveId]!.valveElevation + v.requiredHead).reduce((a, b) => a > b ? a : b);
    expect(staticLift(legacy, rl, legacy.byId('ws') as WaterSupplyEntity, rl.systemFlows.first.supplies.single), closeTo(top - rl.systemFlows.first.supplies.single.elevation, 1e-9));
  });

  test('controller programme, transients and fertigation with the stations', () {
    final p = _golf();
    // an area watered by the heads of A and B
    p.entities.add(AreaEntity(id: 'lawn', name: 'Fairway', points: const [Pt(0, -15), Pt(85, -15), Pt(85, 15), Pt(0, 15)]));
    final r = Designer(p).designAll();
    // the programme: the stations by name, the run time of their area
    final prog = buildControllerProgram(p, r, startDate: DateTime(2026, 10, 25), days: 1);
    expect(prog.entries.map((e) => e.zones), [
      ['A', 'B'],
      ['C'],
    ]);
    final lawn = cropWaterRequirements(p, r).single;
    expect(lawn.hoursPerEvent, greaterThan(0));
    expect(prog.perFlowHours['f1'], closeTo(lawn.hoursPerEvent, 1e-12));
    // C waters no area: the flow keeps its duration
    expect(prog.perFlowHours['f2'], 1);
    expect(prog.warnings, contains('schedule_no_area:f2'));
    expect(areasOfStation(p, 'vih:A').map((a) => a.id), ['lawn']);
    expect(areasOfStation(p, 'vih:C'), isEmpty);

    // transients: the heads of a flow of stations only close with their valves
    final study = TransientStudy(p, results: r);
    for (final j in study.jobs) {
      final run = study.run(j);
      expect(run.skipped, isNull, reason: j.flow.id);
      expect(run.maxSurge, greaterThan(0), reason: j.flow.id);
    }

    // fertigation: to the nearest head first, the farthest last, the area of
    // the stations
    final d = opsDesigner(p, r);
    final f1 = fertigationSetup(d, r, p.systemFlows.first, 'ws')!;
    expect(f1.zones.map((z) => z.demandId), ['vih:A', 'vih:B']);
    for (final z in f1.zones) {
      expect(z.emitterFirst!, greaterThan(z.valveFirst));
      expect(z.emitterFull!, greaterThanOrEqualTo(z.emitterFirst!));
    }
    expect(f1.zones.last.emitterFirst, closeTo(f1.farthestArrival, 1e-12));
    expect(f1.mainline.outlets.length, 8);
    expect(f1.areaM2, closeTo(85 * 30, 1e-6));
    final f2 = fertigationSetup(d, r, p.systemFlows.last, 'ws')!;
    expect(f2.zones.single.demandId, 'vih:C');
    expect(f2.mainline.unreached, isEmpty);
  });
}
