/// Hydraulic transients, air valve placement and the 24-hour extended-period
/// simulation of the mainline of a project, built on the steady mainline of
/// every system flow exactly as the design analyses it
/// ([Designer.mainlineNetworkFor]).
///
/// - [TransientStudy] runs the method of characteristics of `transient.dart`
///   for the scenarios a designer checks on an irrigation mainline: the zone
///   valves of a system flow closing in the closure time of the design
///   parameters (the zones seen from the mainline as orifices whose opening
///   falls to zero), a power failure tripping every pump of the flow (inertia
///   of pump and motor by Thorley & Faithfull 1992 from the rated power and
///   speed, or given) and an isolation valve closing. Every pipe takes its
///   wave celerity from its catalogue wall (Korteweg formula), its physical
///   length and its pressure class at the water temperature; the air release
///   devices drawn on the mainline act as combination air valves; the
///   barometric head follows the site elevation and the vapour pressure the
///   water temperature. Per pipe entity it keeps the transient head and
///   pressure envelopes against the class and against vacuum, the vapour
///   cavities, the profile along the critical path and the pressure in time
///   at the pump discharge and at the worst point (Wylie & Streeter 1993,
///   *Fluid Transients in Systems*; Chaudhry 2014, *Applied Hydraulic
///   Transients*).
/// - [suggestMainlineAirValves] builds the profile of every path from a water
///   supply to an end of the mainline (pipe and ground elevations, the lowest
///   steady grade line of the flows, the transient minimum envelope when one
///   is given, bores, pumps and check valves) and places and sizes air valves
///   on it by the practice of AWWA Manual M51 (`air_valves.dart`), with world
///   positions on the pipes and the catalogue item that fits.
/// - [simulateDay] runs the system flows over a day at their start hours and
///   durations (`eps.dart`), every pump on while one of the flows it serves
///   runs, with the energy and its cost at the tariff of the parameters and
///   an optional peak band.
///
/// Pure Dart: the dialogs of the app, the tests and a worker can use it.
library;

import 'dart:math' as math;

import '../hydraulics/eps.dart';
import '../hydraulics/minor_losses.dart';
import '../hydraulics/network.dart';
import '../hydraulics/pump.dart';
import '../hydraulics/transient.dart';
import '../hydraulics/water_hammer.dart';
import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/geometry.dart';
import '../model/project.dart';
import '../units.dart';
import 'air_valves.dart';
import 'designer.dart';
import 'network_builder.dart';
import 'results.dart';

// ---------------------------------------------------------------- shared

/// JSON cannot hold NaN or infinities: they travel as null.
Object? _jd(double v) => v.isFinite ? v : null;
double _rd(Map<String, dynamic> j, String k, [double def = 0]) => (j[k] as num?)?.toDouble() ?? def;
double _rn(Map<String, dynamic> j, String k) => (j[k] as num?)?.toDouble() ?? double.nan;
List<double> _dl(Object? v) => [for (final x in (v as List?) ?? const []) (x as num?)?.toDouble() ?? double.nan];
List<Object?> _jl(List<double> v) => [for (final x in v) _jd(x)];
Pt? _pt(Object? v) => v is List && v.length >= 2 ? Pt.fromList(v) : null;
List<String> _sl(Object? v) => [for (final x in (v as List?) ?? const []) '$x'];

void _addOnce(List<String> list, String m) {
  if (!list.contains(m)) list.add(m);
}

/// The steady mainline of one system flow: the network, its solution and
/// the demand of every zone valve or pivot it feeds (m³/s).
class MainlineFlowState {
  const MainlineFlowState(this.flow, this.network, this.steady, this.demand);
  final SystemFlow flow;
  final HydraulicNetwork network;
  final NetworkResult steady;
  final Map<String, double> demand;
}

/// The steady mainline of every system flow as the design analyses it,
/// shared by the transient, air valve and 24-hour studies. The zone and
/// pivot results of a finished design are reused, so the zones are not
/// analysed again (and the study sees the flows the design found).
class MainlineFlows {
  MainlineFlows(this.project, {DesignResults? results, String Function(String key)? label}) : designer = Designer(project, label: label) {
    if (results != null) {
      designer.results.zones.addAll(results.zones);
      designer.results.pivots.addAll(results.pivots);
    }
  }

  final Project project;
  final Designer designer;
  late final List<SystemFlow> flows = designer.effectiveSystemFlows();
  final Map<String, MainlineFlowState?> _states = {};

  NetworkModel get model => designer.model;

  /// The steady mainline of [f] (null without a water supply), computed once.
  MainlineFlowState? stateOf(SystemFlow f) => _states.putIfAbsent(f.id, () {
    final m = designer.mainlineNetworkFor(f);
    return m == null ? null : MainlineFlowState(f, m.$1, m.$2, m.$3);
  });

  /// Ground elevation of the site, for its barometric pressure: the first
  /// water supply, else the mean of the mainline.
  double get siteElevation {
    for (final id in model.supplyNodes.values) {
      final n = model.nodes[id];
      if (n != null) return n.ground;
    }
    var s = 0.0, k = 0;
    for (final id in model.mainlineNodes) {
      s += model.nodes[id]!.ground;
      k++;
    }
    return k == 0 ? 0 : s / k;
  }

  /// Head a demand (zone valve or pivot) requires at its mainline node, once
  /// its flow is known ([stateOf] computes it).
  double requiredHeadOf(String id) => designer.results.zones[id]?.requiredUpstreamHead ?? designer.results.pivots[id]?.inletHead ?? 0;

  /// Entity a node of the network stands for in messages: the mainline pipe
  /// that reaches it, else the item at it (satellite nodes of the designer,
  /// `<node>_s<k>`, belong to their node).
  String? entityOfNode(String nodeId) {
    final n = model.nodes[nodeId];
    if (n == null) {
      final i = nodeId.lastIndexOf('_s');
      return i > 0 ? entityOfNode(nodeId.substring(0, i)) : null;
    }
    for (final l in n.links) {
      if (l.kind == GLinkKind.pipe && model.mainlineLinks.contains(l.id)) return l.entityId;
    }
    for (final l in n.links) {
      if (model.mainlineLinks.contains(l.id)) return l.entityId;
    }
    return n.entityIds.isEmpty ? null : n.entityIds.first;
  }
}

/// Position at [x] metres along [l] from its `from` end (its drawn segment).
Pt _along(GLink l, double x) => l.length > 1e-9 ? Pt.lerp(l.a, l.b, (x / l.length).clamp(0.0, 1.0)) : l.a;

/// Minimal binary heap of (distance, node) for the shortest-path trees.
class _Heap {
  final _d = <double>[];
  final _n = <String>[];
  bool get isEmpty => _d.isEmpty;
  void push(double d, String n) {
    _d.add(d);
    _n.add(n);
    var i = _d.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (_d[p] <= _d[i]) break;
      _swap(i, p);
      i = p;
    }
  }

  (double, String) pop() {
    final top = (_d.first, _n.first);
    final last = _d.length - 1;
    _swap(0, last);
    _d.removeLast();
    _n.removeLast();
    var i = 0;
    while (true) {
      final l = 2 * i + 1, r = l + 1;
      var m = i;
      if (l < _d.length && _d[l] < _d[m]) m = l;
      if (r < _d.length && _d[r] < _d[m]) m = r;
      if (m == i) break;
      _swap(i, m);
      i = m;
    }
    return top;
  }

  void _swap(int a, int b) {
    final d = _d[a], n = _n[a];
    _d[a] = _d[b];
    _n[a] = _n[b];
    _d[b] = d;
    _n[b] = n;
  }
}

/// Shortest-path tree by physical length from the water supplies: the paths
/// water takes along a branched mainline (and a spanning tree of a looped one).
class _PathTree {
  _PathTree(Iterable<String> roots, this.edges) {
    final adj = <String, List<int>>{};
    for (var i = 0; i < edges.length; i++) {
      final (a, b, _) = edges[i];
      (adj[a] ??= []).add(i);
      (adj[b] ??= []).add(i);
    }
    final heap = _Heap();
    for (final r in roots) {
      dist[r] = 0;
      heap.push(0, r);
    }
    final done = <String>{};
    while (!heap.isEmpty) {
      final (d, n) = heap.pop();
      if (!done.add(n)) continue;
      for (final e in adj[n] ?? const <int>[]) {
        final (a, b, len) = edges[e];
        final o = a == n ? b : a;
        final nd = d + math.max(len, 0.0);
        if (nd < (dist[o] ?? double.infinity) - 1e-12) {
          dist[o] = nd;
          parent[o] = e;
          heap.push(nd, o);
        }
      }
    }
    for (final e in parent.entries) {
      final (a, b, _) = edges[e.value];
      (children[a == e.key ? b : a] ??= []).add(e.key);
    }
  }

  final List<(String, String, double)> edges;
  final dist = <String, double>{};
  final parent = <String, int>{};
  final children = <String, List<String>>{};

  /// Edges from the root to [node], with whether each is walked from its
  /// first end to its second.
  List<(int, bool)> pathTo(String node) {
    final out = <(int, bool)>[];
    var cur = node;
    var guard = 0;
    while (parent.containsKey(cur) && guard++ < 1000000) {
      final e = parent[cur]!;
      final (a, b, _) = edges[e];
      final up = a == cur ? b : a;
      out.add((e, b == cur));
      cur = up;
    }
    return out.reversed.toList();
  }

  /// The end farthest from the root among the nodes downstream of [node].
  String deepestBelow(String node) {
    var best = node, bestD = dist[node] ?? 0;
    final stack = [node];
    while (stack.isNotEmpty) {
      final n = stack.removeLast();
      final d = dist[n] ?? 0;
      if (d > bestD + 1e-9 || (n != node && (d - bestD).abs() <= 1e-9 && n.compareTo(best) < 0 && best != node)) {
        best = n;
        bestD = d;
      }
      stack.addAll(children[n] ?? const <String>[]);
    }
    return best;
  }

  /// Nodes of the tree without children (the ends of the line).
  List<String> get leaves => [
    for (final n in dist.keys)
      if (parent.containsKey(n) && (children[n] ?? const []).isEmpty) n,
  ];
}

// ---------------------------------------------------------------- transients

/// What disturbs the steady mainline of a system flow.
enum TransientScenario {
  /// The zone valves (and pivots) of the flow close in the closure time, and
  /// the heads of the valve-in-head stations it schedules.
  valveClosure,

  /// A power failure trips every running pump of the flow.
  pumpTrip,

  /// An isolation valve of the mainline closes.
  isolationClosure,
}

/// Settings of a [TransientStudy].
class TransientStudyOptions {
  const TransientStudyOptions({
    this.scenarios = const {TransientScenario.valveClosure},
    this.flowIds,
    this.closureTime,
    this.isolationId,
    this.isolationClosureTime,
    this.motorPoles = 2,
    this.speedRpm,
    this.inertia,
    this.duration,
    this.maxDuration = 120,
    this.columnSeparation = true,
    this.airValves = true,
    this.maxWork = 2e7,
    this.samples = 400,
  });

  final Set<TransientScenario> scenarios;

  /// System flows to analyse (null = every one).
  final Set<String>? flowIds;

  /// Closure time of the zone valves (s); null = the design parameters'.
  final double? closureTime;

  /// The isolation device (a mainline item whose catalogue kind is an
  /// isolation or master valve) of [TransientScenario.isolationClosure], and
  /// its closure time (s; null = [closureTime]).
  final String? isolationId;
  final double? isolationClosureTime;

  /// Poles of the pump motors (2: 3500 rpm on 60 Hz mains, 2900 on 50 Hz;
  /// 4: 1750 or 1450) unless [speedRpm] gives the speed.
  final int motorPoles;
  final double? speedRpm;

  /// Moment of inertia of every pump and its motor (kg·m²); null or 0 =
  /// estimated from the rated power and speed (Thorley & Faithfull 1992).
  final double? inertia;

  /// Simulated time (s); null or 0 = automatic: the event plus six periods
  /// 4L/a of the longest path, at least 15 s and at most [maxDuration].
  final double? duration;
  final double maxDuration;

  /// Vapour cavities (discrete vapour cavity model) where the pressure falls
  /// to the vapour pressure.
  final bool columnSeparation;

  /// The air release devices drawn on the mainline act as air valves.
  final bool airValves;

  /// Work budget of the method of characteristics (grid points × steps).
  final double maxWork;

  /// Samples kept of every time series.
  final int samples;

