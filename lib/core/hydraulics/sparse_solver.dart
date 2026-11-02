/// Sparse symmetric positive-definite linear solver (LDLᵀ elimination with a
/// minimum-degree ordering). Used by the Global Gradient Algorithm, whose
/// Jacobian is SPD and, for branched irrigation networks, nearly a tree.
library;

import 'dart:typed_data';

class SparseSymmetricSystem {
  SparseSymmetricSystem(this.n) : rows = List.generate(n, (_) => <int, double>{}), rhs = List.filled(n, 0);

  final int n;
  final List<Map<int, double>> rows;
  final List<double> rhs;

  void add(int i, int j, double v) {
    rows[i][j] = (rows[i][j] ?? 0) + v;
    if (i != j) rows[j][i] = (rows[j][i] ?? 0) + v;
  }

  void addDiagonal(int i, double v) {
    rows[i][i] = (rows[i][i] ?? 0) + v;
  }

  /// Solves A·x = rhs. The system is consumed (rows are modified).
  List<double> solve() {
    if (n == 0) return const [];
    final a = rows.map((r) => Map<int, double>.from(r)).toList();
    final b = List<double>.from(rhs);
    final eliminated = List<bool>.filled(n, false);
    final order = <int>[];
    final pivotRows = <Map<int, double>>[];

    // Bucketed minimum-degree selection.
    final degree = List<int>.generate(n, (i) => a[i].length - (a[i].containsKey(i) ? 1 : 0));
    final buckets = <int, Set<int>>{};
    for (var i = 0; i < n; i++) {
      buckets.putIfAbsent(degree[i], () => <int>{}).add(i);
    }
    int minDegree = 0;

    int pickNext() {
      while (true) {
        final s = buckets[minDegree];
        if (s != null && s.isNotEmpty) {
          final p = s.first;
          s.remove(p);
          return p;
        }
        minDegree++;
        if (minDegree > n + 1) {
          for (var i = 0; i < n; i++) {
            if (!eliminated[i]) return i;
          }
          return -1;
        }
      }
    }

    void setDegree(int i, int d) {
      buckets[degree[i]]?.remove(i);
      degree[i] = d;
      buckets.putIfAbsent(d, () => <int>{}).add(i);
      if (d < minDegree) minDegree = d;
    }

    for (var step = 0; step < n; step++) {
      final p = pickNext();
      if (p < 0) break;
      eliminated[p] = true;
      final row = a[p];
      final pivot = row[p] ?? 0;
      if (pivot.abs() < 1e-300) {
        // Singular pivot: isolate node (keeps solver alive).
        row[p] = 1e-30;
      }
      final piv = row[p]!;
      final neighbors = <int>[];
      final coeffs = <double>[];
      for (final e in row.entries) {
        if (e.key != p && !eliminated[e.key]) {
          neighbors.add(e.key);
          coeffs.add(e.value);
        }
      }
      // Schur complement update.
      for (var x = 0; x < neighbors.length; x++) {
        final i = neighbors[x];
        final f = coeffs[x] / piv;
        b[i] -= f * b[p];
        final ri = a[i];
        ri.remove(p);
        for (var y = 0; y < neighbors.length; y++) {
          final j = neighbors[y];
          final upd = -f * coeffs[y];
          ri[j] = (ri[j] ?? 0) + upd;
        }
        setDegree(i, ri.length - (ri.containsKey(i) ? 1 : 0));
      }
      order.add(p);
      pivotRows.add({for (var x = 0; x < neighbors.length; x++) neighbors[x]: coeffs[x], p: piv});
    }

    final x = List<double>.filled(n, 0);
    for (var k = order.length - 1; k >= 0; k--) {
      final p = order[k];
      final row = pivotRows[k];
      var s = b[p];
      for (final e in row.entries) {
        if (e.key != p) s -= e.value * x[e.key];
      }
      x[p] = s / row[p]!;
    }
    return x;
  }
}

/// The elimination [SparseSymmetricSystem.solve] performs, worked out once
/// for a sparsity pattern: the pivot order, the neighbours of every pivot and
/// the slot of every value in one flat array. Systems of that pattern (every
/// iteration of the network solver) are then solved on typed arrays, without
/// a map, with the same pivots and the same operations in the same order as
/// [SparseSymmetricSystem], so with the same solution to the last bit.
class EliminationPlan {
  EliminationPlan._(this.n, this._from, this._to, this.slotCount, this.pairSlotFT, this.pairSlotTF, this._order, this._nbStart, this._nb, this._nbSlot, this._updStart, this._upd);

