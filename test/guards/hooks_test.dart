import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/hooks/banned_names.dart' show BannedNames, bannedNamesFile, findBanned, localListFile, namesIn;
import '../../tool/sw_manifest.dart' show sha256Hex;

/// The git hooks of tool/hooks (enabled with `git config core.hooksPath tool/hooks`).
void main() {
  String digest(String name) => sha256Hex(utf8.encode(name));

  test('the banned-name check finds a listed name in the added lines only, with its line', () {
    final names = BannedNames(everywhere: {digest('forbiddenword')}, userFacing: {digest('quux cad'), digest('quuxcad')});
    const diff = '''
diff --git a/docs/a.md b/docs/a.md
--- a/docs/a.md
+++ b/docs/a.md
@@ -3,0 +4,2 @@
+a plain line
+works like ForbiddenWord does
@@ -10 +12 @@
-forbiddenword in a removed line
+fine again
diff --git a/lib/core/x.dart b/lib/core/x.dart
--- a/lib/core/x.dart
+++ b/lib/core/x.dart
@@ -1,0 +2,2 @@
+// read like Quux-CAD writes it
+// quux and cad apart
diff --git a/tool/hooks/banned-names.sha256 b/tool/hooks/banned-names.sha256
+++ b/tool/hooks/banned-names.sha256
@@ -1,0 +2 @@
+forbiddenword
''';
    // a commit adds no name of either section, in code and comments either
    expect(findBanned(diff, names), ['docs/a.md:5', 'lib/core/x.dart:2']);
    expect(findBanned(diff, BannedNames(everywhere: {digest('other')})), isEmpty);
  });

  test('the list reads its two sections and refuses what it cannot check', () {
    final names = BannedNames.parse('# comment\n[everywhere]\n${digest('aaaa')}\n\n[user-facing]\n${digest('bbbb')}\n');
    expect(names.everywhere, {digest('aaaa')});
    expect(names.userFacing, {digest('bbbb')});
    expect(names.forPath('lib/core/a.dart'), {digest('aaaa')}, reason: 'CAD names count in what people read');
    expect(names.forPath('docs/manual/a.md'), {digest('aaaa'), digest('bbbb')});
    expect(() => BannedNames.parse(digest('aaaa')), throwsFormatException, reason: 'a digest before any section');
    expect(() => BannedNames.parse('[elsewhere]\n'), throwsFormatException);
    expect(() => BannedNames.parse('[everywhere]\nquuxcad\n'), throwsFormatException, reason: 'names are never written in clear');
    expect(() => BannedNames.parse('[everywhere]\n${digest('aaaa').toUpperCase()}\n'), throwsFormatException);
  });

  test('the committed list is the one list: digests only, in both sections, and nothing else names it', () {
    final names = BannedNames.load();
    expect(names.everywhere, isNotEmpty);
    expect(names.userFacing, isNotEmpty);
    // the list of before 1.6.0 and the digests kept inside the test are gone
    expect(File('tool/hooks/banned-words.sha256').existsSync(), isFalse);
    expect(File('test/editorial_names_test.dart').readAsStringSync(), isNot(matches(RegExp(r"'[0-9a-f]{64}'"))));
  });

  test('a plain local list adds names everywhere, written in clear only there', () {
    final dir = Directory.systemTemp.createTempSync('oci_hooks_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final git = Process.runSync('git', ['init', '-q', dir.path]);
    if (git.exitCode != 0) {
      markTestSkipped('git not available');
      return;
    }
    Directory('${dir.path}/tool/hooks').createSync(recursive: true);
    File('${dir.path}/$bannedNamesFile').writeAsStringSync('[everywhere]\n${digest('aaaa')}\n[user-facing]\n');
    expect(BannedNames.loadWithLocal(dir.path).everywhere, {digest('aaaa')});
    localListFile(dir.path)!
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('# local names\nQuux CAD\n\n');
    final names = BannedNames.loadWithLocal(dir.path);
    expect(names.everywhere, {digest('aaaa'), digest('quuxcad')});
    expect(namesIn('the Quux-CAD file', names.everywhere), {digest('quuxcad')});
  });

  test('the pre-commit hook is executable', () {
    if (Platform.isWindows) return;
    final mode = Process.runSync('git', ['ls-files', '-s', 'tool/hooks/pre-commit']).stdout as String;
    expect(mode, anyOf(isEmpty, startsWith('100755')), reason: 'git update-index --chmod=+x tool/hooks/pre-commit');
    expect(File('tool/hooks/pre-commit').statSync().modeString(), startsWith('rwx'));
  });
}
