/// Photovoltaic (PV) pumping sizing from the daily water volume of every
/// month, with a comparison against grid energy.
///
/// - Terms follow IEC 62253:2011 (Photovoltaic pumping systems — Design
///   qualification and performance measurements): PV generator (array),
///   power conditioner (controller/inverter), motor-pump set, total dynamic
///   head and daily water volume; the daily hydraulic energy is
///   Eh = ρ·g·H·V.
/// - Array energy: E = P·HT·PR/Gstc with the reference yield HT/Gstc (peak
///   sun hours, Gstc = 1 kW/m²) and the performance ratio PR of IEC 61724-1
///   (temperature, soiling, wiring, mismatch losses); the cell temperature
///   from the NOCT method, Tc = Ta + (NOCT − 20)·G/800 (Duffie & Beckman,
///   Solar Engineering of Thermal Processes, section 23.3).
/// - Irradiation on the tilted array from the monthly mean on the horizontal
///   with the isotropic sky model of Liu & Jordan (Duffie & Beckman eq.
///   2.19.1): HT = H·[(1 − Hd/H)·Rb + (Hd/H)·(1 + cos β)/2 + ρg·(1 − cos β)/2],
///   the monthly diffuse fraction of Erbs, Klein & Duffie (1982) (Duffie &
///   Beckman eq. 2.12.1), and Rb the ratio of the daily extraterrestrial
///   radiation on the tilted surface to that on the horizontal on the mean
///   day of the month (Duffie & Beckman Table 1.6.1, eqs. 1.6.1a, 1.6.2,
///   1.6.5, 1.10.3), integrated numerically over the day so that any
///   orientation works (equal to the closed form of eqs. 2.19.3–2.19.4 for
///   equator-facing surfaces).
/// - Irradiation from climate_online.dart (Open-Meteo shortwave_radiation_sum
///   or NASA POWER ALLSKY_SFC_SW_DWN): MJ/m²/day ÷ 3.6 = kWh/m²/day.
library;

import 'dart:math' as math;

import '../units.dart';

/// Irradiance at standard test conditions (kW/m²).
const double stcIrradianceKWm2 = 1.0;

const double _gscWm2 = 1367;
const double _deg = math.pi / 180;

/// Day of the year of the mean day of each month (Duffie & Beckman Table
/// 1.6.1, after Klein 1977).
const meanDayOfMonth = [17, 47, 75, 105, 135, 162, 198, 228, 258, 288, 318, 344];

/// Solar declination (degrees), Cooper (1969), Duffie & Beckman eq. 1.6.1a.
double declinationDeg(int dayOfYear) => 23.45 * math.sin(2 * math.pi * (284 + dayOfYear) / 365);

/// Daily extraterrestrial irradiation on the horizontal (kWh/m²/day),
/// Duffie & Beckman eq. 1.10.3.
double extraterrestrialDailyKWhM2(double latitudeDeg, int dayOfYear) {
  final phi = latitudeDeg * _deg, d = declinationDeg(dayOfYear) * _deg;
  final ws = math.acos((-math.tan(phi) * math.tan(d)).clamp(-1.0, 1.0));
  final h = 24 * 3600 * _gscWm2 / math.pi * (1 + 0.033 * math.cos(2 * math.pi * dayOfYear / 365)) * (math.cos(phi) * math.cos(d) * math.sin(ws) + ws * math.sin(phi) * math.sin(d));
  return math.max(h, 0.0) / 3.6e6;
}

/// Monthly mean diffuse fraction Hd/H from the clearness index KT
/// (Erbs, Klein & Duffie 1982; Duffie & Beckman eq. 2.12.1), KT limited to
/// the 0.3–0.8 range of the correlation.
double monthlyDiffuseFraction(double clearnessIndex, double sunsetHourAngleDeg) {
  final k = clearnessIndex.clamp(0.3, 0.8);
  if (sunsetHourAngleDeg <= 81.4) return 1.391 - 3.560 * k + 4.189 * k * k - 2.137 * k * k * k;
  return 1.311 - 3.022 * k + 3.427 * k * k - 1.821 * k * k * k;
}

