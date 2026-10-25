/// What the AI assistant needs from a model provider, whoever it is: the
/// models offered (with their tier and list prices), tokens and cost,
/// errors, cancellation, the HTTP exchange (injected: fetch in the browser,
/// HttpClient on the desktop, a scripted fake in tests), the parts of a
/// message, and the client each provider implements — Anthropic's Messages
/// API ([AnthropicClient]) and OpenAI's Responses API ([OpenAiClient]).
///
/// Pure Dart. Each provider gets its own key, sent only to its own host.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

/// The companies whose models the assistant can use, each called directly
/// with the user's own key.
enum AiProvider {
  anthropic('Anthropic', 'api.anthropic.com', 'https://console.anthropic.com/settings/keys', 'sk-ant-'),
  openai('OpenAI', 'api.openai.com', 'https://platform.openai.com/api-keys', 'sk-');

  const AiProvider(this.company, this.host, this.keysUrl, this.keyPrefix);
  final String company;

  /// The only host this provider's key is ever sent to.
  final String host;

  /// Where the user creates a key.
  final String keysUrl;

  /// How the provider's keys usually start (a hint, never enforced).
  final String keyPrefix;
}

/// Place of a model in its provider's range.
enum AiTier { top, intermediate, fast }

/// How much the model reasons before answering (Anthropic
/// `output_config.effort`, OpenAI `reasoning.effort`; every model offered
/// takes all five).
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
  });

  final AiProvider provider;
  final String id;
  final String label;
  final AiTier tier;
  final double input, output, cacheRead, cacheWrite;

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

  // Anthropic (Claude API list prices; cache writes 1.25 × input for the
  // five-minute cache). Task budgets are left off Claude Fable 5.1 until
  // Anthropic confirms them for it.
  static const fable51 = AiModel(
    AiProvider.anthropic,
    'claude-fable-5-1',
    'Claude Fable 5.1',
    AiTier.top,
    input: 10,
    output: 50,
    cacheRead: 0.25,
    cacheWrite: 12.5,
    serverFallback: true,
    alwaysThinks: true,
    longTurns: true,
    needsRetention: true,
  );
  static const opus55 = AiModel(AiProvider.anthropic, 'claude-opus-5-5', 'Claude Opus 5.5', AiTier.top, input: 4, output: 20, cacheRead: 0.2, cacheWrite: 5, serverFallback: true, taskBudget: true);
  static const sonnet55 = AiModel(
    AiProvider.anthropic,
    'claude-sonnet-5-5',
    'Claude Sonnet 5.5',
    AiTier.intermediate,
    input: 2,
    output: 10,
    cacheRead: 0.2,
    cacheWrite: 2.5,
    serverFallback: true,
    taskBudget: true,
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
  );

  // Models a refused request may fall back to on the server (priced only).
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
  );

  /// The models offered, by provider and tier.
  static const all = [fable51, opus55, sonnet55, haiku55, gpt6Astra, gpt61Sol, gpt6Luna, gpt6Sol, gpt56Terra];

  /// The model used until the user picks another.
  static const standard = opus55;

  static AiModel byId(String? id) => all.firstWhere((m) => m.id == id, orElse: () => standard);

  /// The model a reply says served it (a fallback may), else [requested].
  static AiModel served(String replyModel, AiModel requested) => [...all, _opus5, _opus48].where((m) => replyModel == m.id || replyModel.startsWith('${m.id}-')).firstOrNull ?? requested;

  /// Price per million tokens of input and output, for the settings.
  String get priceText => '${_usd(input)} / ${_usd(output)}';
  static String _usd(double v) => v < 1 ? v.toStringAsFixed(v < 0.1 ? 3 : 2).replaceFirst(RegExp(r'0$'), '') : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2));

  @override
  String toString() => id;
}

/// Tokens of one or more requests.
class AiUsage {
  const AiUsage({this.input = 0, this.output = 0, this.cacheWrite = 0, this.cacheRead = 0});
  static const zero = AiUsage();

  /// Input tokens neither read from nor written to the cache.
  final int input;
  final int output, cacheWrite, cacheRead;

  /// Every input token.
  int get totalInput => input + cacheWrite + cacheRead;

  AiUsage operator +(AiUsage o) => AiUsage(input: input + o.input, output: output + o.output, cacheWrite: cacheWrite + o.cacheWrite, cacheRead: cacheRead + o.cacheRead);

  /// Estimated cost at [m]'s list prices (US$).
  double cost(AiModel m) {
    final long = m.longAbove > 0 && totalInput > m.longAbove;
    final fi = long ? m.longInput : 1.0, fo = long ? m.longOutput : 1.0;
    return ((input * m.input + cacheWrite * m.cacheWrite + cacheRead * m.cacheRead) * fi + output * m.output * fo) / 1e6;
  }
}

