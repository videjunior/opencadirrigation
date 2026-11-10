/// OpenRouter's Responses API (`POST https://openrouter.ai/api/v1/responses`)
/// as the AI assistant uses it: one OpenRouter key reaches the models of many
/// makers through OpenRouter's servers, called straight from the user's
/// browser or desktop, no server of this app in between.
///
/// It has the shape of OpenAI's Responses API and is stateless only (OpenRouter
/// rejects `store: true` and `previous_response_id`): the conversation goes
/// whole with every request, so the client is [OpenAiClient] with what
/// differs changed, and a conversation is kept in the same format. What
/// differs, from OpenRouter's documentation (openrouter.ai/docs, read on
/// 2026-11-10: api_reference/responses/*, errors-and-debugging, limits,
/// streaming, prompt-caching, reasoning-tokens, app-attribution, usage
/// accounting, multimodal):
///
/// * the request: no `context_management` (not in OpenRouter's request
///   schema; no server-side compaction), a top-level `cache_control` that
///   turns on the automatic cache breakpoint of the models whose cache needs
///   one (Anthropic's above all; not for OpenAI's, which cache by
///   themselves), a `session_id` that keeps the requests of one conversation
///   on the same provider (OpenRouter's sticky routing, so the cache is
///   found again), and PDFs read by OpenRouter's free parser for the models
///   that do not read files themselves (its default for them bills an OCR
///   per page on every request);
/// * the conversation: assistant messages, reasoning items and function
///   calls carry the `id` (and `status`) OpenRouter requires, and the
///   pictures of tool results go in a user message after the results for
///   the makers whose tool results are not known to carry pictures through
///   OpenRouter (only the array form of `function_call_output` is
///   documented, "forwarded to supported multimodal models"), so that every
///   model that reads pictures sees them;
/// * the reasoning of every maker comes back as `reasoning` items (OpenAI's
///   encrypted content, Anthropic's thinking text with its signature,
///   Google's thought signatures; `format` names which) and goes back
///   exactly as it came: tool loops keep their reasoning with all of them;
/// * errors: OpenRouter's own (402 no credit, the in-flight spending budget,
///   403 budgets, moderation and guardrails, 408, 429 with the free models'
///   limits, 502/503 no provider) and the provider errors it wraps, read
///   from the canonical `error_type` it adds beside the narrower Responses
///   `code`;
/// * the usage carries the `cost` OpenRouter charged ([lastCost]) and the
///   answer names the model that answered (a router reports the one it
///   chose), so the app prices it as that model;
/// * the request names the app for OpenRouter's app rankings
///   (`HTTP-Referer: https://opencadirrigation.com`,
///   `X-OpenRouter-Title: OpenCADIrrigation`; the CORS preflight allows
///   both), nothing about the user.
///
/// Pure Dart; the key goes in the authorization header of the request to
/// OpenRouter and nowhere else.
library;

import 'dart:convert';

import 'openai_api.dart';
import 'openrouter_catalog.dart';

class OpenRouterClient extends OpenAiClient {
  OpenRouterClient({required super.apiKey, required super.transport, super.sleep, super.maxRetries});

  static final endpoint = Uri.parse('https://openrouter.ai/api/v1/responses');

  /// The app as OpenRouter's app attribution names it: its public address
  /// (`HTTP-Referer`) and its name (`X-OpenRouter-Title`, which replaced
  /// `X-Title`).
  static const appUrl = 'https://opencadirrigation.com';
  static const appTitle = 'OpenCADIrrigation';

  /// The clock of the waits until a limit resets (tests set it).
  static DateTime Function() clock = DateTime.now;

  @override
  Uri get url => endpoint;

  @override
  AiProvider get provider => AiProvider.openrouter;

  /// OpenRouter's Responses API has no `context_management`: no server-side
  /// compaction (the models of the table have `compaction: false`).
  @override
  bool compacts(AiRequest r) => false;

