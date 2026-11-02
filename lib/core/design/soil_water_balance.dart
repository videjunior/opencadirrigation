/// Daily soil water balance of the root zone of an irrigated area, FAO-56
/// chapter 8 (Allen, Pereira, Raes & Smith 1998), with the single crop
/// coefficient of the area's crop:
/// - ETc = Kc·ETo, with the localized irrigation reduction ETc,loc =
///   Kr·Kc·ETo of area_water.dart; the stress coefficient Ks =
///   (TAW − Dr)/((1 − p)·TAW) once the depletion Dr passes the readily
///   available water RAW = p·TAW (eq. 84) and ETc,adj = Ks·ETc (eq. 81);
/// - TAW = AWC·Zr (eq. 82), RAW = p·TAW (eq. 83) with p adjusted to the ETc
///   of the day (Table 22 note 2) while it is the table's value; for
///   localized irrigation both are times the wetted fraction Pw (the soil
///   within the reach of the emitters, the rule of area_water.dart);
/// - the depletion at the end of each day Dr,i = Dr,i−1 − (P − RO)i − Ii +
///   ETc,adj,i + DPi (eq. 85), kept between 0 and TAW (eq. 86), the water
///   above field capacity lost by deep percolation (eq. 88); rain below
///   0.2·ETo of the day wets only the surface and evaporates (FAO-56 ch. 8),
///   surface runoff and capillary rise are taken as zero;
/// - irrigation when the depletion reaches the allowed depletion of the
///   growth stage (RAW, or more for regulated deficit irrigation, FAO-56
///   ch. 8 "deficit irrigation"), refilling a share of it; or every few
///   days; or never (rain only);
/// - the yield response to the water deficit of the season, 1 − Ya/Ym =
///   Ky·(1 − ΣETc,adj/ΣETc) (FAO-56 eq. 90; Doorenbos & Kassam 1979,
///   FAO-33), with the seasonal Ky of FAO-33.
///
/// The weather is a typical year built from the monthly normals of the
/// site (the ETo of each month on every day of it, as the requirement
/// table takes it, and the month's rain in a few equal events), or one year
/// of the daily series kept with the site climate (a station file or a
/// download).
library;

import 'dart:math' as math;

import '../model/agronomy_plan.dart';
import '../model/entities.dart';
import '../model/project.dart';
import 'area_water.dart';
import 'climate.dart' show daysInMonth;
import 'crops.dart';
import 'irrigation_requirement.dart';

/// Seasonal yield response factors Ky of FAO-33 (Doorenbos & Kassam 1979,
/// "Yield response to water", Table 24), as tabulated in FAO Irrigation
/// Water Management Training Manual No. 4 (Brouwer, Prins & Heibloem 1989,
/// "Irrigation scheduling"), Annex II, Table 12, "total growing period";
/// a range is stored as its mid value. Crops FAO-33 does not list have
/// none (type it).
const fao33SeasonalKy = <String, double>{
  'crop.alfalfa': 0.9, // 0.7–1.1
  'crop.banana': 1.275, // 1.2–1.35
  'crop.dryBean': 1.15,
  'crop.citrus': 0.95, // 0.8–1.1
  'crop.cotton': 0.85,
  'crop.grape': 0.85,
  'crop.tableGrape': 0.85,
  'crop.peanut': 0.7,
  'crop.maize': 1.25,
  'crop.onion': 1.1,
  'crop.pepper': 1.1,
  'crop.potato': 1.1,
  'crop.sorghum': 0.9,
  'crop.soybean': 0.85,
  'crop.sugarbeet': 0.9, // sugar yield 0.7–1.1
  'crop.sugarcane': 1.2,
  'crop.sugarcanePlant': 1.2,
  'crop.sunflower': 0.95,
  'crop.tomato': 1.05,
  'crop.watermelon': 1.1,
  'crop.wheat': 1.15, // spring wheat (the row of the crop table)
};

/// Rain of a day below this share of its ETo only wets the surface and
/// evaporates (FAO-56 chapter 8).
const ineffectiveRainShareOfEto = 0.2;

/// Weather of one day of the balance.
class BalanceWeather {
  const BalanceWeather(this.date, this.etoMm, this.rainMm);
  final DateTime date;
  final double etoMm;
  final double rainMm;
}

