import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/ai/claude_api.dart';

import 'claude_contract.dart';

/// One scripted answer of [FakeClaude].
class FakeReply {
  FakeReply.text(this.text, {this.stopReason = 'end_turn', this.model = 'claude-opus-5-5', this.compaction})
    : tools = const [],
      status = 200,
      errorType = '',
      headers = const {},
      hang = false,
      streamError = null,
      category = null;
  FakeReply.tools(this.tools, {this.text = '', this.model = 'claude-opus-5-5', this.stopReason = 'tool_use', this.compaction})
    : status = 200,
      errorType = '',
      headers = const {},
      hang = false,
      streamError = null,
      category = null;
  FakeReply.error(this.status, this.errorType, this.text, {this.headers = const {}})
    : tools = const [],
      stopReason = '',
      model = '',
      hang = false,
      streamError = null,
      compaction = null,
      category = null;

  /// A request the safety classifiers declined (HTTP 200, `refusal`).
  FakeReply.refusal(String this.category, {this.text = ''})
    : tools = const [],
      stopReason = 'refusal',
      model = 'claude-opus-5-5',
      status = 200,
      errorType = '',
      headers = const {},
      hang = false,
      streamError = null,
      compaction = null;

  /// The connection opens and nothing ever arrives (for cancellation).
  FakeReply.hang() : tools = const [], text = '', stopReason = '', model = '', status = 200, errorType = '', headers = const {}, hang = true, streamError = null, compaction = null, category = null;

  /// An `error` event in the middle of the stream.
  FakeReply.streamError(String type, {this.text = 'Overloaded'})
    : tools = const [],
      stopReason = '',
      model = '',
      status = 200,
      errorType = '',
      headers = const {},
      hang = false,
      streamError = type,
      compaction = null,
      category = null;

  final String text;
  final List<(String, Map<String, dynamic>)> tools;
  final String stopReason, model, errorType;
  final int status;
  final Map<String, String> headers;
  final bool hang;
  final String? streamError;

  /// A compaction block (with this summary) at the start of the answer.
  final String? compaction;

  /// `stop_details.category` of a refusal.
  final String? category;
}

/// A scripted Claude: answers the requests in order with [script] (each
/// entry may read the request body) and records them. With [contract] (the
/// default) every request is checked as the real API would check it
/// ([ClaudeContract]: tool calls and results paired, no empty text, at most
/// four cache breakpoints, betas with their fields, and the conversation
/// sent again byte for byte), and the test fails on the problems found
/// ([violations]); a test that rewinds a conversation on purpose turns it
/// off.
class FakeClaude {
  FakeClaude(this.script, {this.contract = true}) {
    if (!contract) return;
    try {
      addTearDown(() => expect(violations, isEmpty, reason: 'requests the Messages API would refuse, or that lose the cache and the earlier reasoning'));
    } catch (_) {
      // made outside a test: the caller checks [violations]
    }
  }
  final List<FakeReply Function(Map<String, dynamic> body)> script;
  final bool contract;
  final _checker = ClaudeContract();

  /// What [ClaudeContract] found wrong in the requests, by request.
  final violations = <String>[];
  final requests = <AiHttpRequest>[];
  final bodies = <Map<String, dynamic>>[];
  var _tool = 0;

  int get calls => requests.length;

