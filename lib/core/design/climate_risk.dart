/// Climate risk over the years (1.7.0 CLR): how the system as designed would
/// have done in each of the last thirty to forty real years, instead of the
/// one design figure (a peak ETo or a monthly normal) it was sized for.
///
/// Method:
/// - the weather is a daily series of the site: the NASA POWER daily point
///   series (MERRA-2 meteorology and GEWEX SRB / CERES solar data, every
///   parameter from 1984; climate_online.dart downloads it) or the daily
///   series kept with the site climate (a station file or an earlier
///   download). The reference evapotranspiration of each day is the FAO
///   Penman-Monteith ETo (Allen, Pereira, Raes & Smith 1998, FAO Irrigation
///   and Drainage Paper 56, eq. 6, missing humidity, radiation and wind
///   estimated as its chapter 3 says; `dailyPenmanMonteith` of
///   inmet_csv.dart);
/// - every irrigated area with a water balance runs, season by season, the
///   daily soil water balance of FAO-56 chapter 8 (soil_water_balance.dart,
///   the same inputs as Design → Agronomy → Daily water balance: crop, Kc
///   curve, planting date, soil, p, Kr, Pw, efficiency and leaching), twice:
///   with no limit, which gives the irrigation requirement of the season,
///   and with the gross depth the designed system can apply a day
///   ([areaDailyCapacity]), which gives what it would have applied and the
///   crop days the depletion stayed above the allowed depletion (the RAW,
///   or the regulated deficit of the stage): the deficit days. A season
///   with none is reliable;
/// - the peak-period demand of a season is the largest mean, over
///   [ClimateRiskSummary.peakDays] consecutive days, of ETc,loc less the rain
///   the root zone kept (effective rain less deep percolation), over the
///   gross/net factor of the month; the peak-period ETo the largest mean ETo
///   over as many days;
/// - the yearly values are ranked with Weibull plotting positions and their
///   probabilities read by interpolation (climate_risk_stats.dart); the
///   trend is Sen's slope with the Mann-Kendall test;
/// - crops in the field all year, and the site's own figures, run by
///   irrigation year: from the first day of the month whose mean rain most
///   exceeds its mean ETo, so the soil may start at field capacity and the
///   dry season of either hemisphere falls inside one year; seasonal crops
///   from their planting day, the season running into the next year when it
///   is long or planted late (both labelled by the year they start);
/// - days without ETo take the series' own mean ETo of their month, days
///   without rain count as dry for the balance; a season or year with more
///   than a tenth of its days filled is left out; the longest dry spell is
///   the ETCCDI index CDD, the most consecutive days with less than 1 mm of
///   rain (Karl, Nicholls & Ghazi 1999; Zhang et al. 2011), a missing day
///   ending the spell.
///
/// Reanalysis data are means over cells of tens of kilometres: they smooth
/// the local extremes (peak ETo, dry spells, intense rain) a station on the
/// site would show.
library;

import 'dart:math' as math;

import '../io/climate_online.dart' show ClimateSeries;
import '../io/inmet_csv.dart' show dailyPenmanMonteith;
import '../model/agronomy_plan.dart';
import '../model/climate_risk_summary.dart';
import '../model/entities.dart';
import '../model/project.dart';
import '../model/site_climate.dart';
import '../units.dart';
import 'agronomy.dart' show areasOfMachine;
import 'area_water.dart';
import 'climate.dart' show daysInMonth;
import 'climate_risk_stats.dart';
import 'designer.dart' show areaRequirements;
import 'permit.dart' show areaMonthlyNeed;
import 'report_tables.dart';
import 'results.dart';
import 'soil_water_balance.dart';
import 'system_capacity.dart';

export '../model/climate_risk_summary.dart';

/// First year of the NASA POWER daily series used: solar radiation (and so
/// the Penman-Monteith ETo from measured radiation) starts on 1 January
/// 1984; the meteorology goes back to 1981.
const climateRiskFirstYear = 1984;

/// Lengths of the peak period offered (days); 30 compares with the monthly
/// normals the design uses.
const climateRiskPeakDays = [7, 10, 15, 30];

