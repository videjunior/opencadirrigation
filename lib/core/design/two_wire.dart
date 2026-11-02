/// Two-wire (decoder) valve wiring. One pair of conductors leaves the
/// controller and runs along the wire routes past every valve; a decoder
/// spliced on the pair at a valve drives the solenoids of 1, 2, 4 or 6
/// stations, the valves within the reach of a solenoid cable from it. The
/// pair always carries the idle current of every decoder and, while stations
/// run, their solenoid currents. Both conductors carry the current, so the
/// drop along a stretch of the path is I·2·R'·L, with I the current of
/// everything beyond the stretch (Ohm's law around the loop) and L the
/// cable length (route plus slack).
///
/// For every controller the design takes the cheapest wire of the list (the
/// thinnest on a tie) that keeps every decoder with a running station at or
/// above the minimum voltage while each station of a system flow opens
/// (inrush) with the other stations of the flow holding; valves in no flow
/// run alone, and without flows every valve runs at once, as in the
/// hydraulic design. Because the drops grow with the length, the largest
/// distance a wire allows is the layout scaled until the worst decoder
/// reaches the minimum. The results have the shape of `electrical.dart`
/// (stations, decoders, one duty per controller, codes, metres of wire).
///
/// Defaults are orders of magnitude, to be replaced by the data sheets of
/// the controller and the decoders: 34 V on the path, at least 24 V at a
/// decoder, 1 mA idle current per decoder, and the solenoid currents of the
/// design parameters taken on the line (on the safe side: a decoder converts
/// the line power and draws less at the higher voltage). Grounding: a surge
/// arrester with a ground rod at the controller, then every 12 decoders or
/// 150 m of path, whichever comes first, and at every end of the path — a
/// rule of thumb of installation guides, configurable, not a standard.
///
/// Valve-in-head stations (`valve_in_head.dart`): the solenoid of every head
/// is a point of the path like a zone valve, decoders spliced at the heads
/// as two-wire practice puts them on turf, and all the heads of a station
/// answer to one station number of their controller. A decoder drives the
/// heads within the solenoid cable reach; heads of one station share one of
/// its outputs up to [TwoWireSpec.solenoidsPerOutput] solenoids in parallel,
/// beyond that they take another output. When a station opens, the inrush
/// of all its heads loads the pair at once.
library;

import 'dart:math' as math;

import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import 'electrical.dart';
import 'valve_in_head.dart';

/// Electrical data of a two-wire system.
class TwoWireSpec {
  const TwoWireSpec({
    this.outputVolts = 34,
    this.minVolts = 24,
    this.decoderIdleA = 0.001,
    this.inrushA,
    this.holdingA,
    this.decoderCapacities = const [1, 2, 4, 6],
    this.maxSolenoidCableM = 30,
    this.groundEveryDecoders = 12,
    this.groundEveryM = 150,
    this.slackPct,
    this.solenoidsPerOutput = 2,
  });

  /// Solenoids one decoder output drives in parallel (the heads of one
  /// valve-in-head station near a decoder share an output up to it).
  final int solenoidsPerOutput;

  /// Voltage the controller puts on the path and the least a decoder needs
  /// (V).
  final double outputVolts;
  final double minVolts;

  /// Current a decoder draws when idle (A).
  final double decoderIdleA;

  /// Line current of a station opening and holding (A); null = the solenoid
  /// currents of the design parameters.
  final double? inrushA;
  final double? holdingA;

  /// Stations per decoder on sale; valves within [maxSolenoidCableM] (m,
  /// along the routes) of a decoder share it up to the largest.
  final List<int> decoderCapacities;
  final double maxSolenoidCableM;

  /// Grounding rule: every this many decoders or metres of path (0 = not
  /// used), besides the controller and the ends of the path.
  final int groundEveryDecoders;
  final double groundEveryM;

  /// Cable added to the routes (%); null = the wire slack of the design
  /// parameters.
  final double? slackPct;
}

