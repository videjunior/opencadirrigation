/// Irrigation requirement tables of an irrigated area, per crop cycle and
/// per month (of a typical year) or per user-defined period: ETo, Kc, ETc,
/// effective rain, net depth, leaching requirement, gross depth, readily
/// available water, maximum interval, depth and hours per event, volumes.
/// This is the content water-permit applications ask for ("lâmina líquida e
/// bruta por cultura e por período"): every crop cycle keeps its own Kc and
/// rows, Kc is never averaged across crops, and only depths and volumes are
/// added up.
///
/// Method and sources:
/// - ETc = Kc·ETo with the FAO-56 single crop coefficient curve (crops.dart),
///   reduced for localized irrigation by Kr (ETc,loc = Kr·ETc; Keller &
///   Bliesner 1990; FAO Irrigation Manual Module 9 eq. 2);
/// - effective rain per month of crop days (effective_rain.dart), prorated
///   by days for months the crop occupies only in part;
/// - net depth = ETc,loc − Pe (+ percolation and the initial saturation and
///   water layer of paddy rice, Brouwer & Heibloem 1986, FAO Training Manual
///   3, section 4.4);
/// - leaching requirement: LR = ECw/(5·ECe − ECw) for surface and sprinkler
///   irrigation (Ayers & Westcot 1985, FAO-29 eq. 9, ECe for the chosen
///   yield potential from Table 4), LR = ECw/(2·max ECe) for high-frequency
///   drip (Keller & Bliesner 1990, max ECe = zero-yield ECe of FAO-29
///   Table 4); gross = net/(Ea·(1 − LR)), or, by the reasoning of FAO-29
///   Example 3 (application losses already leach), max(net/Ea, net/(1 − LR));
/// - TAW = AWC·Zr (FAO-56 eq. 82), RAW = p·TAW (eq. 83) with p adjusted to
///   ETc (Table 22 note 2), times the wetted fraction Pw for localized
///   irrigation; maximum interval = RAW / net daily depth.
///
/// Depths are over the whole area of the irrigated area (mm = L/m²), and the
/// application rate is the system flow over that area (mm/h).
library;

import 'dart:math' as math;

import 'climate.dart';
import 'crops.dart';
import 'effective_rain.dart';

/// Leaching requirement formula.
enum LeachingFormula {
  /// FAO-29 eq. 9: LR = ECw/(5·ECe − ECw).
  surfaceSprinkler,

  /// Keller & Bliesner (1990): LR = ECw/(2·max ECe).
  highFrequencyDrip,
}

/// How the leaching requirement enters the gross depth.
enum LeachingRule {
  /// gross = net/(Ea·(1 − LR)).
  multiplicative,

  /// gross = max(net/Ea, net/(1 − LR)): losses of application leach too
  /// (FAO-29 Example 3).
  lossesLeach,
}

/// Leaching requirement LR (fraction, 0 without salinity) for the salinity
/// of the irrigation water ECw and of the soil saturation extract ECe (dS/m).
/// For [LeachingFormula.highFrequencyDrip] pass the zero-yield ECe as
/// [eceDsM]. Null when the water is too saline for the crop (5·ECe ≤ ECw).
double? leachingRequirement({required double ecwDsM, required double eceDsM, LeachingFormula formula = LeachingFormula.surfaceSprinkler}) {
  if (ecwDsM <= 0) return 0;
  if (eceDsM <= 0) return null;
  switch (formula) {
    case LeachingFormula.surfaceSprinkler:
      final d = 5 * eceDsM - ecwDsM;
      if (d <= 0) return null;
      final lr = ecwDsM / d;
      return lr < 1 ? lr : null;
    case LeachingFormula.highFrequencyDrip:
      final lr = ecwDsM / (2 * eceDsM);
      return lr < 1 ? lr : null;
  }
}

/// Soil salinity ECe (dS/m) for a yield potential (%), on the straight line
/// between the threshold (100 %) and the zero-yield ECe (FAO-29 eq. 10 and
/// Table 4).
double eceForYieldPotential({required double eceThreshold, required double eceMax, double yieldPct = 100}) => eceThreshold + (eceMax - eceThreshold) * (100 - yieldPct.clamp(0.0, 100.0)) / 100;

