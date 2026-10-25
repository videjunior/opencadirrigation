/// Calibration of the pipe roughness against field measurements: a
/// Hazen-Williams C scale per group of pipes (one global factor, or one per
/// material group; one to three parameters as a rule) fitted to measured
/// pressures and flows by weighted least squares, with the network solver in
/// the loop. Every residual is (model − measured)/σ and the objective is the
/// sum of their squares. One factor is found by golden-section search over
/// the allowed range (Kiefer 1953, "Sequential minimax search for a
/// maximum", Proc. American Mathematical Society 4); more factors by
/// Levenberg–Marquardt (Levenberg 1944, Quarterly of Applied Mathematics 2;
/// Marquardt 1963, J. SIAM 11) with a forward-difference Jacobian, the
/// Marquardt scaling of the damping and the factors kept inside the range.
/// The approximate standard errors come from s²·(JᵀJ)⁻¹ at the solution.
library;

import 'dart:math' as math;

import '../hydraulics/friction.dart';
import '../hydraulics/network.dart';
import '../model/catalog.dart';
import 'criticality.dart';
import 'network_builder.dart';

/// A measured pressure head (m) at a node; [sigma] is its standard error
/// (m), the weight of the residual.
class PressureMeasurement {
  const PressureMeasurement({required this.nodeId, required this.pressure, this.sigma = 0.5});
  final String nodeId;
  final double pressure;
  final double sigma;
}

/// A measured flow (m³/s, positive from the link's start to its end) in a
/// link; [sigma] = 0 takes 2 % of the reading, at least 0.1 L/s.
class FlowMeasurement {
  const FlowMeasurement({required this.linkId, required this.flow, this.sigma = 0});
  final String linkId;
  final double flow;
  final double sigma;
}

/// Limits of [calibrateRoughness].
class CalibrationOptions {
  const CalibrationOptions({this.minScale = 0.3, this.maxScale = 1.5, this.tolerance = 1e-6, this.maxIterations = 80});

  /// Range of every factor.
  final double minScale;
  final double maxScale;

  /// Width of the final golden-section interval, or relative decrease of the
  /// objective that ends Levenberg–Marquardt.
  final double tolerance;
  final int maxIterations;
}

enum MeasurementKind { pressure, flow }

/// A measurement against the model before and after the calibration.
class CalibrationResidual {
  CalibrationResidual({required this.id, required this.kind, required this.measured, required this.before, required this.after, required this.sigma});

  /// Node (pressure) or link (flow) id.
  final String id;
  final MeasurementKind kind;
  final double measured;
  final double before;
  final double after;
  final double sigma;
  double get residual => after - measured;

  Map<String, dynamic> toJson() => {'id': id, 'kind': kind.name, 'm': measured, 'b': before, 'a': after, 's': sigma};
  static CalibrationResidual fromJson(Map<String, dynamic> j) => CalibrationResidual(
    id: j['id'] as String, kind: MeasurementKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => MeasurementKind.pressure),
    measured: _d(j['m']), before: _d(j['b']), after: _d(j['a']), sigma: _d(j['s'], 1),
  );
}

/// Outcome of [calibrateRoughness].
class CalibrationResult {
  CalibrationResult({required this.scales, required this.standardErrors, required this.initialObjective, required this.objective, required this.iterations, required this.evaluations, required this.residuals, required this.converged, required this.codes});

  /// Fitted factor of every group (multiplies the C of its pipes).
  final List<double> scales;

  /// Approximate standard error of every factor (NaN when the data cannot
  /// tell: no redundancy, or a group no measurement depends on).
  final List<double> standardErrors;

  /// Σ ((model − measured)/σ)² before and after.
  final double initialObjective;
  final double objective;
  final int iterations;

  /// Network solutions used.
  final int evaluations;
  final List<CalibrationResidual> residuals;
  final bool converged;

