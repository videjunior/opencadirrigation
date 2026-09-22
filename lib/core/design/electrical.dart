/// Electrical design of the valve wiring: the 24 V AC that a controller
/// sends to the solenoid of every zone valve along the wire routes drawn
/// from it. Each valve gets a station conductor of its own; the common
/// (return) conductor is shared along the routes. The design picks, for
/// every controller, the common wire and the station wire of every valve
/// with the lowest cost that keeps the solenoid voltage, while the valve
/// opens, at or above the minimum.
library;

import 'dart:collection';
import 'dart:math' as math;

import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';

/// One valve circuit: station conductor from the controller to the valve.
class WireRun {
  WireRun({required this.valveId, required this.zoneName, required this.controllerId, required this.station, required this.routeM, required this.wireM, this.stationWireId, this.commonWireId, required this.volts, required this.ok, this.openTogether = 1});
  final String valveId;
  final String zoneName;
  final String controllerId;

  /// Station number on the controller (1 = nearest valve).
  final int station;

  /// Length of the route from the controller (m) and of the conductor with
  /// the slack allowance (m).
  final double routeM;
  final double wireM;
  final String? stationWireId;
  final String? commonWireId;

  /// Solenoid voltage while the valve opens, with the valves of its system
  /// flow already on (V).
  final double volts;
  final bool ok;

  /// Valves of the same controller open together (worst system flow).
  final int openTogether;

  Map<String, dynamic> toJson() => {
    'valve': valveId, 'zone': zoneName, 'ctrl': controllerId, 'st': station, 'route': routeM, 'wire': wireM, if (stationWireId != null) 'sw': stationWireId, if (commonWireId != null) 'cw': commonWireId,
    'v': volts, 'ok': ok, 'n': openTogether,
  };
  static WireRun fromJson(Map<String, dynamic> j) => WireRun(
    valveId: j['valve'] as String, zoneName: j['zone'] as String? ?? '', controllerId: j['ctrl'] as String? ?? '', station: (j['st'] as num?)?.toInt() ?? 0,
    routeM: (j['route'] as num?)?.toDouble() ?? 0, wireM: (j['wire'] as num?)?.toDouble() ?? 0, stationWireId: j['sw'] as String?, commonWireId: j['cw'] as String?,
    volts: (j['v'] as num?)?.toDouble() ?? 0, ok: j['ok'] as bool? ?? true, openTogether: (j['n'] as num?)?.toInt() ?? 1,
  );
}

/// What a controller drives.
class ControllerDuty {
  ControllerDuty({required this.controllerId, required this.name, required this.stations, required this.used, this.commonWireId, required this.commonRouteM, required this.commonWireM, required this.maxOpen, required this.peakCurrentA});
  final String controllerId;
  final String name;
  final int stations;
  final int used;
  final String? commonWireId;

  /// Routes the common conductor follows (m) and its length with slack (m).
  final double commonRouteM;
  final double commonWireM;

  /// Most valves of this controller open together, and the current the
  /// controller supplies then (one opening, the others holding; A).
  final int maxOpen;
  final double peakCurrentA;
  bool get overloaded => used > stations;

  Map<String, dynamic> toJson() => {
    'ctrl': controllerId, 'name': name, 'stations': stations, 'used': used, if (commonWireId != null) 'cw': commonWireId, 'route': commonRouteM, 'wire': commonWireM, 'open': maxOpen, 'amps': peakCurrentA,
  };
  static ControllerDuty fromJson(Map<String, dynamic> j) => ControllerDuty(
    controllerId: j['ctrl'] as String, name: j['name'] as String? ?? '', stations: (j['stations'] as num?)?.toInt() ?? 0, used: (j['used'] as num?)?.toInt() ?? 0, commonWireId: j['cw'] as String?,
    commonRouteM: (j['route'] as num?)?.toDouble() ?? 0, commonWireM: (j['wire'] as num?)?.toDouble() ?? 0, maxOpen: (j['open'] as num?)?.toInt() ?? 0, peakCurrentA: (j['amps'] as num?)?.toDouble() ?? 0,
  );
}

class ElectricalResult {
  ElectricalResult({List<WireRun>? runs, List<ControllerDuty>? controllers, List<String>? warnings, Map<String, double>? wireMeters})
      : runs = runs ?? [],
        controllers = controllers ?? [],
        warnings = warnings ?? [],
        wireMeters = wireMeters ?? {};
  final List<WireRun> runs;
  final List<ControllerDuty> controllers;

  /// Codes (`elec_*`, optionally `:<entity id>`) translated like the other
  /// design messages.
  final List<String> warnings;

  /// Conductor length per catalogue wire (m, slack included).
  final Map<String, double> wireMeters;