  /// OpenRouter's id of a generation (`gen-…`), which its activity page and
  /// support use; the CORS headers let the page read it.
  @override
  String get requestIdHeader => 'x-generation-id';

  @override
  Map<String, String> headers() => {...super.headers(), 'http-referer': appUrl, 'x-openrouter-title': appTitle};

  /// The cache of [m] may need a breakpoint, which the top-level
  /// `cache_control` places at the end of the request and moves along as the
  /// conversation grows (OpenRouter's automatic caching, the only form the
  /// Responses API takes: Anthropic's models cache nothing without it, and
  /// OpenRouter's Gemini and Alibaba caching want breakpoints too). OpenAI's
  /// models cache by themselves and take other controls. Where caching is
  /// automatic (xAI, DeepSeek…) it is a parameter the provider does not take,
  /// which OpenRouter leaves out by default (provider routing,
  /// `require_parameters: false`).
  static bool cachesExplicitly(AiModel m) => !m.id.startsWith('openai/');

  /// Tool results of [m] carry their pictures inside the
  /// `function_call_output` (Anthropic's tool results and OpenAI's function
  /// outputs take pictures); for every other maker, and the routers, the
  /// pictures go in a user message right after the results.
  static bool picturesInToolOutputs(AiModel m) => m.id.startsWith('anthropic/') || m.id.startsWith('openai/');

  /// OpenRouter's PDF parser that costs nothing (`cloudflare-ai`), for the
  /// models that do not read files themselves: without it OpenRouter picks
  /// `mistral-ocr`, billed per page, again on every request of the
  /// conversation (the Responses API cannot send back the parsed copy).
  static const freeParser = [
    {
      'id': 'file-parser',
      'pdf': {'engine': 'cloudflare-ai'},
    },
  ];

  /// The request carries a PDF that OpenRouter, not the model, has to read.
  bool parsesFiles(AiRequest r) => !OpenRouterCatalog.readsFiles(r.model.id) && countMedia(r.history).$2 > 0;

  @override
  List<String> optionalFields(AiRequest r) => [if (cachesExplicitly(r.model)) 'cache_control', 'session_id', if (parsesFiles(r)) 'plugins'];

  @override
  Map<String, Object?> body(AiRequest r) {
    final m = r.model;
    final b = super.body(r)..remove('context_management');
    if (cachesExplicitly(m) && offers(m, 'cache_control')) b['cache_control'] = const {'type': 'ephemeral'};
    if (offers(m, 'session_id')) b['session_id'] = sessionOf(r);
    if (parsesFiles(r) && offers(m, 'plugins')) b['plugins'] = freeParser;
    return b;
  }

  /// The id of the conversation of [r] for OpenRouter's sticky routing: a
  /// hash of the system prompt and of the text of the first message, the
  /// same for every request of the conversation (and nothing that the
  /// request does not already carry).
  static String sessionOf(AiRequest r) {
    final first = r.history.isEmpty ? const <String, dynamic>{} : r.history.first;
    final text = StringBuffer(r.system);
    void walk(Object? o) {
      if (o is Map) {
        if (o['type'] == 'input_text' || o['type'] == 'output_text') text.write('\u0000${o['text']}');
        if (o['type'] == 'input_image' || o['type'] == 'input_file') text.write('\u0000#');
        for (final v in o.values) {
          if (v is Map || v is List) walk(v);
        }
      } else if (o is List) {
        for (final v in o) {
          walk(v);
        }
      }
    }

    walk(first);
    final s = text.toString();
    String hex(int seed) => _fnv(s, seed).toRadixString(16).padLeft(8, '0');
    return 'oci-${hex(0x811c9dc5)}${hex(0x01000193)}';
  }

  /// 32-bit FNV-1a, exact in the browser too (the product split in halves
  /// so that no value passes 2^53).
  static int _fnv(String s, int h) {
    for (var i = 0; i < s.length; i++) {
      h ^= s.codeUnitAt(i);
      h = ((h & 0xFFFF) * 0x01000193 + ((((h >>> 16) * 0x01000193) & 0xFFFF) << 16)) & 0xFFFFFFFF;
    }
    return h;
  }

