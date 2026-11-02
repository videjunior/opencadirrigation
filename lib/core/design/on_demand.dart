/// On-demand collective networks: design flows per pipe of a branched
/// network of hydrants by Clément's first formula, and the check of a network
/// against random configurations of open hydrants, both as in FAO Irrigation
/// and Drainage Paper 59 (Lamaddalena & Sagardoy 2000, "Performance analysis
/// of on-demand pressurized irrigation systems").
///
/// Clément (1966, "Calcul des débits dans les réseaux d'irrigation
/// fonctionnant à la demande", La Houille Blanche 5): every hydrant i is open
/// with probability p_i, independently of the others, so the flow of a
/// section serving the hydrants downstream of it, not exceeded with the
/// operating quality Pq, is
///
///     Q = Σ p_i·d_i + U(Pq)·√(Σ p_i·(1 − p_i)·d_i²)        (FAO 59 eq. 12)
///
/// with d_i the nominal discharge and U(Pq) the standard normal deviate
/// (1.645 for 95 %). p_i = t_i / T', t_i being the hours hydrant i must be
/// open per day of the peak period and T' = r·24 h the network's operating
/// time (r the coefficient of utilisation), or p_i = q_s·A_i / (r·d_i) from
/// the specific continuous discharge q_s and the plot area A_i (eq. 3). At
/// the extremities the flows are summed: a section serving N_min hydrants or
/// fewer carries them all, no section carries less than its N_min largest
/// hydrants, and a section never carries less than one downstream of it
/// (FAO 59: N_min between four and ten, 4 in its Box 1). With equal
/// hydrants the number open is rounded up, as in Box 1.
///
/// The random check (FAO 59 chapter 5) solves C configurations of hydrants
/// open at once with the network solver. An open hydrant j of configuration
/// r is satisfied when its pressure head H_j,r ≥ H_min; per hydrant the
/// relative pressure deficit ΔH_j,r = (H_j,r − H_min) / H_min (eq. 52) and
/// the reliability α_j = Σ_r Ih_j,r·Ip_j,r / Σ_r Ih_j,r (eq. 54, the share of
/// the configurations with the hydrant open in which it is satisfied) are
/// reported, and per configuration the percentage of unsatisfied hydrants.
/// With an upstream discharge Q the configurations come from the random
/// generation model of FAO 59 chapter 3: hydrants drawn uniformly at random,
/// without replacement, until |Q_conf − Q| < ε, ε being the smallest hydrant
/// discharge (Bethery et al. 1981); without one every hydrant is open
/// independently with its probability (Clément's hypothesis). The draws come
/// from a seeded [Mrg32k3a], so a check is reproducible on every platform.
///
/// Hydrants have flow limiters. FAO 59 assumes every open hydrant draws its
/// nominal discharge whatever its pressure, which a demand-driven solution
/// gives directly (the default). With [RandomCheckOptions.flowLimited] a
/// hydrant below H_min delivers like an orifice instead, through the active
/// set of [solvePressureDriven] (see there why not a steep device curve).
library;

import 'dart:math' as math;

import '../hydraulics/friction.dart';
import '../hydraulics/minor_losses.dart';
import '../hydraulics/network.dart';
import 'criticality.dart';

/// Combined multiple-recursive random number generator MRG32k3a (L'Ecuyer
/// 1999, "Good parameters and implementations for combined multiple
/// recursive random number generators", Operations Research 47(1)). Every
/// operation is exact in double precision, so a seed gives the same sequence
/// on the VM, in the browser and across releases, which `dart:math` Random
/// does not promise.
class Mrg32k3a {
  Mrg32k3a._(this._s10, this._s11, this._s12, this._s20, this._s21, this._s22);

  /// A generator seeded from [seed] (its six state words come from a Lehmer
  /// sequence, x ← 48271·x mod (2³¹ − 1), started at |seed| mod (2³¹ − 2) + 1).
  factory Mrg32k3a([int seed = 12345]) {
    var x = seed.abs() % 2147483646 + 1;
    double next() {
      x = 48271 * x % 2147483647;
      return x.toDouble();
    }

    return Mrg32k3a._(next(), next(), next(), next(), next(), next());
  }

  /// The generator in a given state (s10, s11, s12 below m1 and s20, s21, s22
  /// below m2, neither triple all zero), as in the reference code.
  factory Mrg32k3a.fromState(List<double> s) => Mrg32k3a._(s[0], s[1], s[2], s[3], s[4], s[5]);

  static const double _m1 = 4294967087, _m2 = 4294944443, _a12 = 1403580, _a13n = 810728, _a21 = 527612, _a23n = 1370589, _norm = 2.328306549295727688e-10;
  double _s10, _s11, _s12, _s20, _s21, _s22;

