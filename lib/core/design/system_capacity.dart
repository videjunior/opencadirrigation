/// Capacity of the irrigation system against the peak demand of the crops:
/// can the system put on every area its gross requirement of the month of
/// largest demand (the design month of the FAO-56 requirement table, or
/// the ETo and Kc typed on the area; area_water.dart) within the hours a
/// day it may run — the irrigation window of the controller programme
/// (24 h when none is set)?
///
/// - System flows run one after another: a flow runs as long as the area
///   of its zones that needs the most hours (the gross daily volume of the
///   area over the flow of the emitters that water it), and the day must
///   hold all the flows. Without system flows every zone runs at once.
/// - A centre pivot or linear move applies its depth per cycle in the
///   hours of a cycle: its capacity in the window, d·W/T (mm/day), must
///   reach the peak gross requirement of the area under it.
///
/// The flows are the nominal ones of the emitters (no design needed), or
/// those of [DesignResults] when given.
library;

import 'dart:math' as math;

import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import 'agronomy.dart' show areasOfMachine, areasOfStation;
import 'area_water.dart';
import 'designer.dart' show areaRequirements;
import 'network_builder.dart';
import 'results.dart';
import 'valve_in_head.dart';

/// Hours one system flow needs on the peak day.
class FlowCapacity {
  const FlowCapacity({required this.flowId, required this.name, required this.hours, this.areaId});
  final String flowId;
  final String name;
  final double hours;

  /// The area that needs the most hours.
  final String? areaId;
}

/// A machine against the peak requirement of its area.
class MachineCapacity {
  const MachineCapacity({required this.pivotId, required this.name, required this.capacityMmDay, required this.peakGrossMmDay, required this.hoursNeeded, this.areaId});
  final String pivotId;
  final String name;

  /// Depth the machine applies a day running the whole window (mm/day).
  final double capacityMmDay;

  /// Peak gross requirement of the area under it (mm/day), and the hours a
  /// day the machine must run for it.
  final double peakGrossMmDay;
  final double hoursNeeded;
  final String? areaId;
  bool get short => capacityMmDay < peakGrossMmDay * (1 - 1e-6);
}

/// The capacity check of a project.
class SystemCapacity {
  const SystemCapacity({required this.windowHours, required this.flows, required this.machines});

  /// Hours a day the system may run.
  final double windowHours;
  final List<FlowCapacity> flows;
  final List<MachineCapacity> machines;

  /// Hours of the peak day: every flow one after another.
  double get totalHours => flows.fold(0.0, (s, f) => s + f.hours);
  bool get flowsFit => totalHours <= windowHours * (1 + 1e-6);
  bool get ok => flowsFit && machines.every((m) => !m.short);
}

/// Areas that hold at least a fifth of the emitters of zone [valveId] of
/// [model], by their nominal positions (heads on an area's outline count
/// when their arc opens into it), as `areasOfZone` does with results.
List<AreaEntity> areasOfZoneNominal(Project p, NetworkModel model, String valveId) {
  final nodes = model.zoneNodes[valveId];
  if (nodes == null || nodes.isEmpty) return const [];
  final emitters = <(GNode, EmitterRef)>[
    for (final id in nodes)
      if (model.nodes[id] case final n?)
        for (final e in n.emitters) (n, e),
  ];
  final total = emitters.fold(0, (s, x) => s + x.$2.count);
  if (total == 0) return const [];
  final heads = {
    for (final e in p.entities)
      if (e is OutletEntity) e.id: e,
  };
  final out = <AreaEntity>[];
  for (final a in p.entities.whereType<AreaEntity>()) {
    if (a.points.length < 3) continue;
    var inside = 0;
    for (final (node, e) in emitters) {
      final head = heads[e.entityId];
      if (head != null ? p.outletWatersArea(head, a.points) : pointInPolygon(node.p, a.points)) inside += e.count;
    }
    if (inside * 5 >= total) out.add(a);
  }
  return out;
}

/// The capacity check of [p] (see the library notes).
SystemCapacity systemCapacity(Project p, {DesignResults? results}) {
  final window = p.agronomy.programme.effectiveWindowHours;
  final reqs = {for (final r in areaRequirements(p, results)) r.areaId: r};
  final machines = <MachineCapacity>[];
  final machineHours = <String, double>{};
  for (final m in p.entities.whereType<PivotEntity>()) {
    if (m.grossDepthMm <= 0 || m.hoursPerCycle <= 0) continue;
    var peak = 0.0;
    String? worst;
    for (final a in areasOfMachine(p, m)) {
      final g = areaWaterBasis(p, a).grossMmDay;
      if (g > peak) {
        peak = g;
        worst = a.id;
      }
    }
    if (peak <= 0) continue;
    final hours = peak * m.hoursPerCycle / m.grossDepthMm;
    machineHours[m.id] = hours;
    machines.add(
      MachineCapacity(
        pivotId: m.id,
        name: m.name.isNotEmpty ? m.name : (m.zoneName.isNotEmpty ? m.zoneName : m.id),
        capacityMmDay: m.grossDepthMm * window / m.hoursPerCycle,
        peakGrossMmDay: peak,
        hoursNeeded: hours,
        areaId: worst,
      ),
    );
  }
  final vih = VihStations.of(p);
  final valves = [for (final e in p.entities.whereType<ControlValveEntity>()) e.id];
  final flows = p.systemFlows.where((f) => f.valveIds.isNotEmpty).toList();
  final groups = flows.isNotEmpty
      ? [for (final f in flows) (f.id, f.name, f.valveIds)]
      : [
          ('all', '', {...valves, ...vih.heads.keys, for (final m in p.entities.whereType<PivotEntity>()) m.id}),
        ];
  NetworkModel? model;
  final out = <FlowCapacity>[];
  for (final (id, name, members) in groups) {
    var hours = 0.0;
    String? worst;
    void need(AreaEntity a) {
      final r = reqs[a.id];
      if (r == null || r.flow <= 0 || r.machineFlow > 0.5 * r.flow) return;
      if (r.hoursPerDay > hours) {
        hours = r.hoursPerDay;
        worst = a.id;
      }
    }

    for (final v in members) {
      final e = p.byId(v);
      if (e is PivotEntity) {
        final h = machineHours[v];
        if (h != null && h > hours) {
          hours = h;
          worst = null;
        }
      } else if (vih.isStation(v)) {
        areasOfStation(p, v, stations: vih).forEach(need);
      } else if (e is ControlValveEntity) {
        final net = model ??= NetworkBuilder(p).build();
        areasOfZoneNominal(p, net, v).forEach(need);
      }
    }
    if (hours > 0) out.add(FlowCapacity(flowId: id, name: name, hours: math.min(hours, 1e6), areaId: worst));
  }
  return SystemCapacity(windowHours: window, flows: out, machines: machines);
}
