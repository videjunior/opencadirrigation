/// What the AI assistant needs from a model provider, whoever it is: the
/// models offered (with their tier and list prices), tokens and cost,
/// errors, cancellation, the HTTP exchange (injected: fetch in the browser,
/// HttpClient on the desktop, a scripted fake in tests), the parts of a
/// message, and the client each provider implements — Anthropic's Messages
/// API ([AnthropicClient]), OpenAI's Responses API ([OpenAiClient]) and the
/// Responses APIs of xAI, Meta and OpenRouter built on it, and Google's
/// Gemini API ([GeminiClient]).
///
/// Pure Dart. Each provider gets its own key, sent only to its own host.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

/// The companies whose models the assistant can use, each called directly
/// with the user's own key. [openrouter] is a marketplace: one key reaches
/// the models of the others, and many more, through its own servers.
enum AiProvider {
  anthropic('Anthropic', 'Claude', 'api.anthropic.com', 'https://console.anthropic.com/settings/keys', 'sk-ant-', 'https://platform.claude.com/settings/billing'),
  openai('OpenAI', 'GPT', 'api.openai.com', 'https://platform.openai.com/api-keys', 'sk-', 'https://platform.openai.com/settings/organization/billing/overview'),
  google('Google', 'Gemini', 'generativelanguage.googleapis.com', 'https://aistudio.google.com/apikey', 'AIza', 'https://aistudio.google.com/usage'),
  xai('xAI', 'Grok', 'api.x.ai', 'https://console.x.ai/', 'xai-', 'https://console.x.ai/'),
  meta('Meta', 'Muse', 'api.meta.ai', 'https://dev.meta.ai/', '', 'https://dev.meta.ai/'),
  openrouter('OpenRouter', 'OpenRouter', 'openrouter.ai', 'https://openrouter.ai/settings/keys', 'sk-or-', 'https://openrouter.ai/settings/credits');

  const AiProvider(this.company, this.family, this.host, this.keysUrl, this.keyPrefix, this.billingUrl);
  final String company;

  /// The name its models go by (Claude, GPT, Gemini, Grok, Muse).
  final String family;

  /// The only host this provider's key is ever sent to.
  final String host;

  /// Where the user creates a key.
  final String keysUrl;

  /// How the provider's keys usually start (a hint, never enforced; empty
  /// when its keys have no fixed start).
  final String keyPrefix;

  /// Where the account's credit and spending limits are managed.
  final String billingUrl;

  /// The provider whose keys start as [key] does, by the longest known start
  /// (`sk-ant-` and `sk-or-` before `sk-`); null when none does.
  static AiProvider? ofKey(String key) {
    AiProvider? best;
    for (final p in values) {
      if (p.keyPrefix.isEmpty || !key.startsWith(p.keyPrefix)) continue;
      if (best == null || p.keyPrefix.length > best.keyPrefix.length) best = p;
    }
    return best;
  }
}

/// Place of a model in its provider's range.
enum AiTier { top, intermediate, fast }

/// How much the model reasons before answering (Anthropic
/// `output_config.effort` and OpenAI `reasoning.effort`, which take all
/// five; the other providers take some of them, see [AiModel.efforts]).
enum AiEffort { low, medium, high, xhigh, max }

/// A model the user can choose. Prices are list prices in US$ per million
/// tokens, from each provider's pricing page; the meter shows estimates.
class AiModel {
  const AiModel(
    this.provider,
    this.id,
    this.label,
    this.tier, {
    required this.input,
    required this.output,
    required this.cacheRead,
    required this.cacheWrite,
    this.longAbove = 0,
    this.longInput = 1,
    this.longOutput = 1,
    this.serverFallback = false,
    this.alwaysThinks = false,
    this.longTurns = false,
    this.earlier = false,
    this.needsRetention = false,
    this.taskBudget = false,
    this.compaction = true,
    this.listed = true,
    this.maxOutput = 64000,
    this.progressUpdates = false,
    this.highResVision = false,
    this.perMessageEffort = false,
    this.efforts = AiEffort.values,
    this.freeTier = false,
    this.introUntil = 0,
    this.introFactor = 1,
    this.vision = true,
    this.tools = true,
    this.priced = true,
  });

  final AiProvider provider;
  final String id;
  final String label;
  final AiTier tier;
  final double input, output, cacheRead, cacheWrite;

  /// The efforts the model takes; another one goes as the nearest it does
  /// ([effortFor]).
  final List<AiEffort> efforts;

  /// The provider serves it free of charge within limits of its own (the
  /// prices here are those of its paid use).
  final bool freeTier;

  /// An introductory price: until the day [introUntil] (a date as the number
  /// yyyymmdd, UTC; 0: none) every price is [introFactor] × the one here.
  final int introUntil;
  final double introFactor;

  /// Reads pictures (the views of the drawing and the map).
  final bool vision;

  /// Calls tools (without them the assistant can only talk).
  final bool tools;

  /// The prices are known (false: a router that picks the model, billed at
  /// that model's prices; the meter then shows no cost for it).
  final bool priced;

  /// The clock of the introductory prices (tests set it).
  static DateTime Function() clock = DateTime.now;

  /// What the prices are multiplied by today ([introFactor] while the
  /// introductory price lasts).
  double get priceFactor {
    if (introUntil <= 0) return 1;
    final d = clock().toUtc();
    return d.year * 10000 + d.month * 100 + d.day < introUntil ? introFactor : 1;
  }

  /// The day the introductory price ends, or null when there is none now.
  DateTime? get introEnds => priceFactor == 1 ? null : DateTime.utc(introUntil ~/ 10000, introUntil ~/ 100 % 100, introUntil % 100);

  /// [e], or the nearest effort the model takes: the highest one below it,
  /// else the lowest it has.
  AiEffort effortFor(AiEffort e) {
    if (efforts.isEmpty || efforts.contains(e)) return e;
    final below = efforts.where((x) => x.index < e.index);
    return below.isNotEmpty ? below.reduce((a, b) => a.index > b.index ? a : b) : efforts.reduce((a, b) => a.index < b.index ? a : b);
  }

  /// Prompts above [longAbove] input tokens bill input and cache at
  /// [longInput] × and output at [longOutput] × (0: no such rule).
  final int longAbove;
  final double longInput, longOutput;

  /// Anthropic: takes `fallbacks: "default"` (a request a safety classifier
  /// declines is re-run on the model Anthropic recommends).
  final bool serverFallback;

  /// Anthropic: thinking is always on and takes no `thinking` setting.
  final bool alwaysThinks;

  /// One request may think for many minutes (longer timeouts).
  final bool longTurns;

  /// An earlier release still offered by the provider.
  final bool earlier;

  /// Needs an organisation with 30-day data retention (not available under
  /// zero data retention).
  final bool needsRetention;

  /// Anthropic: takes a task budget (`output_config.task_budget`, beta), a
  /// token allowance for a whole task the model paces itself against.
  final bool taskBudget;

  /// Summarises older turns on the server when the conversation grows long
  /// (Anthropic threshold compaction, OpenAI `context_management`).
  final bool compaction;

  /// Offered in the settings (false: only priced, e.g. a fallback model).
  final bool listed;

  /// Output tokens one answer may take (`max_tokens`; thinking counts in
  /// it). Requests stream, which answers this long need.
  final int maxOutput;

  /// Anthropic: between tool calls the model writes short notes on its
  /// progress as thinking blocks, which come back as text with
  /// `thinking.display: "updates"` (beta) instead of empty.
  final bool progressUpdates;

  /// Anthropic: reads a picture of up to 2576 px on its long edge and 4784
  /// visual tokens (about 3.75 megapixels) as it is, its coordinates one to
  /// one with the pixels; the others get pictures that fit the older limit
  /// (1568 px, about 1.15 megapixels), which every provider reads unscaled.
  final bool highResVision;

