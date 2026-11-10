import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/ai/agent_tools_agent.dart';
import 'package:opencadirrigation/app/ai/ai_coverage.dart';
import 'package:opencadirrigation/app/ai/ops_eng_common.dart';
import 'package:opencadirrigation/app/io/forecast_http.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/widgets/dialogs/data_cache_dialog.dart';
import 'package:opencadirrigation/app/widgets/dialogs/forecast_dialog.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/design/irrigation_forecast.dart';
import 'package:opencadirrigation/core/io/data_credits.dart';
import 'package:opencadirrigation/core/io/geo.dart';
import 'package:opencadirrigation/core/io/project_export.dart' show ReportFormat;
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/project.dart';

/// The irrigation forecast in the interface (1.7.0 FCT): the dialog with a fake fetcher (the recorded answers of
/// test/fixtures/forecast), on a desktop and on a phone, in light and dark themes, without a site or areas; the
/// exports; the operation of the assistant and its coverage.
class _Host implements AgentHost {
  @override
  AgentPermission permission = AgentPermission.auto;
  @override
  bool stopped = false;
  @override
  String notes = '';
  @override
  final Map<String, Uint8List> files = {};
  @override
  String get instructions => '';
  @override
  void setTodos(List<AiTodo> items) {}
  @override
  Future<List<String>?> ask(List<AiQuestion> questions) async => null;
  @override
  Future<PlanDecision?> reviewPlan(String plan) async => null;
  @override
  void setNotes(String text) => notes = text;
  @override
  bool openTab(Project p) => false;
}

