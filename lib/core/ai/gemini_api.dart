/// Google's Gemini API as the AI assistant uses it: called straight from the
/// user's browser or desktop with the user's own Gemini API key, no server
/// in between.
///
/// Which API (documentation of 2026-11-10, https://aistudio.google.com/llms.txt):
/// the Interactions API (`POST /v1beta/interactions`), which Google recommends
/// for every new project (generally available since June 2026, also as the
/// stable `v1`), and not the legacy `generateContent`, which stays supported
/// but gets no new capabilities. It does everything the assistant needs:
/// - stateless: `store: false` keeps nothing at Google for later requests
///   (no logs, no `previous_interaction_id`), and the whole conversation goes
///   with each request as a list of steps;
/// - function calling with parallel calls, and `function_result` steps that
///   carry pictures (image content blocks) and an error flag;
/// - reasoning across tool calls: the model's reasoning comes back in `thought`
///   steps of their own (an encrypted `signature`, never attached to text or
///   to a function call), which stateless mode must send back exactly as they
///   came, in their place;
/// - streaming (server-sent events: `interaction.created`, then each step as
///   `step.start` → `step.delta`… → `step.stop`, then `interaction.completed`
///   with the usage), thinking levels per model, a per-picture media
///   resolution, the usage with the tokens read from the implicit cache, and
///   typed error codes (generation blocked: `safety`, `recitation`…).
/// `/v1beta` is the path every guide and model page uses for the current
/// models (the `v1` reference does not list them yet); its May 2026 schema
/// change (`steps` instead of `outputs`) is the only shape since June 8, 2026,
/// so no `Api-Revision` header is sent. The CORS preflight from a page origin
/// allows `x-goog-api-key` and `content-type`, the only headers sent.
///
/// The conversation is kept in the neutral format ([OpenAiFormat]) and each
/// request is written from it, deterministically (the same history always
/// gives the same bytes: the implicit cache matches prefixes). The model's
/// turn is kept as `message` items (its text), `function_call` items (the
/// arguments as the JSON text that came) and, for any other step (`thought`
/// with its signature), a `gemini_step` item holding the step as it came; a
/// text or call step that carries more than its neutral item says keeps the
/// whole step too (`gemini_step` field), so every step goes back unchanged.
///
/// Pure Dart; the key goes in the `x-goog-api-key` header of requests to
/// generativelanguage.googleapis.com and nowhere else.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'llm.dart';
import 'llm_formats.dart';
import 'openai_api.dart' show pruneToolPictures;

export 'llm.dart';

/// The type of a neutral item that holds a step of Gemini's own (a thought
/// with its signature) under `step`, and the field that holds the whole step
/// of a `message` or `function_call` item that says more than its neutral
/// form.
const geminiStep = 'gemini_step';

/// The Interactions API's translation from and into the neutral format.
abstract final class GeminiFormat {
  static List<Map<String, dynamic>> _maps(Object? o) => [
    if (o is List)
      for (final x in o)
        if (x is Map) Map<String, dynamic>.from(x),
  ];

  // ---------------------------------------------------------------- tools

  /// A function tool, its parameters converted with [schema].
  static Map<String, Object?> tool(AiToolSpec s) {
    final p = schema(s.inputSchema);
    return {'type': 'function', 'name': s.name, 'description': s.description, if (p.isNotEmpty) 'parameters': p};
  }

  /// String formats the API reads (structured outputs guide, "JSON schema
  /// support"); another one is said in the description.
  static const formats = {'date-time', 'date', 'time'};

  /// Keywords dropped without a word: metadata of the schema itself.
  static const _metadata = {r'$schema', r'$id', r'$comment', 'strict'};

