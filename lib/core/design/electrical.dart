/// Electrical design of the valve wiring: the 24 V AC that a controller
/// sends to the solenoid of every zone valve along the wire routes drawn
/// from it. Each valve gets a station conductor of its own; the common
/// (return) conductor is shared along the routes. The design picks, for
/// every controller, the common wire and the station wire of every valve
/// with the lowest cost that keeps the solenoid voltage, while the valve
/// opens, at or above the minimum.
///
/// A valve-in-head station (`valve_in_head.dart`) is a station like a zone
/// valve, after the zone valves of its controller, with the solenoids of
/// its heads in parallel: its station conductor follows the routes from the
/// controller to every head (the union of their paths), and on every stretch
/// it carries the current of the heads beyond it, as the common conductor
/// does. A head that no route reaches is reported unwired, the station's
/// other heads still wired.
///
/// The controller must also deliver the current: every station output the
/// inrush of its solenoids (a valve-in-head station opens all its heads at
/// once) and the controller the worst instant of a system flow — a station
/// opening while the others hold, or the master valve opening together with
/// the first station (two inrush currents). Without the controller's data
/// the typical outputs of 24 V AC controllers are used ([typicalStationCurrentA],
/// [typicalControllerCurrentA]); above them a relay (pump start or station
/// relay) or a split station is needed (`elec_station_current`,
/// `elec_overcurrent`).
library;

import 'dart:collection';
import 'dart:math' as math;

import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import 'valve_in_head.dart';

/// One valve circuit: station conductor from the controller to the valve.
class WireRun {
  WireRun({
    required this.valveId,
    required this.zoneName,
    required this.controllerId,
    required this.station,
    required this.routeM,
    required this.wireM,
    this.stationWireId,
    this.commonWireId,
    required this.volts,
    required this.ok,
    this.openTogether = 1,
    this.solenoids = 1,
  });

  /// The valve, master valve or valve-in-head station (station id).
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
  /// flow already on (V); the lowest head of a valve-in-head station.
  final double volts;
  final bool ok;

  /// Valves of the same controller open together (worst system flow).
  final int openTogether;

  /// Solenoids on the station conductor: the wired heads of a valve-in-head
  /// station, else 1.
  final int solenoids;

  Map<String, dynamic> toJson() => {
    'valve': valveId,
    'zone': zoneName,
    'ctrl': controllerId,
    'st': station,
    'route': routeM,
    'wire': wireM,
    if (stationWireId != null) 'sw': stationWireId,
    if (commonWireId != null) 'cw': commonWireId,
    'v': volts,
    'ok': ok,
    'n': openTogether,
    if (solenoids != 1) 'sol': solenoids,
  };
  static WireRun fromJson(Map<String, dynamic> j) => WireRun(
    valveId: j['valve'] as String,
    zoneName: j['zone'] as String? ?? '',
    controllerId: j['ctrl'] as String? ?? '',
    station: (j['st'] as num?)?.toInt() ?? 0,
    routeM: (j['route'] as num?)?.toDouble() ?? 0,
    wireM: (j['wire'] as num?)?.toDouble() ?? 0,
    stationWireId: j['sw'] as String?,
    commonWireId: j['cw'] as String?,
    volts: (j['v'] as num?)?.toDouble() ?? 0,
    ok: j['ok'] as bool? ?? true,
    openTogether: (j['n'] as num?)?.toInt() ?? 1,
    solenoids: (j['sol'] as num?)?.toInt() ?? 1,
  );
}

/// Current one station output of a 24 V AC controller typically delivers
/// (A), when the controller's own rating is not given.
const typicalStationCurrentA = 0.56;

/// Current a 24 V AC controller typically delivers in all (A; a transformer
/// of about 40 VA), when its own rating is not given.
const typicalControllerCurrentA = 1.5;

/// What a controller drives.
class ControllerDuty {
  ControllerDuty({
    required this.controllerId,
    required this.name,
    required this.stations,
    required this.used,
    this.commonWireId,
    required this.commonRouteM,
    required this.commonWireM,
    required this.maxOpen,
    required this.peakCurrentA,
    this.largestStationA = 0,
    this.stationLimitA = typicalStationCurrentA,
    this.totalLimitA = typicalControllerCurrentA,
  });
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

