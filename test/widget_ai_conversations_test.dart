import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/ai/ai_assistant.dart';
import 'package:opencadirrigation/app/io/ai_store.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/widgets/ai/ai_conversations.dart';

import 'support/fake_claude.dart';

/// The dialog of the conversations of a project (the list button of the
/// assistant): the conversations kept, the one on screen marked, opening
/// one with a tap, deleting one after a confirmation, a new conversation,
/// the export to a file and what the dialog says when nothing is kept. The
/// conversations themselves (how they are kept, opened and deleted) are
/// tested in widget_ai_ia_plus_test.dart; here, what the buttons do.
void main() {
  const key = 'sk-ant-api03-TEST-ANTHROPIC-0000';
  late ProjectController c;
  late MemoryConversationStore store;
  late Directory dir;
  final home = Directory.current;

  setUp(() async {
    LocalProjectStore().clearAll();
    for (final k in ['ai.model', 'ai.effort', 'ai.mode', 'ai.steps', 'ai.parts', 'ai.cap', 'ai.compact', 'ai.instructions', 'ai.keepChats', AiAssistant.titlesPref]) {
      removePref(k);
    }
    setPref('ai.showChanges', 'off');
    AiAssistant.clearSessionKey();
    store = MemoryConversationStore();
    AiAssistant.conversations = store;
    c = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
    await c.setLanguage('en', persist: false);
    AiAssistant.debugSleep = (_) async {};
    AiAssistant.debugBrowser = true;
    setPref(AiAssistant.keyPref, key);
    // a file saved without the file dialog (no navigator of the app here)
    // goes to the current folder: a temporary one
    dir = Directory.systemTemp.createTempSync('oci_conv');
    Directory.current = dir;
  });
  tearDown(() {
    Directory.current = home;
    dir.deleteSync(recursive: true);
    AiAssistant.debugTransport = null;
    AiAssistant.debugSleep = null;
    AiAssistant.debugBrowser = null;
    AiAssistant.clearSessionKey();
    for (final k in [AiAssistant.keyPref, 'ai.showChanges', AiAssistant.titlesPref]) {
      removePref(k);
    }
  });

  /// Sends [text] and pumps until the turn is over (and kept).
  Future<void> say(WidgetTester tester, AiAssistant a, String text) async {
    unawaited(a.send(text));
    for (var i = 0; i < 3000 && a.busy; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(a.busy, isFalse, reason: 'the turn did not end');
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Lets the file system work (it answers in real time, in several steps
  /// that each go on at the next pump) until [done].
  Future<void> until(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 400 && !done(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(done(), isTrue, reason: 'the file was not written');
  }

  /// A page with a button that opens the dialog, as the panel's does.
  Future<void> page(WidgetTester tester, AiAssistant a) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCadTheme(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(key: const Key('open'), onPressed: () => showAiConversations(ctx, c, a), child: const Text('open')),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('open')));
    await settle(tester);
    expect(find.byKey(const Key('ai_conversations_dialog')), findsOneWidget);
  }

  String titleOf(WidgetTester tester, int row) => (tester.widget<ListTile>(find.byKey(Key('ai_conv_$row'))).title! as Text).data!;
  String subtitleOf(WidgetTester tester, int row) => (tester.widget<ListTile>(find.byKey(Key('ai_conv_$row'))).subtitle! as Text).data!;
  bool enabled(WidgetTester tester, String buttonKey) => tester.widget<ButtonStyleButton>(find.byKey(Key(buttonKey))).onPressed != null;

  testWidgets('nothing kept: the dialog says so, and there is nothing to export', (tester) async {
    final a = AiAssistant.of(c);
    await page(tester, a);
    await open(tester);
    expect(find.byKey(const Key('ai_conv_none')), findsOneWidget);
    expect(find.text('No conversation of this project is kept.'), findsOneWidget);
    expect(enabled(tester, 'ai_conv_export'), isFalse);
    expect(enabled(tester, 'ai_conv_new'), isTrue);
    // importing without choosing a file leaves the dialog open
    await tester.tap(find.byKey(const Key('ai_conv_import')));
    await settle(tester);
    expect(find.byKey(const Key('ai_conversations_dialog')), findsOneWidget);
    await tester.tap(find.text('Close'));
    await settle(tester);
    expect(find.byKey(const Key('ai_conversations_dialog')), findsNothing);
  });

  testWidgets('the list marks the conversation on screen; a tap on another opens it and closes the dialog', (tester) async {
    AiAssistant.debugTransport = FakeClaude([(_) => FakeReply.text('About the pump.'), (_) => FakeReply.text('About the quote.')]).call;
    final a = AiAssistant.of(c);
    await say(tester, a, 'First: the pump');
    a.newConversation();
    await tester.pump();
    await say(tester, a, 'Second: the quote');
    await page(tester, a);
    await open(tester);
    expect(find.byKey(const Key('ai_conv_none')), findsNothing);
    final titles = [titleOf(tester, 0), titleOf(tester, 1)];
    expect(titles, unorderedEquals(['First: the pump', 'Second: the quote']));
    final second = titles.indexOf('Second: the quote'), first = 1 - second;
    // the date and time it was kept, and which one is on screen
    expect(subtitleOf(tester, second), matches(RegExp(r'^\d{4}-\d\d-\d\d \d\d:\d\d · on screen$')));
    expect(subtitleOf(tester, first), matches(RegExp(r'^\d{4}-\d\d-\d\d \d\d:\d\d$')));
    expect(tester.widget<ListTile>(find.byKey(Key('ai_conv_$second'))).selected, isTrue);
    expect(tester.widget<ListTile>(find.byKey(Key('ai_conv_$second'))).onTap, isNull, reason: 'the one on screen is already open');
    expect(enabled(tester, 'ai_conv_export'), isTrue);
    await tester.tap(find.byKey(Key('ai_conv_$first')));
    await settle(tester);
    expect(find.byKey(const Key('ai_conversations_dialog')), findsNothing);
    expect(a.items.first.text, 'First: the pump');
    // now the first is the one on screen
    await open(tester);
    final now = [titleOf(tester, 0), titleOf(tester, 1)].indexOf('First: the pump');
    expect(subtitleOf(tester, now), endsWith('· on screen'));
  });

  testWidgets('deleting asks first: Cancel keeps the conversation, Delete takes it out of the list', (tester) async {
    AiAssistant.debugTransport = FakeClaude([(_) => FakeReply.text('About the pump.'), (_) => FakeReply.text('About the quote.')]).call;
    final a = AiAssistant.of(c);
    await say(tester, a, 'First: the pump');
    a.newConversation();
    await tester.pump();
    await say(tester, a, 'Second: the quote');
    await page(tester, a);
    await open(tester);
    final first = [titleOf(tester, 0), titleOf(tester, 1)].indexOf('First: the pump');
    await tester.tap(find.byKey(Key('ai_conv_delete_$first')));
    await settle(tester);
    expect(find.text('Delete the conversation "First: the pump" from this browser?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(await a.projectConversations(), hasLength(2));
    expect(find.byKey(const Key('ai_conv_1')), findsOneWidget);
    await tester.tap(find.byKey(Key('ai_conv_delete_$first')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('ai_conv_delete_ok')));
    await settle(tester);
    expect((await a.projectConversations()).single.title, 'Second: the quote');
    expect(titleOf(tester, 0), 'Second: the quote');
    expect(find.byKey(const Key('ai_conv_1')), findsNothing);
    expect(a.items.first.text, 'Second: the quote', reason: 'the one on screen stays');
  });

  testWidgets('New conversation empties the screen and keeps the one that was there; Export writes it to a file', (tester) async {
    AiAssistant.debugTransport = FakeClaude([(_) => FakeReply.text('About the pump.')]).call;
    final a = AiAssistant.of(c);
    await say(tester, a, 'First: the pump');
    await page(tester, a);
    await open(tester);
    await tester.tap(find.byKey(const Key('ai_conv_export')));
    await until(tester, () => c.lastMessage != null);
    final files = dir.listSync().whereType<File>().toList();
    expect(files.single.path, endsWith('project - AI conversation.json'));
    final text = files.single.readAsStringSync();
    expect(text, contains('First: the pump'));
    expect(text, isNot(contains(key)), reason: 'the key never goes into the file');
    expect(jsonDecode(text), isA<Map<String, dynamic>>());
    expect(c.lastMessage, c.t('ai.conv.exported'));
    // a new conversation: the dialog closes, the screen is empty, the first one is in the list
    await tester.tap(find.byKey(const Key('ai_conv_new')));
    await settle(tester);
    expect(find.byKey(const Key('ai_conversations_dialog')), findsNothing);
    expect(a.items, isEmpty);
    await open(tester);
    expect(titleOf(tester, 0), 'First: the pump');
    expect(subtitleOf(tester, 0), isNot(contains('on screen')));
    expect(enabled(tester, 'ai_conv_export'), isFalse, reason: 'nothing on screen to export');
    // exporting with nothing on screen says so
    await aiExportConversation(c, a);
    expect(c.lastMessage, c.t('ai.conv.exportNone'));
    expect(dir.listSync().whereType<File>(), hasLength(1));
  });
}
