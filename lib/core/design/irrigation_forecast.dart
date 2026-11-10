/// The irrigation forecast (1.7.0 FCT): how long each irrigated area should run in the coming days, from the weather
/// forecast of the site (lib/core/io/forecast_online.dart) and the design. Design programs stop at the delivered
/// drawing; this keeps the project useful every day of the season.
///
/// Method, for every irrigated area with a water balance, day by day from today over the days of the forecast:
/// - ETo of the day: the service's when it publishes one (Open-Meteo), else FAO Penman-Monteith (FAO-56 eq. 6,
///   climate.dart) on the daily values of the forecast, with the solar radiation from the temperature range (FAO-56
///   eq. 50) when the service gives no radiation (MET Norway);
/// - the crop of the area as its requirement table and its daily soil water balance take it (`balanceInputOf`,
///   soil_water_balance.dart): the Kc curve of FAO-56 (or the user's crop, or the Kc typed on the area) on each date,
///   from the planting date of the area (read for the hemisphere of the site), ETc,loc = Kr·Kc·ETo, TAW = AWC·Zr·Pw,
///   RAW = p·TAW with p adjusted to the ETc of the day (FAO-56 Table 22 note 2), the stress coefficient Ks of eq. 84;
/// - the rain of the forecast, effective as the daily balance of the app takes it: a day's rain below 0.2·ETo only
///   wets the surface (FAO-56 chapter 8); above field capacity it percolates (eq. 88);
/// - irrigate on the day the depletion would reach the smaller of the allowed depletion of the stage (RAW unless a
///   regulated deficit is set for the area) and the net depth of one event of the design programme
///   (agronomy.dart): the programme's interval is kept as long as the weather asks for the design depth, and a day
///   that asks for less waits; an irrigation refills the depletion (the share set in the area's balance settings),
///   the gross depth is the net over the efficiency (with the leaching requirement of the month), and the run time
///   is the gross depth over the application rate of the area in the design results;
/// - the share of one programmed event that day (% of the design run time) and the water budget of the forecast
///   days: the net water the crop uses less the rain the root zone keeps (effective rain less what percolates), over
///   what the design programme applies in as many days of its design month (the seasonal adjustment a controller
///   takes, irrigation_programme.dart).
///
/// Assumed: the state of the soil at the start (full today by default, or after the last irrigation or rain the user
/// gives, with no rain since and the ETo of the site climate for the month in between); no rain after the last day
/// of the forecast; the forecast as given. A forecast is uncertain, more so after the first three days.
library;

import 'dart:math' as math;

import '../model/entities.dart';
import '../model/project.dart';
import '../io/forecast_online.dart';
import '../translate.dart';
import '../units.dart';
import 'agronomy.dart' show CropWaterResult, cropWaterRequirements;
import 'area_water.dart';
import 'crops.dart';
import 'fertigation_stages.dart' show fertStageNames;
import 'report_tables.dart';
import 'results.dart';
import 'soil_water_balance.dart';

/// Hours of today the forecast must still cover for today's ETo to come from today's own values; below it the ETo of
/// tomorrow stands for it (the extremes of a few evening hours say little about the day).
const forecastTodayMinHours = 12.0;

/// Hours a later day must be covered to count; the last day of a horizon is usually cut short.
const forecastDayMinHours = 18.0;

/// How the soil stands when the forecast starts: the simplest the user can tell.
class ForecastStart {
  /// The root zone at field capacity at the start of today (just irrigated, or after a good rain): the default.
  const ForecastStart.full() : full = true, daysAgo = 1, depthMm = null;

  /// The last irrigation or rain [daysAgo] days ago (0 = today), with [depthMm] of water into the soil; null: it
  /// filled the root zone. A depth smaller than the depletion at which the area is irrigated leaves the soil short of
  /// full by the difference (the event is taken to have come at that depletion).
  const ForecastStart.last(this.daysAgo, {this.depthMm}) : full = false;

  final bool full;
  final int daysAgo;
  final double? depthMm;
}

/// One day of the weather of the forecast.
class ForecastWeatherDay {
  const ForecastWeatherDay({
    required this.date,
    required this.etoMm,
    required this.byService,
    required this.rainMm,
    required this.effectiveRainMm,
    this.tMaxC,
    this.tMinC,
    this.estimated = false,
    this.radiationFromTemperature = false,
  });
  final DateTime date;
  final double etoMm;