/// Monthly climate normals for the requirement: mean ETo (mm/day) and rain
/// (mm/month), January first.
class ClimateNormals {
  ClimateNormals({required List<double> etoMmDay, required List<double> rainMm, List<double>? dependableRainMm})
    : etoMmDay = List.unmodifiable(_twelve(etoMmDay)),
      rainMm = List.unmodifiable(_twelve(rainMm)),
      dependableRainMm = dependableRainMm == null ? null : List.unmodifiable(_twelve(dependableRainMm));

  /// From monthly climate data: ETo given per month, or computed with the
  /// FAO Penman-Monteith equation (climate.dart) at [latitudeDeg] and
  /// [elevationM].
  factory ClimateNormals.fromMonthlyClimate(List<MonthlyClimate> months, {required double latitudeDeg, required double elevationM, double kRs = 0.16}) {
    final pm = fao56MonthlySeries(months, latitudeDeg: latitudeDeg, elevationM: elevationM, kRs: kRs);
    final byMonth = {for (final m in months) m.month: m};
    final dep = [for (var m = 1; m <= 12; m++) byMonth[m]?.dependableRainMm];
    return ClimateNormals(
      etoMmDay: [for (var m = 1; m <= 12; m++) byMonth[m]?.etoMmDay ?? pm[m - 1]?.etoMmDay ?? 0],
      rainMm: [for (var m = 1; m <= 12; m++) byMonth[m]?.rainMm ?? 0],
      dependableRainMm: dep.every((d) => d != null) ? [for (final d in dep) d!] : null,
    );
  }

  final List<double> etoMmDay;
  final List<double> rainMm;
  final List<double>? dependableRainMm;

  static List<double> _twelve(List<double> v) {
    if (v.length != 12) throw ArgumentError('twelve months expected');
    return [for (final x in v) x.isFinite ? math.max(x, 0.0) : 0.0];
  }
}

/// One crop cycle of an irrigated area.
class CropCycle {
  const CropCycle({
    required this.cropKey,
    required this.curve,
    required this.planting,
    this.repeatsYearly = true,
    this.kr = 1,
    this.rootDepthM,
    this.depletionFraction,
    this.eceThreshold,
    this.eceMax,
    this.percolationMmDay = 0,
    this.establishmentMm = 0,
  });

  /// Cycle of a crop of the table ([fao56Crops]) with its Table 11 curve,
  /// root depth for scheduling, p and salt tolerance.
  factory CropCycle.fromTable(String cropKey, {required DateTime planting, bool repeatsYearly = true, KcCurve? curve, double kr = 1, double? rootDepthM, double? depletionFraction, double percolationMmDay = 0, double establishmentMm = 0}) {
    final c = fao56Crops[cropKey];
    return CropCycle(
      cropKey: cropKey,
      curve: curve ?? c?.curve ?? const KcCurve.constant(1),
      planting: planting,
      repeatsYearly: repeatsYearly,
      kr: kr,
      rootDepthM: rootDepthM ?? c?.schedulingRootDepthM,
      depletionFraction: depletionFraction ?? c?.depletionFraction,
      eceThreshold: c?.eceThreshold,
      eceMax: c?.eceMax,
      percolationMmDay: percolationMmDay,
      establishmentMm: establishmentMm,
    );
  }

  /// i18n key of the crop (`crop.*`).
  final String cropKey;
  final KcCurve curve;

  /// Planting (or green-up) date; with [repeatsYearly] only the day and
  /// month matter.
  final DateTime planting;
  final bool repeatsYearly;

  /// Localized irrigation reduction factor (1 for sprinkler and surface).
  final double kr;

  /// Root depth (m) and depletion fraction p for ETc ≈ 5 mm/day; null takes
  /// the area defaults.
  final double? rootDepthM;
  final double? depletionFraction;

  /// Salt tolerance (dS/m): ECe at 100 % and at zero yield (FAO-29 Table 4).
  final double? eceThreshold;
  final double? eceMax;

  /// Paddy rice: deep percolation and seepage every crop day (4–8 mm/day)
  /// and the water for saturation and the water layer at planting.
  final double percolationMmDay;
  final double establishmentMm;
}

/// A period of the requirement table (inclusive dates).
class RequirementPeriod {
  const RequirementPeriod({required this.id, required this.start, required this.end});
  final String id;
  final DateTime start;
  final DateTime end;
}

