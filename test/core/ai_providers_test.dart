// The six AI providers and their model table (1.7.0): which company a key
// belongs to, the models of each company with their list prices, the
// introductory prices that end on a date, the efforts a model takes, the
// models added while the app runs, and the clients built on the Responses
// API pointing at their own hosts.

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/ai/claude_api.dart';
import 'package:opencadirrigation/core/ai/gemini_api.dart';
import 'package:opencadirrigation/core/ai/meta_api.dart';
import 'package:opencadirrigation/core/ai/openai_api.dart';
import 'package:opencadirrigation/core/ai/openrouter_api.dart';
import 'package:opencadirrigation/core/ai/xai_api.dart';

Future<AiHttpResponse> _never(AiHttpRequest r, AiCancel c) async => throw AiError(AiErrorKind.network);

void main() {
  tearDown(() {
    AiModel.clock = DateTime.now;
    AiModel.unregister();
  });

  test('a key tells its company by how it starts, the longest start first', () {
    expect(AiProvider.ofKey('sk-ant-api03-xxxx'), AiProvider.anthropic);
    expect(AiProvider.ofKey('sk-or-v1-xxxx'), AiProvider.openrouter);
    expect(AiProvider.ofKey('sk-proj-xxxx'), AiProvider.openai);
    expect(AiProvider.ofKey('xai-xxxx'), AiProvider.xai);
    expect(AiProvider.ofKey('AIzaSyXXXX'), AiProvider.google);
    expect(AiProvider.ofKey('LLM_1607358788850350_xxxx'), AiProvider.meta, reason: 'Meta documents this start');
    expect(AiProvider.ofKey('something-else'), isNull);
  });

  test('every company has its own host, a place to make keys, and a top and a fast model', () {
    expect(AiProvider.values.map((p) => p.host).toSet().length, AiProvider.values.length, reason: 'a key goes to one host only');
    for (final p in AiProvider.values) {
      expect(Uri.parse(p.keysUrl).scheme, 'https', reason: p.name);
      expect(Uri.parse(p.billingUrl).scheme, 'https', reason: p.name);
      final offered = AiModel.offered(p);
      expect(offered, isNotEmpty, reason: p.name);
      expect(offered.map((m) => m.tier).toSet(), containsAll([AiTier.top, AiTier.fast]), reason: p.name);
    }
    expect(AiModel.all.map((m) => m.id).toSet().length, AiModel.all.length, reason: 'ids are unique across the companies');
    expect(AiModel.standard, AiModel.opus55);
  });

  test('list prices of the new companies, with their long-prompt rules', () {
    const million = AiUsage(input: 1000000, output: 1000000);
    AiModel.clock = () => DateTime.utc(2027, 6, 1);
    expect(million.cost(AiModel.gemini4Argon), closeTo(4 + 20, 1e-9), reason: 'no long-prompt rule');
    expect(million.cost(AiModel.gemini38Flash), closeTo(1.5 + 7.5, 1e-9));
    expect(million.cost(AiModel.gemini35FlashLite), closeTo(0.3 + 2.5, 1e-9));
    expect(million.cost(AiModel.grok47), closeTo((2 + 6) * 2, 1e-9), reason: 'a prompt of 200K tokens or more pays twice');
    expect(const AiUsage(input: 100000, output: 1000).cost(AiModel.grok47), closeTo((100000 * 2 + 1000 * 6) / 1e6, 1e-12));
    expect(const AiUsage(input: 200000).cost(AiModel.grok47), closeTo(200000 * 2 * 2 / 1e6, 1e-12), reason: 'the step is at a prompt that reaches 200K');
    expect(const AiUsage(input: 199999).cost(AiModel.grok47), closeTo(199999 * 2 / 1e6, 1e-12));
    expect(million.cost(AiModel.museWonder), closeTo(24, 1e-9));
    expect(million.cost(AiModel.museSpark), closeTo(1.25 + 4.25, 1e-9));
    expect(million.cost(AiModel.museEmber), closeTo((0.1 + 0.5) * 3, 1e-9), reason: 'over 200K input tokens Muse Ember costs three times as much');
    expect(const AiUsage(cacheRead: 1000000).cost(AiModel.museEmber), closeTo(0.004 * 3, 1e-9));
    expect(million.cost(AiModel.orFable52), million.cost(AiModel.fable52), reason: 'OpenRouter charges the maker\'s price');
    // OpenRouter lists the makers' long-prompt prices too
    for (final (or, own) in [(AiModel.orGpt6Astra, AiModel.gpt6Astra), (AiModel.orGpt61Sol, AiModel.gpt61Sol), (AiModel.orGpt61Terra, AiModel.gpt61Terra), (AiModel.orHaiku55, AiModel.haiku55)]) {
      expect(million.cost(or), closeTo(million.cost(own), 1e-9), reason: or.id);
      expect(or.longAbove, own.longAbove, reason: or.id);
    }
  });

  test('where keys and billing are, and the largest answers', () {
    expect(AiProvider.google.billingUrl, 'https://aistudio.google.com/billing');
    expect(AiProvider.meta.keysUrl, 'https://dev.meta.ai/api-keys');
    expect(AiProvider.meta.billingUrl, 'https://dev.meta.ai/billing');
    expect(AiModel.museSpark.maxOutput, 131072);
    expect(AiModel.museEmber.maxOutput, 131072);
    expect(AiModel.museWonder.maxOutput, 64000, reason: 'Meta documents none: the default');
    // OpenRouter holds the price of the largest answer allowed while a request runs: kept near US$ 1.30
    for (final m in AiModel.offered(AiProvider.openrouter)) {
      expect(m.maxOutput * m.output / 1e6, lessThanOrEqualTo(1.61), reason: m.id);
    }
    expect(AiModel.orFable52.maxOutput, 32000);
    expect(AiModel.orOpus55.maxOutput, 64000);
    expect(AiModel.orSonnet55.maxOutput, 128000);
  });

  test('what the provider says it charged prices only an answer the table cannot price', () {
    AiReply reply(String model, AiUsage usage) => AiReply(items: const [], text: 'x', calls: const [], stop: AiStop.end, model: model, usage: usage);
    const u = AiUsage(input: 1000000, output: 100000, charged: 0.42);
    // a router's pick that is not offered here: OpenRouter's figure
    expect(reply('deepseek/unknown-model', u).cost(AiModel.orAuto), 0.42);
    // one the table knows: the table's list prices, as for every other answer
    expect(reply('anthropic/claude-sonnet-5.5', u).cost(AiModel.orAuto), closeTo(2 + 1, 1e-9));
    expect(reply('anthropic/claude-sonnet-5.5', u).cost(AiModel.orSonnet55), closeTo(2 + 1, 1e-9));
    // nothing said: nothing known (the settings say the meter cannot price a router's unknown pick)
    expect(reply('deepseek/unknown-model', const AiUsage(input: 1000000)).cost(AiModel.orAuto), 0);
    // summed over the requests of a task; absent stays absent
    expect((u + const AiUsage(input: 5, charged: 0.08)).charged, closeTo(0.5, 1e-12));
    expect((u + const AiUsage(input: 5)).charged, 0.42);
    expect((const AiUsage(input: 5) + const AiUsage(output: 5)).charged, isNull);
    expect(u.withCharged(null).charged, isNull);
    expect(u.withCharged(1).input, 1000000);
  });

  test('an introductory price halves every price until its last day, and the settings say when it ends', () {
    const u = AiUsage(input: 1000000, output: 1000000, cacheRead: 1000000);
    AiModel.clock = () => DateTime.utc(2026, 11, 30, 23, 59);
    expect(AiModel.gemini4Argon.priceFactor, 0.5);
    expect(u.cost(AiModel.gemini4Argon), closeTo(2 + 10 + 0.1, 1e-9));
    expect(AiModel.gemini4Argon.priceText, '2 / 10');
    expect(AiModel.gemini4Argon.introEnds, DateTime.utc(2026, 12, 1));
    AiModel.clock = () => DateTime.utc(2026, 12, 1);
    expect(AiModel.gemini4Argon.priceFactor, 1);
    expect(u.cost(AiModel.gemini4Argon), closeTo(4 + 20 + 0.2, 1e-9));
    expect(AiModel.gemini4Argon.priceText, '4 / 20');
    expect(AiModel.gemini4Argon.introEnds, isNull);
    expect(AiModel.gemini38Flash.priceFactor, 0.5, reason: 'until the end of 2026');
    AiModel.clock = () => DateTime.utc(2027, 1, 1);
    expect(AiModel.gemini38Flash.priceFactor, 1);
    expect(AiModel.opus55.priceFactor, 1);
    expect(AiModel.opus55.introEnds, isNull);
  });

  test('an effort the model does not take goes as the nearest one below it', () {
    expect(AiModel.opus55.effortFor(AiEffort.max), AiEffort.max);
    expect(AiModel.gemini4Argon.effortFor(AiEffort.max), AiEffort.high);
    expect(AiModel.gemini4Argon.effortFor(AiEffort.xhigh), AiEffort.high);
    expect(AiModel.gemini4Argon.effortFor(AiEffort.low), AiEffort.low);
    expect(AiModel.grok47.effortFor(AiEffort.max), AiEffort.xhigh);
    expect(AiModel.grok43.effortFor(AiEffort.max), AiEffort.xhigh);
    expect(AiModel.grok47.pdf, isFalse, reason: 'a PDF goes to Grok as its text');
    const odd = AiModel(AiProvider.openrouter, 'x/odd', 'Odd', AiTier.fast, input: 1, output: 1, cacheRead: 1, cacheWrite: 1, efforts: [AiEffort.high, AiEffort.max]);
    expect(odd.effortFor(AiEffort.low), AiEffort.high, reason: 'nothing below: the lowest it has');
    expect(odd.effortFor(AiEffort.xhigh), AiEffort.high);
  });

  test('models added while the app runs are found, offered after the fixed ones, and never replace a fixed one', () {
    const extra = AiModel(AiProvider.openrouter, 'deepseek/some-model', 'Some Model (OpenRouter)', AiTier.fast, input: 0.2, output: 0.8, cacheRead: 0.02, cacheWrite: 0.2);
    expect(AiModel.find('deepseek/some-model'), isNull);
    expect(AiModel.byId('deepseek/some-model'), AiModel.standard);
    AiModel.register(extra);
    expect(AiModel.byId('deepseek/some-model'), extra);
    expect(AiModel.offered(AiProvider.openrouter).last, extra);
    expect(AiModel.served('deepseek/some-model', AiModel.orAuto), extra, reason: 'what a router chose is priced as that model');
    const again = AiModel(AiProvider.openrouter, 'deepseek/some-model', 'Some Model (OpenRouter)', AiTier.fast, input: 0.3, output: 0.9, cacheRead: 0.03, cacheWrite: 0.3);
    AiModel.register(again);
    expect(AiModel.registered.length, 1);
    expect(AiModel.byId('deepseek/some-model').input, 0.3);
    AiModel.register(const AiModel(AiProvider.openrouter, 'anthropic/claude-opus-5.5', 'Impostor', AiTier.fast, input: 0, output: 0, cacheRead: 0, cacheWrite: 0));
    expect(AiModel.byId('anthropic/claude-opus-5.5'), AiModel.orOpus55);
    AiModel.unregister('deepseek/some-model');
    expect(AiModel.find('deepseek/some-model'), isNull);
  });

  test('each client speaks to its own company', () {
    final clients = <AiHttpClient>[
      AnthropicClient(apiKey: 'k', transport: _never),
      OpenAiClient(apiKey: 'k', transport: _never),
      GeminiClient(apiKey: 'k', transport: _never),
      XaiClient(apiKey: 'k', transport: _never),
      MetaClient(apiKey: 'k', transport: _never),
      OpenRouterClient(apiKey: 'k', transport: _never),
    ];
    expect(clients.map((c) => c.provider), AiProvider.values);
    expect(OpenAiClient(apiKey: 'k', transport: _never).url.host, AiProvider.openai.host);
    expect(XaiClient(apiKey: 'k', transport: _never).url.host, AiProvider.xai.host);
    expect(MetaClient(apiKey: 'k', transport: _never).url.host, AiProvider.meta.host);
    expect(OpenRouterClient(apiKey: 'k', transport: _never).url.host, AiProvider.openrouter.host);
  });
}