/// One station: a valve driven by a decoder (or one head of a valve-in-head
/// station, its station's name and number).
class TwoWireStation {
  TwoWireStation({
    required this.valveId,
    required this.zoneName,
    required this.controllerId,
    required this.decoderId,
    required this.station,
    required this.routeM,
    required this.solenoidCableM,
    required this.volts,
    required this.ok,
    this.openTogether = 1,
  });

  /// The valve, or the head (outlet id) of a valve-in-head station.
  final String valveId;
  final String zoneName;
  final String controllerId;
  final String decoderId;

  /// Station number on the controller, along the path.
  final int station;

  /// Path length from the controller to the decoder (m) and the solenoid
  /// cable from the decoder to the valve (m, along the routes, slack
  /// included).
  final double routeM;
  final double solenoidCableM;

  /// Voltage at the decoder while the station opens with the others of its
  /// flow holding (V).
  final double volts;
  final bool ok;

  /// Stations of the same controller running together (worst flow).
  final int openTogether;

  Map<String, dynamic> toJson() => {
    'valve': valveId,
    'zone': zoneName,
    'ctrl': controllerId,
    'dec': decoderId,
    'st': station,
    'route': routeM,
    'sol': solenoidCableM,
    'v': volts,
    'ok': ok,
    'n': openTogether,
  };
  static TwoWireStation fromJson(Map<String, dynamic> j) => TwoWireStation(
    valveId: j['valve'] as String,
    zoneName: j['zone'] as String? ?? '',
    controllerId: j['ctrl'] as String? ?? '',
    decoderId: j['dec'] as String? ?? '',
    station: (j['st'] as num?)?.toInt() ?? 0,
    routeM: _d(j['route']),
    solenoidCableM: _d(j['sol']),
    volts: _d(j['v']),
    ok: j['ok'] as bool? ?? true,
    openTogether: (j['n'] as num?)?.toInt() ?? 1,
  );
}

/// A decoder on the path.
class TwoWireDecoder {
  TwoWireDecoder({required this.id, required this.controllerId, required this.p, required this.capacity, required this.valveIds, required this.routeM, required this.volts});
  final String id;
  final String controllerId;
  final Pt p;

  /// Stations (outputs) of the decoder model (1, 2, 4, 6) and the valves and
  /// valve-in-head heads it drives.
  final int capacity;
  final List<String> valveIds;

  /// Path length from the controller (m) and the lowest voltage at the
  /// decoder while one of its stations runs (V).
  final double routeM;
  final double volts;

  Map<String, dynamic> toJson() => {'id': id, 'ctrl': controllerId, 'p': p.toList(), 'cap': capacity, 'valves': valveIds, 'route': routeM, 'v': volts};
  static TwoWireDecoder fromJson(Map<String, dynamic> j) => TwoWireDecoder(
    id: j['id'] as String,
    controllerId: j['ctrl'] as String? ?? '',
    p: j['p'] is List ? Pt.fromList(j['p'] as List) : Pt.zero,
    capacity: (j['cap'] as num?)?.toInt() ?? 1,
    valveIds: ((j['valves'] as List?) ?? []).cast<String>(),
    routeM: _d(j['route']),
    volts: _d(j['v']),
  );
}

/// How a wire of the list does on a path.
class TwoWireSizeCheck {
  TwoWireSizeCheck({required this.wireId, required this.worstVolts, required this.ok, required this.maxDistanceM});
  final String? wireId;

  /// Lowest voltage at a running decoder (V) and whether it is enough.
  final double worstVolts;
  final bool ok;

  /// Farthest decoder distance the wire allows with this layout scaled (m;
  /// infinite without load).
  final double maxDistanceM;

  Map<String, dynamic> toJson() => {if (wireId != null) 'w': wireId, 'v': worstVolts, 'ok': ok, 'max': maxDistanceM.isFinite ? maxDistanceM : null};
  static TwoWireSizeCheck fromJson(Map<String, dynamic> j) =>
      TwoWireSizeCheck(wireId: j['w'] as String?, worstVolts: _d(j['v']), ok: j['ok'] as bool? ?? true, maxDistanceM: (j['max'] as num?)?.toDouble() ?? double.infinity);
}

