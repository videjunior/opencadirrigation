/// Automatic routing of the valve wires along the pipe trenches. The pipes
/// (mainline and zone pipes, as polylines) become a graph: vertices within
/// the tolerance are one node, a pipe ending on another or crossing it joins
/// it there. Every controller, zone valve, master valve and pump-start relay
/// is attached at the nearest point of a pipe, through a short stub when it
/// is off the pipes. Each valve goes to the controller nearest along the
/// trenches, and every controller's routes form a tree:
///
/// * `shortestPaths` (default for conventional wiring, where every valve has
///   a station conductor of its own): the union of the shortest paths from
///   the controller to its valves, a shortest-path tree (Dijkstra 1959), so
///   every station conductor is as short as the trenches allow;
/// * `steiner` (for a two-wire path, where only the route length counts):
///   the shortest-path heuristic for the Steiner tree in graphs (Takahashi &
///   Matsuyama 1980, "An approximate solution for the Steiner problem in
///   graphs", Mathematica Japonica 24): the tree grows from the controller by
///   the shortest path to the nearest valve not yet on it, at most twice the
///   optimum length.
///
/// The trees come back as polylines that share their end vertices, so that
/// `electrical.dart` and `two_wire.dart` connect them, with the valves on
/// their vertices. The master valve and the pump-start relay, when present,
/// are routed too and allocated as stations after the zone valves (or on the
/// controller's dedicated terminals, station 0). Every head of a
/// valve-in-head station (`valve_in_head.dart`) is routed, all of a station's
/// heads to one controller (the nearest to most of them), and the station
/// takes one station after the zone valves.
library;

import 'dart:collection';
import 'dart:math' as math;

import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import 'valve_in_head.dart';

/// How the routes of a controller are joined into a tree.
enum RoutingMode { shortestPaths, steiner }

/// What a station drives.
enum StationKind { zoneValve, valveInHead, masterValve, pumpRelay }

/// Options of [routeWires].
class WireRoutingOptions {
  const WireRoutingOptions({
    this.mode = RoutingMode.shortestPaths,
    this.tolerance = 0.1,
    this.connectCrossings = true,
    this.maxStubM = 30,
    this.masterValveStations = true,
    this.pumpRelayStations = true,
    this.includeZonePipes = true,
  });
  final RoutingMode mode;

  /// Distance (m) within which points are one node and an item is on a pipe.
  final double tolerance;

  /// Pipes crossing without a shared vertex join where they cross (the
  /// trenches meet there).
  final bool connectCrossings;

  /// Stubs longer than this (m) from a valve, master valve or relay to the
  /// nearest pipe are reported.
  final double maxStubM;

  /// Master valves and pump-start relays take stations after the zone
  /// valves (false = the controller's dedicated terminals, station 0).
  final bool masterValveStations;
  final bool pumpRelayStations;

  /// Zone pipes are trenches too ([autoRouteWires]); laterals and tapes
  /// never are.
  final bool includeZonePipes;
}

/// A route of one controller.
class WireRoute {
  WireRoute({required this.controllerId, required this.points});
  final String controllerId;
  final List<Pt> points;
  double get length => polylineLength(points);

  Map<String, dynamic> toJson() => {
    'ctrl': controllerId,
    'pts': [for (final p in points) p.toList()],
  };
  static WireRoute fromJson(Map<String, dynamic> j) => WireRoute(controllerId: j['ctrl'] as String? ?? '', points: [for (final p in (j['pts'] as List?) ?? []) Pt.fromList(p as List)]);
}

/// A station of a controller.
class StationAllocation {
  StationAllocation({required this.controllerId, required this.station, required this.kind, required this.entityId, required this.routeM});
  final String controllerId;

  /// Station number (0 = a dedicated terminal of the controller).
  final int station;
  final StationKind kind;

  /// The valve, master valve or pump; the station id of a valve-in-head
  /// station.
  final String entityId;

  /// Length of the route from the controller (m); for a valve-in-head
  /// station, of the routes to all its heads.
  final double routeM;

