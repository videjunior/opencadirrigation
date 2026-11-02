/// Design runner for the browser: a dedicated Web Worker running
/// `design_worker.js` (compiled from `lib/worker/design_worker.dart` by
/// `tool/build_worker.sh`). Falls back to the UI thread when the worker
/// cannot be loaded.
///
/// Every job has a number that the worker repeats in its answers, so an
/// answer to a cancelled job is never taken for the next one. The first
/// answer also says which build made the worker: one left in the browser
/// cache by an earlier version is stopped and loaded again past the cache
/// (`design_worker.js?v=<version>`), once; a worker that keeps failing is
/// given up after [WorkerDesignRunner.maxFailures] jobs in a row, and the
/// next ones run on the UI thread.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../version.dart';
import 'design_job.dart';

DesignRunner createDesignRunner() => WorkerDesignRunner();

/// The worker script could not be loaded, crashed before answering, or
/// belongs to another build of the program.
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
  final InThreadDesignRunner _fallback = InThreadDesignRunner();

  /// Jobs in a row the worker failed: past [maxFailures] the UI thread runs
  /// them (a worker that cannot load is not tried on every design).
  int _failures = 0;
  static const maxFailures = 3;

  /// Loads the script past the browser cache (after a worker of another build).
  bool _bypassCache = false;

  int _job = 0;
  Completer<DesignResponse>? _pending;

  /// Why the worker was given up on, if it was.
  String? unavailableReason;

  String get _url => _bypassCache ? '$scriptUrl?v=${Uri.encodeQueryComponent(appVersionFull)}' : scriptUrl;

  @override
  Future<DesignResponse> run(DesignRequest request, {void Function(DesignProgress progress)? onProgress, void Function(String mode)? onMode, Future<void> Function()? yieldControl}) async {
    if (_failures < maxFailures) {
      onMode?.call('worker');
      try {
        final r = await _runInWorker(request, onProgress);
        _failures = 0;
        return r;
      } on _StaleWorker {
        // a worker of another build: once more past the cache
        _bypassCache = true;
        try {
          final r = await _runInWorker(request, onProgress);
          _failures = 0;
          return r;
        } on _StaleWorker {
          _failures = maxFailures;
          unavailableReason = 'design_worker.js of another build';
        } on WorkerUnavailable catch (e) {
          _failures++;
          unavailableReason = e.message;
        }
      } on WorkerUnavailable catch (e) {
        _failures++;
        unavailableReason = e.message;
      }
    }
    return _fallback.run(request, onProgress: onProgress, onMode: onMode, yieldControl: yieldControl);
  }

  Future<DesignResponse> _runInWorker(DesignRequest request, void Function(DesignProgress progress)? onProgress) {
    final job = ++_job;
    final done = Completer<DesignResponse>();
    _pending = done;
    final web.Worker w;
    try {
      w = _worker ??= web.Worker(_url.toJS);
    } catch (e) {
      return Future.error(WorkerUnavailable('$e'));
    }
    var checked = false;
    w.onmessage = ((web.MessageEvent e) {
      if (done.isCompleted) return;
      final data = e.data;
      if (data == null || !data.typeofEquals('string')) return;
      final m = jsonDecode((data as JSString).toDart) as Map<String, dynamic>;
      if (!checked) {
        checked = true;
        if (!isSameBuild(m)) {
          _drop(w);
          done.completeError(const _StaleWorker());
          return;
        }
      }
      // an answer to an earlier job (cancelled) is not this one's
      if (m[jobKey] != job) return;
      dispatchDesignMessage(m, onProgress: onProgress, onDone: done.complete, onError: done.completeError);
    }).toJS;
    w.onerror = ((web.Event e) {
      final msg = e.isA<web.ErrorEvent>() ? (e as web.ErrorEvent).message : 'worker error';
      _drop(w);
      if (!done.isCompleted) done.completeError(WorkerUnavailable(msg));
    }).toJS;
    w.postMessage(jsonEncode({...request.toJson(), jobKey: job}).toJS);
    return done.future.whenComplete(() {
      if (identical(_pending, done)) _pending = null;
    });
  }

  void _drop(web.Worker w) {
    if (identical(_worker, w)) _worker = null;
    w.terminate();
  }

  /// Stops the worker in the middle of the job (it cannot be told to stop:
  /// it is terminated, and the next job starts a new one).
  @override
  void cancel() {
    final p = _pending;
    _pending = null;
    final w = _worker;
    if (w != null) _drop(w);
    _fallback.cancel();
    if (p != null && !p.isCompleted) p.completeError(const DesignCancelled());
  }

  @override
  void dispose() {
    cancel();
  }
}

class _StaleWorker implements Exception {
  const _StaleWorker();
}