/// Non-exceedance probabilities shown.
const climateRiskLevels = [0.5, 0.8, 0.9, 0.95];

/// Most of a season or year that may be filled (missing days).
const maxFilledShare = 0.1;

/// A day with less rain than this (mm) is dry (ETCCDI CDD).
const dryDayRainMm = 1.0;

/// The daily series of the analysis: ETo and rain a day from [start], NaN
/// where the day has none.
class RiskSeries {
  RiskSeries({required DateTime start, required List<double> eto, required List<double> rain, this.source = '', this.attribution = '', this.latitudeDeg = 0, this.longitudeDeg = 0})
    : start = DateTime.utc(start.year, start.month, start.day),
      eto = List.unmodifiable(eto.sublist(0, math.min(eto.length, rain.length))),
      rain = List.unmodifiable(rain.sublist(0, math.min(eto.length, rain.length))) {
    // the series' own mean ETo of every month fills the days without one
    final sum = List<double>.filled(12, 0), n = List<int>.filled(12, 0);
    for (var i = 0; i < length; i++) {
      if (!this.eto[i].isFinite) continue;
      final m = dateAt(i).month - 1;
      sum[m] += this.eto[i];
      n[m]++;
    }
    final all = n.fold(0, (a, b) => a + b);
    final mean = all == 0 ? 0.0 : sum.fold(0.0, (a, b) => a + b) / all;
    monthlyEto = [for (var m = 0; m < 12; m++) n[m] > 0 ? sum[m] / n[m] : mean];
    hasEto = all > 0;
  }

  /// The days of a download: ETo by FAO-56 Penman-Monteith of each day
  /// (`dailyPenmanMonteith`), one value a day from the first to the last.
  factory RiskSeries.ofClimateSeries(ClimateSeries s, {String attribution = ''}) {
    final days = [...s.days]..sort((a, b) => a.date.compareTo(b.date));
    if (days.isEmpty) return RiskSeries(start: DateTime.utc(2000), eto: const [], rain: const [], source: s.source.name, attribution: attribution);
    final first = DateTime.utc(days.first.date.year, days.first.date.month, days.first.date.day);
    final last = DateTime.utc(days.last.date.year, days.last.date.month, days.last.date.day);
    final n = last.difference(first).inDays + 1;
    final eto = List<double>.filled(n, double.nan), rain = List<double>.filled(n, double.nan);
    for (final d in days) {
      final i = DateTime.utc(d.date.year, d.date.month, d.date.day).difference(first).inDays;
      final e = d.etoMmDay ?? dailyPenmanMonteith(d, latitudeDeg: s.latitudeDeg, elevationM: s.elevationM ?? 0);
      if (e != null && e.isFinite && e >= 0) eto[i] = e;
      final r = d.rainMm;
      if (r != null && r.isFinite) rain[i] = math.max(r, 0.0);
    }
    return RiskSeries(start: first, eto: eto, rain: rain, source: s.source.name, attribution: attribution, latitudeDeg: s.latitudeDeg, longitudeDeg: s.longitudeDeg);
  }

  /// The daily ETo and rain kept with the site climate.
  factory RiskSeries.ofDaily(DailyClimate d, {String attribution = '', double latitudeDeg = 0, double longitudeDeg = 0}) =>
      RiskSeries(start: d.start, eto: d.etoMm, rain: d.rainMm, source: d.source, attribution: attribution, latitudeDeg: latitudeDeg, longitudeDeg: longitudeDeg);

  final DateTime start;
  final List<double> eto;
  final List<double> rain;
  final String source;
  final String attribution;
  final double latitudeDeg, longitudeDeg;

  /// Mean ETo of every month in the series (mm/day), January first.
  late final List<double> monthlyEto;
  late final bool hasEto;

  int get length => eto.length;
  DateTime dateAt(int i) => start.add(Duration(days: i));
  DateTime get end => dateAt(length);

  /// Index of [date] (may be outside the series).
  int indexOf(DateTime date) => DateTime.utc(date.year, date.month, date.day).difference(start).inDays;