  Map<String, dynamic> toJson() => {'ctrl': controllerId, 'st': station, 'kind': kind.name, 'id': entityId, 'route': routeM};
  static StationAllocation fromJson(Map<String, dynamic> j) => StationAllocation(
    controllerId: j['ctrl'] as String? ?? '',
    station: (j['st'] as num?)?.toInt() ?? 0,
    kind: StationKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => StationKind.zoneValve),
    entityId: j['id'] as String? ?? '',
    routeM: (j['route'] as num?)?.toDouble() ?? 0,
  );
}

/// Outcome of [routeWires].
class WireRoutingResult {
  WireRoutingResult({required this.routes, required this.stations, required this.warnings});
  final List<WireRoute> routes;
  final List<StationAllocation> stations;

  /// `wire_route_no_controller`, `wire_route_no_pipes`,
  /// `wire_route_unreachable:<id>` (no trench joins the item to a
  /// controller), `wire_route_long_stub:<id>`, `wire_route_stations:<controller>`
  /// (more stations than the controller has).
  final List<String> warnings;

  double get totalRouteM => routes.fold(0.0, (s, r) => s + r.length);
  double routeLengthOf(String controllerId) => routes.where((r) => r.controllerId == controllerId).fold(0.0, (s, r) => s + r.length);

  Map<String, dynamic> toJson() => {'routes': routes.map((r) => r.toJson()).toList(), 'st': stations.map((s) => s.toJson()).toList(), 'warn': warnings};
  static WireRoutingResult fromJson(Map<String, dynamic> j) => WireRoutingResult(
    routes: [for (final r in (j['routes'] as List?) ?? []) WireRoute.fromJson(r as Map<String, dynamic>)],
    stations: [for (final s in (j['st'] as List?) ?? []) StationAllocation.fromJson(s as Map<String, dynamic>)],
    warnings: ((j['warn'] as List?) ?? []).cast<String>(),
  );
}

/// Routes for the controllers, zone valves, master valves and relays of [p]
/// along its pipes ([routeWires]): every controller, every zone valve, the
/// master valves (or control-kind devices on the mainline) as master valves and the pumps as
/// pump-start relays; mainline pipes and, with
/// [WireRoutingOptions.includeZonePipes], zone pipes.
WireRoutingResult autoRouteWires(Project p, {WireRoutingOptions options = const WireRoutingOptions()}) {
  final controllers = {for (final c in p.entities.whereType<ControllerEntity>()) c.id: c.position};
  final valves = {for (final v in p.entities.whereType<ControlValveEntity>()) v.id: v.position};
  final masters = {
    for (final m in p.entities.whereType<MiscHydraulicEntity>())
      if (switch (p.catalog.valve(m.valveSpecId)?.kind) {
        ValveKind.master => true,
        ValveKind.control => m.scope == HydraulicScope.mainline,
        _ => false,
      })
        m.id: m.position,
  };
  final relays = {for (final pu in p.entities.whereType<PumpEntity>()) pu.id: pu.position};
  final pipes = [
    for (final e in p.entities.whereType<PipeEntity>())
      if (e.points.length >= 2 && (e.scope == HydraulicScope.mainline || options.includeZonePipes)) e.points,
  ];
  final r = routeWires(controllers: controllers, valves: valves, pipes: pipes, masterValves: masters, pumpRelays: relays, valveInHead: valveInHeadOf(p), options: options);
  for (final c in p.entities.whereType<ControllerEntity>()) {
    final used = r.stations.where((s) => s.controllerId == c.id && s.station > 0).length;
    if (used > c.stations) r.warnings.add('wire_route_stations:${c.id}');
  }
  return r;
}

/// The heads of every valve-in-head station of [p]: station id → head id →
/// position.
Map<String, Map<String, Pt>> valveInHeadOf(Project p) {
  final vih = VihStations.of(p);
  if (vih.isEmpty) return const {};
  final at = {
    for (final e in p.entities)
      if (e is OutletEntity && vih.stationOf.containsKey(e.id)) e.id: e.position,
  };
  return {
    for (final s in vih.heads.entries) s.key: {for (final h in s.value) h: at[h]!},
  };
}

