/// Steady-state pipe-network solver based on the Global Gradient Algorithm
/// (Todini & Pilati 1988), as implemented in EPANET, extended with
/// pressure-dependent emitters, pumps, PRVs and check valves.
///
/// Units are SI throughout: flow m³/s, head m, elevation m, diameter m.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'emitter.dart';
import 'friction.dart';
import 'minor_losses.dart';
import 'pump.dart';
import 'sparse_solver.dart';

enum HNodeKind { junction, reservoir }

class HNode {
  HNode({
    required this.id,
    this.kind = HNodeKind.junction,
    this.elevation = 0,
    this.demand = 0,
    this.fixedHead,
    this.emitter,
    this.emitterCount = 1,
    this.emitterOffset = 0,
    this.label = '',
    this.tag,
  });

  final String id;
  HNodeKind kind;
  double elevation;

  /// Fixed demand (m³/s), positive = outflow.
  double demand;

  /// Total head (m) for reservoirs.
  double? fixedHead;

  /// Pressure-dependent outflow q = k·p^x per emitter (p = pressure head).
  EmitterCurve? emitter;
  int emitterCount;

  /// Height of the emitter above the node elevation (riser), metres.
  double emitterOffset;
  String label;
  Object? tag;
}

/// Link kinds: [prv] reduces the downstream pressure to its setting, [psv]
/// sustains the upstream pressure at its setting, [fcv] limits the flow to
/// [HLink.fcvFlow] (EPANET's valve models).
enum HLinkKind { pipe, pump, prv, device, closed, psv, fcv }

enum LinkStatus { open, closed, active }

class HLink {
  HLink({
    required this.id,
    required this.from,
    required this.to,
    this.kind = HLinkKind.pipe,
    this.diameter = 0.05,
    this.length = 1,
    this.hazenC = 150,
    this.roughness = 1.5e-6,
    this.minorK = 0,
    this.checkValve = false,
    this.pump,
    this.device,
    this.prvSetting = 0,
    this.label = '',
    this.tag,
    this.scobeyKs = 0.40,
    this.manningN = 0.010,
    this.fcvFlow = 0,
  });

  final String id;
  final String from;
  final String to;
  HLinkKind kind;
  double diameter;
  double length;
  double hazenC;
  double roughness;

  /// Coefficients of the Scobey and Manning laws.
  double scobeyKs;
  double manningN;
  double minorK;
  bool checkValve;
  PumpCurve? pump;
  DeviceLossCurve? device;

  /// Pressure-head setting (m) of a PRV (above the downstream node) or of a
  /// PSV (above the upstream node).
  double prvSetting;

  /// Flow setting of an FCV (m³/s).
  double fcvFlow;
  String label;
  Object? tag;

  LinkStatus status = LinkStatus.open;
}

class NetworkOptions {
  const NetworkOptions({
    this.method = FrictionMethod.hazenWilliams,
    this.kinematicViscosity = 1.004e-6,
    this.maxIterations = 200,
    this.flowTolerance = 1e-5,
    this.absoluteFlowTolerance = 1e-9,
    this.headTolerance = 1e-4,
  });
  final FrictionMethod method;
  final double kinematicViscosity;
  final int maxIterations;

  /// Relative flow change Σ|ΔQ|/Σ|Q| threshold.
  final double flowTolerance;

  /// Absolute Σ|ΔQ| threshold (m³/s) that also counts as converged, for
  /// networks carrying (almost) no flow, where the relative measure is noise.
  final double absoluteFlowTolerance;

  /// Largest error (m) of the energy equation |hᵢ − hⱼ − h(Q)| over the
  /// links and emitters once the flows have settled (EPANET 2.2's head
  /// error); 0 = the flow test alone.
  final double headTolerance;
}

class NodeResult {
  NodeResult({required this.head, required this.pressure, required this.demand, required this.emitterFlow});
  final double head;
  final double pressure;
  final double demand;

  /// Total emitter outflow at the node (m³/s).
  final double emitterFlow;
}

class LinkResult {
  LinkResult({required this.flow, required this.velocity, required this.headLoss, required this.status, this.pumpHead = 0});
  final double flow;
  final double velocity;
  final double headLoss;
  final LinkStatus status;
  final double pumpHead;
}

class NetworkResult {
  NetworkResult({required this.converged, required this.iterations, required this.nodes, required this.links, required this.warnings, required this.relativeFlowError});
  final bool converged;
  final int iterations;
  final Map<String, NodeResult> nodes;
  final Map<String, LinkResult> links;
  final List<String> warnings;
  final double relativeFlowError;
}

class HydraulicNetwork {
  HydraulicNetwork({this.options = const NetworkOptions()});

  final NetworkOptions options;
  final Map<String, HNode> nodes = {};
  final List<HLink> links = [];

  HNode addNode(HNode n) {
    nodes[n.id] = n;
    return n;
  }

  HLink addLink(HLink l) {
    links.add(l);
    return l;
  }

  static const double _closedResistance = 1e8;
  static const double _qMin = 1e-7;

  /// Smallest head loss gradient of a device or an open valve (EPANET's
  /// RQtol): with nearly no loss at nearly no flow (an air valve on a line
  /// at rest) a smaller one made the system too ill-conditioned to solve
  /// next to the 1/10⁸ conductance of a closed pump.
  static const double _minGradient = 1e-7;

