import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';
import 'package:opencadirrigation/core/ai/claude_api.dart';
import 'package:opencadirrigation/core/ai/llm_formats.dart';
import 'package:opencadirrigation/core/ai/openai_api.dart';

import '../support/fake_claude.dart';
import '../support/fake_openai.dart';

/// The 1.6.0 additions to the assistant's core, against scripted models (no
/// network): the costs and the cache by step, a change approved ahead (Apply
/// the rest of this task) that never reaches an export, the effort by stage
/// through effort messages (and the step that goes again when the API turns
/// one down), the tokens a tool spends asking a model of its own, and the
/// connection test of a model with its rate limits and the fields the
/// account turns down.
void main() {
  const key = 'sk-ant-api03-SECRET-test-key-0000';

  AnthropicClient api(FakeClaude f) => AnthropicClient(apiKey: key, transport: f.call, browser: true, sleep: (_) async {});

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
  tearDown(AiHttpClient.declined.clear);

  test('every request of a turn is a step: its tokens read from and written to the cache, the cost, the size of the request and the effort', () async {
    final f = FakeClaude([
      (_) => FakeReply.tools([
        ('look', {'x': 1}),
      ]),
      (_) => FakeReply.text('Done.'),
    ]);
    final seen = <AgentStep>[];
    final turn = await AgentLoop(api: api(f), tools: [tool('look')]).run(
      model: AiModel.opus55,
      effort: AiEffort.high,
      system: 's',
      history: const [],
      user: user('go'),
      cancel: AiCancel(),
      events: AgentEvents(onStep: seen.add),
    );
    expect(turn.stop, AgentStop.done);
    expect(turn.stepStats, hasLength(2));
    expect(seen, hasLength(2), reason: 'each step as it ends');
    final s = turn.stepStats.first;
    expect(s.model, 'claude-opus-5-5');
    // the scripted usage: 1000 outside the cache, 200 written, 300 read, 50 out
    expect(s.usage.input, 1000);
    expect(s.usage.cacheWrite, 200);
    expect(s.usage.cacheRead, 300);
    expect(s.usage.output, 50);
    expect(s.cacheShare, closeTo(300 / 1500, 1e-9));
    expect(s.cost, closeTo(s.usage.cost(AiModel.opus55), 1e-12));
    expect(s.effort, AiEffort.high);
    expect(s.bytes, f.requests.first.body.length, reason: 'the characters of the body sent');
    expect(s.images, 0);
    expect(s.failed, isFalse);
    expect(s.subagent, isFalse);
    expect(turn.cost, closeTo(turn.stepStats.fold<double>(0, (x, s) => x + s.cost), 1e-12));
    // kept with the conversation and read back
    final back = AgentStep.fromJson(jsonDecode(jsonEncode(s.toJson())))!;
    expect(back.model, s.model);
    expect(back.usage.cacheRead, 300);
    expect(back.usage.cacheWrite, 200);
    expect(back.effort, AiEffort.high);
    expect(back.bytes, s.bytes);
    expect(AgentStep.fromJson('not a step'), isNull);
  });

  test('the pictures and the PDFs a request carries are counted, in tool results too', () async {
    expect(countMedia(const []), (0, 0));
    final msgs = [
      AnthropicFormat.user([const AiImagePart('image/png', 'AAAA'), const AiPdfPart('sheet.pdf', 'JVBERi0='), const AiTextPart('look')]),
      ...AnthropicFormat.toolResults([
        const AiToolResult('t1', ToolOutput('a view', images: [ToolImage('image/jpeg', 'BBBB')])),
      ]),
    ];
    expect(countMedia(msgs), (2, 1));
    final f = FakeClaude([(_) => FakeReply.text('I see it.')]);
    final turn = await AgentLoop(api: api(f), tools: const []).run(
      model: AiModel.sonnet55,
      system: 's',
      history: const [],
      user: AnthropicFormat.user([const AiImagePart('image/png', 'AAAA'), const AiTextPart('look')]),
      cancel: AiCancel(),
    );
    expect(turn.stepStats.single.images, 1);
    expect(turn.stepStats.single.documents, 0);
  });

  test('a change approved ahead runs without a card; an export still asks, and the call says it is always confirmed', () async {
    final f = FakeClaude([
      (_) => FakeReply.tools([
        ('draw', {'x': 1}),
        ('save', {'x': 2}),
      ]),
      (_) => FakeReply.text('Drawn and saved.'),
    ]);
    final asked = <String>[];
    final turn = await AgentLoop(api: api(f), tools: [tool('draw', effect: ToolEffect.write), tool('save', effect: ToolEffect.export)]).run(
      model: AiModel.opus55,
      system: 's',
      history: const [],
      user: user('go'),
      permission: AgentPermission.ask,
      cancel: AiCancel(),
      events: AgentEvents(
        autoApprove: (_) => true,
        approve: (call) async {
          asked.add(call.name);
          return Approval.apply;
        },
      ),
    );
    expect(ran, ['draw', 'save']);
    expect(asked, ['save'], reason: 'an export is confirmed whatever was approved ahead');
    expect(turn.calls.firstWhere((x) => x.name == 'save').confirm, isTrue);
    expect(turn.calls.firstWhere((x) => x.name == 'draw').confirm, isFalse);
    // without the approval ahead, the change asks too
    ran.clear();
    final g = FakeClaude([
      (_) => FakeReply.tools([
        ('draw', {'x': 1}),
      ]),
      (_) => FakeReply.text('Drawn.'),
    ]);
    final cards = <String>[];
    await AgentLoop(api: api(g), tools: [tool('draw', effect: ToolEffect.write)]).run(
      model: AiModel.opus55,
      system: 's',
      history: const [],
      user: user('go'),
      permission: AgentPermission.ask,
      cancel: AiCancel(),
      events: AgentEvents(
        autoApprove: (_) => false,
        approve: (call) async {
          cards.add(call.name);
          return Approval.apply;
        },
      ),
    );
    expect(cards, ['draw']);
  });

  test('the effort follows the stage: an effort message after a plain round, back to the effort chosen after the others, the cached prefix kept', () async {
    final f = FakeClaude([
      (_) => FakeReply.tools([
        ('list', {'x': 1}),
      ]),
      (_) => FakeReply.tools([
        ('think', {'x': 1}),
      ]),
      (_) => FakeReply.text('Done.'),
    ]);
    final turn = await AgentLoop(api: api(f), tools: [tool('list'), tool('think')]).run(
      model: AiModel.opus55,
      effort: AiEffort.high,
      system: 's',
      history: const [],
      user: user('go'),
      cancel: AiCancel(),
      events: AgentEvents(stageEffort: (round, now) => round.every((x) => x.name == 'list') ? AiEffort.low : AiEffort.high),
    );
    List<Map> efforts(int n) => [
      for (final m in f.bodies[n]['messages'] as List)
        if ((m as Map)['role'] == 'system') m,
    ];
    expect(efforts(0), isEmpty);
    expect(efforts(1).single['output_config'], {'effort': 'low'});
    expect(efforts(1).single['content'], isEmpty);
    expect(efforts(2).last['output_config'], {'effort': 'high'});
    expect(f.requests[1].headers['anthropic-beta'], contains(AnthropicClient.effortBeta));
    expect((f.bodies[1]['output_config'] as Map)['effort'], 'high', reason: 'the request\'s own effort stays as it was: so does the cache');
    expect([for (final s in turn.stepStats) s.effort], [AiEffort.high, AiEffort.low, AiEffort.high]);
    // the turn keeps them: the conversation goes on from there
    expect(turn.messages.where((m) => m['role'] == 'system'), hasLength(2));
  });

  test('an effort message of a stage the API turns down leaves the conversation, and the step goes again without it', () async {
    final f = FakeClaude([
      (_) => FakeReply.tools([
        ('list', {'x': 1}),
      ]),
      (_) => FakeReply.error(400, 'invalid_request_error', 'messages.3: output_config: per-turn effort is not supported for this model'),
      (_) => FakeReply.text('Done.'),
    ]);
    final turn = await AgentLoop(api: api(f), tools: [tool('list')]).run(
      model: AiModel.opus55,
      effort: AiEffort.high,
      system: 's',
      history: const [],
      user: user('go'),
      cancel: AiCancel(),
      events: AgentEvents(stageEffort: (_, _) => AiEffort.low),
    );
    expect(f.calls, 3);
    expect(turn.stop, AgentStop.done);
    expect([for (final m in f.bodies[2]['messages'] as List) (m as Map)['role']], ['user', 'assistant', 'user']);
    expect(turn.messages.where((m) => m['role'] == 'system'), isEmpty);
  });

  test('the tokens a tool spends asking a model of its own count in the turn, its cost and its cap', () async {
    const spent = AiUsage(input: 40000, output: 900);
    final f = FakeClaude([
      (_) => FakeReply.tools([
        ('read', {'x': 1}),
      ]),
      (_) => FakeReply.text('Read.'),
    ]);
    final turn = await AgentLoop(
      api: api(f),
      tools: [tool('read', out: (_) => ToolOutput('the answer', spent: spent, spentCost: spent.cost(AiModel.haiku55), spentModel: 'claude-haiku-5-5'))],
    ).run(model: AiModel.opus55, system: 's', history: const [], user: user('go'), cancel: AiCancel());
    final sub = turn.stepStats.where((s) => s.subagent).single;
    expect(sub.model, 'claude-haiku-5-5');
    expect(sub.usage.input, 40000);
    expect(turn.usage.input, 2 * 1000 + 40000, reason: 'the two requests and the reading model');
    expect(turn.cost, closeTo(turn.stepStats.fold<double>(0, (x, s) => x + s.cost), 1e-12));
    expect(sub.cost, closeTo(spent.cost(AiModel.haiku55), 1e-12));
  });

  test('the connection test: one small request with what the assistant sends, its cost and the rate limits of the headers', () async {
    final f = FakeClaude([(_) => FakeReply.text('OK')]);
    Future<AiHttpResponse> withLimits(AiHttpRequest r, AiCancel cancel) async {
      final res = await f.call(r, cancel);
      return AiHttpResponse(res.status, {
        ...res.headers,
        'request-id': 'req_probe',
        'anthropic-ratelimit-requests-limit': '50',
        'anthropic-ratelimit-requests-remaining': '49',
        'anthropic-ratelimit-tokens-limit': '400000',
        'anthropic-ratelimit-tokens-remaining': '399000',
      }, res.body);
    }

    final p = await AnthropicClient(apiKey: key, transport: withLimits, browser: true).probe(AiModel.fable51, cancel: AiCancel());
    expect(p.ok, isTrue, reason: '${p.error}');
    expect(p.text, 'OK');
    expect(p.servedBy, 'claude-opus-5-5', reason: 'the scripted reply names its model');
    expect(p.usage.totalInput, 1500);
    expect(p.cost, greaterThan(0));
    expect(p.limits['requests-remaining'], '49');
    expect(p.limits['tokens-limit'], '400000');
    expect(p.requestId, 'req_probe');
    expect(p.declined, isEmpty);
    final b = f.bodies.single;
    expect(b['model'], 'claude-fable-5-1');
    expect(b['max_tokens'], AiHttpClient.probeTokens);
    expect((b['output_config'] as Map)['effort'], 'low');
    expect(b.containsKey('tools'), isFalse);
    expect(b['fallbacks'], 'default', reason: 'the fields of the real requests go with it');
    expect(b['context_management'], isNotNull);
    final edits = (b['context_management'] as Map)['edits'] as List;
    expect((edits.first as Map).containsKey('exclude_tools'), isFalse, reason: 'no tool to keep in a request without tools');
    expect(f.requests.single.headers['x-api-key'], key);
  });

  test('the connection test names the fields the account turns down (left out from then on) and the errors', () async {
    final f = FakeClaude([
      (_) => FakeReply.error(400, 'invalid_request_error', 'thinking.display: unknown beta thinking-display-updates-2026-08-18'),
      (_) => FakeReply.text('OK'),
    ]);
    final p = await api(f).probe(AiModel.sonnet55, cancel: AiCancel());
    expect(p.ok, isTrue);
    expect(p.declined, ['display']);
    expect(AiHttpClient.declined, contains('claude-sonnet-5-5:display'));
    expect((f.bodies[1]['thinking'] as Map?)?.containsKey('display') ?? false, isFalse);
    // a key refused: the error, never thrown
    final g = FakeClaude([(_) => FakeReply.error(401, 'authentication_error', 'invalid x-api-key')]);
    final q = await api(g).probe(AiModel.haiku55, cancel: AiCancel());
    expect(q.ok, isFalse);
    expect(q.error!.kind, AiErrorKind.auth);
    expect(q.limits, isEmpty);
    // OpenAI through the same request path
    final o = FakeOpenAi([(_) => OpenAiReply.text('OK')]);
    final r = await OpenAiClient(apiKey: 'sk-proj-TEST-OPENAI-KEY-0000', transport: o.call, sleep: (_) async {}).probe(AiModel.gpt6Luna, cancel: AiCancel());
    expect(r.ok, isTrue, reason: '${r.error}');
    expect(o.bodies.single['max_output_tokens'], AiHttpClient.probeTokens);
    expect((o.bodies.single['reasoning'] as Map)['effort'], 'low');
  });

  test('the rate limits of either company by name', () {
    expect(AiHttpClient.rateLimitsOf({'anthropic-ratelimit-requests-remaining': '9', 'x-ratelimit-remaining-tokens': '120', 'content-type': 'x'}), {
      'requests-remaining': '9',
      'remaining-tokens': '120',
    });
  });
}
