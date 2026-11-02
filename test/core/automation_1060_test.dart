// Automatic design, layout geometry and the design assistant: the defects of
// the sweep of 1 November 2026 (AUT-01 … AUT-30), each with a test that
// failed before its correction, and the invariants every generator keeps.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/advisor.dart';
import 'package:opencadirrigation/core/design/auto_layout.dart';
import 'package:opencadirrigation/core/design/block_generator.dart';
import 'package:opencadirrigation/core/design/design_check.dart';
import 'package:opencadirrigation/core/design/network_builder.dart';
import 'package:opencadirrigation/core/design/routing.dart';
import 'package:opencadirrigation/core/design/templates.dart';
import 'package:opencadirrigation/core/design/tree_rings.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/units.dart';

List<Pt> rect(double x0, double y0, double x1, double y1) => [Pt(x0, y0), Pt(x1, y0), Pt(x1, y1), Pt(x0, y1)];

/// Length (m) over which the polylines [a] and [b] run on top of each other
/// (collinear segments sharing a stretch).
double overlapLength(List<Pt> a, List<Pt> b) {
  var total = 0.0;
  for (var i = 1; i < a.length; i++) {
    for (var j = 1; j < b.length; j++) {
      final p = a[i - 1], q = a[i], r = b[j - 1], s = b[j];
      final d1 = q - p, d2 = s - r;
      if (d1.length < 1e-9 || d2.length < 1e-9) continue;
      if (d1.cross(d2).abs() > 1e-9 * d1.length * d2.length) continue;
      if ((r - p).cross(d1).abs() > 1e-6 * d1.length) continue;
      final t0 = (r - p).dot(d1) / d1.dot(d1), t1 = (s - p).dot(d1) / d1.dot(d1);
      final lo = (t0 < t1 ? t0 : t1).clamp(0.0, 1.0), hi = (t0 < t1 ? t1 : t0).clamp(0.0, 1.0);
      if (hi > lo) total += (hi - lo) * d1.length;
    }
  }
  return total;
}

/// Share of the rectangle [w] × [h] farther than [reach] from every line.
double uncovered(List<List<Pt>> lines, double w, double h, double reach) {
  var dry = 0, total = 0;
  for (var x = 1.0; x < w; x += 2) {
    for (var y = 1.0; y < h; y += 2) {
      final q = Pt(x, y);
      total++;
      var best = double.infinity;
      for (final l in lines) {
        for (var i = 1; i < l.length; i++) {
          final d = distanceToSegment(q, l[i - 1], l[i]);
          if (d < best) best = d;
        }
      }
      if (best > reach) dry++;
    }
  }
  return dry / total;
}

bool crossEachOther(List<List<Pt>> ls) {
  for (var i = 0; i < ls.length; i++) {
    for (var j = i + 1; j < ls.length; j++) {
      if (polylineIntersections(ls[i], ls[j]).any((x) => ls[i].every((q) => q.distanceTo(x) > 1e-6) && ls[j].every((q) => q.distanceTo(x) > 1e-6))) return true;
    }
  }
  return false;
}

