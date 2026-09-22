/// Pump curves, system curves and operating points.
library;

import 'dart:math' as math;

import '../units.dart';

/// Quadratic pump curve H = a·Q² + b·Q + c (H metres, Q m³/s).
class PumpCurve {
  const PumpCurve({required this.a, required this.b, required this.c, this.speedRatio = 1});
  final double a;
  final double b;
  final double c;

  /// Relative speed ω (affinity laws): H(Q) = ω²·Hbase(Q/ω).
  final double speedRatio;

  double head(double q) {
    final w = speedRatio;
    final qq = q / w;
    return w * w * (a * qq * qq + b * qq + c);
  }

  double get shutoffHead => head(0);

  /// dH/dQ (negative on a normal curve).
  double gradient(double q) {
    final w = speedRatio;
    final qq = q / w;
    return w * (2 * a * qq + b);
  }

  /// Maximum flow where head reaches zero (runout), if any.
  double get runoutFlow {
    if (a == 0) return b < 0 ? -c / b * speedRatio : double.infinity;
    final disc = b * b - 4 * a * c;
    if (disc < 0) return double.infinity;
    final r1 = (-b - math.sqrt(disc)) / (2 * a);
    final r2 = (-b + math.sqrt(disc)) / (2 * a);
    final roots = [r1, r2].where((r) => r > 0).toList()..sort();
    return roots.isEmpty ? double.infinity : roots.first * speedRatio;
  }

  PumpCurve withSpeed(double ratio) => PumpCurve(a: a, b: b, c: c, speedRatio: ratio);

  /// Least-squares quadratic fit of (Q, H) points (≥ 3 points; 2 points give a
  /// linear curve; 1 point gives EPANET-style 3-point synthetic curve).
  static PumpCurve fit(List<(double, double)> points) {
    final pts = points.where((p) => p.$1 >= 0 && p.$2 >= 0).toList();
    if (pts.isEmpty) return const PumpCurve(a: 0, b: 0, c: 0);
    if (pts.length == 1) {
      // EPANET convention: shutoff 1.33·H at 0, runout 2·Q at 0 head.
      final (q, h) = pts.first;
      return fit([(0, 1.33 * h), (q, h), (2 * q, 0)]);
    }
    if (pts.length == 2) {
      final (q1, h1) = pts[0];
      final (q2, h2) = pts[1];
      final b = (h2 - h1) / (q2 - q1);
      return PumpCurve(a: 0, b: b, c: h1 - b * q1);
    }
    // Normal equations for y = a x² + b x + c
    double s0 = pts.length.toDouble(), s1 = 0, s2 = 0, s3 = 0, s4 = 0, t0 = 0, t1 = 0, t2 = 0;
    for (final (x, y) in pts) {
      s1 += x;
      s2 += x * x;
      s3 += x * x * x;
      s4 += x * x * x * x;
      t0 += y;
      t1 += x * y;
      t2 += x * x * y;
    }
    final m = [
      [s4, s3, s2, t2],
      [s3, s2, s1, t1],
      [s2, s1, s0, t0],
    ];
    final sol = _solve3(m);
    return PumpCurve(a: sol[0], b: sol[1], c: sol[2]);
  }

  static List<double> _solve3(List<List<double>> m) {
    for (var i = 0; i < 3; i++) {
      var piv = i;
      for (var r = i + 1; r < 3; r++) {
        if (m[r][i].abs() > m[piv][i].abs()) piv = r;
      }
      final tmp = m[i];
      m[i] = m[piv];
      m[piv] = tmp;
      if (m[i][i].abs() < 1e-18) continue;
      for (var r = 0; r < 3; r++) {
        if (r == i) continue;
        final f = m[r][i] / m[i][i];
        for (var c = i; c < 4; c++) {
          m[r][c] -= f * m[i][c];
        }
      }
    }
    return [for (var i = 0; i < 3; i++) m[i][i].abs() < 1e-18 ? 0 : m[i][3] / m[i][i]];
  }

  Map<String, dynamic> toJson() => {'a': a, 'b': b, 'c': c, 'w': speedRatio};
  static PumpCurve fromJson(Map<String, dynamic> j) => PumpCurve(
    a: (j['a'] as num).toDouble(),
    b: (j['b'] as num).toDouble(),
    c: (j['c'] as num).toDouble(),
    speedRatio: (j['w'] as num?)?.toDouble() ?? 1,
  );
}

/// System curve H = static + k·Q^n.
class SystemCurve {
  const SystemCurve({required this.staticHead, required this.k, this.n = 1.852});
  final double staticHead;
  final double k;
  final double n;
  double head(double q) => staticHead + k * math.pow(q.abs(), n);
}

/// Intersection of pump and system curves by bisection. Returns (Q, H) or null.
(double, double)? operatingPoint(PumpCurve pump, SystemCurve system, {double qMax = 1}) {
  double f(double q) => pump.head(q) - system.head(q);
  var lo = 0.0, hi = qMax;
  if (f(lo) < 0) return null; // pump cannot overcome static head
  // Expand hi until f(hi) < 0
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

/// Atmospheric pressure head (m of water) at [elevation] metres above sea
/// level, standard atmosphere: 10.33 m at sea level, about 9.2 m at 1000 m.
double atmosphericHead(double elevation) => 10.33 * math.pow(1 - 2.25577e-5 * elevation.clamp(-500.0, 8000.0), 5.25588).toDouble();

/// Vapour pressure head of water at 20 °C (m).
const vapourHead20C = 0.24;

/// Allowance for the NPSH a surface pump requires plus a safety margin (m).
const suctionNpshAllowance = 3.0;

/// Practical suction lift limit (m) of a surface pump at [elevation]: the
/// atmospheric head minus the vapour pressure and the NPSH allowance
/// (about 7.1 m at sea level). The suction lift is the negative pressure
/// head at the pump inlet: static lift plus the losses of the suction pipe.
double maxSuctionLift(double elevation) => atmosphericHead(elevation) - vapourHead20C - suctionNpshAllowance;

/// Hydraulic power (W) = ρ·g·Q·H; shaft power divides by efficiency.
double hydraulicPower({required double flow, required double head}) =>
    waterDensity * gravity * flow * head;

double shaftPower({required double flow, required double head, double efficiency = 0.7}) =>
    hydraulicPower(flow: flow, head: head) / math.max(efficiency, 0.05);

/// Capital recovery factor for interest [rate] (fraction) over [years].
double capitalRecoveryFactor(double rate, int years) {
  if (years <= 0) return 1;
  if (rate <= 0) return 1 / years;
  final f = math.pow(1 + rate, years).toDouble();
  return rate * f / (f - 1);
}

/// Annual energy cost (currency) for a duty point.
double annualEnergyCost({
  required double flow,
  required double head,
  required double hoursPerYear,
  required double costPerKwh,
  double pumpEfficiency = 0.7,
}) =>
    shaftPower(flow: flow, head: head, efficiency: pumpEfficiency) / 1000 * hoursPerYear * costPerKwh;
