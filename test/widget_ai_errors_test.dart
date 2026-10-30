import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/ai/ai_assistant.dart';
import 'package:opencadirrigation/app/io/prefs.dart';
import 'package:opencadirrigation/app/io/project_store.dart';
import 'package:opencadirrigation/app/state/controller.dart';
import 'package:opencadirrigation/app/state/design_runner.dart';
import 'package:opencadirrigation/core/ai/agent_loop.dart';

import 'support/fake_claude.dart';

/// Server-sent events of a whole streamed message.
String events(List<Map<String, dynamic>> list) => [for (final e in list) 'event: ${e['type']}\ndata: ${jsonEncode(e)}\n\n'].join();

Map<String, dynamic> start({String model = 'claude-opus-5-5'}) => {
  'type': 'message_start',
  'message': {
    'id': 'msg',
    'type': 'message',
    'role': 'assistant',
    'model': model,
    'content': [],
    'usage': {'input_tokens': 10, 'output_tokens': 1},
  },
};

List<Map<String, dynamic>> stop(String reason, {Map<String, dynamic>? details}) => [
  {
    'type': 'message_delta',
    'delta': {'stop_reason': reason, 'stop_details': ?details},
    'usage': {'output_tokens': 5},
  },
  {'type': 'message_stop'},
];

