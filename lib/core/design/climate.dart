/// Reference evapotranspiration ETo with the FAO Penman-Monteith method,
/// daily and monthly, with the FAO missing-data procedures, and the
/// Hargreaves-Samani alternative. Every equation number below refers to
/// Allen, R. G.; Pereira, L. S.; Raes, D.; Smith, M. (1998). Crop
/// evapotranspiration — Guidelines for computing crop water requirements.
/// FAO Irrigation and Drainage Paper 56, Rome (chapters 2–4):
///
/// - eq. 6 FAO Penman-Monteith; eq. 7 pressure; eq. 8 psychrometric
///   constant; eqs. 11–19 vapour pressures; eq. 20 radiation as evaporation;
///   eqs. 21–27 extraterrestrial radiation; eq. 34 daylight hours; eq. 35
///   Angström; eqs. 36–37 clear-sky radiation; eqs. 38–40 net radiation;
///   eqs. 42–44 soil heat flux; eq. 47 wind at 2 m;
/// - missing data: eq. 48 (dew point ≈ Tmin), eq. 50 (Hargreaves' radiation
///   from the temperature range, kRs 0.16 interior / 0.19 coastal), eq. 51
///   (islands), 2 m/s when wind is missing and u2 ≥ 0.5 m/s in eq. 6;
/// - eq. 52 Hargreaves-Samani ETo; eqs. 63–64 RHmin for the Kc adjustments.
///
/// Units follow FAO-56: °C, kPa, m/s, MJ m⁻² day⁻¹ and mm/day; latitudes in
/// decimal degrees (south negative).
library;

import 'dart:math' as math;

/// Solar constant Gsc (MJ m⁻² min⁻¹), FAO-56 eq. 21.
const double solarConstantMJPerM2Min = 0.0820;

/// Stefan-Boltzmann constant σ (MJ K⁻⁴ m⁻² day⁻¹), FAO-56 eq. 39.
const double stefanBoltzmannMJPerM2Day = 4.903e-9;

/// Latent heat of vaporisation λ (MJ/kg) used by FAO-56 (eq. 8, Annex 3).
const double latentHeatMJPerKg = 2.45;

/// Radiation in MJ m⁻² day⁻¹ to the equivalent evaporation in mm/day (1/λ,
/// FAO-56 eq. 20).
const double mmPerMJPerM2 = 0.408;

/// MJ/m² in one kWh/m².
const double mjPerKWh = 3.6;

/// Kelvin offset used by FAO-56 (K = °C + 273.16, eq. 39).
const double _kelvin = 273.16;

/// Atmospheric pressure P (kPa) at an elevation (m), FAO-56 eq. 7.
double atmosphericPressureKPa(double elevationM) => 101.3 * math.pow((293 - 0.0065 * elevationM) / 293, 5.26).toDouble();

/// Psychrometric constant γ (kPa/°C) for an atmospheric pressure (kPa),
/// FAO-56 eq. 8.
double psychrometricConstantKPaPerC(double pressureKPa) => 0.665e-3 * pressureKPa;

/// Saturation vapour pressure e°(T) (kPa), FAO-56 eq. 11.
double saturationVapourPressureKPa(double tempC) => 0.6108 * math.exp(17.27 * tempC / (tempC + 237.3));

/// Mean saturation vapour pressure es (kPa) of a day or period from the mean
/// daily maximum and minimum temperatures, FAO-56 eq. 12.
double meanSaturationVapourPressureKPa(double tMaxC, double tMinC) => (saturationVapourPressureKPa(tMaxC) + saturationVapourPressureKPa(tMinC)) / 2;

/// Slope Δ (kPa/°C) of the saturation vapour pressure curve, FAO-56 eq. 13.
double vapourPressureSlopeKPaPerC(double tempC) {
  final d = tempC + 237.3;
  return 4098 * saturationVapourPressureKPa(tempC) / (d * d);
}

/// Actual vapour pressure ea (kPa) from the dew point, FAO-56 eq. 14 (and
/// eq. 48 when the minimum temperature stands in for the dew point).
double actualVapourPressureFromDewPointKPa(double dewPointC) => saturationVapourPressureKPa(dewPointC);

