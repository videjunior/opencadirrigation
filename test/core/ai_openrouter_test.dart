// The OpenRouter client (its Responses API) against scripted transcripts in
// the shapes OpenRouter documents (openrouter.ai/docs, read 2026-11-10:
// api_reference/responses/*, streaming, errors-and-debugging, limits,
// prompt-caching, reasoning-tokens, usage-accounting, app-attribution):
// the request it takes, a plain answer, tool loops that keep the reasoning
// of a Claude, a GPT and a Gemini model, pictures (in tool results where
// the maker reads them there, after the results elsewhere), PDFs, the
// usage with OpenRouter's cost, every error it documents, and a router
// naming the model that answered. No network.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/ai/llm_formats.dart';
import 'package:opencadirrigation/core/ai/openrouter_api.dart';

const _key = 'sk-or-v1-SECRET-test-key-0000';

/// One scripted HTTP answer.
class _Out {
  const _Out(this.status, this.text, {this.headers = const {}});
  final int status;
  final String text;
  final Map<String, String> headers;
}

/// A scripted OpenRouter: answers the requests in order and records them.
class _Server {
  _Server(this.script);
  final List<_Out Function(Map<String, dynamic> body)> script;
  final requests = <AiHttpRequest>[];
  final bodies = <Map<String, dynamic>>[];

  Future<AiHttpResponse> call(AiHttpRequest r, AiCancel cancel) async {
    requests.add(r);
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    bodies.add(body);
    final n = requests.length - 1;
    final out = n < script.length ? script[n](body) : _text('(end of script)');
    final bytes = utf8.encode(out.text);
    final chunks = [for (var k = 0; k < bytes.length; k += 97) bytes.sublist(k, k + 97 > bytes.length ? bytes.length : k + 97)];
    return AiHttpResponse(out.status, {'x-generation-id': 'gen-test-$n', ...out.headers}, Stream.fromIterable(chunks));
  }
}

const _sseHeaders = {'content-type': 'text/event-stream'};
const _jsonHeaders = {'content-type': 'application/json'};

/// A stream of events as OpenRouter sends it: a keep-alive comment first,
/// `data:` lines, `[DONE]` at the end.
_Out _sse(List<Map<String, dynamic>> events) {
  final b = StringBuffer(': OPENROUTER PROCESSING\n\n');
  var seq = 0;
  for (final e in events) {
    b.write('data: ${jsonEncode({...e, 'sequence_number': seq++})}\n\n');
  }
  b.write('data: [DONE]\n\n');
  return _Out(200, b.toString(), headers: _sseHeaders);
}

Map<String, dynamic> _usage({int input = 1200, int cached = 1000, int written = 0, int output = 50, int reasoning = 20, double cost = 0.00123}) => {
  'input_tokens': input,
  'input_tokens_details': {'cached_tokens': cached, 'cache_write_tokens': written},
  'output_tokens': output,
  'output_tokens_details': {'reasoning_tokens': reasoning},
  'total_tokens': input + output,
  'cost': cost,
  'is_byok': false,
  'cost_details': {'upstream_inference_cost': null, 'upstream_inference_input_cost': cost * 0.8, 'upstream_inference_output_cost': cost * 0.2},
};

/// A whole answer: [output] items streamed (text in two deltas), then
/// `response.completed` naming [served] (a router names the model it chose;
/// the first events name [asked]).
_Out _answer(List<Map<String, dynamic>> output, {String asked = 'openai/gpt-6.1-sol', String? served, Map<String, dynamic>? usage}) {
  final resp = {'id': 'gen-1', 'object': 'response', 'status': 'in_progress', 'model': asked, 'output': <Object?>[]};
  final events = <Map<String, dynamic>>[
    {'type': 'response.created', 'response': resp},
    {'type': 'response.in_progress', 'response': resp},
  ];
  for (final (i, it) in output.indexed) {
    switch (it['type']) {
      case 'message':
        events.add({
          'type': 'response.output_item.added',
          'output_index': i,
          'item': {...it, 'status': 'in_progress', 'content': <Object?>[]},
        });
        final text = '${((it['content'] as List).first as Map)['text']}';
        final half = text.length ~/ 2;
        for (final d in [text.substring(0, half), text.substring(half)]) {
          events.add({'type': 'response.output_text.delta', 'item_id': it['id'], 'output_index': i, 'content_index': 0, 'delta': d});
        }
      case 'function_call':
        events.add({
          'type': 'response.output_item.added',
          'output_index': i,
          'item': {...it, 'arguments': ''},
        });
        events.add({'type': 'response.function_call_arguments.delta', 'item_id': it['id'], 'output_index': i, 'delta': it['arguments']});
        events.add({'type': 'response.function_call_arguments.done', 'item_id': it['id'], 'output_index': i, 'arguments': it['arguments']});
      default:
        events.add({'type': 'response.output_item.added', 'output_index': i, 'item': it});
    }
    events.add({'type': 'response.output_item.done', 'output_index': i, 'item': it});
  }
  events.add({
    'type': 'response.completed',
    'response': {...resp, 'status': 'completed', 'model': served ?? asked, 'output': output, 'usage': usage ?? _usage()},
  });
  return _sse(events);
}

