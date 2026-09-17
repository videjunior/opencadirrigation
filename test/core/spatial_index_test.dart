import 'dart:math' as math;

import 'package:flutter/material.dart' show Offset, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/canvas/snapping.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/spatial_index.dart';

/// The STR R-tree used for viewport culling, hit testing and snapping.
void main() {
  List<Entity> randomEntities(int n, {int seed = 7, double extent = 5000}) {
    final rnd = math.Random(seed);
    final out = <Entity>[];
    for (var i = 0; i < n; i++) {
      final x = rnd.nextDouble() * extent, y = rnd.nextDouble() * extent;
      switch (i % 4) {
        case 0:
          out.add(SpotHeightEntity(id: 'e$i', position: Pt(x, y), elevation: 100));
        case 1:
          out.add(LineEntity(id: 'e$i', a: Pt(x, y), b: Pt(x + rnd.nextDouble() * 200 - 100, y + rnd.nextDouble() * 200 - 100)));
        case 2:
          out.add(CircleEntity(id: 'e$i', center: Pt(x, y), radius: 1 + rnd.nextDouble() * 30));
        default:
          final pts = [for (var k = 0; k < 5; k++) Pt(x + rnd.nextDouble() * 60, y + rnd.nextDouble() * 60)];
          out.add(PipeEntity(id: 'e$i', points: pts, scope: HydraulicScope.zone));
      }
    }
    return out;
  }

  List<int> brute(List<Entity> ents, Bounds q) => [for (var i = 0; i < ents.length; i++) if (ents[i].bounds.intersects(q)) i];

  group('SpatialIndex', () {
    test('window queries match a brute-force scan and keep drawing order', () {
      final ents = randomEntities(3000);
      final idx = SpatialIndex.build(ents);
      expect(idx.length, 3000);
      expect(idx.indexed, 3000);
      expect(idx.nodeCount, greaterThan(250));
      final rnd = math.Random(3);
      for (var k = 0; k < 200; k++) {
        final x = rnd.nextDouble() * 5000, y = rnd.nextDouble() * 5000;
        final w = rnd.nextDouble() * 800, h = rnd.nextDouble() * 800;
        final q = Bounds(x, y, x + w, y + h);
        expect(idx.query(q), brute(ents, q), reason: 'query $k');
      }
      // whole extent and nothing
      expect(idx.query(idx.bounds), List.generate(3000, (i) => i));
      expect(idx.query(const Bounds(-100, -100, -50, -50)), isEmpty);
      expect(idx.query(Bounds.empty), isEmpty);
      // cached bounds are the entity bounds
      for (var i = 0; i < 50; i++) {
        expect(idx.boundsAt(i).minX, ents[i].bounds.minX);
      }
    });

    test('small and degenerate inputs', () {
      expect(SpatialIndex.build(const []).query(const Bounds(0, 0, 1, 1)), isEmpty);
      expect(SpatialIndex.build(const []).bounds.isEmpty, isTrue);
      final one = SpatialIndex.build([SpotHeightEntity(id: 'a', position: const Pt(3, 4), elevation: 1)]);
      expect(one.query(const Bounds(0, 0, 5, 5)), [0]);
      expect(one.query(const Bounds(4, 4, 5, 5)), isEmpty);
      expect(one.entitiesNear(const Pt(3.5, 4), 1).single.id, 'a');
      // an entity without geometry (empty bounds) is skipped, not crashed on
      final mixed = SpatialIndex.build([
        PolylineEntity(id: 'empty', points: []),
        LineEntity(id: 'l', a: const Pt(0, 0), b: const Pt(10, 10)),
      ]);
      expect(mixed.indexed, 1);
      expect(mixed.entitiesIn(const Bounds(-1, -1, 20, 20)).single.id, 'l');
      // leaf size 2 forces a deep tree
      final deep = SpatialIndex.build(randomEntities(500), leafSize: 2);
      final ents = deep.entities;
      const q = Bounds(1000, 1000, 2500, 2500);
      expect(deep.query(q), brute(ents, q));
    });

    test('is far cheaper than a scan on a large drawing', () {
      final ents = randomEntities(40000);
      final sw = Stopwatch()..start();
      final idx = SpatialIndex.build(ents);
      final build = sw.elapsedMicroseconds;
      const q = Bounds(2000, 2000, 2300, 2200); // a zoomed-in viewport
      sw.reset();
      List<int> a = const [];
      for (var k = 0; k < 50; k++) {
        a = idx.query(q);
      }
      final indexed = sw.elapsedMicroseconds / 50;
      sw.reset();
      List<int> b = const [];
      for (var k = 0; k < 50; k++) {
        b = brute(ents, q);
      }
      final scan = sw.elapsedMicroseconds / 50;
      expect(a, b);
      expect(a.length, lessThan(400));
      // ignore: avoid_print
      print('spatial index: build ${(build / 1000).toStringAsFixed(1)} ms, query ${indexed.toStringAsFixed(0)} µs vs scan ${scan.toStringAsFixed(0)} µs (${a.length} of ${ents.length} entities)');
      expect(indexed, lessThan(scan));
    });
  });

  group('controller uses the index', () {
    ProjectController controller() {
      final c = ProjectController();
      c.project = Project();
      c.camera.size = const Size(800, 600);
      c.camera.center = const Pt(50, 50);
      c.camera.scale = 4;
      return c;
    }

    test('rebuilds after edits, undo, redo and project replacement', () {
      final c = controller();
      final i0 = c.index;
      expect(identical(c.index, i0), isTrue, reason: 'cached while nothing changed');
      c.addEntity(LineEntity(id: c.project.newId(), a: const Pt(0, 0), b: const Pt(100, 0)));
      final i1 = c.index;
      expect(identical(i1, i0), isFalse);
      expect(i1.length, 1);
      expect(c.pick(const Pt(50, 1), 2)?.id, c.project.entities.single.id);
      expect(c.pick(const Pt(50, 5), 2), isNull);
      // grip move: the cached bounds follow the geometry
      c.setGrip(c.project.entities.single.id, 1, const Pt(100, 40));
      expect(c.pick(const Pt(100, 39), 2), isNotNull);
      c.undo();
      expect(c.pick(const Pt(100, 39), 2), isNull);
      expect(c.pick(const Pt(99, 0.5), 2), isNotNull);
      c.redo();
      expect(c.pick(const Pt(100, 39), 2), isNotNull);
      // hidden layer: not picked, not in entitiesIn
      c.toggleLayer(Layers.drawing);
      expect(c.pick(const Pt(100, 39), 2), isNull);
      expect(c.entitiesIn(const Bounds(-10, -10, 200, 200)), isEmpty);
      c.toggleLayer(Layers.drawing);
      // replacing the project rebuilds
      c.project = Project()..entities.add(SpotHeightEntity(id: 's', position: const Pt(5, 5), elevation: 1));
      expect(c.index.length, 1);
      expect(c.pick(const Pt(5, 5), 1)?.id, 's');
      // a direct change reported with entitiesChanged() is picked up too
      c.project.entities.add(SpotHeightEntity(id: 's2', position: const Pt(20, 20), elevation: 1));
      expect(c.pick(const Pt(20, 20), 1)?.id, 's2', reason: 'length changed');
      (c.project.entities.first as SpotHeightEntity).position = const Pt(30, 30);
      c.entitiesChanged();
      expect(c.pick(const Pt(30, 30), 1)?.id, 's');
    });

    test('window selection and snapping go through the index', () {
      final c = controller();
      c.addEntities([
        LineEntity(id: 'a', a: const Pt(0, 0), b: const Pt(10, 0)),
        LineEntity(id: 'b', a: const Pt(20, 0), b: const Pt(40, 0)),
        SpotHeightEntity(id: 'c', position: const Pt(30, 30), elevation: 1),
      ]);
      expect(c.pickWindow(const Bounds(-1, -1, 11, 1)).map((e) => e.id), ['a']);
      expect(c.pickWindow(const Bounds(-1, -1, 25, 1)).map((e) => e.id), ['a']);
      expect(c.pickWindow(const Bounds(-1, -1, 25, 1), crossing: true).map((e) => e.id), ['a', 'b']);
      expect(c.pickWindow(const Bounds(-1, -1, 50, 50)).map((e) => e.id), ['a', 'b', 'c']);
      final s = Snapper(c).snap(const Pt(10.4, 0.3));
      expect(s.kind, 'endpoint');
      expect(s.point, const Pt(10, 0));
      expect(s.entityId, 'a');
      final far = Snapper(c).snap(const Pt(15, 15));
      expect(far.isSnapped, isFalse);
      // unused imports guard
      expect(const Offset(1, 1).dx, 1);
    });
  });
}