  /// [s] in the subset of JSON Schema the API takes for function parameters
  /// (types, a type list with "null", title, description, properties,
  /// required, additionalProperties, enum, string formats date-time / date /
  /// time, minimum, maximum, items, prefixItems, anyOf, `$ref` / `$defs`).
  /// What the API would reject, or would turn into a grammar too large to
  /// compile (array bounds: "minItems and maxItems duplicate the item schema
  /// for each counted position"), becomes words in the description instead,
  /// so the model still knows it and the request is never rejected for it;
  /// the agent loop checks every input against the original schema anyway.
  /// Property names are kept as they are, whatever they spell.
  static Map<String, Object?> schema(Map<String, Object?> s) {
    final out = <String, Object?>{};
    final notes = <String>[];
    final props = s['properties'];
    var nullable = false;
    final anyOf = <Map<String, Object?>>[];
    for (final e in s.entries) {
      final k = e.key, v = e.value;
      switch (k) {
        case 'type':
          if (v is String) {
            out['type'] = v;
          } else if (v is List) {
            final types = [for (final t in v) '$t'];
            final some = types.where((t) => t != 'null').toList();
            final orNull = types.contains('null');
            if (some.length <= 1) {
              // a type, or a type or null (the documented form)
              out['type'] = some.isEmpty ? 'null' : (orNull ? [some.single, 'null'] : some.single);
            } else {
              // several types: one branch each
              for (final t in some) {
                anyOf.add({
                  'type': orNull ? [t, 'null'] : t,
                });
              }
            }
          }
        case 'description':
          out['description'] = null; // its place; written below
        case 'title':
          if (v is String) out['title'] = v;
        case 'properties':
          if (v is Map && v.isNotEmpty) {
            out['properties'] = {for (final p in v.entries) '${p.key}': p.value is Map ? schema(Map<String, Object?>.from(p.value as Map)) : <String, Object?>{}};
          }
        case 'required':
          if (v is List) {
            final names = [
              for (final n in v)
                if (n is String && (props is! Map || props.containsKey(n))) n,
            ];
            if (names.isNotEmpty) out['required'] = names;
          }
        case 'additionalProperties':
          if (v is bool) out[k] = v;
          if (v is Map) out[k] = schema(Map<String, Object?>.from(v));
        case 'enum':
          if (v is List && v.isNotEmpty) out[k] = [...v];
        case 'const':
          out['enum'] = [v];
        case 'format':
          if (formats.contains(v)) {
            out[k] = v;
          } else {
            notes.add('Format: $v.');
          }
        case 'minimum' || 'maximum':
          if (v is num) out[k] = v;
        case 'items':
          if (v is Map) out[k] = schema(Map<String, Object?>.from(v));
          if (v is List) out['prefixItems'] = [for (final x in v) x is Map ? schema(Map<String, Object?>.from(x)) : <String, Object?>{}];
        case 'prefixItems':
          if (v is List) out[k] = [for (final x in v) x is Map ? schema(Map<String, Object?>.from(x)) : <String, Object?>{}];
        case 'anyOf' || 'oneOf':
          if (v is List) {
            for (final x in v) {
              if (x is Map) anyOf.add(schema(Map<String, Object?>.from(x)));
            }
          }
        case r'$ref':
          if (v is String) out[k] = v;
        case r'$defs' || 'definitions':
          if (v is Map) out[r'$defs'] = {for (final d in v.entries) '${d.key}': d.value is Map ? schema(Map<String, Object?>.from(d.value as Map)) : <String, Object?>{}};
        case 'nullable':
          nullable = v == true;
        case 'minItems':
          notes.add('At least $v items.');
        case 'maxItems':
          notes.add('At most $v items.');
        case 'minLength':
          notes.add('At least $v characters.');
        case 'maxLength':
          notes.add('At most $v characters.');
        case 'minProperties':
          notes.add('At least $v fields.');
        case 'maxProperties':
          notes.add('At most $v fields.');
        case 'pattern':
          notes.add('Matches the pattern $v.');
        case 'exclusiveMinimum':
          notes.add('Greater than $v.');
        case 'exclusiveMaximum':
          notes.add('Less than $v.');
        case 'multipleOf':
          notes.add('A multiple of $v.');
        case 'uniqueItems':
          if (v == true) notes.add('No item repeated.');
        case 'default':
          notes.add('Default: ${_short(jsonEncode(v))}.');
        case 'examples':
          notes.add('Examples: ${_short(jsonEncode(v))}.');
        default:
          if (!_metadata.contains(k)) notes.add('$k: ${_short(jsonEncode(v))}.');
      }
    }
    if (nullable) {
      final t = out['type'];
      if (t is String && t != 'null') out['type'] = [t, 'null'];
    }
    if (anyOf.isNotEmpty) out['anyOf'] = anyOf;
    final desc = [if (s['description'] is String && (s['description'] as String).isNotEmpty) s['description'] as String, ...notes].join(' ');
    if (desc.isEmpty) {
      out.remove('description');
    } else {
      out['description'] = desc;
    }
    return out;
  }

  static String _short(String s) => s.length <= 200 ? s : '${s.substring(0, 199)}…';

  // ---------------------------------------------------------------- input

  /// Gemini's content blocks of a neutral part (none for a part it has no
  /// block for): text, a picture at [resolution], a PDF after its name.
  static List<Map<String, dynamic>> contentOf(Map<String, dynamic> p, {required String resolution}) {
    switch (p['type']) {
      case 'input_text' || 'output_text' || 'text':
        return [
          {'type': 'text', 'text': '${p['text'] ?? ''}'},
        ];
      case 'input_image':
        final url = '${p['image_url'] ?? ''}';
        final d = OpenAiFormat.fromDataUrl(url);
        return [
          d == null ? {'type': 'image', 'uri': url, 'resolution': resolution} : {'type': 'image', 'mime_type': d.$1, 'data': d.$2, 'resolution': resolution},
        ];
      case 'input_file':
        final d = OpenAiFormat.fromDataUrl('${p['file_data'] ?? ''}');
        if (d == null) return const [];
        final name = '${p['filename'] ?? ''}';
        // a document block has no name: the file's name goes before it, as the other providers have it
        return [
          if (name.isNotEmpty) {'type': 'text', 'text': '[file: $name]'},
          {'type': 'document', 'mime_type': d.$1, 'data': d.$2},
        ];
    }
    return const [];
  }

