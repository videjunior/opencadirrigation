/// The daily weather forecast of a site for the irrigation forecast (1.7.0 FCT): the request, the answer read into
/// days (from the hours of the forecast when the service gives hours), the reference evapotranspiration of each day,
/// and a polite fetch that keeps the answer for as long as it stays valid and never asks again before the service
/// allows. Pure Dart; the HTTP GET is injected by the app layer (lib/app/io/forecast_http.dart).
///
/// Sources (both keyless, worldwide, and answering simple cross-origin GET requests of a browser page with
/// `Access-Control-Allow-Origin: *`; checked with curl on 2026-11-10):
/// - MET Norway Locationforecast 2.0, product "complete" (api.met.no): about nine and a half days, hourly for the
///   first two to three days and every six hours after; instant air temperature, dew point, wind speed at 10 m and
///   cloud area fraction, the precipitation of the next 1 or 6 hours and the extreme temperatures of the next 6
///   hours. It has no solar radiation (MET plans to add it): the radiation of a day comes from its temperature range,
///   the procedure FAO-56 gives for missing radiation (eq. 50, kRs 0.16; [forecastDayEto]). The daylight cloud cover
///   is kept for the reader: through Kasten & Czeplak (1980), Rs = Rso·(1 − 0.75·C^3.4), it gave on the five whole
///   days of the recorded answer of the tests an ETo 19 % above the one Open-Meteo published for the same place and
///   days, against −1 % (mean absolute difference 0.3 mm/day) with eq. 50. Licence: Norwegian Licence for Open Government Data
///   2.0 and CC BY 4.0, which allow any use, commercial included, with the credit "MET Norway" and a mention of the
///   changes made (the app writes "Based on data from MET Norway": it turns the hours into daily values and ETo).
///   Terms of service (https://api.met.no/doc/TermsOfService, read on 2026-11-10): identify the client (a browser
///   page identifies itself by the Origin header it sends; desktop builds send a User-Agent with a contact), at most
///   4 decimals in the coordinates (5 or more answer 403), never repeat a request before the time of its `Expires`
///   header, send `If-Modified-Since` with the `Last-Modified` of the previous answer where the client can (a browser
///   page cannot: the header makes the request "non-simple", and the API answers no CORS preflight; the browser's own
///   HTTP cache revalidates), keep the total traffic of the application under 20 requests a second. "Low-volume
///   websites and mobile apps may use simple cross-origin Javascript requests"; the fully supported way is a proxy
///   (the app has no server, so it calls the API directly, only when the user asks, and keeps the answer). The FAQ of
///   Locationforecast asks to wait at least half the update interval (one hour in the Nordic area, six hours
///   elsewhere) before repeating: the app keeps an answer three hours ([ForecastSource.reuse]).
/// - Open-Meteo Forecast API (api.open-meteo.com): 16 days of daily values for the local days of the site (its time
///   zone), with the FAO-56 reference evapotranspiration the service computes from its hourly data
///   (`et0_fao_evapotranspiration`), used as given. The free API is for non-commercial use only (600 calls a minute,
///   5 000 an hour, 10 000 a day); commercial use needs a key of its paid plan. The data are CC BY 4.0: "Weather data
///   by Open-Meteo.com". It sends no caching header: the app keeps an answer one hour.
library;

import 'dart:convert';
import 'dart:math' as math;

import '../design/climate.dart';
import 'data_cache.dart';

/// The services the forecast can come from.
enum ForecastSource {
  metNorway(reuse: Duration(hours: 3)),
  openMeteo(reuse: Duration(hours: 1));

  const ForecastSource({required this.reuse});

  /// How long a kept answer is used before the service is asked again (never before its `Expires` time).
  final Duration reuse;

  /// Name of the service.
  String get label => switch (this) {
    ForecastSource.metNorway => 'MET Norway Locationforecast',
    ForecastSource.openMeteo => 'Open-Meteo Forecast API',
  };