/// Actual vapour pressure ea (kPa) from a psychrometer: wet bulb depression
/// and the instrument coefficient apsy (0.000662 ventilated, 0.000800
/// naturally ventilated, 0.001200 indoor), FAO-56 eqs. 15–16.
double actualVapourPressurePsychrometricKPa(double dryBulbC, double wetBulbC, double pressureKPa, {double aPsy = 0.000662}) =>
    saturationVapourPressureKPa(wetBulbC) - aPsy * pressureKPa * (dryBulbC - wetBulbC);

/// Actual vapour pressure ea (kPa) from RHmax and RHmin (%), FAO-56 eq. 17.
double actualVapourPressureFromRhKPa(double tMaxC, double tMinC, double rhMaxPct, double rhMinPct) =>
    (saturationVapourPressureKPa(tMinC) * rhMaxPct / 100 + saturationVapourPressureKPa(tMaxC) * rhMinPct / 100) / 2;

/// Actual vapour pressure ea (kPa) from RHmax only, FAO-56 eq. 18.
double actualVapourPressureFromRhMaxKPa(double tMinC, double rhMaxPct) => saturationVapourPressureKPa(tMinC) * rhMaxPct / 100;

/// Actual vapour pressure ea (kPa) from RHmean (%), FAO-56 eq. 19 (the
/// least desirable of the humidity equations).
double actualVapourPressureFromRhMeanKPa(double tMaxC, double tMinC, double rhMeanPct) => rhMeanPct / 100 * meanSaturationVapourPressureKPa(tMaxC, tMinC);

/// Wind speed at 2 m (m/s) from a measurement at [heightM] above a short
/// grass surface (logarithmic profile), FAO-56 eq. 47.
double windSpeedAt2m(double windSpeedMs, double heightM) => heightM == 2 ? windSpeedMs : windSpeedMs * 4.87 / math.log(67.8 * heightM - 5.42);

/// Day of the year J (1 = 1 January), as tabulated in FAO-56 Annex 2,
/// Table 2.5.
int dayOfYear(DateTime date) => DateTime.utc(date.year, date.month, date.day).difference(DateTime.utc(date.year)).inDays + 1;

/// Day of the year of the 15th of [month] (1–12) in a common year, the day
/// FAO-56 uses for monthly computations (Table 2.5; Examples 17 and 20).
int midMonthDayOfYear(int month) => const [15, 46, 74, 105, 135, 166, 196, 227, 258, 288, 319, 349][(month - 1).clamp(0, 11)];

/// Inverse relative distance Earth–Sun dr, FAO-56 eq. 23.
double inverseRelativeDistance(int dayOfYear) => 1 + 0.033 * math.cos(2 * math.pi * dayOfYear / 365);

/// Solar declination δ (rad), FAO-56 eq. 24.
double solarDeclinationRad(int dayOfYear) => 0.409 * math.sin(2 * math.pi * dayOfYear / 365 - 1.39);

/// Sunset hour angle ωs (rad), FAO-56 eq. 25; the argument is clamped so
/// that polar day and night give π and 0 (the purpose of eqs. 26–27).
double sunsetHourAngleRad(double latitudeRad, double declinationRad) => math.acos((-math.tan(latitudeRad) * math.tan(declinationRad)).clamp(-1.0, 1.0));

/// Extraterrestrial radiation Ra (MJ m⁻² day⁻¹) for a latitude (degrees,
/// south negative) and a day of the year, FAO-56 eq. 21.
double extraterrestrialRadiationMJ(double latitudeDeg, int dayOfYear) {
  final phi = latitudeDeg * math.pi / 180; // eq. 22
  final dr = inverseRelativeDistance(dayOfYear);
  final delta = solarDeclinationRad(dayOfYear);
  final ws = sunsetHourAngleRad(phi, delta);
  final ra = 24 * 60 / math.pi * solarConstantMJPerM2Min * dr * (ws * math.sin(phi) * math.sin(delta) + math.cos(phi) * math.cos(delta) * math.sin(ws));
  return math.max(ra, 0.0);
}

/// Daylight hours N, FAO-56 eq. 34.
double daylightHours(double latitudeDeg, int dayOfYear) => 24 / math.pi * sunsetHourAngleRad(latitudeDeg * math.pi / 180, solarDeclinationRad(dayOfYear));

/// Solar radiation Rs (MJ m⁻² day⁻¹) from the hours of bright sunshine n
/// (Angström formula, FAO-56 eq. 35; as = 0.25 and bs = 0.50 when not
/// calibrated).
double solarRadiationFromSunshineMJ(double raMJ, double sunshineHours, double daylightHours, {double angstromA = 0.25, double angstromB = 0.50}) =>
    (angstromA + angstromB * (daylightHours > 0 ? (sunshineHours / daylightHours).clamp(0.0, 1.0) : 0)) * raMJ;

