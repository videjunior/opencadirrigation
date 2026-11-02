/// Zone and mainline routing: for every zone a valve (on a given mainline,
/// next to the zone on the side of the point of connection, in a manifold
/// at the point of connection, or where the user put it) and zone pipes
/// joining every head to it as a tree; then a mainline tree from the point
/// of connection (water supply or pump) to every valve. The pipes are
/// polylines with a vertex at every head, so that the network builder
/// connects each head (coincident vertices connect), they keep clear of the
/// heads and valves of the other zones (which would join two zones) and go
/// round buildings and other exclusions; the designer sizes them.
///
/// The zone trees use the Prim–Dijkstra trade-off of Alpert, Hu, Huang,
/// Kahng & Karger (1995, *IEEE Trans. Computer-Aided Design* 14(7)): every
/// head joins the tree where c·(path length from the valve) + (pipe length)
/// is least, c = 0 giving the minimum spanning tree (the least pipe) and
/// c = 1 the shortest-path tree (the least friction to the farthest head);
/// a small c keeps the pipe short without long serpentine paths. An
/// optional bias makes pipes along and across the rows cheaper than
/// diagonal ones, so laterals follow the rows (the rectilinear layout of
/// practice). The mainline is a greedy Steiner tree: the valve nearest to
/// the tree joins it at the nearest point of any pipe, with a tee there
/// (Takahashi & Matsuyama 1980, *Math. Japonica* 24).
library;

import 'dart:math' as math;

import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import 'auto_layout.dart';

/// Where the valves of the zones go.
enum ValvePlacement {
  /// At the zone, by its head nearest to the mainline or to the point of
  /// connection.
  nearZone,

  /// Side by side in a manifold at the point of connection.
  manifold,
}

/// Options of [routeZones].
class RouteOptions {
  RouteOptions({
    this.exclusions = const [],
    this.mainline,
    this.pointOfConnection,
    this.valvePositions,
    this.placement = ValvePlacement.nearZone,
    this.valveOffset = 1.0,
    this.minValveSeparation = 1.5,
    this.pathWeight = 0.25,
    this.direction,
    this.directionBias = 0.15,
    this.neighbours = 10,
    this.clearance = 0.3,
    this.obstacleMargin = 0.5,
    this.boundary,
  });

  /// Polygons the pipes keep out of (buildings, ponds, beds).
  final List<List<Pt>> exclusions;

  /// The lot or field outline: pipes between two points on or inside it
  /// stay inside it (round its re-entrant corners, never across the street
  /// in front of a house built on the lot line), and the valves are placed
  /// inside it or on it. A pipe from a point of connection outside it (a
  /// water meter on the pavement) enters it the short way. Null = no limit.
  final List<Pt>? boundary;

  /// An existing mainline: the valves go on it (the network builder splits
  /// it there) and no new mainline is drawn.
  final List<Pt>? mainline;

  /// Water supply or pump outlet where the new mainline starts.
  final Pt? pointOfConnection;

  /// Valve of every zone given by the user (null entries are placed).
  final List<Pt?>? valvePositions;
  final ValvePlacement placement;

  /// Distance (m) from the zone's nearest head to its valve.
  final double valveOffset;

  /// Least distance (m) between two valves (along the mainline, or in a
  /// manifold).
  final double minValveSeparation;

  /// Prim–Dijkstra trade-off c (0 = least pipe, 1 = shortest paths).
  final double pathWeight;

  /// Direction of the rows (null = no preference).
  final Pt? direction;

  /// Extra cost of a diagonal zone pipe over one along or across the rows
  /// (fraction of its length at 45°).
  final double directionBias;

  /// Candidate pipes from every head to its nearest neighbours.
  final int neighbours;

  /// Zone pipes keep at least this far (m) from the heads and valves of the
  /// other zones (well above the connection tolerance).
  final double clearance;

  /// Detours round exclusions keep this far (m) from them.
  final double obstacleMargin;
}

/// One pipe of the routing.
class RoutedPipe {
  const RoutedPipe(this.points, this.scope, {this.zone = -1});

  /// Vertices: every head and valve on the pipe is a vertex.
  final List<Pt> points;
  final HydraulicScope scope;

  /// Zone index (−1 for the mainline).
  final int zone;

  double get length => polylineLength(points);
}

/// The valve and pipes of one zone.
class RoutedZone {
  RoutedZone({required this.zone, required this.valve, required this.pipes, required this.maxPathLength});
  final int zone;
  final Pt valve;
  final List<RoutedPipe> pipes;

  /// Longest pipe path from the valve to a head (m).
  final double maxPathLength;

  double get length => pipes.fold(0.0, (s, p) => s + p.length);
}

/// Outcome of [routeZones].
class RoutingResult {
  RoutingResult({required this.zones, required this.mainline, required this.messages, required this.crossings});
  final List<RoutedZone> zones;
  final List<RoutedPipe> mainline;

  /// Codes: `route_no_connection` (neither a mainline nor a point of
  /// connection: valves by the zones, no mainline), `route_detour_failed:<zone>`
  /// (a head reached in a straight line through an exclusion),
  /// `route_valve_crowded:<zone>` (no free spot at the minimum separation).
  final List<String> messages;

  /// Pipes of different zones (or of the mainline) crossing without a
  /// junction (the design check warns about them).
  final int crossings;

  double get zonePipeLength => zones.fold(0.0, (s, z) => s + z.length);
  double get mainlineLength => mainline.fold(0.0, (s, p) => s + p.length);

  /// The valves and pipes as entities of [p] (new ids): a zone valve named
  /// [zoneNames] (the zone index when missing) with [valveSpecIds], zone
  /// pipes and mainline pipes sized by the designer unless a spec is given,
  /// buried [depth] metres (the mainline [mainlineDepth], by default as
  /// deep).
  List<Entity> toEntities(Project p, {List<String>? zoneNames, List<String?>? valveSpecIds, String? zonePipeSpecId, String? mainlinePipeSpecId, double depth = 0, double? mainlineDepth}) {
    final out = <Entity>[];
    for (final z in zones) {
      final name = zoneNames != null && z.zone < zoneNames.length ? zoneNames[z.zone] : '${z.zone + 1}';
      final spec = valveSpecIds != null && z.zone < valveSpecIds.length ? valveSpecIds[z.zone] : null;
      out.add(ControlValveEntity(id: p.newId(), position: z.valve, valveSpecId: spec, zoneName: name, name: name));
      for (final pipe in z.pipes) {
        out.add(PipeEntity(id: p.newId(), points: List.of(pipe.points), scope: HydraulicScope.zone, pipeSpecId: zonePipeSpecId, computerSized: zonePipeSpecId == null, depth: depth));
      }
    }
    for (final pipe in mainline) {
      out.add(
        PipeEntity(
          id: p.newId(),
          points: List.of(pipe.points),
          scope: HydraulicScope.mainline,
          pipeSpecId: mainlinePipeSpecId,
          computerSized: mainlinePipeSpecId == null,
          depth: mainlineDepth ?? depth,
        ),
      );
    }
    return out;
  }
}

