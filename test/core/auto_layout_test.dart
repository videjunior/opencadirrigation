import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/auto_layout.dart';
import 'package:opencadirrigation/core/design/block_generator.dart' show GridPattern;
import 'package:opencadirrigation/core/design/densogram.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

List<Pt> _rect(double x0, double y0, double x1, double y1) => [Pt(x0, y0), Pt(x1, y0), Pt(x1, y1), Pt(x0, y1)];
List<Pt> _circle(Pt c, double r, int n) => [for (var i = 0; i < n; i++) c + Pt.polar(r, 2 * math.pi * i / n)];

/// A 24 × 14 m kidney-ish bed outline (72 vertices, no corner).
final _bed = [for (var i = 0; i < 72; i++) Pt(12 * math.cos(2 * math.pi * i / 72), 7 * math.sin(2 * math.pi * i / 72) * (1 + 0.15 * math.cos(2 * math.pi * i / 72)))];
const _l12 = [Pt(0, 0), Pt(30, 0), Pt(30, 12), Pt(12, 12), Pt(12, 30), Pt(0, 30)];
const _l18 = [Pt(0, 0), Pt(50, 0), Pt(50, 18), Pt(20, 18), Pt(20, 40), Pt(0, 40)];

final _cat = Catalog.defaultCatalog();
OutletSpec get _rotor => _cat.outlet('rotor')!;
OutletSpec get _spray => _cat.outlet('spray')!;

/// Direction (unit) of the middle of a head's sector.
Pt _bisector(LayoutHead h) => Pt.polar(1, degToRad(h.orientationDeg + h.arcDeg / 2));

/// Farthest sampled point of the region from every head (m).
double _farthest(LandscapeLayout l, {double step = 0.5}) {
  final b = l.region.bounds;
  var worst = 0.0;
  for (var x = b.minX + step / 2; x < b.maxX; x += step) {
    for (var y = b.minY + step / 2; y < b.maxY; y += step) {
      final p = Pt(x, y);
      if (!l.region.contains(p)) continue;
      worst = math.max(worst, l.heads.fold(double.infinity, (m, h) => math.min(m, h.position.distanceTo(p))));
    }
  }
  return worst;
}