/// Ratio Rb of the daily extraterrestrial radiation on a surface of slope
/// [tiltDeg] and azimuth [azimuthFromEquatorDeg] (0 = facing the equator,
/// positive towards the west) to that on the horizontal, for a day of the
/// year: the integral of cos θ (Duffie & Beckman eq. 1.6.2, zero while the
/// sun is behind the surface) over the integral of cos θz (eq. 1.6.5) from
/// sunrise to sunset.
double beamTiltRatio(double latitudeDeg, double tiltDeg, double azimuthFromEquatorDeg, int dayOfYear, {int steps = 720}) {
  final phi = latitudeDeg * _deg, beta = tiltDeg * _deg, delta = declinationDeg(dayOfYear) * _deg;
  // surface azimuth in the Duffie & Beckman convention (0 = south, west positive)
  final gamma = (latitudeDeg >= 0 ? azimuthFromEquatorDeg : 180 - azimuthFromEquatorDeg) * _deg;
  final ws = math.acos((-math.tan(phi) * math.tan(delta)).clamp(-1.0, 1.0));
  if (ws <= 0) return 0;
  final sd = math.sin(delta), cd = math.cos(delta), sp = math.sin(phi), cp = math.cos(phi), sb = math.sin(beta), cb = math.cos(beta), sg = math.sin(gamma), cg = math.cos(gamma);
  var num = 0.0, den = 0.0;
  final h = 2 * ws / steps;
  for (var i = 0; i <= steps; i++) {
    final w = -ws + i * h;
    final wt = i == 0 || i == steps ? 0.5 : 1.0;
    final cw = math.cos(w), sw = math.sin(w);
    final cosTheta = sd * sp * cb - sd * cp * sb * cg + cd * cp * cb * cw + cd * sp * sb * cg * cw + cd * sb * sg * sw;
    final cosZ = cp * cd * cw + sp * sd;
    num += wt * math.max(cosTheta, 0.0);
    den += wt * math.max(cosZ, 0.0);
  }
  return den > 0 ? num / den : 0;
}

/// Monthly mean daily irradiation on a tilted surface (kWh/m²/day) from the
/// monthly mean on the horizontal [horizontalKWhM2Day] (isotropic sky, Liu &
/// Jordan; Duffie & Beckman eq. 2.19.1), for [month] (1–12).
double tiltedMonthlyIrradiationKWhM2({required double horizontalKWhM2Day, required double latitudeDeg, required int month, double tiltDeg = 0, double azimuthFromEquatorDeg = 0, double groundAlbedo = 0.2}) {
  if (horizontalKWhM2Day <= 0) return 0;
  if (tiltDeg == 0) return horizontalKWhM2Day;
  final n = meanDayOfMonth[(month - 1).clamp(0, 11)];
  final h0 = extraterrestrialDailyKWhM2(latitudeDeg, n);
  final phi = latitudeDeg * _deg, d = declinationDeg(n) * _deg;
  final wsDeg = math.acos((-math.tan(phi) * math.tan(d)).clamp(-1.0, 1.0)) / _deg;
  final kt = h0 > 0 ? horizontalKWhM2Day / h0 : 0.5;
  final fd = monthlyDiffuseFraction(kt, wsDeg).clamp(0.0, 1.0);
  final rb = beamTiltRatio(latitudeDeg, tiltDeg, azimuthFromEquatorDeg, n);
  final b = tiltDeg * _deg;
  return horizontalKWhM2Day * ((1 - fd) * rb + fd * (1 + math.cos(b)) / 2 + groundAlbedo * (1 - math.cos(b)) / 2);
}

