/// Minimal HTTP helper (fetch on the web, HttpClient elsewhere).
library;

import 'http_stub.dart' if (dart.library.js_interop) 'http_web.dart' as impl;

/// A response outside the 2xx range. [status] lets callers tell a missing
/// resource (404, e.g. a map tile with no data) from a rejected request
/// (400/403, e.g. an invalid API key).
class HttpStatusException implements Exception {
  HttpStatusException(this.status, [this.body = '']);
  final int status;
  final String body;

  /// Message of a Google-style JSON error body, else the raw body, else
  /// the status.
  String get message {
    final m = RegExp(r'"message"\s*:\s*"([^"]*)"').firstMatch(body);
    final s = m?.group(1) ?? body.trim();
    return s.isEmpty ? 'HTTP $status' : s;
  }

  @override
  String toString() => body.isEmpty ? 'HTTP $status' : 'HTTP $status: $body';
}

/// Performs a request and returns the response body as text; throws on
/// network errors or non-2xx status.
Future<String> httpRequest(String method, String url, {Map<String, String> headers = const {}, String? body}) => impl.httpRequest(method, url, headers: headers, body: body);

/// Downloads binary content (map tiles, images).
Future<List<int>> httpBytes(String url) => impl.httpBytes(url);