/// The errors and the status line of the assistant as the user reads them:
/// each failure named for what it is, with what to do, the wait and the
/// request id where they help; the model's notes between tool calls and
/// retries after a lost connection in the status line.
void main() {
  const key = 'sk-ant-api03-TEST-ERRORS-0000';
  late ProjectController c;
  AiAssistant ai() => AiAssistant.of(c);

  setUp(() async {
    LocalProjectStore().clearAll();
    for (final k in ['ai.model', 'ai.effort', 'ai.mode', 'ai.steps', 'ai.parts', 'ai.cap', 'ai.compact', 'ai.showChanges', 'ai.instructions']) {
      removePref(k);
    }
    // the picture after each round renders in real time only: on where a test asks for it
    setPref('ai.showChanges', 'off');
    AiAssistant.clearSessionKey();
    AiHttpClient.declined.clear();
    c = ProjectController()
      ..autosaveEnabled = false
      ..designRunner = InThreadDesignRunner();
    c.newProject();
    await c.setLanguage('en', persist: false);
    AiAssistant.debugSleep = (_) async {};
    AiAssistant.debugBrowser = true;
    setPref(AiAssistant.keyPref, key);
  });
  tearDown(() {
    AiAssistant.debugTransport = null;
    AiAssistant.debugSleep = null;
    AiAssistant.debugBrowser = null;
    AiAssistant.clearSessionKey();
    removePref(AiAssistant.keyPref);
  });

  /// The error shown after sending a question answered by [transport].
  Future<String?> errorFor(WidgetTester tester, AiTransport transport, {String question = 'Hello?'}) async {
    AiAssistant.debugTransport = transport;
    ai().clear();
    await tester.runAsync(() => ai().send(question));
    return ai().items.last.error;
  }

  AiTransport error(int status, String type, String message, {Map<String, String> headers = const {}, Map<String, dynamic>? details}) =>
      (r, cancel) async => AiHttpResponse(
        status,
        {'content-type': 'application/json', ...headers},
        Stream.value(
          utf8.encode(
            jsonEncode({
              'type': 'error',
              'error': {'type': type, 'message': message, 'details': ?details},
              'request_id': 'req_test',
            }),
          ),
        ),
      );

  testWidgets('each failure named for what it is, with what to do', (tester) async {
    final t = c.t;
    const m = 'Claude Opus 5.5';
    final args = {'p': 'Anthropic', 'h': 'api.anthropic.com', 'm': m, 'u': AiProvider.anthropic.billingUrl};
    expect(
      await errorFor(tester, error(400, 'invalid_request_error', 'Your credit balance is too low to access the Anthropic API. Please go to Plans & Billing to upgrade or purchase credits.')),
      t('ai.err.credit', args),
    );
    expect(await errorFor(tester, error(400, 'invalid_request_error', 'prompt is too long: 1050000 tokens > 1000000 maximum')), t('ai.err.context', args));
    const capped = 'You have reached your API usage limits: your organization has crossed its monthly API usage threshold. You will regain access on 2026-11-01 at 00:00 UTC.';
    expect(await errorFor(tester, error(429, 'rate_limit_error', capped, details: {'error_code': 'enforced_spend_limit_reached'})), '${t('ai.err.spendLimit', args)} ($capped)');
    expect(await errorFor(tester, error(429, 'rate_limit_error', 'Slow down', headers: {'retry-after': '120'})), t('ai.err.rateLimitWait', {...args, 'w': '2 min'}));
    expect(
      await errorFor(tester, error(400, 'invalid_request_error', 'messages.0.content.0: unknown block')),
      '${t('ai.err.invalid', {'m': 'messages.0.content.0: unknown block'})} ${t('ai.err.requestId', {'r': 'req_test'})}',
    );
    expect(t('ai.err.requestId', {'r': 'req_test'}), '(request id: req_test)');
    // a refusal: the category, the hint, and the model that could have answered
    final declined = await errorFor(
      tester,
      (r, cancel) async => AiHttpResponse(
        200,
        {'content-type': 'text/event-stream'},
        Stream.value(
          utf8.encode(
            events([
              start(),
              ...stop('refusal', details: {'type': 'refusal', 'category': 'cyber', 'explanation': 'Declined by a classifier.', 'recommended_model': 'claude-opus-4-8'}),
            ]),
          ),
        ),
      ),
    );
    expect(
      declined,
      [t('ai.err.refusalCat', {...args, 'c': t('ai.err.cat.cyber')}), '(Declined by a classifier.)', t('ai.err.refusalHint'), t('ai.err.refusalBusy', {'r': 'Claude Opus 4.8'})].join(' '),
    );
    final reasoning = await errorFor(tester, FakeClaude([(_) => FakeReply.refusal('reasoning_extraction')]).call);
    expect(reasoning, '${t('ai.err.refusal', args)} ${t('ai.err.refusalReasoning')}');
    // a full context window while answering is not "cut at the length limit"
    final full = await errorFor(
      tester,
      (r, cancel) async => AiHttpResponse(
        200,
        {'content-type': 'text/event-stream'},
        Stream.value(
          utf8.encode(
            events([
              start(),
              {
                'type': 'content_block_start',
                'index': 0,
                'content_block': {'type': 'text', 'text': 'Part of it'},
              },
              {'type': 'content_block_stop', 'index': 0},
              ...stop('model_context_window_exceeded'),
            ]),
          ),
        ),
      ),
    );
    expect(full, t('ai.err.context', args));
    // too large to send: said before the upload, with the sizes
    ai().clear();
    final requests = <AiHttpRequest>[];
    AiAssistant.debugTransport = (r, cancel) async {
      requests.add(r);
      throw StateError('never sent');
    };
    ai().addAttachment(AiAttachment('notes.txt', 'text/plain', Uint8List.fromList(List.filled(31000000, 0x61))));
    await tester.runAsync(() => ai().send('Read this.'));
    expect(requests, isEmpty);
    expect(ai().items.last.error, t('ai.err.tooLargeConv', {'s': '32', 'l': '30'}));
    expect(ai().attachments.single.name, 'notes.txt', reason: 'nothing was kept: the file is back in the input');
  });

  testWidgets('the status line: the model\'s note between tool calls, and a retry after a lost connection', (tester) async {
    const note = 'Reading the drawing first.';
    final seen = <String>[];
    var n = 0;
    AiAssistant.debugTransport = (r, cancel) async {
      final k = n++;
      if (k == 0) throw AiError(AiErrorKind.network);
      final body = StreamController<List<int>>();
      () async {
        body.add(
          utf8.encode(
            events([
              start(),
              {
                'type': 'content_block_start',
                'index': 0,
                'content_block': {'type': 'thinking', 'thinking': '', 'signature': ''},
              },
              {
                'type': 'content_block_delta',
                'index': 0,
                'delta': {'type': 'thinking_delta', 'thinking': note},
              },
            ]),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        seen.add(ai().items.last.status);
        body.add(
          utf8.encode(
            events([
              {
                'type': 'content_block_delta',
                'index': 0,
                'delta': {'type': 'signature_delta', 'signature': 'sig'},
              },
              {'type': 'content_block_stop', 'index': 0},
              {
                'type': 'content_block_start',
                'index': 1,
                'content_block': {'type': 'text', 'text': 'All set.'},
              },
              {'type': 'content_block_stop', 'index': 1},
              ...stop('end_turn'),
            ]),
          ),
        );
        await body.close();
      }();
      return AiHttpResponse(200, {'content-type': 'text/event-stream'}, body.stream);
    };
    AiAssistant.debugSleep = (_) async => seen.add(ai().items.last.status);
    await tester.runAsync(() => ai().send('Go.'));
    expect(seen, [
      c.t('ai.status.retryNet', {'s': '2'}),
      c.t('ai.status.note', {'m': 'Claude Opus 5.5', 'x': note}),
    ]);
    expect(ai().items.last.text, 'All set.');
    expect(ai().items.last.error, isNull);
  });
}
