/// Zoning by flow: heads (or drip areas) grouped into valve zones whose flow
/// stays within the valve and supply limits, never mixing emitters that
/// apply water at different rates, each zone compact and in one piece, the
/// zones of a class with balanced flows.
///
/// Hydrozoning rules after the Irrigation Association (*Landscape
/// Irrigation Best Management Practices*, 2014, practice 2: "group
/// emitters with like precipitation rates") and Keller & Bliesner (1990,
/// chap. 17: a zone as large as the flow allows, compact so that the zone
/// pipes stay short). The grouping is a capacitated region growing on a
/// nearest-neighbour graph: as many seeds as the flow asks for, spread by
/// farthest-point sampling; the least loaded zone takes, one at a time, the
/// unassigned neighbour nearest to its seed; seeds move to the middle of
/// their zones and the growth repeats; a last pass moves boundary items
/// from heavier to lighter neighbouring zones while both stay in one piece.
/// Every choice breaks ties by item index, so the result is deterministic.
library;

import 'dart:math' as math;

import '../model/catalog.dart';
import '../model/geometry.dart';
import 'auto_layout.dart';

/// How fast an emitter applies water: emitters of different classes never
/// share a zone, since one run time cannot suit both.
enum PrecipitationClass { spray, rotor, microSprinkler, bubbler, drip, gun, other }

/// Wetted radius (m) below which a sprinkler is a spray head (fixed spray
/// nozzles throw up to about 5.5 m, rotors from about 6 m).
const sprayRadiusLimit = 6.5;

/// Precipitation class of [family] (with [nozzle] at [headM] when given, to
/// tell sprays from rotors by their wetted radius).
PrecipitationClass precipitationClassOf(OutletSpec family, {NozzleSpec? nozzle, double? headM}) {
  switch (family.kind) {
    case OutletKind.dripper:
      return PrecipitationClass.drip;
    case OutletKind.bubbler:
      return PrecipitationClass.bubbler;
    case OutletKind.microSprinkler:
      return PrecipitationClass.microSprinkler;
    case OutletKind.gun:
      return PrecipitationClass.gun;
    case OutletKind.demandPoint:
      return PrecipitationClass.other;
    case OutletKind.sprinkler:
      final n = nozzle ?? (family.nozzles.isEmpty ? null : family.nozzles.first);
      if (n == null) return PrecipitationClass.rotor;
      final r = n.curve.radius(headM ?? n.defaultHeadM);
      return r > 0 && r < sprayRadiusLimit ? PrecipitationClass.spray : PrecipitationClass.rotor;
  }
}

/// One thing to put in a zone: a head, or a drip area (its centroid) with
/// the flow of all its emitters.
class ZoneItem {
  const ZoneItem({required this.position, required this.flow, this.classKey = ''});
  final Pt position;

  /// Flow (m³/s).
  final double flow;

  /// Items of different keys never share a zone (a precipitation class, or
  /// a class and a head family when families must not mix either).
  final String classKey;
}

/// The heads of [layout] as zone items, keyed by their precipitation class
/// (and family, when [byFamily]).
List<ZoneItem> zoneItemsOf(LandscapeLayout layout, OutletSpec family, {bool byFamily = false}) => [
  for (final h in layout.heads)
    ZoneItem(
      position: h.position,
      flow: h.flow,
      classKey: [precipitationClassOf(family, nozzle: family.nozzle(h.nozzleId), headM: layout.headM).name, if (byFamily) family.id].join(':'),
    ),
];

/// Options of [zoneByFlow].
class ZoningOptions {
  ZoningOptions({required this.maxZoneFlow, this.maxItemsPerZone = 0, this.neighbours = 8, this.linkFactor = 2.5, this.balanceTolerance = 0.1, this.refinePasses = 6, this.seedRounds = 3});

  /// Largest flow of a zone (m³/s): the valve, the supply or the mainline
  /// limit.
  double maxZoneFlow;

