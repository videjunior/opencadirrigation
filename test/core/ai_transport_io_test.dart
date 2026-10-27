import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/ai/ai_transport_stub.dart' as io;
import 'package:opencadirrigation/core/ai/llm.dart';

/// The desktop transport of the AI assistant against a server on this
/// machine: it says when the body is up, streams the answer, and closes
/// the connection when the request is cancelled or its body dropped, so
/// the server stops writing an answer nobody reads.
void main() {
  late ServerSocket server;
  late Completer<void> gone;
  late Completer<String> received;

  // a bare HTTP server, which sees at once when the client closes the
  // connection: it answers with an event stream that never ends
  setUp(() async {
    gone = Completer<void>();
    received = Completer<String>();
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((sock) {
      final buf = <int>[];
      Timer? ticks;
      void left() {
        ticks?.cancel();
        if (!gone.isCompleted) gone.complete();
      }

      // writing after the client reset the connection fails here, not in write
      sock.done.then((_) => left(), onError: (_) => left());

      sock.listen(
        (data) {
          buf.addAll(data);
          if (received.isCompleted) return;
          final text = latin1.decode(buf);
          final head = text.indexOf('\r\n\r\n');
          if (head < 0) return;
          final length = int.parse(RegExp(r'content-length: *(\d+)', caseSensitive: false).firstMatch(text)!.group(1)!);
          if (buf.length < head + 4 + length) return;
          received.complete(utf8.decode(buf.sublist(head + 4, head + 4 + length)));
          sock.write('HTTP/1.1 200 OK\r\ncontent-type: text/event-stream\r\ntransfer-encoding: chunked\r\n\r\n');
          var n = 0;
          ticks = Timer.periodic(const Duration(milliseconds: 20), (_) {
            final chunk = 'data: {"n": ${n++}}\n\n';
            try {
              sock.write('${chunk.length.toRadixString(16)}\r\n$chunk\r\n');
            } catch (_) {
              left();
            }
          });
        },
        onDone: left,
        onError: (_) => left(),
        cancelOnError: true,
      );
    });
  });
  tearDown(() => server.close());

  AiHttpRequest request({void Function()? onSent}) => AiHttpRequest(Uri.parse('http://127.0.0.1:${server.port}/v1/messages'), const {'content-type': 'application/json'}, '{"q": "ação"}', onSent: onSent);

  test('the body goes up as UTF-8 and the transport says so before the answer; cancelling closes the connection', () async {
    var sent = false;
    final cancel = AiCancel();
    final res = await io.post(request(onSent: () => sent = true), cancel);
    expect(sent, isTrue);
    expect(await received.future, '{"q": "ação"}');
    expect(res.status, 200);
    final first = Completer<void>();
    final sub = res.body.listen((_) {
      if (!first.isCompleted) first.complete();
    }, onError: (_) {});
    await first.future;
    cancel.cancel();
    await gone.future.timeout(const Duration(seconds: 10));
    await sub.cancel();
  });

  test('dropping the body before its end (an idle timeout) closes the connection too', () async {
    final res = await io.post(request(), AiCancel());
    final first = Completer<void>();
    late StreamSubscription<List<int>> sub;
    sub = res.body.listen((_) {
      if (!first.isCompleted) first.complete();
    });
    await first.future;
    await sub.cancel();
    await gone.future.timeout(const Duration(seconds: 10));
  });

  test('an idle timeout of the client stops the exchange it reads', () async {
    final client = _Idle(transport: io.post);
    final cancel = AiCancel();
    final res = await client.open(request(), AiModel.opus55, cancel);
    // the server writes only "data:" lines without blank lines: never an event,
    // but data; the idle timeout counts lines, so give it none by not listening
    // until the timeout fired
    await expectLater(
      client.readLines(res.body.where((_) => false), AiModel.opus55, (_) {}, cancel, idle: const Duration(milliseconds: 100)),
      throwsA(isA<AiError>().having((e) => e.kind, 'kind', AiErrorKind.timeout)),
    );
    expect(cancel.cancelled, isTrue, reason: 'the attempt\'s token stops the exchange');
    await gone.future.timeout(const Duration(seconds: 10));
  });
}

/// The shared HTTP side of the clients, alone.
class _Idle extends AiHttpClient {
  _Idle({required super.transport}) : super(apiKey: 'test-key-0000');
  @override
  AiProvider get provider => AiProvider.anthropic;
  @override
  Future<AiReply> attempt(AiRequest r, AiCancel cancel, AiStreamListener listener) => throw UnimplementedError();
  @override
  Map<String, dynamic> userMessage(List<AiPart> parts) => const {};
  @override
  List<Map<String, dynamic>> toolResults(List<AiToolResult> results, {List<AiPart> user = const [], String? note}) => const [];
}
