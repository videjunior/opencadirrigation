/// xAI's Responses API (`POST https://api.x.ai/v1/responses`) as the AI
/// assistant uses it for the Grok models: called straight from the user's
/// browser or desktop with the user's own xAI key, no server in between.
///
/// It has the shape of OpenAI's Responses API, so the client is
/// [OpenAiClient] with what differs changed, and a conversation is kept in
/// the same format. Pure Dart; the key goes in the authorization header of
/// the request to xAI and nowhere else.
///
/// What differs, from xAI's documentation (docs.x.ai, read 2026-11-10):
///
/// * Storage: the Responses API stores every response for 30 days unless
///   the request says `store: false`, which it always does here; the whole
///   conversation goes with each request, the reasoning items with their
///   `encrypted_content` sent back exactly as they came (asking for them in
///   `include` also keeps xAI from storing the thinking trace for later
///   requests). xAI still keeps requests and responses 30 days for abuse
///   audits unless the team has zero data retention.
/// * Caching is automatic and hits only on the server that saw the prefix:
///   `prompt_cache_key` routes every request of one conversation to the
///   same server ([cacheKey]). A cache read costs the model's cached-input
///   price; nothing is billed for writing.
/// * `context_management` is "parsed but not yet executed": never sent.
///   xAI's compaction is a request of its own ([compact]).
/// * `max_output_tokens` limits only the visible answer, not the reasoning
///   or the function calls; `usage.output_tokens` likewise leaves the
///   reasoning tokens out (they are billed at the output price) ([usageOf]).
/// * Pictures: JPEG and PNG only, up to 20 MiB each ([acceptedImageUrl]).
///   A PDF goes inline as raw base64 with its media type; xAI then searches
///   it with its own attachment search, a server-side tool billed per call.
/// * Errors come as `{"code": "invalid-argument", "error": "…"}`, and a key
///   xAI does not know gets a 400, not a 401 ([kindOf]).
/// * Sampling: the documentation asks for `temperature` 0.7 and `top_p`
///   0.95 on every request.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import 'image_prep.dart' show modelJpegQuality;
import 'llm_formats.dart';
import 'openai_api.dart';

class XaiClient extends OpenAiClient {
  XaiClient({required super.apiKey, required super.transport, super.sleep, super.maxRetries});

  static final endpoint = Uri.parse('https://api.x.ai/v1/responses');

  /// xAI's compaction (`POST /v1/responses/compact`), see [compact].
  static final compactEndpoint = Uri.parse('https://api.x.ai/v1/responses/compact');

  /// The sampling xAI's best-practices guide asks for on every request
  /// ("Grok models don't respond well to other sampling settings").
  static const temperature = 0.7, topP = 0.95;

  /// The picture types xAI reads (its image-understanding page).
  static const acceptedImageTypes = {'image/jpeg', 'image/png'};

  /// Category of a request declined under xAI's usage guidelines.
  static const policyCategory = 'usage_guidelines';

  @override
  Uri get url => endpoint;

  @override
  AiProvider get provider => AiProvider.xai;

  /// Never: xAI parses `context_management` but does not act on it.
  @override
  bool compacts(AiRequest r) => false;

  /// Fields worth having but not worth a failed request: a model that turns
  /// one down gets its requests without it.
  static const _optional = ['prompt_cache_key', 'temperature', 'top_p'];

  @override
  List<String> optionalFields(AiRequest r) => [
    for (final f in _optional)
      if (offers(r.model, f)) f,
  ];

  /// xAI's efforts are low, medium, high and xhigh (`grok-4.3` also takes
  /// none): the app's highest goes as xhigh. A model that lacks xhigh reads
  /// it as high (reasoning page).
  @override
  String effortOf(AiModel m, AiEffort e) {
    final x = m.effortFor(e);
    return x == AiEffort.max ? AiEffort.xhigh.name : x.name;
  }

  /// The conversation as OpenAI's client sends it, with the pictures xAI
  /// cannot read turned into JPEG or PNG and the PDFs as xAI takes them.
  @override
  List<Map<String, dynamic>> inputOf(AiRequest r) => [for (final it in super.inputOf(r)) itemFor(it)];

  @override
  Map<String, Object?> body(AiRequest r) => {
    ...super.body(r),
    if (offers(r.model, 'prompt_cache_key')) 'prompt_cache_key': cacheKey(r),
    if (offers(r.model, 'temperature')) 'temperature': temperature,
    if (offers(r.model, 'top_p')) 'top_p': topP,
  };