/// Solar radiation Rs (MJ m⁻² day⁻¹) from the temperature range (Hargreaves'
/// radiation formula, FAO-56 eq. 50): kRs ≈ 0.16 for interior and 0.19 for
/// coastal locations. FAO-56 limits the result to Rso, which
/// [fao56Eto] does; the method suits monthly or several-day means.
double solarRadiationFromTemperatureMJ(double raMJ, double tMaxC, double tMinC, {double kRs = 0.16}) => kRs * math.sqrt(math.max(tMaxC - tMinC, 0.0)) * raMJ;

/// Solar radiation Rs (MJ m⁻² day⁻¹) for islands narrower than about 20 km
/// and below 100 m: Rs = 0.7·Ra − b with b = 4 MJ m⁻² day⁻¹ (FAO-56 eq. 51,
/// monthly use only).
double solarRadiationIslandMJ(double raMJ, {double b = 4}) => math.max(0.7 * raMJ - b, 0.0);

/// Clear-sky solar radiation Rso (MJ m⁻² day⁻¹): (as + bs)·Ra when
/// calibrated Angström coefficients are given (FAO-56 eq. 36), otherwise
/// (0.75 + 2·10⁻⁵·z)·Ra (eq. 37).
double clearSkyRadiationMJ(double raMJ, double elevationM, {double? angstromSum}) => angstromSum != null ? angstromSum * raMJ : (0.75 + 2e-5 * elevationM) * raMJ;

/// Net shortwave radiation Rns (MJ m⁻² day⁻¹), FAO-56 eq. 38 (albedo 0.23
/// for the grass reference).
double netShortwaveRadiationMJ(double rsMJ, {double albedo = 0.23}) => (1 - albedo) * rsMJ;

/// Net outgoing longwave radiation Rnl (MJ m⁻² day⁻¹), FAO-56 eq. 39, with
/// Rs/Rso limited to 1.
double netLongwaveRadiationMJ(double tMaxC, double tMinC, double eaKPa, double rsMJ, double rsoMJ) {
  final tx = tMaxC + _kelvin, tn = tMinC + _kelvin;
  final sigmaT4 = stefanBoltzmannMJPerM2Day * (tx * tx * tx * tx + tn * tn * tn * tn) / 2;
  final ratio = rsoMJ > 0 ? (rsMJ / rsoMJ).clamp(0.0, 1.0) : 0.0;
  return sigmaT4 * (0.34 - 0.14 * math.sqrt(math.max(eaKPa, 0.0))) * (1.35 * ratio - 0.35);
}

/// Soil heat flux of a month G (MJ m⁻² day⁻¹) from the mean temperatures of
/// the previous and next months, FAO-56 eq. 43; with only the previous
/// month known, eq. 44 (0.14·(Ti − Ti−1)); zero without neighbours (daily
/// steps, eq. 42).
double monthlySoilHeatFluxMJ({required double tMeanC, double? tPrevMonthC, double? tNextMonthC}) {
  if (tPrevMonthC != null && tNextMonthC != null) return 0.07 * (tNextMonthC - tPrevMonthC);
  if (tPrevMonthC != null) return 0.14 * (tMeanC - tPrevMonthC);
  return 0;
}

/// Minimum relative humidity (%) from the dew point (FAO-56 eq. 63) or, when
/// it is unknown, from Tmin (eq. 64; FAO-56 recommends Tmin − 2 °C in arid
/// and semi-arid climates, [aridTminOffsetC]). Used by the Kc mid and Kc end
/// climatic adjustments.
double minRelativeHumidityPct({required double tMaxC, double? tDewC, double? tMinC, double aridTminOffsetC = 0}) {
  final dew = tDewC ?? (tMinC == null ? null : tMinC - aridTminOffsetC);
  if (dew == null) return 45; // the RHmin of the Kc tables (FAO-56 Table 12)
  return (100 * saturationVapourPressureKPa(dew) / saturationVapourPressureKPa(tMaxC)).clamp(0.0, 100.0);
}

