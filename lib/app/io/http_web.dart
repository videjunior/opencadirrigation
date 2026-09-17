import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'http.dart';

Future<String> httpRequest(String method, String url, {Map<String, String> headers = const {}, String? body}) async {
  final h = web.Headers();
  headers.forEach((k, v) => h.append(k, v));
  final init = web.RequestInit(method: method, headers: h);
  if (body != null) init.body = body.toJS;
  final r = await web.window.fetch(url.toJS, init).toDart;
  final text = (await r.text().toDart).toDart;
  if (r.status < 200 || r.status >= 300) throw HttpStatusException(r.status, text);
  return text;
}

Future<List<int>> httpBytes(String url) async {
  final r = await web.window.fetch(url.toJS).toDart;
  if (r.status < 200 || r.status >= 300) throw HttpStatusException(r.status);
  final buf = await r.arrayBuffer().toDart;
  return buf.toDart.asUint8List();
}
