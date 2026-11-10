/// xAI's Responses API (`POST https://api.x.ai/v1/responses`) as the AI
/// assistant uses it for the Grok models: called straight from the user's
/// browser or desktop with the user's own xAI key, no server in between.
///
/// It has the shape of OpenAI's Responses API, so the client is
/// [OpenAiClient] with what differs changed, and a conversation is kept in
/// the same format. Pure Dart; the key goes in the authorization header of
/// the request to xAI and nowhere else.
library;

import 'openai_api.dart';

class XaiClient extends OpenAiClient {
  XaiClient({required super.apiKey, required super.transport, super.sleep, super.maxRetries});

  static final endpoint = Uri.parse('https://api.x.ai/v1/responses');

  @override
  Uri get url => endpoint;

  @override
  AiProvider get provider => AiProvider.xai;
}