/// The weather of a typical [year] from monthly [normals]: the month's mean
/// ETo every day of it and its rain (mean, or dependable with [dependable])
/// in [rainEvents] equal events spread evenly over the month.
List<BalanceWeather> typicalYearWeather(ClimateNormals normals, {int year = 2001, int rainEvents = 4, bool dependable = false}) {
  final rain = dependable && normals.dependableRainMm != null ? normals.dependableRainMm! : normals.rainMm;
  final k = rainEvents.clamp(1, 31);
  final out = <BalanceWeather>[];
  for (var m = 1; m <= 12; m++) {
    final n = daysInMonth(year, m);
    final events = math.min(k, n);
    final wet = <int>{for (var i = 0; i < events; i++) ((i + 0.5) * n / events).floor() + 1};
    for (var d = 1; d <= n; d++) {
      out.add(BalanceWeather(DateTime.utc(year, m, d), normals.etoMmDay[m - 1], wet.contains(d) ? rain[m - 1] / wet.length : 0.0));
    }
  }
  return out;
}

/// The day of [weather] on the date of [date] in a cyclic typical year
/// (the same day and month; 29 February takes the 28th).
BalanceWeather _cyclicDay(List<BalanceWeather> weather, DateTime date) {
  final y = weather.first.date.year;
  final d = DateTime.utc(y, date.month, date.month == 2 && date.day == 29 ? 28 : date.day);
  final i = d.difference(DateTime.utc(y, 1, 1)).inDays;
  return weather[i.clamp(0, weather.length - 1)];
}

/// The weather of [days] (date, ETo, rain) of a daily series.
List<BalanceWeather> seriesWeather(List<(DateTime, double, double)> days) => [for (final (d, e, r) in days) BalanceWeather(d, e, r)];

/// Inputs of the balance of one area.
class BalanceInput {
  const BalanceInput({
    required this.weather,
    required this.curve,
    required this.planting,
    this.repeatsYearly = true,
    this.kr = 1,
    this.wettedFraction = 1,
    required this.awcMmPerM,
    required this.rootDepthM,
    required this.depletionFraction,
    this.adjustDepletionToEtc = true,
    this.efficiency = 0.9,
    this.grossFactorByMonth,
    required this.settings,
    this.ky,
    this.cyclic = true,
  });

  /// Daily weather: a typical year ([cyclic], the season may wrap around
  /// its end) or the days of a series.
  final List<BalanceWeather> weather;
  final bool cyclic;
  final KcCurve curve;
  final DateTime planting;
  final bool repeatsYearly;
  final double kr;
  final double wettedFraction;
  final double awcMmPerM;
  final double rootDepthM;

  /// Depletion fraction p (for ETc ≈ 5 mm/day when [adjustDepletionToEtc]).
  final double depletionFraction;
  final bool adjustDepletionToEtc;

  /// Application efficiency Ea, and the gross over net depth of every month
  /// (efficiency and leaching requirement of the requirement table; null:
  /// 1/Ea).
  final double efficiency;
  final List<double>? grossFactorByMonth;
  final BalanceSettings settings;

  /// Seasonal yield response factor (null: no yield estimate).
  final double? ky;
}

/// One day of the balance.
class BalanceDay {
  const BalanceDay({
    required this.date,
    required this.stage,
    required this.kc,
    required this.etoMm,
    required this.etcMm,
    required this.etaMm,
    required this.ks,
    required this.rainMm,
    required this.effectiveRainMm,
    required this.netIrrigationMm,
    required this.grossIrrigationMm,
    required this.depletionMm,
    required this.rawMm,
    required this.tawMm,
    required this.deepPercolationMm,
  });
  final DateTime date;

  /// Growth stage: 0 initial, 1 development, 2 mid-season, 3 late; −1 off
  /// season (no crop).
  final int stage;
  final double kc;
  final double etoMm;

  /// ETc,loc = Kr·Kc·ETo and ETc,adj = Ks·ETc,loc (mm).
  final double etcMm;
  final double etaMm;
  final double ks;
  final double rainMm;
  final double effectiveRainMm;
  final double netIrrigationMm;
  final double grossIrrigationMm;

  /// Depletion at the end of the day, and the RAW and TAW of the day (mm,
  /// over the whole area: times Pw for localized irrigation).
  final double depletionMm;
  final double rawMm;
  final double tawMm;
  final double deepPercolationMm;

