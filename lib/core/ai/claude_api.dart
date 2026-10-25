/// Anthropic's Messages API (`POST /v1/messages`, API version 2026-10-21) as
/// the AI assistant uses it: called straight from the user's browser or
/// desktop with the user's own Anthropic key, no server in between.
///
/// Pure Dart; the HTTP exchange is injected ([AiTransport]). Requests stream
/// (server-sent events) and carry adaptive thinking (always on, and not to
/// be set, on Claude Fable 5.1), an explicit effort, prompt caching, the
/// server-side refusal fallback where the model takes it, a task budget
/// when one is set, and threshold compaction for long sessions. The history
/// is append-only: answers go back exactly as they came (thinking blocks
/// with their signatures), and after a compaction only the summary onward
/// is sent. The key goes in a header of the request to Anthropic and
/// nowhere else.
library;

import 'dart:convert';

import 'llm.dart';
import 'llm_formats.dart';

export 'llm.dart';

/// Content of an answer as it is echoed back: after a server-side fallback
/// in the middle of an answer, the thinking and tool-use blocks before the
/// last `fallback` block are left out (only their text counts), and the
/// marker itself is dropped.
List<Map<String, dynamic>> echoContent(List<Map<String, dynamic>> blocks) {
  final last = blocks.lastIndexWhere((b) => b['type'] == 'fallback');
  if (last < 0) return blocks;
  return [
    for (var i = 0; i < blocks.length; i++)
      if (i > last || (i < last && blocks[i]['type'] == 'text')) blocks[i],
  ];
}

/// Messages from the last compaction on (the API ignores what comes before
/// a compaction block, so it need not travel).
List<Map<String, dynamic>> sinceCompaction(List<Map<String, dynamic>> messages) {
  for (var i = messages.length - 1; i > 0; i--) {
    final c = messages[i]['content'];
    if (messages[i]['role'] == 'assistant' && c is List && c.any((b) => b is Map && b['type'] == 'compaction')) return messages.sublist(i);
  }
  return messages;
}

/// Client of the Messages API.
class AnthropicClient extends AiHttpClient {
  AnthropicClient({required super.apiKey, required super.transport, this.browser = false, super.sleep, super.maxRetries});

  static final endpoint = Uri.parse('https://api.anthropic.com/v1/messages');
  static const apiVersion = '2026-10-21';
  static const fallbackBeta = 'server-side-fallback-2026-07-01';
  static const taskBudgetBeta = 'task-budgets-2026-03-13';
  static const compactionBeta = 'compact-2026-01-12';
  static const contextEditingBeta = 'context-management-2025-06-27';

  /// Old tool results are cleared on the server past this many input
  /// tokens (pictures above all), the last [keepToolUses] kept.
  static const clearAt = 80000;
  static const keepToolUses = 4;

  /// Results never cleared: what the model needs for the whole task.
  static const keptTools = ['get_notes', 'get_playbook', 'read_manual', 'ask_user', 'present_plan', 'update_todo', 'find_operations'];

  /// Least task budget the API takes.
  static const minTaskBudget = 20000;

  /// Least compaction threshold the API takes.
  static const minCompactAt = 50000;

  /// Sent from a web page: the API wants the direct-browser-access header
  /// (without it the answer has no CORS headers and the browser blocks it).
  final bool browser;

  @override
  AiProvider get provider => AiProvider.anthropic;

  bool _fallback(AiRequest r) => r.model.serverFallback && offers(r.model, 'fallbacks');
  bool _budget(AiRequest r) => r.taskBudget != null && r.model.taskBudget && offers(r.model, 'task_budget');
  bool _compact(AiRequest r) => r.compactAt != null && r.model.compaction && offers(r.model, 'context_management');

  /// Clearing of old tool results goes with compaction (both keep the
  /// history as sent: the server edits its own copy).
  bool _clear(AiRequest r) => _compact(r) && offers(r.model, 'clear_tool_uses');

  @override
  List<String> optionalFields(AiRequest r) => [if (_fallback(r)) 'fallbacks', if (_budget(r)) 'task_budget', if (_clear(r)) 'clear_tool_uses', if (_compact(r)) 'context_management'];

  /// A complaint about context management drops the clearing first, then
  /// compaction.
  @override
  String? declinedField(AiRequest r, String message) {
    const about = ['clear_tool_uses', 'context_management', 'context-management', 'exclude_tools'];
    if (_clear(r) && about.any(message.contains)) return 'clear_tool_uses';
    return super.declinedField(r, message);
  }

