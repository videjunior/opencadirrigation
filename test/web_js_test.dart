import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/site.dart' show renderSiteScript;

/// The JavaScript of the site that the Dart tests cannot run: the share target and the hosted fonts of the service
/// worker (web/sw.js), the launch queue of web/flutter_bootstrap.js and the share links of site.js (as
/// tool/site.dart writes it), each driven by a script of test/js with a fake browser in Node (no network). Skipped
/// where Node is not installed.
void main() {
  String? node;
  try {
    if (Process.runSync('node', ['--version']).exitCode == 0) node = 'node';
  } on ProcessException {
    node = null;
  }
  final skip = node == null ? 'Node is not installed' : null;

  void run(List<String> args) {
    final r = Process.runSync(node!, args);
    expect(r.exitCode, 0, reason: '${args.join(' ')}\n${r.stdout}\n${r.stderr}');
  }

  test('the service worker keeps what is shared with the installed app, and the fonts the site serves', () => run(['test/js/sw_share_fonts.test.js', 'web/sw.js']), skip: skip);

  test('the bootstrap queues the launches and the shared files for the app, and hands the address of the fonts to the engine', () {
    run(['test/js/bootstrap_launch.test.js', 'web/flutter_bootstrap.js']);
    run(['test/js/bootstrap_launch.test.js', 'web/flutter_bootstrap.js', 'fonts/']);
  }, skip: skip);

  test('a shared project leaves the address before the engine and the statistics load, and reaches the app: at the start, on a first visit, and pasted later', () {
    final dir = Directory.systemTemp.createTempSync('oci_site_js');
    try {
      final script = File('${dir.path}/site.js')..writeAsStringSync(renderSiteScript());
      run(['test/js/site_share_link.test.js', script.path]);
    } finally {
      dir.deleteSync(recursive: true);
    }
  }, skip: skip);
}
