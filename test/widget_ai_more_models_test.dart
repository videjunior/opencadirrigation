import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/app/ai/ai_assistant.dart';
import 'package:opencadirrigation/app/ai/view_snapshot.dart';
import 'package:opencadirrigation/app/io/data_cache_store.dart';
import 'package:opencadirrigation/app/io/place_search.dart' show siteFetch;
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/app/theme.dart';
import 'package:opencadirrigation/app/widgets/dialogs/ai_assistant_dialog.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/ai/openrouter_catalog.dart';
import 'package:opencadirrigation/core/model/geometry.dart';

import 'support/fake_claude.dart';
import 'support/fake_openai.dart';

/// A plain picture of the drawing, without rendering.
class _Pictures implements ViewSnapshots {
  const _Pictures();
  @override
  Future<SnapshotImage> drawing(ProjectController c, Bounds world, int maxSide) async {
    const w = 300, h = 200;
    final s = math.max(world.width / w, world.height / h);
    final cen = world.center;
    return SnapshotImage(
      png: img.encodePng(img.Image(width: w, height: h)),
      width: w,
      height: h,
      world: Bounds(cen.x - w * s / 2, cen.y - h * s / 2, cen.x + w * s / 2, cen.y + h * s / 2),
    );
  }

  @override
  Future<SnapshotImage?> baseMap(ProjectController c, Bounds world, int maxSide) async => null;
}