  /// ETo published by the service (else Penman-Monteith on the day's values).
  final bool byService;
  final double rainMm;

  /// Rain that counts (0 below 0.2·ETo).
  final double effectiveRainMm;
  final double? tMaxC;
  final double? tMinC;

  /// Today with too few hours left: its ETo is tomorrow's.
  final bool estimated;

  /// Solar radiation from the temperature range (FAO-56 eq. 50).
  final bool radiationFromTemperature;
}

/// One day of one area.
class AreaForecastDay {
  const AreaForecastDay({
    required this.date,
    required this.stage,
    required this.kc,
    required this.etcMm,
    required this.etaMm,
    required this.effectiveRainMm,
    required this.depletionMm,
    required this.endDepletionMm,
    required this.rawMm,
    required this.tawMm,
    required this.thresholdMm,
    required this.netMm,
    required this.grossMm,
    required this.deepPercolationMm,
    this.runHours,
    this.eventPct,
  });
  final DateTime date;

  /// 0 initial, 1 development, 2 mid-season, 3 late; −1 no crop.
  final int stage;
  final double kc;

  /// ETc,loc and ETc,adj (mm).
  final double etcMm;
  final double etaMm;
  final double effectiveRainMm;

  /// Depletion of the root zone the day reaches before any irrigation, and at its end (mm).
  final double depletionMm;
  final double endDepletionMm;
  final double rawMm;
  final double tawMm;

  /// The depletion that calls for irrigation that day (mm).
  final double thresholdMm;
  final double netMm;
  final double grossMm;
  final double deepPercolationMm;

  /// Run time (h) at the application rate; null without a rate.
  final double? runHours;

  /// The gross depth as a share of one event of the design programme (%); null when the programme has none.
  final double? eventPct;

  bool get irrigate => netMm > 0;
}

/// The forecast of one irrigated area.
class AreaForecast {
  const AreaForecast({
    required this.areaId,
    required this.name,
    required this.cropKey,
    required this.balance,
    required this.rateMmH,
    required this.programmeNetMm,
    required this.programmeGrossMm,
    this.programmeHours,
    required this.intervalDays,
    required this.designNetMmDay,
    required this.startDepletionMm,
    this.days = const [],
    this.budgetPct,
    this.warnings = const [],
  });
  final String areaId;
  final String name;
  final String cropKey;

  /// The area has a water balance (false: a fixed daily depth, which the weather does not change).
  final bool balance;

  /// Application rate over the area (mm/h): from the design results, else from the nominal emitters.
  final double rateMmH;

  /// One event of the design programme: net and gross depth (mm), run time (h), days between events.
  final double programmeNetMm;
  final double programmeGrossMm;
  final double? programmeHours;
  final double intervalDays;

  /// Net requirement per day in the design month (mm/day).
  final double designNetMmDay;

  /// Depletion at the start of the first day (mm).
  final double startDepletionMm;
  final List<AreaForecastDay> days;

  /// Water budget of the forecast days (%), the figure a controller takes; null without a programme.
  final double? budgetPct;

  /// Codes `fct_no_rate`, `fct_off_season`, `fct_start_dry`, `fct_fixed_depth`, `fct_gap_estimated`.
  final List<String> warnings;

  int get irrigations => days.where((d) => d.irrigate).length;
  double get grossMm => days.fold(0.0, (s, d) => s + d.grossMm);
  double get netMm => days.fold(0.0, (s, d) => s + d.netMm);
}

/// The irrigation forecast of a project.
class ForecastPlan {
  const ForecastPlan({required this.series, required this.today, required this.start, required this.days, required this.areas, this.warnings = const []});
  final ForecastSeries series;

  /// The local date at the site when the plan was made.
  final DateTime today;
  final ForecastStart start;
  final List<ForecastWeatherDay> days;
  final List<AreaForecast> areas;

  /// Codes `fct_no_days`, `fct_today_estimated`, `fct_starts_later`, `fct_stale`, `fct_no_results`, `fct_no_areas`.
  final List<String> warnings;
}

