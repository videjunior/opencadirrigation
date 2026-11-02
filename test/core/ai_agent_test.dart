import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/ai/claude_api.dart';

import '../support/fake_claude.dart';

/// The Anthropic client and the agent loop of the AI assistant, against a
/// scripted model (no network): the request the API documents (Claude Fable
/// 5.1's own rules included), the streamed answer, tools and their results,
/// permissions and plan mode, the step limit, the spending cap, what the
/// user writes while the model works, compaction, stopping, errors and
/// retries — and the key only ever in its header.
void main() {
  const key = 'sk-ant-api03-SECRET-test-key-0000';

  AnthropicClient api(FakeClaude f, {bool browser = false}) => AnthropicClient(apiKey: key, transport: f.call, browser: browser, sleep: (_) async {});

  final ran = <String>[];
  AgentTool tool(String name, {ToolEffect effect = ToolEffect.read, bool confirm = false, String Function(Map<String, dynamic>)? out}) => FnTool(
    name: name,
    description: 'test tool $name',
    effect: effect,
    confirm: confirm ? (_) => true : null,
    inputSchema: {
      'type': 'object',
      'properties': {
        'x': {'type': 'number'},
        'id': {'type': 'string'},
      },
      'additionalProperties': false,
    },
    handler: (i) async {
      ran.add(name);
      if (i['id'] == 'bad') throw ToolInputError('no item "bad"');
      return ToolOutput(out?.call(i) ?? '$name ok ${jsonEncode(i)}');
    },
  );

  Map<String, dynamic> user(String s) => {
    'role': 'user',
    'content': [
      {'type': 'text', 'text': s},
    ],
  };

  setUp(() {
    ran.clear();
    AiHttpClient.declined.clear();
  });

  test('the request follows the API: endpoint, headers, streaming, adaptive thinking with the notes between tool calls, effort, the full output limit, caching, refusal fallback', () async {
    final f = FakeClaude([(_) => FakeReply.text('Hello')]);
    final r = await api(f, browser: true).send(
      AiRequest(model: AiModel.opus55, system: 'sys', history: [user('hi')], tools: [tool('a').spec], effort: AiEffort.high),
      cancel: AiCancel(),
    );
    expect(r.text, 'Hello');
    expect(r.stop, AiStop.end);
    final req = f.requests.single;
    expect(req.url.toString(), 'https://api.anthropic.com/v1/messages');
    expect(req.headers['x-api-key'], key);
    expect(req.headers['anthropic-version'], '2026-10-21');
    expect(req.headers['anthropic-dangerous-direct-browser-access'], 'true');
    expect(req.headers['anthropic-beta'], 'server-side-fallback-2026-07-01,thinking-display-updates-2026-08-18,thinking-binding-controls-2026-08-01');
    expect(req.headers['content-type'], 'application/json');
    final b = f.bodies.single;
    expect(b['model'], 'claude-opus-5-5');
    expect(b['stream'], isTrue);
    expect(b['max_tokens'], 128000, reason: 'the most the model takes when streaming');
    expect(b['thinking'], {
      'type': 'adaptive',
      'display': 'updates',
      'block_binding': {'prefix_mismatch_behavior': 'drop_block'},
    }, reason: 'a thinking block the conversation before it no longer matches is dropped, and the answer says so');
    expect(b['output_config'], {'effort': 'high'});
    expect(b['cache_control'], {'type': 'ephemeral'});
    expect((b['system'] as List).single, {
      'type': 'text',
      'text': 'sys',
      'cache_control': {'type': 'ephemeral'},
    });
    expect(b['fallbacks'], 'default');
    expect(((b['tools'] as List).single as Map)['eager_input_streaming'], isTrue);
    expect(b.containsKey('temperature'), isFalse);
    expect(b.containsKey('tool_choice'), isFalse, reason: 'forced tool choice is a 400 on these models');
    // the key is in its header only
    expect(req.body.contains(key), isFalse);
    // usage of the message, cumulative output
    expect(r.usage.input, 1000);
    expect(r.usage.cacheWrite, 200);
    expect(r.usage.cacheRead, 300);
    expect(r.usage.output, 50);
  });

  test('Claude Fable 5.1: adaptive thinking only (always on) with its notes as text, every effort level, the refusal fallback, no task budget', () async {
    for (final e in AiEffort.values) {
      final f = FakeClaude([(_) => FakeReply.text('ok', model: 'claude-fable-5-1')]);
      await api(f).send(
        AiRequest(model: AiModel.fable51, system: 's', history: [user('q')], effort: e, taskBudget: 100000, compactAt: 150000),
        cancel: AiCancel(),
      );
      final b = f.bodies.single;
      expect(b['model'], 'claude-fable-5-1');
      expect(b['thinking'], {
        'type': 'adaptive',
        'display': 'updates',
        'block_binding': {'prefix_mismatch_behavior': 'drop_block'},
      }, reason: 'adaptive (or nothing) is all Claude Fable 5.1 takes; display "updates" returns its notes');
      expect(b['max_tokens'], 128000);
      expect(b['output_config'], {'effort': e.name});
      expect(b['fallbacks'], 'default');
      expect(b.containsKey('tool_choice'), isFalse);
      expect(
        f.requests.single.headers['anthropic-beta'],
        'server-side-fallback-2026-07-01,context-management-2025-06-27,compact-2026-01-12,thinking-display-updates-2026-08-18,thinking-binding-controls-2026-08-01',
      );
    }
    expect(AiModel.fable51.input, 10);
    expect(AiModel.fable51.output, 50);
    expect(AiModel.fable51.cacheRead, 0.25);
    expect(AiModel.fable51.needsRetention, isTrue);
    expect(AiModel.fable51.tier, AiTier.top);
  });

  test('a task budget and compaction where the model takes them; Haiku takes no fallback; desktop requests carry no browser header', () async {
    final f = FakeClaude([(_) => FakeReply.text('ok'), (_) => FakeReply.text('ok', model: 'claude-haiku-5-5')]);
    await api(f).send(
      AiRequest(model: AiModel.opus55, system: 's', history: [user('q')], taskBudget: 5000, compactAt: 10),
      cancel: AiCancel(),
    );
    final b = f.bodies.first;
    expect(b['output_config'], {
      'effort': 'medium',
      'task_budget': {'type': 'tokens', 'total': 20000},
    }, reason: 'raised to the least the API takes');
    expect(b['context_management'], {
      'edits': [
        {
          'type': 'clear_tool_uses_20250919',
          'trigger': {'type': 'input_tokens', 'value': 80000},
          'keep': {'type': 'tool_uses', 'value': 4},
          'clear_at_least': {'type': 'input_tokens', 'value': 10000},
          // (no tool to keep in a request without tools: the field is left out)
        },
        {
          'type': 'compact_20260112',
          'trigger': {'type': 'input_tokens', 'value': 50000},
          'instructions': AnthropicClient.compactionInstructions,
        },
      ],
    });
    expect(
      f.requests.first.headers['anthropic-beta'],
      'server-side-fallback-2026-07-01,task-budgets-2026-03-13,context-management-2025-06-27,compact-2026-01-12,thinking-display-updates-2026-08-18,thinking-binding-controls-2026-08-01',
    );
    await api(f).send(
      AiRequest(model: AiModel.haiku55, system: 's', history: [user('q')]),
      cancel: AiCancel(),
    );
    expect(f.requests.last.headers.containsKey('anthropic-dangerous-direct-browser-access'), isFalse);
    expect(f.requests.last.headers['anthropic-beta'], 'thinking-binding-controls-2026-08-01');
    expect(f.bodies.last.containsKey('fallbacks'), isFalse);
    expect(f.bodies.last['thinking'], {
      'type': 'adaptive',
      'block_binding': {'prefix_mismatch_behavior': 'drop_block'},
    }, reason: 'Claude Haiku 5.5 writes no notes between tool calls');
    expect(f.bodies.last['model'], 'claude-haiku-5-5');
  });

  test('an optional field the model turns down is dropped and the request sent again at once', () async {
    final f = FakeClaude([(_) => FakeReply.error(400, 'invalid_request_error', 'output_config.task_budget: Extra inputs are not permitted'), (_) => FakeReply.text('fine')]);
    final r = await api(f).send(
      AiRequest(model: AiModel.sonnet55, system: 's', history: [user('q')], taskBudget: 60000),
      cancel: AiCancel(),
    );
    expect(r.text, 'fine');
    expect(f.calls, 2);
    expect((f.bodies[0]['output_config'] as Map).containsKey('task_budget'), isTrue);
    expect((f.bodies[1]['output_config'] as Map).containsKey('task_budget'), isFalse);
    expect(f.requests[1].headers['anthropic-beta'], 'server-side-fallback-2026-07-01,thinking-display-updates-2026-08-18,thinking-binding-controls-2026-08-01');
  });

  test('old tool results are cleared on the server, never the notes or the answers; a rejected combination drops the clearing first', () async {
    final f = FakeClaude([(_) => FakeReply.error(400, 'invalid_request_error', 'context_management.edits.0: this combination is not supported'), (_) => FakeReply.text('ok')]);
    final tools = [tool('view_snapshot').spec, tool('ask_user').spec, tool('get_notes').spec];
    final r = await api(f).send(
      AiRequest(model: AiModel.opus55, system: 's', history: [user('q')], tools: tools, compactAt: 150000),
      cancel: AiCancel(),
    );
    expect(r.text, 'ok');
    final first = ((f.bodies[0]['context_management'] as Map)['edits'] as List).cast<Map>();
    expect(first.map((e) => e['type']), ['clear_tool_uses_20250919', 'compact_20260112']);
    expect(first.first['exclude_tools'], ['get_notes', 'ask_user'], reason: 'only the tools of the request, never a picture tool');
    final second = ((f.bodies[1]['context_management'] as Map)['edits'] as List).cast<Map>();
    expect(second.map((e) => e['type']), ['compact_20260112'], reason: 'compaction stays');
    expect(f.requests[1].headers['anthropic-beta'], 'server-side-fallback-2026-07-01,compact-2026-01-12,thinking-display-updates-2026-08-18,thinking-binding-controls-2026-08-01');
  });

  test('a turn runs the tools the model asks for and keeps a history the API accepts', () async {
    final f = FakeClaude([
      (_) => FakeReply.tools([
        ('look', {'x': 1}),
        ('look', {'x': 2}),
      ], text: 'Let me look.'),
      (_) => FakeReply.text('Two looks done.'),
    ]);
    final texts = <String>[];
    final turn = await AgentLoop(api: api(f), tools: [tool('look')]).run(
      model: AiModel.opus55,
      system: 's',
      history: const [],
      user: user('go'),
      cancel: AiCancel(),
      events: AgentEvents(onText: texts.add),
    );
    expect(turn.stop, AgentStop.done);
    expect(ran, ['look', 'look']);
    expect(turn.text, 'Let me look.\n\nTwo looks done.');
    expect(texts.join(), turn.text, reason: 'the text streams as it arrives');
    expect(turn.messages.map((m) => m['role']), ['user', 'assistant', 'user', 'assistant']);
    // the thinking block goes back unchanged, with its signature
    final first = (turn.messages[1]['content'] as List).cast<Map>();
    expect(first.first, {'type': 'thinking', 'thinking': '', 'signature': 'sig0'});
    final uses = first.where((b) => b['type'] == 'tool_use').toList();
    expect(uses.map((u) => u['input']), [
      {'x': 1},
      {'x': 2},
    ]);
    // every tool use answered, in one user message, in order
    final results = (turn.messages[2]['content'] as List).cast<Map>();
    expect(results.map((r) => r['tool_use_id']), uses.map((u) => u['id']));
    expect(results.first['content'], 'look ok {"x":1}');
    // the second request re-sent the whole exchange, byte for byte
    expect((f.bodies[1]['messages'] as List).length, 3);
    expect(jsonEncode((f.bodies[1]['messages'] as List)[1]), jsonEncode(turn.messages[1]));
    expect(turn.usage.output, 100);
    expect(turn.cost, greaterThan(0));
  });

  test('invalid inputs, unknown tools and tool errors go back to the model as error results', () async {
    final f = FakeClaude([
      (_) => FakeReply.tools([
        ('look', {'y': 1}),
        ('nope', {}),
        ('look', {'id': 'bad'}),
        ('look', {'x': 'text'}),
      ]),
      (b) => FakeReply.text('Sorry.'),
    ]);
    final turn = await AgentLoop(api: api(f), tools: [tool('look')]).run(model: AiModel.opus55, system: 's', history: const [], user: user('go'), cancel: AiCancel());
    expect(ran, ['look'], reason: 'only the call with a valid input ran');
    final results = (turn.messages[2]['content'] as List).cast<Map>();
    expect(results.every((r) => r['is_error'] == true), isTrue);
    expect(results[0]['content'], contains('Unknown field "input.y"'));
    expect(results[1]['content'], contains('Unknown tool'));
    expect(results[2]['content'], 'no item "bad"');
    expect(results[3]['content'], contains('must be of type number'));
    expect(turn.calls.where((c) => c.state == ToolCallState.failed).length, 3);
  });

  test('ask mode asks before each change; a skipped change is reported to the model; read-only and plan mode refuse without asking', () async {
    final asked = <String>[];
    Future<AgentTurn> run(AgentPermission p, Approval answer) {
      final f = FakeClaude([
        (_) => FakeReply.tools([
          ('read', {}),
          ('edit', {'x': 3}),
        ]),
        (_) => FakeReply.text('ok'),
      ]);
      return AgentLoop(
        api: api(f),
        tools: [
          tool('read'),
          tool('edit', effect: ToolEffect.write),
        ],
      ).run(
        model: AiModel.opus55,
        system: 's',
        history: const [],
        user: user('go'),
        permission: p,
        cancel: AiCancel(),
        events: AgentEvents(
          approve: (call) async {
            asked.add(call.name);
            return answer;
          },
        ),
      );
    }

    var turn = await run(AgentPermission.ask, Approval.apply);
    expect(asked, ['edit']);
    expect(ran, ['read', 'edit']);
    ran.clear();
    asked.clear();
    turn = await run(AgentPermission.ask, Approval.skip);
    expect(ran, ['read']);
    expect(((turn.messages[2]['content'] as List)[1] as Map)['content'], contains('declined'));
    expect(turn.calls.last.state, ToolCallState.skipped);
    ran.clear();
    asked.clear();
    turn = await run(AgentPermission.readOnly, Approval.apply);
    expect(asked, isEmpty);
    expect(ran, ['read']);
    expect(((turn.messages[2]['content'] as List)[1] as Map)['content'], contains('read-only'));
    ran.clear();
    turn = await run(AgentPermission.plan, Approval.apply);
    expect(asked, isEmpty);
    expect(ran, ['read']);
    expect(((turn.messages[2]['content'] as List)[1] as Map)['content'], contains('present_plan'));
    expect(turn.calls.last.state, ToolCallState.refused);
    ran.clear();
    turn = await run(AgentPermission.auto, Approval.skip);
    expect(asked, isEmpty);
    expect(ran, ['read', 'edit'], reason: 'automatic mode applies changes without asking');
  });

  test('plan mode: changes wait until the plan is approved within the same turn', () async {
    var mode = AgentPermission.plan;
    final f = FakeClaude([
      (_) => FakeReply.tools([
        ('edit', {'x': 1}),
      ]),
      (_) => FakeReply.tools([('approve_plan', {})]),
      (_) => FakeReply.tools([
        ('edit', {'x': 2}),
      ]),
      (_) => FakeReply.text('done'),
    ]);
    final approvePlan = FnTool(
      name: 'approve_plan',
      description: 'the user approves the plan',
      inputSchema: const {'type': 'object', 'properties': {}},
      handler: (_) async {
        mode = AgentPermission.auto;
        return const ToolOutput('Approved.');
      },
    );
    final turn = await AgentLoop(
      api: api(f),
      tools: [
        tool('edit', effect: ToolEffect.write),
        approvePlan,
      ],
    ).run(model: AiModel.opus55, system: 's', history: const [], user: user('go'), permission: AgentPermission.plan, permissionNow: () => mode, cancel: AiCancel());
    expect(turn.stop, AgentStop.done);
    expect(ran, ['edit'], reason: 'the edit before the approval was refused, the one after it ran');
    expect(f.lastUserText(1), contains('plan mode'));
    expect(turn.calls.map((c) => c.state), [ToolCallState.refused, ToolCallState.done, ToolCallState.done]);
  });

  test('exports are confirmed even when changes apply automatically', () async {
    final asked = <String>[];
    final f = FakeClaude([
      (_) => FakeReply.tools([('save', {})]),
      (_) => FakeReply.text('ok'),
    ]);
    await AgentLoop(
      api: api(f),
      tools: [tool('save', effect: ToolEffect.export)],
    ).run(
      model: AiModel.opus55,
      system: 's',
      history: const [],
      user: user('go'),
      permission: AgentPermission.auto,
      cancel: AiCancel(),
      events: AgentEvents(
        approve: (c) async {
          asked.add(c.name);
          return Approval.apply;
        },
      ),
    );
    expect(asked, ['save']);
  });

  test('the step limit ends the turn with every tool use answered', () async {
    final f = FakeClaude([
      for (var k = 0; k < 10; k++)
        (_) => FakeReply.tools([
          ('look', {'x': k}),
        ]),
    ]);
    final turn = await AgentLoop(api: api(f), tools: [tool('look')]).run(model: AiModel.opus55, system: 's', history: const [], user: user('loop'), maxSteps: 3, cancel: AiCancel());
    expect(turn.stop, AgentStop.stepLimit);
    expect(f.calls, 3);
    expect(ran.length, 2, reason: 'the third request\'s tools are not run');
    // the note before the last step, and a valid history
    expect(f.lastUserText(2), contains('Step limit'));
    final last = (turn.messages.last['content'] as List).cast<Map>();
    expect(last.single['content'], contains('step limit'));
    final uses = [
      for (final m in turn.messages)
        if (m['role'] == 'assistant')
          for (final b in (m['content'] as List).cast<Map>())
            if (b['type'] == 'tool_use') b['id'],
    ];
    final answered = [
      for (final m in turn.messages)
        if (m['role'] == 'user' && m['content'] is List)
          for (final b in (m['content'] as List).cast<Map>())
            if (b['type'] == 'tool_result') b['tool_use_id'],
    ];
    expect(answered, uses);
  });

  test('the spending cap: a warning near it, then no new request past it', () async {
    final f = FakeClaude([
      for (var k = 0; k < 10; k++)
        (_) => FakeReply.tools([
          ('look', {'x': k}),
        ]),
    ]);
    // each request costs about US$ 0.006 at Opus 5.5 list prices
    final turn = await AgentLoop(api: api(f), tools: [tool('look')]).run(model: AiModel.opus55, system: 's', history: const [], user: user('loop'), maxSteps: 50, costCap: 0.015, cancel: AiCancel());
    expect(turn.stop, AgentStop.budget);
    expect(f.calls, 3);
    expect(turn.cost, greaterThanOrEqualTo(0.015));
    expect(f.lastUserText(2), contains('Spending cap'));
    // every call answered
    expect((turn.messages.last['content'] as List).cast<Map>().first['type'], 'tool_result');
  });

  test('what the user writes while the model works goes with the next results', () async {
    final queue = ['Use 25 mm pipe for the laterals.'];
    final f = FakeClaude([
      (_) => FakeReply.tools([
        ('look', {'x': 1}),
      ]),
      (_) => FakeReply.text('Noted: 25 mm.'),
    ]);
    final turn = await AgentLoop(api: api(f), tools: [tool('look')]).run(
      model: AiModel.opus55,
      system: 's',
      history: const [],
      user: user('go'),
      cancel: AiCancel(),
      events: AgentEvents(
        steer: () {
          final out = [for (final s in queue) AiTextPart(s)];
          queue.clear();
          return out;
        },
      ),
    );
    expect(turn.stop, AgentStop.done);
    final blocks = (turn.messages[2]['content'] as List).cast<Map>();
    expect(blocks.first['type'], 'tool_result', reason: 'the results come first');
    expect(blocks.last['text'], contains('Use 25 mm pipe'));
    expect(blocks.last['text'], startsWith('[Message from the user'));
  });

  test('compaction: the summary goes back and the earlier messages are no longer sent', () async {
    final f = FakeClaude([
      (_) => FakeReply.tools([
        ('look', {'x': 1}),
      ], compaction: 'Summary of the work so far.'),
      (_) => FakeReply.text('Done.'),
    ]);
    var compacted = 0;
    final history = [
      user('earlier question'),
      {
        'role': 'assistant',
        'content': [
          {'type': 'text', 'text': 'earlier answer'},
        ],
      },
    ];
    final turn = await AgentLoop(api: api(f), tools: [tool('look')]).run(
      model: AiModel.opus55,
      system: 's',
      history: history,
      user: user('go on'),
      compactAt: 150000,
      cancel: AiCancel(),
      events: AgentEvents(onCompacted: () => compacted++),
    );
    expect(turn.stop, AgentStop.done);
    expect(compacted, 1);
    expect(turn.compactions, 1);
    expect((f.bodies[0]['messages'] as List).length, 3);
    final second = (f.bodies[1]['messages'] as List).cast<Map>();
    expect(second.first['role'], 'assistant', reason: 'the request starts at the compaction');
    expect(((second.first['content'] as List).first as Map)['type'], 'compaction');
    expect(((second.first['content'] as List).first as Map)['content'], 'Summary of the work so far.');
    expect(second.length, 2);
    // the whole history is kept on this side (a rewind needs it)
    expect(turn.messages.length, 4);
    // the compaction is billed on top of the message
    expect(turn.usage.input, greaterThan(160000));
  });

  test('stopping while a change awaits approval or while the model answers', () async {
    final cancel = AiCancel();
    final f = FakeClaude([
      (_) => FakeReply.tools([
        ('edit', {'x': 1}),
        ('edit', {'x': 2}),
      ]),
    ]);
    final turn =
        await AgentLoop(
          api: api(f),
          tools: [tool('edit', effect: ToolEffect.write)],
        ).run(
          model: AiModel.opus55,
          system: 's',
          history: const [],
          user: user('go'),
          cancel: cancel,
          events: AgentEvents(
            approve: (c) {
              cancel.cancel();
              return Completer<Approval>().future; // never answered: the stop wins
            },
          ),
        );
    expect(turn.stop, AgentStop.cancelled);
    expect(ran, isEmpty);
    // the tool uses are answered so the conversation can go on
    final results = (turn.messages.last['content'] as List).cast<Map>();
    expect(results.length, 2);
    expect(results.every((r) => (r['content'] as String).contains('stopped')), isTrue);

    final c2 = AiCancel();
    final hang = FakeClaude([(_) => FakeReply.hang()]);
    final future = AgentLoop(api: api(hang), tools: const []).run(model: AiModel.opus55, system: 's', history: const [], user: user('go'), cancel: c2);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    c2.cancel();
    final t2 = await future;
    expect(t2.stop, AgentStop.cancelled);
    expect(t2.messages, isEmpty, reason: 'nothing came back: the question can be sent again');
  });

  test('errors: a rejected key is not retried; overloads and rate limits are; the key never shows in a message', () async {
    final bad = FakeClaude([(_) => FakeReply.error(401, 'authentication_error', 'invalid x-api-key $key')]);
    final turn = await AgentLoop(api: api(bad), tools: const []).run(model: AiModel.opus55, system: 's', history: const [], user: user('q'), cancel: AiCancel());
    expect(turn.stop, AgentStop.error);
    expect(turn.error!.kind, AiErrorKind.auth);
    expect(bad.calls, 1);
    expect(turn.error!.message.contains(key), isFalse);
    expect(turn.error.toString().contains(key), isFalse);

    final waits = <Duration>[];
    final busy = FakeClaude([
      (_) => FakeReply.error(529, 'overloaded_error', 'Overloaded'),
      (_) => FakeReply.error(429, 'rate_limit_error', 'slow down', headers: {'retry-after': '3'}),
      (_) => FakeReply.text('fine'),
    ]);
    final r = await AnthropicClient(apiKey: key, transport: busy.call, sleep: (d) async => waits.add(d)).send(
      AiRequest(model: AiModel.sonnet55, system: 's', history: [user('q')]),
      cancel: AiCancel(),
    );
    expect(r.text, 'fine');
    expect(busy.calls, 3);
    expect(waits, [const Duration(seconds: 2), const Duration(seconds: 3)], reason: 'backoff, then the wait the API asked for');

    final stream = FakeClaude([(_) => FakeReply.streamError('overloaded_error'), (_) => FakeReply.text('second try')]);
    final r2 = await api(stream).send(
      AiRequest(model: AiModel.opus55, system: 's', history: [user('q')]),
      cancel: AiCancel(),
    );
    expect(r2.text, 'second try');

    final never = FakeClaude([for (var k = 0; k < 5; k++) (_) => FakeReply.error(500, 'api_error', 'boom')]);
    await expectLater(
      api(never).send(
        AiRequest(model: AiModel.opus55, system: 's', history: [user('q')]),
        cancel: AiCancel(),
      ),
      throwsA(isA<AiError>().having((e) => e.kind, 'kind', AiErrorKind.server)),
    );
    expect(never.calls, 3, reason: 'two retries at most');

    final empty = AnthropicClient(apiKey: '  ', transport: never.call);
    await expectLater(
      empty.send(
        AiRequest(model: AiModel.opus55, system: 's', history: [user('q')]),
        cancel: AiCancel(),
      ),
      throwsA(isA<AiError>().having((e) => e.kind, 'kind', AiErrorKind.noKey)),
    );
  });

  test('Claude Fable 5.1 asked from an organisation without data retention is explained as such', () async {
    const msg = 'In order to access this model, your organization or workspace must have data retention enabled.';
    final f = FakeClaude([(_) => FakeReply.error(400, 'invalid_request_error', msg), (_) => FakeReply.error(400, 'invalid_request_error', msg)]);
    await expectLater(
      api(f).send(
        AiRequest(model: AiModel.fable51, system: 's', history: [user('q')]),
        cancel: AiCancel(),
      ),
      throwsA(isA<AiError>().having((e) => e.kind, 'kind', AiErrorKind.retention)),
    );
    expect(f.calls, 1, reason: 'not retried');
    await expectLater(
      api(f).send(
        AiRequest(model: AiModel.opus55, system: 's', history: [user('q')]),
        cancel: AiCancel(),
      ),
      throwsA(isA<AiError>().having((e) => e.kind, 'kind', AiErrorKind.invalidRequest)),
    );
  });

  test('a refusal discards the answer and keeps its category; a tool call cut by the length limit is not run', () async {
    final f = FakeClaude([(_) => FakeReply.refusal('cyber', text: 'Declined by a classifier.')]);
    final turn = await AgentLoop(api: api(f), tools: const []).run(model: AiModel.opus55, system: 's', history: const [], user: user('q'), cancel: AiCancel());
    expect(turn.error!.kind, AiErrorKind.refusal);
    expect(turn.error!.category, 'cyber');
    expect(turn.error!.message, 'Declined by a classifier.');
    expect(turn.messages, isEmpty);

    final cut = FakeClaude([
      (_) => FakeReply.tools([
        ('look', {'x': 1}),
      ], stopReason: 'max_tokens'),
    ]);
    final t2 = await AgentLoop(api: api(cut), tools: [tool('look')]).run(model: AiModel.opus55, system: 's', history: const [], user: user('q'), cancel: AiCancel());
    expect(t2.error!.kind, AiErrorKind.truncated);
    expect(ran, isEmpty);
    expect(t2.messages, isEmpty);
  });

  test('an answer served by a fallback model is priced at that model', () async {
    final f = FakeClaude([(_) => FakeReply.text('ok', model: 'claude-opus-5')]);
    final turn = await AgentLoop(api: api(f), tools: const []).run(model: AiModel.fable51, system: 's', history: const [], user: user('q'), cancel: AiCancel());
    // 1000 in, 200 written, 300 read, 50 out at Claude Opus 5 prices
    expect(turn.cost, closeTo((1000 * 5 + 200 * 6.25 + 300 * 0.5 + 50 * 25) / 1e6, 1e-12));
  });

  test('after a mid-answer fallback only text before the switch is echoed back', () {
    final blocks = <Map<String, dynamic>>[
      {'type': 'thinking', 'thinking': '', 'signature': 'a'},
      {'type': 'text', 'text': 'Partial '},
      {'type': 'tool_use', 'id': 't1', 'name': 'x', 'input': {}},
      {
        'type': 'fallback',
        'from': {'model': 'claude-opus-5-5'},
        'to': {'model': 'claude-opus-5'},
      },
      {'type': 'text', 'text': 'rest'},
      {'type': 'tool_use', 'id': 't2', 'name': 'x', 'input': {}},
    ];
    expect(echoContent(blocks).map((b) => b['type']), ['text', 'text', 'tool_use']);
    expect(echoContent(blocks).last['id'], 't2');
  });

  test('prices: list prices per model, the long-prompt rules, estimates of each kind of token', () {
    const u = AiUsage(input: 1000000, output: 1000000, cacheWrite: 0, cacheRead: 0);
    expect(u.cost(AiModel.opus55), 24);
    expect(u.cost(AiModel.haiku55), closeTo(0.6 * 5, 1e-9), reason: 'over 100K input tokens Haiku costs five times as much');
    expect(const AiUsage(input: 90000, output: 1000).cost(AiModel.haiku55), closeTo((90000 * 0.1 + 1000 * 0.5) / 1e6, 1e-12));
    expect(const AiUsage(input: 300000, output: 1000).cost(AiModel.gpt6Astra), closeTo((300000 * 10 * 2 + 1000 * 50 * 1.5) / 1e6, 1e-12));
    expect(const AiUsage(cacheRead: 100000).cost(AiModel.gpt61Sol), closeTo(0.01, 1e-12));
    expect(AiModel.byId('claude-sonnet-5-5'), AiModel.sonnet55);
    expect(AiModel.byId('gone'), AiModel.opus55, reason: 'Claude Opus 5.5 is the default');
    expect(AiModel.all.where((m) => m.provider == AiProvider.anthropic).map((m) => m.tier), [AiTier.top, AiTier.top, AiTier.intermediate, AiTier.fast]);
    expect(AiModel.all.where((m) => m.provider == AiProvider.openai).map((m) => m.id), ['gpt-6-astra', 'gpt-6.1-sol', 'gpt-6-luna', 'gpt-6-sol', 'gpt-5.6-terra']);
  });

  test('schemaProblem checks nested items, enums and required fields', () {
    final schema = <String, Object?>{
      'type': 'object',
      'properties': {
        'mode': {
          'type': 'string',
          'enum': ['a', 'b'],
        },
        'list': {
          'type': 'array',
          'maxItems': 2,
          'items': {
            'type': 'object',
            'properties': {
              'n': {'type': 'integer'},
            },
            'required': ['n'],
            'additionalProperties': false,
          },
        },
      },
      'required': ['mode'],
      'additionalProperties': false,
    };
    expect(
      schemaProblem(schema, {
        'mode': 'a',
        'list': [
          {'n': 1},
        ],
      }),
      isNull,
    );
    expect(schemaProblem(schema, {}), contains('Missing "input.mode"'));
    expect(schemaProblem(schema, {'mode': 'c'}), contains('one of: a, b'));
    expect(
      schemaProblem(schema, {
        'mode': 'a',
        'list': [
          {'n': 1.5},
        ],
      }),
      contains('integer'),
    );
    expect(
      schemaProblem(schema, {
        'mode': 'a',
        'list': [{}],
      }),
      contains('Missing "input.list[0].n"'),
    );
    expect(
      schemaProblem(schema, {
        'mode': 'a',
        'list': [
          {'n': 1},
          {'n': 2},
          {'n': 3},
        ],
      }),
      contains('at most 2'),
    );
    expect(
      ToolArgs({
        'p': [1, 2],
      }).point('p'),
      isNotNull,
    );
    expect(
      () => ToolArgs({
        'p': [1],
      }).point('p'),
      throwsA(isA<ToolInputError>()),
    );
  });
}
