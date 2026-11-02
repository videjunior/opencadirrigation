import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/ai/agent_tools_agent.dart';
import 'package:opencadirrigation/app/ai/ops_eng_common.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/dialogs/deliverables_dialogs.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/ai/claude_api.dart';
import 'package:opencadirrigation/core/ai/llm_formats.dart';
import 'package:opencadirrigation/core/io/xlsx.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/main.dart';

import 'support/fake_claude.dart';

/// The technical documents of Reports → Technical documents (1.6.0): the
/// five dialogs lay out on a phone, sideways, right to left and with the
/// text twice as big; their fields are one undo step with OK and are put
/// back with Cancel; the export writes the document with the value being
/// typed; and the assistant reaches all of it through its operations.
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
  Future<List<String>?> ask(List<AiQuestion> questions) async => [for (final _ in questions) ''];
  @override
  Future<PlanDecision?> reviewPlan(String plan) async => const PlanDecision.approved(AgentPermission.auto);
  @override
  void setNotes(String text) => notes = text;
  @override
  bool openTab(Project p) => false;
}

void main() {
  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<ProjectController> pumpShell(WidgetTester tester, Size size, {String lang = 'pt', double textScale = 1}) async {
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
    c.autosaveEnabled = false;
    loadExampleAction(c);
    await settle(tester);
    return c;
  }

  BuildContext ctxOf(WidgetTester tester) => tester.element(find.byType(Scaffold).first);

  final dialogs = <String, Future<void> Function(BuildContext, ProjectController)>{
    'permit': showPermitTableDialog,
    'memorial': showMemorialDialog,
    'om': showOmPlanDialog,
    'budget': showBudgetDialog,
    'lcc': showLifeCycleDialog,
  };

  for (final (name, size, lang, scale) in const [
    ('phone', Size(360, 640), 'pt', 1.0),
    ('phone sideways', Size(844, 390), 'pt', 1.0),
    ('right to left', Size(360, 640), 'ar', 1.0),
    ('text twice as big', Size(1280, 800), 'pt', 2.0),
  ]) {
    testWidgets('the document dialogs lay out: $name', (tester) async {
      final c = await pumpShell(tester, size, lang: lang, textScale: scale);
      expect(tester.takeException(), isNull, reason: 'the shell itself');
      for (final e in dialogs.entries) {
        e.value(ctxOf(tester), c);
        await settle(tester);
        expect(tester.takeException(), isNull, reason: '${e.key} at $name');
        expect(find.byKey(Key('prb_dialog_${e.key}')), findsOneWidget, reason: '${e.key} opened');
        Navigator.of(tester.element(find.byType(Dialog).last)).pop();
        await settle(tester);
        expect(tester.takeException(), isNull, reason: '${e.key} closing at $name');
      }
    });
  }

  testWidgets('the permit table: OK keeps the fields as one undo step; the export takes the value being typed', (tester) async {
    final c = await pumpShell(tester, const Size(1280, 900));
    final files = <String, Object>{};
    final keep = docFileSink;
    docFileSink = (c, name, mime, data) async => files[name] = data;
    addTearDown(() => docFileSink = keep);
    final supply = c.project.entities.whereType<WaterSupplyEntity>().first;
    final steps = c.historyIndex;
    showPermitTableDialog(ctxOf(tester), c);
    await settle(tester);
    final body = find.descendant(of: find.byKey(Key('prb_permit_body_${supply.id}')), matching: find.byType(TextField));
    await tester.ensureVisible(body);
    await tester.enterText(body, 'Rio Claro');
    final csv = find.byKey(const Key('prb_export_csv'));
    await tester.ensureVisible(csv);
    await tester.tap(csv);
    await settle(tester);
    expect(files.keys.single, endsWith('_${c.t('prb.file.permit')}.csv'));
    expect(files.values.single as String, contains('Rio Claro'));
    await tester.tap(find.byKey(const Key('prb_ok')));
    await settle(tester);
    expect(c.project.deliverables.permit.sources[supply.id]!.waterBody, 'Rio Claro');
    expect(c.historyIndex, steps + 1);
    expect(c.project.toJson()['deliverables'], isNotNull);
    c.undo();
    await settle(tester);
    expect(c.project.deliverables.permit.sources[supply.id]?.waterBody ?? '', '');
  });

  testWidgets('the memorial: Cancel puts the texts back; the Markdown export holds them', (tester) async {
    final c = await pumpShell(tester, const Size(1280, 900));
    final files = <String, Object>{};
    final keep = docFileSink;
    docFileSink = (c, name, mime, data) async => files[name] = data;
    addTearDown(() => docFileSink = keep);
    final steps = c.historyIndex;
    showMemorialDialog(ctxOf(tester), c);
    await settle(tester);
    final objective = find.descendant(of: find.byKey(const Key('prb_mem_objective')), matching: find.byType(TextField));
    await tester.enterText(objective, 'Projeto executivo para o edital.');
    final md = find.byKey(const Key('prb_export_md'));
    await tester.ensureVisible(md);
    await tester.tap(md);
    await settle(tester);
    expect(files.keys.single, endsWith('.md'));
    expect(files.values.single as String, contains('Projeto executivo para o edital.'));
    expect(files.values.single as String, startsWith('# ${c.t('prb.mem.title')}'));
    await tester.tap(find.byKey(const Key('prb_cancel')));
    await settle(tester);
    expect(c.project.deliverables.memorial.objective, '');
    expect(c.historyIndex, steps);
  });

  testWidgets('the budget: the BDI follows its parts, and the XLSX export has the compositions', (tester) async {
    final c = await pumpShell(tester, const Size(1280, 900));
    final files = <String, Object>{};
    final keep = docFileSink;
    docFileSink = (c, name, mime, data) async => files[name] = data;
    addTearDown(() => docFileSink = keep);
    showBudgetDialog(ctxOf(tester), c);
    await settle(tester);
    final iss = find.descendant(of: find.byKey(const Key('prb_bud_iss')), matching: find.byType(TextField));
    await tester.enterText(iss, '5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(c.project.deliverables.budget.issPct, 5);
    final xlsx = find.byKey(const Key('prb_export_xlsx'));
    await tester.ensureVisible(xlsx);
    await tester.tap(xlsx);
    await settle(tester);
    final sheets = XlsxReader.read(files.values.single as Uint8List);
    expect(sheets.map((s) => s.name), contains(c.t('prb.bud.compositions')));
    await tester.tap(find.byKey(const Key('prb_ok')));
    await settle(tester);
    expect(c.project.deliverables.budget.issPct, 5);
  });

  group('the operations of the assistant', () {
    late ProjectController c;
    late List<AgentTool> ops;
    final files = <String, Object>{};
    final saveFiles = engFileSink;

    setUp(() async {
      LocalProjectStore().clearAll();
      c = ProjectController()
        ..autosaveEnabled = false
        ..designRunner = InThreadDesignRunner();
      c.newProject();
      await c.setLanguage('en', persist: false);
      ops = AgentToolbox(c, host: _Host()).operations;
      files.clear();
      engFileSink = (c, name, mime, data) async => files[name] = data;
    });
    tearDown(() => engFileSink = saveFiles);

    /// One turn of the scripted model calling [calls] at once, then "done".
    Future<(String, AgentTurn)> turn(WidgetTester tester, List<(String, Map<String, dynamic>)> calls) async {
      final fake = FakeClaude([(_) => FakeReply.tools(calls), (_) => FakeReply.text('done')]);
      AgentTurn? out;
      await tester.runAsync(() async {
        out =
            await AgentLoop(
              api: AnthropicClient(apiKey: 'sk-ant-test', transport: fake.call, sleep: (_) async {}),
              tools: ops,
            ).run(
              model: AiModel.opus55,
              system: 's',
              history: const [],
              user: AnthropicFormat.user([AiTextPart('go')]),
              permission: AgentPermission.auto,
              cancel: AiCancel(),
              events: AgentEvents(approve: (call) async => Approval.apply),
            );
      });
      return (fake.lastUserText(1), out!);
    }

    void allDone(AgentTurn t) {
      for (final call in t.calls) {
        expect(call.state, ToolCallState.done, reason: '${call.name}: ${call.result}');
      }
    }

    testWidgets('read, set and export every document', (tester) async {
      loadExampleAction(c, ExampleId.orchard);
      await tester.runAsync(() => c.runDesign());
      expect(c.results, isNotNull, reason: c.lastMessage);
      final supply = c.project.entities.whereType<WaterSupplyEntity>().first;
      final (text, t) = await turn(tester, [
        ('permit_table', {}),
        ('document_text', {'document': 'memorial', 'max_chars': 5000}),
        ('life_cycle_cost', {}),
      ]);
      allDone(t);
      expect(text, contains('Monitoring unit other'));
      expect(text, contains('Source ${supply.id}'));
      expect(text, contains('m³/month'));
      expect(text, contains('# ${c.t('prb.mem.title')}'));
      expect(text, contains('Lowest LCC'));
      final steps = c.historyIndex;
      final (_, t2) = await turn(tester, [
        ('set_permit_info', {'source': supply.id, 'water_body': 'Rio Claro', 'kind': 'groundwater', 'fixed_hours_per_day': 10, 'federal_floor': true}),
        ('set_memorial_texts', {'objective': 'Objective of the test.'}),
        ('set_om_settings', {'spares_pct': 5, 'chlorine_product_pct': 12}),
        (
          'set_budget_settings',
          {
            'iss_pct': 5,
            'hourly_costs': {'helper': 30},
            'period_days': 5,
          },
        ),
        (
          'set_life_cycle_settings',
          {
            'years': 15,
            'water_price': 0.1,
            'life': {'bom.tapes': 4},
          },
        ),
      ]);
      allDone(t2);
      final d = c.project.deliverables;
      expect(d.permit.sources[supply.id]!.waterBody, 'Rio Claro');
      expect(d.permit.sources[supply.id]!.kind, 'groundwater');
      expect(d.permit.fixedHoursPerDay, 10);
      expect(d.permit.federalFloor, isTrue);
      expect(d.memorial.objective, 'Objective of the test.');
      expect(d.om.sparesPct, 5);
      expect(d.om.chlorineProductPct, 12);
      expect(d.budget.issPct, 5);
      expect(d.budget.rates['helper'], 30);
      expect(d.budget.periodDays, 5);
      expect(d.lifeCycle.years, 15);
      expect(d.lifeCycle.waterPrice, 0.1);
      expect(d.lifeCycle.life['bom.tapes'], 4);
      expect(c.historyIndex, greaterThan(steps));
      expect(c.results, isNotNull, reason: 'the settings of the documents keep the results');
      // the exports: always confirmed, written through the file sink
      final (_, t3) = await turn(tester, [
        for (final k in techDocumentKeys) ('export_document', {'document': k, 'format': 'csv'}),
        ('export_document', {'document': 'memorial', 'format': 'pdf'}),
      ]);
      allDone(t3);
      expect(files.keys.where((f) => f.endsWith('.csv')), hasLength(techDocumentKeys.length));
      expect(files.keys.where((f) => f.endsWith('.pdf')), hasLength(1));
      final permit = files.entries.firstWhere((e) => e.key.contains(c.t('prb.file.permit'))).value as String;
      expect(permit, contains('Rio Claro'));
      // an unknown source and a bad document say what to do
      final (bad, t4) = await turn(tester, [
        ('set_permit_info', {'source': 'nowhere', 'water_body': 'x'}),
        ('permit_table', {'source': 'nowhere'}),
      ]);
      expect(t4.calls.every((x) => x.state == ToolCallState.failed), isTrue);
      expect(bad, contains('No water supply "nowhere"'));
    });
  });
}
