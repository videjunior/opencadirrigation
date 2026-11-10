/// Meta's Model API, Responses format (`POST https://api.meta.ai/v1/responses`),
/// as the AI assistant uses it for the Muse models (Muse Wonder, Muse Spark,
/// Muse Ember): called straight from the user's browser or desktop with the
/// user's own Meta key, no server in between.
///
/// It has the shape of OpenAI's Responses API, so the client is
/// [OpenAiClient] with what differs changed, and a conversation is kept in
/// the same format. Pure Dart; the key goes in the authorization header of
/// the request to Meta and nowhere else.
///
/// Written from Meta's documentation of 2026-11-10 (dev.meta.ai/docs:
/// protocols/responses, reasoning, tool-calling, media-understanding,
/// file-handling, prompt-caching, error-handling, pricing-rate-limits and
/// the Responses API reference):
///
/// * Stateless: `store: false` with `include: ["reasoning.encrypted_content"]`,
///   the replay Meta recommends for agents ("Nothing is stored
///   server-side"); never `previous_response_id`, which keeps the
///   conversation on Meta's servers (and cannot be combined with the
///   encrypted reasoning). The whole conversation goes with every request.
/// * The model's output items go back as they came — reasoning items with
///   their encrypted content, assistant messages with their `phase` — except
///   what the API documents it would reject ([itemsOf]).
/// * No server-side compaction: the API has no `context_management`, and
///   rejects `truncation: "auto"`.
/// * No built-in tool: only the app's function tools (Meta's `web_search`
///   is billed per query and `tool_search` changes how tools load; neither
///   is ever sent).
/// * Pictures in user messages and in function outputs as `input_image`
///   data URLs, PDFs as `input_file` data URLs — the neutral format as it
///   is. Meta's own computer-use agent returns its screenshots inside
///   `function_call_output` the same way.
/// * Caching is automatic; [cacheKey] keeps the requests of the app on
///   backends that hold their prefix. Usage counts only the caller's tokens
///   (Meta's injected steering prompt is neither billed nor counted).
library;

import 'dart:math' as math;

import 'llm_formats.dart';
import 'openai_api.dart';

class MetaClient extends OpenAiClient {
  MetaClient({required super.apiKey, required super.transport, super.sleep, super.maxRetries});

  static final endpoint = Uri.parse('https://api.meta.ai/v1/responses');

  @override
  Uri get url => endpoint;

  @override
  AiProvider get provider => AiProvider.meta;

  /// The `prompt_cache_key` of every request: requests that share a key are
  /// routed together, so a conversation's next request is more likely to
  /// reach a backend that holds its prefix. Meta asks for one stable key per
  /// application or use case, not one per user or session (that lowers the
  /// hit rate). A constant: it says nothing about the user.
  static const cacheKey = 'opencadirrigation-assistant';

  /// The least `max_output_tokens` the API takes.
  static const minOutputTokens = 16;

  /// Output tokens below which an answer is not worth asking for when the
  /// conversation leaves less room than the request's limit (the reasoning
  /// shares the limit with the answer): the same floor the agent loop gives
  /// an answer under a spending cap (AgentLoop.minCappedOutput). With less
  /// room the conversation no longer fits ([AiErrorKind.contextWindow]).
  static const minOutputRoom = 16000;

  /// The largest `max_output_tokens` a model took, by model id, learned from
  /// a rejection that named it ("must be <= N"): later requests ask for no
  /// more. Meta documents 524 288 for Muse Ember and 131 072 in its setup of
  /// Muse Spark for coding agents; it gives none for Muse Wonder.
  static final Map<String, int> outputCeilings = {};

  /// Meta's Responses API has no server-side compaction.
  @override
  bool compacts(AiRequest r) => false;

  @override
  List<String> optionalFields(AiRequest r) => [if (offers(r.model, 'prompt_cache_key')) 'prompt_cache_key'];

  /// The output limit sent: the request's, within what the model takes.
  int outputTokensOf(AiRequest r) {
    final ceiling = outputCeilings[r.model.id];
    final n = ceiling != null && ceiling < r.outputTokens ? ceiling : r.outputTokens;
    return math.max(minOutputTokens, n);
  }

