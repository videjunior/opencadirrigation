// isolates are slow to start when the machine is busy with the rest of the suite
@Timeout(Duration(minutes: 3))
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/mcp/json_schema.dart';
import 'package:opencadirrigation/core/mcp/mcp_server.dart';

import '../../bin/src/oci_mcp_io.dart';

/// The protocol layer of the MCP server (lib/core/mcp/mcp_server.dart) on
/// tools of its own, driven line by line: both kinds of revision, the
/// JSON-RPC errors, argument validation, cancellation, the time limit,
/// progress, subscriptions, resources and prompts (docs/MCP.md).
void main() {
  const modern = {'io.modelcontextprotocol/protocolVersion': '2026-07-28', 'io.modelcontextprotocol/clientCapabilities': <String, Object?>{}};

  test('the validator follows the JSON Schema keywords it supports', () {
    const schema = {
      'type': 'object',
      'properties': {
        'name': {'type': 'string', 'minLength': 1, 'maxLength': 5},
        'n': {'type': 'integer', 'minimum': 1, 'maximum': 3},
        'x': {'type': 'number', 'exclusiveMinimum': 0},
        'kind': {
          'enum': ['a', 'b'],
        },
        'code': {'type': 'string', 'pattern': r'^[A-Z]{3}$'},
        'list': {
          'type': 'array',
          'minItems': 1,
          'maxItems': 2,
          'items': {'type': 'boolean'},
        },
        'ref': {
          'type': ['object', 'null'],
        },
      },
      'required': ['name'],
      'additionalProperties': false,
    };
    expect(schemaProblems(schema), isEmpty);
    expect(
      schemaErrors({
        'name': 'abc',
        'n': 2,
        'x': 0.5,
        'kind': 'a',
        'code': 'BRL',
        'list': [true],
        'ref': null,
      }, schema),
      isEmpty,
    );
    // a whole number may come as 2.0 (and on the web every number is a double)
    expect(schemaErrors({'name': 'abc', 'n': 2.0}, schema), isEmpty);
    expect(schemaErrors(<String, Object?>{}, schema), ['arguments.name: required']);
    expect(schemaErrors({'name': ''}, schema).single, contains('must not be empty'));
    expect(schemaErrors({'name': 'abcdef'}, schema).single, contains('at most 5 characters'));
    expect(schemaErrors({'name': 'a', 'n': 2.5}, schema).single, contains('must be a whole number'));
    expect(schemaErrors({'name': 'a', 'n': 4}, schema).single, contains('at most 3'));
    expect(schemaErrors({'name': 'a', 'x': 0}, schema).single, contains('more than 0'));
    expect(schemaErrors({'name': 'a', 'kind': 'c'}, schema).single, 'arguments.kind: must be one of a, b (got "c")');
    expect(schemaErrors({'name': 'a', 'code': 'brl'}, schema).single, contains('"brl" is not valid'));
    expect(schemaErrors({'name': 'a', 'list': []}, schema).single, contains('must not be empty'));
    expect(
      schemaErrors({
        'name': 'a',
        'list': [1],
      }, schema).single,
      startsWith('arguments.list[0]: must be a boolean'),
    );
    expect(
      schemaErrors({
        'name': 'a',
        'list': [true, true, true],
      }, schema).single,
      contains('at most 2 items'),
    );
    expect(schemaErrors({'name': 'a', 'frob': 1}, schema).single, contains('unknown argument "frob"'));
    expect(schemaErrors('text', schema).single, contains('must be an object'));
    // a schema with a keyword it cannot check is refused, not trusted
    expect(schemaProblems({'type': 'object', r'$ref': '#/x'}), [contains(r'"$ref" is not supported')]);
    expect(schemaProblems({'type': 'thing'}), isNotEmpty);
    expect(
      schemaProblems({
        'required': ['a'],
      }),
      [contains('"a" is required but has no property')],
    );
  });

  late List<Map<String, dynamic>> sent;
  late McpServer server;
  late Completer<void> slowGate;
  var slowStarted = 0;

  McpServer make({McpExecutor executor = const InlineExecutor(), Duration timeLimit = const Duration(minutes: 1), Duration heartbeat = const Duration(seconds: 5)}) => McpServer(
    info: const McpImplementation(name: 'test-server', version: '9.9'),
    instructions: 'be nice',
    executor: executor,
    timeLimit: timeLimit,
    heartbeat: heartbeat,
    send: (m) {
      expect(m, isNot(contains('\n')), reason: 'one message per line');
      sent.add(jsonDecode(m) as Map<String, dynamic>);
    },
    tools: [
      McpTool(
        name: 'echo',
        title: 'Echo',
        description: 'Gives the text back.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'text': {'type': 'string', 'minLength': 1},
          },
          'required': ['text'],
          'additionalProperties': false,
        },
        outputSchema: const {
          'type': 'object',
          'properties': {
            'text': {'type': 'string'},
          },
        },
        annotations: const McpToolAnnotations.reading(),
        call: (a) async => McpToolResult.ok({'text': a['text']}),
      ),
      McpTool(
        name: 'fail',
        title: 'Fail',
        description: 'Fails as a tool does.',
        inputSchema: const {'type': 'object', 'additionalProperties': false},
        annotations: const McpToolAnnotations.reading(),
        call: (a) async => throw McpToolError('no such field'),
      ),
      McpTool(
        name: 'slow',
        title: 'Slow',
        description: 'Waits for the test.',
        inputSchema: const {'type': 'object'},
        annotations: const McpToolAnnotations(readOnly: false, destructive: true),
        call: (a) async {
          slowStarted++;
          await slowGate.future;
          return McpToolResult.ok({'done': true});
        },
      ),
      McpTool(name: 'spin', title: 'Spin', description: 'Never ends, and never yields.', inputSchema: const {'type': 'object'}, annotations: const McpToolAnnotations.reading(), call: _spin),
    ],
    resources: [
      McpResource(
        uri: 'test://a',
        name: 'a',
        title: 'A',
        description: 'a resource',
        mimeType: 'text/plain',
        read: () => const McpResourceContents(text: 'hello', mimeType: 'text/plain'),
      ),
      McpResource(uri: 'test://gone', name: 'gone', title: 'Gone', description: 'not there', mimeType: 'text/plain', read: () => null),
    ],
    prompts: [
      McpPrompt(
        name: 'greet',
        title: 'Greet',
        description: 'Greets someone.',
        arguments: const [McpPromptArgument(name: 'who', description: 'who', required: true)],
        text: (a) => 'Hello ${a['who']}',
      ),
    ],
  );

  setUp(() {
    sent = [];
    slowGate = Completer<void>();
    slowStarted = 0;
    server = make();
  });

  void send(Object message) => server.receive(message is String ? message : jsonEncode(message));

  Future<Map<String, dynamic>> reply(Object id, String method, [Map<String, Object?>? params, bool withMeta = true]) async {
    send({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': {...?params, if (withMeta) '_meta': modern},
    });
    for (var i = 0; i < 2000; i++) {
      final hit = sent.where((m) => m['id'] == id && (m.containsKey('result') || m.containsKey('error')));
      if (hit.isNotEmpty) return hit.first;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('no reply to $method');
  }

  test('the 2026-07-28 revision: per-request version, result type, server identity, cache hints, discover', () async {
    final d = await reply(1, 'server/discover');
    final r = d['result'] as Map<String, dynamic>;
    expect(r['resultType'], 'complete');
    expect(r['supportedVersions'], ['2026-07-28', '2025-11-25', '2025-06-18']);
    expect(r['capabilities'], {'tools': {}, 'resources': {}, 'prompts': {}});
    expect(r['instructions'], 'be nice');
    expect(r['ttlMs'], greaterThan(0));
    expect(r['cacheScope'], 'public');
    expect((r['_meta'] as Map)['io.modelcontextprotocol/serverInfo'], {'name': 'test-server', 'version': '9.9'});
    final list = (await reply(2, 'tools/list'))['result'] as Map<String, dynamic>;
    expect(list['resultType'], 'complete');
    expect([for (final t in list['tools'] as List) t['name']], ['echo', 'fail', 'slow', 'spin']);
    expect(list['ttlMs'], greaterThan(0));
    final echo = (list['tools'] as List).first as Map<String, dynamic>;
    expect(echo['annotations'], {'title': 'Echo', 'readOnlyHint': true, 'openWorldHint': false});
    expect(echo['outputSchema'], isNotNull);
    expect(((list['tools'] as List)[2] as Map)['annotations'], {'title': 'Slow', 'readOnlyHint': false, 'destructiveHint': true, 'idempotentHint': false, 'openWorldHint': false});
    final call =
        (await reply(3, 'tools/call', {
              'name': 'echo',
              'arguments': {'text': 'hi'},
            }))['result']
            as Map<String, dynamic>;
    expect(call['resultType'], 'complete');
    expect(call['isError'], isFalse);
    expect(call['structuredContent'], {'text': 'hi'});
    expect(jsonDecode((call['content'] as List).single['text'] as String), {'text': 'hi'});
    expect(server.legacyVersion, isNull, reason: 'no state from modern requests');
  });

  test('version negotiation: an unknown revision, a missing _meta, missing capabilities', () async {
    send({
      'jsonrpc': '2.0',
      'id': 'v',
      'method': 'tools/list',
      'params': {
        '_meta': {'io.modelcontextprotocol/protocolVersion': '1900-01-01', 'io.modelcontextprotocol/clientCapabilities': {}},
      },
    });
    final e = sent.last['error'] as Map<String, dynamic>;
    expect(sent.last['id'], 'v');
    expect(e['code'], -32022);
    expect(e['data'], {
      'supported': ['2026-07-28', '2025-11-25', '2025-06-18'],
      'requested': '1900-01-01',
    });
    // neither _meta nor a handshake
    final none = await reply(4, 'tools/list', null, false);
    expect((none['error'] as Map)['code'], -32602);
    expect((none['error'] as Map)['message'], contains('initialize'));
    // the version without the capabilities
    send({
      'jsonrpc': '2.0',
      'id': 5,
      'method': 'tools/list',
      'params': {
        '_meta': {'io.modelcontextprotocol/protocolVersion': '2026-07-28'},
      },
    });
    expect((sent.last['error'] as Map)['code'], -32602);
    expect((sent.last['error'] as Map)['message'], contains('clientCapabilities'));
  });

  test('the handshake revisions: initialize negotiates, then requests need no _meta', () async {
    final init = await reply(1, 'initialize', {
      'protocolVersion': '2025-06-18',
      'capabilities': {},
      'clientInfo': {'name': 'old', 'version': '1'},
    }, false);
    final r = init['result'] as Map<String, dynamic>;
    expect(r['protocolVersion'], '2025-06-18');
    expect(r['serverInfo'], {'name': 'test-server', 'version': '9.9'});
    expect(r['capabilities'], contains('tools'));
    expect(r.containsKey('resultType'), isFalse, reason: 'the shapes of that revision');
    send({'jsonrpc': '2.0', 'method': 'notifications/initialized'});
    expect(server.initialized, isTrue);
    expect(sent.length, 1, reason: 'no reply to a notification');
    final list = (await reply(2, 'tools/list', null, false))['result'] as Map<String, dynamic>;
    expect(list.containsKey('ttlMs'), isFalse);
    expect((list['tools'] as List).length, 4);
    expect((await reply(3, 'ping', null, false))['result'], <String, Object?>{});
    final call =
        (await reply(4, 'tools/call', {
              'name': 'echo',
              'arguments': {'text': 'x'},
            }, false))['result']
            as Map<String, dynamic>;
    expect(call['structuredContent'], {'text': 'x'});
    expect(call.containsKey('resultType'), isFalse);
    // a revision the server does not have: the newest handshake one
    final other = await reply(5, 'initialize', {'protocolVersion': '2024-11-05', 'capabilities': {}}, false);
    expect((other['result'] as Map)['protocolVersion'], '2025-11-25');
    final latest = await reply(6, 'initialize', {'protocolVersion': '2025-11-25', 'capabilities': {}}, false);
    expect((latest['result'] as Map)['protocolVersion'], '2025-11-25');
    // a modern request is still served in its own way next to the session
    expect(((await reply(7, 'tools/list'))['result'] as Map)['resultType'], 'complete');
  });

  test('JSON-RPC errors: not JSON, a batch, no object, no version, null id, unknown method, bad params', () async {
    send('{not json');
    expect(sent.last, {
      'jsonrpc': '2.0',
      'id': null,
      'error': {'code': -32700, 'message': 'Parse error: the line is not JSON'},
    });
    send('[{"jsonrpc":"2.0","id":1,"method":"ping"}]');
    expect((sent.last['error'] as Map)['code'], -32600);
    send('42');
    expect((sent.last['error'] as Map)['code'], -32600);
    send({'id': 1, 'method': 'ping'});
    expect((sent.last['error'] as Map)['code'], -32600);
    expect(sent.last['id'], 1);
    send({'jsonrpc': '2.0', 'id': null, 'method': 'ping'});
    expect((sent.last['error'] as Map)['code'], -32600);
    send({'jsonrpc': '2.0', 'id': 2});
    expect((sent.last['error'] as Map)['code'], -32600);
    final unknown = await reply(3, 'resources/subscribe');
    expect((unknown['error'] as Map)['code'], -32601);
    send({
      'jsonrpc': '2.0',
      'id': 4,
      'method': 'tools/list',
      'params': [1, 2],
    });
    expect((sent.last['error'] as Map)['code'], -32602);
    expect((await reply(5, 'tools/list', {'cursor': 'abc'}))['error'], containsPair('code', -32602));
    expect((await reply(6, 'tools/call', {'name': 'nope'}))['error'], {'code': -32602, 'message': 'Unknown tool: nope'});
    expect((await reply(7, 'tools/call', {'arguments': {}}))['error'], containsPair('code', -32602));
    expect((await reply(8, 'tools/call', {'name': 'echo', 'arguments': 'text'}))['error'], containsPair('code', -32602));
    // a response from the client and an unknown notification: nothing back
    final before = sent.length;
    send({'jsonrpc': '2.0', 'id': 99, 'result': {}});
    send({'jsonrpc': '2.0', 'method': 'notifications/whatever'});
    send('   ');
    expect(sent.length, before);
    server.rejectTooLong();
    expect((sent.last['error'] as Map)['code'], -32700);
  });

  test('invalid arguments and tool failures are tool results with isError, for the model to correct', () async {
    final bad =
        (await reply(1, 'tools/call', {
              'name': 'echo',
              'arguments': {'text': '', 'more': 1},
            }))['result']
            as Map<String, dynamic>;
    expect(bad['isError'], isTrue);
    final text = (bad['content'] as List).single['text'] as String;
    expect(text, contains('Invalid arguments for echo'));
    expect(text, contains('arguments.text: must not be empty'));
    expect(text, contains('unknown argument "more"'));
    expect(bad.containsKey('structuredContent'), isFalse);
    final missing = (await reply(2, 'tools/call', {'name': 'echo'}))['result'] as Map<String, dynamic>;
    expect((missing['content'] as List).single['text'], contains('arguments.text: required'));
    final failed = (await reply(3, 'tools/call', {'name': 'fail'}))['result'] as Map<String, dynamic>;
    expect(failed['isError'], isTrue);
    expect((failed['content'] as List).single['text'], 'no such field');
  });

  test('a cancelled call gets no response; a call id in use is refused', () async {
    send({
      'jsonrpc': '2.0',
      'id': 'c1',
      'method': 'tools/call',
      'params': {'name': 'slow', '_meta': modern},
    });
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(slowStarted, 1);
    expect(server.inFlight, 1);
    send({
      'jsonrpc': '2.0',
      'id': 'c1',
      'method': 'tools/call',
      'params': {'name': 'echo', '_meta': modern},
    });
    expect((sent.last['error'] as Map)['code'], -32600);
    // cancelling an id nobody knows is ignored
    send({
      'jsonrpc': '2.0',
      'method': 'notifications/cancelled',
      'params': {'requestId': 'nobody'},
    });
    send({
      'jsonrpc': '2.0',
      'method': 'notifications/cancelled',
      'params': {'requestId': 'c1', 'reason': 'the user stopped it'},
    });
    await Future<void>.delayed(const Duration(milliseconds: 20));
    slowGate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(sent.where((m) => m['id'] == 'c1' && m.containsKey('result')), isEmpty);
    expect(server.inFlight, 0);
    // the writing tools wait for each other; the server goes on answering
    expect(
      ((await reply('after', 'tools/call', {
            'name': 'echo',
            'arguments': {'text': 'ok'},
          }))['result']
          as Map)['isError'],
      isFalse,
    );
  });

  test('a call in an isolate is killed by a cancellation, even one that never yields', () async {
    server = make(executor: const IsolateExecutor());
    send({
      'jsonrpc': '2.0',
      'id': 7,
      'method': 'tools/call',
      'params': {'name': 'spin', '_meta': modern},
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // the server is free while the isolate spins
    expect((await reply(8, 'server/discover'))['result'], isNotNull);
    send({
      'jsonrpc': '2.0',
      'method': 'notifications/cancelled',
      'params': {'requestId': 7},
    });
    for (var i = 0; i < 1000 && server.inFlight > 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(server.inFlight, 0);
    expect(sent.where((m) => m['id'] == 7), isEmpty);
  });

  test('the time limit stops a call with a message', () async {
    server = make(executor: const IsolateExecutor(), timeLimit: const Duration(milliseconds: 400));
    final r = (await reply(1, 'tools/call', {'name': 'spin'}))['result'] as Map<String, dynamic>;
    expect(r['isError'], isTrue);
    expect((r['content'] as List).single['text'], contains('was stopped after'));
  });

  test('a progress token gets notifications while the call runs; they stop with it', () async {
    server = make(heartbeat: const Duration(milliseconds: 30));
    send({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'tools/call',
      'params': {
        'name': 'slow',
        '_meta': {...modern, 'progressToken': 'p1'},
      },
    });
    List<Map> progress() => [
      for (final m in sent)
        if (m['method'] == 'notifications/progress') m['params'] as Map,
    ];
    for (var i = 0; i < 500 && progress().length < 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final beats = progress();
    expect(beats.length, greaterThanOrEqualTo(2));
    expect(beats.every((p) => p['progressToken'] == 'p1'), isTrue);
    expect(beats.map((p) => p['progress'] as int).toList(), orderedEquals([for (var i = 1; i <= beats.length; i++) i]));
    slowGate.complete();
    for (var i = 0; i < 500 && sent.last['id'] != 1; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final n = sent.length;
    expect(sent.last['id'], 1);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(sent.length, n, reason: 'no progress after the result');
  });

  test('resources, prompts and subscriptions', () async {
    final res = (await reply(1, 'resources/list'))['result'] as Map<String, dynamic>;
    expect([for (final r in res['resources'] as List) r['uri']], ['test://a', 'test://gone']);
    final read = (await reply(2, 'resources/read', {'uri': 'test://a'}))['result'] as Map<String, dynamic>;
    expect(read['contents'], [
      {'uri': 'test://a', 'mimeType': 'text/plain', 'text': 'hello'},
    ]);
    expect(read['ttlMs'], isNotNull);
    expect((await reply(3, 'resources/read', {'uri': 'test://gone'}))['error'], {
      'code': -32602,
      'message': 'Resource not found',
      'data': {'uri': 'test://gone'},
    });
    expect(((await reply(4, 'resources/templates/list'))['result'] as Map)['resourceTemplates'], isEmpty);
    final prompts = (await reply(5, 'prompts/list'))['result'] as Map<String, dynamic>;
    expect((prompts['prompts'] as List).single['arguments'], [
      {'name': 'who', 'description': 'who', 'required': true},
    ]);
    final got =
        (await reply(6, 'prompts/get', {
              'name': 'greet',
              'arguments': {'who': 'Ana'},
            }))['result']
            as Map<String, dynamic>;
    expect(got['messages'], [
      {
        'role': 'user',
        'content': {'type': 'text', 'text': 'Hello Ana'},
      },
    ]);
    expect((await reply(7, 'prompts/get', {'name': 'greet'}))['error'], containsPair('code', -32602));
    expect((await reply(8, 'prompts/get', {'name': 'nope'}))['error'], containsPair('code', -32602));
    // a subscription is acknowledged with no notification type (nothing changes) and ends at close
    send({
      'jsonrpc': '2.0',
      'id': 's1',
      'method': 'subscriptions/listen',
      'params': {
        '_meta': modern,
        'notifications': {'toolsListChanged': true},
      },
    });
    expect(sent.last['method'], 'notifications/subscriptions/acknowledged');
    expect(sent.last['params'], {
      '_meta': {'io.modelcontextprotocol/subscriptionId': 's1'},
      'notifications': {},
    });
    await server.close();
    expect(sent.last['id'], 's1');
    expect((sent.last['result'] as Map)['resultType'], 'complete');
    // the handshake revisions name a missing resource with their own code
    server = make();
    await reply(9, 'initialize', {'protocolVersion': '2025-11-25', 'capabilities': {}}, false);
    expect(((await reply(10, 'resources/read', {'uri': 'test://gone'}, false))['error'] as Map)['code'], -32002);
  });

  test('closing lets the calls in flight answer within the grace, then stops the rest', () async {
    send({
      'jsonrpc': '2.0',
      'id': 'w',
      'method': 'tools/call',
      'params': {'name': 'slow', '_meta': modern},
    });
    await Future<void>.delayed(const Duration(milliseconds: 10));
    Timer(const Duration(milliseconds: 30), slowGate.complete);
    await server.close(grace: const Duration(seconds: 2));
    expect(sent.where((m) => m['id'] == 'w' && m.containsKey('result')), hasLength(1));
    // and one that does not finish in time gets nothing
    sent.clear();
    server = make();
    slowGate = Completer<void>();
    send({
      'jsonrpc': '2.0',
      'id': 'x',
      'method': 'tools/call',
      'params': {'name': 'slow', '_meta': modern},
    });
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await server.close(grace: const Duration(milliseconds: 50));
    slowGate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(sent.where((m) => m['id'] == 'x'), isEmpty);
  });

  test('the stdio transport splits lines, drops a line too long and sends one message per line', () async {
    final input = StreamController<List<int>>();
    final out = StringBuffer(), err = StringBuffer();
    final done = serveMcpStdio(
      (send, log) => McpServer(
        info: const McpImplementation(name: 's', version: '1'),
        tools: const [],
        send: send,
        log: log,
      ),
      input: input.stream,
      output: out,
      errors: err,
    );
    input.add(utf8.encode('{"jsonrpc":"2.0","id":1,"method":"ping"}\r\n{"jsonrpc":"2.0","id":2,'));
    input.add(utf8.encode('"method":"ping"}\n'));
    input.add(utf8.encode('x' * 100));
    await input.close();
    await done;
    final lines = const LineSplitter().convert('$out');
    expect(lines.length, 3);
    expect(jsonDecode(lines[0]), {'jsonrpc': '2.0', 'id': 1, 'result': {}});
    expect(jsonDecode(lines[1])['id'], 2);
    expect(jsonDecode(lines[2])['error']['code'], -32700, reason: 'the last line is not JSON');
    // a line above the limit is answered once and dropped up to its end
    final long = <String>[];
    var rejected = 0;
    await for (final l in mcpLines(Stream.fromIterable([utf8.encode('${'a' * 40}\nshort\n${'b' * 15}'), utf8.encode('${'c' * 30}\nend')]), maxBytes: 20, tooLong: () => rejected++)) {
      long.add(l);
    }
    expect(long, ['short', 'end']);
    expect(rejected, 2);
  });
}

/// Spins without ever giving the event loop a turn (only killing its
/// isolate stops it).
Future<McpToolResult> _spin(Map<String, Object?> a) async {
  var x = 0;
  while (x >= 0) {
    x = (x + 1) % 1000;
  }
  return McpToolResult.ok(x);
}
