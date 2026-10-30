/// The two wire formats in one place: tool definitions, the user's message
/// (text, pictures, PDFs), tool results (text and pictures), notes from the
/// program, and the tool calls and text of an answer — for Anthropic's
/// Messages API ([AnthropicFormat]) and OpenAI's Responses API
/// ([OpenAiFormat]). Each also reads its own shapes back ([AnthropicFormat.specOf],
/// [OpenAiFormat.userParts]…), which the tests use to check that nothing is
/// lost on the way.
///
/// Pure Dart. Entries of a history are kept exactly as they were sent or
/// received; these functions only build new entries and read old ones.
library;

import 'dart:convert';

import 'llm.dart';

/// Start of an error result sent to OpenAI, whose function outputs have no
/// error flag.
const toolErrorPrefix = 'Error: ';

/// Start of a message the user wrote while the assistant was working.
const steeringPrefix = '[Message from the user, written while you were working]\n';

Map<String, dynamic> _map(Object? o) => o is Map ? Map<String, dynamic>.from(o) : <String, dynamic>{};
List<Map<String, dynamic>> _maps(Object? o) => [
  if (o is List)
    for (final x in o)
      if (x is Map) Map<String, dynamic>.from(x),
];

/// Tool input from its JSON text: the map, or null with [raw] kept when it
/// is not a JSON object (an empty text is an empty input).
(Map<String, dynamic>?, String?) parseToolInput(String raw) {
  if (raw.trim().isEmpty) return (<String, dynamic>{}, null);
  try {
    final v = jsonDecode(raw);
    if (v is Map) return (Map<String, dynamic>.from(v), null);
  } catch (_) {}
  return (null, raw);
}

abstract final class AnthropicFormat {
  /// A tool definition; inputs stream as they are generated (the loop checks
  /// them against the schema before running the tool).
  static Map<String, Object?> tool(AiToolSpec s) => {'name': s.name, 'description': s.description, 'eager_input_streaming': true, 'input_schema': s.inputSchema};

  static AiToolSpec specOf(Map<String, Object?> d) => AiToolSpec('${d['name']}', '${d['description'] ?? ''}', Map<String, Object?>.from(d['input_schema'] as Map? ?? const {}));

  static Map<String, dynamic> part(AiPart p) => switch (p) {
    AiTextPart(:final text) => {'type': 'text', 'text': text},
    AiImagePart(:final mediaType, :final base64) => {
      'type': 'image',
      'source': {'type': 'base64', 'media_type': mediaType, 'data': base64},
    },
    AiPdfPart(:final name, :final base64) => {
      'type': 'document',
      'source': {'type': 'base64', 'media_type': 'application/pdf', 'data': base64},
      'title': name,
    },
  };

  /// The part of a content block (null for blocks that are not one).
  static AiPart? partOf(Map<String, dynamic> b) {
    final src = _map(b['source']);
    return switch (b['type']) {
      'text' => AiTextPart('${b['text'] ?? ''}'),
      'image' => AiImagePart('${src['media_type'] ?? ''}', '${src['data'] ?? ''}'),
      'document' => AiPdfPart('${b['title'] ?? ''}', '${src['data'] ?? ''}'),
      _ => null,
    };
  }

  static Map<String, dynamic> user(List<AiPart> parts) => {
    'role': 'user',
    'content': [for (final p in parts) part(p)],
  };

  static List<AiPart> userParts(Map<String, dynamic> message) => [for (final b in _maps(message['content'])) ?partOf(b)];

  static Map<String, dynamic> toolResult(AiToolResult r) {
    final o = r.output;
    return {
      'type': 'tool_result',
      'tool_use_id': r.id,
      if (o.isError) 'is_error': true,
      'content': o.images.isEmpty
          ? o.text
          : [
              {'type': 'text', 'text': o.text},
              for (final i in o.images) part(AiImagePart(i.mediaType, i.base64)),
            ],
    };
  }