  NetworkResult solve({Map<String, double>? initialFlows}) {
    final warnings = <String>[];
    final nodeList = nodes.values.toList();
    final nodeCount = nodeList.length;
    // Nodes and links by position: the iterations run on typed arrays
    final at = <String, int>{for (var i = 0; i < nodeCount; i++) nodeList[i].id: i};
    final unknown = Int32List(nodeCount);
    var unknownCount = 0;
    for (var i = 0; i < nodeCount; i++) {
      unknown[i] = nodeList[i].kind == HNodeKind.junction ? unknownCount++ : -1;
    }
    if (nodeList.where((n) => n.kind == HNodeKind.reservoir).isEmpty) {
      warnings.add('no_fixed_head_node');
    }
    final heads = Float64List(nodeCount);
    for (var i = 0; i < nodeCount; i++) {
      final n = nodeList[i];
      heads[i] = n.kind == HNodeKind.reservoir ? (n.fixedHead ?? n.elevation) : n.elevation + 10;
    }
    final linkCount = links.length;
    final fromNode = Int32List(linkCount), toNode = Int32List(linkCount);
    for (var k = 0; k < linkCount; k++) {
      fromNode[k] = at[links[k].from]!;
      toNode[k] = at[links[k].to]!;
    }

    // Initial flows: 1 m/s-equivalent in pipes, positive for pumps.
    final q = Float64List(linkCount);
    for (var k = 0; k < linkCount; k++) {
      final l = links[k];
      final init = initialFlows?[l.id];
      if (init != null) {
        q[k] = init;
      } else {
        switch (l.kind) {
          case HLinkKind.pipe:
          case HLinkKind.device:
          case HLinkKind.prv:
          case HLinkKind.psv:
            q[k] = flowForVelocity(velocity: 1.0, diameter: l.diameter);
          case HLinkKind.fcv:
            q[k] = l.fcvFlow;
          case HLinkKind.pump:
            q[k] = l.pump != null ? math.max(l.pump!.runoutFlow.isFinite ? l.pump!.runoutFlow / 2 : 0.01, 1e-4) : 0.01;
          case HLinkKind.closed:
            q[k] = 0;
        }
      }
      if (_isValve(l)) l.status = LinkStatus.active;
      if (l.kind == HLinkKind.closed) l.status = LinkStatus.closed;
      if (l.kind != HLinkKind.closed && !_isValve(l)) l.status = LinkStatus.open;
    }

    // Emitters are fictitious links to a reservoir at the emitter elevation
    // whose flow is a state variable, as in EPANET: in flow form the law
    // p = (q/k)^(1/x) is convex, so the Newton step behaves like a pipe's;
    // linearising q(p) instead overshoots (dq/dp is infinite at p = 0) and
    // made emitters near zero pressure flip open/closed without end.
    // They are one-way: closed below their elevation, no backflow.
    final emitterFlow = Float64List(nodeCount);
    final emitterOpen = Uint8List(nodeCount);
    for (var i = 0; i < nodeCount; i++) {
      final n = nodeList[i];
      final em = n.emitter;
      if (em == null || n.emitterCount <= 0 || n.kind != HNodeKind.junction) continue;
      final p0 = heads[i] - n.elevation - n.emitterOffset;
      emitterOpen[i] = p0 > 0 ? 1 : 0;
      emitterFlow[i] = p0 > 0 ? _emitterLaw(em, n.emitterCount, p0) : 0;
    }
    final eGrad = Float64List(nodeCount);
    final eLoss = Float64List(nodeCount);

    // Parts with a demand that no fixed head reaches through links that
    // can ever open (a closed link, a pump without a curve, an FCV set to no
    // flow): the demand cannot be met. Solved with the rest they drew it
    // through the 10⁻⁸ conductance of the closed links, the nodes at
    // −200 000 m with the solution converged; they rest empty instead, at
    // zero pressure, their demand left out (`demand_disconnected:<node>`).
    final cutOff = warnings.contains('no_fixed_head_node') ? null : _cutOffParts(nodeList, fromNode, toNode);
    if (cutOff != null) {
      for (var i = 0; i < nodeCount; i++) {
        if (cutOff[i] == 0) continue;
        emitterOpen[i] = 0;
        emitterFlow[i] = 0;
      }
    }

    // What the iterations do not change: the friction exponent, and the
    // resistance (unless Darcy–Weisbach) and minor loss coefficient of each pipe.
    final exponent = switch (options.method) {
      FrictionMethod.hazenWilliams => 1.852,
      FrictionMethod.scobey => 1.9,
      FrictionMethod.darcyWeisbach || FrictionMethod.manning => 2.0,
    };
    final darcy = options.method == FrictionMethod.darcyWeisbach;
    final resistance = Float64List(linkCount), minor = Float64List(linkCount);
    for (var k = 0; k < linkCount; k++) {
      final l = links[k];
      if (l.kind != HLinkKind.pipe) continue;
      if (!darcy) resistance[k] = _pipeResistance(l, 0);
      minor[k] = l.minorK > 0 ? minorLossFlowCoefficient(k: l.minorK, diameter: l.diameter) : 0.0;
    }
    // Links meeting at each node, for the continuity of active PRVs and PSVs.
    final incident = links.any((l) => l.kind == HLinkKind.prv || l.kind == HLinkKind.psv) ? _incidence(nodeCount, fromNode, toNode) : null;

    var converged = false;
    var iter = 0;
    var refine = 0;
    var relErr = double.infinity;
    var lastErr = double.infinity;
    var damping = 1.0;

    // Working arrays per link.
    final g = Float64List(linkCount)..fillRange(0, linkCount, 1);
    final y = Float64List(linkCount);

    // Nodes at rest behind closed links and their level.
    final resting = Uint8List(nodeCount);
    final restLevel = Float64List(nodeCount);

    // The elimination of the system, made again only when the links that
    // tie two unknowns change (a part comes to rest, a valve turns active).
    EliminationPlan? plan;
    final tied = Uint8List(linkCount);
    final pairOf = Int32List(linkCount);

    for (iter = 1; iter <= options.maxIterations; iter++) {
      // --- link coefficients ---
      for (var k = 0; k < linkCount; k++) {
        final l = links[k];
        final qk = q[k];
        double gk, yk;
        switch (l.kind) {
          case HLinkKind.closed:
            gk = _closedResistance;
            yk = _closedResistance * qk;
          case HLinkKind.pipe:
            if (l.status == LinkStatus.closed) {
              gk = _closedResistance;
              yk = _closedResistance * qk;
            } else {
              final r = darcy ? _pipeResistance(l, qk) : resistance[k];
              final n = exponent;
              final qa = math.max(qk.abs(), _qMin);
              final m = minor[k];
              var gg = n * r * math.pow(qa, n - 1) + 2 * m * qa;
              if (darcy && qa > _qMin * 10) {
                // add ∂r/∂Q·|Q|^n numerically
                final r2 = _pipeResistance(l, qa * 1.01);
                final dr = (r2 - r) / (qa * 0.01);
                gg += dr * math.pow(qa, n);
              }
              final h = r * math.pow(qa, n) + m * qa * qa;
              gk = math.max(gg, 1e-12);
              yk = qk < 0 ? -h : h;
            }
          case HLinkKind.device:
            final d = l.device ?? const DeviceLossCurve(k: 0);
            if (l.status == LinkStatus.closed) {
              gk = _closedResistance;
              yk = _closedResistance * qk;
            } else {
              gk = math.max(d.gradient(qk), _minGradient);
              yk = d.loss(qk);
            }
          case HLinkKind.prv:
          case HLinkKind.psv:
          case HLinkKind.fcv:
            final d = l.device;
            if (l.status == LinkStatus.closed) {
              gk = _closedResistance;
              yk = _closedResistance * qk;
            } else if (l.status == LinkStatus.open) {
              gk = d != null ? math.max(d.gradient(qk), _minGradient) : 1e-2;
              yk = d != null ? d.loss(qk) : 1e-2 * qk;
            } else {
              gk = double.infinity; // active: handled specially
              yk = 0;
            }
          case HLinkKind.pump:
            final p = l.pump;
            if (p == null || l.status == LinkStatus.closed) {
              gk = _closedResistance;
              yk = _closedResistance * qk;
            } else {
              // open: the curve at |Q| (EPANET); a pump that cannot deliver
              // the head is closed by the status check below. Left of the
              // top of a curve that rises first, the top: the pump runs on
              // the falling part (a rising gradient made the system singular)
              final qa = math.max(qk.abs(), _qMin);
              final runout = p.runoutFlow;
              if (runout.isFinite && qa > runout) {
                final gr = math.max(-p.gradient(runout), 1e-6);
                gk = gr;
                yk = -p.head(runout) + (qa - runout) * gr;
              } else {
                final qe = math.max(qa, p.peakFlow);
                gk = math.max(-p.gradient(qe), 1e-6);
                yk = -p.head(qe);
              }
            }
        }
        g[k] = gk;
        y[k] = yk;
      }

      // parts at rest behind closed links take their level as known heads
      if (_restingParts(nodeList, fromNode, toNode, heads, emitterOpen, resting, restLevel, cutOff)) {
        for (var i = 0; i < nodeCount; i++) {
          if (resting[i] == 1) heads[i] = restLevel[i];
        }
      }

      // --- sparsity pattern ---
      var samePattern = plan != null;
      for (var k = 0; k < linkCount; k++) {
        final l = links[k];
        final iFrom = resting[fromNode[k]] == 1 ? -1 : unknown[fromNode[k]];
        final iTo = resting[toNode[k]] == 1 ? -1 : unknown[toNode[k]];
        final fixesHead = (l.kind == HLinkKind.prv || l.kind == HLinkKind.psv) && l.status == LinkStatus.active;
        final t = iFrom >= 0 && iTo >= 0 && iFrom != iTo && !fixesHead ? 1 : 0;
        if (t != tied[k]) {
          tied[k] = t;
          samePattern = false;
        }
      }
      if (!samePattern) {
        final from = <int>[], to = <int>[];
        for (var k = 0; k < linkCount; k++) {
          if (tied[k] == 0) continue;
          pairOf[k] = from.length;
          from.add(unknown[fromNode[k]]);
          to.add(unknown[toNode[k]]);
        }
        plan = _planFor(unknownCount, from, to);
      }
      final sys = plan!;

      // --- assemble ---
      final a = Float64List(sys.slotCount);
      final rhs = Float64List(unknownCount);
      void addOff(int k, int iFrom, int iTo, double v) {
        if (iFrom == iTo) {
          a[iFrom] += v;
        } else {
          a[sys.pairSlotFT[pairOf[k]]] += v;
          a[sys.pairSlotTF[pairOf[k]]] += v;
        }
      }

      for (var ni = 0; ni < nodeCount; ni++) {
        final i = unknown[ni];
        if (i < 0) continue;
        if (resting[ni] == 1) {
          a[i] += 1;
          rhs[i] += restLevel[ni];
          continue;
        }
        final n = nodeList[ni];
        var demand = n.demand;
        final em = n.emitter;
        if (em != null && n.emitterCount > 0) {
          final zEm = n.elevation + n.emitterOffset;
          if (emitterOpen[ni] != 1) {
            // Closed: no outflow and no backflow into the node. A negligible
            // conductance keeps the equation regular; the emitter reopens
            // once the pressure turns positive.
            const ge = 1e-12;
            a[i] += ge;
            rhs[i] += ge * zEm;
          } else {
            final qe = emitterFlow[ni];
            final (h, dh) = _emitterLoss(em, n.emitterCount, qe);
            eLoss[ni] = h;
            eGrad[ni] = dh;
            a[i] += 1 / dh;
            rhs[i] += -qe + (h + zEm) / dh;
          }
        }
        rhs[i] -= demand;
      }
      for (var k = 0; k < linkCount; k++) {
        final l = links[k];
        final iFrom = resting[fromNode[k]] == 1 ? -1 : unknown[fromNode[k]];
        final iTo = resting[toNode[k]] == 1 ? -1 : unknown[toNode[k]];
        if (l.kind == HLinkKind.prv && l.status == LinkStatus.active) {
          // downstream node fixed to setting; flow appears as demand upstream
          final hSet = nodes[l.to]!.elevation + l.prvSetting;
          if (iTo >= 0) {
            a[iTo] += 1e8;
            rhs[iTo] += 1e8 * hSet;
            // the valve flow enters node `to` as an inflow: include current q
            rhs[iTo] += q[k];
          }
          if (iFrom >= 0) rhs[iFrom] += -q[k];
          continue;
        }
        if (l.kind == HLinkKind.psv && l.status == LinkStatus.active) {
          // upstream node fixed to setting; flow leaves it towards `to`
          final hSet = nodes[l.from]!.elevation + l.prvSetting;
          if (iFrom >= 0) {
            a[iFrom] += 1e8;
            rhs[iFrom] += 1e8 * hSet;
            rhs[iFrom] += -q[k];
          }
          if (iTo >= 0) rhs[iTo] += q[k];
          continue;
        }
        if (l.kind == HLinkKind.fcv && l.status == LinkStatus.active) {
          // fixed flow from `from` to `to`, with a vanishing conductance
          // between them so neither side is left without a head (EPANET)
          const tiny = 1e-8;
          if (iFrom >= 0) {
            a[iFrom] += tiny;
            rhs[iFrom] += -l.fcvFlow;
            if (iTo < 0) rhs[iFrom] += heads[toNode[k]] * tiny;
          }
          if (iTo >= 0) {
            a[iTo] += tiny;
            rhs[iTo] += l.fcvFlow;
            if (iFrom < 0) rhs[iTo] += heads[fromNode[k]] * tiny;
          }
          if (iFrom >= 0 && iTo >= 0) addOff(k, iFrom, iTo, -tiny);
          continue;
        }
        final inv = 1 / g[k];
        final qk = q[k];
        final yk = y[k];
        if (iFrom >= 0) {
          a[iFrom] += inv;
          rhs[iFrom] += -qk + yk * inv;
          if (iTo < 0) rhs[iFrom] += heads[toNode[k]] * inv;
        }
        if (iTo >= 0) {
          a[iTo] += inv;
          rhs[iTo] += qk - yk * inv;
          if (iFrom < 0) rhs[iTo] += heads[fromNode[k]] * inv;
        }
        if (iFrom >= 0 && iTo >= 0) addOff(k, iFrom, iTo, -inv);
      }

      final x = sys.solve(a, rhs);
      for (var ni = 0; ni < nodeCount; ni++) {
        final i = unknown[ni];
        if (i >= 0) {
          final hNew = x[i];
          if (hNew.isFinite) heads[ni] = hNew;
        }
      }

      // --- update flows ---
      var sumDq = 0.0, sumQ = 0.0;
      for (var k = 0; k < linkCount; k++) {
        final l = links[k];
        final dh = heads[fromNode[k]] - heads[toNode[k]];
        double qNew;
        if (l.kind == HLinkKind.prv && l.status == LinkStatus.active) {
          // continuity at downstream node
          final down = toNode[k];
          var net = nodes[l.to]!.demand + emitterFlow[down];
          for (var t = incident![down]; t < incident[down + 1]; t++) {
            final j = incident[t];
            if (j == k) continue;
            if (fromNode[j] == down) net += q[j];
            if (toNode[j] == down) net -= q[j];
          }
          qNew = net;
        } else if (l.kind == HLinkKind.psv && l.status == LinkStatus.active) {
          // continuity at the upstream node
          final up = fromNode[k];
          var net = -nodes[l.from]!.demand - emitterFlow[up];
          for (var t = incident![up]; t < incident[up + 1]; t++) {
            final j = incident[t];
            if (j == k) continue;
            if (toNode[j] == up) net += q[j];
            if (fromNode[j] == up) net -= q[j];
          }
          qNew = net;
        } else if (l.kind == HLinkKind.fcv && l.status == LinkStatus.active) {
          qNew = l.fcvFlow;
        } else if (resting[fromNode[k]] == 1 && resting[toNode[k]] == 1) {
          qNew = 0;
        } else {
          qNew = q[k] - damping * (y[k] - dh) / g[k];
        }
        if (!qNew.isFinite) qNew = 0;
        sumDq += (qNew - q[k]).abs();
        sumQ += qNew.abs();
        q[k] = qNew;
      }
      var emitterStatusChanged = false;
      for (var ni = 0; ni < nodeCount; ni++) {
        final n = nodeList[ni];
        final em = n.emitter;
        if (em == null || n.emitterCount <= 0 || unknown[ni] < 0) continue;
        final zEm = n.elevation + n.emitterOffset;
        final p = heads[ni] - zEm;
        if (emitterOpen[ni] == 1) {
          final qe = emitterFlow[ni];
          var qNew = qe - damping * (eLoss[ni] - p) / eGrad[ni];
          if (!qNew.isFinite) qNew = 0;
          // Newton overshoots a steep law from below (pressure compensating
          // x = 0.02 is h ∝ q^50): never far above what the law gives at the
          // current pressure. Near the solution the plain step goes on (a
          // tight cap there alternated with it and stalled the convergence).
          if (p > 0) {
            final law = _emitterLaw(em, n.emitterCount, p);
            if (qNew > 1.1 * law) qNew = law;
          }
          if (qNew <= 0) {
            // would draw water back in: one-way, so it closes
            qNew = 0;
            emitterOpen[ni] = 0;
            emitterStatusChanged = true;
          }
          sumDq += (qNew - qe).abs();
          sumQ += qNew.abs();
          emitterFlow[ni] = qNew;
        }
      }
      relErr = sumQ > 0 ? sumDq / sumQ : 0;
      if (sumDq < options.absoluteFlowTolerance) relErr = 0;

      // --- status checks ---
      // As in EPANET: statuses change when the flows have converged, and in
      // the first iterations every other one; checking them at every
      // iteration let one-way devices near their switching point flip
      // open/closed without end.
      final flowsConverged = relErr < options.flowTolerance && iter > 1;
      var statusChanged = emitterStatusChanged;
      if (flowsConverged || (iter <= _maxStatusCheck && iter % _statusCheckFrequency == 0)) {
        for (var ni = 0; ni < nodeCount; ni++) {
          final n = nodeList[ni];
          final em = n.emitter;
          if (em == null || n.emitterCount <= 0 || unknown[ni] < 0 || emitterOpen[ni] == 1) continue;
          final p = heads[ni] - n.elevation - n.emitterOffset;
          if (p > 1e-4) {
            emitterOpen[ni] = 1;
            emitterFlow[ni] = _emitterLaw(em, n.emitterCount, p);
            statusChanged = true;
          }
        }
        statusChanged = _checkLinkStatus(heads, fromNode, toNode, q, prvs: flowsConverged) || statusChanged;
      }
      // the flows have settled: the energy equation must hold too, within
      // headTolerance on every link and emitter (the head error test of
      // EPANET 2.2). The flow test alone, dominated by the large flows, let
      // drippers of 4·10⁻⁷ m³/s end centimetres off; a few more Newton steps
      // settle them (at most [_maxHeadRefinements])
      if (flowsConverged && !statusChanged) {
        final tol = options.headTolerance;
        if (!(tol > 0) || refine >= _maxHeadRefinements || _headError(nodeList, heads, fromNode, toNode, q, emitterFlow, emitterOpen, resting, resistance, minor, exponent, darcy) <= tol) {
          converged = true;
          break;
        }
        refine++;
      }
      // adaptive damping if diverging
      if (relErr > lastErr * 1.5 && iter > 3) {
        damping = math.max(0.3, damping * 0.7);
      } else if (damping < 1) {
        damping = math.min(1, damping * 1.2);
      }
      lastErr = relErr;
    }
    if (!converged) warnings.add('not_converged');
    if (cutOff != null) warnings.addAll(_cutOffWarnings(nodeList, fromNode, toNode, cutOff));
    return _results(nodeList, heads, fromNode, toNode, q, emitterFlow, emitterOpen, converged, iter, warnings, relErr);
  }

