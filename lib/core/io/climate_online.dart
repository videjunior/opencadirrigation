/// Online daily climate data for agronomy and solar pumping, aggregated to
/// monthly normals: builds the request URLs, parses the answers, drives a
/// polite download (sequential requests, a budget of calls per minute,
/// retries, waits on HTTP 429) and computes the monthly means, the mean and
/// dependable monthly rain and the FAO Penman-Monteith ETo. Pure Dart; the
/// HTTP GET is injected by the app layer.
///
/// Sources (keyless, both answer cross-origin requests with
/// `Access-Control-Allow-Origin: *`, so the web build can use them):
/// - Open-Meteo historical weather API (archive-api.open-meteo.com,
///   reanalysis ERA5 / ERA5-Land from 1940, about 5 days behind real time):
///   daily et0_fao_evapotranspiration, precipitation_sum,
///   temperature_2m_max/min, wind_speed_10m_mean, shortwave_radiation_sum,
///   relative_humidity_2m_max/min and dew_point_2m_mean. Terms: the free API
///   is for non-commercial use (10 000 calls per day, 5 000 per hour, 600 per
///   minute); a request with more than 10 variables or more than two weeks
///   of data counts as several calls (fractionally: variables/10 ×
///   days/14); commercial use needs an API key. The data are licensed
///   CC BY 4.0 and must be credited ("Weather data by Open-Meteo.com"; the
///   underlying reanalysis is Copernicus Climate Change Service
///   information).
/// - NASA POWER daily point API (power.larc.nasa.gov, MERRA-2 meteorology
///   and CERES/FLASHFlux solar data, from 1981): T2M_MAX, T2M_MIN, T2MDEW,
///   RH2M, WS2M, PRECTOTCORR and ALLSKY_SFC_SW_DWN (MJ/m²/day with
///   community=AG). Free; NASA asks for the acknowledgement quoted in
///   [ClimateSource.attribution] and the service version and access date.
///   The climatology endpoint returns the extreme T2M_MAX/T2M_MIN of each
///   month, not mean daily values, so the normals here are built from the
///   daily endpoint.
library;

import 'dart:convert';
import 'dart:math' as math;

import '../design/climate.dart';
import '../design/effective_rain.dart';
import '../design/irrigation_requirement.dart' show ClimateNormals;

enum ClimateSource {
  openMeteo(firstYear: 1940, chunkYears: 1, callsPerMinute: 500, minInterval: Duration.zero, lagDays: 6),
  nasaPower(firstYear: 1981, chunkYears: 5, callsPerMinute: 30, minInterval: Duration(milliseconds: 1100), lagDays: 10);

  const ClimateSource({required this.firstYear, required this.chunkYears, required this.callsPerMinute, required this.minInterval, required this.lagDays});

  /// First year with data.
  final int firstYear;

  /// Years per request.
  final int chunkYears;

  /// Budget of calls (in the service's own counting) per sliding minute.
  final double callsPerMinute;

  /// Pause between consecutive requests.
  final Duration minInterval;

  /// Days behind today the archive is usually complete.
  final int lagDays;

  /// Both services answer cross-origin requests.
  bool get browserOk => true;

  /// Credit line the data licence asks for (shown with the data).
  String get attribution => switch (this) {
    ClimateSource.openMeteo => 'Weather data by Open-Meteo.com (CC BY 4.0), based on Copernicus Climate Change Service information (ERA5)',
    ClimateSource.nasaPower => "The data was obtained from the National Aeronautics and Space Administration (NASA) Langley Research Center's Prediction Of Worldwide Energy Resources (POWER) project funded through the NASA Earth Science Division",
  };
}

/// Error of a climate download; [code] is a message code for the interface
/// (`climate_bad_request`, `climate_bad_response`, `climate_service_error`,
/// `climate_no_data`, `climate_cancelled`), [detail] the service's own
/// reason when it gave one.
class ClimateException implements Exception {
  const ClimateException(this.code, [this.detail]);
  final String code;
  final String? detail;
  @override
  String toString() => detail == null ? code : '$code:$detail';
}

/// One day of data (null where the service has none).
class ClimateDay {
  const ClimateDay({required this.date, this.tMaxC, this.tMinC, this.tDewC, this.rhMaxPct, this.rhMinPct, this.rhMeanPct, this.windSpeed2mMs, this.solarMJm2, this.rainMm, this.etoMmDay});
  final DateTime date;
  final double? tMaxC;
  final double? tMinC;
  final double? tDewC;
  final double? rhMaxPct;
  final double? rhMinPct;
  final double? rhMeanPct;

