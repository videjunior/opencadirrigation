import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/pivot.dart';
import 'package:opencadirrigation/core/design/pivot_package.dart';
import 'package:opencadirrigation/core/hydraulics/emitter.dart';
import 'package:opencadirrigation/core/hydraulics/friction.dart';
import 'package:opencadirrigation/core/hydraulics/minor_losses.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/units.dart';

double ft(double v) => v * metersPerFoot;
double gpm(double v) => v * m3sPerGpm;
double psi(double v) => v / psiPerMeterHead;

/// NRCS NEH 623 ch. 11, sample calculation 11-18: 1,300 ft lateral of 6.36 in
/// galvanised pipe (C = 130), last tower at 1,260 ft, 1,400 ft irrigated
/// radius with the end gun on, 0.30 in/day gross in 22 h/day.
PivotPackageSpec neh1118({bool booster = false}) => PivotPackageSpec(
  spans: [
    for (var i = 0; i < 7; i++) PivotSpanDef(lengthM: ft(180), pipeInnerMm: 6.36 * 25.4, hazenC: 130, outletSpacingM: ft(10), firstOutletM: ft(10)),
    PivotSpanDef(lengthM: ft(40), pipeInnerMm: 6.36 * 25.4, hazenC: 130, outletSpacingM: ft(10), firstOutletM: ft(10), overhang: true),
  ],
  endGun: EndGunUse.fullCircle,
  endGunRadiusM: ft(100) / 0.9,
  endGunPressureM: psi(70),
  endGunBooster: booster,
  grossDepthMm: 0.30 * 25.4,
  hoursPerCycle: 22,
  regulated: false,
  nozzlePressureM: psi(45),
  dropMinorK: 0,
  drive: TowerDrive(speedMPerMin: ft(2.0)),
);