  /// The step of a model item of the neutral format (null for one that says
  /// nothing).
  static Map<String, dynamic>? modelStep(Map<String, dynamic> it) {
    final whole = it[geminiStep];
    if (whole is Map) return Map<String, dynamic>.from(whole);
    switch (it['type']) {
      case geminiStep:
        final s = it['step'];
        return s is Map ? Map<String, dynamic>.from(s) : null;
      case 'message':
        final texts = [
          for (final c in _maps(it['content']))
            if (c['type'] == 'output_text') {'type': 'text', 'text': '${c['text'] ?? ''}'},
        ];
        return texts.isEmpty ? null : {'type': 'model_output', 'content': texts};
      case 'function_call':
        final (input, _) = parseToolInput('${it['arguments'] ?? ''}');
        return {'type': 'function_call', 'id': '${it['call_id'] ?? ''}', 'name': '${it['name'] ?? ''}', 'arguments': input ?? <String, dynamic>{}};
    }
    return null;
  }

  /// The `function_result` step of a neutral function output: its text and
  /// pictures in order, the error flag from the error prefix, and the name
  /// of the function from the call of the same id ([names]).
  static Map<String, dynamic> resultStep(Map<String, dynamic> it, Map<String, String> names, {required String resolution}) {
    final id = '${it['call_id'] ?? ''}';
    final out = it['output'];
    // (a result holds text and pictures only; an empty text, as before a picture alone, is left out)
    final parts = <Map<String, dynamic>>[
      if (out is List)
        for (final p in _maps(out)) ...contentOf(p, resolution: resolution).where((b) => b['type'] == 'image' || (b['type'] == 'text' && '${b['text']}'.isNotEmpty))
      else if ('${out ?? ''}'.isNotEmpty)
        {'type': 'text', 'text': '${out ?? ''}'},
    ];
    final first = parts.where((b) => b['type'] == 'text').firstOrNull;
    final error = first != null && '${first['text']}'.startsWith(toolErrorPrefix);
    return {'type': 'function_result', if (names[id] != null) 'name': names[id], 'call_id': id, 'result': parts.isEmpty ? '' : parts, if (error) 'is_error': true};
  }

  /// The `input` of a request: the neutral conversation [items] as steps —
  /// user messages and the program's notes as `user_input` steps (those in
  /// a row merged into one), the model's items back as the steps they came
  /// from, function outputs as `function_result` steps. Items of no use to
  /// Gemini (another provider's opaque items) are left out.
  static List<Map<String, dynamic>> steps(List<Map<String, dynamic>> items, {String resolution = 'high'}) {
    final out = <Map<String, dynamic>>[];
    final names = <String, String>{};
    List<Map<String, dynamic>>? user;
    void flush() {
      final u = user;
      if (u != null && u.isNotEmpty) out.add({'type': 'user_input', 'content': u});
      user = null;
    }

    for (final it in items) {
      switch (it['type']) {
        case 'message' when it['role'] != 'assistant':
          final content = [for (final p in _maps(it['content'])) ...contentOf(p, resolution: resolution)];
          if (content.isNotEmpty) (user ??= []).addAll(content);
        case 'message' || 'function_call' || geminiStep:
          flush();
          final s = modelStep(it);
          if (s == null) continue;
          if (s['type'] == 'function_call') names['${s['id'] ?? ''}'] = '${s['name'] ?? ''}';
          out.add(s);
        case 'function_call_output':
          flush();
          out.add(resultStep(it, names, resolution: resolution));
      }
    }
    flush();
    return out;
  }

  // ---------------------------------------------------------------- output

  /// [m]'s keys are [keys], in that order: the shape [modelStep] rebuilds.
  static bool _shaped(Map<String, dynamic> m, List<String> keys) {
    final k = m.keys.toList();
    if (k.length != keys.length) return false;
    for (var i = 0; i < k.length; i++) {
      if (k[i] != keys[i]) return false;
    }
    return true;
  }

