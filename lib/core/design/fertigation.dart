/// Fertigation: how long a product injected at one point of a solved network
/// takes to reach every outlet, the injection schedule that delivers it and
/// flushes it out of the pipes before the irrigation ends, the amounts for a
/// dose per hectare and a stock-solution concentration, and the check of a
/// venturi injector on a bypass.
///
/// Travel times are plug flow along the steady flows: crossing a pipe takes
/// its volume over its flow, V/|Q| (devices and pumps hold no volume). The
/// product first appears at a node after the fastest path from the injection
/// point (Dijkstra 1959) and the node gets the full concentration once the
/// slowest path has arrived too (longest path over the flow directions,
/// which form an acyclic graph in a steady solution). For the product to be
/// flushed out of every pipe, the injection must stop at least the slowest
/// arrival at the farthest outlet before the irrigation ends. Pre-wetting,
/// injection and flushing default to the common rule of thumb of one quarter,
/// one half and one quarter of the irrigation time, the flushing never
/// shorter than that travel time (for fertigation practice see Burt,
/// O'Connor & Ruehr 1995, "Fertigation", Irrigation Training and Research
/// Center, California Polytechnic State University).
library;

import 'dart:collection';
import 'dart:math' as math;

import '../hydraulics/network.dart';
import 'network_builder.dart';

/// Arrival times (s after the injection starts) of the product at a node.
class TravelTime {
  const TravelTime({required this.nodeId, required this.earliest, required this.latest});
  final String nodeId;

  /// The product first appears (fastest path) and the full concentration
  /// arrives (slowest path).
  final double earliest;
  final double latest;

  Map<String, dynamic> toJson() => {'node': nodeId, 'e': earliest, 'l': latest};
  static TravelTime fromJson(Map<String, dynamic> j) => TravelTime(nodeId: j['node'] as String, earliest: _d(j['e']), latest: _d(j['l']));
}

/// Outcome of [fertigationTravel].
class FertigationTravel {
  FertigationTravel({required this.injectionNode, required this.nodes, required this.outlets, required this.unreached, required this.volume, required this.codes});
  final String injectionNode;

  /// Every node the product reaches, by id.
  final Map<String, TravelTime> nodes;

  /// Outlet nodes (emitters and demands) the product reaches, and those it
  /// never reaches (no flow path from the injection point).
  final List<String> outlets;
  final List<String> unreached;

  /// Volume of the pipes carrying the product (m³).
  final double volume;

  /// `fertigation_unknown_node`, `fertigation_no_flow` (nothing leaves the
  /// injection point), `fertigation_unreached` (outlets the product never
  /// reaches), `fertigation_flow_cycle` (circulating flow: the slowest
  /// arrival of the nodes on it is taken as the fastest).
  final List<String> codes;

  /// The product reaches the nearest outlet, has reached every outlet (the
  /// time to the farthest one), and every outlet has the full concentration
  /// (s).
  double get firstArrival => outlets.isEmpty ? 0 : outlets.map((o) => nodes[o]!.earliest).reduce(math.min);
  double get farthestArrival => outlets.isEmpty ? 0 : outlets.map((o) => nodes[o]!.earliest).reduce(math.max);
  double get fullArrival => outlets.isEmpty ? 0 : outlets.map((o) => nodes[o]!.latest).reduce(math.max);

  /// The outlet the product reaches last.
  String? get farthestOutlet => outlets.isEmpty ? null : outlets.reduce((a, b) => nodes[b]!.earliest > nodes[a]!.earliest ? b : a);

  Map<String, dynamic> toJson() => {'inj': injectionNode, 'nodes': nodes.values.map((t) => t.toJson()).toList(), 'out': outlets, 'unreached': unreached, 'vol': volume, 'codes': codes};
  static FertigationTravel fromJson(Map<String, dynamic> j) => FertigationTravel(
    injectionNode: j['inj'] as String? ?? '',
    nodes: {for (final t in ((j['nodes'] as List?) ?? []).map((e) => TravelTime.fromJson(e as Map<String, dynamic>))) t.nodeId: t},
    outlets: ((j['out'] as List?) ?? []).cast<String>(),
    unreached: ((j['unreached'] as List?) ?? []).cast<String>(),
    volume: _d(j['vol']),
    codes: ((j['codes'] as List?) ?? []).cast<String>(),
  );
}

