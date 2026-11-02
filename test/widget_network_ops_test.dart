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
import 'package:opencadirrigation/app/widgets/dialogs/network_ops_dialogs.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/units.dart';
import 'package:opencadirrigation/main.dart';

/// The network operation dialogs on a designed example: on-demand flows and
/// the random check, the tariff schedule, the grouping of zones for energy,
/// automatic wire routes, criticality, calibration and fertigation; every
/// change they apply is one undo step.
void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> until(WidgetTester tester, bool Function() done, {int max = 3000}) async {
    for (var i = 0; i < max && !done(); i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(done(), isTrue, reason: 'condition not reached');
    await settle(tester, 2);
  }

  Future<ProjectController> pumpShell(WidgetTester tester, {Size size = const Size(1920, 1080)}) async {
    TutorialController.markDone();
    setPref('lang', 'pt');
    LocalProjectStore().clearAll();
    tester.view.physicalSize = size;
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
    return c;
  }

  /// The orchard example (two zones, a pump, a filter, a controller with its
  /// wire routes, two system flows), designed.
  Future<ProjectController> designedOrchard(WidgetTester tester, {Size size = const Size(1920, 1080)}) async {
    final c = await pumpShell(tester, size: size);
    loadExampleAction(c, ExampleId.orchard);
    await settle(tester);
    c.runDesign();
    await until(tester, () => !c.busy && c.results != null);
    return c;
  }

  BuildContext ctxOf(WidgetTester tester) => tester.element(find.byType(CadCanvas));

  Future<void> tapVisible(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle(tester);
  }

  Future<void> enter(WidgetTester tester, Finder field, String value) async {
    final f = find.descendant(of: field, matching: find.byType(TextField));
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(f, value);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 2);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.tap(find.text('Fechar').last);
    await settle(tester);
  }

  testWidgets('without a design the analyses say what is missing', (tester) async {
    final c = await pumpShell(tester);
    c.newProject();
    await settle(tester);
    for (final show in [showOnDemandDialog, showTariffDialog, showEnergyGroupingDialog, showCriticalityDialog, showCalibrationDialog, showFertigationDialog]) {
      show(ctxOf(tester), c);
      await settle(tester);
      expect(find.text('Execute Projeto ▶ para gerar resultados'), findsOneWidget);
      await close(tester);
    }
    // the routes need no design: no controller to route from
    showWireRoutingDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.text('Rotas automáticas de fios'), findsOneWidget);
    expect(find.text('Nenhum controlador no projeto'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('wr_apply'))).onPressed, isNull);
    await close(tester);
  });

  testWidgets('on demand: Clément flows of the mainline and the random check', (tester) async {
    final c = await designedOrchard(tester);
    final zones = [for (final v in c.project.entities.whereType<ControlValveEntity>()) v.zoneName];
    showOnDemandDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.text('Linha principal sob demanda'), findsOneWidget);
    expect(find.text('HIDRANTES'), findsOneWidget);
    for (final z in zones) {
      expect(find.text(z), findsWidgets);
    }
    expect(find.text('Q Clément (${c.units.flowLabel})'), findsOneWidget);
    // two hydrants, fewer than Nmin: the trunk carries both
    expect(find.text('Todos abertos'), findsWidgets);
    expect(find.text('Configurações calculadas'), findsNothing);
    await enter(tester, find.byKey(const Key('od_configs')), '40');
    await tapVisible(tester, find.byKey(const Key('od_run')));
    await settle(tester);
    expect(find.text('Configurações calculadas'), findsOneWidget);
    expect(find.text('40'), findsWidgets);
    expect(find.text('Sorteios com falta de pressão'), findsOneWidget);
    expect(find.text('Confiabilidade'), findsOneWidget);
    await close(tester);
  });

  testWidgets('tariff: the least-cost start hours are applied as one undo step that keeps the results', (tester) async {
    final c = await designedOrchard(tester);
    final before = {for (final f in c.project.systemFlows) f.id: f.startHour};
    final history = c.historyIndex;
    showTariffDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.text('Tarifa horária de energia'), findsOneWidget);
    // a project in reais: the Brazilian discount by default
    expect(find.text('Brasil: tarifa rural de irrigação'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('tar_apply'))).onPressed, isNull, reason: 'nothing computed yet');
    await tapVisible(tester, find.byKey(const Key('tar_compute')));
    await settle(tester);
    expect(find.text('HORÁRIOS DE MENOR CUSTO'), findsOneWidget);
    expect(find.text('Horários atuais'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tar_apply')));
    await settle(tester);
    expect(find.text('Tarifa horária de energia'), findsNothing);
    final after = {for (final f in c.project.systemFlows) f.id: f.startHour};
    expect(after, isNot(before), reason: 'the discount window is at night: the flows move there');
    expect(c.historyIndex, history + 1);
    expect(c.results, isNotNull, reason: 'start hours change no hydraulic result');
    c.undo();
    await settle(tester);
    expect({for (final f in c.project.systemFlows) f.id: f.startHour}, before);
  });

  testWidgets('energy grouping: one group replaces the system flows, one undo restores them', (tester) async {
    final c = await designedOrchard(tester);
    final before = [for (final f in c.project.systemFlows) f.toJson()];
    final valves = {for (final v in c.project.entities.whereType<ControlValveEntity>()) v.id};
    showEnergyGroupingDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.text('Turnos de menor consumo de energia'), findsOneWidget);
    await enter(tester, find.byKey(const Key('eg_max_flow')), '1000000');
    await enter(tester, find.byKey(const Key('eg_max_groups')), '1');
    await tapVisible(tester, find.byKey(const Key('eg_compute')));
    await settle(tester);
    expect(find.text('PROPOSTA'), findsOneWidget);
    expect(find.text('Turnos atuais (por rodada)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('eg_apply')));
    await settle(tester);
    expect(c.project.systemFlows, hasLength(1));
    expect(c.project.systemFlows.single.valveIds, valves);
    expect(c.results, isNull, reason: 'new system flows: the design must run again');
    c.undo();
    await settle(tester);
    expect([for (final f in c.project.systemFlows) f.toJson()], before);
  });

  testWidgets('wire routes: drawn along the trenches in one undo step, with the two-wire sizing', (tester) async {
    final c = await designedOrchard(tester);
    final before = [for (final w in c.project.entities.whereType<WireEntity>()) w.id];
    expect(before, isNotEmpty);
    showWireRoutingDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.text('Rotas automáticas de fios'), findsOneWidget);
    expect(find.text('Válvula de zona'), findsNWidgets(2));
    expect(find.text('Relé da bomba'), findsOneWidget);
    expect(find.text('SISTEMA DE DOIS FIOS (DECODIFICADORES)'), findsOneWidget);
    expect(find.text('Pontos de aterramento'), findsOneWidget);
    // the layout of least total length, as for a two-wire path
    await tapVisible(tester, find.byKey(const Key('wr_mode')));
    await tester.tap(find.text('Dois fios: menor comprimento total').last);
    await settle(tester);
    final history = c.historyIndex;
    await tester.tap(find.byKey(const Key('wr_apply')));
    await settle(tester);
    final wires = c.project.entities.whereType<WireEntity>().toList();
    expect(wires, isNotEmpty);
    expect(wires.map((w) => w.id).toSet().intersection(before.toSet()), isEmpty, reason: 'the routes drawn replace the old ones');
    expect(c.historyIndex, history + 1);
    c.undo();
    await settle(tester);
    expect([for (final w in c.project.entities.whereType<WireEntity>()) w.id], before);
  });

  testWidgets('criticality: the pipes of the branched mainline ranked by the demand they cut off', (tester) async {
    final c = await designedOrchard(tester);
    showCriticalityDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.text('Criticidade dos tubos da linha principal'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('crit_run')));
    await settle(tester);
    expect(find.text('Zonas sem água'), findsOneWidget);
    expect(find.text('Linha ramificada: cada tubo corta o que está a jusante dele.'), findsOneWidget);
    // with the decimal comma of Portuguese (UI-08)
    expect(find.text('100,0 %'), findsWidgets, reason: 'the riser cuts the whole flow off');
    await close(tester);
  });

  testWidgets('calibration: a lower pressure read at a valve gives a lower C, applied as one undo step', (tester) async {
    final c = await designedOrchard(tester);
    expect(c.project.params.hazenCScale, 1);
    showCalibrationDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.text('Calibração da rugosidade (C de Hazen-Williams)'), findsOneWidget);
    final field = find.descendant(of: find.byKey(const ValueKey('cal_p_0')), matching: find.byType(TextField));
    final model = parseNumber(tester.widget<TextField>(field).controller!.text)!;
    await enter(tester, find.byKey(const ValueKey('cal_p_0')), fmt(model - 0.5, 2));
    await tapVisible(tester, find.byKey(const Key('cal_run')));
    await settle(tester);
    expect(find.text('Fator do C ajustado'), findsOneWidget);
    expect(find.text('Resíduo'), findsOneWidget);
    final history = c.historyIndex;
    await tester.tap(find.byKey(const Key('cal_apply')));
    await settle(tester);
    expect(c.project.params.hazenCScale, lessThan(1));
    expect(c.historyIndex, history + 1);
    expect(c.lastMessage, startsWith('Escala do C de Hazen-Williams'));
    c.undo();
    await settle(tester);
    expect(c.project.params.hazenCScale, 1);
  });

  testWidgets('on a 390 × 844 phone every dialog opens and computes without exceptions', (tester) async {
    const phone = Size(390, 844);
    final c = await pumpShell(tester, size: phone);
    c.newProject();
    await settle(tester);
    final dialogs = [
      (showOnDemandDialog, 'od_run'),
      (showTariffDialog, 'tar_compute'),
      (showEnergyGroupingDialog, 'eg_compute'),
      (showWireRoutingDialog, ''),
      (showCriticalityDialog, 'crit_run'),
      (showCalibrationDialog, 'cal_run'),
      (showFertigationDialog, ''),
    ];
    // without a design: what is missing
    for (final (show, _) in dialogs) {
      show(ctxOf(tester), c);
      await settle(tester);
      expect(tester.takeException(), isNull, reason: '$show without a design');
      await close(tester);
    }
    // designed: every dialog with its results
    loadExampleAction(c, ExampleId.orchard);
    await settle(tester);
    c.runDesign();
    await until(tester, () => !c.busy && c.results != null);
    for (final (show, run) in dialogs) {
      show(ctxOf(tester), c);
      await settle(tester);
      expect(tester.takeException(), isNull, reason: '$show opened');
      if (run.isNotEmpty) {
        await tapVisible(tester, find.byKey(Key(run)));
        await settle(tester);
        expect(tester.takeException(), isNull, reason: '$show computed');
      }
      await close(tester);
    }
  });

  testWidgets('fertigation: travel to the valves and the farthest emitters, the plan and the venturi', (tester) async {
    final c = await designedOrchard(tester);
    showFertigationDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.text('Fertirrigação'), findsOneWidget);
    expect(find.text('Emissor mais distante: começa'), findsOneWidget);
    expect(find.text('Injeção'), findsOneWidget);
    expect(find.text('Taxa de injeção'), findsOneWidget);
    expect(find.text('INJETOR VENTURI'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^(Funciona|Não funciona)')), findsOneWidget);
    // from the pump outlet
    await tapVisible(tester, find.byKey(const Key('fert_injection')));
    final pump = c.project.entities.whereType<PumpEntity>().single;
    await tester.tap(find.text(c.entityName(pump.id)).last);
    await settle(tester);
    expect(find.text('Emissor mais distante: começa'), findsOneWidget);
    await close(tester);
  });
}