  /// Newton steps past the flow test to meet [NetworkOptions.headTolerance].
  static const _maxHeadRefinements = 10;

  /// Largest error (m) of the energy equation over the open links and the
  /// open emitters for flows [q] and [heads]: |hᵢ − hⱼ − h(Q)| (the head
  /// error test of EPANET 2.2).
  double _headError(
    List<HNode> nodeList,
    Float64List heads,
    Int32List fromNode,
    Int32List toNode,
    Float64List q,
    Float64List emitterFlow,
    Uint8List emitterOpen,
    Uint8List resting,
    Float64List resistance,
    Float64List minor,
    double exponent,
    bool darcy,
  ) {
    var worst = 0.0;
    for (var k = 0; k < links.length; k++) {
      final l = links[k];
      if (resting[fromNode[k]] == 1 && resting[toNode[k]] == 1) continue;
      final dh = heads[fromNode[k]] - heads[toNode[k]];
      double h;
      switch (l.kind) {
        case HLinkKind.pipe:
          if (l.status == LinkStatus.closed) continue;
          final r = darcy ? _pipeResistance(l, q[k]) : resistance[k];
          final qa = q[k].abs();
          final hh = r * math.pow(qa, exponent) + minor[k] * qa * qa;
          h = q[k] < 0 ? -hh : hh;
        case HLinkKind.device:
          if (l.status == LinkStatus.closed) continue;
          h = (l.device ?? const DeviceLossCurve(k: 0)).loss(q[k]);
        case HLinkKind.pump:
          final p = l.pump;
          if (p == null || l.status == LinkStatus.closed) continue;
          // as the coefficients: straight on beyond the runout
          final qa = math.max(q[k].abs(), _qMin), runout = p.runoutFlow;
          h = runout.isFinite && qa > runout ? -p.head(runout) + (qa - runout) * math.max(-p.gradient(runout), 1e-6) : -p.head(math.max(qa, p.peakFlow));
        default:
          continue;
      }
      worst = math.max(worst, (h - dh).abs());
    }
    for (var i = 0; i < nodeList.length; i++) {
      final n = nodeList[i];
      final em = n.emitter;
      if (em == null || n.emitterCount <= 0 || emitterOpen[i] != 1 || resting[i] == 1 || n.kind != HNodeKind.junction) continue;
      final (h, _) = _emitterLoss(em, n.emitterCount, emitterFlow[i]);
      worst = math.max(worst, (h - (heads[i] - n.elevation - n.emitterOffset)).abs());
    }
    return worst;
  }

