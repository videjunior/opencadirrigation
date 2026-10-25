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
  });

  /// Polygons the pipes keep out of (buildings, ponds, beds).
  final List<List<Pt>> exclusions;

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
  /// pipes and mainline pipes sized by the designer unless a spec is given.
  List<Entity> toEntities(Project p, {List<String>? zoneNames, List<String?>? valveSpecIds, String? zonePipeSpecId, String? mainlinePipeSpecId, double depth = 0}) {
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
      out.add(PipeEntity(id: p.newId(), points: List.of(pipe.points), scope: HydraulicScope.mainline, pipeSpecId: mainlinePipeSpecId, computerSized: mainlinePipeSpecId == null, depth: depth));
    }
    return out;
  }
}

/// The smallest enabled zone valve of [catalog] whose flow range holds
/// [flow] (m³/s); else the one with the largest range. Null without zone
/// valves.
ValveSpec? pickZoneValve(Catalog catalog, double flow) {
  ValveSpec? best, widest;
  for (final v in catalog.valves) {
    if (!v.enabled || v.kind != ValveKind.control) continue;
    if (widest == null || v.maxFlow > widest.maxFlow) widest = v;
    if (flow < v.minFlow - 1e-12 || flow > v.maxFlow + 1e-12) continue;
    if (best == null || v.sizeMm < best.sizeMm || (v.sizeMm == best.sizeMm && v.cost < best.cost)) best = v;
  }
  return best ?? widest;
}

// ---------------------------------------------------------------- obstacles

/// Exclusions the pipes go round: a segment is blocked when it crosses one
/// (or runs inside it); detours follow the shortest path through the
/// corners of the exclusions pushed out by a margin (visibility graph).
class _Obstacles {
  _Obstacles(List<List<Pt>> polys, double margin) : polys = [for (final p in polys) if (normalizePolygon(p) case final q when q.length >= 3) q] {
    for (final poly in this.polys) {
      final n = poly.length;
      for (var i = 0; i < n; i++) {
        final prev = poly[(i - 1 + n) % n], v = poly[i], next = poly[(i + 1) % n];
        final d1 = (v - prev).normalized, d2 = (next - v).normalized;
        // outward normals of a counter-clockwise polygon point right
        final n1 = Pt(d1.y, -d1.x), n2 = Pt(d2.y, -d2.x);
        var bis = (n1 + n2).normalized;
        if (bis.length == 0) bis = n1;
        final cosHalf = bis.dot(n1);
        final k = cosHalf > 0.3 ? margin / cosHalf : margin * 3;
        final q = v + bis * k;
        if (!inside(q)) nodes.add(q);
      }
    }
  }

  final List<List<Pt>> polys;
  final List<Pt> nodes = [];
  List<List<int>>? _vis;

  bool get isEmpty => polys.isEmpty;

  bool inside(Pt p) => polys.any((poly) => pointInPolygon(p, poly) && !pointOnPolygonBoundary(p, poly, tol: 1e-9));