void main() {
  group('AUT-01 guided blocks cover the whole polygon', () {
    const field = [Pt(0, 0), Pt(200, 0), Pt(200, 100), Pt(0, 100)];
    final guides = <String, List<Pt>>{
      'gentle contour': const [Pt(-10, 50), Pt(100, 60), Pt(210, 50)],
      'valley V': const [Pt(-10, 80), Pt(100, 20), Pt(210, 80)],
      'sharp valley V': const [Pt(-10, 95), Pt(100, 5), Pt(210, 95)],
      'contour over the middle only': const [Pt(50, 50), Pt(100, 56), Pt(150, 52)],
      'saw-tooth contour': [for (var i = 0; i <= 40; i++) Pt(-10 + 5.5 * i, 50 + 30 * (i < 20 ? 1 : -1) * (i % 20) / 20)],
    };
    for (final MapEntry(:key, :value) in guides.entries) {
      test(key, () {
        final p = Project();
        final r = generateBlock(p, BlockOptions(polygon: field, direction: const Pt(1, 0), lateralSpacing: 5, isTape: true, tapeSpecId: 'tape16', guide: value));
        final lines = [for (final e in r.laterals) (e as TapeEntity).points];
        expect(uncovered(lines, 200, 100, 5), lessThan(0.005), reason: 'every point within one lateral spacing of a lateral');
        final length = lines.fold(0.0, (s, l) => s + polylineLength(l));
        expect(length, closeTo(4000, 250), reason: 'about the field area over the spacing');
        expect(crossEachOther(lines), isFalse, reason: 'offset copies never cross');
        expect(r.messages, isEmpty);
        for (final l in lines) {
          for (final q in l) {
            expect(q.x, inInclusiveRange(-1e-6, 200 + 1e-6));
            expect(q.y, inInclusiveRange(-1e-6, 100 + 1e-6));
          }
        }
      });
    }

    test('a guide that cannot reach part of the polygon is reported', () {
      // a guide turning back on itself: the offsets of the hairpin stay
      // near it, the far corner of an L-shaped field is reached anyway or
      // reported, never silently dry
      const lField = [Pt(0, 0), Pt(120, 0), Pt(120, 40), Pt(40, 40), Pt(40, 120), Pt(0, 120)];
      final p = Project();
      final r = generateBlock(p, BlockOptions(polygon: lField, direction: const Pt(1, 0), lateralSpacing: 4, isTape: true, tapeSpecId: 'tape16', guide: const [Pt(-5, 20), Pt(125, 20)]));
      final lines = [for (final e in r.laterals) (e as TapeEntity).points];
      var dry = 0, inside = 0;
      for (var x = 1.0; x < 120; x += 2) {
        for (var y = 1.0; y < 120; y += 2) {
          if (!pointInPolygon(Pt(x, y), lField)) continue;
          inside++;
          var best = double.infinity;
          for (final l in lines) {
            for (var i = 1; i < l.length; i++) {
              best = best < distanceToSegment(Pt(x, y), l[i - 1], l[i]) ? best : distanceToSegment(Pt(x, y), l[i - 1], l[i]);
            }
          }
          if (best > 4) dry++;
        }
      }
      expect(dry / inside > guidedUncoveredLimit, r.messages.any((m) => m.startsWith('block_uncovered:')), reason: 'a dry share above the limit is always reported');
    });

    test('a mitre-limited offset of a hairpin stays near the line', () {
      const hairpin = [Pt(0, 0), Pt(200, 0), Pt(0, 2)];
      for (final d in [-17.5, 17.5]) {
        final off = offsetPolylineMitred(hairpin, d);
        final b = Bounds.ofPoints(off);
        expect(b.minX, greaterThan(-30), reason: 'd $d');
        expect(b.maxX, lessThan(200 + 17.5 + 1e-6), reason: 'no mitre spike beyond the turn (d $d)');
      }
    });
  });

  group('AUT-02 a row through a vertex of the polygon', () {
    List<double> rows(List<Pt> poly, double spacing, double first) {
      final p = Project();
      final r = generateBlock(p, BlockOptions(polygon: poly, direction: const Pt(1, 0), lateralSpacing: spacing, firstLateralOffset: first, isTape: true, tapeSpecId: 'tape16'));
      return ({for (final e in r.laterals) double.parse((e as TapeEntity).points.first.y.toStringAsFixed(3))}.toList()..sort());
    }

    test('a diamond with its side vertices on a row keeps that row', () {
      const diamond = [Pt(10, 0), Pt(20, 10), Pt(10, 20), Pt(0, 10)];
      expect(rows(diamond, 2, 2), [2, 4, 6, 8, 10, 12, 14, 16, 18]);
    });

    test('a hexagon keeps the row through its widest vertices', () {
      const hexagon = [Pt(5, 0), Pt(15, 0), Pt(20, 10), Pt(15, 20), Pt(5, 20), Pt(0, 10)];
      expect(rows(hexagon, 1.5, 1), contains(10.0));
      expect(rows(hexagon, 1.5, 1).length, 13);
    });
  });

  group('AUT-14 a centre submain keeps its stub off the laterals', () {
    for (final vp in ValvePosition.values) {
      for (final n in [6, 5]) {
        test('valve ${vp.name}, $n rows', () {
          final p = Project();
          final h = n * 5.0;
          final b = generateBlock(
            p,
            BlockOptions(
              polygon: [const Pt(0, 0), const Pt(60, 0), Pt(60, h), Pt(0, h)],
              direction: const Pt(1, 0),
              lateralSpacing: 5,
              outletSpecId: 'micro',
              nozzleId: 'm50',
              outletSpacing: 3,
              headM: 15,
              submainPosition: SubmainPosition.centre,
              valvePosition: vp,
              submainStub: 1.5,
              valveSpecId: 'ev50',
              zoneName: 'A',
            ),
          );
          final stub = b.stub!.points;
          for (final l in b.laterals) {
            expect(overlapLength(stub, (l as PolyEntity).points), 0, reason: 'the stub lies on no lateral');
            expect(distanceToSegment(b.valve!.position, l.points.first, l.points.last), greaterThan(0.5), reason: 'the valve stands off the laterals');
          }
          if (vp != ValvePosition.centre) {
            final y = b.valve!.position.y;
            expect(y < 2.5 || y > h - 2.5, isTrue, reason: 'at an end of the submain the valve stands beyond the outer rows, on the submain line');
            expect(b.valve!.position.x, closeTo(30, 1e-9));
          }
        });
      }
    }
  });

  group('AUT-15 tree rings fed from the centre with an odd count a row', () {
    for (final w in [30.0, 36.0]) {
      test('width $w', () {
        final area = [const Pt(0, 0), Pt(w, 0), Pt(w, 21), const Pt(0, 21)];
        final l = layoutTreeRings(
          area: area,
          options: TreeRingOptions(plantSpacing: 6, rowSpacing: 7, submainPosition: SubmainPosition.centre),
        );
        for (var i = 0; i < l.laterals.length; i++) {
          for (var j = i + 1; j < l.laterals.length; j++) {
            expect(overlapLength(l.laterals[i], l.laterals[j]), lessThan(1e-6), reason: 'laterals $i and $j');
          }
          final pts = l.laterals[i];
          for (var k = 2; k < pts.length; k++) {
            final a = pts[k - 1] - pts[k - 2], b = pts[k] - pts[k - 1];
            expect(a.dot(b), greaterThan(0), reason: 'lateral $i never turns back at vertex ${k - 1}');
          }
        }
        for (final t in l.trees) {
          expect(l.submain.every((q) => q.distanceTo(t) > 0.6), isTrue, reason: 'the submain passes no trunk');
        }
      });
    }
  });

  group('AUT-03 zones routed round the same exclusion stay apart', () {
    test('two zones bending round one corner of a house do not share the bend', () {
      const building = [Pt(10, 10), Pt(20, 10), Pt(20, 20), Pt(10, 20)];
      final zones = [
        [const Pt(9, 22), const Pt(22, 9)],
        [const Pt(8, 23), const Pt(23, 8)],
      ];
      final r = routeZones(zones, RouteOptions(exclusions: [building], pointOfConnection: const Pt(40, 40)));
      final vertices = [
        for (final z in r.zones) {for (final pipe in z.pipes) ...pipe.points},
      ];
      for (final a in vertices[0]) {
        for (final b in vertices[1]) {
          expect(a.distanceTo(b), greaterThan(0.3), reason: '$a of zone 1 and $b of zone 2');
        }
      }
      final p = Project();
      p.entities.add(WaterSupplyEntity(id: p.newId(), position: const Pt(40, 40), calculatePressure: true));
      for (var z = 0; z < zones.length; z++) {
        for (final h in zones[z]) {
          p.entities.add(OutletEntity(id: p.newId(), position: h, outletSpecId: 'spray', nozzleId: 's12', headM: 20, zoneName: 'Z$z'));
        }
      }
      p.entities.addAll(r.toEntities(p, zoneNames: ['Z0', 'Z1']));
      expect(NetworkBuilder(p).build().warnings.where((w) => w.startsWith('zone_overlap')), isEmpty);
    });

    test('many zones round a dense orchard of tree rings share no vertex', () {
      final rnd = math.Random(3);
      final trees = <List<Pt>>[];
      for (var i = 0; i < 40; i++) {
        final c = Pt(5 + rnd.nextDouble() * 50, 5 + rnd.nextDouble() * 40);
        trees.add([for (var k = 0; k < 12; k++) c + Pt.polar(1.2, 2 * math.pi * k / 12)]);
      }
      final heads = <Pt>[
        for (var x = 3.0; x < 60; x += 5)
          for (var y = 3.0; y < 50; y += 5)
            if (!trees.any((t) => pointInPolygon(Pt(x, y), t))) Pt(x, y),
      ];
      final zones = <List<Pt>>[[], [], [], [], [], []];
      for (final h in heads) {
        zones[(h.x / 10).floor().clamp(0, 5)].add(h);
      }
      final r = routeZones(zones, RouteOptions(exclusions: trees, pointOfConnection: const Pt(-5, -5)));
      final owner = <Pt, int>{};
      for (final z in r.zones) {
        for (final pipe in z.pipes) {
          for (final q in pipe.points) {
            final o = owner[q];
            expect(o == null || o == z.zone, isTrue, reason: 'vertex $q of zones $o and ${z.zone}');
            owner[q] = z.zone;
          }
        }
      }
    });

    test('zones joined without a valve are an error, in the check and the assistant', () {
      final p = Project();
      p.entities.add(WaterSupplyEntity(id: p.newId(), position: const Pt(-10, 0), calculatePressure: true));
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(-10, 0), const Pt(0, 0), const Pt(0, 10)], scope: HydraulicScope.mainline));
      p.entities.add(ControlValveEntity(id: p.newId(), position: const Pt(0, 0), zoneName: 'A', valveSpecId: 'ev25'));
      p.entities.add(ControlValveEntity(id: p.newId(), position: const Pt(0, 10), zoneName: 'B', valveSpecId: 'ev25'));
      // one zone pipe from each valve, meeting at a shared vertex
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(0, 0), const Pt(10, 5)], scope: HydraulicScope.zone));
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(0, 10), const Pt(10, 5)], scope: HydraulicScope.zone));
      p.entities.add(OutletEntity(id: p.newId(), position: const Pt(10, 5), outletSpecId: 'spray', nozzleId: 's12', headM: 20));
      final check = runDesignCheck(p).issues.where((i) => i.code == 'zone_overlap').toList();
      expect(check, isNotEmpty);
      expect(check.every((i) => i.severity == CheckSeverity.error), isTrue);
      final advice = buildAdvice(p).where((a) => a.code == 'zone_overlap').toList();
      expect(advice, isNotEmpty);
      expect(advice.every((a) => a.level == AdviceLevel.error), isTrue);
    });
  });

  group('AUT-06 routing round many exclusions is quick', () {
    test('120 tree rings and 200 heads in four zones', () {
      final rnd = math.Random(7);
      final trees = <List<Pt>>[];
      for (var i = 0; i < 120; i++) {
        final c = Pt(5 + rnd.nextDouble() * 90, 5 + rnd.nextDouble() * 60);
        trees.add([for (var k = 0; k < 16; k++) c + Pt.polar(1.2, 2 * math.pi * k / 16)]);
      }
      final heads = <Pt>[
        for (var x = 3.0; x < 100; x += 6)
          for (var y = 3.0; y < 70; y += 6)
            if (!trees.any((t) => pointInPolygon(Pt(x, y), t))) Pt(x, y),
      ];
      final zones = <List<Pt>>[[], [], [], []];
      for (final h in heads) {
        zones[(h.x / 25).floor().clamp(0, 3)].add(h);
      }
      final sw = Stopwatch()..start();
      final r = routeZones(zones, RouteOptions(exclusions: trees, pointOfConnection: const Pt(-5, -5)));
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(4000), reason: 'about 20 s before the exclusions were indexed');
      expect(r.messages, isEmpty);
      expect(r.zones, hasLength(4));
      // every pipe keeps out of the tree rings
      for (final z in r.zones) {
        for (final pipe in z.pipes) {
          for (var i = 1; i < pipe.points.length; i++) {
            for (final t in trees) {
              for (var k = 1; k < 10; k++) {
                final m = Pt.lerp(pipe.points[i - 1], pipe.points[i], k / 10);
                expect(pointInPolygon(m, t) && !pointOnPolygonBoundary(m, t, tol: 1e-6), isFalse);
              }
            }
          }
        }
      }
    });
  });

  group('AUT-12 the zone valve for flows outside every range', () {
    final cat = Catalog.defaultCatalog();
    test('below every minimum: the smallest valve, not the 6" one', () {
      for (final q in [0.05, 0.1]) {
        expect(pickZoneValve(cat, q * m3sPerM3h)?.id, 'ev25', reason: '$q m³/h');
      }
    });
    test('within ranges and above every maximum', () {
      expect(pickZoneValve(cat, 5 * m3sPerM3h)?.id, 'ev25');
      expect(pickZoneValve(cat, 20 * m3sPerM3h)?.id, 'ev50');
      expect(pickZoneValve(cat, 500 * m3sPerM3h)?.id, 'ev150');
    });
    test('in a gap between two ranges: the nearer one', () {
      final c = Catalog.defaultCatalog();
      for (final v in c.valves) {
        if (v.kind == ValveKind.control && v.id != 'ev25' && v.id != 'ev100') v.enabled = false;
      }
      // ev25 holds 0.2–6 m³/h, ev100 10–140: 6.5 is nearer to ev25, 9.5 to ev100
      expect(pickZoneValve(c, 6.5 * m3sPerM3h)?.id, 'ev25');
      expect(pickZoneValve(c, 9.5 * m3sPerM3h)?.id, 'ev100');
    });
  });

  group('AUT-18 routes and valves keep to the lot', () {
    test('a house on the front lot line: zone pipes, valve and mainline inside the lot', () {
      final cat = Catalog.defaultCatalog();
      final lot = rect(0, 0, 40, 30);
      final house = rect(10, -5, 25, 12);
      final l = layoutLandscape(outline: lot, exclusions: [house], family: cat.outlet('rotor')!);
      final heads = [for (final h in l.heads) h.position];
      final r = routeZones([heads], RouteOptions(exclusions: [house], pointOfConnection: const Pt(0, 30), boundary: lot));
      final region = LayoutRegion(lot);
      bool out(Pt q) => !region.contains(q) && region.distanceToBoundary(q) > 0.05;
      for (final z in r.zones) {
        expect(out(z.valve), isFalse, reason: 'the valve stays on the lot');
        for (final pipe in z.pipes) {
          for (var i = 1; i < pipe.points.length; i++) {
            for (var k = 0; k < 20; k++) {
              expect(out(Pt.lerp(pipe.points[i - 1], pipe.points[i], (k + 0.5) / 20)), isFalse, reason: 'pipe ${pipe.points}');
            }
          }
        }
      }
      final m = routeMainline(const Pt(0, 1), [const Pt(35, 1)], exclusions: [house], boundary: lot);
      for (final pipe in m) {
        for (final q in pipe.points) {
          expect(out(q), isFalse, reason: 'the mainline goes round the back of the house, not the street');
        }
      }
      // without the lot outline it takes the street, as before
      final street = routeMainline(const Pt(0, 1), [const Pt(35, 1)], exclusions: [house]);
      expect(street.any((pipe) => pipe.points.any(out)), isTrue);
    });

    test('a point of connection outside the lot enters it the short way', () {
      final lot = rect(0, 0, 40, 30);
      final m = routeMainline(const Pt(-5, 15), [const Pt(30, 15)], boundary: lot);
      expect(m.single.points, [const Pt(-5, 15), const Pt(30, 15)]);
    });
  });

  group('AUT-04 green template on a polygon of few vertices', () {
    final rotor = Catalog.defaultCatalog().outlet('rotor')!;
    test('a rectangle green gets the arcs of its densely drawn twin', () {
      final four = golfGreenLayout(family: rotor, green: const [Pt(-9, -6), Pt(9, -6), Pt(9, 6), Pt(-9, 6)]);
      final dense = golfGreenLayout(
        family: rotor,
        green: [
          for (var i = 0; i <= 18; i++) Pt(-9.0 + i, -6),
          for (var i = 1; i <= 12; i++) Pt(9, -6.0 + i),
          for (var i = 1; i <= 18; i++) Pt(9.0 - i, 6),
          for (var i = 1; i < 12; i++) Pt(-9, 6.0 - i),
        ],
      );
      expect(four.heads.length, dense.heads.length);
      for (var i = 0; i < four.heads.length; i++) {
        expect(four.heads[i].arcDeg, closeTo(dense.heads[i].arcDeg, 3), reason: 'head $i');
        expect(four.heads[i].arcDeg, greaterThan(90));
      }
      expect(four.metrics!.cu, greaterThan(75), reason: 'CU 11 % with 30° arcs at the corners before');
      expect(four.metrics!.dryPct, lessThan(5));
    });

    test('a pentagon green has no 30° arcs', () {
      final penta = golfGreenLayout(family: rotor, green: [for (var i = 0; i < 5; i++) Pt.polar(8, 2 * math.pi * i / 5)]);
      expect(penta.heads.every((h) => h.arcDeg > 60), isTrue);
      expect(penta.metrics!.cu, greaterThan(70));
    });
  });

  group('AUT-17 corner heads keep the minimum distance', () {
    for (final gap in [0.2, 0.5, 1.0, 2.0]) {
      for (final fam in ['spray', 'rotor']) {
        test('$fam, house $gap m from the lot line', () {
          final family = Catalog.defaultCatalog().outlet(fam)!;
          final o = LandscapeLayoutOptions();
          final l = layoutLandscape(outline: rect(0, 0, 40, 30), exclusions: [rect(10, gap, 25, 12)], family: family, options: o);
          var closest = double.infinity;
          for (var i = 0; i < l.heads.length; i++) {
            for (var j = i + 1; j < l.heads.length; j++) {
              closest = math.min(closest, l.heads[i].position.distanceTo(l.heads[j].position));
            }
          }
          expect(closest, greaterThanOrEqualTo(o.minSpacingFraction * l.spacing - 1e-6), reason: 'two heads 0.2 m apart before');
          expect(l.metrics!.dryPct, lessThan(2));
        });
      }
    }

    test('an area smaller than the gap keeps one head opening into it', () {
      for (final s in [0.5, 1.0]) {
        final l = layoutLandscape(outline: rect(0, 0, s, s), family: Catalog.defaultCatalog().outlet('spray')!);
        expect(l.heads, isNotEmpty);
        expect(l.metrics!.dryPct, 0, reason: 'square $s m');
      }
    });
  });

  group('AUT-27 layout metrics of awkward areas', () {
    test('Christiansen CU never below zero', () {
      final region = LayoutRegion(rect(0, 0, 18, 12));
      // one head in a corner throwing away from the area: almost all dry
      final m = evaluateHeadLayout(region, [const LayoutHead(position: Pt(0, 0), arcDeg: 30, orientationDeg: 0, flow: 1e-4, radius: 10)]);
      expect(m.cu, greaterThanOrEqualTo(0));
    });

    test('a strip narrower than the evaluation cell is still evaluated', () {
      final l = layoutLandscape(outline: rect(0, 0, 50, 0.3), family: Catalog.defaultCatalog().outlet('spray')!);
      expect(l.heads, isNotEmpty);
      expect(l.metrics!.dryPct, lessThan(100), reason: 'CU 0 and all dry with heads before');
      expect(l.metrics!.cu, greaterThan(50));
    });
  });

  group('AUT-28 fairway centrelines that turn sharply', () {
    final impact = Catalog.defaultCatalog().outlet('impact34')!;
    test('a centreline that doubles back is refused', () {
      final l = fairwayLayout(family: impact, centreline: const [Pt(0, 0), Pt(200, 0), Pt(0, 2)], width: 35);
      expect(l.heads, isEmpty, reason: '723 heads over 5 km before');
      expect(l.messages, contains('template_centreline_turn'));
    });

    for (final c in const [
      [Pt(0, 0), Pt(200, 0), Pt(200, 150)],
      [Pt(0, 0), Pt(200, 0), Pt(80, 120)],
    ]) {
      test('a dogleg keeps every head near the fairway (${c.last})', () {
        final l = fairwayLayout(family: impact, centreline: c, width: 35);
        expect(l.heads, isNotEmpty);
        final b = Bounds.ofPoints(c).inflate(40);
        expect(l.heads.every((h) => b.contains(h.position)), isTrue);
        expect(l.metrics!.cu, greaterThan(85));
      });
    }
  });
}
