// The xAI client (Grok, Responses API) against a scripted server that copies
// the wire shapes of xAI's documentation (docs.x.ai, 2026-11-10): data-only
// server-sent events ending in `data: [DONE]`, reasoning items carrying
// `encrypted_content`, function calls arriving whole, usage whose
// `output_tokens` leaves the reasoning out, `{"code", "error"}` error bodies
// and the 400 a key xAI does not know gets. No network.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/ai/llm_formats.dart';
import 'package:opencadirrigation/core/ai/openai_api.dart';
import 'package:opencadirrigation/core/ai/xai_api.dart';

typedef _Reply = AiHttpResponse Function(Map<String, dynamic> body, int n);

/// A scripted xAI server: answers the requests in order and records them.
class _FakeXai {
  _FakeXai(this.script);
  final List<_Reply> script;
  final requests = <AiHttpRequest>[];
  final bodies = <Map<String, dynamic>>[];

  int get calls => requests.length;

  Future<AiHttpResponse> call(AiHttpRequest r, AiCancel cancel) async {
    requests.add(r);
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    bodies.add(body);
    final n = requests.length - 1;
    return n < script.length ? script[n](body, n) : _answer(text: '(end of script)')(body, n);
  }

  List<Map<String, dynamic>> input(int n) => (bodies[n]['input'] as List).cast<Map<String, dynamic>>();
}

/// xAI's usage object (the documented convention: total = input + output + reasoning).
Map<String, dynamic> _usage({int input = 1500, int cached = 300, int output = 40, int reasoning = 20}) => {
  'input_tokens': input,
  'input_tokens_details': {'cached_tokens': cached},
  'output_tokens': output,
  'output_tokens_details': {'reasoning_tokens': reasoning},
  'total_tokens': input + output + reasoning,
  'num_sources_used': 0,
  'num_server_side_tools_used': 0,
  'cost_in_usd_ticks': 37756000,
};

/// Data-only server-sent events, as xAI streams them, in uneven chunks.
AiHttpResponse _sse(List<Map<String, dynamic>> events, {bool done = true, Map<String, String> headers = const {}}) {
  final text = StringBuffer();
  for (final e in events) {
    text.write('data: ${jsonEncode(e)}\n\n');
  }
  if (done) text.write('data: [DONE]\n\n');
  final bytes = utf8.encode(text.toString());
  final chunks = <List<int>>[for (var k = 0; k < bytes.length; k += 97) bytes.sublist(k, k + 97 > bytes.length ? bytes.length : k + 97)];
  return AiHttpResponse(200, {'content-type': 'text/event-stream', ...headers}, Stream.fromIterable(chunks));
}

AiHttpResponse _json(int status, Object body, {Map<String, String> headers = const {}}) =>
    AiHttpResponse(status, {'content-type': 'application/json', ...headers}, Stream.value(utf8.encode(body is String ? body : jsonEncode(body))));