  /// Running speed (rpm) of an induction motor of [poles] poles on [hz]
  /// mains: the synchronous 120·f/p less about 3 % slip, to the nearest 50.
  static double speedForPoles(int poles, [double hz = 60]) => ((120 * hz / math.max(poles, 2) * 0.97) / 50).round() * 50.0;

  double pumpSpeedRpmAt(double mainsHz) => speedRpm != null && speedRpm! > 0 ? speedRpm! : speedForPoles(motorPoles, mainsHz);
}

/// One simulation of a study: a scenario on a system flow.
class TransientJob {
  const TransientJob(this.flow, this.scenario);
  final SystemFlow flow;
  final TransientScenario scenario;
}

/// Transient envelope of a pipe entity (all its segments).
class TransientPipeEnvelope {
  const TransientPipeEnvelope({
    required this.entityId,
    this.pipeName = '',
    this.rating = 0,
    required this.steadyMaxPressure,
    required this.steadyMinPressure,
    required this.maxPressure,
    required this.minPressure,
    required this.maxHead,
    required this.minHead,
    this.maxAt,
    this.minAt,
    this.columnSeparation = false,
    this.vapourGauge = -10,
    this.maxRun = -1,
    this.minRun = -1,
  });

  final String entityId;
  final String pipeName;

  /// Pressure class at the water temperature (m; 0 = unknown).
  final double rating;

  /// Pressure heads (m) of the steady state and of the transient envelopes,
  /// and the transient heads (m).
  final double steadyMaxPressure, steadyMinPressure, maxPressure, minPressure, maxHead, minHead;

  /// Where the extremes happen.
  final Pt? maxAt, minAt;

  /// A vapour cavity formed on the pipe or at its ends.
  final bool columnSeparation;

  /// Gauge vapour pressure head of the run (m, about −10).
  final double vapourGauge;

  /// Runs of a [TransientAnalysis] where the maximum and the minimum happen.
  final int maxRun, minRun;

  bool get overRating => rating > 0 && maxPressure > rating + 1e-6;

  /// Below atmospheric pressure in the transient, beyond what the steady
  /// state already has (a suction pipe runs below atmospheric anyway).
  bool get belowAtmosphere => minPressure < -0.01 && minPressure < steadyMinPressure - 0.01;

  /// Full vacuum: the vapour pressure reached, the liquid column separates.
  bool get vacuum => columnSeparation || minPressure <= vapourGauge + 0.05;

  bool get ok => !overRating && !vacuum && !belowAtmosphere;

  Map<String, dynamic> toJson() => {
    'id': entityId,
    'name': pipeName,
    'pn': rating,
    'p0max': steadyMaxPressure,
    'p0min': steadyMinPressure,
    'pmax': maxPressure,
    'pmin': minPressure,
    'hmax': maxHead,
    'hmin': minHead,
    if (maxAt != null) 'atMax': maxAt!.toList(),
    if (minAt != null) 'atMin': minAt!.toList(),
    'cav': columnSeparation,
    'hv': vapourGauge,
    'rMax': maxRun,
    'rMin': minRun,
  };

  static TransientPipeEnvelope fromJson(Map<String, dynamic> j) => TransientPipeEnvelope(
    entityId: j['id'] as String,
    pipeName: j['name'] as String? ?? '',
    rating: _rd(j, 'pn'),
    steadyMaxPressure: _rd(j, 'p0max'),
    steadyMinPressure: _rd(j, 'p0min'),
    maxPressure: _rd(j, 'pmax'),
    minPressure: _rd(j, 'pmin'),
    maxHead: _rd(j, 'hmax'),
    minHead: _rd(j, 'hmin'),
    maxAt: _pt(j['atMax']),
    minAt: _pt(j['atMin']),
    columnSeparation: j['cav'] as bool? ?? false,
    vapourGauge: _rd(j, 'hv', -10),
    maxRun: (j['rMax'] as num?)?.toInt() ?? -1,
    minRun: (j['rMin'] as num?)?.toInt() ?? -1,
  );
}

/// Pressure in time at a point of the mainline.
class TransientTrace {
  const TransientTrace({
    required this.nodeId,
    this.entityId,
    this.position,
    required this.elevation,
    required this.times,
    required this.heads,
    required this.pressures,
    this.flows = const [],
    this.speeds = const [],
  });
  final String nodeId;
  final String? entityId;
  final Pt? position;
  final double elevation;

  /// Sample times (s), heads and pressure heads (m).
  final List<double> times, heads, pressures;

  /// Flow (m³/s) and speed ratio of the pump of a pump discharge trace.
  final List<double> flows, speeds;

  Map<String, dynamic> toJson() => {
    'node': nodeId,
    if (entityId != null) 'e': entityId,
    if (position != null) 'p': position!.toList(),
    'z': elevation,
    't': _jl(times),
    'h': _jl(heads),
    'pr': _jl(pressures),
    if (flows.isNotEmpty) 'q': _jl(flows),
    if (speeds.isNotEmpty) 'w': _jl(speeds),
  };

  static TransientTrace fromJson(Map<String, dynamic> j) => TransientTrace(
    nodeId: j['node'] as String? ?? '',
    entityId: j['e'] as String?,
    position: _pt(j['p']),
    elevation: _rd(j, 'z'),
    times: _dl(j['t']),
    heads: _dl(j['h']),
    pressures: _dl(j['pr']),
    flows: _dl(j['q']),
    speeds: _dl(j['w']),
  );
}

/// Kinds of points worth showing on the drawing.
enum TransientFindingKind { overpressure, vacuum, columnSeparation, airAdmitted }

/// A point of the mainline where the transient does something notable.
class TransientFinding {
  const TransientFinding({required this.kind, this.entityId, this.position, this.value = 0});
  final TransientFindingKind kind;
  final String? entityId;
  final Pt? position;

  /// Pressure head (m) of an overpressure or vacuum, volume (m³) of a vapour
  /// cavity or of the air admitted.
  final double value;

  Map<String, dynamic> toJson() => {'k': kind.name, if (entityId != null) 'e': entityId, if (position != null) 'p': position!.toList(), 'v': _jd(value)};
  static TransientFinding fromJson(Map<String, dynamic> j) =>
      TransientFinding(kind: TransientFindingKind.values.asNameMap()[j['k']] ?? TransientFindingKind.vacuum, entityId: j['e'] as String?, position: _pt(j['p']), value: _rd(j, 'v'));
}

/// A point of the profile along the critical path.
class TransientProfilePoint {
  const TransientProfilePoint({
    required this.chainage,
    required this.elevation,
    required this.ground,
    required this.steadyHead,
    required this.maxHead,
    required this.minHead,
    this.ratingHead = double.nan,
    this.entityId,
    this.position,
  });

  /// Distance from the water supply (m).
  final double chainage;

  /// Pipe and ground elevations, steady head and transient envelopes (m).
  final double elevation, ground, steadyHead, maxHead, minHead;

  /// Elevation plus the pressure class (NaN on devices and unrated pipes).
  final double ratingHead;
  final String? entityId;
  final Pt? position;

  Map<String, dynamic> toJson() => {
    'x': chainage,
    'z': elevation,
    'g': ground,
    'h0': steadyHead,
    'hx': maxHead,
    'hn': minHead,
    'hr': _jd(ratingHead),
    if (entityId != null) 'e': entityId,
    if (position != null) 'p': position!.toList(),
  };
  static TransientProfilePoint fromJson(Map<String, dynamic> j) => TransientProfilePoint(
    chainage: _rd(j, 'x'),
    elevation: _rd(j, 'z'),
    ground: _rd(j, 'g'),
    steadyHead: _rd(j, 'h0'),
    maxHead: _rd(j, 'hx'),
    minHead: _rd(j, 'hn'),
    ratingHead: _rn(j, 'hr'),
    entityId: j['e'] as String?,
    position: _pt(j['p']),
  );
}

/// Result of one [TransientJob].
class TransientRun {
  const TransientRun({
    required this.flowId,
    required this.flowName,
    required this.scenario,
    this.targetId,
    this.skipped,
    this.closureTime = 0,
    this.duration = 0,
    this.timeStep = 0,
    this.steps = 0,
    this.barometricHead = 10.33,
    this.vapourGauge = -10.09,
    this.maxSurge = 0,
    this.maxSurgeEntity,
    this.pipes = const [],
    this.profile = const [],
    this.source,
    this.worst,
    this.findings = const [],
    this.checkValves = const {},
    this.nodeMinHeads = const {},
    this.nodeMaxHeads = const {},
    this.messages = const [],
  });

  final String flowId, flowName;
  final TransientScenario scenario;

  /// The isolation device of [TransientScenario.isolationClosure].
  final String? targetId;

  /// Why the run did not simulate (a message code), null when it did.
  final String? skipped;

  /// Closure time of the valves (s), simulated time (s), the common time
  /// step (s) and the number of steps.
  final double closureTime, duration, timeStep;
  final int steps;

  /// Atmospheric pressure head and gauge vapour pressure head (m).
  final double barometricHead, vapourGauge;

  /// Largest head rise above the steady state (m) and where.
  final double maxSurge;
  final String? maxSurgeEntity;

  final List<TransientPipeEnvelope> pipes;

  /// Along the critical path: from the water supply through the worst point.
  final List<TransientProfilePoint> profile;

  /// Pressure in time at the pump discharge (or the start of the line
  /// without a pump) and at the worst point.
  final TransientTrace? source, worst;
  final List<TransientFinding> findings;

  /// Time (s) of the first closure of every check valve (pumps, check valve
  /// devices), by entity.
  final Map<String, double> checkValves;

  /// Transient head envelopes by node of the network (m).
  final Map<String, double> nodeMinHeads, nodeMaxHeads;

  /// Message codes with entity ids (`transient_overpressure:<pipe>` …).
  final List<String> messages;

  bool get ran => skipped == null;
  double get maxPressure => pipes.fold(-double.infinity, (m, p) => math.max(m, p.maxPressure));
  double get minPressure => pipes.fold(double.infinity, (m, p) => math.min(m, p.minPressure));
  int get overRatingCount => pipes.where((p) => p.overRating).length;
  int get vacuumCount => pipes.where((p) => p.vacuum).length;

  /// How bad the run is, to show the worst one first: pipes above their
  /// class or in vacuum count most, then the largest share of the class.
  double get severity {
    if (!ran) return -1;
    var share = 0.0;
    for (final p in pipes) {
      if (p.rating > 0) share = math.max(share, p.maxPressure / p.rating);
    }
    return 1000.0 * (overRatingCount + vacuumCount) + 10.0 * pipes.where((p) => p.belowAtmosphere).length + share;
  }

  Map<String, dynamic> toJson() => {
    'flow': flowId,
    'name': flowName,
    'sc': scenario.name,
    if (targetId != null) 'target': targetId,
    if (skipped != null) 'skip': skipped,
    'tc': closureTime,
    'T': duration,
    'dt': timeStep,
    'n': steps,
    'hb': barometricHead,
    'hv': vapourGauge,
    'surge': maxSurge,
    if (maxSurgeEntity != null) 'surgeAt': maxSurgeEntity,
    'pipes': [for (final p in pipes) p.toJson()],
    'profile': [for (final p in profile) p.toJson()],
    if (source != null) 'src': source!.toJson(),
    if (worst != null) 'worst': worst!.toJson(),
    'find': [for (final f in findings) f.toJson()],
    'cv': checkValves,
    'hmin': {for (final e in nodeMinHeads.entries) e.key: _jd(e.value)},
    'hmax': {for (final e in nodeMaxHeads.entries) e.key: _jd(e.value)},
    'msg': messages,
  };

  static TransientRun fromJson(Map<String, dynamic> j) {
    Map<String, double> m(Object? v) => {for (final e in ((v as Map?) ?? const {}).entries) '${e.key}': (e.value as num?)?.toDouble() ?? double.nan};
    return TransientRun(
      flowId: j['flow'] as String? ?? '',
      flowName: j['name'] as String? ?? '',
      scenario: TransientScenario.values.asNameMap()[j['sc']] ?? TransientScenario.valveClosure,
      targetId: j['target'] as String?,
      skipped: j['skip'] as String?,
      closureTime: _rd(j, 'tc'),
      duration: _rd(j, 'T'),
      timeStep: _rd(j, 'dt'),
      steps: (j['n'] as num?)?.toInt() ?? 0,
      barometricHead: _rd(j, 'hb', 10.33),
      vapourGauge: _rd(j, 'hv', -10.09),
      maxSurge: _rd(j, 'surge'),
      maxSurgeEntity: j['surgeAt'] as String?,
      pipes: [for (final p in (j['pipes'] as List?) ?? const []) TransientPipeEnvelope.fromJson(p as Map<String, dynamic>)],
      profile: [for (final p in (j['profile'] as List?) ?? const []) TransientProfilePoint.fromJson(p as Map<String, dynamic>)],
      source: j['src'] is Map ? TransientTrace.fromJson(j['src'] as Map<String, dynamic>) : null,
      worst: j['worst'] is Map ? TransientTrace.fromJson(j['worst'] as Map<String, dynamic>) : null,
      findings: [for (final f in (j['find'] as List?) ?? const []) TransientFinding.fromJson(f as Map<String, dynamic>)],
      checkValves: m(j['cv']),
      nodeMinHeads: m(j['hmin']),
      nodeMaxHeads: m(j['hmax']),
      messages: _sl(j['msg']),
    );
  }
}

