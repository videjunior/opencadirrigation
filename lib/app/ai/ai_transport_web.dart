import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../core/ai/llm.dart';

/// Response headers the clients read (when the API exposes them to the page),
/// the account's rate limits among them (the connection test shows them).
final _headers = [
  'content-type',
  'retry-after',
  'retry-after-ms',
  'request-id',
  'x-request-id',
  'x-should-retry',
  for (final k in ['requests', 'tokens', 'input-tokens', 'output-tokens'])
    for (final x in ['limit', 'remaining', 'reset']) 'anthropic-ratelimit-$k-$x',
  for (final x in ['limit', 'remaining', 'reset'])
    for (final k in ['requests', 'tokens']) 'x-ratelimit-$x-$k',
];

/// fetch with an AbortController; the body is read chunk by chunk from its
/// ReadableStream, so the answer shows as it is written. No cookies and no
/// referrer go with the request. Cancelling aborts the fetch, and so does
/// dropping the body before its end (an idle timeout), so the server stops
/// writing an answer nobody reads. fetch cannot tell when the upload is
/// over: [AiHttpRequest.onSent] is never called here.
Future<AiHttpResponse> post(AiHttpRequest r, AiCancel cancel) async {
  final abort = web.AbortController();
  cancel.onCancel(() => abort.abort());
  final h = web.Headers();
  r.headers.forEach((k, v) => h.append(k, v));
  final init = web.RequestInit(method: 'POST', headers: h, body: r.body.toJS, signal: abort.signal, credentials: 'omit', referrerPolicy: 'no-referrer', cache: 'no-store');
  final web.Response res;
  try {
    res = await web.window.fetch(r.url.toString().toJS, init).toDart;
  } catch (_) {
    // a blocked request (CORS, offline, extension, an OpenAI error answered
    // without CORS headers) gives no detail
    if (cancel.cancelled) throw AiError(AiErrorKind.cancelled);
    throw AiError(AiErrorKind.network);
  }
  final headers = <String, String>{};
  for (final k in _headers) {
    final v = res.headers.get(k);
    if (v != null) headers[k] = v;
  }
  return AiHttpResponse(res.status, headers, _body(res, cancel, abort));
}

Stream<List<int>> _body(web.Response res, AiCancel cancel, web.AbortController abort) async* {
  final stream = res.body;
  if (stream == null) {
    final buf = await res.arrayBuffer().toDart;
    yield buf.toDart.asUint8List();
    return;
  }
  final reader = stream.getReader() as web.ReadableStreamDefaultReader;
  try {
    while (true) {
      final web.ReadableStreamReadResult chunk;
      try {
        chunk = await reader.read().toDart;
      } catch (_) {
        throw AiError(cancel.cancelled ? AiErrorKind.cancelled : AiErrorKind.network);
      }
      if (chunk.done) break;
      final v = chunk.value;
      if (v != null && v.isA<JSUint8Array>()) yield (v as JSUint8Array).toDart;
    }
  } finally {
    // read to its end, or dropped by the listener: either way the exchange
    // is over (after the end, aborting does nothing)
    abort.abort();
    try {
      reader.releaseLock();
    } catch (_) {}
  }
}