  /// Uniform deviate in (0, 1).
  double nextDouble() {
    var p1 = _a12 * _s11 - _a13n * _s10;
    p1 -= (p1 / _m1).truncateToDouble() * _m1;
    if (p1 < 0) p1 += _m1;
    _s10 = _s11;
    _s11 = _s12;
    _s12 = p1;
    var p2 = _a21 * _s22 - _a23n * _s20;
    p2 -= (p2 / _m2).truncateToDouble() * _m2;
    if (p2 < 0) p2 += _m2;
    _s20 = _s21;
    _s21 = _s22;
    _s22 = p2;
    return p1 <= p2 ? (p1 - p2 + _m1) * _norm : (p1 - p2) * _norm;
  }

  /// Uniform integer in 0 ≤ k < [n].
  int nextInt(int n) => math.min(n - 1, (nextDouble() * n).floor());
}

/// Standard normal quantile: the U with Φ(U) = [p], 0 < p < 1 (Wichura
/// 1988, "Algorithm AS 241: the percentage points of the normal
/// distribution", Applied Statistics 37(3), PPND16, about 16 digits).
double normalQuantile(double p) {
  if (!(p > 0 && p < 1)) return p <= 0 ? double.negativeInfinity : double.infinity;
  final q = p - 0.5;
  if (q.abs() <= 0.425) {
    final r = 0.180625 - q * q;
    return q *
        (((((((2509.0809287301226727 * r + 33430.575583588128105) * r + 67265.770927008700853) * r + 45921.953931549871457) * r + 13731.693765509461125) * r + 1971.5909503065514427) * r +
                    133.14166789178437745) *
                r +
            3.3871328727963666080) /
        (((((((5226.4952788528545610 * r + 28729.085735721942674) * r + 39307.895800092710610) * r + 21213.794301586595867) * r + 5394.1960214247511077) * r + 687.18700749205790830) * r +
                    42.313330701600911252) *
                r +
            1);
  }
  var r = math.sqrt(-math.log(q < 0 ? p : 1 - p));
  double x;
  if (r <= 5) {
    r -= 1.6;
    x =
        (((((((7.74545014278341407640e-4 * r + 0.0227238449892691845833) * r + 0.241780725177450611770) * r + 1.27045825245236838258) * r + 3.64784832476320460504) * r + 5.76949722146069140550) * r +
                    4.63033784615654529590) *
                r +
            1.42343711074968357734) /
        (((((((1.05075007164441684324e-9 * r + 5.47593808499534494600e-4) * r + 0.0151986665636164571966) * r + 0.148103976427480074590) * r + 0.689767334985100004550) * r + 1.67638483018380384940) *
                        r +
                    2.05319162663775882187) *
                r +
            1);
  } else {
    r -= 5;
    x =
        (((((((2.01033439929228813265e-7 * r + 2.71155556874348757815e-5) * r + 1.24266094738807843860e-3) * r + 0.0265321895265761230930) * r + 0.296560571828504891230) * r +
                            1.78482653991729133580) *
                        r +
                    5.46378491116411436990) *
                r +
            6.65790464350110377720) /
        (((((((2.04426310338993978564e-15 * r + 1.42151175831644588870e-7) * r + 1.84631831751005468180e-5) * r + 7.86869131145613259100e-4) * r + 0.0148753612908506148525) * r +
                            0.136929880922735805310) *
                        r +
                    0.599832206555887937690) *
                r +
            1);
  }
  return q < 0 ? -x : x;
}

/// A hydrant of an on-demand network, at a node of the [HydraulicNetwork].
class Hydrant {
  const Hydrant({required this.id, required this.nodeId, required this.discharge, this.minPressure = 20, this.probability, this.hoursPerDay = 0, this.areaHa = 0});
  final String id;
  final String nodeId;

  /// Nominal discharge d (m³/s): the setting of its flow limiter.
  final double discharge;

  /// Least pressure head the on-farm system needs (H_min, m).
  final double minPressure;

  /// Probability of being open, when known; otherwise from [hoursPerDay] or
  /// from [areaHa] (see [ClementOptions]).
  final double? probability;

  /// Hours the hydrant must be open per day of the peak period (t).
  final double hoursPerDay;

  /// Plot area it serves (ha).
  final double areaHa;

  Map<String, dynamic> toJson() => {'id': id, 'node': nodeId, 'd': discharge, 'hmin': minPressure, if (probability != null) 'p': probability, 'h': hoursPerDay, 'a': areaHa};
  static Hydrant fromJson(Map<String, dynamic> j) => Hydrant(
    id: j['id'] as String,
    nodeId: j['node'] as String,
    discharge: (j['d'] as num?)?.toDouble() ?? 0,
    minPressure: (j['hmin'] as num?)?.toDouble() ?? 20,
    probability: (j['p'] as num?)?.toDouble(),
    hoursPerDay: (j['h'] as num?)?.toDouble() ?? 0,
    areaHa: (j['a'] as num?)?.toDouble() ?? 0,
  );
}