  Future<AiHttpResponse> call(AiHttpRequest r, AiCancel cancel) async {
    requests.add(r);
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    bodies.add(body);
    final n = requests.length - 1;
    if (contract) {
      for (final p in _checker.check(body, r.headers)) {
        violations.add('request ${n + 1}: $p');
      }
    }
    final reply = n < script.length ? script[n](body) : FakeReply.text('(end of script)');
    // a refused request, or a compaction: the next one starts the comparison anew
    if (reply.status != 200 || reply.compaction != null || reply.streamError != null || reply.hang) _checker.reset();
    if (reply.status != 200) {
      final err = jsonEncode({
        'type': 'error',
        'error': {'type': reply.errorType, 'message': reply.text},
        'request_id': 'req_test',
      });
      return AiHttpResponse(reply.status, {'content-type': 'application/json', ...reply.headers}, Stream.value(utf8.encode(err)));
    }
    if (reply.hang) {
      final c = StreamController<List<int>>();
      cancel.onCancel(c.close);
      return AiHttpResponse(200, {'content-type': 'text/event-stream'}, c.stream);
    }
    final events = <Map<String, dynamic>>[
      {
        'type': 'message_start',
        'message': {
          'id': 'msg_$n',
          'type': 'message',
          'role': 'assistant',
          'model': reply.model,
          'content': [],
          'usage': {'input_tokens': 1000, 'output_tokens': 1, 'cache_creation_input_tokens': 200, 'cache_read_input_tokens': 300},
        },
      },
    ];
    if (reply.streamError != null) {
      events.add({
        'type': 'error',
        'error': {'type': reply.streamError, 'message': reply.text},
      });
    } else {
      var i = -1;
      if (reply.compaction != null) {
        i++;
        events
          ..add({
            'type': 'content_block_start',
            'index': i,
            'content_block': {'type': 'compaction', 'content': ''},
          })
          ..add({
            'type': 'content_block_delta',
            'index': i,
            'delta': {'type': 'compaction_delta', 'content': reply.compaction},
          })
          ..add({'type': 'content_block_stop', 'index': i});
      }
      i++;
      events
        ..add({
          'type': 'content_block_start',
          'index': i,
          'content_block': {'type': 'thinking', 'thinking': '', 'signature': ''},
        })
        ..add({
          'type': 'content_block_delta',
          'index': i,
          'delta': {'type': 'thinking_delta', 'thinking': ''},
        })
        ..add({
          'type': 'content_block_delta',
          'index': i,
          'delta': {'type': 'signature_delta', 'signature': 'sig$n'},
        })
        ..add({'type': 'content_block_stop', 'index': i})
        ..add({'type': 'ping'});
      if (reply.text.isNotEmpty && reply.stopReason != 'refusal') {
        i++;
        final half = reply.text.length ~/ 2;
        events
          ..add({
            'type': 'content_block_start',
            'index': i,
            'content_block': {'type': 'text', 'text': ''},
          })
          ..add({
            'type': 'content_block_delta',
            'index': i,
            'delta': {'type': 'text_delta', 'text': reply.text.substring(0, half)},
          })
          ..add({
            'type': 'content_block_delta',
            'index': i,
            'delta': {'type': 'text_delta', 'text': reply.text.substring(half)},
          })
          ..add({'type': 'content_block_stop', 'index': i});
      }
      for (final (name, input) in reply.tools) {
        i++;
        final json = jsonEncode(input);
        final half = json.length ~/ 2;
        events
          ..add({
            'type': 'content_block_start',
            'index': i,
            'content_block': {'type': 'tool_use', 'id': 'toolu_${++_tool}', 'name': name, 'input': {}},
          })
          ..add({
            'type': 'content_block_delta',
            'index': i,
            'delta': {'type': 'input_json_delta', 'partial_json': ''},
          })
          ..add({
            'type': 'content_block_delta',
            'index': i,
            'delta': {'type': 'input_json_delta', 'partial_json': json.substring(0, half)},
          })
          ..add({
            'type': 'content_block_delta',
            'index': i,
            'delta': {'type': 'input_json_delta', 'partial_json': json.substring(half)},
          })
          ..add({'type': 'content_block_stop', 'index': i});
      }
      events
        ..add({
          'type': 'message_delta',
          'delta': {
            'stop_reason': reply.stopReason,
            'stop_sequence': null,
            if (reply.category != null) 'stop_details': {'type': 'refusal', 'category': reply.category, 'explanation': reply.text},
          },
          'usage': {
            'output_tokens': 50,
            if (reply.compaction != null)
              'iterations': [
                {'type': 'compaction', 'input_tokens': 160000, 'output_tokens': 2000},
                {'type': 'message', 'input_tokens': 1000, 'output_tokens': 50},
              ],
          },
        })
        ..add({'type': 'message_stop'});
    }
    final text = StringBuffer();
    for (final e in events) {
      text.write('event: ${e['type']}\ndata: ${jsonEncode(e)}\n\n');
    }
    // chunks cut in the middle of lines, as the network delivers them
    final bytes = utf8.encode(text.toString());
    final chunks = <List<int>>[for (var k = 0; k < bytes.length; k += 97) bytes.sublist(k, k + 97 > bytes.length ? bytes.length : k + 97)];
    return AiHttpResponse(200, {'content-type': 'text/event-stream; charset=utf-8'}, Stream.fromIterable(chunks));
  }

  /// The text of the last user message of request [n] (tool results joined).
  String lastUserText(int n) {
    final msgs = bodies[n]['messages'] as List;
    final last = msgs.lastWhere((m) => (m as Map)['role'] == 'user') as Map;
    final content = last['content'];
    if (content is String) return content;
    return [
      for (final b in content as List)
        if (b['type'] == 'text') b['text'] else if (b['type'] == 'tool_result') (b['content'] is String ? b['content'] : jsonEncode(b['content'])),
    ].join('\n');
  }
}
