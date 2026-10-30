import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/network_builder.dart';
import 'package:opencadirrigation/core/hydraulics/sparse_solver.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';

/// The faster engine gives the very same results: the elimination plan of
/// the network solver against the map-based solver, and the indexed lookups
/// against edits of their lists. (The zone networks the designer reuses are
/// checked against new ones in every design run with asserts on.)
void main() {
  group('elimination plan', () {
    test('solves to the last bit as SparseSymmetricSystem', () {
      final rnd = math.Random(7);
      for (var trial = 0; trial < 400; trial++) {
        final n = 1 + rnd.nextInt(trial < 300 ? 30 : 300);
        final from = <int>[], to = <int>[];
        // a tree, with loops, a dense mesh or parts cut off; parallel pairs
        final kind = trial % 4;
        for (var i = 1; i < n; i++) {
          if (kind == 3 && rnd.nextInt(5) == 0) continue;
          from.add(rnd.nextInt(i));
          to.add(i);
        }
        for (var e = 0; e < (kind == 0 ? 0 : (kind == 1 ? n ~/ 5 : n)); e++) {
          final a = rnd.nextInt(n), b = rnd.nextInt(n);
          if (a == b) continue;
          from.add(a);
          to.add(b);
        }
        if (from.isNotEmpty) {
          from.add(from.first);
          to.add(to.first);
        }
        final order = List<int>.generate(from.length, (i) => i)..shuffle(rnd);
        final f = [for (final i in order) from[i]], t = [for (final i in order) to[i]];
        final w = [for (var k = 0; k < f.length; k++) math.pow(10, rnd.nextDouble() * 8 - 4).toDouble()];
        final diag = [for (var i = 0; i < n; i++) rnd.nextInt(6) == 0 ? 0.0 : math.pow(10, rnd.nextDouble() * 6 - 3).toDouble()];
        final b = [for (var i = 0; i < n; i++) rnd.nextDouble() * 200 - 100];

        final reference = SparseSymmetricSystem(n);
        final plan = EliminationPlan(n, f, t);
        final values = Float64List(plan.slotCount);
        for (var i = 0; i < n; i++) {
          if (diag[i] == 0) continue;
          reference.addDiagonal(i, diag[i]);
          values[i] += diag[i];
        }
        for (var k = 0; k < f.length; k++) {
          reference
            ..addDiagonal(f[k], w[k])
            ..addDiagonal(t[k], w[k])
            ..add(f[k], t[k], -w[k]);
          values[f[k]] += w[k];
          values[t[k]] += w[k];
          values[plan.pairSlotFT[k]] += -w[k];
          values[plan.pairSlotTF[k]] += -w[k];
        }
        for (var i = 0; i < n; i++) {
          reference.rhs[i] = b[i];
        }
        expect(plan.solve(values, Float64List.fromList(b)), orderedEquals(reference.solve()), reason: 'trial $trial');
        expect(plan.matches(n, f, t), isTrue);
        expect(plan.matches(n + 1, f, t), isFalse);
      }
    });
  });

  group('indexed lookups', () {
    GLink link(String id, String entity) => GLink(id: id, from: 'a', to: 'b', kind: GLinkKind.pipe, scope: HydraulicScope.zone, entityId: entity);

    test('NetworkModel.linkById follows links replaced, added and removed', () {
      final m = NetworkModel();
      m.links.addAll([link('l1', 'e1'), link('l2', 'e2'), link('l3', 'e3')]);
      expect(m.linkById('l2')!.entityId, 'e2');
      m.links[1] = link('l2', 'moved');
      expect(m.linkById('l2')!.entityId, 'moved');
      m.links.add(link('l4', 'e4'));
      expect(m.linkById('l4')!.entityId, 'e4');
      m.links.removeAt(0);
      expect(m.linkById('l1'), isNull);
      expect(m.linkById('l3')!.entityId, 'e3');
      m.links.insert(0, link('l3', 'first'));
      expect(m.linkById('l3')!.entityId, 'first');
      expect(m.linkById('nope'), isNull);
    });

    test('Catalog lookups follow edits of the lists, first match first', () {
      PipeSpec pipe(String id, double d) => PipeSpec(id: id, name: id, nominalMm: d, innerDiameterMm: d);
      final c = Catalog(pipes: [pipe('p1', 20), pipe('p2', 25), pipe('p2', 99)]);
      expect(c.pipe('p2')!.innerDiameterMm, 25);
      c.pipes[1] = pipe('p2', 32);
      expect(c.pipe('p2')!.innerDiameterMm, 32);
      c.pipes.removeAt(1);
      expect(c.pipe('p2')!.innerDiameterMm, 99);
      c.pipes.insert(0, pipe('p3', 40));
      expect(c.pipe('p3')!.innerDiameterMm, 40);
      expect(c.pipe('p1')!.innerDiameterMm, 20);
      c.pipes.removeWhere((p) => p.id == 'p1');
      expect(c.pipe('p1'), isNull);
      expect(c.pipe(null), isNull);
      c.merge(Catalog(pipes: [pipe('p4', 50)]));
      expect(c.pipe('p4')!.innerDiameterMm, 50);
    });
  });
}