  WireRun? runOf(String valveId) => runs.where((r) => r.valveId == valveId).firstOrNull;

  Map<String, dynamic> toJson() => {
    'runs': runs.map((r) => r.toJson()).toList(), 'ctrls': controllers.map((c) => c.toJson()).toList(), 'warn': warnings, 'meters': wireMeters,
  };
  static ElectricalResult fromJson(Map<String, dynamic> j) => ElectricalResult(
    runs: ((j['runs'] as List?) ?? []).map((e) => WireRun.fromJson(e as Map<String, dynamic>)).toList(),
    controllers: ((j['ctrls'] as List?) ?? []).map((e) => ControllerDuty.fromJson(e as Map<String, dynamic>)).toList(),
    warnings: ((j['warn'] as List?) ?? []).cast<String>(),
    wireMeters: {for (final e in ((j['meters'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toDouble()},
  );
}

/// A stretch of wire route between two nodes of a [WireGraph].
class WireEdge {
  WireEdge(this.a, this.b, this.length, this.wireId);
  final int a, b;
  final double length;
  final String wireId;
  int other(int n) => n == a ? b : a;
}

/// The wire routes as a graph: vertices within the tolerance are one node;
/// a controller or valve on a vertex or on a route becomes a node.
class WireGraph {
  WireGraph(this.tolerance);
  final double tolerance;
  final List<Pt> nodes = [];
  final List<WireEdge?> _edges = [];
  final Map<(int, int), List<int>> _grid = {};

  (int, int) _cell(Pt p) => ((p.x / tolerance).floor(), (p.y / tolerance).floor());

  int? find(Pt p) {
    final (cx, cy) = _cell(p);
    int? best;
    var bd = tolerance;
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        for (final i in _grid[(cx + dx, cy + dy)] ?? const <int>[]) {
          final d = nodes[i].distanceTo(p);
          if (d <= bd) {
            bd = d;
            best = i;
          }
        }
      }
    }
    return best;
  }

  int node(Pt p) {
    final f = find(p);
    if (f != null) return f;
    nodes.add(p);
    _grid.putIfAbsent(_cell(p), () => []).add(nodes.length - 1);
    return nodes.length - 1;
  }

  void addEdge(int a, int b, String wireId) {
    if (a == b) return;
    _edges.add(WireEdge(a, b, nodes[a].distanceTo(nodes[b]), wireId));
  }

  Iterable<(int, WireEdge)> get edges sync* {
    for (var i = 0; i < _edges.length; i++) {
      final e = _edges[i];
      if (e != null) yield (i, e);
    }
  }

  /// Node for a device at [p]: an existing vertex, or a new one splitting
  /// the nearest route within the tolerance; null when [p] is off the routes.
  int? attach(Pt p) {
    final f = find(p);
    if (f != null) return f;
    int? bestEdge;
    var bd = tolerance;
    for (final (i, e) in edges) {
      final d = distanceToSegment(p, nodes[e.a], nodes[e.b]);
      if (d <= bd) {
        bd = d;
        bestEdge = i;
      }
    }
    if (bestEdge == null) return null;
    final e = _edges[bestEdge]!;
    _edges[bestEdge] = null;
    nodes.add(p);
    _grid.putIfAbsent(_cell(p), () => []).add(nodes.length - 1);
    final m = nodes.length - 1;
    addEdge(e.a, m, e.wireId);
    addEdge(m, e.b, e.wireId);
    return m;
  }

  Map<int, List<int>> adjacency() {
    final adj = <int, List<int>>{};
    for (final (i, e) in edges) {
      adj.putIfAbsent(e.a, () => []).add(i);
      adj.putIfAbsent(e.b, () => []).add(i);
    }
    return adj;
  }

  WireEdge edge(int i) => _edges[i]!;

  /// Shortest distances from [start] and the edge that reached each node.
  (Map<int, double>, Map<int, int>) shortest(int start, Map<int, List<int>> adj) {
    final dist = <int, double>{start: 0};
    final via = <int, int>{};
    final queue = SplayTreeSet<(double, int)>((x, y) => x.$1 != y.$1 ? x.$1.compareTo(y.$1) : x.$2.compareTo(y.$2))..add((0, start));
    while (queue.isNotEmpty) {
      final (d, n) = queue.first;
      queue.remove(queue.first);
      if (d > (dist[n] ?? double.infinity)) continue;
      for (final ei in adj[n] ?? const <int>[]) {
        final e = _edges[ei]!;
        final m = e.other(n);
        final nd = d + e.length;
        if (nd < (dist[m] ?? double.infinity) - 1e-12) {
          dist[m] = nd;
          via[m] = ei;
          queue.add((nd, m));
        }
      }
    }
    return (dist, via);
  }
}

/// Electrical settings of the design (see [DesignParameters]).
class SolenoidSpec {
  const SolenoidSpec({this.inrushA = 0.37, this.holdingA = 0.22, this.minVolts = 20});
  final double inrushA;
  final double holdingA;
  final double minVolts;
}

/// Designs the valve wiring of [p]: returns null when the drawing has no
/// controller and no wire route. [flows] are the valve sets that operate
/// together (the system flows; valves in no flow open alone).
ElectricalResult? designElectrical(Project p, {List<Set<String>> flows = const []}) {
  final controllers = p.entities.whereType<ControllerEntity>().toList();
  final wires = p.entities.whereType<WireEntity>().where((w) => w.points.length >= 2).toList();
  if (controllers.isEmpty && wires.isEmpty) return null;
  final params = p.params;
  final sol = SolenoidSpec(inrushA: params.solenoidInrushA, holdingA: params.solenoidHoldingA, minVolts: params.solenoidMinVolts);
  final slack = 1 + math.max(0.0, params.wireSlackPct) / 100;
  final result = ElectricalResult();
  final valves = p.entities.whereType<ControlValveEntity>().toList();
  if (controllers.isEmpty) {
    result.warnings.add('elec_no_controller');
    return result;
  }
  final g = WireGraph(math.max(p.params.connectTolerance, 0.1));
  for (final w in wires) {
    for (var i = 1; i < w.points.length; i++) {
      g.addEdge(g.node(w.points[i - 1]), g.node(w.points[i]), w.id);
    }
  }
  final ctrlNode = <String, int>{};
  for (final c in controllers) {
    final n = g.attach(c.position);
    if (n != null) ctrlNode[c.id] = n;
  }
  final valveNode = <String, int>{};
  for (final v in valves) {
    final n = g.attach(v.position);
    if (n != null) valveNode[v.id] = n;
  }
  final adj = g.adjacency();
  final paths = <String, (Map<int, double>, Map<int, int>)>{for (final e in ctrlNode.entries) e.key: g.shortest(e.value, adj)};

  // every valve to the nearest controller it is wired to
  final owner = <String, String>{};
  final distance = <String, double>{};
  for (final v in valves) {
    final n = valveNode[v.id];
    if (n == null) continue;
    for (final c in controllers) {
      final d = paths[c.id]?.$1[n];
      if (d != null && d < (distance[v.id] ?? double.infinity)) {
        distance[v.id] = d;
        owner[v.id] = c.id;
      }
    }
  }
  for (final v in valves) {
    if (!owner.containsKey(v.id)) result.warnings.add('elec_unwired:${v.id}');
  }
  // routes that reach no controller
  final reached = <int>{for (final pth in paths.values) ...pth.$1.keys};
  for (final w in wires) {
    final a = g.find(w.points.first);
    if (a == null || !reached.contains(a)) result.warnings.add('elec_wire_orphan:${w.id}');
  }
  for (final c in controllers) {
    if (!ctrlNode.containsKey(c.id)) result.warnings.add('elec_ctrl_unwired:${c.id}');
  }

  final catWires = p.catalog.enabledWires;
  if (catWires.isEmpty && owner.isNotEmpty) result.warnings.add('elec_no_wires');
  // a 1.5 mm² copper conductor stands in when the catalogue has no wire
  final candidates = catWires.isEmpty ? [WireSpec(id: '', name: '', sectionMm2: 1.5, ohmPerKm: copperOhmPerKm(1.5))] : catWires;

  for (final c in controllers) {
    final mine = [for (final v in valves) if (owner[v.id] == c.id) v]..sort((a, b) => distance[a.id]!.compareTo(distance[b.id]!));
    if (mine.isEmpty) {
      result.controllers.add(ControllerDuty(controllerId: c.id, name: c.name, stations: c.stations, used: 0, commonRouteM: 0, commonWireM: 0, maxOpen: 0, peakCurrentA: 0));
      continue;
    }
    if (mine.length > c.stations) result.warnings.add('elec_stations:${c.id}');
    final via = paths[c.id]!.$2;
    // edges from the controller to each valve
    final pathOf = <String, List<int>>{};
    for (final v in mine) {
      final edges = <int>[];
      var n = valveNode[v.id]!;
      var guard = 0;
      while (n != ctrlNode[c.id] && guard++ < 100000) {
        final ei = via[n]!;
        edges.add(ei);
        n = g.edge(ei).other(n);
      }
      pathOf[v.id] = edges;
    }
    final treeEdges = {for (final e in pathOf.values) ...e};
    final commonRoute = treeEdges.fold(0.0, (s, ei) => s + g.edge(ei).length);
    // groups of this controller's valves that open together
    final ids = {for (final v in mine) v.id};
    final groups = <Set<String>>[];
    for (final f in flows) {
      final gset = f.intersection(ids);
      if (gset.isNotEmpty) groups.add(gset);
    }
    for (final v in mine) {
      if (!groups.any((gs) => gs.contains(v.id))) groups.add({v.id});
    }
    final maxOpen = groups.fold(0, (m, gs) => math.max(m, gs.length));
    if (c.maxSimultaneous > 0 && maxOpen > c.maxSimultaneous) result.warnings.add('elec_simultaneous:${c.id}');

    /// Common-conductor voltage drop per ohm/km of wire for valve [v]
    /// opening with the other valves of [group] holding.
    double commonDropPerOhmKm(String v, Set<String> group) {
      var drop = 0.0;
      for (final ei in pathOf[v]!) {
        var amps = 0.0;
        for (final u in group) {
          if (pathOf[u]!.contains(ei)) amps += u == v ? sol.inrushA : sol.holdingA;
        }
        drop += amps * g.edge(ei).length * slack / 1000;
      }
      return drop;
    }

    final worstCommon = {for (final v in mine) v.id: groups.where((gs) => gs.contains(v.id)).map((gs) => commonDropPerOhmKm(v.id, gs)).fold(0.0, math.max)};
    final openWith = {for (final v in mine) v.id: groups.where((gs) => gs.contains(v.id)).map((gs) => gs.length).fold(1, math.max)};
    double volts(String v, WireSpec station, WireSpec common) =>
        c.outputVolts - sol.inrushA * station.ohmPerKm * distance[v]! * slack / 1000 - worstCommon[v]! * common.ohmPerKm;

    WireSpec? commonBest;
    Map<String, WireSpec>? stationBest;
    var bestCost = double.infinity;
    for (final cw in candidates) {
      final chosen = <String, WireSpec>{};
      var cost = commonRoute * slack * cw.costPerM;
      var feasible = true;
      for (final v in mine) {
        // the cheapest station wire that keeps the voltage (thinnest on a tie)
        WireSpec? sw;
        for (final s in candidates) {
          if (volts(v.id, s, cw) >= sol.minVolts - 1e-9 && (sw == null || s.costPerM < sw.costPerM - 1e-12)) sw = s;
        }
        if (sw == null) {
          feasible = false;
          break;
        }
        chosen[v.id] = sw;
        cost += distance[v.id]! * slack * sw.costPerM;
      }
      if (feasible && cost < bestCost - 1e-9) {
        bestCost = cost;
        commonBest = cw;
        stationBest = chosen;
      }
    }
    final common = commonBest ?? candidates.last;
    final stationOf = stationBest ?? {for (final v in mine) v.id: candidates.last};
    var station = 0;
    var peak = 0.0;
    for (final gs in groups) {
      peak = math.max(peak, sol.inrushA + (gs.length - 1) * sol.holdingA);
    }
    for (final v in mine) {
      final sw = stationOf[v.id]!;
      final u = volts(v.id, sw, common);
      final ok = u >= sol.minVolts - 1e-9;
      if (!ok) result.warnings.add('elec_voltage:${v.id}');
      final len = distance[v.id]! * slack;
      result.runs.add(WireRun(
        valveId: v.id, zoneName: v.zoneName.isNotEmpty ? v.zoneName : v.name, controllerId: c.id, station: ++station, routeM: distance[v.id]!, wireM: len,
        stationWireId: sw.id.isEmpty ? null : sw.id, commonWireId: common.id.isEmpty ? null : common.id, volts: u, ok: ok, openTogether: openWith[v.id]!,
      ));
      if (sw.id.isNotEmpty) result.wireMeters[sw.id] = (result.wireMeters[sw.id] ?? 0) + len;
    }
    if (common.id.isNotEmpty) result.wireMeters[common.id] = (result.wireMeters[common.id] ?? 0) + commonRoute * slack;
    result.controllers.add(ControllerDuty(
      controllerId: c.id, name: c.name, stations: c.stations, used: mine.length, commonWireId: common.id.isEmpty ? null : common.id, commonRouteM: commonRoute, commonWireM: commonRoute * slack, maxOpen: maxOpen, peakCurrentA: peak,
    ));
  }
  return result;
}

/// Station counts controllers are commonly sold with.
const standardControllerStations = [4, 6, 8, 9, 12, 16, 18, 24, 32, 36, 42, 48, 54, 60, 72, 99];

/// The smallest standard station count that holds [used] valves.
int standardStations(int used) => standardControllerStations.firstWhere((n) => n >= used, orElse: () => used);
