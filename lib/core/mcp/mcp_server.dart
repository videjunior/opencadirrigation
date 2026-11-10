/// A Model Context Protocol (MCP) server: JSON-RPC 2.0 messages in, JSON-RPC
/// messages out, one message per line, with no transport of its own (the
/// command line connects it to stdin and stdout, the tests to lists of
/// lines; see `bin/src/oci_mcp_io.dart` and docs/MCP.md).
///
/// Protocol revisions (modelcontextprotocol.io/specification):
///
/// * **2026-07-28** (the current one), stateless: every request carries its
///   revision and the client's capabilities in
///   `_meta["io.modelcontextprotocol/protocolVersion"]` and
///   `_meta["io.modelcontextprotocol/clientCapabilities"]`, results carry
///   `resultType` and the server's identity, lists carry `ttlMs` and
///   `cacheScope`; `server/discover` names what the server supports and
///   `subscriptions/listen` is acknowledged (nothing here ever changes, so
///   it never notifies).
/// * **2025-11-25** and **2025-06-18**, the handshake revisions: an
///   `initialize` request selects them for the rest of the process
///   (`notifications/initialized`, `ping`), with the result shapes of those
///   revisions. A request for another revision gets 2025-11-25, as their
///   version negotiation says.
///
/// Both kinds can be served by one process at once (a "dual-era" server in
/// the words of the specification). Tools, resources and prompts are what
/// the caller gives; tool arguments are validated against the tool's input
/// schema (json_schema.dart) before the tool runs, and a call can be
/// cancelled (`notifications/cancelled`) or stopped by the time limit, through
/// the [McpExecutor] that runs it.
///
/// Pure Dart (no dart:io, no isolates): it runs wherever the engine runs.
library;

import 'dart:async';
import 'dart:convert';

import 'json_schema.dart';

/// The per-request revision, newest first.
const mcpModernVersions = ['2026-07-28'];

/// The revisions of the `initialize` handshake, newest first.
const mcpLegacyVersions = ['2025-11-25', '2025-06-18'];

/// Every revision the server speaks, newest first.
const mcpSupportedVersions = [...mcpModernVersions, ...mcpLegacyVersions];

/// JSON-RPC error codes the server answers with.
abstract final class McpErrorCode {
  static const parseError = -32700;
  static const invalidRequest = -32600;
  static const methodNotFound = -32601;
  static const invalidParams = -32602;
  static const internalError = -32603;

  /// 2025-11-25 and earlier: a resource that does not exist (2026-07-28 uses
  /// [invalidParams]).
  static const legacyResourceNotFound = -32002;

  /// 2026-07-28: the request names a revision the server does not speak.
  static const unsupportedProtocolVersion = -32022;
}

const _kVersion = 'io.modelcontextprotocol/protocolVersion';
const _kCapabilities = 'io.modelcontextprotocol/clientCapabilities';
const _kServerInfo = 'io.modelcontextprotocol/serverInfo';
const _kSubscription = 'io.modelcontextprotocol/subscriptionId';

/// The longest message the server reads (a line of the transport): longer
/// ones are answered with a parse error and dropped.
const mcpMaxMessageBytes = 16 * 1024 * 1024;

/// Who the server is (`serverInfo`).
class McpImplementation {
  const McpImplementation({required this.name, required this.version, this.title, this.description, this.websiteUrl});
  final String name;
  final String version;
  final String? title;
  final String? description;
  final String? websiteUrl;

  Map<String, Object?> toJson() => {
    'name': name,
    if (title != null) 'title': title,
    'version': version,
    if (description != null) 'description': description,
    if (websiteUrl != null) 'websiteUrl': websiteUrl,
  };
}

/// The behaviour hints of a tool (ToolAnnotations). Every tool states all
/// four, so that no client has to fall back on the defaults of the
/// specification (which assume the worst).
class McpToolAnnotations {
  const McpToolAnnotations({required this.readOnly, this.destructive = false, this.idempotent = false, this.openWorld = false});

