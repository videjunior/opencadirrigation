import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/auto_layout.dart';
import 'package:opencadirrigation/core/design/templates.dart';
import 'package:opencadirrigation/core/hydraulics/emitter.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/units.dart';

/// A sports-field rotor with matched quarter, half, three-quarter and full
/// nozzles throwing 18, 24 and 35 m at 45 m.
OutletSpec _sportsRotor() {
  EmitterCurve q(double m3h, double r) => EmitterCurve.fromNominal(flow: m3h * m3sPerM3h, head: 45, x: 0.5, radius: r, radiusB: 0.35);
  NozzleSpec n(String id, double m3h, double r, double arc) => NozzleSpec(id: id, name: id, curve: q(m3h, r), arcDeg: arc, minHeadM: 30, maxHeadM: 60, defaultHeadM: 45);
  return OutletSpec(id: 'sport', name: 'Sports rotor', kind: OutletKind.sprinkler, nozzles: [
    for (final (r, f) in const [(18.0, 3.2), (24.0, 5.6), (35.0, 12.0)]) ...[n('f$r', f, r, 360), n('t$r', f * 0.75, r, 270), n('h$r', f / 2, r, 180), n('q$r', f / 4, r, 90)],
  ]);
}

Pt _bisector(LayoutHead h) => Pt.polar(1, degToRad(h.orientationDeg + h.arcDeg / 2));

void main() {
  final sport = _sportsRotor();
  final cat = Catalog.defaultCatalog();

  group('football pitch', () {
    test('3, 4 or 5 rows: head to head, part circles on the lines, CU above 93 %', () {
      // (rows, spacings along a row, nozzle): 105 m in steps no longer than the radius
      for (final (rows, steps, nozzle) in [(3, 3, 'f35.0'), (4, 5, 'f24.0'), (5, 6, 'f18.0')]) {
        final l = sportsPitchLayout(family: sport, rows: rows);
        expect(l.messages, isEmpty, reason: '$rows rows');
        expect(l.referenceNozzleId, nozzle);
        expect(l.rowSpacing, closeTo(68 / (rows - 1), 1e-9));
        expect(l.heads, hasLength(rows * (steps + 1)));
        expect(l.spacing, lessThanOrEqualTo(l.heads.first.radius + 1e-9));
        final corners = l.heads.where((h) => h.role == HeadRole.corner).toList();
        expect(corners, hasLength(4));
        for (final h in l.heads) {
          if (h.role == HeadRole.interior) {
            expect(h.fullCircle, isTrue);
            continue;
          }
          expect(h.arcDeg, h.role == HeadRole.corner ? 90 : 180);
          expect(_bisector(h).dot(const Pt(52.5, 34) - h.position), greaterThan(0));
        }
        expect(l.maxPrecipitationMismatch, lessThan(0.01));
        expect(l.metrics!.cu, greaterThan(93), reason: '$rows rows');
        expect(l.metrics!.oversprayPct, lessThan(3));
      }
    });

    test('a turned and moved pitch keeps its layout; rows chosen from the radius', () {
      final a = sportsPitchLayout(family: sport, rows: 5);
      final b = sportsPitchLayout(family: sport, rows: 5, origin: const Pt(100, 50), rotationDeg: 30);
      expect(b.heads.length, a.heads.length);
      expect(b.metrics!.cu, closeTo(a.metrics!.cu, 1));
      final t = Affine.rotation(degToRad(30), const Pt(100, 50));
      for (var i = 0; i < a.heads.length; i++) {
        expect(b.heads[i].position.distanceTo(t.apply(a.heads[i].position + const Pt(100, 50))), lessThan(1e-9));
        final d = normalizeDeg(b.heads[i].orientationDeg - a.heads[i].orientationDeg - 30);
        expect(math.min(d, 360 - d), lessThan(1e-6));
      }
      // automatic rows: the largest nozzle reaches 34 m, so 3 rows
      expect(sportsPitchLayout(family: sport, rows: 0).rowSpacing, closeTo(34, 1e-9));
      // a family too short for the rows says so
      expect(sportsPitchLayout(family: cat.outlet('rotor')!, rows: 5).messages, contains('template_radius_short'));
    });
  });

  test('running track infield: a lawn inside the kerb', () {
    final outline = trackInfieldOutline();
    expect(polygonArea(outline), closeTo(84.39 * 73 + math.pi * 36.5 * 36.5, 25));
    final l = runningTrackInfieldLayout(family: sport);
    expect(l.metrics!.cu, greaterThan(90));
    expect(l.heads.every((h) => l.region.signedDistance(h.position) > -1e-6), isTrue);
  });

  test('golf green: rotors outside the collar throwing onto the green, CU above 88 %', () {
    final green = ellipseOutline(Pt.zero, 30, 22, rotationDeg: 20);
    final l = golfGreenLayout(family: sport, green: green, setback: 1.5);
    expect(l.heads.length, greaterThanOrEqualTo(4));
    for (final h in l.heads) {
      // on the ring 1.5 m outside the green, the arc opening onto it
      expect(pointInPolygon(h.position, green), isFalse);
      expect(LayoutRegion(green).distanceToBoundary(h.position), closeTo(1.5, 0.3));
      expect(h.fullCircle, isFalse);
      expect(_bisector(h).dot(-h.position), greaterThan(0));
      // the head spans the green within its reach
      final toCentre = normalizeDeg(radToDeg((-h.position).angle) - h.orientationDeg);
      expect(toCentre, lessThan(h.arcDeg));
    }
    // heads round the green no farther apart than their radius
    final n = l.heads.length;
    for (var i = 0; i < n; i++) {
      expect(l.heads[i].position.distanceTo(l.heads[(i + 1) % n].position), lessThanOrEqualTo(l.heads[i].radius + 1e-6));
    }
    expect(l.metrics!.cu, greaterThan(88));
    expect(l.maxPrecipitationMismatch, lessThan(0.3));
  });

  test('tee and fairway', () {
    final tee = teeLayout(family: cat.outlet('spray')!, length: 30, width: 8, rotationDeg: 10);
    expect(tee.metrics!.cu, greaterThan(92));
    expect(tee.direction.angle, closeTo(degToRad(10), 1e-9));
    final line = [for (var i = 0; i <= 20; i++) Pt(i * 15.0, 30 * math.sin(i / 20 * math.pi))];
    final rotor = cat.outlet('rotor')!;
    final full = fairwayLayout(family: rotor, centreline: line, width: 35);
    expect(full.heads.every((h) => h.fullCircle), isTrue);
    // rows 0.866 spacings apart, staggered: equilateral triangles
    expect(full.rowSpacing, closeTo(full.spacing * math.sqrt(3) / 2, 1e-9));
    expect(full.metrics!.cu, greaterThan(85));
    final edges = fairwayLayout(family: rotor, centreline: line, width: 35, edgePartCircles: true);
    expect(edges.heads.where((h) => h.role == HeadRole.edge && h.arcDeg == 180), isNotEmpty);
    expect(edges.metrics!.cu, greaterThan(93));
    expect(edges.metrics!.oversprayPct, lessThan(full.metrics!.oversprayPct));
    expect(fairwayLayout(family: rotor, centreline: const [Pt(0, 0)], width: 30).messages, ['layout_empty']);
  });
}