/// What a controller's two-wire path carries (the [ControllerDuty] of
/// `electrical.dart`).
class TwoWirePath {
  TwoWirePath({
    required this.controllerId,
    required this.name,
    required this.stations,
    required this.used,
    this.wireId,
    required this.routeM,
    required this.cableM,
    required this.decoders,
    required this.maxOpen,
    required this.peakCurrentA,
    required this.worstVolts,
    required this.maxDistanceM,
    required this.sizes,
  });
  final String controllerId;
  final String name;

  /// Stations of the controller and stations used.
  final int stations;
  final int used;

  /// Wire chosen for the pair.
  final String? wireId;

  /// Route length of the path (m) and of the cable with the slack (m).
  final double routeM;
  final double cableM;
  final int decoders;

  /// Most stations running together and the current the controller then
  /// supplies (idle decoders, one station opening, the others holding; A).
  final int maxOpen;
  final double peakCurrentA;

  /// Lowest voltage at a running decoder with the chosen wire (V) and the
  /// farthest decoder distance that wire allows (m).
  final double worstVolts;
  final double maxDistanceM;

  /// Every wire of the list on this path, thinnest first.
  final List<TwoWireSizeCheck> sizes;
  bool get overloaded => used > stations;

  Map<String, dynamic> toJson() => {
    'ctrl': controllerId,
    'name': name,
    'stations': stations,
    'used': used,
    if (wireId != null) 'w': wireId,
    'route': routeM,
    'cable': cableM,
    'dec': decoders,
    'open': maxOpen,
    'amps': peakCurrentA,
    'v': worstVolts,
    'max': maxDistanceM.isFinite ? maxDistanceM : null,
    'sizes': sizes.map((s) => s.toJson()).toList(),
  };
  static TwoWirePath fromJson(Map<String, dynamic> j) => TwoWirePath(
    controllerId: j['ctrl'] as String,
    name: j['name'] as String? ?? '',
    stations: (j['stations'] as num?)?.toInt() ?? 0,
    used: (j['used'] as num?)?.toInt() ?? 0,
    wireId: j['w'] as String?,
    routeM: _d(j['route']),
    cableM: _d(j['cable']),
    decoders: (j['dec'] as num?)?.toInt() ?? 0,
    maxOpen: (j['open'] as num?)?.toInt() ?? 0,
    peakCurrentA: _d(j['amps']),
    worstVolts: _d(j['v']),
    maxDistanceM: (j['max'] as num?)?.toDouble() ?? double.infinity,
    sizes: [for (final s in (j['sizes'] as List?) ?? []) TwoWireSizeCheck.fromJson(s as Map<String, dynamic>)],
  );
}

/// Why a grounding point is where it is.
enum GroundKind { controller, interval, end }

/// A grounding (surge protection) point of a path.
class TwoWireGround {
  TwoWireGround({required this.controllerId, required this.p, required this.kind, this.decoderId});
  final String controllerId;
  final Pt p;
  final GroundKind kind;

  /// The decoder at the point, if any.
  final String? decoderId;

  Map<String, dynamic> toJson() => {'ctrl': controllerId, 'p': p.toList(), 'kind': kind.name, if (decoderId != null) 'dec': decoderId};
  static TwoWireGround fromJson(Map<String, dynamic> j) => TwoWireGround(
    controllerId: j['ctrl'] as String? ?? '',
    p: j['p'] is List ? Pt.fromList(j['p'] as List) : Pt.zero,
    kind: GroundKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => GroundKind.interval),
    decoderId: j['dec'] as String?,
  );
}