  bool missing(int i) => !eto[i].isFinite || !rain[i].isFinite;
  double etoAt(int i) => eto[i].isFinite ? eto[i] : monthlyEto[dateAt(i).month - 1];
  double rainAt(int i) => rain[i].isFinite ? rain[i] : 0.0;

  /// Days of [i0]..[i1] (exclusive) whose ETo or rain is missing.
  int gaps(int i0, int i1) {
    var n = 0;
    for (var i = i0; i < i1; i++) {
      if (missing(i)) n++;
    }
    return n;
  }
}

/// The month the irrigation year of [s] starts: the one whose mean rain
/// most exceeds its mean ETo (the least ETo − rain; 1 without data).
int waterYearStartMonth(RiskSeries s) {
  final eto = List<double>.filled(12, 0), rain = List<double>.filled(12, 0);
  final ne = List<int>.filled(12, 0), nr = List<int>.filled(12, 0);
  for (var i = 0; i < s.length; i++) {
    final m = s.dateAt(i).month - 1;
    if (s.eto[i].isFinite) {
      eto[m] += s.eto[i];
      ne[m]++;
    }
    if (s.rain[i].isFinite) {
      rain[m] += s.rain[i];
      nr[m]++;
    }
  }
  var best = 1;
  var bestV = double.infinity;
  for (var m = 0; m < 12; m++) {
    if (ne[m] == 0 || nr[m] == 0) continue;
    final days = daysInMonth(2001, m + 1);
    final v = (eto[m] / ne[m] - rain[m] / nr[m]) * days;
    if (v < bestV - 1e-9) {
      bestV = v;
      best = m + 1;
    }
  }
  return best;
}

/// Largest mean of [values] over [window] consecutive values (the whole
/// list when it is shorter; 0 when empty).
double peakMean(List<double> values, int window) {
  if (values.isEmpty) return 0;
  final w = window.clamp(1, values.length);
  var sum = 0.0;
  for (var i = 0; i < w; i++) {
    sum += values[i];
  }
  var best = sum;
  for (var i = w; i < values.length; i++) {
    sum += values[i] - values[i - w];
    if (sum > best) best = sum;
  }
  return best / w;
}

/// The longest run of dry days (rain below [dryDayRainMm]) of [s] in
/// [i0]..[i1] (exclusive), a missing day ending it: (days, first index).
(int, int) longestDrySpell(RiskSeries s, int i0, int i1) {
  var best = 0, bestAt = i0, run = 0, runAt = i0;
  for (var i = i0; i < i1; i++) {
    final r = s.rain[i];
    if (r.isFinite && r < dryDayRainMm) {
      if (run == 0) runAt = i;
      run++;
      if (run > best) {
        best = run;
        bestAt = runAt;
      }
    } else {
      run = 0;
    }
  }
  return (best, bestAt);
}

/// The gross depth (mm/day) the designed system can apply on each area, by
/// area id (areas without a known capacity are left out):
/// - an area under a centre pivot or linear move: the machine's depth per
///   cycle over the hours of a cycle, times the hours of the programme's
///   window (system_capacity.dart);
/// - any other area: the application rate of its emitters over the area
///   (mm/h; designer.dart `areaRequirements`, the flows of the design when
///   given, else the nominal ones) times the hours its system flow may run:
///   the flows run one after another, so the window is shared among them
///   in proportion to the hours each needs on the design's peak day (every
///   flow then has the same share of spare time); without system flows
///   every zone runs the whole window.
Map<String, double> areaDailyCapacity(Project p, DesignResults? results, {SystemCapacity? capacity}) {
  final cap = capacity ?? systemCapacity(p, results: results);
  final out = <String, double>{};
  final machineAreas = <String>{};
  for (final m in cap.machines) {
    final e = p.byId(m.pivotId);
    if (e is! PivotEntity) continue;
    for (final a in areasOfMachine(p, e)) {
      machineAreas.add(a.id);
      out[a.id] = math.min(out[a.id] ?? double.infinity, m.capacityMmDay);
    }
  }
  final total = cap.totalHours, window = cap.windowHours;
  final hours = <String, double>{};
  for (final f in cap.flows) {
    final share = total > 0 ? window * f.hours / total : window;
    for (final id in f.areaIds) {
      hours[id] = math.max(hours[id] ?? 0, share);
    }
  }
  for (final r in areaRequirements(p, results)) {
    if (machineAreas.contains(r.areaId) || r.precipitationMmH <= 0 || r.machineFlow > 0.5 * r.flow) continue;
    final h = hours[r.areaId];
    if (h == null) continue;
    out[r.areaId] = r.precipitationMmH * h;
  }
  return out;
}

