import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/catch_cans.dart';
import 'package:opencadirrigation/core/design/densogram.dart';
import 'package:opencadirrigation/core/design/fertigation_stages.dart';
import 'package:opencadirrigation/core/model/agronomy_plan.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// Depth densogram, virtual catch cans and the field evaluation of
/// uniformity (1.6.0 AGR, PRD-28), and the fertigation by crop stage.
void main() {
  const square = [Pt(0, 0), Pt(10, 0), Pt(10, 10), Pt(0, 10)];
  const hectare = [Pt(0, 0), Pt(100, 0), Pt(100, 100), Pt(0, 100)];
  const sprayAt = [(2.5, 2.5), (7.5, 2.5), (2.5, 7.5), (7.5, 7.5)];

  // four 12F sprays (0.60 m³/h at 20 m) on 100 m²: 24 mm/h
  Project sprays() => Project(
    entities: [
      AreaEntity(id: 'a', points: square, useWaterBalance: true, etoMmDay: 5, kc: 0.85, awcMmPerM: 150, rootDepthM: 0.3, mad: 0.5),
      for (final (x, y) in sprayAt) OutletEntity(id: 's$x$y', position: Pt(x, y), outletSpecId: 'spray', nozzleId: 's12', headM: 20),
    ],
  );

  group('catch cans', () {
    test('volume and depth of a can', () {
      expect(canMouthAreaMm2(100), closeTo(math.pi * 2500, 1e-9));
      expect(canDepthMm(canVolumeMl(12.5, 100), 100), closeTo(12.5, 1e-12));
      expect(canVolumeMl(10, 100), closeTo(78.5398, 1e-4));
    });

    test('a grid of cans over an area, half a spacing in', () {
      final g = canGridOver(square, id: 'c');
      expect(g.cols, 3);
      expect(g.values, hasLength(9));
      expect(g.values.every((v) => v == 0), isTrue);
      expect(g.position(0).x, closeTo(1.5, 1e-9));
      expect(g.position(0).y, closeTo(1.5, 1e-9));
      expect(g.position(8).x, closeTo(7.5, 1e-9));
      expect(g.position(8).y, closeTo(7.5, 1e-9));
      // turned a quarter: still nine cans, all inside the square
      final turned = canGridOver(square, id: 'r', angleDeg: 90);
      expect(turned.values.whereType<double>(), hasLength(9));
      for (var k = 0; k < 9; k++) {
        expect(pointInPolygon(turned.position(k), square), isTrue, reason: '$k');
      }
      // cans outside a triangle are left out
      final tri = canGridOver(const [Pt(0, 0), Pt(10, 0), Pt(0, 10)], id: 't');
      expect(tri.values.where((v) => v == null), isNotEmpty);
      expect(tri.values.whereType<double>(), isNotEmpty);
    });

    test('values typed or pasted: decimal commas, thousands, missing cans', () {
      expect(parseFieldValues('10 12,5 -\n11;x;9'), [10, 12.5, null, 11, null, 9]);
      expect(parseFieldValues('1,250 1,300'), [1250, 1300]);
      expect(parseFieldValues('1,5 2,25\n\n'), [1.5, 2.25]);
      expect(parseFieldValues('-3\t4'), [null, 4]);
      expect(parseFieldValues(''), isEmpty);
    });

    test('uniformity of a sample: Christiansen CU and low-quarter DU', () {
      final s = FieldStats.of([1, 2, 3, 4, double.nan, -1]);
      expect(s.count, 4);
      expect(s.mean, 2.5);
      expect(s.cu, closeTo(60, 1e-9));
      expect(s.du, closeTo(40, 1e-9));
      expect(FieldStats.of(const []).count, 0);
    });
  });

  group('field evaluation (PRD-28)', () {
    test('emitter flows measured in a drip zone', () {
      final e = evaluateFieldTest(Project(), FieldTest(id: 'e', kind: FieldTestKind.emitters, values: [1, 2, 3, 4, null]));
      expect(e.measuredStats.count, 4);
      expect(e.measuredStats.cu, closeTo(60, 1e-9));
      expect(e.measuredStats.du, closeTo(40, 1e-9));
      expect(e.designMean, 0, reason: 'no design results');
      expect(e.meanRatio, 0);
    });

    test('cans that caught what the design lays down read as the design', () {
      final p = sprays();
      final map = computeDensogram(p);
      final ft = canGridOver(square, id: 'c', mouthMm: 100, hours: 0.5);
      for (var k = 0; k < ft.values.length; k++) {
        if (ft.values[k] != null) ft.values[k] = canVolumeMl(map.rateAt(ft.position(k)) * 0.5, 100);
      }
      final e = evaluateFieldTest(p, ft);
      expect(e.measuredStats.count, 9);
      expect(e.measuredStats.mean, greaterThan(0));
      expect(e.meanRatio, closeTo(1, 1e-9));
      expect(e.measuredStats.cu, closeTo(e.predictedStats.cu, 1e-9));
      expect(e.meanRateMmH, closeTo(e.measuredStats.mean / 0.5, 1e-9));
      // half the water in every can: half the design, the same uniformity
      for (var k = 0; k < ft.values.length; k++) {
        if (ft.values[k] != null) ft.values[k] = ft.values[k]! / 2;
      }
      final half = evaluateFieldTest(p, ft);
      expect(half.meanRatio, closeTo(0.5, 1e-9));
      expect(half.measuredStats.cu, closeTo(e.measuredStats.cu, 1e-9));
    });
  });

  group('depth densogram', () {
    test('the rate times the hours each sprinkler runs; a sprinkler not listed applies nothing', () {
      final p = sprays();
      final rate = computeDensogram(p);
      final ids = [for (final (x, y) in sprayAt) 's$x$y'];
      final depth = computeDensogram(p, options: DensogramOptions(depthHours: {for (final id in ids) id: 2.0}));
      expect(rate.depth, isFalse);
      expect(depth.depth, isTrue);
      for (final at in const [Pt(5, 5), Pt(1, 1), Pt(9, 4)]) {
        expect(depth.rateAt(at), closeTo(2 * rate.rateAt(at), 1e-9 * (1 + rate.rateAt(at))));
      }
      final one = computeDensogram(p, options: DensogramOptions(depthHours: {ids.first: 1.0}));
      expect(one.sources, hasLength(1));
      // without a programme nothing runs
      expect(depthDensogram(p, null).isEmpty, isTrue);
    });
  });

  group('fertigation by crop stage', () {
    test('products for the doses: phosphate and potash first, their nitrogen counted', () {
      final kg = productsForNutrients([100, 52, 60], defaultFertProducts);
      expect(kg[1], closeTo(100, 1e-9), reason: 'MAP 11-52-0');
      expect(kg[2], closeTo(100, 1e-9), reason: 'KCl 0-0-60');
      expect(kg[0], closeTo((100 - 11) / 0.45, 1e-9), reason: 'urea 45-0-0 for the rest');
      expect(productsForNutrients([0, 52, 0], defaultFertProducts), [0, closeTo(100, 1e-9), 0]);
    });

    test('a tomato hectare: the doses split by the water use of each stage', () {
      // the table's Kc ini (0.6): irrigated every 12 days from planting
      final a = AreaEntity(id: 'a', points: hectare, useWaterBalance: true, cropKey: 'crop.tomato', etoMmDay: 5, climateKc: false);
      final p = Project(entities: [a]);
      final plan = FertigationStagePlan(doseKgHa: [100, 52, 60]);
      // with Kc ini from the wetting of the initial stage (AGR-09, the
      // default) the 36 mm of RAW outlast the 30 days of the stage: no
      // irrigation carries its share, and the plan says so
      final wetting = AreaEntity(id: 'w', points: hectare, useWaterBalance: true, cropKey: 'crop.tomato', etoMmDay: 5);
      final dry = fertigationSchedule(Project(entities: [wetting]), wetting, plan: plan)!;
      expect(dry.stages.first.irrigations, 0);
      expect(dry.warnings, ['fert_stage_no_irrigation:initial']);
      final s = fertigationSchedule(p, a, plan: plan)!;
      expect(s.areaHa, closeTo(1, 1e-9));
      expect(s.stages.map((x) => x.stage), [0, 1, 2, 3]);
      expect(s.stages.every((x) => x.irrigations > 0 && x.fertigations == x.irrigations), isTrue);
      for (var k = 0; k < 3; k++) {
        expect(s.stages.fold(0.0, (t, x) => t + x.sharePct[k]), closeTo(100, 1e-9));
      }
      // the mid-season uses the most water, the initial stage the least
      expect(s.stages[2].etcMm, greaterThan(s.stages[0].etcMm));
      expect(s.stages[2].kgHa[0], greaterThan(s.stages[0].kgHa[0]));
      final totals = s.productTotalsKg;
      expect(totals[0], closeTo(89 / 0.45, 1e-6));
      expect(totals[1], closeTo(100, 1e-6));
      expect(totals[2], closeTo(100, 1e-6));
      expect(s.ecwLimitDsM, closeTo(2.5 / 1.5, 1e-9), reason: 'tomato ECe threshold 2.5 dS/m (FAO-29)');
      expect(s.warnings, isEmpty);
      expect(s.stages.every((x) => x.waterM3PerEvent > 0 && x.concentrationGL > 0 && x.ecRiseDsM > 0), isTrue);
      // every second irrigation: half the injections, twice the product each
      final every2 = fertigationSchedule(p, a, plan: FertigationStagePlan(doseKgHa: [100, 52, 60], everyNth: 2))!;
      expect(every2.stages[2].fertigations, (s.stages[2].irrigations / 2).ceil());
      expect(every2.productTotalsKg[1], closeTo(100, 1e-6));
      // salty water: the injection takes it past what tomato keeps its yield with
      a.ecwDsM = 1.65;
      expect(fertigationSchedule(p, a, plan: plan)!.warnings.any((w) => w.startsWith('fert_ec_high:')), isTrue);
    });

    test('a typed Kc has no stages; an area without water balance has no plan', () {
      final typed = AreaEntity(id: 'a', points: hectare, useWaterBalance: true, etoMmDay: 5, kc: 0.9);
      final p = Project(entities: [typed]);
      expect(fertigationSchedule(p, typed, plan: FertigationStagePlan(doseKgHa: [100, 0, 0]))!.warnings, contains('fert_no_stages'));
      final fixed = AreaEntity(id: 'b', points: hectare);
      expect(fertigationSchedule(Project(entities: [fixed]), fixed), isNull);
    });
  });
}