/// The smallest enabled zone valve of [catalog] whose flow range holds
/// [flow] (m³/s). Out of every range: below every minimum the smallest
/// valve (a few drippers, a small ring), above every maximum the one with
/// the largest range, and in a gap between ranges the valve whose range is
/// nearest (on a log scale). Null without zone valves.
ValveSpec? pickZoneValve(Catalog catalog, double flow) {
  ValveSpec? best, widest, smallest, nearest;
  var nearestGap = double.infinity;
  var below = true;
  bool smaller(ValveSpec v, ValveSpec o) => v.sizeMm < o.sizeMm || (v.sizeMm == o.sizeMm && v.cost < o.cost);
  for (final v in catalog.valves) {
    if (!v.enabled || v.kind != ValveKind.control) continue;
    if (widest == null || v.maxFlow > widest.maxFlow) widest = v;
    if (smallest == null || smaller(v, smallest)) smallest = v;
    if (flow >= v.minFlow - 1e-12) below = false;
    if (flow < v.minFlow - 1e-12 || flow > v.maxFlow + 1e-12) {
      // how far (log ratio) the flow lies outside this valve's range
      final gap = flow > 0 && v.minFlow > 0 && v.maxFlow > 0 ? (flow < v.minFlow ? math.log(v.minFlow / flow) : math.log(flow / v.maxFlow)) : double.infinity;
      if (gap < nearestGap - 1e-12 || (gap <= nearestGap + 1e-12 && nearest != null && smaller(v, nearest))) {
        nearestGap = gap;
        nearest = v;
      }
      continue;
    }
    if (best == null || smaller(v, best)) best = v;
  }
  if (best != null) return best;
  if (below) return smallest;
  if (widest != null && flow > widest.maxFlow + 1e-12) return widest;
  return nearest ?? widest;
}

// ---------------------------------------------------------------- obstacles

/// Exclusions the pipes go round: a segment is blocked when it crosses one
/// (or runs inside it), or when it leaves the [boundary] between two points
/// inside it; detours follow the shortest path through the corners of the
/// exclusions pushed out by a margin, and the re-entrant corners of the
/// boundary pulled in by it (visibility graph). The exclusions are bucketed
/// on a grid, so a segment is tested only against those near it, and a
/// detour is searched among the corners near its two ends first (a lawn
/// with a hundred tree rings has thousands of corners), farther only when
/// no way is found there; the visibility of two corners is computed once.
class _Obstacles {
  _Obstacles(List<List<Pt>> polys, double margin, {List<Pt>? boundary})
    : polys = [
        for (final p in polys)
          if (normalizePolygon(p) case final q when q.length >= 3) q,
      ] {
    final b = boundary == null ? const <Pt>[] : normalizePolygon(boundary);
    this.boundary = b.length >= 3 && polygonArea(b).abs() > 1e-9 ? b : null;
    boxes = [for (final p in this.polys) Bounds.ofPoints(p)];
    var all = Bounds.empty;
    var size = 0.0;
    for (final bb in boxes) {
      all = all.union(bb);
      size += math.max(bb.width, bb.height);
    }
    _origin = all.isEmpty ? Pt.zero : Pt(all.minX, all.minY);
    _cell = all.isEmpty ? 1 : math.max(1e-3, math.max(size / boxes.length, math.max(all.width, all.height) / 256));
    for (var k = 0; k < boxes.length; k++) {
      final bb = boxes[k];
      for (var ix = _ix(bb.minX); ix <= _ix(bb.maxX); ix++) {
        for (var iy = _iy(bb.minY); iy <= _iy(bb.maxY); iy++) {
          (_cells[_key(ix, iy)] ??= []).add(k);
        }
      }
    }
    _stamp = List<int>.filled(this.polys.length, -1);
    for (var k = 0; k < this.polys.length; k++) {
      final poly = this.polys[k];
      final n = poly.length;
      for (var i = 0; i < n; i++) {
        final prev = poly[(i - 1 + n) % n], v = poly[i], next = poly[(i + 1) % n];
        final d1 = (v - prev).normalized, d2 = (next - v).normalized;
        // outward normals of a counter-clockwise polygon point right
        final n1 = Pt(d1.y, -d1.x), n2 = Pt(d2.y, -d2.x);
        var bis = (n1 + n2).normalized;
        if (bis.length == 0) bis = n1;
        final cosHalf = bis.dot(n1);
        final kk = cosHalf > 0.3 ? margin / cosHalf : margin * 3;
        final q = v + bis * kk;
        if (!inside(q) && insideBoundary(q)) _addNode(q, bis);
      }
    }
    final lot = this.boundary;
    if (lot != null) {
      // re-entrant corners of the lot (a right turn of the counter-clockwise
      // outline), pulled in by the margin: the way round them from inside
      final n = lot.length;
      for (var i = 0; i < n; i++) {
        final prev = lot[(i - 1 + n) % n], v = lot[i], next = lot[(i + 1) % n];
        final d1 = (v - prev).normalized, d2 = (next - v).normalized;
        if (d1.cross(d2) >= -1e-9) continue;
        final n1 = d1.perpendicular, n2 = d2.perpendicular; // inward (left) normals
        var bis = (n1 + n2).normalized;
        if (bis.length == 0) bis = n1;
        final cosHalf = bis.dot(n1);
        final q = v + bis * (cosHalf > 0.3 ? margin / cosHalf : margin * 3);
        if (!inside(q) && insideBoundary(q)) _addNode(q, bis);
      }
    }
    final nb = Bounds.ofPoints(nodes);
    _nodeGrid = PointGrid(pointGridCell(nb, nodes.length, minimum: 0.05), origin: nb.isEmpty ? Pt.zero : Pt(nb.minX, nb.minY));
    for (final q in nodes) {
      _nodeGrid.add(q);
    }
    _reach0 = math.max(2 * margin + 1, boxes.isEmpty ? 1.0 : 2 * size / boxes.length);
  }