BalanceInput _withWeather(BalanceInput b, List<BalanceWeather> weather, {DateTime? yearStart, double? maxGrossMmDay}) => BalanceInput(
  weather: weather,
  cyclic: false,
  curve: b.curve,
  planting: b.planting,
  repeatsYearly: b.repeatsYearly,
  kr: b.kr,
  wettedFraction: b.wettedFraction,
  awcMmPerM: b.awcMmPerM,
  rootDepthM: b.rootDepthM,
  depletionFraction: b.depletionFraction,
  adjustDepletionToEtc: b.adjustDepletionToEtc,
  efficiency: b.efficiency,
  grossFactorByMonth: b.grossFactorByMonth,
  settings: b.settings,
  ky: b.ky,
  maxGrossMmDay: maxGrossMmDay,
  yearStart: yearStart,
);

/// Crop days of [r] whose depletion at the end of the day is above the
/// allowed depletion of [s] (the stage's share of TAW, else the RAW).
int deficitDaysOf(BalanceResult r, BalanceSettings s) {
  var n = 0;
  for (final d in r.days) {
    if (d.kc <= 0 || d.stage < 0) continue;
    final allowed = d.stage < 4 && s.allowedDepletion[d.stage] > 0 ? s.allowedDepletion[d.stage] * d.tawMm : d.rawMm;
    if (d.depletionMm > allowed + 1e-6) n++;
  }
  return n;
}

/// The gross/net factor of [month] (1–12) of [b] (the requirement table's,
/// else 1/Ea), as the balance takes it.
double _factor(BalanceInput b, int month) {
  final f = b.grossFactorByMonth;
  if (f != null && f[month - 1] > 0) return f[month - 1];
  return 1 / b.efficiency.clamp(0.05, 1.0);
}

/// Largest mean gross demand (mm/day) over [window] consecutive days of the
/// unlimited balance [r]: ETc,loc less the rain kept in the root zone
/// (effective rain less deep percolation), at least 0, over the gross/net
/// factor of the middle day's month.
double peakGrossDemand(BalanceResult r, BalanceInput b, int window) {
  final days = r.days;
  if (days.isEmpty) return 0;
  final w = window.clamp(1, days.length);
  final need = [for (final d in days) d.etcMm - math.max(d.effectiveRainMm - d.deepPercolationMm, 0.0)];
  var sum = 0.0;
  for (var i = 0; i < w; i++) {
    sum += need[i];
  }
  var best = 0.0;
  for (var i = w - 1; i < days.length; i++) {
    if (i >= w) sum += need[i] - need[i - w];
    final mid = days[i - w ~/ 2].date.month;
    final g = math.max(sum, 0.0) / w * _factor(b, mid);
    if (g > best) best = g;
  }
  return best;
}

