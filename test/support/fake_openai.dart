import 'dart:async';
import 'dart:convert';

import 'package:opencadirrigation/core/ai/openai_api.dart';

/// One scripted answer of [FakeOpenAi].
class OpenAiReply {
  OpenAiReply.text(this.text, {this.model = 'gpt-6-astra', this.compaction = false})
    : tools = const [],
      status = 200,
      code = '',
      type = '',
      mime = '',
      end = 'completed',
      reason = null,
      hang = false,
      cut = false,
      refusal = '';
  OpenAiReply.tools(this.tools, {this.text = '', this.model = 'gpt-6-astra', this.compaction = false})
    : status = 200,
      code = '',
      type = '',
      mime = '',
      end = 'completed',
      reason = null,
      hang = false,
      cut = false,
      refusal = '';

  /// An HTTP error with an OpenAI error body ([mime] text/plain: the raw text).
  OpenAiReply.error(this.status, this.code, this.text, {this.type = 'invalid_request_error', this.mime = 'application/json'})
    : tools = const [],
      model = '',
      end = '',
      reason = null,
      hang = false,
      cut = false,
      refusal = '',
      compaction = false;

  /// A response that fails in the stream (`response.failed`).
  OpenAiReply.failed(this.code, this.text)
    : tools = const [],
      status = 200,
      type = '',
      mime = '',
      model = 'gpt-6-astra',
      end = 'failed',
      reason = null,
      hang = false,
      cut = false,
      refusal = '',
      compaction = false;

  /// A response cut short (`response.incomplete`, e.g. max_output_tokens).
  OpenAiReply.incomplete(String this.reason, {this.text = '', this.tools = const []})
    : status = 200,
      code = '',
      type = '',
      mime = '',
      model = 'gpt-6-astra',
      end = 'incomplete',
      hang = false,
      cut = false,
      refusal = '',
      compaction = false;

  /// The model declines (a refusal content part).
  OpenAiReply.refusal(this.refusal)
    : text = '',
      tools = const [],
      status = 200,
      code = '',
      type = '',
      mime = '',
      model = 'gpt-6-astra',
      end = 'completed',
      reason = null,
      hang = false,
      cut = false,
      compaction = false;

  /// The connection opens and nothing ever arrives.
  OpenAiReply.hang() : text = '', tools = const [], status = 200, code = '', type = '', mime = '', model = '', end = '', reason = null, hang = true, cut = false, refusal = '', compaction = false;

  /// The stream stops before the response is complete.
  OpenAiReply.cut(this.text)
    : tools = const [],
      status = 200,
      code = '',
      type = '',
      mime = '',
      model = 'gpt-6-astra',
      end = '',
      reason = null,
      hang = false,
      cut = true,
      refusal = '',
      compaction = false;

  final String text;
  final List<(String, Map<String, dynamic>)> tools;
  final int status;
  final String code, type, mime, model, end;
  final String? reason;
  final bool hang, cut;
  final String refusal;

  /// A compaction item at the start of the output.
  final bool compaction;
}

/// A scripted OpenAI model: answers the requests in order with [script]
/// (each entry may read the request body) and records them.
class FakeOpenAi {
  FakeOpenAi(this.script);
  final List<OpenAiReply Function(Map<String, dynamic> body)> script;
  final requests = <AiHttpRequest>[];
  final bodies = <Map<String, dynamic>>[];
  var _n = 0;

  int get calls => requests.length;