/// Every run of a study and the worst envelope of every pipe over them.
class TransientAnalysis {
  const TransientAnalysis({required this.runs, required this.pipes, required this.messages, required this.nodeMinHeads, required this.nodeMaxHeads});
  final List<TransientRun> runs;

  /// Worst over the runs ([TransientPipeEnvelope.maxRun] / [TransientPipeEnvelope.minRun] tell which).
  final List<TransientPipeEnvelope> pipes;
  final List<String> messages;

  /// Lowest and highest transient head of every node over the runs (m): the
  /// minimum envelope the air valve placement checks against vacuum.
  final Map<String, double> nodeMinHeads, nodeMaxHeads;

  /// Index of the most severe run that simulated (-1 when none did).
  int get worstRun {
    var best = -1;
    var s = -double.infinity;
    for (var i = 0; i < runs.length; i++) {
      final v = runs[i].severity;
      if (runs[i].ran && v > s) {
        s = v;
        best = i;
      }
    }
    return best;
  }

  Map<String, dynamic> toJson() => {
    'runs': [for (final r in runs) r.toJson()],
    'pipes': [for (final p in pipes) p.toJson()],
    'msg': messages,
    'hmin': {for (final e in nodeMinHeads.entries) e.key: _jd(e.value)},
    'hmax': {for (final e in nodeMaxHeads.entries) e.key: _jd(e.value)},
  };

  static TransientAnalysis fromJson(Map<String, dynamic> j) {
    Map<String, double> m(Object? v) => {for (final e in ((v as Map?) ?? const {}).entries) '${e.key}': (e.value as num?)?.toDouble() ?? double.nan};
    return TransientAnalysis(
      runs: [for (final r in (j['runs'] as List?) ?? const []) TransientRun.fromJson(r as Map<String, dynamic>)],
      pipes: [for (final p in (j['pipes'] as List?) ?? const []) TransientPipeEnvelope.fromJson(p as Map<String, dynamic>)],
      messages: _sl(j['msg']),
      nodeMinHeads: m(j['hmin']),
      nodeMaxHeads: m(j['hmax']),
    );
  }
}

/// Accumulates the envelope of a pipe entity over its segments (or runs).
class _PipeAcc {
  _PipeAcc(this.entityId, this.name, this.vapourGauge);
  final String entityId;
  String name;
  final double vapourGauge;
  double rating = 0;
  double p0max = -double.infinity, p0min = double.infinity, pmax = -double.infinity, pmin = double.infinity, hmax = -double.infinity, hmin = double.infinity;
  Pt? atMax, atMin;
  bool cavity = false;
  int maxRun = -1, minRun = -1;

  void rate(double r) {
    if (r > 0 && (rating <= 0 || r < rating)) rating = r;
  }

  TransientPipeEnvelope build() => TransientPipeEnvelope(
    entityId: entityId,
    pipeName: name,
    rating: rating,
    steadyMaxPressure: p0max.isFinite ? p0max : 0,
    steadyMinPressure: p0min.isFinite ? p0min : 0,
    maxPressure: pmax.isFinite ? pmax : 0,
    minPressure: pmin.isFinite ? pmin : 0,
    maxHead: hmax.isFinite ? hmax : 0,
    minHead: hmin.isFinite ? hmin : 0,
    maxAt: atMax,
    minAt: atMin,
    columnSeparation: cavity,
    vapourGauge: vapourGauge,
    maxRun: maxRun,
    minRun: minRun,
  );
}

/// Transient simulations of the mainline of a project: [jobs] lists the
/// (system flow, scenario) pairs the options ask for, [run] simulates one
/// (so an interface can show progress between them) and [analyze] all.
class TransientStudy {
  TransientStudy(Project project, {DesignResults? results, TransientStudyOptions options = const TransientStudyOptions(), String Function(String key)? label})
    : this.on(
        MainlineFlows(project, results: results, label: label),
        options: options,
      );

  TransientStudy.on(this.mainline, {this.options = const TransientStudyOptions()});

  final MainlineFlows mainline;
  final TransientStudyOptions options;

  late final List<TransientJob> jobs = [
    for (final f in mainline.flows)
      if (options.flowIds == null || options.flowIds!.contains(f.id))
        for (final s in TransientScenario.values)
          if (options.scenarios.contains(s)) TransientJob(f, s),
  ];

  /// Every job, combined.
  TransientAnalysis analyze() => combine([for (final j in jobs) run(j)]);

