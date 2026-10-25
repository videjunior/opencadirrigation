import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/canvas/cad_canvas.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/dialogs/transient_dialogs.dart';
import 'package:opencadirrigation/app/widgets/fields.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/main.dart';

/// The mainline dialogs: hydraulic transients, air valves (inserted as one
/// undo step) and the 24-hour simulation, on the designed orchard example.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  /// Pumps frames until [f] shows (the dialogs compute between frames).
  Future<void> until(WidgetTester tester, Finder f, {int max = 300}) async {
    for (var i = 0; i < max && f.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(f, findsWidgets);
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
    loadExampleAction(c, ExampleId.orchard);
    await settle(tester);
    // the design runs real async work: outside the fake-async test zone
    await tester.runAsync(() => c.runDesign());
    await settle(tester);
    expect(c.results, isNotNull);
    return c;
  }

  BuildContext ctxOf(WidgetTester tester) => tester.element(find.byType(CadCanvas));

  List<MiscHydraulicEntity> airValves(ProjectController c) => [
    for (final e in c.project.entities.whereType<MiscHydraulicEntity>())
      if (c.project.catalog.valve(e.valveSpecId)?.kind == ValveKind.airRelease) e,
  ];

  testWidgets('the transient dialog simulates the scenarios of every flow with charts, the pipe table and the messages', (tester) async {
    final c = await pumpShell(tester);
    showTransientDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.text('Transientes hidráulicos (golpe de aríete)'), findsOneWidget);
    expect(find.text('Fechamento das válvulas dos setores do turno'), findsOneWidget);
    expect(find.byKey(const Key('tr_poles')), findsNothing, reason: 'the motor options belong to the pump trip');
    await tester.tap(find.byKey(const Key('tr_sc_pumpTrip')));
    await settle(tester, 2);
    expect(find.byKey(const Key('tr_poles')), findsOneWidget);
    expect(find.byKey(const Key('tr_inertia')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tr_run')));
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byKey(const Key('tr_progress')), findsOneWidget, reason: 'a progress bar while the flows are simulated');
    await until(tester, find.byKey(const Key('tr_profile')));
    expect(find.byKey(const Key('tr_series')), findsOneWidget);
    expect(find.text('TUBOS E SUAS CLASSES'), findsOneWidget);
    final a = lastTransientAnalysis(c)!;
    expect(a.runs, hasLength(c.project.systemFlows.length * 2));
    expect(a.runs.every((r) => r.ran), isTrue);
    // the worst run shows first: the power failure empties the dead-end branch
    expect(a.runs[a.worstRun].scenario.name, 'pumpTrip');
    expect(find.textContaining('Vácuo no transiente'), findsWidgets);
    expect(find.textContaining('vácuo'), findsWidgets, reason: 'the status column');
    // another run
    await tester.tap(find.byKey(const Key('tr_pick')));
    await settle(tester, 2);
    await tester.tap(find.textContaining('Fechamento das válvulas dos setores do turno').last);
    await settle(tester);
    expect(find.byKey(const Key('tr_profile')), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await settle(tester);
    expect(find.byKey(const Key('tr_run')), findsNothing);
    // opened again, the last analysis is shown at once
    showTransientDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.byKey(const Key('tr_profile')), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await settle(tester);
  });

  testWidgets('the air valve dialog lists the suggestions and inserts them as one undo step', (tester) async {
    final c = await pumpShell(tester);
    expect(airValves(c), isEmpty);
    final entities = c.project.entities.length;
    final history = c.historyIndex;
    showAirValveDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.text('Ventosas na linha principal'), findsOneWidget);
    await until(tester, find.text('Item do catálogo'));
    expect(find.textContaining('Sem transiente simulado'), findsOneWidget);
    expect(find.text('saída da bomba'), findsWidgets);
    expect(find.textContaining('fim da linha'), findsWidgets);
    final insert = tester.widget<FilledButton>(find.byKey(const Key('av_insert')));
    expect(insert.onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('av_insert')));
    await settle(tester);
    expect(find.text('Ventosas na linha principal'), findsNothing, reason: 'the dialog closes');
    final added = airValves(c);
    expect(added, isNotEmpty);
    expect(c.project.entities.length, entities + added.length);
    expect(c.historyIndex, history + 1, reason: 'one undo step');
    expect(c.historyEntries.last.label, 'hist.airValves|${added.length}');
    expect(c.results, isNull, reason: 'the drawing changed');
    for (final e in added) {
      expect(e.scope, HydraulicScope.mainline);
    }
    // opened again: the valves are there
    showAirValveDialog(ctxOf(tester), c);
    await until(tester, find.text('Item do catálogo'));
    expect(find.textContaining('existente'), findsWidgets);
    expect(tester.widget<FilledButton>(find.byKey(const Key('av_insert'))).onPressed, isNull, reason: 'nothing left to insert');
    await tester.tap(find.text('Fechar'));
    await settle(tester);
    c.undo();
    await settle(tester);
    expect(airValves(c), isEmpty);
    expect(c.project.entities.length, entities);
  });

  testWidgets('the three dialogs open, run and close on a phone screen', (tester) async {
    final c = await pumpShell(tester);
    tester.view.physicalSize = const Size(390, 844);
    await settle(tester);
    Future<void> tapVisible(Finder f) async {
      await tester.ensureVisible(f);
      await tester.pump();
      await tester.tap(f);
      await settle(tester, 2);
    }

    Future<void> close() async {
      await tester.ensureVisible(find.text('Fechar').last);
      await tester.pump();
      await tester.tap(find.text('Fechar').last);
      await settle(tester);
    }

    showTransientDialog(ctxOf(tester), c);
    await settle(tester);
    expect(tester.takeException(), isNull, reason: 'transients: options');
    await tapVisible(find.byKey(const Key('tr_sc_pumpTrip')));
    await tapVisible(find.byKey(const Key('tr_run')));
    await until(tester, find.byKey(const Key('tr_profile')));
    await settle(tester);
    expect(tester.takeException(), isNull, reason: 'transients: results');
    await close();
    showAirValveDialog(ctxOf(tester), c);
    await until(tester, find.text('Item do catálogo'));
    expect(tester.takeException(), isNull, reason: 'air valves');
    await close();
    showEpsDialog(ctxOf(tester), c);
    await until(tester, find.byKey(const Key('eps_flow')));
    await settle(tester);
    expect(tester.takeException(), isNull, reason: '24 hours');
    await close();
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a water supply the dialogs say what is missing', (tester) async {
    final c = await pumpShell(tester);
    c.newProject();
    await settle(tester);
    showTransientDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.textContaining('Sem resultados de projeto'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tr_run')));
    await until(tester, find.byKey(const Key('tr_pick')));
    expect(find.textContaining('Nenhuma fonte de água conectada'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Fechar'));
    await settle(tester);
    showAirValveDialog(ctxOf(tester), c);
    await until(tester, find.text('Nenhuma ventosa sugerida.'));
    expect(find.textContaining('Nenhuma fonte de água conectada'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('av_insert'))).onPressed, isNull);
    await tester.tap(find.text('Fechar'));
    await settle(tester);
    showEpsDialog(ctxOf(tester), c);
    await until(tester, find.text('Energia do dia'));
    expect(find.textContaining('Nenhuma fonte de água conectada'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Fechar'));
    await settle(tester);
  });

  testWidgets('the 24-hour dialog simulates the day with charts and the energy per pump and hour', (tester) async {
    final c = await pumpShell(tester);
    showEpsDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.text('Simulação de 24 horas (período estendido)'), findsOneWidget);
    await until(tester, find.byKey(const Key('eps_flow')));
    expect(find.byKey(const Key('eps_power')), findsOneWidget);
    expect(find.byKey(const Key('eps_pressure')), findsOneWidget);
    expect(find.text('TOTAL'), findsOneWidget);
    String kv(String k) => tester.widgetList<KV>(find.byType(KV)).firstWhere((w) => w.k == k).v;
    final energy = kv('Energia do dia'), cost = kv('Custo do dia');
    expect(energy, endsWith('kWh'));
    expect(energy, isNot(startsWith('0.0')));
    // a peak band over the morning shift at three times the price
    Future<void> field(String key, String value) async {
      final f = find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));
      await tester.tap(f);
      await tester.enterText(f, value);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester, 2);
    }

    await field('eps_peak_start', '6');
    await field('eps_peak_end', '9');
    await field('eps_peak_factor', '3');
    await tester.tap(find.byKey(const Key('eps_run')));
    await settle(tester, 2);
    await until(tester, find.byKey(const Key('eps_flow')));
    expect(kv('Energia do dia'), energy, reason: 'the tariff does not change the energy');
    expect(kv('Custo do dia'), isNot(cost));
    await tester.tap(find.text('Fechar'));
    await settle(tester);
  });
}