  /// Anthropic: the effort can change from one message to the next through
  /// an effort-only system message in the conversation (beta), which keeps
  /// the cached conversation; changing the request's own effort rewrites it.
  final bool perMessageEffort;

  /// US$ per million tokens written to the one-hour cache (Anthropic: twice
  /// the input price; the five-minute cache costs [cacheWrite]).
  double get cacheWriteHour => input * 2;

  /// Input tokens above which the server summarises the older turns: below
  /// the price step of [longAbove] when the model has one (every request
  /// past it would cost [longInput] × as much), otherwise 150 000 (Anthropic)
  /// or 200 000 (OpenAI).
  int get compactAt {
    final base = provider == AiProvider.anthropic ? 150000 : 200000;
    return longAbove > 0 && longAbove - 10000 < base ? longAbove - 10000 : base;
  }

  // Anthropic (Claude API list prices; cache writes 1.25 × input for the
  // five-minute cache, 2 × for the one-hour cache).
  static const fable52 = AiModel(
    AiProvider.anthropic,
    'claude-fable-5-2',
    'Claude Fable 5.2',
    AiTier.top,
    input: 8,
    output: 40,
    cacheRead: 0.2,
    cacheWrite: 10,
    serverFallback: true,
    alwaysThinks: true,
    longTurns: true,
    needsRetention: true,
    taskBudget: true,
    maxOutput: 128000,
    perMessageEffort: true,
    progressUpdates: true,
    highResVision: true,
  );
  static const opus55 = AiModel(
    AiProvider.anthropic,
    'claude-opus-5-5',
    'Claude Opus 5.5',
    AiTier.top,
    input: 4,
    output: 20,
    cacheRead: 0.2,
    cacheWrite: 5,
    serverFallback: true,
    taskBudget: true,
    maxOutput: 128000,
    perMessageEffort: true,
    progressUpdates: true,
    highResVision: true,
  );
  static const sonnet55 = AiModel(
    AiProvider.anthropic,
    'claude-sonnet-5-5',
    'Claude Sonnet 5.5',
    AiTier.intermediate,
    input: 2,
    output: 10,
    cacheRead: 0.1,
    cacheWrite: 2.5,
    serverFallback: true,
    taskBudget: true,
    maxOutput: 128000,
    perMessageEffort: true,
    progressUpdates: true,
    highResVision: true,
  );
  static const haiku55 = AiModel(
    AiProvider.anthropic,
    'claude-haiku-5-5',
    'Claude Haiku 5.5',
    AiTier.fast,
    input: 0.1,
    output: 0.5,
    cacheRead: 0.01,
    cacheWrite: 0.125,
    longAbove: 100000,
    longInput: 5,
    longOutput: 5,
    taskBudget: true,
    maxOutput: 128000,
    perMessageEffort: true,
    highResVision: true,
  );

  // Claude models that are priced only: the one Claude Fable 5.2 replaced
  // (a choice or a conversation of it goes on with Claude Fable 5.2, which
  // reads its thinking) and those a refused request may fall back to on the
  // server.
  static const _fable51 = AiModel(AiProvider.anthropic, 'claude-fable-5-1', 'Claude Fable 5.1', AiTier.top, input: 10, output: 50, cacheRead: 0.25, cacheWrite: 12.5, listed: false);
  static const _opus5 = AiModel(AiProvider.anthropic, 'claude-opus-5', 'Claude Opus 5', AiTier.top, input: 5, output: 25, cacheRead: 0.5, cacheWrite: 6.25, listed: false);
  static const _opus48 = AiModel(AiProvider.anthropic, 'claude-opus-4-8', 'Claude Opus 4.8', AiTier.top, input: 5, output: 25, cacheRead: 0.5, cacheWrite: 6.25, listed: false);

  // OpenAI (developers.openai.com model pages and pricing, Standard tier;
  // prompts over 272K input tokens: 2 × input and cache, 1.5 × output).
  static const gpt6Astra = AiModel(
    AiProvider.openai,
    'gpt-6-astra',
    'GPT-6 Astra',
    AiTier.top,
    input: 10,
    output: 50,
    cacheRead: 1,
    cacheWrite: 12.5,
    longAbove: 272000,
    longInput: 2,
    longOutput: 1.5,
    longTurns: true,
    maxOutput: 128000,
  );
  static const gpt61Sol = AiModel(
    AiProvider.openai,
    'gpt-6.1-sol',
    'GPT-6.1 Sol',
    AiTier.intermediate,
    input: 2,
    output: 10,
    cacheRead: 0.1,
    cacheWrite: 2.5,
    longAbove: 272000,
    longInput: 2,
    longOutput: 1.5,
    maxOutput: 128000,
  );
  static const gpt61Terra = AiModel(
    AiProvider.openai,
    'gpt-6.1-terra',
    'GPT-6.1 Terra',
    AiTier.fast,
    input: 1,
    output: 5,
    cacheRead: 0.05,
    cacheWrite: 1.25,
    longAbove: 272000,
    longInput: 2,
    longOutput: 1.5,
    maxOutput: 128000,
  );
  static const gpt6Luna = AiModel(
    AiProvider.openai,
    'gpt-6-luna',
    'GPT-6 Luna',
    AiTier.fast,
    input: 0.1,
    output: 0.5,
    cacheRead: 0.01,
    cacheWrite: 0.125,
    longAbove: 272000,
    longInput: 2,
    longOutput: 1.5,
    maxOutput: 128000,
  );
  static const gpt6Sol = AiModel(
    AiProvider.openai,
    'gpt-6-sol',
    'GPT-6 Sol',
    AiTier.intermediate,
    input: 2,
    output: 10,
    cacheRead: 0.2,
    cacheWrite: 2.5,
    longAbove: 272000,
    longInput: 2,
    longOutput: 1.5,
    earlier: true,
    maxOutput: 128000,
  );
  static const gpt56Terra = AiModel(
    AiProvider.openai,
    'gpt-5.6-terra',
    'GPT-5.6 Terra',
    AiTier.intermediate,
    input: 2,
    output: 12,
    cacheRead: 0.2,
    cacheWrite: 2.5,
    longAbove: 272000,
    longInput: 2,
    longOutput: 1.5,
    earlier: true,
    maxOutput: 128000,
  );

  // Google (Gemini API pricing page, paid tier; caching is implicit, so a
  // prompt written to the cache pays the input price). Gemini 4 Argon and
  // Gemini 3.8 Flash cost half of these prices until the dates below; the
  // two Flash models have a free tier with limits, on which Google may use
  // the content to improve its products.
  static const gemini4Argon = AiModel(
    AiProvider.google,
    'gemini-4-argon',
    'Gemini 4 Argon',
    AiTier.top,
    input: 4,
    output: 20,
    cacheRead: 0.2,
    cacheWrite: 4,
    introUntil: 20261201,
    introFactor: 0.5,
    longTurns: true,
    maxOutput: 65536,
    compaction: false,
    efforts: [AiEffort.low, AiEffort.medium, AiEffort.high],
  );
  static const gemini38Flash = AiModel(
    AiProvider.google,
    'gemini-3.8-flash',
    'Gemini 3.8 Flash',
    AiTier.intermediate,
    input: 1.5,
    output: 7.5,
    cacheRead: 0.15,
    cacheWrite: 1.5,
    introUntil: 20270101,
    introFactor: 0.5,
    freeTier: true,
    maxOutput: 65536,
    compaction: false,
    efforts: [AiEffort.low, AiEffort.medium, AiEffort.high],
  );
  static const gemini35FlashLite = AiModel(
    AiProvider.google,
    'gemini-3.5-flash-lite',
    'Gemini 3.5 Flash-Lite',
    AiTier.fast,
    input: 0.3,
    output: 2.5,
    cacheRead: 0.03,
    cacheWrite: 0.3,
    freeTier: true,
    maxOutput: 65536,
    compaction: false,
    efforts: [AiEffort.low, AiEffort.medium, AiEffort.high],
  );