  /// Changes nothing.
  const McpToolAnnotations.reading() : readOnly = true, destructive = false, idempotent = true, openWorld = false;
  final bool readOnly;
  final bool destructive;
  final bool idempotent;
  final bool openWorld;

  Map<String, Object?> toJson() => {'readOnlyHint': readOnly, if (!readOnly) 'destructiveHint': destructive, if (!readOnly) 'idempotentHint': idempotent, 'openWorldHint': openWorld};
}

/// What a tool returns: the structured result (a JSON value, matching the
/// tool's output schema) or an error message for the model to act on.
class McpToolResult {
  const McpToolResult._(this.structured, this.text, this.isError);

  /// A result: [structured] goes out as `structuredContent` and, as the
  /// specification advises, serialised in a text block too (or [text]).
  factory McpToolResult.ok(Object? structured, {String? text}) => McpToolResult._(structured, text, false);

  /// A tool execution error (`isError: true`) the model can correct.
  factory McpToolResult.error(String message) => McpToolResult._(null, message, true);
  final Object? structured;
  final String? text;
  final bool isError;

  Map<String, Object?> toJson() => {
    'content': [
      {'type': 'text', 'text': text ?? mcpJson(structured)},
    ],
    if (!isError) 'structuredContent': structured,
    'isError': isError,
  };
}

/// An expected failure of a tool (a missing file, a project with nothing
/// to design…): the call ends with `isError: true` and this message.
class McpToolError implements Exception {
  McpToolError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A tool: its definition (name, description, schemas, hints) and what it
/// does with arguments already validated against [inputSchema].
class McpTool {
  const McpTool({required this.name, required this.title, required this.description, required this.inputSchema, required this.annotations, required this.call, this.outputSchema});
  final String name;
  final String title;
  final String description;
  final Map<String, Object?> inputSchema;
  final Map<String, Object?>? outputSchema;
  final McpToolAnnotations annotations;
  final Future<McpToolResult> Function(Map<String, Object?> arguments) call;

  Map<String, Object?> toJson() => {
    'name': name,
    'title': title,
    'description': description,
    'inputSchema': inputSchema,
    if (outputSchema != null) 'outputSchema': outputSchema,
    'annotations': {'title': title, ...annotations.toJson()},
  };
}

/// The contents of a resource.
class McpResourceContents {
  const McpResourceContents({required this.text, required this.mimeType});
  final String text;
  final String mimeType;
}

/// A resource the client may read (`resources/list`, `resources/read`).
class McpResource {
  const McpResource({required this.uri, required this.name, required this.title, required this.description, required this.mimeType, required this.read});
  final String uri;
  final String name;
  final String title;
  final String description;
  final String mimeType;

  /// Its text; null when it cannot be read (then it is "not found").
  final McpResourceContents? Function() read;

  Map<String, Object?> toJson() => {'uri': uri, 'name': name, 'title': title, 'description': description, 'mimeType': mimeType};
}

/// An argument of a prompt.
class McpPromptArgument {
  const McpPromptArgument({required this.name, required this.description, this.required = false});
  final String name;
  final String description;
  final bool required;
  Map<String, Object?> toJson() => {'name': name, 'description': description, 'required': required};
}

/// A prompt template (`prompts/list`, `prompts/get`): one user message.
class McpPrompt {
  const McpPrompt({required this.name, required this.title, required this.description, required this.arguments, required this.text});
  final String name;
  final String title;
  final String description;
  final List<McpPromptArgument> arguments;

  /// The text of the message for these arguments.
  final String Function(Map<String, String> arguments) text;