/// Outcome of [designTwoWire] (the [ElectricalResult] of a two-wire system).
class TwoWireResult {
  TwoWireResult({List<TwoWireStation>? stations, List<TwoWireDecoder>? decoders, List<TwoWirePath>? paths, List<TwoWireGround>? grounds, List<String>? warnings, Map<String, double>? wireMeters})
    : stations = stations ?? [],
      decoders = decoders ?? [],
      paths = paths ?? [],
      grounds = grounds ?? [],
      warnings = warnings ?? [],
      wireMeters = wireMeters ?? {};
  final List<TwoWireStation> stations;
  final List<TwoWireDecoder> decoders;
  final List<TwoWirePath> paths;
  final List<TwoWireGround> grounds;

  /// Codes (`twowire_*`, optionally `:<entity id>`): `twowire_no_controller`,
  /// `twowire_unwired:<valve>` (or the heads of a valve-in-head station no
  /// route reaches, `:<head>:<head>…`), `twowire_wire_orphan:<wire>`,
  /// `twowire_ctrl_unwired:<controller>`, `twowire_no_wires`,
  /// `twowire_stations:<controller>` (more stations than it has),
  /// `twowire_simultaneous:<controller>` (a flow runs more stations than it
  /// drives at once), `twowire_voltage:<valve>` (below the minimum even with
  /// the thickest wire).
  final List<String> warnings;

  /// Conductor length per catalogue wire (m, both conductors, slack
  /// included).
  final Map<String, double> wireMeters;

  TwoWireStation? stationOf(String valveId) => stations.where((s) => s.valveId == valveId).firstOrNull;