  /// Links that never let water through: a closed link, a pump without a
  /// curve, an FCV set to no flow.
  static bool _neverOpen(HLink l) => l.kind == HLinkKind.closed || (l.kind == HLinkKind.pump && l.pump == null) || (l.kind == HLinkKind.fcv && l.fcvFlow <= 0);

  /// Nodes (1) of the parts no fixed head reaches through links that can
  /// open and that hold a demand; null when there are none.
  Uint8List? _cutOffParts(List<HNode> nodeList, Int32List fromNode, Int32List toNode) {
    if (!links.any(_neverOpen)) return null;
    final count = nodeList.length;
    final parent = Int32List.fromList(List<int>.generate(count, (i) => i));
    int find(int i) {
      while (parent[i] != i) {
        parent[i] = parent[parent[i]];
        i = parent[i];
      }
      return i;
    }

    for (var k = 0; k < links.length; k++) {
      if (_neverOpen(links[k])) continue;
      final ra = find(fromNode[k]), rb = find(toNode[k]);
      if (ra != rb) parent[ra] = rb;
    }
    final fed = Uint8List(count), wants = Uint8List(count);
    for (var i = 0; i < count; i++) {
      final n = nodeList[i];
      if (n.kind != HNodeKind.junction) fed[find(i)] = 1;
      if (n.demand != 0) wants[find(i)] = 1;
    }
    Uint8List? out;
    for (var i = 0; i < count; i++) {
      final r = find(i);
      if (fed[r] == 1 || wants[r] == 0) continue;
      (out ??= Uint8List(count))[i] = 1;
    }
    return out;
  }

