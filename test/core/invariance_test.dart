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
import 'package:opencadirrigation/core/design/block_generator.dart';
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
  for (final f in r.systemFlows) ...{'${f.flowId} flow': f.totalFlow, for (final s in f.supplies) '${f.flowId} ${s.supplyId} head': s.requiredHead, '${f.flowId} warnings': f.warnings.length},
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

/// [p] with every pipe, tape and sprayline drawn the other way round (the
/// outlets of a sprayline stay where they were: its first outlet is then as
/// far from the new start as its last one was from the old end).
Project _reversed(Project p) {
  final q = _copy(p);
  for (final e in q.entities) {
    switch (e) {
      case PipeEntity l:
        l.points = l.points.reversed.toList();
      case TapeEntity l:
        l.points = l.points.reversed.toList();
      case SpraylineEntity s:
        final n = s.outletCount;
        final rest = s.length - (s.firstOutletDistance + (n - 1) * s.spacing);
        if (n < 1 || rest <= 1e-9) continue;
        s.points = s.points.reversed.toList();
        s.offset = rest;
      default:
        break;
    }
  }
  return q;
}

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
      _expectSame(base, _figures(design(_reversed(original))), 'pipes, tapes and spraylines drawn the other way round');
      // the order the hydraulic items were drawn in (the terrain keeps its
      // own: the triangulation of co-circular spot heights follows it)
      final shuffled = _copy(original);
      final hydraulic = shuffled.entities.where((e) => e.isHydraulic).toList();
      final others = shuffled.entities.where((e) => !e.isHydraulic).toList();
      shuffled.entities
        ..clear()
        ..addAll([...others, ...hydraulic.reversed]);
      _expectSame(base, _figures(design(shuffled)), 'hydraulic items in the other order');
      for (final lang in ['pt', 'ar']) {
        final other = Designer(buildExample(id, I18n(lang).call, lang: lang), label: (k) => I18n(lang)(k)).designAll();
        _expectSame(_figures(design(_copy(original)), costs: false), _figures(other, costs: false), 'language $lang');
      }
    });
  }

  // MOT-02: the inlet pressure of a tape was read at the first emitter as
  // drawn, the far end of a tape drawn from the edge of the field towards
  // its submain (the valve went from 19.5 m to 42.2 m, the flow from 12.8 to
  // 19.3 m³/h, the class of 14 tapes exceeded); the open end of the
  // flushing landed next to the submain
  for (final (name, tape, slope) in [('tapes', true, 0.0), ('spraylines', false, 0.0), ('tapes on a slope', true, 3.0)]) {
    test('$name drawn towards their submain: the same zone, the same flushing', () {
      Project block() {
        final p = Project();
        final poly = [const Pt(0, 0), const Pt(100, 0), const Pt(100, 30), const Pt(0, 30)];
        final b = generateBlock(
          p,
          BlockOptions(
            polygon: poly,
            direction: const Pt(1, 0),
            lateralSpacing: tape ? 1.5 : 4,
            isTape: tape,
            tapeSpecId: 'tape16_16_20',
            tapeInletHeadM: 8,
            outletSpecId: 'micro',
            nozzleId: 'm50',
            outletSpacing: 3.5,
            headM: 15,
            submainPosition: SubmainPosition.start,
            valveSpecId: 'ev50',
            valvePosition: ValvePosition.centre,
            submainStub: 1.5,
            zoneName: 'Z',
          ),
        );
        p.entities.addAll(b.all);
        final valve = b.valve!;
        final supplyPos = valve.position + const Pt(-100, 0);
        p.entities.add(PipeEntity(id: 'main', points: [supplyPos, valve.position], scope: HydraulicScope.mainline, name: 'Main'));
        p.entities.add(WaterSupplyEntity(id: 'tank', position: supplyPos, name: 'Tank', calculatePressure: true, designHeadM: 0, waterLevelOffsetM: 0));
        for (final (x, y) in [(-200.0, -200.0), (300.0, -200.0), (-200.0, 300.0), (300.0, 300.0)]) {
          p.entities.add(SpotHeightEntity(id: p.newId(), position: Pt(x, y), elevation: 100 - slope / 100 * x));
        }
        return p;
      }

      final p = block();
      final laterals = p.entities.where((e) => e is TapeEntity || e is SpraylineEntity).length;
      expect(laterals, greaterThan(5));
      final drawnBack = _reversed(p);
      // only the laterals: the submain and the mainline as they were
      for (final e in drawnBack.entities.whereType<PipeEntity>()) {
        e.points = e.points.reversed.toList();
      }
      expect(drawnBack.entities.whereType<TapeEntity>().every((t) => t.points.first.x > t.points.last.x) || !tape, isTrue);
      for (final analyse in [true, false]) {
        DesignResults run(Project q) => analyse ? Designer(_copy(q)).analyzeAll() : Designer(_copy(q)).designAll();
        final a = run(p), b = run(drawnBack);
        _expectSame(_figures(a), _figures(b), analyse ? 'analysed' : 'designed');
        if (tape) {
          expect(b.flushing, hasLength(1));
          expect(b.flushing.single.flow, closeTo(a.flushing.single.flow, 1e-6 * a.flushing.single.flow));
          expect(b.flushing.single.requiredUpstreamHead, closeTo(a.flushing.single.requiredUpstreamHead, 1e-6 * math.max(1, a.flushing.single.requiredUpstreamHead)));
        }
        // the outlet results still go by the outlets as drawn: the group of
        // the first outlet of a line is the one at its start
        final za = a.zones.values.single, zb = b.zones.values.single;
        for (final id in {for (final o in za.outlets) o.entityId}) {
          final ra = za.outlets.where((o) => o.entityId == id).toList()..sort((x, y) => x.index.compareTo(y.index));
          final rb = zb.outlets.where((o) => o.entityId == id).toList()..sort((x, y) => x.index.compareTo(y.index));
          expect(rb.length, ra.length, reason: id);
          expect(rb.first.index, 0, reason: id);
          expect(rb.last.pressure, closeTo(ra.first.pressure, 1e-6 * math.max(1, ra.first.pressure.abs())), reason: '$id: the inlet group is now the last as drawn');
        }
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