/// One answer: a reasoning item (encrypted), then a message with [text]
/// (or a refusal), then [calls] whole (xAI does not stream the arguments),
/// then [extra] items; ending as [status] (`completed`, `incomplete` with
/// [reason]), or cut off before the end ([cut]).
_Reply _answer({
  String text = '',
  String refusal = '',
  List<(String, Map<String, dynamic>)> calls = const [],
  List<Map<String, dynamic>> extra = const [],
  Map<String, dynamic>? usage,
  String status = 'completed',
  String? reason,
  bool cut = false,
  String model = 'grok-4.7',
}) => (body, n) {
  final events = <Map<String, dynamic>>[];
  var seq = 0;
  void ev(String type, Map<String, dynamic> data) => events.add({'type': type, 'sequence_number': seq++, ...data});
  final resp = {'id': 'resp_$n', 'object': 'response', 'status': 'in_progress', 'model': model, 'output': <Object?>[], 'store': false};
  ev('response.created', {'response': resp});
  ev('response.in_progress', {'response': resp});
  final output = <Map<String, dynamic>>[];
  var i = 0;
  final rs = {'id': 'rs_$n', 'type': 'reasoning', 'summary': <Object?>[], 'status': 'in_progress'};
  ev('response.output_item.added', {'output_index': i, 'item': rs});
  ev('response.reasoning_summary_text.delta', {'output_index': i, 'summary_index': 0, 'delta': 'Thinking about the pipes'});
  final rsDone = {
    'id': 'rs_$n',
    'type': 'reasoning',
    'summary': [
      {'type': 'summary_text', 'text': 'Thinking about the pipes'},
    ],
    'status': 'completed',
    'encrypted_content': 'enc_${n}_opaque+/=',
  };
  ev('response.output_item.done', {'output_index': i, 'item': rsDone});
  output.add(rsDone);
  i++;
  if (text.isNotEmpty || refusal.isNotEmpty) {
    final id = 'msg_${n}_us-east-1';
    ev('response.output_item.added', {
      'output_index': i,
      'item': {'id': id, 'type': 'message', 'role': 'assistant', 'status': 'in_progress', 'content': <Object?>[]},
    });
    final Map<String, dynamic> part;
    if (refusal.isNotEmpty) {
      part = {'type': 'refusal', 'refusal': refusal};
    } else {
      final half = text.length ~/ 2;
      for (final d in [text.substring(0, half), text.substring(half)]) {
        ev('response.output_text.delta', {'item_id': id, 'output_index': i, 'content_index': 0, 'delta': d});
      }
      ev('response.output_text.done', {'item_id': id, 'output_index': i, 'content_index': 0, 'text': text});
      part = {'type': 'output_text', 'text': text, 'logprobs': null, 'annotations': <Object?>[]};
    }
    if (cut) return _sse(events, done: false);
    final msg = {
      'id': id,
      'type': 'message',
      'role': 'assistant',
      'status': 'completed',
      'content': [part],
    };
    ev('response.output_item.done', {'output_index': i, 'item': msg});
    output.add(msg);
    i++;
  }
  for (final (k, (name, input)) in calls.indexed) {
    final call = {'id': 'fc_${n}_$k', 'type': 'function_call', 'call_id': 'call_${n}_$k', 'name': name, 'arguments': jsonEncode(input), 'status': 'completed'};
    ev('response.output_item.added', {'output_index': i, 'item': call});
    ev('response.function_call_arguments.done', {'item_id': call['id'], 'output_index': i, 'arguments': call['arguments']});
    ev('response.output_item.done', {'output_index': i, 'item': call});
    output.add(call);
    i++;
  }
  for (final it in extra) {
    ev('response.output_item.added', {'output_index': i, 'item': it});
    ev('response.output_item.done', {'output_index': i, 'item': it});
    output.add(it);
    i++;
  }
  ev('response.$status', {
    'response': {
      ...resp,
      'status': status,
      'output': output,
      'usage': usage ?? _usage(),
      'incomplete_details': reason == null ? null : {'reason': reason},
    },
  });
  return _sse(events);
};

/// An xAI error body (`{"code": …, "error": "<message>"}`).
_Reply _error(int status, String code, String message, {Map<String, String> headers = const {}}) =>
    (_, _) => _json(status, {'code': code, 'error': message}, headers: headers);

