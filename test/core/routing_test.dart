import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/auto_layout.dart';
import 'package:opencadirrigation/core/design/routing.dart';
import 'package:opencadirrigation/core/design/zoning.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/units.dart';

import '../support/perf.dart';

List<Pt> _rect(double x0, double y0, double x1, double y1) => [Pt(x0, y0), Pt(x1, y0), Pt(x1, y1), Pt(x0, y1)];

/// Graph of the vertices of [pipes]: (vertex count, edge count, connected).
(int, int, bool) _graph(List<RoutedPipe> pipes) {
  final adj = <Pt, Set<Pt>>{};
  var edges = 0;
  for (final p in pipes) {
    for (var i = 1; i < p.points.length; i++) {
      adj.putIfAbsent(p.points[i - 1], () => {}).add(p.points[i]);
      adj.putIfAbsent(p.points[i], () => {}).add(p.points[i - 1]);
      edges++;
    }
  }
  if (adj.isEmpty) return (0, 0, true);
  final seen = <Pt>{adj.keys.first};
  final queue = [adj.keys.first];
  for (var h = 0; h < queue.length; h++) {
    for (final n in adj[queue[h]]!) {
      if (seen.add(n)) queue.add(n);
    }
  }
  return (adj.length, edges, seen.length == adj.length);
}

/// Whether segment ab crosses the inside of [poly].
bool _crossesInside(Pt a, Pt b, List<Pt> poly) {
  for (var k = 1; k < 20; k++) {
    final m = Pt.lerp(a, b, k / 20);
    if (pointInPolygon(m, poly) && !pointOnPolygonBoundary(m, poly, tol: 1e-6)) return true;
  }
  return false;
}

/// Heads of a rotor lawn grouped into zones of at most [maxM3h].
(LandscapeLayout, List<List<Pt>>) _zones(List<Pt> lawn, double maxM3h, {List<List<Pt>> exclusions = const []}) {
  final family = Catalog.defaultCatalog().outlet('rotor')!;
  final layout = layoutLandscape(outline: lawn, exclusions: exclusions, family: family);
  final z = zoneByFlow(zoneItemsOf(layout, family), ZoningOptions(maxZoneFlow: maxM3h * m3sPerM3h));
  return (
    layout,
    [
      for (final g in z.zones) [for (final i in g.items) layout.heads[i].position],
    ],
  );
}