/// Routes the wires from [controllers] to [valves], [masterValves],
/// [pumpRelays] (ids → positions) and the heads of the [valveInHead]
/// stations (station id → head id → position) along the [pipes] polylines
/// (see the library comment).
WireRoutingResult routeWires({
  required Map<String, Pt> controllers,
  required Map<String, Pt> valves,
  required List<List<Pt>> pipes,
  Map<String, Pt> masterValves = const {},
  Map<String, Pt> pumpRelays = const {},
  Map<String, Map<String, Pt>> valveInHead = const {},
  WireRoutingOptions options = const WireRoutingOptions(),
}) {
  final warnings = <String>[];
  if (controllers.isEmpty) {
    warnings.add('wire_route_no_controller');
    return WireRoutingResult(routes: const [], stations: const [], warnings: warnings);
  }
  final tol = math.max(options.tolerance, 1e-6);
  final g = _TrenchGraph(tol);
  for (final pts in pipes) {
    for (var i = 1; i < pts.length; i++) {
      if (pts[i - 1].distanceTo(pts[i]) > tol) g.segments.add((pts[i - 1], pts[i]));
    }
  }
  if (g.segments.isEmpty) warnings.add('wire_route_no_pipes');
  g.index();
  // pipe vertices on other segments, and crossings
  for (final pts in pipes) {
    for (final p in pts) {
      g.splitNear(p);
    }
  }
  if (options.connectCrossings) g.splitCrossings();
  // terminals
  final kindOf = <String, StationKind>{};
  final terminals = <String, Pt>{};
  for (final e in valves.entries) {
    terminals[e.key] = e.value;
    kindOf[e.key] = StationKind.zoneValve;
  }
  for (final e in masterValves.entries) {
    terminals[e.key] = e.value;
    kindOf[e.key] = StationKind.masterValve;
  }
  for (final e in pumpRelays.entries) {
    terminals[e.key] = e.value;
    kindOf[e.key] = StationKind.pumpRelay;
  }
  final stationOfHead = <String, String>{};
  for (final s in valveInHead.entries) {
    for (final h in s.value.entries) {
      terminals[h.key] = h.value;
      kindOf[h.key] = StationKind.valveInHead;
      stationOfHead[h.key] = s.key;
    }
  }
  final attach = <String, (Pt, Pt?)>{};
  for (final e in {...controllers, ...terminals}.entries) {
    final (on, d) = g.nearest(e.value);
    if (on == null) continue;
    if (d <= tol) {
      g.splitAt(on);
      attach[e.key] = (on, null);
    } else {
      g.splitAt(on);
      attach[e.key] = (on, e.value);
      if (terminals.containsKey(e.key) && d > options.maxStubM) warnings.add('wire_route_long_stub:${e.key}');
    }
  }
  g.build();
  final nodeOf = <String, int>{};
  for (final e in attach.entries) {
    final (on, stub) = e.value;
    final a = g.node(on);
    if (stub == null) {
      nodeOf[e.key] = a;
    } else {
      final b = g.node(stub);
      g.addEdge(a, b);
      nodeOf[e.key] = b;
    }
  }
  // stand-alone items when there are no pipes: a controller and a valve at the
  // same place still connect
  for (final e in {...controllers, ...terminals}.entries) {
    nodeOf[e.key] ??= g.node(e.value);
  }
  // every terminal to its nearest controller along the trenches
  final ctrlIds = controllers.keys.toList()..sort();
  final (best, owner) = g.dijkstra([for (final c in ctrlIds) nodeOf[c]!]);
  final ctrlOfNode = {for (final c in ctrlIds) nodeOf[c]!: c};
  final ownerOf = <String, String>{};
  for (final t in (terminals.keys.toList()..sort())) {
    final n = nodeOf[t]!;
    final src = owner[n];
    if (src == null || best[n] == null) {
      warnings.add('wire_route_unreachable:$t');
      continue;
    }
    ownerOf[t] = ctrlOfNode[src]!;
  }
  // the heads of a valve-in-head station on one controller: the nearest to
  // most of them (the first on a tie)
  final votes = <String, Map<String, int>>{};
  for (final e in ownerOf.entries) {
    final s = stationOfHead[e.key];
    if (s == null) continue;
    final v = votes.putIfAbsent(s, () => {});
    v[e.value] = (v[e.value] ?? 0) + 1;
  }
  final mine = <String, List<String>>{for (final c in ctrlIds) c: []};
  for (final e in ownerOf.entries) {
    final s = stationOfHead[e.key];
    mine[s == null ? e.value : votes[s]!.entries.reduce((a, b) => b.value > a.value ? b : a).key]!.add(e.key);
  }
  final routes = <WireRoute>[];
  final stations = <StationAllocation>[];
  for (final c in ctrlIds) {
    final root = nodeOf[c]!;
    final targets = mine[c]!;
    if (targets.isEmpty) continue;
    final tree = <int>{};
    if (options.mode == RoutingMode.shortestPaths) {
      final (_, _, via) = g.dijkstraVia([root]);
      for (final t in targets) {
        var n = nodeOf[t]!;
        while (n != root) {
          final ei = via[n];
          if (ei == null || !tree.add(ei)) break;
          n = g.other(ei, n);
        }
      }
    } else {
      final inTree = <int>{root};
      final left = [...targets];
      while (left.isNotEmpty) {
        final (dist, _, via) = g.dijkstraVia(inTree.toList());
        String? pick;
        for (final t in left) {
          final d = dist[nodeOf[t]!];
          if (d == null) continue;
          if (pick == null || d < dist[nodeOf[pick]!]! - 1e-12) pick = t;
        }
        if (pick == null) break;
        var n = nodeOf[pick]!;
        while (!inTree.contains(n)) {
          inTree.add(n);
          final ei = via[n]!;
          tree.add(ei);
          n = g.other(ei, n);
        }
        left.remove(pick);
      }
    }
    // distances along the tree, for the station order
    final adj = <int, List<int>>{};
    for (final ei in tree) {
      final (a, b, _) = g.edges[ei];
      adj.putIfAbsent(a, () => []).add(ei);
      adj.putIfAbsent(b, () => []).add(ei);
    }
    final along = <int, double>{root: 0};
    // tree edge of every node towards the controller
    final up = <int, int>{};
    final stack = [root];
    while (stack.isNotEmpty) {
      final n = stack.removeLast();
      for (final ei in adj[n] ?? const <int>[]) {
        final m = g.other(ei, n);
        if (along.containsKey(m)) continue;
        along[m] = along[n]! + g.edges[ei].$3;
        up[m] = ei;
        stack.add(m);
      }
    }
    // a head on another part of the trenches than its station's controller
    for (final t in targets) {
      if (stationOfHead.containsKey(t) && !along.containsKey(nodeOf[t]!)) warnings.add('wire_route_unreachable:$t');
    }
    // polylines between branch points
    final visited = <int>{};
    for (final start in [root, ...(adj.keys.toList()..sort())]) {
      if (start != root && (adj[start]?.length ?? 0) == 2) continue;
      for (final first in adj[start] ?? const <int>[]) {
        if (visited.contains(first)) continue;
        final pts = <Pt>[g.nodes[start]];
        var n = start, ei = first;
        while (true) {
          visited.add(ei);
          n = g.other(ei, n);
          pts.add(g.nodes[n]);
          final next = adj[n]!;
          if (n == root || next.length != 2) break;
          final e2 = next[0] == ei ? next[1] : next[0];
          if (visited.contains(e2)) break;
          ei = e2;
        }
        routes.add(WireRoute(controllerId: c, points: pts));
      }
    }
    // stations: zone valves by distance, then the valve-in-head stations by
    // their nearest head, then master valves, then relays
    double routeOf(String t) => along[nodeOf[t]!] ?? 0;
    int byRoute(String a, String b) => routeOf(a) != routeOf(b) ? routeOf(a).compareTo(routeOf(b)) : a.compareTo(b);
    // the conductor of a valve-in-head station: the tree up from its heads
    double conductorOf(Iterable<String> heads) {
      final used = <int>{};
      for (final h in heads) {
        var n = nodeOf[h]!;
        while (n != root) {
          final ei = up[n];
          if (ei == null || !used.add(ei)) break;
          n = g.other(ei, n);
        }
      }
      return used.fold(0.0, (s, ei) => s + g.edges[ei].$3);
    }

    var next = 0;
    for (final kind in StationKind.values) {
      if (kind == StationKind.valveInHead) {
        final byStation = <String, List<String>>{};
        for (final t in targets) {
          if (kindOf[t] == kind && along.containsKey(nodeOf[t]!)) byStation.putIfAbsent(stationOfHead[t]!, () => []).add(t);
        }
        double nearest(String s) => byStation[s]!.map(routeOf).reduce(math.min);
        for (final s in byStation.keys.toList()..sort((a, b) => nearest(a) != nearest(b) ? nearest(a).compareTo(nearest(b)) : a.compareTo(b))) {
          stations.add(StationAllocation(controllerId: c, station: ++next, kind: kind, entityId: s, routeM: conductorOf(byStation[s]!)));
        }
        continue;
      }
      final list = targets.where((t) => kindOf[t] == kind).toList()..sort(byRoute);
      final dedicated = (kind == StationKind.masterValve && !options.masterValveStations) || (kind == StationKind.pumpRelay && !options.pumpRelayStations);
      for (final t in list) {
        stations.add(StationAllocation(controllerId: c, station: dedicated ? 0 : ++next, kind: kind, entityId: t, routeM: routeOf(t)));
      }
    }
  }
  return WireRoutingResult(routes: routes, stations: stations, warnings: warnings);
}