  /// Most items in a zone (0 = no limit).
  int maxItemsPerZone;

  /// Neighbours of every item in the graph the zones grow on.
  int neighbours;

  /// Items farther apart than this many typical neighbour distances are not
  /// neighbours: separate lawns get separate zones (0 = any distance).
  double linkFactor;

  /// While growing, a zone stops at the class's mean zone flow times
  /// (1 + this) before the others catch up.
  double balanceTolerance;

  /// Passes moving boundary items towards the lighter zone.
  int refinePasses;

  /// Rounds of re-seeding at the middle of every zone.
  int seedRounds;
}

/// One valve zone.
class ZoneGroup {
  ZoneGroup({required this.items, required this.classKey, required this.flow, required this.centroid});

  /// Indices of the items, ascending.
  final List<int> items;
  final String classKey;

  /// Flow of the zone (m³/s).
  final double flow;
  final Pt centroid;
}

/// Outcome of [zoneByFlow].
class ZoningResult {
  ZoningResult(this.zones, this.zoneOf, this.messages);

  /// Zones by class (in order of first appearance), then by first item.
  final List<ZoneGroup> zones;

  /// Zone of every item (index into [zones]).
  final List<int> zoneOf;

  /// Codes: `zone_item_over_capacity:<item>` (an item alone draws more than
  /// the maximum: it gets a zone of its own), `zone_no_flow:<item>` (an item
  /// without flow, zoned with its neighbours).
  final List<String> messages;

  double get maxFlow => zones.fold(0.0, (m, z) => math.max(m, z.flow));
  double get minFlow => zones.isEmpty ? 0 : zones.fold(double.infinity, (m, z) => math.min(m, z.flow));

  /// Largest zone flow over the mean zone flow of its class (1 = every zone
  /// of a class draws the same).
  double get imbalance {
    var worst = zones.isEmpty ? 0.0 : 1.0;
    final byClass = <String, List<ZoneGroup>>{};
    for (final z in zones) {
      (byClass[z.classKey] ??= []).add(z);
    }
    for (final list in byClass.values) {
      final mean = list.fold(0.0, (s, z) => s + z.flow) / list.length;
      if (mean <= 0) continue;
      for (final z in list) {
        worst = math.max(worst, z.flow / mean);
      }
    }
    return worst;
  }
}

/// Groups [items] into zones (see the library comment).
ZoningResult zoneByFlow(List<ZoneItem> items, ZoningOptions o) {
  final zoneOf = List<int>.filled(items.length, -1);
  final messages = <String>[];
  final zones = <ZoneGroup>[];
  if (items.isEmpty) return ZoningResult(zones, zoneOf, messages);
  final cap = o.maxZoneFlow > 0 && o.maxZoneFlow.isFinite ? o.maxZoneFlow : double.infinity;
  for (var i = 0; i < items.length; i++) {
    if (!(items[i].flow > 0)) messages.add('zone_no_flow:$i');
    if (items[i].flow > cap) messages.add('zone_item_over_capacity:$i');
  }
  final classes = <String>[];
  for (final it in items) {
    if (!classes.contains(it.classKey)) classes.add(it.classKey);
  }
  for (final key in classes) {
    final members = [
      for (var i = 0; i < items.length; i++)
        if (items[i].classKey == key) i,
    ];
    final adj = _neighbourGraph(items, members, o);
    for (final comp in _components(members, adj)) {
      for (final g in _zoneComponent(items, comp, adj, cap, o)) {
        g.sort();
        zones.add(_group(items, g, key));
      }
    }
  }
  // zones by class, then by first item
  final order = List<int>.generate(zones.length, (i) => i)
    ..sort((a, b) {
      final ca = classes.indexOf(zones[a].classKey), cb = classes.indexOf(zones[b].classKey);
      return ca != cb ? ca.compareTo(cb) : zones[a].items.first.compareTo(zones[b].items.first);
    });
  final sorted = [for (final i in order) zones[i]];
  for (var z = 0; z < sorted.length; z++) {
    for (final i in sorted[z].items) {
      zoneOf[i] = z;
    }
  }
  return ZoningResult(sorted, zoneOf, messages);
}