/// The irrigation forecast of [p] with the design [results] (null: nominal application rates) and the forecast
/// [series], made at [now], with the soil as [start] says (see the library notes). [maxDays] limits the days.
ForecastPlan irrigationForecast(Project p, DesignResults? results, ForecastSeries series, {required DateTime now, ForecastStart start = const ForecastStart.full(), int? maxDays}) {
  final warnings = <String>[];
  final today = series.localDate(now);
  final lat = series.latitudeDeg, elev = series.elevationM ?? 0;
  ForecastEto? etoOf(ForecastDay d) => forecastDayEto(d, latitudeDeg: lat, elevationM: elev);
  final src = series.days.where((d) => !d.date.isBefore(today)).toList();
  final days = <ForecastWeatherDay>[];
  for (var i = 0; i < src.length; i++) {
    final d = src[i];
    final isToday = d.date == today;
    ForecastEto? e;
    var estimated = false;
    if (d.coverageHours >= (isToday ? forecastTodayMinHours : forecastDayMinHours) - 1e-9) {
      e = etoOf(d);
    } else if (isToday && i + 1 < src.length && src[i + 1].coverageHours >= forecastDayMinHours - 1e-9) {
      e = etoOf(src[i + 1]);
      estimated = true;
    } else if (!isToday) {
      break; // the horizon cuts this day short
    }
    if (e == null) {
      if (isToday) continue;
      break;
    }
    final rain = math.max(d.rainMm, 0.0);
    days.add(
      ForecastWeatherDay(
        date: d.date,
        etoMm: e.mmDay,
        byService: e.byService && !estimated,
        rainMm: rain,
        effectiveRainMm: rain > 0 && rain >= ineffectiveRainShareOfEto * e.mmDay ? rain : 0,
        tMaxC: d.tMaxC,
        tMinC: d.tMinC,
        estimated: estimated,
        radiationFromTemperature: e.radiationFromTemperature,
      ),
    );
    if (estimated) warnings.add('fct_today_estimated');
    if (maxDays != null && days.length >= maxDays) break;
  }
  if (series.staleCode != null) warnings.add('fct_stale');
  if (days.isEmpty) return ForecastPlan(series: series, today: today, start: start, days: const [], areas: const [], warnings: [...warnings, 'fct_no_days']);
  if (days.first.date != today) warnings.add('fct_starts_later');
  if (results == null) warnings.add('fct_no_results');
  final programme = {for (final r in cropWaterRequirements(p, results)) r.areaId: r};
  final areas = <AreaForecast>[];
  for (final a in p.entities.whereType<AreaEntity>()) {
    if (a.points.length < 3) continue;
    final f = _areaForecast(p, a, programme[a.id], days, today, start);
    areas.add(f);
  }
  if (areas.isEmpty) warnings.add('fct_no_areas');
  return ForecastPlan(series: series, today: today, start: start, days: days, areas: areas, warnings: warnings);
}