/// Parameters of [clementFlows].
class ClementOptions {
  const ClementOptions({this.operatingQuality = 0.95, this.u, this.utilisation = 1, this.specificContinuousFlow = 0, this.minSimultaneous = 4, this.roundToWholeHydrants = true});

  /// Operating quality Pq: probability that a section's flow is not exceeded
  /// (FAO 59: 0.95 to 0.99).
  final double operatingQuality;

  /// U(Pq) to use instead of the exact quantile of [operatingQuality] (FAO
  /// 59 Table 1 rounds 95 % to 1.645).
  final double? u;

  /// Coefficient of utilisation r = T'/T: the network operates r·24 h a day
  /// (FAO 59: usually 16/24 to 22/24).
  final double utilisation;

  /// Specific continuous discharge q_s (m³/s per ha, 24 h a day), for the
  /// probabilities from the plot areas.
  final double specificContinuousFlow;

  /// N_min: sections serving this many hydrants or fewer carry them all, and
  /// none carries less than its N_min largest hydrants.
  final int minSimultaneous;

  /// With equal hydrants downstream, round the number open up (FAO 59 Box 1).
  final bool roundToWholeHydrants;
}

/// Which rule set the design flow of a section.
enum ClementRule {
  /// Clément's formula (rounded up to whole hydrants when they are equal).
  formula,

  /// Every hydrant downstream (few hydrants, or the formula above their sum).
  allOpen,

  /// The N_min largest hydrants downstream.
  minimumOpen,

  /// A section downstream carries more.
  downstream,
}

/// Design flow of one link.
class ClementFlow {
  ClementFlow({
    required this.linkId,
    required this.downstreamNode,
    required this.hydrants,
    required this.meanFlow,
    required this.stdFlow,
    required this.formulaFlow,
    required this.flow,
    required this.rule,
    required this.headLoss,
  });
  final String linkId;

  /// Node at the end away from the source.
  final String downstreamNode;

  /// Hydrants downstream of the link.
  final int hydrants;

  /// Σ p·d and √(Σ p·(1 − p)·d²) of those hydrants (m³/s).
  final double meanFlow;
  final double stdFlow;

  /// Σ p·d + U·σ, before the extremity rules (m³/s).
  final double formulaFlow;

  /// Design flow (m³/s).
  final double flow;
  final ClementRule rule;

  /// Head loss of the link at the design flow (m; negative across a pump).
  final double headLoss;

  Map<String, dynamic> toJson() => {'link': linkId, 'node': downstreamNode, 'n': hydrants, 'mean': meanFlow, 'std': stdFlow, 'qf': formulaFlow, 'q': flow, 'rule': rule.name, 'hl': headLoss};
  static ClementFlow fromJson(Map<String, dynamic> j) => ClementFlow(
    linkId: j['link'] as String,
    downstreamNode: j['node'] as String? ?? '',
    hydrants: (j['n'] as num?)?.toInt() ?? 0,
    meanFlow: _d(j['mean']),
    stdFlow: _d(j['std']),
    formulaFlow: _d(j['qf']),
    flow: _d(j['q']),
    rule: ClementRule.values.firstWhere((r) => r.name == j['rule'], orElse: () => ClementRule.formula),
    headLoss: _d(j['hl']),
  );
}

/// Outcome of [clementFlows].
class ClementResult {
  ClementResult({
    required this.flows,
    required this.probabilities,
    required this.requiredHead,
    required this.sourceFlow,
    required this.sourceRequiredHead,
    required this.u,
    required this.elasticity,
    required this.codes,
  });

  /// Design flow of every link of the tree, by link id.
  final Map<String, ClementFlow> flows;

  /// Probability of every hydrant being open, by hydrant id.
  final Map<String, double> probabilities;

  /// Piezometric head (m) the source must hold for each hydrant to get its
  /// minimum pressure with every section at its design flow: hydrant
  /// elevation + H_min + the losses along its path.
  final Map<String, double> requiredHead;

  /// Design flow leaving every source and the highest [requiredHead] of the
  /// hydrants it feeds, by source node id.
  final Map<String, double> sourceFlow;
  final Map<String, double> sourceRequiredHead;

  /// U(Pq) used.
  final double u;

  /// Elasticity of the network e_R = Q / (q_s·ΣA) (FAO 59 eq. 13; 0 when
  /// the areas or q_s are unknown).
  final double elasticity;

