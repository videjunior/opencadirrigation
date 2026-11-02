/// Pump curves, system curves and operating points.
library;

import 'dart:math' as math;

import '../units.dart';

/// Pump curve H(Q) (H metres, Q m³/s): the parabola H = a·Q² + b·Q + c, or,
/// when a parabola cannot stand for the manufacturer's points, the monotone
/// cubic through them ([throughPoints], see [fit]).
class PumpCurve {
  const PumpCurve({required this.a, required this.b, required this.c, this.speedRatio = 1}) : _q = null, _h = null, _d = null, _tail = 0;

  const PumpCurve._points(this.a, this.b, this.c, this.speedRatio, this._q, this._h, this._d, this._tail);

  /// The parabola: the curve itself, or for a curve [throughPoints] the
  /// non-rising least-squares parabola of its points, the closed form the
  /// transient analysis linearises around the operating point.
  final double a;
  final double b;
  final double c;

  /// Relative speed ω (affinity laws): H(Q) = ω²·Hbase(Q/ω).
  final double speedRatio;

  /// Knots of the monotone cubic (flows from the smallest, heads never
  /// rising, slopes) at full speed; null for a parabola.
  final List<double>? _q;
  final List<double>? _h;
  final List<double>? _d;

  /// Slope (m per m³/s, negative) beyond the last knot, where the curve runs
  /// on straight to zero head.
  final double _tail;

  /// Whether the curve goes through the manufacturer's points (monotone
  /// piecewise cubic) instead of being a parabola.
  bool get throughPoints => _q != null;

  /// The (Q, H) knots at full speed of a curve [throughPoints] (empty for a parabola).
  List<(double, double)> get knots => [for (var i = 0; i < (_q?.length ?? 0); i++) (_q![i], _h![i])];

  double head(double q) {
    final w = speedRatio;
    final qq = q / w;
    if (_q == null) return w * w * (a * qq * qq + b * qq + c);
    return w * w * _cubic(qq).$1;
  }

  /// Head at zero flow.
  double get shutoffHead => head(0);

  /// dH/dQ (negative on a normal curve).
  double gradient(double q) {
    final w = speedRatio;
    final qq = q / w;
    if (_q == null) return w * (2 * a * qq + b);
    return w * _cubic(qq).$2;
  }

  /// Flow of the highest head: 0 for a curve that only falls, the top of a
  /// parabola that rises from its shutoff first.
  double get peakFlow => _q == null && a < 0 && b > 0 ? -b / (2 * a) * speedRatio : 0;

  /// Highest head the pump gives: above it no flow gets through (its check
  /// valve closes). It is the shutoff head unless a parabola rises first.
  double get maxHead => head(peakFlow);