  /// `calibration_not_hazen_williams` (the network uses Darcy-Weisbach: C
  /// plays no part), `calibration_no_measurements`, `calibration_unknown_node:<id>`,
  /// `calibration_unknown_link:<id>`, `calibration_empty_group:<g>`,
  /// `calibration_insensitive:<g>` (no measurement depends on the group: kept
  /// at 1), `calibration_at_bound:<g>`, `calibration_no_redundancy` (no more
  /// measurements than factors), `calibration_not_converged` (a solution did
  /// not converge).
  final List<String> codes;

  /// Root mean square residual of the pressures (m) and of the flows (m³/s)
  /// after the calibration.
  double get rmsePressure => _rmse(MeasurementKind.pressure);
  double get rmseFlow => _rmse(MeasurementKind.flow);
  double _rmse(MeasurementKind k) {
    final r = residuals.where((x) => x.kind == k).toList();
    return r.isEmpty ? 0 : math.sqrt(r.fold(0.0, (s, x) => s + x.residual * x.residual) / r.length);
  }

  Map<String, dynamic> toJson() => {
    'scales': scales, 'se': [for (final s in standardErrors) s.isFinite ? s : null], 'f0': initialObjective, 'f': objective, 'it': iterations, 'ev': evaluations,
    'res': residuals.map((r) => r.toJson()).toList(), 'conv': converged, 'codes': codes,
  };
  static CalibrationResult fromJson(Map<String, dynamic> j) => CalibrationResult(
    scales: [for (final s in (j['scales'] as List?) ?? []) (s as num).toDouble()], standardErrors: [for (final s in (j['se'] as List?) ?? []) (s as num?)?.toDouble() ?? double.nan],
    initialObjective: _d(j['f0']), objective: _d(j['f']), iterations: (j['it'] as num?)?.toInt() ?? 0, evaluations: (j['ev'] as num?)?.toInt() ?? 0,
    residuals: ((j['res'] as List?) ?? []).map((r) => CalibrationResidual.fromJson(r as Map<String, dynamic>)).toList(), converged: j['conv'] as bool? ?? false, codes: ((j['codes'] as List?) ?? []).cast<String>(),
  );
}

/// Groups for [calibrateRoughness] by pipe material: every pipe link of a
/// network built by the designer carries its [GLink] as tag, whose pipe spec
/// gives the material. The [maxGroups] − 1 materials with the most length
/// get a group each and the rest share the last one; links without a pipe
/// spec (tapes, devices) are not scaled. Returns the group of every link (−1
/// = not scaled) and the material names of the groups (`other` for a shared
/// group).
(Map<String, int>, List<String>) materialGroups(HydraulicNetwork net, Catalog catalog, {int maxGroups = 3}) {
  final material = <String, String>{};
  final length = <String, double>{};
  for (final l in net.links) {
    if (l.kind != HLinkKind.pipe) continue;
    final tag = l.tag;
    if (tag is! GLink || tag.tapeSpecId != null) continue;
    final spec = catalog.pipe(tag.pipeSpecId);
    if (spec == null) continue;
    material[l.id] = spec.material.name;
    length[spec.material.name] = (length[spec.material.name] ?? 0) + tag.length;
  }
  final names = length.keys.toList()..sort((a, b) => length[b]!.compareTo(length[a]!) != 0 ? length[b]!.compareTo(length[a]!) : a.compareTo(b));
  final cap = math.max(1, maxGroups);
  final groupNames = names.length <= cap ? names : [...names.take(cap - 1), 'other'];
  final groupOf = <String, int>{};
  for (final e in material.entries) {
    final i = names.indexOf(e.value);
    groupOf[e.key] = names.length <= cap ? i : math.min(i, cap - 1);
  }
  return (groupOf, groupNames);
}