/// Grass reference ETo (mm/day) with the Hargreaves-Samani equation,
/// FAO-56 eq. 52 (Ra converted to mm/day by eq. 20).
double etoHargreavesMmDay({required double latitudeDeg, required int dayOfYear, required double tMaxC, required double tMinC}) {
  final ra = extraterrestrialRadiationMJ(latitudeDeg, dayOfYear) * mmPerMJPerM2;
  return math.max(0.0023 * ((tMaxC + tMinC) / 2 + 17.8) * math.sqrt(math.max(tMaxC - tMinC, 0.0)) * ra, 0.0);
}

/// Data estimated or limited by [fao56Eto] (FAO-56 chapter 3, "Estimating
/// missing climatic data").
enum Fao56Estimate {
  /// Actual vapour pressure from Tmin as dew point (eq. 48).
  vapourPressureFromTmin,

  /// Solar radiation from the temperature range (eq. 50).
  radiationFromTemperature,

  /// Solar radiation by the island formula (eq. 51).
  radiationIsland,

  /// Solar radiation above the clear-sky value, limited to Rso.
  radiationLimitedToClearSky,

  /// Wind speed missing: 2 m/s (FAO-56 Table 4 note).
  windDefault,

  /// Wind speed below 0.5 m/s raised to 0.5 m/s.
  windLimited,
}

/// Inputs of a FAO Penman-Monteith calculation for one day, or for the mean
/// day of a ten-day period or month (then give the period means and, for
/// months, the soil heat flux from [monthlySoilHeatFluxMJ]).
class Fao56Input {
  const Fao56Input({
    required this.latitudeDeg,
    required this.elevationM,
    required this.dayOfYear,
    required this.tMaxC,
    required this.tMinC,
    this.tDewC,
    this.rhMaxPct,
    this.rhMinPct,
    this.rhMeanPct,
    this.actualVapourPressureKPa,
    this.windSpeedMs,
    this.windHeightM = 2,
    this.sunshineHours,
    this.solarRadiationMJ,
    this.soilHeatFluxMJ = 0,
    this.kRs = 0.16,
    this.island = false,
    this.angstromA = 0.25,
    this.angstromB = 0.50,
    this.calibratedAngstrom = false,
    this.albedo = 0.23,
    this.aridTminOffsetC = 0,
  });

  final double latitudeDeg;
  final double elevationM;
  final int dayOfYear;
  final double tMaxC;
  final double tMinC;

  /// Humidity, in order of preference (FAO-56 eqs. 14, 17, 18, 19, then 48):
  /// measured ea, dew point, RHmax with RHmin, RHmax alone, RHmean.
  final double? actualVapourPressureKPa;
  final double? tDewC;
  final double? rhMaxPct;
  final double? rhMinPct;
  final double? rhMeanPct;

  /// Wind speed (m/s) measured at [windHeightM]; null uses 2 m/s at 2 m.
  final double? windSpeedMs;
  final double windHeightM;

  /// Radiation, in order of preference: measured Rs, hours of bright
  /// sunshine (eq. 35), then the temperature range (eq. 50) or the island
  /// formula (eq. 51).
  final double? solarRadiationMJ;
  final double? sunshineHours;

  /// Soil heat flux G (MJ m⁻² day⁻¹): 0 for daily steps (eq. 42).
  final double soilHeatFluxMJ;

  /// Adjustment coefficient of eq. 50: 0.16 interior, 0.19 coastal.
  final double kRs;

  /// Use eq. 51 instead of eq. 50 when no radiation or sunshine is given.
  final bool island;
  final double angstromA;
  final double angstromB;

  /// Rso from (as + bs)·Ra (eq. 36) instead of eq. 37.
  final bool calibratedAngstrom;
  final double albedo;

  /// Subtracted from Tmin when it stands in for the dew point in arid
  /// climates (FAO-56 Annex 6: about 2 °C).
  final double aridTminOffsetC;
}

/// FAO Penman-Monteith result and its intermediate terms.
class Fao56Result {
  const Fao56Result({
    required this.etoMmDay,
    required this.raMJ,
    required this.rsMJ,
    required this.rsoMJ,
    required this.rnsMJ,
    required this.rnlMJ,
    required this.rnMJ,
    required this.gMJ,
    required this.deltaKPaPerC,
    required this.gammaKPaPerC,
    required this.pressureKPa,
    required this.esKPa,
    required this.eaKPa,
    required this.u2Ms,
    required this.daylightHours,
    required this.radiationTermMmDay,
    required this.aerodynamicTermMmDay,
    required this.estimated,
  });

