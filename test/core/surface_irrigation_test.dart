import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/surface_irrigation.dart';
import 'package:opencadirrigation/core/units.dart';

/// FAO 45 works in m³/min and minutes; the engine in m³/s and seconds.
double perMin(double q) => q / 60;

void main() {
  group('volume-balance advance (FAO 45 §5.3.1)', () {
    test('worked example: 200 m furrow, 0.15 m³/min, advance about 65 min', () {
      final s = SurfaceSpec(system: SurfaceSystem.furrow, lengthM: 200, slope: 0.001, manningN: 0.04, section: const FlowSection(rho1: 0.55, rho2: 1.35), intake: KostiakovLewis.perMinute(k: 0.00324, a: 0.568, f0: 0.000174));
      final adv = surfaceAdvance(s, perMin(0.15));
      expect(adv.complete, isTrue);
      expect(adv.advanceS / 60, closeTo(65, 1));
      expect(adv.r, closeTo(0.63, 0.01));
      // the power advance passes through both points it was fitted on
      expect(adv.timeAt(200), closeTo(adv.advanceS, 1e-6 * adv.advanceS));
      expect(adv.distanceAt(adv.halfS), closeTo(100, 1e-6));
      // inlet area by Manning (eq. 48): (Q·n/(60·ρ1·√S0))^(1/ρ2)
      expect(adv.inletArea, closeTo(math.pow(0.15 * 0.04 / (60 * 0.55 * math.sqrt(0.001)), 1 / 1.35), 1e-12));
    });

    test('sigma z of eq. 47 and the Newton opportunity time of eq. 59', () {
      expect(sigmaZ(0.532, 0.5208), closeTo(0.7622, 1e-4)); // FAO 45 §4.6
      final i = KostiakovLewis.perMinute(k: 0.00346, a: 0.388, f0: 0.000057);
      final t = i.timeFor(0.04);
      expect(i.z(t), closeTo(0.04, 1e-12));
      expect(i.kPerMinute, closeTo(0.00346, 1e-15));
      expect(i.f0PerMinute, closeTo(0.000057, 1e-15));
      expect(i.timeFor(0), 0);
    });
  });

  group('furrow design example (FAO 45 §5.4.4)', () {
    final first = KostiakovLewis.perMinute(k: 0.00346, a: 0.388, f0: 0.000057);
    final later = KostiakovLewis.perMinute(k: 0.0038, a: 0.327, f0: 0.000037);
    SurfaceSpec spec(KostiakovLewis i) => SurfaceSpec(system: SurfaceSystem.furrow, lengthM: 200, slope: 0.001, manningN: 0.04, section: const FlowSection(rho1: 0.57, rho2: 1.367), furrowSpacingM: 0.5, intake: i);

    test('required opportunity times for 8 cm: 214 and 371 min', () {
      expect(first.timeFor(0.08 * 0.5) / 60, closeTo(214, 1));
      expect(later.timeFor(0.08 * 0.5) / 60, closeTo(371, 1));
    });

    test('advance times of the table within 2 %', () {
      for (final (q, tl) in [(0.09, 58.2), (0.072, 72.6), (0.045, 130.8), (0.036, 184.2), (0.018, 847.8)]) {
        expect(surfaceAdvance(spec(first), perMin(q)).advanceS / 60, closeTo(tl, tl * 0.02), reason: 'first irrigation, $q m³/min');
      }
      for (final (q, tl) in [(0.045, 101.4), (0.036, 132.6), (0.018, 379.2), (0.009, 2390.4)]) {
        expect(surfaceAdvance(spec(later), perMin(q)).advanceS / 60, closeTo(tl, tl * 0.02), reason: 'later irrigation, $q m³/min');
      }
    });

    test('application efficiency of the traditional design (tco = τreq + tL)', () {
      for (final (q, ea) in [(0.09, 32.6), (0.072, 38.6), (0.045, 51.5), (0.036, 55.7), (0.018, 41.9)]) {
        final e = designForDepth(spec(first), inflow: perMin(q), requiredDepthM: 0.08);
        expect(e.efficiency * 100, closeTo(ea, 1), reason: 'first irrigation, $q m³/min');
        expect(e.requirementEfficiency, closeTo(1, 1e-9), reason: 'the tail just gets the requirement');
        expect(e.cutoffS, closeTo(e.requiredTimeS + e.advanceS, 1e-6));
      }
      for (final (q, ea) in [(0.045, 37.7), (0.036, 44.2), (0.018, 59.3), (0.009, 32.2)]) {
        expect(designForDepth(spec(later), inflow: perMin(q), requiredDepthM: 0.08).efficiency * 100, closeTo(ea, 1), reason: 'later irrigation, $q m³/min');
      }
    });

    test('non-erosive maximum flow for 13 m/min: 1.768 m³/min (eq. 67)', () {
      final q = maxNonErosiveFlow(section: const FlowSection(rho1: 0.57, rho2: 1.367), manningN: 0.04, slope: 0.001, maxVelocity: 13 / 60);
      expect(q * 60, closeTo(1.768, 0.001));
    });

    test('the inflow search finds the best flow of the later irrigations near 0.018 m³/min', () {
      final d = designSurface(spec(later), requiredDepthM: 0.08, minInflow: perMin(0.009), maxInflow: perMin(0.09), steps: 30);
      expect(d.best, isNotNull);
      expect(d.best!.efficiency, greaterThanOrEqualTo(0.59));
      expect(d.best!.inflow * 60, inInclusiveRange(0.012, 0.03));
      expect(d.rows.length, 30);
      expect(d.rows.map((r) => r.efficiency).reduce(math.max), closeTo(d.best!.efficiency, 1e-12));
      final back = SurfaceDesign.fromJson(d.toJson());
      expect(back.rows.length, 30);
      expect(back.best!.efficiency, closeTo(d.best!.efficiency, 1e-12));
    });

    test('volumes balance and the ratios add up to one', () {
      final e = evaluateSurface(spec(first), inflow: perMin(0.036), cutoffS: 450 * 60, requiredDepthM: 0.08);
      expect(e.appliedM3, closeTo(perMin(0.036) * 450 * 60, 1e-12));
      expect(e.infiltratedM3 + e.runoffM3, closeTo(e.appliedM3, 1e-9));
      expect(e.efficiency + e.deepPercolationRatio + e.tailwaterRatio, closeTo(1, 1e-9));
      expect(e.lowQuarterDu, inExclusiveRange(0.5, 1.0));
      expect(e.minDepthM, lessThanOrEqualTo(e.meanDepthM));
      expect(e.profile.length, 100);
      // depth decreases from head to tail with recession at cutoff
      expect(e.profile.first.depthM, greaterThan(e.profile.last.depthM));
      final back = SurfaceEvaluation.fromJson(e.toJson());
      expect(back.efficiency, closeTo(e.efficiency, 1e-12));
      expect(back.profile.length, 100);
    });

    test('a cutoff before the advance ends and an advance that never ends are flagged', () {
      final short = evaluateSurface(spec(first), inflow: perMin(0.036), cutoffS: 60 * 60, requiredDepthM: 0.08, id: 'f1');
      expect(short.warnings, contains('surface_cutoff_before_advance:f1'));
      expect(short.profile.last.depthM, 0, reason: 'the tail stays dry');
      final none = evaluateSurface(spec(first), inflow: perMin(0.001), cutoffS: 3600, requiredDepthM: 0.08);
      expect(none.complete, isFalse);
      expect(none.warnings, contains('surface_no_advance'));
    });
  });

  group('open-end border design example (FAO 45 §5.5.3)', () {
    final first = KostiakovLewis.perMinute(k: 0.00484, a: 0.388, f0: 0.00008);
    final later = KostiakovLewis.perMinute(k: 0.0053, a: 0.327, f0: 0.000052);

    test('required opportunity times: 388.5 and 678.9 min', () {
      expect(first.timeFor(0.08) / 60, closeTo(388.5, 0.5));
      expect(later.timeFor(0.08) / 60, closeTo(678.9, 0.5));
    });

    test('advance, cutoff and recession times and efficiencies of the four tables', () {
      final cases = <(double, double, double, KostiakovLewis, List<(double, double, double, double, double)>)>[
        (200, 0.001, 0.04, first, [(0.036, 6.36, 11.34, 12.83, 65.3), (0.0545, 3.11, 8.10, 9.59, 60.4), (0.072, 2.14, 7.12, 8.61, 52.0), (0.09, 1.64, 6.63, 8.12, 44.7)]),
        (200, 0.001, 0.10, later, [(0.018, 15.55, 23.66, 26.86, 62.6), (0.036, 5.03, 13.12, 16.34, 56.5), (0.0545, 3.15, 11.25, 14.47, 43.4)]),
        (100, 0.008, 0.04, first, [(0.018, 5.27, 11.21, 11.74, 66.1), (0.0269, 2.35, 8.30, 8.83, 59.8), (0.036, 1.44, 7.39, 7.92, 50.1), (0.045, 1.03, 6.98, 7.51, 42.4)]),
        (100, 0.008, 0.10, later, [(0.009, 12.89, 23.07, 24.20, 64.2), (0.018, 3.45, 13.61, 14.76, 54.4)]),
      ];
      for (final (length, slope, n, intake, rows) in cases) {
        final s = SurfaceSpec(system: SurfaceSystem.border, lengthM: length, slope: slope, manningN: n, intake: intake);
        for (final (q, tl, tco, tr, ea) in rows) {
          final e = designForDepth(s, inflow: perMin(q), requiredDepthM: 0.08);
          final why = 'L $length, n $n, $q m³/min/m';
          expect(e.advanceS / 3600, closeTo(tl, 0.02), reason: '$why: advance');
          expect(e.cutoffS / 3600, closeTo(tco, 0.02), reason: '$why: cutoff');
          expect(e.recessionS / 3600, closeTo(tr, 0.02), reason: '$why: recession');
          expect(e.efficiency * 100, closeTo(ea, 0.2), reason: '$why: efficiency');
          expect(e.requirementEfficiency, closeTo(1, 1e-6), reason: '$why: the whole border gets the requirement');
        }
      }
    });

    test('Strelkoff depletion terms of the worked iteration: I = 0.000072, Sy = 0.000154, 824 − 147 = 677 min', () {
      final i = KostiakovLewis.perMinute(k: 0.0053, a: 0.327, f0: 0.000052);
      final rate = (i.a * i.kPerMinute / 2) * (math.pow(824, i.a - 1) + math.pow(824 - 145, i.a - 1)) + i.f0PerMinute;
      expect(rate, closeTo(0.000072, 0.0000005));
      final sy = borderSurfaceSlope(inflowPerMin: 0.072, intakeRatePerMin: 0.000072, lengthM: 200, manningN: 0.1, slope: 0.001);
      expect(sy, closeTo(0.000154, 0.0000005));
      expect(824 - strelkoffRecessionMinutes(manningN: 0.1, surfaceSlope: 0.000154, lengthM: 200, intakeRate: 0.000072, slope: 0.001), closeTo(677, 0.5));
    });

    test('inlet depth and the spreading minimum flow (eqs. 94 and 93)', () {
      final s = SurfaceSpec(system: SurfaceSystem.border, lengthM: 200, slope: 0.001, manningN: 0.04, intake: first);
      expect(inletFlowArea(s, perMin(0.036)), closeTo(0.0134, 0.0001)); // the 0.0134 m of §5.5.4
      expect(borderMinFlow(lengthM: 200, slope: 0.001, manningN: 0.10) * 60, closeTo(0.0226, 0.0001));
      expect(borderMinFlow(lengthM: 100, slope: 0.008, manningN: 0.10) * 60, closeTo(0.032, 0.0005));
    });
  });

  group('level basin design example (FAO 45 §5.6.1)', () {
    final first = KostiakovLewis.perMinute(k: 0.00484, a: 0.388, f0: 0.00008);
    final s = SurfaceSpec(system: SurfaceSystem.basin, lengthM: 100, slope: 0, manningN: 0.04, intake: first);

    test('inlet depth (eq. 112) and maximum unit flow (eq. 115)', () {
      expect(inletFlowArea(s, perMin(0.09)), closeTo(0.0326, 0.0002));
      // the example prints 0.623 m³/min/m: V = 13 m/min, n = 0.04, L = 100 m
      expect(basinMaxFlow(manningN: 0.04, lengthM: 100, maxVelocity: 13 / 60) * 60, closeTo(0.623, 0.002));
      // the general level-field solution gives the same for sheet flow
      expect(levelMaxFlow(s, 13 / 60), closeTo(basinMaxFlow(manningN: 0.04, lengthM: 100, maxVelocity: 13 / 60), 1e-12));
      // a level furrow gets its own section
      final furrow = SurfaceSpec(system: SurfaceSystem.furrow, lengthM: 100, slope: 0, manningN: 0.04, intake: first, furrowSpacingM: 0.75);
      final qf = levelMaxFlow(furrow, 13 / 60);
      expect(qf / inletFlowArea(furrow, qf, x: 100 / 9), closeTo(13 / 60, 1e-9));
    });

    test('cutoff of eq. 113 with the tabulated advance: 116 min and Ea 76.6 % at 0.09 m³/min/m', () {
      final y0 = inletFlowArea(s, perMin(0.09));
      final adv = SurfaceAdvance(advanceS: 55 * 60, halfS: 20 * 60, r: 0.72, p: 100 / math.pow(55 * 60, 0.72), inletArea: y0, complete: true);
      final tco = designCutoffTime(s, inflow: perMin(0.09), requiredDepthM: 0.08, advance: adv);
      expect(tco / 60, closeTo(116, 0.5));
      expect(100 * 0.08 * 100 / (perMin(0.09) * tco), closeTo(76.6, 0.3));
    });

    test('volume-balance advance against the chart values (hydrodynamic model) within 12 %', () {
      for (final (q, tl) in [(0.036, 140.0), (0.09, 55.0)]) {
        expect(surfaceAdvance(s, perMin(q)).advanceS / 60, closeTo(tl, tl * 0.12), reason: '$q m³/min/m');
      }
    });

    test('no runoff: all the water infiltrates and the tail gets the requirement', () {
      final e = designForDepth(s, inflow: perMin(0.09), requiredDepthM: 0.08);
      expect(e.runoffM3, 0);
      expect(e.infiltratedM3, closeTo(e.appliedM3, 1e-9));
      expect(e.tailwaterRatio, 0);
      expect(e.minDepthM, closeTo(0.08, 0.004));
      expect(e.efficiency, greaterThan(0.75));
    });
  });

  group('two-point infiltration from a field evaluation (FAO 45 §4.6)', () {
    test('a = 0.532, σz = 0.7622 and k = 0.00208 m³/min^a/m', () {
      final s = SurfaceSpec(system: SurfaceSystem.furrow, lengthM: 200, slope: 0.0075, manningN: 0.04, section: const FlowSection(rho1: 0.444, rho2: 1.357), intake: const KostiakovLewis(k: 0, a: 0.5));
      final a0 = inletFlowArea(s, perMin(0.12));
      expect(a0, closeTo(0.0106, 0.0001));
      final f0 = basicIntakeFromInflowOutflow(inflow: 0.002, outflow: 0.00095, lengthM: 200);
      expect(f0 * 60, closeTo(0.000315, 1e-9));
      final tp = twoPointInfiltration(inflow: 0.002, basicIntake: f0, x1: 112, t1: 18 * 60, x2: 200, t2: 54.8 * 60, inletArea: 0.0106);
      expect(tp.r, closeTo(0.5208, 0.0001));
      expect(tp.intake.a, closeTo(0.532, 0.001));
      expect(tp.sigmaZ, closeTo(0.7622, 0.0005));
      expect(tp.intake.kPerMinute, closeTo(0.00208, 0.00002));
      expect(tp.intake.f0PerMinute, closeTo(0.000315, 1e-9));
    });
  });

  group('flow section and NRCS intake families', () {
    test('power laws of the FAO 45 §4.3.3 furrow give ρ1 ≈ 0.550 and ρ2 ≈ 1.357', () {
      final f = FlowSection.fromPowerLaws(sigma1: 0.9696, sigma2: 1.732, gamma1: 2.4125, gamma2: 0.805);
      expect(f.rho2, closeTo(1.357, 0.001));
      expect(f.rho1, closeTo(0.550, 0.002));
      expect(FlowSection.faoFurrow.rho1, closeTo(f.rho1, 1e-4));
      expect(FlowSection.faoFurrow.rho2, closeTo(f.rho2, 1e-4));
      // sheet flow: depth = area, unit perimeter
      expect(FlowSection.sheet.depthOf(0.05), closeTo(0.05, 1e-12));
      expect(FlowSection.sheet.wettedPerimeterOf(0.05), closeTo(1, 1e-12));
      expect(f.depthOf(0.9696 * math.pow(0.08, 1.732)), closeTo(0.08, 1e-9));
    });

    test('tables in US units convert to SI', () {
      final f = nrcsIntakeFamily(0.5);
      expect(f.a, 0.514);
      expect(f.furrowK, 0.017660);
      expect(f.borderK, 0.007750);
      // furrow: ft³/ft/min^a → m³/m/s^a
      expect(f.furrow.k, closeTo(0.017660 * metersPerFoot * metersPerFoot * math.pow(60, -0.514), 1e-15));
      expect(f.furrow.f0, closeTo(0.0012628 * metersPerFoot * metersPerFoot / 60, 1e-15));
      // border: ft/min^a → m/s^a
      expect(f.border.k, closeTo(0.007750 * metersPerFoot * math.pow(60, -0.514), 1e-15));
      expect(f.border.z(360 * 60), closeTo((0.007750 * math.pow(360, 0.514) + 0.0005541 * 360) * metersPerFoot, 1e-12));
      // higher families take in more water in 6 hours
      for (var i = 1; i < nrcsIntakeFamiliesInitial.length; i++) {
        expect(nrcsIntakeFamiliesInitial[i].border.z(6 * 3600), greaterThan(nrcsIntakeFamiliesInitial[i - 1].border.z(6 * 3600)));
        expect(nrcsIntakeFamiliesInitial[i].furrow.z(6 * 3600), greaterThan(nrcsIntakeFamiliesInitial[i - 1].furrow.z(6 * 3600)));
      }
      expect(nrcsIntakeFamily(0.5, later: true).a, 0.411);
      expect(f.refFlow, closeTo(20.152 * m3sPerGpm, 1e-12));
      expect(f.refPerimeterM, closeTo(0.767 * metersPerFoot, 1e-12));
    });

    test('families interpolate between table rows and clamp at the ends', () {
      final mid = nrcsIntakeFamily(0.55);
      expect(mid.a, closeTo((0.514 + 0.537) / 2, 1e-12));
      expect(nrcsIntakeFamily(0.001).family, 0.02);
      expect(nrcsIntakeFamily(9).family, 4.00);
      expect(nrcsIntakeFamiliesInitial.length, 19);
      expect(nrcsIntakeFamiliesLater.length, 19);
      for (var i = 0; i < 19; i++) {
        expect(nrcsIntakeFamiliesLater[i].a, lessThan(nrcsIntakeFamiliesInitial[i].a), reason: 'later irrigations take in less');
      }
    });

    test('furrow intake scales with the wetted perimeter (NEH 623 ch. 4, eq. 4-78)', () {
      final ref = nrcsFurrowIntake(1.0);
      final wide = nrcsFurrowIntake(1.0, wettedPerimeterM: 2 * 1.050 * metersPerFoot);
      expect(wide.k, closeTo(2 * ref.k, 1e-15));
      expect(wide.f0, closeTo(2 * ref.f0, 1e-15));
      expect(nrcsBorderIntake(1.0).k, closeTo(0.010856 * metersPerFoot * math.pow(60, -0.597), 1e-15));
    });
  });
}