  /// The request body. The effort goes as `reasoning.effort` (the top-level
  /// `reasoning_effort` is the Chat Completions spelling); Meta takes
  /// `minimal`, `low`, `medium`, `high`, `xhigh` and `max` on Muse Wonder,
  /// Muse Spark 1.3 and Muse Ember, so every effort of the app goes by its
  /// own name ([OpenAiClient.effortOf] through [AiModel.effortFor]).
  @override
  Map<String, Object?> body(AiRequest r) => {
    'model': r.model.id,
    'instructions': r.system,
    'input': inputOf(r),
    if (r.tools.isNotEmpty) 'tools': [for (final s in r.tools) OpenAiFormat.tool(s)],
    'reasoning': {'effort': effortOf(r.model, r.effort)},
    'max_output_tokens': outputTokensOf(r),
    'stream': true,
    'store': false,
    'include': ['reasoning.encrypted_content'],
    if (offers(r.model, 'prompt_cache_key')) 'prompt_cache_key': cacheKey,
  };

  bool _replayable(Map<String, dynamic> it) {
    final enc = it['encrypted_content'];
    return enc is String && enc.isNotEmpty;
  }

  /// The output items as they go back in the next request: unchanged, but
  /// for what Meta documents it rejects in a replayed conversation (HTTP 400):
  ///
  /// * a reasoning item without its encrypted content (with `store: false`
  ///   there is nothing on the server its id could refer to) or with no
  ///   assistant message or function call after it in the answer (a
  ///   reasoning item must be followed by one before the next user, system
  ///   or developer message) is left out — "the server does not require a
  ///   reasoning item to travel with its message or tool call, so dropping
  ///   one is allowed";
  /// * an assistant message before a function call goes as
  ///   `phase: "commentary"`, which the model sets on such messages itself
  ///   ("intermediate assistant text that precedes a function_call must be
  ///   tagged phase: commentary"); a phase the model gave stays as it is.
  @override
  List<Map<String, dynamic>> itemsOf(List<Map<String, dynamic>> output) {
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < output.length; i++) {
      final it = output[i];
      final after = output.skip(i + 1);
      switch (it['type']) {
        case 'reasoning':
          if (_replayable(it) && after.any((x) => x['type'] == 'message' || x['type'] == 'function_call')) out.add(it);
        case 'message' when it['role'] == 'assistant' && it['phase'] == null && after.any((x) => x['type'] == 'function_call'):
          out.add({...it, 'phase': 'commentary'});
        default:
          out.add(it);
      }
    }
    return out;
  }

  /// The tokens of a response's `usage`: `input_tokens` counts the cached
  /// ones too (`input_tokens_details.cached_tokens`, billed at the cached
  /// rate); `output_tokens` counts the reasoning tokens, billed as output.
  /// Meta bills no cache writes apart, and reports none.
  @override
  AiUsage usageOf(Map<String, dynamic> usage) {
    int v(Object? m, String k) => m is Map ? (m[k] as num?)?.toInt() ?? 0 : 0;
    final cached = v(usage['input_tokens_details'], 'cached_tokens');
    return AiUsage(input: math.max(0, v(usage, 'input_tokens') - cached), cacheRead: cached, output: v(usage, 'output_tokens'));
  }

  /// "You passed {N} input tokens and requested {M} output tokens. However,
  /// the model's context length is only {C} tokens…" (HTTP 400, no code).
  static final _contextLength = RegExp(r'passed (\d+) input tokens and requested (\d+) output tokens.*?context length is only (\d+) tokens', caseSensitive: false);

  /// A validation error naming the most `max_output_tokens` takes, in the
  /// form of Meta's validation messages ("`top_p`: The number must be
  /// `<= 1.0`.").
  static final _outputCeiling = RegExp(r'max_output_tokens\W.*?<=\s*`?(\d+)', caseSensitive: false);

  /// A replayed reasoning item the API turned down: "Referenced reasoning
  /// item … was not found or has expired", "Invalid reasoning ID format",
  /// duplicate `reasoning_id` values, "reasoning items must be followed by
  /// an assistant message or function call…".
  static final _reasoningRejected = RegExp(r'reasoning (item|id)|reasoning_id', caseSensitive: false);

  /// Output tokens the conversation leaves in the context window, from a
  /// context-length rejection (null for another message).
  static int? outputRoomOf(String message) {
    final m = _contextLength.firstMatch(message);
    if (m == null) return null;
    return int.parse(m.group(3)!) - int.parse(m.group(1)!);
  }

  /// The kind of an error of Meta's: the codes and types of its error
  /// objects (`invalid_request_error`, `authentication_error`,
  /// `billing_error`, `rate_limit_error`, `server_error`), else the HTTP
  /// status as for OpenAI.
  @override
  AiErrorKind errorKind(int? status, String type, String code, String message) {
    switch (code) {
      // a rolling restart, a busy or unreachable backend: always worth sending again
      case 'server_shutting_down' || 'service_overloaded' || 'backend_unavailable':
        return AiErrorKind.overloaded;
      case 'payload_too_large':
        return AiErrorKind.tooLarge;
    }
    // past a server time limit: Meta says the same request usually times out again, so it is not retried
    if (code == 'gateway_timeout' || status == 504) return AiErrorKind.http;
    // no balance, a lapsed payment method or billing not set up
    if (type == 'billing_error' || status == 402) return AiErrorKind.billing;
    if (_contextLength.hasMatch(message)) return AiErrorKind.contextWindow;
    if (status == null) {
      // an error event of the stream, with no status to go by
      switch (type) {
        case 'rate_limit_error':
          return AiErrorKind.rateLimit;
        case 'server_error':
          return AiErrorKind.server;
        case 'authentication_error':
          return AiErrorKind.auth;
      }
    }
    return super.errorKind(status, type, code, message);
  }

  /// As [OpenAiClient.httpError]; a context-length rejection that still
  /// leaves room for an answer of [minOutputRoom] tokens is an invalid
  /// request, which [recover] sends again with a smaller output limit.
  @override
  AiError httpError(int status, String body, Map<String, String> headers) {
    final e = super.httpError(status, body, headers);
    if (e.kind != AiErrorKind.contextWindow) return e;
    final room = outputRoomOf(e.message);
    if (room == null || room < minOutputRoom) return e;
    return AiError(AiErrorKind.invalidRequest, status: e.status, message: e.message, retryAfter: e.retryAfter, requestId: e.requestId);
  }

  /// Policy codes of a failed response or an error event: the request was
  /// declined (Meta's `content_policy_violation` for media besides OpenAI's
  /// codes). The same code on an HTTP 400 stays an invalid request, so the
  /// agent loop sends the round again without its pictures.
  @override
  Set<String> get declinedCodes => {...super.declinedCodes, 'content_policy_violation'};

  /// A request to send instead of [r], which Meta rejected with [e] (HTTP
  /// 400), at most three times for one request:
  ///
  /// * the conversation leaves less room than the output limit asked for:
  ///   the same request asking for what is left;
  /// * the output limit is above what the model takes: the same request at
  ///   that limit, which later requests keep ([outputCeilings]);
  /// * a reasoning item it no longer takes: the same request without the
  ///   reasoning items (allowed: the model then goes on without its earlier
  ///   reasoning). The stored history keeps them.
  @override
  AiRequest? recover(AiRequest r, AiError e, int tries) {
    if (tries >= 3 || e.status != 400) return null;
    final room = outputRoomOf(e.message);
    if (room != null) return room >= minOutputRoom && room < outputTokensOf(r) ? r.withMaxTokens(room) : null;
    final ceiling = _outputCeiling.firstMatch(e.message);
    if (ceiling != null) {
      final n = int.parse(ceiling.group(1)!);
      if (n < minOutputTokens || n >= outputTokensOf(r)) return null;
      outputCeilings[r.model.id] = n;
      return r.withMaxTokens(n);
    }
    if (_reasoningRejected.hasMatch(e.message) && r.history.any((it) => it['type'] == 'reasoning')) {
      return r.withHistory([
        for (final it in r.history)
          if (it['type'] != 'reasoning') it,
      ]);
    }
    return null;
  }

  /// Meta keys look like `LLM_{numeric id}_{secret}`.
  static final _metaKey = RegExp(r'LLM_\d+_[A-Za-z0-9_.\-*]+');

  /// [s] cleaned as every client's, a Meta key in it (even a masked one)
  /// too.
  @override
  String clean(String s) => super.clean(s.replaceAll(_metaKey, '[key]'));
}
