import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/ai/llm.dart';

/// HttpClient: the body bytes are written as UTF-8 (a JSON body holds any
/// language) and flushed, which tells when the upload is over
/// ([AiHttpRequest.onSent]); the response streams. Cancelling closes the
/// connection, and so does dropping the body before its end (an idle
/// timeout), so the server stops writing an answer nobody reads.
Future<AiHttpResponse> post(AiHttpRequest r, AiCancel cancel) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  cancel.onCancel(() => client.close(force: true));
  try {
    final req = await client.postUrl(r.url);
    r.headers.forEach(req.headers.set);
    final bytes = utf8.encode(r.body);
    req.contentLength = bytes.length;
    req.add(bytes);
    await req.flush();
    r.onSent?.call();
    final res = await req.close();
    final headers = <String, String>{};
    res.headers.forEach((k, v) => headers[k.toLowerCase()] = v.join(', '));
    final body = StreamController<List<int>>();
    final sub = res.listen(
      body.add,
      onError: (Object e) {
        body.addError(cancel.cancelled ? AiError(AiErrorKind.cancelled) : AiError(AiErrorKind.network, message: e is SocketException ? e.message : e.runtimeType.toString()));
        body.close();
        client.close(force: true);
      },
      onDone: () {
        body.close();
        client.close();
      },
      cancelOnError: true,
    );
    body.onCancel = () {
      sub.cancel();
      client.close(force: true);
    };
    return AiHttpResponse(res.statusCode, headers, body.stream);
  } catch (e) {
    client.close(force: true);
    if (cancel.cancelled) throw AiError(AiErrorKind.cancelled);
    throw AiError(AiErrorKind.network, message: e is SocketException ? e.message : e.runtimeType.toString());
  }
}