  /// `clement_unknown_node:<hydrant>`, `clement_no_probability:<hydrant>`,
  /// `clement_probability_over_one:<hydrant>` (p capped at 1),
  /// `clement_low_freedom:<hydrant>` (d below 1.5 times its duty q_s·A, where
  /// the demand model stops applying), `clement_high_freedom:<hydrant>` (d
  /// above 8 times the duty), `clement_unreachable:<hydrant>`,
  /// `clement_looped:<link>` (the formula needs a tree: the link is left
  /// out), `clement_prv_ignored:<link>`, `clement_pump_reversed:<link>`.
  final List<String> codes;

  /// The hydrant that needs the highest source head.
  String? get criticalHydrant => requiredHead.isEmpty ? null : requiredHead.entries.reduce((a, b) => b.value > a.value ? b : a).key;

  Map<String, dynamic> toJson() => {
    'flows': flows.values.map((f) => f.toJson()).toList(),
    'p': probabilities,
    'hreq': requiredHead,
    'qsrc': sourceFlow,
    'hsrc': sourceRequiredHead,
    'u': u,
    'eR': elasticity,
    'codes': codes,
  };
  static ClementResult fromJson(Map<String, dynamic> j) => ClementResult(
    flows: {for (final f in ((j['flows'] as List?) ?? []).map((e) => ClementFlow.fromJson(e as Map<String, dynamic>))) f.linkId: f},
    probabilities: _map(j['p']),
    requiredHead: _map(j['hreq']),
    sourceFlow: _map(j['qsrc']),
    sourceRequiredHead: _map(j['hsrc']),
    u: _d(j['u']),
    elasticity: _d(j['eR']),
    codes: ((j['codes'] as List?) ?? []).cast<String>(),
  );
}

/// Running sums of the hydrants downstream of a node.
class _Downstream {
  int count = 0;
  double sumD = 0, mean = 0, variance = 0, minD = double.infinity, maxD = 0;
  List<double> top = [];

  void add(double d, double p, int keep) {
    count++;
    sumD += d;
    mean += p * d;
    variance += p * (1 - p) * d * d;
    minD = math.min(minD, d);
    maxD = math.max(maxD, d);
    top = ([...top, d]..sort((a, b) => b.compareTo(a))).take(keep).toList();
  }

  void merge(_Downstream o, int keep) {
    count += o.count;
    sumD += o.sumD;
    mean += o.mean;
    variance += o.variance;
    minD = math.min(minD, o.minD);
    maxD = math.max(maxD, o.maxD);
    top = ([...top, ...o.top]..sort((a, b) => b.compareTo(a))).take(keep).toList();
  }
}