  /// The neutral item of a step of the model's turn ([raw]: the arguments
  /// of a function call as the JSON text that streamed); null for a step
  /// that says nothing. A step that [modelStep] would not rebuild to the
  /// same JSON from the item (other fields, another order of its fields)
  /// is kept whole in the item as well.
  static Map<String, dynamic>? itemOf(Map<String, dynamic> step, {String? raw}) {
    switch (step['type']) {
      case 'model_output':
        final content = _maps(step['content']);
        if (content.isEmpty) return null;
        final plain = _shaped(step, const ['type', 'content']) && content.every((c) => c['type'] == 'text' && _shaped(c, const ['type', 'text']));
        return {
          'type': 'message',
          'role': 'assistant',
          'content': [
            for (final c in content)
              if (c['type'] == 'text') {'type': 'output_text', 'text': '${c['text'] ?? ''}', 'annotations': <Object?>[]},
          ],
          if (!plain) geminiStep: step,
        };
      case 'function_call':
        // the step is rebuilt from the item: its arguments parsed from this text
        final args = step['arguments'];
        final text = raw ?? (args is Map ? jsonEncode(args) : '${args ?? ''}');
        final plain = _shaped(step, const ['type', 'id', 'name', 'arguments']) && args is Map;
        return {'type': 'function_call', 'call_id': '${step['id'] ?? ''}', 'name': '${step['name'] ?? ''}', 'arguments': text, if (!plain) geminiStep: step};
    }
    return {'type': geminiStep, 'step': step};
  }

  /// The neutral items of the steps of a turn ([raw]: streamed arguments by
  /// position in [steps]).
  static List<Map<String, dynamic>> itemsOf(List<Map<String, dynamic>> steps, {Map<int, String> raw = const {}}) => [for (var i = 0; i < steps.length; i++) ?itemOf(steps[i], raw: raw[i])];
}

class GeminiClient extends AiHttpClient {
  GeminiClient({required super.apiKey, required super.transport, super.sleep, super.maxRetries});

  static final endpoint = Uri.parse('https://generativelanguage.googleapis.com/v1beta/interactions');

  /// Where the requests go.
  Uri get url => endpoint;

  /// Largest request body sent: "inline image data limits your total
  /// request size (text prompts, system instructions, and inline bytes) to
  /// 20MB" (image understanding guide; the file input guide says 100 MB per
  /// request, 50 MB for PDFs: the lower figure is kept).
  static const maxBytes = 20000000;

  @override
  AiProvider get provider => AiProvider.google;

  /// The headers of a request (the key in `x-goog-api-key`, nowhere else).
  Map<String, String> headers() => {'content-type': 'application/json', 'x-goog-api-key': apiKey.trim()};

  /// The `thinking_level` of [e] for [m]: the nearest effort the model takes
  /// ([AiModel.effortFor]) by its Gemini name. Gemini 4 Argon and Gemini 3.8
  /// Flash take low, medium and high (3.8 Flash answers `minimal` with an
  /// error); Gemini 3.5 Flash-Lite takes minimal too, which no effort of the
  /// app maps to. The two highest efforts go as high, the highest there is.
  static String levelOf(AiModel m, AiEffort e) => switch (m.effortFor(e)) {
    AiEffort.low => 'low',
    AiEffort.medium => 'medium',
    _ => 'high',
  };

  /// The media resolution of every picture: `ultra_high` (2240 tokens a
  /// picture on Gemini 4 and 3, the level for computer use, where the model
  /// reads positions on screenshots — the assistant measures on its
  /// pictures too), or `high` (1120 tokens) once a model turned it down.
  String resolutionOf(AiModel m) => offers(m, 'ultra_high') ? 'ultra_high' : 'high';

  /// The conversation of [r] in the neutral format as it goes: the oldest
  /// pictures of tool results replaced by a note (as with the Responses
  /// APIs), the stored history untouched.
  List<Map<String, dynamic>> neutralInput(AiRequest r) => pruneToolPictures(r.history);

  /// The `input` of [r].
  List<Map<String, dynamic>> inputOf(AiRequest r) => GeminiFormat.steps(neutralInput(r), resolution: resolutionOf(r.model));

  /// The request body.
  Map<String, Object?> body(AiRequest r) => {
    'model': r.model.id,
    if (r.system.isNotEmpty) 'system_instruction': r.system,
    'input': inputOf(r),
    if (r.tools.isNotEmpty) 'tools': [for (final s in r.tools) GeminiFormat.tool(s)],
    'generation_config': {'thinking_level': levelOf(r.model, r.effort), 'max_output_tokens': r.outputTokens},
    'stream': true,
    'store': false,
  };

  @override
  List<String> optionalFields(AiRequest r) => [if (offers(r.model, 'ultra_high') && countMedia(neutralInput(r)).$1 > 0) 'ultra_high'];

  @override
  String? declinedField(AiRequest r, String message) {
    final m = message.toLowerCase();
    return optionalFields(r).where(m.contains).firstOrNull;
  }

