/// The engine as a Dart package without Flutter (1.6.0 MOD, MOD-22):
/// tool/engine_package.dart writes lib/core, the command line and the two
/// plain-Dart files of lib/app it reads under a pubspec with the engine's
/// packages only; every library they reach is in it.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/engine_package.dart';

void main() {
  test('the engine package holds what lib/core and bin/oci.dart reach, and no Flutter', () {
    final dest = Directory.systemTemp.createTempSync('oci_engine_');
    try {
      final files = writeEnginePackage(Directory.current.path, dest.path, assets: false);
      expect(files, contains('bin/oci.dart'));
      expect(files, contains('lib/core/api.dart'));
      expect(files, contains('lib/app/i18n.dart'));
      expect(files.where((f) => f.startsWith('lib/app/') && !f.startsWith('lib/app/i18n_parts/')).toSet(), {'lib/app/i18n.dart', 'lib/app/version.dart'});
      final pubspec = File('${dest.path}/pubspec.yaml').readAsStringSync();
      expect(pubspec, isNot(contains('flutter')));
      expect(pubspec, contains('name: opencadirrigation'));
      for (final p in enginePackages) {
        expect(pubspec, contains(RegExp('^  $p: \\S+', multiLine: true)), reason: p);
      }
      expect(pubspec, contains(RegExp(r'^  sdk: \^?\d', multiLine: true)));
      // every import of the libraries in the package resolves inside it or
      // to one of the engine's packages
      final missing = <String>[], foreign = <String>{};
      final todo = ['bin/oci.dart', 'lib/core/api.dart'], seen = <String>{};
      while (todo.isNotEmpty) {
        final rel = todo.removeLast();
        if (!seen.add(rel)) continue;
        final f = File('${dest.path}/$rel');
        if (!f.existsSync()) {
          missing.add(rel);
          continue;
        }
        for (final m in RegExp(r'''^(?:import|export|part)\s+'([^']+)'(?:\s|;)''', multiLine: true).allMatches(f.readAsStringSync())) {
          final uri = m.group(1)!;
          if (uri.startsWith('dart:')) {
            if (uri == 'dart:ui') foreign.add('$rel → $uri');
          } else if (uri.startsWith('package:opencadirrigation/')) {
            todo.add('lib/${uri.substring('package:opencadirrigation/'.length)}');
          } else if (uri.startsWith('package:')) {
            final name = uri.substring('package:'.length).split('/').first;
            if (!enginePackages.contains(name)) foreign.add('$rel → $uri');
          } else {
            todo.add(Uri.parse(rel).resolve(uri).path);
          }
        }
      }
      expect(missing, isEmpty, reason: 'libraries reached but not in the package');
      expect(foreign, isEmpty, reason: 'imports of packages the engine package does not have');
      expect(seen.length, greaterThan(100));
    } finally {
      dest.deleteSync(recursive: true);
    }
  });

  test('the pubspec of the engine follows the app\'s versions', () {
    const app = '''
name: opencadirrigation
version: 9.8.7+6
environment:
  sdk: ^3.13.3
  flutter: 3.47.9
dependencies:
  flutter:
    sdk: flutter
  web: ^1.1.2
  xml: ^7.1.0
  archive: ^4.6.0
  image: ^4.12.0
''';
    final p = enginePubspec(app);
    expect(p, contains('version: 9.8.7+6'));
    expect(p, contains('  sdk: ^3.13.3'));
    expect(p, contains('  archive: ^4.6.0'));
    expect(p, contains('  image: ^4.12.0'));
    expect(p, contains('  xml: ^7.1.0'));
    expect(p, isNot(contains('web:')));
    expect(p, isNot(contains('flutter')));
  });
}
