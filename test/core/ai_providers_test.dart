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
    expect(AiProvider.ofKey('something-else'), isNull);
    expect(AiProvider.meta.keyPrefix, isEmpty, reason: 'Meta keys have no fixed start: never guessed');
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
