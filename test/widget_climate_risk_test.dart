import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/ai/agent_tools_agent.dart' show AgentHost;
import 'package:opencadirrigation/app/io/data_cache_store.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/dialogs/climate_risk_dialog.dart';
import 'package:opencadirrigation/app/widgets/reports_panel.dart' show ReportTableView;
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/design/climate_risk.dart';
import 'package:opencadirrigation/core/io/climate_online.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/site_climate.dart';
import 'package:opencadirrigation/main.dart';

class _Host implements AgentHost {
  @override
  bool stopped = false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The answer of the NASA POWER daily point API for the period of [url]: a
/// warm site with a wet summer (December to March) and a dry winter, the
/// shape of the real answers (test/fixtures/climate_risk).
String fakePower(String url) {
  final q = Uri.parse(url).queryParameters;
  DateTime day(String s) => DateTime.utc(int.parse(s.substring(0, 4)), int.parse(s.substring(4, 6)), int.parse(s.substring(6, 8)));
  final a = day(q['start']!), b = day(q['end']!);
  final p = {
    for (final k in ['T2M_MAX', 'T2M_MIN', 'T2MDEW', 'RH2M', 'WS2M', 'PRECTOTCORR', 'ALLSKY_SFC_SW_DWN']) k: <String, double>{},
  };
  for (var d = a; !d.isAfter(b); d = d.add(const Duration(days: 1))) {
    final k = '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    final doy = d.difference(DateTime.utc(d.year)).inDays;
    final season = math.cos(2 * math.pi * doy / 365); // 1 in January
    final wet = d.month >= 12 || d.month <= 3;
    p['T2M_MAX']![k] = 29 + 3 * season + (d.year % 7) * 0.2;
    p['T2M_MIN']![k] = 16 + 3 * season;
    p['T2MDEW']![k] = wet ? 17 : 9;
    p['RH2M']![k] = wet ? 75 : 50;
    p['WS2M']![k] = 2;
    p['PRECTOTCORR']![k] = wet && (d.day % 4 == 0) ? 18 : (d.day == 15 ? 3 : 0);
    p['ALLSKY_SFC_SW_DWN']![k] = 18 + 4 * season;
  }
  return jsonEncode({
    'type': 'Feature',
    'geometry': {
      'type': 'Point',
      'coordinates': [-47.06, -22.9, 755.36],
    },
    'properties': {'parameter': p},
    'header': {'fill_value': -999.0},
    'messages': <String>[],
  });
}

void main() {
  final requests = <String>[];
  late MemoryDataCacheStore store;

  setUp(() {
    requests.clear();
    store = MemoryDataCacheStore();
    debugAppDataCache = DataCache(store);
    ProjectController.climateUrlLoader = (url) async {
      requests.add(url);
      return fakePower(url);
    };
    // the last complete year is 1994: three parts of five years at most
    climateRiskClock = () => DateTime.utc(1995, 3, 1);
  });
  tearDown(() {
    debugAppDataCache = null;
    climateRiskClock = DateTime.now;
  });

  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<ProjectController> pumpShell(WidgetTester tester, Size size, {bool example = true, String lang = 'en', double textScale = 1}) async {
    TutorialController.markDone();
    setPref('lang', lang);
    LocalProjectStore().clearAll();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false, askAi: false));
    await settle(tester);
    final c = (tester.state(find.byType(AppShell)) as dynamic).c as ProjectController;
    c
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    if (example) loadExampleAction(c);
    await settle(tester);
    return c;
  }

  BuildContext ctxOf(WidgetTester tester) => tester.element(find.byType(Scaffold).first);

  /// Pumps the test's clock until [done] (the pauses of the download are
  /// its timers), at most a minute of it; the pumps it took.
  Future<int> until(WidgetTester tester, bool Function() done) async {
    var n = 0;
    while (!done() && n < 200) {
      await tester.pump(const Duration(milliseconds: 300));
      n++;
    }
    await settle(tester);
    return n;
  }

  /// Ten years of a synthetic site: ETo with the seasons, rain in summer.
  RiskSeries synthetic() {
    final start = DateTime.utc(2001);
    final n = DateTime.utc(2011).difference(start).inDays;
    final eto = <double>[], rain = <double>[];
    for (var i = 0; i < n; i++) {
      final d = start.add(Duration(days: i));
      eto.add(4.5 + 1.5 * math.cos(2 * math.pi * (d.month - 1) / 12) + (d.year % 3) * 0.3);
      rain.add((d.month <= 3 || d.month == 12) && d.day % 5 == 0 ? 25 : 0);
    }
    return RiskSeries(start: start, eto: eto, rain: rain, source: 'test');
  }

  for (final (name, size, lang, scale, dark) in const [
    ('phone', Size(360, 640), 'pt', 1.0, true),
    ('phone, light theme', Size(360, 640), 'es', 1.0, false),
    ('phone sideways', Size(844, 390), 'pt', 1.0, true),
    ('right to left', Size(360, 640), 'ar', 1.0, true),
    ('text twice as big', Size(1280, 800), 'pt', 2.0, false),
  ]) {
    testWidgets('the dialog and its results lay out: $name', (tester) async {
      setThemeMode(dark ? CadThemeMode.dark : CadThemeMode.light);
      addTearDown(() => setThemeMode(CadThemeMode.dark));
      final c = await pumpShell(tester, size, lang: lang, textScale: scale);
      c.project.climateRisk = climateRiskAnalysis(c.project, synthetic(), today: DateTime.utc(2026, 11, 10));
      showClimateRiskDialog(ctxOf(tester), c);
      await settle(tester);
      expect(tester.takeException(), isNull, reason: 'the project view at $name');
      expect(find.byKey(const Key('clr_chart_years')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('clr_view')));
      await settle(tester, 1);
      await tester.tap(find.byKey(const Key('clr_view')));
      await settle(tester);
      await tester.tap(find.text(c.project.climateRisk!.areas.first.name).last);
      await settle(tester);
      expect(tester.takeException(), isNull, reason: 'an area\'s view at $name');
      expect(find.byKey(const Key('clr_chart_curve')), findsOneWidget);
      Navigator.of(tester.element(find.byType(Dialog).last)).pop();
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Design → Agronomy → Climate risk on the desktop; the same in the phone\'s menu', (tester) async {
    var c = await pumpShell(tester, const Size(1600, 1000));
    final t = c.t;
    for (final label in [t('menu.design'), t('agr.menu'), t('clr.menu')]) {
      await tester.tap(find.text(label).last);
      await settle(tester, 2);
    }
    expect(find.text(t('clr.title')), findsOneWidget);
    await tester.tap(find.byKey(const Key('clr_close')));
    await settle(tester);
    c = await pumpShell(tester, const Size(390, 844));
    Finder inMenu(Finder f) => find.descendant(of: find.byKey(const Key('mobile_menu_sheet')), matching: f);
    await tester.tap(find.byKey(const Key('mobile_menu')));
    await settle(tester);
    await tester.ensureVisible(inMenu(find.byKey(const Key('mobile_menu_design'))));
    await settle(tester, 1);
    await tester.tap(inMenu(find.byKey(const Key('mobile_menu_design'))));
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('mobile_menu_climate_risk')));
    await settle(tester, 1);
    await tester.tap(find.byKey(const Key('mobile_menu_climate_risk')));
    await settle(tester);
    expect(find.text(c.t('clr.title')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty project: a clear message, nothing to run, no download', (tester) async {
    final c = await pumpShell(tester, const Size(360, 640), example: false);
    showClimateRiskDialog(ctxOf(tester), c);
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('clr_no_areas')), findsOneWidget);
    expect(find.text(c.t('msg.climate_no_site')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('clr_run'))).onPressed, isNull);
    await expectLater(runClimateRisk(c), throwsA(isA<ClimateException>().having((e) => e.code, 'code', 'clr_no_areas')));
    expect(requests, isEmpty);
    expect(climateRiskError(c, const ClimateException('clr_no_areas')), c.t('clr.err.clr_no_areas'));
    await tester.tap(find.byKey(const Key('clr_close')));
    await settle(tester);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('NASA POWER once, then from the device: the summary in the project as one undo step, charts and tables', (tester) async {
    final c = await pumpShell(tester, const Size(1600, 1000));
    c.setGeoreferenceAt(-22.9031, -47.0598);
    await settle(tester);
    showClimateRiskDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.text(c.t('clr.title')), findsOneWidget);
    expect(find.byKey(const Key('clr_stored')), findsNothing, reason: 'nothing computed yet, nothing downloaded');
    expect(requests, isEmpty);
    final before = c.historyIndex;
    await tester.tap(find.byKey(const Key('clr_run')));
    // (the pace between parts mixes the test's clock and the real one: not counted here)
    await until(tester, () => c.project.climateRisk != null);
    // 1984–1994 in parts of five years, the site rounded to 0.01°
    expect(requests, hasLength(3));
    expect(requests.every((u) => u.contains('latitude=-22.9000') && u.contains('longitude=-47.0600') && u.startsWith('https://power.larc.nasa.gov/')), isTrue);
    expect(store.values.keys.every((k) => k.startsWith('climate:https://power.larc.nasa.gov/')), isTrue);
    expect(store.values, hasLength(3));
    final s = c.project.climateRisk!;
    expect(s.source, 'nasaPower');
    expect(s.firstYear, climateRiskFirstYear);
    expect(s.lastYear, 1994);
    expect(s.attribution, contains('POWER'));
    expect(s.areas, isNotEmpty);
    expect(s.areas.every((a) => a.seasons.isNotEmpty), isTrue);
    expect(c.historyIndex, before + 1);
    expect(find.byKey(const Key('clr_stored')), findsOneWidget);
    expect(find.byKey(const Key('clr_chart_years')), findsOneWidget);
    expect(find.byKey(const Key('clr_chart_curve')), findsOneWidget);
    expect(find.byKey(const Key('clr_reanalysis')), findsOneWidget);
    expect(find.byType(ReportTableView), findsNWidgets(2));
    expect(c.reportTables().map((t) => t.key), containsAll(['climateRisk', 'climateRiskYears']));
    // one area's view
    await tester.tap(find.byKey(const Key('clr_view')));
    await settle(tester);
    await tester.tap(find.text(s.areas.first.name).last);
    await settle(tester);
    expect(find.textContaining(c.t('clr.capacityTitle'), findRichText: true), findsWidgets);
    expect(find.textContaining(c.t('clr.season'), findRichText: true), findsWidgets);
    expect(tester.takeException(), isNull);
    // again: every part is on the device, nothing goes out and nothing waits
    final first = c.project.climateRisk;
    await tester.tap(find.byKey(const Key('clr_run')));
    final again = await until(tester, () => !identical(c.project.climateRisk, first));
    expect(requests, hasLength(3));
    expect(again, lessThanOrEqualTo(1), reason: 'no pause between parts read from the device');
    expect(c.historyIndex, before + 2);
    await tester.tap(find.byKey(const Key('clr_close')));
    await settle(tester);
    c.undo();
    c.undo();
    expect(c.project.climateRisk, isNull);
  });

  testWidgets('the site climate\'s own daily series; a cancelled download changes nothing', (tester) async {
    final c = await pumpShell(tester, const Size(390, 844));
    // ten years of the station: ETo 5, rain on the 1st of every month
    final start = DateTime.utc(2001);
    final n = DateTime.utc(2011).difference(start).inDays;
    c.project.climate = SiteClimate(
      etoMmDay: List.filled(12, 5),
      rainMm: List.filled(12, 20),
      source: 'inmet',
      attribution: 'INMET A701',
      daily: DailyClimate(
        start: start,
        etoMm: List.filled(n, 5),
        rainMm: [for (var i = 0; i < n; i++) start.add(Duration(days: i)).day == 1 ? 20.0 : 0.0],
        source: 'inmet',
      ),
    );
    showClimateRiskDialog(ctxOf(tester), c);
    await settle(tester);
    // no georeference: the site's series is the one offered first
    expect(find.textContaining('inmet, 2001–2010'), findsOneWidget);
    await tester.tap(find.byKey(const Key('clr_run')));
    await until(tester, () => c.project.climateRisk != null);
    expect(requests, isEmpty);
    final s = c.project.climateRisk!;
    expect(s.source, 'inmet');
    expect(s.attribution, 'INMET A701');
    expect(s.site.length, greaterThanOrEqualTo(9));
    expect(tester.takeException(), isNull, reason: 'the results lay out on a phone');
    await tester.tap(find.byKey(const Key('clr_close')));
    await settle(tester);
    // a download stopped before it ends keeps nothing
    c.setGeoreferenceAt(-22.9, -47.06);
    final kept = c.project.climateRisk;
    Object? error;
    await tester.runAsync(() async {
      try {
        await runClimateRisk(c, cancelled: () => true);
      } catch (e) {
        error = e;
      }
    });
    expect(error, isA<ClimateException>().having((e) => e.code, 'code', 'climate_cancelled'));
    expect(identical(c.project.climateRisk, kept), isTrue);
  });

  testWidgets('the assistant\'s operation: same figures, its effect by what it does', (tester) async {
    final c = await pumpShell(tester, const Size(1600, 1000));
    final box = AgentToolbox(c, host: _Host());
    final op = box.operations.firstWhere((o) => o.name == 'climate_risk');
    expect(op.effectOf({}), ToolEffect.write);
    expect(op.effectOf({'keep': false}), ToolEffect.network);
    expect(op.effectOf({'keep': false, 'source': 'site'}), ToolEffect.read);
    expect(op.effectOf({'use_kept': true}), ToolEffect.read);
    Future<String> run(Map<String, dynamic> input) async {
      String? text;
      Object? error;
      await tester.runAsync(() async {
        try {
          text = (await op.run(input)).text;
        } catch (e) {
          error = e;
        }
      });
      if (error != null) return 'ERROR ${error is ToolInputError ? (error as ToolInputError).message : error}';
      return text!;
    }

    expect(await run({}), contains('set_site'));
    expect(await run({'use_kept': true}), contains('keeps no climate risk'));
    c.setGeoreferenceAt(-22.9, -47.06);
    final area = c.project.entities.whereType<AreaEntity>().first;
    final out = await run({'probability': 0.9, 'peak_days': 10, 'area': area.id});
    expect(out, contains('Kept in the project'));
    expect(out, contains('Climate risk over 1984–1994'));
    expect(out, contains('design values at P90'));
    expect(out, contains('Seasons of'));
    final s = c.project.climateRisk!;
    expect(s.probability, 0.9);
    expect(s.peakDays, 10);
    // the kept one, read again without a download
    final n = requests.length;
    final again = await run({'use_kept': true});
    expect(again, contains('Year by year'));
    expect(requests, hasLength(n));
    // only answering leaves the project as it was
    final hist = c.historyIndex;
    expect(await run({'keep': false}), isNot(contains('Kept in the project')));
    expect(c.historyIndex, hist);
    expect(await run({'area': 'nothing-like-this'}), startsWith('ERROR'));
  });
}