  final List<List<Pt>> polys;
  late final List<Bounds> boxes;

  /// The lot outline (counter-clockwise), or null.
  late final List<Pt>? boundary;

  final List<Pt> nodes = [];

  /// Direction in which every node stands off its exclusion (or into the
  /// lot, for a corner of the boundary).
  final List<Pt> nodeDirs = [];
  final Map<Pt, int> _nodeIndex = {};
  late final PointGrid _nodeGrid;
  final Map<int, bool> _visible = {};
  late final double _reach0;

  late final Pt _origin;
  late final double _cell;
  final Map<int, List<int>> _cells = {};
  late final List<int> _stamp;
  int _query = 0;

  int _ix(double x) => ((x - _origin.x) / _cell).floor();
  int _iy(double y) => ((y - _origin.y) / _cell).floor();
  static int _key(int ix, int iy) => (ix + 1048576) * 2097152 + (iy + 1048576);

  void _addNode(Pt q, Pt dir) {
    if (_nodeIndex.containsKey(q)) return;
    _nodeIndex[q] = nodes.length;
    nodes.add(q);
    nodeDirs.add(dir);
  }

  bool get isEmpty => polys.isEmpty && boundary == null;

  /// Outward direction of the detour node at [p] (null: not a node).
  Pt? outwardAt(Pt p) {
    final i = _nodeIndex[p];
    return i == null ? null : nodeDirs[i];
  }

  /// Exclusions whose bounds meet [bb].
  Iterable<int> _near(Bounds bb) sync* {
    if (polys.isEmpty) return;
    final x0 = _ix(bb.minX), x1 = _ix(bb.maxX), y0 = _iy(bb.minY), y1 = _iy(bb.maxY);
    _query++;
    if ((x1 - x0 + 1) * (y1 - y0 + 1) > 4 * polys.length + 64) {
      for (var k = 0; k < polys.length; k++) {
        if (boxes[k].intersects(bb)) yield k;
      }
      return;
    }
    final q = _query;
    for (var ix = x0; ix <= x1; ix++) {
      for (var iy = y0; iy <= y1; iy++) {
        for (final k in _cells[_key(ix, iy)] ?? const <int>[]) {
          if (_stamp[k] == q) continue;
          _stamp[k] = q;
          if (boxes[k].intersects(bb)) yield k;
        }
      }
    }
  }

  bool inside(Pt p) {
    for (final k in _near(Bounds(p.x, p.y, p.x, p.y))) {
      if (pointInPolygon(p, polys[k]) && !pointOnPolygonBoundary(p, polys[k], tol: 1e-9)) return true;
    }
    return false;
  }

  /// Whether [p] lies inside the boundary or on it (true without one).
  bool insideBoundary(Pt p) {
    final b = boundary;
    return b == null || pointInPolygon(p, b) || pointOnPolygonBoundary(p, b, tol: 1e-6);
  }

  /// Whether the segment ab, both of its ends inside the boundary or on
  /// it, leaves the boundary.
  bool _leaves(Pt a, Pt b) {
    final lot = boundary;
    if (lot == null || !insideBoundary(a) || !insideBoundary(b)) return false;
    for (var i = 0; i < lot.length; i++) {
      final c = lot[i], d = lot[(i + 1) % lot.length];
      final x = segmentIntersection(a, b, c, d, eps: 1e-12);
      if (x == null) continue;
      if (x.distanceTo(a) < 1e-7 || x.distanceTo(b) < 1e-7 || x.distanceTo(c) < 1e-7 || x.distanceTo(d) < 1e-7) continue;
      return true;
    }
    for (final f in const [0.25, 0.5, 0.75]) {
      if (!insideBoundary(Pt.lerp(a, b, f))) return true;
    }
    return false;
  }

  /// Whether the segment ab passes through an exclusion (or out of the
  /// boundary between two points inside it).
  bool blocked(Pt a, Pt b) {
    if (_leaves(a, b)) return true;
    if (polys.isEmpty) return false;
    final bb = Bounds.ofPoints([a, b]);
    for (final k in _near(bb).toList()) {
      final poly = polys[k];
      for (var i = 0; i < poly.length; i++) {
        final c = poly[i], d = poly[(i + 1) % poly.length];
        final x = segmentIntersection(a, b, c, d, eps: 1e-12);
        if (x == null) continue;
        // touching at an end of ab or at a corner of the exclusion is not crossing
        if (x.distanceTo(a) < 1e-7 || x.distanceTo(b) < 1e-7 || x.distanceTo(c) < 1e-7 || x.distanceTo(d) < 1e-7) continue;
        return true;
      }
      for (final f in const [0.25, 0.5, 0.75]) {
        final m = Pt.lerp(a, b, f);
        if (pointInPolygon(m, poly) && !pointOnPolygonBoundary(m, poly, tol: 1e-7)) return true;
      }
    }
    return false;
  }

  /// Whether nodes [i] and [j] see each other (cached).
  bool _sees(int i, int j) {
    final k = i < j ? i * nodes.length + j : j * nodes.length + i;
    return _visible[k] ??= !blocked(nodes[i], nodes[j]);
  }

  /// Shortest polyline from [a] to [b] round the exclusions (null when
  /// none is found): searched among the nodes near the two ends, in a box
  /// that grows until a way is found or it holds every node.
  List<Pt>? path(Pt a, Pt b) {
    if (!blocked(a, b)) return [a, b];
    if (nodes.isEmpty) return null;
    final all = Bounds.ofPoints(nodes);
    var box = Bounds.ofPoints([a, b]).inflate(_reach0);
    for (var round = 0; round < 24; round++) {
      final c = box.center;
      final half = math.sqrt(box.width * box.width + box.height * box.height) / 2;
      final local = [
        for (final i in _nodeGrid.within(c, half))
          if (box.contains(nodes[i])) i,
      ];
      final covers = box.contains(Pt(all.minX, all.minY)) && box.contains(Pt(all.maxX, all.maxY));
      if (local.length > 4000 && !covers) return null;
      final p = _search(a, b, local);
      if (p != null || covers) return p;
      box = box.inflate(math.max(box.width, box.height) / 2 + _reach0);
    }
    return null;
  }