/// Travel times of a product injected at [injectionNode] of [net] solved as
/// [result] (see the library comment). Pipe lengths come from [lengths] (by
/// link id), else from the [GLink] tag of a designer network (its real
/// length: the solver's link carries the minor-loss allowance), else from the
/// link. [outlets] are the nodes to report (default: the nodes with an
/// emitter that flows or a demand). [offsetSeconds] is added to every time
/// (the travel to the injection point, to chain the mainline and a zone).
/// Links carrying under [minFlow] (m³/s) are taken as stagnant.
FertigationTravel fertigationTravel(
  HydraulicNetwork net,
  NetworkResult result,
  String injectionNode, {
  Map<String, double>? lengths,
  Iterable<String>? outlets,
  double offsetSeconds = 0,
  double minFlow = 1e-9,
}) {
  final codes = <String>[];
  if (!net.nodes.containsKey(injectionNode)) {
    codes.add('fertigation_unknown_node');
    return FertigationTravel(injectionNode: injectionNode, nodes: const {}, outlets: const [], unreached: const [], volume: 0, codes: codes);
  }
  // directed edges along the flow, weighted by the travel time
  final out = <String, List<(String, double, double)>>{};
  for (final l in net.links) {
    final q = result.links[l.id]?.flow ?? 0;
    if (q.abs() < minFlow || l.kind == HLinkKind.closed) continue;
    var volume = 0.0;
    if (l.kind == HLinkKind.pipe) {
      final tag = l.tag;
      final len = lengths?[l.id] ?? (tag is GLink ? tag.length : l.length);
      volume = math.pi * l.diameter * l.diameter / 4 * math.max(0.0, len);
    }
    final (a, b) = q > 0 ? (l.from, l.to) : (l.to, l.from);
    out.putIfAbsent(a, () => []).add((b, volume / q.abs(), volume));
  }
  if ((out[injectionNode] ?? const []).isEmpty) codes.add('fertigation_no_flow');
  // fastest arrival: Dijkstra
  final earliest = <String, double>{injectionNode: 0};
  final queue = SplayTreeSet<(double, String)>((x, y) => x.$1 != y.$1 ? x.$1.compareTo(y.$1) : x.$2.compareTo(y.$2))..add((0, injectionNode));
  while (queue.isNotEmpty) {
    final (t, n) = queue.first;
    queue.remove(queue.first);
    if (t > earliest[n]!) continue;
    for (final (m, w, _) in out[n] ?? const <(String, double, double)>[]) {
      final nt = t + w;
      if (nt < (earliest[m] ?? double.infinity) - 1e-12) {
        if (earliest.containsKey(m)) queue.remove((earliest[m]!, m));
        earliest[m] = nt;
        queue.add((nt, m));
      }
    }
  }
  // slowest arrival: longest path in topological order over the reached nodes
  final indeg = <String, int>{for (final n in earliest.keys) n: 0};
  var volume = 0.0;
  for (final n in earliest.keys) {
    for (final (m, _, v) in out[n] ?? const <(String, double, double)>[]) {
      indeg[m] = indeg[m]! + 1;
      volume += v;
    }
  }
  final latest = <String, double>{injectionNode: 0};
  final ready = [
    for (final e in indeg.entries)
      if (e.value == 0) e.key,
  ]..sort();
  final done = <String>{};
  for (var i = 0; i < ready.length; i++) {
    final n = ready[i];
    done.add(n);
    final ln = latest[n] ?? earliest[n]!;
    for (final (m, w, _) in out[n] ?? const <(String, double, double)>[]) {
      latest[m] = math.max(latest[m] ?? -double.infinity, ln + w);
      indeg[m] = indeg[m]! - 1;
      if (indeg[m] == 0) ready.add(m);
    }
  }
  if (done.length < earliest.length) codes.add('fertigation_flow_cycle');
  final nodes = <String, TravelTime>{};
  for (final e in earliest.entries) {
    final l = done.contains(e.key) ? math.max(latest[e.key] ?? e.value, e.value) : e.value;
    nodes[e.key] = TravelTime(nodeId: e.key, earliest: e.value + offsetSeconds, latest: l + offsetSeconds);
  }
  final wanted =
      outlets?.toList() ??
      [
        for (final n in net.nodes.values)
          if (n.kind == HNodeKind.junction && ((n.emitter != null && n.emitterCount > 0 && (result.nodes[n.id]?.emitterFlow ?? 0) > 0) || n.demand > 0)) n.id,
      ];
  final reached = [
    for (final o in wanted)
      if (nodes.containsKey(o)) o,
  ];
  final unreached = [
    for (final o in wanted)
      if (!nodes.containsKey(o)) o,
  ];
  if (unreached.isNotEmpty) codes.add('fertigation_unreached');
  return FertigationTravel(injectionNode: injectionNode, nodes: nodes, outlets: reached, unreached: unreached, volume: volume, codes: codes);
}

