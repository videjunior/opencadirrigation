/// Extended-period simulation (EPS): a sequence of steady solutions of a
/// [HydraulicNetwork] in time, with tanks whose level changes with their net
/// inflow, demand and emitter multipliers by time pattern, link schedules
/// (irrigation shifts: zone valves opening at their start hour for their
/// duration) and demand schedules (the same shifts on a mainline network,
/// where a zone is the demand of its valve node), simple controls (pumps or
/// valves switched by a tank level or by the clock) and the pump energy and
/// its cost.
///
/// The time stepping follows EPANET (Rossman 2000, *EPANET 2 Users Manual*,
/// and the analysis algorithms of EPANET 2.2): every hydraulic step solves
/// the network with the tanks as fixed heads at their current levels, then
/// integrates the tank volumes over the step, which is cut short at the
/// next schedule, pattern or control event, when a tank would fill or empty,
/// or when a tank reaches the level of a control. A full tank closes the
/// links that would overfill it and an empty one those that would drain it.
/// Each solve starts from the flows of the previous one. The network solver
/// itself ([HydraulicNetwork.solve]) is not changed: the simulation works on
/// a copy of the network.
///
/// Units are SI: time s, flow m³/s, head and level m, volume m³, energy kWh.
library;

import 'dart:math' as math;

import '../units.dart';
import 'emitter.dart';
import 'network.dart';

/// A tank at a node of the network: its head is the bottom elevation plus
/// the water level.
class EpsTank {
  /// Levels are measured from the bottom (m). The volume is a cylinder of
  /// [area] (or [diameter]) or follows [volumeCurve], (level, volume)
  /// points with both increasing.
  const EpsTank({required this.nodeId, required this.initialLevel, required this.maxLevel, this.minLevel = 0, this.area, this.diameter, this.volumeCurve, this.bottomElevation});
  final String nodeId;
  final double initialLevel;
  final double maxLevel;
  final double minLevel;
  final double? area;
  final double? diameter;
  final List<(double, double)>? volumeCurve;

  /// Elevation of the bottom (m); null = the node elevation.
  final double? bottomElevation;

  double get _area {
    final a = area;
    if (a != null && a > 0) return a;
    final d = diameter;
    if (d != null && d > 0) return math.pi * d * d / 4;
    return 1;
  }

  /// Volume (m³) at [level] (m above the bottom).
  double volumeAt(double level) {
    final c = volumeCurve;
    if (c == null || c.length < 2) return _area * level;
    if (level <= c.first.$1) return c.first.$2 + (level - c.first.$1) * _slope(c, 0);
    for (var i = 1; i < c.length; i++) {
      if (level <= c[i].$1) {
        final (l0, v0) = c[i - 1];
        final (l1, v1) = c[i];
        return l1 > l0 ? v0 + (v1 - v0) * (level - l0) / (l1 - l0) : v1;
      }
    }
    return c.last.$2 + (level - c.last.$1) * _slope(c, c.length - 2);
  }

  /// Level (m above the bottom) holding [volume].
  double levelAt(double volume) {
    final c = volumeCurve;
    if (c == null || c.length < 2) return volume / _area;
    if (volume <= c.first.$2) {
      final s = _slope(c, 0);
      return s > 0 ? c.first.$1 + (volume - c.first.$2) / s : c.first.$1;
    }
    for (var i = 1; i < c.length; i++) {
      if (volume <= c[i].$2) {
        final (l0, v0) = c[i - 1];
        final (l1, v1) = c[i];
        return v1 > v0 ? l0 + (l1 - l0) * (volume - v0) / (v1 - v0) : l1;
      }
    }
    final s = _slope(c, c.length - 2);
    return s > 0 ? c.last.$1 + (volume - c.last.$2) / s : c.last.$1;
  }

  static double _slope(List<(double, double)> c, int i) {
    final dl = c[i + 1].$1 - c[i].$1;
    return dl > 0 ? (c[i + 1].$2 - c[i].$2) / dl : 0;
  }
}

