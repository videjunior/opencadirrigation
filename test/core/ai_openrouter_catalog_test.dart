// OpenRouter's list of models read into the assistant's models, against a
// small recorded sample of the real list (GET /api/v1/models, 2026-11-10;
// descriptions shortened, benchmarks left out): which rows are offered,
// their prices per million tokens with the long-prompt rules, efforts,
// output limits and what they can do; the tier rule; the user's list kept
// in the preferences and registered again; and the download's failures,
// with the copy kept for when it fails.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/ai/openrouter_catalog.dart';

void main() {
  final sample = File('test/fixtures/openrouter/models_sample.json').readAsStringSync();
  List<OpenRouterEntry> entries() => OpenRouterCatalog.parse(sample);
  OpenRouterEntry entry(String id) => entries().firstWhere((e) => e.id == id);

  tearDown(AiModel.unregister);

  test('the sample is a dozen rows of the real list, under 30 KB', () {
    expect(utf8.encode(sample).length, lessThan(30 * 1024));
    expect((jsonDecode(sample)['data'] as List).length, 15);
  });

  test('offered: the rows the Responses API serves with text out; not the batch rows, the aliases, the image models', () {
    final ids = entries().map((e) => e.id).toList();
    expect(ids, [
      'anthropic/claude-opus-5.5',
      'anthropic/claude-haiku-5.5',
      'openai/gpt-6.1-sol',
      'x-ai/grok-4.7',
      'google/gemini-3.8-flash',
      'google/gemma-4-31b-it:free',
      'openrouter/auto',
      'openrouter/free',
      'z-ai/glm-5.3',
      'writer/palmyra-x5',
      'liquid/lfm-3-1.7b',
      'minimax/minimax-m3.1-flash',
    ]);
    // a row served by the Responses API whose output is not text is left out too
    final row = Map<String, dynamic>.from((jsonDecode(sample)['data'] as List).first as Map);
    row['architecture'] = {
      ...row['architecture'] as Map,
      'output_modalities': ['image'],
    };
    expect(OpenRouterCatalog.entryOf(row), isNull);
    expect(OpenRouterCatalog.entryOf(const {'id': 'x/no-price', 'pricing': {}}), isNull);
    expect(OpenRouterCatalog.entryOf(const {'name': 'no id'}), isNull);
  });

  test('a maker\'s model: its name and maker, prices per million tokens with the cache, efforts, output limit, pictures, tools, PDFs', () {
    final e = entry('anthropic/claude-opus-5.5');
    final m = e.model;
    expect(e.name, 'Claude Opus 5.5');
    expect(e.maker, 'Anthropic');
    expect(m.provider, AiProvider.openrouter);
    expect(m.label, 'Claude Opus 5.5 (OpenRouter)');
    expect([m.input, m.output, m.cacheRead, m.cacheWrite], [4, 20, 0.2, 5]);
    expect(m.tier, AiTier.top);
    expect(m.efforts, AiEffort.values);
    expect(m.maxOutput, 128000);
    expect(e.context, 1000000);
    expect(m.vision && m.tools && e.files && e.reasoning, isTrue);
    expect(m.compaction, isFalse);
    expect(m.priced, isTrue);
    expect(m.freeTier, isFalse);
    expect(m.longAbove, 0);
    // the same prices as the app's own entry for it
    for (final f in [(AiModel x) => x.input, (AiModel x) => x.output, (AiModel x) => x.cacheRead, (AiModel x) => x.cacheWrite]) {
      expect(f(m), f(AiModel.orOpus55));
    }
  });

  test('a longer prompt priced higher (the length overrides), not the time-of-day ones', () {
    final haiku = entry('anthropic/claude-haiku-5.5').model;
    expect([haiku.longAbove, haiku.longInput, haiku.longOutput], [100000, 5, 5]);
    expect(haiku.tier, AiTier.fast);
    final sol = entry('openai/gpt-6.1-sol').model;
    expect([sol.longAbove, sol.longInput, sol.longOutput], [272000, 2, 1.5]);
    expect(const AiUsage(input: 300000, output: 1000000).cost(sol), closeTo((300000 * 2 * 2 + 1000000 * 10 * 1.5) / 1e6, 1e-9));
    final grok = entry('x-ai/grok-4.7');
    expect(grok.maker, 'SpaceXAI');
    expect([grok.model.longAbove, grok.model.longInput, grok.model.longOutput], [200000, 2, 2]);
    expect(grok.model.cacheWrite, grok.model.input, reason: 'no price for writing the cache: written tokens cost the input price');
    expect(grok.model.efforts, [AiEffort.low, AiEffort.medium, AiEffort.high, AiEffort.xhigh]);
    expect(entry('minimax/minimax-m3.1-flash').model.longAbove, 0, reason: 'a discount by the hour of the day is not a prompt length');
    final flash = entry('google/gemini-3.8-flash').model;
    expect(flash.input, 0.825);
    expect(flash.efforts, [AiEffort.low, AiEffort.medium, AiEffort.high]);
    expect(flash.maxOutput, 65536);
  });

  test('free models, routers, and what a model cannot do', () {
    final gemma = entry('google/gemma-4-31b-it:free');
    expect(gemma.free, isTrue);
    expect([gemma.model.input, gemma.model.output], [0, 0]);
    expect(gemma.model.tier, AiTier.fast);
    expect(gemma.files, isFalse);
    expect(gemma.model.efforts, isEmpty, reason: 'it reasons but takes no effort setting');
    expect(gemma.model.maxOutput, 32768);
    final auto = entry('openrouter/auto');
    expect(auto.router, isTrue);
    expect(auto.model.priced, isFalse, reason: 'the list prices a router at −1: it bills the model it picks');
    expect([auto.model.input, auto.model.output], [0, 0]);
    expect(auto.model.tier, AiTier.intermediate);
    expect(auto.model.maxOutput, OpenRouterCatalog.defaultOutput);
    expect(auto.maker, 'OpenRouter');
    expect(auto.sortPrice, double.infinity);
    final free = entry('openrouter/free');
    expect(free.free && free.model.priced, isTrue);
    expect(entry('z-ai/glm-5.3').model.vision, isFalse);
    expect(entry('z-ai/glm-5.3').model.tools, isTrue);
    expect(entry('writer/palmyra-x5').model.tools, isFalse);
    final lfm = entry('liquid/lfm-3-1.7b');
    expect(lfm.reasoning, isTrue);
    expect(lfm.model.efforts, isEmpty, reason: 'mandatory reasoning, no effort setting exposed');
    expect(lfm.model.maxOutput, 8192);
    // the documentation: a null list of efforts takes any (no row of the list has one today)
    final row = Map<String, dynamic>.from((jsonDecode(sample)['data'] as List).firstWhere((r) => r['id'] == 'liquid/lfm-3-1.7b') as Map);
    row['reasoning'] = {'mandatory': true, 'supported_efforts': null};
    expect(OpenRouterCatalog.entryOf(row)!.model.efforts, AiEffort.values);
  });

  test('prices: US\$ per token to US\$ per million, to a millionth of a dollar', () {
    expect(OpenRouterCatalog.perMillion('0.0000025'), 2.5);
    expect(OpenRouterCatalog.perMillion('0.0000000416666666666667'), 0.041667);
    expect(OpenRouterCatalog.perMillion('-1'), -1000000);
    expect(OpenRouterCatalog.perMillion(0.00002), 20);
    expect(OpenRouterCatalog.perMillion('abc'), isNull);
    expect(OpenRouterCatalog.perMillion(null), isNull);
  });

  test('the tier is a band of the output price; on the app\'s own models it differs only for Grok 4.7 and GPT-6.1 Terra', () {
    expect(OpenRouterCatalog.tierOf(40), AiTier.top);
    expect(OpenRouterCatalog.tierOf(15), AiTier.top);
    expect(OpenRouterCatalog.tierOf(14.99), AiTier.intermediate);
    expect(OpenRouterCatalog.tierOf(4), AiTier.intermediate);
    expect(OpenRouterCatalog.tierOf(3.99), AiTier.fast);
    expect(OpenRouterCatalog.tierOf(0), AiTier.fast);
    expect(OpenRouterCatalog.tierOf(0, router: true), AiTier.intermediate);
    final differ = {
      for (final m in AiModel.all)
        if (OpenRouterCatalog.tierOf(m.output, router: !m.priced) != m.tier) m.id,
    };
    expect(differ, {'grok-4.7', 'gpt-6.1-terra', 'x-ai/grok-4.7', 'openai/gpt-6.1-terra'});
  });

  test('the user\'s list: kept in the preferences, registered again at start, models removed, fixed ones never duplicated', () {
    final prefs = <String, String>{};
    void setPref(String k, String v) => prefs[k] = v;
    final glm = entry('z-ai/glm-5.3'), gemma = entry('google/gemma-4-31b-it:free'), sol = entry('openai/gpt-6.1-sol');
    expect(OpenRouterCatalog.add(glm, setPref), same(AiModel.find('z-ai/glm-5.3')));
    OpenRouterCatalog.add(gemma, setPref);
    expect(OpenRouterCatalog.add(entry('anthropic/claude-opus-5.5'), setPref), AiModel.orOpus55, reason: 'already one of the app\'s models');
    OpenRouterCatalog.add(sol, setPref);
    expect(OpenRouterCatalog.added.map((m) => m.id), ['z-ai/glm-5.3', 'google/gemma-4-31b-it:free']);
    expect(AiModel.offered(AiProvider.openrouter).last.id, 'google/gemma-4-31b-it:free');
    final text = prefs[OpenRouterCatalog.prefKey]!;
    expect(text.length, lessThan(600), reason: 'compact');
    // a new start: nothing registered, the list read back
    AiModel.unregister();
    expect(AiModel.find('z-ai/glm-5.3'), isNull);
    final back = OpenRouterCatalog.restore((k) => prefs[k]);
    expect(back.map((m) => m.id), ['z-ai/glm-5.3', 'google/gemma-4-31b-it:free']);
    for (final (a, b) in [(glm.model, back[0]), (gemma.model, back[1])]) {
      expect(b.label, a.label);
      expect(b.tier, a.tier);
      expect([b.input, b.output, b.cacheRead, b.cacheWrite], [a.input, a.output, a.cacheRead, a.cacheWrite]);
      expect([b.longAbove, b.longInput, b.longOutput, b.maxOutput], [a.longAbove, a.longInput, a.longOutput, a.maxOutput]);
      expect(b.efforts, a.efforts);
      expect([b.freeTier, b.vision, b.tools, b.priced, b.compaction], [a.freeTier, a.vision, a.tools, a.priced, false]);
      expect(AiModel.find(a.id), same(b));
    }
    expect(OpenRouterCatalog.readsFiles('google/gemma-4-31b-it:free'), isFalse);
    // a long-prompt rule survives the trip
    final haiku = OpenRouterCatalog.decode(OpenRouterCatalog.encode([entry('anthropic/claude-haiku-5.5').model])).single;
    expect([haiku.longAbove, haiku.longInput, haiku.longOutput], [100000, 5, 5]);
    final router = OpenRouterCatalog.decode(OpenRouterCatalog.encode([entry('openrouter/auto').model])).single;
    expect(router.priced, isFalse);
    OpenRouterCatalog.remove('z-ai/glm-5.3', setPref);
    expect(AiModel.find('z-ai/glm-5.3'), isNull);
    expect(OpenRouterCatalog.decode(prefs[OpenRouterCatalog.prefKey]).map((m) => m.id), ['google/gemma-4-31b-it:free']);
    // nothing kept, or a broken text: an empty list, never an exception
    expect(OpenRouterCatalog.restore((_) => null), isEmpty);
    expect(OpenRouterCatalog.decode('{not json'), isEmpty);
    expect(OpenRouterCatalog.decode('{"v":1,"m":[{"l":"no id"},{"i":"x/y","p":["a"]}]}').single.id, 'x/y');
  });

  test('PDFs: read by the model where the list says so (or its maker does), by OpenRouter\'s parser for free models', () {
    expect(OpenRouterCatalog.readsFiles('anthropic/claude-sonnet-5.5'), isTrue);
    expect(OpenRouterCatalog.readsFiles('openrouter/free'), isFalse);
    expect(OpenRouterCatalog.readsFiles('meta-llama/llama-9:free'), isFalse);
    expect(OpenRouterCatalog.readsFiles('unknown/model'), isFalse);
    entries();
    expect(OpenRouterCatalog.readsFiles('writer/palmyra-x5'), isFalse);
    expect(OpenRouterCatalog.readsFiles('anthropic/claude-haiku-5.5'), isTrue);
  });

  group('the download', () {
    test('a plain GET of the public list, no key and no header', () async {
      Uri? asked;
      Map<String, String>? headers;
      final list = await OpenRouterCatalog.load((u, h) async {
        asked = u;
        headers = h;
        return sample;
      });
      expect(asked.toString(), 'https://openrouter.ai/api/v1/models');
      expect(headers, isEmpty);
      expect(list.entries, hasLength(12));
      expect(list.copyOf, isNull);
    });

    test('its failures: no connection, no answer in time, an HTTP status, a body that is not the list', () async {
      Future<OpenRouterCatalogError> failure(CatalogFetch f) async {
        try {
          await OpenRouterCatalog.load(f, timeout: const Duration(milliseconds: 50));
        } on OpenRouterCatalogError catch (e) {
          return e;
        }
        fail('no error');
      }

      expect((await failure((u, h) async => throw const SocketException('down'))).failure, CatalogFailure.network);
      expect((await failure((u, h) => Completer<String>().future)).failure, CatalogFailure.timeout);
      final status = await failure((u, h) async => throw const OpenRouterCatalogError(CatalogFailure.status, status: 503));
      expect(status.status, 503);
      expect('$status', 'OpenRouter answered 503');
      expect((await failure((u, h) async => '<html>maintenance</html>')).failure, CatalogFailure.format);
      expect((await failure((u, h) async => '{"error":{"code":500}}')).failure, CatalogFailure.format);
    });

    test('kept on success; when the download fails, the kept copy with its day; neither: the error', () async {
      String? stored;
      final day = DateTime.utc(2026, 11, 8);
      final ok = await OpenRouterCatalog.load((u, h) async => sample, keep: (b) async => stored = b, kept: () async => null);
      expect(ok.entries, hasLength(12));
      expect(stored, sample);
      final offline = await OpenRouterCatalog.load((u, h) async => throw const SocketException('offline'), kept: () async => (stored!, day));
      expect(offline.entries, hasLength(12));
      expect(offline.copyOf, day);
      expect(offline.error, isA<OpenRouterCatalogError>());
      // a store that fails to keep does not lose the list
      final still = await OpenRouterCatalog.load((u, h) async => sample, keep: (b) async => throw StateError('quota'));
      expect(still.entries, hasLength(12));
      // a broken copy: the download's own error
      await expectLater(
        OpenRouterCatalog.load((u, h) async => throw const SocketException('offline'), kept: () async => ('garbage', day)),
        throwsA(isA<OpenRouterCatalogError>().having((e) => e.failure, 'failure', CatalogFailure.network)),
      );
      // a list the app cannot read is not kept
      stored = null;
      await expectLater(OpenRouterCatalog.load((u, h) async => 'garbage', keep: (b) async => stored = b), throwsA(isA<OpenRouterCatalogError>()));
      expect(stored, isNull);
    });
  });
}