  Map<String, String> headers(AiRequest r) {
    final betas = [if (_fallback(r)) fallbackBeta, if (_budget(r)) taskBudgetBeta, if (_clear(r)) contextEditingBeta, if (_compact(r)) compactionBeta];
    return {
      'content-type': 'application/json',
      'x-api-key': apiKey.trim(),
      'anthropic-version': apiVersion,
      if (browser) 'anthropic-dangerous-direct-browser-access': 'true',
      if (betas.isNotEmpty) 'anthropic-beta': betas.join(','),
    };
  }

  /// The request body. The tools and the system prompt are cached by the
  /// breakpoint at the end of the system prompt, the growing conversation
  /// by automatic caching.
  Map<String, Object?> body(AiRequest r) => {
    'model': r.model.id,
    'max_tokens': r.maxTokens,
    'stream': true,
    'system': [
      {
        'type': 'text',
        'text': r.system,
        'cache_control': {'type': 'ephemeral'},
      },
    ],
    if (r.tools.isNotEmpty) 'tools': [for (final s in r.tools) AnthropicFormat.tool(s)],
    'messages': sinceCompaction(r.history),
    // thinking is always on for Claude Fable 5.1, which takes no setting
    if (!r.model.alwaysThinks) 'thinking': {'type': 'adaptive'},
    'output_config': {
      'effort': r.effort.name,
      if (_budget(r)) 'task_budget': {'type': 'tokens', 'total': r.taskBudget! < minTaskBudget ? minTaskBudget : r.taskBudget},
    },
    'cache_control': {'type': 'ephemeral'},
    if (_fallback(r)) 'fallbacks': 'default',
    if (_compact(r))
      'context_management': {
        'edits': [
          if (_clear(r))
            {
              'type': 'clear_tool_uses_20250919',
              'trigger': {'type': 'input_tokens', 'value': clearAt},
              'keep': {'type': 'tool_uses', 'value': keepToolUses},
              'clear_at_least': {'type': 'input_tokens', 'value': 10000},
              'exclude_tools': [
                for (final n in keptTools)
                  if (r.tools.any((t) => t.name == n)) n,
              ],
            },
          {
            'type': 'compact_20260112',
            'trigger': {'type': 'input_tokens', 'value': r.compactAt! < minCompactAt ? minCompactAt : r.compactAt},
          },
        ],
      },
  };

  @override
  Map<String, dynamic> userMessage(List<AiPart> parts) => AnthropicFormat.user(parts);

  @override
  List<Map<String, dynamic>> toolResults(List<AiToolResult> results, {List<AiPart> user = const [], String? note}) => AnthropicFormat.toolResults(results, user: user, note: note);

  @override
  Future<AiReply> attempt(AiRequest r, AiCancel cancel, AiStreamListener listener) async {
    final req = AiHttpRequest(endpoint, headers(r), jsonEncode(body(r)));
    final res = await open(req, r.model, cancel);
    if (res.status < 200 || res.status >= 300) {
      final text = await readAll(res.body, r.model, cancel);
      throw _httpError(r.model, res.status, text, res.headers);
    }
    if (!(res.headers['content-type'] ?? '').contains('event-stream')) {
      final text = await readAll(res.body, r.model, cancel);
      final Object? j;
      try {
        j = jsonDecode(text);
      } catch (_) {
        throw AiError(AiErrorKind.http, status: res.status, message: clean(text));
      }
      if (j is! Map<String, dynamic>) throw AiError(AiErrorKind.http, status: res.status);
      final acc = _Accumulator(listener, (e) => streamError(r.model, e, clean))..whole(j);
      return acc.finish();
    }
    final acc = _Accumulator(listener, (e) => streamError(r.model, e, clean));
    final sse = SseReader(acc.event);
    try {
      await readLines(res.body, r.model, sse.line, cancel);
      sse.close();
    } on AiError catch (e) {
      throw acc.sawText ? e.withPartial() : e;
    }
    return acc.finish();
  }

  static final _retention = RegExp(r'data retention|zero[- ]data', caseSensitive: false);