  /// Host the requests go to (for the Content-Security-Policy and the privacy notice).
  String get host => switch (this) {
    ForecastSource.metNorway => 'api.met.no',
    ForecastSource.openMeteo => 'api.open-meteo.com',
  };

  /// The credit the licence asks for, as it asks for it (never translated).
  String get attribution => switch (this) {
    ForecastSource.metNorway => 'Based on data from MET Norway (Locationforecast 2.0, CC BY 4.0), turned into daily values and ETo',
    ForecastSource.openMeteo => 'Weather data by Open-Meteo.com (CC BY 4.0)',
  };

  /// The page of the terms of the service.
  String get termsUrl => switch (this) {
    ForecastSource.metNorway => 'https://api.met.no/doc/TermsOfService',
    ForecastSource.openMeteo => 'https://open-meteo.com/en/terms',
  };

  /// The free service allows professional (commercial) work.
  bool get commercialUse => this == ForecastSource.metNorway;
}

/// Error of a forecast fetch; [code] is a message code for the interface (`fc_bad_request`, `fc_no_site`,
/// `fc_network`, `fc_rate_limited`, `fc_forbidden`, `fc_service_error`, `fc_bad_response`), [detail] what the service
/// or the network said.
class ForecastException implements Exception {
  const ForecastException(this.code, [this.detail]);
  final String code;
  final String? detail;
  @override
  String toString() => detail == null || detail!.isEmpty ? code : '$code:$detail';
}

/// One day of the forecast at the site; [date] is the local date (UTC midnight of it). Null where the service gives
/// nothing.
class ForecastDay {
  const ForecastDay({
    required this.date,
    this.tMaxC,
    this.tMinC,
    this.tDewC,
    this.rhMaxPct,
    this.rhMinPct,
    this.windSpeed2mMs,
    this.cloudFraction,
    this.solarMJm2,
    this.rainMm = 0,
    this.etoServiceMmDay,
    this.coverageHours = 24,
  });
  final DateTime date;
  final double? tMaxC;
  final double? tMinC;

  /// Mean dew point of the day (°C).
  final double? tDewC;
  final double? rhMaxPct;
  final double? rhMinPct;

  /// Mean wind speed at 2 m (m/s; the 10 m wind converted with FAO-56 eq. 47).
  final double? windSpeed2mMs;

  /// Mean cloud area fraction of the daylight hours (0–1).
  final double? cloudFraction;

  /// Daily solar radiation the service gives (MJ/m²).
  final double? solarMJm2;
  final double rainMm;

  /// ETo the service gives (mm/day).
  final double? etoServiceMmDay;

  /// Hours of the day the forecast covers (24 for daily values).
  final double coverageHours;
}

/// The ETo of a forecast day and how it was found.
class ForecastEto {
  const ForecastEto(this.mmDay, {required this.byService, this.estimated = const {}});
  final double mmDay;

  /// Given by the service (else the FAO Penman-Monteith equation of climate.dart on the day's values).
  final bool byService;

  /// Data the Penman-Monteith calculation had to estimate (FAO-56 chapter 3): the radiation from the temperature
  /// range (eq. 50) when the service gives none.
  final Set<Fao56Estimate> estimated;

  /// The solar radiation came from the temperature range (FAO-56 eq. 50).
  bool get radiationFromTemperature => estimated.contains(Fao56Estimate.radiationFromTemperature);
}