ZoneGroup _group(List<ZoneItem> items, List<int> g, String key) {
  var q = 0.0, sx = 0.0, sy = 0.0;
  for (final i in g) {
    q += items[i].flow;
    sx += items[i].position.x;
    sy += items[i].position.y;
  }
  return ZoneGroup(items: g, classKey: key, flow: q, centroid: Pt(sx / g.length, sy / g.length));
}

/// Symmetric k-nearest-neighbour graph over [members] (indices into
/// [items]), without links longer than the link factor allows.
Map<int, List<int>> _neighbourGraph(List<ZoneItem> items, List<int> members, ZoningOptions o) {
  final adj = <int, List<int>>{for (final i in members) i: <int>[]};
  if (members.length < 2) return adj;
  final b = Bounds.ofPoints([for (final i in members) items[i].position]);
  final grid = PointGrid(pointGridCell(b, members.length), origin: Pt(b.minX, b.minY));
  for (final i in members) {
    grid.add(items[i].position);
  }
  final k = math.max(1, o.neighbours);
  final near = <List<int>>[];
  final nn = <double>[];
  for (var a = 0; a < members.length; a++) {
    final list = grid.kNearest(items[members[a]].position, k + 1, skip: (j) => j == a);
    near.add(list);
    if (list.isNotEmpty) nn.add(grid.points[list.first].distanceTo(items[members[a]].position));
  }
  nn.sort();
  final typical = nn.isEmpty ? 0.0 : nn[nn.length ~/ 2];
  final maxLink = o.linkFactor > 0 && typical > 0 ? o.linkFactor * typical : double.infinity;
  // neighbours: the items around (the diagonal of a square grid, not the
  // head beyond the next one) …
  final local = typical > 0 ? math.min(maxLink, 1.5 * typical) : maxLink;
  void link(int x, int y) {
    if (!adj[x]!.contains(y)) adj[x]!.add(y);
    if (!adj[y]!.contains(x)) adj[y]!.add(x);
  }

  final cands = <(double, int, int)>[];
  for (var a = 0; a < members.length; a++) {
    for (final bIdx in near[a].take(k)) {
      final d = items[members[a]].position.distanceTo(items[members[bIdx]].position);
      if (d <= local) link(members[a], members[bIdx]);
      if (d <= maxLink) cands.add((d, math.min(a, bIdx), math.max(a, bIdx)));
    }
  }
  // … and the shortest links that keep an area in one piece (a minimum
  // spanning tree of the candidates, Kruskal)
  cands.sort((x, y) => x.$1 != y.$1 ? x.$1.compareTo(y.$1) : (x.$2 != y.$2 ? x.$2.compareTo(y.$2) : x.$3.compareTo(y.$3)));
  final root = List<int>.generate(members.length, (i) => i);
  int find(int x) {
    while (root[x] != x) {
      root[x] = root[root[x]];
      x = root[x];
    }
    return x;
  }

  final slot = {for (var a = 0; a < members.length; a++) members[a]: a};
  for (var a = 0; a < members.length; a++) {
    for (final nb in adj[members[a]]!) {
      root[find(a)] = find(slot[nb]!);
    }
  }
  for (final (_, a, bIdx) in cands) {
    final ra = find(a), rb = find(bIdx);
    if (ra == rb) continue;
    root[ra] = rb;
    link(members[a], members[bIdx]);
  }
  for (final l in adj.values) {
    l.sort();
  }
  return adj;
}

