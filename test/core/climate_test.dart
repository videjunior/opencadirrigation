import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/climate.dart';

/// FAO Penman-Monteith ETo and its parts against the worked examples of
/// FAO Irrigation and Drainage Paper 56 (Allen et al. 1998), chapters 3
/// and 4, within their printed precision.
void main() {
  group('FAO-56 chapter 3', () {
    test('Example 2: pressure and psychrometric constant at 1800 m', () {
      final p = atmosphericPressureKPa(1800);
      expect(p, closeTo(81.8, 0.05));
      expect(psychrometricConstantKPaPerC(p), closeTo(0.054, 0.0005));
    });

    test('Example 3: saturation vapour pressure of a day', () {
      expect(saturationVapourPressureKPa(24.5), closeTo(3.075, 0.0005));
      expect(saturationVapourPressureKPa(15), closeTo(1.705, 0.0005));
      expect(meanSaturationVapourPressureKPa(24.5, 15), closeTo(2.39, 0.005));
      expect(saturationVapourPressureKPa(19.75), closeTo(2.30, 0.005));
    });

    test('Example 4: actual vapour pressure from a ventilated psychrometer', () {
      final p = atmosphericPressureKPa(1200);
      expect(p, closeTo(87.9, 0.05));
      expect(actualVapourPressurePsychrometricKPa(25.6, 19.5, p), closeTo(1.91, 0.005));
    });

    test('Examples 5 and 6: actual vapour pressure from relative humidity', () {
      expect(saturationVapourPressureKPa(18), closeTo(2.064, 0.0005));
      expect(saturationVapourPressureKPa(25), closeTo(3.168, 0.0005));
      final ea = actualVapourPressureFromRhKPa(25, 18, 82, 54);
      expect(ea, closeTo(1.70, 0.005));
      expect(actualVapourPressureFromRhMeanKPa(25, 18, 68), closeTo(1.78, 0.005));
      expect(meanSaturationVapourPressureKPa(25, 18) - ea, closeTo(0.91, 0.005));
      expect(actualVapourPressureFromRhMaxKPa(18, 82), closeTo(2.064 * 0.82, 1e-3));
    });

    test('Examples 8 and 9: Ra and daylight hours on 3 September at 20°S', () {
      final j = dayOfYear(DateTime(2001, 9, 3));
      expect(j, 246);
      expect(inverseRelativeDistance(j), closeTo(0.985, 0.0005));
      expect(solarDeclinationRad(j), closeTo(0.120, 0.0005));
      expect(sunsetHourAngleRad(-20 * math.pi / 180, solarDeclinationRad(j)), closeTo(1.527, 0.0005));
      expect(extraterrestrialRadiationMJ(-20, j), closeTo(32.2, 0.05));
      expect(extraterrestrialRadiationMJ(-20, j) * mmPerMJPerM2, closeTo(13.1, 0.05));
      expect(daylightHours(-20, j), closeTo(11.7, 0.05));
    });

    test('Example 10: solar radiation from sunshine in Rio de Janeiro in May', () {
      final j = dayOfYear(DateTime(2001, 5, 15));
      expect(j, 135);
      final ra = extraterrestrialRadiationMJ(-22.9, j);
      expect(ra, closeTo(25.1, 0.05));
      final n = daylightHours(-22.9, j);
      expect(n, closeTo(10.9, 0.05));
      expect(solarRadiationFromSunshineMJ(ra, 220 / 31, n), closeTo(14.5, 0.05));
    });

    test('Examples 11 and 12: net longwave and net radiation in Rio de Janeiro', () {
      final rso = clearSkyRadiationMJ(25.1, 0, angstromSum: 0.75);
      expect(rso, closeTo(18.8, 0.05));
      final rnl = netLongwaveRadiationMJ(25.1, 19.1, 2.1, 14.5, rso);
      expect(rnl, closeTo(3.5, 0.05));
      // FAO-56 prints Rns = 11.1 for 0.77 × 14.5 = 11.165
      expect(netShortwaveRadiationMJ(14.5), closeTo(11.165, 1e-9));
      expect(netShortwaveRadiationMJ(14.5) - rnl, closeTo(7.6, 0.05));
    });

    test('Example 13: monthly soil heat flux in April at Algiers', () {
      expect(monthlySoilHeatFluxMJ(tMeanC: 16.1, tPrevMonthC: 14.1, tNextMonthC: 18.8), closeTo(0.33, 0.005));
      // only the previous month known (eq. 44), and daily steps (eq. 42)
      expect(monthlySoilHeatFluxMJ(tMeanC: 16.1, tPrevMonthC: 14.1), closeTo(0.28, 1e-9));
      expect(monthlySoilHeatFluxMJ(tMeanC: 16.1), 0);
    });

    test('Example 14: wind speed at 2 m from a measurement at 10 m', () {
      expect(windSpeedAt2m(3.2, 10), closeTo(2.4, 0.05));
      expect(windSpeedAt2m(1, 10), closeTo(0.748, 0.0005));
      expect(windSpeedAt2m(3, 2), 3);
    });

    test('Example 15: solar radiation from the temperature range in Lyon in July', () {
      final j = dayOfYear(DateTime(2001, 7, 15));
      expect(j, 196);
      final ra = extraterrestrialRadiationMJ(45 + 43 / 60, j);
      expect(ra, closeTo(40.6, 0.05));
      expect(solarRadiationFromTemperatureMJ(ra, 26.6, 14.8), closeTo(22.3, 0.05));
    });

    test('Example 16: net radiation in Bangkok without radiation data (coastal kRs)', () {
      final ra = extraterrestrialRadiationMJ(13 + 44 / 60, 105);
      expect(ra, closeTo(38.1, 0.05));
      final rs = solarRadiationFromTemperatureMJ(ra, 34.8, 25.6, kRs: 0.19);
      expect(rs, closeTo(21.9, 0.05));
      final rso = clearSkyRadiationMJ(ra, 2);
      final rn = netShortwaveRadiationMJ(rs) - netLongwaveRadiationMJ(34.8, 25.6, 2.85, rs, rso);
      expect(rn, closeTo(13.9, 0.05));
    });

    test('island formula and RHmin from Tmin (eqs. 51, 64)', () {
      expect(solarRadiationIslandMJ(30), closeTo(17, 1e-9));
      // Example 20: RHmin = 100·e°(Tmin)/e°(Tmax) = 48 %
      expect(minRelativeHumidityPct(tMaxC: 26.6, tMinC: 14.8), closeTo(48, 0.5));
      expect(minRelativeHumidityPct(tMaxC: 26.6), 45);
    });
  });

  group('FAO-56 chapter 4: ETo', () {
    test('Example 17: monthly ETo in Bangkok in April', () {
      expect(midMonthDayOfYear(4), 105);
      final r = fao56Eto(Fao56Input(
        latitudeDeg: 13 + 44 / 60,
        elevationM: 2,
        dayOfYear: 105,
        tMaxC: 34.8,
        tMinC: 25.6,
        actualVapourPressureKPa: 2.85,
        windSpeedMs: 2,
        sunshineHours: 8.5,
        soilHeatFluxMJ: monthlySoilHeatFluxMJ(tMeanC: 30.2, tPrevMonthC: 29.2),
      ));
      expect(r.deltaKPaPerC, closeTo(0.246, 0.0005));
      expect(r.pressureKPa, closeTo(101.3, 0.05));
      expect(r.gammaKPaPerC, closeTo(0.0674, 0.0001));
      expect(r.esKPa, closeTo(4.42, 0.005));
      expect(r.vapourPressureDeficitKPa, closeTo(1.57, 0.005));
      expect(r.raMJ, closeTo(38.06, 0.005));
      expect(r.daylightHours, closeTo(12.31, 0.005));
      expect(r.rsMJ, closeTo(22.65, 0.01));
      expect(r.rsoMJ, closeTo(28.54, 0.01));
      expect(r.rnsMJ, closeTo(17.44, 0.01));
      expect(r.rnlMJ, closeTo(3.11, 0.01));
      expect(r.rnMJ, closeTo(14.33, 0.01));
      expect(r.gMJ, closeTo(0.14, 1e-9));
      expect(r.radiationTermMmDay, closeTo(3.97, 0.01));
      expect(r.aerodynamicTermMmDay, closeTo(1.75, 0.01));
      expect(r.etoMmDay, closeTo(5.72, 0.01));
      expect(r.estimated, isEmpty);
    });

    test('Example 18: daily ETo at Uccle (Brussels) on 6 July', () {
      final r = fao56Eto(Fao56Input(
        latitudeDeg: 50 + 48 / 60,
        elevationM: 100,
        dayOfYear: dayOfYear(DateTime(2001, 7, 6)),
        tMaxC: 21.5,
        tMinC: 12.3,
        rhMaxPct: 84,
        rhMinPct: 63,
        windSpeedMs: 10 / 3.6,
        windHeightM: 10,
        sunshineHours: 9.25,
      ));
      expect(r.u2Ms, closeTo(2.078, 0.001));
      expect(r.pressureKPa, closeTo(100.1, 0.05));
      expect(r.deltaKPaPerC, closeTo(0.122, 0.0005));
      expect(r.gammaKPaPerC, closeTo(0.0666, 0.00005));
      expect(r.esKPa, closeTo(1.997, 0.001));
      expect(r.eaKPa, closeTo(1.409, 0.001));
      expect(r.raMJ, closeTo(41.09, 0.005));
      expect(r.daylightHours, closeTo(16.1, 0.05));
      expect(r.rsMJ, closeTo(22.07, 0.01));
      expect(r.rsoMJ, closeTo(30.90, 0.01));
      expect(r.rnsMJ, closeTo(17.00, 0.01));
      expect(r.rnlMJ, closeTo(3.71, 0.01));
      expect(r.rnMJ, closeTo(13.28, 0.01));
      expect(r.radiationTermMmDay, closeTo(2.81, 0.01));
      expect(r.aerodynamicTermMmDay, closeTo(1.07, 0.01));
      expect(r.etoMmDay, closeTo(3.88, 0.01));
    });

    test('Example 20: monthly ETo at Lyon in July from Tmax and Tmin only', () {
      final r = fao56Eto(const Fao56Input(latitudeDeg: 45 + 43 / 60, elevationM: 200, dayOfYear: 196, tMaxC: 26.6, tMinC: 14.8));
      expect(r.estimated, containsAll([Fao56Estimate.vapourPressureFromTmin, Fao56Estimate.radiationFromTemperature, Fao56Estimate.windDefault]));
      expect(r.deltaKPaPerC, closeTo(0.150, 0.0005));
      expect(r.eaKPa, closeTo(1.68, 0.005));
      expect(r.esKPa, closeTo(2.58, 0.005));
      expect(r.raMJ, closeTo(40.55, 0.01));
      expect(r.rsMJ, closeTo(22.29, 0.01));
      expect(r.rsoMJ, closeTo(30.58, 0.01));
      expect(r.rnsMJ, closeTo(17.16, 0.01));
      expect(r.rnlMJ, closeTo(3.68, 0.01));
      expect(r.rnMJ, closeTo(13.48, 0.01));
      expect(r.radiationTermMmDay, closeTo(3.17, 0.01));
      expect(r.aerodynamicTermMmDay, closeTo(1.39, 0.01));
      expect(r.etoMmDay, closeTo(4.56, 0.01));
      // the Hargreaves equation predicts 5.0 mm/day for the same month
      expect(etoHargreavesMmDay(latitudeDeg: 45 + 43 / 60, dayOfYear: 196, tMaxC: 26.6, tMinC: 14.8), closeTo(5.0, 0.05));
    });

    test('Example 20 sensitivity: 1 and 3 m/s instead of 2 m/s', () {
      double eto(double u) => fao56Eto(Fao56Input(latitudeDeg: 45 + 43 / 60, elevationM: 200, dayOfYear: 196, tMaxC: 26.6, tMinC: 14.8, windSpeedMs: u)).etoMmDay;
      expect(eto(1), closeTo(4.2, 0.05));
      expect(eto(3), closeTo(4.8, 0.05));
    });

    test('wind is limited to 0.5 m/s and radiation estimates to the clear-sky value', () {
      final calm = fao56Eto(const Fao56Input(latitudeDeg: 0, elevationM: 0, dayOfYear: 80, tMaxC: 30, tMinC: 20, windSpeedMs: 0.1));
      expect(calm.u2Ms, 0.5);
      expect(calm.estimated, contains(Fao56Estimate.windLimited));
      // a huge temperature range would give Rs above Rso
      final dry = fao56Eto(const Fao56Input(latitudeDeg: 25, elevationM: 0, dayOfYear: 170, tMaxC: 45, tMinC: 5, windSpeedMs: 2));
      expect(dry.rsMJ, closeTo(dry.rsoMJ, 1e-9));
      expect(dry.estimated, contains(Fao56Estimate.radiationLimitedToClearSky));
    });

    test('a monthly series takes the soil heat flux from both neighbours (eq. 43)', () {
      final months = [for (var m = 1; m <= 12; m++) MonthlyClimate(month: m, tMaxC: 25 + 5 * math.cos((m - 1) / 12 * 2 * math.pi), tMinC: 15 + 5 * math.cos((m - 1) / 12 * 2 * math.pi), windSpeed2mMs: 2)];
      final s = fao56MonthlySeries(months, latitudeDeg: 45, elevationM: 100);
      expect(s, hasLength(12));
      // warmest in January (southern-hemisphere-like): April cools (G < 0),
      // October warms (G > 0)
      expect(s[3]!.gMJ, closeTo(0.07 * (months[4].tMeanC - months[2].tMeanC), 1e-9));
      expect(s[3]!.gMJ, lessThan(0));
      expect(s[9]!.gMJ, greaterThan(0));
      // January wraps to December and February
      expect(s[0]!.gMJ, closeTo(0.07 * (months[1].tMeanC - months[11].tMeanC), 1e-9));
      // a missing month gives no result
      expect(fao56MonthlySeries(months.sublist(0, 6), latitudeDeg: 45, elevationM: 100)[8], isNull);
    });

    test('polar night and day do not break the radiation geometry', () {
      expect(extraterrestrialRadiationMJ(80, 355), 0);
      expect(daylightHours(80, 172), closeTo(24, 1e-9));
      expect(daylightHours(-80, 172), 0);
      expect(daysInMonth(2024, 2), 29);
      expect(daysInMonth(2023, 2), 28);
    });
  });
}