  /// Whether the segment ab passes through an exclusion.
  bool blocked(Pt a, Pt b) {
    if (polys.isEmpty) return false;
    final bb = Bounds.ofPoints([a, b]);
    for (final poly in polys) {
      if (!bb.intersects(Bounds.ofPoints(poly))) continue;
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

  /// Shortest polyline from [a] to [b] round the exclusions (null when
  /// none is found).
  List<Pt>? path(Pt a, Pt b) {
    if (!blocked(a, b)) return [a, b];
    if (nodes.isEmpty) return null;
    final vis = _vis ??= [
      for (var i = 0; i < nodes.length; i++) [for (var j = 0; j < nodes.length; j++) if (i != j && !blocked(nodes[i], nodes[j])) j],
    ];
    final n = nodes.length;
    // Dijkstra over a, the nodes and b (n, n + 1 are a and b)
    Pt at(int i) => i < n ? nodes[i] : (i == n ? a : b);
    final fromA = [for (var j = 0; j < n; j++) if (!blocked(a, nodes[j])) j];
    final toB = {for (var j = 0; j < n; j++) if (!blocked(nodes[j], b)) j};
    final dist = List<double>.filled(n + 2, double.infinity);
    final prev = List<int>.filled(n + 2, -1);
    final done = List<bool>.filled(n + 2, false);
    dist[n] = 0;
    for (var iter = 0; iter < n + 2; iter++) {
      var u = -1;
      for (var i = 0; i < n + 2; i++) {
        if (!done[i] && dist[i].isFinite && (u < 0 || dist[i] < dist[u])) u = i;
      }
      if (u < 0 || u == n + 1) break;
      done[u] = true;
      final next = u == n ? fromA : vis[u];
      for (final v in next) {
        final d = dist[u] + at(u).distanceTo(at(v));
        if (d < dist[v] - 1e-12) {
          dist[v] = d;
          prev[v] = u;
        }
      }
      if (u < n && toB.contains(u)) {
        final d = dist[u] + at(u).distanceTo(b);
        if (d < dist[n + 1] - 1e-12) {
          dist[n + 1] = d;
          prev[n + 1] = u;
        }
      }
    }
    if (!dist[n + 1].isFinite) return null;
    final out = <Pt>[];
    for (var v = n + 1; v >= 0; v = prev[v]) {
      out.add(at(v));
      if (v == n) break;
    }
    return out.reversed.toList();
  }
}

// ---------------------------------------------------------------- routing

/// Routes the zones whose heads are [zoneHeads] (see the library comment).
RoutingResult routeZones(List<List<Pt>> zoneHeads, RouteOptions o) {
  final messages = <String>[];
  final obstacles = _Obstacles(o.exclusions, math.max(0.05, o.obstacleMargin));
  final all = <Pt>[for (final z in zoneHeads) ...z];
  final b = Bounds.ofPoints([...all, ?o.pointOfConnection, ...?o.mainline]);
  if (all.isEmpty || b.isEmpty) return RoutingResult(zones: const [], mainline: const [], messages: const [], crossings: 0);
  final cell = pointGridCell(b, all.length + zoneHeads.length, minimum: 0.25);
  // every head, by zone, for the clearance checks
  final grid = PointGrid(cell, origin: Pt(b.minX, b.minY));
  final owner = <int>[];
  for (var z = 0; z < zoneHeads.length; z++) {
    for (final h in zoneHeads[z]) {
      grid.add(h);
      owner.add(z);
    }
  }
  final valves = _placeValves(zoneHeads, o, obstacles, grid, owner, messages);
  for (var z = 0; z < valves.length; z++) {
    grid.add(valves[z]);
    owner.add(z);
  }
  final zones = <RoutedZone>[];
  // pipes routed so far: later zones go round them where they can
  final routed = _Segments(math.max(cell, 1.0), Pt(b.minX, b.minY));
  for (var z = 0; z < zoneHeads.length; z++) {
    if (zoneHeads[z].isEmpty) continue;
    final rz = _routeZone(z, zoneHeads[z], valves[z], o, obstacles, grid, owner, messages, routed);
    for (final pipe in rz.pipes) {
      for (var i = 1; i < pipe.points.length; i++) {
        routed.add(pipe.points[i - 1], pipe.points[i], z);
      }
    }
    zones.add(rz);
  }
  final mainline = o.mainline == null && o.pointOfConnection != null ? _mainlineTree(o.pointOfConnection!, [for (final z in zones) z.valve], obstacles) : <RoutedPipe>[];
  return RoutingResult(zones: zones, mainline: mainline, messages: messages, crossings: _crossings([for (final z in zones) ...z.pipes, ...mainline]));
}

/// A mainline tree from [pointOfConnection] to [valves] (or to pivot
/// points, or to the valves of blocks made by the block generator) round
/// [exclusions]: the greedy Steiner tree of [routeZones].
List<RoutedPipe> routeMainline(Pt pointOfConnection, List<Pt> valves, {List<List<Pt>> exclusions = const [], double obstacleMargin = 0.5}) =>
    _mainlineTree(pointOfConnection, valves, _Obstacles(exclusions, math.max(0.05, obstacleMargin)));

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
  final placed = <Pt>[for (var z = 0; z < n; z++) if (given[z]) out[z]];
  bool free(Pt p, int zone) {
    if (obstacles.inside(p)) return false;
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
RoutedZone _routeZone(int zone, List<Pt> heads, Pt valve, RouteOptions o, _Obstacles obstacles, PointGrid grid, List<int> owner, List<String> messages, _Segments routed) {
  final nodes = [valve, ...heads];
  final n = nodes.length;
  final b = Bounds.ofPoints(nodes);
  final local = PointGrid(pointGridCell(b, n, minimum: 0.25), origin: Pt(b.minX, b.minY));
  for (final p in nodes) {
    local.add(p);
  }
  final dir = o.direction != null && o.direction!.length > 0 ? o.direction!.normalized : null;
  final clear = math.max(o.clearance, 0.06);
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
    for (var i = 1; i < p.length; i++) {
      if (foreignNear(p[i - 1], p[i])) return null;
    }
    return p;
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
      final verts = <Pt>{poc, for (var k = 0; k < segs.length; k++) if (alive[k]) ...[segs[k].$1, segs[k].$2]}.toList()..sort((a, b) => a.distanceTo(v).compareTo(b.distanceTo(v)));
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
  final b = Bounds.ofPoints([for (final s in segs) ...[s.$1, s.$2]]);
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
