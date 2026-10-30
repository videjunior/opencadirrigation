import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/ai/llm_formats.dart';
import 'package:opencadirrigation/core/ai/openai_api.dart';

import '../support/fake_openai.dart';

/// The OpenAI client (Responses API) under the same agent loop, against a
/// scripted model (no network): the request the API documents, the streamed
/// answer, reasoning items going back unchanged, tools with text and
/// pictures, compaction, errors (a rejected key, quota versus rate limit, a
/// model the account cannot use, failures in the stream) and the key only
/// in its header.
void main() {
  const key = 'sk-proj-SECRET-test-key-0000';

  OpenAiClient api(FakeOpenAi f, {List<Duration>? waits}) => OpenAiClient(apiKey: key, transport: f.call, sleep: (d) async => waits?.add(d));

  final ran = <String>[];
  AgentTool tool(String name, {ToolEffect effect = ToolEffect.read, ToolOutput Function(Map<String, dynamic>)? out}) => FnTool(
    name: name,
    description: 'test tool $name',
    effect: effect,
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
  });

  test('the request follows the Responses API: endpoint, bearer key, instructions, input, function tools, reasoning effort, no storage', () async {
    final f = FakeOpenAi([(_) => OpenAiReply.text('Hello')]);
    final r = await api(f).send(
      AiRequest(model: AiModel.gpt6Astra, system: 'sys', history: [user('hi')], tools: [tool('a').spec], effort: AiEffort.xhigh, compactAt: 200000),
      cancel: AiCancel(),
    );
    expect(r.text, 'Hello');
    expect(r.stop, AiStop.end);
    final req = f.requests.single;
    expect(req.url.toString(), 'https://api.openai.com/v1/responses');
    expect(req.headers['authorization'], 'Bearer $key');
    expect(req.headers['content-type'], 'application/json');
    expect(req.headers.keys.where((k) => k.startsWith('anthropic') || k == 'x-api-key'), isEmpty);
    final b = f.bodies.single;
    expect(b['model'], 'gpt-6-astra');
    expect(b['instructions'], 'sys');
    expect(b['input'], [
      {
        'type': 'message',
        'role': 'user',
        'content': [
          {'type': 'input_text', 'text': 'hi'},
        ],
      },
    ]);
    expect(b['tools'], [
      {'type': 'function', 'name': 'a', 'description': 'test tool a', 'parameters': tool('a').inputSchema, 'strict': false},
    ]);
    expect(b['reasoning'], {'effort': 'xhigh'});
    expect(b['stream'], isTrue);
    expect(b['store'], isFalse);
    expect(b['include'], ['reasoning.encrypted_content']);
    expect(b['max_output_tokens'], 64000);
    expect(b['context_management'], [
      {'type': 'compaction', 'compact_threshold': 200000},
    ]);
    expect(
      b.keys.toSet().difference({'model', 'instructions', 'input', 'tools', 'reasoning', 'max_output_tokens', 'stream', 'store', 'include', 'context_management'}),
      isEmpty,
      reason: 'only documented fields',
    );
    expect(req.body.contains(key), isFalse);
    // 1500 input tokens of which 300 read from and 200 written to the cache
    expect(r.usage.input, 1000);
    expect(r.usage.cacheRead, 300);
    expect(r.usage.cacheWrite, 200);
    expect(r.usage.output, 60);
    // the reasoning item with its encrypted content goes back as it came
    expect(r.items.first, {'id': 'rs_0', 'type': 'reasoning', 'summary': [], 'encrypted_content': 'enc_0'});
  });

  test('a turn with tools: function outputs answer every call, the history goes back unchanged, pictures travel with the results', () async {
    final f = FakeOpenAi([
      (_) => OpenAiReply.tools([
        ('look', {'x': 1}),
        ('snap', {}),
      ], text: 'Let me look.'),
      (_) => OpenAiReply.text('Seen it.'),
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
          model: AiModel.gpt61Sol,
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
    expect(turn.messages.map((m) => m['type']), ['message', 'reasoning', 'message', 'function_call', 'function_call', 'function_call_output', 'function_call_output', 'reasoning', 'message']);
    final input = (f.bodies[1]['input'] as List).cast<Map<String, dynamic>>();
    final calls = input.where((i) => i['type'] == 'function_call').toList();
    final outs = input.where((i) => i['type'] == 'function_call_output').toList();
    expect(outs.map((o) => o['call_id']), calls.map((c) => c['call_id']));
    expect(outs.first['output'], 'look ok {"x":1}');
    expect(outs.last['output'], [
      {'type': 'input_text', 'text': 'a view'},
      {'type': 'input_image', 'image_url': 'data:image/png;base64,iVBORw0K', 'detail': 'high'},
    ]);
    // byte for byte as received
    expect(jsonEncode(input.sublist(0, 5)), jsonEncode(turn.messages.sublist(0, 5)));
    expect(turn.cost, greaterThan(0));
  });

  test('the user\'s pictures and PDFs, notes from the program and messages written meanwhile', () async {
    final msg = OpenAiFormat.user([const AiImagePart('image/jpeg', 'AAAA'), const AiPdfPart('sheet.pdf', 'JVBERi0'), const AiTextPart('Read these.')]);
    expect(msg['content'], [
      {'type': 'input_image', 'image_url': 'data:image/jpeg;base64,AAAA', 'detail': 'high'},
      {'type': 'input_file', 'filename': 'sheet.pdf', 'file_data': 'data:application/pdf;base64,JVBERi0'},
      {'type': 'input_text', 'text': 'Read these.'},
    ]);
    final queue = ['Use 25 mm pipe.'];
    final f = FakeOpenAi([
      for (var k = 0; k < 3; k++)
        (_) => OpenAiReply.tools([
          ('look', {'x': k}),
        ]),
    ]);
    final turn = await AgentLoop(api: api(f), tools: [tool('look')]).run(
      model: AiModel.gpt6Luna,
      system: 's',
      history: const [],
      user: msg,
      maxSteps: 3,
      cancel: AiCancel(),
      events: AgentEvents(
        steer: () {
          final out = [for (final s in queue) AiTextPart(s)];
          queue.clear();
          return out;
        },
      ),
    );
    expect(turn.stop, AgentStop.stepLimit);
    final second = (f.bodies[1]['input'] as List).cast<Map<String, dynamic>>();
    expect(second.last['role'], 'user');
    expect(((second.last['content'] as List).single as Map)['text'], contains('Use 25 mm pipe.'));
    final third = (f.bodies[2]['input'] as List).cast<Map<String, dynamic>>();
    expect(third.last['role'], 'developer', reason: 'a note from the program');
    expect(f.lastInputText(2), contains('Step limit'));
  });

  test('compaction: the next request starts at the compaction item', () async {
    final f = FakeOpenAi([
      (_) => OpenAiReply.tools([
        ('look', {'x': 1}),
      ], compaction: true),
      (_) => OpenAiReply.text('Done.'),
    ]);
    final turn = await AgentLoop(
      api: api(f),
      tools: [tool('look')],
    ).run(model: AiModel.gpt6Astra, system: 's', history: [user('earlier'), ...OpenAiFormat.assistant('earlier answer', const [])], user: user('go on'), compactAt: 200000, cancel: AiCancel());
    expect(turn.compactions, 1);
    final second = (f.bodies[1]['input'] as List).cast<Map<String, dynamic>>();
    expect(second.first, {'id': 'cmp_0', 'type': 'compaction', 'encrypted_content': 'compacted_0'});
    expect(second.where((i) => i['type'] == 'message' && i['role'] == 'user'), isEmpty, reason: 'what came before is in the compaction item');
  });

  test('old pictures in tool results leave the request in steps; the user\'s own pictures and the stored history stay', () {
    Map<String, dynamic> pic(int k) => OpenAiFormat.toolResult(AiToolResult('c$k', ToolOutput('view $k', images: [ToolImage('image/png', 'P$k')])));
    final mine = OpenAiFormat.user([const AiImagePart('image/jpeg', 'MINE'), const AiTextPart('my photo')]);
    final items = [mine, for (var k = 0; k < 6; k++) pic(k)];
    expect(identical(pruneToolPictures(items), items), isTrue, reason: 'six pictures: nothing pruned yet');
    final more = [...items, pic(6)];
    final pruned = pruneToolPictures(more);
    String kinds(Map<String, dynamic> it) => [for (final p in it['output'] as List) (p as Map)['type']].join(',');
    expect([for (final it in pruned.skip(1)) kinds(it)], [for (var k = 0; k < 4; k++) 'input_text,input_text', for (var k = 4; k < 7; k++) 'input_text,input_image']);
    expect(pruned.first, mine);
    expect(kinds(more[1]), 'input_text,input_image', reason: 'the history itself is not changed');
  });

  test('a model without server-side compaction gets the request again without it', () async {
    final f = FakeOpenAi([(_) => OpenAiReply.error(400, '', "Unsupported parameter: 'context_management' is not supported with this model."), (_) => OpenAiReply.text('ok')]);
    final r = await api(f).send(
      AiRequest(model: AiModel.gpt56Terra, system: 's', history: [user('q')], compactAt: 200000),
      cancel: AiCancel(),
    );
    expect(r.text, 'ok');
    expect(f.bodies[0].containsKey('context_management'), isTrue);
    expect(f.bodies[1].containsKey('context_management'), isFalse);
  });

  test('errors: a rejected key, quota versus rate limit, a model the account cannot use, a refusal, a response cut short', () async {
    Future<AiError> failure(OpenAiReply Function(Map<String, dynamic>) reply) async {
      final f = FakeOpenAi([reply, reply, reply, reply]);
      try {
        await api(f).send(
          AiRequest(model: AiModel.gpt6Astra, system: 's', history: [user('q')]),
          cancel: AiCancel(),
        );
      } on AiError catch (e) {
        return e;
      }
      throw StateError('no error');
    }

    final auth = await failure(
      (_) => OpenAiReply.error(401, 'invalid_api_key', 'Incorrect API key provided: sk-proj-****************0000. You can find your API key at https://platform.openai.com/account/api-keys.'),
    );
    expect(auth.kind, AiErrorKind.auth);
    expect(auth.message, isNot(contains('sk-proj-')));
    expect(auth.message, contains('[key]'));
    final plain = await failure((_) => OpenAiReply.error(401, '', 'Unauthorized', mime: 'text/plain'));
    expect(plain.kind, AiErrorKind.auth);
    final quota = await failure((_) => OpenAiReply.error(429, 'insufficient_quota', 'You exceeded your current quota, please check your plan and billing details.', type: 'insufficient_quota'));
    expect(quota.kind, AiErrorKind.credit, reason: 'no credit left: a page to add it, not a retry');
    expect(quota.retryable, isFalse);
    final model = await failure((_) => OpenAiReply.error(404, 'model_not_found', 'The model `gpt-6-astra` does not exist or you do not have access to it.'));
    expect(model.kind, AiErrorKind.notFound);
    final access = await failure((_) => OpenAiReply.error(403, '', 'Project `proj_x` does not have access to model `gpt-6-astra`', type: 'invalid_request_error'));
    expect(access.kind, AiErrorKind.notFound);
    final bad = await failure((_) => OpenAiReply.error(400, 'context_length_exceeded', 'Your input exceeds the context window of this model.'));
    expect(bad.kind, AiErrorKind.contextWindow);

    // rate limits and failures in the stream are retried
    final waits = <Duration>[];
    final busy = FakeOpenAi([
      (_) => OpenAiReply.error(429, 'rate_limit_exceeded', 'Rate limit reached for requests', type: 'requests'),
      (_) => OpenAiReply.failed('server_error', 'The server had an error while processing your request.'),
      (_) => OpenAiReply.text('fine'),
    ]);
    final r = await api(busy, waits: waits).send(
      AiRequest(model: AiModel.gpt6Sol, system: 's', history: [user('q')]),
      cancel: AiCancel(),
    );
    expect(r.text, 'fine');
    expect(busy.calls, 3);
    expect(waits.length, 2);

    // a refusal is an error with the model's words; a cut answer is not retried
    final refused = FakeOpenAi([(_) => OpenAiReply.refusal('I cannot help with that.')]);
    final t = await AgentLoop(api: api(refused), tools: const []).run(model: AiModel.gpt6Astra, system: 's', history: const [], user: user('q'), cancel: AiCancel());
    expect(t.error!.kind, AiErrorKind.refusal);
    expect(t.error!.message, 'I cannot help with that.');
    expect(t.messages, isEmpty);
    final cut = FakeOpenAi([(_) => OpenAiReply.cut('Half an ans'), (_) => OpenAiReply.text('never asked')]);
    final t2 = await AgentLoop(api: api(cut), tools: const []).run(model: AiModel.gpt6Astra, system: 's', history: const [], user: user('q'), cancel: AiCancel());
    expect(t2.error!.kind, AiErrorKind.interrupted);
    expect(cut.calls, 1);
    final long = FakeOpenAi([(_) => OpenAiReply.incomplete('max_output_tokens', text: 'A long answer')]);
    final t3 = await AgentLoop(api: api(long), tools: const []).run(model: AiModel.gpt6Astra, system: 's', history: const [], user: user('q'), cancel: AiCancel());
    expect(t3.stop, AgentStop.maxTokens);
    expect(t3.text, 'A long answer');
    final filtered = FakeOpenAi([(_) => OpenAiReply.incomplete('content_filter')]);
    final t4 = await AgentLoop(api: api(filtered), tools: const []).run(model: AiModel.gpt6Astra, system: 's', history: const [], user: user('q'), cancel: AiCancel());
    expect(t4.error!.kind, AiErrorKind.refusal);
    expect(t4.error!.category, 'content_filter');
  });

  test('the model list: tiers, list prices, the long-prompt rule', () {
    expect(AiModel.gpt6Astra.tier, AiTier.top);
    expect(AiModel.gpt61Sol.tier, AiTier.intermediate);
    expect(AiModel.gpt6Luna.tier, AiTier.fast);
    expect([AiModel.gpt6Astra.input, AiModel.gpt6Astra.cacheRead, AiModel.gpt6Astra.cacheWrite, AiModel.gpt6Astra.output], [10, 1, 12.5, 50]);
    expect([AiModel.gpt61Sol.input, AiModel.gpt61Sol.cacheRead, AiModel.gpt61Sol.cacheWrite, AiModel.gpt61Sol.output], [2, 0.1, 2.5, 10]);
    expect([AiModel.gpt6Luna.input, AiModel.gpt6Luna.cacheRead, AiModel.gpt6Luna.cacheWrite, AiModel.gpt6Luna.output], [0.1, 0.01, 0.125, 0.5]);
    expect([AiModel.gpt6Sol.earlier, AiModel.gpt56Terra.earlier], [isTrue, isTrue]);
    for (final m in AiModel.all.where((m) => m.provider == AiProvider.openai)) {
      expect(m.longAbove, 272000, reason: m.id);
    }
  });
}