/// The models of OpenRouter's list in the assistant (1.7.0): "More models…"
/// in the settings opens the list, and the model chosen there is added,
/// chosen and comes back when the app starts again; a model that calls no
/// tools only talks (no tools in its requests, and it is told so); a model
/// that reads no pictures gets none (the user's, a tool's, the drawing after
/// a change) and is told they were left out; OpenRouter's own words follow
/// the app's error texts; the blocks of Gemini are named.
void main() {
  const orKey = 'sk-or-v1-TEST-OPENROUTER-KEY-0000';
  final sample = File('test/fixtures/openrouter/models_sample.json').readAsStringSync();
  final originalFetch = siteFetch;

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
      'ai.instructions',
      OpenRouterCatalog.prefKey,
      for (final p in AiProvider.values) AiAssistant.keyPrefOf(p),
      for (final p in AiProvider.values) 'ai.model.${p.name}',
    ]) {
      removePref(k);
    }
    setPref('ai.showChanges', 'off');
    AiAssistant.clearSessionKey();
    AiHttpClient.declined.clear();
    AiModel.unregister();
    AiAssistant.restoreModels();
    debugAppDataCache = DataCache(MemoryDataCacheStore());
    siteFetch = (url, headers) async => sample;
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
    AiAssistant.debugSnapshots = null;
    AiAssistant.clearSessionKey();
    siteFetch = originalFetch;
    debugAppDataCache = null;
    removePref(OpenRouterCatalog.prefKey);
    removePref('ai.model');
    for (final p in AiProvider.values) {
      removePref(AiAssistant.keyPrefOf(p));
      removePref('ai.model.${p.name}');
    }
    AiModel.unregister();
    AiAssistant.restoreModels();
  });

  Future<void> open(WidgetTester tester, {Size size = const Size(1280, 1800)}) async {
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

  Future<void> drive(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 4000 && !done(); i++) {
      await tester.pump(const Duration(milliseconds: 20));
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

  OpenRouterEntry entry(String id) => OpenRouterCatalog.parse(sample).firstWhere((e) => e.id == id);

  testWidgets('More models… in the settings opens OpenRouter\'s list; the model chosen is added, chosen, and comes back when the app starts again', (tester) async {
    ai().saveKey(orKey, provider: AiProvider.openrouter);
    ai().model = AiModel.orSonnet55;
    await open(tester);
    await tester.tap(find.byKey(const Key('ai_view_settings')));
    await tester.pump();
    expect(find.byKey(const Key('ai_model_browse')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai_model_browse')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aor_dialog')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('aor_search')), 'minimax');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('aor_row_0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aor_dialog')), findsNothing);
    expect(ai().model.id, 'minimax/minimax-m3.1-flash', reason: 'chosen at once');
    expect(getPref('ai.model'), 'minimax/minimax-m3.1-flash');
    expect(getPref('ai.model.openrouter'), 'minimax/minimax-m3.1-flash');
    final picker = tester.widget<DropdownButton<AiModel>>(find.byKey(const Key('ai_model')));
    expect(picker.value, same(ai().model));
    expect(picker.items!.map((i) => i.value!.id), containsAll(['anthropic/claude-sonnet-5.5', 'minimax/minimax-m3.1-flash']), reason: 'offered with OpenRouter\'s fixed models');
    expect(tester.takeException(), isNull);

    // the app starts again: nothing registered, the list kept in the settings
    final kept = getPref(OpenRouterCatalog.prefKey);
    expect(kept, isNotNull);
    AiModel.unregister();
    removePref(OpenRouterCatalog.prefKey);
    AiAssistant.restoreModels();
    expect(AiModel.byId('minimax/minimax-m3.1-flash'), AiModel.standard, reason: 'unknown until the list is read');
    setPref(OpenRouterCatalog.prefKey, kept!);
    final again = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    again.newProject();
    final next = AiAssistant.of(again);
    expect(next.model.id, 'minimax/minimax-m3.1-flash', reason: 'the first assistant reads the list before the model chosen');
    expect(next.model.provider, AiProvider.openrouter);
    expect(next.lastModelOf(AiProvider.openrouter)?.id, 'minimax/minimax-m3.1-flash');
    // another company has no such button
    await tester.tap(find.byKey(const Key('ai_provider_anthropic')));
    await tester.pump();
    expect(find.byKey(const Key('ai_model_browse')), findsNothing);
  });

  testWidgets('a model that calls no tools only talks: no tools in its requests, it is told so, and the settings say it', (tester) async {
    final m = OpenRouterCatalog.add(entry('writer/palmyra-x5'), setPref);
    AiAssistant.modelsChanged();
    expect(m.tools, isFalse);
    final fake = FakeOpenAi([(_) => OpenAiReply.text('Run Design → Design check and read the messages.', model: 'writer/palmyra-x5')]);
    AiAssistant.debugTransport = fake.call;
    ai().saveKey(orKey, provider: AiProvider.openrouter);
    ai().model = m;
    await open(tester);
    await send(tester, 'Is my design fine?');
    await drive(tester, () => !ai().busy && fake.calls == 1);
    final b = fake.bodies.single;
    expect(fake.requests.single.url.host, 'openrouter.ai');
    expect(b['model'], 'writer/palmyra-x5');
    expect(b.containsKey('tools'), isFalse);
    expect(b['instructions'], contains('you have no tools'));
    expect(b['instructions'], contains('must choose a model that calls tools'));
    expect(ai().systemPrompt, endsWith(AiAssistant.noToolsNote));
    expect(find.textContaining('Design check'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai_view_settings')));
    await tester.pump();
    final hint = tester.widget<Text>(find.byKey(const Key('ai_model_hint'))).data!;
    expect(hint, contains(c.t('ai.model.noTools')));
    expect(hint, contains(c.t('ai.model.noVision')));
    // a model with tools has no such note
    expect(AiModel.orSonnet55.tools, isTrue);
    ai().model = AiModel.orSonnet55;
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('ai_model_hint'))).data!, isNot(contains(c.t('ai.model.noTools'))));
  });

  testWidgets('a model that reads no pictures gets none: the user\'s picture, a tool\'s picture and the drawing after a change stay out, and it is told', (tester) async {
    final m = OpenRouterCatalog.add(entry('z-ai/glm-5.3'), setPref);
    AiAssistant.modelsChanged();
    expect(m.vision, isFalse);
    expect(m.tools, isTrue);
    AiAssistant.debugSnapshots = const _Pictures();
    setPref('ai.showChanges', 'on');
    final fake = FakeOpenAi([
      (_) => OpenAiReply.tools([
        (
          'create_entities',
          {
            'entities': [
              {
                'type': 'area',
                'name': 'Lawn',
                'pts': [
                  [0, 0],
                  [20, 0],
                  [20, 10],
                  [0, 10],
                ],
              },
            ],
          },
        ),
      ], model: 'z-ai/glm-5.3'),
      (_) => OpenAiReply.tools([('view_snapshot', <String, dynamic>{})], model: 'z-ai/glm-5.3'),
      (_) => OpenAiReply.text('Done: one lawn of 200 m².', model: 'z-ai/glm-5.3'),
    ]);
    AiAssistant.debugTransport = fake.call;
    ai()
      ..saveKey(orKey, provider: AiProvider.openrouter)
      ..model = m
      ..permission = AgentPermission.auto;
    ai().attachments.add(AiAttachment('site.png', 'image/png', Uint8List.fromList(img.encodePng(img.Image(width: 40, height: 30)))));
    await open(tester);
    await send(tester, 'Draw a lawn like the one in the picture.');
    await drive(tester, () => !ai().busy && fake.calls == 3);

    final first = jsonEncode(fake.bodies.first['input']);
    expect(first, isNot(contains('input_image')), reason: 'the user\'s picture did not go');
    expect(first, contains('This model does not read pictures'));
    expect(first, contains('site.png'));
    expect(find.text(c.t('ai.attach.noVision', {'m': m.label})), findsOneWidget, reason: 'the user is told');
    expect((fake.bodies.first['tools'] as List).isNotEmpty, isTrue, reason: 'it still has its tools');

    final last = jsonEncode(fake.bodies.last['input']);
    expect(last, isNot(contains('input_image')), reason: 'neither the tool\'s picture nor the drawing after the change');
    expect(last, isNot(contains('data:image')));
    expect(last, contains('The picture of this result did not go: this model does not read pictures.'));
    expect(last, isNot(contains('The drawing after these changes')));
    expect(last, isNot(contains('Error:')), reason: 'both tools ran');
    expect(c.project.entities.length, 1, reason: 'the change itself was made');
    expect(ai().items.where((it) => it.pictures > 0), isEmpty, reason: 'no picture counted as sent');
  });

  testWidgets('a free model answers under the spending cap (no price to divide the cap by)', (tester) async {
    final fake = FakeOpenAi([(_) => OpenAiReply.text('Hello.', model: 'google/gemma-4-31b-it:free')]);
    AiAssistant.debugTransport = fake.call;
    ai()
      ..saveKey(orKey, provider: AiProvider.openrouter)
      ..model = AiModel.orFree;
    expect(ai().costCap, greaterThan(0), reason: 'the cap is on by default');
    await open(tester);
    await send(tester, 'Hello');
    await drive(tester, () => !ai().busy && fake.calls == 1);
    expect(ai().items.last.error, isNull);
    expect(find.text('Hello.'), findsOneWidget);
    expect(fake.bodies.single['max_output_tokens'], AiModel.orFree.maxOutput);
    expect(ai().cost, 0);
    expect(AiModel.orFree.taskBudgetFor(2), 0);
  });

  testWidgets('OpenRouter\'s own words follow the app\'s text of an account error', (tester) async {
    final fake = FakeOpenAi([
      (_) => OpenAiReply.error(429, 'rate_limit_exceeded', 'Rate limit exceeded: free-models-per-day. Add 10 credits to unlock 1000 free model requests per day', type: 'rate_limit_error'),
    ]);
    AiAssistant.debugTransport = fake.call;
    ai()
      ..saveKey(orKey, provider: AiProvider.openrouter)
      ..model = AiModel.orFree;
    await open(tester);
    await send(tester, 'Hello');
    await drive(tester, () => !ai().busy && fake.calls >= 1);
    final error = ai().items.last.error!;
    expect(error, contains('OpenRouter'));
    expect(error, contains('Add 10 credits to unlock 1000 free model requests per day'));
    expect(error, isNot(contains(orKey)));
  });

  testWidgets('the blocks of Gemini and OpenRouter\'s moderation are named in the refusal', (tester) async {
    const anthropicKey = 'sk-ant-api03-TEST-ANTHROPIC-0000';
    String refusalOf(String category) {
      final a = ai();
      return a.debugErrorText(AiError(AiErrorKind.refusal, category: category), AiModel.gemini38Flash);
    }

    ai().saveKey(anthropicKey);
    final filter = c.t('ai.err.cat.filter');
    for (final k in ['safety', 'jailbreak', 'blocklist', 'prohibited_content', 'spii', 'image_safety', 'image_prohibited_content', 'content_blocked', 'moderation', 'content_filter']) {
      expect(refusalOf(k), contains(filter), reason: k);
    }
    expect(refusalOf('recitation'), contains(c.t('ai.err.cat.recitation')));
    expect(refusalOf('image_recitation'), contains(c.t('ai.err.cat.recitation')));
    expect(refusalOf('language'), contains(c.t('ai.err.cat.language')));
    expect(refusalOf('empty'), isNot(contains(c.t('ai.err.cat.policy'))), reason: 'an empty answer names no category');
    expect(refusalOf('something_new'), contains(c.t('ai.err.cat.policy')));
    // unused: the fake transport of another test must not leak
    expect(FakeClaude(const []).calls, 0);
  });
}
