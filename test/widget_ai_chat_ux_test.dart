import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/ai/ai_assistant.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/widgets/dialogs/ai_assistant_dialog.dart';
import 'package:opencadirrigation/core/ai/llm.dart';

import 'support/fake_claude.dart';

/// The conversation's everyday handling: Try again after a failure (the
/// same question in its place) and the way to the settings for a refused
/// key, a suggestion that leaves the cursor in the box so Enter sends it,
/// messages typed for the next step coming back on Stop, commands while
/// the assistant works, the key in the wrong company's field, the model a
/// first key starts with, "remember" moving a saved key, the AI notes saved
/// as one undo step, and an assistant stopping when its tab closes.
void main() {
  const key = 'sk-ant-api03-TEST-KEY-DO-NOT-SEND-0000';

  late ProjectController c;
  setUp(() async {
    LocalProjectStore().clearAll();
    removePref(AiAssistant.keyPref);
    removePref(AiAssistant.keyPrefOf(AiProvider.openai));
    AiAssistant.clearSessionKey();
    for (final k in ['ai.model', 'ai.effort', 'ai.mode', 'ai.steps', 'ai.parts', 'ai.cap', 'ai.compact', 'ai.showChanges', 'ai.instructions']) {
      removePref(k);
    }
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
    removePref(AiAssistant.keyPrefOf(AiProvider.openai));
    AiAssistant.clearSessionKey();
    AiAssistant.dockable = false;
    AiAssistant.panelOpen.value = false;
  });

  Future<void> open(WidgetTester tester, {Size size = const Size(1280, 1600)}) async {
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

  Future<void> drive(WidgetTester tester, bool Function() done, {int max = 3000}) async {
    for (var i = 0; i < max && !done(); i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(done(), isTrue, reason: 'the assistant did not finish');
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  String inputText(WidgetTester tester) => tester.widget<TextField>(find.byKey(const Key('ai_input'))).controller!.text;
  bool inputFocused(WidgetTester tester) => tester.widget<EditableText>(find.descendant(of: find.byKey(const Key('ai_input')), matching: find.byType(EditableText))).focusNode.hasFocus;
  AiAssistant ai() => AiAssistant.of(c);

  testWidgets('a failed question comes back with Try again, which sends it once more in its place', (tester) async {
    setPref(AiAssistant.keyPref, key);
    final fake = FakeClaude([(_) => FakeReply.error(400, 'invalid_request_error', 'Bad request'), (_) => FakeReply.text('The mainline is sized.')]);
    AiAssistant.debugTransport = fake.call;
    await open(tester);
    await tester.enterText(find.byKey(const Key('ai_input')), 'Size the mainline');
    await tester.tap(find.byKey(const Key('ai_send')));
    await drive(tester, () => !ai().busy && fake.calls == 1);
    expect(find.byKey(const Key('ai_error')), findsOneWidget);
    expect(find.byKey(const Key('ai_retry')), findsOneWidget);
    expect(find.byKey(const Key('ai_err_settings')), findsNothing, reason: 'nothing to change in the settings for this one');
    expect(ai().historyLength, 0);
    await tester.tap(find.byKey(const Key('ai_retry')));
    await drive(tester, () => !ai().busy && fake.calls == 2);
    expect(find.textContaining('The mainline is sized.'), findsOneWidget);
    expect(ai().items.where((it) => it.kind == AiItemKind.user).map((it) => it.text), ['Size the mainline'], reason: 'the failed attempt left the conversation');
    expect(fake.requests.last.body, contains('Size the mainline'));
    expect(find.byKey(const Key('ai_retry')), findsNothing);
  });

  testWidgets('a refused key points to the settings', (tester) async {
    setPref(AiAssistant.keyPref, key);
    final fake = FakeClaude([(_) => FakeReply.error(401, 'authentication_error', 'invalid x-api-key')]);
    AiAssistant.debugTransport = fake.call;
    await open(tester);
    await tester.enterText(find.byKey(const Key('ai_input')), 'Hello?');
    await tester.tap(find.byKey(const Key('ai_send')));
    await drive(tester, () => !ai().busy && fake.calls == 1);
    expect(find.byKey(const Key('ai_err_settings')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai_err_settings')));
    await tester.pump();
    expect(find.byKey(const Key('ai_key_field_anthropic')), findsOneWidget);
  });

  testWidgets('a suggestion fills the box and leaves the cursor in it, so Enter sends it', (tester) async {
    setPref(AiAssistant.keyPref, key);
    final fake = FakeClaude([(_) => FakeReply.text('Where is the site?')]);
    AiAssistant.debugTransport = fake.call;
    await open(tester);
    // an empty project: the suggestions start a design
    expect(find.text(c.t('ai.start.prompt')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai_starter_0')));
    await tester.pump();
    await tester.pump();
    expect(inputText(tester), c.t('ai.start.prompt'));
    expect(inputFocused(tester), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await drive(tester, () => !ai().busy && fake.calls == 1);
    expect(find.textContaining('Where is the site?'), findsOneWidget);
    expect(inputFocused(tester), isTrue, reason: 'ready for the next message');
  });

  testWidgets('messages typed for the next step come back to the box on Stop; commands while busy act now or wait', (tester) async {
    setPref(AiAssistant.keyPref, key);
    final fake = FakeClaude([(_) => FakeReply.hang()]);
    AiAssistant.debugTransport = fake.call;
    await open(tester);
    await tester.enterText(find.byKey(const Key('ai_input')), 'Start the design');
    await tester.tap(find.byKey(const Key('ai_send')));
    await tester.pump(const Duration(milliseconds: 60));
    expect(ai().busy, isTrue);
    await tester.enterText(find.byKey(const Key('ai_input')), 'Use PVC on the mainline');
    await tester.tap(find.byKey(const Key('ai_queue')));
    await tester.pump();
    expect(ai().queued, ['Use PVC on the mainline']);
    await tester.enterText(find.byKey(const Key('ai_input')), '/cost');
    await tester.tap(find.byKey(const Key('ai_queue')));
    await tester.pump();
    expect(ai().queued, ['Use PVC on the mainline'], reason: '/cost is not a message for the model');
    expect(find.byKey(const Key('ai_notice')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('ai_input')), '/new');
    await tester.tap(find.byKey(const Key('ai_queue')));
    await tester.pump();
    expect(ai().busy, isTrue, reason: '/new waits for the task to end');
    await tester.tap(find.byKey(const Key('ai_stop')));
    await drive(tester, () => !ai().busy);
    expect(inputText(tester), 'Use PVC on the mainline');
    expect(ai().queued, isEmpty);
    expect(find.byKey(const Key('ai_retry')), findsOneWidget, reason: 'the stopped question can be sent again');
  });

  testWidgets('keys: the wrong company is refused, a first OpenAI key starts on the intermediate model, remember moves a saved key', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const Key('ai_key_field_openai')), key);
    await tester.tap(find.byKey(const Key('ai_key_save_openai')));
    await tester.pump();
    expect(ai().keyOf(AiProvider.openai), isNull, reason: 'an Anthropic key in the OpenAI field');
    expect(find.byKey(const Key('ai_key_one')), findsOneWidget, reason: 'without keys the settings say one is enough');
    await tester.enterText(find.byKey(const Key('ai_key_field_openai')), 'sk-proj-TEST-OPENAI-KEY-0000');
    await tester.tap(find.byKey(const Key('ai_key_save_openai')));
    await tester.pump();
    expect(ai().keyOf(AiProvider.openai), 'sk-proj-TEST-OPENAI-KEY-0000');
    expect(ai().model, AiModel.gpt61Sol, reason: 'not the dearest model of the company');
    expect(getPref(AiAssistant.keyPrefOf(AiProvider.openai)), isNull);
    await tester.tap(find.byKey(const Key('ai_view_settings')));
    await tester.pump();
    final remember = find.byKey(const Key('ai_key_remember_openai'));
    await tester.ensureVisible(remember);
    await tester.tap(remember);
    await tester.pump();
    expect(getPref(AiAssistant.keyPrefOf(AiProvider.openai)), 'sk-proj-TEST-OPENAI-KEY-0000', reason: 'stored at once');
    await tester.tap(remember);
    await tester.pump();
    expect(getPref(AiAssistant.keyPrefOf(AiProvider.openai)), isNull, reason: 'and out again');
    expect(ai().keyOf(AiProvider.openai), 'sk-proj-TEST-OPENAI-KEY-0000', reason: 'still there for the session');
  });

  testWidgets('the AI notes are saved after a pause in typing, as one undo step', (tester) async {
    await open(tester);
    final before = c.historyEntries.length;
    final notes = find.byKey(const Key('ai_notes'));
    await tester.ensureVisible(notes);
    for (final s in ['P', 'PV', 'PVC', 'PVC PN 80']) {
      await tester.enterText(notes, s);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(c.project.aiNotes, isEmpty, reason: 'not on every key');
    await tester.pump(const Duration(milliseconds: 1500));
    expect(c.project.aiNotes, 'PVC PN 80');
    expect(c.historyEntries.length, before + 1);
  });

  test('an assistant whose tab closed stops waiting', () {
    final other = ProjectController()..autosaveEnabled = false;
    other.newProject();
    final a = AiAssistant.of(other);
    final review = AiPlanReview('Lay out the heads');
    a.planReview = review;
    expect(a.waiting, isTrue);
    expect(AiAssistant.peek(other), same(a));
    AiAssistant.stopRemoved([c, other]);
    expect(a.waiting, isTrue, reason: 'its tab is still open');
    AiAssistant.stopRemoved([c]);
    expect(a.waiting, isFalse);
    expect(review.done.isCompleted, isTrue);
  });
}