/// The ETo of [d] at [latitudeDeg] and [elevationM]: the service's when it gives one, else FAO Penman-Monteith (FAO-56
/// eq. 6 through [fao56Eto]) on the day's values, with the service's solar radiation or, without it, the radiation
/// of the temperature range (FAO-56 eq. 50, kRs 0.16 for an interior site; limited to Rso); null without the day's
/// maximum and minimum temperature.
ForecastEto? forecastDayEto(ForecastDay d, {required double latitudeDeg, double elevationM = 0}) {
  if (d.etoServiceMmDay != null) return ForecastEto(math.max(d.etoServiceMmDay!, 0.0), byService: true);
  final tx = d.tMaxC, tn = d.tMinC;
  if (tx == null || tn == null) return null;
  final r = fao56Eto(
    Fao56Input(
      latitudeDeg: latitudeDeg,
      elevationM: elevationM,
      dayOfYear: dayOfYear(d.date),
      tMaxC: math.max(tx, tn),
      tMinC: math.min(tx, tn),
      tDewC: d.tDewC,
      rhMaxPct: d.rhMaxPct,
      rhMinPct: d.rhMinPct,
      windSpeedMs: d.windSpeed2mMs,
      solarRadiationMJ: d.solarMJm2,
    ),
  );
  return ForecastEto(r.etoMmDay, byService: false, estimated: r.estimated);
}

/// The forecast of one site.
class ForecastSeries {
  const ForecastSeries({
    required this.source,
    required this.latitudeDeg,
    required this.longitudeDeg,
    this.elevationM,
    required this.utcOffsetHours,
    this.updatedAt,
    required this.fetchedAt,
    this.expiresAt,
    required this.days,
    this.fromDevice = false,
    this.staleCode,
    this.deprecated = false,
  });
  final ForecastSource source;
  final double latitudeDeg;
  final double longitudeDeg;

  /// Elevation of the forecast point (m), when the service gives it.
  final double? elevationM;

  /// Hours from UTC of the local days: the site's time zone (Open-Meteo) or its solar time, longitude/15 (MET Norway,
  /// whose times are UTC).
  final double utcOffsetHours;

  /// When the service made the forecast (MET Norway's `updated_at`).
  final DateTime? updatedAt;

  /// When the answer came from the service (UTC).
  final DateTime fetchedAt;

  /// Before this time the service must not be asked again (its `Expires` header; UTC).
  final DateTime? expiresAt;
  final List<ForecastDay> days;

  /// The answer kept on the device was used (the service was not asked).
  final bool fromDevice;

  /// The kept answer stands in for a fetch that failed with this code.
  final String? staleCode;

  /// The service marked the product as deprecated (HTTP 203 of MET Norway).
  final bool deprecated;

  ForecastSeries copyWith({DateTime? fetchedAt, DateTime? expiresAt, bool? fromDevice, String? staleCode, bool? deprecated}) => ForecastSeries(
    source: source,
    latitudeDeg: latitudeDeg,
    longitudeDeg: longitudeDeg,
    elevationM: elevationM,
    utcOffsetHours: utcOffsetHours,
    updatedAt: updatedAt,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    expiresAt: expiresAt ?? this.expiresAt,
    days: days,
    fromDevice: fromDevice ?? this.fromDevice,
    staleCode: staleCode ?? this.staleCode,
    deprecated: deprecated ?? this.deprecated,
  );

  /// The local date at the site at [now].
  DateTime localDate(DateTime now) {
    final t = now.toUtc().add(Duration(minutes: (utcOffsetHours * 60).round()));
    return DateTime.utc(t.year, t.month, t.day);
  }

  /// The earliest time the service may be asked again: its `Expires`, else the fetch.
  DateTime get askAgainAfter => expiresAt ?? fetchedAt;
}

/// Coordinates cut (not rounded) to 4 decimals, as MET Norway asks.
String _coord4(double v) {
  final t = (v * 1e4).truncate() / 1e4;
  return t.toStringAsFixed(4);
}

/// Daily variables asked from Open-Meteo.
const openMeteoForecastDaily = [
  'et0_fao_evapotranspiration',
  'precipitation_sum',
  'temperature_2m_max',
  'temperature_2m_min',
  'dew_point_2m_mean',
  'relative_humidity_2m_max',
  'relative_humidity_2m_min',
  'wind_speed_10m_mean',
  'shortwave_radiation_sum',
];