  bool get stressed => ks < 1 - 1e-9;
}

/// One irrigation of the balance.
class BalanceEvent {
  const BalanceEvent({required this.date, required this.depletionMm, required this.netMm, required this.grossMm});
  final DateTime date;

  /// Depletion the irrigation found (mm).
  final double depletionMm;
  final double netMm;
  final double grossMm;
}

/// The daily balance of one area over its season.
class BalanceResult {
  const BalanceResult({
    required this.days,
    required this.events,
    required this.etcMm,
    required this.etaMm,
    required this.rainMm,
    required this.effectiveRainMm,
    required this.netMm,
    required this.grossMm,
    required this.deepPercolationMm,
    required this.stressDays,
    required this.initialDepletionMm,
    this.ky,
    this.warnings = const [],
  });
  final List<BalanceDay> days;
  final List<BalanceEvent> events;

  /// Totals over the period (mm).
  final double etcMm, etaMm, rainMm, effectiveRainMm, netMm, grossMm, deepPercolationMm;
  final int stressDays;
  final double initialDepletionMm;
  final double? ky;

  /// Message codes (`wb_*`).
  final List<String> warnings;

  /// ETc,adj over ETc of the season (1 = no stress).
  double get relativeEt => etcMm > 0 ? etaMm / etcMm : 1.0;

  /// Ya/Ym by FAO-56 eq. 90 (null without Ky).
  double? get relativeYield => ky == null ? null : (1 - ky! * (1 - relativeEt)).clamp(0.0, 1.0).toDouble();

  /// Depletion at the end of the period (mm).
  double get finalDepletionMm => days.isEmpty ? initialDepletionMm : days.last.depletionMm;

  /// The balance closes: water in (effective rain, net irrigation) less
  /// water out (ETc,adj, deep percolation) is the fall of the depletion.
  double get closureErrorMm => (effectiveRainMm + netMm - etaMm - deepPercolationMm) - (initialDepletionMm - finalDepletionMm);
}

/// The growth stage at [t] days after planting on [curve] (−1 off season).
int growthStage(KcCurve curve, double? t) {
  if (t == null) return -1;
  final s = curve.stages;
  if (t < s.initial) return 0;
  if (t < s.initial + s.development) return 1;
  if (t < s.initial + s.development + s.mid) return 2;
  return t <= s.total ? 3 : -1;
}

