/// The HTTP exchange of the AI assistant on this platform: fetch with a
/// streamed body in the browser, HttpClient on the desktop. Only the API of
/// the provider of the chosen model ([AiProvider.host]) is ever called
/// through it, each with its own key.
library;

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/ai/llm.dart';
import 'ai_transport_stub.dart' if (dart.library.js_interop) 'ai_transport_web.dart' as impl;

/// The platform transport.
Future<AiHttpResponse> platformTransport(AiHttpRequest request, AiCancel cancel) => impl.post(request, cancel);

/// Requests leave a web page (Anthropic wants the direct-browser-access
/// header; a refused OpenAI key shows as a network failure there).
bool get platformIsBrowser => kIsWeb;
