/// Automatic pump selection from the mainline duty (flow and required head
/// at a water supply) against the catalog pump curves.
library;

import 'dart:math' as math;

import '../hydraulics/friction.dart';
import '../hydraulics/pump.dart';
import '../model/catalog.dart';
import '../model/entities.dart';
import '../model/project.dart';
import 'results.dart';

/// Standard IEC motor ratings (kW) with their nominal cv (hp metric).
const standardMotorsKw = <(double, double)>[(0.75, 1), (1.1, 1.5), (1.5, 2), (2.2, 3), (3, 4), (3.7, 5), (4, 5.5), (5.5, 7.5), (7.5, 10), (9.2, 12.5), (11, 15), (15, 20), (18.5, 25), (22, 30), (30, 40), (37, 50), (45, 60), (55, 75), (75, 100), (90, 125), (110, 150), (132, 180), (160, 220), (200, 270), (250, 340)];

/// Smallest standard motor whose rating covers the shaft power with the
/// service factor (default 1.15); returns (kW, cv). Null for zero power.
(double, double)? standardMotor(double shaftKw, {double serviceFactor = 1.15}) {
  if (!(shaftKw > 0)) return null;
  final need = shaftKw * serviceFactor;
  for (final m in standardMotorsKw) {
    if (m.$1 >= need - 1e-9) return m;
  }
  return standardMotorsKw.last;
}

class PumpCandidate {
  PumpCandidate({required this.spec, required this.headAtDuty, required this.margin, required this.operatingFlow, required this.operatingHead, required this.shaftPowerKw, required this.annualEnergy, required this.inRange, required this.parallelCount, this.suctionOk = true});
  final PumpSpec spec;

  /// Head the pump delivers at the duty flow (m).
  final double headAtDuty;

  /// headAtDuty − required head (m); negative = insufficient.
  final double margin;

  /// Operating point against the system curve derived from the duty.
  final double operatingFlow;
  final double operatingHead;
  final double shaftPowerKw;
  final double annualEnergy;
  final bool inRange;

  /// Pumps in parallel needed to reach the duty flow (1 = single pump).
  final int parallelCount;

  /// False for a surface pump when the water lies deeper than its
  /// practical suction lift.
  final bool suctionOk;
  bool get suitable => margin >= -1e-6 && inRange && suctionOk;
}

/// System curve H = static + k·Q^1.852 through the duty point, with the
/// static part estimated from the elevation difference and valve pressure.
SystemCurve systemCurveFromDuty({required double flow, required double head, required double staticHead}) {
  final stat = head <= 0 ? 0.0 : staticHead.clamp(0.0, head); // a negative duty head would invert the clamp range
  final k = flow > 0 ? (head - stat) / math.pow(flow, 1.852) : 0.0;
  return SystemCurve(staticHead: stat, k: k);
}

/// Ranks the catalog pumps for a duty (Q, H). [staticHead] is the static
/// lift (elevation + required valve pressure); when unknown 60 % of H is used.
/// All pump duties of a supply, one per system flow (see [worstPumpDuty]).
List<PumpDuty> pumpDuties(DesignResults r, String supplyId) {
  final out = <PumpDuty>[];
  for (final f in r.systemFlows) {
    final boost = f.devices.fold<double>(0, (sum, d) => sum + math.max(0, d.pumpHead));
    for (final d in f.supplies) {
      if (d.supplyId == supplyId) out.add(PumpDuty(supply: d, head: d.requiredHead + boost, flowName: f.name));
    }
  }
  return out;
}

