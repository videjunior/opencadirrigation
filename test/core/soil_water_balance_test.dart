import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/crops.dart';
import 'package:opencadirrigation/core/design/irrigation_requirement.dart';
import 'package:opencadirrigation/core/design/soil_water_balance.dart';
import 'package:opencadirrigation/core/model/agronomy_plan.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/site_climate.dart';

/// The daily soil water balance of FAO-56 chapter 8 (1.6.0 AGR), checked by
/// hand: Kc 1, ETo 5 mm/day, no rain, AWC 100 mm/m, Zr 1 m (TAW 100 mm),
/// p 0.5 (RAW 50 mm), Ea 0.8.
void main() {
  const square = [Pt(0, 0), Pt(100, 0), Pt(100, 100), Pt(0, 100)];
  final dry = ClimateNormals(etoMmDay: List.filled(12, 5.0), rainMm: List.filled(12, 0.0));

  BalanceInput input(BalanceSettings s, {ClimateNormals? normals, double? ky}) => BalanceInput(
    weather: typicalYearWeather(normals ?? dry),
    curve: const KcCurve.constant(1),
    planting: DateTime.utc(2001, 1, 1),
    awcMmPerM: 100,
    rootDepthM: 1,
    depletionFraction: 0.5,
    adjustDepletionToEtc: false,
    efficiency: 0.8,
    settings: s,
    ky: ky,
  );

  group('typical year of the normals', () {
    test('the ETo of each month every day and its rain in equal events', () {
      final w = typicalYearWeather(ClimateNormals(etoMmDay: List.filled(12, 5.0), rainMm: List.filled(12, 40.0)));
      expect(w, hasLength(365));
      expect(w.first.date, DateTime.utc(2001, 1, 1));
      // 31 days, four events: the 4th, 12th, 20th and 28th
      expect(
        [
          for (final d in w.take(31))
            if (d.rainMm > 0) d.date.day,
        ],
        [4, 12, 20, 28],
      );
      expect(w[3].rainMm, 10);
      expect(w.fold(0.0, (s, d) => s + d.rainMm), closeTo(480, 1e-9));
      expect(w.every((d) => d.etoMm == 5), isTrue);
    });
  });

  group('daily balance (FAO-56 chapter 8)', () {
    test('irrigating at the readily available water: 36 refills of 50 mm, the balance closes', () {
      final r = soilWaterBalance(input(BalanceSettings()));
      expect(r.days, hasLength(365));
      expect(r.days.first.tawMm, 100);
      expect(r.days.first.rawMm, 50);
      expect(r.days.first.stage, 2, reason: 'a crop of Kc constant all year is in mid-season');
      expect(r.events, hasLength(36));
      expect(r.events.first.date, DateTime.utc(2001, 1, 10));
      expect(r.events.first.depletionMm, closeTo(50, 1e-9));
      expect(r.events.every((e) => (e.netMm - 50).abs() < 1e-9 && (e.grossMm - 62.5).abs() < 1e-9), isTrue);
      expect(r.events[1].date.difference(r.events[0].date).inDays, 10);
      expect(r.etcMm, closeTo(1825, 1e-9));
      expect(r.etaMm, closeTo(1825, 1e-9));
      expect(r.netMm, closeTo(1800, 1e-9));
      expect(r.grossMm, closeTo(2250, 1e-9));
      expect(r.finalDepletionMm, closeTo(25, 1e-9));
      expect(r.closureErrorMm, closeTo(0, 1e-9));
      expect(r.stressDays, 0);
      expect(r.relativeEt, 1);
      expect(r.warnings, isEmpty);
    });

    test('rain only: the crop dries the root zone and the yield falls by Ky', () {
      final r = soilWaterBalance(input(BalanceSettings(trigger: BalanceTrigger.rainfed), ky: 1.0));
      expect(r.events, isEmpty);
      // RAW reached on day 10, stressed from day 11 on
      expect(r.stressDays, 354);
      expect(r.days[10].ks, 1);
      expect(r.days[11].ks, closeTo(0.9, 1e-12));
      expect(r.finalDepletionMm, closeTo(100, 1e-6));
      expect(r.closureErrorMm, closeTo(0, 1e-9));
      expect(r.relativeEt, closeTo(r.finalDepletionMm / 1825, 1e-9));
      expect(r.relativeYield, closeTo(r.relativeEt, 1e-12));
      expect(r.warnings, isNot(contains('wb_stress')), reason: 'stress is what rain-only asks to see');
    });

    test('regulated deficit: irrigating at 70 % of the available water stresses the crop', () {
      final r = soilWaterBalance(input(BalanceSettings(allowedDepletion: [0, 0, 0.7, 0])));
      // days 11–14 stressed: Ks 0.9, 0.81, 0.729, 0.6561; refill on day 14
      expect(r.events.first.date, DateTime.utc(2001, 1, 15));
      expect(r.events.first.netMm, closeTo(70.4755, 1e-9));
      expect(r.events, hasLength(24));
      expect(r.events.every((e) => e.depletionMm >= 70 - 1e-9), isTrue);
      expect(r.stressDays, greaterThan(90));
      expect(r.relativeEt, inExclusiveRange(0.9, 0.97));
      expect(r.warnings, contains('wb_stress'));
      expect(r.closureErrorMm, closeTo(0, 1e-9));
    });

    test('a fixed interval refills whatever was used; partial refills', () {
      final r = soilWaterBalance(input(BalanceSettings(trigger: BalanceTrigger.interval, intervalDays: 7)));
      expect(r.events, hasLength(53));
      expect(r.events[0].netMm, closeTo(5, 1e-9));
      expect(r.events[1].date.difference(r.events[0].date).inDays, 7);
      expect(r.events[1].netMm, closeTo(35, 1e-9));
      expect(r.netMm, closeTo(1825, 1e-9));
      expect(r.closureErrorMm, closeTo(0, 1e-9));
      final half = soilWaterBalance(input(BalanceSettings(refillPct: 50)));
      expect(half.events.first.netMm, closeTo(25, 1e-9));
      expect(half.events[1].date.difference(half.events[0].date).inDays, 5);
      expect(half.closureErrorMm, closeTo(0, 1e-9));
    });

    test('rain below a fifth of the ETo only wets the surface', () {
      final light = soilWaterBalance(
        input(
          BalanceSettings(),
          normals: ClimateNormals(etoMmDay: List.filled(12, 5.0), rainMm: List.filled(12, 2.0)),
        ),
      );
      expect(light.rainMm, closeTo(24, 1e-9));
      expect(light.effectiveRainMm, 0);
      final wet = soilWaterBalance(
        input(
          BalanceSettings(),
          normals: ClimateNormals(etoMmDay: List.filled(12, 5.0), rainMm: List.filled(12, 40.0)),
        ),
      );
      expect(wet.effectiveRainMm, closeTo(480, 1e-9));
      expect(wet.netMm, lessThan(1800));
      expect(wet.closureErrorMm, closeTo(0, 1e-9));
    });

    test('no weather, no soil water', () {
      final none = soilWaterBalance(
        BalanceInput(weather: const [], curve: const KcCurve.constant(1), planting: DateTime.utc(2001), awcMmPerM: 100, rootDepthM: 1, depletionFraction: 0.5, settings: BalanceSettings()),
      );
      expect(none.warnings, ['wb_no_weather']);
      final noSoil = soilWaterBalance(input(BalanceSettings()).copyWithAwc(0));
      expect(noSoil.warnings, contains('wb_no_soil_water'));
    });
  });

  group('balance of an irrigated area', () {
    test('typed ETo and Kc: the same hand case from the area', () {
      final a = AreaEntity(id: 'a', points: square, useWaterBalance: true, etoMmDay: 5, kc: 1, awcMmPerM: 100, rootDepthM: 1, mad: 0.5, efficiency: 0.8);
      final p = Project(entities: [a]);
      final r = areaWaterBalance(p, a)!;
      expect(r.events, hasLength(36));
      expect(r.events.first.grossMm, closeTo(62.5, 1e-9));
      expect(r.relativeYield, isNull, reason: 'no Ky for a typed Kc');
      // a fixed daily depth has no balance
      expect(areaWaterBalance(p, AreaEntity(id: 'b', points: square)), isNull);
      // localized: Kr times the ETc, TAW and RAW times the wetted fraction
      a
        ..irrigationMethod = 'localized'
        ..wettedFraction = 0.5
        ..groundCover = 0.64;
      final drip = areaWaterBalance(p, a)!;
      expect(drip.days.first.tawMm, closeTo(50, 1e-9));
      expect(drip.days.first.etcMm, closeTo(0.8 * 5, 1e-9));
      // 4 mm a day against RAW 25 mm: refilled on day 7, 28 mm
      expect(drip.days.first.rawMm, closeTo(25, 1e-9));
      expect(drip.events.first.date, DateTime.utc(2001, 1, 7));
      expect(drip.events.first.netMm, closeTo(28, 1e-9));
    });

    test('a crop of the table runs its season from planting with its stages and Ky', () {
      final a = AreaEntity(id: 'a', points: square, useWaterBalance: true, cropKey: 'crop.maize', etoMmDay: 5, awcMmPerM: 140, rootDepthM: 1, mad: 0.55);
      final p = Project(entities: [a]);
      final r = areaWaterBalance(p, a)!;
      expect(r.days, hasLength(150));
      expect(r.days.first.date, DateTime.utc(2001, 4, 1));
      expect({for (final d in r.days) d.stage}, {0, 1, 2, 3});
      // Kc ini follows the wetting of the initial stage (AGR-09, on by
      // default): this deep soil, wetted at planting, needs no irrigation in
      // the 30 days of the stage (FAO-56 Annex 7, heavy wetting, medium soil)
      expect(r.days.first.kc, closeTo(kcIniFromWetting(etoMmDay: 5, wettingIntervalDays: 30, infiltrationDepthMm: 40), 1e-9));
      expect(r.days.first.kc, inExclusiveRange(0.15, 0.3));
      // the table's Kc ini with the adjustment off
      a.climateKc = false;
      expect(areaWaterBalance(p, a)!.days.first.kc, closeTo(0.3, 1e-9));
      a.climateKc = true;
      expect(r.ky, fao33SeasonalKy['crop.maize']);
      // p follows the ETc of the day (Table 22 note 2): a day can start just
      // above a RAW that fell overnight, nothing more
      expect(r.relativeYield!, greaterThan(0.99));
      expect(r.closureErrorMm, closeTo(0, 1e-6));
      // the stored settings of the area are the ones used
      p.agronomy.balance['a'] = BalanceSettings(trigger: BalanceTrigger.rainfed);
      final rainfed = areaWaterBalance(p, a)!;
      expect(rainfed.events, isEmpty);
      expect(rainfed.relativeYield!, lessThan(0.9));
    });

    test('a year of the daily series of the site', () {
      final days = [for (var i = 0; i < 730; i++) (DateTime.utc(2018).add(Duration(days: i)), 5.0, DateTime.utc(2018).add(Duration(days: i)).year == 2019 && i % 7 == 0 ? 15.0 : 0.0)];
      final a = AreaEntity(id: 'a', points: square, useWaterBalance: true, etoMmDay: 5, kc: 1, awcMmPerM: 100, rootDepthM: 1, mad: 0.5, efficiency: 0.8);
      final p = Project(entities: [a])..climate = SiteClimate(etoMmDay: List.filled(12, 5.0), rainMm: List.filled(12, 0.0), daily: DailyClimate.fromDays(days));
      expect(balanceYears(p), [2018, 2019]);
      final y2018 = areaWaterBalance(p, a, settings: BalanceSettings(year: 2018))!;
      final y2019 = areaWaterBalance(p, a, settings: BalanceSettings(year: 2019))!;
      expect(y2018.rainMm, 0);
      expect(y2019.rainMm, greaterThan(0));
      expect(y2019.netMm, lessThan(y2018.netMm));
      expect(y2019.days.first.date, DateTime.utc(2019, 1, 1));
    });
  });
}

extension on BalanceInput {
  BalanceInput copyWithAwc(double awc) => BalanceInput(
    weather: weather,
    curve: curve,
    planting: planting,
    awcMmPerM: awc,
    rootDepthM: rootDepthM,
    depletionFraction: depletionFraction,
    adjustDepletionToEtc: adjustDepletionToEtc,
    efficiency: efficiency,
    settings: settings,
  );
}