  // xAI (docs.x.ai models page; a prompt of 200K tokens or more pays twice
  // these prices; caching is automatic, with no price for the writing).
  static const grok47 = AiModel(
    AiProvider.xai,
    'grok-4.7',
    'Grok 4.7',
    AiTier.top,
    input: 2,
    output: 6,
    cacheRead: 0.5,
    cacheWrite: 2,
    longAbove: 200000,
    longInput: 2,
    longOutput: 2,
    compaction: false,
    efforts: [AiEffort.low, AiEffort.medium, AiEffort.high, AiEffort.xhigh],
  );
  static const grok43 = AiModel(
    AiProvider.xai,
    'grok-4.3',
    'Grok 4.3',
    AiTier.fast,
    input: 1.25,
    output: 2.5,
    cacheRead: 0.2,
    cacheWrite: 1.25,
    longAbove: 200000,
    longInput: 2,
    longOutput: 2,
    compaction: false,
    efforts: [AiEffort.low, AiEffort.medium, AiEffort.high],
  );

  // Meta (Meta Model API pricing page, Standard mode: the content is not
  // used to train models; caching is automatic). Muse Ember costs three
  // times these prices when the request has more than 200K input tokens.
  static const museWonder = AiModel(AiProvider.meta, 'muse-wonder-1.0', 'Muse Wonder', AiTier.top, input: 4, output: 20, cacheRead: 0.2, cacheWrite: 4, longTurns: true, compaction: false);
  static const museSpark = AiModel(AiProvider.meta, 'muse-spark-1.3', 'Muse Spark 1.3', AiTier.intermediate, input: 1.25, output: 4.25, cacheRead: 0.15, cacheWrite: 1.25, compaction: false);
  static const museEmber = AiModel(
    AiProvider.meta,
    'muse-ember-1.0',
    'Muse Ember',
    AiTier.fast,
    input: 0.1,
    output: 0.5,
    cacheRead: 0.004,
    cacheWrite: 0.1,
    longAbove: 200000,
    longInput: 3,
    longOutput: 3,
    compaction: false,
  );

  // OpenRouter (its models list, `GET /api/v1/models`: the prices of the
  // models' makers, charged to the OpenRouter account). These are the ones
  // offered before the list is downloaded; any other model of the list that
  // calls tools can be added ([register]). The two routers pick a model
  // themselves and are billed at that model's prices.
  static const orFable52 = AiModel(
    AiProvider.openrouter,
    'anthropic/claude-fable-5.2',
    'Claude Fable 5.2 (OpenRouter)',
    AiTier.top,
    input: 8,
    output: 40,
    cacheRead: 0.2,
    cacheWrite: 10,
    longTurns: true,
    maxOutput: 128000,
    compaction: false,
  );
  static const orOpus55 = AiModel(
    AiProvider.openrouter,
    'anthropic/claude-opus-5.5',
    'Claude Opus 5.5 (OpenRouter)',
    AiTier.top,
    input: 4,
    output: 20,
    cacheRead: 0.2,
    cacheWrite: 5,
    maxOutput: 128000,
    compaction: false,
  );
  static const orSonnet55 = AiModel(
    AiProvider.openrouter,
    'anthropic/claude-sonnet-5.5',
    'Claude Sonnet 5.5 (OpenRouter)',
    AiTier.intermediate,
    input: 2,
    output: 10,
    cacheRead: 0.1,
    cacheWrite: 2.5,
    maxOutput: 128000,
    compaction: false,
  );
  static const orHaiku55 = AiModel(
    AiProvider.openrouter,
    'anthropic/claude-haiku-5.5',
    'Claude Haiku 5.5 (OpenRouter)',
    AiTier.fast,
    input: 0.1,
    output: 0.5,
    cacheRead: 0.01,
    cacheWrite: 0.125,
    maxOutput: 128000,
    compaction: false,
  );
  static const orGpt6Astra = AiModel(
    AiProvider.openrouter,
    'openai/gpt-6-astra',
    'GPT-6 Astra (OpenRouter)',
    AiTier.top,
    input: 10,
    output: 50,
    cacheRead: 1,
    cacheWrite: 12.5,
    longTurns: true,
    maxOutput: 128000,
    compaction: false,
  );
  static const orGpt61Sol = AiModel(
    AiProvider.openrouter,
    'openai/gpt-6.1-sol',
    'GPT-6.1 Sol (OpenRouter)',
    AiTier.intermediate,
    input: 2,
    output: 10,
    cacheRead: 0.1,
    cacheWrite: 2.5,
    maxOutput: 128000,
    compaction: false,
  );
  static const orGpt61Terra = AiModel(
    AiProvider.openrouter,
    'openai/gpt-6.1-terra',
    'GPT-6.1 Terra (OpenRouter)',
    AiTier.fast,
    input: 1,
    output: 5,
    cacheRead: 0.05,
    cacheWrite: 1.25,
    maxOutput: 128000,
    compaction: false,
  );
  static const orGemini4Argon = AiModel(
    AiProvider.openrouter,
    'google/gemini-4-argon',
    'Gemini 4 Argon (OpenRouter)',
    AiTier.top,
    input: 4,
    output: 20,
    cacheRead: 0.2,
    cacheWrite: 4,
    introUntil: 20261201,
    introFactor: 0.5,
    longTurns: true,
    maxOutput: 65536,
    compaction: false,
    efforts: [AiEffort.low, AiEffort.medium, AiEffort.high],
  );
  static const orGemini38Flash = AiModel(
    AiProvider.openrouter,
    'google/gemini-3.8-flash',
    'Gemini 3.8 Flash (OpenRouter)',
    AiTier.intermediate,
    input: 1.65,
    output: 8.25,
    cacheRead: 0.165,
    cacheWrite: 1.65,
    introUntil: 20270101,
    introFactor: 0.5,
    maxOutput: 65536,
    compaction: false,
    efforts: [AiEffort.low, AiEffort.medium, AiEffort.high],
  );
  static const orGrok47 = AiModel(
    AiProvider.openrouter,
    'x-ai/grok-4.7',
    'Grok 4.7 (OpenRouter)',
    AiTier.top,
    input: 2,
    output: 6,
    cacheRead: 0.5,
    cacheWrite: 2,
    longAbove: 200000,
    longInput: 2,
    longOutput: 2,
    compaction: false,
    efforts: [AiEffort.low, AiEffort.medium, AiEffort.high, AiEffort.xhigh],
  );
  static const orMuseSpark = AiModel(
    AiProvider.openrouter,
    'meta/muse-spark-1.3',
    'Muse Spark 1.3 (OpenRouter)',
    AiTier.intermediate,
    input: 1.25,
    output: 4.25,
    cacheRead: 0.15,
    cacheWrite: 1.25,
    compaction: false,
  );
  static const orAuto = AiModel(
    AiProvider.openrouter,
    'openrouter/auto',
    'Auto Router (OpenRouter)',
    AiTier.intermediate,
    input: 0,
    output: 0,
    cacheRead: 0,
    cacheWrite: 0,
    compaction: false,
    priced: false,
  );
  static const orFree = AiModel(
    AiProvider.openrouter,
    'openrouter/free',
    'Free Models Router (OpenRouter)',
    AiTier.fast,
    input: 0,
    output: 0,
    cacheRead: 0,
    cacheWrite: 0,
    compaction: false,
    freeTier: true,
  );

  /// The models offered, by provider and tier.
  static const all = [
    fable52,
    opus55,
    sonnet55,
    haiku55,
    gpt6Astra,
    gpt61Sol,
    gpt61Terra,
    gpt6Luna,
    gpt6Sol,
    gpt56Terra,
    gemini4Argon,
    gemini38Flash,
    gemini35FlashLite,
    grok47,
    grok43,
    museWonder,
    museSpark,
    museEmber,
    orFable52,
    orOpus55,
    orSonnet55,
    orHaiku55,
    orGpt6Astra,
    orGpt61Sol,
    orGpt61Terra,
    orGemini4Argon,
    orGemini38Flash,
    orGrok47,
    orMuseSpark,
    orAuto,
    orFree,
  ];

