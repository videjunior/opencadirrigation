import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/ai/claude_api.dart';
import 'package:opencadirrigation/core/ai/llm_formats.dart';
import 'package:opencadirrigation/core/ai/openai_api.dart';

import '../support/fake_claude.dart';

/// The fixes of the 1 November 2026 review of the assistant's core: the
/// spending cap and the attempts that broke off (IA-07), rounds that ran
/// kept in the history (IA-02), the input fixed when a call is planned
/// (IA-05), the one-hour cache and the keep-alive (IA-09), the stepped
/// pruning of OpenAI pictures (IA-10), compaction below Haiku's price step
/// (IA-16) and with instructions (IA-17), effort messages (IA-18), the
/// model that answered (IA-19), the thinking binding (IA-21) and the cache
/// breakpoints of long answers (IA-22).
void main() {
  const key = 'sk-ant-api03-TEST-KEY-0000';
  AnthropicClient api(AiTransport t) => AnthropicClient(apiKey: key, transport: t, sleep: (_) async {});
  Map<String, dynamic> user(String s) => AnthropicFormat.user([AiTextPart(s)]);

  setUp(AiHttpClient.declined.clear);

  /// A tool that records what it ran with.
  final ran = <Map<String, dynamic>>[];
  FnTool tool(String name, {ToolEffect effect = ToolEffect.read, Map<String, dynamic> Function(Map<String, dynamic>)? binder, bool Function(Map<String, dynamic>)? confirm}) => FnTool(
    name: name,
    description: 'test tool $name',
    inputSchema: {'type': 'object', 'properties': <String, Object?>{}, 'additionalProperties': true},
    effect: effect,
    binder: binder,
    confirm: confirm,
    summary: (i) => '$name ${jsonEncode(i)}',
    handler: (i) async {
      ran.add(i);
      return ToolOutput('$name ok');
    },
  );
  setUp(ran.clear);

  group('the spending cap (IA-07)', () {
    test('each request may write only what is left of the cap buys, at least 16 000 tokens', () async {
      final f = FakeClaude([
        (_) => FakeReply.tools([('look', <String, dynamic>{})], model: 'claude-fable-5-2'),
        (_) => FakeReply.text('done', model: 'claude-fable-5-2'),
      ]);
      await AgentLoop(api: api(f.call), tools: [tool('look')]).run(model: AiModel.fable52, system: 's', history: const [], user: user('go'), costCap: 2.0, cancel: AiCancel());
      expect(f.bodies.first['max_tokens'], 50000, reason: 'US\$ 2 buys 50 000 output tokens of Claude Fable 5.2 at US\$ 40 per million');
      final f2 = FakeClaude([(_) => FakeReply.text('done')]);
      await AgentLoop(api: api(f2.call), tools: const []).run(model: AiModel.opus55, system: 's', history: const [], user: user('go'), costCap: 0.05, cancel: AiCancel());
      expect(f2.bodies.single['max_tokens'], AgentLoop.minCappedOutput, reason: 'never below the floor');
      final f3 = FakeClaude([(_) => FakeReply.text('done')]);
      await AgentLoop(api: api(f3.call), tools: const []).run(model: AiModel.opus55, system: 's', history: const [], user: user('go'), cancel: AiCancel());
      expect(f3.bodies.single['max_tokens'], 128000, reason: 'no cap: the model\'s whole output limit');
    });

    test('an answer the cap\'s limit cut ends the task at the cap (Continue), not as an error', () async {
      final f = FakeClaude([
        (_) => FakeReply.tools([('look', <String, dynamic>{})], stopReason: 'max_tokens'),
      ]);
      final t = await AgentLoop(api: api(f.call), tools: [tool('look')]).run(model: AiModel.opus55, system: 's', history: const [], user: user('go'), costCap: 1.0, cancel: AiCancel());
      expect(t.stop, AgentStop.budget);
      expect(ran, isEmpty, reason: 'a call cut by the length limit is not run');
    });

    test('the input of an attempt that broke off is counted in the meter and the cap', () async {
      var n = 0;
      Future<AiHttpResponse> transport(AiHttpRequest r, AiCancel c) async {
        n++;
        // the first attempt: the message starts (its input is billed), then the stream ends early
        final start = {
          'type': 'message_start',
          'message': {
            'model': 'claude-opus-5-5',
            'usage': {'input_tokens': 5000, 'cache_read_input_tokens': 20000, 'cache_creation_input_tokens': 0, 'output_tokens': 1},
          },
        };
        final events = n == 1
            ? [start]
            : [
                start,
                {
                  'type': 'content_block_start',
                  'index': 0,
                  'content_block': {'type': 'text', 'text': 'ok'},
                },
                {'type': 'content_block_stop', 'index': 0},
                {
                  'type': 'message_delta',
                  'delta': {'stop_reason': 'end_turn'},
                  'usage': {'output_tokens': 10},
                },
                {'type': 'message_stop'},
              ];
        final text = events.map((e) => 'event: ${e['type']}\ndata: ${jsonEncode(e)}\n\n').join();
        return AiHttpResponse(200, {'content-type': 'text/event-stream'}, Stream.value(utf8.encode(text)));
      }

      final t = await AgentLoop(api: api(transport), tools: const []).run(model: AiModel.opus55, system: 's', history: const [], user: user('go'), cancel: AiCancel());
      expect(n, 2, reason: 'the stream that ended early was tried again');
      expect(t.stop, AgentStop.done);
      expect(t.usage.input, 10000, reason: 'both attempts\' input, the broken one included');
      expect(t.usage.cacheRead, 40000);
      expect(t.cost, closeTo(const AiUsage(input: 10000, cacheRead: 40000, output: 11).cost(AiModel.opus55), 1e-9));
    });

    test('an attempt cancelled after it started still counts what it was billed', () async {
      final cancel = AiCancel();
      Future<AiHttpResponse> transport(AiHttpRequest r, AiCancel c) async {
        final body = StreamController<List<int>>();
        c.onCancel(body.close);
        body.add(
          utf8.encode(
            'event: message_start\ndata: ${jsonEncode({
              'type': 'message_start',
              'message': {
                'model': 'claude-opus-5-5',
                'usage': {'input_tokens': 3000, 'output_tokens': 1},
              },
            })}\n\n',
          ),
        );
        Timer(const Duration(milliseconds: 20), cancel.cancel);
        return AiHttpResponse(200, {'content-type': 'text/event-stream'}, body.stream);
      }

      final t = await AgentLoop(api: api(transport), tools: const []).run(model: AiModel.opus55, system: 's', history: const [], user: user('go'), cancel: cancel);
      expect(t.stop, AgentStop.cancelled);
      expect(t.usage.input, 3000);
      expect(t.cost, greaterThan(0));
    });
  });

  group('a round that ran stays in the history (IA-02)', () {
    test('the turn so far is handed out after each change, every call answered', () async {
      final f = FakeClaude([
        (_) => FakeReply.tools([('make', <String, dynamic>{}), ('look', <String, dynamic>{})]),
        (_) => FakeReply.text('done'),
      ]);
      final saved = <List<Map<String, dynamic>>>[];
      await AgentLoop(
        api: api(f.call),
        tools: [
          tool('make', effect: ToolEffect.write),
          tool('look'),
        ],
      ).run(
        model: AiModel.opus55,
        system: 's',
        history: const [],
        user: user('go'),
        permission: AgentPermission.auto,
        cancel: AiCancel(),
        events: AgentEvents(
          onProgress: (m, {required changed}) {
            if (changed) saved.add(m);
          },
        ),
      );
      expect(saved, isNotEmpty);
      final first = saved.first;
      // after "make" ran: the round is closed with "look" as not run, so the copy is one the API takes
      final results = (first.last['content'] as List).cast<Map>();
      expect(results.map((r) => r['type']), ['tool_result', 'tool_result']);
      expect('${results[0]['content']}', 'make ok');
      expect('${results[1]['content']}', contains('Not run'));
    });
  });

  group('the call runs with what the card showed (IA-05)', () {
    test('the bound input is the call\'s: described, confirmed, approved and run', () async {
      var selection = ['a', 'b'];
      final described = <Map<String, dynamic>>[];
      final t = FnTool(
        name: 'erase',
        description: 'erases the selection',
        inputSchema: {'type': 'object', 'properties': <String, Object?>{}, 'additionalProperties': true},
        effect: ToolEffect.write,
        binder: (i) => {
          ...i,
          'ids': [...selection],
        },
        summary: (i) {
          described.add(i);
          return 'erase ${i['ids']}';
        },
        handler: (i) async {
          ran.add(i);
          return const ToolOutput('erased');
        },
      );
      final f = FakeClaude([
        (_) => FakeReply.tools([('erase', <String, dynamic>{})]),
        (_) => FakeReply.text('done'),
      ]);
      AgentToolCall? asked;
      await AgentLoop(api: api(f.call), tools: [t]).run(
        model: AiModel.opus55,
        system: 's',
        history: const [],
        user: user('go'),
        permission: AgentPermission.ask,
        cancel: AiCancel(),
        events: AgentEvents(
          approve: (call) async {
            asked = call;
            // the user clicks other items while the card waits
            selection = ['z'];
            return Approval.apply;
          },
        ),
      );
      expect(asked!.input['ids'], ['a', 'b'], reason: 'the card shows the ids');
      expect(asked!.summary, 'erase [a, b]');
      expect(ran.single['ids'], ['a', 'b'], reason: 'and those are what runs');
      expect(described.every((i) => i['ids'].toString() == '[a, b]'), isTrue);
      // the history keeps the model's own call, untouched
      expect(jsonEncode(f.bodies[1]['messages']), isNot(contains('"ids"')));
    });
  });

  group('the cache (IA-09, IA-22)', () {
    test('a long step caches for an hour: every breakpoint alike, priced at twice the input', () async {
      final f = FakeClaude([(_) => FakeReply.text('ok')]);
      await api(f.call).send(
        AiRequest(model: AiModel.fable52, system: 's', history: [user('q')], longCache: true),
        cancel: AiCancel(),
      );
      final b = f.bodies.single;
      const hour = {'type': 'ephemeral', 'ttl': '1h'};
      expect(b['cache_control'], hour);
      expect((b['system'] as List).single['cache_control'], hour);
      // the usage of one-hour writes, read apart
      const u = AiUsage(input: 100, cacheWrite: 1000, cacheWriteHour: 2000, cacheRead: 5000, output: 10);
      expect(u.totalInput, 8100);
      expect(u.cost(AiModel.opus55), closeTo((100 * 4 + 1000 * 5 + 2000 * 8 + 5000 * 0.2 + 10 * 20) / 1e6, 1e-12));
      expect(AiModel.fable52.cacheWriteHour, 16, reason: 'Claude Fable 5.2: one-hour writes US\$ 16 per million');
    });

    test('one-hour cache writes are read from the usage breakdown', () async {
      Future<AiHttpResponse> transport(AiHttpRequest r, AiCancel c) async => AiHttpResponse(
        200,
        {'content-type': 'application/json'},
        Stream.value(
          utf8.encode(
            jsonEncode({
              'model': 'claude-opus-5-5',
              'content': [
                {'type': 'text', 'text': 'ok'},
              ],
              'stop_reason': 'end_turn',
              'usage': {
                'input_tokens': 10,
                'cache_creation_input_tokens': 3000,
                'cache_creation': {'ephemeral_5m_input_tokens': 1000, 'ephemeral_1h_input_tokens': 2000},
                'cache_read_input_tokens': 0,
                'output_tokens': 5,
              },
            }),
          ),
        ),
      );
      final r = await api(transport).send(
        AiRequest(model: AiModel.opus55, system: 's', history: [user('q')]),
        cancel: AiCancel(),
      );
      expect(r.usage.cacheWrite, 1000);
      expect(r.usage.cacheWriteHour, 2000);
    });

    test('the keep-alive reads the conversation without an answer: max_tokens 0, no stream, the breakpoint at its end', () async {
      final bodies = <Map<String, dynamic>>[];
      final headers = <Map<String, String>>[];
      Future<AiHttpResponse> transport(AiHttpRequest r, AiCancel c) async {
        bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
        headers.add(r.headers);
        return AiHttpResponse(
          200,
          {'content-type': 'application/json'},
          Stream.value(
            utf8.encode(
              jsonEncode({
                'content': [],
                'stop_reason': 'max_tokens',
                'usage': {'input_tokens': 3, 'cache_read_input_tokens': 40000, 'cache_creation_input_tokens': 120, 'output_tokens': 0},
              }),
            ),
          ),
        );
      }

      final history = [
        user('first'),
        {
          'role': 'assistant',
          'content': [
            {'type': 'thinking', 'thinking': '', 'signature': 's1'},
            {'type': 'text', 'text': 'answer'},
          ],
        },
      ];
      final u = await api(transport).keepWarm(
        AiRequest(
          model: AiModel.opus55,
          system: 'sys',
          history: history,
          tools: const [
            AiToolSpec('look', 'looks', {'type': 'object'}),
          ],
          effort: AiEffort.high,
          compactAt: 150000,
        ),
        cancel: AiCancel(),
      );
      expect(u.cacheRead, 40000);
      final b = bodies.single;
      expect(b['max_tokens'], 0);
      expect(b.containsKey('stream'), isFalse, reason: 'max_tokens 0 is refused with stream true');
      expect(b.containsKey('cache_control'), isFalse, reason: 'no automatic breakpoint: it would cache the placeholder');
      expect(b['output_config'], {'effort': 'high'}, reason: 'the same thinking and effort as the real requests');
      final msgs = (b['messages'] as List).cast<Map<String, dynamic>>();
      expect(msgs.length, 3);
      final answer = (msgs[1]['content'] as List).cast<Map>();
      expect(answer.last['cache_control'], {'type': 'ephemeral'}, reason: 'the breakpoint on the end of the conversation');
      expect(answer.first.containsKey('cache_control'), isFalse, reason: 'never on a thinking block');
      expect(msgs.last['role'], 'user', reason: 'a request may not end with the model\'s answer');
      expect(jsonEncode(history), isNot(contains('cache_control')), reason: 'the history is not changed');
      final edits = ((b['context_management'] as Map)['edits'] as List).cast<Map>();
      expect(edits.map((e) => e['type']), ['clear_tool_uses_20250919'], reason: 'the same clearing, never a compaction');
      expect(headers.single['anthropic-beta'], isNot(contains('compact-')));
    });

    test('the breakpoint at the end goes on the nearest block that takes one, never a thinking block', () {
      final m = withCacheMarkers(
        [
          user('q'),
          {
            'role': 'assistant',
            'content': [
              {'type': 'text', 'text': 'answer'},
              {'type': 'thinking', 'thinking': '', 'signature': 's'},
            ],
          },
        ],
        const {'type': 'ephemeral'},
        atEnd: true,
      );
      final blocks = (m.last['content'] as List).cast<Map>();
      expect(blocks.first['cache_control'], {'type': 'ephemeral'});
      expect(blocks.last.containsKey('cache_control'), isFalse);
    });

    test('a long answer gets breakpoints within 20 positions of each other; a short one none', () {
      Map<String, dynamic> answer(int calls) => {
        'role': 'assistant',
        'content': [
          for (var k = 0; k < calls; k++) ...[
            {'type': 'thinking', 'thinking': 'note $k', 'signature': 's$k'},
            {'type': 'tool_use', 'id': 't$k', 'name': 'look', 'input': <String, dynamic>{}},
          ],
        ],
      };
      Map<String, dynamic> results(int calls) => AnthropicFormat.toolResults([for (var k = 0; k < calls; k++) AiToolResult('t$k', const ToolOutput('ok'))]).single;
      const marker = {'type': 'ephemeral'};
      int marks(List<Map<String, dynamic>> m) => RegExp('cache_control').allMatches(jsonEncode(m)).length;
      final short = [user('q'), answer(4), results(4)];
      expect(marks(withCacheMarkers(short, marker)), 0);
      final long = [user('q'), answer(12), results(12)];
      expect(cachePositions(long.sublist(1)).length, 25);
      final marked = withCacheMarkers(long, marker);
      expect(marks(marked), 1, reason: 'one breakpoint 15 positions from the end');
      expect(marks(withCacheMarkers([user('q'), answer(20), results(20)], marker)), 2);
      expect(jsonEncode(long), isNot(contains('cache_control')), reason: 'copies are marked, not the history');
      // never on a thinking block
      for (final m in marked) {
        for (final b in (m['content'] as List).cast<Map>()) {
          if (b.containsKey('cache_control')) expect(b['type'], isNot('thinking'));
        }
      }
    });

    test('a request with a long answer carries at most four breakpoints', () async {
      final f = FakeClaude([(_) => FakeReply.text('ok')]);
      final calls = [
        for (var k = 0; k < 20; k++) ...[
          {'type': 'thinking', 'thinking': 'n', 'signature': 's$k'},
          {'type': 'tool_use', 'id': 't$k', 'name': 'look', 'input': <String, dynamic>{}},
        ],
      ];
      await api(f.call).send(
        AiRequest(
          model: AiModel.opus55,
          system: 's',
          history: [
            user('q'),
            {'role': 'assistant', 'content': calls},
            ...AnthropicFormat.toolResults([for (var k = 0; k < 20; k++) AiToolResult('t$k', const ToolOutput('ok'))]),
          ],
        ),
        cancel: AiCancel(),
      );
      final n = RegExp('cache_control').allMatches(jsonEncode(f.bodies.single)).length;
      expect(n, lessThanOrEqualTo(4));
      expect(n, 4, reason: 'the system prompt, two inside the answer, the automatic one');
    });
  });

  group('OpenAI pictures pruned in steps (IA-10)', () {
    List<Map<String, dynamic>> conv(int n) => [
      for (var i = 1; i <= n; i++)
        {
          'type': 'function_call_output',
          'call_id': 'c$i',
          'output': [
            {'type': 'input_text', 'text': 'p$i'},
            {'type': 'input_image', 'image_url': 'data:image/jpeg;base64,IMG$i', 'detail': 'high'},
          ],
        },
    ];
    String state(List<Map<String, dynamic>> items) => [for (final it in items) ((it['output'] as List).any((p) => p['type'] == 'input_image') ? 'I' : '-')].join();

    test('the pictures replaced change once every four new ones, not with each', () {
      expect([for (var n = 6; n <= 12; n++) state(pruneToolPictures(conv(n)))], ['IIIIII', '----III', '----IIII', '----IIIII', '----IIIIII', '--------III', '--------IIII']);
      expect([for (var n = 0; n <= 15; n++) prunedPictures(n)], [0, 0, 0, 0, 0, 0, 0, 4, 4, 4, 4, 8, 8, 8, 8, 12]);
    });

    test('the request with 8 pictures starts as the one with 7 did (the cached prefix holds)', () {
      final a = jsonEncode(pruneToolPictures(conv(7)));
      final b = jsonEncode(pruneToolPictures(conv(8)));
      expect(b.startsWith(a.substring(0, a.length - 1)), isTrue);
    });
  });

  group('compaction (IA-16, IA-17)', () {
    test('below the price step of a model that has one', () {
      expect(AiModel.haiku55.compactAt, 90000, reason: 'Claude Haiku 5.5 bills 5 × past 100 000 input tokens');
      expect(AiModel.opus55.compactAt, 150000);
      expect(AiModel.fable52.compactAt, 150000);
      expect(AiModel.gpt61Sol.compactAt, 200000);
    });

    test('the summary is told what to keep; turned down, only the instructions go', () async {
      final f = FakeClaude([(_) => FakeReply.error(400, 'invalid_request_error', 'context_management.edits.1.instructions: Extra inputs are not permitted'), (_) => FakeReply.text('ok')]);
      await api(f.call).send(
        AiRequest(model: AiModel.opus55, system: 's', history: [user('q')], compactAt: 150000),
        cancel: AiCancel(),
      );
      Map edit(int n) => ((f.bodies[n]['context_management'] as Map)['edits'] as List).cast<Map>().last;
      expect(edit(0)['instructions'], AnthropicClient.compactionInstructions);
      expect(AnthropicClient.compactionInstructions, contains('ids, names and coordinates'));
      expect(edit(1)['type'], 'compact_20260112', reason: 'compaction stays');
      expect(edit(1).containsKey('instructions'), isFalse);
      expect(((f.bodies[1]['context_management'] as Map)['edits'] as List).length, 2, reason: 'the clearing stays too');
    });
  });

  group('effort messages (IA-18)', () {
    test('an effort message: a system message with no content, and its beta', () async {
      final c = api((_, _) async => throw UnimplementedError());
      final m = c.effortMessage(AiModel.opus55, AiEffort.low)!;
      expect(m, {
        'role': 'system',
        'content': <Object?>[],
        'output_config': {'effort': 'low'},
      });
      expect(effortOfMessage(m), AiEffort.low);
      expect(effortAfter([user('a'), m, user('b')], AiEffort.high), AiEffort.low);
      expect(effortAfter([user('a')], AiEffort.high), AiEffort.high);
      expect(OpenAiClient(apiKey: 'sk-x', transport: (_, _) async => throw UnimplementedError()).effortMessage(AiModel.gpt61Sol, AiEffort.low), isNull);
      final f = FakeClaude([(_) => FakeReply.text('ok')]);
      await api(f.call).send(
        AiRequest(model: AiModel.opus55, system: 's', history: [user('q'), m], effort: AiEffort.high),
        cancel: AiCancel(),
      );
      expect(f.requests.single.headers['anthropic-beta'], contains(AnthropicClient.effortBeta));
      expect((f.bodies.single['output_config'] as Map)['effort'], 'high', reason: 'the request keeps the conversation\'s effort');
    });

    test('turned down, the turn goes again with the effort as the request\'s own', () async {
      final f = FakeClaude([
        (_) => FakeReply.error(400, 'invalid_request_error', 'messages.1.output_config.effort requires a model that supports per-turn effort; this model does not'),
        (_) => FakeReply.text('ok'),
      ]);
      final c = api(f.call);
      final t = await AgentLoop(
        api: c,
        tools: const [],
      ).run(model: AiModel.opus55, effort: AiEffort.high, system: 's', history: const [], user: user('go'), extra: [c.effortMessage(AiModel.opus55, AiEffort.low)!], cancel: AiCancel());
      expect(t.stop, AgentStop.done);
      expect(t.effortDeclined, isTrue);
      expect((f.bodies[1]['output_config'] as Map)['effort'], 'low');
      expect(jsonEncode(t.messages), isNot(contains('output_config')), reason: 'the effort message left the turn');
    });

    test('accepted, it follows the question in the history', () async {
      final f = FakeClaude([(_) => FakeReply.text('ok')]);
      final c = api(f.call);
      final t = await AgentLoop(
        api: c,
        tools: const [],
      ).run(model: AiModel.opus55, effort: AiEffort.high, system: 's', history: const [], user: user('go'), extra: [c.effortMessage(AiModel.opus55, AiEffort.low)!], cancel: AiCancel());
      expect(t.messages.length, 3);
      expect(effortOfMessage(t.messages[1]), AiEffort.low);
    });
  });

  group('who answered and what the API dropped (IA-19, IA-21)', () {
    test('a fallback model is reported once; dropped thinking blocks are counted', () async {
      final served = <String>[];
      Future<AiHttpResponse> transport(AiHttpRequest r, AiCancel c) async {
        final events = [
          {
            'type': 'message_start',
            'message': {
              'model': 'claude-opus-5',
              'usage': {'input_tokens': 10, 'output_tokens': 1},
              'input_transformations': [
                {'type': 'thinking_dropped', 'path': 'messages.1.content.0', 'reason': 'prefix_binding_mismatch'},
                {'type': 'thinking_dropped', 'path': 'messages.3.content.0', 'reason': 'model_binding_mismatch'},
              ],
            },
          },
          {
            'type': 'content_block_start',
            'index': 0,
            'content_block': {'type': 'text', 'text': 'ok'},
          },
          {'type': 'content_block_stop', 'index': 0},
          {
            'type': 'message_delta',
            'delta': {'stop_reason': 'end_turn'},
            'usage': {'output_tokens': 4},
          },
          {'type': 'message_stop'},
        ];
        return AiHttpResponse(200, {'content-type': 'text/event-stream'}, Stream.value(utf8.encode(events.map((e) => 'event: ${e['type']}\ndata: ${jsonEncode(e)}\n\n').join())));
      }

      final t = await AgentLoop(api: api(transport), tools: const []).run(
        model: AiModel.opus55,
        system: 's',
        history: const [],
        user: user('go'),
        cancel: AiCancel(),
        events: AgentEvents(onModel: served.add),
      );
      expect(served, ['claude-opus-5']);
      expect(t.models, ['claude-opus-5']);
      expect(t.prefixDrops, 1, reason: 'a model switch is not an edit of the history');
    });

    test('an account without the binding beta: the request goes again without it', () async {
      final f = FakeClaude([
        (_) => FakeReply.error(400, 'invalid_request_error', 'Unexpected value(s) `thinking-binding-controls-2026-08-01` for the `anthropic-beta` header.'),
        (_) => FakeReply.text('ok'),
      ]);
      final r = await api(f.call).send(
        AiRequest(model: AiModel.opus55, system: 's', history: [user('q')]),
        cancel: AiCancel(),
      );
      expect(r.text, 'ok');
      expect((f.bodies[0]['thinking'] as Map)['block_binding'], {'prefix_mismatch_behavior': 'drop_block'});
      expect((f.bodies[1]['thinking'] as Map).containsKey('block_binding'), isFalse);
      expect(f.requests[1].headers['anthropic-beta'], isNot(contains('thinking-binding')));
      expect(AiHttpClient.declined, contains('claude-opus-5-5:block_binding'));
    });
  });

  group('a body near the size the API takes (IA-08)', () {
    test('the server is asked to compact now, without clearing first', () async {
      final f = FakeClaude([(_) => FakeReply.text('ok')]);
      final big = 'A' * (AnthropicClient.compactBytes + 1000);
      await api(f.call).send(
        AiRequest(
          model: AiModel.opus55,
          system: 's',
          history: [
            AnthropicFormat.user([AiImagePart('image/jpeg', big)]),
          ],
          compactAt: 150000,
        ),
        cancel: AiCancel(),
      );
      final edits = ((f.bodies.single['context_management'] as Map)['edits'] as List).cast<Map>();
      expect(edits.map((e) => e['type']), ['compact_20260112']);
      expect((edits.single['trigger'] as Map)['value'], AnthropicClient.minCompactAt);
    });
  });
}