/// Multipliers that change every [step] seconds from [start], repeating.
class EpsPattern {
  const EpsPattern(this.multipliers, {this.step = 3600, this.start = 0});
  final List<double> multipliers;
  final double step;
  final double start;

  int _period(double t) => ((t - start) / step + 1e-9).floor();

  /// Multiplier at time [t] (s).
  double at(double t) {
    if (multipliers.isEmpty || step <= 0) return 1;
    final n = multipliers.length;
    return multipliers[((_period(t) % n) + n) % n];
  }

  /// First change after [t].
  double nextChange(double t) => multipliers.length <= 1 || step <= 0 ? double.infinity : start + (_period(t) + 1) * step;
}

/// Status of a link by time: an irrigation shift is a zone valve open from
/// its start for its duration.
class EpsSchedule {
  /// Open during every (start, duration) interval and closed otherwise; with
  /// [period] (e.g. 86400 s) the intervals repeat.
  const EpsSchedule.intervals(this.linkId, List<(double, double)> this.intervals, {this.period}) : events = null;

  /// Status set at given times, (time, open); before the first one the link
  /// keeps its own status.
  const EpsSchedule.events(this.linkId, List<(double, bool)> this.events) : intervals = null, period = null;

  final String linkId;
  final List<(double, double)>? intervals;
  final List<(double, bool)>? events;
  final double? period;

  /// Status at [t]: true open, false closed, null not scheduled (yet).
  bool? openAt(double t) {
    final iv = intervals;
    if (iv != null) {
      final p = period;
      final tt = p != null && p > 0 ? t % p : t;
      for (final (s, d) in iv) {
        if (tt >= s - 1e-9 && tt < s + d - 1e-9) return true;
      }
      return false;
    }
    bool? st;
    for (final (te, open) in events!) {
      if (te <= t + 1e-9) st = open;
    }
    return st;
  }

  /// First status change after [t].
  double nextChange(double t) {
    var best = double.infinity;
    final iv = intervals;
    if (iv != null) {
      final p = period;
      if (p != null && p > 0) {
        final base = (t / p).floor() * p;
        for (var k = 0; k <= 1; k++) {
          for (final (s, d) in iv) {
            for (final b in [base + k * p + s, base + k * p + s + d]) {
              if (b > t + 1e-9 && b < best) best = b;
            }
          }
        }
      } else {
        for (final (s, d) in iv) {
          for (final b in [s, s + d]) {
            if (b > t + 1e-9 && b < best) best = b;
          }
        }
      }
      return best;
    }
    for (final (te, _) in events!) {
      if (te > t + 1e-9 && te < best) best = te;
    }
    return best;
  }
}

/// Demand (and emitters) of a node switched on during intervals: a zone as
/// the mainline sees it, drawing its flow while its valve is open, so the
/// shifts of a system flow (start hour, duration) become the intervals of
/// the mainline nodes of its valves.
class EpsDemandSchedule {
  /// On during every (start, duration) interval, off otherwise; with
  /// [period] (e.g. 86400 s) the intervals repeat.
  const EpsDemandSchedule(this.nodeId, this.intervals, {this.period});
  final String nodeId;
  final List<(double, double)> intervals;
  final double? period;

  EpsSchedule get _asSchedule => EpsSchedule.intervals(nodeId, intervals, period: period);

  /// On at [t].
  bool onAt(double t) => _asSchedule.openAt(t)!;

  /// First switch after [t].
  double nextChange(double t) => _asSchedule.nextChange(t);
}

/// What triggers a control.
enum EpsControlKind { levelBelow, levelAbove, time, clockTime }

