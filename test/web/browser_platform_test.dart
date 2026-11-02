@TestOn('browser')
@Timeout(Duration(minutes: 3))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/ai/ai_transport_web.dart' as transport;
import 'package:opencadirrigation/app/examples.dart';
import 'package:opencadirrigation/app/i18n.dart';
import 'package:opencadirrigation/app/io/ai_store.dart';
import 'package:opencadirrigation/app/io/gzip_text_web.dart' as gzip;
import 'package:opencadirrigation/app/io/http.dart';
import 'package:opencadirrigation/app/io/http_web.dart' as http;
import 'package:opencadirrigation/app/io/prefs_web.dart' as prefs;
import 'package:opencadirrigation/app/state/design_job.dart';
import 'package:opencadirrigation/app/state/design_runner_web.dart';
import 'package:opencadirrigation/core/ai/llm.dart';
import 'package:web/web.dart' as web;

/// The code that only runs in the browser (the `*_web.dart` side of the
/// conditional imports), which the VM suite never executes: storage,
/// compression, fetch, the AI transport and the compiled design worker.
/// Run with `flutter test --platform chrome test/web`; a server for fetch
/// runs beside the browser in a hybrid isolate on the loopback interface.
void main() {
  group('prefs (localStorage)', () {
    test('values round-trip under the opencadirrigation. prefix', () {
      prefs.removePref('e2e.k');
      expect(prefs.getPref('e2e.k'), isNull);
      prefs.setPref('e2e.k', 'ação ✓');
      expect(prefs.getPref('e2e.k'), 'ação ✓');
      expect(web.window.localStorage.getItem('opencadirrigation.e2e.k'), 'ação ✓');
      prefs.removePref('e2e.k');
      expect(prefs.getPref('e2e.k'), isNull);
    });
  });

  group('gzip (CompressionStream)', () {
    test('what the browser packs unpacks to the same text', () async {
      final text = '${List.generate(4000, (i) => 'linha $i: ação, 水, ✓').join('\n')}\n';
      final b64 = await gzip.gzipBase64(text);
      expect(b64, isNotNull, reason: 'Chrome has CompressionStream');
      final packed = base64Decode(b64!);
      expect(packed.sublist(0, 2), [0x1f, 0x8b], reason: 'a gzip member');
      expect(packed.length, lessThan(utf8.encode(text).length ~/ 5));
      expect(utf8.decode(const GZipDecoder().decodeBytes(packed)), text);
    });
  });

  group('conversations (IndexedDB)', () {
    test('save, load, list, delete and clear', () async {
      final store = platformConversationStore();
      await store.clear();
      expect(await store.list(), isEmpty);
      expect(await store.save('p1', '{"m":["olá"]}'), isTrue);
      expect(await store.save('p2', '{"m":[]}'), isTrue);
      final one = await store.load('p1');
      expect(one?.json, '{"m":["olá"]}');
      expect(one!.saved.difference(DateTime.now()).inMinutes.abs(), lessThan(5));
      expect((await store.list()).keys, unorderedEquals(['p1', 'p2']));
      await store.delete('p1');
      expect(await store.load('p1'), isNull);
      await store.clear();
      expect(await store.list(), isEmpty);
    });

    test('keeps the most recent maxKept', () async {
      final store = platformConversationStore();
      await store.clear();
      for (var i = 0; i <= ConversationStore.maxKept; i++) {
        expect(await store.save('c$i', '{"i":$i}'), isTrue);
      }
      final kept = await store.list();
      expect(kept.length, ConversationStore.maxKept);
      expect(kept.containsKey('c0'), isFalse, reason: 'the least recently saved goes');
      await store.clear();
    });
  });

  group('fetch', () {
    late StreamChannelLike server;
    late Uri base;
    setUpAll(() async {
      server = StreamChannelLike(spawnHybridUri('fake_server.dart'));
      base = Uri.parse(await server.next() as String);
    });
    tearDownAll(() => server.close());

    test('text and bytes, and the status of a failed request', () async {
      expect(await http.httpRequest('POST', base.resolve('echo').toString(), headers: {'x-test': '1'}, body: 'ação'), 'POST ação 1');
      expect(await http.httpBytes(base.resolve('bytes').toString()), [0, 1, 2, 250]);
      await expectLater(http.httpRequest('GET', base.resolve('missing').toString()), throwsA(isA<HttpStatusException>().having((e) => e.status, 'status', 404)));
    });

    test('the AI transport streams the answer as it is written', () async {
      final r = AiHttpRequest(base.resolve('stream'), const {'content-type': 'application/json'}, '{"q":1}');
      final res = await transport.post(r, AiCancel());
      expect(res.status, 200);
      expect(res.headers['content-type'], startsWith('text/event-stream'));
      final chunks = <String>[];
      await for (final c in res.body) {
        chunks.add(utf8.decode(c));
      }
      expect(chunks.join(), 'data: um\n\ndata: dois\n\ndata: três\n\n');
      expect(chunks.length, greaterThan(1), reason: 'read chunk by chunk, not at the end');
    });

    test('cancelling aborts a request in flight', () async {
      final cancel = AiCancel();
      final r = AiHttpRequest(base.resolve('slow'), const {}, '{}');
      final res = await transport.post(r, cancel);
      final got = <String>[];
      final done = Completer<Object?>();
      res.body.listen((c) => got.add(utf8.decode(c)), onError: done.complete, onDone: () => done.isCompleted ? null : done.complete(null), cancelOnError: true);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      cancel.cancel();
      final error = await done.future.timeout(const Duration(seconds: 10));
      expect(error, isA<AiError>().having((e) => e.kind, 'kind', AiErrorKind.cancelled));
      expect(got.join(), startsWith('data: first'));
    });

    test('a refused connection is a network error', () async {
      final r = AiHttpRequest(Uri.parse('http://127.0.0.1:9/nothing'), const {}, '{}');
      await expectLater(transport.post(r, AiCancel()), throwsA(isA<AiError>().having((e) => e.kind, 'kind', AiErrorKind.network)));
    });
  });

  group('design worker', () {
    test('the committed web/design_worker.js designs an example in a real Web Worker', () async {
      final source = StreamChannelLike(spawnHybridUri('read_worker.dart'));
      final js = await source.next() as String;
      source.close();
      final url = web.URL.createObjectURL(web.Blob([js.toJS].toJS, web.BlobPropertyBag(type: 'text/javascript')));
      final runner = WorkerDesignRunner(scriptUrl: url);
      addTearDown(() {
        runner.dispose();
        web.URL.revokeObjectURL(url);
      });
      final project = buildExample(ExampleId.garden, I18n('en').call);
      final modes = <String>[];
      final stages = <DesignStage>{};
      final response = await runner.run(
        DesignRequest.of(project, lang: 'en'),
        onMode: modes.add,
        onProgress: (p) => stages.add(p.stage),
      );
      expect(modes, ['worker']);
      expect(runner.unavailableReason, isNull, reason: 'no fallback to the main thread');
      expect(response.results.zones, isNotEmpty);
      expect(response.entities, isNotEmpty);
      expect(stages, isNotEmpty, reason: 'progress messages come back from the worker');
    });
  });
}

/// A hybrid isolate's channel read one message at a time.
class StreamChannelLike {
  StreamChannelLike(this._channel) : _queue = StreamQueue(_channel.stream);
  final dynamic _channel;
  final StreamQueue<Object?> _queue;

  Future<Object?> next() => _queue.next;

  void close() {
    _channel.sink.close();
    unawaited(_queue.cancel());
  }
}

/// The few calls of package:async's StreamQueue these tests need.
class StreamQueue<T> {
  StreamQueue(Stream<T> stream) {
    _sub = stream.listen((v) {
      if (_waiting.isNotEmpty) {
        _waiting.removeAt(0).complete(v);
      } else {
        _buffer.add(v);
      }
    });
  }
  late final StreamSubscription<T> _sub;
  final _buffer = <T>[];
  final _waiting = <Completer<T>>[];

  Future<T> get next {
    if (_buffer.isNotEmpty) return Future.value(_buffer.removeAt(0));
    final c = Completer<T>();
    _waiting.add(c);
    return c.future;
  }

  Future<void> cancel() => _sub.cancel();
}