/// Design flows of the branched network [net] by Clément's first formula for
/// the [hydrants], oriented from its fixed-head nodes (the sources), with the
/// head each hydrant needs at the source (see the library comment). Loops are
/// reported and left out (the formula needs a tree).
ClementResult clementFlows(HydraulicNetwork net, List<Hydrant> hydrants, {ClementOptions options = const ClementOptions()}) {
  final codes = <String>[];
  final u = options.u ?? normalQuantile(options.operatingQuality.clamp(0.5, 1 - 1e-12));
  final r = options.utilisation > 0 ? math.min(options.utilisation, 1.0) : 1.0;
  final qs = options.specificContinuousFlow;
  final keep = math.max(0, options.minSimultaneous);
  final prob = <String, double>{};
  final atNode = <String, List<Hydrant>>{};
  var area = 0.0;
  for (final h in hydrants) {
    if (!net.nodes.containsKey(h.nodeId)) {
      codes.add('clement_unknown_node:${h.id}');
      continue;
    }
    atNode.putIfAbsent(h.nodeId, () => []).add(h);
    var p = h.probability ?? (h.hoursPerDay > 0 ? h.hoursPerDay / (24 * r) : (h.areaHa > 0 && qs > 0 && h.discharge > 0 ? qs * h.areaHa / (r * h.discharge) : -1.0));
    if (p < 0) {
      codes.add('clement_no_probability:${h.id}');
      p = 0;
    }
    if (p > 1) {
      codes.add('clement_probability_over_one:${h.id}');
      p = 1;
    }
    prob[h.id] = p;
    area += h.areaHa;
    if (h.areaHa > 0 && qs > 0) {
      final freedom = h.discharge / (qs * h.areaHa);
      if (freedom < 1.5) {
        codes.add('clement_low_freedom:${h.id}');
      } else if (freedom > 8) {
        codes.add('clement_high_freedom:${h.id}');
      }
    }
  }
  // spanning tree from the sources, breadth first
  final adj = <String, List<HLink>>{};
  for (final l in net.links) {
    if (l.kind == HLinkKind.closed) continue;
    adj.putIfAbsent(l.from, () => []).add(l);
    adj.putIfAbsent(l.to, () => []).add(l);
  }
  final parent = <String, HLink?>{};
  final root = <String, String>{};
  final children = <String, List<String>>{};
  final order = <String>[];
  for (final n in net.nodes.values) {
    if (n.kind != HNodeKind.reservoir) continue;
    parent[n.id] = null;
    root[n.id] = n.id;
    order.add(n.id);
  }
  for (var i = 0; i < order.length; i++) {
    final id = order[i];
    for (final l in adj[id] ?? const <HLink>[]) {
      final o = l.from == id ? l.to : l.from;
      if (parent.containsKey(o)) continue;
      parent[o] = l;
      root[o] = root[id]!;
      children.putIfAbsent(id, () => []).add(o);
      order.add(o);
    }
  }
  final treeLinks = {
    for (final l in parent.values)
      if (l != null) l.id,
  };
  for (final l in net.links) {
    if (l.kind != HLinkKind.closed && !treeLinks.contains(l.id) && parent.containsKey(l.from) && parent.containsKey(l.to)) codes.add('clement_looped:${l.id}');
  }
  for (final e in atNode.entries) {
    if (!parent.containsKey(e.key)) {
      for (final h in e.value) {
        codes.add('clement_unreachable:${h.id}');
      }
    }
  }

  (double, double, ClementRule) design(_Downstream s) {
    if (s.count == 0) return (0, 0, ClementRule.formula);
    final formula = s.mean + u * math.sqrt(math.max(0.0, s.variance));
    if (s.count <= keep) return (formula, s.sumD, ClementRule.allOpen);
    var q = formula;
    var rule = ClementRule.formula;
    if (options.roundToWholeHydrants && s.maxD > 0 && s.maxD - s.minD <= 1e-9 * s.maxD) q = (q / s.maxD - 1e-9).ceil() * s.maxD;
    final least = s.top.fold(0.0, (a, b) => a + b);
    if (least > q + 1e-15) {
      q = least;
      rule = ClementRule.minimumOpen;
    }
    if (q > s.sumD) {
      q = s.sumD;
      rule = ClementRule.allOpen;
    }
    return (formula, q, rule);
  }

  // hydrants downstream of every node, from the leaves up
  final down = <String, _Downstream>{};
  final flow = <String, double>{};
  final rule = <String, ClementRule>{};
  final formula = <String, double>{};
  for (final id in order.reversed) {
    final s = _Downstream();
    for (final h in atNode[id] ?? const <Hydrant>[]) {
      s.add(h.discharge, prob[h.id]!, keep);
    }
    var below = 0.0;
    for (final c in children[id] ?? const <String>[]) {
      s.merge(down[c]!, keep);
      below = math.max(below, flow[c]!);
    }
    down[id] = s;
    var (f, q, ru) = design(s);
    if (below > q + 1e-15) {
      q = below;
      ru = ClementRule.downstream;
    }
    formula[id] = f;
    flow[id] = q;
    rule[id] = ru;
  }
  // losses at the design flows and the head every hydrant needs at the source
  final flows = <String, ClementFlow>{};
  final cumLoss = <String, double>{};
  for (final id in order) {
    final l = parent[id];
    if (l == null) {
      cumLoss[id] = 0;
      continue;
    }
    final q = flow[id]!;
    final forward = l.to == id;
    double hl;
    switch (l.kind) {
      case HLinkKind.pipe:
        hl =
            frictionLoss(
              method: net.options.method,
              flow: q,
              diameter: l.diameter,
              length: l.length,
              c: l.hazenC,
              roughness: l.roughness,
              kinematicViscosity: net.options.kinematicViscosity,
              scobeyKs: l.scobeyKs,
              manningN: l.manningN,
            ) +
            (l.minorK > 0 ? minorLoss(k: l.minorK, flow: q, diameter: l.diameter) : 0);
      case HLinkKind.device:
        hl = (l.device?.loss(q) ?? 0).abs();
      case HLinkKind.pump:
        if (!forward) codes.add('clement_pump_reversed:${l.id}');
        hl = forward && l.pump != null ? -l.pump!.head(q) : 0;
      case HLinkKind.prv || HLinkKind.psv || HLinkKind.fcv:
        codes.add('clement_prv_ignored:${l.id}');
        hl = 0;
      case HLinkKind.closed:
        hl = 0;
    }
    final s = down[id]!;
    cumLoss[id] = cumLoss[l.from == id ? l.to : l.from]! + hl;
    flows[l.id] = ClementFlow(
      linkId: l.id,
      downstreamNode: id,
      hydrants: s.count,
      meanFlow: s.mean,
      stdFlow: math.sqrt(math.max(0.0, s.variance)),
      formulaFlow: formula[id]!,
      flow: q,
      rule: rule[id]!,
      headLoss: hl,
    );
  }
  final required = <String, double>{};
  final sourceRequired = <String, double>{};
  for (final e in atNode.entries) {
    final loss = cumLoss[e.key];
    if (loss == null) continue;
    final z = net.nodes[e.key]!.elevation;
    for (final h in e.value) {
      final need = z + h.minPressure + loss;
      required[h.id] = need;
      final src = root[e.key]!;
      sourceRequired[src] = math.max(sourceRequired[src] ?? -double.infinity, need);
    }
  }
  final sourceFlow = {
    for (final id in order)
      if (parent[id] == null) id: flow[id]!,
  };
  final total = sourceFlow.values.fold(0.0, (a, b) => a + b);
  return ClementResult(
    flows: flows,
    probabilities: prob,
    requiredHead: required,
    sourceFlow: sourceFlow,
    sourceRequiredHead: sourceRequired,
    u: u,
    elasticity: qs > 0 && area > 0 ? total / (qs * area) : 0,
    codes: codes,
  );
}

