/// OpenAI's Responses API (`POST /v1/responses`) as the AI assistant uses it:
/// called straight from the user's browser or desktop with the user's own
/// OpenAI key, no server in between.
///
/// Pure Dart; the HTTP exchange is injected ([AiTransport]). Requests stream
/// (server-sent events) with function tools, reasoning at the chosen effort,
/// `store: false` (nothing kept on OpenAI's side for later requests) with
/// the encrypted reasoning returned so it can go back in the next request,
/// and server-side compaction for long sessions. The conversation is sent
/// whole each time: the output items exactly as they came, the function
/// outputs, and after a compaction only the compaction item onward. The key
/// goes in the authorization header of the request to OpenAI and nowhere
/// else.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'llm.dart';
import 'llm_formats.dart';

export 'llm.dart';

/// Items from the last compaction item on (it carries what came before).
List<Map<String, dynamic>> sinceCompactionItem(List<Map<String, dynamic>> items) {
  final i = items.lastIndexWhere((it) => it['type'] == 'compaction');
  return i <= 0 ? items : items.sublist(i);
}

/// What replaces a picture taken out of an earlier tool result.
const prunedPicture = '[An earlier picture was removed to keep the conversation small; take a new one if you need it.]';

/// [items] with the pictures of tool results beyond the newest [keep]
/// replaced by a short text, once there are more than [above] (in steps,
/// so the cached prefix changes rarely). The pictures the user attached
/// stay. The stored history is not touched: only the request is lighter.
List<Map<String, dynamic>> pruneToolPictures(List<Map<String, dynamic>> items, {int keep = 3, int above = 6}) {
  var n = 0;
  for (final it in items) {
    final out = it['output'];
    if (it['type'] == 'function_call_output' && out is List) n += out.where((p) => p is Map && p['type'] == 'input_image').length;
  }
  if (n <= above) return items;
  var drop = n - keep;
  return [
    for (final it in items)
      if (drop > 0 && it['type'] == 'function_call_output' && it['output'] is List && (it['output'] as List).any((p) => p is Map && p['type'] == 'input_image'))
        {
          ...it,
          'output': [
            for (final p in it['output'] as List)
              if (p is Map && p['type'] == 'input_image' && drop-- > 0) {'type': 'input_text', 'text': prunedPicture} else p,
          ],
        }
      else
        it,
  ];
}

class OpenAiClient extends AiHttpClient {
  OpenAiClient({required super.apiKey, required super.transport, super.sleep, super.maxRetries});

  static final endpoint = Uri.parse('https://api.openai.com/v1/responses');

  @override
  AiProvider get provider => AiProvider.openai;

  bool _compact(AiRequest r) => r.compactAt != null && r.model.compaction && offers(r.model, 'context_management');

  @override
  List<String> optionalFields(AiRequest r) => [if (_compact(r)) 'context_management'];

  Map<String, String> headers() => {'content-type': 'application/json', 'authorization': 'Bearer ${apiKey.trim()}'};

  /// The `reasoning.effort` of [e]: the Responses API's levels end at
  /// `xhigh`, which "maximum" asks for.
  static String effortOf(AiEffort e) => e == AiEffort.max ? 'xhigh' : e.name;

  Map<String, Object?> body(AiRequest r) => {
    'model': r.model.id,
    'instructions': r.system,
    'input': pruneToolPictures(sinceCompactionItem(r.history)),
    if (r.tools.isNotEmpty) 'tools': [for (final s in r.tools) OpenAiFormat.tool(s)],
    'reasoning': {'effort': effortOf(r.effort)},
    'max_output_tokens': r.outputTokens,
    'stream': true,
    'store': false,
    'include': ['reasoning.encrypted_content'],
    if (_compact(r))
      'context_management': [
        {'type': 'compaction', 'compact_threshold': r.compactAt},
      ],
  };

  @override
  Map<String, dynamic> userMessage(List<AiPart> parts) => OpenAiFormat.user(parts);

  @override
  List<Map<String, dynamic>> toolResults(List<AiToolResult> results, {List<AiPart> user = const [], String? note}) => OpenAiFormat.toolResults(results, user: user, note: note);

