import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/ai/llm_formats.dart';
import 'package:opencadirrigation/core/ai/meta_api.dart';
import 'package:opencadirrigation/core/ai/openai_api.dart';

// Meta's Model API (Responses format) under the same agent loop, against
// scripted transcripts that copy the wire shapes of Meta's documentation
// (dev.meta.ai/docs, 2026-11-10: protocols/responses, the Responses API
// reference, reasoning, tool-calling, media-understanding, prompt-caching,
// error-handling, pricing-rate-limits): the request, nothing stored, the
// encrypted reasoning replayed unchanged across tool calls, pictures in
// user messages and in tool outputs, each effort on each model, the stream
// (keepalives, content parts, the commentary phase, [DONE]), usage with
// cached tokens and Muse Ember's long-prompt price, each documented error,
// and OpenAI's own client unchanged.

const _key = 'LLM_1607358788850350_test-secret-0000';

int _seq = 0;

Map<String, dynamic> _reasoning(String id, [String? enc]) => {'id': id, 'type': 'reasoning', 'summary': <Object?>[], 'encrypted_content': ?enc};

Map<String, dynamic> _msg(String id, String text, {String? phase}) => {
  'id': id,
  'type': 'message',
  'role': 'assistant',
  'status': 'completed',
  'phase': ?phase,
  'content': [
    {'type': 'output_text', 'text': text, 'annotations': <Object?>[]},
  ],
};

Map<String, dynamic> _call(String id, String callId, String name, Map<String, dynamic> args) => {
  'id': id,
  'type': 'function_call',
  'call_id': callId,
  'name': name,
  'arguments': jsonEncode(args),
  'status': 'completed',
};

Map<String, dynamic> _usage({int input = 1500, int cached = 0, int output = 60, int reasoning = 20}) => {
  'input_tokens': input,
  'input_tokens_details': {'cached_tokens': cached},
  'output_tokens': output,
  'output_tokens_details': {'reasoning_tokens': reasoning},
  'total_tokens': input + output,
};

/// The response object of a stream's lifecycle events.
Map<String, dynamic> _response(String model, String status, {List<Map<String, dynamic>> output = const [], Map<String, dynamic>? usage, String? reason, Map<String, dynamic>? error}) => {
  'id': 'resp_${_seq++}',
  'object': 'response',
  'created_at': 1762750000,
  'status': status,
  'model': model,
  'store': false,
  'tools': <Object?>[],
  'tool_choice': 'auto',
  'parallel_tool_calls': true,
  'output': output,
  'usage': ?usage,
  'incomplete_details': reason == null ? null : {'reason': reason},
  'error': error,
};

/// Server-sent events as Meta sends them (an `event:` and a `data:` line
/// each, then `data: [DONE]`), in pieces that cut lines apart.
AiHttpResponse _sse(List<Map<String, dynamic>> events, {Map<String, String> headers = const {}}) {
  final text = StringBuffer();
  var n = 0;
  for (final e in events) {
    final ev = {...e, 'sequence_number': n++};
    text.write('event: ${ev['type']}\ndata: ${jsonEncode(ev)}\n\n');
  }
  text.write('data: [DONE]\n\n');
  final bytes = utf8.encode(text.toString());
  final chunks = <List<int>>[for (var k = 0; k < bytes.length; k += 97) bytes.sublist(k, k + 97 > bytes.length ? bytes.length : k + 97)];
  return AiHttpResponse(200, {'content-type': 'text/event-stream; charset=utf-8', 'x-request-id': 'req_meta', ...headers}, Stream.fromIterable(chunks));
}

/// A streamed answer with [output] in the order Meta documents: created,
/// in progress, a keepalive, each item added → its parts and deltas → done,
/// then the terminal event with the whole output and the usage.
AiHttpResponse _answer(
  List<Map<String, dynamic>> output, {
  String model = 'muse-wonder-1.0',
  String status = 'completed',
  String? reason,
  Map<String, dynamic>? usage,
  Map<String, String> headers = const {},
}) {
  final events = <Map<String, dynamic>>[
    {'type': 'response.created', 'response': _response(model, 'in_progress')},
    {'type': 'response.in_progress', 'response': _response(model, 'in_progress')},
    {'type': 'keepalive'},
  ];
  for (var i = 0; i < output.length; i++) {
    final it = output[i];
    switch (it['type']) {
      case 'reasoning':
        events
          ..add({
            'type': 'response.output_item.added',
            'output_index': i,
            'item': {'id': it['id'], 'type': 'reasoning', 'summary': <Object?>[]},
          })
          ..add({'type': 'keepalive'})
          ..add({'type': 'response.output_item.done', 'output_index': i, 'item': it});
      case 'message':
        final content = (it['content'] as List).first as Map;
        final text = '${content['text'] ?? content['refusal']}';
        final refusal = content['type'] == 'refusal';
        events.add({
          'type': 'response.output_item.added',
          'output_index': i,
          'item': {...it, 'status': 'in_progress', 'content': <Object?>[]},
        });
        events.add({
          'type': 'response.content_part.added',
          'item_id': it['id'],
          'output_index': i,
          'content_index': 0,
          'part': refusal ? {'type': 'refusal', 'refusal': ''} : {'type': 'output_text', 'text': '', 'annotations': <Object?>[]},
        });
        final half = text.length ~/ 2;
        for (final d in [text.substring(0, half), text.substring(half)]) {
          events.add({
            'type': refusal ? 'response.refusal.delta' : 'response.output_text.delta',
            'item_id': it['id'],
            'output_index': i,
            'content_index': 0,
            'delta': d,
            if (!refusal) 'logprobs': <Object?>[],
          });
        }
        events
          ..add(
            refusal
                ? {'type': 'response.refusal.done', 'item_id': it['id'], 'output_index': i, 'content_index': 0, 'refusal': text}
                : {'type': 'response.output_text.done', 'item_id': it['id'], 'output_index': i, 'content_index': 0, 'text': text, 'logprobs': <Object?>[]},
          )
          ..add({'type': 'response.content_part.done', 'item_id': it['id'], 'output_index': i, 'content_index': 0, 'part': content})
          ..add({'type': 'response.output_item.done', 'output_index': i, 'item': it});
      case 'function_call':
        final args = '${it['arguments']}';
        events.add({
          'type': 'response.output_item.added',
          'output_index': i,
          'item': {...it, 'arguments': '', 'status': 'in_progress'},
        });
        final half = args.length ~/ 2;
        for (final d in [args.substring(0, half), args.substring(half)]) {
          events.add({'type': 'response.function_call_arguments.delta', 'item_id': it['id'], 'output_index': i, 'delta': d});
        }
        events
          ..add({'type': 'response.function_call_arguments.done', 'item_id': it['id'], 'output_index': i, 'name': it['name'], 'arguments': args})
          ..add({'type': 'response.output_item.done', 'output_index': i, 'item': it});
    }
  }
  events.add({'type': 'response.$status', 'response': _response(model, status, output: output, usage: usage ?? _usage(), reason: reason)});
  return _sse(events, headers: headers);
}