/// Fits the Hazen-Williams C scale of [groups] groups of pipes of [net] to
/// the measurements (see the library comment). [groupOf] gives the group of
/// every link id (−1 or absent = not scaled); null puts every pipe in group
/// 0, one global factor. [net] is not changed: apply the factors to the pipes
/// (or, for one global factor, to DesignParameters.hazenCScale).
CalibrationResult calibrateRoughness(HydraulicNetwork net, {List<PressureMeasurement> pressures = const [], List<FlowMeasurement> flows = const [], int groups = 1, Map<String, int>? groupOf, CalibrationOptions options = const CalibrationOptions()}) {
  final codes = <String>[];
  final ng = math.max(1, groups);
  final lo = math.min(options.minScale, options.maxScale), hi = math.max(options.minScale, options.maxScale);
  final work = copyNetwork(net);
  // measurements that exist in the network
  final pm = <PressureMeasurement>[];
  for (final m in pressures) {
    if (net.nodes.containsKey(m.nodeId)) {
      pm.add(m);
    } else {
      codes.add('calibration_unknown_node:${m.nodeId}');
    }
  }
  final linkIds = {for (final l in net.links) l.id};
  final fm = <FlowMeasurement>[];
  for (final m in flows) {
    if (linkIds.contains(m.linkId)) {
      fm.add(m);
    } else {
      codes.add('calibration_unknown_link:${m.linkId}');
    }
  }
  final sigma = [for (final m in pm) m.sigma > 0 ? m.sigma : 0.5, for (final m in fm) m.sigma > 0 ? m.sigma : math.max(0.02 * m.flow.abs(), 1e-4)];
  final groupOfLink = <int>[];
  final baseC = <double>[];
  final members = List<int>.filled(ng, 0);
  for (final l in work.links) {
    final g = l.kind != HLinkKind.pipe ? -1 : (groupOf == null ? 0 : (groupOf[l.id] ?? -1));
    final gg = g >= 0 && g < ng ? g : -1;
    groupOfLink.add(gg);
    baseC.add(l.hazenC);
    if (gg >= 0) members[gg]++;
  }
  var evaluations = 0;
  var anyNotConverged = false;
  List<double> model(List<double> s) {
    for (var k = 0; k < work.links.length; k++) {
      final g = groupOfLink[k];
      work.links[k].hazenC = g < 0 ? baseC[k] : baseC[k] * s[g];
    }
    final r = work.solve();
    evaluations++;
    if (!r.converged) anyNotConverged = true;
    return [for (final m in pm) r.nodes[m.nodeId]?.pressure ?? 0, for (final m in fm) r.links[m.linkId]?.flow ?? 0];
  }

  final measured = [for (final m in pm) m.pressure, for (final m in fm) m.flow];
  List<double> residual(List<double> s) {
    final y = model(s);
    return [for (var i = 0; i < y.length; i++) (y[i] - measured[i]) / sigma[i]];
  }

  double sq(List<double> r) => r.fold(0.0, (a, b) => a + b * b);
  final ones = List<double>.filled(ng, 1);
  if (net.options.method != FrictionMethod.hazenWilliams) codes.add('calibration_not_hazen_williams');
  if (measured.isEmpty) codes.add('calibration_no_measurements');
  final before = model(ones);
  if (measured.isEmpty || net.options.method != FrictionMethod.hazenWilliams) {
    return _result(ones, List.filled(ng, double.nan), sq(residual(ones)), sq(residual(ones)), 0, evaluations, pm, fm, measured, before, before, sigma, false, codes);
  }
  final f0 = sq([for (var i = 0; i < before.length; i++) (before[i] - measured[i]) / sigma[i]]);
  // groups that can move: with pipes and with measurements depending on them
  final free = <int>[];
  final start = [for (var g = 0; g < ng; g++) 1.0.clamp(lo, hi)];
  final r0 = residual(start);
  // sensitivity of the residuals to every group (a pipe without flow still
  // moves the solution by round-off, so the test is relative)
  final norms = List<double>.filled(ng, 0);
  for (var g = 0; g < ng; g++) {
    if (members[g] == 0) {
      codes.add('calibration_empty_group:$g');
      continue;
    }
    final h = _step(start[g], lo, hi);
    final r2 = residual([...start]..[g] = start[g] + h);
    var norm = 0.0;
    for (var i = 0; i < r0.length; i++) {
      norm += math.pow((r2[i] - r0[i]) / h, 2);
    }
    norms[g] = math.sqrt(norm);
  }
  final largest = norms.fold(0.0, math.max);
  for (var g = 0; g < ng; g++) {
    if (members[g] == 0) continue;
    if (norms[g] <= math.max(1e-6 * largest, 1e-12)) {
      codes.add('calibration_insensitive:$g');
    } else {
      free.add(g);
    }
  }
  var s = [...start];
  var iterations = 0;
  var converged = false;
  if (free.length == 1) {
    // golden-section search over [lo, hi]
    final g = free.first;
    double f(double x) => sq(residual([...s]..[g] = x));
    const phi = 0.6180339887498949;
    var a = lo, b = hi;
    var x1 = b - phi * (b - a), x2 = a + phi * (b - a);
    var f1 = f(x1), f2 = f(x2);
    while (iterations < options.maxIterations) {
      iterations++;
      if (b - a <= options.tolerance * math.max(1.0, (a + b).abs() / 2)) {
        converged = true;
        break;
      }
      if (f1 < f2) {
        b = x2;
        x2 = x1;
        f2 = f1;
        x1 = b - phi * (b - a);
        f1 = f(x1);
      } else {
        a = x1;
        x1 = x2;
        f1 = f2;
        x2 = a + phi * (b - a);
        f2 = f(x2);
      }
    }
    s[g] = f1 < f2 ? x1 : x2;
  } else if (free.length > 1) {
    var r = r0;
    var f = sq(r);
    var lambda = 1e-3;
    while (iterations < options.maxIterations) {
      iterations++;
      final jac = _jacobian(residual, s, r, free, lo, hi);
      final p = free.length;
      final a = List.generate(p, (i) => List.generate(p, (j) => 0.0));
      final gvec = List<double>.filled(p, 0);
      for (var i = 0; i < r.length; i++) {
        for (var x = 0; x < p; x++) {
          gvec[x] += jac[i][x] * r[i];
          for (var y = 0; y < p; y++) {
            a[x][y] += jac[i][x] * jac[i][y];
          }
        }
      }
      var accepted = false;
      var fNew = f;
      List<double>? sNew;
      List<double>? rNew;
      for (var tries = 0; tries < 12; tries++) {
        final m = [for (var x = 0; x < p; x++) [for (var y = 0; y < p; y++) a[x][y] + (x == y ? lambda * math.max(a[x][x], 1e-12) : 0.0)]];
        final delta = _solve(m, [for (final v in gvec) -v]);
        if (delta == null) {
          lambda *= 10;
          continue;
        }
        final cand = [...s];
        for (var x = 0; x < p; x++) {
          cand[free[x]] = (s[free[x]] + delta[x]).clamp(lo, hi);
        }
        final rc = residual(cand);
        final fc = sq(rc);
        if (fc < f) {
          accepted = true;
          sNew = cand;
          rNew = rc;
          fNew = fc;
          lambda = math.max(lambda / 10, 1e-12);
          break;
        }
        lambda *= 10;
      }
      if (!accepted) {
        converged = true;
        break;
      }
      final drop = (f - fNew) / math.max(f, 1e-300);
      var step = 0.0;
      for (final g in free) {
        step = math.max(step, (sNew![g] - s[g]).abs());
      }
      s = sNew!;
      r = rNew!;
      f = fNew;
      if (drop < options.tolerance || step < 1e-9 || f < 1e-24) {
        converged = true;
        break;
      }
    }
  } else {
    converged = true;
  }
  // standard errors from the Jacobian at the solution
  final rs = residual(s);
  final fs = sq(rs);
  final se = List<double>.filled(ng, double.nan);
  final m = rs.length, p = free.length;
  if (p > 0 && m > p) {
    final jac = _jacobian(residual, s, rs, free, lo, hi);
    final a = List.generate(p, (i) => List.generate(p, (j) => 0.0));
    for (var i = 0; i < m; i++) {
      for (var x = 0; x < p; x++) {
        for (var y = 0; y < p; y++) {
          a[x][y] += jac[i][x] * jac[i][y];
        }
      }
    }
    final inv = _inverse(a);
    if (inv != null) {
      final s2 = fs / (m - p);
      for (var x = 0; x < p; x++) {
        if (inv[x][x] >= 0) se[free[x]] = math.sqrt(s2 * inv[x][x]);
      }
    }
  } else if (p > 0) {
    codes.add('calibration_no_redundancy');
  }
  for (final g in free) {
    if ((s[g] - lo).abs() < 1e-9 || (s[g] - hi).abs() < 1e-9) codes.add('calibration_at_bound:$g');
  }
  final after = model(s);
  if (anyNotConverged) codes.add('calibration_not_converged');
  return _result(s, se, f0, fs, iterations, evaluations, pm, fm, measured, before, after, sigma, converged, codes);
}