  Map<String, Object?> toJson() => {
    'name': name,
    'title': title,
    'description': description,
    'arguments': [for (final a in arguments) a.toJson()],
  };
}

/// Thrown by [McpExecutor.run] when the call was cancelled or its time ran
/// out before it finished.
class McpCallStopped implements Exception {
  const McpCallStopped();
}

/// Runs the work of one tool call. [InlineExecutor] runs it in the
/// server's own event loop (a synchronous calculation cannot be stopped);
/// the command line runs every call in an isolate of its own, which a
/// cancellation or the time limit kills.
abstract interface class McpExecutor {
  /// The result of [work], or [McpCallStopped] as soon as [stop] completes
  /// (if the work can be stopped).
  Future<McpToolResult> run(Future<McpToolResult> Function() work, {required Future<void> stop});
}

/// Runs the work in the same event loop.
class InlineExecutor implements McpExecutor {
  const InlineExecutor();
  @override
  Future<McpToolResult> run(Future<McpToolResult> Function() work, {required Future<void> stop}) {
    final done = Completer<McpToolResult>();
    stop.then((_) {
      if (!done.isCompleted) done.completeError(const McpCallStopped());
    });
    work().then(
      (r) {
        if (!done.isCompleted) done.complete(r);
      },
      onError: (Object e, StackTrace st) {
        if (!done.isCompleted) done.completeError(e, st);
      },
    );
    return done.future;
  }
}

/// JSON text of [value] on one line (JSON escapes every newline inside a
/// string); numbers that are not finite become null, any other object its
/// text.
String mcpJson(Object? value) => const JsonEncoder(_encodable).convert(value);

Object? _encodable(Object? o) => switch (o) {
  double d when !d.isFinite => null,
  _ => '$o',
};

class _RpcError implements Exception {
  _RpcError(this.code, this.message, [this.data]);
  final int code;
  final String message;
  final Object? data;
}

/// A request in progress.
class _Call {
  _Call(this.id);
  final Object id;
  final stop = Completer<void>();
  String? stoppedBy;
  bool subscription = false;
  bool modern = false;
  Timer? heartbeat;
  Timer? limit;

  void halt(String why) {
    stoppedBy ??= why;
    if (!stop.isCompleted) stop.complete();
  }
}

/// Lets any number of reading calls run together and a writing call alone.
class _Gate {
  int _readers = 0;
  bool _writing = false;
  final _waiting = <(bool, Completer<void>)>[];

  Future<void> enter(bool write) {
    if (_waiting.isEmpty && (write ? !_writing && _readers == 0 : !_writing)) {
      _take(write);
      return Future.value();
    }
    final c = Completer<void>();
    _waiting.add((write, c));
    return c.future;
  }

  void _take(bool write) => write ? _writing = true : _readers++;

  void leave(bool write) {
    if (write) {
      _writing = false;
    } else {
      _readers--;
    }
    while (_waiting.isNotEmpty) {
      final (w, c) = _waiting.first;
      if (w ? _writing || _readers > 0 : _writing) break;
      _waiting.removeAt(0);
      _take(w);
      c.complete();
      if (w) break;
    }
  }
}

/// The server. [send] receives every outgoing message (one line of JSON,
/// without the newline); [log] the diagnostics, which go to stderr on the
/// command line and never to the message channel.
class McpServer {
  McpServer({
    required this.info,
    required List<McpTool> tools,
    required this.send,
    this.resources = const [],
    this.prompts = const [],
    this.instructions,
    this.executor = const InlineExecutor(),
    this.timeLimit = const Duration(minutes: 15),
    this.heartbeat = const Duration(seconds: 5),
    this.log,
  }) : tools = List.unmodifiable(tools) {
    final names = <String>{};
    for (final t in tools) {
      if (!RegExp(r'^[A-Za-z0-9_.-]{1,128}$').hasMatch(t.name)) throw ArgumentError('tool name ${t.name}: 1 to 128 of A-Z a-z 0-9 _ - .');
      if (!names.add(t.name)) throw ArgumentError('tool ${t.name} twice');
    }
  }

  final McpImplementation info;

  /// In the order tools/list gives them (always the same).
  final List<McpTool> tools;
  final List<McpResource> resources;
  final List<McpPrompt> prompts;

  /// Guidance for the model (`instructions` of initialize and discover).
  final String? instructions;
  final McpExecutor executor;

  /// The longest a tool call may run.
  final Duration timeLimit;