/// A stream that fails: `response.failed` carrying the response with its
/// error object, or an `error` event.
AiHttpResponse _failed(String code, String message) => _sse([
  {'type': 'response.created', 'response': _response('muse-spark-1.3', 'in_progress')},
  {
    'type': 'response.failed',
    'response': _response('muse-spark-1.3', 'failed', error: {'code': code, 'message': message}),
  },
]);

AiHttpResponse _errorEvent(String code, String message) => _sse([
  {'type': 'response.created', 'response': _response('muse-spark-1.3', 'in_progress')},
  {'type': 'error', 'code': code, 'message': message, 'param': null},
]);

/// An HTTP error with Meta's error object.
AiHttpResponse _error(int status, String message, {String type = 'invalid_request_error', String? code, String? param, Map<String, String> headers = const {}}) => AiHttpResponse(
  status,
  {'content-type': 'application/json', 'x-request-id': 'req_meta_err', ...headers},
  Stream.value(
    utf8.encode(
      jsonEncode({
        'error': {'message': message, 'type': type, 'param': param, 'code': code},
      }),
    ),
  ),
);

/// A scripted Meta model: answers the requests in order and records them.
class _FakeMeta {
  _FakeMeta(this.script);
  final List<AiHttpResponse Function(Map<String, dynamic> body)> script;
  final requests = <AiHttpRequest>[];
  final bodies = <Map<String, dynamic>>[];

  int get calls => requests.length;

  List<Map<String, dynamic>> input(int n) => [for (final x in bodies[n]['input'] as List) Map<String, dynamic>.from(x as Map)];

  Future<AiHttpResponse> call(AiHttpRequest r, AiCancel cancel) async {
    requests.add(r);
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    bodies.add(body);
    final n = requests.length - 1;
    return n < script.length ? script[n](body) : _answer([_msg('msg_end', '(end of script)')]);
  }
}