  /// Simulates [job].
  TransientRun run(TransientJob job) {
    final f = job.flow;
    final project = mainline.project;
    final params = project.params;
    final d = mainline.designer;
    final model = mainline.model;
    final closure = math.max(0.0, options.closureTime ?? params.valveClosureTimeS);
    TransientRun skip(String code) => TransientRun(
      flowId: f.id,
      flowName: f.name,
      scenario: job.scenario,
      targetId: job.scenario == TransientScenario.isolationClosure ? options.isolationId : null,
      skipped: code,
      closureTime: closure,
    );
    final st = mainline.stateOf(f);
    if (st == null) return skip('no_water_supply');
    final net = st.network, steady = st.steady;
    final messages = <String>[];

    // pipes: celerity from the wall, physical length, class at the water temperature
    final data = <String, TransientLinkData>{};
    final ratingOf = <String, double>{};
    final specName = <String, String>{};
    for (final l in net.links) {
      if (l.kind != HLinkKind.pipe) continue;
      final gl = l.tag;
      if (gl is! GLink) {
        // a satellite of the designer (1 cm to a second emitter kind)
        data[l.id] = TransientLinkData(length: l.length);
        continue;
      }
      final spec = d.specOf(gl);
      if (spec == null) {
        data[l.id] = TransientLinkData(length: gl.length);
        _addOnce(messages, 'transient_pipe_unsized:${gl.entityId}');
        continue;
      }
      final rating = spec.ratingAt(params.waterTempC);
      ratingOf[l.id] = rating;
      specName[gl.entityId] = spec.name;
      final wall = math.max(spec.wallThicknessMm, 0.5) / 1000;
      data[l.id] = TransientLinkData.fromPipe(
        diameter: spec.innerDiameter,
        wallThickness: wall,
        material: spec.material,
        length: gl.length,
        rating: rating > 0 ? rating : null,
        // a thin wall collapses below the atmosphere by its buckling head
        // (never filled in: only the vapour limit was checked)
        minRating: -collapsePressureHead(diameter: spec.innerDiameter, wallThickness: wall, material: spec.material),
      );
    }

    // air release devices drawn on the mainline: combination air valves at
    // their upstream node, both orifices of the nominal size
    final airValves = <AirValve>[];
    final airEntityAt = <String, String>{};
    if (options.airValves) {
      for (final l in net.links) {
        final gl = l.tag;
        if (gl is! GLink || gl.kind != GLinkKind.device) continue;
        final spec = project.catalog.valve(gl.valveSpecId);
        if (spec == null || spec.kind != ValveKind.airRelease) continue;
        final dia = (spec.sizeMm > 0 ? spec.sizeMm : 50) / 1000;
        airValves.add(AirValve(nodeId: l.from, inflowDiameter: dia, outflowDiameter: dia));
        airEntityAt[l.from] = gl.entityId;
      }
    }

    // the event
    final events = <TransientEvent>[];
    var span = closure;
    switch (job.scenario) {
      case TransientScenario.valveClosure:
        final nodes = <String>{};
        for (final id in st.demand.keys) {
          final n = d.demandNodeOf(id);
          if (n != null && net.nodes.containsKey(n) && net.nodes[n]!.demand > 0) nodes.add(n);
        }
        // the heads of the valve-in-head stations the flow schedules close
        // with their valves (their node, or the satellite of a second kind
        // of head there); a station no flow lists runs on, as mainline
        // outlets always did
        final heads = d.scheduledHeadNodes(f);
        for (final n in net.nodes.values) {
          if (n.emitter == null || n.emitterCount <= 0) continue;
          final i = n.id.lastIndexOf('_s');
          if (heads.containsKey(n.id) || (i > 0 && !model.nodes.containsKey(n.id) && heads.containsKey(n.id.substring(0, i)))) nodes.add(n.id);
        }
        if (nodes.isEmpty) return skip('transient_no_valves');
        for (final n in nodes) {
          events.add(TransientEvent.demandStop(n, stopTime: closure, mode: DemandStopMode.orifice));
        }
      case TransientScenario.pumpTrip:
        final rpm = options.pumpSpeedRpmAt(project.params.mainsHz);
        for (final l in net.links) {
          if (l.kind != HLinkKind.pump) continue;
          final lr = steady.links[l.id];
          final q = lr?.flow ?? 0;
          if (q <= 1e-6) continue;
          final gl = l.tag is GLink ? l.tag as GLink : null;
          final spec = project.catalog.pump(gl?.pumpSpecId);
          final w = l.pump?.speedRatio ?? 1;
          final eff = (spec?.efficiencyAt(q, speed: w) ?? params.pumpEfficiency).clamp(0.05, 1.0).toDouble();
          // the inertia belongs to the machine: rated power and speed, even
          // when a drive runs it slower
          final given = options.inertia;
          final shaftKw = waterDensity * gravity * q * math.max(lr?.pumpHead ?? 0, 0.1) / eff / 1000;
          final inertia = given != null && given > 0 ? given : estimatePumpInertia(powerKw: spec != null && spec.powerKw > 0 ? spec.powerKw : shaftKw, speedRpm: rpm);
          events.add(TransientEvent.pumpTrip(l.id, inertia: inertia, speedRpm: rpm * w, efficiency: eff));
        }
        if (events.isEmpty) return skip('transient_no_pump');
        span = 5;
      case TransientScenario.isolationClosure:
        final id = options.isolationId;
        if (id == null) return skip('transient_no_isolation');
        HLink? link;
        for (final l in net.links) {
          final gl = l.tag;
          if (l.kind != HLinkKind.pipe && l.kind != HLinkKind.pump && gl is GLink && gl.entityId == id) link = l;
        }
        if (link == null) return skip('transient_no_isolation');
        if ((steady.links[link.id]?.flow ?? 0).abs() <= 1e-6) return skip('transient_isolation_no_flow:$id');
        span = math.max(0.0, options.isolationClosureTime ?? closure);
        events.add(TransientEvent.valveClosure(link.id, closureTime: span));
    }

    // the longest path and the slowest wave set the automatic duration
    final reservoirs = [
      for (final n in net.nodes.values)
        if (n.kind == HNodeKind.reservoir) n.id,
    ];
    final edges = <(String, String, double)>[for (final l in net.links) (l.from, l.to, l.kind == HLinkKind.pipe ? (data[l.id]?.length ?? l.length) : 0.0)];
    final tree = _PathTree(reservoirs, edges);
    final longest = tree.dist.values.fold(0.0, math.max);
    var aMin = double.infinity;
    for (final v in data.values) {
      final a = v.celerity;
      if (a != null && a > 0 && (v.length ?? 0) > 1) aMin = math.min(aMin, a);
    }
    if (!aMin.isFinite) aMin = 1000;
    final given = options.duration;
    final duration = given != null && given > 0 ? given : (span + 6 * 4 * longest / aMin + 5).clamp(15.0, math.max(15.0, options.maxDuration)).toDouble();

    final hb = atmosphericHead(mainline.siteElevation);
    final hv = vapourHead(params.waterTempC);
    final hvg = hv - hb;
    final nodeIds = [
      for (final n in net.nodes.values)
        if (n.kind != HNodeKind.reservoir) n.id,
    ];
    final pumpIds = [
      for (final l in net.links)
        if (l.kind == HLinkKind.pump) l.id,
    ];
    final probes = [for (final id in nodeIds) TransientProbe.node(id), for (final id in pumpIds) TransientProbe.link(id)];
    final samples = math.max(50, math.min(options.samples, (600000 / math.max(1, probes.length)).floor()));
    final sim = TransientModel.fromNetwork(net, steady, linkData: data, airValves: airValves).simulate(
      events: events,
      options: TransientOptions(
        duration: duration,
        barometricHead: hb,
        vapourHead: hv,
        columnSeparation: options.columnSeparation,
        probes: probes,
        recordInterval: duration / samples,
        maxWork: options.maxWork,
      ),
    );

    // with the cavity model no head falls below the vapour head: the bound
    // is kept for the envelopes interpolated between grid points
    double floor(double head, double z) => options.columnSeparation ? math.max(head, z + hvg) : head;
    final linkById = {for (final l in net.links) l.id: l};
    String? entityOfLink(String id) {
      final t = linkById[id]?.tag;
      if (t is GLink) return t.entityId;
      final l = linkById[id];
      return l == null ? null : mainline.entityOfNode(l.from);
    }

    // pipe envelopes by entity
    final acc = <String, _PipeAcc>{};
    final ratingAt = <String, double>{};
    for (final l in net.links) {
      if (l.kind != HLinkKind.pipe) continue;
      final gl = l.tag;
      final env = sim.links[l.id];
      if (gl is! GLink || env == null) continue;
      final a = acc.putIfAbsent(gl.entityId, () => _PipeAcc(gl.entityId, specName[gl.entityId] ?? '', hvg));
      final r = ratingOf[l.id] ?? 0;
      a.rate(r);
      if (r > 0) {
        for (final id in [l.from, l.to]) {
          ratingAt[id] = math.min(ratingAt[id] ?? double.infinity, r);
        }
      }
      for (final id in [l.from, l.to]) {
        final nr = steady.nodes[id];
        if (nr == null) continue;
        a.p0max = math.max(a.p0max, nr.pressure);
        a.p0min = math.min(a.p0min, nr.pressure);
      }
      for (final p in env.points) {
        final lo = floor(p.minHead, p.elevation);
        if (p.maxHead - p.elevation > a.pmax) {
          a.pmax = p.maxHead - p.elevation;
          a.atMax = _along(gl, p.chainage);
        }
        if (lo - p.elevation < a.pmin) {
          a.pmin = lo - p.elevation;
          a.atMin = _along(gl, p.chainage);
        }
        a.hmax = math.max(a.hmax, p.maxHead);
        a.hmin = math.min(a.hmin, lo);
        if (p.maxCavityVolume > 1e-12) a.cavity = true;
      }
    }

    // messages and findings by entity
    final findings = <TransientFinding>[];
    TransientPointEnvelope? pointOf(String linkId, double Function(TransientPointEnvelope p) score) {
      final env = sim.links[linkId];
      if (env == null || env.points.isEmpty) return null;
      return env.points.reduce((a, b) => score(b) > score(a) ? b : a);
    }

    Pt? atLink(String linkId, TransientPointEnvelope? p) {
      final gl = linkById[linkId]?.tag;
      return gl is GLink && p != null ? _along(gl, p.chainage) : null;
    }

    for (final m in sim.messages) {
      final i = m.indexOf(':');
      final code = i < 0 ? m : m.substring(0, i);
      final id = i < 0 ? '' : m.substring(i + 1);
      switch (code) {
        case 'transient_not_converged':
        case 'transient_steady_not_converged':
          _addOnce(messages, code);
        case 'transient_overpressure':
        case 'transient_underpressure':
        case 'transient_vacuum_pipe':
        case 'transient_column_separation_pipe':
        case 'transient_unknown_link':
        case 'transient_not_a_pump':
        case 'transient_not_a_valve':
        case 'transient_closed_link_flow':
          final e = entityOfLink(id);
          _addOnce(messages, e == null ? code : '$code:$e');
          if (code == 'transient_overpressure') {
            final p = pointOf(id, (p) => p.maxPressure);
            findings.add(TransientFinding(kind: TransientFindingKind.overpressure, entityId: e, position: atLink(id, p), value: p?.maxPressure ?? 0));
          } else if (code == 'transient_vacuum_pipe') {
            final p = pointOf(id, (p) => -p.minPressure);
            findings.add(TransientFinding(kind: TransientFindingKind.vacuum, entityId: e, position: atLink(id, p), value: p == null ? hvg : floor(p.minHead, p.elevation) - p.elevation));
          } else if (code == 'transient_column_separation_pipe') {
            final p = pointOf(id, (p) => p.maxCavityVolume);
            findings.add(TransientFinding(kind: TransientFindingKind.columnSeparation, entityId: e, position: atLink(id, p), value: p?.maxCavityVolume ?? 0));
          }
        case 'transient_air_admitted':
          final e = airEntityAt[id] ?? mainline.entityOfNode(id);
          _addOnce(messages, e == null ? code : '$code:$e');
          findings.add(TransientFinding(kind: TransientFindingKind.airAdmitted, entityId: e, position: model.nodes[id]?.p, value: sim.nodes[id]?.maxAirVolume ?? 0));
        default:
          final e = mainline.entityOfNode(id);
          _addOnce(messages, e == null || id.isEmpty ? code : '$code:$e');
          final env = sim.nodes[id];
          if (code == 'transient_vacuum') {
            findings.add(TransientFinding(kind: TransientFindingKind.vacuum, entityId: e, position: model.nodes[id]?.p, value: env == null ? hvg : floor(env.minHead, env.elevation) - env.elevation));
          } else if (code == 'transient_column_separation') {
            findings.add(TransientFinding(kind: TransientFindingKind.columnSeparation, entityId: e, position: model.nodes[id]?.p, value: env?.maxCavityVolume ?? 0));
          }
      }
    }

    // the largest surge, node heads, check valves
    var surge = 0.0;
    String? surgeAt;
    final nodeMin = <String, double>{}, nodeMax = <String, double>{};
    for (final e in sim.nodes.values) {
      nodeMin[e.nodeId] = floor(e.minHead, e.elevation);
      nodeMax[e.nodeId] = e.maxHead;
      if (e.maxHead - e.steadyHead > surge) {
        surge = e.maxHead - e.steadyHead;
        surgeAt = mainline.entityOfNode(e.nodeId);
      }
    }
    final checks = <String, double>{};
    for (final e in sim.checkValveClosures.entries) {
      final ent = entityOfLink(e.key);
      if (ent != null) checks.putIfAbsent(ent, () => e.value);
    }

    // the worst point: the deepest depression on the pressurised side, else
    // the highest pressure against the class of its pipes
    String? worstId;
    var worstMin = double.infinity;
    for (final id in nodeIds) {
      final e = sim.nodes[id];
      if (e == null || !model.nodes.containsKey(id) || e.steadyPressure < 0) continue;
      final p = floor(e.minHead, e.elevation) - e.elevation;
      if (p < worstMin - 1e-9) {
        worstMin = p;
        worstId = id;
      }
    }
    if (worstMin >= -0.5) {
      var best = -double.infinity;
      for (final id in nodeIds) {
        final e = sim.nodes[id];
        if (e == null || !model.nodes.containsKey(id)) continue;
        final r = ratingAt[id];
        final s = r != null && r.isFinite ? e.maxPressure - r : e.maxPressure - 1e6;
        if (s > best + 1e-9) {
          best = s;
          worstId = id;
        }
      }
    }

    TransientTrace? trace(String nodeId, {String? linkId, String? entity}) {
      final s = sim.seriesOf(nodeId);
      final n = net.nodes[nodeId];
      if (s == null || n == null) return null;
      final z = n.elevation;
      final heads = [for (final h in s.heads) floor(h, z)];
      final ls = linkId == null ? null : sim.seriesOf(linkId);
      return TransientTrace(
        nodeId: nodeId,
        entityId: entity ?? mainline.entityOfNode(nodeId),
        position: model.nodes[nodeId]?.p,
        elevation: z,
        times: [...sim.times],
        heads: heads,
        pressures: [for (final h in heads) h - z],
        flows: ls == null ? const [] : [...ls.flows],
        speeds: ls == null ? const [] : [...ls.speeds],
      );
    }

    // the pump discharge (the pump carrying most), else the start of the line
    TransientTrace? source;
    HLink? mainPump;
    for (final l in net.links) {
      if (l.kind != HLinkKind.pump) continue;
      if (mainPump == null || (steady.links[l.id]?.flow ?? 0) > (steady.links[mainPump.id]?.flow ?? 0)) mainPump = l;
    }
    if (mainPump != null) {
      final gl = mainPump.tag;
      source = trace(mainPump.to, linkId: mainPump.id, entity: gl is GLink ? gl.entityId : null);
    } else {
      HLink? first;
      for (final l in net.links) {
        final fromRes = net.nodes[l.from]?.kind == HNodeKind.reservoir, toRes = net.nodes[l.to]?.kind == HNodeKind.reservoir;
        if (fromRes == toRes) continue;
        if (first == null || (steady.links[l.id]?.flow.abs() ?? 0) > (steady.links[first.id]?.flow.abs() ?? 0)) first = l;
      }
      if (first != null) source = trace(net.nodes[first.from]?.kind == HNodeKind.reservoir ? first.to : first.from);
    }
    final worst = worstId == null ? null : trace(worstId);

    // profile along the critical path: from the supply through the worst
    // point to the farthest end beyond it
    final profile = <TransientProfilePoint>[];
    if (worstId != null && tree.dist.containsKey(worstId)) {
      final end = tree.deepestBelow(worstId);
      var ch = 0.0;
      for (final (e, forward) in tree.pathTo(end)) {
        final l = net.links[e];
        final from = forward ? l.from : l.to, to = forward ? l.to : l.from;
        final gl = l.tag is GLink ? l.tag as GLink : null;
        final env = sim.links[l.id];
        final len = edges[e].$3;
        final h0a = steady.nodes[from]?.head ?? 0, h0b = steady.nodes[to]?.head ?? 0;
        final ga = model.nodes[from]?.ground ?? net.nodes[from]?.elevation ?? 0, gb = model.nodes[to]?.ground ?? net.nodes[to]?.elevation ?? 0;
        final r = ratingOf[l.id] ?? 0;
        if (env != null && env.points.length >= 2 && l.kind == HLinkKind.pipe) {
          final total = env.points.last.chainage;
          final pts = forward ? env.points : env.points.reversed.toList();
          for (final p in pts) {
            final x = forward ? p.chainage : total - p.chainage;
            final w = total > 1e-9 ? (x / total).clamp(0.0, 1.0) : 0.0;
            profile.add(
              TransientProfilePoint(
                chainage: ch + (total > 1e-9 ? x / total * len : 0),
                elevation: p.elevation,
                ground: ga + (gb - ga) * w,
                steadyHead: h0a + (h0b - h0a) * w,
                maxHead: p.maxHead,
                minHead: floor(p.minHead, p.elevation),
                ratingHead: r > 0 ? p.elevation + r : double.nan,
                entityId: gl?.entityId,
                position: gl == null ? null : _along(gl, forward ? x / math.max(total, 1e-9) * gl.length : (total - x) / math.max(total, 1e-9) * gl.length),
              ),
            );
          }
        } else {
          for (final (id, g, h0) in [(from, ga, h0a), (to, gb, h0b)]) {
            final ne = sim.nodes[id];
            final z = net.nodes[id]?.elevation ?? 0;
            profile.add(
              TransientProfilePoint(
                chainage: ch,
                elevation: z,
                ground: g,
                steadyHead: h0,
                maxHead: ne?.maxHead ?? h0,
                minHead: floor(ne?.minHead ?? h0, z),
                entityId: gl?.entityId,
                position: model.nodes[id]?.p,
              ),
            );
          }
        }
        ch += len;
      }
    }

    return TransientRun(
      flowId: f.id,
      flowName: f.name,
      scenario: job.scenario,
      targetId: job.scenario == TransientScenario.isolationClosure ? options.isolationId : null,
      closureTime: job.scenario == TransientScenario.pumpTrip ? 0 : span,
      duration: sim.duration,
      timeStep: sim.timeStep,
      steps: sim.steps,
      barometricHead: hb,
      vapourGauge: hvg,
      maxSurge: surge,
      maxSurgeEntity: surgeAt,
      pipes: [for (final a in acc.values) a.build()],
      profile: profile,
      source: source,
      worst: worst,
      findings: findings,
      checkValves: checks,
      nodeMinHeads: nodeMin,
      nodeMaxHeads: nodeMax,
      messages: messages,
    );
  }