void main() {
  group('region', () {
    test('an exclusion inside the outline is a hole, one across it cuts the outline', () {
      final inside = LayoutRegion(_rect(0, 0, 40, 30), exclusions: [_rect(12, 10, 26, 20)]);
      expect(inside.loops, hasLength(2));
      expect(inside.area, closeTo(1200 - 140, 1e-6));
      expect(inside.contains(const Pt(5, 5)), isTrue);
      expect(inside.contains(const Pt(20, 15)), isFalse);
      // the hole runs clockwise: the lawn is on the left of every loop
      expect(inside.loops.where((l) => l.isHole), hasLength(1));
      final across = LayoutRegion(_rect(0, 0, 40, 30), exclusions: [_rect(15, -5, 25, 10)]);
      expect(across.loops, hasLength(1));
      expect(across.area, closeTo(1200 - 100, 1e-6));
      expect(across.contains(const Pt(20, 5)), isFalse);
      expect(across.contains(const Pt(20, 15)), isTrue);
      // a building wall on the lot line, and one that splits the lot in two
      expect(LayoutRegion(_rect(0, 0, 40, 30), exclusions: [_rect(15, 0, 25, 10)]).area, closeTo(1100, 1e-6));
      final split = LayoutRegion(_rect(0, 0, 40, 30), exclusions: [_rect(15, -5, 25, 35)]);
      expect(split.loops, hasLength(2));
      expect(split.area, closeTo(900, 1e-6));
      // overlapping exclusions count once
      expect(LayoutRegion(_rect(0, 0, 40, 30), exclusions: [_rect(5, 5, 15, 15), _rect(10, 10, 20, 20)]).area, closeTo(1200 - 175, 1e-6));
      // an exclusion over the whole outline leaves nothing
      expect(LayoutRegion(_rect(0, 0, 10, 10), exclusions: [_rect(-1, -1, 11, 11)]).isEmpty, isTrue);
    });

    test('clipLine and the distance to the boundary', () {
      final r = LayoutRegion(_rect(0, 0, 40, 30), exclusions: [_rect(12, 10, 26, 20)]);
      final spans = r.clipLine(const Pt(0, 15), const Pt(1, 0));
      expect(spans, hasLength(2));
      expect(spans[0].$1, closeTo(0, 1e-9));
      expect(spans[0].$2, closeTo(12, 1e-9));
      expect(spans[1].$1, closeTo(26, 1e-9));
      expect(spans[1].$2, closeTo(40, 1e-9));
      expect(r.distanceToBoundary(const Pt(6, 15)), closeTo(6, 1e-9));
      expect(r.distanceToBoundary(const Pt(6, 15), maxDistance: 2), 2);
      expect(r.signedDistance(const Pt(20, 15)), lessThan(0));
    });

    test('the largest inscribed circle', () {
      final (c, rad) = maximumInscribedCircle(LayoutRegion(_rect(0, 0, 40, 30)), precision: 0.01);
      expect(rad, closeTo(15, 0.02));
      expect(c.y, closeTo(15, 0.05));
      expect(c.x, inInclusiveRange(15 - 0.05, 25 + 0.05));
      final (_, rl) = maximumInscribedCircle(LayoutRegion(_l12), precision: 0.01);
      // the elbow of the L: tangent to two sides and to the inner corner
      expect(rl, closeTo(12 * math.sqrt2 / (1 + math.sqrt2), 0.05));
    });
  });

  group('matched precipitation', () {
    test('quarter, half and full circles take the nozzles of their share of the flow', () {
      final ref = _rotor.nozzle('r3')!;
      final q = fullCircleFlow(ref, 25), r = ref.curve.radius(25);
      expect(matchedPrecipitationNozzle(_rotor, 90, headM: 25, fullFlow: q, radius: r)!.nozzle.id, 'r3_90');
      expect(matchedPrecipitationNozzle(_rotor, 180, headM: 25, fullFlow: q, radius: r)!.nozzle.id, 'r3_180');
      expect(matchedPrecipitationNozzle(_rotor, 360, headM: 25, fullFlow: q, radius: r)!.nozzle.id, 'r3');
      final c = matchedPrecipitationNozzle(_rotor, 180, headM: 25, fullFlow: q, radius: r)!;
      expect(c.ratio, closeTo(1, 0.01));
      final s = _spray.nozzle('s12')!;
      expect(matchedPrecipitationNozzle(_spray, 90, headM: 20, fullFlow: fullCircleFlow(s, 20), radius: s.curve.radius(20))!.nozzle.id, 's12q');
      // a full circle never takes a part-circle nozzle
      expect(matchedPrecipitationNozzle(_spray, 360, headM: 20, fullFlow: 1e-9, radius: 3.7)!.nozzle.arcDeg, 360);
    });

    test('the reference nozzle comes with matched part circles and fits the area', () {
      expect(referenceNozzle(_rotor, 25)!.id, 'r3');
      expect(referenceNozzle(_spray, 20)!.id, 's12');
      expect(matchedPartCircles(_rotor, _rotor.nozzle('r3')!, 25), 2);
      expect(matchedPartCircles(_cat.outlet('impact34')!, _cat.outlet('impact34')!.nozzle('i5.0')!, 30), 0);
      // too wide for every nozzle: the smallest radius
      expect(referenceNozzle(_rotor, 25, maxRadius: 3)!.id, 'r1.5');
    });
  });

  group('landscape layout', () {
    test('rectangle: corners, edges and interior head to head, CU above 94 %', () {
      final l = layoutLandscape(outline: _rect(0, 0, 40, 30), family: _rotor);
      expect(l.messages, isEmpty);
      expect(l.referenceNozzleId, 'r3');
      expect(l.spacing, closeTo(10, 1e-9));
      final corners = l.heads.where((h) => h.role == HeadRole.corner).toList();
      expect(corners, hasLength(4));
      for (final c in corners) {
        expect(c.arcDeg, closeTo(90, 1e-6));
        expect(c.nozzleId, 'r3_90');
        // the quarter opens into the lawn: its bisector points to the middle
        expect(_bisector(c).dot(const Pt(20, 15) - c.position), greaterThan(0));
      }
      final edges = l.heads.where((h) => h.role == HeadRole.edge).toList();
      expect(edges, hasLength(10));
      for (final e in edges) {
        expect(e.arcDeg, closeTo(180, 1e-6));
        expect(e.nozzleId, 'r3_180');
        expect(_bisector(e).dot(const Pt(20, 15) - e.position), greaterThan(0));
      }
      expect(l.heads.where((h) => h.role == HeadRole.interior).every((h) => h.fullCircle && h.nozzleId == 'r3'), isTrue);
      // head to head: every head throws at least to its nearest neighbour
      for (final h in l.heads) {
        final nn = l.heads.where((o) => !identical(o, h)).fold(double.infinity, (m, o) => math.min(m, o.position.distanceTo(h.position)));
        expect(nn, lessThanOrEqualTo(h.radius + 1e-6));
      }
      final m = l.metrics!;
      expect(m.cu, greaterThan(94));
      expect(m.du, greaterThan(92));
      expect(m.oversprayPct, lessThan(1));
      expect(l.maxPrecipitationMismatch, lessThan(0.05));
      // gross rate: 0.7 m³/h over every 10 × 10 m
      expect(l.grossRateMmH, closeTo(7.0, 0.3));
    });

    test('rectangles that the spacing does not divide, and a turned one', () {
      final odd = layoutLandscape(outline: _rect(0, 0, 37, 23), family: _rotor);
      expect(odd.metrics!.cu, greaterThan(93));
      expect(_farthest(odd), lessThan(0.75 * odd.spacing));
      final a = layoutLandscape(outline: _rect(0, 0, 40, 30), family: _rotor);
      final turned = layoutLandscape(outline: [for (final p in _rect(0, 0, 40, 30)) p.rotate(math.pi / 5)], family: _rotor);
      expect(turned.heads.length, a.heads.length);
      expect(turned.metrics!.cu, closeTo(a.metrics!.cu, 1.5));
    });

    test('triangular pattern on a rectangle', () {
      final l = layoutLandscape(outline: _rect(0, 0, 40, 30), family: _rotor, options: LandscapeLayoutOptions(pattern: GridPattern.triangular));
      expect(l.metrics!.cu, greaterThan(90));
      expect(l.rowSpacing, lessThan(l.spacing));
    });

    test('L-shapes: both arms treated alike, every point within reach, CU above 85 %', () {
      for (final (poly, min) in [(_l12, 85.0), (_l18, 88.0)]) {
        final l = layoutLandscape(outline: poly, family: _rotor);
        expect(l.metrics!.cu, greaterThan(min), reason: '$poly');
        expect(_farthest(l), lessThan(0.75 * l.spacing), reason: '$poly');
        // the re-entrant corner gets a three-quarter circle
        final inner = l.heads.firstWhere((h) => h.position.distanceTo(poly[3]) < 1e-6);
        expect(inner.arcDeg, closeTo(270, 1e-6));
        // no two heads closer than the minimum
        for (var i = 0; i < l.heads.length; i++) {
          for (var j = i + 1; j < l.heads.length; j++) {
            expect(l.heads[i].position.distanceTo(l.heads[j].position), greaterThanOrEqualTo(0.4 * l.spacing - 1e-6));
          }
        }
      }
      // the 12 m arms: a row of heads down each, or none in either
      final l = layoutLandscape(outline: _l12, family: _rotor);
      final lower = l.heads.where((h) => h.position.y > 3 && h.position.y < 9 && h.position.x > 14 && h.position.x < 28).length;
      final upper = l.heads.where((h) => h.position.x > 3 && h.position.x < 9 && h.position.y > 14 && h.position.y < 28).length;
      expect(lower, upper);
    });

    test('a curved bed of sprays: heads round the curve with their own arcs, CU above 88 %', () {
      final l = layoutLandscape(outline: _bed, family: _spray);
      expect(l.referenceNozzleId, 's12');
      expect(l.heads.where((h) => h.role == HeadRole.corner), isEmpty);
      final edges = l.heads.where((h) => h.role == HeadRole.edge).toList();
      expect(edges.length, greaterThan(10));
      // a convex curve: the edge's arc is a little under a half circle
      expect(edges.where((h) => h.arcDeg < 180).length, greaterThan(edges.length * 0.8));
      for (final e in edges) {
        expect(pointOnPolygonBoundary(e.position, l.region.outline, tol: 1e-6), isTrue);
      }
      expect(l.metrics!.cu, greaterThan(88));
      expect(l.metrics!.dryPct, lessThan(2));
    });

    test('a round lawn and a ring round a tree bed', () {
      expect(layoutLandscape(outline: _circle(Pt.zero, 20, 64), family: _rotor).metrics!.cu, greaterThan(88));
      final ring = layoutLandscape(outline: _circle(Pt.zero, 30, 72), exclusions: [_circle(Pt.zero, 8, 36)], family: _rotor);
      expect(ring.metrics!.cu, greaterThan(88));
      expect(ring.heads.any((h) => h.position.length < 8 - 1e-6), isFalse);
    });

    test('a house in the lawn: three-quarter circles at its corners, nothing inside, CU above 85 %', () {
      final house = _rect(12, 10, 26, 20);
      final l = layoutLandscape(outline: _rect(0, 0, 40, 30), exclusions: [house], family: _rotor);
      expect(l.heads.any((h) => pointInPolygon(h.position, house) && !pointOnPolygonBoundary(h.position, house)), isFalse);
      for (final c in house) {
        final h = l.heads.firstWhere((h) => h.position.distanceTo(c) < 1e-6);
        expect(h.arcDeg, closeTo(270, 1e-6));
        // facing away from the house
        expect(_bisector(h).dot(c - const Pt(19, 15)), greaterThan(0));
      }
      expect(l.metrics!.cu, greaterThan(85));
      expect(l.metrics!.oversprayPct, lessThan(2));
      final edge = layoutLandscape(outline: _rect(0, 0, 40, 30), exclusions: [_rect(15, -5, 25, 10)], family: _rotor);
      expect(edge.metrics!.cu, greaterThan(84));
      expect(edge.heads.any((h) => edge.region.signedDistance(h.position) < -1e-6), isFalse);
    });

    test('a small bed gets no ring of heads: the lawn heads keep out and throw over it', () {
      final bed = _circle(const Pt(15, 12), 4, 24);
      final l = layoutLandscape(outline: _rect(0, 0, 50, 35), exclusions: [bed, _rect(30, 18, 42, 26)], family: _rotor);
      expect(l.heads.any((h) => pointInPolygon(h.position, bed) || pointOnPolygonBoundary(h.position, bed, tol: 1e-6)), isFalse);
      expect(l.metrics!.cu, greaterThan(83));
      // with every exclusion ringed the bed gets heads on its outline
      final ringed = layoutLandscape(outline: _rect(0, 0, 50, 35), exclusions: [bed], family: _rotor, options: LandscapeLayoutOptions(smallExclusionFactor: 0));
      expect(ringed.heads.any((h) => pointOnPolygonBoundary(h.position, bed, tol: 1e-6)), isTrue);
    });

    test('a family without matched part circles gets full circles inset half a spacing', () {
      final impact = _cat.outlet('impact34')!;
      final l = layoutLandscape(outline: _rect(0, 0, 80, 60), family: impact);
      expect(l.messages, contains('layout_full_circles'));
      expect(l.heads.every((h) => h.fullCircle), isTrue);
      expect(l.heads.every((h) => l.region.distanceToBoundary(h.position) > 0.2 * l.spacing), isTrue);
      expect(l.maxPrecipitationMismatch, lessThan(0.01));
      expect(l.metrics!.cu, greaterThan(82));
      // part circles forced on: corners get the full nozzle and a mismatch
      final forced = layoutLandscape(outline: _rect(0, 0, 80, 60), family: impact, options: LandscapeLayoutOptions(partCircles: PartCircleMode.always));
      expect(forced.messages.any((m) => m.startsWith('layout_mp_mismatch:')), isTrue);
    });

    test('spacing rules', () {
      final wide = layoutLandscape(outline: _rect(0, 0, 60, 40), family: _rotor, options: LandscapeLayoutOptions(spacingRule: SpacingRule.percentOfDiameter, spacingPercent: 60));
      expect(wide.spacing, closeTo(12, 1e-9));
      final fixed = layoutLandscape(outline: _rect(0, 0, 60, 40), family: _rotor, options: LandscapeLayoutOptions(spacingRule: SpacingRule.fixed, spacingM: 8));
      expect(fixed.spacing, 8);
      expect(fixed.heads.length, greaterThan(wide.heads.length));
      final clamped = layoutLandscape(outline: _rect(0, 0, 60, 40), family: _rotor, options: LandscapeLayoutOptions(spacingRule: SpacingRule.fixed, spacingM: 50));
      expect(clamped.messages, contains('layout_spacing_clamped'));
      expect(clamped.spacing, closeTo(20, 1e-9));
    });

    test('degenerate inputs give a message, not an exception', () {
      expect(layoutLandscape(outline: const [Pt(0, 0), Pt(1, 1)], family: _rotor).messages, ['layout_empty']);
      expect(layoutLandscape(outline: _rect(0, 0, 10, 10), family: _cat.outlet('drip_pc')!).messages, ['layout_no_nozzle']);
      expect(layoutLandscape(outline: _rect(0, 0, 1e5, 1e5), family: _spray).messages, ['layout_too_many_heads']);
      final narrow = layoutLandscape(outline: _rect(0, 0, 60, 6), family: _rotor);
      expect(narrow.messages, contains('layout_radius_large'));
    });

    test('the same input gives the same layout', () {
      String key(LandscapeLayout l) => [for (final h in l.heads) '${h.position}|${h.arcDeg}|${h.orientationDeg}|${h.nozzleId}'].join(';');
      final a = layoutLandscape(outline: _l18, exclusions: [_rect(30, 4, 36, 10)], family: _rotor);
      final b = layoutLandscape(outline: _l18, exclusions: [_rect(30, 4, 36, 10)], family: _rotor);
      expect(key(a), key(b));
    });

    test('the outlets: the layout as the densogram of a project sees it', () {
      final l = layoutLandscape(outline: _l18, family: _rotor);
      final p = Project();
      final outlets = l.toOutlets(p, zoneName: (i) => 'Z${i % 3}');
      expect(outlets, hasLength(l.heads.length));
      for (var i = 0; i < outlets.length; i++) {
        expect(outlets[i].position, l.heads[i].position);
        expect(outlets[i].nozzleId, l.heads[i].nozzleId);
        expect(outlets[i].headM, l.headM);
        expect(outlets[i].zoneName, 'Z${i % 3}');
        expect(p.outletWatersArea(outlets[i], _l18), isTrue);
      }
      p.entities
        ..addAll(outlets)
        ..add(AreaEntity(id: p.newId(), points: _l18));
      final d = computeDensogram(p, options: DensogramOptions(cellSize: l.metrics!.cellSize));
      expect(d.stats.cu, closeTo(l.metrics!.cu, 1.5));
      expect(d.stats.du, closeTo(l.metrics!.du, 2.5));
    });

    test('thousands of heads in well under a second', () {
      final sw = Stopwatch()..start();
      final l = layoutLandscape(outline: const [Pt(0, 0), Pt(600, 0), Pt(600, 250), Pt(300, 400), Pt(0, 400)], exclusions: [_rect(100, 100, 160, 140), _rect(400, 50, 450, 120)], family: _rotor);
      final ms = sw.elapsedMilliseconds;
      expect(l.heads.length, greaterThan(2000));
      expect(l.metrics!.cu, greaterThan(94));
      // generous for a debug test run (about 50 ms compiled)
      expect(ms, lessThan(1500));
    });
  });
}
