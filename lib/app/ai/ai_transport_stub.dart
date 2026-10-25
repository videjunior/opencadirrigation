import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/ai/llm.dart';

/// HttpClient: the body bytes are written as UTF-8 (a JSON body holds any
/// language), the response streams; cancelling closes the connection.
Future<AiHttpResponse> post(AiHttpRequest r, AiCancel cancel) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  cancel.onCancel(() => client.close(force: true));
  try {
    final req = await client.postUrl(r.url);
    r.headers.forEach(req.headers.set);
    final bytes = utf8.encode(r.body);
    req.contentLength = bytes.length;
    req.add(bytes);
    final res = await req.close();
    final headers = <String, String>{};
    res.headers.forEach((k, v) => headers[k.toLowerCase()] = v.join(', '));
    final body = StreamController<List<int>>();
    res.listen(
      body.add,
      onError: body.addError,
      onDone: () {
        body.close();
        client.close();
      },
      cancelOnError: true,
    );
    return AiHttpResponse(res.statusCode, headers, body.stream);
  } catch (e) {
    client.close(force: true);
    if (cancel.cancelled) throw AiError(AiErrorKind.cancelled);
    throw AiError(AiErrorKind.network, message: e is SocketException ? e.message : e.runtimeType.toString());
  }
}
