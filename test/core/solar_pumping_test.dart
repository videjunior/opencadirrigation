import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/climate.dart';
import 'package:opencadirrigation/core/design/solar_pumping.dart';

/// PV pumping: the tilted-surface geometry against the closed forms of
/// Duffie & Beckman (eqs. 2.19.3–2.19.4), the Erbs monthly diffuse fraction,
/// FAO-56 extraterrestrial radiation, and the sizing energy balance worked
/// by hand.
void main() {
  /// Duffie & Beckman eq. 2.19.3 (north) / 2.19.4 (south) for surfaces
  /// facing the equator.
  double closedFormRb(double latDeg, double tiltDeg, int n) {
    final d = declinationDeg(n) * math.pi / 180, phi = latDeg * math.pi / 180;
    final pb = (latDeg >= 0 ? latDeg - tiltDeg : latDeg + tiltDeg) * math.pi / 180;
    final ws = math.acos(-math.tan(phi) * math.tan(d));
    final wsp = math.min(ws, math.acos((-math.tan(pb) * math.tan(d)).clamp(-1.0, 1.0)));
    final num = math.cos(pb) * math.cos(d) * math.sin(wsp) + wsp * math.sin(pb) * math.sin(d);
    final den = math.cos(phi) * math.cos(d) * math.sin(ws) + ws * math.sin(phi) * math.sin(d);
    return num / den;
  }

  group('geometry', () {
    test('the numerical Rb equals the closed form for equator-facing surfaces', () {
      expect(beamTiltRatio(40, 30, 0, 17), closeTo(closedFormRb(40, 30, 17), 1e-4));
      expect(beamTiltRatio(40, 30, 0, 17), closeTo(2.025, 0.001));
      expect(beamTiltRatio(40, 30, 0, 198), closeTo(0.912, 0.001));
      expect(beamTiltRatio(-23, 20, 0, 162), closeTo(1.411, 0.001));
      expect(beamTiltRatio(-23, 20, 0, 344), closeTo(0.864, 0.001));
      expect(beamTiltRatio(10, 0, 0, 100), closeTo(1, 1e-9));
    });

    test('east and west faces receive the same daily beam; a face turned from the equator gets less', () {
      expect(beamTiltRatio(-15, 25, 90, 100), closeTo(beamTiltRatio(-15, 25, -90, 100), 1e-6));
      // a surface facing away from the equator gets less than one facing it
      expect(beamTiltRatio(-15, 25, 180, 162), lessThan(beamTiltRatio(-15, 25, 0, 162)));
    });

    test('extraterrestrial radiation agrees with FAO-56 Example 8 (32.2 MJ/m² at 20°S on 3 September)', () {
      expect(extraterrestrialDailyKWhM2(-20, 246) * 3.6, closeTo(32.2, 0.3));
      expect(extraterrestrialDailyKWhM2(-20, 246) * 3.6, closeTo(extraterrestrialRadiationMJ(-20, 246), 0.3));
    });

    test('Erbs monthly diffuse fraction', () {
      expect(monthlyDiffuseFraction(0.5, 80), closeTo(0.391, 0.001));
      expect(monthlyDiffuseFraction(0.5, 85), closeTo(0.429, 0.001));
      expect(monthlyDiffuseFraction(0.95, 80), monthlyDiffuseFraction(0.8, 80));
    });

    test('tilted irradiation: horizontal kept, winter gains, summer loses for a steep tilt', () {
      expect(tiltedMonthlyIrradiationKWhM2(horizontalKWhM2Day: 5, latitudeDeg: -23, month: 6), 5);
      final june = tiltedMonthlyIrradiationKWhM2(horizontalKWhM2Day: 4.0, latitudeDeg: -23, month: 6, tiltDeg: 23);
      expect(june, greaterThan(4.0));
      final dec = tiltedMonthlyIrradiationKWhM2(horizontalKWhM2Day: 6.0, latitudeDeg: -23, month: 12, tiltDeg: 45);
      expect(dec, lessThan(6.0));
      expect(tiltedMonthlyIrradiationKWhM2(horizontalKWhM2Day: 0, latitudeDeg: -23, month: 6, tiltDeg: 23), 0);
      expect(meanDayOfMonth, hasLength(12));
    });
  });

  group('sizing', () {
    test('energy balance of a constant need at the equator (tilt 0)', () {
      final months = [for (var m = 1; m <= 12; m++) SolarPumpMonth(month: m, dailyVolumeM3: 100, horizontalKWhM2Day: 5)];
      final r = sizeSolarPumping(SolarPumpInput(months: months, latitudeDeg: 0, headM: 30, motorPumpEfficiency: 0.45, converterEfficiency: 0.95, performanceRatio: 0.8, modulePowerWp: 550, gridTariffPerKWh: 0.2));
      final eh = hydraulicEnergyKWh(100, 30);
      expect(eh, closeTo(998.2 * 9.80665 * 3000 / 3.6e6, 1e-9));
      expect(r.tiltDeg, 0);
      expect(r.requiredKWp, closeTo(eh / (5 * 0.8 * 0.95 * 0.45), 1e-9));
      expect(r.modules, (r.requiredKWp * 1000 / 550).ceil());
      expect(r.arrayKWp, closeTo(r.modules * 0.55, 1e-9));
      final jan = r.months.first;
      expect(jan.peakSunHours, 5);
      expect(jan.pumpedM3Day, closeTo(r.arrayKWp * 5 * 0.8 * 0.95 * 0.45 / hydraulicEnergyKWh(1, 30), 1e-9));
      expect(jan.pumpedM3Day, greaterThan(100));
      expect(r.annualDemandM3, closeTo(36500, 1e-6));
      expect(r.annualPumpedM3, closeTo(36500, 1e-6));
      expect(r.annualGridKWh, closeTo(eh / 0.45 * 365, 1e-6));
      expect(r.annualGridCost, closeTo(r.annualGridKWh * 0.2, 1e-9));
    });

    test('the darkest month with the largest need sets the array', () {
      final months = [
        for (var m = 1; m <= 12; m++) SolarPumpMonth(month: m, dailyVolumeM3: m == 7 ? 120 : 80, horizontalKWhM2Day: m == 6 ? 3.5 : 5.5),
      ];
      final r = sizeSolarPumping(SolarPumpInput(months: months, latitudeDeg: 0, headM: 40, performanceRatio: 0.8));
      // July: 120/5.5 > June: 80/3.5? 21.8 < 22.9: June governs
      expect(r.criticalMonth, 6);
      expect(r.months.firstWhere((m) => m.month == 6).pumpedM3Day, greaterThanOrEqualTo(80 - 1e-9));
      expect(r.warnings, isEmpty);
    });

    test('a month with a need but no sun is left out of the sizing and reported', () {
      final months = [for (var m = 1; m <= 12; m++) SolarPumpMonth(month: m, dailyVolumeM3: 50, horizontalKWhM2Day: m == 6 ? 0 : 5)];
      final r = sizeSolarPumping(SolarPumpInput(months: months, latitudeDeg: 0, headM: 20, performanceRatio: 0.8));
      expect(r.warnings, ['solar_no_irradiation:6']);
      expect(r.modules, greaterThan(0));
      expect(r.months[5].pumpedM3Day, 0);
      expect(r.annualPumpedM3, closeTo(50 * (365 - 30), 1e-6));
    });

    test('an efficiency curve evaluated at the mean flow over the sun hours', () {
      double eta(double q, double h) => 0.5 - 0.001 * (q - 20).abs();
      final months = [for (var m = 1; m <= 12; m++) SolarPumpMonth(month: m, dailyVolumeM3: 100, horizontalKWhM2Day: 5)];
      final r = sizeSolarPumping(SolarPumpInput(months: months, latitudeDeg: 0, headM: 30, motorPumpEfficiencyAt: eta, converterEfficiency: 0.95, performanceRatio: 0.8, nominalFlowM3h: 20));
      // 100 m³ over 5 sun hours = 20 m³/h, the best point (η 0.5)
      expect(r.requiredKWp, closeTo(hydraulicEnergyKWh(100, 30) / (5 * 0.8 * 0.95 * 0.5), 1e-9));
      final m = r.months.first;
      expect(m.motorPumpEfficiency, lessThanOrEqualTo(0.5));
      expect(m.pumpingHours, closeTo(100 / 20, 1e-9));
    });

    test('performance ratio from losses and temperature', () {
      expect(pvTemperatureFactor(ambientC: 30), closeTo(0.88, 1e-9)); // Tc = 55 °C
      expect(pvPerformanceRatio(), closeTo(0.97 * 0.98 * 0.98, 1e-12));
      final cool = sizeSolarPumping(SolarPumpInput(months: const [SolarPumpMonth(month: 1, dailyVolumeM3: 50, horizontalKWhM2Day: 5, ambientC: 15)], latitudeDeg: 0, headM: 20));
      final hot = sizeSolarPumping(SolarPumpInput(months: const [SolarPumpMonth(month: 1, dailyVolumeM3: 50, horizontalKWhM2Day: 5, ambientC: 35)], latitudeDeg: 0, headM: 20));
      expect(hot.requiredKWp, greaterThan(cool.requiredKWp));
      expect(mjToKWhPerM2(18), closeTo(5, 1e-12));
    });
  });
}