  /// The runs and the worst envelope of every pipe over them.
  static TransientAnalysis combine(List<TransientRun> runs) {
    final acc = <String, _PipeAcc>{};
    final messages = <String>[];
    final nodeMin = <String, double>{}, nodeMax = <String, double>{};
    for (var i = 0; i < runs.length; i++) {
      final r = runs[i];
      if (r.skipped != null) _addOnce(messages, r.skipped!);
      for (final m in r.messages) {
        _addOnce(messages, m);
      }
      for (final p in r.pipes) {
        final a = acc.putIfAbsent(p.entityId, () => _PipeAcc(p.entityId, p.pipeName, p.vapourGauge));
        a.rate(p.rating);
        a.p0max = math.max(a.p0max, p.steadyMaxPressure);
        a.p0min = math.min(a.p0min, p.steadyMinPressure);
        if (p.maxPressure > a.pmax) {
          a.pmax = p.maxPressure;
          a.atMax = p.maxAt;
          a.maxRun = i;
        }
        if (p.minPressure < a.pmin) {
          a.pmin = p.minPressure;
          a.atMin = p.minAt;
          a.minRun = i;
        }
        a.hmax = math.max(a.hmax, p.maxHead);
        a.hmin = math.min(a.hmin, p.minHead);
        a.cavity = a.cavity || p.columnSeparation;
      }
      for (final e in r.nodeMinHeads.entries) {
        if (e.value.isFinite) nodeMin[e.key] = math.min(nodeMin[e.key] ?? double.infinity, e.value);
      }
      for (final e in r.nodeMaxHeads.entries) {
        if (e.value.isFinite) nodeMax[e.key] = math.max(nodeMax[e.key] ?? -double.infinity, e.value);
      }
    }
    return TransientAnalysis(runs: runs, pipes: [for (final a in acc.values) a.build()], messages: messages, nodeMinHeads: nodeMin, nodeMaxHeads: nodeMax);
  }
}

/// Isolation devices of the mainline a [TransientScenario.isolationClosure]
/// can close: items whose catalogue kind is an isolation or master valve.
List<MiscHydraulicEntity> isolationDevices(Project project) => [
  for (final e in project.entities.whereType<MiscHydraulicEntity>())
    if (e.scope == HydraulicScope.mainline && (project.catalog.valve(e.valveSpecId)?.kind == ValveKind.isolation || project.catalog.valve(e.valveSpecId)?.kind == ValveKind.master)) e,
];

// ---------------------------------------------------------------- air valves

/// An air valve suggested on the mainline.
class MainlineAirValve {
  const MainlineAirValve({
    required this.position,
    required this.chainage,
    required this.path,
    required this.type,
    required this.reasons,
    required this.sizing,
    required this.elevation,
    required this.ground,
    this.pipeEntityId,
    this.specId,
    this.existingId,
  });

  /// Where on the drawing (on the pipe), and the distance from the water
  /// supply along path [path] of the study (m).
  final Pt position;
  final double chainage;
  final int path;
  final AirValveType type;

  /// Every reason, the main one first.
  final List<AirValveReason> reasons;
  final AirValveSizing sizing;

  /// Pipe and ground elevations (m).
  final double elevation, ground;

  /// The mainline pipe it sits on.
  final String? pipeEntityId;

  /// Catalogue air valve that fits (the smallest at least the nominal size,
  /// else the largest), null when the catalogue has none.
  final String? specId;

  /// An air valve already drawn within the merge distance.
  final String? existingId;

  AirValveReason get reason => reasons.first;
  String get code => 'air_valve_${reason.code}';
  bool get existing => existingId != null;

  MainlineAirValve copyWith({String? existingId, String? specId}) => MainlineAirValve(
    position: position,
    chainage: chainage,
    path: path,
    type: type,
    reasons: reasons,
    sizing: sizing,
    elevation: elevation,
    ground: ground,
    pipeEntityId: pipeEntityId,
    specId: specId ?? this.specId,
    existingId: existingId ?? this.existingId,
  );

  Map<String, dynamic> toJson() => {
    'p': position.toList(),
    'x': chainage,
    'path': path,
    'type': type.name,
    'why': [for (final r in reasons) r.name],
    'z': elevation,
    'g': ground,
    'size': {'large': sizing.largeOrifice, 'small': sizing.smallOrifice, 'dn': sizing.nominalSize, 'qd': sizing.drainFlow, 'qf': sizing.fillFlow, 'qa': sizing.releaseAirFlow},
    if (pipeEntityId != null) 'pipe': pipeEntityId,
    if (specId != null) 'spec': specId,
    if (existingId != null) 'existing': existingId,
  };

  static MainlineAirValve fromJson(Map<String, dynamic> j) {
    final s = (j['size'] as Map?)?.cast<String, dynamic>() ?? const {};
    return MainlineAirValve(
      position: _pt(j['p']) ?? Pt.zero,
      chainage: _rd(j, 'x'),
      path: (j['path'] as num?)?.toInt() ?? 0,
      type: AirValveType.values.asNameMap()[j['type']] ?? AirValveType.combination,
      reasons: [for (final r in (j['why'] as List?) ?? const []) ?AirValveReason.values.asNameMap()[r]],
      sizing: AirValveSizing(largeOrifice: _rd(s, 'large'), smallOrifice: _rd(s, 'small'), nominalSize: _rd(s, 'dn'), drainFlow: _rd(s, 'qd'), fillFlow: _rd(s, 'qf'), releaseAirFlow: _rd(s, 'qa')),
      elevation: _rd(j, 'z'),
      ground: _rd(j, 'g'),
      pipeEntityId: j['pipe'] as String?,
      specId: j['spec'] as String?,
      existingId: j['existing'] as String?,
    );
  }
}

/// A path of the air valve study: from a water supply to an end of the line.
class AirValvePath {
  const AirValvePath({required this.supplyId, required this.endEntityId, required this.length, required this.start});
  final String? supplyId;

  /// The item or pipe at the end of the path.
  final String? endEntityId;

  /// Length from the supply (m) and the chainage where the profile starts
  /// (the discharge of the first pump; the suction side is left out).
  final double length, start;

  Map<String, dynamic> toJson() => {if (supplyId != null) 'supply': supplyId, if (endEntityId != null) 'end': endEntityId, 'L': length, 'x0': start};
  static AirValvePath fromJson(Map<String, dynamic> j) => AirValvePath(supplyId: j['supply'] as String?, endEntityId: j['end'] as String?, length: _rd(j, 'L'), start: _rd(j, 'x0'));
}

/// Result of [suggestMainlineAirValves].
class AirValveStudy {
  const AirValveStudy({required this.suggestions, required this.paths, required this.messages, this.usedTransient = false});

  /// Merged over the paths, by path and chainage.
  final List<MainlineAirValve> suggestions;
  final List<AirValvePath> paths;

  /// `air_hgl_below_pipe:<pipe>`, `air_no_spec`, `air_valve_undersized`,
  /// `no_water_supply`.
  final List<String> messages;

  /// The transient minimum envelope took part (vacuum protection).
  final bool usedTransient;

  /// The suggestions without an air valve drawn yet.
  List<MainlineAirValve> get missing => [
    for (final s in suggestions)
      if (!s.existing) s,
  ];

  Map<String, dynamic> toJson() => {
    'sugg': [for (final s in suggestions) s.toJson()],
    'paths': [for (final p in paths) p.toJson()],
    'msg': messages,
    'tr': usedTransient,
  };
  static AirValveStudy fromJson(Map<String, dynamic> j) => AirValveStudy(
    suggestions: [for (final s in (j['sugg'] as List?) ?? const []) MainlineAirValve.fromJson(s as Map<String, dynamic>)],
    paths: [for (final p in (j['paths'] as List?) ?? const []) AirValvePath.fromJson(p as Map<String, dynamic>)],
    messages: _sl(j['msg']),
    usedTransient: j['tr'] as bool? ?? false,
  );
}

/// Air valves of the catalogue (enabled, kind air release), smallest first.
List<ValveSpec> airValveSpecs(Catalog catalog) => [
  for (final v in catalog.valves)
    if (v.enabled && v.kind == ValveKind.airRelease) v,
]..sort((a, b) => a.sizeMm.compareTo(b.sizeMm));

/// Air valves suggested on the mainline of [project] (see the library
/// documentation); [transient] adds the vacuum protection of its minimum
/// envelope. Without [options] the defaults of AWWA M51 apply, with the
/// barometric pressure of the site elevation.
AirValveStudy suggestMainlineAirValves(Project project, {DesignResults? results, TransientAnalysis? transient, AirValveOptions? options, String Function(String key)? label}) =>
    suggestMainlineAirValvesOn(
      MainlineFlows(project, results: results, label: label),
      transient: transient,
      options: options,
    );

