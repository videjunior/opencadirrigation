import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/app/ai/ai_assistant.dart';
import 'package:opencadirrigation/app/ai/view_snapshot.dart';
import 'package:opencadirrigation/app/io/ai_store.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/widgets/dialogs/ai_assistant_dialog.dart';
import 'package:opencadirrigation/core/ai/llm.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

import 'support/fake_claude.dart';
import 'support/fake_openai.dart';

/// Pictures of the drawing without rendering: a plain picture of the size
/// asked (north up, square pixels), or one of noise that does not compress.
class _Pictures implements ViewSnapshots {
  _Pictures({this.noise = false});
  final bool noise;

  @override
  Future<SnapshotImage> drawing(ProjectController c, Bounds world, int maxSide) async {
    const w = 300, h = 200;
    final im = img.Image(width: w, height: h);
    if (noise) {
      final r = math.Random(7);
      for (final p in im) {
        p
          ..r = r.nextInt(256)
          ..g = r.nextInt(256)
          ..b = r.nextInt(256);
      }
    }
    final s = math.max(world.width / w, world.height / h);
    final cen = world.center;
    return SnapshotImage(png: img.encodePng(im), width: w, height: h, world: Bounds(cen.x - w * s / 2, cen.y - h * s / 2, cen.x + w * s / 2, cen.y + h * s / 2));
  }

  @override
  Future<SnapshotImage?> baseMap(ProjectController c, Bounds world, int maxSide) async => null;
}

