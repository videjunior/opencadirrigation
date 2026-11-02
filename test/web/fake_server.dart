/// Hybrid isolate of test/web/browser_platform_test.dart (runs in the VM,
/// beside the browser): an HTTP server on the loopback interface that
/// answers the page's fetch calls with CORS headers. It sends its address
/// as the first message.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// [channel] is the StreamChannel package:test hands to hybrid isolates.
Future<void> hybridMain(dynamic channel) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    final res = req.response;
    res.headers
      ..set('access-control-allow-origin', '*')
      ..set('access-control-allow-headers', '*')
      ..set('access-control-allow-methods', 'GET, POST, OPTIONS')
      ..set('access-control-expose-headers', 'content-type, request-id');
    if (req.method == 'OPTIONS') {
      await res.close();
      return;
    }
    final body = await utf8.decoder.bind(req).join();
    switch (req.uri.path) {
      case '/echo':
        res.headers.contentType = ContentType('text', 'plain', charset: 'utf-8');
        res.write('${req.method} $body ${req.headers.value('x-test') ?? '-'}');
      case '/bytes':
        res.headers.contentType = ContentType('application', 'octet-stream');
        res.add([0, 1, 2, 250]);
      case '/stream':
        // server-sent events written in three pieces
        res.headers.contentType = ContentType('text', 'event-stream', charset: 'utf-8');
        res.bufferOutput = false;
        for (final word in ['um', 'dois', 'três']) {
          res.add(utf8.encode('data: $word\n\n'));
          await res.flush();
          await Future<void>.delayed(const Duration(milliseconds: 80));
        }
      case '/slow':
        // one piece, then nothing for a long time (the client cancels)
        res.headers.contentType = ContentType('text', 'event-stream', charset: 'utf-8');
        res.bufferOutput = false;
        res.add(utf8.encode('data: first\n\n'));
        await res.flush();
        await Future<void>.delayed(const Duration(seconds: 30));
      default:
        res.statusCode = HttpStatus.notFound;
        res.write('not found');
    }
    try {
      await res.close();
    } on Object {
      // the client went away (the cancelled request)
    }
  });
  channel.sink.add('http://127.0.0.1:${server.port}/');
  await (channel.stream as Stream<Object?>).drain<void>();
  await server.close(force: true);
}