/// The request of [source] for the point [latitudeDeg], [longitudeDeg] (coordinates cut to 4 decimals).
String forecastRequestUrl(ForecastSource source, double latitudeDeg, double longitudeDeg) => switch (source) {
  ForecastSource.metNorway => 'https://api.met.no/weatherapi/locationforecast/2.0/complete?lat=${_coord4(latitudeDeg)}&lon=${_coord4(longitudeDeg)}',
  ForecastSource.openMeteo =>
    'https://api.open-meteo.com/v1/forecast?latitude=${_coord4(latitudeDeg)}&longitude=${_coord4(longitudeDeg)}&daily=${openMeteoForecastDaily.join(',')}&timezone=auto&wind_speed_unit=ms&forecast_days=16',
};

double? _num(Object? v) {
  if (v is! num) return null;
  final x = v.toDouble();
  return x.isFinite ? x : null;
}

const _months = {'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, 'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12};

/// An HTTP date (`Tue, 10 Nov 2026 03:39:27 GMT`, RFC 9110 IMF-fixdate) in UTC; null when it is not one.
DateTime? parseHttpDate(String? s) {
  if (s == null) return null;
  final m = RegExp(r'(\d{1,2})[ -]([A-Za-z]{3})[ -](\d{2,4}) (\d{2}):(\d{2}):(\d{2})').firstMatch(s);
  if (m == null) return null;
  final month = _months[m.group(2)!.toLowerCase()];
  if (month == null) return null;
  var y = int.parse(m.group(3)!);
  if (y < 100) y += y < 70 ? 2000 : 1900;
  return DateTime.utc(y, month, int.parse(m.group(1)!), int.parse(m.group(4)!), int.parse(m.group(5)!), int.parse(m.group(6)!));
}

/// [t] (UTC) as an HTTP date.
String formatHttpDate(DateTime t) {
  final u = t.toUtc();
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String two(int v) => v.toString().padLeft(2, '0');
  return '${days[u.weekday - 1]}, ${two(u.day)} ${months[u.month - 1]} ${u.year} ${two(u.hour)}:${two(u.minute)}:${two(u.second)} GMT';
}

class _Acc {
  double hours = 0;
  double? tMax, tMin, rhMax, rhMin;
  double dew = 0, dewW = 0, wind = 0, windW = 0, cloudDay = 0, cloudDayW = 0, cloudAll = 0, cloudAllW = 0, rain = 0;

  void temp(double? v) {
    if (v == null) return;
    tMax = tMax == null ? v : math.max(tMax!, v);
    tMin = tMin == null ? v : math.min(tMin!, v);
  }
}

