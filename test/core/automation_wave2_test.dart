import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/auto_fix.dart';
import 'package:opencadirrigation/core/design/auto_layout.dart';
import 'package:opencadirrigation/core/design/block_generator.dart';
import 'package:opencadirrigation/core/design/densogram.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/lateral_limit.dart';
import 'package:opencadirrigation/core/design/proposal.dart';
import 'package:opencadirrigation/core/design/results.dart';
import 'package:opencadirrigation/core/design/tree_rings.dart';
import 'package:opencadirrigation/core/hydraulics/emitter.dart';
import 'package:opencadirrigation/core/hydraulics/lateral.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/proposal_settings.dart';

List<Pt> _rect(double x0, double y0, double x1, double y1) => [Pt(x0, y0), Pt(x1, y0), Pt(x1, y1), Pt(x0, y1)];

/// Whether the segment ab passes through the inside of the closed [poly].
bool _crossesInside(Pt a, Pt b, List<Pt> poly) {
  for (var k = 1; k < 20; k++) {
    final q = Pt.lerp(a, b, k / 20);
    if (pointInPolygon(q, poly) && !pointOnPolygonBoundary(q, poly, tol: 1e-6)) return true;
  }
  return false;
}

/// The functions added in 1.6.0 (wave 2) for automatic design and the
/// layout geometry: one self-crossing detector and one offset for the whole
/// program, the guided block that says when its rows are no plain copies of
/// the guide, the scheduling coefficient over a contiguous window, tree
/// rings round a pond, the default burial depths of the quote, the computed
/// longest lateral, and the corrections and changes recorded one by one for
/// the review of "fix automatically" and "optimise".
void main() {
  group('one self-crossing detector', () {
    test('the crossing edges are those of the outline as given, repeated vertices and all', () {
      const bow = [Pt(0, 0), Pt(10, 10), Pt(10, 0), Pt(0, 10)];
      expect(polygonSelfCrossingEdges(bow).map((x) => (x.$1, x.$2)), [(0, 2)]);
      expect(polygonSelfCrossing(bow)!.$3.distanceTo(const Pt(5, 5)), lessThan(1e-9));
      // a repeated vertex counts once (as its last copy) and the edges keep their numbers
      const repeated = [Pt(0, 0), Pt(10, 10), Pt(10, 10), Pt(10, 0), Pt(0, 10)];
      final x = polygonSelfCrossing(repeated)!;
      expect((x.$1, x.$2), (0, 3));
      expect(x.$3.distanceTo(const Pt(5, 5)), lessThan(1e-9));
      expect(polygonSelfCrossings(bow), hasLength(1));
      // a closing vertex equal to the first is the first
      expect(polygonSelfCrossingEdges(const [Pt(0, 0), Pt(10, 0), Pt(10, 10), Pt(0, 10), Pt(0, 0)]), isEmpty);
    });

    test('a spike is a crossing too, and the parts leave it out', () {
      const spiked = [Pt(0, 0), Pt(10, 0), Pt(10, 10), Pt(5, 10), Pt(5, 15), Pt(5, 10), Pt(0, 10)];
      expect(polygonSelfCrossings(spiked), isNotEmpty);
      final parts = simplePolygonParts(spiked);
      expect(parts, hasLength(1));
      expect(polygonArea(parts.single), closeTo(100, 1e-9));
      // (the vertex at the foot of the spike stays, on the top side)
      expect(splitSelfIntersecting(spiked).single, hasLength(5));
      expect(polygonSelfCrossingEdges(parts.single), isEmpty);
      // the slivers below the area asked for are dropped
      expect(splitSelfIntersecting(const [Pt(0, 0), Pt(10, 10), Pt(10, 0), Pt(0, 10)], minArea: 30), isEmpty);
    });

    test('an open polyline that crosses itself', () {
      expect(polylineSelfCrosses(const [Pt(0, 0), Pt(10, 10), Pt(10, 0), Pt(0, 10)]), isTrue);
      expect(polylineSelfCrosses(const [Pt(0, 0), Pt(10, 0), Pt(20, 5), Pt(30, 0)]), isFalse);
    });
  });

  group('one offset', () {
    // a guide turning back by 160°
    final v = [const Pt(0, 0), const Pt(100, 0), Pt(100 - 100 * math.cos(degToRad(20)), 100 * math.sin(degToRad(20)))];

    test('the report counts the corners bevelled or rounded and the loops cut', () {
      final outer = OffsetReport();
      final o = offsetPolyline(v, -20, report: outer);
      expect(outer.corners, 1);
      expect(outer.loops, 0);
      expect(o, hasLength(4));
      final inner = OffsetReport();
      offsetPolyline(v, 5, report: inner);
      expect(inner.loops, 1, reason: 'the two offsets inside the turn cross');
      final plain = OffsetReport();
      offsetPolyline(const [Pt(0, 0), Pt(10, 0), Pt(20, 5)], 1, report: plain);
      expect(plain.changed, isFalse);
    });

    test('a round join stays at the distance; the guided blocks and corridors use it', () {
      final round = offsetPolyline(v, -20, miterLimit: 2, join: OffsetJoin.round);
      expect(round.length, greaterThan(5));
      for (final q in round.skip(1).take(round.length - 2)) {
        expect(q.distanceTo(v[1]), closeTo(20, 1e-9));
      }
      expect(offsetPolylineMitred(v, -20), round);
    });

    test('a line that crosses itself keeps its own crossing', () {
      const eight = [Pt(0, 0), Pt(20, 20), Pt(20, 0), Pt(0, 20)];
      expect(polylineSelfCrosses(offsetPolyline(eight, 1)), isTrue);
    });

    test('MOD-26: a guided block whose rows go round a sharp bend of the guide says so', () {
      Project p() => Project();
      BlockResult block(List<Pt> guide) => generateBlock(
        p(),
        BlockOptions(polygon: _rect(0, -20, 100, 40), direction: const Pt(1, 0), lateralSpacing: 5, guide: guide, isTape: true, tapeSpecId: 'x'),
      );
      final bent = block(const [Pt(0, 0), Pt(80, 0), Pt(0, 30)]);
      expect(bent.laterals, isNotEmpty);
      expect(bent.messages.any((m) => m.startsWith('block_guide_offset:')), isTrue, reason: '${bent.messages}');
      final straight = block(const [Pt(0, 10), Pt(100, 10)]);
      expect(straight.messages.where((m) => m.startsWith('block_guide_offset:')), isEmpty);
    });
  });

  test('AGR-21: the scheduling coefficient of a layout is over the driest contiguous 5 %', () {
    // one spray head in the middle of a 40 m square, 25 m of throw: the four
    // corners stay dry, 2.8 % of the lawn in four spots
    final region = LayoutRegion(_rect(-20, -20, 20, 20));
    final m = evaluateSprayUniformity(region, [const SpraySource(entityId: 'h', p: Pt.zero, flow: 1e-3, radius: 25)], profile: SprayProfile.uniform, cellSize: 0.5);
    expect(m.dryPct, closeTo(2.83, 0.6));
    // over the driest 5 % wherever they lie it would be about 2.2; one window
    // of 5 % holds a single corner and some wet ground
    expect(m.sc, lessThan(1.4));
    expect(m.sc, greaterThan(1.0));
  });

  group('AUT-19 tree rings round an exclusion', () {
    test('the lateral goes round a pond between two trees of its row', () {
      final area = _rect(0, 0, 60, 20);
      final pond = _rect(22, 6, 38, 14);
      final t = layoutTreeRings(area: area, options: TreeRingOptions(plantSpacing: 6, rowSpacing: 8, exclusions: [pond]));
      expect(t.trees.every((q) => !pointInPolygon(q, pond)), isTrue);
      expect(t.messages.any((m) => m.startsWith('rings_detour:')), isTrue, reason: '${t.messages}');
      expect(t.messages.where((m) => m.startsWith('rings_row_gap:')), isEmpty);
      for (final l in t.laterals) {
        for (var i = 1; i < l.length; i++) {
          expect(_crossesInside(l[i - 1], l[i], pond), isFalse, reason: 'segment ${l[i - 1]} → ${l[i]} crosses the pond');
        }
      }
    });

    test('a row cut by a notch of the area goes round it inside the area', () {
      const u = [Pt(0, 0), Pt(40, 0), Pt(40, 20), Pt(28, 20), Pt(28, 8), Pt(12, 8), Pt(12, 20), Pt(0, 20)];
      final t = layoutTreeRings(area: u, options: TreeRingOptions(plantSpacing: 4, rowSpacing: 5));
      expect(t.messages.any((m) => m.startsWith('rings_detour:')), isTrue, reason: '${t.messages}');
      const notch = [Pt(12, 8), Pt(28, 8), Pt(28, 20.5), Pt(12, 20.5)];
      for (final l in t.laterals) {
        for (var i = 1; i < l.length; i++) {
          expect(_crossesInside(l[i - 1], l[i], notch), isFalse, reason: 'segment ${l[i - 1]} → ${l[i]} crosses the notch');
        }
      }
    });
  });

  group('AUT-25 default burial depths of the quote', () {
    test('zone pipes without a depth lie on the surface unless the quote says how deep', () {
      final p = Project();
      p.entities.addAll([
        PipeEntity(id: p.newId(), points: const [Pt(0, 0), Pt(100, 0)], scope: HydraulicScope.zone),
        PipeEntity(id: p.newId(), points: const [Pt(0, 10), Pt(50, 10)], scope: HydraulicScope.mainline),
      ]);
      final s = ProposalSettings();
      expect(trenchRows(p, s).map((r) => r.scope), [HydraulicScope.mainline], reason: 'as before');
      expect(autoZonePipeDepth(p), defaultZonePipeDepthM);
      s
        ..zoneDepthM = 0.3
        ..mainlineDepthM = 0.8;
      final rows = trenchRows(p, s);
      expect(rows, hasLength(2));
      final od = 50 / 1000; // no catalogue pipe: 50 mm
      expect(rows.firstWhere((r) => r.scope == HydraulicScope.zone).depth, closeTo(0.3 + od / 2 + s.beddingM, 1e-9));
      expect(rows.firstWhere((r) => r.scope == HydraulicScope.mainline).depth, closeTo(0.8 + od / 2 + s.beddingM, 1e-9));
      expect(scheduleTasks(p, s).any((x) => x.key == 'trench'), isTrue);
      p.proposal.zoneDepthM = 0.5;
      expect(autoZonePipeDepth(p), 0.5);
      expect(autoMainlineDepth(p), 0.6);
    });

    test('the depths are kept in the file only when set, and unknown fields of the quote stay', () {
      expect(ProposalSettings().toJson().containsKey('mainD'), isFalse);
      expect(ProposalSettings().isDefault, isTrue);
      final s = ProposalSettings(zoneDepthM: 0.35, mainlineDepthM: 0.9);
      final j = s.toJson();
      expect(j['zoneD'], 0.35);
      expect(j['mainD'], 0.9);
      final back = ProposalSettings.fromJson({...j, 'future': 7});
      expect(back.zoneDepthM, 0.35);
      expect(back.mainlineDepthM, 0.9);
      expect(back.toJson()['future'], 7);
      expect(ProposalSettings.fromJson({'future': 7}).isDefault, isFalse, reason: 'what a newer version wrote is written back');
    });
  });

  group('the computed longest lateral', () {
    // a drip tape of 1 L/h every 0.3 m at 10 m, 16 mm
    final tape = TapeSpec(id: 't', name: 'T', innerDiameterMm: 16, emitterSpacingM: 0.3, emitter: EmitterCurve.fromNominal(flow: 1e-3 / 3600, head: 10));
    final spec = tapeLateralSpec(tape, DesignParameters());

    double qVar(double length) {
      final r = analyzeLateralForMeanPressure(spec.copyWith(length: length), 10);
      final q = [for (final x in r.points) x.emitterFlow];
      return 100 * (q.reduce(math.max) - q.reduce(math.min)) / q.reduce(math.max);
    }

    test('by the flow variation: the longest that holds, one emitter more does not', () {
      final level = maxLateralRun(spec, nominalHeadM: 10);
      expect(level.limitedBy, LateralLimitBy.flowVariation);
      expect(level.emitters, greaterThan(100));
      expect(level.flowVariationPct, lessThanOrEqualTo(10 + 1e-9));
      expect(qVar(level.length), closeTo(level.flowVariationPct, 1e-6));
      expect(qVar(level.length + spec.spacing), greaterThan(10));
      // a stricter rule, a shorter lateral
      expect(maxLateralRun(spec, nominalHeadM: 10, allowedFlowVariationPct: 5).length, lessThan(level.length));
    });

    test('uphill shorter, gently downhill longer; both ways from the slope', () {
      final level = maxLateralRun(spec, nominalHeadM: 10);
      final up = maxLateralRun(spec, nominalHeadM: 10, slopePct: 2);
      final down = maxLateralRun(spec, nominalHeadM: 10, slopePct: -0.5);
      expect(up.length, lessThan(level.length));
      expect(down.length, greaterThan(level.length));
      final both = maxLateralRunsBothWays(spec, nominalHeadM: 10, slopePct: -2);
      expect(both.uphill.length, closeTo(up.length, 1e-9));
      expect(both.shorter.length, lessThanOrEqualTo(both.downhill.length));
    });

    test('a compensating tape is limited by its pressure window', () {
      final pc = TapeSpec(id: 'pc', name: 'PC', innerDiameterMm: 16, emitterSpacingM: 0.3, emitter: const EmitterCurve(k: 1e-3 / 3600 / 1.07, x: 0.03, compensationHead: 6));
      final r = maxLateralRun(tapeLateralSpec(pc, DesignParameters()), nominalHeadM: 10, minHeadM: 6, maxHeadM: 25);
      expect(r.limitedBy, LateralLimitBy.pressure);
      expect(r.minHeadM, greaterThanOrEqualTo(6 - 1e-9));
    });

    test('the slope of the terrain along the rows, the longest row of a block and the pipe a flow needs', () {
      final p = Project();
      for (var x = 0.0; x <= 100; x += 10) {
        for (var y = 0.0; y <= 50; y += 10) {
          p.entities.add(SpotHeightEntity(id: p.newId(), position: Pt(x, y), elevation: 100 + 0.02 * x - 0.01 * y));
        }
      }
      final terrain = p.buildTerrain();
      final field = _rect(5, 5, 95, 45);
      expect(terrainSlopeAlong(terrain, field, const Pt(1, 0)), closeTo(2, 0.05));
      expect(terrainSlopeAlong(terrain, field, const Pt(0, 1)), closeTo(-1, 0.05));
      expect(terrainSlopeAlong(Project().buildTerrain(), field, const Pt(1, 0)), isNull);
      expect(longestRowLength(_rect(0, 0, 100, 40), const Pt(1, 0), 10), closeTo(100, 1e-9));
      expect(longestRowLength(_rect(0, 0, 100, 40), const Pt(1, 0), 10, centre: true), closeTo(50, 1e-9));
      expect(longestRowLength(_rect(0, 0, 100, 40), const Pt(1, 0), 10, exclusions: [_rect(40, -1, 60, 41)]), closeTo(40, 1e-9));
      final cat = Catalog.defaultCatalog();
      final pipe = pipeForFlow(cat, PipeUsage.zone, 2e-3, 1.5)!;
      expect(pipeVelocity(pipe, 2e-3), lessThanOrEqualTo(1.5));
      final smaller = cat.pipesFor(PipeUsage.zone).where((x) => x.innerDiameter < pipe.innerDiameter);
      expect(smaller.every((x) => pipeVelocity(x, 2e-3) > 1.5), isTrue);
    });
  });

  group('the review of "fix automatically" and "optimise"', () {
    final t = I18n('pt');

    Project lawn() {
      final p = Project();
      p.params.connectTolerance = 0.05;
      p.entities.add(WaterSupplyEntity(id: p.newId(), position: const Pt(-20, 0), calculatePressure: true));
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(-20, 0), const Pt(0, 0)], scope: HydraulicScope.mainline));
      p.entities.add(ControlValveEntity(id: p.newId(), position: const Pt(0, 0), zoneName: 'A', valveSpecId: 'ev25'));
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(0, 0), const Pt(30, 0)], scope: HydraulicScope.zone));
      p.entities.add(OutletEntity(id: p.newId(), position: const Pt(30, 0), outletSpecId: 'rotor', nozzleId: 'r3', headM: 25, zoneName: 'A'));
      // a head off its pipe and a pipe of no length
      p.entities.add(OutletEntity(id: p.newId(), position: const Pt(15, 1.8), outletSpecId: 'rotor', nozzleId: 'r3', headM: 25, zoneName: 'A'));
      p.entities.add(PipeEntity(id: p.newId(), points: [const Pt(500, 500), const Pt(500, 500)], scope: HydraulicScope.mainline));
      return p;
    }

    test('every correction is recorded with its problem, and a run can make only the ones kept', () async {
      final p = lawn();
      final before = p.toJson();
      final all = await runAutoFix(p, () async => null, label: t.call, lang: 'pt');
      expect(all.steps, hasLength(all.applied.length));
      expect(all.steps.length, greaterThanOrEqualTo(2), reason: all.applied.map((f) => f.key).join(', '));
      expect(all.steps.first.round, 1);
      expect([for (final s in all.steps) s.result.key], [for (final f in all.applied) f.key]);
      final keep = {all.steps.first.id};
      final again = Project.fromJson(before);
      final some = await runAutoFix(again, () async => null, label: t.call, lang: 'pt', skip: onlyFixSteps(keep));
      expect([for (final s in some.steps) s.id], [all.steps.first.id]);
      expect(fixStepId(all.steps.first.advice, all.steps.first.kind), all.steps.first.id);
    });

    test('every change of the optimisation is recorded and made again on the project as it was', () async {
      final p = buildExample(ExampleId.orchard, t.call, lang: 'pt');
      p.params.sizingMethod = SizingMethod.greedy;
      for (final e in p.entities.whereType<PipeEntity>()) {
        e.computerSized = false;
      }
      final before = p.toJson();
      Future<DesignResults?> run() async => Designer(p, label: t.call).designAll();
      final report = await runOptimize(p, run, options: const OptimizeOptions(resizeFixedPipes: true, choosePumps: false, resizeValves: false));
      expect(report.improved, isTrue);
      expect([for (final ch in report.changes) ch.id], containsAll(['autoSizePipes', 'lpSizing']));
      expect([for (final ch in report.changes) ch.result.key], [for (final f in report.applied) f.key]);
      // only the sizing method, on the project as it was
      final q = Project.fromJson(before);
      report.changes.firstWhere((ch) => ch.id == 'lpSizing').apply(q);
      expect(q.params.sizingMethod, SizingMethod.lp);
      expect(q.entities.whereType<PipeEntity>().any((e) => !e.computerSized), isTrue, reason: 'the pipes stay as the user fixed them');
      report.changes.firstWhere((ch) => ch.id == 'autoSizePipes').apply(q);
      expect(q.entities.whereType<PipeEntity>().every((e) => e.computerSized), isTrue);
    });
  });
}
