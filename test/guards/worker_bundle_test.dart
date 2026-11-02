import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/toolchain.dart';

/// web/design_worker.js is committed, and `flutter run`, the plain
/// `flutter build web` and the repository itself serve it as it is: a change
/// to the engine, to the job protocol (lib/app/state/design_job.dart) or to a
/// string of lib/app/i18n.dart that skipped tool/build_worker.sh would run an
/// old engine in the browser while the VM tests pass on the new one. dart2js
/// is deterministic for one SDK, so the guard compiles the worker again with
/// the flags of tool/build_worker.sh and wants the same bytes.
void main() {
  test('tool/build_worker.sh compiles lib/worker/design_worker.dart to web/design_worker.js', () {
    expect(workerCompileFlags(), contains('--no-source-maps'));
  });

  test('web/design_worker.js is the compiled lib/worker/design_worker.dart of this tree', () async {
    final why = toolchainMismatch();
    if (why != null) {
      markTestSkipped(why);
      return;
    }
    final sdk = FlutterSdk.current()!;
    final tmp = Directory.systemTemp.createTempSync('oci_worker_');
    try {
      final out = '${tmp.path}/design_worker.js';
      final r = await Process.run(sdk.dart, ['compile', 'js', ...workerCompileFlags(), '-o', out, 'lib/worker/design_worker.dart']);
      expect(r.exitCode, 0, reason: 'dart compile js failed:\n${r.stdout}\n${r.stderr}');
      final fresh = File(out).readAsBytesSync();
      final committed = File('web/design_worker.js').readAsBytesSync();
      var same = fresh.length == committed.length;
      for (var i = 0; same && i < fresh.length; i++) {
        same = fresh[i] == committed[i];
      }
      expect(
        same,
        isTrue,
        reason:
            'web/design_worker.js (${committed.length} bytes) is not the worker of this tree (${fresh.length} bytes): '
            'run `sh tool/build_worker.sh` and commit web/design_worker.js',
      );
    } finally {
      tmp.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

/// The `dart compile js` options of tool/build_worker.sh (between `js` and `-o`).
List<String> workerCompileFlags() {
  final script = File('tool/build_worker.sh').readAsStringSync();
  final m = RegExp(r'^dart compile js (.*?)\s*-o web/design_worker\.js lib/worker/design_worker\.dart\s*$', multiLine: true).firstMatch(script);
  if (m == null) throw StateError('tool/build_worker.sh: no "dart compile js … -o web/design_worker.js lib/worker/design_worker.dart" line');
  return m.group(1)!.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
}