  /// Maximum flow where head reaches zero (runout), if any.
  double get runoutFlow {
    final qs = _q;
    if (qs != null) {
      final hs = _h!;
      final n = qs.length;
      if (hs[n - 1] > 0) return _tail < 0 ? (qs[n - 1] + hs[n - 1] / -_tail) * speedRatio : double.infinity;
      // zero head at a knot or inside the piece before it
      var k = 1;
      while (k < n && hs[k] > 0) {
        k++;
      }
      if (hs[0] <= 0) return 0;
      var lo = qs[k - 1], hi = qs[k];
      for (var i = 0; i < 60; i++) {
        final mid = (lo + hi) / 2;
        if (_cubic(mid).$1 > 0) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      return (lo + hi) / 2 * speedRatio;
    }
    if (a == 0) return b < 0 ? -c / b * speedRatio : double.infinity;
    final disc = b * b - 4 * a * c;
    if (disc < 0) return double.infinity;
    final r1 = (-b - math.sqrt(disc)) / (2 * a);
    final r2 = (-b + math.sqrt(disc)) / (2 * a);
    final roots = [r1, r2].where((r) => r > 0).toList()..sort();
    return roots.isEmpty ? double.infinity : roots.first * speedRatio;
  }

  PumpCurve withSpeed(double ratio) => _q == null ? PumpCurve(a: a, b: b, c: c, speedRatio: ratio) : PumpCurve._points(a, b, c, ratio, _q, _h, _d, _tail);

  /// The parabola A·Q² + B·Q + C (actual flow, speed included) that has the
  /// head and the slope of the curve at [q]: the curve itself for a
  /// parabola; for a curve [throughPoints] its tangent there with the
  /// curvature of [a] (a pump element of the transient analysis).
  (double, double, double) localParabola(double q) {
    if (_q == null) {
      final w = speedRatio;
      return (a, b * w, c * w * w);
    }
    final g = gradient(q), h = head(q);
    final bb = g - 2 * a * q;
    return (a, bb, h - a * q * q - bb * q);
  }

  /// Head and slope of the monotone cubic at full-speed flow [q]: straight
  /// on with the end slopes before the first knot (back to zero flow) and
  /// beyond the last.
  (double, double) _cubic(double q) {
    final qs = _q!, hs = _h!, ds = _d!;
    final n = qs.length;
    if (q <= qs[0]) return (hs[0] + ds[0] * (q - qs[0]), ds[0]);
    if (q >= qs[n - 1]) return (hs[n - 1] + _tail * (q - qs[n - 1]), _tail);
    // the piece holding q (binary search)
    var lo = 0, hi = n - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (qs[mid] <= q) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final h = qs[hi] - qs[lo];
    final t = (q - qs[lo]) / h, t2 = t * t, t3 = t2 * t;
    final y0 = hs[lo], y1 = hs[hi], m0 = ds[lo] * h, m1 = ds[hi] * h;
    final y = (2 * t3 - 3 * t2 + 1) * y0 + (t3 - 2 * t2 + t) * m0 + (-2 * t3 + 3 * t2) * y1 + (t3 - t2) * m1;
    final dy = ((6 * t2 - 6 * t) * y0 + (3 * t2 - 4 * t + 1) * m0 + (-6 * t2 + 6 * t) * y1 + (3 * t2 - 2 * t) * m1) / h;
    return (y, dy);
  }

  /// Largest share of the shutoff head a parabola may rise above it
  /// before its top (the parabola then stands for a curve that falls).
  static const humpTolerance = 1e-3;

  /// Largest gap between a parabola and the points it stands for, as a
  /// share of the highest head: the head tolerance of acceptance grade 1B
  /// of ISO 9906 (±3 %), what a manufacturer's curve itself is good for.
  static const fitTolerance = 0.03;

  /// Pump curve of the (Q, H) points of a data sheet. One point gives the
  /// EPANET 3-point synthetic curve (shutoff 1.33·H, runout 2·Q), two a
  /// straight line, three or more the least-squares parabola when it stands
  /// for them: never rising above its shutoff head (by more than
  /// [humpTolerance]), reaching zero head before it could turn up again, and
  /// within [fitTolerance] of every point. Otherwise (a flat top that the
  /// parabola overshoots into a hump, a curve the parabola cannot follow)
  /// the curve goes through the points: the monotone piecewise cubic of
  /// Fritsch & Carlson (1980), "Monotone piecewise cubic interpolation",
  /// SIAM J. Numer. Anal. 17(2), with the slopes of Fritsch & Butland
  /// (1984), straight on beyond the last point. Heads that rise with the
  /// flow (the unstable left part of some curves) are held at the top
  /// first: a pump runs on the falling part of its curve.
  static PumpCurve fit(List<(double, double)> points) {
    // points at the same flow (typed twice, or two readings) become one at
    // their mean head: two of them made the 2-point slope infinite (NaN curve)
    final byFlow = <double, List<double>>{};
    for (final (q, h) in points) {
      if (q.isFinite && h.isFinite && q >= 0 && h >= 0) (byFlow[q] ??= []).add(h);
    }
    final pts = [for (final e in byFlow.entries) (e.key, e.value.reduce((a, b) => a + b) / e.value.length)]..sort((a, b) => a.$1.compareTo(b.$1));
    if (pts.isEmpty) return const PumpCurve(a: 0, b: 0, c: 0);
    if (pts.length == 1) {
      // EPANET convention: shutoff 1.33·H at 0, runout 2·Q at 0 head.
      final (q, h) = pts.first;
      // a shutoff head alone gives no flow to build on: a flat curve
      if (q <= 0) return PumpCurve(a: 0, b: 0, c: h);
      return fit([(0, 1.33 * h), (q, h), (2 * q, 0)]);
    }
    if (pts.length == 2) {
      final (q1, h1) = pts[0];
      final (q2, h2) = pts[1];
      final b = (h2 - h1) / (q2 - q1);
      return PumpCurve(a: 0, b: b, c: h1 - b * q1);
    }
    final parabola = _leastSquares(pts);
    if (_standsFor(parabola, pts)) return parabola;
    return _monotoneCubic(pts);
  }

  /// Least-squares parabola y = a x² + b x + c of [pts] (normal equations).
  static PumpCurve _leastSquares(List<(double, double)> pts) {
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

  /// Whether parabola [p] stands for the points [pts] (see [fit]).
  static bool _standsFor(PumpCurve p, List<(double, double)> pts) {
    final top = pts.fold(p.c, (m, e) => math.max(m, e.$2));
    if (!(top > 0) || !p.a.isFinite || !p.b.isFinite || !p.c.isFinite) return false;
    if (p.a < 0) {
      if (p.b > 0 && p.b * p.b / (-4 * p.a) > humpTolerance * math.max(p.c, 1e-9)) return false;
    } else if (p.a > 0) {
      // a parabola turning up: only while it reaches zero head first
      if (!(p.b < 0) || p.c - p.b * p.b / (4 * p.a) > 0) return false;
    } else if (p.b > 0) {
      return false;
    }
    for (final (q, h) in pts) {
      if ((p.head(q) - h).abs() > fitTolerance * top) return false;
    }
    return true;
  }

  /// The monotone cubic through [pts] (flows increasing, at least two),
  /// rising heads held at the top that follows them.
  static PumpCurve _monotoneCubic(List<(double, double)> pts) {
    final n = pts.length;
    final q = [for (final p in pts) p.$1];
    final h = [for (final p in pts) p.$2];
    for (var i = n - 2; i >= 0; i--) {
      h[i] = math.max(h[i], h[i + 1]);
    }
    final d = monotoneSlopes(q, h);
    // straight on beyond the last point with its slope; a curve that ends
    // flat falls with its mean slope (or to zero head at twice its flow)
    var tail = d[n - 1];
    if (!(tail < 0)) {
      final mean = (h[n - 1] - h[0]) / (q[n - 1] - q[0]);
      tail = mean < 0 ? mean : (h[n - 1] > 0 && q[n - 1] > 0 ? -h[n - 1] / q[n - 1] : 0.0);
    }
    // the parabola for the closed-form uses: never rising
    var p = _leastSquares(pts);
    if (!(p.a <= 0 && p.b <= 0)) {
      p = _leastSquaresNoLinear(pts);
      if (!(p.a <= 0)) p = PumpCurve(a: 0, b: tail, c: h[0] - tail * q[0]);
    }
    return PumpCurve._points(p.a, p.b, p.c, 1, q, h, d, tail);
  }

  /// Least-squares y = a x² + c of [pts] (no linear term).
  static PumpCurve _leastSquaresNoLinear(List<(double, double)> pts) {
    final n = pts.length.toDouble();
    var sx = 0.0, sxx = 0.0, sy = 0.0, sxy = 0.0;
    for (final (q, h) in pts) {
      final x = q * q;
      sx += x;
      sxx += x * x;
      sy += h;
      sxy += x * h;
    }
    final den = n * sxx - sx * sx;
    if (den.abs() < 1e-300) return PumpCurve(a: 0, b: 0, c: sy / n);
    final a = (n * sxy - sx * sy) / den;
    return PumpCurve(a: a, b: 0, c: (sy - a * sx) / n);
  }

  /// Slopes of the monotone piecewise cubic Hermite interpolant through
  /// ([x], [y]), x increasing: zero at a local extreme, else the weighted
  /// harmonic mean of the neighbouring secants (Fritsch & Butland 1984,
  /// "A method for constructing local monotone piecewise cubic
  /// interpolants", SIAM J. Sci. Stat. Comput. 5(2)), and the shape
  /// preserving three-point formula at both ends (as MATLAB's pchip).
  static List<double> monotoneSlopes(List<double> x, List<double> y) {
    final n = x.length;
    if (n < 2) return List.filled(n, 0);
    final hh = [for (var k = 0; k < n - 1; k++) x[k + 1] - x[k]];
    final del = [for (var k = 0; k < n - 1; k++) (y[k + 1] - y[k]) / hh[k]];
    if (n == 2) return [del[0], del[0]];
    final d = List<double>.filled(n, 0);
    for (var k = 1; k < n - 1; k++) {
      if (del[k - 1] * del[k] <= 0) continue;
      final w1 = 2 * hh[k] + hh[k - 1], w2 = hh[k] + 2 * hh[k - 1];
      d[k] = (w1 + w2) / (w1 / del[k - 1] + w2 / del[k]);
    }
    double end(double h0, double h1, double d0, double d1) {
      final s = ((2 * h0 + h1) * d0 - h0 * d1) / (h0 + h1);
      if (s.sign != d0.sign) return 0;
      if (d0.sign != d1.sign && s.abs() > (3 * d0).abs()) return 3 * d0;
      return s;
    }

    d[0] = end(hh[0], hh[1], del[0], del[1]);
    d[n - 1] = end(hh[n - 2], hh[n - 3], del[n - 2], del[n - 3]);
    return d;
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

  Map<String, dynamic> toJson() => {
    'a': a,
    'b': b,
    'c': c,
    'w': speedRatio,
    if (_q != null) ...{'q': _q, 'h': _h, 't': _tail},
  };
  static PumpCurve fromJson(Map<String, dynamic> j) {
    final a = (j['a'] as num).toDouble(), b = (j['b'] as num).toDouble(), c = (j['c'] as num).toDouble(), w = (j['w'] as num?)?.toDouble() ?? 1;
    final qs = j['q'] as List?, hs = j['h'] as List?;
    if (qs == null || hs == null || qs.length < 2 || qs.length != hs.length) return PumpCurve(a: a, b: b, c: c, speedRatio: w);
    final q = [for (final v in qs) (v as num).toDouble()], h = [for (final v in hs) (v as num).toDouble()];
    return PumpCurve._points(a, b, c, w, q, h, monotoneSlopes(q, h), (j['t'] as num?)?.toDouble() ?? 0);
  }
}

/// System curve H = static + k·Q^n.
class SystemCurve {
  const SystemCurve({required this.staticHead, required this.k, this.n = 1.852});
  final double staticHead;
  final double k;
  final double n;
  double head(double q) => staticHead + k * math.pow(q.abs(), n);
}

/// Intersection of pump and system curves by bisection, on the falling part
/// of the pump curve (from its top). Returns (Q, H) or null.
(double, double)? operatingPoint(PumpCurve pump, SystemCurve system, {double qMax = 1}) {
  double f(double q) => pump.head(q) - system.head(q);
  var lo = pump.peakFlow, hi = math.max(qMax, 2 * pump.peakFlow);
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

/// Margin (m) the NPSH available must keep above the required one
/// (ANSI/HI 9.6.1 recommends 0.5–1.5 m or a ratio for most services).
const npshMargin = 0.6;

/// Vapour pressure of water as a head (m) at [tempC] (Tetens' formula).
double vapourHead(double tempC) => 0.61078 * math.exp(17.27 * tempC / (tempC + 237.3)) * 1000 / (waterDensity * gravity);

/// Net positive suction head available (m) at a pump inlet of gauge
/// pressure head [inletPressure] at [elevation], water at [tempC]: the
/// atmospheric head plus the inlet pressure minus the vapour pressure.
double npshAvailable({required double inletPressure, required double elevation, double tempC = 20}) => atmosphericHead(elevation) + inletPressure - vapourHead(tempC);

/// Practical suction lift limit (m) of a surface pump at [elevation]: the
/// atmospheric head minus the vapour pressure and the NPSH allowance
/// (about 7.1 m at sea level). The suction lift is the negative pressure
/// head at the pump inlet: static lift plus the losses of the suction pipe.
double maxSuctionLift(double elevation) => atmosphericHead(elevation) - vapourHead20C - suctionNpshAllowance;

/// Hydraulic power (W) = ρ·g·Q·H; shaft power divides by efficiency.
double hydraulicPower({required double flow, required double head}) => waterDensity * gravity * flow * head;

double shaftPower({required double flow, required double head, double efficiency = 0.7}) => hydraulicPower(flow: flow, head: head) / math.max(efficiency, 0.05);

/// Capital recovery factor for interest [rate] (fraction) over [years].
double capitalRecoveryFactor(double rate, int years) {
  if (years <= 0) return 1;
  if (rate <= 0) return 1 / years;
  final f = math.pow(1 + rate, years).toDouble();
  return rate * f / (f - 1);
}

/// Annual energy cost (currency) for a duty point.
double annualEnergyCost({required double flow, required double head, required double hoursPerYear, required double costPerKwh, double pumpEfficiency = 0.7}) =>
    shaftPower(flow: flow, head: head, efficiency: pumpEfficiency) / 1000 * hoursPerYear * costPerKwh;