  static AiToolResult resultOf(Map<String, dynamic> b) {
    final c = b['content'];
    final blocks = c is List ? _maps(c) : const <Map<String, dynamic>>[];
    final text = c is String
        ? c
        : [
            for (final x in blocks)
              if (x['type'] == 'text') '${x['text'] ?? ''}',
          ].join();
    final images = [
      for (final x in blocks)
        if (x['type'] == 'image') ToolImage('${_map(x['source'])['media_type'] ?? ''}', '${_map(x['source'])['data'] ?? ''}'),
    ];
    return AiToolResult('${b['tool_use_id'] ?? ''}', ToolOutput(text, images: images, isError: b['is_error'] == true));
  }

  /// One round of results: a user message with every result first, then
  /// what the user wrote meanwhile, then [note] (a text block after the
  /// results, which keeps an append-only history valid however the turn
  /// goes on).
  static List<Map<String, dynamic>> toolResults(List<AiToolResult> results, {List<AiPart> user = const [], String? note}) => [
    {
      'role': 'user',
      'content': [
        for (final r in results) toolResult(r),
        for (final p in user) part(p),
        if (note != null) {'type': 'text', 'text': note},
      ],
    },
  ];

  /// The results in a message of [toolResults], and the other parts.
  static (List<AiToolResult>, List<AiPart>) resultsOf(Map<String, dynamic> message) {
    final results = <AiToolResult>[], parts = <AiPart>[];
    for (final b in _maps(message['content'])) {
      if (b['type'] == 'tool_result') {
        results.add(resultOf(b));
      } else {
        final p = partOf(b);
        if (p != null) parts.add(p);
      }
    }
    return (results, parts);
  }

  /// The tool calls of an answer's content; [invalid] holds the raw input of
  /// calls whose JSON did not parse, by id.
  static List<AiToolCall> calls(List<Map<String, dynamic>> content, {Map<String, String> invalid = const {}}) => [
    for (final b in content)
      if (b['type'] == 'tool_use') AiToolCall('${b['id'] ?? ''}', '${b['name'] ?? ''}', _map(b['input']), invalidRaw: invalid['${b['id']}']),
  ];

  static String text(List<Map<String, dynamic>> content) => [
    for (final b in content)
      if (b['type'] == 'text') '${b['text'] ?? ''}',
  ].join();

  /// An assistant message carrying [calls] (the shape the model sends).
  static Map<String, dynamic> assistant(String text, List<AiToolCall> calls) => {
    'role': 'assistant',
    'content': [
      if (text.isNotEmpty) {'type': 'text', 'text': text},
      for (final c in calls) {'type': 'tool_use', 'id': c.id, 'name': c.name, 'input': c.input},
    ],
  };
}

abstract final class OpenAiFormat {
  /// A function tool. `strict` is off: the schemas have optional fields
  /// (strict mode wants every field required), and the loop checks inputs.
  static Map<String, Object?> tool(AiToolSpec s) => {'type': 'function', 'name': s.name, 'description': s.description, 'parameters': s.inputSchema, 'strict': false};

  static AiToolSpec specOf(Map<String, Object?> d) => AiToolSpec('${d['name']}', '${d['description'] ?? ''}', Map<String, Object?>.from(d['parameters'] as Map? ?? const {}));

  static String dataUrl(String mediaType, String base64) => 'data:$mediaType;base64,$base64';

  /// (media type, base64) of a data URL; null for other URLs.
  static (String, String)? fromDataUrl(String url) {
    final m = RegExp(r'^data:([^;,]+);base64,').firstMatch(url);
    return m == null ? null : (m.group(1)!, url.substring(m.end));
  }

  static Map<String, dynamic> part(AiPart p) => switch (p) {
    AiTextPart(:final text) => {'type': 'input_text', 'text': text},
    // high: never the 512-pixel low-detail reading (pictures are measured)
    AiImagePart(:final mediaType, :final base64) => {'type': 'input_image', 'image_url': dataUrl(mediaType, base64), 'detail': 'high'},
    AiPdfPart(:final name, :final base64) => {'type': 'input_file', 'filename': name, 'file_data': dataUrl('application/pdf', base64)},
  };

  static AiPart? partOf(Map<String, dynamic> b) {
    switch (b['type']) {
      case 'input_text':
      case 'output_text':
        return AiTextPart('${b['text'] ?? ''}');
      case 'input_image':
        final d = fromDataUrl('${b['image_url'] ?? ''}');
        return d == null ? null : AiImagePart(d.$1, d.$2);
      case 'input_file':
        final d = fromDataUrl('${b['file_data'] ?? ''}');
        return d == null ? null : AiPdfPart('${b['filename'] ?? ''}', d.$2);
    }
    return null;
  }

