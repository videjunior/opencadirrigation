/// Design runner for the Dart VM (desktop, tests): one short-lived isolate
/// per run, messages as JSON strings.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'design_job.dart';

DesignRunner createDesignRunner() => IsolateDesignRunner();

class IsolateDesignRunner implements DesignRunner {
  @override
  Future<DesignResponse> run(DesignRequest request, {void Function(DesignProgress progress)? onProgress, void Function(String mode)? onMode, Future<void> Function()? yieldControl}) async {
    onMode?.call('isolate');
    final port = ReceivePort();
    final done = Completer<DesignResponse>();
    final sub = port.listen((msg) {
      if (done.isCompleted) return;
      dispatchDesignMessage(jsonDecode(msg as String) as Map<String, dynamic>, onProgress: onProgress, onDone: done.complete, onError: done.completeError);
    });
    final send = port.sendPort;
    final payload = jsonEncode(request.toJson());
    // Listen to the outcome before the isolate can answer: an error posted
    // before anyone awaits [done] would be reported as unhandled.
    _spawn(payload, send).catchError((Object e, StackTrace st) {
      if (!done.isCompleted) done.completeError(e, st);
    });
    try {
      return await done.future;
    } finally {
      await sub.cancel();
      port.close();
    }
  }

  @override
  void dispose() {}
}

/// Spawned from a scope that holds only sendable values: a closure created
/// inside [IsolateDesignRunner.run] would capture its completer and port
/// subscription, which cannot cross isolates.
Future<void> _spawn(String payload, SendPort send) => Isolate.run(() => _job(payload, send));

Future<void> _job(String payload, SendPort send) => runDesignJob(jsonDecode(payload) as Map<String, dynamic>, (m) => send.send(jsonEncode(m)));
