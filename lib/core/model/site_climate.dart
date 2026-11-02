/// Climate of the site kept in the project: monthly normals of reference
/// evapotranspiration, rain (mean and dependable), solar radiation and,
/// for the climatic adjustment of the crop coefficients, the minimum
/// relative humidity and the wind speed at 2 m, downloaded from a public
/// service or typed in, with their provenance.
library;

import 'dart:math' as math;

import '../design/climate.dart' show minRelativeHumidityPct;
import '../design/irrigation_requirement.dart';

// 1.6.0 AGR

/// Daily ETo and rain of the site (the days of a weather station file or of
/// a download), kept for the daily soil water balance (FAO-56 chapter 8):
/// [etoMm] and [rainMm] hold one value a day from [start] (UTC midnight),
/// NaN where the day has none. At most [maxDays] are kept (the latest).
class DailyClimate {
  factory DailyClimate({required DateTime start, required List<double> etoMm, required List<double> rainMm, String source = ''}) {
    final n = math.min(etoMm.length, rainMm.length);
    final cut = math.max(0, n - maxDays);
    final first = DateTime.utc(start.year, start.month, start.day).add(Duration(days: cut));
    return DailyClimate._(first, List.unmodifiable(etoMm.sublist(cut, n)), List.unmodifiable(rainMm.sublist(cut, n)), source);
  }
  DailyClimate._(this.start, this.etoMm, this.rainMm, this.source);

  /// About forty years.
  static const maxDays = 14700;
  final DateTime start;
  final List<double> etoMm;
  final List<double> rainMm;

  /// Where the days come from (`inmet`, `openMeteo`, `nasaPower`…).
  final String source;

  int get length => math.min(etoMm.length, rainMm.length);
  DateTime dateAt(int i) => start.add(Duration(days: i));

  /// From days in any order (date, ETo, rain; null = none): one value a day
  /// from the first to the last date, the gaps NaN.
  static DailyClimate? fromDays(Iterable<(DateTime, double?, double?)> days, {String source = ''}) {
    final byDay = <int, (double?, double?)>{};
    DateTime? first, last;
    for (final (d, e, r) in days) {
      final u = DateTime.utc(d.year, d.month, d.day);
      byDay[u.millisecondsSinceEpoch ~/ 86400000] = (e, r);
      if (first == null || u.isBefore(first)) first = u;
      if (last == null || u.isAfter(last)) last = u;
    }
    if (first == null || last == null) return null;
    final n = last.difference(first).inDays + 1;
    final eto = List<double>.filled(n, double.nan), rain = List<double>.filled(n, double.nan);
    final k0 = first.millisecondsSinceEpoch ~/ 86400000;
    byDay.forEach((k, v) {
      final e = v.$1, r = v.$2;
      if (e != null && e.isFinite && e >= 0) eto[k - k0] = e;
      if (r != null && r.isFinite && r >= 0) rain[k - k0] = r;
    });
    return DailyClimate(start: first, etoMm: eto, rainMm: rain, source: source);
  }

  /// Years of the series with at least 90 % of their days holding ETo and
  /// rain.
  List<int> get completeYears {
    final count = <int, int>{};
    for (var i = 0; i < length; i++) {
      if (etoMm[i].isFinite && rainMm[i].isFinite) count.update(dateAt(i).year, (v) => v + 1, ifAbsent: () => 1);
    }
    return [
      for (final e in count.entries)
        if (e.value >= 0.9 * (DateTime.utc(e.key + 1).difference(DateTime.utc(e.key)).inDays)) e.key,
    ]..sort();
  }

  /// The days of [year] and of the next year (a season planted late in the
  /// year runs into it), as (date, ETo, rain); a missing ETo takes the
  /// month's value of [fill] (else 0) and missing rain is none. Empty when
  /// the series has no day of [year].
  List<(DateTime, double, double)> yearDays(int year, {List<double>? fill}) {
    final out = <(DateTime, double, double)>[];
    final from = DateTime.utc(year), to = DateTime.utc(year + 2);
    for (var i = 0; i < length; i++) {
      final d = dateAt(i);
      if (d.isBefore(from) || !d.isBefore(to)) continue;
      final e = etoMm[i].isFinite ? etoMm[i] : (fill != null && fill.length == 12 ? fill[d.month - 1] : 0.0);
      out.add((d, e, rainMm[i].isFinite ? rainMm[i] : 0.0));
    }
    return out.isNotEmpty && out.first.$1.year == year ? out : const [];
  }

  static double? _round(double v, int k) => v.isFinite ? double.parse(v.toStringAsFixed(k)) : null;

  Map<String, dynamic> toJson() => {
    'd0': '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
    'eto': [for (var i = 0; i < length; i++) _round(etoMm[i], 2)],
    'p': [for (var i = 0; i < length; i++) _round(rainMm[i], 1)],
    if (source.isNotEmpty) 'src': source,
  };

  static DailyClimate? fromJson(Object? v) {
    if (v is! Map) return null;
    final d0 = DateTime.tryParse('${v['d0']}');
    final eto = v['eto'], rain = v['p'];
    if (d0 == null || eto is! List || rain is! List) return null;
    List<double> values(List l) => [for (final x in l) x is num && x.isFinite ? x.toDouble() : double.nan];
    return DailyClimate(start: d0, etoMm: values(eto), rainMm: values(rain), source: v['src'] is String ? v['src'] as String : '');
  }
}