  /// A* over [a], the nodes [local] and [b].
  List<Pt>? _search(Pt a, Pt b, List<int> local) {
    final m = local.length;
    Pt at(int i) => i < m ? nodes[local[i]] : (i == m ? a : b);
    final dist = List<double>.filled(m + 2, double.infinity);
    final prev = List<int>.filled(m + 2, -1);
    final done = List<bool>.filled(m + 2, false);
    final fromA = <int, bool>{};
    final toB = <int, bool>{};
    bool sees(int u, int v) {
      if (u == m) return fromA[v] ??= !blocked(a, at(v));
      return _sees(local[u], local[v]);
    }

    final heap = _MinHeap();
    dist[m] = 0;
    heap.push(a.distanceTo(b), m);
    while (heap.isNotEmpty) {
      final u = heap.pop();
      if (done[u]) continue;
      done[u] = true;
      if (u == m + 1) break;
      void relax(int v) {
        final d = dist[u] + at(u).distanceTo(at(v));
        if (d < dist[v] - 1e-12) {
          dist[v] = d;
          prev[v] = u;
          heap.push(d + at(v).distanceTo(b), v);
        }
      }

      if (u < m && (toB[u] ??= !blocked(at(u), b))) relax(m + 1);
      for (var v = 0; v < m; v++) {
        if (v == u || done[v]) continue;
        if (sees(u, v)) relax(v);
      }
    }
    if (!dist[m + 1].isFinite) return null;
    final out = <Pt>[];
    for (var v = m + 1; v >= 0; v = prev[v]) {
      out.add(at(v));
      if (v == m) break;
    }
    return out.reversed.toList();
  }
}

/// Binary min-heap of (key, index), ties by the lower index.
class _MinHeap {
  final List<(double, int)> _a = [];
  bool get isNotEmpty => _a.isNotEmpty;
  bool _less((double, int) x, (double, int) y) => x.$1 != y.$1 ? x.$1 < y.$1 : x.$2 < y.$2;

  void push(double key, int i) {
    _a.add((key, i));
    var k = _a.length - 1;
    while (k > 0) {
      final p = (k - 1) >> 1;
      if (!_less(_a[k], _a[p])) break;
      final t = _a[p];
      _a[p] = _a[k];
      _a[k] = t;
      k = p;
    }
  }

  int pop() {
    final top = _a.first;
    final last = _a.removeLast();
    if (_a.isNotEmpty) {
      _a[0] = last;
      var k = 0;
      while (true) {
        final l = 2 * k + 1, r = l + 1;
        var m = k;
        if (l < _a.length && _less(_a[l], _a[m])) m = l;
        if (r < _a.length && _less(_a[r], _a[m])) m = r;
        if (m == k) break;
        final t = _a[m];
        _a[m] = _a[k];
        _a[k] = t;
        k = m;
      }
    }
    return top.$2;
  }
}

// ---------------------------------------------------------------- routing

/// Routes the zones whose heads are [zoneHeads] (see the library comment).
RoutingResult routeZones(List<List<Pt>> zoneHeads, RouteOptions o) {
  final r = ZoneRouter(zoneHeads, o);
  while (r.step()) {}
  return r.result;
}

/// [routeZones] one zone at a time: [step] routes the next zone (the
/// mainline after the last one), so that a caller can show the progress
/// between steps, let the screen paint and stop when the inputs change.
class ZoneRouter {
  ZoneRouter(this.zoneHeads, this.options) : _obstacles = _Obstacles(options.exclusions, math.max(0.05, options.obstacleMargin), boundary: options.boundary) {
    final o = options;
    final all = <Pt>[for (final z in zoneHeads) ...z];
    final b = Bounds.ofPoints([...all, ?o.pointOfConnection, ...?o.mainline]);
    _empty = all.isEmpty || b.isEmpty;
    final cell = _empty ? 1.0 : pointGridCell(b, all.length + zoneHeads.length, minimum: 0.25);
    final origin = _empty ? Pt.zero : Pt(b.minX, b.minY);
    _grid = PointGrid(cell, origin: origin);
    _routed = _Segments(math.max(cell, 1.0), origin);
    _bends = PointGrid(math.max(cell, 0.25), origin: origin);
    if (_empty) return;
    // every head, by zone, for the clearance checks
    for (var z = 0; z < zoneHeads.length; z++) {
      for (final h in zoneHeads[z]) {
        _grid.add(h);
        _owner.add(z);
      }
    }
    _valves = _placeValves(zoneHeads, o, _obstacles, _grid, _owner, _messages);
    for (var z = 0; z < _valves.length; z++) {
      _grid.add(_valves[z]);
      _owner.add(z);
    }
  }

  final List<List<Pt>> zoneHeads;
  final RouteOptions options;
  final _Obstacles _obstacles;
  late final bool _empty;
  late final PointGrid _grid;
  final List<int> _owner = [];
  final List<String> _messages = [];
  List<Pt> _valves = const [];
  final List<RoutedZone> _zones = [];

  // pipes routed so far: later zones go round them where they can
  late final _Segments _routed;

  // the bends of the pipes routed so far (detours round an exclusion, a
  // dogleg round a head): a later zone never puts a vertex of its own on
  // one, since coincident vertices connect and would join the two zones
  late final PointGrid _bends;
  final List<int> _bendOwner = [];
  int _next = 0;
  List<RoutedPipe>? _mainline;

  /// Zones routed so far.
  int get routed => _next;

  /// Routes the next zone, or the mainline after the last one; false once
  /// everything is routed.
  bool step() {
    if (_empty || _mainline != null) return false;
    final o = options;
    while (_next < zoneHeads.length && zoneHeads[_next].isEmpty) {
      _next++;
    }
    if (_next < zoneHeads.length) {
      final z = _next++;
      final rz = _routeZone(z, zoneHeads[z], _valves[z], o, _obstacles, _grid, _owner, _messages, _routed, _bends, _bendOwner);
      final own = {...zoneHeads[z], _valves[z]};
      for (final pipe in rz.pipes) {
        for (var i = 1; i < pipe.points.length; i++) {
          _routed.add(pipe.points[i - 1], pipe.points[i], z);
        }
        for (final q in pipe.points) {
          if (own.contains(q)) continue;
          _bends.add(q);
          _bendOwner.add(z);
        }
      }
      _zones.add(rz);
      return true;
    }
    _mainline = o.mainline == null && o.pointOfConnection != null ? _mainlineTree(o.pointOfConnection!, [for (final z in _zones) z.valve], _obstacles) : <RoutedPipe>[];
    return false;
  }

  /// The routing (complete once [step] returned false).
  RoutingResult get result {
    if (_empty) return RoutingResult(zones: const [], mainline: const [], messages: const [], crossings: 0);
    final mainline = _mainline ?? const <RoutedPipe>[];
    return RoutingResult(zones: _zones, mainline: mainline, messages: _messages, crossings: _crossings([for (final z in _zones) ...z.pipes, ...mainline]));
  }
}

