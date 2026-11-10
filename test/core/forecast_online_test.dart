import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/climate.dart';
import 'package:opencadirrigation/core/io/data_cache.dart';
import 'package:opencadirrigation/core/io/forecast_online.dart';

/// The weather forecast of the irrigation forecast (1.7.0 FCT): the request, the recorded answers of MET Norway
/// (test/fixtures/forecast/met_locationforecast.json, the "complete" product for -22.7253, -47.6492 fetched on
/// 2026-11-10 03:00 UTC, trimmed to the variables read and to 2026-11-15 06:00) and of Open-Meteo, read into days, the
/// ETo of each day, and the fetch that keeps an answer for as long as it stays valid.
///
/// The daily values and ETo of the MET answer were worked out again by an independent script (Python, written from
/// FAO-56 and the aggregation rules of [metNorwayDays], not from the Dart code): 2026-11-10, local solar day, 24 h:
/// Tmax 26.3 °C, Tmin 14.9 °C, mean dew point 13.6833 °C, u2 2.6396 m/s (10 m wind by eq. 47), rain 0.10 mm,
/// Ra 41.167 MJ/m², Rs by eq. 50 22.240 MJ/m², ETo 4.9280 mm; 2026-11-12: rain 8.40 mm, ETo 4.2289 mm.
void main() {
  final metBody = File('test/fixtures/forecast/met_locationforecast.json').readAsStringSync();
  final omBody = File('test/fixtures/forecast/open_meteo_forecast.json').readAsStringSync();
  const lat = -22.7253, lon = -47.6492;
  final fetched = DateTime.utc(2026, 11, 10, 3);

  group('requests', () {
    test('coordinates cut (not rounded) to 4 decimals, as MET Norway asks; Open-Meteo in the local days of the site', () {
      expect(forecastRequestUrl(ForecastSource.metNorway, -22.72539, -47.64929), 'https://api.met.no/weatherapi/locationforecast/2.0/complete?lat=-22.7253&lon=-47.6492');
      expect(forecastRequestUrl(ForecastSource.metNorway, 59.91277, 10.75), contains('lat=59.9127&lon=10.7500'));
      final om = forecastRequestUrl(ForecastSource.openMeteo, lat, lon);
      expect(om, startsWith('https://api.open-meteo.com/v1/forecast?latitude=-22.7253&longitude=-47.6492&daily='));
      expect(om, contains('et0_fao_evapotranspiration'));
      expect(om, contains('timezone=auto'));
      expect(om, contains('forecast_days=16'));
      expect(ForecastSource.metNorway.commercialUse, isTrue);
      expect(ForecastSource.openMeteo.commercialUse, isFalse);
      expect(ForecastSource.metNorway.attribution, contains('MET Norway'));
      expect(ForecastSource.openMeteo.attribution, contains('Open-Meteo.com'));
    });

    test('HTTP dates', () {
      expect(parseHttpDate('Tue, 10 Nov 2026 03:39:27 GMT'), DateTime.utc(2026, 11, 10, 3, 39, 27));
      expect(parseHttpDate('Tuesday, 10-Nov-26 03:39:27 GMT'), DateTime.utc(2026, 11, 10, 3, 39, 27));
      expect(parseHttpDate('not a date'), isNull);
      expect(parseHttpDate(null), isNull);
      expect(formatHttpDate(DateTime.utc(2026, 1, 4, 7, 5, 9)), 'Sun, 04 Jan 2026 07:05:09 GMT');
      expect(parseHttpDate(formatHttpDate(DateTime.utc(2026, 11, 10, 3, 1, 58))), DateTime.utc(2026, 11, 10, 3, 1, 58));
    });
  });

  group('MET Norway answer', () {
    final s = forecastParse(ForecastSource.metNorway, metBody, latitudeDeg: lat, longitudeDeg: lon, fetchedAt: fetched);

    test('the point, its elevation and the local solar days (UTC + longitude/15)', () {
      expect(s.elevationM, 531);
      expect(s.utcOffsetHours, closeTo(-47.6492 / 15, 1e-9));
      expect(s.updatedAt, DateTime.utc(2026, 11, 10, 1, 18, 7));
      // 02:00 UTC is 22:49 of the 9th at the site: the first hour belongs to the day before
      expect([for (final d in s.days) d.date.day], [9, 10, 11, 12, 13, 14]);
      expect(s.days.first.coverageHours, 1);
      expect([for (final d in s.days.skip(1)) d.coverageHours], everyElement(24));
      expect(s.localDate(DateTime.utc(2026, 11, 10, 3, 30)), DateTime.utc(2026, 11, 10));
      expect(s.localDate(DateTime.utc(2026, 11, 10, 2, 30)), DateTime.utc(2026, 11, 9));
    });

    test('daily values and FAO-56 Penman-Monteith ETo against the independent calculation', () {
      final d = s.days.firstWhere((d) => d.date == DateTime.utc(2026, 11, 10));
      expect(d.tMaxC, 26.3);
      expect(d.tMinC, 14.9);
      expect(d.tDewC, closeTo(13.6833, 1e-4));
      expect(d.windSpeed2mMs, closeTo(2.6396, 1e-4));
      expect(d.rainMm, closeTo(0.10, 1e-9));
      expect(d.solarMJm2, isNull, reason: 'MET Norway gives no radiation');
      final e = forecastDayEto(d, latitudeDeg: s.latitudeDeg, elevationM: s.elevationM!)!;
      expect(e.byService, isFalse);
      expect(e.radiationFromTemperature, isTrue);
      expect(e.mmDay, closeTo(4.9280, 1e-3));
      expect(extraterrestrialRadiationMJ(s.latitudeDeg, dayOfYear(d.date)), closeTo(41.167, 1e-3));
      final wet = s.days.firstWhere((d) => d.date == DateTime.utc(2026, 11, 12));
      expect(wet.rainMm, closeTo(8.40, 1e-9));
      expect(forecastDayEto(wet, latitudeDeg: s.latitudeDeg, elevationM: 531)!.mmDay, closeTo(4.2289, 1e-3));
    });

    test('hourly and six-hourly steps: each period of rain once, in the day of its middle; the extremes of six hours', () {
      // lon 0: local = UTC. 22:00 and 23:00 hourly (1 mm each), then 6-hourly from 00:00 (6 mm, extremes 12/4 °C), a
      // last 06:00 entry with its six hours
      Map<String, Object?> e(String time, double temp, {double? p1, double? p6, double? tx, double? tn}) => {
        'time': time,
        'data': {
          'instant': {
            'details': {'air_temperature': temp, 'dew_point_temperature': temp - 5, 'wind_speed': 4.87 / 4.87, 'cloud_area_fraction': 50.0},
          },
          if (p1 != null)
            'next_1_hours': {
              'details': {'precipitation_amount': p1},
            },
          if (p6 != null)
            'next_6_hours': {
              'details': {'precipitation_amount': p6, 'air_temperature_max': ?tx, 'air_temperature_min': ?tn},
            },
        },
      };
      final body = jsonEncode({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [0.0, 45.0, 100],
        },
        'properties': {
          'meta': {'updated_at': '2026-03-01T20:00:00Z'},
          'timeseries': [
            e('2026-03-01T22:00:00Z', 8, p1: 1, p6: 50),
            e('2026-03-01T23:00:00Z', 7, p1: 1, p6: 50),
            e('2026-03-02T00:00:00Z', 6, p1: 9, p6: 6, tx: 12, tn: 4),
            e('2026-03-02T06:00:00Z', 5, p6: 3, tx: 11, tn: 3),
          ],
        },
      });
      final x = forecastParse(ForecastSource.metNorway, body, latitudeDeg: 45, longitudeDeg: 0, fetchedAt: DateTime.utc(2026, 3, 1, 21));
      expect(x.utcOffsetHours, 0);
      expect([for (final d in x.days) d.date], [DateTime.utc(2026, 3, 1), DateTime.utc(2026, 3, 2)]);
      final first = x.days.first, second = x.days.last;
      expect(first.coverageHours, 2);
      expect(first.rainMm, 2, reason: 'the hourly amounts, not the overlapping six-hour ones');
      expect(second.coverageHours, 12);
      expect(second.rainMm, 9, reason: 'the two six-hour periods (6 + 3), not the hourly 9 of the first 6-hourly entry');
      expect(second.tMaxC, 12);
      expect(second.tMinC, 3);
      expect(second.tDewC, closeTo(0.5, 1e-9));
      expect(second.windSpeed2mMs, closeTo(windSpeedAt2m(1, 10), 1e-12));
      expect(second.cloudFraction, closeTo(0.5, 1e-12));
    });

    test('answers that are not a forecast', () {
      expect(
        () => forecastParse(ForecastSource.metNorway, 'not json', latitudeDeg: lat, longitudeDeg: lon, fetchedAt: fetched),
        throwsA(isA<ForecastException>().having((e) => e.code, 'code', 'fc_bad_response')),
      );
      expect(() => forecastParse(ForecastSource.metNorway, '{"properties":{}}', latitudeDeg: lat, longitudeDeg: lon, fetchedAt: fetched), throwsA(isA<ForecastException>()));
      expect(
        () => forecastParse(ForecastSource.openMeteo, '{"error":true,"reason":"Latitude must be in range"}', latitudeDeg: lat, longitudeDeg: lon, fetchedAt: fetched),
        throwsA(isA<ForecastException>().having((e) => e.detail, 'detail', 'Latitude must be in range')),
      );
    });
  });

  group('Open-Meteo answer', () {
    final s = forecastParse(ForecastSource.openMeteo, omBody, latitudeDeg: lat, longitudeDeg: lon, fetchedAt: fetched);

    test('the local days of the site, its own ETo taken as published; the empty last day left out', () {
      expect(s.utcOffsetHours, -3);
      expect(s.elevationM, 527);
      expect(s.days, hasLength(15), reason: 'the 16th day comes as nulls');
      expect(s.days.first.date, DateTime.utc(2026, 11, 10));
      final e = forecastDayEto(s.days.first, latitudeDeg: s.latitudeDeg, elevationM: s.elevationM!)!;
      expect(e.byService, isTrue);
      expect(e.mmDay, 5.21);
      expect(s.days[2].rainMm, 10.5);
    });

    test('its ETo agrees with Penman-Monteith on its own daily values (the service works hour by hour)', () {
      var sum = 0.0, sumPm = 0.0;
      for (final d in s.days) {
        sum += d.etoServiceMmDay!;
        sumPm += forecastDayEto(
          ForecastDay(date: d.date, tMaxC: d.tMaxC, tMinC: d.tMinC, tDewC: d.tDewC, windSpeed2mMs: d.windSpeed2mMs, solarMJm2: d.solarMJm2),
          latitudeDeg: s.latitudeDeg,
          elevationM: s.elevationM!,
        )!.mmDay;
      }
      expect(sumPm / sum, closeTo(1, 0.08));
    });
  });

  group('fetch and keep', () {
    late DateTime now;
    late List<(String, Map<String, String>)> calls;
    late ForecastHttpResponse Function() answer;
    Future<ForecastHttpResponse> get(String url, Map<String, String> headers) async {
      calls.add((url, headers));
      return answer();
    }

    const expires = 'Tue, 10 Nov 2026 03:31:58 GMT';
    setUp(() {
      now = DateTime.utc(2026, 11, 10, 3);
      calls = [];
      answer = () => ForecastHttpResponse(200, metBody, expires: expires, lastModified: 'Tue, 10 Nov 2026 02:31:47 GMT');
    });

    Future<ForecastSeries> fetch(ForecastKeeper k, {bool refresh = false, bool conditional = false, String? userAgent}) =>
        fetchForecast(ForecastSource.metNorway, latitudeDeg: lat, longitudeDeg: lon, get: get, keeper: k, clock: () => now, refresh: refresh, conditional: conditional, userAgent: userAgent);

    test('a kept answer is used until its Expires and three hours after it came; then the service is asked again', () async {
      final k = MemoryForecastKeeper();
      final a = await fetch(k);
      expect(calls, hasLength(1));
      expect(a.fromDevice, isFalse);
      expect(a.expiresAt, DateTime.utc(2026, 11, 10, 3, 31, 58));
      expect(a.fetchedAt, now);
      now = now.add(const Duration(hours: 2));
      final b = await fetch(k);
      expect(calls, hasLength(1), reason: 'within the reuse window of MET Norway');
      expect(b.fromDevice, isTrue);
      expect(b.days, hasLength(a.days.length));
      now = DateTime.utc(2026, 11, 10, 6, 0, 1);
      await fetch(k);
      expect(calls, hasLength(2));
    });

    test('asking again is refused before Expires (the terms of MET Norway) and allowed after it', () async {
      final k = MemoryForecastKeeper();
      await fetch(k);
      now = DateTime.utc(2026, 11, 10, 3, 20);
      final early = await fetch(k, refresh: true);
      expect(calls, hasLength(1));
      expect(early.fromDevice, isTrue);
      expect(early.askAgainAfter, DateTime.utc(2026, 11, 10, 3, 31, 58));
      now = DateTime.utc(2026, 11, 10, 3, 32);
      final late = await fetch(k, refresh: true);
      expect(calls, hasLength(2));
      expect(late.fromDevice, isFalse);
    });

    test('a browser page adds no header; the desktop identifies itself and asks If-Modified-Since, a 304 renews the kept answer', () async {
      final k = MemoryForecastKeeper();
      await fetch(k);
      expect(calls.single.$2, isEmpty, reason: 'a header would make the request non-simple (a preflight MET Norway does not answer)');
      now = DateTime.utc(2026, 11, 10, 7);
      answer = () => const ForecastHttpResponse(304, '', expires: 'Tue, 10 Nov 2026 07:30:00 GMT');
      final r = await fetch(k, conditional: true, userAgent: 'OpenCADIrrigation/1.7 github.com/videjunior/opencadirrigation');
      expect(calls.last.$2, {'User-Agent': 'OpenCADIrrigation/1.7 github.com/videjunior/opencadirrigation', 'If-Modified-Since': 'Tue, 10 Nov 2026 02:31:47 GMT'});
      expect(r.days, isNotEmpty);
      expect(r.fetchedAt, now);
      expect(r.expiresAt, DateTime.utc(2026, 11, 10, 7, 30));
      expect(r.fromDevice, isFalse);
    });

    test('failures: an error code without a kept answer, the kept answer marked stale with one', () async {
      Future<String> code(ForecastHttpResponse Function() a) async {
        answer = a;
        try {
          await fetch(MemoryForecastKeeper());
          return 'none';
        } on ForecastException catch (e) {
          return e.code;
        }
      }

      expect(await code(() => const ForecastHttpResponse(429, 'slow down')), 'fc_rate_limited');
      expect(await code(() => const ForecastHttpResponse(403, 'forbidden')), 'fc_forbidden');
      expect(await code(() => const ForecastHttpResponse(500, 'oops')), 'fc_service_error');
      expect(await code(() => const ForecastHttpResponse(200, '<html>')), 'fc_bad_response');
      expect(await code(() => throw const SocketException('offline')), 'fc_network');
      expect(() => fetchForecast(ForecastSource.metNorway, latitudeDeg: 95, longitudeDeg: 0, get: get), throwsA(isA<ForecastException>().having((e) => e.code, 'code', 'fc_bad_request')));
      final k = MemoryForecastKeeper();
      answer = () => ForecastHttpResponse(200, metBody, expires: expires);
      await fetch(k);
      now = DateTime.utc(2026, 11, 10, 9);
      answer = () => throw const SocketException('offline');
      final stale = await fetch(k);
      expect(stale.staleCode, 'fc_network');
      expect(stale.fromDevice, isTrue);
      expect(stale.days, isNotEmpty);
      answer = () => const ForecastHttpResponse(429, '');
      expect((await fetch(k)).staleCode, 'fc_rate_limited');
    });

    test('HTTP 203 (a deprecated product) still serves, marked', () async {
      answer = () => ForecastHttpResponse(203, metBody);
      final s = await fetch(MemoryForecastKeeper());
      expect(s.deprecated, isTrue);
      expect(s.expiresAt, isNull);
    });

    test('kept on the device: survives the page (a new memory) while keeping downloads is on', () async {
      final store = MemoryDataCacheStore();
      final cache = DataCache(store);
      await fetch(DataCacheForecastKeeper(cache));
      expect(store.values.keys.single, startsWith('forecast:https://api.met.no/'));
      expect((await cache.stats('forecast')).count, 1);
      now = now.add(const Duration(hours: 1));
      final again = await fetch(DataCacheForecastKeeper(cache));
      expect(calls, hasLength(1));
      expect(again.fromDevice, isTrue);
      // keeping off: the device is neither read nor written, the memory of the page still keeps the rule
      cache.enabled = false;
      final memory = MemoryForecastKeeper();
      await fetch(DataCacheForecastKeeper(cache, memory: memory));
      expect(calls, hasLength(2));
      await fetch(DataCacheForecastKeeper(cache, memory: memory));
      expect(calls, hasLength(2));
      await cache.clear('forecast');
      expect(store.values, isEmpty);
    });
  });
}