  /// Mean wind speed at 2 m (m/s); 10 m data are converted with FAO-56
  /// eq. 47.
  final double? windSpeed2mMs;

  /// Daily solar radiation (MJ/m²).
  final double? solarMJm2;
  final double? rainMm;

  /// ETo given by the service (Open-Meteo), mm/day.
  final double? etoMmDay;
}

/// Daily series of one location.
class ClimateSeries {
  const ClimateSeries({required this.source, required this.latitudeDeg, required this.longitudeDeg, this.elevationM, required this.days});
  final ClimateSource source;
  final double latitudeDeg;
  final double longitudeDeg;

  /// Elevation of the data cell (m), when the service gives it.
  final double? elevationM;

  /// Days in date order, without repeats.
  final List<ClimateDay> days;
}

const _openMeteoDaily = [
  'et0_fao_evapotranspiration',
  'precipitation_sum',
  'temperature_2m_max',
  'temperature_2m_min',
  'wind_speed_10m_mean',
  'shortwave_radiation_sum',
  'relative_humidity_2m_max',
  'relative_humidity_2m_min',
  'dew_point_2m_mean',
];

const _powerParameters = ['T2M_MAX', 'T2M_MIN', 'T2MDEW', 'RH2M', 'WS2M', 'PRECTOTCORR', 'ALLSKY_SFC_SW_DWN'];