  @override
  List<Map<String, dynamic>> inputOf(AiRequest r) {
    final items = withIds(super.inputOf(r));
    return picturesInToolOutputs(r.model) ? items : picturesAfterResults(items);
  }

  /// [items] with the fields OpenRouter requires of replayed output items
  /// where one is missing (an assistant message written by the program or
  /// kept from another API: `id` and `status`; a reasoning item: `id` and
  /// `summary`; a function call: `id`), made from the position so that they
  /// are the same in every request. Items that have them stay as they are.
  static List<Map<String, dynamic>> withIds(List<Map<String, dynamic>> items) {
    List<Map<String, dynamic>>? out;
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      Map<String, dynamic>? fixed;
      switch (it['type']) {
        case 'message' when it['role'] == 'assistant' && (it['id'] == null || it['status'] == null):
          fixed = {...it, 'id': it['id'] ?? 'msg_$i', 'status': it['status'] ?? 'completed'};
        case 'reasoning' when it['id'] == null || it['summary'] == null:
          fixed = {...it, 'id': it['id'] ?? 'rs_$i', 'summary': it['summary'] ?? const <Object?>[]};
        case 'function_call' when it['id'] == null:
          fixed = {...it, 'id': 'fc_${it['call_id'] ?? i}'};
      }
      if (fixed != null) (out ??= List.of(items))[i] = fixed;
    }
    return out ?? items;
  }

  /// What a tool result says when its pictures went after the results.
  static const picturesMoved = '[The pictures of this result are in the message after the tool results.]';

  /// The text that opens the pictures of one tool result ([name]: the tool).
  static String picturesOf(String name, String callId) => 'Pictures from the result of $name (call $callId):';

  /// [items] with the pictures of every run of function outputs taken out of
  /// them (each output says so) and put, in the same order, in one user
  /// message right after the run. The history keeps them where they were:
  /// only the request changes, the same way every time.
  static List<Map<String, dynamic>> picturesAfterResults(List<Map<String, dynamic>> items) {
    bool pictured(Map<String, dynamic> it) => it['type'] == 'function_call_output' && it['output'] is List && (it['output'] as List).any((p) => p is Map && p['type'] == 'input_image');
    if (!items.any(pictured)) return items;
    final names = {
      for (final it in items)
        if (it['type'] == 'function_call') '${it['call_id']}': '${it['name'] ?? ''}',
    };
    final out = <Map<String, dynamic>>[];
    var moved = <Map<String, dynamic>>[];
    void flush() {
      if (moved.isEmpty) return;
      out.add({'type': 'message', 'role': 'user', 'content': moved});
      moved = [];
    }

    for (final it in items) {
      if (it['type'] != 'function_call_output') flush();
      if (!pictured(it)) {
        out.add(it);
        continue;
      }
      final parts = (it['output'] as List).whereType<Map>().toList();
      final text = [
        for (final p in parts)
          if (p['type'] == 'input_text') '${p['text'] ?? ''}',
      ].join('\n');
      out.add({...it, 'output': text.isEmpty ? picturesMoved : '$text\n$picturesMoved'});
      final id = '${it['call_id'] ?? ''}';
      moved.add({'type': 'input_text', 'text': picturesOf(names[id] ?? 'a tool', id)});
      for (final p in parts) {
        if (p['type'] == 'input_image') moved.add(Map<String, dynamic>.from(p));
      }
    }
    flush();
    return out;
  }

  /// Events as OpenRouter sends them, in the shape [OpenAiClient] reads: a
  /// failed response carries the canonical `error_type` beside its `error`
  /// (moved into it, where [errorOf] reads it), and `response.done` (an
  /// older name in OpenRouter's examples) ends the answer as
  /// `response.completed` does.
  @override
  Map<String, dynamic>? eventOf(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'response.done':
        return {...event, 'type': 'response.completed'};
      case 'response.failed':
        final r = event['response'];
        if (r is Map && r['error_type'] != null) {
          final e = r['error'];
          return {
            ...event,
            'response': {
              ...r,
              'error': {if (e is Map) ...e, 'error_type': r['error_type']},
            },
          };
        }
    }
    return event;
  }

  /// US$ OpenRouter charged for the last answer read (its `usage.cost`; 0 for
  /// a free model, only OpenRouter's fee with the user's own provider key);
  /// null when the usage had none. The app prices tokens with its own table
  /// of list prices; this is the figure of OpenRouter's activity page, which
  /// goes with the usage ([AiUsage.charged]) and prices the answer of a
  /// model the table does not know (a router's pick).
  double? lastCost;

  @override
  AiUsage usageOf(Map<String, dynamic> usage) {
    final c = usage['cost'];
    lastCost = c is num ? c.toDouble() : null;
    return super.usageOf(usage).withCharged(lastCost);
  }

  /// Policy codes of a failed response that mean the request was declined
  /// (OpenAI's `invalid_prompt` is not one here: on OpenRouter it is any
  /// request that did not validate, a too long prompt among them).
  @override
  Set<String> get declinedCodes => const {'bio_policy', 'cyber_policy', 'misalignment_policy_violation', 'image_content_policy_violation'};

  @override
  AiError httpError(int status, String body, Map<String, String> headers) {
    Object? j;
    try {
      j = jsonDecode(body);
    } catch (_) {}
    final root = j is Map ? j : const {};
    final e = root['error'];
    final err = e is Map ? e : {'message': e is String ? e : (j == null ? body : '')};
    return _errorOf(status, {...err, if (root['error_type'] != null) 'error_type': root['error_type']}, headers);
  }

  @override
  AiError errorOf(Object? e) => _errorOf(null, e is Map ? e : const {}, const {});

  static final _contextFull = RegExp(r'context (length|window)|maximum context|too many (input )?tokens|prompt is too long|exceeds the context', caseSensitive: false);
  static final _perDay = RegExp(r'per[- _]day|daily', caseSensitive: false);

  /// The wait until a limit resets: `retry-after`, else OpenRouter's
  /// `X-RateLimit-Reset` (milliseconds since 1970), else, for a daily limit
  /// of the free models (counted by UTC day), until the next 00:00 UTC.
  /// The browser lets the page read none of these headers (OpenRouter does
  /// not expose them to CORS): there only the message tells.
  static Duration? waitOf(Map<String, String> headers, String message) {
    final asked = AiHttpClient.retryAfterOf(headers);
    if (asked != null) return asked;
    final now = clock().toUtc();
    final reset = num.tryParse(headers['x-ratelimit-reset']?.trim() ?? '');
    if (reset != null && reset > 0) {
      final ms = reset < 1e11 ? reset * 1000 : reset;
      final d = DateTime.fromMillisecondsSinceEpoch(ms.round(), isUtc: true).difference(now);
      if (d > Duration.zero) return d;
    }
    if (_perDay.hasMatch(message)) return DateTime.utc(now.year, now.month, now.day + 1).difference(now);
    return null;
  }

  /// The error of OpenRouter's error object [e] (its `code`, a number on the
  /// HTTP errors and a Responses code in the stream, `message`, `metadata`,
  /// and the canonical `error_type` wherever it came), of HTTP [status]
  /// (null inside a stream).
  AiError _errorOf(int? status, Map<dynamic, dynamic> e, Map<String, String> headers) {
    final meta = e['metadata'] is Map ? e['metadata'] as Map : const {};
    final code = '${e['code'] ?? ''}';
    final type = '${e['error_type'] ?? meta['error_type'] ?? ''}';
    final source = '${meta['limit_source'] ?? ''}';
    final message = clean('${e['message'] ?? ''}');
    final id = headers[requestIdHeader];
    final reasons = meta['reasons'] is List ? [for (final x in meta['reasons'] as List) '$x'] : const <String>[];
    if (type == 'content_policy_violation' || type == 'refusal' || declinedCodes.contains(code) || reasons.isNotEmpty) {
      return AiError(
        AiErrorKind.refusal,
        status: status,
        message: clean([if (reasons.isNotEmpty) reasons.join('; '), if (message.isNotEmpty) message].join(' — ')),
        category: reasons.isNotEmpty ? 'moderation' : (type.isNotEmpty ? type : code),
        requestId: id,
      );
    }
    final kind = _kind(status, type, code, source, message);
    return AiError(
      kind,
      status: status,
      message: message,
      retryAfter: kind == AiErrorKind.rateLimit || kind == AiErrorKind.overloaded ? waitOf(headers, message) : AiHttpClient.retryAfterOf(headers),
      requestId: id,
    );
  }

  static AiErrorKind _kind(int? status, String type, String code, String source, String message) {
    switch (source) {
      // running requests hold the spending budget: transient, a wait helps
      case 'openrouter_in_flight_budget':
        return AiErrorKind.rateLimit;
      case 'openrouter_guardrail_budget' || 'openrouter_workspace_budget' || 'openrouter_key_limit':
        return AiErrorKind.spendLimit;
      case 'openrouter_credits':
        return AiErrorKind.credit;
    }
    final byType = switch (type) {
      'context_length_exceeded' => AiErrorKind.contextWindow,
      'authentication' => AiErrorKind.auth,
      'permission_denied' => AiErrorKind.permission,
      'payment_required' => AiErrorKind.credit,
      'rate_limit_exceeded' => AiErrorKind.rateLimit,
      'provider_overloaded' => AiErrorKind.overloaded,
      'provider_unavailable' || 'server' || 'unmapped' => AiErrorKind.server,
      'timeout' => AiErrorKind.timeout,
      'not_found' => AiErrorKind.notFound,
      'payload_too_large' => AiErrorKind.tooLarge,
      'invalid_request' ||
      'invalid_prompt' ||
      'unprocessable' ||
      'precondition_failed' ||
      'max_tokens_exceeded' ||
      'token_limit_exceeded' ||
      'string_too_long' => _contextFull.hasMatch(message) ? AiErrorKind.contextWindow : AiErrorKind.invalidRequest,
      'invalid_image' || 'image_too_large' || 'image_too_small' || 'unsupported_image_format' || 'image_not_found' || 'image_download_failed' => AiErrorKind.invalidRequest,
      _ => null,
    };
    if (byType != null) return byType;
    final byCode = switch (code) {
      'invalid_api_key' => AiErrorKind.auth,
      'rate_limit_exceeded' => AiErrorKind.rateLimit,
      'permission_denied' || 'data_residency_mismatch' => AiErrorKind.permission,
      'flex_unavailable' => AiErrorKind.overloaded,
      'invalid_prompt' => _contextFull.hasMatch(message) ? AiErrorKind.contextWindow : AiErrorKind.invalidRequest,
      'server_error' || 'vector_store_timeout' => AiErrorKind.server,
      final c when c.startsWith('invalid_image') || c.startsWith('image_') || c.contains('_image_') || c == 'invalid_base64_image' || c == 'failed_to_download_image' => AiErrorKind.invalidRequest,
      _ => null,
    };
    if (byCode != null) return byCode;
    return switch (status) {
      null => _contextFull.hasMatch(message) ? AiErrorKind.contextWindow : AiErrorKind.invalidRequest,
      400 || 422 => _contextFull.hasMatch(message) ? AiErrorKind.contextWindow : AiErrorKind.invalidRequest,
      401 => AiErrorKind.auth,
      402 => AiErrorKind.credit,
      403 => AiErrorKind.permission,
      404 => AiErrorKind.notFound,
      408 || 504 => AiErrorKind.timeout,
      413 => AiErrorKind.tooLarge,
      429 => AiErrorKind.rateLimit,
      503 => AiErrorKind.overloaded,
      final int s when s >= 500 => AiErrorKind.server,
      _ => AiErrorKind.http,
    };
  }
}