/// Inputs of the requirement of one irrigated area.
class RequirementInput {
  const RequirementInput({
    required this.areaId,
    required this.areaM2,
    required this.cycles,
    required this.climate,
    this.rainMethod = EffectiveRainMethod.usdaScs,
    this.rainFraction = 0.8,
    this.useDependableRain = false,
    this.efficiency = 0.9,
    this.applicationRateMmH = 0,
    this.wettedFraction = 1,
    this.awcMmPerM = 120,
    this.rootDepthM = 0.6,
    this.depletionFraction = 0.5,
    this.adjustDepletionToEtc = true,
    this.fixedIntervalDays,
    this.ecwDsM = 0,
    this.leachingFormula = LeachingFormula.surfaceSprinkler,
    this.leachingRule = LeachingRule.multiplicative,
    this.yieldPotentialPct = 100,
    this.operatingHoursPerDay,
  });

  final String areaId;
  final double areaM2;
  final List<CropCycle> cycles;
  final ClimateNormals climate;
  final EffectiveRainMethod rainMethod;

  /// Share kept by [EffectiveRainMethod.fixedPercentage].
  final double rainFraction;

  /// Use the dependable rain of [ClimateNormals] instead of the mean.
  final bool useDependableRain;

  /// Application efficiency Ea (0–1).
  final double efficiency;

  /// System application rate over the whole area (mm/h); 0 leaves hours out.
  final double applicationRateMmH;

  /// Fraction of the area wetted Pw (localized irrigation; 1 otherwise).
  final double wettedFraction;

  /// Soil available water capacity (mm/m), root depth (m) and depletion
  /// fraction p used when a cycle does not set its own.
  final double awcMmPerM;
  final double rootDepthM;
  final double depletionFraction;

  /// Adjust p to the ETc of the period (FAO-56 Table 22 note 2).
  final bool adjustDepletionToEtc;

  /// Interval chosen by the designer (days); null takes the longest whole
  /// number of days within the RAW.
  final int? fixedIntervalDays;

  /// Salinity of the irrigation water (dS/m); 0 = no leaching.
  final double ecwDsM;
  final LeachingFormula leachingFormula;
  final LeachingRule leachingRule;

  /// Yield potential (%) whose ECe sets LR with the surface/sprinkler
  /// formula (FAO-29 recommends 90 % or more).
  final double yieldPotentialPct;

  /// Hours of pumping per day for the required flow (null leaves it out).
  final double? operatingHoursPerDay;
}

/// One row of the requirement table (one crop cycle in one month or
/// period).
class RequirementRow {
  const RequirementRow({
    required this.areaId,
    required this.cycleIndex,
    required this.cropKey,
    required this.periodId,
    required this.start,
    required this.end,
    required this.cropDays,
    required this.etoMm,
    required this.kc,
    required this.kr,
    required this.etcMm,
    required this.etcLocMm,
    required this.rainMm,
    required this.effectiveRainMm,
    required this.extraMm,
    required this.netMm,
    required this.leachingFraction,
    required this.grossMm,
    required this.tawMm,
    required this.depletionFraction,
    required this.rawMm,
    required this.maxIntervalDays,
    required this.intervalDays,
    required this.netPerEventMm,
    required this.grossPerEventMm,
    required this.hoursPerEvent,
    required this.events,
    required this.volumeM3,
    required this.dailyVolumeM3,
    required this.flowM3h,
    required this.warnings,
  });

  final String areaId;
  final int cycleIndex;
  final String cropKey;

  /// `YYYY-MM` for monthly rows, the period id otherwise.
  final String periodId;
  final DateTime start;
  final DateTime end;

  /// Days of the period with the crop in the field.
  final int cropDays;

  /// Sums over the crop days (mm).
  final double etoMm;

  /// Kc of the period, ETc/ETo (the ETo-weighted mean, so that ETo·Kc = ETc;
  /// within a month it is the mean of the curve over the crop days), and the
  /// localized reduction factor.
  final double kc;
  final double kr;
  final double etcMm;

  /// ETc·Kr (mm).
  final double etcLocMm;

  /// Rain falling on the crop days and its effective part (mm).
  final double rainMm;
  final double effectiveRainMm;

  /// Percolation and establishment water of paddy rice (mm).
  final double extraMm;

  /// Net and gross irrigation depths (mm) and the leaching requirement.
  final double netMm;
  final double leachingFraction;
  final double grossMm;

