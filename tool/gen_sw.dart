/// Fills in the offline service worker of a web build (see
/// tool/sw_manifest.dart and web/sw.js). tool/build_web.sh runs it after
/// `flutter build web`:
///   dart run tool/gen_sw.dart [build/web] [--commit abc1234] [--date 2026-10-25]
library;

import 'dart:io';

import 'sw_manifest.dart';

void main(List<String> args) {
  String? option(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final positional = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i].startsWith('--')) {
      i++;
      continue;
    }
    positional.add(args[i]);
  }
  final dir = Directory(positional.isEmpty ? 'build/web' : positional.first);
  final version = pubspecVersion(File('pubspec.yaml').readAsStringSync());
  try {
    final r = generateServiceWorker(dir, version: version, commit: option('--commit') ?? '', date: option('--date') ?? '');
    String mb(int b) => (b / 1e6).toStringAsFixed(1);
    stdout.writeln('sw.js: build ${r.build}, ${r.files.length} files + CanvasKit ${r.canvasKit.keys.join('/')}: '
        '${mb(r.bytesFor('chromium'))} MB kept in Chromium browsers, ${mb(r.bytesFor('full'))} MB in the others (uncompressed)');
  } on Exception catch (e) {
    stderr.writeln('gen_sw: $e');
    exitCode = 1;
  }
}
