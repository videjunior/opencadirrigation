import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/auto_layout.dart';
import 'package:opencadirrigation/core/design/zoning.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/units.dart';

import '../support/perf.dart';

List<Pt> _rect(double x0, double y0, double x1, double y1) => [Pt(x0, y0), Pt(x1, y0), Pt(x1, y1), Pt(x0, y1)];

/// Whether the members of [zone] are connected by links no longer than
/// [link] between members.
bool _connected(List<ZoneItem> items, List<int> zone, double link) {
  final seen = <int>{zone.first};
  final queue = [zone.first];
  for (var h = 0; h < queue.length; h++) {
    for (final j in zone) {
      if (!seen.contains(j) && items[queue[h]].position.distanceTo(items[j].position) <= link + 1e-9) {
        seen.add(j);
        queue.add(j);
      }
    }
  }
  return seen.length == zone.length;
}

/// A grid of [nx] × [ny] items [s] metres apart with [q] m³/h each.
List<ZoneItem> _grid(int nx, int ny, double s, double q, {String key = 'rotor', Pt at = Pt.zero}) => [
  for (var j = 0; j < ny; j++)
    for (var i = 0; i < nx; i++) ZoneItem(position: at + Pt(i * s, j * s), flow: q * m3sPerM3h, classKey: key),
];

void main() {
  final cat = Catalog.defaultCatalog();

  test('precipitation classes of the default catalogue', () {
    expect(precipitationClassOf(cat.outlet('spray')!), PrecipitationClass.spray);
    expect(precipitationClassOf(cat.outlet('rotor')!), PrecipitationClass.rotor);
    expect(precipitationClassOf(cat.outlet('impact34')!), PrecipitationClass.rotor);
    expect(precipitationClassOf(cat.outlet('drip_pc')!), PrecipitationClass.drip);
    expect(precipitationClassOf(cat.outlet('micro')!), PrecipitationClass.microSprinkler);
    expect(precipitationClassOf(cat.outlet('gun')!), PrecipitationClass.gun);
    expect(precipitationClassOf(cat.outlet('demand')!), PrecipitationClass.other);
  });

  test('zones within the flow, contiguous, compact and balanced', () {
    final items = _grid(12, 8, 10, 0.7);
    final r = zoneByFlow(items, ZoningOptions(maxZoneFlow: 4 * m3sPerM3h));
    // 96 heads of 0.7 m³/h: at least 17 zones of at most 5 heads
    expect(r.zones.length, inInclusiveRange(17, 22));
    expect(r.zoneOf.every((z) => z >= 0), isTrue);
    expect([for (final z in r.zones) ...z.items]..sort(), List.generate(items.length, (i) => i));
    for (final z in r.zones) {
      expect(z.flow, lessThanOrEqualTo(4 * m3sPerM3h + 1e-12));
      expect(_connected(items, z.items, 10 * math.sqrt2), isTrue, reason: '${z.items}');
      // compact: every head within a few spacings of the middle
      for (final i in z.items) {
        expect(items[i].position.distanceTo(z.centroid), lessThan(25));
      }
    }
    expect(r.imbalance, lessThan(1.3));
    expect(r.maxFlow / m3sPerM3h, lessThanOrEqualTo(4 + 1e-9));
  });

  test('head types and precipitation classes never share a zone; separate lawns get their own zones', () {
    final items = [..._grid(4, 3, 4, 0.6, key: 'spray'), ..._grid(4, 3, 10, 0.7, key: 'rotor', at: const Pt(0, 40)), ..._grid(2, 2, 4, 0.6, key: 'spray', at: const Pt(200, 0))];
    final r = zoneByFlow(items, ZoningOptions(maxZoneFlow: 20 * m3sPerM3h));
    for (final z in r.zones) {
      expect(z.items.map((i) => items[i].classKey).toSet(), hasLength(1));
    }
    // one zone of each kind would do by flow; the lone spray lawn 200 m away gets its own
    expect(r.zones.where((z) => z.classKey == 'spray'), hasLength(2));
    expect(r.zones.where((z) => z.classKey == 'rotor'), hasLength(1));
    // joining distant lawns when asked
    final joined = zoneByFlow(items, ZoningOptions(maxZoneFlow: 20 * m3sPerM3h, linkFactor: 0));
    expect(joined.zones.where((z) => z.classKey == 'spray'), hasLength(1));
  });

  test('an item over the limit gets its own zone; limits on the number of items', () {
    final items = [..._grid(3, 1, 5, 1), const ZoneItem(position: Pt(5, 5), flow: 9 * m3sPerM3h, classKey: 'rotor')];
    final r = zoneByFlow(items, ZoningOptions(maxZoneFlow: 5 * m3sPerM3h));
    expect(r.messages, contains('zone_item_over_capacity:3'));
    expect(r.zones.firstWhere((z) => z.items.contains(3)).items, [3]);
    final few = zoneByFlow(_grid(6, 1, 5, 0.1), ZoningOptions(maxZoneFlow: 10 * m3sPerM3h, maxItemsPerZone: 2));
    expect(few.zones, hasLength(3));
    expect(few.zones.every((z) => z.items.length <= 2), isTrue);
    expect(zoneByFlow(const [], ZoningOptions(maxZoneFlow: 1)).zones, isEmpty);
  });

  test('the heads of a layout: deterministic zones', () {
    final family = cat.outlet('rotor')!;
    final layout = layoutLandscape(outline: const [Pt(0, 0), Pt(50, 0), Pt(50, 18), Pt(20, 18), Pt(20, 40), Pt(0, 40)], family: family);
    final items = zoneItemsOf(layout, family);
    expect(items.map((i) => i.classKey).toSet(), {'rotor'});
    final a = zoneByFlow(items, ZoningOptions(maxZoneFlow: 3 * m3sPerM3h));
    final b = zoneByFlow(items, ZoningOptions(maxZoneFlow: 3 * m3sPerM3h));
    expect(a.zoneOf, b.zoneOf);
    final total = items.fold(0.0, (s, i) => s + i.flow);
    expect(a.zones.length, greaterThanOrEqualTo((total / (3 * m3sPerM3h)).ceil()));
    for (final z in a.zones) {
      expect(z.flow, lessThanOrEqualTo(3 * m3sPerM3h + 1e-12));
      expect(_connected(items, z.items, 1.5 * layout.spacing), isTrue);
    }
  });

  test('thousands of heads in well under a second', () {
    final family = cat.outlet('rotor')!;
    final layout = layoutLandscape(
      outline: const [Pt(0, 0), Pt(600, 0), Pt(600, 250), Pt(300, 400), Pt(0, 400)],
      exclusions: [_rect(100, 100, 160, 140)],
      family: family,
      options: LandscapeLayoutOptions(evaluate: false),
    );
    final items = zoneItemsOf(layout, family);
    final sw = Stopwatch()..start();
    final r = zoneByFlow(items, ZoningOptions(maxZoneFlow: 4 * m3sPerM3h));
    final ms = sw.elapsedMilliseconds;
    expect(items.length, greaterThan(2000));
    expect(r.zones.every((z) => z.flow <= 4 * m3sPerM3h + 1e-12), isTrue);
    // within 15 % of the fewest zones whole heads allow (a zone holds at
    // least the limit less one head)
    final total = items.fold(0.0, (s, i) => s + i.flow);
    expect(r.zones.length, lessThan(1.15 * total / ((4 - 0.7) * m3sPerM3h)));
    expect(ms, lessThan(perfBudgetMs(1500)));
  }, tags: perfTag);
}