/// A mainline tree from [pointOfConnection] to [valves] (or to pivot
/// points, or to the valves of blocks made by the block generator) round
/// [exclusions]: the greedy Steiner tree of [routeZones].
List<RoutedPipe> routeMainline(Pt pointOfConnection, List<Pt> valves, {List<List<Pt>> exclusions = const [], double obstacleMargin = 0.5, List<Pt>? boundary}) =>
    _mainlineTree(pointOfConnection, valves, _Obstacles(exclusions, math.max(0.05, obstacleMargin), boundary: boundary));

/// Valve of every zone.
List<Pt> _placeValves(List<List<Pt>> zoneHeads, RouteOptions o, _Obstacles obstacles, PointGrid heads, List<int> owner, List<String> messages) {
  final n = zoneHeads.length;
  final out = List<Pt>.filled(n, Pt.zero);
  final given = List<bool>.filled(n, false);
  for (var z = 0; z < n; z++) {
    final v = o.valvePositions != null && z < o.valvePositions!.length ? o.valvePositions![z] : null;
    if (v != null) {
      out[z] = v;
      given[z] = true;
    }
  }
  Pt nearestHead(List<Pt> hs, Pt Function(Pt) target) {
    var best = hs.first;
    var bd = double.infinity;
    for (final h in hs) {
      final d = target(h).distanceTo(h);
      if (d < bd - 1e-12) {
        bd = d;
        best = h;
      }
    }
    return best;
  }

  final main = o.mainline;
  if (main != null && main.length >= 2) {
    // on the mainline, at the point nearest to the zone, spread apart
    final total = polylineLength(main);
    final stations = <(double, int)>[];
    for (var z = 0; z < n; z++) {
      if (given[z] || zoneHeads[z].isEmpty) continue;
      final h = nearestHead(zoneHeads[z], (h) => polylineStationOf(main, h).$2);
      stations.add((polylineStationOf(main, h).$1, z));
    }
    stations.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
    final sep = math.max(0.0, o.minValveSeparation);
    final s = [for (final st in stations) st.$1];
    for (var i = 1; i < s.length; i++) {
      if (s[i] < s[i - 1] + sep) s[i] = s[i - 1] + sep;
    }
    if (s.isNotEmpty && s.last > total) {
      s[s.length - 1] = total;
      for (var i = s.length - 2; i >= 0; i--) {
        if (s[i] > s[i + 1] - sep) s[i] = s[i + 1] - sep;
      }
      if (s.first < 0) messages.add('route_valve_crowded:${stations.first.$2}');
    }
    // a valve on another zone's head would join the two zones: slide it
    // along the mainline until it is clear
    final clear = math.max(o.clearance, 0.05) * 2;
    for (var i = 0; i < stations.length; i++) {
      final z = stations[i].$2;
      var at = s[i].clamp(0.0, total);
      for (var k = 0; k < 40; k++) {
        final q = pointAlongPolyline(main, at);
        final h = heads.nearest(q, maxDistance: clear, skip: (j) => owner[j] == z);
        if (h < 0) break;
        at = (s[i] + (k.isEven ? 1 : -1) * ((k ~/ 2) + 1) * clear).clamp(0.0, total);
      }
      out[z] = pointAlongPolyline(main, at);
    }
    return out;
  }
  final poc = o.pointOfConnection;
  if (poc == null) messages.add('route_no_connection');
  final placed = <Pt>[
    for (var z = 0; z < n; z++)
      if (given[z]) out[z],
  ];
  // valves stay on the lot (a manifold at a point of connection outside it
  // stays by that point)
  final keepIn = poc == null || o.placement != ValvePlacement.manifold || obstacles.insideBoundary(poc);
  bool free(Pt p, int zone) {
    if (obstacles.inside(p)) return false;
    if (keepIn && !obstacles.insideBoundary(p)) return false;
    for (final q in placed) {
      if (q.distanceTo(p) < o.minValveSeparation - 1e-9) return false;
    }
    final i = heads.nearest(p, maxDistance: math.max(o.clearance, 0.05) * 2);
    return i < 0;
  }

  if (poc != null && o.placement == ValvePlacement.manifold) {
    // a row of valves at the point of connection, across the way to the site
    final c = Bounds.ofPoints([for (final z in zoneHeads) ...z]).center;
    final away = (c - poc).length > 0 ? (c - poc).normalized : const Pt(1, 0);
    final across = away.perpendicular;
    final base = poc + away * math.max(o.valveOffset, o.minValveSeparation);
    var k = 0;
    for (var z = 0; z < n; z++) {
      if (given[z] || zoneHeads[z].isEmpty) continue;
      Pt p;
      var guard = 0;
      do {
        final side = k.isEven ? 1 : -1;
        p = base + across * (side * ((k + 1) ~/ 2) * o.minValveSeparation);
        k++;
      } while (!free(p, z) && ++guard < 200);
      out[z] = p;
      placed.add(p);
    }
    return out;
  }
  for (var z = 0; z < n; z++) {
    if (given[z] || zoneHeads[z].isEmpty) continue;
    final hs = zoneHeads[z];
    final h = poc != null ? nearestHead(hs, (_) => poc) : hs.reduce((a, b) => a.x < b.x || (a.x == b.x && a.y < b.y) ? a : b);
    final toward = poc != null && poc.distanceTo(h) > 1e-9 ? (poc - h).normalized : const Pt(-1, 0);
    Pt? spot;
    for (final turn in const [0.0, 30.0, -30.0, 60.0, -60.0, 90.0, -90.0, 120.0, -120.0, 150.0, -150.0, 180.0]) {
      for (final f in const [1.0, 1.5, 2.0, 3.0]) {
        final p = h + toward.rotate(degToRad(turn)) * (o.valveOffset * f);
        if (free(p, z)) {
          spot = p;
          break;
        }
      }
      if (spot != null) break;
    }
    if (spot == null) messages.add('route_valve_crowded:$z');
    out[z] = spot ?? h + toward * o.valveOffset;
    placed.add(out[z]);
  }
  return out;
}

/// Segments of the pipes routed so far, bucketed for crossing tests.
class _Segments {
  _Segments(this.cell, this.origin);
  final double cell;
  final Pt origin;
  final List<(Pt, Pt, int)> _segs = [];
  final Map<int, List<int>> _buckets = {};