  /// Grass reference evapotranspiration (mm/day), FAO-56 eq. 6.
  final double etoMmDay;
  final double raMJ;
  final double rsMJ;
  final double rsoMJ;
  final double rnsMJ;
  final double rnlMJ;
  final double rnMJ;
  final double gMJ;
  final double deltaKPaPerC;
  final double gammaKPaPerC;
  final double pressureKPa;
  final double esKPa;
  final double eaKPa;
  final double u2Ms;
  final double daylightHours;

  /// The two terms of eq. 6: 0.408·Δ·(Rn − G)/[Δ + γ(1 + 0.34u2)] and
  /// γ·900/(T + 273)·u2·(es − ea)/[Δ + γ(1 + 0.34u2)] (mm/day).
  final double radiationTermMmDay;
  final double aerodynamicTermMmDay;

  /// Data that had to be estimated or limited.
  final Set<Fao56Estimate> estimated;

  /// Vapour pressure deficit es − ea (kPa).
  double get vapourPressureDeficitKPa => esKPa - eaKPa;
}

/// Grass reference evapotranspiration with the FAO Penman-Monteith equation
/// (FAO-56 eq. 6, Box 11 calculation sheet), estimating missing humidity,
/// radiation and wind as FAO-56 chapter 3 recommends.
Fao56Result fao56Eto(Fao56Input i) {
  final estimated = <Fao56Estimate>{};
  final tMean = (i.tMaxC + i.tMinC) / 2; // eq. 9
  final p = atmosphericPressureKPa(i.elevationM);
  final gamma = psychrometricConstantKPaPerC(p);
  final delta = vapourPressureSlopeKPaPerC(tMean);
  final es = meanSaturationVapourPressureKPa(i.tMaxC, i.tMinC);
  double ea;
  if (i.actualVapourPressureKPa != null) {
    ea = i.actualVapourPressureKPa!;
  } else if (i.tDewC != null) {
    ea = actualVapourPressureFromDewPointKPa(i.tDewC!);
  } else if (i.rhMaxPct != null && i.rhMinPct != null) {
    ea = actualVapourPressureFromRhKPa(i.tMaxC, i.tMinC, i.rhMaxPct!, i.rhMinPct!);
  } else if (i.rhMaxPct != null) {
    ea = actualVapourPressureFromRhMaxKPa(i.tMinC, i.rhMaxPct!);
  } else if (i.rhMeanPct != null) {
    ea = actualVapourPressureFromRhMeanKPa(i.tMaxC, i.tMinC, i.rhMeanPct!);
  } else {
    ea = actualVapourPressureFromDewPointKPa(i.tMinC - i.aridTminOffsetC);
    estimated.add(Fao56Estimate.vapourPressureFromTmin);
  }
  // radiation
  final ra = extraterrestrialRadiationMJ(i.latitudeDeg, i.dayOfYear);
  final n = daylightHours(i.latitudeDeg, i.dayOfYear);
  final rso = clearSkyRadiationMJ(ra, i.elevationM, angstromSum: i.calibratedAngstrom ? i.angstromA + i.angstromB : null);
  double rs;
  if (i.solarRadiationMJ != null) {
    rs = i.solarRadiationMJ!;
  } else if (i.sunshineHours != null) {
    rs = solarRadiationFromSunshineMJ(ra, i.sunshineHours!, n, angstromA: i.angstromA, angstromB: i.angstromB);
  } else if (i.island) {
    rs = solarRadiationIslandMJ(ra);
    estimated.add(Fao56Estimate.radiationIsland);
  } else {
    rs = solarRadiationFromTemperatureMJ(ra, i.tMaxC, i.tMinC, kRs: i.kRs);
    estimated.add(Fao56Estimate.radiationFromTemperature);
    if (rs > rso) {
      rs = rso;
      estimated.add(Fao56Estimate.radiationLimitedToClearSky);
    }
  }
  final rns = netShortwaveRadiationMJ(rs, albedo: i.albedo);
  final rnl = netLongwaveRadiationMJ(i.tMaxC, i.tMinC, ea, rs, rso);
  final rn = rns - rnl;
  // wind
  var u2 = i.windSpeedMs == null ? 2.0 : windSpeedAt2m(i.windSpeedMs!, i.windHeightM);
  if (i.windSpeedMs == null) estimated.add(Fao56Estimate.windDefault);
  if (u2 < 0.5) {
    u2 = 0.5;
    estimated.add(Fao56Estimate.windLimited);
  }
  final g = i.soilHeatFluxMJ;
  final den = delta + gamma * (1 + 0.34 * u2);
  final radTerm = mmPerMJPerM2 * delta * (rn - g) / den;
  final aeroTerm = gamma * 900 / (tMean + 273) * u2 * (es - ea) / den;
  return Fao56Result(
    etoMmDay: math.max(radTerm + aeroTerm, 0.0),
    raMJ: ra,
    rsMJ: rs,
    rsoMJ: rso,
    rnsMJ: rns,
    rnlMJ: rnl,
    rnMJ: rn,
    gMJ: g,
    deltaKPaPerC: delta,
    gammaKPaPerC: gamma,
    pressureKPa: p,
    esKPa: es,
    eaKPa: ea,
    u2Ms: u2,
    daylightHours: n,
    radiationTermMmDay: radTerm,
    aerodynamicTermMmDay: aeroTerm,
    estimated: estimated,
  );
}