enum AiErrorKind { noKey, auth, permission, billing, notFound, invalidRequest, tooLarge, rateLimit, overloaded, server, network, timeout, interrupted, cancelled, refusal, truncated, retention, http }

/// A failed request. [message] is the provider's own text when it gave one
/// (never the key).
class AiError implements Exception {
  AiError(this.kind, {this.status, this.message = '', this.retryAfter, this.requestId, this.category, this.partial = false});
  final AiErrorKind kind;
  final int? status;
  final String message;

  /// Wait the provider asked for (`retry-after`).
  final Duration? retryAfter;
  final String? requestId;

  /// Category of a refusal, when given.
  final String? category;

  /// Part of the answer had already arrived.
  final bool partial;

  bool get retryable => switch (kind) {
    AiErrorKind.rateLimit || AiErrorKind.overloaded || AiErrorKind.server || AiErrorKind.network => true,
    _ => false,
  };

  AiError withPartial() => AiError(kind, status: status, message: message, retryAfter: retryAfter, requestId: requestId, category: category, partial: true);

  @override
  String toString() => 'AiError(${kind.name}${status == null ? '' : ', $status'}${message.isEmpty ? '' : ': $message'})';
}

/// Stops a request (and the waits between retries) when the user asks.
class AiCancel {
  bool _cancelled = false;
  final List<void Function()> _hooks = [];
  bool get cancelled => _cancelled;