  /// Gemini 4 Argon may think for many minutes before the next event:
  /// Google asks for client timeouts of at least 15 minutes.
  @override
  Duration idleTimeout(AiModel m, [AiEffort effort = AiEffort.medium]) {
    final base = super.idleTimeout(m, effort);
    const least = Duration(minutes: 15);
    return m.longTurns && base < least ? least : base;
  }

  @override
  Map<String, dynamic> userMessage(List<AiPart> parts) => OpenAiFormat.user(parts);

  @override
  List<Map<String, dynamic>> toolResults(List<AiToolResult> results, {List<AiPart> user = const [], String? note}) => OpenAiFormat.toolResults(results, user: user, note: note);

  @override
  Future<AiReply> attempt(AiRequest r, AiCancel cancel, AiStreamListener listener) async {
    final json = jsonEncode(body(r));
    AiHttpClient.checkSize(json, limit: maxBytes);
    // what the request carries, for the costs by step (the pictures pruned from it left out)
    final (images, documents) = countMedia(neutralInput(r));
    final reply = await _exchange(r, json, cancel, listener);
    return reply.withRequest(bytes: json.length, images: images, documents: documents);
  }

  Future<AiReply> _exchange(AiRequest r, String json, AiCancel cancel, AiStreamListener listener) async {
    final res = await open(AiHttpRequest(url, headers(), json), r.model, cancel);
    final idle = idleTimeout(r.model, r.effort);
    final turn = _Turn(this, listener, r.model);
    if (res.status < 200 || res.status >= 300) {
      final text = await readAll(res.body, r.model, cancel, idle: idle);
      final e = errorBody(text);
      final blocked = blockedOf(e);
      if (blocked != null) return turn.refusal(blocked.$1, blocked.$2);
      throw errorOf(res.status, e ?? {'message': text}, headers: res.headers);
    }
    if (!(res.headers['content-type'] ?? '').contains('event-stream')) {
      final text = await readAll(res.body, r.model, cancel, idle: idle);
      Object? j;
      try {
        j = jsonDecode(text);
      } catch (_) {
        throw AiError(AiErrorKind.http, status: res.status, message: clean(text));
      }
      if (j is List && j.isNotEmpty) j = j.first;
      if (j is! Map) throw AiError(AiErrorKind.http, status: res.status);
      turn.whole(Map<String, dynamic>.from(j));
      return turn.finish();
    }
    final sse = SseReader(turn.event);
    try {
      await readLines(res.body, r.model, sse.line, cancel, idle: idle);
      sse.close();
      return turn.finish();
    } on AiError catch (e) {
      final x = e.withRequestId(turn.id.isEmpty ? null : turn.id);
      throw turn.sawText ? x.withPartial() : x;
    }
  }

  /// The error object of an error body: `{"error": {...}}`, or a list of
  /// them (the shape Google's front end answers with); null when there is
  /// none.
  static Map<String, dynamic>? errorBody(String text) {
    Object? j;
    try {
      j = jsonDecode(text);
    } catch (_) {
      return null;
    }
    if (j is List && j.isNotEmpty) j = j.first;
    final e = j is Map ? j['error'] : null;
    return e is Map ? Map<String, dynamic>.from(e) : null;
  }

  /// "Generation blocked" codes (API errors page): policy, safety or content
  /// restrictions blocked the input or the output. Not an error of the
  /// request: the answer ends as a refusal.
  static const blockedCodes = {
    'safety',
    'recitation',
    'language',
    'prohibited_content',
    'spii',
    'blocklist',
    'jailbreak',
    'image_safety',
    'image_prohibited_content',
    'image_recitation',
    'image_other',
    'content_blocked',
  };

  /// (category, explanation) of an error object that is a block; null for
  /// any other.
  (String, String)? blockedOf(Map<String, dynamic>? e) {
    final code = e?['code'];
    if (code is! String || !blockedCodes.contains(code.toLowerCase())) return null;
    return (code.toLowerCase(), clean('${e?['message'] ?? ''}'));
  }

  static final _context = RegExp(r'exceeds the maximum number of tokens|input token count|context window|context length|too many (input )?tokens', caseSensitive: false);
  static final _authText = RegExp(r'API key not valid|API key expired|API_KEY_INVALID|reported as leaked|unregistered callers|without established identity|unrestricted', caseSensitive: false);
  static final _billingText = RegExp(r'billing|payment|free tier|FREE_TIER|verification|verify|outstanding balance|prepay', caseSensitive: false);
  static final _spendText = RegExp(r'spend(ing)?[ -](cap|limit)', caseSensitive: false);
  static final _creditText = RegExp(r'credits? (balance )?(is |are |has been )?(depleted|exhausted|used up)', caseSensitive: false);
  static final _retryIn = RegExp(r'retry (in|after) (\d+(?:\.\d+)?) ?(ms|s|seconds?)\b', caseSensitive: false);