  Map<String, dynamic> toJson() => {
    'st': stations.map((s) => s.toJson()).toList(),
    'dec': decoders.map((d) => d.toJson()).toList(),
    'paths': paths.map((p) => p.toJson()).toList(),
    'gnd': grounds.map((g) => g.toJson()).toList(),
    'warn': warnings,
    'meters': wireMeters,
  };
  static TwoWireResult fromJson(Map<String, dynamic> j) => TwoWireResult(
    stations: [for (final s in (j['st'] as List?) ?? []) TwoWireStation.fromJson(s as Map<String, dynamic>)],
    decoders: [for (final s in (j['dec'] as List?) ?? []) TwoWireDecoder.fromJson(s as Map<String, dynamic>)],
    paths: [for (final s in (j['paths'] as List?) ?? []) TwoWirePath.fromJson(s as Map<String, dynamic>)],
    grounds: [for (final s in (j['gnd'] as List?) ?? []) TwoWireGround.fromJson(s as Map<String, dynamic>)],
    warnings: ((j['warn'] as List?) ?? []).cast<String>(),
    wireMeters: {for (final e in ((j['meters'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toDouble()},
  );
}

/// Designs the two-wire wiring of [p] along [routes] (default: the wire
/// routes drawn; the polylines of `wire_routing.dart` work too). Returns null
/// when there is neither a controller nor a route. [flows] are the valve sets
/// that run together (the system flows with the valve-in-head stations they
/// run, as `wiringFlows` of `network_ops.dart` gives them).
TwoWireResult? designTwoWire(Project p, {List<Set<String>> flows = const [], TwoWireSpec spec = const TwoWireSpec(), List<List<Pt>>? routes}) {
  final controllers = p.entities.whereType<ControllerEntity>().toList();
  final lines =
      routes ??
      [
        for (final w in p.entities.whereType<WireEntity>())
          if (w.points.length >= 2) w.points,
      ];
  final wireIds = routes == null
      ? [
          for (final w in p.entities.whereType<WireEntity>())
            if (w.points.length >= 2) w.id,
        ]
      : [for (var i = 0; i < lines.length; i++) 'route$i'];
  if (controllers.isEmpty && lines.isEmpty) return null;
  final params = p.params;
  final inrush = spec.inrushA ?? params.solenoidInrushA;
  final holding = spec.holdingA ?? params.solenoidHoldingA;
  final slack = 1 + math.max(0.0, spec.slackPct ?? params.wireSlackPct) / 100;
  final result = TwoWireResult();
  if (controllers.isEmpty) {
    result.warnings.add('twowire_no_controller');
    return result;
  }
  final valves = p.entities.whereType<ControlValveEntity>().toList();
  final vih = VihStations.of(p);
  final headAt = <String, Pt>{
    for (final e in p.entities)
      if (e is OutletEntity && vih.stationOf.containsKey(e.id)) e.id: e.position,
  };
  final g = WireGraph(math.max(params.connectTolerance, 0.1));
  for (var k = 0; k < lines.length; k++) {
    final pts = lines[k];
    for (var i = 1; i < pts.length; i++) {
      g.addEdge(g.node(pts[i - 1]), g.node(pts[i]), wireIds[k]);
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
  final headNode = <String, int>{};
  for (final e in headAt.entries) {
    final n = g.attach(e.value);
    if (n != null) headNode[e.key] = n;
  }
  final adj = g.adjacency();
  final paths = {for (final e in ctrlNode.entries) e.key: g.shortest(e.value, adj)};
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
    if (!owner.containsKey(v.id)) result.warnings.add('twowire_unwired:${v.id}');
  }
  // a valve-in-head station on the controller that reaches most of its
  // heads (the shorter routes on a tie), the others reported together
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
        'twowire_unwired:${[for (final h in s.value)
          if (!wired.contains(h)) h].join(':')}',
      );
    }
    if (best == null || wired.isEmpty) continue;
    owner[s.key] = best;
    stationHeads[s.key] = wired;
  }
  final reached = <int>{for (final pth in paths.values) ...pth.$1.keys};
  for (var k = 0; k < lines.length; k++) {
    final a = g.find(lines[k].first);
    if (routes == null && (a == null || !reached.contains(a))) result.warnings.add('twowire_wire_orphan:${wireIds[k]}');
  }
  for (final c in controllers) {
    if (!ctrlNode.containsKey(c.id)) result.warnings.add('twowire_ctrl_unwired:${c.id}');
  }
  final catWires = p.catalog.enabledWires;
  if (catWires.isEmpty && owner.isNotEmpty) result.warnings.add('twowire_no_wires');
  final candidates = catWires.isEmpty ? [WireSpec(id: '', name: '', sectionMm2: 1.5, ohmPerKm: copperOhmPerKm(1.5))] : catWires;
  final caps = ([...spec.decoderCapacities.where((c) => c > 0)]..sort()).toList();
  if (caps.isEmpty) caps.add(1);
  var decoderSeq = 0;

