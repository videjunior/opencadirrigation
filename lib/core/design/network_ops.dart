/// Network operation tools on a designed project: the glue between the
/// design (the mainline exactly as the designer solves it for a set of
/// valves, the zone and pivot results) and the operation analyses of
/// `on_demand.dart`, `tariff.dart`, `energy_grouping.dart`,
/// `wire_routing.dart`, `two_wire.dart`, `criticality.dart`,
/// `calibration.dart` and `fertigation.dart`, for the dialogs of the
/// application. Everything here reads the project and its results; the
/// changes a tool proposes (start hours, system flows, wire routes, the C
/// scale) come back as values for the caller to apply as one undo step.
library;

import 'dart:math' as math;

import '../hydraulics/network.dart';
import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../units.dart';
import 'agronomy.dart';
import 'calibration.dart';
import 'criticality.dart';
import 'designer.dart';
import 'energy_grouping.dart';
import 'fertigation.dart';
import 'management.dart';
import 'network_builder.dart';
import 'on_demand.dart';
import 'results.dart';
import 'tariff.dart';
import 'valve_in_head.dart';
import 'wire_routing.dart';

// ---------------------------------------------------------------- common

/// A designer for the analyses of a designed project. The zone and pivot
/// results of [results] stand for the demands, so the mainline of any set of
/// valves is built without analysing the zones again (a zone analysis is a
/// network solution per zone, many for a detailed one). [label] translates
/// the names the designer gives (the "all zones" flow of a project without
/// system flows).
Designer opsDesigner(Project p, DesignResults results, {String Function(String key)? label}) {
  final d = Designer(p, label: label);
  d.results.zones.addAll(results.zones);
  d.results.pivots.addAll(results.pivots);
  return d;
}

/// Flow (m³/s) and pressure head needed at the mainline node (m) of a zone
/// valve or pivot, from the design; null when the design has no result for
/// it.
(double, double)? demandDuty(DesignResults r, String id) {
  final z = r.zones[id];
  if (z != null) return (z.totalFlow, z.requiredUpstreamHead);
  final pv = r.pivots[id];
  if (pv != null) return (pv.flow, pv.inletHead);
  return null;
}

/// Zone valves and pivots fed by the mainline, in drawing order.
List<String> mainlineDemands(Designer d) => [
  for (final id in demandIds(d.project))
    if (d.demandNodeOf(id) case final n? when d.model.mainlineNodes.contains(n)) id,
];

/// The demands (zone valves and pivots) at every mainline node.
Map<String, List<String>> demandsByNode(Designer d, [Iterable<String>? ids]) {
  final out = <String, List<String>>{};
  for (final id in ids ?? mainlineDemands(d)) {
    final n = d.demandNodeOf(id);
    if (n != null) out.putIfAbsent(n, () => []).add(id);
  }
  return out;
}

/// The model links by id (the model keeps them in a list).
Map<String, GLink> modelLinks(Designer d) => {for (final l in d.model.links) l.id: l};

/// Entity a link of a designer network comes from (the link id itself for a
/// link without a model link).
String linkEntity(HLink l) => l.tag is GLink ? (l.tag as GLink).entityId : l.id;

/// Pressure head (m) every supply of the mainline runs at in the design: the
/// highest over its system flows (a calculated supply at the head its worst
/// flow needs), else its design head.
Map<String, double> designSupplyPressure(Designer d, DesignResults r) {
  final out = <String, double>{};
  for (final s in d.project.entities.whereType<WaterSupplyEntity>()) {
    final n = d.model.supplyNodes[s.id];
    if (n == null || !d.model.mainlineNodes.contains(n)) continue;
    double? best;
    for (final f in r.systemFlows) {
      for (final duty in f.supplies) {
        if (duty.supplyId == s.id) best = math.max(best ?? -double.infinity, duty.head);
      }
    }
    out[s.id] = best ?? (s.calculatePressure ? 0 : s.designHeadM);
  }
  return out;
}

/// Sets every supply node of [net] (a designer mainline) to the pressure of
/// [pressure] (m, by supply entity id): its fixed head becomes its level plus
/// that pressure.
void setSupplyPressures(Designer d, HydraulicNetwork net, Map<String, double> pressure) {
  for (final e in pressure.entries) {
    final n = net.nodes[d.model.supplyNodes[e.key] ?? ''];
    if (n != null && n.kind == HNodeKind.reservoir) n.fixedHead = n.elevation + e.value;
  }
}

// ---------------------------------------------------------------- on demand

