import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/io/forecast_http.dart';

/// The GET of the forecast on the desktop (1.7.0 FCT, lib/app/io/forecast_http_stub.dart) against a server on the
/// loopback interface (plain tests only: a file with testWidgets answers 400 to every request).
void main() {
  test('the desktop GET: the headers it is given, the status as it comes, the caching headers it gets', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final seen = <String?>[];
    server.listen((r) {
      seen
        ..add(r.headers.value('user-agent'))
        ..add(r.headers.value('if-modified-since'));
      if (r.headers.value('if-modified-since') != null) {
        r.response.statusCode = 304;
      } else {
        r.response.headers
          ..set('expires', 'Tue, 10 Nov 2026 03:31:58 GMT')
          ..set('last-modified', 'Tue, 10 Nov 2026 02:31:47 GMT');
        r.response.write('{"ok":true}');
      }
      r.response.close();
    });
    try {
      final url = 'http://127.0.0.1:${server.port}/weatherapi/locationforecast/2.0/complete';
      final a = await forecastUrlLoader(url, {'User-Agent': forecastUserAgent});
      expect(a.status, 200);
      expect(a.body, '{"ok":true}');
      expect(a.expires, 'Tue, 10 Nov 2026 03:31:58 GMT');
      expect(a.lastModified, 'Tue, 10 Nov 2026 02:31:47 GMT');
      expect(seen.first, startsWith('OpenCADIrrigation/'));
      expect(seen.first, contains('github.com/videjunior/opencadirrigation'));
      final b = await forecastUrlLoader(url, {'If-Modified-Since': 'Tue, 10 Nov 2026 02:31:47 GMT'});
      expect(b.status, 304, reason: 'a status outside 2xx is an answer, not an error');
      expect(forecastFromBrowser, isFalse);
    } finally {
      await server.close(force: true);
    }
  });
}
