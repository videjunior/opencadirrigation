/// Steady-state pipe-network solver based on the Global Gradient Algorithm
/// (Todini & Pilati 1988), as implemented in EPANET, extended with
/// pressure-dependent emitters, pumps, PRVs and check valves.
///
/// Units are SI throughout: flow m³/s, head m, elevation m, diameter m.
library;

import 'dart:math' as math;

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

enum HLinkKind { pipe, pump, prv, device, closed }

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
  });

  final String id;
  final String from;
  final String to;
  HLinkKind kind;
  double diameter;
  double length;
  double hazenC;
  double roughness;
  double minorK;
  bool checkValve;
  PumpCurve? pump;
  DeviceLossCurve? device;

  /// PRV downstream pressure-head setting (m above the downstream node).
  double prvSetting;
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
  NetworkResult({
    required this.converged,
    required this.iterations,
    required this.nodes,
    required this.links,
    required this.warnings,
    required this.relativeFlowError,
  });
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

  NetworkResult solve({Map<String, double>? initialFlows}) {
    final warnings = <String>[];
    final nodeList = nodes.values.toList();
    final index = <String, int>{};
    var unknownCount = 0;
    for (final n in nodeList) {
      if (n.kind == HNodeKind.junction) {
        index[n.id] = unknownCount++;
      }
    }
    if (nodeList.where((n) => n.kind == HNodeKind.reservoir).isEmpty) {
      warnings.add('no_fixed_head_node');
    }
    final heads = <String, double>{
      for (final n in nodeList) n.id: n.kind == HNodeKind.reservoir ? (n.fixedHead ?? n.elevation) : n.elevation + 10,
    };

    // Initial flows: 1 m/s-equivalent in pipes, positive for pumps.
    final q = <double>[];
    for (final l in links) {
      final init = initialFlows?[l.id];
      if (init != null) {
        q.add(init);
      } else {
        switch (l.kind) {
          case HLinkKind.pipe:
          case HLinkKind.device:
          case HLinkKind.prv:
            q.add(flowForVelocity(velocity: 1.0, diameter: l.diameter));
          case HLinkKind.pump:
            q.add(l.pump != null ? math.max(l.pump!.runoutFlow.isFinite ? l.pump!.runoutFlow / 2 : 0.01, 1e-4) : 0.01);
          case HLinkKind.closed:
            q.add(0);
        }
      }
      if (l.kind == HLinkKind.prv) l.status = LinkStatus.active;
      if (l.kind == HLinkKind.closed) l.status = LinkStatus.closed;
      if (l.kind != HLinkKind.closed && l.kind != HLinkKind.prv) l.status = LinkStatus.open;
    }

    // Emitters are fictitious links to a reservoir at the emitter elevation
    // whose flow is a state variable, as in EPANET: in flow form the law
    // p = (q/k)^(1/x) is convex, so the Newton step behaves like a pipe's;
    // linearising q(p) instead overshoots (dq/dp is infinite at p = 0) and
    // made emitters near zero pressure flip open/closed without end.
    // They are one-way: closed below their elevation, no backflow.
    final emitterFlow = <String, double>{for (final n in nodeList) n.id: 0};
    final emitterOpen = <String, bool>{};
    for (final n in nodeList) {
      final em = n.emitter;
      if (em == null || n.emitterCount <= 0 || n.kind != HNodeKind.junction) continue;
      final p0 = heads[n.id]! - n.elevation - n.emitterOffset;
      emitterOpen[n.id] = p0 > 0;
      emitterFlow[n.id] = p0 > 0 ? _emitterLaw(em, n.emitterCount, p0) : 0;
    }
    final eGrad = <String, double>{};
    final eLoss = <String, double>{};

    var converged = false;
    var iter = 0;
    var relErr = double.infinity;
    var lastErr = double.infinity;
    var damping = 1.0;

    // Working arrays per link.
    final g = List<double>.filled(links.length, 1);
    final y = List<double>.filled(links.length, 0);

    for (iter = 1; iter <= options.maxIterations; iter++) {
      // --- link coefficients ---
      for (var k = 0; k < links.length; k++) {
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
              final r = _pipeResistance(l, qk);
              final n = options.method == FrictionMethod.hazenWilliams ? 1.852 : 2.0;
              final qa = math.max(qk.abs(), _qMin);
              final m = l.minorK > 0 ? minorLossFlowCoefficient(k: l.minorK, diameter: l.diameter) : 0.0;
              var gg = n * r * math.pow(qa, n - 1) + 2 * m * qa;
              if (options.method == FrictionMethod.darcyWeisbach && qa > _qMin * 10) {
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
              gk = math.max(d.gradient(qk), 1e-9);
              yk = d.loss(qk);
            }
          case HLinkKind.prv:
            final d = l.device;
            if (l.status == LinkStatus.closed) {
              gk = _closedResistance;
              yk = _closedResistance * qk;
            } else if (l.status == LinkStatus.open) {
              gk = d != null ? math.max(d.gradient(qk), 1e-9) : 1e-2;
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
              // the head is closed by the status check below
              final qa = math.max(qk.abs(), _qMin);
              final runout = p.runoutFlow;
              if (runout.isFinite && qa > runout) {
                final gr = math.max(-p.gradient(runout), 1e-6);
                gk = gr;
                yk = -p.head(runout) + (qa - runout) * gr;
              } else {
                gk = math.max(-p.gradient(qa), 1e-6);
                yk = -p.head(qa);
              }
            }
        }
        g[k] = gk;
        y[k] = yk;
      }

      // --- assemble ---
      final sys = SparseSymmetricSystem(unknownCount);
      for (final n in nodeList) {
        final i = index[n.id];
        if (i == null) continue;
        var demand = n.demand;
        final em = n.emitter;
        if (em != null && n.emitterCount > 0) {
          final zEm = n.elevation + n.emitterOffset;
          if (emitterOpen[n.id] != true) {
            // Closed: no outflow and no backflow into the node. A negligible
            // conductance keeps the equation regular; the emitter reopens
            // once the pressure turns positive.
            const ge = 1e-12;
            sys.addDiagonal(i, ge);
            sys.rhs[i] += ge * zEm;
          } else {
            final qe = emitterFlow[n.id]!;
            final (h, dh) = _emitterLoss(em, n.emitterCount, qe);
            eLoss[n.id] = h;
            eGrad[n.id] = dh;
            sys.addDiagonal(i, 1 / dh);
            sys.rhs[i] += -qe + (h + zEm) / dh;
          }
        }
        sys.rhs[i] -= demand;
      }
      for (var k = 0; k < links.length; k++) {
        final l = links[k];
        final iFrom = index[l.from];
        final iTo = index[l.to];
        if (l.kind == HLinkKind.prv && l.status == LinkStatus.active) {
          // downstream node fixed to setting; flow appears as demand upstream
          final toNode = nodes[l.to]!;
          final hSet = toNode.elevation + l.prvSetting;
          if (iTo != null) {
            sys.addDiagonal(iTo, 1e8);
            sys.rhs[iTo] += 1e8 * hSet;
            // the valve flow enters node `to` as an inflow: include current q
            sys.rhs[iTo] += q[k];
          }
          if (iFrom != null) sys.rhs[iFrom] += -q[k];
          continue;
        }
        final inv = 1 / g[k];
        final qk = q[k];
        final yk = y[k];
        if (iFrom != null) {
          sys.addDiagonal(iFrom, inv);
          sys.rhs[iFrom] += -qk + yk * inv;
          if (iTo == null) sys.rhs[iFrom] += heads[l.to]! * inv;
        }
        if (iTo != null) {
          sys.addDiagonal(iTo, inv);
          sys.rhs[iTo] += qk - yk * inv;
          if (iFrom == null) sys.rhs[iTo] += heads[l.from]! * inv;
        }
        if (iFrom != null && iTo != null) sys.add(iFrom, iTo, -inv);
      }

      final x = sys.solve();
      for (final n in nodeList) {
        final i = index[n.id];
        if (i != null) {
          final hNew = x[i];
          if (hNew.isFinite) heads[n.id] = hNew;
        }
      }

      // --- update flows ---
      var sumDq = 0.0, sumQ = 0.0;
      for (var k = 0; k < links.length; k++) {
        final l = links[k];
        final dh = heads[l.from]! - heads[l.to]!;
        double qNew;
        if (l.kind == HLinkKind.prv && l.status == LinkStatus.active) {
          // continuity at downstream node
          final toNode = nodes[l.to]!;
          var net = toNode.demand + emitterFlow[l.to]!;
          for (var j = 0; j < links.length; j++) {
            if (j == k) continue;
            final o = links[j];
            if (o.from == l.to) net += q[j];
            if (o.to == l.to) net -= q[j];
          }
          qNew = net;
        } else {
          qNew = q[k] - damping * (y[k] - dh) / g[k];
        }
        if (!qNew.isFinite) qNew = 0;
        sumDq += (qNew - q[k]).abs();
        sumQ += qNew.abs();
        q[k] = qNew;
      }
      var emitterStatusChanged = false;
      for (final n in nodeList) {
        final em = n.emitter;
        if (em == null || n.emitterCount <= 0 || index[n.id] == null) continue;
        final zEm = n.elevation + n.emitterOffset;
        final p = heads[n.id]! - zEm;
        if (emitterOpen[n.id] == true) {
          final qe = emitterFlow[n.id]!;
          var qNew = qe - damping * (eLoss[n.id]! - p) / eGrad[n.id]!;
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
            emitterOpen[n.id] = false;
            emitterStatusChanged = true;
          }
          sumDq += (qNew - qe).abs();
          sumQ += qNew.abs();
          emitterFlow[n.id] = qNew;
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
        for (final n in nodeList) {
          final em = n.emitter;
          if (em == null || n.emitterCount <= 0 || index[n.id] == null || emitterOpen[n.id] == true) continue;
          final p = heads[n.id]! - n.elevation - n.emitterOffset;
          if (p > 1e-4) {
            emitterOpen[n.id] = true;
            emitterFlow[n.id] = _emitterLaw(em, n.emitterCount, p);
            statusChanged = true;
          }
        }
        statusChanged = _checkLinkStatus(heads, q, prvs: flowsConverged) || statusChanged;
      }
      if (flowsConverged && !statusChanged) {
        converged = true;
        break;
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
    return _results(nodeList, heads, q, emitterFlow, emitterOpen, converged, iter, warnings, relErr);
  }

  static const _statusCheckFrequency = 2;
  static const _maxStatusCheck = 10;

  /// Status changes of check valves, pumps and (with [prvs]) pressure
  /// reducing valves for the current heads; true when any changed.
  bool _checkLinkStatus(Map<String, double> heads, List<double> q, {required bool prvs}) {
    var statusChanged = false;
    for (var k = 0; k < links.length; k++) {
      final l = links[k];
      // check valves: on a pipe, or a device of its own (a check valve
      // placed on the mainline), which used to let water run backwards
      if ((l.kind == HLinkKind.pipe || l.kind == HLinkKind.device) && l.checkValve) {
        final dh = heads[l.from]! - heads[l.to]!;
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
        // above the shutoff head, reopened below it
        final gain = heads[l.to]! - heads[l.from]!;
        final shutoff = l.pump!.shutoffHead;
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
        final toNode = nodes[l.to]!;
        final hSet = toNode.elevation + l.prvSetting;
        final hi = heads[l.from]!, hj = heads[l.to]!;
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
    }
    return statusChanged;
  }

  NetworkResult _results(List<HNode> nodeList, Map<String, double> heads, List<double> q, Map<String, double> emitterFlow, Map<String, bool> emitterOpen, bool converged, int iter, List<String> warnings, double relErr) {
    final nodeResults = <String, NodeResult>{};
    for (final n in nodeList) {
      final h = heads[n.id]!;
      // the converged state of the emitter flow (it closes the balance)
      final qe = n.emitter != null && n.emitterCount > 0 && emitterOpen[n.id] == true ? emitterFlow[n.id]! : 0.0;
      nodeResults[n.id] = NodeResult(head: h, pressure: h - n.elevation, demand: n.demand, emitterFlow: qe);
    }
    final linkResults = <String, LinkResult>{};
    for (var k = 0; k < links.length; k++) {
      final l = links[k];
      final flow = q[k];
      final v = l.kind == HLinkKind.pipe ? velocity(flow: flow.abs(), diameter: l.diameter) : 0.0;
      final hl = heads[l.from]! - heads[l.to]!;
      final pumpHead = l.kind == HLinkKind.pump && l.pump != null && flow > 0 ? l.pump!.head(flow) : 0.0;
      linkResults[l.id] = LinkResult(flow: flow, velocity: v, headLoss: hl, status: l.status, pumpHead: pumpHead);
    }
    return NetworkResult(
      converged: converged,
      iterations: iter,
      nodes: nodeResults,
      links: linkResults,
      warnings: warnings,
      relativeFlowError: relErr,
    );
  }

  /// Flow on the curve of [pump] where it gives [head] (a trickle when it
  /// cannot).
  static double _pumpFlowAtHead(PumpCurve pump, double head) {
    var lo = 0.0, hi = pump.runoutFlow.isFinite ? pump.runoutFlow : 1.0;
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
    }
  }
}