AreaForecast _areaForecast(Project p, AreaEntity a, CropWaterResult? w, List<ForecastWeatherDay> days, DateTime today, ForecastStart start) {
  final name = a.name.isEmpty ? a.id : a.name;
  final basis = areaWaterBasis(p, a);
  final rate = w?.applicationRateMmH ?? 0.0;
  final eventNet = w?.netDepthMm ?? basis.netPerEventMm;
  final eventGross = w?.grossDepthMm ?? basis.grossPerEventMm;
  final interval = w?.intervalDays ?? basis.intervalDays.toDouble();
  final double? eventHours = rate > 0 ? eventGross / rate : null;
  final input = balanceInputOf(p, a);
  if (input == null) {
    return AreaForecast(
      areaId: a.id,
      name: name,
      cropKey: a.cropKey,
      balance: false,
      rateMmH: rate,
      programmeNetMm: eventNet,
      programmeGrossMm: eventGross,
      programmeHours: eventHours,
      intervalDays: interval,
      designNetMmDay: basis.netMmDay,
      startDepletionMm: 0,
      warnings: const ['fct_fixed_depth'],
    );
  }
  final warnings = <String>[];
  final curve = input.curve, season = curve.seasonDays;
  final stages = curve.stages;
  final yearRound = season >= 365 - 1e-9;
  final s = input.settings;
  final taw = math.max(input.awcMmPerM, 0.0) * math.max(input.rootDepthM, 0.0) * input.wettedFraction.clamp(0.05, 1.0);
  final eff = input.efficiency.clamp(0.05, 1.0).toDouble();
  final pTab = input.depletionFraction.clamp(0.05, 0.95).toDouble();
  final refill = s.refillPct.clamp(10.0, 100.0) / 100;

  // the crop on [date]: Kc of the curve over that day, the growth stage, ETc (full and localized)
  (double, int, double, double) crop(DateTime date, double eto) {
    final t = daysIntoCycle(date, input.planting, season, repeatsYearly: input.repeatsYearly);
    final kc = math.max(t == null ? curve.offSeasonKc : curve.mean(t, math.min(t + 1, season)), 0.0);
    final stage = kc <= 0 ? -1 : (yearRound && stages.initial + stages.development + stages.late == 0 ? 2 : growthStage(curve, t));
    final full = kc * math.max(eto, 0.0);
    return (kc, stage, full, full * input.kr);
  }

  double pOf(double etcFull) => input.adjustDepletionToEtc ? adjustDepletionFraction(pTab, etcFull) : pTab;
  double ksOf(double dr, double raw, double pp) => taw <= 0 ? 0.0 : (dr <= raw ? 1.0 : ((taw - dr) / ((1 - pp) * taw)).clamp(0.0, 1.0).toDouble());
  double thresholdOf(int stage, double raw) {
    final allowed = stage >= 0 && stage < 4 && s.allowedDepletion[stage] > 0 ? s.allowedDepletion[stage] * taw : raw;
    return eventNet > 1e-9 ? math.min(allowed, eventNet) : allowed;
  }

  double grossFactor(int month) {
    final g = input.grossFactorByMonth;
    return g != null && g[month - 1] > 0 ? g[month - 1] : 1 / eff;
  }

  // the depletion at the start of the first day
  final first = days.first;
  var dr = 0.0;
  if (!start.full && start.depthMm != null) {
    final (_, st0, full0, _) = crop(first.date, first.etoMm);
    dr = math.max(0.0, thresholdOf(st0, pOf(full0) * taw) - math.max(start.depthMm!, 0.0));
  }
  // the days between the event and the first day of the forecast: no rain, the ETo of the site climate that month
  final event = today.subtract(Duration(days: start.full ? 1 : math.max(start.daysAgo, 0)));
  final climate = p.climate?.etoMmDay;
  var gapEstimated = false;
  for (var d = event.add(const Duration(days: 1)); d.isBefore(first.date); d = d.add(const Duration(days: 1))) {
    final eto = climate != null && climate.length == 12 && climate[d.month - 1] > 0 ? climate[d.month - 1] : null;
    if (eto == null) gapEstimated = true;
    final (_, _, full, etc) = crop(d, eto ?? first.etoMm);
    final pp = pOf(full);
    dr = math.min(taw, dr + ksOf(dr, pp * taw, pp) * etc);
  }
  if (gapEstimated) warnings.add('fct_gap_estimated');
  final dr0 = dr;
  final out = <AreaForecastDay>[];
  var anyCrop = false;
  for (final wd in days) {
    final (kc, stage, full, etc) = crop(wd.date, wd.etoMm);
    if (kc > 0) anyCrop = true;
    final pp = pOf(full);
    final raw = pp * taw;
    final ks = ksOf(dr, raw, pp);
    final eta = ks * etc;
    final pe = wd.effectiveRainMm;
    final projected = dr - pe + eta;
    final threshold = thresholdOf(stage, raw);
    final net = kc > 0 && projected > 1e-9 && projected >= threshold - 1e-9 ? projected * refill : 0.0;
    var next = projected - net;
    var dp = 0.0;
    if (next < 0) {
      dp = -next;
      next = 0;
    }
    if (next > taw) next = taw;
    final gross = net * grossFactor(wd.date.month);
    out.add(
      AreaForecastDay(
        date: wd.date,
        stage: stage,
        kc: kc,
        etcMm: etc,
        etaMm: eta,
        effectiveRainMm: pe,
        depletionMm: math.max(projected, 0.0),
        endDepletionMm: next,
        rawMm: raw,
        tawMm: taw,
        thresholdMm: threshold,
        netMm: net,
        grossMm: gross,
        deepPercolationMm: dp,
        runHours: rate > 0 ? gross / rate : null,
        eventPct: eventGross > 1e-9 ? 100 * gross / eventGross : null,
      ),
    );
    dr = next;
  }
  if (rate <= 0) warnings.add('fct_no_rate');
  if (!anyCrop) warnings.add('fct_off_season');
  if (dr0 > (out.isEmpty ? 0 : out.first.rawMm) + 1e-9) warnings.add('fct_start_dry');
  // the water budget: what the crop uses less the rain the root zone keeps, over the programme in as many days
  final used = out.fold(0.0, (s, d) => s + d.etaMm);
  final kept = out.fold(0.0, (s, d) => s + d.effectiveRainMm - d.deepPercolationMm);
  final designDay = basis.netMmDay;
  final budget = designDay > 1e-9 && out.isNotEmpty ? (100 * math.max(0.0, used - kept) / (out.length * designDay)).clamp(0.0, 300.0).toDouble() : null;
  return AreaForecast(
    areaId: a.id,
    name: name,
    cropKey: a.cropKey,
    balance: true,
    rateMmH: rate,
    programmeNetMm: eventNet,
    programmeGrossMm: eventGross,
    programmeHours: eventHours,
    intervalDays: interval,
    designNetMmDay: designDay,
    startDepletionMm: dr0,
    days: out,
    budgetPct: budget,
    warnings: warnings,
  );
}