String _d(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String _compact(DateTime d) => _d(d).replaceAll('-', '');
String _coord(double v) => v.toStringAsFixed(4);

/// URL of one request of [source] for [start]..[end] (inclusive dates).
/// [apiKey] uses the Open-Meteo commercial host.
String climateRequestUrl(ClimateSource source, double latitudeDeg, double longitudeDeg, DateTime start, DateTime end, {String? apiKey}) {
  switch (source) {
    case ClimateSource.openMeteo:
      final host = apiKey == null || apiKey.isEmpty ? 'archive-api.open-meteo.com' : 'customer-archive-api.open-meteo.com';
      final key = apiKey == null || apiKey.isEmpty ? '' : '&apikey=${Uri.encodeQueryComponent(apiKey)}';
      return 'https://$host/v1/archive?latitude=${_coord(latitudeDeg)}&longitude=${_coord(longitudeDeg)}&start_date=${_d(start)}&end_date=${_d(end)}&daily=${_openMeteoDaily.join(',')}&timezone=auto&wind_speed_unit=ms$key';
    case ClimateSource.nasaPower:
      return 'https://power.larc.nasa.gov/api/temporal/daily/point?parameters=${_powerParameters.join(',')}&community=AG&longitude=${_coord(longitudeDeg)}&latitude=${_coord(latitudeDeg)}&start=${_compact(start)}&end=${_compact(end)}&format=JSON';
  }
}

/// Weight of one request in the service's counting of calls (Open-Meteo:
/// variables/10 × days/14, at least 1 each; NASA POWER: 1).
double climateRequestWeight(ClimateSource source, DateTime start, DateTime end) {
  if (source != ClimateSource.openMeteo) return 1;
  final days = DateTime.utc(end.year, end.month, end.day).difference(DateTime.utc(start.year, start.month, start.day)).inDays + 1;
  return math.max(1, _openMeteoDaily.length / 10) * math.max(1, days / 14);
}

/// Request periods (inclusive dates) covering the years [firstYear] to
/// [lastYear], chunked by [ClimateSource.chunkYears] and cut [lagDays]
/// before [today].
List<(DateTime, DateTime)> climateRequestPeriods(ClimateSource source, int firstYear, int lastYear, {required DateTime today}) {
  final last = DateTime.utc(today.year, today.month, today.day).subtract(Duration(days: source.lagDays));
  final out = <(DateTime, DateTime)>[];
  for (var y = firstYear; y <= lastYear; y += source.chunkYears) {
    final s = DateTime.utc(y);
    var e = DateTime.utc(math.min(y + source.chunkYears - 1, lastYear), 12, 31);
    if (e.isAfter(last)) e = last;
    if (e.isBefore(s)) break;
    out.add((s, e));
  }
  return out;
}

double? _num(Object? v, {double? fill}) {
  if (v is! num) return null;
  final x = v.toDouble();
  if (!x.isFinite || (fill != null && (x - fill).abs() < 1e-9)) return null;
  return x;
}

/// Parses one answer of [source] into its days and the cell elevation.
(List<ClimateDay>, double?) climateParseResponse(ClimateSource source, String body) {
  final Object? j;
  try {
    j = jsonDecode(body);
  } on FormatException {
    throw const ClimateException('climate_bad_response');
  }
  if (j is! Map<String, dynamic>) throw const ClimateException('climate_bad_response');
  switch (source) {
    case ClimateSource.openMeteo:
      if (j['error'] == true) throw ClimateException('climate_service_error', j['reason']?.toString());
      final daily = j['daily'];
      if (daily is! Map<String, dynamic> || daily['time'] is! List) throw const ClimateException('climate_bad_response');
      final time = daily['time'] as List;
      List<Object?> col(String k) {
        final v = daily[k];
        return v is List && v.length == time.length ? v : List<Object?>.filled(time.length, null);
      }

      final eto = col('et0_fao_evapotranspiration'), rain = col('precipitation_sum'), tx = col('temperature_2m_max'), tn = col('temperature_2m_min');
      final wind = col('wind_speed_10m_mean'), rs = col('shortwave_radiation_sum'), rhx = col('relative_humidity_2m_max'), rhn = col('relative_humidity_2m_min'), dew = col('dew_point_2m_mean');
      final units = j['daily_units'];
      final windUnit = units is Map ? units['wind_speed_10m_mean']?.toString() : null;
      final windFactor = switch (windUnit) {
        'km/h' => 1 / 3.6,
        'mp/h' || 'mph' => 0.44704,
        'kn' => 0.514444,
        _ => 1.0,
      };
      final days = <ClimateDay>[];
      for (var i = 0; i < time.length; i++) {
        final date = DateTime.tryParse('${time[i]}');
        if (date == null) continue;
        final w = _num(wind[i]);
        days.add(
          ClimateDay(
            date: DateTime.utc(date.year, date.month, date.day),
            tMaxC: _num(tx[i]),
            tMinC: _num(tn[i]),
            tDewC: _num(dew[i]),
            rhMaxPct: _num(rhx[i]),
            rhMinPct: _num(rhn[i]),
            windSpeed2mMs: w == null ? null : windSpeedAt2m(w * windFactor, 10),
            solarMJm2: _num(rs[i]),
            rainMm: _num(rain[i]),
            etoMmDay: _num(eto[i]),
          ),
        );
      }
      return (days, _num(j['elevation']));
    case ClimateSource.nasaPower:
      final props = j['properties'];
      final param = props is Map ? props['parameter'] : null;
      if (param is! Map) {
        final msgs = j['messages'];
        if (msgs is List && msgs.isNotEmpty) throw ClimateException('climate_service_error', msgs.join('; '));
        throw const ClimateException('climate_bad_response');
      }
      final header = j['header'];
      final fill = header is Map ? _num(header['fill_value']) ?? -999.0 : -999.0;
      Map<String, Object?> series(String k) => param[k] is Map ? Map<String, Object?>.from(param[k] as Map) : const {};
      final s = {for (final k in _powerParameters) k: series(k)};
      final keys = <String>{for (final m in s.values) ...m.keys};
      final days = <ClimateDay>[];
      for (final k in keys) {
        if (k.length != 8) continue;
        final y = int.tryParse(k.substring(0, 4)), m = int.tryParse(k.substring(4, 6)), d = int.tryParse(k.substring(6, 8));
        if (y == null || m == null || d == null || m < 1 || m > 12 || d < 1 || d > 31) continue;
        double? v(String p) => _num(s[p]![k], fill: fill);
        days.add(
          ClimateDay(
            date: DateTime.utc(y, m, d),
            tMaxC: v('T2M_MAX'),
            tMinC: v('T2M_MIN'),
            tDewC: v('T2MDEW'),
            rhMeanPct: v('RH2M'),
            windSpeed2mMs: v('WS2M'),
            solarMJm2: v('ALLSKY_SFC_SW_DWN'),
            rainMm: v('PRECTOTCORR'),
          ),
        );
      }
      days.sort((a, b) => a.date.compareTo(b.date));
      final geometry = j['geometry'];
      final coords = geometry is Map ? geometry['coordinates'] : null;
      final elev = coords is List && coords.length > 2 ? _num(coords[2], fill: fill) : null;
      return (days, elev);
  }
}

/// Downloads the daily data of [firstYear]..[lastYear] at a point with
/// [fetch] (GET url → body). Requests run one after another, at most
/// [callsPerMinute] calls (service counting, see [climateRequestWeight]) per
/// sliding [budgetWindow] and [minInterval] apart; a failed request is
/// retried up to [retries] times when [retryable] accepts the error, and an
/// error [rateLimited] accepts (HTTP 429) waits [rateLimitDelay] × attempt
/// first. [onProgress] gets (finished requests, total), [onWait] every pause
/// imposed by a limit, and [cancelled] is polled between requests (true
/// throws `climate_cancelled`). [today] fixes the end of the archive (tests).
Future<ClimateSeries> climateDownload(
  ClimateSource source, {
  required double latitudeDeg,
  required double longitudeDeg,
  required int firstYear,
  required int lastYear,
  required Future<String> Function(String url) fetch,
  String? apiKey,
  DateTime? today,
  void Function(int done, int total)? onProgress,
  void Function(Duration wait)? onWait,
  bool Function()? cancelled,
  int retries = 3,
  bool Function(Object error)? retryable,
  bool Function(Object error)? rateLimited,
  Duration retryDelay = const Duration(seconds: 1),
  Duration rateLimitDelay = const Duration(seconds: 30),
  double? callsPerMinute,
  Duration? minInterval,
  Duration budgetWindow = const Duration(seconds: 62),
}) async {
  if (!latitudeDeg.isFinite || !longitudeDeg.isFinite || latitudeDeg.abs() > 90 || longitudeDeg.abs() > 180) throw const ClimateException('climate_bad_request', 'coordinates');
  final now = today ?? DateTime.now().toUtc();
  final first = math.max(firstYear, source.firstYear);
  if (lastYear < first) throw const ClimateException('climate_bad_request', 'years');
  final periods = climateRequestPeriods(source, first, lastYear, today: now);
  if (periods.isEmpty) throw const ClimateException('climate_no_data');
  final budget = callsPerMinute ?? source.callsPerMinute;
  final gap = minInterval ?? source.minInterval;
  final canRetry = retryable ?? (e) => e is! ClimateException;
  final isRateLimit = rateLimited ?? (e) => false;
  final sent = <(DateTime, double)>[];
  var lastStart = DateTime.fromMillisecondsSinceEpoch(0);
  final byDate = <DateTime, ClimateDay>{};
  double? elevation;
  onProgress?.call(0, periods.length);

  Future<void> pause(Duration d) async {
    if (d <= Duration.zero) return;
    onWait?.call(d);
    await Future<void>.delayed(d);
  }

  void checkCancel() {
    if (cancelled?.call() ?? false) throw const ClimateException('climate_cancelled');
  }

  for (var i = 0; i < periods.length; i++) {
    final (s, e) = periods[i];
    final url = climateRequestUrl(source, latitudeDeg, longitudeDeg, s, e, apiKey: apiKey);
    final weight = climateRequestWeight(source, s, e);
    for (var attempt = 0; ; attempt++) {
      checkCancel();
      if (budget > 0) {
        while (true) {
          final t = DateTime.now();
          sent.removeWhere((x) => t.difference(x.$1) >= budgetWindow);
          final used = sent.fold(0.0, (a, x) => a + x.$2);
          if (used + weight <= budget || sent.isEmpty) break;
          await pause(budgetWindow - t.difference(sent.first.$1) + const Duration(milliseconds: 200));
          checkCancel();
        }
        sent.add((DateTime.now(), weight));
      }
      if (gap > Duration.zero) {
        final wait = lastStart.add(gap).difference(DateTime.now());
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      lastStart = DateTime.now();
      try {
        final body = await fetch(url);
        checkCancel();
        final (days, elev) = climateParseResponse(source, body);
        elevation ??= elev;
        for (final d in days) {
          byDate[d.date] = d;
        }
        break;
      } catch (err) {
        if (err is ClimateException && err.code == 'climate_cancelled') rethrow;
        final limited = isRateLimit(err);
        if (attempt >= retries || !(limited || canRetry(err))) rethrow;
        if (limited) {
          // the service's minute is full: give it time to roll over
          await pause(rateLimitDelay * (attempt + 1));
        } else {
          await Future<void>.delayed(retryDelay * (1 << attempt));
        }
      }
    }
    onProgress?.call(i + 1, periods.length);
  }
  if (byDate.isEmpty) throw const ClimateException('climate_no_data');
  final days = byDate.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  return ClimateSeries(source: source, latitudeDeg: latitudeDeg, longitudeDeg: longitudeDeg, elevationM: elevation, days: days);
}

/// Monthly normal of a series (means of the daily values over the complete
/// months of every year; rain as monthly totals).
class MonthlyNormal {
  const MonthlyNormal({
    required this.month,
    required this.years,
    this.tMaxC,
    this.tMinC,
    this.tDewC,
    this.rhMaxPct,
    this.rhMinPct,
    this.rhMeanPct,
    this.windSpeed2mMs,
    this.solarMJm2Day,
    this.rainMeanMm,
    this.rainDependableMm,
    this.rainYearsMm = const [],
    this.etoServiceMmDay,
    this.etoPenmanMonteithMmDay,
  });

  /// 1–12.
  final int month;

  /// Complete years averaged.
  final int years;
  final double? tMaxC;
  final double? tMinC;
  final double? tDewC;
  final double? rhMaxPct;
  final double? rhMinPct;
  final double? rhMeanPct;
  final double? windSpeed2mMs;

  /// Mean daily solar radiation (MJ/m²/day).
  final double? solarMJm2Day;

  /// Mean monthly rain and the rain exceeded with the chosen probability
  /// (mm/month), and the monthly totals of every year (for other
  /// probabilities).
  final double? rainMeanMm;
  final double? rainDependableMm;
  final List<double> rainYearsMm;

  /// Mean daily ETo from the service (Open-Meteo) and from the FAO
  /// Penman-Monteith equation applied to every day (mm/day).
  final double? etoServiceMmDay;
  final double? etoPenmanMonteithMmDay;

  /// Mean daily solar radiation in kWh/m²/day.
  double? get solarKWhM2Day => solarMJm2Day == null ? null : solarMJm2Day! / mjPerKWh;

  /// ETo for design: the service's when given, else Penman-Monteith.
  double? get etoMmDay => etoServiceMmDay ?? etoPenmanMonteithMmDay;

  /// As FAO-56 monthly climate (null without temperatures).
  MonthlyClimate? toMonthlyClimate() {
    if (tMaxC == null || tMinC == null) return null;
    return MonthlyClimate(
      month: month,
      tMaxC: tMaxC!,
      tMinC: tMinC!,
      tDewC: tDewC,
      rhMaxPct: rhMaxPct,
      rhMinPct: rhMinPct,
      rhMeanPct: rhMeanPct,
      windSpeed2mMs: windSpeed2mMs,
      solarRadiationMJ: solarMJm2Day,
      rainMm: rainMeanMm ?? 0,
      dependableRainMm: rainDependableMm,
      etoMmDay: etoMmDay,
    );
  }
}

/// Monthly normals (January first) of [series]: a month of a year counts
/// when at least [minCompleteness] of its days have rain and temperatures;
/// [dependableProbability] sets the dependable rain (0.8 = exceeded in four
/// years out of five). Daily ETo is computed with the FAO Penman-Monteith
/// equation (climate.dart) wherever temperatures and radiation exist.
List<MonthlyNormal> climateMonthlyNormals(ClimateSeries series, {double dependableProbability = 0.8, double minCompleteness = 0.9}) =>
    monthlyNormalsOfDays(series.days, latitudeDeg: series.latitudeDeg, elevationM: series.elevationM ?? 0, dependableProbability: dependableProbability, minCompleteness: minCompleteness);

/// [climateMonthlyNormals] of daily values [days] of any source (1.6.0 AGR:
/// also the days of a weather station file) at [latitudeDeg] and
/// [elevationM].
List<MonthlyNormal> monthlyNormalsOfDays(List<ClimateDay> days, {required double latitudeDeg, double elevationM = 0, double dependableProbability = 0.8, double minCompleteness = 0.9}) {
  final elev = elevationM;
  final groups = <(int, int), List<ClimateDay>>{};
  for (final d in days) {
    (groups[(d.date.year, d.date.month)] ??= []).add(d);
  }
  final perMonth = <int, List<_MonthStats>>{};
  groups.forEach((ym, days) {
    final n = daysInMonth(ym.$1, ym.$2);
    final withRain = days.where((d) => d.rainMm != null).length;
    final withTemp = days.where((d) => d.tMaxC != null && d.tMinC != null).length;
    if (withRain < minCompleteness * n || withTemp < minCompleteness * n) return;
    (perMonth[ym.$2] ??= []).add(_MonthStats.of(days, latitudeDeg, elev, n));
  });
  final out = <MonthlyNormal>[];
  for (var m = 1; m <= 12; m++) {
    final list = perMonth[m] ?? const <_MonthStats>[];
    double? mean(double? Function(_MonthStats s) f) {
      final xs = [for (final s in list) f(s)].whereType<double>().toList();
      return xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;
    }

    final rains = [for (final s in list) s.rainMm];
    out.add(
      MonthlyNormal(
        month: m,
        years: list.length,
        tMaxC: mean((s) => s.tMaxC),
        tMinC: mean((s) => s.tMinC),
        tDewC: mean((s) => s.tDewC),
        rhMaxPct: mean((s) => s.rhMaxPct),
        rhMinPct: mean((s) => s.rhMinPct),
        rhMeanPct: mean((s) => s.rhMeanPct),
        windSpeed2mMs: mean((s) => s.wind),
        solarMJm2Day: mean((s) => s.solar),
        rainMeanMm: rains.isEmpty ? null : rains.reduce((a, b) => a + b) / rains.length,
        rainDependableMm: rainExceededWithProbability(rains, dependableProbability),
        rainYearsMm: rains,
        etoServiceMmDay: mean((s) => s.etoService),
        etoPenmanMonteithMmDay: mean((s) => s.etoPm),
      ),
    );
  }
  return out;
}

/// Climate normals for the requirement tables (ETo and rain per month); null
/// when a month has no ETo.
ClimateNormals? climateNormalsForRequirement(List<MonthlyNormal> normals, {bool preferPenmanMonteith = false}) {
  if (normals.length != 12) return null;
  final eto = <double>[], rain = <double>[], dep = <double>[];
  for (final n in normals) {
    final e = preferPenmanMonteith ? n.etoPenmanMonteithMmDay ?? n.etoServiceMmDay : n.etoMmDay;
    if (e == null) return null;
    eto.add(e);
    rain.add(n.rainMeanMm ?? 0);
    dep.add(n.rainDependableMm ?? n.rainMeanMm ?? 0);
  }
  return ClimateNormals(etoMmDay: eto, rainMm: rain, dependableRainMm: dep);
}

class _MonthStats {
  _MonthStats({required this.rainMm, this.tMaxC, this.tMinC, this.tDewC, this.rhMaxPct, this.rhMinPct, this.rhMeanPct, this.wind, this.solar, this.etoService, this.etoPm});

  final double rainMm;
  final double? tMaxC, tMinC, tDewC, rhMaxPct, rhMinPct, rhMeanPct, wind, solar, etoService, etoPm;

  static _MonthStats of(List<ClimateDay> days, double lat, double elev, int monthDays) {
    double? mean(double? Function(ClimateDay d) f) {
      final xs = [for (final d in days) f(d)].whereType<double>().toList();
      return xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;
    }

    final withRain = days.where((d) => d.rainMm != null).toList();
    // monthly total, scaled up for the few missing days
    final rain = withRain.isEmpty ? 0.0 : withRain.fold(0.0, (s, d) => s + d.rainMm!) * monthDays / withRain.length;
    final pm = <double>[];
    for (final d in days) {
      if (d.tMaxC == null || d.tMinC == null || d.solarMJm2 == null) continue;
      pm.add(
        fao56Eto(
          Fao56Input(
            latitudeDeg: lat,
            elevationM: elev,
            dayOfYear: dayOfYear(d.date),
            tMaxC: d.tMaxC!,
            tMinC: d.tMinC!,
            tDewC: d.tDewC,
            rhMaxPct: d.rhMaxPct,
            rhMinPct: d.rhMinPct,
            rhMeanPct: d.rhMeanPct,
            windSpeedMs: d.windSpeed2mMs,
            solarRadiationMJ: d.solarMJm2,
          ),
        ).etoMmDay,
      );
    }
    return _MonthStats(
      rainMm: rain,
      tMaxC: mean((d) => d.tMaxC),
      tMinC: mean((d) => d.tMinC),
      tDewC: mean((d) => d.tDewC),
      rhMaxPct: mean((d) => d.rhMaxPct),
      rhMinPct: mean((d) => d.rhMinPct),
      rhMeanPct: mean((d) => d.rhMeanPct),
      wind: mean((d) => d.windSpeed2mMs),
      solar: mean((d) => d.solarMJm2),
      etoService: mean((d) => d.etoMmDay),
      etoPm: pm.isEmpty ? null : pm.reduce((a, b) => a + b) / pm.length,
    );
  }
}