/// A simple control (as in EPANET): set link [linkId] open or closed when a
/// tank level falls below or rises above a value, at a time, or every day at
/// a clock hour. Controls act after the schedules.
class EpsControl {
  const EpsControl.levelBelow(this.linkId, {required String this.tankId, required this.level, required this.open}) : kind = EpsControlKind.levelBelow, time = 0;
  const EpsControl.levelAbove(this.linkId, {required String this.tankId, required this.level, required this.open}) : kind = EpsControlKind.levelAbove, time = 0;
  const EpsControl.atTime(this.linkId, {required this.time, required this.open}) : kind = EpsControlKind.time, tankId = null, level = 0;

  /// Every day at [hour] (0–24) of the clock (see [EpsOptions.startHour]).
  const EpsControl.atClockTime(this.linkId, {required double hour, required this.open}) : kind = EpsControlKind.clockTime, time = hour * 3600, tankId = null, level = 0;

  final EpsControlKind kind;
  final String linkId;
  final String? tankId;

  /// Level (m above the tank bottom) of a level control.
  final double level;

  /// Time (s) of a time control, or the clock time (s after midnight).
  final double time;
  final bool open;
}

/// Integration of the tank volumes over a step.
enum EpsIntegration {
  /// Explicit Euler with the flows at the start of the step (EPANET).
  euler,

  /// Heun's predictor-corrector: a second solve at the end of the step,
  /// second order in the step.
  heun,
}

/// Simulation settings.
class EpsOptions {
  const EpsOptions({
    this.duration = 86400,
    this.hydraulicStep = 3600,
    this.integration = EpsIntegration.euler,
    this.demandPatterns = const {},
    this.defaultDemandPattern,
    this.emitterPatterns = const {},
    this.defaultEmitterPattern,
    this.pumpEfficiency = const {},
    this.defaultEfficiency = 0.7,
    this.tariff,
    this.startHour = 0,
    this.recordNodes,
    this.recordLinks,
  });

  /// Simulated time and the largest hydraulic step (s).
  final double duration;
  final double hydraulicStep;
  final EpsIntegration integration;

  /// Demand multipliers per node; nodes without one use
  /// [defaultDemandPattern] (none = 1).
  final Map<String, EpsPattern> demandPatterns;
  final EpsPattern? defaultDemandPattern;

  /// Emitter coefficient multipliers per node, and the default.
  final Map<String, EpsPattern> emitterPatterns;
  final EpsPattern? defaultEmitterPattern;

  /// Efficiency of each pump link, and the default.
  final Map<String, double> pumpEfficiency;
  final double defaultEfficiency;

  /// Price of energy (currency per kWh) at an hour of the day (0–24).
  final double Function(double hour)? tariff;

  /// Clock hour at t = 0 (for the tariff and the clock controls).
  final double startHour;

  /// Nodes and links whose series are kept (null = all).
  final Set<String>? recordNodes;
  final Set<String>? recordLinks;
}

/// Energy of one pump.
class EpsPumpEnergy {
  EpsPumpEnergy(this.linkId);
  final String linkId;

  /// Energy (kWh), its cost, volume pumped (m³), hours running and the
  /// largest power (kW).
  double energyKwh = 0;
  double cost = 0;
  double volume = 0;
  double hoursOn = 0;
  double maxPowerKw = 0;

  /// Shaft power (kW) at each entry of [EpsResult.times].
  final List<double> power = [];
}

/// Result of [simulateEps]: series with one entry per hydraulic step start
/// (the state during the step) and one at the end.
class EpsResult {
  EpsResult();

  /// Times (s).
  final List<double> times = [];

  /// Tank levels (m above the bottom) and volumes (m³).
  final Map<String, List<double>> tankLevels = {};
  final Map<String, List<double>> tankVolumes = {};

  /// Node heads and pressure heads (m).
  final Map<String, List<double>> nodeHeads = {};
  final Map<String, List<double>> nodePressures = {};

  /// Link flows (m³/s) and whether each link was open.
  final Map<String, List<double>> linkFlows = {};
  final Map<String, List<bool>> linkOpen = {};