/// [suggestMainlineAirValves] on prepared mainline flows.
AirValveStudy suggestMainlineAirValvesOn(MainlineFlows mainline, {TransientAnalysis? transient, AirValveOptions? options}) {
  final project = mainline.project;
  final model = mainline.model;
  final catalog = project.catalog;
  final messages = <String>[];
  final states = [for (final f in mainline.flows) ?mainline.stateOf(f)];
  if (states.isEmpty) return const AirValveStudy(suggestions: [], paths: [], messages: ['no_water_supply']);
  final o = options ?? AirValveOptions(barometricHead: atmosphericHead(mainline.siteElevation));

  // the lowest steady grade line of the flows and the largest flow of every link
  final hgl = <String, double>{};
  final flowOf = <String, double>{};
  for (final s in states) {
    for (final e in s.steady.nodes.entries) {
      hgl[e.key] = math.min(hgl[e.key] ?? double.infinity, e.value.head);
    }
    for (final e in s.steady.links.entries) {
      flowOf[e.key] = math.max(flowOf[e.key] ?? 0, e.value.flow.abs());
    }
  }
  final minHgl = transient?.nodeMinHeads;
  final useTransient = minHgl != null && minHgl.isNotEmpty;

  final links = [
    for (final l in model.links)
      if (model.mainlineLinks.contains(l.id)) l,
  ];
  final roots = [
    for (final id in model.supplyNodes.values)
      if (model.mainlineNodes.contains(id)) id,
  ];
  final tree = _PathTree(roots, [for (final l in links) (l.from, l.to, l.kind == GLinkKind.pipe ? l.length : 0.0)]);
  final leaves = tree.leaves..sort((a, b) => (tree.dist[b] ?? 0).compareTo(tree.dist[a] ?? 0));

  bool busy(String nodeId) {
    final n = model.nodes[nodeId];
    if (n == null) return false;
    if (n.isSupply) return true;
    for (final id in n.entityIds) {
      final e = project.byId(id);
      if (e != null && e is! PipeEntity) return true;
    }
    return false;
  }

  double innerOf(GLink l) => mainline.designer.specOf(l)?.innerDiameter ?? 0;

  final candidates = <MainlineAirValve>[];
  final paths = <AirValvePath>[];
  // links of the paths already studied (longest first): their long runs are
  // spaced; a later path sharing the trunk only adds valves beyond it
  final covered = <String>{};
  const runReasons = {AirValveReason.longAscent, AirValveReason.longDescent, AirValveReason.longHorizontal};
  for (final leaf in leaves) {
    final steps = tree.pathTo(leaf);
    if (steps.isEmpty) continue;
    final seq = <GLink>[for (final (e, _) in steps) links[e]];
    final fwd = [for (final (_, f) in steps) f];
    final nodes = <String>[fwd.first ? seq.first.from : seq.first.to, for (var k = 0; k < seq.length; k++) fwd[k] ? seq[k].to : seq[k].from];
    final chain = <double>[0];
    for (final l in seq) {
      chain.add(chain.last + (l.kind == GLinkKind.pipe ? l.length : 0));
    }
    // the profile starts at the discharge of the first pump: the suction
    // side of a pump drawing from the source is no place for an air valve
    var start = 0;
    for (var k = 0; k < seq.length; k++) {
      if (seq[k].kind == GLinkKind.pump) {
        start = k + 1;
        break;
      }
    }
    final pathIndex = paths.length;
    final root = nodes.first;
    String? endEntity = seq.last.entityId;
    for (final id in model.nodes[leaf]?.entityIds ?? const <String>{}) {
      final e = project.byId(id);
      if (e != null && e is! PipeEntity) endEntity = id;
    }
    paths.add(AirValvePath(supplyId: model.nodes[root]?.supplyEntityId, endEntityId: endEntity, length: chain.last, start: chain[start]));
    if (chain.last - chain[start] < 1e-6) continue;

    // one profile point per chainage: the nodes of a device (zero length)
    // become one point with the lower grade line
    final pts = <ProfilePoint>[];
    final pumps = <double>[], checks = <double>[];
    double? lastX;
    double z = 0, g = 0, h = double.infinity, hn = double.infinity;
    double? dia;
    void flush() {
      if (lastX == null) return;
      // a node the transient did not cover keeps its steady head: the
      // envelope check needs a value at every point
      pts.add(ProfilePoint(chainage: lastX, pipe: z, ground: g, hgl: h.isFinite ? h : null, minHgl: useTransient ? (hn.isFinite ? hn : (h.isFinite ? h : null)) : null, diameter: dia));
    }

    for (var k = start; k < nodes.length; k++) {
      final x = chain[k];
      final n = model.nodes[nodes[k]];
      if (n == null) continue;
      if (lastX == null || (x - lastX).abs() > 1e-9) {
        flush();
        lastX = x;
        h = double.infinity;
        hn = double.infinity;
      }
      z = n.elevation;
      g = n.ground;
      h = math.min(h, hgl[n.id] ?? double.infinity);
      hn = math.min(hn, minHgl?[n.id] ?? double.infinity);
      dia = k < seq.length && seq[k].kind == GLinkKind.pipe ? innerOf(seq[k]) : null;
      if (dia != null && dia <= 0) dia = null;
      if (k < seq.length) {
        final l = seq[k];
        if (l.kind == GLinkKind.pump) pumps.add(chain[k + 1]);
        if (l.kind == GLinkKind.device && catalog.valve(l.valveSpecId)?.kind == ValveKind.check) checks.add(chain[k + 1]);
      }
    }
    flush();
    if (start > 0) pumps.insert(0, chain[start]);
    var designFlow = 0.0, d0 = 0.0, c0 = 140.0;
    for (var k = start; k < seq.length; k++) {
      final l = seq[k];
      if (l.kind != GLinkKind.pipe) continue;
      designFlow = math.max(designFlow, flowOf[l.id] ?? 0);
      if (d0 <= 0) {
        d0 = innerOf(l);
        c0 = mainline.designer.specOf(l)?.hazenC ?? 140;
      }
    }
    final plan = suggestAirValves(
      PipelineProfile(points: pts, diameter: d0 > 0 ? d0 : 0.1, hazenC: c0, designFlow: designFlow, pumpDischarges: pumps, checkValves: checks),
      options: o,
    );

    // positions on the pipes, clear of the items at the nodes; with the link
    (Pt, String?, double, String)? place(double x) {
      var k = -1;
      for (var i = start; i < seq.length; i++) {
        if (seq[i].kind != GLinkKind.pipe || seq[i].length <= 1e-9) continue;
        k = i;
        if (chain[i + 1] >= x - 1e-9) break;
      }
      if (k < 0) return null;
      final l = seq[k];
      final len = l.length;
      var local = (x - chain[k]).clamp(0.0, len).toDouble();
      final startBusy = busy(nodes[k]), endBusy = busy(nodes[k + 1]);
      const clear = 1.0, snap = 0.3;
      if (local < clear && startBusy) local = math.min(clear, len / 2);
      if (len - local < clear && endBusy) local = math.max(len - clear, len / 2);
      if (local < snap && !startBusy) local = 0;
      if (len - local < snap && !endBusy) local = len;
      final along = fwd[k] ? local : len - local;
      return (_along(l, along), l.entityId, chain[k] + local, l.id);
    }

    for (final s in plan.suggestions) {
      final at = place(s.chainage);
      if (at == null) continue;
      if (covered.contains(at.$4) && s.reasons.every(runReasons.contains)) continue;
      candidates.add(MainlineAirValve(position: at.$1, chainage: at.$3, path: pathIndex, type: s.type, reasons: s.reasons, sizing: s.sizing, elevation: s.pipe, ground: s.ground, pipeEntityId: at.$2));
    }
    covered.addAll([for (final l in seq) l.id]);
    for (final m in plan.messages) {
      if (!m.startsWith('air_hgl_below_pipe:')) continue;
      final x = double.tryParse(m.substring(m.indexOf(':') + 1)) ?? 0;
      final at = place(x);
      _addOnce(messages, at?.$2 == null ? 'air_hgl_below_pipe' : 'air_hgl_below_pipe:${at!.$2}');
    }
  }

  // the paths share their trunk: suggestions closer than the merge distance
  // on the same pipe (or at the same point) are one valve, at the place of
  // the main reason, with every reason; the ends of two branches that come
  // close keep a valve each
  final merged = <MainlineAirValve>[];
  for (final c in candidates) {
    var best = -1;
    var bestD = double.infinity;
    for (var i = 0; i < merged.length; i++) {
      final dd = merged[i].position.distanceTo(c.position);
      final near = dd <= 1 || (merged[i].pipeEntityId == c.pipeEntityId && dd <= o.mergeDistance + 1e-9);
      if (near && dd < bestD) {
        bestD = dd;
        best = i;
      }
    }
    if (best < 0) {
      merged.add(c);
      continue;
    }
    final m = merged[best];
    final lead = c.reason.index < m.reason.index ? c : m;
    final reasons = {...m.reasons, ...c.reasons}.toList()..sort((a, b) => a.index.compareTo(b.index));
    final type = m.type == c.type ? m.type : AirValveType.combination;
    final sizing = c.sizing.nominalSize > m.sizing.nominalSize + 1e-12 || (c.sizing.nominalSize == m.sizing.nominalSize && c.sizing.largeOrifice > m.sizing.largeOrifice) ? c.sizing : m.sizing;
    merged[best] = MainlineAirValve(
      position: lead.position,
      chainage: lead.chainage,
      path: lead.path,
      type: type,
      reasons: reasons,
      sizing: sizing,
      elevation: lead.elevation,
      ground: lead.ground,
      pipeEntityId: lead.pipeEntityId,
    );
  }

  // the catalogue item and the air valves already drawn
  final specs = airValveSpecs(catalog);
  if (specs.isEmpty && merged.isNotEmpty) messages.add('air_no_spec');
  final drawn = [
    for (final e in project.entities.whereType<MiscHydraulicEntity>())
      if (e.scope == HydraulicScope.mainline && catalog.valve(e.valveSpecId)?.kind == ValveKind.airRelease) e,
  ];
  final out = <MainlineAirValve>[];
  for (final m in merged) {
    ValveSpec? spec;
    final need = m.sizing.nominalSize * 1000;
    for (final s in specs) {
      if (s.sizeMm >= need - 0.5) {
        spec = s;
        break;
      }
    }
    if (spec == null && specs.isNotEmpty) {
      spec = specs.last;
      _addOnce(messages, 'air_valve_undersized');
    }
    String? existing;
    var bestD = double.infinity;
    for (final e in drawn) {
      final dd = e.position.distanceTo(m.position);
      if (dd <= o.mergeDistance + 1e-9 && dd < bestD) {
        bestD = dd;
        existing = e.id;
      }
    }
    out.add(m.copyWith(specId: spec?.id, existingId: existing));
  }
  out.sort((a, b) => a.path != b.path ? a.path.compareTo(b.path) : a.chainage.compareTo(b.chainage));
  return AirValveStudy(suggestions: out, paths: paths, messages: messages, usedTransient: useTransient);
}

/// Air valve devices for [suggestions] not drawn yet, on the mainline pipes
/// at their positions (ids from [newId]); the network builder splits the
/// pipes under them.
List<MiscHydraulicEntity> airValveEntities(Iterable<MainlineAirValve> suggestions, String Function() newId) => [
  for (final s in suggestions)
    if (!s.existing && s.specId != null) MiscHydraulicEntity(id: newId(), position: s.position, valveSpecId: s.specId, scope: HydraulicScope.mainline),
];

// ---------------------------------------------------------------- 24 hours

/// Settings of [simulateDay].
class EpsDayOptions {
  const EpsDayOptions({this.pricePerKwh, this.peakStartHour = 18, this.peakEndHour = 21, this.peakMultiplier = 1, this.hydraulicStep = 3600});

  /// Energy price (currency per kWh); null = the design parameters'.
  final double? pricePerKwh;

  /// Peak band of the day (hours, may wrap past midnight) whose price is
  /// [peakMultiplier] times the normal one (1 = a flat tariff).
  final double peakStartHour, peakEndHour, peakMultiplier;

  /// Largest hydraulic step (s); the steps are also cut where a flow starts
  /// or stops.
  final double hydraulicStep;

  /// Price at [hour] (0–24) of the day for the base price [base].
  double priceAt(double hour, double base) => inPeak(hour) ? base * peakMultiplier : base;

  bool inPeak(double hour) {
    final h = ((hour % 24) + 24) % 24;
    final a = ((peakStartHour % 24) + 24) % 24, b = ((peakEndHour % 24) + 24) % 24;
    if ((a - b).abs() < 1e-9) return false;
    return a < b ? h >= a - 1e-9 && h < b - 1e-9 : h >= a - 1e-9 || h < b - 1e-9;
  }

  /// ∫ price dt over [t0, t1] (s), in currency per kW: the price changes
  /// only at the ends of the peak band.
  double priceIntegral(double t0, double t1, double base) {
    if (t1 <= t0) return 0;
    final cuts = <double>{t0, t1};
    for (final hh in [peakStartHour, peakEndHour]) {
      final c = ((hh % 24) + 24) % 24 * 3600;
      for (var k = (t0 / 86400).floor() - 1; k <= (t1 / 86400).floor() + 1; k++) {
        final x = c + k * 86400;
        if (x > t0 && x < t1) cuts.add(x);
      }
    }
    final s = cuts.toList()..sort();
    var out = 0.0;
    for (var i = 0; i + 1 < s.length; i++) {
      out += priceAt((s[i] + s[i + 1]) / 2 / 3600, base) * (s[i + 1] - s[i]) / 3600;
    }
    return out;
  }
}

/// One hour of the day.
class EpsHour {
  const EpsHour({
    required this.hour,
    required this.flow,
    required this.powerKw,
    required this.energyKwh,
    required this.cost,
    required this.lowestPressure,
    this.lowestValve,
    this.lowestMargin = double.nan,
    this.flows = const [],
  });
  final int hour;

  /// Mean flow delivered (m³/s) and mean power (kW).
  final double flow, powerKw;
  final double energyKwh, cost;

  /// Lowest pressure head at a running zone valve or pivot (m; NaN when none
  /// runs), which one, and its margin over what it needs (m).
  final double lowestPressure;
  final String? lowestValve;
  final double lowestMargin;

  /// System flows running at some time of the hour.
  final List<String> flows;

  Map<String, dynamic> toJson() => {
    'h': hour,
    'q': flow,
    'kw': powerKw,
    'kwh': energyKwh,
    'cost': cost,
    'p': _jd(lowestPressure),
    if (lowestValve != null) 'v': lowestValve,
    'm': _jd(lowestMargin),
    'flows': flows,
  };
  static EpsHour fromJson(Map<String, dynamic> j) => EpsHour(
    hour: (j['h'] as num?)?.toInt() ?? 0,
    flow: _rd(j, 'q'),
    powerKw: _rd(j, 'kw'),
    energyKwh: _rd(j, 'kwh'),
    cost: _rd(j, 'cost'),
    lowestPressure: _rn(j, 'p'),
    lowestValve: j['v'] as String?,
    lowestMargin: _rn(j, 'm'),
    flows: _sl(j['flows']),
  );
}

/// Energy of a pump over the day; a supply whose pressure the design
/// calculates counts as a pump giving that pressure ([calculated]), as in the
/// energy cost of the design.
class EpsPumpDay {
  const EpsPumpDay({required this.entityId, required this.energyKwh, required this.cost, required this.hoursOn, required this.volume, required this.maxPowerKw, this.calculated = false});
  final String entityId;
  final double energyKwh, cost, hoursOn;

  /// Water pumped (m³) and the largest power (kW).
  final double volume, maxPowerKw;
  final bool calculated;

  Map<String, dynamic> toJson() => {'id': entityId, 'kwh': energyKwh, 'cost': cost, 'hours': hoursOn, 'vol': volume, 'kw': maxPowerKw, 'calc': calculated};
  static EpsPumpDay fromJson(Map<String, dynamic> j) => EpsPumpDay(
    entityId: j['id'] as String? ?? '',
    energyKwh: _rd(j, 'kwh'),
    cost: _rd(j, 'cost'),
    hoursOn: _rd(j, 'hours'),
    volume: _rd(j, 'vol'),
    maxPowerKw: _rd(j, 'kw'),
    calculated: j['calc'] as bool? ?? false,
  );
}