  /// The model used until the user picks another.
  static const standard = opus55;

  /// Models added while the app runs (those the user picked from a
  /// provider's own list, OpenRouter's above all): found by [byId] and
  /// [served], and offered after the provider's fixed ones.
  static final List<AiModel> _registered = [];

  /// The models added with [register], in the order they were.
  static List<AiModel> get registered => List.unmodifiable(_registered);

  /// Adds [m] to the models offered (replacing an earlier one of the same
  /// id; a model of the fixed list is left as it is).
  static void register(AiModel m) {
    if (all.any((x) => x.id == m.id)) return;
    _registered
      ..removeWhere((x) => x.id == m.id)
      ..add(m);
  }

  /// Forgets the model [id] added with [register] (every one when null).
  static void unregister([String? id]) => id == null ? _registered.clear() : _registered.removeWhere((x) => x.id == id);

  /// The models of [p] offered for choosing: the fixed ones, then those
  /// added with [register].
  static List<AiModel> offered(AiProvider p) => [...all.where((m) => m.provider == p && m.listed), ..._registered.where((m) => m.provider == p)];

  /// The model a choice of an earlier version stands for now.
  static const _successors = {'claude-fable-5-1': fable52};

  /// The model of [id] (a fixed one, one added with [register], or the
  /// successor of one no longer offered); [standard] for an unknown id.
  static AiModel byId(String? id) => find(id) ?? standard;

  /// As [byId], but null for an unknown id.
  static AiModel? find(String? id) => all.where((m) => m.id == id).firstOrNull ?? _registered.where((m) => m.id == id).firstOrNull ?? _successors[id];

  /// The model a reply says served it (a fallback may, and a router's
  /// choice), else [requested].
  static AiModel served(String replyModel, AiModel requested) =>
      [...all, ..._registered, _fable51, _opus5, _opus48].where((m) => replyModel == m.id || replyModel.startsWith('${m.id}-')).firstOrNull ?? requested;

  /// The task budget (tokens) for a spending cap of [usd] US\$. The model
  /// paces what it writes against the budget (thinking, tool calls, text:
  /// output tokens), while the cap also pays for the input of every step
  /// (the conversation read again from the cache, tool results and
  /// pictures written to it), about half of what an agentic task here
  /// spends ([outputShare]). At the output price alone the model would plan
  /// for about twice what the cap allows and be stopped mid-task. Constant
  /// for a given cap, so it does not change the conversation's cached
  /// prefix from one task to the next. The client raises it to the API's
  /// minimum (20 000).
  int taskBudgetFor(double usd, {double outputShare = 0.5}) => (usd * outputShare / output * 1e6).round();

  /// Price per million tokens of input and output today, for the settings.
  String get priceText => '${_usd(input * priceFactor)} / ${_usd(output * priceFactor)}';
  static String _usd(double v) => v < 1 ? v.toStringAsFixed(v < 0.1 ? 3 : 2).replaceFirst(RegExp(r'0$'), '') : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2));

  @override
  String toString() => id;
}

/// Tokens of one or more requests.
class AiUsage {
  const AiUsage({this.input = 0, this.output = 0, this.cacheWrite = 0, this.cacheRead = 0, this.cacheWriteHour = 0});
  static const zero = AiUsage();

  /// Input tokens neither read from nor written to the cache.
  final int input;

  /// [cacheWrite]: tokens written to the five-minute cache; [cacheWriteHour]
  /// to the one-hour cache (Anthropic), priced higher.
  final int output, cacheWrite, cacheRead, cacheWriteHour;

  /// Every input token.
  int get totalInput => input + cacheWrite + cacheWriteHour + cacheRead;

  bool get isZero => totalInput == 0 && output == 0;

  AiUsage operator +(AiUsage o) =>
      AiUsage(input: input + o.input, output: output + o.output, cacheWrite: cacheWrite + o.cacheWrite, cacheRead: cacheRead + o.cacheRead, cacheWriteHour: cacheWriteHour + o.cacheWriteHour);

  /// Estimated cost at [m]'s list prices (US$).
  double cost(AiModel m) {
    final long = m.longAbove > 0 && totalInput > m.longAbove;
    final fi = long ? m.longInput : 1.0, fo = long ? m.longOutput : 1.0;
    return ((input * m.input + cacheWrite * m.cacheWrite + cacheWriteHour * m.cacheWriteHour + cacheRead * m.cacheRead) * fi + output * m.output * fo) * m.priceFactor / 1e6;
  }
}

enum AiErrorKind {
  noKey,
  auth,
  permission,
  billing,

  /// The account has no credit left (or reached its quota).
  credit,

  /// The organisation or workspace reached a spending limit (the tier's
  /// monthly cap or one set in the console): retrying fails until it resets.
  spendLimit,
  notFound,
  invalidRequest,

  /// The request is larger than the API takes (a 413, or found before
  /// sending: [AiError.size]).
  tooLarge,

  /// The conversation no longer fits in the model's context window.
  contextWindow,
  rateLimit,
  overloaded,
  server,
  network,
  timeout,
  interrupted,
  cancelled,
  refusal,
  truncated,
  retention,
  http,

  /// Something failed in this program while it talked to the API.
  unexpected,
}

/// A failed request. [message] is the provider's own text when it gave one
/// (never the key).
class AiError implements Exception {
  AiError(this.kind, {this.status, this.message = '', this.retryAfter, this.requestId, this.category, this.recommendedModel, this.size, this.limit, this.partial = false, this.usage = AiUsage.zero});
  final AiErrorKind kind;

  /// Tokens the provider billed for attempts that did not finish (the input
  /// a streamed answer reported before it broke off, was cancelled or was
  /// tried again): they count in the meter and the spending cap.
  final AiUsage usage;
  final int? status;
  final String message;

  /// Wait the provider asked for (`retry-after`).
  final Duration? retryAfter;

  /// The provider's id of the request (what its support asks for).
  final String? requestId;

  /// Category of a refusal, when given.
  final String? category;

  /// A refusal whose fallback could not run: the model the API suggests
  /// trying instead (`stop_details.recommended_model`).
  final String? recommendedModel;

  /// [AiErrorKind.tooLarge] found before sending: the bytes of the request
  /// and the most this client sends.
  final int? size, limit;

  /// Part of the answer had already arrived.
  final bool partial;

  /// Worth sending again after a wait (when no part of the answer has been
  /// shown yet): a busy or failing service, a lost connection, a timeout.
  bool get retryable => switch (kind) {
    AiErrorKind.rateLimit || AiErrorKind.overloaded || AiErrorKind.server || AiErrorKind.network || AiErrorKind.timeout || AiErrorKind.interrupted => true,
    _ => false,
  };

  /// The API refused what the request carried (an invalid or oversized
  /// request, or one the size check stopped before it left), not the
  /// account or the service: what was added to the conversation since the
  /// last request it accepted has to leave it again.
  bool get refusedContent {
    final s = status;
    return switch (kind) {
      AiErrorKind.invalidRequest || AiErrorKind.tooLarge || AiErrorKind.contextWindow => s == null || (s >= 400 && s < 500),
      AiErrorKind.http => s != null && s >= 400 && s < 500,
      _ => false,
    };
  }

  AiError _copy({bool? partial, String? requestId, AiUsage? usage}) => AiError(
    kind,
    status: status,
    message: message,
    retryAfter: retryAfter,
    requestId: requestId ?? this.requestId,
    category: category,
    recommendedModel: recommendedModel,
    size: size,
    limit: limit,
    partial: partial ?? this.partial,
    usage: usage ?? this.usage,
  );

