import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/core/design/climate.dart';
import 'package:opencadirrigation/core/design/climate_risk.dart';
import 'package:opencadirrigation/core/design/climate_risk_stats.dart';
import 'package:opencadirrigation/core/design/crops.dart';
import 'package:opencadirrigation/core/design/irrigation_requirement.dart';
import 'package:opencadirrigation/core/design/report_tables.dart';
import 'package:opencadirrigation/core/design/soil_water_balance.dart';
import 'package:opencadirrigation/core/io/climate_online.dart';
import 'package:opencadirrigation/core/io/inmet_csv.dart' show dailyPenmanMonteith;
import 'package:opencadirrigation/core/model/agronomy_plan.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// The climate risk over the years (1.7.0 CLR): the frequency analysis and
/// the trend test by hand, the NASA POWER daily answer recorded from the
/// service, missing days, both hemispheres and leap years, the daily
/// balance with the system's capacity, the analysis over a synthetic
/// multi-year series with known answers, the summary kept in the project
/// and its report tables.
void main() {
  const square = [Pt(0, 0), Pt(100, 0), Pt(100, 100), Pt(0, 100)]; // 1 ha

  /// A typed area: Kc 1 all year, ETo 5, TAW 100 mm (AWC 100 mm/m, Zr 1 m),
  /// p 0.5 (RAW 50 mm), Ea 0.8.
  AreaEntity typedArea({String id = 'a', double eto = 5}) => AreaEntity(id: id, points: square, useWaterBalance: true, etoMmDay: eto, kc: 1, awcMmPerM: 100, rootDepthM: 1, mad: 0.5, efficiency: 0.8);

  /// [years] whole years from [first] with ETo [eto] every day and the rain
  /// of [rainOn] (none by default).
  RiskSeries constant({int first = 2001, int years = 10, double eto = 5, double Function(DateTime d)? rainOn}) {
    final start = DateTime.utc(first);
    final n = DateTime.utc(first + years).difference(start).inDays;
    return RiskSeries(
      start: start,
      eto: List.filled(n, eto),
      rain: [for (var i = 0; i < n; i++) rainOn?.call(start.add(Duration(days: i))) ?? 0.0],
      source: 'test',
    );
  }

  group('frequency analysis and trend (by hand)', () {
    test('Weibull plotting positions i/(n + 1) and the interpolated quantiles', () {
      expect(weibullPosition(1, 4), closeTo(0.2, 1e-12));
      expect(weibullPosition(4, 4), closeTo(0.8, 1e-12));
      const xs = [40.0, 10.0, 30.0, 20.0];
      // F = 0.5: rank 0.5·5 = 2.5, between 20 and 30
      expect(quantileAt(xs, 0.5), closeTo(25, 1e-12));
      // F = 0.6: rank 3 exactly
      expect(quantileAt(xs, 0.6), closeTo(30, 1e-12));
      // F = 0.2: rank 1; below it and above rank n the sample's ends (no extrapolation)
      expect(quantileAt(xs, 0.2), 10);
      expect(quantileAt(xs, 0.1), 10);
      expect(quantileAt(xs, 0.8), 40);
      expect(quantileAt(xs, 0.95), 40);
      expect(quantileAt(const [], 0.5), isNull);
      expect(exceedanceCurve(const [30, 10, 20]), [(0.25, 10.0), (0.5, 20.0), (0.75, 30.0)]);
      expect(countAbove(const [1, 2, 3], 2), 1);
      expect(countAbove(const [2, 2], 2), 0, reason: 'a value equal to the figure does not exceed it');
      expect(median(const [3, 1, 2]), 2);
      expect(median(const [4, 1, 3, 2]), 2.5);
    });

    test('Sen\'s slope and the Mann-Kendall test, ties corrected', () {
      final years = [for (var y = 2001; y <= 2010; y++) y];
      // a steady rise: S = 45, Var(S) = 10·9·25/18 = 125, Z = 44/√125
      final up = senMannKendall(years, [for (var i = 1; i <= 10; i++) i.toDouble()])!;
      expect(up.n, 10);
      expect(up.s, 45);
      expect(up.varS, closeTo(125, 1e-12));
      expect(up.z, closeTo(44 / math.sqrt(125), 1e-12));
      expect(up.slopePerYear, closeTo(1, 1e-12));
      expect(up.slopePerDecade, closeTo(10, 1e-12));
      expect(up.significant, isTrue);
      // pairs of equal values: five ties of two, Var(S) = (2250 − 5·2·1·9)/18 = 120, S = 40
      final tied = senMannKendall(years, const [1, 1, 2, 2, 3, 3, 4, 4, 5, 5])!;
      expect(tied.s, 40);
      expect(tied.varS, closeTo(120, 1e-12));
      expect(tied.z, closeTo(39 / math.sqrt(120), 1e-12));
      expect(tied.slopePerYear, closeTo(0.5, 1e-12));
      // no trend
      final flat = senMannKendall([for (var y = 2001; y <= 2012; y++) y], const [5, 3, 6, 2, 7, 4, 5, 3, 6, 4, 5, 4])!;
      expect(flat.s, 0);
      expect(flat.z, 0);
      expect(flat.significant, isFalse);
      // a falling series is negative
      expect(senMannKendall(years, [for (var i = 10; i >= 1; i--) i.toDouble()])!.z, closeTo(-44 / math.sqrt(125), 1e-12));
      expect(senMannKendall(const [2001, 2002, 2003], const [1, 2, 3]), isNull, reason: 'fewer than $minTrendYears years');
    });

    test('peak means, dry spells and the irrigation year of either hemisphere', () {
      expect(peakMean(const [1, 2, 3, 10, 1], 2), closeTo(6.5, 1e-12));
      expect(peakMean(const [1, 2, 3], 10), closeTo(2, 1e-12), reason: 'a window longer than the list takes the list');
      expect(peakMean(const [], 5), 0);
      final s = RiskSeries(start: DateTime.utc(2001), eto: List.filled(10, 4), rain: [5, 0, 0, 0.5, 0, 2, 0, 0, double.nan, 0]);
      // days 1–4 dry (0, 0, 0.5, 0); the missing day ends the run 6–7
      expect(longestDrySpell(s, 0, 10), (4, 1));
      // rain only in January (a wet southern summer) or only in July (a wet southern winter, a dry northern summer)
      expect(waterYearStartMonth(constant(rainOn: (d) => d.month == 1 ? 10 : 0)), 1);
      expect(waterYearStartMonth(constant(rainOn: (d) => d.month == 7 ? 10 : 0)), 7);
      // no rain and the same ETo every day: the shortest month
      expect(waterYearStartMonth(constant()), 2);
    });
  });

  group('the daily series', () {
    test('a recorded NASA POWER daily answer: days across the new year, FAO-56 Penman-Monteith ETo of each day', () {
      final body = File('test/fixtures/climate_risk/nasa_power_daily_2023.json').readAsStringSync();
      final (days, elev) = climateParseResponse(ClimateSource.nasaPower, body);
      expect(elev, closeTo(755.36, 1e-9));
      final cs = ClimateSeries(source: ClimateSource.nasaPower, latitudeDeg: -22.9, longitudeDeg: -47.06, elevationM: elev, days: days);
      final s = RiskSeries.ofClimateSeries(cs, attribution: ClimateSource.nasaPower.attribution);
      expect(s.start, DateTime.utc(2023, 12, 26));
      expect(s.length, 12);
      expect(s.dateAt(6), DateTime.utc(2024));
      expect(s.gaps(0, s.length), 0);
      expect(s.rain[0], closeTo(4.51, 1e-9));
      expect(s.rain[8], closeTo(9.07, 1e-9));
      expect(s.source, 'nasaPower');
      expect(s.attribution, contains('POWER'));
      // 26 December 2023: Tmax 33.1, Tmin 18.87, dew point 18.67, u2 2.74, Rs 21.86 MJ/m², z 755 m
      final d = days.first;
      final e = fao56Eto(Fao56Input(latitudeDeg: -22.9, elevationM: 755.36, dayOfYear: 360, tMaxC: 33.1, tMinC: 18.87, tDewC: 18.67, rhMeanPct: 66.18, windSpeedMs: 2.74, solarRadiationMJ: 21.86));
      expect(dayOfYear(d.date), 360);
      expect(s.eto[0], closeTo(e.etoMmDay, 1e-12));
      expect(e.estimated, isEmpty, reason: 'every input measured');
      expect(s.eto[0], inInclusiveRange(4, 6.5), reason: 'a summer day in São Paulo state');
      expect(s.monthlyEto[11], closeTo([for (var i = 0; i < 6; i++) s.eto[i]].reduce((a, b) => a + b) / 6, 1e-12));
    });

    test('the model\'s sentinel −999: no radiation before 1984 (ETo from the temperature range), a missing temperature leaves the day without ETo', () {
      final body = File('test/fixtures/climate_risk/nasa_power_daily_1983.json').readAsStringSync();
      var (days, elev) = climateParseResponse(ClimateSource.nasaPower, body);
      expect(days.first.solarMJm2, isNull);
      expect(days.last.solarMJm2, closeTo(26.5, 1e-9));
      var s = RiskSeries.ofClimateSeries(ClimateSeries(source: ClimateSource.nasaPower, latitudeDeg: -22.9, longitudeDeg: -47.06, elevationM: elev, days: days));
      expect(s.eto[0], closeTo(dailyPenmanMonteith(days.first, latitudeDeg: -22.9, elevationM: elev!)!, 1e-12));
      expect(fao56Eto(Fao56Input(latitudeDeg: -22.9, elevationM: elev, dayOfYear: 363, tMaxC: 25.57, tMinC: 17.45, tDewC: 18.64)).estimated, contains(Fao56Estimate.radiationFromTemperature));
      // the same answer with Tmax of 30 December missing
      (days, elev) = climateParseResponse(ClimateSource.nasaPower, body.replaceFirst('"19831230":24.52', '"19831230":-999.0'));
      s = RiskSeries.ofClimateSeries(ClimateSeries(source: ClimateSource.nasaPower, latitudeDeg: -22.9, longitudeDeg: -47.06, elevationM: elev, days: days));
      expect(s.eto[1].isNaN, isTrue);
      expect(s.missing(1), isTrue);
      expect(s.gaps(0, s.length), 1);
      // filled with the series' own mean ETo of December
      expect(s.etoAt(1), closeTo((s.eto[0] + s.eto[2]) / 2, 1e-12));
      expect(s.rainAt(1), closeTo(19.13, 1e-9));
    });

    test('missing days: ETo of the month, no rain; a year with more than a tenth filled is left out', () {
      final base = constant();
      final eto = [...base.eto], rain = [...base.rain];
      // 5 days of June 2005 and 40 days of June–July 2003 without data
      for (var i = base.indexOf(DateTime.utc(2005, 6, 1)); i < base.indexOf(DateTime.utc(2005, 6, 6)); i++) {
        eto[i] = double.nan;
        rain[i] = double.nan;
      }
      for (var i = base.indexOf(DateTime.utc(2003, 6, 1)); i < base.indexOf(DateTime.utc(2003, 7, 11)); i++) {
        eto[i] = double.nan;
        rain[i] = double.nan;
      }
      final s = RiskSeries(start: base.start, eto: eto, rain: rain);
      final p = Project()..entities.add(typedArea());
      final r = climateRiskAnalysis(p, s);
      expect(r.startMonth, 2);
      expect([for (final y in r.site) y.year], [2001, 2002, 2004, 2005, 2006, 2007, 2008, 2009]);
      expect(r.site.firstWhere((y) => y.year == 2005).filledDays, 5);
      expect(r.site.firstWhere((y) => y.year == 2005).etoMm, closeTo(5 * 365, 1e-9), reason: 'filled with the month\'s mean');
      final a = r.areas.single;
      expect(a.years, [2001, 2002, 2004, 2005, 2006, 2007, 2008, 2009]);
      expect(a.seasons.firstWhere((x) => x.year == 2005).filledDays, 5);
      expect(a.seasons.firstWhere((x) => x.year == 2005).grossMm, closeTo(2250, 1e-6));
      // the dry spell does not run through the missing days
      expect(r.site.firstWhere((y) => y.year == 2005).drySpellDays, lessThan(365));
    });
  });

  group('the daily balance with the system\'s capacity (FAO-56 chapter 8)', () {
    BalanceInput input(BalanceSettings s, {double? cap, List<BalanceWeather>? weather, DateTime? yearStart}) => BalanceInput(
      weather: weather ?? typicalYearWeather(ClimateNormals(etoMmDay: List.filled(12, 5.0), rainMm: List.filled(12, 0.0))),
      curve: const KcCurve.constant(1),
      planting: DateTime.utc(2001, 1, 1),
      awcMmPerM: 100,
      rootDepthM: 1,
      depletionFraction: 0.5,
      adjustDepletionToEtc: false,
      efficiency: 0.8,
      settings: s,
      maxGrossMmDay: cap,
      yearStart: yearStart,
    );

    test('5 mm a day gross (4 net) against ETc 5: past the RAW from 15 January, the depletion settles at 60 mm', () {
      final s = BalanceSettings();
      final r = soilWaterBalance(input(s, cap: 5));
      // the RAW is reached on 10 January: 4 mm a day from then on
      expect(r.events.first.date, DateTime.utc(2001, 1, 10));
      expect(r.events.every((e) => e.netMm <= 4 + 1e-9), isTrue);
      expect(r.events, hasLength(356));
      expect(r.grossMm, closeTo(1780, 1e-6));
      // 46, 47, 48, 49, 50, then 51 on the 15th: past the allowed depletion
      expect(r.days[13].depletionMm, closeTo(50, 1e-9));
      expect(r.days[14].depletionMm, closeTo(51, 1e-9));
      expect(deficitDaysOf(r, s), 351);
      // Ks·5 = 4 when Dr = 100 − 0.8·50
      expect(r.finalDepletionMm, closeTo(60, 1e-6));
      expect(r.closureErrorMm, closeTo(0, 1e-9));
      // without the limit nothing changes from 1.6.0
      final free = soilWaterBalance(input(s));
      expect(free.grossMm, closeTo(2250, 1e-9));
      expect(deficitDaysOf(free, s), 0);
    });

    test('an irrigation every 7 days may apply 7 days of the capacity', () {
      final r = soilWaterBalance(input(BalanceSettings(trigger: BalanceTrigger.interval, intervalDays: 7), cap: 5));
      expect(r.events.every((e) => e.netMm <= 28 + 1e-9), isTrue);
      expect(r.events[1].netMm, closeTo(28, 1e-9));
      expect(r.closureErrorMm, closeTo(0, 1e-9));
    });

    test('a crop in the field all year balanced from 1 July', () {
      final w = [for (var i = 0; i < 730; i++) BalanceWeather(DateTime.utc(2001).add(Duration(days: i)), 5, 0)];
      final r = soilWaterBalance(input(BalanceSettings(), weather: w, yearStart: DateTime.utc(2001, 7)));
      expect(r.days.first.date, DateTime.utc(2001, 7));
      expect(r.days.last.date, DateTime.utc(2002, 6, 30));
      expect(r.days, hasLength(365));
      expect(r.grossMm, closeTo(2250, 1e-9));
    });
  });

  group('the analysis over the years', () {
    test('ten years of ETo 5 and no rain: every year alike, the leap years one day longer', () {
      final p = Project()..entities.add(typedArea());
      final r = climateRiskAnalysis(p, constant(), probability: 0.9, peakDays: 10, today: DateTime.utc(2026, 11, 10));
      expect(r.computed, '2026-11-10');
      expect(r.probability, 0.9);
      expect(r.peakDays, 10);
      expect(r.firstYear, 2001);
      expect(r.lastYear, 2010);
      // irrigation years from February (no month wetter than another: the shortest)
      expect(r.startMonth, 2);
      expect(r.siteCrossesYear, isTrue);
      expect([for (final y in r.site) y.year], [for (var y = 2001; y <= 2009; y++) y]);
      for (final y in r.site) {
        final leap = y.year == 2004 || y.year == 2008;
        expect(y.etoMm, closeTo(5 * (leap ? 366 : 365), 1e-9), reason: '${y.year}');
        expect(y.rainMm, 0);
        expect(y.peakEtoMmDay, closeTo(5, 1e-12));
        expect(y.drySpellDays, leap ? 366 : 365);
        expect(y.drySpellStart, DateTime.utc(y.year, 2));
      }
      final a = r.areas.single;
      expect(a.startMonth, 2);
      expect(a.startDay, 1);
      expect(a.seasonDays, 365);
      expect(a.crossesYear, isTrue);
      expect(a.capacityGrossMmDay, isNull, reason: 'no emitters');
      expect(a.warnings, ['clr_no_capacity']);
      expect(a.seasons, hasLength(9));
      for (final x in a.seasons) {
        // 36 refills of 50 mm a year (the 366th day is not the 370th)
        expect(x.netMm, closeTo(1800, 1e-6));
        expect(x.grossMm, closeTo(2250, 1e-6));
        expect(x.appliedGrossMm, closeTo(2250, 1e-6));
        expect(x.peakGrossMmDay, closeTo(6.25, 1e-9), reason: 'ETc 5 over Ea 0.8');
        expect(x.peakEtoMmDay, closeTo(5, 1e-12));
        expect(x.deficitDays, 0);
      }
      // the figures of the design: the ETo typed on the area, 5/0.8 a day, 365 days of it
      expect(a.designEtoMmDay, 5);
      expect(a.designPeakGrossMmDay, closeTo(6.25, 1e-12));
      expect(a.designYearGrossMm, closeTo(6.25 * 365, 1e-6));
      expect(quantileAt(a.grossMm, 0.95), closeTo(2250, 1e-6));
      expect(countAbove(a.grossMm, a.designYearGrossMm), 0);
      expect(a.reliability, 1);
      expect(r.project, hasLength(9));
      expect(r.project.every((y) => y.complete && (y.requirementM3 - 22500).abs() < 1e-3 && y.deficitDays == 0), isTrue);
      expect(r.projectEtoMmDay, isNull, reason: 'no site climate');
      expect(r.warnings, contains('clr_short'));
    });

    test('a season planted in November runs into the next year; the last one, not complete, is left out', () {
      final p = Project()..entities.add(AreaEntity(id: 'm', points: square, useWaterBalance: true, cropKey: 'crop.maize', plantingMonthDay: '11-15', awcMmPerM: 120, rootDepthM: 0.8));
      final r = climateRiskAnalysis(p, constant(eto: 6));
      final a = r.areas.single;
      expect(a.startMonth, 11);
      expect(a.startDay, 15);
      expect(a.seasonDays, fao56Crops['crop.maize']!.curve.seasonDays.ceil());
      expect(a.crossesYear, isTrue);
      expect(a.years, [for (var y = 2001; y <= 2009; y++) y]);
      expect(ClimateRiskSummary.yearLabel(2009, crosses: a.crossesYear), '2009/10');
      expect(ClimateRiskSummary.yearLabel(1999, crosses: true), '1999/00');
      expect(a.seasons.every((x) => x.grossMm > 0 && x.peakEtoMmDay == 6), isTrue);
    });

    test('a rainfed balance is evaluated irrigating; an area of fixed depth is left out', () {
      final p = Project()..entities.addAll([typedArea(), AreaEntity(id: 'f', points: square, netDepthMmPerDay: 4)]);
      p.agronomy.balance['a'] = BalanceSettings(trigger: BalanceTrigger.rainfed);
      final r = climateRiskAnalysis(p, constant());
      expect(r.areas.single.areaId, 'a');
      expect(r.areas.single.warnings, contains('clr_rainfed'));
      expect(r.areas.single.seasons.first.grossMm, closeTo(2250, 1e-6));
      expect(r.warnings, contains('clr_fixed:f'));
      expect(climateRiskAnalysis(Project(), constant()).warnings, contains('clr_no_areas'));
    });

    test('under the gallery pivot: 8.5 mm a day gross against 10 needed, past the RAW from the 8th day', () {
      final p = buildExample(ExampleId.pivot, (k, [a]) => k);
      final area = p.entities.whereType<AreaEntity>().single;
      area
        ..cropKey = ''
        ..useWaterBalance = true
        ..etoMmDay = 8
        ..kc = 1
        ..awcMmPerM = 100
        ..rootDepthM = 1
        ..mad = 0.5
        ..efficiency = 0.8;
      expect(areaDailyCapacity(p, null)[area.id], closeTo(8.5, 1e-9));
      final r = climateRiskAnalysis(p, constant(eto: 8));
      final a = r.areas.single;
      expect(a.capacityGrossMmDay, closeTo(8.5, 1e-9));
      for (final x in a.seasons) {
        final leap = x.year == 2004 || x.year == 2008;
        // without a limit: a refill of 56 mm every 7 days
        expect(x.grossMm, closeTo(3640, 1e-6));
        // with it: 6.8 mm net a day from the 7th day, the depletion past 50 mm from the 8th
        expect(x.appliedGrossMm, closeTo(leap ? 3060 : 3051.5, 1e-6));
        expect(x.deficitDays, leap ? 359 : 358);
      }
      expect(a.reliableSeasons, 0);
      expect(r.project.every((y) => y.areasInDeficit == 1 && y.deficitDays >= 358), isTrue);
    });

    test('the capacity of sprinkler areas: their rate times the share of the window of their flow', () {
      final p = buildExample(ExampleId.orchard, (k, [a]) => k);
      final caps = areaDailyCapacity(p, null);
      expect(caps, isNotEmpty);
      for (final a in p.entities.whereType<AreaEntity>()) {
        expect(caps[a.id], greaterThan(0), reason: a.id);
      }
      // a shorter window gives proportionally less
      p.agronomy.programme = ProgrammeSettings(windowHours: 12);
      final half = areaDailyCapacity(p, null);
      for (final e in caps.entries) {
        expect(half[e.key], closeTo(e.value / 2, 1e-9));
      }
    });
  });

  group('the summary in the project and its report tables', () {
    final t = I18n('en');
    ReportLabels labels() => ReportLabels(t: t.call, has: t.has, warning: t.warning);

    test('kept in the file, small; read back the same; a damaged one is dropped', () {
      final p = Project()..entities.add(typedArea());
      p.climateRisk = climateRiskAnalysis(p, constant(), today: DateTime.utc(2026, 11, 10));
      final text = jsonEncode(p.toJson());
      expect(jsonEncode(p.climateRisk!.toJson()).length, lessThan(2000));
      final back = Project.fromJson(jsonDecode(text) as Map<String, dynamic>).climateRisk!;
      expect(back.computed, '2026-11-10');
      expect(back.startMonth, 2);
      expect(back.site, hasLength(9));
      expect(back.site.first.drySpellStart, DateTime.utc(2001, 2));
      expect(back.areas.single.seasons.map((s) => s.grossMm), everyElement(closeTo(2250, 0.05)));
      expect(back.areas.single.warnings, ['clr_no_capacity']);
      expect(back.project.first.complete, isTrue);
      expect(jsonEncode(back.toJson()), jsonEncode(p.climateRisk!.toJson()));
      expect(ClimateRiskSummary.fromJson('nonsense'), isNull);
      expect(ClimateRiskSummary.fromJson({'areas': 'x', 'site': 3})!.areas, isEmpty);
      final damaged = jsonDecode(text) as Map<String, dynamic>;
      damaged['climateRisk'] = 7;
      expect(Project.fromJson(damaged).climateRisk, isNull);
      expect(Project().toJson().containsKey('climateRisk'), isFalse, reason: 'nothing written without a summary');
    });

    test('the distribution table and the year-by-year table, in the report and its exports', () {
      final p = Project()..entities.add(typedArea());
      expect(climateRiskTables(p, labels()), isEmpty);
      p.climateRisk = climateRiskAnalysis(p, constant(), today: DateTime.utc(2026, 11, 10));
      final tables = climateRiskTables(p, labels());
      expect(tables.map((x) => x.key), ['climateRisk', 'climateRiskYears']);
      final stats = tables.first;
      expect(stats.headers, ['Area', 'Quantity', 'P50', 'P80', 'P90', 'P95', 'max', 'Design figure', 'Note']);
      expect(stats.rows.every((r) => r.length == stats.headers.length), isTrue);
      // the project's block (peak ETo, ETo, rain, dry spell, volume, pumped, deficit days), then the area's five rows
      expect(stats.rows, hasLength(12));
      final gross = stats.rows.firstWhere((r) => r[1] == 'Gross irrigation needed in the year (mm)');
      expect([for (final c in gross.sublist(2, 7)) (c as RNum).value], everyElement(closeTo(2250, 1e-6)));
      expect((gross[7] as RNum).value, closeTo(2281.25, 1e-6));
      expect(gross[8], contains('exceeded in 0 of 9 years'));
      final peak = stats.rows.firstWhere((r) => '${r[1]}'.startsWith('Peak 30-day gross demand'));
      expect(peak[8], contains('capacity unknown'));
      final deficit = stats.rows.lastWhere((r) => '${r[1]}'.startsWith('Days past the allowed depletion'));
      expect(deficit[8], '9 of 9 years without a deficit day (100 %)');
      expect(stats.ids.where((id) => id == 'a'), hasLength(5));
      final years = tables.last;
      expect(years.rows, hasLength(9));
      expect(years.rows.first.first, '2001/02');
      expect((years.rows.first[5] as RNum).value, closeTo(22500, 1e-3));
      // in every export, with the standard of the criteria (FAO 56)
      final all = buildReportTables(project: p, results: null, labels: labels());
      expect(all.map((x) => x.key), containsAll(['climateRisk', 'climateRiskYears']));
      expect(all.firstWhere((x) => x.key == 'climateRisk').standards, contains('FAO 56'));
      expect(reportTablesToCsv(all.where((x) => x.key.startsWith('climateRisk')).toList()), contains('CLIMATE RISK: SPREAD OF THE YEARS'));
    });
  });
}
