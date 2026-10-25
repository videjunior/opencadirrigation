import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/climate.dart';
import 'package:opencadirrigation/core/io/climate_online.dart';

/// Online climate download with canned answers (no network): request URLs
/// and weights, parsing of Open-Meteo and NASA POWER answers, the paced
/// download with retries, rate limits and cancellation, and the monthly
/// normals with the dependable rain.
void main() {
  // shapes of real answers (October 2026), shortened
  const openMeteoBody = '{"latitude":-22.88225,"longitude":-47.01773,"generationtime_ms":0.18,"utc_offset_seconds":-10800,"timezone":"America/Sao_Paulo","timezone_abbreviation":"GMT-3","elevation":667.0,'
      '"daily_units":{"time":"iso8601","et0_fao_evapotranspiration":"mm","precipitation_sum":"mm","temperature_2m_max":"°C","temperature_2m_min":"°C","wind_speed_10m_mean":"m/s","shortwave_radiation_sum":"MJ/m²","relative_humidity_2m_max":"%","relative_humidity_2m_min":"%","dew_point_2m_mean":"°C"},'
      '"daily":{"time":["2024-01-01","2024-01-02","2024-01-03"],"et0_fao_evapotranspiration":[5.67,5.50,null],"precipitation_sum":[1.00,1.40,26.30],"temperature_2m_max":[28.3,30.0,31.4],"temperature_2m_min":[19.1,18.6,19.6],'
      '"wind_speed_10m_mean":[3.22,2.60,3.21],"shortwave_radiation_sum":[25.41,25.68,24.93],"relative_humidity_2m_max":[83,89,95],"relative_humidity_2m_min":[50,48,49],"dew_point_2m_mean":[17.1,17.6,19.5]}}';
  const powerBody = '{"type":"Feature","geometry":{"type":"Point","coordinates":[-47.06,-22.9,755.36]},"properties":{"parameter":{'
      '"T2M_MAX":{"20240101":33.75,"20240102":33.86},"T2M_MIN":{"20240101":18.08,"20240102":19.35},"T2MDEW":{"20240101":15.71,"20240102":16.99},"RH2M":{"20240101":61.41,"20240102":64.4},'
      '"WS2M":{"20240101":2.22,"20240102":1.85},"PRECTOTCORR":{"20240101":0.12,"20240102":0.85},"ALLSKY_SFC_SW_DWN":{"20240101":20.37,"20240102":-999.0}}},'
      '"header":{"title":"NASA/POWER Source Native Resolution Daily Data","api":{"version":"v2.10.1","name":"POWER Daily API"},"fill_value":-999.0,"time_standard":"LST","start":"20240101","end":"20240102"},"messages":[]}';

  group('requests', () {
    test('URLs of both services', () {
      final om = climateRequestUrl(ClimateSource.openMeteo, -22.9, -47.06, DateTime.utc(2001), DateTime.utc(2001, 12, 31));
      final u = Uri.parse(om);
      expect(u.host, 'archive-api.open-meteo.com');
      expect(u.path, '/v1/archive');
      expect(u.queryParameters['start_date'], '2001-01-01');
      expect(u.queryParameters['end_date'], '2001-12-31');
      expect(u.queryParameters['latitude'], '-22.9000');
      expect(u.queryParameters['daily']!.split(','), containsAll(['et0_fao_evapotranspiration', 'precipitation_sum', 'shortwave_radiation_sum', 'wind_speed_10m_mean']));
      expect(u.queryParameters['wind_speed_unit'], 'ms');
      expect(u.queryParameters['timezone'], 'auto');
      final paid = Uri.parse(climateRequestUrl(ClimateSource.openMeteo, 0, 0, DateTime.utc(2001), DateTime.utc(2001, 1, 7), apiKey: 'k&1'));
      expect(paid.host, 'customer-archive-api.open-meteo.com');
      expect(paid.queryParameters['apikey'], 'k&1');
      final power = Uri.parse(climateRequestUrl(ClimateSource.nasaPower, -22.9, -47.06, DateTime.utc(1990), DateTime.utc(1994, 12, 31)));
      expect(power.host, 'power.larc.nasa.gov');
      expect(power.path, '/api/temporal/daily/point');
      expect(power.queryParameters['start'], '19900101');
      expect(power.queryParameters['end'], '19941231');
      expect(power.queryParameters['community'], 'AG');
      expect(power.queryParameters['parameters']!.split(','), containsAll(['T2M_MAX', 'T2M_MIN', 'PRECTOTCORR', 'ALLSKY_SFC_SW_DWN', 'WS2M']));
    });

    test('periods are chunked and stop before the archive lag', () {
      final today = DateTime.utc(2003, 3, 10);
      final om = climateRequestPeriods(ClimateSource.openMeteo, 2000, 2003, today: today);
      expect(om, hasLength(4));
      expect(om.last.$1, DateTime.utc(2003));
      expect(om.last.$2, DateTime.utc(2003, 3, 4));
      final pw = climateRequestPeriods(ClimateSource.nasaPower, 1990, 2001, today: today);
      expect(pw.map((p) => (p.$1.year, p.$2.year)).toList(), [(1990, 1994), (1995, 1999), (2000, 2001)]);
      expect(climateRequestPeriods(ClimateSource.openMeteo, 2030, 2031, today: today), isEmpty);
    });

    test('weights follow the Open-Meteo counting (variables/10 × days/14)', () {
      expect(climateRequestWeight(ClimateSource.openMeteo, DateTime.utc(2001), DateTime.utc(2001, 12, 31)), closeTo(365 / 14, 1e-9));
      expect(climateRequestWeight(ClimateSource.openMeteo, DateTime.utc(2001), DateTime.utc(2001, 1, 7)), 1);
      expect(climateRequestWeight(ClimateSource.nasaPower, DateTime.utc(1990), DateTime.utc(1994, 12, 31)), 1);
    });

    test('attribution lines', () {
      expect(ClimateSource.openMeteo.attribution, contains('Open-Meteo.com'));
      expect(ClimateSource.openMeteo.attribution, contains('CC BY 4.0'));
      expect(ClimateSource.nasaPower.attribution, contains('Prediction Of Worldwide Energy Resources (POWER)'));
      expect(ClimateSource.values.every((s) => s.browserOk), isTrue);
    });
  });

  group('parsing', () {
    test('Open-Meteo daily answer; 10 m wind converted to 2 m; nulls kept', () {
      final (days, elev) = climateParseResponse(ClimateSource.openMeteo, openMeteoBody);
      expect(elev, 667);
      expect(days, hasLength(3));
      expect(days.first.date, DateTime.utc(2024));
      expect(days.first.etoMmDay, 5.67);
      expect(days.last.etoMmDay, isNull);
      expect(days[2].rainMm, 26.3);
      expect(days.first.windSpeed2mMs, closeTo(3.22 * 0.748, 0.001));
      expect(days.first.rhMinPct, 50);
      expect(days.first.tDewC, 17.1);
      expect(days.first.solarMJm2, 25.41);
    });

    test('NASA POWER daily answer with fill values', () {
      final (days, elev) = climateParseResponse(ClimateSource.nasaPower, powerBody);
      expect(elev, 755.36);
      expect(days.map((d) => d.date).toList(), [DateTime.utc(2024), DateTime.utc(2024, 1, 2)]);
      expect(days.first.tMaxC, 33.75);
      expect(days.first.rhMeanPct, 61.41);
      expect(days.first.windSpeed2mMs, 2.22);
      expect(days[1].solarMJm2, isNull); // −999
      expect(days.first.etoMmDay, isNull);
    });

    test('errors become message codes', () {
      Matcher code(String c, [String? detail]) => isA<ClimateException>().having((e) => e.code, 'code', c).having((e) => e.detail, 'detail', detail);
      expect(() => climateParseResponse(ClimateSource.openMeteo, '{"error":true,"reason":"Cannot initialize WeatherVariable"}'), throwsA(code('climate_service_error', 'Cannot initialize WeatherVariable')));
      expect(() => climateParseResponse(ClimateSource.nasaPower, '{"header":"The POWER Daily API failed","messages":["One of your parameters is incorrect: BADPARAM."]}'), throwsA(code('climate_service_error', 'One of your parameters is incorrect: BADPARAM.')));
      expect(() => climateParseResponse(ClimateSource.openMeteo, '<html>502</html>'), throwsA(code('climate_bad_response')));
      expect(() => climateParseResponse(ClimateSource.nasaPower, '[]'), throwsA(code('climate_bad_response')));
      expect(const ClimateException('climate_service_error', 'x').toString(), 'climate_service_error:x');
    });
  });

  group('download and normals', () {
    /// Synthetic Open-Meteo server: January rain of (year − 2000) mm/day,
    /// 2 mm/day in other months, steady weather otherwise.
    String fakeOpenMeteo(String url) {
      final q = Uri.parse(url).queryParameters;
      final s = DateTime.parse(q['start_date']!), e = DateTime.parse(q['end_date']!);
      final time = <String>[], rain = <double>[];
      for (var d = DateTime.utc(s.year, s.month, s.day); !d.isAfter(DateTime.utc(e.year, e.month, e.day)); d = d.add(const Duration(days: 1))) {
        time.add(d.toIso8601String().substring(0, 10));
        rain.add(d.month == 1 ? (d.year - 2000).toDouble() : 2);
      }
      List<double> f(double v) => List.filled(time.length, v);
      return jsonEncode({
        'elevation': 600,
        'daily_units': {'wind_speed_10m_mean': 'm/s'},
        'daily': {'time': time, 'et0_fao_evapotranspiration': f(5), 'precipitation_sum': rain, 'temperature_2m_max': f(30), 'temperature_2m_min': f(18), 'wind_speed_10m_mean': f(3), 'shortwave_radiation_sum': f(20), 'relative_humidity_2m_max': f(90), 'relative_humidity_2m_min': f(40), 'dew_point_2m_mean': f(15)},
      });
    }

    test('three years, paced, merged and turned into monthly normals', () async {
      final progress = <(int, int)>[];
      final waits = <Duration>[];
      final s = await climateDownload(
        ClimateSource.openMeteo,
        latitudeDeg: -22.9,
        longitudeDeg: -47.06,
        firstYear: 2001,
        lastYear: 2003,
        today: DateTime.utc(2026, 10, 25),
        fetch: (url) async => fakeOpenMeteo(url),
        onProgress: (d, t) => progress.add((d, t)),
        onWait: waits.add,
        // a year weighs 26 calls: the second request waits for the window
        callsPerMinute: 30,
        budgetWindow: const Duration(milliseconds: 30),
      );
      expect(s.days, hasLength(365 * 3));
      expect(s.elevationM, 600);
      expect(progress.last, (3, 3));
      expect(waits, isNotEmpty);
      final normals = climateMonthlyNormals(s);
      expect(normals, hasLength(12));
      final jan = normals.first;
      expect(jan.years, 3);
      expect(jan.rainYearsMm, [31, 62, 93]);
      expect(jan.rainMeanMm, closeTo(62, 1e-9));
      expect(jan.rainDependableMm, closeTo(31, 1e-9)); // four years in five, three years: the driest
      expect(normals[5].rainMeanMm, closeTo(60, 1e-9));
      expect(jan.etoServiceMmDay, closeTo(5, 1e-9));
      expect(jan.etoPenmanMonteithMmDay, inExclusiveRange(2, 9));
      expect(jan.windSpeed2mMs, closeTo(windSpeedAt2m(3, 10), 1e-9));
      expect(jan.solarKWhM2Day, closeTo(20 / 3.6, 1e-9));
      final c = jan.toMonthlyClimate()!;
      expect(c.tMaxC, 30);
      expect(c.etoMmDay, 5);
      final req = climateNormalsForRequirement(normals)!;
      expect(req.etoMmDay, everyElement(5));
      expect(req.rainMm.first, closeTo(62, 1e-9));
      expect(req.dependableRainMm!.first, closeTo(31, 1e-9));
      expect(climateNormalsForRequirement(normals, preferPenmanMonteith: true)!.etoMmDay.first, closeTo(jan.etoPenmanMonteithMmDay!, 1e-12));
    });

    test('incomplete months are left out of the normals', () async {
      final s = await climateDownload(ClimateSource.openMeteo, latitudeDeg: 0, longitudeDeg: 0, firstYear: 2003, lastYear: 2003, today: DateTime.utc(2003, 3, 10), fetch: (url) async => fakeOpenMeteo(url));
      expect(s.days.last.date, DateTime.utc(2003, 3, 4));
      final n = climateMonthlyNormals(s);
      expect(n[0].years, 1);
      expect(n[1].years, 1);
      expect(n[2].years, 0); // 4 of 31 days
      expect(n[2].rainMeanMm, isNull);
      expect(climateNormalsForRequirement(n), isNull);
    });

    test('transient errors are retried, rate limits wait, service errors are not retried', () async {
      var calls = 0;
      final s = await climateDownload(ClimateSource.openMeteo, latitudeDeg: 0, longitudeDeg: 0, firstYear: 2001, lastYear: 2001, today: DateTime.utc(2026), retryDelay: const Duration(milliseconds: 1), fetch: (url) async {
        if (calls++ == 0) throw StateError('connection reset');
        return fakeOpenMeteo(url);
      });
      expect(calls, 2);
      expect(s.days, hasLength(365));

      final waits = <Duration>[];
      var limited = 0;
      await climateDownload(ClimateSource.openMeteo, latitudeDeg: 0, longitudeDeg: 0, firstYear: 2001, lastYear: 2001, today: DateTime.utc(2026), rateLimited: (e) => e is _TooManyRequests, rateLimitDelay: const Duration(milliseconds: 2), onWait: waits.add, fetch: (url) async {
        if (limited++ == 0) throw const _TooManyRequests();
        return fakeOpenMeteo(url);
      });
      expect(waits, [const Duration(milliseconds: 2)]);

      var serviceCalls = 0;
      await expectLater(
        climateDownload(ClimateSource.openMeteo, latitudeDeg: 0, longitudeDeg: 0, firstYear: 2001, lastYear: 2001, today: DateTime.utc(2026), fetch: (url) async {
          serviceCalls++;
          return '{"error":true,"reason":"bad"}';
        }),
        throwsA(isA<ClimateException>().having((e) => e.code, 'code', 'climate_service_error')),
      );
      expect(serviceCalls, 1);
    });

    test('cancellation and bad requests', () async {
      var n = 0;
      await expectLater(
        climateDownload(ClimateSource.openMeteo, latitudeDeg: 0, longitudeDeg: 0, firstYear: 2001, lastYear: 2003, today: DateTime.utc(2026), cancelled: () => n > 0, fetch: (url) async {
          n++;
          return fakeOpenMeteo(url);
        }),
        throwsA(isA<ClimateException>().having((e) => e.code, 'code', 'climate_cancelled')),
      );
      expect(n, 1);
      await expectLater(climateDownload(ClimateSource.openMeteo, latitudeDeg: 95, longitudeDeg: 0, firstYear: 2001, lastYear: 2001, fetch: (url) async => ''), throwsA(isA<ClimateException>().having((e) => e.code, 'code', 'climate_bad_request')));
      await expectLater(climateDownload(ClimateSource.nasaPower, latitudeDeg: 0, longitudeDeg: 0, firstYear: 1975, lastYear: 1970, fetch: (url) async => ''), throwsA(isA<ClimateException>().having((e) => e.code, 'code', 'climate_bad_request')));
      await expectLater(climateDownload(ClimateSource.openMeteo, latitudeDeg: 0, longitudeDeg: 0, firstYear: 2030, lastYear: 2031, today: DateTime.utc(2026), fetch: (url) async => ''), throwsA(isA<ClimateException>().having((e) => e.code, 'code', 'climate_no_data')));
    });

    test('NASA POWER series: Penman-Monteith ETo from the daily variables', () async {
      String fakePower(String url) {
        final q = Uri.parse(url).queryParameters;
        final s = DateTime.parse('${q['start']!.substring(0, 4)}-${q['start']!.substring(4, 6)}-${q['start']!.substring(6)}');
        final e = DateTime.parse('${q['end']!.substring(0, 4)}-${q['end']!.substring(4, 6)}-${q['end']!.substring(6)}');
        final keys = <String>[];
        for (var d = DateTime.utc(s.year, s.month, s.day); !d.isAfter(DateTime.utc(e.year, e.month, e.day)); d = d.add(const Duration(days: 1))) {
          keys.add(d.toIso8601String().substring(0, 10).replaceAll('-', ''));
        }
        Map<String, double> f(double v) => {for (final k in keys) k: v};
        return jsonEncode({
          'geometry': {'coordinates': [-47.06, -22.9, 755.36]},
          'header': {'fill_value': -999.0},
          'properties': {'parameter': {'T2M_MAX': f(30), 'T2M_MIN': f(18), 'T2MDEW': f(15), 'RH2M': f(65), 'WS2M': f(2), 'PRECTOTCORR': f(3), 'ALLSKY_SFC_SW_DWN': f(20)}},
        });
      }

      final s = await climateDownload(ClimateSource.nasaPower, latitudeDeg: -22.9, longitudeDeg: -47.06, firstYear: 2001, lastYear: 2002, today: DateTime.utc(2026), minInterval: Duration.zero, fetch: (url) async => fakePower(url));
      expect(s.elevationM, 755.36);
      final n = climateMonthlyNormals(s);
      expect(n.first.etoServiceMmDay, isNull);
      final expected = fao56Eto(Fao56Input(latitudeDeg: -22.9, elevationM: 755.36, dayOfYear: 1, tMaxC: 30, tMinC: 18, tDewC: 15, rhMeanPct: 65, windSpeedMs: 2, solarRadiationMJ: 20)).etoMmDay;
      expect(n.first.etoPenmanMonteithMmDay, closeTo(expected, 0.05)); // January days differ only in geometry
      expect(n.first.etoMmDay, n.first.etoPenmanMonteithMmDay);
      expect(n.first.rainMeanMm, closeTo(93, 1e-9));
    });
  });
}

class _TooManyRequests implements Exception {
  const _TooManyRequests();
}
