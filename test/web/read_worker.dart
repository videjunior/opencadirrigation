/// Hybrid isolate of test/web/browser_platform_test.dart (runs in the VM):
/// sends the committed web/design_worker.js, which the page starts as a
/// Web Worker from a Blob.
library;

import 'dart:io';

/// [channel] is the StreamChannel package:test hands to hybrid isolates.
void hybridMain(dynamic channel) {
  channel.sink.add(File('web/design_worker.js').readAsStringSync());
}
