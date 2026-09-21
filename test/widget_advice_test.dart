import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/history_panel.dart';
import 'package:opencadirrigation/app/widgets/reports_panel.dart';
import 'package:opencadirrigation/core/design/advisor.dart';
import 'package:opencadirrigation/core/design/auto_fix.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';
import 'package:opencadirrigation/main.dart';

/// The design assistant in the app: the Messages tab explains every problem
/// and fixes it in one click, "fix automatically", the optimisation and the
/// jump to the Messages tab after a design with errors.
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
    final c = (tester.state(find.byType(AppShell)) as dynamic).c as ProjectController;
    c
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.snap.enabled = false;
    return c;
  }

  /// Pumps until [f] completes (designs run in-thread between frames).
  Future<T> drive<T>(WidgetTester tester, Future<T> f) async {
    var done = false;
    late T value;
    f.then((v) {
      value = v;
      done = true;
    });
    for (var i = 0; i < 3000 && !done; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(done, isTrue, reason: 'the assistant did not finish');
    await settle(tester);
    return value;
  }

  void openMessages(ProjectController c) {
    c.showReports = true;
    c.reportTab = ProjectController.messagesReportTab;
    c.refresh();
  }

  test('the Messages tab index matches the report tabs', () {
    expect(reportTabKeys.indexOf('reports.messages'), ProjectController.messagesReportTab);
  });

  testWidgets('the Messages tab explains a problem and its button fixes it', (tester) async {
    final c = await pumpShell(tester);
    final pump = c.project.entities.whereType<PumpEntity>().first;
    c.select([pump.id]);
    c.moveSelected(const Pt(0, 0.8));
    openMessages(c);
    await settle(tester);
    expect(find.textContaining('Item desconectado da rede'), findsWidgets);
    expect(find.textContaining('Por quê'), findsWidgets);
    expect(find.textContaining('Como resolver'), findsWidgets);
    expect(find.text('Mensagens (1)'), findsOneWidget);
    final fix = find.textContaining('Conectar ao mais próximo');
    expect(fix, findsOneWidget);
    await tester.ensureVisible(fix);
    await settle(tester);
    await tester.tap(fix);
    await settle(tester);
    expect(c.advice.where((a) => a.code == 'unconnected'), isEmpty);
    expect(c.lastMessage, contains('Corrigido'));
    expect(HistoryPanel.labelText(c, c.historyEntries.last.label), contains('Correção'));
    expect(find.textContaining('Nenhum problema'), findsOneWidget);
    // one undo step brings the problem back
    c.undo();
    await settle(tester);
    expect(c.advice.where((a) => a.code == 'unconnected'), isNotEmpty);
  });

  testWidgets('a design that ends with errors opens the Messages tab', (tester) async {
    final c = await pumpShell(tester);
    final line = c.project.entities.whereType<SpraylineEntity>().first;
    c.mutate(() => line.headM = 80);
    await drive(tester, c.runDesign());
    expect(c.results, isNotNull);
    expect(c.reportTab, ProjectController.messagesReportTab);
    expect(c.lastMessage, contains('erro'));
    expect(find.textContaining('Pressão do emissor fora da faixa do bocal'), findsWidgets);
    expect(find.textContaining('Usar a pressão nominal do emissor'), findsOneWidget);
  });

  testWidgets('fix automatically corrects several mistakes in one undo step', (tester) async {
    final c = await pumpShell(tester);
    final undoBefore = c.historyEntries.length;
    c.project.params.maxZoneVelocity = 0;
    c.mutate(() => c.project.entities.whereType<WaterSupplyEntity>().first.waterLevelOffsetM = -12);
    final pump = c.project.entities.whereType<PumpEntity>().first;
    c.select([pump.id]);
    c.moveSelected(const Pt(0, 0.6));
    openMessages(c);
    await settle(tester);
    expect(tester.widget<FilledButton>(find.byKey(const Key('advice_fix_all'))).onPressed, isNotNull);
    final report = await drive(tester, c.autoFixAll());
    expect(report, isNotNull);
    expect(report!.errors, 0, reason: report.remaining.map((a) => a.code).join(', '));
    expect(report.applied.length, greaterThanOrEqualTo(3));
    expect(c.project.params.maxZoneVelocity, greaterThan(0));
    expect(c.historyEntries.length, undoBefore + 3); // two edits + the automatic correction
    expect(HistoryPanel.labelText(c, c.historyEntries.last.label), 'Correção automática');
    expect(c.assistantProgress, isEmpty);
  });

  testWidgets('the optimisation keeps or restores the design and the dialogs open from the menu', (tester) async {
    final c = await pumpShell(tester);
    await drive(tester, c.runDesign());
    final report = await drive(tester, c.optimizeDesign(const OptimizeOptions()));
    expect(report, isNotNull);
    expect(report!.after.errors, 0);
    expect(report.after.annualTotal, lessThanOrEqualTo(report.before.annualTotal * 1.02));
    // menu entries
    await tester.tap(find.text('Projeto').first);
    await settle(tester, 2);
    expect(find.byKey(const Key('menu_autofix')), findsOneWidget);
    await tester.tap(find.byKey(const Key('menu_optimize')));
    await settle(tester);
    expect(find.byKey(const Key('opt_run')), findsOneWidget);
    expect(find.textContaining('menor custo anual'), findsWidgets);
    await tester.tap(find.text('Cancelar'));
    await settle(tester);
    // design check dialog shows the same assistant
    await tester.tap(find.text('Projeto').first);
    await settle(tester, 2);
    await tester.tap(find.byKey(const Key('menu_check')));
    await settle(tester);
    expect(find.byKey(const Key('check_list')), findsOneWidget);
    expect(find.byKey(const Key('advice_fix_all')), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await settle(tester);
  });

  testWidgets('without a supply only the missing supply is reported, with a one-click fix', (tester) async {
    final c = await pumpShell(tester);
    final supply = c.project.entities.whereType<WaterSupplyEntity>().first;
    c.select([supply.id]);
    c.deleteSelected();
    final advice = c.advice;
    expect(advice.first.code, 'no_supply');
    expect(advice.first.fixes, [FixKind.addSupply]);
    expect(advice.where((a) => a.code == 'unconnected'), isEmpty);
    openMessages(c);
    await settle(tester);
    await tester.ensureVisible(find.textContaining('Colocar a fonte na ponta livre'));
    await settle(tester);
    await tester.tap(find.textContaining('Colocar a fonte na ponta livre'));
    await settle(tester);
    expect(c.project.entities.whereType<WaterSupplyEntity>(), hasLength(1));
    expect(c.advice.where((a) => a.level == AdviceLevel.error), isEmpty);
  });
}
