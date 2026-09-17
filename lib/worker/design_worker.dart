/// Web Worker entry point: receives a design request as a JSON string and
/// answers with `progress`, then `done` or `error` messages (JSON strings).
///
/// Compiled with `tool/build_worker.sh` into `web/design_worker.js`, which
/// the app loads through `WorkerDesignRunner`. Rebuild it after changing the
/// engine (`lib/core`) or the job protocol.
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../app/state/design_job.dart';

void main() {
  final scope = globalContext as web.DedicatedWorkerGlobalScope;
  scope.addEventListener(
    'message',
    ((web.MessageEvent e) {
      final data = e.data;
      if (data == null || !data.typeofEquals('string')) return;
      final request = jsonDecode((data as JSString).toDart) as Map<String, dynamic>;
      runDesignJob(request, (m) => scope.postMessage(jsonEncode(m).toJS));
    }).toJS,
  );
}
