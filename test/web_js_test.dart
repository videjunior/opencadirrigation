import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The JavaScript of the site that the Dart tests cannot run: the share target and the hosted fonts of the service
/// worker (web/sw.js) and the launch queue of web/flutter_bootstrap.js, each driven by a script of test/js with a
/// fake browser in Node (no network). Skipped where Node is not installed.
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
}