  static AiErrorKind _kindOf(String type, int? status) => switch (type) {
    'authentication_error' => AiErrorKind.auth,
    'permission_error' => AiErrorKind.permission,
    'billing_error' => AiErrorKind.billing,
    'not_found_error' => AiErrorKind.notFound,
    'request_too_large' => AiErrorKind.tooLarge,
    'rate_limit_error' => AiErrorKind.rateLimit,
    'overloaded_error' => AiErrorKind.overloaded,
    'invalid_request_error' => AiErrorKind.invalidRequest,
    'api_error' => AiErrorKind.server,
    _ => switch (status) {
      401 => AiErrorKind.auth,
      402 => AiErrorKind.billing,
      403 => AiErrorKind.permission,
      404 => AiErrorKind.notFound,
      413 => AiErrorKind.tooLarge,
      429 => AiErrorKind.rateLimit,
      529 => AiErrorKind.overloaded,
      400 => AiErrorKind.invalidRequest,
      null => AiErrorKind.server,
      >= 500 => AiErrorKind.server,
      _ => AiErrorKind.http,
    },
  };

  /// A model that needs 30-day data retention, asked from an organisation
  /// without it, is a rejected request whose message says so.
  static AiErrorKind _refine(AiModel m, AiErrorKind k, String message) => k == AiErrorKind.invalidRequest && m.needsRetention && _retention.hasMatch(message) ? AiErrorKind.retention : k;

  AiError _httpError(AiModel m, int status, String body, Map<String, String> headers) {
    var type = '', message = '';
    String? requestId = headers['request-id'];
    try {
      final j = jsonDecode(body);
      if (j is Map) {
        final e = j['error'];
        if (e is Map) {
          type = '${e['type'] ?? ''}';
          message = '${e['message'] ?? ''}';
        }
        requestId ??= j['request_id'] as String?;
      }
    } catch (_) {
      message = body;
    }
    final kind = _refine(m, _kindOf(type, status), message);
    return AiError(kind, status: status, message: clean(message), retryAfter: AiHttpClient.retryAfterOf(headers), requestId: requestId);
  }

  /// The error of an `error` event in the stream.
  static AiError streamError(AiModel m, Object? error, String Function(String) clean) {
    final e = error is Map ? error : const {};
    final message = '${e['message'] ?? ''}';
    return AiError(_refine(m, _kindOf('${e['type'] ?? ''}', null), message), message: clean(message));
  }
}

/// Builds the answer from the server-sent events (or a whole message).
class _Accumulator {
  _Accumulator(this.listener, this.error);
  final AiStreamListener listener;
  final AiError Function(Object? error) error;
  final Map<int, Map<String, dynamic>> _blocks = {};
  final Map<int, StringBuffer> _json = {};
  final Map<String, String> _invalid = {};
  String? _stopReason, _category, _explanation;
  String _model = '';
  Map<String, dynamic> _usage = {};
  bool _stopped = false;
  bool sawText = false;

  void _mergeUsage(Object? u) {
    if (u is Map) _usage = {..._usage, ...Map<String, dynamic>.from(u)};
  }

  void _details(Object? d) {
    if (d is! Map) return;
    _category = d['category'] as String? ?? _category;
    _explanation = d['explanation'] as String? ?? _explanation;
  }

  /// A non-streamed message.
  void whole(Map<String, dynamic> m) {
    var i = 0;
    for (final b in (m['content'] as List? ?? const [])) {
      if (b is Map) _blocks[i++] = Map<String, dynamic>.from(b);
    }
    _model = m['model'] as String? ?? '';
    _stopReason = m['stop_reason'] as String? ?? 'end_turn';
    _details(m['stop_details']);
    _mergeUsage(m['usage']);
    _stopped = true;
  }