  int _ix(double x) => ((x - origin.x) / cell).floor();
  int _iy(double y) => ((y - origin.y) / cell).floor();

  Iterable<int> _keys(Pt a, Pt b) sync* {
    final x0 = _ix(math.min(a.x, b.x)), x1 = _ix(math.max(a.x, b.x));
    final y0 = _iy(math.min(a.y, b.y)), y1 = _iy(math.max(a.y, b.y));
    // a very long segment goes in one bucket every query looks at
    if ((x1 - x0 + 1) * (y1 - y0 + 1) > 4096) {
      yield -1;
      return;
    }
    for (var ix = x0; ix <= x1; ix++) {
      for (var iy = y0; iy <= y1; iy++) {
        yield (ix + 1048576) * 2097152 + (iy + 1048576);
      }
    }
  }

  void add(Pt a, Pt b, int zone) {
    final i = _segs.length;
    _segs.add((a, b, zone));
    for (final k in _keys(a, b)) {
      (_buckets[k] ??= []).add(i);
    }
  }

  /// Segments of other zones that ab crosses in their interiors.
  int crossings(Pt a, Pt b, int zone) {
    final seen = <int>{};
    var n = 0;
    for (final k in [..._keys(a, b), -1]) {
      for (final i in _buckets[k] ?? const <int>[]) {
        if (!seen.add(i)) continue;
        final (c, d, z) = _segs[i];
        if (z == zone) continue;
        final x = segmentIntersection(a, b, c, d);
        if (x == null || x.distanceTo(a) < 1e-6 || x.distanceTo(b) < 1e-6 || x.distanceTo(c) < 1e-6 || x.distanceTo(d) < 1e-6) continue;
        n++;
      }
    }
    return n;
  }
}

/// A candidate pipe of a zone tree.
class _Edge {
  _Edge(this.to, this.path, this.cost) : length = polylineLength(path);
  final int to;
  final List<Pt> path;
  final double cost, length;
}

/// The zone tree from the valve (node 0) to the heads (nodes 1…).
RoutedZone _routeZone(
  int zone,
  List<Pt> heads,
  Pt valve,
  RouteOptions o,
  _Obstacles obstacles,
  PointGrid grid,
  List<int> owner,
  List<String> messages,
  _Segments routed,
  PointGrid bends,
  List<int> bendOwner,
) {
  final nodes = [valve, ...heads];
  final n = nodes.length;
  final b = Bounds.ofPoints(nodes);
  final local = PointGrid(pointGridCell(b, n, minimum: 0.25), origin: Pt(b.minX, b.minY));
  for (final p in nodes) {
    local.add(p);
  }
  final dir = o.direction != null && o.direction!.length > 0 ? o.direction!.normalized : null;
  final clear = math.max(o.clearance, 0.06);
  // a bend of another zone's pipe within twice the clearance of [v]
  bool bendTaken(Pt v) => bends.nearest(v, maxDistance: 2 * clear, skip: (j) => bendOwner[j] == zone) >= 0;
  // a straight pipe must keep clear of the other zones' heads and valves
  bool foreignNear(Pt a, Pt c) {
    final mid = Pt.lerp(a, c, 0.5);
    for (final i in grid.within(mid, a.distanceTo(c) / 2 + clear)) {
      if (owner[i] == zone) continue;
      if (distanceToSegment(grid.points[i], a, c) < clear) return true;
    }
    return false;
  }

  double weight(List<Pt> path) {
    var w = 0.0;
    for (var i = 1; i < path.length; i++) {
      final d = path[i] - path[i - 1];
      final len = d.length;
      var f = 1.0;
      if (dir != null && len > 0) f += o.directionBias * (2 * d.cross(dir) * d.dot(dir) / (len * len)).abs();
      // crossing another zone's pipe costs as much as a long detour
      final crossings = routed.crossings(path[i - 1], path[i], zone);
      w += len * f + crossings * (2 * len + 5);
    }
    return w;
  }

  // a dogleg round the foreign point nearest to the middle of ac
  List<Pt>? dogleg(Pt a, Pt c) {
    final mid = Pt.lerp(a, c, 0.5);
    var best = -1;
    var bd = double.infinity;
    for (final i in grid.within(mid, a.distanceTo(c) / 2 + clear)) {
      if (owner[i] == zone) continue;
      final d = distanceToSegment(grid.points[i], a, c);
      if (d < clear && d < bd) {
        bd = d;
        best = i;
      }
    }
    if (best < 0) return [a, c];
    final f = grid.points[best];
    final along = (c - a).normalized;
    var side = along.perpendicular;
    if ((f - a).dot(side) > 0) side = -side;
    for (final k in const [2.0, 4.0, 8.0]) {
      for (final sgn in const [1.0, -1.0]) {
        final m = f + side * (clear * k * sgn);
        if (bendTaken(m)) continue;
        if (!foreignNear(a, m) && !foreignNear(m, c) && !obstacles.blocked(a, m) && !obstacles.blocked(m, c)) return [a, m, c];
      }
    }
    return null;
  }

  List<Pt>? connect(Pt a, Pt c) {
    if (!obstacles.blocked(a, c)) {
      if (!foreignNear(a, c)) return [a, c];
      return dogleg(a, c);
    }
    final p = obstacles.path(a, c);
    if (p == null) return null;
    // a detour corner another zone bends at already: this zone bends a
    // little farther out
    final q = List.of(p);
    for (var i = 1; i + 1 < q.length; i++) {
      if (!bendTaken(q[i])) continue;
      final away = obstacles.outwardAt(p[i]) ?? (q[i] - Pt.lerp(q[i - 1], q[i + 1], 0.5)).normalized;
      if (away.length == 0) return null;
      Pt? moved;
      for (var k = 1; k <= 8 && moved == null; k++) {
        final m = q[i] + away * (2 * clear * k);
        if (bendTaken(m) || obstacles.inside(m) || !obstacles.insideBoundary(m) || obstacles.blocked(q[i - 1], m) || obstacles.blocked(m, q[i + 1])) continue;
        moved = m;
      }
      if (moved == null) return null;
      q[i] = moved;
    }
    for (var i = 1; i < q.length; i++) {
      if (foreignNear(q[i - 1], q[i])) return null;
    }
    return q;
  }

  final k = math.max(2, o.neighbours);
  final edges = List.generate(n, (_) => <_Edge>[]);
  final seen = <int>{};
  for (var i = 0; i < n; i++) {
    for (final j in local.kNearest(nodes[i], k + 1, skip: (j) => j == i)) {
      final key = i < j ? i * n + j : j * n + i;
      if (!seen.add(key)) continue;
      final path = connect(nodes[i], nodes[j]);
      if (path == null) continue;
      final w = weight(path);
      edges[i].add(_Edge(j, path, w));
      edges[j].add(_Edge(i, path.reversed.toList(), w));
    }
  }
  // Prim–Dijkstra from the valve
  final parent = List<int>.filled(n, -1);
  final parentPath = List<List<Pt>?>.filled(n, null);
  final pathLen = List<double>.filled(n, 0);
  final inTree = List<bool>.filled(n, false);
  final heap = _Heap();
  void grow(int u) {
    inTree[u] = true;
    for (final e in edges[u]) {
      if (!inTree[e.to]) heap.push(o.pathWeight * pathLen[u] + e.cost, e.to, u, e);
    }
  }

  var reached = 0;
  void run() {
    while (heap.isNotEmpty) {
      final (_, v, u, e) = heap.pop();
      if (inTree[v]) continue;
      parent[v] = u;
      parentPath[v] = e.path;
      pathLen[v] = pathLen[u] + e.length;
      reached++;
      grow(v);
    }
  }

  reached = 1;
  grow(0);
  run();
  // heads the candidates did not reach: join the nearest pair that can be
  // joined (round the exclusions and the other zones' heads), then grow on
  var guard = 0;
  while (reached < n && guard++ < n) {
    final pairs = <(double, int, int)>[
      for (var v = 0; v < n; v++)
        if (!inTree[v])
          for (var u = 0; u < n; u++)
            if (inTree[u]) (nodes[u].distanceTo(nodes[v]), u, v),
    ]..sort((x, y) => x.$1 != y.$1 ? x.$1.compareTo(y.$1) : (x.$3 != y.$3 ? x.$3.compareTo(y.$3) : x.$2.compareTo(y.$2)));
    if (pairs.isEmpty) break;
    _Edge? e;
    for (final (_, u, v) in pairs.take(64)) {
      final path = connect(nodes[u], nodes[v]);
      if (path != null) {
        e = _Edge(v, path, weight(path));
        heap.push(0, v, u, e);
        break;
      }
    }
    if (e == null) {
      final (_, u, v) = pairs.first;
      final path = obstacles.path(nodes[u], nodes[v]) ?? [nodes[u], nodes[v]];
      if (!messages.contains('route_detour_failed:$zone')) messages.add('route_detour_failed:$zone');
      heap.push(0, v, u, _Edge(v, path, weight(path)));
    }
    run();
  }
  // the tree as pipes: chains between branch points
  final children = List.generate(n, (_) => <int>[]);
  for (var v = 1; v < n; v++) {
    if (parent[v] >= 0) children[parent[v]].add(v);
  }
  final pipes = <RoutedPipe>[];
  final starts = <int>[0];
  while (starts.isNotEmpty) {
    final s = starts.removeLast();
    for (final c in children[s]) {
      final pts = <Pt>[nodes[s]];
      var cur = c;
      while (true) {
        final seg = parentPath[cur]!;
        pts.addAll(seg.skip(1));
        if (children[cur].length != 1) break;
        cur = children[cur].first;
      }
      pipes.add(RoutedPipe(_dedupe(pts), HydraulicScope.zone, zone: zone));
      if (children[cur].length > 1) starts.add(cur);
    }
  }
  return RoutedZone(zone: zone, valve: valve, pipes: pipes, maxPathLength: pathLen.fold(0.0, math.max));
}