  /// How often a call with a progress token reports that it is still
  /// working.
  final Duration heartbeat;
  final void Function(String message) send;
  final void Function(String line)? log;

  /// The revision the `initialize` handshake agreed on (null: none yet).
  String? legacyVersion;

  /// The client sent `notifications/initialized`.
  bool initialized = false;

  final _calls = <String, _Call>{};
  final _running = <Future<void>>[];
  final _gate = _Gate();
  bool _closed = false;

  /// Requests in progress (tool calls and subscriptions).
  int get inFlight => _calls.length;

  Map<String, Object?> get _capabilities => {'tools': <String, Object?>{}, if (resources.isNotEmpty) 'resources': <String, Object?>{}, if (prompts.isNotEmpty) 'prompts': <String, Object?>{}};

  static String _key(Object id) => id is num ? 'n:${id.toInt()}' : 's:$id';

  void _out(Map<String, Object?> message) {
    if (_closed && message['method'] != null) return;
    send(mcpJson(message));
  }

  void _error(Object? id, int code, String message, [Object? data]) => _out({
    'jsonrpc': '2.0',
    'id': id,
    'error': {'code': code, 'message': message, 'data': ?data},
  });

  /// The transport dropped a message longer than [mcpMaxMessageBytes].
  void rejectTooLong() => _error(null, McpErrorCode.parseError, 'message longer than ${mcpMaxMessageBytes ~/ (1024 * 1024)} MB: dropped');

  /// Handles one incoming message (a line of the transport).
  void receive(String line) {
    if (line.trim().isEmpty) return;
    if (line.length > mcpMaxMessageBytes) {
      _error(null, McpErrorCode.parseError, 'message longer than ${mcpMaxMessageBytes ~/ (1024 * 1024)} MB');
      return;
    }
    Object? msg;
    try {
      msg = jsonDecode(line);
    } catch (_) {
      _error(null, McpErrorCode.parseError, 'Parse error: the line is not JSON');
      return;
    }
    if (msg is List) {
      _error(null, McpErrorCode.invalidRequest, 'Invalid Request: batches are not part of MCP; send one message per line');
      return;
    }
    if (msg is! Map<String, dynamic>) {
      _error(null, McpErrorCode.invalidRequest, 'Invalid Request: a message is a JSON object');
      return;
    }
    final rawId = msg['id'];
    // answered with the id as sent (a string or a whole number)
    final Object? id = rawId is String || (rawId is num && rawId.isFinite && rawId == rawId.roundToDouble()) ? rawId : null;
    if (msg['jsonrpc'] != '2.0') {
      _error(id, McpErrorCode.invalidRequest, 'Invalid Request: "jsonrpc" must be "2.0"');
      return;
    }
    final method = msg['method'];
    if (method is! String) {
      if (msg.containsKey('result') || msg.containsKey('error')) {
        log?.call('mcp: a response to no request of this server was ignored');
      } else {
        _error(id, McpErrorCode.invalidRequest, 'Invalid Request: no "method"');
      }
      return;
    }
    final params = msg['params'];
    if (!msg.containsKey('id')) {
      if (params is Map<String, dynamic> || params == null) _notification(method, params as Map<String, dynamic>? ?? const {});
      return;
    }
    if (id == null) {
      _error(null, McpErrorCode.invalidRequest, 'Invalid Request: the id must be a string or a whole number (not null)');
      return;
    }
    if (params != null && params is! Map<String, dynamic>) {
      _error(id, McpErrorCode.invalidParams, 'Invalid params: "params" must be an object');
      return;
    }
    if (_calls.containsKey(_key(id))) {
      _error(id, McpErrorCode.invalidRequest, 'Invalid Request: id $id is already used by a request in progress');
      return;
    }
    try {
      _request(id, method, params as Map<String, dynamic>? ?? const {});
    } on _RpcError catch (e) {
      _error(id, e.code, e.message, e.data);
    } catch (e, st) {
      log?.call('mcp: $method failed: $e\n$st');
      _error(id, McpErrorCode.internalError, 'Internal error: $e');
    }
  }