/// Conversations kept in this browser across a reload: the same project in
/// a new page brings its conversation back — the transcript, the history
/// byte for byte (thinking blocks and pictures), the to-do list, the meter,
/// the model and the pictures' mappings — and the model goes on with it; a
/// conversation too large is kept without its pictures and thinking; a turn
/// the page closed on comes back with Try again; New conversation and the
/// setting off delete what is kept; the conversation follows the project of
/// the tab; marks the model heard are not sent again; small files are kept.
void main() {
  const key = 'sk-ant-api03-TEST-KEY-DO-NOT-SEND-0000';
  late ProjectController c;
  late MemoryConversationStore store;

  Future<ProjectController> tab() async {
    final t = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    t.newProject();
    await t.setLanguage('en', persist: false);
    return t;
  }

  setUp(() async {
    LocalProjectStore().clearAll();
    AiAssistant.clearSessionKey();
    for (final k in ['ai.model', 'ai.effort', 'ai.mode', 'ai.steps', 'ai.parts', 'ai.cap', 'ai.compact', 'ai.instructions', 'ai.keepChats']) {
      removePref(k);
    }
    // only the pictures the tools take
    setPref('ai.showChanges', 'off');
    setPref(AiAssistant.keyPref, key);
    store = MemoryConversationStore();
    AiAssistant.conversations = store;
    AiAssistant.keptChars = ConversationStore.maxChars;
    AiAssistant.keptFileBytes = 10 * 1024 * 1024;
    c = await tab();
    AiAssistant.debugSleep = (_) async {};
    AiAssistant.debugBrowser = true;
  });
  tearDown(() {
    AiAssistant.debugTransport = null;
    AiAssistant.debugSleep = null;
    AiAssistant.debugBrowser = null;
    AiAssistant.debugSnapshots = null;
    AiAssistant.clearSessionKey();
    for (final k in [AiAssistant.keyPref, 'ai.showChanges', 'ai.keepChats']) {
      removePref(k);
    }
  });

  /// Sends [text] to [ai] and pumps until its turn is over (and kept).
  Future<void> say(WidgetTester tester, AiAssistant ai, String text) async {
    unawaited(ai.send(text));
    for (var i = 0; i < 3000 && ai.busy; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(ai.busy, isFalse, reason: 'the turn did not end');
    await tester.pump();
  }

  /// The page reloads: the old page's assistant is gone, and a tab of the
  /// new page opens the same project (the autosave recovered).
  Future<ProjectController> reload(WidgetTester tester, ProjectController from) async {
    AiAssistant.peek(from)?.dispose();
    final t = await tab();
    t.loadJson(from.saveJson());
    return t;
  }

  Future<String?> kept(ProjectController t) async => (await store.load(t.project.meta.uid))?.json;

  testWidgets('a reload brings the conversation back as it was, and the model goes on with all of it', (tester) async {
    AiAssistant.debugSnapshots = _Pictures();
    final fake = FakeClaude([
      (_) => FakeReply.tools([
        (
          'update_todo',
          {
            'items': [
              {'content': 'Look at the site', 'status': 'done'},
              {'content': 'Lay out the heads', 'status': 'pending'},
            ],
          },
        ),
        (
          'view_snapshot',
          {
            'bbox': [0, 0, 30, 20],
          },
        ),
      ], text: 'Let me look.'),
      (_) => FakeReply.text('The lawn is 30 × 20 m.'),
    ]);
    AiAssistant.debugTransport = fake.call;
    final a = AiAssistant.of(c);
    await say(tester, a, 'How large is the lawn?');
    expect(fake.calls, 2);
    final json = await kept(c);
    expect(json, isNotNull, reason: 'kept once the turn ended');
    expect(json!.contains(key), isFalse, reason: 'never an API key');
    expect(a.unsavedConversation, isFalse, reason: 'kept as it is: leaving the page need not ask');
    final picture = VisionSession.of(a.toolbox)['s1']!;
    List<Object> shown(AiAssistant x) => [
      for (final it in x.items) [it.kind, it.text, it.model, it.error ?? '', for (final call in it.calls) '${call.summary}|${call.state.name}|${call.result}'],
    ];
    final transcript = shown(a);
    final length = a.historyLength;

    final c2 = await reload(tester, c);
    final b = AiAssistant.of(c2);
    expect(b.items, isEmpty, reason: 'it arrives a moment later');
    await tester.pump();
    expect(b.items.last.kind, AiItemKind.notice);
    expect(b.items.last.text, startsWith('Conversation restored — saved ${DateTime.now().year}-'));
    expect(shown(b)..removeLast(), transcript);
    expect(b.historyLength, length);
    expect(b.conversationModel, a.conversationModel);
    expect(b.todos.map((x) => '${x.content}:${x.status.name}'), ['Look at the site:done', 'Lay out the heads:pending']);
    expect([b.usage.input, b.usage.output, b.usage.cacheRead, b.usage.cacheWrite], [a.usage.input, a.usage.output, a.usage.cacheRead, a.usage.cacheWrite]);
    expect(b.cost, a.cost);
    expect(b.pictures, a.pictures);
    expect(b.attachContext, isFalse, reason: 'the project data went with the first message');
    final m = VisionSession.of(b.toolbox)['s1']!;
    expect(
      [m.world.minX, m.world.minY, m.world.maxX, m.world.maxY, m.width, m.height, m.what, m.geo],
      [picture.world.minX, picture.world.minY, picture.world.maxX, picture.world.maxY, picture.width, picture.height, picture.what, picture.geo],
    );
    expect(b.unsavedConversation, isFalse);
    // the restored checkpoints take back the conversation only
    final first = b.items.firstWhere((it) => it.kind == AiItemKind.user);
    expect(b.rewindsProject(first), isFalse);

    // the next message: the earlier conversation goes exactly as it was sent
    final next = FakeClaude([(_) => FakeReply.text('From the west side.')]);
    AiAssistant.debugTransport = next.call;
    await say(tester, b, 'Where is the tap?');
    final sent = next.bodies.single['messages'] as List;
    expect(sent, hasLength(length + 1));
    expect(jsonEncode(sent.take(3).toList()), jsonEncode(fake.bodies[1]['messages']), reason: 'the question, the answer with its thinking block and the tool results with the picture, byte for byte');
    final answer = (sent[3] as Map)['content'] as List;
    expect(answer.first, {'type': 'thinking', 'thinking': '', 'signature': 'sig1'});
    expect(jsonEncode(next.bodies.single['system']), jsonEncode(fake.bodies[0]['system']), reason: 'the system prompt of the conversation');
    expect(next.lastUserText(0), contains('Where is the tap?'));
    expect(b.items.where((it) => it.text.startsWith('Conversation restored')), hasLength(1));
    // kept again, without the notice of this page
    final again = await kept(c2);
    expect(again, isNot(contains('Conversation restored')));
    expect(again, contains('From the west side.'));
  });

  testWidgets('a conversation too large is kept without its pictures and thinking blocks, and goes on', (tester) async {
    AiAssistant.debugSnapshots = _Pictures(noise: true);
    final fake = FakeClaude([
      (_) => FakeReply.tools([
        (
          'view_snapshot',
          {
            'bbox': [0, 0, 30, 20],
          },
        ),
      ]),
      (_) => FakeReply.text('A green field.'),
      (_) => FakeReply.text('You are welcome.'),
    ]);
    AiAssistant.debugTransport = fake.call;
    final a = AiAssistant.of(c);
    await say(tester, a, 'What do you see?');
    final whole = (await kept(c))!;
    final results = ((fake.bodies[1]['messages'] as List).last as Map)['content'] as List;
    final data = (((results.first as Map)['content'] as List).last as Map)['source']['data'] as String;
    expect(data.length, greaterThan(100000));
    expect(whole, contains(data), reason: 'within the limit: kept whole');
    expect(whole, contains('"signature":"sig0"'));
    // now too large for the limit: the picture has to go
    AiAssistant.keptChars = whole.length - data.length ~/ 2;
    await say(tester, a, 'Thanks.');
    final small = (await kept(c))!;
    expect(small.length, lessThanOrEqualTo(AiAssistant.keptChars));
    expect(small.contains(data), isFalse);
    expect(small.contains('"type":"thinking"'), isFalse, reason: 'an edited history keeps no thinking block');
    expect(small, contains('left out when this conversation was kept in the browser'));
    expect(small, contains('You are welcome.'));

    final c2 = await reload(tester, c);
    final b = AiAssistant.of(c2);
    await tester.pump();
    expect(b.historyLength, a.historyLength, reason: 'every entry is there');
    expect(b.items.last.text, contains(c.t('ai.restored.reduced')));
    expect(b.items.where((it) => it.kind == AiItemKind.assistant).map((it) => it.text), ['A green field.', 'You are welcome.']);
    final next = FakeClaude([(_) => FakeReply.text('Sure.')]);
    AiAssistant.debugTransport = next.call;
    await say(tester, b, 'One more thing.');
    final body = jsonEncode(next.bodies.single['messages']);
    expect(body.contains('"type":"thinking"'), isFalse);
    expect(body, contains('left out when this conversation was kept in the browser'));
    expect(next.bodies.single['messages'] as List, hasLength(a.historyLength + 1));
  });

  testWidgets('a turn the page closed on comes back stopped, and Try again sends the question again with its file', (tester) async {
    final hang = FakeClaude([(_) => FakeReply.hang()]);
    AiAssistant.debugTransport = hang.call;
    final a = AiAssistant.of(c);
    a.addAttachment(AiAttachment('notes.txt', 'text/plain', Uint8List.fromList(utf8.encode('Mainline in PVC PN 80'))));
    unawaited(a.send('Read my notes'));
    await tester.pump(const Duration(milliseconds: 60));
    expect(a.busy, isTrue);
    // what this browser holds as the page closes
    final closed = MemoryConversationStore();
    expect(await closed.save(c.project.meta.uid, (await kept(c))!), isTrue);
    expect(a.unsavedConversation, isFalse, reason: 'no answer yet');
    a.stop();
    for (var i = 0; i < 50 && a.busy; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    AiAssistant.conversations = closed;
    final c2 = await reload(tester, c);
    final b = AiAssistant.of(c2);
    await tester.pump();
    final answer = b.items.lastWhere((it) => it.kind == AiItemKind.assistant);
    expect(answer.stopped, isTrue);
    expect(answer.running, isFalse);
    expect(answer.retry?.kept, isFalse);
    expect(b.items.last.text, contains(c.t('ai.restored.interrupted')));
    expect(b.historyLength, 0, reason: 'nothing of that turn reached the model');
    final fake = FakeClaude([(_) => FakeReply.text('Noted: PVC PN 80.')]);
    AiAssistant.debugTransport = fake.call;
    unawaited(b.resume(answer));
    for (var i = 0; i < 500 && (b.busy || fake.calls == 0); i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(fake.calls, 1);
    expect(fake.lastUserText(0), contains('Read my notes'));
    expect(fake.lastUserText(0), contains('Mainline in PVC PN 80'), reason: 'its file went again');
    expect(b.items.where((it) => it.kind == AiItemKind.user).map((it) => it.text), ['Read my notes'], reason: 'once, in its place');
    expect(b.items.last.text, 'Noted: PVC PN 80.');
  });

  testWidgets('New conversation deletes the one kept; with the setting off nothing is kept and what was kept goes', (tester) async {
    final fake = FakeClaude([for (var k = 0; k < 4; k++) (_) => FakeReply.text('Answer $k.')]);
    AiAssistant.debugTransport = fake.call;
    final a = AiAssistant.of(c);
    await say(tester, a, 'First');
    expect(await kept(c), isNotNull);
    a.clear();
    await tester.pump();
    expect(await kept(c), isNull, reason: 'a new conversation: the old one is not kept');
    // a key typed into a message is not kept either
    await say(tester, a, 'My key is $key');
    final json = (await kept(c))!;
    expect(json.contains(key), isFalse);
    expect(json, contains('My key is [key]'));
    AiAssistant.keepConversations = false;
    await tester.pump();
    expect(await store.list(), isEmpty, reason: 'off: what was kept is deleted');
    expect(a.unsavedConversation, isTrue, reason: 'leaving the page asks again');
    await say(tester, a, 'Third');
    expect(await store.list(), isEmpty, reason: 'and nothing more is kept');
    AiAssistant.keepConversations = true;
    await tester.pump();
    expect(await kept(c), contains('Answer 2.'), reason: 'on again: the conversation on screen is kept');
    expect(a.unsavedConversation, isFalse);

    // the settings: the switch, and Delete saved conversations after a confirmation
    tester.view.physicalSize = const Size(1280, 2600);
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
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('ai_view_settings')));
    await tester.pump();
    final delete = find.byKey(const Key('ai_keep_delete'));
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pump(const Duration(milliseconds: 300));
    expect(await store.list(), isNotEmpty, reason: 'nothing before the confirmation');
    await tester.tap(find.byKey(const Key('ai_keep_delete_ok')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(await store.list(), isEmpty);
    expect(c.lastMessage, c.t('ai.keep.deleted'));
    expect(a.unsavedConversation, isTrue);
    final keep = find.byKey(const Key('ai_keep'));
    await tester.ensureVisible(keep);
    await tester.tap(keep);
    await tester.pump();
    expect(AiAssistant.keepConversations, isFalse);
    expect(getPref('ai.keepChats'), 'off');
  });

  testWidgets('the conversation follows the project of the tab', (tester) async {
    final fake = FakeClaude([for (var k = 0; k < 3; k++) (_) => FakeReply.text('Answer $k.')]);
    AiAssistant.debugTransport = fake.call;
    final a = AiAssistant.of(c);
    await say(tester, a, 'About the orchard');
    final orchard = c.saveJson();
    final first = c.project.meta.uid;
    c.newProject();
    await tester.pump();
    expect(a.items, isEmpty, reason: 'another project: its own conversation');
    expect(a.historyLength, 0);
    await say(tester, a, 'About the garden');
    final second = c.project.meta.uid;
    expect((await store.list()).keys, containsAll([first, second]));
    c.loadJson(orchard);
    await tester.pump();
    expect(a.items.where((it) => it.kind == AiItemKind.user).map((it) => it.text), ['About the orchard']);
    expect(a.historyLength, 2);
    // a restored checkpoint takes back the conversation only; back to the start, nothing is kept
    a.rewind(a.items.firstWhere((it) => it.kind == AiItemKind.user));
    await tester.pump();
    expect(a.historyLength, 0);
    expect(a.items.last.text, c.t('ai.rewound.chat'));
    expect(await store.load(first), isNull);
    expect(await store.load(second), isNotNull);
  });

  testWidgets('marks the model heard are not sent again; marks gone with the page are said once', (tester) async {
    final fake = FakeClaude([for (var k = 0; k < 4; k++) (_) => FakeReply.text('Answer $k.')]);
    AiAssistant.debugTransport = fake.call;
    c.aiMarks.add([const Pt(5, 5)], note: 'pump here');
    final a = AiAssistant.of(c);
    await say(tester, a, 'Where does the pump go?');
    expect(fake.lastUserText(0), contains('pump here'));
    // a new page where the same mark is placed before the conversation comes
    // back (opening the project dropped the tab's marks): nothing new to say
    final c2 = await reload(tester, c);
    c2.aiMarks.add([const Pt(5, 5)], note: 'pump here');
    final b = AiAssistant.of(c2);
    await tester.pump();
    expect(b.historyLength, 2);
    await say(tester, b, 'And the valves?');
    expect(fake.lastUserText(1).contains('<user_marks>'), isFalse);
    // another page without it: the model hears the marks went, once
    final c3 = await reload(tester, c2);
    final d = AiAssistant.of(c3);
    await tester.pump();
    await say(tester, d, 'And now?');
    expect(fake.lastUserText(2), contains('The user removed the marks'));
    await say(tester, d, 'Anything else?');
    expect(fake.lastUserText(3).contains('<user_marks>'), isFalse);
  });

  testWidgets('a conversation with GPT comes back the same way, its pictures left out when too large', (tester) async {
    AiAssistant.debugSnapshots = _Pictures(noise: true);
    final a = AiAssistant.of(c);
    a
      ..saveKey('sk-proj-TEST-OPENAI-KEY-0000', provider: AiProvider.openai)
      ..model = AiModel.gpt6Astra;
    final fake = FakeOpenAi([
      (_) => OpenAiReply.tools([
        (
          'view_snapshot',
          {
            'bbox': [0, 0, 30, 20],
          },
        ),
      ]),
      (_) => OpenAiReply.text('A field.'),
      (_) => OpenAiReply.text('Noted.'),
    ]);
    AiAssistant.debugTransport = fake.call;
    await say(tester, a, 'What do you see?');
    final whole = (await kept(c))!;
    expect(whole, contains('"type":"input_image"'));
    AiAssistant.keptChars = whole.length - 100000;
    await say(tester, a, 'Thanks.');
    final small = (await kept(c))!;
    expect(small.contains('"type":"input_image"'), isFalse);
    expect(small, contains('left out when this conversation was kept in the browser'));
    expect(small.contains('sk-proj-TEST-OPENAI-KEY-0000'), isFalse);

    final c2 = await reload(tester, c);
    final b = AiAssistant.of(c2);
    await tester.pump();
    expect(b.conversationModel, AiModel.gpt6Astra);
    expect(b.historyLength, a.historyLength);
    expect(b.items.last.text, contains(c.t('ai.restored.reduced')));
    final next = FakeOpenAi([(_) => OpenAiReply.text('Sure.')]);
    AiAssistant.debugTransport = next.call;
    await say(tester, b, 'One more thing.');
    final sent = next.bodies.single;
    expect(sent['model'], 'gpt-6-astra');
    expect(jsonEncode(sent['input']).contains('"type":"input_image"'), isFalse);
    expect(jsonEncode(sent['input']), contains('A field.'));
    expect(next.lastInputText(0), contains('One more thing.'));
  });

  testWidgets('small attached files are kept with the conversation, larger ones are named', (tester) async {
    AiAssistant.keptFileBytes = 1000;
    final fake = FakeClaude([(_) => FakeReply.text('Read them.')]);
    AiAssistant.debugTransport = fake.call;
    final a = AiAssistant.of(c);
    a
      ..addAttachment(AiAttachment('small.txt', 'text/plain', Uint8List.fromList(utf8.encode('PN 80'))))
      ..addAttachment(AiAttachment('big.txt', 'text/plain', Uint8List(5000)..fillRange(0, 5000, 0x61)));
    await say(tester, a, 'Read these.');
    final c2 = await reload(tester, c);
    final b = AiAssistant.of(c2);
    await tester.pump();
    expect(b.toolbox.host!.files.keys, ['small.txt']);
    expect(utf8.decode(b.toolbox.host!.files['small.txt']!), 'PN 80');
    expect(b.items.last.text, contains(c.t('ai.restored.files', {'f': 'big.txt'})));
    expect(b.items.firstWhere((it) => it.kind == AiItemKind.user).attachments, ['small.txt', 'big.txt']);
  });

  testWidgets('a conversation on a project never changed comes back after a reload, which starts a new empty project', (tester) async {
    removePref(AiAssistant.pristinePref);
    AiAssistant.debugTransport = FakeClaude([(_) => FakeReply.text('A lateral is the pipe that carries the emitters.')]).call;
    final a = AiAssistant.of(c);
    await say(tester, a, 'What is a lateral?');
    final uid = c.project.meta.uid;
    expect(getPref(AiAssistant.pristinePref), uid, reason: 'nothing else brings this conversation back');
    // the reload: nothing to recover, a new empty project takes the uid back
    AiAssistant.peek(c)?.dispose();
    final t = await tab();
    expect(t.project.meta.uid, isNot(uid));
    AiAssistant.resumePristine(t);
    expect(t.project.meta.uid, uid);
    final b = AiAssistant.of(t);
    await tester.pump();
    expect(b.items.map((it) => it.text), contains('A lateral is the pipe that carries the emitters.'));
    // once the project changes, its recovery brings the conversation back
    t.addEntity(TextEntity(id: 't1', position: Pt.zero, text: 'Pump'));
    AiAssistant.debugTransport = FakeClaude([(_) => FakeReply.text('Noted.')]).call;
    await say(tester, b, 'The pump goes there.');
    expect(getPref(AiAssistant.pristinePref), isNull);
    // never the uid of a project kept in this browser, nor a changed project
    setPref(AiAssistant.pristinePref, 'kept-uid');
    t.store.save('kept-uid', 'Farm', t.saveJson(), kind: 'autosave');
    final u = await tab();
    AiAssistant.resumePristine(u);
    expect(u.project.meta.uid, isNot('kept-uid'));
    setPref(AiAssistant.pristinePref, uid);
    u.addEntity(TextEntity(id: 't2', position: Pt.zero, text: 'Well'));
    AiAssistant.resumePristine(u);
    expect(u.project.meta.uid, isNot(uid));
    removePref(AiAssistant.pristinePref);
  });
}