  /// The `prompt_cache_key` of [r]'s conversation: the same for every
  /// request of it (the system prompt and the first entry of a conversation
  /// never change), another for another conversation. A hash: nothing of
  /// the conversation can be read from it.
  static String cacheKey(AiRequest r) => 'oci-${_hash('${r.system}\u0000${r.history.isEmpty ? '' : jsonEncode(r.history.first)}')}';

  /// Two 32-bit FNV-1a lanes over the first million characters of [s] and
  /// its length, as 16 hex digits. The multiplication is split so that it
  /// stays exact where an int is a double (the web).
  static String _hash(String s) {
    int step(int h, int c) {
      h = (h ^ c) & 0xFFFFFFFF;
      return (h * 0x193 + ((h << 24) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    }

    var a = 0x811C9DC5, b = 0x3C6EF372;
    final n = math.min(s.length, 1 << 20);
    for (var i = 0; i < n; i++) {
      final c = s.codeUnitAt(i);
      a = step(a, c);
      b = step(b, c ^ 0x5A5A);
    }
    a = step(a, s.length & 0xFFFF);
    b = step(b, (s.length >> 16) & 0xFFFF);
    return '${a.toRadixString(16).padLeft(8, '0')}${b.toRadixString(16).padLeft(8, '0')}';
  }

  /// [it], an entry of the conversation, as xAI takes it: the parts of a
  /// message and of a function output with their pictures in a type xAI
  /// reads and their PDFs as raw base64 (`file_data`) with `mime_type`.
  /// Everything else — the model's own items above all — goes as it is.
  static Map<String, dynamic> itemFor(Map<String, dynamic> it) {
    final field = it['type'] == 'message'
        ? 'content'
        : it['type'] == 'function_call_output'
        ? 'output'
        : null;
    final parts = field == null ? null : it[field];
    if (parts is! List) return it;
    List<Object?>? out;
    for (var i = 0; i < parts.length; i++) {
      final p = parts[i];
      final q = p is Map ? _part(p) : p;
      if (!identical(p, q)) (out ??= List<Object?>.of(parts))[i] = q;
    }
    return out == null ? it : {...it, field!: out};
  }

  static Object _part(Map p) {
    switch (p['type']) {
      case 'input_image':
        final url = '${p['image_url'] ?? ''}';
        final fixed = acceptedImageUrl(url);
        return fixed == url ? p : {...p, 'image_url': fixed};
      case 'input_file':
        final d = OpenAiFormat.fromDataUrl('${p['file_data'] ?? ''}');
        if (d == null) return p;
        // "Inline file bytes (base64 encoded)"; the file name is required with them
        return {'type': 'input_file', 'filename': '${p['filename'] ?? 'document.pdf'}', 'file_data': d.$2, 'mime_type': d.$1};
    }
    return p;
  }

  /// The pictures converted lately (data URL → data URL), so that a
  /// conversation's pictures, sent again with every request, are converted
  /// once and always to the same bytes.
  static final Map<String, String> _converted = {};

  /// [url] as xAI reads it: a JPEG or PNG data URL (or a web address) as it
  /// is; another picture (a GIF or WebP the user attached) decoded and sent
  /// as PNG when it is a GIF or is transparent somewhere, otherwise as a JPEG
  /// at the app's quality, at its own size, so positions on it hold. A picture that cannot be decoded
  /// goes as it came (the API then refuses it, and the loop takes it out).
  static String acceptedImageUrl(String url) {
    final d = OpenAiFormat.fromDataUrl(url);
    if (d == null || acceptedImageTypes.contains(d.$1)) return url;
    final hit = _converted.remove(url);
    if (hit != null) return _converted[url] = hit;
    final out = _convert(d.$1, d.$2) ?? url;
    _converted[url] = out;
    while (_converted.length > 8) {
      _converted.remove(_converted.keys.first);
    }
    return out;
  }

  static String? _convert(String type, String base64) {
    try {
      var im = img.decodeImage(base64Decode(base64), frame: 0);
      if (im == null) return null;
      if (im.hasPalette || im.format != img.Format.uint8) im = im.convert(format: img.Format.uint8, numChannels: im.hasAlpha ? 4 : 3);
      if (type == 'image/gif' || _transparent(im)) return OpenAiFormat.dataUrl('image/png', base64Encode(img.encodePng(im)));
      return OpenAiFormat.dataUrl('image/jpeg', base64Encode(img.encodeJpg(im.hasAlpha ? im.convert(numChannels: 3) : im, quality: modelJpegQuality)));
    } catch (_) {
      return null;
    }
  }

  /// Some pixel of [im] is not opaque (a WebP decodes with an alpha channel
  /// even when every pixel is opaque).
  static bool _transparent(img.Image im) {
    if (!im.hasAlpha) return false;
    for (final p in im) {
      if (p.a < p.maxChannelValue) return true;
    }
    return false;
  }

  /// Tokens of a response's (or a compaction's) `usage`. `input_tokens`
  /// counts the cached ones (`input_tokens_details.cached_tokens`); in the
  /// documented responses `total_tokens` is input + output + reasoning, so
  /// `output_tokens` leaves the reasoning out (a compaction's counts it in):
  /// the output is what the total adds to the input, which holds either way,
  /// else output plus reasoning.
  @override
  AiUsage usageOf(Map<String, dynamic> usage) {
    int v(Object? m, String k) => m is Map ? (m[k] as num?)?.toInt() ?? 0 : 0;
    final input = v(usage, 'input_tokens');
    final cached = math.min(input, v(usage['input_tokens_details'], 'cached_tokens'));
    final out = v(usage, 'output_tokens'), total = v(usage, 'total_tokens');
    final output = total > 0 && total - input >= out ? total - input : out + v(usage['output_tokens_details'], 'reasoning_tokens');
    return AiUsage(input: input - cached, cacheRead: cached, output: output);
  }

  /// A response xAI ended because the prompt is longer than the model reads
  /// fails as [AiErrorKind.contextWindow]; an `error` event whose error is
  /// nested (as in xAI's WebSocket mode) is read like OpenAI's.
  @override
  Map<String, dynamic>? eventOf(Map<String, dynamic> event) {
    if (event['type'] == 'response.incomplete') {
      final r = event['response'];
      final d = r is Map ? r['incomplete_details'] : null;
      if (d is Map && d['reason'] == 'max_prompt_tokens') throw AiError(AiErrorKind.contextWindow, message: 'incomplete: max_prompt_tokens');
    }
    return event;
  }

  static final _badKey = RegExp(r'incorrect api key|invalid api key|api key (is )?(invalid|incorrect|not valid|revoked|disabled|blocked|expired)|no credentials', caseSensitive: false);
  static final _noCredit = RegExp(
    r"(doesn'?t|does not|don'?t|do not) have any credits|(used|exhausted|run out of|ran out of) (up )?(all )?(of )?(your |its |the )?(available |prepaid )?credits|insufficient (credits|balance|funds)|purchase (more )?credits|no credits",
    caseSensitive: false,
  );
  static final _spendLimit = RegExp(r'spending limit|billing limit', caseSensitive: false);
  static final _policy = RegExp(r'usage guideline|violat\w* (of )?(our |the |xai.s )?(usage |content |acceptable use )?polic', caseSensitive: false);
  static final _tooLong = RegExp(r'maximum (prompt|context) length|context (length|window)|prompt is too long|too many (input |prompt )?tokens|prompt tokens? (exceed|limit)', caseSensitive: false);
  static final _noModel = RegExp(r'model .* does not exist|does not have access to (the )?model', caseSensitive: false);

  /// The kind of an xAI error from its HTTP [status] (null inside a
  /// stream), its `code` (gRPC names: `invalid-argument`, `not-found`,
  /// `unauthenticated:no-credentials`, `permission-denied`,
  /// `resource-exhausted`…) and its message. The message decides first: a
  /// key xAI does not know is a 400 "Incorrect API key provided", and an
  /// account out of credits or over its spending limit is told in words
  /// whatever the status.
  static AiErrorKind kindOf(int? status, String type, String code, String message) {
    final c = code.toLowerCase().replaceAll(RegExp(r'[_\s]+'), '-');
    if (_badKey.hasMatch(message) || c.startsWith('unauthenticated')) return AiErrorKind.auth;
    if (_noCredit.hasMatch(message)) return AiErrorKind.credit;
    if (_spendLimit.hasMatch(message)) return AiErrorKind.spendLimit;
    if (_policy.hasMatch(message)) return AiErrorKind.refusal;
    if (_tooLong.hasMatch(message)) return AiErrorKind.contextWindow;
    if (status == 413) return AiErrorKind.tooLarge;
    if (_noModel.hasMatch(message) || c.contains('not-found')) return AiErrorKind.notFound;
    if (c.contains('permission')) return AiErrorKind.permission;
    if (c.contains('exhausted')) return AiErrorKind.rateLimit;
    if (c.contains('unavailable')) return AiErrorKind.overloaded;
    if (c.contains('internal') || c.contains('unknown') || c.contains('deadline') || c.contains('aborted') || c.contains('data-loss')) return AiErrorKind.server;
    if (c.contains('invalid-argument') || c.contains('failed-precondition') || c.contains('out-of-range') || c.contains('unimplemented')) {
      return status != null && status >= 500 ? AiErrorKind.server : AiErrorKind.invalidRequest;
    }
    return OpenAiClient.kindOf(status, type, code, message);
  }

  @override
  AiErrorKind errorKind(int? status, String type, String code, String message) => kindOf(status, type, code, message);

  /// The error of a response that is not a success: xAI's body is
  /// `{"code": …, "error": "<message>"}`; OpenAI's nested `error` object is
  /// read too.
  @override
  AiError httpError(int status, String body, Map<String, String> headers) {
    var type = '', code = '', message = '';
    try {
      final j = jsonDecode(body);
      if (j is Map) {
        final e = j['error'];
        if (e is Map) {
          type = '${e['type'] ?? ''}';
          code = '${e['code'] ?? j['code'] ?? ''}';
          message = '${e['message'] ?? ''}';
        } else {
          code = '${j['code'] ?? ''}';
          message = e is String ? e : '${j['message'] ?? body}';
        }
      } else {
        message = body;
      }
    } catch (_) {
      message = body;
    }
    final kind = errorKind(status, type, code, message);
    return AiError(
      kind,
      status: status,
      message: clean(message),
      retryAfter: AiHttpClient.retryAfterOf(headers),
      requestId: headers[requestIdHeader],
      category: kind == AiErrorKind.refusal ? policyCategory : null,
    );
  }

  /// The error of a failed response or of an `error` event, whose error may
  /// be a text, an object, or nested in the event.
  @override
  AiError errorOf(Object? e) {
    Object? m = e is String ? {'message': e} : e;
    if (m is Map) {
      final inner = m['error'];
      if (inner is Map) {
        m = {...inner, 'type': inner['type'] ?? m['type']};
      } else if (inner is String && m['message'] == null) {
        m = {...m, 'message': inner};
      }
    }
    final x = super.errorOf(m);
    return x.kind == AiErrorKind.refusal && x.category == null ? AiError(AiErrorKind.refusal, message: x.message, category: policyCategory) : x;
  }

  /// Also without xAI's masked keys (`xai-a**b`).
  @override
  String clean(String s) => super.clean(s.replaceAll(RegExp(r'xai-[A-Za-z0-9_\-]*\*+[A-Za-z0-9_\-]*'), '[key]'));

  /// [history] folded by xAI into one compaction item (`POST
  /// /v1/responses/compact`, stateless: the item comes back and nothing is
  /// kept), which then stands for all of it: the next requests start at it
  /// ([sinceCompactionItem]) and go on after it. The call is billed (the
  /// whole conversation read once more, and the summary written), and the
  /// tokens are returned with the items. Not used by the agent loop yet.
  Future<(List<Map<String, dynamic>> items, AiUsage usage)> compact(AiModel m, List<Map<String, dynamic>> history, {required AiCancel cancel}) async {
    if (apiKey.trim().isEmpty) throw AiError(AiErrorKind.noKey);
    final json = jsonEncode({
      'model': m.id,
      'input': [for (final it in pruneToolPictures(sinceCompactionItem(history))) itemFor(it)],
    });
    AiHttpClient.checkSize(json);
    final res = await open(AiHttpRequest(compactEndpoint, headers(), json), m, cancel);
    final text = StringBuffer();
    await readLines(res.body, m, (l) => text.writeln(l), cancel, idle: idleTimeout(m));
    if (res.status < 200 || res.status >= 300) throw httpError(res.status, text.toString(), res.headers);
    final Object? j;
    try {
      j = jsonDecode(text.toString());
    } catch (_) {
      throw AiError(AiErrorKind.http, status: res.status, message: clean(text.toString()), requestId: res.headers[requestIdHeader]);
    }
    final out = [
      if (j is Map && j['output'] is List)
        for (final x in j['output'] as List)
          if (x is Map) Map<String, dynamic>.from(x),
    ];
    if (!out.any((it) => it['type'] == 'compaction')) throw AiError(AiErrorKind.http, status: res.status, message: 'no compaction item', requestId: res.headers[requestIdHeader]);
    final u = j is Map ? j['usage'] : null;
    return (out, u is Map ? usageOf(Map<String, dynamic>.from(u)) : AiUsage.zero);
  }
}