  /// Runs [f] on cancellation (at once when already cancelled).
  void onCancel(void Function() f) {
    if (_cancelled) {
      f();
    } else {
      _hooks.add(f);
    }
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
  const AiHttpRequest(this.url, this.headers, this.body);
  final Uri url;
  final Map<String, String> headers;
  final String body;
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
/// should stop the exchange when [cancel] fires and throw an [AiError]
/// (`network`) when the server cannot be reached.
typedef AiTransport = Future<AiHttpResponse> Function(AiHttpRequest request, AiCancel cancel);

/// Progress of a streamed answer.
class AiStreamListener {
  const AiStreamListener({this.onText, this.onToolStart, this.onActivity});
  final void Function(String text)? onText;

  /// The model started a tool call ([name]).
  final void Function(String name)? onToolStart;

  /// Anything arrived: the request is alive.
  final void Function()? onActivity;
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
  const ToolOutput(this.text, {this.images = const [], this.isError = false});
  factory ToolOutput.error(String text) => ToolOutput(text, isError: true);
  final String text;
  final List<ToolImage> images;
  final bool isError;

  /// [text] cut at [maxChars], with a note of what was left out.
  String clipped(int maxChars) => text.length <= maxChars ? text : '${text.substring(0, maxChars)}\n… (${text.length - maxChars} more characters left out: ask for less, e.g. with a filter or paging)';

  /// This output with its text cut at [maxChars].
  ToolOutput clip(int maxChars) => text.length <= maxChars ? this : ToolOutput(clipped(maxChars), images: images, isError: isError);
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

enum AiStop { end, tool, maxTokens, refusal }

/// The model's answer to one request.
class AiReply {
  const AiReply({
    required this.items,
    required this.text,
    required this.calls,
    required this.stop,
    required this.model,
    required this.usage,
    this.category,
    this.explanation = '',
    this.compacted = false,
  });

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
  final AiUsage usage;

  /// Category of a refusal.
  final String? category;

  /// Why the model declined, when it said.
  final String explanation;

  /// The server summarised the earlier conversation in this answer.
  final bool compacted;
}

/// One request. [history] is in the provider's own format and only ever
/// grows (earlier entries are sent byte for byte as they were).
class AiRequest {
  const AiRequest({required this.model, required this.system, required this.history, this.tools = const [], this.effort = AiEffort.medium, this.maxTokens = 64000, this.taskBudget, this.compactAt});
  final AiModel model;
  final String system;
  final List<Map<String, dynamic>> history;
  final List<AiToolSpec> tools;
  final AiEffort effort;
  final int maxTokens;

  /// Tokens the whole task may use (Anthropic task budget, on the models
  /// that take it; at least 20 000); null: none.
  final int? taskBudget;

  /// Input tokens above which the server summarises the older turns
  /// (where the model supports it); null: never.
  final int? compactAt;
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

  /// Sends [r] and gathers the streamed answer; transient failures are
  /// retried unless part of the answer arrived.
  Future<AiReply> send(AiRequest r, {required AiCancel cancel, AiStreamListener listener = const AiStreamListener(), void Function(Duration wait, int attempt)? onRetry});
}

/// The HTTP side every client shares: one key and transport, timeouts,
/// retries with backoff (honouring `retry-after`), line-by-line reading of
/// a streamed body, and messages cleaned of the key.
abstract class AiHttpClient implements AiClient {
  AiHttpClient({required this.apiKey, required this.transport, this.sleep, this.maxRetries = 2});
  final String apiKey;
  final AiTransport transport;
  final int maxRetries;

  /// Waits between retries (tests make them instant); cancellable timers
  /// when null.
  final Future<void> Function(Duration d)? sleep;

  /// No status line after this long: a timeout.
  Duration headerTimeout(AiModel m) => Duration(seconds: m.longTurns ? 300 : 90);

  /// No data at all for this long: a timeout.
  Duration idleTimeout(AiModel m) => Duration(seconds: m.longTurns ? 600 : 180);

  /// One attempt.
  Future<AiReply> attempt(AiRequest r, AiCancel cancel, AiStreamListener listener);

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

  @override
  Future<AiReply> send(AiRequest r, {required AiCancel cancel, AiStreamListener listener = const AiStreamListener(), void Function(Duration wait, int attempt)? onRetry}) async {
    if (apiKey.trim().isEmpty) throw AiError(AiErrorKind.noKey);
    for (var n = 0; ; n++) {
      if (cancel.cancelled) throw AiError(AiErrorKind.cancelled);
      try {
        return await attempt(r, cancel, listener);
      } on AiError catch (e) {
        // an optional field this model does not take: the same request
        // without it, at once
        if (e.kind == AiErrorKind.invalidRequest && !e.partial) {
          final field = declinedField(r, e.message);
          if (field != null) {
            declined.add('${r.model.id}:$field');
            n--;
            continue;
          }
        }
        final wait = backoff(e, n);
        if (cancel.cancelled || !e.retryable || e.partial || n >= maxRetries || wait == null) rethrow;
        onRetry?.call(wait, n + 1);
        await _wait(wait, cancel);
      }
    }
  }

  /// Wait before retry [attempt] (0-based) after [e]; null: do not retry.
  static Duration? backoff(AiError e, int attempt) {
    final asked = e.retryAfter;
    if (asked != null) return asked > const Duration(seconds: 30) ? null : asked;
    final base = switch (e.kind) {
      AiErrorKind.rateLimit => 4000,
      AiErrorKind.network => 1500,
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
    cancel.onCancel(() {
      timer.cancel();
      if (!done.isCompleted) done.completeError(AiError(AiErrorKind.cancelled));
    });
    return done.future;
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

  /// Sends [req]: the response once its status arrived, or a timeout.
  Future<AiHttpResponse> open(AiHttpRequest req, AiModel model, AiCancel cancel) async {
    final done = Completer<AiHttpResponse>();
    final timer = Timer(headerTimeout(model), () {
      if (done.isCompleted) return;
      done.completeError(AiError(AiErrorKind.timeout));
      cancel.cancel();
    });
    cancel.onCancel(() {
      timer.cancel();
      if (!done.isCompleted) done.completeError(AiError(AiErrorKind.cancelled));
    });
    Future<AiHttpResponse> f;
    try {
      f = transport(req, cancel);
    } catch (e) {
      f = Future.error(e);
    }
    f.then(
      (r) {
        timer.cancel();
        if (!done.isCompleted) done.complete(r);
      },
      onError: (Object e) {
        timer.cancel();
        if (!done.isCompleted) done.completeError(e is AiError ? e : (cancel.cancelled ? AiError(AiErrorKind.cancelled) : AiError(AiErrorKind.network, message: clean('$e'))));
      },
    );
    return done.future;
  }

  /// The whole body as text (at most 64 KB kept).
  Future<String> readAll(Stream<List<int>> body, AiModel model, AiCancel cancel) async {
    final out = StringBuffer();
    try {
      await readLines(body, model, (l) {
        if (out.length < 65536) out.writeln(l);
      }, cancel);
    } on AiError catch (e) {
      if (e.kind == AiErrorKind.cancelled) rethrow;
    }
    return out.toString();
  }

  /// Feeds [body] line by line to [onLine]; fails on cancellation, on a
  /// network error and after the idle timeout without data.
  Future<void> readLines(Stream<List<int>> body, AiModel model, void Function(String line) onLine, AiCancel cancel) {
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
      timer = Timer(idleTimeout(model), () => fail(AiError(AiErrorKind.timeout)));
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
            } catch (e) {
              fail(e);
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