/// The days of a MET Norway Locationforecast answer [j]: every entry of the time series stands for the hours to the
/// next entry (at most six), and belongs to the local solar day (UTC + longitude/15 h) of the middle of those hours.
/// Per day: the extremes of the instant temperatures and of the 6-hour extremes, the means (weighted by hours) of
/// the dew point, of the wind (10 m, converted to 2 m by FAO-56 eq. 47) and of the cloud area fraction of the
/// daylight hours (FAO-56 eq. 34; of all hours when none is in daylight), the precipitation of the next hour where the
/// series is hourly and of the next six hours after, each period counted once in the day of its middle, and the hours
/// covered.
List<ForecastDay> metNorwayDays(Map<String, dynamic> j, {required double latitudeDeg, required double utcOffsetHours}) {
  final props = j['properties'];
  final ts = props is Map ? props['timeseries'] : null;
  if (ts is! List) throw const ForecastException('fc_bad_response');
  final entries = <(DateTime, Map<String, dynamic>)>[];
  for (final e in ts) {
    if (e is! Map) continue;
    final t = DateTime.tryParse('${e['time']}');
    final data = e['data'];
    if (t == null || data is! Map) continue;
    entries.add((t.toUtc(), Map<String, dynamic>.from(data)));
  }
  entries.sort((a, b) => a.$1.compareTo(b.$1));
  final offset = Duration(minutes: (utcOffsetHours * 60).round());
  DateTime dayOf(DateTime utc) {
    final l = utc.add(offset);
    return DateTime.utc(l.year, l.month, l.day);
  }

  double localHour(DateTime utc) {
    final l = utc.add(offset);
    return l.hour + l.minute / 60;
  }

  Map<String, dynamic>? details(Map<String, dynamic> data, String key) {
    final p = data[key];
    final d = p is Map ? p['details'] : null;
    return d is Map ? Map<String, dynamic>.from(d) : null;
  }

  final acc = <DateTime, _Acc>{};
  var coveredUntil = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  for (var i = 0; i < entries.length; i++) {
    final (t, data) = entries[i];
    final next1 = details(data, 'next_1_hours'), next6 = details(data, 'next_6_hours');
    final gap = i + 1 < entries.length ? entries[i + 1].$1.difference(t).inMinutes / 60 : (next6 != null ? 6.0 : 1.0);
    final step = gap.clamp(0.0, 6.0).toDouble();
    if (step <= 0) continue;
    final mid = t.add(Duration(minutes: (step * 30).round()));
    final day = dayOf(mid);
    final a = acc[day] ??= _Acc();
    a.hours += step;
    final inst = details(data, 'instant') ?? const <String, dynamic>{};
    final temp = _num(inst['air_temperature']);
    a.temp(temp);
    if (step >= 6 - 1e-9 && next6 != null) {
      a.temp(_num(next6['air_temperature_max']));
      a.temp(_num(next6['air_temperature_min']));
    }
    final dew = _num(inst['dew_point_temperature']);
    if (dew != null) {
      a.dew += dew * step;
      a.dewW += step;
    }
    final rh = _num(inst['relative_humidity']);
    if (rh != null) {
      a.rhMax = a.rhMax == null ? rh : math.max(a.rhMax!, rh);
      a.rhMin = a.rhMin == null ? rh : math.min(a.rhMin!, rh);
    }
    final w = _num(inst['wind_speed']);
    if (w != null) {
      a.wind += windSpeedAt2m(w, 10) * step;
      a.windW += step;
    }
    final cloud = _num(inst['cloud_area_fraction']);
    if (cloud != null) {
      final c = (cloud / 100).clamp(0.0, 1.0);
      a.cloudAll += c * step;
      a.cloudAllW += step;
      final n = daylightHours(latitudeDeg, dayOfYear(day));
      if ((localHour(mid) - 12).abs() < n / 2) {
        a.cloudDay += c * step;
        a.cloudDayW += step;
      }
    }
    // the precipitation of each period once: hourly where the series is hourly, else the next six hours
    if (!t.isBefore(coveredUntil)) {
      final p1 = next1 == null ? null : _num(next1['precipitation_amount']);
      final p6 = next6 == null ? null : _num(next6['precipitation_amount']);
      if (step <= 1 + 1e-9 && p1 != null) {
        a.rain += math.max(p1, 0.0);
        coveredUntil = t.add(const Duration(hours: 1));
      } else if (p6 != null) {
        (acc[dayOf(t.add(const Duration(hours: 3)))] ??= _Acc()).rain += math.max(p6, 0.0);
        coveredUntil = t.add(const Duration(hours: 6));
      } else if (p1 != null) {
        a.rain += math.max(p1, 0.0);
        coveredUntil = t.add(const Duration(hours: 1));
      }
    }
  }
  final days = acc.keys.toList()..sort();
  return [
    for (final d in days)
      () {
        final a = acc[d]!;
        return ForecastDay(
          date: d,
          tMaxC: a.tMax,
          tMinC: a.tMin,
          tDewC: a.dewW > 0 ? a.dew / a.dewW : null,
          rhMaxPct: a.rhMax,
          rhMinPct: a.rhMin,
          windSpeed2mMs: a.windW > 0 ? a.wind / a.windW : null,
          cloudFraction: a.cloudDayW > 0 ? a.cloudDay / a.cloudDayW : (a.cloudAllW > 0 ? a.cloudAll / a.cloudAllW : null),
          rainMm: a.rain,
          coverageHours: math.min(a.hours, 24.0),
        );
      }(),
  ];
}