  /// `demand_disconnected:<node>` for every part of [cutOff], at its node
  /// of the largest demand.
  List<String> _cutOffWarnings(List<HNode> nodeList, Int32List fromNode, Int32List toNode, Uint8List cutOff) {
    // the parts again (closed links apart), to name each one once
    final count = nodeList.length;
    final parent = Int32List.fromList(List<int>.generate(count, (i) => i));
    int find(int i) {
      while (parent[i] != i) {
        parent[i] = parent[parent[i]];
        i = parent[i];
      }
      return i;
    }

    for (var k = 0; k < links.length; k++) {
      if (_neverOpen(links[k]) || cutOff[fromNode[k]] == 0 || cutOff[toNode[k]] == 0) continue;
      final ra = find(fromNode[k]), rb = find(toNode[k]);
      if (ra != rb) parent[ra] = rb;
    }
    final top = <int, int>{};
    for (var i = 0; i < count; i++) {
      if (cutOff[i] == 0) continue;
      final r = find(i);
      final best = top[r];
      if (best == null || nodeList[i].demand.abs() > nodeList[best].demand.abs()) top[r] = i;
    }
    return [for (final i in top.values) 'demand_disconnected:${nodeList[i].id}'];
  }

  /// Plans of the last patterns solved, most recent first: the designer
  /// solves the networks of a zone again and again (bisections on the valve
  /// pressure), and making the plan was a good part of each solve.
  static final List<EliminationPlan> _plans = [];

