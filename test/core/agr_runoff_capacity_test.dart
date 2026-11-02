import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/core/design/design_check.dart';
import 'package:opencadirrigation/core/design/runoff_potential.dart';
import 'package:opencadirrigation/core/design/soils.dart';
import 'package:opencadirrigation/core/design/system_capacity.dart';
import 'package:opencadirrigation/core/model/agronomy_plan.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// Runoff potential of the machines and of the sprinkler zones, and the
/// capacity of the system against the peak demand in the irrigation window
/// (1.6.0 AGR; AGR-10).
void main() {
  String t(String key, [Map<String, String>? args]) => key;

  group('infiltration of the soil', () {
    test('intake family by texture: the middle of the sprinkle intake range of NEH 652', () {
      expect(intakeFamilyFor(SoilTexture.clay), closeTo(0.15, 1e-12));
      expect(intakeFamilyFor(SoilTexture.loam), closeTo(0.6, 1e-12));
      expect(intakeFamilyFor(SoilTexture.sand), 2.0, reason: 'open range');
      // the capacity falls as the water goes in
      final clay = IntakeCapacity.family(0.15);
      expect(clay.rateAt(1), greaterThan(clay.rateAt(10)));
      expect(clay.rateAt(10), greaterThan(clay.rateAt(50)));
    });

    test('a pass runs off more the deeper it is; a sand takes it all', () {
      final clay = IntakeCapacity.family(0.15);
      double runoff(double d) => passRunoffMm(peakRateMmH: 60, depthMm: d, capacity: clay, surfaceStorageMm: 2.54);
      expect(runoff(10), greaterThan(0));
      expect(runoff(20), greaterThanOrEqualTo(runoff(10)));
      expect(runoff(40), greaterThanOrEqualTo(runoff(20)));
      expect(runoff(40), lessThan(40));
      expect(passRunoffMm(peakRateMmH: 20, depthMm: 20, capacity: IntakeCapacity.family(2.0), surfaceStorageMm: 10), 0);
      // the largest depth without runoff
      final d = maxRunoffFreeDepthMm(peakRateMmH: 60, capacity: clay, surfaceStorageMm: 2.54);
      expect(d, inExclusiveRange(0, 10));
      expect(passRunoffMm(peakRateMmH: 60, depthMm: d, capacity: clay, surfaceStorageMm: 2.54), lessThanOrEqualTo(0.01));
      expect(passRunoffMm(peakRateMmH: 60, depthMm: d + 5, capacity: clay, surfaceStorageMm: 2.54), greaterThan(0.01));
      expect(maxRunoffFreeDepthMm(peakRateMmH: 20, capacity: IntakeCapacity.family(2.0), surfaceStorageMm: 10), 150);
    });
  });

  group('runoff under a centre pivot', () {
    test('the outer spans of the gallery pivot run off a sloping clay', () {
      final p = buildExample(ExampleId.pivot, t);
      final pv = p.entities.whereType<PivotEntity>().single;
      final field = p.entities.whereType<AreaEntity>().single;
      expect(machineRunoff(p, pv), isNull, reason: 'no soil on the field');
      expect(agronomyIssues(p).where((i) => i.code == 'pivot_runoff'), isEmpty);
      field
        ..soilKey = 'soil.clay'
        ..slopePct = 15;
      final r = machineRunoff(p, pv)!;
      expect(r.soil.areaId, field.id);
      expect(r.soil.family, closeTo(0.15, 1e-12));
      expect(r.soil.surfaceStorageMm, closeTo(0.10 * 25.4, 1e-9));
      // a station at every tower and one at the reach of the end sprinkler
      expect(r.rows.length, greaterThanOrEqualTo(2));
      for (var i = 1; i < r.rows.length; i++) {
        expect(r.rows[i].radiusM, greaterThan(r.rows[i - 1].radiusM));
        expect(r.rows[i].meanRateMmH, greaterThan(r.rows[i - 1].meanRateMmH), reason: 'the rate grows with the radius');
        expect(r.rows[i].runoffMm, greaterThanOrEqualTo(r.rows[i - 1].runoffMm - 1e-9));
      }
      for (final row in r.rows) {
        expect(row.peakRateMmH, closeTo(row.meanRateMmH * 4 / math.pi, 1e-9));
        expect(row.passMinutes, closeTo(60 * row.depthMm / (math.pi / 4 * row.peakRateMmH), 1e-9));
        expect(row.depthMm, pv.grossDepthMm);
      }
      expect(r.worst.radiusM, r.rows.last.radiusM);
      expect(r.worst.runoffMm, greaterThan(0.5));
      expect(r.worst.maxDepthMm, lessThan(pv.grossDepthMm));
      final issue = agronomyIssues(p).singleWhere((i) => i.code == 'pivot_runoff');
      expect(issue.entityIds, [pv.id]);
      expect(issue.severity, CheckSeverity.warning);
      // a sandy field takes the same pass
      field.soilKey = 'soil.sand';
      expect(machineRunoff(p, pv)!.worst.runoffMm, 0);
      expect(agronomyIssues(p).where((i) => i.code == 'pivot_runoff'), isEmpty);
    });
  });

  group('runoff of the sprinkler zones', () {
    const square = [Pt(0, 0), Pt(10, 0), Pt(10, 10), Pt(0, 10)];
    // four 12F sprays (0.60 m³/h at 20 m) on 100 m²: 24 mm/h
    Project sprays(String soil) => Project(
      entities: [
        AreaEntity(id: 'a', points: square, soilKey: soil, useWaterBalance: true, etoMmDay: 5, kc: 0.85, awcMmPerM: 150, rootDepthM: 0.3, mad: 0.5),
        for (final (x, y) in const [(2.5, 2.5), (7.5, 2.5), (2.5, 7.5), (7.5, 7.5)]) OutletEntity(id: 's$x$y', position: Pt(x, y), outletSpecId: 'spray', nozzleId: 's12', headM: 20),
      ],
    );

    test('sprays on clay run off without cycle and soak; the cycles keep it', () {
      final z = zoneRunoff(sprays('soil.clay')).single;
      expect(z.areaId, 'a');
      expect(z.rateMmH, closeTo(24, 1e-6));
      expect(z.intakeMmH, closeTo(2.54, 1e-9));
      expect(z.surfaceStorageMm, closeTo(5.08, 1e-9));
      expect(z.runoffMm, closeTo((z.rateMmH - z.intakeMmH) * z.runHours - z.surfaceStorageMm, 1e-9));
      expect(z.runHours, closeTo(z.depthMm / z.rateMmH, 1e-12));
      expect(z.runoffMm, greaterThan(0));
      expect(z.maxRunMinutes, closeTo(60 * z.surfaceStorageMm / (z.rateMmH - z.intakeMmH), 1e-9));
      expect(z.cycles, greaterThan(1));
      expect(zoneRunoff(sprays('soil.sand')).single.runoffMm, lessThan(z.runoffMm));
      expect(zoneRunoff(sprays('')), isEmpty, reason: 'no soil, no estimate');
    });
  });

  group('capacity against the peak demand', () {
    test('the gallery pivot: 8.5 mm a day in 24 h against 8.1 mm gross; not in a 20-hour window', () {
      final p = buildExample(ExampleId.pivot, t);
      final pv = p.entities.whereType<PivotEntity>().single;
      final peak = 6 * 1.15 / 0.85; // ETo × Kc / Ea of the field
      var cap = systemCapacity(p);
      final m = cap.machines.single;
      expect(m.pivotId, pv.id);
      expect(m.capacityMmDay, closeTo(8.5, 1e-9));
      expect(m.peakGrossMmDay, closeTo(peak, 1e-6));
      expect(m.short, isFalse);
      expect(cap.windowHours, 24);
      expect(cap.ok, isTrue);
      expect(agronomyIssues(p).where((i) => i.code.contains('capacity')), isEmpty);
      p.agronomy.programme = ProgrammeSettings(windowHours: 20);
      cap = systemCapacity(p);
      final short = cap.machines.single;
      expect(short.capacityMmDay, closeTo(8.5 * 20 / 24, 1e-9));
      expect(short.hoursNeeded, closeTo(peak * 24 / 8.5, 1e-6));
      expect(short.short, isTrue);
      expect(cap.flowsFit, isFalse);
      final issues = agronomyIssues(p);
      expect(issues.singleWhere((i) => i.code == 'pivot_capacity_below_peak').entityIds, [pv.id]);
      expect(issues.where((i) => i.code == 'capacity_below_peak'), hasLength(1));
      expect(runDesignCheck(p).issues.map((i) => i.code), containsAll(['pivot_capacity_below_peak', 'capacity_below_peak']));
    });

    test('a project without zones or machines has nothing to check', () {
      final cap = systemCapacity(Project());
      expect(cap.flows, isEmpty);
      expect(cap.machines, isEmpty);
      expect(cap.ok, isTrue);
    });
  });
}