void main() {
  final met = File('test/fixtures/forecast/met_locationforecast.json').readAsStringSync();
  final om = File('test/fixtures/forecast/open_meteo_forecast.json').readAsStringSync();
  final saveLoader = forecastUrlLoader, saveClock = forecastClock, saveBrowser = forecastFromBrowser, saveFiles = engFileSink;
  late ProjectController c;
  late List<(String, Map<String, String>)> calls;
  late Future<ForecastHttpResponse> Function(String url) answer;
  const square = [Pt(0, 0), Pt(10, 0), Pt(10, 10), Pt(0, 10)];

  Project field({bool georef = true, bool areas = true}) {
    final p = Project(
      entities: [
        if (areas) AreaEntity(id: 'a', name: 'Block A', points: square, useWaterBalance: true, etoMmDay: 5, kc: 1, awcMmPerM: 100, rootDepthM: 1, mad: 0.5, efficiency: 0.8),
        if (areas)
          for (final (x, y) in const [(2.5, 2.5), (7.5, 2.5), (2.5, 7.5), (7.5, 7.5)]) OutletEntity(id: 's$x$y', position: Pt(x, y), outletSpecId: 'spray', nozzleId: 's12', headM: 20),
        if (!areas) LineEntity(id: 'l', a: Pt.zero, b: const Pt(10, 10)),
      ],
    );
    if (georef) p.meta.georef = GeoReference.fromLatLonOrigin(-22.7253, -47.6492);
    return p;
  }

  setUp(() async {
    LocalProjectStore().clearAll();
    debugClearForecastMemory();
    c = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
    await c.setLanguage('en', persist: false);
    calls = [];
    answer = (url) async => ForecastHttpResponse(200, url.contains('open-meteo') ? om : met, expires: 'Tue, 10 Nov 2026 12:30:00 GMT');
    forecastUrlLoader = (url, headers) {
      calls.add((url, headers));
      return answer(url);
    };
    // 09:00 at the site on 10 November 2026
    forecastClock = () => DateTime.utc(2026, 11, 10, 12);
    forecastFromBrowser = true;
  });
  tearDown(() {
    forecastUrlLoader = saveLoader;
    forecastClock = saveClock;
    forecastFromBrowser = saveBrowser;
    engFileSink = saveFiles;
    Cad.use(Brightness.light);
  });

  Future<BuildContext> app(WidgetTester tester, {Size size = const Size(1400, 1000), Brightness brightness = Brightness.light}) async {
    Cad.use(brightness);
    late BuildContext ctx;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCadTheme(brightness),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return ctx;
  }

  testWidgets('without a site or without areas: a clear message, nothing fetched', (tester) async {
    final ctx = await app(tester);
    c.openProject(field(georef: false));
    showIrrigationForecastDialog(ctx, c);
    await tester.pumpAndSettle();
    expect(find.text(c.t('fct.err.fc_no_site')), findsOneWidget);
    await tester.tap(find.text(c.t('close')));
    await tester.pumpAndSettle();
    c.openProject(field(areas: false));
    showIrrigationForecastDialog(ctx, c);
    await tester.pumpAndSettle();
    expect(find.text(c.t('fct.noAreas')), findsOneWidget);
    await tester.tap(find.text(c.t('close')));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
  });

  for (final dark in [false, true]) {
    testWidgets('desktop, ${dark ? 'dark' : 'light'}: nothing until asked; the plan, the chart, the credit; not again before Expires', (tester) async {
      final ctx = await app(tester, brightness: dark ? Brightness.dark : Brightness.light);
      c.openProject(field());
      showIrrigationForecastDialog(ctx, c);
      await tester.pumpAndSettle();
      expect(find.text(c.t('fct.title')), findsOneWidget);
      expect(calls, isEmpty, reason: 'nothing is fetched until the user asks');
      expect(find.byKey(const Key('fct_table')), findsNothing);
      await tester.tap(find.byKey(const Key('fct_fetch')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
      expect(calls.single.$1, startsWith('https://api.met.no/weatherapi/locationforecast/2.0/complete?lat=-22.72'));
      expect(calls.single.$2, isEmpty, reason: 'a browser page adds no header');
      expect(find.byKey(const Key('fct_chart')), findsOneWidget);
      expect(find.byKey(const Key('fct_table')), findsOneWidget);
      expect(find.text('Block A'), findsWidgets);
      expect(find.textContaining('Based on data from MET Norway'), findsOneWidget);
      expect(find.text(c.t('fct.etoBy.pm')), findsOneWidget);
      expect(find.byKey(const Key('fct_assume')), findsOneWidget);
      expect(find.text(c.t('fct.w.fct_no_results')), findsOneWidget);
      // the service asks not to come back before 12:30 UTC
      expect(find.byKey(const Key('fct_too_soon')), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('fct_fetch'))).onPressed, isNull);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('fct_close')));
      await tester.pumpAndSettle();
      // opened again: the kept forecast, no new request
      showIrrigationForecastDialog(ctx, c);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fct_table')), findsOneWidget);
      expect(find.textContaining(c.t('fct.kept')), findsOneWidget);
      expect(calls, hasLength(1));
      await tester.tap(find.byKey(const Key('fct_close')));
      await tester.pumpAndSettle();
    });
  }

  testWidgets('phone: the dialog fits 360 px, the soil at the start, Open-Meteo marked non-commercial with its own ETo', (tester) async {
    final ctx = await app(tester, size: const Size(360, 740));
    c.openProject(field());
    showIrrigationForecastDialog(ctx, c);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fct_source')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(c.t('fct.src.openMeteo')).last);
    await tester.pumpAndSettle();
    expect(find.text(c.t('terms.src.openMeteoForecast')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('fct_terms'))).style?.color, Cad.warning);
    await tester.tap(find.byKey(const Key('fct_start')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(c.t('fct.start.last')).last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fct_days_ago_1')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('fct_fetch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fct_fetch')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(calls.single.$1, startsWith('https://api.open-meteo.com/v1/forecast?'));
    expect(find.text(c.t('fct.etoBy.service')), findsOneWidget);
    expect(find.byKey(const Key('fct_table')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('fct_close')));
    await tester.pumpAndSettle();
  });

  testWidgets('a failed fetch says so and shows no plan', (tester) async {
    final ctx = await app(tester);
    c.openProject(field());
    answer = (url) async => throw const SocketException('offline');
    showIrrigationForecastDialog(ctx, c);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fct_fetch')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fct_error')), findsOneWidget);
    expect(find.text(c.t('fct.err.fc_network')), findsOneWidget);
    expect(find.byKey(const Key('fct_table')), findsNothing);
    answer = (url) async => const ForecastHttpResponse(429, '');
    await tester.tap(find.byKey(const Key('fct_fetch')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(find.text(c.t('fct.err.fc_rate_limited')), findsOneWidget);
    await tester.tap(find.byKey(const Key('fct_close')));
    await tester.pumpAndSettle();
  });

  testWidgets('the exports: the two tables as CSV and XLSX', (tester) async {
    c.openProject(field());
    final s = await fetchSiteForecast(c, ForecastSource.metNorway);
    final plan = irrigationForecast(c.project, c.results, s, now: forecastClock());
    final (name, csv) = await forecastExportFile(c, plan, ReportFormat.csv);
    expect(name, endsWith('_${c.t('fct.file')}.csv'));
    expect(csv as String, contains(c.t('fct.table.plan').toUpperCase()));
    expect(csv, contains('Block A;156;'));
    expect(csv, contains(c.t('fct.table.days').toUpperCase()));
    final (xname, xlsx) = await forecastExportFile(c, plan, ReportFormat.xlsx);
    expect(xname, endsWith('.xlsx'));
    expect((xlsx as Uint8List).sublist(0, 2), [0x50, 0x4b], reason: 'a zip (Office Open XML)');
  });

  testWidgets('the sources in Help → Terms of the data and the kind in File → Saved downloaded data', (tester) async {
    expect(dataSources.where((s) => s.kind == DataKind.forecast).map((s) => s.id), ['metNorway', 'openMeteoForecast']);
    expect(dataSources.firstWhere((s) => s.id == 'metNorway').use, DataUse.any);
    expect(dataSources.firstWhere((s) => s.id == 'openMeteoForecast').use, DataUse.nonCommercial);
    for (final s in dataSources) {
      expect(c.t.has('terms.src.${s.id}'), isTrue, reason: s.id);
      expect(c.t.has('src.kind.${s.kind.name}'), isTrue, reason: s.kind.name);
    }
    expect(dataCacheKinds, contains('forecast'));
    expect(c.t.has('cache.forecast'), isTrue);
  });

  group('the assistant', () {
    late AgentToolbox box;
    final files = <String, Object>{};
    setUp(() {
      box = AgentToolbox(c, host: _Host());
      files.clear();
      engFileSink = (c, name, mime, data) async => files[name] = data;
    });
    AgentTool op(String name) => box.operations.firstWhere((o) => o.name == name);

    testWidgets('the operation asks an online service (an export is confirmed); the menu and the dialog have their route', (tester) async {
      final o = op('irrigation_forecast');
      expect(o.effectOf(const {}), ToolEffect.network);
      expect(o.mustConfirm(const {}), isFalse);
      expect(o.effectOf(const {'export': 'csv'}), ToolEffect.export);
      expect(o.mustConfirm(const {'export': 'csv'}), isTrue);
      expect(o.describe(const {}), c.t('ai.op.irrigation_forecast'));
      for (final k in ['menu:fct.menu', 'dialog:forecast_dialog.irrigationForecast']) {
        expect(aiCoverage[k], 'op:irrigation_forecast', reason: k);
      }
    });

    testWidgets('how much to irrigate today: the plan in words, the credit, the assumptions', (tester) async {
      c.openProject(field());
      final out = (await op('irrigation_forecast').run(const {'start': 'last', 'days_ago': 3})).text;
      expect(calls, hasLength(1));
      expect(out, contains('MET Norway Locationforecast'));
      expect(out, contains('Credit: Based on data from MET Norway'));
      expect(out, contains('Block A (a):'));
      expect(out, contains('water budget'));
      expect(out, contains('2026-11-10'));
      expect(out, contains('Assumptions: A forecast is uncertain'));
      // asked again: the kept answer
      final again = (await op('irrigation_forecast').run(const {'source': 'met_norway', 'area': 'Block A', 'export': 'csv'})).text;
      expect(calls, hasLength(1));
      expect(again, contains('kept on this device'));
      expect(files.keys.single, endsWith('.csv'));
      // without a site the model is told what to do
      c.openProject(field(georef: false));
      await expectLater(op('irrigation_forecast').run(const {}), throwsA(isA<ToolInputError>().having((e) => e.message, 'message', contains('set_site'))));
      c.openProject(field());
      await expectLater(op('irrigation_forecast').run(const {'area': 'l'}), throwsA(isA<ToolInputError>()));
    });
  });
}
