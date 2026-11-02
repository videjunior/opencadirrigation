/// Anthropic's Messages API (`POST /v1/messages`, API version 2026-10-21) as
/// the AI assistant uses it: called straight from the user's browser or
/// desktop with the user's own Anthropic key, no server in between.
///
/// Pure Dart; the HTTP exchange is injected ([AiTransport]). Requests stream
/// (server-sent events) and carry adaptive thinking (always on on Claude
/// Fable 5.1) with the model's notes between tool calls returned as text
/// where it writes them, an explicit effort, prompt caching, the
/// server-side refusal fallback where the model takes it, a task budget
/// when one is set, and threshold compaction for long sessions. The history
/// is append-only: answers go back exactly as they came (thinking blocks
/// with their signatures), and after a compaction only the summary onward
/// is sent; the one exception is the recovery from a thinking block the
/// API no longer accepts ([stripThinking]). The key goes in a header of the
/// request to Anthropic and nowhere else.
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

/// [messages] without their thinking blocks (`thinking` and
/// `redacted_thinking`): every one from block [from] (message index, block
/// index) on, or all when [from] is null. Text, tool calls and the rest
/// stay; a message that would be left empty stays as it was.
List<Map<String, dynamic>> stripThinking(List<Map<String, dynamic>> messages, {(int, int)? from}) {
  bool thinking(Object? b) => b is Map && (b['type'] == 'thinking' || b['type'] == 'redacted_thinking');
  return [
    for (var i = 0; i < messages.length; i++)
      if (from != null && i < from.$1 || messages[i]['role'] != 'assistant' || messages[i]['content'] is! List)
        messages[i]
      else
        () {
          final c = messages[i]['content'] as List;
          final kept = [
            for (var j = 0; j < c.length; j++)
              if (!thinking(c[j]) || (from != null && i == from.$1 && j < from.$2)) c[j],
          ];
          return kept.length == c.length || kept.isEmpty ? messages[i] : {...messages[i], 'content': kept};
        }(),
  ];
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
  static const displayBeta = 'thinking-display-updates-2026-08-18';

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

  /// The text of a progress block that stands in for work an answer cut
  /// short did not finish (not a note to show).
  static const interruptedNote = 'This part of the response was interrupted before it finished.';

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

  /// The model's notes between tool calls come back as text.
  bool _updates(AiRequest r) => r.model.progressUpdates && offers(r.model, 'display');

  @override
  List<String> optionalFields(AiRequest r) => [
    if (_fallback(r)) 'fallbacks',
    if (_budget(r)) 'task_budget',
    if (_clear(r)) 'clear_tool_uses',
    if (_compact(r)) 'context_management',
    if (_updates(r)) 'display',
  ];

  /// A complaint about context management drops the clearing first, then
  /// compaction; a beta the account does not have drops its field.
  @override
  String? declinedField(AiRequest r, String message) {
    const about = ['clear_tool_uses', 'context_management', 'context-management', 'exclude_tools'];
    if (_clear(r) && about.any(message.contains)) return 'clear_tool_uses';
    if (_updates(r) && (message.contains('display') || message.contains(displayBeta))) return 'display';
    final fields = optionalFields(r);
    for (final (beta, field) in const [(fallbackBeta, 'fallbacks'), (taskBudgetBeta, 'task_budget'), (compactionBeta, 'context_management')]) {
      if (message.contains(beta) && fields.contains(field)) return field;
    }
    return super.declinedField(r, message);
  }

  Map<String, String> headers(AiRequest r) {
    final betas = [if (_fallback(r)) fallbackBeta, if (_budget(r)) taskBudgetBeta, if (_clear(r)) contextEditingBeta, if (_compact(r)) compactionBeta, if (_updates(r)) displayBeta];
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
    'max_tokens': r.outputTokens,
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
    // adaptive thinking with the notes between tool calls as text; thinking
    // is always on for Claude Fable 5.1, which takes no other setting (an
    // explicit adaptive one included), so without the notes it gets none
    if (_updates(r)) 'thinking': {'type': 'adaptive', 'display': 'updates'} else if (!r.model.alwaysThinks) 'thinking': {'type': 'adaptive'},
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

  static final _signature = RegExp(r'Invalid `?signature`? in `?thinking`? block', caseSensitive: false);
  static final _position = RegExp(r'messages\.(\d+)\.content\.(\d+)');

  /// A thinking block the API no longer accepts ("bound to a different
  /// conversation": the conversation before it is not byte for byte what
  /// produced it): the block and every thinking block after it leave the
  /// history, once; should that not do, every thinking block, once more.
  /// Text and tool calls stay, and so does the stripped history afterwards.
  @override
  AiRequest? recover(AiRequest r, AiError e, int tries) {
    if (tries >= 2 || !_signature.hasMatch(e.message)) return null;
    (int, int)? from;
    final at = tries == 0 ? _position.firstMatch(e.message) : null;
    if (at != null) {
      // positions count in the messages sent: from the last compaction on
      final offset = r.history.length - sinceCompaction(r.history).length;
      final i = int.parse(at.group(1)!) + offset, j = int.parse(at.group(2)!);
      final c = i < r.history.length ? r.history[i]['content'] : null;
      final b = c is List && j < c.length ? c[j] : null;
      if (b is Map && (b['type'] == 'thinking' || b['type'] == 'redacted_thinking')) from = (i, j);
    }
    final h = stripThinking(r.history, from: from);
    var changed = false;
    for (var k = 0; k < h.length && !changed; k++) {
      changed = !identical(h[k], r.history[k]);
    }
    return changed ? r.withHistory(h) : null;
  }

  @override
  Future<AiReply> attempt(AiRequest r, AiCancel cancel, AiStreamListener listener) async {
    final json = jsonEncode(body(r));
    AiHttpClient.checkSize(json);
    final req = AiHttpRequest(endpoint, headers(r), json);
    final res = await open(req, r.model, cancel);
    final id = res.headers['request-id'];
    final idle = idleTimeout(r.model, r.effort);
    if (res.status < 200 || res.status >= 300) {
      final text = await readAll(res.body, r.model, cancel, idle: idle);
      throw _httpError(r.model, res.status, text, res.headers);
    }
    final acc = _Accumulator(listener, (e) => streamError(r.model, e, clean).withRequestId(id), requested: r.model.id);
    if (!(res.headers['content-type'] ?? '').contains('event-stream')) {
      final text = await readAll(res.body, r.model, cancel, idle: idle);
      final Object? j;
      try {
        j = jsonDecode(text);
      } catch (_) {
        throw AiError(AiErrorKind.http, status: res.status, message: clean(text), requestId: id);
      }
      if (j is! Map<String, dynamic>) throw AiError(AiErrorKind.http, status: res.status, requestId: id);
      acc.whole(j);
      return acc.finish();
    }
    final sse = SseReader(acc.event);
    try {
      await readLines(res.body, r.model, sse.line, cancel, idle: idle);
      sse.close();
      return acc.finish();
    } on AiError catch (e) {
      final x = e.withRequestId(id);
      throw acc.sawText ? x.withPartial() : x;
    }
  }

  static final _retention = RegExp(r'data retention|zero[- ]data', caseSensitive: false);
  static final _credit = RegExp(r'credit balance', caseSensitive: false);
  static final _spend = RegExp(r'reached your (specified )?(workspace )?API usage limits', caseSensitive: false);
  static final _context = RegExp(r'prompt is too long|context (window|length|limit)', caseSensitive: false);

  static AiErrorKind _kindOf(String type, int? status) => switch (type) {
    'authentication_error' => AiErrorKind.auth,
    'permission_error' => AiErrorKind.permission,
    'billing_error' => AiErrorKind.billing,
    'not_found_error' => AiErrorKind.notFound,
    'request_too_large' => AiErrorKind.tooLarge,
    'rate_limit_error' => AiErrorKind.rateLimit,
    'overloaded_error' => AiErrorKind.overloaded,
    'invalid_request_error' => AiErrorKind.invalidRequest,
    'timeout_error' => AiErrorKind.timeout,
    'api_error' => AiErrorKind.server,
    _ => switch (status) {
      401 => AiErrorKind.auth,
      402 => AiErrorKind.billing,
      403 => AiErrorKind.permission,
      404 => AiErrorKind.notFound,
      413 => AiErrorKind.tooLarge,
      429 => AiErrorKind.rateLimit,
      504 => AiErrorKind.timeout,
      529 => AiErrorKind.overloaded,
      400 => AiErrorKind.invalidRequest,
      null => AiErrorKind.server,
      >= 500 => AiErrorKind.server,
      _ => AiErrorKind.http,
    },
  };

  /// What a rejection is about, from its message and `details.error_code`:
  /// no credit left, a spending limit, a prompt longer than the context
  /// window, and a model that needs 30-day data retention asked from an
  /// organisation without it.
  static AiErrorKind _refine(AiModel m, AiErrorKind k, String message, [String code = '']) {
    if (code == 'enforced_spend_limit_reached') return AiErrorKind.spendLimit;
    if ((k == AiErrorKind.invalidRequest || k == AiErrorKind.billing) && _credit.hasMatch(message)) return AiErrorKind.credit;
    if (k != AiErrorKind.invalidRequest) return k;
    if (m.needsRetention && _retention.hasMatch(message)) return AiErrorKind.retention;
    if (_spend.hasMatch(message)) return AiErrorKind.spendLimit;
    if (_context.hasMatch(message)) return AiErrorKind.contextWindow;
    return k;
  }

  static String? _str(Object? o) => o is String ? o : null;

  AiError _httpError(AiModel m, int status, String body, Map<String, String> headers) {
    var type = '', message = '', code = '';
    var requestId = headers['request-id'];
    try {
      final j = jsonDecode(body);
      if (j is Map) {
        final e = j['error'];
        if (e is Map) {
          type = '${e['type'] ?? ''}';
          message = '${e['message'] ?? ''}';
          final d = e['details'];
          if (d is Map) code = '${d['error_code'] ?? ''}';
        }
        requestId ??= _str(j['request_id']);
      }
    } catch (_) {
      message = body;
    }
    final kind = _refine(m, _kindOf(type, status), message, code);
    return AiError(kind, status: status, message: clean(message), retryAfter: AiHttpClient.retryAfterOf(headers), requestId: requestId);
  }

  /// The error of an `error` event in the stream.
  static AiError streamError(AiModel m, Object? error, String Function(String) clean) {
    final e = error is Map ? error : const {};
    final message = '${e['message'] ?? ''}';
    final d = e['details'];
    return AiError(_refine(m, _kindOf('${e['type'] ?? ''}', null), message, d is Map ? '${d['error_code'] ?? ''}' : ''), message: clean(message));
  }
}

/// Builds the answer from the server-sent events (or a whole message).
class _Accumulator {
  _Accumulator(this.listener, this.error, {this.requested = ''});
  final AiStreamListener listener;
  final AiError Function(Object? error) error;

  /// The model asked for: an attempt of the server's that names no model
  /// of its own ran on it.
  final String requested;
  final Map<int, Map<String, dynamic>> _blocks = {};
  final Map<int, StringBuffer> _json = {};
  final Map<String, String> _invalid = {};
  String? _stopReason, _category, _explanation, _recommended;
  String _model = '';
  Map<String, dynamic> _usage = {};
  bool _stopped = false;
  bool sawText = false;

  static String? _str(Object? o) => o is String ? o : null;
  static int? _index(Map e) => e['index'] is num ? (e['index'] as num).toInt() : null;

  void _mergeUsage(Object? u) {
    if (u is Map) _usage = {..._usage, ...Map<String, dynamic>.from(u)};
  }

  void _details(Object? d) {
    if (d is! Map) return;
    _category = _str(d['category']) ?? _category;
    _explanation = _str(d['explanation']) ?? _explanation;
    _recommended = _str(d['recommended_model']) ?? _recommended;
  }

  /// A thinking block with text is a note on the model's progress (its
  /// reasoning stays hidden: it never comes back as text here).
  void _note(Object? thinking) {
    final s = _str(thinking)?.trim() ?? '';
    if (s.isNotEmpty && s != AnthropicClient.interruptedNote) listener.onThinking?.call(s);
  }

  /// A non-streamed message.
  void whole(Map<String, dynamic> m) {
    var i = 0;
    for (final b in (m['content'] is List ? m['content'] as List : const [])) {
      if (b is Map) {
        _blocks[i++] = Map<String, dynamic>.from(b);
        if (b['type'] == 'thinking') _note(b['thinking']);
      }
    }
    _model = _str(m['model']) ?? '';
    _stopReason = _str(m['stop_reason']) ?? 'end_turn';
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
          _model = _str(m['model']) ?? _model;
          _mergeUsage(m['usage']);
        }
      case 'content_block_start':
        final i = _index(e);
        final start = e['content_block'];
        if (i == null || start is! Map) return;
        final b = Map<String, dynamic>.from(start);
        _blocks[i] = b;
        if (b['type'] == 'tool_use') {
          _json[i] = StringBuffer();
          listener.onToolStart?.call(_str(b['name']) ?? '');
        }
        if (b['type'] == 'thinking') _note(b['thinking']);
        final t = _str(b['text']) ?? '';
        if (b['type'] == 'text' && t.isNotEmpty) {
          sawText = true;
          listener.onText?.call(t);
        }
      case 'content_block_delta':
        final i = _index(e);
        final b = i == null ? null : _blocks[i];
        final d = e['delta'];
        if (b == null || d is! Map) return;
        switch (d['type']) {
          case 'text_delta':
            final s = _str(d['text']) ?? '';
            b['text'] = '${b['text'] ?? ''}$s';
            if (s.isNotEmpty) {
              sawText = true;
              listener.onText?.call(s);
            }
          case 'thinking_delta':
            final s = _str(d['thinking']) ?? '';
            b['thinking'] = '${b['thinking'] ?? ''}$s';
            // under display "updates" a block with text is a progress note
            if (s.isNotEmpty) _note(b['thinking']);
          case 'signature_delta':
            b['signature'] = '${b['signature'] ?? ''}${d['signature'] ?? ''}';
          case 'input_json_delta':
            _json[i]?.write(d['partial_json'] ?? '');
          case 'citations_delta':
            final list = b['citations'];
            if (list is List) {
              list.add(d['citation']);
            } else {
              b['citations'] = <Object?>[d['citation']];
            }
          case 'compaction_delta':
            // the whole summary in one delta
            b['content'] = '${b['content'] ?? ''}${d['content'] ?? ''}';
        }
      case 'content_block_stop':
        final i = _index(e);
        final b = i == null ? null : _blocks[i];
        final raw = i == null ? null : _json.remove(i)?.toString();
        if (b == null || raw == null) return;
        final (input, bad) = parseToolInput(raw);
        b['input'] = input ?? <String, dynamic>{};
        if (bad != null) _invalid['${b['id'] ?? i}'] = bad;
      case 'message_delta':
        final d = e['delta'];
        if (d is Map) {
          _stopReason = _str(d['stop_reason']) ?? _stopReason;
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

  /// Tokens of the request and, when the server ran more than the answer
  /// (a compaction; an attempt declined before a fallback model took
  /// over), each attempt with the model that ran it. The top-level counts
  /// are those of the attempt that produced the message (the fallback
  /// model's when one served it); the others come from `usage.iterations`.
  (AiUsage, List<(String, AiUsage)>) _billing() {
    int v(Map u, String k) => u[k] is num ? (u[k] as num).toInt() : 0;
    AiUsage of(Map u) => AiUsage(input: v(u, 'input_tokens'), output: v(u, 'output_tokens'), cacheWrite: v(u, 'cache_creation_input_tokens'), cacheRead: v(u, 'cache_read_input_tokens'));
    final top = of(_usage);
    final its = [
      if (_usage['iterations'] is List)
        for (final it in _usage['iterations'] as List)
          if (it is Map) it,
    ];
    if (its.isEmpty) return (top, const []);
    var serving = its.lastIndexWhere((it) => it['type'] == 'fallback_message');
    if (serving < 0) serving = its.lastIndexWhere((it) => it['type'] == 'message');
    final billed = <(String, AiUsage)>[
      for (var k = 0; k < its.length; k++)
        if (k == serving) (_str(its[k]['model']) ?? _model, top) else (_str(its[k]['model']) ?? requested, of(its[k])),
      if (serving < 0) (_model, top),
    ];
    var total = AiUsage.zero;
    for (final (_, u) in billed) {
      total += u;
    }
    return (total, billed);
  }

  AiReply finish() {
    if (!_stopped && _stopReason == null) throw AiError(AiErrorKind.interrupted, partial: sawText);
    final keys = _blocks.keys.toList()..sort();
    final content = echoContent([for (final k in keys) _blocks[k]!]);
    final calls = AnthropicFormat.calls(content, invalid: _invalid);
    final text = AnthropicFormat.text(content);
    final compacted = content.any((b) => b['type'] == 'compaction');
    final keep = compacted || calls.isNotEmpty || text.isNotEmpty;
    final (usage, billed) = _billing();
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
        'max_tokens' => AiStop.maxTokens,
        'model_context_window_exceeded' => AiStop.contextWindow,
        'refusal' => AiStop.refusal,
        'pause_turn' => AiStop.pause,
        _ => AiStop.end,
      },
      model: _model,
      usage: usage,
      billed: billed,
      category: _category,
      explanation: _explanation ?? '',
      recommendedModel: _recommended,
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