void main() {
  test('every zone is a tree from its valve with a vertex at every head', () {
    final (layout, zones) = _zones(_rect(0, 0, 40, 30), 3);
    final r = routeZones(zones, RouteOptions(pointOfConnection: const Pt(-8, -6), direction: layout.direction));
    expect(r.messages, isEmpty);
    expect(r.zones, hasLength(zones.length));
    for (final z in r.zones) {
      final vertices = {for (final p in z.pipes) ...p.points};
      for (final h in zones[z.zone]) {
        expect(vertices, contains(h));
      }
      expect(vertices, contains(z.valve));
      expect(z.pipes.every((p) => p.scope.name == 'zone' && p.zone == z.zone), isTrue);
      final (v, e, connected) = _graph(z.pipes);
      expect(connected, isTrue);
      expect(e, v - 1, reason: 'a tree');
      expect(z.maxPathLength, greaterThan(0));
      expect(z.maxPathLength, lessThanOrEqualTo(z.length + 1e-9));
    }
    // a zone pipe never runs over a head or a valve of another zone
    for (final z in r.zones) {
      for (final p in z.pipes) {
        for (var i = 1; i < p.points.length; i++) {
          for (var o = 0; o < zones.length; o++) {
            if (o == z.zone) continue;
            for (final h in [...zones[o], r.zones[o].valve]) {
              expect(distanceToSegment(h, p.points[i - 1], p.points[i]), greaterThanOrEqualTo(0.3 - 1e-9));
            }
          }
        }
      }
    }
    // the mainline: a tree from the point of connection through every valve
    final (_, e, connected) = _graph(r.mainline);
    expect(connected, isTrue);
    final mv = {for (final p in r.mainline) ...p.points};
    expect(mv, contains(const Pt(-8, -6)));
    for (final z in r.zones) {
      expect(mv, contains(z.valve));
    }
    expect(e, mv.length - 1);
    expect(r.crossings, 0);
  });

  test('valves on a given mainline, apart from each other', () {
    final (layout, zones) = _zones(_rect(0, 0, 60, 30), 3);
    const main = [Pt(-5, -4), Pt(65, -4)];
    final r = routeZones(zones, RouteOptions(mainline: main, direction: layout.direction));
    expect(r.mainline, isEmpty);
    final vs = [for (final z in r.zones) z.valve]..sort((a, b) => a.x.compareTo(b.x));
    for (final v in vs) {
      expect(distanceToSegment(v, main[0], main[1]), lessThan(1e-9));
    }
    for (var i = 1; i < vs.length; i++) {
      expect(vs[i].distanceTo(vs[i - 1]), greaterThanOrEqualTo(1.5 - 1e-9));
    }
  });

  test('a manifold at the point of connection', () {
    final (_, zones) = _zones(_rect(0, 0, 40, 30), 2);
    final r = routeZones(zones, RouteOptions(pointOfConnection: const Pt(-6, 15), placement: ValvePlacement.manifold));
    final vs = [for (final z in r.zones) z.valve];
    for (var i = 0; i < vs.length; i++) {
      expect(vs[i].distanceTo(const Pt(-6, 15)), lessThan(1.5 * vs.length + 2));
      for (var j = i + 1; j < vs.length; j++) {
        expect(vs[i].distanceTo(vs[j]), greaterThanOrEqualTo(1.5 - 1e-9));
      }
    }
    expect(_graph(r.mainline).$3, isTrue);
  });

  test('pipes go round a building', () {
    final house = _rect(12, 10, 26, 20);
    final (layout, zones) = _zones(_rect(0, 0, 40, 30), 3, exclusions: [house]);
    final r = routeZones(zones, RouteOptions(pointOfConnection: const Pt(19, -8), exclusions: [house], direction: layout.direction));
    for (final p in [for (final z in r.zones) ...z.pipes, ...r.mainline]) {
      for (var i = 1; i < p.points.length; i++) {
        expect(_crossesInside(p.points[i - 1], p.points[i], house), isFalse, reason: '${p.points[i - 1]} ${p.points[i]}');
      }
    }
    // a mainline round the house reaches a valve beyond it
    final m = routeMainline(const Pt(19, -8), [const Pt(19, 25)], exclusions: [house]);
    expect(_graph(m).$3, isTrue);
    expect({for (final p in m) ...p.points}, contains(const Pt(19, 25)));
    for (final p in m) {
      for (var i = 1; i < p.points.length; i++) {
        expect(_crossesInside(p.points[i - 1], p.points[i], house), isFalse);
      }
    }
  });

  test('the smallest zone valve for the flow', () {
    final cat = Catalog.defaultCatalog();
    expect(pickZoneValve(cat, 3 * m3sPerM3h)!.id, 'ev25');
    expect(pickZoneValve(cat, 10 * m3sPerM3h)!.id, 'ev40');
    expect(pickZoneValve(cat, 1000 * m3sPerM3h)!.id, 'ev150');
    expect(pickZoneValve(Catalog(), 1), isNull);
  });

  test('without a point of connection the valves stand by their zones', () {
    final (_, zones) = _zones(_rect(0, 0, 40, 30), 3);
    final r = routeZones(zones, RouteOptions());
    expect(r.messages, contains('route_no_connection'));
    expect(r.mainline, isEmpty);
    expect(r.zones.every((z) => z.pipes.isNotEmpty), isTrue);
  });

  test('thousands of heads in well under a second', () {
    final family = Catalog.defaultCatalog().outlet('rotor')!;
    final layout = layoutLandscape(
      outline: const [Pt(0, 0), Pt(600, 0), Pt(600, 250), Pt(300, 400), Pt(0, 400)],
      exclusions: [_rect(100, 100, 160, 140)],
      family: family,
      options: LandscapeLayoutOptions(evaluate: false),
    );
    final z = zoneByFlow(zoneItemsOf(layout, family), ZoningOptions(maxZoneFlow: 4 * m3sPerM3h));
    final zones = [
      for (final g in z.zones) [for (final i in g.items) layout.heads[i].position],
    ];
    final sw = Stopwatch()..start();
    final r = routeZones(zones, RouteOptions(pointOfConnection: const Pt(-10, -10), exclusions: [_rect(100, 100, 160, 140)], direction: layout.direction));
    expect(sw.elapsedMilliseconds, lessThan(perfBudgetMs(1500)));
    expect(r.zones, hasLength(zones.length));
    expect(_graph(r.mainline).$3, isTrue);
  }, tags: perfTag);
}