  AiError withPartial() => _copy(partial: true);

  /// This error with the request's id when it had none.
  AiError withRequestId(String? id) => id == null || requestId != null ? this : _copy(requestId: id);

  /// This error with [u] more billed tokens (see [usage]).
  AiError withUsage(AiUsage u) => u.isZero ? this : _copy(usage: usage + u);

  @override
  String toString() => 'AiError(${kind.name}${status == null ? '' : ', $status'}${message.isEmpty ? '' : ': $message'})';
}

/// Stops a request (and the waits between retries) when the user asks.
class AiCancel {
  bool _cancelled = false;
  final List<void Function()> _hooks = [];
  void Function()? _unlink;
  bool get cancelled => _cancelled;

  /// Runs [f] on cancellation (at once when already cancelled); the
  /// function returned forgets [f].
  void Function() onCancel(void Function() f) {
    if (_cancelled) {
      f();
      return () {};
    }
    _hooks.add(f);
    return () => _hooks.remove(f);
  }

  /// A token cancelled with this one or on its own: one attempt of a
  /// request, which a timeout stops (with its HTTP exchange) while the task
  /// goes on. [release] unlinks it once the attempt is over.
  AiCancel child() {
    final c = AiCancel();
    c._unlink = onCancel(c.cancel);
    return c;
  }

  /// Unlinks a [child] from the token it came from.
  void release() {
    _unlink?.call();
    _unlink = null;
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    final hooks = List.of(_hooks);
    _hooks.clear();
    for (final f in hooks) {
      try {
        f();
      } catch (_) {}
    }
  }
}

class AiHttpRequest {
  const AiHttpRequest(this.url, this.headers, this.body, {this.onSent});
  final Uri url;
  final Map<String, String> headers;
  final String body;

  /// Called by a transport that can tell when the whole body has gone out
  /// (the wait for the answer starts then); others never call it.
  final void Function()? onSent;
}

/// A response whose body may still be arriving. [headers] have lower-case
/// names.
class AiHttpResponse {
  AiHttpResponse(this.status, this.headers, this.body);
  final int status;
  final Map<String, String> headers;
  final Stream<List<int>> body;
}

/// Sends one POST and completes once the status and headers arrived. It
/// should stop the exchange when [cancel] fires (also while the body is
/// still being read) and throw an [AiError] (`network`) when the server
/// cannot be reached.
typedef AiTransport = Future<AiHttpResponse> Function(AiHttpRequest request, AiCancel cancel);

/// Progress of a streamed answer.
class AiStreamListener {
  const AiStreamListener({this.onText, this.onToolStart, this.onActivity, this.onThinking});
  final void Function(String text)? onText;

  /// The model started a tool call ([name]).
  final void Function(String name)? onToolStart;

  /// Anything arrived: the request is alive.
  final void Function()? onActivity;

  /// A note the model writes on its progress between tool calls, the whole
  /// note so far as it grows (Anthropic progress updates; never its
  /// reasoning).
  final void Function(String note)? onThinking;
}

/// A piece of a user message.
sealed class AiPart {
  const AiPart();
}

class AiTextPart extends AiPart {
  const AiTextPart(this.text);
  final String text;
}

class AiImagePart extends AiPart {
  const AiImagePart(this.mediaType, this.base64);
  final String mediaType;
  final String base64;
}

class AiPdfPart extends AiPart {
  const AiPdfPart(this.name, this.base64);
  final String name;
  final String base64;
}

/// An image a tool returns (a view of the drawing, the aerial map).
class ToolImage {
  const ToolImage(this.mediaType, this.base64);
  final String mediaType;
  final String base64;
}

/// What a tool hands back to the model.
class ToolOutput {
  const ToolOutput(this.text, {this.images = const [], this.isError = false, this.spent = AiUsage.zero, this.spentCost = 0, this.spentModel = ''});
  factory ToolOutput.error(String text) => ToolOutput(text, isError: true);
  final String text;
  final List<ToolImage> images;
  final bool isError;

  /// Tokens a tool billed to the task by asking a model of its own (a
  /// cheaper model that read a long attachment for the main one), what they
  /// cost (US$ at list prices) and that model's id: they count in the meter
  /// and in the spending cap like the task's own requests.
  final AiUsage spent;
  final double spentCost;
  final String spentModel;

  /// [text] cut at [maxChars], with a note of what was left out.
  String clipped(int maxChars) => text.length <= maxChars ? text : '${text.substring(0, maxChars)}\n… (${text.length - maxChars} more characters left out: ask for less, e.g. with a filter or paging)';

  /// This output with its text cut at [maxChars].
  ToolOutput clip(int maxChars) => text.length <= maxChars ? this : ToolOutput(clipped(maxChars), images: images, isError: isError, spent: spent, spentCost: spentCost, spentModel: spentModel);
}

/// A tool as every provider describes it.
class AiToolSpec {
  const AiToolSpec(this.name, this.description, this.inputSchema);
  final String name;
  final String description;
  final Map<String, Object?> inputSchema;
}

/// A tool call the model asked for. [invalidRaw] holds the input when it
/// was not valid JSON.
class AiToolCall {
  const AiToolCall(this.id, this.name, this.input, {this.invalidRaw});
  final String id;
  final String name;
  final Map<String, dynamic> input;
  final String? invalidRaw;
}

/// The answer to a tool call.
class AiToolResult {
  const AiToolResult(this.id, this.output);
  final String id;
  final ToolOutput output;
}

/// Why an answer ended: its turn ([end]), tool calls ([tool]), the output
/// limit ([maxTokens]), the context window filled ([contextWindow]), a
/// refusal, or the server paused a long turn of its own ([pause]: the same
/// conversation goes again, without a new message).
enum AiStop { end, tool, maxTokens, contextWindow, refusal, pause }

/// The model's answer to one request.
class AiReply {
  const AiReply({
    required this.items,
    required this.text,
    required this.calls,
    required this.stop,
    required this.model,
    required this.usage,
    this.billed = const [],
    this.category,
    this.explanation = '',
    this.recommendedModel,
    this.compacted = false,
    this.history,
    this.transformations = const [],
    this.requestBytes = 0,
    this.images = 0,
    this.documents = 0,
  });

  /// What the request of this answer carried: the characters of its body
  /// (about its bytes: the JSON is mostly ASCII), and the pictures and the
  /// PDFs in it (every one goes again with each request of the
  /// conversation). 0 when the client did not count them.
  final int requestBytes, images, documents;

  /// What the API did to the request before the model read it (Anthropic
  /// `input_transformations`): thinking blocks it dropped, each with the
  /// position (`path`) and why (`reason`: `prefix_binding_mismatch` — the
  /// conversation before the block changed —, `model_binding_mismatch` — a
  /// block of another model).
  final List<Map<String, dynamic>> transformations;

  /// Thinking blocks dropped because the conversation before them changed
  /// (an edit of the history, which also costs the cache).
  int get prefixDrops => transformations.where((t) => t['type'] == 'thinking_dropped' && t['reason'] == 'prefix_binding_mismatch').length;

  /// What goes back into the history, in the provider's format, unchanged
  /// (Anthropic thinking blocks with their signatures, OpenAI reasoning
  /// items with their encrypted content); empty when the answer said
  /// nothing.
  final List<Map<String, dynamic>> items;
  final String text;
  final List<AiToolCall> calls;
  final AiStop stop;

  /// The model that served the answer.
  final String model;

  /// Tokens of the request, every attempt the server ran included.
  final AiUsage usage;

  /// The attempts the server ran, each with the model that ran it (id) and
  /// its tokens, when they were not all the answer's: a compaction, or an
  /// attempt declined before a fallback model answered. Empty: all of
  /// [usage] is [model]'s.
  final List<(String, AiUsage)> billed;

  /// Category of a refusal.
  final String? category;

  /// Why the model declined, when it said.
  final String explanation;

