import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/soils.dart';
import 'package:opencadirrigation/core/design/water_budget.dart';

/// MWELO 2015 water budget (23 CCR §§ 490–495, Appendix B) and the SWAT
/// cycle-and-soak rule (Rt = 60·ASA/(PR − IR), start-to-start ≥ Da/IR).
void main() {
  group('MWELO water budget', () {
    test('MAWA of a residential landscape in US units', () {
      // ETo 50 in/year, 5000 ft², no special areas: 50·0.62·0.55·5000 gallons
      expect(maximumAppliedWaterAllowance(etoPerYear: 50, landscapeArea: 5000, units: BudgetUnits.us), closeTo(85250, 1e-6));
      // a special landscape area gets the whole ETo
      expect(maximumAppliedWaterAllowance(etoPerYear: 50, landscapeArea: 5000, specialArea: 1000, units: BudgetUnits.us), closeTo(50 * 0.62 * (0.55 * 5000 + 0.45 * 1000), 1e-6));
    });

    test('ETWU with ETAF = PF/IE per hydrozone and the compliance checks', () {
      final b = mweloWaterBudget(
        etoPerYear: 50,
        units: BudgetUnits.us,
        hydrozones: const [
          Hydrozone(id: 'lawn', area: 2000, plantFactor: 0.7),
          Hydrozone(id: 'shrubs', area: 3000, plantFactor: 0.3, irrigationEfficiency: mweloEfficiencyDrip),
        ],
      );
      final lawn = 50 * 0.62 * 0.7 / 0.75 * 2000, shrubs = 50 * 0.62 * 0.3 / 0.81 * 3000;
      expect(b.perHydrozone['lawn'], closeTo(lawn, 1e-6));
      expect(b.perHydrozone['shrubs'], closeTo(shrubs, 1e-6));
      expect(b.etwu, closeTo(lawn + shrubs, 1e-6));
      expect(b.mawa, closeTo(85250, 1e-6));
      expect(b.averageEtaf, closeTo((0.7 / 0.75 * 2000 + 0.3 / 0.81 * 3000) / 5000, 1e-12));
      expect(b.complies, isFalse); // ETAF 0.60 > 0.55 and ETWU > MAWA
      final ok = mweloWaterBudget(
        etoPerYear: 50,
        units: BudgetUnits.us,
        hydrozones: const [
          Hydrozone(id: 'shrubs', area: 4000, plantFactor: 0.3, irrigationEfficiency: mweloEfficiencyDrip),
          Hydrozone(id: 'veg', area: 1000, plantFactor: 0.8, specialLandscapeArea: true),
        ],
      );
      expect(ok.specialArea, 1000);
      expect(ok.landscapeArea, 5000);
      expect(ok.complies, isTrue);
    });

    test('metric budgets give litres and agree with the US factor', () {
      // 1270 mm/year on 1000 m² with 100 m² of SLA
      final l = maximumAppliedWaterAllowance(etoPerYear: 1270, landscapeArea: 1000, specialArea: 100);
      expect(l, closeTo(1270 * (0.55 * 1000 + 0.45 * 100), 1e-6));
      const ft2 = 10.7639104;
      final gal = maximumAppliedWaterAllowance(etoPerYear: 50, landscapeArea: 1000 * ft2, specialArea: 100 * ft2, units: BudgetUnits.us);
      // the ordinance's 0.62 is 0.6234 rounded down
      expect(gal * 3.785411784 / l, closeTo(0.62 / 0.62337, 0.002));
      final nonRes = mweloWaterBudget(etoPerYear: 1000, residential: false, hydrozones: const [Hydrozone(id: 'z', area: 100, plantFactor: 0.2)]);
      expect(nonRes.etafLimit, mweloEtafNonResidential);
      expect(nonRes.mawa, closeTo(1000 * 0.45 * 100, 1e-6));
    });

    test('plant factor categories', () {
      expect(plantFactorRange(PlantWaterUse.moderate), (0.4, 0.6));
      expect(plantWaterUseOf(0.05), PlantWaterUse.veryLow);
      expect(plantWaterUseOf(0.2), PlantWaterUse.low);
      expect(plantWaterUseOf(0.5), PlantWaterUse.moderate);
      expect(plantWaterUseOf(0.8), PlantWaterUse.high);
      expect(const Hydrozone(id: 'h', area: 1, plantFactor: 0.6, specialLandscapeArea: true).etaf, 1.0);
    });
  });

  group('cycle and soak', () {
    test('1.5 in/h sprays on a clay loam with 5 % slope applying 0.5 in', () {
      // IR 0.20 in/h, ASA 0.22 in: Rt = 60·0.22/(1.5 − 0.2) = 10.2 min
      final c = cycleAndSoakForSoil(precipitationRateMmH: 1.5 * 25.4, depthMm: 0.5 * 25.4, texture: SoilTexture.clayLoam, slopePct: 5);
      expect(c.maxCycleMinutes, closeTo(60 * 0.22 / 1.3, 1e-9));
      expect(c.totalRunMinutes, closeTo(20, 1e-9));
      expect(c.cycles, 2);
      expect(c.runMinutesPerCycle, closeTo(10, 1e-9));
      expect(c.depthPerCycleMm, closeTo(0.25 * 25.4, 1e-9));
      // next start no earlier than Da/IR = 0.25/0.2 h = 75 min after the first
      expect(c.soakMinutes, closeTo(65, 1e-9));
      expect(c.windowMinutes, closeTo(85, 1e-9));
      expect(c.needsCycling, isTrue);
    });

    test('no cycling when the soil takes the rate; steeper slopes need more cycles', () {
      final drip = cycleAndSoak(precipitationRateMmH: 5, depthMm: 10, intakeRateMmH: 8, allowableSurfaceMm: 5);
      expect(drip.cycles, 1);
      expect(drip.maxCycleMinutes, double.infinity);
      expect(drip.soakMinutes, 0);
      final flat = cycleAndSoakForSoil(precipitationRateMmH: 40, depthMm: 15, texture: SoilTexture.clay, slopePct: 1);
      final steep = cycleAndSoakForSoil(precipitationRateMmH: 40, depthMm: 15, texture: SoilTexture.clay, slopePct: 15);
      expect(steep.cycles, greaterThan(flat.cycles));
      // a minimum practical cycle merges cycles
      final merged = cycleAndSoakForSoil(precipitationRateMmH: 40, depthMm: 15, texture: SoilTexture.clay, slopePct: 15, minCycleMinutes: 10);
      expect(merged.cycles, lessThanOrEqualTo(steep.cycles));
      expect(merged.runMinutesPerCycle, greaterThanOrEqualTo(10 - 1e-9));
      expect(cycleAndSoak(precipitationRateMmH: 40, depthMm: 0, intakeRateMmH: 2, allowableSurfaceMm: 5).cycles, 0);
      expect(steep.runoffFree, isTrue);
    });

    test('no surface storage: the most cycles allowed, and the runoff is reported', () {
      final c = cycleAndSoak(precipitationRateMmH: 40, depthMm: 10, intakeRateMmH: 2, allowableSurfaceMm: 0, maxCycles: 6);
      expect(c.maxCycleMinutes, 0);
      expect(c.cycles, 6);
      expect(c.runoffFree, isFalse);
    });
  });
}