  static EliminationPlan _planFor(int n, List<int> from, List<int> to) {
    for (var i = 0; i < _plans.length; i++) {
      final p = _plans[i];
      if (!p.matches(n, from, to)) continue;
      if (i > 0) _plans.insert(0, _plans.removeAt(i));
      return p;
    }
    final p = EliminationPlan(n, from, to);
    _plans.insert(0, p);
    if (_plans.length > 8) _plans.removeLast();
    return p;
  }

  static const _statusCheckFrequency = 2;
  static const _maxStatusCheck = 10;

  static bool _isClosedLink(HLink l) => l.status == LinkStatus.closed || _neverOpen(l);

  /// Links meeting at every node, each once and in link order, in CSR form:
  /// those of node i are at [start[i], start[i + 1]) after the n + 1 starts.
  static Int32List _incidence(int nodeCount, Int32List fromNode, Int32List toNode) {
    final count = Int32List(nodeCount + 1);
    for (var k = 0; k < fromNode.length; k++) {
      count[fromNode[k]]++;
      if (toNode[k] != fromNode[k]) count[toNode[k]]++;
    }
    final out = Int32List(nodeCount + 1 + count.fold(0, (s, c) => s + c));
    out[0] = nodeCount + 1;
    for (var i = 0; i < nodeCount; i++) {
      out[i + 1] = out[i] + count[i];
    }
    final fill = Int32List.fromList(out.sublist(0, nodeCount));
    for (var k = 0; k < fromNode.length; k++) {
      out[fill[fromNode[k]]++] = k;
      if (toNode[k] != fromNode[k]) out[fill[toNode[k]]++] = k;
    }
    return out;
  }

  /// Parts of the network that closed links cut off from every fixed head
  /// while nothing is drawn from them (a line at rest behind an idle pump),
  /// with the level each one rests at: the mean head across its closed
  /// links, which their equal 1/10⁸ conductances give, or its lowest
  /// emitter when that is lower, since the water drains out there. Solved
  /// with the rest, such a part left the system singular to rounding, its
  /// level held only by those conductances next to ones of 10⁷ inside it.
  /// Marks those nodes in [resting] with their level in [level]; false when
  /// no part rests. The parts of [cutOff] (a demand no fixed head reaches)
  /// rest too, empty: at zero pressure.
  bool _restingParts(List<HNode> nodeList, Int32List fromNode, Int32List toNode, Float64List heads, Uint8List emitterOpen, Uint8List resting, Float64List level, Uint8List? cutOff) {
    resting.fillRange(0, resting.length, 0);
    var anyClosed = false;
    for (final l in links) {
      if (_isClosedLink(l)) {
        anyClosed = true;
        break;
      }
    }
    if (!anyClosed) return false;
    final count = nodeList.length;
    final parent = Int32List.fromList(List<int>.generate(count, (i) => i));
    int find(int i) {
      while (parent[i] != i) {
        parent[i] = parent[parent[i]];
        i = parent[i];
      }
      return i;
    }

    for (var k = 0; k < links.length; k++) {
      if (_isClosedLink(links[k])) continue;
      final ra = find(fromNode[k]), rb = find(toNode[k]);
      if (ra != rb) parent[ra] = rb;
    }
    // parts that hold a fixed head, draw water or may move it themselves
    final busy = Uint8List(count);
    for (var i = 0; i < count; i++) {
      final n = nodeList[i];
      if (cutOff != null && cutOff[i] == 1) continue;
      if (n.kind != HNodeKind.junction || n.demand != 0 || emitterOpen[i] == 1) busy[find(i)] = 1;
    }
    for (var k = 0; k < links.length; k++) {
      final l = links[k];
      if (_isClosedLink(l)) continue;
      if (cutOff != null && cutOff[fromNode[k]] == 1) continue;
      if (l.kind == HLinkKind.pump || l.kind == HLinkKind.fcv || ((l.kind == HLinkKind.prv || l.kind == HLinkKind.psv) && l.status == LinkStatus.active)) {
        busy[find(fromNode[k])] = 1;
      }
    }
    final top = Float64List(count)..fillRange(0, count, double.negativeInfinity);
    final lowestEmitter = Float64List(count)..fillRange(0, count, double.infinity);
    final rests = Uint8List(count);
    var any = false;
    for (var i = 0; i < count; i++) {
      final r = find(i);
      if (busy[r] == 1) continue;
      final n = nodeList[i];
      rests[r] = 1;
      any = true;
      top[r] = math.max(top[r], n.elevation);
      if (n.emitter != null && n.emitterCount > 0) lowestEmitter[r] = math.min(lowestEmitter[r], n.elevation + n.emitterOffset);
    }
    if (!any) return false;
    final sum = Float64List(count);
    final across = Int32List(count);
    for (var k = 0; k < links.length; k++) {
      if (!_isClosedLink(links[k])) continue;
      final ra = find(fromNode[k]), rb = find(toNode[k]);
      if (ra == rb) continue;
      if (rests[ra] == 1) {
        sum[ra] += heads[toNode[k]];
        across[ra]++;
      }
      if (rests[rb] == 1) {
        sum[rb] += heads[fromNode[k]];
        across[rb]++;
      }
    }
    for (var i = 0; i < count; i++) {
      final r = find(i);
      if (rests[r] == 0) continue;
      resting[i] = 1;
      level[i] = cutOff != null && cutOff[i] == 1 ? nodeList[i].elevation : math.min(across[r] > 0 ? sum[r] / across[r] : top[r], lowestEmitter[r]);
    }
    return true;
  }