  void _notification(String method, Map<String, dynamic> params) {
    switch (method) {
      case 'notifications/initialized':
        initialized = true;
      case 'notifications/cancelled':
        final raw = params['requestId'];
        if (raw is! String && raw is! num) return;
        final call = _calls[_key(raw)];
        if (call == null) return;
        log?.call('mcp: request ${call.id} cancelled${params['reason'] is String ? ' (${params['reason']})' : ''}');
        if (call.subscription) _calls.remove(_key(call.id));
        call.halt('cancelled');
      default:
        // other notifications need nothing of this server
        break;
    }
  }

  /// The revision of a request: from its `_meta`, else the handshake's.
  /// True in the second field for the per-request (2026-07-28) shapes.
  (String, bool) _era(String method, Map<String, dynamic> params) {
    final meta = params['_meta'];
    final version = meta is Map ? meta[_kVersion] : null;
    if (version != null) {
      if (version is! String || !mcpSupportedVersions.contains(version)) {
        throw _RpcError(McpErrorCode.unsupportedProtocolVersion, 'Unsupported protocol version', {'supported': mcpSupportedVersions, 'requested': version});
      }
      final modern = mcpModernVersions.contains(version);
      if (modern && meta![_kCapabilities] is! Map) {
        throw _RpcError(McpErrorCode.invalidParams, 'Invalid params: _meta["$_kCapabilities"] is required (an object; {} when the client has none)');
      }
      return (version, modern);
    }
    final legacy = legacyVersion;
    if (legacy != null || method == 'ping') return (legacy ?? mcpLegacyVersions.first, false);
    throw _RpcError(
      McpErrorCode.invalidParams,
      'Invalid params: no _meta["$_kVersion"]. Send it with every request (protocol ${mcpModernVersions.first}), or start with initialize (protocol ${mcpLegacyVersions.join(' or ')})',
      {'supported': mcpSupportedVersions},
    );
  }

  void _result(Object id, Map<String, Object?> body, {required bool modern, bool cacheable = false, int ttlMs = 0, String cacheScope = 'public'}) {
    _out({
      'jsonrpc': '2.0',
      'id': id,
      'result': {
        if (modern) 'resultType': 'complete',
        ...body,
        if (modern && cacheable) 'ttlMs': ttlMs,
        if (modern && cacheable) 'cacheScope': cacheScope,
        if (modern)
          '_meta': {
            _kServerInfo: {'name': info.name, 'version': info.version},
          },
      },
    });
  }

  void _request(Object id, String method, Map<String, dynamic> params) {
    if (method == 'initialize') {
      _initialize(id, params);
      return;
    }
    final (_, modern) = _era(method, params);
    const hour = 3600000;
    switch (method) {
      case 'ping':
        _result(id, const {}, modern: modern);
      case 'server/discover':
        _result(
          id,
          {'supportedVersions': mcpSupportedVersions, 'capabilities': _capabilities, 'serverInfo': info.toJson(), 'instructions': ?instructions},
          modern: modern,
          cacheable: true,
          ttlMs: hour,
        );
      case 'tools/list':
        _noCursor(params);
        _result(
          id,
          {
            'tools': [for (final t in tools) t.toJson()],
          },
          modern: modern,
          cacheable: true,
          ttlMs: hour,
        );
      case 'tools/call':
        _callTool(id, params, modern);
      case 'resources/list':
        _noCursor(params);
        _result(
          id,
          {
            'resources': [for (final r in resources) r.toJson()],
          },
          modern: modern,
          cacheable: true,
          ttlMs: hour,
        );
      case 'resources/templates/list':
        _noCursor(params);
        _result(id, {'resourceTemplates': const <Object>[]}, modern: modern, cacheable: true, ttlMs: hour);
      case 'resources/read':
        final uri = params['uri'];
        if (uri is! String) throw _RpcError(McpErrorCode.invalidParams, 'Invalid params: "uri" (a string) is required');
        final r = resources.where((r) => r.uri == uri).firstOrNull;
        final contents = r?.read();
        if (r == null || contents == null) throw _RpcError(modern ? McpErrorCode.invalidParams : McpErrorCode.legacyResourceNotFound, 'Resource not found', {'uri': uri});
        _result(
          id,
          {
            'contents': [
              {'uri': uri, 'mimeType': contents.mimeType, 'text': contents.text},
            ],
          },
          modern: modern,
          cacheable: true,
          ttlMs: hour,
        );
      case 'prompts/list':
        _noCursor(params);
        _result(
          id,
          {
            'prompts': [for (final p in prompts) p.toJson()],
          },
          modern: modern,
          cacheable: true,
          ttlMs: hour,
        );
      case 'prompts/get':
        _getPrompt(id, params, modern);
      case 'subscriptions/listen':
        if (!modern) throw _RpcError(McpErrorCode.methodNotFound, 'Method not found: subscriptions/listen (protocol ${mcpModernVersions.first})');
        final call = _Call(id)
          ..subscription = true
          ..modern = true;
        _calls[_key(id)] = call;
        // nothing of this server changes while it runs: no notification type is taken
        _out({
          'jsonrpc': '2.0',
          'method': 'notifications/subscriptions/acknowledged',
          'params': {
            '_meta': {_kSubscription: id},
            'notifications': <String, Object?>{},
          },
        });
      default:
        throw _RpcError(McpErrorCode.methodNotFound, 'Method not found: $method');
    }
  }

