import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/ai/ai_assistant.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/widgets/dialogs/ai_assistant_dialog.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

import 'support/fake_claude.dart';

/// The review of the drawing from the chat's start view: it sends /review,
/// which runs read-only even when changes apply automatically.
void main() {
  const key = 'sk-ant-api03-TEST-KEY-DO-NOT-SEND-0000';
  late ProjectController c;
  setUp(() async {
    LocalProjectStore().clearAll();
    removePref(AiAssistant.keyPref);
    AiAssistant.clearSessionKey();
    for (final k in ['ai.model', 'ai.effort', 'ai.mode', 'ai.steps', 'ai.parts', 'ai.cap', 'ai.compact', 'ai.showChanges', 'ai.instructions']) {
      removePref(k);
    }
    // the picture after each round renders in real time only: on where a test asks for it
    setPref('ai.showChanges', 'off');
    c = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
    await c.setLanguage('en', persist: false);
    AiAssistant.debugSleep = (_) async {};
    AiAssistant.debugBrowser = true;
  });
  tearDown(() {
    AiAssistant.debugTransport = null;
    AiAssistant.debugSleep = null;
    AiAssistant.debugBrowser = null;
    removePref(AiAssistant.keyPref);
    AiAssistant.clearSessionKey();
  });

  testWidgets('Review the design runs read-only: a change the model tries is refused, the project stays as it was', (tester) async {
    setPref(AiAssistant.keyPref, key);
    c.addEntity(LineEntity(id: 'l1', a: Pt.zero, b: const Pt(10, 0)));
    AiAssistant.of(c).permission = AgentPermission.auto;
    final fake = FakeClaude([
      (_) => FakeReply.tools([
        (
          'create_entities',
          {
            'entities': [
              {
                'type': 'line',
                'a': [0, 5],
                'b': [10, 5],
              },
            ],
          },
        ),
      ]),
      (_) => FakeReply.text('| Point | Status |\n|---|---|\n| Network | problem |'),
    ]);
    AiAssistant.debugTransport = fake.call;
    tester.view.physicalSize = const Size(1280, 1600);
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
    expect(find.byKey(const Key('ai_review')), findsOneWidget);
    final before = c.historyIndex;
    await tester.tap(find.byKey(const Key('ai_review')));
    final ai = AiAssistant.of(c);
    for (var i = 0; i < 3000 && (ai.busy || fake.calls < 2); i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(fake.calls, 2);
    final first = fake.bodies.first['messages'] as List;
    expect('${first.last}', contains('Review this design without changing anything'));
    // the refusal went back to the model with the tool result
    final second = '${(fake.bodies[1]['messages'] as List).last}';
    expect(second.toLowerCase(), contains('read-only'));
    expect(c.historyIndex, before, reason: 'nothing changed');
    expect(c.project.entities, hasLength(1));
    expect(ai.permission, AgentPermission.auto, reason: 'the mode in the settings stays');
  });
}
