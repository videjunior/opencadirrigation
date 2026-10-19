/// Minor (local) losses in fittings and valves.
library;

import 'dart:math' as math;

import '../units.dart';
import 'friction.dart';

/// Typical resistance coefficients K (velocity-head form) from Crane TP-410
/// and irrigation design references.
class FittingK {
  static const double elbow90Standard = 0.75;
  static const double elbow90LongRadius = 0.35;
  static const double elbow45 = 0.35;
  static const double teeRun = 0.4;
  static const double teeBranch = 1.5;
  static const double cross = 2.0;
  static const double gateValveOpen = 0.15;
  static const double globeValveOpen = 8.0;
  static const double ballValveOpen = 0.05;
  static const double butterflyValveOpen = 0.6;
  static const double checkValveSwing = 2.0;
  static const double reducerGradual = 0.3;
  static const double enlargementSudden = 1.0;
  static const double entranceSharp = 0.5;
  static const double entranceRounded = 0.05;
  static const double exit = 1.0;
  static const double strainerScreen = 1.5;
  static const double waterMeter = 7.0;
  static const double emitterBarbInline = 0.4; // per emitter, default Kd
}

/// Minor loss hm = K·V²/(2g).
double minorLoss({required double k, required double flow, required double diameter}) {
  final v = velocity(flow: flow.abs(), diameter: diameter);
  final h = k * v * v / (2 * gravity);
  return flow < 0 ? -h : h;
}

/// Flow-form minor loss coefficient m so that hm = m·Q² (EPANET style).
double minorLossFlowCoefficient({required double k, required double diameter}) {
  final a = math.pi * diameter * diameter / 4;
  return k / (2 * gravity * a * a);
}

/// Equivalent pipe length for a fitting: Le = K·D/f.
double equivalentLength({required double k, required double diameter, double f = 0.02}) =>
    k * diameter / f;

/// Head loss law of a valve/device: h = K·Q^n + C with Q in m³/s.
class DeviceLossCurve {
  const DeviceLossCurve({required this.k, this.n = 2, this.c = 0});
  final double k;
  final double n;
  final double c;

  double loss(double flow) {
    if (flow == 0) return c > 0 ? 0 : 0;
    final h = k * math.pow(flow.abs(), n) + c;
    return flow < 0 ? -h : h;
  }

  /// dh/dQ, guarded against zero flow.
  double gradient(double flow) {
    final q = math.max(flow.abs(), 1e-9);
    return math.max(n * k * math.pow(q, n - 1), 1e-9);
  }

  /// Least-squares fit of h = K·Q^n from (Q, h) samples (log-log regression).
  static DeviceLossCurve fit(List<(double, double)> samples) {
    final pts = samples.where((s) => s.$1 > 0 && s.$2 > 0).toList();
    if (pts.length < 2) {
      if (pts.length == 1) return DeviceLossCurve(k: pts.first.$2 / math.pow(pts.first.$1, 2));
      return const DeviceLossCurve(k: 0);
    }
    var sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
    for (final (q, h) in pts) {
      final x = math.log(q), y = math.log(h);
      sx += x;
      sy += y;
      sxx += x * x;
      sxy += x * y;
    }
    final n = pts.length;
    final denom = n * sxx - sx * sx;
    if (denom.abs() < 1e-12) {
      // every sample at the same flow: no exponent to fit, h = K·Q² through
      // their mean (the slope was 0/0, a NaN curve)
      final q = math.exp(sx / n), h = math.exp(sy / n);
      return DeviceLossCurve(k: h / (q * q));
    }
    final slope = (n * sxy - sx * sy) / denom;
    final intercept = (sy - slope * sx) / n;
    return DeviceLossCurve(k: math.exp(intercept), n: slope);
  }

  /// Build from a nominal K coefficient and diameter (h = K V²/2g).
  static DeviceLossCurve fromK(double k, double diameter) =>
      DeviceLossCurve(k: minorLossFlowCoefficient(k: k, diameter: diameter), n: 2);

  Map<String, dynamic> toJson() => {'k': k, 'n': n, 'c': c};
  static DeviceLossCurve fromJson(Map<String, dynamic> j) => DeviceLossCurve(
    k: (j['k'] as num).toDouble(),
    n: (j['n'] as num?)?.toDouble() ?? 2,
    c: (j['c'] as num?)?.toDouble() ?? 0,
  );
}
