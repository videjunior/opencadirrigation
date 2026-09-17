/// Sparse symmetric positive-definite linear solver (LDLᵀ elimination with a
/// minimum-degree ordering). Used by the Global Gradient Algorithm, whose
/// Jacobian is SPD and, for branched irrigation networks, nearly a tree.
library;

class SparseSymmetricSystem {
  SparseSymmetricSystem(this.n)
      : rows = List.generate(n, (_) => <int, double>{}),
        rhs = List.filled(n, 0);

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
