/// Design runner for the Dart VM (desktop, tests): one short-lived isolate
/// per run, messages as JSON strings. [IsolateDesignRunner.cancel] kills
/// the isolate.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'design_job.dart';

DesignRunner createDesignRunner() => IsolateDesignRunner();

class IsolateDesignRunner implements DesignRunner {
  Isolate? _isolate;
  Completer<DesignResponse>? _pending;

  @override
  Future<DesignResponse> run(DesignRequest request, {void Function(DesignProgress progress)? onProgress, void Function(String mode)? onMode, Future<void> Function()? yieldControl}) async {
    onMode?.call('isolate');
    final port = ReceivePort();
    final exit = ReceivePort();
    final done = Completer<DesignResponse>();
    _pending = done;
    final sub = port.listen((msg) {
      if (done.isCompleted) return;
      dispatchDesignMessage(jsonDecode(msg as String) as Map<String, dynamic>, onProgress: onProgress, onDone: done.complete, onError: done.completeError);
    });
    // an isolate that ends without answering (killed, crashed)
    final exitSub = exit.listen((_) {
      if (!done.isCompleted) done.completeError(DesignJobException('the design job ended without an answer'));
    });
    final payload = jsonEncode(request.toJson());
    // Listen to the outcome before the isolate can answer: an error posted
    // before anyone awaits [done] would be reported as unhandled.
    Isolate.spawn(_job, (payload, port.sendPort), onExit: exit.sendPort, errorsAreFatal: true)
        .then((iso) {
          _isolate = iso;
          // cancelled while it started
          if (!identical(_pending, done)) iso.kill(priority: Isolate.immediate);
        })
        .catchError((Object e, StackTrace st) {
          if (!done.isCompleted) done.completeError(e, st);
        });
    try {
      return await done.future;
    } finally {
      if (identical(_pending, done)) _pending = null;
      _isolate = null;
      await sub.cancel();
      await exitSub.cancel();
      port.close();
      exit.close();
    }
  }

  @override
  void cancel() {
    final p = _pending;
    _pending = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    if (p != null && !p.isCompleted) p.completeError(const DesignCancelled());
  }

  @override
  void dispose() => cancel();
}

/// Spawned with only sendable values: a closure created inside
/// [IsolateDesignRunner.run] would capture its completer and port
/// subscription, which cannot cross isolates.
Future<void> _job((String, SendPort) args) => runDesignJob(jsonDecode(args.$1) as Map<String, dynamic>, (m) => args.$2.send(jsonEncode(m)));