String _d10(DateTime d) => d.toIso8601String().substring(0, 10);

/// The name of growth stage [stage] (−1: no crop).
String forecastStageName(int stage, Translate t) => stage >= 0 && stage < 4 ? t('fst.stage.${fertStageNames[stage]}') : t('fct.offSeason');

/// The tables of [plan] in the units [u]: the plan (the days as columns: the ETo and the rain of each day, then the
/// run time of every area, or "skip") and the day-by-day detail.
List<ReportTable> forecastTables(ForecastPlan plan, ReportLabels labels, Units u) {
  final t = labels.t;
  final dl = u.depthLabel;
  RNum depth(double mm, [int d = 1]) => RNum(u.depthFromMm(mm), d);
  final dates = [for (final d in plan.days) '${_d10(d.date)}${d.estimated ? '*' : ''}'];
  Object cell(AreaForecast a, AreaForecastDay d) {
    if (!d.irrigate) return t('fct.skip');
    if (d.runHours != null) return RNum(60 * d.runHours!, 0);
    return '${fmt(u.depthFromMm(d.grossMm), 1)} $dl';
  }

  final grid = ReportTable(
    key: 'irrigationForecast',
    title: t('fct.table.plan'),
    headers: [t('rep.area'), '${t('fct.programme')} (min)', '${t('fct.budget')} (%)', ...dates],
    rows: [
      ['ETo ($dl)', '-', '-', for (final d in plan.days) depth(d.etoMm)],
      ['${t('req.rain')} ($dl)', '-', '-', for (final d in plan.days) depth(d.rainMm)],
      for (final a in plan.areas)
        [
          a.name,
          a.programmeHours == null ? '-' : RNum(60 * a.programmeHours!, 0),
          a.budgetPct == null ? '-' : RNum(a.budgetPct!, 0),
          if (!a.balance)
            for (final _ in plan.days) '-'
          else
            for (final d in a.days) cell(a, d),
        ],
    ],
    ids: [null, null, for (final a in plan.areas) a.areaId],
    warn: [false, false, for (final a in plan.areas) a.warnings.isNotEmpty],
  );
  final detail = ReportTable(
    key: 'irrigationForecastDays',
    title: t('fct.table.days'),
    headers: [
      t('sch.date'),
      t('rep.area'),
      t('fst.stage'),
      'Kc',
      'ETo ($dl)',
      'ETc ($dl)',
      '${t('req.effRain')} ($dl)',
      '${t('swb.depletion')} ($dl)',
      t('fct.decision'),
      '${t('req.net')} ($dl)',
      '${t('req.gross')} ($dl)',
      '${t('fct.runTime')} (min)',
      '${t('fct.ofEvent')} (%)',
    ],
    rows: [
      for (final a in plan.areas)
        if (a.balance)
          for (var i = 0; i < a.days.length; i++)
            [
              _d10(a.days[i].date),
              a.name,
              forecastStageName(a.days[i].stage, t),
              RNum(a.days[i].kc, 2),
              depth(plan.days[i].etoMm),
              depth(a.days[i].etcMm),
              depth(a.days[i].effectiveRainMm),
              depth(a.days[i].depletionMm),
              a.days[i].irrigate ? t('fct.irrigate') : t('fct.skip'),
              depth(a.days[i].netMm),
              depth(a.days[i].grossMm),
              a.days[i].runHours == null ? '-' : RNum(60 * a.days[i].runHours!, 0),
              a.days[i].eventPct == null ? '-' : RNum(a.days[i].eventPct!, 0),
            ],
    ],
    ids: [
      for (final a in plan.areas)
        if (a.balance)
          for (final _ in a.days) a.areaId,
    ],
  );
  return [grid, detail];
}
