/// The GET of the forecast in the browser: a simple cross-origin request (no header of its own, so no preflight),
/// through the browser's HTTP cache (which revalidates a stale answer with `If-Modified-Since` by itself); `Expires`
/// and `Last-Modified` are headers a page may read.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../core/io/forecast_online.dart';

const isBrowser = true;

Future<ForecastHttpResponse> forecastGet(String url, Map<String, String> headers) async {
  final h = web.Headers();
  headers.forEach((k, v) => h.append(k, v));
  final r = await web.window.fetch(url.toJS, web.RequestInit(method: 'GET', headers: h)).toDart;
  final text = (await r.text().toDart).toDart;
  return ForecastHttpResponse(r.status, text, expires: r.headers.get('expires'), lastModified: r.headers.get('last-modified'));
}