void main() {
  group('sample calculation 11-18 of NEH 623 ch. 11', () {
    final r = designPivotPackage(neh1118(), id: 'pv');

    test('system capacity and effective radius with the end gun', () {
      expect(r.effectiveRadiusM, closeTo(ft(1400), 1e-6));
      expect(r.systemFlow / m3sPerGpm, closeTo(873, 2));
      // the outlet flows and the gun share add up to the system flow
      final sum = r.outlets.fold(0.0, (s, o) => s + o.requiredFlow) + r.endGunFlow;
      expect(sum, closeTo(r.systemFlow, 1e-12));
      expect(r.designFlow, closeTo(r.systemFlow, 1e-12));
    });

    test('discharge of the sprinkler 1,200 ft from the pivot with 10 ft spacing: 10.69 gpm (eq. 11-44)', () {
      final o = r.outlets.firstWhere((o) => (o.distanceM - ft(1200)).abs() < 1e-6);
      expect(o.requiredFlow / m3sPerGpm, closeTo(2 * 1200 * 10 * (r.systemFlow / m3sPerGpm) / (1400 * 1400), 1e-6));
      expect(o.requiredFlow / m3sPerGpm, closeTo(10.69, 0.03));
      expect(o.servedWidthM, closeTo(ft(10), 1e-9));
      expect(o.spacingM, closeTo(ft(10), 1e-9));
    });

    test('end gun discharge Q·(1 − L²/R²): about 120 gpm (eq. 11-46)', () {
      expect(r.endGunFlow / m3sPerGpm, closeTo(120, 1));
      expect(r.endGunFlow, closeTo(r.systemFlow * (1 - 1300 * 1300 / (1400 * 1400)), 1e-12));
    });

    test('pipe friction to the end: 33.1 ft', () {
      expect(r.frictionLossM / metersPerFoot, closeTo(33.1, 33.1 * 0.02));
    });

    test('a 66-hour revolution at 2.0 ft/min of the end tower applies 0.90 in', () {
      expect(r.lastTowerRadiusM, closeTo(ft(1260), 1e-6));
      expect(r.hoursAt100, closeTo(2 * math.pi * 1260 / 2.0 / 60, 1e-9));
      expect(r.hoursAt100, closeTo(66, 0.1));
      expect(r.depthAt100Mm / 25.4, closeTo(0.90, 0.01));
      // timer chart: time and depth grow as 100/p
      expect(r.timer.length, defaultTimerSettings.length);
      final half = r.timer.firstWhere((t) => t.timerPct == 50);
      expect(half.hours, closeTo(2 * r.hoursAt100, 1e-9));
      expect(half.depthMm, closeTo(2 * r.depthAt100Mm, 1e-9));
      expect(half.speedMPerMin, closeTo(ft(1.0), 1e-12));
      expect(r.timerForDepth(2 * r.depthAt100Mm), closeTo(50, 1e-9));
      expect(r.depthAtTimer(25), closeTo(4 * r.depthAt100Mm, 1e-9));
    });

    test('booster for a 65 psi gun with 5 psi of plumbing on a 45 psi lateral end: 2.7 hp at 65 %', () {
      final b = designPivotPackage(neh1118(booster: true));
      expect(b.endPressureM, closeTo(psi(45), 0.01));
      expect(b.boosterHeadM, closeTo(psi(25), 0.01));
      expect(b.boosterPowerKw / 0.7457, closeTo(2.7, 0.05));
      // without a booster the gun sets the inlet pressure
      expect(r.requiredInletHeadM, greaterThan(b.requiredInletHeadM + psi(24)));
      expect(r.endPressureM, closeTo(psi(70), 0.01));
    });

    test('nozzle a little larger than 7/32 in for 10.69 gpm at 45 psi (orifice, Cd 0.97)', () {
      final d = orificeDiameter(flow: gpm(10.69), head: psi(45));
      expect(d / metersPerInch, greaterThan(7 / 32));
      expect(d / metersPerInch * 128, closeTo(30, 0.5));
      expect(orificeFlow(diameter: d, head: psi(45)), closeTo(gpm(10.69), 1e-12));
      // 29.82·Cd·d²·√P in gpm, inches and psi
      expect(orificeFlow(diameter: metersPerInch * 0.25, head: psi(50)) / m3sPerGpm, closeTo(29.824 * 0.97 * 0.0625 * math.sqrt(50), 0.01));
    });
  });

  group('regulated package with the numbered nozzle series', () {
    PivotPackageSpec spec({double available = 0, int maxNumber = 80}) => PivotPackageSpec(
      spans: [for (var i = 0; i < 7; i++) const PivotSpanDef(lengthM: 54, outletSpacingM: 3, archM: 0.5), const PivotSpanDef(lengthM: 22, outletSpacingM: 3, overhang: true)],
      nozzlePressureM: 14,
      regulated: true,
      nozzleHeightM: 1.5,
      grossDepthMm: 8,
      hoursPerCycle: 24,
      endThrowM: 5,
      availableInletHeadM: available,
      minNozzleNumber: 8,
      maxNozzleNumber: maxNumber,
      drive: const TowerDrive(motorRpm: 1740, centerGearRatio: 40, wheelGearRatio: 52, tyreRollingDiameterM: 1.3),
    );
    final r = designPivotPackage(spec(), id: 'p2');

    test('regulator rating nearest the target and every nozzle at the rating', () {
      expect(r.regulatorM, closeTo(psi(20), 1e-12));
      final active = r.outlets.where((o) => !o.plugged).toList();
      expect(active, isNotEmpty);
      for (final o in active) {
        expect(o.nozzlePressureM, closeTo(r.regulatorM, 1e-9));
        expect(o.regulatorM, r.regulatorM);
        expect(o.nozzleNumber, inInclusiveRange(8, 80));
        // the number nearest the orifice diameter, at least the smallest
        // (outlets needing between half and all of the smallest nozzle keep it)
        final dReq = orificeDiameter(flow: o.requiredFlow, head: o.nozzlePressureM);
        expect(o.nozzleNumber, (dReq / (metersPerInch / 128)).round().clamp(8, 80));
        expect(o.requiredFlow, greaterThanOrEqualTo(0.5 * orificeFlow(diameter: 8 * metersPerInch / 128, head: o.nozzlePressureM) - 1e-15));
        expect(o.nozzleDiameterMm, closeTo(o.nozzleNumber * 25.4 / 128, 1e-9));
      }
      expect(r.warnings, isNot(contains('pivot_pkg_regulator_starved:p2')));
      expect(r.warnings, isNot(contains('pivot_pkg_nozzle_max:p2')));
    });

    test('an outlet beyond the largest nozzle gets the largest one and a warning', () {
      final small = designPivotPackage(spec(maxNumber: 40), id: 'p2');
      expect(small.warnings, contains('pivot_pkg_nozzle_max:p2'));
      // a few outlets short at the end: the package as a whole stays close
      // to its flow (the deviation is weighted by flow)
      expect(small.warnings, isNot(contains('pivot_pkg_flow_dev:p2')));
      final tiny = designPivotPackage(spec(maxNumber: 12), id: 'p2');
      expect(tiny.warnings, contains('pivot_pkg_flow_dev:p2'));
      expect(small.outlets.last.nozzleNumber, 40);
      expect(small.outlets.last.deliveredFlow, lessThan(small.outlets.last.requiredFlow));
    });

    test('flows near the pivot point are merged into fewer sprinklers and still add up', () {
      expect(r.outlets.first.plugged, isTrue);
      expect(r.outlets.last.plugged, isFalse);
      final sum = r.outlets.fold(0.0, (s, o) => s + o.requiredFlow);
      expect(sum, closeTo(r.systemFlow, 1e-12));
      expect(r.sprinklerCount, lessThan(r.outlets.length));
      // the delivered total is close to the design total
      expect((r.deliveredFlow - r.designFlow).abs() / r.designFlow, lessThan(0.02));
      // served widths cover the whole radius
      final widths = r.outlets.fold(0.0, (s, o) => s + o.servedWidthM);
      expect(widths, closeTo(r.effectiveRadiusM, 1e-9));
    });

    test('drops are longer in mid-span (arch) and the system flow follows the area', () {
      final mid = r.outlets.firstWhere((o) => (o.distanceM - 28.5).abs() < 1e-6); // 3 m spacing from 1.5 m: 28.5 m is near mid-span
      final t = 28.5 / 54;
      expect(mid.dropLengthM, closeTo(3.5 + 0.5 * 4 * t * (1 - t) - 1.5, 1e-9));
      final overhangOutlet = r.outlets.last;
      expect(overhangOutlet.dropLengthM, closeTo(2.0, 1e-9));
      expect(r.effectiveRadiusM, closeTo(405, 1e-9));
      expect(r.systemFlow, closeTo(math.pi * 405 * 405 * 0.008 / (24 * 3600), 1e-12));
    });

    test('inlet head covers the regulator margin at the critical outlet', () {
      // design position = worst position (level): the regulator inlet at every
      // outlet is at least rating + margin, the critical one exactly
      var tightest = double.infinity;
      for (final o in r.outlets.where((o) => !o.plugged)) {
        final dropLoss = hazenWilliamsLoss(flow: o.requiredFlow, diameter: 0.019, length: o.dropLengthM, c: 140) + 1.5 * math.pow(velocity(flow: o.requiredFlow, diameter: 0.019), 2) / (2 * gravity);
        tightest = math.min(tightest, o.pipePressureM + o.dropLengthM - dropLoss - (r.regulatorM + 5 / psiPerMeterHead));
      }
      expect(tightest, closeTo(0, 1e-6));
      expect(r.inletHeadM, closeTo(r.requiredInletHeadM, 1e-12));
    });

    test('timer chart from the drive train', () {
      const v = 1740 / (40 * 52) * math.pi * 1.3;
      expect(r.speedAt100MPerMin, closeTo(v, 1e-9));
      expect(r.hoursAt100, closeTo(2 * math.pi * 378 / v / 60, 1e-9));
      expect(r.depthAt100Mm, closeTo(r.systemFlow * r.hoursAt100 * 3600 / (math.pi * 405 * 405) * 1000, 1e-9));
      expect(TowerDrive.tyreRollingDiameter(sectionWidthInch: 11.2, rimDiameterInch: 38), closeTo((38 + 2 * 0.95 * 11.2) * 0.0254 * 0.95, 1e-12));
    });

    test('too little pressure at the pivot starves the regulators', () {
      final low = designPivotPackage(spec(available: r.requiredInletHeadM - 3), id: 'p2');
      expect(low.warnings, containsAll(['pivot_pkg_pressure_deficit:p2', 'pivot_pkg_regulator_starved:p2']));
      expect(low.outlets.last.nozzlePressureM, lessThan(low.regulatorM));
      expect(low.inletHeadM, closeTo(r.requiredInletHeadM - 3, 1e-12));
    });

    test('a rising field adds its rise to the inlet pressure', () {
      final up = designPivotPackage(spec(), worstRiseAt: (d) => d / 100);
      expect(up.requiredInletHeadM, greaterThan(r.requiredInletHeadM + 3.5));
      expect(up.requiredInletHeadM, lessThan(r.requiredInletHeadM + 4.1));
    });

    test('JSON round trip', () {
      final back = PivotPackageResult.fromJson(r.toJson());
      expect(back.outlets.length, r.outlets.length);
      expect(back.spans.length, r.spans.length);
      expect(back.timer.length, r.timer.length);
      expect(back.regulatorM, r.regulatorM);
      expect(back.outlets[10].nozzleNumber, r.outlets[10].nozzleNumber);
      expect(back.outlets.first.plugged, r.outlets.first.plugged);
      expect(back.depthAt100Mm, closeTo(r.depthAt100Mm, 1e-12));
      expect(back.warnings, r.warnings);
    });

    test('span summary', () {
      expect(r.spans.length, 8);
      expect(r.spans.last.overhang, isTrue);
      expect(r.spans.fold(0, (s, e) => s + e.outlets), r.sprinklerCount);
      expect(r.spans.fold(0.0, (s, e) => s + e.frictionLossM), closeTo(r.frictionLossM, 1e-9));
      for (final sp in r.spans) {
        expect(sp.pressureEndM, lessThanOrEqualTo(sp.pressureStartM + 1e-9));
      }
    });
  });

  group('catalogue nozzles, end guns and linear moves', () {
    final family = [
      for (final lph in [400.0, 600, 800, 1000, 1200, 1500, 1800, 2200, 2600, 3000])
        NozzleSpec(
          id: 'n$lph',
          name: '$lph',
          curve: EmitterCurve.fromNominal(flow: lph * m3sPerLph, head: 10),
          minHeadM: 5,
          maxHeadM: 30,
        ),
    ];

    test('the closest catalogue nozzle at the nozzle pressure', () {
      final r = designPivotPackage(
        const PivotPackageSpec(
          spans: [PivotSpanDef(lengthM: 50, outletSpacingM: 5), PivotSpanDef(lengthM: 50, outletSpacingM: 5), PivotSpanDef(lengthM: 50, outletSpacingM: 2.5)],
          nozzlePressureM: 10,
          regulated: true,
          grossDepthMm: 10,
          hoursPerCycle: 20,
        ),
        nozzles: family,
        regulators: [ValveSpec(id: 'reg10', name: 'regulator', kind: ValveKind.prv, sizeMm: 20, loss: const DeviceLossCurve(k: 1e5), defaultSettingM: 10.5)],
      );
      expect(r.regulatorId, 'reg10');
      expect(r.regulatorM, 10.5);
      for (final o in r.outlets.where((o) => !o.plugged)) {
        final best = family.map((n) => (n.curve.flow(o.nozzlePressureM) - o.requiredFlow).abs()).reduce(math.min);
        final chosen = family.firstWhere((n) => n.id == o.nozzle);
        expect((chosen.curve.flow(o.nozzlePressureM) - o.requiredFlow).abs(), closeTo(best, 1e-15));
        expect(o.deliveredFlow, closeTo(chosen.curve.flow(o.nozzlePressureM), 1e-15));
      }
    });

    test('a corner gun is added on top of the sprinklers', () {
      final r = designPivotPackage(
        const PivotPackageSpec(spans: [PivotSpanDef(lengthM: 300, outletSpacingM: 3)], endGun: EndGunUse.corners, endGunRadiusM: 30, endGunPressureM: 40, grossDepthMm: 8, hoursPerCycle: 24),
      );
      final rate = r.systemFlow / (math.pi * 305 * 305);
      expect(r.endGunFlow, closeTo(rate * math.pi * (327 * 327 - 305 * 305), 1e-12));
      expect(r.designFlow, closeTo(r.systemFlow + r.endGunFlow, 1e-12));
      final noRadius = designPivotPackage(
        const PivotPackageSpec(spans: [PivotSpanDef(lengthM: 300, outletSpacingM: 3)], endGun: EndGunUse.corners, endGunPressureM: 40),
        id: 'g',
      );
      expect(noRadius.warnings, contains('pivot_pkg_gun_undefined:g'));
    });

    test('the gun radius comes from its catalogue nozzle', () {
      final gun = [
        NozzleSpec(
          id: 'g20',
          name: 'gun',
          curve: EmitterCurve.fromNominal(flow: 20 * m3sPerM3h, head: 40, radius: 36, radiusB: 0.5),
        ),
      ];
      final r = designPivotPackage(
        const PivotPackageSpec(spans: [PivotSpanDef(lengthM: 300, outletSpacingM: 3)], endGun: EndGunUse.fullCircle, endGunPressureM: 40, grossDepthMm: 8, hoursPerCycle: 24),
        gunNozzles: gun,
      );
      expect(r.gunNozzle, 'g20');
      expect(r.gunRadiusM, closeTo(36, 1e-9));
      expect(r.effectiveRadiusM, closeTo(300 + 0.9 * 36, 1e-9));
    });

    test('a linear move gets flows in proportion to the width each outlet waters', () {
      final r = designPivotPackage(
        const PivotPackageSpec(
          kind: PivotKind.linear,
          spans: [PivotSpanDef(lengthM: 200, outletSpacingM: 2.5)],
          travelM: 800,
          endThrowM: 0,
          grossDepthMm: 10,
          hoursPerCycle: 20,
          drive: TowerDrive(speedMPerMin: 2),
        ),
      );
      expect(r.systemFlow, closeTo(200 * 800 * 0.010 / (20 * 3600), 1e-12));
      final inner = r.outlets[10], other = r.outlets[50];
      expect(inner.requiredFlow, closeTo(other.requiredFlow, 1e-15));
      expect(inner.requiredFlow, closeTo(r.systemFlow * 2.5 / 200, 1e-15));
      expect(r.hoursAt100, closeTo(800 / 2 / 60, 1e-12));
      expect(r.depthAt100Mm, closeTo(r.systemFlow * r.hoursAt100 * 3600 / (200 * 800) * 1000, 1e-9));
    });

    test('package from a pivot spec', () {
      const p = PivotSpec(kind: PivotKind.pivot, lengthM: 420, spanLengthM: 50, sprinklerSpacingM: 2.5, endGunFlow: 0.004, endGunPressureM: 35, endPressureM: 12);
      final s = PivotPackageSpec.fromPivot(p);
      expect(s.spans.length, 9);
      expect(s.spans.last.overhang, isTrue);
      expect(s.spans.last.lengthM, closeTo(20, 1e-9));
      expect(s.pipeLengthM, closeTo(420, 1e-9));
      expect(s.lastTowerRadiusM, closeTo(400, 1e-9));
      expect(s.endGun, EndGunUse.corners);
      expect(s.nozzlePressureM, 12);
      final r = designPivotPackage(s, id: 'pv');
      expect(r.endGunFlow, 0.004);
      expect(r.warnings, contains('pivot_pkg_no_drive:pv'));
      expect(r.timer, isEmpty);
    });
  });
}
