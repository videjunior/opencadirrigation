import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/ai/agent_tools_agent.dart';
import 'package:opencadirrigation/app/ai/ai_assistant.dart';
import 'package:opencadirrigation/app/ai/manual_example.dart';
import 'package:opencadirrigation/app/ai/view_snapshot.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/widgets/ai/ai_panel.dart';
import 'package:opencadirrigation/app/widgets/dialogs/ai_assistant_dialog.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

import 'support/fake_claude.dart';
import 'support/fake_openai.dart';

/// The assistant as a design agent, against scripted models of both
/// providers (no network): the two companies with their own keys and a new
/// conversation on a switch, a whole small project built end to end through
/// questions, a plan and the real tools, plan mode refusing changes until
/// approval, the to-do list, messages typed while it works, rewind, the
/// spending cap, compaction, quick commands, pictures for the model, the
/// transcript, and the docked panel on a desktop and a phone.
void main() {
  const anthropicKey = 'sk-ant-api03-TEST-ANTHROPIC-0000';
  const openaiKey = 'sk-proj-TEST-OPENAI-KEY-0000';

  late ProjectController c;
  AiAssistant ai() => AiAssistant.of(c);

  setUp(() async {
    LocalProjectStore().clearAll();
    for (final k in [
      'ai.model',
      'ai.effort',
      'ai.mode',
      'ai.steps',
      'ai.parts',
      'ai.cap',
      'ai.compact',
      'ai.showChanges',
      'ai.instructions',
      AiAssistant.keyPref,
      AiAssistant.keyPrefOf(AiProvider.openai),
    ]) {
      removePref(k);
    }
    AiAssistant.clearSessionKey();
    AiHttpClient.declined.clear();
    c = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
    await c.setLanguage('en', persist: false);
    AiAssistant.debugSleep = (_) async {};
    AiAssistant.debugBrowser = true;
    setPref(AiAssistant.keyPref, anthropicKey);
  });
  tearDown(() {
    AiAssistant.debugTransport = null;
    AiAssistant.debugSleep = null;
    AiAssistant.debugBrowser = null;
    AiAssistant.debugSnapshots = null;
    AiAssistant.clearSessionKey();
    AiAssistant.panelOpen.value = false;
    AiAssistant.dockable = false;
    removePref(AiAssistant.keyPref);
    removePref(AiAssistant.keyPrefOf(AiProvider.openai));
  });

  Future<void> open(WidgetTester tester, {Size size = const Size(1280, 900)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCadTheme(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(key: const Key('open'), onPressed: () => showAiAssistantDialog(ctx, c), child: const Text('open')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Pumps until [done] holds; [answer] handles the cards (approvals,
  /// questions, plans) as they come.
  Future<void> drive(WidgetTester tester, bool Function() done, {Future<void> Function()? answer, int max = 4000}) async {
    for (var i = 0; i < max && !done(); i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (answer != null) await answer();
    }
    expect(done(), isTrue, reason: 'the assistant did not finish');
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('ai_input')), text);
    await tester.tap(find.byKey(const Key('ai_send')));
    await tester.pump();
  }

  /// Requests to each API go to their own fake.
  AiTransport route(FakeClaude claude, FakeOpenAi openai) =>
      (r, cancel) => r.url.host == 'api.openai.com' ? openai.call(r, cancel) : claude.call(r, cancel);

  testWidgets('GPT through the Responses API with the OpenAI key; switching company starts anew; neither key reaches the other company', (tester) async {
    final claude = FakeClaude([(_) => FakeReply.text('Hello from Claude.')]);
    final openai = FakeOpenAi([(_) => OpenAiReply.text('Hello from GPT.')]);
    AiAssistant.debugTransport = route(claude, openai);
    ai().saveKey(openaiKey, provider: AiProvider.openai);
    ai().model = AiModel.gpt6Astra;
    await open(tester);
    await send(tester, 'Hello?');
    await drive(tester, () => !ai().busy && openai.calls == 1);
    expect(find.textContaining('Hello from GPT.'), findsOneWidget);
    expect(claude.calls, 0);
    final req = openai.requests.single;
    expect(req.headers['authorization'], 'Bearer $openaiKey');
    expect(req.headers.containsKey('x-api-key'), isFalse);
    expect('${req.headers}${req.body}'.contains(anthropicKey), isFalse, reason: 'the Anthropic key never goes to OpenAI');
    expect(openai.bodies.single['model'], 'gpt-6-astra');
    // another company: a new conversation, said so
    ai().model = AiModel.opus55;
    await tester.pump();
    expect(ai().items.single.kind, AiItemKind.notice);
    expect(find.textContaining('New conversation with Claude Opus 5.5'), findsOneWidget);
    await send(tester, 'Hello, Claude?');
    await drive(tester, () => !ai().busy && claude.calls == 1);
    final r2 = claude.requests.single;
    expect(r2.headers['x-api-key'], anthropicKey);
    expect('${r2.headers}${r2.body}'.contains(openaiKey), isFalse, reason: 'the OpenAI key never goes to Anthropic');
    expect((claude.bodies.single['messages'] as List).length, 1, reason: 'nothing of the GPT conversation goes to Anthropic');
  });

  testWidgets('a Claude model takes over the conversation of another Claude model', (tester) async {
    final claude = FakeClaude([(_) => FakeReply.text('First.'), (_) => FakeReply.text('Second.', model: 'claude-sonnet-5-5')]);
    AiAssistant.debugTransport = claude.call;
    await open(tester);
    await send(tester, 'One');
    await drive(tester, () => !ai().busy && claude.calls == 1);
    ai().model = AiModel.sonnet55;
    await tester.pump();
    expect(ai().items.where((i) => i.kind == AiItemKind.notice), isEmpty);
    await send(tester, 'Two');
    await drive(tester, () => !ai().busy && claude.calls == 2);
    expect((claude.bodies[1]['messages'] as List).length, 3, reason: 'the conversation goes on');
    expect(claude.bodies[1]['model'], 'claude-sonnet-5-5');
  });

  testWidgets('a whole small project: questions, a plan, the drawing, the design, the check, the fixes and the report, with the to-do list', (tester) async {
    ai().permission = AgentPermission.plan;
    final steps = [for (final s in workedExample) (s.tool, Map<String, dynamic>.from(jsonDecode(jsonEncode(s.input)) as Map))];
    final claude = FakeClaude([
      (_) => FakeReply.tools([
        (
          'update_todo',
          {
            'items': [
              {'content': 'Ask for the water source', 'status': 'in_progress'},
              {'content': 'Plan the block', 'status': 'pending'},
              {'content': 'Draw, design and check', 'status': 'pending'},
            ],
          },
        ),
        (
          'ask_user',
          {
            'questions': [
              {
                'question': 'Where does the water come from?',
                'header': 'Source',
                'options': [
                  {'label': 'Well', 'description': 'water about 4 m down'},
                  {'label': 'Reservoir'},
                ],
              },
            ],
          },
        ),
      ], text: 'Let me ask first.'),
      // a change before the plan is approved is refused
      (_) => FakeReply.tools([
        steps.first,
        ('present_plan', {'plan': '# Plan\n- A drip block of tape, fed from the well\n- Design, check and report'}),
      ]),
      for (final s in steps) (_) => FakeReply.tools([s]),
      (_) => FakeReply.tools([('auto_fix', {}), ('get_design_messages', {})]),
      (_) => FakeReply.tools([
        ('get_report_table', {'table': 'zones'}),
        ('get_report_table', {'table': 'bom'}),
        (
          'update_todo',
          {
            'items': [
              {'content': 'Ask for the water source', 'status': 'done'},
              {'content': 'Plan the block', 'status': 'done'},
              {'content': 'Draw, design and check', 'status': 'done'},
            ],
          },
        ),
      ]),
      (_) => FakeReply.text('The block is designed and checked; the materials are in the report.'),
    ]);
    AiAssistant.debugTransport = claude.call;
    await open(tester);
    await send(tester, 'Design drip irrigation for a 50 × 30 m tomato field from the well.');
    var answered = false, approved = false;
    await drive(
      tester,
      () => !ai().busy && claude.calls == steps.length + 5,
      answer: () async {
        if (!answered && find.byKey(const Key('ai_question')).evaluate().isNotEmpty) {
          answered = true;
          expect(find.byKey(const Key('ai_todos')), findsOneWidget, reason: 'the to-do list shows above the conversation');
          await tester.tap(find.byKey(const Key('ai_question_opt_0_0')));
          await tester.pump();
          await tester.tap(find.byKey(const Key('ai_question_send')));
        }
        if (!approved && find.byKey(const Key('ai_plan')).evaluate().isNotEmpty) {
          approved = true;
          expect(c.project.entities, isEmpty, reason: 'nothing changed before the plan was approved');
          await tester.tap(find.byKey(const Key('ai_plan_approve_auto')));
        }
      },
    );
    expect(answered && approved, isTrue);
    expect(claude.lastUserText(1), contains('Where does the water come from? → Well'));
    expect(claude.lastUserText(2), contains('plan mode'), reason: 'the change before the approval was refused');
    expect(claude.lastUserText(2), contains('approved the plan'));
    expect(ai().permission, AgentPermission.auto);
    final p = c.project;
    expect(p.entities.whereType<WaterSupplyEntity>(), hasLength(1));
    expect(p.entities.whereType<PipeEntity>().where((e) => e.scope.name == 'mainline'), isNotEmpty);
    expect(p.entities.whereType<ControlValveEntity>(), isNotEmpty);
    expect(p.entities.whereType<TapeEntity>(), isNotEmpty);
    expect(c.results, isNotNull);
    expect(claude.lastUserText(steps.length + 4), contains('Block 1'), reason: 'the zones table went back to the model');
    expect(ai().todos.every((x) => x.status == TodoStatus.done), isTrue);
    // the whole task is one undo step, and its undo leaves nothing
    expect(c.historyEntries.where((e) => e.label == 'hist.ai'), hasLength(1));
    expect(find.textContaining('the materials are in the report'), findsOneWidget);
  });

  testWidgets('messages typed while it works reach it with the next results', (tester) async {
    final gate = Completer<void>();
    final claude = FakeClaude([
      (_) => FakeReply.tools([('get_parameters', {})]),
      (_) => FakeReply.text('Using 25 mm laterals.'),
    ]);
    AiAssistant.debugTransport = (r, cancel) async {
      if (claude.calls == 0) await gate.future;
      return claude.call(r, cancel);
    };
    await open(tester);
    await send(tester, 'Size the laterals.');
    expect(ai().busy, isTrue);
    await tester.enterText(find.byKey(const Key('ai_input')), 'Use 25 mm pipe for the laterals.');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.byKey(const Key('ai_queued_0')), findsOneWidget, reason: 'queued for the next step');
    gate.complete();
    await drive(tester, () => !ai().busy && claude.calls == 2);
    expect(claude.lastUserText(1), contains('Use 25 mm pipe for the laterals.'));
    expect(claude.lastUserText(1), contains('[Message from the user'));
    expect(find.text(c.t('ai.steered')), findsOneWidget);
    expect(ai().queued, isEmpty);
  });

  testWidgets('rewind takes the project and the conversation back to before a message', (tester) async {
    ai().permission = AgentPermission.auto;
    Map<String, dynamic> area(String name, double x) => {
      'entities': [
        {
          'type': 'area',
          'name': name,
          'pts': [
            [x, 0],
            [x + 10, 0],
            [x + 10, 10],
          ],
        },
      ],
    };
    final claude = FakeClaude([
      (_) => FakeReply.tools([('create_entities', area('A', 0))]),
      (_) => FakeReply.text('A drawn.'),
      (_) => FakeReply.tools([('create_entities', area('B', 20))]),
      (_) => FakeReply.text('B drawn.'),
    ]);
    AiAssistant.debugTransport = claude.call;
    await open(tester);
    await send(tester, 'Draw A');
    await drive(tester, () => !ai().busy && claude.calls == 2);
    await send(tester, 'Draw B');
    await drive(tester, () => !ai().busy && claude.calls == 4);
    expect(c.project.entities, hasLength(2));
    final second = ai().items.where((i) => i.kind == AiItemKind.user).last;
    final index = ai().items.indexOf(second);
    await tester.ensureVisible(find.byKey(Key('ai_rewind_$index')));
    await tester.pump();
    await tester.tap(find.byKey(Key('ai_rewind_$index')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai_rewind_ok')));
    await tester.pump();
    await tester.pump();
    expect(c.project.entities.map((e) => e.name), ['A'], reason: 'the project as it was before "Draw B"');
    expect(ai().historyLength, 4, reason: 'the conversation up to that message');
    expect((tester.widget(find.byKey(const Key('ai_input'))) as TextField).controller!.text, 'Draw B');
    // rewinding to the first message empties both
    ai().rewind(ai().items.firstWhere((i) => i.kind == AiItemKind.user));
    await tester.pump();
    expect(c.project.entities, isEmpty);
    expect(ai().historyLength, 0);
    c.redo();
    expect(c.project.entities, hasLength(1), reason: 'redo brings the project forward again');
  });

  testWidgets('the spending cap stops a long task, and Continue goes on', (tester) async {
    setPref('ai.cap', '0.01');
    ai().permission = AgentPermission.auto;
    final claude = FakeClaude([
      for (var k = 0; k < 6; k++) (_) => FakeReply.tools([('get_parameters', {})]),
      (_) => FakeReply.text('Finished.'),
    ]);
    AiAssistant.debugTransport = claude.call;
    await open(tester);
    await send(tester, 'Check every parameter.');
    await drive(tester, () => !ai().busy);
    expect(claude.calls, 2, reason: 'about US\$ 0.006 a request at Claude Opus 5.5 list prices');
    expect(find.textContaining('spending cap'), findsOneWidget);
    expect(((claude.bodies.first['output_config'] as Map)['task_budget'] as Map)['total'], 20000, reason: 'the cap as a task budget (at least 20 000 tokens)');
    await tester.tap(find.byKey(const Key('ai_continue')));
    await tester.pump();
    await drive(tester, () => !ai().busy && claude.calls >= 3);
    expect(claude.lastUserText(2), contains(c.t('ai.continue.prompt')));
  });

  testWidgets('quick commands: the menu, /cost and /plan here, /check as a prompt', (tester) async {
    final claude = FakeClaude([(_) => FakeReply.text('Checked.')]);
    AiAssistant.debugTransport = claude.call;
    await open(tester);
    await tester.enterText(find.byKey(const Key('ai_input')), '/');
    await tester.pump();
    expect(find.byKey(const Key('ai_cmd_menu')), findsOneWidget);
    expect(find.byKey(const Key('ai_cmd_design')), findsOneWidget);
    await send(tester, '/cost');
    expect(claude.calls, 0);
    expect(find.byKey(const Key('ai_notice')), findsOneWidget);
    await send(tester, '/plan');
    expect(ai().permission, AgentPermission.plan);
    ai().permission = AgentPermission.ask;
    await send(tester, '/check the mainline too');
    await drive(tester, () => !ai().busy && claude.calls == 1);
    expect(claude.lastUserText(0), contains('design check'));
    expect(claude.lastUserText(0), contains('the mainline too'));
  });

  testWidgets('a compaction on the server is said in the conversation', (tester) async {
    final claude = FakeClaude([(_) => FakeReply.text('Still here.', compaction: 'Summary.')]);
    AiAssistant.debugTransport = claude.call;
    await open(tester);
    await send(tester, 'Go on');
    await drive(tester, () => !ai().busy && claude.calls == 1);
    expect(find.text(c.t('ai.compacted')), findsOneWidget);
    expect((claude.bodies.single['context_management'] as Map)['edits'], isNotEmpty, reason: 'on by default');
  });

  testWidgets('pictures for the model: the user attaches the view, the drawing after the changes goes with the results', (tester) async {
    AiAssistant.debugSnapshots = const CanvasSnapshots();
    ai()
      ..permission = AgentPermission.auto
      ..showChanges = true;
    final claude = FakeClaude([
      (_) => FakeReply.tools([
        (
          'create_entities',
          {
            'entities': [
              {
                'type': 'area',
                'name': 'Lawn',
                'pts': [
                  [0, 0],
                  [40, 0],
                  [40, 30],
                  [0, 30],
                ],
              },
            ],
          },
        ),
      ]),
      (_) => FakeReply.text('Drawn.'),
    ]);
    AiAssistant.debugTransport = claude.call;
    c.addEntity(TextEntity(id: c.project.newId(), position: const Pt(5, 5), text: 'Road', height: 1));
    await tester.runAsync(() async {
      expect(await ai().attachView(), isTrue);
      final a = ai().attachments.single;
      expect(a.isImage, isTrue);
      expect(a.note, contains('y = maxY'), reason: 'the pixel ↔ world mapping goes with the picture');
      await ai().send('Draw the lawn along the road in this picture.');
    });
    expect(claude.calls, 2);
    final first = jsonEncode((claude.bodies[0]['messages'] as List).last);
    expect(first, contains('"type":"image"'), reason: 'the user\'s picture');
    final results = ((claude.bodies[1]['messages'] as List).last as Map)['content'] as List;
    final res = results.firstWhere((b) => (b as Map)['type'] == 'tool_result') as Map;
    expect(res['content'], isA<List>());
    expect((res['content'] as List).any((b) => (b as Map)['type'] == 'image'), isTrue, reason: 'the drawing after the change');
    expect(ai().pictures, greaterThanOrEqualTo(2));
  });

  testWidgets('the transcript is Markdown of the whole conversation', (tester) async {
    final claude = FakeClaude([
      (_) => FakeReply.tools([('get_project_summary', {})]),
      (_) => FakeReply.text('An empty project.'),
    ]);
    AiAssistant.debugTransport = claude.call;
    await open(tester);
    await send(tester, 'What is in the project?');
    await drive(tester, () => !ai().busy && claude.calls == 2);
    final md = ai().transcript();
    expect(md, startsWith('# '));
    expect(md, contains('## You'));
    expect(md, contains('What is in the project?'));
    expect(md, contains('`get_project_summary`'));
    expect(md, contains('An empty project.'));
    expect(md, contains('Claude Opus 5.5 (Anthropic)'));
  });

  testWidgets('the docked panel beside the drawing, its button, and the phone sheet with a question card', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final claude = FakeClaude([
      (_) => FakeReply.tools([
        (
          'ask_user',
          {
            'questions': [
              {
                'question': 'Which soil?',
                'options': [
                  {'label': 'Sand'},
                  {'label': 'Clay'},
                ],
              },
            ],
          },
        ),
      ]),
      (_) => FakeReply.text('Noted.'),
    ]);
    AiAssistant.debugTransport = claude.call;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCadTheme(),
        home: Scaffold(
          body: Row(
            children: [
              const Expanded(child: Placeholder()),
              ValueListenableBuilder<bool>(
                valueListenable: AiAssistant.panelOpen,
                builder: (_, open, _) => open
                    ? SizedBox(
                        width: aiPanelWidth,
                        child: AiAgentPanel(c: c),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          bottomNavigationBar: AiPanelButton(c: c),
        ),
      ),
    );
    expect(find.byKey(const Key('ai_panel')), findsNothing);
    await tester.tap(find.byKey(const Key('ai_panel_button')));
    await tester.pump();
    expect(find.byKey(const Key('ai_panel')), findsOneWidget);
    for (final v in ['ai_view_data', 'ai_view_settings', 'ai_view_chat']) {
      await tester.tap(find.byKey(Key(v)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull, reason: v);
    }
    await send(tester, 'Ask me the soil.');
    await drive(tester, () => find.byKey(const Key('ai_question')).evaluate().isNotEmpty);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('ai_question_opt_0_1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai_question_send')));
    await drive(tester, () => !ai().busy && claude.calls == 2);
    expect(claude.lastUserText(1), contains('Which soil? → Clay'));

    // the phone: a bottom sheet over the drawing
    tester.view.physicalSize = const Size(390, 844);
    AiAssistant.panelOpen.value = false;
    AiAssistant.dockable = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCadTheme(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(
                key: const Key('open'),
                onPressed: () => showAiAssistantDialog(ctx, c, prompt: 'Lay out the lawn'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('ai_panel')), findsOneWidget, reason: 'the sheet holds the panel');
    expect((tester.widget(find.byKey(const Key('ai_input'))) as TextField).controller!.text, 'Lay out the lawn');
    for (final v in ['ai_view_data', 'ai_view_settings', 'ai_view_chat']) {
      await tester.tap(find.byKey(Key(v)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull, reason: v);
    }
  });
}