/// Parameters of [checkRandomConfigurations].
class RandomCheckOptions {
  const RandomCheckOptions({this.configurations = 0, this.seed = 1, this.upstreamDischarge = 0, this.tolerance = 0, this.flowLimited = false});

  /// Configurations C (0 = the larger of 200 and R + 1; FAO 59 asks for more
  /// configurations than hydrants when there are fewer than 200).
  final int configurations;

  /// Seed of the [Mrg32k3a] draws.
  final int seed;

  /// Discharge of every configuration at the upstream end (m³/s): the random
  /// generation model of FAO 59. 0 = every hydrant open independently with
  /// its probability.
  final double upstreamDischarge;

  /// Accepted |Q_conf − Q| (m³/s); 0 = the smallest hydrant discharge.
  final double tolerance;

  /// Hydrants below H_min deliver like an orifice (else the nominal
  /// discharge, as FAO 59 assumes).
  final bool flowLimited;
}

/// Performance of one hydrant over the configurations.
class HydrantReliability {
  HydrantReliability({
    required this.hydrantId,
    required this.nodeId,
    required this.open,
    required this.satisfied,
    required this.minRelative,
    required this.p10Relative,
    required this.meanRelative,
    required this.maxRelative,
    required this.meanDeficit,
    required this.maxDeficit,
    required this.deliveredShare,
  });
  final String hydrantId;
  final String nodeId;

  /// Configurations with the hydrant open, and those in which it got H_min.
  final int open;
  final int satisfied;

  /// Relative pressure deficit (H − H_min)/H_min over the configurations with
  /// the hydrant open: lowest, 10th percentile (the value exceeded in 90 % of
  /// them), mean and highest (0 when never open).
  final double minRelative;
  final double p10Relative;
  final double meanRelative;
  final double maxRelative;

  /// Pressure deficit max(0, H_min − H) (m): mean over the configurations
  /// with the hydrant open, and the largest.
  final double meanDeficit;
  final double maxDeficit;

  /// Mean delivered share of the nominal discharge (1 unless flow-limited).
  final double deliveredShare;

  /// Reliability α_j (FAO 59 eq. 54); 1 when never open.
  double get reliability => open > 0 ? satisfied / open : 1;

  Map<String, dynamic> toJson() => {
    'id': hydrantId,
    'node': nodeId,
    'open': open,
    'ok': satisfied,
    'rmin': minRelative,
    'r10': p10Relative,
    'rmean': meanRelative,
    'rmax': maxRelative,
    'dmean': meanDeficit,
    'dmax': maxDeficit,
    'share': deliveredShare,
  };
  static HydrantReliability fromJson(Map<String, dynamic> j) => HydrantReliability(
    hydrantId: j['id'] as String,
    nodeId: j['node'] as String? ?? '',
    open: (j['open'] as num?)?.toInt() ?? 0,
    satisfied: (j['ok'] as num?)?.toInt() ?? 0,
    minRelative: _d(j['rmin']),
    p10Relative: _d(j['r10']),
    meanRelative: _d(j['rmean']),
    maxRelative: _d(j['rmax']),
    meanDeficit: _d(j['dmean']),
    maxDeficit: _d(j['dmax']),
    deliveredShare: _d(j['share'], 1),
  );
}

/// Outcome of [checkRandomConfigurations].
class RandomCheckResult {
  RandomCheckResult({
    required this.hydrants,
    required this.configurations,
    required this.satisfiedConfigurations,
    required this.meanUnsatisfied,
    required this.p90Unsatisfied,
    required this.maxUnsatisfied,
    required this.meanOpen,
    required this.meanDischarge,
    required this.notConverged,
    required this.codes,
  });