  /// Total available water in the root zone (mm), p, and readily available
  /// water over the area (p·TAW·Pw, mm).
  final double tawMm;
  final double depletionFraction;
  final double rawMm;

  /// Longest interval the RAW allows (days; infinite without a net
  /// requirement) and the interval used.
  final double maxIntervalDays;
  final int intervalDays;
  final double netPerEventMm;
  final double grossPerEventMm;

  /// Hours per event at the application rate (null without a rate).
  final double? hoursPerEvent;

  /// Irrigation events in the period (net depth / net per event).
  final double events;

  /// Gross volume of the period and of a mean crop day (m³), and the flow
  /// for the operating hours (m³/h; null without them).
  final double volumeM3;
  final double dailyVolumeM3;
  final double? flowM3h;

  /// Message codes (`req_interval_exceeds_raw`, `req_leaching_infeasible`,
  /// `req_no_application_rate`).
  final List<String> warnings;

  double get etoMmDay => cropDays > 0 ? etoMm / cropDays : 0;
  double get etcMmDay => cropDays > 0 ? etcMm / cropDays : 0;
  double get etcLocMmDay => cropDays > 0 ? etcLocMm / cropDays : 0;
  double get netMmDay => cropDays > 0 ? netMm / cropDays : 0;
  double get grossMmDay => cropDays > 0 ? grossMm / cropDays : 0;
}

/// Totals of one crop cycle (or of the whole area) over the rows given.
class RequirementTotals {
  const RequirementTotals({required this.etoMm, required this.etcMm, required this.etcLocMm, required this.rainMm, required this.effectiveRainMm, required this.netMm, required this.grossMm, required this.volumeM3, required this.cropDays, this.peakPeriodId, required this.peakNetMmDay, required this.peakGrossMmDay, required this.peakDailyVolumeM3, this.peakFlowM3h});
  final double etoMm;
  final double etcMm;
  final double etcLocMm;
  final double rainMm;
  final double effectiveRainMm;
  final double netMm;
  final double grossMm;
  final double volumeM3;
  final int cropDays;

  /// Period (month) of the largest net daily depth: the design period.
  final String? peakPeriodId;
  final double peakNetMmDay;
  final double peakGrossMmDay;
  final double peakDailyVolumeM3;
  final double? peakFlowM3h;

  static RequirementTotals of(Iterable<RequirementRow> rows) {
    var eto = 0.0, etc = 0.0, etcLoc = 0.0, rain = 0.0, pe = 0.0, net = 0.0, gross = 0.0, vol = 0.0;
    var days = 0;
    RequirementRow? peak;
    for (final r in rows) {
      eto += r.etoMm;
      etc += r.etcMm;
      etcLoc += r.etcLocMm;
      rain += r.rainMm;
      pe += r.effectiveRainMm;
      net += r.netMm;
      gross += r.grossMm;
      vol += r.volumeM3;
      days += r.cropDays;
      if (peak == null || r.netMmDay > peak.netMmDay) peak = r;
    }
    return RequirementTotals(
      etoMm: eto,
      etcMm: etc,
      etcLocMm: etcLoc,
      rainMm: rain,
      effectiveRainMm: pe,
      netMm: net,
      grossMm: gross,
      volumeM3: vol,
      cropDays: days,
      peakPeriodId: peak?.periodId,
      peakNetMmDay: peak?.netMmDay ?? 0,
      peakGrossMmDay: peak?.grossMmDay ?? 0,
      peakDailyVolumeM3: peak?.dailyVolumeM3 ?? 0,
      peakFlowM3h: peak?.flowM3h,
    );
  }
}

/// The requirement of one irrigated area.
class RequirementTable {
  const RequirementTable({required this.areaId, required this.monthly, required this.periods, required this.cycleTotals, required this.areaTotals, required this.warnings});
  final String areaId;

  /// Rows per cycle and month of the typical year (months without the crop
  /// are left out), cycle by cycle.
  final List<RequirementRow> monthly;

  /// Rows per cycle and user period, in the order of the periods.
  final List<RequirementRow> periods;

  /// Year totals per cycle (index = cycle index) and of the area.
  final List<RequirementTotals> cycleTotals;
  final RequirementTotals areaTotals;

  /// Area-level message codes (`req_cycles_overlap`, `req_no_cycles`).
  final List<String> warnings;
}

