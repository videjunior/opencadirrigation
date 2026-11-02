/// Criticality (N−1) of a pipe network: every chosen link is closed in turn
/// and, per scenario, the demand cut off from every source, the demand the
/// remaining pressures cannot deliver and the pressure deficits at the demand
/// nodes are reported.
///
/// In a network fed by a single source through a tree (a branched mainline)
/// closing a pipe cuts off everything downstream of it and the pressures of
/// the rest cannot fall (less flow, smaller losses, a falling pump curve
/// gives more head), so the downstream loss is reported directly, without a
/// solution. Elsewhere the part still connected to a source is re-solved.
///
/// The module also holds the network helpers the scenario analyses share: a
/// deep copy of a [HydraulicNetwork] and the pressure-driven solution of
/// demands that need a minimum pressure (used for hydrants with a flow
/// limiter in `on_demand.dart`).
library;

import 'dart:math' as math;

import '../hydraulics/emitter.dart';
import '../hydraulics/network.dart';

/// Deep copy of [net]: new [HNode] and [HLink] objects with the same data, so
/// a scenario can change demands, emitters, roughness or statuses without
/// touching [net]. Nodes outside [keepNodes] (when given) and links for which
/// [keepLink] is false are left out, and so is every link to a node left out.
HydraulicNetwork copyNetwork(HydraulicNetwork net, {bool Function(HLink l)? keepLink, Set<String>? keepNodes, NetworkOptions? options}) {
  final out = HydraulicNetwork(options: options ?? net.options);
  for (final n in net.nodes.values) {
    if (keepNodes != null && !keepNodes.contains(n.id)) continue;
    out.addNode(
      HNode(
        id: n.id,
        kind: n.kind,
        elevation: n.elevation,
        demand: n.demand,
        fixedHead: n.fixedHead,
        emitter: n.emitter,
        emitterCount: n.emitterCount,
        emitterOffset: n.emitterOffset,
        label: n.label,
        tag: n.tag,
      ),
    );
  }
  for (final l in net.links) {
    if (keepLink != null && !keepLink(l)) continue;
    if (!out.nodes.containsKey(l.from) || !out.nodes.containsKey(l.to)) continue;
    out.addLink(
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
  }
  return out;
}

/// Ids of the nodes joined to a fixed-head node (reservoir) through links
/// that are not closed and not in [removed]. Flow direction is ignored: a
/// check valve, a pump or a PRV may still stop the water, which the solution
/// then shows as a pressure deficit.
Set<String> nodesReachingSource(HydraulicNetwork net, {Set<String> removed = const {}}) {
  final adj = <String, List<String>>{};
  for (final l in net.links) {
    if (l.kind == HLinkKind.closed || removed.contains(l.id)) continue;
    adj.putIfAbsent(l.from, () => []).add(l.to);
    adj.putIfAbsent(l.to, () => []).add(l.from);
  }
  final seen = <String>{
    for (final n in net.nodes.values)
      if (n.kind == HNodeKind.reservoir) n.id,
  };
  final queue = [...seen];
  for (var i = 0; i < queue.length; i++) {
    for (final o in adj[queue[i]] ?? const <String>[]) {
      if (seen.add(o)) queue.add(o);
    }
  }
  return seen;
}

/// A demand that needs a pressure: [demand] (m³/s) at [nodeId] is delivered
/// in full while the pressure head there is at least [requiredPressure] (m);
/// below it the delivery falls like an orifice, q = demand·√(p / p_req), and
/// stops at p ≤ 0 (Wagner, Shamir & Marks 1988, "Water distribution
/// reliability: simulation methods", J. Water Resources Planning and
/// Management 114(3), with zero minimum pressure). A hydrant with a flow
/// limiter behaves this way: the limiter holds the nominal discharge above
/// its minimum pressure.
class PressureDemand {
  const PressureDemand({required this.nodeId, required this.demand, required this.requiredPressure});
  final String nodeId;
  final double demand;
  final double requiredPressure;
}

/// Outcome of [solvePressureDriven].
class PressureDrivenResult {
  PressureDrivenResult({required this.result, required this.delivered, required this.demand, required this.reduced, required this.rounds, required this.settled});

  /// The last network solution.
  final NetworkResult result;

  /// Flow delivered at every pressure-demand node (m³/s), never above its
  /// demand.
  final Map<String, double> delivered;

  /// Demand of every pressure-demand node (m³/s).
  final Map<String, double> demand;

  /// Nodes that ended below their required pressure (orifice regime).
  final Set<String> reduced;

  /// Network solutions used.
  final int rounds;

  /// False when a node kept switching between the two regimes: it is then
  /// left in the orifice regime, at about its required pressure, with its
  /// delivery capped at the demand.
  final bool settled;

  /// Demand not delivered (m³/s).
  double get unmet => demand.entries.fold(0.0, (s, e) => s + math.max(0.0, e.value - (delivered[e.key] ?? 0)));
}

/// Solves [net] with every demand of [demands] delivered in full where its
/// pressure reaches the required one and through an orifice law below it
/// ([PressureDemand]). The nodes' own fixed demands stay as other
/// consumption; [net] is restored before returning.
///
/// The solver has no flow-limited outlet, so the two regimes are an active
/// set: every node starts with its full demand as a fixed demand (what a flow
/// limiter delivers above its minimum pressure); a node below its required
/// pressure becomes an emitter q = (d/√p_req)·p^0.5 in the next solution,
/// and an emitter node that rises above the requirement (its law would then
/// exceed d) goes back to the fixed demand; the rounds stop when the set no
/// longer changes (at most [maxRounds]). Moving a node to the orifice regime
/// only lowers the flows and raises the pressures, so the set settles in a
/// few rounds. A steep device loss curve (h ∝ Q^n, n ≫ 2) in series with an
/// orifice would also cap the flow, but the gradient method shrinks an
/// over-estimated flow through such a law only by a factor (1 − 1/n) per
/// iteration and holds the cap only approximately; the active set gives the
/// two-regime law exactly. A node that already has an emitter of its own
/// keeps its demand fixed.
PressureDrivenResult solvePressureDriven(HydraulicNetwork net, List<PressureDemand> demands, {int maxRounds = 12}) {
  final demand = <String, double>{};
  final required = <String, double>{};
  for (final d in demands) {
    if (!net.nodes.containsKey(d.nodeId) || !(d.demand > 0)) continue;
    demand[d.nodeId] = (demand[d.nodeId] ?? 0) + d.demand;
    // two demands on one node: the stricter requirement
    required[d.nodeId] = math.max(required[d.nodeId] ?? 0, d.requiredPressure);
  }
  final saved = {for (final id in demand.keys) id: (net.nodes[id]!.demand, net.nodes[id]!.emitter, net.nodes[id]!.emitterCount, net.nodes[id]!.emitterOffset)};
  final orifice = <String>{};
  final flips = <String, int>{};
  var settled = true;
  var rounds = 0;
  late NetworkResult r;
  const tol = 1e-3;
  try {
    while (true) {
      rounds++;
      for (final id in demand.keys) {
        final n = net.nodes[id]!;
        final (base, em, count, offset) = saved[id]!;
        final preq = required[id]!;
        if (orifice.contains(id) && em == null && preq > 0) {
          n.demand = base;
          n.emitter = EmitterCurve(k: demand[id]! / math.sqrt(preq), x: 0.5);
          n.emitterCount = 1;
          n.emitterOffset = 0;
        } else {
          n.demand = base + demand[id]!;
          n.emitter = em;
          n.emitterCount = count;
          n.emitterOffset = offset;
        }
      }
      final res = net.solve();
      r = res;
      var changed = false;
      for (final id in demand.keys) {
        final preq = required[id]!;
        if (saved[id]!.$2 != null || preq <= 0) continue;
        final p = res.nodes[id]?.pressure ?? 0;
        if (!orifice.contains(id)) {
          if (p < preq - tol) {
            orifice.add(id);
            changed = true;
          }
        } else if (p > preq + tol) {
          // the orifice would over-deliver: the true state is at the limit
          if ((flips[id] ?? 0) >= 2) {
            settled = false;
            continue;
          }
          flips[id] = (flips[id] ?? 0) + 1;
          orifice.remove(id);
          changed = true;
        }
      }
      if (!changed) break;
      if (rounds >= maxRounds) {
        settled = false;
        break;
      }
    }
  } finally {
    for (final e in saved.entries) {
      final n = net.nodes[e.key]!;
      final (base, em, count, offset) = e.value;
      n.demand = base;
      n.emitter = em;
      n.emitterCount = count;
      n.emitterOffset = offset;
    }
  }
  final delivered = <String, double>{};
  for (final id in demand.keys) {
    final nr = r.nodes[id];
    delivered[id] = orifice.contains(id) ? math.min(demand[id]!, nr?.emitterFlow ?? 0) : demand[id]!;
  }
  return PressureDrivenResult(result: r, delivered: delivered, demand: demand, reduced: orifice, rounds: rounds, settled: settled);
}

/// A demand node below its required pressure.
class NodeDeficit {
  NodeDeficit({required this.nodeId, required this.requiredPressure, required this.pressure, required this.demand, required this.delivered});
  final String nodeId;

  /// Required and computed pressure head (m).
  final double requiredPressure;
  final double pressure;

  /// Demand and the delivery estimated by the pressure-driven solution
  /// (m³/s; equal to the demand when that solution was not run).
  final double demand;
  final double delivered;
  double get deficit => requiredPressure - pressure;

  Map<String, dynamic> toJson() => {'node': nodeId, 'req': requiredPressure, 'p': pressure, 'q': demand, 'del': delivered};
  static NodeDeficit fromJson(Map<String, dynamic> j) => NodeDeficit(
    nodeId: j['node'] as String,
    requiredPressure: (j['req'] as num?)?.toDouble() ?? 0,
    pressure: (j['p'] as num?)?.toDouble() ?? 0,
    demand: (j['q'] as num?)?.toDouble() ?? 0,
    delivered: (j['del'] as num?)?.toDouble() ?? 0,
  );
}

/// One scenario: a link closed.
class CriticalityScenario {
  CriticalityScenario({required this.linkId, required this.cutOffNodes, required this.cutOffDemand, required this.unmetDemand, required this.deficits, required this.solved, required this.converged});
  final String linkId;

  /// Demand nodes no longer joined to any source, and their demand (m³/s).
  final List<String> cutOffNodes;
  final double cutOffDemand;

  /// Demand of the nodes still connected that is not delivered (m³/s): the
  /// emitter outflow lost to lower pressures and, with the pressure-driven
  /// solution, the demand of the nodes below their required pressure.
  final double unmetDemand;

  /// Connected demand nodes below their required pressure, by the
  /// demand-driven solution (every demand drawn in full).
  final List<NodeDeficit> deficits;

  /// False when the downstream loss of a tree was reported without a
  /// solution (the deficits are then those of the intact network, an upper
  /// bound).
  final bool solved;
  final bool converged;

  double get lostDemand => cutOffDemand + unmetDemand;
  double get maxDeficit => deficits.fold(0.0, (m, d) => math.max(m, d.deficit));

  Map<String, dynamic> toJson() => {
    'link': linkId,
    'cut': cutOffNodes,
    'qcut': cutOffDemand,
    'qunmet': unmetDemand,
    'def': deficits.map((d) => d.toJson()).toList(),
    'solved': solved,
    'conv': converged,
  };
  static CriticalityScenario fromJson(Map<String, dynamic> j) => CriticalityScenario(
    linkId: j['link'] as String,
    cutOffNodes: ((j['cut'] as List?) ?? []).cast<String>(),
    cutOffDemand: (j['qcut'] as num?)?.toDouble() ?? 0,
    unmetDemand: (j['qunmet'] as num?)?.toDouble() ?? 0,
    deficits: ((j['def'] as List?) ?? []).map((d) => NodeDeficit.fromJson(d as Map<String, dynamic>)).toList(),
    solved: j['solved'] as bool? ?? true,
    converged: j['conv'] as bool? ?? true,
  );
}

/// Outcome of [analyzeCriticality].
class CriticalityResult {
  CriticalityResult({required this.scenarios, required this.totalDemand, required this.baseDeficits, required this.baseUnmet, required this.tree, required this.codes});

  /// One scenario per tested link, in the order asked.
  final List<CriticalityScenario> scenarios;

  /// Demand of the intact network (m³/s): fixed demands plus the emitter
  /// flows of its solution.
  final double totalDemand;

  /// The intact network's own deficits and pressure-driven shortfall.
  final List<NodeDeficit> baseDeficits;
  final double baseUnmet;

  /// The network is a tree fed by one source (downstream losses reported
  /// directly).
  final bool tree;

  /// `criticality_base_not_converged`, `criticality_unknown_link:<id>`,
  /// `criticality_not_converged:<link id>`.
  final List<String> codes;

  /// Scenarios from the worst: lost demand, then the largest deficit.
  List<CriticalityScenario> get ranked => [...scenarios]
    ..sort((a, b) {
      if ((a.lostDemand - b.lostDemand).abs() > 1e-12) return b.lostDemand.compareTo(a.lostDemand);
      final d = b.maxDeficit.compareTo(a.maxDeficit);
      return d != 0 ? d : a.linkId.compareTo(b.linkId);
    });

  Map<String, dynamic> toJson() => {
    'scen': scenarios.map((s) => s.toJson()).toList(),
    'q': totalDemand,
    'base': baseDeficits.map((d) => d.toJson()).toList(),
    'baseUnmet': baseUnmet,
    'tree': tree,
    'codes': codes,
  };
  static CriticalityResult fromJson(Map<String, dynamic> j) => CriticalityResult(
    scenarios: ((j['scen'] as List?) ?? []).map((s) => CriticalityScenario.fromJson(s as Map<String, dynamic>)).toList(),
    totalDemand: (j['q'] as num?)?.toDouble() ?? 0,
    baseDeficits: ((j['base'] as List?) ?? []).map((d) => NodeDeficit.fromJson(d as Map<String, dynamic>)).toList(),
    baseUnmet: (j['baseUnmet'] as num?)?.toDouble() ?? 0,
    tree: j['tree'] as bool? ?? false,
    codes: ((j['codes'] as List?) ?? []).cast<String>(),
  );
}

/// N−1 analysis of [net]: each link of [linkIds] (default: every pipe) is
/// closed in turn. [requiredPressure] gives the pressure head (m) each demand
/// node needs (for a mainline, the required upstream head of every zone at
/// its valve node); nodes without one only count when they are cut off.
/// Demands are the nodes' fixed demands plus the emitter flows of the intact
/// network. With [pressureDriven] the connected nodes are also solved with
/// [solvePressureDriven] to estimate the demand not delivered; with
/// [treeShortcut] a tree fed by one source is not re-solved (see the library
/// comment). Deficits under [minDeficit] (m) are ignored. [net] is not
/// changed.
CriticalityResult analyzeCriticality(
  HydraulicNetwork net, {
  Map<String, double> requiredPressure = const {},
  Iterable<String>? linkIds,
  bool pressureDriven = true,
  bool treeShortcut = true,
  double minDeficit = 0.01,
}) {
  final codes = <String>[];
  final base = copyNetwork(net);
  final r0 = base.solve();
  if (!r0.converged) codes.add('criticality_base_not_converged');
  // base demand of every junction: fixed demand and emitter outflow
  final demand = <String, double>{};
  final emitterBase = <String, double>{};
  for (final n in net.nodes.values) {
    if (n.kind != HNodeKind.junction) continue;
    final qe = r0.nodes[n.id]?.emitterFlow ?? 0;
    if (qe > 0) emitterBase[n.id] = qe;
    final q = math.max(0.0, n.demand) + qe;
    if (q > 0) demand[n.id] = q;
  }
  final total = demand.values.fold(0.0, (s, q) => s + q);
  final tree = _singleSourceForest(net);

  /// Deficits and pressure-driven shortfall of [scen] (a copy restricted to
  /// the nodes still connected).
  (List<NodeDeficit>, double, bool) evaluate(HydraulicNetwork scen) {
    final r = scen.solve();
    var delivered = <String, double>{};
    var unmet = 0.0;
    var converged = r.converged;
    var last = r;
    if (pressureDriven) {
      final pd = <PressureDemand>[];
      for (final id in scen.nodes.keys) {
        final n = scen.nodes[id]!;
        final preq = requiredPressure[id] ?? 0;
        if (n.kind != HNodeKind.junction || !(n.demand > 0) || preq <= 0 || n.emitter != null) continue;
        pd.add(PressureDemand(nodeId: id, demand: n.demand, requiredPressure: preq));
      }
      if (pd.isNotEmpty) {
        // the pressure demands replace the nodes' fixed demands
        final saved = {for (final d in pd) d.nodeId: scen.nodes[d.nodeId]!.demand};
        for (final d in pd) {
          scen.nodes[d.nodeId]!.demand = 0;
        }
        final res = solvePressureDriven(scen, pd);
        for (final e in saved.entries) {
          scen.nodes[e.key]!.demand = e.value;
        }
        delivered = res.delivered;
        unmet += res.unmet;
        converged = converged && res.result.converged;
        last = res.result;
      }
    }
    // emitters (mainline outlets) deliver less at a lower pressure
    for (final e in emitterBase.entries) {
      if (!scen.nodes.containsKey(e.key)) continue;
      unmet += math.max(0.0, e.value - (last.nodes[e.key]?.emitterFlow ?? 0));
    }
    final deficits = <NodeDeficit>[];
    for (final e in requiredPressure.entries) {
      final nr = r.nodes[e.key];
      final q = demand[e.key] ?? 0;
      if (nr == null || q <= 0 || e.value <= 0) continue;
      if (e.value - nr.pressure > minDeficit) deficits.add(NodeDeficit(nodeId: e.key, requiredPressure: e.value, pressure: nr.pressure, demand: q, delivered: delivered[e.key] ?? q));
    }
    return (deficits, unmet, converged);
  }

  final (baseDeficits, baseUnmet, _) = evaluate(copyNetwork(net));
  final linkById = {for (final l in net.links) l.id: l};
  final scenarios = <CriticalityScenario>[];
  for (final id
      in linkIds ??
          [
            for (final l in net.links)
              if (l.kind == HLinkKind.pipe) l.id,
          ]) {
    if (!linkById.containsKey(id)) {
      codes.add('criticality_unknown_link:$id');
      continue;
    }
    final reach = nodesReachingSource(net, removed: {id});
    final cut = [
      for (final n in demand.keys)
        if (!reach.contains(n)) n,
    ]..sort();
    final cutQ = cut.fold(0.0, (s, n) => s + demand[n]!);
    if (tree && treeShortcut) {
      scenarios.add(
        CriticalityScenario(
          linkId: id,
          cutOffNodes: cut,
          cutOffDemand: cutQ,
          solved: false,
          converged: r0.converged,
          deficits: [
            for (final d in baseDeficits)
              if (reach.contains(d.nodeId)) d,
          ],
          unmetDemand: cut.isEmpty ? baseUnmet : _unmetWithout(baseDeficits, reach, baseUnmet),
        ),
      );
      continue;
    }
    final scen = copyNetwork(net, keepLink: (l) => l.id != id, keepNodes: reach);
    final (deficits, unmet, converged) = evaluate(scen);
    if (!converged) codes.add('criticality_not_converged:$id');
    scenarios.add(CriticalityScenario(linkId: id, cutOffNodes: cut, cutOffDemand: cutQ, unmetDemand: unmet, deficits: deficits, solved: true, converged: converged));
  }
  return CriticalityResult(scenarios: scenarios, totalDemand: total, baseDeficits: baseDeficits, baseUnmet: baseUnmet, tree: tree, codes: codes);
}

/// Shortfall of the intact network left among the nodes in [reach] (the
/// shortfall of nodes now cut off is counted with the cut-off demand).
double _unmetWithout(List<NodeDeficit> deficits, Set<String> reach, double total) {
  var lost = 0.0;
  for (final d in deficits) {
    if (!reach.contains(d.nodeId)) lost += math.max(0.0, d.demand - d.delivered);
  }
  return math.max(0.0, total - lost);
}

/// Whether the open links of [net] form a forest with at most one fixed-head
/// node in each tree.
bool _singleSourceForest(HydraulicNetwork net) {
  final ids = net.nodes.keys.toList();
  final index = {for (var i = 0; i < ids.length; i++) ids[i]: i};
  final parent = List<int>.generate(ids.length, (i) => i);
  int find(int x) {
    while (parent[x] != x) {
      parent[x] = parent[parent[x]];
      x = parent[x];
    }
    return x;
  }

  for (final l in net.links) {
    if (l.kind == HLinkKind.closed) continue;
    final a = index[l.from], b = index[l.to];
    if (a == null || b == null) continue;
    final ra = find(a), rb = find(b);
    if (ra == rb) return false; // a loop
    parent[ra] = rb;
  }
  final sources = <int, int>{};
  for (final n in net.nodes.values) {
    if (n.kind != HNodeKind.reservoir) continue;
    final root = find(index[n.id]!);
    sources[root] = (sources[root] ?? 0) + 1;
    if (sources[root]! > 1) return false;
  }
  return true;
}