  /// Inrush of the station that draws most (A) and the limits checked: one
  /// station output and the whole controller (A).
  final double largestStationA;
  final double stationLimitA;
  final double totalLimitA;
  bool get overloaded => used > stations;

  /// The controller cannot deliver a station or the peak of a flow.
  bool get overcurrent => largestStationA > stationLimitA + 1e-9 || peakCurrentA > totalLimitA + 1e-9;

  Map<String, dynamic> toJson() => {
    'ctrl': controllerId,
    'name': name,
    'stations': stations,
    'used': used,
    if (commonWireId != null) 'cw': commonWireId,
    'route': commonRouteM,
    'wire': commonWireM,
    'open': maxOpen,
    'amps': peakCurrentA,
    if (largestStationA > 0) 'ist': largestStationA,
    'imax': stationLimitA,
    'itot': totalLimitA,
  };
  static ControllerDuty fromJson(Map<String, dynamic> j) => ControllerDuty(
    controllerId: j['ctrl'] as String,
    name: j['name'] as String? ?? '',
    stations: (j['stations'] as num?)?.toInt() ?? 0,
    used: (j['used'] as num?)?.toInt() ?? 0,
    commonWireId: j['cw'] as String?,
    commonRouteM: (j['route'] as num?)?.toDouble() ?? 0,
    commonWireM: (j['wire'] as num?)?.toDouble() ?? 0,
    maxOpen: (j['open'] as num?)?.toInt() ?? 0,
    peakCurrentA: (j['amps'] as num?)?.toDouble() ?? 0,
    largestStationA: (j['ist'] as num?)?.toDouble() ?? 0,
    stationLimitA: (j['imax'] as num?)?.toDouble() ?? typicalStationCurrentA,
    totalLimitA: (j['itot'] as num?)?.toDouble() ?? typicalControllerCurrentA,
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

  Map<String, dynamic> toJson() => {'runs': runs.map((r) => r.toJson()).toList(), 'ctrls': controllers.map((c) => c.toJson()).toList(), 'warn': warnings, 'meters': wireMeters};
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
/// together (the system flows with the valve-in-head stations they run;
/// valves in no flow open alone).
ElectricalResult? designElectrical(Project p, {List<Set<String>> flows = const []}) {
  final controllers = p.entities.whereType<ControllerEntity>().toList();
  final wires = p.entities.whereType<WireEntity>().where((w) => w.points.length >= 2).toList();
  if (controllers.isEmpty && wires.isEmpty) return null;
  final params = p.params;
  final sol = SolenoidSpec(inrushA: params.solenoidInrushA, holdingA: params.solenoidHoldingA, minVolts: params.solenoidMinVolts);
  final slack = 1 + math.max(0.0, params.wireSlackPct) / 100;
  final result = ElectricalResult();
  final valves = p.entities.whereType<ControlValveEntity>().toList();
  // master valves on the mainline: open whenever a zone of their controller
  // is (its master-valve output, not a station)
  final masters = [
    for (final e in p.entities.whereType<MiscHydraulicEntity>())
      if (p.catalog.valve(e.valveSpecId)?.kind == ValveKind.master) e,
  ];
  final circuits = <String, Pt>{for (final v in valves) v.id: v.position, for (final m in masters) m.id: m.position};
  final vih = VihStations.of(p);
  final headAt = <String, Pt>{
    for (final e in p.entities)
      if (e is OutletEntity && vih.stationOf.containsKey(e.id)) e.id: e.position,
  };
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
  for (final e in circuits.entries) {
    final n = g.attach(e.value);
    if (n != null) valveNode[e.key] = n;
  }
  final headNode = <String, int>{};
  for (final e in headAt.entries) {
    final n = g.attach(e.value);
    if (n != null) headNode[e.key] = n;
  }
  final adj = g.adjacency();
  final paths = <String, (Map<int, double>, Map<int, int>)>{for (final e in ctrlNode.entries) e.key: g.shortest(e.value, adj)};

  // every valve to the nearest controller it is wired to
  final owner = <String, String>{};
  final distance = <String, double>{};
  for (final id in circuits.keys) {
    final n = valveNode[id];
    if (n == null) continue;
    for (final c in controllers) {
      final d = paths[c.id]?.$1[n];
      if (d != null && d < (distance[id] ?? double.infinity)) {
        distance[id] = d;
        owner[id] = c.id;
      }
    }
  }
  for (final id in circuits.keys) {
    if (!owner.containsKey(id)) result.warnings.add('elec_unwired:$id');
  }
  // a valve-in-head station on the controller that reaches most of its
  // heads (the shorter routes on a tie): the heads it does not reach are
  // reported together, the others wired
  final stationHeads = <String, List<String>>{};
  for (final s in vih.heads.entries) {
    String? best;
    var reach = 0;
    var total = double.infinity;
    for (final c in controllers) {
      final dist = paths[c.id]?.$1;
      if (dist == null) continue;
      var k = 0;
      var sum = 0.0;
      for (final h in s.value) {
        final d = dist[headNode[h] ?? -1];
        if (d == null) continue;
        k++;
        sum += d;
      }
      if (k > reach || (k == reach && k > 0 && sum < total)) {
        best = c.id;
        reach = k;
        total = sum;
      }
    }
    final dist = best == null ? const <int, double>{} : paths[best]!.$1;
    final wired = [
      for (final h in s.value)
        if (dist.containsKey(headNode[h] ?? -1)) h,
    ];
    if (wired.length < s.value.length) {
      result.warnings.add(
        'elec_unwired:${[for (final h in s.value)
          if (!wired.contains(h)) h].join(':')}',
      );
    }
    if (best == null || wired.isEmpty) continue;
    owner[s.key] = best;
    distance[s.key] = wired.map((h) => dist[headNode[h]!]!).reduce(math.min);
    stationHeads[s.key] = wired;
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
    final mine = [
      for (final v in valves)
        if (owner[v.id] == c.id) v,
    ]..sort((a, b) => distance[a.id]!.compareTo(distance[b.id]!));
    // valve-in-head stations after the zone valves, by their nearest head
    final myHeads = [
      for (final s in stationHeads.keys)
        if (owner[s] == c.id) s,
    ]..sort((a, b) => distance[a]!.compareTo(distance[b]!));
    final stationLimit = c.stationMaxA > 0 ? c.stationMaxA : typicalStationCurrentA;
    final totalLimit = c.totalMaxA > 0 ? c.totalMaxA : typicalControllerCurrentA;
    if (mine.isEmpty && myHeads.isEmpty) {
      result.controllers.add(
        ControllerDuty(
          controllerId: c.id,
          name: c.name,
          stations: c.stations,
          used: 0,
          commonRouteM: 0,
          commonWireM: 0,
          maxOpen: 0,
          peakCurrentA: 0,
          stationLimitA: stationLimit,
          totalLimitA: totalLimit,
        ),
      );
      continue;
    }
    if (mine.length + myHeads.length > c.stations) result.warnings.add('elec_stations:${c.id}');
    final myMasters = [
      for (final m in masters)
        if (owner[m.id] == c.id) m.id,
    ]..sort((a, b) => distance[a]!.compareTo(distance[b]!));
    final circuitIds = [for (final v in mine) v.id, ...myHeads, ...myMasters];
    final via = paths[c.id]!.$2;
    List<int> walk(int from) {
      final edges = <int>[];
      var n = from;
      var guard = 0;
      while (n != ctrlNode[c.id] && guard++ < 100000) {
        final ei = via[n]!;
        edges.add(ei);
        n = g.edge(ei).other(n);
      }
      return edges;
    }

    // edges from the controller to each valve (and master valve); for a
    // valve-in-head station to each head, and the heads beyond every edge
    final pathOf = <String, List<int>>{};
    final headPaths = <String, Map<String, List<int>>>{};
    final beyond = <String, Map<int, int>>{};
    for (final id in circuitIds) {
      final hs = stationHeads[id];
      if (hs == null) {
        pathOf[id] = walk(valveNode[id]!);
        continue;
      }
      final per = {for (final h in hs) h: walk(headNode[h]!)};
      final k = <int, int>{};
      for (final e in per.values) {
        for (final ei in e) {
          k[ei] = (k[ei] ?? 0) + 1;
        }
      }
      headPaths[id] = per;
      beyond[id] = k;
      pathOf[id] = k.keys.toList();
    }
    final treeEdges = {for (final e in pathOf.values) ...e};
    final commonRoute = treeEdges.fold(0.0, (s, ei) => s + g.edge(ei).length);
    // groups of this controller's valves that open together
    final ids = {for (final v in mine) v.id, ...myHeads};
    final groups = <Set<String>>[];
    for (final f in flows) {
      final gset = f.intersection(ids);
      if (gset.isNotEmpty) groups.add(gset);
    }
    for (final id in [for (final v in mine) v.id, ...myHeads]) {
      if (!groups.any((gs) => gs.contains(id))) groups.add({id});
    }
    final maxOpen = groups.fold(0, (m, gs) => math.max(m, gs.length));
    if (c.maxSimultaneous > 0 && maxOpen > c.maxSimultaneous) result.warnings.add('elec_simultaneous:${c.id}');
    // the master valves are on with every group of zones
    for (final gs in groups) {
      gs.addAll(myMasters);
    }

    /// Solenoids of circuit [u] fed through edge [ei].
    int solenoidsOn(String u, int ei) => beyond[u]?[ei] ?? (pathOf[u]!.contains(ei) ? 1 : 0);

    /// Common-conductor voltage drop per ohm/km of wire along [path] (to a
    /// valve or a head) while circuit [v] opens with the other circuits of
    /// [group] holding.
    double commonDropPerOhmKm(List<int> path, String v, Set<String> group) {
      var drop = 0.0;
      for (final ei in path) {
        var amps = 0.0;
        for (final u in group) {
          final k = solenoidsOn(u, ei);
          if (k > 0) amps += k * (u == v ? sol.inrushA : sol.holdingA);
        }
        drop += amps * g.edge(ei).length * slack / 1000;
      }
      return drop;
    }

    final worstCommon = {
      for (final id in circuitIds)
        if (!headPaths.containsKey(id)) id: groups.where((gs) => gs.contains(id)).map((gs) => commonDropPerOhmKm(pathOf[id]!, id, gs)).fold(0.0, math.max),
    };
    final openWith = {for (final id in circuitIds) id: groups.where((gs) => gs.contains(id)).map((gs) => gs.length).fold(1, math.max)};
    // every head of a valve-in-head station: the station and common
    // conductor drops per ohm/km (all its heads opening together)
    final headDrops = {
      for (final e in headPaths.entries)
        e.key: [
          for (final h in e.value.entries)
            (
              h.key,
              h.value.fold(0.0, (s, ei) => s + beyond[e.key]![ei]! * sol.inrushA * g.edge(ei).length * slack / 1000),
              groups.where((gs) => gs.contains(e.key)).map((gs) => commonDropPerOhmKm(h.value, e.key, gs)).fold(0.0, math.max),
            ),
        ],
    };
    double headVolts((String, double, double) d, WireSpec station, WireSpec common) => c.outputVolts - d.$2 * station.ohmPerKm - d.$3 * common.ohmPerKm;
    double volts(String v, WireSpec station, WireSpec common) {
      final drops = headDrops[v];
      if (drops != null) return drops.fold(double.infinity, (m, d) => math.min(m, headVolts(d, station, common)));
      return c.outputVolts - sol.inrushA * station.ohmPerKm * distance[v]! * slack / 1000 - worstCommon[v]! * common.ohmPerKm;
    }

    // conductor route: to the valve, or along the union of a station's paths
    double routeOf(String id) => headPaths.containsKey(id) ? pathOf[id]!.fold(0.0, (s, ei) => s + g.edge(ei).length) : distance[id]!;

    WireSpec? commonBest;
    Map<String, WireSpec>? stationBest;
    var bestCost = double.infinity;
    for (final cw in candidates) {
      final chosen = <String, WireSpec>{};
      var cost = commonRoute * slack * cw.costPerM;
      var feasible = true;
      for (final id in circuitIds) {
        // the cheapest station wire that keeps the voltage (thinnest on a tie)
        WireSpec? sw;
        for (final s in candidates) {
          if (volts(id, s, cw) >= sol.minVolts - 1e-9 && (sw == null || s.costPerM < sw.costPerM - 1e-12)) sw = s;
        }
        if (sw == null) {
          feasible = false;
          break;
        }
        chosen[id] = sw;
        cost += routeOf(id) * slack * sw.costPerM;
      }
      if (feasible && cost < bestCost - 1e-9) {
        bestCost = cost;
        commonBest = cw;
        stationBest = chosen;
      }
    }
    final common = commonBest ?? candidates.last;
    final stationOf = stationBest ?? {for (final id in circuitIds) id: candidates.last};
    var station = 0;
    var peak = 0.0;
    // one circuit opening (all the solenoids of a station at once), the
    // others of its group holding; or the master valve opening together
    // with the first station of the group: two inrush currents at once
    int solenoids(String id) => stationHeads[id]?.length ?? 1;
    final masterSet = myMasters.toSet();
    for (final gs in groups) {
      final top = gs.where((u) => !masterSet.contains(u)).fold(1, (m, u) => math.max(m, solenoids(u)));
      final all = gs.fold(0, (s, u) => s + solenoids(u));
      final masterCount = gs.where(masterSet.contains).length;
      peak = math.max(peak, math.max(top * sol.inrushA + (all - top) * sol.holdingA, (top + masterCount) * sol.inrushA));
    }
    // what one station output and the controller can deliver
    var largestStation = 0.0;
    for (final id in [for (final v in mine) v.id, ...myHeads]) {
      final amps = solenoids(id) * sol.inrushA;
      largestStation = math.max(largestStation, amps);
      // the valve, or every head of a valve-in-head station
      if (amps > stationLimit + 1e-9) result.warnings.add('elec_station_current:${(stationHeads[id] ?? [id]).join(':')}');
    }
    if (peak > totalLimit + 1e-9) result.warnings.add('elec_overcurrent:${c.id}');
    final byId = {for (final v in mine) v.id: v};
    for (final id in circuitIds) {
      final v = byId[id];
      final drops = headDrops[id];
      final sw = stationOf[id]!;
      final u = volts(id, sw, common);
      final ok = u >= sol.minVolts - 1e-9;
      // a station's message points at its lowest head
      if (!ok) result.warnings.add('elec_voltage:${drops == null ? id : drops.reduce((a, b) => headVolts(a, sw, common) <= headVolts(b, sw, common) ? a : b).$1}');
      final route = routeOf(id);
      final len = route * slack;
      final name = drops != null ? vih.nameOf(id) : (v == null ? (p.byId(id)?.name ?? '') : (v.zoneName.isNotEmpty ? v.zoneName : v.name));
      result.runs.add(
        WireRun(
          // station 0: the master-valve output
          valveId: id,
          zoneName: name,
          controllerId: c.id,
          station: v == null && drops == null ? 0 : ++station,
          routeM: route,
          wireM: len,
          stationWireId: sw.id.isEmpty ? null : sw.id,
          commonWireId: common.id.isEmpty ? null : common.id,
          volts: u,
          ok: ok,
          openTogether: openWith[id]!,
          solenoids: solenoids(id),
        ),
      );
      if (sw.id.isNotEmpty) result.wireMeters[sw.id] = (result.wireMeters[sw.id] ?? 0) + len;
    }
    if (common.id.isNotEmpty) result.wireMeters[common.id] = (result.wireMeters[common.id] ?? 0) + commonRoute * slack;
    result.controllers.add(
      ControllerDuty(
        controllerId: c.id,
        name: c.name,
        stations: c.stations,
        used: mine.length + myHeads.length,
        commonWireId: common.id.isEmpty ? null : common.id,
        commonRouteM: commonRoute,
        commonWireM: commonRoute * slack,
        maxOpen: maxOpen,
        peakCurrentA: peak,
        largestStationA: largestStation,
        stationLimitA: stationLimit,
        totalLimitA: totalLimit,
      ),
    );
  }
  return result;
}

/// Station counts controllers are commonly sold with.
const standardControllerStations = [4, 6, 8, 9, 12, 16, 18, 24, 32, 36, 42, 48, 54, 60, 72, 99];

/// The smallest standard station count that holds [used] valves.
int standardStations(int used) => standardControllerStations.firstWhere((n) => n >= used, orElse: () => used);
