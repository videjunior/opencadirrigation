/// The summary of the climate risk over the years kept in the project
/// (1.7.0 CLR, Design → Agronomy → Climate risk over the years): for every
/// year of a daily weather series, the site's reference evapotranspiration,
/// rain, peak-period ETo and longest dry spell, and for every irrigated area
/// the season's irrigation requirement, what the designed system could
/// apply, its peak-period demand and the days the soil went below the
/// allowed depletion; the figures the design uses beside them. The daily
/// series itself is not kept (the downloads stay in the device's data
/// cache): a few numbers a year and area. Built by
/// lib/core/design/climate_risk.dart.
library;

import '../design/climate_risk_stats.dart';

double _d(Object? v) => v is num && v.isFinite ? v.toDouble() : 0.0;
double? _dn(Object? v) => v is num && v.isFinite ? v.toDouble() : null;
int _i(Object? v) => v is num && v.isFinite ? v.round() : 0;
double _r(double v, int k) => v.isFinite ? double.parse(v.toStringAsFixed(k)) : 0;

String _date(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// One season (or irrigation year) of one area.
class ClimateRiskSeason {
  const ClimateRiskSeason({
    required this.year,
    required this.grossMm,
    required this.netMm,
    required this.appliedGrossMm,
    required this.peakGrossMmDay,
    required this.peakEtoMmDay,
    required this.deficitDays,
    this.filledDays = 0,
  });

  /// Year the season starts (planting, or the start of the irrigation year).
  final int year;

  /// Gross and net irrigation requirement of the season (mm over the area),
  /// with no limit of capacity.
  final double grossMm, netMm;

  /// Gross depth the designed system could apply (mm), limited by its
  /// capacity.
  final double appliedGrossMm;

  /// Largest mean gross demand of the peak period (mm/day) and largest mean
  /// ETo of the peak period in the season (mm/day).
  final double peakGrossMmDay, peakEtoMmDay;

  /// Crop days with the depletion above the allowed depletion, with the
  /// system as designed.
  final int deficitDays;

  /// Days of the season whose ETo or rain was missing and filled.
  final int filledDays;

  List<Object> toJson() => [year, _r(grossMm, 1), _r(netMm, 1), _r(appliedGrossMm, 1), _r(peakGrossMmDay, 2), _r(peakEtoMmDay, 2), deficitDays, filledDays];

  static ClimateRiskSeason? fromJson(Object? v) {
    if (v is! List || v.length < 7) return null;
    return ClimateRiskSeason(
      year: _i(v[0]),
      grossMm: _d(v[1]),
      netMm: _d(v[2]),
      appliedGrossMm: _d(v[3]),
      peakGrossMmDay: _d(v[4]),
      peakEtoMmDay: _d(v[5]),
      deficitDays: _i(v[6]),
      filledDays: v.length > 7 ? _i(v[7]) : 0,
    );
  }
}

/// The years of one irrigated area.
class ClimateRiskArea {
  const ClimateRiskArea({
    required this.areaId,
    required this.name,
    required this.areaM2,
    this.capacityGrossMmDay,
    required this.designEtoMmDay,
    required this.designPeakGrossMmDay,
    required this.designYearGrossMm,
    required this.startMonth,
    required this.startDay,
    required this.seasonDays,
    required this.seasons,
    this.warnings = const [],
  });
  final String areaId;
  final String name;
  final double areaM2;

  /// Gross depth the system can apply in a day (mm/day); null when unknown
  /// (no emitters in the area, or the area in no system flow).
  final double? capacityGrossMmDay;

  /// The figures the design uses: the ETo and the gross requirement of the
  /// design month (mm/day) and the gross requirement of the typical year
  /// (mm).
  final double designEtoMmDay, designPeakGrossMmDay, designYearGrossMm;

  /// Day and month the season starts, and its length (days; 365 for crops
  /// in the field all year, whose irrigation year starts on that day).
  final int startMonth, startDay, seasonDays;
  final List<ClimateRiskSeason> seasons;

  /// Message codes (`clr_*`).
  final List<String> warnings;

  /// The season runs into the next year (it is labelled "2019/20").
  bool get crossesYear => DateTime.utc(2001, startMonth, startDay).add(Duration(days: seasonDays - 1)).year > 2001;

  List<int> get years => [for (final s in seasons) s.year];
  List<double> get grossMm => [for (final s in seasons) s.grossMm];
  List<double> get peakGrossMmDay => [for (final s in seasons) s.peakGrossMmDay];
  List<double> get peakEtoMmDay => [for (final s in seasons) s.peakEtoMmDay];
  List<double> get deficitDays => [for (final s in seasons) s.deficitDays.toDouble()];

  /// Gross volume of the requirement and pumped by the system each season (m³).
  List<double> get requirementM3 => [for (final s in seasons) s.grossMm / 1000 * areaM2];
  List<double> get pumpedM3 => [for (final s in seasons) s.appliedGrossMm / 1000 * areaM2];

  /// Seasons without a deficit day.
  int get reliableSeasons => seasons.where((s) => s.deficitDays == 0).length;

  /// Share of the seasons without a deficit day (0–1; null without seasons).
  double? get reliability => seasons.isEmpty ? null : reliableSeasons / seasons.length;

  /// The worst seasons: most deficit days, then the largest requirement.
  List<ClimateRiskSeason> worst([int k = 3]) {
    final xs = [...seasons]..sort((a, b) => b.deficitDays != a.deficitDays ? b.deficitDays.compareTo(a.deficitDays) : b.grossMm.compareTo(a.grossMm));
    return xs.take(k).toList();
  }

  TrendTest? get trend => senMannKendall(years, grossMm);

  Map<String, dynamic> toJson() => {
    'id': areaId,
    'name': name,
    'a': _r(areaM2, 1),
    if (capacityGrossMmDay != null) 'cap': _r(capacityGrossMmDay!, 3),
    'eto': _r(designEtoMmDay, 3),
    'peak': _r(designPeakGrossMmDay, 3),
    'yr': _r(designYearGrossMm, 1),
    'start': [startMonth, startDay, seasonDays],
    'seasons': [for (final s in seasons) s.toJson()],
    if (warnings.isNotEmpty) 'warn': warnings,
  };

  static ClimateRiskArea? fromJson(Object? v) {
    if (v is! Map || v['id'] is! String) return null;
    final st = v['start'] is List ? v['start'] as List : const [];
    return ClimateRiskArea(
      areaId: v['id'] as String,
      name: v['name'] is String ? v['name'] as String : '',
      areaM2: _d(v['a']),
      capacityGrossMmDay: _dn(v['cap']),
      designEtoMmDay: _d(v['eto']),
      designPeakGrossMmDay: _d(v['peak']),
      designYearGrossMm: _d(v['yr']),
      startMonth: st.isNotEmpty ? _i(st[0]).clamp(1, 12) : 1,
      startDay: st.length > 1 ? _i(st[1]).clamp(1, 31) : 1,
      seasonDays: st.length > 2 ? _i(st[2]).clamp(1, 366) : 365,
      seasons: [
        if (v['seasons'] is List)
          for (final s in v['seasons'] as List) ?ClimateRiskSeason.fromJson(s),
      ],
      warnings: [
        if (v['warn'] is List)
          for (final w in v['warn'] as List)
            if (w is String) w,
      ],
    );
  }
}

/// One (irrigation) year of the site.
class ClimateRiskSiteYear {
  const ClimateRiskSiteYear({required this.year, required this.etoMm, required this.rainMm, required this.peakEtoMmDay, required this.drySpellDays, this.drySpellStart, this.filledDays = 0});

  /// Year the irrigation year starts in.
  final int year;

  /// ETo and rain of the year (mm).
  final double etoMm, rainMm;

  /// Largest mean ETo of the peak period (mm/day).
  final double peakEtoMmDay;

  /// Longest run of days with less than 1 mm of rain (ETCCDI index CDD) and
  /// its first day.
  final int drySpellDays;
  final DateTime? drySpellStart;
  final int filledDays;

  List<Object> toJson() => [year, _r(etoMm, 1), _r(rainMm, 1), _r(peakEtoMmDay, 2), drySpellDays, drySpellStart == null ? '' : _date(drySpellStart!), filledDays];

  static ClimateRiskSiteYear? fromJson(Object? v) {
    if (v is! List || v.length < 5) return null;
    final d = v.length > 5 ? DateTime.tryParse('${v[5]}') : null;
    return ClimateRiskSiteYear(
      year: _i(v[0]),
      etoMm: _d(v[1]),
      rainMm: _d(v[2]),
      peakEtoMmDay: _d(v[3]),
      drySpellDays: _i(v[4]),
      drySpellStart: d == null ? null : DateTime.utc(d.year, d.month, d.day),
      filledDays: v.length > 6 ? _i(v[6]) : 0,
    );
  }
}

/// One year of the whole project (the seasons of every area that start in
/// it).
class ClimateRiskProjectYear {
  const ClimateRiskProjectYear({required this.year, required this.requirementM3, required this.pumpedM3, required this.deficitDays, required this.areasInDeficit, required this.complete});
  final int year;

  /// Gross volume of the requirement and pumped by the system (m³).
  final double requirementM3, pumpedM3;

  /// Days with at least one area below the allowed depletion, and the areas
  /// that had any.
  final int deficitDays, areasInDeficit;

  /// Every area has its season of this year.
  final bool complete;

  List<Object> toJson() => [year, _r(requirementM3, 0), _r(pumpedM3, 0), deficitDays, areasInDeficit, complete ? 1 : 0];

  static ClimateRiskProjectYear? fromJson(Object? v) {
    if (v is! List || v.length < 6) return null;
    return ClimateRiskProjectYear(year: _i(v[0]), requirementM3: _d(v[1]), pumpedM3: _d(v[2]), deficitDays: _i(v[3]), areasInDeficit: _i(v[4]), complete: _i(v[5]) != 0);
  }
}

/// The climate risk over the years of a project.
class ClimateRiskSummary {
  const ClimateRiskSummary({
    required this.source,
    required this.attribution,
    required this.latitudeDeg,
    required this.longitudeDeg,
    required this.firstYear,
    required this.lastYear,
    required this.computed,
    required this.probability,
    required this.peakDays,
    required this.startMonth,
    required this.windowHours,
    this.projectEtoMmDay,
    required this.site,
    required this.areas,
    required this.project,
    this.warnings = const [],
  });

  /// Where the daily series came from (`nasaPower`, or the source of the
  /// site climate's own series: `inmet`, `openMeteo`…) and its credit.
  final String source;
  final String attribution;
  final double latitudeDeg, longitudeDeg;

  /// First and last day's year of the series.
  final int firstYear, lastYear;

  /// When it was computed (`YYYY-MM-DD`).
  final String computed;

  /// Non-exceedance probability of the design values (0.8 = not exceeded
  /// in four years out of five) and the length of the peak period (days).
  final double probability;
  final int peakDays;

  /// Month the irrigation year of the site starts (the month whose mean
  /// rain most exceeds its ETo; 1 = calendar years).
  final int startMonth;

  /// Hours a day the system may run (the programme's window).
  final double windowHours;

  /// The largest monthly ETo of the site climate the design uses (mm/day;
  /// null without a site climate).
  final double? projectEtoMmDay;
  final List<ClimateRiskSiteYear> site;
  final List<ClimateRiskArea> areas;
  final List<ClimateRiskProjectYear> project;

  /// Message codes (`clr_*`).
  final List<String> warnings;

  /// The label of [year]: "2019", or "2019/20" when the year or season
  /// runs into the next one.
  static String yearLabel(int year, {bool crosses = false}) => crosses ? '$year/${((year + 1) % 100).toString().padLeft(2, '0')}' : '$year';

  /// Site years run into the next calendar year.
  bool get siteCrossesYear => startMonth != 1;

  Map<String, dynamic> toJson() => {
    'v': 1,
    'src': source,
    if (attribution.isNotEmpty) 'credit': attribution,
    'lat': _r(latitudeDeg, 4),
    'lon': _r(longitudeDeg, 4),
    'y0': firstYear,
    'y1': lastYear,
    'at': computed,
    'p': probability,
    'n': peakDays,
    'm0': startMonth,
    'w': windowHours,
    if (projectEtoMmDay != null) 'eto': _r(projectEtoMmDay!, 3),
    'site': [for (final s in site) s.toJson()],
    'areas': [for (final a in areas) a.toJson()],
    'project': [for (final y in project) y.toJson()],
    if (warnings.isNotEmpty) 'warn': warnings,
  };

  /// Reads a summary; null when [v] is none (never throws).
  static ClimateRiskSummary? fromJson(Object? v) {
    if (v is! Map) return null;
    try {
      List<T> each<T>(Object? l, T? Function(Object?) read) => [
        if (l is List)
          for (final x in l) ?read(x),
      ];
      return ClimateRiskSummary(
        source: v['src'] is String ? v['src'] as String : '',
        attribution: v['credit'] is String ? v['credit'] as String : '',
        latitudeDeg: _d(v['lat']),
        longitudeDeg: _d(v['lon']),
        firstYear: _i(v['y0']),
        lastYear: _i(v['y1']),
        computed: v['at'] is String ? v['at'] as String : '',
        probability: (_dn(v['p']) ?? 0.8).clamp(0.5, 0.99).toDouble(),
        peakDays: _i(v['n']).clamp(1, 92),
        startMonth: _i(v['m0']).clamp(1, 12),
        windowHours: _dn(v['w']) ?? 24,
        projectEtoMmDay: _dn(v['eto']),
        site: each(v['site'], ClimateRiskSiteYear.fromJson),
        areas: each(v['areas'], ClimateRiskArea.fromJson),
        project: each(v['project'], ClimateRiskProjectYear.fromJson),
        warnings: [
          if (v['warn'] is List)
            for (final w in v['warn'] as List)
              if (w is String) w,
        ],
      );
    } on Object {
      return null;
    }
  }
}
