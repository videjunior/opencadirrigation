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

/// Whether block [b] may carry a cache breakpoint (thinking blocks may not).
bool _cacheable(Object? b) => b is Map && const {'text', 'image', 'tool_use', 'tool_result', 'document'}.contains(b['type']);

/// The blocks of [messages] where the cache looks back from: a run of
/// tool_use blocks, or of tool_result blocks, is one position, any other
/// block one. Each position is given by its last block (message index,
/// block index), the last position first.
List<(int, int)> cachePositions(List<Map<String, dynamic>> messages) {
  final out = <(int, int)>[];
  String? run;
  for (var i = messages.length - 1; i >= 0; i--) {
    final c = messages[i]['content'];
    if (c is! List) {
      out.add((i, -1));
      run = null;
      continue;
    }
    for (var j = c.length - 1; j >= 0; j--) {
      final b = c[j];
      final type = b is Map ? b['type'] : null;
      if ((type == 'tool_use' || type == 'tool_result') && type == run) continue;
      run = type == 'tool_use' || type == 'tool_result' ? type as String : null;
      out.add((i, j));
    }
  }
  return out;
}

/// [messages] with cache breakpoints of [marker] inside the newest content:
/// the cache finds the entry of the request before only within 20
/// positions ([cachePositions]) of a breakpoint, and an answer with many
/// tool calls between progress notes adds more than that (every request
/// would then write the whole conversation again). Within the last two
/// messages (what a request adds to the one before it: the model's answer
/// and the results), one breakpoint 15 positions from the end when they
/// hold more than 20, a second one 30 from the end when they hold more than
/// 35. [atEnd] also marks the last block (a request without automatic
/// caching). The messages given are not changed: the marked ones are
/// copies (a breakpoint is not part of what the cache or the thinking
/// signatures compare).
List<Map<String, dynamic>> withCacheMarkers(List<Map<String, dynamic>> messages, Map<String, Object?> marker, {bool atEnd = false}) {
  if (messages.isEmpty) return messages;
  final from = messages.length >= 2 ? messages.length - 2 : 0;
  final positions = cachePositions(messages);
  final recent = positions.where((p) => p.$1 >= from).length;
  final targets = <(int, int)>[if (atEnd) positions.first, if (recent > 20) positions[15], if (recent > 35) positions[30]];
  if (targets.isEmpty) return messages;
  final out = [...messages];
  for (final (i0, j0) in targets) {
    // the nearest block towards the end that takes a breakpoint (towards
    // the start when there is none after: a thinking block last)
    var (i, j) = (i0, j0);
    while (i < out.length) {
      final c = out[i]['content'];
      if (c is List && j >= 0 && j < c.length && _cacheable(c[j])) break;
      if (c is List && j + 1 < c.length) {
        j++;
      } else {
        i++;
        j = 0;
      }
    }
    if (i >= out.length) {
      (i, j) = (i0, j0);
      while (i >= 0) {
        final c = out[i]['content'];
        if (c is List && j >= 0 && j < c.length && _cacheable(c[j])) break;
        if (c is List && j - 1 >= 0) {
          j--;
        } else {
          i--;
          final p = i >= 0 ? out[i]['content'] : null;
          j = p is List ? p.length - 1 : -1;
        }
      }
      if (i < 0) continue;
    }
    final c = [...out[i]['content'] as List];
    c[j] = {...c[j] as Map<String, dynamic>, 'cache_control': marker};
    out[i] = {...out[i], 'content': c};
  }
  return out;
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

  /// `thinking.block_binding` and the `input_transformations` of answers.
  static const bindingBeta = 'thinking-binding-controls-2026-08-01';

  /// Effort-only system messages ([effortMessage]).
  static const effortBeta = 'mid-conversation-output-config-2026-07-01';

  /// What the summary of a compaction keeps: the conversation is replaced
  /// by it, and the model goes on from it alone (its earlier thinking is not
  /// part of the summarizer's input).
  static const compactionInstructions =
      'Summarize the conversation so far so that the work can go on from the summary alone; the conversation itself will be gone. '
      'Keep, exactly as written in it: the ids, names and coordinates (metres) of the items being worked on or referred to; the decisions and the answers the user gave, and their requirements and preferences; what the user asked for and what is still to do (the to-do list and its state); the last figures of the project as the tools reported them (flows, pressures, sizes, costs, messages) with their units; files and pictures attached and what they showed; what was declined or refused, so it is not tried again. '
      'Leave out greetings, repetition and reasoning that led nowhere. Write it as notes under short headings, in the language of the conversation.';

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

  /// A thinking block the conversation before it no longer matches (an
  /// edit of the history, a conversation brought back by a later version of
  /// the app whose tool descriptions changed) is dropped, with every later
  /// one, and the answer says so ([AiReply.transformations]), instead of
  /// the request being refused.
  bool _binding(AiRequest r) => offers(r.model, 'block_binding');

  /// The summary of a compaction keeps what [compactionInstructions] says.
  bool _instructions(AiRequest r) => _compact(r) && offers(r.model, 'compaction_instructions');

  /// The conversation holds effort messages ([effortMessage]).
  static bool _effortMessages(AiRequest r) => r.history.any((m) => effortOfMessage(m) != null);

  /// The request body is near the size the API takes: compaction is asked
  /// for now (the old turns, their pictures above all, leave the body).
  static const compactBytes = 20000000;

  @override
  List<String> optionalFields(AiRequest r) => [
    if (_fallback(r)) 'fallbacks',
    if (_budget(r)) 'task_budget',
    if (_clear(r)) 'clear_tool_uses',
    if (_compact(r)) 'context_management',
    if (_updates(r)) 'display',
    if (_binding(r)) 'block_binding',
    if (_instructions(r)) 'compaction_instructions',
  ];

  /// A complaint about context management drops the summary's instructions
  /// first, then the clearing, then compaction; a beta the account does not
  /// have drops its field.
  @override
  String? declinedField(AiRequest r, String message) {
    // a thinking block refused names the binding setting as the way out: no field is at fault ([recover])
    if (_signature.hasMatch(message)) return null;
    if (_binding(r) && (message.contains('block_binding') || message.contains(bindingBeta) || message.contains('prefix_mismatch_behavior'))) return 'block_binding';
    if (_instructions(r) && message.contains('instructions')) return 'compaction_instructions';
    const about = ['clear_tool_uses', 'context_management', 'context-management', 'exclude_tools'];
    if (_clear(r) && about.any(message.contains)) return 'clear_tool_uses';
    if (_updates(r) && (message.contains('display') || message.contains(displayBeta))) return 'display';
    final fields = optionalFields(r);
    for (final (beta, field) in const [(fallbackBeta, 'fallbacks'), (taskBudgetBeta, 'task_budget'), (compactionBeta, 'context_management')]) {
      if (message.contains(beta) && fields.contains(field)) return field;
    }
    return super.declinedField(r, message);
  }

  /// The models that take [effortMessage] (until the API turned one down
  /// in this session).
  bool takesEffortMessages(AiModel m) => m.perMessageEffort && offers(m, 'effort_message');

  @override
  Map<String, dynamic>? effortMessage(AiModel m, AiEffort e) => takesEffortMessages(m)
      ? {
          'role': 'system',
          'content': <Object?>[],
          'output_config': {'effort': e.name},
        }
      : null;

  /// Whether [e] is the API turning down an effort message (the model, or
  /// the account, does not take them).
  static bool refusesEffortMessage(AiError e) => e.kind == AiErrorKind.invalidRequest && (e.message.contains(effortBeta) || e.message.contains('per-turn effort'));

  Map<String, String> headers(AiRequest r) {
    final betas = [
      if (_fallback(r)) fallbackBeta,
      if (_budget(r)) taskBudgetBeta,
      if (_clear(r)) contextEditingBeta,
      if (_compact(r)) compactionBeta,
      if (_updates(r)) displayBeta,
      if (_binding(r)) bindingBeta,
      if (_effortMessages(r)) effortBeta,
    ];
    return {
      'content-type': 'application/json',
      'x-api-key': apiKey.trim(),
      'anthropic-version': apiVersion,
      if (browser) 'anthropic-dangerous-direct-browser-access': 'true',
      if (betas.isNotEmpty) 'anthropic-beta': betas.join(','),
    };
  }

  /// The cache breakpoint of [r]: five minutes, or an hour for a
  /// [AiRequest.longCache] request (every breakpoint of a request alike:
  /// the longer ones must come first).
  static Map<String, Object?> _marker(AiRequest r) => r.longCache ? const {'type': 'ephemeral', 'ttl': '1h'} : const {'type': 'ephemeral'};

  /// The `thinking` setting: adaptive, with the notes between tool calls as
  /// text and the dropping of blocks the conversation no longer matches.
  /// Thinking is always on for Claude Fable 5.1, so it gets the setting only
  /// for one of these.
  Map<String, Object?>? _thinking(AiRequest r) {
    final extra = <String, Object?>{
      if (_updates(r)) 'display': 'updates',
      if (_binding(r)) 'block_binding': const {'prefix_mismatch_behavior': 'drop_block'},
    };
    if (extra.isEmpty && r.model.alwaysThinks) return null;
    return {'type': 'adaptive', ...extra};
  }

  /// The request body. The tools and the system prompt are cached by the
  /// breakpoint at the end of the system prompt, the growing conversation
  /// by automatic caching (and the breakpoints of [withCacheMarkers] inside
  /// an answer with many tool calls). [compactNow]: the body is near the
  /// size the API takes, so the server is asked to compact the conversation
  /// at its least threshold, without first clearing old tool results (which
  /// would keep the token count under it while the body stays as large).
  Map<String, Object?> body(AiRequest r, {bool compactNow = false}) {
    final marker = _marker(r);
    final thinking = _thinking(r);
    return {
      'model': r.model.id,
      'max_tokens': r.outputTokens,
      'stream': true,
      'system': [
        {'type': 'text', 'text': r.system, 'cache_control': marker},
      ],
      if (r.tools.isNotEmpty) 'tools': [for (final s in r.tools) AnthropicFormat.tool(s)],
      'messages': withCacheMarkers(sinceCompaction(r.history), marker),
      'thinking': ?thinking,
      'output_config': {
        'effort': r.effort.name,
        if (_budget(r)) 'task_budget': {'type': 'tokens', 'total': r.taskBudget! < minTaskBudget ? minTaskBudget : r.taskBudget},
      },
      'cache_control': marker,
      if (_fallback(r)) 'fallbacks': 'default',
      if (_compact(r)) 'context_management': _contextManagement(r, compactNow: compactNow),
    };
  }

  Map<String, Object?> _contextManagement(AiRequest r, {bool compactNow = false, bool compaction = true}) => {
    'edits': [
      if (_clear(r) && !compactNow)
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
      if (compaction)
        {
          'type': 'compact_20260112',
          'trigger': {'type': 'input_tokens', 'value': compactNow || r.compactAt! < minCompactAt ? minCompactAt : r.compactAt},
          if (_instructions(r)) 'instructions': compactionInstructions,
        },
    ],
  };

  /// Keeps the cached conversation of [r] (its system prompt, tools and
  /// [AiRequest.history]) alive for another five minutes while the user
  /// pauses: the same request with `max_tokens` 0 and no stream (the API
  /// only reads it, and bills a cache read instead of the write of the
  /// whole conversation that the next message would cost once the cache
  /// expired). The breakpoint goes on the last block of the history, which
  /// a placeholder message follows (a request may not end with the model's
  /// answer). Returns the tokens billed; never throws (a failed keep-alive
  /// costs nothing more), except for [AiErrorKind.auth] and the like, which
  /// say the next ones would fail too.
  Future<AiUsage> keepWarm(AiRequest r, {required AiCancel cancel}) async {
    if (apiKey.trim().isEmpty) throw AiError(AiErrorKind.noKey);
    final marker = _marker(r);
    final thinking = _thinking(r);
    final b = {
      'model': r.model.id,
      'max_tokens': 0,
      'system': [
        {'type': 'text', 'text': r.system, 'cache_control': marker},
      ],
      if (r.tools.isNotEmpty) 'tools': [for (final s in r.tools) AnthropicFormat.tool(s)],
      'messages': [
        ...withCacheMarkers(sinceCompaction(r.history), marker, atEnd: true),
        AnthropicFormat.user(const [AiTextPart(keepWarmText)]),
      ],
      'thinking': ?thinking,
      'output_config': {'effort': r.effort.name},
      // the same clearing of old tool results as the requests (it shapes
      // what is cached), never a compaction
      if (_clear(r)) 'context_management': _contextManagement(r, compaction: false),
    };
    final json = jsonEncode(b);
    AiHttpClient.checkSize(json);
    final h = headers(r)..update('anthropic-beta', (v) => v.split(',').where((x) => x != compactionBeta && x != fallbackBeta && x != taskBudgetBeta).join(','), ifAbsent: () => '');
    if (h['anthropic-beta']!.isEmpty) h.remove('anthropic-beta');
    final one = cancel.child();
    try {
      final res = await open(AiHttpRequest(endpoint, h, json), r.model, one);
      final text = await readAll(res.body, r.model, one);
      if (res.status < 200 || res.status >= 300) {
        final e = _httpError(r.model, res.status, text, res.headers);
        if (const {AiErrorKind.auth, AiErrorKind.permission, AiErrorKind.billing, AiErrorKind.credit, AiErrorKind.spendLimit, AiErrorKind.notFound}.contains(e.kind)) throw e;
        return AiUsage.zero;
      }
      final j = jsonDecode(text);
      return j is Map ? _usageOf(j['usage']).$1 : AiUsage.zero;
    } on AiError catch (e) {
      if (e.kind == AiErrorKind.auth || e.kind == AiErrorKind.permission || e.kind == AiErrorKind.noKey) rethrow;
      return AiUsage.zero;
    } catch (_) {
      return AiUsage.zero;
    } finally {
      one.release();
      one.cancel();
    }
  }

  /// The placeholder message of [keepWarm] (read, never answered).
  static const keepWarmText = 'Cache keep-alive while the user pauses; no answer is produced.';

  /// Tokens of a `usage` object and its one-hour cache writes apart.
  static (AiUsage, Map<String, dynamic>) _usageOf(Object? u) {
    if (u is! Map) return (AiUsage.zero, const {});
    int v(Map m, String k) => m[k] is num ? (m[k] as num).toInt() : 0;
    final written = v(u, 'cache_creation_input_tokens');
    final by = u['cache_creation'];
    final hour = by is Map ? v(by, 'ephemeral_1h_input_tokens') : 0;
    return (
      AiUsage(input: v(u, 'input_tokens'), output: v(u, 'output_tokens'), cacheWrite: written - hour < 0 ? 0 : written - hour, cacheWriteHour: hour, cacheRead: v(u, 'cache_read_input_tokens')),
      Map<String, dynamic>.from(u),
    );
  }

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
    var json = jsonEncode(body(r));
    // near the size the API takes: the old turns and their pictures go into a summary now
    if (_compact(r) && json.length * 3 > compactBytes && AiHttpClient.utf8Length(json) > compactBytes) json = jsonEncode(body(r, compactNow: true));
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
      // the input of an answer that broke off was billed all the same
      final x = e.withRequestId(id).withUsage(acc.billedSoFar);
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

  /// `input_transformations` of the message (the last list given).
  List<Map<String, dynamic>> _transformations = const [];

  static String? _str(Object? o) => o is String ? o : null;
  static int? _index(Map e) => e['index'] is num ? (e['index'] as num).toInt() : null;

  void _mergeUsage(Object? u) {
    if (u is Map) _usage = {..._usage, ...Map<String, dynamic>.from(u)};
  }

  void _transform(Object? t) {
    if (t is List) {
      _transformations = [
        for (final x in t)
          if (x is Map) Map<String, dynamic>.from(x),
      ];
    }
  }

  /// The tokens reported so far (the input, from the start of the stream):
  /// what an answer that breaks off is billed at least.
  AiUsage get billedSoFar => _billing().$1;

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
    _transform(m['input_transformations']);
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
          _transform(m['input_transformations']);
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
        // again after a fallback in the middle of the answer
        _transform(e['input_transformations']);
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
    AiUsage of(Map u) => AnthropicClient._usageOf(u).$1;
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
      transformations: _transformations,
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