CalibrationResult _result(List<double> s, List<double> se, double f0, double f, int it, int ev, List<PressureMeasurement> pm, List<FlowMeasurement> fm, List<double> measured, List<double> before, List<double> after, List<double> sigma, bool converged, List<String> codes) => CalibrationResult(
  scales: s, standardErrors: se, initialObjective: f0, objective: f, iterations: it, evaluations: ev, converged: converged, codes: codes,
  residuals: [
    for (var i = 0; i < measured.length; i++)
      CalibrationResidual(id: i < pm.length ? pm[i].nodeId : fm[i - pm.length].linkId, kind: i < pm.length ? MeasurementKind.pressure : MeasurementKind.flow, measured: measured[i], before: before[i], after: after[i], sigma: sigma[i]),
  ],
);

/// Finite-difference step for a factor at [x] that stays inside [lo, hi].
double _step(double x, double lo, double hi) {
  final h = 1e-4 * math.max(1.0, x.abs());
  return x + h <= hi ? h : -h;
}

/// Forward-difference Jacobian of [residual] at [s] over the [free] factors.
List<List<double>> _jacobian(List<double> Function(List<double>) residual, List<double> s, List<double> r, List<int> free, double lo, double hi) {
  final jac = List.generate(r.length, (_) => List<double>.filled(free.length, 0));
  for (var x = 0; x < free.length; x++) {
    final g = free[x];
    final h = _step(s[g], lo, hi);
    final r2 = residual([...s]..[g] = s[g] + h);
    for (var i = 0; i < r.length; i++) {
      jac[i][x] = (r2[i] - r[i]) / h;
    }
  }
  return jac;
}