  void event(Map<String, dynamic> e) {
    listener.onActivity?.call();
    switch (e['type']) {
      case 'message_start':
        final m = e['message'];
        if (m is Map) {
          _model = m['model'] as String? ?? _model;
          _mergeUsage(m['usage']);
        }
      case 'content_block_start':
        final i = (e['index'] as num).toInt();
        final b = Map<String, dynamic>.from(e['content_block'] as Map);
        _blocks[i] = b;
        if (b['type'] == 'tool_use') {
          _json[i] = StringBuffer();
          listener.onToolStart?.call(b['name'] as String? ?? '');
        }
        if (b['type'] == 'text' && (b['text'] as String? ?? '').isNotEmpty) {
          sawText = true;
          listener.onText?.call(b['text'] as String);
        }
      case 'content_block_delta':
        final i = (e['index'] as num).toInt();
        final b = _blocks[i];
        final d = e['delta'];
        if (b == null || d is! Map) return;
        switch (d['type']) {
          case 'text_delta':
            final s = d['text'] as String? ?? '';
            b['text'] = '${b['text'] ?? ''}$s';
            if (s.isNotEmpty) {
              sawText = true;
              listener.onText?.call(s);
            }
          case 'thinking_delta':
            b['thinking'] = '${b['thinking'] ?? ''}${d['thinking'] ?? ''}';
          case 'signature_delta':
            b['signature'] = '${b['signature'] ?? ''}${d['signature'] ?? ''}';
          case 'input_json_delta':
            _json[i]?.write(d['partial_json'] ?? '');
          case 'citations_delta':
            ((b['citations'] ??= <Object?>[]) as List<Object?>).add(d['citation']);
          case 'compaction_delta':
            // the whole summary in one delta
            b['content'] = '${b['content'] ?? ''}${d['content'] ?? ''}';
        }
      case 'content_block_stop':
        final i = (e['index'] as num).toInt();
        final b = _blocks[i];
        final raw = _json.remove(i)?.toString();
        if (b == null || raw == null) return;
        final (input, bad) = parseToolInput(raw);
        b['input'] = input ?? <String, dynamic>{};
        if (bad != null) _invalid[b['id'] as String? ?? '$i'] = bad;
      case 'message_delta':
        final d = e['delta'];
        if (d is Map) {
          _stopReason = d['stop_reason'] as String? ?? _stopReason;
          _details(d['stop_details']);
        }
        _details(e['stop_details']);
        _mergeUsage(e['usage']);
      case 'message_stop':
        _stopped = true;
      case 'error':
        throw error(e['error']);
      default:
        break; // ping and event types added later
    }
  }

  /// Tokens of the answer; a compaction in it is billed on top (its
  /// iteration is not in the top-level counts).
  AiUsage _usageOf() {
    int v(Map u, String k) => (u[k] as num?)?.toInt() ?? 0;
    var extraIn = 0, extraOut = 0;
    for (final it in (_usage['iterations'] as List? ?? const [])) {
      if (it is Map && it['type'] == 'compaction') {
        extraIn += v(it, 'input_tokens');
        extraOut += v(it, 'output_tokens');
      }
    }
    return AiUsage(
      input: v(_usage, 'input_tokens') + extraIn,
      output: v(_usage, 'output_tokens') + extraOut,
      cacheWrite: v(_usage, 'cache_creation_input_tokens'),
      cacheRead: v(_usage, 'cache_read_input_tokens'),
    );
  }

  AiReply finish() {
    if (!_stopped && _stopReason == null) throw AiError(AiErrorKind.interrupted, partial: sawText);
    final keys = _blocks.keys.toList()..sort();
    final content = echoContent([for (final k in keys) _blocks[k]!]);
    final calls = AnthropicFormat.calls(content, invalid: _invalid);
    final text = AnthropicFormat.text(content);
    final compacted = content.any((b) => b['type'] == 'compaction');
    final keep = compacted || calls.isNotEmpty || text.isNotEmpty;
    return AiReply(
      items: keep
          ? [
              {'role': 'assistant', 'content': content},
            ]
          : const [],
      text: text,
      calls: calls,
      stop: switch (_stopReason) {
        'tool_use' => AiStop.tool,
        'max_tokens' || 'model_context_window_exceeded' => AiStop.maxTokens,
        'refusal' => AiStop.refusal,
        _ => AiStop.end,
      },
      model: _model,
      usage: _usageOf(),
      category: _category,
      explanation: _explanation ?? '',
      compacted: compacted,
    );
  }
}

// The names of the first version of this library, when it spoke to
// Anthropic only; kept for code written against them.

typedef ClaudeApi = AnthropicClient;
typedef ClaudeModel = AiModel;
typedef ClaudeEffort = AiEffort;
typedef ClaudeUsage = AiUsage;
typedef ClaudeError = AiError;
typedef ClaudeErrorKind = AiErrorKind;
typedef ClaudeCancel = AiCancel;
typedef ClaudeTransport = AiTransport;
typedef ClaudeHttpRequest = AiHttpRequest;
typedef ClaudeHttpResponse = AiHttpResponse;
typedef ClaudeStreamListener = AiStreamListener;
