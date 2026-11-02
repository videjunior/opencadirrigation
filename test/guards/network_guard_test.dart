import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../flutter_test_config.dart';

/// The network guard of test/flutter_test_config.dart: plain tests (outside
/// testWidgets) reach the loopback interface and nothing else.
void main() {
  test('loopback hosts', () {
    for (final h in ['localhost', '127.0.0.1', '127.1.2.3', '::1', '[::1]', 'tiles.localhost']) {
      expect(isLoopbackHost(h), isTrue, reason: h);
    }
    for (final h in ['example.com', '10.0.0.1', '192.168.0.10', '0.0.0.0', 'localhost.example.com', '::', '8.8.8.8']) {
      expect(isLoopbackHost(h), isFalse, reason: h);
    }
  });

  test('a request to another host fails at once and is recorded', () async {
    if (Platform.environment['OCI_TEST_NETWORK'] == '1') {
      markTestSkipped('OCI_TEST_NETWORK=1 lifts the guard');
      return;
    }
    expect(HttpOverrides.current, isA<LoopbackOnlyHttpOverrides>());
    final client = HttpClient();
    try {
      await expectLater(client.getUrl(Uri.parse('https://opencadirrigation.com/version.json')), throwsA(isA<SocketException>().having((e) => e.message, 'message', contains('blocked in tests'))));
      expect(blockedHosts, {'opencadirrigation.com'});
    } finally {
      client.close(force: true);
      // the attempt was deliberate: keep the file green
      blockedHosts.clear();
    }
  });

  test('a fake server on the loopback interface answers', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) {
      r.response
        ..headers.contentType = ContentType.text
        ..write('ok ${r.uri.path}')
        ..close();
    });
    final client = HttpClient();
    try {
      for (final host in ['127.0.0.1', 'localhost']) {
        final req = await client.getUrl(Uri.parse('http://$host:${server.port}/ping'));
        final res = await req.close();
        expect(res.statusCode, 200);
        expect(await res.transform(utf8.decoder).join(), 'ok /ping');
      }
      expect(blockedHosts, isEmpty);
    } finally {
      client.close(force: true);
      await server.close(force: true);
    }
  });
}