List<Pt> _dedupe(List<Pt> pts) {
  final out = <Pt>[];
  for (final p in pts) {
    if (out.isEmpty || out.last.distanceTo(p) > 1e-9) out.add(p);
  }
  return out;
}

/// Binary min-heap of (key, node, parent, edge), ties by node then parent.
class _Heap {
  final List<(double, int, int, _Edge)> _a = [];
  bool get isNotEmpty => _a.isNotEmpty;

  bool _less((double, int, int, _Edge) x, (double, int, int, _Edge) y) => x.$1 != y.$1 ? x.$1 < y.$1 : (x.$2 != y.$2 ? x.$2 < y.$2 : x.$3 < y.$3);

  void push(double key, int node, int parent, _Edge e) {
    _a.add((key, node, parent, e));
    var i = _a.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (!_less(_a[i], _a[p])) break;
      final t = _a[p];
      _a[p] = _a[i];
      _a[i] = t;
      i = p;
    }
  }

  (double, int, int, _Edge) pop() {
    final top = _a.first;
    final last = _a.removeLast();
    if (_a.isNotEmpty) {
      _a[0] = last;
      var i = 0;
      while (true) {
        final l = 2 * i + 1, r = l + 1;
        var m = i;
        if (l < _a.length && _less(_a[l], _a[m])) m = l;
        if (r < _a.length && _less(_a[r], _a[m])) m = r;
        if (m == i) break;
        final t = _a[m];
        _a[m] = _a[i];
        _a[i] = t;
        i = m;
      }
    }
    return top;
  }
}