/// Hours per day every demand runs in the peak period: the mean daily run
/// time of the areas a zone waters (crop water requirement: hours per event
/// over the interval), else the hours of the system flows that open it (each
/// flow running once a day), at most 24; demands neither tells about are left
/// out.
Map<String, double> demandHoursPerDay(Project p, DesignResults r) {
  final crops = {for (final c in cropWaterRequirements(p, r)) c.areaId: c};
  final out = <String, double>{};
  for (final id in demandIds(p)) {
    var h = 0.0;
    if (r.zones.containsKey(id)) {
      for (final a in areasOfZone(p, r, id)) {
        final cw = crops[a.id];
        if (cw != null && cw.dailyHours > 0) h = math.max(h, cw.dailyHours);
      }
    }
    if (h <= 0) {
      for (final f in p.systemFlows) {
        if (f.valveIds.contains(id)) h += math.max(0.0, f.durationHours);
      }
    }
    if (h > 0) out[id] = math.min(h, 24.0);
  }
  return out;
}

/// The mainline of a design as an on-demand network: every zone valve and
/// pivot a hydrant at its mainline node.
class OnDemandModel {
  OnDemandModel({required this.designer, required this.network, required this.hydrants, required this.designFlows, required this.supplyPressure});
  final Designer designer;

  /// The mainline (every demand open, as the designer builds it) with no
  /// demand left at the hydrant nodes: the draws of the random check open
  /// the hydrants; mainline outlets stay as they are.
  final HydraulicNetwork network;

  /// One hydrant per zone valve or pivot with a design result (id = its
  /// entity id): its design flow, the pressure head it needs at its mainline
  /// node and its hours per day ([demandHoursPerDay], else the default).
  final List<Hydrant> hydrants;

  /// Largest |flow| of every mainline link over the system flows of the
  /// design (m³/s): what the pipes were sized for.
  final Map<String, double> designFlows;

  /// Pressure (m) of every supply in the design ([designSupplyPressure]).
  final Map<String, double> supplyPressure;
}

/// The on-demand model of a designed project; null without a water supply
/// or without demands on the mainline.
OnDemandModel? onDemandModel(Project p, DesignResults r, {double defaultHours = 8, String Function(String key)? label}) {
  final d = opsDesigner(p, r, label: label);
  final ids = mainlineDemands(d);
  if (ids.isEmpty) return null;
  // the valve-in-head stations stay on, as mainline outlets always were here
  final built = d.mainlineNetworkFor(SystemFlow(id: 'onDemand', name: '', valveIds: {...ids, ...d.vih.heads.keys}));
  if (built == null) return null;
  final net = copyNetwork(built.$1);
  final hours = demandHoursPerDay(p, r);
  final hydrants = <Hydrant>[];
  for (final id in ids) {
    final node = d.demandNodeOf(id)!;
    net.nodes[node]?.demand = 0;
    final duty = demandDuty(r, id);
    if (duty == null || !(duty.$1 > 0) || !net.nodes.containsKey(node)) continue;
    hydrants.add(Hydrant(id: id, nodeId: node, discharge: duty.$1, minPressure: duty.$2, hoursPerDay: hours[id] ?? defaultHours));
  }
  final design = <String, double>{};
  for (final f in r.systemFlows) {
    for (final pp in f.pipes) {
      design[pp.linkId] = math.max(design[pp.linkId] ?? 0, pp.flow.abs());
    }
  }
  return OnDemandModel(designer: d, network: net, hydrants: hydrants, designFlows: design, supplyPressure: designSupplyPressure(d, r));
}

/// A copy of the on-demand network with the supplies at [pressure] (m, by
/// supply id; the design pressure for those left out), for the random check.
HydraulicNetwork onDemandCheckNetwork(OnDemandModel m, Map<String, double> pressure) {
  final net = copyNetwork(m.network);
  setSupplyPressures(m.designer, net, {...m.supplyPressure, ...pressure});
  return net;
}

/// One mainline pipe under on-demand operation: the segment with the largest
/// Clément flow, against the flow the design sized it for.
class OnDemandPipeRow {
  const OnDemandPipeRow({required this.entityId, required this.linkId, required this.hydrants, required this.flow, required this.designFlow, required this.diameter, required this.rule});
  final String entityId;
  final String linkId;

  /// Hydrants downstream of the segment.
  final int hydrants;

  /// Clément design flow and the largest flow of the system flows of the
  /// design in the same segment (m³/s).
  final double flow;
  final double designFlow;

  /// Inner diameter (m).
  final double diameter;
  final ClementRule rule;

  /// Velocity at the Clément flow (m/s).
  double get velocity => diameter > 0 ? flow / (math.pi * diameter * diameter / 4) : 0;