List<List<int>> _components(List<int> members, Map<int, List<int>> adj) {
  final seen = <int>{};
  final out = <List<int>>[];
  for (final s in members) {
    if (!seen.add(s)) continue;
    final comp = <int>[s];
    for (var h = 0; h < comp.length; h++) {
      for (final n in adj[comp[h]]!) {
        if (seen.add(n)) comp.add(n);
      }
    }
    comp.sort();
    out.add(comp);
  }
  return out;
}

/// Zones of one connected component: as many seeds as the flow asks for,
/// more zones where the growth leaves pockets, the best of a few rounds of
/// re-seeding.
List<List<int>> _zoneComponent(List<ZoneItem> items, List<int> comp, Map<int, List<int>> adj, double cap, ZoningOptions o) {
  // items over the cap get zones of their own
  final big = [
    for (final i in comp)
      if (items[i].flow > cap) i,
  ];
  final rest = [
    for (final i in comp)
      if (items[i].flow <= cap) i,
  ];
  final out = <List<int>>[
    for (final i in big) [i],
  ];
  if (rest.isEmpty) return out;
  final total = rest.fold(0.0, (s, i) => s + math.max(0.0, items[i].flow));
  var n = cap.isFinite ? math.max(1, (total / cap - 1e-9).ceil()) : 1;
  if (o.maxItemsPerZone > 0) n = math.max(n, (rest.length / o.maxItemsPerZone).ceil());
  n = math.min(n, rest.length);
  final inRest = rest.toSet();
  final soft = cap.isFinite ? math.min(cap, total / n * (1 + o.balanceTolerance)) : total / n * (1 + o.balanceTolerance);
  var seeds = _farthestSeeds(items, rest, n);
  List<List<int>>? best;
  var bestScore = double.infinity;
  for (var round = 0; round <= o.seedRounds; round++) {
    final zones = _growFrom(items, rest, inRest, adj, cap, soft, seeds, o);
    _mergeSmall(items, zones, adj, cap, o);
    _refine(items, zones, adj, cap, o);
    final score = _score(items, zones, rest, cap);
    if (score < bestScore - 1e-12) {
      bestScore = score;
      best = [for (final z in zones) List.of(z)];
    }
    // re-seed at the member nearest to the middle of every zone
    seeds = [
      for (final z in zones)
        () {
          final c = _group(items, z, '').centroid;
          var s = z.first;
          for (final i in z) {
            if (items[i].position.distanceTo(c) < items[s].position.distanceTo(c) - 1e-12) s = i;
          }
          return s;
        }(),
    ];
  }
  return [...out, ...best!];
}

/// Quality of a zoning: fewest zones first, then the spread of the flows
/// around the most a zone may draw, then compactness.
double _score(List<ZoneItem> items, List<List<int>> zones, List<int> rest, double cap) {
  final loads = [for (final z in zones) z.fold(0.0, (s, i) => s + items[i].flow)];
  final mean = loads.fold(0.0, (s, l) => s + l) / zones.length;
  final spread = loads.fold(0.0, (m, l) => math.max(m, (l - mean).abs())) / (mean > 0 ? mean : 1);
  var compact = 0.0;
  for (final z in zones) {
    final c = _group(items, z, '').centroid;
    for (final i in z) {
      compact += items[i].position.distanceTo(c);
    }
  }
  return zones.length * 1e6 + spread * 1e3 + compact / rest.length / math.max(1e-9, _scale(items, rest));
}

double _scale(List<ZoneItem> items, List<int> rest) {
  final b = Bounds.ofPoints([for (final i in rest) items[i].position]);
  return math.max(1e-6, math.max(b.width, b.height));
}

