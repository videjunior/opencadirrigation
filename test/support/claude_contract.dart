import 'dart:convert';

/// What the real Messages API would refuse, or what would cost the cache and
/// the model's earlier reasoning, in the requests a fake Claude receives:
/// tool calls and their results paired (the results first in the message
/// after the call), no empty text block, at most four cache breakpoints,
/// every beta field with its beta header, and — between consecutive
/// requests of one conversation — the system prompt, the tools and the
/// earlier messages byte for byte as they were (the check preserved
/// thinking runs; only cache breakpoints may move).
///
/// [ClaudeContract.check] returns the problems of one request; it keeps the
/// last request of the conversation to compare the next one with. A request
/// the fake refused, a compaction, a keep-alive (max_tokens 0) and a new
/// conversation (another first message) start the comparison anew.
class ClaudeContract {
  Map<String, dynamic>? _last;
  bool _fresh = true;

  /// The next request may differ from the last one (the last one was
  /// refused, or the answer compacted the conversation).
  void reset() => _fresh = true;

  List<String> check(Map<String, dynamic> body, Map<String, String> headers) {
    final out = <String>[];
    final betas = {...(headers['anthropic-beta'] ?? '').split(',').where((s) => s.isNotEmpty)};
    final messages = [for (final m in (body['messages'] as List? ?? const [])) Map<String, dynamic>.from(m as Map)];
    // ---- tool calls and results
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      final content = m['content'] is List ? (m['content'] as List).cast<Map>() : const <Map>[];
      if (m['role'] == 'assistant') {
        final uses = [
          for (final b in content)
            if (b['type'] == 'tool_use') '${b['id']}',
        ];
        if (uses.isEmpty) continue;
        if (i + 1 >= messages.length) {
          out.add('messages.$i: tool calls ${uses.join(', ')} with no results after them');
          continue;
        }
        final next = messages[i + 1];
        final nc = next['content'] is List ? (next['content'] as List).cast<Map>() : const <Map>[];
        final results = <String>[];
        var seenOther = false;
        for (final b in nc) {
          if (b['type'] == 'tool_result') {
            if (seenOther) out.add('messages.${i + 1}: a tool_result after other content (results must come first)');
            results.add('${b['tool_use_id']}');
          } else {
            seenOther = true;
          }
        }
        if (next['role'] != 'user' || !_sameSet(uses, results)) out.add('messages.${i + 1}: results ${results.join(', ')} do not answer the calls ${uses.join(', ')} of messages.$i');
      } else if (m['role'] == 'user') {
        final prev = i > 0 ? messages[i - 1] : null;
        final prevUses = {
          if (prev != null && prev['role'] == 'assistant' && prev['content'] is List)
            for (final b in (prev['content'] as List).cast<Map>())
              if (b['type'] == 'tool_use') '${b['id']}',
        };
        for (final b in content) {
          if (b['type'] == 'tool_result' && !prevUses.contains('${b['tool_use_id']}')) out.add('messages.$i: tool_result ${b['tool_use_id']} answers no call of the message before');
        }
      }
      // ---- empty text blocks (refused by the API)
      for (var j = 0; j < content.length; j++) {
        final b = content[j];
        if (b['type'] == 'text' && '${b['text'] ?? ''}'.isEmpty) out.add('messages.$i.content.$j: an empty text block');
        if (b['type'] == 'tool_result' && b['content'] is List) {
          for (final x in (b['content'] as List).cast<Map>()) {
            if (x['type'] == 'text' && '${x['text'] ?? ''}'.isEmpty) out.add('messages.$i.content.$j: an empty text block in a tool result');
          }
        }
      }
    }
    // (after a compaction the request starts at the model's compaction block)
    bool compaction(Map m) => m['content'] is List && (m['content'] as List).any((b) => b is Map && b['type'] == 'compaction');
    if (messages.isNotEmpty && messages.first['role'] == 'assistant' && !compaction(messages.first)) out.add('messages.0: the conversation starts with the model');
    // ---- cache breakpoints
    final marks = RegExp('"cache_control"').allMatches(jsonEncode({'system': body['system'], 'tools': body['tools'], 'messages': body['messages']})).length + (body['cache_control'] != null ? 1 : 0);
    if (marks > 4) out.add('$marks cache breakpoints (at most 4)');
    // ---- every beta field with its header
    void needs(bool field, String beta, String what) {
      if (field && !betas.contains(beta)) out.add('$what without the $beta header');
    }

    final thinking = body['thinking'] is Map ? body['thinking'] as Map : const {};
    final cm = body['context_management'] is Map ? body['context_management'] as Map : const {};
    final edits = [for (final e in (cm['edits'] as List? ?? const [])) e as Map];
    needs(body.containsKey('fallbacks'), 'server-side-fallback-2026-07-01', 'fallbacks');
    needs(thinking.containsKey('display'), 'thinking-display-updates-2026-08-18', 'thinking.display');
    needs(thinking.containsKey('block_binding'), 'thinking-binding-controls-2026-08-01', 'thinking.block_binding');
    needs((body['output_config'] as Map?)?.containsKey('task_budget') ?? false, 'task-budgets-2026-03-13', 'output_config.task_budget');
    needs(edits.any((e) => e['type'] == 'compact_20260112'), 'compact-2026-01-12', 'compaction');
    needs(edits.any((e) => e['type'] == 'clear_tool_uses_20250919'), 'context-management-2025-06-27', 'clearing of tool results');
    needs(messages.any((m) => m['role'] == 'system' && m.containsKey('output_config')), 'mid-conversation-output-config-2026-07-01', 'an effort message');
    // ---- the same conversation: what was sent before goes again unchanged
    final keepAlive = body['max_tokens'] == 0;
    final last = _last;
    if (!keepAlive && !_fresh && last != null) {
      final a = _strip(last['messages'] as List? ?? const []), b = _strip(body['messages'] as List? ?? const []);
      final same = a.isNotEmpty && b.isNotEmpty && a.first == b.first;
      if (same) {
        if (jsonEncode(_stripOne(last['system'])) != jsonEncode(_stripOne(body['system']))) out.add('the system prompt changed in the middle of the conversation');
        if (jsonEncode(_stripOne(last['tools'])) != jsonEncode(_stripOne(body['tools']))) out.add('the tools changed in the middle of the conversation');
        if (b.length < a.length) {
          out.add('the conversation lost messages (${a.length} → ${b.length})');
        } else {
          for (var i = 0; i < a.length; i++) {
            if (a[i] != b[i]) {
              out.add('messages.$i changed since the request before (the cache and every later thinking block are lost)');
              break;
            }
          }
        }
      }
    }
    if (!keepAlive) {
      _last = body;
      _fresh = false;
    }
    return out;
  }

  static bool _sameSet(List<String> a, List<String> b) => a.length == b.length && a.toSet().containsAll(b);

  /// [o] without its cache breakpoints, as JSON.
  static Object? _stripOne(Object? o) {
    if (o is Map) {
      return {
        for (final e in o.entries)
          if (e.key != 'cache_control') e.key: _stripOne(e.value),
      };
    }
    if (o is List) return [for (final x in o) _stripOne(x)];
    return o;
  }

  static List<String> _strip(List messages) => [for (final m in messages) jsonEncode(_stripOne(m))];
}