/// Temperature factor of the array power: 1 + γ·(Tc − 25) with the cell
/// temperature Tc = Ta + (NOCT − 20)·G/800 (NOCT method); γ ≈ −0.004/°C for
/// crystalline silicon.
double pvTemperatureFactor({required double ambientC, double noctC = 45, double irradianceWm2 = 800, double powerTempCoeffPerC = -0.004}) {
  final tc = ambientC + (noctC - 20) * irradianceWm2 / 800;
  return math.max(1 + powerTempCoeffPerC * (tc - 25), 0.0);
}

/// Performance ratio of the array (IEC 61724-1 sense) from its losses:
/// soiling, DC wiring, mismatch and others as fractions, times the
/// temperature factor.
double pvPerformanceRatio({double temperatureFactor = 1, double soiling = 0.03, double wiring = 0.02, double mismatch = 0.02, double other = 0}) =>
    math.max(temperatureFactor * (1 - soiling) * (1 - wiring) * (1 - mismatch) * (1 - other), 0.0);

/// Daily hydraulic energy (kWh/day) to lift [volumeM3] against [headM].
double hydraulicEnergyKWh(double volumeM3, double headM) => waterDensity * gravity * math.max(volumeM3, 0.0) * math.max(headM, 0.0) / 3.6e6;

/// One month of the pumping need.
class SolarPumpMonth {
  const SolarPumpMonth({required this.month, required this.dailyVolumeM3, required this.horizontalKWhM2Day, this.ambientC, this.headM});

  /// 1–12.
  final int month;
  final double dailyVolumeM3;

  /// Monthly mean daily irradiation on the horizontal (kWh/m²/day).
  final double horizontalKWhM2Day;

  /// Mean daytime air temperature (°C) for the temperature losses.
  final double? ambientC;

  /// Total dynamic head of the month (m); null uses the system head.
  final double? headM;
}

/// Inputs of a PV pumping sizing.
class SolarPumpInput {
  const SolarPumpInput({
    required this.months,
    required this.latitudeDeg,
    required this.headM,
    this.tiltDeg,
    this.azimuthFromEquatorDeg = 0,
    this.groundAlbedo = 0.2,
    this.motorPumpEfficiency = 0.45,
    this.motorPumpEfficiencyAt,
    this.converterEfficiency = 0.95,
    this.performanceRatio,
    this.soiling = 0.03,
    this.wiring = 0.02,
    this.mismatch = 0.02,
    this.noctC = 45,
    this.powerTempCoeffPerC = -0.004,
    this.modulePowerWp = 550,
    this.oversize = 1.0,
    this.nominalFlowM3h,
    this.gridMotorPumpEfficiency,
    this.gridTariffPerKWh = 0,
    this.year = 2001,
  });

  final List<SolarPumpMonth> months;
  final double latitudeDeg;

  /// Total dynamic head (m) of the months without their own.
  final double headM;

  /// Array slope (degrees); null takes |latitude| (a common choice for a
  /// year-round load; set it lower for a summer peak).
  final double? tiltDeg;
  final double azimuthFromEquatorDeg;
  final double groundAlbedo;

  /// Motor-pump set efficiency (wire to water): constant, or as a function
  /// of the mean flow (m³/h) and head (m) when [motorPumpEfficiencyAt] is
  /// given (the mean flow is the daily volume over the peak sun hours).
  final double motorPumpEfficiency;
  final double Function(double flowM3h, double headM)? motorPumpEfficiencyAt;

  /// Power conditioner (controller/inverter) efficiency.
  final double converterEfficiency;

  /// Fixed performance ratio; null computes it from the losses and the
  /// monthly temperature.
  final double? performanceRatio;
  final double soiling;
  final double wiring;
  final double mismatch;
  final double noctC;
  final double powerTempCoeffPerC;

  /// Module rating (Wp at STC) and the margin on the required power.
  final double modulePowerWp;
  final double oversize;

  /// Flow of the pump at its design point (m³/h), for the hours of pumping.
  final double? nominalFlowM3h;

