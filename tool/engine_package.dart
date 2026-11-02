/// Writes the engine as a Dart package of its own, without Flutter (1.6.0
/// MOD, MOD-22): `lib/core`, the two plain-Dart files of `lib/app` the
/// command line reads (the string table with its parts, and the version),
/// `bin/oci.dart`, the language packs, the PDF fonts and the catalogue
/// packs, under a pubspec that depends on the engine's packages only
/// ([enginePackages], at the versions of the app's pubspec). The package
/// keeps the name `opencadirrigation`, so `package:opencadirrigation/core/…`
/// imports work unchanged in a server, a CI job or another Dart program:
///
///   dart tool/engine_package.dart [<folder>]      (default build/engine)
///   cd build/engine && dart pub get && dart run bin/oci.dart --help
///
/// It imports dart: libraries only, so it runs with the Dart SDK alone,
/// before any `pub get` of the app (which needs the Flutter SDK).
library;

import 'dart:io';

/// The packages the engine imports (test/guards/engine_package_test.dart
/// checks that nothing else is reached).
const enginePackages = ['archive', 'image', 'xml'];

/// Folders copied whole into the engine package.
const engineFolders = ['lib/core', 'lib/app/i18n_parts', 'bin', 'assets/i18n', 'assets/fonts', 'catalogs'];

/// Single files copied into the engine package.
const engineFiles = ['lib/app/i18n.dart', 'lib/app/version.dart', 'LICENSE.md'];

/// The pubspec of the engine package, from the text of the app's pubspec
/// [appPubspec]: its version, its Dart SDK constraint and the constraints
/// of [enginePackages]; no Flutter.
String enginePubspec(String appPubspec) {
  String? field(String pattern) => RegExp(pattern, multiLine: true).firstMatch(appPubspec)?.group(1)?.trim();
  final version = field(r'^version:\s*(\S+)') ?? '0.0.0';
  final sdk = field(r'^\s+sdk:\s*(\^?[0-9][^\s#]*)') ?? '^3.0.0';
  final deps = [
    for (final p in enginePackages) '  $p: ${field('^\\s+$p:\\s*(\\S+)') ?? 'any'}',
  ];
  return [
    'name: opencadirrigation',
    'description: "The OpenCADIrrigation engine in pure Dart (no Flutter): projects, design, hydraulics, file formats and the oci command line."',
    'version: $version',
    'publish_to: none',
    '',
    'environment:',
    '  sdk: $sdk',
    '',
    'dependencies:',
    ...deps,
    '',
    'executables:',
    '  oci: oci',
    '',
  ].join('\n');
}

/// Writes the engine package of the repository at [root] into [dest]
/// (emptied first); with [assets] false, the language packs, fonts and
/// catalogue packs are left out (the code alone). Returns the files
/// written, relative to [dest].
List<String> writeEnginePackage(String root, String dest, {bool assets = true}) {
  final out = Directory(dest);
  if (out.existsSync()) out.deleteSync(recursive: true);
  out.createSync(recursive: true);
  final written = <String>[];
  void copy(String rel) {
    final target = File('$dest/$rel');
    target.parent.createSync(recursive: true);
    File('$root/$rel').copySync(target.path);
    written.add(rel);
  }

  for (final folder in engineFolders) {
    if (!assets && (folder.startsWith('assets/') || folder == 'catalogs')) continue;
    final dir = Directory('$root/$folder');
    if (!dir.existsSync()) continue;
    final files = dir.listSync(recursive: true).whereType<File>().map((f) => f.path.replaceAll(r'\', '/').substring(root.replaceAll(r'\', '/').length + 1)).toList()..sort();
    for (final rel in files) {
      // the folders of the app's own sources are not part of the engine
      if (rel.split('/').any((s) => s.startsWith('.'))) continue;
      copy(rel);
    }
  }
  for (final rel in engineFiles) {
    if (File('$root/$rel').existsSync()) copy(rel);
  }
  File('$dest/pubspec.yaml').writeAsStringSync(enginePubspec(File('$root/pubspec.yaml').readAsStringSync()));
  written.add('pubspec.yaml');
  return written;
}

void main(List<String> args) {
  final root = Directory.current.path;
  if (!File('$root/pubspec.yaml').existsSync() || !Directory('$root/lib/core').existsSync()) {
    stderr.writeln('run from the repository root');
    exit(2);
  }
  final dest = args.isEmpty ? '$root/build/engine' : args.first;
  final files = writeEnginePackage(root, dest);
  stdout.writeln('${files.length} files in $dest');
  stdout.writeln('next: cd $dest && dart pub get && dart run bin/oci.dart --help');
}
