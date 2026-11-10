/// The GET of the forecast on the desktop (dart:io): the headers the caller gives (the User-Agent MET Norway asks
/// for, `If-Modified-Since`), the status as it comes (a 304 is an answer) and the caching headers.
library;

import 'dart:convert';
import 'dart:io';

import '../../core/io/forecast_online.dart';

const isBrowser = false;

Future<ForecastHttpResponse> forecastGet(String url, Map<String, String> headers) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse(url));
    headers.forEach(req.headers.set);
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    return ForecastHttpResponse(res.statusCode, text, expires: res.headers.value('expires'), lastModified: res.headers.value('last-modified'));
  } finally {
    client.close();
  }
}
