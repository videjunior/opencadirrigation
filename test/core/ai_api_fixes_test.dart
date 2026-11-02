import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/ai/claude_api.dart';
import 'package:opencadirrigation/core/ai/llm_formats.dart';
import 'package:opencadirrigation/core/ai/openai_api.dart';

import '../support/fake_openai.dart';

const key = 'sk-ant-api03-SECRET-test-key-0000';

/// A server-sent-event response carrying [events].
AiHttpResponse sse(List<Map<String, dynamic>> events, {Map<String, String> headers = const {}}) {
  final text = StringBuffer();
  for (final e in events) {
    text.write('event: ${e['type']}\ndata: ${jsonEncode(e)}\n\n');
  }
  return AiHttpResponse(200, {'content-type': 'text/event-stream', ...headers}, Stream.value(utf8.encode(text.toString())));
}

Map<String, dynamic> thinking(String text, String signature) => {'type': 'thinking', 'thinking': text, 'signature': signature};
Map<String, dynamic> textBlock(String text) => {'type': 'text', 'text': text};
Map<String, dynamic> toolUse(String id, String name, Map<String, dynamic> input) => {'type': 'tool_use', 'id': id, 'name': name, 'input': input};

const topUsage = {'input_tokens': 1000, 'output_tokens': 1, 'cache_creation_input_tokens': 200, 'cache_read_input_tokens': 300};

/// The events of a message made of [blocks], each streamed as the API does
/// (thinking text and signature, text and tool input in deltas).
List<Map<String, dynamic>> message(
  List<Map<String, dynamic>> blocks, {
  String? stop = 'end_turn',
  String model = 'claude-opus-5-5',
  Map<String, dynamic> usage = topUsage,
  List<Map<String, dynamic>>? iterations,
  Map<String, dynamic>? stopDetails,
  bool end = true,
}) => [
  {
    'type': 'message_start',
    'message': {'id': 'msg', 'type': 'message', 'role': 'assistant', 'model': model, 'content': [], 'usage': usage},
  },
  for (var i = 0; i < blocks.length; i++)
    ...switch (blocks[i]['type']) {
      'thinking' => [
        {
          'type': 'content_block_start',
          'index': i,
          'content_block': {'type': 'thinking', 'thinking': '', 'signature': ''},
        },
        if ((blocks[i]['thinking'] as String).isNotEmpty)
          {
            'type': 'content_block_delta',
            'index': i,
            'delta': {'type': 'thinking_delta', 'thinking': blocks[i]['thinking']},
          },
        {
          'type': 'content_block_delta',
          'index': i,
          'delta': {'type': 'signature_delta', 'signature': blocks[i]['signature']},
        },
        {'type': 'content_block_stop', 'index': i},
      ],
      'text' => [
        {
          'type': 'content_block_start',
          'index': i,
          'content_block': {'type': 'text', 'text': ''},
        },
        {
          'type': 'content_block_delta',
          'index': i,
          'delta': {'type': 'text_delta', 'text': blocks[i]['text']},
        },
        {'type': 'content_block_stop', 'index': i},
      ],
      _ => [
        {
          'type': 'content_block_start',
          'index': i,
          'content_block': {...blocks[i], 'input': {}},
        },
        {
          'type': 'content_block_delta',
          'index': i,
          'delta': {'type': 'input_json_delta', 'partial_json': jsonEncode(blocks[i]['input'])},
        },
        {'type': 'content_block_stop', 'index': i},
      ],
    },
  if (end) ...[
    {
      'type': 'message_delta',
      'delta': {'stop_reason': stop, 'stop_sequence': null, 'stop_details': ?stopDetails},
      'usage': {'output_tokens': 50, 'iterations': ?iterations},
    },
    {'type': 'message_stop'},
  ],
];

/// An error answer of the API.
AiHttpResponse apiError(int status, String type, String text, {Map<String, String> headers = const {}, Map<String, dynamic>? details}) => AiHttpResponse(
  status,
  {'content-type': 'application/json', ...headers},
  Stream.value(
    utf8.encode(
      jsonEncode({
        'type': 'error',
        'error': {'type': type, 'message': text, 'details': ?details},
        'request_id': 'req_body',
      }),
    ),
  ),
);

/// A scripted transport: the requests in order, each answered by a step.
class Script {
  Script(this.steps);
  final List<FutureOr<AiHttpResponse> Function(AiHttpRequest r, AiCancel cancel)> steps;
  final requests = <AiHttpRequest>[];
  final bodies = <Map<String, dynamic>>[];
  final cancels = <AiCancel>[];
  int get calls => requests.length;

  Future<AiHttpResponse> call(AiHttpRequest r, AiCancel cancel) async {
    requests.add(r);
    cancels.add(cancel);
    bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
    final n = requests.length - 1;
    return n < steps.length ? steps[n](r, cancel) : sse(message([textBlock('(end of script)')]));
  }

  /// The messages request [n] sent.
  List<Map<String, dynamic>> messages(int n) => [for (final m in bodies[n]['messages'] as List) Map<String, dynamic>.from(m as Map)];
}

/// Timeouts of milliseconds, for the tests of timeouts.
class QuickClaude extends AnthropicClient {
  QuickClaude(AiTransport t, {this.header = const Duration(milliseconds: 60), this.idle = const Duration(milliseconds: 60), super.maxRetries}) : super(apiKey: key, transport: t, sleep: (_) async {});
  final Duration header, idle;
  @override
  Duration headerTimeout(AiModel m) => header;
  @override
  Duration idleTimeout(AiModel m, [AiEffort effort = AiEffort.medium]) => idle;
}