  /// One entry per hydrant, in the order given.
  final List<HydrantReliability> hydrants;
  final int configurations;

  /// Configurations in which every open hydrant got H_min.
  final int satisfiedConfigurations;

  /// Share of unsatisfied hydrants among the open ones per configuration
  /// (0..1): mean, the value exceeded in 10 % of the configurations, highest.
  final double meanUnsatisfied;
  final double p90Unsatisfied;
  final double maxUnsatisfied;

  /// Mean number of hydrants open and their nominal discharge (m³/s).
  final double meanOpen;
  final double meanDischarge;

  /// Solutions that did not converge (their pressures still counted).
  final int notConverged;

  /// `random_unknown_node:<hydrant>`, `random_no_hydrants`,
  /// `random_discharge_above_total` (Q above every hydrant open),
  /// `random_not_converged`.
  final List<String> codes;

  double get satisfiedShare => configurations > 0 ? satisfiedConfigurations / configurations : 0;

  Map<String, dynamic> toJson() => {
    'hyd': hydrants.map((h) => h.toJson()).toList(),
    'c': configurations,
    'ok': satisfiedConfigurations,
    'puh': meanUnsatisfied,
    'puh90': p90Unsatisfied,
    'puhMax': maxUnsatisfied,
    'open': meanOpen,
    'q': meanDischarge,
    'nc': notConverged,
    'codes': codes,
  };
  static RandomCheckResult fromJson(Map<String, dynamic> j) => RandomCheckResult(
    hydrants: ((j['hyd'] as List?) ?? []).map((h) => HydrantReliability.fromJson(h as Map<String, dynamic>)).toList(),
    configurations: (j['c'] as num?)?.toInt() ?? 0,
    satisfiedConfigurations: (j['ok'] as num?)?.toInt() ?? 0,
    meanUnsatisfied: _d(j['puh']),
    p90Unsatisfied: _d(j['puh90']),
    maxUnsatisfied: _d(j['puhMax']),
    meanOpen: _d(j['open']),
    meanDischarge: _d(j['q']),
    notConverged: (j['nc'] as num?)?.toInt() ?? 0,
    codes: ((j['codes'] as List?) ?? []).cast<String>(),
  );
}

