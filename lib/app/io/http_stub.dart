import 'dart:convert';
import 'dart:io';

import 'http.dart';

Future<String> httpRequest(String method, String url, {Map<String, String> headers = const {}, String? body}) async {
  final client = HttpClient();
  try {
    final req = await client.openUrl(method, Uri.parse(url));
    headers.forEach(req.headers.set);
    if (body != null) req.write(body);
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode < 200 || res.statusCode >= 300) throw HttpStatusException(res.statusCode, text);
    return text;
  } finally {
    client.close();
  }
}

Future<List<int>> httpBytes(String url) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse(url));
    final res = await req.close();
    if (res.statusCode < 200 || res.statusCode >= 300) throw HttpStatusException(res.statusCode);
    final chunks = <int>[];
    await for (final c in res) {
      chunks.addAll(c);
    }
    return chunks;
  } finally {
    client.close();
  }
}
