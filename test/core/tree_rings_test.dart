import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/block_generator.dart' show SubmainPosition;
import 'package:opencadirrigation/core/design/network_builder.dart';
import 'package:opencadirrigation/core/design/tree_rings.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

List<Pt> _rect(double x0, double y0, double x1, double y1) => [Pt(x0, y0), Pt(x1, y0), Pt(x1, y1), Pt(x0, y1)];

/// Whether [p] is a vertex of one of [lines].
bool _onVertex(Pt p, List<List<Pt>> lines) => lines.any((l) => l.any((q) => q.distanceTo(p) < 1e-9));

void main() {
  test('a planting grid: trees inside the area with the plant and row spacings', () {
    final rows = plantingGrid(_rect(0, 0, 60, 40), TreeRingOptions(plantSpacing: 6, rowSpacing: 7));
    // rows at 3.5, 10.5 … 38.5; trees at 3, 9 … 57
    expect(rows, hasLength(6));
    expect(rows.every((r) => r.length == 10), isTrue);
    expect(rows.first.first, const Pt(3, 3.5));
    expect(rows.first[1].x - rows.first[0].x, closeTo(6, 1e-9));
    expect(rows[1].first.y - rows[0].first.y, closeTo(7, 1e-9));
    // offsets and a turned grid stay inside the area, a ring radius from the edge
    final turned = plantingGrid(const [Pt(0, 0), Pt(50, 10), Pt(40, 50), Pt(-5, 35)], TreeRingOptions(direction: const Pt(5, 1), plantSpacing: 5, rowSpacing: 6, rowOffset: 2, plantOffset: 1, ringRadius: 1));
    for (final t in [...turned.expand((r) => r)]) {
      expect(pointInPolygon(t, const [Pt(0, 0), Pt(50, 10), Pt(40, 50), Pt(-5, 35)]), isTrue);
    }
  });

  test('every ring is joined to its lateral at both ends, round its tree', () {
    for (final kind in RingKind.values) {
      for (final side in SubmainPosition.values) {
        final t = layoutTreeRings(area: _rect(0, 0, 60, 40), options: TreeRingOptions(plantSpacing: 6, rowSpacing: 7, ringRadius: 0.75, kind: kind, drippersPerTree: 4, submainPosition: side));
        expect(t.messages, isEmpty, reason: '$kind $side');
        expect(t.trees, hasLength(60));
        expect(t.rings, hasLength(60));
        for (final r in t.rings) {
          expect(r.halves, hasLength(2));
          for (final h in r.halves) {
            expect(_onVertex(h.first, t.laterals), isTrue);
            expect(_onVertex(h.last, t.laterals), isTrue);
            for (final q in h) {
              expect(q.distanceTo(r.tree), closeTo(0.75, 1e-9));
            }
          }
          // one half on each side of the row
          final n = t.direction.perpendicular;
          final s0 = (r.halves[0][r.halves[0].length ~/ 2] - r.tree).dot(n), s1 = (r.halves[1][r.halves[1].length ~/ 2] - r.tree).dot(n);
          expect(s0 * s1, lessThan(0));
          if (kind == RingKind.drippers) {
            expect(r.drippers, hasLength(4));
            for (final d in r.drippers) {
              expect(_onVertex(d, r.halves), isTrue);
            }
          }
        }
        // the laterals start on the submain, the valve on a stub from it
        for (final l in t.laterals) {
          expect(t.submain.any((q) => q.distanceTo(l.first) < 1e-9), isTrue);
        }
        expect(t.stub.first, t.valve);
        expect(t.submain.any((q) => q.distanceTo(t.stub.last) < 1e-9), isTrue);
        expect(t.laterals, hasLength(side == SubmainPosition.centre ? 12 : 6));
      }
    }
  });

  test('the entities connect: rings, laterals, submain and valve form one zone', () {
    final t = layoutTreeRings(area: _rect(0, 0, 30, 20), options: TreeRingOptions(plantSpacing: 5, rowSpacing: 6, ringRadius: 0.6, kind: RingKind.drippers, drippersPerTree: 3));
    final p = Project();
    p.entities.addAll(t.toEntities(p, outletSpecId: 'drip_pc', nozzleId: 'pc4', headM: 10, valveSpecId: 'ev25', zoneName: 'Orchard'));
    final valve = p.entities.whereType<ControlValveEntity>().single;
    expect(valve.zoneName, 'Orchard');
    expect(p.entities.whereType<OutletEntity>(), hasLength(t.dripperCount));
    final m = NetworkBuilder(p).build();
    expect(m.warnings, isEmpty);
    // everything but the valve hangs downstream of it (the valve needs a mainline)
    expect(m.unconnectedEntities, [valve.id]);
    final emitters = (m.zoneNodes[valve.id] ?? const <String>{}).fold<int>(0, (s, id) => s + m.nodes[id]!.emitters.length);
    expect(emitters, t.dripperCount);
    // three drippers: one where the lateral enters, one on each side; each
    // half is a 120° chord and a 60° chord
    expect(t.ringLength, closeTo(t.trees.length * 2 * 0.6 * (math.sqrt(3) + 1), 1e-9));
  });

  test('surveyed trees grouped in rows', () {
    final rnd = math.Random(3);
    final pts = [for (var r = 0; r < 5; r++) for (var c = 0; c < 8; c++) Pt(c * 5.0 + rnd.nextDouble() * 0.6, r * 6.0 + rnd.nextDouble() * 0.6)];
    final rows = treeRows(pts, const Pt(1, 0), 1.5);
    expect(rows, hasLength(5));
    expect(rows.every((r) => r.length == 8), isTrue);
    final t = layoutTreeRings(trees: pts, options: TreeRingOptions(rowSpacing: 6, plantSpacing: 5, kind: RingKind.drippers, drippersPerTree: 3));
    expect(t.laterals, hasLength(5));
    expect(t.dripperCount, 40 * 3);
    for (final r in t.rings) {
      for (final h in r.halves) {
        expect(_onVertex(h.first, t.laterals) && _onVertex(h.last, t.laterals), isTrue);
      }
    }
  });

  test('rings that touch and rows that leave the area are reported', () {
    expect(layoutTreeRings(area: _rect(0, 0, 20, 10), options: TreeRingOptions(plantSpacing: 2, rowSpacing: 4, ringRadius: 1.2)).messages, contains('rings_overlap'));
    const u = [Pt(0, 0), Pt(40, 0), Pt(40, 20), Pt(28, 20), Pt(28, 8), Pt(12, 8), Pt(12, 20), Pt(0, 20)];
    final t = layoutTreeRings(area: u, options: TreeRingOptions(plantSpacing: 4, rowSpacing: 5));
    expect(t.messages.any((m) => m.startsWith('rings_row_gap:')), isTrue);
    expect(layoutTreeRings(area: const [Pt(0, 0), Pt(1, 0), Pt(0, 1)], options: TreeRingOptions()).messages, ['rings_no_trees']);
  });
}
