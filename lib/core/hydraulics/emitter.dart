/// Emitter / sprinkler discharge laws.
library;

import 'dart:math' as math;

/// q = k·H^x with q in m³/s and H in metres of head (internal SI),
/// plus the wetted-radius law R = a·H^b.
class EmitterCurve {
  const EmitterCurve({required this.k, required this.x, this.radiusA = 0, this.radiusB = 0});

  /// Discharge coefficient (m³/s per m^x).
  final double k;

  /// Discharge exponent (0 = pressure compensating, 0.5 = orifice, 1 = laminar).
  final double x;

  /// Wetted radius coefficients (m per m^b).
  final double radiusA;
  final double radiusB;

  bool get isPressureCompensating => x < 0.1;

  double flow(double head) {
    if (head <= 0) return 0;
    return k * math.pow(head, x);
  }

  double radius(double head) {
    if (head <= 0 || radiusA == 0) return 0;
    return radiusA * math.pow(head, radiusB);
  }

  /// dq/dH at the given head (guarded).
  double gradient(double head) {
    final h = math.max(head, 1e-6);
    if (x == 0) return 1e-9;
    return k * x * math.pow(h, x - 1);
  }

  /// Head that produces the given flow (inverse law).
  double headForFlow(double q) {
    if (x <= 0 || k <= 0 || q <= 0) return 0;
    return math.pow(q / k, 1 / x).toDouble();
  }

  /// Convenience: build from nominal flow at nominal head and exponent.
  static EmitterCurve fromNominal({required double flow, required double head, double x = 0.5, double radius = 0, double radiusB = 0.5}) {
    final k = flow / math.pow(head, x);
    final a = radius > 0 ? radius / math.pow(head, radiusB) : 0.0;
    return EmitterCurve(k: k, x: x, radiusA: a, radiusB: radius > 0 ? radiusB : 0);
  }

  /// Least-squares power-law fit through (head, flow) samples.
  static EmitterCurve fit(List<(double, double)> samples, {double radiusA = 0, double radiusB = 0}) {
    final pts = samples.where((s) => s.$1 > 0 && s.$2 > 0).toList();
    if (pts.isEmpty) return const EmitterCurve(k: 0, x: 0.5);
    if (pts.length == 1) return fromNominal(flow: pts.first.$2, head: pts.first.$1);
    var sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
    for (final (h, q) in pts) {
      final lx = math.log(h), ly = math.log(q);
      sx += lx;
      sy += ly;
      sxx += lx * lx;
      sxy += lx * ly;
    }
    final n = pts.length;
    final denom = n * sxx - sx * sx;
    if (denom.abs() < 1e-12) return fromNominal(flow: pts.first.$2, head: pts.first.$1);
    final slope = (n * sxy - sx * sy) / denom;
    final intercept = (sy - slope * sx) / n;
    return EmitterCurve(k: math.exp(intercept), x: slope, radiusA: radiusA, radiusB: radiusB);
  }

  /// Curve of a nozzle from the rows of its data sheet: (head m, flow m³/s)
  /// with an optional wetted radius (m) per row. Flow q = k·H^x and radius
  /// R = a·H^b are both least-squares power laws in log-log space; with a
  /// single radius the exponent [defaultRadiusB] is assumed (0.5 when the
  /// throw grows like the jet velocity). [EmitterFit.maxFlowError] and
  /// [EmitterFit.maxRadiusError] give the worst relative deviation of the
  /// rows from the fitted laws.
  static EmitterFit fitTable(List<(double, double, double?)> rows, {double defaultRadiusB = 0.5}) {
    final flows = [
      for (final r in rows)
        if (r.$1 > 0 && r.$2 > 0) (r.$1, r.$2),
    ];
    final radii = [
      for (final r in rows)
        if (r.$1 > 0 && (r.$3 ?? 0) > 0) (r.$1, r.$3!),
    ];
    final c = fit(flows);
    var a = 0.0, b = 0.0;
    if (radii.length == 1) {
      b = defaultRadiusB;
      a = radii.first.$2 / math.pow(radii.first.$1, b);
    } else if (radii.length > 1) {
      final r = fit(radii);
      a = r.k;
      b = r.x;
    }
    final curve = EmitterCurve(k: c.k, x: c.x, radiusA: a, radiusB: b);
    var qErr = 0.0, rErr = 0.0;
    for (final (h, q) in flows) {
      qErr = math.max(qErr, (curve.flow(h) - q).abs() / q);
    }
    for (final (h, r) in radii) {
      rErr = math.max(rErr, (curve.radius(h) - r).abs() / r);
    }
    return EmitterFit(curve: curve, flowRows: flows.length, radiusRows: radii.length, maxFlowError: qErr, maxRadiusError: rErr);
  }

