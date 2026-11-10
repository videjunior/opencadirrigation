import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/ai/agent_tools_agent.dart';
import 'package:opencadirrigation/app/ai/op_parts/scr.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/tutorial/tutorial.dart';
import 'package:opencadirrigation/app/widgets/dialogs/scorecard_dialog.dart';
import 'package:opencadirrigation/app/widgets/scorecard_radar.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/design/designer.dart';
import 'package:opencadirrigation/core/design/scorecard.dart';
import 'package:opencadirrigation/core/model/catalog.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/project.dart';
import 'package:opencadirrigation/main.dart';

/// Design → Design scorecard (1.7.0 SCR): the dialog from the desktop menu
/// and the phone menu, in the dark and the light theme, on a phone, with
/// an empty project and without results; the comparison with a remembered
/// score; the ageing test; and the assistant's operation that reads it and
/// tells what a change did.
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
  tearDown(() {
    ScorecardMemory.clear();
    forgetScorecardCalls();
    setThemeMode(CadThemeMode.dark);
    removePref('theme');
  });

  Future<void> settle(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<ProjectController> pumpShell(WidgetTester tester, {Size size = const Size(1600, 1000), String lang = 'en'}) async {
    TutorialController.markDone();
    setPref('lang', lang);
    LocalProjectStore().clearAll();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const IrrigationCadApp(autoTutorial: false, offerRecovery: false, askAi: false));
    await settle(tester);
    final c = (tester.state(find.byType(AppShell)) as dynamic).c as ProjectController;
    c
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    return c;
  }

  Future<void> designOrchard(WidgetTester tester, ProjectController c) async {
    loadExampleAction(c, ExampleId.orchard);
    await settle(tester);
    c.results = Designer(c.project, label: c.t.call).designAll();
    c.refresh();
    await settle(tester, 2);
  }

  BuildContext ctxOf(WidgetTester tester) => tester.element(find.byType(Scaffold).first);

  testWidgets('from the Design menu: grade, radar, improvements, the table and the remembered score', (tester) async {
    final c = await pumpShell(tester);
    await designOrchard(tester, c);
    final t = c.t;
    await tester.tap(find.text(t('menu.design')).first);
    await settle(tester, 2);
    await tester.tap(find.byKey(const Key('menu_scorecard')));
    await settle(tester);
    expect(tester.takeException(), isNull);
    final s = projectScorecard(c)!;
    expect(find.byKey(const Key('scr_grade')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('scr_grade')), matching: find.text(s.grade!)), findsOneWidget);
    expect(find.byType(ScorecardRadar), findsOneWidget);
    expect(find.byKey(const Key('scr_table')), findsOneWidget);
    // the first improvement is the one with the most points, with its tool
    final first = s.improvements.first.$1;
    expect(find.byKey(Key('scr_imp_${first.key}')), findsOneWidget);
    expect(find.byKey(Key('scr_open_${first.key}')), findsOneWidget);
    for (final cat in ScoreCategory.values) {
      expect(find.byKey(Key('scr_cat_${cat.name}')), findsOneWidget, reason: cat.name);
    }
    // remember the score, make the design worse, compare
    await tester.tap(find.byKey(const Key('scr_remember')));
    await settle(tester, 1);
    expect(find.byKey(const Key('scr_compare')), findsOneWidget);
    final small = c.project.catalog.pipesFor(PipeUsage.zone).reduce((a, b) => a.innerDiameterMm < b.innerDiameterMm ? a : b);
    for (final e in c.project.entities) {
      if (e is PipeEntity && e.scope == HydraulicScope.zone) {
        e
          ..pipeSpecId = small.id
          ..computerSized = false;
      }
    }
    c.results = Designer(c.project, label: t.call).analyzeAll();
    c.refresh();
    await settle(tester, 2);
    await tester.tap(find.byKey(const Key('scr_compare')));
    await settle(tester, 2);
    await tester.tap(find.textContaining(t('scr.remembered', {'d': ''}).replaceAll('()', '').trim()).last);
    await settle(tester, 2);
    expect(tester.takeException(), isNull);
    final worse = projectScorecard(c)!;
    expect(worse.overall!, lessThan(s.overall!));
    // the overall score shows the change against the remembered one
    final overall = tester.widget<Text>(find.byKey(const Key('scr_overall'))).data!;
    expect(overall, contains('−'));
    // the method is there
    await tester.ensureVisible(find.byKey(const Key('scr_method')));
    await tester.tap(find.byKey(const Key('scr_method')));
    await settle(tester, 2);
    expect(find.text(t('scr.method')), findsOneWidget);
    await tester.tap(find.byKey(const Key('scr_close')));
    await settle(tester);
    expect(find.byKey(const Key('scr_table')), findsNothing);
  });

  testWidgets('the ageing test from the dialog assesses the robustness over the life', (tester) async {
    final c = await pumpShell(tester);
    await designOrchard(tester, c);
    showScorecardDialog(ctxOf(tester), c);
    await settle(tester);
    expect(projectScorecard(c)!.indicator('agedEu')!.assessed, isFalse);
    await tester.tap(find.byKey(const Key('scr_ageing')));
    await tester.runAsync(() async {
      for (var i = 0; i < 200 && ScorecardMemory.lifeOf(c) == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await settle(tester);
    expect(ScorecardMemory.lifeOf(c), hasLength(4));
    expect(projectScorecard(c)!.indicator('agedEu')!.assessed, isTrue);
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byType(Dialog).last)).pop();
    await settle(tester);
  });

  for (final (name, size, light) in const [('phone, dark', Size(360, 740), false), ('phone, light', Size(390, 844), true), ('desktop, light', Size(1280, 800), true)]) {
    testWidgets('the dialog lays out: $name', (tester) async {
      final c = await pumpShell(tester, size: size, lang: 'pt');
      if (light) setThemeMode(CadThemeMode.light);
      await designOrchard(tester, c);
      showScorecardDialog(ctxOf(tester), c);
      await settle(tester);
      expect(tester.takeException(), isNull, reason: name);
      expect(find.byType(ScorecardRadar), findsOneWidget);
      // the table scrolls into view and the dialog closes
      await tester.ensureVisible(find.byKey(const Key('scr_table')));
      await settle(tester, 1);
      expect(tester.takeException(), isNull, reason: name);
      await tester.ensureVisible(find.byKey(const Key('scr_close')));
      await tester.tap(find.byKey(const Key('scr_close')));
      await settle(tester);
    });
  }

  testWidgets('the phone menu opens it; without results and with an empty project it says what to do', (tester) async {
    final c = await pumpShell(tester, size: const Size(390, 844));
    c.newProject();
    await settle(tester);
    await tester.pump(const Duration(seconds: 4));
    await settle(tester, 2);
    await tester.tap(find.byKey(const Key('mobile_menu')));
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('mobile_menu_design')));
    await settle(tester, 1);
    await tester.tap(find.byKey(const Key('mobile_menu_design')));
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('mobile_menu_scorecard')));
    await settle(tester, 1);
    await tester.tap(find.byKey(const Key('mobile_menu_scorecard')));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('scr_need_design')), findsOneWidget);
    // an empty project cannot be designed: the button is off
    expect(tester.widget<FilledButton>(find.byKey(const Key('scr_design'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('scr_close')));
    await settle(tester);
    // a project not designed yet: the button designs it and the scorecard appears
    loadExampleAction(c, ExampleId.garden);
    await settle(tester);
    c.results = null;
    c.refresh();
    showScorecardDialog(ctxOf(tester), c);
    await settle(tester);
    expect(find.byKey(const Key('scr_need_design')), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('scr_design')));
      for (var i = 0; i < 300 && (c.results == null || c.busy); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await settle(tester);
    expect(c.results, isNotNull);
    expect(find.byKey(const Key('scr_grade')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('the assistant', () {
    late ProjectController c;
    setUp(() async {
      LocalProjectStore().clearAll();
      c = ProjectController()
        ..autosaveEnabled = false
        ..designRunner = InThreadDesignRunner();
      c.newProject();
      await c.setLanguage('en', persist: false);
    });

    Future<String> call(WidgetTester tester, Map<String, dynamic> input) async {
      final op = AgentToolbox(c, host: _Host()).operations.firstWhere((o) => o.name == 'design_scorecard');
      Object? error;
      ToolOutput? out;
      await tester.runAsync(() async {
        try {
          out = await op.run(input);
        } catch (e) {
          error = e;
        }
      });
      if (error != null) throw error!;
      return out!.text;
    }

    testWidgets('design_scorecard reads it, tells what a change did and compares with an alternative', (tester) async {
      // no results: it asks for a design
      await expectLater(call(tester, {}), throwsA(isA<ToolInputError>()));
      loadExampleAction(c, ExampleId.orchard);
      c.results = Designer(c.project, label: c.t.call).designAll();
      final s = projectScorecard(c)!;
      final text = await call(tester, {});
      expect(text, contains('Design scorecard: overall ${s.overall!.toStringAsFixed(1)}/100, grade ${s.grade}'));
      expect(text, contains('energy/headUse'));
      expect(text, contains('Improve first'));
      expect(text, contains('Operation: rank_pumps'));
      expect(text, contains('robustness/agedEu (${c.t('scr.na.life')})'));
      expect(text, isNot(contains('Compared with')));
      // a change, then the same call: what it did
      c.project.params.maxZoneVariationPct = 5;
      c.results = Designer(c.project, label: c.t.call).designAll();
      final again = await call(tester, {});
      expect(again, contains('Compared with the previous design_scorecard call'));
      expect(again, contains('overall ${s.overall!.toStringAsFixed(1)} → '));
      // an alternative saved with its results
      c.saveScenario('First');
      final alt = await call(tester, {'compare_with': 'First'});
      expect(alt, contains('Compared with the alternative "First": overall'));
      await expectLater(call(tester, {'compare_with': 'nope'}), throwsA(isA<ToolInputError>()));
      // the ageing test assesses the robustness over the life
      final aged = await call(tester, {'run_ageing': true});
      expect(aged, isNot(contains('robustness/agedEu (')));
      expect(projectScorecard(c)!.indicator('agedEu')!.assessed, isTrue);
      // the report table reads the same
      expect(c.reportTables().firstWhere((tb) => tb.key == 'scorecard').rows, isNotEmpty);
    });
  });
}
