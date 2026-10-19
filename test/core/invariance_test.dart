/// What must not change a design: moving the whole drawing (also to UTM
/// coordinates, as a georeferenced import does), drawing the pipes the other
/// way round, saving and reopening, or the interface language (hydraulics
/// alike; only prices follow the language's currency). Moving the drawing
/// used to change pressures by centimetres: the terrain's inverse-distance
/// search counted some spot heights twice, depending on where they lay.
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

import '../support/language_packs.dart';

/// Hydraulic figures of a design keyed by entity ids (names follow the
/// language), and the costs.
Map<String, num> _figures(DesignResults r, {bool costs = true}) => {
  if (costs) 'capital': r.capitalCost,
  if (costs) 'energy': r.annualEnergyCost,
  for (final z in r.zones.values) ...{
    '${z.valveId} flow': z.totalFlow,
    '${z.valveId} head': z.requiredUpstreamHead,
    '${z.valveId} pmin': z.minOutletPressure,
    '${z.valveId} pmax': z.maxOutletPressure,
    '${z.valveId} EU': z.uniformity.eu,
    '${z.valveId} warnings': z.warnings.length,
  },
  for (final f in r.systemFlows) ...{
    '${f.flowId} flow': f.totalFlow,
    for (final s in f.supplies) '${f.flowId} ${s.supplyId} head': s.requiredHead,
    '${f.flowId} warnings': f.warnings.length,
  },
  for (final e in r.pivots.entries) ...{'${e.key} flow': e.value.flow, '${e.key} head': e.value.inletHead},
  'bom lines': r.bom.length,
};

void _expectSame(Map<String, num> a, Map<String, num> b, String reason) {
  expect(b.keys.toSet(), a.keys.toSet(), reason: reason);
  for (final k in a.keys) {
    expect(b[k]!.toDouble(), closeTo(a[k]!.toDouble(), 1e-6 * math.max(1, a[k]!.abs())), reason: '$reason: $k');
  }
}

Project _copy(Project p) => Project.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);

Project _moved(Project p, Pt by) {
  final q = _copy(p);
  for (var i = 0; i < q.entities.length; i++) {
    q.entities[i] = q.entities[i].transformed(Affine.translation(by));
  }
  return q;
}

void main() {
  setUpAll(installLanguagePacksFromDisk);

  test('inverse distance weighting counts every spot height once, wherever the drawing lies', () {
    const spots = [(0.0, 0.0, 100.0), (105.0, 0.0, 99.5), (0.0, 68.0, 100.1), (105.0, 68.0, 99.6), (-6.0, -24.0, 100.2)];
    for (final (ox, oy) in [(0.0, 0.0), (1234.5, -987.25), (523456.789, 7456789.123)]) {
      final t = Terrain(samples: [for (final (x, y, z) in spots) TerrainSample(Pt(x + ox, y + oy), z)]);
      final p = Pt(-6 + ox, 34 + oy);
      var num = 0.0, den = 0.0;
      for (final (x, y, z) in spots) {
        final d = Pt(x + ox, y + oy).distanceTo(p);
        num += z / (d * d);
        den += 1 / (d * d);
      }
      expect(t.idwAt(p), closeTo(num / den, 1e-9), reason: 'offset ($ox, $oy)');
    }
  });

  // spot heights on rectangle corners (co-circular) and mainlines outside
  // their hull (inverse distance weighting); quick to design
  for (final id in [ExampleId.sportsField, ExampleId.garden, ExampleId.golf]) {
    test('${id.name}: moving, reversing the pipes, reopening or another language leave the design as it was', () {
      final t = I18n('en');
      DesignResults design(Project p) => Designer(p, label: (k) => t(k)).designAll();
      final original = buildExample(id, t.call, lang: 'en');
      final base = _figures(design(_copy(original)));
      _expectSame(base, _figures(design(_copy(original))), 'saved and reopened');
      _expectSame(base, _figures(design(_moved(original, const Pt(1234.5, -987.25)))), 'moved');
      _expectSame(base, _figures(design(_moved(original, const Pt(523456.789, 7456789.123)))), 'moved to UTM coordinates');
      final reversed = _copy(original);
      for (final e in reversed.entities) {
        if (e is PipeEntity) e.points = e.points.reversed.toList();
      }
      _expectSame(base, _figures(design(reversed)), 'pipes drawn the other way round');
      for (final lang in ['pt', 'ar']) {
        final other = Designer(buildExample(id, I18n(lang).call, lang: lang), label: (k) => I18n(lang)(k)).designAll();
        _expectSame(_figures(design(_copy(original)), costs: false), _figures(other, costs: false), 'language $lang');
      }
    });
  }

  test('terrain from contour lines: moving the project to UTM coordinates leaves the design as it was', () {
    final t = I18n('en');
    DesignResults design(Project p) => Designer(p, label: (k) => t(k)).designAll();
    final original = buildExample(ExampleId.gravity, t.call, lang: 'en');
    _expectSame(_figures(design(_copy(original))), _figures(design(_moved(original, const Pt(523456.789, 7456789.123)))), 'moved to UTM coordinates');
  });
}