/// The days of an Open-Meteo forecast answer [j] (daily values of the site's local days).
List<ForecastDay> openMeteoDays(Map<String, dynamic> j) {
  if (j['error'] == true) throw ForecastException('fc_service_error', j['reason']?.toString());
  final daily = j['daily'];
  if (daily is! Map || daily['time'] is! List) throw const ForecastException('fc_bad_response');
  final time = daily['time'] as List;
  List<Object?> col(String k) {
    final v = daily[k];
    return v is List && v.length == time.length ? v : List<Object?>.filled(time.length, null);
  }

  final units = j['daily_units'];
  final windUnit = units is Map ? units['wind_speed_10m_mean']?.toString() : null;
  final windFactor = switch (windUnit) {
    'km/h' => 1 / 3.6,
    'mp/h' || 'mph' => 0.44704,
    'kn' => 0.514444,
    _ => 1.0,
  };
  final eto = col('et0_fao_evapotranspiration'), rain = col('precipitation_sum'), tx = col('temperature_2m_max'), tn = col('temperature_2m_min');
  final dew = col('dew_point_2m_mean'), rhx = col('relative_humidity_2m_max'), rhn = col('relative_humidity_2m_min'), wind = col('wind_speed_10m_mean'), rs = col('shortwave_radiation_sum');
  final out = <ForecastDay>[];
  for (var i = 0; i < time.length; i++) {
    final d = DateTime.tryParse('${time[i]}');
    if (d == null) continue;
    // the last day of the horizon comes empty (nulls): no forecast for it
    if (_num(tx[i]) == null && _num(eto[i]) == null) continue;
    final w = _num(wind[i]);
    out.add(
      ForecastDay(
        date: DateTime.utc(d.year, d.month, d.day),
        tMaxC: _num(tx[i]),
        tMinC: _num(tn[i]),
        tDewC: _num(dew[i]),
        rhMaxPct: _num(rhx[i]),
        rhMinPct: _num(rhn[i]),
        windSpeed2mMs: w == null ? null : windSpeedAt2m(w * windFactor, 10),
        solarMJm2: _num(rs[i]),
        rainMm: math.max(_num(rain[i]) ?? 0, 0.0),
        etoServiceMmDay: _num(eto[i]),
      ),
    );
  }
  return out;
}

/// The answer [body] of [source] for the point asked, fetched at [fetchedAt].
ForecastSeries forecastParse(ForecastSource source, String body, {required double latitudeDeg, required double longitudeDeg, required DateTime fetchedAt, DateTime? expiresAt}) {
  final Object? j;
  try {
    j = jsonDecode(body);
  } on FormatException {
    throw const ForecastException('fc_bad_response');
  }
  if (j is! Map<String, dynamic>) throw const ForecastException('fc_bad_response');
  switch (source) {
    case ForecastSource.metNorway:
      final geometry = j['geometry'];
      final coords = geometry is Map ? geometry['coordinates'] : null;
      final elev = coords is List && coords.length > 2 ? _num(coords[2]) : null;
      final lon = coords is List && coords.isNotEmpty ? _num(coords[0]) ?? longitudeDeg : longitudeDeg;
      final lat = coords is List && coords.length > 1 ? _num(coords[1]) ?? latitudeDeg : latitudeDeg;
      final props = j['properties'];
      final meta = props is Map ? props['meta'] : null;
      final offset = lon / 15;
      return ForecastSeries(
        source: source,
        latitudeDeg: lat,
        longitudeDeg: lon,
        elevationM: elev,
        utcOffsetHours: offset,
        updatedAt: meta is Map ? DateTime.tryParse('${meta['updated_at']}')?.toUtc() : null,
        fetchedAt: fetchedAt.toUtc(),
        expiresAt: expiresAt?.toUtc(),
        days: metNorwayDays(j, latitudeDeg: lat, utcOffsetHours: offset),
      );
    case ForecastSource.openMeteo:
      final days = openMeteoDays(j);
      final off = _num(j['utc_offset_seconds']);
      return ForecastSeries(
        source: source,
        latitudeDeg: _num(j['latitude']) ?? latitudeDeg,
        longitudeDeg: _num(j['longitude']) ?? longitudeDeg,
        elevationM: _num(j['elevation']),
        utcOffsetHours: off == null ? longitudeDeg / 15 : off / 3600,
        fetchedAt: fetchedAt.toUtc(),
        expiresAt: expiresAt?.toUtc(),
        days: days,
      );
  }
}