  /// A refusal whose fallback could not run: the model to try instead.
  final String? recommendedModel;

  /// The server summarised the earlier conversation in this answer.
  final bool compacted;

  /// The history of the request as the client rewrote it to have it
  /// accepted (thinking blocks taken out after a signature error), as many
  /// entries as it had; null when it went as it was.
  final List<Map<String, dynamic>>? history;

  /// Estimated cost (US$) at list prices, each attempt at the prices of
  /// the model that ran it ([requested]'s when it is not one offered).
  double cost(AiModel requested) {
    if (billed.isEmpty) return usage.cost(AiModel.served(model, requested));
    var c = 0.0;
    for (final (id, u) in billed) {
      c += u.cost(AiModel.served(id, requested));
    }
    return c;
  }

  AiReply _copy({List<Map<String, dynamic>>? history, AiUsage? usage, List<(String, AiUsage)>? billed, int? requestBytes, int? images, int? documents}) => AiReply(
    items: items,
    text: text,
    calls: calls,
    stop: stop,
    model: model,
    usage: usage ?? this.usage,
    billed: billed ?? this.billed,
    category: category,
    explanation: explanation,
    recommendedModel: recommendedModel,
    compacted: compacted,
    history: history ?? this.history,
    transformations: transformations,
    requestBytes: requestBytes ?? this.requestBytes,
    images: images ?? this.images,
    documents: documents ?? this.documents,
  );

  AiReply withHistory(List<Map<String, dynamic>> h) => _copy(history: h);

  /// This answer with what its request carried ([requestBytes], [images],
  /// [documents]).
  AiReply withRequest({required int bytes, required int images, required int documents}) => _copy(requestBytes: bytes, images: images, documents: documents);

  /// This answer with the tokens of earlier attempts of the same request
  /// that did not finish ([spent], billed at [requested]'s prices) counted
  /// in it.
  AiReply withSpent(AiUsage spent, String requested) => spent.isZero
      ? this
      : _copy(
          usage: usage + spent,
          billed: [
            (requested, spent),
            ...(billed.isEmpty ? [(model, usage)] : billed),
          ],
        );
}

/// One request. [history] is in the provider's own format and only ever
/// grows (earlier entries are sent byte for byte as they were).
class AiRequest {
  const AiRequest({
    required this.model,
    required this.system,
    required this.history,
    this.tools = const [],
    this.effort = AiEffort.medium,
    this.maxTokens,
    this.taskBudget,
    this.compactAt,
    this.longCache = false,
  });
  final AiModel model;
  final String system;
  final List<Map<String, dynamic>> history;
  final List<AiToolSpec> tools;

  /// The effort of the request itself (Anthropic: the conversation's first;
  /// a later change goes as an effort message in [history], see
  /// [AiClient.effortMessage]).
  final AiEffort effort;

  /// Anthropic: the conversation is cached for an hour instead of five
  /// minutes (a step may think for longer than five minutes, so the next
  /// one would find the cache gone), at twice the input price per token
  /// written ([AiModel.cacheWriteHour]).
  final bool longCache;

  /// Output tokens one answer may take; null: the model's
  /// [AiModel.maxOutput].
  final int? maxTokens;

  /// Tokens the whole task may use (Anthropic task budget, on the models
  /// that take it; at least 20 000); null: none.
  final int? taskBudget;

  /// Input tokens above which the server summarises the older turns
  /// (where the model supports it); null: never.
  final int? compactAt;

  /// The output limit sent.
  int get outputTokens => maxTokens ?? model.maxOutput;

  /// The same request over [h].
  AiRequest withHistory(List<Map<String, dynamic>> h) =>
      AiRequest(model: model, system: system, history: h, tools: tools, effort: effort, maxTokens: maxTokens, taskBudget: taskBudget, compactAt: compactAt, longCache: longCache);

  /// The same request with another output limit.
  AiRequest withMaxTokens(int? n) =>
      AiRequest(model: model, system: system, history: history, tools: tools, effort: effort, maxTokens: n, taskBudget: taskBudget, compactAt: compactAt, longCache: longCache);
}

/// One provider's API.
abstract class AiClient {
  AiProvider get provider;

  /// The user's message, in this API's format.
  Map<String, dynamic> userMessage(List<AiPart> parts);

  /// The results of a round of tool calls, with what the user wrote
  /// meanwhile ([user]) and an instruction from the program ([note]), in
  /// this API's format.
  List<Map<String, dynamic>> toolResults(List<AiToolResult> results, {List<AiPart> user = const [], String? note});

  /// An entry for the conversation, placed right after a user message, that
  /// sets the effort [e] of the model's answers from that message on while
  /// the cached conversation stays as it is (changing the request's own
  /// effort would rewrite it); null where [m] cannot take one.
  Map<String, dynamic>? effortMessage(AiModel m, AiEffort e);

  /// Sends [r] and gathers the streamed answer; transient failures are
  /// retried unless part of the answer arrived ([onRetry] says when, and
  /// after what).
  Future<AiReply> send(AiRequest r, {required AiCancel cancel, AiStreamListener listener = const AiStreamListener(), void Function(Duration wait, int attempt, AiError error)? onRetry});
}

/// The effort an effort message of [AiClient.effortMessage] sets, or null
/// when [m] is not one.
AiEffort? effortOfMessage(Map<String, dynamic> m) {
  if (m['role'] != 'system') return null;
  final c = m['content'], o = m['output_config'];
  if (c is! List || c.isNotEmpty || o is! Map) return null;
  return AiEffort.values.where((e) => e.name == o['effort']).firstOrNull;
}

/// The effort the model answers with after [history], which started at
/// [start] (the request's own effort): the last effort message's, if any.
AiEffort effortAfter(List<Map<String, dynamic>> history, AiEffort start) {
  for (var i = history.length - 1; i >= 0; i--) {
    final e = effortOfMessage(history[i]);
    if (e != null) return e;
  }
  return start;
}

/// The pictures and the documents (PDFs) in [o], a request's messages in
/// either provider's format: blocks of type `image` / `input_image` and
/// `document` / `input_file`, wherever they are (in tool results too).
(int images, int documents) countMedia(Object? o) {
  var images = 0, documents = 0;
  void walk(Object? x) {
    if (x is Map) {
      final type = x['type'];
      if (type == 'image' || type == 'input_image') {
        images++;
        return;
      }
      if (type == 'document' || type == 'input_file') {
        documents++;
        return;
      }
      for (final v in x.values) {
        if (v is Map || v is List) walk(v);
      }
    } else if (x is List) {
      for (final v in x) {
        walk(v);
      }
    }
  }

  walk(o);
  return (images, documents);
}

/// What a connection test found ([AiHttpClient.probe]): one small request
/// to [model] with what the assistant's requests carry.
class AiProbe {
  const AiProbe({
    required this.model,
    this.error,
    this.usage = AiUsage.zero,
    this.cost = 0,
    this.servedBy = '',
    this.elapsed = Duration.zero,
    this.limits = const {},
    this.declined = const [],
    this.text = '',
    this.requestId,
  });

  /// The model tested.
  final AiModel model;

  /// Why the request failed; null when the model answered.
  final AiError? error;
  final AiUsage usage;

  /// US$ at list prices (an estimate).
  final double cost;

  /// The model that answered (a server-side fallback may answer instead).
  final String servedBy;
  final Duration elapsed;

  /// The account's rate limits as the answer's headers gave them (header
  /// name without its provider prefix → value), when the API lets the page
  /// read them.
  final Map<String, String> limits;

  /// Optional request fields the API turned down for this model: they are
  /// left out of its requests from now on.
  final List<String> declined;

  /// The model's answer (a word or two).
  final String text;
  final String? requestId;

  bool get ok => error == null;
}