/// [n] seeds by farthest-point sampling, the first one farthest from the
/// centroid.
List<int> _farthestSeeds(List<ZoneItem> items, List<int> rest, int n) {
  var sx = 0.0, sy = 0.0;
  for (final i in rest) {
    sx += items[i].position.x;
    sy += items[i].position.y;
  }
  final c = Pt(sx / rest.length, sy / rest.length);
  var first = rest.first;
  for (final i in rest) {
    if (items[i].position.distanceTo(c) > items[first].position.distanceTo(c) + 1e-12) first = i;
  }
  final seeds = [first];
  final dmin = [for (final i in rest) items[i].position.distanceTo(items[first].position)];
  while (seeds.length < n) {
    var bi = -1;
    var bd = -1.0;
    for (var k = 0; k < rest.length; k++) {
      if (dmin[k] > bd + 1e-12) {
        bd = dmin[k];
        bi = k;
      }
    }
    if (bi < 0 || bd <= 0) break;
    final s = rest[bi];
    seeds.add(s);
    for (var k = 0; k < rest.length; k++) {
      final d = items[rest[k]].position.distanceTo(items[s].position);
      if (d < dmin[k]) dmin[k] = d;
    }
  }
  return seeds;
}

/// Grows one zone from every seed: the least loaded zone takes the
/// unassigned neighbour nearest to its seed that fits ([soft] first, then
/// [cap]); items left in pockets seed zones of their own.
List<List<int>> _growFrom(List<ZoneItem> items, List<int> rest, Set<int> inRest, Map<int, List<int>> adj, double cap, double soft, List<int> seeds, ZoningOptions o) {
  final zoneOf = <int, int>{};
  final zones = <List<int>>[];
  final loads = <double>[];
  final frontier = <List<int>>[];
  final maxItems = o.maxItemsPerZone > 0 ? o.maxItemsPerZone : 1 << 30;
  void expose(int z, int i) {
    for (final nb in adj[i]!) {
      if (inRest.contains(nb) && !zoneOf.containsKey(nb) && !frontier[z].contains(nb)) frontier[z].add(nb);
    }
  }

  int open(int s) {
    final z = zones.length;
    zoneOf[s] = z;
    zones.add([s]);
    loads.add(items[s].flow);
    frontier.add([]);
    expose(z, s);
    return z;
  }

  /// One more item for zone [z] within [limit]; false when none fits.
  bool step(int z, double limit) {
    frontier[z].removeWhere(zoneOf.containsKey);
    if (zones[z].length >= maxItems) return false;
    final seed = items[zones[z].first].position;
    int? pick;
    var pd = double.infinity;
    for (final i in frontier[z]) {
      if (loads[z] + items[i].flow > limit + 1e-12) continue;
      final d = items[i].position.distanceTo(seed);
      if (d < pd - 1e-12 || (d <= pd + 1e-12 && pick != null && i < pick)) {
        pd = d;
        pick = i;
      }
    }
    if (pick == null) return false;
    zoneOf[pick] = z;
    zones[z].add(pick);
    loads[z] += items[pick].flow;
    expose(z, pick);
    return true;
  }

  for (final s in seeds) {
    if (!zoneOf.containsKey(s)) open(s);
  }
  for (final limit in [soft, cap]) {
    // least loaded zone first (ties by index): a zone that cannot grow is
    // done for this limit
    final heap = _LoadHeap();
    for (var z = 0; z < zones.length; z++) {
      heap.push(loads[z], z);
    }
    while (heap.isNotEmpty) {
      final z = heap.pop();
      if (step(z, limit)) heap.push(loads[z], z);
    }
  }
  // pockets the zones could not reach within the cap
  for (final i in rest) {
    if (zoneOf.containsKey(i)) continue;
    final z = open(i);
    while (step(z, cap)) {}
  }
  return zones;
}

/// Min-heap of (load, zone), ties by zone.
class _LoadHeap {
  final List<(double, int)> _a = [];
  bool get isNotEmpty => _a.isNotEmpty;
  bool _less((double, int) x, (double, int) y) => x.$1 != y.$1 ? x.$1 < y.$1 : x.$2 < y.$2;