  /// Motor-pump efficiency on the grid (null: the same set); tariff per kWh.
  final double? gridMotorPumpEfficiency;
  final double gridTariffPerKWh;

  /// Year whose month lengths count the annual totals.
  final int year;
}

/// One month of the sizing result.
class SolarPumpMonthResult {
  const SolarPumpMonthResult({required this.month, required this.days, required this.tiltedKWhM2Day, required this.peakSunHours, required this.performanceRatio, required this.motorPumpEfficiency, required this.hydraulicKWhDay, required this.requiredKWp, required this.pumpedM3Day, required this.demandM3Day, required this.pumpingHours});
  final int month;
  final int days;

  /// Irradiation on the array (kWh/m²/day) = peak sun hours (h/day).
  final double tiltedKWhM2Day;
  final double peakSunHours;
  final double performanceRatio;
  final double motorPumpEfficiency;

  /// Hydraulic energy of the demand (kWh/day) and the array power it needs.
  final double hydraulicKWhDay;
  final double requiredKWp;

  /// Volume the chosen array lifts per day (m³), against the demand.
  final double pumpedM3Day;
  final double demandM3Day;

  /// Hours per day at the nominal flow for the pumped volume (the peak sun
  /// hours when no nominal flow is given).
  final double pumpingHours;
}

/// PV pumping sizing result.
class SolarPumpResult {
  const SolarPumpResult({required this.months, required this.tiltDeg, required this.criticalMonth, required this.requiredKWp, required this.modules, required this.arrayKWp, required this.annualDemandM3, required this.annualPumpedM3, required this.annualHydraulicKWh, required this.annualGridKWh, required this.annualGridCost, this.warnings = const []});
  final List<SolarPumpMonthResult> months;
  final double tiltDeg;

  /// Month (1–12) that sets the array: the largest required power.
  final int? criticalMonth;
  final double requiredKWp;
  final int modules;
  final double arrayKWp;

  /// Year totals of the demand and of the water the array lifts (capped at
  /// the demand).
  final double annualDemandM3;
  final double annualPumpedM3;
  final double annualHydraulicKWh;

  /// Energy and cost of the same demand pumped from the grid.
  final double annualGridKWh;
  final double annualGridCost;

  /// Message codes: `solar_no_irradiation:<month>` (a need without sun, left
  /// out of the sizing), `solar_deficit:<month>` (the array lifts less than
  /// the need).
  final List<String> warnings;
}