  void _noCursor(Map<String, dynamic> params) {
    // every list fits in one page: no cursor is ever handed out
    if (params['cursor'] != null) throw _RpcError(McpErrorCode.invalidParams, 'Invalid params: unknown cursor (every list of this server comes in one page)');
  }

  void _initialize(Object id, Map<String, dynamic> params) {
    final asked = params['protocolVersion'];
    if (asked is! String) throw _RpcError(McpErrorCode.invalidParams, 'Invalid params: "protocolVersion" (a string) is required', {'supported': mcpSupportedVersions});
    // the handshake revisions: the one asked for, else the newest of them
    final version = mcpLegacyVersions.contains(asked) ? asked : mcpLegacyVersions.first;
    legacyVersion = version;
    final client = params['clientInfo'];
    log?.call('mcp: initialize from ${client is Map ? '${client['name']} ${client['version']}' : 'a client'}: protocol $version${version == asked ? '' : ' (asked for $asked)'}');
    _result(id, {'protocolVersion': version, 'capabilities': _capabilities, 'serverInfo': info.toJson(), 'instructions': ?instructions}, modern: false);
  }

  void _getPrompt(Object id, Map<String, dynamic> params, bool modern) {
    final name = params['name'];
    final p = prompts.where((p) => p.name == name).firstOrNull;
    if (p == null) throw _RpcError(McpErrorCode.invalidParams, 'Invalid params: unknown prompt ${name is String ? name : '(no name)'}');
    final raw = params['arguments'];
    if (raw != null && raw is! Map) throw _RpcError(McpErrorCode.invalidParams, 'Invalid params: "arguments" must be an object of strings');
    final args = <String, String>{
      for (final e in (raw as Map? ?? const {}).entries)
        if (e.value is String) '${e.key}': e.value as String,
    };
    final missing = [
      for (final a in p.arguments)
        if (a.required && (args[a.name] ?? '').trim().isEmpty) a.name,
    ];
    if (missing.isNotEmpty) throw _RpcError(McpErrorCode.invalidParams, 'Invalid params: the prompt ${p.name} needs ${missing.join(', ')}');
    _result(id, {
      'description': p.description,
      'messages': [
        {
          'role': 'user',
          'content': {'type': 'text', 'text': p.text(args)},
        },
      ],
    }, modern: modern);
  }