/// What a fertigation needs.
class FertigationInput {
  const FertigationInput({
    required this.irrigationHours,
    required this.flow,
    required this.areaHa,
    required this.doseKgPerHa,
    required this.stockKgPerL,
    this.nutrientFraction = 1,
    this.preWettingFraction = 0.25,
    this.flushingFraction = 0.25,
    this.flushingMargin = 1,
    this.tankLitres = 0,
  });

  /// Duration of the irrigation (h) and the flow through the injection point
  /// (m³/s).
  final double irrigationHours;
  final double flow;

  /// Area fertilised (ha) and the dose (kg/ha) of nutrient, which is
  /// [nutrientFraction] of the product's mass (1 when the dose is of the
  /// product itself; 0.46 for the N of urea).
  final double areaHa;
  final double doseKgPerHa;
  final double nutrientFraction;

  /// Product dissolved in the stock solution (kg per litre).
  final double stockKgPerL;

  /// Shares of the irrigation time for pre-wetting and for flushing.
  final double preWettingFraction;
  final double flushingFraction;

  /// The flushing lasts at least this many times the full-concentration
  /// arrival at the farthest outlet.
  final double flushingMargin;

  /// Volume of the stock tank (L; 0 = not checked).
  final double tankLitres;
}

/// A fertigation schedule and its amounts.
class FertigationPlan {
  FertigationPlan({
    required this.preWetting,
    required this.injection,
    required this.flushing,
    required this.productKg,
    required this.stockLitres,
    required this.injectionRate,
    required this.concentration,
    required this.flow,
    required this.codes,
  });

  /// Pre-wetting, injection and flushing time (s), in that order, adding up
  /// to the irrigation time (the injection is 0 when nothing is left for it).
  final double preWetting;
  final double injection;
  final double flushing;

  /// Product mass (kg), stock solution to inject (L) and its injection rate
  /// (m³/s).
  final double productKg;
  final double stockLitres;
  final double injectionRate;

  /// Product in the irrigation water while injecting (kg/m³ = g/L).
  final double concentration;

  /// Flow through the injection point (m³/s).
  final double flow;

  /// `fertigation_too_short` (the flushing and the pre-wetting leave no time
  /// to inject), `fertigation_tank_small` (the stock solution does not fit in
  /// the tank), `fertigation_unreached` (the travel left outlets out),
  /// `fertigation_no_flow`.
  final List<String> codes;

  /// Irrigation water per volume of stock solution.
  double get dilution => injectionRate > 0 ? flow / injectionRate : 0;

  Map<String, dynamic> toJson() => {'pre': preWetting, 'inj': injection, 'flush': flushing, 'kg': productKg, 'L': stockLitres, 'qi': injectionRate, 'c': concentration, 'q': flow, 'codes': codes};
  static FertigationPlan fromJson(Map<String, dynamic> j) => FertigationPlan(
    preWetting: _d(j['pre']),
    injection: _d(j['inj']),
    flushing: _d(j['flush']),
    productKg: _d(j['kg']),
    stockLitres: _d(j['L']),
    injectionRate: _d(j['qi']),
    concentration: _d(j['c']),
    flow: _d(j['q']),
    codes: ((j['codes'] as List?) ?? []).cast<String>(),
  );
}

/// The schedule and amounts of [input] with the [travel] times (see the
/// library comment).
FertigationPlan planFertigation(FertigationInput input, FertigationTravel travel) {
  final codes = <String>[];
  final total = math.max(0.0, input.irrigationHours) * 3600;
  final pre = total * input.preWettingFraction.clamp(0.0, 1.0);
  final flush = math.max(total * input.flushingFraction.clamp(0.0, 1.0), travel.fullArrival * math.max(input.flushingMargin, 0.0));
  var injection = total - pre - flush;
  if (injection <= 0) {
    injection = 0;
    codes.add('fertigation_too_short');
  }
  final product = math.max(0.0, input.doseKgPerHa) * math.max(0.0, input.areaHa) / (input.nutrientFraction > 0 ? input.nutrientFraction : 1);
  final litres = input.stockKgPerL > 0 ? product / input.stockKgPerL : 0.0;
  if (input.tankLitres > 0 && litres > input.tankLitres + 1e-9) codes.add('fertigation_tank_small');
  final rate = injection > 0 ? litres / 1000 / injection : 0.0;
  final conc = injection > 0 && input.flow > 0 ? product / (input.flow * injection) : 0.0;
  if (travel.unreached.isNotEmpty) codes.add('fertigation_unreached');
  if (travel.codes.contains('fertigation_no_flow')) codes.add('fertigation_no_flow');
  // whatever is left after injecting is flushing
  final flushing = injection > 0 ? flush : math.max(0.0, total - pre);
  return FertigationPlan(preWetting: pre, injection: injection, flushing: flushing, productKg: product, stockLitres: litres, injectionRate: rate, concentration: conc, flow: input.flow, codes: codes);
}

