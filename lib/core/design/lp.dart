/// Dense two-phase simplex for the pipe-sizing linear programs.
///
/// minimise c·x subject to A·x (≤ | = | ≥) b, x ≥ 0. Sizes are small
/// (hundreds of variables and constraints), so a dense tableau with
/// Dantzig pricing and a Bland fallback against cycling is enough.
library;

import 'dart:typed_data';

enum LpSense { le, eq, ge }

class LpConstraint {
  LpConstraint(this.coefficients, this.sense, this.rhs);

  /// Sparse row: variable index → coefficient.
  final Map<int, double> coefficients;
  final LpSense sense;
  final double rhs;
}

class LpProblem {
  LpProblem(this.variableCount);
  final int variableCount;
  final List<double> cost = [];
  final List<LpConstraint> constraints = [];

  /// Optional names for diagnostics.
  final List<String> names = [];

  int addVariable(double c, {String name = ''}) {
    cost.add(c);
    names.add(name);
    return cost.length - 1;
  }

  void add(Map<int, double> coefficients, LpSense sense, double rhs) => constraints.add(LpConstraint(coefficients, sense, rhs));
}

class LpResult {
  LpResult({required this.status, required this.x, required this.objective, this.iterations = 0});
  final LpStatus status;
  final List<double> x;
  final double objective;
  final int iterations;
  bool get optimal => status == LpStatus.optimal;
}

enum LpStatus { optimal, infeasible, unbounded, iterationLimit }

/// Solves [p] with a two-phase dense simplex.
LpResult solveLp(LpProblem p, {double eps = 1e-9, int? maxIterations}) {
  final n = p.cost.length;
  final m = p.constraints.length;
  if (n == 0) return LpResult(status: LpStatus.optimal, x: const [], objective: 0);
  // count slacks and artificials
  var slackCount = 0, artCount = 0;
  final rowSense = <LpSense>[];
  final rowRhs = <double>[];
  for (final c in p.constraints) {
    var s = c.sense;
    var r = c.rhs;
    if (r < 0) {
      r = -r;
      s = switch (s) { LpSense.le => LpSense.ge, LpSense.ge => LpSense.le, LpSense.eq => LpSense.eq };
    }
    rowSense.add(s);
    rowRhs.add(r);
    if (s != LpSense.eq) slackCount++;
    if (s != LpSense.le) artCount++;
  }
  final cols = n + slackCount + artCount; // + rhs column
  final width = cols + 1;
  final t = List<Float64List>.generate(m, (_) => Float64List(width));
  final basis = List<int>.filled(m, -1);
  var slackIdx = n, artIdx = n + slackCount;
  final artificial = <int>[];
  for (var i = 0; i < m; i++) {
    final c = p.constraints[i];
    final flip = c.rhs < 0 ? -1.0 : 1.0;
    final row = t[i];
    c.coefficients.forEach((j, v) {
      if (j >= 0 && j < n) row[j] += v * flip;
    });
    row[cols] = rowRhs[i];
    switch (rowSense[i]) {
      case LpSense.le:
        row[slackIdx] = 1;
        basis[i] = slackIdx++;
      case LpSense.ge:
        row[slackIdx] = -1;
        slackIdx++;
        row[artIdx] = 1;
        basis[i] = artIdx;
        artificial.add(artIdx++);
      case LpSense.eq:
        row[artIdx] = 1;
        basis[i] = artIdx;
        artificial.add(artIdx++);
    }
  }
  final limit = maxIterations ?? (50 * (m + cols) + 1000);
  var iterations = 0;

  // objective row helper: reduced costs z_j - c_j for a cost vector
  Float64List reduced(Float64List costs) {
    final r = Float64List(width);
    for (var j = 0; j < width; j++) {
      var s = j < cols ? -costs[j] : 0.0;
      for (var i = 0; i < m; i++) {
        s += costs[basis[i]] * t[i][j];
      }
      r[j] = s;
    }
    return r;
  }

  void pivot(int r, int c) {
    final pr = t[r];
    final pv = pr[c];
    for (var j = 0; j < width; j++) {
      pr[j] /= pv;
    }
    for (var i = 0; i < m; i++) {
      if (i == r) continue;
      final f = t[i][c];
      if (f == 0) continue;
      final ri = t[i];
      for (var j = 0; j < width; j++) {
        ri[j] -= f * pr[j];
      }
    }
    basis[r] = c;
  }

  /// Runs the simplex on the current tableau for [costs]; returns status.
  LpStatus run(Float64List costs, Set<int> forbidden) {
    var z = reduced(costs);
    var stall = 0;
    var lastObj = double.infinity;
    var bland = false;
    while (iterations < limit) {
      // entering variable
      var enter = -1;
      var best = eps;
      for (var j = 0; j < cols; j++) {
        if (forbidden.contains(j)) continue;
        final v = z[j];
        if (v > best) {
          if (bland) {
            enter = j;
            break;
          }
          best = v;
          enter = j;
        }
      }
      if (enter < 0) return LpStatus.optimal;
      // ratio test
      var leave = -1;
      var minRatio = double.infinity;
      for (var i = 0; i < m; i++) {
        final a = t[i][enter];
        if (a <= eps) continue;
        final ratio = t[i][cols] / a;
        if (ratio < minRatio - 1e-12 || (ratio <= minRatio + 1e-12 && leave >= 0 && basis[i] < basis[leave])) {
          minRatio = ratio;
          leave = i;
        }
      }
      if (leave < 0) return LpStatus.unbounded;
      pivot(leave, enter);
      iterations++;
      z = reduced(costs);
      var obj = 0.0;
      for (var i = 0; i < m; i++) {
        obj += costs[basis[i]] * t[i][cols];
      }
      if (obj > lastObj - 1e-12) {
        stall++;
        if (stall > 30) bland = true;
      } else {
        stall = 0;
        bland = false;
      }
      lastObj = obj;
    }
    return LpStatus.iterationLimit;
  }

  // phase 1
  if (artificial.isNotEmpty) {
    final c1 = Float64List(width);
    for (final a in artificial) {
      c1[a] = 1;
    }
    final st = run(c1, const {});
    if (st == LpStatus.iterationLimit) return LpResult(status: st, x: List.filled(n, 0), objective: 0, iterations: iterations);
    var infeas = 0.0;
    for (var i = 0; i < m; i++) {
      if (artificial.contains(basis[i])) infeas += t[i][cols];
    }
    if (infeas > 1e-6) return LpResult(status: LpStatus.infeasible, x: List.filled(n, 0), objective: 0, iterations: iterations);
    // drive artificial variables out of the basis when possible
    for (var i = 0; i < m; i++) {
      if (!artificial.contains(basis[i])) continue;
      var found = -1;
      for (var j = 0; j < n + slackCount; j++) {
        if (t[i][j].abs() > 1e-7) {
          found = j;
          break;
        }
      }
      if (found >= 0) {
        pivot(i, found);
      }
    }
  }
  // phase 2
  final c2 = Float64List(width);
  for (var j = 0; j < n; j++) {
    c2[j] = p.cost[j];
  }
  final st = run(c2, artificial.toSet());
  final x = List<double>.filled(n, 0);
  for (var i = 0; i < m; i++) {
    if (basis[i] < n) x[basis[i]] = t[i][cols];
  }
  var obj = 0.0;
  for (var j = 0; j < n; j++) {
    obj += p.cost[j] * x[j];
  }
  return LpResult(status: st == LpStatus.optimal ? LpStatus.optimal : st, x: x, objective: obj, iterations: iterations);
}