  /// A wait such as "33s", "1.5s" or "250ms" (a protobuf Duration as JSON).
  static Duration? durationOf(Object? v) {
    final m = RegExp(r'^\s*(\d+(?:\.\d+)?)\s*(ms|s)\s*$').firstMatch('${v ?? ''}');
    if (m == null) return null;
    final n = double.parse(m.group(1)!);
    return Duration(milliseconds: (m.group(2) == 'ms' ? n : n * 1000).round());
  }

  /// The error of a failed request ([status]: its HTTP status, null for one
  /// in the stream) from its error object [e], in either shape the API
  /// answers with: the Interactions API's (`code` a snake_case name) or
  /// Google's front end's (`code` the HTTP status, `status` the gRPC name,
  /// `details` with the reason, the quota broken and the wait asked for).
  AiError errorOf(int? status, Map<String, dynamic> e, {Map<String, String> headers = const {}}) {
    final raw = e['code'];
    final code = raw is String ? raw.toLowerCase() : '';
    final s = status ?? (raw is num ? raw.toInt() : null);
    final rpc = '${e['status'] ?? ''}';
    final message = '${e['message'] ?? ''}';
    var reason = '';
    Duration? wait;
    final quotas = <String>[];
    var zero = false;
    for (final d in GeminiFormat._maps(e['details'])) {
      final type = '${d['@type'] ?? ''}';
      if (type.endsWith('ErrorInfo')) reason = '${d['reason'] ?? ''}';
      if (type.endsWith('RetryInfo')) wait = durationOf(d['retryDelay']);
      if (type.endsWith('QuotaFailure')) {
        for (final v in GeminiFormat._maps(d['violations'])) {
          quotas.add('${v['quotaId'] ?? ''} ${v['quotaMetric'] ?? ''}');
          if ('${v['quotaValue'] ?? ''}' == '0') zero = true;
        }
      }
    }
    final asked = _retryIn.firstMatch(message);
    if (wait == null && asked != null) {
      final n = double.parse(asked.group(2)!);
      wait = Duration(milliseconds: (asked.group(3) == 'ms' ? n : n * 1000).round());
    }
    wait ??= AiHttpClient.retryAfterOf(headers);
    if (RegExp(r'limit: ?0\b').hasMatch(message)) zero = true;
    final freeTier = quotas.any((q) => q.contains('FreeTier') || q.contains('free_tier')) || RegExp(r'free[_ ]tier', caseSensitive: false).hasMatch(message);
    final kind = kindOf(status: s, code: code, rpc: rpc, reason: reason, message: message, freeTierZero: freeTier && zero);
    return AiError(kind, status: s, message: clean(message), retryAfter: wait);
  }

  /// The kind of an error from its HTTP [status], Interactions [code], gRPC
  /// status name [rpc], ErrorInfo [reason] and [message] (API errors pages,
  /// troubleshooting, billing and rate limits guides). A quota of the free
  /// tier at 0 ([freeTierZero]: the model has no free use, the project no
  /// billing) is a billing problem, not a wait.
  static AiErrorKind kindOf({int? status, String code = '', String rpc = '', String reason = '', String message = '', bool freeTierZero = false}) {
    if (reason == 'API_KEY_INVALID' || code == 'authentication' || rpc == 'UNAUTHENTICATED' || status == 401) return AiErrorKind.auth;
    if (status == 402 || code == 'payment_required') return AiErrorKind.credit;
    if (status == 429 || rpc == 'RESOURCE_EXHAUSTED' || const {'rate_limit_exceeded', 'quota_exceeded', 'too_many_requests'}.contains(code)) {
      if (_spendText.hasMatch(message)) return AiErrorKind.spendLimit;
      if (freeTierZero) return AiErrorKind.billing;
      if (_creditText.hasMatch(message)) return AiErrorKind.credit;
      return AiErrorKind.rateLimit;
    }
    // (a `not_found` in the stream is the service losing its own result, not the model)
    if (code == 'model_not_found' || status == 404) return AiErrorKind.notFound;
    if (status == 403 || code == 'permission_denied' || rpc == 'PERMISSION_DENIED') {
      if (_authText.hasMatch(message)) return AiErrorKind.auth;
      if (_billingText.hasMatch(message)) return AiErrorKind.billing;
      return AiErrorKind.permission;
    }
    if (_authText.hasMatch(message) && (status == 400 || rpc == 'INVALID_ARGUMENT')) return AiErrorKind.auth;
    if (code == 'failed_precondition' || rpc == 'FAILED_PRECONDITION') return AiErrorKind.billing;
    if (status == 413 || RegExp(r'payload size exceeds|request (entity |payload )?too large', caseSensitive: false).hasMatch(message)) return AiErrorKind.tooLarge;
    if (_context.hasMatch(message) && (status == null || status == 400)) return AiErrorKind.contextWindow;
    // the model wrote a call that could not be read: the same request may well do better
    if (const {'malformed_function_call', 'malformed_tool_call', 'unexpected_tool_call', 'too_many_tool_calls'}.contains(code)) return AiErrorKind.server;
    if (status == 400 ||
        status == 416 ||
        status == 501 ||
        rpc == 'INVALID_ARGUMENT' ||
        const {'invalid_request', 'parameter_unknown', 'out_of_range', 'unimplemented', 'missing_thought_signature'}.contains(code)) {
      return AiErrorKind.invalidRequest;
    }
    if (status == 503 || code == 'service_unavailable' || rpc == 'UNAVAILABLE') return AiErrorKind.overloaded;
    if (status == 504 || status == 408 || code == 'deadline_exceeded' || code == 'gateway_timeout' || rpc == 'DEADLINE_EXCEEDED') return AiErrorKind.timeout;
    if (status == 499 || code == 'cancelled' || code == 'aborted') return AiErrorKind.interrupted;
    if (code == 'api_error' || rpc == 'INTERNAL' || (status != null && status >= 500)) return AiErrorKind.server;
    // an error in the stream without a known code: the request did not go through
    return status == null ? AiErrorKind.server : AiErrorKind.http;
  }

