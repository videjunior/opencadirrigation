import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/electrical.dart';
import 'package:opencadirrigation/core/design/energy_grouping.dart';
import 'package:opencadirrigation/core/design/fertigation.dart';
import 'package:opencadirrigation/core/design/network_ops.dart';
import 'package:opencadirrigation/core/design/on_demand.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/design/tariff.dart';
import 'package:opencadirrigation/core/design/two_wire.dart';
import 'package:opencadirrigation/core/design/wire_routing.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// The glue between a designed project and the network operation analyses:
/// on-demand flows, tariff schedule, energy grouping, wire routes,
/// criticality, calibration and fertigation, on the example gallery.
void main() {
  final t = I18n('en');
  (Project, DesignResults) designed(ExampleId id) {
    final p = buildExample(id, t.call, lang: 'en');
    return (p, Designer(p, label: (k) => t(k)).designAll());
  }

  final (orchard, orchardResults) = designed(ExampleId.orchard);
  final valves = orchard.entities.whereType<ControlValveEntity>().toList();

  test('the designer of the analyses uses the design results for the demands', () {
    final d = opsDesigner(orchard, orchardResults);
    expect(identical(d.results.zones[valves.first.id], orchardResults.zones[valves.first.id]), isTrue);
    expect(mainlineDemands(d), [for (final v in valves) v.id]);
    final duty = demandDuty(orchardResults, valves.first.id)!;
    expect(duty.$1, orchardResults.zones[valves.first.id]!.totalFlow);
    expect(duty.$2, orchardResults.zones[valves.first.id]!.requiredUpstreamHead);
    expect(demandDuty(orchardResults, 'nothing'), isNull);
    // the supply runs at the highest head of its flows
    final pressure = designSupplyPressure(d, orchardResults);
    final supply = orchard.entities.whereType<WaterSupplyEntity>().single;
    expect(pressure.keys, [supply.id]);
    expect(pressure[supply.id], orchardResults.systemFlows.map((f) => f.supplies.single.head).reduce(math.max));
    expect(clockOf(1290), '21:30');
    expect(clockOf(-30), '23:30');
    expect(clockOf(1440 + 61), '01:01');
  });

  test('on demand: one hydrant per zone at its node, demands left to the draws, design flows per link', () {
    final m = onDemandModel(orchard, orchardResults)!;
    expect(m.hydrants.map((h) => h.id), [for (final v in valves) v.id]);
    for (final h in m.hydrants) {
      final z = orchardResults.zones[h.id]!;
      expect(h.discharge, z.totalFlow);
      expect(h.minPressure, z.requiredUpstreamHead);
      expect(h.nodeId, m.designer.demandNodeOf(h.id));
      expect(m.network.nodes[h.nodeId]!.demand, 0);
      // the areas of the example have a water balance: hours from the crop
      expect(h.hoursPerDay, greaterThan(0));
      expect(h.hoursPerDay, lessThanOrEqualTo(24));
    }
    expect(m.designFlows, isNotEmpty);
    final c = clementFlows(m.network, m.hydrants);
    // two hydrants, fewer than N_min: every pipe carries all of its hydrants
    final total = m.hydrants.fold(0.0, (s, h) => s + h.discharge);
    expect(c.sourceFlow.values.single, closeTo(total, 1e-12));
    final rows = onDemandPipeRows(m, c);
    expect(rows.first.flow, closeTo(total, 1e-12));
    expect(rows.first.hydrants, 2);
    expect(rows.first.rule, ClementRule.allOpen);
    // the trunk carries one zone at a time in the design: on demand it carries both
    expect(rows.first.ratio, greaterThan(1));
    expect(rows.first.velocity, closeTo(total / (math.pi * rows.first.diameter * rows.first.diameter / 4), 1e-12));
    expect(rows.map((r) => r.entityId).toSet().length, rows.length);
    final need = clementSupplyPressure(m, c);
    expect(need.values.single, greaterThan(0));
    // the random check network: the supplies at the pressure asked
    final supply = m.supplyPressure.keys.single;
    final net = onDemandCheckNetwork(m, {supply: 33});
    final sn = net.nodes[m.designer.model.supplyNodes[supply]]!;
    expect(sn.fixedHead! - sn.elevation, closeTo(33, 1e-12));
    final check = checkRandomConfigurations(net, m.hydrants, probabilities: c.probabilities, options: const RandomCheckOptions(configurations: 50));
    expect(check.configurations, 50);
    expect(m.network.nodes[sn.id]!.fixedHead, isNot(closeTo(sn.elevation + 33, 1e-9)), reason: 'the model keeps the design pressure');
  });

  test('on demand with a pivot: its machine flow and inlet head', () {
    final (p, r) = designed(ExampleId.pivot);
    final m = onDemandModel(p, r)!;
    final pv = r.pivots.values.single;
    expect(m.hydrants.single.id, pv.pivotId);
    expect(m.hydrants.single.discharge, pv.flow);
    expect(m.hydrants.single.minPressure, pv.inletHead);
  });

  test('tariff: the schedule sets the start hours of the system flows', () {
    final p = buildExample(ExampleId.orchard, t.call, lang: 'en');
    final r = Designer(p).designAll();
    final s = scheduleJobs(tariffJobsFromDesign(p, r), TariffSeason(basePricePerKwh: 0.5, discount: IrrigationDiscount.brazil(BrazilConsumerGroup.b, BrazilDiscountRegion.others)));
    expect(s.jobs.map((j) => j.id).toSet(), {for (final f in p.systemFlows) f.id});
    final n = applyTariffSchedule(p, s);
    expect(n, greaterThan(0));
    for (final j in s.jobs) {
      expect(p.systemFlows.firstWhere((f) => f.id == j.id).startHour, j.startMinute / 60);
    }
    expect(applyTariffSchedule(p, s), 0);
  });

  test('energy grouping: pivots join the zones, the designer heads, the energy of a grouping', () {
    final d = opsDesigner(orchard, orchardResults);
    final (zones, source) = energyZonesWithPivots(d, orchardResults);
    expect(zones.map((z) => z.id).toSet(), {for (final v in valves) v.id});
    final head = designerGroupHead(d, [valves.first.id]);
    // the flow of that zone alone in the design: its pump and supply pressure
    final f = orchardResults.systemFlows.firstWhere((f) => f.valves.single.valveId == valves.first.id);
    expect(head, closeTo(f.supplies.single.head + f.devices.fold(0.0, (s, dv) => s + math.max(0.0, dv.pumpHead)), 0.05));
    expect(designerGroupHead(d, [for (final v in valves) v.id]), greaterThanOrEqualTo(head - 1e-6));
    final groups = [for (final f in orchard.systemFlows) f.valveIds];
    final e = groupingEnergyKwh(groups, zones, (g) => designerGroupHead(d, g.map((z) => z.id)), efficiency: 0.65);
    expect(e, greaterThan(0));
    final formula = groupingEnergyKwh(groups, zones, (g) => formulaGroupHead(g, source));
    expect(formula, greaterThan(0));
    expect(formulaGroupHead(const [], 0), 0);
    // the pivot example has no zone valves: the pivot is the zone
    final (p, r) = designed(ExampleId.pivot);
    final dp = opsDesigner(p, r);
    final (pz, _) = energyZonesWithPivots(dp, r);
    expect(pz.single.id, r.pivots.keys.single);
    expect(pz.single.requiredHead, r.pivots.values.single.inletHead);
    expect(pz.single.elevation, dp.model.nodes[dp.demandNodeOf(pz.single.id)]!.elevation);
    final g = groupZonesForEnergy(pz, groupHead: (g) => designerGroupHead(dp, g.map((z) => z.id)));
    expect(g.groups.single.zoneIds, [pz.single.id]);
    expect(g.energyKwh, greaterThan(0));
  });

  test('wire routes: the valves and the master valves along the pipes, ready for both wiring designs', () {
    final p = buildExample(ExampleId.orchard, t.call, lang: 'en');
    final master = p.catalog.valves.firstWhere((v) => v.kind == ValveKind.master);
    final main = p.entities.whereType<PipeEntity>().firstWhere((e) => e.scope == HydraulicScope.mainline);
    p.entities.add(MiscHydraulicEntity(id: 'mv', position: Pt.lerp(main.points.first, main.points.last, 0.5), valveSpecId: master.id));
    expect(masterValvesOf(p).keys, ['mv']);
    final r = routeProjectWires(p);
    expect(r.warnings, isEmpty);
    final st = {for (final s in r.stations) s.entityId: s};
    for (final v in p.entities.whereType<ControlValveEntity>()) {
      expect(st[v.id]!.kind, StationKind.zoneValve);
    }
    expect(st['mv']!.kind, StationKind.masterValve);
    expect(st.values.where((s) => s.kind == StationKind.pumpRelay), hasLength(1));
    final before = p.entities.length;
    final old = p.entities.whereType<WireEntity>().length;
    final wires = wireEntitiesOf(p, r);
    expect(wires, hasLength(r.routes.length));
    expect(wires.map((w) => w.id).toSet(), hasLength(wires.length));
    p.entities
      ..removeWhere((e) => e is WireEntity)
      ..addAll(wires);
    expect(p.entities.length, before - old + wires.length);
    final e = designElectrical(p, flows: wiringFlows(p))!;
    expect(e.warnings.where((w) => w.startsWith('elec_unwired') || w.startsWith('elec_wire_orphan')), isEmpty);
    final tw = designTwoWire(p, flows: wiringFlows(p))!;
    expect(tw.warnings.where((w) => w.startsWith('twowire_unwired')), isEmpty);
    expect(tw.paths.single.used, p.entities.whereType<ControlValveEntity>().length);
    // without system flows every valve runs at once
    final q = Project()..entities.addAll([ControlValveEntity(id: 'a', position: Pt.zero), ControlValveEntity(id: 'b', position: const Pt(1, 0))]);
    expect(wiringFlows(q), [
      {'a', 'b'},
    ]);
  });

  test('criticality: the trunk of a branched mainline cuts every zone off', () {
    final d = opsDesigner(orchard, orchardResults);
    final all = SystemFlow(id: 'all', name: 'all', valveIds: {for (final v in valves) v.id});
    final v = criticalityOf(d, orchardResults, all)!;
    expect(v.result.tree, isTrue);
    expect(v.rows, isNotEmpty);
    final worst = v.rows.first;
    expect(worst.cutOff.toSet(), {for (final x in valves) x.id});
    expect(worst.scenario.lostDemand, closeTo(v.result.totalDemand, 1e-9));
    expect(orchard.byId(worst.entityId), isA<PipeEntity>());
    // a branch cuts one zone off
    expect(v.rows.any((r) => r.cutOff.length == 1), isTrue);
    expect(v.demandsAt.values.expand((x) => x).toSet(), {for (final x in valves) x.id});
  });

  test('calibration: readings from a rougher pipe give its C factor back', () {
    final pts = measurePoints(opsDesigner(orchard, orchardResults));
    expect(pts.where((m) => m.kind == MeasurePointKind.valve).map((m) => m.entityId), [for (final v in valves) v.id]);
    expect(pts.where((m) => m.kind == MeasurePointKind.supply), hasLength(1));
    expect(pts.where((m) => m.kind == MeasurePointKind.device), hasLength(1), reason: 'the filter');
    final sf = orchard.systemFlows.last;
    // the truth: every C at 75 %
    final truthProject = buildExample(ExampleId.orchard, t.call, lang: 'en');
    final truthResults = Designer(truthProject).designAll();
    truthProject.params.hazenCScale = 0.75;
    final td = opsDesigner(truthProject, truthResults);
    final (tnet, tres, _) = td.mainlineNetworkFor(sf)!;
    final supply = orchard.entities.whereType<WaterSupplyEntity>().single;
    final supplyNode = tnet.nodes[td.model.supplyNodes[supply.id]]!;
    final valve = sf.valveIds.single;
    final readings = [
      FieldReading(entityId: supply.id, value: supplyNode.fixedHead! - supplyNode.elevation),
      FieldReading(entityId: valve, value: tres.nodes[td.demandNodeOf(valve)]!.pressure, sigma: 0.05),
    ];
    final d = opsDesigner(orchard, orchardResults);
    final cal = calibrateFromField(
      d,
      sf,
      pressures: readings,
      flows: [FieldReading(entityId: supply.id, value: orchardResults.zones[valve]!.totalFlow)],
    )!;
    expect(cal.boundary, [supply.id]);
    expect(cal.result.residuals.map((r) => cal.entityOf[r.id]), [valve, supply.id]);
    expect(cal.result.scales.single, closeTo(0.75, 0.02));
    expect(cal.result.objective, lessThan(cal.result.initialObjective));
    final (s, o) = calibratedC(DesignParameters(hazenCScale: 1.2, hazenCOffset: -5), 0.5);
    expect(s, closeTo(0.6, 1e-12));
    expect(o, closeTo(-2.5, 1e-12));
  });

  test('fertigation: travel to every valve and on to the farthest emitter, from the supply or the pump', () {
    final d = opsDesigner(orchard, orchardResults);
    final points = injectionPoints(d);
    final supply = orchard.entities.whereType<WaterSupplyEntity>().single;
    final pump = orchard.entities.whereType<PumpEntity>().single;
    expect(points, [supply.id, pump.id]);
    final all = SystemFlow(id: 'all', name: 'all', valveIds: {for (final v in valves) v.id});
    final s = fertigationSetup(d, orchardResults, all, supply.id)!;
    expect(s.zones.map((z) => z.demandId), [for (final v in valves) v.id]);
    for (final z in s.zones) {
      expect(z.valveFirst, greaterThan(0));
      expect(z.valveFull, greaterThanOrEqualTo(z.valveFirst - 1e-9));
      expect(z.emitterFirst, greaterThan(z.valveFirst));
      expect(z.emitterFull, greaterThanOrEqualTo(z.emitterFirst! - 1e-9));
    }
    expect(s.flow, closeTo(valves.fold(0.0, (a, v) => a + orchardResults.zones[v.id]!.totalFlow), 1e-6));
    // the two blocks of the example: 120 × 45 m and 110 × 50 m
    expect(s.areaM2, closeTo(120 * 45 + 110 * 50, 1e-6));
    expect(s.farthestArrival, greaterThan(0));
    expect(s.fullArrival, greaterThanOrEqualTo(s.farthestArrival - 1e-9));
    final plan = planFertigation(FertigationInput(irrigationHours: 3, flow: s.flow, areaHa: s.areaM2 / 1e4, doseKgPerHa: 20, stockKgPerL: 0.25), s.combined);
    expect(plan.injection, greaterThan(0));
    expect(plan.flushing, greaterThanOrEqualTo(s.fullArrival - 1e-9));
    // from the pump outlet: a little earlier
    final fromPump = fertigationSetup(d, orchardResults, all, pump.id)!;
    expect(fromPump.zones.first.valveFirst, lessThanOrEqualTo(s.zones.first.valveFirst + 1e-9));
    expect(fromPump.flow, closeTo(s.flow, 1e-6));
    // the filter is a device a venturi can bypass
    final sites = venturiSites(s);
    expect(sites.map((x) => orchard.byId(x.entityId)), everyElement(isA<MiscHydraulicEntity>()));
    expect(sites.single.headLoss, greaterThan(0));
    expect(sites.single.inletPressure, greaterThan(0));
    expect(fertigationSetup(d, orchardResults, all, 'nothing'), isNull);
  });

  test('a project without a supply has no mainline to analyse', () {
    final p = Project()..entities.add(ControlValveEntity(id: 'v', position: Pt.zero));
    final r = DesignResults(timestamp: DateTime(2026));
    expect(onDemandModel(p, r), isNull);
    final d = opsDesigner(p, r);
    expect(criticalityOf(d, r, SystemFlow(id: 'f', name: 'f', valveIds: {'v'})), isNull);
    expect(calibrateFromField(d, SystemFlow(id: 'f', name: 'f', valveIds: {'v'})), isNull);
    expect(fertigationSetup(d, r, SystemFlow(id: 'f', name: 'f', valveIds: {'v'}), 'v'), isNull);
    expect(injectionPoints(d), isEmpty);
    expect(designerGroupHead(d, ['v']), 0);
    expect(routeProjectWires(p).warnings, ['wire_route_no_controller']);
    expect(demandsAreaM2(p, r, ['v']), 0);
    expect(demandHoursPerDay(p, r), isEmpty);
  });
}