/// Sizes the PV array for the critical month and gives the volume it lifts
/// in every month.
SolarPumpResult sizeSolarPumping(SolarPumpInput input) {
  final tilt = input.tiltDeg ?? input.latitudeDeg.abs();
  final conv = input.converterEfficiency.clamp(0.05, 1.0);
  final pre = <(SolarPumpMonth, double ht, double pr, int days, double head)>[];
  for (final m in input.months) {
    final ht = tiltedMonthlyIrradiationKWhM2(horizontalKWhM2Day: m.horizontalKWhM2Day, latitudeDeg: input.latitudeDeg, month: m.month, tiltDeg: tilt, azimuthFromEquatorDeg: input.azimuthFromEquatorDeg, groundAlbedo: input.groundAlbedo);
    final tf = m.ambientC == null ? 1.0 : pvTemperatureFactor(ambientC: m.ambientC!, noctC: input.noctC, powerTempCoeffPerC: input.powerTempCoeffPerC);
    final pr = input.performanceRatio ?? pvPerformanceRatio(temperatureFactor: tf, soiling: input.soiling, wiring: input.wiring, mismatch: input.mismatch);
    final days = DateTime.utc(input.year, m.month + 1).difference(DateTime.utc(input.year, m.month)).inDays;
    pre.add((m, ht, pr, days, m.headM ?? input.headM));
  }
  double eta(double volumeM3Day, double psh, double head) {
    final f = input.motorPumpEfficiencyAt;
    if (f == null || psh <= 0) return input.motorPumpEfficiency.clamp(0.01, 1.0);
    return f(volumeM3Day / psh, head).clamp(0.01, 1.0);
  }

  // required power per month and the critical month (months with a need
  // but no sun cannot be served by any array and are left out of it)
  var required = 0.0;
  int? critical;
  final reqByMonth = <double>[];
  final warnings = <String>[];
  for (final (m, ht, pr, _, head) in pre) {
    final eh = hydraulicEnergyKWh(m.dailyVolumeM3, head);
    final psh = ht / stcIrradianceKWm2;
    final e = eta(m.dailyVolumeM3, psh, head);
    final kwp = eh > 0 && psh > 0 && pr > 0 ? eh / (psh * pr * conv * e) : (eh > 0 ? double.infinity : 0.0);
    reqByMonth.add(kwp);
    if (!kwp.isFinite) {
      warnings.add('solar_no_irradiation:${m.month}');
      continue;
    }
    if (kwp > required) {
      required = kwp;
      critical = m.month;
    }
  }
  final need = required * math.max(input.oversize, 1.0);
  final modules = need.isFinite && input.modulePowerWp > 0 ? (need * 1000 / input.modulePowerWp - 1e-9).ceil() : 0;
  final array = modules * input.modulePowerWp / 1000;
  final results = <SolarPumpMonthResult>[];
  var demandYear = 0.0, pumpedYear = 0.0, hydraulicYear = 0.0, gridYear = 0.0;
  for (var i = 0; i < pre.length; i++) {
    final (m, ht, pr, days, head) = pre[i];
    final psh = ht / stcIrradianceKWm2;
    final eh = hydraulicEnergyKWh(m.dailyVolumeM3, head);
    // volume the array lifts: fixed point on the efficiency at the mean flow
    var v = m.dailyVolumeM3;
    var e = eta(v, psh, head);
    final unit = hydraulicEnergyKWh(1, head);
    for (var k = 0; k < 20; k++) {
      final next = unit > 0 ? array * psh * pr * conv * e / unit : 0.0;
      final eNext = eta(next, psh, head);
      v = next;
      if ((eNext - e).abs() < 1e-6) break;
      e = eNext;
    }
    final q = input.nominalFlowM3h;
    final served = math.min(v, m.dailyVolumeM3);
    if (served < m.dailyVolumeM3 * (1 - 1e-6) && reqByMonth[i].isFinite) warnings.add('solar_deficit:${m.month}');
    results.add(SolarPumpMonthResult(
      month: m.month,
      days: days,
      tiltedKWhM2Day: ht,
      peakSunHours: psh,
      performanceRatio: pr,
      motorPumpEfficiency: e,
      hydraulicKWhDay: eh,
      requiredKWp: reqByMonth[i],
      pumpedM3Day: v,
      demandM3Day: m.dailyVolumeM3,
      pumpingHours: q != null && q > 0 ? served / q : psh,
    ));
    demandYear += m.dailyVolumeM3 * days;
    pumpedYear += served * days;
    hydraulicYear += eh * days;
    final eg = (input.gridMotorPumpEfficiency ?? eta(m.dailyVolumeM3, psh, head)).clamp(0.01, 1.0);
    gridYear += eh / eg * days;
  }
  return SolarPumpResult(
    months: results,
    tiltDeg: tilt,
    criticalMonth: critical,
    requiredKWp: required,
    modules: modules,
    arrayKWp: array,
    annualDemandM3: demandYear,
    annualPumpedM3: pumpedYear,
    annualHydraulicKWh: hydraulicYear,
    annualGridKWh: gridYear,
    annualGridCost: gridYear * input.gridTariffPerKWh,
    warnings: warnings,
  );
}

/// Irradiation in MJ/m²/day (Open-Meteo, NASA POWER with community=AG) to
/// kWh/m²/day.
double mjToKWhPerM2(double mjPerM2) => mjPerM2 / 3.6;