Map<String, dynamic> _msg(String text, [String id = 'msg_1']) => {
  'type': 'message',
  'id': id,
  'status': 'completed',
  'role': 'assistant',
  'content': [
    {'type': 'output_text', 'text': text, 'annotations': <Object?>[]},
  ],
};

Map<String, dynamic> _call(String name, Map<String, dynamic> args, String id) => {
  'type': 'function_call',
  'id': 'fc_$id',
  'call_id': 'call_$id',
  'name': name,
  'arguments': jsonEncode(args),
  'status': 'completed',
};

_Out _text(String text, {String model = 'openai/gpt-6.1-sol'}) => _answer([_msg(text)], asked: model);

/// An error answer before the stream.
_Out _error(int status, Map<String, dynamic> body, {Map<String, String> headers = const {}}) => _Out(status, jsonEncode(body), headers: {..._jsonHeaders, ...headers});

/// A stream that fails: [before] text first (none: the failure is the
/// first event), then `response.failed` with [error] and [type].
_Out _failed(Map<String, dynamic> error, String type, {String before = ''}) {
  final resp = {'id': 'gen-1', 'object': 'response', 'status': 'in_progress', 'model': 'openai/gpt-6.1-sol', 'output': <Object?>[]};
  return _sse([
    if (before.isNotEmpty) ...[
      {'type': 'response.created', 'response': resp},
      {
        'type': 'response.output_item.added',
        'output_index': 0,
        'item': {'type': 'message', 'id': 'msg_1', 'role': 'assistant', 'status': 'in_progress', 'content': <Object?>[]},
      },
      {'type': 'response.output_text.delta', 'item_id': 'msg_1', 'output_index': 0, 'content_index': 0, 'delta': before},
    ],
    {
      'type': 'response.failed',
      'response': {...resp, 'status': 'failed', 'output': <Object?>[], 'error': error, 'error_type': type},
    },
  ]);
}