  /// Clément flow over the design flow (infinite when the design never
  /// carried water there).
  double get ratio => designFlow > 0 ? flow / designFlow : (flow > 0 ? double.infinity : 1);
}

/// The pipes of [m] with the flows of [c], one row per pipe entity, the
/// trunk (largest Clément flow) first.
List<OnDemandPipeRow> onDemandPipeRows(OnDemandModel m, ClementResult c) {
  final links = {for (final l in m.network.links) l.id: l};
  final best = <String, OnDemandPipeRow>{};
  for (final f in c.flows.values) {
    final l = links[f.linkId];
    if (l == null || l.kind != HLinkKind.pipe) continue;
    final entity = linkEntity(l);
    final cur = best[entity];
    if (cur != null && cur.flow >= f.flow) continue;
    best[entity] = OnDemandPipeRow(entityId: entity, linkId: l.id, hydrants: f.hydrants, flow: f.flow, designFlow: m.designFlows[l.id] ?? 0, diameter: l.diameter, rule: f.rule);
  }
  return best.values.toList()..sort((a, b) => b.flow != a.flow ? b.flow.compareTo(a.flow) : a.entityId.compareTo(b.entityId));
}

/// Pressure (m above the supply level) a source must hold for the Clément
/// flows, by supply entity id ([ClementResult.sourceRequiredHead] is a
/// piezometric head).
Map<String, double> clementSupplyPressure(OnDemandModel m, ClementResult c) {
  final out = <String, double>{};
  for (final s in m.supplyPressure.keys) {
    final node = m.designer.model.supplyNodes[s];
    final h = c.sourceRequiredHead[node];
    final n = m.network.nodes[node];
    if (h != null && n != null) out[s] = h - n.elevation;
  }
  return out;
}

// ---------------------------------------------------------------- tariff

/// Sets the start hour of every system flow of [p] that [s] schedules (the
/// jobs carry the flow ids, see [tariffJobsFromDesign]); returns how many
/// changed.
int applyTariffSchedule(Project p, TariffSchedule s) {
  var n = 0;
  for (final j in s.jobs) {
    for (final f in p.systemFlows) {
      if (f.id != j.id) continue;
      final h = j.startMinute / 60;
      if ((f.startHour - h).abs() > 1e-9) {
        f.startHour = h;
        n++;
      }
    }
  }
  return n;
}

