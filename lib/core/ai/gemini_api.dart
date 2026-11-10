/// Google's Gemini API as the AI assistant uses it: called straight from the
/// user's browser or desktop with the user's own Gemini API key, no server
/// in between.
///
/// A conversation is kept in the same format as with the Responses APIs
/// ([OpenAiFormat]: user messages, function calls and their outputs), and
/// each request is written from it in Gemini's own format. Pure Dart; the
/// key goes in a header of the request to Google and nowhere else.
library;

import 'llm.dart';
import 'llm_formats.dart';

export 'llm.dart';

class GeminiClient extends AiHttpClient {
  GeminiClient({required super.apiKey, required super.transport, super.sleep, super.maxRetries});

  @override
  AiProvider get provider => AiProvider.google;

  @override
  Map<String, dynamic> userMessage(List<AiPart> parts) => OpenAiFormat.user(parts);

  @override
  List<Map<String, dynamic>> toolResults(List<AiToolResult> results, {List<AiPart> user = const [], String? note}) => OpenAiFormat.toolResults(results, user: user, note: note);

  @override
  Future<AiReply> attempt(AiRequest r, AiCancel cancel, AiStreamListener listener) async => throw AiError(AiErrorKind.unexpected, message: 'The Gemini client is not written yet.');
}