/// A venturi injector: its suction against the pressure differential, or,
/// without a curve, the least differential it needs as a share of the inlet
/// pressure. Twenty per cent is a common rule of thumb for the start of
/// suction; the manufacturer's curve, when known, takes precedence.
class VenturiSpec {
  const VenturiSpec({this.curve = const [], this.minDifferentialFraction = 0.2});

  /// (differential pressure head across the injector (m), suction flow
  /// (m³/s)) points, by increasing differential.
  final List<(double, double)> curve;
  final double minDifferentialFraction;
}

/// Outcome of [checkVenturi].
class VenturiCheck {
  VenturiCheck({required this.requiredDifferential, required this.availableDifferential, required this.suctionCapacity, required this.ok, required this.codes});

  /// Differential the injection needs and the one available across the
  /// bypassed device (m).
  final double requiredDifferential;
  final double availableDifferential;

  /// Suction at the available differential (m³/s; NaN without a curve).
  final double suctionCapacity;
  final bool ok;

  /// `venturi_insufficient_differential`, `venturi_capacity_exceeded` (the
  /// injection rate is above the whole curve).
  final List<String> codes;

  Map<String, dynamic> toJson() => {'req': requiredDifferential, 'avail': availableDifferential, 'cap': suctionCapacity.isFinite ? suctionCapacity : null, 'ok': ok, 'codes': codes};
}

/// Whether a venturi of [spec], drawing [injectionRate] (m³/s) with
/// [inletPressure] (m) upstream, works on a bypass across a device whose head
/// loss is [availableDifferential] (m): the loss of the regulator, filter or
/// valve it bypasses, from the network solution.
VenturiCheck checkVenturi(VenturiSpec spec, {required double injectionRate, required double inletPressure, required double availableDifferential}) {
  final codes = <String>[];
  double required;
  var capacity = double.nan;
  final pts = [...spec.curve]..sort((a, b) => a.$1.compareTo(b.$1));
  if (pts.length >= 2) {
    double suction(double dp) {
      if (dp <= pts.first.$1) return dp <= 0 ? 0 : pts.first.$2 * dp / pts.first.$1;
      for (var i = 1; i < pts.length; i++) {
        if (dp <= pts[i].$1) return pts[i - 1].$2 + (pts[i].$2 - pts[i - 1].$2) * (dp - pts[i - 1].$1) / (pts[i].$1 - pts[i - 1].$1);
      }
      return pts.last.$2;
    }

    capacity = suction(math.max(0.0, availableDifferential));
    if (injectionRate > pts.last.$2 + 1e-15) {
      codes.add('venturi_capacity_exceeded');
      required = pts.last.$1;
    } else {
      // the smallest differential that draws the injection rate
      required = pts.first.$1;
      if (injectionRate > pts.first.$2) {
        for (var i = 1; i < pts.length; i++) {
          if (injectionRate <= pts[i].$2 + 1e-15) {
            final span = pts[i].$2 - pts[i - 1].$2;
            required = span > 0 ? pts[i - 1].$1 + (pts[i].$1 - pts[i - 1].$1) * (injectionRate - pts[i - 1].$2) / span : pts[i].$1;
            break;
          }
        }
      } else if (pts.first.$2 > 0) {
        required = pts.first.$1 * injectionRate / pts.first.$2;
      }
    }
  } else {
    required = spec.minDifferentialFraction * math.max(0.0, inletPressure);
  }
  final ok = availableDifferential >= required - 1e-9 && !codes.contains('venturi_capacity_exceeded');
  if (availableDifferential < required - 1e-9) codes.add('venturi_insufficient_differential');
  return VenturiCheck(requiredDifferential: required, availableDifferential: availableDifferential, suctionCapacity: capacity, ok: ok, codes: codes);
}

double _d(Object? v, [double def = 0]) => (v as num?)?.toDouble() ?? def;