/// Result of [simulateDay]: series with one entry per simulation step
/// (the state from that time to the next) and the hourly summary.
class EpsDay {
  const EpsDay({
    this.times = const [],
    this.flow = const [],
    this.powerKw = const [],
    this.lowestPressure = const [],
    this.lowestValve = const [],
    this.lowestMargin = const [],
    this.hours = const [],
    this.pumps = const [],
    this.energyKwh = 0,
    this.cost = 0,
    this.volume = 0,
    this.pricePerKwh = 0,
    this.converged = true,
    this.messages = const [],
  });

  /// Step start times (s after midnight) and the end of the day.
  final List<double> times;

  /// Flow delivered by the supplies (m³/s), total pump power (kW), lowest
  /// pressure head at a running valve (m, NaN when none runs), which valve,
  /// and its margin over the pressure it needs (m).
  final List<double> flow, powerKw, lowestPressure;
  final List<String?> lowestValve;
  final List<double> lowestMargin;
  final List<EpsHour> hours;
  final List<EpsPumpDay> pumps;

  /// Totals of the day: energy (kWh), cost and volume delivered (m³).
  final double energyKwh, cost, volume;
  final double pricePerKwh;
  final bool converged;

  /// `eps_pressure_deficit:<valve>`, `eps_flows_overlap:<flow>`,
  /// `eps_not_converged:<hh:mm>`, `no_water_supply`.
  final List<String> messages;

  Map<String, dynamic> toJson() => {
    't': _jl(times),
    'q': _jl(flow),
    'kw': _jl(powerKw),
    'p': _jl(lowestPressure),
    'v': lowestValve,
    'm': _jl(lowestMargin),
    'hours': [for (final h in hours) h.toJson()],
    'pumps': [for (final p in pumps) p.toJson()],
    'kwh': energyKwh,
    'cost': cost,
    'vol': volume,
    'price': pricePerKwh,
    'conv': converged,
    'msg': messages,
  };

  static EpsDay fromJson(Map<String, dynamic> j) => EpsDay(
    times: _dl(j['t']),
    flow: _dl(j['q']),
    powerKw: _dl(j['kw']),
    lowestPressure: _dl(j['p']),
    lowestValve: [for (final v in (j['v'] as List?) ?? const []) v as String?],
    lowestMargin: _dl(j['m']),
    hours: [for (final h in (j['hours'] as List?) ?? const []) EpsHour.fromJson(h as Map<String, dynamic>)],
    pumps: [for (final p in (j['pumps'] as List?) ?? const []) EpsPumpDay.fromJson(p as Map<String, dynamic>)],
    energyKwh: _rd(j, 'kwh'),
    cost: _rd(j, 'cost'),
    volume: _rd(j, 'vol'),
    pricePerKwh: _rd(j, 'price'),
    converged: j['conv'] as bool? ?? true,
    messages: _sl(j['msg']),
  );
}

/// The windows of the day (start s, length s) a system flow runs in: its
/// start hour (taken modulo 24) for its duration, split at midnight.
List<(double, double)> flowWindows(SystemFlow f) {
  const day = 86400.0;
  final len = f.durationHours.clamp(0.0, 24.0) * 3600;
  if (!(len > 1e-6)) return const [];
  if (len >= day - 1e-6) return const [(0.0, day)];
  final start = ((f.startHour % 24) + 24) % 24 * 3600;
  final end = start + len;
  return end <= day + 1e-9 ? [(start, len)] : [(start, day - start), (0.0, end - day)];
}

/// A day of operation of the mainline of [project] (see the library
/// documentation).
EpsDay simulateDay(Project project, {DesignResults? results, EpsDayOptions options = const EpsDayOptions(), String Function(String key)? label}) => simulateDayOn(
  MainlineFlows(project, results: results, label: label),
  options: options,
);

