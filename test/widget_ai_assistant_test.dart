import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/actions.dart';
import 'package:opencadirrigation/app/ai/ai_assistant.dart';
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/widgets/dialogs/ai_assistant_dialog.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/model/entities.dart';
import 'package:opencadirrigation/core/io/project_export.dart' show ReportFormat;

import 'support/fake_claude.dart';

/// The AI assistant in the app, against a scripted model (no network): the
/// key kept in this device's preferences only, nothing sent before Send and
/// the preview equal to what is sent, the agent building and designing a
/// lawn through the real tools with approvals, a skipped change, the undo
/// of the whole turn, errors, stopping, and the phone layout.
void main() {
  const key = 'sk-ant-api03-TEST-KEY-DO-NOT-SEND-0000';

  late ProjectController c;
  setUp(() async {
    LocalProjectStore().clearAll();
    removePref(AiAssistant.keyPref);
    AiAssistant.clearSessionKey();
    removePref(AiAssistant.keyPrefOf(AiProvider.openai));
    for (final k in ['ai.model', 'ai.effort', 'ai.mode', 'ai.steps', 'ai.parts', 'ai.cap', 'ai.compact', 'ai.showChanges', 'ai.instructions']) {
      removePref(k);
    }
    // the picture after each round renders in real time only: on where a test asks for it
    setPref('ai.showChanges', 'off');
    AiHttpClient.declined.clear();
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

  /// Pumps until [done] holds, answering approvals with [decide].
  Future<void> drive(WidgetTester tester, bool Function() done, {String Function(String tool)? decide, int max = 4000}) async {
    for (var i = 0; i < max && !done(); i++) {
      await tester.pump(const Duration(milliseconds: 20));
      final p = AiAssistant.of(c).pending;
      if (p != null && find.byKey(const Key('ai_apply')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(Key(decide?.call(p.call.name) ?? 'ai_apply')));
      }
    }
    expect(done(), isTrue, reason: 'the assistant did not finish');
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  String previewOf(WidgetTester tester) => (tester.widget(find.byKey(const Key('ai_preview_text'))) as SelectableText).data!;

  testWidgets('each key stays in memory unless remembered on this device, is shown masked, and is forgotten on request', (tester) async {
    await open(tester, size: const Size(1280, 1800));
    // no key yet: the settings open first, the chosen model's company first
    expect(find.byKey(const Key('ai_key_field_anthropic')), findsOneWidget);
    expect(find.byKey(const Key('ai_key_field_openai')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('ai_key_field_anthropic')), key);
    await tester.tap(find.byKey(const Key('ai_key_save_anthropic')));
    await tester.pump();
    expect(getPref(AiAssistant.keyPref), isNull, reason: 'not in the browser storage unless asked');
    expect(AiAssistant.of(c).apiKey, key);
    await tester.tap(find.byKey(const Key('ai_view_settings')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai_key_remember_anthropic')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('ai_key_field_anthropic')), key);
    await tester.tap(find.byKey(const Key('ai_key_save_anthropic')));
    await tester.pump();
    expect(getPref(AiAssistant.keyPref), key);
    expect(find.byKey(const Key('ai_input')), findsOneWidget, reason: 'back to the conversation');
    await tester.tap(find.byKey(const Key('ai_view_settings')));
    await tester.pump();
    final saved = (tester.widget(find.byKey(const Key('ai_key_saved_anthropic'))) as Text).data!;
    expect(saved.contains(key), isFalse);
    expect(saved, contains('…'));
    expect(find.textContaining(key), findsNothing);
    // the OpenAI key is a key of its own
    const openaiKey = 'sk-proj-TEST-OPENAI-KEY-0000';
    await tester.enterText(find.byKey(const Key('ai_key_field_openai')), openaiKey);
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai_key_save_openai')));
    await tester.pump();
    expect(AiAssistant.of(c).keyOf(AiProvider.openai), openaiKey);
    expect(AiAssistant.of(c).keyOf(AiProvider.anthropic), key);
    expect(getPref(AiAssistant.keyPrefOf(AiProvider.openai)), isNull, reason: 'session only, as asked');
    await tester.tap(find.byKey(const Key('ai_view_settings')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai_key_forget_anthropic')));
    await tester.pump();
    expect(getPref(AiAssistant.keyPref), isNull);
    expect(AiAssistant.of(c).hasKeyFor(AiProvider.anthropic), isFalse);
    expect(AiAssistant.of(c).hasKeyFor(AiProvider.openai), isTrue, reason: 'forgetting one key keeps the other');
  });

  testWidgets('nothing is sent before Send, and what is sent is the preview', (tester) async {
    setPref(AiAssistant.keyPref, key);
    loadExampleAction(c, ExampleId.orchard);
    await tester.runAsync(() => c.runDesign());
    final fake = FakeClaude([(_) => FakeReply.text('The **pressure** window holds.')]);
    AiAssistant.debugTransport = fake.call;
    await open(tester);
    await tester.enterText(find.byKey(const Key('ai_input')), 'Does every zone hold its pressure window?');
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai_view_data')));
    await tester.pump();
    final preview = previewOf(tester);
    expect(preview, contains('<project_data>'));
    expect(preview, contains('Does every zone hold its pressure window?'));
    expect(preview, contains(c.project.meta.name));
    expect(find.byKey(const Key('ai_privacy')), findsOneWidget);
    // untick a part: the preview follows
    await tester.ensureVisible(find.byKey(const Key('ai_part_catalog')));
    await tester.tap(find.byKey(const Key('ai_part_catalog')));
    await tester.pump();
    final preview2 = previewOf(tester);
    expect(preview2.contains(c.t('ai.ctx.catalog')), isFalse);
    expect(fake.calls, 0, reason: 'opening, typing and previewing send nothing');
    await tester.tap(find.byKey(const Key('ai_view_chat')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai_send')));
    await drive(tester, () => !AiAssistant.of(c).busy && fake.calls == 1);
    expect(fake.lastUserText(0), preview2);
    // the key travels in its header only, to the Anthropic API
    final req = fake.requests.single;
    expect(req.url.host, 'api.anthropic.com');
    expect(req.headers['x-api-key'], key);
    expect(req.body.contains(key), isFalse);
    expect(find.textContaining('pressure'), findsWidgets);
    expect(find.textContaining('window holds'), findsOneWidget);
    // the next message does not carry the project data again
    expect(AiAssistant.of(c).attachContext, isFalse);
    expect(c.saveJson().contains(key), isFalse);
  });

  testWidgets('the agent lays out and designs a lawn with the real tools; a skipped change is not made; the whole turn undoes in one step', (tester) async {
    setPref(AiAssistant.keyPref, key);
    final fake = FakeClaude([
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
              {
                'type': 'waterSupply',
                'name': 'Tap',
                'p': [-15, 15],
                'calc': true,
              },
            ],
          },
        ),
      ], text: 'I will draw the lawn and the tap.'),
      (_) => FakeReply.tools([
        ('layout_sprinklers', {'area': 'Lawn', 'zoning': true, 'routing': true}),
      ]),
      (_) => FakeReply.tools([('run_design', {})]),
      (_) => FakeReply.tools([
        ('get_report_table', {'table': 'zones'}),
        ('get_entity', {'id': 'nope'}),
      ]),
      (_) => FakeReply.tools([
        (
          'delete_entities',
          {
            'ids': ['Lawn'],
          },
        ),
      ]),
      (_) => FakeReply.text('The lawn is laid out and designed.'),
    ]);
    AiAssistant.debugTransport = fake.call;
    await open(tester);
    await tester.enterText(find.byKey(const Key('ai_input')), 'Design the irrigation of a 40 × 30 m lawn fed from a tap 15 m west of it.');
    await tester.tap(find.byKey(const Key('ai_send')));
    final asked = <String>[];
    await drive(
      tester,
      () => !AiAssistant.of(c).busy && fake.calls == 6,
      decide: (tool) {
        asked.add(tool);
        return tool == 'delete_entities' ? 'ai_skip' : 'ai_apply';
      },
    );
    expect(asked, ['create_entities', 'layout_sprinklers', 'run_design', 'delete_entities'], reason: 'every change was asked; reads were not');
    final p = c.project;
    expect(p.entities.whereType<AreaEntity>().single.name, 'Lawn', reason: 'the skipped deletion did not happen');
    expect(p.entities.whereType<WaterSupplyEntity>(), hasLength(1));
    expect(p.entities.whereType<OutletEntity>().length, greaterThan(4));
    expect(p.entities.whereType<ControlValveEntity>(), isNotEmpty);
    expect(p.entities.whereType<PipeEntity>(), isNotEmpty);
    expect(c.results, isNotNull, reason: 'the results of the design the AI ran are kept');
    // what the tools returned to the model
    expect(fake.lastUserText(2), contains('heads'));
    expect(fake.lastUserText(3), contains('zones'));
    expect(fake.lastUserText(4), contains(c.results!.zones.values.first.zoneName));
    expect(fake.lastUserText(4), contains('No item "nope"'), reason: 'a failing tool goes back as an error result');
    expect(fake.lastUserText(5), contains('declined'));
    // one step in the history for the whole turn, and its undo
    expect(c.historyEntries.where((e) => e.label == 'hist.ai'), hasLength(1));
    final answer = AiAssistant.of(c).items.last;
    expect(answer.changes, isNotNull);
    expect(answer.changes!.added.keys, contains(c.t('tool.outlet').split('/').first.trim()));
    expect(answer.text, contains('designed'));
    expect(find.byKey(const Key('ai_changes')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('ai_undo_turn')));
    await tester.tap(find.byKey(const Key('ai_undo_turn')));
    await tester.pump();
    expect(c.project.entities, isEmpty, reason: 'back to the empty project');
    expect(answer.changes!.undone, isTrue);
    expect(find.text(c.t('ai.chg.undone')), findsOneWidget);
    // the key never left its header
    for (final r in fake.requests) {
      expect(r.body.contains(key), isFalse);
    }
    expect(c.saveJson().contains(key), isFalse);
    // tokens counted for the conversation
    expect(AiAssistant.of(c).usage.output, 300);
    expect(find.byKey(const Key('ai_meter')), findsOneWidget);
  });

  testWidgets('a rejected key is explained without showing it; Stop cancels a request in flight', (tester) async {
    setPref(AiAssistant.keyPref, key);
    final fake = FakeClaude([(_) => FakeReply.error(401, 'authentication_error', 'invalid x-api-key: $key'), (_) => FakeReply.hang()]);
    AiAssistant.debugTransport = fake.call;
    await open(tester);
    await tester.enterText(find.byKey(const Key('ai_input')), 'Hello?');
    // Enter sends (Shift+Enter would add a line)
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await drive(tester, () => !AiAssistant.of(c).busy && fake.calls == 1);
    expect(find.text(c.t('ai.err.auth', {'p': 'Anthropic'})), findsOneWidget);
    expect(find.textContaining(key), findsNothing);
    expect(AiAssistant.of(c).historyLength, 0, reason: 'a failed question is not kept');
    await tester.enterText(find.byKey(const Key('ai_input')), 'Again?');
    await tester.tap(find.byKey(const Key('ai_send')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('ai_stop')), findsOneWidget);
    expect(find.byKey(const Key('ai_status')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai_stop')));
    await drive(tester, () => !AiAssistant.of(c).busy);
    expect(AiAssistant.of(c).items.last.stopped, isTrue);
    expect(find.text(c.t('ai.stopped')), findsOneWidget);
    expect(find.byKey(const Key('ai_send')), findsOneWidget);
  });

  testWidgets('read-only mode refuses changes without asking', (tester) async {
    setPref(AiAssistant.keyPref, key);
    AiAssistant.of(c).permission = AgentPermission.readOnly;
    final fake = FakeClaude([
      (_) => FakeReply.tools([
        (
          'create_entities',
          {
            'entities': [
              {
                'type': 'text',
                'p': [0, 0],
                'text': 'x',
              },
            ],
          },
        ),
      ]),
      (_) => FakeReply.text('I may not change the project.'),
    ]);
    AiAssistant.debugTransport = fake.call;
    await open(tester);
    await tester.enterText(find.byKey(const Key('ai_input')), 'Add a note.');
    await tester.tap(find.byKey(const Key('ai_send')));
    await drive(tester, () => !AiAssistant.of(c).busy && fake.calls == 2);
    expect(c.project.entities, isEmpty);
    expect(fake.lastUserText(1), contains('read-only'));
    expect(find.byKey(const Key('ai_approval')), findsNothing);
  });

  testWidgets('a PDF data sheet goes whole, or as the text read on this device', (tester) async {
    loadExampleAction(c, ExampleId.orchard);
    await tester.runAsync(() => c.runDesign());
    final pdf = c.exporter().exportReport(ReportFormat.pdf) as dynamic;
    final a = AiAttachment('sheet.pdf', 'application/pdf', pdf);
    expect(a.parts().single, isA<AiPdfPart>());
    final text = a.pdfText;
    expect(text, isNotNull);
    expect(text, contains(c.results!.zones.values.first.zoneName));
    a.asText = true;
    final b = a.parts().single as AiTextPart;
    expect(b.text, startsWith('<attachment name="sheet.pdf"'));
    expect(AiAttachment.mimeOf('photo.JPG'), 'image/jpeg');
    // a drawing is imported, not read: the model learns it is there
    expect(AiAttachment.mimeOf('model.dwg'), AiAttachment.importMime);
    final dwg = AiAttachment('site.dwg', AiAttachment.importMime, pdf);
    expect((dwg.parts().single as AiTextPart).text, contains('import_attachment'));
    expect(AiAttachment.mimeOf('virus.exe'), isNull);
  });

  testWidgets('the dialog fits a phone (390×844) in every view, with an approval card', (tester) async {
    setPref(AiAssistant.keyPref, key);
    final fake = FakeClaude([
      (_) => FakeReply.tools([
        (
          'create_entities',
          {
            'entities': [
              {
                'type': 'text',
                'p': [1, 1],
                'text': 'Note',
              },
            ],
          },
        ),
      ]),
      (_) => FakeReply.text('Added a note.'),
    ]);
    AiAssistant.debugTransport = fake.call;
    await open(tester, size: const Size(390, 844));
    expect(tester.takeException(), isNull);
    for (final v in ['ai_view_data', 'ai_view_settings', 'ai_view_chat']) {
      await tester.tap(find.byKey(Key(v)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull, reason: v);
    }
    await tester.enterText(find.byKey(const Key('ai_input')), 'Add a note at 1, 1.');
    await tester.tap(find.byKey(const Key('ai_send')));
    for (var i = 0; i < 200 && find.byKey(const Key('ai_approval')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.byKey(const Key('ai_approval')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await drive(tester, () => !AiAssistant.of(c).busy && fake.calls == 2);
    expect(c.project.entities.whereType<TextEntity>().single.text, 'Note');
    expect(tester.takeException(), isNull);
  });
}
