import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/air_valves.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/network_builder.dart';
import 'package:opencadirrigation/core/design/transient_analysis.dart';
import 'package:opencadirrigation/core/hydraulics/network.dart';
import 'package:opencadirrigation/core/hydraulics/pump.dart';
import 'package:opencadirrigation/core/hydraulics/water_hammer.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

import '../support/language_packs.dart';

import '../support/perf.dart';

/// A water supply at [supply], a mainline through [vertices] (PVC DN 100 by
/// default) and zone valves at [valves], each feeding a demand point of
/// [nozzle] 5 m beside the line. [spots] give the terrain (x, y, z).
Project lineProject({
  Pt supply = Pt.zero,
  required List<Pt> vertices,
  required List<Pt> valves,
  double designHead = 45,
  bool calculated = false,
  String pipe = 'pvc100',
  String? pumpSpec,
  String nozzle = 'd20',
  List<(double, double, double)> spots = const [],
}) {
  final p = Project(catalog: Catalog.defaultCatalog());
  p.params.valveClosureTimeS = 0;
  for (final (x, y, z) in spots) {
    p.entities.add(SpotHeightEntity(id: p.newId(), position: Pt(x, y), elevation: z));
  }
  p.entities.add(WaterSupplyEntity(id: p.newId(), position: supply, name: 'Supply', calculatePressure: calculated, designHeadM: designHead));
  p.entities.add(PipeEntity(id: p.newId(), points: [supply, ...vertices], scope: HydraulicScope.mainline, pipeSpecId: pipe, computerSized: false));
  if (pumpSpec != null) {
    final at = supply + (vertices.first - supply).normalized * 2;
    p.entities.add(PumpEntity(id: p.newId(), position: at, pumpSpecId: pumpSpec));
  }
  for (var i = 0; i < valves.length; i++) {
    final v = valves[i];
    final out = v + const Pt(0, 5);
    p.entities.add(ControlValveEntity(id: 'valve$i', position: v, valveSpecId: 'ev80', zoneName: 'Z$i'));
    p.entities.add(PipeEntity(id: p.newId(), points: [v, out], scope: HydraulicScope.zone, pipeSpecId: 'pvc75', computerSized: false));
    p.entities.add(OutletEntity(id: p.newId(), position: out, outletSpecId: 'demand', nozzleId: nozzle, headM: 25));
  }
  return p;
}

void roundTrip(Map<String, dynamic> Function() json, Map<String, dynamic> Function(Map<String, dynamic>) back) {
  final a = jsonEncode(json());
  expect(jsonEncode(back(jsonDecode(a) as Map<String, dynamic>)), a);
}