  void _callTool(Object id, Map<String, dynamic> params, bool modern) {
    final name = params['name'];
    if (name is! String) throw _RpcError(McpErrorCode.invalidParams, 'Invalid params: "name" (a string) is required');
    final tool = tools.where((t) => t.name == name).firstOrNull;
    if (tool == null) throw _RpcError(McpErrorCode.invalidParams, 'Unknown tool: $name');
    final args = params['arguments'];
    if (args != null && args is! Map<String, dynamic>) throw _RpcError(McpErrorCode.invalidParams, 'Invalid params: "arguments" must be an object');
    final arguments = args as Map<String, dynamic>? ?? <String, dynamic>{};
    final meta = params['_meta'];
    final token = meta is Map ? meta['progressToken'] : null;
    final call = _Call(id)..modern = modern;
    _calls[_key(id)] = call;
    final done = _run(call, tool, arguments, token is String || token is num ? token : null);
    _running.add(done);
    done.whenComplete(() => _running.remove(done));
  }

  /// The work of [tool] with [arguments], kept apart from the server so
  /// that an executor may send it to another isolate.
  static Future<McpToolResult> Function() _work(McpTool tool, Map<String, Object?> arguments) =>
      () => tool.call(arguments);

  Future<void> _run(_Call call, McpTool tool, Map<String, dynamic> arguments, Object? progressToken) async {
    final problems = schemaErrors(arguments, tool.inputSchema);
    if (problems.isNotEmpty) {
      _calls.remove(_key(call.id));
      _result(call.id, McpToolResult.error('Invalid arguments for ${tool.name}:\n- ${problems.join('\n- ')}').toJson(), modern: call.modern);
      return;
    }
    final write = !tool.annotations.readOnly;
    await _gate.enter(write);
    var progress = 0;
    final started = DateTime.now();
    if (progressToken != null) {
      call.heartbeat = Timer.periodic(heartbeat, (_) {
        if (call.stop.isCompleted) return;
        progress++;
        final s = DateTime.now().difference(started).inSeconds;
        _out({
          'jsonrpc': '2.0',
          'method': 'notifications/progress',
          'params': {'progressToken': progressToken, 'progress': progress, 'message': '${tool.name}: working ($s s)'},
        });
      });
    }
    call.limit = Timer(timeLimit, () => call.halt('time'));
    McpToolResult? result;
    try {
      if (call.stop.isCompleted) throw const McpCallStopped();
      result = await executor.run(_work(tool, arguments), stop: call.stop.future);
    } on McpCallStopped {
      result = null;
    } on McpToolError catch (e) {
      result = McpToolResult.error(e.message);
    } catch (e, st) {
      log?.call('mcp: ${tool.name} failed: $e\n$st');
      result = McpToolResult.error('${tool.name} failed: $e');
    } finally {
      call.heartbeat?.cancel();
      call.limit?.cancel();
      _gate.leave(write);
      _calls.remove(_key(call.id));
    }
    if (call.stoppedBy == 'cancelled' || _closed) return; // no response for a cancelled request
    if (call.stoppedBy == 'time' || result == null) {
      result = McpToolResult.error('${tool.name} was stopped after ${_minutes(timeLimit)}: the limit of a call. Try a smaller project or fewer outputs at once.');
    }
    _result(call.id, result.toJson(), modern: call.modern);
  }

  static String _minutes(Duration d) => d.inMinutes >= 1 ? '${d.inMinutes} min' : '${d.inSeconds} s';

  /// The transport closed: the subscriptions end with their completion
  /// result, the calls in flight get [grace] to finish and answer (a script
  /// that writes its requests and closes the input still gets its answers),
  /// then the rest are stopped without a response.
  Future<void> close({Duration grace = const Duration(seconds: 10)}) async {
    for (final call in _calls.values.toList()) {
      if (call.subscription) {
        _result(call.id, const {}, modern: true);
        _calls.remove(_key(call.id));
      }
    }
    if (_running.isNotEmpty) {
      final all = Future.wait(_running.toList());
      await Future.any([all, Future<void>.delayed(grace)]);
    }
    _closed = true;
    for (final call in _calls.values.toList()) {
      call.halt('closed');
    }
    await Future.wait(_running.toList());
  }
}