  /// The tokens of an interaction's `usage`: the input without the tokens
  /// read from the implicit cache (plus those of tool-use prompts, billed as
  /// input), the output with the thinking tokens (billed as output). Caching
  /// is implicit: nothing is billed for writing to it.
  static AiUsage usageOf(Map<String, dynamic> u) {
    int v(String k) => u[k] is num ? (u[k] as num).toInt() : 0;
    final cached = v('total_cached_tokens');
    return AiUsage(input: math.max(0, v('total_input_tokens') - cached) + v('total_tool_use_tokens'), cacheRead: cached, output: v('total_output_tokens') + v('total_thought_tokens'));
  }
}

/// Builds the answer from the streamed events (or a whole interaction).
class _Turn {
  _Turn(this.client, this.listener, this.requested);
  final GeminiClient client;
  final AiStreamListener listener;
  final AiModel requested;
  final Map<int, Map<String, dynamic>> _steps = {};
  // the arguments of function calls and the growing text of the model's
  // output, by step (buffers: an answer of 64K tokens comes in thousands of deltas)
  final Map<int, StringBuffer> _args = {}, _open = {};
  List<Map<String, dynamic>>? _whole;

  /// The block that ended the answer: (category, explanation).
  (String, String)? _blocked;
  Map<String, dynamic> _usage = {};
  String model = '', id = '';
  String? _status;
  bool _done = false, sawText = false;
  int _last = -1;

  static Map<String, dynamic> _map(Object? o) => o is Map ? Map<String, dynamic>.from(o) : <String, dynamic>{};

  void _text(String s) {
    if (s.isEmpty) return;
    sawText = true;
    listener.onText?.call(s);
  }

  /// An interaction object: created, completed, or the whole answer.
  void whole(Map<String, dynamic> it) {
    if (it['model'] is String) model = it['model'] as String;
    if (it['id'] is String) id = it['id'] as String;
    if (it['status'] is String) _status = it['status'] as String;
    if (it['usage'] is Map) _usage = _map(it['usage']);
    final steps = GeminiFormat._maps(it['steps']);
    if (steps.isNotEmpty) _whole = steps;
    if (const {'completed', 'requires_action', 'incomplete', 'requires_continuation', 'failed', 'cancelled'}.contains(_status)) _done = true;
    if (_status == 'failed') {
      final errors = GeminiFormat._maps(it['errors']);
      final e = it['error'] is Map ? _map(it['error']) : (errors.isNotEmpty ? errors.first : <String, dynamic>{});
      _fail(e);
    }
  }

  int _index(Map<String, dynamic> e) => e['index'] is num ? (e['index'] as num).toInt() : _last;

