import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/core/design/area_water.dart';
import 'package:opencadirrigation/core/design/design_check.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/mechanised.dart';
import 'package:opencadirrigation/core/design/soils.dart';
import 'package:opencadirrigation/core/design/water_budget.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/site_climate.dart';

/// The agronomy checks of the design check (sweep of 2026-11-01): the rate
/// of the sprinklers against the soil (AGR-10, NEH 15-11 Table 11-4) and on
/// the pivots the soil of the area under them, the ETo typed against the
/// site climate (AGR-05), planting dates (AGR-08) and water too saline for
/// the crop (AGR-11).
void main() {
  String t(String key, [Map<String, String>? args]) => key;
  const square = [Pt(0, 0), Pt(10, 0), Pt(10, 10), Pt(0, 10)];

  // four 12F sprays (0.60 m³/h at 20 m) on 100 m²: 24 mm/h
  Project sprays(String soil, {double slope = 0}) => Project(
    entities: [
      AreaEntity(id: 'a', points: square, soilKey: soil, slopePct: slope, useWaterBalance: true, etoMmDay: 5, kc: 0.85, awcMmPerM: 150, rootDepthM: 0.3, mad: 0.5),
      for (final (x, y) in const [(2.5, 2.5), (7.5, 2.5), (2.5, 7.5), (7.5, 7.5)]) OutletEntity(id: 's$x$y', position: Pt(x, y), outletSpecId: 'spray', nozzleId: 's12', headM: 20),
    ],
  );

  group('application rate against the soil (AGR-10)', () {
    test('sprays on clay: reported with the cycle-and-soak split', () {
      final p = sprays('soil.clay');
      expect(areaRequirements(p, null).single.precipitationMmH, closeTo(24, 1e-6));
      // NEH 15-11 Table 11-4, heavy clay, 0–5 %: 0.15 in/h
      expect(soilRateLimitMmH(p.entities.first as AreaEntity), closeTo(0.15 * 25.4, 1e-9));
      final issue = agronomyIssues(p).singleWhere((i) => i.code == 'area_rate_exceeds_soil');
      expect(issue.severity, CheckSeverity.warning);
      expect(issue.entityIds, ['a']);
      final cs = cycleAndSoakForSoil(precipitationRateMmH: 24, depthMm: areaWaterBasis(p, p.entities.first as AreaEntity).grossPerEventMm, texture: SoilTexture.clay, slopePct: 0);
      expect(cs.cycles, greaterThan(1));
      expect(issue.value, '24.0 > 3.8 mm/h · ${cs.cycles} × ${cs.runMinutesPerCycle.round()} min / ${cs.soakMinutes.round()} min');
      expect(runDesignCheck(p).issues.map((i) => i.code), contains('area_rate_exceeds_soil'));
    });

    test('a sandy soil takes the sprays; a soil not given or drip are not checked', () {
      expect(agronomyIssues(sprays('soil.sand')).where((i) => i.code == 'area_rate_exceeds_soil'), isEmpty);
      expect(agronomyIssues(sprays('')).where((i) => i.code == 'area_rate_exceeds_soil'), isEmpty);
      final drip = sprays('soil.clay');
      (drip.entities.first as AreaEntity).irrigationMethod = 'localized';
      expect(agronomyIssues(drip).where((i) => i.code == 'area_rate_exceeds_soil'), isEmpty);
      // grass takes 25 % more, slopes less
      final turf = sprays('soil.clay');
      (turf.entities.first as AreaEntity).cropKey = 'crop.turf';
      expect(soilRateLimitMmH(turf.entities.first as AreaEntity), closeTo(0.15 * 25.4 * 1.25, 1e-9));
      expect(soilRateLimitMmH(sprays('soil.loam', slope: 10).entities.first as AreaEntity), closeTo(0.30 * 25.4, 1e-9));
    });

    test('a pivot takes the limit of the soil under it when none is typed', () {
      final p = buildExample(ExampleId.pivot, t);
      final pv = p.entities.whereType<PivotEntity>().single;
      final field = p.entities.whereType<AreaEntity>().single;
      expect(machineRateLimitMmH(p, pv), 0, reason: 'the gallery field has no soil: no check');
      field.soilKey = 'soil.loam';
      expect(machineRateLimitMmH(p, pv), closeTo(0.5 * 25.4, 1e-9));
      final r = Designer(p, label: t).designAll();
      // about 48 mm/h at the outer end against 12.7 mm/h: it went unnoticed
      expect(r.pivots[pv.id]!.appRateEndPeak, greaterThan(12.7));
      expect(r.pivots[pv.id]!.warnings, contains('pivot_app_rate:${pv.id}'));
      // a limit typed on the machine wins
      pv.maxAppRateMmH = 60;
      expect(machineRateLimitMmH(p, pv), 60);
    });
  });

  test('the ETo typed on an area against the site climate (AGR-05)', () {
    final a = AreaEntity(id: 'a', points: square, useWaterBalance: true, etoMmDay: 5);
    final p = Project(entities: [a])..climate = SiteClimate(etoMmDay: [7.5, 7.0, 6.0, 5.0, 4.0, 3.5, 3.5, 4.5, 5.5, 6.5, 7.0, 7.5], rainMm: List.filled(12, 0.0));
    expect(agronomyIssues(p).single.code, 'area_eto_climate');
    expect(agronomyIssues(p).single.value, '5.0 / 7.5 mm/d');
    a.etoMmDay = 7.2;
    expect(agronomyIssues(p), isEmpty);
    // a crop of the table takes the climate by itself
    a
      ..etoMmDay = 5
      ..cropKey = 'crop.maize';
    expect(agronomyIssues(p).where((i) => i.code == 'area_eto_climate'), isEmpty);
  });

  test('planting dates that are not dates or could be read two ways (AGR-08)', () {
    final a = AreaEntity(id: 'a', points: square, cropKey: 'crop.maize', plantingMonthDay: '05/09');
    final p = Project(entities: [a]);
    expect(agronomyIssues(p).single.code, 'area_planting_date');
    expect(agronomyIssues(p).single.value, '"05/09"');
    a.plantingMonthDay = '31/02';
    expect(agronomyIssues(p).single.code, 'area_planting_date');
    a.plantingMonthDay = '15/09';
    expect(agronomyIssues(p), isEmpty);
    a.plantingMonthDay = '';
    expect(agronomyIssues(p), isEmpty);
  });

  test('water too saline for the crop (AGR-11)', () {
    final a = AreaEntity(id: 'a', points: square, cropKey: 'crop.dryBean', ecwDsM: 6);
    expect(agronomyIssues(Project(entities: [a])).single.code, 'area_leaching_infeasible');
    a.ecwDsM = 0.5;
    expect(agronomyIssues(Project(entities: [a])), isEmpty);
  });
}