  /// Status changes of check valves, pumps and (with [prvs]) pressure
  /// reducing valves for the current heads; true when any changed.
  bool _checkLinkStatus(Float64List heads, Int32List fromNode, Int32List toNode, Float64List q, {required bool prvs}) {
    var statusChanged = false;
    for (var k = 0; k < links.length; k++) {
      final l = links[k];
      // a device whose loss has a constant part C (the head that opens
      // it): closed while the head across it is below C, as a check valve
      // with that cracking head (the step of its law at zero flow left an
      // idle branch off by ±C and two fixed heads closer than C unsolved)
      final opening = l.kind == HLinkKind.device ? (l.device?.c ?? 0) : 0.0;
      if (opening > 0) {
        final dh = heads[fromNode[k]] - heads[toNode[k]];
        final push = l.checkValve ? dh : dh.abs();
        final wasClosed = l.status == LinkStatus.closed;
        // open with next to no flow: the branch is idle and the valve shut
        if (!wasClosed && (push < opening - 1e-4 || q[k].abs() < 1e-9 || (l.checkValve && q[k] < -1e-6))) {
          l.status = LinkStatus.closed;
          q[k] = 0;
          statusChanged = true;
        } else if (wasClosed && push > opening + 1e-4) {
          l.status = LinkStatus.open;
          q[k] = dh < 0 ? -_qMin : _qMin;
          statusChanged = true;
        }
      } else
      // check valves: on a pipe, or a device of its own (a check valve
      // placed on the mainline), which used to let water run backwards
      if ((l.kind == HLinkKind.pipe || l.kind == HLinkKind.device) && l.checkValve) {
        final dh = heads[fromNode[k]] - heads[toNode[k]];
        final wasClosed = l.status == LinkStatus.closed;
        if (!wasClosed && (q[k] < -1e-6 || dh < -1e-4)) {
          l.status = LinkStatus.closed;
          statusChanged = true;
        } else if (wasClosed && dh > 1e-4) {
          l.status = LinkStatus.open;
          q[k] = _qMin;
          statusChanged = true;
        }
      }
      if (l.kind == HLinkKind.pump && l.pump != null) {
        // built-in check valve: closed while the head gain asked for is
        // above the highest head of the curve, reopened below it (the
        // shutoff head closed a pump that runs right of the top of a curve
        // that rises first)
        final gain = heads[toNode[k]] - heads[fromNode[k]];
        final shutoff = l.pump!.maxHead;
        if (l.status == LinkStatus.closed) {
          if (gain < shutoff - 1e-4) {
            l.status = LinkStatus.open;
            q[k] = _pumpFlowAtHead(l.pump!, gain);
            statusChanged = true;
          }
        } else if (gain > shutoff + 1e-4) {
          l.status = LinkStatus.closed;
          q[k] = 0;
          statusChanged = true;
        }
      }
      if (prvs && l.kind == HLinkKind.prv) {
        final hSet = nodes[l.to]!.elevation + l.prvSetting;
        final hi = heads[fromNode[k]], hj = heads[toNode[k]];
        final old = l.status;
        switch (old) {
          case LinkStatus.active:
            // opens when even fully open it cannot hold the setting: the
            // inlet less the open valve's own loss (EPANET), not the inlet
            final openLoss = l.device?.loss(q[k]) ?? 1e-2 * q[k];
            if (q[k] < -1e-6) {
              l.status = LinkStatus.closed;
            } else if (hi - openLoss < hSet - 1e-4) {
              l.status = LinkStatus.open;
            }
          case LinkStatus.open:
            if (q[k] < -1e-6) {
              l.status = LinkStatus.closed;
            } else if (hj > hSet + 1e-4) {
              l.status = LinkStatus.active;
            }
          case LinkStatus.closed:
            if (hi > hj + 1e-4 && hi < hSet - 1e-4) {
              l.status = LinkStatus.open;
            } else if (hi > hj + 1e-4 && hj < hSet - 1e-4) {
              l.status = LinkStatus.active;
            }
        }
        if (l.status != old) statusChanged = true;
        if (l.status == LinkStatus.closed) q[k] = 0;
      }
      if (prvs && l.kind == HLinkKind.psv) {
        // EPANET psvstatus: the setting is the upstream pressure
        final hSet = nodes[l.from]!.elevation + l.prvSetting;
        final hi = heads[fromNode[k]], hj = heads[toNode[k]];
        final old = l.status;
        switch (old) {
          case LinkStatus.active:
            // opens when, fully open, it would leave the upstream above the
            // setting anyway: the outlet plus the open valve's own loss
            final openLoss = l.device?.loss(q[k]) ?? 1e-2 * q[k];
            if (q[k] < -1e-6) {
              l.status = LinkStatus.closed;
            } else if (hj + openLoss > hSet + 1e-4) {
              l.status = LinkStatus.open;
            }
          case LinkStatus.open:
            if (q[k] < -1e-6) {
              l.status = LinkStatus.closed;
            } else if (hi < hSet - 1e-4) {
              l.status = LinkStatus.active;
            }
          case LinkStatus.closed:
            if (hj > hSet + 1e-4 && hi > hj + 1e-4) {
              l.status = LinkStatus.open;
            } else if (hi > hSet + 1e-4 && hi > hj + 1e-4) {
              l.status = LinkStatus.active;
            }
        }
        if (l.status != old) statusChanged = true;
        if (l.status == LinkStatus.closed) q[k] = 0;
      }
      if (prvs && l.kind == HLinkKind.fcv && l.fcvFlow > 0) {
        // EPANET fcvstatus: active while there is head to push the setting;
        // open (less than the setting) when the head across turns negative
        final hi = heads[fromNode[k]], hj = heads[toNode[k]];
        final old = l.status;
        if (old == LinkStatus.active && hi < hj - 1e-4) {
          l.status = LinkStatus.open;
        } else if (old == LinkStatus.open && q[k] >= l.fcvFlow) {
          l.status = LinkStatus.active;
          q[k] = l.fcvFlow;
        }
        if (l.status != old) statusChanged = true;
      }
    }
    return statusChanged;
  }

