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
import 'package:opencadirrigation/core/design/auto_fix.dart';
import 'package:opencadirrigation/core/design/field_subdivision.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/design/zoning.dart';
import 'package:opencadirrigation/core/design/pivot.dart';
import 'package:opencadirrigation/core/design/proposal.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/model/proposal_settings.dart';

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
        // nothing left dry; since 1.6.0 (MOD-26) the rows of the saw-tooth
        // that lie 10 m or more from it have the loops of its teeth cut out,
        // which block_guide_offset says (the smooth guides keep plain copies)
        expect(r.messages.where((m) => !m.startsWith('block_guide_offset:')), isEmpty);
        expect(r.messages.any((m) => m.startsWith('block_guide_offset:')), key == 'saw-tooth contour', reason: '${r.messages}');
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

  group('AUT-05 outlines that cross themselves', () {
    const bow = [Pt(0, 0), Pt(40, 10), Pt(40, 0), Pt(0, 20)];
    const left = [Pt(0, 0), Pt(80 / 3, 20 / 3), Pt(0, 20)];
    const right = [Pt(80 / 3, 20 / 3), Pt(40, 10), Pt(40, 0)];
    test('a bow tie is found and cut into its two triangles', () {
      expect(polygonSelfCrossings(bow), isNotEmpty);
      expect(polygonSelfCrossings(rect(0, 0, 10, 10)), isEmpty);
      final parts = simplePolygonParts(bow);
      expect(parts, hasLength(2));
      final areas = [for (final q in parts) polygonArea(q)]..sort();
      expect(areas.every((a) => a > 0), isTrue, reason: 'every part counter-clockwise');
      expect(areas.first, closeTo(polygonArea(right).abs(), 1e-6));
      expect(areas.last, closeTo(polygonArea(left).abs(), 1e-6));
    });

    test('the layout of a bow tie waters both lobes with arcs opening into them', () {
      final l = layoutLandscape(outline: bow, family: Catalog.defaultCatalog().outlet('spray')!);
      expect(l.region.area, closeTo(polygonArea(left).abs() + polygonArea(right).abs(), 1e-3), reason: '200 m² of the real 333 before');
      expect(l.messages, contains('layout_self_intersect'));
      for (final h in l.heads.where((h) => !h.fullCircle)) {
        final mid = h.position + Pt.polar(0.3, degToRad(h.orientationDeg + h.arcDeg / 2));
        expect(pointInPolygon(mid, left) || pointInPolygon(mid, right), isTrue, reason: 'arc of the head at ${h.position} opens out of the area');
      }
      // a symmetric bow tie is not "empty"
      final sym = layoutLandscape(outline: const [Pt(0, 0), Pt(20, 20), Pt(20, 0), Pt(0, 20)], family: Catalog.defaultCatalog().outlet('spray')!);
      expect(sym.heads, isNotEmpty);
      expect(sym.region.area, closeTo(200, 1e-6));
    });

    test('the design check flags the area and its correction splits it', () {
      final p = Project();
      final a = AreaEntity(id: p.newId(), points: List.of(bow), name: 'Gramado', crop: 'grama');
      p.entities.add(a);
      final issue = runDesignCheck(p).issues.where((i) => i.code == 'area_self_intersect').single;
      expect(issue.severity, CheckSeverity.error);
      final advice = buildAdvice(p).where((x) => x.code == 'area_self_intersect').single;
      expect(advice.level, AdviceLevel.error);
      expect(advice.fixes, [FixKind.splitArea]);
      expect(advice.autoFixable, isTrue);
      final res = applyFix(p, advice, FixKind.splitArea);
      expect(res.ok, isTrue);
      final areas = p.entities.whereType<AreaEntity>().toList();
      expect(areas, hasLength(2));
      expect(areas.first.id, a.id, reason: 'the first part keeps the id');
      expect(areas.every((x) => x.crop == 'grama'), isTrue);
      expect(areas.fold(0.0, (s, x) => s + x.area), closeTo(polygonArea(left).abs() + polygonArea(right).abs(), 1e-6));
      expect(runDesignCheck(p).issues.where((i) => i.code == 'area_self_intersect'), isEmpty);
    });

    test('a field that crosses itself is subdivided lobe by lobe', () {
      final sub = subdivideField(const [Pt(0, 0), Pt(400, 100), Pt(400, 0), Pt(0, 200)], FieldSubdivisionOptions(direction: const Pt(1, 0), maxBlockArea: 5000));
      expect(sub.messages, contains('field_self_intersect'));
      expect(sub.fieldArea, closeTo(100 * 333.3333, 1));
      expect(sub.blocksArea, greaterThan(0.85 * sub.fieldArea));
    });
  });

  group('AUT-16 pipes and laterals on top of each other', () {
    Project base() {
      final p = Project();
      p.entities.add(WaterSupplyEntity(id: p.newId(), position: const Pt(-20, 0), calculatePressure: true));
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(-20, 0), const Pt(0, 0)], scope: HydraulicScope.mainline));
      p.entities.add(ControlValveEntity(id: p.newId(), position: const Pt(0, 0), zoneName: 'A', valveSpecId: 'ev50'));
      return p;
    }

    List<CheckIssue> overlaps(Project p) => runDesignCheck(p).issues.where((i) => i.code == 'pipes_overlap').toList();

    test('a zone pipe pasted twice: found, and the correction keeps one', () {
      final p = base();
      final a = PipeEntity(id: p.newId(), points: [const Pt(0, 0), const Pt(30, 0)], scope: HydraulicScope.zone);
      final b = PipeEntity(id: p.newId(), points: [const Pt(30, 0), const Pt(0, 0)], scope: HydraulicScope.zone);
      p.entities.addAll([a, b]);
      p.entities.add(SpraylineEntity(id: p.newId(), points: [const Pt(30, 0), const Pt(30, 40)], outletSpecId: 'micro', nozzleId: 'm50', headM: 15, spacing: 4, offset: 2));
      expect(overlaps(p).single.entityIds.toSet(), {a.id, b.id});
      final advice = buildAdvice(p).where((x) => x.code == 'pipes_overlap').single;
      expect(advice.fixes, [FixKind.removeDuplicates]);
      expect(applyFix(p, advice, FixKind.removeDuplicates).ok, isTrue);
      expect(p.entities.whereType<PipeEntity>().where((e) => e.scope == HydraulicScope.zone), hasLength(1));
      expect(overlaps(p), isEmpty);
    });

    test('two pipes sharing 20 m: found, no automatic correction', () {
      final p = base();
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(0, 0), const Pt(30, 0)], scope: HydraulicScope.zone));
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(10, 0), const Pt(40, 0)], scope: HydraulicScope.zone));
      final o = overlaps(p).single;
      expect(o.at!.x, closeTo(20, 1e-6));
      expect(buildAdvice(p).where((x) => x.code == 'pipes_overlap').single.fixes, isEmpty);
    });

    test('pipes end to end, crossing or of different scopes are no overlap', () {
      final p = base();
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(0, 0), const Pt(30, 0)], scope: HydraulicScope.zone));
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(30, 0), const Pt(60, 0)], scope: HydraulicScope.zone));
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(15, -10), const Pt(15, 10)], scope: HydraulicScope.zone));
      // a mainline in the trench of a zone pipe is not joined to it either
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(5, 0), const Pt(25, 0)], scope: HydraulicScope.mainline));
      expect(overlaps(p), isEmpty);
    });

    test('a lateral that doubles back on itself', () {
      final p = base();
      p.entities.add(TapeEntity(id: p.newId(), points: [const Pt(0, 0), const Pt(10, 0), const Pt(4, 0), const Pt(4, 20)], tapeSpecId: 'tape16'));
      expect(overlaps(p), hasLength(1));
    });
  });

  group('AUT-06 field subdivision of long outlines is quick', () {
    List<Pt> wiggly(int n) => [for (var i = 0; i < n; i++) Pt.polar(560 + 15 * math.sin(7 * 2 * math.pi * i / n) + 5 * math.sin(31 * 2 * math.pi * i / n), 2 * math.pi * i / n)];
    test('100 ha with 2000 vertices in blocks of 1 ha', () {
      final sw = Stopwatch()..start();
      final s = subdivideField(wiggly(2000), FieldSubdivisionOptions(direction: const Pt(1, 0), maxBlockArea: 1e4));
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(1500), reason: 'about 10 s before the area profile');
      // as many strips as the 10 m minimum width allows (the larger blocks say so)
      expect(s.blocks.length, greaterThan(70));
      expect(s.blocks.every((b) => b.area <= 1e4 * (1 + 1e-6) || s.messages.contains('field_block_large:${s.blocks.indexOf(b)}')), isTrue);
    });

    test('equal strips: the cuts give blocks of equal area', () {
      for (final f in [
        rect(0, 0, 400, 300),
        const [Pt(0, 0), Pt(420, 0), Pt(420, 180), Pt(250, 260), Pt(0, 260)],
        wiggly(600),
        // far from the origin, as in projected coordinates
        [for (final q in wiggly(300)) q + const Pt(700000, 7400000)],
      ]) {
        final s = subdivideField(f, FieldSubdivisionOptions(direction: Pt.polar(1, 0.3), maxBlockArea: 2e4, roadWidth: 0));
        final areas = [for (final b in s.blocks) b.area];
        expect(areas.fold(0.0, (a, b) => a + b), closeTo(s.fieldArea, s.fieldArea * 1e-6));
        final mean = areas.fold(0.0, (a, b) => a + b) / areas.length;
        // strips cut into several pieces aside, every strip has the same area
        final byStrip = <int, double>{};
        for (final b in s.blocks) {
          byStrip[b.strip] = (byStrip[b.strip] ?? 0) + b.area;
        }
        for (final a in byStrip.values) {
          expect(a, closeTo(byStrip.values.first, mean * 1e-4));
        }
      }
    });
  });

  group('AUT-06 routing one zone at a time', () {
    test('the stepwise router gives what routeZones gives, a zone a step', () {
      const building = [Pt(10, 10), Pt(20, 10), Pt(20, 20), Pt(10, 20)];
      final zones = [
        [const Pt(2, 2), const Pt(8, 3), const Pt(4, 8)],
        [const Pt(25, 25), const Pt(28, 22), const Pt(30, 28)],
        <Pt>[],
        [const Pt(22, 5), const Pt(27, 4)],
      ];
      final o = RouteOptions(exclusions: [building], pointOfConnection: const Pt(-5, -5));
      final whole = routeZones(zones, o);
      final r = ZoneRouter(zones, o);
      var steps = 0;
      while (r.step()) {
        steps++;
        expect(r.routed, lessThanOrEqualTo(zones.length));
      }
      expect(steps, 3, reason: 'one step a zone with heads; the mainline comes with the last call');
      expect(r.step(), isFalse);
      final stepwise = r.result;
      expect(stepwise.zones.length, whole.zones.length);
      for (var z = 0; z < whole.zones.length; z++) {
        expect(stepwise.zones[z].valve, whole.zones[z].valve);
        expect([for (final p in stepwise.zones[z].pipes) p.points], [for (final p in whole.zones[z].pipes) p.points]);
      }
      expect([for (final p in stepwise.mainline) p.points], [for (final p in whole.mainline) p.points]);
      expect(ZoneRouter(const [], o).step(), isFalse);
    });
  });

  group('AUT-07 fix automatically and a booster pump on the mains', () {
    test('no pump is put on a public network: the user decides it', () async {
      final t = I18n('en');
      final p = buildExample(ExampleId.garden, t.call, lang: 'en');
      p.entities.removeWhere((e) => e is PumpEntity);
      p.entities.whereType<WaterSupplyEntity>().first
        ..calculatePressure = false
        ..designHeadM = 15
        ..maxHeadM = 40;
      final rep = await runAutoFix(p, () async => Designer(p, label: t.call).designAll(), label: t.call);
      expect(p.entities.whereType<PumpEntity>(), isEmpty, reason: 'a 1 hp pump was inserted on its own before');
      expect(rep.applied.where((f) => f.key == 'fixed.insertPump'), isEmpty);
      final pending = rep.decisions.where((a) => a.fixes.first == FixKind.choosePump).toList();
      expect(pending, isNotEmpty, reason: 'listed for the user to decide');
      expect(needsDecision(p, pending.first, FixKind.choosePump, rep.results), isTrue);
      // the button applies it
      expect(applyFix(p, pending.first, FixKind.choosePump, results: rep.results, label: t.call).key, 'fixed.insertPump');
      expect(p.entities.whereType<PumpEntity>(), hasLength(1));
    });
  });

  group('AUT-08 fix automatically and items off their pipe', () {
    Project lawn(double tol, Pt head, {String zone = ''}) {
      final p = Project();
      p.params.connectTolerance = tol;
      p.entities.add(WaterSupplyEntity(id: p.newId(), position: const Pt(-20, 0), calculatePressure: true));
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(-20, 0), const Pt(0, 0)], scope: HydraulicScope.mainline));
      p.entities.add(ControlValveEntity(id: p.newId(), position: const Pt(0, 0), zoneName: 'A', valveSpecId: 'ev25'));
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(0, 0), const Pt(30, 0)], scope: HydraulicScope.zone));
      p.entities.add(OutletEntity(id: p.newId(), position: const Pt(30, 0), outletSpecId: 'rotor', nozzleId: 'r3', headM: 25, zoneName: 'A'));
      p.entities.add(OutletEntity(id: p.newId(), position: head, outletSpecId: 'rotor', nozzleId: 'r3', headM: 25, zoneName: zone));
      return p;
    }

    for (final (tol, y) in [(0.05, 1.8), (0.3, 5.0)]) {
      test('a head $y m off the pipe stays where it is and gets a short pipe (tolerance $tol m)', () async {
        final p = lawn(tol, Pt(15, y));
        final head = p.entities.whereType<OutletEntity>().last;
        final rep = await runAutoFix(p, () async => null);
        expect(head.position, Pt(15, y), reason: 'moved ${y.toStringAsFixed(1)} m before');
        expect(rep.applied.map((f) => f.key), contains('fixed.connectPipe'));
        final stub = p.entities.whereType<PipeEntity>().last;
        expect(stub.points.last, head.position);
        expect(stub.points.first.y, closeTo(0, 1e-9));
        expect(NetworkBuilder(p).build().unconnectedEntities, isNot(contains(head.id)));
      });
    }

    test('a head of zone A is not piped to the pipe of zone B', () {
      final p = lawn(0.05, const Pt(15, 1.5), zone: 'A');
      // zone B's pipe passes nearer to the head
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(-20, 3), const Pt(0, 3)], scope: HydraulicScope.mainline));
      p.entities.add(ControlValveEntity(id: p.newId(), position: const Pt(0, 3), zoneName: 'B', valveSpecId: 'ev25'));
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(0, 3), const Pt(30, 3)], scope: HydraulicScope.zone));
      final head = p.entities.whereType<OutletEntity>().firstWhere((o) => o.position == const Pt(15, 1.5));
      final plan = connectTarget(p, head)!;
      expect(plan.pipe, isTrue);
      expect(plan.to.y, closeTo(0, 1e-9), reason: 'its own zone A, 1.5 m away, not zone B 1.5 m away the other side');
    });

    test('a valve or a lateral end farther than twice the tolerance is left to the button', () async {
      final p = lawn(0.05, const Pt(30, 0));
      final valve = p.entities.whereType<ControlValveEntity>().single;
      valve.position = const Pt(0, 1.5);
      final rep = await runAutoFix(p, () async => null);
      expect(valve.position, const Pt(0, 1.5), reason: 'moving a valve 1.5 m may change the zone it feeds');
      expect(rep.applied.where((f) => f.key == 'fixed.connect'), isEmpty);
      final left = rep.remaining.where((a) => a.code == 'unconnected' && a.entityIds.contains(valve.id)).toList();
      expect(left.isEmpty || left.first.fixes.contains(FixKind.connect), isTrue, reason: 'the button still offers it');
    });
  });

  group('AUT-09 dividing the zones into more system flows', () {
    test('the user\'s names and first start are kept, the plan fits in a day or is refused', () {
      final t = I18n('en');
      final p = buildExample(ExampleId.golf, t.call, lang: 'en');
      final r0 = Designer(p, label: t.call).designAll();
      final s = p.entities.whereType<WaterSupplyEntity>().first;
      final largest = r0.zones.values.map((z) => z.totalFlow).reduce(math.max);
      s.designFlow = largest * 1.05;
      for (final f in p.systemFlows) {
        f.durationHours = 6;
      }
      final names = {for (final f in p.systemFlows) f.name};
      final first = p.systemFlows.map((f) => f.startHour).reduce(math.min);
      final r = Designer(p, label: t.call).designAll();
      final plan = splitFlowsPlan(p, r, s, t.call)!;
      expect(plan.every((f) => names.any((n) => f.name.startsWith(n))), isTrue, reason: 'names were "Flow N" before: ${plan.map((f) => f.name)}');
      expect(plan.first.startHour, first);
      expect(plan.every((f) => f.startHour >= 0 && f.startHour < 24), isTrue, reason: 'hours 28 and 34 before');
      final valves = {for (final v in p.entities.whereType<ControlValveEntity>()) v.id};
      expect({for (final f in plan) ...f.valveIds}.containsAll(valves), isTrue, reason: 'every zone in a flow');
      final total = plan.fold(0.0, (a, f) => a + f.durationHours);
      final a = buildAdvice(p, results: r).firstWhere(
        (x) => x.fixes.contains(FixKind.splitFlows),
        orElse: () => Advice(code: 'supply_flow_exceeded', raw: 'supply_flow_exceeded', level: AdviceLevel.warning, entityIds: [s.id]),
      );
      expect(needsDecision(p, a, FixKind.splitFlows, r), isTrue, reason: 'the user has flows of their own');
      final res = applyFix(p, a, FixKind.splitFlows, results: r, label: t.call);
      if (total > 24) {
        expect(res.key, 'fixfail.flowsPastDay');
      } else {
        expect(res.ok, isTrue);
      }
      // longer flows than a day fit: refused with the hours it would take
      for (final f in p.systemFlows) {
        f.durationHours = 10;
      }
      final res2 = applyFix(p, a, FixKind.splitFlows, results: r, label: t.call);
      expect(res2.key, 'fixfail.flowsPastDay');
    });
  });

  group('AUT-10 supply design values above the maximums', () {
    test('the design comes down to the limit, by hand only', () {
      final p = Project();
      final s = WaterSupplyEntity(id: p.newId(), position: Pt.zero, calculatePressure: false, designHeadM: 40, maxHeadM: 30, designFlow: 8 / 3600, maxFlow: 5 / 3600);
      p.entities.add(s);
      final a = buildAdvice(p).firstWhere((x) => x.code == 'supply_limits');
      expect(a.fixes, [FixKind.capSupplyDesign]);
      expect(a.autoFixable, isFalse, reason: 'it raised the well limit to the design flow on its own before');
      expect(applyFix(p, a, FixKind.capSupplyDesign).ok, isTrue);
      expect(s.maxFlow, closeTo(5 / 3600, 1e-12));
      expect(s.designFlow, closeTo(5 / 3600, 1e-12));
      expect(s.maxHeadM, 30);
      expect(s.designHeadM, 30);
      expect(buildAdvice(p).where((x) => x.code == 'supply_limits'), isEmpty);
    });
  });

  group('AUT-11 optimisation and warnings', () {
    DesignScore score(double cost, List<String> warnings, {int errors = 0}) {
      final r = DesignResults(timestamp: DateTime(2026))
        ..annualCapitalCost = cost
        ..messages.addAll(warnings);
      final advice = [
        for (final w in warnings) Advice(code: w, raw: w, level: AdviceLevel.warning),
        for (var i = 0; i < errors; i++) Advice(code: 'no_supply', raw: 'no_supply', level: AdviceLevel.error),
      ];
      return DesignScore(r, advice);
    }

    test('a cheaper design with a new warning is not better', () {
      final base = score(1000, ['velocity_exceeded']);
      expect(score(800, ['velocity_exceeded', 'surge_rating_exceeded']).betterThan(base), isFalse);
      expect(score(800, ['velocity_exceeded', 'velocity_exceeded']).betterThan(base), isFalse, reason: 'one more of the same');
      expect(score(800, ['velocity_exceeded']).betterThan(base), isTrue);
      expect(score(1000, []).betterThan(base), isTrue, reason: 'as cheap, one warning less');
      expect(score(1200, ['surge_rating_exceeded']).betterThan(score(900, ['surge_rating_exceeded'], errors: 1)), isTrue, reason: 'fewer errors first');
      expect(score(800, ['velocity_exceeded', 'surge_rating_exceeded']).newWarnings(base), ['surge_rating_exceeded']);
    });

    test('a step that adds a warning is taken back, the project as it was', () async {
      final p = Project();
      p.params.sizingMethod = SizingMethod.greedy;
      // a design whose LP sizing is cheaper but brings water hammer
      Future<DesignResults?> fake() async {
        final lp = p.params.sizingMethod == SizingMethod.lp;
        final r = DesignResults(timestamp: DateTime(2026))..annualCapitalCost = lp ? 700 : 1000;
        if (lp) r.messages.add('surge_rating_exceeded');
        return r;
      }

      final rep = await runOptimize(p, fake, options: const OptimizeOptions(choosePumps: false, resizeValves: false));
      expect(rep.improved, isFalse, reason: 'kept as "better" before for being cheaper');
      expect(rep.rejected.map((f) => f.key), contains('fixed.lpSizing'));
      expect(p.params.sizingMethod, SizingMethod.greedy, reason: 'the step was taken back');
    });
  });

  group('AUT-13 largest zone flow without the supply\'s flow', () {
    test('the usual flow of the family, not the largest valve', () {
      final p = Project();
      final cat = p.catalog;
      final supply = WaterSupplyEntity(id: p.newId(), position: Pt.zero, calculatePressure: true);
      p.entities.add(supply);
      final spray = defaultMaxZoneFlow(p, family: cat.outlet('spray'));
      expect(spray.typical, isTrue);
      expect(spray.flow * 3600, closeTo(3.5, 1e-9), reason: '300 m³/h (the 6" valve) before');
      expect(defaultMaxZoneFlow(p, family: cat.outlet('rotor')).flow * 3600, closeTo(5, 1e-9));
      // an L-shaped lawn of sprays (about 64 m³/h) falls in many zones, not one
      final lawn = [const Pt(0, 0), const Pt(40, 0), const Pt(40, 15), const Pt(15, 15), const Pt(15, 50), const Pt(0, 50)];
      final family = cat.outlet('spray')!;
      final l = layoutLandscape(outline: lawn, family: family);
      final z = zoneByFlow(zoneItemsOf(l, family), ZoningOptions(maxZoneFlow: spray.flow));
      expect(z.zones.length, greaterThan(10));
      expect(pickZoneValve(cat, z.maxFlow)?.id, 'ev25', reason: 'a 1" valve, not a 3" one');
      // with the supply's flow, that one (within the largest valve)
      supply.designFlow = 3 / 3600;
      final given = defaultMaxZoneFlow(p, family: family);
      expect(given.typical, isFalse);
      expect(given.flow * 3600, closeTo(3, 1e-9));
    });
  });

  group('AUT-21 elevations of the report in the units of the project', () {
    test('a pivot rise and the pipe ends in feet', () {
      final t = I18n('en');
      final p = buildExample(ExampleId.garden, t.call, lang: 'en');
      p.params.units = Units.us;
      final r = Designer(p, label: t.call).designAll();
      r.pivots['pv'] = analyzePivot(
        const PivotSpec(kind: PivotKind.pivot, lengthM: 300, endThrowM: 0),
        id: 'pv',
        name: 'Pivot',
        groundRiseAt: (d) => d / 100,
      );
      final tables = buildReportTables(
        project: p,
        results: r,
        labels: ReportLabels(t: t.call, has: t.has, warning: (w) => t.warning(w)),
      );
      final pivots = tables.firstWhere((x) => x.key == 'pivots');
      final col = pivots.headers.indexWhere((h) => h.startsWith(t('rep.rise')));
      expect(pivots.headers[col], contains('(ft)'));
      expect((pivots.rows.single[col] as RNum).value, closeTo(3 / metersPerFoot, 1e-6), reason: '3 m showed as "3 ft" before');
      final pipes = tables.firstWhere((x) => x.key == 'pipes');
      final za = pipes.headers.indexWhere((h) => h.startsWith(t('rep.zStart')));
      expect(pipes.headers[za], contains('(ft)'));
      final seg = r.zones.values.expand((z) => z.pipes).first;
      final row = pipes.rows.firstWhere((x) => x[2] == seg.segmentIndex && (x[5] as RNum).value == (RNum(Units.us.lengthFromSi(seg.length), 1)).value);
      expect((row[za] as RNum).value, closeTo(seg.elevationA / metersPerFoot, 1e-6));
    });
  });

  group('AUT-25 trenches of the networks the automatic tools draw', () {
    test('a mainline without a depth is dug as buried pipe; generated submains are buried', () {
      final p = Project();
      p.entities.add(PipeEntity(id: 'main', points: [Pt.zero, const Pt(100, 0)], scope: HydraulicScope.mainline, pipeSpecId: 'pvc100'));
      p.entities.add(PipeEntity(id: 'zone', points: [Pt.zero, const Pt(0, 30)], scope: HydraulicScope.zone, pipeSpecId: 'pvc50'));
      final rows = trenchRows(p, ProposalSettings());
      expect(rows, hasLength(1), reason: 'no trench at all before');
      expect(rows.single.scope, HydraulicScope.mainline);
      expect(rows.single.length, closeTo(100, 1e-9));
      expect(rows.single.depth, greaterThan(defaultMainlineDepthM));
      expect(scheduleTasks(p, ProposalSettings()).map((k) => k.key), containsAll(['trench', 'backfill']));
      // a block of the subdivision gets its submain and stub buried
      final b = generateBlock(p, BlockOptions(polygon: rect(0, 0, 60, 30), direction: const Pt(1, 0), lateralSpacing: 1.5, isTape: true, tapeSpecId: 'tape16', submainDepth: defaultZonePipeDepthM));
      expect(b.submain!.depth, defaultZonePipeDepthM);
      expect(b.stub!.depth, defaultZonePipeDepthM);
      expect(b.laterals.whereType<TapeEntity>(), isNotEmpty);
      // routed zones: zone pipes and mainline as deep as asked
      final routed = routeZones([
        [const Pt(5, 5), const Pt(10, 5)],
      ], RouteOptions(pointOfConnection: const Pt(-5, 0)));
      final es = routed.toEntities(p, depth: defaultZonePipeDepthM, mainlineDepth: defaultMainlineDepthM).whereType<PipeEntity>().toList();
      expect(es.where((e) => e.scope == HydraulicScope.zone).every((e) => e.depth == defaultZonePipeDepthM), isTrue);
      expect(es.where((e) => e.scope == HydraulicScope.mainline).every((e) => e.depth == defaultMainlineDepthM), isTrue);
    });
  });

  group('AUT-22 spacing and uniformity of the sprinklers', () {
    test('the two spacings of a grid of heads', () {
      expect(
        gridSpacings([
          for (var i = 0; i < 6; i++)
            for (var j = 0; j < 4; j++) Pt(10.0 * i, 10.0 * j),
        ]),
        (10.0, 10.0),
      );
      final (a, b) = gridSpacings([
        for (var i = 0; i < 6; i++)
          for (var j = 0; j < 4; j++) Pt(12.0 * i, 18.0 * j),
      ]);
      expect((a, b), (12.0, 18.0));
      expect(gridSpacings([for (var i = 0; i < 6; i++) Pt(5.0 * i, 0)]), (5.0, null), reason: 'a single row');
    });

    test('the pasture laterals 18 m apart with a 13 m throw are reported; with 14 m they are not', () {
      final t = I18n('en');
      final p = buildExample(ExampleId.pasture, t.call, lang: 'en');
      expect(runDesignCheck(p).issues.where((i) => i.code == 'zone_spacing_wide'), isEmpty, reason: 'the example throws 14 m now');
      for (final l in p.entities.whereType<SpraylineEntity>()) {
        l.nozzleId = 'i4.0';
      }
      final wide = runDesignCheck(p).issues.where((i) => i.code == 'zone_spacing_wide').toList();
      expect(wide, hasLength(3), reason: 'no message at all before');
      expect(wide.first.value, contains('12 × 18 m'));
      expect(buildAdvice(p).where((a) => a.code == 'zone_spacing_wide').every((a) => a.level == AdviceLevel.warning), isTrue);
    });

    test('a tee of half circles 5 m apart and 6 m across is watered unevenly', () {
      final p = Project();
      final tee = rect(-40, 12, -10, 18);
      p.entities.add(AreaEntity(id: p.newId(), points: tee, name: 'Tee'));
      for (var i = 0; i <= 6; i++) {
        p.entities.add(OutletEntity(id: p.newId(), position: Pt(-40.0 + 5 * i, 12), outletSpecId: 'spray', nozzleId: 's12h', headM: 20, arcDeg: 180, orientationDeg: 0));
        p.entities.add(OutletEntity(id: p.newId(), position: Pt(-40.0 + 5 * i, 18), outletSpecId: 'spray', nozzleId: 's12h', headM: 20, arcDeg: 180, orientationDeg: 180));
      }
      final low = checkAreaUniformity(p);
      expect(low, hasLength(1), reason: 'CU 65 %, 12 % dry, and nothing said before');
      expect(low.single.code, 'area_uniformity_low');
      expect(low.single.value, startsWith('Tee: CU'));
    });

    test('the golf example: green and tee head to head, every area evenly watered', () {
      final t = I18n('en');
      final p = buildExample(ExampleId.golf, t.call, lang: 'en');
      final issues = runDesignCheck(p).issues.map((i) => i.code).toList();
      expect(issues, isNot(contains('area_uniformity_low')));
      expect(issues, isNot(contains('zone_spacing_wide')));
      final green = p.entities.whereType<OutletEntity>().where((o) => o.zoneName == t('ex.go.green')).toList();
      expect(green, hasLength(8));
      expect(green.every((o) => o.arcDeg < 360), isTrue, reason: 'part circles opening onto the green, not full circles on its edge');
      final tee = p.entities.whereType<OutletEntity>().where((o) => o.zoneName == t('ex.go.tee')).toList();
      // no two neighbours farther apart than the throw
      for (final o in tee) {
        final d = tee.where((x) => x != o).map((x) => x.position.distanceTo(o.position)).reduce(math.min);
        expect(d, lessThanOrEqualTo(3.75 + 1e-9));
      }
    });
  });

  group('AUT-26 zones mixing emitters of different rates', () {
    Project zone() {
      final p = Project();
      p.entities.add(WaterSupplyEntity(id: p.newId(), position: const Pt(-20, 0), calculatePressure: true));
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(-20, 0), const Pt(-2, 0)], scope: HydraulicScope.mainline));
      p.entities.add(ControlValveEntity(id: p.newId(), position: const Pt(-2, 0), zoneName: 'A', valveSpecId: 'ev50'));
      return p;
    }

    bool mixed(Project p) => runDesignCheck(p).issues.any((i) => i.code == 'zone_mixed_emitters');

    /// Tapes [a] then [b], a metre apart, fed from a submain along x = 0.
    Project tapes(String a, String b) {
      final p = zone();
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(-2, 0), const Pt(0, 0), const Pt(0, 1), const Pt(0, 2), const Pt(0, 3)], scope: HydraulicScope.zone));
      for (var k = 0; k < 4; k++) {
        p.entities.add(TapeEntity(id: p.newId(), points: [Pt(0, k.toDouble()), Pt(40, k.toDouble())], tapeSpecId: k < 2 ? a : b));
      }
      return p;
    }

    test('drip tapes of very different rates in one zone', () {
      // 1.71 L/h every 0.2 m against 2.4 L/h every 0.75 m: 8.6 and 3.2 L/h a metre
      expect(mixed(tapes('tape16_16_20', 'drip16_24_75')), isTrue, reason: 'drip was left out of the comparison before');
      // 1.07 L/h every 0.3 m and 1.6 L/h every 0.5 m apply about the same
      expect(mixed(tapes('tape16_10_30', 'drip16_16_50')), isFalse);
    });

    test('rotors of two nozzles, each spaced for its own throw, are no mix', () {
      final p = zone();
      final pts = <Pt>[const Pt(-2, 0)];
      void grid(String nozzle, double s, double x0) {
        for (var i = 0; i < 3; i++) {
          for (var j = 0; j < 3; j++) {
            final q = Pt(x0 + s * i, s * j);
            pts.add(q);
            p.entities.add(OutletEntity(id: p.newId(), position: q, outletSpecId: 'rotor', nozzleId: nozzle, headM: 25));
          }
        }
      }

      grid('r1.5', 8, 0); // 8 m throw on an 8 m grid
      grid('r3', 10, 40); // 10 m throw on a 10 m grid
      p.entities.add(PipeEntity(id: p.newId(), points: pts, scope: HydraulicScope.zone));
      expect(mixed(p), isFalse, reason: 'flagged before: the rate of both was taken on the 10 m circle');
      // sprays among rotors still are a mix
      p.entities.add(OutletEntity(id: p.newId(), position: pts.last + const Pt(4, 0), outletSpecId: 'spray', nozzleId: 's12', headM: 20));
      p.entities.add(OutletEntity(id: p.newId(), position: pts.last + const Pt(8, 0), outletSpecId: 'spray', nozzleId: 's12', headM: 20));
      (p.entities.whereType<PipeEntity>().last).points.addAll([pts.last + const Pt(4, 0), pts.last + const Pt(8, 0)]);
      expect(mixed(p), isTrue);
    });
  });

  group('AUT-20 zoning by hydrozone', () {
    test('sprays of a sunny lawn and of a shrub bed never share a valve', () {
      final family = Catalog.defaultCatalog().outlet('spray')!;
      final lot = rect(0, 0, 40, 20);
      final lawn = AreaEntity(id: 'lawn', points: rect(0, 0, 20, 20), name: 'Lawn', kc: 0.8);
      final bed = AreaEntity(id: 'bed', points: rect(20, 0, 40, 20), name: 'Shrubs', plantWaterUse: 'low');
      expect(hydrozoneOf(lawn), 'high');
      expect(hydrozoneOf(bed), 'low');
      expect(hydrozoneOf(AreaEntity(id: 'x', points: lot, kc: 0.5)), 'moderate');
      final l = layoutLandscape(outline: lot, family: family);
      final z = zoneByFlow(zoneItemsOf(l, family, areas: [lawn, bed]), ZoningOptions(maxZoneFlow: 4 / 3600));
      for (final g in z.zones) {
        final sides = {
          for (final i in g.items)
            if (l.heads[i].position.x < 20 - 1e-6) 'lawn' else if (l.heads[i].position.x > 20 + 1e-6) 'bed',
        };
        expect(sides.length, lessThanOrEqualTo(1), reason: 'zone ${g.classKey} mixes the lawn and the bed');
      }
      // without the areas, one class: zones may straddle the two
      final mixed = zoneByFlow(zoneItemsOf(l, family), ZoningOptions(maxZoneFlow: 4 / 3600));
      expect(mixed.zones.map((g) => g.classKey).toSet(), hasLength(1));
    });
  });

  group('AUT-19 exclusions inside blocks, fields and orchards', () {
    final pond = [for (var i = 0; i < 16; i++) const Pt(50, 30) + Pt.polar(8, 2 * math.pi * i / 16)];
    bool crossesPond(List<Pt> l) {
      for (var i = 1; i < l.length; i++) {
        for (var k = 1; k < 20; k++) {
          final q = Pt.lerp(l[i - 1], l[i], k / 20);
          if (pointInPolygon(q, pond) && !pointOnPolygonBoundary(q, pond, tol: 1e-6)) return true;
        }
      }
      return false;
    }

    for (final guided in [false, true]) {
      test('a block of tape round a pond${guided ? ' (laterals along a guide)' : ''}', () {
        final p = Project();
        final r = generateBlock(
          p,
          BlockOptions(
            polygon: rect(0, 0, 100, 60),
            direction: const Pt(1, 0),
            lateralSpacing: 2,
            isTape: true,
            tapeSpecId: 'tape16_10_30',
            exclusions: [pond],
            guide: guided ? const [Pt(-5, 2), Pt(105, 6)] : null,
            valveSpecId: 'ev50',
          ),
        );
        final lines = [for (final e in r.laterals) (e as TapeEntity).points];
        expect(lines.any(crossesPond), isFalse, reason: 'the laterals crossed the pond before');
        // the rows beyond the pond are fed: every lateral joins the network
        p.entities.addAll(r.all);
        p.entities.add(WaterSupplyEntity(id: p.newId(), position: r.valve!.position + const Pt(-5, 0), calculatePressure: true));
        p.entities.add(PipeEntity(id: p.newId(), points: [r.valve!.position + const Pt(-5, 0), r.valve!.position], scope: HydraulicScope.mainline));
        final unconnected = NetworkBuilder(p).build().unconnectedEntities;
        expect(r.laterals.where((e) => unconnected.contains(e.id)), isEmpty);
        // the ground round the pond is still covered
        var dry = 0, n = 0;
        for (var x = 1.0; x < 100; x += 2) {
          for (var y = 1.0; y < 60; y += 2) {
            final q = Pt(x, y);
            if (pointInPolygon(q, pond)) continue;
            n++;
            var best = double.infinity;
            for (final l in lines) {
              for (var i = 1; i < l.length; i++) {
                best = math.min(best, distanceToSegment(q, l[i - 1], l[i]));
              }
            }
            if (best > 2) dry++;
          }
        }
        expect(dry / n, lessThan(0.02));
      });
    }

    test('a field with a pond: the blocks share the net area and keep out of it', () {
      final field = rect(0, 0, 200, 120);
      final big = [for (var i = 0; i < 16; i++) const Pt(100, 60) + Pt.polar(20, 2 * math.pi * i / 16)];
      final o = FieldSubdivisionOptions(direction: const Pt(1, 0), maxBlockArea: 5000, roadWidth: 0, exclusions: [big]);
      final s = subdivideField(field, o);
      final net = 200 * 120 - polygonArea(big).abs();
      expect(s.fieldArea, closeTo(net, 1e-6), reason: 'the pond counted as field before');
      expect(s.blocksArea, closeTo(net, 1));
      for (final b in s.blocks) {
        expect(b.area, lessThanOrEqualTo(5000 * (1 + 1e-6)));
      }
      final p = Project();
      for (final b in s.blocks) {
        final r = generateBlock(p, blockOptionsFor(b, s.direction, lateralSpacing: 2, isTape: true, tapeSpecId: 'tape16', exclusions: [big]));
        for (final e in r.laterals) {
          final l = (e as TapeEntity).points;
          for (var i = 1; i < l.length; i++) {
            expect(pointInPolygon(Pt.lerp(l[i - 1], l[i], 0.5), big), isFalse);
          }
        }
      }
    });

    test('no tree of the planting grid in the pond', () {
      final l = layoutTreeRings(
        area: rect(0, 0, 100, 60),
        options: TreeRingOptions(plantSpacing: 5, rowSpacing: 6, exclusions: [pond]),
      );
      expect(l.trees, isNotEmpty);
      expect(l.trees.where((t) => pointInPolygon(t, pond)), isEmpty, reason: 'trees were planted in the pond before');
      expect(l.trees.every((t) => pond.every((q) => true) && distanceToSegment(t, pond.first, pond[1]) >= 0), isTrue);
    });
  });

  group('AUT-23 subdivision of concave and triangular fields', () {
    test('a U field: its base and arms are subdivided apart', () {
      const u = [Pt(0, 0), Pt(300, 0), Pt(300, 200), Pt(200, 200), Pt(200, 60), Pt(100, 60), Pt(100, 200), Pt(0, 200)];
      final s = subdivideField(u, FieldSubdivisionOptions(direction: const Pt(1, 0), maxBlockArea: 1e4));
      expect(s.blocks.length, lessThanOrEqualTo(6), reason: '8 blocks before, 6 of them of 0.42 ha');
      expect(s.blocks.every((b) => b.area <= 1e4 * (1 + 1e-6)), isTrue);
      expect(s.blocks.every((b) => b.area >= 0.6e4), isTrue, reason: 'no half blocks');
      for (var i = 0; i < s.blocks.length; i++) {
        for (var j = 0; j < s.blocks.length; j++) {
          if (i != j) expect(pointInPolygon(polygonCentroid(s.blocks[i].polygon), s.blocks[j].polygon), isFalse);
        }
      }
    });

    test('a triangle in a grid: columns by the lateral length first', () {
      const tri = [Pt(0, 0), Pt(400, 0), Pt(0, 300)];
      final s = subdivideField(tri, FieldSubdivisionOptions(direction: const Pt(1, 0), mode: SubdivisionMode.grid, maxBlockArea: 1e4, maxLateralLength: 120));
      expect(s.blocks.length, lessThanOrEqualTo(8), reason: '12 blocks of 0.45 ha before');
      expect(s.blocks.every((b) => b.area <= 1e4 * (1 + 1e-6) && b.lateralLength <= 120 + 1e-6), isTrue);
      expect(s.messages, isEmpty);
    });

    test('a wiggly outline is not cut at every bump', () {
      final pts = [for (var i = 0; i < 600; i++) Pt.polar(560 + 15 * math.sin(7 * 2 * math.pi * i / 600) + 5 * math.sin(31 * 2 * math.pi * i / 600), 2 * math.pi * i / 600)];
      final s = subdivideField(pts, FieldSubdivisionOptions(direction: const Pt(1, 0), maxBlockArea: 5e4));
      expect(s.blocks.length, lessThanOrEqualTo(20));
    });
  });

  group('AUT-24 zoning by flow close to the fewest zones', () {
    test('562 sprays in zones of 2 and 4.5 m³/h', () {
      final family = Catalog.defaultCatalog().outlet('spray')!;
      final l = layoutLandscape(outline: rect(0, 0, 100, 70), family: family);
      for (final (cap, before) in [(2.0, 199), (4.5, 85)]) {
        final z = zoneByFlow(zoneItemsOf(l, family), ZoningOptions(maxZoneFlow: cap / 3600));
        final least = (l.totalFlow / (cap / 3600) - 1e-9).ceil();
        expect(z.zones.length, lessThan(before), reason: '$before zones before (at least $least)');
        expect(z.zones.length, lessThanOrEqualTo((least * 1.18).ceil()));
        expect(z.maxFlow, lessThanOrEqualTo(cap / 3600 * (1 + 1e-9)));
        // every zone in one piece and every head in a zone
        expect(z.zoneOf.every((k) => k >= 0), isTrue);
      }
    });
  });

  group('AUT-30 invariants of every generator', () {
    /// A supply and a mainline to [valve], then the checks every generated
    /// network passes: nothing on top of anything, no zones joined, nothing
    /// left unconnected.
    void sound(Project p, Pt valve, String what) {
      p.entities.add(WaterSupplyEntity(id: p.newId(), position: valve + const Pt(-6, -6), calculatePressure: true));
      p.entities.add(PipeEntity(id: p.newId(), points: [valve + const Pt(-6, -6), valve + const Pt(-6, 0), valve], scope: HydraulicScope.mainline));
      final codes = runDesignCheck(p).issues.map((i) => '${i.code} ${i.entityIds}').toList();
      expect(codes.where((c) => c.startsWith('pipes_overlap') || c.startsWith('zone_overlap') || c.startsWith('unconnected')), isEmpty, reason: what);
    }

    final shapes = <String, List<Pt>>{
      'rectangle': rect(0, 0, 60, 30),
      'diamond': const [Pt(30, 0), Pt(60, 20), Pt(30, 40), Pt(0, 20)],
      'L': const [Pt(0, 0), Pt(60, 0), Pt(60, 20), Pt(25, 20), Pt(25, 45), Pt(0, 45)],
    };
    for (final MapEntry(key: name, value: poly) in shapes.entries) {
      for (final pos in SubmainPosition.values) {
        for (final vp in ValvePosition.values) {
          test('block of tape, $name, submain ${pos.name}, valve ${vp.name}', () {
            final p = Project();
            final b = generateBlock(
              p,
              BlockOptions(
                polygon: poly,
                direction: const Pt(1, 0),
                lateralSpacing: 2,
                firstLateralOffset: 2,
                isTape: true,
                tapeSpecId: 'tape16_10_30',
                submainPosition: pos,
                valvePosition: vp,
                valveSpecId: 'ev50',
              ),
            );
            p.entities.addAll(b.all);
            sound(p, b.valve!.position, '$name ${pos.name} ${vp.name}');
            // every point of the polygon within one spacing of a lateral
            final lines = [for (final e in b.laterals) (e as TapeEntity).points];
            final bb = Bounds.ofPoints(poly);
            for (var x = bb.minX + 0.5; x < bb.maxX; x += 3) {
              for (var y = bb.minY + 0.5; y < bb.maxY; y += 3) {
                final q = Pt(x, y);
                if (!pointInPolygon(q, poly)) continue;
                var best = double.infinity;
                for (final l in lines) {
                  for (var i = 1; i < l.length; i++) {
                    best = math.min(best, distanceToSegment(q, l[i - 1], l[i]));
                  }
                }
                expect(best, lessThanOrEqualTo(2 + 1e-6), reason: '$name: $q');
              }
            }
          });
        }
      }
    }

    for (final w in [30.0, 36.0, 42.0]) {
      test('tree rings fed from the centre, $w m wide', () {
        final p = Project();
        final l = layoutTreeRings(
          area: rect(0, 0, w, 21),
          options: TreeRingOptions(plantSpacing: 6, rowSpacing: 7, submainPosition: SubmainPosition.centre),
        );
        p.entities.addAll(l.toEntities(p, tapeSpecId: 'tape16_10_30', valveSpecId: 'ev25', zoneName: 'A'));
        sound(p, l.valve!, 'rings $w');
      });
    }

    test('zones routed round a house share no vertex and none is left unconnected', () {
      final family = Catalog.defaultCatalog().outlet('spray')!;
      final lot = rect(0, 0, 40, 30), house = rect(12, 10, 26, 20);
      final layout = layoutLandscape(outline: lot, exclusions: [house], family: family);
      final z = zoneByFlow(zoneItemsOf(layout, family), ZoningOptions(maxZoneFlow: 3 / 3600));
      final r = routeZones([
        for (final g in z.zones) [for (final i in g.items) layout.heads[i].position],
      ], RouteOptions(exclusions: [house], pointOfConnection: const Pt(-6, -6), boundary: lot));
      final p = Project();
      final names = [for (var k = 0; k < z.zones.length; k++) 'Z$k'];
      p.entities.addAll(layout.toOutlets(p, zoneName: (i) => names[z.zoneOf[i]]));
      p.entities.addAll(r.toEntities(p, zoneNames: names));
      p.entities.add(WaterSupplyEntity(id: p.newId(), position: const Pt(-6, -6), calculatePressure: true));
      final codes = runDesignCheck(p).issues.map((i) => i.code).toSet();
      expect(codes.intersection({'pipes_overlap', 'zone_overlap', 'unconnected'}), isEmpty);
    });
  });
}