  void event(Map<String, dynamic> e) {
    listener.onActivity?.call();
    switch (e['event_type']) {
      case 'interaction.created' || 'interaction.completed':
        if (e['interaction'] is Map) whole(_map(e['interaction']));
        if (e['event_type'] == 'interaction.completed') _done = true;
      case 'interaction.status_update':
        if (e['status'] is String) _status = e['status'] as String;
      case 'step.start':
        final i = e['index'] is num ? (e['index'] as num).toInt() : _last + 1;
        _last = i;
        final s = _map(e['step']);
        _steps[i] = s;
        if (s['type'] == 'function_call') listener.onToolStart?.call('${s['name'] ?? ''}');
        if (s['type'] == 'model_output') {
          final content = GeminiFormat._maps(s['content']);
          for (final c in content) {
            if (c['type'] == 'text') _text('${c['text'] ?? ''}');
          }
          // a plain text part at the end goes on growing with the deltas
          if (content.isNotEmpty && GeminiFormat._shaped(content.last, const ['type', 'text'])) {
            _open[i] = StringBuffer('${content.last['text'] ?? ''}');
            s['content'] = content.sublist(0, content.length - 1);
          }
        }
      case 'step.delta':
        _delta(_index(e), _map(e['delta']));
      case 'step.stop':
        if (e['usage'] is Map) _usage = _map(e['usage']);
      case 'error':
        _fail(_map(e['error']));
    }
  }

  void _delta(int i, Map<String, dynamic> d) {
    final type = d['type'];
    final s = _steps[i] ??= {
      'type': switch (type) {
        'arguments_delta' => 'function_call',
        'thought_signature' || 'thought_summary' => 'thought',
        _ => 'model_output',
      },
    };
    switch (type) {
      case 'text':
        final t = '${d['text'] ?? ''}';
        (_open[i] ??= StringBuffer()).write(t);
        _text(t);
      case 'arguments_delta':
        (_args[i] ??= StringBuffer()).write('${d['arguments'] ?? ''}');
      case 'thought_signature':
        s['signature'] = '${d['signature'] ?? ''}';
      case 'thought_summary':
        s['summary'] = [if (s['summary'] is List) ...s['summary'] as List, if (d['content'] != null) d['content']];
      case 'image' || 'audio':
        _close(i);
        s['content'] = [
          if (s['content'] is List) ...s['content'] as List,
          {for (final x in d.entries) x.key: x.value},
        ];
      default:
        // another step's fields, as they come
        for (final x in d.entries) {
          if (x.key != 'type') s[x.key] = x.value;
        }
    }
  }

  /// The text of step [i] that is still growing, as its last content part.
  void _close(int i) {
    final b = _open.remove(i);
    final s = _steps[i];
    if (b == null || s == null) return;
    s['content'] = [
      if (s['content'] is List) ...s['content'] as List,
      {'type': 'text', 'text': b.toString()},
    ];
  }

  /// An error in the stream or a failed interaction: a block ends the answer
  /// as a refusal, anything else fails the request.
  void _fail(Map<String, dynamic> e) {
    final b = client.blockedOf(e);
    if (b != null) {
      _blocked = b;
      _done = true;
      return;
    }
    throw client.errorOf(null, e).withRequestId(id.isEmpty ? null : id);
  }

  AiReply refusal(String category, String explanation) => AiReply(
    items: const [],
    text: '',
    calls: const [],
    stop: AiStop.refusal,
    model: model.isEmpty ? requested.id : model,
    usage: GeminiClient.usageOf(_usage),
    category: category,
    explanation: explanation,
  );

  AiReply finish() {
    final b = _blocked;
    if (b != null) return refusal(b.$1, b.$2);
    if (!_done) throw AiError(AiErrorKind.interrupted, partial: sawText);
    if (_status == 'cancelled' || _status == 'in_progress') throw AiError(AiErrorKind.interrupted, partial: sawText);
    final List<Map<String, dynamic>> steps;
    final raw = <int, String>{};
    final whole = _whole;
    if (whole != null) {
      steps = whole;
    } else {
      for (final k in [..._open.keys]) {
        _close(k);
      }
      final keys = _steps.keys.toList()..sort();
      steps = [];
      for (final k in keys) {
        final s = _steps[k]!;
        final a = _args[k]?.toString();
        if (s['type'] == 'function_call' && a != null && a.isNotEmpty) {
          raw[steps.length] = a;
          final (input, _) = parseToolInput(a);
          s['arguments'] = input ?? <String, dynamic>{};
        }
        steps.add(s);
      }
    }
    final items = GeminiFormat.itemsOf(steps, raw: raw);
    final calls = OpenAiFormat.calls(items);
    final text = OpenAiFormat.text(items);
    final cut = _status == 'incomplete' || _status == 'requires_continuation';
    // no step at all, not even the thought (with its signature) every answer carries: a silent block
    if (steps.isEmpty && !cut) return refusal('empty', '');
    final stop = cut ? AiStop.maxTokens : (calls.isNotEmpty ? AiStop.tool : AiStop.end);
    return AiReply(
      items: calls.isNotEmpty || text.isNotEmpty ? items : const [],
      text: text,
      calls: calls,
      stop: stop,
      model: model.isEmpty ? requested.id : model,
      usage: GeminiClient.usageOf(_usage),
    );
  }
}
