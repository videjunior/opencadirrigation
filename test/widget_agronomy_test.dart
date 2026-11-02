import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/canvas/cad_canvas.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/dialogs/agronomy_dialogs.dart';
import 'package:opencadirrigation/core/io/climate_online.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/core/model/site_climate.dart';
import 'package:opencadirrigation/main.dart';

/// The site climate (downloaded and typed), the requirement report and the
/// agronomy calculators: solar pumping, wetted bulb and water budget.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<ProjectController> pumpShell(WidgetTester tester) async {
    TutorialController.markDone();
    setPref('lang', 'pt');
    LocalProjectStore().clearAll();
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false));
    await settle(tester);
    final shell = tester.state(find.byType(AppShell)) as dynamic;
    final ProjectController c = shell.c as ProjectController;
    c
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.snap.enabled = false;
    c.newProject();
    await settle(tester);
    return c;
  }

  BuildContext ctxOf(WidgetTester tester) => tester.element(find.byType(CadCanvas));

  /// Open-Meteo answered from the request: ETo 4 mm/day, 3 mm of rain a
  /// day, 18 MJ/m² of radiation (5 kWh/m²).
  final requests = <String>[];
  Future<String> fakeOpenMeteo(String url) async {
    requests.add(url);
    final q = Uri.parse(url).queryParameters;
    final s = DateTime.parse(q['start_date']!), e = DateTime.parse(q['end_date']!);
    final time = <String>[];
    for (var d = DateTime.utc(s.year, s.month, s.day); !d.isAfter(DateTime.utc(e.year, e.month, e.day)); d = d.add(const Duration(days: 1))) {
      time.add(d.toIso8601String().substring(0, 10));
    }
    List<double> f(double v) => List.filled(time.length, v);
    return jsonEncode({
      'elevation': 600,
      'daily_units': {'wind_speed_10m_mean': 'm/s'},
      'daily': {
        'time': time,
        'et0_fao_evapotranspiration': f(4),
        'precipitation_sum': f(3),
        'temperature_2m_max': f(30),
        'temperature_2m_min': f(18),
        'wind_speed_10m_mean': f(3),
        'shortwave_radiation_sum': f(18),
        'relative_humidity_2m_max': f(90),
        'relative_humidity_2m_min': f(40),
        'dew_point_2m_mean': f(15),
      },
    });
  }

  setUp(() {
    requests.clear();
    ProjectController.climateUrlLoader = fakeOpenMeteo;
  });

  testWidgets('downloads the site climate into the project as one undo step', (tester) async {
    final c = await pumpShell(tester);
    await expectLater(c.downloadClimate(ClimateSource.openMeteo, years: 1), throwsA(isA<ClimateException>().having((e) => e.code, 'code', 'climate_no_site')));
    expect(c.describeError(const ClimateException('climate_no_site', '')), contains('Georreferencie'));
    expect(c.describeError(const ClimateException('climate_service_error', 'HTTP 500')), contains('HTTP 500'));
    c.setGeoreferenceAt(-21.8, -46.6);
    await settle(tester);
    final before = c.historyIndex;
    final sc = await tester.runAsync(() => c.downloadClimate(ClimateSource.openMeteo, years: 2));
    expect(requests, isNotEmpty);
    expect(sc!.source, 'openMeteo');
    expect(sc.attribution, isNotEmpty);
    expect(sc.lastYear - sc.firstYear, 1);
    expect(sc.etoMmDay, everyElement(closeTo(4, 1e-9)));
    expect(sc.solarKWhM2Day, everyElement(closeTo(5, 1e-6)));
    expect(c.project.climate, same(sc));
    expect(c.historyIndex, before + 1);
    // kept in the file
    final back = SiteClimate.fromJson((jsonDecode(jsonEncode(c.project.toJson())) as Map<String, dynamic>)['climate'] as Map<String, dynamic>?)!;
    expect(back.rainMm, sc.rainMm);
    expect(back.attribution, sc.attribution);
    c.undo();
    expect(c.project.climate, isNull);
  });

  testWidgets('the climate dialog edits the months; edited values become typed data', (tester) async {
    final c = await pumpShell(tester);
    c.setClimate(SiteClimate(etoMmDay: List.filled(12, 5), rainMm: List.filled(12, 60), source: 'openMeteo', attribution: 'Weather data by Open-Meteo.com'));
    await settle(tester);
    final before = c.historyIndex;
    showSiteClimateDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.text('Clima do local'), findsOneWidget);
    for (final m in ['Janeiro', 'Junho', 'Dezembro']) {
      expect(find.text(m), findsOneWidget);
    }
    expect(find.textContaining('Georreferencie'), findsOneWidget, reason: 'no site to download for');
    // OK with nothing changed: no new undo step
    await tester.tap(find.byKey(const Key('clim_ok')));
    await settle(tester);
    expect(c.historyIndex, before);
    expect(c.project.climate!.source, 'openMeteo');
    // July ETo typed over the download
    showSiteClimateDialog(ctxOf(tester), c);
    await settle(tester);
    final july = find.descendant(of: find.byType(Table), matching: find.byType(TextField)).at(6 * 4);
    await tester.tap(july);
    await tester.enterText(july, '6,5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 2);
    await tester.tap(find.byKey(const Key('clim_ok')));
    await settle(tester);
    expect(c.project.climate!.etoMmDay[6], closeTo(6.5, 1e-9));
    expect(c.project.climate!.etoMmDay[5], 5);
    expect(c.project.climate!.source, 'manual');
    expect(c.project.climate!.attribution, isNotEmpty, reason: 'the credit stays with data derived from the service');
    expect(c.historyIndex, before + 1);
    // removed
    showSiteClimateDialog(ctxOf(tester), c);
    await settle(tester);
    await tester.tap(find.text('Remover clima'));
    await settle(tester);
    expect(c.project.climate, isNull);
  });

  testWidgets('an area with a crop of the table gets the requirement report; the calculators open', (tester) async {
    final c = await pumpShell(tester);
    c.setClimate(SiteClimate(etoMmDay: [for (var m = 0; m < 12; m++) 3.0 + m % 6], rainMm: List.filled(12, 40), solarKWhM2Day: List.filled(12, 5.5)));
    final area = AreaEntity(id: c.project.newId(), points: const [Pt(0, 0), Pt(100, 0), Pt(100, 100), Pt(0, 100)], name: 'Talhão 1')
      ..cropKey = 'crop.maize'
      ..plantingMonthDay = '09-15'
      ..soilKey = 'soil.loam'
      ..plantWaterUse = 'low';
    c.addEntity(area);
    await settle(tester);
    final tables = c.reportTables();
    final req = tables.firstWhere((t) => t.key == 'requirement');
    expect(req.rows, isNotEmpty);
    expect(req.rows.first[1], 'Milho');
    expect(tables.firstWhere((t) => t.key == 'requirementTotals').rows, hasLength(1));

    showSolarPumpingDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.text('Bombeamento solar fotovoltaico'), findsOneWidget);
    expect(find.text('Mês crítico'), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await settle(tester);

    showWettedBulbDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.text('Largura molhada'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^\d+ %$')), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await settle(tester);

    showWaterBudgetDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.text('Talhão 1'), findsOneWidget);
    expect(find.text('MAWA'), findsOneWidget);
    expect(find.text('ETWU'), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await settle(tester);
  });
}