class _Day {
  _Day(this.eto, this.kc, this.etc, this.etcLoc, this.extra, this.rain);
  final double eto, kc, etc, etcLoc, extra, rain;
  double pe = 0;
}

/// Requirement table of one area for the typical year [year] (a common
/// year by default) and, optionally, for [periods] at their own dates.
RequirementTable irrigationRequirement(RequirementInput input, {List<RequirementPeriod> periods = const [], int year = 2001}) {
  final warnings = <String>[];
  if (input.cycles.isEmpty) warnings.add('req_no_cycles');
  final rain = input.useDependableRain && input.climate.dependableRainMm != null ? input.climate.dependableRainMm! : input.climate.rainMm;
  // months to evaluate (whole months, so that the monthly effective rain
  // sees every crop day of the month)
  final months = <(int, int)>{for (var m = 1; m <= 12; m++) (year, m)};
  for (final p in periods) {
    for (var d = DateTime.utc(p.start.year, p.start.month); !d.isAfter(DateTime.utc(p.end.year, p.end.month)); d = DateTime.utc(d.year, d.month + 1)) {
      months.add((d.year, d.month));
    }
  }
  // daily records per cycle
  final perCycle = <Map<DateTime, _Day>>[];
  for (final c in input.cycles) {
    final days = <DateTime, _Day>{};
    for (final (y, m) in months) {
      final n = daysInMonth(y, m);
      final eto = input.climate.etoMmDay[m - 1];
      for (var d = 1; d <= n; d++) {
        final date = DateTime.utc(y, m, d);
        final t = daysIntoCycle(date, c.planting, c.curve.seasonDays, repeatsYearly: c.repeatsYearly);
        if (t == null) continue;
        final kc = c.curve.mean(t, math.min(t + 1, c.curve.seasonDays));
        if (kc <= 0) continue;
        final etc = eto * kc;
        final extra = c.percolationMmDay + (t < 1 ? c.establishmentMm : 0);
        days[date] = _Day(eto, kc, etc, etc * c.kr, extra, rain[m - 1] / n);
      }
    }
    perCycle.add(days);
  }
  // overlapping cycles in the typical year
  for (var i = 0; i < perCycle.length; i++) {
    for (var j = i + 1; j < perCycle.length; j++) {
      if (perCycle[i].keys.any((d) => d.year == year && perCycle[j].containsKey(d))) warnings.add('req_cycles_overlap:$i:$j');
    }
  }
  // effective rain, month by month, spread evenly over the crop days
  for (var i = 0; i < perCycle.length; i++) {
    final c = input.cycles[i];
    final storage = input.awcMmPerM * (c.rootDepthM ?? input.rootDepthM) * (c.depletionFraction ?? input.depletionFraction);
    final groups = <(int, int), List<_Day>>{};
    perCycle[i].forEach((date, day) => (groups[(date.year, date.month)] ??= []).add(day));
    groups.forEach((ym, list) {
      final demand = list.fold(0.0, (s, d) => s + d.etcLoc + d.extra);
      final pe = effectiveRainForPartOfMonthMm(input.rainMethod, monthRainMm: rain[ym.$2 - 1], days: list.length, monthDays: daysInMonth(ym.$1, ym.$2), etcMmInPeriod: demand, netDepthMm: storage, fraction: input.rainFraction);
      for (final d in list) {
        d.pe = pe / list.length;
      }
    });
  }

  RequirementRow? row(int i, String id, DateTime start, DateTime end) {
    final c = input.cycles[i];
    final days = perCycle[i];
    var n = 0;
    var eto = 0.0, kc = 0.0, etc = 0.0, etcLoc = 0.0, extra = 0.0, rainSum = 0.0, pe = 0.0;
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      final r = days[d];
      if (r == null) continue;
      n++;
      eto += r.eto;
      kc += r.kc;
      etc += r.etc;
      etcLoc += r.etcLoc;
      extra += r.extra;
      rainSum += r.rain;
      pe += r.pe;
    }
    if (n == 0) return null;
    final rowWarnings = <String>[];
    final net = math.max(etcLoc + extra - pe, 0.0);
    // leaching
    var lr = 0.0;
    if (input.ecwDsM > 0) {
      final double? ece;
      if (input.leachingFormula == LeachingFormula.highFrequencyDrip) {
        ece = c.eceMax;
      } else {
        final t = c.eceThreshold, mx = c.eceMax;
        ece = t == null ? null : (mx == null ? t : eceForYieldPotential(eceThreshold: t, eceMax: mx, yieldPct: input.yieldPotentialPct));
      }
      final v = ece == null ? null : leachingRequirement(ecwDsM: input.ecwDsM, eceDsM: ece, formula: input.leachingFormula);
      if (v == null) {
        rowWarnings.add(ece == null ? 'req_salt_tolerance_unknown' : 'req_leaching_infeasible');
        lr = ece == null ? 0 : 0.9;
      } else {
        lr = v;
      }
    }
    final ea = input.efficiency.clamp(0.05, 1.0);
    final double factor = switch (input.leachingRule) {
      LeachingRule.multiplicative => 1 / (ea * (1 - lr)),
      LeachingRule.lossesLeach => math.max(1 / ea, 1 / (1 - lr)),
    };
    final gross = net * factor;
    // soil water
    final zr = c.rootDepthM ?? input.rootDepthM;
    final taw = input.awcMmPerM * math.max(zr, 0.0);
    final pTab = c.depletionFraction ?? input.depletionFraction;
    final p = input.adjustDepletionToEtc ? adjustDepletionFraction(pTab, etc / n) : pTab.clamp(0.05, 0.95);
    final raw = p * taw * input.wettedFraction.clamp(0.01, 1.0);
    final netDay = net / n;
    final maxInterval = netDay > 0 ? raw / netDay : double.infinity;
    int interval;
    if (input.fixedIntervalDays != null) {
      interval = math.max(1, input.fixedIntervalDays!);
      if (interval > maxInterval + 1e-9) rowWarnings.add('req_interval_exceeds_raw');
    } else {
      interval = maxInterval.isFinite ? math.max(1, maxInterval.floor()) : n;
      if (maxInterval < 1) rowWarnings.add('req_interval_exceeds_raw');
    }
    final netEvent = netDay * interval;
    final grossEvent = netEvent * factor;
    final rate = input.applicationRateMmH;
    if (rate <= 0) rowWarnings.add('req_no_application_rate');
    final dailyVolume = gross / n * input.areaM2 / 1000;
    final hours = input.operatingHoursPerDay;
    return RequirementRow(
      areaId: input.areaId,
      cycleIndex: i,
      cropKey: c.cropKey,
      periodId: id,
      start: start,
      end: end,
      cropDays: n,
      etoMm: eto,
      kc: eto > 0 ? etc / eto : kc / n,
      kr: c.kr,
      etcMm: etc,
      etcLocMm: etcLoc,
      rainMm: rainSum,
      effectiveRainMm: pe,
      extraMm: extra,
      netMm: net,
      leachingFraction: lr,
      grossMm: gross,
      tawMm: taw,
      depletionFraction: p,
      rawMm: raw,
      maxIntervalDays: maxInterval,
      intervalDays: interval,
      netPerEventMm: netEvent,
      grossPerEventMm: grossEvent,
      hoursPerEvent: rate > 0 ? grossEvent / rate : null,
      events: netEvent > 0 ? net / netEvent : 0,
      volumeM3: gross * input.areaM2 / 1000,
      dailyVolumeM3: dailyVolume,
      flowM3h: hours != null && hours > 0 ? dailyVolume / hours : null,
      warnings: rowWarnings,
    );
  }

  final monthly = <RequirementRow>[];
  final cycleTotals = <RequirementTotals>[];
  for (var i = 0; i < input.cycles.length; i++) {
    final rows = <RequirementRow>[];
    for (var m = 1; m <= 12; m++) {
      final r = row(i, '$year-${m.toString().padLeft(2, '0')}', DateTime.utc(year, m), DateTime.utc(year, m, daysInMonth(year, m)));
      if (r != null) rows.add(r);
    }
    monthly.addAll(rows);
    cycleTotals.add(RequirementTotals.of(rows));
  }
  final periodRows = <RequirementRow>[];
  for (final p in periods) {
    for (var i = 0; i < input.cycles.length; i++) {
      final r = row(i, p.id, DateTime.utc(p.start.year, p.start.month, p.start.day), DateTime.utc(p.end.year, p.end.month, p.end.day));
      if (r != null) periodRows.add(r);
    }
  }
  return RequirementTable(areaId: input.areaId, monthly: monthly, periods: periodRows, cycleTotals: cycleTotals, areaTotals: RequirementTotals.of(monthly), warnings: warnings);
}
