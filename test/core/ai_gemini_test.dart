import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/ai/agent_tools.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/ai/gemini_api.dart';
import 'package:opencadirrigation/core/ai/llm_formats.dart';

/// The Gemini client (Interactions API) under the same agent loop, against
/// a scripted server (no network) that answers with the wire shapes of
/// Google's documentation (streaming guide, thinking guide, function calling
/// guide, API errors pages; 2026-11-10) and with the error body the live
/// server gave for an invalid key: the request written from the neutral
/// history, the streamed answer, thought signatures going back unchanged,
/// tools with text and pictures, every effort, every stop reason and
/// documented error, the determinism of the translation, the key only in
/// its header, and every tool schema of the assistant converted to what the
/// API takes.
void main() {
  const key = 'AIzaSy-SECRET-test-key-0000';

  GeminiClient api(FakeGemini f, {List<Duration>? waits, int maxRetries = 2}) => GeminiClient(apiKey: key, transport: f.call, sleep: (d) async => waits?.add(d), maxRetries: maxRetries);

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
  List<Map<String, dynamic>> input(Map<String, dynamic> body) => [for (final s in body['input'] as List) Map<String, dynamic>.from(s as Map)];

  Future<AiError> failure(GeminiClient c, {AiModel? model}) async {
    try {
      await c.send(
        AiRequest(model: model ?? AiModel.gemini38Flash, system: 's', history: [user('q')]),
        cancel: AiCancel(),
      );
    } on AiError catch (e) {
      return e;
    }
    throw StateError('no error');
  }

  setUp(() {
    ran.clear();
    AiHttpClient.declined.clear();
    AiModel.clock = DateTime.now;
  });

  test('a plain question: the documented request, the key in its header only, nothing stored, the answer streamed', () async {
    final f = FakeGemini([(_) => GemReply.stream(answer(text: 'Hello there', signature: 'SIG_0'))]);
    final r = await api(f).send(
      AiRequest(model: AiModel.gemini38Flash, system: 'sys', history: [user('hi')], tools: [tool('a').spec], effort: AiEffort.high),
      cancel: AiCancel(),
    );
    final req = f.requests.single;
    expect(req.url.toString(), 'https://generativelanguage.googleapis.com/v1beta/interactions');
    expect(req.url.host, AiProvider.google.host);
    expect(req.headers, {'content-type': 'application/json', 'x-goog-api-key': key}, reason: 'the two headers the CORS preflight allows');
    expect(req.body.contains(key), isFalse);
    final b = f.bodies.single;
    expect(b['model'], 'gemini-3.8-flash');
    expect(b['system_instruction'], 'sys');
    expect(b['input'], [
      {
        'type': 'user_input',
        'content': [
          {'type': 'text', 'text': 'hi'},
        ],
      },
    ]);
    expect(b['tools'], [
      {
        'type': 'function',
        'name': 'a',
        'description': 'test tool a',
        'parameters': {
          'type': 'object',
          'properties': {
            'x': {'type': 'number'},
          },
          'additionalProperties': false,
        },
      },
    ]);
    expect(b['generation_config'], {'thinking_level': 'high', 'max_output_tokens': 65536});
    expect(b['stream'], isTrue);
    expect(b['store'], isFalse, reason: 'nothing kept at Google for later requests');
    expect(b.keys.toSet(), {'model', 'system_instruction', 'input', 'tools', 'generation_config', 'stream', 'store'}, reason: 'only documented fields');

    expect(r.text, 'Hello there');
    expect(r.stop, AiStop.end);
    expect(r.calls, isEmpty);
    expect(r.model, 'gemini-3.8-flash');
    // 5000 input tokens of which 4096 read from the implicit cache; 90 output + 245 thinking tokens
    expect([r.usage.input, r.usage.cacheRead, r.usage.cacheWrite, r.usage.output], [904, 4096, 0, 335]);
    expect(r.items, [
      {
        'type': geminiStep,
        'step': {'type': 'thought', 'signature': 'SIG_0'},
      },
      {
        'type': 'message',
        'role': 'assistant',
        'content': [
          {'type': 'output_text', 'text': 'Hello there', 'annotations': <Object?>[]},
        ],
      },
    ]);
    expect(OpenAiFormat.text(r.items), r.text);
    expect(r.requestBytes, req.body.length);
    // the list prices of the model table (after the introductory price)
    AiModel.clock = () => DateTime.utc(2027, 6, 1);
    expect(r.cost(AiModel.gemini38Flash), closeTo((904 * 1.5 + 4096 * 0.15 + 335 * 7.5) / 1e6, 1e-12));
  });

  test('a multi-step tool round trip: parallel calls, results named after their calls, thought signatures sent back unchanged in their places', () async {
    final tools = <String>[];
    final f = FakeGemini([
      (_) => GemReply.stream(
        answer(
          text: 'Let me look.',
          signature: 'SIG_A/+==',
          calls: [
            ('fc_1', 'look', {'x': 1}),
            ('fc_2', 'snap', {}),
          ],
        ),
      ),
      (_) => GemReply.stream(
        answer(
          signature: 'SIG_B',
          calls: [
            ('fc_3', 'look', {'x': 2.5}),
          ],
        ),
      ),
      (_) => GemReply.stream(answer(text: 'Seen it.', signature: 'SIG_C')),
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
          model: AiModel.gemini4Argon,
          system: 's',
          history: const [],
          user: user('go'),
          cancel: AiCancel(),
          events: AgentEvents(
            onText: texts.add,
            onCall: (c) {
              if (c.state == ToolCallState.running && !tools.contains(c.id)) tools.add(c.id);
            },
          ),
        );
    expect(turn.stop, AgentStop.done);
    expect(ran, ['look', 'snap', 'look']);
    expect(tools, ['fc_1', 'fc_2', 'fc_3'], reason: 'the ids Gemini gave are the call ids');
    expect(turn.text, 'Let me look.\n\nSeen it.');
    expect(texts.join(), turn.text);

    final second = input(f.bodies[1]);
    expect(second, [
      {
        'type': 'user_input',
        'content': [
          {'type': 'text', 'text': 'go'},
        ],
      },
      {'type': 'thought', 'signature': 'SIG_A/+=='},
      {
        'type': 'model_output',
        'content': [
          {'type': 'text', 'text': 'Let me look.'},
        ],
      },
      {
        'type': 'function_call',
        'id': 'fc_1',
        'name': 'look',
        'arguments': {'x': 1},
      },
      {'type': 'function_call', 'id': 'fc_2', 'name': 'snap', 'arguments': <String, dynamic>{}},
      {
        'type': 'function_result',
        'name': 'look',
        'call_id': 'fc_1',
        'result': [
          {'type': 'text', 'text': 'look ok {"x":1}'},
        ],
      },
      {
        'type': 'function_result',
        'name': 'snap',
        'call_id': 'fc_2',
        'result': [
          {'type': 'text', 'text': 'a view'},
          {'type': 'image', 'mime_type': 'image/png', 'data': 'iVBORw0K', 'resolution': 'ultra_high'},
        ],
      },
    ]);
    final third = input(f.bodies[2]);
    // the conversation only grows: the second request goes again byte for byte
    expect(jsonEncode(third.sublist(0, second.length)), jsonEncode(second));
    expect(third.sublist(second.length), [
      {'type': 'thought', 'signature': 'SIG_B'},
      {
        'type': 'function_call',
        'id': 'fc_3',
        'name': 'look',
        'arguments': {'x': 2.5},
      },
      {
        'type': 'function_result',
        'name': 'look',
        'call_id': 'fc_3',
        'result': [
          {'type': 'text', 'text': 'look ok {"x":2.5}'},
        ],
      },
    ]);
    expect(f.bodies[2]['generation_config'], {'thinking_level': 'medium', 'max_output_tokens': 65536});
    // the conversation the app keeps, in the neutral format the app reads
    expect(turn.messages.map((m) => m['type']), [
      'message',
      geminiStep,
      'message',
      'function_call',
      'function_call',
      'function_call_output',
      'function_call_output',
      geminiStep,
      'function_call',
      'function_call_output',
      geminiStep,
      'message',
    ]);
    expect(OpenAiFormat.calls(turn.messages).map((c) => '${c.id} ${c.name} ${jsonEncode(c.input)}'), ['fc_1 look {"x":1}', 'fc_2 snap {}', 'fc_3 look {"x":2.5}']);
    // written again from the kept conversation (as after a reload), the same bytes
    final kept = [for (final m in jsonDecode(jsonEncode(turn.messages)) as List) Map<String, dynamic>.from(m as Map)];
    final again = GeminiFormat.steps(kept, resolution: 'ultra_high');
    expect(jsonEncode(again.sublist(0, third.length)), jsonEncode(third));
    expect(again.where((s) => s['type'] == 'thought').map((s) => s['signature']), ['SIG_A/+==', 'SIG_B', 'SIG_C']);
    expect(turn.cost, greaterThan(0));
  });

  test('pictures and PDFs: inline, the user\'s and the tools\', at ultra_high; a model that turns it down gets high from then on', () async {
    final msg = OpenAiFormat.user([const AiImagePart('image/jpeg', 'AAAA'), const AiPdfPart('sheet.pdf', 'JVBERi0'), const AiTextPart('Read these.')]);
    final f = FakeGemini([
      (_) => GemReply.json(400, {
        'error': {'code': 'invalid_request', 'message': "The value 'ultra_high' is not supported for 'resolution' at 'input[0].content[0]'."},
      }),
      (_) => GemReply.stream(answer(text: 'Read.')),
      (_) => GemReply.stream(answer(text: 'Again.')),
    ]);
    final c = api(f);
    final r = await c.send(
      AiRequest(model: AiModel.gemini35FlashLite, system: 's', history: [msg]),
      cancel: AiCancel(),
    );
    expect(r.text, 'Read.');
    expect([r.images, r.documents], [1, 1]);
    expect(f.calls, 2, reason: 'sent again at once without the field the model turned down');
    expect(input(f.bodies[0]).single['content'], [
      {'type': 'image', 'mime_type': 'image/jpeg', 'data': 'AAAA', 'resolution': 'ultra_high'},
      {'type': 'text', 'text': '[file: sheet.pdf]'},
      {'type': 'document', 'mime_type': 'application/pdf', 'data': 'JVBERi0'},
      {'type': 'text', 'text': 'Read these.'},
    ]);
    expect((input(f.bodies[1]).single['content'] as List).first, {'type': 'image', 'mime_type': 'image/jpeg', 'data': 'AAAA', 'resolution': 'high'});
    await c.send(
      AiRequest(model: AiModel.gemini35FlashLite, system: 's', history: [msg]),
      cancel: AiCancel(),
    );
    expect((input(f.bodies[2]).single['content'] as List).first['resolution'], 'high', reason: 'the model keeps the lower level');
    expect(c.resolutionOf(AiModel.gemini38Flash), 'ultra_high', reason: 'other models are not affected');

    // a tool result made only of a picture, and one whose picture was pruned from an old round
    final out = GeminiFormat.resultStep(OpenAiFormat.toolResult(const AiToolResult('c1', ToolOutput('', images: [ToolImage('image/jpeg', 'QQ')]))), const {'c1': 'view_snapshot'}, resolution: 'high');
    expect(out, {
      'type': 'function_result',
      'name': 'view_snapshot',
      'call_id': 'c1',
      'result': [
        {'type': 'image', 'mime_type': 'image/jpeg', 'data': 'QQ', 'resolution': 'high'},
      ],
    });
    // an error result is flagged
    final err = GeminiFormat.resultStep(OpenAiFormat.toolResult(AiToolResult('c2', ToolOutput.error('No such pipe.'))), const {}, resolution: 'high');
    expect(err, {
      'type': 'function_result',
      'call_id': 'c2',
      'result': [
        {'type': 'text', 'text': 'Error: No such pipe.'},
      ],
      'is_error': true,
    });
  });

  test('old pictures of tool results leave the request in steps, as with the other providers; the stored history is untouched', () async {
    Map<String, dynamic> pic(int k) => OpenAiFormat.toolResult(AiToolResult('c$k', ToolOutput('view $k', images: [ToolImage('image/png', 'P$k')])));
    final history = <Map<String, dynamic>>[user('go')];
    for (var k = 0; k < 7; k++) {
      history
        ..add({'type': 'function_call', 'call_id': 'c$k', 'name': 'snap', 'arguments': '{}'})
        ..add(pic(k));
    }
    final f = FakeGemini([(_) => GemReply.stream(answer(text: 'ok'))]);
    final r = await api(f).send(
      AiRequest(model: AiModel.gemini38Flash, system: 's', history: history),
      cancel: AiCancel(),
    );
    final results = input(f.bodies.single).where((s) => s['type'] == 'function_result').toList();
    expect([for (final s in results) (s['result'] as List).map((b) => (b as Map)['type']).join(',')], [for (var k = 0; k < 4; k++) 'text,text', for (var k = 4; k < 7; k++) 'text,image']);
    expect(r.images, 3);
    expect((history[2]['output'] as List).last['type'], 'input_image');
  });

  test('every effort on each model goes as a thinking level the model takes, never "minimal"', () async {
    const want = {AiEffort.low: 'low', AiEffort.medium: 'medium', AiEffort.high: 'high', AiEffort.xhigh: 'high', AiEffort.max: 'high'};
    for (final m in [AiModel.gemini4Argon, AiModel.gemini38Flash, AiModel.gemini35FlashLite]) {
      expect(m.efforts, [AiEffort.low, AiEffort.medium, AiEffort.high], reason: m.id);
      for (final e in AiEffort.values) {
        final f = FakeGemini([(_) => GemReply.stream(answer(text: 'ok'))]);
        await api(f).send(
          AiRequest(model: m, system: 's', history: [user('q')], effort: e),
          cancel: AiCancel(),
        );
        expect(f.bodies.single['generation_config'], {'thinking_level': want[e], 'max_output_tokens': 65536}, reason: '${m.id} ${e.name}');
        expect(GeminiClient.levelOf(m, e), want[e]);
      }
    }
    // a capped answer asks for less
    final f = FakeGemini([(_) => GemReply.stream(answer(text: 'ok'))]);
    await api(f).send(
      AiRequest(model: AiModel.gemini4Argon, system: 's', history: [user('q')], maxTokens: 16000),
      cancel: AiCancel(),
    );
    expect((f.bodies.single['generation_config'] as Map)['max_output_tokens'], 16000);
  });

  test('streaming: the text as it arrives (also text that comes with the step), the tool as it starts, activity on every event, in the documented order', () async {
    final events = [
      ...answer(
        text: 'Checking the pipes.',
        signature: 'SIG',
        calls: [
          ('fc_9', 'look', {'x': 3}),
        ],
      ),
    ];
    // the thinking guide shows a model_output step that starts with its first words
    final start = events.indexWhere((e) => e['event_type'] == 'step.start' && (e['step'] as Map)['type'] == 'model_output');
    events[start] = {
      ...events[start],
      'step': {
        'type': 'model_output',
        'content': [
          {'type': 'text', 'text': 'Now: '},
        ],
      },
    };
    final f = FakeGemini([(_) => GemReply.stream(events)]);
    final seen = <String>[];
    var activity = 0;
    final r = await api(f).send(
      AiRequest(model: AiModel.gemini38Flash, system: 's', history: [user('q')], tools: [tool('look').spec]),
      cancel: AiCancel(),
      listener: AiStreamListener(onText: (s) => seen.add('text:$s'), onToolStart: (n) => seen.add('tool:$n'), onActivity: () => activity++),
    );
    expect(seen, ['text:Now: ', 'text:Checking ', 'text:the pipes.', 'tool:look']);
    expect(activity, events.length);
    expect(r.text, 'Now: Checking the pipes.');
    expect(r.stop, AiStop.tool);
    expect(r.calls.single.input, {'x': 3});
    expect(r.items[1]['content'], [
      {'type': 'output_text', 'text': 'Now: Checking the pipes.', 'annotations': <Object?>[]},
    ]);
  });

  test('a long answer in thousands of deltas comes whole; Gemini 4 Argon waits 15 minutes for the next event; a connection test asks at the lowest level', () async {
    final events = answer(text: 'xy', complete: false);
    final at = events.lastIndexWhere((e) => e['event_type'] == 'step.delta');
    final many = [
      for (var k = 0; k < 20000; k++)
        {
          'event_type': 'step.delta',
          'index': 1,
          'delta': {'text': 'w$k ', 'type': 'text'},
        },
    ];
    final done = answer(text: 'z').last;
    final f = FakeGemini([
      (_) => GemReply.stream([...events.sublist(0, at + 1), ...many, ...events.sublist(at + 1), done]),
    ]);
    final watch = Stopwatch()..start();
    final r = await api(f).send(
      AiRequest(model: AiModel.gemini38Flash, system: 's', history: [user('q')]),
      cancel: AiCancel(),
    );
    expect(r.text, 'xy${[for (var k = 0; k < 20000; k++) 'w$k '].join()}');
    expect((r.items[1]['content'] as List).length, 1);
    expect(watch.elapsed, lessThan(const Duration(seconds: 20)));

    final c = api(FakeGemini(const []));
    expect(c.idleTimeout(AiModel.gemini4Argon), const Duration(minutes: 15), reason: 'Google: client timeouts of at least 15 minutes');
    expect(c.idleTimeout(AiModel.gemini4Argon, AiEffort.max), const Duration(minutes: 20));
    expect(c.idleTimeout(AiModel.gemini38Flash), const Duration(minutes: 3));

    final p = FakeGemini([(_) => GemReply.stream(answer(text: 'OK'))]);
    final probe = await api(p).probe(AiModel.gemini35FlashLite, cancel: AiCancel());
    expect(probe.ok, isTrue);
    expect(probe.text, 'OK');
    expect(p.bodies.single['generation_config'], {'thinking_level': 'low', 'max_output_tokens': AiHttpClient.probeTokens});
    expect(p.bodies.single.containsKey('tools'), isFalse);
  });

  test('a non-streamed answer (one interaction object) is read the same way, and its steps go back as they came', () async {
    final steps = [
      {
        'type': 'thought',
        'signature': 'SIG_W',
        'summary': [
          {'type': 'text', 'text': 'Need the pipes.'},
        ],
      },
      {
        'type': 'model_output',
        'content': [
          {
            'type': 'text',
            'text': 'See ',
            'annotations': [
              {'type': 'url_citation', 'url': 'https://example.org', 'start_index': 0, 'end_index': 3},
            ],
          },
        ],
      },
      {
        'name': 'look',
        'type': 'function_call',
        'arguments': {'x': 4},
        'id': 'call_98231',
      },
    ];
    final f = FakeGemini([
      (_) => GemReply.json(200, {
        'id': 'v1_whole',
        'status': 'requires_action',
        'model': 'gemini-4-argon',
        'object': 'interaction',
        'steps': steps,
        'usage': {'total_input_tokens': 100, 'total_cached_tokens': 0, 'total_output_tokens': 10, 'total_thought_tokens': 5, 'total_tokens': 115},
      }),
    ]);
    final r = await api(f).send(
      AiRequest(model: AiModel.gemini4Argon, system: 's', history: [user('q')], tools: [tool('look').spec]),
      cancel: AiCancel(),
    );
    expect(r.text, 'See ');
    expect(r.stop, AiStop.tool);
    expect(r.calls.single.id, 'call_98231');
    expect(r.calls.single.input, {'x': 4});
    expect([r.usage.input, r.usage.output], [100, 15]);
    expect(r.model, 'gemini-4-argon');
    expect(jsonEncode(GeminiFormat.steps(r.items)), jsonEncode(steps), reason: 'the step with a citation goes back whole');
  });

  test('stop reasons: its turn, tool calls, the output limit, a long decode left to continue, blocks and an empty answer as refusals with their category', () async {
    Future<AiReply> one(GemReply reply) => api(FakeGemini([(_) => reply]), maxRetries: 0).send(
      AiRequest(model: AiModel.gemini4Argon, system: 's', history: [user('q')]),
      cancel: AiCancel(),
    );
    expect((await one(GemReply.stream(answer(text: 'Done.')))).stop, AiStop.end);
    expect(
      (await one(
        GemReply.stream(
          answer(
            calls: [
              ('fc', 'look', {'x': 1}),
            ],
          ),
        ),
      )).stop,
      AiStop.tool,
    );
    final cut = await one(GemReply.stream(answer(text: 'A long ans', status: 'incomplete')));
    expect(cut.stop, AiStop.maxTokens);
    expect(cut.text, 'A long ans');
    expect((await one(GemReply.stream(answer(text: 'Part one', status: 'requires_continuation')))).stop, AiStop.maxTokens);

    // a block arrives as an error with a "generation blocked" code: a refusal, not an exception
    final safety = await one(
      GemReply.json(400, {
        'error': {'code': 'safety', 'message': 'Request blocked due to safety violations (harmful content). Please modify your input and retry.'},
      }),
    );
    expect(safety.stop, AiStop.refusal);
    expect(safety.category, 'safety');
    expect(safety.explanation, contains('safety violations'));
    expect(safety.items, isEmpty);
    final recitation = await one(
      GemReply.stream([
        ...answer(text: 'Once upon', complete: false),
        {
          'event_type': 'error',
          'error': {'code': 'recitation', 'message': 'Copyright or recitation restrictions blocked the request.'},
        },
      ], done: false),
    );
    expect([recitation.stop, recitation.category], [AiStop.refusal, 'recitation']);
    final empty = await one(
      GemReply.stream([
        {
          'event_type': 'interaction.completed',
          'interaction': {'id': 'v1_e', 'status': 'completed', 'usage': <String, dynamic>{}},
        },
      ]),
    );
    expect([empty.stop, empty.category], [AiStop.refusal, 'empty']);

    // under the agent loop a refusal is an error with its category, and the question can be asked again
    final t = await AgentLoop(
      api: api(
        FakeGemini([
          (_) => GemReply.json(400, {
            'error': {'code': 'prohibited_content', 'message': 'Input blocked: prohibited content.'},
          }),
        ]),
      ),
      tools: const [],
    ).run(model: AiModel.gemini38Flash, system: 's', history: const [], user: user('q'), cancel: AiCancel());
    expect(t.error!.kind, AiErrorKind.refusal);
    expect(t.error!.category, 'prohibited_content');
    expect(t.messages, isEmpty);

    // a stream that ends before the interaction is complete is not an answer
    final broken = FakeGemini([(_) => GemReply.stream(answer(text: 'Half', complete: false), done: false)]);
    final e = await failure(api(broken, maxRetries: 0));
    expect(e.kind, AiErrorKind.interrupted);
    expect(e.partial, isTrue, reason: 'text had shown: not sent again');
  });

  test('documented errors map to what the user can do; waits Google asks for are honoured; the key never shows', () async {
    Future<AiError> one(GemReply reply, {AiModel? model}) => failure(api(FakeGemini([(_) => reply]), maxRetries: 0), model: model);
    Map<String, dynamic> err(String code, String message) => {
      'error': {'code': code, 'message': message},
    };
    // Google's front end answers in its own shape, as a list (seen on 2026-11-10 for an invalid key)
    List<Object?> rpc(int code, String status, String message, [List<Map<String, dynamic>> details = const []]) => [
      {
        'error': {'code': code, 'message': message, 'status': status, if (details.isNotEmpty) 'details': details},
      },
    ];

    final invalid = await one(
      GemReply.json(
        400,
        rpc(400, 'INVALID_ARGUMENT', 'API key not valid. Please pass a valid API key.', [
          {
            '@type': 'type.googleapis.com/google.rpc.ErrorInfo',
            'reason': 'API_KEY_INVALID',
            'domain': 'googleapis.com',
            'metadata': {'service': 'generativelanguage.googleapis.com'},
          },
        ]),
      ),
    );
    expect(invalid.kind, AiErrorKind.auth);
    expect(invalid.status, 400);
    expect(invalid.retryable, isFalse);
    expect((await one(GemReply.json(401, err('authentication', 'The API key is missing, invalid, or expired.')))).kind, AiErrorKind.auth);
    expect((await one(GemReply.json(403, rpc(403, 'PERMISSION_DENIED', 'Your API key was reported as leaked. Please use another API key.')))).kind, AiErrorKind.auth);
    expect((await one(GemReply.json(402, err('payment_required', 'Your Prepay credit balance is depleted.')))).kind, AiErrorKind.credit);
    expect((await one(GemReply.json(403, err('permission_denied', 'Your project has been denied access. Please contact support.')))).kind, AiErrorKind.permission);
    expect((await one(GemReply.json(403, rpc(403, 'PERMISSION_DENIED', 'FREE_TIER_VERIFICATION_REQUIRED: verify your account to use the free tier.')))).kind, AiErrorKind.billing);
    expect(
      (await one(GemReply.json(400, rpc(400, 'FAILED_PRECONDITION', 'Gemini API free tier is not available in your country. Please enable billing on your project in Google AI Studio.')))).kind,
      AiErrorKind.billing,
    );
    expect((await one(GemReply.json(404, err('model_not_found', 'The specified model was not found.')))).kind, AiErrorKind.notFound);
    final context = await one(GemReply.json(400, err('invalid_request', 'The input token count (1200000) exceeds the maximum number of tokens allowed (1048576).')));
    expect(context.kind, AiErrorKind.contextWindow);
    final bad = await one(GemReply.json(400, err('invalid_request', "The value 'x' is not supported for 'type' at 'tools[0]'.")));
    expect(bad.kind, AiErrorKind.invalidRequest);
    expect(bad.message, contains('tools[0]'));
    expect((await one(GemReply.json(413, err('invalid_request', 'Request payload size exceeds the limit.')))).kind, AiErrorKind.tooLarge);
    expect((await one(GemReply.json(503, err('service_unavailable', 'The service is temporarily overloaded.')))).kind, AiErrorKind.overloaded);
    expect((await one(GemReply.json(504, err('deadline_exceeded', 'The request did not finish within the deadline.')))).kind, AiErrorKind.timeout);
    expect((await one(GemReply.plain(502, 'Bad gateway'))).kind, AiErrorKind.server);

    // the free tier's per-minute limit: the wait from RetryInfo (more than is waited: the error, with it)
    final perMinute = FakeGemini([
      (_) => GemReply.json(
        429,
        rpc(429, 'RESOURCE_EXHAUSTED', 'You exceeded your current quota, please check your plan and billing details.', [
          {
            '@type': 'type.googleapis.com/google.rpc.QuotaFailure',
            'violations': [
              {'quotaMetric': 'generativelanguage.googleapis.com/generate_content_free_tier_requests', 'quotaId': 'GenerateRequestsPerMinutePerProjectPerModel-FreeTier', 'quotaValue': '10'},
            ],
          },
          {'@type': 'type.googleapis.com/google.rpc.RetryInfo', 'retryDelay': '34s'},
        ]),
      ),
    ]);
    final waited = <Duration>[];
    final rate = await failure(api(perMinute, waits: waited));
    expect(rate.kind, AiErrorKind.rateLimit);
    expect(rate.retryAfter, const Duration(seconds: 34));
    expect(perMinute.calls, 1, reason: 'a wait over 30 s is not waited for');
    // a model with no free use on a project without billing: a quota of 0, not a wait
    final noBilling = await one(
      GemReply.json(
        429,
        rpc(
          429,
          'RESOURCE_EXHAUSTED',
          'You exceeded your current quota.\n* Quota exceeded for metric: generativelanguage.googleapis.com/generate_content_free_tier_input_token_count, limit: 0, model: gemini-4-argon\nPlease retry in 33.6s.',
        ),
      ),
      model: AiModel.gemini4Argon,
    );
    expect(noBilling.kind, AiErrorKind.billing);
    expect((await one(GemReply.json(429, err('rate_limit_exceeded', 'Monthly spend cap reached for this project.')))).kind, AiErrorKind.spendLimit);
    // a short wait in the message is waited for, then the request goes again
    final daily = FakeGemini([
      (_) => GemReply.json(429, err('rate_limit_exceeded', 'You have exceeded the per-minute token limit. Please retry in 2.5s.')),
      (_) => GemReply.stream(answer(text: 'fine')),
    ]);
    final waits = <Duration>[];
    final ok = await api(daily, waits: waits).send(
      AiRequest(model: AiModel.gemini38Flash, system: 's', history: [user('q')]),
      cancel: AiCancel(),
    );
    expect(ok.text, 'fine');
    expect(waits, [const Duration(milliseconds: 2500)]);

    // failures of the service, also inside the stream, are tried again
    final busy = FakeGemini([
      (_) => GemReply.json(500, err('api_error', 'An unexpected error occurred on the server.')),
      (_) => GemReply.stream([
        ...answer(complete: false),
        {
          'event_type': 'error',
          'error': {'message': 'Deadline expired before operation could complete.', 'code': 'gateway_timeout'},
        },
      ], done: false),
      (_) => GemReply.stream([
        ...answer(complete: false),
        {
          'event_type': 'error',
          'error': {'code': 'malformed_function_call', 'message': 'The model produced a function call that could not be parsed.'},
        },
      ], done: false),
      (_) => GemReply.stream(answer(text: 'fine')),
    ]);
    final r = await api(busy, maxRetries: 3).send(
      AiRequest(model: AiModel.gemini38Flash, system: 's', history: [user('q')]),
      cancel: AiCancel(),
    );
    expect(r.text, 'fine');
    expect(busy.calls, 4);
    // an error in the stream carries the interaction's id
    final inStream = await one(
      GemReply.stream([
        ...answer(complete: false),
        {'event_type': 'error', 'error': err('invalid_request', 'Bad step.')['error']},
      ], done: false),
    );
    expect([inStream.kind, inStream.requestId], [AiErrorKind.invalidRequest, 'v1_test']);

    // the key never shows, whatever echoes it
    final echoed = await one(GemReply.json(400, rpc(400, 'INVALID_ARGUMENT', 'API key not valid: $key')));
    expect(echoed.message, isNot(contains(key)));
    expect(echoed.message, contains('[key]'));
    final net = await failure(GeminiClient(apiKey: key, transport: (r, c) async => throw StateError('connection to ${r.url}?key=$key refused'), maxRetries: 0));
    expect(net.kind, AiErrorKind.network);
    expect(net.message, isNot(contains(key)));
    expect((await failure(GeminiClient(apiKey: '  ', transport: FakeGemini(const []).call))).kind, AiErrorKind.noKey);
  });

  test('the translation is deterministic: the same conversation gives the same bytes, from any client, after a save and a reload', () async {
    final history = <Map<String, dynamic>>[
      OpenAiFormat.user([const AiTextPart('Lay out the lawn.'), const AiImagePart('image/png', 'U1')]),
      {
        'type': geminiStep,
        'step': {'type': 'thought', 'signature': 'S1'},
      },
      ...OpenAiFormat.assistant('Looking.', const [
        AiToolCall('a1', 'snap', {'size': 800, 'region': 'all'}),
      ]),
      OpenAiFormat.toolResult(const AiToolResult('a1', ToolOutput('view', images: [ToolImage('image/png', 'V1')]))),
      OpenAiFormat.user([const AiTextPart('${steeringPrefix}Use 25 mm pipe.')]),
      OpenAiFormat.developer('Step limit: the next answer is the last step of this request.'),
    ];
    final specs = [tool('snap').spec, tool('look').spec];
    String bytes(GeminiClient c, List<Map<String, dynamic>> h) => jsonEncode(c.body(AiRequest(model: AiModel.gemini38Flash, system: 'sys', history: h, tools: specs)));
    final a = bytes(api(FakeGemini(const [])), history);
    expect(bytes(api(FakeGemini(const [])), history), a);
    final reloaded = [for (final m in jsonDecode(jsonEncode(history)) as List) Map<String, dynamic>.from(m as Map)];
    expect(bytes(api(FakeGemini(const [])), reloaded), a);
    final steps = input(jsonDecode(a) as Map<String, dynamic>);
    expect(steps.map((s) => s['type']), ['user_input', 'thought', 'model_output', 'function_call', 'function_result', 'user_input']);
    expect(steps.last['content'], [
      {'type': 'text', 'text': '${steeringPrefix}Use 25 mm pipe.'},
      {'type': 'text', 'text': 'Step limit: the next answer is the last step of this request.'},
    ], reason: 'what the user wrote meanwhile and the program\'s note: one user step');
    expect(steps[3], {
      'type': 'function_call',
      'id': 'a1',
      'name': 'snap',
      'arguments': {'size': 800, 'region': 'all'},
    });
    // items of another provider in the history are left out
    expect(
      GeminiFormat.steps([
        ...history,
        {'type': 'reasoning', 'encrypted_content': 'x'},
      ]).length,
      steps.length,
    );
    expect(identical(history.first['content'], reloaded.first['content']), isFalse);
  });

  test('schemas: what the API does not take becomes words in the description; property names stay whatever they spell', () {
    final s = GeminiFormat.schema({
      r'$schema': 'https://json-schema.org/draft/2020-12/schema',
      'type': 'object',
      'description': 'Inputs.',
      'properties': {
        'pattern': {
          'type': 'string',
          'enum': ['square', 'triangular'],
        },
        'format': {'type': 'string', 'description': 'File format.', 'format': 'uri'},
        'default': {'type': 'string', 'pattern': r'^[a-z]+$', 'maxLength': 20},
        'base_map': {
          'type': ['string', 'boolean'],
          'description': 'A choice or a boolean.',
        },
        'values': {
          'type': 'array',
          'items': {
            'type': ['number', 'null'],
          },
          'maxItems': 20000,
          'description': 'Readings.',
        },
        'points': {
          'type': 'array',
          'minItems': 2,
          'items': {
            'type': 'array',
            'items': {'type': 'number'},
            'minItems': 2,
            'maxItems': 2,
          },
        },
        'mode': {'const': 'fast'},
        'shape': {
          'oneOf': [
            {'type': 'string'},
            {'type': 'number', 'exclusiveMinimum': 0},
          ],
        },
        'attrs': {
          'type': 'object',
          'additionalProperties': {'type': 'string', 'default': ''},
        },
        'when': {'type': 'string', 'format': 'date-time'},
        'empty': {'type': 'object', 'properties': <String, Object?>{}},
      },
      'required': ['pattern', 'ghost'],
      'additionalProperties': false,
    });
    expect(s, {
      'type': 'object',
      'description': 'Inputs.',
      'properties': {
        'pattern': {
          'type': 'string',
          'enum': ['square', 'triangular'],
        },
        'format': {'type': 'string', 'description': 'File format. Format: uri.'},
        'default': {'type': 'string', 'description': r'Matches the pattern ^[a-z]+$. At most 20 characters.'},
        'base_map': {
          'description': 'A choice or a boolean.',
          'anyOf': [
            {'type': 'string'},
            {'type': 'boolean'},
          ],
        },
        'values': {
          'type': 'array',
          'items': {
            'type': ['number', 'null'],
          },
          'description': 'Readings. At most 20000 items.',
        },
        'points': {
          'type': 'array',
          'items': {
            'type': 'array',
            'items': {'type': 'number'},
            'description': 'At least 2 items. At most 2 items.',
          },
          'description': 'At least 2 items.',
        },
        'mode': {
          'enum': ['fast'],
        },
        'shape': {
          'anyOf': [
            {'type': 'string'},
            {'type': 'number', 'description': 'Greater than 0.'},
          ],
        },
        'attrs': {
          'type': 'object',
          'additionalProperties': {'type': 'string', 'description': 'Default: "".'},
        },
        'when': {'type': 'string', 'format': 'date-time'},
        'empty': {'type': 'object'},
      },
      'required': ['pattern'],
      'additionalProperties': false,
    });
    // a tool without inputs
    expect(GeminiFormat.tool(const AiToolSpec('ping', 'Ping.', {'type': 'object', 'properties': <String, Object?>{}})), {
      'type': 'function',
      'name': 'ping',
      'description': 'Ping.',
      'parameters': {'type': 'object'},
    });
  });

  testWidgets('every tool and operation of the assistant converts to a schema the API takes, nothing of it lost', (tester) async {
    LocalProjectStore().clearAll();
    final c = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
    final box = AgentToolbox(c);
    const allowed = {'type', 'title', 'description', 'properties', 'required', 'additionalProperties', 'enum', 'format', 'minimum', 'maximum', 'items', 'prefixItems', 'anyOf', r'$ref', r'$defs'};
    const types = {'string', 'number', 'integer', 'boolean', 'object', 'array', 'null'};
    var bounds = 0;
    // every schema of [g] is of the subset; [o] is the original it came from (property names and bounds compared)
    void walk(Map<String, Object?> g, Map<String, Object?> o, String path) {
      expect(g.keys.toSet().difference(allowed), isEmpty, reason: path);
      final t = g['type'];
      if (t is String) expect(types, contains(t), reason: path);
      if (t is List) expect(t.length == 2 && t.contains('null') && t.every(types.contains), isTrue, reason: path);
      if (g.containsKey('format')) expect(GeminiFormat.formats, contains(g['format']), reason: path);
      for (final b in ['minItems', 'maxItems']) {
        if (o[b] != null) {
          bounds++;
          expect('${g['description']}', contains('${b == 'minItems' ? 'At least' : 'At most'} ${o[b]} items.'), reason: '$path $b');
        }
      }
      final op = o['properties'], gp = g['properties'];
      if (op is Map && op.isNotEmpty) {
        expect((gp as Map).keys.toList(), op.keys.toList(), reason: '$path: the same properties');
        for (final k in op.keys) {
          walk(Map<String, Object?>.from(gp[k] as Map), Map<String, Object?>.from(op[k] as Map), '$path.$k');
        }
      }
      final req = g['required'];
      if (req is List) expect((gp as Map).keys, containsAll(req), reason: path);
      if (o['items'] is Map) walk(Map<String, Object?>.from(g['items'] as Map), Map<String, Object?>.from(o['items'] as Map), '$path[]');
      if (o['additionalProperties'] is Map) {
        walk(Map<String, Object?>.from(g['additionalProperties'] as Map), Map<String, Object?>.from(o['additionalProperties'] as Map), '$path{}');
      }
      for (final x in [...(g['anyOf'] as List? ?? const [])]) {
        expect((x as Map).keys.toSet().difference(allowed), isEmpty, reason: path);
      }
    }

    final all = [...box.tools, ...box.operations];
    expect(all.length, greaterThan(40));
    for (final t in all) {
      final g = GeminiFormat.tool(t.spec);
      expect(g['name'], t.name);
      expect(g['description'], t.description);
      final p = g['parameters'] as Map<String, Object?>?;
      if (p != null) walk(p, t.inputSchema, t.name);
      // every schema of the assistant has inputs or is an object without them
      expect(p?['type'] ?? 'object', 'object', reason: t.name);
      expect(jsonEncode(GeminiFormat.tool(t.spec)), jsonEncode(g), reason: 'deterministic');
    }
    expect(bounds, greaterThan(0), reason: 'the assistant\'s array bounds were found and said in words');
  });
}

/// The event list of a streamed answer, in the order the streaming guide
/// documents: the interaction created, its status, each step (a thought
/// with its signature as the last delta, the model's text in two deltas,
/// each function call with its id and name at the start and its arguments
/// as JSON text in two deltas), then the interaction completed with the
/// usage ([complete] false: the stream stops before it).
List<Map<String, dynamic>> answer({
  String text = '',
  List<(String, String, Map<String, dynamic>)> calls = const [],
  String? signature = 'sig',
  String? status,
  bool complete = true,
  String model = 'gemini-3.8-flash',
}) {
  Map<String, dynamic> ev(String type, Map<String, dynamic> data) => {...data, 'event_type': type};
  final out = <Map<String, dynamic>>[
    ev('interaction.created', {
      'interaction': {'id': 'v1_test', 'status': 'in_progress', 'object': 'interaction', 'model': model},
    }),
    ev('interaction.status_update', {'interaction_id': 'v1_test', 'status': 'in_progress'}),
  ];
  var i = 0;
  if (signature != null) {
    out
      ..add(
        ev('step.start', {
          'index': i,
          'step': {'type': 'thought'},
        }),
      )
      ..add(
        ev('step.delta', {
          'index': i,
          'delta': {'signature': signature, 'type': 'thought_signature'},
        }),
      )
      ..add(ev('step.stop', {'index': i}));
    i++;
  }
  if (text.isNotEmpty) {
    out.add(
      ev('step.start', {
        'index': i,
        'step': {'type': 'model_output'},
      }),
    );
    final half = text.length ~/ 2;
    for (final d in [text.substring(0, half), text.substring(half)]) {
      out.add(
        ev('step.delta', {
          'index': i,
          'delta': {'text': d, 'type': 'text'},
        }),
      );
    }
    out.add(ev('step.stop', {'index': i}));
    i++;
  }
  for (final (id, name, args) in calls) {
    out.add(
      ev('step.start', {
        'index': i,
        'step': {'type': 'function_call', 'id': id, 'name': name, 'arguments': <String, dynamic>{}},
      }),
    );
    final json = jsonEncode(args);
    final half = json.length ~/ 2;
    for (final d in [json.substring(0, half), json.substring(half)]) {
      out.add(
        ev('step.delta', {
          'index': i,
          'delta': {'arguments': d, 'type': 'arguments_delta'},
        }),
      );
    }
    out.add(ev('step.stop', {'index': i}));
    i++;
  }
  if (complete) {
    out.add(
      ev('interaction.completed', {
        'interaction': {
          'id': 'v1_test',
          'status': status ?? (calls.isEmpty ? 'completed' : 'requires_action'),
          'usage': {
            'total_tokens': 5335,
            'total_input_tokens': 5000,
            'input_tokens_by_modality': [
              {'modality': 'text', 'tokens': 5000},
            ],
            'total_cached_tokens': 4096,
            'total_output_tokens': 90,
            'total_tool_use_tokens': 0,
            'total_thought_tokens': 245,
          },
          'created': '2026-11-10T12:00:00Z',
          'updated': '2026-11-10T12:00:02Z',
          'service_tier': 'standard',
          'object': 'interaction',
          'model': model,
        },
      }),
    );
  }
  return out;
}

/// One scripted answer of [FakeGemini].
class GemReply {
  /// Server-sent events, each `event: <type>` and `data: <json>`, then
  /// `event: done` / `data: [DONE]` ([done]).
  GemReply.stream(List<Map<String, dynamic>> events, {bool done = true})
    : status = 200,
      mime = 'text/event-stream; charset=utf-8',
      text = [for (final e in events) 'event: ${e['event_type']}\ndata: ${jsonEncode(e)}\n\n', if (done) 'event: done\ndata: [DONE]\n\n'].join();
  GemReply.json(this.status, Object? body) : mime = 'application/json; charset=UTF-8', text = jsonEncode(body);
  GemReply.plain(this.status, this.text) : mime = 'text/plain';
  final int status;
  final String mime, text;
}

/// A scripted Gemini API: answers the requests in order with [script] (each
/// entry may read the request body), in chunks that cut lines anywhere, and
/// records them.
class FakeGemini {
  FakeGemini(this.script);
  final List<GemReply Function(Map<String, dynamic> body)> script;
  final requests = <AiHttpRequest>[];
  final bodies = <Map<String, dynamic>>[];

  int get calls => requests.length;

  Future<AiHttpResponse> call(AiHttpRequest r, AiCancel cancel) async {
    requests.add(r);
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    bodies.add(body);
    final n = requests.length - 1;
    final reply = n < script.length ? script[n](body) : GemReply.stream(answer(text: '(end of script)'));
    final bytes = utf8.encode(reply.text);
    final chunks = <List<int>>[for (var k = 0; k < bytes.length; k += 61) bytes.sublist(k, k + 61 > bytes.length ? bytes.length : k + 61)];
    return AiHttpResponse(reply.status, {'content-type': reply.mime}, Stream.fromIterable(chunks));
  }
}