/// The HTTP side every client shares: one key and transport, timeouts,
/// retries with backoff (honouring `retry-after`), line-by-line reading of
/// a streamed body, the size check before sending, and messages cleaned of
/// the key.
abstract class AiHttpClient implements AiClient {
  AiHttpClient({required this.apiKey, required this.transport, this.sleep, this.maxRetries = 2});
  final String apiKey;
  final AiTransport transport;
  final int maxRetries;

  /// Waits between retries (tests make them instant); cancellable timers
  /// when null.
  final Future<void> Function(Duration d)? sleep;

  /// No status line this long after the body went out: a timeout.
  Duration headerTimeout(AiModel m) => Duration(seconds: m.longTurns ? 300 : 90);

  /// What the body may take to go up on a slow connection (128 KB/s),
  /// added to [headerTimeout] until the transport says it went out.
  static Duration uploadAllowance(int bytes) => Duration(milliseconds: bytes ~/ 128);

  /// No data at all for this long: a timeout (twice as long at the two
  /// highest efforts, where the model may think for many minutes).
  Duration idleTimeout(AiModel m, [AiEffort effort = AiEffort.medium]) => Duration(seconds: (m.longTurns ? 600 : 180) * (effort.index >= AiEffort.xhigh.index ? 2 : 1));

  /// Largest request body sent, in UTF-8 bytes. The Messages API takes
  /// 32 MB and answers a larger one only after the upload, with a 413 (in
  /// the browser even without CORS headers, so it shows as a network
  /// failure); a larger request fails here instead, before it leaves.
  static const maxRequestBytes = 30000000;

  /// Longest wait asked by `retry-after` that is waited for (a longer one
  /// is the error, with the wait in it).
  static const maxWait = Duration(seconds: 30);

  /// One attempt.
  Future<AiReply> attempt(AiRequest r, AiCancel cancel, AiStreamListener listener);

  /// The headers of the last response that arrived (lower-case names).
  Map<String, String> lastHeaders = const {};

  /// The system prompt and the question of a connection test ([probe]).
  static const probeSystem = 'Connection test of the OpenCADIrrigation assistant. Answer with one word.';
  static const probeQuestion = 'Reply with the word OK.';

  /// Output tokens a connection test may take (thinking counts in them).
  static const probeTokens = 256;

  /// The request of a connection test of [m]: what the assistant's requests
  /// carry for it (thinking, the betas and their fields, compaction and the
  /// clearing of old tool results, the cache breakpoints), without tools,
  /// at the lowest effort and with a few output tokens.
  AiRequest probeRequest(AiModel m) => AiRequest(
    model: m,
    system: probeSystem,
    history: [
      userMessage(const [AiTextPart(probeQuestion)]),
    ],
    effort: AiEffort.low,
    maxTokens: probeTokens,
    compactAt: m.compaction ? m.compactAt : null,
  );

  /// A connection test of [m]: one small request sent as the assistant's
  /// are ([probeRequest], [send]), which tells whether the key, the account
  /// and the model take what the assistant sends, what it cost, and the
  /// account's rate limits when the answer's headers carry them. An
  /// optional field the API turns down is left out from then on, as in
  /// [send], and named in [AiProbe.declined]. Never throws.
  Future<AiProbe> probe(AiModel m, {required AiCancel cancel}) async {
    final watch = Stopwatch()..start();
    final before = {...declined};
    List<String> newly() => [
      for (final d in declined.difference(before))
        if (d.startsWith('${m.id}:')) d.substring(m.id.length + 1),
    ];
    lastHeaders = const {};
    try {
      final r = await send(probeRequest(m), cancel: cancel);
      return AiProbe(
        model: m,
        usage: r.usage,
        cost: r.cost(m),
        servedBy: r.model,
        elapsed: watch.elapsed,
        limits: rateLimitsOf(lastHeaders),
        declined: newly(),
        text: r.text.trim(),
        requestId: lastHeaders['request-id'] ?? lastHeaders['x-request-id'],
      );
    } on AiError catch (e) {
      return AiProbe(model: m, error: e, usage: e.usage, cost: e.usage.cost(m), elapsed: watch.elapsed, limits: rateLimitsOf(lastHeaders), declined: newly(), requestId: e.requestId);
    } catch (e) {
      return AiProbe(
        model: m,
        error: AiError(AiErrorKind.unexpected, message: clean('${e.runtimeType}')),
        elapsed: watch.elapsed,
        declined: newly(),
      );
    }
  }

  /// The rate limits in [headers]: `anthropic-ratelimit-*` and
  /// `x-ratelimit-*`, by name without that prefix.
  static Map<String, String> rateLimitsOf(Map<String, String> headers) => {
    for (final e in headers.entries)
      if (e.key.startsWith('anthropic-ratelimit-')) e.key.substring('anthropic-ratelimit-'.length): e.value else if (e.key.startsWith('x-ratelimit-')) e.key.substring('x-ratelimit-'.length): e.value,
  };

  /// Optional request fields a model turned down ("model id:field"), left
  /// out from then on in this session.
  static final Set<String> declined = {};

  /// Whether [field] goes into requests to [m].
  bool offers(AiModel m, String field) => !declined.contains('${m.id}:$field');

  /// The optional fields [r] carries (names as the API spells them), which
  /// are dropped when a request is rejected for one of them.
  List<String> optionalFields(AiRequest r) => const [];

  /// The optional field a rejection with [message] is about, if any.
  String? declinedField(AiRequest r, String message) => optionalFields(r).where(message.contains).firstOrNull;

  /// A request to send instead of [r], which the API rejected with [e]
  /// (its history repaired, say); null when nothing can be done. [tries]:
  /// recoveries already made for this request.
  AiRequest? recover(AiRequest r, AiError e, int tries) => null;

  @override
  Map<String, dynamic>? effortMessage(AiModel m, AiEffort e) => null;

  @override
  Future<AiReply> send(AiRequest r, {required AiCancel cancel, AiStreamListener listener = const AiStreamListener(), void Function(Duration wait, int attempt, AiError error)? onRetry}) async {
    if (apiKey.trim().isEmpty) throw AiError(AiErrorKind.noKey);
    var req = r;
    var recoveries = 0;
    // tokens billed for attempts that did not finish (counted in the reply,
    // or in the error that ends the request)
    var spent = AiUsage.zero;
    for (var n = 0; ; n++) {
      if (cancel.cancelled) throw AiError(AiErrorKind.cancelled, usage: spent);
      // each attempt has a token of its own: a timeout stops that attempt
      // and its HTTP exchange, while the task (and the retry) goes on
      final one = cancel.child();
      AiError e;
      try {
        final reply = await attempt(req, one, listener);
        return (identical(req, r) ? reply : reply.withHistory(req.history)).withSpent(spent, r.model.id);
      } on AiError catch (x) {
        e = x;
      } catch (x) {
        e = AiError(AiErrorKind.unexpected, message: clean('${x.runtimeType}'));
      } finally {
        one.release();
      }
      spent += e.usage;
      e = AiError(
        e.kind,
        status: e.status,
        message: e.message,
        retryAfter: e.retryAfter,
        requestId: e.requestId,
        category: e.category,
        recommendedModel: e.recommendedModel,
        size: e.size,
        limit: e.limit,
        partial: e.partial,
        usage: spent,
      );
      // whatever still runs of the failed attempt stops: a stream left
      // after an idle timeout, an upload, an answer nobody reads
      one.cancel();
      if (cancel.cancelled) throw AiError(AiErrorKind.cancelled, usage: spent);
      if (e.kind == AiErrorKind.invalidRequest && !e.partial) {
        // an optional field this model does not take: the same request
        // without it, at once
        final field = declinedField(req, e.message);
        if (field != null) {
          declined.add('${req.model.id}:$field');
          n--;
          continue;
        }
        final again = recover(req, e, recoveries);
        if (again != null) {
          recoveries++;
          req = again;
          n--;
          continue;
        }
      }
      final wait = backoff(e, n);
      if (!e.retryable || e.partial || n >= maxRetries || wait == null) throw e;
      onRetry?.call(wait, n + 1, e);
      try {
        await _wait(wait, cancel);
      } on AiError catch (x) {
        throw x.withUsage(spent);
      }
    }
  }