  @override
  Future<AiReply> attempt(AiRequest r, AiCancel cancel, AiStreamListener listener) async {
    final json = jsonEncode(body(r));
    AiHttpClient.checkSize(json);
    final req = AiHttpRequest(endpoint, headers(), json);
    final res = await open(req, r.model, cancel);
    final id = res.headers['x-request-id'];
    final idle = idleTimeout(r.model, r.effort);
    if (res.status < 200 || res.status >= 300) {
      final text = await readAll(res.body, r.model, cancel, idle: idle);
      throw httpError(res.status, text, res.headers);
    }
    if (!(res.headers['content-type'] ?? '').contains('event-stream')) {
      final text = await readAll(res.body, r.model, cancel, idle: idle);
      final Object? j;
      try {
        j = jsonDecode(text);
      } catch (_) {
        throw AiError(AiErrorKind.http, status: res.status, message: clean(text), requestId: id);
      }
      if (j is! Map<String, dynamic>) throw AiError(AiErrorKind.http, status: res.status, requestId: id);
      try {
        final acc = _Stream(listener, clean)..terminal(j);
        return acc.finish();
      } on AiError catch (e) {
        throw e.withRequestId(id);
      }
    }
    final acc = _Stream(listener, clean);
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

  static final _noAccess = RegExp(r'does not have access to (the )?model|model .* does not exist|not available for (your|this) (account|organi[sz]ation|project)', caseSensitive: false);

  /// The kind of an error from its HTTP status, `type` and `code`.
  static AiErrorKind kindOf(int? status, String type, String code, String message) {
    if (code == 'insufficient_quota' || type == 'insufficient_quota') return AiErrorKind.credit;
    if (code == 'model_not_found' || ((status == 403 || status == 404) && _noAccess.hasMatch(message))) return AiErrorKind.notFound;
    if (code == 'context_length_exceeded') return AiErrorKind.contextWindow;
    if (code == 'rate_limit_exceeded') return AiErrorKind.rateLimit;
    if (code == 'server_error') return AiErrorKind.server;
    if (code == 'invalid_api_key' || type == 'authentication_error') return AiErrorKind.auth;
    return switch (status) {
      401 => AiErrorKind.auth,
      403 => AiErrorKind.permission,
      404 => AiErrorKind.notFound,
      413 => AiErrorKind.tooLarge,
      429 => AiErrorKind.rateLimit,
      400 || 422 => AiErrorKind.invalidRequest,
      503 => AiErrorKind.overloaded,
      final int s when s >= 500 => AiErrorKind.server,
      _ => AiErrorKind.http,
    };
  }

  AiError httpError(int status, String body, Map<String, String> headers) {
    var type = '', code = '', message = '';
    try {
      final j = jsonDecode(body);
      final e = j is Map ? j['error'] : null;
      if (e is Map) {
        type = '${e['type'] ?? ''}';
        code = '${e['code'] ?? ''}';
        message = '${e['message'] ?? ''}';
      } else {
        message = body;
      }
    } catch (_) {
      message = body;
    }
    return AiError(kindOf(status, type, code, message), status: status, message: clean(message), retryAfter: AiHttpClient.retryAfterOf(headers), requestId: headers['x-request-id']);
  }
}

/// Builds the answer from the streamed events (or a whole response).
class _Stream {
  _Stream(this.listener, this.clean);
  final AiStreamListener listener;
  final String Function(String) clean;
  final Map<int, Map<String, dynamic>> _items = {};
  final Map<int, StringBuffer> _args = {}, _text = {};
  List<Map<String, dynamic>>? _output;
  Map<String, dynamic> _usage = {};
  String _model = '';
  String? _status, _reason;
  bool sawText = false;

  static List<Map<String, dynamic>> _maps(Object? o) => [
    if (o is List)
      for (final x in o)
        if (x is Map) Map<String, dynamic>.from(x),
  ];

  /// Policy codes of a failed response: the request was declined.
  static const _declined = {'bio_policy', 'misalignment_policy_violation', 'invalid_prompt', 'image_content_policy_violation'};

  AiError _error(Object? e) {
    final m = e is Map ? e : const {};
    final code = '${m['code'] ?? ''}';
    final message = clean('${m['message'] ?? ''}');
    if (_declined.contains(code)) return AiError(AiErrorKind.refusal, message: message, category: code);
    final kind = OpenAiClient.kindOf(null, '${m['type'] ?? ''}', code, message);
    return AiError(kind == AiErrorKind.http ? AiErrorKind.invalidRequest : kind, message: message);
  }

  static String? _str(Object? o) => o is String ? o : null;

