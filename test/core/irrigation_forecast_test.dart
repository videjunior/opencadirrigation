import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/design/irrigation_forecast.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/io/forecast_online.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/core/model/site_climate.dart';
import 'package:opencadirrigation/core/units.dart';

/// The irrigation forecast (1.7.0 FCT), checked by hand on an area of Kc 1 (no crop of the table), AWC 100 mm/m,
/// Zr 1 m (TAW 100 mm), p 0.5 (RAW 50 mm), Ea 0.8, sprinkler, ETo 5 mm/day typed on the area (the design month):
/// the programme irrigates every 10 days (RAW / ETc = 50 / 5) with 50 mm net, 62.5 mm gross; four 12F sprays on
/// 100 m² apply 24 mm/h, so one event runs 62.5 / 24 h = 156.25 min.
void main() {
  const square = [Pt(0, 0), Pt(10, 0), Pt(10, 10), Pt(0, 10)];
  Project project({String crop = '', double lat = -22.9, double lon = -47.1}) {
    final p = Project(
      entities: [
        AreaEntity(id: 'a', name: 'Block A', points: square, cropKey: crop, useWaterBalance: true, etoMmDay: 5, kc: 1, awcMmPerM: 100, rootDepthM: 1, mad: 0.5, efficiency: 0.8),
        for (final (x, y) in const [(2.5, 2.5), (7.5, 2.5), (2.5, 7.5), (7.5, 7.5)]) OutletEntity(id: 's$x$y', position: Pt(x, y), outletSpecId: 'spray', nozzleId: 's12', headM: 20),
      ],
    );
    p.meta.georef = GeoReference.fromLatLonOrigin(lat, lon);
    return p;
  }

  // daily values with the service's ETo (as Open-Meteo gives them), local days at UTC−3
  ForecastSeries series(DateTime first, List<double> eto, List<double> rain, {double lat = -22.9, double offset = -3}) => ForecastSeries(
    source: ForecastSource.openMeteo,
    latitudeDeg: lat,
    longitudeDeg: offset * 15,
    utcOffsetHours: offset,
    fetchedAt: first,
    days: [
      for (var i = 0; i < eto.length; i++)
        ForecastDay(
          date: first.add(Duration(days: i)),
          etoServiceMmDay: eto[i],
          rainMm: rain[i],
          tMaxC: 30,
          tMinC: 18,
        ),
    ],
  );
  final nov10 = DateTime.utc(2026, 11, 10);
  final morning = DateTime.utc(2026, 11, 10, 12); // 09:00 at the site
  final dry = series(nov10, List.filled(7, 10.0), List.filled(7, 0.0));

  group('the balance forward', () {
    test('the programme of the design and the application rate of the area', () {
      final f = irrigationForecast(project(), null, dry, now: morning);
      final a = f.areas.single;
      expect(a.balance, isTrue);
      expect(a.rateMmH, closeTo(24, 1e-6));
      expect(a.programmeNetMm, closeTo(50, 1e-9));
      expect(a.programmeGrossMm, closeTo(62.5, 1e-9));
      expect(60 * a.programmeHours!, closeTo(156.25, 1e-6));
      expect(a.intervalDays, 10);
      expect(a.designNetMmDay, closeTo(5, 1e-9));
      expect(f.today, nov10);
      expect(f.days, hasLength(7));
      expect(f.warnings, contains('fct_no_results'));
    });

    test('the deficit carries over: 10 mm a day, irrigated on the fifth day when the soil lost one event (50 mm)', () {
      final a = irrigationForecast(project(), null, dry, now: morning).areas.single;
      expect([for (final d in a.days) d.depletionMm], [10, 20, 30, 40, 50, 10, 20]);
      expect([for (final d in a.days) d.irrigate], [false, false, false, false, true, false, false]);
      final day = a.days[4];
      expect(day.date, DateTime.utc(2026, 11, 14));
      expect(day.netMm, closeTo(50, 1e-9));
      expect(day.grossMm, closeTo(62.5, 1e-9));
      expect(60 * day.runHours!, closeTo(156.25, 1e-6));
      expect(day.eventPct, closeTo(100, 1e-9));
      expect(day.endDepletionMm, 0);
      expect(a.days.every((d) => d.etaMm == d.etcMm), isTrue, reason: 'never past RAW: no stress');
      // the crop uses 70 mm in 7 days, the programme gives 5 mm/day: 200 %
      expect(a.budgetPct, closeTo(200, 1e-9));
    });

    test('rain skips: 35 mm on the third day fills the soil (5 mm percolate) and the next irrigation waits', () {
      final wet = series(nov10, List.filled(7, 10.0), [0, 0, 35, 0, 0, 0, 0]);
      final f = irrigationForecast(project(), null, wet, now: morning);
      final a = f.areas.single;
      expect(f.days[2].effectiveRainMm, 35);
      expect([for (final d in a.days) d.depletionMm], [10, 20, 0, 10, 20, 30, 40]);
      expect(a.days[2].deepPercolationMm, closeTo(5, 1e-9));
      expect(a.irrigations, 0);
      // used 70 mm, the soil kept 30 of the 35 mm of rain: (70 − 30) / (7 × 5) = 114 %
      expect(a.budgetPct, closeTo(100 * 40 / 35, 1e-9));
    });

    test('rain below 0.2·ETo of the day does not count (FAO-56 chapter 8)', () {
      final f = irrigationForecast(project(), null, series(nov10, List.filled(3, 10.0), [1.9, 2.0, 0]), now: morning);
      expect([for (final d in f.days) d.effectiveRainMm], [0, 2, 0]);
    });

    test('a lower demand than the design: the event waits, the budget falls', () {
      final f = irrigationForecast(project(), null, series(nov10, List.filled(7, 2.5), List.filled(7, 0.0)), now: morning);
      final a = f.areas.single;
      expect(a.irrigations, 0);
      expect(a.budgetPct, closeTo(50, 1e-9));
    });

    test('the soil at the start: the last irrigation days ago, with or without its depth', () {
      // three days ago, it filled the soil: the two days between (no climate: the ETo of the first forecast day) took 20 mm
      final a = irrigationForecast(project(), null, dry, now: morning, start: const ForecastStart.last(3)).areas.single;
      expect(a.startDepletionMm, closeTo(20, 1e-9));
      expect(a.warnings, contains('fct_gap_estimated'));
      expect([for (final d in a.days) d.irrigate].indexOf(true), 2);
      // with the site climate the days between take its ETo of the month (4 mm/day in November)
      final p = project()
        ..climate = SiteClimate(
          etoMmDay: List.filled(12, 4.0),
          rainMm: List.filled(12, 0.0),
          source: 'manual',
          firstYear: 0,
          lastYear: 0,
          latitudeDeg: -22.9,
          longitudeDeg: -47.1,
          retrieved: '',
          attribution: '',
        );
      final b = irrigationForecast(p, null, dry, now: morning, start: const ForecastStart.last(3)).areas.single;
      expect(b.startDepletionMm, closeTo(8, 1e-9));
      expect(b.warnings, isNot(contains('fct_gap_estimated')));
      // yesterday, 30 mm into the soil: it came at the 50 mm of an event, so 20 mm short of full
      final c = irrigationForecast(project(), null, dry, now: morning, start: const ForecastStart.last(1, depthMm: 30)).areas.single;
      expect(c.startDepletionMm, closeTo(20, 1e-9));
      // soil full today: nothing missing
      expect(irrigationForecast(project(), null, dry, now: morning).areas.single.startDepletionMm, 0);
    });

    test('a soil left dry long ago starts stressed', () {
      final a = irrigationForecast(project(), null, dry, now: morning, start: const ForecastStart.last(9)).areas.single;
      expect(a.startDepletionMm, greaterThan(50));
      expect(a.warnings, contains('fct_start_dry'));
      expect(a.days.first.irrigate, isTrue);
      expect(a.days.first.etaMm, lessThan(a.days.first.etcMm));
    });

    test('an area of fixed daily depth is left as the programme has it; no emitters, no run time', () {
      final p = project();
      p.entities.add(AreaEntity(id: 'f', points: const [Pt(20, 0), Pt(30, 0), Pt(30, 10), Pt(20, 10)]));
      p.entities.add(AreaEntity(id: 'b', points: const [Pt(40, 0), Pt(50, 0), Pt(50, 10), Pt(40, 10)], useWaterBalance: true, etoMmDay: 5, kc: 1, awcMmPerM: 100, rootDepthM: 1, mad: 0.5));
      final f = irrigationForecast(p, null, dry, now: morning);
      final fixed = f.areas.firstWhere((a) => a.areaId == 'f');
      expect(fixed.balance, isFalse);
      expect(fixed.warnings, ['fct_fixed_depth']);
      final bare = f.areas.firstWhere((a) => a.areaId == 'b');
      expect(bare.warnings, contains('fct_no_rate'));
      expect(bare.days.where((d) => d.irrigate).every((d) => d.runHours == null), isTrue);
    });
  });

  group('the days of the forecast', () {
    test('days before today are left out; a today with few hours left takes the ETo of tomorrow; a cut last day ends it', () {
      final s = ForecastSeries(
        source: ForecastSource.metNorway,
        latitudeDeg: -22.9,
        longitudeDeg: -45,
        utcOffsetHours: -3,
        fetchedAt: DateTime.utc(2026, 11, 10, 23),
        days: [
          ForecastDay(date: DateTime.utc(2026, 11, 9), tMaxC: 30, tMinC: 18, coverageHours: 2),
          ForecastDay(date: nov10, tMaxC: 22, tMinC: 18, coverageHours: 4, rainMm: 1),
          for (var i = 1; i <= 3; i++) ForecastDay(date: nov10.add(Duration(days: i)), tMaxC: 30, tMinC: 18, tDewC: 15),
          ForecastDay(date: DateTime.utc(2026, 11, 14), tMaxC: 30, tMinC: 18, coverageHours: 12),
        ],
      );
      // 20:00 at the site
      final f = irrigationForecast(project(), null, s, now: DateTime.utc(2026, 11, 10, 23));
      expect([for (final d in f.days) d.date.day], [10, 11, 12, 13]);
      expect(f.days.first.estimated, isTrue);
      expect(f.days.first.etoMm, closeTo(f.days[1].etoMm, 1e-12));
      expect(f.days.first.rainMm, 1);
      expect(f.days.first.byService, isFalse);
      expect(f.warnings, contains('fct_today_estimated'));
      expect(f.days[1].estimated, isFalse);
    });

    test('a forecast with nothing from today on gives no plan', () {
      final f = irrigationForecast(project(), null, dry, now: DateTime.utc(2026, 12, 1));
      expect(f.days, isEmpty);
      expect(f.areas, isEmpty);
      expect(f.warnings, contains('fct_no_days'));
    });
  });

  group('the crop on its dates, by hemisphere', () {
    // maize: FAO-56 planting in April (northern seasons), six months later south of the equator; 30/40/50/30 days
    test('southern site in January: maize in mid-season, irrigated', () {
      final p = project(crop: 'crop.maize', lat: -22.9);
      final jan = DateTime.utc(2026, 1, 10);
      final f = irrigationForecast(p, null, series(jan, List.filled(5, 6.0), List.filled(5, 0.0)), now: jan.add(const Duration(hours: 12)));
      final a = f.areas.single;
      expect(a.days.every((d) => d.stage == 2), isTrue);
      expect(a.days.first.kc, closeTo(1.2, 1e-9));
      expect(a.days.first.etcMm, closeTo(7.2, 1e-9));
      expect(a.warnings, isNot(contains('fct_off_season')));
    });

    test('northern site in January: maize out of season, nothing to irrigate; in July it is the north that irrigates', () {
      final p = project(crop: 'crop.maize', lat: 41.6, lon: -0.9);
      final jan = DateTime.utc(2026, 1, 10);
      final f = irrigationForecast(p, null, series(jan, List.filled(5, 3.0), List.filled(5, 0.0), lat: 41.6, offset: 0), now: jan.add(const Duration(hours: 12)));
      final a = f.areas.single;
      expect(a.days.every((d) => d.stage == -1 && d.kc == 0 && !d.irrigate), isTrue);
      expect(a.warnings, contains('fct_off_season'));
      final jul = DateTime.utc(2026, 7, 10);
      final g = irrigationForecast(p, null, series(jul, List.filled(5, 7.0), List.filled(5, 0.0), lat: 41.6, offset: 0), now: jul.add(const Duration(hours: 12)));
      expect(g.areas.single.days.every((d) => d.stage == 2), isTrue);
      final south = irrigationForecast(project(crop: 'crop.maize'), null, series(jul, List.filled(5, 4.0), List.filled(5, 0.0)), now: jul.add(const Duration(hours: 12)));
      expect(south.areas.single.days.every((d) => d.stage == -1), isTrue);
    });
  });

  group('report tables', () {
    test('the days as columns: ETo and rain on top, the run time of the area or "skip", the programme and the budget', () {
      final f = irrigationForecast(project(), null, dry, now: morning);
      String t(String key, [Map<String, String>? args]) => key;
      final labels = ReportLabels(t: t, has: (_) => true, warning: (c) => c);
      final tables = forecastTables(f, labels, Units());
      final grid = tables.first;
      expect(grid.key, 'irrigationForecast');
      expect(grid.headers.take(3), ['rep.area', 'fct.programme (min)', 'fct.budget (%)']);
      expect(grid.headers.skip(3), ['2026-11-10', '2026-11-11', '2026-11-12', '2026-11-13', '2026-11-14', '2026-11-15', '2026-11-16']);
      expect(grid.rows[0].first, 'ETo (mm)');
      expect((grid.rows[0][3] as RNum).value, 10);
      expect(grid.rows[1].first, 'req.rain (mm)');
      final row = grid.rows[2];
      expect(row[0], 'Block A');
      expect((row[1] as RNum).value, closeTo(156.25, 1e-6));
      expect((row[2] as RNum).value, closeTo(200, 1e-9));
      expect(row[3], 'fct.skip');
      expect((row[7] as RNum).value, closeTo(156.25, 1e-6));
      expect(grid.ids, [null, null, 'a']);
      final detail = tables.last;
      expect(detail.key, 'irrigationForecastDays');
      expect(detail.rows, hasLength(7));
      expect(detail.rows[4][8], 'fct.irrigate');
      expect((detail.rows[4][10] as RNum).value, closeTo(62.5, 1e-9));
      expect(detail.headers, hasLength(detail.rows.first.length));
      // the CSV of the reports takes them as they are
      expect(reportTablesToCsv(tables), contains('Block A'));
    });

    test('in US units the depths are in inches', () {
      final f = irrigationForecast(project(), null, dry, now: morning);
      final tables = forecastTables(f, ReportLabels(t: (k, [a]) => k, has: (_) => true, warning: (c) => c), Units(length: LengthUnit.ft));
      expect(tables.first.rows[0].first, 'ETo (in)');
      expect((tables.first.rows[0][3] as RNum).value, closeTo(10 / 25.4, 1e-12));
    });
  });
}
