import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/climate.dart';
import 'package:opencadirrigation/core/design/crops.dart';
import 'package:opencadirrigation/core/design/effective_rain.dart';
import 'package:opencadirrigation/core/design/irrigation_requirement.dart';

/// Requirement tables against published worked examples: FAO Irrigation
/// Manual Module 9 (Examples 1, 2 and 6: drip-irrigated citrus), FAO-29
/// Example 3 (leaching of maize), FAO Training Manual 3 sections 4.3 and 4.4
/// (irrigation need, paddy rice), plus the bookkeeping of months, periods
/// and crop cycles.
void main() {
  ClimateNormals flat(double eto, {double rain = 0}) => ClimateNormals(etoMmDay: List.filled(12, eto), rainMm: List.filled(12, rain));

  group('leaching requirement (FAO-29)', () {
    test('Example 3: maize, river water of 1.2 dS/m', () {
      // ECe 2.5 dS/m for 90 % yield, 1.7 dS/m for 100 % (Table 4)
      final lr90 = leachingRequirement(ecwDsM: 1.2, eceDsM: 2.5)!;
      final lr100 = leachingRequirement(ecwDsM: 1.2, eceDsM: 1.7)!;
      expect(lr90, closeTo(0.10, 0.01));
      expect(lr100, closeTo(0.16, 0.01));
      // applied water to meet ET and leaching: 800/(1 − LR) ≈ 890 mm
      expect(800 / (1 - lr90), closeTo(890, 9));
      expect(eceForYieldPotential(eceThreshold: 1.7, eceMax: 10, yieldPct: 90), closeTo(2.5, 0.05));
    });

    test('high-frequency drip uses the zero-yield ECe; saline water can be infeasible', () {
      expect(leachingRequirement(ecwDsM: 1.2, eceDsM: 10, formula: LeachingFormula.highFrequencyDrip), closeTo(0.06, 1e-9));
      expect(leachingRequirement(ecwDsM: 0, eceDsM: 1.7), 0);
      expect(leachingRequirement(ecwDsM: 10, eceDsM: 1.7), isNull);
      expect(leachingRequirement(ecwDsM: 30, eceDsM: 10, formula: LeachingFormula.highFrequencyDrip), isNull);
    });
  });

  group('FAO Irrigation Manual Module 9: drip-irrigated citrus', () {
    // Example 1: peak ETc 7.1 mm/day, 70 % ground cover, Kr 0.85 (Freeman &
    // Garzoli); Example 2: Ea = 0.95·0.90 = 0.86; Example 6: trees 6 × 6 m,
    // Pw 60 %, available water 120 mm/m over 1 m, 20 % depletion.
    final input = RequirementInput(
      areaId: 'a1',
      areaM2: 36,
      cycles: [CropCycle(cropKey: 'crop.citrus', curve: const KcCurve.constant(1), planting: DateTime.utc(2001), kr: localizedReductionFactor(0.7, method: LocalizedReductionMethod.freemanGarzoli))],
      climate: flat(7.1),
      rainMethod: EffectiveRainMethod.none,
      efficiency: 0.86,
      wettedFraction: 0.6,
      awcMmPerM: 120,
      rootDepthM: 1,
      depletionFraction: 0.2,
      adjustDepletionToEtc: false,
      applicationRateMmH: 2,
    );

    test('net and gross daily requirement (Examples 1 and 2)', () {
      final t = irrigationRequirement(input);
      final july = t.monthly.firstWhere((r) => r.periodId == '2001-07');
      expect(july.etcLocMmDay, closeTo(6.035, 1e-9)); // printed 6.04
      expect(july.netMmDay, closeTo(6.04, 0.006));
      expect(july.grossMmDay, closeTo(7.02, 0.005));
      // 217 litres per tree and day
      expect(july.netMmDay * 36, closeTo(217, 1));
    });

    test('irrigation frequency at peak demand (Example 6): 2 days, 434 litres per tree', () {
      final july = irrigationRequirement(input).monthly.firstWhere((r) => r.periodId == '2001-07');
      expect(july.rawMm * 36, closeTo(518, 1)); // readily available water per tree (L)
      expect(july.maxIntervalDays, closeTo(2.39, 0.01));
      expect(july.intervalDays, 2);
      expect(july.netPerEventMm * 36, closeTo(434, 1));
      expect(july.hoursPerEvent, closeTo(july.grossPerEventMm / 2, 1e-9));
      expect(july.events, closeTo(31 / 2, 1e-9));
      expect(july.warnings, isEmpty);
    });

    test('a fixed interval beyond the RAW is flagged', () {
      final t = irrigationRequirement(RequirementInput(areaId: 'a1', areaM2: 36, cycles: input.cycles, climate: input.climate, rainMethod: EffectiveRainMethod.none, wettedFraction: 0.6, rootDepthM: 1, depletionFraction: 0.2, adjustDepletionToEtc: false, fixedIntervalDays: 4));
      final july = t.monthly.firstWhere((r) => r.periodId == '2001-07');
      expect(july.intervalDays, 4);
      expect(july.warnings, containsAll(['req_interval_exceeds_raw', 'req_no_application_rate']));
      expect(july.hoursPerEvent, isNull);
    });
  });

  test('FAO Training Manual 3, section 4.3: monthly irrigation need of a crop', () {
    // ETc of February to June 69, 123, 180, 234, 180 mm with rain of 20, 38,
    // 40, 80 and 16 mm: IN = 67, 110, 166, 195, 180 mm
    const etcMonth = <double>[0, 69, 123, 180, 234, 180, 0, 0, 0, 0, 0, 0];
    const rainMonth = <double>[0, 20, 38, 40, 80, 16, 0, 0, 0, 0, 0, 0];
    final eto = [for (var m = 1; m <= 12; m++) etcMonth[m - 1] / daysInMonth(2001, m)];
    final t = irrigationRequirement(RequirementInput(
      areaId: 'tm3',
      areaM2: 10000,
      cycles: [CropCycle(cropKey: 'crop.vegetables', curve: const KcCurve.constant(1), planting: DateTime.utc(2001))],
      climate: ClimateNormals(etoMmDay: eto, rainMm: rainMonth),
      rainMethod: EffectiveRainMethod.faoEmpirical,
      efficiency: 1,
    ));
    const need = <double>[67, 110, 166, 195, 180];
    for (var m = 2; m <= 6; m++) {
      final r = t.monthly.firstWhere((r) => r.periodId == '2001-0$m');
      expect(r.etcMm, closeTo(etcMonth[m - 1], 1e-6));
      expect(r.netMm, closeTo(need[m - 2], 0.5), reason: 'month $m');
      expect(r.grossMm, closeTo(r.netMm, 1e-9));
      // 1 mm on a hectare is 10 m³
      expect(r.volumeM3, closeTo(r.grossMm * 10, 1e-6));
    }
  });

  test('FAO Training Manual 3, section 4.4: paddy rice in April needs 313 mm', () {
    // ETo 6 mm/day, Kc 1.1, percolation 5 mm/day, 100 mm water layer, Pe 135 mm
    final t = irrigationRequirement(RequirementInput(
      areaId: 'rice',
      areaM2: 10000,
      cycles: [CropCycle(cropKey: 'crop.rice', curve: const KcCurve(kcIni: 1.1, kcMid: 1.1, kcEnd: 1.1, stages: CropStages(30, 0, 0, 0)), planting: DateTime.utc(2001, 4, 1), percolationMmDay: 5, establishmentMm: 100)],
      climate: ClimateNormals(etoMmDay: List.filled(12, 6), rainMm: [0, 0, 0, 135, 0, 0, 0, 0, 0, 0, 0, 0]),
      rainMethod: EffectiveRainMethod.total,
      efficiency: 1,
    ));
    final april = t.monthly.single;
    expect(april.periodId, '2001-04');
    expect(april.cropDays, 30);
    expect(april.etcMm, closeTo(198, 1e-6));
    expect(april.extraMm, closeTo(250, 1e-6));
    expect(april.effectiveRainMm, closeTo(135, 1e-6));
    expect(april.netMm, closeTo(313, 1e-6));
    expect(april.netMmDay, closeTo(10.4, 0.05));
  });

  group('salinity in the table', () {
    CropCycle maize() => CropCycle.fromTable('crop.maize', planting: DateTime.utc(2001, 4, 1));

    test('multiplicative rule: gross = net/(Ea·(1 − LR))', () {
      final t = irrigationRequirement(RequirementInput(areaId: 'm', areaM2: 1, cycles: [maize()], climate: flat(5), rainMethod: EffectiveRainMethod.none, efficiency: 0.65, ecwDsM: 1.2, yieldPotentialPct: 90));
      final r = t.monthly.firstWhere((r) => r.periodId == '2001-06');
      expect(r.leachingFraction, closeTo(1.2 / (5 * eceForYieldPotential(eceThreshold: 1.7, eceMax: 10, yieldPct: 90) - 1.2), 1e-9));
      expect(r.grossMm, closeTo(r.netMm / (0.65 * (1 - r.leachingFraction)), 1e-9));
    });

    test('FAO-29 Example 3 reasoning: application losses already leach', () {
      final t = irrigationRequirement(RequirementInput(areaId: 'm', areaM2: 1, cycles: [maize()], climate: flat(5), rainMethod: EffectiveRainMethod.none, efficiency: 0.65, ecwDsM: 1.2, yieldPotentialPct: 90, leachingRule: LeachingRule.lossesLeach));
      final r = t.monthly.firstWhere((r) => r.periodId == '2001-06');
      expect(r.grossMm, closeTo(r.netMm / 0.65, 1e-9));
    });

    test('high-frequency drip and too saline water', () {
      final drip = irrigationRequirement(RequirementInput(areaId: 'm', areaM2: 1, cycles: [maize()], climate: flat(5), rainMethod: EffectiveRainMethod.none, ecwDsM: 1.2, leachingFormula: LeachingFormula.highFrequencyDrip));
      expect(drip.monthly.first.leachingFraction, closeTo(0.06, 1e-9));
      final salty = irrigationRequirement(RequirementInput(areaId: 'm', areaM2: 1, cycles: [maize()], climate: flat(5), rainMethod: EffectiveRainMethod.none, ecwDsM: 9));
      expect(salty.monthly.first.warnings, contains('req_leaching_infeasible'));
      final unknown = irrigationRequirement(RequirementInput(areaId: 'm', areaM2: 1, cycles: [CropCycle.fromTable('crop.coffee', planting: DateTime.utc(2001))], climate: flat(5), ecwDsM: 1));
      expect(unknown.monthly.first.warnings, contains('req_salt_tolerance_unknown'));
      expect(unknown.monthly.first.leachingFraction, 0);
    });
  });

  group('months, periods and cycles', () {
    final tomato = fao56Crops['crop.tomato']!;
    RequirementInput two() => RequirementInput(
      areaId: 'v',
      areaM2: 5000,
      cycles: [
        CropCycle.fromTable('crop.tomato', planting: DateTime.utc(2001, 4, 1), repeatsYearly: false),
        // planted every year on 1 September: runs into January of the typical year
        CropCycle.fromTable('crop.maize', planting: DateTime.utc(2001, 9, 1)),
      ],
      climate: ClimateNormals(etoMmDay: [6, 5.5, 5, 4, 3.5, 3, 3.2, 4, 4.8, 5.5, 6, 6.2], rainMm: [220, 180, 160, 80, 60, 40, 30, 30, 60, 120, 150, 200]),
      efficiency: 0.9,
      applicationRateMmH: 3,
      operatingHoursPerDay: 20,
    );

    test('each cycle keeps its own Kc and months; depths and volumes add up', () {
      final t = irrigationRequirement(two());
      expect(t.warnings, isEmpty);
      final tom = t.monthly.where((r) => r.cycleIndex == 0).toList();
      final mz = t.monthly.where((r) => r.cycleIndex == 1).toList();
      expect(tom.fold(0, (s, r) => s + r.cropDays), tomato.stages!.total);
      expect(mz.fold(0, (s, r) => s + r.cropDays), fao56Crops['crop.maize']!.stages!.total);
      expect(tom.first.periodId, '2001-04');
      expect(tom.first.kc, closeTo(tomato.kcIni, 1e-9));
      expect(tom.every((r) => r.cropKey == 'crop.tomato'), isTrue);
      // ETc = Σ ETo·Kc, net = ETc − Pe, never negative
      for (final r in t.monthly) {
        expect(r.etcMm, closeTo(r.etoMm * r.kc, 1e-6));
        expect(r.netMm, closeTo((r.etcLocMm - r.effectiveRainMm).clamp(0, double.infinity), 1e-9));
        expect(r.effectiveRainMm, lessThanOrEqualTo(r.rainMm + 1e-9));
        expect(r.flowM3h, closeTo(r.dailyVolumeM3 / 20, 1e-9));
      }
      final total = t.areaTotals;
      expect(total.volumeM3, closeTo(t.cycleTotals[0].volumeM3 + t.cycleTotals[1].volumeM3, 1e-6));
      expect(total.netMm, closeTo(t.monthly.fold(0.0, (s, r) => s + r.netMm), 1e-9));
      expect(total.peakNetMmDay, greaterThan(0));
      expect(t.monthly.map((r) => r.periodId), contains(total.peakPeriodId));
    });

    test('user periods sum to the months they cover', () {
      final t = irrigationRequirement(two(), periods: [
        RequirementPeriod(id: 'season1', start: DateTime.utc(2001, 4, 1), end: DateTime.utc(2001, 8, 31)),
        RequirementPeriod(id: 'q4', start: DateTime.utc(2001, 10, 1), end: DateTime.utc(2001, 12, 31)),
      ]);
      final s1 = t.periods.firstWhere((r) => r.periodId == 'season1' && r.cycleIndex == 0);
      final months = t.monthly.where((r) => r.cycleIndex == 0);
      expect(s1.cropDays, months.fold(0, (s, r) => s + r.cropDays));
      expect(s1.etcMm, closeTo(months.fold(0.0, (s, r) => s + r.etcMm), 1e-6));
      expect(s1.effectiveRainMm, closeTo(months.fold(0.0, (s, r) => s + r.effectiveRainMm), 1e-6));
      expect(s1.kc, closeTo(s1.etcMm / s1.etoMm, 1e-9));
      // the maize cycle has no day in season1 before September
      expect(t.periods.where((r) => r.periodId == 'season1' && r.cycleIndex == 1), isEmpty);
      expect(t.periods.where((r) => r.periodId == 'q4').single.cropKey, 'crop.maize');
    });

    test('periods in another year use the same monthly normals', () {
      final t = irrigationRequirement(
        RequirementInput(areaId: 'p', areaM2: 1, cycles: [CropCycle.fromTable('crop.citrus', planting: DateTime.utc(2001))], climate: flat(5, rain: 31)),
        periods: [RequirementPeriod(id: 'y2030', start: DateTime.utc(2030), end: DateTime.utc(2030, 12, 31))],
      );
      expect(t.periods.single.cropDays, 365);
      expect(t.periods.single.etoMm, closeTo(365 * 5, 1e-6));
    });

    test('overlapping cycles in the same area are flagged; no cycle is reported', () {
      final t = irrigationRequirement(RequirementInput(
        areaId: 'o',
        areaM2: 1,
        cycles: [CropCycle.fromTable('crop.tomato', planting: DateTime.utc(2001, 4, 1)), CropCycle.fromTable('crop.lettuce', planting: DateTime.utc(2001, 5, 1))],
        climate: flat(5),
      ));
      expect(t.warnings, contains('req_cycles_overlap:0:1'));
      expect(irrigationRequirement(RequirementInput(areaId: 'e', areaM2: 1, cycles: const [], climate: flat(5))).warnings, ['req_no_cycles']);
    });

    test('dependable rain and the monthly-climate constructor', () {
      final months = [for (var m = 1; m <= 12; m++) MonthlyClimate(month: m, tMaxC: 30, tMinC: 18, windSpeed2mMs: 2, rainMm: 100, dependableRainMm: 60)];
      final c = ClimateNormals.fromMonthlyClimate(months, latitudeDeg: -15, elevationM: 500);
      expect(c.etoMmDay.every((e) => e > 2 && e < 8), isTrue);
      expect(c.dependableRainMm, everyElement(60));
      final input = RequirementInput(areaId: 'd', areaM2: 1, cycles: [CropCycle.fromTable('crop.turf', planting: DateTime.utc(2001))], climate: c, rainMethod: EffectiveRainMethod.total);
      final mean = irrigationRequirement(input).areaTotals;
      final dep = irrigationRequirement(RequirementInput(areaId: 'd', areaM2: 1, cycles: input.cycles, climate: c, rainMethod: EffectiveRainMethod.total, useDependableRain: true)).areaTotals;
      expect(dep.effectiveRainMm, lessThan(mean.effectiveRainMm));
      expect(dep.netMm, greaterThan(mean.netMm));
      expect(() => ClimateNormals(etoMmDay: [1, 2], rainMm: List.filled(12, 0)), throwsArgumentError);
    });
  });
}