  /// Energy per pump link.
  final Map<String, EpsPumpEnergy> pumps = {};

  /// Times at which each tank became full and empty.
  final Map<String, List<double>> tankFullTimes = {};
  final Map<String, List<double>> tankEmptyTimes = {};

  /// Codes: `eps_tank_full:<id>`, `eps_tank_empty:<id>`, `eps_not_converged:<t>`
  /// (t in s), `eps_unknown_node:<id>`, `eps_unknown_link:<id>`.
  final List<String> messages = [];

  /// Every solve converged.
  bool converged = true;

  double get totalEnergyKwh => pumps.values.fold(0.0, (s, p) => s + p.energyKwh);
  double get totalCost => pumps.values.fold(0.0, (s, p) => s + p.cost);

  /// Index of the entry in force at [t] (the last one starting at or before it).
  int indexAt(double t) {
    var lo = 0, hi = times.length - 1;
    if (hi < 0) return -1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (times[mid] <= t + 1e-9) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }
}

class _TankState {
  _TankState(this.spec, this.node, this.bottom) : vMin = spec.volumeAt(spec.minLevel), vMax = spec.volumeAt(spec.maxLevel);
  final EpsTank spec;
  final HNode node;
  final double bottom;
  final double vMin;
  final double vMax;
  late double volume;
  late double level;
  bool wasFull = false, wasEmpty = false;
  double get tol => 1e-9 * math.max(vMax.abs(), 1);
  bool get full => volume >= vMax - tol;
  bool get empty => volume <= vMin + tol;
}

/// Runs an extended-period simulation of [network] (which is not changed):
/// [tanks] are nodes with a variable level (turned into fixed heads at each
/// step), [schedules] and [controls] open and close links over time and
/// [demandSchedules] switch the demands of nodes on and off.
EpsResult simulateEps(
  HydraulicNetwork network, {
  List<EpsTank> tanks = const [],
  List<EpsSchedule> schedules = const [],
  List<EpsControl> controls = const [],
  List<EpsDemandSchedule> demandSchedules = const [],
  EpsOptions options = const EpsOptions(),
}) => _Eps(network, tanks, schedules, controls, demandSchedules, options).run();