void main() {
  final waits = <Duration>[];
  OpenRouterClient api(_Server s) => OpenRouterClient(apiKey: _key, transport: s.call, sleep: (d) async => waits.add(d));

  Map<String, dynamic> user(String s) => OpenAiFormat.user([AiTextPart(s)]);
  AiRequest req(AiModel m, {String text = 'hi', AiEffort effort = AiEffort.medium, List<Map<String, dynamic>>? history}) =>
      AiRequest(model: m, system: 'sys', history: history ?? [user(text)], effort: effort);

  final ran = <String>[];
  AgentTool tool(String name, {ToolOutput Function(Map<String, dynamic>)? out}) => FnTool(
    name: name,
    description: 'test tool $name',
    inputSchema: {
      'type': 'object',
      'properties': {
        'x': {'type': 'number'},
      },
    },
    handler: (i) async {
      ran.add(name);
      return out?.call(i) ?? ToolOutput('$name ok ${jsonEncode(i)}');
    },
  );
  const picture = ToolImage('image/png', 'iVBORw0K');

  setUp(() {
    waits.clear();
    ran.clear();
    AiHttpClient.declined.clear();
    OpenRouterClient.clock = () => DateTime.utc(2026, 11, 10, 21, 30);
  });
  tearDown(() {
    OpenRouterClient.clock = DateTime.now;
    AiModel.unregister();
  });

  test('the request: OpenRouter\'s endpoint, the key in its header only, the app named, stateless, reasoning effort, no compaction, the session kept', () async {
    final s = _Server([(_) => _text('Hello')]);
    final c = api(s);
    final r = await c.send(req(AiModel.orGpt61Sol, effort: AiEffort.xhigh), cancel: AiCancel());
    expect(r.text, 'Hello');
    expect(r.stop, AiStop.end);
    final q = s.requests.single;
    expect(q.url.toString(), 'https://openrouter.ai/api/v1/responses');
    expect(q.headers, {'content-type': 'application/json', 'authorization': 'Bearer $_key', 'http-referer': 'https://opencadirrigation.com', 'x-openrouter-title': 'OpenCADIrrigation'});
    // the headers the CORS preflight of openrouter.ai allows (checked 2026-11-10)
    const allowed = {'authorization', 'content-type', 'http-referer', 'x-openrouter-title', 'x-title', 'x-session-id'};
    expect(allowed.containsAll(q.headers.keys), isTrue);
    expect(q.body.contains(_key), isFalse);
    final b = s.bodies.single;
    expect(b['model'], 'openai/gpt-6.1-sol');
    expect(b['instructions'], 'sys');
    expect(b['store'], isFalse);
    expect(b['stream'], isTrue);
    expect(b['include'], ['reasoning.encrypted_content']);
    expect(b['reasoning'], {'effort': 'xhigh'});
    expect(b['max_output_tokens'], 128000);
    expect(b.containsKey('context_management'), isFalse, reason: 'not in OpenRouter\'s request schema');
    expect(b.containsKey('previous_response_id'), isFalse);
    expect(b.containsKey('cache_control'), isFalse, reason: 'OpenAI\'s models cache by themselves');
    expect(b['session_id'], matches(RegExp(r'^oci-[0-9a-f]{16}$')));
    expect(b.keys.toSet().difference({'model', 'instructions', 'input', 'reasoning', 'max_output_tokens', 'stream', 'store', 'include', 'session_id'}), isEmpty);
    // usage: 1200 input of which 1000 read from the cache; output with its reasoning
    expect(r.usage.input, 200);
    expect(r.usage.cacheRead, 1000);
    expect(r.usage.output, 50);
    expect(c.lastCost, closeTo(0.00123, 1e-12), reason: 'OpenRouter\'s own figure');
    expect(r.model, 'openai/gpt-6.1-sol');
    expect(r.items.single, _msg('Hello'));
  });

  test('Claude\'s cache gets OpenRouter\'s automatic breakpoint, and the session id stays the same through the conversation', () async {
    final s = _Server([(_) => _text('a', model: 'anthropic/claude-opus-5.5'), (_) => _text('b', model: 'anthropic/claude-opus-5.5')]);
    final c = api(s);
    final first = req(AiModel.orOpus55, text: 'design the field');
    await c.send(first, cancel: AiCancel());
    await c.send(first.withHistory([...first.history, _msg('a'), user('and the pump')]), cancel: AiCancel());
    expect(s.bodies[0]['cache_control'], {'type': 'ephemeral'});
    expect(s.bodies[1]['cache_control'], {'type': 'ephemeral'});
    expect(s.bodies[0]['session_id'], s.bodies[1]['session_id']);
    expect(OpenRouterClient.sessionOf(req(AiModel.orOpus55, text: 'another field')), isNot(s.bodies[0]['session_id']));
    // the effort the model takes, the nearest below for Gemini
    final g = _Server([(_) => _text('x', model: 'google/gemini-4-argon')]);
    await api(g).send(req(AiModel.orGemini4Argon, effort: AiEffort.max), cancel: AiCancel());
    expect(g.bodies.single['reasoning'], {'effort': 'high'});
    expect(g.bodies.single['cache_control'], {'type': 'ephemeral'});
  });

  test('a session id needs nothing but what the request carries, and is the same in the browser (no 64-bit arithmetic)', () {
    final r = req(AiModel.orOpus55, text: 'olá');
    expect(OpenRouterClient.sessionOf(r), OpenRouterClient.sessionOf(req(AiModel.orSonnet55, text: 'olá')), reason: 'one conversation, whatever the model');
    // FNV-1a 32-bit of "a" from 0x811c9dc5 is 0xe40c292c (the published test vector)
    expect(OpenRouterClient.sessionOf(const AiRequest(model: AiModel.orOpus55, system: 'a', history: [])).substring(4, 12), 'e40c292c');
  });

  for (final (label, model, reasoning) in [
    (
      'Claude (thinking text with its signature)',
      AiModel.orSonnet55,
      {
        'type': 'reasoning',
        'id': 'rs_c1',
        'format': 'anthropic-claude-v1',
        'status': 'completed',
        'content': [
          {'type': 'reasoning_text', 'text': 'The user wants a look at the field first.'},
        ],
        'summary': [
          {'type': 'summary_text', 'text': 'Looking at the field.'},
        ],
        'signature': 'EvcBCkgIChABGAIqQKkSDbRuVEQUk9qN1odC098l9SEj',
      },
    ),
    (
      'GPT (encrypted reasoning)',
      AiModel.orGpt6Astra,
      {'type': 'reasoning', 'id': 'rs_g1', 'format': 'openai-responses-v1', 'encrypted_content': 'gAAAAABotI9-FK1PbhZhaZk4yMrZw3XDI1AWFaKb9T0N', 'summary': <Object?>[]},
    ),
    ('Gemini (thought signature)', AiModel.orGemini38Flash, {'type': 'reasoning', 'id': 'rs_m1', 'format': 'google-gemini-v1', 'encrypted_content': 'CiQB0e2Kb8sT3tB2', 'summary': <Object?>[]}),
  ]) {
    test('a tool loop with $label: the reasoning goes back exactly as it came, every call answered', () async {
      final s = _Server([
        (_) => _answer([
          reasoning,
          _call('look', {'x': 1}, 'a'),
          _call('snap', {}, 'b'),
        ], asked: model.id),
        (_) => _text('Seen it.', model: model.id),
      ]);
      final turn = await AgentLoop(
        api: api(s),
        tools: [
          tool('look'),
          tool('snap', out: (_) => const ToolOutput('a view', images: [picture])),
        ],
      ).run(model: model, system: 's', history: const [], user: user('go'), cancel: AiCancel());
      expect(turn.stop, AgentStop.done);
      expect(ran, ['look', 'snap']);
      expect(turn.text, 'Seen it.');
      final input = (s.bodies[1]['input'] as List).cast<Map<String, dynamic>>();
      expect(jsonEncode(input[1]), jsonEncode(reasoning), reason: 'byte for byte');
      expect(input.where((i) => i['type'] == 'function_call').map((i) => i['call_id']), ['call_a', 'call_b']);
      final outs = input.where((i) => i['type'] == 'function_call_output').toList();
      expect(outs.map((o) => o['call_id']), ['call_a', 'call_b']);
      expect(outs.first['output'], 'look ok {"x":1}');
      // the history keeps the picture in the result whoever the maker
      final kept = turn.messages.where((m) => m['type'] == 'function_call_output').last;
      expect(kept['output'], [
        {'type': 'input_text', 'text': 'a view'},
        {'type': 'input_image', 'image_url': 'data:image/png;base64,iVBORw0K', 'detail': 'high'},
      ]);
      if (OpenRouterClient.picturesInToolOutputs(model)) {
        expect(outs.last['output'], kept['output'], reason: '$label reads pictures in tool results');
        expect(input.last['type'], 'function_call_output');
      } else {
        expect(outs.last['output'], 'a view\n${OpenRouterClient.picturesMoved}');
        expect(input.last, {
          'type': 'message',
          'role': 'user',
          'content': [
            {'type': 'input_text', 'text': OpenRouterClient.picturesOf('snap', 'call_b')},
            {'type': 'input_image', 'image_url': 'data:image/png;base64,iVBORw0K', 'detail': 'high'},
          ],
        });
      }
      expect(countMedia(input).$1, 1, reason: 'the picture goes once');
    });
  }

  test('pictures after the results: one message per round, before what the user wrote meanwhile, the same in every request', () {
    final items = [
      user('go'),
      _call('snap', {}, 'a'),
      _call('map', {}, 'b'),
      ...OpenAiFormat.toolResults(
        [
          const AiToolResult('call_a', ToolOutput('drawing', images: [ToolImage('image/png', 'AAAA')])),
          const AiToolResult('call_b', ToolOutput('aerial', images: [ToolImage('image/jpeg', 'BBBB'), ToolImage('image/jpeg', 'CCCC')])),
        ],
        user: const [AiTextPart('also the pump')],
      ),
    ];
    final out = OpenRouterClient.picturesAfterResults(items);
    expect(out.map((i) => '${i['type']}:${i['role'] ?? ''}'), ['message:user', 'function_call:', 'function_call:', 'function_call_output:', 'function_call_output:', 'message:user', 'message:user']);
    final moved = out[5]['content'] as List;
    expect(
      [for (final p in moved) p['type'] == 'input_text' ? p['text'] : (p['image_url'] as String).substring(5, 15)],
      [OpenRouterClient.picturesOf('snap', 'call_a'), 'image/png;', OpenRouterClient.picturesOf('map', 'call_b'), 'image/jpeg', 'image/jpeg'],
    );
    expect(OpenAiFormat.userParts(out[6]).single, isA<AiTextPart>());
    expect(jsonEncode(OpenRouterClient.picturesAfterResults(items)), jsonEncode(out));
    expect(items[3]['output'], isA<List>(), reason: 'the history is not touched');
    final none = [user('go')];
    expect(identical(OpenRouterClient.picturesAfterResults(none), none), isTrue);
  });

  test('the user\'s pictures and PDFs go as OpenRouter documents; a model that does not read PDFs gets the free parser', () async {
    final parts = [const AiTextPart('see these'), const AiImagePart('image/jpeg', '/9j/AAAA'), const AiPdfPart('memorial.pdf', 'JVBERi0x')];
    final s = _Server([(_) => _text('ok', model: 'anthropic/claude-opus-5.5'), (_) => _text('ok', model: 'openrouter/free')]);
    final c = api(s);
    await c.send(
      AiRequest(model: AiModel.orOpus55, system: 's', history: [c.userMessage(parts)]),
      cancel: AiCancel(),
    );
    expect((s.bodies[0]['input'] as List).single['content'], [
      {'type': 'input_text', 'text': 'see these'},
      {'type': 'input_image', 'image_url': 'data:image/jpeg;base64,/9j/AAAA', 'detail': 'high'},
      {'type': 'input_file', 'filename': 'memorial.pdf', 'file_data': 'data:application/pdf;base64,JVBERi0x'},
    ]);
    expect(s.bodies[0].containsKey('plugins'), isFalse, reason: 'Claude reads PDFs itself');
    await c.send(
      AiRequest(model: AiModel.orFree, system: 's', history: [c.userMessage(parts)]),
      cancel: AiCancel(),
    );
    expect(s.bodies[1]['plugins'], OpenRouterClient.freeParser, reason: 'not the OCR billed per page on every request');
    expect(OpenRouterClient.freeParser.single['pdf'], {'engine': 'cloudflare-ai'});
  });

  test('replayed items get the id and status OpenRouter requires, made from their place; the history stays as it was', () async {
    final history = [
      user('hi'),
      {
        'type': 'message',
        'role': 'assistant',
        'content': [
          {'type': 'output_text', 'text': 'Hello', 'annotations': <Object?>[]},
        ],
      },
      {'type': 'reasoning', 'encrypted_content': 'x'},
      {'type': 'function_call', 'call_id': 'call_9', 'name': 'look', 'arguments': '{}'},
      {'type': 'function_call_output', 'call_id': 'call_9', 'output': 'fine'},
      user('more'),
    ];
    final s = _Server([(_) => _text('ok'), (_) => _text('ok')]);
    await api(s).send(req(AiModel.orGpt61Sol, history: history), cancel: AiCancel());
    final input = (s.bodies[0]['input'] as List).cast<Map<String, dynamic>>();
    expect(input[1]['id'], 'msg_1');
    expect(input[1]['status'], 'completed');
    expect(input[2], {'type': 'reasoning', 'encrypted_content': 'x', 'id': 'rs_2', 'summary': <Object?>[]});
    expect(input[3]['id'], 'fc_call_9');
    expect(history[1].containsKey('id'), isFalse);
    await api(s).send(req(AiModel.orGpt61Sol, history: history), cancel: AiCancel());
    expect(jsonEncode(s.bodies[1]['input']), jsonEncode(s.bodies[0]['input']), reason: 'the same prefix every time: the cache holds');
    final complete = [user('a'), _msg('b')];
    expect(identical(OpenRouterClient.withIds(complete), complete), isTrue);
  });

  test('a router names the model it chose: the answer is priced as that model', () async {
    final s = _Server([
      (_) => _answer([_msg('Hi')], asked: 'openrouter/auto', served: 'anthropic/claude-sonnet-5.5', usage: _usage(input: 1000000, cached: 0, output: 0, reasoning: 0, cost: 2)),
      (_) => _answer([_msg('Hi')], asked: 'openrouter/free', served: 'google/gemma-4-31b-it:free', usage: _usage(cost: 0)),
    ]);
    final c = api(s);
    final r = await c.send(req(AiModel.orAuto), cancel: AiCancel());
    expect(r.model, 'anthropic/claude-sonnet-5.5');
    expect(AiModel.served(r.model, AiModel.orAuto), AiModel.orSonnet55);
    expect(r.cost(AiModel.orAuto), closeTo(2, 1e-9), reason: 'a million input tokens at Sonnet\'s US\$ 2');
    expect(c.lastCost, 2);
    final f = await c.send(req(AiModel.orFree), cancel: AiCancel());
    expect(f.model, 'google/gemma-4-31b-it:free');
    expect(f.cost(AiModel.orFree), 0);
    expect(c.lastCost, 0);
  });

  test('a mid-stream failure: the canonical error type decides, text already shown is not sent again', () async {
    Future<AiError> failWith(_Out out) async {
      try {
        await api(_Server([(_) => out])).send(req(AiModel.orGpt61Sol), cancel: AiCancel());
      } on AiError catch (e) {
        return e;
      }
      fail('no error');
    }

    final cut = await failWith(_failed({'code': 'server_error', 'message': 'Provider disconnected unexpectedly'}, 'provider_unavailable', before: 'Hal'));
    expect(cut.kind, AiErrorKind.server);
    expect(cut.partial, isTrue);
    expect(cut.requestId, 'gen-test-0');
    expect(waits, isEmpty, reason: 'part of the answer arrived: not retried');
    final auth = await failWith(_failed({'code': 'server_error', 'message': 'Invalid credentials'}, 'authentication'));
    expect(auth.kind, AiErrorKind.auth, reason: 'server_error collapses many kinds; error_type tells');
    final filter = await failWith(_failed({'code': 'image_content_policy_violation', 'message': 'Flagged by SAFETY'}, 'content_policy_violation'));
    expect(filter.kind, AiErrorKind.refusal);
    expect(filter.category, 'content_policy_violation');
    expect(filter.message, 'Flagged by SAFETY');
    final refused = await failWith(_failed({'code': 'invalid_prompt', 'message': 'The model refused to respond'}, 'refusal'));
    expect(refused.kind, AiErrorKind.refusal);
    final context = await failWith(_failed({'code': 'invalid_prompt', 'message': 'Input is longer than the context window'}, 'context_length_exceeded'));
    expect(context.kind, AiErrorKind.contextWindow);
    final plain = await failWith(
      _sse([
        {'type': 'error', 'code': 'invalid_api_key', 'message': 'Invalid API key provided', 'param': null},
      ]),
    );
    expect(plain.kind, AiErrorKind.auth);
  });

  test('an answer cut at the output limit or stopped by a filter is an answer, not an error', () async {
    final resp = {'id': 'gen-1', 'object': 'response', 'model': 'anthropic/claude-opus-5.5', 'output': <Object?>[]};
    final s = _Server([
      (_) => _sse([
        {
          'type': 'response.incomplete',
          'response': {
            ...resp,
            'status': 'incomplete',
            'incomplete_details': {'reason': 'content_filter'},
            'output': [
              {
                'type': 'message',
                'id': 'msg_1',
                'status': 'incomplete',
                'role': 'assistant',
                'content': [
                  {'type': 'refusal', 'refusal': 'I can\'t help with that.'},
                ],
              },
            ],
            'usage': _usage(),
          },
        },
      ]),
      (_) => _sse([
        {
          'type': 'response.incomplete',
          'response': {
            ...resp,
            'status': 'incomplete',
            'incomplete_details': {'reason': 'max_output_tokens'},
            'output': [_msg('Half of it')],
            'usage': _usage(),
          },
        },
      ]),
    ]);
    final c = api(s);
    final refusal = await c.send(req(AiModel.orOpus55), cancel: AiCancel());
    expect(refusal.stop, AiStop.refusal);
    expect(refusal.explanation, 'I can\'t help with that.');
    final cut = await c.send(req(AiModel.orOpus55), cancel: AiCancel());
    expect(cut.stop, AiStop.maxTokens);
    expect(cut.text, 'Half of it');
  });

  group('errors before the stream, as OpenRouter documents them', () {
    Future<(AiError, _Server)> failing(List<_Out> outs, {AiModel? model}) async {
      final s = _Server([for (final o in outs) (_) => o]);
      try {
        await api(s).send(req(model ?? AiModel.orGpt61Sol), cancel: AiCancel());
      } on AiError catch (e) {
        return (e, s);
      }
      fail('no error');
    }

    test('401: a rejected key, not retried, with the generation id', () async {
      final (e, s) = await failing([
        _error(401, {
          'error': {'message': 'User not found.', 'code': 401},
        }),
      ]);
      expect(e.kind, AiErrorKind.auth);
      expect(e.status, 401);
      expect(e.message, 'User not found.');
      expect(e.requestId, 'gen-test-0');
      expect(s.requests, hasLength(1));
    });

    test('402: no credit; the in-flight budget is a wait, not a lack of credit', () async {
      final (credit, s) = await failing([
        _error(402, {
          'error': {
            'code': 402,
            'message': 'Insufficient credits. Add more using https://openrouter.ai/settings/credits',
            'metadata': {'limit_source': 'openrouter_credits', 'remedy_hint': 'Add credits.'},
          },
        }),
      ]);
      expect(credit.kind, AiErrorKind.credit);
      expect(s.requests, hasLength(1));
      final plain = await failing([
        _error(402, {
          'error': {'code': 402, 'message': 'Payment required'},
        }),
      ]);
      expect(plain.$1.kind, AiErrorKind.credit);
      final s2 = _Server([
        (_) => _error(
          402,
          {
            'error': {
              'code': 402,
              'message': 'This request would exceed your available credits given your current in-flight requests. Retry after in-flight requests settle, or add credits.',
              'metadata': {'reason': 'in_flight_budget_exhausted', 'limit_source': 'openrouter_in_flight_budget'},
            },
          },
          headers: {'retry-after': '3'},
        ),
        (_) => _text('done'),
      ]);
      final r = await api(s2).send(req(AiModel.orGpt61Sol), cancel: AiCancel());
      expect(r.text, 'done');
      expect(waits, [const Duration(seconds: 3)]);
    });

    test('403: a budget is a spending limit, a flag of the moderation a refusal with its reasons, a guardrail a permission', () async {
      final (budget, _) = await failing([
        _error(403, {
          'error': {
            'code': 403,
            'message': 'Key limit exceeded (monthly limit). \$10.00 of \$10.00 used; resets 2026-12-01T00:00:00.000Z.',
            'metadata': {'limit_source': 'openrouter_key_limit', 'scope': 'key_limit', 'limit_usd': 10, 'spend_usd': 10, 'resets_at': '2026-12-01T00:00:00.000Z'},
          },
        }),
      ]);
      expect(budget.kind, AiErrorKind.spendLimit);
      expect(budget.message, contains('resets 2026-12-01'));
      final (flag, _) = await failing([
        _error(403, {
          'error': {
            'code': 403,
            'message': 'Your input was flagged',
            'metadata': {
              'reasons': ['violence'],
              'flagged_input': 'abc',
              'provider_name': 'OpenAI',
              'model_slug': 'openai/gpt-6.1-sol',
            },
          },
        }),
      ]);
      expect(flag.kind, AiErrorKind.refusal);
      expect(flag.category, 'moderation');
      expect(flag.message, 'violence — Your input was flagged');
      final (guard, _) = await failing([
        _error(403, {
          'error': {
            'code': 403,
            'message': 'Request blocked: prompt injection patterns detected',
            'metadata': {
              'patterns': ['ignore all previous instructions'],
            },
          },
        }),
      ]);
      expect(guard.kind, AiErrorKind.permission);
    });

    test('408 and 502 are tried again; 503 (no provider meets the routing) is the service busy', () async {
      final s = _Server([
        (_) => _error(408, {
          'error': {'code': 408, 'message': 'Your request timed out'},
        }),
        (_) => _error(502, {
          'error': {'code': 502, 'message': 'Provider returned error'},
        }),
        (_) => _text('ok'),
      ]);
      expect((await api(s).send(req(AiModel.orGpt61Sol), cancel: AiCancel())).text, 'ok');
      expect(waits, hasLength(2));
      final (busy, _) = await failing([
        for (var i = 0; i < 3; i++)
          _error(503, {
            'error': {'code': 503, 'message': 'No allowed providers are available for the selected model.'},
          }),
      ]);
      expect(busy.kind, AiErrorKind.overloaded);
    });

    test('429 of a free model\'s daily limit waits until 00:00 UTC (the headers are not readable in the browser) and is not retried', () async {
      final (e, s) = await failing([
        _error(429, {
          'error': {
            'code': 429,
            'message': 'Rate limit exceeded: free-models-per-day. Add 10 credits to unlock 1000 free model requests per day',
            'metadata': {'error_type': 'rate_limit_exceeded'},
          },
        }),
      ], model: AiModel.orFree);
      expect(e.kind, AiErrorKind.rateLimit);
      expect(e.retryAfter, const Duration(hours: 2, minutes: 30), reason: 'clock at 21:30 UTC');
      expect(s.requests, hasLength(1), reason: 'longer than any wait worth making');
      // on the desktop the reset header is read
      expect(OpenRouterClient.waitOf({'x-ratelimit-reset': '${DateTime.utc(2026, 11, 10, 21, 30, 20).millisecondsSinceEpoch}'}, 'Rate limit exceeded'), const Duration(seconds: 20));
      expect(OpenRouterClient.waitOf({'retry-after': '7'}, ''), const Duration(seconds: 7));
      expect(OpenRouterClient.waitOf(const {}, 'Rate limit exceeded'), isNull);
      // a per-minute limit is retried after the usual backoff
      final s2 = _Server([
        (_) => _error(429, {
          'error': {'code': 429, 'message': 'Rate limit exceeded: free-models-per-min.'},
        }),
        (_) => _text('ok'),
      ]);
      expect((await api(s2).send(req(AiModel.orFree), cancel: AiCancel())).text, 'ok');
      expect(waits, hasLength(1));
    });

    test('400: a prompt over the context window, a field the model does not take, an invalid request (never a refusal)', () async {
      final (context, _) = await failing([
        _error(400, {
          'error': {'code': 400, 'message': 'This endpoint\'s maximum context length is 200000 tokens. However, you requested about 250000 tokens.'},
        }),
      ]);
      expect(context.kind, AiErrorKind.contextWindow);
      final (invalid, _) = await failing([
        _error(400, {
          'error': {'code': 'invalid_prompt', 'message': 'Missing required parameter: \'model\'.'},
          'metadata': null,
        }),
      ]);
      expect(invalid.kind, AiErrorKind.invalidRequest, reason: 'OpenRouter\'s invalid_prompt is a validation error');
      final s = _Server([
        (_) => _error(400, {
          'error': {'code': 400, 'message': 'Invalid parameter: session_id must be at most 256 characters'},
        }),
        (_) => _text('ok'),
      ]);
      expect((await api(s).send(req(AiModel.orGpt61Sol), cancel: AiCancel())).text, 'ok');
      expect(s.bodies[1].containsKey('session_id'), isFalse, reason: 'an optional field turned down is left out from then on');
      final (notFound, _) = await failing([
        _error(404, {
          'error': {'code': 404, 'message': 'No endpoints found for x/unknown.'},
        }),
      ]);
      expect(notFound.kind, AiErrorKind.notFound);
      final (tooLarge, _) = await failing([
        _error(413, {
          'error': {'code': 413, 'message': 'Payload too large'},
        }),
      ]);
      expect(tooLarge.kind, AiErrorKind.tooLarge);
      final (raw, _) = await failing([
        for (var i = 0; i < 3; i++) const _Out(500, '<html>Bad gateway</html>', headers: {'content-type': 'text/html'}),
      ]);
      expect(raw.kind, AiErrorKind.server);
    });
  });

  test('the connection test of an OpenRouter model goes as the assistant\'s requests do', () async {
    final s = _Server([(_) => _text('OK', model: 'anthropic/claude-haiku-5.5')]);
    final p = await api(s).probe(AiModel.orHaiku55, cancel: AiCancel());
    expect(p.ok, isTrue);
    expect(p.text, 'OK');
    expect(p.servedBy, 'anthropic/claude-haiku-5.5');
    expect(s.bodies.single['max_output_tokens'], AiHttpClient.probeTokens);
    expect(s.bodies.single['reasoning'], {'effort': 'low'});
  });
}