void main() {
  const key = 'xai-SECRET-test-key-0000000000';

  final waits = <Duration>[];
  XaiClient api(_FakeXai f) => XaiClient(apiKey: key, transport: f.call, sleep: (d) async => waits.add(d));

  final ran = <String>[];
  AgentTool tool(String name, {ToolOutput Function(Map<String, dynamic>)? out}) => FnTool(
    name: name,
    description: 'test tool $name',
    effect: ToolEffect.read,
    inputSchema: {
      'type': 'object',
      'properties': {
        'x': {'type': 'number'},
      },
      'additionalProperties': false,
    },
    handler: (i) async {
      ran.add(name);
      return out?.call(i) ?? ToolOutput('$name ok ${jsonEncode(i)}');
    },
  );

  Map<String, dynamic> user(String s) => OpenAiFormat.user([AiTextPart(s)]);
  AiRequest req(AiModel m, List<Map<String, dynamic>> history, {AiEffort effort = AiEffort.medium, List<AiToolSpec> tools = const [], int? compactAt}) =>
      AiRequest(model: m, system: 'You design irrigation.', history: history, tools: tools, effort: effort, compactAt: compactAt);

  Future<(AiError, _FakeXai)> failure(List<_Reply> script, {AiModel? model}) async {
    final f = _FakeXai(script);
    try {
      await api(f).send(req(model ?? AiModel.grok47, [user('q')]), cancel: AiCancel());
    } on AiError catch (e) {
      return (e, f);
    }
    throw StateError('no error');
  }

  setUp(() {
    ran.clear();
    waits.clear();
    AiHttpClient.declined.clear();
  });

  test('the request: xAI\'s endpoint, the key only as a bearer, store false, encrypted reasoning asked for, the documented sampling, function tools only, no compaction field', () async {
    final f = _FakeXai([_answer(text: 'Hello')]);
    final r = await api(f).send(
      req(AiModel.grok47, [user('hi')], effort: AiEffort.high, tools: [tool('a').spec], compactAt: 190000),
      cancel: AiCancel(),
    );
    expect(r.text, 'Hello');
    expect(r.stop, AiStop.end);
    expect(r.model, 'grok-4.7');
    final q = f.requests.single;
    expect(q.url.toString(), 'https://api.x.ai/v1/responses');
    expect(q.url.host, AiProvider.xai.host);
    expect(q.headers, {'content-type': 'application/json', 'authorization': 'Bearer $key'});
    expect(q.body.contains(key), isFalse);
    final b = f.bodies.single;
    expect(b.keys.toSet(), {'model', 'instructions', 'input', 'tools', 'reasoning', 'max_output_tokens', 'stream', 'store', 'include', 'prompt_cache_key', 'temperature', 'top_p'});
    expect(b['model'], 'grok-4.7');
    expect(b['instructions'], 'You design irrigation.');
    expect(b['input'], [user('hi')]);
    expect(b['store'], isFalse);
    expect(b['stream'], isTrue);
    expect(b['include'], ['reasoning.encrypted_content']);
    expect(b['reasoning'], {'effort': 'high'});
    expect(b['temperature'], 0.7);
    expect(b['top_p'], 0.95);
    expect(b['max_output_tokens'], AiModel.grok47.maxOutput);
    expect(b['prompt_cache_key'], matches(RegExp(r'^oci-[0-9a-f]{16}$')));
    expect(b.containsKey('context_management'), isFalse, reason: 'xAI parses it but does not act on it');
    expect(b.containsKey('previous_response_id'), isFalse);
    // no server-side tool (web, X, code, collections) is ever enabled
    expect([for (final t in b['tools'] as List) (t as Map)['type']], ['function']);
    expect(b['tools'], [
      {'type': 'function', 'name': 'a', 'description': 'test tool a', 'parameters': tool('a').inputSchema, 'strict': false},
    ]);
    // the reasoning item with its encrypted content is kept as it came
    expect(r.items.first['encrypted_content'], 'enc_0_opaque+/=');
    expect(OpenAiFormat.text(r.items), r.text);
  });

  test('a turn with parallel tool calls: nothing stored, the whole conversation each time, the encrypted reasoning replayed unchanged, one cache key', () async {
    final f = _FakeXai([
      _answer(
        text: 'Let me look.',
        calls: [
          ('look', {'x': 1}),
          ('snap', {}),
        ],
      ),
      _answer(
        calls: [
          ('look', {'x': 2}),
        ],
      ),
      _answer(text: 'Seen it.'),
    ]);
    final texts = <String>[];
    final turn =
        await AgentLoop(
          api: api(f),
          tools: [
            tool('look'),
            tool('snap', out: (_) => const ToolOutput('a view', images: [ToolImage('image/png', 'iVBORw0K')])),
          ],
        ).run(
          model: AiModel.grok47,
          system: 's',
          history: const [],
          user: user('go'),
          cancel: AiCancel(),
          events: AgentEvents(onText: texts.add),
        );
    expect(turn.stop, AgentStop.done);
    expect(ran, ['look', 'snap', 'look']);
    expect(turn.text, 'Let me look.\n\nSeen it.');
    expect(texts.join(), turn.text);
    expect(f.calls, 3);
    for (final b in f.bodies) {
      expect(b['store'], isFalse);
      expect(b.containsKey('previous_response_id'), isFalse);
    }
    // each request carries the one before it, byte for byte, and what came back
    for (var n = 1; n < 3; n++) {
      expect(jsonEncode(f.input(n).sublist(0, f.input(n - 1).length)), jsonEncode(f.input(n - 1)));
    }
    final second = f.input(1);
    expect(second.map((i) => i['type']), ['message', 'reasoning', 'message', 'function_call', 'function_call', 'function_call_output', 'function_call_output']);
    expect(second[1], {
      'id': 'rs_0',
      'type': 'reasoning',
      'summary': [
        {'type': 'summary_text', 'text': 'Thinking about the pipes'},
      ],
      'status': 'completed',
      'encrypted_content': 'enc_0_opaque+/=',
    });
    final third = f.input(2);
    expect(third.where((i) => i['type'] == 'reasoning').map((i) => i['encrypted_content']), ['enc_0_opaque+/=', 'enc_1_opaque+/=']);
    final outs = second.where((i) => i['type'] == 'function_call_output').toList();
    expect(outs.map((o) => o['call_id']), ['call_0_0', 'call_0_1']);
    expect(outs.first['output'], 'look ok {"x":1}');
    // the tool's picture goes inside its function output, where Grok sees it
    expect(outs.last['output'], [
      {'type': 'input_text', 'text': 'a view'},
      {'type': 'input_image', 'image_url': 'data:image/png;base64,iVBORw0K', 'detail': 'high'},
    ]);
    expect(f.bodies.map((b) => b['prompt_cache_key']).toSet().length, 1, reason: 'one conversation, one server');
    expect(jsonEncode(turn.messages.sublist(0, third.length)), jsonEncode(third));
    expect(turn.cost, greaterThan(0));
  });

  test('the cache key: the same through a conversation, another for another conversation, nothing of the text in it', () {
    final a = [user('Design drip lines for the orchard.')];
    final k1 = XaiClient.cacheKey(req(AiModel.grok47, a));
    final k2 = XaiClient.cacheKey(req(AiModel.grok47, [...a, ...OpenAiFormat.assistant('Sure.', const []), user('And the valves?')]));
    final k3 = XaiClient.cacheKey(req(AiModel.grok43, [...a, user('later')]));
    final other = XaiClient.cacheKey(req(AiModel.grok47, [user('Size the pump.')]));
    expect(k2, k1);
    expect(k3, k1, reason: 'another model of the same conversation keeps it');
    expect(other, isNot(k1));
    expect(XaiClient.cacheKey(AiRequest(model: AiModel.grok47, system: 'other prompt', history: a)), isNot(k1));
    expect(k1, isNot(contains('orchard')));
  });

  test('pictures and PDFs in the user\'s message as xAI takes them: JPEG and PNG as they are, WebP and GIF turned into JPEG and PNG of the same size, PDFs as raw base64', () async {
    final webp = File('web/screenshots/design-720.webp').readAsBytesSync();
    final src = img.decodeWebP(webp)!;
    final gif = img.encodeGif(img.Image(width: 30, height: 20)..clear(img.ColorRgb8(10, 120, 200)));
    final msg = OpenAiFormat.user([
      const AiImagePart('image/jpeg', '/9j/AAAA'),
      const AiImagePart('image/png', 'iVBORw0K'),
      AiImagePart('image/webp', base64Encode(webp)),
      AiImagePart('image/gif', base64Encode(gif)),
      const AiPdfPart('sheet.pdf', 'JVBERi0'),
      const AiTextPart('Read these.'),
    ]);
    final stored = jsonEncode(msg);
    final f = _FakeXai([_answer(text: 'One.'), _answer(text: 'Two.')]);
    final r = await api(f).send(req(AiModel.grok47, [msg]), cancel: AiCancel());
    final parts = (f.input(0).single['content'] as List).cast<Map<String, dynamic>>();
    expect(parts[0], {'type': 'input_image', 'image_url': 'data:image/jpeg;base64,/9j/AAAA', 'detail': 'high'});
    expect(parts[1], {'type': 'input_image', 'image_url': 'data:image/png;base64,iVBORw0K', 'detail': 'high'});
    // an opaque WebP (the decoder gives it an alpha channel all the same) as a JPEG
    final asJpeg = OpenAiFormat.fromDataUrl(parts[2]['image_url'] as String)!;
    expect(asJpeg.$1, 'image/jpeg');
    final back = img.decodeJpg(base64Decode(asJpeg.$2))!;
    expect([back.width, back.height], [src.width, src.height], reason: 'positions on the picture hold');
    // a WebP with transparent pixels (the logo) as a PNG
    final logo = File('web/brand/logo-horizontal-520.webp').readAsBytesSync();
    final asLogo = OpenAiFormat.fromDataUrl(XaiClient.acceptedImageUrl(OpenAiFormat.dataUrl('image/webp', base64Encode(logo))))!;
    expect(asLogo.$1, 'image/png');
    expect(img.decodePng(base64Decode(asLogo.$2))!.width, 520);
    final asPng = OpenAiFormat.fromDataUrl(parts[3]['image_url'] as String)!;
    expect(asPng.$1, 'image/png');
    expect(img.decodePng(base64Decode(asPng.$2))!.width, 30);
    expect(parts[4], {'type': 'input_file', 'filename': 'sheet.pdf', 'file_data': 'JVBERi0', 'mime_type': 'application/pdf'});
    expect(parts[5], {'type': 'input_text', 'text': 'Read these.'});
    expect(r.images, 4);
    expect(r.documents, 1);
    expect(jsonEncode(msg), stored, reason: 'the conversation kept by the app is not changed');
    // the next request sends the same converted bytes: the cached prefix holds
    await api(f).send(req(AiModel.grok47, [msg, ...r.items, user('more')]), cancel: AiCancel());
    expect(jsonEncode(f.input(1).first), jsonEncode(f.input(0).first));
    // a picture that cannot be decoded goes as it came
    expect(XaiClient.acceptedImageUrl('data:image/webp;base64,AAAA'), 'data:image/webp;base64,AAAA');
    expect(XaiClient.acceptedImageUrl('https://example.org/a.webp'), 'https://example.org/a.webp');
  });

  test('every effort on each Grok model goes in xAI\'s words', () async {
    const documented = {
      'grok-4.7': {'low', 'medium', 'high', 'xhigh'},
      'grok-4.3': {'none', 'low', 'medium', 'high', 'xhigh'},
    };
    for (final m in [AiModel.grok47, AiModel.grok43]) {
      for (final e in AiEffort.values) {
        final f = _FakeXai([_answer(text: 'ok')]);
        await api(f).send(req(m, [user('q')], effort: e), cancel: AiCancel());
        final sent = (f.bodies.single['reasoning'] as Map)['effort'];
        final x = m.effortFor(e);
        expect(sent, x == AiEffort.max ? 'xhigh' : x.name, reason: '${m.id} ${e.name}');
        expect(documented[m.id], contains(sent), reason: '${m.id} ${e.name}');
      }
    }
    final c = XaiClient(apiKey: key, transport: _FakeXai(const []).call);
    expect([for (final e in AiEffort.values) c.effortOf(AiModel.grok47, e)], ['low', 'medium', 'high', 'xhigh', 'xhigh']);
    const any = AiModel(AiProvider.xai, 'grok-next', 'Grok next', AiTier.top, input: 2, output: 6, cacheRead: 0.5, cacheWrite: 2);
    expect(c.effortOf(any, AiEffort.max), 'xhigh', reason: 'xAI has no "max"');
  });

  test('the stream as xAI sends it: text deltas shown, reasoning summaries not, tool calls announced, [DONE] at the end; a whole JSON answer works too', () async {
    final shown = <String>[], started = <String>[];
    var alive = 0;
    final f = _FakeXai([
      _answer(
        text: 'Two laterals.',
        calls: [
          ('look', {'x': 3}),
        ],
      ),
    ]);
    final r = await api(f).send(
      req(AiModel.grok43, [user('q')], tools: [tool('look').spec]),
      cancel: AiCancel(),
      listener: AiStreamListener(onText: shown.add, onToolStart: started.add, onActivity: () => alive++),
    );
    expect(shown.join(), 'Two laterals.');
    expect(started, ['look']);
    expect(alive, greaterThan(5));
    expect(r.stop, AiStop.tool);
    expect(r.calls.single.input, {'x': 3});
    expect(r.calls.single.id, 'call_0_0');

    // a whole response (no stream), as the reference's example shows it
    final whole = _FakeXai([
      (_, _) => _json(200, {
        'id': 'ad5663da',
        'object': 'response',
        'model': 'grok-4.3',
        'status': 'completed',
        'store': false,
        'output': [
          {
            'id': 'msg_ad5663da',
            'type': 'message',
            'role': 'assistant',
            'status': 'completed',
            'content': [
              {'type': 'output_text', 'text': '101 multiplied by 3 is 303.', 'logprobs': null, 'annotations': <Object?>[]},
            ],
          },
          {
            'id': '',
            'type': 'reasoning',
            'status': 'completed',
            'summary': [
              {'type': 'summary_text', 'text': 'Simple multiplication.'},
            ],
          },
        ],
        'usage': {
          'input_tokens': 32,
          'input_tokens_details': {'cached_tokens': 8},
          'output_tokens': 9,
          'output_tokens_details': {'reasoning_tokens': 110},
          'total_tokens': 151,
        },
      }),
    ]);
    final w = await api(whole).send(req(AiModel.grok43, [user('101*3?')]), cancel: AiCancel());
    expect(w.text, '101 multiplied by 3 is 303.');
    expect(w.stop, AiStop.end);
    expect(w.usage.output, 119);
    expect(w.items.length, 2);
  });

  test('a server-side search item (attachment search on a PDF) is kept and sent back, never run as one of the app\'s tools', () async {
    final search = {'id': 'ctc_1', 'type': 'custom_tool_call', 'call_id': 'as_1', 'name': 'attachment_search', 'input': '{"query":"flow"}', 'status': 'completed'};
    final f = _FakeXai([
      _answer(text: 'The sheet says 2 L/h.', extra: [search]),
    ]);
    final r = await api(f).send(req(AiModel.grok47, [user('q')]), cancel: AiCancel());
    expect(r.calls, isEmpty);
    expect(r.stop, AiStop.end);
    expect(r.items.last, search);
  });

  test('ends of an answer: the output limit, a content filter, a refusal, a prompt too long, a stream cut short', () async {
    final long = _FakeXai([_answer(text: 'A long answer', status: 'incomplete', reason: 'max_output_tokens')]);
    final t = await AgentLoop(api: api(long), tools: const []).run(model: AiModel.grok47, system: 's', history: const [], user: user('q'), cancel: AiCancel());
    expect(t.stop, AgentStop.maxTokens);
    expect(t.text, 'A long answer');

    final filtered = await api(_FakeXai([_answer(status: 'incomplete', reason: 'content_filter')])).send(req(AiModel.grok47, [user('q')]), cancel: AiCancel());
    expect(filtered.stop, AiStop.refusal);
    expect(filtered.category, 'content_filter');

    final refused = await api(_FakeXai([_answer(refusal: 'I cannot help with that.')])).send(req(AiModel.grok47, [user('q')]), cancel: AiCancel());
    expect(refused.stop, AiStop.refusal);
    expect(refused.explanation, 'I cannot help with that.');
    expect(refused.items, isEmpty);

    final (full, f1) = await failure([_answer(status: 'incomplete', reason: 'max_prompt_tokens')]);
    expect(full.kind, AiErrorKind.contextWindow);
    expect(full.refusedContent, isTrue, reason: 'what was added leaves the conversation again');
    expect(f1.calls, 1);

    final (cut, f2) = await failure([_answer(text: 'Half an ans', cut: true)]);
    expect(cut.kind, AiErrorKind.interrupted);
    expect(cut.partial, isTrue);
    expect(f2.calls, 1, reason: 'part of the answer was shown: not sent again');
  });

  test('tokens: cached input apart, reasoning counted as output, the price from the table and its step at 200K prompt tokens', () {
    final c = XaiClient(apiKey: key, transport: _FakeXai(const []).call);
    // the reference's example: 32 input (8 cached), 9 output, 110 reasoning, 151 in all
    final u = c.usageOf({
      'input_tokens': 32,
      'input_tokens_details': {'cached_tokens': 8},
      'output_tokens': 9,
      'output_tokens_details': {'reasoning_tokens': 110},
      'total_tokens': 151,
    });
    expect([u.input, u.cacheRead, u.cacheWrite, u.output], [24, 8, 0, 119]);
    expect(u.cost(AiModel.grok47), closeTo((24 * 2 + 8 * 0.5 + 119 * 6) / 1e6, 1e-15));
    expect(u.cost(AiModel.grok43), closeTo((24 * 1.25 + 8 * 0.2 + 119 * 2.5) / 1e6, 1e-15));
    // without a total: output plus reasoning; a compaction's output counts its reasoning already
    expect(
      c.usageOf({
        'input_tokens': 10,
        'output_tokens': 9,
        'output_tokens_details': {'reasoning_tokens': 110},
      }).output,
      119,
    );
    expect(
      c.usageOf({
        'input_tokens': 12000,
        'input_tokens_details': {'cached_tokens': 0},
        'output_tokens': 800,
        'output_tokens_details': {'reasoning_tokens': 240},
        'total_tokens': 12800,
      }).output,
      800,
    );
    // xAI writes to its cache for free: never a cache write
    expect(AiModel.grok47.cacheRead, 0.5);
    expect(AiModel.grok43.cacheRead, 0.2);
    // a prompt of 200K tokens or more pays every token at twice the price
    const big = AiUsage(input: 50000, cacheRead: 160000, output: 1000);
    expect(big.cost(AiModel.grok47), closeTo(((50000 * 2 + 160000 * 0.5) * 2 + 1000 * 6 * 2) / 1e6, 1e-12));
    expect(big.cost(AiModel.grok43), closeTo(((50000 * 1.25 + 160000 * 0.2) * 2 + 1000 * 2.5 * 2) / 1e6, 1e-12));
    const small = AiUsage(input: 40000, cacheRead: 150000, output: 1000);
    expect(small.cost(AiModel.grok47), closeTo((40000 * 2 + 150000 * 0.5 + 1000 * 6) / 1e6, 1e-12));
  });

  test('errors as xAI sends them: a key it does not know (a 400), no key, a model, credits, a spending limit, the rate limit, the context, the usage guidelines, its servers', () async {
    // the bodies seen from api.x.ai on 2026-11-10 for a made-up key and for none
    final (bad, f1) = await failure([_error(400, 'invalid-argument', 'Incorrect API key provided. You can obtain an API key from https://console.x.ai.')]);
    expect(bad.kind, AiErrorKind.auth);
    expect(bad.status, 400);
    expect(bad.message, startsWith('Incorrect API key provided.'));
    expect(bad.refusedContent, isFalse);
    expect(f1.calls, 1);
    final (none, _) = await failure([_error(401, 'unauthenticated:no-credentials', 'No credentials presented.')]);
    expect(none.kind, AiErrorKind.auth);

    // the regional-endpoints page's example
    final (model, _) = await failure([
      _error(
        404,
        'not-found',
        'The model grok-4.7 does not exist or your team abc does not have access to it. If you believe this is a mistake, please contact support and quote your team ID and the model name.',
      ),
    ]);
    expect(model.kind, AiErrorKind.notFound);

    final (broke, f2) = await failure([_error(403, 'permission-denied', "Your newly created team doesn't have any credits yet. You can purchase credits on https://console.x.ai/team/abc.")]);
    expect(broke.kind, AiErrorKind.credit);
    expect(f2.calls, 1);
    final (spent, f3) = await failure([
      _error(
        429,
        'resource-exhausted',
        'Your team abc has either used all available credits or reached its monthly spending limit. To continue making API requests, please purchase more credits or raise your spending limit.',
      ),
    ]);
    expect(spent.kind, AiErrorKind.credit, reason: 'no retry: credits to buy or a limit to raise');
    expect(f3.calls, 1);
    final (limit, _) = await failure([_error(403, 'permission-denied', 'Your team has reached its invoiced billing limit.')]);
    expect(limit.kind, AiErrorKind.spendLimit);
    final (ctx, _) = await failure([_error(400, 'invalid-argument', "This model's maximum prompt length is 500000 but the request contains 612345 tokens.")]);
    expect(ctx.kind, AiErrorKind.contextWindow);
    final (big, _) = await failure([
      (_, _) => AiHttpResponse(413, {'content-type': 'text/plain'}, Stream.value(utf8.encode('Request Entity Too Large'))),
    ]);
    expect(big.kind, AiErrorKind.tooLarge);
    final (policy, _) = await failure([_error(403, 'permission-denied', 'This request violates our usage policies.')]);
    expect(policy.kind, AiErrorKind.refusal);
    expect(policy.category, XaiClient.policyCategory);
    final (masked, _) = await failure([
      _error(403, 'permission-denied', 'The API key xai-ab**cd was disabled.', headers: {'x-request-id': 'req_9'}),
    ]);
    expect(masked.kind, AiErrorKind.permission);
    expect(masked.message, isNot(contains('xai-ab')));
    expect(masked.message, contains('[key]'));
    expect(masked.requestId, 'req_9');
    final (old, _) = await failure([_error(400, 'Client specified an invalid argument', 'Argument not supported: logit_bias')]);
    expect(old.kind, AiErrorKind.invalidRequest);

    // the rate limit, a busy service and a failure inside the stream are tried again
    final busy = _FakeXai([
      _error(429, 'resource-exhausted', 'Too many requests', headers: {'retry-after': '1'}),
      _error(503, 'unavailable', 'Service temporarily unavailable'),
      (_, n) => _sse([
        {
          'type': 'response.created',
          'response': {'id': 'resp_$n', 'status': 'in_progress', 'model': 'grok-4.7'},
        },
        {
          'type': 'response.failed',
          'response': {
            'id': 'resp_$n',
            'status': 'failed',
            'model': 'grok-4.7',
            'error': {'code': 'internal', 'message': 'Internal error'},
          },
        },
      ]),
      _answer(text: 'fine'),
    ]);
    final c = XaiClient(apiKey: key, transport: busy.call, sleep: (d) async => waits.add(d), maxRetries: 3);
    final r = await c.send(req(AiModel.grok47, [user('q')]), cancel: AiCancel());
    expect(r.text, 'fine');
    expect(busy.calls, 4);
    expect(waits.first, const Duration(seconds: 1), reason: 'retry-after honoured');
    expect(waits.length, 3);

    // an error event, flat (as OpenAI's) or nested (as xAI's WebSocket mode)
    final (flat, _) = await failure([
      (_, _) => _sse([
        {'type': 'error', 'code': 'invalid-argument', 'message': 'Image format not supported'},
      ]),
    ]);
    expect(flat.kind, AiErrorKind.invalidRequest);
    expect(flat.message, 'Image format not supported');
    final (nested, f4) = await failure([
      for (var k = 0; k < 3; k++)
        (_, _) => _sse([
          {
            'type': 'error',
            'status': 500,
            'error': {'code': 'internal', 'message': 'Internal error'},
          },
        ]),
    ]);
    expect(nested.kind, AiErrorKind.server);
    expect(f4.calls, 3, reason: 'a server failure is tried again');
  });

  test('an optional field the API turns down is left out from then on', () async {
    final f = _FakeXai([_error(400, 'invalid-argument', 'Argument not supported: prompt_cache_key'), _answer(text: 'ok')]);
    final r = await api(f).send(req(AiModel.grok43, [user('q')]), cancel: AiCancel());
    expect(r.text, 'ok');
    expect(f.bodies[0].containsKey('prompt_cache_key'), isTrue);
    expect(f.bodies[1].containsKey('prompt_cache_key'), isFalse);
    expect(f.bodies[1]['temperature'], 0.7);
  });

  test('compaction: xAI folds the conversation into one item, and the next request starts at it', () async {
    final f = _FakeXai([
      (body, _) => _json(200, {
        'id': 'cmp_01',
        'object': 'response.compaction',
        'model': 'grok-4.7',
        'output': [
          {'type': 'compaction', 'id': 'cmp_01', 'encrypted_content': 'blob=='},
        ],
        'usage': {
          'input_tokens': 12000,
          'input_tokens_details': {'cached_tokens': 0},
          'output_tokens': 800,
          'output_tokens_details': {'reasoning_tokens': 240},
          'total_tokens': 12800,
          'dropped_message_count': 45,
        },
      }),
      _answer(text: 'Yes, 25 mm.'),
    ]);
    final c = api(f);
    final history = [user('earlier'), ...OpenAiFormat.assistant('earlier answer', const [])];
    final (items, usage) = await c.compact(AiModel.grok47, history, cancel: AiCancel());
    expect(f.requests.first.url.toString(), 'https://api.x.ai/v1/responses/compact');
    expect(f.requests.first.headers['authorization'], 'Bearer $key');
    expect(f.bodies.first, {'model': 'grok-4.7', 'input': history});
    expect(items, [
      {'type': 'compaction', 'id': 'cmp_01', 'encrypted_content': 'blob=='},
    ]);
    expect([usage.input, usage.output], [12000, 800]);
    await c.send(req(AiModel.grok47, [...history, ...items, user('go on')]), cancel: AiCancel());
    expect(f.input(1), [...items, user('go on')]);

    final failed = _FakeXai([_error(400, 'invalid-argument', 'Incorrect API key provided.')]);
    await expectLater(api(failed).compact(AiModel.grok47, history, cancel: AiCancel()), throwsA(isA<AiError>().having((e) => e.kind, 'kind', AiErrorKind.auth)));
  });

  test('OpenAI\'s own client is unchanged: no xAI fields, its PDFs and pictures as they were, its usage and errors as before', () {
    final c = OpenAiClient(apiKey: 'sk-test', transport: _FakeXai(const []).call);
    final msg = OpenAiFormat.user([const AiImagePart('image/webp', 'UklGRg'), const AiPdfPart('sheet.pdf', 'JVBERi0')]);
    final b = c.body(AiRequest(model: AiModel.gpt6Astra, system: 's', history: [msg], effort: AiEffort.max, compactAt: 200000));
    expect(b.keys.toSet(), {'model', 'instructions', 'input', 'reasoning', 'max_output_tokens', 'stream', 'store', 'include', 'context_management'});
    expect(b['reasoning'], {'effort': 'max'});
    expect(b['input'], [msg]);
    expect(c.url, OpenAiClient.endpoint);
    final u = c.usageOf({
      'input_tokens': 32,
      'input_tokens_details': {'cached_tokens': 8},
      'output_tokens': 9,
      'output_tokens_details': {'reasoning_tokens': 110},
      'total_tokens': 151,
    });
    expect([u.input, u.cacheRead, u.output], [24, 8, 9]);
    expect(c.errorKind(400, '', 'invalid-argument', 'Incorrect API key provided.'), AiErrorKind.invalidRequest);
    expect(c.compacts(AiRequest(model: AiModel.gpt6Astra, system: 's', history: [msg], compactAt: 200000)), isTrue);
  });
}