/// The pipe trenches as a graph.
class _TrenchGraph {
  _TrenchGraph(this.tol) : cell = math.max(tol * 20, 10);
  final double tol;
  final double cell;
  final List<(Pt, Pt)> segments = [];
  final Map<(int, int), List<int>> _segGrid = {};
  final Map<int, List<Pt>> _splits = {};
  final List<Pt> nodes = [];
  final Map<(int, int), List<int>> _nodeGrid = {};

  /// (from node, to node, length).
  final List<(int, int, double)> edges = [];

  (int, int) _cellOf(Pt p, double size) => ((p.x / size).floor(), (p.y / size).floor());

  void index() {
    for (var i = 0; i < segments.length; i++) {
      final (a, b) = segments[i];
      final (x0, y0) = _cellOf(Pt(math.min(a.x, b.x) - tol, math.min(a.y, b.y) - tol), cell);
      final (x1, y1) = _cellOf(Pt(math.max(a.x, b.x) + tol, math.max(a.y, b.y) + tol), cell);
      for (var x = x0; x <= x1; x++) {
        for (var y = y0; y <= y1; y++) {
          _segGrid.putIfAbsent((x, y), () => []).add(i);
        }
      }
    }
  }

  Iterable<int> _segmentsNear(Pt p) sync* {
    final (cx, cy) = _cellOf(p, cell);
    final seen = <int>{};
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        for (final i in _segGrid[(cx + dx, cy + dy)] ?? const <int>[]) {
          if (seen.add(i)) yield i;
        }
      }
    }
  }

  /// Splits every segment passing within the tolerance of [p] (not at its
  /// ends) at the nearest point.
  void splitNear(Pt p) {
    for (final i in _segmentsNear(p)) {
      final (a, b) = segments[i];
      final (q, t) = closestPointOnSegment(p, a, b);
      if (q.distanceTo(p) > tol || a.distanceTo(q) <= tol || b.distanceTo(q) <= tol || t <= 0 || t >= 1) continue;
      _splits.putIfAbsent(i, () => []).add(q);
    }
  }

  /// Splits the segment that holds [p] (an exact point on it, from
  /// [nearest]).
  void splitAt(Pt p) {
    for (final i in _segmentsNear(p)) {
      final (a, b) = segments[i];
      if (distanceToSegment(p, a, b) > 1e-9) continue;
      if (a.distanceTo(p) <= tol || b.distanceTo(p) <= tol) return;
      _splits.putIfAbsent(i, () => []).add(p);
      return;
    }
  }

  void splitCrossings() {
    final done = <(int, int)>{};
    for (final list in _segGrid.values) {
      for (var x = 0; x < list.length; x++) {
        for (var y = x + 1; y < list.length; y++) {
          final i = math.min(list[x], list[y]), j = math.max(list[x], list[y]);
          if (!done.add((i, j))) continue;
          final (a, b) = segments[i];
          final (c, d) = segments[j];
          final q = segmentIntersection(a, b, c, d);
          if (q == null) continue;
          for (final (k, s, e) in [(i, a, b), (j, c, d)]) {
            if (s.distanceTo(q) > tol && e.distanceTo(q) > tol) _splits.putIfAbsent(k, () => []).add(q);
          }
        }
      }
    }
  }

  /// The nearest point of the pipes to [p] and its distance (null without
  /// pipes).
  (Pt?, double) nearest(Pt p) {
    Pt? best;
    var bd = double.infinity;
    // the neighbouring cells first, every segment when nothing is near
    for (final pass in [0, 1]) {
      final Iterable<int> cands = pass == 0 ? _segmentsNear(p) : List<int>.generate(segments.length, (i) => i);
      for (final i in cands) {
        final (a, b) = segments[i];
        final (q, _) = closestPointOnSegment(p, a, b);
        final d = q.distanceTo(p);
        if (d < bd - 1e-12) {
          bd = d;
          best = q;
        }
      }
      if (best != null && bd <= cell) break;
    }
    return (best, bd);
  }

  int node(Pt p) {
    final (cx, cy) = _cellOf(p, tol);
    int? best;
    var bd = tol;
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        for (final i in _nodeGrid[(cx + dx, cy + dy)] ?? const <int>[]) {
          final d = nodes[i].distanceTo(p);
          if (d <= bd) {
            bd = d;
            best = i;
          }
        }
      }
    }
    if (best != null) return best;
    nodes.add(p);
    _nodeGrid.putIfAbsent((cx, cy), () => []).add(nodes.length - 1);
    return nodes.length - 1;
  }

  void addEdge(int a, int b) {
    if (a == b) return;
    edges.add((a, b, nodes[a].distanceTo(nodes[b])));
    _adj = null;
  }

  /// The edges of every segment between its split points.
  void build() {
    for (var i = 0; i < segments.length; i++) {
      final (a, b) = segments[i];
      final pts = [a, ...?_splits[i], b];
      final ab = b - a;
      final l2 = ab.dot(ab);
      pts.sort((p, q) => ((p - a).dot(ab) / l2).compareTo((q - a).dot(ab) / l2));
      for (var k = 1; k < pts.length; k++) {
        addEdge(node(pts[k - 1]), node(pts[k]));
      }
    }
  }

  int other(int ei, int n) => edges[ei].$1 == n ? edges[ei].$2 : edges[ei].$1;

  Map<int, List<int>>? _adj;
  Map<int, List<int>> get adjacency {
    final cached = _adj;
    if (cached != null) return cached;
    final adj = <int, List<int>>{};
    for (var i = 0; i < edges.length; i++) {
      adj.putIfAbsent(edges[i].$1, () => []).add(i);
      adj.putIfAbsent(edges[i].$2, () => []).add(i);
    }
    return _adj = adj;
  }

  /// Shortest distances from [sources] and the source that reached each node.
  (Map<int, double>, Map<int, int>) dijkstra(List<int> sources) {
    final (dist, src, _) = dijkstraVia(sources);
    return (dist, src);
  }

  /// Shortest distances from [sources], the source of every node and the
  /// edge that reached it (ties: the lower node and edge index).
  (Map<int, double>, Map<int, int>, Map<int, int>) dijkstraVia(List<int> sources) {
    final adj = adjacency;
    final dist = <int, double>{};
    final src = <int, int>{};
    final via = <int, int>{};
    final queue = SplayTreeSet<(double, int)>((x, y) => x.$1 != y.$1 ? x.$1.compareTo(y.$1) : x.$2.compareTo(y.$2));
    for (final s in sources) {
      dist[s] = 0;
      src[s] = s;
      queue.add((0, s));
    }
    while (queue.isNotEmpty) {
      final (d, n) = queue.first;
      queue.remove(queue.first);
      if (d > dist[n]!) continue;
      for (final ei in adj[n] ?? const <int>[]) {
        final m = other(ei, n);
        final nd = d + edges[ei].$3;
        if (nd < (dist[m] ?? double.infinity) - 1e-12) {
          if (dist.containsKey(m)) queue.remove((dist[m]!, m));
          dist[m] = nd;
          src[m] = src[n]!;
          via[m] = ei;
          queue.add((nd, m));
        }
      }
    }
    return (dist, src, via);
  }
}
