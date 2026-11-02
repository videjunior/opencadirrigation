import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/hooks/banned_names.dart' show findBanned;
import '../../tool/sw_manifest.dart' show sha256Hex;

/// The git hooks of tool/hooks (enabled with `git config core.hooksPath tool/hooks`).
void main() {
  test('the banned-name check finds a listed word in the added lines only, with its line', () {
    final hashes = {sha256Hex(utf8.encode('forbiddenword'))};
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
diff --git a/tool/hooks/banned-words.sha256 b/tool/hooks/banned-words.sha256
+++ b/tool/hooks/banned-words.sha256
@@ -1,0 +2 @@
+forbiddenword
''';
    expect(findBanned(diff, hashes), ['docs/a.md:5']);
    expect(findBanned(diff, {sha256Hex(utf8.encode('other'))}), isEmpty);
  });

  test('the hash list holds SHA-256 values only', () {
    for (final l in File('tool/hooks/banned-words.sha256').readAsLinesSync()) {
      if (l.trim().isEmpty || l.startsWith('#')) continue;
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(l.trim()), isTrue, reason: l);
    }
  });

  test('the pre-commit hook is executable', () {
    if (Platform.isWindows) return;
    final mode = Process.runSync('git', ['ls-files', '-s', 'tool/hooks/pre-commit']).stdout as String;
    expect(mode, anyOf(isEmpty, startsWith('100755')), reason: 'git update-index --chmod=+x tool/hooks/pre-commit');
    expect(File('tool/hooks/pre-commit').statSync().modeString(), startsWith('rwx'));
  });
}