/// Ranks the catalog pumps for a duty (Q, H); [otherDuties] are further
/// (flow, head) points every candidate must also satisfy (other system
/// flows): the margin reported is the smallest over all points. With
/// [requireSubmersible] (water deeper than the suction lift of a surface
/// pump, see [suctionLiftTooDeep]) only submersible pumps are suitable.
List<PumpCandidate> rankPumps(Catalog cat, {required double flow, required double head, double? staticHead, required double hoursPerYear, required double costPerKwh, int maxParallel = 3, List<(double, double)> otherDuties = const [], bool requireSubmersible = false}) {
  final out = <PumpCandidate>[];
  if (!(flow > 0) || !(head > 0)) return out; // no meaningful duty
  final sys = systemCurveFromDuty(flow: flow, head: head, staticHead: staticHead ?? 0.6 * head);
  for (final p in cat.pumps) {
    if (!p.enabled) continue;
    for (var n = 1; n <= maxParallel; n++) {
      final qEach = flow / n;
      final hAt = p.curve.head(qEach);
      var margin = hAt - head;
      var inRange = qEach >= p.minFlow - 1e-9 && qEach <= p.maxFlow + 1e-9;
      for (final (q2, h2) in otherDuties) {
        if (!(q2 > 0) || !(h2 > 0)) continue;
        final e = q2 / n;
        margin = math.min(margin, p.curve.head(e) - h2);
        inRange = inRange && e >= p.minFlow - 1e-9 && e <= p.maxFlow + 1e-9;
      }
      // operating point: n pumps in parallel → curve Q = n·q
      final parallel = _ParallelCurve(p.curve, n);
      final op = _operatingPoint(parallel, sys, qMax: math.max(flow * 3, 0.01));
      final oq = op?.$1 ?? 0, oh = op?.$2 ?? 0;
      final power = oq > 0 ? shaftPower(flow: oq, head: oh, efficiency: p.efficiency) / 1000 : 0.0;
      out.add(PumpCandidate(spec: p, headAtDuty: hAt, margin: margin, operatingFlow: oq, operatingHead: oh, shaftPowerKw: power, annualEnergy: power * hoursPerYear * costPerKwh, inRange: inRange, parallelCount: n, suctionOk: p.submersible || !requireSubmersible));
      if (margin >= 0 && inRange) break; // a single unit (or fewer units) is enough
    }
  }
  out.sort((a, b) {
    if (a.suitable != b.suitable) return a.suitable ? -1 : 1;
    final ca = a.spec.cost * a.parallelCount + a.annualEnergy * 5;
    final cb = b.spec.cost * b.parallelCount + b.annualEnergy * 5;
    return ca.compareTo(cb);
  });
  return out;
}

class _ParallelCurve {
  _ParallelCurve(this.base, this.n);
  final PumpCurve base;
  final int n;
  double head(double q) => base.head(q / n);
}

(double, double)? _operatingPoint(_ParallelCurve pump, SystemCurve system, {double qMax = 1}) {
  double f(double q) => pump.head(q) - system.head(q);
  var lo = 0.0, hi = qMax;
  if (f(lo) < 0) return null;
  var it = 0;
  while (f(hi) > 0 && it < 60) {
    hi *= 2;
    it++;
  }
  if (f(hi) > 0) return null;
  for (var i = 0; i < 100; i++) {
    final mid = (lo + hi) / 2;
    if (f(mid) > 0) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final q = (lo + hi) / 2;
  return (q, pump.head(q));
}

/// Duty for pump selection: the supply duty of one system flow plus the head
/// the pumps already present in that flow provide, i.e. the head a pump must
/// add at the source so every valve is satisfied.
class PumpDuty {
  PumpDuty({required this.supply, required this.head, required this.flowName});
  final SupplyDuty supply;
  final double head;
  final String flowName;
}

/// Pump duty with the highest head over all system flows of [supplyId].
PumpDuty? worstPumpDuty(DesignResults r, String supplyId) {
  PumpDuty? worst;
  for (final f in r.systemFlows) {
    final boost = f.devices.fold<double>(0, (sum, d) => sum + math.max(0, d.pumpHead));
    for (final d in f.supplies) {
      if (d.supplyId != supplyId) continue;
      final head = d.requiredHead + boost;
      if (worst == null || head > worst.head) worst = PumpDuty(supply: d, head: head, flowName: f.name);
    }
  }
  return worst;
}

/// Worst duty (max required head, its flow) of a supply over all system flows.
SupplyDuty? worstDuty(DesignResults r, String supplyId) {
  SupplyDuty? worst;
  for (final f in r.systemFlows) {
    for (final d in f.supplies) {
      if (d.supplyId == supplyId && (worst == null || d.requiredHead > worst.requiredHead)) worst = d;
    }
  }
  return worst;
}

/// Static lift for a supply: highest (valve elevation + required pressure)
/// minus supply water level ([SupplyDuty.elevation], the supply node lies at
/// the water surface).
double staticLift(Project project, DesignResults r, WaterSupplyEntity s, SupplyDuty duty) {
  var top = -double.infinity;
  for (final f in r.systemFlows) {
    for (final v in f.valves) {
      final z = r.zones[v.valveId]?.valveElevation ?? duty.elevation;
      top = math.max(top, z + v.requiredHead);
    }
  }
  if (!top.isFinite) return 0;
  return math.max(0, top - duty.elevation);
}

/// Whether the water of [s] lies deeper below the ground than a surface pump
/// can lift it (static part only; the suction pipe losses add to it).
/// [duty] gives the water level ([SupplyDuty.elevation]).
bool suctionLiftTooDeep(WaterSupplyEntity s, SupplyDuty duty) => -s.waterLevelOffsetM > maxSuctionLift(duty.elevation - s.waterLevelOffsetM);

/// Velocity in the delivery main at the duty, for information.
double mainVelocity(double flow, double diameter) => diameter > 0 ? velocity(flow: flow, diameter: diameter) : 0;
