/// OpenRouter's Responses API (`POST https://openrouter.ai/api/v1/responses`)
/// as the AI assistant uses it: one OpenRouter key reaches the models of many
/// makers through OpenRouter's servers, called straight from the user's
/// browser or desktop, no server of this app in between.
///
/// It has the shape of OpenAI's Responses API (stateless: the conversation
/// goes whole with every request), so the client is [OpenAiClient] with what
/// differs changed, and a conversation is kept in the same format. Pure
/// Dart; the key goes in the authorization header of the request to
/// OpenRouter and nowhere else.
library;

import 'openai_api.dart';

class OpenRouterClient extends OpenAiClient {
  OpenRouterClient({required super.apiKey, required super.transport, super.sleep, super.maxRetries});

  static final endpoint = Uri.parse('https://openrouter.ai/api/v1/responses');

  @override
  Uri get url => endpoint;

  @override
  AiProvider get provider => AiProvider.openrouter;
}
