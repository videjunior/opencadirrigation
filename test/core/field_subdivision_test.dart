import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/block_generator.dart';
import 'package:opencadirrigation/core/design/field_subdivision.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

const _u = [Pt(0, 0), Pt(300, 0), Pt(300, 200), Pt(200, 200), Pt(200, 60), Pt(100, 60), Pt(100, 200), Pt(0, 200)];
const _trapezoid = [Pt(0, 0), Pt(420, 0), Pt(420, 180), Pt(250, 260), Pt(0, 260)];

double _area(List<List<Pt>> pieces) => pieces.fold(0.0, (s, p) => s + polygonArea(p).abs());

/// Whether the blocks overlap (a point of one strictly inside another).
bool _overlap(List<FieldBlock> blocks) {
  for (var i = 0; i < blocks.length; i++) {
    final c = polygonCentroid(blocks[i].polygon);
    for (var j = 0; j < blocks.length; j++) {
      if (i != j && pointInPolygon(c, blocks[j].polygon)) return true;
    }
  }
  return false;
}

void main() {
  group('half-plane clipping', () {
    test('a concave field falls in one piece per arm', () {
      // above y = 100 the U is two arms
      final arms = clipPolygonHalfPlane(_u, const Pt(0, 1), 100);
      expect(arms, hasLength(2));
      expect(_area(arms), closeTo(2 * 100 * 100, 1e-6));
      final below = clipPolygonHalfPlane(_u, const Pt(0, 1), 100, above: false);
      expect(below, hasLength(1));
      expect(_area(below), closeTo(300 * 60 + 2 * 100 * 40, 1e-6));
      expect(_area(arms) + _area(below), closeTo(polygonArea(_u).abs(), 1e-6));
      // every piece counter-clockwise and inside the field
      for (final p in [...arms, ...below]) {
        expect(polygonArea(p), greaterThan(0));
        expect(pointInPolygon(polygonCentroid(p), _u), isTrue);
      }
      // a slab across the arms and the base, and lines missing the field
      expect(clipPolygonSlab(_u, const Pt(0, 1), 40, 120), hasLength(1));
      expect(clipPolygonHalfPlane(_u, const Pt(0, 1), 500), isEmpty);
      expect(clipPolygonHalfPlane(_u, const Pt(0, 1), -5), hasLength(1));
      // a cut through vertices and along an edge
      expect(_area(clipPolygonHalfPlane(_u, const Pt(0, 1), 60)), closeTo(2 * 100 * 140, 1e-6));
      expect(_area(clipPolygonHalfPlane(_u, const Pt(1, 0), 100, above: false)), closeTo(100 * 200, 1e-6));
    });

    test('a turned cut of a star', () {
      final star = [for (var i = 0; i < 10; i++) Pt.polar(i.isEven ? 30 : 12, math.pi * i / 5)];
      final n = Pt.polar(1, 0.3);
      final a = clipPolygonHalfPlane(star, n, 2), b = clipPolygonHalfPlane(star, n, 2, above: false);
      expect(_area(a) + _area(b), closeTo(polygonArea(star).abs(), 1e-6));
      for (final p in a) {
        for (final q in p) {
          expect(q.dot(n), greaterThanOrEqualTo(2 - 1e-9));
        }
      }
    });
  });

  group('subdivision', () {
    test('strips of equal area within the limit, roads between them', () {
      final s = subdivideField(_trapezoid, FieldSubdivisionOptions(direction: const Pt(1, 0), maxBlockArea: 2e4, roadWidth: 4, pointOfConnection: const Pt(-10, 130)));
      expect(s.fieldArea, closeTo(polygonArea(_trapezoid).abs(), 1e-6));
      expect(s.blocks.length, (s.fieldArea / 2e4).ceil());
      final areas = [for (final b in s.blocks) b.area];
      for (final a in areas) {
        expect(a, lessThanOrEqualTo(2e4 + 1e-6));
        expect(a, closeTo(areas.first, 1));
      }
      expect(_overlap(s.blocks), isFalse);
      // the field less a 4 m road at every cut
      expect(s.blocksArea, lessThan(s.fieldArea));
      expect(s.blocksArea, greaterThan(s.fieldArea - (s.blocks.length - 1) * 4 * 420 - 1));
      // strips span the field along the rows, the submain on the side of the supply
      for (final b in s.blocks) {
        expect(b.submain, SubmainPosition.start);
        expect(b.column, 0);
      }
      // laterals too long for no limit asked: none reported
      expect(s.messages, isEmpty);
    });

    test('a grid keeps every lateral within the limit', () {
      final s = subdivideField(_trapezoid, FieldSubdivisionOptions(direction: const Pt(1, 0), mode: SubdivisionMode.grid, maxBlockArea: 2e4, maxLateralLength: 150, roadWidth: 4, minBlockWidth: 15));
      expect(s.messages, isEmpty);
      for (final b in s.blocks) {
        expect(b.lateralLength, lessThanOrEqualTo(150 + 1e-6));
        expect(b.area, lessThanOrEqualTo(2e4 + 1e-6));
      }
      expect(s.blocks.map((b) => b.column).toSet().length, greaterThan(1));
      expect(_overlap(s.blocks), isFalse);
      // centre-fed blocks may be twice as long
      final c = subdivideField(_trapezoid, FieldSubdivisionOptions(direction: const Pt(1, 0), mode: SubdivisionMode.grid, maxBlockArea: 4e4, maxLateralLength: 150, centreFeed: true));
      expect(c.blocks.every((b) => b.submain == SubmainPosition.centre && b.lateralLength <= 150 + 1e-6), isTrue);
      expect(c.blocks.length, lessThan(s.blocks.length));
    });

    test('blocks from the flow and the emitter flow per hectare; an arm of the U is a block of its own', () {
      final s = subdivideField(_u, FieldSubdivisionOptions(direction: const Pt(1, 0), maxBlockFlow: 30 * m3sPerM3h, flowPerHectare: 25 * m3sPerM3h, roadWidth: 4));
      expect(s.messages, isEmpty);
      for (final b in s.blocks) {
        expect(b.flow, lessThanOrEqualTo(30 * m3sPerM3h + 1e-9));
        expect(b.flow, closeTo(b.area / 1e4 * 25 * m3sPerM3h, 1e-12));
      }
      // the arms above the base come as separate blocks
      expect(s.blocks.where((b) => polygonCentroid(b.polygon).y > 100).length, greaterThanOrEqualTo(2));
      expect(subdivideField(_u, FieldSubdivisionOptions(direction: const Pt(1, 0))).messages, contains('field_no_limit'));
      expect(subdivideField(const [Pt(0, 0), Pt(1, 1)], FieldSubdivisionOptions(direction: const Pt(1, 0))).messages, ['field_empty']);
    });

    test('the narrowest block: no more strips than the width allows', () {
      final s = subdivideField(const [Pt(0, 0), Pt(400, 0), Pt(400, 50), Pt(0, 50)], FieldSubdivisionOptions(direction: const Pt(1, 0), maxBlockArea: 1000, minBlockWidth: 10, roadWidth: 4));
      // (50 + 4) / (10 + 4) = 3 strips at most
      expect(s.blocks, hasLength(3));
      expect(s.messages.where((m) => m.startsWith('field_block_large')), hasLength(3));
    });

    test('the blocks feed the block generator: valve and submain where suggested', () {
      final p = Project();
      final s = subdivideField(_trapezoid, FieldSubdivisionOptions(direction: const Pt(0, 1), mode: SubdivisionMode.grid, maxBlockArea: 3e4, maxLateralLength: 140, roadWidth: 4, pointOfConnection: const Pt(500, 100)));
      for (final b in s.blocks) {
        final o = blockOptionsFor(b, s.direction, lateralSpacing: 1.8, isTape: true, tapeSpecId: 'tape16_10_30', valveSpecId: 'ev80', submainStub: 2);
        expect(o.submainPosition, b.submain);
        expect(o.valvePosition, b.valvePosition);
        final r = generateBlock(p, o);
        expect(r.laterals, isNotEmpty);
        expect(r.valve, isNotNull);
        // the valve is the suggested point moved out along the stub
        expect(r.valve!.position.distanceTo(b.valvePoint), lessThan(2 + 1.8 + 1e-6));
        for (final l in r.laterals) {
          final pts = (l as dynamic).points as List<Pt>;
          expect(pointInPolygon(Pt.lerp(pts.first, pts.last, 0.5), b.polygon), isTrue);
        }
      }
      // rows along y, the supply to the east: every valve at the east end of
      // its submain
      for (final b in s.blocks) {
        expect(b.valvePosition, ValvePosition.start);
        expect(b.valvePoint.x, closeTo(b.polygon.fold(-double.infinity, (m, q) => math.max(m, q.x)), 1e-6));
      }
    });
  });
}