/// Random-configuration check of [net] with its [hydrants] (see the library
/// comment). Independent draws use [probabilities] (by hydrant id, e.g.
/// [ClementResult.probabilities]) or each hydrant's own probability. The
/// sources keep the heads of [net] (the set-point head); [net] is not
/// changed.
RandomCheckResult checkRandomConfigurations(HydraulicNetwork net, List<Hydrant> hydrants, {RandomCheckOptions options = const RandomCheckOptions(), Map<String, double>? probabilities}) {
  final codes = <String>[];
  final hyd = <Hydrant>[];
  for (final h in hydrants) {
    if (net.nodes.containsKey(h.nodeId) && h.discharge > 0) {
      hyd.add(h);
    } else {
      codes.add('random_unknown_node:${h.id}');
    }
  }
  final n = hyd.length;
  if (n == 0) {
    codes.add('random_no_hydrants');
    return RandomCheckResult(
      hydrants: const [],
      configurations: 0,
      satisfiedConfigurations: 0,
      meanUnsatisfied: 0,
      p90Unsatisfied: 0,
      maxUnsatisfied: 0,
      meanOpen: 0,
      meanDischarge: 0,
      notConverged: 0,
      codes: codes,
    );
  }
  final count = options.configurations > 0 ? options.configurations : math.max(200, n + 1);
  final rng = Mrg32k3a(options.seed);
  final work = copyNetwork(net);
  final baseDemand = {for (final h in hyd) h.nodeId: work.nodes[h.nodeId]!.demand};
  final q0 = options.upstreamDischarge;
  final eps = options.tolerance > 0 ? options.tolerance : hyd.map((h) => h.discharge).reduce(math.min);
  final total = hyd.fold(0.0, (s, h) => s + h.discharge);
  if (q0 > 0 && q0 > total + eps) codes.add('random_discharge_above_total');
  final p = [for (final h in hyd) (probabilities?[h.id] ?? h.probability ?? 0).clamp(0.0, 1.0)];
  final opened = List<int>.filled(n, 0);
  final ok = List<int>.filled(n, 0);
  final rel = List<List<double>>.generate(n, (_) => []);
  final deficitSum = List<double>.filled(n, 0);
  final deficitMax = List<double>.filled(n, 0);
  final shareSum = List<double>.filled(n, 0);
  final puh = <double>[];
  var satisfiedConfigs = 0, notConverged = 0;
  var openSum = 0.0, dischargeSum = 0.0;
  final perm = List<int>.generate(n, (i) => i);
  for (var c = 0; c < count; c++) {
    final open = <int>[];
    if (q0 > 0) {
      // Fisher-Yates shuffle, then hydrants in that order until the discharge
      for (var i = n - 1; i > 0; i--) {
        final j = rng.nextInt(i + 1);
        final t = perm[i];
        perm[i] = perm[j];
        perm[j] = t;
      }
      var q = 0.0;
      for (final i in perm) {
        if (open.isNotEmpty && (q0 - q).abs() < eps) break;
        if (q + hyd[i].discharge - q0 < eps) {
          open.add(i);
          q += hyd[i].discharge;
        }
      }
    } else {
      for (var i = 0; i < n; i++) {
        if (rng.nextDouble() < p[i]) open.add(i);
      }
    }
    open.sort();
    for (final e in baseDemand.entries) {
      work.nodes[e.key]!.demand = e.value;
    }
    NetworkResult res;
    Map<String, double>? delivered;
    if (options.flowLimited) {
      final pd = solvePressureDriven(work, [for (final i in open) PressureDemand(nodeId: hyd[i].nodeId, demand: hyd[i].discharge, requiredPressure: hyd[i].minPressure)]);
      res = pd.result;
      delivered = {for (final e in pd.delivered.entries) e.key: pd.demand[e.key]! > 0 ? e.value / pd.demand[e.key]! : 1.0};
    } else {
      for (final i in open) {
        work.nodes[hyd[i].nodeId]!.demand += hyd[i].discharge;
      }
      res = work.solve();
    }
    if (!res.converged) notConverged++;
    var unsatisfied = 0;
    for (final i in open) {
      final h = hyd[i];
      final pr = res.nodes[h.nodeId]?.pressure ?? 0;
      opened[i]++;
      if (pr >= h.minPressure - 1e-6) {
        ok[i]++;
      } else {
        unsatisfied++;
      }
      rel[i].add(h.minPressure > 0 ? (pr - h.minPressure) / h.minPressure : 0);
      final deficit = math.max(0.0, h.minPressure - pr);
      deficitSum[i] += deficit;
      deficitMax[i] = math.max(deficitMax[i], deficit);
      shareSum[i] += delivered == null ? 1 : (delivered[h.nodeId] ?? 1);
      dischargeSum += h.discharge;
    }
    openSum += open.length;
    puh.add(open.isEmpty ? 0 : unsatisfied / open.length);
    if (unsatisfied == 0) satisfiedConfigs++;
  }
  for (final e in baseDemand.entries) {
    work.nodes[e.key]!.demand = e.value;
  }
  if (notConverged > 0) codes.add('random_not_converged');
  final out = <HydrantReliability>[];
  for (var i = 0; i < n; i++) {
    final v = rel[i]..sort();
    final k = opened[i];
    out.add(
      HydrantReliability(
        hydrantId: hyd[i].id,
        nodeId: hyd[i].nodeId,
        open: k,
        satisfied: ok[i],
        minRelative: v.isEmpty ? 0 : v.first,
        p10Relative: percentile(v, 0.10),
        meanRelative: v.isEmpty ? 0 : v.fold(0.0, (a, b) => a + b) / v.length,
        maxRelative: v.isEmpty ? 0 : v.last,
        meanDeficit: k > 0 ? deficitSum[i] / k : 0,
        maxDeficit: deficitMax[i],
        deliveredShare: k > 0 ? shareSum[i] / k : 1,
      ),
    );
  }
  puh.sort();
  return RandomCheckResult(
    hydrants: out,
    configurations: count,
    satisfiedConfigurations: satisfiedConfigs,
    meanUnsatisfied: puh.fold(0.0, (a, b) => a + b) / puh.length,
    p90Unsatisfied: percentile(puh, 0.90),
    maxUnsatisfied: puh.last,
    meanOpen: openSum / count,
    meanDischarge: dischargeSum / count,
    notConverged: notConverged,
    codes: codes,
  );
}

/// Quantile [q] (0..1) of the ascending [sorted] values, linear between
/// order statistics (Hyndman & Fan 1996, definition 7); 0 when empty.
double percentile(List<double> sorted, double q) {
  if (sorted.isEmpty) return 0;
  final h = (sorted.length - 1) * q.clamp(0.0, 1.0);
  final lo = h.floor();
  final hi = math.min(lo + 1, sorted.length - 1);
  return sorted[lo] + (h - lo) * (sorted[hi] - sorted[lo]);
}

double _d(Object? v, [double def = 0]) => (v as num?)?.toDouble() ?? def;

Map<String, double> _map(Object? v) => {for (final e in ((v as Map?) ?? const {}).entries) e.key as String: (e.value as num).toDouble()};