/// Mean climate of one calendar month (means of daily values; rain is the
/// monthly total). Fields left null are estimated by [fao56Eto] (humidity,
/// radiation, wind) or by the given [etoMmDay].
class MonthlyClimate {
  const MonthlyClimate({
    required this.month,
    required this.tMaxC,
    required this.tMinC,
    this.tDewC,
    this.rhMaxPct,
    this.rhMinPct,
    this.rhMeanPct,
    this.windSpeed2mMs,
    this.sunshineHours,
    this.solarRadiationMJ,
    this.rainMm = 0,
    this.dependableRainMm,
    this.etoMmDay,
  });

  /// 1–12.
  final int month;
  final double tMaxC;
  final double tMinC;
  final double? tDewC;
  final double? rhMaxPct;
  final double? rhMinPct;
  final double? rhMeanPct;

  /// Mean wind speed at 2 m (m/s).
  final double? windSpeed2mMs;

  /// Mean daily bright sunshine (h/day).
  final double? sunshineHours;

  /// Mean daily solar radiation (MJ m⁻² day⁻¹).
  final double? solarRadiationMJ;

  /// Mean monthly rain (mm/month) and the rain exceeded in a given share of
  /// the years (dependable rain, mm/month), when known.
  final double rainMm;
  final double? dependableRainMm;

  /// ETo known beforehand (mm/day); [fao56MonthlySeries] keeps it.
  final double? etoMmDay;

  double get tMeanC => (tMaxC + tMinC) / 2;
}

/// Monthly ETo of a whole year with the FAO Penman-Monteith equation for the
/// mean day (the 15th) of every month, with the soil heat flux from the
/// neighbouring months (FAO-56 eq. 43, the year taken as cyclic). [months]
/// must hold the twelve months in any order; the result follows January to
/// December (null for a month that is missing).
List<Fao56Result?> fao56MonthlySeries(List<MonthlyClimate> months, {required double latitudeDeg, required double elevationM, double kRs = 0.16, bool island = false}) {
  final byMonth = {for (final m in months) m.month: m};
  final out = <Fao56Result?>[];
  for (var m = 1; m <= 12; m++) {
    final c = byMonth[m];
    if (c == null) {
      out.add(null);
      continue;
    }
    final prev = byMonth[m == 1 ? 12 : m - 1], next = byMonth[m == 12 ? 1 : m + 1];
    final g = monthlySoilHeatFluxMJ(tMeanC: c.tMeanC, tPrevMonthC: prev?.tMeanC, tNextMonthC: next?.tMeanC);
    out.add(
      fao56Eto(
        Fao56Input(
          latitudeDeg: latitudeDeg,
          elevationM: elevationM,
          dayOfYear: midMonthDayOfYear(m),
          tMaxC: c.tMaxC,
          tMinC: c.tMinC,
          tDewC: c.tDewC,
          rhMaxPct: c.rhMaxPct,
          rhMinPct: c.rhMinPct,
          rhMeanPct: c.rhMeanPct,
          windSpeedMs: c.windSpeed2mMs,
          sunshineHours: c.sunshineHours,
          solarRadiationMJ: c.solarRadiationMJ,
          soilHeatFluxMJ: g,
          kRs: kRs,
          island: island,
        ),
      ),
    );
  }
  return out;
}

/// Days in [month] of [year] (Gregorian calendar).
int daysInMonth(int year, int month) => DateTime.utc(year, month + 1).difference(DateTime.utc(year, month)).inDays;
