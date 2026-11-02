import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The engine (lib/core) is plain Dart: the command line, the design Web
/// Worker and whoever imports `package:opencadirrigation/core/api.dart`
/// use it without Flutter, in the VM and in the browser alike. The suite
/// runs with Flutter, so a stray `package:flutter` or `dart:ui` import in
/// lib/core would pass every other test and break only those users; this
/// guard follows the imports of every file of lib/core and lib/worker.
void main() {
  test('lib/core and everything it imports stay plain, platform-neutral Dart', () {
    final graph = ImportGraph();
    final roots = dartFilesUnder('lib/core');
    expect(roots.length, greaterThan(100), reason: 'lib/core not found: run from the repository root');
    final offenders = graph.offenders(roots, allowedApp: const {'lib/app/i18n.dart', 'lib/app/version.dart'});
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('the design worker reaches only the engine, the job protocol and the string table', () {
    final graph = ImportGraph();
    final roots = dartFilesUnder('lib/worker');
    expect(roots, contains('lib/worker/design_worker.dart'));
    final offenders = graph.offenders(roots, allowedApp: const {'lib/app/i18n.dart', 'lib/app/version.dart', 'lib/app/state/design_job.dart'});
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('the import reader sees conditional imports and package URIs', () {
    final edges = ImportGraph.directives('''
import 'dart:math';
import 'package:opencadirrigation/core/units.dart' show Units;
import 'a_stub.dart' if (dart.library.js_interop) 'a_web.dart' as impl;
export '../x.dart' hide Y;
// import 'package:flutter/material.dart';
part 'p.dart';
''');
    expect(edges, ['dart:math', 'package:opencadirrigation/core/units.dart', 'a_stub.dart', 'a_web.dart', '../x.dart']);
  });
}

/// Libraries no file of the engine may import: Flutter, and what exists only
/// on one platform (the engine runs in the VM and compiled to JavaScript).
bool _flutter(String uri) => uri.startsWith('package:flutter') || uri == 'dart:ui' || uri == 'dart:ui_web';
const _platformOnly = {'dart:io', 'dart:html', 'dart:js', 'dart:js_util', 'dart:js_interop', 'dart:js_interop_unsafe', 'dart:isolate', 'dart:ffi', 'dart:mirrors'};
bool _platform(String uri) => _platformOnly.contains(uri) || uri.startsWith('package:web/');

/// The .dart files under [dir], sorted.
List<String> dartFilesUnder(String dir) => [
  for (final f in Directory(dir).listSync(recursive: true))
    if (f is File && f.path.endsWith('.dart')) f.path.replaceAll(r'\', '/'),
]..sort();

/// Imports and exports of the package's libraries, read from the source.
class ImportGraph {
  final _cache = <String, List<String>>{};

  /// URIs of the import and export directives of [source], conditional
  /// alternatives included, in order (commented-out directives are not).
  static List<String> directives(String source) {
    final out = <String>[];
    for (final m in RegExp(r"^[ \t]*(?:import|export)\s+'([^']+)'([^;]*);", multiLine: true).allMatches(source)) {
      out.add(m.group(1)!);
      for (final alt in RegExp(r"if\s*\([^)]*\)\s*'([^']+)'").allMatches(m.group(2)!)) {
        out.add(alt.group(1)!);
      }
    }
    return out;
  }

  List<String> _uris(String path) => _cache[path] ??= directives(File(path).readAsStringSync());

  /// The package file [uri] of a directive in [from] points at, or null for
  /// `dart:` libraries and other packages.
  static String? resolve(String from, String uri) {
    const self = 'package:opencadirrigation/';
    if (uri.startsWith(self)) return 'lib/${uri.substring(self.length)}';
    if (uri.contains(':')) return null;
    final parts = from.split('/')..removeLast();
    for (final seg in uri.split('/')) {
      if (seg == '..') {
        parts.removeLast();
      } else if (seg != '.') {
        parts.add(seg);
      }
    }
    return parts.join('/');
  }

  /// Every rule broken by [roots] and the libraries they reach, as
  /// "file → import: why" lines. Files of lib/app may be reached only when
  /// listed in [allowedApp]; `dart:js_interop` and `package:web` only from
  /// lib/worker.
  List<String> offenders(List<String> roots, {required Set<String> allowedApp}) {
    final out = <String>[];
    final seen = <String>{};
    final todo = [...roots];
    while (todo.isNotEmpty) {
      final path = todo.removeLast();
      if (!seen.add(path)) continue;
      if (!File(path).existsSync()) {
        out.add('$path: imported but missing');
        continue;
      }
      for (final uri in _uris(path)) {
        if (_flutter(uri)) out.add('$path → $uri: the engine must not use Flutter');
        if (_platform(uri) && !path.startsWith('lib/worker/')) out.add('$path → $uri: the engine runs in the VM and in the browser alike');
        final target = resolve(path, uri);
        if (target == null) continue;
        if (target.startsWith('lib/app/') && !allowedApp.contains(target)) {
          out.add('$path → $uri: of lib/app only ${allowedApp.join(', ')} may be reached');
          continue;
        }
        todo.add(target);
      }
    }
    return out;
  }
}