/// Runs the daily balance of [input].
BalanceResult soilWaterBalance(BalanceInput input) {
  final s = input.settings;
  final warnings = <String>[];
  final curve = input.curve;
  final season = curve.seasonDays;
  // the period: one cycle from the planting date, or the calendar year of
  // the weather for crops in the field all year
  final yearRound = season >= 365 - 1e-9;
  final List<BalanceWeather> period;
  if (input.weather.isEmpty) {
    return BalanceResult(
      days: const [],
      events: const [],
      etcMm: 0,
      etaMm: 0,
      rainMm: 0,
      effectiveRainMm: 0,
      netMm: 0,
      grossMm: 0,
      deepPercolationMm: 0,
      stressDays: 0,
      initialDepletionMm: 0,
      ky: input.ky,
      warnings: const ['wb_no_weather'],
    );
  }
  if (yearRound) {
    final y0 = input.weather.first.date.year;
    period = [
      for (final w in input.weather)
        if (w.date.year == y0) w,
    ];
  } else {
    final y0 = input.weather.first.date.year;
    final start = DateTime.utc(y0, input.planting.month, input.planting.day);
    final n = season.ceil();
    if (input.cyclic) {
      period = [for (var i = 0; i < n; i++) _cyclicDay(input.weather, start.add(Duration(days: i)))];
      // the dates of the cycle itself (the weather of the same day of the year)
      for (var i = 0; i < period.length; i++) {
        final d = start.add(Duration(days: i));
        period[i] = BalanceWeather(d, period[i].etoMm, period[i].rainMm);
      }
    } else {
      final byDate = {for (final w in input.weather) w.date: w};
      period = [
        for (var i = 0; i < n; i++)
          if (byDate[start.add(Duration(days: i))] case final w?) w,
      ];
      if (period.length < n) warnings.add('wb_series_short');
    }
  }
  final fw = input.wettedFraction.clamp(0.05, 1.0).toDouble();
  final taw = math.max(input.awcMmPerM, 0.0) * math.max(input.rootDepthM, 0.0) * fw;
  final eff = input.efficiency.clamp(0.05, 1.0).toDouble();
  var dr = (s.initialDepletionPct.clamp(0.0, 100.0) / 100 * taw).toDouble();
  final dr0 = dr;
  final days = <BalanceDay>[];
  final events = <BalanceEvent>[];
  var etcSum = 0.0, etaSum = 0.0, rainSum = 0.0, peSum = 0.0, netSum = 0.0, grossSum = 0.0, dpSum = 0.0;
  var stress = 0;
  var firstCropDay = -1;
  for (var i = 0; i < period.length; i++) {
    final w = period[i];
    final double? t;
    if (yearRound) {
      t = daysIntoCycle(w.date, input.planting, season, repeatsYearly: true);
    } else {
      t = i.toDouble();
    }
    final kcRaw = t == null ? curve.offSeasonKc : curve.mean(t, math.min(t + 1, season));
    final kc = math.max(kcRaw, 0.0);
    final stage = kc <= 0 ? -1 : (yearRound && curve.stages.initial + curve.stages.development + curve.stages.late == 0 ? 2 : growthStage(curve, t));
    final eto = math.max(w.etoMm, 0.0);
    final etcFull = kc * eto;
    final etc = etcFull * input.kr;
    final pTab = input.depletionFraction.clamp(0.05, 0.95).toDouble();
    final p = input.adjustDepletionToEtc ? adjustDepletionFraction(pTab, etcFull) : pTab;
    final raw = p * taw;
    // stress from the depletion at the start of the day (eq. 84)
    final ks = taw <= 0 ? 0.0 : (dr <= raw ? 1.0 : ((taw - dr) / ((1 - p) * taw)).clamp(0.0, 1.0).toDouble());
    final eta = ks * etc;
    final rain = math.max(w.rainMm, 0.0);
    final pe = rain >= ineffectiveRainShareOfEto * eto ? rain : 0.0;
    // irrigation
    var net = 0.0;
    if (kc > 0) {
      if (firstCropDay < 0) firstCropDay = i;
      final projected = dr - pe + eta;
      final allowed = stage >= 0 && stage < 4 && s.allowedDepletion[stage] > 0 ? s.allowedDepletion[stage] * taw : raw;
      switch (s.trigger) {
        case BalanceTrigger.depletion:
          if (projected >= allowed - 1e-9 && projected > 0) net = projected * s.refillPct.clamp(10.0, 100.0) / 100;
        case BalanceTrigger.interval:
          final every = math.max(1, s.intervalDays);
          if ((i - firstCropDay) % every == 0 && projected > 0) net = projected * s.refillPct.clamp(10.0, 100.0) / 100;
        case BalanceTrigger.rainfed:
          break;
      }
    }
    var next = dr - pe - net + eta;
    var dp = 0.0;
    if (next < 0) {
      dp = -next;
      next = 0;
    }
    if (next > taw) next = taw;
    final month = w.date.month;
    final factor = input.grossFactorByMonth != null && input.grossFactorByMonth![month - 1] > 0 ? input.grossFactorByMonth![month - 1] : 1 / eff;
    final gross = net * factor;
    if (net > 0) events.add(BalanceEvent(date: w.date, depletionMm: dr - pe + eta, netMm: net, grossMm: gross));
    if (kc > 0 && ks < 1 - 1e-9) stress++;
    days.add(
      BalanceDay(
        date: w.date,
        stage: stage,
        kc: kc,
        etoMm: eto,
        etcMm: etc,
        etaMm: eta,
        ks: ks,
        rainMm: rain,
        effectiveRainMm: pe,
        netIrrigationMm: net,
        grossIrrigationMm: gross,
        depletionMm: next,
        rawMm: raw,
        tawMm: taw,
        deepPercolationMm: dp,
      ),
    );
    etcSum += etc;
    etaSum += eta;
    rainSum += rain;
    peSum += pe;
    netSum += net;
    grossSum += gross;
    dpSum += dp;
    dr = next;
  }
  if (taw <= 0) warnings.add('wb_no_soil_water');
  if (s.trigger != BalanceTrigger.rainfed && stress > 0) warnings.add('wb_stress');
  return BalanceResult(
    days: days,
    events: events,
    etcMm: etcSum,
    etaMm: etaSum,
    rainMm: rainSum,
    effectiveRainMm: peSum,
    netMm: netSum,
    grossMm: grossSum,
    deepPercolationMm: dpSum,
    stressDays: stress,
    initialDepletionMm: dr0,
    ky: input.ky,
    warnings: warnings,
  );
}

