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

    final emitterFlow = <String, double>{for (final n in nodeList) n.id: 0};
    // Emitters are one-way: below their elevation they are closed. Tracked so
    // that an open/closed change counts as a status change for convergence.
    final emitterOpen = <String, bool>{};

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
            } else if (qk <= 0) {
              // reverse flow: close the pump (check valve behaviour)
              gk = _closedResistance;
              yk = _closedResistance * qk;
            } else {
              final runout = p.runoutFlow;
              if (runout.isFinite && qk > runout) {
                final gr = math.max(-p.gradient(runout), 1e-6);
                gk = gr;
                yk = -p.head(runout) + (qk - runout) * gr;
              } else {
                gk = math.max(-p.gradient(qk), 1e-6);
                yk = -p.head(qk);
              }
            }
        }
        g[k] = gk;
        y[k] = yk;
      }

      // --- assemble ---
      final sys = SparseSymmetricSystem(unknownCount);
      var emitterStatusChanged = false;
      for (final n in nodeList) {
        final i = index[n.id];
        if (i == null) continue;
        var demand = n.demand;
        final em = n.emitter;
        if (em != null && n.emitterCount > 0) {
          // emitter as fictitious link to a reservoir at the emitter elevation
          final zEm = n.elevation + n.emitterOffset;
          final pRaw = heads[n.id]! - zEm;
          final open = pRaw > 0;
          final was = emitterOpen[n.id];
          if (was != null && was != open) emitterStatusChanged = true;
          emitterOpen[n.id] = open;
          if (!open) {
            // Closed: no outflow and, unlike a reservoir link, no backflow
            // into the node. A negligible conductance keeps the equation
            // regular; the emitter reopens once the pressure turns positive.
            const ge = 1e-12;
            sys.addDiagonal(i, ge);
            sys.rhs[i] += ge * zEm;
            emitterFlow[n.id] = 0;
          } else {
            final p = math.max(pRaw, 1e-6);
            final qe = em.flow(p) * n.emitterCount;
            final ge = math.max(em.gradient(p) * n.emitterCount, 1e-9);
            // link i -> fictitious (H_f = zEm): h = p, dh/dq = 1/ge
            final gLink = 1 / ge; // dh/dQ
            final yLink = p; // h(Q) for the current Q = qe
            sys.addDiagonal(i, 1 / gLink);
            sys.rhs[i] += (-qe) + yLink / gLink + zEm / gLink;
            emitterFlow[n.id] = qe;
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
      relErr = sumQ > 0 ? sumDq / sumQ : 0;
      if (sumDq < options.absoluteFlowTolerance) relErr = 0;

      // --- status checks (PRV, check valves) ---
      var statusChanged = emitterStatusChanged;
      for (var k = 0; k < links.length; k++) {
        final l = links[k];
        if (l.kind == HLinkKind.pipe && l.checkValve) {
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
        if (l.kind == HLinkKind.prv) {
          final toNode = nodes[l.to]!;
          final hSet = toNode.elevation + l.prvSetting;
          final hi = heads[l.from]!, hj = heads[l.to]!;
          final old = l.status;
          switch (old) {
            case LinkStatus.active:
              if (q[k] < -1e-6) {
                l.status = LinkStatus.closed;
              } else if (hi < hSet - 1e-4) {
                l.status = LinkStatus.open;
              }
            case LinkStatus.open:
              if (q[k] < -1e-6) {
                l.status = LinkStatus.closed;
              } else if (hi > hSet + 1e-4) {
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

      if (relErr < options.flowTolerance && !statusChanged && iter > 1) {
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

    // --- results ---
    final nodeResults = <String, NodeResult>{};
    for (final n in nodeList) {
      final h = heads[n.id]!;
      double qe = 0;
      if (n.emitter != null && n.emitterCount > 0) {
        qe = n.emitter!.flow(math.max(h - n.elevation - n.emitterOffset, 0)) * n.emitterCount;
      }
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