/// The climate risk of [p] over the years of [series] (see the library
/// notes): [probability] the non-exceedance probability of the design
/// values, [peakDays] the length of the peak period, [results] the design
/// (its flows for the capacity; nominal flows without it), [today] the date
/// written in it.
ClimateRiskSummary climateRiskAnalysis(Project p, RiskSeries series, {DesignResults? results, double probability = 0.8, int peakDays = 30, DateTime? today}) {
  final warnings = <String>[];
  final now = today ?? DateTime.now();
  final m0 = waterYearStartMonth(series);
  final window = peakDays.clamp(1, 92);
  // ---- the site, irrigation year by irrigation year
  final site = <ClimateRiskSiteYear>[];
  if (series.length > 0) {
    for (var y = series.start.year - 1; y <= series.end.year; y++) {
      final i0 = series.indexOf(DateTime.utc(y, m0)), i1 = series.indexOf(DateTime.utc(y + 1, m0));
      if (i0 < 0 || i1 > series.length) continue;
      final filled = series.gaps(i0, i1);
      if (filled > maxFilledShare * (i1 - i0)) continue;
      final eto = [for (var i = i0; i < i1; i++) series.etoAt(i)];
      var rain = 0.0;
      for (var i = i0; i < i1; i++) {
        rain += series.rainAt(i);
      }
      final (dry, at) = longestDrySpell(series, i0, i1);
      site.add(
        ClimateRiskSiteYear(
          year: y,
          etoMm: eto.fold(0.0, (a, b) => a + b),
          rainMm: rain,
          peakEtoMmDay: peakMean(eto, window),
          drySpellDays: dry,
          drySpellStart: dry > 0 ? series.dateAt(at) : null,
          filledDays: filled,
        ),
      );
    }
  }
  if (!series.hasEto) warnings.add('clr_no_eto');
  if (site.length < minTrendYears) warnings.add('clr_short');
  // ---- the areas, season by season
  final capacity = systemCapacity(p, results: results);
  final caps = areaDailyCapacity(p, results, capacity: capacity);
  final areas = <ClimateRiskArea>[];
  final byYear = <int, ({double req, double pumped, Set<int> days, int inDeficit, int count})>{};
  for (final a in p.entities.whereType<AreaEntity>()) {
    if (a.points.length < 3) continue;
    if (!a.useWaterBalance) {
      warnings.add('clr_fixed:${a.id}');
      continue;
    }
    final aw = <String>[];
    final s = balanceSettingsOf(p, a).copy()..year = 0;
    if (s.trigger == BalanceTrigger.rainfed) {
      s.trigger = BalanceTrigger.depletion;
      aw.add('clr_rainfed');
    }
    final base = balanceInputOf(p, a, settings: s);
    if (base == null) continue;
    if ((requirementInputOf(p, a)?.cycles.length ?? 0) > 1) aw.add('clr_cycles');
    final cap = caps[a.id];
    if (cap == null) aw.add('clr_no_capacity');
    final seasonLength = base.curve.seasonDays;
    final yearRound = seasonLength >= 365 - 1e-9;
    final startMonth = yearRound ? m0 : base.planting.month, startDay = yearRound ? 1 : base.planting.day;
    final seasons = <ClimateRiskSeason>[];
    if (series.hasEto && series.length > 0) {
      for (var y = series.start.year - 1; y <= series.end.year; y++) {
        final start = DateTime.utc(y, startMonth, startDay);
        final end = yearRound ? DateTime.utc(y + 1, startMonth, startDay) : start.add(Duration(days: seasonLength.ceil()));
        final i0 = series.indexOf(start), i1 = series.indexOf(end);
        if (i0 < 0 || i1 > series.length || i1 <= i0) continue;
        final filled = series.gaps(i0, i1);
        if (filled > maxFilledShare * (i1 - i0)) continue;
        final weather = [for (var i = i0; i < i1; i++) BalanceWeather(series.dateAt(i), series.etoAt(i), series.rainAt(i))];
        final free = soilWaterBalance(_withWeather(base, weather, yearStart: yearRound ? start : null));
        if (free.days.isEmpty) continue;
        final limited = cap == null ? free : soilWaterBalance(_withWeather(base, weather, yearStart: yearRound ? start : null, maxGrossMmDay: cap));
        final deficit = deficitDaysOf(limited, s);
        seasons.add(
          ClimateRiskSeason(
            year: y,
            grossMm: free.grossMm,
            netMm: free.netMm,
            appliedGrossMm: limited.grossMm,
            peakGrossMmDay: peakGrossDemand(free, base, window),
            peakEtoMmDay: peakMean([for (final d in free.days) d.etoMm], window),
            deficitDays: deficit,
            filledDays: filled,
          ),
        );
        // the project's year: every area's season that starts in it
        final days = <int>{};
        for (var k = 0; k < limited.days.length; k++) {
          final d = limited.days[k];
          if (d.kc <= 0 || d.stage < 0) continue;
          final allowed = d.stage < 4 && s.allowedDepletion[d.stage] > 0 ? s.allowedDepletion[d.stage] * d.tawMm : d.rawMm;
          if (d.depletionMm > allowed + 1e-6) days.add(series.indexOf(d.date));
        }
        final cur = byYear[y];
        byYear[y] = (
          req: (cur?.req ?? 0) + free.grossMm / 1000 * a.area,
          pumped: (cur?.pumped ?? 0) + limited.grossMm / 1000 * a.area,
          days: {...?cur?.days, ...days},
          inDeficit: (cur?.inDeficit ?? 0) + (deficit > 0 ? 1 : 0),
          count: (cur?.count ?? 0) + 1,
        );
      }
    }
    if (seasons.isEmpty) aw.add('clr_no_seasons');
    final basis = areaWaterBasis(p, a);
    areas.add(
      ClimateRiskArea(
        areaId: a.id,
        name: a.name.isEmpty ? a.id : a.name,
        areaM2: a.area,
        capacityGrossMmDay: cap,
        designEtoMmDay: basis.etoMmDay,
        designPeakGrossMmDay: basis.grossMmDay,
        designYearGrossMm: a.area > 0 ? areaMonthlyNeed(p, a).annualM3 / a.area * 1000 : 0,
        startMonth: startMonth,
        startDay: startDay,
        seasonDays: yearRound ? 365 : seasonLength.ceil(),
        seasons: seasons,
        warnings: aw,
      ),
    );
  }
  if (areas.isEmpty) warnings.add('clr_no_areas');
  final withSeasons = areas.where((a) => a.seasons.isNotEmpty).length;
  final project = [
    for (final y in byYear.keys.toList()..sort())
      ClimateRiskProjectYear(
        year: y,
        requirementM3: byYear[y]!.req,
        pumpedM3: byYear[y]!.pumped,
        deficitDays: byYear[y]!.days.length,
        areasInDeficit: byYear[y]!.inDeficit,
        complete: byYear[y]!.count >= withSeasons,
      ),
  ];
  final c = p.climate;
  String two(int v) => v.toString().padLeft(2, '0');
  return ClimateRiskSummary(
    source: series.source,
    attribution: series.attribution,
    latitudeDeg: series.latitudeDeg,
    longitudeDeg: series.longitudeDeg,
    firstYear: series.length > 0 ? series.start.year : 0,
    lastYear: series.length > 0 ? series.dateAt(series.length - 1).year : 0,
    computed: '${now.year}-${two(now.month)}-${two(now.day)}',
    probability: probability.clamp(0.5, 0.99).toDouble(),
    peakDays: window,
    startMonth: m0,
    windowHours: capacity.windowHours,
    projectEtoMmDay: c?.etoMmDay.fold<double>(0.0, math.max),
    site: site,
    areas: areas,
    project: project,
    warnings: warnings,
  );
}

