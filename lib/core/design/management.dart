/// Management helpers: demand of every zone and pivot, and the automatic
/// grouping of the zones into system flows (shifts) that fit the supply.
library;

import 'dart:math' as math;

import '../model/entities.dart';
import '../model/project.dart';
import 'designer.dart';
import 'network_builder.dart';
import 'results.dart';

/// Ids of the demands a system flow can hold: zone valves and pivots, in
/// drawing order.
List<String> demandIds(Project p) => [
  for (final e in p.entities)
    if (e is ControlValveEntity || e is PivotEntity) e.id,
];

/// Display name of a demand: the zone name of a valve or pivot, else its
/// name, else its id.
String demandName(Project p, String id) {
  final e = p.byId(id);
  final zone = switch (e) {
    ControlValveEntity v => v.zoneName,
    PivotEntity v => v.zoneName,
    _ => '',
  };
  if (zone.isNotEmpty) return zone;
  final n = e?.name ?? '';
  return n.isNotEmpty ? n : id;
}

/// Flow (m³/s) each zone valve and pivot draws: the design flows when
/// [results] hold them, else the nominal flow of the emitters downstream of
/// the valve (every emitter at its nominal pressure) and the machine flow of
/// the pivots.
Map<String, double> nominalDemands(Project p, {DesignResults? results}) {
  final out = <String, double>{};
  NetworkModel? model;
  Designer? designer;
  for (final id in demandIds(p)) {
    final fromResults = results?.zones[id]?.totalFlow ?? results?.pivots[id]?.flow;
    if (fromResults != null && fromResults > 0) {
      out[id] = fromResults;
      continue;
    }
    final e = p.byId(id);
    if (e is PivotEntity) {
      designer ??= Designer(p);
      out[id] = designer.analyzePivotEntity(e).flow;
      continue;
    }
    model ??= designer?.model ?? NetworkBuilder(p).build();
    var q = 0.0;
    for (final nid in model.zoneNodes[id] ?? const <String>{}) {
      for (final em in model.nodes[nid]?.emitters ?? const <EmitterRef>[]) {
        if (em.index == -2) continue; // flushing ends
        q += em.nominalFlow;
      }
    }
    out[id] = q;
  }
  return out;
}

/// Options of [autoSystemFlows].
class AutoFlowOptions {
  AutoFlowOptions({this.maxFlow = 0, this.maxValves = 0, this.durationHours = 1, this.firstStartHour = 6});

  /// Largest flow of a system flow (m³/s); 0 = the design flow of the water
  /// supplies (their sum), or no limit when no supply states one.
  double maxFlow;

  /// Most zones open together (0 = no limit).
  int maxValves;

  /// Duration of each system flow (h) and start of the first one (h).
  double durationHours;
  double firstStartHour;
}

/// Outcome of [autoSystemFlows].
class AutoFlowPlan {
  AutoFlowPlan(this.flows, this.capacity, this.demands, this.oversized);

  /// The new system flows, in operating order.
  final List<SystemFlow> flows;

  /// Flow limit used (m³/s; 0 = none).
  final double capacity;

  /// Demand of every zone and pivot (m³/s).
  final Map<String, double> demands;

  /// Zones or pivots that alone draw more than [capacity]: each got a
  /// system flow of its own and will be reported by the design.
  final List<String> oversized;
}

/// Sum of the design flows of the water supplies, or 0 when any supply
/// leaves it blank (no limit known).
double suppliesDesignFlow(Project p) {
  final supplies = p.entities.whereType<WaterSupplyEntity>().toList();
  if (supplies.isEmpty || supplies.any((s) => !(s.designFlow > 0))) return 0;
  return supplies.fold(0.0, (s, e) => s + e.designFlow);
}

/// Groups the zones and pivots into as few system flows as the flow limit
/// and the number of valves allow (first-fit decreasing: the largest
/// demands are placed first). The flows run one after the other from
/// [AutoFlowOptions.firstStartHour]. [label] translates `name.flow`.
AutoFlowPlan autoSystemFlows(Project p, AutoFlowOptions o, {DesignResults? results, String Function(String key) label = _id}) {
  final demands = nominalDemands(p, results: results);
  final cap = o.maxFlow > 0 ? o.maxFlow : suppliesDesignFlow(p);
  final order = demands.keys.toList()
    ..sort((a, b) {
      final c = demands[b]!.compareTo(demands[a]!);
      return c != 0 ? c : demandIds(p).indexOf(a).compareTo(demandIds(p).indexOf(b));
    });
  final bins = <List<String>>[];
  final loads = <double>[];
  final oversized = <String>[];
  for (final id in order) {
    final q = demands[id]!;
    if (cap > 0 && q > cap + 1e-12) {
      oversized.add(id);
      bins.add([id]);
      loads.add(q);
      continue;
    }
    var placed = false;
    for (var i = 0; i < bins.length; i++) {
      if (oversized.contains(bins[i].first)) continue;
      final fits = (cap <= 0 || loads[i] + q <= cap + 1e-12) && (o.maxValves <= 0 || bins[i].length < o.maxValves);
      if (fits) {
        bins[i].add(id);
        loads[i] += q;
        placed = true;
        break;
      }
    }
    if (!placed) {
      bins.add([id]);
      loads.add(q);
    }
  }
  // operate in drawing order of the first zone of each flow
  final drawn = demandIds(p);
  for (final b in bins) {
    b.sort((x, y) => drawn.indexOf(x).compareTo(drawn.indexOf(y)));
  }
  final idx = List.generate(bins.length, (i) => i)..sort((a, b) => drawn.indexOf(bins[a].first).compareTo(drawn.indexOf(bins[b].first)));
  final taken = {for (final f in p.systemFlows) f.id};
  final flows = <SystemFlow>[];
  final dur = o.durationHours > 0 ? o.durationHours : 1.0;
  var start = o.firstStartHour;
  for (var k = 0; k < idx.length; k++) {
    final ids = bins[idx[k]];
    var id = 'sf${k + 1}';
    for (var n = 2; taken.contains(id) && !p.systemFlows.any((f) => f.id == id && _sameSet(f.valveIds, ids)); n++) {
      id = 'sf${k + 1}_$n';
    }
    final zones = ids.map((v) => demandName(p, v)).join(' + ');
    flows.add(SystemFlow(id: id, name: '${label('name.flow')} ${k + 1} — $zones', valveIds: ids.toSet(), startHour: start % 24, durationHours: dur));
    start += dur;
  }
  return AutoFlowPlan(flows, cap, demands, oversized);
}

bool _sameSet(Set<String> a, List<String> b) => a.length == b.length && a.containsAll(b);

String _id(String k) => k;

/// Largest total demand among [flows] (m³/s).
double peakFlowDemand(List<SystemFlow> flows, Map<String, double> demands) =>
    flows.fold(0.0, (m, f) => math.max(m, f.valveIds.fold(0.0, (s, id) => s + (demands[id] ?? 0))));