class _Eps {
  _Eps(HydraulicNetwork source, this.tankSpecs, this.schedules, this.controls, this.demandSchedules, this.o) : net = HydraulicNetwork(options: source.options) {
    for (final n in source.nodes.values) {
      net.addNode(
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
    for (final l in source.links) {
      net.addLink(
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
  }

  final HydraulicNetwork net;
  final List<EpsTank> tankSpecs;
  final List<EpsSchedule> schedules;
  final List<EpsControl> controls;
  final List<EpsDemandSchedule> demandSchedules;
  final EpsOptions o;
  final res = EpsResult();
  final baseEmitterCount = <String, int>{};
  final demandOn = <String, List<EpsDemandSchedule>>{};
  final tanks = <_TankState>[];
  final baseKind = <String, HLinkKind>{};
  final baseDemand = <String, double>{};
  final baseEmitter = <String, EmitterCurve>{};
  final emitterMult = <String, double>{};
  final linkById = <String, HLink>{};
  final linksAt = <String, List<HLink>>{};

  /// Wanted status of each link (schedules and controls); absent = its own.
  final wanted = <String, bool>{};
  final closedByTank = <String>{};
  final firedTime = <int>{};
  Map<String, double>? warm;

  static const double _eps = 1e-6;

  EpsResult run() {
    for (final l in net.links) {
      baseKind[l.id] = l.kind;
      linkById[l.id] = l;
      (linksAt[l.from] ??= []).add(l);
      (linksAt[l.to] ??= []).add(l);
    }
    for (final n in net.nodes.values) {
      baseDemand[n.id] = n.demand;
      baseEmitterCount[n.id] = n.emitterCount;
      final em = n.emitter;
      if (em != null) baseEmitter[n.id] = em;
    }
    for (final d in demandSchedules) {
      if (net.nodes.containsKey(d.nodeId)) {
        (demandOn[d.nodeId] ??= []).add(d);
      } else {
        res.messages.add('eps_unknown_node:${d.nodeId}');
      }
    }
    for (final t in tankSpecs) {
      final node = net.nodes[t.nodeId];
      if (node == null) {
        res.messages.add('eps_unknown_node:${t.nodeId}');
        continue;
      }
      node.kind = HNodeKind.reservoir;
      final s = _TankState(t, node, t.bottomElevation ?? node.elevation);
      s.volume = t.volumeAt(t.initialLevel.clamp(t.minLevel, t.maxLevel));
      s.level = t.levelAt(s.volume);
      s.wasFull = s.full;
      s.wasEmpty = s.empty;
      tanks.add(s);
      res.tankLevels[t.nodeId] = [];
      res.tankVolumes[t.nodeId] = [];
    }
    for (final s in schedules) {
      if (!linkById.containsKey(s.linkId)) res.messages.add('eps_unknown_link:${s.linkId}');
    }
    for (final c in controls) {
      if (!linkById.containsKey(c.linkId)) res.messages.add('eps_unknown_link:${c.linkId}');
      if (c.tankId != null && !tanks.any((t) => t.spec.nodeId == c.tankId)) res.messages.add('eps_unknown_node:${c.tankId}');
    }
    for (final l in net.links) {
      if (l.kind == HLinkKind.pump) res.pumps[l.id] = EpsPumpEnergy(l.id);
    }

    var t = 0.0;
    final end = math.max(o.duration, 0.0);
    while (true) {
      _apply(t);
      final r = _solve(t);
      _record(t, r);
      if (t >= end - _eps) break;
      final flows = _tankFlows(r);
      final dt = _stepLength(t, end, flows);
      final powers = _powers(r);
      List<double> qEnd = flows;
      Map<String, double> pEnd = powers;
      if (o.integration == EpsIntegration.heun) {
        final saved = [for (final s in tanks) s.volume];
        for (var i = 0; i < tanks.length; i++) {
          _setVolume(tanks[i], saved[i] + flows[i] * dt);
        }
        final r2 = _solveFixed();
        if (!r2.converged) _notConverged(t + dt);
        qEnd = _tankFlows(r2);
        pEnd = _powers(r2);
        for (var i = 0; i < tanks.length; i++) {
          _setVolume(tanks[i], saved[i]);
        }
      }
      _energy(t, dt, r, powers, pEnd);
      for (var i = 0; i < tanks.length; i++) {
        final s = tanks[i];
        final q = o.integration == EpsIntegration.heun ? 0.5 * (flows[i] + qEnd[i]) : flows[i];
        _setVolume(s, s.volume + q * dt);
      }
      t += dt;
      if ((t - end).abs() < _eps) t = end;
      for (final s in tanks) {
        if (s.full && !s.wasFull) {
          (res.tankFullTimes[s.spec.nodeId] ??= []).add(t);
          final m = 'eps_tank_full:${s.spec.nodeId}';
          if (!res.messages.contains(m)) res.messages.add(m);
        }
        if (s.empty && !s.wasEmpty) {
          (res.tankEmptyTimes[s.spec.nodeId] ??= []).add(t);
          final m = 'eps_tank_empty:${s.spec.nodeId}';
          if (!res.messages.contains(m)) res.messages.add(m);
        }
        s.wasFull = s.full;
        s.wasEmpty = s.empty;
      }
    }
    return res;
  }

  void _setVolume(_TankState s, double v) {
    s.volume = v.clamp(s.vMin, s.vMax);
    if ((s.volume - s.vMax).abs() <= s.tol) s.volume = s.vMax;
    if ((s.volume - s.vMin).abs() <= s.tol) s.volume = s.vMin;
    s.level = s.spec.levelAt(s.volume);
  }

  /// Patterns, schedules and controls in force at [t].
  void _apply(double t) {
    for (final n in net.nodes.values) {
      final ds = demandOn[n.id];
      final on = ds == null || ds.any((d) => d.onAt(t));
      n.emitterCount = on ? baseEmitterCount[n.id]! : 0;
      final base = baseDemand[n.id] ?? 0;
      if (base != 0) n.demand = on ? base * ((o.demandPatterns[n.id] ?? o.defaultDemandPattern)?.at(t) ?? 1) : 0;
      final em = baseEmitter[n.id];
      if (em != null) {
        final m = (o.emitterPatterns[n.id] ?? o.defaultEmitterPattern)?.at(t) ?? 1;
        if (emitterMult[n.id] != m) {
          emitterMult[n.id] = m;
          n.emitter = m == 1 ? em : EmitterCurve(k: em.k * m, x: em.x, radiusA: em.radiusA, radiusB: em.radiusB);
        }
      }
    }
    for (final s in schedules) {
      if (!linkById.containsKey(s.linkId)) continue;
      final st = s.openAt(t);
      if (st != null) wanted[s.linkId] = st;
    }
    for (var i = 0; i < controls.length; i++) {
      final c = controls[i];
      if (!linkById.containsKey(c.linkId)) continue;
      switch (c.kind) {
        case EpsControlKind.levelBelow:
        case EpsControlKind.levelAbove:
          final s = _tank(c.tankId);
          if (s == null) continue;
          final hit = c.kind == EpsControlKind.levelBelow ? s.level <= c.level + 1e-6 : s.level >= c.level - 1e-6;
          if (hit) wanted[c.linkId] = c.open;
        case EpsControlKind.time:
          if (!firedTime.contains(i) && t >= c.time - _eps) {
            firedTime.add(i);
            wanted[c.linkId] = c.open;
          }
        case EpsControlKind.clockTime:
          // fires when the clock passes its hour, between the last step and this one
          final occ = _nextClock(c, prevT);
          if (occ <= t + _eps) wanted[c.linkId] = c.open;
      }
    }
    prevT = t;
  }

  /// Time of the last call of [_apply] (the clock controls fire on crossing).
  double prevT = -1;

  /// First time after [t] (s) at which the clock reads the hour of [c].
  double _nextClock(EpsControl c, double t) {
    final start = o.startHour * 3600;
    final k = ((t + start - c.time) / 86400 + 1e-9).floor() + 1;
    var occ = c.time - start + k * 86400;
    if (occ - 86400 > t + _eps) occ -= 86400;
    return occ;
  }

  _TankState? _tank(String? id) {
    for (final s in tanks) {
      if (s.spec.nodeId == id) return s;
    }
    return null;
  }

  /// Pumps off for the step because they have nothing to deliver.
  final idlePumps = <String>{};

  void _setKinds() {
    for (final l in net.links) {
      final base = baseKind[l.id]!;
      final w = wanted[l.id];
      final open = (w ?? base != HLinkKind.closed) && !closedByTank.contains(l.id) && !idlePumps.contains(l.id);
      l.kind = open ? (base == HLinkKind.closed ? HLinkKind.device : base) : HLinkKind.closed;
    }
    for (final s in tanks) {
      s.node.fixedHead = s.bottom + s.level;
    }
  }

  /// Solves at [t] with the tanks as fixed heads; a full tank closes the
  /// links that would overfill it, an empty one those that would drain it
  /// (EPANET), reopened when the heads turn the flow the allowed way. A
  /// pump with nothing to deliver (every zone off) makes the steady solver
  /// cycle at its shutoff head: when a solve fails, the pumps without flow
  /// are off for the step.
  NetworkResult _solve(double t) {
    closedByTank.clear();
    idlePumps.clear();
    if (!_hasSink()) {
      for (final l in net.links) {
        if (baseKind[l.id] == HLinkKind.pump) idlePumps.add(l.id);
      }
    }
    NetworkResult? r;
    for (var iter = 0; iter < 8; iter++) {
      r = _solveFixed();
      var changed = false;
      if (!r.converged) {
        for (final l in net.links) {
          if (l.kind == HLinkKind.pump && !idlePumps.contains(l.id) && (r.links[l.id]?.flow ?? 0).abs() <= 1e-6) {
            idlePumps.add(l.id);
            changed = true;
          }
        }
      }
      for (final s in tanks) {
        if (!s.full && !s.empty) continue;
        final id = s.node.id;
        final ht = s.bottom + s.level;
        for (final l in linksAt[id] ?? const <HLink>[]) {
          final lr = r.links[l.id];
          if (lr == null) continue;
          final into = l.to == id ? lr.flow : -lr.flow;
          final other = l.to == id ? l.from : l.to;
          final ho = r.nodes[other]?.head ?? ht;
          if (!closedByTank.contains(l.id)) {
            if ((s.full && into > 1e-9) || (s.empty && into < -1e-9)) {
              closedByTank.add(l.id);
              changed = true;
            }
          } else if (baseKind[l.id] != HLinkKind.pump) {
            // a closed pipe reopens when the heads would move water the allowed way
            if ((s.full && ho < ht - 1e-6) || (s.empty && ho > ht + 1e-6)) {
              closedByTank.remove(l.id);
              changed = true;
            }
          }
        }
      }
      if (!changed) break;
    }
    if (!r!.converged) _notConverged(t);
    warm = {for (final e in r.links.entries) e.key: e.value.flow};
    return r;
  }

  /// Whether water can leave the network anywhere: a demand, an emitter, or
  /// a second fixed head (reservoir or tank) for a pump to deliver into.
  bool _hasSink() {
    var fixed = 0;
    for (final n in net.nodes.values) {
      if (n.kind == HNodeKind.reservoir) {
        fixed++;
      } else if (n.demand > 0 || (n.emitter != null && n.emitterCount > 0)) {
        return true;
      }
    }
    return fixed >= 2;
  }

  NetworkResult _solveFixed() {
    _setKinds();
    return net.solve(initialFlows: warm);
  }

  void _notConverged(double t) {
    res.converged = false;
    final m = 'eps_not_converged:${t.round()}';
    if (!res.messages.contains(m)) res.messages.add(m);
  }

  /// Flow of link [l]: none when it is closed (the steady solver lets a
  /// closed link pass a trickle, ΔH/10⁸, that would add up over the hours).
  double _flow(NetworkResult r, HLink l) => l.kind == HLinkKind.closed ? 0.0 : (r.links[l.id]?.flow ?? 0);

  /// Net inflow (m³/s) of every tank.
  List<double> _tankFlows(NetworkResult r) => [
    for (final s in tanks)
      (linksAt[s.node.id] ?? const <HLink>[]).fold(0.0, (q, l) {
        final f = _flow(r, l);
        return q + (l.to == s.node.id ? f : -f);
      }),
  ];

  /// Length of the step from [t]: the hydraulic step, cut at the next
  /// pattern, schedule or time control, when a tank fills or empties or
  /// reaches the level of a control (EPANET).
  double _stepLength(double t, double end, List<double> flows) {
    var next = end;
    void cut(double v) {
      if (v > t + _eps && v < next) next = v;
    }

    final h = o.hydraulicStep > 0 ? o.hydraulicStep : end;
    cut(((t / h) + 1e-9).floor() * h + h);
    for (final p in {...o.demandPatterns.values, ...o.emitterPatterns.values, ?o.defaultDemandPattern, ?o.defaultEmitterPattern}) {
      cut(p.nextChange(t));
    }
    for (final s in schedules) {
      if (linkById.containsKey(s.linkId)) cut(s.nextChange(t));
    }
    for (final d in demandSchedules) {
      if (demandOn.containsKey(d.nodeId)) cut(d.nextChange(t));
    }
    for (var i = 0; i < controls.length; i++) {
      final c = controls[i];
      if (!linkById.containsKey(c.linkId)) continue;
      switch (c.kind) {
        case EpsControlKind.time:
          cut(c.time);
        case EpsControlKind.clockTime:
          cut(_nextClock(c, t));
        case EpsControlKind.levelBelow:
        case EpsControlKind.levelAbove:
          final s = _tank(c.tankId);
          if (s == null) continue;
          final q = flows[tanks.indexOf(s)];
          final vx = s.spec.volumeAt(c.level);
          if (q > 1e-12 && s.volume < vx - s.tol) cut(t + (vx - s.volume) / q);
          if (q < -1e-12 && s.volume > vx + s.tol) cut(t + (s.volume - vx) / -q);
      }
    }
    for (var i = 0; i < tanks.length; i++) {
      final s = tanks[i], q = flows[i];
      if (q > 1e-12 && !s.full) cut(t + (s.vMax - s.volume) / q);
      if (q < -1e-12 && !s.empty) cut(t + (s.volume - s.vMin) / -q);
    }
    return next - t;
  }

  /// Shaft power (kW) of every pump: ρ·g·Q·H/η. A pump counts as running
  /// above 0.01 L/s (not against a closed link, which passes a trickle).
  Map<String, double> _powers(NetworkResult r) {
    final out = <String, double>{};
    for (final id in res.pumps.keys) {
      final lr = r.links[id];
      final on = linkById[id]!.kind == HLinkKind.pump && lr != null && lr.flow > 1e-5 && lr.pumpHead > 0;
      final eff = (o.pumpEfficiency[id] ?? o.defaultEfficiency).clamp(0.05, 1.0);
      out[id] = on ? waterDensity * gravity * lr.flow * lr.pumpHead / eff / 1000 : 0.0;
    }
    return out;
  }

  void _energy(double t, double dt, NetworkResult r, Map<String, double> p0, Map<String, double> p1) {
    final heun = o.integration == EpsIntegration.heun;
    final tariff = o.tariff;
    final hour = ((o.startHour + (t + dt / 2) / 3600) % 24 + 24) % 24;
    final price = tariff == null ? 0.0 : tariff(hour);
    for (final e in res.pumps.values) {
      final p = heun ? 0.5 * (p0[e.linkId]! + p1[e.linkId]!) : p0[e.linkId]!;
      final kwh = p * dt / 3600;
      e.energyKwh += kwh;
      e.cost += kwh * price;
      final lr = r.links[e.linkId];
      if (p0[e.linkId]! > 0 && lr != null) {
        e.volume += lr.flow * dt;
        e.hoursOn += dt / 3600;
      }
      e.maxPowerKw = math.max(e.maxPowerKw, p0[e.linkId]!);
    }
  }

  void _record(double t, NetworkResult r) {
    res.times.add(t);
    for (final s in tanks) {
      res.tankLevels[s.spec.nodeId]!.add(s.level);
      res.tankVolumes[s.spec.nodeId]!.add(s.volume);
    }
    final rn = o.recordNodes;
    for (final e in r.nodes.entries) {
      if (rn != null && !rn.contains(e.key)) continue;
      (res.nodeHeads[e.key] ??= []).add(e.value.head);
      (res.nodePressures[e.key] ??= []).add(e.value.pressure);
    }
    final rl = o.recordLinks;
    for (final l in net.links) {
      if (rl != null && !rl.contains(l.id)) continue;
      (res.linkFlows[l.id] ??= []).add(_flow(r, l));
      (res.linkOpen[l.id] ??= []).add(l.kind != HLinkKind.closed);
    }
    final p = _powers(r);
    for (final e in res.pumps.values) {
      e.power.add(p[e.linkId]!);
    }
  }
}