void main() {
  MetaClient api(_FakeMeta f, {List<Duration>? waits}) => MetaClient(apiKey: _key, transport: f.call, sleep: (d) async => waits?.add(d));

  final ran = <String>[];
  AgentTool tool(String name, {ToolOutput Function(Map<String, dynamic>)? out}) => FnTool(
    name: name,
    description: 'test tool $name',
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

  setUp(() {
    ran.clear();
    AiHttpClient.declined.clear();
    MetaClient.outputCeilings.clear();
  });
  tearDown(() => AiModel.unregister());

  test('the request: Meta\'s endpoint, the key only as a bearer token, function tools, the effort, nothing stored, the encrypted reasoning asked for, no field Meta lacks', () async {
    final f = _FakeMeta([
      (_) => _answer([_reasoning('rs_1', 'enc_1'), _msg('msg_1', 'Hello')]),
    ]);
    final r = await api(f).send(
      AiRequest(model: AiModel.museWonder, system: 'sys', history: [user('hi')], tools: [tool('a').spec], effort: AiEffort.high, compactAt: 200000),
      cancel: AiCancel(),
    );
    expect(r.text, 'Hello');
    expect(r.stop, AiStop.end);
    expect(r.model, 'muse-wonder-1.0');
    final req = f.requests.single;
    expect(req.url.toString(), 'https://api.meta.ai/v1/responses');
    expect(req.url.host, AiProvider.meta.host);
    expect(req.headers, {'content-type': 'application/json', 'authorization': 'Bearer $_key'}, reason: 'two headers, both allowed by the preflight of api.meta.ai');
    expect(req.body.contains(_key), isFalse);
    final b = f.bodies.single;
    expect(b['model'], 'muse-wonder-1.0');
    expect(b['instructions'], 'sys');
    expect(b['input'], [user('hi')]);
    expect(b['tools'], [
      {'type': 'function', 'name': 'a', 'description': 'test tool a', 'parameters': tool('a').inputSchema, 'strict': false},
    ]);
    expect(b['reasoning'], {'effort': 'high'});
    expect(b['max_output_tokens'], AiModel.museWonder.maxOutput);
    expect(b['stream'], isTrue);
    expect(b['store'], isFalse, reason: 'stateless: Meta keeps no copy of the conversation');
    expect(b['include'], ['reasoning.encrypted_content']);
    expect(b['prompt_cache_key'], MetaClient.cacheKey);
    expect(b.keys.toSet(), {'model', 'instructions', 'input', 'tools', 'reasoning', 'max_output_tokens', 'stream', 'store', 'include', 'prompt_cache_key'});
    for (final absent in ['previous_response_id', 'context_management', 'truncation', 'background', 'reasoning_effort', 'conversation', 'prompt_cache_retention', 'safety_identifier']) {
      expect(b.containsKey(absent), isFalse, reason: absent);
    }
    expect((b['tools'] as List).every((t) => (t as Map)['type'] == 'function'), isTrue, reason: 'no web_search (billed per query) nor tool_search');
    // the reasoning item with its encrypted content is kept for the next request
    expect(r.items, [_reasoning('rs_1', 'enc_1'), _msg('msg_1', 'Hello')]);
    expect(OpenAiFormat.text(r.items), r.text);
  });

  test('a task with tools: the encrypted reasoning, the commentary and both calls go back unchanged, each output answers its call, a picture inside one', () async {
    final first = [
      _reasoning('rs_a', 'gAAAAenc-A=='),
      _msg('msg_a', 'Let me look.', phase: 'commentary'),
      _call('fc_1', 'call_1', 'look', {'x': 1}),
      _call('fc_2', 'call_2', 'snap', {}),
    ];
    final f = _FakeMeta([
      (_) => _answer(first, model: 'muse-spark-1.3', usage: _usage(input: 2000, cached: 0)),
      (_) => _answer([_reasoning('rs_b', 'gAAAAenc-B=='), _msg('msg_b', 'Seen it.')], model: 'muse-spark-1.3', usage: _usage(input: 4000, cached: 1900)),
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
          model: AiModel.museSpark,
          system: 's',
          history: const [],
          user: user('go'),
          cancel: AiCancel(),
          events: AgentEvents(onText: texts.add),
        );
    expect(turn.stop, AgentStop.done);
    expect(ran, ['look', 'snap']);
    expect(turn.text, 'Let me look.\n\nSeen it.');
    expect(texts.join(), turn.text);
    expect(f.calls, 2);
    expect(turn.messages.map((m) => m['type']), ['message', 'reasoning', 'message', 'function_call', 'function_call', 'function_call_output', 'function_call_output', 'reasoning', 'message']);
    final second = f.input(1);
    // the whole conversation again, the first request's input first
    expect(jsonEncode(second.sublist(0, 1)), jsonEncode(f.input(0)));
    // the model's items byte for byte as Meta sent them
    expect(jsonEncode(second.sublist(1, 5)), jsonEncode(first));
    expect(second[1]['encrypted_content'], 'gAAAAenc-A==');
    expect(second[2]['phase'], 'commentary');
    final calls = second.where((i) => i['type'] == 'function_call').toList();
    final outs = second.where((i) => i['type'] == 'function_call_output').toList();
    expect(outs.map((o) => o['call_id']), calls.map((c) => c['call_id']), reason: 'every call answered, in order');
    expect(outs.first['output'], 'look ok {"x":1}');
    expect(outs.last['output'], [
      {'type': 'input_text', 'text': 'a view'},
      {'type': 'input_image', 'image_url': 'data:image/png;base64,iVBORw0K', 'detail': 'high'},
    ], reason: 'a function output carries the picture, as Meta\'s own computer-use agent sends its screenshots');
    for (final b in f.bodies) {
      expect(b['store'], isFalse);
      expect(b.containsKey('previous_response_id'), isFalse);
      expect(b['instructions'], 's');
    }
    expect(turn.usage.cacheRead, 1900);
    expect(turn.cost, closeTo(((2000 + 2100) * 1.25 + 1900 * 0.15 + 120 * 4.25) / 1e6, 1e-12));
  });

  test('what Meta rejects in a replay is left out of the items: reasoning without its encrypted content or with nothing after it; text before a call goes as commentary', () async {
    final f = _FakeMeta([
      (_) => _answer([
        _reasoning('rs_bare'),
        _msg('msg_c', 'Checking the pipes.'),
        _reasoning('rs_ok', 'enc_ok'),
        _call('fc_3', 'call_3', 'look', {'x': 2}),
        _reasoning('rs_last', 'enc_last'),
      ]),
      (_) => _answer([_reasoning('rs_d', 'enc_d'), _msg('msg_d', 'Done.')]),
    ]);
    final r = await api(f).send(
      AiRequest(model: AiModel.museEmber, system: 's', history: [user('q')], tools: [tool('look').spec]),
      cancel: AiCancel(),
    );
    expect(r.stop, AiStop.tool);
    expect(r.calls.single.input, {'x': 2});
    expect(r.items, [
      {..._msg('msg_c', 'Checking the pipes.'), 'phase': 'commentary'},
      _reasoning('rs_ok', 'enc_ok'),
      _call('fc_3', 'call_3', 'look', {'x': 2}),
    ]);
    expect(OpenAiFormat.text(r.items), r.text);
    expect(OpenAiFormat.calls(r.items).single.id, r.calls.single.id);
    // a final answer keeps no phase and loses nothing
    final done = await api(f).send(
      AiRequest(model: AiModel.museEmber, system: 's', history: [user('q')]),
      cancel: AiCancel(),
    );
    expect(done.items, [_reasoning('rs_d', 'enc_d'), _msg('msg_d', 'Done.')]);
    // OpenAI's own client leaves its items as they come
    final raw = [_msg('m', 'text'), _call('f', 'c', 'look', {})];
    expect(OpenAiClient(apiKey: 'k', transport: f.call).itemsOf(raw), same(raw));
  });

  test('the user\'s pictures and PDFs, and the pictures of tool outputs, in the shapes Meta documents', () async {
    final client = api(_FakeMeta(const []));
    final msg = client.userMessage([const AiImagePart('image/jpeg', 'AAAA'), const AiPdfPart('sheet.pdf', 'JVBERi0'), const AiTextPart('Read these.')]);
    expect(msg, {
      'type': 'message',
      'role': 'user',
      'content': [
        {'type': 'input_image', 'image_url': 'data:image/jpeg;base64,AAAA', 'detail': 'high'},
        {'type': 'input_file', 'filename': 'sheet.pdf', 'file_data': 'data:application/pdf;base64,JVBERi0'},
        {'type': 'input_text', 'text': 'Read these.'},
      ],
    });
    final results = client.toolResults([
      const AiToolResult('call_9', ToolOutput('map', images: [ToolImage('image/jpeg', 'BBBB')])),
      AiToolResult('call_10', ToolOutput.error('no such pipe')),
    ]);
    expect(results, [
      {
        'type': 'function_call_output',
        'call_id': 'call_9',
        'output': [
          {'type': 'input_text', 'text': 'map'},
          {'type': 'input_image', 'image_url': 'data:image/jpeg;base64,BBBB', 'detail': 'high'},
        ],
      },
      {'type': 'function_call_output', 'call_id': 'call_10', 'output': 'Error: no such pipe'},
    ]);
    final f = _FakeMeta([
      (_) => _answer([_msg('m', 'A sheet and a photo.')]),
    ]);
    final r = await api(f).send(
      AiRequest(model: AiModel.museWonder, system: 's', history: [msg]),
      cancel: AiCancel(),
    );
    expect(f.input(0).single, msg, reason: 'sent as it is kept');
    expect([r.images, r.documents], [1, 1]);
    expect(r.requestBytes, f.requests.single.body.length);
  });

  test('every effort of the app goes by its own name to each Muse model; an earlier model without max gets xhigh', () async {
    for (final m in [AiModel.museWonder, AiModel.museSpark, AiModel.museEmber]) {
      expect(m.efforts, AiEffort.values, reason: '${m.id}: Meta takes minimal to max');
      for (final e in AiEffort.values) {
        final f = _FakeMeta([
          (_) => _answer([_msg('m', 'ok')], model: m.id),
        ]);
        await api(f).send(
          AiRequest(model: m, system: 's', history: [user('q')], effort: e),
          cancel: AiCancel(),
        );
        expect(f.bodies.single['reasoning'], {'effort': e.name}, reason: '${m.id} ${e.name}');
        expect(f.bodies.single.containsKey('reasoning_effort'), isFalse, reason: 'the Chat Completions spelling');
      }
    }
    // Muse Spark 1.2 and 1.1 lack "max" (dev.meta.ai/docs/choose-a-model)
    const spark12 = AiModel(
      AiProvider.meta,
      'muse-spark-1.2',
      'Muse Spark 1.2',
      AiTier.intermediate,
      input: 1.25,
      output: 4.25,
      cacheRead: 0.15,
      cacheWrite: 1.25,
      compaction: false,
      efforts: [AiEffort.low, AiEffort.medium, AiEffort.high, AiEffort.xhigh],
    );
    AiModel.register(spark12);
    final f = _FakeMeta([
      (_) => _answer([_msg('m', 'ok')], model: spark12.id),
    ]);
    await api(f).send(
      AiRequest(model: spark12, system: 's', history: [user('q')], effort: AiEffort.max),
      cancel: AiCancel(),
    );
    expect(f.bodies.single['reasoning'], {'effort': 'xhigh'});
  });

  test('the stream as Meta sends it: keepalives, content parts, the arguments in pieces, [DONE]; a whole JSON answer too', () async {
    final f = _FakeMeta([
      (_) => _answer([
        _reasoning('rs_s', 'enc_s'),
        _msg('msg_s', 'Sizing the laterals.', phase: 'commentary'),
        _call('fc_s', 'call_s', 'size_laterals', {'zone': 2}),
      ]),
    ]);
    final pieces = <String>[], tools = <String>[];
    var activity = 0;
    final r = await api(f).send(
      AiRequest(model: AiModel.museSpark, system: 's', history: [user('q')]),
      cancel: AiCancel(),
      listener: AiStreamListener(onText: pieces.add, onToolStart: tools.add, onActivity: () => activity++),
    );
    expect(pieces, ['Sizing the', ' laterals.'], reason: 'text as it arrives');
    expect(tools, ['size_laterals']);
    expect(activity, greaterThanOrEqualTo(15), reason: 'every event, the keepalives too, keeps the request alive');
    expect(r.calls.single.name, 'size_laterals');
    expect(r.calls.single.input, {'zone': 2});
    expect(r.stop, AiStop.tool);

    // arguments that are not JSON are reported, never thrown
    final bad = _FakeMeta([
      (_) => _answer([
        {..._call('fc_x', 'call_x', 'look', {}), 'arguments': '{"x": 1'},
      ]),
    ]);
    final rb = await api(bad).send(
      AiRequest(model: AiModel.museSpark, system: 's', history: [user('q')]),
      cancel: AiCancel(),
    );
    expect(rb.calls.single.invalidRaw, '{"x": 1');

    // a whole response, not streamed
    final whole = _response('muse-ember-1.0', 'completed', output: [_reasoning('rs_j', 'enc_j'), _msg('msg_j', 'Plain JSON.')], usage: _usage(input: 300, cached: 100, output: 20));
    final j = _FakeMeta([
      (_) => AiHttpResponse(200, {'content-type': 'application/json'}, Stream.value(utf8.encode(jsonEncode(whole)))),
    ]);
    final rj = await api(j).send(
      AiRequest(model: AiModel.museEmber, system: 's', history: [user('q')]),
      cancel: AiCancel(),
    );
    expect(rj.text, 'Plain JSON.');
    expect(rj.items.first['encrypted_content'], 'enc_j');
    expect([rj.usage.input, rj.usage.cacheRead, rj.usage.output], [200, 100, 20]);
  });

  test('usage: cached tokens are part of the input, reasoning part of the output, no cache writes; Muse Ember costs three times as much above 200K input tokens', () async {
    Future<AiReply> reply(AiModel m, Map<String, dynamic> usage) =>
        api(
          _FakeMeta([
            (_) => _answer([_msg('m', 'ok')], model: m.id, usage: usage),
          ]),
        ).send(
          AiRequest(model: m, system: 's', history: [user('q')]),
          cancel: AiCancel(),
        );

    final w = await reply(AiModel.museWonder, _usage(input: 12000, cached: 10000, output: 900, reasoning: 600));
    expect([w.usage.input, w.usage.cacheRead, w.usage.cacheWrite, w.usage.output], [2000, 10000, 0, 900]);
    // US$ 4 input, 0.20 cached input, 20 output per million
    expect(w.cost(AiModel.museWonder), closeTo((2000 * 4 + 10000 * 0.2 + 900 * 20) / 1e6, 1e-12));
    // no long-context premium on Muse Spark, even near the full window
    final s = await reply(AiModel.museSpark, _usage(input: 900000, cached: 800000, output: 1000));
    expect(s.cost(AiModel.museSpark), closeTo((100000 * 1.25 + 800000 * 0.15 + 1000 * 4.25) / 1e6, 1e-12));
    // Muse Ember: up to 200K input tokens (cached ones included) at 0.10 / 0.004 / 0.50 …
    final e1 = await reply(AiModel.museEmber, _usage(input: 200000, cached: 150000, output: 2000));
    expect(e1.cost(AiModel.museEmber), closeTo((50000 * 0.10 + 150000 * 0.004 + 2000 * 0.50) / 1e6, 1e-12));
    // … and above, the whole request at the long-context rates 0.30 / 0.012 / 1.50
    final e2 = await reply(AiModel.museEmber, _usage(input: 210000, cached: 150000, output: 2000));
    expect(e2.cost(AiModel.museEmber), closeTo((60000 * 0.30 + 150000 * 0.012 + 2000 * 1.50) / 1e6, 1e-12));
  });

  test('errors as Meta documents them: status, type and code; the request id kept; retries only where they help', () async {
    Future<(AiError, int, List<Duration>)> failure(AiHttpResponse Function() reply) async {
      final f = _FakeMeta([for (var k = 0; k < 4; k++) (_) => reply()]);
      final waits = <Duration>[];
      try {
        await api(f, waits: waits).send(
          AiRequest(model: AiModel.museSpark, system: 's', history: [user('q')]),
          cancel: AiCancel(),
        );
      } on AiError catch (e) {
        return (e, f.calls, waits);
      }
      throw StateError('no error');
    }

    final (auth, authCalls, _) = await failure(() => _error(401, 'Unauthorized', type: 'authentication_error', code: 'invalid_api_key'));
    expect(auth.kind, AiErrorKind.auth);
    expect(auth.status, 401);
    expect(auth.requestId, 'req_meta_err');
    expect(authCalls, 1);
    final (billing, billingCalls, _) = await failure(() => _error(402, 'Billing account issue. Please check your account status.', type: 'billing_error', code: 'billing_not_configured'));
    expect(billing.kind, AiErrorKind.billing, reason: 'no balance, a lapsed payment method or billing not set up');
    expect(billingCalls, 1);
    final (forbidden, _, _) = await failure(() => _error(403, 'This API key does not have permission to use this feature.'));
    expect(forbidden.kind, AiErrorKind.permission);
    final (model, _, _) = await failure(() => _error(404, 'The model `bogus-model` does not exist or is not available', code: 'model_not_found'));
    expect(model.kind, AiErrorKind.notFound);
    final (big, _, _) = await failure(() => _error(413, 'request body too large (1300000 bytes, max 1048576)', code: 'payload_too_large'));
    expect(big.kind, AiErrorKind.tooLarge);
    final (bad, badCalls, _) = await failure(() => _error(400, '`top_p`: The number must be `<= 1.0`.', param: 'top_p'));
    expect(bad.kind, AiErrorKind.invalidRequest);
    expect(bad.message, '`top_p`: The number must be `<= 1.0`.');
    expect(badCalls, 1);
    final (policy, _, _) = await failure(() => _error(400, 'The image does not meet the content policy.', code: 'content_policy_violation'));
    expect(policy.kind, AiErrorKind.invalidRequest);
    expect(policy.refusedContent, isTrue, reason: 'the loop sends the round again without its pictures');
    final (busy, busyCalls, busyWaits) = await failure(
      () => _error(503, 'The backend is temporarily overloaded. Please retry.', type: 'server_error', code: 'service_overloaded', headers: {'retry-after': '60'}),
    );
    expect(busy.kind, AiErrorKind.overloaded);
    expect(busy.retryAfter, const Duration(seconds: 60));
    expect([busyCalls, busyWaits.length], [1, 0], reason: 'a wait of a minute is the error, with the wait in it');
    final (down, _, _) = await failure(() => _error(503, 'The backend is temporarily unavailable. Please retry.', type: 'server_error', code: 'backend_unavailable'));
    expect(down.kind, AiErrorKind.overloaded);
    final (late, lateCalls, _) = await failure(
      () => _error(
        504,
        'Request exceeded the non-streaming server time limit before a response was produced. For large or slow requests, use the streaming API by setting "stream": true.',
        type: 'server_error',
        code: 'gateway_timeout',
      ),
    );
    expect(late.kind, AiErrorKind.http);
    expect(late.status, 504);
    expect(lateCalls, 1, reason: 'Meta: the same request usually times out again');
    final (limited, limitedCalls, limitedWaits) = await failure(
      () => _error(429, 'Rate limit exceeded. Please retry after 15 seconds.', type: 'rate_limit_error', code: 'rate_limit_exceeded', headers: {'retry-after': '15'}),
    );
    expect(limited.kind, AiErrorKind.rateLimit);
    expect(limitedCalls, 3);
    expect(limitedWaits, [const Duration(seconds: 15), const Duration(seconds: 15)]);

    // transient failures are sent again and then answered
    final waits = <Duration>[];
    final flaky = _FakeMeta([
      (_) => _error(503, 'Server is shutting down. Please retry your request.', type: 'server_error', code: 'server_shutting_down', headers: {'retry-after': '2'}),
      (_) => _errorEvent('server_shutting_down', 'Server is shutting down. Please retry your request.'),
      (_) => _failed('server_error', 'The server had an error while processing your request.'),
      (_) => _answer([_msg('m', 'fine')]),
    ]);
    final ok = await MetaClient(apiKey: _key, transport: flaky.call, sleep: (d) async => waits.add(d), maxRetries: 3).send(
      AiRequest(model: AiModel.museSpark, system: 's', history: [user('q')]),
      cancel: AiCancel(),
    );
    expect(ok.text, 'fine');
    expect(flaky.calls, 4);
    expect(waits.first, const Duration(seconds: 2), reason: 'retry-after honoured');

    // the browser cannot read x-request-id (not exposed by CORS): no id then
    final hidden = _FakeMeta([
      (_) => AiHttpResponse(401, {
        'content-type': 'application/json',
      }, Stream.value(utf8.encode('{"error":{"code":"invalid_api_key","message":"Unauthorized","param":null,"type":"authentication_error"}}'))),
    ]);
    try {
      await api(hidden).send(
        AiRequest(model: AiModel.museSpark, system: 's', history: [user('q')]),
        cancel: AiCancel(),
      );
      fail('no error');
    } on AiError catch (e) {
      expect(e.kind, AiErrorKind.auth);
      expect(e.requestId, isNull);
    }

    // the key never shows in a message, nor a masked copy of it
    final (leak, _, _) = await failure(() => _error(401, 'Invalid key $_key (LLM_1607358788850350_nx9.....LJY)', type: 'authentication_error', code: 'invalid_api_key'));
    expect(leak.message, isNot(contains('LLM_')));
    expect(leak.message, contains('[key]'));
  });

  test('refusals: a declined prompt, a content filter, a refusal part; an answer cut by the output limit', () async {
    Future<AgentTurn> run(AiHttpResponse Function() reply) =>
        AgentLoop(api: api(_FakeMeta([(_) => reply()])), tools: const []).run(model: AiModel.museWonder, system: 's', history: const [], user: user('q'), cancel: AiCancel());

    final declined = await run(() => _failed('invalid_prompt', 'Invalid prompt: your prompt was flagged.'));
    expect(declined.error!.kind, AiErrorKind.refusal);
    expect(declined.error!.category, 'invalid_prompt');
    final media = await run(() => _errorEvent('content_policy_violation', 'The image does not meet the content policy.'));
    expect(media.error!.kind, AiErrorKind.refusal);
    expect(media.error!.category, 'content_policy_violation');
    final filtered = await run(() => _answer([_reasoning('rs_f', 'enc_f')], status: 'incomplete', reason: 'content_filter'));
    expect(filtered.error!.kind, AiErrorKind.refusal);
    expect(filtered.error!.category, 'content_filter');
    final refused = await run(
      () => _answer([
        {
          'id': 'msg_r',
          'type': 'message',
          'role': 'assistant',
          'status': 'completed',
          'content': [
            {'type': 'refusal', 'refusal': 'I cannot help with that.'},
          ],
        },
      ]),
    );
    expect(refused.error!.kind, AiErrorKind.refusal);
    expect(refused.error!.message, 'I cannot help with that.');
    expect(refused.messages, isEmpty, reason: 'a declined answer is not kept');
    final long = await run(() => _answer([_reasoning('rs_l', 'enc_l'), _msg('msg_l', 'A long answer')], status: 'incomplete', reason: 'max_output_tokens'));
    expect(long.stop, AgentStop.maxTokens);
    expect(long.text, 'A long answer');
  });

  test('a conversation near the end of the window: the answer gets the room left, or the conversation is too long', () async {
    String tooLong(int n, int m) =>
        'You passed $n input tokens and requested $m output tokens. However, the model\'s context length is only 1048576 tokens, resulting in a maximum input length of 1048575 tokens. Please reduce the length of the input prompt';
    final f = _FakeMeta([
      (b) => _error(400, tooLong(1000000, b['max_output_tokens'] as int)),
      (_) => _answer([_msg('m', 'Short answer.')]),
    ]);
    final r = await api(f).send(
      AiRequest(model: AiModel.museWonder, system: 's', history: [user('q')], maxTokens: 64000),
      cancel: AiCancel(),
    );
    expect(r.text, 'Short answer.');
    expect([for (final b in f.bodies) b['max_output_tokens']], [64000, 48576]);

    Future<(AiError, int)> failure(int n) async {
      final g = _FakeMeta([for (var k = 0; k < 4; k++) (b) => _error(400, tooLong(n, b['max_output_tokens'] as int))]);
      try {
        await api(g).send(
          AiRequest(model: AiModel.museWonder, system: 's', history: [user('q')], maxTokens: 64000),
          cancel: AiCancel(),
        );
      } on AiError catch (e) {
        return (e, g.calls);
      }
      throw StateError('no error');
    }

    final (tight, tightCalls) = await failure(1040000);
    expect(tight.kind, AiErrorKind.contextWindow, reason: 'less than ${MetaClient.minOutputRoom} tokens left for the answer');
    expect(tightCalls, 1);
    final (over, overCalls) = await failure(1200064);
    expect(over.kind, AiErrorKind.contextWindow);
    expect(overCalls, 1);
  });

  test('an output limit above what the model takes is lowered to it, and later requests ask for no more', () async {
    final f = _FakeMeta([
      (b) => (b['max_output_tokens'] as int) > 131072 ? _error(400, '`max_output_tokens`: The number must be `<= 131072`.', param: 'max_output_tokens') : _answer([_msg('m', 'ok')]),
      (_) => _answer([_msg('m', 'ok')]),
      (_) => _answer([_msg('m', 'ok')]),
      (_) => _answer([_msg('m', 'ok')]),
    ]);
    Future<void> ask(AiModel m) => api(f).send(
      AiRequest(model: m, system: 's', history: [user('q')], maxTokens: 200000),
      cancel: AiCancel(),
    );
    await ask(AiModel.museWonder);
    expect([for (final b in f.bodies) b['max_output_tokens']], [200000, 131072]);
    await ask(AiModel.museWonder);
    expect(f.bodies.last['max_output_tokens'], 131072, reason: 'learned for the model');
    await ask(AiModel.museEmber);
    expect(f.bodies.last['max_output_tokens'], 200000, reason: 'each model its own');
    expect(f.calls, 4);
    // the least the API takes
    final g = _FakeMeta([
      (_) => _answer([_msg('m', 'ok')]),
    ]);
    await api(g).send(
      AiRequest(model: AiModel.museEmber, system: 's', history: [user('q')], maxTokens: 4),
      cancel: AiCancel(),
    );
    expect(g.bodies.single['max_output_tokens'], MetaClient.minOutputTokens);
  });

  test('a reasoning item Meta no longer takes: the request goes again without the reasoning items, the stored history keeps them', () async {
    final history = [user('earlier'), _reasoning('rs_old', 'enc_old'), _msg('msg_old', 'Earlier answer.'), user('go on')];
    final f = _FakeMeta([
      (_) => _error(400, 'Referenced reasoning item rs_old was not found or has expired', param: 'input'),
      (_) => _answer([_msg('m', 'Going on.')]),
    ]);
    final r = await api(f).send(
      AiRequest(model: AiModel.museSpark, system: 's', history: history),
      cancel: AiCancel(),
    );
    expect(r.text, 'Going on.');
    expect(f.input(0).map((i) => i['type']), ['message', 'reasoning', 'message', 'message']);
    expect(f.input(1).map((i) => i['type']), ['message', 'message', 'message']);
    expect(history[1], _reasoning('rs_old', 'enc_old'), reason: 'the history itself is not changed');
    // an error that is not about reasoning items is not "recovered"
    final g = _FakeMeta([(_) => _error(400, '`reasoning.effort`: "none" is not supported for this model.', param: 'reasoning')]);
    await expectLater(
      api(g).send(
        AiRequest(model: AiModel.museSpark, system: 's', history: history),
        cancel: AiCancel(),
      ),
      throwsA(isA<AiError>().having((e) => e.kind, 'kind', AiErrorKind.invalidRequest)),
    );
    expect(g.calls, 1);
  });

  test('a connection test: the smallest request, the account\'s rate limits from the headers', () async {
    final f = _FakeMeta([
      (_) => _answer(
        [_reasoning('rs_p', 'enc_p'), _msg('m', 'OK')],
        model: 'muse-ember-1.0',
        usage: _usage(input: 40, output: 30),
        headers: {'x-ratelimit-limit-tokens': '4000000', 'x-ratelimit-remaining-tokens': '3999930', 'x-ratelimit-limit-requests': '3000', 'x-ratelimit-remaining-requests': '2999'},
      ),
    ]);
    final p = await api(f).probe(AiModel.museEmber, cancel: AiCancel());
    expect(p.ok, isTrue);
    expect(p.text, 'OK');
    expect(p.limits, {'limit-tokens': '4000000', 'remaining-tokens': '3999930', 'limit-requests': '3000', 'remaining-requests': '2999'});
    expect(p.requestId, 'req_meta');
    final b = f.bodies.single;
    expect(b['reasoning'], {'effort': 'low'});
    expect(b['max_output_tokens'], AiHttpClient.probeTokens);
    expect(b.containsKey('tools'), isFalse);
    expect(b.containsKey('context_management'), isFalse);
  });

  test('the Muse models as Meta prices and describes them', () {
    for (final m in [AiModel.museWonder, AiModel.museSpark, AiModel.museEmber]) {
      expect(m.provider, AiProvider.meta);
      expect(m.compaction, isFalse, reason: '${m.id}: Meta has no server-side compaction');
      expect(m.vision, isTrue);
      expect(m.tools, isTrue);
      expect(m.freeTier, isFalse);
      expect(m.id.contains('contributor'), isFalse, reason: 'Contributor variants let Meta train on the content');
    }
    expect([AiModel.museWonder.id, AiModel.museSpark.id, AiModel.museEmber.id], ['muse-wonder-1.0', 'muse-spark-1.3', 'muse-ember-1.0']);
    expect([AiModel.museWonder.tier, AiModel.museSpark.tier, AiModel.museEmber.tier], [AiTier.top, AiTier.intermediate, AiTier.fast]);
    expect([AiModel.museWonder.input, AiModel.museWonder.cacheRead, AiModel.museWonder.output], [4, 0.2, 20]);
    expect([AiModel.museSpark.input, AiModel.museSpark.cacheRead, AiModel.museSpark.output], [1.25, 0.15, 4.25]);
    expect([AiModel.museEmber.input, AiModel.museEmber.cacheRead, AiModel.museEmber.output], [0.1, 0.004, 0.5]);
    expect([AiModel.museEmber.longAbove, AiModel.museEmber.longInput, AiModel.museEmber.longOutput], [200000, 3, 3]);
    expect([AiModel.museWonder.longAbove, AiModel.museSpark.longAbove], [0, 0], reason: 'the same rate at any context length');
    expect(AiModel.offered(AiProvider.meta).any((m) => m.id.contains('contributor')), isFalse);
  });

  test('OpenAI\'s own client is unchanged by Meta\'s', () async {
    // a lower output limit learned for a Meta model stays with Meta
    MetaClient.outputCeilings[AiModel.gpt6Astra.id] = 1000;
    final f = _FakeMeta([
      (_) => _answer([_msg('m', 'ok')], model: 'gpt-6-astra'),
    ]);
    await OpenAiClient(apiKey: 'sk-proj-test', transport: f.call).send(
      AiRequest(model: AiModel.gpt6Astra, system: 's', history: [user('q')], compactAt: 200000),
      cancel: AiCancel(),
    );
    final b = f.bodies.single;
    expect(f.requests.single.url.host, 'api.openai.com');
    expect(b['max_output_tokens'], AiModel.gpt6Astra.maxOutput);
    expect(b['context_management'], [
      {'type': 'compaction', 'compact_threshold': 200000},
    ]);
    expect(b.containsKey('prompt_cache_key'), isFalse);
    final o = OpenAiClient(apiKey: 'k', transport: f.call);
    expect(o.errorKind(402, '', '', ''), AiErrorKind.credit);
    expect(o.errorKind(504, '', '', ''), AiErrorKind.server);
    expect(o.errorKind(null, '', 'server_shutting_down', ''), AiErrorKind.http);
    expect(o.declinedCodes.contains('content_policy_violation'), isFalse);
    expect(o.compacts(AiRequest(model: AiModel.gpt6Astra, system: 's', history: const [], compactAt: 200000)), isTrue);
    expect(o.clean('see LLM_1607358788850350_abc'), 'see LLM_1607358788850350_abc', reason: 'only the Meta client knows Meta\'s key format');
    final m = api(f);
    expect(m.errorKind(402, 'billing_error', 'billing_not_configured', ''), AiErrorKind.billing);
    expect(m.errorKind(null, 'server_error', 'server_shutting_down', ''), AiErrorKind.overloaded);
    expect(m.compacts(AiRequest(model: AiModel.museWonder, system: 's', history: const [], compactAt: 200000)), isFalse);
  });
}
