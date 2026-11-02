import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/hooks/banned_names.dart' show BannedNames, namesIn, scanFiles;
import '../tool/sw_manifest.dart' show sha256Hex;

/// The editorial rule of the repository (CONTRIBUTING.md): competing
/// irrigation-design products and their makers are never named, anywhere;
/// CAD products and their makers are not named in what people read (the
/// interface texts, language packs, tutorial, site pages and documentation),
/// where a format goes by the name of the format (DXF, DWG R2000).
///
/// The names are the one list of tool/hooks/banned-names.sha256, which the
/// pre-commit hook checks the added lines with too: SHA-256 digests of the
/// lower-case names (one to three words, joined by a space or written
/// together), so that neither this test nor the list names them: a failure
/// gives the file, not the name.
void main() {
  final names = BannedNames.load();
  // one pass over the repository for both scopes
  late Map<String, List<String>> found;
  setUpAll(() => found = scanFiles(_repositoryFiles(), names));

  Map<String, List<String>> where(Set<String> digests) => {
    for (final e in found.entries)
      if (digests.contains(e.key)) e.key.substring(0, 12): e.value,
  };

  test('the list has both scopes, and no digest in both', () {
    expect(names.everywhere, isNotEmpty);
    expect(names.userFacing, isNotEmpty);
    expect(names.everywhere.intersection(names.userFacing), isEmpty);
  });

  test('no competing irrigation-design product or maker is named in the repository', () {
    expect(where(names.everywhere), isEmpty, reason: 'names the editorial rule forbids (digest → files)');
  });

  test('no CAD product or maker is named in the interface, the site or the documentation', () {
    expect(where(names.userFacing), isEmpty, reason: 'names the editorial rule forbids in what users read (digest → files)');
  });

  test('the digests catch a name however it is written, and nothing else', () {
    // a stand-in name with its digest (the real ones are not written anywhere)
    final probe = {sha256Hex(utf8.encode('quuxcad'))};
    for (final text in ['QuuxCAD 2.0', 'the quuxcad file', 'Quux CAD plug-in', '(quux-cad)', 'QUUX_CAD']) {
      expect(namesIn(text, probe), isNotEmpty, reason: text);
    }
    for (final text in ['quux', 'cad quux', 'quuxcadence', 'a quuxcadd']) {
      expect(namesIn(text, probe), isEmpty, reason: text);
    }
  });
}

/// Text files of the repository, relative to its root: what git tracks or
/// would add (so not the folders kept out of it, such as local notes and
/// reports), binary files left out; without git, everything but the tools'
/// caches and build output.
List<String> _repositoryFiles() {
  final binary = RegExp(r'\.(png|webp|ico|jpe?g|gif|ttf|otf|woff2?|wasm|dwg|dgn|gz|zip|kmz|shp|shx|dbf|pdf|tiff?|las|laz|bin|xlsx|jar|keystore|icns|so|dylib)$', caseSensitive: false);
  try {
    final git = Process.runSync('git', ['ls-files', '--cached', '--others', '--exclude-standard', '-z'], stdoutEncoding: utf8);
    if (git.exitCode == 0) {
      return [
        for (final path in (git.stdout as String).split('\u0000'))
          if (path.isNotEmpty && !binary.hasMatch(path) && !path.endsWith('.DS_Store') && File(path).existsSync()) path,
      ];
    }
  } on ProcessException {
    // no git: walk the folder
  }
  final out = <String>[];
  final skipDirs = {'.git', '.dart_tool', 'build', 'node_modules', '.idea', '.vscode', 'Pods', 'ephemeral', '.claude', 'reports', 'research_notes'};
  void walk(Directory dir, String prefix) {
    for (final e in dir.listSync(followLinks: false)) {
      final name = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
      final path = '$prefix$name';
      if (e is Directory) {
        if (!skipDirs.contains(name)) walk(e, '$path/');
      } else if (e is File && !binary.hasMatch(name) && name != '.DS_Store') {
        out.add(path);
      }
    }
  }

  walk(Directory.current, '');
  return out;
}
