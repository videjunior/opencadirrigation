/// Design runner for the browser: a dedicated Web Worker running
/// `design_worker.js` (compiled from `lib/worker/design_worker.dart` by
/// `tool/build_worker.sh`). Falls back to the UI thread when the worker
/// cannot be loaded.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'design_job.dart';

DesignRunner createDesignRunner() => WorkerDesignRunner();

/// The worker script could not be loaded or crashed before answering.
class WorkerUnavailable implements Exception {
  WorkerUnavailable(this.message);
  final String message;

  @override
  String toString() => 'WorkerUnavailable: $message';
}

class WorkerDesignRunner implements DesignRunner {
  WorkerDesignRunner({this.scriptUrl = 'design_worker.js'});

  final String scriptUrl;
  web.Worker? _worker;
  bool _unavailable = false;
  final InThreadDesignRunner _fallback = InThreadDesignRunner();

  /// Why the worker was given up on, if it was.
  String? unavailableReason;

  @override
  Future<DesignResponse> run(DesignRequest request, {void Function(DesignProgress progress)? onProgress, void Function(String mode)? onMode, Future<void> Function()? yieldControl}) async {
    if (!_unavailable) {
      try {
        onMode?.call('worker');
        return await _runInWorker(request, onProgress);
      } on WorkerUnavailable catch (e) {
        _unavailable = true;
        unavailableReason = e.message;
      }
    }
    return _fallback.run(request, onProgress: onProgress, onMode: onMode, yieldControl: yieldControl);
  }

  Future<DesignResponse> _runInWorker(DesignRequest request, void Function(DesignProgress progress)? onProgress) {
    final done = Completer<DesignResponse>();
    final w = _worker ??= web.Worker(scriptUrl.toJS);
    w.onmessage = ((web.MessageEvent e) {
      if (done.isCompleted) return;
      final data = e.data;
      if (data == null || !data.typeofEquals('string')) return;
      dispatchDesignMessage(jsonDecode((data as JSString).toDart) as Map<String, dynamic>, onProgress: onProgress, onDone: done.complete, onError: done.completeError);
    }).toJS;
    w.onerror = ((web.Event e) {
      final msg = e.isA<web.ErrorEvent>() ? (e as web.ErrorEvent).message : 'worker error';
      _worker = null;
      w.terminate();
      if (!done.isCompleted) done.completeError(WorkerUnavailable(msg));
    }).toJS;
    w.postMessage(jsonEncode(request.toJson()).toJS);
    return done.future;
  }

  @override
  void dispose() {
    _worker?.terminate();
    _worker = null;
  }
}