// ---------------------------------------------------------------- fetch and keep

/// The answer of a GET: status, body and the caching headers (CORS lets a page read `Expires` and `Last-Modified`).
class ForecastHttpResponse {
  const ForecastHttpResponse(this.status, this.body, {this.expires, this.lastModified});
  final int status;
  final String body;
  final String? expires;
  final String? lastModified;
}

/// A GET of [url] with [headers]; throws only when the network fails (a status outside 2xx is an answer).
typedef ForecastGet = Future<ForecastHttpResponse> Function(String url, Map<String, String> headers);

/// Where answers are kept, by request address.
abstract class ForecastKeeper {
  Future<String?> read(String url);
  Future<void> write(String url, String value);
}

/// Answers kept in memory (one page; tests).
class MemoryForecastKeeper implements ForecastKeeper {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String url) async => values[url];
  @override
  Future<void> write(String url, String value) async => values[url] = value;
}

/// The memory of this page in front of the device's kept downloads (kind `forecast` of [DataCache]): an answer
/// survives a reload while keeping downloads is on, and the page still keeps it (the `Expires` rule holds) when it is
/// off.
class DataCacheForecastKeeper implements ForecastKeeper {
  DataCacheForecastKeeper(this.cache, {MemoryForecastKeeper? memory}) : memory = memory ?? MemoryForecastKeeper();
  final DataCache cache;
  final MemoryForecastKeeper memory;

  /// The kind of the kept downloads.
  static const kind = 'forecast';

  @override
  Future<String?> read(String url) async => await memory.read(url) ?? await cache.keptText(kind, url);
  @override
  Future<void> write(String url, String value) async {
    await memory.write(url, value);
    await cache.keepText(kind, url, value);
  }
}

class _Kept {
  const _Kept(this.body, this.fetched, this.expires, this.lastModified);
  final String body;
  final DateTime fetched;
  final DateTime? expires;
  final String? lastModified;

  static _Kept? of(String? s) {
    if (s == null) return null;
    try {
      final j = jsonDecode(s);
      if (j is! Map || j['body'] is! String) return null;
      final f = DateTime.tryParse('${j['fetched']}');
      if (f == null) return null;
      return _Kept(j['body'] as String, f.toUtc(), j['expires'] == null ? null : DateTime.tryParse('${j['expires']}')?.toUtc(), j['lastModified'] as String?);
    } on Object {
      return null;
    }
  }

  String encode() => jsonEncode({'v': 1, 'fetched': fetched.toIso8601String(), 'expires': ?expires?.toIso8601String(), 'lastModified': ?lastModified, 'body': body});
}