/// Solution of the small dense system m·x = b (Gaussian elimination with
/// partial pivoting); null when singular.
List<double>? _solve(List<List<double>> m, List<double> b) {
  final n = b.length;
  final a = [for (var i = 0; i < n; i++) [...m[i], b[i]]];
  for (var c = 0; c < n; c++) {
    var piv = c;
    for (var r = c + 1; r < n; r++) {
      if (a[r][c].abs() > a[piv][c].abs()) piv = r;
    }
    if (a[piv][c].abs() < 1e-300) return null;
    final t = a[c];
    a[c] = a[piv];
    a[piv] = t;
    for (var r = 0; r < n; r++) {
      if (r == c) continue;
      final f = a[r][c] / a[c][c];
      if (f == 0) continue;
      for (var k = c; k <= n; k++) {
        a[r][k] -= f * a[c][k];
      }
    }
  }
  return [for (var i = 0; i < n; i++) a[i][n] / a[i][i]];
}

/// Inverse of a small dense matrix; null when singular.
List<List<double>>? _inverse(List<List<double>> m) {
  final n = m.length;
  final cols = <List<double>>[];
  for (var c = 0; c < n; c++) {
    final x = _solve(m, [for (var i = 0; i < n; i++) i == c ? 1.0 : 0.0]);
    if (x == null) return null;
    cols.add(x);
  }
  return [for (var i = 0; i < n; i++) [for (var j = 0; j < n; j++) cols[j][i]]];
}

double _d(Object? v, [double def = 0]) => (v as num?)?.toDouble() ?? def;
