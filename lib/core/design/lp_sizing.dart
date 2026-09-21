/// Linear-programming pipe sizing ("LP design").
///
/// Each computer-sized unit (entity) may be built from fractions of the
/// candidate diameters; the LP minimises annualised pipe cost plus the
/// energy cost of the inlet head subject to the pressure window of every
/// critical outlet (and to the required pressure of every valve for the
/// mainline). Fractions are then rounded to the allowed number of
/// diameters per unit, largest diameters upstream (telescoping).
library;

import 'dart:math' as math;

import '../model/catalog.dart';
import 'lp.dart';

/// A free head variable of the LP (zone inlet head or a supply head).
class LpHeadVar {
  LpHeadVar({this.energyPerMetre = 0, this.fixedValue, this.maxValue, this.name = ''});

  /// Annual energy cost per metre of head (currency/m/year); when 0 a tiny
  /// weight is used so the LP still prefers the lowest head.
  final double energyPerMetre;

  /// Known head (fixed-pressure supply); the variable is then a constant.
  final double? fixedValue;
  final double? maxValue;
  final String name;
}

/// Pressure constraint at a node: head − Σ losses − constant within
/// [minPressure, maxPressure].
class LpHeadConstraint {
  LpHeadConstraint({required this.headVar, required this.lossByUnitSpec, this.constant = 0, this.minPressure, this.maxPressure, this.tag = ''});
  final int headVar;

  /// unit id → spec id → head loss (m) of the part of the unit on the path
  /// when built entirely with that spec.
  final Map<String, Map<String, double>> lossByUnitSpec;
  final double constant;
  final double? minPressure;
  final double? maxPressure;
  final String tag;
}

class LpSizingInput {
  LpSizingInput({required this.units, required this.candidates, required this.unitLength, required this.maxSizes, required this.headVars, required this.constraints, required this.crf, required this.tradeCapital, this.pipeCost});

  /// Unit ids in order.
  final List<String> units;
  final Map<String, List<PipeSpec>> candidates;
  final Map<String, double> unitLength;
  final Map<String, int> maxSizes;
  final List<LpHeadVar> headVars;
  final List<LpHeadConstraint> constraints;
  final double crf;
  final bool tradeCapital;

  /// Price per metre of a candidate (default: its catalogue price); lets the
  /// designer supply estimates for pipes that have no price.
  final double Function(PipeSpec spec)? pipeCost;
}

class LpAssignment {
  LpAssignment({required this.feasible, required this.fractions, required this.heads, this.message, this.iterations = 0, this.objective = 0});
  final bool feasible;

  /// unit id → (spec, fraction of length), sorted by diameter descending.
  final Map<String, List<(PipeSpec, double)>> fractions;

  /// Solved head variables (m).
  final List<double> heads;
  final String? message;
  final int iterations;
  final double objective;

  /// Largest diameter of a unit (used for interim analyses).
  PipeSpec? largest(String unit) => fractions[unit]?.first.$1;
}

/// Builds and solves the sizing LP, then rounds to the allowed sizes.
LpAssignment lpSize(LpSizingInput input) {
  final varIndex = <String, Map<String, int>>{};
  final p = LpProblem(0);
  for (final u in input.units) {
    final cands = input.candidates[u] ?? const [];
    final len = input.unitLength[u] ?? 0;
    final m = <String, int>{};
    for (final s in cands) {
      final cost = (input.pipeCost?.call(s) ?? s.costPerM) * len * (input.tradeCapital ? input.crf : 1.0);
      m[s.id] = p.addVariable(cost, name: '$u:${s.id}');
    }
    varIndex[u] = m;
  }
  final headIndex = <int, int>{}; // head var → LP var (absent when fixed)
  for (var i = 0; i < input.headVars.length; i++) {
    final h = input.headVars[i];
    if (h.fixedValue != null) continue;
    final e = h.energyPerMetre > 0 ? h.energyPerMetre : 1e-3;
    headIndex[i] = p.addVariable(input.tradeCapital ? e : math.max(e, 1e-3), name: 'H${h.name}');
    if (h.maxValue != null && h.maxValue! > 0) p.add({headIndex[i]!: 1.0}, LpSense.le, h.maxValue!);
  }
  // fractions sum to one
  for (final u in input.units) {
    final m = varIndex[u]!;
    if (m.isEmpty) continue;
    p.add({for (final v in m.values) v: 1.0}, LpSense.eq, 1);
  }
  // pressure constraints
  for (final c in input.constraints) {
    final row = <int, double>{};
    var rhsShift = 0.0;
    final h = input.headVars[c.headVar];
    if (h.fixedValue != null) {
      rhsShift += h.fixedValue!;
    } else {
      row[headIndex[c.headVar]!] = 1.0;
    }
    c.lossByUnitSpec.forEach((u, bySpec) {
      final m = varIndex[u];
      if (m == null) return;
      bySpec.forEach((sid, loss) {
        final v = m[sid];
        if (v != null) row[v] = (row[v] ?? 0) - loss;
      });
    });
    if (row.isEmpty) continue;
    if (c.minPressure != null) p.add(Map.of(row), LpSense.ge, c.minPressure! + c.constant - rhsShift);
    if (c.maxPressure != null && c.maxPressure!.isFinite) p.add(Map.of(row), LpSense.le, c.maxPressure! + c.constant - rhsShift);
  }
  if (p.cost.isEmpty) return LpAssignment(feasible: true, fractions: const {}, heads: [for (final h in input.headVars) h.fixedValue ?? 0]);
  final r = solveLp(p);
  if (!r.optimal) {
    return LpAssignment(feasible: false, fractions: const {}, heads: const [], message: r.status.name, iterations: r.iterations);
  }
  final fractions = <String, List<(PipeSpec, double)>>{};
  for (final u in input.units) {
    final m = varIndex[u]!;
    final cands = input.candidates[u] ?? const [];
    if (m.isEmpty) continue;
    final list = <(PipeSpec, double)>[];
    for (final s in cands) {
      final f = r.x[m[s.id]!];
      if (f > 0.02) list.add((s, f));
    }
    if (list.isEmpty) {
      list.add((cands.last, 1.0));
    }
    list.sort((a, b) => b.$1.innerDiameterMm.compareTo(a.$1.innerDiameterMm));
    fractions[u] = roundFractions(list, input.maxSizes[u] ?? 1);
  }
  final heads = <double>[];
  for (var i = 0; i < input.headVars.length; i++) {
    final h = input.headVars[i];
    heads.add(h.fixedValue ?? r.x[headIndex[i]!]);
  }
  return LpAssignment(feasible: true, fractions: fractions, heads: heads, iterations: r.iterations, objective: r.objective);
}

/// Keeps at most [maxSizes] diameters (the largest ones); smaller fractions
/// are absorbed by the smallest kept diameter (conservative: less loss).
List<(PipeSpec, double)> roundFractions(List<(PipeSpec, double)> sorted, int maxSizes) {
  final n = math.max(1, maxSizes);
  if (sorted.length <= n) return _normalise(sorted);
  final kept = sorted.take(n).toList();
  var rest = 0.0;
  for (final f in sorted.skip(n)) {
    rest += f.$2;
  }
  final last = kept.last;
  kept[kept.length - 1] = (last.$1, last.$2 + rest);
  return _normalise(kept);
}

List<(PipeSpec, double)> _normalise(List<(PipeSpec, double)> l) {
  final s = l.fold(0.0, (a, f) => a + f.$2);
  if (s <= 0) return l;
  return [for (final f in l) (f.$1, f.$2 / s)];
}