/// Seasonal Ky of the crop of area [a]: the one set for the balance, the
/// user crop's, else FAO-33's (null when unknown).
double? seasonalKyOf(Project p, AreaEntity a, BalanceSettings s) {
  if (s.ky > 0) return s.ky;
  final u = p.agronomy.userCrop(a.cropKey);
  if (u != null) return u.ky > 0 ? u.ky : null;
  return fao33SeasonalKy[a.cropKey];
}

/// The balance settings of area [a] (the defaults when none are kept).
BalanceSettings balanceSettingsOf(Project p, AreaEntity a) => p.agronomy.balance[a.id] ?? BalanceSettings();

/// The years of the daily series of the site climate the balance can run.
List<int> balanceYears(Project p) => p.climate?.daily?.completeYears ?? const [];

/// The balance input of area [a] of [p] (null when the area has a fixed
/// daily depth, no water balance): the crop of the requirement table
/// (`requirementInputOf`: its Kc curve with the climatic adjustment,
/// planting date, Kr, Pw, soil and p, and the gross factor of every month
/// with the leaching requirement), or the ETo and Kc typed on the area
/// all year; the weather of [settings] (a year of the daily series, else
/// the typical year of the normals, else the area's ETo without rain).
BalanceInput? balanceInputOf(Project p, AreaEntity a, {BalanceSettings? settings}) {
  if (!a.useWaterBalance || a.points.length < 3) return null;
  final s = settings ?? balanceSettingsOf(p, a);
  final normals = p.climate?.normals ?? ClimateNormals(etoMmDay: List.filled(12, a.etoMmDay), rainMm: List.filled(12, 0.0));
  final daily = p.climate?.daily;
  final days = s.year != 0 && daily != null ? daily.yearDays(s.year, fill: normals.etoMmDay) : null;
  final series = days == null || days.isEmpty ? null : seriesWeather(days);
  final weather = series ?? typicalYearWeather(normals, rainEvents: s.rainEventsPerMonth, dependable: a.useDependableRain);
  final req = requirementInputOf(p, a);
  if (req != null && req.cycles.isNotEmpty) {
    final c = req.cycles.first;
    final table = irrigationRequirement(req);
    final factor = List<double>.filled(12, 0);
    for (final r in table.monthly) {
      if (r.cycleIndex == 0 && r.netMm > 0 && r.applicable) factor[r.start.month - 1] = r.grossMm / r.netMm;
    }
    return BalanceInput(
      weather: weather,
      cyclic: series == null,
      curve: c.curve,
      planting: c.planting,
      repeatsYearly: c.repeatsYearly,
      kr: c.kr,
      wettedFraction: req.wettedFraction,
      awcMmPerM: req.awcMmPerM,
      rootDepthM: c.rootDepthM ?? req.rootDepthM,
      depletionFraction: c.depletionFraction ?? req.depletionFraction,
      adjustDepletionToEtc: req.adjustDepletionToEtc,
      efficiency: req.efficiency,
      grossFactorByMonth: factor,
      settings: s,
      ky: seasonalKyOf(p, a, s),
    );
  }
  return BalanceInput(
    weather: weather,
    cyclic: series == null,
    curve: KcCurve.constant(math.max(a.kc, 0.0)),
    planting: DateTime.utc(weather.first.date.year, 1, 1),
    kr: areaKr(a),
    wettedFraction: areaPw(a),
    awcMmPerM: a.awcMmPerM,
    rootDepthM: a.rootDepthM,
    depletionFraction: a.mad,
    adjustDepletionToEtc: false,
    efficiency: a.efficiency,
    settings: s,
    ky: s.ky > 0 ? s.ky : null,
  );
}

/// The daily balance of area [a] of [p] (null when it has no water
/// balance).
BalanceResult? areaWaterBalance(Project p, AreaEntity a, {BalanceSettings? settings}) {
  final input = balanceInputOf(p, a, settings: settings);
  return input == null ? null : soilWaterBalance(input);
}