/// The ids of the tool calls in [messages] and of the results answering them.
(List<String>, List<String>) callsAndResults(List<Map<String, dynamic>> messages) => (
  [
    for (final m in messages)
      if (m['role'] == 'assistant' && m['content'] is List)
        for (final b in (m['content'] as List).cast<Map>())
          if (b['type'] == 'tool_use') '${b['id']}',
  ],
  [
    for (final m in messages)
      if (m['role'] == 'user' && m['content'] is List)
        for (final b in (m['content'] as List).cast<Map>())
          if (b['type'] == 'tool_result') '${b['tool_use_id']}',
  ],
);

/// The fixes of the API layer of the AI assistant: a refused request leaves
/// no trace in the conversation, pictures and requests stay within the
/// limits, timeouts and dropped streams are retried per attempt, the output
/// limit, errors named for what they are, the recovery from a thinking
/// block the API no longer accepts, the model's notes between tool calls,
/// unexpected failures, unanswered calls and paused turns, OpenAI's top
/// effort, and the price of every attempt the server ran.
void main() {
  AnthropicClient api(Script s, {int maxRetries = 2}) => AnthropicClient(apiKey: key, transport: s.call, sleep: (_) async {}, maxRetries: maxRetries);

  Map<String, dynamic> user(String s) => AnthropicFormat.user([AiTextPart(s)]);

  final ran = <String>[];
  AgentTool tool(String name, {ToolOutput Function(Map<String, dynamic>)? out}) => FnTool(
    name: name,
    description: 'test tool $name',
    inputSchema: const {
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

  setUp(() {
    ran.clear();
    AiHttpClient.declined.clear();
  });

  group('a request the API refuses', () {
    Future<AgentTurn> run(Script s, List<Map<String, dynamic>> history, {List<AgentTool>? tools}) =>
        AgentLoop(api: api(s), tools: tools ?? [tool('look')]).run(model: AiModel.opus55, system: 's', history: history, user: user('go'), cancel: AiCancel());

    final prior = [
      user('earlier'),
      {
        'role': 'assistant',
        'content': [textBlock('earlier answer')],
      },
    ];

    test('mid-task (400) after rounds of tools ran: they stay in the history (the project may have changed), every call answered', () async {
      final s = Script([
        (_, _) => sse(
          message([
            toolUse('t1', 'look', {'x': 1}),
          ], stop: 'tool_use'),
        ),
        (_, _) => sse(
          message([
            toolUse('t2', 'look', {'x': 2}),
          ], stop: 'tool_use'),
        ),
        (_, _) => apiError(400, 'invalid_request_error', 'messages.6.content.0.image.source: Could not process image'),
      ]);
      final turn = await run(s, prior);
      expect(turn.stop, AgentStop.error);
      expect(turn.error!.kind, AiErrorKind.invalidRequest);
      expect(turn.error!.requestId, 'req_body');
      expect(ran, ['look', 'look'], reason: 'both rounds ran before the refusal');
      expect(s.calls, 3, reason: 'a refused request without pictures to leave out is not retried');
      // what the refused request carried, minus the earlier conversation: the second round ran, so it stays
      expect(jsonEncode(turn.messages), jsonEncode(s.messages(2).sublist(prior.length)));
      final (uses, answers) = callsAndResults(turn.messages);
      expect(uses, ['t1', 't2']);
      expect(answers, uses);
      expect(jsonEncode(turn.messages), contains('look ok {\\"x\\":2}'), reason: 'Try again goes on from there instead of doing it again');
    });

    test('a 413 at the first step keeps nothing, so the question can be sent again', () async {
      final s = Script([(_, _) => apiError(413, 'request_too_large', 'Request exceeds the maximum size')]);
      final turn = await run(s, prior);
      expect(turn.error!.kind, AiErrorKind.tooLarge);
      expect(turn.messages, isEmpty);
    });

    test('too large to send: stopped before it leaves, and sent again without the pictures of the round that made it so', () async {
      final big = 'A' * (AiHttpClient.maxRequestBytes + 1000);
      final s = Script([
        (_, _) => sse(message([toolUse('t1', 'shot', {})], stop: 'tool_use')),
        (_, _) => sse(message([textBlock('Done without the picture.')])),
      ]);
      final turn = await run(
        s,
        prior,
        tools: [
          tool('shot', out: (_) => ToolOutput('a picture', images: [ToolImage('image/jpeg', big)])),
        ],
      );
      expect(s.calls, 2, reason: 'the oversized request never left; the lightened one did');
      expect(turn.stop, AgentStop.done);
      expect(turn.lightened, isTrue);
      final sent = jsonEncode(s.messages(1).last);
      expect(sent.contains(big.substring(0, 100)), isFalse, reason: 'the picture is left out');
      expect(sent, contains('A picture was left out'));
      expect(sent, contains('a picture'), reason: 'the text of the result stays');
      expect(callsAndResults(turn.messages).$1, ['t1'], reason: 'the round that ran stays in the history');
    });

    test('too large even so: the error with the size, and the round that ran kept without its pictures', () async {
      final big = 'A' * (AiHttpClient.maxRequestBytes + 1000);
      final s = Script([
        (_, _) => sse(message([toolUse('t1', 'shot', {})], stop: 'tool_use')),
        (_, _) => apiError(413, 'request_too_large', 'Request exceeds the maximum size'),
      ]);
      final turn = await run(
        s,
        prior,
        tools: [
          tool('shot', out: (_) => ToolOutput('a picture', images: [ToolImage('image/jpeg', big)])),
        ],
      );
      expect(s.calls, 2);
      expect(turn.stop, AgentStop.error);
      expect(turn.error!.kind, AiErrorKind.tooLarge);
      expect(turn.error!.refusedContent, isTrue);
      expect(callsAndResults(turn.messages).$1, ['t1'], reason: 'the tool ran: the history says so, so Try again does not do it twice');
      expect(jsonEncode(turn.messages).contains(big.substring(0, 100)), isFalse);
      // the size check itself, before anything leaves
      expect(
        () => AiHttpClient.checkSize(big),
        throwsA(isA<AiError>().having((e) => e.size, 'size', greaterThan(AiHttpClient.maxRequestBytes)).having((e) => e.limit, 'limit', AiHttpClient.maxRequestBytes)),
      );
    });

    test('a failure of the service, not of the request, keeps everything (every call answered)', () async {
      final s = Script([
        (_, _) => sse(
          message([
            toolUse('t1', 'look', {'x': 1}),
          ], stop: 'tool_use'),
        ),
        for (var k = 0; k < 3; k++) (_, _) => throw AiError(AiErrorKind.network),
      ]);
      final turn = await run(s, prior);
      expect(turn.error!.kind, AiErrorKind.network);
      expect(s.calls, 4, reason: 'two retries');
      expect(turn.messages.map((m) => m['role']), ['user', 'assistant', 'user']);
      final (uses, answers) = callsAndResults(turn.messages);
      expect(answers, uses);
    });
  });

  group('timeouts and dropped streams', () {
    test('a header timeout stops that attempt only, and the request is sent again', () async {
      var aborted = 0;
      final s = Script([
        (_, c) {
          c.onCancel(() => aborted++);
          return Completer<AiHttpResponse>().future;
        },
        (_, _) => sse(message([textBlock('hello')])),
      ]);
      final task = AiCancel();
      final retries = <AiErrorKind>[];
      final r = await QuickClaude(s.call).send(
        AiRequest(model: AiModel.opus55, system: 's', history: [user('q')]),
        cancel: task,
        onRetry: (_, _, e) => retries.add(e.kind),
      );
      expect(r.text, 'hello');
      expect(retries, [AiErrorKind.timeout]);
      expect(task.cancelled, isFalse, reason: 'the task goes on');
      expect(s.cancels.first.cancelled, isTrue, reason: 'the timed-out attempt is stopped');
      expect(aborted, 1);
      expect(s.cancels.last.cancelled, isFalse);
    });

    test('no data for the idle timeout aborts the exchange (not just the reading) and tries again', () async {
      var aborted = false;
      final s = Script([
        (_, c) {
          final body = StreamController<List<int>>();
          body.add(utf8.encode('event: message_start\ndata: ${jsonEncode(message(const [])[0])}\n\n'));
          c.onCancel(() {
            aborted = true;
            body.close();
          });
          return AiHttpResponse(200, {'content-type': 'text/event-stream'}, body.stream);
        },
        (_, _) => sse(message([textBlock('again')])),
      ]);
      final retries = <AiErrorKind>[];
      final r = await QuickClaude(s.call).send(
        AiRequest(model: AiModel.opus55, system: 's', history: [user('q')]),
        cancel: AiCancel(),
        onRetry: (_, _, e) => retries.add(e.kind),
      );
      expect(r.text, 'again');
      expect(aborted, isTrue);
      expect(retries, [AiErrorKind.timeout]);
    });

    test('a stream that ends early is sent again before any text shows; once text showed it is not', () async {
      final s = Script([
        (_, _) => sse(message([thinking('', 'sig')], end: false)),
        (_, _) => sse(message([textBlock('whole')])),
      ]);
      final r = await api(s).send(
        AiRequest(model: AiModel.opus55, system: 's', history: [user('q')]),
        cancel: AiCancel(),
      );
      expect(r.text, 'whole');
      expect(s.calls, 2);

      final cut = Script([
        (_, _) => sse(message([textBlock('half an ans')], end: false)),
        (_, _) => sse(message([textBlock('never')])),
      ]);
      final shown = <String>[];
      await expectLater(
        api(cut).send(
          AiRequest(model: AiModel.opus55, system: 's', history: [user('q')]),
          cancel: AiCancel(),
          listener: AiStreamListener(onText: shown.add),
        ),
        throwsA(isA<AiError>().having((e) => e.kind, 'kind', AiErrorKind.interrupted).having((e) => e.partial, 'partial', isTrue)),
      );
      expect(cut.calls, 1);
      expect(shown, ['half an ans']);
    });

    test('the wait for the answer starts once the body is up, where the transport tells', () async {
      // the answer comes 300 ms after the request; the body is up at 150 ms
      Future<AiHttpResponse> slow(AiHttpRequest r, AiCancel c, {required bool tells}) async {
        if (tells) unawaited(Future<void>.delayed(const Duration(milliseconds: 150), r.onSent));
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return sse(message([textBlock('in time')]));
      }

      final told = Script([(r, c) => slow(r, c, tells: true)]);
      final r = await QuickClaude(told.call, header: const Duration(milliseconds: 200), maxRetries: 0).send(
        AiRequest(model: AiModel.opus55, system: 's', history: [user('q')]),
        cancel: AiCancel(),
      );
      expect(r.text, 'in time');
      final silent = Script([(r, c) => slow(r, c, tells: false)]);
      await expectLater(
        QuickClaude(silent.call, header: const Duration(milliseconds: 200), maxRetries: 0).send(
          AiRequest(model: AiModel.opus55, system: 's', history: [user('q')]),
          cancel: AiCancel(),
        ),
        throwsA(isA<AiError>().having((e) => e.kind, 'kind', AiErrorKind.timeout)),
      );
      expect(AiHttpClient.uploadAllowance(1280000), const Duration(seconds: 10), reason: 'a large body may take its time to go up');
    });

    test('timeouts: longer at the two highest efforts; backoff per kind; a long retry-after is the error', () {
      final c = AnthropicClient(apiKey: key, transport: (_, _) => throw StateError('no'));
      expect(c.idleTimeout(AiModel.opus55), const Duration(seconds: 180));
      expect(c.idleTimeout(AiModel.opus55, AiEffort.high), const Duration(seconds: 180));
      expect(c.idleTimeout(AiModel.opus55, AiEffort.xhigh), const Duration(seconds: 360));
      expect(c.idleTimeout(AiModel.fable51, AiEffort.max), const Duration(seconds: 1200));
      expect(AiError(AiErrorKind.timeout).retryable, isTrue);
      expect(AiError(AiErrorKind.interrupted).retryable, isTrue);
      expect(AiError(AiErrorKind.credit).retryable, isFalse);
      expect(AiHttpClient.backoff(AiError(AiErrorKind.timeout), 1), const Duration(seconds: 2));
      expect(AiHttpClient.backoff(AiError(AiErrorKind.rateLimit, retryAfter: const Duration(seconds: 31)), 0), isNull);
    });

    test('a token per attempt: cancelled with the task, unlinked once the attempt is over', () {
      final task = AiCancel();
      final a = task.child();
      final b = task.child()..release();
      var hooked = 0;
      final forget = task.onCancel(() => hooked += 10);
      task.onCancel(() => hooked++);
      forget();
      task.cancel();
      expect(a.cancelled, isTrue);
      expect(b.cancelled, isFalse);
      expect(hooked, 1, reason: 'a forgotten hook does not run');
      var late = false;
      task.onCancel(() => late = true);
      expect(late, isTrue, reason: 'at once when already cancelled');
    });
  });

  group('the request', () {
    test('every Claude model asks for its whole output limit (128 000, streamed); OpenAI keeps its own', () async {
      for (final m in [AiModel.fable51, AiModel.opus55, AiModel.sonnet55, AiModel.haiku55]) {
        final s = Script([
          (_, _) => sse(message([textBlock('ok')], model: m.id)),
        ]);
        await api(s).send(
          AiRequest(model: m, system: 's', history: [user('q')]),
          cancel: AiCancel(),
        );
        expect(s.bodies.single['max_tokens'], 128000, reason: m.id);
        expect(s.bodies.single['stream'], isTrue);
      }
      final asked = Script([
        (_, _) => sse(message([textBlock('ok')])),
      ]);
      await api(asked).send(
        AiRequest(model: AiModel.opus55, system: 's', history: [user('q')], maxTokens: 4096),
        cancel: AiCancel(),
      );
      expect(asked.bodies.single['max_tokens'], 4096);
      expect(AiModel.gpt6Astra.maxOutput, 64000);
    });

    test('UTF-8 size without encoding, and the size check before sending', () {
      const s = 'aé€😀';
      expect(AiHttpClient.utf8Length(s), utf8.encode(s).length);
      expect(AiHttpClient.utf8Length('ação ${'x' * 50} 中文'), utf8.encode('ação ${'x' * 50} 中文').length);
      AiHttpClient.checkSize('é' * 100, limit: 200);
      expect(
        () => AiHttpClient.checkSize('é' * 101, limit: 200),
        throwsA(isA<AiError>().having((e) => e.kind, 'kind', AiErrorKind.tooLarge).having((e) => e.size, 'size', 202).having((e) => e.retryable, 'retryable', isFalse)),
      );
    });

    test('OpenAI: "maximum" effort goes as xhigh, its top value; the others as they are', () async {
      for (final e in AiEffort.values) {
        final f = FakeOpenAi([(_) => OpenAiReply.text('ok')]);
        await OpenAiClient(apiKey: 'sk-proj-test-0000', transport: f.call).send(
          AiRequest(
            model: AiModel.gpt6Astra,
            system: 's',
            history: [
              OpenAiFormat.user([AiTextPart('q')]),
            ],
            effort: e,
          ),
          cancel: AiCancel(),
        );
        expect((f.bodies.single['reasoning'] as Map)['effort'], e == AiEffort.max ? 'xhigh' : e.name);
      }
    });

    test('the task budget for a spending cap: half the cap at the output price', () {
      expect(AiModel.opus55.taskBudgetFor(2), 50000);
      expect(AiModel.haiku55.taskBudgetFor(1), 1000000);
      expect(AiModel.fable51.taskBudgetFor(5, outputShare: 1), 100000);
    });
  });

  group('errors named for what they are', () {
    Future<(AiError, int)> fail(FutureOr<AiHttpResponse> Function(AiHttpRequest, AiCancel) step, {AiModel model = AiModel.opus55}) async {
      final s = Script([
        step,
        (_, _) => sse(message([textBlock('retried')])),
      ]);
      try {
        await api(s).send(
          AiRequest(model: model, system: 's', history: [user('q')]),
          cancel: AiCancel(),
        );
      } on AiError catch (e) {
        return (e, s.calls);
      }
      throw StateError('no error');
    }

    test('no credit, spending limits, a prompt longer than the window, a long retry-after, a gateway timeout', () async {
      var (e, n) = await fail(
        (_, _) => apiError(400, 'invalid_request_error', 'Your credit balance is too low to access the Anthropic API. Please go to Plans & Billing to upgrade or purchase credits.'),
      );
      expect((e.kind, n), (AiErrorKind.credit, 1));
      (e, n) = await fail(
        (_, _) => apiError(
          429,
          'rate_limit_error',
          'You have reached your API usage limits: your organization has crossed its monthly API usage threshold. You will regain access on 2026-11-01 at 00:00 UTC.',
          details: {'error_code': 'enforced_spend_limit_reached'},
        ),
      );
      expect((e.kind, n), (AiErrorKind.spendLimit, 1), reason: 'retrying fails until access resumes');
      (e, n) = await fail((_, _) => apiError(400, 'invalid_request_error', 'You have reached your specified workspace API usage limits. You will regain access on 2026-11-01 at 00:00 UTC.'));
      expect((e.kind, n), (AiErrorKind.spendLimit, 1));
      (e, n) = await fail((_, _) => apiError(400, 'invalid_request_error', 'prompt is too long: 1050000 tokens > 1000000 maximum'));
      expect((e.kind, n), (AiErrorKind.contextWindow, 1));
      expect(e.refusedContent, isTrue);
      (e, n) = await fail((_, _) => apiError(429, 'rate_limit_error', 'Number of request tokens has exceeded your per-minute rate limit', headers: {'retry-after': '120'}));
      expect((e.kind, n), (AiErrorKind.rateLimit, 1));
      expect(e.retryAfter, const Duration(seconds: 120), reason: 'the wait goes to the user');
      final s = Script([
        (_, _) => apiError(504, 'timeout_error', 'Request timed out'),
        (_, _) => sse(message([textBlock('second')])),
      ]);
      final r = await api(s).send(
        AiRequest(model: AiModel.opus55, system: 's', history: [user('q')]),
        cancel: AiCancel(),
      );
      expect(r.text, 'second');
    });

    test('the request id: from the error body, and from the header for an error in the stream', () async {
      final busy = Script([for (var k = 0; k < 3; k++) (_, _) => apiError(500, 'api_error', 'Internal server error')]);
      await expectLater(
        api(busy).send(
          AiRequest(model: AiModel.opus55, system: 's', history: [user('q')]),
          cancel: AiCancel(),
        ),
        throwsA(isA<AiError>().having((e) => e.kind, 'kind', AiErrorKind.server).having((e) => e.requestId, 'requestId', 'req_body')),
      );
      final s = Script([
        (_, _) => sse(
          [
            message(const [])[0],
            {
              'type': 'error',
              'error': {'type': 'invalid_request_error', 'message': 'bad things'},
            },
          ],
          headers: {'request-id': 'req_stream'},
        ),
      ]);
      await expectLater(
        api(s).send(
          AiRequest(model: AiModel.opus55, system: 's', history: [user('q')]),
          cancel: AiCancel(),
        ),
        throwsA(isA<AiError>().having((e) => e.requestId, 'requestId', 'req_stream')),
      );
    });

    test('a full context window is not "cut at the length limit"; a refusal says which model to try', () async {
      final full = Script([
        (_, _) => sse(message([textBlock('A partial answer')], stop: 'model_context_window_exceeded')),
      ]);
      final t = await AgentLoop(api: api(full), tools: const []).run(model: AiModel.opus55, system: 's', history: const [], user: user('q'), cancel: AiCancel());
      expect(t.stop, AgentStop.error);
      expect(t.error!.kind, AiErrorKind.contextWindow);
      expect(t.messages.length, 2, reason: 'what the model wrote stays');
      final cut = Script([
        (_, _) => sse(
          message([
            toolUse('t1', 'look', {'x': 1}),
          ], stop: 'model_context_window_exceeded'),
        ),
      ]);
      final t2 = await AgentLoop(api: api(cut), tools: [tool('look')]).run(model: AiModel.opus55, system: 's', history: const [], user: user('q'), cancel: AiCancel());
      expect(t2.error!.kind, AiErrorKind.contextWindow);
      expect(ran, isEmpty, reason: 'a call cut by the full window is not run');
      expect(t2.messages, isEmpty);

      final declined = Script([
        (_, _) => sse(message(const [], stop: 'refusal', stopDetails: {'type': 'refusal', 'category': 'cyber', 'explanation': 'Declined by a classifier.', 'recommended_model': 'claude-opus-4-8'})),
      ]);
      final t3 = await AgentLoop(api: api(declined), tools: const []).run(model: AiModel.opus55, system: 's', history: const [], user: user('q'), cancel: AiCancel());
      expect(t3.error!.kind, AiErrorKind.refusal);
      expect(t3.error!.category, 'cyber');
      expect(t3.error!.recommendedModel, 'claude-opus-4-8');
      expect(AiModel.served('claude-opus-4-8', AiModel.opus55).label, 'Claude Opus 4.8');
    });
  });

  group('a thinking block the API no longer accepts', () {
    String bound(int i) =>
        'messages.$i.content.0: Invalid `signature` in `thinking` block. The block is bound to a different conversation. Remove the block, or set `thinking.block_binding.prefix_mismatch_behavior` to "drop_block". That setting requires the `thinking-binding-controls-2026-08-01` value in the `anthropic-beta` header.';
    List<Map<String, dynamic>> conversation() => [
      user('first'),
      {
        'role': 'assistant',
        'content': [thinking('', 'sigA'), textBlock('answer one')],
      },
      user('second'),
      {
        'role': 'assistant',
        'content': [thinking('', 'sigB'), textBlock('answer two')],
      },
    ];
    List<String> types(Map<String, dynamic> m) => [for (final b in (m['content'] as List).cast<Map>()) '${b['type']}'];

    test('is taken out with every thinking block after it, the request sent once more, and the stripped history kept', () async {
      final history = conversation();
      final before = jsonEncode(history);
      final s = Script([
        (_, _) => apiError(400, 'invalid_request_error', bound(1)),
        (_, _) => sse(message([thinking('', 'sigC'), textBlock('fine')])),
      ]);
      final turn = await AgentLoop(api: api(s), tools: const []).run(model: AiModel.opus55, system: 's', history: history, user: user('third'), cancel: AiCancel());
      expect(turn.stop, AgentStop.done);
      expect(s.calls, 2);
      final sent = s.messages(1);
      expect(types(sent[1]), ['text'], reason: 'the named block goes');
      expect(types(sent[3]), ['text'], reason: 'and every thinking block after it');
      expect(turn.history, isNotNull);
      expect(turn.history!.length, history.length, reason: 'the same entries in the same places');
      expect(types(turn.history![1]), ['text']);
      expect(jsonEncode(history), before, reason: 'the caller\'s list is not changed');
      expect(types(turn.messages.last), ['thinking', 'text'], reason: 'the new answer keeps its own');
    });

    test('a block later on goes with the ones after it only; positions count from the last compaction', () async {
      final s = Script([
        (_, _) => apiError(400, 'invalid_request_error', bound(3)),
        (_, _) => sse(message([textBlock('fine')])),
      ]);
      await api(s).send(
        AiRequest(model: AiModel.opus55, system: 's', history: [...conversation(), user('third')]),
        cancel: AiCancel(),
      );
      expect(types(s.messages(1)[1]), ['thinking', 'text'], reason: 'before the named block: kept');
      expect(types(s.messages(1)[3]), ['text']);

      final compacted = [
        user('long ago'),
        {
          'role': 'assistant',
          'content': [
            {'type': 'compaction', 'content': 'Summary.'},
          ],
        },
        user('then'),
        {
          'role': 'assistant',
          'content': [thinking('', 'sigA'), textBlock('answer')],
        },
        user('now'),
      ];
      final c = Script([
        (_, _) => apiError(400, 'invalid_request_error', bound(2)),
        (_, _) => sse(message([textBlock('fine')])),
      ]);
      final r = await api(c).send(
        AiRequest(model: AiModel.opus55, system: 's', history: compacted),
        cancel: AiCancel(),
      );
      expect(c.messages(0).length, 4, reason: 'the request starts at the compaction');
      expect(types(c.messages(1)[2]), ['text'], reason: 'messages.2 of the request is entry 3 of the history');
      expect(types(r.history![3]), ['text']);
    });

    test('should that not do, every thinking block goes, once more; another rejection is left alone', () async {
      final s = Script([
        (_, _) => apiError(400, 'invalid_request_error', bound(3)),
        (_, _) => apiError(400, 'invalid_request_error', bound(1)),
        (_, _) => sse(message([textBlock('fine')])),
      ]);
      final r = await api(s).send(
        AiRequest(model: AiModel.opus55, system: 's', history: [...conversation(), user('third')]),
        cancel: AiCancel(),
      );
      expect(s.calls, 3);
      expect(r.history!.where((m) => m['role'] == 'assistant').map(types), [
        ['text'],
        ['text'],
      ]);

      final other = Script([(_, _) => apiError(400, 'invalid_request_error', 'messages.1.content.0: something else')]);
      await expectLater(
        api(other).send(
          AiRequest(model: AiModel.opus55, system: 's', history: [...conversation(), user('third')]),
          cancel: AiCancel(),
        ),
        throwsA(isA<AiError>().having((e) => e.kind, 'kind', AiErrorKind.invalidRequest)),
      );
      expect(other.calls, 1);
      expect(stripThinking(conversation(), from: (3, 0))[1], conversation()[1]);
    });
  });

  group('the model\'s notes between tool calls', () {
    test('Claude Opus 5.5, Sonnet 5.5 and Fable 5.1 ask for them; Haiku 5.5 does not', () async {
      for (final m in [AiModel.opus55, AiModel.sonnet55, AiModel.fable51, AiModel.haiku55]) {
        final s = Script([
          (_, _) => sse(message([textBlock('ok')], model: m.id)),
        ]);
        await api(s).send(
          AiRequest(model: m, system: 's', history: [user('q')]),
          cancel: AiCancel(),
        );
        final notes = m != AiModel.haiku55;
        const binding = {'prefix_mismatch_behavior': 'drop_block'};
        expect(s.bodies.single['thinking'], notes ? {'type': 'adaptive', 'display': 'updates', 'block_binding': binding} : {'type': 'adaptive', 'block_binding': binding}, reason: m.id);
        expect((s.requests.single.headers['anthropic-beta'] ?? '').contains(AnthropicClient.displayBeta), notes, reason: m.id);
      }
    });

    test('turned down (the value or the beta), the request goes again without them, as before', () async {
      for (final (m, why) in [
        (AiModel.opus55, "thinking.display: Input should be 'summarized' or 'omitted'"),
        (AiModel.fable51, 'Unexpected value(s) `thinking-display-updates-2026-08-18` for the `anthropic-beta` header.'),
      ]) {
        final s = Script([
          (_, _) => apiError(400, 'invalid_request_error', why),
          (_, _) => sse(message([textBlock('ok')], model: m.id)),
        ]);
        final r = await api(s).send(
          AiRequest(model: m, system: 's', history: [user('q')]),
          cancel: AiCancel(),
        );
        expect(r.text, 'ok');
        expect(s.calls, 2);
        expect(s.bodies[1]['thinking'], {
          'type': 'adaptive',
          'block_binding': {'prefix_mismatch_behavior': 'drop_block'},
        }, reason: 'Claude Fable 5.1 keeps an explicit adaptive setting for the binding only');
        expect((s.requests[1].headers['anthropic-beta'] ?? '').contains('thinking-display'), isFalse);
        expect(AiHttpClient.declined, contains('${m.id}:display'));
      }
      // a beta the account lacks drops its own field
      final s = Script([
        (_, _) => apiError(400, 'invalid_request_error', 'Unexpected value(s) `task-budgets-2026-03-13` for the `anthropic-beta` header.'),
        (_, _) => sse(message([textBlock('ok')])),
      ]);
      await api(s).send(
        AiRequest(model: AiModel.sonnet55, system: 's', history: [user('q')], taskBudget: 50000),
        cancel: AiCancel(),
      );
      expect((s.bodies[1]['output_config'] as Map).containsKey('task_budget'), isFalse);
      expect(s.bodies[1]['thinking'], {
        'type': 'adaptive',
        'display': 'updates',
        'block_binding': {'prefix_mismatch_behavior': 'drop_block'},
      });
    });

    test('a note streams as a status, stays with the tool it introduced, and goes back unchanged', () async {
      const note = 'Found the mainline; checking the laterals next.';
      final s = Script([
        (_, _) => sse(
          message([
            thinking('', 'sig0'),
            thinking(note, 'sig1'),
            toolUse('t1', 'look', {'x': 1}),
          ], stop: 'tool_use'),
        ),
        (_, _) => sse(message([thinking(AnthropicClient.interruptedNote, 'sig2'), textBlock('Done.')])),
      ]);
      final statuses = <AgentStatus>[];
      final turn = await AgentLoop(api: api(s), tools: [tool('look')]).run(
        model: AiModel.opus55,
        system: 's',
        history: const [],
        user: user('go'),
        cancel: AiCancel(),
        events: AgentEvents(onStatus: statuses.add),
      );
      expect(turn.text, 'Done.', reason: 'a note is not text of the answer');
      final updates = statuses.where((x) => x.kind == 'update').map((x) => x.note).toList();
      expect(updates, [note], reason: 'empty blocks and the stand-in for unfinished work are no notes');
      expect(statuses.firstWhere((x) => x.kind == 'tool').note, note);
      expect(s.messages(1)[1]['content'], [
        thinking('', 'sig0'),
        thinking(note, 'sig1'),
        toolUse('t1', 'look', {'x': 1}),
      ]);
    });
  });

  group('failures of this program and unanswered calls', () {
    test('malformed events are skipped; a failure while reading is an error, not a crash', () async {
      final s = Script([
        (_, _) => sse([
          message(const [])[0],
          {'type': 'content_block_start', 'index': 'zero', 'content_block': null},
          {
            'type': 'content_block_delta',
            'delta': {'type': 'text_delta', 'text': 'x'},
          },
          {'type': 'content_block_stop', 'index': 7},
          ...message([textBlock('still fine')]).sublist(1),
        ]),
      ]);
      final r = await api(s).send(
        AiRequest(model: AiModel.opus55, system: 's', history: [user('q')]),
        cancel: AiCancel(),
      );
      expect(r.text, 'still fine');

      final odd = [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': DateTime(2026)},
          ],
        },
      ];
      await expectLater(
        api(Script([])).send(
          AiRequest(model: AiModel.opus55, system: 's', history: odd),
          cancel: AiCancel(),
        ),
        throwsA(isA<AiError>().having((e) => e.kind, 'kind', AiErrorKind.unexpected)),
      );
    });

    test('an exception in the middle of a round ends the turn as an error with every call answered', () async {
      final s = Script([
        (_, _) => sse(
          message([
            toolUse('t1', 'look', {'x': 1}),
            toolUse('t2', 'look', {'x': 2}),
          ], stop: 'tool_use'),
        ),
      ]);
      var n = 0;
      final turn = await AgentLoop(api: api(s), tools: [tool('look')]).run(
        model: AiModel.opus55,
        system: 's',
        history: const [],
        user: user('go'),
        cancel: AiCancel(),
        events: AgentEvents(
          onCall: (c) {
            if (c.state == ToolCallState.running && ++n == 2) throw StateError('a broken callback');
          },
        ),
      );
      expect(turn.stop, AgentStop.error);
      expect(turn.error!.kind, AiErrorKind.unexpected);
      expect(turn.error!.message, 'StateError');
      final (uses, answers) = callsAndResults(turn.messages);
      expect(uses, ['t1', 't2']);
      expect(answers, uses);
      final results = (turn.messages.last['content'] as List).cast<Map>();
      expect(results.first['content'], contains('look ok'), reason: 'the result made before the failure stays');
      expect(results.last['content'], contains('Not run'));

      final throwing = Script([
        (_, _) => sse(
          message([
            toolUse('t1', 'look', {'x': 1}),
          ], stop: 'tool_use'),
        ),
        (_, _) => sse(message([textBlock('words')])),
      ]);
      final t2 = await AgentLoop(api: api(throwing), tools: [tool('look')]).run(
        model: AiModel.opus55,
        system: 's',
        history: const [],
        user: user('go'),
        cancel: AiCancel(),
        events: AgentEvents(onText: (_) => throw StateError('the panel broke')),
      );
      expect(t2.error!.kind, AiErrorKind.unexpected);
      expect(t2.messages.map((m) => m['role']), ['user', 'assistant', 'user'], reason: 'the valid part of the task stays');
    });

    test('tool calls in an answer that did not stop for them get "not run" results', () async {
      final s = Script([
        (_, _) => sse(
          message([
            textBlock('I will look.'),
            toolUse('t1', 'look', {'x': 1}),
          ], stop: 'end_turn'),
        ),
      ]);
      final turn = await AgentLoop(api: api(s), tools: [tool('look')]).run(model: AiModel.opus55, system: 's', history: const [], user: user('go'), cancel: AiCancel());
      expect(turn.stop, AgentStop.done);
      expect(ran, isEmpty);
      expect(turn.messages.map((m) => m['role']), ['user', 'assistant', 'user']);
      final r = (turn.messages.last['content'] as List).cast<Map>().single;
      expect(r['tool_use_id'], 't1');
      expect(r['is_error'], isTrue);
      expect(r['content'], startsWith('Not run'));
    });

    test('a paused turn goes again as it is, without a new message', () async {
      final s = Script([
        (_, _) => sse(message([textBlock('Working on it…')], stop: 'pause_turn')),
        (_, _) => sse(message([textBlock(' Done.')])),
      ]);
      final turn = await AgentLoop(api: api(s), tools: const []).run(model: AiModel.opus55, system: 's', history: const [], user: user('go'), cancel: AiCancel());
      expect(turn.stop, AgentStop.done);
      expect(turn.steps, 2);
      expect(s.messages(1).map((m) => m['role']), ['user', 'assistant'], reason: 'the paused answer last, no new user message');
      expect(turn.messages.map((m) => m['role']), ['user', 'assistant', 'assistant']);
    });
  });

  group('the price of every attempt', () {
    test('an attempt declined before a fallback answered is priced at the model asked for, the answer at the fallback model', () async {
      final s = Script([
        (_, _) => sse(
          message(
            [textBlock('ok')],
            model: 'claude-opus-5',
            iterations: [
              {'type': 'message', 'input_tokens': 5000, 'output_tokens': 0},
              {'type': 'fallback_message', 'model': 'claude-opus-5', 'input_tokens': 1000, 'output_tokens': 50},
            ],
          ),
        ),
      ]);
      final turn = await AgentLoop(api: api(s), tools: const []).run(model: AiModel.opus55, system: 's', history: const [], user: user('q'), cancel: AiCancel());
      // 5000 in at Claude Opus 5.5; 1000 in, 200 written, 300 read, 50 out at Claude Opus 5
      expect(turn.cost, closeTo((5000 * 4 + 1000 * 5 + 200 * 6.25 + 300 * 0.5 + 50 * 25) / 1e6, 1e-12));
      expect(turn.usage.input, 6000);
      expect(turn.usage.output, 50);
    });

    test('without a model of its own, the serving attempt is the message\'s model; a compaction is the requested one\'s', () async {
      final s = Script([
        (_, _) => sse(
          message(
            [textBlock('ok')],
            model: 'claude-opus-4-8',
            iterations: [
              {'type': 'compaction', 'input_tokens': 100000, 'output_tokens': 2000},
              {'type': 'message', 'input_tokens': 3000, 'output_tokens': 0},
              {'type': 'fallback_message', 'input_tokens': 1000, 'output_tokens': 50},
            ],
          ),
        ),
      ]);
      final r = await api(s).send(
        AiRequest(model: AiModel.sonnet55, system: 's', history: [user('q')]),
        cancel: AiCancel(),
      );
      expect(r.billed.map((b) => b.$1), ['claude-sonnet-5-5', 'claude-sonnet-5-5', 'claude-opus-4-8']);
      expect(r.cost(AiModel.sonnet55), closeTo((100000 * 2 + 2000 * 10 + 3000 * 2 + 1000 * 5 + 200 * 6.25 + 300 * 0.5 + 50 * 25) / 1e6, 1e-12));
    });
  });
}