  static Map<String, dynamic> message(String role, List<AiPart> parts) => {
    'type': 'message',
    'role': role,
    'content': [for (final p in parts) part(p)],
  };

  static Map<String, dynamic> user(List<AiPart> parts) => message('user', parts);

  /// An instruction from the program (the developer role).
  static Map<String, dynamic> developer(String text) => message('developer', [AiTextPart(text)]);

  static List<AiPart> userParts(Map<String, dynamic> message) => [for (final b in _maps(message['content'])) ?partOf(b)];

  static Map<String, dynamic> toolResult(AiToolResult r) {
    final o = r.output;
    final text = o.isError ? '$toolErrorPrefix${o.text}' : o.text;
    return {
      'type': 'function_call_output',
      'call_id': r.id,
      'output': o.images.isEmpty
          ? text
          : [
              {'type': 'input_text', 'text': text},
              for (final i in o.images) part(AiImagePart(i.mediaType, i.base64)),
            ],
    };
  }

  static AiToolResult resultOf(Map<String, dynamic> item) {
    final out = item['output'];
    final parts = out is List ? [for (final b in _maps(out)) ?partOf(b)] : const <AiPart>[];
    var text = out is String
        ? out
        : [
            for (final p in parts)
              if (p is AiTextPart) p.text,
          ].join();
    final error = text.startsWith(toolErrorPrefix);
    if (error) text = text.substring(toolErrorPrefix.length);
    return AiToolResult(
      '${item['call_id'] ?? ''}',
      ToolOutput(
        text,
        images: [
          for (final p in parts)
            if (p is AiImagePart) ToolImage(p.mediaType, p.base64),
        ],
        isError: error,
      ),
    );
  }

  /// One round of results: every function output, then a user message with
  /// what the user wrote meanwhile, then [note] as a developer message.
  static List<Map<String, dynamic>> toolResults(List<AiToolResult> results, {List<AiPart> user = const [], String? note}) => [
    for (final r in results) toolResult(r),
    if (user.isNotEmpty) OpenAiFormat.user(user),
    if (note != null) developer(note),
  ];

  static (List<AiToolResult>, List<AiPart>) resultsOf(List<Map<String, dynamic>> items) {
    final results = <AiToolResult>[], parts = <AiPart>[];
    for (final it in items) {
      if (it['type'] == 'function_call_output') {
        results.add(resultOf(it));
      } else if (it['type'] == 'message') {
        parts.addAll(userParts(it));
      }
    }
    return (results, parts);
  }

  /// The function calls among output items (the arguments are JSON text).
  static List<AiToolCall> calls(List<Map<String, dynamic>> items) => [
    for (final it in items)
      if (it['type'] == 'function_call') _call(it),
  ];

  static AiToolCall _call(Map<String, dynamic> it) {
    final (input, raw) = parseToolInput('${it['arguments'] ?? ''}');
    return AiToolCall('${it['call_id'] ?? ''}', '${it['name'] ?? ''}', input ?? <String, dynamic>{}, invalidRaw: raw);
  }

  static String _parts(List<Map<String, dynamic>> items, String type, String field) => [
    for (final it in items)
      if (it['type'] == 'message')
        for (final c in _maps(it['content']))
          if (c['type'] == type) '${c[field] ?? ''}',
  ].join();

  /// The text the model wrote (its output_text parts).
  static String text(List<Map<String, dynamic>> items) => _parts(items, 'output_text', 'text');

  /// Why the model declined, when it did (its refusal parts).
  static String refusal(List<Map<String, dynamic>> items) => _parts(items, 'refusal', 'refusal');

  /// Output items carrying [text] and [calls] (the shapes the model sends).
  static List<Map<String, dynamic>> assistant(String text, List<AiToolCall> calls) => [
    if (text.isNotEmpty)
      {
        'type': 'message',
        'role': 'assistant',
        'content': [
          {'type': 'output_text', 'text': text, 'annotations': <Object?>[]},
        ],
      },
    for (final c in calls) {'type': 'function_call', 'call_id': c.id, 'name': c.name, 'arguments': jsonEncode(c.input)},
  ];
}
