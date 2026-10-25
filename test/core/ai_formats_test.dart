import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/ai/llm.dart';
import 'package:opencadirrigation/core/ai/llm_formats.dart';

/// The two wire formats: what the program builds for each provider reads
/// back to what it was made from (tools, the user's message with pictures
/// and PDFs, tool results with pictures and errors, answers with tool
/// calls), and an exchange converted from one format to the other and back
/// loses nothing.
void main() {
  const spec = AiToolSpec('create_entities', 'Creates items.', {
    'type': 'object',
    'properties': {
      'entities': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'type': {
              'type': 'string',
              'enum': ['area', 'pipe'],
            },
            'pts': {
              'type': 'array',
              'items': {
                'type': 'array',
                'items': {'type': 'number'},
              },
            },
          },
          'required': ['type'],
        },
      },
    },
    'required': ['entities'],
    'additionalProperties': false,
  });
  const parts = <AiPart>[AiImagePart('image/png', 'iVBORw0KGgo='), AiPdfPart('sheet.pdf', 'JVBERi0xLjc='), AiTextPart('<project_data>…</project_data>\n\nDesign it.')];
  const results = [
    AiToolResult('t1', ToolOutput('3 items')),
    AiToolResult('t2', ToolOutput('Missing "zone".', isError: true)),
    AiToolResult('t3', ToolOutput('the drawing', images: [ToolImage('image/png', 'AAAA'), ToolImage('image/png', 'BBBB')])),
  ];
  final calls = [
    const AiToolCall('t1', 'list_entities', {'type': 'pipe'}),
    const AiToolCall('t2', 'create_entities', {
      'entities': [
        {
          'type': 'area',
          'pts': [
            [0, 0],
            [40, 0],
            [40, 30],
          ],
        },
      ],
    }),
  ];

  String partKey(AiPart p) => switch (p) {
    AiTextPart(:final text) => 'text:$text',
    AiImagePart(:final mediaType, :final base64) => 'image:$mediaType:$base64',
    AiPdfPart(:final name, :final base64) => 'pdf:$name:$base64',
  };
  String resultKey(AiToolResult r) => jsonEncode({
    'id': r.id,
    'text': r.output.text,
    'error': r.output.isError,
    'images': [for (final i in r.output.images) '${i.mediaType}:${i.base64}'],
  });
  String callKey(AiToolCall c) => jsonEncode({'id': c.id, 'name': c.name, 'input': c.input});

  test('tool definitions read back unchanged in both formats', () {
    for (final back in [AnthropicFormat.specOf(AnthropicFormat.tool(spec)), OpenAiFormat.specOf(OpenAiFormat.tool(spec))]) {
      expect(back.name, spec.name);
      expect(back.description, spec.description);
      expect(jsonEncode(back.inputSchema), jsonEncode(spec.inputSchema));
    }
    expect(AnthropicFormat.tool(spec).keys, ['name', 'description', 'eager_input_streaming', 'input_schema']);
    expect(OpenAiFormat.tool(spec)['strict'], isFalse);
    expect(OpenAiFormat.tool(spec)['type'], 'function');
  });

  test('the user\'s message, its pictures and PDFs read back in both formats', () {
    expect(AnthropicFormat.userParts(AnthropicFormat.user(parts)).map(partKey), parts.map(partKey));
    expect(OpenAiFormat.userParts(OpenAiFormat.user(parts)).map(partKey), parts.map(partKey));
    final a = AnthropicFormat.user(parts)['content'] as List;
    expect((a[1] as Map)['type'], 'document');
    expect(((a[1] as Map)['source'] as Map)['media_type'], 'application/pdf');
    final o = OpenAiFormat.user(parts)['content'] as List;
    expect((o[0] as Map)['image_url'], 'data:image/png;base64,iVBORw0KGgo=');
    expect((o[1] as Map)['file_data'], 'data:application/pdf;base64,JVBERi0xLjc=');
  });

  test('tool results with errors and pictures, with a note and what the user wrote meanwhile, read back in both formats', () {
    const said = [AiTextPart('Use 25 mm pipe.')];
    final (ar, ap) = AnthropicFormat.resultsOf(AnthropicFormat.toolResults(results, user: said, note: 'Step limit.').single);
    expect(ar.map(resultKey), results.map(resultKey));
    expect(ap.map(partKey), ['text:Use 25 mm pipe.', 'text:Step limit.']);
    final items = OpenAiFormat.toolResults(results, user: said, note: 'Step limit.');
    expect(items.map((i) => i['type']), ['function_call_output', 'function_call_output', 'function_call_output', 'message', 'message']);
    expect(items[1]['output'], 'Error: Missing "zone".', reason: 'function outputs have no error flag');
    expect(items[4]['role'], 'developer');
    final (or, op) = OpenAiFormat.resultsOf(items);
    expect(or.map(resultKey), results.map(resultKey));
    expect(op.map(partKey), ['text:Use 25 mm pipe.', 'text:Step limit.']);
  });

  test('answers with text and tool calls read back in both formats', () {
    final a = AnthropicFormat.assistant('Let me draw it.', calls);
    expect(AnthropicFormat.calls((a['content'] as List).cast<Map<String, dynamic>>()).map(callKey), calls.map(callKey));
    expect(AnthropicFormat.text((a['content'] as List).cast<Map<String, dynamic>>()), 'Let me draw it.');
    final o = OpenAiFormat.assistant('Let me draw it.', calls);
    expect(OpenAiFormat.calls(o).map(callKey), calls.map(callKey));
    expect(OpenAiFormat.text(o), 'Let me draw it.');
    // a call whose arguments are not JSON keeps them for the error result
    final bad = OpenAiFormat.calls([
      {'type': 'function_call', 'call_id': 'c9', 'name': 'x', 'arguments': '{"a": '},
    ]).single;
    expect(bad.invalidRaw, '{"a": ');
    expect(parseToolInput('').$1, isEmpty);
  });

  test('an exchange converted from one format to the other and back loses nothing', () {
    // Anthropic → neutral → OpenAI → neutral → Anthropic
    final user = AnthropicFormat.user(parts);
    final answer = AnthropicFormat.assistant('Two calls.', calls);
    final res = AnthropicFormat.toolResults(results).single;
    final toOpenAi = [
      OpenAiFormat.user(AnthropicFormat.userParts(user)),
      ...OpenAiFormat.assistant(AnthropicFormat.text((answer['content'] as List).cast()), AnthropicFormat.calls((answer['content'] as List).cast())),
      ...OpenAiFormat.toolResults(AnthropicFormat.resultsOf(res).$1),
    ];
    final (r2, _) = OpenAiFormat.resultsOf(toOpenAi);
    final back = [
      AnthropicFormat.user(OpenAiFormat.userParts(toOpenAi.first)),
      AnthropicFormat.assistant(OpenAiFormat.text(toOpenAi), OpenAiFormat.calls(toOpenAi)),
      ...AnthropicFormat.toolResults(r2),
    ];
    expect(jsonEncode(back), jsonEncode([user, answer, res]));
  });
}