  Future<AiHttpResponse> call(AiHttpRequest r, AiCancel cancel) async {
    requests.add(r);
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    bodies.add(body);
    final n = requests.length - 1;
    final reply = n < script.length ? script[n](body) : OpenAiReply.text('(end of script)');
    if (reply.status != 200) {
      final text = reply.mime == 'application/json'
          ? jsonEncode({
              'error': {'message': reply.text, 'type': reply.type, 'param': null, 'code': reply.code.isEmpty ? null : reply.code},
            })
          : reply.text;
      return AiHttpResponse(reply.status, {'content-type': reply.mime, 'x-request-id': 'req_test'}, Stream.value(utf8.encode(text)));
    }
    if (reply.hang) {
      final c = StreamController<List<int>>();
      cancel.onCancel(c.close);
      return AiHttpResponse(200, {'content-type': 'text/event-stream'}, c.stream);
    }
    var seq = 0;
    final events = <Map<String, dynamic>>[];
    void ev(String type, Map<String, dynamic> data) => events.add({'type': type, 'sequence_number': seq++, ...data});
    final resp = {'id': 'resp_$n', 'object': 'response', 'status': 'in_progress', 'model': reply.model, 'output': <Object?>[]};
    ev('response.created', {'response': resp});
    ev('response.in_progress', {'response': resp});
    final output = <Map<String, dynamic>>[];
    var i = 0;
    if (reply.compaction) {
      final it = {'id': 'cmp_$n', 'type': 'compaction', 'encrypted_content': 'compacted_$n'};
      ev('response.output_item.added', {'output_index': i, 'item': it});
      ev('response.output_item.done', {'output_index': i, 'item': it});
      output.add(it);
      i++;
    }
    final rs = {'id': 'rs_$n', 'type': 'reasoning', 'summary': <Object?>[]};
    ev('response.output_item.added', {'output_index': i, 'item': rs});
    final rsDone = {...rs, 'encrypted_content': 'enc_$n'};
    ev('response.output_item.done', {'output_index': i, 'item': rsDone});
    output.add(rsDone);
    i++;
    if ((reply.text.isNotEmpty && reply.end != 'failed') || reply.refusal.isNotEmpty) {
      final id = 'msg_$n';
      ev('response.output_item.added', {
        'output_index': i,
        'item': {'id': id, 'type': 'message', 'role': 'assistant', 'status': 'in_progress', 'content': <Object?>[]},
      });
      final Map<String, dynamic> part;
      if (reply.refusal.isNotEmpty) {
        ev('response.refusal.delta', {'item_id': id, 'output_index': i, 'content_index': 0, 'delta': reply.refusal});
        part = {'type': 'refusal', 'refusal': reply.refusal};
      } else {
        final half = reply.text.length ~/ 2;
        for (final d in [reply.text.substring(0, half), reply.text.substring(half)]) {
          ev('response.output_text.delta', {'item_id': id, 'output_index': i, 'content_index': 0, 'delta': d, 'logprobs': <Object?>[]});
        }
        part = {'type': 'output_text', 'text': reply.text, 'annotations': <Object?>[]};
      }
      if (reply.cut) {
        // the connection drops here
        return _send(events);
      }
      final msg = {
        'id': id,
        'type': 'message',
        'role': 'assistant',
        'status': 'completed',
        'content': [part],
      };
      ev('response.output_item.done', {'output_index': i, 'item': msg});
      output.add(msg);
      i++;
    }
    for (final (name, input) in reply.tools) {
      final json = jsonEncode(input);
      final id = 'fc_${++_n}';
      final call = {'id': id, 'type': 'function_call', 'call_id': 'call_$_n', 'name': name, 'arguments': '', 'status': 'in_progress'};
      ev('response.output_item.added', {'output_index': i, 'item': call});
      final half = json.length ~/ 2;
      for (final d in [json.substring(0, half), json.substring(half)]) {
        ev('response.function_call_arguments.delta', {'item_id': id, 'output_index': i, 'delta': d});
      }
      ev('response.function_call_arguments.done', {'item_id': id, 'output_index': i, 'arguments': json, 'name': name});
      final done = {...call, 'arguments': json, 'status': 'completed'};
      ev('response.output_item.done', {'output_index': i, 'item': done});
      output.add(done);
      i++;
    }
    final usage = {
      'input_tokens': 1500,
      'input_tokens_details': {'cached_tokens': 300, 'cache_write_tokens': 200},
      'output_tokens': 60,
      'output_tokens_details': {'reasoning_tokens': 10},
      'total_tokens': 1560,
    };
    switch (reply.end) {
      case 'completed':
        ev('response.completed', {
          'response': {...resp, 'status': 'completed', 'output': output, 'usage': usage},
        });
      case 'incomplete':
        ev('response.incomplete', {
          'response': {
            ...resp,
            'status': 'incomplete',
            'output': output,
            'usage': usage,
            'incomplete_details': {'reason': reply.reason},
          },
        });
      case 'failed':
        ev('response.failed', {
          'response': {
            ...resp,
            'status': 'failed',
            'output': output,
            'error': {'code': reply.code, 'message': reply.text},
          },
        });
    }
    return _send(events);
  }

  AiHttpResponse _send(List<Map<String, dynamic>> events) {
    final text = StringBuffer();
    for (final e in events) {
      text.write('event: ${e['type']}\ndata: ${jsonEncode(e)}\n\n');
    }
    final bytes = utf8.encode(text.toString());
    final chunks = <List<int>>[for (var k = 0; k < bytes.length; k += 89) bytes.sublist(k, k + 89 > bytes.length ? bytes.length : k + 89)];
    return AiHttpResponse(200, {'content-type': 'text/event-stream; charset=utf-8'}, Stream.fromIterable(chunks));
  }

  /// The input items of request [n] after the model's last output: function
  /// outputs and user messages, as text.
  String lastInputText(int n) {
    final items = [for (final x in bodies[n]['input'] as List) Map<String, dynamic>.from(x as Map)];
    var start = items.length;
    while (start > 0 && (items[start - 1]['type'] == 'function_call_output' || (items[start - 1]['type'] == 'message' && items[start - 1]['role'] != 'assistant'))) {
      start--;
    }
    return [
      for (final it in items.sublist(start))
        if (it['type'] == 'function_call_output')
          (it['output'] is String ? it['output'] : jsonEncode(it['output']))
        else
          for (final c in it['content'] as List)
            if ((c as Map)['type'] == 'input_text') c['text'],
    ].join('\n');
  }
}