  /// Wait before retry [attempt] (0-based) after [e]; null: do not retry.
  static Duration? backoff(AiError e, int attempt) {
    final asked = e.retryAfter;
    if (asked != null) return asked > maxWait ? null : asked;
    final base = switch (e.kind) {
      AiErrorKind.rateLimit => 4000,
      AiErrorKind.network || AiErrorKind.interrupted => 1500,
      AiErrorKind.timeout => 1000,
      _ => 2000,
    };
    return Duration(milliseconds: base * math.pow(2, attempt).toInt());
  }

  Future<void> _wait(Duration d, AiCancel cancel) async {
    final sleep = this.sleep;
    if (sleep != null) {
      await sleep(d);
      if (cancel.cancelled) throw AiError(AiErrorKind.cancelled);
      return;
    }
    final done = Completer<void>();
    final timer = Timer(d, () {
      if (!done.isCompleted) done.complete();
    });
    final forget = cancel.onCancel(() {
      timer.cancel();
      if (!done.isCompleted) done.completeError(AiError(AiErrorKind.cancelled));
    });
    try {
      await done.future;
    } finally {
      forget();
    }
  }

  /// [s] on one line, without the key or a masked copy of it, at most 400
  /// characters.
  String clean(String s) {
    final k = apiKey.trim();
    var out = k.length >= 8 ? s.replaceAll(k, '[key]') : s;
    out = out.replaceAll(RegExp(r'sk-[A-Za-z0-9_\-]*\*+[A-Za-z0-9_\-]*'), '[key]');
    out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
    return out.length <= 400 ? out : '${out.substring(0, 399)}…';
  }

  /// Bytes of [s] in UTF-8, without encoding it.
  static int utf8Length(String s) {
    var n = s.length;
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (c < 0x80) continue;
      if (c < 0x800) {
        n += 1;
      } else if (c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length) {
        // a surrogate pair: 4 bytes for its 2 code units
        n += 2;
        i++;
      } else {
        n += 2;
      }
    }
    return n;
  }

  /// Fails with [AiErrorKind.tooLarge] when [body] is over [limit] bytes.
  static void checkSize(String body, {int limit = maxRequestBytes}) {
    // each code unit is 1 to 3 bytes: count only when it can matter
    if (body.length * 3 <= limit) return;
    final bytes = body.length > limit ? body.length : utf8Length(body);
    if (bytes > limit) throw AiError(AiErrorKind.tooLarge, size: bytes, limit: limit);
  }

  /// Sends [req]: the response once its status arrived, or a timeout,
  /// which stops the exchange through [cancel] (the attempt's token).
  Future<AiHttpResponse> open(AiHttpRequest req, AiModel model, AiCancel cancel) async {
    if (cancel.cancelled) throw AiError(AiErrorKind.cancelled);
    final done = Completer<AiHttpResponse>();
    Timer? timer;
    void arm(Duration d) {
      timer?.cancel();
      timer = Timer(d, () {
        if (done.isCompleted) return;
        done.completeError(AiError(AiErrorKind.timeout));
        cancel.cancel();
      });
    }

    // until the transport says the body went out, the upload's own time on top
    arm(headerTimeout(model) + uploadAllowance(req.body.length));
    cancel.onCancel(() {
      timer?.cancel();
      if (!done.isCompleted) done.completeError(AiError(AiErrorKind.cancelled));
    });
    final sent = AiHttpRequest(
      req.url,
      req.headers,
      req.body,
      onSent: () {
        if (!done.isCompleted) arm(headerTimeout(model));
        req.onSent?.call();
      },
    );
    Future<AiHttpResponse> f;
    try {
      f = transport(sent, cancel);
    } catch (e) {
      f = Future.error(e);
    }
    f.then(
      (r) {
        timer?.cancel();
        lastHeaders = r.headers;
        if (!done.isCompleted) done.complete(r);
      },
      onError: (Object e) {
        timer?.cancel();
        if (!done.isCompleted) done.completeError(e is AiError ? e : (cancel.cancelled ? AiError(AiErrorKind.cancelled) : AiError(AiErrorKind.network, message: clean('$e'))));
      },
    );
    return done.future;
  }

  /// The whole body as text (at most 64 KB kept).
  Future<String> readAll(Stream<List<int>> body, AiModel model, AiCancel cancel, {Duration? idle}) async {
    final out = StringBuffer();
    try {
      await readLines(
        body,
        model,
        (l) {
          if (out.length < 65536) out.writeln(l);
        },
        cancel,
        idle: idle,
      );
    } on AiError catch (e) {
      if (e.kind == AiErrorKind.cancelled) rethrow;
    }
    return out.toString();
  }

  /// Feeds [body] line by line to [onLine]; fails on cancellation, on a
  /// network error and after [idle] (by default [idleTimeout]) without
  /// data, when it also stops the exchange through [cancel]. A failure of
  /// [onLine] that is not an [AiError] fails as [AiErrorKind.unexpected].
  Future<void> readLines(Stream<List<int>> body, AiModel model, void Function(String line) onLine, AiCancel cancel, {Duration? idle}) {
    final wait = idle ?? idleTimeout(model);
    final done = Completer<void>();
    StreamSubscription<String>? sub;
    Timer? timer;
    void fail(Object e) {
      if (done.isCompleted) return;
      timer?.cancel();
      sub?.cancel();
      done.completeError(e);
    }

    void arm() {
      timer?.cancel();
      timer = Timer(wait, () {
        fail(AiError(AiErrorKind.timeout));
        cancel.cancel();
      });
    }

    cancel.onCancel(() => fail(AiError(AiErrorKind.cancelled)));
    if (done.isCompleted) return done.future;
    arm();
    sub = body
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            arm();
            try {
              onLine(line);
            } on AiError catch (e) {
              fail(e);
            } catch (e) {
              fail(AiError(AiErrorKind.unexpected, message: clean('${e.runtimeType}')));
            }
          },
          onError: (Object e) => fail(e is AiError ? e : (cancel.cancelled ? AiError(AiErrorKind.cancelled) : AiError(AiErrorKind.network, message: clean('$e')))),
          onDone: () {
            timer?.cancel();
            if (!done.isCompleted) done.complete();
          },
          cancelOnError: true,
        );
    return done.future;
  }

  /// The wait a `retry-after-ms` or `retry-after` (seconds) header asks for.
  static Duration? retryAfterOf(Map<String, String> headers) {
    final ms = double.tryParse(headers['retry-after-ms']?.trim() ?? '');
    if (ms != null) return Duration(milliseconds: ms.round());
    final s = double.tryParse(headers['retry-after']?.trim() ?? '');
    return s == null ? null : Duration(milliseconds: (s * 1000).round());
  }
}

/// Server-sent events, one decoded `data:` payload at a time.
class SseReader {
  SseReader(this.onEvent);
  final void Function(Map<String, dynamic> event) onEvent;
  final List<String> _data = [];

  void line(String l) {
    if (l.isEmpty) {
      if (_data.isEmpty) return;
      final raw = _data.join('\n');
      _data.clear();
      if (raw.trim() == '[DONE]') return;
      Object? j;
      try {
        j = jsonDecode(raw);
      } catch (_) {
        return; // not JSON: nothing this client knows
      }
      if (j is Map<String, dynamic>) onEvent(j);
      return;
    }
    if (l.startsWith(':')) return;
    final i = l.indexOf(':');
    final field = i < 0 ? l : l.substring(0, i);
    var value = i < 0 ? '' : l.substring(i + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    if (field == 'data') _data.add(value);
  }

  /// Ends the stream (a last event without its blank line).
  void close() => line('');
}