  void push(double load, int z) {
    _a.add((load, z));
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

  int pop() {
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
    return top.$2;
  }
}

/// Merges every zone lighter than half the mean into its lightest
/// neighbouring zone when both fit in [cap] together (the pockets of the
/// growth, small leftovers).
void _mergeSmall(List<ZoneItem> items, List<List<int>> zones, Map<int, List<int>> adj, double cap, ZoningOptions o) {
  final maxItems = o.maxItemsPerZone > 0 ? o.maxItemsPerZone : 1 << 30;
  var merged = true;
  while (merged && zones.length > 1) {
    merged = false;
    final zoneOf = <int, int>{};
    for (var z = 0; z < zones.length; z++) {
      for (final i in zones[z]) {
        zoneOf[i] = z;
      }
    }
    final loads = [for (final z in zones) z.fold(0.0, (s, i) => s + items[i].flow)];
    final mean = loads.fold(0.0, (s, l) => s + l) / zones.length;
    final order = List<int>.generate(zones.length, (i) => i)..sort((a, b) => loads[a] != loads[b] ? loads[a].compareTo(loads[b]) : a.compareTo(b));
    for (final z in order) {
      if (loads[z] >= 0.5 * mean) break;
      final nbs = <int>{
        for (final i in zones[z])
          for (final nb in adj[i]!)
            if (zoneOf[nb] != null && zoneOf[nb] != z) zoneOf[nb]!,
      }.toList()..sort((a, b) => loads[a] != loads[b] ? loads[a].compareTo(loads[b]) : a.compareTo(b));
      for (final y in nbs) {
        if (loads[y] + loads[z] > cap + 1e-12 || zones[y].length + zones[z].length > maxItems) continue;
        zones[y].addAll(zones[z]);
        zones.removeAt(z);
        merged = true;
        break;
      }
      if (merged) break;
    }
  }
}

/// Moves boundary items from the heavier to the lighter of two neighbouring
/// zones when that narrows their difference, keeps the lighter one within
/// [cap] and leaves the heavier one in one piece.
void _refine(List<ZoneItem> items, List<List<int>> zones, Map<int, List<int>> adj, double cap, ZoningOptions o) {
  final zoneOf = <int, int>{};
  for (var z = 0; z < zones.length; z++) {
    for (final i in zones[z]) {
      zoneOf[i] = z;
    }
  }
  final loads = [for (final z in zones) z.fold(0.0, (s, i) => s + items[i].flow)];
  final maxItems = o.maxItemsPerZone > 0 ? o.maxItemsPerZone : 1 << 30;
  bool connectedWithout(int z, int out) {
    final members = zones[z].where((i) => i != out).toSet();
    if (members.isEmpty) return false;
    final start = members.first;
    final seen = <int>{start};
    final queue = [start];
    for (var h = 0; h < queue.length; h++) {
      for (final nb in adj[queue[h]]!) {
        if (members.contains(nb) && seen.add(nb)) queue.add(nb);
      }
    }
    return seen.length == members.length;
  }

  for (var pass = 0; pass < o.refinePasses; pass++) {
    var moved = false;
    final all = zoneOf.keys.toList()..sort();
    for (final i in all) {
      final a = zoneOf[i]!;
      final q = items[i].flow;
      final targets = <int>{
        for (final nb in adj[i]!)
          if (zoneOf[nb] != null && zoneOf[nb] != a) zoneOf[nb]!,
      }.toList()..sort();
      for (final b in targets) {
        if (!(q < loads[a] - loads[b] - 1e-12)) continue;
        if (loads[b] + q > cap + 1e-12 || zones[b].length >= maxItems) continue;
        if (!connectedWithout(a, i)) continue;
        zones[a].remove(i);
        zones[b].add(i);
        zoneOf[i] = b;
        loads[a] -= q;
        loads[b] += q;
        moved = true;
        break;
      }
    }
    if (!moved) break;
  }
}