/// [simulateDay] on prepared mainline flows.
///
/// The networks of the flows share their nodes and links; one network holds
/// the demand of every zone valve and pivot, switched on in the windows of
/// the flows it belongs to (`EpsDemandSchedule`). What differs between the
/// flows is replicated and scheduled: a supply whose pressure the design
/// calculates per flow becomes one source per pressure behind a check valve
/// (the higher one feeds when flows overlap), and a pump whose drive runs at
/// a different speed in different flows one pump per speed (the fastest of
/// the running flows runs). A mainline outlet (valve-in-head head) runs in
/// the windows of the flows that run its station: those that list it, or
/// every flow while none does (`valve_in_head.dart`).
EpsDay simulateDayOn(MainlineFlows mainline, {EpsDayOptions options = const EpsDayOptions()}) {
  const day = 86400.0;
  final project = mainline.project;
  final params = project.params;
  final d = mainline.designer;
  final model = mainline.model;
  final base = options.pricePerKwh ?? params.powerCostPerKwh;
  final flows = <SystemFlow>[];
  final states = <MainlineFlowState>[];
  for (final f in mainline.flows) {
    final s = mainline.stateOf(f);
    if (s == null) continue;
    flows.add(f);
    states.add(s);
  }
  if (states.isEmpty) return EpsDay(pricePerKwh: base, messages: const ['no_water_supply']);
  final messages = <String>[];

  // the day in segments where the same flows run
  final windows = [for (final f in flows) flowWindows(f)];
  final cuts = <double>{0, day};
  for (final w in windows) {
    for (final (a, l) in w) {
      cuts
        ..add(a)
        ..add(math.min(a + l, day));
    }
  }
  final sorted = cuts.toList()..sort();
  final segs = <(double, double, Set<int>)>[];
  for (var i = 0; i + 1 < sorted.length; i++) {
    final a = sorted[i], b = sorted[i + 1];
    if (b - a < 1e-6) continue;
    final mid = (a + b) / 2;
    segs.add((
      a,
      b,
      {
        for (var k = 0; k < flows.length; k++)
          if (windows[k].any((w) => mid >= w.$1 && mid < w.$1 + w.$2)) k,
      },
    ));
  }
  for (final (_, _, on) in segs) {
    if (on.length < 2) continue;
    for (final k in on) {
      _addOnce(messages, 'eps_flows_overlap:${flows[k].id}');
    }
  }
  Set<int> runningAt(double t) {
    for (final (a, b, on) in segs) {
      if (t >= a - 1e-9 && t < b - 1e-9) return on;
    }
    return const {};
  }

  List<(double, double)> where(bool Function(Set<int> on) test) {
    final out = <(double, double)>[];
    for (final (a, b, on) in segs) {
      if (!test(on)) continue;
      if (out.isNotEmpty && (out.last.$1 + out.last.$2 - a).abs() < 1e-6) {
        out[out.length - 1] = (out.last.$1, b - out.last.$1);
      } else {
        out.add((a, b - a));
      }
    }
    return out;
  }

  // one network for the day
  final first = states.first.network;
  final u = HydraulicNetwork(options: first.options);
  for (final n in first.nodes.values) {
    u.addNode(
      HNode(id: n.id, kind: n.kind, elevation: n.elevation, fixedHead: n.fixedHead, emitter: n.emitter, emitterCount: n.emitterCount, emitterOffset: n.emitterOffset, label: n.label, tag: n.tag),
    );
  }
  final extra = <HLink>[];
  // windows of the day (absolute) in which every scheduled link is open and
  // every scheduled node draws
  final linkWindows = <String, List<(double, double)>>{};
  final nodeWindows = <String, List<(double, double)>>{};

  // mainline outlets: a head off in a flow keeps its node with no emitter
  // running there (Designer), so the day holds every head with the flows
  // that run it
  final emitterFlows = <String, Set<int>>{};
  for (final n in u.nodes.values) {
    if (n.emitter == null) continue;
    var count = 0;
    for (var k = 0; k < states.length; k++) {
      final c = states[k].network.nodes[n.id]?.emitterCount ?? 0;
      if (c <= 0) continue;
      (emitterFlows[n.id] ??= {}).add(k);
      count = math.max(count, c);
    }
    n.emitterCount = count;
  }

  // zone valves and pivots
  final q = <String, double>{};
  final member = <String, Set<int>>{};
  for (var k = 0; k < states.length; k++) {
    for (final e in states[k].demand.entries) {
      q[e.key] = e.value;
      (member[e.key] ??= {}).add(k);
    }
  }
  final byNode = <String, List<String>>{};
  for (final id in q.keys) {
    final n = d.demandNodeOf(id);
    if (n != null && u.nodes.containsKey(n)) (byNode[n] ??= []).add(id);
  }
  bool sameSet(Set<int> a, Set<int> b) => a.length == b.length && a.containsAll(b);
  final readAt = <String, String>{};
  for (final e in byNode.entries) {
    final node = u.nodes[e.key]!;
    final ids = e.value;
    final emitters = node.emitter != null && node.emitterCount > 0;
    if (!emitters && ids.every((id) => sameSet(member[id]!, member[ids.first]!))) {
      node.demand = ids.fold(0.0, (s, id) => s + q[id]!);
      final m = member[ids.first]!;
      nodeWindows[e.key] = where((on) => on.any(m.contains));
      for (final id in ids) {
        readAt[id] = e.key;
      }
      continue;
    }
    // valves of different flows at one node (or beside outlets): each its own
    for (final id in ids) {
      final sid = '${e.key}~$id';
      u.addNode(HNode(id: sid, elevation: node.elevation, demand: q[id]!));
      extra.add(HLink(id: 'eps_dem_$id', from: e.key, to: sid, kind: HLinkKind.device, device: const DeviceLossCurve(k: 1e-6)));
      final m = member[id]!;
      nodeWindows[sid] = where((on) => on.any(m.contains));
      readAt[id] = sid;
    }
  }
  // mainline outlets run with the flows that run them
  for (final e in emitterFlows.entries) {
    nodeWindows[e.key] = where((on) => on.any(e.value.contains));
  }

  // supplies whose pressure differs between flows: one source per pressure
  double outflow(MainlineFlowState s, String node) {
    var out = 0.0;
    for (final l in s.network.links) {
      final f = s.steady.links[l.id]?.flow ?? 0;
      if (l.from == node) out += f;
      if (l.to == node) out -= f;
    }
    return out;
  }

  final sources = <String, List<(String, double)>>{}; // supply node → (source node, pressure)
  for (final n in first.nodes.values) {
    if (n.kind != HNodeKind.reservoir) continue;
    final heads = [for (final s in states) s.network.nodes[n.id]?.fixedHead ?? n.fixedHead ?? n.elevation];
    final users = {
      for (var k = 0; k < states.length; k++)
        if (outflow(states[k], n.id) > 1e-7) k,
    };
    final distinct = <double>[];
    for (var k = 0; k < heads.length; k++) {
      if (!users.contains(k) && users.isNotEmpty) continue;
      if (!distinct.any((h) => (h - heads[k]).abs() < 1e-6)) distinct.add(heads[k]);
    }
    if (distinct.length <= 1) {
      final h = distinct.isEmpty ? (n.fixedHead ?? n.elevation) : distinct.first;
      u.nodes[n.id]!.fixedHead = h;
      sources[n.id] = [(n.id, h - n.elevation)];
      continue;
    }
    final node = u.nodes[n.id]!
      ..kind = HNodeKind.junction
      ..fixedHead = null;
    final list = <(String, double)>[];
    for (var j = 0; j < distinct.length; j++) {
      final h = distinct[j];
      final sid = '${n.id}@$j';
      u.addNode(HNode(id: sid, kind: HNodeKind.reservoir, elevation: node.elevation, fixedHead: h));
      final lid = 'eps_src_$sid';
      extra.add(HLink(id: lid, from: sid, to: n.id, kind: HLinkKind.device, device: const DeviceLossCurve(k: 1e-6), checkValve: true));
      linkWindows[lid] = where((on) {
        final run = on.where(users.contains);
        if (run.isEmpty) return false;
        final top = run.map((k) => heads[k]).reduce(math.max);
        return (top - h).abs() < 1e-6;
      });
      list.add((sid, h - node.elevation));
    }
    sources[n.id] = list;
  }

  // pumps: on while a flow they serve runs; one per speed of their drive
  final efficiency = <String, double>{};
  final pumpEntity = <String, String>{};
  for (final l in first.links) {
    if (l.kind != HLinkKind.pump) {
      u.addLink(
        HLink(
          id: l.id,
          from: l.from,
          to: l.to,
          kind: l.kind,
          diameter: l.diameter,
          length: l.length,
          hazenC: l.hazenC,
          roughness: l.roughness,
          minorK: l.minorK,
          checkValve: l.checkValve,
          pump: l.pump,
          device: l.device,
          prvSetting: l.prvSetting,
          label: l.label,
          tag: l.tag,
          scobeyKs: l.scobeyKs,
          manningN: l.manningN,
          fcvFlow: l.fcvFlow,
        ),
      );
      continue;
    }
    final gl = l.tag is GLink ? l.tag as GLink : null;
    final spec = project.catalog.pump(gl?.pumpSpecId);
    final users = {
      for (var k = 0; k < states.length; k++)
        if ((states[k].steady.links[l.id]?.flow ?? 0) > 1e-6) k,
    };
    final speedOf = <int, double>{};
    for (var k = 0; k < states.length; k++) {
      final hl = states[k].network.links.where((x) => x.id == l.id).firstOrNull;
      speedOf[k] = hl?.pump?.speedRatio ?? l.pump?.speedRatio ?? 1;
    }
    final distinct = <double>[];
    for (final k in users) {
      if (!distinct.any((w) => (w - speedOf[k]!).abs() < 1e-6)) distinct.add(speedOf[k]!);
    }
    double effAt(double w) {
      var best = -1, qBest = 0.0;
      for (final k in users) {
        final qq = states[k].steady.links[l.id]?.flow ?? 0;
        if ((speedOf[k]! - w).abs() < 1e-6 && qq > qBest) {
          qBest = qq;
          best = k;
        }
      }
      // the motor and its drive as well, as in the annual energy (MOT-15)
      final pump = project.byId(gl?.entityId ?? '');
      final motor = pump is PumpEntity ? pump.motorEfficiency.clamp(0.05, 1.0) : 1.0;
      return motor * (best < 0 ? (spec?.efficiency ?? params.pumpEfficiency) : (spec?.efficiencyAt(qBest, speed: w) ?? params.pumpEfficiency));
    }

    if (distinct.length <= 1) {
      u.addLink(HLink(id: l.id, from: l.from, to: l.to, kind: HLinkKind.pump, pump: l.pump?.withSpeed(distinct.isEmpty ? l.pump!.speedRatio : distinct.first), label: l.label, tag: l.tag));
      linkWindows[l.id] = where((on) => on.any(users.contains));
      efficiency[l.id] = effAt(distinct.isEmpty ? (l.pump?.speedRatio ?? 1) : distinct.first);
      if (gl != null) pumpEntity[l.id] = gl.entityId;
      continue;
    }
    for (var j = 0; j < distinct.length; j++) {
      final w = distinct[j];
      final lid = '${l.id}@$j';
      u.addLink(HLink(id: lid, from: l.from, to: l.to, kind: HLinkKind.pump, pump: l.pump?.withSpeed(w), label: l.label, tag: l.tag));
      linkWindows[lid] = where((on) {
        final run = on.where(users.contains);
        if (run.isEmpty) return false;
        return (run.map((k) => speedOf[k]!).reduce(math.max) - w).abs() < 1e-6;
      });
      efficiency[lid] = effAt(w);
      if (gl != null) pumpEntity[lid] = gl.entityId;
    }
  }
  for (final l in extra) {
    u.addLink(l);
  }

  final sourceNodes = {
    for (final list in sources.values)
      for (final (id, _) in list) id,
  };
  final linkFlowsNeeded = <String>{
    for (final l in u.links)
      if (l.kind == HLinkKind.pump || sourceNodes.contains(l.from) || sourceNodes.contains(l.to)) l.id,
  };

  // calculated supplies: a pump giving their pressure (as in the design's energy)
  final calculated = <String, (String, double)>{}; // source node → (supply entity, pressure)
  for (final e in sources.entries) {
    final sid = model.nodes[e.key]?.supplyEntityId;
    final s = sid == null ? null : project.byId(sid);
    if (s is! WaterSupplyEntity || !s.calculatePressure) continue;
    for (final (node, p) in e.value) {
      if (p > 1e-6) calculated[node] = (s.id, p);
    }
  }
  final eta = params.pumpEfficiency.clamp(0.05, 1.0).toDouble();

  // The day runs in blocks of consecutive segments in which some flow runs.
  // Without tanks nothing carries over from one block to the next, and the
  // network at rest in between (every pump off, no demand) has no defined
  // steady state for the solver: those hours are simply idle.
  final blocks = <(double, double)>[];
  for (final (a, b, on) in segs) {
    if (on.isEmpty) continue;
    if (blocks.isNotEmpty && (blocks.last.$2 - a).abs() < 1e-6) {
      blocks[blocks.length - 1] = (blocks.last.$1, b);
    } else {
      blocks.add((a, b));
    }
  }
  List<(double, double)> clip(List<(double, double)> w, double s, double e) => [
    for (final (a, l) in w)
      if (math.min(a + l, e) > math.max(a, s) + 1e-9) (math.max(a, s) - s, math.min(a + l, e) - math.max(a, s)),
  ];

  final times = <double>[], flow = <double>[], power = <double>[], lowP = <double>[], lowM = <double>[];
  final lowV = <String?>[];
  final pumpPower = <Map<String, (double, double)>>[]; // per step: entity key → (kW, m³/s)
  void idle(double t) {
    times.add(t);
    flow.add(0);
    power.add(0);
    lowP.add(double.nan);
    lowM.add(double.nan);
    lowV.add(null);
    pumpPower.add(const {});
  }

  var converged = true;
  final deficits = <String>{};
  var cursor = 0.0;
  for (final (s, e) in blocks) {
    if (s > cursor + 1e-6) idle(cursor);
    final res = simulateEps(
      u,
      schedules: [for (final w in linkWindows.entries) EpsSchedule.intervals(w.key, clip(w.value, s, e))],
      demandSchedules: [for (final w in nodeWindows.entries) EpsDemandSchedule(w.key, clip(w.value, s, e))],
      options: EpsOptions(
        duration: e - s,
        hydraulicStep: options.hydraulicStep > 0 ? options.hydraulicStep : 3600,
        pumpEfficiency: efficiency,
        defaultEfficiency: params.pumpEfficiency,
        recordNodes: {...readAt.values},
        recordLinks: linkFlowsNeeded,
      ),
    );
    for (final m in res.messages) {
      if (m.startsWith('eps_not_converged:')) {
        // the state after the block (every flow off) is not used
        final rel = double.tryParse(m.substring(m.indexOf(':') + 1)) ?? 0;
        if (rel >= e - s - 1) continue;
        converged = false;
        final mm = (((s + rel) / 60).round()) % 1440;
        _addOnce(messages, 'eps_not_converged:${(mm ~/ 60).toString().padLeft(2, '0')}:${(mm % 60).toString().padLeft(2, '0')}');
      } else {
        _addOnce(messages, m);
      }
    }
    double sourceOut(String node, int i) {
      var out = 0.0;
      for (final l in u.links) {
        final series = res.linkFlows[l.id];
        if (series == null || i >= series.length) continue;
        if (l.from == node) out += series[i];
        if (l.to == node) out -= series[i];
      }
      return out;
    }

    // every step of the block but its end (the state after it)
    for (var i = 0; i + 1 < res.times.length; i++) {
      final t = s + res.times[i];
      final dt = res.times[i + 1] - res.times[i];
      var qTotal = 0.0, pTotal = 0.0;
      for (final node in sourceNodes) {
        qTotal += sourceOut(node, i);
      }
      final pp = <String, (double, double)>{};
      for (final ep in res.pumps.entries) {
        final p = i < ep.value.power.length ? ep.value.power[i] : 0.0;
        final qq = res.linkFlows[ep.key];
        final key = pumpEntity[ep.key] ?? ep.key;
        final prev = pp[key] ?? (0.0, 0.0);
        pp[key] = (prev.$1 + p, prev.$2 + (p > 0 && qq != null && i < qq.length ? qq[i] : 0.0));
        pTotal += p;
      }
      for (final c in calculated.entries) {
        final qq = math.max(0.0, sourceOut(c.key, i));
        final p = waterDensity * gravity * qq * c.value.$2 / eta / 1000;
        final key = 'calc:${c.value.$1}';
        final prev = pp[key] ?? (0.0, 0.0);
        pp[key] = (prev.$1 + p, prev.$2 + (p > 0 ? qq : 0.0));
        pTotal += p;
      }
      var lp = double.nan, lm = double.nan;
      String? lv;
      final on = runningAt(t);
      for (final id in q.keys) {
        if (!member[id]!.any(on.contains)) continue;
        final node = readAt[id];
        final series = node == null ? null : res.nodePressures[node];
        if (series == null || i >= series.length) continue;
        final p = series[i];
        final margin = p - mainline.requiredHeadOf(id);
        if (lp.isNaN || p < lp) {
          lp = p;
          lv = id;
        }
        if (lm.isNaN || margin < lm) lm = margin;
        if (margin < -0.05 && dt > 0) deficits.add(id);
      }
      times.add(t);
      flow.add(qTotal);
      power.add(pTotal);
      lowP.add(lp);
      lowM.add(lm);
      lowV.add(lv);
      pumpPower.add(pp);
    }
    cursor = e;
  }
  if (cursor < day - 1e-6) idle(cursor);
  idle(day);
  for (final id in q.keys) {
    if (deficits.contains(id)) _addOnce(messages, 'eps_pressure_deficit:$id');
  }

  // energy and cost of every pump, step by step at the price of the clock
  final n = times.length;
  final perPump = <String, List<double>>{}; // entity → [kWh, cost, hours, m³, max kW]
  for (var i = 0; i + 1 < n; i++) {
    final dt = times[i + 1] - times[i];
    final price = options.priceIntegral(times[i], times[i + 1], base);
    for (final e in pumpPower[i].entries) {
      final acc = perPump.putIfAbsent(e.key, () => [0, 0, 0, 0, 0]);
      final (p, qq) = e.value;
      acc[0] += p * dt / 3600;
      acc[1] += p * price;
      if (p > 0) {
        acc[2] += dt / 3600;
        acc[3] += qq * dt;
      }
      acc[4] = math.max(acc[4], p);
    }
  }

  // the hours
  final hours = <EpsHour>[];
  for (var h = 0; h < 24; h++) {
    final h0 = h * 3600.0, h1 = h0 + 3600;
    var qm = 0.0, pm = 0.0, cost = 0.0, lp = double.nan, lm = double.nan;
    String? lv;
    for (var i = 0; i + 1 < n; i++) {
      final a = math.max(times[i], h0), b = math.min(times[i + 1], h1);
      if (b <= a + 1e-9) continue;
      final w = (b - a) / 3600;
      qm += flow[i] * w;
      pm += power[i] * w;
      cost += power[i] * options.priceIntegral(a, b, base);
      if (!lowP[i].isNaN && (lp.isNaN || lowP[i] < lp)) {
        lp = lowP[i];
        lv = lowV[i];
      }
      if (!lowM[i].isNaN && (lm.isNaN || lowM[i] < lm)) lm = lowM[i];
    }
    final running = <String>[];
    for (final (a, b, on) in segs) {
      if (b <= h0 + 1e-9 || a >= h1 - 1e-9) continue;
      for (final k in on) {
        if (!running.contains(flows[k].id)) running.add(flows[k].id);
      }
    }
    hours.add(EpsHour(hour: h, flow: qm, powerKw: pm, energyKwh: pm, cost: cost, lowestPressure: lp, lowestValve: lv, lowestMargin: lm, flows: running));
  }
  final pumps = [
    for (final e in perPump.entries)
      EpsPumpDay(
        entityId: e.key.startsWith('calc:') ? e.key.substring(5) : e.key,
        energyKwh: e.value[0],
        cost: e.value[1],
        hoursOn: e.value[2],
        volume: e.value[3],
        maxPowerKw: e.value[4],
        calculated: e.key.startsWith('calc:'),
      ),
  ];
  var volume = 0.0;
  for (var i = 0; i + 1 < n; i++) {
    volume += flow[i] * (times[i + 1] - times[i]);
  }
  return EpsDay(
    times: times,
    flow: flow,
    powerKw: power,
    lowestPressure: lowP,
    lowestValve: lowV,
    lowestMargin: lowM,
    hours: hours,
    pumps: pumps,
    energyKwh: pumps.fold(0.0, (s, p) => s + p.energyKwh),
    cost: pumps.fold(0.0, (s, p) => s + p.cost),
    volume: volume,
    pricePerKwh: base,
    converged: converged,
    messages: messages,
  );
}