  static bool _isValve(HLink l) => l.kind == HLinkKind.prv || l.kind == HLinkKind.psv || l.kind == HLinkKind.fcv;

  NetworkResult _results(
    List<HNode> nodeList,
    Float64List heads,
    Int32List fromNode,
    Int32List toNode,
    Float64List q,
    Float64List emitterFlow,
    Uint8List emitterOpen,
    bool converged,
    int iter,
    List<String> warnings,
    double relErr,
  ) {
    final nodeResults = <String, NodeResult>{};
    for (var i = 0; i < nodeList.length; i++) {
      final n = nodeList[i];
      final h = heads[i];
      // the converged state of the emitter flow (it closes the balance)
      final qe = n.emitter != null && n.emitterCount > 0 && emitterOpen[i] == 1 ? emitterFlow[i] : 0.0;
      nodeResults[n.id] = NodeResult(head: h, pressure: h - n.elevation, demand: n.demand, emitterFlow: qe);
    }
    final linkResults = <String, LinkResult>{};
    for (var k = 0; k < links.length; k++) {
      final l = links[k];
      final flow = q[k];
      final v = l.kind == HLinkKind.pipe ? velocity(flow: flow.abs(), diameter: l.diameter) : 0.0;
      final hl = heads[fromNode[k]] - heads[toNode[k]];
      final pumpHead = l.kind == HLinkKind.pump && l.pump != null && flow > 0 ? l.pump!.head(flow) : 0.0;
      linkResults[l.id] = LinkResult(flow: flow, velocity: v, headLoss: hl, status: l.status, pumpHead: pumpHead);
    }
    return NetworkResult(converged: converged, iterations: iter, nodes: nodeResults, links: linkResults, warnings: warnings, relativeFlowError: relErr);
  }

  /// Flow on the falling part of the curve of [pump] where it gives [head]
  /// (a trickle when it cannot).
  static double _pumpFlowAtHead(PumpCurve pump, double head) {
    var lo = pump.peakFlow, hi = pump.runoutFlow.isFinite ? pump.runoutFlow : math.max(1.0, 2 * pump.peakFlow);
    if (!(pump.head(lo) > head)) return _qMin;
    for (var i = 0; i < 60; i++) {
      final mid = (lo + hi) / 2;
      if (pump.head(mid) > head) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return math.max((lo + hi) / 2, _qMin);
  }

  /// Pressure head an emitter node needs to pass [flow] through its
  /// [count] emitters, and its derivative, in the flow form h = (q/(c·k))^(1/x)
  /// of the law. Very small gradients (an emitter starved of water, or
  /// pressure compensating below its flow) use a linear law, as EPANET does.
  static (double, double) _emitterLoss(EmitterCurve em, int count, double flow) {
    final x = math.max(em.x, 0.01);
    final kk = em.k * count * (em.x < 0.01 ? math.pow(10.0, em.x - x).toDouble() : 1.0);
    if (!(kk > 0)) return (0.0, _emitterMinGradient);
    final hc = em.compensationHead;
    if (hc > 0) {
      // below its compensating range an orifice: h = hc·(q/qc)²
      final qc = kk * math.pow(hc, x).toDouble();
      final qq = math.max(flow, 0.0);
      if (qq < qc) {
        final h = hc * (qq / qc) * (qq / qc), grad = 2 * hc * qq / (qc * qc);
        if (grad < _emitterMinGradient) return (_emitterMinGradient * qq, _emitterMinGradient);
        return (h, grad);
      }
    }
    final q = math.min(math.max(flow, 0.0), kk * math.pow(_emitterMaxHead, x).toDouble());
    final h = math.pow(q / kk, 1 / x).toDouble();
    final grad = q > 0 ? h / (x * q) : 0.0;
    if (!h.isFinite || !grad.isFinite) return (_emitterMaxHead, 1e12);
    if (grad < _emitterMinGradient) return (_emitterMinGradient * q, _emitterMinGradient);
    return (h, grad);
  }

  static const double _emitterMinGradient = 1e-6;

  /// Highest pressure head the flow form is evaluated at (m): above it a
  /// steep law overflows; no emitter works there anyway.
  static const double _emitterMaxHead = 1000;

  /// Flow of [count] emitters at pressure head [p], in the law the solver
  /// uses (x below 0.01 taken as 0.01 through the same flow at 10 m).
  static double _emitterLaw(EmitterCurve em, int count, double p) {
    final x = math.max(em.x, 0.01);
    final kk = em.k * count * (em.x < 0.01 ? math.pow(10.0, em.x - x).toDouble() : 1.0);
    final hc = em.compensationHead;
    if (hc > 0 && p < hc) return kk * math.pow(hc, x).toDouble() * math.sqrt(math.max(p, 0.0) / hc);
    return kk * math.pow(math.min(math.max(p, 0.0), _emitterMaxHead), x).toDouble();
  }

  double _pipeResistance(HLink l, double flow) {
    switch (options.method) {
      case FrictionMethod.hazenWilliams:
        return hazenWilliamsResistance(diameter: l.diameter, length: l.length, c: l.hazenC);
      case FrictionMethod.darcyWeisbach:
        final qa = math.max(flow.abs(), _qMin);
        final v = velocity(flow: qa, diameter: l.diameter);
        final re = v * l.diameter / options.kinematicViscosity;
        final f = darcyFrictionFactor(reynolds: re, relRoughness: l.roughness / l.diameter);
        final a = math.pi * l.diameter * l.diameter / 4;
        return f * l.length / (l.diameter * 2 * 9.80665 * a * a);
      case FrictionMethod.scobey:
        return scobeyResistance(diameter: l.diameter, length: l.length, ks: l.scobeyKs);
      case FrictionMethod.manning:
        return manningResistance(diameter: l.diameter, length: l.length, n: l.manningN);
    }
  }
}