/// The forecast of [source] for the point [latitudeDeg], [longitudeDeg] through [get]:
/// - an answer kept in [keeper] is used while it stays valid: until its `Expires` time and at least
///   [ForecastSource.reuse] after it came;
/// - [refresh] asks the service again, but never before the `Expires` time of the kept answer (the terms of MET
///   Norway): until then the kept answer is given;
/// - with [conditional] (clients that may add headers: not a browser page), `If-Modified-Since` carries the
///   `Last-Modified` of the kept answer, and a 304 renews it; [userAgent] identifies the client;
/// - when the service cannot be reached or refuses, the kept answer is given with [ForecastSeries.staleCode], else
///   a [ForecastException] is thrown.
/// [clock] gives the time (tests).
Future<ForecastSeries> fetchForecast(
  ForecastSource source, {
  required double latitudeDeg,
  required double longitudeDeg,
  required ForecastGet get,
  ForecastKeeper? keeper,
  DateTime Function()? clock,
  bool refresh = false,
  bool conditional = false,
  String? userAgent,
}) async {
  if (!latitudeDeg.isFinite || !longitudeDeg.isFinite || latitudeDeg.abs() > 90 || longitudeDeg.abs() > 180) throw const ForecastException('fc_bad_request', 'coordinates');
  final url = forecastRequestUrl(source, latitudeDeg, longitudeDeg);
  final now = (clock ?? DateTime.now)().toUtc();
  _Kept? kept;
  try {
    kept = _Kept.of(await keeper?.read(url));
  } on Object {
    kept = null;
  }
  ForecastSeries keptSeries(_Kept k, {String? staleCode}) =>
      forecastParse(source, k.body, latitudeDeg: latitudeDeg, longitudeDeg: longitudeDeg, fetchedAt: k.fetched, expiresAt: k.expires).copyWith(fromDevice: true, staleCode: staleCode);
  Future<void> keep(_Kept k) async {
    try {
      await keeper?.write(url, k.encode());
    } on Object {
      // a full or blocked store keeps nothing: the answer still serves
    }
  }

  if (kept != null) {
    final hard = kept.expires ?? kept.fetched;
    final soft = kept.fetched.add(source.reuse);
    final until = hard.isAfter(soft) ? hard : soft;
    try {
      if (!refresh && now.isBefore(until)) return keptSeries(kept);
      if (refresh && now.isBefore(hard)) return keptSeries(kept);
    } on ForecastException {
      kept = null; // a kept answer that no longer reads is fetched again
    }
  }
  final headers = <String, String>{'User-Agent': ?userAgent, if (conditional && kept?.lastModified != null) 'If-Modified-Since': kept!.lastModified!};
  final ForecastHttpResponse r;
  try {
    r = await get(url, headers);
  } on ForecastException {
    rethrow;
  } on Object catch (e) {
    if (kept != null) return keptSeries(kept, staleCode: 'fc_network');
    throw ForecastException('fc_network', '$e');
  }
  final expires = parseHttpDate(r.expires);
  if (r.status == 304 && kept != null) {
    final renewed = _Kept(kept.body, now, expires ?? kept.expires, r.lastModified ?? kept.lastModified);
    await keep(renewed);
    return keptSeries(renewed).copyWith(fromDevice: false);
  }
  if (r.status < 200 || r.status >= 300) {
    final code = switch (r.status) {
      429 => 'fc_rate_limited',
      403 => 'fc_forbidden',
      _ => 'fc_service_error',
    };
    if (kept != null) return keptSeries(kept, staleCode: code);
    throw ForecastException(code, 'HTTP ${r.status}');
  }
  final ForecastSeries series;
  try {
    series = forecastParse(source, r.body, latitudeDeg: latitudeDeg, longitudeDeg: longitudeDeg, fetchedAt: now, expiresAt: expires);
  } on ForecastException catch (e) {
    if (kept != null) return keptSeries(kept, staleCode: e.code);
    rethrow;
  }
  if (series.days.isEmpty) {
    if (kept != null) return keptSeries(kept, staleCode: 'fc_bad_response');
    throw const ForecastException('fc_bad_response', 'no days');
  }
  await keep(_Kept(r.body, now, expires, r.lastModified));
  return r.status == 203 ? series.copyWith(deprecated: true) : series;
}
