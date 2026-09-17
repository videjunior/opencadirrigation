import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/lp.dart';

void main() {
  test('simplex solves a small LP with ≤ and ≥ constraints', () {
    // minimise x + 2y  s.t. x + y >= 4, x <= 3, y <= 5
    final p = LpProblem(2);
    p.addVariable(1, name: 'x');
    p.addVariable(2, name: 'y');
    p.add({0: 1, 1: 1}, LpSense.ge, 4);
    p.add({0: 1}, LpSense.le, 3);
    p.add({1: 1}, LpSense.le, 5);
    final r = solveLp(p);
    expect(r.optimal, isTrue);
    expect(r.x[0], closeTo(3, 1e-9));
    expect(r.x[1], closeTo(1, 1e-9));
    expect(r.objective, closeTo(5, 1e-9));
  });

  test('simplex: equality rows, infeasible and unbounded detection', () {
    final p = LpProblem(3);
    p.addVariable(3);
    p.addVariable(1);
    p.addVariable(0);
    p.add({0: 1, 1: 1}, LpSense.eq, 1);
    p.add({0: 1, 2: -1}, LpSense.ge, 0.5);
    final r = solveLp(p);
    expect(r.optimal, isTrue);
    expect(r.x[0] + r.x[1], closeTo(1, 1e-9));
    expect(r.x[0], greaterThanOrEqualTo(0.5 - 1e-9));
    expect(r.objective, closeTo(0.5 * 3 + 0.5 * 1, 1e-9));
    final inf = LpProblem(1);
    inf.addVariable(1);
    inf.add({0: 1}, LpSense.ge, 5);
    inf.add({0: 1}, LpSense.le, 2);
    expect(solveLp(inf).status, LpStatus.infeasible);
    final unb = LpProblem(1);
    unb.addVariable(-1);
    unb.add({0: 1}, LpSense.ge, 0);
    expect(solveLp(unb).status, LpStatus.unbounded);
  });

  test('simplex: pipe sizing shaped problem (fractions sum to 1, head budget)', () {
    // 3 units × 3 diameters; loss coefficients decrease with diameter; cost increases.
    final p = LpProblem(10);
    final losses = [
      [8.0, 3.0, 1.0],
      [6.0, 2.0, 0.7],
      [4.0, 1.5, 0.5],
    ];
    final cost = [1.0, 2.0, 4.0];
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        p.addVariable(cost[j] * 100, name: 'u${i}d$j');
      }
    }
    final h0 = p.addVariable(50, name: 'H0'); // energy cost per metre
    for (var i = 0; i < 3; i++) {
      p.add({for (var j = 0; j < 3; j++) i * 3 + j: 1.0}, LpSense.eq, 1);
    }
    // end node pressure H0 - losses >= 10 and <= 14
    final path = {for (var i = 0; i < 3; i++) for (var j = 0; j < 3; j++) i * 3 + j: -losses[i][j]};
    p.add({...path, h0: 1.0}, LpSense.ge, 10);
    p.add({...path, h0: 1.0}, LpSense.le, 14);
    final r = solveLp(p);
    expect(r.optimal, isTrue);
    for (var i = 0; i < 3; i++) {
      var s = 0.0;
      for (var j = 0; j < 3; j++) {
        s += r.x[i * 3 + j];
      }
      expect(s, closeTo(1, 1e-9));
    }
    var loss = 0.0;
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        loss += losses[i][j] * r.x[i * 3 + j];
      }
    }
    expect(r.x[h0] - loss, greaterThanOrEqualTo(10 - 1e-9));
    expect(r.x[h0] - loss, lessThanOrEqualTo(14 + 1e-9));
  });
}