  /// A finished response (`response.completed`, `.incomplete`, `.failed`).
  void terminal(Map<String, dynamic> resp) {
    _model = _str(resp['model']) ?? _model;
    _status = _str(resp['status']) ?? _status;
    final out = _maps(resp['output']);
    if (out.isNotEmpty) _output = out;
    final u = resp['usage'];
    if (u is Map) _usage = Map<String, dynamic>.from(u);
    final d = resp['incomplete_details'];
    if (d is Map) _reason = _str(d['reason']);
    if (_status == 'failed') throw _error(resp['error']);
  }

  void event(Map<String, dynamic> e) {
    listener.onActivity?.call();
    final i = e['output_index'] is num ? (e['output_index'] as num).toInt() : -1;
    switch (e['type']) {
      case 'response.created' || 'response.in_progress' || 'response.queued':
        final r = e['response'];
        if (r is Map) _model = _str(r['model']) ?? _model;
      case 'response.output_item.added':
        final it = e['item'];
        if (it is Map) {
          _items[i] = Map<String, dynamic>.from(it);
          if (it['type'] == 'function_call') listener.onToolStart?.call('${it['name'] ?? ''}');
        }
      case 'response.output_text.delta':
        final s = '${e['delta'] ?? ''}';
        (_text[i] ??= StringBuffer()).write(s);
        if (s.isNotEmpty) {
          sawText = true;
          listener.onText?.call(s);
        }
      case 'response.function_call_arguments.delta':
        (_args[i] ??= StringBuffer()).write('${e['delta'] ?? ''}');
      case 'response.output_item.done':
        final it = e['item'];
        if (it is Map) _items[i] = Map<String, dynamic>.from(it);
      case 'response.completed' || 'response.incomplete':
        final r = e['response'];
        if (r is Map) terminal(Map<String, dynamic>.from(r));
        _status ??= e['type'] == 'response.completed' ? 'completed' : 'incomplete';
      case 'response.failed':
        final r = e['response'];
        if (r is Map) terminal({...Map<String, dynamic>.from(r), 'status': 'failed'});
        throw _error(null);
      case 'error':
        throw _error(e);
      default:
        break; // reasoning summaries, compaction progress, later event types
    }
  }

  /// Items as they arrived, completed from the deltas when the final
  /// response did not list them.
  List<Map<String, dynamic>> _gathered() {
    final keys = _items.keys.toList()..sort();
    return [
      for (final k in keys)
        {
          ..._items[k]!,
          if (_items[k]!['type'] == 'function_call' && (_items[k]!['arguments'] ?? '') == '' && _args[k] != null) 'arguments': _args[k].toString(),
          if (_items[k]!['type'] == 'message' && (_items[k]!['content'] is! List || (_items[k]!['content'] as List).isEmpty) && _text[k] != null)
            'content': [
              {'type': 'output_text', 'text': _text[k].toString(), 'annotations': <Object?>[]},
            ],
        },
    ];
  }

  AiUsage _usageOf() {
    int v(Object? m, String k) => m is Map ? (m[k] as num?)?.toInt() ?? 0 : 0;
    final d = _usage['input_tokens_details'];
    final cached = v(d, 'cached_tokens'), written = v(d, 'cache_write_tokens');
    return AiUsage(input: math.max(0, v(_usage, 'input_tokens') - cached - written), cacheRead: cached, cacheWrite: written, output: v(_usage, 'output_tokens'));
  }

  AiReply finish() {
    if (_status == null) throw AiError(AiErrorKind.interrupted, partial: sawText);
    final items = _output ?? _gathered();
    final calls = OpenAiFormat.calls(items);
    final text = OpenAiFormat.text(items);
    final refusal = OpenAiFormat.refusal(items);
    final compacted = items.any((it) => it['type'] == 'compaction');
    final stop = _status == 'incomplete'
        ? (_reason == 'content_filter' ? AiStop.refusal : AiStop.maxTokens)
        : refusal.isNotEmpty && calls.isEmpty
        ? AiStop.refusal
        : calls.isNotEmpty
        ? AiStop.tool
        : AiStop.end;
    final keep = stop != AiStop.refusal && (compacted || calls.isNotEmpty || text.isNotEmpty);
    return AiReply(
      items: keep ? items : const [],
      text: text,
      calls: calls,
      stop: stop,
      model: _model,
      usage: _usageOf(),
      category: _status == 'incomplete' && _reason == 'content_filter' ? 'content_filter' : null,
      explanation: clean(refusal),
      compacted: compacted,
    );
  }
}