class SiteClimate {
  SiteClimate({
    required this.etoMmDay,
    required this.rainMm,
    this.dependableRainMm,
    this.solarKWhM2Day,
    this.rhMinPct,
    this.windSpeed2mMs,
    this.source = 'manual',
    this.firstYear = 0,
    this.lastYear = 0,
    this.latitudeDeg = 0,
    this.longitudeDeg = 0,
    this.retrieved = '',
    this.attribution = '',
    this.daily,
  });

  /// Twelve monthly values, January first.
  final List<double> etoMmDay;
  final List<double> rainMm;
  final List<double>? dependableRainMm;

  /// Global horizontal irradiation (kWh/m²/day), for solar pumping.
  final List<double>? solarKWhM2Day;

  /// Mean daily minimum relative humidity (%) and mean wind speed at 2 m
  /// (m/s) of every month, for the Kc adjustment of FAO-56 eqs. 62 and 65
  /// (null when unknown).
  final List<double>? rhMinPct;
  final List<double>? windSpeed2mMs;

  /// Twelve values when every month has one, else null.
  static List<double>? monthlyOrNull(List<double?> v) => v.length == 12 && v.every((x) => x != null && x.isFinite) ? [for (final x in v) x!] : null;

  /// Monthly minimum relative humidity (%) of twelve months given as
  /// (RHmin, Tmax, dew point, Tmin): the month's own value or, without it,
  /// FAO-56 eq. 63 from the dew point and Tmax (eq. 64 with Tmin as the dew
  /// point); null unless every month has one.
  static List<double>? monthlyRhMin(List<(double?, double?, double?, double?)> months) =>
      monthlyOrNull([for (final (rh, tMax, dew, tMin) in months) rh ?? (tMax != null && (dew ?? tMin) != null ? minRelativeHumidityPct(tMaxC: tMax, tDewC: dew, tMinC: tMin) : null)]);

  /// `openMeteo`, `nasaPower` or `manual`.
  final String source;
  final int firstYear, lastYear;
  final double latitudeDeg, longitudeDeg;

  /// Date of the download (`YYYY-MM-DD`).
  final String retrieved;

  /// Credit the data service asks for.
  final String attribution;

  /// 1.6.0 AGR: the daily ETo and rain behind the normals, for the daily
  /// soil water balance (null when typed by hand).
  final DailyClimate? daily;

  ClimateNormals get normals => ClimateNormals(etoMmDay: etoMmDay, rainMm: rainMm, dependableRainMm: dependableRainMm);

  SiteClimate copyWith({
    List<double>? etoMmDay,
    List<double>? rainMm,
    List<double>? dependableRainMm,
    List<double>? solarKWhM2Day,
    List<double>? rhMinPct,
    List<double>? windSpeed2mMs,
    String? source,
  }) => SiteClimate(
    etoMmDay: etoMmDay ?? this.etoMmDay,
    rainMm: rainMm ?? this.rainMm,
    dependableRainMm: dependableRainMm ?? this.dependableRainMm,
    solarKWhM2Day: solarKWhM2Day ?? this.solarKWhM2Day,
    rhMinPct: rhMinPct ?? this.rhMinPct,
    windSpeed2mMs: windSpeed2mMs ?? this.windSpeed2mMs,
    source: source ?? this.source,
    firstYear: firstYear,
    lastYear: lastYear,
    latitudeDeg: latitudeDeg,
    longitudeDeg: longitudeDeg,
    retrieved: retrieved,
    attribution: attribution,
    daily: daily,
  );

  Map<String, dynamic> toJson() => {
    'eto': etoMmDay,
    'rain': rainMm,
    if (dependableRainMm != null) 'rainDep': dependableRainMm,
    if (solarKWhM2Day != null) 'rs': solarKWhM2Day,
    if (rhMinPct != null) 'rhmin': rhMinPct,
    if (windSpeed2mMs != null) 'u2': windSpeed2mMs,
    'source': source,
    if (firstYear > 0) 'y0': firstYear,
    if (lastYear > 0) 'y1': lastYear,
    'lat': latitudeDeg,
    'lon': longitudeDeg,
    if (retrieved.isNotEmpty) 'at': retrieved,
    if (attribution.isNotEmpty) 'credit': attribution,
    if (daily != null) 'daily': daily!.toJson(),
  };

  static List<double>? _months(Object? v) {
    if (v is! List || v.length != 12) return null;
    return [for (final x in v) (x is num && x.isFinite) ? x.toDouble() : 0.0];
  }

  static SiteClimate? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final eto = _months(j['eto']), rain = _months(j['rain']);
    if (eto == null || rain == null) return null;
    return SiteClimate(
      etoMmDay: eto,
      rainMm: rain,
      dependableRainMm: _months(j['rainDep']),
      solarKWhM2Day: _months(j['rs']),
      rhMinPct: _months(j['rhmin']),
      windSpeed2mMs: _months(j['u2']),
      source: j['source'] as String? ?? 'manual',
      firstYear: (j['y0'] as num?)?.toInt() ?? 0,
      lastYear: (j['y1'] as num?)?.toInt() ?? 0,
      latitudeDeg: (j['lat'] as num?)?.toDouble() ?? 0,
      longitudeDeg: (j['lon'] as num?)?.toDouble() ?? 0,
      retrieved: j['at'] as String? ?? '',
      attribution: j['credit'] as String? ?? '',
      daily: DailyClimate.fromJson(j['daily']),
    );
  }
}