void main() {
  setUpAll(installLanguagePacksFromDisk);
  final t = I18n('pt');

  group('transients of the examples', () {
    for (final id in [ExampleId.sugarcane, ExampleId.gravity]) {
      test('${id.name}: every scenario runs and the steady state lies inside the envelopes', () {
        final p = buildExample(id, t.call, lang: 'pt');
        final r = Designer(p, label: (k) => t(k)).designAll();
        final iso = isolationDevices(p);
        final study = TransientStudy(
          p,
          results: r,
          label: (k) => t(k),
          options: TransientStudyOptions(scenarios: TransientScenario.values.toSet(), isolationId: iso.isEmpty ? null : iso.first.id),
        );
        expect(study.jobs, hasLength(study.mainline.flows.length * 3));
        final watch = Stopwatch()..start();
        final a = study.analyze();
        expect(watch.elapsedMilliseconds, lessThan(perfBudgetMs(20000)));
        final ran = a.runs.where((x) => x.ran).toList();
        expect(ran.where((x) => x.scenario == TransientScenario.valveClosure), hasLength(study.mainline.flows.length));
        for (final run in ran) {
          final why = '${run.flowName} ${run.scenario.name}';
          expect(run.pipes, isNotEmpty, reason: why);
          expect(run.timeStep, greaterThan(0));
          expect(run.duration, inInclusiveRange(15, 120));
          expect(run.barometricHead, closeTo(atmosphericHead(study.mainline.siteElevation), 1e-9));
          for (final e in run.pipes) {
            expect(e.maxPressure, greaterThanOrEqualTo(e.steadyMaxPressure - 1e-6), reason: '$why ${e.entityId}');
            expect(e.minPressure, lessThanOrEqualTo(e.steadyMinPressure + 1e-6), reason: '$why ${e.entityId}');
            expect(e.minPressure, greaterThanOrEqualTo(run.vapourGauge - 1e-9), reason: 'never below the vapour pressure');
            expect(e.maxHead, greaterThanOrEqualTo(e.minHead));
          }
          // the profile along the critical path holds the steady grade line
          expect(run.profile.length, greaterThan(2), reason: why);
          for (var i = 1; i < run.profile.length; i++) {
            expect(run.profile[i].chainage, greaterThanOrEqualTo(run.profile[i - 1].chainage - 1e-9));
          }
          for (final pt in run.profile) {
            expect(pt.steadyHead, inInclusiveRange(pt.minHead - 1e-4, pt.maxHead + 1e-4), reason: '$why at ${pt.chainage}');
          }
          for (final tr in [run.source, run.worst]) {
            expect(tr, isNotNull, reason: why);
            expect(tr!.pressures.length, tr.times.length);
            expect(tr.times.first, 0);
            expect(tr.times.last, closeTo(run.duration, 1e-6));
          }
          // the Newton of the junctions converges, also with the air valve
          // at the pump discharge opening and closing
          expect(run.messages.where((m) => m.startsWith('transient_not_converged')), isEmpty, reason: why);
          // messages carry entity ids of the project
          for (final m in run.messages) {
            final i = m.indexOf(':');
            if (i > 0 && m.startsWith('transient_') && !m.startsWith('transient_not_converged')) expect(p.byId(m.substring(i + 1)), isNotNull, reason: m);
          }
        }
        roundTrip(a.toJson, (j) => TransientAnalysis.fromJson(j).toJson());
        expect(a.worstRun, greaterThanOrEqualTo(0));
        expect(a.nodeMinHeads, isNotEmpty);
        if (id == ExampleId.sugarcane) {
          final trip = ran.firstWhere((x) => x.scenario == TransientScenario.pumpTrip);
          final pump = p.entities.whereType<PumpEntity>().first;
          expect(trip.checkValves.keys, contains(pump.id), reason: 'the pump check valve closes after the trip');
          expect(trip.source!.speeds.first, 1);
          expect(trip.source!.speeds.last, lessThan(0.5), reason: 'the pump runs down');
          expect(trip.source!.entityId, pump.id);
          // the air valve drawn on the mainline takes part
          final air = p.entities.whereType<MiscHydraulicEntity>().firstWhere((e) => p.catalog.valve(e.valveSpecId)?.kind == ValveKind.airRelease);
          final noAir = TransientStudy.on(study.mainline, options: const TransientStudyOptions(scenarios: {TransientScenario.pumpTrip}, airValves: false)).analyze();
          expect(a.messages, contains('transient_air_admitted:${air.id}'), reason: 'the downsurge opens the air valve at the pump discharge');
          expect(a.runs.expand((x) => x.findings).any((f) => f.kind == TransientFindingKind.airAdmitted && f.entityId == air.id && f.position != null), isTrue);
          expect(noAir.messages.where((m) => m.startsWith('transient_air_admitted')), isEmpty);
        } else {
          expect(a.messages, contains('transient_no_pump'), reason: 'the gravity line has no pump');
          expect(a.runs.where((x) => x.scenario == TransientScenario.pumpTrip).every((x) => !x.ran), isTrue);
        }
      }, tags: perfTag);
    }
  });

  test('an instantaneous closure on a simple line gives about the Joukowsky surge', () {
    final p = lineProject(vertices: const [Pt(800, 0)], valves: const [Pt(800, 0)]);
    final study = TransientStudy(p, options: const TransientStudyOptions(closureTime: 0, duration: 30));
    final run = study.analyze().runs.single;
    expect(run.ran, isTrue, reason: run.skipped);
    expect(run.closureTime, 0);
    final st = study.mainline.stateOf(study.mainline.flows.first)!;
    final node = study.mainline.designer.demandNodeOf('valve0')!;
    final q = st.demand['valve0']!;
    final spec = p.catalog.pipe('pvc100')!;
    final a = waveCelerity(diameter: spec.innerDiameter, wallThickness: spec.wallThicknessMm / 1000, material: spec.material);
    final v = q / (math.pi * spec.innerDiameter * spec.innerDiameter / 4);
    final joukowsky = a * v / gravity;
    expect(joukowsky, inInclusiveRange(10, 40));
    final h0 = st.steady.nodes[node]!.head;
    final supply = st.network.nodes.values.firstWhere((n) => n.kind == HNodeKind.reservoir);
    final friction = supply.fixedHead! - h0;
    final rise = run.nodeMaxHeads[node]! - h0;
    // a·ΔV/g at once, then the line packing adds up to the friction loss
    expect(rise, greaterThanOrEqualTo(0.97 * joukowsky));
    expect(rise, lessThanOrEqualTo(joukowsky + friction + 0.03 * joukowsky));
    expect(run.maxSurge, closeTo(rise, 0.05 * joukowsky));
    // the wave reaches the supply and comes back: a downsurge follows
    expect(run.nodeMinHeads[node]!, lessThan(h0 - 0.5 * joukowsky));
    // the pipe is within its class and the critical point is the valve end
    final env = run.pipes.single;
    expect(env.rating, closeTo(spec.ratingAt(p.params.waterTempC), 1e-9));
    expect(env.maxPressure, closeTo(rise + (h0 - st.network.nodes[node]!.elevation), 0.05 * joukowsky));
    expect(run.worst!.nodeId, node);
    expect(run.worst!.position!.distanceTo(const Pt(800, 0)), lessThan(0.1));
    // a slow closure (ten times 2L/a) surges much less
    final slow = TransientStudy.on(study.mainline, options: TransientStudyOptions(closureTime: 20 * 800 / a, duration: 60)).analyze().runs.single;
    expect(slow.nodeMaxHeads[node]! - h0, lessThan(0.5 * rise));
  });

  test('a power failure trips the pump: the check valve closes, the speed falls, the discharge drops', () {
    final p = lineProject(vertices: const [Pt(600, 0)], valves: const [Pt(600, 0)], designHead: 0, pumpSpec: 'pump_c7_5');
    final study = TransientStudy(p, options: const TransientStudyOptions(scenarios: {TransientScenario.pumpTrip, TransientScenario.valveClosure}));
    final a = study.analyze();
    final trip = a.runs.firstWhere((r) => r.scenario == TransientScenario.pumpTrip);
    expect(trip.ran, isTrue, reason: trip.skipped);
    final pump = p.entities.whereType<PumpEntity>().single;
    expect(trip.checkValves[pump.id], isNotNull);
    expect(trip.source!.entityId, pump.id);
    final s = trip.source!;
    expect(s.speeds.first, 1);
    expect(s.speeds.last, lessThan(s.speeds.first));
    expect(s.pressures.reduce(math.min), lessThan(s.pressures.first - 1), reason: 'the downsurge at the discharge');
    // a heavier set runs down slower: a later check valve closure
    final heavy = TransientStudy.on(study.mainline, options: const TransientStudyOptions(scenarios: {TransientScenario.pumpTrip}, inertia: 0.1)).analyze().runs.single;
    expect(heavy.checkValves[pump.id]!, greaterThan(trip.checkValves[pump.id]!));
    // 4 poles: the slower speed estimates a larger inertia
    final slow = TransientStudy.on(study.mainline, options: const TransientStudyOptions(scenarios: {TransientScenario.pumpTrip}, motorPoles: 4)).analyze().runs.single;
    expect(slow.checkValves[pump.id]!, greaterThan(trip.checkValves[pump.id]!));
    expect(TransientStudyOptions.speedForPoles(2, 50), 2900);
    expect(TransientStudyOptions.speedForPoles(2, 60), 3500);
    expect(TransientStudyOptions.speedForPoles(4, 50), 1450);
    expect(TransientStudyOptions.speedForPoles(4, 60), 1750);
    // an isolation scenario without a device is reported, not simulated
    final none = TransientStudy.on(study.mainline, options: const TransientStudyOptions(scenarios: {TransientScenario.isolationClosure})).analyze();
    expect(none.runs.single.ran, isFalse);
    expect(none.messages, ['transient_no_isolation']);
  });

  group('air valves', () {
    // a hill: 100 m at both ends, 120 m in the middle
    const spots = [(0.0, -60.0, 100.0), (0.0, 60.0, 100.0), (500.0, -60.0, 120.0), (500.0, 60.0, 120.0), (1000.0, -60.0, 100.0), (1000.0, 60.0, 100.0)];
    Project hill() => lineProject(vertices: const [Pt(250, 0), Pt(500, 0), Pt(750, 0), Pt(1000, 0)], valves: const [Pt(1000, 0)], spots: spots, designHead: 50);

    test('a high point of the profile gets a combination valve on the pipe; inserted valves are connected', () {
      final p = hill();
      final mf = MainlineFlows(p);
      expect(mf.model.nodes.values.where((n) => n.p.distanceTo(const Pt(500, 0)) < 0.01).first.elevation, closeTo(120, 1e-6));
      final s = suggestMainlineAirValvesOn(mf);
      expect(s.paths, hasLength(1));
      expect(s.paths.first.length, closeTo(1000, 1e-6));
      final top = s.suggestions.firstWhere((v) => v.reasons.contains(AirValveReason.highPoint));
      expect(top.position.distanceTo(const Pt(500, 0)), lessThan(1e-6), reason: 'at the vertex of the summit');
      expect(top.type, AirValveType.combination);
      expect(top.elevation, closeTo(120, 1e-6));
      expect(top.sizing.largeOrifice, greaterThan(0));
      expect(top.sizing.smallOrifice, greaterThan(0));
      expect(top.specId, isNotNull);
      expect(p.catalog.valve(top.specId)!.sizeMm, greaterThanOrEqualTo(top.sizing.nominalSize * 1000 - 0.5));
      expect(top.existing, isFalse);
      // the end of the line: clear of the zone valve drawn there, on the pipe
      final end = s.suggestions.firstWhere((v) => v.reasons.contains(AirValveReason.lineEnd));
      expect(end.position.distanceTo(const Pt(999, 0)), lessThan(1e-6));
      for (final v in s.suggestions) {
        final pipe = p.byId(v.pipeEntityId!) as PipeEntity;
        expect(pipe.scope, HydraulicScope.mainline);
        expect(pipe.distanceTo(v.position), lessThan(1e-6));
      }
      roundTrip(s.toJson, (j) => AirValveStudy.fromJson(j).toJson());
      // drawn on the pipes: connected inline devices, then reported as existing
      final added = airValveEntities(s.missing, p.newId);
      expect(added, hasLength(s.suggestions.length));
      p.entities.addAll(added);
      final m = NetworkBuilder(p).build();
      expect(m.unconnectedEntities, isEmpty);
      for (final e in added) {
        expect(m.mainlineLinks, contains('dev_${e.id}'));
      }
      final again = suggestMainlineAirValves(p);
      expect(again.suggestions.every((v) => v.existing), isTrue);
      expect(again.missing, isEmpty);
      expect(airValveEntities(again.suggestions, p.newId), isEmpty);
    });

    test('the transient minimum envelope adds vacuum protection; a catalogue without air valves is reported', () {
      final p = hill();
      final mf = MainlineFlows(p);
      // a downsurge below the pipe at the quarter point of the ascent
      final quarter = mf.model.nodes.values.firstWhere((n) => n.p.distanceTo(const Pt(250, 0)) < 0.01);
      // nodes the transient does not cover keep their steady head
      final fake = TransientAnalysis(runs: const [], pipes: const [], messages: const [], nodeMinHeads: {quarter.id: quarter.elevation - 6}, nodeMaxHeads: const {});
      final s = suggestMainlineAirValvesOn(mf, transient: fake);
      expect(s.usedTransient, isTrue);
      final v = s.suggestions.firstWhere((x) => x.reasons.contains(AirValveReason.transientVacuum));
      expect(v.position.distanceTo(const Pt(250, 0)), lessThan(1e-6));
      // a real transient: the closure at the end of the line
      final a = TransientStudy.on(mf, options: const TransientStudyOptions(closureTime: 0)).analyze();
      expect(a.nodeMinHeads, isNotEmpty);
      expect(suggestMainlineAirValvesOn(mf, transient: a).usedTransient, isTrue);
      p.catalog.valves.removeWhere((x) => x.kind == ValveKind.airRelease);
      final none = suggestMainlineAirValves(p);
      expect(none.messages, contains('air_no_spec'));
      expect(none.suggestions.every((x) => x.specId == null), isTrue);
      expect(airValveEntities(none.suggestions, p.newId), isEmpty);
    });

    test('the suction side of a pump is left out; paths branch to every end', () {
      final p = lineProject(vertices: const [Pt(400, 0), Pt(400, 300)], valves: const [Pt(400, 300)], designHead: 0, pumpSpec: 'pump_c7_5');
      // a branch to a second valve
      p.entities.add(PipeEntity(id: p.newId(), points: const [Pt(400, 0), Pt(700, 0)], scope: HydraulicScope.mainline, pipeSpecId: 'pvc75', computerSized: false));
      p.entities.add(ControlValveEntity(id: 'valveB', position: const Pt(700, 0), valveSpecId: 'ev80', zoneName: 'ZB'));
      p.entities.add(PipeEntity(id: p.newId(), points: const [Pt(700, 0), Pt(700, 5)], scope: HydraulicScope.zone, pipeSpecId: 'pvc75', computerSized: false));
      p.entities.add(OutletEntity(id: p.newId(), position: const Pt(700, 5), outletSpecId: 'demand', nozzleId: 'd10', headM: 25));
      final s = suggestMainlineAirValves(p);
      expect(s.paths, hasLength(2));
      for (final path in s.paths) {
        expect(path.start, closeTo(2, 1e-6), reason: 'from the pump discharge');
      }
      final pump = s.suggestions.firstWhere((v) => v.reasons.contains(AirValveReason.pumpDischarge));
      expect(pump.position.distanceTo(const Pt(3, 0)), lessThan(1e-6), reason: '1 m downstream of the pump');
      expect(s.suggestions.where((v) => v.reasons.contains(AirValveReason.lineEnd)), hasLength(2));
      expect(s.messages, isEmpty, reason: 'no grade line below the pipe: the suction is left out');
    });
  });

  group('24-hour simulation', () {
    test('the energy and its cost match the hand calculation', () {
      final p = lineProject(vertices: const [Pt(300, 0), Pt(600, 0)], valves: const [Pt(300, 0), Pt(600, 0)], designHead: 0, pumpSpec: 'pump_c5', nozzle: 'd10');
      p.systemFlows
        ..add(SystemFlow(id: 'f1', name: 'Morning', valveIds: {'valve0'}, startHour: 6, durationHours: 4))
        ..add(SystemFlow(id: 'f2', name: 'Evening', valveIds: {'valve1'}, startHour: 19, durationHours: 3));
      p.params.powerCostPerKwh = 0.5;
      final mf = MainlineFlows(p);
      const options = EpsDayOptions(peakStartHour: 18, peakEndHour: 21, peakMultiplier: 3);
      final day = simulateDayOn(mf, options: options);
      expect(day.messages, isEmpty);
      expect(day.converged, isTrue);
      final pump = p.entities.whereType<PumpEntity>().single;
      final spec = p.catalog.pump(pump.pumpSpecId)!;
      (double, double) duty(String flow) {
        final st = mf.stateOf(p.systemFlows.firstWhere((f) => f.id == flow))!;
        final lr = st.steady.links['pump_${pump.id}']!;
        return (lr.flow, waterDensity * gravity * lr.flow * lr.pumpHead / spec.efficiencyAt(lr.flow) / 1000);
      }

      final (q1, p1) = duty('f1');
      final (q2, p2) = duty('f2');
      expect(p1, greaterThan(0.5));
      expect(p2, greaterThan(0.5));
      expect(day.energyKwh, closeTo(4 * p1 + 3 * p2, 1e-3 * (4 * p1 + 3 * p2)));
      // 19:00–21:00 in the peak band at three times the price, 21:00–22:00 not
      final cost = 0.5 * (4 * p1 + 2 * 3 * p2 + p2);
      expect(day.cost, closeTo(cost, 1e-3 * cost));
      expect(day.volume, closeTo((4 * q1 + 3 * q2) * 3600, 1e-3 * (4 * q1 + 3 * q2) * 3600));
      final pd = day.pumps.single;
      expect(pd.entityId, pump.id);
      expect(pd.hoursOn, closeTo(7, 1e-9));
      expect(pd.maxPowerKw, closeTo(math.max(p1, p2), 1e-3 * math.max(p1, p2)));
      expect(day.hours, hasLength(24));
      for (final h in day.hours) {
        final expected = h.hour >= 6 && h.hour < 10 ? p1 : (h.hour >= 19 && h.hour < 22 ? p2 : 0.0);
        expect(h.powerKw, closeTo(expected, 1e-3 * math.max(expected, 1)), reason: 'hour ${h.hour}');
        expect(h.flows, expected == 0 ? isEmpty : hasLength(1));
        if (expected > 0) {
          expect(h.lowestPressure.isFinite, isTrue);
          expect(h.lowestValve, h.hour < 12 ? 'valve0' : 'valve1');
          expect(h.lowestMargin, greaterThan(0), reason: 'the pump covers the valves');
        } else {
          expect(h.lowestPressure.isNaN, isTrue);
        }
      }
      expect(day.lowestPressure.length, day.times.length);
      expect(day.times.first, 0);
      expect(day.times.last, 86400);
      roundTrip(day.toJson, (j) => EpsDay.fromJson(j).toJson());
      // a flat tariff and the price of the parameters
      final flat = simulateDayOn(mf);
      expect(flat.cost, closeTo(0.5 * (4 * p1 + 3 * p2), 1e-3 * (4 * p1 + 3 * p2)));
    });

    test('flows across midnight and overlapping flows', () {
      expect(flowWindows(SystemFlow(id: 'a', name: 'a', startHour: 22, durationHours: 4)), [(79200.0, 7200.0), (0.0, 7200.0)]);
      expect(flowWindows(SystemFlow(id: 'b', name: 'b', startHour: 24, durationHours: 2)), [(0.0, 7200.0)]);
      expect(flowWindows(SystemFlow(id: 'c', name: 'c', startHour: 3, durationHours: 30)), [(0.0, 86400.0)]);
      expect(flowWindows(SystemFlow(id: 'd', name: 'd', startHour: 3, durationHours: 0)), isEmpty);
      final p = lineProject(vertices: const [Pt(300, 0), Pt(600, 0)], valves: const [Pt(300, 0), Pt(600, 0)], designHead: 0, pumpSpec: 'pump_c5', nozzle: 'd5');
      p.systemFlows
        ..add(SystemFlow(id: 'f1', name: 'Night', valveIds: {'valve0'}, startHour: 23, durationHours: 2))
        ..add(SystemFlow(id: 'f2', name: 'Late', valveIds: {'valve1'}, startHour: 0, durationHours: 2));
      final day = simulateDay(p);
      expect(day.messages, containsAll(['eps_flows_overlap:f1', 'eps_flows_overlap:f2']));
      final h0 = day.hours[0], h1 = day.hours[1], h23 = day.hours[23];
      expect(h0.flows, containsAll(['f1', 'f2']));
      expect(h1.flows, ['f2']);
      expect(h23.flows, ['f1']);
      // both zones draw at once from 0:00 to 1:00
      expect(h0.flow, closeTo(h1.flow + h23.flow, 0.02 * h0.flow));
      expect(day.pumps.single.hoursOn, closeTo(3, 1e-9));
    });

    test('a supply whose pressure the design calculates counts as a pump giving it', () {
      final p = lineProject(vertices: const [Pt(800, 0)], valves: const [Pt(800, 0)], calculated: true);
      p.systemFlows.add(SystemFlow(id: 'f', name: 'F', valveIds: {'valve0'}, startHour: 8, durationHours: 2));
      final mf = MainlineFlows(p);
      final st = mf.stateOf(p.systemFlows.single)!;
      final supply = st.network.nodes.values.firstWhere((n) => n.kind == HNodeKind.reservoir);
      final pressure = supply.fixedHead! - supply.elevation;
      expect(pressure, greaterThan(20));
      final q = st.demand['valve0']!;
      final day = simulateDayOn(mf);
      final kw = waterDensity * gravity * q * pressure / p.params.pumpEfficiency / 1000;
      final pd = day.pumps.single;
      expect(pd.calculated, isTrue);
      expect(pd.entityId, p.entities.whereType<WaterSupplyEntity>().single.id);
      expect(pd.energyKwh, closeTo(2 * kw, 2e-3 * kw));
      expect(day.hours[8].powerKw, closeTo(kw, 2e-3 * kw));
      // without a supply there is nothing to simulate
      expect(simulateDay(Project(catalog: Catalog.defaultCatalog())).messages, ['no_water_supply']);
    });
  });
}