  /// Allowable head window for a flow tolerance (fractions, e.g. 0.05 = 5 %).
  /// Returns (hMin, hMax) around [nominalHead].
  (double, double) headWindow(double nominalHead, {double below = 0.05, double above = 0.05}) {
    if (x <= 0.01) return (0, double.infinity);
    final hMin = nominalHead * math.pow(1 - below, 1 / x);
    final hMax = nominalHead * math.pow(1 + above, 1 / x);
    return (hMin, hMax);
  }

  Map<String, dynamic> toJson() => {'k': k, 'x': x, 'ra': radiusA, 'rb': radiusB};
  static EmitterCurve fromJson(Map<String, dynamic> j) =>
      EmitterCurve(k: (j['k'] as num).toDouble(), x: (j['x'] as num).toDouble(), radiusA: (j['ra'] as num?)?.toDouble() ?? 0, radiusB: (j['rb'] as num?)?.toDouble() ?? 0);
}

/// Result of [EmitterCurve.fitTable].
class EmitterFit {
  const EmitterFit({required this.curve, required this.flowRows, required this.radiusRows, required this.maxFlowError, required this.maxRadiusError});
  final EmitterCurve curve;
  final int flowRows;
  final int radiusRows;

  /// Worst relative deviation (fraction) of the rows from the fitted laws.
  final double maxFlowError;
  final double maxRadiusError;

  bool get isUsable => flowRows > 0 && curve.k > 0 && curve.x.isFinite;
}

/// Precipitation (application) rate in m/s for a sprinkler grid.
/// [flow] m³/s per sprinkler, [spacingAlong] the spacing along the lateral
/// and [spacingBetween] the perpendicular distance between laterals, in m.
/// Each sprinkler serves Sl·Sm for both square and triangular (staggered)
/// layouts, the same convention as [gridOverlapCU]; only when
/// [equilateral] is true is [spacingBetween] the side of the equilateral
/// triangle (lateral distance = Sm·sin 60°).
double precipitationRate({required double flow, required double spacingAlong, required double spacingBetween, bool equilateral = false}) {
  final area = spacingAlong * spacingBetween * (equilateral ? 0.8660254 : 1.0);
  if (area <= 0) return 0;
  return flow / area;
}

/// Converts precipitation rate m/s to mm/h.
double precipitationMmPerHour(double rateSi) => rateSi * 1000 * 3600;

/// Simulates the overlapped application depth on a grid of sprinklers with a
/// simple triangular (linear) radial distribution profile and returns the
/// Christiansen CU (%) inside one spacing cell. Useful as a coverage check.
double gridOverlapCU({required double radius, required double spacingAlong, required double spacingBetween, bool triangular = false, int samples = 24}) {
  if (radius <= 0 || spacingAlong <= 0 || spacingBetween <= 0 || samples <= 0) return 0;
  // every head that reaches the cell: up to radius/spacing rows away
  // (bounded for absurd layouts, where the overlap is uniform anyway)
  final na = math.min(40, (radius / spacingAlong).ceil()), nb = math.min(40, (radius / spacingBetween).ceil());
  final depths = <double>[];
  for (var i = 0; i < samples; i++) {
    for (var j = 0; j < samples; j++) {
      final px = (i + 0.5) / samples * spacingAlong;
      final py = (j + 0.5) / samples * spacingBetween;
      var depth = 0.0;
      for (var a = -na; a <= na + 1; a++) {
        for (var b = -nb; b <= nb + 1; b++) {
          var sx = a * spacingAlong;
          final sy = b * spacingBetween;
          if (triangular && b.isOdd) sx += spacingAlong / 2;
          final d = math.sqrt((px - sx) * (px - sx) + (py - sy) * (py - sy));
          if (d < radius) depth += 1 - d / radius;
        }
      }
      depths.add(depth);
    }
  }
  final mean = depths.reduce((a, b) => a + b) / depths.length;
  if (mean <= 0) return 0;
  final dev = depths.fold<double>(0, (s, d) => s + (d - mean).abs()) / depths.length;
  return 100 * (1 - dev / mean);
}