  for (final c in controllers) {
    final mine = [
      for (final v in valves)
        if (owner[v.id] == c.id) v,
    ];
    final myStations = [
      for (final s in stationHeads.keys)
        if (owner[s] == c.id) s,
    ];
    if (mine.isEmpty && myStations.isEmpty) {
      result.paths.add(
        TwoWirePath(
          controllerId: c.id,
          name: c.name,
          stations: c.stations,
          used: 0,
          routeM: 0,
          cableM: 0,
          decoders: 0,
          maxOpen: 0,
          peakCurrentA: 0,
          worstVolts: spec.outputVolts,
          maxDistanceM: double.infinity,
          sizes: const [],
        ),
      );
      continue;
    }
    if (mine.length + myStations.length > c.stations) result.warnings.add('twowire_stations:${c.id}');
    // the solenoids along the path (id, node, station): every valve, and every
    // wired head of the valve-in-head stations
    final points = <(String, int, String)>[
      for (final v in mine) (v.id, valveNode[v.id]!, v.id),
      for (final s in myStations)
        for (final h in stationHeads[s]!) (h, headNode[h]!, s),
    ];
    final pointsOf = <String, List<String>>{
      for (final v in mine) v.id: [v.id],
      for (final s in myStations) s: stationHeads[s]!,
    };
    final root = ctrlNode[c.id]!;
    final (dist, via) = paths[c.id]!;
    // the tree: the shortest paths from the controller to its valves
    final parentEdge = <int, int>{};
    for (final (_, node, _) in points) {
      var n = node;
      var guard = 0;
      while (n != root && guard++ < 1000000) {
        final ei = via[n]!;
        if (parentEdge.containsKey(n)) break;
        parentEdge[n] = ei;
        n = g.edge(ei).other(n);
      }
    }
    final children = <int, List<int>>{};
    for (final e in parentEdge.entries) {
      children.putIfAbsent(g.edge(e.value).other(e.key), () => []).add(e.key);
    }
    for (final l in children.values) {
      l.sort((a, b) => parentEdge[a]!.compareTo(parentEdge[b]!));
    }
    final treeLength = parentEdge.values.fold(0.0, (s, ei) => s + g.edge(ei).length);
    // preorder of the tree and the valves along it
    final preorder = <int>[];
    final stack = [root];
    while (stack.isNotEmpty) {
      final n = stack.removeLast();
      preorder.add(n);
      final ch = children[n] ?? const <int>[];
      for (var i = ch.length - 1; i >= 0; i--) {
        stack.add(ch[i]);
      }
    }
    final rank = {for (var i = 0; i < preorder.length; i++) preorder[i]: i};
    final ordered = [...points]
      ..sort((a, b) {
        final ra = rank[a.$2]!, rb = rank[b.$2]!;
        if (ra != rb) return ra.compareTo(rb);
        return a.$1.compareTo(b.$1);
      });
    int parentOf(int n) => g.edge(parentEdge[n]!).other(n);
    double treeDistance(int a, int b) {
      final up = <int>{};
      var x = a;
      up.add(x);
      while (x != root) {
        x = parentOf(x);
        up.add(x);
      }
      var y = b;
      while (!up.contains(y)) {
        y = parentOf(y);
      }
      return dist[a]! + dist[b]! - 2 * dist[y]!;
    }

    // decoders: consecutive valves within the solenoid cable reach, one
    // output each; a head beside another of its station shares that output
    // while it drives fewer solenoids than it can
    final decoderOf = <String, int>{};
    final decoders = <(int, List<String>, List<(String, int)>)>[]; // host, solenoids, outputs (station, solenoids)
    for (final (id, n, s) in ordered) {
      if (decoders.isNotEmpty) {
        final (host, members, outputs) = decoders.last;
        if (treeDistance(host, n) <= spec.maxSolenoidCableM + 1e-9) {
          final o = id == s ? -1 : outputs.indexWhere((x) => x.$1 == s && x.$2 < spec.solenoidsPerOutput);
          if (o >= 0 || outputs.length < caps.last) {
            members.add(id);
            if (o >= 0) {
              outputs[o] = (s, outputs[o].$2 + 1);
            } else {
              outputs.add((s, 1));
            }
            decoderOf[id] = decoders.length - 1;
            continue;
          }
        }
      }
      decoders.add((n, [id], [(s, 1)]));
      decoderOf[id] = decoders.length - 1;
    }
    final decoderIds = [for (var i = 0; i < decoders.length; i++) 'dec${++decoderSeq}'];
    final idleAt = <int, double>{};
    for (final (host, _, _) in decoders) {
      idleAt[host] = (idleAt[host] ?? 0) + spec.decoderIdleA;
    }
    // groups of this controller's valves (and stations) that run together
    final ids = {for (final v in mine) v.id, ...myStations};
    final groups = <Set<String>>[];
    for (final f in flows) {
      final gs = f.intersection(ids);
      if (gs.isNotEmpty) groups.add(gs);
    }
    for (final id in [for (final v in mine) v.id, ...myStations]) {
      if (!groups.any((gs) => gs.contains(id))) groups.add({id});
    }
    final maxOpen = groups.fold(0, (m, gs) => math.max(m, gs.length));
    if (c.maxSimultaneous > 0 && maxOpen > c.maxSimultaneous) result.warnings.add('twowire_simultaneous:${c.id}');
    final idleTotal = decoders.length * spec.decoderIdleA;
    // one station opening (all the heads of a valve-in-head one at once),
    // the others of its group holding
    var load = 0.0;
    for (final gs in groups) {
      final top = gs.fold(1, (m, u) => math.max(m, pointsOf[u]!.length));
      final all = gs.fold(0, (n, u) => n + pointsOf[u]!.length);
      load = math.max(load, top * inrush + (all - top) * holding);
    }
    final peak = idleTotal + load;

    /// Drop per ohm/m of conductor (V·m/Ω) at every tree node for the
    /// station [opener] opening with the rest of [group] holding.
    Map<int, double> drops(String opener, Set<String> group) {
      final load = Map<int, double>.from(idleAt);
      for (final v in group) {
        for (final pt in pointsOf[v]!) {
          final host = decoders[decoderOf[pt]!].$1;
          load[host] = (load[host] ?? 0) + (v == opener ? inrush : holding);
        }
      }
      final current = <int, double>{};
      for (final n in preorder.reversed) {
        var i = load[n] ?? 0;
        for (final ch in children[n] ?? const <int>[]) {
          i += current[ch]!;
        }
        current[n] = i;
      }
      final drop = <int, double>{root: 0};
      for (final n in preorder) {
        if (n == root) continue;
        final e = g.edge(parentEdge[n]!);
        drop[n] = drop[parentOf(n)]! + current[n]! * 2 * e.length * slack;
      }
      return drop;
    }

    // worst drops: per station while it opens, per decoder while it runs,
    // and on the whole path
    final openingDrop = <String, double>{};
    final decoderDrop = List<double>.filled(decoders.length, 0);
    var worstDrop = 0.0;
    final openWith = <String, int>{};
    for (final gs in groups) {
      for (final o in gs) {
        final d = drops(o, gs);
        for (final pt in pointsOf[o]!) {
          openingDrop[pt] = math.max(openingDrop[pt] ?? 0, d[decoders[decoderOf[pt]!].$1]!);
          openWith[pt] = math.max(openWith[pt] ?? 1, gs.length);
        }
        for (final v in gs) {
          for (final pt in pointsOf[v]!) {
            final k = decoderOf[pt]!;
            final dd = d[decoders[k].$1]!;
            decoderDrop[k] = math.max(decoderDrop[k], dd);
            worstDrop = math.max(worstDrop, dd);
          }
        }
      }
    }
    final farthest = decoders.fold(0.0, (m, d) => math.max(m, dist[d.$1]!));
    double volts(double drop, WireSpec w) => spec.outputVolts - drop * w.ohmPerKm / 1000;
    final sizes = [
      for (final w in candidates)
        TwoWireSizeCheck(
          wireId: w.id.isEmpty ? null : w.id,
          worstVolts: volts(worstDrop, w),
          ok: volts(worstDrop, w) >= spec.minVolts - 1e-9,
          maxDistanceM: worstDrop > 0 && w.ohmPerKm > 0 ? farthest * (spec.outputVolts - spec.minVolts) / (worstDrop * w.ohmPerKm / 1000) : double.infinity,
        ),
    ];
    WireSpec? chosen;
    for (var i = 0; i < candidates.length; i++) {
      if (!sizes[i].ok) continue;
      final w = candidates[i];
      if (chosen == null || w.costPerM < chosen.costPerM - 1e-12) chosen = w;
    }
    final wire = chosen ?? candidates.last;
    final check = sizes[candidates.indexOf(wire)];
    // stations along the path; the heads of a station share its number
    var station = 0;
    final numberOf = <String, int>{};
    final valveOf = {for (final v in mine) v.id: v};
    for (final (id, n, s) in ordered) {
      final k = decoderOf[id]!;
      final host = decoders[k].$1;
      final u = volts(openingDrop[id] ?? 0, wire);
      final ok = u >= spec.minVolts - 1e-9;
      if (!ok) result.warnings.add('twowire_voltage:$id');
      final v = valveOf[id];
      result.stations.add(
        TwoWireStation(
          valveId: id,
          zoneName: v == null ? vih.nameOf(s) : (v.zoneName.isNotEmpty ? v.zoneName : v.name),
          controllerId: c.id,
          decoderId: decoderIds[k],
          station: numberOf.putIfAbsent(s, () => ++station),
          routeM: dist[host]!,
          solenoidCableM: treeDistance(host, n) * slack,
          volts: u,
          ok: ok,
          openTogether: openWith[id] ?? 1,
        ),
      );
    }
    for (var k = 0; k < decoders.length; k++) {
      final (host, members, outputs) = decoders[k];
      result.decoders.add(
        TwoWireDecoder(
          id: decoderIds[k],
          controllerId: c.id,
          p: g.nodes[host],
          capacity: caps.firstWhere((x) => x >= outputs.length, orElse: () => caps.last),
          valveIds: [...members],
          routeM: dist[host]!,
          volts: volts(decoderDrop[k], wire),
        ),
      );
    }
    if (wire.id.isNotEmpty) result.wireMeters[wire.id] = (result.wireMeters[wire.id] ?? 0) + 2 * treeLength * slack;
    result.paths.add(
      TwoWirePath(
        controllerId: c.id,
        name: c.name,
        stations: c.stations,
        used: mine.length + myStations.length,
        wireId: wire.id.isEmpty ? null : wire.id,
        routeM: treeLength,
        cableM: treeLength * slack,
        decoders: decoders.length,
        maxOpen: maxOpen,
        peakCurrentA: peak,
        worstVolts: check.worstVolts,
        maxDistanceM: check.maxDistanceM,
        sizes: sizes,
      ),
    );
    // grounding points: the controller, every N decoders or M metres, the ends
    final decodersAt = <int, List<int>>{};
    for (var k = 0; k < decoders.length; k++) {
      decodersAt.putIfAbsent(decoders[k].$1, () => []).add(k);
    }
    result.grounds.add(TwoWireGround(controllerId: c.id, p: g.nodes[root], kind: GroundKind.controller, decoderId: decodersAt[root] != null ? decoderIds[decodersAt[root]!.first] : null));
    // depth first from the controller with the decoders and metres since the
    // last grounding point
    final todo = <(int, int, double)>[(root, 0, 0)];
    while (todo.isNotEmpty) {
      final (n, count, metres) = todo.removeLast();
      final ch = children[n] ?? const <int>[];
      for (var i = ch.length - 1; i >= 0; i--) {
        final m = ch[i];
        final e = g.edge(parentEdge[m]!);
        final a = g.nodes[n], b = g.nodes[m];
        var cnt = count, run = metres, along = 0.0;
        if (spec.groundEveryM > 0) {
          // points inside the stretch
          while (true) {
            final next = along + spec.groundEveryM - run;
            if (next >= e.length - 1e-9) break;
            result.grounds.add(TwoWireGround(controllerId: c.id, p: Pt.lerp(a, b, next / e.length), kind: GroundKind.interval));
            along = next;
            run = 0;
            cnt = 0;
          }
        }
        run += e.length - along;
        final here = decodersAt[m] ?? const <int>[];
        cnt += here.length;
        final leaf = (children[m] ?? const <int>[]).isEmpty;
        final due = (spec.groundEveryDecoders > 0 && cnt >= spec.groundEveryDecoders) || (spec.groundEveryM > 0 && run >= spec.groundEveryM - 1e-9);
        if (leaf || due) {
          result.grounds.add(TwoWireGround(controllerId: c.id, p: b, kind: leaf ? GroundKind.end : GroundKind.interval, decoderId: here.isEmpty ? null : decoderIds[here.first]));
          todo.add((m, 0, 0));
        } else {
          todo.add((m, cnt, run));
        }
      }
    }
  }
  return result;
}

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