/// Clock text of a minute of the day ("21:30").
String clockOf(num minute) {
  final m = (minute.round() % 1440 + 1440) % 1440;
  return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------- energy grouping

/// Zones of a design for the energy grouping: those of
/// [energyZonesFromDesign] plus the pivots, at the elevation of their
/// mainline node (the pivot results do not carry it), with their inlet head
/// and the loss from the supply estimated from the analyses the same way.
(List<EnergyZone>, double) energyZonesWithPivots(Designer d, DesignResults r, {double lossExponent = 1.852}) {
  final p = d.project;
  final (zones, source) = energyZonesFromDesign(p, r, lossExponent: lossExponent);
  final hours = <String, double>{};
  for (final f in p.systemFlows) {
    for (final v in f.valveIds) {
      hours[v] = math.max(hours[v] ?? 0, f.durationHours);
    }
  }
  final out = [...zones];
  for (final pv in r.pivots.values) {
    final node = d.demandNodeOf(pv.pivotId);
    if (node == null || !(pv.flow > 0)) continue;
    final z = d.model.nodes[node]?.elevation ?? 0;
    var k = 0.0;
    for (final f in r.systemFlows) {
      if (f.supplies.isEmpty || f.totalFlow <= 0) continue;
      final s = f.supplies.first;
      final top = s.elevation + s.head + f.devices.fold(0.0, (a, dv) => a + math.max(0.0, dv.pumpHead));
      for (final v in f.valves) {
        if (v.valveId == pv.pivotId) k = math.max(k, math.max(0.0, top - (z + v.availableHead)) / math.pow(f.totalFlow, lossExponent));
      }
    }
    out.add(EnergyZone(id: pv.pivotId, flow: pv.flow, requiredHead: pv.inletHead, elevation: z, hours: hours[pv.pivotId] ?? 1, lossCoefficient: k));
  }
  return (out, source);
}

/// Pumping head (m) of a set of demands by the designer: the mainline solved
/// for those valves alone, as the design analyses a system flow (a
/// calculated supply at the pressure its worst valve needs), the highest
/// calculated-supply pressure plus the heads the mainline pumps add. A supply
/// at a fixed pressure (the mains) costs the system no energy.
double designerGroupHead(Designer d, Iterable<String> ids) {
  final built = d.mainlineNetworkFor(SystemFlow(id: 'group', name: '', valveIds: ids.toSet()));
  if (built == null) return 0;
  final (net, res, _) = built;
  final calculated = {
    for (final s in d.project.entities.whereType<WaterSupplyEntity>())
      if (s.calculatePressure) ?d.model.supplyNodes[s.id],
  };
  var h = 0.0;
  for (final n in net.nodes.values) {
    if (n.kind == HNodeKind.reservoir && calculated.contains(n.id)) h = math.max(h, (n.fixedHead ?? n.elevation) - n.elevation);
  }
  for (final l in net.links) {
    if (l.kind == HLinkKind.pump) h += math.max(0.0, res.links[l.id]?.pumpHead ?? 0);
  }
  return h;
}

/// Head (m) a group needs by the formula of `energy_grouping.dart`: the
/// highest piezometric need of its zones plus the loss at the group flow,
/// above the source level.
double formulaGroupHead(List<EnergyZone> group, double sourceElevation, {double lossExponent = 1.852}) {
  final q = group.fold(0.0, (s, z) => s + z.flow);
  var h = -double.infinity;
  for (final z in group) {
    h = math.max(h, z.piezometric + (z.lossCoefficient > 0 ? z.lossCoefficient * math.pow(q, lossExponent) : 0));
  }
  return group.isEmpty ? 0 : math.max(0.0, h - sourceElevation);
}

/// Pumping energy (kWh per round of irrigation) of the valve sets [groups]
/// with the zones of [zones], each group at the [head] of its zones, as
/// `energy_grouping.dart` counts it (ρ·g·H·Σ q·t / η): for comparing the
/// system flows of a project with a proposal.
double groupingEnergyKwh(Iterable<Set<String>> groups, List<EnergyZone> zones, double Function(List<EnergyZone> group) head, {double efficiency = 0.65}) {
  final byId = {for (final z in zones) z.id: z};
  var e = 0.0;
  for (final g in groups) {
    final members = [for (final id in g) ?byId[id]];
    if (members.isEmpty) continue;
    final volume = members.fold(0.0, (s, z) => s + z.flow * z.hours * 3600);
    e += waterDensity * gravity * head(members) * volume / math.max(efficiency, 0.05) / 3.6e6;
  }
  return e;
}

// ---------------------------------------------------------------- wire routing

/// Master valves of [p] for the routing: the master-valve devices of the
/// catalogue, which the electrical design drives from the controller's
/// master-valve output, and the control-kind devices on the mainline, which
/// [autoRouteWires] takes for master valves.
Map<String, Pt> masterValvesOf(Project p) => {
  for (final m in p.entities.whereType<MiscHydraulicEntity>())
    if (p.catalog.valve(m.valveSpecId)?.kind case final k? when k == ValveKind.master || (k == ValveKind.control && m.scope == HydraulicScope.mainline)) m.id: m.position,
};

/// Wire routes of [p] along its pipes ([routeWires]), as [autoRouteWires]
/// with the master valves of [masterValvesOf].
WireRoutingResult routeProjectWires(Project p, {WireRoutingOptions options = const WireRoutingOptions()}) {
  final controllers = {for (final c in p.entities.whereType<ControllerEntity>()) c.id: c.position};
  final valves = {for (final v in p.entities.whereType<ControlValveEntity>()) v.id: v.position};
  final relays = {for (final pu in p.entities.whereType<PumpEntity>()) pu.id: pu.position};
  final pipes = [
    for (final e in p.entities.whereType<PipeEntity>())
      if (e.points.length >= 2 && (e.scope == HydraulicScope.mainline || options.includeZonePipes)) e.points,
  ];
  final r = routeWires(controllers: controllers, valves: valves, pipes: pipes, masterValves: masterValvesOf(p), pumpRelays: relays, valveInHead: valveInHeadOf(p), options: options);
  for (final c in p.entities.whereType<ControllerEntity>()) {
    final used = r.stations.where((s) => s.controllerId == c.id && s.station > 0).length;
    if (used > c.stations) r.warnings.add('wire_route_stations:${c.id}');
  }
  return r;
}

/// One wire route entity per route of [r] (new ids from [p]: call it inside
/// the undo step that adds them).
List<WireEntity> wireEntitiesOf(Project p, WireRoutingResult r) => [
  for (final w in r.routes)
    if (w.points.length >= 2) WireEntity(id: p.newId(), points: [...w.points]),
];

/// Valve sets that run together for the electrical designs: the system
/// flows with the valve-in-head stations they run, or every valve and
/// station at once without any (as the hydraulic design).
List<Set<String>> wiringFlows(Project p) {
  final vih = VihStations.of(p);
  return p.systemFlows.isNotEmpty
      ? [for (final f in p.systemFlows) vih.isEmpty ? f.valveIds : {...f.valveIds, ...vih.runningIn(f.valveIds)}]
      : [
          {for (final v in p.entities.whereType<ControlValveEntity>()) v.id, ...vih.heads.keys},
        ];
}

// ---------------------------------------------------------------- criticality

/// A link whose failure leaves demands short.
class CriticalityRow {
  CriticalityRow({required this.scenario, required this.entityId, required this.cutOff, required this.short});
  final CriticalityScenario scenario;

  /// Pipe entity of the link.
  final String entityId;

  /// Demands (zone valves, pivots) cut off from every supply.
  final List<String> cutOff;

  /// Demands still connected but below the pressure they need, with the
  /// deficit of their node.
  final List<(String, NodeDeficit)> short;
}

/// Outcome of [criticalityOf].
class CriticalityView {
  CriticalityView({required this.result, required this.rows, required this.demandsAt});
  final CriticalityResult result;

  /// Links whose failure loses demand or pressure, from the worst.
  final List<CriticalityRow> rows;

  /// The demands at every mainline node of the flow.
  final Map<String, List<String>> demandsAt;
}

/// Pipe-by-pipe failure analysis of the mainline of system flow [sf]
/// ([analyzeCriticality]): every pipe closed in turn, every valve or pivot
/// of the flow needing the pressure head of its design at its node. Null
/// without a water supply.
CriticalityView? criticalityOf(Designer d, DesignResults r, SystemFlow sf, {bool pressureDriven = true}) {
  final built = d.mainlineNetworkFor(sf);
  if (built == null) return null;
  final at = <String, List<String>>{};
  final required = <String, double>{};
  for (final id in sf.valveIds) {
    final node = d.demandNodeOf(id);
    final duty = demandDuty(r, id);
    if (node == null || duty == null) continue;
    at.putIfAbsent(node, () => []).add(id);
    required[node] = math.max(required[node] ?? 0, duty.$2);
  }
  final net = built.$1;
  final res = analyzeCriticality(net, requiredPressure: required, pressureDriven: pressureDriven);
  final links = {for (final l in net.links) l.id: l};
  final rows = <CriticalityRow>[];
  for (final s in res.ranked) {
    if (s.lostDemand <= 1e-9 && s.deficits.isEmpty) continue;
    final l = links[s.linkId];
    rows.add(
      CriticalityRow(
        scenario: s,
        entityId: l == null ? s.linkId : linkEntity(l),
        cutOff: [for (final n in s.cutOffNodes) ...?at[n]],
        short: [
          for (final def in s.deficits)
            for (final id in at[def.nodeId] ?? const <String>[]) (id, def),
        ],
      ),
    );
  }
  return CriticalityView(result: res, rows: rows, demandsAt: at);
}

// ---------------------------------------------------------------- calibration

/// What a measuring point of the mainline is.
enum MeasurePointKind { valve, supply, junction, device }

/// A point of the mainline where a pressure can be read: a zone valve or
/// pivot (its mainline node), a supply, a junction or a device (its upstream
/// side).
class MeasurePoint {
  const MeasurePoint({required this.entityId, required this.kind, required this.nodeId});
  final String entityId;
  final MeasurePointKind kind;
  final String nodeId;
}

/// Every measuring point of the mainline of [d].
List<MeasurePoint> measurePoints(Designer d) {
  final p = d.project;
  final main = d.model.mainlineNodes;
  final out = <MeasurePoint>[
    for (final id in mainlineDemands(d)) MeasurePoint(entityId: id, kind: MeasurePointKind.valve, nodeId: d.demandNodeOf(id)!),
    for (final s in p.entities.whereType<WaterSupplyEntity>())
      if (d.model.supplyNodes[s.id] case final n? when main.contains(n)) MeasurePoint(entityId: s.id, kind: MeasurePointKind.supply, nodeId: n),
  ];
  for (final n in d.model.nodes.values) {
    if (!main.contains(n.id)) continue;
    for (final e in n.entityIds) {
      if (p.byId(e) is JunctionEntity) out.add(MeasurePoint(entityId: e, kind: MeasurePointKind.junction, nodeId: n.id));
    }
  }
  final links = modelLinks(d);
  for (final lid in d.model.mainlineLinks) {
    final l = links[lid];
    if (l == null || l.kind == GLinkKind.pipe || l.kind == GLinkKind.pump || l.kind == GLinkKind.controlValve) continue;
    if (p.byId(l.entityId) is MiscHydraulicEntity) out.add(MeasurePoint(entityId: l.entityId, kind: MeasurePointKind.device, nodeId: l.from));
  }
  return out;
}

/// A field reading at an entity: a pressure head (m) at a measuring point or
/// a flow (m³/s) leaving a supply, with its standard error (m or m³/s; 0 =
/// the default of [calibrateRoughness]).
class FieldReading {
  const FieldReading({required this.entityId, required this.value, this.sigma = 0});
  final String entityId;
  final double value;
  final double sigma;
}

/// Outcome of [calibrateFromField].
class FieldCalibration {
  FieldCalibration({required this.result, required this.network, required this.entityOf, required this.boundary});
  final CalibrationResult result;

  /// The network calibrated (the supplies read set to their readings).
  final HydraulicNetwork network;

  /// Entity of every residual id (node or link id).
  final Map<String, String> entityOf;

  /// Supplies whose pressure reading set the head the network receives.
  final List<String> boundary;
}

/// Fits one Hazen-Williams C factor of the mainline of system flow [sf] to
/// field readings ([calibrateRoughness]). A pressure read at a supply is the
/// head the network receives (the supply is a fixed head in the model, so a
/// reading there is a boundary condition, not a residual); pressures
/// elsewhere and the flows leaving the supplies are fitted. Null without a
/// water supply.
FieldCalibration? calibrateFromField(
  Designer d,
  SystemFlow sf, {
  List<FieldReading> pressures = const [],
  List<FieldReading> flows = const [],
  CalibrationOptions options = const CalibrationOptions(),
}) {
  final built = d.mainlineNetworkFor(sf);
  if (built == null) return null;
  final (net0, res0, _) = built;
  final net = copyNetwork(net0);
  final points = {for (final m in measurePoints(d)) m.entityId: m};
  final supplies = {for (final s in d.project.entities.whereType<WaterSupplyEntity>()) s.id};
  final boundary = <String>[];
  final pm = <PressureMeasurement>[];
  final entityOf = <String, String>{};
  for (final rd in pressures) {
    if (supplies.contains(rd.entityId)) {
      setSupplyPressures(d, net, {rd.entityId: rd.value});
      boundary.add(rd.entityId);
      continue;
    }
    final pt = points[rd.entityId];
    final node = pt?.nodeId ?? rd.entityId;
    pm.add(PressureMeasurement(nodeId: node, pressure: rd.value, sigma: rd.sigma > 0 ? rd.sigma : 0.5));
    entityOf[node] = rd.entityId;
  }
  final fm = <FlowMeasurement>[];
  for (final rd in flows) {
    final node = d.model.supplyNodes[rd.entityId];
    // the link that leaves the supply carrying the most water (one as a rule)
    HLink? out;
    for (final l in net.links) {
      if (l.from != node && l.to != node) continue;
      if (out == null || (res0.links[l.id]?.flow.abs() ?? 0) > (res0.links[out.id]?.flow.abs() ?? 0)) out = l;
    }
    if (node == null || out == null) {
      fm.add(FlowMeasurement(linkId: 'supply:${rd.entityId}', flow: rd.value, sigma: rd.sigma));
      continue;
    }
    fm.add(FlowMeasurement(linkId: out.id, flow: out.from == node ? rd.value : -rd.value, sigma: rd.sigma));
    entityOf[out.id] = rd.entityId;
  }
  final r = calibrateRoughness(net, pressures: pm, flows: fm, options: options);
  return FieldCalibration(result: r, network: net, entityOf: entityOf, boundary: boundary);
}

/// The Hazen-Williams C scale and offset that multiply every C of the
/// design by [factor]: the design uses C·scale + offset, so both scale.
(double, double) calibratedC(DesignParameters p, double factor) => (p.hazenCScale * factor, p.hazenCOffset * factor);

// ---------------------------------------------------------------- fertigation

/// Arrival of the product at a demand of the flow.
class FertigationZoneTime {
  const FertigationZoneTime({required this.demandId, required this.valveFirst, required this.valveFull, this.emitterFirst, this.emitterFull});
  final String demandId;

  /// At the valve's mainline node (s after the injection starts): the product
  /// first appears and the full concentration arrives.
  final double valveFirst;
  final double valveFull;

  /// At the farthest emitter of the zone (null for a pivot or a zone without
  /// detailed results); for a valve-in-head station at its farthest head,
  /// its nearest head standing for the valve.
  final double? emitterFirst;
  final double? emitterFull;
}

/// Travel times of a fertigation during one system flow.
class FertigationSetup {
  FertigationSetup({required this.network, required this.result, required this.injectionNode, required this.mainline, required this.zones, required this.flow, required this.areaM2});

  /// The mainline of the flow and its steady solution.
  final HydraulicNetwork network;
  final NetworkResult result;
  final String injectionNode;
  final FertigationTravel mainline;
  final List<FertigationZoneTime> zones;

  /// Flow through the injection point (m³/s) and the area its zones water
  /// (m²).
  final double flow;
  final double areaM2;

  /// The arrival at the farthest outlet (an emitter, else a valve) and the
  /// full concentration there (s): what the flushing must cover.
  double get farthestArrival => zones.fold(0.0, (m, z) => math.max(m, z.emitterFirst ?? z.valveFirst));
  double get fullArrival => zones.fold(0.0, (m, z) => math.max(m, z.emitterFull ?? z.valveFull));

  /// The travel of the whole system, mainline and zones together, for
  /// [planFertigation].
  FertigationTravel get combined => FertigationTravel(
    injectionNode: injectionNode,
    nodes: {for (final z in zones) z.demandId: TravelTime(nodeId: z.demandId, earliest: z.emitterFirst ?? z.valveFirst, latest: z.emitterFull ?? z.valveFull)},
    outlets: [for (final z in zones) z.demandId],
    unreached: mainline.unreached,
    volume: mainline.volume,
    codes: mainline.codes,
  );
}

/// Injection points of [d]: the supplies and the pumps of the mainline.
List<String> injectionPoints(Designer d) => [
  for (final s in d.project.entities.whereType<WaterSupplyEntity>())
    if (d.model.supplyNodes[s.id] case final n? when d.model.mainlineNodes.contains(n)) s.id,
  for (final pu in d.project.entities.whereType<PumpEntity>())
    if (d.model.mainlineLinks.contains('pump_${pu.id}')) pu.id,
];

/// Area (m²) the demands [ids] water: the irrigated areas of their zones and
/// valve-in-head stations (each counted once), else the outline of a zone's
/// emitters or a station's heads, and the area of the pivots.
double demandsAreaM2(Project p, DesignResults r, Iterable<String> ids) {
  final areas = <String, double>{};
  var other = 0.0;
  final vih = VihStations.of(p);
  final at = vih.isEmpty ? const <String, Pt>{} : {for (final e in p.entities) if (e is OutletEntity && vih.stationOf.containsKey(e.id)) e.id: e.position};
  for (final id in ids) {
    final pv = r.pivots[id];
    if (pv != null) {
      other += pv.areaM2;
      continue;
    }
    if (vih.isStation(id)) {
      final of = areasOfStation(p, id, stations: vih);
      final heads = vih.heads[id]!;
      if (of.isNotEmpty) {
        for (final a in of) {
          areas[a.id] = a.area;
        }
      } else if (heads.length >= 3) {
        other += polygonArea(convexHull([for (final h in heads) at[h]!])).abs();
      }
      continue;
    }
    final z = r.zones[id];
    if (z == null) continue;
    final of = areasOfZone(p, r, id);
    if (of.isNotEmpty) {
      for (final a in of) {
        areas[a.id] = a.area;
      }
    } else if (z.outlets.length >= 3) {
      other += polygonArea(convexHull([for (final o in z.outlets) o.p])).abs();
    }
  }
  return areas.values.fold(other, (s, a) => s + a);
}

/// Travel of the product inside the zone of [z] from its valve, plug flow
/// along the flows of the zone results; null without detailed results.
FertigationTravel? zoneTravel(Designer d, ZoneResult z, Map<String, GLink> links) {
  final nodes = d.model.valveNodes[z.valveId];
  if (nodes == null || z.pipes.isEmpty) return null;
  final net = HydraulicNetwork();
  final flows = <String, LinkResult>{};
  void node(String id) {
    if (!net.nodes.containsKey(id)) net.addNode(HNode(id: id));
  }

  for (final pp in z.pipes) {
    final l = links[pp.linkId];
    if (l == null) continue;
    node(l.from);
    node(l.to);
    net.addLink(HLink(id: pp.linkId, from: l.from, to: l.to, diameter: pp.diameter, length: pp.length));
    flows[pp.linkId] = LinkResult(flow: pp.flow, velocity: pp.velocity, headLoss: pp.headLoss, status: LinkStatus.open);
  }
  for (final dv in z.devices) {
    final l = links[dv.linkId];
    if (l == null) continue;
    node(l.from);
    node(l.to);
    net.addLink(HLink(id: dv.linkId, from: l.from, to: l.to, kind: HLinkKind.device));
    flows[dv.linkId] = LinkResult(flow: dv.flow, velocity: 0, headLoss: dv.headLoss, status: LinkStatus.open);
  }
  final outlets = [
    for (final id in d.model.zoneNodes[z.valveId] ?? const <String>{})
      if (net.nodes.containsKey(id) && (d.model.nodes[id]?.emitters.isNotEmpty ?? false)) id,
  ];
  final res = NetworkResult(converged: true, iterations: 0, nodes: const {}, links: flows, warnings: const [], relativeFlowError: 0);
  return fertigationTravel(net, res, nodes.$2, outlets: outlets);
}

/// Travel times of a product injected at [injectionId] (a supply or a
/// mainline pump: its outlet) while system flow [sf] runs: along the mainline
/// to every valve and pivot of the flow, then inside every zone to its
/// farthest emitter, and to the heads of the valve-in-head stations that run
/// in the flow (`valve_in_head.dart`; a station at its nearest head as its
/// "valve" and its farthest one as its farthest emitter). Null without a
/// water supply or an injection point on the mainline.
FertigationSetup? fertigationSetup(Designer d, DesignResults r, SystemFlow sf, String injectionId) {
  final built = d.mainlineNetworkFor(sf);
  if (built == null) return null;
  final (net, res, _) = built;
  final e = d.project.byId(injectionId);
  String? node;
  var flow = 0.0;
  if (e is WaterSupplyEntity) {
    node = d.model.supplyNodes[e.id];
    for (final l in net.links) {
      final q = res.links[l.id]?.flow ?? 0;
      if (l.from == node) flow += q;
      if (l.to == node) flow -= q;
    }
  } else if (e is PumpEntity) {
    final l = net.links.where((l) => l.id == 'pump_${e.id}').firstOrNull;
    node = l?.to;
    flow = res.links[l?.id ?? '']?.flow ?? 0;
  }
  if (node == null || !net.nodes.containsKey(node)) return null;
  final at = demandsByNode(d, sf.valveIds);
  final stations = d.vih.runningIn(sf.valveIds);
  final headNode = d.vihHeadNodes;
  final heads = {
    for (final s in stations)
      for (final h in d.vih.heads[s]!) ?headNode[h],
  };
  final travel = fertigationTravel(net, res, node, outlets: {...at.keys, ...heads});
  final links = modelLinks(d);
  final zones = <FertigationZoneTime>[];
  for (final s in stations) {
    final times = [for (final h in d.vih.heads[s]!) ?travel.nodes[headNode[h] ?? '']];
    if (times.isEmpty) continue;
    final near = times.reduce((a, b) => b.earliest < a.earliest ? b : a);
    zones.add(FertigationZoneTime(demandId: s, valveFirst: near.earliest, valveFull: near.latest, emitterFirst: times.map((t) => t.earliest).reduce(math.max), emitterFull: times.map((t) => t.latest).reduce(math.max)));
  }
  for (final id in sf.valveIds) {
    final n = d.demandNodeOf(id);
    final tv = travel.nodes[n ?? ''];
    if (n == null || tv == null) continue;
    final z = r.zones[id];
    final inside = z == null ? null : zoneTravel(d, z, links);
    final far = inside?.farthestOutlet;
    zones.add(
      FertigationZoneTime(
        demandId: id,
        valveFirst: tv.earliest,
        valveFull: tv.latest,
        emitterFirst: far == null ? null : tv.earliest + inside!.farthestArrival,
        emitterFull: far == null ? null : tv.latest + inside!.fullArrival,
      ),
    );
  }
  final order = demandIds(d.project);
  zones.sort((a, b) => order.indexOf(a.demandId).compareTo(order.indexOf(b.demandId)));
  return FertigationSetup(network: net, result: res, injectionNode: node, mainline: travel, zones: zones, flow: math.max(0.0, flow), areaM2: demandsAreaM2(d.project, r, {...sf.valveIds, ...stations}));
}

/// A device of the mainline a venturi injector can bypass, with its head
/// loss and the pressure upstream of it in the flow.
class VenturiSite {
  const VenturiSite({required this.entityId, required this.linkId, required this.headLoss, required this.inletPressure});
  final String entityId;
  final String linkId;
  final double headLoss;
  final double inletPressure;
}

/// The devices (filters, valves, meters, regulators) of the mainline of
/// [s] that carry water, with their losses.
List<VenturiSite> venturiSites(FertigationSetup s) => [
  for (final l in s.network.links)
    if (l.kind == HLinkKind.device || l.kind == HLinkKind.prv || l.kind == HLinkKind.psv || l.kind == HLinkKind.fcv)
      if (s.result.links[l.id] case final lr? when lr.flow.abs() > 1e-9)
        VenturiSite(entityId: linkEntity(l), linkId: l.id, headLoss: lr.headLoss.abs(), inletPressure: s.result.nodes[lr.flow >= 0 ? l.from : l.to]?.pressure ?? 0),
];