/// Greedy Steiner tree from [poc] to [valves]: the valve nearest to the
/// tree joins it at the nearest point of any of its pipes (round the
/// exclusions); the tree is returned as chains between its branch points.
List<RoutedPipe> _mainlineTree(Pt poc, List<Pt> valves, _Obstacles obstacles) {
  if (valves.isEmpty) return const [];
  // the tree as segments (a split segment dies and leaves two halves);
  // every valve keeps the nearest point of the tree, updated as it grows
  final segs = <(Pt, Pt)>[];
  final alive = <bool>[];
  final n = valves.length;
  final bestD = [for (final v in valves) v.distanceTo(poc)];
  final bestAt = List<Pt>.filled(n, poc);
  final bestSeg = List<int>.filled(n, -1);
  final joined = List<bool>.filled(n, false);
  var checked = 0;
  void update() {
    for (var i = 0; i < n; i++) {
      if (joined[i]) continue;
      final v = valves[i];
      for (var s = checked; s < segs.length; s++) {
        if (!alive[s]) continue;
        var (cp, _) = closestPointOnSegment(v, segs[s].$1, segs[s].$2);
        // an end of the pipe exactly (a + ab·1 is not b to the last bit)
        if (cp.distanceTo(segs[s].$1) <= 1e-6) cp = segs[s].$1;
        if (cp.distanceTo(segs[s].$2) <= 1e-6) cp = segs[s].$2;
        final dd = cp.distanceTo(v);
        if (dd < bestD[i] - 1e-9) {
          bestD[i] = dd;
          bestAt[i] = cp;
          bestSeg[i] = s;
        }
      }
    }
    checked = segs.length;
  }

  void addSeg(Pt a, Pt c) {
    if (a.distanceTo(c) <= 1e-9) return;
    segs.add((a, c));
    alive.add(true);
  }

  for (var round = 0; round < n; round++) {
    var bi = -1;
    for (var i = 0; i < n; i++) {
      if (!joined[i] && (bi < 0 || bestD[i] < bestD[bi] - 1e-9)) bi = i;
    }
    if (bi < 0) break;
    final v = valves[bi];
    var at = bestAt[bi];
    var seg = bestSeg[bi];
    var path = obstacles.path(at, v);
    if (path == null) {
      // no way round from that point: join at the nearest tree vertex that
      // has one
      final verts = <Pt>{
        poc,
        for (var k = 0; k < segs.length; k++)
          if (alive[k]) ...[segs[k].$1, segs[k].$2],
      }.toList()..sort((a, b) => a.distanceTo(v).compareTo(b.distanceTo(v)));
      for (final c in verts) {
        final pth = obstacles.path(c, v);
        if (pth != null) {
          at = c;
          path = pth;
          seg = -1;
          break;
        }
      }
    }
    path ??= [at, v];
    joined[bi] = true;
    if (seg >= 0 && at != segs[seg].$1 && at != segs[seg].$2) {
      final (a, c) = segs[seg];
      alive[seg] = false;
      addSeg(a, at);
      addSeg(at, c);
      // valves whose nearest point was on the dead segment find it again
      // on its halves
      for (var i = 0; i < n; i++) {
        if (!joined[i] && bestSeg[i] == seg) {
          bestD[i] = valves[i].distanceTo(poc);
          bestAt[i] = poc;
          bestSeg[i] = -1;
          for (var k = 0; k < segs.length; k++) {
            if (!alive[k]) continue;
            var (cp, _) = closestPointOnSegment(valves[i], segs[k].$1, segs[k].$2);
            if (cp.distanceTo(segs[k].$1) <= 1e-6) cp = segs[k].$1;
            if (cp.distanceTo(segs[k].$2) <= 1e-6) cp = segs[k].$2;
            final dd = cp.distanceTo(valves[i]);
            if (dd < bestD[i] - 1e-9) {
              bestD[i] = dd;
              bestAt[i] = cp;
              bestSeg[i] = k;
            }
          }
        }
      }
    }
    for (var k = 1; k < path.length; k++) {
      addSeg(path[k - 1], path[k]);
    }
    update();
  }
  // chains: from the point of connection, through vertices of degree two
  final adj = <Pt, List<Pt>>{};
  for (var k = 0; k < segs.length; k++) {
    if (!alive[k]) continue;
    final (a, c) = segs[k];
    (adj[a] ??= []).add(c);
    (adj[c] ??= []).add(a);
  }
  final used = <String>{};
  String key(Pt a, Pt c) => '${a.x},${a.y}|${c.x},${c.y}';
  final out = <RoutedPipe>[];
  final stack = <Pt>[poc];
  final visited = <Pt>{};
  while (stack.isNotEmpty) {
    final s = stack.removeLast();
    if (!visited.add(s)) continue;
    for (final nb in adj[s] ?? const <Pt>[]) {
      if (used.contains(key(s, nb))) continue;
      final pts = <Pt>[s];
      var prev = s, cur = nb;
      while (true) {
        used.add(key(prev, cur));
        used.add(key(cur, prev));
        pts.add(cur);
        final next = (adj[cur] ?? const <Pt>[]).where((x) => !used.contains(key(cur, x))).toList();
        if ((adj[cur]?.length ?? 0) != 2 || next.isEmpty) break;
        prev = cur;
        cur = next.first;
      }
      out.add(RoutedPipe(_dedupe(pts), HydraulicScope.mainline));
      stack.add(cur);
    }
  }
  return out;
}

/// Pairs of pipes of the same scope (zone pipes of different zones, or two
/// mainline pipes) whose segments cross in their interiors.
int _crossings(List<RoutedPipe> pipes) {
  final segs = <(Pt, Pt, int, int)>[];
  for (var p = 0; p < pipes.length; p++) {
    final pts = pipes[p].points;
    for (var i = 1; i < pts.length; i++) {
      segs.add((pts[i - 1], pts[i], p, pipes[p].scope == HydraulicScope.mainline ? -1 : pipes[p].zone));
    }
  }
  if (segs.length < 2) return 0;
  final b = Bounds.ofPoints([
    for (final s in segs) ...[s.$1, s.$2],
  ]);
  final avg = segs.fold(0.0, (s, e) => s + e.$1.distanceTo(e.$2)) / segs.length;
  final cell = math.max(avg, math.max(b.width, b.height) / 512);
  final buckets = <int, List<int>>{};
  int keyOf(int ix, int iy) => (ix + 1048576) * 2097152 + (iy + 1048576);
  for (var s = 0; s < segs.length; s++) {
    final sb = Bounds.ofPoints([segs[s].$1, segs[s].$2]);
    for (var ix = ((sb.minX - b.minX) / cell).floor(); ix <= ((sb.maxX - b.minX) / cell).floor(); ix++) {
      for (var iy = ((sb.minY - b.minY) / cell).floor(); iy <= ((sb.maxY - b.minY) / cell).floor(); iy++) {
        (buckets[keyOf(ix, iy)] ??= []).add(s);
      }
    }
  }
  final pairs = <int>{};
  for (final list in buckets.values) {
    for (var x = 0; x < list.length; x++) {
      for (var y = x + 1; y < list.length; y++) {
        final s = segs[list[x]], t = segs[list[y]];
        if (s.$3 == t.$3) continue;
        // pipes of one zone touching are a junction, not a crossing; a zone
        // pipe over the mainline is not connected either way
        if (s.$4 == t.$4 && s.$4 >= 0) continue;
        if ((s.$4 < 0) != (t.$4 < 0)) continue;
        final p = segmentIntersection(s.$1, s.$2, t.$1, t.$2);
        if (p == null) continue;
        if (p.distanceTo(s.$1) < 1e-6 || p.distanceTo(s.$2) < 1e-6 || p.distanceTo(t.$1) < 1e-6 || p.distanceTo(t.$2) < 1e-6) continue;
        pairs.add(math.min(s.$3, t.$3) * pipes.length + math.max(s.$3, t.$3));
      }
    }
  }
  return pairs.length;
}
