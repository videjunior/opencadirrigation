/// The terrain model depends on the terrain data, never on the order of the
/// items they come from: co-circular points (a cell of a regular grid, spot
/// heights at the corners of a rectangle) used to take the diagonal of
/// their insertion order, so reordering the items of the garden example
/// moved pressures by 2.6 mm (1.6.0 MOD, from the MOT review).
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/terrain.dart';
import 'package:opencadirrigation/core/model/tin.dart';

import '../support/language_packs.dart';

/// The triangles of [t] as sets of vertex positions, so two TINs compare
/// whatever their numbering.
Set<String> _faces(Tin t) => {
  for (final tr in t.triangles) ([t.vertex(tr.a), t.vertex(tr.b), t.vertex(tr.c)].map((p) => '${p.x},${p.y}').toList()..sort()).join(' '),
};

Project _copy(Project p) => Project.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);

Map<String, double> _figures(DesignResults r) => {
  for (final z in r.zones.values) ...{
    '${z.valveId} flow': z.totalFlow,
    '${z.valveId} head': z.requiredUpstreamHead,
    '${z.valveId} pmin': z.minOutletPressure,
    '${z.valveId} pmax': z.maxOutletPressure,
  },
  for (final f in r.systemFlows)
    for (final s in f.supplies) '${f.flowId} ${s.supplyId} head': s.requiredHead,
};

void main() {
  setUpAll(installLanguagePacksFromDisk);

  test('a regular grid triangulates alike in any order of its points', () {
    final grid = [
      for (var i = 0; i < 6; i++)
        for (var j = 0; j < 5; j++) (i * 10.0, j * 10.0, 100 + i * 0.37 + j * j * 0.11),
    ];
    final base = Tin.build(grid);
    expect(base.triangles.length, 2 * 5 * 4);
    final rnd = math.Random(7);
    for (var k = 0; k < 6; k++) {
      final order = [...grid]..shuffle(rnd);
      final other = Tin.build(k.isEven ? order : order.reversed);
      expect(_faces(other), _faces(base), reason: 'order $k');
      for (var x = 0.5; x < 50; x += 3.7) {
        for (var y = 0.5; y < 40; y += 2.9) {
          expect(other.elevationAt(Pt(x, y)), base.elevationAt(Pt(x, y)), reason: 'order $k at ($x, $y)');
        }
      }
    }
  });

  test('duplicate positions: points take their mean, a breakline vertex wins, in any order', () {
    final a = Tin.build([(0, 0, 10), (20, 0, 12), (0, 20, 14), (0, 0, 11), (20, 20, 13)]);
    final b = Tin.build([(20, 20, 13), (0, 0, 11), (0, 20, 14), (20, 0, 12), (0.0004, 0.0003, 10)]);
    expect(a.pointCount, 4);
    expect(b.pointCount, 4);
    expect(a.elevationAt(Pt.zero), closeTo(10.5, 1e-12));
    expect(b.elevationAt(Pt.zero), closeTo(10.5, 1e-12));
    // the merged vertex lies at the least position of its group
    expect(b.vertex(0), Pt.zero);
    // a breakline through a spot height takes the vertex with its own elevation
    final line = Tin.build(
      [(0, 0, 10), (20, 0, 12), (0, 20, 14), (20, 20, 13), (10, 10, 50)],
      breaklines: [
        [(0, 0, 10), (10, 10, 11), (20, 20, 13)],
      ],
    );
    expect(line.elevationAt(const Pt(10, 10)), closeTo(11, 1e-9));
    final reversed = Tin.build(
      [(10, 10, 50), (20, 20, 13), (0, 20, 14), (20, 0, 12), (0, 0, 10)],
      breaklines: [
        [(20, 20, 13), (10, 10, 11), (0, 0, 10)],
      ],
    );
    expect(_faces(reversed), _faces(line));
    expect(reversed.elevationAt(const Pt(10, 10)), closeTo(11, 1e-9));
  });

  test('spot heights on the corners of rectangles: the same model in any order of the items', () {
    const corners = [(0.0, 0.0), (40.0, 0.0), (40.0, 25.0), (0.0, 25.0), (80.0, 0.0), (80.0, 25.0), (0.0, 50.0), (40.0, 50.0), (80.0, 50.0)];
    final spots = <(double, double, double)>[for (final (x, y) in corners) (x, y, 100 + x * 0.013 - y * 0.021 + (x * y) * 1e-4)];
    Terrain terrain(Iterable<(double, double, double)> s) => Terrain(samples: [for (final (x, y, z) in s) TerrainSample(Pt(x, y), z)]);
    final base = terrain(spots);
    for (final order in [spots.reversed.toList(), [...spots.skip(4), ...spots.take(4)], [...spots]..shuffle(math.Random(3))]) {
      final other = terrain(order);
      for (var x = 1.0; x < 80; x += 6.5) {
        for (var y = 1.0; y < 50; y += 4.5) {
          expect(other.elevationAt(Pt(x, y)), base.elevationAt(Pt(x, y)), reason: '($x, $y)');
        }
      }
    }
  });

  test('garden example: reordering its terrain items leaves the design as it was', () {
    final t = I18n('en');
    DesignResults design(Project p) => Designer(p, label: (k) => t(k)).designAll();
    final original = buildExample(ExampleId.garden, t.call, lang: 'en');
    final base = _figures(design(_copy(original)));
    expect(base, isNotEmpty);
    bool terrainItem(Entity e) => e is SpotHeightEntity || e is ContourEntity || e is BreaklineEntity;
    for (final reverse in [true, false]) {
      final shuffled = _copy(original);
      final terrain = shuffled.entities.where(terrainItem).toList();
      final others = shuffled.entities.where((e) => !terrainItem(e)).toList();
      if (reverse) {
        shuffled.entities
          ..clear()
          ..addAll([...terrain.reversed, ...others]);
      } else {
        terrain.shuffle(math.Random(11));
        shuffled.entities
          ..clear()
          ..addAll([...others, ...terrain]);
      }
      final got = _figures(design(shuffled));
      expect(got.keys.toSet(), base.keys.toSet());
      for (final k in base.keys) {
        expect(got[k]!, closeTo(base[k]!, 1e-9 * math.max(1, base[k]!.abs())), reason: '${reverse ? 'reversed' : 'shuffled'}: $k');
      }
    }
  });
}