// ---------------------------------------------------------------- report tables

String _n(double v, int d) => fmt(v, d);

/// The report tables of the climate risk kept in [p] (none when it has
/// none): the distribution of the yearly figures of the project and of
/// each area beside the figure the design uses (`climateRisk`), and the
/// figures year by year (`climateRiskYears`).
List<ReportTable> climateRiskTables(Project p, ReportLabels labels) {
  final s = p.climateRisk;
  if (s == null) return const [];
  final t = labels.t;
  final u = p.params.units;
  final rows = <List<Object>>[];
  final warn = <bool>[];
  final ids = <String?>[];
  final dl = u.depthLabel, dd = u.depthPerDayLabel, vl = u.volumeLabel;
  void row(String who, String? id, String quantity, List<double> xs, double Function(double) conv, int dec, {double? project, String note = '', bool warning = false}) {
    if (xs.isEmpty) return;
    rows.add([who, quantity, for (final f in climateRiskLevels) RNum(conv(quantileAt(xs, f)!), dec), RNum(conv(xs.reduce(math.max)), dec), project == null ? '-' : RNum(conv(project), dec), note]);
    warn.add(warning);
    ids.add(id);
  }

  String exceeded(List<double> xs, double? x) => x == null || x <= 0 ? '' : t('clr.exceeded', {'k': '${countAbove(xs, x)}', 'n': '${xs.length}'});
  String trend(List<int> years, List<double> xs, String unit, double Function(double) conv, int dec) {
    final tr = senMannKendall(years, xs);
    if (tr == null) return '';
    final v = conv(tr.slopePerDecade);
    return t('clr.trend', {'v': '${v >= 0 ? '+' : ''}${_n(v, dec)} $unit', 's': t(tr.significant ? 'clr.trend.sig' : 'clr.trend.ns')});
  }

  String reliability(int k, int n) => n == 0 ? '' : t('clr.reliability', {'k': '$k', 'n': '$n', 'p': _n(100 * k / n, 0)});
  final peakLabel = t('clr.q.peak', {'n': '${s.peakDays}'});
  final etoLabel = t('clr.q.eto', {'n': '${s.peakDays}'});
  // ---- the project and its site
  final who = t('clr.project');
  final years = [for (final y in s.site) y.year];
  final peakEto = [for (final y in s.site) y.peakEtoMmDay];
  row(
    who,
    null,
    '$etoLabel ($dd)',
    peakEto,
    u.depthFromMm,
    2,
    project: s.projectEtoMmDay,
    note: exceeded(peakEto, s.projectEtoMmDay),
    warning: s.projectEtoMmDay != null && (quantileAt(peakEto, s.probability) ?? 0) > s.projectEtoMmDay!,
  );
  row(who, null, 'ETo ($dl)', [for (final y in s.site) y.etoMm], u.depthFromMm, 0, note: trend(years, [for (final y in s.site) y.etoMm], dl, u.depthFromMm, 0));
  row(who, null, '${t('req.rain')} ($dl)', [for (final y in s.site) y.rainMm], u.depthFromMm, 0, note: trend(years, [for (final y in s.site) y.rainMm], dl, u.depthFromMm, 0));
  final dry = [for (final y in s.site) y.drySpellDays.toDouble()];
  final worstDry = s.site.isEmpty ? null : s.site.reduce((a, b) => b.drySpellDays > a.drySpellDays ? b : a);
  row(
    who,
    null,
    '${t('clr.q.dry')} (d)',
    dry,
    (x) => x,
    0,
    note: worstDry?.drySpellStart == null ? '' : t('clr.drySpell', {'n': '${worstDry!.drySpellDays}', 'd': worstDry.drySpellStart!.toIso8601String().substring(0, 10)}),
  );
  final full = s.project.where((y) => y.complete).toList();
  final designM3 = s.areas.fold(0.0, (a, x) => a + x.designYearGrossMm / 1000 * x.areaM2);
  row(
    who,
    null,
    '${t('clr.q.volume')} ($vl)',
    [for (final y in full) y.requirementM3],
    u.volumeFromM3,
    0,
    project: designM3 > 0 ? designM3 : null,
    note: trend([for (final y in full) y.year], [for (final y in full) y.requirementM3], vl, u.volumeFromM3, 0),
  );
  row(who, null, '${t('clr.q.pumped')} ($vl)', [for (final y in full) y.pumpedM3], u.volumeFromM3, 0, project: designM3 > 0 ? designM3 : null);
  final ok = full.where((y) => y.deficitDays == 0).length;
  row(who, null, '${t('clr.q.deficit')} (d)', [for (final y in full) y.deficitDays.toDouble()], (x) => x, 0, note: reliability(ok, full.length), warning: ok < full.length);
  // ---- every area
  for (final a in s.areas) {
    if (a.seasons.isEmpty) continue;
    row(
      a.name,
      a.areaId,
      '${t('clr.q.gross')} ($dl)',
      a.grossMm,
      u.depthFromMm,
      0,
      project: a.designYearGrossMm > 0 ? a.designYearGrossMm : null,
      note: [exceeded(a.grossMm, a.designYearGrossMm), trend(a.years, a.grossMm, dl, u.depthFromMm, 0)].where((x) => x.isNotEmpty).join(' · '),
    );
    final cap = a.capacityGrossMmDay;
    row(
      a.name,
      a.areaId,
      '$peakLabel ($dd)',
      a.peakGrossMmDay,
      u.depthFromMm,
      2,
      project: a.designPeakGrossMmDay > 0 ? a.designPeakGrossMmDay : null,
      note: [
        exceeded(a.peakGrossMmDay, a.designPeakGrossMmDay),
        cap == null ? t('clr.capacityUnknown') : t('clr.capacity', {'v': '${_n(u.depthFromMm(cap), 2)} $dd'}),
      ].where((x) => x.isNotEmpty).join(' · '),
      warning: cap != null && (quantileAt(a.peakGrossMmDay, s.probability) ?? 0) > cap,
    );
    row(a.name, a.areaId, '$etoLabel ($dd)', a.peakEtoMmDay, u.depthFromMm, 2, project: a.designEtoMmDay > 0 ? a.designEtoMmDay : null, note: exceeded(a.peakEtoMmDay, a.designEtoMmDay));
    row(a.name, a.areaId, '${t('clr.q.pumped')} ($vl)', a.pumpedM3, u.volumeFromM3, 0, project: a.designYearGrossMm > 0 ? a.designYearGrossMm / 1000 * a.areaM2 : null);
    row(a.name, a.areaId, '${t('clr.q.deficit')} (d)', a.deficitDays, (x) => x, 0, note: reliability(a.reliableSeasons, a.seasons.length), warning: a.reliableSeasons < a.seasons.length);
  }
  final out = <ReportTable>[];
  if (rows.isNotEmpty) {
    out.add(
      ReportTable(
        key: 'climateRisk',
        title: t('clr.tbl.stats'),
        headers: [t('rep.area'), t('clr.col.quantity'), for (final f in climateRiskLevels) 'P${(f * 100).round()}', t('clr.col.max'), t('clr.col.project'), t('clr.col.note')],
        rows: rows,
        warn: warn,
        ids: ids,
      ),
    );
  }
  // ---- year by year
  final siteBy = {for (final y in s.site) y.year: y};
  final projBy = {for (final y in s.project) y.year: y};
  final all = {...siteBy.keys, ...projBy.keys}.toList()..sort();
  final crosses = s.siteCrossesYear || s.areas.any((a) => a.crossesYear);
  if (all.isNotEmpty) {
    out.add(
      ReportTable(
        key: 'climateRiskYears',
        title: t('clr.tbl.years'),
        headers: [
          t('clr.col.year'),
          'ETo ($dl)',
          '${t('req.rain')} ($dl)',
          '$etoLabel ($dd)',
          '${t('clr.q.dry')} (d)',
          '${t('clr.q.volume')} ($vl)',
          '${t('clr.q.pumped')} ($vl)',
          '${t('clr.q.deficit')} (d)',
          t('clr.col.areas'),
        ],
        rows: [
          for (final y in all)
            [
              ClimateRiskSummary.yearLabel(y, crosses: crosses),
              siteBy[y] == null ? '-' : RNum(u.depthFromMm(siteBy[y]!.etoMm), 0),
              siteBy[y] == null ? '-' : RNum(u.depthFromMm(siteBy[y]!.rainMm), 0),
              siteBy[y] == null ? '-' : RNum(u.depthFromMm(siteBy[y]!.peakEtoMmDay), 2),
              siteBy[y] == null ? '-' : siteBy[y]!.drySpellDays,
              projBy[y] == null || !projBy[y]!.complete ? '-' : RNum(u.volumeFromM3(projBy[y]!.requirementM3), 0),
              projBy[y] == null || !projBy[y]!.complete ? '-' : RNum(u.volumeFromM3(projBy[y]!.pumpedM3), 0),
              projBy[y] == null ? '-' : projBy[y]!.deficitDays,
              projBy[y] == null ? '-' : projBy[y]!.areasInDeficit,
            ],
        ],
        warn: [for (final y in all) (projBy[y]?.deficitDays ?? 0) > 0],
      ),
    );
  }
  return out;
}