  /// The plan for [n] unknowns whose off-diagonal entries are first added in
  /// the order of the pairs (`from[k]`, `to[k]`), as [SparseSymmetricSystem.add]
  /// adds them: both (i, j) and (j, i), a repeated pair to the same entries.
  /// A pair must not tie an unknown to itself (that is the diagonal).
  factory EliminationPlan(int n, List<int> from, List<int> to) {
    // The off-diagonal keys of every row in the order the maps of
    // SparseSymmetricSystem hold them, with the slot of each value; slot i
    // holds the diagonal of row i, whose place in the map orders nothing.
    final keys = List<List<int>>.generate(n, (_) => <int>[]);
    final slots = List<List<int>>.generate(n, (_) => <int>[]);
    var slotCount = n;
    int slotOf(int i, int j) {
      final k = keys[i];
      for (var t = 0; t < k.length; t++) {
        if (k[t] == j) return slots[i][t];
      }
      k.add(j);
      slots[i].add(slotCount);
      return slotCount++;
    }

    final ft = Int32List(from.length), tf = Int32List(from.length);
    for (var k = 0; k < from.length; k++) {
      ft[k] = slotOf(from[k], to[k]);
      tf[k] = slotOf(to[k], from[k]);
    }

    // Degree buckets as linked lists in the insertion order of the sets of
    // SparseSymmetricSystem: a node moved to a bucket goes to its end.
    final degree = Int32List(n);
    final first = Int32List(n + 2)..fillRange(0, n + 2, -1);
    final last = Int32List(n + 2)..fillRange(0, n + 2, -1);
    final next = Int32List(n), prev = Int32List(n);
    void append(int i) {
      final d = degree[i];
      prev[i] = last[d];
      next[i] = -1;
      if (last[d] >= 0) {
        next[last[d]] = i;
      } else {
        first[d] = i;
      }
      last[d] = i;
    }

    void unlink(int i) {
      final d = degree[i];
      final a = prev[i], b = next[i];
      if (a >= 0) {
        next[a] = b;
      } else {
        first[d] = b;
      }
      if (b >= 0) {
        prev[b] = a;
      } else {
        last[d] = a;
      }
    }

    for (var i = 0; i < n; i++) {
      degree[i] = keys[i].length;
      append(i);
    }
    final eliminated = Uint8List(n);
    var minDegree = 0;
    int pickNext() {
      while (true) {
        if (minDegree <= n + 1 && first[minDegree] >= 0) {
          final p = first[minDegree];
          unlink(p);
          return p;
        }
        minDegree++;
        if (minDegree > n + 1) {
          for (var i = 0; i < n; i++) {
            if (eliminated[i] == 0) return i;
          }
          return -1;
        }
      }
    }

    final order = <int>[];
    final nbStart = <int>[0], nb = <int>[], nbSlot = <int>[];
    final updStart = <int>[0], upd = <int>[];
    final seen = Int32List(n)..fillRange(0, n, -1);
    final at = Int32List(n);
    var mark = 0;
    for (var step = 0; step < n; step++) {
      final p = pickNext();
      if (p < 0) break;
      eliminated[p] = 1;
      final start = nb.length;
      final kp = keys[p], sp = slots[p];
      for (var t = 0; t < kp.length; t++) {
        if (eliminated[kp[t]] == 0) {
          nb.add(kp[t]);
          nbSlot.add(sp[t]);
        }
      }
      final end = nb.length;
      // Schur complement: every pair of neighbours gets an update; entries
      // that exist keep their place, new ones (fill) join the end of the row
      for (var x = start; x < end; x++) {
        final i = nb[x];
        final ki = keys[i], si = slots[i];
        final pos = ki.indexOf(p);
        if (pos >= 0) {
          ki.removeAt(pos);
          si.removeAt(pos);
        }
        mark++;
        for (var t = 0; t < ki.length; t++) {
          seen[ki[t]] = mark;
          at[ki[t]] = t;
        }
        for (var y = start; y < end; y++) {
          final j = nb[y];
          if (j == i) {
            upd.add(i);
          } else if (seen[j] == mark) {
            upd.add(si[at[j]]);
          } else {
            seen[j] = mark;
            at[j] = ki.length;
            ki.add(j);
            si.add(slotCount);
            upd.add(slotCount++);
          }
        }
        unlink(i);
        degree[i] = ki.length;
        append(i);
        if (ki.length < minDegree) minDegree = ki.length;
      }
      order.add(p);
      nbStart.add(end);
      updStart.add(upd.length);
    }
    return EliminationPlan._(
      n,
      Int32List.fromList(from),
      Int32List.fromList(to),
      slotCount,
      ft,
      tf,
      Int32List.fromList(order),
      Int32List.fromList(nbStart),
      Int32List.fromList(nb),
      Int32List.fromList(nbSlot),
      Int32List.fromList(updStart),
      Int32List.fromList(upd),
    );
  }

  final int n;
  final Int32List _from, _to;

  /// Whether this is the plan of [n] unknowns and the pairs ([from], [to]).
  bool matches(int n, List<int> from, List<int> to) {
    if (n != this.n || from.length != _from.length) return false;
    for (var k = 0; k < from.length; k++) {
      if (from[k] != _from[k] || to[k] != _to[k]) return false;
    }
    return true;
  }

  /// Length of the value array: the diagonal of row i is slot i.
  final int slotCount;

  /// Slots of the entries (`from[k]`, `to[k]`) and (`to[k]`, `from[k]`) of
  /// the pairs the plan was made from.
  final Int32List pairSlotFT, pairSlotTF;

  final Int32List _order, _nbStart, _nb, _nbSlot, _updStart, _upd;

  /// Solves A·x = [rhs] for the matrix whose values are in [values] (by
  /// slot); both arrays are consumed.
  Float64List solve(Float64List values, Float64List rhs) {
    final x = Float64List(n);
    final coef = Float64List(_nb.length);
    final piv = Float64List(_order.length);
    for (var s = 0; s < _order.length; s++) {
      final p = _order[s];
      // Singular pivot: isolate node (keeps solver alive).
      if (values[p].abs() < 1e-300) values[p] = 1e-30;
      final pv = values[p];
      piv[s] = pv;
      final start = _nbStart[s], end = _nbStart[s + 1];
      for (var t = start; t < end; t++) {
        coef[t] = values[_nbSlot[t]];
      }
      final bp = rhs[p];
      var u = _updStart[s];
      for (var a = start; a < end; a++) {
        final f = coef[a] / pv;
        rhs[_nb[a]] -= f * bp;
        for (var c = start; c < end; c++) {
          values[_upd[u++]] += -f * coef[c];
        }
      }
    }
    for (var s = _order.length - 1; s >= 0; s--) {
      var acc = rhs[_order[s]];
      for (var t = _nbStart[s]; t < _nbStart[s + 1]; t++) {
        acc -= coef[t] * x[_nb[t]];
      }
      x[_order[s]] = acc / piv[s];
    }
    return x;
  }
}
